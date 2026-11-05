import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { expect, test } from "bun:test";
import { Option } from "effect";
import { Url } from "foldkit";

import { arenaHref, arenaStateOf, replayHref, routeOf, SiteRoute } from "../src/site/route.ts";

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

test("a replay URL gives back its match and move", () =>
  hegel.test((tc) => {
    const id = tc.draw(gs.sampledFrom(["0749d95aa85420a706c6010b199b9ad35ef034ab71997083fed58bc3108caac9", "0", "ff"]));
    const maybeAt = tc.draw(gs.booleans()) ? Option.some(tc.draw(gs.integers({ minValue: 0, maxValue: 500 }))) : Option.none<number>();

    expect(routeAt(replayHref(id, maybeAt))).toEqual(SiteRoute.Replay({ id, at: Option.getOrUndefined(maybeAt) }));
  }));

test("the arena's old section links lead to the arena; other paths, and replays of no match id, are not found", () => {
  expect(routeAt("/")).toEqual(SiteRoute.Play());
  expect(routeAt("/#scatter")).toEqual(SiteRoute.Arena({}));
  expect(routeAt("/#luck")).toEqual(SiteRoute.Arena({}));
  expect(routeAt("/#nothing")).toEqual(SiteRoute.Play());
  expect(routeAt("/nowhere")).toEqual(SiteRoute.NotFound({ path: "/nowhere" }));
  expect(routeAt("/replay/not%20a%20match")).toEqual(SiteRoute.NotFound({ path: "/replay/not%20a%20match" }));
});
