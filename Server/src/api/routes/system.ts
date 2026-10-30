import type { FastifyInstance } from "fastify";
import type { HubConfig } from "../../config/config.js";
import { buildBootstrapCapabilities } from "../../config/config.js";
import type { ReadinessService } from "../../db/readiness.js";

export interface SystemRouteDependencies {
  readonly config: HubConfig;
  readonly hubVersion: string;
  readonly readiness: ReadinessService;
  readonly openApiDocument: Record<string, unknown>;
}

export function registerSystemRoutes(
  app: FastifyInstance,
  dependencies: SystemRouteDependencies
): void {
  app.get("/health", async (_request, reply) => {
    reply.header("cache-control", "no-store");
    return {
      status: "ok" as const,
      hubVersion: dependencies.hubVersion,
      uptimeSeconds: Math.floor(process.uptime()),
      checkedAt: new Date().toISOString()
    };
  });

  app.get("/ready", async (request, reply) => {
    reply.header("cache-control", "no-store");
    const report = await dependencies.readiness.check();
    if (!report.ready) {
      return reply.code(503).send({
        code: "NOT_READY",
        message: "Hub is not ready",
        retryable: true,
        requestId: request.id,
        details: {
          status: "not_ready",
          checkedAt: report.checkedAt,
          checks: report.checks
        }
      });
    }
    return {
      status: "ready" as const,
      checkedAt: report.checkedAt,
      requestId: request.id,
      checks: report.checks
    };
  });

  app.get("/v1/bootstrap", async (_request, reply) => {
    reply.header("cache-control", "no-store");
    return {
      apiVersion: "1" as const,
      hubVersion: dependencies.hubVersion,
      capabilities: buildBootstrapCapabilities(dependencies.config)
    };
  });

  app.get("/v1/openapi.json", async (_request, reply) => {
    reply.header("cache-control", "public, max-age=300");
    return reply
      .type("application/json; charset=utf-8")
      .send(dependencies.openApiDocument);
  });
}
