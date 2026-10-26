import Base
import ../domain.bend as D
import ../sm/state.bend as S
import ../sm/items.bend as I
import ../simple/state.bend as T
import ../simple/main.bend as M
import ./types.bend as A
import ./evaluation.bend as E

# The expected-deal leaf (two seats only). A reload's draws (the item
# amount, each item taken, the batch and the shuffle) are answered with every
# value, each equally likely, by the simple machine itself, until the next
# choice. States the draws reach are merged when they differ only in where a
# seat's items sit in its slots or in the order of the shells in the gun, so
# each distinct deal is carried once with its probability. Below a deal the
# static evaluation reads neither: the gun only through whether every order of
# it agrees on the chamber, which its counts decide.
#
# The batch and the shuffle come after the items are placed and read and write
# no slot, so a deal's load is drawn once for all the ways its items came out
# rather than once for each.

# One state a deal reached, with its probability under the public and under
# the private belief. One pass carries both.
type Dealt is Data:
  Dealt{state: T.State, public: F32, private: F32}

# The players one way of dealing the items gives, with its probabilities.
type Outcome is Data:
  Outcome{players: S.Players, public: F32, private: F32}

# A state at its load, standing for every item outcome that reached it.
type AtLoad is Data:
  AtLoad{state: T.State, outcomes: List<&2, Outcome>}

# The states the next draws start from, the loads still to draw, and the
# states whose deal is over.
type Frontier is Data:
  Frontier{next: Map<&2, Dealt>, loads: Map<&2, AtLoad>, done: List<&2, Dealt>}

# Probability times static value, summed over the deals.
type Sums is Data:
  Sums{public: F32, private: F32}

# Keys
# ====

def put(+code: U32, rest: String) -> String:
  SCon{Chr{code}, rest}

def put.nat(+n: Nat, rest: String) -> String:
  put(U32.from_nat(n), rest)

def put.bool(b: Bool, rest: String) -> String:
  put(Bool.pick(U32, b, 1, 0), rest)

def put.seat(seat: D.Seat, rest: String) -> String:
  match seat:
    case D.Seat0{}:
      put(0, rest)
    case D.Seat1{}:
      put(1, rest)
    case D.Seat2{}:
      put(2, rest)
    case D.Seat3{}:
      put(3, rest)

def put.maybe_seat(seat: Maybe<&2, D.Seat>, rest: String) -> String:
  match seat:
    case None{}:
      put(9, rest)
    case Some{seat}:
      put.seat(seat, rest)

def put.item(item: Maybe<&2, D.Item>, rest: String) -> String:
  match item:
    case None{}:
      put(0, rest)
    case Some{item}:
      put.nat(D.item.godot_id(item), rest)

def put.load(load: D.Load, rest: String) -> String:
  match load:
    case D.Load{live, blank}:
      put.nat(live, put.nat(blank, rest))

def shells.live(shells: List<&2, D.Shell>) -> Nat:
  match shells:
    case Nil{}:
      0n
    case D.Live{} <> rest:
      1n+shells.live(rest)
    case D.Blank{} <> rest:
      shells.live(rest)

# The gun by its counts, not its order.
def put.shells(+shells: List<&2, D.Shell>, rest: String) -> String:
  +live : Nat = shells.live(shells)
  put.nat(live, put.nat(Nat.sub(List.length(&2, D.Shell, shells), live), rest))

def put.items(items: List<&2, D.Item>, rest: String) -> String:
  match items:
    case Nil{}:
      rest
    case item <> more:
      put.item(Some{item}, put.items(more, rest))

def put.batches(batches: List<&2, S.Batch>, rest: String) -> String:
  match batches:
    case Nil{}:
      rest
    case S.Batch{id, _} <> more:
      put.nat(id, put.batches(more, rest))

def put.jam(jam: S.Jam, rest: String) -> String:
  match jam:
    case S.Free{}:
      put(0, rest)
    case S.Jammed{}:
      put(1, rest)
    case S.JammedSkipped{}:
      put(2, rest)

