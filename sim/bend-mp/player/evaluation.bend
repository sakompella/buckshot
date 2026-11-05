import Base
import ../domain.bend as D
import ../sm/state.bend as S
import ../sm/rules.bend as G
import ../simple/state.bend as T
import ./types.bend as A
import ./belief.bend as B

def item.weight(item: D.Item) -> U32:
  match item:
    case D.Saw{}:
      65
    case D.Glass{}:
      60
    case D.Jammer{}:
      90
    case D.Cigarettes{}:
      75
    case D.Beer{}:
      25
    case D.Phone{}:
      30
    case D.Inverter{}:
      45
    case D.Adrenaline{}:
      80
    case D.Remote{}:
      15

def slot.weight(item: Maybe<&2, D.Item>) -> U32:
  match item:
    case None{}:
      0
    case Some{item}:
      item.weight(item)

def slots.weight(slots: D.Slots) -> U32:
  match slots:
    case D.Slots{a, b, c, d, e, f, g, h, _}:
      (slot.weight(a) + slot.weight(b) + slot.weight(c) + slot.weight(d) + slot.weight(e) + slot.weight(f) + slot.weight(g) + slot.weight(h) : U32)

# A seat's weight, and whether it is alive.
type Weighed is Data:
  Weighed{weight: U32, alive: Bool}

def seat.weight(player: S.Seat, tempo: Bool) -> Weighed:
  match player:
    case S.Seat{0n, _, _, _}:
      Weighed{0, False{}}
    case S.Seat{hp, jam, _, slots}:
      +base : U32 = (100 * U32.from_nat(hp) + slots.weight(slots) + Bool.pick(U32, tempo, 35, 0) : U32)
      Weighed{U32.sub(base, Bool.pick(U32, S.jam.jammed(jam), U32.min(base, 50), 0)), True{}}

def turn.is(turn: Maybe<&2, D.Seat>, seat: D.Seat) -> Bool:
  match turn:
    case None{}:
      False{}
    case Some{current}:
      D.seat.eq(current, seat)

# Every seat's weight summed, with me's weight and life when me is seated.
type Weights is Data:
  Weights{total: U32, own: Maybe<&2, Weighed>}

def weights.add(mine: Bool, weighed: Weighed, weights: Weights) -> Weights:
  match mine weighed weights:
    case True{} Weighed{+weight, alive} Weights{total, _}:
      Weights{(weight + total : U32), Some{Weighed{weight, alive}}}
    case False{} Weighed{weight, _} Weights{total, own}:
      Weights{(weight + total : U32), own}

def weights(entries: List<&2, D.At<&2, S.Seat>>, +turn: Maybe<&2, D.Seat>, +me: D.Seat) -> Weights:
  match entries:
    case Nil{}:
      Weights{0, None{}}
    case D.At{+seat, player} <> rest:
      weights.add(D.seat.eq(seat, me), seat.weight(player, turn.is(turn, seat)), weights(rest, turn, me))

# An unseated me weighs as S.players.seat's stand-in seat.
def weights.own(own: Maybe<&2, Weighed>, +turn: Maybe<&2, D.Seat>, +me: D.Seat) -> Weighed:
  match own:
    case Some{weighed}:
      weighed
    case None{}:
      seat.weight(S.Seat{100n, S.Free{}, 0, D.slots.empty()}, turn.is(turn, me))

def estimate.of(own: Weighed, total: U32, knowledge: Bool) -> U32:
  match own:
    case Weighed{weight, alive}:
      +bonus : U32 = Bool.pick(U32, Bool.and(knowledge, alive), 25, 0)
      F32.to_u32(F32.mul(1000000.0, F32.div(U32.to_f32((weight + bonus : U32)), U32.to_f32(U32.max(1, (total + bonus : U32))))))

def estimate(weights: Weights, +turn: Maybe<&2, D.Seat>, +me: D.Seat, knowledge: Bool) -> U32:
  match weights:
    case Weights{total, own}:
      estimate.of(weights.own(own, turn, me), total, knowledge)

def exact.note(note: D.Note, +me: D.Seat) -> Maybe<&2, U32>:
  match note:
    case D.Shown{D.RoundWon{seat, _}}:
      Some{Bool.pick(U32, D.seat.eq(me, seat), 1000000, 0)}
    case _:
      None{}

