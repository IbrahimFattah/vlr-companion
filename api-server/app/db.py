"""SQLite access + schema for accounts and forums.

One process-wide connection (WAL, thread-safe reads for our low volume). Callers
on the event loop wrap writes in `asyncio.to_thread`.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

from . import config

_conn: sqlite3.Connection | None = None


def connect(path: str = "") -> sqlite3.Connection:
    global _conn
    if _conn is not None:
        return _conn
    path = path or config.DB_PATH
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.executescript(SCHEMA)
    conn.commit()
    _conn = conn
    return conn


def db() -> sqlite3.Connection:
    return connect()


SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id           TEXT PRIMARY KEY,
    username     TEXT NOT NULL UNIQUE,
    avatar_emoji TEXT NOT NULL DEFAULT '🎯',
    avatar_color TEXT NOT NULL DEFAULT 'FF4655',
    apple_sub    TEXT UNIQUE,
    created_at   REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
    token      TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS favorites (
    user_id     TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    favorite    TEXT,
    secondaries TEXT NOT NULL DEFAULT '[]',
    updated_at  REAL NOT NULL
);

-- Forum posts. scope+ref identify the thread: ('match','12345'),
-- ('event','2470'), or ('general','main'). parent_id null = top-level.
CREATE TABLE IF NOT EXISTS posts (
    id           TEXT PRIMARY KEY,
    scope        TEXT NOT NULL,
    ref          TEXT NOT NULL,
    user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_id    TEXT REFERENCES posts(id) ON DELETE CASCADE,
    body         TEXT NOT NULL,
    created_at   REAL NOT NULL,
    deleted      INTEGER NOT NULL DEFAULT 0,
    hidden       INTEGER NOT NULL DEFAULT 0,
    report_count INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_posts_thread ON posts(scope, ref, created_at);

CREATE TABLE IF NOT EXISTS upvotes (
    post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS reports (
    id         TEXT PRIMARY KEY,
    post_id    TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason     TEXT NOT NULL DEFAULT '',
    created_at REAL NOT NULL,
    UNIQUE (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS blocks (
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at REAL NOT NULL,
    PRIMARY KEY (user_id, blocked_id)
);
"""
