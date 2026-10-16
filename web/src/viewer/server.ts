import { Option, Result, Schema } from "effect";

import { costOf, DEFAULT_PRICES, EMPTY, loadPrices, type PriceTable, type Total, totalsBy } from "../arena/cost.ts";
import type { CallLine } from "../arena/runlog.ts";
import { Cursors, type JsonlLine, MatchResponse, type PricedCall, RunsResponse } from "./api.ts";
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

const labelled = (totals: ReadonlyMap<string, Total>) => [...totals].map(([label, total]) => ({ label, total }));

const runsResponse = (runsDir: string, prices: PriceTable) => {
  const runs = readRuns(runsDir, new Date());
  const readable = runs.flatMap((run) => (Result.isSuccess(run) ? [run.success] : [])).toSorted((left, right) => right.summary.started.localeCompare(left.summary.started));
  const calls = readable.flatMap(callsOf);

  return encodeRuns({
    runs: [...readable.map((run) => ({ ...run.summary, cost: totalsBy(prices, callsOf(run).map((call) => [run.id, call])).get(run.id) ?? EMPTY })), ...runs.flatMap((run) => (Result.isFailure(run) ? [run.failure] : []))],
    totals: {
      agents: labelled(totalsBy(prices, calls.map((call) => [`${call.agent} ${call.model}`, call]))),
      models: labelled(totalsBy(prices, calls.map((call) => [`${call.api}/${call.model}`, call]))),
    },
  });
};

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

  return Bun.serve({
    hostname: "127.0.0.1",
    port,
    development: false,
    routes: {
      "/": page,
      "/match/:id": page,
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