def exact.after(found: Maybe<&2, U32>, note: D.Note, +me: D.Seat) -> Maybe<&2, U32>:
  match found:
    case Some{value}:
      Some{value}
    case None{}:
      exact.note(note, me)

# The value of the first RoundWon in the log, read in place.
def exact(log: T.Log, +me: D.Seat) -> Maybe<&2, U32>:
  match log:
    case T.Empty{}:
      None{}
    case T.Snoc{earlier, note}:
      exact.after(exact(earlier, me), note, me)

def state.exact(found: Maybe<&2, U32>, players: S.Players, +turn: Maybe<&2, D.Seat>, +me: D.Seat, knowledge: Bool) -> U32:
  match found:
    case Some{value}:
      value
    case None{}:
      estimate(weights(D.ring.entries(S.Seat, players), turn, me), turn, me, knowledge)

def state(state: T.State, +me: D.Seat, knowledge: Bool) -> U32:
  match state:
    case T.State{world, players, _, log, _}:
      state.exact(exact(log, me), players, S.world.turn(world), me, knowledge)

# A state's value with and without knowledge of the chamber, and its chamber.
type Valued is Data:
  Valued{known: U32, unknown: U32, chamber: Maybe<&2, D.Shell>}

def valued.exact(found: Maybe<&2, U32>, players: S.Players, +turn: Maybe<&2, D.Seat>, +me: D.Seat, chamber: Maybe<&2, D.Shell>) -> Valued:
  match found:
    case Some{+value}:
      Valued{value, value, chamber}
    case None{}:
      +weights : Weights = weights(D.ring.entries(S.Seat, players), turn, me)
      Valued{estimate(weights, turn, me, True{}), estimate(weights, turn, me, False{}), chamber}

def chamber(gun: List<&2, D.Shell>) -> Maybe<&2, D.Shell>:
  match gun:
    case Nil{}:
      None{}
    case shell <> _:
      Some{shell}

def valued(state: T.State, +me: D.Seat) -> Valued:
  match state:
    case T.State{S.World{_, _, _, _, _, _, _, +turn, _, _, _, _, _, gun, _, _}, players, _, log, _}:
      valued.exact(exact(log, me), players, turn, me, chamber(gun))

# Over the worlds after the first: the weighted sums with and without chamber
# knowledge, folded right to left as sum would, and whether every chamber
# matches the first world's.
type Sums is Data:
  Sums{known: F32, unknown: F32, same: Bool}

def chamber.same(a: Maybe<&2, D.Shell>, b: Maybe<&2, D.Shell>) -> Bool:
  match a b:
    case Some{x} Some{y}:
      B.shell.eq(x, y)
    case _ _:
      False{}

def sums.add(+weight: F32, valued: Valued, +first: Maybe<&2, D.Shell>, sums: Sums) -> Sums:
  match valued sums:
    case Valued{k, u, chamber} Sums{sk, su, same}:
      Sums{F32.add(F32.mul(weight, U32.to_f32(k)), sk), F32.add(F32.mul(weight, U32.to_f32(u)), su), Bool.and(chamber.same(chamber, first), same)}

def sums(worlds: List<&2, A.World>, +me: D.Seat, +first: Maybe<&2, D.Shell>) -> Sums:
  match worlds:
    case Nil{}:
      Sums{0.0, 0.0, True{}}
    case A.World{position, +weight} <> rest:
      sums.add(weight, valued(position, me), first, sums(rest, me, first))

def static.first(+weight: F32, valued: Valued, sums: Sums) -> F32:
  match valued sums:
    case Valued{k, _, Some{_}} Sums{sk, _, True{}}:
      F32.add(F32.mul(weight, U32.to_f32(k)), sk)
    case Valued{_, u, _} Sums{_, su, _}:
      F32.add(F32.mul(weight, U32.to_f32(u)), su)

def static.from(+weight: F32, valued: Valued, rest: List<&2, A.World>, +me: D.Seat) -> F32:
  match valued:
    case Valued{k, u, +first}:
      static.first(weight, Valued{k, u, first}, sums(rest, me, first))

# The weighted value of the worlds, knowing the chamber when every world's
# chamber holds the same shell (E.known), summed right to left as sum does.
def static(worlds: List<&2, A.World>, +me: D.Seat) -> F32:
  match worlds:
    case Nil{}:
      0.0
    case A.World{position, +weight} <> rest:
      static.from(weight, valued(position, me), rest, me)
