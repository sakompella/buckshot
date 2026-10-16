import { existsSync } from "node:fs";
import { join } from "node:path";

import { Option, Result, Schema } from "effect";

import { costOf, DEFAULT_PRICES, loadPrices, type PriceTable, totalOf, totalsBy } from "../arena/cost.ts";
import { effortRank, modelName } from "../arena/model-names.ts";
import type { CallLine } from "../arena/runlog.ts";
import { finishedNames, readTournamentFile, type TournamentFile, tournamentOf } from "../arena/tournament-dir.ts";
import { reportOf } from "../arena/tournament-report.ts";
import { modelEntrant } from "../arena/tournament.ts";
import { Cursors, type JsonlLine, LeaderboardResponse, MatchResponse, type PricedCall, RunsResponse } from "./api.ts";
import page from "./page/index.html";
import { type Replay, replayOf } from "./replay.ts";
import { callsOf, movesOf, type RunRead, readRun, readRuns } from "./runs.ts";

// The viewer's server: the page, and a read-only JSON API over a directory of
// arena runs. Polls carry cursors, the counts of lines and frames the page
// already has, so the server keeps nothing per page and a reconnect just works.
// Prices are read on every request, so an edit to prices.json shows at once.

const encodeRuns = Schema.encodeSync(Schema.fromJsonString(RunsResponse));

const encodeMatch = Schema.encodeSync(Schema.fromJsonString(MatchResponse));

const Count = Schema.NumberFromString.check(Schema.isInt(), Schema.isGreaterThanOrEqualTo(0));

const decodeCursors = Schema.decodeUnknownOption(Schema.Struct({ calls: Count, events: Count, frames: Count }));

const json = (body: string) => new Response(body, { headers: { "content-type": "application/json" } });

const encodeLeaderboard = Schema.encodeSync(Schema.fromJsonString(LeaderboardResponse));

const hasTournament = (runsDir: string) => existsSync(join(runsDir, "tournament.json"));

const byModelThenEffort = (left: { readonly model: string; readonly effort?: string | undefined }, right: { readonly model: string; readonly effort?: string | undefined }) =>
  modelName(left.model).localeCompare(modelName(right.model)) || effortRank(left.effort) - effortRank(right.effort);

const groupedBy = <A, K>(items: ReadonlyArray<A>, key: (item: A) => K): ReadonlyMap<K, ReadonlyArray<A>> => {
  const groups = new Map<K, Array<A>>();

  for (const item of items) groups.set(key(item), [...(groups.get(key(item)) ?? []), item]);

  return groups;
};

/** What the calls of each model cost, and of each model at each effort. A call's effort is its agent's in the run. */
const totalsOf = (readable: ReadonlyArray<RunRead>, prices: PriceTable) => {
  const tagged = readable.flatMap((run) => callsOf(run).map((call) => ({ call, effort: run.summary.agents.find((agent) => agent.agent === call.agent)?.effort })));
  const byModel = [...groupedBy(tagged, ({ call }) => call.model)];

  return {
    byModel: byModel.map(([model, group]) => ({ model, total: totalOf(prices, group.map(({ call }) => call)) })).toSorted(byModelThenEffort),
    byEffort: byModel
      .flatMap(([model, group]) => [...groupedBy(group, ({ effort }) => effort ?? "")].map(([effort, calls]) => ({ model, effort: effort === "" ? undefined : effort, total: totalOf(prices, calls.map(({ call }) => call)) })))
      .toSorted(byModelThenEffort),
  };
};

const runsResponse = (runsDir: string, prices: PriceTable) => {
  const runs = readRuns(runsDir, new Date());
  const readable = runs.flatMap((run) => (Result.isSuccess(run) ? [run.success] : [])).toSorted((left, right) => right.summary.started.localeCompare(left.summary.started));

  return encodeRuns({
    runs: [...readable.map((run) => ({ ...run.summary, cost: totalOf(prices, callsOf(run)) })), ...runs.flatMap((run) => (Result.isFailure(run) ? [run.failure] : []))],
    leaderboard: hasTournament(runsDir),
    totals: totalsOf(readable, prices),
  });
};

