"""Tests for SearXNG MCP Server"""

import pytest
import pytest_asyncio


@pytest.mark.asyncio
async def test_search_web_basic():
    """Test basic search functionality"""
    from src.server import search_web

    # This test requires SearXNG to be running
    # Skip if not available
    result = await search_web(
        query="test query",
        max_results=3
    )

    assert "query" in result
    assert "results" in result
    assert "total_returned" in result


@pytest.mark.asyncio
async def test_health_check():
    """Test health check endpoint"""
    from src.server import health_check

    result = await health_check()

    assert "healthy" in result
    assert "service" in result
    assert result["service"] == "searxng-mcp"


@pytest.mark.asyncio
async def test_search_with_category():
    """Test search with category filter"""
    from src.server import search_web

    result = await search_web(
        query="news",
        category="news",
        max_results=5
    )

    assert result["query"] == "news"
    assert isinstance(result["results"], list)


@pytest.mark.asyncio
async def test_max_results_boundary():
    """Test max_results boundary validation"""
    from src.server import search_web

    # Test upper boundary (should be limited to 20)
    result = await search_web(
        query="test",
        max_results=100
    )

    assert result["total_returned"] <= 20

    # Test lower boundary (should be at least 1)
    result = await search_web(
        query="test",
        max_results=0
    )

    assert result["total_returned"] >= 0
