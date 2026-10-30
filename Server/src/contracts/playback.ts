import { z } from "zod";
import {
  nonNegativeIntegerSchema,
  positiveIntegerSchema,
  secondsSchema,
  utcIso8601Schema
} from "./common.js";

export const playbackSourceSchema = z.object({
  sourceId: z.string().min(1).max(200),
  mode: z.enum(["direct", "relay", "remux"]),
  url: z.string().url(),
  expiresAt: utcIso8601Schema.optional()
});

export const playbackTracksSchema = z.object({
  subtitleLanguages: z.array(z.string().min(1).max(35)).max(32),
  hasAlternateAudio: z.boolean()
});

export const playbackCapabilitiesSchema = z.object({
  canSeek: z.boolean(),
  canAutoFailover: z.boolean()
});

export const playbackPlanSchema = z.object({
  sessionId: z.string().min(1).max(100),
  episodeId: z.number().int().positive(),
  status: z.literal("ready"),
  resumeAtSeconds: secondsSchema,
  resumeRevision: nonNegativeIntegerSchema,
  writeEpoch: positiveIntegerSchema,
  source: playbackSourceSchema,
  tracks: playbackTracksSchema,
  capabilities: playbackCapabilitiesSchema
});

export type PlaybackPlan = z.infer<typeof playbackPlanSchema>;
export type PlaybackSource = z.infer<typeof playbackSourceSchema>;
export type PlaybackTracks = z.infer<typeof playbackTracksSchema>;
export type PlaybackCapabilities = z.infer<typeof playbackCapabilitiesSchema>;
