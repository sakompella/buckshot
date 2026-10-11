import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { config, round, list, array, kind, seat, tag, plain, requestJSON } from './reference-adapter.mjs';

const dir = mkdtempSync(join(tmpdir(), 'bend-mp-machine-core-'));
function build(name, relativeSource) {
  const source = fileURLToPath(new URL(relativeSource, import.meta.url));
  const output = join(dir, `${name}.mjs`);
  for (const args of [[source, '--check-only'], [source, '-o', output]]) {
    const result = spawnSync(process.env.BEND ?? 'bend', args, { encoding: 'utf8' });
    if (result.error) throw result.error;
    const log = `${result.stdout}${result.stderr}`;
    assert.equal(result.status, 0, `Bend ${name} failed:
${log}`);
    assert.doesNotMatch(log, /SOME (?:PROOFS|TYPES) FAIL/, `Bend ${name} reported a check failure`);
    if (args.includes('--check-only')) assert.match(log, /ALL PROOFS CHECK/);
  }
  return pathToFileURL(output).href;
}

try {
  const machine = build('machine', '../sm/main.bend');
  const reference = build('reference', '../ref/main.bend');
  const M = (await import(machine)).default;
  const R = (await import(reference)).default;

  const normalize = value => JSON.parse(JSON.stringify(value, (key, x) => {
    if (typeof x === 'bigint') return Number(x);
    if (key === '$') return x.split('.').at(-1);
    return x;
  }));
  const ring = (template, f) => Object.fromEntries(Object.entries(template).map(([key, value]) => [key, key === '$' ? value : f(value, key)]));
  const nil = list([]);
  const hostState = state => {
    const { world, players } = state;
    const seats = ring(players.health, (_, key) => ({ health: players.health[key], jammed: players.jammed[key], jam_checked: players.checked[key], cash: players.cash[key], slots: players.slots[key], grabbing: false, holding: { $: 'None' }, has_turn: players.has_turn[key] }));
    return { ...world, seats, distributing: false };
  };
  const referenceHost = state => ({ ...state.host, seats: ring(state.host.seats, props => {
    const { $, ...fields } = props;
    return fields;
  }) });
  let checked = 0;
  const compare = (reference, machine) => {
    assert.deepEqual(normalize(M.point(machine)), normalize(R.point(reference)), 'public point must agree');
    const host = hostState(machine);
    const expected = referenceHost(reference);
    delete host.$;
    delete expected.$;
    assert.deepEqual(normalize(host), normalize(expected), 'hidden fields and independent player rings must agree');
    checked++;
  };
  const replay = (c, tape) => {
    let r = R.start(c), m = M.start(c);
    assert.deepEqual(normalize(m.notes), normalize(r.notes));
    compare(r.state, m.state);
    for (const answer of tape) {
      r = R.answer(r.state, answer);
      m = M.answer(m.state, answer);
      assert.deepEqual(normalize(m.notes), normalize(r.notes), 'per-answer note order must agree');
      compare(r.state, m.state);
    }
    return { reference: r.state, machine: m.state };
  };
  const twoBlank = config(2, [round({ live: 1, blank: 1 })]);
  replay(twoBlank, [0, 0, 0, 0, 0, 0, 1, 99]);
  replay(config(2, Array.from({ length: 3 }, () => round({ live: 1, blank: 1 }))), [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]);
  replay(config(3), [0, 0, 0, 1, 0, 0, 0]);
  replay(config(4), [0, 0, 0, 1, 0, 2, 0, 0, 0]);
  for (const seats of [2, 3, 4]) {
    const c = config(seats, [round({ health: 100, live: 0, blank: 1 })]);
    replay(c, Array(140).fill(0));
  }
  let seed = 0x4b534854;
  const random = () => { seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5; return seed >>> 0; };
  for (const seats of [2, 3, 4]) {
    for (let trial = 0; trial < 30; trial++) {
      const rounds = Array.from({ length: 1 + random() % 3 }, () => round({
        health: random() % 2 ? null : 1 + random() % 5,
        loads: Array.from({ length: 4 }, () => {
          const total = 1 + random() % 7;
          const live = random() % (total + 1);
          return { live: random() % 2 ? null : live, blank: total - live, amount: random() % 2 ? null : random() % 6 };
        }),
      }));
      replay(config(seats, rounds), Array.from({ length: 120 }, () => random() % 20));
    }
  }
  for (const seats of [2, 3, 4]) {
    const c = config(seats, [round({ health: 3, live: 1, blank: 1 })]);
    const { reference, machine } = replay(c, [0, 0, 1, 0]);
    const jammedR = { ...reference, host: { ...reference.host, seats: ring(reference.host.seats, props => ({ ...props, jammed: true, jam_checked: false })) }, notes: nil };
    const jammedM = { ...machine, players: { ...machine.players, jammed: ring(machine.players.jammed, () => true), checked: ring(machine.players.checked, () => false) }, notes: nil };
    const actor = seats === 2 ? 1 : 0;
    const grantedR = R.settle(96, { ...jammedR, frame: { $: 'PassTurn', seat: seat(actor) } });
    const grantedM = M.grant(jammedM, seat(actor));
    compare(grantedR, grantedM);
    assert.deepEqual(normalize(grantedM.notes), normalize(grantedR.notes), 'unchecked jam chain must preserve checked bits and note order');
    for (const direction of ['Clockwise', 'CounterClockwise']) {
      const deadR = { ...reference, host: { ...reference.host, direction: tag(direction), seats: ring(reference.host.seats, (props, key) => ({ ...props, health: key === `s${actor}` ? 0n : props.health })) } };
      const deadM = { ...machine, world: { ...machine.world, direction: tag(direction) }, players: { ...machine.players, health: ring(machine.players.health, (hp, key) => key === `s${actor}` ? 0n : hp) } };
      assert.deepEqual(normalize(M['rules.next_turn'](deadM.players.health, deadM.world.direction, seat(actor))), normalize(R['rules.GetNextTurn_Socket'](deadR.host, seat(actor))));
    }
    for (const shell of ['Live', 'Blank']) {
      const sawR = { ...reference, host: { ...reference.host, sawed: true, gun: list([tag(shell)]) } };
      const sawM = { ...machine, world: { ...machine.world, sawed: true, gun: list([tag(shell)]) } };
      const shotR = R.answer(sawR, 0), shotM = M.answer(sawM, 0);
      compare(shotR.state, shotM.state);
      assert.deepEqual(normalize(shotM.notes), normalize(shotR.notes));
    }
  }
  for (const fuel of [0, 1, 3, 100]) {
    const r = R.start(twoBlank).state, m = M.start(twoBlank).state;
    const tape = list([0, 0, 0, 0, 0, 0, 1, 99]);
    const rr = R.run(fuel, r, tape), mr = M.run(fuel, m, tape);
    compare(rr.state, mr.state);
    assert.deepEqual(normalize(mr.notes), normalize(rr.notes));
    assert.deepEqual(normalize(mr.tape), normalize(rr.tape));
  }
  for (const seats of [2, 3, 4]) {
    const { reference, machine } = replay(config(seats, [round({ health: 3 })]), [0, 0]);
    const keys = Object.keys(machine.players.health).filter(key => key.startsWith('s'));
    for (let flags = 0; flags < 1 << (2 * seats); flags++) {
      const jammed = key => Boolean(flags & 1 << (2 * keys.indexOf(key)));
      const checked = key => Boolean(flags & 1 << (2 * keys.indexOf(key) + 1));
      for (const direction of ['Clockwise', 'CounterClockwise']) {
        const r = { ...reference, notes: nil, host: { ...reference.host, direction: tag(direction), seats: ring(reference.host.seats, (props, key) => ({ ...props, jammed: jammed(key), jam_checked: checked(key) })) } };
        const m = { ...machine, notes: nil, world: { ...machine.world, direction: tag(direction) }, players: { ...machine.players, jammed: ring(machine.players.jammed, (_, key) => jammed(key)), checked: ring(machine.players.checked, (_, key) => checked(key)) } };
        for (const key of keys) {
          const actor = seat(Number(key.slice(1)));
          const rg = R.settle(96, { ...r, frame: { $: 'PassTurn', seat: actor } }), mg = M.grant(m, actor);
          compare(rg, mg);
          assert.deepEqual(normalize(mg.notes), normalize(rg.notes));
        }
      }
    }
  }
  const idle = replay(twoBlank, [0, 0, 0]).machine;
  const forgedMove = tag('Choice', { seat: seat(1), index: 0n, move: tag('Shoot', { target: seat(3) }) });
  assert.deepEqual(normalize(M['answer.choice'](idle, forgedMove)), normalize(M.pickup(idle, seat(1))), 'effect must reread typed options and ignore Choice.move');
  const initial = M.start(twoBlank).state;
  const terminals = [
    { $: 'state.Ended' },
    { $: 'state.Blocked' },
    { $: 'state.Aim', seat: seat(1), targets: nil },
    { $: 'state.NeedSwap', load: tag('Load', { live: 0n, blank: 0n }), shells: nil, i: 0n },
  ];
  for (const phase of terminals) {
    const state = { ...initial, phase, notes: list([tag('Shown', { event: tag('MatchConcluded') })]) };
    const answer = M.answer(state, 99), ran = M.run(99, state, list([1, 2]));
    assert.deepEqual(plain(answer.state), plain(state));
    assert.deepEqual(array(answer.notes), []);
    assert.deepEqual(plain(ran.state), plain(state));
    assert.deepEqual(array(ran.notes), []);
    assert.deepEqual(array(ran.tape).map(Number), [1, 2]);
  }
  const exhausted = { ...initial, phase: { $: 'state.NeedBatch' }, world: { ...initial.world, decks: { ...initial.world.decks, two: nil } } };
  assert.equal(requestJSON(M.point(exhausted).request).kind, 'Stuck');
  assert.deepEqual(plain(M.answer(exhausted, 0).state), plain(exhausted));
  assert.deepEqual(array(M.run(5, exhausted, list([1, 2])).tape).map(Number), [1, 2]);
  const unsupported = config(2, [round(), round({ items: { saw: {} } })]);
  assert.equal(requestJSON(M.point(M.start(unsupported).state).request).kind, 'Stuck', 'support predicate must cover every round');
  console.log(`core differential verification: ${checked} boundaries passed`);
} finally {
  rmSync(dir, { recursive: true });
}
