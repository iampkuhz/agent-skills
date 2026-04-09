"""FastMCP Gateway - 服务注册表

维护所有 MCP 服务的注册信息
"""

from typing import Optional


class ServiceRegistry:
    """MCP 服务注册表"""

    # 服务注册表
    # 格式：{service_name: {"module": module_path, "enabled": bool}}
    SERVICES: dict[str, dict] = {
        # 示例：
        # "searxng": {
        #     "module": "tools.search.searxng_mcp.src.server",
        #     "enabled": True,
        # },
        # "crawl4ai": {
        #     "module": "tools.crawl.crawl4ai_mcp.src.server",
        #     "enabled": True,
        # },
    }

    @classmethod
    def register(
        cls,
        name: str,
        module: str,
        enabled: bool = True,
    ) -> None:
        """注册服务

        Args:
            name: 服务名称（如 "searxng"）
            module: 模块路径（如 "tools.search.searxng_mcp.src.server"）
            enabled: 是否启用
        """
        cls.SERVICES[name] = {"module": module, "enabled": enabled}

    @classmethod
    def enable(cls, name: str) -> None:
        """启用服务"""
        if name in cls.SERVICES:
            cls.SERVICES[name]["enabled"] = True

    @classmethod
    def disable(cls, name: str) -> None:
        """禁用服务"""
        if name in cls.SERVICES:
            cls.SERVICES[name]["enabled"] = False

    @classmethod
    def get_enabled_services(cls) -> list[tuple[str, str]]:
        """获取所有启用的服务

        返回：[(name, module), ...]
        """
        return [
            (name, info["module"])
            for name, info in cls.SERVICES.items()
            if info["enabled"]
        ]


# 便捷函数
def register_service(name: str, module: str) -> None:
    """注册 MCP 服务"""
    ServiceRegistry.register(name, module)


def get_services() -> list[tuple[str, str]]:
    """获取所有启用的服务"""
    return ServiceRegistry.get_enabled_services()
