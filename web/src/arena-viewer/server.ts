import type { Database } from "bun:sqlite";
import crypto from "node:crypto";
import { join, normalize } from "node:path";

import { Array as Arr, Option, Result, Schema } from "effect";

import { agentMoves } from "../agent/moves.ts";
import { replayOf } from "../arena/replay.ts";
import type { TableMove } from "../board.ts";
import { seatsOut } from "../domain.ts";
import { Controller } from "../driver.ts";
import { Letter, rosterOf } from "../players.ts";
import { AGGREGATE_NAMES, aggregatesOf, encodeAggregates } from "./aggregates.ts";
import { decodeVisible, roundStory, ShellTracker, shotLineIn } from "./analysis.ts";
import { Blunders, Call, CertainMistakes, Decisions, type MatchDetail, MatchDetailJson, MatchSeat, MatchSummary, type PlayerState, SeatsResponse, type Step, type TablePosition } from "./api.ts";
import { findBlunders } from "./blunders.ts";
import type { Certain } from "./certain.ts";
import { type ArenaPaths, loadArena, NOT_DEEPSEEK } from "./load.ts";
import { withPotShares } from "./page/data.ts";
import type { Regret } from "./regret.ts";

// The arena viewer's server: the built site (web/dist), and a read-only JSON API over the arena analysis database
// as load.ts reads it.

const decodeSummary = Schema.decodeUnknownOption(MatchSummary);

const decodeMatchSeat = Schema.decodeUnknownSync(MatchSeat);

const decodeCall = Schema.decodeUnknownSync(Call);

const DecisionRow = Schema.Struct({
  id: Schema.String,
  ordinal: Schema.Number,
  turn: Schema.Number,
  player: Letter,
  byWhom: Schema.Literals(["agent", "human", "engine", "fallback", "forced"]),
  label: Schema.String,
  move: Schema.Number,
  visible: Schema.NullOr(Schema.String),
});

type DecisionRow = typeof DecisionRow.Type;

const decodeDecisionRow = Schema.decodeUnknownSync(DecisionRow);

const encodeSeats = Schema.encodeSync(Schema.fromJsonString(SeatsResponse));

const encodeDecisions = Schema.encodeSync(Schema.fromJsonString(Decisions));

const encodeBlunders = Schema.encodeSync(Schema.fromJsonString(Blunders));

const encodeCertain = Schema.encodeSync(Schema.fromJsonString(CertainMistakes));

const encodeMatch = Schema.encodeSync(Schema.fromJsonString(MatchDetailJson));

// A move's outcome is the start of its player's next window, up to the first line by someone else or a new round, distribution or load.
const isOutcomeEnd = (text: string, player: string): boolean =>
  (text.startsWith("Player ") && !text.startsWith(`Player ${player} `)) || /^(Round \d+ begins|Item distribution|The shotgun is loaded)/.test(text);

/** What a replay needs of a match's manifest. */
const ReplayManifest = Schema.fromJsonString(Schema.Struct({ seed: Schema.String, controllers: Schema.Array(Controller), letters: Schema.Array(Letter) }));

const decodeReplayManifest = Schema.decodeUnknownOption(ReplayManifest);

/** Each decision's table, from the match replayed through the rules; none from where it stops replaying. */
const tablesOf = (manifest: string | null, decisions: ReadonlyArray<DecisionRow>): ReadonlyArray<TablePosition> =>
  Option.match(decodeReplayManifest(manifest), {
    onNone: () => [],
    onSome: (setup) =>
      Result.match(replayOf(Option.none(), setup, decisions.map(({ turn, player, move, label, byWhom }) => ({ turn, player, move, label, by: byWhom }))), {
        onFailure: () => [],
        onSuccess: (replay) =>
          replay.applied.flatMap((line, index) => {
            const source = replay.frames[index]?.source;

            if (source === undefined) return [];

            const roster = rosterOf(source.game.seats, source.letters);

            return Option.match(roster.find(line.player), {
              onNone: () => [],
              onSome: ({ seat }) =>
                Result.match(agentMoves(source, roster, seat), {
                  onFailure: () => [],
                  onSuccess: (moves) => [
                    {
                      board: source.game.board,
                      out: [...seatsOut(source.events)],
                      moves: moves.map(({ label, chain }): TableMove => ({ seat, steps: Arr.map(chain, ({ move }) => move), label })),
                      chosen: line.move,
                    },
                  ],
                }),
            });
          }),
      }),
  });

