"""The worker loop: polls vlrggapi, diffs match state, and sends APNs alerts on
transitions (starting soon → live → finished) plus a major-finals topic.
"""
from __future__ import annotations

import asyncio
import time

from . import config
from .apns import APNsClient
from .identity import match_id, short_tag, slug_id
from .store import Device, Store
from .vlr import VLRClient

# Defaults must match the app's registered UserDefaults defaults.
ALERT_DEFAULTS = {"live": True, "startingSoon": True, "finished": False, "majorFinals": False}

FINAL_HINTS = ("grand final", "final", "grand-final")


def _int(value) -> int | None:
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def _norm_logo(raw: str | None) -> str:
    if not raw:
        return ""
    if raw.startswith("//"):
        return "https:" + raw
    return raw


def _is_final(*texts: str | None) -> bool:
    blob = " ".join(t.lower() for t in texts if t)
    return any(h in blob for h in FINAL_HINTS)


class Poller:
    def __init__(self, store: Store):
        self.store = store
        self.vlr = VLRClient()
        self.apns = APNsClient()

    async def close(self) -> None:
        await self.vlr.close()
        await self.apns.close()

    async def run_forever(self) -> None:
        while True:
            try:
                await self.tick()
            except Exception as exc:  # keep the loop alive
                print(f"[poller] tick failed: {exc}")
            await asyncio.sleep(config.POLL_INTERVAL)

    # -- one poll cycle ----------------------------------------------------

    async def tick(self) -> None:
        live, results, upcoming = await asyncio.gather(
            self.vlr.live(), self.vlr.results(), self.vlr.upcoming()
        )
        matches = self._collect(upcoming, results, live)
        if not matches:
            return

        prev = self.store.match_state()
        devices = self.store.all_devices()

        for mid, m in matches.items():
            prev_status = prev.get(mid, {}).get("status")
            for event_type in self._transitions(m, prev_status):
                await self._dispatch(mid, m, event_type, devices)
            self.store.set_match_state(mid, m["status"], m.get("score", ""))

        self.store.prune_sent()

    def _collect(self, upcoming, results, live) -> dict[str, dict]:
        """Merge the three feeds keyed by match id; live wins over completed
        wins over upcoming."""
        matches: dict[str, dict] = {}

        for seg in upcoming:
            mid = match_id(seg.get("match_page"))
            if not mid:
                continue
            matches[mid] = {
                "status": "upcoming",
                "team1": seg.get("team1", ""), "team2": seg.get("team2", ""),
                "event": seg.get("match_event", ""), "stage": seg.get("match_series", ""),
                "score1": None, "score2": None, "score": "",
                "unix": _int(seg.get("unix_timestamp")),
                "logo1": "", "logo2": "",
            }

        for seg in results:
            mid = match_id(seg.get("match_page"))
            if not mid:
                continue
            s1, s2 = _int(seg.get("score1")), _int(seg.get("score2"))
            matches[mid] = {
                "status": "completed",
                "team1": seg.get("team1", ""), "team2": seg.get("team2", ""),
                "event": seg.get("tournament_name", ""), "stage": seg.get("round_info", ""),
                "score1": s1, "score2": s2, "score": f"{s1}-{s2}",
                "unix": None, "logo1": "", "logo2": "",
            }

        for seg in live:
            mid = match_id(seg.get("match_page"))
            if not mid:
                continue
            s1, s2 = _int(seg.get("score1")), _int(seg.get("score2"))
            matches[mid] = {
                "status": "live",
                "team1": seg.get("team1", ""), "team2": seg.get("team2", ""),
                "event": seg.get("match_event", ""), "stage": seg.get("match_series", ""),
                "score1": s1, "score2": s2, "score": f"{s1}-{s2}",
                "unix": None,
                "logo1": _norm_logo(seg.get("team1_logo")),
                "logo2": _norm_logo(seg.get("team2_logo")),
            }
        return matches

    def _transitions(self, m: dict, prev_status: str | None) -> list[str]:
        events: list[str] = []
        status = m["status"]
        final = _is_final(m.get("event"), m.get("stage"))
        # First time we've ever seen this match id — record its state silently
        # rather than alerting. Prevents a cold start (or a fresh restart) from
        # blasting "live"/"finished" for every match already in progress or done.
        # Time-based "starting soon" is exempt: it's meant to fire on first
        # sight of an upcoming match inside the lead window (deduped anyway).
        first_sight = prev_status is None

        if status == "live":
            if not first_sight and prev_status != "live":
                events.append("live")
                if final:
                    events.append("majorFinals")
        elif status == "completed":
            if not first_sight and prev_status != "completed":
                events.append("finished")
        elif status == "upcoming":
            unix = m.get("unix")
            if unix is not None:
                lead = unix - time.time()
                if 0 <= lead <= config.STARTING_SOON_WINDOW:
                    events.append("startingSoon")
                    if final:
                        events.append("majorFinals")
        return events

    # -- sending -----------------------------------------------------------

    async def _dispatch(self, mid: str, m: dict, event_type: str, devices: list[Device]) -> None:
        key = f"{mid}:{event_type}"
        if self.store.already_sent(key):
            return

        recipients = self._recipients(m, event_type, devices)
        payload = self._payload(mid, m, event_type)

        sent_any = False
        for device in recipients:
            delivered, stale = await self.apns.send(device, payload)
            sent_any = sent_any or delivered
            if stale:
                self.store.delete_device(device.token)

        # Mark the transition handled so we don't reprocess it every tick,
        # even if there were no eligible devices this cycle.
        self.store.mark_sent(key)
        if recipients:
            print(f"[poller] {event_type} {mid} → {len(recipients)} device(s), delivered={sent_any}")

    def _recipients(self, m: dict, event_type: str, devices: list[Device]) -> list[Device]:
        team_slugs = {slug_id(m["team1"]), slug_id(m["team2"])}
        out: list[Device] = []
        for d in devices:
            follows = bool(set(d.teams) & team_slugs)
            if event_type == "majorFinals":
                # Topic subscribers who don't already follow a team in the match
                # (followers get the normal live/starting-soon alert instead).
                if not follows and d.alerts.get("majorFinals", ALERT_DEFAULTS["majorFinals"]):
                    out.append(d)
            else:
                if follows and d.alerts.get(event_type, ALERT_DEFAULTS[event_type]):
                    out.append(d)
        return out

    def _payload(self, mid: str, m: dict, event_type: str) -> dict:
        t1, t2 = m["team1"] or "Team 1", m["team2"] or "Team 2"
        event, stage = m.get("event", ""), m.get("stage", "")
        s1, s2 = m.get("score1"), m.get("score2")

        if event_type == "startingSoon":
            title = f"{t1} vs {t2} starts soon"
        elif event_type == "finished":
            if s1 is not None and s2 is not None:
                winner, loser, ws, ls = (t1, t2, s1, s2) if s1 >= s2 else (t2, t1, s2, s1)
                title = f"{winner} beat {loser} {ws}–{ls}"
            else:
                title = f"{t1} vs {t2} finished"
        elif event_type == "majorFinals":
            title = f"{event} — final is live" if event else f"{t1} vs {t2} final is live"
        else:  # live
            title = f"{t1} vs {t2} is live"

        body = " · ".join(x for x in (event, stage) if x)

        return {
            "aps": {
                "alert": {"title": title, "body": body},
                "sound": "default",
                "category": "MATCH_ALERT",
            },
            "match": {
                "id": mid,
                "team1": t1, "tag1": short_tag(t1),
                "team2": t2, "tag2": short_tag(t2),
                "event": event, "stage": stage,
                "status": m["status"],
                "score1": s1, "score2": s2,
                "logo1": m.get("logo1", ""), "logo2": m.get("logo2", ""),
            },
        }
