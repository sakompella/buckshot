import assert from 'node:assert/strict';
import { config, round, list, array, kind, seat, tag, plain, requestJSON, maybe, machineJam } from './reference-adapter.mjs';
import { loadModels, lockstep, nil, normalize, ring } from './machine-items-lib.mjs';

const { M, R, close } = await loadModels('bend-mp-machine-core-');
try {
  const { compare, boundaries } = lockstep(M, R);
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
  for (const seats of [2, 3, 4]) {
    const c = config(seats, [round({ health: 3, live: 1, blank: 1 })]);
    const { reference, machine } = replay(c, [0, 0, 1, 0]);
    const jammedR = { ...reference, host: { ...reference.host, seats: ring(reference.host.seats, props => ({ ...props, jammed: true, jam_checked: false, has_turn: false })) }, notes: nil };
    const jammedM = { ...machine, players: ring(machine.players, s => ({ ...s, jam: machineJam(true, false) })), notes: nil };
    const actor = seats === 2 ? 1 : 0;
    const grantedR = R.settle(96, { ...jammedR, frame: { $: 'PassTurn', seat: seat(actor) } });
    const grantedM = M.grant(jammedM, seat(actor));
    compare(grantedR, grantedM);
    assert.deepEqual(normalize(grantedM.notes), normalize(grantedR.notes), 'unchecked jam chain must preserve checked bits and note order');
    for (const direction of ['Clockwise', 'CounterClockwise']) {
      const deadR = { ...reference, host: { ...reference.host, direction: tag(direction), seats: ring(reference.host.seats, (props, key) => ({ ...props, health: key === `s${actor}` ? 0 : props.health })) } };
      const deadM = { ...machine, world: { ...machine.world, direction: tag(direction) }, players: ring(machine.players, (s, key) => key === `s${actor}` ? { ...s, health: 0 } : s) };
      assert.deepEqual(normalize(M['rules:next_turn'](M['state:players.health'](deadM.players), deadM.world.direction, seat(actor))), normalize(R['rules:GetNextTurn_Socket'](deadR.host, seat(actor))));
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
    const keys = Object.keys(machine.players).filter(key => key.startsWith('s'));
    for (let flags = 0; flags < 1 << (2 * seats); flags++) {
      const jammed = key => Boolean(flags & 1 << (2 * keys.indexOf(key)));
      const checked = key => Boolean(flags & 1 << (2 * keys.indexOf(key) + 1));
      for (const direction of ['Clockwise', 'CounterClockwise']) {
        const r = { ...reference, notes: nil, host: { ...reference.host, direction: tag(direction), seats: ring(reference.host.seats, (props, key) => ({ ...props, jammed: jammed(key), jam_checked: checked(key), has_turn: false })) } };
        const m = { ...machine, notes: nil, world: { ...machine.world, direction: tag(direction) }, players: ring(machine.players, (s, key) => ({ ...s, jam: machineJam(jammed(key), checked(key)) })) };
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
  const forgedMove = tag('Choice', { seat: seat(1), index: 0, move: tag('Shoot', { target: seat(3) }) });
  assert.deepEqual(normalize(M['answer.choice'](idle, forgedMove)), normalize(M.pickup(idle, seat(1))), 'effect must reread typed options and ignore Choice.move');
  const initial = M.start(twoBlank).state;
  const dead = ring(initial.players, s => ({ ...s, health: 0 }));
  const terminals = [
    { phase: { $: 'Ended' } },
    { phase: { $: 'Blocked', holder: maybe(null) } },
    { phase: { $: 'Aim', seat: seat(1) }, players: dead },
    { phase: { $: 'NeedSwap', load: tag('Load', { live: 0, blank: 0 }), shells: nil, i: 0 } },
  ];
  for (const { phase, players = initial.players } of terminals) {
    const state = { ...initial, phase, players, notes: list([tag('Shown', { event: tag('MatchConcluded') })]) };
    const answer = M.answer(state, 99), ran = M.run(99, state, list([1, 2]));
    assert.deepEqual(plain(answer.state), plain(state));
    assert.deepEqual(array(answer.notes), []);
    assert.deepEqual(plain(ran.state), plain(state));
    assert.deepEqual(array(ran.notes), []);
    assert.deepEqual(array(ran.tape).map(Number), [1, 2]);
  }
  const exhausted = { ...initial, phase: { $: 'NeedBatch' }, world: { ...initial.world, decks: { ...initial.world.decks, two: nil } } };
  assert.equal(requestJSON(M.point(exhausted).request).kind, 'Stuck');
  assert.deepEqual(plain(M.answer(exhausted, 0).state), plain(exhausted));
  assert.deepEqual(array(M.run(5, exhausted, list([1, 2])).tape).map(Number), [1, 2]);
  const itemized = config(2, [round(), round({ items: { saw: {} } })]);
  assert.notEqual(requestJSON(M.point(M.start(itemized).state).request).kind, 'Stuck', 'an item config starts');
  compare(R.start(itemized).state, M.start(itemized).state);
  console.log(`core differential verification: ${boundaries()} boundaries passed`);
} finally {
  close();
}
