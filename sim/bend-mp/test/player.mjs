// Properties of the minimax player (player/main.bend) over positions from
// seeded random games of the simple machine. Every position is built from one
// player's own log, as a caller would; the true state is used only to check
// that certain outcomes really happen.
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { config, round, list, array, kind, seatNumber, tag } from './reference-adapter.mjs';
import { build, makeRandom } from './machine-items-lib.mjs';

const GAMES = Number(process.env.PLAYER_GAMES ?? 2);
const WIN = 1000000;

const dir = mkdtempSync(join(tmpdir(), 'bend-mp-player-'));
const P = (await import(build(dir, 'player', '../player/main.bend'))).default;
rmSync(dir, { recursive: true });
const S = name => P[`../simple/main.${name}`], D = name => P[`../domain.${name}`], X = name => P[`search.${name}`];
const { random } = makeRandom(0x706c6179);

const sockets = n => n === 2 ? [1, 3] : Array.from({ length: n }, (_, i) => i);
const seat = n => tag(`Seat${n}`);
const json = x => JSON.stringify(x, (_, v) => typeof v === 'bigint' ? Number(v) : v);
const close = (a, b, label) => assert.ok(Math.abs(a - b) < 1e-4, `${label}: ${a} vs ${b}`);
const sum = xs => xs.reduce((a, b) => a + b, 0);
const count = {};
const checked = name => { count[name] = (count[name] ?? 0) + 1; };
const spent = {};
const timed = (name, f) => (...args) => { const t = performance.now(); try { return f(...args); } finally { spent[name] = (spent[name] ?? 0) + performance.now() - t; } };

const position = (cfg, board, log, me) => ({ $: 'types.Position', config: cfg, board, log: list(log), me: seat(me) });
const analyse = (pos, depth, budget) => P.analyse(pos, BigInt(depth), BigInt(budget));
const lines = analysis => array(analysis.lines);
const menu = request => [request.moves.head, ...array(request.moves.tail)];

// Every Choose point of seeded random games, from the mover's log.
function positions(cfg, players, steps) {
  const found = [];
  let stepped = S('start')(cfg), state = stepped.state;
  const logs = Object.fromEntries(sockets(players).map(s => [s, []]));
  const hear = notes => { for (const s of sockets(players)) logs[s].push(...array(D('hear')(notes, seat(s)))); };
  hear(stepped.notes);
  for (let step = 0; step < steps; step++) {
    const point = S('point')(state), request = point.request;
    if (kind(request) !== 'Choose' && kind(request) !== 'Draw') break;
    let answer;
    if (kind(request) === 'Choose') {
      const me = seatNumber(request.seat);
      found.push({ cfg, state, me, request, log: [...logs[me]], position: position(cfg, point.board, logs[me], me) });
      answer = random() % menu(request).length;
    } else answer = random() % (Number(request.range.extra) + 2);
    stepped = S('answer')(state, BigInt(answer));
    state = stepped.state;
    hear(stepped.notes);
  }
  return found;
}

const tables = { 2: 'TwoSeats', 3: 'ThreeSeats', 4: 'FourSeats' };
const sample = [2, 3, 4].flatMap(n => Array.from({ length: GAMES }, () => positions(D('config.default')(tag(tables[n])), n, 150)).flat());

// A move's observations, computed independently from the notes: worlds group
// by every public event (public) or by everything the searcher heard
// (private), with the phone's draws expanded.
function observed(worlds, index, me) {
  const outs = [];
  for (const world of worlds) {
    const played = S('answer')(world.state, BigInt(index));
    const request = S('request')(played.state);
    const add = (notes, weight) => outs.push({ weight, public: json(D('public_events')(list(notes))), private: json(D('hear')(list(notes), seat(me))) });
    if (kind(request) === 'Draw' && kind(request.label) === 'PhoneIndex') {
      const values = Number(request.range.extra) + 2;
      for (let k = 0; k < values; k++) add([...array(played.notes), ...array(S('answer')(played.state, BigInt(k)).notes)], world.weight / values);
    } else add(array(played.notes), world.weight);
  }
  return outs;
}
const masses = (outs, key) => [...Map.groupBy(outs, out => out[key]).values()].map(group => sum(group.map(out => out.weight))).sort();

