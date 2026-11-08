// Tape dumper for the Rust port of the simple machine. Plays the simple
// machine (simple/main.bend) and writes one JSONL line per answered request,
// so the Rust port can be replayed against the same states, requests, answers
// and notes. States, requests and notes are the machine's own JSON.
//
//   node rust-tapes.mjs MODE... [--seeds a,b,c | --seed S] [--steps CAP] [--dir DIR | --out FILE]
//
// Modes (each writes DIR/<mode>.jsonl, or FILE when a single mode runs):
//   --random N         N games per table size 2, 3, 4 with random configs and mostly in-range answers
//   --items N          N games per table size: every item on, high caps, full item amounts, answers biased to items
//   --wild N           N games per table size: answers sometimes far out of range (the raw n is recorded)
//   --edge [G]         hand-made configs with biased answers, G games per scenario, table size and seed (default 3)
//   --perturb N        N games per seed from states mutated into ones no valid game reaches (from_state; a few answers each)
//   --arena K [--spread] [--db PATH]
//                      K recorded arena matches replayed with their draws; --spread takes them across tournaments
//
// Each tape has a sibling <tape>.manifest.json: mode, seeds, settings, games,
// steps, capped games, lines and a sha256 over every .bend file under sim/bend-mp.
//
// A step line: {game, step, config (step 0 only), state, request,
//   event: {kind: "Draw"|"Choice", n}, next, notes}. n is the answer fed to
// N.answer: for a Draw the offset into the request's range (value = lo + n),
// for a Choice the menu index. A game ends with {game, step, terminal: true,
// state, request}; request is Finished or Stuck, or the last request when the
// step cap cut the game (then capped: true).
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, appendFileSync, readdirSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { homedir, tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { basename, dirname, join } from 'node:path';
import { array, config, kind, list, round } from './reference-adapter.mjs';
import { build, items, makeRandom, normalize } from './machine-items-lib.mjs';

const arg = (name, fallback) => {
  const at = process.argv.indexOf(`--${name}`);
  return at < 0 ? fallback : process.argv[at + 1];
};
const flag = name => process.argv.includes(`--${name}`);
const count = (name, fallback) => {
  const at = process.argv.indexOf(`--${name}`);
  if (at < 0) return null;
  const next = process.argv[at + 1];
  return next === undefined || next.startsWith('--') ? fallback : Number(next);
};
const seeds = String(arg('seeds', arg('seed', 0x7261636b))).split(',').map(Number);
const MAX_STEPS = Number(arg('steps', 1500));

const bendRoot = fileURLToPath(new URL('..', import.meta.url));
const bendSources = () => {
  const files = readdirSync(bendRoot, { recursive: true }).filter(file => file.endsWith('.bend')).sort();
  const hash = createHash('sha256');
  for (const file of files) hash.update(`${file}\0`).update(readFileSync(join(bendRoot, file))).update('\0');
  return { files: files.length, sha256: hash.digest('hex') };
};
const sources = bendSources();

const dir = mkdtempSync(join(tmpdir(), 'bend-mp-rust-tapes-'));
const SA = (await import(build(dir, 'bridge', '../simple-abstract.bend'))).default;
const N = name => SA[`simple/main:${name}`], M = name => SA[`sm/main:${name}`];

let out, lines, games, steps, capped;
const open = path => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, ''); out = path; lines = games = steps = capped = 0; };
let buffer = null;
const emit = line => {
  if (buffer) return buffer.push(line);
  appendFileSync(out, `${JSON.stringify(line)}\n`);
  lines++;
};
const isOpen = request => !['Finished', 'Stuck'].includes(kind(request));

// Plays one game; answerFor(request, state, step) gives the answer n, or null to stop.
// A game from `initial` (a state, not a start) is marked from_state on its first line.
function play(game, config, answerFor, limit = MAX_STEPS, extra = () => ({}), initial = null) {
  let state = initial ?? N('start')(config).state;
  const first = step => step === 0 && { ...(initial && { from_state: true }), config: normalize(config) };
  for (let step = 0; ; step++) {
    const request = N('request')(state);
    const n = isOpen(request) && step < limit ? answerFor(request, state, step) : null;
    if (n === null) {
      emit({ game, step, ...first(step), terminal: true, ...(isOpen(request) && { capped: true }), state: normalize(state), request: normalize(request), ...extra(state, request, step) });
      games++;
      if (isOpen(request)) capped++;
      return request;
    }
    const answered = N('answer')(state, n);
    emit({
      game, step, ...first(step), state: normalize(state), request: normalize(request),
      event: { kind: kind(request) === 'Draw' ? 'Draw' : 'Choice', n }, next: normalize(answered.state), notes: normalize(answered.notes),
    });
    steps++;
    state = answered.state;
  }
}

