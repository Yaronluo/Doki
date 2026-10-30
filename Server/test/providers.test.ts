import { describe, expect, it } from "vitest";
import { assertSafeOutboundUrl } from "../src/providers/safe-fetch.js";
import { ProviderError, type FetchTransport, type SafeFetchResult } from "../src/providers/types.js";
import { YinghuaProvider } from "../src/providers/yinghua.js";

class FixtureTransport implements FetchTransport {
  async fetch(url: string): Promise<SafeFetchResult> {
    const finalUrl = new URL(url);
    if (url.includes("/search.html")) {
      return {
        response: new Response(searchHtml(), { status: 200 }),
        finalUrl: new URL("https://www.yinghuabb.com/index.php/vod/search.html?wd=x")
      };
    }
    if (url.includes("/detail/")) {
      return {
        response: new Response(detailHtml(), { status: 200 }),
        finalUrl: new URL("https://www.yinghuabb.com/index.php/vod/detail/id/12961.html")
      };
    }
    if (url.includes("/play/")) {
      return {
        response: new Response(playHtml(), { status: 200 }),
        finalUrl: new URL("https://www.yinghuabb.com/index.php/vod/play/id/12961/sid/5/nid/1.html")
      };
    }
    return {
      response: new Response("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nhttps://93.184.216.34/v.m3u8\n", { status: 200 }),
      finalUrl
    };
  }

  async readText(response: Response): Promise<string> {
    return response.text();
  }
}

function searchHtml(): string {
  return `<h3 class="title"><a href="/index.php/vod/detail/id/12961.html">葬送的芙莉莲</a></h3>`;
}

function detailHtml(): string {
  return `
  <div class="playlist"><div class="stui-pannel__head"><h3 class="title">线路1</h3></div>
    <ul class="stui-content__playlist">
      <li><a href="/index.php/vod/play/id/12961/sid/5/nid/1.html">第1集</a></li>
      <li><a href="/index.php/vod/play/id/12961/sid/5/nid/2.html">第2集</a></li>
    </ul>
  </div>
  <div class="playlist"><div class="stui-pannel__head"><h3 class="title">线路2</h3></div>
    <ul class="stui-content__playlist">
      <li><a href="/index.php/vod/play/id/12961/sid/13/nid/1.html">第01集</a></li>
      <li><a href="/index.php/vod/play/id/12961/sid/13/nid/2.html">第02集</a></li>
    </ul>
  </div>`;
}

function playHtml(): string {
  return `<script>var player_aaaa={"encrypt":0,"url":"https://93.184.216.34/a.m3u8"}</script>`;
}

describe("Safe outbound URL policy", () => {
  it("blocks loopback, private and link-local addresses by default", async () => {
    for (const url of [
      "http://127.0.0.1/a",
      "http://10.0.0.10/a",
      "http://192.168.1.10/a",
      "http://169.254.169.254/latest",
      "http://[::1]/a",
      "file:///etc/passwd"
    ]) {
      await expect(assertSafeOutboundUrl(url)).rejects.toBeInstanceOf(ProviderError);
    }
  });

  it("allows the sandwich network only with an explicit local opt-in", async () => {
    await expect(assertSafeOutboundUrl("https://198.18.3.95/a")).rejects.toBeInstanceOf(ProviderError);
    const allowed = await assertSafeOutboundUrl("https://198.18.3.95/a", {
      allowBenchmarkNetwork: true
    });
    expect(allowed.hostname).toBe("198.18.3.95");
  });
});

describe("Yinghua provider fixtures", () => {
  it("parses search, channels, episodes and a direct HLS player_aaaa", async () => {
    const provider = new YinghuaProvider(new FixtureTransport(), { requestIntervalMs: 0 });
    const subjects = await provider.search("葬送的芙莉莲", { requestId: "req_test" });
    expect(subjects).toHaveLength(1);
    expect(subjects[0]?.name).toBe("葬送的芙莉莲");
    expect(subjects[0]?.sourceSubjectKey).toBe("yinghua:subject:12961");

    const episodes = await provider.listEpisodes(subjects[0]!, { requestId: "req_test" });
    expect(episodes).toHaveLength(4);
    expect(episodes[0]).toMatchObject({ channel: "线路1", episodeNumber: 1, title: "第1集" });
    expect(episodes[2]).toMatchObject({ channel: "线路2", episodeNumber: 1, title: "第01集" });

    const asset = await provider.resolve(episodes[0]!, { requestId: "req_test" });
    expect(asset.mediaType).toBe("hls");
    expect(asset.upstreamUrl).toBe("https://93.184.216.34/a.m3u8");
    expect(asset.provider.id).toBe("yinghua");
    expect(asset.provider.snapshotSha256).toHaveLength(64);
  });
});
