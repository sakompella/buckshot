import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/items.bend as I
import ./sm/main.bend as M
import ./sm/rules.bend as Q
import ./ref/main.bend as R
import ./ref/state.bend as H
import ./ref/rules.bend as G
import ./ref/items.bend as RI

# The handout's computations agree between the machine and the reference
# host A.ref_host(s), under the table tie A.Shape(s). Bodies marked generated
# in tools/proof_cases.py are owned by that script.

def absurd(-X: Type, impossible: Empty) -> X:
  match impossible:

def table.is_two(t: D.Table) -> Type:
  match t:
    case D.TwoSeats{}:
      Empty
    case _:
      Unit

def table.is_three(t: D.Table) -> Type:
  match t:
    case D.ThreeSeats{}:
      Empty
    case _:
      Unit

def table.is_four(t: D.Table) -> Type:
  match t:
    case D.FourSeats{}:
      Empty
    case _:
      Unit

def clash.three_two(e: {D.ThreeSeats{} == D.TwoSeats{} : D.Table}) -> Empty:
  %e : table.is_two(_)
  Unit{}

def clash.four_two(e: {D.FourSeats{} == D.TwoSeats{} : D.Table}) -> Empty:
  %e : table.is_two(_)
  Unit{}

def clash.two_three(e: {D.TwoSeats{} == D.ThreeSeats{} : D.Table}) -> Empty:
  %e : table.is_three(_)
  Unit{}

def clash.four_three(e: {D.FourSeats{} == D.ThreeSeats{} : D.Table}) -> Empty:
  %e : table.is_three(_)
  Unit{}

def clash.two_four(e: {D.TwoSeats{} == D.FourSeats{} : D.Table}) -> Empty:
  %e : table.is_four(_)
  Unit{}

def clash.three_four(e: {D.ThreeSeats{} == D.FourSeats{} : D.Table}) -> Empty:
  %e : table.is_four(_)
  Unit{}

def add_cong(+a: Nat, +a2: Nat, +b: Nat, +b2: Nat, ea: {a == a2 : Nat}, eb: {b == b2 : Nat}) -> {Nat.add(a, b) == Nat.add(a2, b2) : Nat}:
  %ea : {Nat.add(a, b) == Nat.add(_, b2) : Nat}
  %eb : {Nat.add(a, b) == Nat.add(a, _) : Nat}
  {==}

# L1. Item counts over slots: the reference's G.item.count and the machine's
# I.copies are the same sum.

def count.bool(+b: Bool) -> {G.item.count.bool(b) == I.bool.nat(b) : Nat}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def count.cell(+c: Maybe<&2, D.Item>, +item: D.Item) -> {G.item.count.here(c, item) == I.copies.one(c, item) : Nat}:
  match c:
    case None{}:
      {==}
    case Some{x}:
      count.bool(D.item.eq(x, item))

def count.list(+xs: List<&2, Maybe<&2, D.Item>>, +item: D.Item) -> {G.item.count(xs, item) == I.copies(xs, item) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +rest:
      add_cong(G.item.count.here(x, item), I.copies.one(x, item), G.item.count(rest, item), I.copies(rest, item), count.cell(x, item), count.list(rest, item))

def count.slots(+sl: D.Slots, +item: D.Item) -> {G.item.count(G.slots.list(sl), item) == I.copies(I.slots.items(sl), item) : Nat}:
  match sl:
    case D.Slots{a, b, c, d, e, f, g, h}:
      count.list([a, b, c, d, e, f, g, h], item)

# One seat's count of an item, slots plus the item in hand.
def own.ref(sl: D.Slots, held: Maybe<&2, D.Item>, +item: D.Item) -> Nat:
  Nat.add(G.item.count(G.slots.list(sl), item), G.item.count.here(held, item))

def own.machine(sl: D.Slots, held: Maybe<&2, D.Item>, +item: D.Item) -> Nat:
  Nat.add(I.copies(I.slots.items(sl), item), I.copies.one(held, item))

def count.owned(+sl: D.Slots, +held: Maybe<&2, D.Item>, +item: D.Item) -> {own.ref(sl, held, item) == own.machine(sl, held, item) : Nat}:
  add_cong(G.item.count(G.slots.list(sl), item), I.copies(I.slots.items(sl), item), G.item.count.here(held, item), I.copies.one(held, item), count.slots(sl, item), count.cell(held, item))

# L2. Pools.

def own.claim(+s: S.State, +seat: D.Seat, +item: D.Item) -> Type:
  {G.props.item_count(H.host.props(A.ref_host(s), seat), item) == I.owned(S.state.players(s), S.state.grabs(s), seat, item) : Nat}

def own.eq(+s: S.State, +seat: D.Seat, +item: D.Item, +shape: A.Shape(s)) -> own.claim(s, seat, item):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} D.Seat1{}:
          count.owned(s1, o1, item)
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} D.Seat3{}:
          count.owned(s3, o3, item)
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat, item), clash.three_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat, item), clash.four_two(e_holding))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat0{}:
          count.owned(s0, o0, item)
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat1{}:
          count.owned(s1, o1, item)
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat2{}:
          count.owned(s2, o2, item)
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat, item), clash.two_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat, item), clash.four_three(e_holding))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat0{}:
          count.owned(s0, o0, item)
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat1{}:
          count.owned(s1, o1, item)
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat2{}:
          count.owned(s2, o2, item)
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat3{}:
          count.owned(s3, o3, item)
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat, item), clash.two_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(own.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat, item), clash.three_four(e_holding))

def total.claim(+s: S.State, +item: D.Item) -> Type:
  {G.table.item_count(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), item) == I.owned.table(D.table.seats(S.world.table(S.state.world(s))), S.state.players(s), S.state.grabs(s), item) : Nat}

def total.eq(+s: S.State, +item: D.Item, +shape: A.Shape(s)) -> total.claim(s, item):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake}:
          add_cong(own.ref(s1, o1, item), own.machine(s1, o1, item), Nat.add(own.ref(s3, o3, item), 0n), Nat.add(own.machine(s3, o3, item), 0n), count.owned(s1, o1, item), add_cong(own.ref(s3, o3, item), own.machine(s3, o3, item), 0n, 0n, count.owned(s3, o3, item), {==}))
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, item), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, item), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, item), clash.three_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, item), clash.four_two(e_holding))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake}:
          add_cong(own.ref(s0, o0, item), own.machine(s0, o0, item), Nat.add(own.ref(s1, o1, item), Nat.add(own.ref(s2, o2, item), 0n)), Nat.add(own.machine(s1, o1, item), Nat.add(own.machine(s2, o2, item), 0n)), count.owned(s0, o0, item), add_cong(own.ref(s1, o1, item), own.machine(s1, o1, item), Nat.add(own.ref(s2, o2, item), 0n), Nat.add(own.machine(s2, o2, item), 0n), count.owned(s1, o1, item), add_cong(own.ref(s2, o2, item), own.machine(s2, o2, item), 0n, 0n, count.owned(s2, o2, item), {==})))
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, item), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, item), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, item), clash.two_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, item), clash.four_three(e_holding))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake}:
          add_cong(own.ref(s0, o0, item), own.machine(s0, o0, item), Nat.add(own.ref(s1, o1, item), Nat.add(own.ref(s2, o2, item), Nat.add(own.ref(s3, o3, item), 0n))), Nat.add(own.machine(s1, o1, item), Nat.add(own.machine(s2, o2, item), Nat.add(own.machine(s3, o3, item), 0n))), count.owned(s0, o0, item), add_cong(own.ref(s1, o1, item), own.machine(s1, o1, item), Nat.add(own.ref(s2, o2, item), Nat.add(own.ref(s3, o3, item), 0n)), Nat.add(own.machine(s2, o2, item), Nat.add(own.machine(s3, o3, item), 0n)), count.owned(s1, o1, item), add_cong(own.ref(s2, o2, item), own.machine(s2, o2, item), Nat.add(own.ref(s3, o3, item), 0n), Nat.add(own.machine(s3, o3, item), 0n), count.owned(s2, o2, item), add_cong(own.ref(s3, o3, item), own.machine(s3, o3, item), 0n, 0n, count.owned(s3, o3, item), {==}))))
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, item), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, item), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, item), clash.two_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(total.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, item), clash.three_four(e_holding))

def put_keep(+b: Bool, +x: D.Item, +rest: List<&2, D.Item>) -> {G.GetItemToGrab.put(b, x, rest) == I.keep(D.Item, b, x, rest) : List<&2, D.Item>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def pool.step(+rule: D.ItemRule, +dealt: Bool, +own: Nat, +total: Nat, +item: D.Item, +rest: List<&2, D.Item>) -> {G.GetItemToGrab.put(G.eligible.rule(rule, dealt, own, total), item, rest) == I.keep(D.Item, I.stock.open(rule, dealt, own, total), item, rest) : List<&2, D.Item>}:
  match rule:
    case D.ItemRule{enabled, cap, global_cap}:
      put_keep(Bool.and(enabled, Bool.and(dealt, Bool.and(Nat.is_lt(own, cap), Nat.is_lt(total, global_cap)))), item, rest)

def rules.items_eq(+r: D.RoundRules) -> {H.rules.items(r) == I.round.items(r) : D.ItemRules}:
  match r:
    case D.RoundRules{a, b, c}:
      {==}

def rules.found_eq(+found: Maybe<&2, D.RoundRules>) -> {H.rules.items(H.rules.found(found)) == I.round.items(Q.value.or(D.RoundRules, found, D.config.default_round())) : D.ItemRules}:
  match found:
    case Some{r}:
      rules.items_eq(r)
    case None{}:
      {==}

def rules.eq(+s: S.State) -> {H.rules.items(H.host.rules(A.ref_host(s))) == I.round.items(Q.world.rules(S.state.world(s))) : D.ItemRules}:
  match s:
    case S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}:
      rules.found_eq(D.plan.round(plan, round))

def table.eq(+s: S.State) -> {H.host.table(A.ref_host(s)) == S.world.table(S.state.world(s)) : D.Table}:
  match s:
    case S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}:
      {==}

def pool.go_eq(+items: List<&2, D.Item>, +s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> {G.GetItemToGrab.pool(items, A.ref_host(s), seat) == I.pool.go(items, I.round.items(Q.world.rules(S.state.world(s))), S.world.table(S.state.world(s)), S.state.players(s), S.state.grabs(s), seat) : List<&2, D.Item>}:
  match items:
    case Nil{}:
      {==}
    case +item <> +rest:
      %rules.eq(s) : {G.GetItemToGrab.pool(item <> rest, A.ref_host(s), seat) == I.keep(D.Item, I.stock.open(D.rules.item(_, item), D.item.dealt_at(S.world.table(S.state.world(s)), item), I.owned(S.state.players(s), S.state.grabs(s), seat, item), I.owned.table(D.table.seats(S.world.table(S.state.world(s))), S.state.players(s), S.state.grabs(s), item)), item, I.pool.go(rest, I.round.items(Q.world.rules(S.state.world(s))), S.world.table(S.state.world(s)), S.state.players(s), S.state.grabs(s), seat)) : List<&2, D.Item>}
      %table.eq(s) : {G.GetItemToGrab.pool(item <> rest, A.ref_host(s), seat) == I.keep(D.Item, I.stock.open(D.rules.item(H.rules.items(H.host.rules(A.ref_host(s))), item), D.item.dealt_at(_, item), I.owned(S.state.players(s), S.state.grabs(s), seat, item), I.owned.table(D.table.seats(S.world.table(S.state.world(s))), S.state.players(s), S.state.grabs(s), item)), item, I.pool.go(rest, I.round.items(Q.world.rules(S.state.world(s))), S.world.table(S.state.world(s)), S.state.players(s), S.state.grabs(s), seat)) : List<&2, D.Item>}
      %own.eq(s, seat, item, shape) : {G.GetItemToGrab.pool(item <> rest, A.ref_host(s), seat) == I.keep(D.Item, I.stock.open(D.rules.item(H.rules.items(H.host.rules(A.ref_host(s))), item), D.item.dealt_at(H.host.table(A.ref_host(s)), item), _, I.owned.table(D.table.seats(S.world.table(S.state.world(s))), S.state.players(s), S.state.grabs(s), item)), item, I.pool.go(rest, I.round.items(Q.world.rules(S.state.world(s))), S.world.table(S.state.world(s)), S.state.players(s), S.state.grabs(s), seat)) : List<&2, D.Item>}
      %total.eq(s, item, shape) : {G.GetItemToGrab.pool(item <> rest, A.ref_host(s), seat) == I.keep(D.Item, I.stock.open(D.rules.item(H.rules.items(H.host.rules(A.ref_host(s))), item), D.item.dealt_at(H.host.table(A.ref_host(s)), item), G.props.item_count(H.host.props(A.ref_host(s), seat), item), _), item, I.pool.go(rest, I.round.items(Q.world.rules(S.state.world(s))), S.world.table(S.state.world(s)), S.state.players(s), S.state.grabs(s), seat)) : List<&2, D.Item>}
      %pool.go_eq(rest, s, seat, shape) : {G.GetItemToGrab.pool(item <> rest, A.ref_host(s), seat) == I.keep(D.Item, I.stock.open(D.rules.item(H.rules.items(H.host.rules(A.ref_host(s))), item), D.item.dealt_at(H.host.table(A.ref_host(s)), item), G.props.item_count(H.host.props(A.ref_host(s), seat), item), G.table.item_count(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), item)), item, _) : List<&2, D.Item>}
      pool.step(D.rules.item(H.rules.items(H.host.rules(A.ref_host(s))), item), D.item.dealt_at(H.host.table(A.ref_host(s)), item), G.props.item_count(H.host.props(A.ref_host(s), seat), item), G.table.item_count(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), item), item, G.GetItemToGrab.pool(rest, A.ref_host(s), seat))

def pool.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> {G.GetItemToGrab.pool(D.item.order(), A.ref_host(s), seat) == I.pool(s, seat) : List<&2, D.Item>}:
  pool.go_eq(D.item.order(), s, seat, shape)

# The reference host's seat entries, read through the machine's per-seat
# readers. Under Shape, entries.eq rewrites the host's entries to this form,
# so a reference loop over entries becomes a loop over the table's seats.

def lens.props(+s: S.State, +seat: D.Seat) -> H.Props:
  +players : S.Players = S.state.players(s)
  +grabs : S.Grabs = S.state.grabs(s)
  +jam : S.Jam = Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(players), seat), S.Free{})
  H.Props{I.seat.health(players, seat), S.jam.jammed(jam), A.jam.checked(jam), Q.value.or(U32, D.ring.get(U32, S.players.cash(players), seat), 0), I.seat.slots(players, seat), I.seat.grabbing(grabs, seat), I.seat.holding(grabs, seat), A.turn.held(A.turn.holder(S.state.phase(s)), seat)}

def lens.entries(seats: List<&2, D.Seat>, +s: S.State) -> List<&2, D.At<&2, H.Props>>:
  match seats:
    case Nil{}:
      Nil{}
    case +seat <> rest:
      D.At{seat, lens.props(s, seat)} <> lens.entries(rest, s)

