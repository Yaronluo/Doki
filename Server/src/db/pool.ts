import pg from "pg";
import type { Pool } from "pg";

export type { Pool };

export interface CreatePoolOptions {
  readonly max?: number;
  readonly statementTimeoutMs?: number;
  readonly applicationName?: string;
}

export function createPool(
  databaseUrl: string,
  options: CreatePoolOptions = {}
): Pool {
  return new pg.Pool({
    connectionString: databaseUrl,
    max: options.max ?? 5,
    connectionTimeoutMillis: 3_000,
    idleTimeoutMillis: 30_000,
    statement_timeout: options.statementTimeoutMs ?? 5_000,
    application_name: options.applicationName ?? "doki-hub"
  });
}

export async function closePool(pool: Pool): Promise<void> {
  await pool.end();
}
