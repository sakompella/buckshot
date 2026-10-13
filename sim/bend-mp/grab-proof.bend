import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/items.bend as I
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
