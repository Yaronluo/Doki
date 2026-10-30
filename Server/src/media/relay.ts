import { createHmac, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import { Readable } from "node:stream";
import { assertSafeOutboundUrl, SafeFetcher } from "../providers/safe-fetch.js";
import {
  ProviderError,
  type FetchTransport
} from "../providers/types.js";

const SESSION_TTL_MS = 2 * 60 * 60_000;
const RESOURCE_TTL_SECONDS = 2 * 60 * 60;

export type RelayResourceKind = "playlist" | "segment" | "key";

interface RelayResource {
  readonly id: string;
  readonly upstreamUrl: string;
  readonly headers: Readonly<Record<string, string>>;
  readonly kind: RelayResourceKind;
}

export interface RelaySession {
  readonly id: string;
  readonly providerId: string;
  readonly createdAtMs: number;
  readonly expiresAtMs: number;
  readonly headers: Readonly<Record<string, string>>;
  readonly resources: Map<string, RelayResource>;
  readonly resourcesByUrl: Map<string, string>;
}

export interface RelaySessionPlan {
  readonly sessionId: string;
  readonly masterUrl: string;
  readonly expiresAt: string;
}

export interface RelayRequest {
  readonly sessionId: string;
  readonly resourceId: string;
  readonly exp: number;
  readonly sig: string;
  readonly method: "GET" | "HEAD";
  readonly range?: string;
}

export interface RelayResponse {
  readonly statusCode: number;
  readonly headers: Readonly<Record<string, string>>;
  readonly body: Buffer | Readable | null;
}

export class MediaRelay {
  readonly #signingKey: Buffer;
  readonly #hubBaseUrl: URL;
  readonly #fetcher: FetchTransport;
  readonly #sessions = new Map<string, RelaySession>();
  readonly #sessionTtlMs: number;

  constructor(options: {
    signingKey: Buffer;
    hubBaseUrl: string;
    fetcher?: FetchTransport;
    sessionTtlMs?: number;
  }) {
    this.#signingKey = Buffer.from(options.signingKey);
    this.#hubBaseUrl = new URL(options.hubBaseUrl);
    this.#fetcher = options.fetcher ?? new SafeFetcher();
    this.#sessionTtlMs = options.sessionTtlMs ?? SESSION_TTL_MS;
  }

  createSession(input: {
    providerId: string;
    upstreamUrl: string;
    headers: Readonly<Record<string, string>>;
  }): RelaySessionPlan {
    this.cleanup();
    const now = Date.now();
    const session: RelaySession = {
      id: `ps_${randomUUID().replaceAll("-", "")}`,
      providerId: input.providerId,
      createdAtMs: now,
      expiresAtMs: now + this.#sessionTtlMs,
      headers: { ...input.headers },
      resources: new Map(),
      resourcesByUrl: new Map()
    };
    const master = this.registerResource(
      session,
      input.upstreamUrl,
      "playlist",
      input.headers
    );
    this.#sessions.set(session.id, session);
    return {
      sessionId: session.id,
      masterUrl: this.signedUrl(session.id, master.id, "GET"),
      expiresAt: new Date(session.expiresAtMs).toISOString()
    };
  }

  verify(request: Omit<RelayRequest, "range">): boolean {
    const session = this.#sessions.get(request.sessionId);
    if (session === undefined || session.expiresAtMs <= Date.now()) {
      return false;
    }
    if (!Number.isSafeInteger(request.exp) || request.exp * 1000 <= Date.now()) {
      return false;
    }
    if (request.exp * 1000 > session.expiresAtMs + 60_000) {
      return false;
    }
    const methods = request.method === "HEAD" ? ["HEAD", "GET"] : ["GET"];
    const actualBuffer = Buffer.from(request.sig);
    return methods.some((method) => {
      const expectedBuffer = Buffer.from(
        this.sign(request.sessionId, request.resourceId, request.exp, method)
      );
      return (
        expectedBuffer.length === actualBuffer.length &&
        timingSafeEqual(expectedBuffer, actualBuffer)
      );
    });
  }

  async handle(request: RelayRequest): Promise<RelayResponse> {
    if (!this.verify(request)) {
      throw new ProviderError({
        code: "MEDIA_URL_INVALID",
        message: "媒体地址无效或已过期",
        retryable: false
      });
    }
    const session = this.#sessions.get(request.sessionId);
    if (session === undefined) {
      throw new ProviderError({
        code: "MEDIA_SESSION_NOT_FOUND",
        message: "播放会话不存在或已过期",
        retryable: false
      });
    }
    const resource = session.resources.get(request.resourceId);
    if (resource === undefined) {
      throw new ProviderError({
        code: "MEDIA_RESOURCE_NOT_FOUND",
        message: "媒体资源不存在",
        retryable: false
      });
    }

    const headers: Record<string, string> = { ...resource.headers };
    if (request.range !== undefined) {
      headers.range = request.range;
    }

    const { response, finalUrl } = await this.#fetcher.fetch(resource.upstreamUrl, {
      method: request.method,
      headers,
      maxRedirects: 4
    });
    if (!response.ok && response.status !== 206) {
      throw new ProviderError({
        code: "UPSTREAM_MEDIA_FAILED",
        message: "上游媒体请求失败",
        retryable: response.status >= 500 || response.status === 429,
        details: { upstreamStatus: response.status }
      });
    }

    if (request.method === "HEAD") {
      return {
        statusCode: response.status,
        headers: this.copyMediaHeaders(response),
        body: null
      };
    }

    if (resource.kind === "playlist") {
      const text = await this.#fetcher.readText(response, {
        maxBytes: 4 * 1024 * 1024
      });
      if (!text.trimStart().startsWith("#EXTM3U")) {
        throw new ProviderError({
          code: "UPSTREAM_MEDIA_NOT_HLS",
          message: "上游资源不是 HLS 清单",
          retryable: false
        });
      }
      const rewritten = await this.rewritePlaylist(session, text, finalUrl, resource);
      return {
        statusCode: 200,
        headers: {
          "content-type": "application/vnd.apple.mpegurl; charset=utf-8",
          "cache-control": "no-store"
        },
        body: Buffer.from(rewritten, "utf8")
      };
    }

    if (response.body === null) {
      throw new ProviderError({
        code: "UPSTREAM_MEDIA_EMPTY",
        message: "上游媒体没有响应体",
        retryable: true
      });
    }
    return {
      statusCode: response.status === 206 ? 206 : 200,
      headers: this.copyMediaHeaders(response),
      body: Readable.fromWeb(response.body)
    };
  }

  private signedUrl(
    sessionId: string,
    resourceId: string,
    method: "GET" | "HEAD"
  ): string {
    const exp = Math.floor(Date.now() / 1000) + RESOURCE_TTL_SECONDS;
    const sig = this.sign(sessionId, resourceId, exp, method);
    const url = new URL(`/s/${sessionId}/${resourceId}`, this.#hubBaseUrl);
    url.searchParams.set("exp", String(exp));
    url.searchParams.set("sig", sig);
    return url.toString();
  }

  private sign(
    sessionId: string,
    resourceId: string,
    exp: number,
    method: string
  ): string {
    return createHmac("sha256", this.#signingKey)
      .update(`${sessionId}:${resourceId}:${exp}:${method}`)
      .digest("base64url");
  }

  private registerResource(
    session: RelaySession,
    upstreamUrl: string,
    kind: RelayResourceKind,
    headers: Readonly<Record<string, string>>
  ): RelayResource {
    const existing = session.resourcesByUrl.get(upstreamUrl);
    if (existing !== undefined) {
      const resource = session.resources.get(existing);
      if (resource !== undefined) {
        return resource;
      }
    }
    const resource: RelayResource = {
      id: randomBytes(18).toString("base64url"),
      upstreamUrl,
      headers: { ...headers },
      kind
    };
    session.resources.set(resource.id, resource);
    session.resourcesByUrl.set(upstreamUrl, resource.id);
    return resource;
  }

  private async rewritePlaylist(
    session: RelaySession,
    text: string,
    baseUrl: URL,
    resource: RelayResource
  ): Promise<string> {
    const isMaster = text.includes("#EXT-X-STREAM-INF");
    const lines = text.replace(/\r\n/g, "\n").split("\n");
    const rewritten: string[] = [];

    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed === "") {
        rewritten.push(line);
        continue;
      }
      if (trimmed.startsWith("#")) {
        if (trimmed.startsWith("#EXT-X-KEY") || trimmed.startsWith("#EXT-X-MAP")) {
          rewritten.push(
            await this.rewriteUriAttributes(
              session,
              line,
              baseUrl,
              trimmed.startsWith("#EXT-X-KEY") ? "key" : "segment"
            )
          );
        } else {
          rewritten.push(line);
        }
        continue;
      }
      const resolved = new URL(trimmed, baseUrl);
      await assertSafeOutboundUrl(resolved.toString(), {
        allowBenchmarkNetwork: process.env.OUTBOUND_ALLOW_BENCHMARK_NETWORK === "1"
      });
      const child = this.registerResource(
        session,
        resolved.toString(),
        isMaster ? "playlist" : "segment",
        resource.headers
      );
      rewritten.push(this.signedUrl(session.id, child.id, "GET"));
    }

    return rewritten.join("\n");
  }

  private async rewriteUriAttributes(
    session: RelaySession,
    line: string,
    baseUrl: URL,
    kind: RelayResourceKind
  ): Promise<string> {
    const matches = [...line.matchAll(/URI="([^"]+)"/g)];
    let result = line;
    for (const match of matches) {
      const uri = match[1];
      if (uri === undefined || uri === "") {
        continue;
      }
      const resolved = new URL(uri, baseUrl);
      await assertSafeOutboundUrl(resolved.toString(), {
        allowBenchmarkNetwork: process.env.OUTBOUND_ALLOW_BENCHMARK_NETWORK === "1"
      });
      const child = this.registerResource(
        session,
        resolved.toString(),
        kind,
        session.headers
      );
      result = result.replace(match[0], `URI="${this.signedUrl(session.id, child.id, "GET")}"`);
    }
    return result;
  }

  private copyMediaHeaders(response: Response): Record<string, string> {
    const result: Record<string, string> = {
      "cache-control": "no-store"
    };
    for (const key of [
      "content-type",
      "content-length",
      "content-range",
      "accept-ranges",
      "etag",
      "last-modified"
    ]) {
      const value = response.headers.get(key);
      if (value !== null) {
        result[key] = value;
      }
    }
    return result;
  }

  private cleanup(): void {
    const now = Date.now();
    for (const [id, session] of this.#sessions) {
      if (session.expiresAtMs <= now) {
        this.#sessions.delete(id);
      }
    }
  }
}
