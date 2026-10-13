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

# Who begins grabbing: GetSocketsToBeginItemGrabbingOn vs begin.seats.

def bool.holds(b: Bool) -> Type:
  match b:
    case True{}:
      Unit
    case False{}:
      Empty

def clash.false_true(e: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, e) : bool.holds(_)
  Unit{}

def lt.succ(+a: Nat, +b: Nat, +e: {Nat.is_lt(a, b) == True{} : Bool}) -> {Nat.is_lt(a, 1n+b) == True{} : Bool}:
  match a b:
    case 0n b:
      {==}
    case 1n+x 0n:
      GP.absurd({Nat.is_lt(1n+x, 1n) == True{} : Bool}, clash.false_true(e))
    case 1n+x 1n+y:
      lt.succ(x, y, e)

def occ.lt(+xs: List<&2, Maybe<&2, D.Item>>) -> {Nat.is_lt(I.occupied(xs), 1n+List.length(&2, Maybe<&2, D.Item>, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case None{} <> +rest:
      lt.succ(I.occupied(rest), 1n+List.length(&2, Maybe<&2, D.Item>, rest), occ.lt(rest))
    case Some{x} <> +rest:
      occ.lt(rest)

def full.list(+xs: List<&2, Maybe<&2, D.Item>>) -> {Bool.not(G.slots.full(xs)) == Nat.is_lt(I.occupied(xs), List.length(&2, Maybe<&2, D.Item>, xs)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case None{} <> +rest:
      Equal.sym(Bool, Nat.is_lt(I.occupied(rest), 1n+List.length(&2, Maybe<&2, D.Item>, rest)), True{}, occ.lt(rest))
    case Some{x} <> +rest:
      full.list(rest)

def full.slots(+sl: D.Slots) -> {Bool.not(G.slots.full(G.slots.list(sl))) == Nat.is_lt(I.occupied(I.slots.items(sl)), 8n) : Bool}:
  match sl:
    case D.Slots{+a, +b, +c, +d, +e, +f, +g, +h}:
      full.list([a, b, c, d, e, f, g, h])

def nonempty.items(+xs: List<&2, D.Item>) -> {G.nonempty(D.Item, xs) == I.has_items(xs) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> rest:
      {==}

def and.cong(+a: Bool, +a2: Bool, +b: Bool, +b2: Bool, +ea: {a == a2 : Bool}, +eb: {b == b2 : Bool}) -> {Bool.and(a, b) == Bool.and(a2, b2) : Bool}:
  Equal.trans(Bool, Bool.and(a, b), Bool.and(a2, b), Bool.and(a2, b2), Equal.cong(Bool, Bool, x => Bool.and(x, b), a, a2, ea), Equal.cong(Bool, Bool, x => Bool.and(a2, x), b, b2, eb))

def or.cong(+a: Bool, +a2: Bool, +b: Bool, +b2: Bool, +ea: {a == a2 : Bool}, +eb: {b == b2 : Bool}) -> {Bool.or(a, b) == Bool.or(a2, b2) : Bool}:
  Equal.trans(Bool, Bool.or(a, b), Bool.or(a2, b), Bool.or(a2, b2), Equal.cong(Bool, Bool, x => Bool.or(x, b), a, a2, ea), Equal.cong(Bool, Bool, x => Bool.or(a2, x), b, b2, eb))

def put.keep(+b: Bool, +seat: D.Seat, +xs: List<&2, D.Seat>, +ys: List<&2, D.Seat>, +e: {xs == ys : List<&2, D.Seat>}) -> {G.turn_ring.put(b, seat, xs) == I.keep(D.Seat, b, seat, ys) : List<&2, D.Seat>}:
  match b:
    case True{}:
      Equal.cong(List<&2, D.Seat>, List<&2, D.Seat>, zs => seat <> zs, xs, ys, e)
    case False{}:
      e

def can.eq(+nr: Bool, +hp: Nat, +sl: D.Slots) -> {Bool.or(nr, Bool.and(G.alive(hp), Bool.not(G.slots.full(G.slots.list(sl))))) == I.begin.can(nr, hp, sl) : Bool}:
  or.cong(nr, nr, Bool.and(G.alive(hp), Bool.not(G.slots.full(G.slots.list(sl)))), Bool.and(Q.alive(hp), Nat.is_lt(I.occupied(I.slots.items(sl)), 8n)), {==}, and.cong(G.alive(hp), Q.alive(hp), Bool.not(G.slots.full(G.slots.list(sl))), Nat.is_lt(I.occupied(I.slots.items(sl)), 8n), LP.alive.eq(hp), full.slots(sl)))

def begin.go_eq(+s: S.State, +seats: List<&2, D.Seat>, +nr: Bool, +shape: A.Shape(s)) -> {G.GetSocketsToBeginItemGrabbingOn.go(GP.lens.entries(seats, quiet(s)), qh(s), nr) == I.begin.go(seats, s, nr) : List<&2, D.Seat>}:
  match s:
    case S.State{+w, +p, +ph, +n, +g}:
      match seats:
        case Nil{}:
          {==}
        case +seat <> +rest:
          +s0 : S.State = S.State{w, p, ph, n, g}
          +sq : S.State = S.State{w, p, S.Blocked{None{}}, n, g}
          +hp : Nat = I.seat.health(p, seat)
          +sl : D.Slots = I.seat.slots(p, seat)
          +pool_r : List<&2, D.Item> = G.GetItemToGrab.pool(D.item.order(), qh(s0), seat)
          +pool_m : List<&2, D.Item> = I.pool(s0, seat)
          +e_pool : {G.nonempty(D.Item, pool_r) == I.has_items(pool_m) : Bool} = Equal.trans(Bool, G.nonempty(D.Item, pool_r), G.nonempty(D.Item, pool_m), I.has_items(pool_m), Equal.cong(List<&2, D.Item>, Bool, xs => G.nonempty(D.Item, xs), pool_r, pool_m, GP.pool.eq(sq, seat, ISP.shape.move(w, p, ph, n, g, S.Blocked{None{}}, n, shape))), nonempty.items(pool_m))
          +e_bit : {Bool.and(Bool.or(nr, Bool.and(G.alive(hp), Bool.not(G.slots.full(G.slots.list(sl))))), G.nonempty(D.Item, pool_r)) == Bool.and(I.begin.can(nr, hp, sl), I.has_items(pool_m)) : Bool} = and.cong(Bool.or(nr, Bool.and(G.alive(hp), Bool.not(G.slots.full(G.slots.list(sl))))), I.begin.can(nr, hp, sl), G.nonempty(D.Item, pool_r), I.has_items(pool_m), can.eq(nr, hp, sl), e_pool)
          +e_rest : {G.GetSocketsToBeginItemGrabbingOn.go(GP.lens.entries(rest, sq), qh(s0), nr) == I.begin.go(rest, s0, nr) : List<&2, D.Seat>} = begin.go_eq(s0, rest, nr, shape)
          %Equal.sym(Bool, Bool.and(Bool.or(nr, Bool.and(G.alive(hp), Bool.not(G.slots.full(G.slots.list(sl))))), G.nonempty(D.Item, pool_r)), Bool.and(I.begin.can(nr, hp, sl), I.has_items(pool_m)), e_bit) : {G.turn_ring.put(_, seat, G.GetSocketsToBeginItemGrabbingOn.go(GP.lens.entries(rest, sq), qh(s0), nr)) == I.keep(D.Seat, Bool.and(I.begin.can(nr, hp, sl), I.has_items(pool_m)), seat, I.begin.go(rest, s0, nr)) : List<&2, D.Seat>}
          put.keep(Bool.and(I.begin.can(nr, hp, sl), I.has_items(pool_m)), seat, G.GetSocketsToBeginItemGrabbingOn.go(GP.lens.entries(rest, sq), qh(s0), nr), I.begin.go(rest, s0, nr), e_rest)

def begin.eq(+s: S.State, +nr: Bool, +amount: Nat, +shape: A.Shape(s)) -> {G.GetSocketsToBeginItemGrabbingOn(qh(s), nr, amount) == I.begin.seats(s, nr, amount) : List<&2, D.Seat>}:
  match s:
    case S.State{+w, +p, +ph, +n, +g}:
      match amount:
        case 0n:
          {==}
        case 1n+a:
          +s0 : S.State = S.State{w, p, ph, n, g}
          +sq : S.State = S.State{w, p, S.Blocked{None{}}, n, g}
          %GP.entries.eq(sq, ISP.shape.move(w, p, ph, n, g, S.Blocked{None{}}, n, shape)) : {G.GetSocketsToBeginItemGrabbingOn.go(_, qh(s0), nr) == I.begin.go(D.table.seats(S.world.table(w)), s0, nr) : List<&2, D.Seat>}
          begin.go_eq(s0, D.table.seats(S.world.table(w)), nr, shape)

# The end of a turn: MainRoutine_UserEndTurn vs turn.winner, and
# UserEndTurn_Packet vs turn.packet. The win (WinRoutine onward) is a premise
# until the round-start closure is proven.

def WinClosure() -> Type:
  @+s:S.State -> @+seat:D.Seat -> @+shape:A.Shape(s) -> @+k:Nat -> {R.settle(Nat.add(23n, k), R.RefState{qh(s), R.WinRoutine{seat}, S.state.notes(s)}) == A.ref(M.win(s, seat)) : R.RefState}

def empty.of(+s: S.State) -> Bool:
  Nat.is_eq(List.length(&2, D.Shell, S.world.gun(S.state.world(s))), 0n)

def end.packet(+s: S.State, +from: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>) -> R.EndPacket:
  R.EndPacket{from, passing, empty.of(s), winner}

def recipient.eq(+passing: Bool, +from: D.Seat, +a: D.Seat, +b: D.Seat, +e: {a == b : D.Seat}) -> {R.MainRoutine_UserEndTurn.recipient(passing, from, a) == M.turn.recipient(passing, from, b) : D.Seat}:
  match passing:
    case True{}:
      e
    case False{}:
      {==}

def main.close(+winner: Maybe<&2, D.Seat>, +s: S.State, +from: D.Seat, +passing: Bool, +k: Nat, +shape: A.Shape(s), win: WinClosure()) -> {R.settle(Nat.add(24n, k), R.RefState{qh(s), R.MainRoutine_UserEndTurn{end.packet(s, from, passing, winner)}, S.state.notes(s)}) == A.ref(M.turn.winner(s, from, passing, winner)) : R.RefState}:
  match winner:
    case Some{+seat}:
      win(s, seat, shape, k)
    case None{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match k:
            case k:
              +s0 : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +nr : D.Seat = G.GetNextTurn_Socket(qh(s0), from)
              +nm : D.Seat = Q.next_turn(S.players.health(p), direction, from)
              +rr : D.Seat = R.MainRoutine_UserEndTurn.recipient(passing, from, nr)
              +rm : D.Seat = M.turn.recipient(passing, from, nm)
              +e_r : {rr == rm : D.Seat} = recipient.eq(passing, from, nr, nm, LP.next.eq(s0, from, shape))
              +s1 : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +moved : {R.settle(23n+k, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rr, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rr, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), False{}, amount)}, n}) == R.settle(23n+k, R.RefState{qh(s1), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(qh(s1), False{}, amount)}, n}) : R.RefState} = Equal.cong(D.Seat, R.RefState, r => R.settle(23n+k, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, r, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, r, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), False{}, amount)}, n}), rr, rm, e_r)
              +seats : {R.settle(23n+k, R.RefState{qh(s1), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(qh(s1), False{}, amount)}, n}) == R.settle(23n+k, R.RefState{qh(s1), R.BeginItemGrabbingForSockets{I.begin.seats(s1, False{}, amount)}, n}) : R.RefState} = Equal.cong(List<&2, D.Seat>, R.RefState, xs => R.settle(23n+k, R.RefState{qh(s1), R.BeginItemGrabbingForSockets{xs}, n}), G.GetSocketsToBeginItemGrabbingOn(qh(s1), False{}, amount), I.begin.seats(s1, False{}, amount), begin.eq(s1, False{}, amount, shape))
              Equal.trans(R.RefState, R.settle(23n+k, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rr, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rr, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), False{}, amount)}, n}), R.settle(23n+k, R.RefState{qh(s1), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(qh(s1), False{}, amount)}, n}), A.ref(M.distribute.begin(s1, I.begin.seats(s1, False{}, amount))), moved, Equal.trans(R.RefState, R.settle(23n+k, R.RefState{qh(s1), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(qh(s1), False{}, amount)}, n}), R.settle(23n+k, R.RefState{qh(s1), R.BeginItemGrabbingForSockets{I.begin.seats(s1, False{}, amount)}, n}), A.ref(M.distribute.begin(s1, I.begin.seats(s1, False{}, amount))), seats, distribute.close(I.begin.seats(s1, False{}, amount), s1, Nat.add(11n, k), shape)))
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +shell <> +rest, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match k:
            case k:
              +s0 : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +nr : D.Seat = G.GetNextTurn_Socket(qh(s0), from)
              +nm : D.Seat = Q.next_turn(S.players.health(p), direction, from)
              +rr : D.Seat = R.MainRoutine_UserEndTurn.recipient(passing, from, nr)
              +rm : D.Seat = M.turn.recipient(passing, from, nm)
              +e_r : {rr == rm : D.Seat} = recipient.eq(passing, from, nr, nm, LP.next.eq(s0, from, shape))
              +rank : Nat = Q.jam_rank(p)
              +slack : Nat = Nat.add(LP.rank.slack(p), 17n+k)
              +jv : S.Jam = Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(p), rm), S.Free{})
              +moved : {R.settle(23n+k, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rr, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rr}, n}) == R.settle(23n+k, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rm}, n}) : R.RefState} = Equal.cong(D.Seat, R.RefState, r => R.settle(23n+k, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, r, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{r}, n}), rr, rm, e_r)
              +fuel : {R.settle(23n+k, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rm}, n}) == R.settle(Nat.add(2n, Nat.add(rank, slack)), R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rm}, n}) : R.RefState} = Equal.cong(Nat, R.RefState, f => R.settle(f, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rm}, n}), 23n+k, Nat.add(2n, Nat.add(rank, slack)), LP.rank.fuel(p, 17n+k))
              +passed : {R.settle(Nat.add(2n, Nat.add(rank, slack)), R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rm}, n}) == A.ref(M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, S.Blocked{None{}}, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm))) : R.RefState} = LP.pass.close(rank, jv, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, S.Blocked{None{}}, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, slack, shape, {==}, {==}, {==})
              +bridged : {A.ref(M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, S.Blocked{None{}}, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm))) == A.ref(M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm))) : R.RefState} = Equal.cong(S.State, R.RefState, x => A.ref(x), M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, S.Blocked{None{}}, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm)), M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm)), Equal.sym(S.State, M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm)), M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, S.Blocked{None{}}, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm)), irr.step(rank, S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}, rm, Q.jam(p, rm))))
              Equal.trans(R.RefState, R.settle(23n+k, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rr, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rr}, n}), R.settle(23n+k, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rm}, n}), A.ref(M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm))), moved, Equal.trans(R.RefState, R.settle(23n+k, R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rm}, n}), R.settle(Nat.add(2n, Nat.add(rank, slack)), R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rm}, n}), A.ref(M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm))), fuel, Equal.trans(R.RefState, R.settle(Nat.add(2n, Nat.add(rank, slack)), R.RefState{qh(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, turn, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}), R.PassTurn{rm}, n}), A.ref(M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, S.Blocked{None{}}, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm))), A.ref(M.grant.step(rank, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, rm, Some{rm}, direction, died, checking, amount, saw, shell <> rest, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, rm, Q.jam(p, rm))), passed, bridged)))

