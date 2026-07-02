"""Profile + favorites sync. `FavoritesStore` in the app is the local cache of
this server-side record once the user signs in.
"""
from __future__ import annotations

import json
import time

from fastapi import APIRouter, Depends, HTTPException

from .auth import _public_user
from .db import db
from .models import FavoritesBody, ProfilePatch
from .security import current_user

router = APIRouter(tags=["profile"])


@router.get("/me")
def get_me(user: dict = Depends(current_user)):
    return _public_user(user)


@router.patch("/me")
def patch_me(patch: ProfilePatch, user: dict = Depends(current_user)):
    fields, values = [], []
    if patch.username is not None:
        fields.append("username = ?"); values.append(patch.username)
    if patch.avatarEmoji is not None:
        fields.append("avatar_emoji = ?"); values.append(patch.avatarEmoji)
    if patch.avatarColor is not None:
        fields.append("avatar_color = ?"); values.append(patch.avatarColor)
    if fields:
        values.append(user["id"])
        try:
            db().execute(f"UPDATE users SET {', '.join(fields)} WHERE id = ?", values)
            db().commit()
        except Exception:
            raise HTTPException(409, "username already taken")
    row = db().execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
    return _public_user(dict(row))


@router.delete("/me")
def delete_me(user: dict = Depends(current_user)):
    # Cascades remove sessions, favorites, posts, upvotes, reports, blocks.
    db().execute("DELETE FROM users WHERE id = ?", (user["id"],))
    db().commit()
    return {"status": "deleted"}


@router.get("/me/favorites")
def get_favorites(user: dict = Depends(current_user)):
    row = db().execute("SELECT * FROM favorites WHERE user_id = ?", (user["id"],)).fetchone()
    if not row:
        return {"favorite": None, "secondaries": []}
    return {"favorite": row["favorite"], "secondaries": json.loads(row["secondaries"])}


@router.put("/me/favorites")
def put_favorites(body: FavoritesBody, user: dict = Depends(current_user)):
    db().execute(
        """INSERT INTO favorites (user_id, favorite, secondaries, updated_at)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(user_id) DO UPDATE SET
             favorite=excluded.favorite, secondaries=excluded.secondaries,
             updated_at=excluded.updated_at""",
        (user["id"], body.favorite, json.dumps(body.secondaries[:3]), time.time()),
    )
    db().commit()
    return {"favorite": body.favorite, "secondaries": body.secondaries[:3]}
