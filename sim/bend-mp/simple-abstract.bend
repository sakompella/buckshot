import Base
import ./domain.bend as D
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./sm/items.bend as I
import ./sm/rules.bend as G
import ./simple/main.bend as N
import ./simple/state.bend as T
import ./simple/point.bend as P

# The bridge from the simple machine to sm. embed is the sm state a simple
# state stands for, and back reads it back. chain lists the sm steps of one
# simple answer, and walk plays them on sm, step by step, failing on any step
# sm would not offer.

def embed.phase(phase: T.Phase, +records: S.State) -> S.Phase:
  match phase:
    case T.NeedFirst{}:
      S.NeedFirst{}
    case T.NeedHealth{}:
      S.NeedHealth{}
    case T.NeedAmount{}:
      S.NeedAmount{}
    case T.NeedBatch{}:
      S.NeedBatch{}
    case T.NeedSwap{load, shells, i}:
      S.NeedSwap{load, shells, i}
    case T.Idle{+seat}:
      S.Idle{seat, D.NonEmpty{S.TakeGun{}, I.uses(records, seat)}}
    case T.Ended{}:
      S.Ended{}
    case T.Blocked{holder}:
      S.Blocked{holder}
    case T.Stalled{}:
      S.Grab{I.grab.needs(records)}
    case T.NeedTurnAmount{from, passing, winner}:
      S.NeedTurnAmount{from, passing, winner}
    case T.NeedItem{seat, first, second, rest}:
      S.NeedItem{seat, first, second, rest}
    case T.NeedPhone{seat, owner, slot}:
      S.NeedPhone{seat, owner, slot}

def embed(+state: T.State) -> S.State:
  S.State{T.state.world(state), T.state.players(state), embed.phase(T.state.phase(state), T.state.records(state)), T.state.notes(state), T.state.grabs(state)}

# A simple answer read as an sm one: the embedded state and the same notes.
def lift(stepped: D.Stepped<&2, T.State>) -> Maybe<&2, D.Stepped<&2, S.State>>:
  match stepped:
    case D.Stepped{state, notes}:
      Some{D.Stepped{embed(state), notes}}

# One sm answer: a tape answer to a draw, or a seat's move.
type Step is Data:
  DrawStep{answer: Nat}
  ChoiceStep{seat: D.Seat, move: D.Move}

def option.steps(+seat: D.Seat, option: Maybe<&2, T.IdleOption>) -> List<&2, Step>:
  match option:
    case Some{T.ShootAt{target}}:
      [ChoiceStep{seat, D.PickUp{}}, ChoiceStep{seat, D.Shoot{target}}]
    case Some{T.UseSlot{slot, item}}:
      [ChoiceStep{seat, D.UseItem{slot, item}}]
    case Some{T.JamWith{slot, target}}:
      [ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, ChoiceStep{seat, D.JamTarget{target}}]
    case Some{T.StealWith{adrenaline, owner, slot, item}}:
      [ChoiceStep{seat, D.UseItem{adrenaline, D.Adrenaline{}}}, ChoiceStep{seat, D.Steal{owner, slot, item}}]
    case Some{T.StealJamWith{adrenaline, owner, slot, target}}:
      [ChoiceStep{seat, D.UseItem{adrenaline, D.Adrenaline{}}}, ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}, ChoiceStep{seat, D.JamTarget{target}}]
    case None{}:
      Nil{}