def entries.claim(+s: S.State) -> Type:
  {lens.entries(D.table.seats(S.world.table(S.state.world(s))), s) == D.ring.entries(H.Props, H.host.seats(A.ref_host(s))) : List<&2, D.At<&2, H.Props>>}

def entries.eq(+s: S.State, +shape: A.Shape(s)) -> entries.claim(s):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(entries.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(entries.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(entries.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(entries.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(entries.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(entries.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.three_four(e_players))

def and_cong(+a: Bool, +a2: Bool, +b: Bool, +b2: Bool, ea: {a == a2 : Bool}, eb: {b == b2 : Bool}) -> {Bool.and(a, b) == Bool.and(a2, b2) : Bool}:
  %ea : {Bool.and(a, b) == Bool.and(_, b2) : Bool}
  %eb : {Bool.and(a, b) == Bool.and(a, _) : Bool}
  {==}

def or_cong(+a: Bool, +a2: Bool, +b: Bool, +b2: Bool, ea: {a == a2 : Bool}, eb: {b == b2 : Bool}) -> {Bool.or(a, b) == Bool.or(a2, b2) : Bool}:
  %ea : {Bool.or(a, b) == Bool.or(_, b2) : Bool}
  %eb : {Bool.or(a, b) == Bool.or(a, _) : Bool}
  {==}

def nonempty.eq(+xs: List<&2, D.Item>) -> {G.nonempty(D.Item, xs) == I.has_items(xs) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> rest:
      {==}

# A pool's emptiness, the reference's reading against the machine's.
def empty.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> {Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), A.ref_host(s), seat))) == Bool.not(I.has_items(I.pool(s, seat))) : Bool}:
  %pool.eq(s, seat, shape) : {Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), A.ref_host(s), seat))) == Bool.not(I.has_items(_)) : Bool}
  %nonempty.eq(G.GetItemToGrab.pool(D.item.order(), A.ref_host(s), seat)) : {Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), A.ref_host(s), seat))) == Bool.not(_) : Bool}
  {==}

# L6. Completion: every seat stopped grabbing, or every pool is empty.

def ended.claim(+s: S.State) -> Type:
  {RI.all_ended(D.ring.entries(H.Props, H.host.seats(A.ref_host(s)))) == I.finish.ended(D.ring.entries(Bool, S.grabs.grabbing(S.state.grabs(s)))) : Bool}

def ended.eq(+s: S.State, +shape: A.Shape(s)) -> ended.claim(s):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}), clash.three_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}), clash.four_two(e_grabbing))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}), clash.two_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}), clash.four_three(e_grabbing))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}), clash.two_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(ended.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}), clash.three_four(e_grabbing))

def all_empty.seats(+seats: List<&2, D.Seat>, +s: S.State, +shape: A.Shape(s)) -> {RI.all_empty(lens.entries(seats, s), A.ref_host(s)) == I.finish.empty(seats, s) : Bool}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> +rest:
      and_cong(Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), A.ref_host(s), seat))), Bool.not(I.has_items(I.pool(s, seat))), RI.all_empty(lens.entries(rest, s), A.ref_host(s)), I.finish.empty(rest, s), empty.eq(s, seat, shape), all_empty.seats(rest, s, shape))

def all_empty.eq(+s: S.State, +shape: A.Shape(s)) -> {RI.all_empty(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s)) == I.finish.empty(D.table.seats(S.world.table(S.state.world(s))), s) : Bool}:
  %entries.eq(s, shape) : {RI.all_empty(_, A.ref_host(s)) == I.finish.empty(D.table.seats(S.world.table(S.state.world(s))), s) : Bool}
  all_empty.seats(D.table.seats(S.world.table(S.state.world(s))), s, shape)

def finished.eq(+s: S.State, +shape: A.Shape(s)) -> {RI.CheckIfItemGrabbingFinishedForAllUsers(A.ref_host(s)) == I.finished(s) : Bool}:
  or_cong(RI.all_ended(D.ring.entries(H.Props, H.host.seats(A.ref_host(s)))), I.finish.ended(D.ring.entries(Bool, S.grabs.grabbing(S.state.grabs(s)))), RI.all_empty(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s)), I.finish.empty(D.table.seats(S.world.table(S.state.world(s))), s), ended.eq(s, shape), all_empty.eq(s, shape))

# L5. IsPlacingLastItem.

def occupied.list(+xs: List<&2, Maybe<&2, D.Item>>) -> {RI.occupied(xs) == I.occupied(xs) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case None{} <> +rest:
      occupied.list(rest)
    case Some{x} <> +rest:
      Equal.cong(Nat, Nat, n => 1n+n, RI.occupied(rest), I.occupied(rest), occupied.list(rest))

def occupied.slots(+sl: D.Slots) -> {RI.occupied(G.slots.list(sl)) == I.occupied(I.slots.items(sl)) : Nat}:
  match sl:
    case D.Slots{a, b, c, d, e, f, g, h}:
      occupied.list([a, b, c, d, e, f, g, h])

def last.parts(+pool_r: List<&2, D.Item>, +pool_m: List<&2, D.Item>, +sl: D.Slots, +n: Nat, +amount: Nat, +empty: {Bool.not(G.nonempty(D.Item, pool_r)) == Bool.not(I.has_items(pool_m)) : Bool}) -> {Bool.or(Bool.not(G.nonempty(D.Item, pool_r)), Bool.or(Nat.is_eq(1n+RI.occupied(G.slots.list(sl)), 8n), Bool.not(Nat.is_lt(n, amount)))) == Bool.or(Bool.not(I.has_items(pool_m)), Bool.or(Nat.is_eq(1n+I.occupied(I.slots.items(sl)), 8n), Bool.not(Nat.is_lt(n, amount)))) : Bool}:
  %occupied.slots(sl) : {Bool.or(Bool.not(G.nonempty(D.Item, pool_r)), Bool.or(Nat.is_eq(1n+RI.occupied(G.slots.list(sl)), 8n), Bool.not(Nat.is_lt(n, amount)))) == Bool.or(Bool.not(I.has_items(pool_m)), Bool.or(Nat.is_eq(1n+_, 8n), Bool.not(Nat.is_lt(n, amount)))) : Bool}
  %empty : {Bool.or(Bool.not(G.nonempty(D.Item, pool_r)), Bool.or(Nat.is_eq(1n+RI.occupied(G.slots.list(sl)), 8n), Bool.not(Nat.is_lt(n, amount)))) == Bool.or(_, Bool.or(Nat.is_eq(1n+RI.occupied(G.slots.list(sl)), 8n), Bool.not(Nat.is_lt(n, amount)))) : Bool}
  {==}

def last.claim(+s: S.State, +seat: D.Seat) -> Type:
  {RI.IsPlacingLastItem(A.ref_host(s), seat) == I.placing.last(s, seat) : Bool}

def last.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> last.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} D.Seat0{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}), D.Seat0{}), I.pool(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, D.Seat0{}), D.slots.empty(), 0n, amount, empty.eq(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, D.Seat0{}, shape))
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} D.Seat1{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}), D.Seat1{}), I.pool(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, D.Seat1{}), s1, n1, amount, empty.eq(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, D.Seat1{}, shape))
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} D.Seat2{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}), D.Seat2{}), I.pool(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, D.Seat2{}), D.slots.empty(), 0n, amount, empty.eq(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, D.Seat2{}, shape))
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} D.Seat3{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}), D.Seat3{}), I.pool(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, D.Seat3{}), s3, n3, amount, empty.eq(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, D.Seat3{}, shape))
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, seat), clash.three_two(e_granted))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, seat), clash.four_two(e_granted))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} D.Seat0{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}), D.Seat0{}), I.pool(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, D.Seat0{}), s0, n0, amount, empty.eq(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, D.Seat0{}, shape))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} D.Seat1{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}), D.Seat1{}), I.pool(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, D.Seat1{}), s1, n1, amount, empty.eq(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, D.Seat1{}, shape))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} D.Seat2{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}), D.Seat2{}), I.pool(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, D.Seat2{}), s2, n2, amount, empty.eq(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, D.Seat2{}, shape))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} D.Seat3{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}), D.Seat3{}), I.pool(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, D.Seat3{}), D.slots.empty(), 0n, amount, empty.eq(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, D.Seat3{}, shape))
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, seat), clash.two_three(e_granted))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, seat), clash.four_three(e_granted))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} D.Seat0{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}), D.Seat0{}), I.pool(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, D.Seat0{}), s0, n0, amount, empty.eq(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, D.Seat0{}, shape))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} D.Seat1{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}), D.Seat1{}), I.pool(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, D.Seat1{}), s1, n1, amount, empty.eq(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, D.Seat1{}, shape))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} D.Seat2{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}), D.Seat2{}), I.pool(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, D.Seat2{}), s2, n2, amount, empty.eq(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, D.Seat2{}, shape))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} D.Seat3{}:
          last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}), D.Seat3{}), I.pool(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, D.Seat3{}), s3, n3, amount, empty.eq(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, D.Seat3{}, shape))
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, seat), clash.two_four(e_granted))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(last.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, seat), clash.three_four(e_granted))

# L7. The noneligible pass: empty-handed grabbers with an empty pool, other
# than the placing seat.

def ring_put_keep(+b: Bool, +x: D.Seat, +rest: List<&2, D.Seat>) -> {G.turn_ring.put(b, x, rest) == I.keep(D.Seat, b, x, rest) : List<&2, D.Seat>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def stalled.cell(+g: Bool, +o: Maybe<&2, D.Item>, +hp: Nat, +jm: Bool, +ck: Bool, +c: U32, +sl: D.Slots, +t: Bool, +seat: D.Seat, +placing: D.Seat, +h: H.Host, +rest: List<&2, D.At<&2, H.Props>>, +pool_m: List<&2, D.Item>, +rest_m: List<&2, D.Seat>, +empty: {Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), h, seat))) == Bool.not(I.has_items(pool_m)) : Bool}, +more: {RI.GetSocketArrayToEndItemGrabbingOn(rest, h, placing) == rest_m : List<&2, D.Seat>}) -> {RI.GetSocketArrayToEndItemGrabbingOn(D.At{seat, H.Props{hp, jm, ck, c, sl, g, o, t}} <> rest, h, placing) == I.keep(D.Seat, Bool.and(g, Bool.and(I.is_none(o), Bool.and(Bool.not(D.seat.eq(seat, placing)), Bool.not(I.has_items(pool_m))))), seat, rest_m) : List<&2, D.Seat>}:
  match g o:
    case True{} None{}:
      %empty : {G.turn_ring.put(Bool.and(Bool.not(D.seat.eq(seat, placing)), Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), h, seat)))), seat, RI.GetSocketArrayToEndItemGrabbingOn(rest, h, placing)) == I.keep(D.Seat, Bool.and(Bool.not(D.seat.eq(seat, placing)), _), seat, rest_m) : List<&2, D.Seat>}
      %more : {G.turn_ring.put(Bool.and(Bool.not(D.seat.eq(seat, placing)), Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), h, seat)))), seat, RI.GetSocketArrayToEndItemGrabbingOn(rest, h, placing)) == I.keep(D.Seat, Bool.and(Bool.not(D.seat.eq(seat, placing)), Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), h, seat)))), seat, _) : List<&2, D.Seat>}
      ring_put_keep(Bool.and(Bool.not(D.seat.eq(seat, placing)), Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), h, seat)))), seat, RI.GetSocketArrayToEndItemGrabbingOn(rest, h, placing))
    case True{} Some{item}:
      more
    case False{} None{}:
      more
    case False{} Some{item}:
      more

def stalled.seats(+seats: List<&2, D.Seat>, +s: S.State, +placing: D.Seat, +shape: A.Shape(s)) -> {RI.GetSocketArrayToEndItemGrabbingOn(lens.entries(seats, s), A.ref_host(s), placing) == I.stalled(seats, s, placing) : List<&2, D.Seat>}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> +rest:
      stalled.cell(I.seat.grabbing(S.state.grabs(s), seat), I.seat.holding(S.state.grabs(s), seat), I.seat.health(S.state.players(s), seat), S.jam.jammed(Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{})), A.jam.checked(Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{})), Q.value.or(U32, D.ring.get(U32, S.players.cash(S.state.players(s)), seat), 0), I.seat.slots(S.state.players(s), seat), A.turn.held(A.turn.holder(S.state.phase(s)), seat), seat, placing, A.ref_host(s), lens.entries(rest, s), I.pool(s, seat), I.stalled(rest, s, placing), empty.eq(s, seat, shape), stalled.seats(rest, s, placing, shape))

def stalled.eq(+s: S.State, +placing: D.Seat, +shape: A.Shape(s)) -> {RI.GetSocketArrayToEndItemGrabbingOn(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), placing) == I.stalled.seats(s, placing) : List<&2, D.Seat>}:
  %entries.eq(s, shape) : {RI.GetSocketArrayToEndItemGrabbingOn(_, A.ref_host(s), placing) == I.stalled.seats(s, placing) : List<&2, D.Seat>}
  stalled.seats(D.table.seats(S.world.table(S.state.world(s))), s, placing, shape)

# L10. Whether anyone still holds an item.

def holding.entries(seats: List<&2, D.Seat>, +grabs: S.Grabs) -> List<&2, D.At<&2, Maybe<&2, D.Item>>>:
  match seats:
    case Nil{}:
      Nil{}
    case +seat <> rest:
      D.At{seat, I.seat.holding(grabs, seat)} <> holding.entries(rest, grabs)

def holders.cell(+o: Maybe<&2, D.Item>, +hp: Nat, +jm: Bool, +ck: Bool, +c: U32, +sl: D.Slots, +g: Bool, +t: Bool, +seat: D.Seat, +rest: List<&2, D.At<&2, H.Props>>, +rest_m: List<&2, D.At<&2, Maybe<&2, D.Item>>>, +more: {RI.holders(rest) == I.holders(rest_m) : Bool}) -> {RI.holders(D.At{seat, H.Props{hp, jm, ck, c, sl, g, o, t}} <> rest) == I.holders(D.At{seat, o} <> rest_m) : Bool}:
  match o:
    case None{}:
      more
    case Some{item}:
      {==}

def holders.seats(+seats: List<&2, D.Seat>, +s: S.State) -> {RI.holders(lens.entries(seats, s)) == I.holders(holding.entries(seats, S.state.grabs(s))) : Bool}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> +rest:
      holders.cell(I.seat.holding(S.state.grabs(s), seat), I.seat.health(S.state.players(s), seat), S.jam.jammed(Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{})), A.jam.checked(Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{})), Q.value.or(U32, D.ring.get(U32, S.players.cash(S.state.players(s)), seat), 0), I.seat.slots(S.state.players(s), seat), I.seat.grabbing(S.state.grabs(s), seat), A.turn.held(A.turn.holder(S.state.phase(s)), seat), seat, lens.entries(rest, s), holding.entries(rest, S.state.grabs(s)), holders.seats(rest, s))

def holding.claim(+s: S.State) -> Type:
  {holding.entries(D.table.seats(S.world.table(S.state.world(s))), S.state.grabs(s)) == D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(S.state.grabs(s))) : List<&2, D.At<&2, Maybe<&2, D.Item>>>}

