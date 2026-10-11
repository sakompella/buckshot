import Base
import ../domain.bend as D
import ./state.bend as S
import ./rules.bend as G

def first.range(table: D.Table) -> D.Range:
  match table:
    case D.TwoSeats{}:
      D.Range{0n, 0n}
    case D.ThreeSeats{}:
      D.Range{0n, 1n}
    case D.FourSeats{}:
      D.Range{0n, 2n}

def batch.request(size: Nat) -> D.Request:
  match size:
    case 1n+1n+extra:
      D.Draw{D.SequenceBatch{}, D.Range{0n, extra}}
    case _:
      D.Stuck{}

def phase.request(phase: S.Phase, +world: S.World) -> D.Request:
  match phase:
    case S.NeedFirst{}:
      D.Draw{D.FirstSeat{}, first.range(S.world.table(world))}
    case S.NeedHealth{}:
      D.Draw{D.StartingHealth{}, D.table.health_range(S.world.table(world))}
    case S.NeedAmount{}:
      D.Draw{D.ItemAmount{}, D.table.amount_range(S.world.table(world))}
    case S.NeedBatch{}:
      batch.request(List.length(&2, S.Batch, S.world.deck(world)))
    case S.NeedSwap{_, _, 1n+extra}:
      D.Draw{D.ShuffleSwap{}, D.Range{0n, extra}}
    case S.NeedSwap{_, _, 0n}:
      D.Stuck{}
    case S.Idle{seat, options}:
      G.seat.menu(S.world.table(world), seat, G.idle.moves(D.nonempty.list(S.IdleOption, options)))
    case S.Aim{seat, targets}:
      G.seat.menu(S.world.table(world), seat, G.aim.moves(targets))
    case S.Ended{}:
      D.Finished{}
    case S.Blocked{}:
      D.Stuck{}

def request(+state: S.State) -> D.Request:
  phase.request(S.state.phase(state), S.state.world(state))

def phase.stage(phase: S.Phase) -> D.Stage:
  match phase:
    case S.NeedBatch{}:
      D.Loading{}
    case S.NeedSwap{_, _, _}:
      D.Loading{}
    case S.Idle{seat, _}:
      D.Playing{seat, D.Idle{}}
    case S.Aim{seat, _}:
      D.Playing{seat, D.Aiming{}}
    case S.Ended{}:
      D.MatchOver{}
    case _:
      D.Setup{}

def stage(state: S.State) -> D.Stage:
  phase.stage(S.state.phase(state))

def field.or(-A: Data, value: Maybe<&2, A>, fallback: A) -> A:
  match value:
    case Some{x}:
      x
    case None{}:
      fallback

def seat.view(+players: S.Players, +seat: D.Seat) -> D.SeatView:
  hp : Nat = field.or(Nat, D.ring.get(Nat, S.players.health(players), seat), 100n)
  jam : Bool = field.or(Bool, D.ring.get(Bool, S.players.jammed(players), seat), False{})
  slots : D.Slots = field.or(D.Slots, D.ring.get(D.Slots, S.players.slots(players), seat), D.slots.empty())
  cash : U32 = field.or(U32, D.ring.get(U32, S.players.cash(players), seat), 0)
  D.SeatView{D.counter.of(jam, hp), slots, cash, D.NotGrabbing{}}

def seat.views(seats: List<&2, D.Seat>, +players: S.Players, views: D.Ring<&2, D.SeatView>) -> D.Ring<&2, D.SeatView>:
  match seats:
    case Nil{}:
      views
    case +seat <> rest:
      seat.views(rest, players, D.ring.set(D.SeatView, views, seat, seat.view(players, seat)))

def board(+state: S.State) -> D.Board:
  +world : S.World = S.state.world(state)
  +table : D.Table = S.world.table(world)
  views : D.Ring<&2, D.SeatView> = seat.views(D.table.seats(table), S.state.players(state), D.ring.fill(D.SeatView, table, D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}}))
  D.Board{D.RoundView{S.world.round_index(world), D.plan.length(S.world.plan(world)), S.world.round_health(world)}, views, D.GunView{S.world.shown(world), List.length(&2, D.Shell, S.world.gun(world)), S.world.sawed(world)}, S.world.direction(world), stage(state)}

def point(+state: S.State) -> D.Point:
  D.Point{request(state), board(state)}
