import { expect, test } from "bun:test";
import { Array as Arr, Option, Result, Schema } from "effect";

import { emptyTable, type HeadlessTable, headlessSession } from "../src/agent/headless.ts";
import { AgentReply, runTool, tools } from "../src/agent/tools.ts";
import { Token } from "../src/agent/view.ts";
import { Game } from "../src/bend.ts";
import { Briefcase, GameEvent, Secret, SeatCount, Stage } from "../src/domain.ts";
import { type Controller, promptsOf } from "../src/driver.ts";
import { rosterOf } from "../src/players.ts";
import { nextBelow, type Rng, seedRng } from "../src/rng.ts";
import { eventText, itemName, secretText } from "../src/text.ts";

// The tool contract, through the same decodeCall and runTool both front ends
// use, over the headless session the MCP server runs.

const STEP_LIMIT = 20_000;

const MAX_PLAYERS = 4;

const View = Schema.Struct({
  you: Schema.Number,
  status: Schema.Literals(["your turn", "waiting", "over"]),
  token: Schema.optionalKey(Schema.String),
  players: Schema.optionalKey(Schema.Array(Schema.Struct({ player: Schema.Number, holding: Schema.optionalKey(Schema.String) }))),
  gun: Schema.optionalKey(Schema.Struct({ heldBy: Schema.optionalKey(Schema.Number) })),
  events: Schema.optionalKey(Schema.Array(Schema.String)),
  moves: Schema.optionalKey(Schema.Array(Schema.String)),
  standings: Schema.optionalKey(Schema.Array(Schema.Struct({ player: Schema.Number, cash: Schema.Number }))),
});

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const receiptOf = Schema.decodeUnknownSync(Token);

const tokenOf = Schema.encodeSync(Token);

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

const newMatch = (players: SeatCount, seed: number, controllers: ReadonlyArray<Controller>, { items = true, on = emptyTable } = {}): HeadlessTable => {
  const started = call(on, "new_match", { players, items, seed: String(seed), controllers });

  answered(started.reply);

  return started.table;
};

const getGame = (table: HeadlessTable, player: number): AgentReply => call(table, "get_game", { player }).reply;

const acknowledge = (table: HeadlessTable, player: number, token: string): Outcome => call(table, "get_game", { player, token });

const viewOf = (table: HeadlessTable, player: number) => parseView(answered(getGame(table, player)));

/** A view of a player who has the turn, with its token and moves. */
const turnViewOf = (table: HeadlessTable, player: number) => {
  const { token, moves = [], ...view } = viewOf(table, player);

  return { ...view, token: token ?? expect.unreachable("a player to move has no token"), moves };
};

const play = (table: HeadlessTable, player: number, index: number, token: string): Outcome => call(table, "play_move", { player, index, token });

/** Plays the first Agent's first move until `isDone` holds or the match ends. */
const playUntil = (start: HeadlessTable, isDone: (table: HeadlessTable) => boolean): HeadlessTable => {
  let table = start;

  for (let steps = 0; steps < STEP_LIMIT && !isOver(table) && !isDone(table); steps++) {
    const player = Arr.getUnsafe(agentsToMove(table), 0);

    table = play(table, player, 0, turnViewOf(table, player).token).table;
  }

  return table;
};

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

      table = play(table, player, choose(Arr.range(0, view.moves.length - 1)), view.token).table;
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
        const outcome = play(table, player, 0, tokenOf({ ...current.game.ticket, player, events: current.events.length }));
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

      expect(call(table, "get_game", { player }).table).toBe(table);

      if (view.status !== "your turn") continue;

      expect(view.players?.map((entry) => entry.player)).toEqual(Arr.range(1, roster.players.length));

      const receipt = receiptOf(view.token ?? expect.unreachable("a view on the player's turn has no token"));
      const otherAgent = agents.find((other) => other !== player);

      const misfits = [
        ["Stale", { ...receipt, generation: receipt.generation - 1 }],
        ["not reached", { ...receipt, generation: receipt.generation + 1 }],
        ["not reached", { ...receipt, events: receipt.events + 1 }],
        ["another match", { ...receipt, match: receipt.match + 1 }],
        ...(otherAgent === undefined ? [] : [["not Player", { ...receipt, player: otherAgent }] as const]),
      ] as const;

      for (const [reason, misfit] of misfits) {
        const outcome = play(table, player, 0, tokenOf(misfit));

        expect(refusal(outcome.reply)).toContain(reason);
        expect(outcome.table).toBe(table);
      }

      for (const [reason, misfit] of misfits.filter(([reason]) => reason !== "Stale")) {
        const outcome = acknowledge(table, player, tokenOf(misfit));

        expect(refusal(outcome.reply)).toContain(reason);
        expect(outcome.table).toBe(table);
      }
    }
  });

  expect(tableSizes).toEqual(new Set(SeatCount.literals));
  expect(otherAgentNotes).toBeGreaterThan(0);
}, 30_000);