def holding.eq(+s: S.State, +shape: A.Shape(s)) -> holding.claim(s):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table grabs:
        case D.TwoSeats{} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake}:
          {==}
        case D.TwoSeats{} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(holding.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}), clash.three_two(e_holding))
        case D.TwoSeats{} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(holding.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}), clash.four_two(e_holding))
        case D.ThreeSeats{} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake}:
          {==}
        case D.ThreeSeats{} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(holding.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}), clash.two_three(e_holding))
        case D.ThreeSeats{} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(holding.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}), clash.four_three(e_holding))
        case D.FourSeats{} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake}:
          {==}
        case D.FourSeats{} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(holding.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}), clash.two_four(e_holding))
        case D.FourSeats{} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(holding.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}), clash.three_four(e_holding))

def holders.eq(+s: S.State, +shape: A.Shape(s)) -> {RI.holders(D.ring.entries(H.Props, H.host.seats(A.ref_host(s)))) == I.holders(D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(S.state.grabs(s)))) : Bool}:
  %entries.eq(s, shape) : {RI.holders(_) == I.holders(D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(S.state.grabs(s)))) : Bool}
  %holding.eq(s, shape) : {RI.holders(lens.entries(D.table.seats(S.world.table(S.state.world(s))), s)) == I.holders(_) : Bool}
  holders.seats(D.table.seats(S.world.table(S.state.world(s))), s)

# L3. The grab menus: the reference renders each seat's menu from its props
# and progress; the machine stores options and renders them.

def place.cell(+found: Maybe<&2, D.Item>, +slot: D.Slot, +rest: List<&2, D.Move>, +rest_m: List<&2, S.GrabOption>, +more: {rest == I.grab.moves(rest_m) : List<&2, D.Move>}) -> {RI.place_moves.here(found, slot, rest) == I.grab.moves(I.puts.here(found, slot, rest_m)) : List<&2, D.Move>}:
  match found:
    case None{}:
      Equal.cong(List<&2, D.Move>, List<&2, D.Move>, xs => D.Place{slot} <> xs, rest, I.grab.moves(rest_m), more)
    case Some{item}:
      more

def place.list(+slots: List<&2, D.Slot>, +inventory: D.Slots) -> {RI.place_moves(slots, inventory) == I.grab.moves(I.puts(slots, inventory)) : List<&2, D.Move>}:
  match slots:
    case Nil{}:
      {==}
    case +slot <> +rest:
      place.cell(D.slots.get(inventory, slot), slot, RI.place_moves(rest, inventory), I.puts(rest, inventory), place.list(rest, inventory))

def menu.cell(+g: Bool, +o: Maybe<&2, D.Item>, +i: Bool, +d: Bool, +sl: D.Slots, +hp: Nat, +jm: Bool, +ck: Bool, +c: U32, +t: Bool, +n: Nat) -> {R.grab_menu(H.Props{hp, jm, ck, c, sl, g, o, t}, H.GrabProgress{n, i}, d) == I.grab.moves(I.grab.offer(g, o, Bool.and(i, d), sl)) : List<&2, D.Move>}:
  match g o i d:
    case True{} Some{x} i True{}:
      place.list(I.slot.order(), sl)
    case True{} Some{x} i False{}:
      place.list(I.slot.order(), sl)
    case True{} None{} True{} True{}:
      {==}
    case True{} None{} True{} False{}:
      {==}
    case True{} None{} False{} True{}:
      {==}
    case True{} None{} False{} False{}:
      {==}
    case False{} o i True{}:
      {==}
    case False{} o i False{}:
      {==}

def menu.claim(+s: S.State, +seat: D.Seat) -> Type:
  {R.grab_menu(lens.props(s, seat), H.host.progress(A.ref_host(s), seat), H.host.distributing(A.ref_host(s))) == I.grab.moves(I.grab.offer(I.seat.grabbing(S.state.grabs(s), seat), I.seat.holding(S.state.grabs(s), seat), Bool.and(I.seat.intake(S.state.grabs(s), seat), S.grabs.distributing(S.state.grabs(s))), I.seat.slots(S.state.players(s), seat))) : List<&2, D.Move>}

def menu.at(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> menu.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat0{}:
          menu.cell(False{}, None{}, False{}, dist, D.slots.empty(), 100n, False{}, False{}, 0, A.turn.held(A.turn.holder(phase), D.Seat0{}), 0n)
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat1{}:
          menu.cell(g1, o1, i1, dist, s1, h1, S.jam.jammed(j1), A.jam.checked(j1), c1, A.turn.held(A.turn.holder(phase), D.Seat1{}), n1)
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat2{}:
          menu.cell(False{}, None{}, False{}, dist, D.slots.empty(), 100n, False{}, False{}, 0, A.turn.held(A.turn.holder(phase), D.Seat2{}), 0n)
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat3{}:
          menu.cell(g3, o3, i3, dist, s3, h3, S.jam.jammed(j3), A.jam.checked(j3), c3, A.turn.held(A.turn.holder(phase), D.Seat3{}), n3)
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat), clash.three_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat), clash.four_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat), clash.three_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat), clash.four_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, seat), clash.three_two(e_granted))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, seat), clash.four_two(e_granted))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat), clash.three_two(e_intake))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat), clash.four_two(e_intake))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat0{}:
          menu.cell(g0, o0, i0, dist, s0, h0, S.jam.jammed(j0), A.jam.checked(j0), c0, A.turn.held(A.turn.holder(phase), D.Seat0{}), n0)
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat1{}:
          menu.cell(g1, o1, i1, dist, s1, h1, S.jam.jammed(j1), A.jam.checked(j1), c1, A.turn.held(A.turn.holder(phase), D.Seat1{}), n1)
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat2{}:
          menu.cell(g2, o2, i2, dist, s2, h2, S.jam.jammed(j2), A.jam.checked(j2), c2, A.turn.held(A.turn.holder(phase), D.Seat2{}), n2)
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat3{}:
          menu.cell(False{}, None{}, False{}, dist, D.slots.empty(), 100n, False{}, False{}, 0, A.turn.held(A.turn.holder(phase), D.Seat3{}), 0n)
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat), clash.two_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat), clash.four_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat), clash.two_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat), clash.four_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, seat), clash.two_three(e_granted))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, seat), clash.four_three(e_granted))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat), clash.two_three(e_intake))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat), clash.four_three(e_intake))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat0{}:
          menu.cell(g0, o0, i0, dist, s0, h0, S.jam.jammed(j0), A.jam.checked(j0), c0, A.turn.held(A.turn.holder(phase), D.Seat0{}), n0)
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat1{}:
          menu.cell(g1, o1, i1, dist, s1, h1, S.jam.jammed(j1), A.jam.checked(j1), c1, A.turn.held(A.turn.holder(phase), D.Seat1{}), n1)
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat2{}:
          menu.cell(g2, o2, i2, dist, s2, h2, S.jam.jammed(j2), A.jam.checked(j2), c2, A.turn.held(A.turn.holder(phase), D.Seat2{}), n2)
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat3{}:
          menu.cell(g3, o3, i3, dist, s3, h3, S.jam.jammed(j3), A.jam.checked(j3), c3, A.turn.held(A.turn.holder(phase), D.Seat3{}), n3)
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat), clash.two_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat), clash.three_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat), clash.two_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat), clash.three_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, seat), clash.two_four(e_granted))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, seat), clash.three_four(e_granted))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat), clash.two_four(e_intake))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(menu.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat), clash.three_four(e_intake))

def menus.set(+menus: D.Ring<&2, List<&2, S.GrabOption>>, +seat: D.Seat, +x: List<&2, S.GrabOption>) -> {D.ring.set(List<&2, D.Move>, I.grab.menus(menus), seat, I.grab.moves(x)) == I.grab.menus(D.ring.set(List<&2, S.GrabOption>, menus, seat, x)) : D.Ring<&2, List<&2, D.Move>>}:
  match menus seat:
    case D.Duo{m1, m3} D.Seat0{}:
      {==}
    case D.Duo{m1, m3} D.Seat1{}:
      {==}
    case D.Duo{m1, m3} D.Seat2{}:
      {==}
    case D.Duo{m1, m3} D.Seat3{}:
      {==}
    case D.Trio{m0, m1, m2} D.Seat0{}:
      {==}
    case D.Trio{m0, m1, m2} D.Seat1{}:
      {==}
    case D.Trio{m0, m1, m2} D.Seat2{}:
      {==}
    case D.Trio{m0, m1, m2} D.Seat3{}:
      {==}
    case D.Quad{m0, m1, m2, m3} D.Seat0{}:
      {==}
    case D.Quad{m0, m1, m2, m3} D.Seat1{}:
      {==}
    case D.Quad{m0, m1, m2, m3} D.Seat2{}:
      {==}
    case D.Quad{m0, m1, m2, m3} D.Seat3{}:
      {==}

def menus.fill(+table: D.Table) -> {I.grab.menus(D.ring.fill(List<&2, S.GrabOption>, table, Nil{})) == D.ring.fill(List<&2, D.Move>, table, Nil{}) : D.Ring<&2, List<&2, D.Move>>}:
  match table:
    case D.TwoSeats{}:
      {==}
    case D.ThreeSeats{}:
      {==}
    case D.FourSeats{}:
      {==}

def menus.seats(+seats: List<&2, D.Seat>, +s: S.State, +needs: D.Ring<&2, List<&2, S.GrabOption>>, +shape: A.Shape(s)) -> {R.grab_menus(lens.entries(seats, s), A.ref_host(s), I.grab.menus(needs)) == I.grab.menus(I.grab.needs.go(seats, S.state.players(s), S.state.grabs(s), needs)) : D.Ring<&2, List<&2, D.Move>>}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> +rest:
      +menu_r : List<&2, D.Move> = R.grab_menu(lens.props(s, seat), H.host.progress(A.ref_host(s), seat), H.host.distributing(A.ref_host(s)))
      +offer : List<&2, S.GrabOption> = I.grab.offer(I.seat.grabbing(S.state.grabs(s), seat), I.seat.holding(S.state.grabs(s), seat), Bool.and(I.seat.intake(S.state.grabs(s), seat), S.grabs.distributing(S.state.grabs(s))), I.seat.slots(S.state.players(s), seat))
      +next : D.Ring<&2, List<&2, S.GrabOption>> = D.ring.set(List<&2, S.GrabOption>, needs, seat, offer)
      +written : {D.ring.set(List<&2, D.Move>, I.grab.menus(needs), seat, menu_r) == I.grab.menus(next) : D.Ring<&2, List<&2, D.Move>>} = Equal.trans(D.Ring<&2, List<&2, D.Move>>, D.ring.set(List<&2, D.Move>, I.grab.menus(needs), seat, menu_r), D.ring.set(List<&2, D.Move>, I.grab.menus(needs), seat, I.grab.moves(offer)), I.grab.menus(next), Equal.cong(List<&2, D.Move>, D.Ring<&2, List<&2, D.Move>>, x => D.ring.set(List<&2, D.Move>, I.grab.menus(needs), seat, x), menu_r, I.grab.moves(offer), menu.at(s, seat, shape)), menus.set(needs, seat, offer))
      Equal.trans(D.Ring<&2, List<&2, D.Move>>, R.grab_menus(lens.entries(rest, s), A.ref_host(s), D.ring.set(List<&2, D.Move>, I.grab.menus(needs), seat, menu_r)), R.grab_menus(lens.entries(rest, s), A.ref_host(s), I.grab.menus(next)), I.grab.menus(I.grab.needs.go(rest, S.state.players(s), S.state.grabs(s), next)), Equal.cong(D.Ring<&2, List<&2, D.Move>>, D.Ring<&2, List<&2, D.Move>>, m => R.grab_menus(lens.entries(rest, s), A.ref_host(s), m), D.ring.set(List<&2, D.Move>, I.grab.menus(needs), seat, menu_r), I.grab.menus(next), written), menus.seats(rest, s, next, shape))

def menus.eq(+s: S.State, +shape: A.Shape(s)) -> {R.grab_menus(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), D.ring.fill(List<&2, D.Move>, H.host.table(A.ref_host(s)), Nil{})) == I.grab.menus(I.grab.needs(s)) : D.Ring<&2, List<&2, D.Move>>}:
  %entries.eq(s, shape) : {R.grab_menus(_, A.ref_host(s), D.ring.fill(List<&2, D.Move>, H.host.table(A.ref_host(s)), Nil{})) == I.grab.menus(I.grab.needs(s)) : D.Ring<&2, List<&2, D.Move>>}
  %Equal.sym(D.Table, H.host.table(A.ref_host(s)), S.world.table(S.state.world(s)), table.eq(s)) : {R.grab_menus(lens.entries(D.table.seats(S.world.table(S.state.world(s))), s), A.ref_host(s), D.ring.fill(List<&2, D.Move>, _, Nil{})) == I.grab.menus(I.grab.needs(s)) : D.Ring<&2, List<&2, D.Move>>}
  %menus.fill(S.world.table(S.state.world(s))) : {R.grab_menus(lens.entries(D.table.seats(S.world.table(S.state.world(s))), s), A.ref_host(s), _) == I.grab.menus(I.grab.needs(s)) : D.Ring<&2, List<&2, D.Move>>}
  menus.seats(D.table.seats(S.world.table(S.state.world(s))), s, D.ring.fill(List<&2, S.GrabOption>, S.world.table(S.state.world(s)), Nil{}), shape)

# L4. A resolved grab choice names the option the machine selects. The
# machine reads needs[seat][index]; the reference reads the rendered move.

# The option index names in a seat's options, for the rendered move.
def SelectedIn(+options: List<&2, S.GrabOption>, +index: Nat, +move: D.Move) -> Data:
  match move:
    case D.Grab{}:
      {I.grab.nth(options, index) == Some{S.TakeItem{}} : Maybe<&2, S.GrabOption>}
    case D.Place{+slot}:
      {I.grab.nth(options, index) == Some{S.PutAt{slot}} : Maybe<&2, S.GrabOption>}
    case _:
      Empty

def Selected(+needs: D.Ring<&2, List<&2, S.GrabOption>>, +choice: D.Choice) -> Data:
  match choice:
    case D.Choice{+seat, +index, +move}:
      SelectedIn(Q.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs, seat), Nil{}), index, move)

def MaybeSelected(+needs: D.Ring<&2, List<&2, S.GrabOption>>, +picked: Maybe<&2, D.Choice>) -> Data:
  match picked:
    case None{}:
      Unit
    case Some{+choice}:
      Selected(needs, choice)

def AllSelected(+needs: D.Ring<&2, List<&2, S.GrabOption>>, +choices: List<&2, D.Choice>) -> Data:
  match choices:
    case Nil{}:
      Unit
    case +choice <> +rest:
      Sigma<&2, &2, Selected(needs, choice), _ => AllSelected(needs, rest)>

def all.append(+needs: D.Ring<&2, List<&2, S.GrabOption>>, +xs: List<&2, D.Choice>, +ys: List<&2, D.Choice>, +ax: AllSelected(needs, xs), +ay: AllSelected(needs, ys)) -> AllSelected(needs, List.append(&2, D.Choice, xs, ys)):
  match xs:
    case Nil{}:
      ay
    case +x <> +rest:
      match ax:
        case Tuple{+here, +more}:
          (here, all.append(needs, rest, ys, more, ay))

