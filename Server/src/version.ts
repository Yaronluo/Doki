import { readFileSync } from "node:fs";

interface PackageMetadata {
  readonly version?: unknown;
}

let cachedVersion: string | undefined;

export function readHubVersion(): string {
  if (cachedVersion !== undefined) {
    return cachedVersion;
  }
  const raw = readFileSync(new URL("../package.json", import.meta.url), "utf8");
  const parsed = JSON.parse(raw) as PackageMetadata;
  if (typeof parsed.version !== "string" || parsed.version.length === 0) {
    throw new Error("Server/package.json has no version");
  }
  cachedVersion = parsed.version;
  return cachedVersion;
}
