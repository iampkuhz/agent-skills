"""Tests for Claude Code parser."""

import json
from pathlib import Path

FIXTURES = Path(__file__).parent.parent / "fixtures"


def test_parse_session_events():
    """Test that we can parse Claude session events."""
    from session_browser.sources.claude import _parse_session_events

    fixture = FIXTURES / "claude_session_sample.jsonl"
    events = _parse_session_events(fixture)
    assert len(events) > 0

    types = {ev.get("type") for ev in events}
    assert "user" in types
    assert "assistant" in types


def test_build_summary_from_events():
    """Test summary building from events."""
    from session_browser.sources.claude import (
        _parse_session_events,
        _build_summary_from_events,
    )

    fixture = FIXTURES / "claude_session_sample.jsonl"
    events = _parse_session_events(fixture)
    summary = _build_summary_from_events(events, "test-session-id", "/test/project")

    assert summary.agent == "claude_code"
    assert summary.session_id == "test-session-id"
    assert summary.user_message_count >= 1
    assert summary.project_name == "project"


def test_extract_messages():
    """Test message extraction."""
    from session_browser.sources.claude import (
        _parse_session_events,
        _extract_messages,
    )

    fixture = FIXTURES / "claude_session_sample.jsonl"
    events = _parse_session_events(fixture)
    messages = _extract_messages(events)

    user_msgs = [m for m in messages if m.role == "user"]
    assert len(user_msgs) >= 1
    assert user_msgs[0].content != ""


def test_parse_history_empty_when_missing():
    """Test that parse_history returns empty list when no data dir."""
    from session_browser.sources import claude
    import tempfile
    import os

    # Temporarily override _claude_dir to a non-existent path
    with tempfile.TemporaryDirectory() as tmpdir:
        original = claude._claude_dir
        claude._claude_dir = lambda: Path(tmpdir)
        try:
            result = claude.parse_history()
            assert result == []
        finally:
            claude._claude_dir = original