test("a view holds only what the screen shows: a bare waiting while it is not the player's turn, no cash or nulls until the match is over, the gun's holder only once it is picked up, each player's drawn briefcase item, and the final standings with every player's cash", () => {
  let holdingsShown = 0;

  playRandomTables(77, 3, (table) => {
    const { board } = match(table).game;
    const roster = rosterAt(table);

    for (const player of agentPlayers(table)) {
      const text = answered(getGame(table, player));
      const view = parseView(text);

      expect(text).not.toContain("null");

      if (view.status === "waiting") {
        expect(JSON.parse(text)).toEqual({ you: player, status: "waiting" });
        continue;
      }

      const holder = Stage.matchOrElse(board.stage, { Playing: ({ seat, mode }) => (mode === "Aiming" ? roster.playerOf(seat) : undefined) }, () => undefined);
      const holdings = board.seats.map((seat) => Briefcase.matchOrElse(seat.briefcase, { Holding: ({ item }) => itemName(item) }, () => undefined));

      expect(text).not.toContain("cash");
      expect(view.gun?.heldBy).toBe(holder);
      expect(view.players?.map(({ holding }) => holding)).toEqual(holdings);
      holdingsShown += holdings.filter((holding) => holding !== undefined).length;
    }
  });

  expect(holdingsShown).toBeGreaterThan(0);

  const table = playUntil(newMatch(2, 5, ["Agent", "DoN"]), () => false);
  const { standings, events, token, ...over } = viewOf(table, 1);

  expect(over).toEqual({ you: 1, status: "over" });
  expect(events?.length).toBeGreaterThan(0);
  expect(standings?.map(({ player }) => player).toSorted()).toEqual([1, 2]);

  const acknowledged = acknowledge(table, 1, token ?? expect.unreachable("an over view with events has no token"));

  expect(JSON.parse(answered(acknowledged.reply))).toEqual({ ...over, standings });
}, 30_000);

test("on random tables of 2 to 4 players, with replies lost at random, an Agent that acknowledges each reply it reads hears the whole log in order with no gaps or repeats, the final events included, with only its own secrets; replies change nothing until acknowledged", () => {
  const choose = chooser(31);
  let secretsShown = 0;
  let roundWinsHeard = 0;
  let repliesLost = 0;

  for (let trial = 0; trial < 9; trial++) {
    const players = SeatCount.literals[trial % SeatCount.literals.length] ?? 2;
    const lead = choose(Arr.range(0, players - 1));
    const controllers = Arr.makeBy(players, (position): Controller => (position === lead ? "Agent" : choose(["Agent", "DoN", "Story"] as const)));
    let table = newMatch(players, choose(Arr.range(1, 10_000)), controllers);
    const heard = new Map<number, ReadonlyArray<string>>();
    const tokens = new Map<number, string>();

    /** Reads a reply unless it is lost, and returns the view if it was read. */
    const receive = (player: number, outcome: Outcome) => {
      table = outcome.table;

      if (choose([false, false, true])) {
        repliesLost += 1;

        return undefined;
      }

      const view = parseView(answered(outcome.reply));

      heard.set(player, [...(heard.get(player) ?? []), ...(view.events ?? [])]);

      if (view.token !== undefined) tokens.set(player, view.token);

      return view;
    };

    const getGameAcknowledging = (player: number): Outcome => {
      const token = tokens.get(player);

      return call(table, "get_game", token === undefined ? { player } : { player, token });
    };

    const expectWholeLog = (player: number): void => {
      const { events, learned } = match(table);
      const everySecret = new Set(learned.map(({ secret }) => secretText(secret)));
      const seen = heard.get(player) ?? [];
      const ownSecrets = learned.filter((note) => note.seat === seatOfPlayer(table, player)).map(({ secret }) => secretText(secret));

      expect(seen.filter((line) => !everySecret.has(line))).toEqual(events.map((event) => eventText(rosterAt(table), event)));
      expect(seen.filter((line) => everySecret.has(line))).toEqual(ownSecrets);
      secretsShown += ownSecrets.length;
    };

    for (let steps = 0; steps < STEP_LIMIT && !isOver(table); steps++) {
      const toMove = new Map<number, string>();

      for (const player of agentPlayers(table)) {
        expect(call(table, "get_game", { player }).table).toBe(table);

        const view = receive(player, getGameAcknowledging(player));

        if (view?.status !== "your turn") continue;

        expectWholeLog(player);
        toMove.set(player, view.token ?? expect.unreachable("a view on the player's turn has no token"));
      }

      const player = choose(agentsToMove(table));
      const token = toMove.get(player);

      if (token !== undefined) receive(player, play(table, player, choose(Arr.range(0, turnViewOf(table, player).moves.length - 1)), token));
    }

    for (const player of agentPlayers(table)) {
      for (let reads = 0; reads < STEP_LIMIT && receive(player, getGameAcknowledging(player)) === undefined; reads++);

      expect(viewOf(table, player).status).toBe("over");
      expectWholeLog(player);
      roundWinsHeard += (heard.get(player) ?? []).filter((line) => line.includes("wins the round")).length;
    }
  }

  expect(repliesLost).toBeGreaterThan(0);
  expect(roundWinsHeard).toBeGreaterThan(0);
  expect(secretsShown).toBeGreaterThan(0);
}, 30_000);

