import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  buildOpenApiDocument,
  serializeOpenApiDocument
} from "../src/contracts/openapi.js";
import { readHubVersion } from "../src/version.js";

const hubVersion = readHubVersion();

describe("OpenAPI generation", () => {
  it("is deterministic and only advertises implemented paths", () => {
    const first = buildOpenApiDocument({ hubVersion });
    const second = buildOpenApiDocument({ hubVersion });
    expect(second).toEqual(first);
    expect(serializeOpenApiDocument(second)).toBe(
      serializeOpenApiDocument(first)
    );

    const paths = first.paths as Record<string, unknown>;
    expect(Object.keys(paths).sort()).toEqual([
      "/health",
      "/ready",
      "/s/{sessionId}/{resourceId}",
      "/v1/account",
      "/v1/account/collections",
      "/v1/artwork/tmdb/{filename}",
      "/v1/bootstrap",
      "/v1/calendar",
      "/v1/dev/source-preview",
      "/v1/devices/pairings",
      "/v1/devices/pairings/{id}",
      "/v1/devices/pairings/{id}/claim",
      "/v1/home",
      "/v1/openapi.json",
      "/v1/search",
      "/v1/subjects/{id}",
      "/v1/subjects/{id}/artwork",
      "/v1/subjects/{id}/characters",
      "/v1/subjects/{id}/episodes",
      "/v1/subjects/{id}/persons"
    ]);
    expect(Object.keys(paths)).toEqual([...Object.keys(paths)].sort());
    expect(JSON.stringify(first)).not.toContain("/v1/playback/sessions");
    expect(JSON.stringify(first)).not.toContain("/v1/progress/events");
    expect(JSON.stringify(first)).not.toContain("/v1/episodes/{id}/danmaku");
  });

  it("publishes contract components for SRC, PLAY, SYNC and DAN work", () => {
    const document = buildOpenApiDocument({ hubVersion });
    const schemas = (
      document.components as { schemas: Record<string, unknown> }
    ).schemas;
    expect(Object.keys(schemas)).toEqual(
      expect.arrayContaining([
        "BootstrapResponse",
        "ErrorResponse",
        "PlaybackPlan",
        "ProgressEvent",
        "SourcePreviewRequest",
        "SourcePreviewPlan",
        "DanmakuItem",
        "DanmakuLoad",
        "DanmakuMapping",
        "Int64Id"
      ])
    );
    const progress = schemas.ProgressEvent as {
      properties: Record<string, unknown>;
    };
    expect(Object.keys(progress.properties)).toEqual(
      expect.arrayContaining([
        "eventId",
        "sessionId",
        "deviceSeq",
        "writeEpoch",
        "baseRevision",
        "kind",
        "positionSeconds"
      ])
    );
    const danmakuId = (schemas.DanmakuItem as {
      properties: Record<string, { type?: string; pattern?: string }>;
    }).properties.id;
    expect(danmakuId?.type).toBe("string");
    expect(danmakuId?.pattern).toContain("[1-9]");
  });

  it("matches the checked-in Server/openapi.json", () => {
    const checkedIn = readFileSync(
      new URL("../openapi.json", import.meta.url),
      "utf8"
    );
    expect(checkedIn).toBe(
      serializeOpenApiDocument(buildOpenApiDocument({ hubVersion }))
    );
  });
});
