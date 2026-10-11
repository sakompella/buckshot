import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const directory = process.env.BUCKSHOT_REVIEW_DIR ?? '/tmp/buckshot-model-review';
mkdirSync(directory, { recursive: true });
const compiler = process.env.BEND_BIN ?? 'bend';
for (const [source, output] of [['model', 'verify-model'], ['controller', 'verify-model-controller']]) {
  const input = new URL(`./${source}.bend`, import.meta.url).pathname;
  const build = spawnSync(compiler, [input, '-o', `${directory}/${output}.mjs`], { encoding: 'utf8' });
  if (build.error) throw build.error;
  assert.equal(build.status, 0, `Bend compilation failed: ${build.stdout}${build.stderr}`);
}
const M = (await import(`${directory}/verify-model.mjs`)).default;
const C = (await import(`${directory}/verify-model-controller.mjs`)).default;

const tag = ($, fields = {}) => ({ $, ...fields });
const list = xs => xs.reduceRight((tail, head) => tag('Con', { head, tail }), tag('Nil'));
const array = xs => { const out = []; for (; xs.$ === 'Con'; xs = xs.tail) out.push(xs.head); return out; };
const player = (hp = 4n, items = [], jammed = false, checked = false) => tag('Player', { hp, items: list(items.map(x => tag(x))), jammed, checked });
const game = (fields = {}) => tag('Game', {
  a: player(), b: player(), turn: tag('A'), max_hp: 4n,
  shells: list(['Live', 'Blank', 'Live'].map(x => tag(x))), deck: M.default_deck(),
  seed: 123, counter: 0, sawed: false, round: 1n,
  wins_a: 0, wins_b: 0, cash_a: 0, cash_b: 0, done: false, ...fields,
});
const shoot = target => tag('Shoot', { target: tag(target) });
const use = item => tag('Use', { item: tag(item) });
const steal = item => tag('Steal', { item: tag(item) });
const results = [];
function check(name, f) {
  try { const detail = f(); results.push({ name, status: 'pass', detail }); }
  catch (e) { results.push({ name, status: 'fail', error: String(e), stack: e.stack }); }
}
function prefix(value) {
  if (Array.isArray(value)) return value.map(prefix);
  if (!value || typeof value !== 'object') return value;
  const plain = new Set(['Con', 'Nil', 'Some', 'None', 'Tuple', 'Mem', 'Seen', 'Story', 'DoN']);
  return Object.fromEntries(Object.entries(value).map(([k,v]) => [k, k === '$' && !plain.has(v) ? `model.${v}` : prefix(v)]));
}

check('shot turn and health laws, 144 explicit states', () => {
  let cases = 0;
  for (const side of ['A', 'B']) for (const shell of ['Live', 'Blank'])
  for (const target of ['Self', 'Opp']) for (const sawed of [false, true])
  for (let a = 2n; a <= 4n; a++) for (let b = 2n; b <= 4n; b++) {
    const before = game({ a: player(a), b: player(b), turn: tag(side), sawed,
      shells: list([tag(shell), tag('Blank')]) });
    const out = M.step(before, shoot(target));
    const g = out.fst;
    const events = array(out.snd);
    const dmg = sawed ? 2n : 1n;
    const victim = target === 'Self' ? side : side === 'A' ? 'B' : 'A';
    const hpA = a - (shell === 'Live' && victim === 'A' ? dmg : 0n);
    const hpB = b - (shell === 'Live' && victim === 'B' ? dmg : 0n);
    assert.equal(events[0].$, 'Fired');
    assert.equal(events[0].damage, dmg);
    if (hpA && hpB) {
      assert.equal(g.a.hp, hpA); assert.equal(g.b.hp, hpB);
      assert.equal(array(g.shells).length, 1);
      assert.equal(g.sawed, false);
      assert.equal(g.turn.$, shell === 'Blank' && target === 'Self' ? side : side === 'A' ? 'B' : 'A');
    } else {
      assert.equal(events[1].$, 'RoundWon');
      assert.equal(events[1].side.$, hpA === 0n ? 'B' : 'A');
    }
    cases++;
  }
  return { cases };
});

check('damage floors at zero and cigs respect cap', () => {
  for (let hp = 0n; hp <= 4n; hp++) for (let damage = 0n; damage <= 6n; damage++)
    assert.equal(M.damage_hp(hp, damage), hp > damage ? hp - damage : 0n);
  for (let hp = 1n; hp <= 4n; hp++) {
    const out = M.step(game({ a: player(hp, ['Cigs']) }), use('Cigs'));
    assert.equal(out.fst.a.hp, hp < 4n ? hp + 1n : 4n);
    assert.equal(array(out.fst.a.items).length, 0);
  }
});

