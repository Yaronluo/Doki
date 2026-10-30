import type { FastifyInstance } from "fastify";
import { afterEach, describe, expect, it } from "vitest";
import { z } from "zod";
import { createApp } from "../src/api/app.js";
import { buildOpenApiDocument } from "../src/contracts/openapi.js";
import type { ReadinessService } from "../src/db/readiness.js";
import { createLogger } from "../src/logging/logger.js";
import { configuredProviderEnv, testConfig } from "./helpers/test-config.js";
import { createCapturedLogger } from "./helpers/captured-logger.js";

const openApiDocument = buildOpenApiDocument({ hubVersion: "0.1.0" });
const silentLogger = createLogger({ level: "silent" });

const apps: FastifyInstance[] = [];

function track(app: FastifyInstance): FastifyInstance {
  apps.push(app);
  return app;
}

afterEach(async () => {
  await Promise.all(apps.splice(0).map(async (app) => app.close()));
});

function readyService(): ReadinessService {
  return {
    async check() {
      return {
        ready: true,
        checkedAt: "2026-10-30T00:00:00.000Z",
        checks: {
          config: { status: "ok" },
          database: { status: "ok" },
          migrations: { status: "ok", applied: 1, pending: 0 }
        }
      };
    }
  };
}

function notReadyService(): ReadinessService {
  return {
    async check() {
      return {
        ready: false,
        checkedAt: "2026-10-30T00:00:00.000Z",
        checks: {
          config: { status: "ok" },
          database: { status: "error", code: "DATABASE_UNAVAILABLE" },
          migrations: { status: "skipped" }
        }
      };
    }
  };
}

function appWith(
  readiness: ReadinessService,
  options: {
    readonly configuredProviders?: boolean;
    readonly logger?: ReturnType<typeof createLogger>;
  } = {}
): FastifyInstance {
  return track(
    createApp({
      config: testConfig(
        options.configuredProviders === true ? configuredProviderEnv : {}
      ),
      readiness,
      logger: options.logger ?? silentLogger,
      hubVersion: "0.1.0",
      openApiDocument
    })
  );
}

