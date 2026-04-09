"""FastMCP Server Template"""

from fastmcp import FastMCP

mcp = FastMCP(
    "template-mcp",
    description="FastMCP service template"
)


@mcp.tool()
async def example_tool(param: str) -> dict:
    """
    Example tool template.

    Args:
        param: Parameter description

    Returns:
        dict with structure:
        {
            "result": str,
            "status": str
        }
    """
    return {
        "result": f"Processed: {param}",
        "status": "success"
    }


@mcp.tool()
async def health_check() -> dict:
    """Check if service is healthy."""
    return {
        "healthy": True,
        "service": "template-mcp"
    }


if __name__ == "__main__":
    mcp.run()
