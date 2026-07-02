"""Environment configuration for the accounts + forums API."""
from __future__ import annotations

import os


def _int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except ValueError:
        return default


DB_PATH = os.environ.get("DB_PATH", "/data/api.db")

# Bearer token that unlocks moderation endpoints (hard-delete, unhide). Set to a
# long random string in production; empty disables the moderation surface.
ADMIN_TOKEN = os.environ.get("ADMIN_TOKEN", "")

# A post is auto-hidden once this many distinct users report it, pending
# moderator review. Keeps obvious abuse out without a human in the loop.
REPORT_HIDE_THRESHOLD = _int("REPORT_HIDE_THRESHOLD", 3)

# Simple anti-spam: max new posts per user per rolling window.
POST_RATE_MAX = _int("POST_RATE_MAX", 8)
POST_RATE_WINDOW = _int("POST_RATE_WINDOW", 60)  # seconds

# Sign in with Apple (wired later). When APPLE_CLIENT_ID is set the /auth/apple
# endpoint verifies real identity tokens; until then it returns 501.
APPLE_CLIENT_ID = os.environ.get("APPLE_CLIENT_ID", "")  # e.g. com.vlrcompanion.app
APPLE_ISSUER = "https://appleid.apple.com"

# Passwordless username login for building/testing before Sign in with Apple is
# available. INSECURE (anyone can claim any free username) — must be turned off
# once real auth lands. Defaults on for now.
ALLOW_DEV_AUTH = os.environ.get("ALLOW_DEV_AUTH", "1") not in ("0", "false", "False")
