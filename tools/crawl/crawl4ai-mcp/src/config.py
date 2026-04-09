"""Crawl4AI MCP Config (Placeholder)"""

import os


def get_config() -> dict:
    """Get Crawl4AI MCP configuration from environment."""
    return {
        "base_url": os.environ.get("CRAWL4AI_BASE_URL", "http://localhost:8888"),
        "timeout": float(os.environ.get("CRAWL4AI_TIMEOUT", "60.0")),
        "port": int(os.environ.get("CRAWL4AI_MCP_PORT", "8889")),
        "log_level": os.environ.get("CRAWL4AI_MCP_LOG_LEVEL", "INFO"),
    }
