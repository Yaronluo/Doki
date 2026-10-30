import type { LookupAddress } from "node:dns";
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";
import { ProviderError, type FetchTransport, type SafeFetchResult } from "./types.js";

const DEFAULT_TIMEOUT_MS = 20_000;
const DEFAULT_MAX_REDIRECTS = 4;
const ALLOWED_PORTS = new Set([80, 443]);
const FORBIDDEN_HOST_SUFFIXES = [".local", ".internal", ".lan", ".home", ".test"];
const FORBIDDEN_HOSTS = new Set(["localhost", "localhost.localdomain"]);

function blocked(message: string, details?: Record<string, unknown>): ProviderError {
  return new ProviderError({
    code: "OUTBOUND_URL_BLOCKED",
    message,
    retryable: false,
    ...(details === undefined ? {} : { details })
  });
}

function isPrivateIPv4(address: string, allowBenchmarkNetwork: boolean): boolean {
  const parts = address.split(".").map((part) => Number(part));
  if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) {
    return true;
  }
  const [a, b] = parts as [number, number, number, number];
  return (
    a === 0 ||
    a === 10 ||
    a === 127 ||
    (a === 100 && b >= 64 && b <= 127) ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 0) ||
    (a === 192 && b === 168) ||
    (!allowBenchmarkNetwork && a === 198 && (b === 18 || b === 19)) ||
    a >= 224
  );
}

function isPrivateIPv6(address: string): boolean {
  const normalized = address.toLowerCase().split("%")[0] ?? address.toLowerCase();
  if (normalized === "::" || normalized === "::1") {
    return true;
  }
  // Reject IPv4-mapped forms conservatively; the provider targets public hosts.
  if (normalized.startsWith("::ffff:")) {
    return true;
  }
  return (
    normalized.startsWith("fc") ||
    normalized.startsWith("fd") ||
    normalized.startsWith("fe8") ||
    normalized.startsWith("fe9") ||
    normalized.startsWith("fea") ||
    normalized.startsWith("feb") ||
    normalized.startsWith("ff") ||
    normalized.startsWith("2001:db8")
  );
}

function isPrivateAddress(
  address: string,
  allowBenchmarkNetwork: boolean
): boolean {
  const version = isIP(address);
  if (version === 4) {
    return isPrivateIPv4(address, allowBenchmarkNetwork);
  }
  if (version === 6) {
    return isPrivateIPv6(address);
  }
  return true;
}

/**
 * Validates an outbound URL before every request and redirect. This blocks
 * credentials, non-HTTP schemes, non-public ports and private/loopback DNS
 * answers. It is not a substitute for a network-level egress proxy or IP
 * pinning; that hardening remains an OPS-001 follow-up.
 */
export interface OutboundSafetyOptions {
  /**
   * The CI/dev host may route egress through a transparent proxy that resolves
   * public names to 198.18.0.0/15. This opt-in is for local verification only;
   * production must leave it disabled.
   */
  readonly allowBenchmarkNetwork?: boolean;
}

export async function assertSafeOutboundUrl(
  raw: string,
  options: OutboundSafetyOptions = {}
): Promise<URL> {
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    throw blocked("Outbound URL is not a valid URL");
  }
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw blocked("Only http(s) outbound URLs are allowed", {
      protocol: parsed.protocol
    });
  }
  if (parsed.username !== "" || parsed.password !== "") {
    throw blocked("Outbound URL must not contain credentials");
  }
  const port = parsed.port === "" ? (parsed.protocol === "https:" ? 443 : 80) : Number(parsed.port);
  if (!ALLOWED_PORTS.has(port)) {
    throw blocked("Outbound port is not allowed", { port });
  }
  const hostname = parsed.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (
    FORBIDDEN_HOSTS.has(hostname) ||
    FORBIDDEN_HOST_SUFFIXES.some((suffix) => hostname.endsWith(suffix))
  ) {
    throw blocked("Outbound hostname is not allowed", { hostname });
  }

  if (isIP(hostname) !== 0) {
    if (isPrivateAddress(hostname, options.allowBenchmarkNetwork === true)) {
      throw blocked("Outbound address must be public", { hostname });
    }
    return parsed;
  }

  let addresses: LookupAddress[];
  try {
    addresses = (await lookup(hostname, {
      all: true,
      verbatim: true
    })) as LookupAddress[];
  } catch {
    throw new ProviderError({
      code: "OUTBOUND_DNS_FAILED",
      message: "Outbound host could not be resolved",
      retryable: true
    });
  }
  if (addresses.length === 0) {
    throw new ProviderError({
      code: "OUTBOUND_DNS_FAILED",
      message: "Outbound host resolved to no addresses",
      retryable: true
    });
  }
  for (const entry of addresses) {
    if (isPrivateAddress(entry.address, options.allowBenchmarkNetwork === true)) {
      throw blocked("Outbound host resolved to a private address");
    }
  }
  return parsed;
}

function sanitizeHeaders(
  headers: Readonly<Record<string, string>> | undefined
): Record<string, string> {
  if (headers === undefined) {
    return {};
  }
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(headers)) {
    if (/\r|\n/.test(value) || /[\r\n]/.test(key)) {
      continue;
    }
    result[key] = value;
  }
  return result;
}

