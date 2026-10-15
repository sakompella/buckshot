import { expect, test } from "bun:test";
import { Array as Arr, Option, Result, Schema } from "effect";

import { emptyTable, type HeadlessTable, headlessSession } from "../src/agent/headless.ts";
import { AgentReply, runTool, tools } from "../src/agent/tools.ts";
import { Game } from "../src/bend.ts";
import { SeatCount } from "../src/domain.ts";
import { type Controller, promptsOf } from "../src/driver.ts";
import { rosterOf } from "../src/players.ts";
import { nextBelow, type Rng, seedRng } from "../src/rng.ts";

// The tool contract, through the same decodeCall and runTool both front ends
// use, over the headless session the MCP server runs.

const STEP_LIMIT = 20_000;

const MAX_PLAYERS = 4;

const View = Schema.Struct({
  you: Schema.Number,
  players: Schema.Array(Schema.Struct({ player: Schema.Number })),
  isYourTurn: Schema.Boolean,
  isMatchOver: Schema.Boolean,
  turn: Schema.Number,
  privateNotes: Schema.Array(Schema.String),
  moves: Schema.Array(Schema.Struct({ index: Schema.Number, label: Schema.String })),
});

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

type ToolName = (typeof tools)[number]["name"];

type ToolInput = Record<string, number | string | boolean | ReadonlyArray<string>>;

type Outcome = { readonly table: HeadlessTable; readonly reply: AgentReply };

const call = (table: HeadlessTable, name: ToolName, input: ToolInput): Outcome => {
  const tool = Arr.findFirst(tools, (candidate) => candidate.name === name).pipe(Option.getOrThrow);

  return Result.match(tool.decodeCall(input), {
    onSuccess: (agentCall) => {
      const { state, reply } = runTool(headlessSession, table, agentCall);

      return { table: state, reply };
    },
    onFailure: (reason): Outcome => ({ table, reply: AgentReply.cases.Refused.make({ reason }) }),
  });
};

const answered = (reply: AgentReply): string =>
  AgentReply.match(reply, { Answered: ({ text }) => text, Refused: ({ reason }) => expect.unreachable(`refused: ${reason}`) });

const refusal = (reply: AgentReply): string =>
  AgentReply.match(reply, { Answered: () => expect.unreachable("expected a refusal"), Refused: ({ reason }) => reason });

const newMatch = (players: SeatCount, seed: number, controllers: ReadonlyArray<Controller>): HeadlessTable => {
  const started = call(emptyTable, "new_match", { players, items: true, seed: String(seed), controllers });

  answered(started.reply);

  return started.table;
};

const getGame = (table: HeadlessTable, player: number): AgentReply => call(table, "get_game", { player }).reply;

const viewOf = (table: HeadlessTable, player: number) => parseView(answered(getGame(table, player)));

const play = (table: HeadlessTable, player: number, index: number, turn: number): Outcome => call(table, "play_move", { player, index, turn });

const match = (table: HeadlessTable) => Option.getOrThrow(table.maybeMatch);

const rosterAt = (table: HeadlessTable) => rosterOf(match(table).game.seats);

const seatOfPlayer = (table: HeadlessTable, player: number) => Option.getOrThrow(rosterAt(table).seatOf(player));

/** Replies speak of players 1 to N and never of seats. */
const expectOnlyPlayers = (table: HeadlessTable, reply: AgentReply): void => {
  const text = AgentReply.match(reply, { Answered: ({ text: answer }) => answer, Refused: ({ reason }) => reason });
  const named = [...text.matchAll(/Player (\d+)/g)].map(([, number]) => Number(number));

  expect(text).not.toMatch(/seat/i);
  expect(named.every((number) => number >= 1 && number <= rosterAt(table).players.length)).toBe(true);
};

const isOver = (table: HeadlessTable): boolean => match(table).game.pending.kind === "Finished";

const agentPlayers = (table: HeadlessTable): ReadonlyArray<number> =>
  rosterAt(table).players.filter((player) => match(table).controllers[seatOfPlayer(table, player)] === "Agent");