def all.nth(+needs: D.Ring<&2, List<&2, S.GrabOption>>, +xs: List<&2, D.Choice>, +n: Nat, +ax: AllSelected(needs, xs)) -> MaybeSelected(needs, D.choices.nth(xs, n)):
  match xs n:
    case Nil{} n:
      Unit{}
    case +x <> Nil{} 0n:
      match ax:
        case Tuple{+here, _}:
          here
    case +x <> Nil{} 1n+k:
      match ax:
        case Tuple{+here, _}:
          here
    case +x <> +y <> +rest 0n:
      match ax:
        case Tuple{+here, _}:
          here
    case +x <> +y <> +rest 1n+k:
      match ax:
        case Tuple{_, +more}:
          all.nth(needs, y <> rest, k, more)

# The options from index i on.
def skip(+i: Nat, +xs: List<&2, S.GrabOption>) -> List<&2, S.GrabOption>:
  match i:
    case 0n:
      xs
    case 1n+k:
      match xs:
        case Nil{}:
          Nil{}
        case x <> +rest:
          skip(k, rest)

def list.is_nil(xs: List<&2, S.GrabOption>) -> Type:
  match xs:
    case Nil{}:
      Unit
    case _:
      Empty

def clash.nil_cons(+x: S.GrabOption, +rest: List<&2, S.GrabOption>, e: {Nil{} == x <> rest : List<&2, S.GrabOption>}) -> Empty:
  %e : list.is_nil(_)
  Unit{}

def skip.head(+xs: List<&2, S.GrabOption>, +i: Nat, +o: S.GrabOption, +os: List<&2, S.GrabOption>, +e: {skip(i, xs) == o <> os : List<&2, S.GrabOption>}) -> {I.grab.nth(xs, i) == Some{o} : Maybe<&2, S.GrabOption>}:
  match xs i:
    case Nil{} 0n:
      absurd({I.grab.nth(Nil{}, 0n) == Some{o} : Maybe<&2, S.GrabOption>}, clash.nil_cons(o, os, e))
    case +x <> +rest 0n:
      %Equal.sym(List<&2, S.GrabOption>, x <> rest, o <> os, e) : {I.grab.nth(_, 0n) == Some{o} : Maybe<&2, S.GrabOption>}
      {==}
    case Nil{} 1n+k:
      absurd({I.grab.nth(Nil{}, 1n+k) == Some{o} : Maybe<&2, S.GrabOption>}, clash.nil_cons(o, os, e))
    case x <> +rest 1n+k:
      skip.head(rest, k, o, os, e)

def skip.tail(+xs: List<&2, S.GrabOption>, +i: Nat, +o: S.GrabOption, +os: List<&2, S.GrabOption>, +e: {skip(i, xs) == o <> os : List<&2, S.GrabOption>}) -> {skip(1n+i, xs) == os : List<&2, S.GrabOption>}:
  match xs i:
    case Nil{} 0n:
      absurd({skip(1n, Nil{}) == os : List<&2, S.GrabOption>}, clash.nil_cons(o, os, e))
    case +x <> +rest 0n:
      %Equal.sym(List<&2, S.GrabOption>, x <> rest, o <> os, e) : {skip(1n, _) == os : List<&2, S.GrabOption>}
      {==}
    case Nil{} 1n+k:
      absurd({skip(2n+k, Nil{}) == os : List<&2, S.GrabOption>}, clash.nil_cons(o, os, e))
    case x <> +rest 1n+k:
      skip.tail(rest, k, o, os, e)

def all.of(+needs: D.Ring<&2, List<&2, S.GrabOption>>, +seat: D.Seat, +opts: List<&2, S.GrabOption>, +i: Nat, +suffix: {skip(i, Q.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs, seat), Nil{})) == opts : List<&2, S.GrabOption>}) -> AllSelected(needs, D.choices.of(I.grab.moves(opts), seat, i)):
  match opts:
    case Nil{}:
      Unit{}
    case S.TakeItem{} <> +os:
      (skip.head(Q.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs, seat), Nil{}), i, S.TakeItem{}, os, suffix), all.of(needs, seat, os, 1n+i, skip.tail(Q.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs, seat), Nil{}), i, S.TakeItem{}, os, suffix)))
    case S.PutAt{+slot} <> +os:
      (skip.head(Q.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs, seat), Nil{}), i, S.PutAt{slot}, os, suffix), all.of(needs, seat, os, 1n+i, skip.tail(Q.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs, seat), Nil{}), i, S.PutAt{slot}, os, suffix)))

def all.flatten(+needs: D.Ring<&2, List<&2, S.GrabOption>>) -> AllSelected(needs, D.choices.flatten(D.ring.entries(List<&2, D.Move>, I.grab.menus(needs)))):
  match needs:
    case D.Duo{+a, +b}:
      all.append(D.Duo{a, b}, D.choices.of(I.grab.moves(a), D.Seat1{}, 0n), List.append(&2, D.Choice, D.choices.of(I.grab.moves(b), D.Seat3{}, 0n), Nil{}), all.of(D.Duo{a, b}, D.Seat1{}, a, 0n, {==}), all.append(D.Duo{a, b}, D.choices.of(I.grab.moves(b), D.Seat3{}, 0n), Nil{}, all.of(D.Duo{a, b}, D.Seat3{}, b, 0n, {==}), Unit{}))
    case D.Trio{+a, +b, +c}:
      all.append(D.Trio{a, b, c}, D.choices.of(I.grab.moves(a), D.Seat0{}, 0n), List.append(&2, D.Choice, D.choices.of(I.grab.moves(b), D.Seat1{}, 0n), List.append(&2, D.Choice, D.choices.of(I.grab.moves(c), D.Seat2{}, 0n), Nil{})), all.of(D.Trio{a, b, c}, D.Seat0{}, a, 0n, {==}), all.append(D.Trio{a, b, c}, D.choices.of(I.grab.moves(b), D.Seat1{}, 0n), List.append(&2, D.Choice, D.choices.of(I.grab.moves(c), D.Seat2{}, 0n), Nil{}), all.of(D.Trio{a, b, c}, D.Seat1{}, b, 0n, {==}), all.append(D.Trio{a, b, c}, D.choices.of(I.grab.moves(c), D.Seat2{}, 0n), Nil{}, all.of(D.Trio{a, b, c}, D.Seat2{}, c, 0n, {==}), Unit{})))
    case D.Quad{+a, +b, +c, +d}:
      all.append(D.Quad{a, b, c, d}, D.choices.of(I.grab.moves(a), D.Seat0{}, 0n), List.append(&2, D.Choice, D.choices.of(I.grab.moves(b), D.Seat1{}, 0n), List.append(&2, D.Choice, D.choices.of(I.grab.moves(c), D.Seat2{}, 0n), List.append(&2, D.Choice, D.choices.of(I.grab.moves(d), D.Seat3{}, 0n), Nil{}))), all.of(D.Quad{a, b, c, d}, D.Seat0{}, a, 0n, {==}), all.append(D.Quad{a, b, c, d}, D.choices.of(I.grab.moves(b), D.Seat1{}, 0n), List.append(&2, D.Choice, D.choices.of(I.grab.moves(c), D.Seat2{}, 0n), List.append(&2, D.Choice, D.choices.of(I.grab.moves(d), D.Seat3{}, 0n), Nil{})), all.of(D.Quad{a, b, c, d}, D.Seat1{}, b, 0n, {==}), all.append(D.Quad{a, b, c, d}, D.choices.of(I.grab.moves(c), D.Seat2{}, 0n), List.append(&2, D.Choice, D.choices.of(I.grab.moves(d), D.Seat3{}, 0n), Nil{}), all.of(D.Quad{a, b, c, d}, D.Seat2{}, c, 0n, {==}), all.append(D.Quad{a, b, c, d}, D.choices.of(I.grab.moves(d), D.Seat3{}, 0n), Nil{}, all.of(D.Quad{a, b, c, d}, D.Seat3{}, d, 0n, {==}), Unit{}))))

def sel.choose(+needs: D.Ring<&2, List<&2, S.GrabOption>>, +n: Nat) -> MaybeSelected(needs, D.choose(I.grab.menus(needs), n)):
  all.nth(needs, D.choices.flatten(D.ring.entries(List<&2, D.Move>, I.grab.menus(needs))), n, all.flatten(needs))

def maybe.is_none(m: Maybe<&2, S.GrabOption>) -> Type:
  match m:
    case None{}:
      Unit
    case _:
      Empty

def clash.none_some(+o: S.GrabOption, e: {None{} == Some{o} : Maybe<&2, S.GrabOption>}) -> Empty:
  %e : maybe.is_none(_)
  Unit{}

def maybe.is_take(m: Maybe<&2, S.GrabOption>) -> Type:
  match m:
    case Some{S.TakeItem{}}:
      Unit
    case _:
      Empty

def clash.take_put(+slot: D.Slot, e: {Some{S.TakeItem{}} == Some{S.PutAt{slot}} : Maybe<&2, S.GrabOption>}) -> Empty:
  %e : maybe.is_take(_)
  Unit{}

def maybe.is_put(m: Maybe<&2, S.GrabOption>) -> Type:
  match m:
    case Some{S.PutAt{slot}}:
      Unit
    case _:
      Empty

def clash.put_take(+slot: D.Slot, e: {Some{S.PutAt{slot}} == Some{S.TakeItem{}} : Maybe<&2, S.GrabOption>}) -> Empty:
  %e : maybe.is_put(_)
  Unit{}

# Every option of a placing seat is a PutAt.
def AllPut(+xs: List<&2, S.GrabOption>) -> Data:
  match xs:
    case Nil{}:
      Unit
    case S.PutAt{_} <> +rest:
      AllPut(rest)
    case S.TakeItem{} <> _:
      Empty

def all_put.here(+found: Maybe<&2, D.Item>, +slot: D.Slot, +rest: List<&2, S.GrabOption>, +more: AllPut(rest)) -> AllPut(I.puts.here(found, slot, rest)):
  match found:
    case None{}:
      more
    case Some{x}:
      more

def all_put.list(+slots: List<&2, D.Slot>, +inventory: D.Slots) -> AllPut(I.puts(slots, inventory)):
  match slots:
    case Nil{}:
      Unit{}
    case +slot <> +rest:
      all_put.here(D.slots.get(inventory, slot), slot, I.puts(rest, inventory), all_put.list(rest, inventory))

def all_put.no_take(+xs: List<&2, S.GrabOption>, +index: Nat, +all: AllPut(xs), e: {I.grab.nth(xs, index) == Some{S.TakeItem{}} : Maybe<&2, S.GrabOption>}) -> Empty:
  match xs index:
    case Nil{} index:
      clash.none_some(S.TakeItem{}, e)
    case S.PutAt{+slot} <> +rest 0n:
      clash.put_take(slot, e)
    case S.PutAt{+slot} <> +rest 1n+k:
      all_put.no_take(rest, k, all, e)
    case S.TakeItem{} <> +rest index:
      match all:

def intake.no_put(+open: Bool, +index: Nat, +slot: D.Slot, e: {I.grab.nth(I.grab.intake(open), index) == Some{S.PutAt{slot}} : Maybe<&2, S.GrabOption>}) -> Empty:
  match open index:
    case True{} 0n:
      clash.take_put(slot, e)
    case True{} 1n+k:
      clash.none_some(S.PutAt{slot}, e)
    case False{} index:
      clash.none_some(S.PutAt{slot}, e)

# A selected grab option passes the reference's grab check on the seat's props.
def accept.claim(+hp: Nat, +jm: Bool, +ck: Bool, +c: U32, +sl: D.Slots, +g: Bool, +o: Maybe<&2, D.Item>, +t: Bool, +move: D.Move) -> Type:
  {R.VerifyPacket.grab(H.Props{hp, jm, ck, c, sl, g, o, t}, move) == True{} : Bool}

def accept.cell(+g: Bool, +o: Maybe<&2, D.Item>, +open: Bool, +sl: D.Slots, +hp: Nat, +jm: Bool, +ck: Bool, +c: U32, +t: Bool, +index: Nat, +move: D.Move, +sel: SelectedIn(I.grab.offer(g, o, open, sl), index, move)) -> accept.claim(hp, jm, ck, c, sl, g, o, t, move):
  match g o move:
    case True{} None{} D.Grab{}:
      {==}
    case True{} None{} D.Place{+slot}:
      absurd(accept.claim(hp, jm, ck, c, sl, True{}, None{}, t, D.Place{slot}), intake.no_put(open, index, slot, sel))
    case True{} Some{+x} D.Grab{}:
      absurd(accept.claim(hp, jm, ck, c, sl, True{}, Some{x}, t, D.Grab{}), all_put.no_take(I.puts(I.slot.order(), sl), index, all_put.list(I.slot.order(), sl), sel))
    case True{} Some{x} D.Place{slot}:
      {==}
    case False{} +o D.Grab{}:
      absurd(accept.claim(hp, jm, ck, c, sl, False{}, o, t, D.Grab{}), clash.none_some(S.TakeItem{}, sel))
    case False{} +o D.Place{+slot}:
      absurd(accept.claim(hp, jm, ck, c, sl, False{}, o, t, D.Place{slot}), clash.none_some(S.PutAt{slot}, sel))
    case g o D.PickUp{}:
      match sel:
    case g o D.Shoot{target}:
      match sel:
    case g o D.UseItem{slot, item}:
      match sel:
    case g o D.JamTarget{target}:
      match sel:
    case g o D.Steal{owner, slot, item}:
      match sel:

def accept.at.claim(+s: S.State, +seat: D.Seat, +move: D.Move) -> Type:
  {R.VerifyPacket.grab(H.host.props(A.ref_host(s), seat), move) == True{} : Bool}