def nonempty.seats(+xs: List<&2, D.Seat>) -> {G.nonempty(D.Seat, xs) == I.has_seats(xs) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> rest:
      {==}

def rule.eq(+s: S.State) -> {G.load.amount(H.host.load_rule(qh(s))) == Q.load.amount(Q.world.load_rule(S.state.world(s))) : D.AmountRule}:
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      Equal.sym(D.AmountRule, Q.load.amount(Q.world.load_rule(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck})), A.turn.source_amount_rule(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p), C.aimproof.amount_rule_matches(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p))

# The reload probe: the packet's reload flag and a positive-amount begin
# list against reload.wanted.
def live.eq(+winner: Maybe<&2, D.Seat>, +s: S.State, +from: D.Seat, +passing: Bool, +shape: A.Shape(s)) -> {Bool.and(R.EndPacket.reload(end.packet(s, from, passing, winner)), G.nonempty(D.Seat, G.GetSocketsToBeginItemGrabbingOn(qh(s), False{}, 1n))) == Bool.and(I.gun.empty(S.world.gun(S.state.world(s))), Bool.and(I.winnerless(winner), I.has_seats(I.begin.seats(s, False{}, 1n)))) : Bool}:
  match winner:
    case Some{+seat}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          {==}
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +shell <> +rest, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          {==}
    case None{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +s0 : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          Equal.trans(Bool, G.nonempty(D.Seat, G.GetSocketsToBeginItemGrabbingOn(qh(s0), False{}, 1n)), G.nonempty(D.Seat, I.begin.seats(s0, False{}, 1n)), I.has_seats(I.begin.seats(s0, False{}, 1n)), Equal.cong(List<&2, D.Seat>, Bool, xs => G.nonempty(D.Seat, xs), G.GetSocketsToBeginItemGrabbingOn(qh(s0), False{}, 1n), I.begin.seats(s0, False{}, 1n), begin.eq(s0, False{}, 1n, shape)), nonempty.seats(I.begin.seats(s0, False{}, 1n)))
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +shell <> +rest, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          {==}

def packet.at(+fuel: Nat, +h: H.Host, +pkt: R.EndPacket, +notes: A.Notes(), +rule: D.AmountRule) -> R.RefState:
  R.settle(fuel, R.UserEndTurn_Packet.amount(R.RefState{h, R.UserEndTurn_Packet{pkt}, notes}, pkt, rule))

def packet.live(+live: Bool, +s: S.State, +from: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>, +k: Nat, +shape: A.Shape(s), +e_rule: {G.load.amount(H.host.load_rule(qh(s))) == D.RandomAmount{} : D.AmountRule}, win: WinClosure()) -> {R.settle(Nat.add(24n, k), R.UserEndTurn_Packet.live(R.RefState{qh(s), R.UserEndTurn_Packet{end.packet(s, from, passing, winner)}, S.state.notes(s)}, end.packet(s, from, passing, winner), live)) == A.ref(M.turn.live(s, from, passing, winner, D.RandomAmount{}, live)) : R.RefState}:
  match live:
    case True{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +s0 : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +next : R.Frame = R.MainRoutine_UserEndTurn{end.packet(s0, from, passing, winner)}
          Equal.cong(D.AmountRule, R.RefState, x => R.settle(23n+k, R.GetRandomItemGrabAmount.rule(R.RefState{qh(s0), R.GetRandomItemGrabAmount{next}, n}, next, x)), G.load.amount(H.host.load_rule(qh(s0))), D.RandomAmount{}, e_rule)
    case False{}:
      main.close(winner, s, from, passing, k, shape, win)

def packet.rule(+rule: D.AmountRule, +s: S.State, +from: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>, +k: Nat, +shape: A.Shape(s), +e_rule: {G.load.amount(H.host.load_rule(qh(s))) == rule : D.AmountRule}, win: WinClosure()) -> {packet.at(Nat.add(24n, k), qh(s), end.packet(s, from, passing, winner), S.state.notes(s), rule) == A.ref(M.turn.live(s, from, passing, winner, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(s)), I.reload.wanted(s, winner)))) : R.RefState}:
  match rule:
    case D.FixedAmount{+a}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          main.close(winner, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, a, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, from, passing, k, shape, win)
    case D.RandomAmount{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +s0 : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +pkt : R.EndPacket = end.packet(s0, from, passing, winner)
          +x : Bool = Bool.and(R.EndPacket.reload(pkt), G.nonempty(D.Seat, G.GetSocketsToBeginItemGrabbingOn(qh(s0), False{}, 1n)))
          +y : Bool = I.reload.wanted(s0, winner)
          +e_live : {Bool.or(dist, x) == Bool.or(dist, y) : Bool} = or.cong(dist, dist, x, y, {==}, live.eq(winner, s0, from, passing, shape))
          Equal.trans(R.RefState, R.settle(Nat.add(24n, k), R.UserEndTurn_Packet.live(R.RefState{qh(s0), R.UserEndTurn_Packet{pkt}, n}, pkt, Bool.or(dist, x))), R.settle(Nat.add(24n, k), R.UserEndTurn_Packet.live(R.RefState{qh(s0), R.UserEndTurn_Packet{pkt}, n}, pkt, Bool.or(dist, y))), A.ref(M.turn.live(s0, from, passing, winner, D.RandomAmount{}, Bool.or(dist, y))), Equal.cong(Bool, R.RefState, b => R.settle(Nat.add(24n, k), R.UserEndTurn_Packet.live(R.RefState{qh(s0), R.UserEndTurn_Packet{pkt}, n}, pkt, b)), Bool.or(dist, x), Bool.or(dist, y), e_live), packet.live(Bool.or(dist, y), s0, from, passing, winner, k, shape, e_rule, win))

def packet.close(+s: S.State, +from: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>, +k: Nat, +shape: A.Shape(s), win: WinClosure()) -> {R.settle(Nat.add(25n, k), R.RefState{qh(s), R.UserEndTurn_Packet{end.packet(s, from, passing, winner)}, S.state.notes(s)}) == A.ref(M.turn.packet(s, from, passing, winner)) : R.RefState}:
  +pkt : R.EndPacket = end.packet(s, from, passing, winner)
  +rule_r : D.AmountRule = G.load.amount(H.host.load_rule(qh(s)))
  +rule_m : D.AmountRule = Q.load.amount(Q.world.load_rule(S.state.world(s)))
  Equal.trans(R.RefState, packet.at(Nat.add(24n, k), qh(s), pkt, S.state.notes(s), rule_r), packet.at(Nat.add(24n, k), qh(s), pkt, S.state.notes(s), rule_m), A.ref(M.turn.packet(s, from, passing, winner)), Equal.cong(D.AmountRule, R.RefState, x => packet.at(Nat.add(24n, k), qh(s), pkt, S.state.notes(s), x), rule_r, rule_m, rule.eq(s)), packet.rule(rule_m, s, from, passing, winner, k, shape, rule.eq(s), win))
