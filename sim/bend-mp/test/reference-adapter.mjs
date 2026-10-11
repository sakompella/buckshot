import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

export const list = xs => xs.reduceRight((tail, head) => ({ $: 'Con', head, tail }), { $: 'Nil' });
export function array(xs) {
  const result = [];
  for (; xs.$ === 'Con'; xs = xs.tail) result.push(xs.head);
  assert.equal(xs.$, 'Nil');
  return result;
}
export const kind = value => value.$.split('.').at(-1);
export const seatNumber = seat => Number(kind(seat).slice(4));
export const tag = (name, fields = {}) => ({ $: `../domain.${name}`, ...fields });
export const bool = value => value;
export const seat = n => tag(`Seat${n}`);
export const maybe = value => value === null ? { $: 'None' } : { $: 'Some', value };
export const valueOf = (value, absent = null) => kind(value) === 'None' ? absent : value.value;
export const plain = value => JSON.parse(JSON.stringify(value, (_, x) => typeof x === 'bigint' ? Number(x) : x));

export async function buildReference() {
  const dir = mkdtempSync(join(tmpdir(), 'bend-mp-core-'));
  try {
    const source = process.env.BEND_REFERENCE_SOURCE ?? new URL('../ref/main.bend', import.meta.url).pathname;
    const output = join(dir, 'reference.mjs');
    for (const args of [[source, '--check-only'], [source, '-o', output]]) {
      const result = spawnSync(process.env.BEND ?? 'bend', args, { encoding: 'utf8' });
      if (result.error) throw result.error;
      assert.equal(result.status, 0, `Bend reference failed:
${result.stdout}${result.stderr}`);
    }
    return { R: (await import(output)).default, close: () => rmSync(dir, { recursive: true }) };
  } catch (error) {
    rmSync(dir, { recursive: true });
    throw error;
  }
}

const itemNames = ['saw', 'glass', 'jammer', 'cigarettes', 'beer', 'phone', 'inverter', 'adrenaline', 'remote'];
export function round({ health = 1, live = 1, blank = 0, amount = 0, loads = null, items = {} } = {}) {
  const load = spec => tag('LoadRule', {
    shells: spec.live === null ? tag('RandomShells') : spec.blank === 0
      ? tag('AllLive', { live: tag('Pos', { minus_one: spec.live - 1 }) })
      : tag('FixedShells', { live: spec.live, blank: tag('Pos', { minus_one: spec.blank - 1 }) }),
    items: spec.amount === null ? tag('RandomAmount') : tag('FixedAmount', { amount: spec.amount }),
  });
  const rules = loads ?? Array.from({ length: 4 }, () => ({ live, blank, amount }));
  assert.equal(rules.length, 4);
  return tag('RoundRules', {
    health: health === null ? tag('RandomHealth') : tag('FixedHealth', { health: tag('Pos', { minus_one: health - 1 }) }),
    loads: tag('LoadRules', Object.fromEntries(rules.map((spec, i) => [`l${i}`, load(spec)]))),
    items: tag('ItemRules', Object.fromEntries(itemNames.map(name => [name, tag('ItemRule', {
      enabled: bool(name in items && items[name]?.enabled !== false), per_player: items[name]?.per_player ?? 8, on_table: items[name]?.on_table ?? 32,
    })]))),
  });
}
export function config(seats, rounds = [round()]) {
  assert.ok([2, 3, 4].includes(seats));
  assert.ok([1, 2, 3].includes(rounds.length));
  return tag('Config', {
    table: tag({ 2: 'TwoSeats', 3: 'ThreeSeats', 4: 'FourSeats' }[seats]),
    plan: tag({ 1: 'OneRound', 2: 'TwoRounds', 3: 'ThreeRounds' }[rounds.length], Object.fromEntries(rounds.map((r, i) => [`r${i}`, r]))),
  });
}
export function entries(ring) {
  return Object.entries(ring).filter(([key]) => /^s[0-3]$/.test(key)).map(([key, value]) => [key.slice(1), value]);
}
export function moveJSON(move) {
  switch (kind(move)) {
    case 'PickUp': return { PickUp: true };
    case 'Shoot': return { Shoot: seatNumber(move.target) };
    case 'UseItem': return { UseItem: [Number(kind(move.slot).slice(4)), kind(move.item)] };
    case 'Grab': return { Grab: true };
    case 'Place': return { Place: Number(kind(move.slot).slice(4)) };
    case 'JamTarget': return { JamTarget: seatNumber(move.target) };
    case 'Steal': return { Steal: [seatNumber(move.owner), Number(kind(move.slot).slice(4)), kind(move.item)] };
    default: assert.fail(`unknown Move ${move.$}`);
  }
}
export function requestJSON(request) {
  const type = kind(request);
  if (type === 'Draw') return { kind: type, label: kind(request.label), lo: Number(request.range.lo), hi: Number(request.range.lo) + Number(request.range.extra) + 1 };
  if (type === 'Choose') return { kind: type, menus: Object.fromEntries(entries(request.menus).map(([s, menu]) => [s, array(menu).map(moveJSON)])) };
  assert.ok(['Finished', 'Stuck'].includes(type));
  return { kind: type };
}
export function stateJSON(snapshot) {
  const chosen = valueOf(snapshot.turn);
  const firstDeath = valueOf(snapshot.first_death);
  return {
    round_index: Number(valueOf(snapshot.round_index, -1)), load_index: Number(snapshot.load_index),
    turn: chosen === null ? 5 : seatNumber(chosen), direction: kind(snapshot.direction) === 'Clockwise' ? 'CW' : 'CCW',
    sawed: snapshot.sawed, first_death: firstDeath === null ? null : seatNumber(firstDeath),
    item_amount: Number(snapshot.item_amount), gun: array(snapshot.gun).map(kind), deck: array(snapshot.deck).map(Number),
    seats: Object.fromEntries(entries(snapshot.seats).map(([s, value]) => [s, {
      health: Number(value.health), jammed: value.jammed, jam_checked: value.jam_checked,
      cash: value.cash, slots: array(value.slots).map(slot => { const item = valueOf(slot); return item === null ? null : kind(item); }),
      grabbing: value.grabbing, holding: valueOf(value.holding) === null ? null : kind(value.holding.value),
    }])),
  };
}
export function traceJSON(R, name, config, tape) {
  const result = R.trace(config, list(tape));
  return { config: name, tape, points: array(result.points).map(point => ({ request: requestJSON(point.request), state: stateJSON(point.state) })), end: kind(result.end).slice(3) };
}
