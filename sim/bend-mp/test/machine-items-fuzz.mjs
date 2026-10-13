// Law-property fuzz for the item machine. LAWS.bend proves these laws only for
// no-item configs; here each is checked as a property at every request point
// of seeded random item games (and some no-item ones), machine against reference.
import assert from 'node:assert/strict';
import { list, array, kind, seatNumber, tag, requestJSON } from './reference-adapter.mjs';
import { loadModels, makeRandom, normalize, asAbstract } from './machine-items-lib.mjs';

const GAMES_PER_TABLE = Number(process.env.FUZZ_GAMES ?? 500);
const SKIPPED = new Set((process.env.FUZZ_SKIP ?? '').split(',')); // lets fuzz_mutations.py see what the other properties catch alone
const MAX_STEPS = Number(process.env.FUZZ_STEPS ?? 50);

const { M, R, A, close } = await loadModels('bend-mp-item-fuzz-', { abstract: true });
const mapped = state => A.ref(asAbstract(state));
const { random, randomConfig, answerFor } = makeRandom(0x66757a7a);

const OBSERVE = '../domain.observe', HEAR = '../domain.hear', RESOLVE = '../domain.resolve';
const sockets = n => n === 2 ? [1, 3] : Array.from({ length: n }, (_, i) => i);
const count = { step_matches: 0, observe_matches: 0, legal_exact: 0, legal_accepted: 0, privacy: 0, reachable_valid: 0 };
const coverage = { games: 0, boundaries: 0, noItemGames: 0, itemGames: 0, choosePoints: 0, finished: 0, itemMoves: 0, hiddenChanged: 0 };

class Mismatch extends Error {}
const same = (property, label, expected, actual, game, detail = '') => {
  if (SKIPPED.has(property)) return;
  try { assert.deepEqual(normalize(actual), normalize(expected)); } catch (error) {
    const reproduction = { property, detail, tape: game.tape, config: normalize(game.config) };
    throw new Mismatch(`${property} failed (${label})${detail ? `: ${detail}` : ''}\n${error.message}\nrepro: ${JSON.stringify(reproduction)}`);
  }
  count[property]++;
};

const shuffled = xs => {
  const ys = [...xs];
  for (let i = ys.length - 1; i > 0; i--) { const j = random() % (i + 1); [ys[i], ys[j]] = [ys[j], ys[i]]; }
  return ys;
};
const rotated = xs => xs.length < 2 ? xs : [...xs.slice(1), xs[0]];

// Same shells in another order, and every deck rotated (reversed when rotation is a no-op).
function otherHidden(state) {
  const gun = array(state.world.gun);
  const decks = state.world.decks;
  const other = xs => {
    const ys = array(xs);
    const r = rotated(ys);
    return list(JSON.stringify(normalize(r)) === JSON.stringify(normalize(ys)) ? [...ys].reverse() : r);
  };
  return { gun: list(shuffled(gun)), decks: { ...decks, two: other(decks.two), three: other(decks.three), four: other(decks.four) } };
}

function checkObservations(game, label, mPoint, rPoint, mNotes, rNotes) {
  for (const s of game.seats) {
    const seat = tag(`Seat${s}`);
    same('observe_matches', `${label} observe seat ${s}`, R[OBSERVE](rPoint, seat), M[OBSERVE](mPoint, seat), game);
    same('observe_matches', `${label} hear seat ${s}`, R[HEAR](rNotes, seat), M[HEAR](mNotes, seat), game);
  }
}

function checkLegal(game, mRequest, rRequest) {
  same('legal_exact', 'request', requestJSON(rRequest), requestJSON(mRequest), game);
  if (kind(mRequest) !== 'Choose') return;
  coverage.choosePoints++;
  const menus = requestJSON(mRequest).menus;
  let n = 0;
  for (const [s, menu] of Object.entries(menus)) for (const [index, move] of menu.entries()) {
    const resolved = M[RESOLVE](mRequest, n++);
    assert.equal(kind(resolved), 'Chose', 'every offered index resolves to a choice');
    const { choice } = resolved;
    same('legal_accepted', `seat ${s} index ${index}`, { seat: Number(s), index, move }, { seat: seatNumber(choice.seat), index: Number(choice.index), move: requestMove(choice.move) }, game, 'resolved choice is the offered move');
    if ('UseItem' in move || 'Steal' in move || 'Grab' in move || 'Place' in move) coverage.itemMoves++;
    same('legal_accepted', `seat ${s} index ${index}`, true, R.VerifyPacket(game.r, choice), game, `reference rejects offered move ${JSON.stringify(move)}`);
  }
}

const requestMove = move => {
  const slot = m => Number(kind(m.slot).slice(4));
  switch (kind(move)) {
    case 'PickUp': return { PickUp: true };
    case 'Shoot': return { Shoot: seatNumber(move.target) };
    case 'UseItem': return { UseItem: [slot(move), kind(move.item)] };
    case 'Grab': return { Grab: true };
    case 'Place': return { Place: slot(move) };
    case 'JamTarget': return { JamTarget: seatNumber(move.target) };
    case 'Steal': return { Steal: [seatNumber(move.owner), slot(move), kind(move.item)] };
    default: assert.fail(`unknown move ${move.$}`);
  }
};

