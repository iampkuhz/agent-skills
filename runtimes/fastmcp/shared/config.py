"""FastMCP Runtime - 共享配置管理"""

import os
from typing import Optional
from functools import lru_cache
from pydantic import BaseModel, Field


class MCPServiceConfig(BaseModel):
    """MCP 服务配置模型"""

    name: str = Field(..., description="服务名称")
    host: str = Field(default="0.0.0.0", description="绑定地址")
    port: int = Field(default=8000, description="服务端口", ge=1024, le=65535)
    transport: str = Field(default="streamable-http", description="传输模式")
    log_level: str = Field(default="INFO", description="日志级别")
    timeout: float = Field(default=30.0, description="请求超时（秒）")

    @classmethod
    def from_env(cls, name: str) -> "MCPServiceConfig":
        """从环境变量加载配置

        环境变量命名规则：{NAME}_PORT, {NAME}_HOST 等
        例如：SEARXNG_PORT=8001, SEARXNG_HOST=0.0.0.0
        """
        prefix = name.upper().replace("-", "_")
        return cls(
            name=name,
            host=os.environ.get(f"{prefix}_HOST", "0.0.0.0"),
            port=int(os.environ.get(f"{prefix}_PORT", "8000")),
            transport=os.environ.get(f"{prefix}_TRANSPORT", "streamable-http"),
            log_level=os.environ.get(f"{prefix}_LOG_LEVEL", "INFO"),
            timeout=float(os.environ.get(f"{prefix}_TIMEOUT", "30.0")),
        )


@lru_cache()
def get_port_registry() -> dict[str, int]:
    """获取端口注册表

    注册已使用的端口，避免冲突
    返回：{service_name: port}
    """
    # 从配置文件或环境变量读取已注册的端口
    registry = {}

    # 读取已知的 MCP 服务端口注册
    port_file = os.path.expanduser("~/.claude/mcp_ports.json")
    if os.path.exists(port_file):
        import json
        try:
            with open(port_file) as f:
                registry = json.load(f)
        except Exception:
            pass

    return registry


def check_port_available(port: int, service_name: str) -> bool:
    """检查端口是否可用"""
    import socket

    # 检查是否被其他服务占用
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind(("0.0.0.0", port))
            return True
        except OSError:
            # 端口被占用，检查是否是同一个服务
            registry = get_port_registry()
            for name, registered_port in registry.items():
                if registered_port == port and name != service_name:
                    return False
            return True


def register_port(service_name: str, port: int) -> None:
    """注册服务端口"""
    port_file = os.path.expanduser("~/.claude/mcp_ports.json")
    os.makedirs(os.path.dirname(port_file), exist_ok=True)

    registry = get_port_registry()
    registry[service_name] = port

    import json
    with open(port_file, "w") as f:
        json.dump(registry, f, indent=2)
