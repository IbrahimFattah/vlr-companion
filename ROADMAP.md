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
scoreboards) and sample data (seeded lines).

Later polish (decided):
- **Agent portrait next to the player name** (left or right of the name,
  like vlr.gg) instead of the text label under it — icons served from the
  assets bucket (`{bucket}/agents/{agent}.png`), rendered in
  `MapScoreboardView.row` and reusable in `AgentChip`.
- **Actual map picture as the scoreboard/map-card background** — full-bleed
  splash art from `{bucket}/maps/{map}.jpg` behind a dark scrim (keep text
  contrast), replacing the duotone gradient once the bucket is populated.
  Hooks already exist (`MapArt.imageURL`); this is about switching from
  banner-strip overlay to full card/sheet-header background.
- All/Attack/Defend side splits — the scraper currently exposes only
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

## 3. Account settings — ✅ built (dev auth); Sign in with Apple pending Apple account

User profile and cross-device sync. Backend + app UI done; the only gap is the
real Apple auth path (portal-gated), which is stubbed and drops in by config.

**Backend (`api-server/`):** users, sessions (bearer tokens), profile (username
+ avatar emoji/color), favorite-team sync, delete-account (cascade). Dev
username login now; `/auth/apple` returns 501 until `APPLE_CLIENT_ID` is set
(verification skeleton in place).

**App:** `AccountStore` (@Observable, token in Keychain) + `AccountService`;
Settings → Account (sign in / edit profile / sign out / delete account);
`SignInView` with avatar picker and a disabled "Sign in with Apple — soon"
button. Favorites mirror to the server on change; `FavoritesStore` stays the
local cache. Verified in Simulator against a local `api-server`.

Remaining: enable Sign in with Apple (capability + `APPLE_CLIENT_ID`), turn off
dev auth (`ALLOW_DEV_AUTH=0`) for production.

## 4. Points & customization economy — ⏸ deferred (revisit after accounts + forums)

Earn points, spend on cosmetic app customization.

- **Earn**: daily check-in, prediction mini-game on followed matches
  (pick winner before start), streaks for opening during favorite team's
  live games.
- **Spend**: alternate app icons, extra accent themes, team-branded app
  skins, profile badges/flair (ties into forums, #7).
- Balance + inventory server-side on the account from #3 (local-first is
  possible for v1 but invites resets/abuse).
- Keep it cosmetic-only — no pay-to-unlock of data features.

## 5. Push notifications for followed matches — ✅ built, pending Apple account + deploy

Real background alerts. Both halves are built; what's left is operational
(a paid Apple Developer account + running the worker on the server).

**App side (done, verified in Simulator):**
- `AppDelegate` (via `UIApplicationDelegateAdaptor`) captures the APNs token,
  presents alerts in the foreground, and routes taps.
- Tapping an alert deep-links to the match: the payload's thin `match` object
  → `Match.fromPushPayload` → `PushRouter` → Home pushes the detail screen
  (verified headlessly with the `-vlrPushMatch <id>` debug hook).
- `NotificationManager` (now a shared `@Observable`): requests authorization,
  registers categories + remote, and POSTs token + followed teams + per-type
  prefs to the push worker; keeps the in-session haptic/local path.
- Settings: the single toggle became a Notifications group — Starting soon /
  Goes live / Final score / Major event finals — plus a Push server URL field.
- `VLRCompanion.entitlements` adds `aps-environment` (real-device only; the
  signing-free simulator build ignores it).

**Server side (done — `push-server/`):**
- FastAPI worker: `/register`, `/unregister`, `/health`, `/test-push`.
- Poller diffs vlrggapi live/upcoming/results every 30s and sends APNs on
  transitions: starting-soon (15-min lead), live, finished (+score), plus a
  major-finals topic for un-followed teams. Cold-start-safe (first sight of a
  match records state silently) and idempotent across restarts (sent ledger).
