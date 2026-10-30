import { pairingRequestSchema, pairingResponseSchema, pairingStatusSchema, pairingClaimSchema, accountStatusSchema, accountCollectionSchema, webLoginSchema } from "./auth.js";
import { creditsSchema, calendarSchema, catalogSubjectSchema, catalogPageSchema, episodePageSchema, catalogSearchSchema, artworkResponseSchema } from "./catalog.js";
import { z } from "zod";
import { bootstrapResponseSchema } from "../contracts/bootstrap.js";
import {
  danmakuItemSchema,
  danmakuLoadSchema,
  danmakuMappingSchema,
  danmakuPreferencesSchema,
  danmakuSearchCandidateSchema,
  danmakuTimingSchema
} from "../contracts/danmaku.js";
import { errorResponseSchema } from "../contracts/errors.js";
import {
  healthResponseSchema,
  readyResponseSchema
} from "../contracts/health.js";
import {
  playbackCapabilitiesSchema,
  playbackPlanSchema,
  playbackSourceSchema,
  playbackTracksSchema
} from "../contracts/playback.js";
import {
  progressEventResultSchema,
  progressEventSchema
} from "../contracts/progress.js";
import {
  sourcePreviewPlanSchema,
  sourcePreviewRequestSchema
} from "../contracts/source-preview.js";

type JsonSchema = Record<string, unknown>;
type OpenApiDocument = Record<string, unknown>;

function toJsonSchema(schema: z.ZodType): JsonSchema {
  const generated = z.toJSONSchema(schema, {
    target: "draft-2020-12",
    io: "output",
    unrepresentable: "any"
  }) as JsonSchema;
  delete generated.$schema;
  return generated;
}

function ref(name: string): JsonSchema {
  return { $ref: `#/components/schemas/${name}` };
}

function jsonResponse(schema: JsonSchema, description: string) {
  return {
    description,
    content: {
      "application/json": {
        schema
      }
    }
  };
}

function sortKeysDeep(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => sortKeysDeep(item));
  }
  if (value !== null && typeof value === "object") {
    const source = value as Record<string, unknown>;
    const sorted: Record<string, unknown> = {};
    for (const key of Object.keys(source).sort()) {
      sorted[key] = sortKeysDeep(source[key]);
    }
    return sorted;
  }
  return value;
}

