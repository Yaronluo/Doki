import { ConfigValidationError, loadConfig } from "../config/config.js";
import { createSecretRedactor } from "../logging/logger.js";
import { getMigrationStatus } from "./migrations.js";
import { createPool } from "./pool.js";

async function main(): Promise<void> {
  let config;
  try {
    config = loadConfig();
  } catch (error) {
    if (error instanceof ConfigValidationError) {
      console.error(
        JSON.stringify({ event: "config_invalid", issues: error.issues })
      );
    } else {
      console.error(JSON.stringify({ event: "config_error" }));
    }
    process.exitCode = 1;
    return;
  }

  const redact = createSecretRedactor(config.secretValuesForLogRedaction());
  const pool = createPool(config.databaseUrl, {
    applicationName: "doki-hub-migrate-status"
  });
  try {
    const status = await getMigrationStatus(pool);
    console.log(
      JSON.stringify({
        event: "migration_status",
        applied: status.applied.map((migration) => migration.version),
        pending: status.pending,
        checksumMismatches: status.checksumMismatches
      })
    );
  } catch (error) {
    const message =
      error instanceof Error ? redact(error.message) : "status failed";
    console.error(
      JSON.stringify({
        event: "migration_status_failed",
        error: {
          name: error instanceof Error ? error.name : "Error",
          message
        }
      })
    );
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

await main();