- Token-based APNs (.p8 / JWT ES256) over HTTP/2; SQLite store.
- `identity.slug_id` is a byte-for-byte mirror of the app's team slug, so
  follows target the right devices (only lines up on **live data**, not mock).
- Verified against the local vlrggapi: parsed real feeds (3 live / 33 upcoming
  / 50 results), correct recipient selection, silent cold start, `finished`
  payload `"Fnatic beat Paper Rex 3–1"`.

**Remaining (operational):**
- Apple: enable Push capability for `com.vlrcompanion.app`, make an APNs auth
  key, build to a real device for a token.
- Deploy `push-server` behind HTTPS next to vlrggapi; paste its URL in Settings.
- Optional later: spoiler-free mode, silent content-available refresh pushes
  (needs `UIBackgroundModes` = remote-notification, deferred).

## 6. Map artwork on map cards — ✅ DONE (gradient identity; bucket art hooks in)

Shipped: every map has a signature duotone banner (`MapArt.colors`) on map
cards and the scoreboard header — works offline, no licensing questions.
When the assets bucket is configured, cards automatically overlay real
splash art from `{bucket}/maps/{map}.jpg` (`MapArt.imageURL`).
Remaining nice-to-have: agent icons in `AgentChip` (host in the bucket too:
`{bucket}/agents/{agent}.png`).

## 7. Forums / discussion — ✅ built (match threads); event/general reuse ready

Community discussion per match (and reusable for event / general boards).

**Backend (`api-server/`):** `match|event|general` threads, posts + one-level
replies, upvote toggle, pagination cursor. UGC compliance: report flow with
auto-hide at a report threshold, user blocking (hides their posts), author
soft-delete, admin moderation (`X-Admin-Token`), per-user post rate limit.

**App:** `DiscussionView` (inline in `MatchDetailView` + standalone
`DiscussionScreen`), `PostRow` with avatar/upvote/reply and a report/block/
delete menu, composer that prompts sign-in, "Load more" paging. A **Community
tab** hosts the profile header + the general board (`scope:"general"`); Events
were folded into Matches to keep 5 tabs. Verified in Simulator (post, reply,
upvote, nested thread) against a local `api-server`.

Remaining: drop `DiscussionView(scope:"event",…)` into `EventDetailView`; show a
first-post terms gate + moderator contact for App Store review; wire real auth
(#3).

## 8. Incremental match loading (perf) — later

Right now each match list (`MatchesView`, Home sections) fetches and renders the
**whole** result set every load — the live-data feeds are large (50+ results,
30+ upcoming). It should show a first page and load the rest as the user scrolls.

- Data layer: add paging to `VLRDataService.matches(_:)` — page/offset or a
  cursor — with a `MatchQuery` limit. vlrggapi returns the full segment list per
  query, so the first cut can page **client-side** (slice the cached array) to
  get instant UI wins with no API change; a real server-side limit is a later
  upstream ask.
- UI: render the first ~15, append on scroll via `.onAppear` of the last row
  (or `List` + `.task`), with a footer skeleton while the next page loads.
  Keep `.refreshable` resetting to page 1.
- Applies to Matches (all three segments), Home "recent results", event match
  lists, and team match history.
- Caching: `CachingDataService` still stores the full payload; paging is a
  presentation concern over the cached array, so offline still works.

---

## Suggested order

| Phase | Items | Why |
|---|---|---|
| 0 | #0 API integration | ✅ done (client side) |
| A | #1 logos, #6 map art, #2 map scoreboard | ✅ done — remaining: populate assets bucket |
| B | #5 push | ✅ built (app + `push-server/`) — remaining: Apple account + deploy |
| C | #3 accounts | ✅ built (`api-server/` + app) — remaining: Sign in with Apple |
| D | #7 forums | ✅ built (match threads) — remaining: event/general + terms gate |
| — | #4 points | ⏸ deferred (user choice) — revisit after C+D |
| — | #8 incremental match loading | Perf polish, any time |
