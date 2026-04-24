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
    cached_output_tokens: int = 0  # cache_creation_input_tokens (write cache)
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
    content_html: str = ""  # pre-rendered markdown HTML
    token_ratio: float = 0  # proportion of session tokens used in this message


@dataclass
class ConversationRound:
    """One exchange: user message + assistant response + tool calls."""

    user_msg: ChatMessage
    assistant_msg: ChatMessage
    tool_calls: list[ToolCall] = field(default_factory=list)
    total_tokens: int = 0
    token_ratio: float = 0  # proportion of total session tokens

    @property
    def input_tokens(self) -> int:
        if self.assistant_msg.usage:
            return self.assistant_msg.usage.get("input_tokens", 0)
        return 0

    @property
    def output_tokens(self) -> int:
        if self.assistant_msg.usage:
            return self.assistant_msg.usage.get("output_tokens", 0)
        return 0

    @property
    def cached_tokens(self) -> int:
        if self.assistant_msg.usage:
            return self.assistant_msg.usage.get("cache_read_input_tokens", 0)
        return 0

    @property
    def cache_write_tokens(self) -> int:
        """cache_creation_input_tokens: tokens being written to cache this turn."""
        if self.assistant_msg.usage:
            return self.assistant_msg.usage.get("cache_creation_input_tokens", 0)
        return 0

    def token_breakdown(self) -> dict:
        """Return a dict of token categories for this round."""
        if not self.assistant_msg.usage:
            return {"input": 0, "cache_read": 0, "cache_write": 0, "output": 0}
        return {
            "input": self.assistant_msg.usage.get("input_tokens", 0),
            "cache_read": self.assistant_msg.usage.get("cache_read_input_tokens", 0),
            "cache_write": self.assistant_msg.usage.get("cache_creation_input_tokens", 0),
            "output": self.assistant_msg.usage.get("output_tokens", 0),
        }


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
