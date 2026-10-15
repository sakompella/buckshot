import Base
import ../domain.bend as D
import ../sm/state.bend as S

# The simple machine: sm's rules with the agent moves of web/src/agent/moves.ts
# as its only choices. It shares sm's World, Players and Grabs records.

type Move is Data:
  Shoot{target: D.Seat}
  Use{item: D.Item}
  Jam{target: D.Seat}
  Steal{owner: D.Seat, item: D.Item}
  StealJam{owner: D.Seat, target: D.Seat}

# A move with the slots it acts on: the first slot of the seat (or owner)
# holding the item, and the first adrenaline slot for a steal.
type IdleOption is Data:
  ShootAt{target: D.Seat}
  UseSlot{slot: D.Slot, item: D.Item}
  JamWith{slot: D.Slot, target: D.Seat}
  StealWith{adrenaline: D.Slot, owner: D.Seat, slot: D.Slot, item: D.Item}
  StealJamWith{adrenaline: D.Slot, owner: D.Seat, slot: D.Slot, target: D.Seat}

type Request is Data:
  Draw{label: D.Label, range: D.Range}
  Choose{seat: D.Seat, moves: D.NonEmpty<&2, Move>}
  Finished{}
  Stuck{}

type Point is Data:
  Point{request: Request, board: D.Board}

type Phase is Data:
  NeedFirst{}
  NeedHealth{}
  NeedAmount{}
  NeedBatch{}
  NeedSwap{load: D.Load, shells: List<&2, D.Shell>, i: Nat}
  Idle{seat: D.Seat}
  Ended{}
  Blocked{holder: Maybe<&2, D.Seat>}
  Stalled{}
  NeedTurnAmount{from: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>}
  NeedItem{seat: D.Seat, first: D.Item, second: D.Item, rest: List<&2, D.Item>}
  NeedPhone{seat: D.Seat, owner: D.Seat, slot: D.Slot}

# The notes of the current answer, oldest first, as a list that grows at its
# end, so a note is added without copying the earlier ones.
type Log is Data:
  Empty{}
  Snoc{earlier: Log, note: D.Note}

def log.list(log: Log) -> List<&2, D.Note>:
  match log:
    case Empty{}:
      Nil{}
    case Snoc{earlier, note}:
      List.append(&2, D.Note, log.list(earlier), [note])

type State is Data:
  State{world: S.World, players: S.Players, phase: Phase, log: Log, grabs: S.Grabs}

def state.world(value: State) -> S.World:
  match value:
    case State{world, _, _, _, _}:
      world

def state.set_world(value: State, replacement: S.World) -> State:
  match value:
    case State{_, players, phase, log, grabs}:
      State{replacement, players, phase, log, grabs}

def state.players(value: State) -> S.Players:
  match value:
    case State{_, players, _, _, _}:
      players

def state.set_players(value: State, replacement: S.Players) -> State:
  match value:
    case State{world, _, phase, log, grabs}:
      State{world, replacement, phase, log, grabs}

def state.phase(value: State) -> Phase:
  match value:
    case State{_, _, phase, _, _}:
      phase

def state.set_phase(value: State, replacement: Phase) -> State:
  match value:
    case State{world, players, _, log, grabs}:
      State{world, players, replacement, log, grabs}

def state.log(value: State) -> Log:
  match value:
    case State{_, _, _, log, _}:
      log

def state.notes(value: State) -> List<&2, D.Note>:
  log.list(state.log(value))

def state.set_log(value: State, replacement: Log) -> State:
  match value:
    case State{world, players, phase, _, grabs}:
      State{world, players, phase, replacement, grabs}

def state.grabs(value: State) -> S.Grabs:
  match value:
    case State{_, _, _, _, grabs}:
      grabs

def state.set_grabs(value: State, replacement: S.Grabs) -> State:
  match value:
    case State{world, players, phase, log, _}:
      State{world, players, phase, log, replacement}

# The records as an sm state, for sm's pure rules (sm/items.bend), which never
# read the phase or the notes.
def state.records(value: State) -> S.State:
  match value:
    case State{world, players, _, _, grabs}:
      S.State{world, players, S.Blocked{None{}}, Nil{}, grabs}

def state.emit(state: State, event: D.GameEvent) -> State:
  match state:
    case State{world, players, phase, log, grabs}:
      State{world, players, phase, Snoc{log, D.Shown{event}}, grabs}

def state.tell(state: State, seat: D.Seat, secret: D.Secret) -> State:
  match state:
    case State{world, players, phase, log, grabs}:
      State{world, players, phase, Snoc{log, D.Told{seat, secret}}, grabs}

def state.stepped(+state: State) -> D.Stepped<&2, State>:
  D.Stepped{state, log.list(state.log(state))}