test("a phone clue's position counts the chambered shell as 1, as the shells fired later show", () => {
  let checked = 0;

  for (const seed of Arr.range(1, 8)) {
    let table = newMatch(3, seed, ["Agent", "Agent", "DoN"]);

    for (let steps = 0; steps < STEP_LIMIT && !isOver(table); steps++) {
      const player = Arr.getUnsafe(agentsToMove(table), 0);
      const { moves, token } = turnViewOf(table, player);

      table = play(table, player, (steps * 7 + 3) % moves.length, token).table;
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
  const table = playUntil(newMatch(3, 42, ["Agent", "Agent", "DoN"]), (current) => agentsToMove(current).length === 2);

  for (const [first, second] of [[1, 2], [2, 1]] as const) {
    const before = turnViewOf(table, second);
    const afterFirst = play(table, first, 0, turnViewOf(table, first).token).table;

    expect(viewOf(afterFirst, second).status).toBe("your turn");
    expect(refusal(play(afterFirst, second, 0, before.token).reply)).toContain("Stale");
    expect(play(afterFirst, second, 0, turnViewOf(afterFirst, second).token).reply._tag).toBe("Answered");
  }
});

test("a move number outside the list, or arguments that do not fit the schema, are refused and change nothing", () => {
  const table = newMatch(2, 3, ["DoN", "Agent"]);
  const { moves, token } = turnViewOf(table, 2);
  const outOfRange = play(table, 2, moves.length, token);

  expect(refusal(outOfRange.reply)).toContain("no move");
  expect(outOfRange.table).toBe(table);

  for (const input of [{ player: 2, index: -1, token }, { player: 2, index: 1.5, token }, { player: 2, index: "zero", token }, { player: 5, index: 0, token }, { player: 0, index: 0, token }, { seat: 3, index: 0, token }, { index: 0, token }, { player: 2, index: 0 }, { player: 2, index: 0, token: 3 }, ...["", "m1t2p3", "m1t2p3e-4", "m1.5t2p3e4", `m${"9".repeat(400)}t2p3e4`, ` ${token}`].map((malformed) => ({ player: 2, index: 0, token: malformed }))]) {
    const outcome = call(table, "play_move", input);

    expect(refusal(outcome.reply)).toContain("Invalid arguments for play_move");
    expect(outcome.table).toBe(table);
  }
});

test("a move when it is not the player's turn is refused", () => {
  const table = playUntil(newMatch(3, 3, ["Agent", "Agent", "DoN"]), (current) => agentsToMove(current).length === 1);
  const waiting = agentPlayers(table).find((player) => !agentsToMove(table).includes(player)) ?? expect.unreachable("no waiting agent");
  const { ticket } = match(table).game;
  const outcome = play(table, waiting, 0, tokenOf({ ...ticket, player: waiting, events: match(table).events.length }));

  expect(refusal(outcome.reply)).toContain("not your turn");
  expect(outcome.table).toBe(table);
});

test("the tools refuse without a match or without an Agent player", () => {
  expect(refusal(getGame(emptyTable, 1))).toContain("new_match");
  expect(refusal(play(emptyTable, 1, 0, tokenOf({ match: 1, generation: 0, player: 1, events: 0 })).reply)).toContain("new_match");

  const botsOnly = newMatch(2, 1, ["DoN", "Story"]);

  expect(isOver(botsOnly)).toBe(true);
  expect(refusal(getGame(botsOnly, 2))).toContain("no player is");
});

test("a lost or repeated get_game reply loses nothing: on seed 3 a retry shows the same events, and only acknowledging the token moves past them, however often it is sent", () => {
  const table = newMatch(2, 3, ["Agent", "DoN"]);
  const first = call(table, "get_game", { player: 1 });
  const retry = call(table, "get_game", { player: 1 });
  const { token = expect.unreachable("no token"), events } = parseView(answered(first.reply));

  expect(events?.length).toBeGreaterThan(0);
  expect(retry).toEqual(first);
  expect(first.table).toBe(table);

  const acknowledged = acknowledge(table, 1, token);
  const again = acknowledge(acknowledged.table, 1, token);

  expect(parseView(answered(acknowledged.reply)).events).toBeUndefined();
  expect(again.reply).toEqual(acknowledged.reply);
});

test("two readers of one player see the same events, and neither a move by one nor an older acknowledgement by the other drops or repeats any", () => {
  const table = newMatch(2, 3, ["Agent", "DoN"]);
  const { token, moves } = turnViewOf(table, 1);

  expect(getGame(table, 1)).toEqual(getGame(table, 1));

  const moved = play(table, 1, moves.length - 1, token);
  const movedView = parseView(answered(moved.reply));
  const otherReader = parseView(answered(acknowledge(moved.table, 1, token).reply));

  expect(movedView.events?.length).toBeGreaterThan(0);
  expect(otherReader).toEqual(movedView);

  const latest = acknowledge(moved.table, 1, movedView.token ?? expect.unreachable("no token after the move"));
  const older = acknowledge(latest.table, 1, token);

  expect(parseView(answered(older.reply)).events).toBeUndefined();
  expect(older.table).toEqual(latest.table);
});

test("a token from an earlier match is refused in a new match with the same seed and setup, at the same turn", () => {
  const setup = [2, 3, ["Agent", "DoN"], { items: false }] as const;
  const atTurnSix = (table: HeadlessTable) => match(table).game.ticket.generation >= 6;
  const earlier = playUntil(newMatch(...setup), atTurnSix);
  const { token } = turnViewOf(earlier, 1);
  const later = playUntil(newMatch(setup[0], setup[1], setup[2], { ...setup[3], on: earlier }), atTurnSix);
  const { match: earlierMatch, ...earlierPoint } = receiptOf(token);
  const { match: laterMatch, ...laterPoint } = receiptOf(turnViewOf(later, 1).token);

  expect(laterPoint).toEqual(earlierPoint);
  expect(laterMatch).not.toBe(earlierMatch);

  for (const outcome of [play(later, 1, 0, token), acknowledge(later, 1, token)]) {
    expect(refusal(outcome.reply)).toContain("another match");
    expect(outcome.table).toBe(later);
  }
});

test("a move repeated after it kept the player's turn is refused, not played twice", () => {
  let kept = 0;

  for (const seed of Arr.range(1, 4)) {
    let table = newMatch(2, seed, ["Agent", "DoN"]);

    for (let steps = 0; steps < STEP_LIMIT && !isOver(table); steps++) {
      const { token, moves } = turnViewOf(table, 1);
      const index = steps % moves.length;
      const once = play(table, 1, index, token);

      if (parseView(answered(once.reply)).status === "your turn" && receiptOf(turnViewOf(once.table, 1).token).events > receiptOf(token).events) {
        const twice = play(once.table, 1, index, token);

        expect(refusal(twice.reply)).toContain("Stale");
        expect(twice.table).toBe(once.table);
        kept += 1;
      }

      table = once.table;
    }
  }

  expect(kept).toBeGreaterThan(0);
}, 30_000);

test("the reply that ends the match carries the last events, the killing shot and the final award included, and repeats them until they are acknowledged", () => {
  let table = newMatch(2, 3, ["Agent", "DoN"]);
  let last = turnViewOf(table, 1);

  while (!isOver(table)) {
    const outcome = play(table, 1, 0, last.token);

    table = outcome.table;

    if (!isOver(table)) last = turnViewOf(table, 1);
  }

  const { events } = match(table);
  const tail = events.slice(receiptOf(last.token).events).map((event) => eventText(rosterAt(table), event));
  const over = viewOf(table, 1);

  expect(over.status).toBe("over");
  expect(over.events?.filter((line) => tail.includes(line))).toEqual(tail);
  expect(tail.some((line) => line.includes("wins the round"))).toBe(true);
  expect(events.slice(receiptOf(last.token).events).some(GameEvent.guards.Fired)).toBe(true);
  expect(viewOf(table, 1)).toEqual(over);
  expect(parseView(answered(acknowledge(table, 1, over.token ?? expect.unreachable("no token at the end")).reply)).events).toBeUndefined();
});

test("on seed 3 the gun has no holder before it is picked up, and the item a player drew from the briefcase is named before it is placed", () => {
  const plain = turnViewOf(newMatch(2, 3, ["Agent", "DoN"], { items: false }), 1);

  expect(plain.moves).toEqual(["Pick up the shotgun"]);
  expect(plain.gun?.heldBy).toBeUndefined();

  const grabbing = newMatch(2, 3, ["Agent", "DoN"]);
  const holding = play(grabbing, 1, 0, turnViewOf(grabbing, 1).token).table;
  const lineOne = match(holding).game.board.seats.find(({ seat }) => seat === seatOfPlayer(holding, 1)) ?? expect.unreachable("Player 1 is not on the board");
  const drawn = Briefcase.matchOrElse(lineOne.briefcase, { Holding: ({ item }) => itemName(item) }, () => expect.unreachable("Player 1 holds no item"));

  expect(turnViewOf(holding, 1).players?.find(({ player }) => player === 1)?.holding).toBe(drawn);
});

test("new_match refuses a seed that is not a safe integer, a controller list of the wrong length, and a Human player with no page to click", () => {
  for (const seed of ["abc", "NaN", "Infinity", "-Infinity", "1e3", "0x10", "1.5", "", " 1", "+1", "9".repeat(400), "-" + "9".repeat(400), "9007199254740992", "-9007199254740992"]) {
    const outcome = call(emptyTable, "new_match", { players: 2, items: false, seed });

    expect(refusal(outcome.reply)).toContain("seed");
    expect(outcome.table).toBe(emptyTable);
  }

  expect(refusal(call(emptyTable, "new_match", { players: 3, items: false, controllers: ["Agent", "Agent"] }).reply)).toContain("one controller per player");
  expect(refusal(call(emptyTable, "new_match", { players: 2, items: false, controllers: ["Agent", "Human"] }).reply)).toContain("Human");
});

const TableReply = Schema.Struct({ players: Schema.Array(Schema.Struct({ player: Schema.Number, controller: Schema.String })), seed: Schema.String });

const parseTable = Schema.decodeUnknownSync(Schema.fromJsonString(TableReply));

/** A view without its token, which names the match and so differs between replays. */
const sightOf = (table: HeadlessTable, player: number) => {
  const { token: _token, ...view } = viewOf(table, player);

  return view;
};

test("new_match makes Player 1 the agent and DoN the others by default, and the seed it returns replays the match, at the edges of the safe integers too", () => {
  const started = call(emptyTable, "new_match", { players: 3, items: true });
  const { players, seed } = parseTable(answered(started.reply));

  expect(players).toEqual([
    { player: 1, controller: "Agent" },
    { player: 2, controller: "DoN" },
    { player: 3, controller: "DoN" },
  ]);
  expect(sightOf(call(emptyTable, "new_match", { players: 3, items: true, seed }).table, 1)).toEqual(sightOf(started.table, 1));

  for (const given of ["0", "-1", "007", "4294967296", "9007199254740991", "-9007199254740991"]) {
    const first = call(emptyTable, "new_match", { players: 2, items: true, seed: given });
    const returned = parseTable(answered(first.reply)).seed;
    const replayed = call(emptyTable, "new_match", { players: 2, items: true, seed: returned });

    expect(returned).toBe(String(Number(given)));
    expect(parseTable(answered(replayed.reply)).seed).toBe(returned);
    expect(sightOf(playUntil(replayed.table, () => false), 1)).toEqual(sightOf(playUntil(first.table, () => false), 1));
  }
}, 30_000);
