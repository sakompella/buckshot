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
import ./core-proof.bend as C
import ./grab-proof.bend as GP
import ./item-step-proof.bend as ISP
import ./load-proof.bend as LP

# The reference host of a state once no seat holds the turn, whatever its
# phase: the chains below start from Idle, Aim and the item phases, whose
# own phase the machine keeps until it sets the next one.
def qh(+s: S.State) -> H.Host:
  A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), None{})

def quiet(+s: S.State) -> S.State:
  S.state.set_phase(s, S.Blocked{None{}})

# Phase irrelevance: the load and the grant set the phase they end in, so the
# phase they start from does not matter.
def irr.step(+rank: Nat, +w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs, +seat: D.Seat, +result: S.JamResult) -> {M.grant.step(rank, S.State{w, p, ph, n, g}, seat, result) == M.grant.step(rank, S.State{w, p, S.Blocked{None{}}, n, g}, seat, result) : S.State}:
  match rank result:
    case rank S.Act{q}:
      {==}
    case rank S.Lift{q}:
      {==}
    case 0n S.Skip{q}:
      {==}
    case 1n+r S.Skip{+q}:
      +next : D.Seat = Q.next_turn(S.players.health(q), S.world.direction(w), seat)
      irr.step(r, S.world.set_turn(w, Some{next}), q, ph, List.append(&2, D.Note, n, [D.Shown{D.TurnSkipped{seat}}]), g, next, Q.jam(q, next))

def irr.grant(+w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs, +seat: D.Seat) -> {M.grant(S.State{w, p, ph, n, g}, seat) == M.grant(S.State{w, p, S.Blocked{None{}}, n, g}, seat) : S.State}:
  irr.step(Q.jam_rank(p), S.world.set_turn(w, Some{seat}), p, ph, n, g, seat, Q.jam(p, seat))

def irr.shuffle(+i: Nat, +w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs, +ld: D.Load, +sh: List<&2, D.Shell>) -> {M.shuffle(S.State{w, p, ph, n, g}, ld, sh, i) == M.shuffle(S.State{w, p, S.Blocked{None{}}, n, g}, ld, sh, i) : S.State}:
  match i:
    case 0n:
      +w2 : S.World = S.world.set_shown(S.world.set_gun(w, sh), ld)
      irr.grant(w2, p, ph, List.append(&2, D.Note, n, [D.Shown{D.Loaded{ld}}]), g, S.world.first_turn(w2))
    case 1n+r:
      {==}

def irr.found(+selected: Maybe<&2, S.Batch>, +w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs, +index: Nat) -> {M.batch.found(S.State{w, p, ph, n, g}, index, selected) == M.batch.found(S.State{w, p, S.Blocked{None{}}, n, g}, index, selected) : S.State}:
  match selected:
    case None{}:
      {==}
    case Some{S.Batch{_, +sampled}}:
      +ld : D.Load = Q.load.actual(Q.world.load_rule(w), sampled)
      +sh : List<&2, D.Shell> = Q.load.shells(ld)
      irr.shuffle(Q.predecessor(List.length(&2, D.Shell, sh)), S.world.set_deck(w, Q.remove(S.Batch, S.world.deck(w), index)), p, ph, n, g, ld, sh)

def irr.batch(+w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs, +index: Nat) -> {M.batch(S.State{w, p, ph, n, g}, index) == M.batch(S.State{w, p, S.Blocked{None{}}, n, g}, index) : S.State}:
  irr.found(Q.nth(S.Batch, S.world.deck(w), index), w, p, ph, n, g, index)

def irr.ready(+deck: List<&2, S.Batch>, +w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs) -> {M.load.ready(S.State{w, p, ph, n, g}, deck) == M.load.ready(S.State{w, p, S.Blocked{None{}}, n, g}, deck) : S.State}:
  match deck:
    case Nil{}:
      {==}
    case only <> Nil{}:
      irr.batch(w, p, ph, n, g, 0n)
    case first <> next <> rest:
      {==}

def irr.refill(+deck: List<&2, S.Batch>, +w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs) -> {M.load.refill(S.State{w, p, ph, n, g}, deck) == M.load.refill(S.State{w, p, S.Blocked{None{}}, n, g}, deck) : S.State}:
  match deck:
    case Nil{}:
      +w2 : S.World = S.world.set_decks(w, Q.decks.full())
      irr.ready(S.world.deck(w2), w2, p, ph, n, g)
    case +first <> +rest:
      irr.ready(first <> rest, w, p, ph, n, g)

def irr.load(+w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs) -> {M.load.begin(S.State{w, p, ph, n, g}) == M.load.begin(S.State{w, p, S.Blocked{None{}}, n, g}) : S.State}:
  +w1 : S.World = S.world.set_load_index(w, Q.load.next(S.world.first_sequence(w), S.world.load_index(w)))
  +w2 : S.World = S.world.set_first_sequence(w1, False{})
  irr.refill(S.world.deck(w2), w2, p, ph, n, g)