# A seat's items by how many of each it holds, not by slot.
def put.counts(order: List<&2, D.Item>, +held: List<&2, Maybe<&2, D.Item>>, rest: String) -> String:
  match order:
    case Nil{}:
      rest
    case item <> more:
      put.nat(I.copies(held, item), put.counts(more, held, rest))

def put.slots(slots: D.Slots, with: Bool, rest: String) -> String:
  match with:
    case True{}:
      put.counts(D.item.order(), I.slots.items(slots), rest)
    case False{}:
      rest

def put.seats(entries: List<&2, D.At<&2, S.Seat>>, +slots: Bool, rest: String) -> String:
  match entries:
    case Nil{}:
      rest
    case D.At{_, S.Seat{health, jam, _, held}} <> more:
      put.nat(health, put.jam(jam, put.slots(held, slots, put.seats(more, slots, rest))))

def put.bools(entries: List<&2, D.At<&2, Bool>>, rest: String) -> String:
  match entries:
    case Nil{}:
      rest
    case D.At{_, b} <> more:
      put.bool(b, put.bools(more, rest))

def put.held(entries: List<&2, D.At<&2, Maybe<&2, D.Item>>>, rest: String) -> String:
  match entries:
    case Nil{}:
      rest
    case D.At{_, item} <> more:
      put.item(item, put.held(more, rest))

def put.nats(entries: List<&2, D.At<&2, Nat>>, rest: String) -> String:
  match entries:
    case Nil{}:
      rest
    case D.At{_, n} <> more:
      put.nat(n, put.nats(more, rest))

def put.grabs(grabs: S.Grabs, rest: String) -> String:
  match grabs:
    case S.Grabs{distributing, grabbing, holding, granted, intake}:
      put.bool(distributing, put.bools(D.ring.entries(Bool, grabbing), put.held(D.ring.entries(Maybe<&2, D.Item>, holding), put.nats(D.ring.entries(Nat, granted), put.bools(D.ring.entries(Bool, intake), rest)))))

def put.phase(phase: T.Phase, rest: String) -> String:
  match phase:
    case T.NeedBatch{}:
      put(1, rest)
    case T.NeedSwap{load, shells, i}:
      put(2, put.load(load, put.shells(shells, put.nat(i, rest))))
    case T.Idle{seat}:
      put(3, put.seat(seat, rest))
    case T.NeedTurnAmount{from, passing, winner}:
      put(4, put.seat(from, put.bool(passing, put.maybe_seat(winner, rest))))
    case T.NeedItem{seat, first, second, more}:
      put(5, put.seat(seat, put.items(first <> second <> more, rest)))
    case _:
      put(6, rest)

# Everything a deal's draws write, with the slots and the gun as counts, or
# without the slots.
def key(+state: T.State, slots: Bool) -> String:
  +world : S.World = T.state.world(state)
  +rest : String = put.seats(D.ring.entries(S.Seat, T.state.players(state)), slots, put.grabs(T.state.grabs(state), SNil{}))
  +rest : String = put.nat(S.world.item_amount(world), put.maybe_seat(S.world.turn(world), put.seat(S.world.first_turn(world), rest)))
  +rest : String = put.shells(S.world.gun(world), put.load(S.world.shown(world), put.batches(S.world.deck(world), rest)))
  put.phase(T.state.phase(state), put.nat(S.world.load_index(world), put.bool(S.world.first_sequence(world), rest)))

# Expansion
# =========

def dealt.merged(found: Maybe<&2, Dealt>, +state: T.State, +public: F32, +private: F32) -> Dealt:
  match found:
    case None{}:
      Dealt{state, public, private}
    case Some{Dealt{_, p, q}}:
      Dealt{state, F32.add(p, public), F32.add(q, private)}

