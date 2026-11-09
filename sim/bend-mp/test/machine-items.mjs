import assert from 'node:assert/strict';
import { config, round, list, array, kind, seatNumber, tag, maybe, requestJSON, stateJSON, machineJam } from './reference-adapter.mjs';
import { items, loadModels, lockstep, makeRandom, nil, normalize, ring, rules } from './machine-items-lib.mjs';

const { M, R, close } = await loadModels('bend-mp-machine-items-');
try {
  const { compare, sameNotes, boundaries } = lockstep(M, R);

  const sockets = n => n === 2 ? [1, 3] : Array.from({ length: n }, (_, i) => i);

  function dual(c, label) {
    const r = R.start(c), m = M.start(c);
    sameNotes(m.notes, r.notes, `${label} start`);
    compare(r.state, m.state, `${label} start`);
    return {
      label, config: c, r: r.state, m: m.state, notes: array(r.notes), tape: [],
      get request() { return requestJSON(R.point(this.r).request); },
      get snapshot() { return stateJSON(R.snapshot(this.r)); },
      get moves() {
        assert.equal(this.request.kind, 'Choose');
        return Object.entries(this.request.menus).flatMap(([s, menu]) => menu.map(move => ({ seat: Number(s), move })));
      },
      answer(n) {
        this.tape.push(n);
        const where = `${this.label} tape ${JSON.stringify(this.tape)}`;
        const nr = R.answer(this.r, n), nm = M.answer(this.m, n);
        sameNotes(nm.notes, nr.notes, where);
        compare(nr.state, nm.state, where);
        this.r = nr.state;
        this.m = nm.state;
        const notes = array(nr.notes);
        this.notes.push(...notes);
        return notes;
      },
      move(s, accepts) {
        const index = this.moves.findIndex(choice => choice.seat === s && accepts(choice.move));
        assert.ok(index >= 0, `seat ${s} has required move in ${JSON.stringify(this.request)}`);
        return this.answer(index);
      },
      draws() {
        for (let fuel = 0; this.request.kind === 'Draw'; fuel++) {
          assert.ok(fuel < 64, 'draw closure terminates');
          this.answer(this.request.label === 'ShuffleSwap' ? this.request.hi : 0);
        }
      },
      grant(s, item) {
        this.move(s, move => 'Grab' in move);
        if (this.request.kind === 'Draw') {
          assert.equal(this.request.label, 'ItemChoice');
          const index = array(this.r.frame.continuation.pool).map(kind).indexOf(item);
          assert.ok(index >= 0, `${item} is in the eligible pool`);
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
          else this.place(choice.seat, choice.move.Place);
        }
      },
      use(s, item) { return this.move(s, move => move.UseItem?.[1] === item); },
      shoot(s, target) {
        this.move(s, move => 'PickUp' in move);
        return this.move(s, move => move.Shoot === target);
      },
      fixture(changes, sawed = null) {
        const host = { ...this.r.host, seats: { ...this.r.host.seats } };
        const players = ring(this.m.players, s => ({ ...s }));
        const grabs = { ...this.m.grabs, grabbing: { ...this.m.grabs.grabbing } };
        for (const [s, change] of Object.entries(changes)) {
          const key = `s${s}`;
          const slots = change.inventory && { ...host.seats[key].slots, ...Object.fromEntries(Array.from({ length: 8 }, (_, i) => [`s${i}`, maybe(change.inventory[i] ? tag(change.inventory[i]) : null)])) };
          const props = { ...host.seats[key] };
          if ('health' in change) { props.health = Number(change.health); players[key].health = Number(change.health); }
          if ('jammed' in change) { props.jammed = change.jammed; players[key].jam = machineJam(change.jammed, props.jam_checked); }
          if ('grabbing' in change) { props.grabbing = change.grabbing; grabs.grabbing[key] = change.grabbing; }
          if (slots) { props.slots = slots; players[key].slots = slots; }
          host.seats[key] = props;
        }
        const world = { ...this.m.world };
        if (sawed !== null) { host.sawed = sawed; world.sawed = sawed; }
        this.r = { ...this.r, host };
        this.m = { ...this.m, world, players, grabs };
        compare(this.r, this.m, `${this.label} fixture`);
      },
      refreshIdle() {
        const actor = tag(`Seat${this.snapshot.turn}`);
        this.r = R.settle(96, { ...this.r, frame: { $: 'GiveTurnPermissions', seat: actor }, notes: nil });
        this.m = M.give_turn({ ...this.m, notes: nil }, actor);
        sameNotes(this.m.notes, this.r.notes, `${this.label} refresh`);
        compare(this.r, this.m, `${this.label} refresh`);
      },
    };
  }

  let scenarios = 0;
  const scenario = (name, run) => { run(name); scenarios++; };

  for (const seats of [2, 3, 4]) {
    const [actor, opponent] = sockets(seats);
    for (const item of items) {
      scenario(`${seats} seats grant and ${item}`, name => {
        const enabled = item === 'Adrenaline' ? ['Adrenaline', 'Beer'] : [item];
        const game = dual(config(seats, [round({ health: 4, live: 3, amount: 1, items: rules(enabled) })]), name);
        game.distribute(s => item === 'Adrenaline' && s !== actor ? 'Beer' : item);
        if (seats === 2 && item === 'Remote') return;
        game.use(actor, item);
        if (item === 'Saw') game.shoot(actor, opponent);
        if (item === 'Jammer') game.move(actor, move => move.JamTarget === opponent);
        if (item === 'Adrenaline') game.move(actor, move => move.Steal?.[0] === opponent);
        if (item === 'Remote') game.shoot(actor, opponent);
      });
    }
    for (const item of items.filter(value => value !== 'Adrenaline' && !(seats === 2 && value === 'Remote'))) {
      scenario(`${seats} seats adrenaline steals ${item}`, name => {
        const game = dual(config(seats, [round({ health: 4, live: 3, amount: 1, items: rules(['Adrenaline', item]) })]), name);
        game.distribute(s => s === actor ? 'Adrenaline' : item);
        game.use(actor, 'Adrenaline');
        game.move(actor, move => move.Steal?.[0] === opponent && move.Steal?.[2] === item);
        if (item === 'Jammer') game.move(actor, move => move.JamTarget === opponent);
      });
    }
  }

  scenario('secondary modes after aiming, jammer and adrenaline', name => {
    const aiming = dual(config(3, [round({ live: 3, amount: 1, items: rules(['Glass']) })]), name);
    aiming.distribute(() => 'Glass');
    aiming.move(0, move => 'PickUp' in move);
    for (const item of ['Jammer', 'Adrenaline']) {
      const game = dual(config(3, [round({ live: 3, amount: 2, items: rules([item, 'Glass']) })]), `${name} ${item}`);
      game.distribute((s, snapshot) => s === 0 && !snapshot.seats[s].slots.includes(item) ? item : 'Glass');
      game.use(0, item);
    }
  });

  scenario('cigarettes heal after damage', name => {
    for (const seats of [2, 3, 4]) {
      const actor = sockets(seats)[0];
      const game = dual(config(seats, [round({ health: 4, live: 10, amount: 1, items: rules(['Cigarettes']) })]), `${name} ${seats}`);
      game.distribute(() => 'Cigarettes');
      game.shoot(actor, actor);
      while (game.snapshot.turn !== actor) game.shoot(game.snapshot.turn, game.snapshot.turn);
      game.use(actor, 'Cigarettes');
    }
  });

  scenario('phone ranges and seventh-shell cap', name => {
    for (const seats of [2, 3, 4]) for (const length of [1, 2, 3, 4, 8, 10]) {
      const mixed = length === 3 || length >= 8;
      const game = dual(config(seats, [round({ live: length - Number(mixed), blank: Number(mixed), amount: 1, items: rules(['Phone']) })]), `${name} ${seats}/${length}`);
      game.distribute(() => 'Phone');
      game.use(sockets(seats)[0], 'Phone');
      if (length > 3) game.answer(999);
    }
  });

  scenario('explicit disabled item rules', name => {
    dual(config(3, [round({ amount: 1, items: { saw: { enabled: false }, beer: {} } })]), name).distribute();
  });

  scenario('held grants count against table caps', name => {
    const game = dual(config(3, [round({ live: 2, amount: 1, items: { inverter: {}, adrenaline: {}, remote: { per_player: 1, on_table: 1 } } })]), name);
    game.draws();
    game.move(0, move => 'Grab' in move);
    game.answer(2);
    game.move(1, move => 'Grab' in move);
    game.answer(0);
    game.place(1);
    game.place(0);
    game.distribute(() => 'Inverter');
  });

  scenario('empty-pool grab disables intake', name => {
    for (const seats of [2, 3, 4]) {
      const [actor, other] = sockets(seats);
      const game = dual(config(seats, [round({ amount: 1, items: { saw: { per_player: 1, on_table: 1 } } })]), `${name} ${seats}`);
      game.draws();
      game.grant(actor, 'Saw');
      game.move(other, move => 'Grab' in move);
      game.place(actor);
    }
  });

  scenario('player caps and full slots', name => {
    for (const seats of [2, 3, 4]) {
      dual(config(seats, [round({ health: 3, amount: 8, items: { beer: { per_player: 1, on_table: 32 } } })]), `${name} capped ${seats}`).distribute();
      const full = dual(config(seats, [round({ health: 3, amount: 8, items: rules(['Beer']) })]), `${name} full ${seats}`);
      full.distribute();
      full.shoot(sockets(seats)[0], sockets(seats)[1]);
      full.draws();
    }
  });

  scenario('beer-out keeps the saw through reload', name => {
    for (const seats of [2, 3, 4]) {
      const [actor, opponent] = sockets(seats);
      const game = dual(config(seats, [round({ health: 4, amount: 2, items: rules(['Saw', 'Beer']) })]), `${name} ${seats}`);
      game.distribute((s, snapshot) => snapshot.seats[s].slots.includes('Saw') ? 'Beer' : 'Saw');
      game.use(actor, 'Saw');
      game.use(actor, 'Beer');
      game.distribute();
      game.shoot(opponent, actor);
    }
  });

  scenario('jammer skips once, lifts, and re-jams', name => {
    for (const seats of [2, 3, 4]) {
      const [actor, opponent] = sockets(seats);
      const game = dual(config(seats, [round({ health: 6, live: 10, amount: 2, items: rules(['Jammer']) })]), `${name} ${seats}`);
      game.distribute(() => 'Jammer');
      game.use(actor, 'Jammer');
      game.move(actor, move => move.JamTarget === opponent);
      game.shoot(actor, actor);
      while (game.snapshot.turn !== actor) game.shoot(game.snapshot.turn, game.snapshot.turn);
      game.shoot(actor, actor);
      while (game.snapshot.turn !== actor) game.shoot(game.snapshot.turn, game.snapshot.turn);
      game.use(actor, 'Jammer');
      game.move(actor, move => move.JamTarget === opponent);
    }
  });

  scenario('M3 capped inventories clear before each handout', name => {
    for (const seats of [2, 3, 4]) {
      const game = dual(config(seats, Array.from({ length: 3 }, () => round({ amount: 1, items: { phone: { per_player: 1, on_table: seats } } }))), `${name} ${seats}`);
      for (let roundIndex = 0; roundIndex < 3; roundIndex++) {
        game.distribute(() => 'Phone');
        while (game.snapshot.round_index === roundIndex && game.request.kind !== 'Finished') {
          const turn = game.snapshot.turn;
          game.shoot(turn, sockets(seats).find(s => s !== turn && game.snapshot.seats[s].health > 0));
          game.draws();
        }
      }
      assert.equal(game.request.kind, 'Finished');
    }
  });

  scenario('M1 completion after a dead non-grabber', name => {
    const game = dual(config(3, [round({ health: 3, amount: 2, items: { saw: { per_player: 1, on_table: 3 }, beer: { per_player: 1, on_table: 1 } } })]), name);
    game.draws();
    game.grant(0, 'Saw');
    game.place(0);
    game.grant(1, 'Saw');
    game.place(1);
    game.grant(0, 'Beer');
    game.fixture({ 2: { health: 0, grabbing: false } });
    game.place(0, 1);
    assert.equal(game.request.label, 'SequenceBatch');
  });

  scenario('M1 keeps holders out of the noneligible end list', name => {
    const game = dual(config(3, [round({ amount: 1, items: { saw: { per_player: 1, on_table: 3 }, beer: { per_player: 1, on_table: 1 } } })]), name);
    game.draws();
    game.grant(0, 'Saw');
    game.grant(1, 'Beer');
    game.fixture({ 1: { inventory: ['Saw'] }, 2: { health: 0, grabbing: false } });
    game.place(1, 1);
    game.place(0);
  });

  scenario('D56 latched completion drains holders', name => {
    for (const seats of [2, 3, 4]) {
      const table = sockets(seats);
      const game = dual(config(seats, [round({ amount: 1, items: { saw: { per_player: 1, on_table: seats } } })]), `${name} ${seats}`);
      game.draws();
      for (const s of table) game.grant(s, 'Saw');
      for (const s of table) game.place(s);
      assert.equal(game.request.label, 'SequenceBatch');
    }
  });

  scenario('M4 refusal and dead owners', name => {
    for (const seats of [2, 3, 4]) {
      const [actor, owner] = sockets(seats);
      const game = dual(config(seats, [round({ health: 3, live: 3 })]), `${name} ${seats}`);
      game.draws();
      const change = Object.fromEntries(sockets(seats).map(s => [s, { inventory: [], jammed: s !== actor }]));
      change[actor].inventory = ['Adrenaline', 'Saw', 'Jammer'];
      change[owner].inventory = ['Adrenaline', 'Saw', 'Jammer'];
      game.fixture(change, true);
      game.refreshIdle();
      assert.ok(!game.moves.some(({ move }) => ['Adrenaline', 'Saw', 'Jammer'].includes(move.UseItem?.[1])));
      game.fixture({ [owner]: { inventory: ['Adrenaline', 'Saw', 'Jammer', 'Glass'], health: 0 } });
      game.refreshIdle();
      game.use(actor, 'Adrenaline');
      game.move(actor, move => move.Steal?.[2] === 'Glass');
    }
  });
  const scenarioBoundaries = boundaries();

  const { random, randomConfig, answerFor } = makeRandom(0x6974656d);
  const seen = { M1: 0, M3: 0, M4: 0, adrenalineRefused: 0, D56: 0, steals: 0, phoneDraws: 0, itemChoices: 0, turnAmounts: 0, finished: 0, stuck: 0 };
  const observe = (game, before, notes) => {
    const events = notes.filter(note => kind(note) === 'Shown').map(note => kind(note.event));
    const done = events.indexOf('DistributionDone');
    if (done > 0 && events.slice(0, done).filter(e => e === 'GrabbingEnded').length > 1) seen.M1++;
    if (before.request.kind === 'Choose' && before.dist === false && Object.values(before.request.menus).flat().some(move => 'Place' in move)) seen.D56++;
    if (events.includes('RoundBegan') && events.includes('GrabbingBegan') && before.carried) seen.M3++;
    if (before.request.label === 'PhoneIndex') seen.phoneDraws++;
    if (before.request.label === 'ItemChoice') seen.itemChoices++;
    if (before.request.label === 'ItemAmount' && before.stage === 'Distributing') seen.turnAmounts++;
    if (Object.values(before.request.menus ?? {}).flat().some(move => 'Steal' in move)) seen.steals++;
  };
  const view = game => {
    const point = R.point(game.r);
    const request = requestJSON(point.request);
    const snapshot = game.snapshot;
    if (request.kind === 'Choose' && kind(point.board.stage) === 'Playing' && kind(point.board.stage.mode) === 'Idle') {
      const s = seatNumber(point.board.stage.seat);
      const offered = (request.menus[s] ?? []).some(move => move.UseItem?.[1] === 'Adrenaline');
      if (snapshot.seats[s].slots.includes('Adrenaline') && !offered) {
        seen.adrenalineRefused++;
        const targets = Object.entries(snapshot.seats).some(([o, props]) => Number(o) !== s && props.health > 0 && !props.jammed);
        const invalid = item => (item === 'Saw' && snapshot.sawed) || (item === 'Jammer' && !targets);
        const others = Object.entries(snapshot.seats).filter(([o]) => Number(o) !== s).flatMap(([, props]) => props.slots.filter(Boolean));
        const rawGodotAllows = others.length > 0 && !others.every(invalid) && !others.every(item => item === 'Adrenaline');
        if (rawGodotAllows) seen.M4++;
      }
    }
    return {
      request, stage: kind(point.board.stage), dist: game.r.host.distributing,
      carried: Object.values(snapshot.seats).some(props => props.slots.some(Boolean)),
    };
  };
  const phaseOf = m => kind(m.phase);
  const keysOf = ringValue => Object.keys(ringValue).filter(key => key !== '$').sort().join();
  const invariants = (m, where) => {
    const phase = phaseOf(m);
    const { players, grabs, world } = m;
    const seatKeys = keysOf(players);
    for (const r of [grabs.grabbing, grabs.holding, grabs.granted, grabs.intake]) assert.equal(keysOf(r), seatKeys, `rings share the table (${where})`);
    const keys = seatKeys.split(',');
    const slotItems = key => Object.entries(players[key].slots).filter(([k]) => k !== '$').map(([, slot]) => kind(slot) === 'Some' ? kind(slot.value) : null);
    const handling = phase === 'Grab' || phase === 'NeedItem';
    if (grabs.distributing) assert.ok(handling, `distributing only in grab phases (${where})`);
    for (const key of keys) {
      const holding = kind(grabs.holding[key]) === 'Some';
      if (holding) assert.ok(grabs.grabbing[key] && !grabs.intake[key] && handling, `a holder is grabbing, intake closed, in a grab phase (${where})`);
      if (grabs.grabbing[key] && !holding) assert.ok(grabs.granted[key] < world.item_amount, `an empty-handed grabber has grants left (${where})`);
    }
    const plan = world.config.plan;
    const rounds = Object.entries(plan).filter(([k]) => k !== '$').map(([, r]) => r);
    const enabledAnywhere = rounds.some(r => Object.entries(r.items).some(([k, rule]) => k !== '$' && rule.enabled));
    if (!enabledAnywhere) {
      assert.ok(!['Grab', 'NeedItem', 'NeedPhone', 'JamPick', 'StealPick', 'NeedTurnAmount'].includes(phase), `no-item configs never reach item phases (${where})`);
      for (const key of keys) assert.ok(slotItems(key).every(item => item === null) && !grabs.grabbing[key] && kind(grabs.holding[key]) === 'None' && !grabs.distributing, `no-item configs keep empty inventories (${where})`);
    }
    if (!['NeedHealth', 'NeedAmount'].includes(phase)) {
      const current = rounds[Number(world.round_index)] ?? rounds[0];
      for (const item of items) {
        const rule = current.items[item.toLowerCase()];
        const counts = keys.map(key => slotItems(key).filter(x => x === item).length + (kind(grabs.holding[key]) === 'Some' && kind(grabs.holding[key].value) === item ? 1 : 0));
        const total = counts.reduce((a, b) => a + b, 0);
        if (!rule.enabled) assert.equal(total, 0, `disabled ${item} is absent (${where})`);
        else assert.ok(counts.every(n => n <= Number(rule.per_player)) && total <= Number(rule.on_table), `${item} within caps (${where})`);
      }
    }
    if (['Idle', 'Aim', 'JamPick', 'StealPick', 'NeedPhone'].includes(phase)) {
      const key = `s${seatNumber(m.phase.seat)}`;
      assert.ok(kind(world.turn) === 'Some' && kind(world.turn.value) === kind(m.phase.seat), `the acting seat holds the turn (${where})`);
      assert.ok(keys.filter(k => Number(players[k].health) > 0).length >= 2, `two seats live during play (${where})`);
    }
    if (phase === 'StealPick') assert.equal(kind(m.phase.picks), 'Con', `a steal always has a pick (M4) (${where})`);
    if (phase === 'JamPick') assert.equal(kind(m.phase.targets), 'Con', `a jammer always has a target (${where})`);
  };
  let games = 0;
  for (const seats of [2, 3, 4]) {
    for (let trial = 0; trial < 50; trial++) {
      const game = dual(randomConfig(seats), `random ${seats}/${trial}`);
      for (let step = 0; step < 600; step++) {
        invariants(game.m, `${game.label} tape ${JSON.stringify(game.tape)}`);
        const before = view(game);
        if (before.request.kind === 'Finished') { seen.finished++; break; }
        if (before.request.kind === 'Stuck') { seen.stuck++; break; }
        observe(game, before, game.answer(answerFor(before.request)));
      }
      games++;
    }
  }
  for (const [situation, hits] of Object.entries(seen)) {
    if (situation !== 'stuck') assert.ok(hits > 0, `random games reach ${situation}`);
  }
  assert.equal(seen.stuck, 0, 'normal random play never reaches Stuck');
  console.log(`machine item verification: ${scenarios} scenarios, ${games} random games, ${boundaries()} boundaries (${scenarioBoundaries} scenario) passed; ${JSON.stringify(seen)}`);
} finally {
  close();
}
