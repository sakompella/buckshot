import Base
import ../domain.bend as D
import ../sm/state.bend as S
import ../simple/state.bend as T
import ./types.bend as A
import ./deal.bend as L
import ../sm/items.bend as I

# The search's memo (README.md, Memo). Within one analysis the config, the
# searcher, the budget and the reload rule are fixed, so a decision node is
# told apart by its beliefs alone, and the entry records the depth it was
# searched to. A key spells every field of every world's state except its
# config and the notes of the answer that reached it, and every weight by its
# bits, so two beliefs share a key exactly when they hold the same states with
# the same weights in the same order. Lists carry their lengths, so no key is
# a prefix of another's encoding.

# Keys
# ====

# A whole word as two characters, each a valid code point above the BMP.
def put.u32(+x: U32, rest: String) -> String:
  L.put((65536 + U32.shrn(x, 16n) : U32), L.put((65536 + U32.and(x, 65535) : U32), rest))

def put.f32(+x: F32, rest: String) -> String:
  put.u32(F32.bits(x), rest)

def put.shell(shell: D.Shell, rest: String) -> String:
  match shell:
    case D.Live{}:
      L.put(1, rest)
    case D.Blank{}:
      L.put(2, rest)

def put.order(shells: List<&2, D.Shell>, rest: String) -> String:
  match shells:
    case Nil{}:
      rest
    case shell <> more:
      put.shell(shell, put.order(more, rest))

# The gun in order, after its length.
def put.gun(+shells: List<&2, D.Shell>, rest: String) -> String:
  L.put.nat(List.length(&2, D.Shell, shells), put.order(shells, rest))

def put.batch_list(batches: List<&2, S.Batch>, rest: String) -> String:
  match batches:
    case Nil{}:
      rest
    case S.Batch{id, load} <> more:
      L.put.nat(id, L.put.load(load, put.batch_list(more, rest)))

def put.batches(+batches: List<&2, S.Batch>, rest: String) -> String:
  L.put.nat(List.length(&2, S.Batch, batches), put.batch_list(batches, rest))

def put.decks(decks: S.Decks, rest: String) -> String:
  match decks:
    case S.Decks{two, three, four}:
      put.batches(two, put.batches(three, put.batches(four, rest)))

def put.direction(direction: D.Direction, rest: String) -> String:
  match direction:
    case D.Clockwise{}:
      L.put(0, rest)
    case D.CounterClockwise{}:
      L.put(1, rest)

def put.world(world: S.World, rest: String) -> String:
  match world:
    case S.World{_, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}:
      +rest : String = put.gun(gun, L.put.load(shown, put.decks(decks, rest)))
      +rest : String = L.put.maybe_seat(first_death, L.put.bool(checking_first_death, L.put.nat(item_amount, L.put.bool(sawed, rest))))
      +rest : String = L.put.nat(round_health, L.put.seat(first_turn, L.put.maybe_seat(turn, put.direction(direction, rest))))
      L.put.bool(before_round, L.put.nat(round_index, L.put.nat(load_index, L.put.bool(first_sequence, rest))))

def put.slots(slots: D.Slots, rest: String) -> String:
  match slots:
    case D.Slots{a, b, c, d, e, f, g, h, _}:
      L.put.item(a, L.put.item(b, L.put.item(c, L.put.item(d, L.put.item(e, L.put.item(f, L.put.item(g, L.put.item(h, rest))))))))

def put.players(entries: List<&2, D.At<&2, S.Seat>>, rest: String) -> String:
  match entries:
    case Nil{}:
      rest
    case D.At{_, S.Seat{health, jam, cash, slots}} <> more:
      L.put.nat(health, L.put.jam(jam, put.u32(cash, put.slots(slots, put.players(more, rest)))))

def put.slot(slot: D.Slot, rest: String) -> String:
  match slot:
    case D.Slot0{}:
      L.put(0, rest)
    case D.Slot1{}:
      L.put(1, rest)
    case D.Slot2{}:
      L.put(2, rest)
    case D.Slot3{}:
      L.put(3, rest)
    case D.Slot4{}:
      L.put(4, rest)
    case D.Slot5{}:
      L.put(5, rest)
    case D.Slot6{}:
      L.put(6, rest)
    case D.Slot7{}:
      L.put(7, rest)

def put.items(+items: List<&2, D.Item>, rest: String) -> String:
  L.put.nat(List.length(&2, D.Item, items), L.put.items(items, rest))

