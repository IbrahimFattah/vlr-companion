"""Rate limiting + post serialization helpers shared by the forums router."""
from __future__ import annotations

import time
from collections import defaultdict, deque

from fastapi import HTTPException

from . import config

_hits: dict[str, deque[float]] = defaultdict(deque)


def check_rate_limit(user_id: str) -> None:
    now = time.time()
    q = _hits[user_id]
    while q and now - q[0] > config.POST_RATE_WINDOW:
        q.popleft()
    if len(q) >= config.POST_RATE_MAX:
        raise HTTPException(429, "slow down — too many posts")
    q.append(now)


def serialize_post(row: dict, upvoted: bool, reply_count: int = 0) -> dict:
    """Public shape of a post. Hidden/deleted posts keep their slot but drop
    author + body so threads stay readable without exposing removed content."""
    removed = bool(row["deleted"]) or bool(row["hidden"])
    return {
        "id": row["id"],
        "scope": row["scope"],
        "ref": row["ref"],
        "parentId": row["parent_id"],
        "body": "[removed]" if removed else row["body"],
        "createdAt": row["created_at"],
        "removed": removed,
        "author": None if removed else {
            "id": row["user_id"],
            "username": row["username"],
            "avatarEmoji": row["avatar_emoji"],
            "avatarColor": row["avatar_color"],
        },
        "upvotes": row["upvotes"],
        "upvoted": upvoted,
        "replyCount": reply_count,
    }