describe("system API", () => {
  it("serves liveness without touching the database", async () => {
    const app = appWith(notReadyService());
    const response = await app.inject({ method: "GET", url: "/health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      status: "ok",
      hubVersion: "0.1.0"
    });
    expect(response.headers["x-request-id"]).toMatch(/^req_/);
  });

  it("serves a structured ready response", async () => {
    const app = appWith(readyService());
    const response = await app.inject({ method: "GET", url: "/ready" });
    expect(response.statusCode).toBe(200);
    const body = response.json();
    expect(body).toMatchObject({
      status: "ready",
      checks: {
        config: { status: "ok" },
        database: { status: "ok" },
        migrations: { status: "ok", applied: 1, pending: 0 }
      }
    });
    expect(body.requestId).toBe(response.headers["x-request-id"]);
  });

  it("returns a structured 503 with checks when not ready", async () => {
    const app = appWith(notReadyService());
    const response = await app.inject({ method: "GET", url: "/ready" });
    expect(response.statusCode).toBe(503);
    const body = response.json();
    expect(body).toMatchObject({
      code: "NOT_READY",
      retryable: true,
      details: {
        status: "not_ready",
        checks: {
          config: { status: "ok" },
          database: { status: "error", code: "DATABASE_UNAVAILABLE" },
          migrations: { status: "skipped" }
        }
      }
    });
    expect(body.requestId).toBe(response.headers["x-request-id"]);
  });

  it("reports empty provider credentials as notConfigured", async () => {
    const app = appWith(readyService());
    const response = await app.inject({ method: "GET", url: "/v1/bootstrap" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      apiVersion: "1",
      hubVersion: "0.1.0",
      capabilities: {
        bangumi: { state: "notConfigured" },
        tmdb: { state: "notConfigured" },
        danmaku: { state: "notConfigured", provider: "dandanplay" }
      }
    });
  });

  it("reports configured but unverified providers as unavailable", async () => {
    const app = appWith(readyService(), { configuredProviders: true });
    const response = await app.inject({ method: "GET", url: "/v1/bootstrap" });
    expect(response.statusCode).toBe(200);
    expect(response.json().capabilities).toEqual({
      bangumi: { state: "unavailable" },
      tmdb: { state: "unavailable" },
      danmaku: { state: "unavailable", provider: "dandanplay" }
    });
  });

  it("serves the generated OpenAPI document without unimplemented routes", async () => {
    const app = appWith(readyService());
    const response = await app.inject({
      method: "GET",
      url: "/v1/openapi.json"
    });
    expect(response.statusCode).toBe(200);
    expect(response.headers["content-type"]).toContain("application/json");
    const document = response.json();
    expect(Object.keys(document.paths).sort()).toEqual([
      "/health",
      "/ready",
      "/s/{sessionId}/{resourceId}",
      "/v1/account",
      "/v1/account/collections",
      "/v1/artwork/tmdb/{filename}",
      "/v1/bootstrap",
      "/v1/calendar",
      "/v1/dev/source-preview",
      "/v1/devices/pairings",
      "/v1/devices/pairings/{id}",
      "/v1/devices/pairings/{id}/claim",
      "/v1/home",
      "/v1/openapi.json",
      "/v1/search",
      "/v1/subjects/{id}",
      "/v1/subjects/{id}/artwork",
      "/v1/subjects/{id}/characters",
      "/v1/subjects/{id}/episodes",
      "/v1/subjects/{id}/persons"
    ]);
    expect(document.components.schemas.PlaybackPlan).toBeDefined();
    expect(document.components.schemas.ProgressEvent).toBeDefined();
    expect(document.components.schemas.DanmakuLoad).toBeDefined();
  });

  it("returns the unified error body for 404", async () => {
    const app = appWith(readyService());
    const response = await app.inject({ method: "GET", url: "/v1/nope" });
    expect(response.statusCode).toBe(404);
    const body = response.json();
    expect(body).toMatchObject({
      code: "NOT_FOUND",
      message: "Route not found",
      retryable: false
    });
    expect(body.requestId).toBe(response.headers["x-request-id"]);
    expect(response.headers["x-request-id"]).toMatch(/^req_/);
  });

  it("does not expose unimplemented playback or danmaku routes", async () => {
    const app = appWith(readyService());
    for (const url of [
      "/v1/playback/sessions",
      "/v1/progress/events",
      "/v1/episodes/1/danmaku/mapping"
    ]) {
      const response = await app.inject({ method: "GET", url });
      expect(response.statusCode).toBe(404);
    }
  });

  it("does not register the development source preview in production", async () => {
    const app = track(
      createApp({
        config: testConfig({ NODE_ENV: "production" }),
        readiness: readyService(),
        logger: silentLogger,
        hubVersion: "0.1.0",
        openApiDocument
      })
    );
    const response = await app.inject({
      method: "POST",
      url: "/v1/dev/source-preview",
      payload: { query: "芙莉莲", episodeNumber: 1 }
    });
    expect(response.statusCode).toBe(404);
    expect(response.json().code).toBe("NOT_FOUND");
  });

  it("maps Zod validation failures to the unified error body", async () => {
    const app = appWith(readyService());
    app.get("/__test/validate", async (request) => {
      const parsed = z
        .object({ count: z.coerce.number().int().min(1) })
        .safeParse(request.query);
      if (!parsed.success) {
        throw parsed.error;
      }
      return parsed.data;
    });
    const response = await app.inject({
      method: "GET",
      url: "/__test/validate?count=0"
    });
    expect(response.statusCode).toBe(400);
    const body = response.json();
    expect(body).toMatchObject({
      code: "VALIDATION_ERROR",
      message: "Request validation failed",
      retryable: false,
      details: {
        issues: [{ path: "count" }]
      }
    });
    expect(body.requestId).toBe(response.headers["x-request-id"]);
  });

  it("returns a generic 500 and keeps request secrets out of logs", async () => {
    const secret = "super-secret-value-123456";
    const captured = createCapturedLogger([secret]);
    const app = appWith(readyService(), { logger: captured.logger });
    app.get("/__test/boom", async () => {
      throw new Error(`handler failed with ${secret}`);
    });
    const response = await app.inject({
      method: "GET",
      url: "/__test/boom",
      headers: {
        authorization: `Bearer ${secret}`,
        "x-hub-setup-secret": secret
      }
    });
    expect(response.statusCode).toBe(500);
    const body = response.json();
    expect(body).toMatchObject({
      code: "INTERNAL_ERROR",
      message: "Internal server error",
      retryable: true
    });
    expect(response.body).not.toContain(secret);
    expect(response.headers["x-request-id"]).toMatch(/^req_/);
    expect(captured.lines.join("")).not.toContain(secret);
    expect(captured.lines.join("")).not.toContain("x-hub-setup-secret");
    expect(captured.lines.join("")).not.toContain("authorization");
  });
});
