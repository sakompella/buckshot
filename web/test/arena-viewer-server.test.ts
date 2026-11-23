import { afterAll, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { NO_CERTAIN } from "../src/arena-viewer/certain.ts";
import { serveArenaViewer } from "../src/arena-viewer/server.ts";

const site = mkdtempSync(join(tmpdir(), "viewer-site-"));

writeFileSync(join(site, "index.html"), "<!doctype html>");

const decisions = { seat: [], ord: [], opp: [], pick: [], rt: [], out: [], gap: [], cost: [], lat: [], tok: [], legalUse: [], legalSteal: [], useItem: [], stealItem: [], shot: [], odds: [] };

const server = serveArenaViewer({ seats: [], decisions, certain: NO_CERTAIN, consistency: [], luck: new Map() }, site, "127.0.0.1", 0, { password: undefined });

afterAll(async () => { await server.stop(); });

const statusOf = async (path: string) => (await Bun.fetch(new URL(path, server.url))).status;

test("the viewer answers a malformed path with 400, an unknown API route with 404, and an aggregate with JSON", async () => {
  expect(await statusOf("/%ZZ")).toBe(400);
  expect(await statusOf("/api/decisions")).toBe(404);
  expect(await statusOf("/api/agg/summary")).toBe(200);
});
