import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { CatalogService } from "../../metadata/catalog.js";
import { catalogSearchSchema } from "../../contracts/catalog.js";
import { ApiHttpError } from "../errors.js";
const idSchema = z.object({ id: z.coerce.number().int().positive().max(2_147_483_647) });

export function registerCatalogRoutes(app: FastifyInstance, catalog: CatalogService): void {
  // Public metadata only. This grants no account, source execution or write access.
  const counts = new Map<string, { start: number; count: number }>();
  app.addHook("onRequest", async request => {
    if (!/^\/v1\/(home|popular|calendar|search|subjects|artwork)(\/|\?|$)/.test(request.url)) return;
    const now = Date.now();
    let count = counts.get(request.ip);
    if (!count || now - count.start > 60_000) {
      if (counts.size >= 256) counts.delete(counts.keys().next().value!);
      count = { start: now, count: 0 }; counts.set(request.ip, count);
    }
    if (++count.count > 120) throw new ApiHttpError({ statusCode: 429, code: "RATE_LIMITED", message: "请求过于频繁，请稍后重试。", retryable: true });
  });
  app.get("/v1/home", async () => {
    const [calendar, picks] = await Promise.all([catalog.calendar(), catalog.picks()]);
    return { calendar, picks, updatedAt: new Date().toISOString() };
  });
  app.get("/v1/popular", async () => catalog.popular());
  app.get("/v1/calendar", async () => catalog.calendar());
  app.get("/v1/subjects/:id", async request => catalog.subject(idSchema.parse(request.params).id));
  app.get("/v1/subjects/:id/episodes", async request => {
    const { offset } = z.object({ offset: z.coerce.number().int().min(0).max(10000).default(0) }).parse(request.query);
    return catalog.episodes(idSchema.parse(request.params).id, offset);
  });
  for (const kind of ["characters", "persons"] as const) app.get(`/v1/subjects/:id/${kind}`, async request => catalog.credits(idSchema.parse(request.params).id, kind));
  app.post("/v1/search", async request => { const body = catalogSearchSchema.parse(request.body); return catalog.search(body.keyword, body.offset); });
  app.get("/v1/subjects/:id/artwork", async request => catalog.artwork(idSchema.parse(request.params).id));
  app.get("/v1/artwork/tmdb/:filename", async (request, reply) => {
    const { filename } = z.object({ filename: z.string().max(100) }).parse(request.params);
    const image = await catalog.image(filename);
    return reply.header("cache-control", "public, max-age=86400").type(image.contentType).send(image.bytes);
  });
}
