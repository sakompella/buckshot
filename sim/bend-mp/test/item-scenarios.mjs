import assert from 'node:assert/strict';
import { buildReference, config, round, list, array, kind, seatNumber, tag, maybe, requestJSON, stateJSON, traceJSON } from './reference-adapter.mjs';
import { items, itemSteps, rules, sockets } from './machine-items-lib.mjs';

const { R, close } = await buildReference();
let count = 0;
function scenario(name, test) {
  test();
  count++;
  console.log(`ok    ${name}`);
}

function session(c) {
  const initial = R.start(c);
  return {
    config: c, state: initial.state, notes: array(initial.notes), tape: [],
    get request() { return requestJSON(R.point(this.state).request); },
    get snapshot() { return stateJSON(R.snapshot(this.state)); },
    get moves() {
      assert.equal(this.request.kind, 'Choose');
      return Object.entries(this.request.menus).flatMap(([s, menu]) => menu.map(move => ({ seat: Number(s), move })));
    },
    answer(n) {
      assert.ok(!['Stuck', 'Finished'].includes(this.request.kind), 'cannot answer a terminal request');
      this.tape.push(n);
      const next = R.answer(this.state, n);
      this.state = next.state;
      this.notes.push(...array(next.notes));
      return array(next.notes);
    },
    move(s, accepts) {
      const index = this.moves.findIndex(choice => choice.seat === s && accepts(choice.move));
      assert.ok(index >= 0, `seat ${s} has required move in ${JSON.stringify(this.request)}`);
      const menu = array(R.point(this.state).request.menus[`s${s}`]);
      const localIndex = this.moves.slice(0, index).filter(choice => choice.seat === s).length;
      const choice = tag('Choice', { seat: tag(`Seat${s}`), index: localIndex, move: menu[localIndex] });
      assert.equal(R.VerifyPacket(this.state, choice), true, 'every offered choice passes the host guards');
      return this.answer(index);
    },
    ...itemSteps(game => game.state),
  };
}
const shown = notes => notes.filter(note => kind(note) === 'Shown').map(note => note.event);
const told = notes => notes.filter(note => kind(note) === 'Told');
const event = (notes, name) => {
  const found = shown(notes).find(value => kind(value) === name);
  assert.ok(found, `event ${name} exists`);
  return found;
};
function privateResult(notes, actor, name, fields = {}) {
  const secrets = told(notes);
  assert.equal(secrets.length, 1);
  assert.equal(seatNumber(secrets[0].seat), actor);
  assert.equal(kind(secrets[0].secret), name);
  for (const [field, value] of Object.entries(fields)) {
    const actual = secrets[0].secret[field];
    assert.equal(typeof value === 'string' ? kind(actual) : Number(actual), value);
  }
}
function boardFixture(game, changes, hostChanges = {}) {
  const seats = { ...game.state.host.seats };
  for (const [s, change] of Object.entries(changes)) {
    const old = seats[`s${s}`];
    const { inventory, ...props } = change;
    seats[`s${s}`] = { ...old, ...props, ...(inventory ? {
      slots: { ...old.slots, ...Object.fromEntries(Array.from({ length: 8 }, (_, i) => [`s${i}`, maybe(inventory[i] ? tag(inventory[i]) : null)])) },
    } : {}) };
  }
  game.state = { ...game.state, host: { ...game.state.host, ...hostChanges, seats } };
}
function refreshIdle(game) {
  game.state = R.settle(96, { ...game.state, frame: { $: 'GiveTurnPermissions', seat: tag(`Seat${game.snapshot.turn}`) }, notes: list([]) });
}

