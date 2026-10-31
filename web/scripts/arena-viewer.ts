import { existsSync } from "node:fs";
import { parseArgs } from "node:util";

import { serveArenaViewer } from "../src/arena-viewer/server.ts";

// Serves the arena viewer over the arena analysis database (docs/arena/database.md). With --regret it also shows the
// regret table of a derived database (docs/arena/analysis/regret.md); without, the viewer has no regret. With --knowledge
// it also shows how consistent each config is in repeated positions (the knowledge database of scripts/arena-knowledge.ts).
// Usage: bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>] [--knowledge <knowledge db>] [--certain-mistakes <opportunities db>]

const USAGE = "usage: bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>] [--knowledge <knowledge db>] [--certain-mistakes <opportunities db>]";

const { positionals, values } = parseArgs({ allowPositionals: true, options: { regret: { type: "string" }, knowledge: { type: "string" }, "certain-mistakes": { type: "string" } } });
const [dbPath, host = "127.0.0.1", port = "8790"] = positionals;
const regretPath = values.regret;
const knowledgePath = values.knowledge;
const certainPath = values["certain-mistakes"];

const isMissing = (path: string | undefined) => path !== undefined && !existsSync(path);

if (dbPath === undefined || isMissing(dbPath) || isMissing(regretPath) || isMissing(knowledgePath) || isMissing(certainPath)) {
  console.error(USAGE);
  process.exit(1);
}

const server = serveArenaViewer(dbPath, host, Number(port), regretPath, knowledgePath, certainPath);

console.log(
  `arena viewer: ${server.url.href} reading ${[dbPath, regretPath, knowledgePath, certainPath].filter((path) => path !== undefined).join(" and ")}`,
);
