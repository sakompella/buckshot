import assert from 'node:assert/strict';
import { buildReference, config, round, list, array, kind, seat, tag, maybe, plain, requestJSON, stateJSON, traceJSON } from './reference-adapter.mjs';

const { R, close } = await buildReference();
let count = 0;
const snap = state => stateJSON(R.snapshot(state));
const req = state => requestJSON(R.point(state).request);
const events = notes => array(notes).map(note => kind(note.event));
const replay = (c, tape) => {
  let { state } = R.start(c);
  const notes = [];
  for (const answer of tape) {
    assert.ok(!['Finished', 'Stuck'].includes(req(state).kind), 'fixed tape must not answer a terminal point');
    const next = R.answer(state, answer);
    notes.push(...array(next.notes));
    state = next.state;
  }
  return { state, notes };
};
function scenario(name, test) { test(); count++; console.log(`ok    ${name}`); }
const twoBlank = config(2, [round({ live: 1, blank: 1 })]);

try {
  // D11, D15, D16, D19, D25, D47. Shuffle j=0 puts blank first.
  // Seat1 self-blanks, picks up again, then kills Seat3 with the live shell.
  scenario('two-seat full match and self blank', () => {
    const { state, notes } = replay(twoBlank, [0, 0, 0, 0, 0, 0, 1]);
    assert.equal(req(state).kind, 'Finished');
    const end = snap(state);
    assert.equal(end.first_death, 3);
    assert.equal(end.seats['1'].cash, 70000);
    assert.equal(end.seats['3'].health, 0);
    assert.deepEqual(notes.map(note => kind(note.event)), ['RoundBegan', 'Loaded', 'TurnGiven', 'PickedUp', 'Fired', 'TurnGiven', 'PickedUp', 'Fired', 'Died', 'RoundWon', 'MatchConcluded']);
    assert.deepEqual(plain(R.answer(state, 99).state), plain(state), 'terminal answer preserves even model-private state');
    assert.equal(array(R.answer(state, 99).notes).length, 0);
  });

  // D16 and D51. Self blank follows CheckIfEndingTurn/UserEndTurn/PassTurn.
  scenario('self blank keeps turn through end-turn path', () => {
    const { state, notes } = replay(twoBlank, [0, 0, 0, 0, 0]);
    assert.deepEqual(req(state), { kind: 'Choose', menus: { 1: [{ PickUp: true }], 3: [] } });
    assert.equal(snap(state).turn, 1);
    assert.deepEqual(snap(state).gun, ['Live']);
    assert.deepEqual(notes.slice(-2).map(note => kind(note.event)), ['Fired', 'TurnGiven']);
    assert.equal(state.host.first_turn.$, seat(1).$);
  });

  // D45 overrides FirstSeat in round2. D25 pays 70k,75k,80k by index.
  // Round0 winner1; round1 first3 and winner3; round2 first1 and winner1.
  scenario('three rounds, first-death override and all prize tiers', () => {
    const c = config(2, Array.from({ length: 3 }, () => round({ live: 1, blank: 1 })));
    const tape = [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1];
    const { state, notes } = replay(c, tape);
    assert.equal(req(state).kind, 'Finished');
    const rounds = notes.filter(note => kind(note.event) === 'RoundBegan').map(note => note.event.first.$);
    assert.deepEqual(rounds, [seat(1).$, seat(3).$, seat(1).$]);
    assert.equal(snap(state).seats['1'].cash, 150000);
    assert.equal(snap(state).seats['3'].cash, 75000);
    const trace = traceJSON(R, 'three-rounds', c, tape);
    assert.equal(trace.points.filter(p => p.request.label === 'FirstSeat').length, 1);
    assert.equal(trace.end, 'Finished');
    assert.deepEqual(snap(state).deck, [3, 4, 5, 6, 7, 8], 'deck is not reset at a round boundary');
  });

  // D07, D14, D16, D51. One live hits3; empty reload carries recipient3.
  // Current socket stays1 until LoadShotgun calls PassTurn.
  scenario('reload mid-round carries the pending turn', () => {
    const c = config(2, [round({ health: 3 })]);
    const { state } = replay(c, [0, 0, 0, 1]);
    assert.deepEqual(req(state), { kind: 'Draw', label: 'SequenceBatch', lo: 0, hi: 7 });
    assert.equal(snap(state).turn, 1);
    assert.equal(state.host.first_turn.$, seat(3).$);
    assert.equal(snap(state).load_index, 1);
    assert.equal(snap(state).seats['3'].health, 2);
    const next = R.answer(state, 0).state;
    assert.equal(snap(next).turn, 3);
    assert.deepEqual(snap(next).gun, ['Live']);
  });

  // D21,D37,D45,D47. 0 kills1; 2 kills0. Dead1 is skipped on traversal.
  scenario('three-seat full match', () => {
    const { state } = replay(config(3), [0, 0, 0, 1, 0, 0, 0]);
    assert.equal(req(state).kind, 'Finished');
    const end = snap(state);
    assert.equal(end.first_death, 1);
    assert.deepEqual(Object.values(end.seats).map(s => s.health), [0, 0, 1]);
    assert.equal(end.seats['2'].cash, 70000);
  });

  // D21,D37,D45,D47. 0 kills1; 2 kills3; 0 kills2.
  scenario('four-seat full match', () => {
    const { state } = replay(config(4), [0, 0, 0, 1, 0, 0, 2, 0, 0, 1]);
    assert.equal(req(state).kind, 'Finished');
    const end = snap(state);
    assert.equal(end.first_death, 1);
    assert.deepEqual(Object.values(end.seats).map(s => s.health), [1, 0, 0, 0]);
    assert.equal(end.seats['0'].cash, 70000);
  });

  // D11 singleton amendment,D14. Each blank-only load needs pickup + self shot.
  // Loads1..8 draw batches. Load9 uses the singleton directly. Load10 refills.
  scenario('deck singleton and refill after nine two-seat loads', () => {
    const c = config(2, [round({ live: 0, blank: 1 })]);
    const { state } = replay(c, Array(27).fill(0));
    assert.deepEqual(req(state), { kind: 'Draw', label: 'SequenceBatch', lo: 0, hi: 8 });
    assert.equal(snap(state).load_index, 1);
    assert.deepEqual(snap(state).deck, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
    assert.equal(snap(state).first_death, null);
    const next = R.answer(state, 0).state;
    assert.equal(snap(next).turn, 1);
    assert.deepEqual(snap(next).deck, [1, 2, 3, 4, 5, 6, 7, 8]);
    assert.deepEqual(snap(next).gun, ['Blank']);
    assert.equal(array(state.host.decks.three).length, 10);
    assert.equal(array(state.host.decks.four).length, 10);
    assert.equal(traceJSON(R, 'refill', c, Array(27).fill(0)).points.filter(p => p.request.label === 'SequenceBatch').length, 9);
  });

  // D11,D12,D23,D51. New-round random amount is retained even with no items.
  // Dead end-turn amounts are absent. Shared health is not installed until
  // AFTER amount selection, so health100 persists at both preceding draws.
  scenario('random no-item request vocabulary at all seat counts', () => {
    for (const [seats, first, health, amount] of [[2, 3, 4, 4], [3, 2, 5, 5], [4, 3, 5, 4]]) {
      const c = config(seats, [round({ health: null, amount: null })]);
      const trace = traceJSON(R, `random-${seats}`, c, [99, 99, 99, 0]);
      assert.deepEqual(trace.points.map(p => p.request.label ?? p.request.kind), ['FirstSeat', 'StartingHealth', 'ItemAmount', 'SequenceBatch', 'Choose']);
      assert.equal(trace.points[0].state.round_index, -1);
      assert.equal(trace.points[0].state.turn, 5);
      for (const point of trace.points.slice(0, 3)) assert.ok(Object.values(point.state.seats).every(s => s.health === 100));
      const last = trace.points.at(-1).state;
      assert.equal(last.turn, first);
      assert.equal(last.item_amount, amount);
      assert.ok(Object.values(last.seats).every(s => s.health === health));
    }
  });

  // D12. Initial amount0 bypasses distribution. The second load's random
  // amount is first read at its empty, nonwinning end turn, before another
  // SequenceBatch can run. Both pools are nonempty at that site.
  scenario('reload retains a live amount draw before distribution', () => {
    const loads = [0, null, 0, 0].map(amount => ({ live: 1, blank: 0, amount }));
    const c = config(2, [round({ health: 3, loads, items: { beer: { per_player: 8, on_table: 32 } } })]);
    const { state } = replay(c, [0, 0, 0, 1, 0, 0, 0]);
    assert.deepEqual(req(state), { kind: 'Draw', label: 'ItemAmount', lo: 2, hi: 4 });
    assert.equal(snap(state).load_index, 1);
    assert.equal(snap(state).turn, 3);
    assert.equal(state.host.first_turn.$, seat(3).$);
    assert.ok(Object.values(snap(state).seats).every(s => !s.grabbing));
    const next = R.answer(state, 2).state;
    assert.equal(snap(next).item_amount, 4);
    assert.equal(next.host.first_turn.$, seat(1).$);
    assert.deepEqual(req(next), { kind: 'Choose', menus: { 1: [{ Grab: true }], 3: [{ Grab: true }] } });
  });

  // D21. Deck resource4 for two seats is (1,1); shuffle j=1 is identity.
  scenario('random composition uses the sampled resource identity', () => {
    const c = config(2, [round({ live: null })]);
    const trace = traceJSON(R, 'sample-resource4', c, [0, 4, 1]);
    assert.deepEqual(trace.points.at(-1).state.gun, ['Live', 'Blank']);
    assert.deepEqual(trace.points.at(-1).state.deck, [0, 1, 2, 3, 5, 6, 7, 8]);
    assert.deepEqual(trace.points[2].request, { kind: 'Draw', label: 'ShuffleSwap', lo: 0, hi: 1 });
    assert.deepEqual(trace.points[2].state.gun, [], 'new shells stay local until shuffle completes');
  });

  // D11,D14. Start [Live,Live,Blank,Blank]. Swaps (3,0),(2,1),(1,0)
  // produce [Blank,Blank,Live,Live]. Each index is a separate request.
  scenario('Fisher-Yates requests descend and install only at completion', () => {
    const c = config(2, [round({ live: 2, blank: 2 })]);
    const trace = traceJSON(R, 'four-shell-shuffle', c, [0, 0, 0, 1, 0]);
    assert.deepEqual(trace.points.slice(2, 5).map(p => p.request), [3, 2, 1].map(hi => ({ kind: 'Draw', label: 'ShuffleSwap', lo: 0, hi })));
    assert.ok(trace.points.slice(2, 5).every(p => p.state.gun.length === 0 && p.state.deck.length === 8 && p.state.turn === 5));
    assert.deepEqual(trace.points.at(-1).state.gun, ['Blank', 'Blank', 'Live', 'Live']);
    assert.deepEqual(plain(replay(c, [0, 0, 0, 1, 0]).state.host.shown), plain(tag('Load', { live: 2, blank: 2 })));
  });

  // D55 M3. These inventories are injected because distribution effects are
  // Phase5. At round1 both old Beer slots hit caps before the scheduled clear.
  // Post-clear selection must nevertheless offer both seats a Grab.
  scenario('injected M3 clears old capped inventories before selection', () => {
    const loads = [0, 0, 1, 0].map(amount => ({ live: 1, blank: 0, amount }));
    const c = config(2, [round({ health: 2 }), round({ loads, items: { beer: { per_player: 1, on_table: 2 } } })]);
    const before = replay(c, [0, 0, 0, 1, 0, 0, 0, 0, 0]).state;
    const slots = { ...before.host.seats.s1.slots, s0: maybe(tag('Beer')) };
    const seats = { ...before.host.seats, s1: { ...before.host.seats.s1, slots }, s3: { ...before.host.seats.s3, slots } };
    const state = R.answer({ ...before, host: { ...before.host, seats } }, 1).state;
    assert.deepEqual(req(state), { kind: 'Choose', menus: { 1: [{ Grab: true }], 3: [{ Grab: true }] } });
    assert.ok(Object.values(snap(state).seats).every(s => s.slots.every(x => x === null)));
  });

  // D12,D14,D55 M3. Round0 ends on load2. Round1 reads amount1 from old
  // index2, not amount0 from index0, and exposes both post-clear grabbers.
  scenario('new-round amount uses the old load index', () => {
    const loads = [0, 0, 1, 0].map(amount => ({ live: 1, blank: 0, amount }));
    const c = config(2, [round({ health: 2 }), round({ loads, items: { beer: { per_player: 1, on_table: 2 } } })]);
    const { state } = replay(c, [0, 0, 0, 1, 0, 0, 0, 0, 0, 1]);
    assert.deepEqual(req(state), { kind: 'Choose', menus: { 1: [{ Grab: true }], 3: [{ Grab: true }] } });
    const end = snap(state);
    assert.equal(end.round_index, 1);
    assert.equal(end.load_index, 2);
    assert.equal(end.item_amount, 1);
    assert.ok(Object.values(end.seats).every(s => s.health === 1 && s.grabbing && s.slots.every(slot => slot === null)));
    assert.equal(state.host.first_turn.$, seat(3).$);
  });

  // D08,D16,D27. Jammer is not reachable in a no-item game. This injected
  // target-selection fixture verifies that the self-blank end-turn checks it.
  scenario('injected jam skips once, then lifts on the next visit', () => {
    const base = replay(twoBlank, [0, 0, 0, 0]).state;
    const props = { ...base.host.seats.s1, jammed: true, jam_checked: false };
    const jammed = { ...base, host: { ...base.host, seats: { ...base.host.seats, s1: props } } };
    const first = R.answer(jammed, 0);
    assert.deepEqual(events(first.notes), ['Fired', 'TurnSkipped', 'TurnGiven']);
    assert.equal(snap(first.state).turn, 3);
    assert.equal(first.state.host.first_turn.$, seat(1).$);
    assert.equal(snap(first.state).seats['1'].jammed, true);
    assert.equal(snap(first.state).seats['1'].jam_checked, true);
    const back = R.settle(96, { ...first.state, frame: { $: 'PassTurn', seat: seat(1) }, notes: list([]) });
    assert.deepEqual(events(back.notes), ['JamLifted', 'TurnGiven']);
    assert.equal(snap(back).turn, 1);
    assert.equal(snap(back).seats['1'].jammed, false);
    assert.equal(snap(back).seats['1'].jam_checked, false);
    const both = { ...jammed, frame: { $: 'PassTurn', seat: seat(1) }, notes: list([]), host: { ...jammed.host, seats: { ...jammed.host.seats, s3: { ...jammed.host.seats.s3, jammed: true, jam_checked: false } } } };
    const closed = R.settle(96, both);
    assert.deepEqual(events(closed.notes), ['TurnSkipped', 'TurnSkipped', 'JamLifted', 'TurnGiven']);
    assert.equal(req(closed).kind, 'Choose');
  });

  // D08. Four simultaneous unchecked jams make four skips, then the first
  // checked jam lifts. The bounded silent closure must still reach Choose.
  scenario('injected four-seat all-jammed closure terminates', () => {
    const state = replay(config(4), [0, 0]).state;
    const seats = Object.fromEntries(Object.entries(state.host.seats).map(([key, value]) => [key, key.startsWith('s') ? { ...value, jammed: true, jam_checked: false } : value]));
    const next = R.settle(96, { ...state, host: { ...state.host, seats }, frame: { $: 'PassTurn', seat: seat(0) }, notes: list([]) });
    assert.deepEqual(events(next.notes), ['TurnSkipped', 'TurnSkipped', 'TurnSkipped', 'TurnSkipped', 'JamLifted', 'TurnGiven']);
    assert.equal(req(next).kind, 'Choose');
    assert.equal(snap(next).turn, 0);
  });

  // D51. Saw Remove is Phase5. The injected flag captures double damage;
  // Grow clears it on a blank too, and damage clamps at zero on live.
  scenario('injected saw is captured and grown on each shot', () => {
    const blank = replay(twoBlank, [0, 0, 0, 0]).state;
    const blankShot = R.answer({ ...blank, host: { ...blank.host, sawed: true } }, 0);
    const firedBlank = array(blankShot.notes).find(note => kind(note.event) === 'Fired').event;
    assert.equal(kind(firedBlank.captured), 'Double');
    assert.equal(Number(firedBlank.applied), 0);
    assert.equal(snap(blankShot.state).sawed, false);
    const c = config(2);
    const live = replay(c, [0, 0, 0]).state;
    for (const target of [0, 1]) {
      const shot = R.answer({ ...live, host: { ...live.host, sawed: true } }, target);
      const fired = array(shot.notes).find(note => kind(note.event) === 'Fired').event;
      assert.equal(kind(fired.captured), 'Double');
      assert.equal(Number(fired.applied), 1);
      assert.equal(snap(shot.state).sawed, false);
      assert.equal(req(shot.state).kind, 'Finished');
    }
  });

  // D45,D51. Remote is the only direction flip, so CCW cannot be reached
  // before Phase5. This injected fixture includes dead current socket1.
  scenario('injected CCW and CW traversal include dead current only', () => {
    const state = replay(config(4, [round({ health: 2 })]), [0, 0]).state;
    const host = { ...state.host, seats: { ...state.host.seats, s1: { ...state.host.seats.s1, health: 0 } } };
    assert.equal(R['rules:GetNextTurn_Socket'](host, seat(1)).$, seat(2).$);
    assert.equal(R['rules:GetNextTurn_Socket'](host, seat(2)).$, seat(3).$);
    const ccw = { ...host, direction: tag('CounterClockwise') };
    assert.equal(R['rules:GetNextTurn_Socket'](ccw, seat(2)).$, seat(0).$);
    assert.equal(R['rules:GetNextTurn_Socket'](ccw, seat(1)).$, seat(0).$);
  });

  // D32. The host predicate checks turn/holding/has_turn, not target health.
  scenario('canonical core menus pass the host guards', () => {
    const idle = replay(twoBlank, [0, 0, 0]).state;
    const choice = (s, move) => tag('Choice', { seat: seat(s), index: 0, move });
    assert.equal(R.VerifyPacket(idle, choice(1, tag('PickUp'))), true);
    assert.equal(R.VerifyPacket(idle, choice(3, tag('PickUp'))), false);
    assert.equal(R.VerifyPacket(idle, choice(1, tag('Shoot', { target: seat(3) }))), false);
    const aiming = R.answer(idle, 0).state;
    assert.equal(R.VerifyPacket(aiming, choice(1, tag('PickUp'))), false);
    assert.equal(R.VerifyPacket(aiming, choice(1, tag('Shoot', { target: seat(3) }))), true);
    const dead = { ...aiming, host: { ...aiming.host, seats: { ...aiming.host.seats, s3: { ...aiming.host.seats.s3, health: 0 } } } };
    assert.equal(R.VerifyPacket(dead, choice(1, tag('Shoot', { target: seat(3) }))), true);
    const noTurn = { ...aiming, host: { ...aiming.host, seats: { ...aiming.host.seats, s1: { ...aiming.host.seats.s1, has_turn: false } } } };
    assert.equal(R.VerifyPacket(noTurn, choice(1, tag('Shoot', { target: seat(3) }))), false);
  });

  // Public API contract. Fuel=answers, not silent calls. Finished keeps tail.
  scenario('request-counted fuel and trace boundary', () => {
    const state = R.start(twoBlank).state;
    const tape = [0, 0, 0, 0, 0, 0, 1, 99];
    const zero = R.run(0, state, list(tape));
    assert.deepEqual(plain(zero.state), plain(state));
    assert.deepEqual(array(zero.tape).map(Number), tape);
    const one = R.run(1, state, list(tape));
    assert.equal(req(one.state).label, 'SequenceBatch');
    assert.deepEqual(array(one.tape).map(Number), tape.slice(1));
    const all = R.run(99, state, list(tape));
    assert.equal(req(all.state).kind, 'Finished');
    assert.deepEqual(array(all.tape).map(Number), [99]);
    const trace = traceJSON(R, 'two-seat-no-items', twoBlank, tape);
    assert.equal(trace.points.length, 8);
    assert.equal(trace.end, 'Finished');
    assert.equal(trace.points.at(-1).request.kind, 'Finished');
    assert.deepEqual(trace.points.at(-1).state, snap(all.state));
    const stuck = R.settle(0, { ...state, frame: { $: 'MainRoutine_StartRound', phase: { $: 'BeginRound' } } });
    assert.equal(req(stuck).kind, 'Stuck');
    assert.equal(array(R.answer(stuck, 0).notes).length, 0);
    assert.deepEqual(plain(R.answer(stuck, 0).state), plain(stuck));
  });
  console.log(`core scenarios: ${count} passed`);
} finally {
  close();
}