const RING_TABLE = { Duo: 'TwoSeats', Trio: 'ThreeSeats', Quad: 'FourSeats' };

// A.Valid at a reachable request point: the item normal form, the table
// tie of the seat ring and the Grabs rings, the round bound and the turn facts.
function checkValid(game) {
  const s = asAbstract(game.m);
  same('reachable_valid', 'Valid normal form', s, A.normalize_items(s), game);
  const { grabbing, holding, granted, intake } = game.m.grabs;
  const table = kind(game.m.world.config.table);
  same('reachable_valid', 'Valid table tie', Array(5).fill(table), [game.m.players, grabbing, holding, granted, intake].map(ring => RING_TABLE[kind(ring)]), game);
  same('reachable_valid', 'Valid facts', { bounded: true, ready: true }, { bounded: A.bounded(s), ready: A.items_ready(s.phase, s.world) }, game);
}

function checkPrivacyAtPoint(game) {
  const { gun, decks } = otherHidden(game.m);
  const swapped = M.replace_hidden(game.m, gun, decks);
  if (JSON.stringify(normalize(gun)) !== JSON.stringify(normalize(game.m.world.gun)) || JSON.stringify(normalize(decks)) !== JSON.stringify(normalize(game.m.world.decks))) coverage.hiddenChanged++;
  const point = M.point(game.m), swappedPoint = M.point(swapped);
  for (const s of game.seats) {
    const seat = tag(`Seat${s}`);
    same('privacy', `seat ${s} observe`, M[OBSERVE](point, seat), M[OBSERVE](swappedPoint, seat), game, 'observe changed with hidden state');
    same('privacy', `seat ${s} hear`, M[HEAR](game.m.notes, seat), M[HEAR](swapped.notes, seat), game, 'hear changed with hidden state');
  }
}

function play(config, label, seats) {
  const r = R.start(config), m = M.start(config);
  const game = { label, config, seats, tape: [], r: r.state, m: m.state };
  let rNotes = r.notes, mNotes = m.notes;
  same('step_matches', 'start notes', rNotes, mNotes, game);
  same('step_matches', 'start state', game.r, mapped(game.m), game, 'A.ref of the machine state');
  same('step_matches', 'start point', R.point(game.r), M.point(game.m), game);
  for (let step = 0; step < MAX_STEPS; step++) {
    const mPoint = M.point(game.m), rPoint = R.point(game.r);
    checkObservations(game, `step ${step}`, mPoint, rPoint, mNotes, rNotes);
    checkLegal(game, mPoint.request, rPoint.request);
    checkPrivacyAtPoint(game);
    checkValid(game);
    coverage.boundaries++;
    const request = requestJSON(rPoint.request);
    if (request.kind === 'Finished') { coverage.finished++; return; }
    if (request.kind === 'Stuck') assert.fail(`Stuck at ${JSON.stringify(game.tape)} in ${label}`);
    const n = answerFor(request);
    game.tape.push(n);
    const nr = R.answer(game.r, n), nm = M.answer(game.m, n);
    same('step_matches', 'answer notes', nr.notes, nm.notes, game);
    same('step_matches', 'answer state', nr.state, mapped(nm.state), game, 'A.ref of the machine state');
    same('step_matches', 'answer point', R.point(nr.state), M.point(nm.state), game);
    game.r = nr.state; game.m = nm.state; rNotes = nr.notes; mNotes = nm.notes;
  }
}

const started = performance.now();
try {
  for (const seats of [2, 3, 4]) for (let trial = 0; trial < GAMES_PER_TABLE; trial++) {
    const config = randomConfig(seats);
    const anyItems = array(list(Object.values(config.plan).filter(r => r?.items))).some(r => Object.entries(r.items).some(([k, rule]) => k !== '$' && rule.enabled));
    coverage[anyItems ? 'itemGames' : 'noItemGames']++;
    play(config, `${seats} seats #${trial}`, sockets(seats));
    coverage.games++;
  }
} catch (error) {
  if (!(error instanceof Mismatch) && !(error instanceof assert.AssertionError)) throw error;
  console.error(error.message);
  process.exitCode = 1;
} finally {
  close();
}
if (process.exitCode !== 1) {
  assert.ok(count.legal_accepted > 0 && coverage.itemMoves > 0 && coverage.noItemGames > 0 && coverage.hiddenChanged > 0, 'fuzz reaches item moves, no-item configs and non-trivial hidden swaps');
  console.log(`machine item law fuzz: ${coverage.games} games, ${coverage.boundaries} request points, ${((performance.now() - started) / 1000).toFixed(0)} s; checks ${JSON.stringify(count)}; ${JSON.stringify(coverage)}`);
}
