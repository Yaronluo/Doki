# Doki Hub (HUB-001)

TypeScript/Fastify/Zod modular-monolith skeleton for the Doki Hub API and worker.
Includes anonymous Bangumi metadata, public-map artwork without a TMDB key,
Hub browser website login, one-time TV pairing, and read-only account collection import (REWORK-002).
Real website captcha was fetched; full login has only synthetic protocol tests, not real-account acceptance.
This is not a deployed Hub and not a complete playback or
danmaku server.

## Runtime and dependency versions

Checked against the local machine on 2026-10-30:

| Tool / package | Version |
|---|---|
| Node.js | 24.22.1 |
| pnpm | 9.14.4 |
| PostgreSQL | 18.6 (Homebrew, isolated test cluster) |
| fastify | 5.12.7 |
| zod | 4.6.7 |
| pg | 8.23.1 |
| pino | 10.4.0 |
| cheerio | 1.2.0 |
| typescript | 5.9.3 |
| tsx | 4.23.15 |
| vitest | 5.0.5 |
| @types/node | 24.19.2 |
| @types/pg | 8.23.1 |

`package.json` pins exact versions; `pnpm-lock.yaml` locks the transitive tree.
The project is ESM and requires Node `>=24.22.1 <25`.

## Commands

```sh
pnpm install --frozen-lockfile
pnpm typecheck
pnpm openapi
pnpm test                 # DB integration tests need TEST_DATABASE_URL
pnpm build
pnpm db:migrate
pnpm start:api
pnpm start:worker -- --once
```

Database-backed tests use a disposable local Postgres. One reproducible setup:

```sh
BASE=/Users/yaron/Doki/.local/postgres-hub
initdb -D "$BASE" -U postgres --auth=trust --no-locale --encoding=UTF8
pg_ctl -D "$BASE" -o "-p 55432 -k $BASE -c listen_addresses=127.0.0.1" \
  -l /Users/yaron/Doki/.local/logs/postgres-hub.log start
createdb -h 127.0.0.1 -p 55432 -U postgres doki_hub_test
TEST_DATABASE_URL='postgres://postgres@127.0.0.1:55432/doki_hub_test' pnpm test
```

The tests drop and recreate the `public` schema of the database named in
`TEST_DATABASE_URL`. Never point that variable at a database you want to keep.
Stop the test cluster with:

```sh
pg_ctl -D /Users/yaron/Doki/.local/postgres-hub stop
```

## Configuration

Configuration comes from process environment only. There is no `.env` loader and
no checked-in secret. The root `.env.example` lists the planned key names.

Required:

- `HUB_BASE_URL` — `https://` URL (plain `http://` is accepted only for
  loopback development), no credentials/query/fragment.
- `DATABASE_URL` — `postgres://` or `postgresql://` URL with a database name.
- `CREDENTIAL_ENCRYPTION_KEY` — base64-encoded exactly 32 bytes.
- `STREAM_SIGNING_KEY` — base64-encoded exactly 32 bytes.

Optional / grouped:

- `HUB_HOST` (default `127.0.0.1`), `HUB_PORT` (default `8080`), `NODE_ENV`.
- `REDIS_URL` — parsed and validated but **not used** in HUB-001. No Redis or
  BullMQ client is installed. The worker uses the Postgres `job` table.
- `HUB_SETUP_SECRET` — optional; if present, at least 32 characters. Empty means
  registration/recovery is restricted to the Hub loopback browser; remote setup requires this secret.
- Bangumi group: `BGM_CLIENT_ID`, `BGM_CLIENT_SECRET`, `BGM_REDIRECT_URI` — all
  three or none.
- TMDB: `TMDB_READ_ACCESS_TOKEN`.
- dandanplay group: `DANDANPLAY_APP_ID`, `DANDANPLAY_APP_SECRET` — both or none.

Invalid or partial configuration fails startup with a sanitized issue list.
Secrets are private fields, never enumerable, and `JSON.stringify(config)` returns
a redacted summary. Request logs include a generated `x-request-id` and strip
query strings and sensitive headers; error/stack text is redacted with known
secret values.

Capability semantics in HUB-001:

- empty provider credentials → `notConfigured`;
- credentials present but never verified → `unavailable`;
- `ready` is not claimed by static bootstrap. Anonymous catalog reads do make real Bangumi requests; artwork makes optional TMDB calls. dandanplay remains unintegrated.

## API routes implemented

| Method | Path | Notes |
|---|---|---|
| GET | `/health` | Liveness only, always 200 while the process runs |
| GET | `/ready` | Checks config, Postgres and applied migrations; structured 503 when not ready |
| GET | `/v1/bootstrap` | `apiVersion`, `hubVersion`, provider capabilities |
| GET | `/v1/openapi.json` | Serves the generated OpenAPI 3.1 document |
| POST | `/v1/dev/source-preview` | **Development only**; resolves the fixed `yinghua` provider and returns a signed relay plan |
| GET/HEAD | `/s/{sessionId}/{resourceId}` | Signed HLS playlist/segment relay; Range/HEAD; HMAC + expiry |

