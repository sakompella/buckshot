import { Database } from "bun:sqlite";
import crypto from "node:crypto";

import { Option, Schema } from "effect";

import { analyse, decodeVisible, roundStory, ShellTracker } from "./analysis.ts";
import { Blunders, Call, Consistency, Decisions, MatchDetail, MatchSeat, MatchSummary, Mistakes, type PlayerState, SeatRow, SeatsResponse, type Step } from "./api.ts";
import { findBlunders } from "./blunders.ts";
import { mistakesOf } from "./mistakes.ts";
import { openConsistency } from "./consistency.ts";
import { groupBy } from "./page/data.ts";
import page from "./page/index.html";
import { openRegret, type Regret } from "./regret.ts";

// The arena viewer's server: the page, and a read-only JSON API over the arena
// analysis database. It never selects match_seats.provenance_json, which holds
// an account email. DeepSeek is left out entirely: a match with a DeepSeek seat
// is dropped here, so no tab, rating or total sees it.

const NOT_DEEPSEEK = `m.id not in (select x.match_id from match_seats x join entrants y on y.id = x.entrant_id where y.model = 'oc/deepseek-v4.1-flash-free')`;

const SEATS_SQL = `with cs as (select match_id, player, count(*) calls, sum(cost_usd) cost, sum(input_tokens) inp, sum(output_tokens) outp,
     sum(cache_read_tokens) cr, sum(cache_write_tokens) cw, sum(reasoning_tokens) rt,
     sum(latency_ms) lat, sum(status = 'failed') failed,
     sum(case when status = 'failed' then coalesce(cost_usd, 0) else 0 end) fcost, sum(case when status = 'failed' then coalesce(latency_ms, 0) else 0 end) flat,
     sum(case when status != 'failed' then coalesce(cost_usd, 0) else 0 end) rcost, sum(case when status != 'failed' then coalesce(latency_ms, 0) else 0 end) rlat,
     sum(reasoning_tokens > 0 and coalesce(reasoning_text, '') = '') rsHidden, sum(coalesce(reasoning_text, '') != '') rsText,
     sum(json_valid(tool_calls_json) and json_array_length(tool_calls_json) > 1) multiTool
   from calls group by match_id, player),
   ds as (select match_id, player, sum(by_whom = 'agent') moves from decisions group by match_id, player)
   select t.name tournament, m.id matchId, m.name matchName, m.status, m.started_at startedAt, m.seed, m.seed_block_id seedBlock,
     substr(m.code_hash, 1, 8) codeHash, e.model, e.effort, ms.player, ms.position, ms.win_share winShare, ms.cash,
     cs.calls, cs.cost, cs.inp, cs.outp, cs.cr, cs.cw, cs.rt, cs.lat, cs.failed, cs.fcost, cs.flat, cs.rcost, cs.rlat, cs.rsHidden, cs.rsText, cs.multiTool, ds.moves
   from match_seats ms join matches m on m.id = ms.match_id join tournaments t on t.id = m.tournament_id
   join entrants e on e.id = ms.entrant_id
   left join cs on cs.match_id = m.id and cs.player = ms.player
   left join ds on ds.match_id = m.id and ds.player = ms.player
   where m.status in ('completed', 'partial') and ${NOT_DEEPSEEK} order by m.started_at, ms.position`;

const decodeSeatRow = Schema.decodeUnknownSync(SeatRow);

const decodeSummary = Schema.decodeUnknownOption(MatchSummary);

const decodeMatchSeat = Schema.decodeUnknownSync(MatchSeat);

const decodeCall = Schema.decodeUnknownSync(Call);

const decodeCallHourRow = Schema.decodeUnknownSync(Schema.Struct({ matchId: Schema.String, player: Schema.String, hour: Schema.Number, calls: Schema.Number, failed: Schema.Number }));

const DecisionRow = Schema.Struct({
  id: Schema.String,
  ordinal: Schema.Number,
  turn: Schema.Number,
  player: Schema.String,
  byWhom: Schema.Literals(["agent", "fallback", "forced"]),
  label: Schema.String,
  visible: Schema.NullOr(Schema.String),
});

const decodeDecisionRow = Schema.decodeUnknownSync(DecisionRow);

const encodeSeats = Schema.encodeSync(Schema.fromJsonString(SeatsResponse));

const encodeConsistency = Schema.encodeSync(Schema.fromJsonString(Schema.Array(Consistency)));

const encodeDecisions = Schema.encodeSync(Schema.fromJsonString(Decisions));

const encodeBlunders = Schema.encodeSync(Schema.fromJsonString(Blunders));

const encodeMistakes = Schema.encodeSync(Schema.fromJsonString(Mistakes));

const encodeMatch = Schema.encodeSync(Schema.fromJsonString(MatchDetail));

