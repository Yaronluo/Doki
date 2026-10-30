import type { FastifyInstance } from "fastify";
import { ApiHttpError } from "../errors.js";
import {
  ProviderError
} from "../../providers/types.js";
import type { MediaRelay } from "../../media/relay.js";

interface RelayParams {
  sessionId: string;
  resourceId: string;
}

interface RelayQuery {
  exp?: string;
  sig?: string;
}

export function registerMediaRelayRoutes(
  app: FastifyInstance,
  relay: MediaRelay
): void {
  app.route<{ Params: RelayParams; Querystring: RelayQuery }>({
    method: ["GET", "HEAD"],
    url: "/s/:sessionId/:resourceId",
    handler: async (request, reply) => {
      const exp = Number(request.query.exp);
      const sig = request.query.sig;
      if (
        !Number.isSafeInteger(exp) ||
        exp <= 0 ||
        typeof sig !== "string" ||
        sig.length === 0
      ) {
        throw new ApiHttpError({
          statusCode: 403,
          code: "MEDIA_URL_INVALID",
          message: "媒体地址无效",
          retryable: false
        });
      }
      try {
        const result = await relay.handle({
          sessionId: request.params.sessionId,
          resourceId: request.params.resourceId,
          exp,
          sig,
          method: request.method === "HEAD" ? "HEAD" : "GET",
          ...(request.headers.range === undefined ? {} : { range: request.headers.range })
        });
        reply.code(result.statusCode);
        for (const [key, value] of Object.entries(result.headers)) {
          reply.header(key, value);
        }
        if (result.body === null) {
          return reply.send();
        }
        return reply.send(result.body);
      } catch (error) {
        if (error instanceof ProviderError) {
          throw new ApiHttpError({
            statusCode: mediaStatusCode(error.code),
            code: error.code,
            message: error.message,
            retryable: error.retryable,
            ...(error.details === undefined ? {} : { details: error.details })
          });
        }
        throw error;
      }
    }
  });
}

function mediaStatusCode(code: string): number {
  switch (code) {
    case "MEDIA_URL_INVALID":
      return 403;
    case "MEDIA_SESSION_NOT_FOUND":
    case "MEDIA_RESOURCE_NOT_FOUND":
      return 404;
    default:
      return 502;
  }
}
