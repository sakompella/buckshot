import { expect, test } from "bun:test";
import { Array as Arr, Option, Result, Schema } from "effect";

import { emptyTable, type HeadlessTable, headlessSession } from "../src/agent/headless.ts";
import { agentMoves } from "../src/agent/moves.ts";
import { AgentReply, runTool, tools } from "../src/agent/tools.ts";
import { Game } from "../src/bend.ts";
import { Briefcase, GameEvent, Move, type Seat, Secret, SeatCount, Stage } from "../src/domain.ts";
import { type Controller, play as playMachine, type Progress, promptsOf } from "../src/driver.ts";
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
  turn: Schema.optionalKey(Schema.Number),
  players: Schema.optionalKey(Schema.Array(Schema.Struct({ player: Schema.Number, holding: Schema.optionalKey(Schema.String) }))),
  gun: Schema.optionalKey(Schema.Struct({ sawed: Schema.optionalKey(Schema.Literal(true)) })),
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

const newMatch = (players: SeatCount, seed: number, controllers: ReadonlyArray<Controller>, { items = true, on = emptyTable } = {}): HeadlessTable => {
  const started = call(on, "new_match", { players, items, seed: String(seed), controllers });

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

const play = (table: HeadlessTable, player: number, move: number, turn: number): Outcome => call(table, "play_move", { player, move, turn });

const match = (table: HeadlessTable) => Option.getOrThrow(table.maybeMatch);

const isOver = (table: HeadlessTable): boolean => match(table).game.pending.kind === "Finished";

const rosterAt = (table: HeadlessTable) => rosterOf(match(table).game.seats);

const seatOfPlayer = (table: HeadlessTable, player: number) => Option.getOrThrow(rosterAt(table).seatOf(player));

/** Replies speak of players 1 to N and never of seats. */
const expectOnlyPlayers = (table: HeadlessTable, reply: AgentReply): void => {
  const text = AgentReply.match(reply, { Answered: ({ text: answer }) => answer, Refused: ({ reason }) => reason });
  const named = [...text.matchAll(/Player (\d+)/g)].map(([, number]) => Number(number));

  expect(text).not.toMatch(/seat/i);
  expect(named.every((number) => number >= 1 && number <= rosterAt(table).players.length)).toBe(true);
};

const agentPlayers = (table: HeadlessTable): ReadonlyArray<number> =>
  rosterAt(table).players.filter((player) => match(table).controllers[seatOfPlayer(table, player)] === "Agent");

const agentsToMove = (table: HeadlessTable): ReadonlyArray<number> =>
  promptsOf(match(table).game).map(({ seat }) => rosterAt(table).playerOf(seat)).filter((player) => agentPlayers(table).includes(player));

/** Plays the first Agent's first move until `isDone` holds or the match ends. */
const playUntil = (start: HeadlessTable, isDone: (table: HeadlessTable) => boolean): HeadlessTable => {
  let table = start;

  for (let steps = 0; steps < STEP_LIMIT && !isOver(table) && !isDone(table); steps++) {
    const player = Arr.getUnsafe(agentsToMove(table), 0);

    table = play(table, player, 0, turnViewOf(table, player).turn).table;
  }

  return table;
};

/** A seeded source of choices, so each run of a test sees the same tables. */
const chooser = (seed: number) => {
  let rng: Rng = seedRng(seed);

  return <A>(options: ReadonlyArray<A>): A => {
    const [value, next] = nextBelow(rng, options.length);

    rng = next;

    return Arr.getUnsafe(options, value);
  };
};

interface Watchers {
  /** Before every move. */
  readonly check?: (table: HeadlessTable) => void;
  /** The view a player moves from. */
  readonly onMove?: (player: number, view: ReturnType<typeof turnViewOf>) => void;
  readonly onOver?: (table: HeadlessTable) => void;
}

/** Plays random matches with items on tables of 2 to 4 players, with Agents moving at random. Returns the table sizes it played. */
const playRandomTables = (seed: number, trials: number, { check, onMove, onOver }: Watchers): ReadonlySet<SeatCount> => {
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
      check?.(table);

      const player = choose(agentsToMove(table));
      const view = turnViewOf(table, player);

      onMove?.(player, view);
      table = play(table, player, choose(Arr.range(0, view.moves.length - 1)), view.turn).table;
    }

    expect(isOver(table)).toBe(true);
    onOver?.(table);
  }

  return tableSizes;
};

