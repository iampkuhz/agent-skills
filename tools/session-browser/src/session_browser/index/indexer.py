"""SQLite indexer for session-browser.

Manages a local SQLite index of all sessions from both Claude Code and Codex.
Supports:
- Full initial scan
- Incremental refresh (based on file mtimes)
- Query interface for dashboard, project, and session pages
"""

from __future__ import annotations

import json
import sqlite3
import time
from pathlib import Path
from typing import Optional

from session_browser.config import INDEX_PATH, ensure_index_dir
from session_browser.domain.models import SessionSummary, ProjectStats
from session_browser.sources import claude as claude_source
from session_browser.sources import codex as codex_source


def _get_connection(db_path: Path | None = None) -> sqlite3.Connection:
    """Get a SQLite connection to the index database."""
    ensure_index_dir()
    path = db_path or INDEX_PATH
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_schema(conn: sqlite3.Connection | None = None) -> sqlite3.Connection:
    """Create the index schema if it doesn't exist."""
    if conn is None:
        conn = _get_connection()

    conn.executescript("""
        CREATE TABLE IF NOT EXISTS sessions (
            session_key TEXT PRIMARY KEY,
            agent TEXT NOT NULL,
            session_id TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            project_key TEXT NOT NULL,
            project_name TEXT NOT NULL DEFAULT '',
            cwd TEXT NOT NULL DEFAULT '',
            started_at TEXT NOT NULL DEFAULT '',
            ended_at TEXT NOT NULL DEFAULT '',
            duration_seconds REAL NOT NULL DEFAULT 0,
            model TEXT NOT NULL DEFAULT '',
            git_branch TEXT NOT NULL DEFAULT '',
            source TEXT NOT NULL DEFAULT '',
            user_message_count INTEGER NOT NULL DEFAULT 0,
            assistant_message_count INTEGER NOT NULL DEFAULT 0,
            tool_call_count INTEGER NOT NULL DEFAULT 0,
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            cached_input_tokens INTEGER NOT NULL DEFAULT 0,
            cached_output_tokens INTEGER NOT NULL DEFAULT 0,
            indexed_at REAL NOT NULL DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS idx_sessions_project
            ON sessions(project_key);
        CREATE INDEX IF NOT EXISTS idx_sessions_agent
            ON sessions(agent);
        CREATE INDEX IF NOT EXISTS idx_sessions_ended_at
            ON sessions(ended_at DESC);
        CREATE INDEX IF NOT EXISTS idx_sessions_model
            ON sessions(model);

        CREATE TABLE IF NOT EXISTS scan_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at REAL NOT NULL,
            finished_at REAL,
            claude_count INTEGER DEFAULT 0,
            codex_count INTEGER DEFAULT 0,
            status TEXT DEFAULT 'running'
        );
    """)
    conn.commit()
    return conn


def upsert_session(conn: sqlite3.Connection, summary: SessionSummary) -> None:
    """Insert or update a single session in the index."""
    conn.execute(
        """
        INSERT INTO sessions (
            session_key, agent, session_id, title, project_key, project_name,
            cwd, started_at, ended_at, duration_seconds, model, git_branch,
            source, user_message_count, assistant_message_count, tool_call_count,
            input_tokens, output_tokens, cached_input_tokens, cached_output_tokens, indexed_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(session_key) DO UPDATE SET
            title=excluded.title,
            project_key=excluded.project_key,
            project_name=excluded.project_name,
            cwd=excluded.cwd,
            started_at=excluded.started_at,
            ended_at=excluded.ended_at,
            duration_seconds=excluded.duration_seconds,
            model=excluded.model,
            git_branch=excluded.git_branch,
            source=excluded.source,
            user_message_count=excluded.user_message_count,
            assistant_message_count=excluded.assistant_message_count,
            tool_call_count=excluded.tool_call_count,
            input_tokens=excluded.input_tokens,
            output_tokens=excluded.output_tokens,
            cached_input_tokens=excluded.cached_input_tokens,
            cached_output_tokens=excluded.cached_output_tokens,
            indexed_at=excluded.indexed_at
        """,
        (
            summary.session_key,
            summary.agent,
            summary.session_id,
            summary.title,
            summary.project_key,
            summary.project_name,
            summary.cwd,
            summary.started_at,
            summary.ended_at,
            summary.duration_seconds,
            summary.model,
            summary.git_branch,
            summary.source,
            summary.user_message_count,
            summary.assistant_message_count,
            summary.tool_call_count,
            summary.input_tokens,
            summary.output_tokens,
            summary.cached_input_tokens,
            summary.cached_output_tokens,
            time.time(),
        ),
    )


