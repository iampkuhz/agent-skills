"""Parser for Claude Code local session data.

Data sources:
- ~/.claude/history.jsonl: session index (sessionId, project, display, timestamp)
- ~/.claude/projects/{project}/{sessionId}.jsonl: full conversation event stream
- ~/.claude/sessions/{pid}.json: active session metadata (optional)

All paths configurable via CLAUDE_DATA_DIR env var.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterator

from session_browser.config import CLAUDE_DATA_DIR
from session_browser.domain.models import SessionSummary, ChatMessage, ToolCall


def parse_history() -> list[dict]:
    """Parse ~/.claude/history.jsonl and return raw session index entries.

    Returns list of dicts with: session_id, project, display, timestamp
    """
    path = CLAUDE_DATA_DIR / "history.jsonl"
    if not path.exists():
        return []

    entries = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                entries.append({
                    "session_id": obj.get("sessionId", ""),
                    "project": obj.get("project", ""),
                    "display": obj.get("display", ""),
                    "timestamp": obj.get("timestamp", 0),
                })
            except json.JSONDecodeError:
                continue
    return entries


def _ts_ms_to_iso(ts_ms: int | float) -> str:
    """Convert millisecond timestamp to ISO8601 string."""
    if not ts_ms:
        return ""
    from datetime import datetime, timezone
    dt = datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc)
    return dt.isoformat()


def _ts_to_iso(ts: int | float) -> str:
    """Convert second timestamp to ISO8601 string."""
    if not ts:
        return ""
    from datetime import datetime, timezone
    dt = datetime.fromtimestamp(ts, tz=timezone.utc)
    return dt.isoformat()


def _parse_session_events(path: Path) -> list[dict]:
    """Parse a single session .jsonl event stream file.

    Returns list of raw event dicts, filtered to relevant types.
    """
    events = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                events.append(obj)
            except json.JSONDecodeError:
                continue
    return events


def parse_session_detail(
    project_key: str,
    session_id: str,
) -> tuple[SessionSummary, list[ChatMessage], list[ToolCall]]:
    """Parse a single Claude session's full event stream.

    Returns (SessionSummary, chat_messages, tool_calls).
    """
    # Locate the session file
    project_dir = CLAUDE_DATA_DIR / "projects" / _normalize_project_segment(project_key)
    session_file = project_dir / f"{session_id}.jsonl"
    if not session_file.exists():
        # Try to find it by scanning
        session_file = _find_session_file(project_key, session_id)
        if session_file is None:
            return _empty_session(session_id, project_key), [], []

    events = _parse_session_events(session_file)

    summary = _build_summary_from_events(events, session_id, project_key)
    messages = _extract_messages(events)
    tool_calls = _extract_tool_calls(events, messages)

    return summary, messages, tool_calls


def _normalize_project_segment(project_key: str) -> str:
    """Convert a full project path to the directory name used in ~/.claude/projects/."""
    if not project_key:
        return ""
    # The projects directory uses a URL-encoded style of the full path
    # For now, return as-is; the actual mapping is 1:1 with path segments
    return project_key


def _find_session_file(project_key: str, session_id: str) -> Path | None:
    """Search for a session file under projects/."""
    projects_dir = CLAUDE_DATA_DIR / "projects"
    if not projects_dir.exists():
        return None

    # Try direct match
    candidate = projects_dir / project_key / f"{session_id}.jsonl"
    if candidate.exists():
        return candidate

    # Search all project directories
    for proj_dir in projects_dir.iterdir():
        if not proj_dir.is_dir():
            continue
        candidate = proj_dir / f"{session_id}.jsonl"
        if candidate.exists():
            return candidate
    return None


def _empty_session(session_id: str, project_key: str) -> SessionSummary:
    """Create an empty session summary as fallback."""
    from pathlib import PurePosixPath
    project_name = PurePosixPath(project_key).name if project_key else "unknown"
    return SessionSummary(
        agent="claude_code",
        session_id=session_id,
        title="",
        project_key=project_key,
        project_name=project_name,
        cwd="",
        started_at="",
        ended_at="",
    )


def _build_summary_from_events(
    events: list[dict],
    session_id: str,
    project_key: str,
) -> SessionSummary:
    """Build SessionSummary from parsed Claude events."""
    from pathlib import PurePosixPath

    user_count = 0
    assistant_count = 0
    tool_count = 0
    input_tokens = 0
    output_tokens = 0
    cached_tokens = 0
    model = ""
    cwd = ""
    git_branch = ""
    source = ""
    first_ts = 0
    last_ts = 0
    title = ""

    for ev in events:
        etype = ev.get("type", "")

        if etype == "user":
            user_count += 1
            ts_str = ev.get("timestamp", "")
            if ts_str and not first_ts:
                from datetime import datetime
                try:
                    dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                    first_ts = int(dt.timestamp() * 1000)
                except (ValueError, TypeError):
                    pass
            # Get title from first user message
            if not title:
                msg = ev.get("message", {})
                if isinstance(msg, dict):
                    content = msg.get("content", "")
                    if isinstance(content, str):
                        title = content[:120]
                    elif isinstance(content, list):
                        for item in content:
                            if isinstance(item, dict) and item.get("type") == "text":
                                title = item.get("text", "")[:120]
                                break
            if not cwd:
                cwd = ev.get("cwd", "")
            if not source:
                source = ev.get("entrypoint", "")
            if not git_branch:
                git_branch = ev.get("gitBranch", "")

        elif etype == "assistant":
            assistant_count += 1
            msg = ev.get("message", {})
            if isinstance(msg, dict):
                if not model:
                    model = msg.get("model", "")
                usage = msg.get("usage", {})
                if isinstance(usage, dict):
                    input_tokens += usage.get("input_tokens", 0)
                    output_tokens += usage.get("output_tokens", 0)
                    cached_tokens += usage.get("cache_read_input_tokens", 0)
                # Count tool_use in content
                content = msg.get("content", [])
                if isinstance(content, list):
                    for item in content:
                        if isinstance(item, dict) and item.get("type") == "tool_use":
                            tool_count += 1

        ts_str = ev.get("timestamp", "")
        if ts_str:
            from datetime import datetime
            try:
                dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                last_ts = int(dt.timestamp() * 1000)
            except (ValueError, TypeError):
                pass

    if not last_ts and first_ts:
        last_ts = first_ts

    duration = 0
    if first_ts and last_ts:
        duration = (last_ts - first_ts) / 1000

    project_name = PurePosixPath(project_key).name if project_key else "unknown"

    return SessionSummary(
        agent="claude_code",
        session_id=session_id,
        title=title,
        project_key=project_key,
        project_name=project_name,
        cwd=cwd,
        started_at=_ts_ms_to_iso(first_ts) if first_ts else "",
        ended_at=_ts_ms_to_iso(last_ts) if last_ts else "",
        duration_seconds=round(duration, 1),
        model=model,
        git_branch=git_branch,
        source=source,
        user_message_count=user_count,
        assistant_message_count=assistant_count,
        tool_call_count=tool_count,
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        cached_input_tokens=cached_tokens,
    )


def _extract_messages(events: list[dict]) -> list[ChatMessage]:
    """Extract user and assistant chat messages from Claude events."""
    messages = []
    for ev in events:
        etype = ev.get("type", "")

        if etype == "user":
            msg = ev.get("message", {})
            content = ""
            if isinstance(msg, dict):
                c = msg.get("content", "")
                if isinstance(c, str):
                    content = c
                elif isinstance(c, list):
                    parts = []
                    for item in c:
                        if isinstance(item, dict) and item.get("type") == "text":
                            parts.append(item.get("text", ""))
                    content = "\n".join(parts)
            ts_str = ev.get("timestamp", "")
            messages.append(ChatMessage(
                role="user",
                content=content,
                timestamp=ts_str,
            ))

        elif etype == "assistant":
            msg = ev.get("message", {})
            if not isinstance(msg, dict):
                continue
            model = msg.get("model", "")
            content_parts = msg.get("content", [])
            text_parts = []
            tool_calls = []
            if isinstance(content_parts, list):
                for item in content_parts:
                    if isinstance(item, dict):
                        if item.get("type") == "text":
                            text_parts.append(item.get("text", ""))
                        elif item.get("type") == "tool_use":
                            tool_calls.append({
                                "name": item.get("name", ""),
                                "parameters": item.get("input", {}),
                            })
            usage = msg.get("usage")
            ts_str = ev.get("timestamp", "")
            if text_parts or tool_calls:
                messages.append(ChatMessage(
                    role="assistant",
                    content="\n".join(text_parts),
                    timestamp=ts_str,
                    model=model,
                    tool_calls=tool_calls,
                    usage=usage if isinstance(usage, dict) else None,
                ))

    return messages


def _extract_tool_calls(
    events: list[dict],
    messages: list[ChatMessage],
) -> list[ToolCall]:
    """Extract tool call records from assistant messages.

    Note: For Claude Code, tool call duration is not directly available
    in the event stream. We compute it from consecutive message timestamps.
    """
    tool_calls = []
    for msg in messages:
        if msg.role != "assistant":
            continue
        for tc in msg.tool_calls:
            tool_calls.append(ToolCall(
                name=tc.get("name", ""),
                parameters=tc.get("parameters", {}),
                timestamp=msg.timestamp,
            ))
    return tool_calls


def scan_all_sessions() -> Iterator[SessionSummary]:
    """Scan all Claude sessions and yield SessionSummary for each.

    This is the main entry point for the indexer.
    It reads history.jsonl for the session list, then parses each session file.
    """
    history = parse_history()

    # Group by project
    # session_id -> project mapping
    session_projects = {}
    for entry in history:
        session_projects[entry["session_id"]] = entry["project"]

    for entry in history:
        sid = entry["session_id"]
        project = entry["project"]
        summary, _msgs, _tcs = parse_session_detail(project, sid)
        # Ensure title from history if empty
        if not summary.title and entry.get("display"):
            summary.title = entry["display"][:120]
        yield summary
