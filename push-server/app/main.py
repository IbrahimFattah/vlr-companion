"""FastAPI surface for the push worker.

Endpoints:
  POST /register    device token + followed teams + alert prefs (called by the app)
  POST /unregister  drop a token
  GET  /health      liveness + registered device count
  POST /test-push   dev helper: send one alert to a token immediately
"""
from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from . import config
from .apns import APNsClient
from .poller import Poller
from .store import Device, Store


class Alerts(BaseModel):
    live: bool = True
    startingSoon: bool = True
    finished: bool = False
    majorFinals: bool = False


class RegisterBody(BaseModel):
    token: str
    teams: list[str] = Field(default_factory=list)
    alerts: Alerts = Field(default_factory=Alerts)
    environment: str = config.APNS_DEFAULT_ENV
    bundleID: str = config.APNS_BUNDLE_ID


class TestPushBody(BaseModel):
    token: str
    environment: str = config.APNS_DEFAULT_ENV
    bundleID: str = config.APNS_BUNDLE_ID
    title: str = "VLR Companion"
    body: str = "Test push"
    match_id: str = "0"


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.store = Store(config.DB_PATH)
    app.state.poller = Poller(app.state.store)
    task = asyncio.create_task(app.state.poller.run_forever())
    try:
        yield
    finally:
        task.cancel()
        await app.state.poller.close()


app = FastAPI(title="VLR Companion Push", lifespan=lifespan)


@app.post("/register")
async def register(body: RegisterBody):
    if not body.token:
        raise HTTPException(400, "token required")
    device = Device(
        token=body.token,
        teams=body.teams,
        alerts=body.alerts.model_dump(),
        environment=body.environment,
        bundle_id=body.bundleID,
    )
    await asyncio.to_thread(app.state.store.upsert_device, device)
    return {"status": "ok", "teams": len(body.teams)}


@app.post("/unregister")
async def unregister(body: RegisterBody):
    await asyncio.to_thread(app.state.store.delete_device, body.token)
    return {"status": "ok"}


@app.get("/health")
async def health():
    count = await asyncio.to_thread(app.state.store.device_count)
    return {
        "status": "ok",
        "devices": count,
        "apns_configured": app.state.poller.apns.configured,
        "vlrggapi": config.VLRGGAPI_URL,
    }


@app.post("/test-push")
async def test_push(body: TestPushBody):
    """Send a single alert to one token — for verifying APNs credentials end to
    end without waiting for a real match transition."""
    client: APNsClient = app.state.poller.apns
    if not client.configured:
        raise HTTPException(400, "APNs not configured (set APNS_KEY_ID/APNS_TEAM_ID/APNS_KEY_PATH)")
    device = Device(token=body.token, teams=[], alerts={}, environment=body.environment,
                    bundle_id=body.bundleID)
    payload = {
        "aps": {"alert": {"title": body.title, "body": body.body},
                "sound": "default", "category": "MATCH_ALERT"},
        "match": {"id": body.match_id, "team1": "Team 1", "tag1": "T1",
                  "team2": "Team 2", "tag2": "T2", "event": "Test", "stage": "",
                  "status": "live"},
    }
    delivered, stale = await client.send(device, payload)
    return {"delivered": delivered, "stale_token": stale}
