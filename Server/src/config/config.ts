import { z } from "zod";
import type {
  BootstrapCapabilities,
  CapabilityState
} from "../contracts/bootstrap.js";

export type Environment = "development" | "test" | "production";

export interface HubEndpointConfig {
  readonly host: string;
  readonly port: number;
  readonly baseUrl: string;
}

export interface ConfigIssue {
  readonly path: string;
  readonly message: string;
}

export class ConfigValidationError extends Error {
  readonly issues: readonly ConfigIssue[];

  constructor(issues: readonly ConfigIssue[]) {
    super(`Invalid Hub configuration (${issues.length} issue(s))`);
    this.name = "ConfigValidationError";
    this.issues = issues;
  }
}

export class BangumiConfig {
  readonly clientId: string;
  readonly redirectUri: string;
  readonly #clientSecret: string;

  constructor(input: {
    clientId: string;
    clientSecret: string;
    redirectUri: string;
  }) {
    this.clientId = input.clientId;
    this.#clientSecret = input.clientSecret;
    this.redirectUri = input.redirectUri;
    Object.freeze(this);
  }

  get clientSecret(): string {
    return this.#clientSecret;
  }

  toJSON(): Record<string, string> {
    return {
      clientId: this.clientId,
      redirectUri: this.redirectUri,
      clientSecret: "[redacted]"
    };
  }
}

export class TmdbConfig {
  readonly #readAccessToken: string;

  constructor(readAccessToken: string) {
    this.#readAccessToken = readAccessToken;
    Object.freeze(this);
  }

  get readAccessToken(): string {
    return this.#readAccessToken;
  }

  toJSON(): Record<string, string> {
    return { readAccessToken: "[redacted]" };
  }
}

export class DandanplayConfig {
  readonly appId: string;
  readonly #appSecret: string;

  constructor(input: { appId: string; appSecret: string }) {
    this.appId = input.appId;
    this.#appSecret = input.appSecret;
    Object.freeze(this);
  }

  get appSecret(): string {
    return this.#appSecret;
  }

  toJSON(): Record<string, string> {
    return { appId: this.appId, appSecret: "[redacted]" };
  }
}

export interface RedactedConfigSummary {
  readonly environment: Environment;
  readonly hub: HubEndpointConfig;
  readonly database: { readonly configured: true };
  readonly redis: { readonly configured: boolean };
  readonly setupSecret: "configured" | "notConfigured";
  readonly keys: {
    readonly credentialEncryption: "configured";
    readonly streamSigning: "configured";
  };
  readonly providers: {
    readonly bangumi: "configured" | "notConfigured";
    readonly tmdb: "configured" | "notConfigured";
    readonly dandanplay: "configured" | "notConfigured";
  };
  readonly capabilities: BootstrapCapabilities;
}

/**
 * Runtime configuration. Secret-bearing fields are private and only available
 * through getters; JSON serialization always goes through toJSON(), which
 * returns a redacted summary.
 */
export class HubConfig {
  readonly environment: Environment;
  readonly hub: HubEndpointConfig;
  readonly #databaseUrl: string;
  readonly #redisUrl: string | undefined;
  readonly #setupSecret: string | undefined;
  readonly #credentialEncryptionKey: Buffer;
  readonly #streamSigningKey: Buffer;
  readonly #bangumi: BangumiConfig | undefined;
  readonly #tmdb: TmdbConfig | undefined;
  readonly #dandanplay: DandanplayConfig | undefined;

  constructor(input: {
    environment: Environment;
    hub: HubEndpointConfig;
    databaseUrl: string;
    redisUrl: string | undefined;
    setupSecret: string | undefined;
    credentialEncryptionKey: Buffer;
    streamSigningKey: Buffer;
    bangumi: BangumiConfig | undefined;
    tmdb: TmdbConfig | undefined;
    dandanplay: DandanplayConfig | undefined;
  }) {
    this.environment = input.environment;
    this.hub = Object.freeze({ ...input.hub });
    this.#databaseUrl = input.databaseUrl;
    this.#redisUrl = input.redisUrl;
    this.#setupSecret = input.setupSecret;
    this.#credentialEncryptionKey = input.credentialEncryptionKey;
    this.#streamSigningKey = input.streamSigningKey;
    this.#bangumi = input.bangumi;
    this.#tmdb = input.tmdb;
    this.#dandanplay = input.dandanplay;
    Object.freeze(this);
  }