# The distribution start (BeginItemGrabbingForSockets vs distribute.begin).

def shape.open(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> A.Shape(S.state.set_grabs(s, I.grabs.open(S.state.grabs(s), seat))):
  match s:
    case S.State{+world, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match shape:
        case Tuple{+e_players, Tuple{+e_grabbing, Tuple{+e_holding, Tuple{+e_granted, +e_intake}}}}:
          +t : D.Table = S.world.table(world)
          (e_players, (Equal.trans(D.Table, D.ring.table(Bool, D.ring.set(Bool, grabbing, seat, True{})), D.ring.table(Bool, grabbing), t, GP.set_table(Bool, grabbing, seat, True{}), e_grabbing), (Equal.trans(D.Table, D.ring.table(Maybe<&2, D.Item>, D.ring.set(Maybe<&2, D.Item>, holding, seat, None{})), D.ring.table(Maybe<&2, D.Item>, holding), t, GP.set_table(Maybe<&2, D.Item>, holding, seat, None{}), e_holding), (Equal.trans(D.Table, D.ring.table(Nat, D.ring.set(Nat, granted, seat, 0n)), D.ring.table(Nat, granted), t, GP.set_table(Nat, granted, seat, 0n), e_granted), Equal.trans(D.Table, D.ring.table(Bool, D.ring.set(Bool, intake, seat, True{})), D.ring.table(Bool, intake), t, GP.set_table(Bool, intake, seat, True{}), e_intake)))))

def shape.dist(+s: S.State, +shape: A.Shape(s)) -> A.Shape(S.state.set_grabs(s, S.grabs.set_distributing(S.state.grabs(s), True{}))):
  match s:
    case S.State{+world, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      shape

def opened(+s: S.State, +xs: List<&2, D.Seat>) -> S.State:
  S.state.set_grabs(s, I.grabs.open_all(xs, S.state.grabs(s)))

def shape.opened(+xs: List<&2, D.Seat>, +s: S.State, +shape: A.Shape(s)) -> A.Shape(opened(s, xs)):
  match xs:
    case Nil{}:
      match s:
        case S.State{+world, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          shape
    case +seat <> +rest:
      match s:
        case S.State{+world, +players, +phase, +notes, +grabs}:
          shape.opened(rest, S.State{world, players, phase, notes, I.grabs.open(grabs, seat)}, shape.open(S.State{world, players, phase, notes, grabs}, seat, shape))

def open.claim(+s: S.State, +seat: D.Seat) -> Type:
  {H.host.set_progress(H.host.set_props(qh(s), seat, H.props.grab(H.host.props(qh(s), seat))), seat, H.GrabProgress{0n, True{}}) == qh(S.state.set_grabs(s, I.grabs.open(S.state.grabs(s), seat))) : H.Host}

def open.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> open.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, D.Duo{+n1, +n3}, D.Duo{+i1, +i3}} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat), GP.clash.three_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat), GP.clash.four_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat), GP.clash.three_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat), GP.clash.four_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, seat), GP.clash.three_two(e_granted))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, seat), GP.clash.four_two(e_granted))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat), GP.clash.three_two(e_intake))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat), GP.clash.four_two(e_intake))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, D.Trio{+n0, +n1, +n2}, D.Trio{+i0, +i1, +i2}} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat), GP.clash.two_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat), GP.clash.four_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat), GP.clash.two_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat), GP.clash.four_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, seat), GP.clash.two_three(e_granted))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Quad{+n0, +n1, +n2, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Quad{n0, n1, n2, n3}, intake}}, seat), GP.clash.four_three(e_granted))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat), GP.clash.two_three(e_intake))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Quad{+i0, +i1, +i2, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Quad{i0, i1, i2, i3}}}, seat), GP.clash.four_three(e_intake))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, D.Quad{+n0, +n1, +n2, +n3}, D.Quad{+i0, +i1, +i2, +i3}} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat), GP.clash.two_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat), GP.clash.three_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat), GP.clash.two_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat), GP.clash.three_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Duo{+n1, +n3}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Duo{n1, n3}, intake}}, seat), GP.clash.two_four(e_granted))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, D.Trio{+n0, +n1, +n2}, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, D.Trio{n0, n1, n2}, intake}}, seat), GP.clash.three_four(e_granted))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Duo{+i1, +i3}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Duo{i1, i3}}}, seat), GP.clash.two_four(e_intake))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, +holding, +granted, D.Trio{+i0, +i1, +i2}} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(open.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, holding, granted, D.Trio{i0, i1, i2}}}, seat), GP.clash.three_four(e_intake))

