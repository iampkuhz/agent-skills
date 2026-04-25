"""CLI entry point for session-browser.

Usage:
    python -m session_browser scan        # Full scan
    python -m session_browser serve       # Start web server
    python -m session_browser serve --port 8899
    python -m session_browser stop        # Stop web server

Environment variables:
    CLAUDE_DATA_DIR  - Claude Code data directory (default: ~/.claude)
    CODEX_DATA_DIR   - Codex data directory (default: ~/.codex)
    INDEX_DIR        - Index storage directory (default: ~/.cache/agent-session-browser)
    SERVER_HOST      - Bind address (default: 0.0.0.0)
    SERVER_PORT      - Server port (default: 8899)
"""

from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
import time

from session_browser.config import SERVER_HOST, SERVER_PORT


def cmd_scan(args: argparse.Namespace) -> None:
    """Run a full or incremental scan."""
    from session_browser.index.indexer import full_scan, init_schema, _get_connection

    conn = _get_connection()
    init_schema(conn)

    agent = args.agent if hasattr(args, 'agent') else None
    label = f" ({agent})" if agent else ""
    print(f"Starting full scan{label}...")
    start = time.time()
    result = full_scan(conn, verbose=True, agent=agent)
    elapsed = time.time() - start

    print(f"\nScan complete in {elapsed:.1f}s")
    print(f"  Claude Code: {result['claude_count']} sessions")
    print(f"  Codex:       {result['codex_count']} sessions")
    print(f"  Total:       {result['total']} sessions")

    conn.close()


def cmd_serve(args: argparse.Namespace) -> None:
    """Start the local web server."""
    from session_browser.web.routes import create_server
    from session_browser.index.indexer import init_schema, _get_connection

    # Ensure index exists
    conn = _get_connection()
    init_schema(conn)
    count = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
    conn.close()

    if count == 0:
        print("Index is empty. Run 'scan' first, or server will show empty data.")
        if not args.allow_empty:
            print("Use --allow-empty to start anyway.")
            sys.exit(1)

    host = args.host or SERVER_HOST
    port = args.port or SERVER_PORT

    server = create_server(host=host, port=port)
    print(f"Starting session-browser on http://{host}:{port}")
    server.serve_forever()


def cmd_stop(args: argparse.Namespace) -> None:
    """Stop the running web server by killing the process on the port."""
    port = args.port or SERVER_PORT

    # Find PID using lsof
    try:
        result = subprocess.run(
            ["lsof", "-ti", f":{port}"],
            capture_output=True, text=True, timeout=5
        )
    except FileNotFoundError:
        print("Error: 'lsof' not found. Stop the server manually.")
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print(f"Error: timed out searching for process on port {port}.")
        sys.exit(1)

    pids = [line.strip() for line in result.stdout.strip().splitlines() if line.strip()]
    if not pids:
        print(f"No process found on port {port}. Server may not be running.")
        return

    for pid in pids:
        try:
            print(f"Stopping process {pid} on port {port}...")
            os.kill(int(pid), signal.SIGTERM)
            print(f"Process {pid} stopped.")
        except ProcessLookupError:
            print(f"Process {pid} already exited.")
        except PermissionError:
            print(f"Permission denied for process {pid}. Try: kill {pid}")


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="session-browser",
        description="Local agent session browser and analyzer",
    )
    sub = parser.add_subparsers(dest="command")

    # scan command
    scan_p = sub.add_parser("scan", help="Scan and index all local sessions")
    scan_p.add_argument("--agent", choices=["claude_code", "codex"],
                        help="Scan only a specific agent (claude_code or codex)")

    # serve command
    serve_p = sub.add_parser("serve", help="Start local web server")
    serve_p.add_argument("--host", default=SERVER_HOST, help=f"Bind address (default: {SERVER_HOST})")
    serve_p.add_argument("--port", type=int, default=SERVER_PORT, help=f"Port (default: {SERVER_PORT})")
    serve_p.add_argument("--allow-empty", action="store_true", help="Allow starting with empty index")

    # stop command
    stop_p = sub.add_parser("stop", help="Stop the running web server")
    stop_p.add_argument("--port", type=int, default=SERVER_PORT, help=f"Port to stop (default: {SERVER_PORT})")

    args = parser.parse_args()

    if args.command == "scan":
        cmd_scan(args)
    elif args.command == "serve":
        cmd_serve(args)
    elif args.command == "stop":
        cmd_stop(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
