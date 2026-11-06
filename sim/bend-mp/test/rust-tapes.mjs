// Tape dumper for the Rust port of the simple machine. Plays the simple
// machine (simple/main.bend) and writes one JSONL line per answered request,
// so the Rust port can be replayed against the same states, requests, answers
// and notes. States, requests and notes are the machine's own JSON.
//
//   node rust-tapes.mjs --random N --seed S [--out PATH]   N games per table size 2, 3, 4
//
// A step line: {game, step, config (step 0 only), state, request,
//   event: {kind: "Draw"|"Choice", n}, next, notes}. n is the answer fed to
// N.answer: for a Draw the offset into the request's range (value = lo + n),
// for a Choice the menu index. A game ends with {game, step, terminal: true,
// state, request}; request is Finished or Stuck, or the last request when the
// step cap cut the game (then capped: true).
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, appendFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { array, kind } from './reference-adapter.mjs';
import { build, makeRandom, normalize } from './machine-items-lib.mjs';

const arg = (name, fallback) => {
  const at = process.argv.indexOf(`--${name}`);
  return at < 0 ? fallback : process.argv[at + 1];
};
const randomGames = arg('random', null);
const seed = Number(arg('seed', 0x7261636b));
const MAX_STEPS = Number(arg('steps', 400));

const dir = mkdtempSync(join(tmpdir(), 'bend-mp-rust-tapes-'));
const SA = (await import(build(dir, 'bridge', '../simple-abstract.bend'))).default;
const N = name => SA[`simple/main:${name}`];

let out, lines = 0, games = 0, steps = 0;
const open = path => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, ''); out = path; lines = games = steps = 0; };
const emit = line => { appendFileSync(out, `${JSON.stringify(line)}\n`); lines++; };
const isOpen = request => !['Finished', 'Stuck'].includes(kind(request));

// Plays one game; answerFor(request, state) gives the answer n, or null to stop.
function play(game, config, answerFor) {
  let state = N('start')(config).state;
  for (let step = 0; ; step++) {
    const request = N('request')(state);
    const n = isOpen(request) && step < MAX_STEPS ? answerFor(request, state, step) : null;
    if (n === null) {
      emit({ game, step, terminal: true, ...(isOpen(request) && { capped: true }), state: normalize(state), request: normalize(request) });
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

try {
  if (randomGames !== null) {
    open(arg('out', '/tmp/rust-tapes/random.jsonl'));
    const { random, randomConfig } = makeRandom(seed);
    const counts = {};
    for (const seats of [2, 3, 4]) for (let trial = 0; trial < Number(randomGames); trial++) {
      const end = play(`random-${seats}-${trial}`, randomConfig(seats), request => kind(request) === 'Draw'
        ? random() % (Number(request.range.extra) + 1)
        : random() % (1 + array(request.moves.tail).length));
      counts[kind(end)] = (counts[kind(end)] ?? 0) + 1;
    }
    console.log(`random tapes: ${games} games, ${steps} answers, ${lines} lines -> ${out}; ends ${JSON.stringify(counts)}`);
  } else {
    console.error('usage: rust-tapes.mjs --random N [--seed S] [--steps CAP] [--out PATH]');
    process.exitCode = 2;
  }
} finally {
  rmSync(dir, { recursive: true });
}