  get databaseUrl(): string {
    return this.#databaseUrl;
  }

  get redisUrl(): string | undefined {
    return this.#redisUrl;
  }

  get setupSecret(): string | undefined {
    return this.#setupSecret;
  }

  get credentialEncryptionKey(): Buffer {
    return Buffer.from(this.#credentialEncryptionKey);
  }

  get streamSigningKey(): Buffer {
    return Buffer.from(this.#streamSigningKey);
  }

  get bangumi(): BangumiConfig | undefined {
    return this.#bangumi;
  }

  get tmdb(): TmdbConfig | undefined {
    return this.#tmdb;
  }

  get dandanplay(): DandanplayConfig | undefined {
    return this.#dandanplay;
  }

  /**
   * Exact values that must never reach a log sink. Used to build the logger
   * redactor; callers must not serialize this list.
   */
  secretValuesForLogRedaction(): readonly string[] {
    const values: (string | undefined)[] = [
      this.#databaseUrl,
      this.#redisUrl,
      this.#setupSecret,
      this.#credentialEncryptionKey.toString("base64"),
      this.#streamSigningKey.toString("base64"),
      this.#bangumi?.clientSecret,
      this.#tmdb?.readAccessToken,
      this.#dandanplay?.appSecret
    ];
    return values.filter(
      (value): value is string => value !== undefined && value.length >= 8
    );
  }

  toJSON(): RedactedConfigSummary {
    return redactedSummary(this);
  }
}

const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "::1", "[::1]"]);

function normalizeHttpUrl(
  raw: string,
  options: { readonly allowLoopbackHttp: boolean }
): string | null {
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    return null;
  }
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    return null;
  }
  if (parsed.username !== "" || parsed.password !== "") {
    return null;
  }
  if (parsed.search !== "" || parsed.hash !== "") {
    return null;
  }
  if (
    parsed.protocol === "http:" &&
    !(options.allowLoopbackHttp && LOOPBACK_HOSTS.has(parsed.hostname))
  ) {
    return null;
  }
  const pathname = parsed.pathname.replace(/\/+$/, "");
  return `${parsed.origin}${pathname}`;
}

function normalizeBaseUrl(raw: string): string | null {
  return normalizeHttpUrl(raw, { allowLoopbackHttp: true });
}

function normalizeRedirectUri(raw: string): string | null {
  return normalizeHttpUrl(raw, { allowLoopbackHttp: true });
}

function isPostgresUrl(raw: string): boolean {
  try {
    const parsed = new URL(raw);
    return (
      (parsed.protocol === "postgres:" || parsed.protocol === "postgresql:") &&
      parsed.hostname !== "" &&
      parsed.pathname.length > 1
    );
  } catch {
    return false;
  }
}

function isRedisUrl(raw: string): boolean {
  try {
    const parsed = new URL(raw);
    return (
      (parsed.protocol === "redis:" || parsed.protocol === "rediss:") &&
      parsed.hostname !== ""
    );
  } catch {
    return false;
  }
}

function isBase64Key(raw: string): boolean {
  const compact = raw.replace(/\s+/g, "");
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(compact)) {
    return false;
  }
  const decoded = Buffer.from(compact, "base64");
  const canonical = decoded.toString("base64").replace(/=+$/, "");
  return (
    decoded.length === 32 &&
    canonical === compact.replace(/=+$/, "")
  );
}

function emptyToUndefined(value: unknown): unknown {
  return typeof value === "string" && value.trim() === "" ? undefined : value;
}

