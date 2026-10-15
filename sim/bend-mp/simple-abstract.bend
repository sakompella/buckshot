import Base
import ./domain.bend as D
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./sm/items.bend as I
import ./simple/main.bend as N
import ./simple/state.bend as T
import ./simple/point.bend as P

# The bridge from the simple machine to sm. embed is the sm state a simple
# state stands for. chain lists the sm steps of one simple answer, and walk
# plays them on sm, step by step, failing on any step sm would not offer.

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
    case T.NeedTurnAmount{from, passing, winner}:
      S.NeedTurnAmount{from, passing, winner}
    case T.NeedItem{seat, first, second, rest}:
      S.NeedItem{seat, first, second, rest}
    case T.NeedPhone{seat, owner, slot}:
      S.NeedPhone{seat, owner, slot}

def embed(+state: T.State) -> S.State:
  S.State{T.state.world(state), T.state.players(state), embed.phase(T.state.phase(state), T.state.records(state)), T.state.notes(state), T.state.grabs(state)}

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

def take.unless(drawn: Bool, seat: D.Seat, rest: List<&2, Step>) -> List<&2, Step>:
  match drawn:
    case True{}:
      rest
    case False{}:
      ChoiceStep{seat, D.Grab{}} <> rest

# The grab moves of a handout, read from its notes: a take before each grant
# (except the grant of an item draw, whose take came before the draw) and each
# empty briefcase, and a place for each placement.
def grab.steps(notes: List<&2, D.Note>, drawn: Bool) -> List<&2, Step>:
  match notes:
    case Nil{}:
      Nil{}
    case D.Shown{D.Granted{seat, _}} <> rest:
      take.unless(drawn, seat, grab.steps(rest, False{}))
    case D.Told{seat, D.EmptyBriefcase{}} <> rest:
      ChoiceStep{seat, D.Grab{}} <> grab.steps(rest, drawn)
    case D.Shown{D.Placed{seat, slot, _}} <> rest:
      ChoiceStep{seat, D.Place{slot}} <> grab.steps(rest, drawn)
    case note <> rest:
      grab.steps(rest, drawn)

# A handout that stops at an item draw ends with that seat's take.
def grab.pending(phase: T.Phase) -> List<&2, Step>:
  match phase:
    case T.NeedItem{seat, _, _, _}:
      [ChoiceStep{seat, D.Grab{}}]
    case _:
      Nil{}

def phase.drawn(phase: T.Phase) -> Bool:
  match phase:
    case T.NeedItem{_, _, _, _}:
      True{}
    case _:
      False{}

def chain.grabs(drawn: Bool, stepped: D.Stepped<&2, T.State>) -> List<&2, Step>:
  match stepped:
    case D.Stepped{state, notes}:
      List.append(&2, Step, grab.steps(notes, drawn), grab.pending(T.state.phase(state)))

def chain.request(+state: T.State, +n: Nat, request: T.Request) -> List<&2, Step>:
  match request:
    case T.Finished{}:
      Nil{}
    case T.Stuck{}:
      Nil{}
    case T.Draw{_, _}:
      DrawStep{n} <> chain.grabs(phase.drawn(T.state.phase(state)), N.answer(state, n))
    case T.Choose{+seat, D.NonEmpty{_, rest}}:
      List.append(&2, Step, option.steps(seat, P.option.nth(P.options(state, seat), D.clamp(n, List.length(&2, T.Move, rest)))), chain.grabs(False{}, N.answer(state, n)))

def chain(+state: T.State, +n: Nat) -> List<&2, Step>:
  chain.request(state, n, N.request(state))

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

def walk.go(steps: List<&2, Step>, answer: Maybe<&2, Nat>, +state: S.State) -> Maybe<&2, D.Stepped<&2, S.State>>:
  match steps answer:
    case _ None{}:
      None{}
    case Nil{} Some{n}:
      Some{M.answer(state, n)}
    case step <> rest Some{n}:
      +stepped : D.Stepped<&2, S.State> = M.answer(state, n)
      +next : S.State = M.stepped.state(stepped)
      walk.merge(stepped, walk.go(rest, walk.legal(M.request(next), step), next))

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
      walk.notes(walk.go(rest, walk.legal(M.request(state), step), state))