check('jammer skip and clear across two shots', () => {
  let g = game({ a: player(4n, ['Jammer']), shells: list(['Blank', 'Blank', 'Live', 'Blank'].map(x => tag(x))) });
  let out = M.step(g, use('Jammer')); g = out.fst;
  assert.equal(g.b.jammed, true); assert.equal(g.b.checked, false);
  out = M.step(g, shoot('Opp')); g = out.fst;
  assert.equal(g.turn.$, 'A'); assert.equal(g.b.jammed, true); assert.equal(g.b.checked, true);
  assert.equal(array(out.snd)[1].$, 'Skipped');
  out = M.step(g, shoot('Opp')); g = out.fst;
  assert.equal(g.turn.$, 'B'); assert.equal(g.b.jammed, false); assert.equal(g.b.checked, true);
});

check('jam persists when blank-self keeps turn and through reload', () => {
  let g = game({ a: player(4n, ['Jammer']), shells: list([tag('Blank')]) });
  g = M.step(g, use('Jammer')).fst;
  let out = M.step(g, shoot('Self')); g = out.fst;
  assert.equal(g.turn.$, 'A'); assert.equal(g.b.checked, false); assert.equal(g.b.jammed, true);
  assert.equal(array(out.snd)[1].$, 'Reloaded');
  out = M.step(g, shoot('Opp'));
  assert.equal(out.fst.turn.$, 'A'); assert.equal(out.fst.b.checked, true);
});

check('deck cycle, shell counts, turn, and inventory caps across 100 seeds', () => {
  const caps = { Saw:2, Glass:2, Jammer:1, Cigs:1, Beer:8, Phone:8, Adrenaline:4, Inverter:4 };
  for (let seed = 0; seed < 100; seed++) {
    let g = game({ seed, turn: tag('B') });
    for (let cycle = 0; cycle < 3; cycle++) {
      const seen = [];
      for (let i = 0; i < 9; i++) {
        const out = M.reload(g); g = out.fst;
        const e = array(out.snd)[0];
        assert.equal(g.turn.$, 'B');
        assert.equal(array(g.deck).length, 8-i);
        const shells = array(g.shells);
        assert.equal(BigInt(shells.filter(x => x.$ === 'Live').length), e.live);
        assert.equal(BigInt(shells.filter(x => x.$ === 'Blank').length), e.blank);
        seen.push(`${e.live}/${e.blank}`);
        const inventories = [array(g.a.items), array(g.b.items)];
        assert(inventories.flat().filter(x => x.$ === 'Jammer').length <= 1);
        for (const inv of inventories) {
          assert(inv.length <= 8);
          for (const [item,cap] of Object.entries(caps)) assert(inv.filter(x => x.$ === item).length <= cap);
        }
      }
      assert.deepEqual(seen.sort(), ['1/2','2/1','2/2','3/2','1/1','2/3','3/3','3/1','4/2'].sort());
    }
  }
  return { reloads: 2700 };
});

check('shuffle realizes all six arrangements of 2 live and 2 blank', () => {
  const seqs = new Map();
  for (let seed = 0; seed < 1000; seed++) {
    const out = M.reload(game({ seed, deck: list([tag('Load', { live: 2n, blank: 2n })]) }));
    const key = array(out.fst.shells).map(x => x.$[0]).join('');
    seqs.set(key, (seqs.get(key) ?? 0) + 1);
  }
  assert.equal(seqs.size, 6);
  return Object.fromEntries(seqs);
});

check('beer consumes chamber, keeps turn, and reloads immediately if empty', () => {
  for (const remaining of [1,3]) {
    const out = M.step(game({ a: player(4n, ['Beer']), shells: list(Array.from({ length: remaining }, () => tag('Blank'))) }), use('Beer'));
    assert.equal(out.fst.turn.$, 'A');
    const es = array(out.snd);
    assert.equal(es[0].$, 'Used'); assert.equal(es[1].$, 'Ejected');
    if (remaining === 1) assert.equal(es[2].$, 'Reloaded');
    else { assert.equal(array(out.fst.shells).length, 2); assert.equal(array(out.fst.a.items).length, 0); }
  }
});