def full_scan(
    conn: sqlite3.Connection | None = None,
    verbose: bool = False,
    agent: str | None = None,
) -> dict:
    """Run a full scan of both Claude Code and Codex data sources.

    Args:
        conn: SQLite connection. If None, creates a new one.
        verbose: Print progress messages.
        agent: If provided, only scan this agent ("claude_code" or "codex").

    Returns a dict with scan statistics.
    """
    if conn is None:
        conn = _get_connection()

    init_schema(conn)

    log_id = conn.execute(
        "INSERT INTO scan_log (started_at, status) VALUES (?, 'running')",
        (time.time(),),
    ).lastrowid
    conn.commit()

    claude_count = 0
    codex_count = 0

    scan_claude = agent is None or agent == "claude_code"
    scan_codex = agent is None or agent == "codex"

    # Scan Claude Code
    if scan_claude:
        if verbose:
            print("Scanning Claude Code...")
        for summary in claude_source.scan_all_sessions():
            upsert_session(conn, summary)
            claude_count += 1
            if verbose and claude_count % 50 == 0:
                print(f"  Claude: {claude_count} sessions")

        conn.commit()

    # Scan Codex (pre-load threads DB once)
    if scan_codex:
        if verbose:
            print("Scanning Codex...")
        threads_db = codex_source.read_threads_db()
        for summary in codex_source.scan_all_sessions(threads_db):
            upsert_session(conn, summary)
            codex_count += 1
            if verbose and codex_count % 50 == 0:
                print(f"  Codex: {codex_count} sessions")

        conn.commit()

    # Update log
    conn.execute(
        "UPDATE scan_log SET finished_at=?, claude_count=?, codex_count=?, status='done' WHERE id=?",
        (time.time(), claude_count, codex_count, log_id),
    )
    conn.commit()

    return {
        "claude_count": claude_count,
        "codex_count": codex_count,
        "total": claude_count + codex_count,
    }


# ─── Query interface ───────────────────────────────────────────────────────


def get_session(conn: sqlite3.Connection, session_key: str) -> SessionSummary | None:
    """Get a single session by key."""
    row = conn.execute(
        "SELECT * FROM sessions WHERE session_key = ?", (session_key,)
    ).fetchone()
    if row is None:
        return None
    return _row_to_summary(row)


def list_sessions(
    conn: sqlite3.Connection,
    agent: str | None = None,
    project_key: str | None = None,
    model: str | None = None,
    limit: int = 50,
    offset: int = 0,
    order_by: str = "ended_at",  # "ended_at" | "input_tokens" | "tool_call_count"
) -> list[SessionSummary]:
    """List sessions with filtering and pagination."""
    clauses = []
    params: list = []

    if agent:
        clauses.append("agent = ?")
        params.append(agent)
    if project_key:
        clauses.append("project_key = ?")
        params.append(project_key)
    if model:
        clauses.append("model = ?")
        params.append(model)

    where = "WHERE " + " AND ".join(clauses) if clauses else ""
    valid_orders = {"ended_at": "ended_at DESC", "input_tokens": "input_tokens DESC", "tool_call_count": "tool_call_count DESC"}
    order = valid_orders.get(order_by, "ended_at DESC")

    query = f"SELECT * FROM sessions {where} ORDER BY {order} LIMIT ? OFFSET ?"
    params.extend([limit, offset])

    rows = conn.execute(query, params).fetchall()
    return [_row_to_summary(r) for r in rows]


def count_sessions(
    conn: sqlite3.Connection,
    agent: str | None = None,
    project_key: str | None = None,
) -> int:
    """Count sessions with optional filtering."""
    clauses = []
    params: list = []
    if agent:
        clauses.append("agent = ?")
        params.append(agent)
    if project_key:
        clauses.append("project_key = ?")
        params.append(project_key)
    where = "WHERE " + " AND ".join(clauses) if clauses else ""
    row = conn.execute(f"SELECT COUNT(*) FROM sessions {where}", params).fetchone()
    return row[0]


