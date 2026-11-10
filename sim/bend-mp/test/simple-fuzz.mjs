// Fuzz of the simple machine against sm. At every simple point of seeded
// random games it checks that one simple answer is a chain of moves sm offers
// (simple-abstract.bend's walk), ending at the embedded next state with the
// same notes; that the embedded state is valid; that the simple board is sm's
// board; that the menu is exactly sm's chains, first slot kept; and privacy.
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { list, array, kind, seatNumber } from './reference-adapter.mjs';
import { build, makeRandom, Mismatch, normalize, propertyCheck, sockets } from './machine-items-lib.mjs';

// Most trials are prefixes of MAX_STEPS answers; a smaller batch plays whole
// games (an item game can run past 2,600 random answers), and one that has
// not finished after COMPLETE_STEPS answers fails.
const GAMES_PER_TABLE = Number(process.env.FUZZ_GAMES ?? 500);
const MAX_STEPS = Number(process.env.FUZZ_STEPS ?? 60);
const COMPLETE_PER_TABLE = Number(process.env.FUZZ_COMPLETE ?? Math.ceil(GAMES_PER_TABLE / 20));
const COMPLETE_STEPS = Number(process.env.FUZZ_COMPLETE_STEPS ?? 10000);

const dir = mkdtempSync(join(tmpdir(), 'bend-mp-simple-fuzz-'));
const bridge = build(dir, 'bridge', '../simple-abstract.bend'), abstract = build(dir, 'abstract', '../abstract.bend');
const SA = (await import(bridge)).default, A = (await import(abstract)).default;
const N = name => SA[`simple/main:${name}`], M = name => SA[`sm/main:${name}`], D = name => SA[`domain:${name}`];
const notesOf = s => SA['simple/state:state.notes'](s);
const { random, randomConfig, drawAnswer, moveAnswer, shuffled } = makeRandom(0x73696d70);

const seatTag = s => ({ $: `Seat${s}` });
const json = x => JSON.stringify(normalize(x));
const count = { refines: 0, valid: 0, board: 0, draws: 0, menus: 0, privacy: 0, schedule: 0 };
const coverage = { prefixes: 0, prefixesFinished: 0, complete: 0, longest: 0, points: 0, itemDraws: 0, distributions: 0 };
const moveKinds = { Shoot: 0, Use: 0, Jam: 0, Steal: 0, StealJam: 0 };
const capBound = { 2: 0, 3: 0, 4: 0 };

const same = propertyCheck(count);

const maybe = x => kind(x) === 'Some' ? x.value : null;
const RING_TABLE = { Duo: 'TwoSeats', Trio: 'ThreeSeats', Quad: 'FourSeats' };

function checkValid(game, label, x) {
  const { grabbing, holding, granted, intake } = x.grabs;
  same('valid', `${label} normal form`, x, A.normalize_items(x), game);
  same('valid', `${label} table tie`, Array(5).fill(kind(x.world.config.table)), [x.players, grabbing, holding, granted, intake].map(ring => RING_TABLE[kind(ring)]), game);
  same('valid', `${label} facts`, { bounded: true, ready: true }, { bounded: A.bounded(x), ready: A.items_ready(x.phase, x.world) }, game);
}

const moveKey = move => {
  const fields = Object.entries(move).filter(([k]) => k !== '$').map(([k, v]) => typeof v === 'object' ? kind(v) : String(v));
  return [kind(move), ...fields].join(' ');
};

// sm's whole-action chains at an Idle point, as moves.ts finds them: a chain
// goes on while the seat aims, picks a jam target or picks a steal.
function smChains(x, seat) {
  const chains = [];
  const visit = (state, prefix) => {
    const prompt = maybe(D('prompt.of')(M('request')(state), seatTag(seat)));
    const menu = [prompt.menu.head, ...array(prompt.menu.tail)];
    menu.forEach((move, k) => {
      const after = M('answer')(state, D('prompt.answer')(prompt, k)).state;
      const chain = [...prefix, move];
      if (['Aim', 'JamPick', 'StealPick'].includes(kind(after.phase))) visit(after, chain); else chains.push(chain);
    });
  };
  visit(x, []);
  return chains;
}

