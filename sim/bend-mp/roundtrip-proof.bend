import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/items.bend as I
import ./sm/rules.bend as Q
import ./ref/main.bend as R
import ./ref/state.bend as H
import ./ref/items.bend as RI
import ./grab-proof.bend as GP
import ./item-step-proof.bend as ISP
import ./load-proof.bend as LP
import ./turn-proof.bend as T

# state_roundtrip: A.back inverts A.ref at every valid state. The world, the
# seats and the Grabs come back field by field (the Grabs rings have the
# table's shape); a recomputed menu comes back from the reference's rendering
# of it (the item normal form); a blocked holder comes back from has_turn
# (it sits at the table).

def batches.back(+deck: List<&2, S.Batch>) -> {deck == A.back.batches(A.batches(deck)) : List<&2, S.Batch>}:
  match deck:
    case Nil{}:
      {==}
    case S.Batch{+id, +load} <> +rest:
      %batches.back(rest) : {S.Batch{id, load} <> rest == S.Batch{id, load} <> _ : List<&2, S.Batch>}
      {==}

def world.back(+w: S.World, +p: S.Players, +g: S.Grabs, +holder: Maybe<&2, D.Seat>) -> {w == A.back.world(A.host.at(w, p, g, holder)) : S.World}:
  match w:
    case S.World{+config, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+a, +b, +c}}:
      %batches.back(a) : {S.World{config, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{a, b, c}} == S.World{config, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{_, A.back.batches(A.batches(b)), A.back.batches(A.batches(c))}} : S.World}
      %batches.back(b) : {S.World{config, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{a, b, c}} == S.World{config, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{a, _, A.back.batches(A.batches(c))}} : S.World}
      %batches.back(c) : {S.World{config, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{a, b, c}} == S.World{config, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{a, b, _}} : S.World}
      {==}

# A seat's jam comes back from the reference's (jammed, checked) pair.
def seat.back(+x: S.Seat, +g: S.Grabs, +holder: Maybe<&2, D.Seat>, +at: D.Seat) -> {x == A.back.props(A.seat.props.at(x, g, holder, at)) : S.Seat}:
  match x:
    case S.Seat{hp, S.Free{}, cash, slots}:
      {==}
    case S.Seat{hp, S.Jammed{}, cash, slots}:
      {==}
    case S.Seat{hp, S.JammedSkipped{}, cash, slots}:
      {==}

def seats.back(+p: S.Players, +g: S.Grabs, +holder: Maybe<&2, D.Seat>) -> {p == A.back.seats(A.props.at(p, g, holder)) : S.Players}:
  match p:
    case D.Duo{+a, +b}:
      %seat.back(a, g, holder, D.Seat1{}) : {D.Duo{a, b} == D.Duo{_, A.back.props(A.seat.props.at(b, g, holder, D.Seat3{}))} : S.Players}
      %seat.back(b, g, holder, D.Seat3{}) : {D.Duo{a, b} == D.Duo{a, _} : S.Players}
      {==}
    case D.Trio{+a, +b, +c}:
      %seat.back(a, g, holder, D.Seat0{}) : {D.Trio{a, b, c} == D.Trio{_, A.back.props(A.seat.props.at(b, g, holder, D.Seat1{})), A.back.props(A.seat.props.at(c, g, holder, D.Seat2{}))} : S.Players}
      %seat.back(b, g, holder, D.Seat1{}) : {D.Trio{a, b, c} == D.Trio{a, _, A.back.props(A.seat.props.at(c, g, holder, D.Seat2{}))} : S.Players}
      %seat.back(c, g, holder, D.Seat2{}) : {D.Trio{a, b, c} == D.Trio{a, b, _} : S.Players}
      {==}
    case D.Quad{+a, +b, +c, +d}:
      %seat.back(a, g, holder, D.Seat0{}) : {D.Quad{a, b, c, d} == D.Quad{_, A.back.props(A.seat.props.at(b, g, holder, D.Seat1{})), A.back.props(A.seat.props.at(c, g, holder, D.Seat2{})), A.back.props(A.seat.props.at(d, g, holder, D.Seat3{}))} : S.Players}
      %seat.back(b, g, holder, D.Seat1{}) : {D.Quad{a, b, c, d} == D.Quad{a, _, A.back.props(A.seat.props.at(c, g, holder, D.Seat2{})), A.back.props(A.seat.props.at(d, g, holder, D.Seat3{}))} : S.Players}
      %seat.back(c, g, holder, D.Seat2{}) : {D.Quad{a, b, c, d} == D.Quad{a, b, _, A.back.props(A.seat.props.at(d, g, holder, D.Seat3{}))} : S.Players}
      %seat.back(d, g, holder, D.Seat3{}) : {D.Quad{a, b, c, d} == D.Quad{a, b, c, _} : S.Players}
      {==}

