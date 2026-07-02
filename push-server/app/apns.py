"""APNs sender using token-based (.p8 / JWT ES256) authentication over HTTP/2.

Token auth is preferred over certificates: one key works for every app under a
team, and the JWT is cheap to mint and reuse (~1/hour).
"""
from __future__ import annotations

import json
import time

import httpx
import jwt

from . import config
from .store import Device


class APNsClient:
    def __init__(self):
        # HTTP/2 is required by APNs.
        self._client = httpx.AsyncClient(http2=True, timeout=15.0)
        self._jwt: str | None = None
        self._jwt_ts: float = 0.0
        self._key: str | None = None

    async def close(self) -> None:
        await self._client.aclose()

    @property
    def configured(self) -> bool:
        return bool(config.APNS_KEY_ID and config.APNS_TEAM_ID)

    def _signing_key(self) -> str:
        if self._key is None:
            with open(config.APNS_KEY_PATH, "r") as f:
                self._key = f.read()
        return self._key

    def _provider_token(self) -> str:
        # Apple accepts a provider JWT for up to 60 minutes; refresh at ~50.
        if self._jwt and (time.time() - self._jwt_ts) < 50 * 60:
            return self._jwt
        self._jwt = jwt.encode(
            {"iss": config.APNS_TEAM_ID, "iat": int(time.time())},
            self._signing_key(),
            algorithm="ES256",
            headers={"kid": config.APNS_KEY_ID},
        )
        self._jwt_ts = time.time()
        return self._jwt

    async def send(self, device: Device, payload: dict) -> tuple[bool, bool]:
        """Send one alert. Returns (delivered, should_delete_token).

        should_delete_token is True when Apple reports the token is no longer
        valid (410 / BadDeviceToken / Unregistered), so the caller can prune it.
        """
        if not self.configured:
            return False, False

        host = config.APNS_HOST.get(device.environment, config.APNS_HOST["sandbox"])
        url = f"https://{host}/3/device/{device.token}"
        headers = {
            "authorization": f"bearer {self._provider_token()}",
            "apns-topic": device.bundle_id or config.APNS_BUNDLE_ID,
            "apns-push-type": "alert",
            "apns-priority": "10",
        }
        try:
            resp = await self._client.post(url, headers=headers, content=json.dumps(payload))
        except httpx.HTTPError as exc:
            print(f"[APNs] transport error for {device.token[:8]}…: {exc}")
            return False, False

        if resp.status_code == 200:
            return True, False

        reason = ""
        try:
            reason = resp.json().get("reason", "")
        except Exception:
            reason = resp.text
        stale = resp.status_code == 410 or reason in {"BadDeviceToken", "Unregistered"}
        print(f"[APNs] {resp.status_code} {reason} for {device.token[:8]}…")
        return False, stale
