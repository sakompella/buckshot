import Base
import ../domain.bend as D
import ../sm/state.bend as S
import ../sm/rules.bend as G
import ../sm/items.bend as I
import ./state.bend as T

# The Idle menu, computed from the state. Each option is one chain of sm's
# moves: pick up and shoot, use an item, jam, steal with adrenaline.

def shots(targets: List<&2, S.TargetOption>) -> List<&2, T.IdleOption>:
  match targets:
    case Nil{}:
      Nil{}
    case S.Target{seat} <> rest:
      T.ShootAt{seat} <> shots(rest)

def items.has(seen: List<&2, D.Item>, +item: D.Item) -> Bool:
  match seen:
    case Nil{}:
      False{}
    case x <> rest:
      Bool.or(D.item.eq(x, item), items.has(rest, item))

def item.chained(item: D.Item) -> Bool:
  match item:
    case D.Jammer{}:
      True{}
    case D.Adrenaline{}:
      True{}
    case _:
      False{}

def use.first(uses: List<&2, S.IdleOption>, +item: D.Item) -> Maybe<&2, D.Slot>:
  match uses:
    case Nil{}:
      None{}
    case S.UseAt{slot, found} <> rest:
      Bool.pick(Maybe<&2, D.Slot>, D.item.eq(found, item), Some{slot}, use.first(rest, item))
    case S.TakeGun{} <> rest:
      use.first(rest, item)

# One use per distinct item, at its first slot, in slot order.
def use.options(uses: List<&2, S.IdleOption>, +seen: List<&2, D.Item>) -> List<&2, T.IdleOption>:
  match uses:
    case Nil{}:
      Nil{}
    case S.UseAt{+slot, +item} <> rest:
      I.keep(T.IdleOption, Bool.not(Bool.or(item.chained(item), items.has(seen, item))), T.UseSlot{slot, item}, use.options(rest, item <> seen))
    case S.TakeGun{} <> rest:
      use.options(rest, seen)

def jam.targets(+slot: D.Slot, targets: List<&2, S.JamOption>) -> List<&2, T.IdleOption>:
  match targets:
    case Nil{}:
      Nil{}
    case S.JamAt{seat} <> rest:
      T.JamWith{slot, seat} <> jam.targets(slot, rest)

def jam.options(jammer: Maybe<&2, D.Slot>, targets: List<&2, S.JamOption>) -> List<&2, T.IdleOption>:
  match jammer:
    case None{}:
      Nil{}
    case Some{slot}:
      jam.targets(slot, targets)

def picks.has(seen: List<&2, D.At<&2, D.Item>>, +owner: D.Seat, +item: D.Item) -> Bool:
  match seen:
    case Nil{}:
      False{}
    case D.At{seat, x} <> rest:
      Bool.or(Bool.and(D.seat.eq(seat, owner), D.item.eq(x, item)), picks.has(rest, owner, item))

# One steal per owner and distinct item other than a jammer, at the owner's
# first slot holding it, by owner then slot.
def steal.picks(+adrenaline: D.Slot, picks: List<&2, S.StealOption>, +seen: List<&2, D.At<&2, D.Item>>) -> List<&2, T.IdleOption>:
  match picks:
    case Nil{}:
      Nil{}
    case S.Pick{+owner, +slot, +item} <> rest:
      I.keep(T.IdleOption, Bool.not(Bool.or(D.item.eq(item, D.Jammer{}), picks.has(seen, owner, item))), T.StealWith{adrenaline, owner, slot, item}, steal.picks(adrenaline, rest, D.At{owner, item} <> seen))

def steal.options(adrenaline: Maybe<&2, D.Slot>, picks: List<&2, S.StealOption>) -> List<&2, T.IdleOption>:
  match adrenaline:
    case None{}:
      Nil{}
    case Some{slot}:
      steal.picks(slot, picks, Nil{})

def steal_jam.targets(+adrenaline: D.Slot, +owner: D.Seat, +slot: D.Slot, targets: List<&2, S.JamOption>) -> List<&2, T.IdleOption>:
  match targets:
    case Nil{}:
      Nil{}
    case S.JamAt{seat} <> rest:
      T.StealJamWith{adrenaline, owner, slot, seat} <> steal_jam.targets(adrenaline, owner, slot, rest)

