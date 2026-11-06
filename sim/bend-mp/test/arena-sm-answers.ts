// Reads recorded arena matches and prints, per match, the answers the strong
// machine took: replays the logged moves as web/src/arena/replay.ts does and
// keeps the chain of rules.answer calls that led to the final state (the
// agent tools also call rules.answer on speculative games). Run from web/:
//   bun ../sim/bend-mp/test/arena-sm-answers.ts DB K
// One JSON line per match: {id, name, seed, letters, config, answers, ...}.
import { Database } from "bun:sqlite";
import { dirname, join } from "node:path";

const web = join(import.meta.dir, "../../../web");
const { Option, Result } = await import(Bun.resolveSync("effect", web));
const { default: rules } = await import(join(web, "generated/rules.mjs"));
const { replayOf } = await import(join(web, "src/arena/replay.ts"));

const [dbPath, countArg] = Bun.argv.slice(2);
const count = Number(countArg);
const db = new Database(dbPath, { readonly: true });

const log: Array<{ before: unknown; n: number; after: any }> = [];
const answer = rules.answer;
rules.answer = (state: unknown, n: number) => {
  const after = answer(state, n);
  log.push({ before: state, n, after: after.state });
  return after;
};

// Completed, replay-validated matches, one in every `stride` by seed then name, so the K cover many seeds and entrants.
const completed = db.query("select id, name, seed, manifest_json from matches where status = 'completed' and replay_status = 'validated' order by seed, name").all() as Array<{ id: string; name: string; seed: number; manifest_json: string }>;
const stride = Math.max(1, Math.floor(completed.length / count));
const picked = completed.filter((_, index) => index % stride === 0).slice(0, count);

for (const match of picked) {
  const setup = JSON.parse(match.manifest_json);
  const moves = db.query("select turn, player, selected_move as move, label, by_whom as by from decisions where match_id = ? order by ordinal").all(match.id);
  log.length = 0;
  const replay = replayOf(Option.none(), setup, moves);
  if (Result.isFailure(replay)) throw new Error(`${match.name}: ${replay.failure}`);
  const divergence = Option.getOrNull(replay.success.divergence);
  const source = Option.getOrThrow(replay.success.session.current(replay.success.table));
  const final = source.game.state;
  const answers: number[] = [];
  for (let state = final; state !== undefined;) {
    const entry = log.find(({ after }) => after === state);
    if (entry === undefined) break;
    answers.push(entry.n);
    state = entry.before;
  }
  answers.reverse();
  const seats = db.query("select player, position, cash from match_seats where match_id = ? order by position").all(match.id);
  console.log(JSON.stringify({
    id: match.id, name: match.name, seed: Number(setup.seed), letters: setup.letters, controllers: setup.controllers,
    config: rules.config({ $: setup.controllers.length === 2 ? "TwoSeats" : setup.controllers.length === 3 ? "ThreeSeats" : "FourSeats" }, true),
    moves: moves.length, applied: replay.success.applied.length, divergence, generation: source.game.ticket.generation, answers, seats,
  }));
}