def insert.popped(popped: Map<&2, Dealt> & Maybe<&2, Dealt>, +key: String, +state: T.State, +public: F32, +private: F32) -> Map<&2, Dealt>:
  (rest, found) = popped
  Map.set(&2, Dealt, rest, key, dealt.merged(found, state, public, private))

def insert(next: Map<&2, Dealt>, +state: T.State, +public: F32, +private: F32) -> Map<&2, Dealt>:
  +key : String = key(state, True{})
  insert.popped(Map.pop(&2, Dealt, next, key), key, state, public, private)

def loading.merged(found: Maybe<&2, AtLoad>, +state: T.State, +outcome: Outcome) -> AtLoad:
  match found:
    case None{}:
      AtLoad{state, [outcome]}
    case Some{AtLoad{_, outcomes}}:
      AtLoad{state, outcome <> outcomes}

def insert.load.popped(popped: Map<&2, AtLoad> & Maybe<&2, AtLoad>, +key: String, +state: T.State, +outcome: Outcome) -> Map<&2, AtLoad>:
  (rest, found) = popped
  Map.set(&2, AtLoad, rest, key, loading.merged(found, state, outcome))

def insert.load(loads: Map<&2, AtLoad>, +state: T.State, +public: F32, +private: F32) -> Map<&2, AtLoad>:
  +key : String = key(state, False{})
  insert.load.popped(Map.pop(&2, AtLoad, loads, key), key, state, Outcome{T.state.players(state), public, private})

def insert.worlds(worlds: List<&2, A.World>, +private: Bool, next: Map<&2, Dealt>) -> Map<&2, Dealt>:
  match worlds:
    case Nil{}:
      next
    case A.World{state, +weight} <> rest:
      insert.worlds(rest, private, insert(next, state, Bool.pick(F32, private, 0.0, weight), Bool.pick(F32, private, weight, 0.0)))

def answered(stepped: D.Stepped<&2, T.State>) -> T.State:
  match stepped:
    case D.Stepped{state, _}:
      state

# Every answer to a draw, each equally likely: answer k is the k-th value.
def draws(count: Nat, +state: T.State, +public: F32, +private: F32, next: Map<&2, Dealt>) -> Map<&2, Dealt>:
  match count:
    case 0n:
      next
    case 1n+(+k):
      draws(k, state, public, private, insert(next, answered(M.answer(state, k)), public, private))

def frontier.draw(frontier: Frontier, +count: Nat, +public: F32, +private: F32, +state: T.State) -> Frontier:
  match frontier:
    case Frontier{next, loads, done}:
      +n : F32 = F32.from_nat(count)
      Frontier{draws(count, state, F32.div(public, n), F32.div(private, n), next), loads, done}

def frontier.load(frontier: Frontier, +public: F32, +private: F32, +state: T.State) -> Frontier:
  match frontier:
    case Frontier{next, loads, done}:
      Frontier{next, insert.load(loads, state, public, private), done}

def frontier.done(frontier: Frontier, +public: F32, +private: F32, +state: T.State) -> Frontier:
  match frontier:
    case Frontier{next, loads, done}:
      Frontier{next, loads, Dealt{state, public, private} <> done}

# A state at a draw is expanded into the next frontier, or with `split` set
# and the items placed, set aside to draw its load once for every outcome.
# Any other state ends its deal.
def frontier.one(request: T.Request, stage: D.Stage, +split: Bool, +state: T.State, +public: F32, +private: F32, frontier: Frontier) -> Frontier:
  match request stage split:
    case T.Draw{_, _} D.Loading{} True{}:
      frontier.load(frontier, public, private, state)
    case T.Draw{_, D.Range{_, extra}} _ _:
      frontier.draw(frontier, 2n+extra, public, private, state)
    case _ _ _:
      frontier.done(frontier, public, private, state)

def expand(pending: List<&2, Dealt>, +split: Bool, frontier: Frontier) -> Frontier:
  match pending:
    case Nil{}:
      frontier
    case Dealt{+state, +public, +private} <> rest:
      expand(rest, split, frontier.one(M.request(state), M.stage(state), split, state, public, private, frontier))

