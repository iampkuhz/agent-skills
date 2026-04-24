"""Configuration for session-browser.

All paths are configurable via environment variables for container compatibility.
Defaults point to the current user's home directory on macOS/Linux.
"""

from __future__ import annotations

import os
from pathlib import Path


def _home() -> Path:
    return Path.home()


# ─── Data source paths ──────────────────────────────────────────────────

# Base directories for agent session data
CLAUDE_DATA_DIR = Path(os.environ.get("CLAUDE_DATA_DIR", str(_home() / ".claude")))
CODEX_DATA_DIR = Path(os.environ.get("CODEX_DATA_DIR", str(_home() / ".codex")))


# ─── Index storage ───────────────────────────────────────────────────────

# SQLite index file location
INDEX_DIR = Path(os.environ.get("INDEX_DIR", str(_home() / ".cache" / "agent-session-browser")))
INDEX_PATH = INDEX_DIR / "index.sqlite"


def ensure_index_dir() -> None:
    INDEX_DIR.mkdir(parents=True, exist_ok=True)


# ─── Server ──────────────────────────────────────────────────────────────

SERVER_HOST = os.environ.get("SERVER_HOST", "0.0.0.0")
SERVER_PORT = int(os.environ.get("SERVER_PORT", "8899"))
