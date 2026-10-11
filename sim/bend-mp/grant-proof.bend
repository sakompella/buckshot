import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/main.bend as M
import ./sm/rules.bend as Q

def machine_jam(+seats: A.Seats(), +seat: D.Seat) -> {Q.jam(A.players(seats), seat) == A.grant.players(A.grant.jam(seats, seat)) : S.JamResult}:
  match seats seat:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      {==}
    case D.Duo{A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Duo{A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Duo{A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, False{}, c3, p3, s3, t3}} D.Seat3{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, True{}, False{}, p3, s3, t3}} D.Seat3{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, True{}, True{}, p3, s3, t3}} D.Seat3{}:
      {==}
    case D.Trio{A.CoreSeat{h0, False{}, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      {==}
    case D.Trio{A.CoreSeat{h0, True{}, False{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      {==}
    case D.Trio{A.CoreSeat{h0, True{}, True{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, False{}, c2, p2, s2, t2}} D.Seat2{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, False{}, p2, s2, t2}} D.Seat2{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, True{}, p2, s2, t2}} D.Seat2{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
      {==}
    case D.Quad{A.CoreSeat{h0, False{}, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      {==}
    case D.Quad{A.CoreSeat{h0, True{}, False{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      {==}
    case D.Quad{A.CoreSeat{h0, True{}, True{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, False{}, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, False{}, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, True{}, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, False{}, c3, p3, s3, t3}} D.Seat3{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, True{}, False{}, p3, s3, t3}} D.Seat3{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, True{}, True{}, p3, s3, t3}} D.Seat3{}:
      {==}

def ref_pass(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes()) -> {A.grant.dispatch(A.grant.pass(world, seats, seat, notes)) == A.grant.pass_case(world, A.grant.jam(seats, seat), seat, notes) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats seat:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case D.Duo{A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, False{}, c3, p3, s3, t3}} D.Seat3{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, True{}, False{}, p3, s3, t3}} D.Seat3{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, True{}, True{}, p3, s3, t3}} D.Seat3{}:
          {==}
        case D.Trio{A.CoreSeat{h0, False{}, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, True{}, False{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, True{}, True{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, False{}, c2, p2, s2, t2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, False{}, p2, s2, t2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, True{}, p2, s2, t2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, False{}, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, True{}, False{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, True{}, True{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, False{}, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, False{}, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, True{}, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, False{}, c3, p3, s3, t3}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, True{}, False{}, p3, s3, t3}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, True{}, True{}, p3, s3, t3}} D.Seat3{}:
          {==}

def give_dispatch(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes()) -> {A.grant.dispatch(A.grant.give(world, seats, seat, notes)) == A.ref(A.grant.given(world, seats, phase, notes, seat)) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats seat:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}

def settle_given(fuel: Nat, +world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes()) -> {A.grant.settle(fuel, A.ref(A.grant.given(world, seats, phase, notes, seat))) == A.ref(A.grant.given(world, seats, phase, notes, seat)) : A.Ref()}:
  match fuel:
    case 0n:
      {==}
    case 1n+rest:
      {==}

def give_closure(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +fuel: Nat) -> {A.grant.settle(1n+fuel, A.grant.give(world, seats, seat, notes)) == A.ref(A.grant.given(world, seats, phase, notes, seat)) : A.Ref()}:
  Equal.trans(A.Ref(), A.grant.settle(fuel, A.grant.dispatch(A.grant.give(world, seats, seat, notes))), A.grant.settle(fuel, A.ref(A.grant.given(world, seats, phase, notes, seat))), A.ref(A.grant.given(world, seats, phase, notes, seat)), Equal.cong(A.Ref(), A.Ref(), state => A.grant.settle(fuel, state), A.grant.dispatch(A.grant.give(world, seats, seat, notes)), A.ref(A.grant.given(world, seats, phase, notes, seat)), give_dispatch(world, seats, seat, phase, notes)), settle_given(fuel, world, seats, seat, phase, notes))

def add_succ(+a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+rest:
      Equal.cong(Nat, Nat, n => 1n+n, Nat.add(rest, 1n+b), 1n+Nat.add(rest, b), add_succ(rest, b))

def sum_succ(+prefix: List<&2, Nat>, +tail: Nat) -> {A.grant.sum(prefix, 1n+tail) == 1n+A.grant.sum(prefix, tail) : Nat}:
  match prefix:
    case Nil{}:
      {==}
    case +x <> +rest:
      Equal.trans(Nat, Nat.add(x, A.grant.sum(rest, 1n+tail)), Nat.add(x, 1n+A.grant.sum(rest, tail)), 1n+Nat.add(x, A.grant.sum(rest, tail)), Equal.cong(Nat, Nat, n => Nat.add(x, n), A.grant.sum(rest, 1n+tail), 1n+A.grant.sum(rest, tail), sum_succ(rest, tail)), add_succ(x, A.grant.sum(rest, tail)))

def rank_drop(+seats: A.Seats(), +seat: D.Seat) -> A.grant.rank_claim(seats, A.grant.jam(seats, seat)):
  match seats seat:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      sum_succ([], Nat.add(Q.jam_rank.bit(j3, c3), 0n))
    case D.Duo{A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, False{}, c3, p3, s3, t3}} D.Seat3{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, True{}, False{}, p3, s3, t3}} D.Seat3{}:
      sum_succ([Q.jam_rank.bit(j1, c1)], 0n)
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, True{}, True{}, p3, s3, t3}} D.Seat3{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, False{}, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, True{}, False{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      sum_succ([], Nat.add(Q.jam_rank.bit(j1, c1), Nat.add(Q.jam_rank.bit(j2, c2), 0n)))
    case D.Trio{A.CoreSeat{h0, True{}, True{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      sum_succ([Q.jam_rank.bit(j0, c0)], Nat.add(Q.jam_rank.bit(j2, c2), 0n))
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, False{}, c2, p2, s2, t2}} D.Seat2{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, False{}, p2, s2, t2}} D.Seat2{}:
      sum_succ([Q.jam_rank.bit(j0, c0), Q.jam_rank.bit(j1, c1)], 0n)
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, True{}, p2, s2, t2}} D.Seat2{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, False{}, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, True{}, False{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      sum_succ([], Nat.add(Q.jam_rank.bit(j1, c1), Nat.add(Q.jam_rank.bit(j2, c2), Nat.add(Q.jam_rank.bit(j3, c3), 0n))))
    case D.Quad{A.CoreSeat{h0, True{}, True{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      sum_succ([Q.jam_rank.bit(j0, c0)], Nat.add(Q.jam_rank.bit(j2, c2), Nat.add(Q.jam_rank.bit(j3, c3), 0n)))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, False{}, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, False{}, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      sum_succ([Q.jam_rank.bit(j0, c0), Q.jam_rank.bit(j1, c1)], Nat.add(Q.jam_rank.bit(j3, c3), 0n))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, True{}, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, False{}, c3, p3, s3, t3}} D.Seat3{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, True{}, False{}, p3, s3, t3}} D.Seat3{}:
      sum_succ([Q.jam_rank.bit(j0, c0), Q.jam_rank.bit(j1, c1), Q.jam_rank.bit(j2, c2)], 0n)
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, True{}, True{}, p3, s3, t3}} D.Seat3{}:
      Unit{}

def jam_once(+seats: A.Seats(), +seat: D.Seat) -> A.grant.once_claim(A.grant.jam(seats, seat), seat):
  match seats seat:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      ({==}, ({==}, ({==}, {==})))
    case D.Duo{A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      ({==}, ({==}, {==}))
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, False{}, c3, p3, s3, t3}} D.Seat3{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, True{}, False{}, p3, s3, t3}} D.Seat3{}:
      ({==}, ({==}, ({==}, {==})))
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, True{}, True{}, p3, s3, t3}} D.Seat3{}:
      ({==}, ({==}, {==}))
    case D.Trio{A.CoreSeat{h0, False{}, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, True{}, False{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      ({==}, ({==}, ({==}, {==})))
    case D.Trio{A.CoreSeat{h0, True{}, True{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      ({==}, ({==}, {==}))
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      ({==}, ({==}, ({==}, {==})))
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      ({==}, ({==}, {==}))
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, False{}, c2, p2, s2, t2}} D.Seat2{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, False{}, p2, s2, t2}} D.Seat2{}:
      ({==}, ({==}, ({==}, {==})))
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, True{}, p2, s2, t2}} D.Seat2{}:
      ({==}, ({==}, {==}))
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, False{}, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, True{}, False{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      ({==}, ({==}, ({==}, {==})))
    case D.Quad{A.CoreSeat{h0, True{}, True{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      ({==}, ({==}, {==}))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      ({==}, ({==}, ({==}, {==})))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      ({==}, ({==}, {==}))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, False{}, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, False{}, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      ({==}, ({==}, ({==}, {==})))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, True{}, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      ({==}, ({==}, {==}))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, False{}, c3, p3, s3, t3}} D.Seat3{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, True{}, False{}, p3, s3, t3}} D.Seat3{}:
      ({==}, ({==}, ({==}, {==})))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, True{}, True{}, p3, s3, t3}} D.Seat3{}:
      ({==}, ({==}, {==}))

law jam_skip_once:
  for +world: S.World
  for +seats: A.Seats()
  for +seat: D.Seat
  for +notes: A.Notes()
  ({A.grant.dispatch(A.grant.pass(world, seats, seat, notes)) == A.grant.pass_case(world, A.grant.jam(seats, seat), seat, notes) : A.Ref()} & A.grant.once_claim(A.grant.jam(seats, seat), seat))

def jam_skip_once(world, seats, seat, notes):
  (ref_pass(world, seats, seat, notes), jam_once(seats, seat))
def turn_cons(hp: Nat, same: Bool, +seat: D.Seat, +left: List<&2, D.Seat>, +right: List<&2, D.Seat>, rest: {left == right : List<&2, D.Seat>}) -> {Q.seats.keep(Bool.or(Q.alive(hp), same), seat, left) == A.ref_keep(Bool.or(same, A.ref_alive(hp)), seat, right) : List<&2, D.Seat>}:
  match hp same:
    case 0n False{}:
      rest
    case 0n True{}:
      Equal.cong(List<&2, D.Seat>, List<&2, D.Seat>, seats => seat <> seats, left, right, rest)
    case 1n+n False{}:
      Equal.cong(List<&2, D.Seat>, List<&2, D.Seat>, seats => seat <> seats, left, right, rest)
    case 1n+n True{}:
      Equal.cong(List<&2, D.Seat>, List<&2, D.Seat>, seats => seat <> seats, left, right, rest)

def turn_entries(+entries: List<&2, D.At<&2, A.CoreSeat>>, +current: D.Seat) -> {A.turn_entries_machine(entries, current) == A.turn_entries_ref(entries, current) : List<&2, D.Seat>}:
  match entries:
    case Nil{}:
      {==}
    case D.At{+seat, A.CoreSeat{hp, _, _, _, _, _}} <> +rest:
      turn_cons(hp, D.seat.eq(seat, current), seat, A.turn_entries_machine(rest, current), A.turn_entries_ref(rest, current), turn_entries(rest, current))

def turn_candidates_match(+seats: D.Ring<&2, A.CoreSeat>, +current: D.Seat) -> {Q.turn_candidates(D.ring.entries(Nat, A.seats.health(seats)), current) == A.turn_candidates_ref(seats, current) : List<&2, D.Seat>}:
  match seats:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      turn_entries(D.ring.entries(A.CoreSeat, seats), current)
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
      turn_entries(D.ring.entries(A.CoreSeat, seats), current)
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      turn_entries(D.ring.entries(A.CoreSeat, seats), current)

def turn_pick(same: Bool, +next: D.Seat, +left: D.Seat, +right: D.Seat, rest: {left == right : D.Seat}) -> {Q.successor.pick(same, next, left) == A.ref_pick(same, next, right) : D.Seat}:
  match same:
    case True{}:
      {==}
    case False{}:
      rest

def successor_go_match(+seats: List<&2, D.Seat>, +current: D.Seat, +wrap: D.Seat) -> {Q.successor.go(seats, current, wrap) == A.ref_successor_go(seats, current, wrap) : D.Seat}:
  match seats:
    case Nil{}:
      {==}
    case seat <> Nil{}:
      {==}
    case +seat <> +next <> +rest:
      turn_pick(D.seat.eq(seat, current), next, Q.successor.go(next <> rest, current, wrap), A.ref_successor_go(next <> rest, current, wrap), successor_go_match(next <> rest, current, wrap))

def successor_match(+seats: List<&2, D.Seat>, +current: D.Seat) -> {Q.successor(seats, current) == A.ref_successor(seats, current) : D.Seat}:
  match seats:
    case Nil{}:
      {==}
    case +head <> +rest:
      successor_go_match(head <> rest, current, head)

def traversal_match(direction: D.Direction, +seats: List<&2, D.Seat>, +current: D.Seat) -> {Q.traversal(direction, seats, current) == A.ref_directed(direction, seats, current) : D.Seat}:
  match direction:
    case D.Clockwise{}:
      successor_match(seats, current)
    case D.CounterClockwise{}:
      successor_match(List.reverse(&2, D.Seat, seats), current)

def turn_raw(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +current: D.Seat) -> {Q.next_turn(A.seats.health(seats), S.world.direction(world), current) == A.ref_turn(world, seats, current) : D.Seat}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      Equal.trans(D.Seat, Q.traversal(direction, Q.turn_candidates(D.ring.entries(Nat, A.seats.health(seats)), current), current), Q.traversal(direction, A.turn_candidates_ref(seats, current), current), A.ref_directed(direction, A.turn_candidates_ref(seats, current), current), Equal.cong(List<&2, D.Seat>, D.Seat, candidates => Q.traversal(direction, candidates, current), Q.turn_candidates(D.ring.entries(Nat, A.seats.health(seats)), current), A.turn_candidates_ref(seats, current), turn_candidates_match(seats, current)), traversal_match(direction, A.turn_candidates_ref(seats, current), current))


def turn_backwards(+world: S.World, +seats: A.Seats(), +seat: D.Seat) -> {A.ref_turn(world, seats, seat) == Q.next_turn(A.seats.health(seats), S.world.direction(world), seat) : D.Seat}:
  %turn_raw(world, seats, seat) : {_ == Q.next_turn(A.seats.health(seats), S.world.direction(world), seat) : D.Seat}
  {==}

def jam_backwards(+seats: A.Seats(), +seat: D.Seat) -> {A.grant.players(A.grant.jam(seats, seat)) == Q.jam(A.players(seats), seat) : S.JamResult}:
  %machine_jam(seats, seat) : {_ == Q.jam(A.players(seats), seat) : S.JamResult}
  {==}

def machine_case(+rank: Nat, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +seat: D.Seat) -> {A.ref(A.grant.machine_case(rank, world, seats, phase, notes, seat, A.grant.jam(seats, seat))) == A.ref(A.grant.machine(rank, world, seats, phase, notes, seat)) : A.Ref()}:
  Equal.cong(S.JamResult, A.Ref(), result => A.ref(M.grant.step(rank, A.pack(S.world.set_turn(world, Some{seat}), seats, phase, notes), seat, result)), A.grant.players(A.grant.jam(seats, seat)), Q.jam(A.players(seats), seat), jam_backwards(seats, seat))


def absurd(-A: Type, impossible: Empty) -> A:
  match impossible:

def zero_succ(n: Nat, impossible: {0n == 1n+n : Nat}) -> Empty:
  %impossible : A.grant.zero_claim(_)
  Unit{}

def remaining_rank(+rank: Nat, +old: Nat, +after: Nat, budget: {1n+rank == old : Nat}, drop: {old == 1n+after : Nat}) -> {rank == after : Nat}:
  Equal.cong(Nat, Nat, n => A.grant.pred(n), 1n+rank, 1n+after, Equal.trans(Nat, 1n+rank, old, 1n+after, budget, drop))

def grant_case_zero(+result: A.GrantCase, +world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +extra: Nat, budget: {0n == A.grant.rank(seats) : Nat}, claim: A.grant.rank_claim(seats, result)) -> {A.grant.settle(1n+extra, A.grant.pass_case(world, result, seat, notes)) == A.ref(A.grant.machine_case(0n, world, seats, phase, notes, seat, result)) : A.Ref()}:
  match result:
    case A.GrantAct{after}:
      give_closure(S.world.set_turn(world, Some{seat}), after, seat, phase, notes, extra)
    case A.GrantLift{after}:
      give_closure(S.world.set_turn(world, Some{seat}), after, seat, phase, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]), extra)
    case A.GrantSkip{+after}:
      absurd({A.grant.settle(1n+extra, A.grant.pass_case(world, result, seat, notes)) == A.ref(A.grant.machine_case(0n, world, seats, phase, notes, seat, result)) : A.Ref()}, zero_succ(A.grant.rank(after), Equal.trans(Nat, 0n, A.grant.rank(seats), 1n+A.grant.rank(after), budget, claim)))