def put.phase(phase: T.Phase, rest: String) -> String:
  match phase:
    case T.NeedFirst{}:
      L.put(0, rest)
    case T.NeedHealth{}:
      L.put(1, rest)
    case T.NeedAmount{}:
      L.put(2, rest)
    case T.NeedBatch{}:
      L.put(3, rest)
    case T.NeedSwap{load, shells, i}:
      L.put(4, L.put.load(load, put.gun(shells, L.put.nat(i, rest))))
    case T.Idle{seat}:
      L.put(5, L.put.seat(seat, rest))
    case T.Ended{}:
      L.put(6, rest)
    case T.Blocked{holder}:
      L.put(7, L.put.maybe_seat(holder, rest))
    case T.Stalled{}:
      L.put(8, rest)
    case T.NeedTurnAmount{from, passing, winner}:
      L.put(9, L.put.seat(from, L.put.bool(passing, L.put.maybe_seat(winner, rest))))
    case T.NeedItem{seat, first, second, more}:
      L.put(10, L.put.seat(seat, L.put.item(Some{first}, L.put.item(Some{second}, put.items(more, rest)))))
    case T.NeedPhone{seat, owner, slot}:
      L.put(11, L.put.seat(seat, L.put.seat(owner, put.slot(slot, rest))))

def put.state(+state: T.State, rest: String) -> String:
  tail : String = put.players(D.ring.entries(S.Seat, T.state.players(state)), put.phase(T.state.phase(state), L.put.grabs(T.state.grabs(state), rest)))
  put.world(T.state.world(state), tail)

def put.world_list(worlds: List<&2, A.World>, rest: String) -> String:
  match worlds:
    case Nil{}:
      rest
    case A.World{state, weight} <> more:
      put.f32(weight, put.state(state, put.world_list(more, rest)))

def put.belief(+worlds: List<&2, A.World>, rest: String) -> String:
  L.put.nat(List.length(&2, A.World, worlds), put.world_list(worlds, rest))

def key(+public: List<&2, A.World>, +private: List<&2, A.World>) -> String:
  put.belief(public, put.belief(private, SNil{}))

def key.state(+state: T.State) -> String:
  put.state(state, SNil{})

# Entries
# =======

# A decision node's value, the depth it was searched to, and the nodes that
# search spent.
type Entry is Data:
  Entry{public: U32, private: U32, pv: List<&2, T.Move>, reach: A.Reach, depth: Nat, cost: Nat}

type Stored is Data:
  Decision{entry: Entry}
  Deal{sums: L.Sums}

type Kept is Data:
  Kept{key: String, stored: Stored}

# The memo files each key under a short hash of it, beside the other keys of
# that hash; comparing whole keys there keeps a collision from mixing values.
# What the search has spent and found so far: its nodes, the memo, the
# decision nodes and deal leaves the memo holds, and how often each was reused.
type Tally is Data:
  Tally{nodes: Nat, memo: Map<&2, List<&2, Kept>>, entries: Nat, hits: Nat, deals: Nat, deal_hits: Nat}

def tally.new() -> Tally:
  Tally{0n, Map.new(&2, List<&2, Kept>), 0n, 0n, 0n, 0n}

def tally.nodes(tally: Tally) -> Nat:
  match tally:
    case Tally{nodes, _, _, _, _, _}:
      nodes

def tally.spend(tally: Tally, +nodes: Nat) -> Tally:
  match tally:
    case Tally{_, memo, entries, hits, deals, deal_hits}:
      Tally{nodes, memo, entries, hits, deals, deal_hits}

def tally.cached(tally: Tally) -> A.Cached:
  match tally:
    case Tally{_, _, entries, hits, deals, deal_hits}:
      A.Cached{entries, hits, deals, deal_hits}

def tally.hit(tally: Tally, +cost: Nat) -> Tally:
  match tally:
    case Tally{nodes, memo, entries, hits, deals, deal_hits}:
      Tally{Nat.add(nodes, cost), memo, entries, 1n+hits, deals, deal_hits}

def tally.deal_hit(tally: Tally) -> Tally:
  match tally:
    case Tally{nodes, memo, entries, hits, deals, deal_hits}:
      Tally{nodes, memo, entries, hits, deals, 1n+deal_hits}