function checkOutcomes(pos) {
  const built = P['belief.build'](pos.position);
  assert.equal(kind(built), 'Built', built.reason);
  const { public: pub, private: priv } = built.belief;
  for (const [index] of menu(pos.request).entries()) {
    const branches = array(X('outcomes')(pub, priv, BigInt(index), seat(pos.me)));
    close(sum(branches.map(b => b.public_p)), 1, 'public probabilities sum to one');
    close(sum(branches.map(b => b.private_p)), 1, 'private probabilities sum to one');
    for (const b of branches) {
      close(sum(array(b.public).map(w => w.weight)), 1, 'a public belief is normalized');
      if (b.private_p > 0) close(sum(array(b.private).map(w => w.weight)), 1, 'a private belief is normalized');
    }
    const ours = observed(array(pub), index, pos.me), mine = observed(array(priv), index, pos.me);
    const publicMasses = branches.filter(b => b.public_p > 0).map(b => b.public_p).sort();
    assert.deepEqual(publicMasses.length, masses(ours, 'public').length, 'one public branch per public observation');
    publicMasses.forEach((m, i) => close(m, masses(ours, 'public')[i], 'public observation mass'));
    const privateMasses = branches.filter(b => b.private_p > 0).map(b => b.private_p).sort();
    assert.deepEqual(privateMasses.length, masses(mine, 'private').length, 'one private branch per private observation');
    privateMasses.forEach((m, i) => close(m, masses(mine, 'private')[i], 'private observation mass'));
    checked('outcomes');
  }
}

function checkAnalysis(analysis, depth, budget) {
  assert.equal(kind(analysis), 'Analysed', analysis.reason);
  const ls = lines(analysis);
  assert.ok(ls.every(l => l.score >= 0 && l.score <= WIN), 'scores are win probabilities');
  const best = Math.max(...ls.map(l => l.score));
  assert.equal(analysis.score, best, 'the score is the best line');
  assert.equal(Number(analysis.best), ls.findIndex(l => l.score === best), 'ties keep the first move');
  assert.ok(Number(analysis.nodes) <= budget, 'the budget bounds the nodes');
  assert.equal(analysis.limited, Number(analysis.depth) < depth, 'only a spent budget stops short');
  ls.forEach((l, i) => {
    assert.equal(Number(l.index), i);
    assert.ok(array(l.pv).length >= 1 && array(l.pv).length <= Number(analysis.depth) || Number(analysis.depth) === 0, 'a PV names at most depth decisions');
  });
  checked('analysis');
}

// Score 1,000,000 or 0 at depth one is certain over the private belief, so
// the true game must agree.
function checkCertain(pos, analysis) {
  for (const l of lines(analysis)) {
    if (l.score !== WIN && l.score !== 0) continue;
    let played = S('answer')(pos.state, l.index);
    const request = S('request')(played.state);
    if (kind(request) === 'Draw' && kind(request.label) === 'PhoneIndex') played = S('answer')(played.state, 0n);
    const events = array(D('public_events')(played.notes));
    const won = events.find(e => kind(e) === 'RoundWon');
    const died = events.some(e => kind(e) === 'Died' && seatNumber(e.seat) === pos.me);
    if (l.score === WIN) assert.ok(won && seatNumber(won.seat) === pos.me, 'a certain win wins the true game');
    else assert.ok(died || (won && seatNumber(won.seat) !== pos.me), 'a certain loss loses the true game');
    checked(l.score === WIN ? 'certain win' : 'certain loss');
  }
}

function checkDeeper(pos, shallow) {
  const wins = lines(shallow).filter(l => l.score === WIN).map(l => Number(l.index));
  if (wins.length === 0) return;
  for (const depth of [2, 3]) {
    const deep = analyse(pos.position, depth, 4000);
    checkAnalysis(deep, depth, 4000);
    if (Number(deep.depth) === 0) continue;
    assert.equal(deep.score, WIN, 'a deeper search keeps a forced win');
    for (const i of wins) assert.equal(lines(deep)[i].score, WIN, 'a deeper search keeps every forced win');
    checked('deeper forced win');
  }
}

// A spent budget publishes the last finished depth, exactly as a search to
// that depth alone would score it.
function checkDeepening(pos) {
  const limited = analyse(pos.position, 4, 1500);
  checkAnalysis(limited, 4, 1500);
  if (!limited.limited || Number(limited.depth) === 0) return;
  const fresh = analyse(pos.position, Number(limited.depth), 1000000);
  assert.equal(fresh.limited, false);
  assert.deepEqual(json(lines(fresh)), json(lines(limited)), 'iterative deepening publishes a finished iteration');
  checked('deepening');
}

function checkPolicy(pos, analysis) {
  for (const gap of [0, 50000, WIN]) {
    const seen = new Set();
    for (const seed of [1, 2, 3, 4, 5, 6, 7, 8]) {
      const level = { $: 'types.Level', depth: 1n, budget: 100000n, gap, seed };
      const pick = P.choose(pos.position, level);
      if (seed === 1) assert.deepEqual(json(P.choose(pos.position, level)), json(pick), 'choose is deterministic for a seed');
      assert.equal(kind(pick), 'Picked');
      const line = lines(pick.analysis)[Number(pick.index)];
      assert.ok(line.score + gap >= pick.analysis.score, 'the pick is within the gap of the best');
      seen.add(Number(pick.index));
    }
    if (gap === 0) assert.ok([...seen].every(i => lines(analysis)[i].score === analysis.score), 'a zero gap plays a best move');
    checked('policy');
  }
  for (const l of lines(analysis)) {
    const r = P.regret(analysis, l.index);
    assert.equal(kind(r), 'Some');
    assert.ok(r.value >= 0);
  }
  assert.deepEqual(json(P.regret(analysis, analysis.best)), json({ $: 'Some', value: 0 }), 'the best move has no regret');
  assert.equal(kind(P.regret(analysis, BigInt(lines(analysis).length))), 'None', 'an index past the menu has no regret');
  checked('regret');
}

