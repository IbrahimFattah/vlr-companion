# VLR Companion — Roadmap

Features planned after the mock-data milestone. Ordered roughly by
dependency: items needing a backend/account system cluster together.

## 1. Real team logos

Replace monogram circles with actual team crests.

- `Team.logoURL` already exists and `TeamLogoView` already upgrades to
  `AsyncImage` when it's set — only the data side is missing.
- Source: vlrggapi returns logo URLs on rankings/team endpoints; populate
  during response mapping in `VLRAPIService`.
- Add disk/memory image caching (e.g. `URLCache` sizing or a tiny image cache)
  so logos render offline alongside the cached JSON.
- Watch dark backgrounds: many crests are black-on-transparent — keep the
  team-color circle as a backing plate.

## 2. Per-map player scoreboard (vlr.gg style)

Tapping a map card opens the full player stat table, like the website:

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

## 6. Map artwork on map cards

Make map cards visually richer (map splash/loading-screen art around the
map name, subtle darkened backdrop so scores stay readable).

- Bundle lightweight map art (Ascent, Bind, Haven, Lotus, Sunset, Abyss,
  Corrode…) or fetch from a CDN with caching; bundled is simpler and works
  offline.
- Apply to `MapCard` in match detail and the veto list; consider a thin
  map-art strip on the live match card ("Map 2 · Ascent").
- Also add agent icons to `AgentChip` (pairs with #2's scoreboard, which
  needs agent icons anyway).

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
| A | #1 logos, #6 map art, #2 map scoreboard | Pure client + existing API data; biggest visible win |
| B | #5 push | Needs small backend worker, no accounts |
| C | #3 accounts, #4 points | Shared auth/profile foundation |
| D | #7 forums | Depends on accounts + moderation tooling |
