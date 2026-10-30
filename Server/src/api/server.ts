import { ConfigValidationError, loadConfig } from "../config/config.js";
import { createPool } from "../db/pool.js";
import { createReadinessService } from "../db/readiness.js";
import { loggerForConfig } from "../logging/logger.js";
import { createApp } from "./app.js";

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

  const logger = loggerForConfig(config, {
    service: "doki-hub-api",
    level: config.environment === "test" ? "silent" : "info"
  });
  const pool = createPool(config.databaseUrl, {
    applicationName: "doki-hub-api"
  });
  const readiness = createReadinessService(pool, config);
  const app = createApp({ config, readiness, logger });

  let shuttingDown = false;
  const shutdown = async (signal: string): Promise<void> => {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    logger.info({ signal }, "api_shutdown_started");
    try {
      await app.close();
    } finally {
      await pool.end();
    }
    logger.info({ signal }, "api_shutdown_complete");
  };

  const handleSignal = (signal: string): void => {
    void shutdown(signal)
      .then(() => process.exit(0))
      .catch((error: unknown) => {
        logger.error({ err: error }, "api_shutdown_failed");
        process.exit(1);
      });
  };
  process.once("SIGINT", () => handleSignal("SIGINT"));
  process.once("SIGTERM", () => handleSignal("SIGTERM"));

  try {
    await app.listen({ host: config.hub.host, port: config.hub.port });
    logger.info(
      {
        host: config.hub.host,
        port: config.hub.port,
        baseUrl: config.hub.baseUrl,
        config: config.toJSON()
      },
      "api_listening"
    );
  } catch (error) {
    logger.fatal({ err: error }, "api_listen_failed");
    await pool.end();
    process.exitCode = 1;
  }
}

await main();
