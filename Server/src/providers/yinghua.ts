import { createHash, randomUUID } from "node:crypto";
import * as cheerio from "cheerio";
import {
  assertSafeOutboundUrl,
  RequestThrottle,
  SafeFetcher
} from "./safe-fetch.js";
import {
  ProviderError,
  type FetchTransport,
  type MediaProvider,
  type ProviderCapabilities,
  type ProviderDescriptor,
  type ProviderRequestContext,
  type ResolvedAsset,
  type SourceEpisode,
  type SourceSubject
} from "./types.js";

const PROVIDER_ID = "yinghua";
const PROVIDER_NAME = "樱花动漫";
const SOURCE_ORIGIN = "https://www.yinghua2.com";
const SEARCH_URL_TEMPLATE =
  "https://www.yinghua2.com/index.php/vod/search.html?wd={keyword}";
const RULE_COMMIT = "d2f58217e6614c2e279d6f461e278d665c2b234b";
const SNAPSHOT_SHA256 =
  "7e54969e4d8de3535242927af3c27e09a8e8d47f65ab9649a84a2163c975535c";
const DEFAULT_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3";
const REQUEST_INTERVAL_MS = 3_000;
const SEARCH_CACHE_TTL_MS = 5 * 60_000;
const EPISODE_CACHE_TTL_MS = 5 * 60_000;
const RESOLVE_CACHE_TTL_MS = 60_000;

const SUBJECT_SELECTOR = ".title > a";
const CHANNEL_NAMES_SELECTOR = ".playlist .stui-pannel__head > h3.title";
const EPISODE_LISTS_SELECTOR = ".stui-content__playlist";
const EPISODE_SORT_REGEX = /第\s*(.+?)\s*[话集]/;
const VIDEO_URL_REGEX =
  /(^http(s)?:\/\/(?!.*http(s)?:\/\/).+((\.mp4)|(\.mkv)|(m3u8)).*(\?.+)?)|(akamaized)|(bilivideo.com)|(.+\?url=(?<v>.+))/;

interface CachedValue<T> {
  readonly expiresAt: number;
  readonly value: T;
}

interface PlayerPayload {
  encrypt?: number;
  url?: string;
  from?: string;
}

const providerDescriptor: ProviderDescriptor = {
  id: PROVIDER_ID,
  name: PROVIDER_NAME,
  sourceOrigin: SOURCE_ORIGIN,
  ruleCommit: RULE_COMMIT,
  snapshotSha256: SNAPSHOT_SHA256
};

export class YinghuaProvider implements MediaProvider {
  readonly descriptor = providerDescriptor;
  readonly capabilities: ProviderCapabilities = {
    search: true,
    episodeList: true,
    resolve: true,
    browserRequired: false
  };

  readonly #fetch: FetchTransport;
  readonly #throttle: RequestThrottle;
  readonly #searchCache = new Map<string, CachedValue<readonly SourceSubject[]>>();
  readonly #episodeCache = new Map<string, CachedValue<readonly SourceEpisode[]>>();
  readonly #resolveCache = new Map<string, CachedValue<ResolvedAsset>>();