const movesOf = request => [request.moves.head, ...array(request.moves.tail)];

// Answers in range, except one past the end now and then; with `prefer` a move
// it likes is taken with probability `p`.
const policy = (random, prefer = null, p = 80) => request => {
  if (kind(request) === 'Draw') return random() % (Number(request.range.extra) + 2);
  const moves = movesOf(request);
  const liked = prefer ? moves.flatMap((move, at) => prefer(move, request) ? [at] : []) : [];
  return liked.length > 0 && random() % 100 < p ? liked[random() % liked.length] : random() % moves.length;
};

const big = [2 ** 31, 2 ** 31 - 1, 2 ** 32 - 1, 65536, 1000003];
const wildPolicy = random => request => {
  const far = random() % 6 === 0;
  if (kind(request) === 'Draw') {
    const span = Number(request.range.extra) + 1;
    return far ? [span, span + 1, span + random() % 100, big[random() % big.length]][random() % 4] : random() % (span + 1);
  }
  const moves = movesOf(request).length;
  return far ? [moves, moves + 1, moves + random() % 100, big[random() % big.length]][random() % 4] : random() % moves;
};

const isMove = (...names) => move => names.includes(kind(move));
const usesItem = name => move => kind(move) === 'Use' && kind(move.item) === name;
const stealsItem = name => move => kind(move) === 'Steal' && kind(move.item) === name;
const shootsSelf = (move, request) => kind(move) === 'Shoot' && kind(move.target) === kind(request.seat);
const shootsOther = (move, request) => kind(move) === 'Shoot' && !shootsSelf(move, request);
const anyOf = (...tests) => (move, request) => tests.some(test => test(move, request));

const itemRules = (names, per_player = 8, on_table = 32) => Object.fromEntries(names.map(name => [name.toLowerCase(), { per_player, on_table }]));
const sameLoads = (live, blank, amount) => Array.from({ length: 4 }, () => ({ live, blank, amount }));
const rounds = (count, spec) => Array.from({ length: count }, () => round(spec));

// Item-heavy configs: every item on with high caps and full amounts, so the
// slots fill to 8 and every item gets used.
const itemConfig = (random, seats) => config(seats, Array.from({ length: 1 + random() % 3 }, () => round({
  health: random() % 4 ? 2 + random() % 4 : null,
  items: itemRules(items, random() % 4 ? 8 : 1 + random() % 8, 32),
  loads: Array.from({ length: 4 }, () => {
    const total = 2 + random() % 7, live = random() % (total + 1);
    return { live: random() % 4 ? live : null, blank: total - live, amount: random() % 4 ? 8 : random() % 9 };
  }),
})));

const itemBiases = [
  null,
  isMove('Use'),
  isMove('Steal', 'StealJam'),
  isMove('Jam', 'StealJam'),
  ...items.map(usesItem),
  ...items.map(stealsItem),
  shootsSelf,
  shootsOther,
];