def grant_case_succ(+result: A.GrantCase, +rest: Nat, +world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +extra: Nat, recur: A.grant.Hypothesis(rest), budget: {1n+rest == A.grant.rank(seats) : Nat}, claim: A.grant.rank_claim(seats, result)) -> {A.grant.settle(2n+Nat.add(rest, extra), A.grant.pass_case(world, result, seat, notes)) == A.ref(A.grant.machine_case(1n+rest, world, seats, phase, notes, seat, result)) : A.Ref()}:
  match result:
    case A.GrantAct{after}:
      give_closure(S.world.set_turn(world, Some{seat}), after, seat, phase, notes, 1n+Nat.add(rest, extra))
    case A.GrantLift{after}:
      give_closure(S.world.set_turn(world, Some{seat}), after, seat, phase, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]), 1n+Nat.add(rest, extra))
    case A.GrantSkip{+after}:
      +turned : S.World = S.world.set_turn(world, Some{seat})
      +following : D.Seat = A.ref_turn(turned, after, seat)
      +updated : A.Notes() = List.append(&2, D.Note, notes, [D.Shown{D.TurnSkipped{seat}}])
      Equal.trans(A.Ref(), A.grant.settle(2n+Nat.add(rest, extra), A.grant.pass(turned, after, following, updated)), A.ref(A.grant.machine(rest, turned, after, phase, updated, following)), A.ref(A.grant.machine(rest, turned, after, phase, updated, Q.next_turn(A.seats.health(after), S.world.direction(turned), seat))), recur(turned, after, following, phase, updated, extra, remaining_rank(rest, A.grant.rank(seats), A.grant.rank(after), budget, claim)), Equal.cong(D.Seat, A.Ref(), next => A.ref(A.grant.machine(rest, turned, after, phase, updated, next)), following, Q.next_turn(A.seats.health(after), S.world.direction(turned), seat), turn_backwards(turned, after, seat)))

