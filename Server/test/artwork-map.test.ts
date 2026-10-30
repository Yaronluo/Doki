import { describe, expect, it } from "vitest";
import { parseArtworkMap, PublicArtworkMap } from "../src/metadata/artwork-map.js";
import { CatalogService } from "../src/metadata/catalog.js";
import type { FetchTransport } from "../src/providers/types.js";
const table="# bangumi-tmdb-map v1\n42\ttv/70\t/Hero.jpg\t\tauto\n43\tmovie/71\t/Movie.jpg\t\tmanual\n44\ttv/72\thttp://127.0.0.1/secret.jpg\t\tauto\n";
describe("no-token public artwork",()=>{
  it("keeps TV/movie identities and refuses injected destinations",()=>{const map=parseArtworkMap(table);expect(map.get(43)?.mediaType).toBe("movie");expect(map.get(44)?.backdropPath).toBeNull();expect(()=>parseArtworkMap("<html>challenge</html>")).toThrow();});
  it("serves a known backdrop without a TMDB token or an API search",async()=>{
    let calls=0;const transport:FetchTransport={async fetch(url,options){calls++;expect(new URL(url).host).toBe("raw.githubusercontent.com");expect(options.headers?.Authorization).toBeUndefined();return{response:new Response(table),finalUrl:new URL(url)};},async readText(r){return r.text();}};
    const service=new CatalogService({transport,artworkMap:new PublicArtworkMap(transport)});
    const [a,b]=await Promise.all([service.artwork(42),service.artwork(43)]);
    expect(a.selected?.backdropURL).toBe("/v1/artwork/tmdb/Hero.jpg");expect(b.selected?.mediaType).toBe("movie");expect(calls).toBe(1);
  });
});
