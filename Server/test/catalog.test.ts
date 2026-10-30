import { describe, expect, it } from "vitest";
import { CatalogService } from "../src/metadata/catalog.js";
import { TmdbConfig } from "../src/config/config.js";
import type { FetchTransport } from "../src/providers/types.js";
import { createApp } from "../src/api/app.js";
import { testConfig } from "./helpers/test-config.js";

function transport(handler: (url: URL, options: Parameters<FetchTransport["fetch"]>[1]) => unknown): FetchTransport {
  return {
    async fetch(url, options) { return { response: new Response(JSON.stringify(handler(new URL(url), options)), { headers: { "content-type": "application/json" } }), finalUrl: new URL(url) }; },
    async readText(response) { return response.text(); }
  };
}
const subject = { id: 42, type: 2, name: "Test anime", name_cn: "测试动画", date: "2026-10-01", platform: "TV" };
const token = "self-made-test-token-never-a-real-secret";

describe("public metadata and optional artwork", () => {
  it("does not touch TMDB or require credentials for the catalog", async () => {
    let calls = 0;
    const service = new CatalogService({ artworkMap: null, transport: transport(url => { calls++; expect(url.origin).toBe("https://api.bgm.tv"); return subject; }) });
    expect(await service.artwork(42)).toEqual({ state: "notConfigured", candidates: [], selected: null });
    expect(calls).toBe(0);
    await Promise.all([service.subject(42), service.subject(42)]);
    expect(calls).toBe(1); // one in-flight request, not two competing refreshes
  });
  it("sends real search JSON and never sends TMDB credentials to Bangumi", async () => {
    const service = new CatalogService({ artworkMap: null, tmdb: new TmdbConfig(token), transport: transport((url, options) => {
      expect(url.origin).toBe("https://api.bgm.tv"); expect(options.headers?.Authorization).toBeUndefined();
      expect(options.method).toBe("POST");
      expect(JSON.parse(options.body!)).toMatchObject({ keyword: "测试", filter: { type: [2], nsfw: false } });
      expect(url.searchParams.get("offset")).toBe("24");
      return { total: 1, data: [subject] };
    }) });
    expect((await service.search("测试", 24)).data).toHaveLength(1);
  });
  it("keeps movie and TV identities distinct and only selects an exact unambiguous match", async () => {
    const movie = { ...subject, platform: "剧场版" };
    const service = new CatalogService({ artworkMap: null, tmdb: new TmdbConfig(token), transport: transport((url, options) => {
      if (url.origin === "https://api.bgm.tv") return movie;
      expect(options.headers?.Authorization).toBe(`Bearer ${token}`);
      expect(url.pathname).toBe("/3/search/movie");
      return { results: [{ id: 13, title: "测试动画", original_title: "Test anime", release_date: "2026-10-01", genre_ids: [16], backdrop_path: "/Example123.jpg" }] };
    }) });
    const result = await service.artwork(42);
    expect(result.selected).toMatchObject({ mediaType: "movie", id: 13, backdropURL: "/v1/artwork/tmdb/Example123.jpg" });
    expect(JSON.stringify(result)).not.toContain(token);
  });
  it("does not auto-select ambiguous titles or a title from another year", async () => {
    const service = new CatalogService({ artworkMap: null, tmdb: new TmdbConfig(token), transport: transport(url => {
      if (url.origin === "https://api.bgm.tv") return subject;
      return { results: [1,2,3].map(id => ({ id, name: "测试动画", original_name: "Test anime", first_air_date: id === 3 ? "2025-01-01" : "2026-01-01", genre_ids: [16], backdrop_path: "/Sample.jpg" })) };
    }) });
    const result = await service.artwork(42);
    expect(result.candidates).toHaveLength(3);
    expect(result.selected).toBeNull();
    expect(result.candidates.find(c => c.id === 3)?.exactMatch).toBe(false);
  });
  it("artwork failure never prevents reading subject metadata", async () => {
    const service = new CatalogService({ artworkMap: null, tmdb: new TmdbConfig(token), transport: transport(url => {
      if (url.origin === "https://api.bgm.tv") return subject;
      throw new Error("network unavailable");
    }) });
    expect((await service.artwork(42)).state).toBe("unavailable");
    expect((await service.subject(42)).id).toBe(42);
  });
  it("accepts real nullable calendar pictures and keeps malformed upstream data retryable", async () => {
    const nullable = new CatalogService({ artworkMap: null, transport: transport(() => [{ weekday: { id: 1 }, items: [{ ...subject, images: null }] }]) });
    expect((await nullable.calendar())[0]?.items[0]?.images).toBeNull();
    let broken = true;
    const recovery = new CatalogService({ artworkMap: null, transport: transport(() => broken ? { id: "invalid" } : subject) });
    await expect(recovery.subject(42)).rejects.toMatchObject({ statusCode: 502, retryable: true });
    broken = false;
    expect((await recovery.subject(42)).id).toBe(42);
  });
  it("rejects private-image path injection before issuing any request", async () => {
    const service = new CatalogService({ artworkMap: null, transport: transport(() => { throw new Error("must never fetch"); }) });
    await expect(service.image("http://127.0.0.1/private.jpg")).rejects.toThrow("图片路径无效");
    await expect(service.image("..%2fprivate.jpg")).rejects.toThrow("图片路径无效");
  });
  it("exposes validated read routes and preserves upstream failures as 502", async () => {
    const service = new CatalogService({ artworkMap: null, transport: transport(url => {
      if (url.pathname === "/calendar") return [{ weekday: { id: 1 }, items: [subject] }];
      if (url.pathname === "/v0/episodes") return { total: 201, data: [{ id: 1001, sort: 101, name: "章节" }] };
      return url.pathname === "/v0/subjects" ? { total: 1, data: [subject] } : subject;
    }) });
    const app = createApp({ config: testConfig(), catalog: service, readiness: { async check() { throw new Error("not used"); } } });
    try {
      const home = await app.inject({ method: "GET", url: "/v1/home" });
      expect(home.statusCode).toBe(200); expect(home.json().picks.data[0].id).toBe(42);
      expect((await app.inject({ method: "GET", url: "/v1/subjects/42/episodes?offset=100" })).json().total).toBe(201);
      expect((await app.inject({ method: "GET", url: "/v1/subjects/-1" })).statusCode).toBe(400);
      expect((await app.inject({ method: "POST", url: "/v1/search", payload: { keyword: "" } })).statusCode).toBe(400);
      expect((await app.inject({ method: "GET", url: "/v1/subjects/42/artwork" })).json().state).toBe("notConfigured");
    } finally { await app.close(); }
  });
});