def get_project_stats(conn: sqlite3.Connection, project_key: str) -> ProjectStats:
    """Get aggregated statistics for a project."""
    row = conn.execute(
        """
        SELECT
            project_key,
            project_name,
            COUNT(*) as total_sessions,
            SUM(CASE WHEN agent='claude_code' THEN 1 ELSE 0 END) as claude_sessions,
            SUM(CASE WHEN agent='codex' THEN 1 ELSE 0 END) as codex_sessions,
            MIN(started_at) as first_seen,
            MAX(ended_at) as last_seen,
            COALESCE(SUM(input_tokens), 0) as total_input_tokens,
            COALESCE(SUM(output_tokens), 0) as total_output_tokens,
            COALESCE(SUM(cached_input_tokens), 0) as total_cached_tokens,
            COALESCE(SUM(tool_call_count), 0) as total_tool_calls,
            COALESCE(SUM(user_message_count), 0) as total_user_messages,
            COALESCE(SUM(assistant_message_count), 0) as total_assistant_messages
        FROM sessions
        WHERE project_key = ?
        GROUP BY project_key
        """,
        (project_key,),
    ).fetchone()

    if row is None:
        return ProjectStats(project_key=project_key, project_name="")

    return ProjectStats(
        project_key=row["project_key"],
        project_name=row["project_name"],
        total_sessions=row["total_sessions"],
        claude_sessions=row["claude_sessions"],
        codex_sessions=row["codex_sessions"],
        first_seen=row["first_seen"] or "",
        last_seen=row["last_seen"] or "",
        total_input_tokens=row["total_input_tokens"],
        total_output_tokens=row["total_output_tokens"],
        total_cached_tokens=row["total_cached_tokens"],
        total_tool_calls=row["total_tool_calls"],
        total_user_messages=row["total_user_messages"],
        total_assistant_messages=row["total_assistant_messages"],
    )


