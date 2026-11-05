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

def seat.weight(+player: S.Seat, tempo: Bool) -> U32:
  match player:
    case S.Seat{0n, _, _, _}:
      0
    case S.Seat{hp, jam, _, slots}:
      +base : U32 = (100 * U32.from_nat(hp) + slots.weight(slots) + Bool.pick(U32, tempo, 35, 0) : U32)
      U32.sub(base, Bool.pick(U32, S.jam.jammed(jam), U32.min(base, 50), 0))

def turn.is(turn: Maybe<&2, D.Seat>, seat: D.Seat) -> Bool:
  match turn:
    case None{}:
      False{}
    case Some{current}:
      D.seat.eq(current, seat)

def total(entries: List<&2, D.At<&2, S.Seat>>, +turn: Maybe<&2, D.Seat>) -> U32:
  match entries:
    case Nil{}:
      0
    case D.At{+seat, player} <> rest:
      (seat.weight(player, turn.is(turn, seat)) + total(rest, turn) : U32)

def exact(notes: List<&2, D.Note>, +me: D.Seat) -> Maybe<&2, U32>:
  match notes:
    case Nil{}:
      None{}
    case D.Shown{D.RoundWon{seat, _}} <> _:
      Some{Bool.pick(U32, D.seat.eq(me, seat), 1000000, 0)}
    case _ <> rest:
      exact(rest, me)

def state.estimate(+state: T.State, +me: D.Seat, knowledge: Bool) -> U32:
  +players : S.Players = T.state.players(state)
  +world : S.World = T.state.world(state)
  +own : S.Seat = S.players.seat(players, me)
  +bonus : U32 = Bool.pick(U32, Bool.and(knowledge, G.alive(S.seat.health(own))), 25, 0)
  +weight : U32 = (seat.weight(own, turn.is(S.world.turn(world), me)) + bonus : U32)
  total : U32 = (total(D.ring.entries(S.Seat, players), S.world.turn(world)) + bonus : U32)
  F32.to_u32(F32.mul(1000000.0, F32.div(U32.to_f32(weight), U32.to_f32(U32.max(1, total)))))

def state.exact(found: Maybe<&2, U32>, state: T.State, me: D.Seat, knowledge: Bool) -> U32:
  match found:
    case Some{value}:
      value
    case None{}:
      state.estimate(state, me, knowledge)

def state(+state: T.State, +me: D.Seat, knowledge: Bool) -> U32:
  state.exact(exact(T.state.notes(state), me), state, me, knowledge)

def same.chamber(worlds: List<&2, A.World>, +shell: D.Shell) -> Bool:
  match worlds:
    case Nil{}:
      True{}
    case A.World{state, _} <> rest:
      Bool.and(B.filter.clue(S.world.gun(T.state.world(state)), 0n, shell), same.chamber(rest, shell))

def known(+worlds: List<&2, A.World>) -> Bool:
  match worlds:
    case Nil{}:
      False{}
    case _ <> _:
      Bool.or(same.chamber(worlds, D.Live{}), same.chamber(worlds, D.Blank{}))

def sum(worlds: List<&2, A.World>, +me: D.Seat, +knowledge: Bool) -> F32:
  match worlds:
    case Nil{}:
      0.0
    case A.World{position, weight} <> rest:
      F32.add(F32.mul(weight, U32.to_f32(state(position, me, knowledge))), sum(rest, me, knowledge))

def evaluate(belief: A.Belief) -> U32:
  match belief:
    case A.Belief{_, +private, me, _}:
      F32.to_u32(sum(private, me, known(private)))
