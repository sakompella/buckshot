import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

import { Database } from "bun:sqlite";
import { Option, Result, Schema } from "effect";

import { agentGame } from "../agent/view.ts";
import { costOf, DEFAULT_PRICES, loadPrices } from "../arena/cost.ts";
import { RunManifest } from "../arena/match.ts";
import { CallLine, EventLine, type MoveLine } from "../arena/runlog.ts";
import { manifestProblems, TournamentFile, tournamentOf } from "../arena/tournament-dir.ts";
import { replayOf, type Replay } from "../viewer/replay.ts";

const sha = (text: string) => createHash("sha256").update(text).digest("hex");

const json = <A>(value: A): string => JSON.stringify(value);

const textOf = (path: string): string | undefined => existsSync(path) ? readFileSync(path, "utf8") : undefined;

const decodeTournament = Schema.decodeUnknownSync(Schema.fromJsonString(TournamentFile));

const decodeManifest = Schema.decodeUnknownResult(Schema.fromJsonString(RunManifest));

const decodeEvent = Schema.decodeUnknownResult(Schema.fromJsonString(EventLine));

const decodeCall = Schema.decodeUnknownResult(Schema.fromJsonString(CallLine));

const ValidationManifest = Schema.Struct({
  status: Schema.String, seed: Schema.String, controllers: Schema.Array(Schema.String),
  letters: Schema.Array(Schema.String), delivery: Schema.String,
  provenance: Schema.Struct({ code_sha: Schema.String, agents: Schema.Record(Schema.String, Schema.Struct({ model: Schema.String, effort: Schema.NullOr(Schema.String) })) }),
  agents: Schema.Record(Schema.String, Schema.Struct({ moves: Schema.Int, reminders: Schema.Int, interventions: Schema.Int })),
});

const validateManifest = Schema.decodeUnknownOption(Schema.fromJsonString(ValidationManifest));

interface Observation<A> { readonly value: A; readonly record: string; readonly line: number }

export interface ImportOptions {
  readonly database: string;
  readonly sources: ReadonlyArray<string>;
  /** Tournament directory to scheduled match name to the reason it is not scored. Unstarted work is not evidence of a skip. */
  readonly skipped?: Readonly<Record<string, Readonly<Record<string, string>>>>;
}

export const openAnalysis = (path: string): Database => {
  mkdirSync(dirname(resolve(path)), { recursive: true });
  const db = new Database(path, { strict: true });
  db.exec(readFileSync(new URL("./schema.sql", import.meta.url), "utf8"));

  return db;
};