def ring.duo(-X: Data, +r: D.Ring<&2, X>, +fallback: X, +e: {D.ring.table(X, r) == D.TwoSeats{} : D.Table}) -> {r == D.Duo{Q.value.or(X, D.ring.get(X, r, D.Seat1{}), fallback), Q.value.or(X, D.ring.get(X, r, D.Seat3{}), fallback)} : D.Ring<&2, X>}:
  match r:
    case D.Duo{a, b}:
      {==}
    case D.Trio{a, b, c}:
      GP.absurd({D.Trio{a, b, c} == D.Duo{Q.value.or(X, D.ring.get(X, D.Trio{a, b, c}, D.Seat1{}), fallback), Q.value.or(X, D.ring.get(X, D.Trio{a, b, c}, D.Seat3{}), fallback)} : D.Ring<&2, X>}, GP.clash.three_two(e))
    case D.Quad{a, b, c, d}:
      GP.absurd({D.Quad{a, b, c, d} == D.Duo{Q.value.or(X, D.ring.get(X, D.Quad{a, b, c, d}, D.Seat1{}), fallback), Q.value.or(X, D.ring.get(X, D.Quad{a, b, c, d}, D.Seat3{}), fallback)} : D.Ring<&2, X>}, GP.clash.four_two(e))

def ring.trio(-X: Data, +r: D.Ring<&2, X>, +fallback: X, +e: {D.ring.table(X, r) == D.ThreeSeats{} : D.Table}) -> {r == D.Trio{Q.value.or(X, D.ring.get(X, r, D.Seat0{}), fallback), Q.value.or(X, D.ring.get(X, r, D.Seat1{}), fallback), Q.value.or(X, D.ring.get(X, r, D.Seat2{}), fallback)} : D.Ring<&2, X>}:
  match r:
    case D.Duo{a, b}:
      GP.absurd({D.Duo{a, b} == D.Trio{Q.value.or(X, D.ring.get(X, D.Duo{a, b}, D.Seat0{}), fallback), Q.value.or(X, D.ring.get(X, D.Duo{a, b}, D.Seat1{}), fallback), Q.value.or(X, D.ring.get(X, D.Duo{a, b}, D.Seat2{}), fallback)} : D.Ring<&2, X>}, GP.clash.two_three(e))
    case D.Trio{a, b, c}:
      {==}
    case D.Quad{a, b, c, d}:
      GP.absurd({D.Quad{a, b, c, d} == D.Trio{Q.value.or(X, D.ring.get(X, D.Quad{a, b, c, d}, D.Seat0{}), fallback), Q.value.or(X, D.ring.get(X, D.Quad{a, b, c, d}, D.Seat1{}), fallback), Q.value.or(X, D.ring.get(X, D.Quad{a, b, c, d}, D.Seat2{}), fallback)} : D.Ring<&2, X>}, GP.clash.four_three(e))

