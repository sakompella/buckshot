import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

import { Database } from "bun:sqlite";
import { Option, Result, Schema } from "effect";

import { agentGame } from "../agent/view.ts";
import { costOf, DEFAULT_PRICES, loadPrices } from "../arena/cost.ts";
import { AgentId } from "../arena/agent.ts";
import { configLabel } from "../arena/model-names.ts";
import { RunManifest } from "../arena/match.ts";
import { CallLine, EventLine, type MoveLine } from "../arena/runlog.ts";
import { manifestProblems, TournamentFile, tournamentOf } from "../arena/tournament-dir.ts";
import { replayOf, type Replay } from "../arena/replay.ts";
import { modelEntrant } from "../arena/tournament.ts";
import { IMPORTER_FILES, IMPORTER_HASH } from "./importer-hash.ts";

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
  provenance: Schema.Struct({ code_sha: Schema.String, agents: Schema.Record(Schema.String, Schema.Struct({ model: Schema.String, effort: Schema.NullOr(Schema.String), instructions_addendum: Schema.optional(Schema.String) })) }),
  agents: Schema.Record(Schema.String, Schema.Struct({ moves: Schema.Int, reminders: Schema.Int, interventions: Schema.Int })),
});

const validateManifest = Schema.decodeUnknownResult(Schema.fromJsonString(ValidationManifest));

/** Stops the import where two sources disagree, naming the match directory, what disagrees and both sides. */
const conflict = (matchDir: string, what: string, dump: string): never => {
  throw new Error(`Import stopped at ${matchDir}: ${what}\n${dump}`);
};

/** Old tournaments ran before configs named their cohort (`config.cohort`); this is their cohort, by tournament name. */
const LEGACY_COHORTS: ReadonlyArray<readonly [string, ReadonlyArray<string>]> = [
  ["opus-effort", ["opus-effort"]],
  ["tournament 3", ["astra-vs-opus-xhigh"]],
  ["tournament 4", ["cross-samples"]],
  ["tournament 5", ["astra-high-cross", "astra-low-cross", "astra-self", "cross-more", "opus-max-cross", "opus-max-effort", "opus-off", "terra61-a", "terra61-b", "terra61-c", "top-four"]],
  ["tournament 6", ["astra-recall", "terra-claude", "opus-none", "haiku-ladder"]],
  ["tournament 7", ["t7-terra-max", "t7-cross-a", "t7-astra-off", "t7-terra-off", "t7-astra-high", "t7-cross-b", "t7-terra-low-high", "t7-terra-xhigh"]],
];

/** The comparison a match is pooled in: its tournament's `cohort`; for tournament 1 (cpa-tiers), each model's effort sweep or the cross-model games. */
const cohortOf = (tournament: string, declared: string | undefined, models: ReadonlyArray<string | null>): string | undefined => {
  if (declared !== undefined) return declared;

  if (tournament === "cpa-tiers") return new Set(models).size === 1 ? `cpa-tiers sweep ${models[0]}` : "cpa-tiers cross-model";

  return LEGACY_COHORTS.find(([, names]) => names.includes(tournament))?.[0];
};