function crossOriginHeaders(
  headers: Record<string, string>,
  from: URL,
  to: URL
): Record<string, string> {
  if (from.origin === to.origin) {
    return headers;
  }
  const next = { ...headers };
  for (const key of Object.keys(next)) {
    if (["authorization", "cookie", "referer", "origin"].includes(key.toLowerCase())) {
      delete next[key];
    }
  }
  return next;
}

export class SafeFetcher implements FetchTransport {
  readonly #timeoutMs: number;
  readonly #maxRedirects: number;
  readonly #allowBenchmarkNetwork: boolean;

  constructor(
    options: {
      timeoutMs?: number;
      maxRedirects?: number;
      allowBenchmarkNetwork?: boolean;
    } = {}
  ) {
    this.#timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    this.#maxRedirects = options.maxRedirects ?? DEFAULT_MAX_REDIRECTS;
    this.#allowBenchmarkNetwork =
      options.allowBenchmarkNetwork ??
      process.env.OUTBOUND_ALLOW_BENCHMARK_NETWORK === "1";
  }

  async fetch(
    url: string,
    options: {
      readonly method?: string;
      readonly body?: string;
      readonly headers?: Readonly<Record<string, string>>;
      readonly signal?: AbortSignal;
      readonly maxRedirects?: number;
      readonly followRedirects?: boolean;
    } = {}
  ): Promise<SafeFetchResult> {
    let current = await assertSafeOutboundUrl(url, {
      allowBenchmarkNetwork: this.#allowBenchmarkNetwork
    });
    let headers = sanitizeHeaders(options.headers);
    const maxRedirects = Math.min(
      options.maxRedirects ?? this.#maxRedirects,
      this.#maxRedirects
    );

    for (let attempt = 0; attempt <= maxRedirects; attempt += 1) {
      const timeout = AbortSignal.timeout(this.#timeoutMs);
      const signal =
        options.signal === undefined
          ? timeout
          : AbortSignal.any([options.signal, timeout]);
      let response: Response;
      try {
        response = await fetch(current, {
          method: options.method ?? "GET",
          ...(options.body === undefined ? {} : { body: options.body }),
          headers,
          redirect: "manual",
          signal
        });
      } catch {
        throw new ProviderError({
          code: "OUTBOUND_FETCH_FAILED",
          message: "Upstream request failed",
          retryable: true
        });
      }

      if ([301, 302, 303, 307, 308].includes(response.status)) {
        if (options.followRedirects === false) return { response, finalUrl: current };
        const location = response.headers.get("location");
        if (location === null) {
          throw new ProviderError({
            code: "OUTBOUND_REDIRECT_INVALID",
            message: "Upstream redirect had no location",
            retryable: false
          });
        }
        let next: URL;
        try {
          next = new URL(location, current);
        } catch {
          throw new ProviderError({
            code: "OUTBOUND_REDIRECT_INVALID",
            message: "Upstream redirect location was invalid",
            retryable: false
          });
        }
        const safeNext = await assertSafeOutboundUrl(next.toString(), {
          allowBenchmarkNetwork: this.#allowBenchmarkNetwork
        });
        headers = crossOriginHeaders(headers, current, safeNext);
        await response.body?.cancel().catch(() => undefined);
        current = safeNext;
        continue;
      }

      return { response, finalUrl: current };
    }

    throw new ProviderError({
      code: "OUTBOUND_REDIRECT_LIMIT",
      message: "Upstream redirected too many times",
      retryable: false
    });
  }

  async readText(
    response: Response,
    options: { readonly maxBytes?: number } = {}
  ): Promise<string> {
    const maxBytes = options.maxBytes ?? 4 * 1024 * 1024;
    const declared = response.headers.get("content-length");
    if (declared !== null && Number(declared) > maxBytes) {
      throw new ProviderError({
        code: "OUTBOUND_RESPONSE_TOO_LARGE",
        message: "Upstream response exceeded the text limit",
        retryable: false
      });
    }
    const reader = response.body?.getReader();
    if (!reader) return "";
    const chunks: Uint8Array[] = [];
    let size = 0;
    try {
      while (true) {
        const next = await reader.read();
        if (next.done) break;
        size += next.value.byteLength;
        if (size > maxBytes) throw new ProviderError({ code: "OUTBOUND_RESPONSE_TOO_LARGE", message: "Upstream response exceeded the text limit", retryable: false });
        chunks.push(next.value);
      }
    } finally { await reader.cancel().catch(() => undefined); }
    return Buffer.concat(chunks).toString("utf8");
  }
}

export class RequestThrottle {
  readonly #minimumIntervalMs: number;
  readonly #lastByHost = new Map<string, number>();

  constructor(minimumIntervalMs: number) {
    this.#minimumIntervalMs = minimumIntervalMs;
  }

  async waitFor(url: string, signal?: AbortSignal): Promise<void> {
    const host = new URL(url).hostname;
    const last = this.#lastByHost.get(host) ?? 0;
    const remaining = last + this.#minimumIntervalMs - Date.now();
    this.#lastByHost.set(host, Date.now() + Math.max(0, remaining));
    if (remaining <= 0) {
      return;
    }
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(resolve, remaining);
      timer.unref();
      signal?.addEventListener(
        "abort",
        () => {
          clearTimeout(timer);
          reject(new DOMException("The operation was aborted.", "AbortError"));
        },
        { once: true }
      );
    });
  }
}
