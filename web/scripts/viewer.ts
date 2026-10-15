import { existsSync } from "node:fs";

import { serveViewer } from "../src/viewer/server.ts";

// Serves the arena viewer, a read-only local site over a directory of arena
// runs, on 127.0.0.1. Port 0 picks a free port.
// Usage: bun scripts/viewer.ts [--dir <runs dir>] [--port 4173]

const flag = (name: string, fallback: string): string => {
  const at = process.argv.indexOf(`--${name}`);

  return at === -1 ? fallback : (process.argv[at + 1] ?? fallback);
};

const dir = flag("dir", new URL("../../_work/arena", import.meta.url).pathname);

if (!existsSync(dir)) {
  console.error(`viewer: no runs directory at ${dir}; pass --dir`);
  process.exit(1);
}

const server = serveViewer(dir, Number(flag("port", "4173")));

console.log(`viewer: ${server.url.href} reading ${dir}`);
