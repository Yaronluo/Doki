import pino, { type DestinationStream, type Logger } from "pino";
import type { HubConfig } from "../config/config.js";

export type { Logger };

export interface LoggerOptions {
  readonly level?: string;
  readonly service?: string;
  readonly destination?: DestinationStream;
  readonly redactValues?: readonly string[];
}

const URL_WITH_CREDENTIALS = /\b(?:postgres(?:ql)?|redis(?:s)?):\/\/[^\s"'<>]+/gi;
const BEARER_VALUE = /\bBearer\s+[A-Za-z0-9._~+/=-]+/gi;
const SECRET_QUERY_PARAM =
  /([?&](?:token|secret|key|sig|signature|code|password)=)[^&\s"'<>]+/gi;
const AUTH_HEADER =
  /\b(authorization|x-hub-setup-secret|proxy-authorization)\s*[:=]\s*[^\s,;"']+/gi;

export function createSecretRedactor(
  secretValues: readonly string[] = []
): (input: string) => string {
  const ordered = [...new Set(secretValues)]
    .filter((value) => value.length >= 8)
    .sort((a, b) => b.length - a.length);

  return (input: string): string => {
    let redacted = input;
    for (const secret of ordered) {
      redacted = redacted.split(secret).join("[redacted]");
    }
    return redacted
      .replace(URL_WITH_CREDENTIALS, "[redacted-url]")
      .replace(BEARER_VALUE, "Bearer [redacted]")
      .replace(SECRET_QUERY_PARAM, "$1[redacted]")
      .replace(AUTH_HEADER, "$1: [redacted]");
  };
}

export function stripQueryString(url: string): string {
  const index = url.indexOf("?");
  return index === -1 ? url : url.slice(0, index);
}

function serializeError(
  value: unknown,
  redact: (input: string) => string
): Record<string, unknown> {
  if (value instanceof Error) {
    const code = (value as NodeJS.ErrnoException).code;
    return {
      type: value.name,
      message: redact(value.message),
      stack: redact(value.stack ?? ""),
      ...(code === undefined ? {} : { code })
    };
  }
  return { type: typeof value, message: redact(String(value)) };
}

export function createLogger(options: LoggerOptions = {}): Logger {
  const redact = createSecretRedactor(options.redactValues);
  return pino(
    {
      level: options.level ?? "info",
      base: { service: options.service ?? "doki-hub" },
      timestamp: pino.stdTimeFunctions.isoTime,
      redact: {
        paths: [
          "*.clientSecret",
          "*.appSecret",
          "*.readAccessToken",
          "*.accessToken",
          "*.refreshToken",
          "*.setupSecret",
          "*.credentialEncryptionKey",
          "*.streamSigningKey",
          "*.databaseUrl",
          "*.redisUrl",
          "*.password",
          "req.headers.authorization",
          "req.headers.cookie",
          "res.headers['set-cookie']"
        ],
        censor: "[redacted]"
      },
      serializers: {
        req(request: {
          method?: string;
          url?: string;
          ip?: string;
          host?: string;
        }) {
          return {
            method: request.method,
            url:
              request.url === undefined
                ? undefined
                : stripQueryString(request.url),
            host: request.host,
            remoteAddress: request.ip
          };
        },
        res(reply: { statusCode?: number }) {
          return { statusCode: reply.statusCode };
        },
        err(error: unknown) {
          return serializeError(error, redact);
        }
      }
    },
    options.destination
  );
}

export function loggerForConfig(
  config: HubConfig,
  options: Omit<LoggerOptions, "redactValues"> = {}
): Logger {
  return createLogger({
    ...options,
    redactValues: config.secretValuesForLogRedaction()
  });
}