def accept.at(+s: S.State, +seat: D.Seat, +index: Nat, +move: D.Move, +shape: A.Shape(s), +sel: Selected(I.grab.needs(s), D.Choice{seat, index, move})) -> accept.at.claim(s, seat, move):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, D.Duo{+i1, +i3}} D.Seat0{}:
          accept.cell(False{}, None{}, False{}, D.slots.empty(), 100n, False{}, False{}, 0, False{}, index, move, sel)
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, D.Duo{+i1, +i3}} D.Seat1{}:
          accept.cell(g1, o1, Bool.and(i1, dist), s1, h1, S.jam.jammed(j1), A.jam.checked(j1), c1, A.turn.held(A.turn.holder(phase), D.Seat1{}), index, move, sel)
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, D.Duo{+i1, +i3}} D.Seat2{}:
          accept.cell(False{}, None{}, False{}, D.slots.empty(), 100n, False{}, False{}, 0, False{}, index, move, sel)
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, D.Duo{+i1, +i3}} D.Seat3{}:
          accept.cell(g3, o3, Bool.and(i3, dist), s3, h3, S.jam.jammed(j3), A.jam.checked(j3), c3, A.turn.held(A.turn.holder(phase), D.Seat3{}), index, move, sel)
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, move), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, move), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat, move), clash.three_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat, move), clash.four_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat, move), clash.three_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat, move), clash.four_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat, move), clash.three_two(e_intake))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat, move), clash.four_two(e_intake))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, D.Trio{+i0, +i1, +i2}} D.Seat0{}:
          accept.cell(g0, o0, Bool.and(i0, dist), s0, h0, S.jam.jammed(j0), A.jam.checked(j0), c0, A.turn.held(A.turn.holder(phase), D.Seat0{}), index, move, sel)
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, D.Trio{+i0, +i1, +i2}} D.Seat1{}:
          accept.cell(g1, o1, Bool.and(i1, dist), s1, h1, S.jam.jammed(j1), A.jam.checked(j1), c1, A.turn.held(A.turn.holder(phase), D.Seat1{}), index, move, sel)
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, D.Trio{+i0, +i1, +i2}} D.Seat2{}:
          accept.cell(g2, o2, Bool.and(i2, dist), s2, h2, S.jam.jammed(j2), A.jam.checked(j2), c2, A.turn.held(A.turn.holder(phase), D.Seat2{}), index, move, sel)
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, D.Trio{+i0, +i1, +i2}} D.Seat3{}:
          accept.cell(False{}, None{}, False{}, D.slots.empty(), 100n, False{}, False{}, 0, False{}, index, move, sel)
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, move), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, move), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat, move), clash.two_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat, move), clash.four_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat, move), clash.two_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat, move), clash.four_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat, move), clash.two_three(e_intake))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat, move), clash.four_three(e_intake))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat0{}:
          accept.cell(g0, o0, Bool.and(i0, dist), s0, h0, S.jam.jammed(j0), A.jam.checked(j0), c0, A.turn.held(A.turn.holder(phase), D.Seat0{}), index, move, sel)
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat1{}:
          accept.cell(g1, o1, Bool.and(i1, dist), s1, h1, S.jam.jammed(j1), A.jam.checked(j1), c1, A.turn.held(A.turn.holder(phase), D.Seat1{}), index, move, sel)
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat2{}:
          accept.cell(g2, o2, Bool.and(i2, dist), s2, h2, S.jam.jammed(j2), A.jam.checked(j2), c2, A.turn.held(A.turn.holder(phase), D.Seat2{}), index, move, sel)
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat3{}:
          accept.cell(g3, o3, Bool.and(i3, dist), s3, h3, S.jam.jammed(j3), A.jam.checked(j3), c3, A.turn.held(A.turn.holder(phase), D.Seat3{}), index, move, sel)
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, move), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, move), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat, move), clash.two_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat, move), clash.three_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat, move), clash.two_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat, move), clash.three_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat, move), clash.two_four(e_intake))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(accept.at.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat, move), clash.three_four(e_intake))

# L9. The handout's host writes, against the machine's Grabs and seat writes.

def stop.state(+s: S.State, +seat: D.Seat) -> S.State:
  S.state.set_grabs(s, I.grabs.stop_intake(S.state.grabs(s), seat))

def stop.claim(+s: S.State, +seat: D.Seat) -> Type:
  {H.host.set_progress(A.ref_host(s), seat, H.GrabProgress{RI.progress.count(H.host.progress(A.ref_host(s), seat)), False{}}) == A.ref_host(stop.state(s, seat)) : H.Host}

def stop.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> stop.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat), clash.three_two(e_intake))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat), clash.four_two(e_intake))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat), clash.two_three(e_intake))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat), clash.four_three(e_intake))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat), clash.two_four(e_intake))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(stop.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat), clash.three_four(e_intake))

def give.state(+s: S.State, +seat: D.Seat, +item: D.Item) -> S.State:
  S.state.set_grabs(s, I.grabs.give(S.state.grabs(s), seat, item))

def give.host(+h: H.Host, +seat: D.Seat, +item: D.Item) -> H.Host:
  +h : H.Host = H.host.set_props(h, seat, H.props.set_holding(H.host.props(h, seat), Some{item}))
  H.host.set_progress(h, seat, H.GrabProgress{1n+RI.progress.count(H.host.progress(h, seat)), False{}})

def give.claim(+s: S.State, +seat: D.Seat, +item: D.Item) -> Type:
  {give.host(A.ref_host(s), seat, item) == A.ref_host(give.state(s, seat, item)) : H.Host}

def give.eq(+s: S.State, +seat: D.Seat, +item: D.Item, +shape: A.Shape(s)) -> give.claim(s, seat, item):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat, item), clash.three_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat, item), clash.four_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, seat, item), clash.three_two(e_granted))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, seat, item), clash.four_two(e_granted))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat, item), clash.three_two(e_intake))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat, item), clash.four_two(e_intake))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat, item), clash.two_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat, item), clash.four_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, seat, item), clash.two_three(e_granted))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, seat, item), clash.four_three(e_granted))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat, item), clash.two_three(e_intake))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat, item), clash.four_three(e_intake))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, item), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat, item), clash.two_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat, item), clash.three_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, seat, item), clash.two_four(e_granted))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, seat, item), clash.three_four(e_granted))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat, item), clash.two_four(e_intake))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(give.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat, item), clash.three_four(e_intake))

def close.state(+s: S.State, +seat: D.Seat) -> S.State:
  S.state.set_grabs(s, I.grabs.close(S.state.grabs(s), seat))

def close.claim(+s: S.State, +seat: D.Seat) -> Type:
  {H.host.set_props(A.ref_host(s), seat, H.props.end_grab(H.host.props(A.ref_host(s), seat))) == A.ref_host(close.state(s, seat)) : H.Host}

def close.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> close.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat), clash.three_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat), clash.four_two(e_grabbing))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat), clash.two_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat), clash.four_three(e_grabbing))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat), clash.two_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(close.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat), clash.three_four(e_grabbing))

def put.state(+s: S.State, +seat: D.Seat, +fresh: D.Slots) -> S.State:
  S.state.set_grabs(S.state.set_players(s, S.players.set_slots(S.state.players(s), seat, fresh)), I.grabs.placed(S.state.grabs(s), seat))

def put.host(+h: H.Host, +seat: D.Seat, +fresh: D.Slots) -> H.Host:
  +props : H.Props = H.props.set_holding(H.props.set_slots(H.host.props(h, seat), fresh), None{})
  +h : H.Host = H.host.set_props(h, seat, props)
  H.host.set_progress(h, seat, H.GrabProgress{RI.progress.count(H.host.progress(h, seat)), RI.props.grabbing(props)})

def put.claim(+s: S.State, +seat: D.Seat, +fresh: D.Slots) -> Type:
  {put.host(A.ref_host(s), seat, fresh) == A.ref_host(put.state(s, seat, fresh)) : H.Host}

def put.eq(+s: S.State, +seat: D.Seat, +fresh: D.Slots, +shape: A.Shape(s)) -> put.claim(s, seat, fresh):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, D.Duo{+i1, +i3}} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, D.Duo{+i1, +i3}} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, D.Duo{+i1, +i3}} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, D.Duo{+i1, +i3}} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, fresh), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, fresh), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat, fresh), clash.three_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat, fresh), clash.four_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat, fresh), clash.three_two(e_intake))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat, fresh), clash.four_two(e_intake))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, D.Trio{+i0, +i1, +i2}} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, D.Trio{+i0, +i1, +i2}} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, D.Trio{+i0, +i1, +i2}} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, D.Trio{+i0, +i1, +i2}} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, fresh), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, fresh), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat, fresh), clash.two_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat, fresh), clash.four_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat, fresh), clash.two_three(e_intake))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat, fresh), clash.four_three(e_intake))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, D.Quad{+i0, +i1, +i2, +i3}} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, fresh), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, fresh), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat, fresh), clash.two_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat, fresh), clash.three_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat, fresh), clash.two_four(e_intake))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(put.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat, fresh), clash.three_four(e_intake))

def done.state(+s: S.State) -> S.State:
  S.state.set_grabs(s, S.grabs.set_distributing(S.state.grabs(s), False{}))

def done.claim(+s: S.State) -> Type:
  {H.host.set_distributing(A.ref_host(s), False{}) == A.ref_host(done.state(s)) : H.Host}

def done.eq(+s: S.State, +shape: A.Shape(s)) -> done.claim(s):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(done.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(done.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(done.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(done.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(done.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(done.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), clash.three_four(e_players))

def dist.eq(+s: S.State) -> {H.host.distributing(A.ref_host(s)) == S.grabs.distributing(S.state.grabs(s)) : Bool}:
  match s:
    case S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}:
      {==}

def held.claim(+s: S.State, +seat: D.Seat) -> Type:
  {RI.props.holding(H.host.props(A.ref_host(s), seat)) == I.seat.holding(S.state.grabs(s), seat) : Maybe<&2, D.Item>}

def held.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> held.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat), clash.three_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat), clash.four_two(e_holding))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat), clash.two_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat), clash.four_three(e_holding))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat), clash.two_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(held.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat), clash.three_four(e_holding))

def slots.set_put(+sl: D.Slots, +slot: D.Slot, +value: Maybe<&2, D.Item>) -> {RI.slots.set(sl, slot, value) == I.slots.put(sl, slot, value) : D.Slots}:
  match sl slot:
    case D.Slots{a, b, c, d, e, f, g, h} D.Slot0{}:
      {==}
    case D.Slots{a, b, c, d, e, f, g, h} D.Slot1{}:
      {==}
    case D.Slots{a, b, c, d, e, f, g, h} D.Slot2{}:
      {==}
    case D.Slots{a, b, c, d, e, f, g, h} D.Slot3{}:
      {==}
    case D.Slots{a, b, c, d, e, f, g, h} D.Slot4{}:
      {==}
    case D.Slots{a, b, c, d, e, f, g, h} D.Slot5{}:
      {==}
    case D.Slots{a, b, c, d, e, f, g, h} D.Slot6{}:
      {==}
    case D.Slots{a, b, c, d, e, f, g, h} D.Slot7{}:
      {==}

# Shape survives the handout's writes: a ring write keeps the constructor.

def set_table(-X: Data, +r: D.Ring<&2, X>, +seat: D.Seat, +x: X) -> {D.ring.table(X, D.ring.set(X, r, seat, x)) == D.ring.table(X, r) : D.Table}:
  match r seat:
    case D.Duo{x1, x3} D.Seat0{}:
      {==}
    case D.Duo{x1, x3} D.Seat1{}:
      {==}
    case D.Duo{x1, x3} D.Seat2{}:
      {==}
    case D.Duo{x1, x3} D.Seat3{}:
      {==}
    case D.Trio{x0, x1, x2} D.Seat0{}:
      {==}
    case D.Trio{x0, x1, x2} D.Seat1{}:
      {==}
    case D.Trio{x0, x1, x2} D.Seat2{}:
      {==}
    case D.Trio{x0, x1, x2} D.Seat3{}:
      {==}
    case D.Quad{x0, x1, x2, x3} D.Seat0{}:
      {==}
    case D.Quad{x0, x1, x2, x3} D.Seat1{}:
      {==}
    case D.Quad{x0, x1, x2, x3} D.Seat2{}:
      {==}
    case D.Quad{x0, x1, x2, x3} D.Seat3{}:
      {==}

# A closure's context: the table tie, and no seat holds the turn (a Grab or
# NeedItem phase), so the reference host's has_turn flags are all clear.
def Ctx(+s: S.State) -> Data:
  Sigma<&2, &2, A.Shape(s), _ => {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}>

def ctx.shape(+s: S.State, +ctx: Ctx(s)) -> A.Shape(s):
  match ctx:
    case Tuple{+shape, _}:
      shape

def ctx.quiet(+s: S.State, +ctx: Ctx(s)) -> {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}:
  match ctx:
    case Tuple{_, +quiet}:
      quiet

def ctx.stop(+s: S.State, +seat: D.Seat, +ctx: Ctx(s)) -> Ctx(stop.state(s, seat)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match ctx:
        case Tuple{Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}, +quiet}:
          ((e_players, (e_grabbing, (e_holding, (e_granted, Equal.trans(D.Table, D.ring.table(Bool, D.ring.set(Bool, intake, seat, False{})), D.ring.table(Bool, intake), table, set_table(Bool, intake, seat, False{}), e_intake))))), quiet)

def ctx.give(+s: S.State, +seat: D.Seat, +item: D.Item, +ctx: Ctx(s)) -> Ctx(give.state(s, seat, item)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match ctx:
        case Tuple{Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}, +quiet}:
          ((e_players, (e_grabbing, (Equal.trans(D.Table, D.ring.table(Maybe<&2, D.Item>, D.ring.set(Maybe<&2, D.Item>, holding, seat, Some{item})), D.ring.table(Maybe<&2, D.Item>, holding), table, set_table(Maybe<&2, D.Item>, holding, seat, Some{item}), e_holding), (Equal.trans(D.Table, D.ring.table(Nat, D.ring.set(Nat, granted, seat, 1n+I.seat.granted(S.Grabs{dist, grabbing, holding, granted, intake}, seat))), D.ring.table(Nat, granted), table, set_table(Nat, granted, seat, 1n+I.seat.granted(S.Grabs{dist, grabbing, holding, granted, intake}, seat)), e_granted), Equal.trans(D.Table, D.ring.table(Bool, D.ring.set(Bool, intake, seat, False{})), D.ring.table(Bool, intake), table, set_table(Bool, intake, seat, False{}), e_intake))))), quiet)

def ctx.close(+s: S.State, +seat: D.Seat, +ctx: Ctx(s)) -> Ctx(close.state(s, seat)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match ctx:
        case Tuple{Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}, +quiet}:
          ((e_players, (Equal.trans(D.Table, D.ring.table(Bool, D.ring.set(Bool, grabbing, seat, False{})), D.ring.table(Bool, grabbing), table, set_table(Bool, grabbing, seat, False{}), e_grabbing), (e_holding, (e_granted, e_intake)))), quiet)

def ctx.put(+s: S.State, +seat: D.Seat, +fresh: D.Slots, +ctx: Ctx(s)) -> Ctx(put.state(s, seat, fresh)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match ctx:
        case Tuple{Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}, +quiet}:
          ((Equal.trans(D.Table, D.ring.table(S.Seat, D.ring.set(S.Seat, players, seat, S.seat.set_slots(S.players.seat(players, seat), fresh))), D.ring.table(S.Seat, players), table, set_table(S.Seat, players, seat, S.seat.set_slots(S.players.seat(players, seat), fresh)), e_players), (e_grabbing, (Equal.trans(D.Table, D.ring.table(Maybe<&2, D.Item>, D.ring.set(Maybe<&2, D.Item>, holding, seat, None{})), D.ring.table(Maybe<&2, D.Item>, holding), table, set_table(Maybe<&2, D.Item>, holding, seat, None{}), e_holding), (e_granted, Equal.trans(D.Table, D.ring.table(Bool, D.ring.set(Bool, intake, seat, I.seat.grabbing(S.Grabs{dist, grabbing, holding, granted, intake}, seat))), D.ring.table(Bool, intake), table, set_table(Bool, intake, seat, I.seat.grabbing(S.Grabs{dist, grabbing, holding, granted, intake}, seat)), e_intake))))), quiet)

def ctx.done(+s: S.State, +ctx: Ctx(s)) -> Ctx(done.state(s)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match ctx:
        case Tuple{Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}, +quiet}:
          ((e_players, (e_grabbing, (e_holding, (e_granted, e_intake)))), quiet)

def ctx.emit(+s: S.State, +event: D.GameEvent, +ctx: Ctx(s)) -> Ctx(S.state.emit(s, event)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match ctx:
        case Tuple{Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}, +quiet}:
          ((e_players, (e_grabbing, (e_holding, (e_granted, e_intake)))), quiet)

