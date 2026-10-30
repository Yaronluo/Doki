import { createHash } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import {
  buildOpenApiDocument,
  serializeOpenApiDocument
} from "../src/contracts/openapi.js";
import { readHubVersion } from "../src/version.js";

const hubVersion = readHubVersion();
const document = buildOpenApiDocument({ hubVersion });
const serialized = serializeOpenApiDocument(document);
const target = fileURLToPath(new URL("../openapi.json", import.meta.url));
await writeFile(target, serialized, "utf8");
const digest = createHash("sha256").update(serialized).digest("hex");
console.log(
  JSON.stringify({
    event: "openapi_generated",
    path: target,
    bytes: Buffer.byteLength(serialized),
    sha256: digest,
    hubVersion
  })
);