def seats.has(seen: List<&2, D.Seat>, +seat: D.Seat) -> Bool:
  match seen:
    case Nil{}:
      False{}
    case x <> rest:
      Bool.or(D.seat.eq(x, seat), seats.has(rest, seat))

def steal_jam.here(take: Bool, +adrenaline: D.Slot, +owner: D.Seat, +slot: D.Slot, targets: List<&2, S.JamOption>) -> List<&2, T.IdleOption>:
  match take:
    case True{}:
      steal_jam.targets(adrenaline, owner, slot, targets)
    case False{}:
      Nil{}

# Each owner's first jammer, stolen and used on each target, by owner then target.
def steal_jam.picks(+adrenaline: D.Slot, picks: List<&2, S.StealOption>, +targets: List<&2, S.JamOption>, +seen: List<&2, D.Seat>) -> List<&2, T.IdleOption>:
  match picks:
    case Nil{}:
      Nil{}
    case S.Pick{+owner, slot, +item} <> rest:
      +jammer : Bool = D.item.eq(item, D.Jammer{})
      List.append(&2, T.IdleOption, steal_jam.here(Bool.and(jammer, Bool.not(seats.has(seen, owner))), adrenaline, owner, slot, targets), steal_jam.picks(adrenaline, rest, targets, I.keep(D.Seat, jammer, owner, seen)))

def steal_jam.options(adrenaline: Maybe<&2, D.Slot>, picks: List<&2, S.StealOption>, targets: List<&2, S.JamOption>) -> List<&2, T.IdleOption>:
  match adrenaline:
    case None{}:
      Nil{}
    case Some{slot}:
      steal_jam.picks(slot, picks, targets, Nil{})

def options(+state: T.State, +seat: D.Seat) -> List<&2, T.IdleOption>:
  +records : S.State = T.state.records(state)
  +uses : List<&2, S.IdleOption> = I.uses(records, seat)
  +targets : List<&2, S.JamOption> = I.jam.for(records, seat)
  +picks : List<&2, S.StealOption> = I.steal.for(records, seat)
  +adrenaline : Maybe<&2, D.Slot> = use.first(uses, D.Adrenaline{})
  List.append(&2, T.IdleOption, shots(G.aim.targets(T.state.players(state))), List.append(&2, T.IdleOption, use.options(uses, Nil{}), List.append(&2, T.IdleOption, jam.options(use.first(uses, D.Jammer{}), targets), List.append(&2, T.IdleOption, steal.options(adrenaline, picks), steal_jam.options(adrenaline, picks, targets)))))

def option.move(option: T.IdleOption) -> T.Move:
  match option:
    case T.ShootAt{target}:
      T.Shoot{target}
    case T.UseSlot{_, item}:
      T.Use{item}
    case T.JamWith{_, target}:
      T.Jam{target}
    case T.StealWith{_, owner, _, item}:
      T.Steal{owner, item}
    case T.StealJamWith{_, owner, _, target}:
      T.StealJam{owner, target}

def moves(options: List<&2, T.IdleOption>) -> List<&2, T.Move>:
  match options:
    case Nil{}:
      Nil{}
    case option <> rest:
      option.move(option) <> moves(rest)

def choose(seat: D.Seat, moves: List<&2, T.Move>) -> T.Request:
  match moves:
    case Nil{}:
      T.Stuck{}
    case move <> rest:
      T.Choose{seat, D.NonEmpty{move, rest}}

def option.nth(options: List<&2, T.IdleOption>, n: Nat) -> Maybe<&2, T.IdleOption>:
  match options n:
    case Nil{} _:
      None{}
    case option <> rest 0n:
      Some{option}
    case option <> rest 1n+n:
      option.nth(rest, n)

def first.range(table: D.Table) -> D.Range:
  match table:
    case D.TwoSeats{}:
      D.Range{0n, 0n}
    case D.ThreeSeats{}:
      D.Range{0n, 1n}
    case D.FourSeats{}:
      D.Range{0n, 2n}

def batch.request(size: Nat) -> T.Request:
  match size:
    case 1n+1n+extra:
      T.Draw{D.SequenceBatch{}, D.Range{0n, extra}}
    case _:
      T.Stuck{}

def phone.request(length: Nat) -> T.Request:
  match length:
    case 1n+1n+1n+1n+extra:
      T.Draw{D.PhoneIndex{}, D.Range{2n, extra}}
    case _:
      T.Stuck{}

