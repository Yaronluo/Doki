import { AuthService } from "../auth/service.js";
import { PgAuthStore, type AuthStore } from "../auth/store.js";
import { createPool } from "../db/pool.js";
import { registerAuthRoutes } from "./routes/auth.js";
import { CatalogService } from "../metadata/catalog.js";
import { registerCatalogRoutes } from "./routes/catalog.js";
import { randomUUID } from "node:crypto";
import Fastify, {
  type FastifyBaseLogger,
  type FastifyInstance
} from "fastify";
import type { HubConfig } from "../config/config.js";
import type { ReadinessService } from "../db/readiness.js";
import { MediaRelay } from "../media/relay.js";
import { SourcePreviewService } from "../providers/source-preview.js";
import { YinghuaProvider } from "../providers/yinghua.js";
import type { MediaProvider } from "../providers/types.js";
import {
  createLogger,
  stripQueryString,
  type Logger
} from "../logging/logger.js";
import { readHubVersion } from "../version.js";
import { notFoundResponse, errorResponseFor } from "./errors.js";
import { loadOpenApiDocument } from "./openapi-file.js";
import { registerMediaRelayRoutes } from "./routes/media-relay.js";
import { registerSourcePreviewRoutes } from "./routes/source-preview.js";
import { registerSystemRoutes } from "./routes/system.js";

export interface AppDependencies {
  readonly config: HubConfig;
  readonly readiness: ReadinessService;
  readonly logger?: Logger;
  readonly hubVersion?: string;
  readonly openApiDocument?: Record<string, unknown>;
  readonly sourceProvider?: MediaProvider;
  readonly mediaRelay?: MediaRelay;
  readonly catalog?: CatalogService;
  readonly authStore?: AuthStore;
  readonly authService?: AuthService;
}

export function createApp(dependencies: AppDependencies): FastifyInstance {
  const logger =
    dependencies.logger ??
    createLogger({ level: "silent", service: "doki-hub-api" });
  const hubVersion = dependencies.hubVersion ?? readHubVersion();
  const openApiDocument =
    dependencies.openApiDocument ??
    loadOpenApiDocument(hubVersion, logger);

  const app = Fastify({
    // Pino's concrete Logger is narrower than FastifyBaseLogger in its type
    // definitions, while Fastify uses the same instance at runtime.
    loggerInstance: logger as unknown as FastifyBaseLogger,
    genReqId: () => `req_${randomUUID()}`,
    requestIdHeader: false,
    bodyLimit: 1_048_576,
    trustProxy: false
  });

  app.addHook("onRequest", async (request, reply) => {
    reply.header("x-request-id", request.id);
    reply.header("x-content-type-options", "nosniff");
  });

  app.addHook("onSend", async (request, reply, payload) => {
    reply.header("x-request-id", request.id);
    reply.header("x-content-type-options", "nosniff");
    return payload;
  });

  app.setNotFoundHandler((request, reply) => {
    return reply.code(404).send(notFoundResponse(request));
  });

  app.setErrorHandler((error, request, reply) => {
    const response = errorResponseFor(error, request.id);
    if (response.statusCode >= 500) {
      request.log.error(
        { err: error, requestId: request.id },
        "unhandled_request_error"
      );
    } else {
      request.log.warn(
        {
          requestId: request.id,
          code: response.body.code,
          path: stripQueryString(request.url)
        },
        "request_rejected"
      );
    }
    return reply.code(response.statusCode).send(response.body);
  });

  registerSystemRoutes(app, {
    config: dependencies.config,
    hubVersion,
    readiness: dependencies.readiness,
    openApiDocument
  });

  const authPool = dependencies.authStore || dependencies.authService ? undefined : createPool(dependencies.config.databaseUrl);
  const authService = dependencies.authService ?? new AuthService(dependencies.authStore ?? new PgAuthStore(authPool!), dependencies.config.credentialEncryptionKey);
  if(authPool) app.addHook("onClose", async()=>authPool.end());
  registerAuthRoutes(app,authService,dependencies.config);
  registerCatalogRoutes(app, dependencies.catalog ?? new CatalogService({ tmdb: dependencies.config.tmdb }));

  const relay =
    dependencies.mediaRelay ??
    new MediaRelay({
      signingKey: dependencies.config.streamSigningKey,
      hubBaseUrl: dependencies.config.hub.baseUrl
    });
  const sourceProvider =
    dependencies.sourceProvider ?? new YinghuaProvider();
  registerMediaRelayRoutes(app, relay);

  if (dependencies.config.environment !== "production") {
    registerSourcePreviewRoutes(
      app,
      new SourcePreviewService({ provider: sourceProvider, relay })
    );
  }

  return app;
}
