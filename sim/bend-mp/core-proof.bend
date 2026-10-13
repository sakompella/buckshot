import Base
import ./grant-proof.bend as GrantProof
import ./shot-proof.bend as ShotProof
import ./abstract.bend as A
import ./domain.bend as D
import ./primitive.bend as P
import ./sm/state.bend as S
import ./sm/main.bend as M
import ./sm/rules.bend as Q
import ./sm/point.bend as PView
import ./sm/items.bend as I

def core_roundtrip(+seats: D.Ring<&2, A.CoreSeat>) -> {A.core(A.players(seats)) == seats : D.Ring<&2, A.CoreSeat>}:
  match seats:
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}}:
      {==}
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}}:
      {==}
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}}:
      {==}

def law.core_roundtrip(+seats: A.Seats()) -> {A.core(A.players(seats)) == seats : A.Seats()}:
  core_roundtrip(seats)


def ref_idle_canonical(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, present: A.seated(world, seat)) -> {A.raw_idle(world, seats, seat, notes) == A.ref_idle_choose(world, seats, seat, notes) : A.Ref()}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      Equal.cong(D.Request, A.Ref(), request => A.ref_idle_request(world, seats, seat, notes, request), P.pickup_request(table, seat), D.Choose{D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}])}, P.pickup_request_choose(table, seat, present))

def true_backwards(+value: Bool, accepted: {value == True{} : Bool}) -> {True{} == value : Bool}:
  %accepted : {_ == value : Bool}
  {==}

def ref_pickup_choose(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, +n: Nat, present: A.seated(world, seat), accepted: {A.raw_accepted(world, seats, seat) == True{} : Bool}) -> {A.ref_answer(A.ref_idle_choose(world, seats, seat, notes), n) == A.expected_pickup(world, seats, seat) : A.RefStep()}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %P.pickup_choose_resolved_backwards(table, seat, n, present) : {A.ref_idle_resolved(world, seats, seat, _) == A.expected_pickup(world, seats, seat) : A.RefStep()}
      %true_backwards(A.raw_accepted(world, seats, seat), accepted) : {A.ref_idle_accepting(world, seats, seat, _) == A.expected_pickup(world, seats, seat) : A.RefStep()}
      {==}


def machine_pickup(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>, +n: Nat, present: A.seated(world, seat)) -> {A.pickup_step(world, seats, seat, notes, n) == A.expected_pickup(world, seats, seat) : A.RefStep()}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %P.pickup_resolved_backwards(table, seat, n, present) : {A.machine_pickup_resolved(world, seats, seat, _) == A.expected_pickup(world, seats, seat) : A.RefStep()}
      %P.seat_self_backwards(seat) : {A.machine_pickup_same(world, seats, seat, _) == A.expected_pickup(world, seats, seat) : A.RefStep()}
      {==}

def accepted_raw(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>, accepted: {A.pickup_accepted(world, seats, seat, notes) == True{} : Bool}) -> {A.raw_accepted(world, seats, seat) == True{} : Bool}:
  accepted

def ref_pickup(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, +n: Nat, +present: A.seated(world, seat), accepted: {A.raw_accepted(world, seats, seat) == True{} : Bool}) -> {A.ref_answer(A.raw_idle(world, seats, seat, notes), n) == A.expected_pickup(world, seats, seat) : A.RefStep()}:
  Equal.trans(A.RefStep(), A.ref_answer(A.raw_idle(world, seats, seat, notes), n), A.ref_answer(A.ref_idle_choose(world, seats, seat, notes), n), A.expected_pickup(world, seats, seat), Equal.cong(A.Ref(), A.RefStep(), state => A.ref_answer(state, n), A.raw_idle(world, seats, seat, notes), A.ref_idle_choose(world, seats, seat, notes), ref_idle_canonical(world, seats, seat, notes, present)), ref_pickup_choose(world, seats, seat, notes, n, present, accepted))

def machine_pickup_backwards(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, +n: Nat, present: A.seated(world, seat)) -> {A.expected_pickup(world, seats, seat) == A.pickup_step(world, seats, seat, notes, n) : A.RefStep()}:
  %machine_pickup(world, seats, seat, notes, n, present) : {_ == A.pickup_step(world, seats, seat, notes, n) : A.RefStep()}
  {==}

def input_roundtrip(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, +n: Nat) -> {A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n) == A.ref_answer(A.raw_idle(world, seats, seat, notes), n) : A.RefStep()}:
  Equal.cong(A.Seats(), A.RefStep(), restored => A.ref_answer(A.raw_idle(world, restored, seat, notes), n), seats, seats, {==})

def machine_pickup_complete(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, +n: Nat, present: A.seated(world, seat)) -> {A.expected_pickup(world, seats, seat) == A.pickup_step(world, seats, seat, notes, n) : A.RefStep()}:
  Equal.trans(A.RefStep(), A.expected_pickup(world, seats, seat), A.expected_pickup(world, seats, seat), A.pickup_step(world, seats, seat, notes, n), Equal.cong(A.Seats(), A.RefStep(), restored => A.expected_pickup(world, restored, seat), seats, seats, {==}), machine_pickup_backwards(world, seats, seat, notes, n, present))

def law.pickup_matches(+world: A.World(), +seats: A.Seats(), +seat: A.Seat(), +notes: A.Notes(), +n: Nat, +present: A.seated(world, seat), accepted: {A.pickup_accepted(world, seats, seat, notes) == True{} : Bool}) -> {A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n) == A.pickup_step(world, seats, seat, notes, n) : A.RefStep()}:
  input : {A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n) == A.ref_answer(A.raw_idle(world, seats, seat, notes), n) : A.RefStep()} = input_roundtrip(world, seats, seat, notes, n)
  reference : {A.ref_answer(A.raw_idle(world, seats, seat, notes), n) == A.expected_pickup(world, seats, seat) : A.RefStep()} = ref_pickup(world, seats, seat, notes, n, present, accepted_raw(world, seats, seat, notes, accepted))
  machine : {A.expected_pickup(world, seats, seat) == A.pickup_step(world, seats, seat, notes, n) : A.RefStep()} = machine_pickup_complete(world, seats, seat, notes, n, present)
  Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n), A.ref_answer(A.raw_idle(world, seats, seat, notes), n), A.pickup_step(world, seats, seat, notes, n), input, Equal.trans(A.RefStep(), A.ref_answer(A.raw_idle(world, seats, seat, notes), n), A.expected_pickup(world, seats, seat), A.pickup_step(world, seats, seat, notes, n), reference, machine))


