import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { expect, test } from "bun:test";
import { Option } from "effect";
import { Url } from "foldkit";

import { arenaHref, arenaStateOf, routeOf, SiteRoute } from "../src/site/route.ts";

const routeAt = (href: string): SiteRoute => routeOf(Option.getOrThrow(Url.fromString(`http://site.test${href}`)));

const NAMES = ["gpt-6.1-terra", "claude-opus-5-5", "Opus 5.5", "a&b=c", "100% / max", "é"];

test("an arena URL gives back the filter and open row it was built from", () =>
  hegel.test((tc) => {
    const names = gs.arrays(gs.sampledFrom(NAMES), { maxSize: 4, unique: true });
    const filter = { offModels: tc.draw(names), offEfforts: tc.draw(names) };
    const maybeRow = tc.draw(gs.booleans()) ? Option.some(`${tc.draw(gs.sampledFrom(NAMES))}|max`) : Option.none();
    const route = routeAt(arenaHref(filter, maybeRow));

    if (!SiteRoute.guards.Arena(route)) return expect.unreachable(`${arenaHref(filter, maybeRow)} is not an arena URL`);

    expect(arenaStateOf(route)).toEqual({ filter, maybeRow });
  }));

test("the root and its old section links lead to the arena; other paths are not found", () => {
  expect(routeAt("/")).toEqual(SiteRoute.Arena({}));
  expect(routeAt("/#scatter")).toEqual(SiteRoute.Arena({}));
  expect(routeAt("/nowhere")).toEqual(SiteRoute.NotFound({ path: "/nowhere" }));
  expect(routeAt("/replay/0749d95aa85420a706c6010b199b9ad35ef034ab71997083fed58bc3108caac9")).toEqual(SiteRoute.NotFound({ path: "/replay/0749d95aa85420a706c6010b199b9ad35ef034ab71997083fed58bc3108caac9" }));
});