try {
  // Item ownership, effects, secrets, and usable moves.
  for (const seats of [2, 3, 4]) {
    const [actor, opponent] = sockets(seats);
    for (const item of items) {
      scenario(`${seats} seats normal grant and ${item} effect`, () => {
        const enabled = item === 'Adrenaline' ? ['Adrenaline', 'Beer'] : [item];
        const game = session(config(seats, [round({ health: 4, live: 3, amount: 1, items: rules(enabled) })]));
        game.distribute(s => item === 'Adrenaline' && s !== actor ? 'Beer' : item);
        if (seats === 2 && item === 'Remote') {
          assert.ok(Object.values(game.snapshot.seats).every(props => props.slots.every(slot => slot === null)));
          assert.ok(!shown(game.notes).some(e => kind(e) === 'Granted'));
          return;
        }
        assert.equal(game.snapshot.turn, actor);
        assert.equal(game.snapshot.seats[actor].slots[0], item);
        const notes = game.use(actor, item);
        const used = event(notes, 'Used');
        assert.equal(seatNumber(used.seat), actor);
        assert.equal(seatNumber(used.owner), actor);
        assert.equal(kind(used.item), item);
        assert.equal(game.snapshot.seats[actor].slots[0], null);
        switch (item) {
          case 'Saw': {
            assert.equal(game.snapshot.sawed, true);
            assert.ok(!game.moves.some(({ move }) => move.UseItem?.[1] === 'Saw'));
            const shot = event(game.shoot(actor, opponent), 'Fired');
            assert.equal(kind(shot.captured), 'Double');
            assert.equal(Number(shot.applied), 2);
            assert.equal(game.snapshot.seats[opponent].health, 2);
            assert.equal(game.snapshot.sawed, false);
            break;
          }
          case 'Glass': privateResult(notes, actor, 'Glimpse', { shell: 'Live' }); break;
          case 'Jammer': {
            assert.deepEqual(game.moves.map(({ move }) => move.JamTarget), sockets(seats).filter(s => s !== actor));
            const jam = game.move(actor, move => move.JamTarget === opponent);
            assert.equal(seatNumber(event(jam, 'JamApplied').target), opponent);
            assert.equal(game.snapshot.seats[opponent].jammed, true);
            assert.equal(game.snapshot.seats[opponent].jam_checked, false);
            break;
          }
          case 'Cigarettes': assert.equal(game.snapshot.seats[actor].health, 4); break;
          case 'Beer':
            assert.equal(kind(event(notes, 'Ejected').shell), 'Live');
            assert.deepEqual(game.snapshot.gun, ['Live', 'Live']);
            break;
          case 'Phone': privateResult(notes, actor, 'Clue', { position: 3, shell: 'Live' }); break;
          case 'Inverter':
            event(notes, 'Inverted');
            assert.deepEqual(game.snapshot.gun, ['Blank', 'Live', 'Live']);
            assert.equal(told(notes).length, 0);
            break;
          case 'Adrenaline': {
            assert.ok(game.moves.every(({ move }) => move.Steal?.[2] === 'Beer'));
            const steal = game.move(actor, move => move.Steal?.[0] === opponent);
            assert.equal(seatNumber(event(steal, 'Used').owner), opponent);
            assert.equal(game.snapshot.seats[opponent].slots[0], null);
            assert.deepEqual(game.snapshot.gun, ['Live', 'Live']);
            break;
          }
          case 'Remote':
            assert.equal(kind(event(notes, 'DirectionFlipped').direction), 'CounterClockwise');
            assert.equal(game.snapshot.direction, 'CCW');
            game.shoot(actor, opponent);
            assert.equal(game.snapshot.turn, sockets(seats).at(-1));
            break;
        }
        assert.equal(game.request.kind, 'Choose');
      });
    }

    for (const item of items.filter(value => value !== 'Adrenaline' && !(seats === 2 && value === 'Remote'))) {
      scenario(`${seats} seats adrenaline steals and uses ${item}`, () => {
        const game = session(config(seats, [round({ health: 4, live: 3, amount: 1, items: rules(['Adrenaline', item]) })]));
        game.distribute(s => s === actor ? 'Adrenaline' : item);
        game.use(actor, 'Adrenaline');
        assert.deepEqual(game.moves.map(({ move }) => move.Steal?.[0]), sockets(seats).filter(s => s !== actor));
        const notes = game.move(actor, move => move.Steal?.[0] === opponent && move.Steal?.[2] === item);
        const used = event(notes, 'Used');
        assert.equal(seatNumber(used.seat), actor);
        assert.equal(seatNumber(used.owner), opponent);
        assert.equal(kind(used.item), item);
        assert.equal(game.snapshot.seats[opponent].slots[0], null);
        assert.ok(game.snapshot.seats[actor].slots.every(slot => slot === null), 'stolen item is used, not stored');
        if (item === 'Jammer') game.move(actor, move => move.JamTarget === opponent);
        if (item === 'Glass') privateResult(notes, actor, 'Glimpse', { shell: 'Live' });
        if (item === 'Phone') privateResult(notes, actor, 'Clue', { position: 3, shell: 'Live' });
        if (item === 'Saw') assert.equal(game.snapshot.sawed, true);
        if (item === 'Beer') assert.deepEqual(game.snapshot.gun, ['Live', 'Live']);
        if (item === 'Inverter') assert.deepEqual(game.snapshot.gun, ['Blank', 'Live', 'Live']);
        if (item === 'Remote') assert.equal(game.snapshot.direction, 'CCW');
        assert.equal(game.request.kind, 'Choose');
      });
    }
  }

  scenario('host acceptance is wider than normal secondary-mode menus', () => {
    const packet = move => tag('Choice', { seat: tag('Seat0'), index: 0, move });
    const aiming = session(config(3, [round({ live: 3, amount: 1, items: rules(['Glass']) })]));
    aiming.distribute(() => 'Glass');
    aiming.move(0, move => 'PickUp' in move);
    assert.ok(aiming.moves.every(({ move }) => 'Shoot' in move));
    assert.equal(R.VerifyPacket(aiming.state, packet(tag('UseItem', { slot: tag('Slot0'), item: tag('Glass') }))), true);
    assert.equal(R.VerifyPacket(aiming.state, packet(tag('PickUp'))), false);
    for (const item of ['Jammer', 'Adrenaline']) {
      const game = session(config(3, [round({ live: 3, amount: 2, items: rules([item, 'Glass']) })]));
      game.distribute((s, snapshot) => s === 0 && !snapshot.seats[s].slots.includes(item) ? item : 'Glass');
      game.use(0, item);
      assert.ok(game.moves.every(({ move }) => item === 'Jammer' ? 'JamTarget' in move : 'Steal' in move));
      assert.equal(R.VerifyPacket(game.state, packet(tag('PickUp'))), true);
      assert.equal(R.VerifyPacket(game.state, packet(tag('UseItem', { slot: tag('Slot1'), item: tag('Glass') }))), true);
    }
  });

  scenario('cigarettes heal one after damage and remain capped at round health', () => {
    for (const seats of [2, 3, 4]) {
      const actor = sockets(seats)[0];
      const game = session(config(seats, [round({ health: 4, live: 10, amount: 1, items: rules(['Cigarettes']) })]));
      game.distribute(() => 'Cigarettes');
      game.shoot(actor, actor);
      while (game.snapshot.turn !== actor) game.shoot(game.snapshot.turn, game.snapshot.turn);
      assert.equal(game.snapshot.seats[actor].health, 3);
      const healed = event(game.use(actor, 'Cigarettes'), 'Healed');
      assert.equal(Number(healed.health), 4);
      assert.equal(game.snapshot.seats[actor].health, 4);
      assert.equal(game.snapshot.seats[actor].slots[0], null);
      assert.equal(game.snapshot.turn, actor);
    }
  });

  scenario('phone ranges, singleton omission, and seventh-shell cap', () => {
    for (const seats of [2, 3, 4]) for (const length of [1, 2, 3, 4, 8, 10]) {
      const actor = sockets(seats)[0];
      const mixed = length === 3 || length >= 8;
      const game = session(config(seats, [round({ live: length - Number(mixed), blank: Number(mixed), amount: 1, items: rules(['Phone']) })]));
      game.distribute(() => 'Phone');
      const notes = game.use(actor, 'Phone');
      if (length <= 2) privateResult(notes, actor, 'NoClue');
      else if (length === 3) privateResult(notes, actor, 'Clue', { position: 3, shell: 'Blank' });
      else {
        assert.deepEqual(game.request, { kind: 'Draw', label: 'PhoneIndex', lo: 2, hi: length - 1 });
        assert.equal(told(notes).length, 0);
        privateResult(game.answer(999), actor, 'Clue', { position: Math.min(length, 7), shell: 'Live' });
      }
      assert.equal(game.request.kind, 'Choose');
      const trace = traceJSON(R, 'phone', game.config, game.tape);
      assert.equal(trace.points.filter(point => point.request.label === 'PhoneIndex').length, Number(length > 3));
    }
  });

  scenario('trace round specs preserve explicit disabled item rules', () => {
    const game = session(config(3, [round({ amount: 1, items: { saw: { enabled: false }, beer: {} } })]));
    game.distribute();
    assert.ok(Object.values(game.snapshot.seats).every(s => s.slots[0] === 'Beer'));
    assert.ok(!shown(game.notes).some(e => kind(e) === 'Granted' && kind(e.item) === 'Saw'));
  });

  scenario('held grants count against table caps and resource order', () => {
    const game = session(config(3, [round({ live: 2, amount: 1, items: {
      inverter: {}, adrenaline: {}, remote: { per_player: 1, on_table: 1 },
    } })]));
    game.draws();
    game.move(0, move => 'Grab' in move);
    assert.deepEqual(array(game.state.frame.continuation.pool).map(kind), ['Inverter', 'Adrenaline', 'Remote']);
    game.answer(2);
    assert.equal(game.snapshot.seats[0].holding, 'Remote');
    game.move(1, move => 'Grab' in move);
    assert.deepEqual(array(game.state.frame.continuation.pool).map(kind), ['Inverter', 'Adrenaline']);
    game.answer(0);
    game.place(1);
    assert.equal(game.snapshot.seats[0].holding, 'Remote');
    game.place(0);
    game.distribute(() => 'Inverter');
    assert.equal(Object.values(game.snapshot.seats).flatMap(s => s.slots).filter(item => item === 'Remote').length, 1);
  });

  scenario('empty-pool grab has no draw or grant and disables intake', () => {
    for (const seats of [2, 3, 4]) {
      const [actor, other] = sockets(seats);
      const game = session(config(seats, [round({ amount: 1, items: { saw: { per_player: 1, on_table: 1 } } })]));
      game.draws();
      game.grant(actor, 'Saw');
      const notes = game.move(other, move => 'Grab' in move);
      privateResult(notes, other, 'EmptyBriefcase');
      assert.equal(shown(notes).length, 0, 'empty pool does not emit a grant');
      assert.equal(game.snapshot.seats[other].holding, null);
      assert.equal(game.request.kind, 'Choose');
      assert.ok(!game.moves.some(({ seat: s }) => s === other), 'empty intake stays disabled until distribution ends');
      game.place(actor);
      assert.equal(game.request.label, 'SequenceBatch');
      assert.equal(game.state.host.distributing, false);
      assert.equal(traceJSON(R, 'empty-pool', game.config, game.tape).points.filter(point => point.request.label === 'ItemChoice').length, 0);
    }
  });

  scenario('player caps and eight full slots stop ordinary grants', () => {
    for (const seats of [2, 3, 4]) {
      const capped = session(config(seats, [round({ health: 3, amount: 8, items: { beer: { per_player: 1, on_table: 32 } } })]));
      capped.distribute();
      assert.ok(Object.values(capped.snapshot.seats).every(s => s.slots.filter(Boolean).length === 1));
      const full = session(config(seats, [round({ health: 3, amount: 8, items: rules(['Beer']) })]));
      full.distribute();
      assert.ok(Object.values(full.snapshot.seats).every(s => s.slots.every(item => item === 'Beer')));
      full.shoot(sockets(seats)[0], sockets(seats)[1]);
      assert.equal(full.request.label, 'SequenceBatch', 'full inventories do not start reload distribution');
      full.draws();
      assert.ok(Object.values(full.snapshot.seats).every(s => !s.grabbing && s.slots.every(item => item === 'Beer')));
    }
  });

  scenario('beer-out preserves saw through reload and passes doubled damage', () => {
    for (const seats of [2, 3, 4]) {
      const [actor, opponent] = sockets(seats);
      const game = session(config(seats, [round({ health: 4, amount: 2, items: rules(['Saw', 'Beer']) })]));
      game.distribute((s, snapshot) => snapshot.seats[s].slots.includes('Saw') ? 'Beer' : 'Saw');
      game.use(actor, 'Saw');
      const beer = game.use(actor, 'Beer');
      event(beer, 'Ejected');
      assert.equal(game.snapshot.sawed, true);
      assert.ok(!shown(beer).some(e => ['Fired', 'RoundWon', 'DirectionFlipped'].includes(kind(e))));
      game.distribute();
      assert.equal(game.snapshot.turn, opponent);
      assert.equal(game.snapshot.sawed, true);
      assert.ok(!game.moves.some(({ move }) => move.UseItem?.[1] === 'Saw'), 'the next player cannot re-saw the carried barrel');
      const fired = event(game.shoot(opponent, actor), 'Fired');
      assert.equal(kind(fired.captured), 'Double');
      assert.equal(Number(fired.applied), 2);
      assert.equal(game.snapshot.seats[actor].health, 2);
      assert.equal(game.snapshot.sawed, false);
    }
  });

  scenario('jammer skips once, lifts, and resets checked on re-jam', () => {
    for (const seats of [2, 3, 4]) {
      const [actor, opponent] = sockets(seats);
      const game = session(config(seats, [round({ health: 6, live: 10, amount: 2, items: rules(['Jammer']) })]));
      game.distribute(() => 'Jammer');
      game.use(actor, 'Jammer');
      game.move(actor, move => move.JamTarget === opponent);
      assert.ok(!game.moves.some(({ move }) => move.JamTarget === opponent));
      const skipped = game.shoot(actor, actor);
      assert.equal(seatNumber(event(skipped, 'TurnSkipped').seat), opponent);
      assert.equal(game.snapshot.seats[opponent].jam_checked, true);
      for (let fuel = 0; game.snapshot.turn !== actor; fuel++) {
        assert.ok(fuel < seats);
        game.shoot(game.snapshot.turn, game.snapshot.turn);
      }
      const lifted = game.shoot(actor, actor);
      event(lifted, 'JamLifted');
      assert.equal(game.snapshot.turn, opponent);
      assert.equal(game.snapshot.seats[opponent].jammed, false);
      assert.equal(game.snapshot.seats[opponent].jam_checked, false);
      while (game.snapshot.turn !== actor) game.shoot(game.snapshot.turn, game.snapshot.turn);
      game.use(actor, 'Jammer');
      game.move(actor, move => move.JamTarget === opponent);
      assert.equal(game.snapshot.seats[opponent].jammed, true);
      assert.equal(game.snapshot.seats[opponent].jam_checked, false);
    }
  });

  scenario('real capped round inventories clear before each new handout', () => {
    for (const seats of [2, 3, 4]) {
      const game = session(config(seats, Array.from({ length: 3 }, () => round({ amount: 1, items: { phone: { per_player: 1, on_table: seats } } }))));
      for (let roundIndex = 0; roundIndex < 3; roundIndex++) {
        game.distribute(() => 'Phone');
        assert.equal(game.snapshot.round_index, roundIndex);
        assert.ok(Object.values(game.snapshot.seats).every(s => s.slots[0] === 'Phone' && s.slots.slice(1).every(item => item === null)));
        while (game.snapshot.round_index === roundIndex && game.request.kind !== 'Finished') {
          const actor = game.snapshot.turn;
          const target = sockets(seats).find(s => s !== actor && game.snapshot.seats[s].health > 0);
          game.shoot(actor, target);
          game.draws();
        }
        if (roundIndex < 2) {
          assert.ok(Object.values(game.snapshot.seats).every(s => s.slots.every(item => item === null)));
          assert.ok(game.moves.every(({ move }) => 'Grab' in move));
        }
      }
      assert.equal(game.request.kind, 'Finished');
    }
  });

  scenario('exact completion does not distribute OR inside forall', () => {
    const game = session(config(3, [round({ health: 3, amount: 2, items: {
      saw: { per_player: 1, on_table: 3 }, beer: { per_player: 1, on_table: 1 },
    } })]));
    game.draws();
    game.grant(0, 'Saw');
    game.place(0);
    game.grant(1, 'Saw');
    game.place(1);
    game.grant(0, 'Beer');
    boardFixture(game, { 2: { health: 0, grabbing: false } });
    game.place(0, 1);
    assert.equal(game.state.host.distributing, false);
    assert.equal(game.request.label, 'SequenceBatch');
    event(game.notes, 'DistributionDone');
  });

  scenario('excludes holders from the noneligible end list', () => {
    const game = session(config(3, [round({ amount: 1, items: { saw: { per_player: 1, on_table: 3 }, beer: { per_player: 1, on_table: 1 } } })]));
    game.draws();
    game.grant(0, 'Saw');
    game.grant(1, 'Beer');
    boardFixture(game, { 1: { inventory: ['Saw'] }, 2: { health: 0, grabbing: false } });
    game.place(1, 1);
    assert.equal(game.state.host.distributing, true);
    assert.equal(game.snapshot.seats[0].holding, 'Saw');
    assert.equal(game.snapshot.seats[0].grabbing, true);
    assert.ok(game.moves.some(({ seat: s, move }) => s === 0 && 'Place' in move));
    game.place(0);
    assert.equal(game.state.host.distributing, false);
  });

  scenario('all-pools-empty completion drains holders before the next load', () => {
    for (const seats of [2, 3, 4]) {
      const table = sockets(seats);
      const game = session(config(seats, [round({ amount: 1, items: { saw: { per_player: 1, on_table: seats } } })]));
      game.draws();
      for (const s of table) game.grant(s, 'Saw');
      const notes = game.place(table[0]);
      event(notes, 'DistributionDone');
      assert.equal(game.state.host.distributing, false, 'completion is latched once every pool is empty');
      assert.equal(game.request.kind, 'Choose', 'the next load waits for held items');
      assert.ok(game.moves.every(({ move }) => 'Place' in move), 'latched completion cannot expose new grabs');
      for (const s of table.slice(1)) {
        assert.equal(game.snapshot.seats[s].holding, 'Saw');
        assert.equal(shown(game.place(s)).filter(e => kind(e) === 'DistributionDone').length, 0, 'completion emits only once');
      }
      assert.equal(game.request.label, 'SequenceBatch');
      assert.ok(Object.values(game.snapshot.seats).every(s => s.slots[0] === 'Saw' && s.holding === null));
    }
  });

  scenario('refusal uses thief target rules and counts dead owners', () => {
    for (const seats of [2, 3, 4]) {
      const [actor, owner] = sockets(seats);
      const game = session(config(seats, [round({ health: 3, live: 3 })]));
      game.draws();
      const change = Object.fromEntries(sockets(seats).map(s => [s, { inventory: [], jammed: s !== actor }]));
      change[actor].inventory = ['Adrenaline', 'Saw', 'Jammer'];
      change[owner].inventory = ['Adrenaline', 'Saw', 'Jammer'];
      boardFixture(game, change, { sawed: true });
      refreshIdle(game);
      assert.ok(!game.moves.some(({ move }) => ['Adrenaline', 'Saw', 'Jammer'].includes(move.UseItem?.[1])), 'invalid items cannot enter a secondary stall');
      boardFixture(game, { [owner]: { inventory: ['Adrenaline', 'Saw', 'Jammer', 'Glass'], health: 0 } });
      refreshIdle(game);
      game.use(actor, 'Adrenaline');
      assert.deepEqual(game.moves.map(({ move }) => move.Steal), [[owner, 3, 'Glass']]);
      privateResult(game.move(actor, move => move.Steal?.[2] === 'Glass'), actor, 'Glimpse', { shell: 'Live' });
    }
  });

  console.log(`item scenarios: ${count} passed`);
} finally {
  close();
}