export function buildOpenApiDocument(
  options: { readonly hubVersion: string } = { hubVersion: "0.0.0" }
): OpenApiDocument {
  const components = {
    securitySchemes: { DeviceToken: {type:"http",scheme:"bearer"}, PairingSecret: {type:"apiKey",in:"header",name:"Authorization",description:"Pairing <secret>; code alone grants no access"} },
    schemas: {
      PairingRequest: toJsonSchema(pairingRequestSchema),
      PairingResponse: toJsonSchema(pairingResponseSchema),
      PairingStatus: toJsonSchema(pairingStatusSchema),
      PairingClaim: toJsonSchema(pairingClaimSchema),
      AccountStatus: toJsonSchema(accountStatusSchema),
      AccountCollections: toJsonSchema(accountCollectionSchema),
      WebLogin: toJsonSchema(webLoginSchema),
      Credits: toJsonSchema(creditsSchema),
      CatalogSubject: toJsonSchema(catalogSubjectSchema),
      CatalogPage: toJsonSchema(catalogPageSchema),
      Calendar: toJsonSchema(calendarSchema),
      EpisodePage: toJsonSchema(episodePageSchema),
      CatalogSearch: toJsonSchema(catalogSearchSchema),
      ArtworkResponse: toJsonSchema(artworkResponseSchema),
      CatalogHome: toJsonSchema(z.object({ calendar: calendarSchema, picks: catalogPageSchema, updatedAt: z.string() })),
      HealthResponse: toJsonSchema(healthResponseSchema),
      ReadyResponse: toJsonSchema(readyResponseSchema),
      BootstrapResponse: toJsonSchema(bootstrapResponseSchema),
      ErrorResponse: toJsonSchema(errorResponseSchema),
      PlaybackPlan: toJsonSchema(playbackPlanSchema),
      PlaybackSource: toJsonSchema(playbackSourceSchema),
      PlaybackTracks: toJsonSchema(playbackTracksSchema),
      PlaybackCapabilities: toJsonSchema(playbackCapabilitiesSchema),
      ProgressEvent: toJsonSchema(progressEventSchema),
      ProgressEventResult: toJsonSchema(progressEventResultSchema),
      SourcePreviewRequest: toJsonSchema(sourcePreviewRequestSchema),
      SourcePreviewPlan: toJsonSchema(sourcePreviewPlanSchema),
      DanmakuItem: toJsonSchema(danmakuItemSchema),
      DanmakuLoad: toJsonSchema(danmakuLoadSchema),
      DanmakuMapping: toJsonSchema(danmakuMappingSchema),
      DanmakuSearchCandidate: toJsonSchema(danmakuSearchCandidateSchema),
      DanmakuTiming: toJsonSchema(danmakuTimingSchema),
      DanmakuPreferences: toJsonSchema(danmakuPreferencesSchema),
      Int64Id: {
        type: "string",
        pattern: "^[1-9][0-9]{0,18}$",
        description:
          "Canonical positive decimal string for a signed 64-bit ID. JavaScript numbers are not accepted."
      }
    }
  };

  const document: OpenApiDocument = {
    openapi: "3.1.0",
    info: {
      title: "Doki Hub API",
      version: options.hubVersion,
      description:
        "System and anonymous Bangumi catalog, optional TMDB artwork, development-only source preview and signed media relay. " +
        "Bangumi-bound playback, progress and danmaku routes are not implemented; their schemas are " +
        "published for client and adapter development only. The development preview route is not " +
        "registered when NODE_ENV=production."
    },
    servers: [{ url: "/" }],
    tags: [
      { name: "system", description: "Liveness, readiness and discovery" },
      {
        name: "development",
        description:
          "Local real-source verification and signed relay. Preview is not registered in production."
      },
      {
        name: "contracts",
        description: "Schemas only; no Bangumi-bound route is live in HUB-001"
      }
    ],
    paths: {
      ...catalogPaths(),
      ...authPaths(),
      "/health": {
        get: {
          operationId: "getHealth",
          summary: "Liveness probe",
          description:
            "Returns 200 while the HTTP process is running. It does not check Postgres.",
          tags: ["system"],
          responses: {
            "200": jsonResponse(ref("HealthResponse"), "Process is alive")
          }
        }
      },
      "/ready": {
        get: {
          operationId: "getReadiness",
          summary: "Readiness probe",
          description:
            "Checks configuration, Postgres connectivity and applied migrations. " +
            "Returns a structured 503 when a dependency is unavailable or migrations are pending.",
          tags: ["system"],
          responses: {
            "200": jsonResponse(ref("ReadyResponse"), "Hub is ready"),
            "503": jsonResponse(
              ref("ErrorResponse"),
              "Hub is not ready; details.checks explains each dependency"
            )
          }
        }
      },
      "/v1/bootstrap": {
        get: {
          operationId: "getBootstrap",
          summary: "API version and provider capabilities",
          description:
            "Capabilities are notConfigured when credentials are absent and unavailable " +
            "when credentials exist but have not been verified. HUB-001 never reports ready.",
          tags: ["system"],
          responses: {
            "200": jsonResponse(ref("BootstrapResponse"), "Bootstrap information")
          }
        }
      },
      "/v1/openapi.json": {
        get: {
          operationId: "getOpenApiDocument",
          summary: "This OpenAPI document",
          tags: ["system"],
          responses: {
            "200": jsonResponse(
              { type: "object", additionalProperties: true },
              "OpenAPI 3.1 document"
            )
          }
        }
      },
      "/v1/dev/source-preview": {
        post: {
          operationId: "createSourcePreview",
          summary: "Resolve one real source for local technical verification",
          description:
            "Development-only. Searches the fixed yinghua provider, reads its episode page, " +
            "validates the HLS master and returns a short-lived signed relay URL. This is not a " +
            "Bangumi-bound PlaybackSession and must not be used for production delivery.",
          tags: ["development"],
          requestBody: {
            required: true,
            content: {
              "application/json": {
                schema: ref("SourcePreviewRequest")
              }
            }
          },
          responses: {
            "200": jsonResponse(ref("SourcePreviewPlan"), "Relay plan is ready"),
            "404": jsonResponse(ref("ErrorResponse"), "No matching subject or episode"),
            "422": jsonResponse(ref("ErrorResponse"), "Unsupported rule or media URL"),
            "502": jsonResponse(ref("ErrorResponse"), "Upstream or media validation failed")
          }
        }
      },
      "/s/{sessionId}/{resourceId}": {
        get: {
          operationId: "getSignedMediaResource",
          summary: "Signed HLS playlist or media segment",
          description:
            "Serves a rewritten HLS playlist or streams a media segment for an authorized relay " +
            "session. URLs are HMAC-signed with exp and method scope; Range/HEAD are supported. " +
            "The client never learns the upstream URL.",
          tags: ["development"],
          parameters: [
            {
              name: "sessionId",
              in: "path",
              required: true,
              schema: { type: "string" }
            },
            {
              name: "resourceId",
              in: "path",
              required: true,
              schema: { type: "string" }
            },
            {
              name: "exp",
              in: "query",
              required: true,
              schema: { type: "integer" }
            },
            {
              name: "sig",
              in: "query",
              required: true,
              schema: { type: "string" }
            }
          ],
          responses: {
            "200": {
              description: "Playlist or media bytes",
              content: {
                "application/vnd.apple.mpegurl": { schema: { type: "string" } },
                "video/mp2t": { schema: { type: "string", format: "binary" } }
              }
            },
            "206": {
              description: "Media byte range",
              content: {
                "video/mp2t": { schema: { type: "string", format: "binary" } }
              }
            },
            "403": jsonResponse(ref("ErrorResponse"), "Invalid or expired signature"),
            "404": jsonResponse(ref("ErrorResponse"), "Unknown session/resource"),
            "502": jsonResponse(ref("ErrorResponse"), "Upstream media failure")
          }
        }
      }
    },
    components
  };

  return sortKeysDeep(document) as OpenApiDocument;
}