// A move's outcome is the start of its player's next window, up to the first line by someone else or a new round, distribution or load.
const isOutcomeEnd = (text: string, player: string): boolean =>
  (text.startsWith("Player ") && !text.startsWith(`Player ${player} `)) || /^(Round \d+ begins|Item distribution|The shotgun is loaded)/.test(text);

interface StepDraft {
  readonly step: Omit<Step, "outcome" | "calls">;
  readonly events: ReadonlyArray<string>;
  readonly previous: number | undefined;
  readonly outcome: Array<string>;
  readonly calls: Array<Call>;
}

const matchDetail = (db: Database, regret: Regret | null, id: string): MatchDetail | null => {
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

  // Each player's view is the concatenation of its own decisions' event windows, so shells and rounds are tracked per player.
  const trackers = new Map<string, ShellTracker>();
  const lastOf = new Map<string, number>();
  const roundOf = new Map<string, number>();
  const healthOf = new Map<string, number>();

  const drafts = db
    .query(`select id, ordinal, turn, player, by_whom byWhom, label, visible_json visible from decisions where match_id = ? order by ordinal`)
    .all(id)
    .map((raw, index): StepDraft => {
      const row = decodeDecisionRow(raw);
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

      const { visible: _visible, ...decision } = row;

      return {
        step: {
          ...decision,
          round: roundOf.get(row.player) ?? 1,
          players,
          live: tracker.live,
          blank: tracker.blank,
          known: chamber !== null && (chamber.by === "glass" || chamber.by === "phone") ? chamber.known : null,
          regret: regretOf?.get(row.ordinal) ?? null,
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
export const serveArenaViewer = (dbPath: string, hostname: string, port: number, regretPath?: string, knowledgePath?: string) => {
  const db = new Database(dbPath, { readonly: true });
  const regret = regretPath === undefined ? null : openRegret(regretPath);
  const started = performance.now();

  const rows = db
    .query(SEATS_SQL)
    .all()
    .map((row) => decodeSeatRow(row));

  const seatIndex = new Map(rows.map((row, index) => [`${row.matchId}|${row.player}`, index]));
  const { decisions, seats: analysed, shellsLeft } = analyse(db, rows, seatIndex);

  const callHours = groupBy(
    db
      .query(`select match_id matchId, player, cast(strftime('%s', t) / 3600 as integer) hour, count(*) calls, sum(status = 'failed') failed from calls group by match_id, player, hour order by hour`)
      .all()
      .map((row) => decodeCallHourRow(row)),
    ({ matchId, player }) => `${matchId}|${player}`,
  );

  const seats = rows.flatMap((row, index) => {
    const extra = analysed[index];
    const key = `${row.matchId}|${row.player}`;

    return extra === undefined ? [] : [{ ...row, ...extra, regret: regret?.seats.get(key) ?? null, callHours: (callHours.get(key) ?? []).map(({ hour, calls, failed }) => [hour, calls, failed] as const) }];
  });

  const seatsBody = encodedBody(encodeSeats(seats));
  const decisionsBody = encodedBody(encodeDecisions(decisions));
  const blundersBody = encodedBody(encodeBlunders(findBlunders(db, regret, seatIndex)));

  const mistakesBody = encodedBody(
    encodeMistakes(
      regret === null
        ? { seat: [], left: [], isShot: [], points: [] }
        : mistakesOf(decisions, shellsLeft, (seat) => rows[seat]?.matchId ?? "", (matchId) => regret.moves(matchId)),
    ),
  );

  const seedBlocks = new Map(seats.map(({ matchId, seedBlock }) => [matchId, seedBlock]));
  const consistencyBody = encodedBody(encodeConsistency(knowledgePath === undefined ? [] : openConsistency(knowledgePath, seedBlocks)));

  console.log(`loaded ${seats.length} seats in ${Math.round(performance.now() - started)} ms; decisions payload ${(decisionsBody.gzipped.length / 1e6).toFixed(1)} MB gzipped`);

  return Bun.serve({
    hostname,
    port,
    development: false,
    routes: {
      "/": page,
      "/api/seats": guarded((request) => json(request, seatsBody)),
      "/api/db": guarded(() => {
        const download = process.env["ARENA_VIEWER_DOWNLOAD"];

        return download === undefined || download === ""
          ? new Response("no download configured", { status: 404 })
          : new Response(Bun.file(download), { headers: { "content-disposition": 'attachment; filename="buckshot.sqlite"' } });
      }),
      "/api/decisions": guarded((request) => json(request, decisionsBody)),
      "/api/blunders": guarded((request) => json(request, blundersBody)),
      "/api/mistakes": guarded((request) => json(request, mistakesBody)),
      "/api/consistency": guarded((request) => json(request, consistencyBody)),
      "/api/match": guarded((request) => {
        const detail = matchDetail(db, regret, new URL(request.url).searchParams.get("id") ?? "");

        return detail === null ? new Response("not found", { status: 404 }) : new Response(encodeMatch(detail), { headers: JSON_TYPE });
      }),
    },
  });
};
