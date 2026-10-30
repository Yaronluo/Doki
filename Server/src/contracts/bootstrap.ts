import { z } from "zod";

export const capabilityStateSchema = z.enum([
  "ready",
  "notConfigured",
  "unavailable"
]);

export type CapabilityState = z.infer<typeof capabilityStateSchema>;

export const capabilitySchema = z.object({
  state: capabilityStateSchema
});

export const danmakuCapabilitySchema = z.object({
  state: capabilityStateSchema,
  provider: z.literal("dandanplay")
});

export const bootstrapResponseSchema = z.object({
  apiVersion: z.literal("1"),
  hubVersion: z.string().min(1),
  capabilities: z.object({
    bangumi: capabilitySchema,
    tmdb: capabilitySchema,
    danmaku: danmakuCapabilitySchema
  })
});

export type BootstrapResponse = z.infer<typeof bootstrapResponseSchema>;
export type BootstrapCapabilities = BootstrapResponse["capabilities"];
export type SimpleCapability = z.infer<typeof capabilitySchema>;
export type DanmakuCapability = z.infer<typeof danmakuCapabilitySchema>;
