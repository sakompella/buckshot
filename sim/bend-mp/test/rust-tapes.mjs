// Tape dumper for the Rust port of the simple machine. Plays the simple
// machine (simple/main.bend) and writes one JSONL line per answered request,
// so the Rust port can be replayed against the same states, requests, answers
// and notes. States, requests and notes are the machine's own JSON.
//
//   node rust-tapes.mjs --random N --seed S [--out PATH]   N games per table size 2, 3, 4
//   node rust-tapes.mjs --arena K [--db PATH] [--out PATH]  K recorded arena matches, replayed with their draws
//
// A step line: {game, step, config (step 0 only), state, request,
//   event: {kind: "Draw"|"Choice", n}, next, notes}. n is the answer fed to
// N.answer: for a Draw the offset into the request's range (value = lo + n),
// for a Choice the menu index. A game ends with {game, step, terminal: true,
// state, request}; request is Finished or Stuck, or the last request when the
// step cap cut the game (then capped: true).
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, appendFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { array, kind } from './reference-adapter.mjs';
import { build, makeRandom, normalize } from './machine-items-lib.mjs';

const arg = (name, fallback) => {
  const at = process.argv.indexOf(`--${name}`);
  return at < 0 ? fallback : process.argv[at + 1];
};
const randomGames = arg('random', null), arenaMatches = arg('arena', null);
const seed = Number(arg('seed', 0x7261636b));
const MAX_STEPS = Number(arg('steps', 1500));

const dir = mkdtempSync(join(tmpdir(), 'bend-mp-rust-tapes-'));
const SA = (await import(build(dir, 'bridge', '../simple-abstract.bend'))).default;
const N = name => SA[`simple/main:${name}`], M = name => SA[`sm/main:${name}`];

let out, lines = 0, games = 0, steps = 0;
const open = path => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, ''); out = path; lines = games = steps = 0; };
const emit = line => { appendFileSync(out, `${JSON.stringify(line)}\n`); lines++; };
const isOpen = request => !['Finished', 'Stuck'].includes(kind(request));

// Plays one game; answerFor(request, state) gives the answer n, or null to stop.
function play(game, config, answerFor, limit = MAX_STEPS, extra = () => ({})) {
  let state = N('start')(config).state;
  for (let step = 0; ; step++) {
    const request = N('request')(state);
    const n = isOpen(request) && step < limit ? answerFor(request, state, step) : null;
    if (n === null) {
      emit({ game, step, terminal: true, ...(isOpen(request) && { capped: true }), state: normalize(state), request: normalize(request), ...extra(state, request, step) });
      games++;
      return request;
    }
    const answered = N('answer')(state, n);
    emit({
      game, step, ...(step === 0 && { config: normalize(config) }), state: normalize(state), request: normalize(request),
      event: { kind: kind(request) === 'Draw' ? 'Draw' : 'Choice', n }, next: normalize(answered.state), notes: normalize(answered.notes),
    });
    steps++;
    state = answered.state;
  }
}

// The arena plays the strong machine (sm) with draws from a seeded generator
// and moves from agents, so one run of web/'s replay (arena-sm-answers.ts)
// gives the whole sequence of sm answers. A simple answer is a chain of sm
// answers (SA.chain, simple-fuzz's 'schedule' check), so at each simple request
// the simple answer is the one whose chain, as sm answers, is the next stretch
// of the recorded sequence: a Draw takes the recorded draw, an Idle Choose the
// menu index whose chain matches the recorded moves.
const maybe = x => kind(x) === 'Some' ? x.value : null;

// The sm answers of simple answer n at state s, or null if sm would refuse a step.
function smAnswers(s, n) {
  let x = SA.embed(s);
  const answers = [];
  for (const step of array(SA.chain(s, n))) {
    const k = maybe(SA['walk.legal'](M('request')(x), step));
    if (k === null) return null;
    answers.push(k);
    x = M('answer')(x, k).state;
  }
  return answers;
}

const sockets = n => n === 2 ? [1, 3] : Array.from({ length: n }, (_, i) => i);

