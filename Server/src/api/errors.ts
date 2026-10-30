import type { FastifyReply, FastifyRequest } from "fastify";
import { ZodError } from "zod";
import { makeErrorResponse, type ErrorResponse } from "../contracts/errors.js";

export class ApiHttpError extends Error {
  readonly statusCode: number;
  readonly code: string;
  readonly retryable: boolean;
  readonly details: Record<string, unknown> | undefined;

  constructor(input: {
    statusCode: number;
    code: string;
    message: string;
    retryable: boolean;
    details?: Record<string, unknown>;
  }) {
    super(input.message);
    this.name = "ApiHttpError";
    this.statusCode = input.statusCode;
    this.code = input.code;
    this.retryable = input.retryable;
    this.details = input.details;
  }
}

export function zodDetails(error: ZodError): Record<string, unknown> {
  return {
    issues: error.issues.slice(0, 50).map((issue) => ({
      path: issue.path.map(String).join("."),
      message: issue.message
    }))
  };
}

export function errorResponseFor(
  error: unknown,
  requestId: string
): { statusCode: number; body: ErrorResponse } {
  if (error instanceof ZodError) {
    return {
      statusCode: 400,
      body: makeErrorResponse(
        {
          code: "VALIDATION_ERROR",
          message: "Request validation failed",
          retryable: false,
          details: zodDetails(error)
        },
        requestId
      )
    };
  }
  if (error instanceof ApiHttpError) {
    return {
      statusCode: error.statusCode,
      body: makeErrorResponse(
        {
          code: error.code,
          message: error.message,
          retryable: error.retryable,
          ...(error.details === undefined ? {} : { details: error.details })
        },
        requestId
      )
    };
  }
  const statusCode =
    typeof error === "object" &&
    error !== null &&
    "statusCode" in error &&
    typeof (error as { statusCode?: unknown }).statusCode === "number"
      ? (error as { statusCode: number }).statusCode
      : 500;
  if (statusCode >= 400 && statusCode < 500) {
    return {
      statusCode,
      body: makeErrorResponse(
        {
          code: "BAD_REQUEST",
          message: "Malformed request",
          retryable: false
        },
        requestId
      )
    };
  }
  return {
    statusCode: 500,
    body: makeErrorResponse(
      {
        code: "INTERNAL_ERROR",
        message: "Internal server error",
        retryable: true
      },
      requestId
    )
  };
}

export function notFoundResponse(request: FastifyRequest): ErrorResponse {
  return makeErrorResponse(
    {
      code: "NOT_FOUND",
      message: "Route not found",
      retryable: false
    },
    request.id
  );
}

export function sendError(
  reply: FastifyReply,
  request: FastifyRequest,
  error: unknown
): FastifyReply {
  const response = errorResponseFor(error, request.id);
  return reply.code(response.statusCode).send(response.body);
}
