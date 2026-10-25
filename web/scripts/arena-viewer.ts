import { existsSync } from "node:fs";
import { parseArgs } from "node:util";

import { serveArenaViewer } from "../src/arena-viewer/server.ts";

// Serves the arena viewer over the arena analysis database (docs/arena/database.md). With --regret it also shows the
// regret table of a derived database (docs/arena/analysis/regret.md); without, the viewer has no regret.
// Usage: bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>]

const { positionals, values } = parseArgs({ allowPositionals: true, options: { regret: { type: "string" } } });
const [dbPath, host = "127.0.0.1", port = "8790"] = positionals;
const regretPath = values.regret;

if (dbPath === undefined || !existsSync(dbPath) || (regretPath !== undefined && !existsSync(regretPath))) {
  console.error("usage: bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>]");
  process.exit(1);
}

const server = serveArenaViewer(dbPath, host, Number(port), regretPath);

console.log(`arena viewer: ${server.url.href} reading ${dbPath}${regretPath === undefined ? "" : ` and ${regretPath}`}`);
