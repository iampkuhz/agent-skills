"""FastMCP Server Template

使用统一的 runtime 框架启动服务
"""

from runtimes.fastmcp import create_mcp

# 创建 MCP 实例
mcp = create_mcp("template-mcp")


@mcp.tool()
async def example_tool(query: str) -> dict:
    """示例工具

    Args:
        query: 查询字符串

    Returns:
        处理结果
    """
    return {
        "result": f"Processed: {query}",
        "status": "success",
    }


@mcp.tool()
async def health_check() -> dict:
    """健康检查"""
    return {
        "healthy": True,
        "service": "template-mcp",
    }


# 启动入口 - 使用统一的 runtime
if __name__ == "__main__":
    from runtimes.fastmcp import run_service
    run_service("template-mcp", __name__)
