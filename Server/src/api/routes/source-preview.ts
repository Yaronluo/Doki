import type { FastifyInstance } from "fastify";
import { ApiHttpError } from "../errors.js";
import {
  sourcePreviewRequestSchema,
  type SourcePreviewPlan
} from "../../contracts/source-preview.js";
import { ProviderError } from "../../providers/types.js";
import type { SourcePreviewService } from "../../providers/source-preview.js";

export function registerSourcePreviewRoutes(
  app: FastifyInstance,
  service: SourcePreviewService
): void {
  app.post("/v1/dev/source-preview", async (request, reply) => {
    const input = sourcePreviewRequestSchema.parse(request.body);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 60_000);
    timer.unref();
    try {
      const plan: SourcePreviewPlan = await service.build(input, {
        requestId: request.id,
        signal: controller.signal
      });
      reply.header("cache-control", "no-store");
      return plan;
    } catch (error) {
      if (error instanceof ProviderError) {
        throw new ApiHttpError({
          statusCode: providerStatusCode(error.code),
          code: error.code,
          message: error.message,
          retryable: error.retryable,
          ...(error.details === undefined ? {} : { details: error.details })
        });
      }
      if (error instanceof Error && error.name === "AbortError") {
        throw new ApiHttpError({
          statusCode: 504,
          code: "SOURCE_PREVIEW_TIMEOUT",
          message: "源站解析超时",
          retryable: true
        });
      }
      throw error;
    } finally {
      clearTimeout(timer);
    }
  });
}

function providerStatusCode(code: string): number {
  switch (code) {
    case "SOURCE_SUBJECT_NOT_FOUND":
    case "SOURCE_EPISODES_EMPTY":
      return 404;
    case "SOURCE_ENCRYPTION_UNSUPPORTED":
    case "SOURCE_MEDIA_URL_UNMATCHED":
      return 422;
    case "SOURCE_QUERY_EMPTY":
      return 400;
    case "OUTBOUND_URL_BLOCKED":
      return 502;
    default:
      return 502;
  }
}