const chainKey = moves => {
  const [first, second, third] = moves;
  switch (moves.map(kind).join(' ')) {
    case 'PickUp Shoot': return `Shoot ${kind(second.target)}`;
    case 'UseItem': return `Use ${kind(first.item)}`;
    case 'UseItem JamTarget': return `Jam ${kind(second.target)}`;
    case 'UseItem Steal': return `Steal ${kind(second.owner)} ${kind(second.item)}`;
    case 'UseItem Steal JamTarget': return `StealJam ${kind(second.owner)} ${kind(third.target)}`;
    default: assert.fail(`unexpected sm chain ${moves.map(kind).join(' ')}`);
  }
};

function checkMenu(game, s, x, request) {
  const seat = seatNumber(request.seat);
  const kept = new Map();
  for (const chain of smChains(x, seat)) if (!kept.has(chainKey(chain))) kept.set(chainKey(chain), chain);
  const moves = [request.moves.head, ...array(request.moves.tail)];
  same('menus', 'menu is the deduped sm chains', [...kept.keys()].sort(), moves.map(moveKey).sort(), game);
  moves.forEach((move, i) => {
    const sm = kept.get(moveKey(move));
    const head = array(SA.chain(s, i)).slice(0, sm.length).map(step => ({ seat: seatNumber(step.seat), move: step.move }));
    same('menus', `move ${moveKey(move)} is sm's first-slot chain`, sm.map(move => ({ seat, move })), head, game);
  });
}

function otherHidden(world) {
  const other = xs => list([...array(xs)].reverse());
  const decks = world.decks;
  return { gun: list(shuffled(array(world.gun))), decks: { ...decks, two: other(decks.two), three: other(decks.three), four: other(decks.four) } };
}

function checkPrivacy(game, s) {
  const { gun, decks } = otherHidden(s.world);
  const swapped = N('replace_hidden')(s, gun, decks);
  same('privacy', 'board', N('point')(s).board, N('point')(swapped).board, game);
  for (const seat of game.seats) same('privacy', `hear seat ${seat}`, D('hear')(notesOf(s), seatTag(seat)), D('hear')(notesOf(swapped), seatTag(seat)), game);
}

// The state with every other seat's items gone, to see whether a take's pool
// was cut by another seat's items (a table cap binding across seats).
function alone(x, seat) {
  const key = `s${seat}`;
  const empty = { $: 'Slots', ...Object.fromEntries(Array.from({ length: 8 }, (_, i) => [`s${i}`, { $: 'None' }])) };
  const others = (ring, f) => Object.fromEntries(Object.entries(ring).map(([k, v]) => [k, /^s[0-3]$/.test(k) && k !== key ? f(v) : v]));
  return { ...x, players: others(x.players, p => ({ ...p, slots: empty })), grabs: { ...x.grabs, holding: others(x.grabs.holding, () => ({ $: 'None' })) } };
}

// Replays a chain on sm. Each take must go to the next seat after the last
// taker that may take, cycling in socket order from the seat after the first
// shooter; each place must be the holder's first free slot. Counts distributions
// whose takes saw a pool cut by another seat's items.
function watchDistributions(game, x, steps) {
  for (const step of steps) {
    let n = step.answer;
    if (kind(step) === 'ChoiceStep') {
      const prompts = array(D('prompts')(M('request')(x)));
      const prompt = prompts.find(p => seatNumber(p.seat) === seatNumber(step.seat));
      n = D('prompt.answer')(prompt, maybe(D('prompt.index')(prompt, step.move)));
      if (kind(step.move) === 'Grab') {
        const takers = prompts.filter(p => array(p.menu.tail).length === 0 && kind(p.menu.head) === 'Grab').map(p => seatNumber(p.seat));
        const order = [...game.seats.filter(s => s > game.lastTaker), ...game.seats.filter(s => s <= game.lastTaker)];
        same('schedule', 'take goes round-robin', order.find(s => takers.includes(s)), seatNumber(step.seat), game);
        game.lastTaker = seatNumber(step.seat);
        const pool = state => array(SA['sm/items:pool'](state, step.seat)).length;
        if (pool(x) < pool(alone(x, seatNumber(step.seat)))) game.bound.add(game.distribution);
      }
      if (kind(step.move) === 'Place') same('schedule', 'place in the first free slot', prompt.menu.head, step.move, game);
    }
    const next = M('answer')(x, n);
    if (array(next.notes).some(note => kind(note) === 'Shown' && kind(note.event) === 'GrabbingBegan')) {
      game.distribution++;
      coverage.distributions++;
      game.lastTaker = seatNumber(next.state.world.first_turn);
    }
    x = next.state;
  }
}