def targets_entries(+entries: List<&2, D.At<&2, A.CoreSeat>>, +holder: Maybe<&2, D.Seat>) -> {A.machine_shots_entries(entries) == A.ref_shots_entries(entries, holder) : List<&2, D.Move>}:
  match entries:
    case Nil{}:
      {==}
    case D.At{seat, S.Seat{0n, jam, cash, sl}} <> +rest:
      targets_entries(rest, holder)
    case D.At{+seat, S.Seat{1n+hp, jam, cash, sl}} <> +rest:
      Equal.cong(List<&2, D.Move>, List<&2, D.Move>, moves => D.Shoot{seat} <> moves, A.machine_shots_entries(rest), A.ref_shots_entries(rest, holder), targets_entries(rest, holder))

def targets_render(+seats: D.Ring<&2, A.CoreSeat>, +holder: Maybe<&2, D.Seat>) -> {A.machine_shots(seats) == A.ref_shots(seats, holder) : List<&2, D.Move>}:
  match seats:
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}}:
      targets_entries(D.ring.entries(A.CoreSeat, seats), holder)
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}}:
      targets_entries(D.ring.entries(A.CoreSeat, seats), holder)
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}}:
      targets_entries(D.ring.entries(A.CoreSeat, seats), holder)

def machine_pickup_actual(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>, +n: Nat, present: A.seated(world, seat)) -> {A.machine_pickup_state(world, seats, seat, notes, n) == A.aim_successor(world, seats, seat) : S.State}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %P.pickup_resolved_backwards(table, seat, n, present) : {A.machine_pickup_resolved_state(world, seats, seat, _) == A.aim_successor(world, seats, seat) : S.State}
      %P.seat_self_backwards(seat) : {A.machine_pickup_same_state(world, seats, seat, _) == A.aim_successor(world, seats, seat) : S.State}
      {==}


def targets_backwards(+seats: D.Ring<&2, A.CoreSeat>, +holder: Maybe<&2, D.Seat>) -> {A.ref_shots(seats, holder) == A.machine_shots(seats) : List<&2, D.Move>}:
  %targets_render(seats, holder) : {_ == A.machine_shots(seats) : List<&2, D.Move>}
  {==}

def successor_point(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat) -> {A.machine_point(A.aim_successor(A.world_for(world, seats), seats, seat)) == A.ref_step_point(A.expected_pickup(A.world_for(world, seats), seats, seat)) : D.Point}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}}:
          %targets_backwards(seats, Some{seat}) : {A.successor_point_with_moves(A.world_for(world, seats), seats, seat, _) == A.ref_step_point(A.expected_pickup(A.world_for(world, seats), seats, seat)) : D.Point}
          {==}
        case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}}:
          %targets_backwards(seats, Some{seat}) : {A.successor_point_with_moves(A.world_for(world, seats), seats, seat, _) == A.ref_step_point(A.expected_pickup(A.world_for(world, seats), seats, seat)) : D.Point}
          {==}
        case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}}:
          %targets_backwards(seats, Some{seat}) : {A.successor_point_with_moves(A.world_for(world, seats), seats, seat, _) == A.ref_step_point(A.expected_pickup(A.world_for(world, seats), seats, seat)) : D.Point}
          {==}


def ref_pickup_complete(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, +n: Nat, +present: A.seated(world, seat), accepted: {A.pickup_accepted(world, seats, seat, notes) == True{} : Bool}) -> {A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n) == A.expected_pickup(world, seats, seat) : A.RefStep()}:
  Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n), A.ref_answer(A.raw_idle(world, seats, seat, notes), n), A.expected_pickup(world, seats, seat), input_roundtrip(world, seats, seat, notes, n), ref_pickup(world, seats, seat, notes, n, present, accepted_raw(world, seats, seat, notes, accepted)))

def reference_successor_backwards(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, +n: Nat, +present: A.seated(world, seat), accepted: {A.pickup_accepted(world, seats, seat, notes) == True{} : Bool}) -> {A.ref_step_point(A.expected_pickup(world, seats, seat)) == A.ref_step_point(A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n)) : D.Point}:
  %ref_pickup_complete(world, seats, seat, notes, n, present, accepted) : {A.ref_step_point(_) == A.ref_step_point(A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n)) : D.Point}
  {==}

def law.pickup_point_matches(+world: A.World(), +seats: A.Seats(), +seat: A.Seat(), +notes: A.Notes(), +n: Nat, +present: A.seated(A.world_for(world, seats), seat), accepted: {A.pickup_accepted(A.world_for(world, seats), seats, seat, notes) == True{} : Bool}) -> {A.pickup_point(A.world_for(world, seats), seats, seat, notes, n) == A.ref_step_point(A.ref_answer(A.ref(A.idle(A.world_for(world, seats), seats, seat, notes)), n)) : A.RefPoint()}:
  +synced : S.World = A.world_for(world, seats)
  actual : {A.pickup_point(synced, seats, seat, notes, n) == A.machine_point(A.aim_successor(synced, seats, seat)) : D.Point} = Equal.cong(S.State, D.Point, state => A.machine_point(state), A.machine_pickup_state(synced, seats, seat, notes, n), A.aim_successor(synced, seats, seat), machine_pickup_actual(synced, seats, seat, notes, n, present))
  point : {A.machine_point(A.aim_successor(synced, seats, seat)) == A.ref_step_point(A.expected_pickup(synced, seats, seat)) : D.Point} = successor_point(world, seats, seat)
  reference : {A.ref_step_point(A.expected_pickup(synced, seats, seat)) == A.ref_step_point(A.ref_answer(A.ref(A.idle(synced, seats, seat, notes)), n)) : D.Point} = reference_successor_backwards(synced, seats, seat, notes, n, present, accepted)
  Equal.trans(D.Point, A.pickup_point(synced, seats, seat, notes, n), A.machine_point(A.aim_successor(synced, seats, seat)), A.ref_step_point(A.ref_answer(A.ref(A.idle(synced, seats, seat, notes)), n)), actual, Equal.trans(D.Point, A.machine_point(A.aim_successor(synced, seats, seat)), A.ref_step_point(A.expected_pickup(synced, seats, seat)), A.ref_step_point(A.ref_answer(A.ref(A.idle(synced, seats, seat, notes)), n)), point, reference))


def ref_request_roundtrip(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>) -> {A.ref_request(A.ref(A.pack(world, seats, phase, notes))) == A.ref_request(A.raw_state(world, seats, phase, notes)) : D.Request}:
  Equal.cong(A.Seats(), D.Request, restored => A.ref_request(A.raw_state(world, restored, phase, notes)), seats, seats, {==})