/** The tournament's report, as the leaderboard lists it, or why there is none. It bootstraps over seeds, which takes seconds, so one is kept until a match finishes or the prices change. */
const leaderboardOf = (runsDir: string, file: TournamentFile, prices: PriceTable): Result.Result<LeaderboardResponse, string> =>
  Result.gen(function* () {
    const tournament = yield* Result.mapError(tournamentOf(file), ({ message }) => message);
    const report = reportOf(runsDir, file, tournament, prices);
    const zero = totalOf(prices, []);

    return {
      name: report.name,
      seeds: report.seeds,
      matches: report.matches,
      anchor: report.anchor,
      notes: report.notes,
      rows: report.entrants.map((row) => {
        const entrant = modelEntrant(tournament.config, row.entrant);
        const interventions = report.interventions.find((counts) => counts.entrant === row.entrant);

        return {
          entrant: row.entrant,
          model: entrant?.model ?? row.entrant,
          effort: entrant?.effort,
          matches: row.matches,
          wins: row.wins,
          share: row.share,
          shareInterval: row.shareInterval,
          rating: row.rating,
          ratingInterval: row.ratingInterval,
          moves: interventions?.moves ?? 0,
          interventions: interventions?.interventions ?? 0,
          cost: report.cost.find((cost) => cost.entrant === row.entrant) ?? zero,
        };
      }),
    };
  });

const priced = (prices: PriceTable) => (line: JsonlLine<CallLine>): JsonlLine<PricedCall> => {
  if (line.kind === "unreadable") return line;

  const dollars = costOf(prices, line.value);

  return { ...line, value: dollars === undefined ? { call: line.value } : { call: line.value, dollars } };
};

const matchResponse = (run: RunRead, replay: Result.Result<Replay, string>, cursors: Cursors, prices: PriceTable) => {
  const calls = callsOf(run);
  const frames = Result.match(replay, { onSuccess: ({ frames }) => frames, onFailure: () => [] });
  const divergence = Result.match(replay, { onSuccess: ({ divergence }) => Option.getOrUndefined(divergence), onFailure: (reason) => `cannot replay: ${reason}` });

  const response: MatchResponse = {
    run: run.summary,
    calls: run.calls.slice(cursors.calls).map(priced(prices)),
    events: run.events.slice(cursors.events),
    frames: frames.slice(cursors.frames),
    agents: [...totalsBy(prices, calls.map((call) => [call.agent, call]))].map(([agent, total]) => ({
      agent,
      total,
      latencyMs: calls.reduce((sum, call) => sum + (call.agent === agent ? (call.latency_ms ?? 0) : 0), 0),
    })),
    cursors: { calls: run.calls.length, events: run.events.length, frames: frames.length },
  };

  return encodeMatch(divergence === undefined ? response : { ...response, divergence });
};

/** Serves the viewer for the runs in `runsDir`, on 127.0.0.1 only. */
export const serveViewer = (runsDir: string, port: number) => {
  /** By run id: the latest replay, extended as a live run's moves arrive. */
  const replays = new Map<string, Replay>();
  let leaderboard: { readonly key: string; readonly result: Result.Result<LeaderboardResponse, string> } | undefined;

  const leaderboardRoute = () => {
    const prices = loadPrices(DEFAULT_PRICES);

    return Result.match(readTournamentFile(runsDir), {
      onFailure: ({ message }) => new Response(message, { status: 404 }),
      onSuccess: (file) => {
        const key = `${finishedNames(runsDir, file.schedule).size} ${file.schedule.length} ${JSON.stringify(prices)}`;

        if (leaderboard?.key !== key) leaderboard = { key, result: leaderboardOf(runsDir, file, prices) };

        return Result.match(leaderboard.result, { onFailure: (message) => new Response(message, { status: 404 }), onSuccess: (response) => json(encodeLeaderboard(response)) });
      },
    });
  };

  return Bun.serve({
    hostname: "127.0.0.1",
    port,
    development: false,
    routes: {
      "/": page,
      "/match/:id": page,
      "/leaderboard": page,
      "/api/leaderboard": leaderboardRoute,
      "/api/runs": () => json(runsResponse(runsDir, loadPrices(DEFAULT_PRICES))),
      "/api/runs/:id": (request) => {
        const query = new URL(request.url).searchParams;
        const cursors = decodeCursors({ calls: query.get("calls") ?? "0", events: query.get("events") ?? "0", frames: query.get("frames") ?? "0" });

        if (Option.isNone(cursors)) return new Response("calls, events and frames must be counts", { status: 400 });

        return Option.match(readRun(runsDir, request.params.id, new Date()), {
          onNone: () => new Response("no such run", { status: 404 }),
          onSome: Result.match({
            onFailure: ({ reason }) => new Response(reason, { status: 404 }),
            onSuccess: (run) => {
              const replay = replayOf(Option.fromUndefinedOr(replays.get(run.id)), run.manifest, movesOf(run.events));

              if (Result.isSuccess(replay)) replays.set(run.id, replay.success);

              return json(matchResponse(run, replay, cursors.value, loadPrices(DEFAULT_PRICES)));
            },
          }),
        });
      },
    },
    fetch: () => new Response("not found", { status: 404 }),
  });
};
