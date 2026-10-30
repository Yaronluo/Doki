import type { Pool } from "pg";
import type { HubConfig } from "../config/config.js";
import type {
  ReadinessChecks,
  ReadinessCheck
} from "../contracts/health.js";
import { getMigrationStatus } from "./migrations.js";

export interface ReadinessReport {
  readonly ready: boolean;
  readonly checkedAt: string;
  readonly checks: ReadinessChecks;
}

export interface ReadinessService {
  check(): Promise<ReadinessReport>;
}

async function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number
): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  try {
    return await Promise.race([
      promise,
      new Promise<never>((_resolve, reject) => {
        timer = setTimeout(() => {
          reject(new Error("timeout"));
        }, timeoutMs);
      })
    ]);
  } finally {
    if (timer !== undefined) {
      clearTimeout(timer);
    }
  }
}

export function createReadinessService(
  pool: Pool,
  config: HubConfig
): ReadinessService {
  return {
    async check(): Promise<ReadinessReport> {
      const checkedAt = new Date().toISOString();
      const configValid =
        config.credentialEncryptionKey.length === 32 &&
        config.streamSigningKey.length === 32 &&
        config.hub.baseUrl.length > 0;
      const checks: {
        config: ReadinessCheck;
        database: ReadinessCheck;
        migrations: ReadinessCheck;
      } = {
        config: configValid
          ? { status: "ok" }
          : { status: "error", code: "CONFIG_INVALID" },
        database: { status: "skipped" },
        migrations: { status: "skipped" }
      };
      if (!configValid) {
        return { ready: false, checkedAt, checks };
      }

      try {
        await withTimeout(pool.query("SELECT 1"), 3_000);
        checks.database = { status: "ok" };
      } catch {
        checks.database = {
          status: "error",
          code: "DATABASE_UNAVAILABLE"
        };
        return {
          ready: false,
          checkedAt,
          checks
        };
      }

      try {
        const status = await withTimeout(getMigrationStatus(pool), 5_000);
        if (status.checksumMismatches.length > 0) {
          checks.migrations = {
            status: "error",
            code: "MIGRATION_CHECKSUM_MISMATCH",
            applied: status.applied.length,
            pending: status.pending.length,
            pendingVersions: status.pending.slice(0, 50)
          };
        } else if (status.pending.length > 0) {
          checks.migrations = {
            status: "error",
            code: "MIGRATIONS_PENDING",
            applied: status.applied.length,
            pending: status.pending.length,
            pendingVersions: status.pending.slice(0, 50)
          };
        } else {
          checks.migrations = {
            status: "ok",
            applied: status.applied.length,
            pending: 0
          };
        }
      } catch {
        checks.migrations = {
          status: "error",
          code: "MIGRATION_STATUS_UNAVAILABLE"
        };
      }

      return {
        ready:
          checks.config.status === "ok" &&
          checks.database.status === "ok" &&
          checks.migrations.status === "ok",
        checkedAt,
        checks
      };
    }
  };
}