const optionalTrimmedString = z.preprocess(
  emptyToUndefined,
  z.string().trim().min(1).max(2_048).optional()
);

const optionalSetupSecret = z.preprocess(
  emptyToUndefined,
  z.string().trim().min(32).max(512).optional()
);

const optionalSecret = (minimum: number) =>
  z.preprocess(
    emptyToUndefined,
    z.string().trim().min(minimum).max(2_048).optional()
  );

const optionalUrl = z.preprocess(
  emptyToUndefined,
  z.string().trim().min(1).max(2_048).optional()
);

const environmentSchema = z.object({
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
  HUB_HOST: z
    .string()
    .trim()
    .min(1)
    .max(255)
    .regex(/^[A-Za-z0-9._:-]+$/, {
      message: "must be a hostname or IP address without spaces or slashes"
    })
    .default("127.0.0.1"),
  HUB_PORT: z.preprocess(
    emptyToUndefined,
    z.coerce.number().int().min(1).max(65_535).default(8080)
  ),
  HUB_BASE_URL: z
    .string()
    .trim()
    .min(1)
    .max(2_048)
    .transform((value, ctx) => {
      const normalized = normalizeBaseUrl(value);
      if (normalized === null) {
        ctx.addIssue({
          code: "custom",
          message:
            "must be an http(s) URL without credentials, query, or fragment"
        });
        return z.NEVER;
      }
      return normalized;
    }),
  DATABASE_URL: z
    .string()
    .trim()
    .min(1)
    .refine(isPostgresUrl, {
      message: "must be a postgres:// or postgresql:// URL with a database name"
    }),
  REDIS_URL: optionalUrl.refine(
    (value) => value === undefined || isRedisUrl(value),
    { message: "must be a redis:// or rediss:// URL" }
  ),
  HUB_SETUP_SECRET: optionalSetupSecret,
  CREDENTIAL_ENCRYPTION_KEY: z
    .string()
    .trim()
    .min(1)
    .refine(isBase64Key, {
      message: "must be a base64-encoded 32-byte key"
    }),
  STREAM_SIGNING_KEY: z
    .string()
    .trim()
    .min(1)
    .refine(isBase64Key, {
      message: "must be a base64-encoded 32-byte key"
    }),
  BGM_CLIENT_ID: optionalTrimmedString,
  BGM_CLIENT_SECRET: optionalSecret(16),
  BGM_REDIRECT_URI: optionalUrl.refine(
    (value) => value === undefined || normalizeRedirectUri(value) !== null,
    {
      message:
        "must be an https:// URL (http:// is allowed only for loopback development)"
    }
  ),
  TMDB_READ_ACCESS_TOKEN: optionalSecret(32),
  DANDANPLAY_APP_ID: optionalTrimmedString,
  DANDANPLAY_APP_SECRET: optionalSecret(16)
});

type ParsedEnvironment = z.infer<typeof environmentSchema>;

function zodIssuesToConfigIssues(
  issues: readonly { path: PropertyKey[]; message: string }[]
): ConfigIssue[] {
  return issues.map((issue) => ({
    path: issue.path.length > 0 ? issue.path.map(String).join(".") : "environment",
    message: issue.message
  }));
}

function groupIssues(
  parsed: ParsedEnvironment,
  fields: readonly (keyof ParsedEnvironment)[]
): ConfigIssue[] {
  const present = fields.filter((field) => parsed[field] !== undefined);
  if (present.length === 0 || present.length === fields.length) {
    return [];
  }
  const missing = fields.filter((field) => parsed[field] === undefined);
  return missing.map((field) => ({
    path: String(field),
    message: `must be set together with ${fields.join(", ")}`
  }));
}

function buildCapabilities(input: {
  bangumi: boolean;
  tmdb: boolean;
  dandanplay: boolean;
}): BootstrapCapabilities {
  return {
    bangumi: { state: capabilityState(input.bangumi) },
    tmdb: { state: capabilityState(input.tmdb) },
    danmaku: {
      state: capabilityState(input.dandanplay),
      provider: "dandanplay"
    }
  };
}

