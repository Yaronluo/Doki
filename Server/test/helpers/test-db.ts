import { createPool, type Pool } from "../../src/db/pool.js";

export function testDatabaseUrl(): string | undefined {
  return process.env.TEST_DATABASE_URL;
}

export function createTestPool(databaseUrl: string): Pool {
  return createPool(databaseUrl, {
    applicationName: "doki-hub-tests",
    max: 4,
    statementTimeoutMs: 30_000
  });
}

export async function resetPublicSchema(pool: Pool): Promise<void> {
  await pool.query("DROP SCHEMA IF EXISTS public CASCADE");
  await pool.query("CREATE SCHEMA public");
}
