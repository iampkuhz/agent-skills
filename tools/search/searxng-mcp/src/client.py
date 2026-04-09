"""SearXNG HTTP Client"""

import httpx
from typing import Optional, List
from urllib.parse import quote


class SearXNGClient:
    """SearXNG search API client"""

    def __init__(
        self,
        base_url: str = "http://localhost:8873",
        timeout: float = 30.0
    ):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self._client = httpx.AsyncClient(timeout=timeout, follow_redirects=True)

    async def close(self):
        """Close the HTTP client"""
        await self._client.aclose()

    async def search(
        self,
        query: str,
        category: Optional[str] = None,
        max_results: int = 8,
        language: Optional[str] = None,
        time_range: Optional[str] = None
    ) -> List[dict]:
        """
        Search using SearXNG API

        Args:
            query: Search query string
            category: Search category (general, images, news, etc.)
            max_results: Maximum number of results to return
            language: Language code (e.g., zh-CN, en)
            time_range: Time range (day, week, month, year)

        Returns:
            List of search results

        Raises:
            ConnectionError: If SearXNG is unreachable
            TimeoutError: If request times out
            ValueError: If response is invalid
        """
        # Build query parameters
        params = {
            "q": query,
            "format": "json",
            "pageno": "1"
        }

        if category:
            params["categories"] = category
        if language:
            params["language"] = language
        if time_range:
            params["time_range"] = time_range

        url = f"{self.base_url}/search"

        try:
            response = await self._client.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            # Extract results
            results = data.get("results", [])

            # Limit to max_results
            results = results[:max_results]

            # Normalize results - only keep essential fields
            normalized = []
            for r in results:
                normalized.append({
                    "title": r.get("title", ""),
                    "url": r.get("url", ""),
                    "snippet": r.get("content", r.get("snippet", "")),
                    "engine": r.get("engine", "unknown")
                })

            return normalized

        except httpx.TimeoutException as e:
            raise TimeoutError(f"SearXNG request timeout: {e}")
        except httpx.ConnectError as e:
            raise ConnectionError(
                f"SearXNG unreachable at {self.base_url}. "
                f"Please ensure SearXNG service is running. Error: {e}"
            )
        except httpx.HTTPStatusError as e:
            raise ValueError(
                f"SearXNG returned invalid response: {e.response.status_code}. "
                f"Check if the service is healthy."
            )
        except Exception as e:
            raise ValueError(f"Invalid response from SearXNG: {e}")

    async def health_check(self) -> bool:
        """Check if SearXNG service is healthy"""
        try:
            url = f"{self.base_url}/healthz"
            response = await self._client.get(url)
            return response.status_code == 200
        except Exception:
            return False
