import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { array, config, round, list, jamPair, kind, seat, seatNumber, turnHolder } from './reference-adapter.mjs';

export function build(dir, name, relativeSource) {
  const source = fileURLToPath(new URL(relativeSource, import.meta.url));
  const output = join(dir, `${name}.mjs`);
  for (const args of [[source, '--check-only'], [source, '-o', output]]) {
    const result = spawnSync(process.env.BEND ?? 'bend', args, { encoding: 'utf8' });
    if (result.error) throw result.error;
    const log = `${result.stdout}${result.stderr}`;
    assert.equal(result.status, 0, `Bend ${name} failed:\n${log}`);
    assert.doesNotMatch(log, /SOME (?:PROOFS|TYPES) FAIL/, `Bend ${name} reported a check failure`);
    if (args.includes('--check-only')) assert.match(log, /ALL PROOFS CHECK/);
  }
  return pathToFileURL(output).href;
}

// Builds the machine and the reference to JS modules in a temp dir, and with
// `abstract` also abstract.bend, whose A.ref maps machine states to reference states.
export async function loadModels(prefix, { abstract = false } = {}) {
  const dir = mkdtempSync(join(tmpdir(), prefix));
  try {
    // Every build comes before the first import: Bun caches the directory listing.
    const machine = build(dir, 'machine', '../sm/main.bend');
    const reference = build(dir, 'reference', '../ref/main.bend');
    const mapping = abstract && build(dir, 'abstract', '../abstract.bend');
    const M = (await import(machine)).default;
    const R = (await import(reference)).default;
    const A = mapping && (await import(mapping)).default;
    return { M, R, A, close: () => rmSync(dir, { recursive: true }) };
  } catch (error) {
    rmSync(dir, { recursive: true });
    throw error;
  }
}

export const normalize = value => JSON.parse(JSON.stringify(value));

// Bend's item order (domain.bend item.order), the item list of every test.
export const items = await (async () => {
  const dir = mkdtempSync(join(tmpdir(), 'bend-mp-items-'));
  try {
    const D = (await import(build(dir, 'domain', '../domain.bend'))).default;
    return array(normalize(D['item.order']())).map(item => item.$);
  } finally {
    rmSync(dir, { recursive: true });
  }
})();

// The item steps of a test session: the session gives request, moves,
// snapshot, move and answer, and referenceOf reads its reference state.
export const itemSteps = referenceOf => ({
  draws() {
    for (let fuel = 0; this.request.kind === 'Draw'; fuel++) {
      assert.ok(fuel < 64, 'draw closure terminates');
      assert.notEqual(this.request.label, 'ItemChoice', 'grant must select its desired item');
      this.answer(this.request.label === 'ShuffleSwap' ? this.request.hi : 0);
    }
  },
  grant(s, item) {
    this.move(s, move => 'Grab' in move);
    if (this.request.kind === 'Draw') {
      assert.equal(this.request.label, 'ItemChoice');
      const pool = array(referenceOf(this).frame.continuation.pool).map(kind);
      const index = pool.indexOf(item);
      assert.ok(index >= 0, `${item} is in eligible pool ${pool}`);
      this.answer(index);
    }
    assert.equal(this.snapshot.seats[s].holding, item);
  },
  place(s, slot = 0) { return this.move(s, move => move.Place === slot); },
  distribute(wanted = () => 'Beer') {
    for (let fuel = 0; ; fuel++) {
      assert.ok(fuel < 256, 'distribution terminates');
      this.draws();
      assert.equal(this.request.kind, 'Choose');
      if (this.moves.some(({ move }) => 'PickUp' in move)) return;
      const choice = this.moves[0];
      if ('Grab' in choice.move) this.grant(choice.seat, wanted(choice.seat, this.snapshot));
      else if ('Place' in choice.move) this.place(choice.seat, choice.move.Place);
      else assert.fail(`unexpected distribution request ${JSON.stringify(this.request)}`);
    }
  },
  use(s, item) { return this.move(s, move => move.UseItem?.[1] === item); },
  shoot(s, target) {
    this.move(s, move => 'PickUp' in move);
    return this.move(s, move => move.Shoot === target);
  },
});

export const rules = names => Object.fromEntries(names.map(name => [name.toLowerCase(), {}]));

// A failed fuzz property, with the tape and config that reproduce it.
export class Mismatch extends Error {}

// The check of fuzz properties: count tallies each property's passes, and
// the properties in skipped are not checked.
export const propertyCheck = (count, skipped = new Set()) => (property, label, expected, actual, game, detail = '') => {
  if (skipped.has(property)) return;
  try { assert.deepEqual(normalize(actual), normalize(expected)); } catch (error) {
    const reproduction = { property, detail, tape: game.tape, config: normalize(game.config) };
    throw new Mismatch(`${property} failed (${label})${detail ? `: ${detail}` : ''}\n${error.message}\nrepro: ${JSON.stringify(reproduction)}`);
  }
  count[property]++;
};

