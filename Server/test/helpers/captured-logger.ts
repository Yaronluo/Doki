import { createLogger, type Logger } from "../../src/logging/logger.js";

export interface CapturedLogger {
  readonly logger: Logger;
  readonly lines: string[];
}

export function createCapturedLogger(
  redactValues: readonly string[] = [],
  level = "debug"
): CapturedLogger {
  const lines: string[] = [];
  const logger = createLogger({
    level,
    service: "doki-hub-test",
    redactValues,
    destination: {
      write(chunk: string) {
        lines.push(chunk);
      }
    }
  });
  return { logger, lines };
}
