"""HTTP server and routes for session-browser.

Uses Python's built-in http.server + jinja2 templates.
No external web framework needed for MVP.
"""

from __future__ import annotations

import json
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

import jinja2

from session_browser.index.indexer import (
    _get_connection,
    get_dashboard_stats,
    list_sessions,
    count_sessions,
    list_projects,
    get_project_stats,
    get_session,
    search_sessions,
    get_trend_data,
)
from session_browser.index.metrics import (
    get_token_breakdown,
    get_model_distribution,
    get_agent_distribution,
)


# Template directory
_TEMPLATE_DIR = Path(__file__).parent / "templates"

_template_env = jinja2.Environment(
    loader=jinja2.FileSystemLoader(str(_TEMPLATE_DIR)),
    autoescape=True,
)


def _format_number(n: int) -> str:
    """Format large numbers with K/M suffix."""
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)


def _format_duration(seconds: float) -> str:
    """Format seconds to human-readable duration."""
    if seconds < 60:
        return f"{int(seconds)}s"
    if seconds < 3600:
        return f"{int(seconds // 60)}min {int(seconds % 60)}s"
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    return f"{hours}h {minutes}min"


def _relative_time(iso_str: str) -> str:
    """Convert ISO8601 to relative time string."""
    if not iso_str:
        return ""
    from datetime import datetime, timezone
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        delta = now - dt
        days = delta.days
        if days > 30:
            return f"{days // 30}mo ago"
        if days > 0:
            return f"{days}d ago"
        hours = delta.seconds // 3600
        if hours > 0:
            return f"{hours}h ago"
        minutes = delta.seconds // 60
        return f"{minutes}m ago"
    except (ValueError, TypeError):
        return iso_str[:16]


# Register template filters
_template_env.filters["format_number"] = _format_number
_template_env.filters["format_duration"] = _format_duration
_template_env.filters["relative_time"] = _relative_time
_template_env.filters["urlencode"] = urllib.parse.quote
_template_env.filters["urldecode"] = urllib.parse.unquote


class SessionBrowserHandler(BaseHTTPRequestHandler):
    """HTTP request handler for session-browser."""

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        try:
            if path == "/" or path == "/dashboard":
                self._serve_dashboard()
            elif path == "/projects":
                self._serve_projects()
            elif path.startswith("/projects/"):
                project_key = urllib.parse.unquote(path[len("/projects/"):])
                self._serve_project(project_key)
            elif path.startswith("/sessions/"):
                # /sessions/{agent}/{session_id}
                parts = path[len("/sessions/"):].split("/", 1)
                if len(parts) == 2:
                    agent, session_id = parts
                    self._serve_session(agent, session_id)
                else:
                    self._send_404()
            elif path == "/search":
                q = params.get("q", [""])[0]
                self._serve_search(q)
            elif path.startswith("/static/"):
                self._serve_static(path[len("/static/"):])
            else:
                self._send_404()
        except Exception as e:
            self._send_500(str(e))

    def _render_template(self, name: str, **context) -> str:
        template = _template_env.get_template(name)
        return template.render(**context)

    def _send_html(self, html: str, status: int = 200) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode("utf-8"))

    def _send_404(self) -> None:
        self._send_html(self._render_template("404.html"), 404)

    def _send_500(self, error: str) -> None:
        self._send_html(self._render_template("error.html", error=error), 500)

    def _serve_dashboard(self) -> None:
        conn = _get_connection()
        stats = get_dashboard_stats(conn)
        projects = list_projects(conn, limit=10)
        recent = list_sessions(conn, limit=20, order_by="ended_at")
        trend = get_trend_data(conn, days=30)
        model_dist = get_model_distribution(conn)
        agent_dist = get_agent_distribution(conn)
        token_breakdown = get_token_breakdown(conn)
        conn.close()

        html = self._render_template(
            "dashboard.html",
            stats=stats,
            projects=projects,
            recent=recent,
            trend=trend,
            model_dist=model_dist.distribution,
            agent_dist=agent_dist,
            tokens=token_breakdown,
        )
        self._send_html(html)

    def _serve_projects(self) -> None:
        conn = _get_connection()
        projects = list_projects(conn, limit=100)
        conn.close()

        html = self._render_template(
            "projects.html",
            projects=projects,
        )
        self._send_html(html)

    def _serve_project(self, project_key: str) -> None:
        conn = _get_connection()
        pstats = get_project_stats(conn, project_key)
        sessions = list_sessions(conn, project_key=project_key, limit=100)
        conn.close()

        html = self._render_template(
            "project.html",
            project=pstats,
            sessions=sessions,
            project_key=project_key,
        )
        self._send_html(html)

    def _serve_session(self, agent: str, session_id: str) -> None:
        session_key = f"{agent}:{session_id}"
        conn = _get_connection()
        session = get_session(conn, session_key)
        conn.close()

        if session is None:
            self._send_404()
            return

        # Get raw conversation data from source
        if agent == "claude_code":
            from session_browser.sources.claude import parse_session_detail
            _, messages, tool_calls = parse_session_detail(
                session.project_key, session_id
            )
        else:
            from session_browser.sources.codex import parse_session_detail
            _, messages, tool_calls = parse_session_detail(session_id)

        html = self._render_template(
            "session.html",
            session=session,
            messages=messages,
            tool_calls=tool_calls,
        )
        self._send_html(html)

    def _serve_search(self, query: str) -> None:
        conn = _get_connection()
        results = search_sessions(conn, query, limit=50) if query else []
        conn.close()

        html = self._render_template(
            "search.html",
            query=query,
            results=results,
        )
        self._send_html(html)

    def _serve_static(self, filename: str) -> None:
        static_dir = Path(__file__).parent / "static"
        filepath = static_dir / filename
        if not filepath.exists():
            self._send_404()
            return

        content_type = "text/css" if filename.endswith(".css") else "application/javascript"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.end_headers()
        self.wfile.write(filepath.read_bytes())

    def log_message(self, format: str, *args) -> None:  # noqa: A002
        """Suppress default request logging."""
        pass


def create_server(
    host: str = "127.0.0.1",
    port: int = 8899,
) -> HTTPServer:
    """Create and return an HTTPServer instance."""
    server = HTTPServer((host, port), SessionBrowserHandler)
    return server