const answerFor = request => kind(request) === 'Draw' ? drawAnswer(Number(request.range.extra) + 2) : moveAnswer(1 + array(request.moves.tail).length);

// Plays up to `limit` answers; returns how many it took to finish, or null
// (a whole game that has not finished fails with its tape).
function play(config, label, seats, limit, whole) {
  const started = N('start')(config);
  const game = { label, config, seats, tape: [], distribution: 0, bound: new Set(), lastTaker: null };
  let s = started.state;
  const smStart = M('start')(config);
  same('refines', 'start', { state: smStart.state, notes: smStart.notes }, { state: SA.embed(s), notes: started.notes }, game);
  for (let step = 0; step < limit; step++) {
    const x = SA.embed(s);
    checkValid(game, `step ${step}`, x);
    const point = N('point')(s), smPoint = M('point')(x);
    same('board', `step ${step}`, smPoint.board, point.board, game);
    checkPrivacy(game, s);
    coverage.points++;
    const request = point.request;
    if (kind(request) === 'Finished') { capBound[seats.length] += game.bound.size; return step; }
    if (kind(s.phase) === 'Stalled') throw new Mismatch(`Stalled at ${JSON.stringify(game.tape)} in ${label}`);
    if (kind(request) === 'Stuck') throw new Mismatch(`Stuck at ${JSON.stringify(game.tape)} in ${label}`);
    if (kind(request) === 'Draw') {
      same('draws', `step ${step}`, { $: 'Draw', label: request.label, range: request.range }, smPoint.request, game);
      if (kind(request.label) === 'ItemChoice') coverage.itemDraws++;
    } else checkMenu(game, s, x, request);
    const n = answerFor(request);
    game.tape.push(n);
    const next = N('answer')(s, n);
    const steps = SA.chain(s, n);
    if (kind(request) === 'Choose') moveKinds[kind([request.moves.head, ...array(request.moves.tail)].at(Math.min(n, array(request.moves.tail).length)))]++;
    const walked = maybe(SA.walk(x, steps));
    if (walked === null) throw new Mismatch(`walk refused the chain at step ${step} in ${label}: ${json(array(steps))}\nrepro: ${JSON.stringify({ tape: game.tape, config: normalize(config) })}`);
    same('refines', `step ${step}`, { state: SA.embed(next.state), notes: next.notes }, { state: walked.state, notes: walked.notes }, game);
    watchDistributions(game, x, array(steps));
    s = next.state;
  }
  if (whole) throw new Mismatch(`unfinished after ${limit} answers in ${label}\nrepro: ${JSON.stringify({ tape: game.tape, config: normalize(config) })}`);
  capBound[seats.length] += game.bound.size;
  return null;
}

const started = performance.now();
try {
  for (const seats of [2, 3, 4]) {
    for (let trial = 0; trial < GAMES_PER_TABLE; trial++) {
      if (play(randomConfig(seats), `${seats} seats #${trial}`, sockets(seats), MAX_STEPS, false) !== null) coverage.prefixesFinished++;
      coverage.prefixes++;
    }
    for (let trial = 0; trial < COMPLETE_PER_TABLE; trial++) {
      const answers = play(randomConfig(seats), `${seats} seats whole game #${trial}`, sockets(seats), COMPLETE_STEPS, true);
      coverage.complete++;
      coverage.longest = Math.max(coverage.longest, answers);
    }
  }
} catch (error) {
  if (!(error instanceof Mismatch) && !(error instanceof assert.AssertionError)) throw error;
  console.error(error.message);
  process.exitCode = 1;
} finally {
  rmSync(dir, { recursive: true });
}
if (process.exitCode !== 1) {
  assert.ok(Object.values(moveKinds).every(n => n > 0) && coverage.itemDraws > 0 && capBound[3] + capBound[4] > 0, 'fuzz plays every kind of move, item draws and cap-bound distributions');
  console.log(`simple fuzz: ${coverage.prefixes} prefixes of ${MAX_STEPS} answers (${coverage.prefixesFinished} finished), ${coverage.complete} whole games (longest ${coverage.longest} answers), ${coverage.points} points, ${((performance.now() - started) / 1000).toFixed(0)} s; checks ${JSON.stringify(count)}; moves ${JSON.stringify(moveKinds)}; ${JSON.stringify(coverage)}; cap-bound distributions by seats ${JSON.stringify(capBound)}`);
}
