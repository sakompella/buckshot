import { existsSync } from "node:fs";

import { serveArenaViewer } from "../src/arena-viewer/server.ts";

// Serves the arena viewer over the arena analysis database (docs/arena/database.md).
// Usage: bun scripts/arena-viewer.ts <db> [host] [port]

const [dbPath, host = "127.0.0.1", port = "8790"] = process.argv.slice(2);

if (dbPath === undefined || !existsSync(dbPath)) {
  console.error("usage: bun scripts/arena-viewer.ts <db> [host] [port]");
  process.exit(1);
}

const server = serveArenaViewer(dbPath, host, Number(port));

console.log(`arena viewer: ${server.url.href} reading ${dbPath}`);
