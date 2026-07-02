"""Forums: threaded discussion scoped to a match, event, or the general board.

App Store UGC requirements are covered here: a report flow (`/report`), user
blocking (`/users/{id}/block`), author delete, and auto-hide on repeated
reports. The app must also show a EULA / no-tolerance notice and a moderator
contact — see api-server/README.md.
"""
from __future__ import annotations

import time

from fastapi import APIRouter, Depends, HTTPException, Query

from .db import db
from .models import PostBody, ReportBody
from .moderation import check_rate_limit, serialize_post
from .security import current_user, new_id, optional_user, require_admin

router = APIRouter(tags=["forums"])

VALID_SCOPES = {"match", "event", "general"}

# Row template joining author + upvote count for serialization.
_POST_SELECT = """
    SELECT p.*, u.username, u.avatar_emoji, u.avatar_color,
           (SELECT COUNT(*) FROM upvotes v WHERE v.post_id = p.id) AS upvotes
    FROM posts p JOIN users u ON u.id = p.user_id
"""


def _blocked_ids(user: dict | None) -> set[str]:
    if not user:
        return set()
    rows = db().execute("SELECT blocked_id FROM blocks WHERE user_id = ?", (user["id"],)).fetchall()
    return {r["blocked_id"] for r in rows}


def _upvoted_ids(user: dict | None, post_ids: list[str]) -> set[str]:
    if not user or not post_ids:
        return set()
    marks = ",".join("?" * len(post_ids))
    rows = db().execute(
        f"SELECT post_id FROM upvotes WHERE user_id = ? AND post_id IN ({marks})",
        (user["id"], *post_ids),
    ).fetchall()
    return {r["post_id"] for r in rows}


@router.get("/threads/{scope}/{ref}/posts")
def list_posts(
    scope: str, ref: str,
    limit: int = Query(20, ge=1, le=50),
    before: float | None = None,
    user: dict | None = Depends(optional_user),
):
    if scope not in VALID_SCOPES:
        raise HTTPException(400, "unknown scope")

    params: list = [scope, ref]
    cursor = ""
    if before is not None:
        cursor = "AND p.created_at < ?"
        params.append(before)
    params.append(limit + 1)  # one extra to detect a next page

    top = db().execute(
        f"""{_POST_SELECT}
            WHERE p.scope = ? AND p.ref = ? AND p.parent_id IS NULL
              AND p.deleted = 0 {cursor}
            ORDER BY p.created_at DESC LIMIT ?""",
        params,
    ).fetchall()

    has_more = len(top) > limit
    top = top[:limit]

    blocked = _blocked_ids(user)
    # Gather replies for this page in one pass.
    parent_ids = [r["id"] for r in top]
    replies_by_parent: dict[str, list] = {pid: [] for pid in parent_ids}
    if parent_ids:
        marks = ",".join("?" * len(parent_ids))
        reply_rows = db().execute(
            f"""{_POST_SELECT}
                WHERE p.parent_id IN ({marks}) AND p.deleted = 0
                ORDER BY p.created_at ASC""",
            parent_ids,
        ).fetchall()
        for r in reply_rows:
            replies_by_parent[r["parent_id"]].append(r)

    all_ids = parent_ids + [r["id"] for rs in replies_by_parent.values() for r in rs]
    upvoted = _upvoted_ids(user, all_ids)

    def visible(row) -> bool:
        return row["user_id"] not in blocked

    items = []
    for r in top:
        if not visible(r):
            continue
        replies = [
            serialize_post(dict(rp), rp["id"] in upvoted)
            for rp in replies_by_parent[r["id"]] if visible(rp)
        ]
        post = serialize_post(dict(r), r["id"] in upvoted, reply_count=len(replies))
        post["replies"] = replies
        items.append(post)

    next_cursor = top[-1]["created_at"] if (has_more and top) else None
    return {"posts": items, "nextCursor": next_cursor}


