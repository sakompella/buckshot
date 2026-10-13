import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/main.bend as M
import ./sm/rules.bend as Q

def ref_pass(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes()) -> {A.grant.dispatch(A.grant.pass(world, seats, seat, notes)) == A.grant.pass_case(world, A.grant.jam(seats, seat), seat, notes) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats seat:
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
          {==}
        case D.Duo{A.CoreSeat{h1, S.Free{}, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, S.Jammed{}, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, S.JammedSkipped{}, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, S.Free{}, p3, s3}} D.Seat3{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, S.Jammed{}, p3, s3}} D.Seat3{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, S.JammedSkipped{}, p3, s3}} D.Seat3{}:
          {==}
        case D.Trio{A.CoreSeat{h0, S.Free{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, S.Jammed{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, S.JammedSkipped{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.Free{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.Jammed{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.JammedSkipped{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.Free{}, p2, s2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.Jammed{}, p2, s2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.JammedSkipped{}, p2, s2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, S.Free{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, S.Jammed{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, S.JammedSkipped{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.Free{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.Jammed{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.JammedSkipped{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.Free{}, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.Jammed{}, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.JammedSkipped{}, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, S.Free{}, p3, s3}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, S.Jammed{}, p3, s3}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, S.JammedSkipped{}, p3, s3}} D.Seat3{}:
          {==}

def jam_once(+seats: A.Seats(), +seat: D.Seat) -> A.grant.once_claim(A.grant.jam(seats, seat), seat):
  match seats seat:
    case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, S.Free{}, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, S.Jammed{}, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
      ({==}, ({==}, {==}))
    case D.Duo{A.CoreSeat{h1, S.JammedSkipped{}, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
      ({==}, {==})
    case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, S.Free{}, p3, s3}} D.Seat3{}:
      Unit{}
    case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, S.Jammed{}, p3, s3}} D.Seat3{}:
      ({==}, ({==}, {==}))
    case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, S.JammedSkipped{}, p3, s3}} D.Seat3{}:
      ({==}, {==})
    case D.Trio{A.CoreSeat{h0, S.Free{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat0{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, S.Jammed{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat0{}:
      ({==}, ({==}, {==}))
    case D.Trio{A.CoreSeat{h0, S.JammedSkipped{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat0{}:
      ({==}, {==})
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.Free{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat1{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.Jammed{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat1{}:
      ({==}, ({==}, {==}))
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.JammedSkipped{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat1{}:
      ({==}, {==})
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.Free{}, p2, s2}} D.Seat2{}:
      Unit{}
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.Jammed{}, p2, s2}} D.Seat2{}:
      ({==}, ({==}, {==}))
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.JammedSkipped{}, p2, s2}} D.Seat2{}:
      ({==}, {==})
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat3{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, S.Free{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, S.Jammed{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
      ({==}, ({==}, {==}))
    case D.Quad{A.CoreSeat{h0, S.JammedSkipped{}, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
      ({==}, {==})
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.Free{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.Jammed{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
      ({==}, ({==}, {==}))
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, S.JammedSkipped{}, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
      ({==}, {==})
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.Free{}, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.Jammed{}, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
      ({==}, ({==}, {==}))
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, S.JammedSkipped{}, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
      ({==}, {==})
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, S.Free{}, p3, s3}} D.Seat3{}:
      Unit{}
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, S.Jammed{}, p3, s3}} D.Seat3{}:
      ({==}, ({==}, {==}))
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, S.JammedSkipped{}, p3, s3}} D.Seat3{}:
      ({==}, {==})

def give_dispatch(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes()) -> {A.grant.dispatch(A.grant.give(world, seats, seat, notes)) == A.ref(A.grant.given(world, seats, phase, notes, seat)) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats seat:
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat3{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat3{}:
          {==}

def settle_given(fuel: Nat, +world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes()) -> {A.grant.settle(fuel, A.ref(A.grant.given(world, seats, phase, notes, seat))) == A.ref(A.grant.given(world, seats, phase, notes, seat)) : A.Ref()}:
  match fuel:
    case 0n:
      {==}
    case 1n+rest:
      {==}

def give_closure(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +fuel: Nat) -> {A.grant.settle(1n+fuel, A.grant.give(world, seats, seat, notes)) == A.ref(A.grant.given(world, seats, phase, notes, seat)) : A.Ref()}:
  Equal.trans(A.Ref(), A.grant.settle(fuel, A.grant.dispatch(A.grant.give(world, seats, seat, notes))), A.grant.settle(fuel, A.ref(A.grant.given(world, seats, phase, notes, seat))), A.ref(A.grant.given(world, seats, phase, notes, seat)), Equal.cong(A.Ref(), A.Ref(), state => A.grant.settle(fuel, state), A.grant.dispatch(A.grant.give(world, seats, seat, notes)), A.ref(A.grant.given(world, seats, phase, notes, seat)), give_dispatch(world, seats, seat, phase, notes)), settle_given(fuel, world, seats, seat, phase, notes))

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
    case D.At{+seat, A.CoreSeat{hp, _, _, sl}} <> +rest:
      turn_cons(hp, D.seat.eq(seat, current), seat, A.turn_entries_machine(rest, current), A.turn_entries_ref(rest, current), turn_entries(rest, current))

def turn_candidates_match(+seats: D.Ring<&2, A.CoreSeat>, +current: D.Seat) -> {Q.turn_candidates(D.ring.entries(Nat, A.seats.health(seats)), current) == A.turn_candidates_ref(seats, current) : List<&2, D.Seat>}:
  match seats:
    case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}}:
      turn_entries(D.ring.entries(A.CoreSeat, seats), current)
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}}:
      turn_entries(D.ring.entries(A.CoreSeat, seats), current)
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}}:
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

def give_point_synced(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes()) -> {A.machine_point(A.grant.given(A.world_for(world, seats), seats, phase, notes, seat)) == A.ref_point(A.ref(A.grant.given(A.world_for(world, seats), seats, phase, notes, seat))) : D.Point}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats seat:
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat3{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat3{}:
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

# No-item scope: every seat is Free, so the grant acts at once.
def grant_free(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +seat: D.Seat) -> {M.grant(A.pack(world, seats, phase, notes), seat) == A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat) : S.State}:
  match seats seat:
    case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
      {==}
    case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat3{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat0{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat1{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat2{}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat3{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat3{}:
      {==}

def ref_pass_free(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes()) -> {A.grant.dispatch(A.grant.pass.free(world, seats, seat, notes)) == A.grant.give(S.world.set_turn(world, Some{seat}), seats, seat, notes) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats seat:
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h3, j3, p3, s3}} D.Seat3{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, p0, s0}, A.CoreSeat{h1, j1, p1, s1}, A.CoreSeat{h2, j2, p2, s2}, A.CoreSeat{h3, j3, p3, s3}} D.Seat3{}:
          {==}

def grant_six_given(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +extra: Nat) -> {A.grant.settle(6n+extra, A.grant.pass.free(world, seats, seat, notes)) == A.ref(A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat)) : A.Ref()}:
  Equal.trans(A.Ref(), A.grant.settle(5n+extra, A.grant.dispatch(A.grant.pass.free(world, seats, seat, notes))), A.grant.settle(5n+extra, A.grant.give(S.world.set_turn(world, Some{seat}), seats, seat, notes)), A.ref(A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat)), Equal.cong(A.Ref(), A.Ref(), state => A.grant.settle(5n+extra, state), A.grant.dispatch(A.grant.pass.free(world, seats, seat, notes)), A.grant.give(S.world.set_turn(world, Some{seat}), seats, seat, notes), ref_pass_free(world, seats, seat, notes)), give_closure(S.world.set_turn(world, Some{seat}), seats, seat, phase, notes, 4n+extra))

law grant_six_dispatches:
  for +world: S.World
  for +seats: A.Seats()
  for +seat: D.Seat
  for +phase: S.Phase
  for +notes: A.Notes()
  for +extra: Nat
  {A.grant.settle(6n+extra, A.grant.pass.free(world, seats, seat, notes)) == A.ref(M.grant(A.pack(world, seats, phase, notes), seat)) : A.Ref()}

def grant_six_dispatches(world, seats, seat, phase, notes, extra):
  Equal.trans(A.Ref(), A.grant.settle(6n+extra, A.grant.pass.free(world, seats, seat, notes)), A.ref(A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat)), A.ref(M.grant(A.pack(world, seats, phase, notes), seat)), grant_six_given(world, seats, seat, phase, notes, extra), Equal.cong(S.State, A.Ref(), state => A.ref(state), A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat), M.grant(A.pack(world, seats, phase, notes), seat), Equal.sym(S.State, M.grant(A.pack(world, seats, phase, notes), seat), A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat), grant_free(world, seats, phase, notes, seat))))

law grant_six_point:
  for +world: S.World
  for +seats: A.Seats()
  for +seat: D.Seat
  for +phase: S.Phase
  for +notes: A.Notes()
  for +extra: Nat
  for synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}
  {A.machine_point(M.grant(A.pack(world, seats, phase, notes), seat)) == A.ref_point(A.grant.settle(6n+extra, A.grant.pass.free(world, seats, seat, notes))) : D.Point}

def grant_six_point(world, seats, seat, phase, notes, extra, synced):
  %Equal.sym(S.State, M.grant(A.pack(world, seats, phase, notes), seat), A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat), grant_free(world, seats, phase, notes, seat)) : {A.machine_point(_) == A.ref_point(A.grant.settle(6n+extra, A.grant.pass.free(world, seats, seat, notes))) : D.Point}
  Equal.trans(D.Point, A.machine_point(A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat)), A.ref_point(A.ref(A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat))), A.ref_point(A.grant.settle(6n+extra, A.grant.pass.free(world, seats, seat, notes))), give_point(S.world.set_turn(world, Some{seat}), seats, seat, phase, notes, Equal.trans(D.Table, S.world.table(S.world.set_turn(world, Some{seat})), S.world.table(world), D.ring.table(A.CoreSeat, seats), table_turn(world, seat), synced)), Equal.cong(A.Ref(), D.Point, state => A.ref_point(state), A.ref(A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat)), A.grant.settle(6n+extra, A.grant.pass.free(world, seats, seat, notes)), Equal.sym(A.Ref(), A.grant.settle(6n+extra, A.grant.pass.free(world, seats, seat, notes)), A.ref(A.grant.given(S.world.set_turn(world, Some{seat}), seats, phase, notes, seat)), grant_six_given(world, seats, seat, phase, notes, extra))))