const edges = [
  { name: 'slots-max', seats: [2, 3, 4], rules: () => rounds(2, { health: 5, loads: sameLoads(3, 3, 8), items: itemRules(items) }), prefer: () => null },
  { name: 'jam-everywhere', seats: [2, 3, 4], rules: () => rounds(2, { health: 4, loads: sameLoads(4, 4, 8), items: itemRules(['Jammer']) }), prefer: () => isMove('Jam') },
  { name: 'steal-jammer-saw', seats: [2, 3, 4], rules: () => rounds(2, { health: 4, loads: sameLoads(4, 4, 6), items: itemRules(['Jammer', 'Saw', 'Adrenaline'], 4) }), prefer: () => isMove('Steal', 'StealJam') },
  { name: 'phone', seats: [2, 3, 4], rules: () => rounds(2, { health: 3, loads: sameLoads(4, 4, 6), items: itemRules(['Phone', 'Adrenaline', 'Glass']) }), prefer: () => anyOf(usesItem('Phone'), stealsItem('Phone')) },
  { name: 'inverter', seats: [2, 3], rules: () => rounds(2, { health: 3, loads: sameLoads(3, 3, 6), items: itemRules(['Inverter', 'Glass', 'Beer']) }), prefer: () => anyOf(usesItem('Inverter'), usesItem('Glass')) },
  { name: 'remote', seats: [3, 4], rules: () => rounds(2, { health: 3, loads: sameLoads(4, 4, 6), items: itemRules(['Remote', 'Adrenaline']) }), prefer: () => anyOf(usesItem('Remote'), stealsItem('Remote')) },
  { name: 'saw-beer', seats: [2, 4], rules: () => rounds(2, { health: 2, loads: sameLoads(4, 2, 6), items: itemRules(['Saw', 'Beer', 'Cigarettes']) }), prefer: () => isMove('Use') },
  { name: 'last-round', seats: [2, 3, 4], rules: () => rounds(3, { health: 1, loads: sameLoads(1, 1, 2), items: itemRules(items, 2) }), prefer: () => shootsOther },
  { name: 'one-health-self', seats: [2, 3, 4], rules: () => rounds(3, { health: 1, loads: sameLoads(2, 0, 2), items: itemRules(['Cigarettes', 'Beer', 'Saw'], 2) }), prefer: () => shootsSelf },
  { name: 'single-load', seats: [2, 3, 4], rules: () => rounds(2, { health: 2, loads: [{ live: 1, blank: 0, amount: 1 }, { live: 0, blank: 1, amount: 1 }, { live: 1, blank: 0, amount: 0 }, { live: 0, blank: 1, amount: 0 }], items: itemRules(items, 3) }), prefer: () => shootsSelf },
];

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
  const report = { id: recorded.id, tournament: recorded.tournament, name: recorded.name, seed: recorded.seed, smAnswers: answers.length, ambiguous: 0, ended: false };
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
  play(`arena-${recorded.name}-${recorded.id}`, recorded.config, answerFor, 100000, finish);
  return report;
}

function recordedMatches(count) {
  const root = fileURLToPath(new URL('../../../web', import.meta.url));
  const db = arg('db', join(homedir(), 'repos/projects/buckshot/_work/arena/analysis/buckshot.sqlite'));
  const helper = fileURLToPath(new URL('./arena-sm-answers.ts', import.meta.url));
  const result = spawnSync('bun', [helper, db, String(count), flag('spread') ? 'spread' : 'stride', String(seeds[0])], { cwd: root, encoding: 'utf8', maxBuffer: 1 << 28 });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`arena-sm-answers failed:\n${result.stderr}`);
  return result.stdout.split('\n').filter(line => line.startsWith('{')).map(line => JSON.parse(line));
}

const modes = [];
const mode = (name, settings, run) => modes.push({ name, settings, run });


