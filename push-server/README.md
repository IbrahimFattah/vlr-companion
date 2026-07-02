# VLR Companion — Push Server

Background worker that turns match state changes on the self-hosted
[vlrggapi](https://github.com/axsddlr/vlrggapi) into APNs push notifications, so
the app can alert a user about a followed team **while it's closed**. The
in-app, foreground "your team is live" haptic/alert path lives in the app
itself (`NotificationManager`) and needs none of this.

## What it does

Every `POLL_INTERVAL` seconds it fetches live / upcoming / results from vlrggapi,
diffs against the last-seen state, and sends a push on each transition:

| Event | Fires when | Alert type key |
|---|---|---|
| Starting soon | upcoming match within 15 min of `unix_timestamp` | `startingSoon` |
| Live | match appears in `live_score` | `live` |
| Finished | match moves to `results` | `finished` |
| Major final | a "final" match goes live (topic, even for un-followed teams) | `majorFinals` |

Recipients are the devices whose registered followed-team set intersects the
match's two teams (major finals also reach topic subscribers who don't follow
either team). A per-device, per-alert-type toggle gates each one.

## Architecture

```
app/
  main.py       FastAPI: /register /unregister /health /test-push + poller lifespan
  poller.py     the diff-and-send loop
  vlr.py        async vlrggapi client (same endpoints/envelope as the iOS app)
  apns.py       token-based (.p8 / JWT ES256) APNs sender over HTTP/2
  store.py      SQLite: devices, match_state, sent-ledger (idempotent across restarts)
  identity.py   team slug + match-id helpers — MUST match the app's VLRAPIService
  config.py     env-var configuration
```

### Team identity contract

`identity.slug_id()` is a byte-for-byte mirror of the app's
`VLRAPIService.slugID` (`"name:" + folded/lowercased/alnum+space`). The app
registers its followed teams by that slug, so **follows only line up when the app
is on live data** (mock team ids like `sen` won't match). If the app's slug
logic ever changes, change it here too.

## Prerequisites (Apple)

Push requires a paid Apple Developer account:

1. Enable the **Push Notifications** capability for the app id `com.vlrcompanion.app`.
2. Create an **APNs Auth Key** (Keys → +→ Apple Push Notifications service).
   Download the `.p8` once → `push-server/secrets/AuthKey.p8`. Note its **Key ID**.
3. Grab your 10-character **Team ID**.

The app must be built onto a real device with that provisioning profile to get a
device token — the Simulator can't register for remote APNs (use `simctl push`
for local UI testing instead, below).

## Run

```bash
cd push-server
cp .env.example .env          # fill APNS_KEY_ID / APNS_TEAM_ID
mkdir -p secrets && cp /path/to/AuthKey.p8 secrets/AuthKey.p8
docker compose up --build     # brings up vlrggapi + push-server
curl localhost:8000/health
```

Point the app at it: **Settings → Data source → Push server URL** =
`https://push.yourdomain.com` (put it behind the same HTTPS reverse proxy as
vlrggapi — see the repo's `SELF_HOSTING.md`). The app POSTs `/register` on
launch, on token receipt, and whenever follows or alert toggles change.

### Verify APNs credentials

```bash
curl -X POST localhost:8000/test-push \
  -H 'content-type: application/json' \
  -d '{"token":"<device-hex-token>","environment":"sandbox"}'
```

`{"delivered": true}` means the key, Team ID, bundle id, and environment all
line up.

## Testing the app's tap handling without a device

The Simulator can render a push and exercise the deep-link handler via
`simctl push`:

```bash
xcrun simctl push booted com.vlrcompanion.app payload.apns
```

`payload.apns` should carry the same `match` object the server sends, e.g.:

```json
{
  "aps": { "alert": { "title": "Fnatic vs Team Heretics is live",
                      "body": "VCT EMEA · Playoffs" },
           "sound": "default", "category": "MATCH_ALERT" },
  "match": { "id": "12345", "team1": "Fnatic", "tag1": "FNC",
             "team2": "Team Heretics", "tag2": "TH",
             "event": "VCT EMEA", "stage": "Playoffs", "status": "live" }
}
```

Tapping it opens that match's detail screen (`PushRouter` → Home).

## Config reference

| Var | Default | Meaning |
|---|---|---|
| `VLRGGAPI_URL` | `http://vlrggapi:3001` | scraper API base |
| `APNS_KEY_ID` | — | APNs auth key id |
| `APNS_TEAM_ID` | — | Apple team id |
| `APNS_KEY_PATH` | `/secrets/AuthKey.p8` | mounted .p8 key |
| `APNS_BUNDLE_ID` | `com.vlrcompanion.app` | apns-topic |
| `APNS_DEFAULT_ENV` | `sandbox` | default token environment |
| `DB_PATH` | `/data/push.db` | SQLite path |
| `POLL_INTERVAL` | `30` | seconds between polls |
| `STARTING_SOON_WINDOW` | `900` | "starting soon" lead (s) |
