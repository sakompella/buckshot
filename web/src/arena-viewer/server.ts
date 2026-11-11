import crypto from "node:crypto";
import { join, normalize } from "node:path";

import { Schema } from "effect";

import { AGGREGATE_NAMES, aggregatesOf, encodeAggregates } from "./aggregates.ts";
import { Blunders, CertainMistakes, Decisions, SeatsResponse } from "./api.ts";
import { findBlunders } from "./blunders.ts";
import { type Arena } from "./load.ts";
import { withPotShares } from "./page/data.ts";

// The arena viewer's server: the built site (web/dist), and a read-only JSON API over the arena analysis database
// as load.ts reads it.

const encodeSeats = Schema.encodeSync(Schema.fromJsonString(SeatsResponse));

const encodeDecisions = Schema.encodeSync(Schema.fromJsonString(Decisions));

const encodeBlunders = Schema.encodeSync(Schema.fromJsonString(Blunders));

const encodeCertain = Schema.encodeSync(Schema.fromJsonString(CertainMistakes));

const JSON_TYPE = { "content-type": "application/json" };

const encodedBody = (body: string) => ({ body, gzipped: Bun.gzipSync(new TextEncoder().encode(body)) });

const json = (request: Request, { body, gzipped }: ReturnType<typeof encodedBody>) =>
  /\bgzip\b/.test(request.headers.get("accept-encoding") ?? "")
    ? new Response(gzipped, { headers: { ...JSON_TYPE, "content-encoding": "gzip", vary: "accept-encoding" } })
    : new Response(body, { headers: { ...JSON_TYPE, vary: "accept-encoding" } });

const digest = (text: string) => new Bun.CryptoHasher("sha256").update(text).digest();

/**
 * With a password, the API asks for it through the browser's basic-auth prompt; the username is ignored.
 * The page shell itself holds no data.
 */
const guardedBy = (password: string | undefined) => (handler: (request: Request) => Response) => {
  if (password === undefined) return handler;

  const expected = digest(password);

  return (request: Request) => {
    const given = Buffer.from((request.headers.get("authorization") ?? "").replace(/^Basic /, ""), "base64").toString().replace(/^[^:]*:/, "");

    return crypto.timingSafeEqual(digest(given), expected)
      ? handler(request)
      : new Response("password required", { status: 401, headers: { "www-authenticate": 'Basic realm="Buckshot arena"' } });
  };
};

/** A file of the built site when the path names one; any other path gets the page, which routes itself. */
const COMPRESSIBLE = /\.(js|css|svg)$/;

const gzippedAssets = new Map<string, Uint8Array<ArrayBuffer>>();

/** A hashed script or stylesheet, gzipped once when asked for; the others are sent as they are. */
const assetResponse = async (pathname: string, file: ReturnType<typeof Bun.file>, request: Request): Promise<Response> => {
  const headers = { "cache-control": "public, max-age=31536000, immutable" };

  if (!COMPRESSIBLE.test(pathname) || !/\bgzip\b/.test(request.headers.get("accept-encoding") ?? "")) return new Response(file, { headers });

  const gzipped = gzippedAssets.get(pathname) ?? Bun.gzipSync(await file.bytes());

  gzippedAssets.set(pathname, gzipped);

  return new Response(gzipped, { headers: { ...headers, "content-type": file.type, "content-encoding": "gzip", vary: "accept-encoding" } });
};

const siteResponse = async (siteDir: string, request: Request): Promise<Response> => {
  const { pathname } = new URL(request.url);
  const file = Bun.file(join(siteDir, normalize(decodeURIComponent(pathname))));

  if (pathname !== "/" && (await file.exists())) return pathname.startsWith("/assets/") ? assetResponse(pathname, file, request) : new Response(file);

  return new Response(Bun.file(join(siteDir, "index.html")), { headers: { "content-type": "text/html; charset=utf-8" } });
};

/** What the API guards: a password for every route. */
export interface ViewerAccess {
  readonly password: string | undefined;
}

export const serveArenaViewer = ({ db, regret, seats, seatIndex, decisions, certain, consistency, luck }: Arena, siteDir: string, hostname: string, port: number, { password }: ViewerAccess) => {
  const guarded = guardedBy(password);
  const aggregateJson = encodeAggregates(aggregatesOf({ seats: withPotShares(seats), decisions, certain: certain.summary.rates, consistency, luck }));
  const aggregateRoutes = Object.fromEntries(AGGREGATE_NAMES.map((name) => [`/api/agg/${name}`, guarded((request) => json(request, encodedBody(aggregateJson[name])))]));

  const seatsBody = encodedBody(encodeSeats(seats));
  const decisionsBody = encodedBody(encodeDecisions(decisions));
  const blundersBody = encodedBody(encodeBlunders(findBlunders(db, regret, seatIndex)));
  const certainBody = encodedBody(encodeCertain(certain.summary));

  console.log(`serving ${seats.length} seats; decisions payload ${(decisionsBody.gzipped.length / 1e6).toFixed(1)} MB gzipped`);

  return Bun.serve({
    hostname,
    port,
    // With routes, Bun otherwise shares the port with a viewer already on it and splits requests between the two.
    reusePort: false,
    development: false,
    fetch: (request) => siteResponse(siteDir, request),
    routes: {
      "/api/*": () => new Response("not found", { status: 404 }),
      "/api/seats": guarded((request) => json(request, seatsBody)),
      "/api/decisions": guarded((request) => json(request, decisionsBody)),
      "/api/blunders": guarded((request) => json(request, blundersBody)),
      ...aggregateRoutes,
      "/api/certain-mistakes": guarded((request) => json(request, certainBody)),
    },
  });
};
