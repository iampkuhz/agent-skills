"""External API Client - Template"""

import httpx
from typing import Optional


class TemplateClient:
    """Template HTTP client"""

    def __init__(self, base_url: str = "http://localhost:8080", timeout: float = 30.0):
        self.base_url = base_url
        self.timeout = timeout
        self._client = httpx.AsyncClient(timeout=timeout)

    async def close(self):
        """Close the HTTP client"""
        await self._client.aclose()

    async def request(self, method: str, path: str, **kwargs) -> dict:
        """Make HTTP request"""
        url = f"{self.base_url}{path}"
        try:
            response = await self._client.request(method, url, **kwargs)
            response.raise_for_status()
            return response.json()
        except httpx.TimeoutException as e:
            raise TimeoutError(f"Request timeout: {e}")
        except httpx.ConnectError as e:
            raise ConnectionError(f"Service unreachable: {e}")
        except httpx.HTTPStatusError as e:
            raise ValueError(f"Invalid response: {e.response.status_code}")