def legal_play_raw(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +aiming: Bool, notes: List<&2, D.Note>) -> {A.machine_request(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes)) : D.Request}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{a, b}:
          match aiming:
            case False{}:
              {==}
            case True{}:
              %targets_backwards(seats, Some{seat}) : {A.play_request_with_moves(A.world_for(world, seats), seat, _) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes)) : D.Request}
              {==}
        case D.Trio{a, b, c}:
          match aiming:
            case False{}:
              {==}
            case True{}:
              %targets_backwards(seats, Some{seat}) : {A.play_request_with_moves(A.world_for(world, seats), seat, _) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes)) : D.Request}
              {==}
        case D.Quad{a, b, c, d}:
          match aiming:
            case False{}:
              {==}
            case True{}:
              %targets_backwards(seats, Some{seat}) : {A.play_request_with_moves(A.world_for(world, seats), seat, _) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes)) : D.Request}
              {==}

def ref_request_backwards(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>) -> {A.ref_request(A.raw_state(world, seats, phase, notes)) == A.ref_request(A.ref(A.pack(world, seats, phase, notes))) : D.Request}:
  %ref_request_roundtrip(world, seats, phase, notes) : {_ == A.ref_request(A.ref(A.pack(world, seats, phase, notes))) : D.Request}
  {==}

def law.legal_play_exact(+world: A.World(), +seats: A.Seats(), +seat: A.Seat(), +aiming: Bool, +notes: A.Notes()) -> {A.machine_request(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)) == A.ref_request(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes))) : D.Request}:
  Equal.trans(D.Request, A.machine_request(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)), A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes)), A.ref_request(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes))), legal_play_raw(world, seats, seat, aiming, notes), ref_request_backwards(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes))


def batch_length(+deck: List<&2, S.Batch>) -> {A.ref_batch_length(deck) == List.length(&2, S.Batch, deck) : Nat}:
  match deck:
    case Nil{}:
      {==}
    case S.Batch{id, load} <> +rest:
      Equal.cong(Nat, Nat, length => 1n+length, A.ref_batch_length(rest), List.length(&2, S.Batch, rest), batch_length(rest))

def batch_length_backwards(+deck: List<&2, S.Batch>) -> {List.length(&2, S.Batch, deck) == A.ref_batch_length(deck) : Nat}:
  %batch_length(deck) : {_ == A.ref_batch_length(deck) : Nat}
  {==}

def subtract_zero(n: Nat) -> {A.subtract_zero(n) == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+k:
      {==}

def subtract_zero_backwards(+n: Nat) -> {n == A.subtract_zero(n) : Nat}:
  %subtract_zero(n) : {_ == A.subtract_zero(n) : Nat}
  {==}

def inv.batches_roundtrip(+deck: List<&2, S.Batch>) -> {A.batches_roundtrip(deck) == deck : List<&2, S.Batch>}:
  match deck:
    case Nil{}:
      {==}
    case S.Batch{+id, +load} <> +rest:
      Equal.cong(List<&2, S.Batch>, List<&2, S.Batch>, xs => S.Batch{id, load} <> xs, A.batches_roundtrip(rest), rest, inv.batches_roundtrip(rest))

def inv.batches_backwards(+deck: List<&2, S.Batch>) -> {deck == A.batches_roundtrip(deck) : List<&2, S.Batch>}:
  %inv.batches_roundtrip(deck) : {_ == A.batches_roundtrip(deck) : List<&2, S.Batch>}
  {==}

def inv.decks_roundtrip(+deck: S.Decks) -> {A.decks_roundtrip(deck) == deck : S.Decks}:
  match deck:
    case S.Decks{+a, +b, +c}:
      %inv.batches_backwards(a) : {S.Decks{_, A.batches_roundtrip(b), A.batches_roundtrip(c)} == deck : S.Decks}
      %inv.batches_backwards(b) : {S.Decks{a, _, A.batches_roundtrip(c)} == deck : S.Decks}
      %inv.batches_backwards(c) : {S.Decks{a, b, _} == deck : S.Decks}
      {==}

def inv.seats_roundtrip(+seats: A.Seats(), +holder: Maybe<&2, D.Seat>) -> {A.players(A.seats_roundtrip(seats, holder)) == A.players.free(seats) : S.Players}:
  match seats:
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}}:
      {==}
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}}:
      {==}
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}}:
      {==}

def inv.world_roundtrip(+world: S.World, seats: A.Seats(), holder: Maybe<&2, D.Seat>) -> {A.world_roundtrip(world, seats, holder) == world : S.World}:
  match world:
    case S.World{+config, +before, +round, +index, +first, +hp, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      Equal.cong(S.Decks, S.World, ds => S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, ds}, A.decks_roundtrip(deck), deck, inv.decks_roundtrip(deck))

def inv.batch_phase(+deck: A.RefBatches(), h: A.RefHost()) -> {A.batch_phase(deck, h) == S.NeedBatch{} : S.Phase}:
  match deck:
    case Nil{}:
      {==}
    case a <> Nil{}:
      {==}
    case a <> b <> rest:
      {==}

def inv.aim_phase(+world: S.World, +seats: A.Seats(), +seat: D.Seat) -> {A.phase_roundtrip(world, seats, A.Aim{seat}) == A.request_phase(A.Aim{seat}, seats) : S.Phase}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      {==}

def inv.idle_phase(+world: S.World, +seats: A.Seats(), +seat: D.Seat) -> {A.idle_options_roundtrip(world, seats, seat) == Nil{} : List<&2, S.IdleOption>}:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
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

def inv.phase_roundtrip(+world: S.World, +seats: A.Seats(), +phase: A.RequestPhase) -> {A.phase_roundtrip(world, seats, phase) == A.request_phase(phase, seats) : S.Phase}:
  match phase:
    case A.First{}:
      {==}
    case A.Health{}:
      {==}
    case A.Amount{}:
      {==}
    case A.Batch{}:
      inv.batch_phase(A.selected_deck(world, seats), A.host(world, seats))
    case A.Swap{load, shells, i}:
      {==}
    case A.Idle{+seat}:
      Equal.cong(List<&2, S.IdleOption>, S.Phase, xs => S.Idle{seat, D.NonEmpty{S.TakeGun{}, xs}}, A.idle_options_roundtrip(world, seats, seat), Nil{}, inv.idle_phase(world, seats, seat))
    case A.Aim{seat}:
      inv.aim_phase(world, seats, seat)
    case A.Ended{}:
      {==}
    case A.Blocked{}:
      {==}

def inv.world_backwards(+world: S.World, +seats: A.Seats(), +holder: Maybe<&2, D.Seat>) -> {world == A.world_roundtrip(world, seats, holder) : S.World}:
  %inv.world_roundtrip(world, seats, holder) : {_ == A.world_roundtrip(world, seats, holder) : S.World}
  {==}