function playArena(recorded) {
  const answers = recorded.answers;
  let at = 0;
  const report = { id: recorded.id, name: recorded.name, seed: recorded.seed, smAnswers: answers.length, ambiguous: 0, ended: false };
  const answerFor = (request, state, step) => {
    const menu = kind(request) === 'Draw' ? [answers[at]] : Array.from({ length: 1 + array(request.moves.tail).length }, (_, i) => i);
    const fits = menu.filter(n => {
      const ns = smAnswers(state, n);
      return ns !== null && ns.length > 0 && ns.length <= answers.length - at && ns.every((k, i) => k === answers[at + i]);
    });
    if (fits.length === 0) {
      const best = menu.map(n => { const ns = smAnswers(state, n) ?? []; return { n, ns, shared: ns.findIndex((k, i) => k !== answers[at + i]) }; });
      report.divergence = { step, recordedAt: at, recorded: answers.slice(at, at + 8), request: kind(request), options: best.slice(0, 12).map(({ n, ns, shared }) => ({ n, ns: ns.slice(0, 8), firstDifference: shared })) };
      return null;
    }
    if (fits.length > 1) report.ambiguous++;
    const n = fits[0];
    at += smAnswers(state, n).length;
    return n;
  };
  const finish = (state, request) => {
    const cash = sockets(recorded.letters.length).map(seat => Number(state.players[`s${seat}`].cash));
    report.ended = kind(request) === 'Finished' && at === answers.length;
    report.consumed = at;
    report.cash = cash;
    report.recordedCash = recorded.seats.map(seat => seat.cash);
    report.cashMatches = JSON.stringify(cash) === JSON.stringify(recorded.seats.map(seat => seat.cash));
    return { arena: report };
  };
  play(`arena-${recorded.name}`, recorded.config, answerFor, 100000, finish);
  return report;
}

function recordedMatches(count) {
  const root = fileURLToPath(new URL('../../../web', import.meta.url));
  const db = arg('db', join(homedir(), 'repos/projects/buckshot/_work/arena/analysis/buckshot.sqlite'));
  const helper = fileURLToPath(new URL('./arena-sm-answers.ts', import.meta.url));
  const result = spawnSync('bun', [helper, db, String(count)], { cwd: root, encoding: 'utf8', maxBuffer: 1 << 28 });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`arena-sm-answers failed:\n${result.stderr}`);
  return result.stdout.split('\n').filter(line => line.startsWith('{')).map(line => JSON.parse(line));
}

try {
  if (randomGames !== null) {
    open(arg('out', '/tmp/rust-tapes/random.jsonl'));
    const { random, randomConfig } = makeRandom(seed);
    const counts = {};
    for (const seats of [2, 3, 4]) for (let trial = 0; trial < Number(randomGames); trial++) {
      const end = play(`random-${seats}-${trial}`, randomConfig(seats), request => kind(request) === 'Draw'
        ? random() % (Number(request.range.extra) + 2)
        : random() % (1 + array(request.moves.tail).length));
      counts[kind(end)] = (counts[kind(end)] ?? 0) + 1;
    }
    console.log(`random tapes: ${games} games, ${steps} answers, ${lines} lines -> ${out}; ends ${JSON.stringify(counts)}`);
  } else if (arenaMatches !== null) {
    open(arg('out', '/tmp/rust-tapes/arena.jsonl'));
    const reports = recordedMatches(Number(arenaMatches)).map(playArena);
    for (const { divergence, ...report } of reports) console.log(JSON.stringify(report), divergence ? `DIVERGES ${JSON.stringify(divergence)}` : '');
    console.log(`arena tapes: ${games} games, ${steps} answers, ${lines} lines -> ${out}; ${reports.filter(r => r.ended).length}/${reports.length} reach the recorded end`);
    if (reports.some(r => !r.ended)) process.exitCode = 1;
  } else {
    console.error('usage: rust-tapes.mjs --random N [--seed S] [--steps CAP] [--out PATH] | --arena K [--db PATH] [--out PATH]');
    process.exitCode = 2;
  }
} finally {
  rmSync(dir, { recursive: true });
}
