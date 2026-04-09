"""FastMCP Runtime - MCP 服务框架

提供：
- 统一的配置管理
- 端口分配和冲突检测
- 共享工具函数
- 服务运行器
"""

from .runtime import MCPRuntime, create_mcp, run_service
from .shared.config import MCPServiceConfig
from .shared.common import setup_logger, truncate_text, sanitize_service_name

__all__ = [
    "MCPRuntime",
    "create_mcp",
    "run_service",
    "MCPServiceConfig",
    "setup_logger",
    "truncate_text",
    "sanitize_service_name",
]
