"""FastMCP Gateway - 统一 MCP 服务入口

将所有 MCP 服务聚合到一个统一的 FastMCP 服务器中
"""

import logging
import os
import sys
from pathlib import Path

from fastmcp import FastMCP

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# 创建统一的 MCP 服务器
mcp = FastMCP("agent-skills-mcp")


def register_service(name: str, service_module: str) -> None:
    """注册 MCP 服务

    Args:
        name: 服务名称
        service_module: 服务模块路径（如 "runtimes.fastmcp.searxng.src.server"）
    """
    try:
        module = __import__(service_module, fromlist=[""])
        service_mcp = getattr(module, "mcp", None)
        if not service_mcp:
            logger.warning(f"Service {name} has no 'mcp' instance, skipping...")
            return

        # 获取服务中的所有 tool
        tools = getattr(service_mcp, "_tools", {})
        for tool_name, tool_fn in tools.items():
            prefixed_name = f"{name}_{tool_name}"
            mcp.tool()(tool_fn)
            logger.info(f"Registered tool: {prefixed_name}")

    except ImportError as e:
        logger.warning(f"Failed to import service {name}: {e}")
    except Exception as e:
        logger.error(f"Failed to register service {name}: {e}")


def discover_services() -> list[tuple[str, str]]:
    """自动发现 MCP 服务

    扫描 runtimes/fastmcp/*/ 目录下的 MCP 服务
    返回：[(service_name, module_path), ...]
    """
    services = []
    fastmcp_dir = Path(__file__).parent.parent

    for service_dir in fastmcp_dir.iterdir():
        # 跳过非服务目录
        if not service_dir.is_dir():
            continue
        if service_dir.name.startswith(".") or service_dir.name in ["gateway", "shared", "templates"]:
            continue

        # 检查是否有 server.py
        server_py = service_dir / "src" / "server.py"
        if not server_py.exists():
            continue

        service_name = service_dir.name
        module_path = f"runtimes.fastmcp.{service_name}.src.server"
        services.append((service_name, module_path))

    return services


def main():
    """主入口"""
    logger.info("Starting Agent Skills MCP Gateway...")

    # 自动发现服务
    services = discover_services()

    # 手动注册特定服务（调试用）
    # services = [
    #     ("searxng", "runtimes.fastmcp.searxng.src.server"),
    # ]

    # 注册所有服务
    for service_name, module_path in services:
        register_service(service_name, module_path)

    # 启动服务器
    port = int(os.getenv("MCP_PORT", "18080"))
    logger.info(f"Starting HTTP server on http://0.0.0.0:{port}")
    import asyncio
    asyncio.run(mcp.run_http_async(host="0.0.0.0", port=port, transport="streamable-http"))


if __name__ == "__main__":
    main()