# A two-seat deal draws at most once for the amount, eight times for items,
# once for the batch and nine times for the shuffle, so the fuel is never
# spent. If it were, the states left would be valued as they stand.
def deal.fuel() -> Nat:
  64n

def deal(fuel: Nat, frontier: Frontier, +split: Bool) -> Frontier:
  match fuel frontier:
    case _ Frontier{MTip{}, loads, done}:
      Frontier{MTip{}, loads, done}
    case 0n Frontier{next, loads, done}:
      Frontier{Map.new(&2, Dealt), loads, List.append(&2, Dealt, Map.values(&2, Dealt, next), done)}
    case 1n+(+fuel) Frontier{next, loads, done}:
      deal(fuel, expand(Map.values(&2, Dealt, next), split, Frontier{Map.new(&2, Dealt), loads, done}), split)

def frontier.finished(frontier: Frontier) -> List<&2, Dealt>:
  match frontier:
    case Frontier{_, _, done}:
      done

# Values
# ======

# Every order of the gun agrees on the chamber exactly when its shells are
# all alike (E.known over the orders of one load).
def chamber.known(shells: List<&2, D.Shell>) -> Bool:
  match shells:
    case Nil{}:
      False{}
    case +shells:
      +live : Nat = shells.live(shells)
      Bool.or(Nat.is_eq(live, 0n), Nat.is_eq(live, List.length(&2, D.Shell, shells)))

# The static value of a state a deal ended at.
def deal.value(+state: T.State, +me: D.Seat) -> F32:
  U32.to_f32(E.state(state, me, chamber.known(S.world.gun(T.state.world(state)))))

def sums.scaled(sums: Sums, +public: F32, +private: F32, +value: F32) -> Sums:
  match sums:
    case Sums{p, q}:
      Sums{F32.add(p, F32.mul(public, value)), F32.add(q, F32.mul(private, value))}

def sums.add(sums: Sums, +public: F32, +private: F32, +state: T.State, +me: D.Seat) -> Sums:
  sums.scaled(sums, public, private, deal.value(state, me))

def done.value(done: List<&2, Dealt>, +me: D.Seat, sums: Sums) -> Sums:
  match done:
    case Nil{}:
      sums
    case Dealt{state, public, private} <> rest:
      done.value(rest, me, sums.add(sums, public, private, state, me))

def slots.from(seats: List<&2, D.Seat>, +from: S.Players, players: S.Players) -> S.Players:
  match seats:
    case Nil{}:
      players
    case +seat <> rest:
      slots.from(rest, from, S.players.set_slots(players, seat, I.seat.slots(from, seat)))

# A state after the load with one item outcome's slots.
def with.slots(+state: T.State, +from: S.Players) -> T.State:
  T.state.set_players(state, slots.from(D.table.seats(S.world.table(T.state.world(state))), from, T.state.players(state)))

def outcomes.value(outcomes: List<&2, Outcome>, +state: T.State, +p: F32, +me: D.Seat, sums: Sums) -> Sums:
  match outcomes:
    case Nil{}:
      sums
    case Outcome{players, public, private} <> rest:
      outcomes.value(rest, state, p, me, sums.add(sums, F32.mul(p, public), F32.mul(p, private), with.slots(state, players), me))

# Each end of the load, which the load drew with probability `public`, under
# every item outcome.
def finals.value(finals: List<&2, Dealt>, +outcomes: List<&2, Outcome>, +me: D.Seat, sums: Sums) -> Sums:
  match finals:
    case Nil{}:
      sums
    case Dealt{state, p, _} <> rest:
      finals.value(rest, outcomes, me, outcomes.value(outcomes, state, p, me, sums))