export function serializeOpenApiDocument(document: OpenApiDocument): string {
  return `${JSON.stringify(sortKeysDeep(document), null, 2)}\n`;
}

function catalogPaths(): Record<string, unknown> {
  const paths: Record<string, unknown> = {};
  for (const [path, schema, operationId] of [
    ["/v1/home", "CatalogHome", "getCatalogHome"],
    ["/v1/popular", "CatalogPage", "getPopularAnime"],
    ["/v1/calendar", "Calendar", "getCatalogCalendar"],
    ["/v1/subjects/{id}", "CatalogSubject", "getCatalogSubject"],
    ["/v1/subjects/{id}/episodes", "EpisodePage", "getCatalogEpisodes"],
    ["/v1/subjects/{id}/characters", "Credits", "getCatalogCharacters"],
    ["/v1/subjects/{id}/persons", "Credits", "getCatalogStaff"],
    ["/v1/subjects/{id}/artwork", "ArtworkResponse", "getCatalogArtwork"]
  ] as const) {
    paths[path] = { get: { operationId, summary: "Public catalog read; no account state or playback availability", parameters: [
      ...(path.includes("{id}") ? [{ name: "id", in: "path", required: true, schema: { type: "integer", minimum: 1 } }] : []),
      ...(schema === "EpisodePage" ? [{ name: "offset", in: "query", schema: { type: "integer", minimum: 0, default: 0 } }] : [])
    ], responses: { "200": jsonResponse(ref(schema), "Catalog data"), "502": jsonResponse(ref("ErrorResponse"), "Upstream unavailable") } } };
  }
  paths["/v1/search"] = { post: { operationId: "searchCatalog", summary: "Anonymous Bangumi anime search", requestBody: { required: true, content: { "application/json": { schema: ref("CatalogSearch") } } }, responses: { "200": jsonResponse(ref("CatalogPage"), "Search results") } } };
  paths["/v1/artwork/tmdb/{filename}"] = { get: { operationId: "getTmdbBackdrop", summary: "Bounded TMDB backdrop proxy; fixed image origin, no credentials", parameters: [{ name: "filename", in: "path", required: true, schema: { type: "string", pattern: "^[A-Za-z0-9]+\\.(jpg|png|webp)$" } }], responses: { "200": { description: "Backdrop", content: { "image/jpeg": { schema: { type: "string", format: "binary" } } } } } } };
  return paths;
}

function authPaths(): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for(const[path,method,response]of[
    ["/v1/devices/pairings","post","PairingResponse"],
    ["/v1/devices/pairings/{id}","get","PairingStatus"],
    ["/v1/devices/pairings/{id}/claim","post","PairingClaim"],
    ["/v1/account","get","AccountStatus"],
    ["/v1/account/collections","get","AccountCollections"]
  ]) {
    result[path!] = {[method!]:{ summary: "TV pairing and credential-free Bangumi website login via Hub browser", parameters: [
      ...(path!.includes("{id}") ? [{ name:"id",in:"path",required:true,schema:{type:"string",format:"uuid"}}]:[]),
      ...(path!.endsWith("collections") ? [{name:"offset",in:"query",schema:{type:"integer",minimum:0,default:0}}]:[])],
      ...(path==="/v1/devices/pairings"?{requestBody:{content:{"application/json":{schema:ref("PairingRequest")}}}}:{security:[{[path!.includes("pairings")?"PairingSecret":"DeviceToken"]:[]}]}),
      responses:{"200":jsonResponse(ref(response!),"Result"),"401":jsonResponse(ref("ErrorResponse"),"Authentication required"),"409":jsonResponse(ref("ErrorResponse"),"Expired or consumed pairing")}}};
  }
  return result;
}