interface StepDraft {
  readonly step: Omit<Step, "outcome" | "calls">;
  readonly events: ReadonlyArray<string>;
  readonly previous: number | undefined;
  readonly outcome: Array<string>;
  readonly calls: Array<Call>;
}

const matchDetail = (db: Database, regret: Regret | null, certain: Certain, id: string): MatchDetail | null => {
  const match = decodeSummary(
    db
      .query(`select m.id, m.name, m.status, m.seed, m.started_at startedAt, m.ended_at endedAt, t.name tournament from matches m join tournaments t on t.id = m.tournament_id where m.id = ? and ${NOT_DEEPSEEK}`)
      .get(id),
  );

  if (Option.isNone(match)) return null;

  const seats = db
    .query(`select ms.player, ms.position, ms.cash, ms.win_share winShare, e.model, e.effort from match_seats ms join entrants e on e.id = ms.entrant_id where match_id = ? order by position`)
    .all(id)
    .map((row) => decodeMatchSeat(row));

  const regretOf = regret?.moves(id);
  const certainOf = certain.moves(id);

  // Each player's view is the concatenation of its own decisions' event windows, so shells and rounds are tracked per player.
  const trackers = new Map<string, ShellTracker>();
  const lastOf = new Map<string, number>();
  const roundOf = new Map<string, number>();
  const healthOf = new Map<string, number>();

  const rows = db
    .query(`select id, ordinal, turn, player, by_whom byWhom, label, selected_move move, visible_json visible from decisions where match_id = ? order by ordinal`)
    .all(id)
    .map((raw) => decodeDecisionRow(raw));

  const manifest = db.query<{ manifest: string | null }, [string]>(`select manifest_json manifest from matches where id = ?`).get(id)?.manifest ?? null;
  const tables = tablesOf(manifest, rows);

  const drafts = rows.map((row, index): StepDraft => {
      const visible = row.visible === null ? null : decodeVisible(row.visible);
      const events = visible?.events ?? [];
      const tracker = trackers.get(row.player) ?? new ShellTracker();
      const previous = lastOf.get(row.player);

      trackers.set(row.player, tracker);
      lastOf.set(row.player, index);

      for (const text of events) {
        tracker.event(text);
        const round = /^Round (\d+) begins/.exec(text);

        if (round) roundOf.set(row.player, Number(round[1]));
      }

      const chamber = tracker.chamber();

      const players = (visible?.players ?? []).map((seen): PlayerState => {
        const health = seen.health ?? healthOf.get(seen.player) ?? 0;

        healthOf.set(seen.player, health);

        return { player: seen.player, health, items: seen.items ?? [] };
      });

      const { visible: _visible, move: _move, ...decision } = row;

      return {
        step: {
          ...decision,
          round: roundOf.get(row.player) ?? 1,
          players,
          live: tracker.live,
          blank: tracker.blank,
          known: chamber !== null && (chamber.by === "glass" || chamber.by === "phone") ? chamber.known : null,
          regret: regretOf?.get(row.ordinal) ?? null,
          certain: certainOf.get(row.ordinal) ?? null,
          table: tables[index] ?? null,
        },
        events,
        previous,
        outcome: [],
        calls: [],
      };
    });

  for (const draft of drafts) {
    const before = draft.previous === undefined ? undefined : drafts[draft.previous];

    if (before === undefined) continue;

    const end = draft.events.findIndex((text) => isOutcomeEnd(text, before.step.player));

    before.outcome.push(...(end === -1 ? draft.events : draft.events.slice(0, end)).filter((text) => !text.endsWith(" picked up the shotgun.")));
  }

  drafts.forEach((draft, index) => {
    if (draft.outcome.length > 0 || !draft.step.label.startsWith("Shoot")) return;

    const line = shotLineIn(
      draft.step.player,
      drafts.slice(index + 1).map(({ step, events }) => ({ player: step.player, events })),
    );

    if (line !== undefined) draft.outcome.push(line);
  });

  const byId = new Map(drafts.map((draft) => [draft.step.id, draft]));
  const unlinked: Array<Call> = [];

  const calls = db.query(
    `select decision_id decisionId, player, t, status, error, latency_ms latency, input_tokens inp, output_tokens outp,
       cache_read_tokens cr, cache_write_tokens cw, reasoning_tokens rt, cost_usd cost,
       reasoning_text reasoning, response_text response, tool_calls_json tools
     from calls where match_id = ? order by ordinal`,
  );

  for (const raw of calls.all(id)) {
    const call = decodeCall(raw);
    const draft = call.decisionId === null ? undefined : byId.get(call.decisionId);

    (draft?.calls ?? unlinked).push(call);
  }

  // One player's windows in order are its whole view; mixing both players' windows misorders round lines.
  const first = seats[0]?.player;

  const story = roundStory(
    drafts.filter(({ step }) => step.player === first).flatMap(({ events }) => events),
    new Map(seats.map((seat) => [seat.player, seat.cash ?? 0])),
  );

  return { match: match.value, seats, decisions: drafts.map(({ step, outcome, calls: linked }) => ({ ...step, outcome, calls: linked })), unlinked, story };
};