check('steal consumes one adrenaline and opponent item, applies effect now', () => {
  const out = M.step(game({ a: player(2n, ['Adrenaline', 'Adrenaline']), b: player(4n, ['Cigs']) }), steal('Cigs'));
  assert.equal(out.fst.a.hp, 3n);
  assert.deepEqual(array(out.fst.a.items).map(x => x.$), ['Adrenaline']);
  assert.equal(array(out.fst.b.items).length, 0);
  assert.equal(array(out.snd)[0].stolen, true);
  const invalid = M.step(game({ a: player(4n, ['Adrenaline']), b: player(4n, ['Adrenaline']) }), steal('Adrenaline'));
  assert.equal(array(invalid.snd).length, 0);
  assert.equal(array(invalid.fst.a.items).length, 1);
  assert.equal(array(invalid.fst.b.items).length, 1);
});

check('glass and phone addressed only to actor; phone indices valid', () => {
  const out = M.step(game({ turn: tag('B'), b: player(4n, ['Glass']) }), use('Glass'));
  const e = array(out.snd)[1];
  assert.equal(e.$, 'Reveal'); assert.equal(e.side.$, 'B'); assert.equal(e.index, 0n); assert.equal(e.shell.$, 'Live');
  for (let seed = 0; seed < 100; seed++) {
    const p = M.step(game({ seed, a: player(4n, ['Phone']) }), use('Phone'));
    const e = array(p.snd)[1];
    assert(e.index >= 1n && e.index <= 2n);
    assert.equal(e.shell.$, ['Live','Blank','Live'][Number(e.index)]);
  }
  const invalid = M.step(game({ a: player(4n, ['Phone']), shells: list([tag('Blank'),tag('Live')]) }), use('Phone'));
  assert.equal(array(invalid.snd).length, 0); assert.equal(array(invalid.fst.a.items).length, 1);
});

check('inverter toggles both live and blank chambers', () => {
  for (const shell of ['Live', 'Blank']) {
    const out = M.step(game({ a: player(4n, ['Inverter']), shells: list([tag(shell),tag('Live')]) }), use('Inverter'));
    assert.equal(array(out.fst.shells)[0].$, shell === 'Live' ? 'Blank' : 'Live');
    assert.equal(array(out.snd)[1].shell.$, shell === 'Live' ? 'Blank' : 'Live');
  }
});

check('all three rounds paid, loser starts, deck persists, final cash wins', () => {
  for (let bits = 0; bits < 8; bits++) {
    let g = game(); let aCash = 0; let bCash = 0;
    for (let round = 1; round <= 3; round++) {
      const aWins = !!(bits & (1 << (round-1)));
      const winner = aWins ? 'A' : 'B'; const loser = aWins ? 'B' : 'A';
      const deckBefore = list([tag('Load', { live: 3n, blank: 1n }),tag('Load', { live: 4n, blank: 2n })]);
      g = { ...g, turn: tag(winner), shells: list([tag('Live')]), deck: deckBefore,
        a: player(aWins ? 4n : 1n, ['Phone']), b: player(aWins ? 1n : 4n, ['Beer']) };
      const out = M.step(g, shoot('Opp')); g = out.fst; const es = array(out.snd);
      const prize = [70000,75000,80000][round-1];
      if (aWins) aCash += prize; else bCash += prize;
      assert.equal(g.cash_a, aCash); assert.equal(g.cash_b, bCash);
      assert.equal(g.turn.$, loser); assert.equal(g.round, BigInt(round+1));
      assert.equal(es[1].$, 'RoundWon'); assert.equal(es[1].prize, prize);
      if (round < 3) {
        assert.equal(es[2].$, 'RoundStarted'); assert.equal(es[2].first.$, loser);
        assert.equal(array(g.deck).length, 1);
        assert(g.max_hp === 3n || g.max_hp === 4n);
        assert.equal(g.a.hp, g.max_hp); assert.equal(g.b.hp, g.max_hp);
        assert.equal(g.a.jammed, false); assert.equal(g.b.jammed, false);
      } else {
        assert.equal(g.done, true); assert.equal(es[2].$, 'MatchWon');
        assert.equal(es[2].side.$, aCash > bCash ? 'A' : 'B');
        assert.equal(array(g.deck).length, 2);
        assert.equal(array(M.step(g,use('Beer')).snd).length, 0);
      }
    }
  }
});

check('observe hides shell order and exposes only counts', () => {
  const obs = M.observe(game(),tag('B'));
  assert(!('shells' in obs)); assert(!('seed' in obs)); assert(!('deck' in obs));
  assert.equal(obs.live, 2n); assert.equal(obs.blank, 1n); assert.equal(obs.remaining, 3n);
});

