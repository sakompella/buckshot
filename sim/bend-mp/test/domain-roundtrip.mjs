import assert from 'node:assert/strict';
import { copyFileSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

// Every domain value below is built by Bend constructors in a probe root that
// imports domain.bend, as the web entry will. The JS side never writes a
// domain tag, so a mistyped tag cannot slip into the last match arm unseen.
const probe = String.raw`import Base
import ./domain.bend as D

def probe.tables() -> List<&2, D.Table>:
  [D.TwoSeats{}, D.ThreeSeats{}, D.FourSeats{}]

def probe.slots() -> List<&2, D.Slot>:
  [D.Slot0{}, D.Slot1{}, D.Slot2{}, D.Slot3{}, D.Slot4{}, D.Slot5{}, D.Slot6{}, D.Slot7{}]

def probe.shells() -> List<&2, D.Shell>:
  [D.Live{}, D.Blank{}]

def probe.damages() -> List<&2, D.Damage>:
  [D.Single{}, D.Double{}]

def probe.labels() -> List<&2, D.Label>:
  [D.FirstSeat{}, D.StartingHealth{}, D.ItemAmount{}, D.ItemChoice{}, D.SequenceBatch{}, D.ShuffleSwap{}, D.PhoneIndex{}]

def probe.moves(+target: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item) -> List<&2, D.Move>:
  [D.PickUp{}, D.Shoot{target}, D.UseItem{slot, item}, D.Grab{}, D.Place{slot}, D.JamTarget{target}, D.Steal{owner, slot, item}]

def probe.events(+a: D.Seat, +b: D.Seat, shell: D.Shell, damage: D.Damage, +n: Nat, slot: D.Slot, item: D.Item) -> List<&2, D.GameEvent>:
  [D.Fired{a, b, shell, damage, n, n}, D.Died{b}, D.Used{a, b, slot, item}, D.Loaded{D.Load{n, n}}, D.MatchConcluded{}]

def probe.secrets(+shell: D.Shell, n: Nat) -> List<&2, D.Secret>:
  [D.Glimpse{shell}, D.Clue{n, shell}, D.NoClue{}, D.EmptyBriefcase{}]

def probe.shown(event: D.GameEvent) -> D.Note:
  D.Shown{event}

def probe.told(seat: D.Seat, secret: D.Secret) -> D.Note:
  D.Told{seat, secret}

def probe.witnessed(event: D.GameEvent) -> D.Heard:
  D.Witnessed{event}

def probe.learned(secret: D.Secret) -> D.Heard:
  D.Learned{secret}

def probe.draw(label: D.Label, range: D.Range) -> D.Request:
  D.Draw{label, range}

def probe.range(lo: Nat, extra: Nat) -> D.Range:
  D.Range{lo, extra}

def probe.chose(seat: D.Seat, index: Nat, move: D.Move) -> D.Resolved:
  D.Chose{D.Choice{seat, index, move}}

def probe.drawn(value: Nat) -> D.Resolved:
  D.Drawn{value}

def probe.ends() -> List<&2, D.Request>:
  [D.Finished{}, D.Stuck{}]
`;

const dir = mkdtempSync(join(tmpdir(), 'bend-mp-domain-'));
copyFileSync(new URL('../domain.bend', import.meta.url).pathname, join(dir, 'domain.bend'));
writeFileSync(join(dir, 'probe.bend'), probe);
const build = spawnSync(process.env.BEND ?? 'bend', [join(dir, 'probe.bend'), '-o', join(dir, 'probe.mjs')], { encoding: 'utf8' });
if (build.error) throw build.error;
assert.equal(build.status, 0, `bend build failed:\n${build.stdout}${build.stderr}`);
const P = (await import(join(dir, 'probe.mjs'))).default;
const D = new Proxy(P, { get: (lib, name) => lib[`domain:${name}`] ?? assert.fail(`no export domain:${name}`) });

const list = xs => xs.reduceRight((tail, head) => ({ $: 'Con', head, tail }), { $: 'Nil' });
const array = xs => { const out = []; for (; xs.$ === 'Con'; xs = xs.tail) out.push(xs.head); assert.equal(xs.$, 'Nil'); return out; };
const plain = v => JSON.parse(JSON.stringify(v));
const same = (a, b, message) => assert.deepEqual(plain(a), plain(b), message);

let seed = Number(process.env.SEED ?? 20261011) >>> 0;
const random = () => {
  seed = (seed + 0x6D2B79F5) >>> 0;
  let t = seed;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const below = n => Math.floor(random() * n);
const pick = xs => xs[below(xs.length)];
const anyNat = () => pick([() => 0, () => below(8), () => below(64), () => below(1 << 20), () => below(2 ** 47)])();

const tables = array(P['probe.tables']());
const seatsAt = table => array(D['table.seats'](table));
const allSeats = seatsAt(tables[2]);
assert.equal(allSeats[1].$, 'Seat1', 'constructor tags are bare names');
const [finished, stuck] = array(P['probe.ends']());
const slots = array(P['probe.slots']());
const shells = array(P['probe.shells']());
const damages = array(P['probe.damages']());
const labels = array(P['probe.labels']());
const items = array(D['item.order']());
const isSeat = (a, b) => D['seat.eq'](a, b);
const anyMove = () => pick(array(P['probe.moves'](pick(allSeats), pick(allSeats), pick(slots), pick(items))));
const noMoves = list([]);

const anyMenus = () => {
  const table = pick(tables);
  const quiet = random() < 0.15;
  let ring = D['ring.fill'](table, noMoves);
  const menus = seatsAt(table).map(seat => {
    const moves = quiet ? [] : Array.from({ length: pick([0, 0, 1, 2, 3, 5]) }, anyMove);
    ring = D['ring.set'](ring, seat, list(moves));
    return { seat, moves };
  });
  return { table, ring, menus };
};

let cases = 0;

for (let i = 0; i < 3000; i++, cases++) {
  const lo = below(40);
  const width = below(12);
  const range = D['range.of'](lo, width);
  if (width === 0) {
    assert.equal(range.$, 'None', 'a one-value range is never a request');
    continue;
  }
  assert.equal(range.$, 'Some');
  same(range.value, P['probe.range'](lo, width - 1), 'range.of keeps lo..lo+width');
  const request = P['probe.draw'](pick(labels), range.value);
  for (const n of [anyNat(), anyNat(), width, width + 1, 2 ** 47]) {
    same(D['resolve'](request, n), P['probe.drawn'](lo + Math.min(n, width)), `draw n=${n} clamps into ${lo}..${lo + width}`);
  }
}

for (let i = 0; i < 3000; i++, cases++) {
  const { table, ring, menus } = anyMenus();
  const request = D['request.choose'](ring);
  const flat = menus.flatMap(({ seat, moves }) => moves.map((move, index) => P['probe.chose'](seat, index, move)));
  const prompts = array(D['prompts'](request));
  if (flat.length === 0) {
    same(request, stuck, 'a request with no move is Stuck');
    assert.equal(prompts.length, 0, 'no prompt without a move');
    continue;
  }
  same(request.menus, ring, 'a request with a move offers the menus unchanged');

  for (const n of [anyNat(), anyNat(), flat.length - 1, flat.length]) {
    same(D['resolve'](request, n), flat[Math.min(n, flat.length - 1)], `menu answer n=${n} clamps to the last move`);
  }

  const active = menus.filter(({ moves }) => moves.length > 0);
  assert.deepEqual(prompts.map(p => p.seat.$), active.map(({ seat }) => seat.$), 'prompts exist exactly for seats with moves');

  for (const { seat, moves } of menus) {
    const found = D['prompt.of'](request, seat);
    if (moves.length === 0) {
      assert.equal(found.$, 'None', `no prompt for ${seat.$}, which has no move`);
      continue;
    }
    assert.equal(found.$, 'Some');
    const prompt = found.value;
    assert.ok(isSeat(prompt.seat, seat));
    same(array(D['nonempty.list'](prompt.menu)), moves, 'prompt menu is the seat menu');
    for (const k of [0, anyNat(), anyNat(), moves.length - 1, moves.length, 2 ** 47]) {
      const resolved = D['resolve'](request, D['prompt.answer'](prompt, k));
      const index = Math.min(k, moves.length - 1);
      assert.ok(isSeat(resolved.choice.seat, seat), `prompt k=${k} for ${seat.$} never selects another seat's move`);
      same(resolved, P['probe.chose'](seat, index, moves[index]), `prompt k=${k} resolves to that entry`);
    }
  }
  for (const seat of allSeats.filter(s => !seatsAt(table).some(t => isSeat(s, t)))) {
    assert.equal(D['prompt.of'](request, seat).$, 'None', `no prompt for ${seat.$}, which is not at the table`);
  }
}

for (const request of [finished, stuck, P['probe.draw'](labels[0], P['probe.range'](0, 0))]) {
  assert.equal(array(D['prompts'](request)).length, 0, `${request.$} has no prompt`);
}

const anyEvent = () => pick(array(P['probe.events'](pick(allSeats), pick(allSeats), pick(shells), pick(damages), below(7), pick(slots), pick(items))));
const anySecret = () => pick(array(P['probe.secrets'](pick(shells), 3 + below(5))));
const anyNote = () => {
  if (random() < 0.5) {
    const event = anyEvent();
    return { note: P['probe.shown'](event), event, to: null, heard: P['probe.witnessed'](event) };
  }
  const to = pick(allSeats);
  const secret = anySecret();
  return { note: P['probe.told'](to, secret), event: null, to, heard: P['probe.learned'](secret) };
};

for (let i = 0; i < 3000; i++, cases++) {
  const notes = Array.from({ length: below(9) }, anyNote);
  const me = pick(allSeats);
  const expected = notes.filter(({ to }) => to === null || isSeat(to, me)).map(({ heard }) => heard);
  same(array(D['hear'](list(notes.map(n => n.note)), me)), expected, `hear keeps public events and only ${me.$}'s secrets, in order`);
  const events = notes.filter(({ to }) => to === null).map(({ event }) => event);
  same(array(D['public_events'](list(notes.map(n => n.note)))), events, 'public_events drops every secret');
}

rmSync(dir, { recursive: true });
console.log(`domain round trip: ${cases} cases, seed ${process.env.SEED ?? 20261011}, ok`);