def inv.seats_backwards(+seats: A.Seats(), +holder: Maybe<&2, D.Seat>) -> {A.players.free(seats) == A.players(A.seats_roundtrip(seats, holder)) : S.Players}:
  %inv.seats_roundtrip(seats, holder) : {_ == A.players(A.seats_roundtrip(seats, holder)) : S.Players}
  {==}

def inv.grabs_roundtrip(+world: S.World, +seats: A.Seats(), +holder: Maybe<&2, D.Seat>) -> {A.grabs_roundtrip(world, seats, holder) == A.grabs(seats) : S.Grabs}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}}:
          {==}
        case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}}:
          {==}
        case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}}:
          {==}

def inv.grabs_backwards(+world: S.World, +seats: A.Seats(), +holder: Maybe<&2, D.Seat>) -> {A.grabs(seats) == A.grabs_roundtrip(world, seats, holder) : S.Grabs}:
  %inv.grabs_roundtrip(world, seats, holder) : {_ == A.grabs_roundtrip(world, seats, holder) : S.Grabs}
  {==}

def inv.phase_backwards(+world: S.World, +seats: A.Seats(), +phase: A.RequestPhase) -> {A.request_phase(phase, seats) == A.phase_roundtrip(world, seats, phase) : S.Phase}:
  %inv.phase_roundtrip(world, seats, phase) : {_ == A.phase_roundtrip(world, seats, phase) : S.Phase}
  {==}

def inv.restored_parts(+world: S.World, +seats: A.Seats(), +phase: A.RequestPhase, +notes: A.Notes()) -> {A.restored_parts(world, seats, phase, notes) == A.canonical(world, seats, phase, notes) : S.State}:
  %inv.world_backwards(world, seats, A.turn.holder(A.request_phase(phase, seats))) : {S.State{_, A.players(A.seats_roundtrip(seats, A.turn.holder(A.request_phase(phase, seats)))), A.phase_roundtrip(world, seats, phase), notes, A.grabs_roundtrip(world, seats, A.turn.holder(A.request_phase(phase, seats)))} == A.canonical(world, seats, phase, notes) : S.State}
  %inv.seats_backwards(seats, A.turn.holder(A.request_phase(phase, seats))) : {S.State{world, _, A.phase_roundtrip(world, seats, phase), notes, A.grabs_roundtrip(world, seats, A.turn.holder(A.request_phase(phase, seats)))} == A.canonical(world, seats, phase, notes) : S.State}
  %inv.grabs_backwards(world, seats, A.turn.holder(A.request_phase(phase, seats))) : {S.State{world, A.players.free(seats), A.phase_roundtrip(world, seats, phase), notes, _} == A.canonical(world, seats, phase, notes) : S.State}
  %inv.phase_backwards(world, seats, phase) : {S.State{world, A.players.free(seats), _, notes, A.grabs(seats)} == A.canonical(world, seats, phase, notes) : S.State}
  {==}

def inv.raw_expansion(+world: S.World, +seats: A.Seats(), +phase: A.RequestPhase, +notes: A.Notes()) -> {A.back(A.raw_canonical(world, seats, phase, notes)) == A.restored_parts(world, seats, phase, notes) : S.State}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      {==}

def inv.raw_roundtrip(+world: S.World, +seats: A.Seats(), +phase: A.RequestPhase, +notes: A.Notes()) -> {A.back(A.raw_canonical(world, seats, phase, notes)) == A.canonical(world, seats, phase, notes) : S.State}:
  Equal.trans(S.State, A.back(A.raw_canonical(world, seats, phase, notes)), A.restored_parts(world, seats, phase, notes), A.canonical(world, seats, phase, notes), inv.raw_expansion(world, seats, phase, notes), inv.restored_parts(world, seats, phase, notes))

def inv.ref_core_roundtrip(+world: S.World, +seats: A.Seats(), +phase: A.RequestPhase, +notes: A.Notes()) -> {A.back(A.ref(A.canonical(world, seats, phase, notes))) == A.back(A.raw_canonical(world, seats, phase, notes)) : S.State}:
  {==}

def law.state_roundtrip(+world: S.World, +seats: A.Seats(), +phase: A.RequestPhase, +notes: A.Notes()) -> {A.back(A.ref(A.pack(world, seats, A.request_phase(phase, seats), notes))) == A.pack(world, seats, A.request_phase(phase, seats), notes) : S.State}:
  Equal.trans(S.State, A.back(A.ref(A.canonical(world, seats, phase, notes))), A.back(A.raw_canonical(world, seats, phase, notes)), A.canonical(world, seats, phase, notes), inv.ref_core_roundtrip(world, seats, phase, notes), inv.raw_roundtrip(world, seats, phase, notes))

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
    case D.At{+seat, S.Seat{hp, _, _, sl}} <> +rest:
      turn_cons(hp, D.seat.eq(seat, current), seat, A.turn_entries_machine(rest, current), A.turn_entries_ref(rest, current), turn_entries(rest, current))

def turn_candidates_match(+seats: D.Ring<&2, A.CoreSeat>, +current: D.Seat) -> {Q.turn_candidates(D.ring.entries(Nat, A.seats.health(seats)), current) == A.turn_candidates_ref(seats, current) : List<&2, D.Seat>}:
  match seats:
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}}:
      turn_entries(D.ring.entries(A.CoreSeat, seats), current)
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}}:
      turn_entries(D.ring.entries(A.CoreSeat, seats), current)
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}}:
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

def law.turn_traversal(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +current: D.Seat) -> {Q.next_turn(A.seats.health(seats), S.world.direction(world), current) == A.ref_turn(world, seats, current) : D.Seat}:
  turn_raw(world, seats, current)

def public(+world: S.World, players: S.Players, grabs: S.Grabs, phase: S.Phase, +seat: D.Seat, remaining: Nat, notes: List<&2, D.Note>) -> D.Obs & List<&2, D.Heard>:
  +table : D.Table = S.world.table(world)
  views : D.Ring<&2, D.SeatView> = PView.seat.views(D.table.seats(table), players, grabs, D.ring.fill(D.SeatView, table, D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}}))
  (D.Obs{seat, D.Board{D.RoundView{S.world.round_index(world), D.plan.length(S.world.plan(world)), S.world.round_health(world)}, views, D.GunView{S.world.shown(world), remaining, S.world.sawed(world)}, S.world.direction(world), PView.phase.stage(phase)}}, D.hear(notes, seat))


