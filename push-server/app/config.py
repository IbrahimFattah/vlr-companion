"""Runtime configuration, all from environment variables.

Nothing here has a hard-coded secret; the APNs values come from the Apple
Developer portal (see push-server/README.md). The service starts fine without
them — it just can't actually send pushes until they're set, which is handy for
local development of the /register + poller plumbing.
"""
from __future__ import annotations

import os


def _int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except ValueError:
        return default


# Where to reach the self-hosted vlrggapi (same instance the app uses).
VLRGGAPI_URL = os.environ.get("VLRGGAPI_URL", "http://vlrggapi:3001").rstrip("/")

# APNs token-based auth (.p8 key). All four required to send.
APNS_KEY_ID = os.environ.get("APNS_KEY_ID", "")
APNS_TEAM_ID = os.environ.get("APNS_TEAM_ID", "")
APNS_KEY_PATH = os.environ.get("APNS_KEY_PATH", "/secrets/AuthKey.p8")
APNS_BUNDLE_ID = os.environ.get("APNS_BUNDLE_ID", "com.vlrcompanion.app")

# "sandbox" (Xcode/TestFlight debug builds) or "production" (App Store).
# Individual device registrations can override this per token.
APNS_DEFAULT_ENV = os.environ.get("APNS_DEFAULT_ENV", "sandbox")

# Storage + loop timing.
DB_PATH = os.environ.get("DB_PATH", "/data/push.db")
POLL_INTERVAL = _int("POLL_INTERVAL", 30)            # seconds between vlrggapi polls
STARTING_SOON_WINDOW = _int("STARTING_SOON_WINDOW", 900)   # 15 min "starting soon" lead

APNS_HOST = {
    "sandbox": "api.sandbox.push.apple.com",
    "production": "api.push.apple.com",
}
