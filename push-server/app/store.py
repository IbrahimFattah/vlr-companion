"""SQLite persistence: device registrations, last-seen match state, and a
sent-alert ledger for idempotency across restarts.

Synchronous and tiny; callers hop through `asyncio.to_thread` where they're on
the event loop.
"""
from __future__ import annotations

import json
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Device:
    token: str
    teams: list[str]
    alerts: dict[str, bool]
    environment: str
    bundle_id: str


class Store:
    def __init__(self, path: str):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA journal_mode=WAL")
        self._migrate()

    def _migrate(self) -> None:
        self.db.executescript(
            """
            CREATE TABLE IF NOT EXISTS devices (
                token       TEXT PRIMARY KEY,
                teams       TEXT NOT NULL DEFAULT '[]',
                alerts      TEXT NOT NULL DEFAULT '{}',
                environment TEXT NOT NULL DEFAULT 'sandbox',
                bundle_id   TEXT NOT NULL DEFAULT '',
                updated_at  REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS match_state (
                match_id   TEXT PRIMARY KEY,
                status     TEXT NOT NULL,
                score      TEXT NOT NULL DEFAULT '',
                updated_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS sent (
                key     TEXT PRIMARY KEY,
                sent_at REAL NOT NULL
            );
            """
        )
        self.db.commit()

    # -- devices -----------------------------------------------------------

    def upsert_device(self, d: Device) -> None:
        self.db.execute(
            """INSERT INTO devices (token, teams, alerts, environment, bundle_id, updated_at)
               VALUES (?, ?, ?, ?, ?, ?)
               ON CONFLICT(token) DO UPDATE SET
                 teams=excluded.teams, alerts=excluded.alerts,
                 environment=excluded.environment, bundle_id=excluded.bundle_id,
                 updated_at=excluded.updated_at""",
            (d.token, json.dumps(d.teams), json.dumps(d.alerts),
             d.environment, d.bundle_id, time.time()),
        )
        self.db.commit()

    def delete_device(self, token: str) -> None:
        self.db.execute("DELETE FROM devices WHERE token = ?", (token,))
        self.db.commit()

    def all_devices(self) -> list[Device]:
        rows = self.db.execute("SELECT * FROM devices").fetchall()
        return [
            Device(
                token=r["token"],
                teams=json.loads(r["teams"]),
                alerts=json.loads(r["alerts"]),
                environment=r["environment"],
                bundle_id=r["bundle_id"],
            )
            for r in rows
        ]

    def device_count(self) -> int:
        return self.db.execute("SELECT COUNT(*) AS n FROM devices").fetchone()["n"]

    # -- match state -------------------------------------------------------

    def match_state(self) -> dict[str, dict]:
        rows = self.db.execute("SELECT * FROM match_state").fetchall()
        return {r["match_id"]: {"status": r["status"], "score": r["score"]} for r in rows}

    def set_match_state(self, match_id: str, status: str, score: str) -> None:
        self.db.execute(
            """INSERT INTO match_state (match_id, status, score, updated_at)
               VALUES (?, ?, ?, ?)
               ON CONFLICT(match_id) DO UPDATE SET
                 status=excluded.status, score=excluded.score, updated_at=excluded.updated_at""",
            (match_id, status, score, time.time()),
        )
        self.db.commit()

    # -- sent ledger (idempotency) ----------------------------------------

    def already_sent(self, key: str) -> bool:
        return self.db.execute("SELECT 1 FROM sent WHERE key = ?", (key,)).fetchone() is not None

    def mark_sent(self, key: str) -> None:
        self.db.execute(
            "INSERT OR IGNORE INTO sent (key, sent_at) VALUES (?, ?)", (key, time.time())
        )
        self.db.commit()

    def prune_sent(self, older_than_seconds: float = 7 * 24 * 3600) -> None:
        cutoff = time.time() - older_than_seconds
        self.db.execute("DELETE FROM sent WHERE sent_at < ?", (cutoff,))
        self.db.commit()
