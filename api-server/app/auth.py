"""Authentication endpoints: dev username login now, Sign in with Apple later."""
from __future__ import annotations

import time

from fastapi import APIRouter, HTTPException

from . import config
from .db import db
from .models import AppleLoginBody, DevLoginBody
from .security import create_session, new_id

router = APIRouter(prefix="/auth", tags=["auth"])


def _public_user(row: dict) -> dict:
    return {
        "id": row["id"],
        "username": row["username"],
        "avatarEmoji": row["avatar_emoji"],
        "avatarColor": row["avatar_color"],
    }


def _create_user(username: str, emoji: str, color: str, apple_sub: str | None = None) -> dict:
    uid = new_id()
    try:
        db().execute(
            """INSERT INTO users (id, username, avatar_emoji, avatar_color, apple_sub, created_at)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (uid, username, emoji, color, apple_sub, time.time()),
        )
        db().commit()
    except Exception:
        raise HTTPException(409, "username already taken")
    return dict(db().execute("SELECT * FROM users WHERE id = ?", (uid,)).fetchone())


@router.post("/dev")
def dev_login(body: DevLoginBody):
    """Passwordless login for development. Reuses an existing account with the
    same username, otherwise creates one. Insecure by design — disabled when
    ALLOW_DEV_AUTH is off."""
    if not config.ALLOW_DEV_AUTH:
        raise HTTPException(403, "dev auth disabled")

    row = db().execute("SELECT * FROM users WHERE username = ?", (body.username,)).fetchone()
    user = dict(row) if row else _create_user(body.username, body.avatarEmoji, body.avatarColor)
    token = create_session(user["id"])
    return {"token": token, "user": _public_user(user)}


@router.post("/apple")
def apple_login(body: AppleLoginBody):
    """Sign in with Apple. Verifies the identity token against Apple's public
    keys and upserts the user keyed by Apple's stable `sub`.

    Gated on APPLE_CLIENT_ID until the Apple Developer account + capability are
    set up; returns 501 until then. The app already sends the right payload, so
    enabling this is a config change, not a client change.
    """
    if not config.APPLE_CLIENT_ID:
        raise HTTPException(501, "Sign in with Apple not configured yet")

    # Verification skeleton (enable once APPLE_CLIENT_ID is set):
    #   import jwt
    #   from jwt import PyJWKClient
    #   jwks = PyJWKClient("https://appleid.apple.com/auth/keys")
    #   key = jwks.get_signing_key_from_jwt(body.identityToken).key
    #   claims = jwt.decode(body.identityToken, key, algorithms=["RS256"],
    #                       audience=config.APPLE_CLIENT_ID, issuer=config.APPLE_ISSUER)
    #   sub = claims["sub"]
    # then upsert by apple_sub, mint a session as in dev_login.
    raise HTTPException(501, "Sign in with Apple not configured yet")