/** A view without the moves, which the machine state behind the board decides. */
const withoutMoves = (reply: AgentReply) => {
  const { moves: _moves, ...view } = parseView(answered(reply));

  return view;
};

test("on random tables of 2 to 4 players, each Agent sees the players as Player 1 to N and never another player's secrets or the hidden shells, get_game changes nothing and says the same twice, and calls for other players or other turns are refused", () => {
  const otherState = match(newMatch(4, 8, ["Agent", "DoN", "DoN", "DoN"])).game.state;
  let otherAgentNotes = 0;

  const tableSizes = playRandomTables(2026, 6, { check: (table) => {
    const current = match(table);
    const agents = agentPlayers(table);
    const roster = rosterAt(table);
    const { turn } = table;

    for (const player of Arr.range(1, Math.min(roster.players.length + 1, MAX_PLAYERS))) {
      if (!agents.includes(player)) {
        const outcome = play(table, player, 0, turn);
        const isAtTable = player <= roster.players.length;

        expect(refusal(getGame(table, player))).toContain(isAtTable ? "not an Agent player" : "no Player");
        expect(refusal(outcome.reply)).toContain(isAtTable ? "not an Agent player" : "no Player");
        expect(outcome.table).toBe(table);

        if (isAtTable) expectOnlyPlayers(table, outcome.reply);

        continue;
      }

      const seat = seatOfPlayer(table, player);
      const read = call(table, "get_game", { player });
      const view = parseView(answered(read.reply));
      const ownNotes = current.learned.filter((note) => note.seat === seat);
      const hiddenSwapped = new Game(current.game.table, current.game.seats, current.game.ticket, current.game.board, current.game.pending, otherState);

      otherAgentNotes += current.learned.filter((note) => note.seat !== seat && agents.includes(roster.playerOf(note.seat))).length;
      expectOnlyPlayers(table, read.reply);
      expect(view.you).toBe(player);
      expect(read.table).toBe(table);
      expect(getGame(table, player)).toEqual(read.reply);
      expect(getGame({ ...table, maybeMatch: Option.some({ ...current, learned: ownNotes }) }, player)).toEqual(read.reply);
      expect(withoutMoves(getGame({ ...table, maybeMatch: Option.some({ ...current, game: hiddenSwapped }) }, player))).toEqual(withoutMoves(read.reply));

      if (view.status !== "your turn") continue;

      expect(view.turn).toBe(turn);
      expect(view.players?.map((entry) => entry.player)).toEqual(Arr.range(1, roster.players.length));

      for (const other of [turn - 1, turn + 1]) {
        const outcome = play(table, player, 0, other);

        expect(refusal(outcome.reply)).toContain("Stale");
        expect(outcome.table).toBe(table);
      }
    }
  } });

  expect(tableSizes).toEqual(new Set(SeatCount.literals));
  expect(otherAgentNotes).toBeGreaterThan(0);
}, 120_000);

