import { SafeFetcher } from "../providers/safe-fetch.js";
import type { FetchTransport } from "../providers/types.js";
export interface MappedArtwork { subjectId: number; mediaType: "tv" | "movie" | "collection"; mediaId: number; backdropPath: string | null; manual: boolean }
export function parseArtworkMap(text: string): Map<number, MappedArtwork> {
  if (!text.startsWith("# bangumi-tmdb-map v1") || Buffer.byteLength(text) > 16 * 1024 * 1024) throw new Error("Invalid artwork map");
  const result = new Map<number, MappedArtwork>();
  for (const row of text.split("\n")) {
    if (row.startsWith("#")) continue;
    const columns = row.split("\t");
    const subjectId = Number(columns[0]);
    if (columns.length < 5 || !Number.isSafeInteger(subjectId) || subjectId <= 0) continue;
    const ref = /^(tv|movie|collection)\/([1-9][0-9]*)$/.exec(columns[1]!);
    if (!ref) continue;
    const path = columns[2] ?? "";
    result.set(subjectId, { subjectId, mediaType: ref[1] as MappedArtwork["mediaType"], mediaId: Number(ref[2]), backdropPath: /^\/[A-Za-z0-9_-]+\.(jpg|png|webp)$/.test(path) ? path : null, manual: columns[4] === "manual" });
  }
  if (!result.size) throw new Error("Empty artwork map");
  return result;
}
export class PublicArtworkMap {
  #entries = new Map<number, MappedArtwork>();
  #expires = 0;
  #pending: Promise<void> | undefined;
  constructor(readonly transport: FetchTransport = new SafeFetcher({ timeoutMs: 15000, maxRedirects: 0 })) {}
  async lookup(id: number): Promise<MappedArtwork | undefined> {
    if (Date.now() >= this.#expires) {
      this.#pending ??= this.#refresh().finally(() => { this.#pending = undefined; });
      await this.#pending;
    }
    return this.#entries.get(id);
  }
  async #refresh(): Promise<void> {
    try {
      const { response } = await this.transport.fetch("https://raw.githubusercontent.com/GrahamZen/bangumi-tmdb-map/main/map/bgm-tmdb.tsv", { maxRedirects: 0 });
      if (!response.ok) throw new Error("Map unavailable");
      this.#entries = parseArtworkMap(await this.transport.readText(response, { maxBytes: 16 * 1024 * 1024 }));
      this.#expires = Date.now() + 6 * 3600_000;
    } catch { this.#expires = Date.now() + 60_000; }
  }
}