/**
 * HUB-001 has no external verification step, so a configured provider is
 * always "unavailable", never "ready". Empty credentials are "notConfigured".
 */
export function capabilityState(configured: boolean): CapabilityState {
  return configured ? "unavailable" : "notConfigured";
}

export function buildBootstrapCapabilities(
  config: HubConfig
): BootstrapCapabilities {
  return buildCapabilities({
    bangumi: config.bangumi !== undefined,
    tmdb: config.tmdb !== undefined,
    dandanplay: config.dandanplay !== undefined
  });
}

export function redactedSummary(config: HubConfig): RedactedConfigSummary {
  return {
    environment: config.environment,
    hub: {
      host: config.hub.host,
      port: config.hub.port,
      baseUrl: config.hub.baseUrl
    },
    database: { configured: true },
    redis: { configured: config.redisUrl !== undefined },
    setupSecret: config.setupSecret === undefined ? "notConfigured" : "configured",
    keys: {
      credentialEncryption: "configured",
      streamSigning: "configured"
    },
    providers: {
      bangumi: config.bangumi === undefined ? "notConfigured" : "configured",
      tmdb: config.tmdb === undefined ? "notConfigured" : "configured",
      dandanplay:
        config.dandanplay === undefined ? "notConfigured" : "configured"
    },
    capabilities: buildBootstrapCapabilities(config)
  };
}

export function loadConfig(
  env: NodeJS.ProcessEnv | Record<string, string | undefined> = process.env
): HubConfig {
  const parsedResult = environmentSchema.safeParse(env);
  if (!parsedResult.success) {
    throw new ConfigValidationError(
      zodIssuesToConfigIssues(parsedResult.error.issues)
    );
  }
  const parsed = parsedResult.data;
  const issues: ConfigIssue[] = [
    ...groupIssues(parsed, [
      "BGM_CLIENT_ID",
      "BGM_CLIENT_SECRET",
      "BGM_REDIRECT_URI"
    ]),
    ...groupIssues(parsed, [
      "DANDANPLAY_APP_ID",
      "DANDANPLAY_APP_SECRET"
    ])
  ];
  if (issues.length > 0) {
    throw new ConfigValidationError(issues);
  }

  const bangumi =
    parsed.BGM_CLIENT_ID !== undefined &&
    parsed.BGM_CLIENT_SECRET !== undefined &&
    parsed.BGM_REDIRECT_URI !== undefined
      ? new BangumiConfig({
          clientId: parsed.BGM_CLIENT_ID,
          clientSecret: parsed.BGM_CLIENT_SECRET,
          redirectUri: normalizeRedirectUri(parsed.BGM_REDIRECT_URI) as string
        })
      : undefined;
  const tmdb =
    parsed.TMDB_READ_ACCESS_TOKEN !== undefined
      ? new TmdbConfig(parsed.TMDB_READ_ACCESS_TOKEN)
      : undefined;
  const dandanplay =
    parsed.DANDANPLAY_APP_ID !== undefined &&
    parsed.DANDANPLAY_APP_SECRET !== undefined
      ? new DandanplayConfig({
          appId: parsed.DANDANPLAY_APP_ID,
          appSecret: parsed.DANDANPLAY_APP_SECRET
        })
      : undefined;

  return new HubConfig({
    environment: parsed.NODE_ENV,
    hub: {
      host: parsed.HUB_HOST,
      port: parsed.HUB_PORT,
      baseUrl: parsed.HUB_BASE_URL
    },
    databaseUrl: parsed.DATABASE_URL,
    redisUrl: parsed.REDIS_URL,
    setupSecret: parsed.HUB_SETUP_SECRET,
    credentialEncryptionKey: Buffer.from(
      parsed.CREDENTIAL_ENCRYPTION_KEY,
      "base64"
    ),
    streamSigningKey: Buffer.from(parsed.STREAM_SIGNING_KEY, "base64"),
    bangumi,
    tmdb,
    dandanplay
  });
}
