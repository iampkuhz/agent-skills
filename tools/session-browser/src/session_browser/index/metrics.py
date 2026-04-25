"""Metrics aggregation utilities for session-browser."""

from __future__ import annotations

from dataclasses import dataclass
import sqlite3


@dataclass
class TokenBreakdown:
    """Token usage breakdown across all sessions."""

    total_input: int = 0
    total_output: int = 0
    total_cached_input: int = 0  # cache read
    total_cached_output: int = 0  # cache write
    total_tool_calls: int = 0
    total_failed_tools: int = 0


@dataclass
class ModelDistribution:
    """Count of sessions per model."""

    distribution: dict[str, int] = None

    def __post_init__(self):
        if self.distribution is None:
            self.distribution = {}


def get_token_breakdown(conn: sqlite3.Connection) -> TokenBreakdown:
    """Get total token usage across all indexed sessions."""
    row = conn.execute(
        """
        SELECT
            COALESCE(SUM(input_tokens), 0) as total_input,
            COALESCE(SUM(output_tokens), 0) as total_output,
            COALESCE(SUM(cached_input_tokens), 0) as total_cached_input,
            COALESCE(SUM(cached_output_tokens), 0) as total_cached_output,
            COALESCE(SUM(tool_call_count), 0) as total_tool_calls,
            COALESCE(SUM(failed_tool_count), 0) as total_failed_tools
        FROM sessions
        """
    ).fetchone()
    return TokenBreakdown(
        total_input=row[0],
        total_output=row[1],
        total_cached_input=row[2],
        total_cached_output=row[3],
        total_tool_calls=row[4],
        total_failed_tools=row[5],
    )


def get_model_distribution(conn: sqlite3.Connection) -> ModelDistribution:
    """Get session count per model."""
    rows = conn.execute(
        """
        SELECT model, COUNT(*) as cnt
        FROM sessions
        WHERE model != ''
        GROUP BY model
        ORDER BY cnt DESC
        """
    ).fetchall()
    return ModelDistribution(
        distribution={r[0]: r[1] for r in rows}
    )


def get_agent_distribution(conn: sqlite3.Connection) -> dict[str, int]:
    """Get session count per agent type."""
    rows = conn.execute(
        """
        SELECT agent, COUNT(*) as cnt
        FROM sessions
        GROUP BY agent
        ORDER BY cnt DESC
        """
    ).fetchall()
    return {r[0]: r[1] for r in rows}


def get_tool_distribution(conn: sqlite3.Connection) -> dict[str, int]:
    """Get total tool call count per session (top sessions by tool usage).

    This returns per-session tool counts, not per-tool-name counts.
    Per-tool-name breakdown requires parsing raw events.
    """
    rows = conn.execute(
        """
        SELECT session_key, title, tool_call_count
        FROM sessions
        WHERE tool_call_count > 0
        ORDER BY tool_call_count DESC
        LIMIT 20
        """
    ).fetchall()
    return {r[0]: {"title": r[1], "tool_call_count": r[2]} for r in rows}


def get_top_projects_by_tokens(conn: sqlite3.Connection, limit: int = 10) -> list[dict]:
    """Get top projects by total token usage."""
    rows = conn.execute(
        """
        SELECT
            project_key,
            project_name,
            COALESCE(SUM(input_tokens + output_tokens + cached_input_tokens + cached_output_tokens), 0) as total_tokens,
            COUNT(*) as session_count
        FROM sessions
        GROUP BY project_key
        ORDER BY total_tokens DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()
    return [dict(r) for r in rows]


def get_top_projects_by_tools(conn: sqlite3.Connection, limit: int = 10) -> list[dict]:
    """Get top projects by tool call count."""
    rows = conn.execute(
        """
        SELECT
            project_key,
            project_name,
            COALESCE(SUM(tool_call_count), 0) as total_tools,
            COALESCE(SUM(failed_tool_count), 0) as failed_tools,
            COUNT(*) as session_count
        FROM sessions
        GROUP BY project_key
        ORDER BY total_tools DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()
    return [dict(r) for r in rows]


def get_slowest_sessions(conn: sqlite3.Connection, limit: int = 10) -> list[dict]:
    """Get sessions with longest duration."""
    rows = conn.execute(
        """
        SELECT session_key, title, agent, model, duration_seconds, project_name
        FROM sessions
        WHERE duration_seconds > 0
        ORDER BY duration_seconds DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()
    return [dict(r) for r in rows]


def get_failed_tool_sessions(conn: sqlite3.Connection, limit: int = 10) -> list[dict]:
    """Get sessions with failed tool calls."""
    rows = conn.execute(
        """
        SELECT session_key, title, agent, model, failed_tool_count, project_name
        FROM sessions
        WHERE failed_tool_count > 0
        ORDER BY failed_tool_count DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()
    return [dict(r) for r in rows]


def get_high_cache_read_sessions(conn: sqlite3.Connection, limit: int = 10) -> list[dict]:
    """Get sessions with highest cache read ratio."""
    rows = conn.execute(
        """
        SELECT
            session_key,
            title,
            agent,
            model,
            cached_input_tokens,
            input_tokens,
            project_name,
            CASE
                WHEN input_tokens + cached_input_tokens > 0
                THEN ROUND(100.0 * cached_input_tokens / (input_tokens + cached_input_tokens), 1)
                ELSE 0
            END as cache_hit_pct
        FROM sessions
        WHERE cached_input_tokens > 0
        ORDER BY cache_hit_pct DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()
    return [dict(r) for r in rows]