def grant_glue(+rank: Nat, +world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +extra: Nat, closed: {A.grant.settle(1n+Nat.add(rank, extra), A.grant.pass_case(world, A.grant.jam(seats, seat), seat, notes)) == A.ref(A.grant.machine_case(rank, world, seats, phase, notes, seat, A.grant.jam(seats, seat))) : A.Ref()}) -> {A.grant.settle(2n+Nat.add(rank, extra), A.grant.pass(world, seats, seat, notes)) == A.ref(A.grant.machine(rank, world, seats, phase, notes, seat)) : A.Ref()}:
  +result : A.GrantCase = A.grant.jam(seats, seat)
  step : {A.grant.settle(1n+Nat.add(rank, extra), A.grant.dispatch(A.grant.pass(world, seats, seat, notes))) == A.grant.settle(1n+Nat.add(rank, extra), A.grant.pass_case(world, result, seat, notes)) : A.Ref()} = Equal.cong(A.Ref(), A.Ref(), state => A.grant.settle(1n+Nat.add(rank, extra), state), A.grant.dispatch(A.grant.pass(world, seats, seat, notes)), A.grant.pass_case(world, result, seat, notes), ref_pass(world, seats, seat, notes))
  Equal.trans(A.Ref(), A.grant.settle(1n+Nat.add(rank, extra), A.grant.dispatch(A.grant.pass(world, seats, seat, notes))), A.grant.settle(1n+Nat.add(rank, extra), A.grant.pass_case(world, result, seat, notes)), A.ref(A.grant.machine(rank, world, seats, phase, notes, seat)), step, Equal.trans(A.Ref(), A.grant.settle(1n+Nat.add(rank, extra), A.grant.pass_case(world, result, seat, notes)), A.ref(A.grant.machine_case(rank, world, seats, phase, notes, seat, result)), A.ref(A.grant.machine(rank, world, seats, phase, notes, seat)), closed, machine_case(rank, world, seats, phase, notes, seat)))

