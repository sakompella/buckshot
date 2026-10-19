import { Option, Result, Schema } from "effect";

import { emptyTable, type HeadlessTable } from "../agent/headless.ts";
import { type AgentCall, AgentReply, type MatchSession, replyText, runTool, tools } from "../agent/tools.ts";
import { agentGame, type AgentSource } from "../agent/view.ts";
import { letteredSession, type RunManifest } from "../arena/match.ts";
import type { MoveLine } from "../arena/runlog.ts";
import { Counter, seatsOut } from "../domain.ts";
import { rosterOf } from "../players.ts";
import { eventText, itemName, secretText } from "../text.ts";
import type { Frame, PlayerAt } from "./api.ts";

// A spectator's replay of a run: the match started from the manifest's seed,
// controllers and letters, as src/arena/match.ts starts it, then each logged
// move played in order through the rules machine. Health, items and the gun
// come from the machine, never from the log's text (ADR-0001).

/** What a replay starts from. */
export type ReplaySetup = Pick<RunManifest, "seed" | "controllers" | "letters">;

export interface Replay {
  readonly setup: ReplaySetup;
  readonly session: MatchSession<HeadlessTable>;
  readonly table: HeadlessTable;
  readonly applied: ReadonlyArray<MoveLine>;
  readonly frames: ReadonlyArray<Frame>;
  /** Set when a logged move does not replay; the replay stops there. */
  readonly divergence: Option.Option<string>;
}

const callOf = (name: (typeof tools)[number]["name"], input: Schema.Json): Result.Result<AgentCall, string> =>
  Result.flatMap(Result.fromNullishOr(tools.find((tool) => tool.name === name), () => `no tool ${name}`), (tool) => tool.decodeCall(input));

/** Runs one call; a refusal is the reason it gives. */
const run = (session: MatchSession<HeadlessTable>, table: HeadlessTable, call: AgentCall): Result.Result<HeadlessTable, string> => {
  const outcome = runTool(session, table, call);

  return AgentReply.guards.Refused(outcome.reply) ? Result.fail(replyText(outcome.reply)) : Result.succeed(outcome.state);
};

const sourceOf = (replay: Pick<Replay, "session" | "table">): AgentSource => Option.getOrThrow(replay.session.current(replay.table));

/** The frame `after` leaves, with the log entries made since `before`: each event, then the secrets heard at it, as a player's log orders them. */
const frameOf = (before: AgentSource | undefined, after: AgentSource, move: Frame["move"]): Frame => {
  const roster = rosterOf(after.game.seats, after.letters);
  const { board } = after.game;
  const firstEvent = before?.events.length ?? 0;
  const secrets = after.learned.slice(before?.learned.length ?? 0);
  const heardAt = (at: number) => secrets.flatMap((note) => (note.at === at ? [{ text: secretText(note.secret), heardBy: roster.playerOf(note.seat).letter }] : []));
  const out = seatsOut(after.events);

  const frame: Frame = {
    round: board.round.index + 1,
    roundHealth: board.round.health,
    entries: [...heardAt(firstEvent), ...after.events.slice(firstEvent).flatMap((event, index) => [{ text: eventText(roster, event) }, ...heardAt(firstEvent + index + 1)])],
    players: board.seats.map((view) => ({
      player: roster.playerOf(view.seat).letter,
      health: Counter.match(view.counter, { Unjammed: ({ health }): PlayerAt["health"] => health, Jammed: (): PlayerAt["health"] => "jammed" }),
      items: view.slots.flatMap(Option.match({ onNone: () => [], onSome: (item) => [itemName(item)] })),
      cash: view.cash,
      out: out.has(view.seat),
    })),
    gun: { live: board.gun.shown.live, blank: board.gun.shown.blank, remaining: board.gun.remaining, sawed: board.gun.sawed },
  };

  return move === undefined ? frame : { ...frame, move };
};

/** The label the machine gives a move now: what match.ts logged as the move's label when it was played. */
const labelOf = (replay: Replay, line: MoveLine): string =>
  Result.match(agentGame(sourceOf(replay), replay.session.turn(replay.table), line.player), {
    onSuccess: (game) => (game.status === "your turn" ? (game.moves[line.move]?.label ?? "") : ""),
    onFailure: () => "",
  });

const diverged = (replay: Replay, note: string): Replay => ({ ...replay, divergence: Option.some(note) });

const playLine = (replay: Replay, line: MoveLine): Replay => {
  const replayed = labelOf(replay, line);

  if (replayed !== line.label) return diverged(replay, `turn ${line.turn}: logged "${line.label}", replayed "${replayed}"`);

  return Result.match(
    Result.flatMap(callOf("play_move", { player: line.player, move: line.move, turn: line.turn }), (call) => run(replay.session, replay.table, call)),
    {
      onFailure: (reason) => diverged(replay, `turn ${line.turn}: logged "${line.label}", refused: ${reason}`),
      onSuccess: (table) => ({
        ...replay,
        table,
        applied: [...replay.applied, line],
        frames: [...replay.frames, frameOf(sourceOf(replay), sourceOf({ session: replay.session, table }), { turn: line.turn, player: line.player, label: line.label, by: line.by })],
      }),
    },
  );
};

/** A replay at the start of the match, or why the run cannot start one. */
const startReplay = (setup: ReplaySetup): Result.Result<Replay, string> => {
  const session = letteredSession(setup.letters);

  return Result.map(
    Result.flatMap(callOf("new_match", { players: setup.controllers.length, items: true, seed: setup.seed, controllers: [...setup.controllers] }), (call) => run(session, emptyTable, call)),
    (table) => ({ setup, session, table, applied: [], frames: [frameOf(undefined, sourceOf({ session, table }), undefined)], divergence: Option.none() }),
  );
};

const sameMove = (left: MoveLine, right: MoveLine | undefined): boolean =>
  right !== undefined && left.turn === right.turn && left.player === right.player && left.move === right.move && left.label === right.label && left.by === right.by;

const sameSetup = (left: ReplaySetup, right: ReplaySetup): boolean => JSON.stringify([left.seed, left.controllers, left.letters]) === JSON.stringify([right.seed, right.controllers, right.letters]);

/**
 * The replay of `moves`, a run's move lines in file order. It extends `previous` when that replayed a prefix of
 * them, as it does while a match is live, since moves are only appended; otherwise it starts over.
 */
export const replayOf = (previous: Option.Option<Replay>, setup: ReplaySetup, moves: ReadonlyArray<MoveLine>): Result.Result<Replay, string> => {
  const extendable = Option.filter(previous, (replay) => sameSetup(replay.setup, setup) && replay.applied.every((line, index) => sameMove(line, moves[index])));

  return Result.map(Option.match(extendable, { onSome: Result.succeed, onNone: () => startReplay(setup) }), (start) => {
    let replay = start;

    for (const line of moves.slice(replay.applied.length)) {
      if (Option.isSome(replay.divergence)) break;

      replay = playLine(replay, line);
    }

    return replay;
  });
};
