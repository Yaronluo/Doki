import { readFileSync } from "node:fs";
import { buildOpenApiDocument } from "../contracts/openapi.js";
import type { Logger } from "../logging/logger.js";

export function loadOpenApiDocument(
  hubVersion: string,
  logger: Logger
): Record<string, unknown> {
  try {
    const raw = readFileSync(
      new URL("../../openapi.json", import.meta.url),
      "utf8"
    );
    const parsed = JSON.parse(raw) as unknown;
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("openapi.json is not an object");
    }
    return parsed as Record<string, unknown>;
  } catch (error) {
    logger.warn(
      { err: error },
      "openapi.json unavailable; serving generated document"
    );
    return buildOpenApiDocument({ hubVersion });
  }
}