def ring.quad(-X: Data, +r: D.Ring<&2, X>, +fallback: X, +e: {D.ring.table(X, r) == D.FourSeats{} : D.Table}) -> {r == D.Quad{Q.value.or(X, D.ring.get(X, r, D.Seat0{}), fallback), Q.value.or(X, D.ring.get(X, r, D.Seat1{}), fallback), Q.value.or(X, D.ring.get(X, r, D.Seat2{}), fallback), Q.value.or(X, D.ring.get(X, r, D.Seat3{}), fallback)} : D.Ring<&2, X>}:
  match r:
    case D.Duo{a, b}:
      GP.absurd({D.Duo{a, b} == D.Quad{Q.value.or(X, D.ring.get(X, D.Duo{a, b}, D.Seat0{}), fallback), Q.value.or(X, D.ring.get(X, D.Duo{a, b}, D.Seat1{}), fallback), Q.value.or(X, D.ring.get(X, D.Duo{a, b}, D.Seat2{}), fallback), Q.value.or(X, D.ring.get(X, D.Duo{a, b}, D.Seat3{}), fallback)} : D.Ring<&2, X>}, GP.clash.two_four(e))
    case D.Trio{a, b, c}:
      GP.absurd({D.Trio{a, b, c} == D.Quad{Q.value.or(X, D.ring.get(X, D.Trio{a, b, c}, D.Seat0{}), fallback), Q.value.or(X, D.ring.get(X, D.Trio{a, b, c}, D.Seat1{}), fallback), Q.value.or(X, D.ring.get(X, D.Trio{a, b, c}, D.Seat2{}), fallback), Q.value.or(X, D.ring.get(X, D.Trio{a, b, c}, D.Seat3{}), fallback)} : D.Ring<&2, X>}, GP.clash.three_four(e))
    case D.Quad{a, b, c, d}:
      {==}

# The Grabs come back from the props and progress rings, which have the seat
# ring's shape; Shape ties every Grabs ring to that shape.
def grabs.back(+w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs, +holder: Maybe<&2, D.Seat>, +shape: A.Shape(S.State{w, p, ph, n, g})) -> {g == A.back.grabs(A.host.at(w, p, g, holder)) : S.Grabs}:
  match w p g:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.Duo{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}} S.Grabs{+d, +gr, +ho, +gn, +ik}:
      match shape:
        case Tuple{+ep, Tuple{+egr, Tuple{+eho, Tuple{+egn, +eik}}}}:
          +P : S.Players = D.Duo{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}}
          +G : S.Grabs = S.Grabs{d, gr, ho, gn, ik}
          %ring.duo(Bool, gr, False{}, Equal.trans(D.Table, D.ring.table(Bool, gr), table, D.TwoSeats{}, egr, Equal.sym(D.Table, D.TwoSeats{}, table, ep))) : {G == S.Grabs{d, _, A.back.holding(A.props.at(P, G, holder)), A.back.granted(A.progress.at(P, G)), A.back.intake(A.progress.at(P, G))} : S.Grabs}
          %ring.duo(Maybe<&2, D.Item>, ho, None{}, Equal.trans(D.Table, D.ring.table(Maybe<&2, D.Item>, ho), table, D.TwoSeats{}, eho, Equal.sym(D.Table, D.TwoSeats{}, table, ep))) : {G == S.Grabs{d, gr, _, A.back.granted(A.progress.at(P, G)), A.back.intake(A.progress.at(P, G))} : S.Grabs}
          %ring.duo(Nat, gn, 0n, Equal.trans(D.Table, D.ring.table(Nat, gn), table, D.TwoSeats{}, egn, Equal.sym(D.Table, D.TwoSeats{}, table, ep))) : {G == S.Grabs{d, gr, ho, _, A.back.intake(A.progress.at(P, G))} : S.Grabs}
          %ring.duo(Bool, ik, False{}, Equal.trans(D.Table, D.ring.table(Bool, ik), table, D.TwoSeats{}, eik, Equal.sym(D.Table, D.TwoSeats{}, table, ep))) : {G == S.Grabs{d, gr, ho, gn, _} : S.Grabs}
          {==}
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+d, +gr, +ho, +gn, +ik}:
      match shape:
        case Tuple{+ep, Tuple{+egr, Tuple{+eho, Tuple{+egn, +eik}}}}:
          +P : S.Players = D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}
          +G : S.Grabs = S.Grabs{d, gr, ho, gn, ik}
          %ring.trio(Bool, gr, False{}, Equal.trans(D.Table, D.ring.table(Bool, gr), table, D.ThreeSeats{}, egr, Equal.sym(D.Table, D.ThreeSeats{}, table, ep))) : {G == S.Grabs{d, _, A.back.holding(A.props.at(P, G, holder)), A.back.granted(A.progress.at(P, G)), A.back.intake(A.progress.at(P, G))} : S.Grabs}
          %ring.trio(Maybe<&2, D.Item>, ho, None{}, Equal.trans(D.Table, D.ring.table(Maybe<&2, D.Item>, ho), table, D.ThreeSeats{}, eho, Equal.sym(D.Table, D.ThreeSeats{}, table, ep))) : {G == S.Grabs{d, gr, _, A.back.granted(A.progress.at(P, G)), A.back.intake(A.progress.at(P, G))} : S.Grabs}
          %ring.trio(Nat, gn, 0n, Equal.trans(D.Table, D.ring.table(Nat, gn), table, D.ThreeSeats{}, egn, Equal.sym(D.Table, D.ThreeSeats{}, table, ep))) : {G == S.Grabs{d, gr, ho, _, A.back.intake(A.progress.at(P, G))} : S.Grabs}
          %ring.trio(Bool, ik, False{}, Equal.trans(D.Table, D.ring.table(Bool, ik), table, D.ThreeSeats{}, eik, Equal.sym(D.Table, D.ThreeSeats{}, table, ep))) : {G == S.Grabs{d, gr, ho, gn, _} : S.Grabs}
          {==}
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+d, +gr, +ho, +gn, +ik}:
      match shape:
        case Tuple{+ep, Tuple{+egr, Tuple{+eho, Tuple{+egn, +eik}}}}:
          +P : S.Players = D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}
          +G : S.Grabs = S.Grabs{d, gr, ho, gn, ik}
          %ring.quad(Bool, gr, False{}, Equal.trans(D.Table, D.ring.table(Bool, gr), table, D.FourSeats{}, egr, Equal.sym(D.Table, D.FourSeats{}, table, ep))) : {G == S.Grabs{d, _, A.back.holding(A.props.at(P, G, holder)), A.back.granted(A.progress.at(P, G)), A.back.intake(A.progress.at(P, G))} : S.Grabs}
          %ring.quad(Maybe<&2, D.Item>, ho, None{}, Equal.trans(D.Table, D.ring.table(Maybe<&2, D.Item>, ho), table, D.FourSeats{}, eho, Equal.sym(D.Table, D.FourSeats{}, table, ep))) : {G == S.Grabs{d, gr, _, A.back.granted(A.progress.at(P, G)), A.back.intake(A.progress.at(P, G))} : S.Grabs}
          %ring.quad(Nat, gn, 0n, Equal.trans(D.Table, D.ring.table(Nat, gn), table, D.FourSeats{}, egn, Equal.sym(D.Table, D.FourSeats{}, table, ep))) : {G == S.Grabs{d, gr, ho, _, A.back.intake(A.progress.at(P, G))} : S.Grabs}
          %ring.quad(Bool, ik, False{}, Equal.trans(D.Table, D.ring.table(Bool, ik), table, D.FourSeats{}, eik, Equal.sym(D.Table, D.FourSeats{}, table, ep))) : {G == S.Grabs{d, gr, ho, gn, _} : S.Grabs}
          {==}

