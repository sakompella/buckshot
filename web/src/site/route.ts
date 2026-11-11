import { Option, pipe, Predicate, Schema } from "effect";
import { Route, type Url } from "foldkit";

import type { Filter } from "../arena-viewer/page/model.ts";

// The site's one page and its URL. The arena's shareable state lives in the query: the models and efforts switched
// off and the open leaderboard row.

const ArenaQuery = Schema.Struct({ offModels: Schema.optional(Schema.String), offEfforts: Schema.optional(Schema.String), row: Schema.optional(Schema.String) });

export const SiteRoute = Route.defineRouteUnion({
  Arena: ArenaQuery.fields,
  NotFound: { path: Schema.String },
});

export type SiteRoute = typeof SiteRoute.Type;

export type ArenaRoute = Extract<SiteRoute, { readonly _tag: "Arena" }>;

const arenaRouter = pipe(Route.literal("arena"), Route.query(ArenaQuery), Route.mapTo(SiteRoute.Arena));

const parseRoute = Route.parseUrlWithFallback(arenaRouter, SiteRoute.NotFound);

/** The paths the site has a page at; every other path answers 404 with the app, which says nothing lives there. */
export const PAGE_PATHS: ReadonlyArray<string> = ["/", "/arena"];

/** The site's root shows the arena; an old link such as `/#scatter` keeps its section. */
export const isRootUrl = (url: Url.Url): boolean => url.pathname === "/";

export const routeOf = (url: Url.Url): SiteRoute => (isRootUrl(url) ? SiteRoute.Arena({}) : parseRoute(url));

export const isArenaRoute = (route: SiteRoute): route is ArenaRoute => Predicate.isTagged(route, "Arena");

const listOf = (value: string | undefined): ReadonlyArray<string> => (value === undefined || value === "" ? [] : value.split(","));

const listParam = (list: ReadonlyArray<string>): string | undefined => (list.length === 0 ? undefined : list.join(","));

/** What the arena's URL says: the filter and the open leaderboard row. */
export const arenaStateOf = (route: Extract<SiteRoute, { readonly _tag: "Arena" }>) => ({
  filter: { offModels: listOf(route.offModels), offEfforts: listOf(route.offEfforts) },
  maybeRow: Option.fromUndefinedOr(route.row),
});

export const arenaHref = (filter: Filter, maybeRow: Option.Option<string>): string =>
  arenaRouter({ offModels: listParam(filter.offModels), offEfforts: listParam(filter.offEfforts), row: Option.getOrUndefined(maybeRow) });