/** Replaying a match through the rules takes up to seconds, so the server keeps the latest few it sent. */
const RECENT_MATCHES = 32;

const JSON_TYPE = { "content-type": "application/json" };

const encodedBody = (body: string) => ({ body, gzipped: Bun.gzipSync(new TextEncoder().encode(body)) });

const json = (request: Request, { body, gzipped }: ReturnType<typeof encodedBody>) =>
  /\bgzip\b/.test(request.headers.get("accept-encoding") ?? "")
    ? new Response(gzipped, { headers: { ...JSON_TYPE, "content-encoding": "gzip", vary: "accept-encoding" } })
    : new Response(body, { headers: { ...JSON_TYPE, vary: "accept-encoding" } });

const digest = (text: string) => new Bun.CryptoHasher("sha256").update(text).digest();

/**
 * With ARENA_VIEWER_PASSWORD set, the API asks for it through the browser's basic-auth prompt; the username is ignored.
 * The page shell itself holds no data.
 */
const guarded = (handler: (request: Request) => Response) => {
  const password = process.env["ARENA_VIEWER_PASSWORD"];

  if (password === undefined || password === "") return handler;

  const expected = digest(password);

  return (request: Request) => {
    const given = Buffer.from((request.headers.get("authorization") ?? "").replace(/^Basic /, ""), "base64").toString().replace(/^[^:]*:/, "");

    return crypto.timingSafeEqual(digest(given), expected)
      ? handler(request)
      : new Response("password required", { status: 401, headers: { "www-authenticate": 'Basic realm="Buckshot arena"' } });
  };
};

/**
 * Loads and analyses the database once, then serves the page and the API. With a regret database, seats and moves carry their regret.
 * With a knowledge database, the page shows how consistent each config is.
 */
/** A file of the built site when the path names one; any other path gets the page, which routes itself. */
const COMPRESSIBLE = /\.(js|css|svg)$/;

const gzippedAssets = new Map<string, Uint8Array<ArrayBuffer>>();

/** A hashed script or stylesheet, gzipped once when asked for; the others are sent as they are. */
const assetResponse = async (pathname: string, file: ReturnType<typeof Bun.file>, request: Request): Promise<Response> => {
  const headers = { "cache-control": "public, max-age=31536000, immutable" };

  if (!COMPRESSIBLE.test(pathname) || !/\bgzip\b/.test(request.headers.get("accept-encoding") ?? "")) return new Response(file, { headers });

  const gzipped = gzippedAssets.get(pathname) ?? Bun.gzipSync(await file.bytes());

  gzippedAssets.set(pathname, gzipped);

  return new Response(gzipped, { headers: { ...headers, "content-type": file.type, "content-encoding": "gzip", vary: "accept-encoding" } });
};

