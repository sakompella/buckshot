import { expect, test } from "bun:test";
import { Array as Arr, Option, Result, Schema } from "effect";

import { emptyTable, type HeadlessTable, headlessSession } from "../src/agent/headless.ts";
import { AgentReply, runTool, tools } from "../src/agent/tools.ts";
import { Game } from "../src/bend.ts";
import { GameEvent, Secret, SeatCount } from "../src/domain.ts";
import { type Controller, promptsOf } from "../src/driver.ts";
import { rosterOf } from "../src/players.ts";
import { nextBelow, type Rng, seedRng } from "../src/rng.ts";
import { eventText, secretText } from "../src/text.ts";

// The tool contract, through the same decodeCall and runTool both front ends
// use, over the headless session the MCP server runs.

const STEP_LIMIT = 20_000;

const MAX_PLAYERS = 4;

const View = Schema.Struct({
  you: Schema.Number,
  status: Schema.Literals(["your turn", "waiting", "over"]),
  turn: Schema.optionalKey(Schema.Number),
  players: Schema.optionalKey(Schema.Array(Schema.Struct({ player: Schema.Number }))),
  events: Schema.optionalKey(Schema.Array(Schema.String)),
  moves: Schema.optionalKey(Schema.Array(Schema.String)),
  standings: Schema.optionalKey(Schema.Array(Schema.Struct({ player: Schema.Number, cash: Schema.Number }))),
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

/** A view of a player who has the turn, with its turn and moves. */
const turnViewOf = (table: HeadlessTable, player: number) => {
  const { turn, moves = [], ...view } = viewOf(table, player);

  return { ...view, turn: turn ?? expect.unreachable("a player to move has no turn"), moves };
};

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

/** Plays random matches on tables of 2 to 4 players, with Agents moving at random, and runs a check at every point where an Agent has the turn. Returns the table sizes it played. */
const playRandomTables = (seed: number, trials: number, check: (table: HeadlessTable) => void): ReadonlySet<SeatCount> => {
  const choose = chooser(seed);
  const tableSizes = new Set<SeatCount>();

  for (let trial = 0; trial < trials; trial++) {
    const players = SeatCount.literals[trial % SeatCount.literals.length] ?? 2;
    const lead = choose(Arr.range(0, players - 1));
    const controllers = Arr.makeBy(players, (position): Controller => (position === lead ? "Agent" : choose(["Agent", "DoN", "Story"] as const)));
    let table = newMatch(players, choose(Arr.range(1, 10_000)), controllers);

    tableSizes.add(players);

    for (let steps = 0; steps < STEP_LIMIT && !isOver(table); steps++) {
      // The bots have already moved: an Agent always has the turn until the end.
      expect(agentsToMove(table).length).toBeGreaterThan(0);
      check(table);

      const player = choose(agentsToMove(table));
      const view = turnViewOf(table, player);

      table = play(table, player, choose(Arr.range(0, view.moves.length - 1)), view.turn).table;
    }

    expect(isOver(table)).toBe(true);
    expect(viewOf(table, lead + 1).status).toBe("over");
  }

  return tableSizes;
};

test("on random tables of 2 to 4 players, each Agent sees the players as Player 1 to N and never another player's secrets or the hidden shells, and calls for other players or stale turns change nothing", () => {
  const otherState = match(newMatch(4, 8, ["Agent", "DoN", "DoN", "DoN"])).game.state;
  let otherAgentNotes = 0;

  const tableSizes = playRandomTables(2026, 9, (table) => {
    const current = match(table);
    const agents = agentPlayers(table);
    const roster = rosterAt(table);

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
      expect(getGame({ ...table, maybeMatch: Option.some({ ...current, learned: ownNotes }) }, player)).toEqual(reply);
      expect(getGame({ ...table, maybeMatch: Option.some({ ...current, game: hiddenSwapped }) }, player)).toEqual(reply);

      if (view.status === "your turn") expect(view.players?.map((entry) => entry.player)).toEqual(Arr.range(1, roster.players.length));

      const turn = view.turn ?? 0;

      for (const staleTurn of [turn - 1, turn + 1]) {
        const outcome = play(table, player, 0, staleTurn);

        expect(refusal(outcome.reply)).toContain(view.status === "your turn" ? "Stale" : "not your turn");
        expect(outcome.table).toBe(table);
      }
    }
  });

  expect(tableSizes).toEqual(new Set(SeatCount.literals));
  expect(otherAgentNotes).toBeGreaterThan(0);
}, 30_000);

test("a view holds only what the screen shows: a bare waiting while it is not the player's turn, no cash or nulls until the match is over, and the final standings with every player's cash", () => {
  playRandomTables(77, 3, (table) => {
    for (const player of agentPlayers(table)) {
      const text = answered(getGame(table, player));
      const view = parseView(text);

      expect(text).not.toContain("null");

      if (view.status === "waiting") expect(JSON.parse(text)).toEqual({ you: player, status: "waiting" });
      else expect(text).not.toContain("cash");
    }
  });

  let table = newMatch(2, 5, ["Agent", "DoN"]);

  while (!isOver(table)) {
    const view = turnViewOf(table, 1);

    table = play(table, 1, 0, view.turn).table;
  }

  const { standings, ...over } = viewOf(table, 1);

  expect(over).toEqual({ you: 1, status: "over" });
  expect(standings?.map(({ player }) => player).toSorted()).toEqual([1, 2]);
}, 30_000);

test("on random tables of 2 to 4 players, an Agent's events are the current round's events in order, from its start, with no gaps or repeats, and only its own secrets in them", () => {
  let laterRounds = 0;
  let secretsShown = 0;

  playRandomTables(31, 9, (table) => {
    const { events, learned } = match(table);
    const roster = rosterAt(table);
    const roundStart = events.findLastIndex(GameEvent.guards.RoundBegan);
    const publicRound = events.slice(roundStart).map((event) => eventText(roster, event));
    const everySecret = new Set(learned.map(({ secret }) => secretText(secret)));

    laterRounds += roundStart > 0 ? 1 : 0;

    for (const player of agentsToMove(table)) {
      const shown = viewOf(table, player).events ?? [];
      const ownSecrets = learned.filter((note) => note.seat === seatOfPlayer(table, player) && note.at > roundStart).map(({ secret }) => secretText(secret));

      expect(shown.filter((line) => !everySecret.has(line))).toEqual(publicRound);
      expect(shown.filter((line) => everySecret.has(line))).toEqual(ownSecrets);
      secretsShown += ownSecrets.length;
    }
  });

  expect(laterRounds).toBeGreaterThan(0);
  expect(secretsShown).toBeGreaterThan(0);
}, 30_000);

test("a phone clue's position counts the chambered shell as 1, as the shells fired later show", () => {
  let checked = 0;

  for (const seed of Arr.range(1, 8)) {
    let table = newMatch(3, seed, ["Agent", "Agent", "DoN"]);

    for (let steps = 0; steps < STEP_LIMIT && !isOver(table); steps++) {
      const player = Arr.getUnsafe(agentsToMove(table), 0);
      const { moves, turn } = turnViewOf(table, player);

      table = play(table, player, (steps * 7 + 3) % moves.length, turn).table;
    }

    const { events, learned } = match(table);

    for (const { secret, at } of learned) {
      if (!Secret.guards.Clue(secret)) continue;

      const rest = events.slice(at);
      const sameGun = rest.slice(0, Math.max(0, rest.findIndex(GameEvent.guards.Loaded)));
      const used = sameGun.flatMap((event) => (GameEvent.guards.Fired(event) || GameEvent.guards.Ejected(event) ? [event.shell] : []));

      // An inverter flips the chambered shell, which would hide what the clue said.
      if (sameGun.some(GameEvent.guards.Inverted) || used.length < secret.position) continue;

      expect(used[secret.position - 1]).toBe(secret.shell);
      checked += 1;
    }
  }

  expect(checked).toBeGreaterThan(0);
}, 30_000);

test("Agent players that may move at once can answer in either order, and the later one must reread its turn", () => {
  let table = newMatch(3, 42, ["Agent", "Agent", "DoN"]);

  for (let steps = 0; steps < STEP_LIMIT && agentsToMove(table).length < 2; steps++) {
    const player = Arr.getUnsafe(agentsToMove(table), 0);

    table = play(table, player, 0, turnViewOf(table, player).turn).table;
  }

  for (const [first, second] of [[1, 2], [2, 1]] as const) {
    const before = turnViewOf(table, second);
    const afterFirst = play(table, first, 0, turnViewOf(table, first).turn).table;

    expect(viewOf(afterFirst, second).status).toBe("your turn");
    expect(refusal(play(afterFirst, second, 0, before.turn).reply)).toContain("Stale");
    expect(play(afterFirst, second, 0, turnViewOf(afterFirst, second).turn).reply._tag).toBe("Answered");
  }
});

test("a move number outside the list, or arguments that do not fit the schema, are refused and change nothing", () => {
  const table = newMatch(2, 3, ["DoN", "Agent"]);
  const { moves, turn } = turnViewOf(table, 2);
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

    table = play(table, player, 0, turnViewOf(table, player).turn).table;
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
