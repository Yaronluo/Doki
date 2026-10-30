import { PgAuthStore } from "../src/auth/store.js";
import { AuthService } from "../src/auth/service.js";
import { randomUUID } from "node:crypto";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Pool } from "pg";
import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it
} from "vitest";
import {
  getMigrationStatus,
  loadMigrations,
  MigrationChecksumError,
  MigrationExecutionError,
  runMigrations
} from "../src/db/migrations.js";
import { createLogger } from "../src/logging/logger.js";
import { runWorkerOnce } from "../src/worker/queue.js";
import {
  createTestPool,
  resetPublicSchema,
  testDatabaseUrl
} from "./helpers/test-db.js";

const databaseUrl = testDatabaseUrl();
const describeWithDatabase = describe.skipIf(databaseUrl === undefined);
const logger = createLogger({ level: "silent", service: "doki-hub-test" });

interface SeedContext {
  readonly userId: string;
  readonly deviceId: string;
  readonly subjectId: number;
  readonly episodeId: number;
  readonly sessionId: string;
}

describeWithDatabase("Postgres migrations and constraints", () => {
  let pool: Pool;
  let seed: SeedContext;

  beforeAll(() => {
    pool = createTestPool(databaseUrl as string);
  });

  afterAll(async () => {
    await pool.end();
  });

  async function seedCore(): Promise<SeedContext> {
    const user = await pool.query<{ id: string }>(
      `INSERT INTO hub_user (display_name) VALUES ('Self-made Test Owner') RETURNING id`
    );
    const userId = user.rows[0]?.id;
    if (userId === undefined) {
      throw new Error("failed to seed user");
    }
    const device = await pool.query<{ id: string }>(
      `INSERT INTO device (user_id, name, token_hash)
       VALUES ($1, 'Test TV', $2) RETURNING id`,
      [userId, "a".repeat(64)]
    );
    const deviceId = device.rows[0]?.id;
    if (deviceId === undefined) {
      throw new Error("failed to seed device");
    }
    await pool.query(
      `INSERT INTO subject (bgm_subject_id, media_type, title)
       VALUES (900001, 'tv', 'Self-made Subject')`
    );
    await pool.query(
      `INSERT INTO episode (bgm_episode_id, bgm_subject_id, kind, sort_number, title)
       VALUES (900101, 900001, 'main', 1, 'Self-made Episode')`
    );
    await pool.query(
      `INSERT INTO provider (provider_id, display_name, implementation_version, enabled)
       VALUES ('test-provider', 'Test Provider', '1', true)`
    );
    await pool.query(
      `INSERT INTO source_subject (provider_id, source_subject_key, title)
       VALUES ('test-provider', 'subject-key', 'Self-made Source Subject')`
    );
    await pool.query(
      `INSERT INTO source_episode
         (provider_id, source_subject_id, media_id, source_subject_key, channel, title)
       SELECT 'test-provider', id, 'media-1', 'subject-key', 'main', 'Self-made Source Episode'
         FROM source_subject WHERE source_subject_key = 'subject-key'`
    );
    await pool.query(
      `INSERT INTO playback_session (id, user_id, device_id, bgm_episode_id, status)
       VALUES ('ps_test_session', $1, $2, 900101, 'ready')`,
      [userId, deviceId]
    );
    return {
      userId,
      deviceId,
      subjectId: 900001,
      episodeId: 900101,
      sessionId: "ps_test_session"
    };
  }

  beforeEach(async () => {
    await resetPublicSchema(pool);
    const result = await runMigrations(pool);
    expect(result.applied).toEqual(["0001", "0002"]);
    seed = await seedCore();
  });

  it("loads a checksummed migration file and creates every minimal table", async () => {
    const migrations = await loadMigrations();
    expect(migrations).toHaveLength(2);
    expect(migrations[0]?.version).toBe("0001");
    expect(migrations[0]?.checksum).toMatch(/^[0-9a-f]{64}$/);

    const tables = await pool.query<{ table_name: string }>(
      `SELECT table_name
         FROM information_schema.tables
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
        ORDER BY table_name`
    );
    const names = tables.rows.map((row) => row.table_name);
    expect(names).toEqual(
      expect.arrayContaining([
        "schema_migrations",
        "hub_user",
        "device",
        "pairing",
        "oauth_transaction",
        "oauth_credential",
        "subject",
        "episode",
        "external_binding",
        "episode_external_mapping",
        "provider",
        "source_subject",
        "source_episode",
        "subject_source_binding",
        "episode_source_mapping",
        "playback_session",
        "progress_event",
        "device_checkpoint",
        "episode_progress",
        "watch_state",
        "collection_intent",
        "upstream_snapshot",
        "user_sync_clock",
        "sync_change",
        "outbox",
        "sync_issue",
        "episode_danmaku_mapping",
        "danmaku_timing",
        "danmaku_preferences",
        "job",
        "provider_health"
      ])
    );
  });

  it("is idempotent and reports an unchanged checksum", async () => {
    const second = await runMigrations(pool);
    expect(second.applied).toEqual([]);
    expect(second.skipped).toEqual(["0001", "0002"]);
    const status = await getMigrationStatus(pool);
    expect(status.applied.map((migration) => migration.version)).toEqual([
      "0001", "0002"
    ]);
    expect(status.pending).toEqual([]);
    expect(status.checksumMismatches).toEqual([]);
  });

  it("claims a TV pairing exactly once under concurrent requests and stores only a token hash", async () => {
    const store = new PgAuthStore(pool);
    const service = new AuthService(store, Buffer.alloc(32, 17));
    const owner = await store.createOwner();
    const pairing = await service.createPairing("Self-made TV");
    await service.approve(pairing.code, owner);
    const results = await Promise.allSettled([service.claim(pairing.id, pairing.secret), service.claim(pairing.id, pairing.secret)]);
    const success = results.filter(r => r.status === "fulfilled");
    expect(success).toHaveLength(1);
    expect(results.filter(r => r.status === "rejected")).toHaveLength(1);
    const claimed = (success[0] as PromiseFulfilledResult<{deviceId:string;token:string}>).value;
    const stored = await pool.query<{token_hash:string}>("SELECT token_hash FROM device WHERE id=$1",[claimed.deviceId]);
    expect(stored.rows[0]!.token_hash).not.toBe(claimed.token);
    expect(await service.deviceUser(claimed.token)).toBe(owner);
    await pool.query("UPDATE device SET status='revoked',revoked_at=now() WHERE id=$1",[claimed.deviceId]);
    await expect(service.deviceUser(claimed.token)).rejects.toMatchObject({statusCode:401});
  });

  it("refuses to run when an applied migration checksum changed", async () => {
    await pool.query(
      `UPDATE schema_migrations SET checksum = 'deadbeef' WHERE version = '0001'`
    );
    await expect(runMigrations(pool)).rejects.toBeInstanceOf(
      MigrationChecksumError
    );
    const status = await getMigrationStatus(pool);
    expect(status.checksumMismatches).toEqual(["0001"]);
  });

  it("rolls back a failing migration and does not record it", async () => {
    const directory = await mkdtemp(join(tmpdir(), "doki-migrations-"));
    try {
      await writeFile(
        join(directory, "0003_bad.sql"),
        "CREATE TABLE should_rollback (id integer);\nSELECT 1 / 0;\n",
        "utf8"
      );
      await expect(
        runMigrations(pool, { directory })
      ).rejects.toBeInstanceOf(MigrationExecutionError);
      const table = await pool.query<{ exists: string | null }>(
        `SELECT to_regclass('public.should_rollback')::text AS exists`
      );
      expect(table.rows[0]?.exists).toBeNull();
      const recorded = await pool.query(
        `SELECT 1 FROM schema_migrations WHERE version = '0003'`
      );
      expect(recorded.rowCount).toBe(0);
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });

  it("enforces foreign keys and composite uniqueness", async () => {
    await expect(
      pool.query(
        `INSERT INTO episode (bgm_episode_id, bgm_subject_id, kind, sort_number)
         VALUES (999999, 123456789, 'main', 1)`
      )
    ).rejects.toMatchObject({ code: "23503" });

    await expect(
      pool.query(
        `INSERT INTO source_episode
           (provider_id, source_subject_id, media_id, source_subject_key)
         SELECT 'test-provider', id, 'media-1', 'subject-key'
           FROM source_subject WHERE source_subject_key = 'subject-key'`
      )
    ).rejects.toMatchObject({ code: "23505" });

    await expect(
      pool.query(
        `INSERT INTO device (user_id, name, token_hash)
         VALUES ($1, 'Duplicate TV', $2)`,
        [seed.userId, "a".repeat(64)]
      )
    ).rejects.toMatchObject({ code: "23505" });
  });

  it("enforces progress event uniqueness, ranges and duration bounds", async () => {
    const insertEvent = (input: {
      eventId?: string;
      deviceSeq: number;
      positionSeconds: string;
      durationSeconds?: string | null;
    }) =>
      pool.query(
        `INSERT INTO progress_event
           (event_id, session_id, device_id, device_seq, write_epoch, base_revision,
            bgm_episode_id, kind, position_seconds, duration_seconds, client_occurred_at)
         VALUES ($1, $2, $3, $4, 1, 0, $5, 'progress', $6, $7, now())`,
        [
          input.eventId ?? randomUUID(),
          seed.sessionId,
          seed.deviceId,
          input.deviceSeq,
          seed.episodeId,
          input.positionSeconds,
          input.durationSeconds ?? null
        ]
      );

    await insertEvent({
      deviceSeq: 1,
      positionSeconds: "12.5",
      durationSeconds: "1440"
    });
    await expect(
      insertEvent({
        deviceSeq: 1,
        positionSeconds: "13.5",
        durationSeconds: "1440"
      })
    ).rejects.toMatchObject({ code: "23505" });

    await expect(
      insertEvent({ deviceSeq: 2, positionSeconds: "-1" })
    ).rejects.toMatchObject({ code: "23514" });
    await expect(
      insertEvent({
        deviceSeq: 3,
        positionSeconds: "1440.1",
        durationSeconds: "1440"
      })
    ).rejects.toMatchObject({ code: "23514" });
  });

  it("stores danmaku IDs as checked int64 decimal strings", async () => {
    const insertMapping = (danmakuEpisodeId: string) =>
      pool.query(
        `INSERT INTO episode_danmaku_mapping
           (user_id, bgm_episode_id, danmaku_episode_id, source, verified)
         VALUES ($1, $2, $3, 'manual', true)`,
        [seed.userId, seed.episodeId, danmakuEpisodeId]
      );

    for (const invalid of [
      "abc",
      "09223372036854775807",
      "9223372036854775808",
      "-1"
    ]) {
      await expect(insertMapping(invalid)).rejects.toMatchObject({
        code: "23514"
      });
    }

    await insertMapping("9223372036854775807");
    await expect(insertMapping("123450001")).rejects.toMatchObject({
      code: "23505"
    });
  });

  it("claims a durable job with SKIP LOCKED semantics and records success", async () => {
    const inserted = await pool.query<{ id: string }>(
      `INSERT INTO job (kind, payload) VALUES ('hub.noop', '{}'::jsonb) RETURNING id`
    );
    const jobId = inserted.rows[0]?.id;
    expect(jobId).toBeDefined();

    const processed = await runWorkerOnce({
      pool,
      logger,
      workerId: "test-worker",
      handlers: new Map([
        [
          "hub.noop",
          async () => {
            // Self-made placeholder; no external calls.
          }
        ]
      ])
    });
    expect(processed).toBe(true);
    const job = await pool.query<{
      status: string;
      attempts: number;
      locked_by: string | null;
    }>(`SELECT status, attempts, locked_by FROM job WHERE id = $1`, [jobId]);
    expect(job.rows[0]).toMatchObject({
      status: "succeeded",
      attempts: 1,
      locked_by: null
    });
    expect(
      await runWorkerOnce({
        pool,
        logger,
        workerId: "test-worker",
        handlers: new Map()
      })
    ).toBe(false);
  });

  it("requeues a retryable handler failure and stops at max attempts", async () => {
    await pool.query(
      `INSERT INTO job (kind, payload, max_attempts)
       VALUES ('hub.retry', '{}'::jsonb, 2)`
    );
    const handlers = new Map([
      [
        "hub.retry",
        async () => {
          throw new Error("temporary self-made failure");
        }
      ]
    ]);
    expect(
      await runWorkerOnce({
        pool,
        logger,
        workerId: "test-worker",
        handlers
      })
    ).toBe(true);
    const first = await pool.query<{
      status: string;
      attempts: number;
      last_error_code: string;
    }>(
      `SELECT status, attempts, last_error_code FROM job WHERE kind = 'hub.retry'`
    );
    expect(first.rows[0]).toMatchObject({
      status: "queued",
      attempts: 1,
      last_error_code: "JOB_HANDLER_ERROR"
    });

    await pool.query(
      `UPDATE job SET run_at = now() WHERE kind = 'hub.retry'`
    );
    expect(
      await runWorkerOnce({
        pool,
        logger,
        workerId: "test-worker",
        handlers
      })
    ).toBe(true);
    const second = await pool.query<{ status: string; attempts: number }>(
      `SELECT status, attempts FROM job WHERE kind = 'hub.retry'`
    );
    expect(second.rows[0]).toMatchObject({ status: "failed", attempts: 2 });
  });

  it("fails an unsupported job kind without retrying forever", async () => {
    await pool.query(
      `INSERT INTO job (kind, payload) VALUES ('unknown.kind', '{}'::jsonb)`
    );
    expect(
      await runWorkerOnce({
        pool,
        logger,
        workerId: "test-worker",
        handlers: new Map()
      })
    ).toBe(true);
    const job = await pool.query<{
      status: string;
      last_error_code: string;
    }>(`SELECT status, last_error_code FROM job WHERE kind = 'unknown.kind'`);
    expect(job.rows[0]).toMatchObject({
      status: "failed",
      last_error_code: "JOB_KIND_UNSUPPORTED"
    });
  });
});
