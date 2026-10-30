import { PublicArtworkMap } from "./artwork-map.js";
import { z } from "zod";
import type { TmdbConfig } from "../config/config.js";
import { ApiHttpError } from "../api/errors.js";
import { SafeFetcher } from "../providers/safe-fetch.js";
import type { FetchTransport } from "../providers/types.js";
import { artworkResponseSchema, creditsSchema, calendarSchema, catalogPageSchema, catalogSubjectSchema, episodePageSchema } from "../contracts/catalog.js";

const BGM = "https://api.bgm.tv";
const TMDB = "https://api.themoviedb.org/3";
const UA = "Doki/0.2 (personal tvOS catalog; https://github.com/bangumi/api)";
function upstream<T>(schema: z.ZodType<T>, value: unknown): T {
  const parsed = schema.safeParse(value);
  if (!parsed.success) throw new ApiHttpError({ statusCode: 502, code: "METADATA_INVALID_RESPONSE", message: "元数据响应格式异常，请稍后重试。", retryable: true });
  return parsed.data;
}
type Subject = z.infer<typeof catalogSubjectSchema>;
type Artwork = z.infer<typeof artworkResponseSchema>;
interface CacheEntry { value: unknown; expires: number }

export class CatalogService {
  readonly #transport: FetchTransport;
  readonly #map: PublicArtworkMap | null;
  readonly #tmdb: TmdbConfig | undefined;
  readonly #cache = new Map<string, CacheEntry>();
  readonly #pending = new Map<string, Promise<unknown>>();
  constructor(options: { transport?: FetchTransport; tmdb?: TmdbConfig; artworkMap?: PublicArtworkMap | null } = {}) {
    this.#transport = options.transport ?? new SafeFetcher({ timeoutMs: 10000, maxRedirects: 0 });
    this.#tmdb = options.tmdb;
    this.#map = options.artworkMap === undefined ? new PublicArtworkMap(this.#transport) : options.artworkMap;
  }

