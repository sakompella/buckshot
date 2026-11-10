import { Option, pipe, Predicate, Schema, SchemaTransformation } from "effect";
import { Route, type Url } from "foldkit";

import type { Filter } from "../arena-viewer/page/model.ts";
import { isOnline } from "./online.ts";

// The site's pages and their URLs. The arena's shareable state lives in the query: the models and efforts switched
// off, the open leaderboard row, and for a replay the move it shows.

/** A match id: the hex digest the arena names a match by. */
const MatchId = Schema.String.check(Schema.isPattern(/^[0-9a-f]+$/));

const Ordinal = Schema.String.pipe(Schema.decodeTo(Schema.Int, SchemaTransformation.numberFromString));

const ArenaQuery = Schema.Struct({ offModels: Schema.optional(Schema.String), offEfforts: Schema.optional(Schema.String), row: Schema.optional(Schema.String) });

const ReplayQuery = Schema.Struct({ at: Schema.optional(Ordinal) });

export const SiteRoute = Route.defineRouteUnion({
  Arena: ArenaQuery.fields,
  Replay: { id: MatchId, ...ReplayQuery.fields },
  NotFound: { path: Schema.String },
});

export type SiteRoute = typeof SiteRoute.Type;

export type ArenaRoute = Extract<SiteRoute, { readonly _tag: "Arena" | "Replay" }>;

const arenaRouter = pipe(Route.literal("arena"), Route.query(ArenaQuery), Route.mapTo(SiteRoute.Arena));

const replayRouter = pipe(Route.literal("replay"), Route.slash(Route.schemaSegment("id", MatchId)), Route.query(ReplayQuery), Route.mapTo(SiteRoute.Replay));

/** The online build has no replays: a replay's URL there is an unknown page. */
const parseRoute = Route.parseUrlWithFallback(isOnline ? arenaRouter : Route.oneOf(replayRouter, arenaRouter), SiteRoute.NotFound);

/** The site's root shows the arena; an old link such as `/#scatter` keeps its section. */
export const isRootUrl = (url: Url.Url): boolean => url.pathname === "/";

export const routeOf = (url: Url.Url): SiteRoute => (isRootUrl(url) ? SiteRoute.Arena({}) : parseRoute(url));

export const isArenaRoute = (route: SiteRoute): route is ArenaRoute => Predicate.isTagged(route, "Arena") || Predicate.isTagged(route, "Replay");

const listOf = (value: string | undefined): ReadonlyArray<string> => (value === undefined || value === "" ? [] : value.split(","));

const listParam = (list: ReadonlyArray<string>): string | undefined => (list.length === 0 ? undefined : list.join(","));

/** What the arena's URL says: the filter and the open leaderboard row. */
export const arenaStateOf = (route: Extract<SiteRoute, { readonly _tag: "Arena" }>) => ({
  filter: { offModels: listOf(route.offModels), offEfforts: listOf(route.offEfforts) },
  maybeRow: Option.fromUndefinedOr(route.row),
});

export const arenaHref = (filter: Filter, maybeRow: Option.Option<string>): string =>
  arenaRouter({ offModels: listParam(filter.offModels), offEfforts: listParam(filter.offEfforts), row: Option.getOrUndefined(maybeRow) });

/** A replay's URL; `at` is the ordinal of the move it shows. */
export const replayHref = (id: string, maybeAt: Option.Option<number>): string => replayRouter({ id, at: Option.getOrUndefined(maybeAt) });
