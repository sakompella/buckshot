import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { config, round, list, jamPair, turnHolder } from './reference-adapter.mjs';

export const items = ['Saw', 'Glass', 'Jammer', 'Cigarettes', 'Beer', 'Phone', 'Inverter', 'Adrenaline', 'Remote'];

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

export const rules = names => Object.fromEntries(names.map(name => [name.toLowerCase(), {}]));

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
  const answerFor = request => {
    if (request.kind === 'Draw') return random() % 8 === 0 ? 50 + random() % 50 : random() % (request.hi - request.lo + 2);
    const count = Object.values(request.menus).reduce((n, menu) => n + menu.length, 0);
    return random() % 16 === 0 ? count + random() % 4 : random() % count;
  };
  return { random, pick, randomConfig, answerFor };
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