  async #json(url: string, body?: object): Promise<unknown> {
    // Fixed, owned API origins only; API redirects are rejected, including same-origin.
    const origin = new URL(url).origin;
    if (![BGM, "https://api.themoviedb.org"].includes(origin)) throw new Error("Invalid metadata origin");
    const headers: Record<string, string> = { "User-Agent": UA, Accept: "application/json" };
    if (origin === "https://api.themoviedb.org" && this.#tmdb) headers.Authorization = `Bearer ${this.#tmdb.readAccessToken}`;
    let fetched;
    try { fetched = await this.#transport.fetch(url, { method: body ? "POST" : "GET", headers: body ? { ...headers, "Content-Type": "application/json" } : headers, maxRedirects: 0, ...(body ? { body: JSON.stringify(body) } : {}) }); } catch { throw new ApiHttpError({ statusCode: 502, code: "METADATA_UNAVAILABLE", message: "元数据服务暂时不可用，请稍后重试。", retryable: true }); }
    const { response } = fetched;
    if (!response.ok) throw new ApiHttpError({ statusCode: response.status === 404 ? 404 : 502, code: "METADATA_UPSTREAM_FAILED", message: "元数据服务暂时不可用，请稍后重试。", retryable: response.status !== 404 });
    try { return JSON.parse(await this.#transport.readText(response, { maxBytes: 4 * 1024 * 1024 })); }
    catch { throw new ApiHttpError({ statusCode: 502, code: "METADATA_INVALID_RESPONSE", message: "元数据响应格式异常，请稍后重试。", retryable: true }); }
  }

  async #remember<T>(key: string, ttl: number, load: () => Promise<T>): Promise<T> {
    const old = this.#cache.get(key);
    if (old && old.expires > Date.now()) return old.value as T;
    const pending = this.#pending.get(key);
    if (pending) return pending as Promise<T>;
    const promise = load().then(value => {
      if (this.#cache.size >= 256) this.#cache.delete(this.#cache.keys().next().value!);
      this.#cache.set(key, { value, expires: Date.now() + (key.startsWith("art:") && (value as { state?: string }).state === "unavailable" ? 30_000 : ttl) });
      return value;
    }).finally(() => this.#pending.delete(key));
    this.#pending.set(key, promise);
    return promise;
  }
  calendar() { return this.#remember("calendar", 15 * 60_000, async () => upstream(calendarSchema, await this.#json(`${BGM}/calendar`)).map(day => ({ ...day, items: day.items.filter(s => s.type === 2 && !s.nsfw) }))); }
  picks() {
    const now = new Date();
    return this.#remember("picks", 60 * 60_000, async () => upstream(catalogPageSchema, await this.#json(`${BGM}/v0/subjects?type=2&sort=rank&year=${now.getUTCFullYear()}&month=${Math.floor(now.getUTCMonth()/3)*3+1}&limit=24&offset=0`)));
  }
  subject(id: number) { return this.#remember(`subject:${id}`, 300_000, async () => upstream(catalogSubjectSchema, await this.#json(`${BGM}/v0/subjects/${id}`))); }
  episodes(id: number, offset: number) { return this.#remember(`episodes:${id}:${offset}`, 300_000, async () => upstream(episodePageSchema, await this.#json(`${BGM}/v0/episodes?subject_id=${id}&type=0&limit=100&offset=${offset}`))); }
  credits(id: number, kind: "characters" | "persons") { return this.#remember(`credits:${id}:${kind}`, 3600_000, async () => upstream(creditsSchema, await this.#json(`${BGM}/v0/subjects/${id}/${kind}`))); }
  search(keyword: string, offset: number) { return this.#remember(`search:${keyword}:${offset}`, 60_000, async () => upstream(catalogPageSchema, await this.#json(`${BGM}/v0/search/subjects?limit=24&offset=${offset}`, { keyword, sort: "match", filter: { type: [2], nsfw: false } }))); }

  async artwork(id: number): Promise<Artwork> {
    const mapped = await this.#map?.lookup(id);
    if (mapped?.backdropPath) {
      const entry = { id: mapped.mediaId, mediaType: mapped.mediaType, title: `TMDB ${mapped.mediaId}`, originalTitle: "", year: "", backdropURL: `/v1/artwork/tmdb${mapped.backdropPath}`, exactMatch: true };
      return { state: "ready", candidates: [entry], selected: entry };
    }
    if (!this.#tmdb) return { state: "notConfigured", candidates: [], selected: null };
    return this.#remember(`art:${id}`, 60 * 60_000, async () => {
      try { return await this.#findArtwork(await this.subject(id)); }
      catch { return { state: "unavailable", candidates: [], selected: null }; }
    });
  }
  async #findArtwork(subject: Subject): Promise<Artwork> {
    const normalized = (s: string) => s.normalize("NFKC").toLowerCase().replace(/[\p{P}\p{Z}\s]/gu, "");
    const names = [subject.name, subject.name_cn ?? ""].filter(Boolean);
    const year = (subject.date ?? subject.air_date ?? "").slice(0,4);
    const candidates: Artwork["candidates"] = [];
    // Bangumi's platform disambiguates films; never treat a movie id as a TV id.
    const kinds: ("tv" | "movie")[] = subject.platform === "剧场版" ? ["movie"] : ["tv", "movie"];
    for (const mediaType of kinds) {
      for (const name of [...new Set(names)]) {
        const data = z.object({ results: z.array(z.object({ id: z.number().int().positive(), name: z.string().optional(), title: z.string().optional(), original_name: z.string().optional(), original_title: z.string().optional(), first_air_date: z.string().optional(), release_date: z.string().optional(), backdrop_path: z.string().nullable().optional(), genre_ids: z.array(z.number()).optional() })) }).parse(await this.#json(`${TMDB}/search/${mediaType}?query=${encodeURIComponent(name)}&include_adult=false&language=zh-CN`));
        for (const item of data.results) {
          if (!item.genre_ids?.includes(16) || candidates.some(c => c.id === item.id && c.mediaType === mediaType)) continue;
          const title = item.name ?? item.title ?? "";
          const originalTitle = item.original_name ?? item.original_title ?? title;
          const itemYear = (item.first_air_date ?? item.release_date ?? "").slice(0,4);
          const exactMatch = year.length === 4 && itemYear === year && names.some(n => [title, originalTitle].some(t => normalized(t) === normalized(n)));
          // Only expose fixed TMDB paths; never accept URLs supplied by a caller.
          const path = item.backdrop_path;
          const backdropURL = path && /^\/[A-Za-z0-9]+\.(jpg|png|webp)$/.test(path) ? `/v1/artwork/tmdb${path}` : null;
          candidates.push({ id: item.id, mediaType, title, originalTitle, year: itemYear, backdropURL, exactMatch });
        }
      }
      if (candidates.some(c => c.exactMatch)) break;
    }
    const exact = candidates.filter(c => c.exactMatch);
    // Ambiguity requires a human choice. Absence of a backdrop never crops a poster.
    return { state: candidates.length ? "ready" : "noMatch", candidates: candidates.slice(0,12), selected: exact.length === 1 ? exact[0]! : null };
  }
  async image(filename: string): Promise<{ bytes: Buffer; contentType: string }> {
    if (!/^[A-Za-z0-9]+\.(jpg|png|webp)$/.test(filename)) throw new ApiHttpError({ statusCode: 400, code: "INVALID_IMAGE", message: "图片路径无效", retryable: false });
    const { response } = await this.#transport.fetch(`https://image.tmdb.org/t/p/w1280/${filename}`, { maxRedirects: 0 });
    if (!response.ok || !/^image\/(jpeg|png|webp)/.test(response.headers.get("content-type") ?? "")) throw new ApiHttpError({ statusCode: 502, code: "IMAGE_UNAVAILABLE", message: "横幅暂时不可用", retryable: true });
    const chunks: Uint8Array[] = []; let size = 0;
    const reader = response.body?.getReader();
    if (!reader) throw new Error("Missing image body");
    try { while (true) { const next = await reader.read(); if (next.done) break; size += next.value.byteLength; if (size > 8 * 1024 * 1024) throw new Error("Image exceeds limit"); chunks.push(next.value); } } finally { await reader.cancel().catch(() => undefined); }
    return { bytes: Buffer.concat(chunks), contentType: response.headers.get("content-type")! };
  }
}