@router.post("/threads/{scope}/{ref}/posts", status_code=201)
def create_post(scope: str, ref: str, body: PostBody, user: dict = Depends(current_user)):
    if scope not in VALID_SCOPES:
        raise HTTPException(400, "unknown scope")
    check_rate_limit(user["id"])

    if body.parentId:
        parent = db().execute(
            "SELECT scope, ref, parent_id FROM posts WHERE id = ? AND deleted = 0",
            (body.parentId,),
        ).fetchone()
        if not parent or parent["scope"] != scope or parent["ref"] != ref:
            raise HTTPException(400, "invalid parent post")
        if parent["parent_id"] is not None:
            raise HTTPException(400, "replies are only one level deep")

    pid = new_id()
    db().execute(
        """INSERT INTO posts (id, scope, ref, user_id, parent_id, body, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (pid, scope, ref, user["id"], body.parentId, body.body.strip(), time.time()),
    )
    db().commit()
    row = db().execute(f"{_POST_SELECT} WHERE p.id = ?", (pid,)).fetchone()
    post = serialize_post(dict(row), upvoted=False)
    post["replies"] = []
    return post


@router.post("/posts/{post_id}/upvote")
def toggle_upvote(post_id: str, user: dict = Depends(current_user)):
    exists = db().execute("SELECT 1 FROM posts WHERE id = ? AND deleted = 0", (post_id,)).fetchone()
    if not exists:
        raise HTTPException(404, "post not found")
    have = db().execute(
        "SELECT 1 FROM upvotes WHERE post_id = ? AND user_id = ?", (post_id, user["id"])
    ).fetchone()
    if have:
        db().execute("DELETE FROM upvotes WHERE post_id = ? AND user_id = ?", (post_id, user["id"]))
        upvoted = False
    else:
        db().execute("INSERT INTO upvotes (post_id, user_id) VALUES (?, ?)", (post_id, user["id"]))
        upvoted = True
    db().commit()
    count = db().execute("SELECT COUNT(*) AS n FROM upvotes WHERE post_id = ?", (post_id,)).fetchone()["n"]
    return {"upvotes": count, "upvoted": upvoted}


@router.post("/posts/{post_id}/report")
def report_post(post_id: str, body: ReportBody, user: dict = Depends(current_user)):
    from . import config
    exists = db().execute("SELECT 1 FROM posts WHERE id = ?", (post_id,)).fetchone()
    if not exists:
        raise HTTPException(404, "post not found")
    try:
        db().execute(
            "INSERT INTO reports (id, post_id, user_id, reason, created_at) VALUES (?, ?, ?, ?, ?)",
            (new_id(), post_id, user["id"], body.reason, time.time()),
        )
    except Exception:
        return {"status": "already reported"}
    count = db().execute("SELECT COUNT(*) AS n FROM reports WHERE post_id = ?", (post_id,)).fetchone()["n"]
    hidden = count >= config.REPORT_HIDE_THRESHOLD
    db().execute(
        "UPDATE posts SET report_count = ?, hidden = MAX(hidden, ?) WHERE id = ?",
        (count, 1 if hidden else 0, post_id),
    )
    db().commit()
    return {"status": "reported", "autoHidden": hidden}


@router.delete("/posts/{post_id}")
def delete_post(post_id: str, user: dict = Depends(current_user)):
    row = db().execute("SELECT user_id FROM posts WHERE id = ?", (post_id,)).fetchone()
    if not row:
        raise HTTPException(404, "post not found")
    if row["user_id"] != user["id"]:
        raise HTTPException(403, "not your post")
    db().execute("UPDATE posts SET deleted = 1 WHERE id = ?", (post_id,))
    db().commit()
    return {"status": "deleted"}


@router.post("/users/{blocked_id}/block")
def block_user(blocked_id: str, user: dict = Depends(current_user)):
    if blocked_id == user["id"]:
        raise HTTPException(400, "cannot block yourself")
    db().execute(
        "INSERT OR IGNORE INTO blocks (user_id, blocked_id, created_at) VALUES (?, ?, ?)",
        (user["id"], blocked_id, time.time()),
    )
    db().commit()
    return {"status": "blocked"}


@router.delete("/users/{blocked_id}/block")
def unblock_user(blocked_id: str, user: dict = Depends(current_user)):
    db().execute(
        "DELETE FROM blocks WHERE user_id = ? AND blocked_id = ?", (user["id"], blocked_id)
    )
    db().commit()
    return {"status": "unblocked"}


# -- moderation (admin token) --------------------------------------------

@router.delete("/admin/posts/{post_id}", dependencies=[Depends(require_admin)])
def admin_delete(post_id: str):
    db().execute("UPDATE posts SET deleted = 1, hidden = 1 WHERE id = ?", (post_id,))
    db().commit()
    return {"status": "removed"}


@router.post("/admin/posts/{post_id}/unhide", dependencies=[Depends(require_admin)])
def admin_unhide(post_id: str):
    db().execute("UPDATE posts SET hidden = 0, report_count = 0 WHERE id = ?", (post_id,))
    db().execute("DELETE FROM reports WHERE post_id = ?", (post_id,))
    db().commit()
    return {"status": "restored"}
