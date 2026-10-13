import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/items.bend as I

# Internal lemmas toward step_matches for item configs, under A.ValidItems.
# Bodies marked generated in tools/proof_cases.py are owned by that script.

# The no-item Valid is a special case of ValidItems: its normal form packs
# empty slots, initial Grabs and a world tied to the seat ring.

def items.idle_uses(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes()) -> {I.uses(A.pack(A.world_for(world, seats), seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes), seat) == Nil{} : List<&2, S.IdleOption>}:
  match seats seat:
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}} D.Seat0{}:
      {==}
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}} D.Seat1{}:
      {==}
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}} D.Seat2{}:
      {==}
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}} D.Seat3{}:
      {==}
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}} D.Seat0{}:
      {==}
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}} D.Seat1{}:
      {==}
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}} D.Seat2{}:
      {==}
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}} D.Seat3{}:
      {==}
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}} D.Seat0{}:
      {==}
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}} D.Seat1{}:
      {==}
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}} D.Seat2{}:
      {==}
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}} D.Seat3{}:
      {==}

def items.pack_shape(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes()) -> A.Shape(A.pack(A.world_for(world, seats), seats, phase, notes)):
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}}:
          ({==}, ({==}, ({==}, ({==}, {==}))))
        case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}}:
          ({==}, ({==}, ({==}, ({==}, {==}))))
        case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}}:
          ({==}, ({==}, ({==}, ({==}, {==}))))

def items.pack_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +ready: {A.phase_ready(phase, world) == True{} : Bool}) -> A.ValidItems(A.pack(A.world_for(world, seats), seats, A.canonical_phase(phase), notes)):
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match phase:
        case S.NeedFirst{}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.NeedFirst{}, notes), (bounded, ready)))
        case S.NeedHealth{}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.NeedHealth{}, notes), (bounded, ready)))
        case S.NeedAmount{}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.NeedAmount{}, notes), (bounded, ready)))
        case S.NeedBatch{}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.NeedBatch{}, notes), (bounded, ready)))
        case S.NeedSwap{_, _, 0n}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.NeedSwap{+swap_load, +shells, 1n+i}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.NeedSwap{swap_load, shells, 1n+i}, notes), (bounded, ready)))
        case S.Idle{+seat, options}:
          (Equal.cong(List<&2, S.IdleOption>, S.State, xs => S.State{A.world_for(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats), A.players.free(seats), S.Idle{seat, D.NonEmpty{S.TakeGun{}, xs}}, notes, A.grabs(seats)}, I.uses(A.pack(A.world_for(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats), seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes), seat), Nil{}, items.idle_uses(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, seat, notes)), (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes), (bounded, ready)))
        case S.Aim{+seat}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Aim{seat}, notes), (bounded, ready)))
        case S.Ended{}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Ended{}, notes), (bounded, ready)))
        case S.Blocked{+holder}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{holder}, notes), (bounded, ready)))
        case S.NeedTurnAmount{_, _, _}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.Grab{_}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.NeedItem{_, _, _, _}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.NeedPhone{_, _, _}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.JamPick{_, _}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.StealPick{_, _}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))

def valid.items(+s: S.State, +valid: A.Valid(s)) -> A.ValidItems(s):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match valid:
        case Tuple{normal, Tuple{_, Tuple{bounded, ready}}}:
          %normal : A.ValidItems(_)
          items.pack_valid(world, players, phase, notes, bounded, ready)
