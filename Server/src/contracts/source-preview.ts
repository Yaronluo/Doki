import { z } from "zod";
import { secondsSchema } from "./common.js";

/**
 * Development-only source preview contract. This is intentionally separate
 * from PlaybackPlan: it has no Bangumi subject/episode IDs, no resume epoch
 * and no write ownership. It exists to validate one real provider, relay and
 * AVPlayer path before the Bangumi-bound playback session is implemented.
 */
export const sourcePreviewRequestSchema = z.object({
  query: z.string().trim().min(1).max(120),
  episodeNumber: z.number().int().min(1).max(9_999).optional(),
  channel: z.string().trim().min(1).max(120).optional()
});

export const sourcePreviewPlanSchema = z.object({
  sessionId: z.string().min(1).max(100),
  status: z.literal("ready"),
  provider: z.object({
    id: z.string().min(1).max(80),
    name: z.string().min(1).max(120)
  }),
  subject: z.object({
    name: z.string().min(1).max(300),
    sourceSubjectKey: z.string().min(1).max(200)
  }),
  episode: z.object({
    number: z.number().int().min(0).max(9_999),
    title: z.string().min(1).max(200),
    channel: z.string().min(1).max(120),
    mediaId: z.string().min(1).max(300)
  }),
  source: z.object({
    mode: z.literal("relay"),
    url: z.string().url(),
    expiresAt: z.string()
  }),
  tracks: z.object({
    subtitleLanguages: z.array(z.string()).max(32),
    hasAlternateAudio: z.boolean()
  }),
  capabilities: z.object({
    canSeek: z.boolean(),
    canAutoFailover: z.boolean()
  }),
  durationHintSeconds: secondsSchema,
  provenance: z.object({
    ruleCommit: z.string().min(1).max(80),
    snapshotSha256: z.string().regex(/^[0-9a-f]{64}$/),
    verifiedAt: z.string()
  })
});

export type SourcePreviewRequest = z.infer<typeof sourcePreviewRequestSchema>;
export type SourcePreviewPlan = z.infer<typeof sourcePreviewPlanSchema>;