const siteResponse = async (siteDir: string, request: Request): Promise<Response> => {
  const { pathname } = new URL(request.url);
  const file = Bun.file(join(siteDir, normalize(decodeURIComponent(pathname))));

  if (pathname !== "/" && (await file.exists())) return pathname.startsWith("/assets/") ? assetResponse(pathname, file, request) : new Response(file);

  return new Response(Bun.file(join(siteDir, "index.html")), { headers: { "content-type": "text/html; charset=utf-8" } });
};

export const serveArenaViewer = (dbPath: string, siteDir: string, hostname: string, port: number, paths: ArenaPaths = {}) => {
  const started = performance.now();
  const { db, regret, seats, seatIndex, decisions, certain, consistency, luck } = loadArena(dbPath, paths);
  const aggregateJson = encodeAggregates(aggregatesOf({ seats: withPotShares(seats), decisions, certain: certain.summary.rates, consistency, luck }));
  const aggregateRoutes = Object.fromEntries(AGGREGATE_NAMES.map((name) => [`/api/agg/${name}`, guarded((request) => json(request, encodedBody(aggregateJson[name])))]));

  const seatsBody = encodedBody(encodeSeats(seats));
  const recentMatches = new Map<string, ReturnType<typeof encodedBody>>();
  const decisionsBody = encodedBody(encodeDecisions(decisions));
  const blundersBody = encodedBody(encodeBlunders(findBlunders(db, regret, seatIndex)));
  const certainBody = encodedBody(encodeCertain(certain.summary));

  console.log(`loaded ${seats.length} seats in ${Math.round(performance.now() - started)} ms; decisions payload ${(decisionsBody.gzipped.length / 1e6).toFixed(1)} MB gzipped`);

  return Bun.serve({
    hostname,
    port,
    // With routes, Bun otherwise shares the port with a viewer already on it and splits requests between the two.
    reusePort: false,
    development: false,
    fetch: (request) => siteResponse(siteDir, request),
    routes: {
      "/api/*": () => new Response("not found", { status: 404 }),
      "/api/seats": guarded((request) => json(request, seatsBody)),
      "/api/download": guarded(() => {
        const download = process.env["ARENA_VIEWER_DOWNLOAD"];

        return download === undefined || download === "" ? new Response("no download configured", { status: 404 }) : Response.json({ bytes: Bun.file(download).size });
      }),
      "/api/db": guarded(() => {
        const download = process.env["ARENA_VIEWER_DOWNLOAD"];

        return download === undefined || download === ""
          ? new Response("no download configured", { status: 404 })
          : new Response(Bun.file(download), { headers: { "content-disposition": 'attachment; filename="buckshot.sqlite"' } });
      }),
      "/api/decisions": guarded((request) => json(request, decisionsBody)),
      "/api/blunders": guarded((request) => json(request, blundersBody)),
      ...aggregateRoutes,
      "/api/certain-mistakes": guarded((request) => json(request, certainBody)),
      "/api/match": guarded((request) => {
        const id = new URL(request.url).searchParams.get("id") ?? "";
        const body = Option.orElse(Option.fromUndefinedOr(recentMatches.get(id)), () => Option.map(Option.fromNullOr(matchDetail(db, regret, certain, id)), (detail) => encodedBody(encodeMatch(detail))));

        if (Option.isSome(body)) {
          recentMatches.delete(id);
          recentMatches.set(id, body.value);

          for (const old of [...recentMatches.keys()].slice(0, Math.max(0, recentMatches.size - RECENT_MATCHES))) recentMatches.delete(old);
        }

        return Option.match(body, { onNone: () => new Response("not found", { status: 404 }), onSome: (found) => json(request, found) });
      }),
    },
  });
};
