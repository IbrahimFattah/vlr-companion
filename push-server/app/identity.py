"""Team identity + match id helpers.

These MUST stay byte-for-byte compatible with the iOS app, otherwise the worker
would target the wrong devices. The single source of truth is
`VLRAPIService.slugID` and `VLRAPIService.matchID` in the app; this is the
Python mirror.
"""
from __future__ import annotations

import unicodedata


def slug_id(name: str) -> str:
    """Normalized, endpoint-stable team id: "name:paper rex".

    Mirror of the app's `slugID`: diacritic-fold + lowercase, keep letters /
    numbers / spaces (everything else becomes a space), collapse whitespace,
    prefix with "name:".
    """
    decomposed = unicodedata.normalize("NFKD", name or "")
    folded = "".join(c for c in decomposed if not unicodedata.combining(c)).lower()
    kept = "".join(c if (c.isalnum() or c == " ") else " " for c in folded)
    collapsed = " ".join(kept.split())
    return "name:" + collapsed


def match_id(match_page: str | None) -> str | None:
    """Digit prefix of a match_page path, mirroring the app's `matchID`."""
    if not match_page:
        return None
    page = match_page[1:] if match_page.startswith("/") else match_page
    digits = ""
    for ch in page:
        if ch.isdigit():
            digits += ch
        else:
            break
    return digits or None


def short_tag(name: str) -> str:
    """Best-effort 2–4 char tag from a team name (the app only uses it for the
    nav title stub; real detail data overrides it once loaded)."""
    if not name:
        return "?"
    words = [w for w in name.split() if w]
    if len(words) >= 2:
        tag = "".join(w[0] for w in words[:4])
    else:
        tag = words[0][:3]
    return tag.upper()