check('controller event memory stays private, shifts, inverts, and reload clears', () => {
  let memA = C.fresh(); let memB = C.fresh();
  const reveal = prefix(tag('Reveal',{ side: tag('A'), index: 1n, shell: tag('Live') }));
  memA = C.update_event(reveal,tag('DoN'),tag('model.A'),memA);
  memB = C.update_event(reveal,tag('DoN'),tag('model.B'),memB);
  assert.equal(array(memA.phone).length, 1); assert.equal(array(memB.phone).length, 0);
  const fired = prefix(tag('Fired',{ side: tag('B'), target: tag('Opp'), shell: tag('Blank'), damage: 1n }));
  memA = C.update_event(fired,tag('DoN'),tag('model.A'),memA);
  assert.equal(array(memA.phone)[0].index, 0n);
  const inverted = prefix(tag('Inverted',{ side: tag('B'), shell: tag('Blank') }));
  memA = C.update_event(inverted,tag('DoN'),tag('model.A'),memA);
  assert.equal(array(memA.phone)[0].shell.$, 'model.Blank');
  assert.equal(memA.known.$, 'None');
  const prep = C.prepare(tag('DoN'),prefix(M.observe(game({ shells: list([tag('Blank'),tag('Live'),tag('Blank')]) }),tag('A'))),memA);
  assert.equal(prep.known.value.$, 'model.Blank');
  memA = C.update_event(prefix(tag('Reloaded',{live:2n,blank:2n})),tag('DoN'),tag('model.A'),prep);
  assert.equal(array(memA.phone).length, 0); assert.equal(memA.known.$,'None');
});

check('public start/step sequences preserve round, cap, and turn-ready invariants', () => {
  let transitions = 0;
  for (let seed = 0; seed < 64; seed++) {
    let g = M.start(seed).fst;
    for (let i = 0; i < 128 && !g.done; i++) {
      const own = g.turn.$ === 'A' ? g.a : g.b;
      const opp = g.turn.$ === 'A' ? g.b : g.a;
      const candidates = [shoot('Self'), shoot('Opp')];
      for (const item of array(own.items)) {
        if (item.$ !== 'Adrenaline' && (item.$ !== 'Phone' || array(g.shells).length > 2)) candidates.push(use(item.$));
      }
      if (array(own.items).some(x => x.$ === 'Adrenaline')) {
        for (const item of array(opp.items)) {
          if (item.$ !== 'Adrenaline' && (item.$ !== 'Phone' || array(g.shells).length > 2)) candidates.push(steal(item.$));
        }
      }
      const choice = M.mix(seed*128+i) % candidates.length;
      g = M.step(g,candidates[choice]).fst;
      assert(g.a.hp <= g.max_hp && g.b.hp <= g.max_hp);
      assert(array(g.a.items).length <= 8 && array(g.b.items).length <= 8);
      assert([...array(g.a.items), ...array(g.b.items)].filter(x => x.$ === 'Jammer').length <= 1);
      assert.equal(g.wins_a + g.wins_b, Number(g.round)-1);
      assert.equal(g.cash_a + g.cash_b, [0,0,70000,145000,225000][Number(g.round)]);
      if (!g.done) {
        assert(g.a.hp > 0n && g.b.hp > 0n);
        assert(array(g.shells).length > 0);
        assert.equal((g.turn.$ === 'A' ? g.a : g.b).jammed, false);
      } else assert.equal(g.round, 4n);
      transitions++;
    }
  }
  return { transitions };
});

check('step skips unchecked jam and drops the requested action', () => {
  const out = M.step(game({ a: player(4n, [], true, false) }),shoot('Opp'));
  const es = array(out.snd);
  assert.equal(es.length, 1); assert.equal(es[0].$, 'Skipped');
  assert.equal(out.fst.turn.$, 'B'); assert.equal(out.fst.b.hp, 4n);
  assert.equal(out.fst.a.jammed, true); assert.equal(out.fst.a.checked, true);
  assert.equal(array(out.fst.shells).length, 3);
});

check('step clears checked jam and applies the requested action', () => {
  const out = M.step(game({ a: player(4n, [], true, true) }),shoot('Opp'));
  assert.equal(array(out.snd)[0].$, 'Fired');
  assert.equal(out.fst.a.jammed, false); assert.equal(out.fst.a.checked, true);
  assert.equal(out.fst.b.hp, 3n); assert.equal(out.fst.turn.$, 'B');
  assert.equal(array(out.fst.shells).length, 2);
});


writeFileSync(`${directory}/verify-model-results.json`, JSON.stringify({ results }, (_,v) => typeof v === 'bigint' ? String(v) : v, 2));
for (const r of results) console.log(`${r.status.toUpperCase()} ${r.name}${r.error ? ': ' + r.error : ''}`);
console.log(JSON.stringify({ passed: results.filter(r => r.status === 'pass').length, failed: results.filter(r => r.status === 'fail').length }));
process.exitCode = results.some(r => r.status === 'fail') ? 1 : 0;
