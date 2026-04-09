"""Data Schemas - Template"""

from pydantic import BaseModel, Field
from typing import Optional


class TemplateInput(BaseModel):
    """Template input schema"""
    query: str = Field(..., description="Query string")
    max_results: int = Field(default=10, ge=1, le=100, description="Max results")
    category: Optional[str] = Field(default=None, description="Category filter")


class TemplateOutput(BaseModel):
    """Template output schema"""
    query: str
    results: list[dict]
    total_returned: int
