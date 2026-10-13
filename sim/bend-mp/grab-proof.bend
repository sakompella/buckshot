import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/items.bend as I
import ./sm/rules.bend as Q
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