# With no holder, every has_turn is clear.
def holder.none(+p: S.Players, +g: S.Grabs) -> {None{} == A.back.holder(D.ring.entries(H.Props, A.props.at(p, g, None{}))) : Maybe<&2, D.Seat>}:
  match p:
    case D.Duo{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}}:
      {==}
    case D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}:
      {==}
    case D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}:
      {==}

# A seated holder is the one seat whose has_turn is set.
def holder.some(+p: S.Players, +g: S.Grabs, +seat: D.Seat, +has: A.Holds(A.table.has(D.ring.table(S.Seat, p), seat))) -> {Some{seat} == A.back.holder(D.ring.entries(H.Props, A.props.at(p, g, Some{seat}))) : Maybe<&2, D.Seat>}:
  match p seat:
    case D.Duo{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}} D.Seat0{}:
      GP.absurd({Some{D.Seat0{}} == A.back.holder(D.ring.entries(H.Props, A.props.at(D.Duo{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}}, g, Some{D.Seat0{}}))) : Maybe<&2, D.Seat>}, T.clash.false_true(has))
    case D.Duo{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}} D.Seat1{}:
      {==}
    case D.Duo{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}} D.Seat2{}:
      GP.absurd({Some{D.Seat2{}} == A.back.holder(D.ring.entries(H.Props, A.props.at(D.Duo{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}}, g, Some{D.Seat2{}}))) : Maybe<&2, D.Seat>}, T.clash.false_true(has))
    case D.Duo{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}} D.Seat3{}:
      {==}
    case D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}} D.Seat0{}:
      {==}
    case D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}} D.Seat1{}:
      {==}
    case D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}} D.Seat2{}:
      {==}
    case D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}} D.Seat3{}:
      GP.absurd({Some{D.Seat3{}} == A.back.holder(D.ring.entries(H.Props, A.props.at(D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, g, Some{D.Seat3{}}))) : Maybe<&2, D.Seat>}, T.clash.false_true(has))
    case D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}} D.Seat0{}:
      {==}
    case D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}} D.Seat1{}:
      {==}
    case D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}} D.Seat2{}:
      {==}
    case D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}} D.Seat3{}:
      {==}