def list_projects(conn: sqlite3.Connection, limit: int = 20) -> list[ProjectStats]:
    """List projects sorted by most recent activity."""
    rows = conn.execute(
        """
        SELECT
            project_key,
            project_name,
            COUNT(*) as total_sessions,
            SUM(CASE WHEN agent='claude_code' THEN 1 ELSE 0 END) as claude_sessions,
            SUM(CASE WHEN agent='codex' THEN 1 ELSE 0 END) as codex_sessions,
            MIN(started_at) as first_seen,
            MAX(ended_at) as last_seen,
            COALESCE(SUM(input_tokens), 0) as total_input_tokens,
            COALESCE(SUM(output_tokens), 0) as total_output_tokens,
            COALESCE(SUM(cached_input_tokens), 0) as total_cached_tokens,
            COALESCE(SUM(tool_call_count), 0) as total_tool_calls,
            COALESCE(SUM(user_message_count), 0) as total_user_messages,
            COALESCE(SUM(assistant_message_count), 0) as total_assistant_messages
        FROM sessions
        GROUP BY project_key
        ORDER BY MAX(ended_at) DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()

    return [
        ProjectStats(
            project_key=r["project_key"],
            project_name=r["project_name"],
            total_sessions=r["total_sessions"],
            claude_sessions=r["claude_sessions"],
            codex_sessions=r["codex_sessions"],
            first_seen=r["first_seen"] or "",
            last_seen=r["last_seen"] or "",
            total_input_tokens=r["total_input_tokens"],
            total_output_tokens=r["total_output_tokens"],
            total_cached_tokens=r["total_cached_tokens"],
            total_tool_calls=r["total_tool_calls"],
            total_user_messages=r["total_user_messages"],
            total_assistant_messages=r["total_assistant_messages"],
        )
        for r in rows
    ]


def get_dashboard_stats(conn: sqlite3.Connection) -> dict:
    """Get dashboard-level aggregated stats."""
    row = conn.execute(
        """
        SELECT
            COUNT(*) as total_sessions,
            SUM(CASE WHEN agent='claude_code' THEN 1 ELSE 0 END) as claude_sessions,
            SUM(CASE WHEN agent='codex' THEN 1 ELSE 0 END) as codex_sessions,
            COUNT(DISTINCT project_key) as project_count,
            COALESCE(SUM(input_tokens), 0) as total_input_tokens,
            COALESCE(SUM(output_tokens), 0) as total_output_tokens,
            COALESCE(SUM(tool_call_count), 0) as total_tool_calls
        FROM sessions
        """
    ).fetchone()

    return {
        "total_sessions": row["total_sessions"],
        "claude_sessions": row["claude_sessions"],
        "codex_sessions": row["codex_sessions"],
        "project_count": row["project_count"],
        "total_input_tokens": row["total_input_tokens"],
        "total_output_tokens": row["total_output_tokens"],
        "total_tool_calls": row["total_tool_calls"],
    }


def get_trend_data(
    conn: sqlite3.Connection,
    days: int = 30,
) -> list[dict]:
    """Get daily session/trend counts for the last N days.

    Returns list of {date, claude_count, codex_count, input_tokens, output_tokens}.
    """
    rows = conn.execute(
        """
        SELECT
            DATE(ended_at) as day,
            SUM(CASE WHEN agent='claude_code' THEN 1 ELSE 0 END) as claude_count,
            SUM(CASE WHEN agent='codex' THEN 1 ELSE 0 END) as codex_count,
            COALESCE(SUM(input_tokens), 0) as input_tokens,
            COALESCE(SUM(output_tokens), 0) as output_tokens,
            COUNT(*) as total_count
        FROM sessions
        WHERE ended_at >= date('now', ?)
        GROUP BY DATE(ended_at)
        ORDER BY day
        """,
        (f"-{days} days",),
    ).fetchall()

    return [
        {
            "date": r["day"],
            "claude_count": r["claude_count"],
            "codex_count": r["codex_count"],
            "input_tokens": r["input_tokens"],
            "output_tokens": r["output_tokens"],
            "total_count": r["total_count"],
        }
        for r in rows
    ]


def list_agents(conn: sqlite3.Connection) -> list[dict]:
    """List all agents with session counts.

    Returns list of {agent, session_count, last_active, total_tokens}.
    """
    rows = conn.execute(
        """
        SELECT
            agent,
            COUNT(*) as session_count,
            MAX(ended_at) as last_active,
            COALESCE(SUM(input_tokens + output_tokens), 0) as total_tokens,
            COALESCE(SUM(tool_call_count), 0) as total_tool_calls,
            COUNT(DISTINCT project_key) as project_count
        FROM sessions
        GROUP BY agent
        ORDER BY MAX(ended_at) DESC
        """
    ).fetchall()
    return [dict(r) for r in rows]


def search_sessions(
    conn: sqlite3.Connection,
    query: str,
    limit: int = 50,
) -> list[SessionSummary]:
    """Search sessions by title, project, or model."""
    q = f"%{query}%"
    rows = conn.execute(
        """
        SELECT * FROM sessions
        WHERE title LIKE ? OR project_key LIKE ? OR project_name LIKE ? OR model LIKE ?
        ORDER BY ended_at DESC
        LIMIT ?
        """,
        (q, q, q, q, limit),
    ).fetchall()
    return [_row_to_summary(r) for r in rows]


# ─── Helpers ───────────────────────────────────────────────────────────────


def _row_to_summary(row: sqlite3.Row) -> SessionSummary:
    """Convert a DB row to SessionSummary."""
    return SessionSummary(
        agent=row["agent"],
        session_id=row["session_id"],
        title=row["title"],
        project_key=row["project_key"],
        project_name=row["project_name"],
        cwd=row["cwd"],
        started_at=row["started_at"],
        ended_at=row["ended_at"],
        duration_seconds=row["duration_seconds"],
        model=row["model"],
        git_branch=row["git_branch"],
        source=row["source"],
        user_message_count=row["user_message_count"],
        assistant_message_count=row["assistant_message_count"],
        tool_call_count=row["tool_call_count"],
        input_tokens=row["input_tokens"],
        output_tokens=row["output_tokens"],
        cached_input_tokens=row["cached_input_tokens"],
        cached_output_tokens=row["cached_output_tokens"],
    )
