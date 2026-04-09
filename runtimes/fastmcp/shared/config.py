"""Configuration conventions for FastMCP services"""

import os
from typing import Optional
from functools import lru_cache


class BaseConfig:
    """Base configuration class"""

    @classmethod
    def from_env(cls, prefix: str = "") -> dict:
        """Load configuration from environment variables"""
        config = {}
        for key, value in cls.__dict__.items():
            if not key.startswith("_") and isinstance(value, (str, int, float, bool, type(None))):
                env_key = f"{prefix}{key.upper()}"
                config[key] = os.environ.get(env_key, value)
        return config


@lru_cache()
def get_service_config(service_name: str) -> dict:
    """Get service-specific configuration"""
    prefix = f"{service_name.upper()}_"
    return {
        "host": os.environ.get(f"{prefix}HOST", "localhost"),
        "port": int(os.environ.get(f"{prefix}PORT", "8888")),
        "timeout": float(os.environ.get(f"{prefix}TIMEOUT", "30.0")),
        "log_level": os.environ.get(f"{prefix}LOG_LEVEL", "INFO"),
    }
