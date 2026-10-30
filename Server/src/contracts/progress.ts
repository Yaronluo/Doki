import { z } from "zod";
import {
  nonNegativeIntegerSchema,
  positiveIntegerSchema,
  secondsSchema,
  utcIso8601Schema,
  uuidSchema
} from "./common.js";

export const progressEventKindSchema = z.enum([
  "progress",
  "pause",
  "seekCompleted",
  "ended"
]);

export const progressEventSchema = z
  .object({
    eventId: uuidSchema,
    sessionId: z.string().min(1).max(100),
    deviceSeq: positiveIntegerSchema,
    writeEpoch: positiveIntegerSchema,
    baseRevision: nonNegativeIntegerSchema,
    kind: progressEventKindSchema,
    positionSeconds: secondsSchema,
    durationSeconds: secondsSchema
      .refine((value) => value > 0, {
        message: "must be greater than zero when present"
      })
      .optional(),
    clientOccurredAt: utcIso8601Schema.optional()
  })
  .strict()
  .superRefine((event, ctx) => {
    if (
      event.durationSeconds !== undefined &&
      event.positionSeconds > event.durationSeconds
    ) {
      ctx.addIssue({
        code: "custom",
        path: ["positionSeconds"],
        message: "must not exceed durationSeconds"
      });
    }
  });

export const progressEventStatusSchema = z.enum([
  "accepted",
  "duplicate",
  "conflict"
]);

export const progressEventResultSchema = z.object({
  eventId: uuidSchema,
  status: progressEventStatusSchema,
  revision: nonNegativeIntegerSchema.optional(),
  currentRevision: nonNegativeIntegerSchema.optional()
});

export type ProgressEvent = z.infer<typeof progressEventSchema>;
export type ProgressEventKind = z.infer<typeof progressEventKindSchema>;
export type ProgressEventResult = z.infer<typeof progressEventResultSchema>;
