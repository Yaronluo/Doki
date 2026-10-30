import { hostname } from "node:os";
import { randomUUID } from "node:crypto";
import { ConfigValidationError, loadConfig } from "../config/config.js";
import { getMigrationStatus } from "../db/migrations.js";
import { createPool } from "../db/pool.js";
import { createSecretRedactor, loggerForConfig } from "../logging/logger.js";
import { runWorkerLoop, type JobHandler } from "./queue.js";

async function main(): Promise<void> {
  const once = process.argv.includes("--once");
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

  const logger = loggerForConfig(config, {
    service: "doki-hub-worker",
    level: config.environment === "test" ? "silent" : "info"
  });
  const pool = createPool(config.databaseUrl, {
    applicationName: "doki-hub-worker"
  });
  const workerId = `worker_${hostname()}_${process.pid}_${randomUUID().slice(0, 8)}`;
  const redact = createSecretRedactor(config.secretValuesForLogRedaction());
  const abortController = new AbortController();
  const handlers = new Map<string, JobHandler>([
    [
      "hub.noop",
      async (job) => {
        logger.info({ jobId: job.id }, "noop_job_processed");
      }
    ]
  ]);

  let stopping = false;
  const requestStop = (signal: string): void => {
    if (stopping) {
      return;
    }
    stopping = true;
    logger.info({ signal, workerId }, "worker_shutdown_started");
    abortController.abort();
  };
  process.once("SIGINT", () => requestStop("SIGINT"));
  process.once("SIGTERM", () => requestStop("SIGTERM"));

  try {
    try {
      const migrationStatus = await getMigrationStatus(pool);
      if (
        migrationStatus.pending.length > 0 ||
        migrationStatus.checksumMismatches.length > 0
      ) {
        logger.warn(
          {
            applied: migrationStatus.applied.map((migration) => migration.version),
            pending: migrationStatus.pending,
            checksumMismatches: migrationStatus.checksumMismatches
          },
          "worker_schema_not_current"
        );
      }
    } catch (error) {
      logger.warn({ err: error }, "worker_schema_check_failed");
    }
    logger.info(
      {
        workerId,
        once,
        config: config.toJSON()
      },
      "worker_started"
    );
    await runWorkerLoop({
      pool,
      logger,
      workerId,
      handlers,
      once,
      signal: abortController.signal,
      redact
    });
    logger.info({ workerId }, "worker_stopped");
  } catch (error) {
    logger.error({ err: error, workerId }, "worker_failed");
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

await main();
