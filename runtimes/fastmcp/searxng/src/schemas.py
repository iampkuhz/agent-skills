"""SearXNG MCP - 输入输出模型"""

from pydantic import BaseModel, Field


class SearchWebInput(BaseModel):
    """搜索输入参数"""
    query: str = Field(..., min_length=1, max_length=500)
    category: str = Field(default="general")
    max_results: int = Field(default=8, ge=1, le=20)
    language: str | None = Field(default=None)
    time_range: str | None = Field(default=None)


class SearchResultItem(BaseModel):
    """搜索结果项"""
    title: str
    url: str
    snippet: str
    engine: str


class SearchWebOutput(BaseModel):
    """搜索输出结果"""
    query: str
    results: list[SearchResultItem]
    total_returned: int
