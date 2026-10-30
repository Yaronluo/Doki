import { describe, expect, it } from "vitest";
import { MediaRelay } from "../src/media/relay.js";
import { ProviderError, type FetchTransport, type SafeFetchResult } from "../src/providers/types.js";
import { Readable } from "node:stream";

class MediaTransport implements FetchTransport {
  async fetch(url: string): Promise<SafeFetchResult> {
    const finalUrl = new URL(url);
    if (url.endsWith("/master.m3u8")) {
      return {
        response: new Response(
          "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1051000,RESOLUTION=1920x1080\nhttps://93.184.216.34/variant.m3u8\n",
          { status: 200, headers: { "content-type": "application/vnd.apple.mpegurl" } }
        ),
        finalUrl
      };
    }
    if (url.endsWith("/variant.m3u8")) {
      return {
        response: new Response(
          "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:4\n#EXTINF:3.753,\nhttps://93.184.216.34/seg0.ts\n#EXT-X-ENDLIST\n",
          { status: 200, headers: { "content-type": "application/vnd.apple.mpegurl" } }
        ),
        finalUrl
      };
    }
    return {
      response: new Response(Buffer.from([0x47, 0x40, 0x11, 0x10]), {
        status: 206,
        headers: {
          "content-type": "video/mp2t",
          "content-range": "bytes 0-3/4",
          "accept-ranges": "bytes"
        }
      }),
      finalUrl
    };
  }

  async readText(response: Response): Promise<string> {
    return response.text();
  }
}

function relayRequest(urlString: string, method: "GET" | "HEAD" = "GET") {
  const url = new URL(urlString);
  const parts = url.pathname.split("/").filter(Boolean);
  return {
    sessionId: parts[1] ?? "",
    resourceId: parts[2] ?? "",
    exp: Number(url.searchParams.get("exp")),
    sig: url.searchParams.get("sig") ?? "",
    method
  };
}

async function bodyText(body: Buffer | Readable | null): Promise<string> {
  if (body === null) {
    return "";
  }
  if (Buffer.isBuffer(body)) {
    return body.toString("utf8");
  }
  const chunks: Buffer[] = [];
  for await (const chunk of body) {
    chunks.push(Buffer.from(chunk as Uint8Array));
  }
  return Buffer.concat(chunks).toString("utf8");
}

describe("HLS relay", () => {
  it("rewrites master/media URLs with signed relay resources and proxies ranges", async () => {
    const relay = new MediaRelay({
      signingKey: Buffer.alloc(32, 7),
      hubBaseUrl: "http://127.0.0.1:18080",
      fetcher: new MediaTransport()
    });
    const session = relay.createSession({
      providerId: "yinghua",
      upstreamUrl: "https://93.184.216.34/master.m3u8",
      headers: { "user-agent": "DokiTest/1.0" }
    });
    expect(session.masterUrl).toMatch(/^http:\/\/127\.0\.0\.1:18080\/s\/ps_/);
    expect(session.masterUrl).not.toContain("93.184.216.34");

    const masterRequest = relayRequest(session.masterUrl);
    expect(relay.verify(masterRequest)).toBe(true);
    expect(relay.verify({ ...masterRequest, method: "HEAD" })).toBe(true);
    const master = await relay.handle(masterRequest);
    expect(master.statusCode).toBe(200);
    expect(master.headers["content-type"]).toContain("application/vnd.apple.mpegurl");
    const masterText = await bodyText(master.body);
    expect(masterText).toContain("#EXT-X-STREAM-INF");
    expect(masterText).toContain("http://127.0.0.1:18080/s/");
    expect(masterText).not.toContain("93.184.216.34");

    const variantUrl = masterText
      .split("\n")
      .find((line) => line.startsWith("http://127.0.0.1:18080/s/"));
    expect(variantUrl).toBeDefined();
    const media = await relay.handle(relayRequest(variantUrl as string));
    const mediaText = await bodyText(media.body);
    expect(mediaText).toContain("#EXTINF");
    const segmentUrl = mediaText
      .split("\n")
      .find((line) => line.startsWith("http://127.0.0.1:18080/s/"));
    expect(segmentUrl).toBeDefined();

    const segment = await relay.handle({
      ...relayRequest(segmentUrl as string),
      range: "bytes=0-3"
    });
    expect(segment.statusCode).toBe(206);
    expect(segment.headers["content-range"]).toBe("bytes 0-3/4");
    const bytes = await (async () => {
      if (segment.body === null) return Buffer.alloc(0);
      if (Buffer.isBuffer(segment.body)) return segment.body;
      const chunks: Buffer[] = [];
      for await (const chunk of segment.body) chunks.push(Buffer.from(chunk as Uint8Array));
      return Buffer.concat(chunks);
    })();
    expect(bytes[0]).toBe(0x47);
  });

  it("rejects a tampered signature and unknown resource", async () => {
    const relay = new MediaRelay({
      signingKey: Buffer.alloc(32, 9),
      hubBaseUrl: "http://127.0.0.1:18080",
      fetcher: new MediaTransport()
    });
    const session = relay.createSession({
      providerId: "yinghua",
      upstreamUrl: "https://93.184.216.34/master.m3u8",
      headers: {}
    });
    const request = relayRequest(session.masterUrl);
    expect(relay.verify({ ...request, sig: "invalid" })).toBe(false);
    await expect(
      relay.handle({ ...request, sig: "invalid" })
    ).rejects.toBeInstanceOf(ProviderError);
    await expect(
      relay.handle({ ...request, resourceId: "not-a-resource" })
    ).rejects.toBeInstanceOf(ProviderError);
  });
});
