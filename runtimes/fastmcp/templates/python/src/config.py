"""Configuration Template"""

import os
from typing import Optional


def get_config() -> dict:
    """Get configuration from environment."""
    return {
        "base_url": os.environ.get("SERVICE_BASE_URL", "http://localhost:8888"),
        "timeout": float(os.environ.get("SERVICE_TIMEOUT", "30.0")),
        "port": int(os.environ.get("SERVICE_PORT", "8888")),
        "log_level": os.environ.get("SERVICE_LOG_LEVEL", "INFO"),
    }