def law.privacy(+state: S.State, +gun: List<&2, D.Shell>, decks: S.Decks, +seat: D.Seat, same_length: {List.length(&2, D.Shell, S.world.gun(S.state.world(state))) == List.length(&2, D.Shell, gun) : Nat}) -> {(D.observe(M.point(state), seat), D.hear(S.state.notes(state), seat)) == (D.observe(M.point(M.replace_hidden(state, gun, decks)), seat), D.hear(S.state.notes(M.replace_hidden(state, gun, decks)), seat)) : D.Obs & List<&2, D.Heard>}:
  match state:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match world:
        case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, +old, shown, deck}:
          match config:
            case D.Config{table, plan}:
              Equal.cong(Nat, D.Obs & List<&2, D.Heard>, remaining => public(world, players, grabs, phase, seat, remaining, notes), List.length(&2, D.Shell, old), List.length(&2, D.Shell, gun), same_length)

def law.jam_skip_once(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes()) -> ({A.grant.dispatch(A.grant.pass(world, seats, seat, notes)) == A.grant.pass_case(world, A.grant.jam(seats, seat), seat, notes) : A.Ref()} & A.grant.once_claim(A.grant.jam(seats, seat), seat)):
  GrantProof.jam_skip_once(world, seats, seat, notes)

def await_driver(fuel: Nat, request: D.Request, +h: A.RefHost(), +stage: D.Stage, +continuation: A.RefContinuation(), +notes: A.Notes(), +tape: List<&2, Nat>) -> {A.ref_run(fuel, A.ref_await(h, request, stage, continuation, notes), tape) == A.ref_driver(fuel, request, A.ref_await(h, request, stage, continuation, notes), tape) : A.RefRan()}:
  match fuel request tape:
    case 0n D.Finished{} Nil{}:
      {==}
    case 0n D.Finished{} n <> rest:
      {==}
    case 0n D.Stuck{} Nil{}:
      {==}
    case 0n D.Stuck{} n <> rest:
      {==}
    case 0n D.Draw{kind, range} Nil{}:
      {==}
    case 0n D.Draw{kind, range} n <> rest:
      {==}
    case 0n D.Choose{menus} Nil{}:
      {==}
    case 0n D.Choose{menus} n <> rest:
      {==}
    case 1n+fuel D.Finished{} Nil{}:
      {==}
    case 1n+fuel D.Finished{} n <> rest:
      {==}
    case 1n+fuel D.Stuck{} Nil{}:
      {==}
    case 1n+fuel D.Stuck{} n <> rest:
      {==}
    case 1n+fuel D.Draw{kind, range} Nil{}:
      {==}
    case 1n+fuel D.Choose{menus} Nil{}:
      {==}
    case 1n+fuel D.Draw{kind, range} n <> rest:
      {==}
    case 1n+fuel D.Choose{menus} n <> rest:
      {==}

def batch_exposed(+deck: A.RefBatches(), +h: A.RefHost(), +notes: A.Notes()) -> {A.pending.batch_raw(h, deck, notes) == A.pending.batch_exposed(h, deck, notes) : A.Ref()}:
  match deck:
    case Nil{}:
      {==}
    case a <> Nil{}:
      {==}
    case a <> b <> rest:
      {==}

def exposed_ref(+state: S.State) -> {A.ref(state) == A.exposed_ref(state) : A.Ref()}:
  match state:
    case S.State{+world, +players, phase, +notes, +grabs}:
      match phase:
        case S.NeedFirst{}:
          {==}
        case S.NeedHealth{}:
          {==}
        case S.NeedAmount{}:
          {==}
        case S.NeedBatch{}:
          batch_exposed(A.ref_deck(state), A.ref_host(state), notes)
        case S.NeedSwap{load, shells, i}:
          {==}
        case S.Idle{seat, options}:
          {==}
        case S.Aim{seat}:
          {==}
        case S.Ended{}:
          {==}
        case S.Blocked{holder}:
          {==}
        case S.NeedTurnAmount{from, passing, winner}:
          {==}
        case S.Grab{needs}:
          {==}
        case S.NeedItem{seat, first, second, rest}:
          {==}
        case S.NeedPhone{seat, owner, slot}:
          {==}
        case S.JamPick{seat, targets}:
          {==}
        case S.StealPick{seat, picks}:
          {==}

def pending_driver(+pending: A.Pending, +fuel: Nat, +h: A.RefHost(), +notes: A.Notes(), +tape: List<&2, Nat>) -> {A.ref_run(fuel, A.pending.state(h, pending, notes), tape) == A.ref_driver(fuel, A.pending.request(pending), A.pending.state(h, pending, notes), tape) : A.RefRan()}:
  match pending:
    case A.Pending{request, stage, continuation}:
      await_driver(fuel, request, h, stage, continuation, notes, tape)

def pending_request_raw(+pending: A.Pending, +h: A.RefHost(), +notes: A.Notes()) -> {A.ref_request(A.pending.state(h, pending, notes)) == A.pending.request(pending) : D.Request}:
  match pending:
    case A.Pending{request, stage, continuation}:
      {==}

def driver_exposed(+fuel: Nat, +state: S.State, +tape: List<&2, Nat>) -> {A.ref_run(fuel, A.exposed_ref(state), tape) == A.ref_driver(fuel, A.ref_request(A.exposed_ref(state)), A.exposed_ref(state), tape) : A.RefRan()}:
  Equal.trans(A.RefRan(), A.ref_run(fuel, A.exposed_ref(state), tape), A.ref_driver(fuel, A.pending.request(A.ref_pending(state)), A.exposed_ref(state), tape), A.ref_driver(fuel, A.ref_request(A.exposed_ref(state)), A.exposed_ref(state), tape), pending_driver(A.ref_pending(state), fuel, A.ref_host(state), S.state.notes(state), tape), Equal.cong(D.Request, A.RefRan(), request => A.ref_driver(fuel, request, A.exposed_ref(state), tape), A.pending.request(A.ref_pending(state)), A.ref_request(A.exposed_ref(state)), Equal.sym(D.Request, A.ref_request(A.exposed_ref(state)), A.pending.request(A.ref_pending(state)), pending_request_raw(A.ref_pending(state), A.ref_host(state), S.state.notes(state)))))

def ref_run_driver(+fuel: Nat, +state: S.State, +tape: List<&2, Nat>) -> {A.ref_run(fuel, A.ref(state), tape) == A.ref_driver(fuel, A.ref_request(A.ref(state)), A.ref(state), tape) : A.RefRan()}:
  %Equal.sym(A.Ref(), A.ref(state), A.exposed_ref(state), exposed_ref(state)) : {A.ref_run(fuel, _, tape) == A.ref_driver(fuel, A.ref_request(_), _, tape) : A.RefRan()}
  driver_exposed(fuel, state, tape)

