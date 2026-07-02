"""Thin async client for the self-hosted vlrggapi, matching the endpoints and
envelope the iOS app uses.
"""
from __future__ import annotations

import json

import httpx

from . import config


def _sanitize(raw: bytes) -> str:
    """The scraper can emit raw control characters (< 0x20) that break strict
    JSON parsing — same hazard the app guards against. Replace them with
    spaces before decoding.
    """
    return bytes(0x20 if b < 0x20 else b for b in raw).decode("utf-8", "replace")


class VLRClient:
    def __init__(self, base_url: str = config.VLRGGAPI_URL):
        self.base_url = base_url.rstrip("/")
        self._client = httpx.AsyncClient(timeout=15.0)

    async def close(self) -> None:
        await self._client.aclose()

    async def _segments(self, path: str, params: dict) -> list[dict]:
        resp = await self._client.get(self.base_url + path, params=params)
        resp.raise_for_status()
        payload = json.loads(_sanitize(resp.content))
        data = payload.get("data", payload)
        if isinstance(data, dict):
            return data.get("segments", []) or []
        return data or []

    async def live(self) -> list[dict]:
        return await self._segments("/v2/match", {"q": "live_score"})

    async def upcoming(self) -> list[dict]:
        return await self._segments("/v2/match", {"q": "upcoming"})

    async def results(self) -> list[dict]:
        return await self._segments("/v2/match", {"q": "results"})