def ctx.tell(+s: S.State, +seat: D.Seat, +secret: D.Secret, +ctx: Ctx(s)) -> Ctx(S.state.tell(s, seat, secret)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match ctx:
        case Tuple{Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}, +quiet}:
          ((e_players, (e_grabbing, (e_holding, (e_granted, e_intake)))), quiet)

def ctx.notes(+s: S.State, +notes2: List<&2, D.Note>, +ctx: Ctx(s)) -> Ctx(S.state.set_notes(s, notes2)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match ctx:
        case Tuple{Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}, +quiet}:
          ((e_players, (e_grabbing, (e_holding, (e_granted, e_intake)))), quiet)

# Closures of the handout, from a machine state's reference host and notes
# (A.close), each as an A.Closure with the reference's dispatch count. The
# load closure (L11) is stated here and proven in load-proof.bend.

def LoadClosure() -> Type:
  @+s:S.State -> @+ctx:Ctx(s) -> A.Closure(11n, s, A.frame_MainRoutine_LoadShotgun(), M.load.begin(s))

def grab.point(+s: S.State, +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {R.RefState{A.ref_host(s), R.Await{D.request.choose(I.grab.menus(I.grab.needs(s))), D.Distributing{}, R.ItemGrab_Packet{}}, S.state.notes(s)} == A.ref(S.state.set_phase(s, S.Grab{I.grab.needs(s)})) : R.RefState}:
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      %Equal.sym(Maybe<&2, D.Seat>, A.turn.holder(phase), None{}, quiet) : {R.RefState{A.host.at(world, A.core(players), grabs, _), R.Await{D.request.choose(I.grab.menus(I.grab.needs(S.State{world, players, phase, notes, grabs}))), D.Distributing{}, R.ItemGrab_Packet{}}, notes} == A.ref(S.State{world, players, S.Grab{I.grab.needs(S.State{world, players, phase, notes, grabs})}, notes, grabs}) : R.RefState}
      {==}

def continue.ready(+s: S.State, +d: Bool, +held: Bool, +k: Nat, +ctx: Ctx(s), load: LoadClosure()) -> {R.settle(Nat.add(11n, k), R.ContinueItemGrabbing.ready(R.RefState{A.ref_host(s), R.ContinueItemGrabbing{}, S.state.notes(s)}, d, held)) == A.ref(M.grab.continue.ready(s, d, held)) : R.RefState}:
  match d held:
    case False{} False{}:
      load(s, ctx, k)
    case True{} True{}:
      %Equal.sym(D.Ring<&2, List<&2, D.Move>>, R.grab_menus(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), D.ring.fill(List<&2, D.Move>, H.host.table(A.ref_host(s)), Nil{})), I.grab.menus(I.grab.needs(s)), menus.eq(s, ctx.shape(s, ctx))) : {R.RefState{A.ref_host(s), R.Await{D.request.choose(_), D.Distributing{}, R.ItemGrab_Packet{}}, S.state.notes(s)} == A.ref(S.state.set_phase(s, S.Grab{I.grab.needs(s)})) : R.RefState}
      grab.point(s, ctx.quiet(s, ctx))
    case True{} False{}:
      %Equal.sym(D.Ring<&2, List<&2, D.Move>>, R.grab_menus(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), D.ring.fill(List<&2, D.Move>, H.host.table(A.ref_host(s)), Nil{})), I.grab.menus(I.grab.needs(s)), menus.eq(s, ctx.shape(s, ctx))) : {R.RefState{A.ref_host(s), R.Await{D.request.choose(_), D.Distributing{}, R.ItemGrab_Packet{}}, S.state.notes(s)} == A.ref(S.state.set_phase(s, S.Grab{I.grab.needs(s)})) : R.RefState}
      grab.point(s, ctx.quiet(s, ctx))
    case False{} True{}:
      %Equal.sym(D.Ring<&2, List<&2, D.Move>>, R.grab_menus(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), D.ring.fill(List<&2, D.Move>, H.host.table(A.ref_host(s)), Nil{})), I.grab.menus(I.grab.needs(s)), menus.eq(s, ctx.shape(s, ctx))) : {R.RefState{A.ref_host(s), R.Await{D.request.choose(_), D.Distributing{}, R.ItemGrab_Packet{}}, S.state.notes(s)} == A.ref(S.state.set_phase(s, S.Grab{I.grab.needs(s)})) : R.RefState}
      grab.point(s, ctx.quiet(s, ctx))

def continue.close(+s: S.State, +ctx: Ctx(s), load: LoadClosure()) -> A.Closure(12n, s, A.frame_ContinueItemGrabbing(), M.grab.continue(s)):
  +k =>
    %dist.eq(s) : {R.settle(Nat.add(11n, k), R.ContinueItemGrabbing.ready(R.RefState{A.ref_host(s), R.ContinueItemGrabbing{}, S.state.notes(s)}, H.host.distributing(A.ref_host(s)), RI.holders(D.ring.entries(H.Props, H.host.seats(A.ref_host(s)))))) == A.ref(M.grab.continue.ready(s, _, I.holders(D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(S.state.grabs(s)))))) : R.RefState}
    %holders.eq(s, ctx.shape(s, ctx)) : {R.settle(Nat.add(11n, k), R.ContinueItemGrabbing.ready(R.RefState{A.ref_host(s), R.ContinueItemGrabbing{}, S.state.notes(s)}, H.host.distributing(A.ref_host(s)), RI.holders(D.ring.entries(H.Props, H.host.seats(A.ref_host(s)))))) == A.ref(M.grab.continue.ready(s, H.host.distributing(A.ref_host(s)), _)) : R.RefState}
    continue.ready(s, H.host.distributing(A.ref_host(s)), RI.holders(D.ring.entries(H.Props, H.host.seats(A.ref_host(s)))), k, ctx, load)