def merge_matches(+step: D.Stepped<&2, S.State>, +ran: D.Ran<&2, S.State>) -> {A.ref_merge(A.stepped(step), A.ran(ran)) == A.ran(A.machine_merge(step, ran)) : A.RefRan()}:
  match step ran:
    case D.Stepped{before, first} D.Ran{state, rest, tape}:
      {==}

def merge_lift(+machine_step: D.Stepped<&2, S.State>, +fuel: Nat, +tape: List<&2, Nat>, ih: {A.ref_run(fuel, A.ref(M.stepped.state(machine_step)), tape) == A.ran(M.run(fuel, M.stepped.state(machine_step), tape)) : A.RefRan()}) -> {A.ref_merge(A.stepped(machine_step), A.ref_run(fuel, A.ref_next(A.stepped(machine_step)), tape)) == A.ran(A.machine_merge(machine_step, M.run(fuel, M.stepped.state(machine_step), tape))) : A.RefRan()}:
  match machine_step:
    case D.Stepped{+state, notes}:
      Equal.trans(A.RefRan(), A.ref_merge(A.stepped(machine_step), A.ref_run(fuel, A.ref(state), tape)), A.ref_merge(A.stepped(machine_step), A.ran(M.run(fuel, state, tape))), A.ran(A.machine_merge(machine_step, M.run(fuel, state, tape))), Equal.cong(A.RefRan(), A.RefRan(), result => A.ref_merge(A.stepped(machine_step), result), A.ref_run(fuel, A.ref(state), tape), A.ran(M.run(fuel, state, tape)), ih), merge_matches(machine_step, M.run(fuel, state, tape)))

def next_run_transport(+step: D.Stepped<&2, S.State>, +fuel: Nat, +tape: List<&2, Nat>, proof: {A.ref_run(fuel, A.ref(A.machine_step_state(step)), tape) == A.ran(M.run(fuel, A.machine_step_state(step), tape)) : A.RefRan()}) -> {A.ref_run(fuel, A.ref(M.stepped.state(step)), tape) == A.ran(M.run(fuel, M.stepped.state(step), tape)) : A.RefRan()}:
  match step:
    case D.Stepped{state, notes}:
      proof

def run_zero(request: D.Request, +state: S.State, +tape: List<&2, Nat>) -> {A.ref_driver(0n, request, A.ref(state), tape) == A.ran(M.run.request(0n, request, state, tape)) : A.RefRan()}:
  match request tape:
    case D.Finished{} Nil{}:
      {==}
    case D.Finished{} n <> rest:
      {==}
    case D.Stuck{} Nil{}:
      {==}
    case D.Stuck{} n <> rest:
      {==}
    case D.Draw{kind, range} Nil{}:
      {==}
    case D.Draw{kind, range} n <> rest:
      {==}
    case D.Choose{menus} Nil{}:
      {==}
    case D.Choose{menus} n <> rest:
      {==}

def loadproof.shell_nth(+shells: List<&2, D.Shell>, +index: Nat) -> {A.ref_shell_nth(shells, index) == A.machine_shell_nth(shells, index) : Maybe<&2, D.Shell>}:
  match shells index:
    case Nil{} _:
      {==}
    case shell <> rest 0n:
      {==}
    case shell <> rest 1n+k:
      loadproof.shell_nth(rest, k)

def loadproof.shell_set(+shells: List<&2, D.Shell>, +index: Nat, +shell: D.Shell) -> {A.ref_shell_set(shells, index, shell) == A.machine_shell_set(shells, index, shell) : List<&2, D.Shell>}:
  match shells index:
    case Nil{} _:
      {==}
    case old <> rest 0n:
      {==}
    case +old <> +rest 1n+k:
      Equal.cong(List<&2, D.Shell>, List<&2, D.Shell>, tail => old <> tail, A.ref_shell_set(rest, k, shell), A.machine_shell_set(rest, k, shell), loadproof.shell_set(rest, k, shell))

def loadproof.swap_found(+shells: List<&2, D.Shell>, +i: Nat, +j: Nat, +x: Maybe<&2, D.Shell>, +y: Maybe<&2, D.Shell>) -> {A.ref_swap_found(shells, i, j, x, y) == A.machine_swap_found(shells, i, j, x, y) : List<&2, D.Shell>}:
  match x y:
    case Some{+a} Some{+b}:
      Equal.trans(List<&2, D.Shell>, A.ref_shell_set(A.ref_shell_set(shells, i, b), j, a), A.ref_shell_set(A.machine_shell_set(shells, i, b), j, a), A.machine_shell_set(A.machine_shell_set(shells, i, b), j, a), Equal.cong(List<&2, D.Shell>, List<&2, D.Shell>, list => A.ref_shell_set(list, j, a), A.ref_shell_set(shells, i, b), A.machine_shell_set(shells, i, b), loadproof.shell_set(shells, i, b)), loadproof.shell_set(A.machine_shell_set(shells, i, b), j, a))
    case None{} None{}:
      {==}
    case None{} Some{b}:
      {==}
    case Some{a} None{}:
      {==}

def loadproof.swap_shells(+shells: List<&2, D.Shell>, +i: Nat, +j: Nat) -> {A.ref_swap(shells, i, j) == A.machine_swap(shells, i, j) : List<&2, D.Shell>}:
  first : {A.ref_swap_found(shells, i, j, A.ref_shell_nth(shells, i), A.ref_shell_nth(shells, j)) == A.ref_swap_found(shells, i, j, A.machine_shell_nth(shells, i), A.ref_shell_nth(shells, j)) : List<&2, D.Shell>} = Equal.cong(Maybe<&2, D.Shell>, List<&2, D.Shell>, found => A.ref_swap_found(shells, i, j, found, A.ref_shell_nth(shells, j)), A.ref_shell_nth(shells, i), A.machine_shell_nth(shells, i), loadproof.shell_nth(shells, i))
  second : {A.ref_swap_found(shells, i, j, A.machine_shell_nth(shells, i), A.ref_shell_nth(shells, j)) == A.ref_swap_found(shells, i, j, A.machine_shell_nth(shells, i), A.machine_shell_nth(shells, j)) : List<&2, D.Shell>} = Equal.cong(Maybe<&2, D.Shell>, List<&2, D.Shell>, found => A.ref_swap_found(shells, i, j, A.machine_shell_nth(shells, i), found), A.ref_shell_nth(shells, j), A.machine_shell_nth(shells, j), loadproof.shell_nth(shells, j))
  final : {A.ref_swap_found(shells, i, j, A.machine_shell_nth(shells, i), A.machine_shell_nth(shells, j)) == A.machine_swap_found(shells, i, j, A.machine_shell_nth(shells, i), A.machine_shell_nth(shells, j)) : List<&2, D.Shell>} = loadproof.swap_found(shells, i, j, A.machine_shell_nth(shells, i), A.machine_shell_nth(shells, j))
  Equal.trans(List<&2, D.Shell>, A.ref_swap(shells, i, j), A.ref_swap_found(shells, i, j, A.machine_shell_nth(shells, i), A.ref_shell_nth(shells, j)), A.machine_swap(shells, i, j), first, Equal.trans(List<&2, D.Shell>, A.ref_swap_found(shells, i, j, A.machine_shell_nth(shells, i), A.ref_shell_nth(shells, j)), A.ref_swap_found(shells, i, j, A.machine_shell_nth(shells, i), A.machine_shell_nth(shells, j)), A.machine_swap(shells, i, j), second, final))