def walk.index(prompt: D.Prompt, index: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match index:
    case None{}:
      None{}
    case Some{k}:
      Some{D.prompt.answer(prompt, k)}

def walk.prompt(prompt: Maybe<&2, D.Prompt>, move: D.Move) -> Maybe<&2, Nat>:
  match prompt:
    case None{}:
      None{}
    case Some{+found}:
      walk.index(found, D.prompt.index(found, move))

# The tape answer for a step, if sm offers it at this request.
def walk.legal(+request: D.Request, step: Step) -> Maybe<&2, Nat>:
  match request step:
    case D.Draw{_, _} DrawStep{n}:
      Some{n}
    case _ ChoiceStep{+seat, move}:
      walk.prompt(D.prompt.of(request, seat), move)
    case _ _:
      None{}

def walk.merge(stepped: D.Stepped<&2, S.State>, rest: Maybe<&2, D.Stepped<&2, S.State>>) -> Maybe<&2, D.Stepped<&2, S.State>>:
  match stepped rest:
    case _ None{}:
      None{}
    case D.Stepped{_, first} Some{D.Stepped{state, notes}}:
      Some{D.Stepped{state, List.append(&2, D.Note, first, notes)}}

def walk.answer(answer: Maybe<&2, Nat>, +state: S.State, rest: S.State -> Maybe<&2, D.Stepped<&2, S.State>>) -> Maybe<&2, D.Stepped<&2, S.State>>:
  match answer:
    case None{}:
      None{}
    case Some{n}:
      +stepped : D.Stepped<&2, S.State> = M.answer(state, n)
      walk.merge(stepped, rest(M.stepped.state(stepped)))

# The steps played from a state: the notes of each sm answer in turn, and the
# state the last one reached.
def walk.go(steps: List<&2, Step>, +state: S.State) -> Maybe<&2, D.Stepped<&2, S.State>>:
  match steps:
    case Nil{}:
      Some{D.Stepped{state, Nil{}}}
    case +step <> rest:
      walk.answer(walk.legal(M.request(state), step), state, next => walk.go(rest, next))

# The end state carries all the notes, as a simple answer's state does.
def walk.notes(walked: Maybe<&2, D.Stepped<&2, S.State>>) -> Maybe<&2, D.Stepped<&2, S.State>>:
  match walked:
    case None{}:
      None{}
    case Some{D.Stepped{state, +notes}}:
      Some{D.Stepped{S.state.set_notes(state, notes), notes}}

def walk(+state: S.State, steps: List<&2, Step>) -> Maybe<&2, D.Stepped<&2, S.State>>:
  match steps:
    case Nil{}:
      Some{D.Stepped{state, Nil{}}}
    case step <> rest:
      walk.notes(walk.go(step <> rest, state))
def log.of.go(notes: List<&2, D.Note>, acc: T.Log) -> T.Log:
  match notes:
    case Nil{}:
      acc
    case note <> rest:
      log.of.go(rest, T.Snoc{acc, note})

def log.of(notes: List<&2, D.Note>) -> T.Log:
  log.of.go(notes, T.Empty{})

# Aim, JamPick and StealPick have no simple phase; they read back as Blocked.
def back.phase(phase: S.Phase) -> T.Phase:
  match phase:
    case S.NeedFirst{}:
      T.NeedFirst{}
    case S.NeedHealth{}:
      T.NeedHealth{}
    case S.NeedAmount{}:
      T.NeedAmount{}
    case S.NeedBatch{}:
      T.NeedBatch{}
    case S.NeedSwap{load, shells, i}:
      T.NeedSwap{load, shells, i}
    case S.Idle{seat, _}:
      T.Idle{seat}
    case S.Ended{}:
      T.Ended{}
    case S.Blocked{holder}:
      T.Blocked{holder}
    case S.Grab{_}:
      T.Stalled{}
    case S.NeedTurnAmount{from, passing, winner}:
      T.NeedTurnAmount{from, passing, winner}
    case S.NeedItem{seat, first, second, rest}:
      T.NeedItem{seat, first, second, rest}
    case S.NeedPhone{seat, owner, slot}:
      T.NeedPhone{seat, owner, slot}
    case _:
      T.Blocked{None{}}

def back(state: S.State) -> T.State:
  match state:
    case S.State{world, players, phase, notes, grabs}:
      T.State{world, players, back.phase(phase), log.of(notes), grabs}

# The distribution schedule, stated over the menus sm offers at a Grab
# point: the last seat to act places at the first Place in its menu;
# otherwise the first seat, cycling in socket order from the one after it,
# whose menu is a lone Grab, takes; otherwise no one moves.
def order(table: D.Table, after: D.Seat) -> List<&2, D.Seat>:
  match table after:
    case D.TwoSeats{} D.Seat1{}:
      [D.Seat3{}, D.Seat1{}]
    case D.TwoSeats{} D.Seat3{}:
      [D.Seat1{}, D.Seat3{}]
    case D.ThreeSeats{} D.Seat0{}:
      [D.Seat1{}, D.Seat2{}, D.Seat0{}]
    case D.ThreeSeats{} D.Seat1{}:
      [D.Seat2{}, D.Seat0{}, D.Seat1{}]
    case D.ThreeSeats{} D.Seat2{}:
      [D.Seat0{}, D.Seat1{}, D.Seat2{}]
    case D.FourSeats{} D.Seat0{}:
      [D.Seat1{}, D.Seat2{}, D.Seat3{}, D.Seat0{}]
    case D.FourSeats{} D.Seat1{}:
      [D.Seat2{}, D.Seat3{}, D.Seat0{}, D.Seat1{}]
    case D.FourSeats{} D.Seat2{}:
      [D.Seat3{}, D.Seat0{}, D.Seat1{}, D.Seat2{}]
    case D.FourSeats{} D.Seat3{}:
      [D.Seat0{}, D.Seat1{}, D.Seat2{}, D.Seat3{}]
    case table _:
      D.table.seats(table)

def menu.of(+menus: D.Ring<&2, List<&2, D.Move>>, seat: D.Seat) -> List<&2, D.Move>:
  G.value.or(List<&2, D.Move>, D.ring.get(List<&2, D.Move>, menus, seat), Nil{})

def menu.takes(moves: List<&2, D.Move>) -> Bool:
  match moves:
    case D.Grab{} <> Nil{}:
      True{}
    case _:
      False{}

def taker(seats: List<&2, D.Seat>, +menus: D.Ring<&2, List<&2, D.Move>>) -> Maybe<&2, Step>:
  match seats:
    case Nil{}:
      None{}
    case +seat <> rest:
      Bool.pick(Maybe<&2, Step>, menu.takes(menu.of(menus, seat)), Some{ChoiceStep{seat, D.Grab{}}}, taker(rest, menus))

def decide.own(own: List<&2, D.Move>, +after: D.Seat, seats: List<&2, D.Seat>, +menus: D.Ring<&2, List<&2, D.Move>>) -> Maybe<&2, Step>:
  match own:
    case D.Place{slot} <> _:
      Some{ChoiceStep{after, D.Place{slot}}}
    case _:
      taker(seats, menus)

def decide(+menus: D.Ring<&2, List<&2, D.Move>>, table: D.Table, +after: D.Seat) -> Maybe<&2, Step>:
  decide.own(menu.of(menus, after), after, order(table, after), menus)

# The simple machine's bound on the grab moves of one distribution.
def budget(table: D.Table) -> Nat:
  match table:
    case D.TwoSeats{}:
      34n
    case D.ThreeSeats{}:
      51n
    case D.FourSeats{}:
      68n

def decide.phase(phase: S.Phase, table: D.Table, +after: D.Seat) -> Maybe<&2, Step>:
  match phase:
    case S.Grab{needs}:
      decide(I.grab.menus(needs), table, after)
    case _:
      None{}

def sched.decide(+state: S.State, +after: D.Seat) -> Maybe<&2, Step>:
  decide.phase(S.state.phase(state), S.world.table(S.state.world(state)), after)

def sched.index(+state: S.State, index: Maybe<&2, Nat>) -> S.State:
  match index:
    case Some{k}:
      M.stepped.state(M.answer(state, k))
    case None{}:
      S.state.set_phase(state, S.Blocked{None{}})

def sched.go(fuel: Nat, step: Maybe<&2, Step>, +state: S.State) -> List<&2, Step>:
  match fuel step:
    case 0n _:
      Nil{}
    case 1n+fuel Some{ChoiceStep{+seat, +move}}:
      +next : S.State = sched.index(state, walk.legal(M.request(state), ChoiceStep{seat, move}))
      ChoiceStep{seat, move} <> sched.go(fuel, sched.decide(next, seat), next)
    case 1n+fuel _:
      Nil{}

# No grab move to make ends the schedule before the fuel is read.
def sched.start(step: Maybe<&2, Step>, +state: S.State, fuel: Nat) -> List<&2, Step>:
  match step:
    case None{}:
      Nil{}
    case Some{first}:
      sched.go(fuel, Some{first}, state)

# The grab moves sm makes after a step, from the state it reached. An item
# draw continues its seat's turn at the briefcase; otherwise a distribution
# starts after the round's or load's first shooter.
def sched(+state: S.State, +after: D.Seat) -> List<&2, Step>:
  sched.start(sched.decide(state, after), state, budget(S.world.table(S.state.world(state))))

def chain.after(phase: T.Phase, +state: S.State) -> D.Seat:
  match phase:
    case T.NeedItem{seat, _, _, _}:
      seat
    case _:
      S.world.first_turn(S.state.world(state))

def chain.first(+state: T.State, +n: Nat, request: T.Request) -> List<&2, Step>:
  match request:
    case T.Finished{}:
      Nil{}
    case T.Stuck{}:
      Nil{}
    case T.Draw{_, _}:
      [DrawStep{n}]
    case T.Choose{+seat, D.NonEmpty{_, rest}}:
      option.steps(seat, P.option.nth(P.options(state, seat), D.clamp(n, List.length(&2, T.Move, rest))))

def chain.rest(+state: T.State, +first: List<&2, Step>, walked: Maybe<&2, D.Stepped<&2, S.State>>) -> List<&2, Step>:
  match first walked:
    case Nil{} _:
      Nil{}
    case _ None{}:
      first
    case _ Some{D.Stepped{+reached, _}}:
      List.append(&2, Step, first, sched(reached, chain.after(T.state.phase(state), reached)))

def chain(+state: T.State, +n: Nat) -> List<&2, Step>:
  +first : List<&2, Step> = chain.first(state, n, N.request(state))
  chain.rest(state, first, walk.go(first, embed(state)))


def ran.state(ran: D.Ran<&2, T.State>) -> T.State:
  match ran:
    case D.Ran{state, _, _}:
      state

# The sm steps of a simple run: each answer's chain, in turn.
def chains.request(fuel: Nat, request: T.Request, +state: T.State, tape: List<&2, Nat>) -> List<&2, Step>:
  match fuel request tape:
    case _ T.Finished{} _:
      Nil{}
    case _ T.Stuck{} _:
      Nil{}
    case 0n _ _:
      Nil{}
    case _ _ Nil{}:
      Nil{}
    case 1n+fuel _ +n <> rest:
      +next : T.State = N.stepped.state(N.answer(state, n))
      List.append(&2, Step, chain(state, n), chains.request(fuel, P.request(next), next, rest))

def chains(fuel: Nat, +state: T.State, tape: List<&2, Nat>) -> List<&2, Step>:
  chains.request(fuel, N.request(state), state, tape)

# sm playing steps from a state, the end state holding all their notes.
def replay(+state: S.State, steps: List<&2, Step>) -> Maybe<&2, D.Stepped<&2, S.State>>:
  walk.notes(walk.go(steps, state))

# A simple run read as an sm one: its end embedded, holding all its notes.
def ran(ran: D.Ran<&2, T.State>) -> Maybe<&2, D.Stepped<&2, S.State>>:
  match ran:
    case D.Ran{+state, +notes, _}:
      Some{D.Stepped{S.state.set_notes(embed(state), notes), notes}}