All errors use `{code,message,retryable,requestId,details?}`. `requestId` is also
returned in the `x-request-id` header. Zod validation failures become
`VALIDATION_ERROR` with path/message issues. Unknown routes are `NOT_FOUND`.

The development source preview/relay is registered only when `NODE_ENV !=
production`. It is not a Bangumi-bound PlaybackSession and has no epoch/revision
or persistent progress semantics. Relay sessions live in process memory with a
2-hour TTL.

Not implemented (schemas exist in `openapi.json` for client/adapter work only):
setup/pairing/OAuth routes, metadata routes, playback sessions, progress writes,
sync, source mappings and all danmaku routes. They are deliberately absent from
`paths`.

## Migrations

`src/db/migrations/0001_initial.sql` is applied by a small custom runner; no ORM
creates tables. The runner:

- orders `NNNN_name.sql` files;
- stores `version`, `filename`, `checksum` and `applied_at` in `schema_migrations`;
- takes a Postgres advisory lock;
- applies each pending migration in its own transaction;
- refuses to continue if an applied migration's file checksum changed;
- is idempotent (a second run reports `skipped`).

The schema covers identity/device/pairing/OAuth transactions, metadata and
external bindings, providers and source mappings, playback sessions/events/
checkpoints, watch state, sync clock/changes/outbox/issues, danmaku mapping/
timing/preferences and durable jobs/provider health. Danmaku int64 IDs are text
columns with canonical decimal and signed-64-bit range checks; progress positions
have finite/range/duration constraints.

## Worker

`pnpm start:worker` runs a separate process that loads the same config, logger and
database code. It polls `job` with `FOR UPDATE SKIP LOCKED`, supports a
`hub.noop` placeholder handler, requeues stale running jobs, and stops cleanly on
SIGINT/SIGTERM. `--once` processes at most one available job and exits 0 when the
queue is empty. Unknown job kinds fail with `JOB_KIND_UNSUPPORTED`; no Redis/BullMQ
behavior is simulated.

## Real-source development preview

The fixed online.json snapshot used for SRC-001 has sha256
`7e54969e4d8de3535242927af3c27e09a8e8d47f65ab9649a84a2163c975535c`. Only the
`yinghua` (樱花动漫) rule is adapted: search CSS, channel/episode CSS, `第…集`
regex and `player_aaaa` encrypt=0. The provider refuses encrypt=3/browser-only
rules instead of silently accepting them.

```sh
export NODE_ENV=development
export OUTBOUND_ALLOW_BENCHMARK_NETWORK=1   # local transparent proxy only
curl -sS -X POST http://127.0.0.1:18080/v1/dev/source-preview \
  -H 'Content-Type: application/json' \
  -d '{"query":"葬送的芙莉莲","episodeNumber":1}'
```

Local real request: preview 200 in ~4.94s; relay master/variant/segment
200/200/206; bad signature 403. **The real stream contained third-party gambling
advertising around 03:03.** It is a technical adapter/relay proof, not an approved
product source; do not enable it for delivery, default playback or public
deployment. Real video frames/raw fetched media were deleted from local evidence.

SafeFetcher validates scheme, port, credentials, hostname, every redirect and
resolved IP; loopback/RFC1918/link-local are blocked. The 198.18.0.0/15 allowance
requires the explicit local environment flag and is not production hardening.
IP pinning/egress proxy remains OPS-001.

## Evidence boundary

HUB-001 was built and tested locally against an isolated Postgres 18.6 cluster.
Real-source preview did make outbound requests to the configured yinghua source;
no Bangumi, TMDB or dandanplay credentials were used and those APIs were not
called. Setup/pairing/OAuth, formal playback sessions, progress/sync and danmaku
routes remain for later tasks.

## REWORK-001 public metadata

See [local setup and credential sources](../docs/development/INTEGRATIONS_SETUP.md).
`/v1/home`, `/v1/calendar`, `/v1/search`, subject/episode/character/staff reads and optional TMDB artwork are implemented. No account token is required for public Bangumi reads. Schemas and OpenAPI are generated from `src/contracts/catalog.ts`; these raw public Bangumi payloads deliberately preserve upstream field spellings. No account, playback-session, sync or danmaku route is implied.

From the repository root `python3 scripts/init-local-config.py` creates private local defaults without printing secrets or overwriting an existing config. In Server use `node --env-file=../.env dist/api/server.js` after build. Database readiness is independent of metadata availability. For the local transparent-proxy network only, the documented benchmark-network switch is necessary; never use it in production.