  constructor(
    fetcher: FetchTransport = new SafeFetcher(),
    options: { readonly requestIntervalMs?: number } = {}
  ) {
    this.#fetch = fetcher;
    this.#throttle = new RequestThrottle(
      options.requestIntervalMs ?? REQUEST_INTERVAL_MS
    );
  }

  async search(
    query: string,
    context: ProviderRequestContext
  ): Promise<readonly SourceSubject[]> {
    const keyword = normalizeQuery(query);
    if (keyword === "") {
      throw new ProviderError({
        code: "SOURCE_QUERY_EMPTY",
        message: "搜索关键词为空",
        retryable: false
      });
    }
    const cached = this.#searchCache.get(keyword);
    if (cached !== undefined && cached.expiresAt > Date.now()) {
      return cached.value;
    }

    const searchUrl = SEARCH_URL_TEMPLATE.replace(
      "{keyword}",
      encodeURIComponent(keyword)
    );
    await this.#throttle.waitFor(searchUrl, context.signal);
    const { response, finalUrl } = await this.#fetch.fetch(searchUrl, {
      headers: { "user-agent": DEFAULT_USER_AGENT, accept: "text/html" },
      signal: context.signal
    });
    if (!response.ok) {
      throw new ProviderError({
        code: "SOURCE_SEARCH_FAILED",
        message: `源站搜索返回 HTTP ${response.status}`,
        retryable: response.status >= 500 || response.status === 429
      });
    }
    const html = await this.#fetch.readText(response, { maxBytes: 4 * 1024 * 1024 });
    const $ = cheerio.load(html);
    const grouped = new Map<string, { name: string; pageUrl: string }>();

    $(SUBJECT_SELECTOR).each((_index, element) => {
      const anchor = $(element);
      const name = anchor.text().trim().replace(/\s+/g, " ");
      const href = anchor.attr("href");
      if (name === "" || href === undefined || href.trim() === "") {
        return;
      }
      let pageUrl: URL;
      try {
        pageUrl = new URL(href, finalUrl);
      } catch {
        return;
      }
      if (pageUrl.protocol !== "https:" && pageUrl.protocol !== "http:") {
        return;
      }
      const canonical = pageUrl.toString();
      const existing = grouped.get(canonical);
      if (existing === undefined || name.length < existing.name.length) {
        grouped.set(canonical, { name, pageUrl: canonical });
      }
    });

    const subjects: SourceSubject[] = [];
    for (const [pageUrl, entry] of grouped) {
      subjects.push({
        providerId: PROVIDER_ID,
        sourceSubjectKey: subjectKey(pageUrl),
        name: entry.name,
        pageUrl
      });
      if (subjects.length >= 20) {
        break;
      }
    }
    this.#searchCache.set(keyword, {
      expiresAt: Date.now() + SEARCH_CACHE_TTL_MS,
      value: subjects
    });
    return subjects;
  }

  async listEpisodes(
    subject: SourceSubject,
    context: ProviderRequestContext
  ): Promise<readonly SourceEpisode[]> {
    if (subject.providerId !== PROVIDER_ID) {
      throw new ProviderError({
        code: "SOURCE_PROVIDER_MISMATCH",
        message: "条目不属于当前源",
        retryable: false
      });
    }
    const cached = this.#episodeCache.get(subject.sourceSubjectKey);
    if (cached !== undefined && cached.expiresAt > Date.now()) {
      return cached.value;
    }

    await this.#throttle.waitFor(subject.pageUrl, context.signal);
    const { response, finalUrl } = await this.#fetch.fetch(subject.pageUrl, {
      headers: { "user-agent": DEFAULT_USER_AGENT, accept: "text/html" },
      signal: context.signal
    });
    if (!response.ok) {
      throw new ProviderError({
        code: "SOURCE_EPISODES_FAILED",
        message: `源站详情返回 HTTP ${response.status}`,
        retryable: response.status >= 500 || response.status === 429
      });
    }
    const html = await this.#fetch.readText(response, { maxBytes: 4 * 1024 * 1024 });
    const $ = cheerio.load(html);
    const channelNames = $(CHANNEL_NAMES_SELECTOR)
      .toArray()
      .map((element) => $(element).text().trim().replace(/\s+/g, " "));
    const episodeLists = $(EPISODE_LISTS_SELECTOR).toArray();

    const episodes: SourceEpisode[] = [];
    const seenUrls = new Set<string>();
    const channelCount = Math.max(episodeLists.length, channelNames.length, 1);

    for (let channelIndex = 0; channelIndex < channelCount; channelIndex += 1) {
      const list = episodeLists[channelIndex];
      if (list === undefined) {
        continue;
      }
      const channelName = channelNames[channelIndex];
      const channel =
        channelName !== undefined && channelName !== ""
          ? channelName
          : `线路${channelIndex + 1}`;
      let order = 0;
      $(list)
        .find("a")
        .each((_index, element) => {
          const anchor = $(element);
          const title = anchor.text().trim().replace(/\s+/g, " ");
          const href = anchor.attr("href");
          if (title === "" || href === undefined || href.trim() === "") {
            return;
          }
          const match = EPISODE_SORT_REGEX.exec(title);
          if (match === null) {
            return;
          }
          order += 1;
          let pageUrl: URL;
          try {
            pageUrl = new URL(href, finalUrl);
          } catch {
            return;
          }
          if (pageUrl.protocol !== "https:" && pageUrl.protocol !== "http:") {
            return;
          }
          const canonical = pageUrl.toString();
          if (seenUrls.has(canonical)) {
            return;
          }
          seenUrls.add(canonical);
          const rawNumber = match[1]?.trim() ?? "";
          const parsedNumber = Number.parseInt(rawNumber, 10);
          const number = Number.isInteger(parsedNumber) && parsedNumber > 0
            ? parsedNumber
            : order;
          episodes.push({
            providerId: PROVIDER_ID,
            mediaId: mediaIdFor(subject.sourceSubjectKey, channelIndex, number, canonical),
            sourceSubjectKey: subject.sourceSubjectKey,
            channel,
            episodeNumber: number,
            title,
            pageUrl: canonical
          });
        });
    }

    episodes.sort((a, b) => {
      if (a.channel !== b.channel) {
        return a.channel.localeCompare(b.channel, "zh-Hans-CN");
      }
      return a.episodeNumber - b.episodeNumber;
    });
    const result = episodes.slice(0, 500);
    this.#episodeCache.set(subject.sourceSubjectKey, {
      expiresAt: Date.now() + EPISODE_CACHE_TTL_MS,
      value: result
    });
    return result;
  }

  async resolve(
    episode: SourceEpisode,
    context: ProviderRequestContext
  ): Promise<ResolvedAsset> {
    const cached = this.#resolveCache.get(episode.mediaId);
    if (cached !== undefined && cached.expiresAt > Date.now()) {
      return cached.value;
    }

    await this.#throttle.waitFor(episode.pageUrl, context.signal);
    const { response } = await this.#fetch.fetch(episode.pageUrl, {
      headers: { "user-agent": DEFAULT_USER_AGENT, accept: "text/html" },
      signal: context.signal
    });
    if (!response.ok) {
      throw new ProviderError({
        code: "SOURCE_PLAY_PAGE_FAILED",
        message: `源站播放页返回 HTTP ${response.status}`,
        retryable: response.status >= 500 || response.status === 429
      });
    }
    const html = await this.#fetch.readText(response, { maxBytes: 4 * 1024 * 1024 });
    const payload = parsePlayerPayload(html);
    if (payload === null) {
      throw new ProviderError({
        code: "SOURCE_PLAYER_CONFIG_MISSING",
        message: "播放页没有可识别的 player_aaaa 配置",
        retryable: false
      });
    }
    const mediaUrl = decryptPlayerUrl(payload);
    if (!VIDEO_URL_REGEX.test(mediaUrl)) {
      throw new ProviderError({
        code: "SOURCE_MEDIA_URL_UNMATCHED",
        message: "解析结果不是规则允许的媒体地址",
        retryable: false
      });
    }
    await assertSafeOutboundUrl(mediaUrl, {
      allowBenchmarkNetwork: process.env.OUTBOUND_ALLOW_BENCHMARK_NETWORK === "1"
    });

    // Validation is separate from rule parsing: fetch the master playlist and
    // verify that it is HLS before reporting the asset as resolvable.
    const headers = {
      "user-agent": DEFAULT_USER_AGENT
    };
    await this.#throttle.waitFor(mediaUrl, context.signal);
    const master = await this.#fetch.fetch(mediaUrl, {
      headers,
      signal: context.signal
    });
    if (!master.response.ok) {
      throw new ProviderError({
        code: "SOURCE_MEDIA_VALIDATION_FAILED",
        message: `媒体主清单返回 HTTP ${master.response.status}`,
        retryable: master.response.status >= 500 || master.response.status === 429
      });
    }
    const playlist = await this.#fetch.readText(master.response, {
      maxBytes: 4 * 1024 * 1024
    });
    if (!playlist.trimStart().startsWith("#EXTM3U")) {
      throw new ProviderError({
        code: "SOURCE_MEDIA_VALIDATION_FAILED",
        message: "媒体主清单不是 HLS",
        retryable: false
      });
    }

    const asset: ResolvedAsset = {
      assetId: randomUUID(),
      mediaId: episode.mediaId,
      upstreamUrl: mediaUrl,
      upstreamHeaders: headers,
      mediaType: "hls",
      expiresAt: new Date(Date.now() + 30 * 60_000).toISOString(),
      provider: providerDescriptor
    };
    this.#resolveCache.set(episode.mediaId, {
      expiresAt: Date.now() + RESOLVE_CACHE_TTL_MS,
      value: asset
    });
    return asset;
  }
}