def grant_induction(+rank: Nat) -> A.grant.Hypothesis(rank):
  match rank:
    case 0n:
      +world => +seats => +seat => +phase => +notes => +extra => budget => grant_glue(0n, world, seats, seat, phase, notes, extra, grant_case_zero(A.grant.jam(seats, seat), world, seats, seat, phase, notes, extra, budget, rank_drop(seats, seat)))
    case 1n+rest:
      +world => +seats => +seat => +phase => +notes => +extra => budget => grant_glue(1n+rest, world, seats, seat, phase, notes, extra, grant_case_succ(A.grant.jam(seats, seat), rest, world, seats, seat, phase, notes, extra, grant_induction(rest), budget, rank_drop(seats, seat)))

law grant_silent_closure:
  for +rank: Nat
  for +world: S.World
  for +seats: A.Seats()
  for +seat: D.Seat
  for +phase: S.Phase
  for +notes: A.Notes()
  for +extra: Nat
  for budget: {rank == Q.jam_rank(A.players(seats)) : Nat}
  {A.grant.settle(2n+Nat.add(rank, extra), A.grant.pass(world, seats, seat, notes)) == A.ref(M.grant.bound(rank, A.pack(world, seats, phase, notes), seat)) : A.Ref()}

def grant_silent_closure(rank, world, seats, seat, phase, notes, extra, budget):
  grant_induction(rank, world, seats, seat, phase, notes, extra, budget)

