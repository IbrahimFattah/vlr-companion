# VLR Companion

A native SwiftUI iOS companion for [VLR.gg](https://www.vlr.gg) — live Valorant esports
scores, match history, events, rankings, and a personalized tab for your favorite team.

Two data sources behind one protocol seam, switchable in Settings → Data source
("Live data" toggle, applies on relaunch):

- **Sample data** (default) — deterministic mock, every screen works offline.
- **Live data** — a self-hosted [vlrggapi](https://github.com/axsddlr/vlrggapi)
  instance (`VLRAPIService`, fully implemented). Setup: see `SELF_HOSTING.md`.
  Both sources sit behind a disk cache, so the app still renders when the
  server (or the network) is down.

## Run

1. Open `VLRCompanion.xcodeproj` in Xcode 16+.
2. Select the **VLRCompanion** scheme and an iOS 17+ simulator.
3. ⌘R.

Or from the command line:

```sh
xcodebuild -project VLRCompanion.xcodeproj -scheme VLRCompanion \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Backend services (local dev)

Three optional self-hosted services live in this repo. The app runs fully
without them (sample data, no accounts); each adds a feature when its URL is set
in **Settings → Data source**.

| Service | Dir | Port | Powers |
|---|---|---|---|
| vlrggapi | (external clone) | 3001 | live scores/stats (`VLRAPIService`) |
| Accounts + forums | `api-server/` | 8080 | sign-in, profile, discussion |
| Push worker | `push-server/` | 8000 | background match alerts (needs Apple acct) |

### Start the accounts + forums API

```sh
cd api-server
python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt
DB_PATH=./data/api.db ALLOW_DEV_AUTH=1 \
  ./.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8080
# health check:
curl http://127.0.0.1:8080/health
```

Then in the app: **Settings → Data source → API server URL** =
`http://127.0.0.1:8080`, and **Settings → Account → Sign in** (username login;
Sign in with Apple arrives with `APPLE_CLIENT_ID`). Docker + full config +
production notes: **[api-server/README.md](api-server/README.md)**. The other
two services are covered in `SELF_HOSTING.md` (Parts 1–3) and their own READMEs.

## App structure

- **Onboarding** — welcome → pick one favorite team (searchable, grouped by region)
  → optionally follow up to 3 secondary teams. Persisted via `FavoritesStore`
  (UserDefaults, full team JSON so My Team renders offline).
- **Home** — live ticker (auto-refreshes every 30 s), today's matches, recent
  results, headlines. A haptic + local notification fires when a followed team's
  match flips to live.
- **Matches** — Live / Upcoming / Results / **Events** segments. The first three
  are day-grouped match lists with countdowns; Events lists Ongoing / Upcoming /
  Completed tournaments → stage-grouped matches.
- **My Team** — favorite-team tab tinted with the team's brand color: next-match
  hero, upcoming, results with W/L chips, roster grid, standing. Secondary teams
  are one tap away via the chip strip.
- **Community** — your profile (avatar + username) over the general discussion
  board; needs the API server + sign-in. Match/event threads live in their
  detail screens.
- **Stats** — Team rankings (with movement indicators) and player stats
  (rating/ACS/K/D/KAST/ADR) behind one tab; region + timespan filters, search.
- **Match detail** — score hero, per-map breakdown with agent picks, map veto,
  head-to-head, stream/VOD links, and a discussion thread.

## Architecture

```
Views ──▶ @Environment(\.dataService): VLRDataService (protocol)
                    │
                    ├── MockVLRDataService   ← ACTIVE (MockData.swift, seeded, relative dates)
                    ├── VLRAPIService        ← vlrggapi client stub (all /v2 endpoints mapped)
                    └── CachingDataService   ← decorator: disk cache + offline fallback
```

- `Loadable<T>` drives skeleton → content → error states on every screen.
- `CachingDataService` writes every successful response to `Caches/VLRCache/` and
  serves the last good copy when the source fails → offline support.
- Red (`#FF4655`) is reserved exclusively for live states. My Team re-tints to the
  team's `colorHex`. Dark mode is the default; light/system available in Settings.

## Wiring the real API (vlrggapi)

The hosted instance (`https://vlrggapi.vercel.app`) is down per the upstream README —
this app assumes a **self-hosted** instance (Docker or `python main.py`), default
`http://127.0.0.1:3001`.

1. In `VLRCompanionApp.swift`, change `DataServiceKey.defaultValue` to
   `CachingDataService(wrapping: VLRAPIService())`.
2. Implement the response mapping in each `VLRAPIService` method — every method
   already documents its endpoint, and the `Envelope` decoder handles the v2
   `{"status": "success", "data": ...}` wrapper. Rate limit: 600 req/min.
3. Base URL is configurable at runtime in Settings → Data source (stored under the
   `apiBaseURL` defaults key, read by `AppConfig`). Nothing in the UI hardcodes a host.
4. **ATS**: plain-HTTP hosts need an exception. Add to the target's Info settings:
   `NSAppTransportSecurity` → `NSAllowsLocalNetworking: YES` (local nets), or a
   per-domain exception for a remote HTTP server. Prefer HTTPS in production.
5. **Push**: `NotificationManager` currently schedules local notifications while the
   app is open. Match-start alerts with the app closed require APNs from the backend —
   the integration point is documented in `NotificationManager.swift`.

### Endpoint map

| App call | vlrggapi endpoint |
|---|---|
| `matches(.live/.upcoming/.results)` | `GET /v2/match?q=live_score\|upcoming\|results` |
| `matchDetail(id:)` | `GET /v2/match/details?match_id=` |
| `rankings(region:)` | `GET /v2/rankings?region=` |
| `playerStats(region:timespan:)` | `GET /v2/stats?region=&timespan=` |
| `events(_:)` | `GET /v2/events?q=` (app "ongoing" → API "live") |
| `eventMatches(eventID:)` | `GET /v2/events/matches?event_id=` |
| `teamProfile(id:)` | `GET /v2/team?id=&q=profile` (+ `q=matches`) |
| `news()` | `GET /v2/news` |
| `allTeams()` | aggregate `/v2/rankings` per region, or `/v2/search?q=` |