function normalizeQuery(query: string): string {
  const firstWord = query.trim().split(/\s+/)[0] ?? "";
  return firstWord.replace(/[^\p{L}\p{N}\s]/gu, "").trim().slice(0, 120);
}

function subjectKey(pageUrl: string): string {
  const id = /\/id\/(\d+)\.html/.exec(pageUrl)?.[1];
  return `${PROVIDER_ID}:subject:${id ?? shortHash(pageUrl)}`;
}

function mediaIdFor(
  subjectKeyValue: string,
  channelIndex: number,
  episodeNumber: number,
  url: string
): string {
  return `${subjectKeyValue}:channel:${channelIndex}:episode:${episodeNumber}:${shortHash(url)}`;
}

function shortHash(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}

function parsePlayerPayload(html: string): PlayerPayload | null {
  const match = /var\s+player_aaaa\s*=\s*(\{.*?\})\s*<\/script>/s.exec(html);
  if (match?.[1] === undefined) {
    return null;
  }
  try {
    const parsed = JSON.parse(match[1]) as PlayerPayload;
    if (parsed === null || typeof parsed !== "object") {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

function decryptPlayerUrl(payload: PlayerPayload): string {
  const raw = payload.url;
  if (typeof raw !== "string" || raw.trim() === "") {
    throw new ProviderError({
      code: "SOURCE_PLAYER_URL_MISSING",
      message: "播放页配置没有媒体地址",
      retryable: false
    });
  }
  switch (payload.encrypt ?? 0) {
    case 0:
      return raw;
    case 1:
      return legacyUnescape(raw);
    case 2:
      return legacyUnescape(Buffer.from(raw, "base64").toString("latin1"));
    default:
      throw new ProviderError({
        code: "SOURCE_ENCRYPTION_UNSUPPORTED",
        message: "该源的播放地址加密方式需要浏览器，当前适配器未启用",
        retryable: false,
        details: { encrypt: payload.encrypt }
      });
  }
}

function legacyUnescape(value: string): string {
  return value.replace(/%u([0-9a-fA-F]{4})|%([0-9a-fA-F]{2})/g, (_match, unicode, hex) => {
    const code = Number.parseInt(unicode ?? hex, 16);
    return Number.isFinite(code) ? String.fromCharCode(code) : "";
  });
}
