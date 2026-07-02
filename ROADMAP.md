# VLR Companion — Roadmap

Features planned after the mock-data milestone. Ordered roughly by
dependency: items needing a backend/account system cluster together.

## 0. Real API integration (self-hosted vlrggapi) — ✅ DONE (client side)

`VLRAPIService` implemented and verified against a local Docker instance;
"Live data" toggle in Settings. Real logos already flow through (#1 partly
done) and per-map player stats are decoded and waiting for UI (#2).
Remaining: deploy the container to the real server + HTTPS
(**[SELF_HOSTING.md](SELF_HOSTING.md)** Part 1).

## 1. Real team logos — ✅ client done, bucket pending

- API logo URLs flow through with backing plates for dark crests; URLCache
  bumped (32 MB / 256 MB) so images cache to disk.
- **Bucket plan (decided)**: no dummy/monogram fallback for known teams —
  we mirror crests in our own bucket/CDN for fast, stable retrieval.
  `TeamLogoView` already prefers `{bucket}/logos/{team-slug}.png` when the
  assets bucket URL is set (Settings → Data source). Remaining: stand up the
  bucket and upload the crest set (one-time script scraping rankings logos).
- Monogram remains only as a loading placeholder / truly-unknown-team case.

## 2. Per-map player scoreboard (vlr.gg style) — ✅ DONE

Shipped: tap a map card → `MapScoreboardView` sheet with per-team tables
(R, ACS, K/D/A, colored +/–, KAST, ADR, HS%, FK, FD), horizontal scroll for
the stat tail, agents under player names. Works on live data (real API
scoreboards) and sample data (seeded lines). Remaining nice-to-have:
All/Attack/Defend side splits — the scraper currently exposes only
aggregates, so this needs an upstream (vlrggapi) change first.

Original spec for reference:

| Column | Meaning |
|---|---|
| R | Rating |
| ACS | Average combat score |
| K / D / A | Kills / deaths / assists |
| +/– | Kill differential |
| KAST | Kill/assist/survive/trade % |
| ADR | Damage per round |
| HS% | Headshot % |
| FK / FD / +/– | First kills / first deaths / differential |

- **All / Attack / Defend** segmented filter at the top (per-side splits).
- One table block per team, player rows with country flag, handle, and
  agent icon(s) played on that map.
- Data: `/v2/match/details` exposes per-map, per-player stats — extend
  `MapResult` with `[MapPlayerStats]` (two arrays or keyed by team) and add
  per-side variants for the Attack/Defend filter.
- UI: new `MapScoreboardView`, pushed (or expanded inline) from `MapCard`
  in `MatchDetailView`. Mock service should generate seeded player lines
  first so the screen is testable before API wiring.

## 3. Account settings

User profile and cross-device sync.

- Sign in with Apple first (native, no password UX), room for email later.
- Profile: username, avatar, favorite/secondary teams synced server-side —
  `FavoritesStore` becomes the local cache of a remote profile.
- New Settings section: account row, sign in/out, delete account (App Store
  requirement when accounts exist).
- Needs the first real backend piece (auth + small profile store). Design it
  together with #4 and #7, which need the same foundation.

## 4. Points & customization economy

Earn points, spend on cosmetic app customization.

- **Earn**: daily check-in, prediction mini-game on followed matches
  (pick winner before start), streaks for opening during favorite team's
  live games.
- **Spend**: alternate app icons, extra accent themes, team-branded app
  skins, profile badges/flair (ties into forums, #7).
- Balance + inventory server-side on the account from #3 (local-first is
  possible for v1 but invites resets/abuse).
- Keep it cosmetic-only — no pay-to-unlock of data features.

## 5. Push notifications for followed matches

Real background alerts (current build only fires local notifications while
the app is open — integration point documented in `NotificationManager`).

- Backend worker polls the self-hosted vlrggapi for followed teams' matches;
  sends APNs on: match starting soon, match live, match finished (+ score,
  optionally spoiler-free mode).
- "Important matches" beyond follows: playoffs/finals of major events as an
  opt-in topic subscription.
- App side: register device token, per-alert-type toggles in Settings
  (extend the existing `matchAlerts` toggle into a group).
- Keep local in-session haptic/alert path as-is; identifiers already use
  `live-{match_id}` so server payloads can dedupe against it.

## 6. Map artwork on map cards — ✅ DONE (gradient identity; bucket art hooks in)

Shipped: every map has a signature duotone banner (`MapArt.colors`) on map
cards and the scoreboard header — works offline, no licensing questions.
When the assets bucket is configured, cards automatically overlay real
splash art from `{bucket}/maps/{map}.jpg` (`MapArt.imageURL`).
Remaining nice-to-have: agent icons in `AgentChip` (host in the bucket too:
`{bucket}/agents/{agent}.png`).

## 7. Forums / discussion

Community discussion per match and per event.

- Structure: match threads (auto-created), event threads, general board.
- Post/reply, upvote, report; user identity + badges come from #3/#4.
- Moderation is the real cost: rate limits, block/report flows, and App
  Store UGC requirements (content flagging, user blocking) are mandatory.
- New tab or a section inside Match/Event detail ("Discussion") — start with
  match-thread-only inside `MatchDetailView` to avoid a 6th tab.

---

## Suggested order

| Phase | Items | Why |
|---|---|---|
| 0 | #0 API integration | ✅ done (client side) |
| A | #1 logos, #6 map art, #2 map scoreboard | ✅ done — remaining: populate assets bucket |
| B | #5 push | Needs small backend worker, no accounts |
| C | #3 accounts, #4 points | Shared auth/profile foundation |
| D | #7 forums | Depends on accounts + moderation tooling |