# The machine state from ref's parts, given its phase comes back.
def parts(+w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs, +shape: A.Shape(S.State{w, p, ph, n, g}), +eph: {ph == A.back.phase(A.frame(ph, A.host.at(w, p, g, A.turn.holder(ph))), A.host.at(w, p, g, A.turn.holder(ph))) : S.Phase}) -> {A.back(A.ref(S.State{w, p, ph, n, g})) == S.State{w, p, ph, n, g} : S.State}:
  match w:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      +W : S.World = S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}
      +holder : Maybe<&2, D.Seat> = A.turn.holder(ph)
      +h : A.RefHost() = A.host.at(W, p, g, holder)
      %world.back(W, p, g, holder) : {S.State{_, A.back.seats(A.props.at(p, g, holder)), A.back.phase(A.frame(ph, h), h), n, A.back.grabs(h)} == S.State{W, p, ph, n, g} : S.State}
      %seats.back(p, g, holder) : {S.State{W, _, A.back.phase(A.frame(ph, h), h), n, A.back.grabs(h)} == S.State{W, p, ph, n, g} : S.State}
      %eph : {S.State{W, p, _, n, A.back.grabs(h)} == S.State{W, p, ph, n, g} : S.State}
      %grabs.back(W, p, ph, n, g, holder, shape) : {S.State{W, p, ph, n, _} == S.State{W, p, ph, n, g} : S.State}
      {==}

def players.table(+w: S.World, +p: S.Players, +ph: S.Phase, +n: A.Notes(), +g: S.Grabs, +shape: A.Shape(S.State{w, p, ph, n, g})) -> {D.ring.table(S.Seat, p) == S.world.table(w) : D.Table}:
  match g:
    case S.Grabs{+d, +gr, +ho, +gn, +ik}:
      match shape:
        case Tuple{+ep, _}:
          ep

def batch.back(+deck: List<&2, H.Batch>, +h: A.RefHost()) -> {S.NeedBatch{} == A.back.phase(A.batch.frame(deck), h) : S.Phase}:
  match deck:
    case Nil{}:
      {==}
    case a <> Nil{}:
      {==}
    case a <> b <> rest:
      {==}

def idle_options.back(+xs: List<&2, S.IdleOption>) -> {xs == A.back.idle_options(Q.idle.moves(xs)) : List<&2, S.IdleOption>}:
  match xs:
    case Nil{}:
      {==}
    case S.TakeGun{} <> +rest:
      %idle_options.back(rest) : {S.TakeGun{} <> rest == S.TakeGun{} <> _ : List<&2, S.IdleOption>}
      {==}
    case S.UseAt{+slot, +item} <> +rest:
      %idle_options.back(rest) : {S.UseAt{slot, item} <> rest == S.UseAt{slot, item} <> _ : List<&2, S.IdleOption>}
      {==}

def jams.back(+xs: List<&2, S.JamOption>) -> {xs == A.back.jams(I.jam.moves(xs)) : List<&2, S.JamOption>}:
  match xs:
    case Nil{}:
      {==}
    case S.JamAt{+seat} <> +rest:
      %jams.back(rest) : {S.JamAt{seat} <> rest == S.JamAt{seat} <> _ : List<&2, S.JamOption>}
      {==}