// Perturbed states: a state reached by a random game is mutated into one no
// valid game reaches (empty gun, no decks, a phase with odd fields, dead seats,
// ...) and Bend plays a few random answers from there. Rust must agree with
// Bend on every state it can represent.
const shell = random => ({ $: random() % 2 ? 'Live' : 'Blank' });
const some = value => ({ $: 'Some', value });
const none = { $: 'None' };
const seatKeys = state => Object.keys(state.players).filter(key => key !== '$');
const seatTag = key => ({ $: `Seat${key.slice(1)}` });
const seatOf = (state, random) => seatKeys(state)[random() % seatKeys(state).length];
// Half the time a seat that may not sit at this table.
const seatAny = (state, random) => random() % 2 ? { $: `Seat${random() % 4}` } : seatTag(seatOf(state, random));
const slotNames = [0, 1, 2, 3, 4, 5, 6, 7].map(i => `s${i}`);
const mutations = [
  state => { state.world.gun = list([]); },
  (state, random) => { state.world.gun = list([shell(random)]); },
  (state, random) => { state.world.gun = list(Array.from({ length: 1 + random() % 3 }, () => shell(random))); },
  state => { state.world.shown = { $: 'Load', live: 0, blank: 0 }; },
  state => { for (const table of ['two', 'three', 'four']) state.world.decks[table] = list([]); },
  (state, random) => { state.world.decks.two = list([{ $: 'Batch', id: random() % 3, load: { $: 'Load', live: 0, blank: 0 } }]); },
  state => { for (const key of seatKeys(state)) state.grabs.holding[key] = none; },
  (state, random) => { for (const key of seatKeys(state)) state.grabs.holding[key] = random() % 2 ? some({ $: items[random() % items.length] }) : none; },
  (state, random) => {
    state.grabs.distributing = random() % 4 > 0;
    for (const key of seatKeys(state)) {
      state.grabs.granted[key] = random() % 3;
      state.grabs.grabbing[key] = random() % 2 === 0;
      state.grabs.intake[key] = random() % 2 === 0;
    }
  },
  (state, random) => { for (const key of seatKeys(state)) if (random() % 2) state.players[key].health = 0; },
  (state, random) => { state.players[seatOf(state, random)].health = 0; },
  state => { state.world.turn = none; },
  (state, random) => { state.world.turn = some(seatAny(state, random)); },
  (state, random) => { for (const slot of slotNames) state.players[seatOf(state, random)].slots[slot] = none; },
  (state, random) => { for (const slot of slotNames) state.players[seatOf(state, random)].slots[slot] = some({ $: items[random() % items.length] }); },
  (state, random) => { state.players[seatOf(state, random)].jam = { $: ['Free', 'Jammed', 'JammedSkipped'][random() % 3] }; },
  (state, random) => { state.world.sawed = random() % 2 === 0; },
  (state, random) => { state.world.direction = { $: random() % 2 ? 'Clockwise' : 'CounterClockwise' }; },
  (state, random) => { state.world.first_death = random() % 2 ? none : some(seatAny(state, random)); },
  (state, random) => { state.world.checking_first_death = random() % 2 === 0; },
  (state, random) => { state.world.first_turn = seatAny(state, random); },
  (state, random) => { state.world.item_amount = random() % 4; },
  (state, random) => { state.world.round_index = random() % 4; state.world.load_index = random() % 5; },
  (state, random) => { state.world.before_round = random() % 2 === 0; state.world.first_sequence = random() % 2 === 0; },
  (state, random) => {
    const seat = () => seatAny(state, random);
    const itemTag = () => ({ $: items[random() % items.length] });
    const load = () => ({ $: 'Load', live: random() % 3, blank: random() % 3 });
    const phases = [
      () => ({ $: 'NeedSwap', load: load(), shells: list(Array.from({ length: random() % 4 }, () => shell(random))), i: random() % 4 }),
      () => ({ $: 'NeedSwap', load: load(), shells: list([]), i: 0 }),
      () => ({ $: 'Idle', seat: seat() }),
      () => ({ $: 'Blocked', holder: random() % 2 ? none : some(seat()) }),
      () => ({ $: 'NeedTurnAmount', from: seat(), passing: random() % 2 === 0, winner: random() % 2 ? none : some(seat()) }),
      () => ({ $: 'NeedItem', seat: seat(), first: itemTag(), second: itemTag(), rest: list(Array.from({ length: random() % 4 }, itemTag)) }),
      () => ({ $: 'NeedPhone', seat: seat(), owner: seat(), slot: { $: `Slot${random() % 8}` } }),
      () => ({ $: ['NeedFirst', 'NeedHealth', 'NeedAmount', 'NeedBatch', 'Stalled', 'Ended'][random() % 6] }),
    ];
    state.phase = phases[random() % phases.length]();
  },
];

// Bend may refuse a state no valid game reaches: its compiled code throws.
// Any other exception (this script, the adapter) is a generator bug and fails,
// and so do more refusals than the cap, which would hollow out the tape.
const MAX_REJECTED = 0.05;
const rejectedByBend = error => (String(error?.stack ?? '').split('\n').find(line => line.trimStart().startsWith('at ')) ?? '').includes(dir);

function perturbed(count, seed) {
  const { random, randomConfig } = makeRandom(seed);
  const reach = (config, target) => {
    let state = N('start')(config).state;
    for (let step = 0; step < target; step++) {
      const request = N('request')(state);
      if (!isOpen(request)) break;
      state = N('answer')(state, kind(request) === 'Draw' ? random() % (Number(request.range.extra) + 2) : random() % (1 + array(request.moves.tail).length)).state;
    }
    return normalize(state);
  };
  let rejected = 0;
  for (let at = 0; at < count; at++) {
    const seats = [2, 3, 4][at % 3];
    const base = reach(at % 2 ? randomConfig(seats) : itemConfig(random, seats), random() % 60);
    const state = base;
    for (let k = 1 + random() % 3; k > 0; k--) mutations[random() % mutations.length](state, random);
    const saved = { games, steps, capped };
    buffer = [];
    try {
      play(`perturb-${seed}-${at}`, state.world.config, request => kind(request) === 'Draw'
        ? (random() % 10 ? random() % (Number(request.range.extra) + 2) : random() % 70000)
        : random() % (1 + array(request.moves.tail).length), 6, undefined, state);
      const kept = buffer;
      buffer = null;
      kept.forEach(emit);
    } catch (error) {
      if (!rejectedByBend(error)) throw error;
      ({ games, steps, capped } = saved);
      rejected++;
    } finally {
      buffer = null;
    }
  }
  if (rejected > count * MAX_REJECTED) throw new Error(`perturb seed ${seed}: Bend rejected ${rejected} of ${count} states, over the cap of ${MAX_REJECTED * 100}%`);
  return rejected;
}

