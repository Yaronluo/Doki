import { z } from "zod";

// These public read contracts intentionally contain no collection/account state.
export const catalogSubjectSchema = z.object({
  id: z.number().int().positive(), type: z.number().int().nullish(),
  name: z.string(), name_cn: z.string().nullish(), summary: z.string().nullish(),
  date: z.string().nullish(), air_date: z.string().nullish(), platform: z.string().nullish(),
  eps: z.number().nullish(), total_episodes: z.number().nullish(), nsfw: z.boolean().nullish(),
  images: z.object({ large: z.string().nullish(), common: z.string().nullish(), medium: z.string().nullish() }).nullish(),
  rating: z.object({ score: z.number().nullish(), rank: z.number().nullish(), total: z.number().nullish(), count: z.record(z.string(), z.number()).nullish() }).nullish(),
  collection: z.object({ doing: z.number().nullish(), wish: z.number().nullish(), collect: z.number().nullish() }).nullish(),
  tags: z.array(z.object({ name: z.string(), count: z.number().nullish() })).nullish()
});
export const catalogPageSchema = z.object({ total: z.number(), limit: z.number().nullish(), offset: z.number().nullish(), data: z.array(catalogSubjectSchema) });
export const calendarSchema = z.array(z.object({ weekday: z.object({ id: z.number().int().min(1).max(7) }), items: z.array(catalogSubjectSchema) }));
export const catalogEpisodeSchema = z.object({ id: z.number().int().positive(), type: z.number().nullish(), sort: z.number(), ep: z.number().nullish(), name: z.string(), name_cn: z.string().nullish(), desc: z.string().nullish(), airdate: z.string().nullish(), duration: z.string().nullish() });
export const episodePageSchema = z.object({ total: z.number(), limit: z.number().nullish(), offset: z.number().nullish(), data: z.array(catalogEpisodeSchema) });
export const catalogSearchSchema = z.object({ keyword: z.string().trim().min(1).max(100), offset: z.number().int().min(0).max(10000).default(0) });
export const artworkCandidateSchema = z.object({ id: z.number().int().positive(), mediaType: z.enum(["tv", "movie", "collection"]), title: z.string(), originalTitle: z.string(), year: z.string(), backdropURL: z.string().nullable(), exactMatch: z.boolean() });
export const artworkResponseSchema = z.object({ state: z.enum(["ready", "notConfigured", "unavailable", "noMatch"]), candidates: z.array(artworkCandidateSchema), selected: artworkCandidateSchema.nullable() });
export const creditSchema = z.object({ id: z.number().int().positive(), name: z.string(), relation: z.string().nullish(), images: z.object({ large: z.string().nullish(), medium: z.string().nullish(), small: z.string().nullish() }).nullable().nullish(), actors: z.array(z.object({ id: z.number(), name: z.string() })).nullish() });
export const creditsSchema = z.array(creditSchema);
