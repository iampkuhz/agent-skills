"""Data Schemas for SearXNG MCP"""

from pydantic import BaseModel, Field
from typing import Optional, List


class SearchResult(BaseModel):
    """A single search result"""
    title: str = Field(..., description="Result title")
    url: str = Field(..., description="Result URL")
    snippet: str = Field(..., description="Result snippet/description")
    engine: str = Field(..., description="Source engine (google, bing, etc.)")


class SearchInput(BaseModel):
    """Search input schema"""
    query: str = Field(..., description="Search query string")
    category: Optional[str] = Field(default="general", description="Search category (general, images, news, etc.)")
    max_results: int = Field(default=8, ge=1, le=20, description="Maximum number of results (1-20)")
    language: Optional[str] = Field(default=None, description="Language code (e.g., zh-CN, en)")
    time_range: Optional[str] = Field(default=None, description="Time range (day, week, month, year)")


class SearchOutput(BaseModel):
    """Search output schema"""
    query: str = Field(..., description="Original query")
    results: List[SearchResult] = Field(default_factory=list, description="List of search results")
    total_returned: int = Field(..., description="Total number of results returned")