test("a view holds only what the screen shows: a bare waiting while it is not the player's turn, no cash or nulls until the match is over, no drawn item, since the bots and the agents here place what they draw before anyone looks, and the final standings with every player's cash", () => {
  playRandomTables(77, 3, { check: (table) => {
    const { board } = match(table).game;

    for (const player of agentPlayers(table)) {
      const text = answered(getGame(table, player));
      const view = parseView(text);

      expect(text).not.toContain("null");

      if (view.status === "waiting") {
        expect(JSON.parse(text)).toEqual({ you: player, status: "waiting" });
        continue;
      }

      const holdings = board.seats.map((seat) => Briefcase.matchOrElse(seat.briefcase, { Holding: ({ item }) => itemName(item) }, () => undefined));

      expect(text).not.toContain("cash");
      expect(view.gun?.sawed).toBe(board.gun.sawed ? true : undefined);
      expect(view.players?.map(({ holding }) => holding)).toEqual(holdings);
      expect(holdings.every((holding) => holding === undefined)).toBe(true);
    }
  } });

  const table = playUntil(newMatch(2, 5, ["Agent", "DoN"]), () => false);
  const reply = getGame(table, 1);
  const { standings, events, ...over } = parseView(answered(reply));

  expect(over).toEqual({ you: 1, status: "over" });
  expect(events?.at(-1)).toBe("The match is over.");
  expect(standings?.map(({ player }) => player).toSorted()).toEqual([1, 2]);
  expect(getGame(table, 1)).toEqual(reply);
}, 30_000);

/** Whether the seat's last machine move left it partway through an action: aiming, choosing a target or an item to steal, or holding a drawn item. */
const isMidAction = (progress: Progress, seat: Seat): boolean =>
  Stage.matchOrElse(progress.game.board.stage, { Playing: (playing) => playing.seat === seat && playing.mode !== "Idle" }, () => false) ||
  progress.game.board.seats.some((view) => view.seat === seat && Briefcase.guards.Holding(view.briefcase));

const menuOf = (progress: Progress, seat: Seat) => Arr.findFirst(promptsOf(progress.game), (prompt) => prompt.seat === seat).pipe(Option.map(({ menu }) => menu));

const playIndex = (progress: Progress, seat: Seat, index: number): Progress => Result.getOrThrow(playMachine(progress, progress.game.ticket, seat, index, progress.rng));

/** Every chain of machine moves that takes the seat from its menu to the end of an action, every slot included. */
const legalChains = (progress: Progress, seat: Seat): ReadonlyArray<ReadonlyArray<{ readonly move: Move; readonly index: number }>> =>
  Option.getOrElse(menuOf(progress, seat), (): ReadonlyArray<Move> => []).flatMap((move, index) => {
    const after = playIndex(progress, seat, index);

    return isMidAction(after, seat) ? legalChains(after, seat).map((rest) => [{ move, index }, ...rest]) : [[{ move, index }]];
  });

/** A chain with its slots left out: the action it takes, whichever copy of an item or free slot it uses. */
const actionOf = (chain: ReadonlyArray<{ readonly move: Move }>): string =>
  JSON.stringify(chain.map(({ move }) => Move.match(move, { UseItem: ({ item }) => ["UseItem", item], Steal: ({ owner, item }) => ["Steal", owner, item], Place: () => ["Place"], PickUp: () => ["PickUp"], Grab: () => ["Grab"], Shoot: ({ target }) => ["Shoot", target], JamTarget: ({ target }) => ["Jam", target] })));

