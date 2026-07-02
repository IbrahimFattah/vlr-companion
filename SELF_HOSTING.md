# Self-hosting vlrggapi + wiring the app to it

The core missing piece: swap mock data for the real
[vlrggapi](https://github.com/axsddlr/vlrggapi) (FastAPI scraper for vlr.gg),
running on our own server — the public instance
(`https://vlrggapi.vercel.app`) is down per the upstream README, so
self-hosting is the plan of record.

## Part 1 — Run the API on the server

### Option A: Docker (preferred)

```sh
git clone https://github.com/axsddlr/vlrggapi
cd vlrggapi
docker build -t vlrggapi .
docker run -d --name vlrggapi --restart unless-stopped -p 3001:3001 vlrggapi
```

`--restart unless-stopped` survives reboots and scraper crashes. Check the
upstream README/Dockerfile in case the port or entrypoint changed.

### Option B: bare Python (quick local testing)

```sh
git clone https://github.com/axsddlr/vlrggapi
cd vlrggapi
pip install -r requirements.txt
python main.py   # serves on 0.0.0.0:3001
```

### Verify

```sh
curl http://127.0.0.1:3001/v2/health
curl "http://127.0.0.1:3001/v2/match?q=live_score"
```

Expect the v2 envelope: `{"status": "success", "data": ...}`.

### Put HTTPS in front (recommended before the app ships anywhere)

Plain HTTP works for simulator testing but fights iOS ATS on device and is
bad practice anyway. One-liner with Caddy (auto-TLS via Let's Encrypt):

```
# Caddyfile
api.yourdomain.com {
    reverse_proxy 127.0.0.1:3001
}
```

(nginx + certbot equivalent works too.) With HTTPS in place, no ATS
exceptions are needed in the app at all.

### Operations notes

- **Rate limit**: 600 req/min built into the API — fine for personal use;
  the app's 30 s ticker + per-endpoint caching in v2 stays far below it.
- **It's a scraper**: breaks whenever vlr.gg changes markup. Symptoms:
  `status != success` or empty `data`. Fix = `git pull` + rebuild the image.
  Worth a daily cron hitting `/v2/health` (or an Uptime-Kuma check) so
  breakage is noticed before the app looks empty.
- **Logs**: `docker logs -f vlrggapi`.
- **Updates**: `git pull && docker build -t vlrggapi . && docker restart` —
  or set up Watchtower if lazy.

## Part 2 — Point the app at it

Everything below already has hooks in the codebase; no UI changes needed.

1. **Swap the service** — `VLRCompanionApp.swift`, `DataServiceKey`:

   ```swift
   static let defaultValue: any VLRDataService =
       CachingDataService(wrapping: VLRAPIService())
   ```

2. **Set the base URL** — Settings → Data source → API base URL
   (`apiBaseURL` defaults key, read by `AppConfig`). Default stays
   `http://127.0.0.1:3001` for simulator-against-local; enter
   `https://api.yourdomain.com` for the real server. Nothing is hardcoded.

3. **Implement response mapping** — each `VLRAPIService` method currently
   throws `notImplemented` and documents its endpoint. Work through them,
   decoding the v2 envelope (already handled by the private `get<T>` helper)
   into app models:
   - `matches(_:)` → `/v2/match?q=live_score|upcoming|results`
   - `matchDetail(id:)` → `/v2/match/details?match_id=`
   - `rankings(region:)` → `/v2/rankings?region=`
   - `playerStats(region:timespan:)` → `/v2/stats`
   - `events(_:)` → `/v2/events` (app "ongoing" → API "live")
   - `eventMatches(eventID:)` → `/v2/events/matches?event_id=`
   - `teamProfile(id:)` → `/v2/team?id=&q=profile` + `q=matches`
   - `news()` → `/v2/news`
   - `allTeams()` → aggregate `/v2/rankings` per region (also brings real
     team IDs + logo URLs → unlocks roadmap #1)

4. **ATS** — only if staying on plain HTTP to a remote host: add
   `NSAppTransportSecurity` exception to target Info settings. Skip
   entirely by doing the HTTPS step above. `http://127.0.0.1` from the
   simulator generally passes as local networking.

5. **Verify offline path** — `CachingDataService` already wraps the real
   service: load screens once, kill the server (or airplane-mode the
   device), relaunch — cached data should render everywhere.

### Suggested implementation order

`matches` → `matchDetail` → `rankings` → `allTeams` (real IDs matter for
My Team) → `teamProfile` → `events`/`eventMatches` → `news` → `playerStats`.
Ship each behind the same protocol; mock stays available for UI work by
flipping `DataServiceKey` back.