def steals.back(+xs: List<&2, S.StealOption>) -> {xs == A.back.steals(I.steal.moves(xs)) : List<&2, S.StealOption>}:
  match xs:
    case Nil{}:
      {==}
    case S.Pick{+owner, +slot, +item} <> +rest:
      %steals.back(rest) : {S.Pick{owner, slot, item} <> rest == S.Pick{owner, slot, item} <> _ : List<&2, S.StealOption>}
      {==}

def grab_options.back(+xs: List<&2, S.GrabOption>) -> {xs == A.back.grab_options(I.grab.moves(xs)) : List<&2, S.GrabOption>}:
  match xs:
    case Nil{}:
      {==}
    case S.TakeItem{} <> +rest:
      %grab_options.back(rest) : {S.TakeItem{} <> rest == S.TakeItem{} <> _ : List<&2, S.GrabOption>}
      {==}
    case S.PutAt{+slot} <> +rest:
      %grab_options.back(rest) : {S.PutAt{slot} <> rest == S.PutAt{slot} <> _ : List<&2, S.GrabOption>}
      {==}

def needs.back(+r: D.Ring<&2, List<&2, S.GrabOption>>) -> {r == A.back.needs(I.grab.menus(r)) : D.Ring<&2, List<&2, S.GrabOption>>}:
  match r:
    case D.Duo{+a, +b}:
      %grab_options.back(a) : {D.Duo{a, b} == D.Duo{_, A.back.grab_options(I.grab.moves(b))} : D.Ring<&2, List<&2, S.GrabOption>>}
      %grab_options.back(b) : {D.Duo{a, b} == D.Duo{a, _} : D.Ring<&2, List<&2, S.GrabOption>>}
      {==}
    case D.Trio{+a, +b, +c}:
      %grab_options.back(a) : {D.Trio{a, b, c} == D.Trio{_, A.back.grab_options(I.grab.moves(b)), A.back.grab_options(I.grab.moves(c))} : D.Ring<&2, List<&2, S.GrabOption>>}
      %grab_options.back(b) : {D.Trio{a, b, c} == D.Trio{a, _, A.back.grab_options(I.grab.moves(c))} : D.Ring<&2, List<&2, S.GrabOption>>}
      %grab_options.back(c) : {D.Trio{a, b, c} == D.Trio{a, b, _} : D.Ring<&2, List<&2, S.GrabOption>>}
      {==}
    case D.Quad{+a, +b, +c, +d}:
      %grab_options.back(a) : {D.Quad{a, b, c, d} == D.Quad{_, A.back.grab_options(I.grab.moves(b)), A.back.grab_options(I.grab.moves(c)), A.back.grab_options(I.grab.moves(d))} : D.Ring<&2, List<&2, S.GrabOption>>}
      %grab_options.back(b) : {D.Quad{a, b, c, d} == D.Quad{a, _, A.back.grab_options(I.grab.moves(c)), A.back.grab_options(I.grab.moves(d))} : D.Ring<&2, List<&2, S.GrabOption>>}
      %grab_options.back(c) : {D.Quad{a, b, c, d} == D.Quad{a, b, _, A.back.grab_options(I.grab.moves(d))} : D.Ring<&2, List<&2, S.GrabOption>>}
      %grab_options.back(d) : {D.Quad{a, b, c, d} == D.Quad{a, b, c, _} : D.Ring<&2, List<&2, S.GrabOption>>}
      {==}