def loads.value(loads: List<&2, AtLoad>, +me: D.Seat, sums: Sums) -> Sums:
  match loads:
    case Nil{}:
      sums
    case AtLoad{state, outcomes} <> rest:
      +finals : List<&2, Dealt> = frontier.finished(deal(deal.fuel(), Frontier{insert(Map.new(&2, Dealt), state, 1.0, 1.0), Map.new(&2, AtLoad), Nil{}}, False{}))
      loads.value(rest, me, finals.value(finals, outcomes, me, sums))

def dealt.value(frontier: Frontier, +me: D.Seat) -> Sums:
  match frontier:
    case Frontier{_, loads, done}:
      loads.value(Map.values(&2, AtLoad, loads), me, done.value(done, me, Sums{0.0, 0.0}))

# The start of each deal: the belief's worlds, merged by key.
def starts(+public: List<&2, A.World>, +private: List<&2, A.World>) -> Map<&2, Dealt>:
  insert.worlds(private, True{}, insert.worlds(public, False{}, Map.new(&2, Dealt)))

# Probability times static value over every distinct deal after a reload,
# under the public and the private belief.
def expected(+public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat) -> Sums:
  dealt.value(deal(deal.fuel(), Frontier{starts(public, private), Map.new(&2, AtLoad), Nil{}}, True{}), me)

# Sampled deals
# =============
#
# The sampled leaf averages the same static value over `count` deals drawn at
# random from each start, rather than over every deal. Each start's deals are
# seeded by its key, so a leaf draws the same deals whenever it is valued.

def mix(+x: U32) -> U32:
  +x1 : U32 = U32.xor(x, U32.shrn(x, 16n))
  +x2 : U32 = U32.mul(x1, 2146121005)
  +x3 : U32 = U32.xor(x2, U32.shrn(x2, 15n))
  +x4 : U32 = U32.mul(x3, 2221713035)
  U32.xor(x4, U32.shrn(x4, 16n))

def key.seed(key: String, +seed: U32) -> U32:
  match key:
    case SNil{}:
      seed
    case SCon{Chr{code}, rest}:
      key.seed(rest, mix(U32.xor(seed, code)))

# Word `n` of the deal's stream answers its n-th draw, each value equally likely.
def sample.deal(fuel: Nat, request: T.Request, +state: T.State, +seed: U32, +n: U32) -> T.State:
  match fuel request:
    case 1n+(+fuel) T.Draw{_, D.Range{_, extra}}:
      +k : U32 = U32.mod(mix(U32.xor(seed, mix(n))), U32.from_nat(2n+extra))
      +next : T.State = answered(M.answer(state, U32.to_nat(k)))
      sample.deal(fuel, M.request(next), next, seed, (n + 1 : U32))
    case _ _:
      state

# The static values of `count` deals drawn from one start, summed.
def sample.sum(count: Nat, +state: T.State, +seed: U32, +me: D.Seat, +sum: F32) -> F32:
  match count:
    case 0n:
      sum
    case 1n+(+k):
      sample.sum(k, state, seed, me, F32.add(sum, deal.value(sample.deal(deal.fuel(), M.request(state), state, mix(U32.xor(seed, U32.from_nat(k))), 0), me)))

# 2166136261 is the FNV offset basis, an arbitrary nonzero start.
def sampled.starts(starts: List<&2, Dealt>, +count: Nat, +me: D.Seat, sums: Sums) -> Sums:
  match starts:
    case Nil{}:
      sums
    case Dealt{+state, public, private} <> rest:
      +sum : F32 = sample.sum(count, state, key.seed(key(state, True{}), 2166136261), me, 0.0)
      sampled.starts(rest, count, me, sums.scaled(sums, public, private, F32.div(sum, F32.from_nat(count))))

# Probability times the mean static value of `count` sampled deals from each
# start, under the public and the private belief. `count` is at least one.
def sampled(+public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat, +count: Nat) -> Sums:
  sampled.starts(Map.values(&2, Dealt, starts(public, private)), count, me, Sums{0.0, 0.0})