law grant_matches:
  for +world: S.World
  for +seats: A.Seats()
  for +seat: D.Seat
  for +phase: S.Phase
  for +notes: A.Notes()
  for +extra: Nat
  {A.grant.settle(2n+Nat.add(Q.jam_rank(A.players(seats)), extra), A.grant.pass(world, seats, seat, notes)) == A.ref(M.grant(A.pack(world, seats, phase, notes), seat)) : A.Ref()}

def grant_matches(world, seats, seat, phase, notes, extra):
  grant_induction(Q.jam_rank(A.players(seats)), world, seats, seat, phase, notes, extra, {==})

def limit_weaken(+amount: Nat, +bound: Nat, proof: A.grant.limit(amount, bound)) -> A.grant.limit(amount, 1n+bound):
  match amount bound:
    case 0n bound:
      Unit{}
    case 1n+amount 0n:
      match proof:
    case 1n+amount 1n+bound:
      limit_weaken(amount, bound, proof)

def rank_head(jammed: Bool, checked: Bool, +rest: Nat, +length: Nat, proof: A.grant.limit(rest, length)) -> A.grant.limit(Nat.add(Q.jam_rank.bit(jammed, checked), rest), 1n+length):
  match jammed checked:
    case False{} checked:
      limit_weaken(rest, length, proof)
    case True{} False{}:
      proof
    case True{} True{}:
      limit_weaken(rest, length, proof)

def rank_entries_limit(+entries: List<&2, D.At<&2, Bool>>, +checked: D.Ring<&2, Bool>) -> A.grant.limit(Q.jam_rank.entries(entries, checked), List.length(&2, D.At<&2, Bool>, entries)):
  match entries:
    case Nil{}:
      Unit{}
    case D.At{+seat, jammed} <> +rest:
      rank_head(jammed, Q.value.or(Bool, D.ring.get(Bool, checked, seat), False{}), Q.jam_rank.entries(rest, checked), List.length(&2, D.At<&2, Bool>, rest), rank_entries_limit(rest, checked))

