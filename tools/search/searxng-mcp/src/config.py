"""Configuration for SearXNG MCP"""

import os
from typing import Optional


def get_config() -> dict:
    """Load configuration from environment variables"""
    return {
        "host": os.environ.get("SEARXNG_MCP_HOST", "localhost"),
        "port": int(os.environ.get("SEARXNG_MCP_PORT", "8888")),
        "base_url": os.environ.get("SEARXNG_BASE_URL", "http://localhost:8873"),
        "timeout": float(os.environ.get("SEARXNG_TIMEOUT", "30.0")),
        "log_level": os.environ.get("SEARXNG_MCP_LOG_LEVEL", "INFO"),
        "transport": os.environ.get("SEARXNG_MCP_TRANSPORT", "stdio"),
    }