def begin.host(+xs: List<&2, D.Seat>, +s: S.State, +shape: A.Shape(s)) -> {RI.begin_grab(xs, qh(s)) == qh(opened(s, xs)) : H.Host}:
  match xs:
    case Nil{}:
      match s:
        case S.State{+world, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          {==}
    case +seat <> +rest:
      match s:
        case S.State{+world, +players, +phase, +notes, +grabs}:
          +s0 : S.State = S.State{world, players, phase, notes, grabs}
          +s1 : S.State = S.State{world, players, phase, notes, I.grabs.open(grabs, seat)}
          +h1 : H.Host = H.host.set_progress(H.host.set_props(qh(s0), seat, H.props.grab(H.host.props(qh(s0), seat))), seat, H.GrabProgress{0n, True{}})
          Equal.trans(H.Host, RI.begin_grab(rest, h1), RI.begin_grab(rest, qh(s1)), qh(opened(s1, rest)), Equal.cong(H.Host, H.Host, h => RI.begin_grab(rest, h), h1, qh(s1), open.eq(s0, seat, shape)), begin.host(rest, s1, shape.open(s0, seat, shape)))

def dist.host(+s: S.State) -> {H.host.set_distributing(qh(s), True{}) == qh(S.state.set_grabs(s, S.grabs.set_distributing(S.state.grabs(s), True{}))) : H.Host}:
  match s:
    case S.State{S.World{+config, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
      match players grabs:
        case D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}

def grab.frame(+h: H.Host, +notes: A.Notes()) -> R.RefState:
  R.RefState{h, R.Await{D.request.choose(R.grab_menus(D.ring.entries(H.Props, H.host.seats(h)), h, D.ring.fill(List<&2, D.Move>, H.host.table(h), Nil{}))), D.Distributing{}, R.ItemGrab_Packet{}}, notes}

def distribute.close(+xs: List<&2, D.Seat>, +s: S.State, +k: Nat, +shape: A.Shape(s)) -> {R.settle(Nat.add(12n, k), R.RefState{qh(s), R.BeginItemGrabbingForSockets{xs}, S.state.notes(s)}) == A.ref(M.distribute.begin(s, xs)) : R.RefState}:
  match xs:
    case Nil{}:
      match s:
        case S.State{+w, +p, +ph, +n, +g}:
          +s0 : S.State = S.State{w, p, ph, n, g}
          %Equal.sym(S.State, M.load.begin(s0), M.load.begin(S.State{w, p, S.Blocked{None{}}, n, g}), irr.load(w, p, ph, n, g)) : {R.settle(Nat.add(12n, k), R.RefState{qh(s0), R.BeginItemGrabbingForSockets{Nil{}}, n}) == A.ref(_) : R.RefState}
          LP.load.close(S.State{w, p, S.Blocked{None{}}, n, g}, k, ISP.shape.move(w, p, ph, n, g, S.Blocked{None{}}, n, shape), {==})
    case +seat <> +rest:
      match s:
        case S.State{+w, +p, +ph, +n, +g}:
          +s0 : S.State = S.State{w, p, ph, n, g}
          +ys : List<&2, D.Seat> = seat <> rest
          +told : A.Notes() = List.append(&2, D.Note, n, [D.Shown{D.GrabbingBegan{ys}}])
          +g1 : S.Grabs = S.grabs.set_distributing(I.grabs.open_all(ys, g), True{})
          +s1 : S.State = S.State{w, p, ph, told, g1}
          +out : S.State = S.State{w, p, S.Grab{I.grab.needs(s1)}, told, g1}
          +h1 : H.Host = H.host.set_distributing(RI.begin_grab(ys, qh(s0)), True{})
          +e_host : {h1 == qh(s1) : H.Host} = Equal.trans(H.Host, h1, H.host.set_distributing(qh(opened(s0, ys)), True{}), qh(s1), Equal.cong(H.Host, H.Host, h => H.host.set_distributing(h, True{}), RI.begin_grab(ys, qh(s0)), qh(opened(s0, ys)), begin.host(ys, s0, shape)), dist.host(opened(s0, ys)))
          +shape1 : A.Shape(out) = ISP.shape.move(w, p, ph, n, g1, S.Grab{I.grab.needs(s1)}, told, shape.dist(opened(s0, ys), shape.opened(ys, s0, shape)))
          Equal.trans(R.RefState, grab.frame(h1, told), grab.frame(qh(s1), told), A.ref(out), Equal.cong(H.Host, R.RefState, h => grab.frame(h, told), h1, qh(s1), e_host), Equal.cong(D.Ring<&2, List<&2, D.Move>>, R.RefState, x => R.RefState{qh(s1), R.Await{D.request.choose(x), D.Distributing{}, R.ItemGrab_Packet{}}, told}, R.grab_menus(D.ring.entries(H.Props, H.host.seats(qh(s1))), qh(s1), D.ring.fill(List<&2, D.Move>, H.host.table(qh(s1)), Nil{})), I.grab.menus(I.grab.needs(out)), GP.menus.eq(out, shape1)))
