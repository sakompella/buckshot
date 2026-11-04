// The parallel search prototype (player/parallel.bend) against search.bend, on
// positions from seeded random games. The JS target runs parallel calls one
// after another, so this checks results only; speed needs the native build.
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { list, array, kind, seatNumber, tag } from './reference-adapter.mjs';
import { build, makeRandom } from './machine-items-lib.mjs';

const GAMES = Number(process.env.PARALLEL_GAMES ?? 2);

const dir = mkdtempSync(join(tmpdir(), 'bend-mp-parallel-'));
const P = (await import(build(dir, 'parallel', '../player/parallel.bend'))).default;
rmSync(dir, { recursive: true });
const S = name => P[`../simple/main:${name}`], D = name => P[`../domain:${name}`];
const { random } = makeRandom(0x70617261);

const sockets = n => n === 2 ? [1, 3] : Array.from({ length: n }, (_, i) => i);
const seat = n => tag(`Seat${n}`);
const menu = request => [request.moves.head, ...array(request.moves.tail)];

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
      found.push({ $: 'Position', config: cfg, board: point.board, log: list(logs[me]), me: seat(me) });
      answer = random() % menu(request).length;
    } else answer = random() % (Number(request.range.extra) + 2);
    stepped = S('answer')(state, Number(answer));
    state = stepped.state;
    hear(stepped.notes);
  }
  return found;
}

const tables = { 2: 'TwoSeats', 3: 'ThreeSeats' };
const sample = n => Array.from({ length: GAMES }, () => positions(D('config.default')(tag(tables[n])), n, 120)).flat();
const two = sample(2), three = sample(3);

const STATIC = { $: 'Static' }, SAMPLED = { $: 'Sampled', count: 7 };
const OFF = { $: 'Off' }, CHARGED = { $: 'Charged' }, FREE = { $: 'Free' };
const lines = a => array(a.lines).map(l => [Number(l.index), Number(l.score), array(l.pv).length, kind(l.reach)]);
const result = a => kind(a) === 'Invalid' ? { invalid: a.reason } : { lines: lines(a), best: Number(a.best), depth: Number(a.depth), limited: a.limited };
const counts = a => kind(a) === 'Invalid' ? {} : { nodes: Number(a.nodes), cached: a.cached };

let checked = 0, limited = 0;
// Under Off and Charged, both modes equal search.bend: without the root fan
// in every field, with it in everything but node and memo counts.
function same(pos, depth, budget, reload, memo) {
  const want = P['search:analyse'](pos, depth, budget, reload, memo);
  const seq = P.analyse(pos, depth, budget, reload, memo, false);
  const fan = P.analyse(pos, depth, budget, reload, memo, true);
  assert.deepEqual({ ...result(seq), ...counts(seq) }, { ...result(want), ...counts(want) }, 'sequential root');
  assert.deepEqual(result(fan), result(want), 'root fan');
  if (kind(want) !== 'Invalid' && !want.limited) assert.equal(Number(fan.nodes), Number(want.nodes), 'unlimited nodes');
  checked++;
  if (want.limited) limited++;
}

for (const pos of two) {
  for (const memo of [OFF, CHARGED]) {
    same(pos, 3, 400, STATIC, memo);
    same(pos, 4, 60, STATIC, memo);
    same(pos, 3, 400, SAMPLED, memo);
  }
}
for (const pos of three) same(pos, 3, 200, STATIC, CHARGED);

// Under Free a budget that never runs out still gives the same scores.
for (const pos of two.slice(0, 20)) {
  const want = P['search:analyse'](pos, 2, 1000000, SAMPLED, FREE), fan = P.analyse(pos, 2, 1000000, SAMPLED, FREE, true);
  if (kind(want) !== 'Invalid') assert.equal(want.limited, false);
  assert.deepEqual(result(fan), result(want), 'free, unlimited');
  checked++;
}

assert.ok(limited > 0, 'some budgets ran out');
console.log(`parallel search: ${checked} analyses equal search.bend (${limited} limited), ${two.length + three.length} positions`);
