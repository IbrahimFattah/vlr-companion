# VLR Companion — Accounts + Forums API

Backend for roadmap #3 (accounts) and #7 (forums): user profiles, favorite-team
sync, and per-match / per-event discussion threads. FastAPI + SQLite, same shape
as `push-server/`.

## Auth

- **Now — dev login** (`POST /auth/dev`): passwordless, pick a username. Insecure
  by design (anyone can claim a free name); it exists so accounts + forums are
  testable before Sign in with Apple is available. Turn off with
  `ALLOW_DEV_AUTH=0`.
- **Later — Sign in with Apple** (`POST /auth/apple`): returns `501` until
  `APPLE_CLIENT_ID` is set. The verification code is stubbed in `auth.py`
  (validate the identity token against Apple's JWKs, upsert by `sub`). The app
  already sends the right payload — enabling it is server config, not a client
  change.

Requests authenticate with `Authorization: Bearer <token>` from the login
response.

## Endpoints

| Method | Path | Notes |
|---|---|---|
| POST | `/auth/dev` | `{username, avatarEmoji?, avatarColor?}` → `{token, user}` |
| POST | `/auth/apple` | Sign in with Apple (501 until configured) |
| GET | `/me` | profile |
| PATCH | `/me` | `{username?, avatarEmoji?, avatarColor?}` |
| DELETE | `/me` | delete account + all their content (cascade) |
| GET/PUT | `/me/favorites` | `{favorite, secondaries[≤3]}` — team slug ids |
| GET | `/threads/{scope}/{ref}/posts` | `scope`=`match`\|`event`\|`general`; `?limit=&before=` |
| POST | `/threads/{scope}/{ref}/posts` | `{body, parentId?}` (replies one level deep) |
| POST | `/posts/{id}/upvote` | toggle |
| POST | `/posts/{id}/report` | `{reason}` — auto-hides at threshold |
| DELETE | `/posts/{id}` | author soft-delete |
| POST/DELETE | `/users/{id}/block` | block / unblock (hides their posts from you) |
| DELETE | `/admin/posts/{id}` · POST `/admin/posts/{id}/unhide` | `X-Admin-Token` |

Thread `ref` matches the app's identifiers: match id (digit prefix of
`match_page`), event id, or `main` for the general board.

## App Store UGC requirements (roadmap #7)

Apps with user-generated content must ship: a **report** flow, **user
blocking**, a way to **remove** objectionable content, and a EULA with a
no-tolerance clause. This server covers report + block + author/admin delete +
auto-hide on repeated reports (`REPORT_HIDE_THRESHOLD`). The app must also:

- show a terms/no-tolerance notice + agree gate before first post,
- surface report + block in the post UI (done in `MatchDiscussion`),
- provide a moderator contact and act on reports within 24h.

## Run

```bash
cd api-server
python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt
DB_PATH=./data/api.db ADMIN_TOKEN=$(openssl rand -hex 24) \
  ./.venv/bin/uvicorn app.main:app --port 8080
# or: docker build -t vlr-api . && docker run -p 8080:8080 -v $PWD/data:/data vlr-api
```

Point the app at it: **Settings → Account → API server URL**
(`AppConfig.accountsBaseURL`). Deploy behind the same HTTPS proxy as the other
services (see repo `SELF_HOSTING.md`).

## Config

| Var | Default | Meaning |
|---|---|---|
| `DB_PATH` | `/data/api.db` | SQLite path |
| `ALLOW_DEV_AUTH` | `1` | enable passwordless username login |
| `APPLE_CLIENT_ID` | — | enables Sign in with Apple when set |
| `ADMIN_TOKEN` | — | unlocks `/admin/*` moderation |
| `REPORT_HIDE_THRESHOLD` | `3` | distinct reports before auto-hide |
| `POST_RATE_MAX` / `POST_RATE_WINDOW` | `8` / `60` | posts per user per window |