def give.close(+s: S.State, +seat: D.Seat, +item: D.Item, +ctx: Ctx(s), load: LoadClosure()) -> A.Closure(13n, s, A.frame_ReceivePacket_GrabItem(seat, item), M.grab.give(s, seat, item)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      +k =>
        +given : S.State = S.state.emit(give.state(S.State{world, players, phase, notes, grabs}, seat, item), D.Granted{seat, item})
        +step : {A.close(Nat.add(13n, k), S.State{world, players, phase, notes, grabs}, A.frame_ReceivePacket_GrabItem(seat, item)) == A.close(Nat.add(12n, k), given, A.frame_ContinueItemGrabbing()) : R.RefState} = Equal.cong(H.Host, R.RefState, x => R.settle(Nat.add(12n, k), R.RefState{x, R.ContinueItemGrabbing{}, List.append(&2, D.Note, notes, [D.Shown{D.Granted{seat, item}}])}), give.host(A.ref_host(S.State{world, players, phase, notes, grabs}), seat, item), A.ref_host(give.state(S.State{world, players, phase, notes, grabs}, seat, item)), give.eq(S.State{world, players, phase, notes, grabs}, seat, item, ctx.shape(S.State{world, players, phase, notes, grabs}, ctx)))
        Equal.trans(R.RefState, A.close(Nat.add(13n, k), S.State{world, players, phase, notes, grabs}, A.frame_ReceivePacket_GrabItem(seat, item)), A.close(Nat.add(12n, k), given, A.frame_ContinueItemGrabbing()), A.ref(M.grab.continue(given)), step, continue.close(given, ctx.emit(give.state(S.State{world, players, phase, notes, grabs}, seat, item), D.Granted{seat, item}, ctx.give(S.State{world, players, phase, notes, grabs}, seat, item, ctx)), load, k))

def chosen.close(+s: S.State, +seat: D.Seat, +found: Maybe<&2, D.Item>, +f: R.Frame, +ctx: Ctx(s), load: LoadClosure()) -> @+k:Nat -> {R.settle(Nat.add(13n, k), R.GetItemToGrab.selected(R.RefState{A.ref_host(s), f, S.state.notes(s)}, seat, found)) == A.ref(M.grab.chosen(s, seat, found)) : R.RefState}:
  match s found:
    case S.State{+world, +players, +phase, +notes, +grabs} Some{+item}:
      give.close(S.State{world, players, phase, notes, grabs}, seat, item, ctx, load)
    case S.State{+world, +players, +phase, +notes, +grabs} None{}:
      +k => continue.close(S.state.tell(S.State{world, players, phase, notes, grabs}, seat, D.EmptyBriefcase{}), ctx.tell(S.State{world, players, phase, notes, grabs}, seat, D.EmptyBriefcase{}, ctx), load, 1n+k)

def item_choice.point(+s: S.State, +seat: D.Seat, +first: D.Item, +second: D.Item, +rest: List<&2, D.Item>, +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {R.RefState{A.ref_host(s), R.Await{D.Draw{D.ItemChoice{}, D.Range{0n, List.length(&2, D.Item, rest)}}, D.Distributing{}, R.ItemChoiceResult{seat, first <> second <> rest}}, S.state.notes(s)} == A.ref(S.state.set_phase(s, S.NeedItem{seat, first, second, rest})) : R.RefState}:
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      %Equal.sym(Maybe<&2, D.Seat>, A.turn.holder(phase), None{}, quiet) : {R.RefState{A.host.at(world, A.core(players), grabs, _), R.Await{D.Draw{D.ItemChoice{}, D.Range{0n, List.length(&2, D.Item, rest)}}, D.Distributing{}, R.ItemChoiceResult{seat, first <> second <> rest}}, notes} == A.ref(S.State{world, players, S.NeedItem{seat, first, second, rest}, notes, grabs}) : R.RefState}
      {==}

def take.pool(+s: S.State, +seat: D.Seat, +pool: List<&2, D.Item>, +f: R.Frame, +ctx: Ctx(s), load: LoadClosure()) -> @+k:Nat -> {R.settle(Nat.add(13n, k), R.GetItemToGrab.pool(R.RefState{A.ref_host(s), f, S.state.notes(s)}, seat, pool)) == A.ref(M.grab.pool(s, seat, pool)) : R.RefState}:
  match pool:
    case Nil{}:
      chosen.close(s, seat, None{}, f, ctx, load)
    case +item <> Nil{}:
      give.close(s, seat, item, ctx, load)
    case +first <> +second <> +rest:
      +k => item_choice.point(s, seat, first, second, rest, ctx.quiet(s, ctx))

def take.close(+s: S.State, +seat: D.Seat, +ctx: Ctx(s), load: LoadClosure()) -> A.Closure(14n, s, A.frame_GetItemToGrab(seat), M.grab.take(s, seat)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      +k =>
        +stopped : S.State = stop.state(S.State{world, players, phase, notes, grabs}, seat)
        +ctx1 : Ctx(stopped) = ctx.stop(S.State{world, players, phase, notes, grabs}, seat, ctx)
        +host1 : {A.close(Nat.add(14n, k), S.State{world, players, phase, notes, grabs}, A.frame_GetItemToGrab(seat)) == R.settle(Nat.add(13n, k), R.GetItemToGrab.pool(R.RefState{A.ref_host(stopped), R.GetItemToGrab{seat}, notes}, seat, G.GetItemToGrab.pool(D.item.order(), A.ref_host(stopped), seat))) : R.RefState} = Equal.cong(H.Host, R.RefState, x => R.settle(Nat.add(13n, k), R.GetItemToGrab.pool(R.RefState{x, R.GetItemToGrab{seat}, notes}, seat, G.GetItemToGrab.pool(D.item.order(), x, seat))), H.host.set_progress(A.ref_host(S.State{world, players, phase, notes, grabs}), seat, H.GrabProgress{RI.progress.count(H.host.progress(A.ref_host(S.State{world, players, phase, notes, grabs}), seat)), False{}}), A.ref_host(stopped), stop.eq(S.State{world, players, phase, notes, grabs}, seat, ctx.shape(S.State{world, players, phase, notes, grabs}, ctx)))
        +pooled : {R.settle(Nat.add(13n, k), R.GetItemToGrab.pool(R.RefState{A.ref_host(stopped), R.GetItemToGrab{seat}, notes}, seat, G.GetItemToGrab.pool(D.item.order(), A.ref_host(stopped), seat))) == R.settle(Nat.add(13n, k), R.GetItemToGrab.pool(R.RefState{A.ref_host(stopped), R.GetItemToGrab{seat}, notes}, seat, I.pool(stopped, seat))) : R.RefState} = Equal.cong(List<&2, D.Item>, R.RefState, p => R.settle(Nat.add(13n, k), R.GetItemToGrab.pool(R.RefState{A.ref_host(stopped), R.GetItemToGrab{seat}, notes}, seat, p)), G.GetItemToGrab.pool(D.item.order(), A.ref_host(stopped), seat), I.pool(stopped, seat), pool.eq(stopped, seat, ctx.shape(stopped, ctx1)))
        Equal.trans(R.RefState, A.close(Nat.add(14n, k), S.State{world, players, phase, notes, grabs}, A.frame_GetItemToGrab(seat)), R.settle(Nat.add(13n, k), R.GetItemToGrab.pool(R.RefState{A.ref_host(stopped), R.GetItemToGrab{seat}, notes}, seat, G.GetItemToGrab.pool(D.item.order(), A.ref_host(stopped), seat))), A.ref(M.grab.take(S.State{world, players, phase, notes, grabs}, seat)), host1, Equal.trans(R.RefState, R.settle(Nat.add(13n, k), R.GetItemToGrab.pool(R.RefState{A.ref_host(stopped), R.GetItemToGrab{seat}, notes}, seat, G.GetItemToGrab.pool(D.item.order(), A.ref_host(stopped), seat))), R.settle(Nat.add(13n, k), R.GetItemToGrab.pool(R.RefState{A.ref_host(stopped), R.GetItemToGrab{seat}, notes}, seat, I.pool(stopped, seat))), A.ref(M.grab.take(S.State{world, players, phase, notes, grabs}, seat)), pooled, take.pool(stopped, seat, I.pool(stopped, seat), R.GetItemToGrab{seat}, ctx1, load, k)))

def slots.claim(+s: S.State, +seat: D.Seat) -> Type:
  {RI.props.slots(H.host.props(A.ref_host(s), seat)) == I.seat.slots(S.state.players(s), seat) : D.Slots}

def slots.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> slots.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(slots.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(slots.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(slots.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(slots.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(slots.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              absurd(slots.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), clash.three_four(e_players))

def blocked.point(+s: S.State, +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {R.stuck(R.RefState{A.ref_host(s), R.Await{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}, S.state.notes(s)}) == A.ref(S.state.set_phase(s, S.Blocked{None{}})) : R.RefState}:
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      %Equal.sym(Maybe<&2, D.Seat>, A.turn.holder(phase), None{}, quiet) : {R.RefState{A.host.at(world, A.core(players), grabs, _), R.Await{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}, notes} == A.ref(S.State{world, players, S.Blocked{None{}}, notes, grabs}) : R.RefState}
      {==}

def put.held.close(+s: S.State, +seat: D.Seat, +slot: D.Slot, +held: Maybe<&2, D.Item>, +ctx: Ctx(s), load: LoadClosure()) -> @+k:Nat -> {R.settle(Nat.add(12n, k), R.ReceivePacket_PlaceItem.held(R.RefState{A.ref_host(s), R.ReceivePacket_PlaceItem{seat, slot}, S.state.notes(s)}, seat, slot, held)) == A.ref(M.grab.put.held(s, seat, slot, held)) : R.RefState}:
  match s held:
    case S.State{+world, +players, +phase, +notes, +grabs} None{}:
      +k => blocked.point(S.State{world, players, phase, notes, grabs}, ctx.quiet(S.State{world, players, phase, notes, grabs}, ctx))
    case S.State{+world, +players, +phase, +notes, +grabs} Some{+item}:
      +k =>
        +placed : S.State = S.state.emit(put.state(S.State{world, players, phase, notes, grabs}, seat, I.slots.put(I.seat.slots(players, seat), slot, Some{item})), D.Placed{seat, slot, item})
        +fresh : {RI.slots.set(RI.props.slots(H.host.props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat)), slot, Some{item}) == I.slots.put(I.seat.slots(players, seat), slot, Some{item}) : D.Slots} = Equal.trans(D.Slots, RI.slots.set(RI.props.slots(H.host.props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat)), slot, Some{item}), RI.slots.set(I.seat.slots(players, seat), slot, Some{item}), I.slots.put(I.seat.slots(players, seat), slot, Some{item}), Equal.cong(D.Slots, D.Slots, sl => RI.slots.set(sl, slot, Some{item}), RI.props.slots(H.host.props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat)), I.seat.slots(players, seat), slots.eq(S.State{world, players, phase, notes, grabs}, seat, ctx.shape(S.State{world, players, phase, notes, grabs}, ctx))), slots.set_put(I.seat.slots(players, seat), slot, Some{item}))
        +host1 : {put.host(A.ref_host(S.State{world, players, phase, notes, grabs}), seat, RI.slots.set(RI.props.slots(H.host.props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat)), slot, Some{item})) == A.ref_host(put.state(S.State{world, players, phase, notes, grabs}, seat, I.slots.put(I.seat.slots(players, seat), slot, Some{item}))) : H.Host} = Equal.trans(H.Host, put.host(A.ref_host(S.State{world, players, phase, notes, grabs}), seat, RI.slots.set(RI.props.slots(H.host.props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat)), slot, Some{item})), put.host(A.ref_host(S.State{world, players, phase, notes, grabs}), seat, I.slots.put(I.seat.slots(players, seat), slot, Some{item})), A.ref_host(put.state(S.State{world, players, phase, notes, grabs}, seat, I.slots.put(I.seat.slots(players, seat), slot, Some{item}))), Equal.cong(D.Slots, H.Host, sl => put.host(A.ref_host(S.State{world, players, phase, notes, grabs}), seat, sl), RI.slots.set(RI.props.slots(H.host.props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat)), slot, Some{item}), I.slots.put(I.seat.slots(players, seat), slot, Some{item}), fresh), put.eq(S.State{world, players, phase, notes, grabs}, seat, I.slots.put(I.seat.slots(players, seat), slot, Some{item}), ctx.shape(S.State{world, players, phase, notes, grabs}, ctx)))
        +step : {R.settle(Nat.add(12n, k), R.ReceivePacket_PlaceItem.held(R.RefState{A.ref_host(S.State{world, players, phase, notes, grabs}), R.ReceivePacket_PlaceItem{seat, slot}, notes}, seat, slot, Some{item})) == A.close(Nat.add(12n, k), placed, A.frame_ContinueItemGrabbing()) : R.RefState} = Equal.cong(H.Host, R.RefState, x => R.settle(Nat.add(12n, k), R.RefState{x, R.ContinueItemGrabbing{}, List.append(&2, D.Note, notes, [D.Shown{D.Placed{seat, slot, item}}])}), put.host(A.ref_host(S.State{world, players, phase, notes, grabs}), seat, RI.slots.set(RI.props.slots(H.host.props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat)), slot, Some{item})), A.ref_host(put.state(S.State{world, players, phase, notes, grabs}, seat, I.slots.put(I.seat.slots(players, seat), slot, Some{item}))), host1)
        Equal.trans(R.RefState, R.settle(Nat.add(12n, k), R.ReceivePacket_PlaceItem.held(R.RefState{A.ref_host(S.State{world, players, phase, notes, grabs}), R.ReceivePacket_PlaceItem{seat, slot}, notes}, seat, slot, Some{item})), A.close(Nat.add(12n, k), placed, A.frame_ContinueItemGrabbing()), A.ref(M.grab.continue(placed)), step, continue.close(placed, ctx.emit(put.state(S.State{world, players, phase, notes, grabs}, seat, I.slots.put(I.seat.slots(players, seat), slot, Some{item})), D.Placed{seat, slot, item}, ctx.put(S.State{world, players, phase, notes, grabs}, seat, I.slots.put(I.seat.slots(players, seat), slot, Some{item}), ctx)), load, k))

def put.close(+s: S.State, +seat: D.Seat, +slot: D.Slot, +ctx: Ctx(s), load: LoadClosure()) -> A.Closure(13n, s, A.frame_ReceivePacket_PlaceItem(seat, slot), M.grab.put(s, seat, slot)):
  +k =>
    +read : {A.close(Nat.add(13n, k), s, A.frame_ReceivePacket_PlaceItem(seat, slot)) == R.settle(Nat.add(12n, k), R.ReceivePacket_PlaceItem.held(R.RefState{A.ref_host(s), R.ReceivePacket_PlaceItem{seat, slot}, S.state.notes(s)}, seat, slot, I.seat.holding(S.state.grabs(s), seat))) : R.RefState} = Equal.cong(Maybe<&2, D.Item>, R.RefState, held => R.settle(Nat.add(12n, k), R.ReceivePacket_PlaceItem.held(R.RefState{A.ref_host(s), R.ReceivePacket_PlaceItem{seat, slot}, S.state.notes(s)}, seat, slot, held)), RI.props.holding(H.host.props(A.ref_host(s), seat)), I.seat.holding(S.state.grabs(s), seat), held.eq(s, seat, ctx.shape(s, ctx)))
    Equal.trans(R.RefState, A.close(Nat.add(13n, k), s, A.frame_ReceivePacket_PlaceItem(seat, slot)), R.settle(Nat.add(12n, k), R.ReceivePacket_PlaceItem.held(R.RefState{A.ref_host(s), R.ReceivePacket_PlaceItem{seat, slot}, S.state.notes(s)}, seat, slot, I.seat.holding(S.state.grabs(s), seat))), A.ref(M.grab.put(s, seat, slot)), read, put.held.close(s, seat, slot, I.seat.holding(S.state.grabs(s), seat), ctx, load, k))

# The completion check, the noneligible pass and the last placement (M1).

def check.done(+s: S.State, +next: R.Frame, +b: Bool, +k: Nat, +ctx: Ctx(s)) -> {R.settle(k, R.CheckIfItemGrabbingFinishedForAllUsers.result(R.RefState{A.ref_host(s), R.CheckIfItemGrabbingFinishedForAllUsers{next}, S.state.notes(s)}, next, b)) == A.close(k, M.grab.check.done(s, b), next) : R.RefState}:
  match s b:
    case S.State{+world, +players, +phase, +notes, +grabs} True{}:
      Equal.cong(H.Host, R.RefState, x => R.settle(k, R.RefState{x, next, List.append(&2, D.Note, notes, [D.Shown{D.DistributionDone{}}])}), H.host.set_distributing(A.ref_host(S.State{world, players, phase, notes, grabs}), False{}), A.ref_host(done.state(S.State{world, players, phase, notes, grabs})), done.eq(S.State{world, players, phase, notes, grabs}, ctx.shape(S.State{world, players, phase, notes, grabs}, ctx)))
    case S.State{+world, +players, +phase, +notes, +grabs} False{}:
      {==}

def check.step(+s: S.State, +next: R.Frame, +k: Nat, +ctx: Ctx(s)) -> {A.close(1n+k, s, R.CheckIfItemGrabbingFinishedForAllUsers{next}) == A.close(k, M.grab.check(s), next) : R.RefState}:
  +flag : {Bool.and(H.host.distributing(A.ref_host(s)), RI.CheckIfItemGrabbingFinishedForAllUsers(A.ref_host(s))) == Bool.and(S.grabs.distributing(S.state.grabs(s)), I.finished(s)) : Bool} = and_cong(H.host.distributing(A.ref_host(s)), S.grabs.distributing(S.state.grabs(s)), RI.CheckIfItemGrabbingFinishedForAllUsers(A.ref_host(s)), I.finished(s), dist.eq(s), finished.eq(s, ctx.shape(s, ctx)))
  Equal.trans(R.RefState, A.close(1n+k, s, R.CheckIfItemGrabbingFinishedForAllUsers{next}), R.settle(k, R.CheckIfItemGrabbingFinishedForAllUsers.result(R.RefState{A.ref_host(s), R.CheckIfItemGrabbingFinishedForAllUsers{next}, S.state.notes(s)}, next, Bool.and(S.grabs.distributing(S.state.grabs(s)), I.finished(s)))), A.close(k, M.grab.check(s), next), Equal.cong(Bool, R.RefState, b => R.settle(k, R.CheckIfItemGrabbingFinishedForAllUsers.result(R.RefState{A.ref_host(s), R.CheckIfItemGrabbingFinishedForAllUsers{next}, S.state.notes(s)}, next, b)), Bool.and(H.host.distributing(A.ref_host(s)), RI.CheckIfItemGrabbingFinishedForAllUsers(A.ref_host(s))), Bool.and(S.grabs.distributing(S.state.grabs(s)), I.finished(s)), flag), check.done(s, next, Bool.and(S.grabs.distributing(S.state.grabs(s)), I.finished(s)), k, ctx))

def ctx.check.done(+s: S.State, +b: Bool, +ctx: Ctx(s)) -> Ctx(M.grab.check.done(s, b)):
  match b:
    case True{}:
      ctx.emit(done.state(s), D.DistributionDone{}, ctx.done(s, ctx))
    case False{}:
      ctx

def ctx.check(+s: S.State, +ctx: Ctx(s)) -> Ctx(M.grab.check(s)):
  ctx.check.done(s, Bool.and(S.grabs.distributing(S.state.grabs(s)), I.finished(s)), ctx)

def end.close(+seats: List<&2, D.Seat>, +s: S.State, +next: R.Frame, +k: Nat, +ctx: Ctx(s)) -> {A.close(Nat.add(List.length(&2, D.Seat, seats), 1n+k), s, R.EndItemGrabbingAfterNonEligible{seats, next}) == A.close(k, M.grab.end_all(seats, s), next) : R.RefState}:
  match seats s:
    case Nil{} s:
      {==}
    case +seat <> +rest S.State{+world, +players, +phase, +notes, +grabs}:
      +ended : S.State = S.state.emit(close.state(S.State{world, players, phase, notes, grabs}, seat), D.GrabbingEnded{seat})
      +step : {A.close(Nat.add(List.length(&2, D.Seat, seat <> rest), 1n+k), S.State{world, players, phase, notes, grabs}, R.EndItemGrabbingAfterNonEligible{seat <> rest, next}) == A.close(Nat.add(List.length(&2, D.Seat, rest), 1n+k), ended, R.EndItemGrabbingAfterNonEligible{rest, next}) : R.RefState} = Equal.cong(H.Host, R.RefState, x => R.settle(Nat.add(List.length(&2, D.Seat, rest), 1n+k), R.RefState{x, R.EndItemGrabbingAfterNonEligible{rest, next}, List.append(&2, D.Note, notes, [D.Shown{D.GrabbingEnded{seat}}])}), H.host.set_props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat, H.props.end_grab(H.host.props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat))), A.ref_host(close.state(S.State{world, players, phase, notes, grabs}, seat)), close.eq(S.State{world, players, phase, notes, grabs}, seat, ctx.shape(S.State{world, players, phase, notes, grabs}, ctx)))
      Equal.trans(R.RefState, A.close(Nat.add(List.length(&2, D.Seat, seat <> rest), 1n+k), S.State{world, players, phase, notes, grabs}, R.EndItemGrabbingAfterNonEligible{seat <> rest, next}), A.close(Nat.add(List.length(&2, D.Seat, rest), 1n+k), ended, R.EndItemGrabbingAfterNonEligible{rest, next}), A.close(k, M.grab.end_all(rest, ended), next), step, end.close(rest, ended, next, k, ctx.emit(close.state(S.State{world, players, phase, notes, grabs}, seat), D.GrabbingEnded{seat}, ctx.close(S.State{world, players, phase, notes, grabs}, seat, ctx))))

def ctx.end_all(+seats: List<&2, D.Seat>, +s: S.State, +ctx: Ctx(s)) -> Ctx(M.grab.end_all(seats, s)):
  match seats s:
    case Nil{} s:
      ctx
    case +seat <> +rest S.State{+world, +players, +phase, +notes, +grabs}:
      ctx.end_all(rest, S.state.emit(close.state(S.State{world, players, phase, notes, grabs}, seat), D.GrabbingEnded{seat}), ctx.emit(close.state(S.State{world, players, phase, notes, grabs}, seat), D.GrabbingEnded{seat}, ctx.close(S.State{world, players, phase, notes, grabs}, seat, ctx)))

def gs.step(+s: S.State, +seat: D.Seat, +slot: D.Slot, +k: Nat, +shape: A.Shape(s)) -> {A.close(1n+k, s, R.GetSocketArrayToEndItemGrabbingOn{seat, slot}) == A.close(k, s, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}) : R.RefState}:
  Equal.cong(List<&2, D.Seat>, R.RefState, xs => R.settle(k, R.RefState{A.ref_host(s), R.EndItemGrabbingAfterNonEligible{xs, R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}, S.state.notes(s)}), RI.GetSocketArrayToEndItemGrabbingOn(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), seat), I.stalled.seats(s, seat), stalled.eq(s, seat, shape))

# Fuel arithmetic for the noneligible pass, whose length is at most four.

def add.succ(+a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, n => 1n+n, Nat.add(p, 1n+b), 1n+Nat.add(p, b), add.succ(p, b))

def add.assoc(+a: Nat, +b: Nat, +c: Nat) -> {Nat.add(Nat.add(a, b), c) == Nat.add(a, Nat.add(b, c)) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, n => 1n+n, Nat.add(Nat.add(p, b), c), Nat.add(p, Nat.add(b, c)), add.assoc(p, b, c))

