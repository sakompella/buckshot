import { existsSync } from "node:fs";
import { parseArgs } from "node:util";

import { serveArenaViewer } from "../src/arena-viewer/server.ts";

// Serves the arena viewer over the arena analysis database (docs/arena/database.md). With --regret it also shows the
// regret table of a derived database (docs/arena/analysis/regret.md); without, the viewer has no regret. With --knowledge
// it also shows how consistent each config is in repeated positions (the knowledge database of scripts/arena-knowledge.ts).
// Usage: bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>] [--knowledge <knowledge db>]

const { positionals, values } = parseArgs({ allowPositionals: true, options: { regret: { type: "string" }, knowledge: { type: "string" } } });
const [dbPath, host = "127.0.0.1", port = "8790"] = positionals;
const regretPath = values.regret;
const knowledgePath = values.knowledge;

if (dbPath === undefined || !existsSync(dbPath) || (regretPath !== undefined && !existsSync(regretPath)) || (knowledgePath !== undefined && !existsSync(knowledgePath))) {
  console.error("usage: bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>] [--knowledge <knowledge db>]");
  process.exit(1);
}

const server = serveArenaViewer(dbPath, host, Number(port), regretPath, knowledgePath);

console.log(`arena viewer: ${server.url.href} reading ${dbPath}${regretPath === undefined ? "" : ` and ${regretPath}`}${knowledgePath === undefined ? "" : ` and ${knowledgePath}`}`);
