import { describe, expect, it } from "vitest";
import {
  buildBootstrapCapabilities,
  ConfigValidationError,
  loadConfig,
  redactedSummary
} from "../src/config/config.js";
import {
  baseEnv,
  configuredProviderEnv,
  TEST_DATABASE_PASSWORD,
  TEST_ENCRYPTION_KEY,
  TEST_SETUP_SECRET,
  TEST_STREAM_KEY,
  testConfig
} from "./helpers/test-config.js";

function expectConfigError(
  env: Record<string, string | undefined>
): ConfigValidationError {
  try {
    loadConfig(env);
  } catch (error) {
    expect(error).toBeInstanceOf(ConfigValidationError);
    return error as ConfigValidationError;
  }
  throw new Error("expected loadConfig to reject");
}

describe("loadConfig", () => {
  it("accepts a minimal Hub configuration and reports providers as notConfigured", () => {
    const config = testConfig();
    expect(config.environment).toBe("test");
    expect(config.hub).toEqual({
      host: "127.0.0.1",
      port: 8080,
      baseUrl: "http://127.0.0.1:8080"
    });
    expect(config.databaseUrl).toContain("doki_hub_test");
    expect(config.redisUrl).toBeUndefined();
    expect(config.setupSecret).toBe(TEST_SETUP_SECRET);
    expect(config.credentialEncryptionKey).toHaveLength(32);
    expect(config.streamSigningKey).toHaveLength(32);
    expect(config.bangumi).toBeUndefined();
    expect(config.tmdb).toBeUndefined();
    expect(config.dandanplay).toBeUndefined();

    expect(buildBootstrapCapabilities(config)).toEqual({
      bangumi: { state: "notConfigured" },
      tmdb: { state: "notConfigured" },
      danmaku: { state: "notConfigured", provider: "dandanplay" }
    });
  });

  it("reports configured but unverified providers as unavailable, never ready", () => {
    const config = testConfig(configuredProviderEnv);
    expect(config.bangumi?.clientId).toBe("doki-test-client");
    expect(config.tmdb?.readAccessToken).toContain("doki-test");
    expect(config.dandanplay?.appId).toBe("doki-test-app");
    expect(buildBootstrapCapabilities(config)).toEqual({
      bangumi: { state: "unavailable" },
      tmdb: { state: "unavailable" },
      danmaku: { state: "unavailable", provider: "dandanplay" }
    });
  });

  it("rejects a partial Bangumi credential group", () => {
    const error = expectConfigError(
      baseEnv({
        BGM_CLIENT_ID: "doki-test-client"
      })
    );
    expect(error.issues.map((issue) => issue.path)).toEqual(
      expect.arrayContaining(["BGM_CLIENT_SECRET", "BGM_REDIRECT_URI"])
    );
    expect(JSON.stringify(error.issues)).not.toContain("doki-test-client");
  });

  it("rejects a partial dandanplay credential group", () => {
    const error = expectConfigError(
      baseEnv({
        DANDANPLAY_APP_ID: "doki-test-app"
      })
    );
    expect(error.issues.map((issue) => issue.path)).toEqual([
      "DANDANPLAY_APP_SECRET"
    ]);
  });

  it("treats explicitly empty provider values as notConfigured", () => {
    const config = testConfig({
      BGM_CLIENT_ID: "",
      BGM_CLIENT_SECRET: "",
      BGM_REDIRECT_URI: "",
      TMDB_READ_ACCESS_TOKEN: "",
      DANDANPLAY_APP_ID: "",
      DANDANPLAY_APP_SECRET: ""
    });
    expect(buildBootstrapCapabilities(config).bangumi.state).toBe(
      "notConfigured"
    );
    expect(buildBootstrapCapabilities(config).danmaku.state).toBe(
      "notConfigured"
    );
  });

  it("rejects an encryption key that is not exactly 32 base64 bytes", () => {
    const error = expectConfigError(
      baseEnv({
        CREDENTIAL_ENCRYPTION_KEY: Buffer.alloc(16, 7).toString("base64")
      })
    );
    expect(error.issues).toEqual([
      {
        path: "CREDENTIAL_ENCRYPTION_KEY",
        message: "must be a base64-encoded 32-byte key"
      }
    ]);
  });

  it("rejects an invalid Hub base URL and port", () => {
    const baseUrlError = expectConfigError(
      baseEnv({ HUB_BASE_URL: "ftp://hub.example.com" })
    );
    expect(baseUrlError.issues[0]?.path).toBe("HUB_BASE_URL");
    const portError = expectConfigError(baseEnv({ HUB_PORT: "70000" }));
    expect(portError.issues[0]?.path).toBe("HUB_PORT");
  });

  it("rejects a non-loopback plaintext HTTP redirect URI", () => {
    const error = expectConfigError(
      baseEnv({
        ...configuredProviderEnv,
        BGM_REDIRECT_URI: "http://hub.example.com/v1/auth/bgm/callback"
      })
    );
    expect(error.issues[0]?.path).toBe("BGM_REDIRECT_URI");
  });

  it("rejects a too-short setup secret and a short provider secret", () => {
    const setupError = expectConfigError(
      baseEnv({ HUB_SETUP_SECRET: "too-short" })
    );
    expect(setupError.issues[0]?.path).toBe("HUB_SETUP_SECRET");
    const secretError = expectConfigError(
      baseEnv({
        ...configuredProviderEnv,
        BGM_CLIENT_SECRET: "short"
      })
    );
    expect(secretError.issues[0]?.path).toBe("BGM_CLIENT_SECRET");
  });

  it("redacts secrets from JSON serialization and the redacted summary", () => {
    const config = testConfig(configuredProviderEnv);
    const serialized = JSON.stringify(config);
    expect(serialized).not.toContain(TEST_DATABASE_PASSWORD);
    expect(serialized).not.toContain(TEST_SETUP_SECRET);
    expect(serialized).not.toContain(TEST_ENCRYPTION_KEY);
    expect(serialized).not.toContain(TEST_STREAM_KEY);
    expect(serialized).not.toContain("doki-test-client-secret");
    expect(serialized).not.toContain("doki-test-tmdb-read-access-token");
    expect(serialized).not.toContain("doki-test-app-secret");
    expect(serialized).not.toContain("doki_hub_test");

    const summary = redactedSummary(config);
    expect(JSON.stringify(summary)).not.toContain(TEST_DATABASE_PASSWORD);
    expect(summary.database).toEqual({ configured: true });
    expect(summary.providers).toEqual({
      bangumi: "configured",
      tmdb: "configured",
      dandanplay: "configured"
    });
    expect(summary.capabilities.bangumi.state).toBe("unavailable");
    expect(JSON.stringify(config.bangumi)).not.toContain(
      "doki-test-client-secret"
    );
    expect(JSON.stringify(config.tmdb)).not.toContain("doki-test-tmdb");
    expect(JSON.stringify(config.dandanplay)).not.toContain(
      "doki-test-app-secret"
    );
  });
});
