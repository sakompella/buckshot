import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { beforeAll, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Option } from "effect";

import {
  emptyLedger,
  itemMoveOf,
  knowledgeOf,
  knownText,
  ledgerMismatch,
  ledgerStep,
  loadLog,
  positionKeys,
  shotOf,
  stolenClue,
} from "../src/analysis/knowledge.ts";
import { loadPlayer, type Player } from "../src/analysis/player.ts";
import { type Board, Briefcase, Counter, GameEvent, type Item, type LearnedSecret, type Seat, Secret, Stage } from "../src/domain.ts";
import { rosterOf } from "../src/players.ts";

// Own-information histories with known answers: each test builds a player's log
// by hand and checks the shell belief Bend's player module returns for it.

let belief: Player;

beforeAll(async () => {
  const dir = mkdtempSync(join(tmpdir(), "buckshot-knowledge-test-"));

  try {
    belief = await loadPlayer(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}, 60_000);

const ME: Seat = 1;

const THEM: Seat = 3;

const loaded = (live: number, blank: number) => GameEvent.cases.Loaded.make({ load: { live, blank } });

const fired = (shooter: Seat, target: Seat, shell: "Live" | "Blank") => GameEvent.cases.Fired.make({ shooter, target, shell, captured: "Single", applied: shell === "Live" ? 1 : 0, health: 2 });

const used = (seat: Seat, owner: Seat, item: Item) => GameEvent.cases.Used.make({ seat, owner, slot: 0, item });

const ejected = (seat: Seat, shell: "Live" | "Blank") => GameEvent.cases.Ejected.make({ seat, shell });

const inverted = (seat: Seat) => GameEvent.cases.Inverted.make({ seat });

const glimpse = (shell: "Live" | "Blank") => Secret.cases.Glimpse.make({ shell });

const clue = (position: number, shell: "Live" | "Blank") => Secret.cases.Clue.make({ position, shell });

/** A history: events, and secrets heard by a seat right after the events before them. */
type Step = GameEvent | { readonly heard: Secret; readonly by?: Seat };

const historyOf = (steps: ReadonlyArray<Step>) => {
  const events: Array<GameEvent> = [];
  const learned: Array<LearnedSecret> = [];

  for (const step of steps) {
    if ("heard" in step) learned.push({ seat: step.by ?? ME, secret: step.heard, at: events.length });
    else events.push(step);
  }

  return { events, learned };
};

const knowledgeAfter = (steps: ReadonlyArray<Step>, seat: Seat = ME) => {
  const { events, learned } = historyOf(steps);

  return knowledgeOf(belief, loadLog(events, learned, seat));
};

test("a phone clue keeps its offset as shots remove shells, and becomes the chamber two shots later", () => {
  const steps: Array<Step> = [loaded(2, 2), used(ME, ME, "Phone"), { heard: clue(3, "Live") }];
  const first = knowledgeAfter(steps);

  // Six orders of 2 live and 2 blank; the third is live in three of them.
  expect(first.private.orders).toBe(3);
  expect(first.private.live).toEqual([1, 1, 3, 1]);
  expect(knownText(first.private)).toBe("3L");
  expect(Option.isNone(first.chamber)).toBe(true);

  const later = knowledgeAfter([...steps, fired(ME, THEM, "Blank"), fired(THEM, ME, "Live")]);

  // Only BLLB of the three is left: live, then blank.
  expect(later.private.live).toEqual([1, 0]);
  expect(Option.getOrNull(later.chamber)).toBe("Live");
  expect(Option.getOrNull(later.source)).toBe("phone");
  expect(Option.getOrNull(later.clue)).toBe(0);
  // Publicly one live and one blank are left, in either order.
  expect(later.public.live).toEqual([1, 1]);
});

test("what a player believes about the shells is never contradicted by the shells actually loaded", () =>
  hegel.test((tc) => {
    const shells = tc.draw(gs.arrays(gs.booleans(), { minSize: 2, maxSize: 8 }));
    const name = (isLive: boolean): "Live" | "Blank" => (isLive ? "Live" : "Blank");
    const loadedShells = loaded(shells.filter(Boolean).length, shells.filter((isLive) => !isLive).length);
    const clueAt = tc.draw(gs.integers({ minValue: 2, maxValue: shells.length }));
    const firedCount = tc.draw(gs.integers({ minValue: 0, maxValue: shells.length - 1 }));
    const hasPhone = tc.draw(gs.booleans());
    const hasGlass = tc.draw(gs.booleans());
    const remaining = shells.slice(firedCount);

    const steps: Array<Step> = [
      loadedShells,
      ...(hasPhone ? [used(ME, ME, "Phone"), { heard: clue(clueAt, name(shells[clueAt - 1] ?? false)) }] : []),
      ...shells.slice(0, firedCount).map((isLive) => fired(ME, THEM, name(isLive))),
      ...(hasGlass ? [used(ME, ME, "Glass"), { heard: glimpse(name(remaining[0] ?? false)) }] : []),
    ];

    const knowledge = knowledgeAfter(steps);
    const remainingLive = remaining.filter(Boolean).length;
    const truth = name(remaining[0] ?? false);

    expect(knowledge.private.orders).toBeGreaterThan(0);
    expect(knowledge.private.live.reduce((total, count) => total + count, 0)).toBe(knowledge.private.orders * remainingLive);

    if (Option.isSome(knowledge.chamber)) expect(knowledge.chamber.value).toBe(truth);

    expect(Option.isSome(knowledge.chamber) || !hasGlass).toBe(true);
  }));

test("the public count settles the chamber before a clue does", () => {
  const knowledge = knowledgeAfter([loaded(1, 2), used(ME, ME, "Phone"), { heard: clue(3, "Live") }, fired(ME, ME, "Blank"), fired(ME, THEM, "Blank")]);

  expect(Option.getOrNull(knowledge.chamber)).toBe("Live");
  expect(Option.getOrNull(knowledge.source)).toBe("public");
});

test("an inverter after the magnifier flips the known chamber; the public belief keeps both counts open", () => {
  const knowledge = knowledgeAfter([loaded(2, 1), used(ME, ME, "Glass"), { heard: glimpse("Blank") }, used(ME, ME, "Inverter"), inverted(ME)]);

  expect(Option.getOrNull(knowledge.chamber)).toBe("Live");
  expect(Option.getOrNull(knowledge.source)).toBe("glass");
  expect(knowledge.private.liveMin).toBe(3);
  expect(knowledge.public.liveMin).toBe(1);
  expect(knowledge.public.liveMax).toBe(3);
  expect(knowledge.public.live).toEqual([1, 2, 2]);
});

test("a beer moves a phone clue one shell closer", () => {
  const knowledge = knowledgeAfter([loaded(2, 2), used(ME, ME, "Phone"), { heard: clue(2, "Blank") }, used(ME, ME, "Beer"), ejected(ME, "Live")]);

  expect(Option.getOrNull(knowledge.chamber)).toBe("Blank");
  expect(Option.getOrNull(knowledge.source)).toBe("phone");
  expect(knowledge.private.live).toEqual([0, 1, 1]);
});

test("a reload forgets the last load's clues", () => {
  const knowledge = knowledgeAfter([loaded(1, 1), used(ME, ME, "Phone"), { heard: clue(2, "Live") }, fired(ME, ME, "Blank"), fired(ME, THEM, "Live"), loaded(2, 2)]);

  expect(knowledge.private.orders).toBe(6);
  expect(knowledge.private.live).toEqual([3, 3, 3, 3]);
  expect(Option.isNone(knowledge.chamber)).toBe(true);
});

test("only clues together can settle the chamber", () => {
  const knowledge = knowledgeAfter([loaded(2, 1), used(ME, ME, "Phone"), { heard: clue(2, "Live") }, used(ME, THEM, "Phone"), { heard: clue(3, "Live") }]);

  expect(Option.getOrNull(knowledge.chamber)).toBe("Blank");
  expect(Option.getOrNull(knowledge.source)).toBe("combined");
});

test("another player's clue is not in this player's belief, and an adrenaline glass counts as stolen", () => {
  const steps: Array<Step> = [loaded(1, 1), used(THEM, THEM, "Adrenaline"), used(THEM, ME, "Glass"), { heard: glimpse("Live"), by: THEM }];
  const { events, learned } = historyOf(steps);

  expect(Option.isNone(knowledgeAfter(steps, ME).chamber)).toBe(true);
  expect(Option.getOrNull(knowledgeAfter(steps, THEM).chamber)).toBe("Live");
  expect(stolenClue(events, learned[0]?.at ?? 0, THEM)).toBe(true);
  expect(stolenClue([loaded(1, 1), used(THEM, THEM, "Glass")], 2, THEM)).toBe(false);
});

test("the load log puts each secret after the events before it", () => {
  const { events, learned } = historyOf([loaded(1, 1), used(ME, ME, "Glass"), { heard: glimpse("Live") }, fired(ME, THEM, "Live")]);
  const log = loadLog(events, learned, ME);

  expect(log.map((entry) => (entry.kind === "event" ? entry.event._tag : entry.secret._tag))).toEqual(["Loaded", "Used", "Glimpse", "Fired"]);
  expect(loadLog(events, learned, THEM).map((entry) => entry.kind)).toEqual(["event", "event", "event"]);
});

test("the ledger follows items to their use, theft, the owner's death or the round's end", () => {
  const placed = (seat: Seat, slot: 0 | 1, item: Item) => GameEvent.cases.Placed.make({ seat, slot, item });

  const events = [
    placed(ME, 0, "Glass"),
    placed(ME, 1, "Beer"),
    placed(THEM, 0, "Adrenaline"),
    placed(THEM, 1, "Saw"),
    GameEvent.cases.Used.make({ seat: ME, owner: ME, slot: 0, item: "Glass" }),
    GameEvent.cases.Used.make({ seat: THEM, owner: THEM, slot: 0, item: "Adrenaline" }),
    GameEvent.cases.Used.make({ seat: THEM, owner: ME, slot: 1, item: "Beer" }),
    GameEvent.cases.Died.make({ seat: THEM }),
    GameEvent.cases.RoundBegan.make({ round: 1, health: 3, first: ME }),
  ];

  const ledger = events.reduce((so, event, index) => ledgerStep(so, event, index), emptyLedger);

  expect(ledger.open).toEqual([]);
  expect(ledger.problems).toEqual([]);
  expect(ledger.closed.map((record) => [record.seat, record.item, record.end, Option.getOrNull(record.by)])).toEqual([
    [ME, "Glass", "used", null],
    [THEM, "Adrenaline", "used", null],
    [ME, "Beer", "stolen", THEM],
    [THEM, "Saw", "died", null],
  ]);
  expect(ledgerStep(emptyLedger, GameEvent.cases.Used.make({ seat: ME, owner: ME, slot: 0, item: "Glass" }), 0).problems).toHaveLength(1);
});

const board = (slots: ReadonlyArray<ReadonlyArray<Item>>): Board => ({
  round: { index: 0, rounds: 3, health: 3 },
  seats: ([ME, THEM] as const).map((seat, index) => ({
    seat,
    counter: Counter.cases.Unjammed.make({ health: 3 }),
    slots: Array.from({ length: 8 }, (_, slot) => Option.fromUndefinedOr(slots[index]?.[slot])),
    cash: 0,
    briefcase: Briefcase.cases.NotGrabbing.make({}),
  })),
  gun: { shown: { live: 1, blank: 1 }, remaining: 2, sawed: false },
  direction: "Clockwise",
  stage: Stage.cases.Playing.make({ seat: ME, mode: "Idle" }),
});

test("the ledger and the board must agree slot by slot", () => {
  const ledger = ledgerStep(emptyLedger, GameEvent.cases.Placed.make({ seat: ME, slot: 0, item: "Glass" }), 0);

  expect(Option.isNone(ledgerMismatch(ledger, board([["Glass"], []])))).toBe(true);
  expect(Option.isSome(ledgerMismatch(ledger, board([["Beer"], []])))).toBe(true);
});

test("labels name the item a move spends and the shot's target", () => {
  expect(Option.getOrNull(itemMoveOf("Use magnifying glass"))).toEqual({ item: "Glass", stolen: false });
  expect(Option.getOrNull(itemMoveOf("Jam Player B"))).toEqual({ item: "Jammer", stolen: false });
  expect(Option.getOrNull(itemMoveOf("Steal jammer from Player A and jam Player A"))).toEqual({ item: "Jammer", stolen: true });
  expect(Option.getOrNull(itemMoveOf("Steal burner phone from Player B"))).toEqual({ item: "Phone", stolen: true });
  expect(Option.isNone(itemMoveOf("Shoot Player A"))).toBe(true);
  expect(Option.getOrNull(shotOf("Shoot yourself"))).toBe("self");
  expect(Option.getOrNull(shotOf("Shoot Player B"))).toBe("opponent");
  expect(Option.isNone(shotOf("Grab an item"))).toBe(true);
});

test("a position's keys do not depend on the players' letters", () => {
  const steps = [loaded(1, 1), used(ME, ME, "Glass"), fired(THEM, ME, "Blank")];

  const keysAs = (letters: ReadonlyMap<Seat, "A" | "B">, opponent: "A" | "B") => {
    const roster = rosterOf([ME, THEM], letters);
    const log = loadLog(steps, [], ME);

    return positionKeys(roster, ME, board([["Beer"], ["Saw"]]), log, { public: belief.orders(log, false), private: belief.orders(log, true) }, [`Shoot Player ${opponent}`, "Shoot yourself"], ["code", "instructions"]);
  };

  const asA = keysAs(new Map([[ME, "A"], [THEM, "B"]]), "B");
  const asB = keysAs(new Map([[ME, "B"], [THEM, "A"]]), "A");

  expect(asA).toEqual(asB);

  const roster = rosterOf([ME, THEM]);
  const log = loadLog(steps, [], ME);
  const other = positionKeys(roster, ME, board([["Beer"], ["Saw"]]), log, { public: belief.orders(log, false), private: belief.orders(log, true) }, ["Shoot Player B", "Shoot yourself"], ["other code", "instructions"]);

  expect(other.exact).not.toBe(asA.exact);
});

test("belief positions with the same shells left differ by the load shown", () => {
  const roster = rosterOf([ME, THEM]);

  const keysAfter = (load: { readonly live: number; readonly blank: number }, shots: ReadonlyArray<"Live" | "Blank">) => {
    const log = loadLog([loaded(load.live, load.blank), ...shots.map((shell) => fired(ME, THEM, shell))], [], ME);
    const orders = { public: belief.orders(log, false), private: belief.orders(log, true) };
    const table = board([["Beer"], ["Saw"]]);

    return { orders, keys: positionKeys(roster, ME, { ...table, gun: { shown: load, remaining: 1, sawed: false } }, log, orders, ["Shoot Player B", "Shoot yourself"], ["code", "instructions"]) };
  };

  const fromThreeLive = keysAfter({ live: 3, blank: 1 }, ["Live", "Live", "Blank"]);
  const fromOneLive = keysAfter({ live: 1, blank: 2 }, ["Blank", "Blank"]);

  expect(fromThreeLive.orders).toEqual(fromOneLive.orders);
  expect(fromThreeLive.keys.belief).not.toBe(fromOneLive.keys.belief);
});