test("on random tables of 2 to 4 players with items, the moves list is exactly the machine's legal chains, one per action, each with the first copy of an item and the first free slot, and each plays legally to the end of its action", () => {
  let checked = 0;
  const kinds = new Set<string>();

  playRandomTables(404, 6, { check: (table) => {
    const progress = match(table);
    const roster = rosterAt(table);

    for (const player of agentsToMove(table)) {
      const seat = seatOfPlayer(table, player);
      const listed = Result.getOrThrow(agentMoves(progress, roster, seat));
      const firstOfEachAction = Arr.dedupeWith(legalChains(progress, seat), (left, right) => actionOf(left) === actionOf(right));

      expect(listed.map(({ chain }) => chain.map(({ index }) => index))).toEqual(firstOfEachAction.map((chain) => chain.map(({ index }) => index)));
      expect(new Set(listed.map(({ label }) => label)).size).toBe(listed.length);
      expect(listed.map(({ label }) => label)).not.toContain("");
      expect(turnViewOf(table, player).moves).toEqual(listed.map(({ label }) => label));

      for (const { chain } of listed) {
        const end = chain.reduce<Progress>((current, { move, index }) => {
          expect(Option.getOrThrow(menuOf(current, seat))[index]).toEqual(move);

          return playIndex(current, seat, index);
        }, progress);

        expect(isMidAction(end, seat)).toBe(false);
        chain.forEach(({ move }) => kinds.add(move._tag));
        checked += 1;
      }
    }
  } });

  expect(checked).toBeGreaterThan(0);
  expect(kinds).toEqual(new Set(["PickUp", "Shoot", "UseItem", "Grab", "Place", "JamTarget", "Steal"]));
}, 120_000);

test("on random tables of 2 to 4 players, an Agent's views on its turns and the final view add up to the whole log in order, with no gaps or repeats and only its own secrets: each starts where its previous turn ended, the first at the match start", () => {
  let secretsShown = 0;
  let turnsRead = 0;
  const heard = new Map<number, Array<string>>();

  const expectWholeLog = (table: HeadlessTable, player: number): void => {
    const { events, learned } = match(table);
    const seat = seatOfPlayer(table, player);
    const own = (count: number) => learned.filter((note) => note.seat === seat && note.at === count).map(({ secret }) => secretText(secret));
    const log = [...own(0), ...events.flatMap((event, index) => [eventText(rosterAt(table), event), ...own(index + 1)])];

    expect(heard.get(player)).toEqual(log);
    secretsShown += learned.filter((note) => note.seat === seat).length;
  };

  playRandomTables(31, 9, {
    onMove: (player, view) => {
      if (!heard.has(player)) expect(view.events?.[0]).toStartWith("Round 1 begins");

      heard.set(player, [...(heard.get(player) ?? []), ...(view.events ?? [])]);
      turnsRead += 1;
    },
    onOver: (table) => {
      for (const player of agentPlayers(table)) {
        heard.set(player, [...(heard.get(player) ?? []), ...(viewOf(table, player).events ?? [])]);
        expectWholeLog(table, player);
      }

      heard.clear();
    },
  });

  expect(turnsRead).toBeGreaterThan(0);
  expect(secretsShown).toBeGreaterThan(0);
}, 60_000);

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
}, 120_000);

test("Agent players that may move at once can answer in either order, and the later one must reread its turn", () => {
  const table = playUntil(newMatch(3, 42, ["Agent", "Agent", "DoN"]), (current) => agentsToMove(current).length === 2);

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

  for (const input of [{ player: 2, move: -1, turn }, { player: 2, move: 1.5, turn }, { player: 2, move: "zero", turn }, { player: 5, move: 0, turn }, { player: 0, move: 0, turn }, { seat: 3, move: 0, turn }, { move: 0, turn }, { player: 2, move: 0 }, { player: 2, move: 0, turn: "1" }, { player: 2, move: 0, turn: -1 }, { player: 2, move: 0, turn: 0.5 }, { player: 2, index: 0, turn }]) {
    const outcome = call(table, "play_move", input);

    expect(refusal(outcome.reply)).toContain("Invalid arguments for play_move");
    expect(outcome.table).toBe(table);
  }
});

test("a move when it is not the player's turn is refused", () => {
  const table = playUntil(newMatch(3, 3, ["Agent", "Agent", "DoN"]), (current) => agentsToMove(current).length === 1);
  const waiting = agentPlayers(table).find((player) => !agentsToMove(table).includes(player)) ?? expect.unreachable("no waiting agent");
  const outcome = play(table, waiting, 0, table.turn);

  expect(refusal(outcome.reply)).toContain("not your turn");
  expect(outcome.table).toBe(table);
});