law grant_rank_at_most_four:
  for +seats: A.Seats()
  A.grant.limit(Q.jam_rank(A.players(seats)), 4n)

def grant_rank_at_most_four(seats):
  match seats:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      limit_weaken(A.grant.rank(seats), 3n, limit_weaken(A.grant.rank(seats), 2n, rank_entries_limit(D.ring.entries(Bool, A.seats.jammed(seats)), A.seats.checked(seats))))
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
      limit_weaken(A.grant.rank(seats), 3n, rank_entries_limit(D.ring.entries(Bool, A.seats.jammed(seats)), A.seats.checked(seats)))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      rank_entries_limit(D.ring.entries(Bool, A.seats.jammed(seats)), A.seats.checked(seats))

law grant_dispatch_at_most_six:
  for +seats: A.Seats()
  A.grant.limit(2n+Q.jam_rank(A.players(seats)), 6n)

def grant_dispatch_at_most_six(seats):
  grant_rank_at_most_four(seats)

def jam_shape(+seats: A.Seats(), +seat: D.Seat) -> A.grant.shape_claim(A.grant.jam(seats, seat), D.ring.table(A.CoreSeat, seats)):
  match seats seat:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      {==}
    case D.Duo{A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Duo{A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Duo{A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, False{}, c3, p3, s3, t3}} D.Seat3{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, True{}, False{}, p3, s3, t3}} D.Seat3{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, True{}, True{}, p3, s3, t3}} D.Seat3{}:
      {==}
    case D.Trio{A.CoreSeat{h0, False{}, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      {==}
    case D.Trio{A.CoreSeat{h0, True{}, False{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      {==}
    case D.Trio{A.CoreSeat{h0, True{}, True{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, False{}, c2, p2, s2, t2}} D.Seat2{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, False{}, p2, s2, t2}} D.Seat2{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, True{}, p2, s2, t2}} D.Seat2{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
      {==}
    case D.Quad{A.CoreSeat{h0, False{}, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      {==}
    case D.Quad{A.CoreSeat{h0, True{}, False{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      {==}
    case D.Quad{A.CoreSeat{h0, True{}, True{}, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, False{}, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, False{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, True{}, True{}, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, False{}, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, False{}, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, True{}, True{}, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, False{}, c3, p3, s3, t3}} D.Seat3{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, True{}, False{}, p3, s3, t3}} D.Seat3{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, True{}, True{}, p3, s3, t3}} D.Seat3{}:
      {==}

def give_point_synced(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes()) -> {A.machine_point(A.grant.given(A.world_for(world, seats), seats, phase, notes, seat)) == A.ref_point(A.ref(A.grant.given(A.world_for(world, seats), seats, phase, notes, seat))) : D.Point}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats seat:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}

def world_config_identity(+world: S.World) -> {S.world.set_config(world, D.Config{S.world.table(world), S.world.plan(world)}) == world : S.World}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      {==}

def world_for_identity(+world: S.World, +seats: A.Seats(), synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> {A.world_for(world, seats) == world : S.World}:
  Equal.trans(S.World, A.world_for(world, seats), S.world.set_config(world, D.Config{S.world.table(world), S.world.plan(world)}), world, Equal.cong(D.Table, S.World, table => S.world.set_config(world, D.Config{table, S.world.plan(world)}), D.ring.table(A.CoreSeat, seats), S.world.table(world), Equal.sym(D.Table, S.world.table(world), D.ring.table(A.CoreSeat, seats), synced)), world_config_identity(world))

def give_point(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> {A.machine_point(A.grant.given(world, seats, phase, notes, seat)) == A.ref_point(A.ref(A.grant.given(world, seats, phase, notes, seat))) : D.Point}:
  %world_for_identity(world, seats, synced) : {A.machine_point(A.grant.given(_, seats, phase, notes, seat)) == A.ref_point(A.ref(A.grant.given(_, seats, phase, notes, seat))) : D.Point}
  give_point_synced(world, seats, seat, phase, notes)

def table_turn(+world: S.World, +seat: D.Seat) -> {S.world.table(S.world.set_turn(world, Some{seat})) == S.world.table(world) : D.Table}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      {==}

def sync_after(+world: S.World, +seats: A.Seats(), +after: A.Seats(), +seat: D.Seat, synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}, shape: {D.ring.table(A.CoreSeat, after) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> {S.world.table(S.world.set_turn(world, Some{seat})) == D.ring.table(A.CoreSeat, after) : D.Table}:
  Equal.trans(D.Table, S.world.table(S.world.set_turn(world, Some{seat})), S.world.table(world), D.ring.table(A.CoreSeat, after), table_turn(world, seat), Equal.trans(D.Table, S.world.table(world), D.ring.table(A.CoreSeat, seats), D.ring.table(A.CoreSeat, after), synced, Equal.sym(D.Table, D.ring.table(A.CoreSeat, after), D.ring.table(A.CoreSeat, seats), shape)))

def machine_state_case(+rank: Nat, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +seat: D.Seat) -> {A.grant.machine_case(rank, world, seats, phase, notes, seat, A.grant.jam(seats, seat)) == A.grant.machine(rank, world, seats, phase, notes, seat) : S.State}:
  Equal.cong(S.JamResult, S.State, result => M.grant.step(rank, A.pack(S.world.set_turn(world, Some{seat}), seats, phase, notes), seat, result), A.grant.players(A.grant.jam(seats, seat)), Q.jam(A.players(seats), seat), jam_backwards(seats, seat))

def point_glue(+rank: Nat, +world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), proved: {A.machine_point(A.grant.machine_case(rank, world, seats, phase, notes, seat, A.grant.jam(seats, seat))) == A.ref_point(A.ref(A.grant.machine_case(rank, world, seats, phase, notes, seat, A.grant.jam(seats, seat)))) : D.Point}) -> {A.machine_point(A.grant.machine(rank, world, seats, phase, notes, seat)) == A.ref_point(A.ref(A.grant.machine(rank, world, seats, phase, notes, seat))) : D.Point}:
  %machine_state_case(rank, world, seats, phase, notes, seat) : {A.machine_point(_) == A.ref_point(A.ref(_)) : D.Point}
  proved

def point_case_zero(+result: A.GrantCase, +world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), budget: {0n == A.grant.rank(seats) : Nat}, claim: A.grant.rank_claim(seats, result), synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}, shape: A.grant.shape_claim(result, D.ring.table(A.CoreSeat, seats))) -> {A.machine_point(A.grant.machine_case(0n, world, seats, phase, notes, seat, result)) == A.ref_point(A.ref(A.grant.machine_case(0n, world, seats, phase, notes, seat, result))) : D.Point}:
  match result:
    case A.GrantAct{+after}:
      give_point(S.world.set_turn(world, Some{seat}), after, seat, phase, notes, sync_after(world, seats, after, seat, synced, shape))
    case A.GrantLift{+after}:
      give_point(S.world.set_turn(world, Some{seat}), after, seat, phase, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]), sync_after(world, seats, after, seat, synced, shape))
    case A.GrantSkip{+after}:
      absurd({A.machine_point(A.grant.machine_case(0n, world, seats, phase, notes, seat, result)) == A.ref_point(A.ref(A.grant.machine_case(0n, world, seats, phase, notes, seat, result))) : D.Point}, zero_succ(A.grant.rank(after), Equal.trans(Nat, 0n, A.grant.rank(seats), 1n+A.grant.rank(after), budget, claim)))

def point_case_succ(+result: A.GrantCase, +rest: Nat, +world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), recur: A.grant.PointHypothesis(rest), budget: {1n+rest == A.grant.rank(seats) : Nat}, claim: A.grant.rank_claim(seats, result), synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}, shape: A.grant.shape_claim(result, D.ring.table(A.CoreSeat, seats))) -> {A.machine_point(A.grant.machine_case(1n+rest, world, seats, phase, notes, seat, result)) == A.ref_point(A.ref(A.grant.machine_case(1n+rest, world, seats, phase, notes, seat, result))) : D.Point}:
  match result:
    case A.GrantAct{+after}:
      give_point(S.world.set_turn(world, Some{seat}), after, seat, phase, notes, sync_after(world, seats, after, seat, synced, shape))
    case A.GrantLift{+after}:
      give_point(S.world.set_turn(world, Some{seat}), after, seat, phase, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]), sync_after(world, seats, after, seat, synced, shape))
    case A.GrantSkip{+after}:
      +turned : S.World = S.world.set_turn(world, Some{seat})
      +following : D.Seat = Q.next_turn(A.seats.health(after), S.world.direction(turned), seat)
      +updated : A.Notes() = List.append(&2, D.Note, notes, [D.Shown{D.TurnSkipped{seat}}])
      recur(turned, after, following, phase, updated, remaining_rank(rest, A.grant.rank(seats), A.grant.rank(after), budget, claim), sync_after(world, seats, after, seat, synced, shape))

def point_induction(+rank: Nat) -> A.grant.PointHypothesis(rank):
  match rank:
    case 0n:
      +world => +seats => +seat => +phase => +notes => budget => synced => point_glue(0n, world, seats, seat, phase, notes, point_case_zero(A.grant.jam(seats, seat), world, seats, seat, phase, notes, budget, rank_drop(seats, seat), synced, jam_shape(seats, seat)))
    case 1n+rest:
      +world => +seats => +seat => +phase => +notes => budget => synced => point_glue(1n+rest, world, seats, seat, phase, notes, point_case_succ(A.grant.jam(seats, seat), rest, world, seats, seat, phase, notes, point_induction(rest), budget, rank_drop(seats, seat), synced, jam_shape(seats, seat)))

law grant_point_matches:
  for +world: S.World
  for +seats: A.Seats()
  for +seat: D.Seat
  for +phase: S.Phase
  for +notes: A.Notes()
  for +extra: Nat
  for synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}
  {A.machine_point(M.grant(A.pack(world, seats, phase, notes), seat)) == A.ref_point(A.grant.settle(2n+Nat.add(Q.jam_rank(A.players(seats)), extra), A.grant.pass(world, seats, seat, notes))) : D.Point}

def grant_point_matches(world, seats, seat, phase, notes, extra, synced):
  Equal.trans(D.Point, A.machine_point(M.grant(A.pack(world, seats, phase, notes), seat)), A.ref_point(A.ref(M.grant(A.pack(world, seats, phase, notes), seat))), A.ref_point(A.grant.settle(2n+Nat.add(Q.jam_rank(A.players(seats)), extra), A.grant.pass(world, seats, seat, notes))), point_induction(Q.jam_rank(A.players(seats)), world, seats, seat, phase, notes, {==}, synced), Equal.cong(A.Ref(), D.Point, state => A.ref_point(state), A.ref(M.grant(A.pack(world, seats, phase, notes), seat)), A.grant.settle(2n+Nat.add(Q.jam_rank(A.players(seats)), extra), A.grant.pass(world, seats, seat, notes)), Equal.sym(A.Ref(), A.grant.settle(2n+Nat.add(Q.jam_rank(A.players(seats)), extra), A.grant.pass(world, seats, seat, notes)), A.ref(M.grant(A.pack(world, seats, phase, notes), seat)), grant_matches(world, seats, seat, phase, notes, extra))))

def grant_six(+rank: Nat, +world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +extra: Nat, +budget: {rank == A.grant.rank(seats) : Nat}, bounded: A.grant.limit(rank, 4n)) -> {A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes)) == A.ref(M.grant(A.pack(world, seats, phase, notes), seat)) : A.Ref()}:
  match rank:
    case 0n:
      %budget : {A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes)) == A.ref(M.grant.bound(_, A.pack(world, seats, phase, notes), seat)) : A.Ref()}
      grant_induction(0n, world, seats, seat, phase, notes, 4n+extra, budget)
    case 1n:
      %budget : {A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes)) == A.ref(M.grant.bound(_, A.pack(world, seats, phase, notes), seat)) : A.Ref()}
      grant_induction(1n, world, seats, seat, phase, notes, 3n+extra, budget)
    case 2n:
      %budget : {A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes)) == A.ref(M.grant.bound(_, A.pack(world, seats, phase, notes), seat)) : A.Ref()}
      grant_induction(2n, world, seats, seat, phase, notes, 2n+extra, budget)
    case 3n:
      %budget : {A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes)) == A.ref(M.grant.bound(_, A.pack(world, seats, phase, notes), seat)) : A.Ref()}
      grant_induction(3n, world, seats, seat, phase, notes, 1n+extra, budget)
    case 4n:
      %budget : {A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes)) == A.ref(M.grant.bound(_, A.pack(world, seats, phase, notes), seat)) : A.Ref()}
      grant_induction(4n, world, seats, seat, phase, notes, 0n+extra, budget)
    case 5n+rest:
      match bounded:

law grant_six_dispatches:
  for +world: S.World
  for +seats: A.Seats()
  for +seat: D.Seat
  for +phase: S.Phase
  for +notes: A.Notes()
  for +extra: Nat
  {A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes)) == A.ref(M.grant(A.pack(world, seats, phase, notes), seat)) : A.Ref()}

def grant_six_dispatches(world, seats, seat, phase, notes, extra):
  grant_six(A.grant.rank(seats), world, seats, seat, phase, notes, extra, {==}, grant_rank_at_most_four(seats))

law grant_six_point:
  for +world: S.World
  for +seats: A.Seats()
  for +seat: D.Seat
  for +phase: S.Phase
  for +notes: A.Notes()
  for +extra: Nat
  for synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}
  {A.machine_point(M.grant(A.pack(world, seats, phase, notes), seat)) == A.ref_point(A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes))) : D.Point}

def grant_six_point(world, seats, seat, phase, notes, extra, synced):
  Equal.trans(D.Point, A.machine_point(M.grant(A.pack(world, seats, phase, notes), seat)), A.ref_point(A.ref(M.grant(A.pack(world, seats, phase, notes), seat))), A.ref_point(A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes))), point_induction(Q.jam_rank(A.players(seats)), world, seats, seat, phase, notes, {==}, synced), Equal.cong(A.Ref(), D.Point, state => A.ref_point(state), A.ref(M.grant(A.pack(world, seats, phase, notes), seat)), A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes)), Equal.sym(A.Ref(), A.grant.settle(6n+extra, A.grant.pass(world, seats, seat, notes)), A.ref(M.grant(A.pack(world, seats, phase, notes), seat)), grant_six_dispatches(world, seats, seat, phase, notes, extra))))
