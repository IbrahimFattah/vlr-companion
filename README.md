# VLR Companion

A native SwiftUI iOS companion for [VLR.gg](https://www.vlr.gg) — live Valorant esports
scores, match history, events, rankings, and a personalized tab for your favorite team.

Currently running entirely on **deterministic sample data** so every screen can be
exercised end-to-end. The data layer is a single protocol seam, ready to swap to a
self-hosted [vlrggapi](https://github.com/axsddlr/vlrggapi) instance.

## Run

1. Open `VLRCompanion.xcodeproj` in Xcode 16+.
2. Select the **VLRCompanion** scheme and an iOS 17+ simulator.
3. ⌘R.

Or from the command line:

```sh
xcodebuild -project VLRCompanion.xcodeproj -scheme VLRCompanion \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## App structure

- **Onboarding** — welcome → pick one favorite team (searchable, grouped by region)
  → optionally follow up to 3 secondary teams. Persisted via `FavoritesStore`
  (UserDefaults, full team JSON so My Team renders offline).
- **Home** — live ticker (auto-refreshes every 30 s), today's matches, recent
  results, headlines. A haptic + local notification fires when a followed team's
  match flips to live.
- **Matches** — Live / Upcoming / Results segments, day-grouped, countdowns.
- **My Team** — favorite-team tab tinted with the team's brand color: next-match
  hero, upcoming, results with W/L chips, roster grid, standing. Secondary teams
  are one tap away via the chip strip.
- **Events** — Ongoing / Upcoming / Completed tournaments → stage-grouped match
  lists.
- **Stats** — Team rankings (with movement indicators) and player stats
  (rating/ACS/K/D/KAST/ADR) behind one tab; region + timespan filters, search.
- **Match detail** — score hero, per-map breakdown with agent picks, map veto,
  head-to-head, stream/VOD links.

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