const agentsToMove = (table: HeadlessTable): ReadonlyArray<number> =>
  promptsOf(match(table).game).map(({ seat }) => rosterAt(table).playerOf(seat)).filter((player) => agentPlayers(table).includes(player));

/** A seeded source of choices, so each run of a test sees the same tables. */
const chooser = (seed: number) => {
  let rng: Rng = seedRng(seed);

  return <A>(options: ReadonlyArray<A>): A => {
    const [value, next] = nextBelow(rng, options.length);

    rng = next;

    return Arr.getUnsafe(options, value);
  };
};

test("on random tables of 2 to 4 players, random Agent moves reach the end; each Agent sees only its own notes and the players as Player 1 to N, and calls for other players or stale turns change nothing", () => {
  const choose = chooser(2026);
  const otherState = match(newMatch(4, 8, ["Agent", "DoN", "DoN", "DoN"])).game.state;
  const tableSizes = new Set<SeatCount>();
  let otherAgentNotes = 0;

  for (let trial = 0; trial < 9; trial++) {
    const players = SeatCount.literals[trial % SeatCount.literals.length] ?? 2;
    const lead = choose(Arr.range(0, players - 1));
    const controllers = Arr.makeBy(players, (position): Controller => (position === lead ? "Agent" : choose(["Agent", "DoN", "Story"] as const)));
    let table = newMatch(players, choose(Arr.range(1, 10_000)), controllers);

    tableSizes.add(players);

    for (let steps = 0; steps < STEP_LIMIT && !isOver(table); steps++) {
      const current = match(table);
      const agents = agentPlayers(table);
      const roster = rosterAt(table);

      // The bots have already moved: an Agent always has the turn until the end.
      expect(agentsToMove(table).length).toBeGreaterThan(0);

      for (const player of Arr.range(1, Math.min(roster.players.length + 1, MAX_PLAYERS))) {
        if (!agents.includes(player)) {
          const outcome = call(table, "play_move", { player, index: 0 });
          const isAtTable = player <= roster.players.length;

          expect(refusal(getGame(table, player))).toContain(isAtTable ? "not an Agent player" : "no Player");
          expect(refusal(outcome.reply)).toContain(isAtTable ? "not an Agent player" : "no Player");
          expect(outcome.table).toBe(table);

          if (isAtTable) expectOnlyPlayers(table, outcome.reply);

          continue;
        }

        const seat = seatOfPlayer(table, player);
        const reply = getGame(table, player);
        const view = parseView(answered(reply));
        const ownNotes = current.learned.filter((note) => note.seat === seat);
        const hiddenSwapped = new Game(current.game.table, current.game.seats, current.game.ticket, current.game.board, current.game.pending, otherState);

        otherAgentNotes += current.learned.filter((note) => note.seat !== seat && agents.includes(roster.playerOf(note.seat))).length;
        expectOnlyPlayers(table, reply);
        expect(view.you).toBe(player);
        expect(view.players.map((entry) => entry.player)).toEqual(Arr.range(1, roster.players.length));
        expect(view.privateNotes).toHaveLength(ownNotes.length);
        expect(getGame({ ...table, maybeMatch: Option.some({ ...current, learned: ownNotes }) }, player)).toEqual(reply);
        expect(getGame({ ...table, maybeMatch: Option.some({ ...current, game: hiddenSwapped }) }, player)).toEqual(reply);

        for (const turn of [view.turn - 1, view.turn + 1]) {
          const outcome = play(table, player, 0, turn);

          expect(refusal(outcome.reply)).toContain(view.isYourTurn ? "Stale" : "not your turn");
          expect(outcome.table).toBe(table);
        }
      }

      const player = choose(agentsToMove(table));
      const view = viewOf(table, player);

      table = play(table, player, choose(view.moves).index, view.turn).table;
    }

    expect(isOver(table)).toBe(true);
    expect(viewOf(table, lead + 1).isMatchOver).toBe(true);
  }

  expect(tableSizes).toEqual(new Set(SeatCount.literals));
  expect(otherAgentNotes).toBeGreaterThan(0);
}, 30_000);