const randomGames = count('random', 20), itemGames = count('items', 20), wildGames = count('wild', 20), edgeGames = count('edge', 3), arenaMatches = count('arena', 5), perturbGames = count('perturb', 200);

if (randomGames !== null) mode('random', { perTable: randomGames }, () => {
  const ends = {};
  for (const seed of seeds) {
    const { random, randomConfig } = makeRandom(seed);
    for (const seats of [2, 3, 4]) for (let trial = 0; trial < randomGames; trial++) {
      const end = play(`random-${seed}-${seats}-${trial}`, randomConfig(seats), request => kind(request) === 'Draw'
        ? random() % (Number(request.range.extra) + 2)
        : random() % (1 + array(request.moves.tail).length));
      ends[kind(end)] = (ends[kind(end)] ?? 0) + 1;
    }
  }
  return ends;
});

if (itemGames !== null) mode('items', { perTable: itemGames }, () => {
  for (const seed of seeds) {
    const { random, pick } = makeRandom(seed);
    for (const seats of [2, 3, 4]) for (let trial = 0; trial < itemGames; trial++) {
      play(`items-${seed}-${seats}-${trial}`, itemConfig(random, seats), policy(random, pick(itemBiases), 70));
    }
  }
});

if (wildGames !== null) mode('wild', { perTable: wildGames }, () => {
  for (const seed of seeds) {
    const { random, pick, randomConfig } = makeRandom(seed);
    for (const seats of [2, 3, 4]) for (let trial = 0; trial < wildGames; trial++) {
      play(`wild-${seed}-${seats}-${trial}`, trial % 2 ? randomConfig(seats) : itemConfig(random, seats), wildPolicy(random));
    }
  }
});

if (edgeGames !== null) mode('edge', { perScenario: edgeGames, scenarios: edges.map(edge => edge.name) }, () => {
  for (const seed of seeds) {
    const { random } = makeRandom(seed);
    for (const edge of edges) for (const seats of edge.seats) for (let trial = 0; trial < edgeGames; trial++) {
      play(`edge-${edge.name}-${seed}-${seats}-${trial}`, config(seats, edge.rules()), policy(random, edge.prefer(), 85));
    }
  }
});

if (perturbGames !== null) mode('perturb', { perSeed: perturbGames }, () => {
  let rejected = 0;
  for (const seed of seeds) rejected += perturbed(perturbGames, seed);
  console.log(`perturb: ${rejected} of ${perturbGames * seeds.length} states rejected by Bend (its code threw), skipped`);
  return { rejectedByBend: rejected };
});

if (arenaMatches !== null) mode(flag('spread') ? 'arena-spread' : 'arena', { matches: arenaMatches, spread: flag('spread'), seed: seeds[0] }, () => {
  const reports = recordedMatches(arenaMatches).map(playArena);
  for (const { divergence, ...report } of reports) console.log(JSON.stringify(report), divergence ? `DIVERGES ${JSON.stringify(divergence)}` : '');
  console.log(`${reports.filter(r => r.ended).length}/${reports.length} reach the recorded end`);
  if (reports.some(r => !r.ended)) process.exitCode = 1;
  return { tournaments: new Set(reports.map(r => r.tournament)).size };
});

try {
  if (modes.length === 0) {
    console.error('usage: rust-tapes.mjs [--random N] [--items N] [--wild N] [--edge [G]] [--perturb N] [--arena K [--spread] [--db PATH]] [--seeds a,b,c] [--steps CAP] [--dir DIR | --out FILE]');
    process.exitCode = 2;
  }
  if (modes.length > 1 && arg('out', null) !== null) throw new Error('--out names one file; use --dir with several modes');
  for (const { name, settings, run } of modes) {
    const path = arg('out', null) ?? join(arg('dir', '/tmp/rust-tapes'), `${name}.jsonl`);
    open(path);
    const result = run();
    writeFileSync(`${path}.manifest.json`, `${JSON.stringify({ tape: basename(path), mode: name, seeds, settings: { ...settings, maxSteps: MAX_STEPS }, result, games, steps, capped, lines, bend: sources }, null, 2)}\n`);
    console.log(`${name} tapes: ${games} games (${capped} capped), ${steps} answers, ${lines} lines -> ${path}`);
  }
} finally {
  rmSync(dir, { recursive: true });
}
