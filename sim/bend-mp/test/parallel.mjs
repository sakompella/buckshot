// search.bend with the root fan against search.bend without it, on positions
// from seeded random games. The JS target runs parallel calls one
// after another, so this checks results only; speed needs the native build.
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { list, array, kind, seat, tag } from './reference-adapter.mjs';
import { build, makeRandom, positions } from './machine-items-lib.mjs';

const GAMES = Number(process.env.PARALLEL_GAMES ?? 2);

const dir = mkdtempSync(join(tmpdir(), 'bend-mp-parallel-'));
const P = (await import(build(dir, 'parallel', '../player/search.bend'))).default;
rmSync(dir, { recursive: true });
const S = name => P[`../simple/main:${name}`], D = name => P[`../domain:${name}`];
const { random } = makeRandom(0x70617261);

const positionAt = ({ cfg, board, log, me }) => ({ $: 'Position', config: cfg, board, log: list(log), me: seat(me) });

const tables = { 2: 'TwoSeats', 3: 'ThreeSeats' };
const sample = n => Array.from({ length: GAMES }, () => positions({ S, D, random }, D('config.default')(tag(tables[n])), n, 120, positionAt)).flat();
const two = sample(2), three = sample(3);

const STATIC = { $: 'Static' }, SAMPLED = { $: 'Sampled', count: 7 };
const OFF = { $: 'Off' }, CHARGED = { $: 'Charged' }, FREE = { $: 'Free' };
const moveKey = move => JSON.stringify(move, (_, v) => typeof v === 'bigint' ? String(v) : v);
const lines = a => array(a.lines).map(l => [Number(l.index), Number(l.score), array(l.pv).map(moveKey), kind(l.reach)]);
const result = a => kind(a) === 'Invalid' ? { invalid: a.reason } : { lines: lines(a), best: Number(a.best), depth: Number(a.depth), limited: a.limited };

let checked = 0, limited = 0;
// Under Off and Charged the fan gives the same result in everything but node
// and memo counts.
function same(pos, depth, budget, reload, memo) {
  const want = P.analyse(pos, depth, budget, reload, memo, false);
  const fan = P.analyse(pos, depth, budget, reload, memo, true);
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
  const want = P.analyse(pos, 2, 1000000, SAMPLED, FREE, false), fan = P.analyse(pos, 2, 1000000, SAMPLED, FREE, true);
  if (kind(want) !== 'Invalid') assert.equal(want.limited, false);
  assert.deepEqual(result(fan), result(want), 'free, unlimited');
  checked++;
}

assert.ok(limited > 0, 'some budgets ran out');
console.log(`parallel search: ${checked} analyses equal without the fan (${limited} limited), ${two.length + three.length} positions`);
