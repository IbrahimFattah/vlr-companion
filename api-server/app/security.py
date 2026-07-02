"""Session tokens + request auth dependencies."""
from __future__ import annotations

import secrets
import time

from fastapi import Depends, Header, HTTPException

from . import config
from .db import db


def new_id() -> str:
    return secrets.token_hex(12)


def new_token() -> str:
    return secrets.token_urlsafe(32)


def create_session(user_id: str) -> str:
    token = new_token()
    db().execute(
        "INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)",
        (token, user_id, time.time()),
    )
    db().commit()
    return token


def _user_for_token(token: str) -> dict | None:
    row = db().execute(
        """SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id
           WHERE s.token = ?""",
        (token,),
    ).fetchone()
    return dict(row) if row else None


def _bearer(authorization: str | None) -> str | None:
    if not authorization:
        return None
    parts = authorization.split(None, 1)
    if len(parts) == 2 and parts[0].lower() == "bearer":
        return parts[1].strip()
    return None


def current_user(authorization: str | None = Header(default=None)) -> dict:
    """Required auth: 401 if no valid session."""
    token = _bearer(authorization)
    user = _user_for_token(token) if token else None
    if not user:
        raise HTTPException(401, "authentication required")
    return user


def optional_user(authorization: str | None = Header(default=None)) -> dict | None:
    """Auth if present, else None — for read endpoints that personalize
    (upvoted/blocked flags) but don't require sign-in."""
    token = _bearer(authorization)
    return _user_for_token(token) if token else None


def require_admin(x_admin_token: str | None = Header(default=None)) -> None:
    if not config.ADMIN_TOKEN or x_admin_token != config.ADMIN_TOKEN:
        raise HTTPException(403, "admin token required")