def reach.join(a: A.Reach, b: A.Reach) -> A.Reach:
  match a b:
    case A.Cut{} _:
      A.Cut{}
    case _ A.Cut{}:
      A.Cut{}
    case A.Reloads{} _:
      A.Reloads{}
    case _ A.Reloads{}:
      A.Reloads{}
    case _ _:
      A.Settled{}

# A value no leaf of which ran out of depth is the same at any greater depth:
# its tree, its leaves and its nodes do not change.
def entry.serves(reach: A.Reach, +searched: Nat, +depth: Nat) -> Bool:
  match reach:
    case A.Cut{}:
      Nat.is_eq(searched, depth)
    case _:
      Nat.is_le(searched, depth)

def entry.cost(memo: A.Memo, +cost: Nat) -> Nat:
  match memo:
    case A.Free{}:
      0n
    case _:
      cost

# Whole keys compared in a loop: a recursive comparison of keys this long
# overflows the JavaScript stack.
def text.eq(a: String, b: String, same: Bool) -> Bool:
  match a b:
    case SNil{} SNil{}:
      same
    case SCon{Chr{x}, xs} SCon{Chr{y}, ys}:
      text.eq(xs, ys, Bool.and(same, U32.is_eq(x, y)))
    case _ _:
      False{}

def bucket.find(bucket: List<&2, Kept>, +key: String) -> Maybe<&2, Stored>:
  match bucket:
    case Nil{}:
      None{}
    case Kept{+other, +stored} <> rest:
      Bool.pick(Maybe<&2, Stored>, text.eq(other, key, True{}), Some{stored}, bucket.find(rest, key))

def bucket.without(bucket: List<&2, Kept>, +key: String) -> List<&2, Kept>:
  match bucket:
    case Nil{}:
      Nil{}
    case Kept{+other, +stored} <> rest:
      I.keep(Kept, Bool.not(text.eq(other, key, True{})), Kept{other, stored}, bucket.without(rest, key))

# 2166136261 is the FNV offset basis, an arbitrary nonzero start.
def hash(+key: String) -> String:
  put.u32(L.key.seed(key, 2166136261), SNil{})

def found.of(got: Map<&2, List<&2, Kept>> & List<&2, Kept>, +key: String, +nodes: Nat, +entries: Nat, +hits: Nat, +deals: Nat, +deal_hits: Nat) -> Tally & Maybe<&2, Stored>:
  (memo, bucket) = got
  (Tally{nodes, memo, entries, hits, deals, deal_hits}, bucket.find(bucket, key))

def find(tally: Tally, +key: String) -> Tally & Maybe<&2, Stored>:
  match tally:
    case Tally{nodes, memo, entries, hits, deals, deal_hits}:
      found.of(Map.get(List<&2, Kept>, Nil{}, memo, hash(key)), key, nodes, entries, hits, deals, deal_hits)

def stored.count(stored: Stored, +entries: Nat, +deals: Nat) -> Nat & Nat:
  match stored:
    case Decision{_}:
      (1n+entries, deals)
    case Deal{_}:
      (entries, 1n+deals)

def kept.counted(counts: Nat & Nat, +nodes: Nat, memo: Map<&2, List<&2, Kept>>, +hits: Nat, +deal_hits: Nat) -> Tally:
  (entries, deals) = counts
  Tally{nodes, memo, entries, hits, deals, deal_hits}

def kept.with(got: Map<&2, List<&2, Kept>> & List<&2, Kept>, +hashed: String, +key: String, +stored: Stored, +nodes: Nat, +entries: Nat, +hits: Nat, +deals: Nat, +deal_hits: Nat) -> Tally:
  (memo, +bucket) = got
  +rest : List<&2, Kept> = bucket.without(bucket, key)
  counts : Nat & Nat = Bool.pick(Nat & Nat, Nat.is_eq(List.length(&2, Kept, rest), List.length(&2, Kept, bucket)), stored.count(stored, entries, deals), (entries, deals))
  kept.counted(counts, nodes, Map.set(&2, List<&2, Kept>, memo, hashed, Kept{key, stored} <> rest), hits, deal_hits)

# Stores `stored` under `key`, in place of what the key held before.
def keep(tally: Tally, +key: String, +stored: Stored) -> Tally:
  match tally:
    case Tally{nodes, memo, entries, hits, deals, deal_hits}:
      +hashed : String = hash(key)
      kept.with(Map.get(List<&2, Kept>, Nil{}, memo, hashed), hashed, key, stored, nodes, entries, hits, deals, deal_hits)
