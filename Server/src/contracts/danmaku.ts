import { z } from "zod";
import {
  int64DecimalStringSchema,
  nonNegativeIntegerSchema,
  positiveIntegerSchema,
  secondsSchema,
  signedOffsetSecondsSchema,
  utcIso8601Schema
} from "./common.js";

export const danmakuModeSchema = z.enum(["scroll", "top", "bottom"]);

export const danmakuItemSchema = z.object({
  id: int64DecimalStringSchema,
  timeSeconds: secondsSchema,
  mode: danmakuModeSchema,
  colorRgb: z.number().int().min(0).max(16_777_215),
  text: z.string().min(1).max(500)
});

export const danmakuLoadStatusSchema = z.enum(["running", "ready", "failed"]);

export const danmakuLoadSchema = z.object({
  loadId: z.string().min(1).max(100),
  status: danmakuLoadStatusSchema,
  bgmEpisodeId: z.number().int().positive(),
  danmakuEpisodeId: int64DecimalStringSchema,
  mappingRevision: nonNegativeIntegerSchema,
  contentRevision: z.string().min(1).max(100),
  mediaId: z.string().min(1).max(200),
  offsetSeconds: signedOffsetSecondsSchema,
  truncated: z.boolean(),
  items: z.array(danmakuItemSchema).max(20_000),
  totalCount: nonNegativeIntegerSchema.optional(),
  failureCode: z.string().min(1).max(100).optional()
});

export const danmakuMappingStateSchema = z.enum([
  "unbound",
  "candidate",
  "confirmed"
]);

export const danmakuMappingSchema = z.object({
  bgmEpisodeId: z.number().int().positive(),
  state: danmakuMappingStateSchema,
  revision: nonNegativeIntegerSchema,
  danmakuEpisodeId: int64DecimalStringSchema.optional(),
  source: z.enum(["bgmMap", "search", "manual"]).optional(),
  verified: z.boolean(),
  updatedAt: utcIso8601Schema.optional()
});

export const danmakuSearchCandidateSchema = z.object({
  danmakuEpisodeId: int64DecimalStringSchema,
  title: z.string().min(1).max(300),
  episodeTitle: z.string().max(300).optional(),
  episodeNumber: z.number().int().positive().optional(),
  basis: z.enum(["bgmMap", "titleSearch", "tmdb", "manual"]),
  confidence: z.number().min(0).max(1).optional()
});

export const danmakuTimingSchema = z.object({
  bgmEpisodeId: z.number().int().positive(),
  mediaId: z.string().min(1).max(200),
  offsetSeconds: signedOffsetSecondsSchema,
  revision: nonNegativeIntegerSchema,
  updatedAt: utcIso8601Schema.optional()
});

export const danmakuPreferencesSchema = z.object({
  enabled: z.boolean(),
  density: z.number().min(0).max(1),
  fontScale: z.number().min(0.5).max(3),
  opacity: z.number().min(0.1).max(1),
  area: z.enum(["top", "middle", "bottom", "full"]),
  modes: z.array(danmakuModeSchema).max(3),
  revision: nonNegativeIntegerSchema
});

export type DanmakuItem = z.infer<typeof danmakuItemSchema>;
export type DanmakuLoad = z.infer<typeof danmakuLoadSchema>;
export type DanmakuLoadStatus = z.infer<typeof danmakuLoadStatusSchema>;
export type DanmakuMapping = z.infer<typeof danmakuMappingSchema>;
export type DanmakuSearchCandidate = z.infer<
  typeof danmakuSearchCandidateSchema
>;
export type DanmakuTiming = z.infer<typeof danmakuTimingSchema>;
export type DanmakuPreferences = z.infer<typeof danmakuPreferencesSchema>;