test("Agent players that may move at once can answer in either order, and the later one must reread its turn", () => {
  let table = newMatch(3, 42, ["Agent", "Agent", "DoN"]);

  for (let steps = 0; steps < STEP_LIMIT && agentsToMove(table).length < 2; steps++) {
    const player = Arr.getUnsafe(agentsToMove(table), 0);

    table = play(table, player, 0, viewOf(table, player).turn).table;
  }

  for (const [first, second] of [[1, 2], [2, 1]] as const) {
    const before = viewOf(table, second);
    const afterFirst = play(table, first, 0, viewOf(table, first).turn).table;

    expect(viewOf(afterFirst, second).isYourTurn).toBe(true);
    expect(refusal(play(afterFirst, second, 0, before.turn).reply)).toContain("Stale");
    expect(play(afterFirst, second, 0, viewOf(afterFirst, second).turn).reply._tag).toBe("Answered");
  }
});

test("a move number outside the list, or arguments that do not fit the schema, are refused and change nothing", () => {
  const table = newMatch(2, 3, ["DoN", "Agent"]);
  const { moves, turn } = viewOf(table, 2);
  const outOfRange = play(table, 2, moves.length, turn);

  expect(refusal(outOfRange.reply)).toContain("no move");
  expect(outOfRange.table).toBe(table);

  for (const input of [{ player: 2, index: -1 }, { player: 2, index: 1.5 }, { player: 2, index: "zero" }, { player: 5, index: 0 }, { player: 0, index: 0 }, { seat: 3, index: 0 }, { index: 0 }]) {
    const outcome = call(table, "play_move", input);

    expect(refusal(outcome.reply)).toContain("Invalid arguments for play_move");
    expect(outcome.table).toBe(table);
  }
});

test("a move when it is not the player's turn is refused", () => {
  let table = newMatch(3, 3, ["Agent", "Agent", "DoN"]);

  for (let steps = 0; steps < STEP_LIMIT && agentsToMove(table).length !== 1; steps++) {
    const player = Arr.getUnsafe(agentsToMove(table), 0);

    table = play(table, player, 0, viewOf(table, player).turn).table;
  }

  const waiting = agentPlayers(table).find((player) => !agentsToMove(table).includes(player)) ?? expect.unreachable("no waiting agent");
  const outcome = call(table, "play_move", { player: waiting, index: 0 });

  expect(refusal(outcome.reply)).toContain("not your turn");
  expect(outcome.table).toBe(table);
});

test("the tools refuse without a match or without an Agent player", () => {
  expect(refusal(getGame(emptyTable, 1))).toContain("new_match");
  expect(refusal(call(emptyTable, "play_move", { player: 1, index: 0 }).reply)).toContain("new_match");

  const botsOnly = newMatch(2, 1, ["DoN", "Story"]);

  expect(isOver(botsOnly)).toBe(true);
  expect(refusal(getGame(botsOnly, 2))).toContain("no player is");
});

test("new_match refuses a seed that is not an integer, a controller list of the wrong length, and a Human player with no page to click", () => {
  expect(refusal(call(emptyTable, "new_match", { players: 2, items: false, seed: "abc" }).reply)).toContain("seed");
  expect(refusal(call(emptyTable, "new_match", { players: 3, items: false, controllers: ["Agent", "Agent"] }).reply)).toContain("one controller per player");
  expect(refusal(call(emptyTable, "new_match", { players: 2, items: false, controllers: ["Agent", "Human"] }).reply)).toContain("Human");
});

test("new_match makes Player 1 the agent and DoN the others by default, and its seed replays the match", () => {
  const Table = Schema.Struct({ players: Schema.Array(Schema.Struct({ player: Schema.Number, controller: Schema.String })), seed: Schema.String });
  const started = call(emptyTable, "new_match", { players: 3, items: true });
  const { players, seed } = Schema.decodeUnknownSync(Schema.fromJsonString(Table))(answered(started.reply));
  const replayed = call(emptyTable, "new_match", { players: 3, items: true, seed });

  expect(players).toEqual([
    { player: 1, controller: "Agent" },
    { player: 2, controller: "DoN" },
    { player: 3, controller: "DoN" },
  ]);
  expect(getGame(replayed.table, 1)).toEqual(getGame(started.table, 1));
});
