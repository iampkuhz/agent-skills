"""FastMCP Runtime - 共享工具函数"""

import logging
from typing import Optional


def setup_logger(
    name: str,
    level: str = "INFO",
    format_str: Optional[str] = None,
) -> logging.Logger:
    """Setup logger with consistent formatting

    Args:
        name: Logger name (usually __name__)
        level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        format_str: Custom format string (uses default if None)

    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level.upper(), logging.INFO))

    if not logger.handlers:
        handler = logging.StreamHandler()
        formatter = logging.Formatter(
            format_str or "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)

    return logger


def truncate_text(text: str, max_length: int = 500, suffix: str = "...") -> str:
    """Truncate text with ellipsis

    Args:
        text: Text to truncate
        max_length: Maximum length
        suffix: Suffix to append when truncated

    Returns:
        Truncated text
    """
    if len(text) <= max_length:
        return text
    return text[: max_length - len(suffix)] + suffix


def sanitize_service_name(name: str) -> str:
    """Sanitize service name for use in environment variables and file paths

    Args:
        name: Raw service name

    Returns:
        Sanitized name (uppercase, alphanumeric + underscore)
    """
    import re

    # Convert to uppercase and replace non-alphanumeric with underscore
    sanitized = re.sub(r"[^A-Z0-9]", "_", name.upper())
    # Remove leading/trailing underscores
    return sanitized.strip("_")


def get_next_available_port(start_port: int = 8000, max_ports: int = 100) -> int:
    """Get next available port starting from start_port

    Args:
        start_port: Starting port number
        max_ports: Maximum number of ports to check

    Returns:
        Available port number

    Raises:
        RuntimeError: If no available port found
    """
    import socket

    for port in range(start_port, start_port + max_ports):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                s.bind(("0.0.0.0", port))
                return port
            except OSError:
                continue

    raise RuntimeError(f"No available port in range {start_port}-{start_port + max_ports}")
