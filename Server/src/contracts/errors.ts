import { z } from "zod";

export const apiErrorCodes = [
  "NOT_FOUND",
  "VALIDATION_ERROR",
  "INTERNAL_ERROR",
  "NOT_READY",
  "DEPENDENCY_NOT_CONFIGURED",
  "DEPENDENCY_UNAVAILABLE",
  "CONFLICT",
  "RATE_LIMITED"
] as const;

export type ApiErrorCode = (typeof apiErrorCodes)[number];

export const errorResponseSchema = z.object({
  code: z.string().min(1),
  message: z.string().min(1),
  retryable: z.boolean(),
  requestId: z.string().min(1),
  details: z.record(z.string(), z.unknown()).optional()
});

export type ErrorResponse = z.infer<typeof errorResponseSchema>;

export interface ApiErrorInput {
  readonly code: string;
  readonly message: string;
  readonly retryable: boolean;
  readonly details?: Record<string, unknown>;
}

export function makeErrorResponse(
  input: ApiErrorInput,
  requestId: string
): ErrorResponse {
  return input.details === undefined
    ? {
        code: input.code,
        message: input.message,
        retryable: input.retryable,
        requestId
      }
    : {
        code: input.code,
        message: input.message,
        retryable: input.retryable,
        requestId,
        details: input.details
      };
}
