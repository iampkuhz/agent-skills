"""SearXNG MCP Server - Web Search Tool for Claude Code"""

import os
from typing import Optional

from fastmcp import FastMCP

from .client import SearXNGClient
from .schema import SearchInput, SearchOutput, SearchResult

# Initialize FastMCP server
mcp = FastMCP(
    "searxng-mcp",
    description="SearXNG web search service for Claude Code"
)

# Global client instance
_client: Optional[SearXNGClient] = None


def get_client() -> SearXNGClient:
    """Get or create SearXNG client"""
    global _client
    if _client is None:
        base_url = os.environ.get("SEARXNG_BASE_URL", "http://localhost:8873")
        timeout = float(os.environ.get("SEARXNG_TIMEOUT", "30.0"))
        _client = SearXNGClient(base_url=base_url, timeout=timeout)
    return _client


@mcp.tool()
async def search_web(
    query: str,
    category: str = "general",
    max_results: int = 8,
    language: Optional[str] = None,
    time_range: Optional[str] = None
) -> dict:
    """
    Search the web using SearXNG metasearch engine.

    This tool aggregates results from multiple search engines (Google, Bing, DuckDuckGo, etc.)
    and returns standardized, deduplicated results.

    Args:
        query: The search query string (required)
        category: Search category - general, images, news, science, etc. (default: "general")
        max_results: Maximum number of results to return, 1-20 (default: 8)
        language: Language code like zh-CN, en, es, etc. (optional)
        time_range: Time range filter - day, week, month, year (optional)

    Returns:
        dict with structure:
        {
            "query": str,           # Original query
            "results": [            # List of search results
                {
                    "title": str,   # Result title
                    "url": str,     # Result URL
                    "snippet": str, # Result snippet/description
                    "engine": str   # Source engine (google, bing, etc.)
                }
            ],
            "total_returned": int   # Total number of results returned
        }

    Errors:
        - "SearXNG unreachable": Service is not running or network issue
        - "Invalid response": SearXNG returned malformed data
        - "No results": Query returned no results

    Example:
        search_web("Python async best practices", max_results=5)
        search_web("AI news", category="news", time_range="day")
        search_web("机器学习中", language="zh-CN")
    """
    # Validate max_results boundary
    max_results = max(1, min(20, max_results))

    client = get_client()

    try:
        results = await client.search(
            query=query,
            category=category if category else "general",
            max_results=max_results,
            language=language,
            time_range=time_range
        )

        if not results:
            return {
                "query": query,
                "results": [],
                "total_returned": 0,
                "_message": "No results found"
            }

        return {
            "query": query,
            "results": results,
            "total_returned": len(results)
        }

    except ConnectionError as e:
        return {
            "query": query,
            "results": [],
            "total_returned": 0,
            "_error": "SearXNG unreachable",
            "_details": str(e)
        }
    except TimeoutError as e:
        return {
            "query": query,
            "results": [],
            "total_returned": 0,
            "_error": "Request timeout",
            "_details": str(e)
        }
    except ValueError as e:
        return {
            "query": query,
            "results": [],
            "total_returned": 0,
            "_error": "Invalid response",
            "_details": str(e)
        }


@mcp.tool()
async def health_check() -> dict:
    """
    Check if SearXNG service is healthy.

    Returns:
        dict with structure:
        {
            "healthy": bool,        # True if service is healthy
            "service": str,         # Service name
            "endpoint": str         # SearXNG endpoint URL
        }
    """
    client = get_client()
    is_healthy = await client.health_check()

    return {
        "healthy": is_healthy,
        "service": "searxng-mcp",
        "endpoint": client.base_url
    }


# Lifecycle hooks
@mcp.lifecycle("startup")
async def startup():
    """Initialize client on startup"""
    global _client
    base_url = os.environ.get("SEARXNG_BASE_URL", "http://localhost:8873")
    timeout = float(os.environ.get("SEARXNG_TIMEOUT", "30.0"))
    _client = SearXNGClient(base_url=base_url, timeout=timeout)


@mcp.lifecycle("shutdown")
async def shutdown():
    """Cleanup client on shutdown"""
    global _client
    if _client:
        await _client.close()
        _client = None


if __name__ == "__main__":
    # Run with Streamable HTTP transport
    mcp.run()
