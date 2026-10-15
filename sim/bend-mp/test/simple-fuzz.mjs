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
import { build, makeRandom, normalize, asAbstract } from './machine-items-lib.mjs';

const GAMES_PER_TABLE = Number(process.env.FUZZ_GAMES ?? 500);
const MAX_STEPS = Number(process.env.FUZZ_STEPS ?? 60);

const dir = mkdtempSync(join(tmpdir(), 'bend-mp-simple-fuzz-'));
const bridge = build(dir, 'bridge', '../simple-abstract.bend'), abstract = build(dir, 'abstract', '../abstract.bend');
const SA = (await import(bridge)).default, A = (await import(abstract)).default;
const N = name => SA[`simple/main.${name}`], M = name => SA[`sm/main.${name}`], D = name => SA[`domain.${name}`];
const { random, randomConfig } = makeRandom(0x73696d70);

const sockets = n => n === 2 ? [1, 3] : Array.from({ length: n }, (_, i) => i);
const seatTag = s => ({ $: `domain.Seat${s}` });
const json = x => JSON.stringify(normalize(x));
const count = { refines: 0, valid: 0, board: 0, draws: 0, menus: 0, privacy: 0, schedule: 0 };
const coverage = { games: 0, points: 0, finished: 0, itemDraws: 0, handouts: 0 };
const moveKinds = { Shoot: 0, Use: 0, Jam: 0, Steal: 0, StealJam: 0 };
const capBound = { 2: 0, 3: 0, 4: 0 };

class Mismatch extends Error {}
const same = (property, label, expected, actual, game) => {
  try { assert.deepEqual(normalize(actual), normalize(expected)); } catch (error) {
    throw new Mismatch(`${property} failed (${label})\n${error.message}\nrepro: ${JSON.stringify({ tape: game.tape, config: normalize(game.config) })}`);
  }
  count[property]++;
};

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
  const shuffled = xs => { const ys = [...xs]; for (let i = ys.length - 1; i > 0; i--) { const j = random() % (i + 1); [ys[i], ys[j]] = [ys[j], ys[i]]; } return ys; };
  const other = xs => list([...array(xs)].reverse());
  const decks = world.decks;
  return { gun: list(shuffled(array(world.gun))), decks: { ...decks, two: other(decks.two), three: other(decks.three), four: other(decks.four) } };
}

function checkPrivacy(game, s) {
  const { gun, decks } = otherHidden(s.world);
  const swapped = N('replace_hidden')(s, gun, decks);
  same('privacy', 'board', N('point')(s).board, N('point')(swapped).board, game);
  for (const seat of game.seats) same('privacy', `hear seat ${seat}`, D('hear')(s.notes, seatTag(seat)), D('hear')(swapped.notes, seatTag(seat)), game);
}

// The state with every other seat's items gone, to see whether a take's pool
// was cut by another seat's items (a table cap binding across seats).
function alone(x, seat) {
  const key = `s${seat}`;
  const empty = { $: 'domain.Slots', ...Object.fromEntries(Array.from({ length: 8 }, (_, i) => [`s${i}`, { $: 'None' }])) };
  const others = (ring, f) => Object.fromEntries(Object.entries(ring).map(([k, v]) => [k, /^s[0-3]$/.test(k) && k !== key ? f(v) : v]));
  return { ...x, players: others(x.players, p => ({ ...p, slots: empty })), grabs: { ...x.grabs, holding: others(x.grabs.holding, () => ({ $: 'None' })) } };
}

// Replays a chain on sm. Each take must go to the next seat after the last
// taker that may take, cycling in socket order from the seat after the first
// shooter; each place must be the holder's first free slot. Counts handouts
// whose takes saw a pool cut by another seat's items.
function watchHandouts(game, x, steps) {
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
        const pool = state => array(SA['sm/items.pool'](state, step.seat)).length;
        if (pool(x) < pool(alone(x, seatNumber(step.seat)))) game.bound.add(game.handout);
      }
      if (kind(step.move) === 'Place') same('schedule', 'place in the first free slot', prompt.menu.head, step.move, game);
    }
    const next = M('answer')(x, n);
    if (array(next.notes).some(note => kind(note) === 'Shown' && kind(note.event) === 'GrabbingBegan')) {
      game.handout++;
      coverage.handouts++;
      game.lastTaker = seatNumber(next.state.world.first_turn);
    }
    x = next.state;
  }
}

function answerFor(request) {
  if (kind(request) === 'Draw') return random() % 8 === 0 ? 50 + random() % 50 : random() % (Number(request.range.extra) + 2);
  const length = 1 + array(request.moves.tail).length;
  return random() % 16 === 0 ? length + random() % 4 : random() % length;
}

function play(config, label, seats) {
  const started = N('start')(config);
  const game = { label, config, seats, tape: [], handout: 0, bound: new Set(), lastTaker: null };
  let s = started.state;
  const smStart = M('start')(config);
  same('refines', 'start', { state: smStart.state, notes: smStart.notes }, { state: SA.embed(s), notes: started.notes }, game);
  for (let step = 0; step < MAX_STEPS; step++) {
    const x = SA.embed(s);
    checkValid(game, `step ${step}`, x);
    const point = N('point')(s), smPoint = M('point')(x);
    same('board', `step ${step}`, smPoint.board, point.board, game);
    checkPrivacy(game, s);
    coverage.points++;
    const request = point.request;
    if (kind(request) === 'Finished') { coverage.finished++; break; }
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
    watchHandouts(game, x, array(steps));
    s = next.state;
  }
  capBound[seats.length] += game.bound.size;
}

const started = performance.now();
try {
  for (const seats of [2, 3, 4]) for (let trial = 0; trial < GAMES_PER_TABLE; trial++) {
    play(asAbstract(randomConfig(seats)), `${seats} seats #${trial}`, sockets(seats));
    coverage.games++;
  }
} catch (error) {
  if (!(error instanceof Mismatch) && !(error instanceof assert.AssertionError)) throw error;
  console.error(error.message);
  process.exitCode = 1;
} finally {
  rmSync(dir, { recursive: true });
}
if (process.exitCode !== 1) {
  assert.ok(Object.values(moveKinds).every(n => n > 0) && coverage.itemDraws > 0 && capBound[3] + capBound[4] > 0, 'fuzz plays every kind of move, item draws and cap-bound handouts');
  console.log(`simple fuzz: ${coverage.games} games, ${coverage.points} points, ${((performance.now() - started) / 1000).toFixed(0)} s; checks ${JSON.stringify(count)}; moves ${JSON.stringify(moveKinds)}; ${JSON.stringify(coverage)}; cap-bound handouts by seats ${JSON.stringify(capBound)}`);
}
