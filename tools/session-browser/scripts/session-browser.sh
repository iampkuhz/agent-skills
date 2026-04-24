#!/usr/bin/env bash
# Launch script for session-browser.
# Usage:
#   ./scripts/session-browser.sh scan    # Scan and index sessions
#   ./scripts/session-browser.sh serve   # Start web server

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# SRC_DIR is one level up from scripts (session-browser/src)
SRC_DIR="$(cd "$SCRIPT_DIR/../src" && pwd)"

export PYTHONPATH="$SRC_DIR:${PYTHONPATH:-}"

CMD="${1:-help}"
shift || true

case "$CMD" in
    scan)
        python3 -m session_browser scan "$@"
        ;;
    serve)
        python3 -m session_browser serve --allow-empty "$@"
        ;;
    *)
        echo "Usage: $0 {scan|serve} [options]"
        echo ""
        echo "Commands:"
        echo "  scan                          Scan and index all local agent sessions"
        echo "  scan --agent <name>           Scan only a specific agent (claude_code or codex)"
        echo "  serve                         Start local web server"
        echo ""
        echo "Examples:"
        echo "  $0 scan"
        echo "  $0 scan --agent codex"
        echo "  $0 scan --agent claude_code"
        echo "  $0 serve --port 8899"
        ;;
esac
