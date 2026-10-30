import { cp } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const migrationsSource = fileURLToPath(new URL("../src/db/migrations", import.meta.url));
const migrationsTarget = fileURLToPath(new URL("../dist/db/migrations", import.meta.url));

await cp(migrationsSource, migrationsTarget, { recursive: true });
console.log(`copied migrations to ${migrationsTarget}`);