def loadproof.found_round(found: Maybe<&2, D.RoundRules>) -> {A.ref_rules_found(found) == A.machine_rules_found(found) : D.RoundRules}:
  match found:
    case None{}:
      {==}
    case Some{round}:
      {==}

def loadproof.round_load(+round: D.RoundRules, +index: Nat) -> {A.ref_round_load(round, index) == A.machine_round_load(round, index) : D.LoadRule}:
  match round index:
    case D.RoundRules{health, D.LoadRules{a, b, c, d}, items} 0n:
      {==}
    case D.RoundRules{health, D.LoadRules{a, b, c, d}, items} 1n:
      {==}
    case D.RoundRules{health, D.LoadRules{a, b, c, d}, items} 2n:
      {==}
    case D.RoundRules{health, D.LoadRules{a, b, c, d}, items} 3n+k:
      {==}

def loadproof.world_rules(+world: S.World, seats: D.Ring<&2, A.CoreSeat>) -> {A.ref_world_rules(world, seats) == A.machine_world_rules(world) : D.RoundRules}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      loadproof.found_round(D.plan.round(plan, round))

def loadproof.world_load(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>) -> {A.ref_world_load(world, seats) == A.machine_world_load(world) : D.LoadRule}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      Equal.trans(D.LoadRule, A.ref_round_load(A.ref_world_rules(world, seats), index), A.ref_round_load(A.machine_world_rules(world), index), A.machine_round_load(A.machine_world_rules(world), index), Equal.cong(D.RoundRules, D.LoadRule, rules => A.ref_round_load(rules, index), A.ref_world_rules(world, seats), A.machine_world_rules(world), loadproof.world_rules(world, seats)), loadproof.round_load(A.machine_world_rules(world), index))


# No-item scope: with every item disabled in the current round, pools are
# empty, nobody begins grabbing, and distribution falls through to loading.
# Phase 6 generalizes these.

# An empty gun with no winner reloads without an amount draw: nobody could grab.
# round.reset with no items skips distribution and loads.
def loadproof.load_next(+first: Bool, +index: Nat) -> {A.ref_next_load(first, index) == A.machine_next_load(first, index) : Nat}:
  match first index:
    case True{} _:
      {==}
    case False{} 0n:
      {==}
    case False{} 1n:
      {==}
    case False{} 2n:
      {==}
    case False{} 3n+k:
      {==}


def loadproof.load_actual(+rule: D.LoadRule, +sampled: D.Load) -> {A.ref_load_actual(rule, sampled) == A.machine_load_actual(rule, sampled) : D.Load}:
  match rule:
    case D.LoadRule{D.RandomShells{}, items}:
      {==}
    case D.LoadRule{D.FixedShells{live, blank}, items}:
      {==}
    case D.LoadRule{D.AllLive{live}, items}:
      {==}

def loadproof.shell_repeat(+n: Nat, +shell: D.Shell) -> {A.ref_shell_repeat(n, shell) == A.machine_shell_repeat(n, shell) : List<&2, D.Shell>}:
  match n:
    case 0n:
      {==}
    case 1n+k:
      Equal.cong(List<&2, D.Shell>, List<&2, D.Shell>, tail => shell <> tail, A.ref_shell_repeat(k, shell), A.machine_shell_repeat(k, shell), loadproof.shell_repeat(k, shell))

def loadproof.load_shells(+load: D.Load) -> {A.ref_load_shells(load) == A.machine_load_shells(load) : List<&2, D.Shell>}:
  match load:
    case D.Load{+live, +blank}:
      %Equal.sym(List<&2, D.Shell>, A.ref_shell_repeat(live, D.Live{}), A.machine_shell_repeat(live, D.Live{}), loadproof.shell_repeat(live, D.Live{})) : {List.append(&2, D.Shell, _, A.ref_shell_repeat(blank, D.Blank{})) == A.machine_load_shells(load) : List<&2, D.Shell>}
      Equal.cong(List<&2, D.Shell>, List<&2, D.Shell>, tail => List.append(&2, D.Shell, A.machine_shell_repeat(live, D.Live{}), tail), A.ref_shell_repeat(blank, D.Blank{}), A.machine_shell_repeat(blank, D.Blank{}), loadproof.shell_repeat(blank, D.Blank{}))

