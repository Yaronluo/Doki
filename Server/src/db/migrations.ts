import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import type { Pool, PoolClient } from "pg";

export const MIGRATIONS_DIR = fileURLToPath(
  new URL("./migrations", import.meta.url)
);

const MIGRATION_FILE_PATTERN = /^(\d{4,})_([a-z0-9_]+)\.sql$/;
const MIGRATION_LOCK_ID = 734_001_001;

export interface MigrationFile {
  readonly version: string;
  readonly filename: string;
  readonly checksum: string;
  readonly sql: string;
}

export interface AppliedMigration {
  readonly version: string;
  readonly filename: string;
  readonly checksum: string;
  readonly appliedAt: Date;
}

export interface MigrationStatus {
  readonly migrations: readonly MigrationFile[];
  readonly applied: readonly AppliedMigration[];
  readonly pending: readonly string[];
  readonly checksumMismatches: readonly string[];
}

export interface MigrationRunResult {
  readonly applied: readonly string[];
  readonly skipped: readonly string[];
}

export class MigrationChecksumError extends Error {
  readonly version: string;

  constructor(version: string) {
    super(
      `Applied migration ${version} does not match its file checksum; refusing to continue`
    );
    this.name = "MigrationChecksumError";
    this.version = version;
  }
}

export class MigrationExecutionError extends Error {
  readonly version: string;

  constructor(version: string, cause: unknown) {
    const message =
      cause instanceof Error && cause.message.length > 0
        ? `Migration ${version} failed: ${cause.message}`
        : `Migration ${version} failed`;
    super(message, { cause });
    this.name = "MigrationExecutionError";
    this.version = version;
  }
}

export async function loadMigrations(
  directory: string = MIGRATIONS_DIR
): Promise<MigrationFile[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const files: MigrationFile[] = [];
  for (const entry of entries) {
    if (!entry.isFile()) {
      continue;
    }
    const match = MIGRATION_FILE_PATTERN.exec(entry.name);
    if (match === null) {
      continue;
    }
    const raw = await readFile(`${directory}/${entry.name}`, "utf8");
    const normalized = raw.replace(/\r\n/g, "\n");
    files.push({
      version: match[1] as string,
      filename: entry.name,
      checksum: createHash("sha256").update(normalized).digest("hex"),
      sql: normalized
    });
  }
  files.sort((a, b) => a.version.localeCompare(b.version));
  const seen = new Set<string>();
  for (const file of files) {
    if (seen.has(file.version)) {
      throw new Error(`Duplicate migration version ${file.version}`);
    }
    seen.add(file.version);
  }
  return files;
}

async function ensureMigrationsTable(client: PoolClient): Promise<void> {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version text PRIMARY KEY,
      filename text NOT NULL,
      checksum text NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT now()
    )
  `);
}

interface AppliedRow {
  version: string;
  filename: string;
  checksum: string;
  applied_at: Date;
}

async function readAppliedMigrations(
  client: Pick<PoolClient, "query">
): Promise<AppliedMigration[]> {
  const result = await client.query<AppliedRow>(
    `SELECT version, filename, checksum, applied_at
       FROM schema_migrations
      ORDER BY version ASC`
  );
  return result.rows.map((row) => ({
    version: row.version,
    filename: row.filename,
    checksum: row.checksum,
    appliedAt: row.applied_at
  }));
}

function isUndefinedTableError(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: unknown }).code === "42P01"
  );
}

export async function getMigrationStatus(
  pool: Pick<Pool, "query">,
  directory: string = MIGRATIONS_DIR
): Promise<MigrationStatus> {
  const migrations = await loadMigrations(directory);
  let applied: AppliedMigration[];
  try {
    applied = await readAppliedMigrations(pool as Pick<PoolClient, "query">);
  } catch (error) {
    if (isUndefinedTableError(error)) {
      return {
        migrations,
        applied: [],
        pending: migrations.map((migration) => migration.version),
        checksumMismatches: []
      };
    }
    throw error;
  }
  const appliedByVersion = new Map(
    applied.map((migration) => [migration.version, migration])
  );
  const pending = migrations
    .filter((migration) => !appliedByVersion.has(migration.version))
    .map((migration) => migration.version);
  const checksumMismatches = migrations
    .filter((migration) => {
      const row = appliedByVersion.get(migration.version);
      return row !== undefined && row.checksum !== migration.checksum;
    })
    .map((migration) => migration.version);
  return { migrations, applied, pending, checksumMismatches };
}

export async function runMigrations(
  pool: Pool,
  options: { readonly directory?: string } = {}
): Promise<MigrationRunResult> {
  const migrations = await loadMigrations(options.directory);
  const client = await pool.connect();
  const appliedVersions: string[] = [];
  const skippedVersions: string[] = [];
  try {
    await client.query("SELECT pg_advisory_lock($1)", [MIGRATION_LOCK_ID]);
    try {
      await ensureMigrationsTable(client);
      const applied = await readAppliedMigrations(client);
      const appliedByVersion = new Map(
        applied.map((migration) => [migration.version, migration])
      );
      for (const migration of migrations) {
        const existing = appliedByVersion.get(migration.version);
        if (existing !== undefined) {
          if (existing.checksum !== migration.checksum) {
            throw new MigrationChecksumError(migration.version);
          }
          skippedVersions.push(migration.version);
          continue;
        }
        try {
          await client.query("BEGIN");
          await client.query(migration.sql);
          await client.query(
            `INSERT INTO schema_migrations (version, filename, checksum)
             VALUES ($1, $2, $3)`,
            [migration.version, migration.filename, migration.checksum]
          );
          await client.query("COMMIT");
          appliedVersions.push(migration.version);
        } catch (error) {
          try {
            await client.query("ROLLBACK");
          } catch {
            // The connection may already be in a failed transaction state.
          }
          throw new MigrationExecutionError(migration.version, error);
        }
      }
    } finally {
      await client.query("SELECT pg_advisory_unlock($1)", [MIGRATION_LOCK_ID]);
    }
  } finally {
    client.release();
  }
  return { applied: appliedVersions, skipped: skippedVersions };
}
