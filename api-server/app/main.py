"""VLR Companion accounts + forums API.

Endpoints:
  POST   /auth/dev                       passwordless username login (dev)
  POST   /auth/apple                     Sign in with Apple (501 until configured)
  GET    /me                             profile
  PATCH  /me                             edit profile
  DELETE /me                             delete account (App Store requirement)
  GET/PUT /me/favorites                  favorite-team sync
  GET    /threads/{scope}/{ref}/posts    thread (paginated), scope=match|event|general
  POST   /threads/{scope}/{ref}/posts    new post / reply
  POST   /posts/{id}/upvote              toggle upvote
  POST   /posts/{id}/report              report (auto-hides on threshold)
  DELETE /posts/{id}                     author delete
  POST/DELETE /users/{id}/block          block / unblock
  DELETE /admin/posts/{id}, POST .../unhide   moderation (X-Admin-Token)
  GET    /health
"""
from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from . import auth, config, forums, profile
from .db import connect


@asynccontextmanager
async def lifespan(app: FastAPI):
    connect()
    yield


app = FastAPI(title="VLR Companion API", lifespan=lifespan)
app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(forums.router)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "devAuth": config.ALLOW_DEV_AUTH,
        "appleAuth": bool(config.APPLE_CLIENT_ID),
    }