def loadproof.predecessor(+n: Nat) -> {A.ref_predecessor(n) == A.machine_predecessor(n) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+k:
      subtract_zero(k)

def loadproof.batch_nth(+deck: List<&2, S.Batch>, +index: Nat) -> {A.ref_batch_nth(deck, index) == A.machine_batch_nth(deck, index) : Maybe<&2, A.RefBatch()>}:
  match deck index:
    case Nil{} _:
      {==}
    case S.Batch{id, load} <> rest 0n:
      {==}
    case S.Batch{id, load} <> +rest 1n+k:
      loadproof.batch_nth(rest, k)

def loadproof.batch_remove(+deck: List<&2, S.Batch>, +index: Nat) -> {A.ref_batch_remove(deck, index) == A.machine_batch_remove(deck, index) : List<&2, A.RefBatch()>}:
  match deck index:
    case Nil{} _:
      {==}
    case S.Batch{id, load} <> rest 0n:
      {==}
    case S.Batch{+id, +load} <> +rest 1n+k:
      Equal.cong(List<&2, A.RefBatch()>, List<&2, A.RefBatch()>, tail => A.ref_batch(S.Batch{id, load}) <> tail, A.ref_batch_remove(rest, k), A.machine_batch_remove(rest, k), loadproof.batch_remove(rest, k))


def loadproof.actual_world_load(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +sampled: D.Load) -> {A.ref_load_actual(A.ref_world_load(world, seats), sampled) == A.machine_load_actual(A.machine_world_load(world), sampled) : D.Load}:
  rules : {A.ref_load_actual(A.ref_world_load(world, seats), sampled) == A.ref_load_actual(A.machine_world_load(world), sampled) : D.Load} = Equal.cong(D.LoadRule, D.Load, rule => A.ref_load_actual(rule, sampled), A.ref_world_load(world, seats), A.machine_world_load(world), loadproof.world_load(world, seats))
  Equal.trans(D.Load, A.ref_load_actual(A.ref_world_load(world, seats), sampled), A.ref_load_actual(A.machine_world_load(world), sampled), A.machine_load_actual(A.machine_world_load(world), sampled), rules, loadproof.load_actual(A.machine_world_load(world), sampled))

def loadproof.generated_batches(+loads: List<&2, D.Load>, +index: Nat) -> {A.ref_generated_batches(loads, index) == A.machine_generated_batches(loads, index) : List<&2, A.RefBatch()>}:
  match loads:
    case Nil{}:
      {==}
    case +load <> +rest:
      Equal.cong(List<&2, A.RefBatch()>, List<&2, A.RefBatch()>, tail => A.ref_batch(S.Batch{index, load}) <> tail, A.ref_generated_batches(rest, 1n+index), A.machine_generated_batches(rest, 1n+index), loadproof.generated_batches(rest, 1n+index))

def loadproof.full_decks() -> {A.ref_full_decks() == A.machine_full_decks() : A.RefDecks()}:
  %Equal.sym(List<&2, A.RefBatch()>, A.ref_generated_batches(D.table.deck(D.TwoSeats{}), 0n), A.machine_generated_batches(D.table.deck(D.TwoSeats{}), 0n), loadproof.generated_batches(D.table.deck(D.TwoSeats{}), 0n)) : {A.ref_decks3(_, A.ref_generated_batches(D.table.deck(D.ThreeSeats{}), 0n), A.ref_generated_batches(D.table.deck(D.FourSeats{}), 0n)) == A.machine_full_decks() : A.RefDecks()}
  %Equal.sym(List<&2, A.RefBatch()>, A.ref_generated_batches(D.table.deck(D.ThreeSeats{}), 0n), A.machine_generated_batches(D.table.deck(D.ThreeSeats{}), 0n), loadproof.generated_batches(D.table.deck(D.ThreeSeats{}), 0n)) : {A.ref_decks3(A.machine_generated_batches(D.table.deck(D.TwoSeats{}), 0n), _, A.ref_generated_batches(D.table.deck(D.FourSeats{}), 0n)) == A.machine_full_decks() : A.RefDecks()}
  Equal.cong(List<&2, A.RefBatch()>, A.RefDecks(), tail => A.ref_decks3(A.machine_generated_batches(D.table.deck(D.TwoSeats{}), 0n), A.machine_generated_batches(D.table.deck(D.ThreeSeats{}), 0n), tail), A.ref_generated_batches(D.table.deck(D.FourSeats{}), 0n), A.machine_generated_batches(D.table.deck(D.FourSeats{}), 0n), loadproof.generated_batches(D.table.deck(D.FourSeats{}), 0n))

def plan_nonempty(plan: D.Plan) -> {Nat.is_lt(0n, D.plan.length(plan)) == True{} : Bool}:
  match plan:
    case D.OneRound{a}:
      {==}
    case D.TwoRounds{a, b}:
      {==}
    case D.ThreeRounds{a, b, c}:
      {==}

def point_stepped(+step: D.Stepped<&2, S.State>) -> {A.point_of_ref(A.machine_step_state(step)) == A.ref_step_point(A.stepped(step)) : D.Point}:
  match step:
    case D.Stepped{state, notes}:
      {==}

# The reference accepts the idle seat's pick-up exactly when it holds world.turn.
def aimproof.rules_found_matches(found: Maybe<&2, D.RoundRules>) -> {Q.value.or(D.RoundRules, found, D.config.default_round()) == A.turn.source_rules_found(found) : D.RoundRules}:
  match found:
    case None{}:
      {==}
    case Some{round}:
      {==}

def aimproof.rules_matches(+world: S.World, seats: A.Seats()) -> {Q.world.rules(world) == A.turn.source_rules(world, seats) : D.RoundRules}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      aimproof.rules_found_matches(D.plan.round(plan, round))

def aimproof.round_load_matches(+round: D.RoundRules, +index: Nat) -> {Q.round.load(round, index) == A.turn.source_load(round, index) : D.LoadRule}:
  match round index:
    case D.RoundRules{health, D.LoadRules{a, b, c, d}, items} 0n:
      {==}
    case D.RoundRules{health, D.LoadRules{a, b, c, d}, items} 1n:
      {==}
    case D.RoundRules{health, D.LoadRules{a, b, c, d}, items} 2n:
      {==}
    case D.RoundRules{health, D.LoadRules{a, b, c, d}, items} 3n+rest:
      {==}

def aimproof.load_rule_matches(+world: S.World, +seats: A.Seats()) -> {Q.world.load_rule(world) == A.turn.source_load_rule(world, seats) : D.LoadRule}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      Equal.trans(D.LoadRule, Q.world.load_rule(world), A.turn.source_load(Q.world.rules(world), index), A.turn.source_load_rule(world, seats), aimproof.round_load_matches(Q.world.rules(world), index), Equal.cong(D.RoundRules, D.LoadRule, round => A.turn.source_load(round, index), Q.world.rules(world), A.turn.source_rules(world, seats), aimproof.rules_matches(world, seats)))

def aimproof.amount_of_matches(rule: D.LoadRule) -> {Q.load.amount(rule) == A.turn.source_amount_of(rule) : D.AmountRule}:
  match rule:
    case D.LoadRule{shells, amount}:
      {==}

def aimproof.amount_rule_matches(+world: S.World, +seats: A.Seats()) -> {Q.load.amount(Q.world.load_rule(world)) == A.turn.source_amount_rule(world, seats) : D.AmountRule}:
  Equal.trans(D.AmountRule, Q.load.amount(Q.world.load_rule(world)), A.turn.source_amount_of(Q.world.load_rule(world)), A.turn.source_amount_rule(world, seats), aimproof.amount_of_matches(Q.world.load_rule(world)), Equal.cong(D.LoadRule, D.AmountRule, A.turn.source_amount_of, Q.world.load_rule(world), A.turn.source_load_rule(world, seats), aimproof.load_rule_matches(world, seats)))

def merge_final_state(+step: D.Stepped<&2, S.State>, +ran: D.Ran<&2, S.State>) -> {A.machine_ran_state(M.run.merge(step, ran)) == A.machine_ran_state(ran) : S.State}:
  match step ran:
    case D.Stepped{before, first} D.Ran{state, notes, tape}:
      {==}

# Split shape, shooter, target, shell and the written health so the reference chain DeathRequest..CheckIfEndingTurn computes; every leaf is the same tail call.
# Split the ring shape, each seat health (0n or 1n+_) and the tape answer until the menu, the chosen index and the target are concrete.