def phase.request(phase: T.Phase, +world: S.World, +state: T.State) -> T.Request:
  match phase:
    case T.NeedFirst{}:
      T.Draw{D.FirstSeat{}, first.range(S.world.table(world))}
    case T.NeedHealth{}:
      T.Draw{D.StartingHealth{}, D.table.health_range(S.world.table(world))}
    case T.NeedAmount{}:
      T.Draw{D.ItemAmount{}, D.table.amount_range(S.world.table(world))}
    case T.NeedBatch{}:
      batch.request(List.length(&2, S.Batch, S.world.deck(world)))
    case T.NeedSwap{_, _, 1n+extra}:
      T.Draw{D.ShuffleSwap{}, D.Range{0n, extra}}
    case T.NeedSwap{_, _, 0n}:
      T.Stuck{}
    case T.Idle{+seat}:
      choose(seat, moves(options(state, seat)))
    case T.Ended{}:
      T.Finished{}
    case T.Blocked{_}:
      T.Stuck{}
    case T.NeedTurnAmount{_, _, _}:
      T.Draw{D.ItemAmount{}, D.table.amount_range(S.world.table(world))}
    case T.NeedItem{_, _, _, rest}:
      T.Draw{D.ItemChoice{}, D.Range{0n, List.length(&2, D.Item, rest)}}
    case T.NeedPhone{_, _, _}:
      phone.request(List.length(&2, D.Shell, S.world.gun(world)))

def request(+state: T.State) -> T.Request:
  phase.request(T.state.phase(state), T.state.world(state), state)

def phase.stage(phase: T.Phase) -> D.Stage:
  match phase:
    case T.NeedBatch{}:
      D.Loading{}
    case T.NeedSwap{_, _, _}:
      D.Loading{}
    case T.Idle{seat}:
      D.Playing{seat, D.Idle{}}
    case T.Ended{}:
      D.MatchOver{}
    case T.NeedTurnAmount{_, _, _}:
      D.Distributing{}
    case T.NeedItem{_, _, _, _}:
      D.Distributing{}
    case T.NeedPhone{seat, _, _}:
      D.Playing{seat, D.Idle{}}
    case _:
      D.Setup{}

def stage(state: T.State) -> D.Stage:
  phase.stage(T.state.phase(state))

def field.or(-A: Data, value: Maybe<&2, A>, fallback: A) -> A:
  match value:
    case Some{x}:
      x
    case None{}:
      fallback

def seat.view(+players: S.Players, +grabs: S.Grabs, +seat: D.Seat) -> D.SeatView:
  hp : Nat = field.or(Nat, D.ring.get(Nat, S.players.health(players), seat), 100n)
  jam : Bool = S.jam.jammed(field.or(S.Jam, D.ring.get(S.Jam, S.players.jam(players), seat), S.Free{}))
  slots : D.Slots = field.or(D.Slots, D.ring.get(D.Slots, S.players.slots(players), seat), D.slots.empty())
  cash : U32 = field.or(U32, D.ring.get(U32, S.players.cash(players), seat), 0)
  D.SeatView{D.counter.of(jam, hp), slots, cash, I.briefcase(I.seat.grabbing(grabs, seat), I.seat.holding(grabs, seat))}

def seat.views(seats: List<&2, D.Seat>, +players: S.Players, +grabs: S.Grabs, views: D.Ring<&2, D.SeatView>) -> D.Ring<&2, D.SeatView>:
  match seats:
    case Nil{}:
      views
    case +seat <> rest:
      seat.views(rest, players, grabs, D.ring.set(D.SeatView, views, seat, seat.view(players, grabs, seat)))

def board(+state: T.State) -> D.Board:
  +world : S.World = T.state.world(state)
  +table : D.Table = S.world.table(world)
  views : D.Ring<&2, D.SeatView> = seat.views(D.table.seats(table), T.state.players(state), T.state.grabs(state), D.ring.fill(D.SeatView, table, D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}}))
  D.Board{D.RoundView{S.world.round_index(world), D.plan.length(S.world.plan(world)), S.world.round_health(world)}, views, D.GunView{S.world.shown(world), List.length(&2, D.Shell, S.world.gun(world)), S.world.sawed(world)}, S.world.direction(world), stage(state)}

def point(+state: T.State) -> T.Point:
  T.Point{request(state), board(state)}
