"""FastMCP Runtime - 核心运行器

提供统一的 MCP 服务启动和管理入口
"""

import asyncio
import importlib
import sys
from pathlib import Path
from typing import Optional

from fastmcp import FastMCP

from .shared.common import setup_logger, get_next_available_port, sanitize_service_name
from .shared.config import MCPServiceConfig, check_port_available, register_port

logger = setup_logger(__name__)


class MCPRuntime:
    """MCP 服务运行器

    统一管理 FastMCP 服务的生命周期
    """

    def __init__(
        self,
        name: str,
        server_module: Optional[str] = None,
        mcp_instance: Optional[FastMCP] = None,
    ):
        """初始化运行器

        Args:
            name: 服务名称（用于环境变量前缀）
            server_module: server.py 模块路径（如 "src.server"）
            mcp_instance: 直接传入 FastMCP 实例（可选）
        """
        self.name = name
        self.sanitized_name = sanitize_service_name(name)
        self.config = MCPServiceConfig.from_env(self.sanitized_name)
        self.mcp = mcp_instance

        # 如果传入模块路径，加载 mcp 实例
        if server_module and not mcp_instance:
            self.mcp = self._load_mcp_from_module(server_module)

        if not self.mcp:
            raise ValueError("Either server_module or mcp_instance must be provided")

    def _load_mcp_from_module(self, module_path: str) -> FastMCP:
        """从模块加载 FastMCP 实例

        约定：模块中必须有名为 'mcp' 的 FastMCP 实例
        """
        try:
            module = importlib.import_module(module_path)
            mcp = getattr(module, "mcp", None)
            if not mcp:
                raise AttributeError(f"Module {module_path} does not have 'mcp' attribute")
            return mcp
        except ImportError as e:
            logger.error(f"Failed to import module {module_path}: {e}")
            raise

    def run(self, transport: Optional[str] = None) -> None:
        """运行服务

        Args:
            transport: 传输模式（覆盖配置）
        """
        transport = transport or self.config.transport

        logger.info(f"Starting MCP service '{self.name}'")
        logger.info(f"  Host: {self.config.host}")
        logger.info(f"  Port: {self.config.port}")
        logger.info(f"  Transport: {transport}")
        logger.info(f"  Log Level: {self.config.log_level}")

        # 检查端口可用性
        if not check_port_available(self.config.port, self.name):
            logger.warning(f"Port {self.config.port} is in use, finding alternative...")
            self.config.port = get_next_available_port(self.config.port)
            logger.info(f"  Using alternative port: {self.config.port}")

        # 注册端口
        register_port(self.name, self.config.port)

        # 运行
        if transport in ("http", "streamable-http"):
            asyncio.run(self._run_http(transport))
        elif transport == "stdio":
            self.mcp.run()
        else:
            logger.error(f"Unknown transport: {transport}")
            sys.exit(1)

    async def _run_http(self, transport: str) -> None:
        """HTTP 模式运行"""
        await self.mcp.run_http_async(
            host=self.config.host,
            port=self.config.port,
            transport=transport,
        )


def create_mcp(name: str) -> FastMCP:
    """创建 FastMCP 实例的辅助函数

    用法：
        from runtimes.fastmcp.runtime import create_mcp
        mcp = create_mcp("searxng-mcp")
    """
    return FastMCP(name)


# 便捷启动函数
def run_service(name: str, server_module: str) -> None:
    """快速启动 MCP 服务

    用法：
        from runtimes.fastmcp.runtime import run_service
        run_service("searxng-mcp", "src.server")
    """
    runtime = MCPRuntime(name=name, server_module=server_module)
    runtime.run()


# CLI 入口
def main():
    """命令行入口

    用法：
        python -m runtimes.fastmcp.runtime searxng-mcp src.server
    """
    if len(sys.argv) < 3:
        print("Usage: python -m runtimes.fastmcp.runtime <service-name> <server-module>")
        print("Example: python -m runtimes.fastmcp.runtime searxng-mcp src.server")
        sys.exit(1)

    service_name = sys.argv[1]
    server_module = sys.argv[2]

    run_service(service_name, server_module)


if __name__ == "__main__":
    main()