/** Why a finished manifest can't be scored: its standings must cover each seated player exactly once. */
const scoringProblem = (standings: ReadonlyArray<{ readonly player: string }> | undefined, players: ReadonlyArray<string>): string | undefined => {
  if (standings === undefined) return "Finished manifest has no standings";

  return standings.length === players.length && players.every((player) => standings.filter((standing) => standing.player === player).length === 1) ? undefined : "Finished manifest standings do not cover each player exactly once";
};

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

        const observe = (path: string, text: string, matchId: string | null): void => {
          put("source_files", { path, tournament_id: tournamentId, match_id: matchId, sha256: sha(text), bytes: Buffer.byteLength(text) });
          db.query("UPDATE source_records SET current = 0 WHERE path = ?").run(path);
        };

        const record = (path: string, line: number, raw: string): string => {
          const id = sha(json([path, line, raw]));
          put("source_records", { id, path, line, raw, current: 1 });

          return id;
        };

        // The same tournament imported from another directory: its earlier paths are no longer its source.
        const sourcePaths = new Set([tournamentPath, ...file.schedule.flatMap(({ name }) => ["manifest.json", "events.jsonl", "calls.jsonl"].map((leaf) => join(dir, name, leaf)))]);
        const stale = db.query<{ path: string }, [string]>("SELECT path FROM source_files WHERE tournament_id = ?").all(tournamentId).filter(({ path }) => !sourcePaths.has(path));

        for (const { path } of stale) {
          db.query("UPDATE source_records SET current = 0 WHERE path = ?").run(path);
          db.query("DELETE FROM source_files WHERE path = ?").run(path);
        }

        put("tournaments", { id: tournamentId, name: file.config.name, source_dir: dir, created_at: file.created_at, git_commit: file.git_commit, status: "partial", config_json: json(file.config), source_record: sha(json([tournamentPath, 1, tournamentText])) });
        observe(tournamentPath, tournamentText, null);
        record(tournamentPath, 1, tournamentText);

        for (const [name, entrant] of Object.entries(file.config.entrants)) {
          const endpoint = "endpoint" in entrant ? file.config.endpoints[entrant.endpoint] : undefined;
          put("entrants", { id: sha(`${tournamentId}\0${name}`), tournament_id: tournamentId, name, model: "model" in entrant ? entrant.model : null, effort: "effort" in entrant ? (entrant.effortLabel ?? entrant.effort) : null, provider: endpoint?.api ?? null, endpoint_category: "endpoint" in entrant ? entrant.endpoint : "bot", config_json: json(entrant) });
        }

        const scheduledNames = new Set(file.schedule.map((match) => match.name));

        for (const entry of readdirSync(dir, { withFileTypes: true })) {
          if (entry.isDirectory() && existsSync(join(dir, entry.name, "manifest.json")) && !scheduledNames.has(entry.name)) conflict(join(dir, entry.name), "a match directory the schedule does not list", json({ schedule: [...scheduledNames] }));
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

          // Checked against this tournament's config before the fingerprint, so a config change is checked on unchanged matches too.
          if (manifestText !== undefined) {
            const validation = validateManifest(manifestText);

            if (Result.isFailure(validation)) conflict(matchDir, "manifest.json does not decode", json({ error: validation.failure.message }));
            else for (const problem of manifestProblems(tournament, match, validation.success)) conflict(matchDir, "the manifest disagrees with the tournament config", json({ problem }));
          }

          const cohort = cohortOf(file.config.name, file.config.cohort, match.entrants.map((name) => modelEntrant(file.config, name)?.model ?? null)) ?? conflict(matchDir, "the tournament config names no cohort", json({ tournament: file.config.name }));
          const fingerprint = sha(json([IMPORTER_HASH, json(match), manifestText, eventText, callText, priceHash, skipReason ?? null, matchDir]));
          const previous = db.query<{ fingerprint: string }, [string]>("SELECT fingerprint FROM matches WHERE id = ?").get(matchId);

          if (previous?.fingerprint === fingerprint) continue;
          db.query("DELETE FROM calls WHERE match_id = ?").run(matchId);
          db.query("DELETE FROM decisions WHERE match_id = ?").run(matchId);
          db.query("DELETE FROM match_seats WHERE match_id = ?").run(matchId);

          for (const path of [manifestPath, eventsPath, callsPath]) {
            db.query("UPDATE source_records SET current = 0 WHERE path = ?").run(path);

            if (!existsSync(path) && db.query("SELECT 1 FROM source_files WHERE path = ?").get(path) !== null) conflict(matchDir, "a source file imported before is gone", json({ path }));
          }

          const manifest = manifestText === undefined ? undefined : Result.getOrElse(decodeManifest(manifestText), (error) => conflict(matchDir, "manifest.json does not decode", json({ error: error.message })));

          if (manifest?.status === "finished") {
            const problem = scoringProblem(manifest.standings, match.entrants.map((_, index) => manifest.letters[index] ?? match.seats[index] ?? ""));

            if (problem !== undefined) conflict(matchDir, problem, json({ standings: manifest.standings, letters: manifest.letters }));
          }

          // A finished, unskipped match becomes completed only after its replay and end event check out, below.
          const status = manifestText !== undefined || eventText !== undefined || callText !== undefined ? "partial" : isSkipped ? "skipped" : "unstarted";
          put("matches", { id: matchId, tournament_id: tournamentId, name: match.name, pairing: match.pairing, block: match.block, seed: match.seed, seed_block_id: sha(json([tournamentId, match.pairing, match.block, match.seed])), status, cohort, disposition: isSkipped ? "skipped" : null, status_reason: skipReason ?? null, started_at: null, ended_at: null, code_hash: null, validated_with: null, instructions_hash: null, source_dir: matchDir, schedule_json: json(match), manifest_json: manifestText ?? null, source_record: null, fingerprint, replay_status: manifest === undefined ? "unavailable" : "pending" });
          const provenanceObject = manifest?.provenance ?? null;
          const provenance = Schema.decodeUnknownOption(Schema.Struct({ code_sha: Schema.String, instructions_sha: Schema.String }))(provenanceObject);
          db.query("UPDATE matches SET code_hash = ?, instructions_hash = ? WHERE id = ?").run(Option.isSome(provenance) ? provenance.value.code_sha : null, Option.isSome(provenance) ? provenance.value.instructions_sha : null, matchId);

          if (manifestText !== undefined) {
            observe(manifestPath, manifestText, matchId);
            db.query("UPDATE matches SET source_record = ? WHERE id = ?").run(record(manifestPath, 1, manifestText), matchId);
          }

          const readLines = <A>(path: string, text: string | undefined, decode: (raw: string) => Result.Result<A, Schema.SchemaError>): ReadonlyArray<Observation<A>> => {
            if (text === undefined) return [];
            observe(path, text, matchId);
            const lines = text.split("\n");
            const values: Array<Observation<A>> = [];

            // The last line has no newline yet while a match is live: it is read once it ends.
            for (const [index, raw] of lines.slice(0, -1).entries()) {
              const value = Result.getOrElse(decode(raw), (error) => conflict(matchDir, `${path} line ${index + 1} does not decode`, json({ line: raw, error: error.message })));
              values.push({ value, record: record(path, index + 1, raw), line: index + 1 });
            }

            return values;
          };

          const events = readLines(eventsPath, eventText, decodeEvent);
          const calls = readLines(callsPath, callText, decodeCall);
          const ended = events.some(({ value }) => value.kind === "end");

          // The end event is written just before the finished manifest, so a live match can be read with one and not the other.
          if (manifest?.status === "finished" && !ended) conflict(matchDir, "the manifest says finished, the events have no end event", json({ manifest: manifest.status, events: events.length }));

          db.query("UPDATE matches SET started_at = ?, ended_at = ? WHERE id = ?").run(events[0]?.value.t ?? null, events.findLast(({ value }) => value.kind === "end")?.value.t ?? null, matchId);

          const shares = new Map<number, number | null>();

          for (const [index, name] of match.entrants.entries()) {
            const player = manifest?.letters[index] ?? match.seats[index];

            if (player === undefined) throw new Error(`No player for ${match.name} position ${index + 1}`);
            const cash = manifest?.standings?.find((standing) => standing.player === player)?.cash;
            const high = manifest?.standings === undefined ? undefined : Math.max(...manifest.standings.map((standing) => standing.cash));
            const winners = manifest?.standings?.filter((standing) => standing.cash === high).length;
            const entrant = file.config.entrants[name];
            const configured = entrant !== undefined && "model" in entrant ? configLabel(entrant.model, entrant.effortLabel ?? entrant.effort) : undefined;
            // A match from before labels were recorded: a model entrant is its config, a bot or an engine its scheduled seat.
            const label = manifest?.labels?.[index] ?? configured ?? match.seats[index] ?? "";

            if (configured !== undefined && label !== configured) conflict(matchDir, `the manifest's label at position ${index + 1} is not its entrant's config`, json({ label, entrant: name, config: entrant }));
            put("match_seats", { match_id: matchId, position: index + 1, entrant_id: sha(`${tournamentId}\0${name}`), player, label, cash: cash ?? null, win_share: null, provenance_json: json(provenanceObject) });
            shares.set(index + 1, cash === undefined || winners === undefined ? null : cash === high ? 1 / winners : 0);

            if (manifest !== undefined && ((Schema.is(AgentId)(match.seats[index]) && manifest.letters[index] !== match.seats[index]) || manifest.seed !== String(match.seed))) conflict(matchDir, `the manifest disagrees with the schedule at position ${index + 1}`, json({ manifest: { letter: manifest.letters[index], seed: manifest.seed }, schedule: { seat: match.seats[index], seed: match.seed } }));
          }

          const moves: Array<Observation<MoveLine>> = [];
          const seen = new Map<string, MoveLine>();

          for (const event of events) {
            const value = event.value;

            if (value.kind !== "move" && value.kind !== "fallback") continue;
            const key = value.seq === undefined ? `turn:${value.turn}:${value.player}` : `seq:${value.seq}`;
            const prior = seen.get(key);

            // A resumed match can log a move again; the same move twice is one move.
            if (prior !== undefined) {
              if (prior.turn !== value.turn || prior.player !== value.player || prior.move !== value.move || prior.label !== value.label || prior.by !== value.by) conflict(matchDir, `two different moves logged as ${key}`, json({ first: prior, second: value }));
              continue;
            }

            seen.set(key, value);
            moves.push({ ...event, value });
          }

          const replayFailed = (reason: string): never => conflict(matchDir, "the replay disagrees with the logged moves", json({ reason }));
          let replay: Option.Option<Replay> = manifest === undefined ? Option.none() : Option.some(Result.getOrElse(replayOf(Option.none(), manifest, []), replayFailed));

          for (const [ordinal, event] of moves.entries()) {
            const move = event.value;
            let visible: string | null = null;
            let legal: string | null = null;

            if (Option.isSome(replay)) {
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
            put("decisions", { id: sha(`${matchId}\0${ordinal}`), match_id: matchId, ordinal, journal_seq: move.seq ?? null, turn: move.turn, player: move.player, position: move.position, selected_move: move.move, label: move.label, by_whom: move.by, visible_json: visible, legal_json: legal, delivered_json: json(delivered), view_provenance: visible === null ? null : "reconstructed:arena/replay.ts + agentGame; not original prompt", source_record: event.record });

            if (manifest !== undefined) {
              const next = Result.getOrElse(replayOf(replay, manifest, moves.slice(0, ordinal + 1).map(({ value }) => value)), replayFailed);

              if (Option.isSome(next.divergence)) replayFailed(next.divergence.value);
              replay = Option.some(next);
            }
          }

          db.query("UPDATE matches SET replay_status = ?, validated_with = ? WHERE id = ?").run(manifest === undefined ? "unavailable" : "validated", manifest === undefined ? null : IMPORTER_HASH, matchId);

          for (const [ordinal, observation] of calls.entries()) {
            const call = observation.value;
            // Each call belongs to its agent's next chosen move. This is a link heuristic, not a provider call id.
            const decision = moves.findIndex(({ value }) => (value.by === "agent" || value.by === "fallback") && value.player === call.agent && value.t >= call.t);
            put("calls", { id: sha(`${matchId}\0call:${observation.line}`), match_id: matchId, decision_id: decision === -1 ? null : sha(`${matchId}\0${decision}`), ordinal, player: call.agent, position: call.position, model: call.model, provider: call.provider, api: call.api, t: call.t, status: call.error !== undefined || call.stop_reason === "error" || call.stop_reason === "aborted" ? "failed" : "returned", error: call.error ?? null, stop_reason: call.stop_reason, latency_ms: call.latency_ms ?? null, input_tokens: call.usage.input, output_tokens: call.usage.output, cache_read_tokens: call.usage.cacheRead, cache_write_tokens: call.usage.cacheWrite, cache_write_1h_tokens: call.usage.cacheWrite1h ?? null, reasoning_tokens: call.usage.reasoning ?? null, cost_usd: costOf(prices, call) ?? null, reasoning_text: call.thinking, reasoning_provenance: "calls.jsonl thinking, provider-returned text concatenated by runlog.ts; may be summary, not complete chain of thought", response_text: call.text, tool_calls_json: json(call.tool_calls), usage_json: json(call.usage), source_record: observation.record, link_method: decision === -1 ? null : "viewer chronological: next chosen move by same player" });
          }

          if (manifest?.status === "finished") {
            for (const [player, totals] of Object.entries(manifest.agents)) {
              const own = calls.filter(({ value }) => value.agent === player);

              if (totals.model_calls !== own.length) conflict(matchDir, `the manifest's model calls for ${player} disagree with calls.jsonl`, json({ manifest: totals.model_calls, calls: own.length }));

              for (const key of ["input", "output", "cacheRead", "cacheWrite", "reasoning"] as const) {
                const sum = own.reduce((total, { value }) => total + (value.usage[key] ?? 0), 0);

                if (totals.usage[key] !== undefined && totals.usage[key] !== sum) conflict(matchDir, `the manifest's ${key} tokens for ${player} disagree with calls.jsonl`, json({ manifest: totals.usage[key], calls: sum }));
              }
            }

            const finished = Option.getOrThrow(replay);
            const current = finished.session.current(finished.table);

            if (Option.isNone(current) || current.value.game.pending.kind !== "Finished") conflict(matchDir, "the manifest says finished, the replay did not reach the end", json({ pending: Option.isSome(current) ? current.value.game.pending.kind : null }));

            const replayed = finished.frames.at(-1)?.players.map(({ player, cash }) => ({ player, cash }));

            for (const standing of manifest.standings ?? []) {
              if (replayed?.find(({ player }) => player === standing.player)?.cash !== standing.cash) conflict(matchDir, `the replayed cash of ${standing.player} disagrees with the manifest`, json({ manifest: manifest.standings, replayed }));
            }
          }

          if (manifest?.status === "finished" && !isSkipped) {
            db.query("UPDATE matches SET status = 'completed' WHERE id = ?").run(matchId);

            for (const [position, share] of shares) db.query("UPDATE match_seats SET win_share = ? WHERE match_id = ? AND position = ?").run(share, matchId, position);
          }
        }

        db.query(`UPDATE tournaments SET status = CASE WHEN EXISTS (SELECT 1 FROM matches WHERE tournament_id = ? AND status NOT IN ('completed','skipped') AND disposition IS NULL) THEN 'partial' ELSE 'completed' END WHERE id = ?`).run(tournamentId, tournamentId);
        // The seat label is the config's one key: two configs under one label would pool as one.
        const shared = db.query<{ label: string; configs: string }, []>("SELECT s.label, json_group_array(DISTINCT json_remove(e.config_json, '$.endpoint')) AS configs FROM match_seats s JOIN entrants e ON e.id = s.entrant_id GROUP BY s.label HAVING COUNT(DISTINCT json_remove(e.config_json, '$.endpoint')) > 1").all();

        for (const { label, configs } of shared) conflict(dir, `two configs play as ${label}`, configs);
        put("metadata", { key: "schema_version", value: "1" });
        put("metadata", { key: "importer_files", value: json(IMPORTER_FILES) });
        put("metadata", { key: "prices_sha256", value: priceHash });
        put("metadata", { key: "prices_json", value: readFileSync(DEFAULT_PRICES, "utf8") });
      })();
    }
  } finally { db.close(); }
};
