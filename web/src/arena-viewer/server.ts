import crypto from "node:crypto";
import { join, normalize } from "node:path";

import { Schema } from "effect";

import { AGGREGATE_NAMES, aggregatesOf, encodeAggregates } from "./aggregates.ts";
import { CertainMistakes, SeatsResponse } from "./api.ts";
import type { Arena } from "./load.ts";
import { withPotShares } from "./page/data.ts";
import { PAGE_PATHS } from "../site/route.ts";

// The arena viewer's server: the built site (web/dist), and a read-only JSON API over the arena analysis database
// as load.ts reads it.

const encodeSeats = Schema.encodeSync(Schema.fromJsonString(SeatsResponse));

const encodeCertain = Schema.encodeSync(Schema.fromJsonString(CertainMistakes));

const JSON_TYPE = { "content-type": "application/json" };

/** A JSON body gzipped once, sent gzipped to a client that accepts it. */
const encodedBody = (body: string): ((request: Request) => Response) => {
  const gzipped = Bun.gzipSync(new TextEncoder().encode(body));

  return (request) =>
      /\bgzip\b/.test(request.headers.get("accept-encoding") ?? "")
        ? new Response(gzipped, { headers: { ...JSON_TYPE, "content-encoding": "gzip", vary: "accept-encoding" } })
        : new Response(body, { headers: { ...JSON_TYPE, vary: "accept-encoding" } });
};

const digest = (text: string) => new Bun.CryptoHasher("sha256").update(text).digest();

/**
 * With a password, the API asks for it through the browser's basic-auth prompt; the username is ignored.
 * The page shell itself holds no data.
 */
const guardedBy = (password: string | undefined) => (handler: (request: Request) => Response) => {
  if (password === undefined) { return handler; }

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

type GzipCache = Map<string, Uint8Array<ArrayBuffer>>;

/** A hashed script or stylesheet, gzipped once per server when asked for; the others are sent as they are. */
const assetResponse = async (gzippedAssets: GzipCache, pathname: string, path: string, request: Request): Promise<Response> => {
  const file = Bun.file(path);
  const headers = { "cache-control": "public, max-age=31536000, immutable" };

  if (!COMPRESSIBLE.test(pathname) || !/\bgzip\b/.test(request.headers.get("accept-encoding") ?? "")) { return new Response(file, { headers }); }

  const gzipped = gzippedAssets.get(pathname) ?? Bun.gzipSync(await file.bytes());

  gzippedAssets.set(pathname, gzipped);

  return new Response(gzipped, { headers: { ...headers, "content-type": file.type, "content-encoding": "gzip", vary: "accept-encoding" } });
};

/** The path a URL names, or null when its percent-escapes are malformed. */
const decodedPath = (pathname: string): string | null => {
  try {
    return decodeURIComponent(pathname);
  } catch {
    return null;
  }
};

const siteResponse = async (siteDir: string, gzippedAssets: GzipCache, request: Request): Promise<Response> => {
  const { pathname } = new URL(request.url);
  const decoded = decodedPath(pathname);

  if (decoded === null) { return new Response("bad request", { status: 400 }); }

  const path = join(siteDir, normalize(decoded));
  const file = Bun.file(path);

  if (pathname !== "/" && (await file.exists())) { return pathname.startsWith("/assets/") ? assetResponse(gzippedAssets, pathname, path, request) : new Response(file); }

  return new Response(Bun.file(join(siteDir, "index.html")), { status: PAGE_PATHS.includes(pathname) ? 200 : 404, headers: { "content-type": "text/html; charset=utf-8" } });
};

/** What the API guards: a password for every route. */
export interface ViewerAccess {
  readonly password: string | undefined;
}

export const serveArenaViewer = ({ seats, decisions, certain, consistency, luck }: Arena, siteDir: string, hostname: string, port: number, { password }: ViewerAccess) => {
  const guarded = guardedBy(password);
  const aggregateJson = encodeAggregates(aggregatesOf({ seats: withPotShares(seats), decisions, certain: certain.summary.rates, consistency, luck }));
  const aggregateRoutes = Object.fromEntries(AGGREGATE_NAMES.map((name) => [`/api/agg/${name}`, guarded(encodedBody(aggregateJson[name]))]));
  const gzippedAssets: GzipCache = new Map();

  console.log(`serving ${seats.length} seats`);

  return Bun.serve({
    hostname,
    port,
    // With routes, Bun otherwise shares the port with a viewer already on it and splits requests between the two.
    reusePort: false,
    development: false,
    fetch: async (request) => siteResponse(siteDir, gzippedAssets, request),
    routes: {
      "/api/*": () => new Response("not found", { status: 404 }),
      "/api/seats": guarded(encodedBody(encodeSeats(seats))),
      ...aggregateRoutes,
      "/api/certain-mistakes": guarded(encodedBody(encodeCertain(certain.summary))),
    },
  });
};