test("the tools refuse without a match or without an Agent player", () => {
  expect(refusal(getGame(emptyTable, 1))).toContain("new_match");
  expect(refusal(play(emptyTable, 1, 0, 0).reply)).toContain("new_match");

  const botsOnly = newMatch(2, 1, ["DoN", "Story"]);

  expect(isOver(botsOnly)).toBe(true);
  expect(refusal(getGame(botsOnly, 2))).toContain("no player is");
});

test("a repeated move, or one from before a move that kept the player's turn, is refused, not played twice", () => {
  let kept = 0;

  for (const seed of Arr.range(1, 4)) {
    let table = newMatch(2, seed, ["Agent", "DoN"]);

    for (let steps = 0; steps < STEP_LIMIT && !isOver(table); steps++) {
      const { turn, moves } = turnViewOf(table, 1);
      const index = steps % moves.length;
      const once = play(table, 1, index, turn);
      const twice = play(once.table, 1, index, turn);

      expect(refusal(twice.reply)).toMatch(isOver(once.table) ? /new_match|not your turn/ : /Stale|not your turn/);
      expect(twice.table).toBe(once.table);
      kept += parseView(answered(once.reply)).status === "your turn" ? 1 : 0;
      table = once.table;
    }
  }

  expect(kept).toBeGreaterThan(0);
}, 30_000);

test("new_match is refused while a match is in progress, and a turn from the finished match is refused in a rematch with the same seed and setup at the same point", () => {
  const setup = [2, 3, ["Agent", "DoN"], { items: false }] as const;
  const earlier = newMatch(...setup);
  const sixMoves = (start: HeadlessTable) => Arr.range(1, 6).reduce((table) => play(table, 1, 0, turnViewOf(table, 1).turn).table, start);
  const atSix = sixMoves(earlier);
  const { turn: earlierTurn, ...earlierView } = turnViewOf(atSix, 1);
  const refusedRestart = call(atSix, "new_match", { players: 2, items: false });

  expect(refusal(refusedRestart.reply)).toBe("A match is in progress; finish it first.");
  expect(refusedRestart.table).toBe(atSix);

  const finished = playUntil(atSix, () => false);
  const later = sixMoves(newMatch(setup[0], setup[1], setup[2], { ...setup[3], on: finished }));
  const { turn: laterTurn, ...laterView } = turnViewOf(later, 1);

  expect(laterView).toEqual(earlierView);
  expect(laterTurn).toBeGreaterThan(finished.turn);

  const stale = play(later, 1, 0, earlierTurn);

  expect(refusal(stale.reply)).toContain("Stale");
  expect(stale.table).toBe(later);
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

test("new_match makes Player 1 the agent and DoN the others by default, and the seed it returns replays the match, at the edges of the safe integers too", () => {
  const started = call(emptyTable, "new_match", { players: 3, items: true });
  const { players, seed } = parseTable(answered(started.reply));

  expect(players).toEqual([
    { player: 1, controller: "Agent" },
    { player: 2, controller: "DoN" },
    { player: 3, controller: "DoN" },
  ]);
  expect(viewOf(call(emptyTable, "new_match", { players: 3, items: true, seed }).table, 1)).toEqual(viewOf(started.table, 1));

  for (const given of ["0", "-1", "007", "4294967296", "9007199254740991", "-9007199254740991"]) {
    const first = call(emptyTable, "new_match", { players: 2, items: true, seed: given });
    const returned = parseTable(answered(first.reply)).seed;
    const replayed = call(emptyTable, "new_match", { players: 2, items: true, seed: returned });

    expect(returned).toBe(String(Number(given)));
    expect(parseTable(answered(replayed.reply)).seed).toBe(returned);
    expect(viewOf(playUntil(replayed.table, () => false), 1)).toEqual(viewOf(playUntil(first.table, () => false), 1));
  }
}, 30_000);
