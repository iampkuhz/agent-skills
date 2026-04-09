"""Crawl4AI MCP Schema (Placeholder)"""

from pydantic import BaseModel, Field
from typing import Optional, List


class FetchUrlInput(BaseModel):
    """Input schema for fetch_url tool"""
    url: str = Field(..., description="URL to fetch")
    wait: int = Field(default=0, ge=0, le=30, description="Wait time in seconds")
    screenshot: bool = Field(default=False, description="Whether to take a screenshot")


class FetchUrlOutput(BaseModel):
    """Output schema for fetch_url tool"""
    url: str = Field(..., description="Fetched URL")
    title: str = Field(..., description="Page title")
    content: str = Field(..., description="Cleaned page content")
    status: int = Field(..., description="HTTP status code")
    links: List[str] = Field(default_factory=list, description="Links found on page")
