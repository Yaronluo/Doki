import { z } from "zod";
import { nonNegativeIntegerSchema, utcIso8601Schema } from "./common.js";

export const healthResponseSchema = z.object({
  status: z.literal("ok"),
  hubVersion: z.string().min(1),
  uptimeSeconds: nonNegativeIntegerSchema,
  checkedAt: utcIso8601Schema
});

export const readinessCheckSchema = z.object({
  status: z.enum(["ok", "error", "skipped"]),
  code: z.string().min(1).optional(),
  applied: nonNegativeIntegerSchema.optional(),
  pending: nonNegativeIntegerSchema.optional(),
  pendingVersions: z.array(z.string().min(1)).max(1_000).optional()
});

export const readinessChecksSchema = z.object({
  config: readinessCheckSchema,
  database: readinessCheckSchema,
  migrations: readinessCheckSchema
});

export const readyResponseSchema = z.object({
  status: z.literal("ready"),
  checkedAt: utcIso8601Schema,
  requestId: z.string().min(1),
  checks: readinessChecksSchema
});

export const notReadyDetailsSchema = z.object({
  status: z.literal("not_ready"),
  checkedAt: utcIso8601Schema,
  checks: readinessChecksSchema
});

export type HealthResponse = z.infer<typeof healthResponseSchema>;
export type ReadinessCheck = z.infer<typeof readinessCheckSchema>;
export type ReadinessChecks = z.infer<typeof readinessChecksSchema>;
export type ReadyResponse = z.infer<typeof readyResponseSchema>;
export type NotReadyDetails = z.infer<typeof notReadyDetailsSchema>;