// The public values, which opponents decide by, do not move when the
// searcher's own clues are removed from its log. A Moves task's depth counts
// the decisions after its own, so every fourth position searches my move and
// the reply to it, where opponents pick by public value, and the rest search
// my move alone.
let privateMattered = 0, clued = 0;
function checkPublicOnly(pos) {
  if (!pos.log.some(h => kind(h) === 'Learned')) return;
  const replies = clued++ % 4 === 0;
  const withClues = P['belief.build'](pos.position).belief;
  const without = P['belief.build'](position(pos.cfg, pos.position.board, pos.log.filter(h => kind(h) !== 'Learned'), pos.me)).belief;
  assert.equal(json(without.public), json(withClues.public));
  const scores = belief => {
    const options = X('options.of')(list(menu(pos.request)), 0n);
    const task = { $: 'search.Moves', depth: replies ? 1n : 0n, public: belief.public, private: belief.private, options, scored: list([]), nodes: 0n };
    const result = X('search')(X('fuel')(1000000n), task, seat(pos.me), 1000000n);
    assert.equal(kind(result), 'Scores');
    return array(result.scored);
  };
  const a = scores(withClues), b = scores(without);
  assert.deepEqual(a.map(s => s.public), b.map(s => s.public), 'opponents decide from public information only');
  if (json(a.map(s => s.private)) !== json(b.map(s => s.private))) privateMattered++;
  checked(replies ? 'public only, with replies' : 'public only');
}

// Two seats, one HP, only live shells, no items: shooting the other seat
// wins and shooting oneself loses, at every depth.
function checkForcedWin() {
  const cfg = config(2, [round({ health: 1, live: 2, blank: 0 })]);
  const pos = positions(cfg, 2, 20)[0];
  const moves = menu(pos.request);
  for (const depth of [1, 2, 3]) {
    const analysis = analyse(pos.position, depth, 100000);
    checkAnalysis(analysis, depth, 100000);
    moves.forEach((m, i) => assert.equal(lines(analysis)[i].score, seatNumber(m.target) === pos.me ? 0 : WIN, `forced result at depth ${depth}`));
  }
  checked('forced win scenario');
}

function checkInvalid(pos) {
  const other = sockets(pos.cfg.table.$.endsWith('TwoSeats') ? 2 : pos.cfg.table.$.endsWith('ThreeSeats') ? 3 : 4).find(s => s !== pos.me);
  const analysis = analyse({ ...pos.position, me: seat(other) }, 1, 1000);
  assert.equal(kind(analysis), 'Invalid', 'only the player to move is analysed');
  assert.equal(kind(P.choose({ ...pos.position, me: seat(other) }, { $: 'types.Level', depth: 1n, budget: 1000n, gap: 0, seed: 0 })), 'Unavailable');
  assert.equal(kind(P.regret(analysis, 0n)), 'None');
  checked('invalid');
}

const started = performance.now();
const t = Object.fromEntries(Object.entries({ checkForcedWin, checkCertain, checkDeeper, checkPublicOnly, checkOutcomes, checkPolicy, checkDeepening, checkInvalid, analyse }).map(([k, f]) => [k, timed(k, f)]));
t.checkForcedWin();
sample.forEach((pos, i) => {
  const analysis = t.analyse(pos.position, 1, 100000);
  checkAnalysis(analysis, 1, 100000);
  t.checkCertain(pos, analysis);
  t.checkDeeper(pos, analysis);
  t.checkPublicOnly(pos);
  if (i % 4 === 0) t.checkOutcomes(pos);
  if (i % 8 === 0) t.checkPolicy(pos, analysis);
  if (i % 16 === 0) t.checkDeepening(pos);
  if (i % 32 === 0) t.checkInvalid(pos);
});
assert.ok(count['certain win'] > 0 && count['deeper forced win'] > 0 && count['public only'] > 0 && count['public only, with replies'] > 0 && privateMattered > 0 && count.deepening > 0, `every property ran on a case that matters: ${json(count)}`);
console.log(`player: ${sample.length} positions, ${((performance.now() - started) / 1000).toFixed(0)} s; checks ${json(count)}; private clues changed private scores ${privateMattered} times`);
if (process.env.PLAYER_PROFILE) console.log(json(Object.fromEntries(Object.entries(spent).map(([k, v]) => [k, Math.round(v / 1000)]))));