def add.shift(+n: Nat, +a: Nat, +b: Nat) -> {Nat.add(a, Nat.add(n, b)) == Nat.add(n, Nat.add(a, b)) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      Equal.trans(Nat, Nat.add(a, 1n+Nat.add(p, b)), 1n+Nat.add(a, Nat.add(p, b)), 1n+Nat.add(p, Nat.add(a, b)), add.succ(a, Nat.add(p, b)), Equal.cong(Nat, Nat, x => 1n+x, Nat.add(a, Nat.add(p, b)), Nat.add(p, Nat.add(a, b)), add.shift(p, a, b)))

def fuel.split(+len: Nat, +room: Nat, +k: Nat, +fits: {Nat.add(len, room) == 4n : Nat}) -> {Nat.add(19n, k) == Nat.add(len, 1n+Nat.add(14n, Nat.add(room, k))) : Nat}:
  +y : Nat = Nat.add(room, k)
  +inner : {Nat.add(len, y) == Nat.add(4n, k) : Nat} = Equal.trans(Nat, Nat.add(len, y), Nat.add(Nat.add(len, room), k), Nat.add(4n, k), Equal.sym(Nat, Nat.add(Nat.add(len, room), k), Nat.add(len, y), add.assoc(len, room, k)), Equal.cong(Nat, Nat, z => Nat.add(z, k), Nat.add(len, room), 4n, fits))
  +rhs : {Nat.add(len, 1n+Nat.add(14n, y)) == Nat.add(19n, k) : Nat} = Equal.trans(Nat, Nat.add(len, 1n+Nat.add(14n, y)), 1n+Nat.add(len, Nat.add(14n, y)), Nat.add(19n, k), add.succ(len, Nat.add(14n, y)), Equal.trans(Nat, 1n+Nat.add(len, Nat.add(14n, y)), 1n+Nat.add(14n, Nat.add(len, y)), Nat.add(19n, k), Equal.cong(Nat, Nat, z => 1n+z, Nat.add(len, Nat.add(14n, y)), Nat.add(14n, Nat.add(len, y)), add.shift(14n, len, y)), Equal.cong(Nat, Nat, z => 1n+Nat.add(14n, z), Nat.add(len, y), Nat.add(4n, k), inner)))
  Equal.sym(Nat, Nat.add(len, 1n+Nat.add(14n, y)), Nat.add(19n, k), rhs)

def Room(+len: Nat, +total: Nat) -> Data:
  Sigma<&2, &2, Nat, room => {Nat.add(len, room) == total : Nat}>

def keep.room(+b: Bool, +x: D.Seat, +rest: List<&2, D.Seat>, +total: Nat, +r: Nat, +e: {Nat.add(List.length(&2, D.Seat, rest), r) == total : Nat}) -> Room(List.length(&2, D.Seat, I.keep(D.Seat, b, x, rest)), 1n+total):
  match b:
    case True{}:
      (r, Equal.cong(Nat, Nat, n => 1n+n, Nat.add(List.length(&2, D.Seat, rest), r), total, e))
    case False{}:
      (1n+r, Equal.trans(Nat, Nat.add(List.length(&2, D.Seat, rest), 1n+r), 1n+Nat.add(List.length(&2, D.Seat, rest), r), 1n+total, add.succ(List.length(&2, D.Seat, rest), r), Equal.cong(Nat, Nat, n => 1n+n, Nat.add(List.length(&2, D.Seat, rest), r), total, e)))

def stalled.room.step(+seat: D.Seat, +rest: List<&2, D.Seat>, +s: S.State, +placing: D.Seat, +ih: Room(List.length(&2, D.Seat, I.stalled(rest, s, placing)), List.length(&2, D.Seat, rest))) -> Room(List.length(&2, D.Seat, I.stalled(seat <> rest, s, placing)), List.length(&2, D.Seat, seat <> rest)):
  match ih:
    case Tuple{+r, +e}:
      keep.room(Bool.and(I.seat.grabbing(S.state.grabs(s), seat), Bool.and(I.is_none(I.seat.holding(S.state.grabs(s), seat)), Bool.and(Bool.not(D.seat.eq(seat, placing)), Bool.not(I.has_items(I.pool(s, seat)))))), seat, I.stalled(rest, s, placing), List.length(&2, D.Seat, rest), r, e)

def stalled.room(+seats: List<&2, D.Seat>, +s: S.State, +placing: D.Seat) -> Room(List.length(&2, D.Seat, I.stalled(seats, s, placing)), List.length(&2, D.Seat, seats)):
  match seats:
    case Nil{}:
      (0n, {==})
    case +seat <> +rest:
      stalled.room.step(seat, rest, s, placing, stalled.room(rest, s, placing))

def table.room(+table: D.Table) -> Room(List.length(&2, D.Seat, D.table.seats(table)), 4n):
  match table:
    case D.TwoSeats{}:
      (2n, {==})
    case D.ThreeSeats{}:
      (1n, {==})
    case D.FourSeats{}:
      (0n, {==})

def room.join(+a: Nat, +b: Nat, +x: Room(a, b), +y: Room(b, 4n)) -> Room(a, 4n):
  match x y:
    case Tuple{+r, +e1} Tuple{+q, +e2}:
      (Nat.add(r, q), Equal.trans(Nat, Nat.add(a, Nat.add(r, q)), Nat.add(Nat.add(a, r), q), 4n, Equal.sym(Nat, Nat.add(Nat.add(a, r), q), Nat.add(a, Nat.add(r, q)), add.assoc(a, r, q)), Equal.trans(Nat, Nat.add(Nat.add(a, r), q), Nat.add(b, q), 4n, Equal.cong(Nat, Nat, z => Nat.add(z, q), Nat.add(a, r), b, e1), e2)))

def stalled.fits(+s: S.State, +placing: D.Seat) -> Room(List.length(&2, D.Seat, I.stalled.seats(s, placing)), 4n):
  +seats : List<&2, D.Seat> = D.table.seats(S.world.table(S.state.world(s)))
  room.join(List.length(&2, D.Seat, I.stalled(seats, s, placing)), List.length(&2, D.Seat, seats), stalled.room(seats, s, placing), table.room(S.world.table(S.state.world(s))))

def place.tail(+s1: S.State, +seat: D.Seat, +slot: D.Slot, +k: Nat, +ctx1: Ctx(s1), load: LoadClosure(), +room: Nat, +fits: {Nat.add(List.length(&2, D.Seat, I.stalled.seats(s1, seat)), room) == 4n : Nat}) -> {A.close(Nat.add(19n, k), s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}) == A.ref(M.grab.put(M.grab.check(M.grab.end_all(I.stalled.seats(s1, seat), s1)), seat, slot)) : R.RefState}:
  +big : Nat = Nat.add(14n, Nat.add(room, k))
  +s2 : S.State = M.grab.end_all(I.stalled.seats(s1, seat), s1)
  +ctx2 : Ctx(s2) = ctx.end_all(I.stalled.seats(s1, seat), s1, ctx1)
  +fuel : {A.close(Nat.add(19n, k), s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}) == A.close(Nat.add(List.length(&2, D.Seat, I.stalled.seats(s1, seat)), 1n+big), s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}) : R.RefState} = Equal.cong(Nat, R.RefState, n => A.close(n, s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}), Nat.add(19n, k), Nat.add(List.length(&2, D.Seat, I.stalled.seats(s1, seat)), 1n+big), fuel.split(List.length(&2, D.Seat, I.stalled.seats(s1, seat)), room, k, fits))
  +ended : {A.close(Nat.add(List.length(&2, D.Seat, I.stalled.seats(s1, seat)), 1n+big), s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}) == A.close(big, s2, R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}) : R.RefState} = end.close(I.stalled.seats(s1, seat), s1, R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}, big, ctx1)
  +checked : {A.close(big, s2, R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}) == A.close(Nat.add(13n, Nat.add(room, k)), M.grab.check(s2), R.ReceivePacket_PlaceItem{seat, slot}) : R.RefState} = check.step(s2, R.ReceivePacket_PlaceItem{seat, slot}, Nat.add(13n, Nat.add(room, k)), ctx2)
  Equal.trans(R.RefState, A.close(Nat.add(19n, k), s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}), A.close(Nat.add(List.length(&2, D.Seat, I.stalled.seats(s1, seat)), 1n+big), s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}), A.ref(M.grab.put(M.grab.check(s2), seat, slot)), fuel, Equal.trans(R.RefState, A.close(Nat.add(List.length(&2, D.Seat, I.stalled.seats(s1, seat)), 1n+big), s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}), A.close(big, s2, R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}), A.ref(M.grab.put(M.grab.check(s2), seat, slot)), ended, Equal.trans(R.RefState, A.close(big, s2, R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}), A.close(Nat.add(13n, Nat.add(room, k)), M.grab.check(s2), R.ReceivePacket_PlaceItem{seat, slot}), A.ref(M.grab.put(M.grab.check(s2), seat, slot)), checked, put.close(M.grab.check(s2), seat, slot, ctx.check(s2, ctx2), load, Nat.add(room, k)))))

def place.tail.fit(+s1: S.State, +seat: D.Seat, +slot: D.Slot, +k: Nat, +ctx1: Ctx(s1), load: LoadClosure(), +fits: Room(List.length(&2, D.Seat, I.stalled.seats(s1, seat)), 4n)) -> {A.close(Nat.add(19n, k), s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}) == A.ref(M.grab.put(M.grab.check(M.grab.end_all(I.stalled.seats(s1, seat), s1)), seat, slot)) : R.RefState}:
  match fits:
    case Tuple{+room, +e}:
      place.tail(s1, seat, slot, k, ctx1, load, room, e)

def place.last(+s: S.State, +seat: D.Seat, +slot: D.Slot, +last: Bool, +ctx: Ctx(s), load: LoadClosure()) -> @+k:Nat -> {R.settle(Nat.add(21n, k), R.IsPlacingLastItem.last(R.RefState{A.ref_host(s), R.IsPlacingLastItem{seat, slot}, S.state.notes(s)}, seat, slot, last)) == A.ref(M.grab.place.last(s, seat, slot, last)) : R.RefState}:
  match s last:
    case S.State{+world, +players, +phase, +notes, +grabs} False{}:
      +k => put.close(S.State{world, players, phase, notes, grabs}, seat, slot, ctx, load, 8n+k)
    case S.State{+world, +players, +phase, +notes, +grabs} True{}:
      +k =>
        +s0 : S.State = S.state.emit(close.state(S.State{world, players, phase, notes, grabs}, seat), D.GrabbingEnded{seat})
        +ctx0 : Ctx(s0) = ctx.emit(close.state(S.State{world, players, phase, notes, grabs}, seat), D.GrabbingEnded{seat}, ctx.close(S.State{world, players, phase, notes, grabs}, seat, ctx))
        +s1 : S.State = M.grab.check(s0)
        +ctx1 : Ctx(s1) = ctx.check(s0, ctx0)
        +ended : {R.settle(Nat.add(21n, k), R.IsPlacingLastItem.last(R.RefState{A.ref_host(S.State{world, players, phase, notes, grabs}), R.IsPlacingLastItem{seat, slot}, notes}, seat, slot, True{})) == A.close(Nat.add(21n, k), s0, R.CheckIfItemGrabbingFinishedForAllUsers{R.GetSocketArrayToEndItemGrabbingOn{seat, slot}}) : R.RefState} = Equal.cong(H.Host, R.RefState, x => R.settle(Nat.add(21n, k), R.RefState{x, R.CheckIfItemGrabbingFinishedForAllUsers{R.GetSocketArrayToEndItemGrabbingOn{seat, slot}}, List.append(&2, D.Note, notes, [D.Shown{D.GrabbingEnded{seat}}])}), H.host.set_props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat, H.props.end_grab(H.host.props(A.ref_host(S.State{world, players, phase, notes, grabs}), seat))), A.ref_host(close.state(S.State{world, players, phase, notes, grabs}, seat)), close.eq(S.State{world, players, phase, notes, grabs}, seat, ctx.shape(S.State{world, players, phase, notes, grabs}, ctx)))
        +checked : {A.close(Nat.add(21n, k), s0, R.CheckIfItemGrabbingFinishedForAllUsers{R.GetSocketArrayToEndItemGrabbingOn{seat, slot}}) == A.close(Nat.add(20n, k), s1, R.GetSocketArrayToEndItemGrabbingOn{seat, slot}) : R.RefState} = check.step(s0, R.GetSocketArrayToEndItemGrabbingOn{seat, slot}, Nat.add(20n, k), ctx0)
        +gathered : {A.close(Nat.add(20n, k), s1, R.GetSocketArrayToEndItemGrabbingOn{seat, slot}) == A.close(Nat.add(19n, k), s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}) : R.RefState} = gs.step(s1, seat, slot, Nat.add(19n, k), ctx.shape(s1, ctx1))
        Equal.trans(R.RefState, R.settle(Nat.add(21n, k), R.IsPlacingLastItem.last(R.RefState{A.ref_host(S.State{world, players, phase, notes, grabs}), R.IsPlacingLastItem{seat, slot}, notes}, seat, slot, True{})), A.close(Nat.add(21n, k), s0, R.CheckIfItemGrabbingFinishedForAllUsers{R.GetSocketArrayToEndItemGrabbingOn{seat, slot}}), A.ref(M.grab.place.last(S.State{world, players, phase, notes, grabs}, seat, slot, True{})), ended, Equal.trans(R.RefState, A.close(Nat.add(21n, k), s0, R.CheckIfItemGrabbingFinishedForAllUsers{R.GetSocketArrayToEndItemGrabbingOn{seat, slot}}), A.close(Nat.add(20n, k), s1, R.GetSocketArrayToEndItemGrabbingOn{seat, slot}), A.ref(M.grab.place.last(S.State{world, players, phase, notes, grabs}, seat, slot, True{})), checked, Equal.trans(R.RefState, A.close(Nat.add(20n, k), s1, R.GetSocketArrayToEndItemGrabbingOn{seat, slot}), A.close(Nat.add(19n, k), s1, R.EndItemGrabbingAfterNonEligible{I.stalled.seats(s1, seat), R.CheckIfItemGrabbingFinishedForAllUsers{R.ReceivePacket_PlaceItem{seat, slot}}}), A.ref(M.grab.place.last(S.State{world, players, phase, notes, grabs}, seat, slot, True{})), gathered, place.tail.fit(s1, seat, slot, k, ctx1, load, stalled.fits(s1, seat)))))

def place.close(+s: S.State, +seat: D.Seat, +slot: D.Slot, +ctx: Ctx(s), load: LoadClosure()) -> A.Closure(22n, s, A.frame_IsPlacingLastItem(seat, slot), M.grab.place(s, seat, slot)):
  +k =>
    +read : {A.close(Nat.add(22n, k), s, A.frame_IsPlacingLastItem(seat, slot)) == R.settle(Nat.add(21n, k), R.IsPlacingLastItem.last(R.RefState{A.ref_host(s), R.IsPlacingLastItem{seat, slot}, S.state.notes(s)}, seat, slot, I.placing.last(s, seat))) : R.RefState} = Equal.cong(Bool, R.RefState, b => R.settle(Nat.add(21n, k), R.IsPlacingLastItem.last(R.RefState{A.ref_host(s), R.IsPlacingLastItem{seat, slot}, S.state.notes(s)}, seat, slot, b)), RI.IsPlacingLastItem(A.ref_host(s), seat), I.placing.last(s, seat), last.eq(s, seat, ctx.shape(s, ctx)))
    Equal.trans(R.RefState, A.close(Nat.add(22n, k), s, A.frame_IsPlacingLastItem(seat, slot)), R.settle(Nat.add(21n, k), R.IsPlacingLastItem.last(R.RefState{A.ref_host(s), R.IsPlacingLastItem{seat, slot}, S.state.notes(s)}, seat, slot, I.placing.last(s, seat))), A.ref(M.grab.place(s, seat, slot)), read, place.last(s, seat, slot, I.placing.last(s, seat), ctx, load, k))