# The normal form of a valid state comes back, by the phase.
def roundtrip.normal(+s: S.State, +shape: A.Shape(s), +ready: A.Holds(A.items_ready(S.state.phase(s), S.state.world(s)))) -> {A.back(A.ref(A.normalize_items(s))) == A.normalize_items(s) : S.State}:
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      match ph:
        case S.NeedFirst{}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedFirst{}, n, g, shape, {==})
        case S.NeedHealth{}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedHealth{}, n, g, shape, {==})
        case S.NeedAmount{}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedAmount{}, n, g, shape, {==})
        case S.NeedBatch{}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedBatch{}, n, g, shape, batch.back(H.host.deck(A.host.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, None{})), A.host.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, None{})))
        case S.NeedSwap{+ld, +sh, 0n}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Blocked{None{}}, n, g, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedSwap{ld, sh, 0n}, n, g, S.Blocked{None{}}, n, shape), Equal.cong(Maybe<&2, D.Seat>, S.Phase, x => S.Blocked{x}, None{}, A.back.holder(D.ring.entries(H.Props, A.props.at(p, g, None{}))), holder.none(p, g)))
        case S.NeedSwap{+ld, +sh, 1n+k}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedSwap{ld, sh, 1n+k}, n, g, shape, {==})
        case S.Idle{+seat, +opts}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Idle{seat, opts}, n, g}
          +shape_st : A.Shape(st) = shape
          +e_list : {I.uses(st, seat) == A.back.idle_options(RI.use_moves(I.slot.order(), A.ref_host(st), seat)) : List<&2, S.IdleOption>} = Equal.trans(List<&2, S.IdleOption>, I.uses(st, seat), A.back.idle_options(Q.idle.moves(I.uses(st, seat))), A.back.idle_options(RI.use_moves(I.slot.order(), A.ref_host(st), seat)), idle_options.back(I.uses(st, seat)), Equal.cong(List<&2, D.Move>, List<&2, S.IdleOption>, ms => A.back.idle_options(ms), Q.idle.moves(I.uses(st, seat)), RI.use_moves(I.slot.order(), A.ref_host(st), seat), Equal.sym(List<&2, D.Move>, RI.use_moves(I.slot.order(), A.ref_host(st), seat), Q.idle.moves(I.uses(st, seat)), LP.uses.eq(st, seat, shape_st))))
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, I.uses(st, seat)}}, n, g, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Idle{seat, opts}, n, g, S.Idle{seat, D.NonEmpty{S.TakeGun{}, I.uses(st, seat)}}, n, shape), Equal.cong(List<&2, S.IdleOption>, S.Phase, xs => S.Idle{seat, D.NonEmpty{S.TakeGun{}, xs}}, I.uses(st, seat), A.back.idle_options(RI.use_moves(I.slot.order(), A.ref_host(st), seat)), e_list))
        case S.Aim{+seat}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Aim{seat}, n, g, shape, {==})
        case S.Ended{}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Ended{}, n, g, shape, {==})
        case S.Blocked{None{}}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Blocked{None{}}, n, g, shape, Equal.cong(Maybe<&2, D.Seat>, S.Phase, x => S.Blocked{x}, None{}, A.back.holder(D.ring.entries(H.Props, A.props.at(p, g, None{}))), holder.none(p, g)))
        case S.Blocked{Some{+seat}}:
          +has : A.Holds(A.table.has(D.ring.table(S.Seat, p), seat)) = Equal.trans(Bool, A.table.has(D.ring.table(S.Seat, p), seat), A.table.has(table, seat), True{}, Equal.cong(D.Table, Bool, t => A.table.has(t, seat), D.ring.table(S.Seat, p), table, players.table(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Blocked{Some{seat}}, n, g, shape)), ready)
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Blocked{Some{seat}}, n, g, shape, Equal.cong(Maybe<&2, D.Seat>, S.Phase, x => S.Blocked{x}, Some{seat}, A.back.holder(D.ring.entries(H.Props, A.props.at(p, g, Some{seat}))), holder.some(p, g, seat, has)))
        case S.NeedTurnAmount{+from, +passing, +winner}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedTurnAmount{from, passing, winner}, n, g, shape, {==})
        case S.Grab{+needs}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Grab{needs}, n, g}
          +shape_st : A.Shape(st) = shape
          +e_list : {I.grab.needs(st) == A.back.needs(R.grab_menus(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), A.ref_host(st), D.ring.fill(List<&2, D.Move>, H.host.table(A.ref_host(st)), Nil{}))) : D.Ring<&2, List<&2, S.GrabOption>>} = Equal.trans(D.Ring<&2, List<&2, S.GrabOption>>, I.grab.needs(st), A.back.needs(I.grab.menus(I.grab.needs(st))), A.back.needs(R.grab_menus(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), A.ref_host(st), D.ring.fill(List<&2, D.Move>, H.host.table(A.ref_host(st)), Nil{}))), needs.back(I.grab.needs(st)), Equal.cong(D.Ring<&2, List<&2, D.Move>>, D.Ring<&2, List<&2, S.GrabOption>>, ms => A.back.needs(ms), I.grab.menus(I.grab.needs(st)), R.grab_menus(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), A.ref_host(st), D.ring.fill(List<&2, D.Move>, H.host.table(A.ref_host(st)), Nil{})), Equal.sym(D.Ring<&2, List<&2, D.Move>>, R.grab_menus(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), A.ref_host(st), D.ring.fill(List<&2, D.Move>, H.host.table(A.ref_host(st)), Nil{})), I.grab.menus(I.grab.needs(st)), GP.menus.eq(st, shape_st))))
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Grab{I.grab.needs(st)}, n, g, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Grab{needs}, n, g, S.Grab{I.grab.needs(st)}, n, shape), Equal.cong(D.Ring<&2, List<&2, S.GrabOption>>, S.Phase, xs => S.Grab{xs}, I.grab.needs(st), A.back.needs(R.grab_menus(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), A.ref_host(st), D.ring.fill(List<&2, D.Move>, H.host.table(A.ref_host(st)), Nil{}))), e_list))
        case S.NeedItem{+seat, +one, +two, +rest}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedItem{seat, one, two, rest}, n, g, shape, {==})
        case S.NeedPhone{+seat, +owner, +slot}:
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedPhone{seat, owner, slot}, n, g, shape, {==})
        case S.JamPick{+seat, +targets}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.JamPick{seat, targets}, n, g}
          +shape_st : A.Shape(st) = shape
          +e_list : {I.jam.for(st, seat) == A.back.jams(RI.jam_moves(RI.jam_targets(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), seat))) : List<&2, S.JamOption>} = Equal.trans(List<&2, S.JamOption>, I.jam.for(st, seat), A.back.jams(I.jam.moves(I.jam.for(st, seat))), A.back.jams(RI.jam_moves(RI.jam_targets(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), seat))), jams.back(I.jam.for(st, seat)), Equal.cong(List<&2, D.Move>, List<&2, S.JamOption>, ms => A.back.jams(ms), I.jam.moves(I.jam.for(st, seat)), RI.jam_moves(RI.jam_targets(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), seat)), Equal.sym(List<&2, D.Move>, RI.jam_moves(RI.jam_targets(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), seat)), I.jam.moves(I.jam.for(st, seat)), LP.jam.eq(st, seat, shape_st))))
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.JamPick{seat, I.jam.for(st, seat)}, n, g, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.JamPick{seat, targets}, n, g, S.JamPick{seat, I.jam.for(st, seat)}, n, shape), Equal.cong(List<&2, S.JamOption>, S.Phase, xs => S.JamPick{seat, xs}, I.jam.for(st, seat), A.back.jams(RI.jam_moves(RI.jam_targets(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), seat))), e_list))
        case S.StealPick{+seat, +picks}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.StealPick{seat, picks}, n, g}
          +shape_st : A.Shape(st) = shape
          +e_list : {I.steal.for(st, seat) == A.back.steals(RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), A.ref_host(st), seat)) : List<&2, S.StealOption>} = Equal.trans(List<&2, S.StealOption>, I.steal.for(st, seat), A.back.steals(I.steal.moves(I.steal.for(st, seat))), A.back.steals(RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), A.ref_host(st), seat)), steals.back(I.steal.for(st, seat)), Equal.cong(List<&2, D.Move>, List<&2, S.StealOption>, ms => A.back.steals(ms), I.steal.moves(I.steal.for(st, seat)), RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), A.ref_host(st), seat), Equal.sym(List<&2, D.Move>, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), A.ref_host(st), seat), I.steal.moves(I.steal.for(st, seat)), LP.steal.eq(st, seat, shape_st))))
          parts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.StealPick{seat, I.steal.for(st, seat)}, n, g, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.StealPick{seat, picks}, n, g, S.StealPick{seat, I.steal.for(st, seat)}, n, shape), Equal.cong(List<&2, S.StealOption>, S.Phase, xs => S.StealPick{seat, xs}, I.steal.for(st, seat), A.back.steals(RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), A.ref_host(st), seat)), e_list))

def law.state_roundtrip(+state: S.State, +valid: A.Valid(state)) -> {A.back(A.ref(state)) == state : S.State}:
  %A.valid.normal(state, valid) : {A.back(A.ref(_)) == _ : S.State}
  roundtrip.normal(state, A.valid.shape(state, valid), A.valid.ready(state, valid))
