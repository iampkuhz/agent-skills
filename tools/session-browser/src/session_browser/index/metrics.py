"""Metrics aggregation utilities for session-browser."""

from __future__ import annotations

from dataclasses import dataclass
import sqlite3


@dataclass
class TokenBreakdown:
    """Token usage breakdown across all sessions."""

    total_input: int = 0
    total_output: int = 0
    total_cached: int = 0
    total_tool_calls: int = 0


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
            COALESCE(SUM(cached_input_tokens), 0) as total_cached,
            COALESCE(SUM(tool_call_count), 0) as total_tool_calls
        FROM sessions
        """
    ).fetchone()
    return TokenBreakdown(
        total_input=row[0],
        total_output=row[1],
        total_cached=row[2],
        total_tool_calls=row[3],
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
