"""Domain models for session-browser."""

from __future__ import annotations

from dataclasses import dataclass, field, asdict
from typing import Optional
from datetime import datetime, timezone


@dataclass
class SessionSummary:
    """Unified session index model for both Claude Code and Codex."""

    agent: str  # "claude_code" | "codex"
    session_id: str
    title: str
    project_key: str  # full normalized path
    project_name: str  # last path segment
    cwd: str
    started_at: str  # ISO8601
    ended_at: str  # ISO8601
    duration_seconds: float = 0
    model: str = ""
    git_branch: str = ""
    source: str = ""  # "cli" | "vscode" | ...
    user_message_count: int = 0
    assistant_message_count: int = 0
    tool_call_count: int = 0
    input_tokens: int = 0
    output_tokens: int = 0
    cached_input_tokens: int = 0
    has_sensitive_data: bool = True

    @property
    def session_key(self) -> str:
        return f"{self.agent}:{self.session_id}"

    def to_dict(self) -> dict:
        d = asdict(self)
        d["session_key"] = self.session_key
        return d


@dataclass
class ChatMessage:
    """A single chat message (user or assistant) in a session."""

    role: str  # "user" | "assistant"
    content: str
    timestamp: str  # ISO8601
    model: str = ""
    tool_calls: list[dict] = field(default_factory=list)  # for assistant messages
    usage: Optional[dict] = None  # token usage for assistant messages


@dataclass
class ToolCall:
    """A tool invocation record."""

    name: str
    parameters: dict = field(default_factory=dict)
    result: str = ""
    status: str = "completed"  # "completed" | "error"
    duration_ms: float = 0
    timestamp: str = ""


@dataclass
class ProjectStats:
    """Aggregated statistics for a project."""

    project_key: str
    project_name: str
    total_sessions: int = 0
    claude_sessions: int = 0
    codex_sessions: int = 0
    first_seen: str = ""
    last_seen: str = ""
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    total_cached_tokens: int = 0
    total_tool_calls: int = 0
    total_user_messages: int = 0
    total_assistant_messages: int = 0
