import {
  loadConfig,
  type HubConfig
} from "../../src/config/config.js";

export const TEST_ENCRYPTION_KEY = Buffer.alloc(32, 0x11).toString("base64");
export const TEST_STREAM_KEY = Buffer.alloc(32, 0x22).toString("base64");
export const TEST_SETUP_SECRET = "test-setup-secret-0123456789abcdef";
export const TEST_DATABASE_PASSWORD = "doki-test-password";

export function baseEnv(
  overrides: Record<string, string | undefined> = {}
): Record<string, string | undefined> {
  return {
    NODE_ENV: "test",
    HUB_HOST: "127.0.0.1",
    HUB_PORT: "8080",
    HUB_BASE_URL: "http://127.0.0.1:8080",
    DATABASE_URL: `postgres://postgres:${TEST_DATABASE_PASSWORD}@127.0.0.1:55432/doki_hub_test`,
    REDIS_URL: "",
    HUB_SETUP_SECRET: TEST_SETUP_SECRET,
    CREDENTIAL_ENCRYPTION_KEY: TEST_ENCRYPTION_KEY,
    STREAM_SIGNING_KEY: TEST_STREAM_KEY,
    BGM_CLIENT_ID: "",
    BGM_CLIENT_SECRET: "",
    BGM_REDIRECT_URI: "",
    TMDB_READ_ACCESS_TOKEN: "",
    DANDANPLAY_APP_ID: "",
    DANDANPLAY_APP_SECRET: "",
    ...overrides
  };
}

export function testConfig(
  overrides: Record<string, string | undefined> = {}
): HubConfig {
  return loadConfig(baseEnv(overrides));
}

export const configuredProviderEnv: Record<string, string> = {
  BGM_CLIENT_ID: "doki-test-client",
  BGM_CLIENT_SECRET: "doki-test-client-secret",
  BGM_REDIRECT_URI: "https://hub.example.com/v1/auth/bgm/callback",
  TMDB_READ_ACCESS_TOKEN: "doki-test-tmdb-read-access-token-0123456789",
  DANDANPLAY_APP_ID: "doki-test-app",
  DANDANPLAY_APP_SECRET: "doki-test-app-secret"
};