/** Refreshes changed matches atomically per tournament. Source files are never opened for writing. */
export const importTournaments = ({ database, sources, skipped = {} }: ImportOptions): void => {
  const db = openAnalysis(database);
  const prices = loadPrices(DEFAULT_PRICES);
  const priceHash = sha(readFileSync(DEFAULT_PRICES, "utf8"));
  const importerHash = sha(readFileSync(new URL(import.meta.url), "utf8") + readFileSync(new URL("./schema.sql", import.meta.url), "utf8"));

  try {
    for (const source of sources) {
      const dir = resolve(source);
      const tournamentPath = join(dir, "tournament.json");
      const tournamentText = readFileSync(tournamentPath, "utf8");
      const file = decodeTournament(tournamentText);
      const tournamentId = sha(`${file.created_at}\0${file.config.name}`);
      const tournament = Result.getOrThrow(tournamentOf(file));
      db.transaction(() => {
        const put = (table: string, values: Readonly<Record<string, string | number | null>>) => {
          const keys = Object.keys(values);
          db.query(`INSERT INTO ${table} (${keys.join(",")}) VALUES (${keys.map(() => "?").join(",")}) ON CONFLICT DO UPDATE SET ${keys.map((key) => `${key}=excluded.${key}`).join(",")}`).run(...Object.values(values));
        };

        const issue = (message: string, matchId: string | null = null, record: string | null = null) => {
          put("issues", { id: sha(json([tournamentId, matchId, record, message])), tournament_id: tournamentId, match_id: matchId, source_record: record, message });
        };

        const observe = (path: string, text: string, matchId: string | null): void => {
          put("source_files", { path, tournament_id: tournamentId, match_id: matchId, sha256: sha(text), bytes: Buffer.byteLength(text) });
          db.query("UPDATE source_records SET current = 0 WHERE path = ?").run(path);
        };

        const record = (path: string, line: number, raw: string, problem: string | null = null): string => {
          const id = sha(json([path, line, raw]));
          put("source_records", { id, path, line, raw, current: 1, issue: problem });

          return id;
        };

        put("tournaments", { id: tournamentId, name: file.config.name, source_dir: dir, created_at: file.created_at, git_commit: file.git_commit, status: "partial", config_json: json(file.config), source_record: sha(json([tournamentPath, 1, tournamentText])) });
        observe(tournamentPath, tournamentText, null);
        record(tournamentPath, 1, tournamentText);

        for (const [name, entrant] of Object.entries(file.config.entrants)) {
          const endpoint = "endpoint" in entrant ? file.config.endpoints[entrant.endpoint] : undefined;
          put("entrants", { id: sha(`${tournamentId}\0${name}`), tournament_id: tournamentId, name, model: "model" in entrant ? entrant.model : null, effort: "effort" in entrant ? entrant.effort : null, provider: endpoint?.api ?? null, endpoint_category: "endpoint" in entrant ? entrant.endpoint : "bot", config_json: json(entrant) });
        }

        const scheduledNames = new Set(file.schedule.map((match) => match.name));

        for (const entry of readdirSync(dir, { withFileTypes: true })) {
          if (entry.isDirectory() && existsSync(join(dir, entry.name, "manifest.json")) && !scheduledNames.has(entry.name)) issue(`Unscheduled match directory: ${entry.name}`);
        }

        for (const match of file.schedule) {
          const matchId = sha(`${tournamentId}\0${match.name}`);
          const matchDir = join(dir, match.name);
          const manifestPath = join(matchDir, "manifest.json");
          const eventsPath = join(matchDir, "events.jsonl");
          const callsPath = join(matchDir, "calls.jsonl");
          // Each read is a bounded file snapshot. A running match can append after this point.
          const manifestText = textOf(manifestPath);
          const eventText = textOf(eventsPath);
          const callText = textOf(callsPath);
          const skipReason = skipped[dir]?.[match.name];
          const isSkipped = skipReason !== undefined;
          const fingerprint = sha(json([importerHash, json(match), manifestText, eventText, callText, priceHash, skipReason ?? null]));
          const previous = db.query<{ fingerprint: string }, [string]>("SELECT fingerprint FROM matches WHERE id = ?").get(matchId);

          if (previous?.fingerprint === fingerprint) continue;
          db.query("DELETE FROM calls WHERE match_id = ?").run(matchId);
          db.query("DELETE FROM decisions WHERE match_id = ?").run(matchId);
          db.query("DELETE FROM match_seats WHERE match_id = ?").run(matchId);
          db.query("DELETE FROM issues WHERE match_id = ?").run(matchId);

          for (const path of [manifestPath, eventsPath, callsPath]) {
            db.query("UPDATE source_records SET current = 0 WHERE path = ?").run(path);

            if (!existsSync(path) && db.query("SELECT 1 FROM source_files WHERE path = ?").get(path) !== null) issue(`Previously imported source file is missing: ${path}`, matchId);
          }

          const parsed = manifestText === undefined ? undefined : decodeManifest(manifestText);
          const manifest = parsed !== undefined && Result.isSuccess(parsed) ? parsed.success : undefined;
          const status = manifest?.status === "finished" && !isSkipped ? "completed" : manifestText !== undefined || eventText !== undefined || callText !== undefined ? "partial" : isSkipped ? "skipped" : "unstarted";
          put("matches", { id: matchId, tournament_id: tournamentId, name: match.name, pairing: match.pairing, block: match.block, seed: match.seed, seed_block_id: sha(json([tournamentId, match.pairing, match.block, match.seed])), status, disposition: isSkipped ? "skipped" : null, status_reason: skipReason ?? null, started_at: null, ended_at: null, code_hash: null, rules_hash: null, instructions_hash: null, source_dir: matchDir, schedule_json: json(match), manifest_json: manifestText ?? null, source_record: null, fingerprint, replay_status: manifest === undefined ? "unavailable" : "pending", replay_error: null });
          const provenanceObject = manifest?.provenance ?? null;
          const provenance = Schema.decodeUnknownOption(Schema.Struct({ code_sha: Schema.String, instructions_sha: Schema.String }))(provenanceObject);
          db.query("UPDATE matches SET code_hash = ?, instructions_hash = ? WHERE id = ?").run(Option.isSome(provenance) ? provenance.value.code_sha : null, Option.isSome(provenance) ? provenance.value.instructions_sha : null, matchId);

          if (manifestText !== undefined) {
            observe(manifestPath, manifestText, matchId);
            const id = record(manifestPath, 1, manifestText, parsed !== undefined && Result.isFailure(parsed) ? parsed.failure.message : null);
            db.query("UPDATE matches SET source_record = ? WHERE id = ?").run(id, matchId);

            if (parsed !== undefined && Result.isFailure(parsed)) issue(`Manifest: ${parsed.failure.message}`, matchId, id);
            const validation = validateManifest(manifestText);

            if (Option.isSome(validation)) for (const message of manifestProblems(tournament, match, validation.value)) issue(message, matchId, id);
          }

          const readLines = <A>(path: string, text: string | undefined, decode: (raw: string) => Result.Result<A, Schema.SchemaError>): ReadonlyArray<Observation<A>> => {
            if (text === undefined) return [];
            observe(path, text, matchId);
            const lines = text.split("\n");
            const values: Array<Observation<A>> = [];

            for (const [index, raw] of lines.entries()) {
              if (index === lines.length - 1 && raw === "") continue;
              const result = decode(raw);
              const problem = index === lines.length - 1 ? "Unterminated JSONL tail; deferred until newline" : Result.isFailure(result) ? result.failure.message : null;
              const id = record(path, index + 1, raw, problem);

              if (problem !== null) issue(problem, matchId, id);
              else if (Result.isSuccess(result)) values.push({ value: result.success, record: id, line: index + 1 });
            }

            return values;
          };

          const events = readLines(eventsPath, eventText, decodeEvent);
          const calls = readLines(callsPath, callText, decodeCall);
          const ended = events.some(({ value }) => value.kind === "end");

          if (manifest?.status === "finished" && !ended) issue("Finished manifest without end event in snapshot", matchId);

          if (manifest?.status === "running" && ended) issue("End event with running manifest in snapshot; refresh after writer finishes", matchId);

          db.query("UPDATE matches SET started_at = ?, ended_at = ? WHERE id = ?").run(events[0]?.value.t ?? null, events.findLast(({ value }) => value.kind === "end")?.value.t ?? null, matchId);

          for (const [index, name] of match.entrants.entries()) {
            const player = manifest?.letters[index] ?? match.seats[index];

            if (player === undefined) throw new Error(`No player for ${match.name} position ${index + 1}`);
            const cash = manifest?.standings?.find((standing) => standing.player === player)?.cash;
            const high = manifest?.standings === undefined ? undefined : Math.max(...manifest.standings.map((standing) => standing.cash));
            const winners = manifest?.standings?.filter((standing) => standing.cash === high).length;
            put("match_seats", { match_id: matchId, position: index + 1, entrant_id: sha(`${tournamentId}\0${name}`), player, cash: cash ?? null, win_share: status !== "completed" || cash === undefined || winners === undefined ? null : cash === high ? 1 / winners : 0, provenance_json: json(provenanceObject) });

            if (manifest !== undefined && (manifest.letters[index] !== match.seats[index] || manifest.seed !== String(match.seed))) issue(`Schedule differs from manifest at position ${index + 1}`, matchId);
          }

          const moves: Array<Observation<MoveLine>> = [];
          const seen = new Map<string, MoveLine>();
          let conflictingMoves = false;

          for (const event of events) {
            const value = event.value;

            if (value.kind !== "move" && value.kind !== "fallback") continue;
            const key = value.seq === undefined ? `turn:${value.turn}:${value.player}` : `seq:${value.seq}`;
            const prior = seen.get(key);

            if (prior !== undefined) {
              const equivalent = prior.turn === value.turn && prior.player === value.player && prior.move === value.move && prior.label === value.label && prior.by === value.by;
              issue(`${equivalent ? "Repeated" : "Conflicting"} move ${key}; observation kept, projection uses first`, matchId, event.record);

              if (!equivalent) conflictingMoves = true;
              continue;
            }

            seen.set(key, value);
            moves.push({ ...event, value });
          }

          let replay: Option.Option<Replay> = Option.none();
          let replayError: string | null = conflictingMoves ? "Conflicting move observations; see issues" : null;

          if (manifest !== undefined) {
            const start = replayOf(Option.none(), manifest, []);

            if (Result.isSuccess(start)) replay = Option.some(start.success);
            else replayError = start.failure;
          }

          for (const [ordinal, event] of moves.entries()) {
            const move = event.value;
            let visible: string | null = null;
            let legal: string | null = null;

            if (Option.isSome(replay) && replayError === null) {
              const current = replay.value.session.current(replay.value.table);

              if (Option.isSome(current)) {
                const game = agentGame(current.value, replay.value.session.turn(replay.value.table), move.player);

                if (Result.isSuccess(game)) {
                  visible = json(game.success);

                  if (game.success.status === "your turn") legal = json(game.success.moves);
                }
              }
            }

            const delivered = events.flatMap(({ value, line }) => value.kind === "delivered" && value.player === move.player && value.turn === move.turn && line < event.line ? [{ from: value.from, entries: value.entries, seq: value.seq, turn: value.turn }] : []);
            put("decisions", { id: sha(`${matchId}\0${ordinal}`), match_id: matchId, ordinal, journal_seq: move.seq ?? null, turn: move.turn, player: move.player, position: move.position, selected_move: move.move, label: move.label, by_whom: move.by, visible_json: visible, legal_json: legal, delivered_json: json(delivered), view_provenance: visible === null ? null : "reconstructed:viewer/replay.ts + agentGame; not original prompt", source_record: event.record });

            if (manifest !== undefined && replayError === null) {
              const next = replayOf(replay, manifest, moves.slice(0, ordinal + 1).map(({ value }) => value));

              if (Result.isFailure(next)) replayError = next.failure;
              else {
                replay = Option.some(next.success);

                if (Option.isSome(next.success.divergence)) replayError = next.success.divergence.value;
              }
            }
          }

          if (replayError !== null) issue(`Replay: ${replayError}`, matchId);
          db.query("UPDATE matches SET replay_status = ?, replay_error = ? WHERE id = ?").run(replayError !== null ? "diverged" : manifest === undefined ? "unavailable" : "validated", replayError, matchId);

          for (const [ordinal, observation] of calls.entries()) {
            const call = observation.value;
            // Same chronological attribution as viewer/reasoning.ts. This is a link heuristic, not a provider call id.
            const decision = moves.findIndex(({ value }) => (value.by === "agent" || value.by === "fallback") && value.player === call.agent && value.t >= call.t);
            put("calls", { id: sha(`${matchId}\0call:${observation.line}`), match_id: matchId, decision_id: decision === -1 ? null : sha(`${matchId}\0${decision}`), ordinal, player: call.agent, position: call.position, model: call.model, provider: call.provider, api: call.api, t: call.t, status: call.error !== undefined || call.stop_reason === "error" || call.stop_reason === "aborted" ? "failed" : "returned", error: call.error ?? null, stop_reason: call.stop_reason, latency_ms: call.latency_ms ?? null, input_tokens: call.usage.input, output_tokens: call.usage.output, cache_read_tokens: call.usage.cacheRead, cache_write_tokens: call.usage.cacheWrite, cache_write_1h_tokens: call.usage.cacheWrite1h ?? null, reasoning_tokens: call.usage.reasoning ?? null, cost_usd: costOf(prices, call) ?? null, reasoning_text: call.thinking, reasoning_provenance: "calls.jsonl thinking, provider-returned text concatenated by runlog.ts; may be summary, not complete chain of thought", response_text: call.text, tool_calls_json: json(call.tool_calls), usage_json: json(call.usage), source_record: observation.record, link_method: decision === -1 ? null : "viewer chronological: next chosen move by same player" });
          }

          if (manifest?.status === "finished") {
            for (const [player, totals] of Object.entries(manifest.agents)) {
              const own = calls.filter(({ value }) => value.agent === player);

              if (totals.model_calls !== own.length) issue(`Manifest ${player} model_calls ${totals.model_calls} != logs ${own.length}`, matchId);

              for (const key of ["input", "output", "cacheRead", "cacheWrite", "reasoning"] as const) {
                const sum = own.reduce((total, { value }) => total + (value.usage[key] ?? 0), 0);

                if (totals.usage[key] !== undefined && totals.usage[key] !== sum) issue(`Manifest ${player} ${key} ${totals.usage[key]} != logs ${sum}`, matchId);
              }
            }

            if (Option.isSome(replay) && replayError === null) {
              const last = replay.value.frames.at(-1);

              for (const standing of manifest.standings ?? []) if (last?.players.find(({ player }) => player === standing.player)?.cash !== standing.cash) issue(`Replayed cash differs for ${standing.player}`, matchId);
            }
          }
        }

        db.query(`UPDATE tournaments SET status = CASE WHEN EXISTS (SELECT 1 FROM matches WHERE tournament_id = ? AND status NOT IN ('completed','skipped') AND disposition IS NULL) THEN 'partial' ELSE 'completed' END WHERE id = ?`).run(tournamentId, tournamentId);
        put("metadata", { key: "schema_version", value: "1" });
        put("metadata", { key: "importer_sha256", value: importerHash });
        put("metadata", { key: "prices_sha256", value: priceHash });
        put("metadata", { key: "prices_json", value: readFileSync(DEFAULT_PRICES, "utf8") });
      })();
    }
  } finally { db.close(); }
};
