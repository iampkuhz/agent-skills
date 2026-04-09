"""SearXNG HTTP API 客户端"""

import logging
from typing import Any
import httpx

logger = logging.getLogger(__name__)


class SearXNGClient:
    """SearXNG HTTP 客户端"""
    
    def __init__(self, base_url: str, timeout: float = 10.0):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self._client = httpx.AsyncClient(timeout=httpx.Timeout(timeout), follow_redirects=True)
    
    async def search(
        self, query: str, category: str = "general", max_results: int = 8,
        language: str | None = None, time_range: str | None = None,
    ) -> list:
        """搜索"""
        params: dict[str, Any] = {"q": query, "format": "json", "categories": category, "pageno": 1}
        if language:
            params["language"] = language
        if time_range:
            params["time_range"] = time_range
        
        response = await self._client.get(f"{self.base_url}/search", params=params)
        response.raise_for_status()
        data = response.json()
        
        results = []
        for item in data.get("results", [])[:max_results]:
            results.append({
                "title": item.get("title", "No title"),
                "url": item.get("url", ""),
                "snippet": item.get("content", item.get("snippet", "No description")),
                "engine": item.get("engine", "unknown"),
            })
        return results
    
    async def close(self) -> None:
        await self._client.aclose()