// Seeded xorshift32 with random item games: configs over 2 to 4 seats and
// answers that are mostly in range but sometimes not.
export function makeRandom(seed) {
  const random = () => { seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5; return seed >>> 0; };
  const pick = xs => xs[random() % xs.length];
  const itemRules = seats => {
    const mode = pick(['all', 'all', 'single', 'subset', 'subset', 'capped', 'none']);
    const names = mode === 'all' ? items : mode === 'single' ? [pick(items)] : mode === 'none' ? [] : items.filter(() => random() % 2);
    return Object.fromEntries(names.map(name => [name.toLowerCase(), mode === 'capped' || random() % 3 === 0
      ? { per_player: 1 + random() % 3, on_table: 1 + random() % (2 * seats) }
      : { per_player: 1 + random() % 8, on_table: 32 }]));
  };
  const randomConfig = seats => config(seats, Array.from({ length: 1 + random() % 3 }, () => round({
    health: random() % 3 ? 1 + random() % 5 : null,
    items: itemRules(seats),
    loads: Array.from({ length: 4 }, () => {
      const total = 1 + random() % 8;
      const live = random() % (total + 1);
      return { live: random() % 3 ? live : null, blank: total - live, amount: random() % 2 ? null : random() % 9 };
    }),
  })));
  // A draw answer is out of range one time in 8, a move one time in 16.
  const drawAnswer = size => random() % 8 === 0 ? 50 + random() % 50 : random() % size;
  const moveAnswer = count => random() % 16 === 0 ? count + random() % 4 : random() % count;
  const answerFor = request => request.kind === 'Draw'
    ? drawAnswer(request.hi - request.lo + 2)
    : moveAnswer(Object.values(request.menus).reduce((n, menu) => n + menu.length, 0));
  const shuffled = xs => {
    const ys = [...xs];
    for (let i = ys.length - 1; i > 0; i--) { const j = random() % (i + 1); [ys[i], ys[j]] = [ys[j], ys[i]]; }
    return ys;
  };
  return { random, pick, randomConfig, answerFor, drawAnswer, moveAnswer, shuffled };
}

export const ring = (template, f) => Object.fromEntries(Object.entries(template).map(([key, value]) => [key, key === '$' ? value : f(value, key)]));
export const nil = list([]);

// Compares the machine with the reference in lockstep: the public point and
// the hidden fields, with the machine's rings folded into the host's seats.
export function lockstep(M, R) {
  const hostState = state => {
    const { world, players, grabs } = state;
    const seats = ring(players, (s, key) => ({ health: s.health, ...jamPair(s.jam), cash: s.cash, slots: s.slots, grabbing: grabs.grabbing[key], holding: grabs.holding[key], has_turn: turnHolder(state.phase) === Number(key.slice(1)) }));
    return { ...world, seats, distributing: grabs.distributing, grabs: ring(players, (_, key) => ({ $: 'GrabProgress', count: grabs.granted[key], intake: grabs.intake[key] })) };
  };
  const referenceHost = state => ({ ...state.host, seats: ring(state.host.seats, props => {
    const { $, ...fields } = props;
    return { ...fields, jam_checked: fields.jammed ? fields.jam_checked : null };
  }) });
  let boundaries = 0;
  return {
    boundaries: () => boundaries,
    compare(reference, machine, where = '') {
      assert.deepEqual(normalize(M.point(machine)), normalize(R.point(reference)), `public point must agree (${where})`);
      const host = hostState(machine);
      const expected = referenceHost(reference);
      delete host.$;
      delete expected.$;
      assert.deepEqual(normalize(host), normalize(expected), `hidden fields must agree (${where})`);
      boundaries++;
    },
    sameNotes: (machine, reference, where = '') => assert.deepEqual(normalize(machine), normalize(reference), `per-answer notes must agree (${where})`),
  };
}

// The sockets of an n-seat table: two players sit opposite each other.
export const sockets = n => n === 2 ? [1, 3] : Array.from({ length: n }, (_, i) => i);
export const menu = request => [request.moves.head, ...array(request.moves.tail)];

// Every Choose point of a seeded random game of the simple machine, from the
// mover's log: record gets { cfg, state, me, request, board, log } and returns
// what to keep. S and D read the simple machine's and domain's exports.
export function positions({ S, D, random }, cfg, players, steps, record) {
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
      found.push(record({ cfg, state, me, request, board: point.board, log: [...logs[me]] }));
      answer = random() % menu(request).length;
    } else answer = random() % (Number(request.range.extra) + 2);
    stepped = S('answer')(state, Number(answer));
    state = stepped.state;
    hear(stepped.notes);
  }
  return found;
}
