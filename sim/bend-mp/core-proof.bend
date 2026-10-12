import Base
import ./support-proof.bend as SupportProof
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
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
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

def core_backwards(+seats: D.Ring<&2, A.CoreSeat>) -> {seats == A.core(A.players(seats)) : D.Ring<&2, A.CoreSeat>}:
  %law.core_roundtrip(seats) : {_ == A.core(A.players(seats)) : D.Ring<&2, A.CoreSeat>}
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


def targets_entries(+entries: List<&2, D.At<&2, A.CoreSeat>>) -> {A.machine_shots_entries(entries) == A.ref_shots_entries(entries) : List<&2, D.Move>}:
  match entries:
    case Nil{}:
      {==}
    case D.At{seat, A.CoreSeat{0n, jam, checked, cash, sl, turn}} <> +rest:
      targets_entries(rest)
    case D.At{+seat, A.CoreSeat{1n+hp, jam, checked, cash, sl, turn}} <> +rest:
      Equal.cong(List<&2, D.Move>, List<&2, D.Move>, moves => D.Shoot{seat} <> moves, A.machine_shots_entries(rest), A.ref_shots_entries(rest), targets_entries(rest))

def targets_render(+seats: D.Ring<&2, A.CoreSeat>) -> {A.machine_shots(seats) == A.ref_shots(seats) : List<&2, D.Move>}:
  match seats:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      targets_entries(D.ring.entries(A.CoreSeat, seats))
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
      targets_entries(D.ring.entries(A.CoreSeat, seats))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      targets_entries(D.ring.entries(A.CoreSeat, seats))

def machine_pickup_actual(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>, +n: Nat, present: A.seated(world, seat)) -> {A.machine_pickup_state(world, seats, seat, notes, n) == A.aim_successor(world, seats, seat) : S.State}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %P.pickup_resolved_backwards(table, seat, n, present) : {A.machine_pickup_resolved_state(world, seats, seat, _) == A.aim_successor(world, seats, seat) : S.State}
      %P.seat_self_backwards(seat) : {A.machine_pickup_same_state(world, seats, seat, _) == A.aim_successor(world, seats, seat) : S.State}
      {==}


def targets_backwards(+seats: D.Ring<&2, A.CoreSeat>) -> {A.ref_shots(seats) == A.machine_shots(seats) : List<&2, D.Move>}:
  %targets_render(seats) : {_ == A.machine_shots(seats) : List<&2, D.Move>}
  {==}

def successor_point(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat) -> {A.machine_point(A.aim_successor(A.world_for(world, seats), seats, seat)) == A.ref_step_point(A.expected_pickup(A.world_for(world, seats), seats, seat)) : D.Point}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          %targets_backwards(seats) : {A.successor_point_with_moves(A.world_for(world, seats), seats, seat, _) == A.ref_step_point(A.expected_pickup(A.world_for(world, seats), seats, seat)) : D.Point}
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
          %targets_backwards(seats) : {A.successor_point_with_moves(A.world_for(world, seats), seats, seat, _) == A.ref_step_point(A.expected_pickup(A.world_for(world, seats), seats, seat)) : D.Point}
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          %targets_backwards(seats) : {A.successor_point_with_moves(A.world_for(world, seats), seats, seat, _) == A.ref_step_point(A.expected_pickup(A.world_for(world, seats), seats, seat)) : D.Point}
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
              %targets_backwards(seats) : {A.play_request_with_moves(A.world_for(world, seats), seat, _) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes)) : D.Request}
              {==}
        case D.Trio{a, b, c}:
          match aiming:
            case False{}:
              {==}
            case True{}:
              %targets_backwards(seats) : {A.play_request_with_moves(A.world_for(world, seats), seat, _) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes)) : D.Request}
              {==}
        case D.Quad{a, b, c, d}:
          match aiming:
            case False{}:
              {==}
            case True{}:
              %targets_backwards(seats) : {A.play_request_with_moves(A.world_for(world, seats), seat, _) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes)) : D.Request}
              {==}

def ref_request_backwards(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>) -> {A.ref_request(A.raw_state(world, seats, phase, notes)) == A.ref_request(A.ref(A.pack(world, seats, phase, notes))) : D.Request}:
  %ref_request_roundtrip(world, seats, phase, notes) : {_ == A.ref_request(A.ref(A.pack(world, seats, phase, notes))) : D.Request}
  {==}

def law.legal_play_exact(+world: A.World(), +seats: A.Seats(), +seat: A.Seat(), +aiming: Bool, +notes: A.Notes()) -> {A.machine_request(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)) == A.ref_request(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes))) : D.Request}:
  Equal.trans(D.Request, A.machine_request(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)), A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes)), A.ref_request(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes))), legal_play_raw(world, seats, seat, aiming, notes), ref_request_backwards(A.world_for(world, seats), seats, A.play_phase(seat, aiming, seats), notes))


def phase_stage(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, notes: List<&2, D.Note>) -> {A.ref_phase_stage(world, seats, phase, notes) == A.machine_stage(phase) : D.Stage}:
  match phase:
    case S.NeedFirst{}:
      {==}
    case S.NeedHealth{}:
      {==}
    case S.NeedAmount{}:
      {==}
    case S.NeedBatch{}:
      A.batch_stage_matches(world, seats, notes)
    case S.NeedSwap{load, shells, i}:
      {==}
    case S.Idle{seat, options}:
      {==}
    case S.Aim{seat, options}:
      {==}
    case S.Ended{}:
      {==}
    case S.Blocked{}:
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


def machine_board_canonical(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, notes: List<&2, D.Note>) -> {A.machine_board(A.pack(A.world_for(world, seats), seats, phase, notes)) == A.board_at(A.world_for(world, seats), seats, A.machine_stage(phase)) : D.Board}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          {==}


def ref_board_canonical(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, notes: List<&2, D.Note>) -> {A.ref_board(A.raw_state(A.world_for(world, seats), seats, phase, notes)) == A.board_at(A.world_for(world, seats), seats, A.ref_phase_stage(A.world_for(world, seats), seats, phase, notes)) : D.Board}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          {==}


def ref_board_roundtrip(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>) -> {A.ref_board(A.ref(A.pack(world, seats, phase, notes))) == A.ref_board(A.raw_state(world, seats, phase, notes)) : D.Board}:
  Equal.cong(A.Seats(), D.Board, restored => A.ref_board(A.raw_state(world, restored, phase, notes)), seats, seats, {==})

def ref_board_shared(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>) -> {A.ref_board(A.ref(A.pack(A.world_for(world, seats), seats, phase, notes))) == A.board_at(A.world_for(world, seats), seats, A.machine_stage(phase)) : D.Board}:
  +synced : S.World = A.world_for(world, seats)
  representation : {A.ref_board(A.ref(A.pack(synced, seats, phase, notes))) == A.ref_board(A.raw_state(synced, seats, phase, notes)) : D.Board} = ref_board_roundtrip(synced, seats, phase, notes)
  canonical : {A.ref_board(A.raw_state(synced, seats, phase, notes)) == A.board_at(synced, seats, A.ref_phase_stage(synced, seats, phase, notes)) : D.Board} = ref_board_canonical(world, seats, phase, notes)
  stage : {A.board_at(synced, seats, A.ref_phase_stage(synced, seats, phase, notes)) == A.board_at(synced, seats, A.machine_stage(phase)) : D.Board} = Equal.cong(D.Stage, D.Board, stage => A.board_at(synced, seats, stage), A.ref_phase_stage(synced, seats, phase, notes), A.machine_stage(phase), phase_stage(synced, seats, phase, notes))
  Equal.trans(D.Board, A.ref_board(A.ref(A.pack(synced, seats, phase, notes))), A.ref_board(A.raw_state(synced, seats, phase, notes)), A.board_at(synced, seats, A.machine_stage(phase)), representation, Equal.trans(D.Board, A.ref_board(A.raw_state(synced, seats, phase, notes)), A.board_at(synced, seats, A.ref_phase_stage(synced, seats, phase, notes)), A.board_at(synced, seats, A.machine_stage(phase)), canonical, stage))

def ref_board_backwards(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>) -> {A.board_at(A.world_for(world, seats), seats, A.machine_stage(phase)) == A.ref_board(A.ref(A.pack(A.world_for(world, seats), seats, phase, notes))) : D.Board}:
  %ref_board_shared(world, seats, phase, notes) : {_ == A.ref_board(A.ref(A.pack(A.world_for(world, seats), seats, phase, notes))) : D.Board}
  {==}

def boards_match(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>) -> {A.machine_board(A.pack(A.world_for(world, seats), seats, phase, notes)) == A.ref_board(A.ref(A.pack(A.world_for(world, seats), seats, phase, notes))) : D.Board}:
  Equal.trans(D.Board, A.machine_board(A.pack(A.world_for(world, seats), seats, phase, notes)), A.board_at(A.world_for(world, seats), seats, A.machine_stage(phase)), A.ref_board(A.ref(A.pack(A.world_for(world, seats), seats, phase, notes))), machine_board_canonical(world, seats, phase, notes), ref_board_backwards(world, seats, phase, notes))

def law.observe_matches(+world: A.World(), +seats: A.Seats(), +phase: A.Phase(), +notes: A.Notes(), +seat: A.Seat()) -> {(A.observation(A.pack(A.world_for(world, seats), seats, phase, notes), seat), A.heard(A.pack(A.world_for(world, seats), seats, phase, notes), seat)) == (A.ref_observation(A.ref(A.pack(A.world_for(world, seats), seats, phase, notes)), seat), A.ref_heard(A.ref(A.pack(A.world_for(world, seats), seats, phase, notes)), seat)) : D.Obs & List<&2, D.Heard>}:
  Equal.cong(D.Board, D.Obs & List<&2, D.Heard>, board => (D.Obs{seat, board}, D.hear(notes, seat)), A.machine_board(A.pack(A.world_for(world, seats), seats, phase, notes)), A.ref_board(A.ref(A.pack(A.world_for(world, seats), seats, phase, notes))), boards_match(world, seats, phase, notes))


def batch_length(+deck: List<&2, S.Batch>) -> {A.ref_batch_length(deck) == List.length(&2, S.Batch, deck) : Nat}:
  match deck:
    case Nil{}:
      {==}
    case S.Batch{id, load} <> +rest:
      Equal.cong(Nat, Nat, length => 1n+length, A.ref_batch_length(rest), List.length(&2, S.Batch, rest), batch_length(rest))

def batch_length_backwards(+deck: List<&2, S.Batch>) -> {List.length(&2, S.Batch, deck) == A.ref_batch_length(deck) : Nat}:
  %batch_length(deck) : {_ == A.ref_batch_length(deck) : Nat}
  {==}

def batch_requests(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +deck: List<&2, S.Batch>, +notes: List<&2, D.Note>) -> {A.machine_batch_request(deck) == A.ref_batch_request(world, seats, deck, notes) : D.Request}:
  match deck:
    case Nil{}:
      {==}
    case S.Batch{id, load} <> Nil{}:
      {==}
    case S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest:
      Equal.cong(Nat, D.Request, extra => D.Draw{D.SequenceBatch{}, D.Range{0n, extra}}, List.length(&2, S.Batch, rest), A.ref_batch_length(rest), batch_length_backwards(rest))


def subtract_zero(n: Nat) -> {A.subtract_zero(n) == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+k:
      {==}

def subtract_zero_backwards(+n: Nat) -> {n == A.subtract_zero(n) : Nat}:
  %subtract_zero(n) : {_ == A.subtract_zero(n) : Nat}
  {==}

def legal_canonical_raw(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, notes: List<&2, D.Note>) -> {A.machine_request(A.canonical_state(world, seats, phase, notes)) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.canonical_phase(phase, seats), notes)) : D.Request}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, four}}:
      match seats:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          match phase:
            case S.NeedFirst{}:
              {==}
            case S.NeedHealth{}:
              {==}
            case S.NeedAmount{}:
              {==}
            case S.NeedBatch{}:
              batch_requests(A.world_for(world, seats), seats, two, notes)
            case S.NeedSwap{load, shells, 0n}:
              {==}
            case S.NeedSwap{load, shells, 1n+extra}:
              Equal.cong(Nat, D.Request, width => D.Draw{D.ShuffleSwap{}, D.Range{0n, width}}, extra, A.subtract_zero(extra), subtract_zero_backwards(extra))
            case S.Idle{seat, options}:
              {==}
            case S.Aim{seat, options}:
              %targets_backwards(seats) : {A.play_request_with_moves(A.world_for(world, seats), seat, _) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.canonical_phase(phase, seats), notes)) : D.Request}
              {==}
            case S.Ended{}:
              {==}
            case S.Blocked{}:
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
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
          match phase:
            case S.NeedFirst{}:
              {==}
            case S.NeedHealth{}:
              {==}
            case S.NeedAmount{}:
              {==}
            case S.NeedBatch{}:
              batch_requests(A.world_for(world, seats), seats, three, notes)
            case S.NeedSwap{load, shells, 0n}:
              {==}
            case S.NeedSwap{load, shells, 1n+extra}:
              Equal.cong(Nat, D.Request, width => D.Draw{D.ShuffleSwap{}, D.Range{0n, width}}, extra, A.subtract_zero(extra), subtract_zero_backwards(extra))
            case S.Idle{seat, options}:
              {==}
            case S.Aim{seat, options}:
              %targets_backwards(seats) : {A.play_request_with_moves(A.world_for(world, seats), seat, _) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.canonical_phase(phase, seats), notes)) : D.Request}
              {==}
            case S.Ended{}:
              {==}
            case S.Blocked{}:
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
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          match phase:
            case S.NeedFirst{}:
              {==}
            case S.NeedHealth{}:
              {==}
            case S.NeedAmount{}:
              {==}
            case S.NeedBatch{}:
              batch_requests(A.world_for(world, seats), seats, four, notes)
            case S.NeedSwap{load, shells, 0n}:
              {==}
            case S.NeedSwap{load, shells, 1n+extra}:
              Equal.cong(Nat, D.Request, width => D.Draw{D.ShuffleSwap{}, D.Range{0n, width}}, extra, A.subtract_zero(extra), subtract_zero_backwards(extra))
            case S.Idle{seat, options}:
              {==}
            case S.Aim{seat, options}:
              %targets_backwards(seats) : {A.play_request_with_moves(A.world_for(world, seats), seat, _) == A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.canonical_phase(phase, seats), notes)) : D.Request}
              {==}
            case S.Ended{}:
              {==}
            case S.Blocked{}:
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


def law.legal_exact(+world: A.World(), +seats: A.Seats(), +phase: A.Phase(), +notes: A.Notes()) -> {A.machine_request(A.canonical_state(world, seats, phase, notes)) == A.ref_request(A.ref(A.canonical_state(world, seats, phase, notes))) : D.Request}:
  Equal.trans(D.Request, A.machine_request(A.canonical_state(world, seats, phase, notes)), A.ref_request(A.raw_state(A.world_for(world, seats), seats, A.canonical_phase(phase, seats), notes)), A.ref_request(A.ref(A.canonical_state(world, seats, phase, notes))), legal_canonical_raw(world, seats, phase, notes), ref_request_backwards(A.world_for(world, seats), seats, A.canonical_phase(phase, seats), notes))


def bool_truth(value: Bool) -> Data:
  match value:
    case False{}:
      Unit
    case True{}:
      Empty

def false_true_absurd(false_true: {False{} == True{} : Bool}) -> Empty:
  %false_true : bool_truth(_)
  Unit{}

def and_left(+a: Bool, b: Bool, both: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}:
      both
    case True{}:
      {==}

def and_right(+a: Bool, +b: Bool, both: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}:
      Empty.absurd({b == True{} : Bool}, false_true_absurd(both))
    case True{}:
      both

def single_shape(+mode: D.Mode, +choice: D.Choice, n: Nat, all: {A.choices_shape(mode, [choice]) == True{} : Bool}) -> {A.maybe_shape(mode, D.choices.nth([choice], n)) == True{} : Bool}:
  match choice:
    case D.Choice{seat, index, move}:
      match n:
        case 0n:
          and_left(A.core_move(mode, move), True{}, all)
        case 1n+k:
          and_left(A.core_move(mode, move), True{}, all)

def chosen_shape(+mode: D.Mode, +choices: List<&2, D.Choice>, +n: Nat, all: {A.choices_shape(mode, choices) == True{} : Bool}) -> {A.maybe_shape(mode, D.choices.nth(choices, n)) == True{} : Bool}:
  match choices n:
    case Nil{} _:
      {==}
    case D.Choice{seat, index, move} <> Nil{} n:
      single_shape(mode, D.Choice{seat, index, move}, n, all)
    case D.Choice{seat, index, move} <> other <> rest 0n:
      and_left(A.core_move(mode, move), A.choices_shape(mode, other <> rest), all)
    case D.Choice{seat, index, move} <> other <> +rest 1n+k:
      chosen_shape(mode, other <> rest, k, and_right(A.core_move(mode, move), A.choices_shape(mode, other <> rest), all))


def target_choices_shape(options: List<&2, S.TargetOption>, +seat: D.Seat, index: Nat) -> {A.choices_shape(D.Aiming{}, A.target_choices(options, seat, index)) == True{} : Bool}:
  match options:
    case Nil{}:
      {==}
    case S.Target{target} <> rest:
      target_choices_shape(rest, seat, 1n+index)

def choices_of_play(aiming: Bool, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat) -> {A.choices_shape(A.play_mode(aiming), D.choices.of(A.play_moves(aiming, seats), seat, 0n)) == True{} : Bool}:
  match aiming:
    case False{}:
      {==}
    case True{}:
      target_choices_shape(A.target_options(seats), seat, 0n)



def menu_shapes(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +aiming: Bool, present: A.seated(world, seat)) -> {A.choices_shape(A.play_mode(aiming), A.menu_choices(world, seat, A.play_moves(aiming, seats))) == True{} : Bool}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      Equal.trans(Bool, A.choices_shape(A.play_mode(aiming), A.menu_choices(world, seat, A.play_moves(aiming, seats))), A.choices_shape(A.play_mode(aiming), D.choices.of(A.play_moves(aiming, seats), seat, 0n)), True{}, Equal.cong(List<&2, D.Choice>, Bool, choices => A.choices_shape(A.play_mode(aiming), choices), A.menu_choices(world, seat, A.play_moves(aiming, seats)), D.choices.of(A.play_moves(aiming, seats), seat, 0n), P.one_menu_choices(table, seat, A.play_moves(aiming, seats), present)), choices_of_play(aiming, seats, seat))

def maybe_resolved_shape(+mode: D.Mode, picked: Maybe<&2, D.Choice>) -> {A.resolved_choice_shape(mode, picked) == A.maybe_shape(mode, picked) : Bool}:
  match picked:
    case None{}:
      {==}
    case Some{D.Choice{seat, index, move}}:
      {==}

def smart_shape(+mode: D.Mode, +menus: D.Ring<&2, List<&2, D.Move>>, +n: Nat, any: Bool, all: {A.choices_shape(mode, D.choices.flatten(D.ring.entries(List<&2, D.Move>, menus))) == True{} : Bool}) -> {A.smart_request_shape(mode, menus, n, any) == True{} : Bool}:
  match any:
    case False{}:
      {==}
    case True{}:
      Equal.trans(Bool, A.resolved_choice_shape(mode, D.choose(menus, n)), A.maybe_shape(mode, D.choose(menus, n)), True{}, maybe_resolved_shape(mode, D.choose(menus, n)), chosen_shape(mode, D.choices.flatten(D.ring.entries(List<&2, D.Move>, menus)), n, all))

def play_selection_shape(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +aiming: Bool, +notes: List<&2, D.Note>, +n: Nat, present: A.seated(world, seat)) -> {A.resolved_shape(A.play_mode(aiming), D.resolve(A.machine_request(A.play_state(world, seats, seat, aiming, notes)), n)) == True{} : Bool}:
  match aiming:
    case False{}:
      smart_shape(D.Idle{}, A.play_menus(world, seat, [D.PickUp{}]), n, D.menus.any(D.ring.entries(List<&2, D.Move>, A.play_menus(world, seat, [D.PickUp{}]))), menu_shapes(world, seats, seat, False{}, present))
    case True{}:
      smart_shape(D.Aiming{}, A.play_menus(world, seat, A.machine_shots(seats)), n, D.menus.any(D.ring.entries(List<&2, D.Move>, A.play_menus(world, seat, A.machine_shots(seats)))), menu_shapes(world, seats, seat, True{}, present))


def packet_shape_selected(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +aiming: Bool, +notes: List<&2, D.Note>, +n: Nat, +choice: D.Choice, present: A.seated(world, seat), selected: {D.resolve(A.machine_request(A.play_state(world, seats, seat, aiming, notes)), n) == D.Chose{choice} : D.Resolved}) -> {A.resolved_pick_shape(aiming, choice) == True{} : Bool}:
  Equal.trans(Bool, A.resolved_pick_shape(aiming, choice), A.resolved_shape(A.play_mode(aiming), D.resolve(A.machine_request(A.play_state(world, seats, seat, aiming, notes)), n)), True{}, Equal.sym(Bool, A.resolved_shape(A.play_mode(aiming), D.resolve(A.machine_request(A.play_state(world, seats, seat, aiming, notes)), n)), A.resolved_pick_shape(aiming, choice), Equal.cong(D.Resolved, Bool, resolved => A.resolved_shape(A.play_mode(aiming), resolved), D.resolve(A.machine_request(A.play_state(world, seats, seat, aiming, notes)), n), D.Chose{choice}, selected)), play_selection_shape(world, seats, seat, aiming, notes, n, present))

def and_true(+a: Bool, +b: Bool, left: {a == True{} : Bool}, right: {b == True{} : Bool}) -> {Bool.and(a, b) == True{} : Bool}:
  Equal.trans(Bool, Bool.and(a, b), Bool.and(True{}, b), True{}, Equal.cong(Bool, Bool, value => Bool.and(value, b), a, True{}, left), right)

def accept_play_packet(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +aiming: Bool, +notes: List<&2, D.Note>, +choice: D.Choice, shape: {A.resolved_pick_shape(aiming, choice) == True{} : Bool}, current: {A.current_matches(A.ref(A.play_state(world, seats, seat, aiming, notes)), A.choice_seat(choice)) == True{} : Bool}, permission: {A.has_turn(A.ref(A.play_state(world, seats, seat, aiming, notes)), A.choice_seat(choice)) == True{} : Bool}) -> {A.verify(A.ref(A.play_state(world, seats, seat, aiming, notes)), choice) == True{} : Bool}:
  match aiming choice:
    case False{} D.Choice{+chosen, index, D.PickUp{}}:
      +state : A.Ref() = A.ref(A.play_state(world, seats, seat, False{}, notes))
      and_true(A.current_matches(state, chosen), Bool.and(A.has_turn(state, chosen), True{}), current, and_true(A.has_turn(state, chosen), True{}, permission, {==}))
    case False{} D.Choice{chosen, index, D.Shoot{target}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, False{}, notes)), D.Choice{chosen, index, D.Shoot{target}}) == True{} : Bool}, false_true_absurd(shape))
    case False{} D.Choice{chosen, index, D.UseItem{slot, item}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, False{}, notes)), D.Choice{chosen, index, D.UseItem{slot, item}}) == True{} : Bool}, false_true_absurd(shape))
    case False{} D.Choice{chosen, index, D.Grab{}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, False{}, notes)), D.Choice{chosen, index, D.Grab{}}) == True{} : Bool}, false_true_absurd(shape))
    case False{} D.Choice{chosen, index, D.Place{slot}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, False{}, notes)), D.Choice{chosen, index, D.Place{slot}}) == True{} : Bool}, false_true_absurd(shape))
    case False{} D.Choice{chosen, index, D.JamTarget{target}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, False{}, notes)), D.Choice{chosen, index, D.JamTarget{target}}) == True{} : Bool}, false_true_absurd(shape))
    case False{} D.Choice{chosen, index, D.Steal{owner, slot, item}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, False{}, notes)), D.Choice{chosen, index, D.Steal{owner, slot, item}}) == True{} : Bool}, false_true_absurd(shape))
    case True{} D.Choice{+chosen, index, D.Shoot{+target}}:
      +state : A.Ref() = A.ref(A.play_state(world, seats, seat, True{}, notes))
      and_true(A.current_matches(state, chosen), Bool.and(A.has_turn(state, chosen), True{}), current, and_true(A.has_turn(state, chosen), True{}, permission, {==}))
    case True{} D.Choice{chosen, index, D.PickUp{}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, True{}, notes)), D.Choice{chosen, index, D.PickUp{}}) == True{} : Bool}, false_true_absurd(shape))
    case True{} D.Choice{chosen, index, D.UseItem{slot, item}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, True{}, notes)), D.Choice{chosen, index, D.UseItem{slot, item}}) == True{} : Bool}, false_true_absurd(shape))
    case True{} D.Choice{chosen, index, D.Grab{}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, True{}, notes)), D.Choice{chosen, index, D.Grab{}}) == True{} : Bool}, false_true_absurd(shape))
    case True{} D.Choice{chosen, index, D.Place{slot}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, True{}, notes)), D.Choice{chosen, index, D.Place{slot}}) == True{} : Bool}, false_true_absurd(shape))
    case True{} D.Choice{chosen, index, D.JamTarget{target}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, True{}, notes)), D.Choice{chosen, index, D.JamTarget{target}}) == True{} : Bool}, false_true_absurd(shape))
    case True{} D.Choice{chosen, index, D.Steal{owner, slot, item}}:
      Empty.absurd({A.verify(A.ref(A.play_state(world, seats, seat, True{}, notes)), D.Choice{chosen, index, D.Steal{owner, slot, item}}) == True{} : Bool}, false_true_absurd(shape))

def law.legal_accepted(+world: A.World(), +seats: A.Seats(), +seat: A.Seat(), +aiming: Bool, +notes: A.Notes(), +n: Nat, +choice: D.Choice, present: A.seated(A.world_for(world, seats), seat), selected: {D.resolve(A.machine_request(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)), n) == D.Chose{choice} : D.Resolved}, current: {A.current_matches(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)), A.choice_seat(choice)) == True{} : Bool}, permission: {A.has_turn(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)), A.choice_seat(choice)) == True{} : Bool}) -> {A.verify(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)), choice) == True{} : Bool}:
  accept_play_packet(A.world_for(world, seats), seats, seat, aiming, notes, choice, packet_shape_selected(A.world_for(world, seats), seats, seat, aiming, notes, n, choice, present, selected), current, permission)

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

def inv.seats_roundtrip(+seats: A.Seats()) -> {A.players(A.seats_roundtrip(seats)) == A.players.free(seats) : S.Players}:
  match seats:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      {==}

def inv.world_roundtrip(+world: S.World, seats: A.Seats()) -> {A.world_roundtrip(world, seats) == world : S.World}:
  match world:
    case S.World{+config, +before, +round, +index, +first, +hp, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      Equal.cong(S.Decks, S.World, ds => S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, ds}, A.decks_roundtrip(deck), deck, inv.decks_roundtrip(deck))

def inv.targets_entries(+entries: List<&2, D.At<&2, A.CoreSeat>>) -> {A.ref_targets_entries(entries) == A.machine_targets_entries(entries) : List<&2, S.TargetOption>}:
  match entries:
    case Nil{}:
      {==}
    case D.At{seat, A.CoreSeat{0n, jam, checked, cash, sl, turn}} <> +rest:
      inv.targets_entries(rest)
    case D.At{+seat, A.CoreSeat{1n+hp, jam, checked, cash, sl, turn}} <> +rest:
      Equal.cong(List<&2, S.TargetOption>, List<&2, S.TargetOption>, xs => S.Target{seat} <> xs, A.ref_targets_entries(rest), A.machine_targets_entries(rest), inv.targets_entries(rest))

def inv.targets_render(+seats: A.Seats()) -> {A.ref_targets(seats) == A.machine_targets(seats) : List<&2, S.TargetOption>}:
  match seats:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      inv.targets_entries(D.ring.entries(A.CoreSeat, seats))
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
      inv.targets_entries(D.ring.entries(A.CoreSeat, seats))
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      inv.targets_entries(D.ring.entries(A.CoreSeat, seats))

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
      Equal.cong(List<&2, S.TargetOption>, S.Phase, xs => S.Aim{seat, xs}, A.ref_targets(seats), A.machine_targets(seats), inv.targets_render(seats))

def inv.idle_phase(+world: S.World, +seats: A.Seats(), +seat: D.Seat) -> {A.idle_options_roundtrip(world, seats, seat) == Nil{} : List<&2, S.IdleOption>}:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
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

def inv.world_backwards(+world: S.World, +seats: A.Seats()) -> {world == A.world_roundtrip(world, seats) : S.World}:
  %inv.world_roundtrip(world, seats) : {_ == A.world_roundtrip(world, seats) : S.World}
  {==}

def inv.seats_backwards(+seats: A.Seats()) -> {A.players.free(seats) == A.players(A.seats_roundtrip(seats)) : S.Players}:
  %inv.seats_roundtrip(seats) : {_ == A.players(A.seats_roundtrip(seats)) : S.Players}
  {==}

def inv.grabs_roundtrip(+world: S.World, +seats: A.Seats()) -> {A.grabs_roundtrip(world, seats) == A.grabs(seats) : S.Grabs}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          {==}

def inv.grabs_backwards(+world: S.World, +seats: A.Seats()) -> {A.grabs(seats) == A.grabs_roundtrip(world, seats) : S.Grabs}:
  %inv.grabs_roundtrip(world, seats) : {_ == A.grabs_roundtrip(world, seats) : S.Grabs}
  {==}

def inv.phase_backwards(+world: S.World, +seats: A.Seats(), +phase: A.RequestPhase) -> {A.request_phase(phase, seats) == A.phase_roundtrip(world, seats, phase) : S.Phase}:
  %inv.phase_roundtrip(world, seats, phase) : {_ == A.phase_roundtrip(world, seats, phase) : S.Phase}
  {==}

def inv.restored_parts(+world: S.World, +seats: A.Seats(), +phase: A.RequestPhase, +notes: A.Notes()) -> {A.restored_parts(world, seats, phase, notes) == A.canonical(world, seats, phase, notes) : S.State}:
  %inv.world_backwards(world, seats) : {S.State{_, A.players(A.seats_roundtrip(seats)), A.phase_roundtrip(world, seats, phase), notes, A.grabs_roundtrip(world, seats)} == A.canonical(world, seats, phase, notes) : S.State}
  %inv.seats_backwards(seats) : {S.State{world, _, A.phase_roundtrip(world, seats, phase), notes, A.grabs_roundtrip(world, seats)} == A.canonical(world, seats, phase, notes) : S.State}
  %inv.grabs_backwards(world, seats) : {S.State{world, A.players.free(seats), A.phase_roundtrip(world, seats, phase), notes, _} == A.canonical(world, seats, phase, notes) : S.State}
  %inv.phase_backwards(world, seats, phase) : {S.State{world, A.players.free(seats), _, notes, A.grabs(seats)} == A.canonical(world, seats, phase, notes) : S.State}
  {==}

def inv.core_roundtrip(+seats: D.Ring<&2, A.CoreSeat>) -> {A.core(A.players(seats)) == seats : D.Ring<&2, A.CoreSeat>}:
  match seats:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
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
    case D.At{+seat, A.CoreSeat{hp, _, _, _, sl, _}} <> +rest:
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

def law.turn_traversal(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +current: D.Seat) -> {Q.next_turn(A.seats.health(seats), S.world.direction(world), current) == A.ref_turn(world, seats, current) : D.Seat}:
  turn_raw(world, seats, current)

def supported_backwards(+value: Bool, proof: {value == True{} : Bool}) -> {True{} == value : Bool}:
  %proof : {_ == value : Bool}
  {==}

def law.start_result_matches(+config: D.Config, supported: {Q.config.no_items(config) == True{} : Bool}) -> {A.ref_start(config) == A.stepped(M.start(config)) : A.RefStep()}:
  match config:
    case D.Config{D.TwoSeats{}, plan}:
      {==}
    case D.Config{D.ThreeSeats{}, plan}:
      {==}
    case D.Config{D.FourSeats{}, plan}:
      {==}

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

def point.canonical(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes()) -> {A.machine_point(A.canonical_state(world, seats, phase, notes)) == A.point_of_ref(A.canonical_state(world, seats, phase, notes)) : D.Point}:
  +state : S.State = A.canonical_state(world, seats, phase, notes)
  requests : {A.machine_request(state) == A.ref_request(A.ref(state)) : D.Request} = law.legal_exact(world, seats, phase, notes)
  boards : {PView.board(state) == A.ref_board(A.ref(state)) : D.Board} = Equal.cong(D.Obs & List<&2, D.Heard>, D.Board, A.observation_board, (A.observation(state, D.Seat0{}), A.heard(state, D.Seat0{})), (A.ref_observation(A.ref(state), D.Seat0{}), A.ref_heard(A.ref(state), D.Seat0{})), law.observe_matches(world, seats, A.canonical_phase(phase, seats), notes, D.Seat0{}))
  Equal.trans(D.Point, A.machine_point(state), D.Point{A.ref_request(A.ref(state)), PView.board(state)}, A.point_of_ref(state), Equal.cong(D.Request, D.Point, request => D.Point{request, PView.board(state)}, A.machine_request(state), A.ref_request(A.ref(state)), requests), Equal.cong(D.Board, D.Point, board => D.Point{A.ref_request(A.ref(state)), board}, PView.board(state), A.ref_board(A.ref(state)), boards))

def point.valid(+state: S.State, +valid: A.Valid(state)) -> {A.machine_point(state) == A.point_of_ref(state) : D.Point}:
  match state:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match valid:
        case (+shape, rest):
          Equal.trans(D.Point, A.machine_point(state), A.machine_point(A.normalize(state)), A.point_of_ref(state), Equal.cong(S.State, D.Point, A.machine_point, state, A.normalize(state), Equal.sym(S.State, A.normalize(state), state, shape)), Equal.trans(D.Point, A.machine_point(A.normalize(state)), A.point_of_ref(A.normalize(state)), A.point_of_ref(state), point.canonical(world, A.core(players), phase, notes), Equal.cong(S.State, D.Point, A.point_of_ref, A.normalize(state), state, shape)))

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
        case S.Aim{seat, targets}:
          {==}
        case S.Ended{}:
          {==}
        case S.Blocked{}:
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

def normalized_request(+state: S.State) -> {A.machine_request(A.normalize(state)) == A.ref_request(A.ref(A.normalize(state))) : D.Request}:
  match state:
    case S.State{world, players, phase, notes, grabs}:
      law.legal_exact(world, A.core(players), phase, notes)

def valid_request(+state: S.State, valid: A.Valid(state)) -> {A.machine_request(state) == A.ref_request(A.ref(state)) : D.Request}:
  %A.valid.norm(state, valid) : {A.machine_request(_) == A.ref_request(A.ref(_)) : D.Request}
  normalized_request(state)

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

def run_successor(+fuel: Nat, +state: S.State, +n: Nat, +tape: List<&2, Nat>, +simulation: A.Simulation(state, n), recur: A.RunHypothesis(fuel)) -> {A.ref_merge(A.ref_answer(A.ref(state), n), A.ref_run(fuel, A.ref_next(A.ref_answer(A.ref(state), n)), tape)) == A.ran(A.machine_merge(M.answer(state, n), M.run(fuel, M.stepped.state(M.answer(state, n)), tape))) : A.RefRan()}:
  Equal.trans(A.RefRan(), A.ref_merge(A.ref_answer(A.ref(state), n), A.ref_run(fuel, A.ref_next(A.ref_answer(A.ref(state), n)), tape)), A.ref_merge(A.stepped(M.answer(state, n)), A.ref_run(fuel, A.ref_next(A.stepped(M.answer(state, n))), tape)), A.ran(A.machine_merge(M.answer(state, n), M.run(fuel, M.stepped.state(M.answer(state, n)), tape))), Equal.cong(A.RefStep(), A.RefRan(), next => A.ref_merge(next, A.ref_run(fuel, A.ref_next(next), tape)), A.ref_answer(A.ref(state), n), A.stepped(M.answer(state, n)), A.simulation.step(state, n, simulation)), merge_lift(M.answer(state, n), fuel, tape, next_run_transport(M.answer(state, n), fuel, tape, recur(A.next(state, n), tape, A.simulation.next(state, n, simulation)))))

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

def run_glue(+fuel: Nat, +state: S.State, +tape: List<&2, Nat>, +valid: A.Valid(state), lifted: {A.ref_driver(fuel, A.machine_request(state), A.ref(state), tape) == A.ran(M.run(fuel, state, tape)) : A.RefRan()}) -> {A.ref_run(fuel, A.ref(state), tape) == A.ran(M.run(fuel, state, tape)) : A.RefRan()}:
  Equal.trans(A.RefRan(), A.ref_run(fuel, A.ref(state), tape), A.ref_driver(fuel, A.machine_request(state), A.ref(state), tape), A.ran(M.run(fuel, state, tape)), Equal.trans(A.RefRan(), A.ref_run(fuel, A.ref(state), tape), A.ref_driver(fuel, A.ref_request(A.ref(state)), A.ref(state), tape), A.ref_driver(fuel, A.machine_request(state), A.ref(state), tape), ref_run_driver(fuel, state, tape), Equal.cong(D.Request, A.RefRan(), request => A.ref_driver(fuel, request, A.ref(state), tape), A.ref_request(A.ref(state)), A.machine_request(state), Equal.sym(D.Request, A.machine_request(state), A.ref_request(A.ref(state)), valid_request(state, valid)))), lifted)

def normalized_pack(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes()) -> {A.normalize(A.pack(world, seats, phase, notes)) == A.canonical_state(world, seats, phase, notes) : S.State}:
  match seats:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      {==}

def canonical_pack(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), world_eq: {A.world_for(world, seats) == world : S.World}, phase_eq: {A.canonical_phase(phase, seats) == phase : S.Phase}) -> {A.canonical_state(world, seats, phase, notes) == A.pack(world, seats, phase, notes) : S.State}:
  Equal.trans(S.State, A.canonical_state(world, seats, phase, notes), A.pack(world, seats, A.canonical_phase(phase, seats), notes), A.pack(world, seats, phase, notes), Equal.cong(S.World, S.State, w => A.pack(w, seats, A.canonical_phase(phase, seats), notes), A.world_for(world, seats), world, world_eq), Equal.cong(S.Phase, S.State, p => A.pack(world, seats, p, notes), A.canonical_phase(phase, seats), phase, phase_eq))

def pack_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats), phase_eq: {A.canonical_phase(phase, seats) == phase : S.Phase}, ready: {A.round_ready(phase, world) == True{} : Bool}) -> A.Valid(A.pack(world, seats, phase, notes)):
  match stable:
    case Tuple{world_eq, Tuple{supported, bounded}}:
      (Equal.trans(S.State, A.normalize(A.pack(world, seats, phase, notes)), A.canonical_state(world, seats, phase, notes), A.pack(world, seats, phase, notes), normalized_pack(world, seats, phase, notes), canonical_pack(world, seats, phase, notes, world_eq, phase_eq)), (supported, (bounded, ready)))

def stable_shape(+world: S.World, +before: A.Seats(), +after: A.Seats(), shape: {D.ring.table(A.CoreSeat, after) == D.ring.table(A.CoreSeat, before) : D.Table}, stable: A.Stable(world, before)) -> A.Stable(world, after):
  match stable:
    case Tuple{world_eq, Tuple{supported, bounded}}:
      (Equal.trans(S.World, A.world_for(world, after), A.world_for(world, before), world, Equal.cong(D.Table, S.World, table => S.world.set_config(world, D.Config{table, S.world.plan(world)}), D.ring.table(A.CoreSeat, after), D.ring.table(A.CoreSeat, before), shape), world_eq), (supported, bounded))

def stable_turn(+world: S.World, +seats: A.Seats(), +seat: D.Seat, stable: A.Stable(world, seats)) -> A.Stable(S.world.set_turn(world, Some{seat}), seats):
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match stable:
        case Tuple{world_eq, Tuple{supported, bounded}}:
          (Equal.cong(S.World, S.World, w => S.world.set_turn(w, Some{seat}), A.world_for(world, seats), world, world_eq), (supported, bounded))

def give_pack(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes()) -> {M.give_turn(A.pack(world, seats, phase, notes), seat) == A.pack(world, A.preserve.turn(seats, seat), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, List.append(&2, D.Note, notes, [D.Shown{D.TurnGiven{seat}}])) : S.State}:
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

def turn_shape(+seats: A.Seats(), +seat: D.Seat) -> {D.ring.table(A.CoreSeat, A.preserve.turn(seats, seat)) == D.ring.table(A.CoreSeat, seats) : D.Table}:
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

def give_valid(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats)) -> A.Valid(M.give_turn(A.pack(world, seats, phase, notes), seat)):
  %Equal.sym(S.State, M.give_turn(A.pack(world, seats, phase, notes), seat), A.pack(world, A.preserve.turn(seats, seat), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, List.append(&2, D.Note, notes, [D.Shown{D.TurnGiven{seat}}])), give_pack(world, seats, seat, phase, notes)) : A.Valid(_)
  pack_valid(world, A.preserve.turn(seats, seat), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, List.append(&2, D.Note, notes, [D.Shown{D.TurnGiven{seat}}]), stable_shape(world, seats, A.preserve.turn(seats, seat), turn_shape(seats, seat), stable), {==}, {==})

def grant_zero_valid(+result: A.GrantCase, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +seat: D.Seat, stable: A.Stable(world, seats), +shape: A.grant.shape_claim(result, D.ring.table(A.CoreSeat, seats))) -> A.Valid(A.grant.machine_case(0n, world, seats, phase, notes, seat, result)):
  match result:
    case A.GrantAct{+after}:
      %shape : A.Valid(M.give_turn(S.State{S.world.set_turn(world, Some{seat}), A.players.free(after), phase, notes, A.grabs.empty(_)}, seat))
      give_valid(S.world.set_turn(world, Some{seat}), after, seat, phase, notes, stable_shape(S.world.set_turn(world, Some{seat}), seats, after, shape, stable_turn(world, seats, seat, stable)))
    case A.GrantLift{+after}:
      %shape : A.Valid(M.give_turn(S.State{S.world.set_turn(world, Some{seat}), A.players.free(after), phase, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]), A.grabs.empty(_)}, seat))
      give_valid(S.world.set_turn(world, Some{seat}), after, seat, phase, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]), stable_shape(S.world.set_turn(world, Some{seat}), seats, after, shape, stable_turn(world, seats, seat, stable)))
    case A.GrantSkip{+after}:
      %shape : A.Valid(S.State{S.world.set_turn(world, Some{seat}), A.players.free(after), S.Blocked{}, notes, A.grabs.empty(_)})
      pack_valid(S.world.set_turn(world, Some{seat}), after, S.Blocked{}, notes, stable_shape(S.world.set_turn(world, Some{seat}), seats, after, shape, stable_turn(world, seats, seat, stable)), {==}, {==})

def grant_succ_valid(+result: A.GrantCase, +rank: Nat, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +seat: D.Seat, recur: A.preserve.GrantHypothesis(rank), stable: A.Stable(world, seats), +shape: A.grant.shape_claim(result, D.ring.table(A.CoreSeat, seats))) -> A.Valid(A.grant.machine_case(1n+rank, world, seats, phase, notes, seat, result)):
  match result:
    case A.GrantAct{+after}:
      %shape : A.Valid(M.give_turn(S.State{S.world.set_turn(world, Some{seat}), A.players.free(after), phase, notes, A.grabs.empty(_)}, seat))
      give_valid(S.world.set_turn(world, Some{seat}), after, seat, phase, notes, stable_shape(S.world.set_turn(world, Some{seat}), seats, after, shape, stable_turn(world, seats, seat, stable)))
    case A.GrantLift{+after}:
      %shape : A.Valid(M.give_turn(S.State{S.world.set_turn(world, Some{seat}), A.players.free(after), phase, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]), A.grabs.empty(_)}, seat))
      give_valid(S.world.set_turn(world, Some{seat}), after, seat, phase, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]), stable_shape(S.world.set_turn(world, Some{seat}), seats, after, shape, stable_turn(world, seats, seat, stable)))
    case A.GrantSkip{+after}:
      +turned : S.World = S.world.set_turn(world, Some{seat})
      %shape : A.Valid(M.grant.bound(rank, S.State{turned, A.players.free(after), phase, List.append(&2, D.Note, notes, [D.Shown{D.TurnSkipped{seat}}]), A.grabs.empty(_)}, Q.next_turn(A.seats.health(after), S.world.direction(turned), seat)))
      recur(turned, after, phase, List.append(&2, D.Note, notes, [D.Shown{D.TurnSkipped{seat}}]), Q.next_turn(A.seats.health(after), S.world.direction(turned), seat), stable_shape(turned, seats, after, shape, stable_turn(world, seats, seat, stable)))

def grant_valid_glue(+rank: Nat, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +seat: D.Seat, proof: A.Valid(A.grant.machine_case(rank, world, seats, phase, notes, seat, A.grant.jam(seats, seat)))) -> A.Valid(M.grant.bound(rank, A.pack(world, seats, phase, notes), seat)):
  %GrantProof.machine_state_case(rank, world, seats, phase, notes, seat) : A.Valid(_)
  proof

def grant_valid(+rank: Nat) -> A.preserve.GrantHypothesis(rank):
  match rank:
    case 0n:
      +world => +seats => +phase => +notes => +seat => +stable => grant_valid_glue(0n, world, seats, phase, notes, seat, grant_zero_valid(A.grant.jam(seats, seat), world, seats, phase, notes, seat, stable, GrantProof.jam_shape(seats, seat)))
    case 1n+rest:
      +world => +seats => +phase => +notes => +seat => +stable => grant_valid_glue(1n+rest, world, seats, phase, notes, seat, grant_succ_valid(A.grant.jam(seats, seat), rest, world, seats, phase, notes, seat, grant_valid(rest), stable, GrantProof.jam_shape(seats, seat)))

def grant_bound_preserves(+rank: Nat, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +seat: D.Seat, synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}, supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}) -> A.Valid(M.grant.bound(rank, A.pack(world, seats, phase, notes), seat)):
  grant_valid(rank, world, seats, phase, notes, seat, (GrantProof.world_for_identity(world, seats, synced), (supported, bounded)))

def grant_preserves(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +seat: D.Seat, synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}, supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}) -> A.Valid(M.grant(A.pack(world, seats, phase, notes), seat)):
  grant_bound_preserves(Q.jam_rank(A.players.free(seats)), world, seats, phase, notes, seat, synced, supported, bounded)

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


def loadproof.disabled_selected(+items: D.ItemRules, +item: D.Item, disabled: {A.items_disabled(items) == True{} : Bool}) -> {A.item_disabled(items, item) == True{} : Bool}:
  match items:
    case D.ItemRules{+a, +b, +c, +d, +e, +f, +g, +h, +i}:
      match item:
        case D.Saw{}:
          and_left(A.disabled_rule(a), Bool.and(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))))), disabled)
        case D.Glass{}:
          and_left(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))))), and_right(A.disabled_rule(a), Bool.and(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))))), disabled))
        case D.Jammer{}:
          and_left(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))), and_right(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))))), and_right(A.disabled_rule(a), Bool.and(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))))), disabled)))
        case D.Cigarettes{}:
          and_left(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))), and_right(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))), and_right(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))))), and_right(A.disabled_rule(a), Bool.and(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))))), disabled))))
        case D.Beer{}:
          and_left(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))), and_right(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))), and_right(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))), and_right(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))))), and_right(A.disabled_rule(a), Bool.and(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))))), disabled)))))
        case D.Phone{}:
          and_left(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))), and_right(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))), and_right(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))), and_right(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))), and_right(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))))), and_right(A.disabled_rule(a), Bool.and(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))))), disabled))))))
        case D.Inverter{}:
          and_left(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)), and_right(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))), and_right(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))), and_right(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))), and_right(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))), and_right(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))))), and_right(A.disabled_rule(a), Bool.and(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))))), disabled)))))))
        case D.Adrenaline{}:
          and_left(A.disabled_rule(h), A.disabled_rule(i), and_right(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)), and_right(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))), and_right(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))), and_right(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))), and_right(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))), and_right(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))))), and_right(A.disabled_rule(a), Bool.and(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))))), disabled))))))))
        case D.Remote{}:
          and_right(A.disabled_rule(h), A.disabled_rule(i), and_right(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)), and_right(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))), and_right(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))), and_right(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))), and_right(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))), and_right(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i))))))), and_right(A.disabled_rule(a), Bool.and(A.disabled_rule(b), Bool.and(A.disabled_rule(c), Bool.and(A.disabled_rule(d), Bool.and(A.disabled_rule(e), Bool.and(A.disabled_rule(f), Bool.and(A.disabled_rule(g), Bool.and(A.disabled_rule(h), A.disabled_rule(i)))))))), disabled))))))))


def loadproof.disabled_ineligible(+rule: D.ItemRule, dealt: Bool, own: Nat, total: Nat, disabled: {A.disabled_rule(rule) == True{} : Bool}) -> {A.eligible_rule(rule, dealt, own, total) == False{} : Bool}:
  match rule:
    case D.ItemRule{False{}, cap, global_cap}:
      {==}
    case D.ItemRule{True{}, cap, global_cap}:
      Empty.absurd({A.eligible_rule(rule, dealt, own, total) == False{} : Bool}, false_true_absurd(disabled))


def loadproof.pool_rule_false(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +item: D.Item, disabled: {A.items_disabled(A.current_items(world, seats)) == True{} : Bool}) -> {A.pool_rule(world, seats, seat, item) == False{} : Bool}:
  loadproof.disabled_ineligible(D.rules.item(A.current_items(world, seats), item), A.pool_dealt(world, seats, item), A.pool_own(world, seats, seat, item), A.pool_total(world, seats, item), loadproof.disabled_selected(A.current_items(world, seats), item, disabled))



def loadproof.rule_off_id(+rule: D.ItemRule, disabled: {A.disabled_rule(rule) == True{} : Bool}) -> {rule == A.rule_off(rule) : D.ItemRule}:
  match rule:
    case D.ItemRule{False{}, cap, total}:
      {==}
    case D.ItemRule{True{}, cap, total}:
      Empty.absurd({rule == A.rule_off(rule) : D.ItemRule}, false_true_absurd(disabled))

def loadproof.items_off_id(+items: D.ItemRules, disabled: {A.items_disabled(items) == True{} : Bool}) -> {items == A.items_off(items) : D.ItemRules}:
  match items:
    case D.ItemRules{+a, +b, +c, +d, +e, +f, +g, +h, +i}:
      match a:
        case D.ItemRule{True{}, ca, ta}:
          Empty.absurd({items == A.items_off(items) : D.ItemRules}, false_true_absurd(disabled))
        case D.ItemRule{False{}, ca, ta}:
          match b:
            case D.ItemRule{True{}, cb, tb}:
              Empty.absurd({items == A.items_off(items) : D.ItemRules}, false_true_absurd(disabled))
            case D.ItemRule{False{}, cb, tb}:
              match c:
                case D.ItemRule{True{}, cc, tc}:
                  Empty.absurd({items == A.items_off(items) : D.ItemRules}, false_true_absurd(disabled))
                case D.ItemRule{False{}, cc, tc}:
                  match d:
                    case D.ItemRule{True{}, cd, td}:
                      Empty.absurd({items == A.items_off(items) : D.ItemRules}, false_true_absurd(disabled))
                    case D.ItemRule{False{}, cd, td}:
                      match e:
                        case D.ItemRule{True{}, ce, te}:
                          Empty.absurd({items == A.items_off(items) : D.ItemRules}, false_true_absurd(disabled))
                        case D.ItemRule{False{}, ce, te}:
                          match f:
                            case D.ItemRule{True{}, cf, tf}:
                              Empty.absurd({items == A.items_off(items) : D.ItemRules}, false_true_absurd(disabled))
                            case D.ItemRule{False{}, cf, tf}:
                              match g:
                                case D.ItemRule{True{}, cg, tg}:
                                  Empty.absurd({items == A.items_off(items) : D.ItemRules}, false_true_absurd(disabled))
                                case D.ItemRule{False{}, cg, tg}:
                                  match h:
                                    case D.ItemRule{True{}, ch, th}:
                                      Empty.absurd({items == A.items_off(items) : D.ItemRules}, false_true_absurd(disabled))
                                    case D.ItemRule{False{}, ch, th}:
                                      match i:
                                        case D.ItemRule{True{}, ci, ti}:
                                          Empty.absurd({items == A.items_off(items) : D.ItemRules}, false_true_absurd(disabled))
                                        case D.ItemRule{False{}, ci, ti}:
                                          {==}

def loadproof.pool_extracted(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +items: List<&2, D.Item>) -> {A.ref_pool(world, seats, seat, items) == A.pool_rules(world, seats, seat, items, A.current_items(world, seats)) : List<&2, D.Item>}:
  match items:
    case Nil{}:
      {==}
    case +item <> +rest:
      Equal.cong(List<&2, D.Item>, List<&2, D.Item>, tail => A.pool_put(A.pool_rule(world, seats, seat, item), item, tail), A.ref_pool(world, seats, seat, rest), A.pool_rules(world, seats, seat, rest, A.current_items(world, seats)), loadproof.pool_extracted(world, seats, seat, rest))

def loadproof.off_rule_ineligible(+items: D.ItemRules, +item: D.Item, dealt: Bool, own: Nat, total: Nat) -> {A.eligible_rule(D.rules.item(A.items_off(items), item), dealt, own, total) == False{} : Bool}:
  match items:
    case D.ItemRules{D.ItemRule{ea, ca, ta}, D.ItemRule{eb, cb, tb}, D.ItemRule{ec, cc, tc}, D.ItemRule{ed, cd, td}, D.ItemRule{ee, ce, te}, D.ItemRule{ef, cf, tf}, D.ItemRule{eg, cg, tg}, D.ItemRule{eh, ch, th}, D.ItemRule{ei, ci, ti}}:
      match item:
        case D.Saw{}:
          {==}
        case D.Glass{}:
          {==}
        case D.Jammer{}:
          {==}
        case D.Cigarettes{}:
          {==}
        case D.Beer{}:
          {==}
        case D.Phone{}:
          {==}
        case D.Inverter{}:
          {==}
        case D.Adrenaline{}:
          {==}
        case D.Remote{}:
          {==}


def loadproof.pool_off_empty(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +items: List<&2, D.Item>, +rules: D.ItemRules) -> {A.pool_rules(world, seats, seat, items, A.items_off(rules)) == Nil{} : List<&2, D.Item>}:
  match items:
    case Nil{}:
      {==}
    case +item <> +rest:
      %Equal.sym(Bool, A.eligible_rule(D.rules.item(A.items_off(rules), item), A.pool_dealt(world, seats, item), A.pool_own(world, seats, seat, item), A.pool_total(world, seats, item)), False{}, loadproof.off_rule_ineligible(rules, item, A.pool_dealt(world, seats, item), A.pool_own(world, seats, seat, item), A.pool_total(world, seats, item))) : {A.pool_put(_, item, A.pool_rules(world, seats, seat, rest, A.items_off(rules))) == Nil{} : List<&2, D.Item>}
      loadproof.pool_off_empty(world, seats, seat, rest, rules)

def loadproof.pool_empty(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +items: List<&2, D.Item>, disabled: {A.items_disabled(A.current_items(world, seats)) == True{} : Bool}) -> {A.ref_pool(world, seats, seat, items) == Nil{} : List<&2, D.Item>}:
  +rules : D.ItemRules = A.current_items(world, seats)
  extraction : {A.ref_pool(world, seats, seat, items) == A.pool_rules(world, seats, seat, items, rules) : List<&2, D.Item>} = loadproof.pool_extracted(world, seats, seat, items)
  disabled_rules : {A.pool_rules(world, seats, seat, items, rules) == A.pool_rules(world, seats, seat, items, A.items_off(rules)) : List<&2, D.Item>} = Equal.cong(D.ItemRules, List<&2, D.Item>, rules => A.pool_rules(world, seats, seat, items, rules), rules, A.items_off(rules), loadproof.items_off_id(rules, disabled))
  empty : {A.pool_rules(world, seats, seat, items, A.items_off(rules)) == Nil{} : List<&2, D.Item>} = loadproof.pool_off_empty(world, seats, seat, items, rules)
  Equal.trans(List<&2, D.Item>, A.ref_pool(world, seats, seat, items), A.pool_rules(world, seats, seat, items, rules), Nil{}, extraction, Equal.trans(List<&2, D.Item>, A.pool_rules(world, seats, seat, items, rules), A.pool_rules(world, seats, seat, items, A.items_off(rules)), Nil{}, disabled_rules, empty))


def loadproof.ref_predecessor(+i: Nat) -> {A.ref_swap_index(1n+i) == i : Nat}:
  subtract_zero(i)

def loadproof.swap_remaining_ref(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +extra: Nat, +j: Nat) -> {A.ref_swap_step(world, seats, load, shells, 2n+extra, j) == A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra) : A.RefStep()}:
  %Equal.sym(Nat, A.ref_swap_index(2n+extra), 1n+extra, loadproof.ref_predecessor(1n+extra)) : {A.ref_shuffle_step(world, seats, load, A.ref_swap(shells, 2n+extra, j), _) == A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra) : A.RefStep()}
  Equal.cong(Nat, A.RefStep(), width => A.swap_raw_result_width(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra, width), extra, A.subtract_zero(extra), subtract_zero_backwards(extra))


def loadproof.swap_machine_remaining(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +extra: Nat, notes: List<&2, D.Note>, +n: Nat) -> {A.machine_swap_state(world, seats, load, shells, 2n+extra, notes, n) == A.swap_result_state(world, seats, load, A.machine_swap(shells, 2n+extra, A.swap_value(1n+extra, n)), 1n+extra) : S.State}:
  {==}

def loadproof.swap_reference_remaining(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +extra: Nat, +notes: List<&2, D.Note>, +n: Nat) -> {A.ref_answer(A.raw_swap(world, seats, load, shells, 2n+extra, notes), n) == A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, A.swap_value(1n+extra, n)), 1n+extra) : A.RefStep()}:
  range : {A.ref_answer(A.raw_swap(world, seats, load, shells, 2n+extra, notes), n) == A.ref_swap_answer_width(world, seats, load, shells, 2n+extra, 1n+extra, notes, n) : A.RefStep()} = Equal.cong(Nat, A.RefStep(), width => A.ref_swap_answer_width(world, seats, load, shells, 2n+extra, width, notes, n), A.ref_swap_index(2n+extra), 1n+extra, loadproof.ref_predecessor(1n+extra))
  result : {A.ref_swap_answer_width(world, seats, load, shells, 2n+extra, 1n+extra, notes, n) == A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, A.swap_value(1n+extra, n)), 1n+extra) : A.RefStep()} = loadproof.swap_remaining_ref(world, seats, load, shells, extra, A.swap_value(1n+extra, n))
  Equal.trans(A.RefStep(), A.ref_answer(A.raw_swap(world, seats, load, shells, 2n+extra, notes), n), A.ref_swap_answer_width(world, seats, load, shells, 2n+extra, 1n+extra, notes, n), A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, A.swap_value(1n+extra, n)), 1n+extra), range, result)


def loadproof.swap_machine_result(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +extra: Nat, +notes: List<&2, D.Note>, +n: Nat) -> {A.swap_answer(world, seats, load, shells, 2n+extra, notes, n) == A.swap_result_state_stepped(world, seats, load, A.machine_swap(shells, 2n+extra, A.swap_value(1n+extra, n)), 1n+extra) : A.RefStep()}:
  Equal.cong(S.State, A.RefStep(), state => A.machine_ref_step(state), A.machine_swap_state(world, seats, load, shells, 2n+extra, notes, n), A.swap_result_state(world, seats, load, A.machine_swap(shells, 2n+extra, A.swap_value(1n+extra, n)), 1n+extra), loadproof.swap_machine_remaining(world, seats, load, shells, extra, notes, n))

def loadproof.swap_input_roundtrip(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +i: Nat, +notes: List<&2, D.Note>, +n: Nat) -> {A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, i, notes)), n) == A.ref_answer(A.raw_swap(world, seats, load, shells, i, notes), n) : A.RefStep()}:
  Equal.cong(A.Seats(), A.RefStep(), restored => A.ref_answer(A.raw_swap(world, restored, load, shells, i, notes), n), seats, seats, {==})

def loadproof.swap_output_roundtrip(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +i: Nat) -> {A.swap_raw_result(world, seats, load, shells, i) == A.swap_result_state_stepped(world, seats, load, shells, i) : A.RefStep()}:
  Equal.cong(A.Seats(), A.RefStep(), restored => A.swap_raw_result(world, restored, load, shells, i), seats, seats, {==})

def loadproof.swap_remaining_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +extra: Nat, +notes: List<&2, D.Note>, +n: Nat) -> {A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, 2n+extra, notes)), n) == A.swap_answer(world, seats, load, shells, 2n+extra, notes, n) : A.RefStep()}:
  +j : Nat = A.swap_value(1n+extra, n)
  first : {A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, 2n+extra, notes)), n) == A.ref_answer(A.raw_swap(world, seats, load, shells, 2n+extra, notes), n) : A.RefStep()} = loadproof.swap_input_roundtrip(world, seats, load, shells, 2n+extra, notes, n)
  second : {A.ref_answer(A.raw_swap(world, seats, load, shells, 2n+extra, notes), n) == A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra) : A.RefStep()} = loadproof.swap_reference_remaining(world, seats, load, shells, extra, notes, n)
  third : {A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra) == A.swap_raw_result(world, seats, load, A.machine_swap(shells, 2n+extra, j), 1n+extra) : A.RefStep()} = Equal.cong(List<&2, D.Shell>, A.RefStep(), shells => A.swap_raw_result(world, seats, load, shells, 1n+extra), A.ref_swap(shells, 2n+extra, j), A.machine_swap(shells, 2n+extra, j), loadproof.swap_shells(shells, 2n+extra, j))
  fourth : {A.swap_raw_result(world, seats, load, A.machine_swap(shells, 2n+extra, j), 1n+extra) == A.swap_result_state_stepped(world, seats, load, A.machine_swap(shells, 2n+extra, j), 1n+extra) : A.RefStep()} = loadproof.swap_output_roundtrip(world, seats, load, A.machine_swap(shells, 2n+extra, j), 1n+extra)
  last : {A.swap_result_state_stepped(world, seats, load, A.machine_swap(shells, 2n+extra, j), 1n+extra) == A.swap_answer(world, seats, load, shells, 2n+extra, notes, n) : A.RefStep()} = Equal.sym(A.RefStep(), A.swap_answer(world, seats, load, shells, 2n+extra, notes, n), A.swap_result_state_stepped(world, seats, load, A.machine_swap(shells, 2n+extra, j), 1n+extra), loadproof.swap_machine_result(world, seats, load, shells, extra, notes, n))
  one : {A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, 2n+extra, notes)), n) == A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra) : A.RefStep()} = Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, 2n+extra, notes)), n), A.ref_answer(A.raw_swap(world, seats, load, shells, 2n+extra, notes), n), A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra), first, second)
  two : {A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra) == A.swap_result_state_stepped(world, seats, load, A.machine_swap(shells, 2n+extra, j), 1n+extra) : A.RefStep()} = Equal.trans(A.RefStep(), A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra), A.swap_raw_result(world, seats, load, A.machine_swap(shells, 2n+extra, j), 1n+extra), A.swap_result_state_stepped(world, seats, load, A.machine_swap(shells, 2n+extra, j), 1n+extra), third, fourth)
  tail : {A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra) == A.swap_answer(world, seats, load, shells, 2n+extra, notes, n) : A.RefStep()} = Equal.trans(A.RefStep(), A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra), A.swap_result_state_stepped(world, seats, load, A.machine_swap(shells, 2n+extra, j), 1n+extra), A.swap_answer(world, seats, load, shells, 2n+extra, notes, n), two, last)
  Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, 2n+extra, notes)), n), A.swap_raw_result(world, seats, load, A.ref_swap(shells, 2n+extra, j), 1n+extra), A.swap_answer(world, seats, load, shells, 2n+extra, notes, n), one, tail)


def loadproof.swap_canonical_point(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +extra: Nat) -> {A.machine_point(A.swap_result_state(A.world_for(world, seats), seats, load, shells, 1n+extra)) == A.ref_step_point(A.swap_result_state_stepped(A.world_for(world, seats), seats, load, shells, 1n+extra)) : D.Point}:
  +phase : S.Phase = S.NeedSwap{load, shells, 1n+extra}
  +state : S.State = A.swap_result_state(A.world_for(world, seats), seats, load, shells, 1n+extra)
  request : {A.machine_request(state) == A.ref_request(A.ref(state)) : D.Request} = law.legal_exact(world, seats, phase, Nil{})
  board : {A.machine_board(state) == A.ref_board(A.ref(state)) : D.Board} = boards_match(world, seats, phase, Nil{})
  Equal.trans(D.Point, A.machine_point(state), D.Point{A.ref_request(A.ref(state)), A.machine_board(state)}, A.ref_step_point(A.swap_result_state_stepped(A.world_for(world, seats), seats, load, shells, 1n+extra)), Equal.cong(D.Request, D.Point, request => D.Point{request, A.machine_board(state)}, A.machine_request(state), A.ref_request(A.ref(state)), request), Equal.cong(D.Board, D.Point, board => D.Point{A.ref_request(A.ref(state)), board}, A.machine_board(state), A.ref_board(A.ref(state)), board))

def loadproof.swap_remaining_point_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +extra: Nat, +notes: List<&2, D.Note>, +n: Nat) -> {A.swap_point(A.world_for(world, seats), seats, load, shells, 2n+extra, notes, n) == A.ref_step_point(A.ref_answer(A.ref(A.swap_state(A.world_for(world, seats), seats, load, shells, 2n+extra, notes)), n)) : D.Point}:
  +synced : S.World = A.world_for(world, seats)
  +next : List<&2, D.Shell> = A.machine_swap(shells, 2n+extra, A.swap_value(1n+extra, n))
  actual : {A.swap_point(synced, seats, load, shells, 2n+extra, notes, n) == A.machine_point(A.swap_result_state(synced, seats, load, next, 1n+extra)) : D.Point} = Equal.cong(S.State, D.Point, state => A.machine_point(state), A.machine_swap_state(synced, seats, load, shells, 2n+extra, notes, n), A.swap_result_state(synced, seats, load, next, 1n+extra), loadproof.swap_machine_remaining(synced, seats, load, shells, extra, notes, n))
  canonical : {A.machine_point(A.swap_result_state(synced, seats, load, next, 1n+extra)) == A.ref_step_point(A.swap_result_state_stepped(synced, seats, load, next, 1n+extra)) : D.Point} = loadproof.swap_canonical_point(world, seats, load, next, extra)
  machine : {A.ref_step_point(A.swap_result_state_stepped(synced, seats, load, next, 1n+extra)) == A.ref_step_point(A.swap_answer(synced, seats, load, shells, 2n+extra, notes, n)) : D.Point} = Equal.cong(A.RefStep(), D.Point, result => A.ref_step_point(result), A.swap_result_state_stepped(synced, seats, load, next, 1n+extra), A.swap_answer(synced, seats, load, shells, 2n+extra, notes, n), Equal.sym(A.RefStep(), A.swap_answer(synced, seats, load, shells, 2n+extra, notes, n), A.swap_result_state_stepped(synced, seats, load, next, 1n+extra), loadproof.swap_machine_result(synced, seats, load, shells, extra, notes, n)))
  reference : {A.ref_step_point(A.swap_answer(synced, seats, load, shells, 2n+extra, notes, n)) == A.ref_step_point(A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 2n+extra, notes)), n)) : D.Point} = Equal.cong(A.RefStep(), D.Point, result => A.ref_step_point(result), A.swap_answer(synced, seats, load, shells, 2n+extra, notes, n), A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 2n+extra, notes)), n), Equal.sym(A.RefStep(), A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 2n+extra, notes)), n), A.swap_answer(synced, seats, load, shells, 2n+extra, notes, n), loadproof.swap_remaining_matches(synced, seats, load, shells, extra, notes, n)))
  prefix : {A.swap_point(synced, seats, load, shells, 2n+extra, notes, n) == A.ref_step_point(A.swap_result_state_stepped(synced, seats, load, next, 1n+extra)) : D.Point} = Equal.trans(D.Point, A.swap_point(synced, seats, load, shells, 2n+extra, notes, n), A.machine_point(A.swap_result_state(synced, seats, load, next, 1n+extra)), A.ref_step_point(A.swap_result_state_stepped(synced, seats, load, next, 1n+extra)), actual, canonical)
  suffix : {A.ref_step_point(A.swap_result_state_stepped(synced, seats, load, next, 1n+extra)) == A.ref_step_point(A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 2n+extra, notes)), n)) : D.Point} = Equal.trans(D.Point, A.ref_step_point(A.swap_result_state_stepped(synced, seats, load, next, 1n+extra)), A.ref_step_point(A.swap_answer(synced, seats, load, shells, 2n+extra, notes, n)), A.ref_step_point(A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 2n+extra, notes)), n)), machine, reference)
  Equal.trans(D.Point, A.swap_point(synced, seats, load, shells, 2n+extra, notes, n), A.ref_step_point(A.swap_result_state_stepped(synced, seats, load, next, 1n+extra)), A.ref_step_point(A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 2n+extra, notes)), n)), prefix, suffix)


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


def loadproof.amount_rule(+rule: D.LoadRule) -> {A.ref_amount_rule(rule) == A.machine_amount_rule(rule) : D.AmountRule}:
  match rule:
    case D.LoadRule{shells, amount}:
      {==}

def loadproof.current_amount_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>) -> {A.ref_amount_rule(A.ref_world_load(world, seats)) == A.current_amount(world) : D.AmountRule}:
  Equal.trans(D.AmountRule, A.ref_amount_rule(A.ref_world_load(world, seats)), A.ref_amount_rule(A.machine_world_load(world)), A.current_amount(world), Equal.cong(D.LoadRule, D.AmountRule, rule => A.ref_amount_rule(rule), A.ref_world_load(world, seats), A.machine_world_load(world), loadproof.world_load(world, seats)), loadproof.amount_rule(A.machine_world_load(world)))

def loadproof.health_random_amount_reference(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +value: Nat, random: {A.current_amount(A.health_world(world, value)) == D.RandomAmount{} : D.AmountRule}) -> {A.ref_health_value(world, seats, value) == A.ref_amount_await(A.health_world(world, value), seats) : A.RefStep()}:
  rules : {A.ref_amount_rule(A.ref_world_load(A.health_world(world, value), seats)) == D.RandomAmount{} : D.AmountRule} = Equal.trans(D.AmountRule, A.ref_amount_rule(A.ref_world_load(A.health_world(world, value), seats)), A.current_amount(A.health_world(world, value)), D.RandomAmount{}, loadproof.current_amount_matches(A.health_world(world, value), seats), random)
  Equal.cong(D.AmountRule, A.RefStep(), rule => A.ref_amount_from_rule(A.health_world(world, value), seats, rule), A.ref_amount_rule(A.ref_world_load(A.health_world(world, value), seats)), D.RandomAmount{}, rules)

def loadproof.health_random_amount_machine(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +value: Nat, random: {A.current_amount(A.health_world(world, value)) == D.RandomAmount{} : D.AmountRule}) -> {A.machine_health_value(world, seats, value) == A.machine_amount_await(A.health_world(world, value), seats) : A.RefStep()}:
  Equal.cong(D.AmountRule, A.RefStep(), rule => A.machine_amount_from_rule(A.health_world(world, value), seats, rule), A.current_amount(A.health_world(world, value)), D.RandomAmount{}, random)


def loadproof.and_false_right(+left: Bool) -> {Bool.and(left, False{}) == False{} : Bool}:
  match left:
    case False{}:
      {==}
    case True{}:
      {==}

def loadproof.grab_entries_extracted(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +new_round: Bool, +entries: List<&2, D.At<&2, A.CoreSeat>>) -> {A.ref_grab_entries(world, seats, new_round, entries) == A.grab_entries(world, seats, new_round, entries, A.current_items(world, seats)) : List<&2, D.Seat>}:
  match entries:
    case Nil{}:
      {==}
    case D.At{+seat, +props} <> +rest:
      pool : {A.pool_nonempty(A.ref_pool(world, seats, seat, D.item.order())) == A.pool_nonempty(A.pool_rules(world, seats, seat, D.item.order(), A.current_items(world, seats))) : Bool} = Equal.cong(List<&2, D.Item>, Bool, pool => A.pool_nonempty(pool), A.ref_pool(world, seats, seat, D.item.order()), A.pool_rules(world, seats, seat, D.item.order(), A.current_items(world, seats)), loadproof.pool_extracted(world, seats, seat, D.item.order()))
      head : {A.grab_put(Bool.and(A.can_grab(props, new_round), A.pool_nonempty(A.ref_pool(world, seats, seat, D.item.order()))), seat, A.ref_grab_entries(world, seats, new_round, rest)) == A.grab_put(Bool.and(A.can_grab(props, new_round), A.pool_nonempty(A.pool_rules(world, seats, seat, D.item.order(), A.current_items(world, seats)))), seat, A.ref_grab_entries(world, seats, new_round, rest)) : List<&2, D.Seat>} = Equal.cong(Bool, List<&2, D.Seat>, any => A.grab_put(Bool.and(A.can_grab(props, new_round), any), seat, A.ref_grab_entries(world, seats, new_round, rest)), A.pool_nonempty(A.ref_pool(world, seats, seat, D.item.order())), A.pool_nonempty(A.pool_rules(world, seats, seat, D.item.order(), A.current_items(world, seats))), pool)
      tail : {A.grab_put(Bool.and(A.can_grab(props, new_round), A.pool_nonempty(A.pool_rules(world, seats, seat, D.item.order(), A.current_items(world, seats)))), seat, A.ref_grab_entries(world, seats, new_round, rest)) == A.grab_entries(world, seats, new_round, entries, A.current_items(world, seats)) : List<&2, D.Seat>} = Equal.cong(List<&2, D.Seat>, List<&2, D.Seat>, tail => A.grab_put(Bool.and(A.can_grab(props, new_round), A.pool_nonempty(A.pool_rules(world, seats, seat, D.item.order(), A.current_items(world, seats)))), seat, tail), A.ref_grab_entries(world, seats, new_round, rest), A.grab_entries(world, seats, new_round, rest, A.current_items(world, seats)), loadproof.grab_entries_extracted(world, seats, new_round, rest))
      Equal.trans(List<&2, D.Seat>, A.ref_grab_entries(world, seats, new_round, entries), A.grab_put(Bool.and(A.can_grab(props, new_round), A.pool_nonempty(A.pool_rules(world, seats, seat, D.item.order(), A.current_items(world, seats)))), seat, A.ref_grab_entries(world, seats, new_round, rest)), A.grab_entries(world, seats, new_round, entries, A.current_items(world, seats)), head, tail)

def loadproof.grab_off_empty(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +new_round: Bool, +entries: List<&2, D.At<&2, A.CoreSeat>>, +rules: D.ItemRules) -> {A.grab_entries(world, seats, new_round, entries, A.items_off(rules)) == Nil{} : List<&2, D.Seat>}:
  match entries:
    case Nil{}:
      {==}
    case D.At{+seat, +props} <> +rest:
      %Equal.sym(List<&2, D.Item>, A.pool_rules(world, seats, seat, D.item.order(), A.items_off(rules)), Nil{}, loadproof.pool_off_empty(world, seats, seat, D.item.order(), rules)) : {A.grab_put(Bool.and(A.can_grab(props, new_round), A.pool_nonempty(_)), seat, A.grab_entries(world, seats, new_round, rest, A.items_off(rules))) == Nil{} : List<&2, D.Seat>}
      %Equal.sym(Bool, Bool.and(A.can_grab(props, new_round), False{}), False{}, loadproof.and_false_right(A.can_grab(props, new_round))) : {A.grab_put(_, seat, A.grab_entries(world, seats, new_round, rest, A.items_off(rules))) == Nil{} : List<&2, D.Seat>}
      loadproof.grab_off_empty(world, seats, new_round, rest, rules)

def loadproof.grab_entries_empty(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +new_round: Bool, +entries: List<&2, D.At<&2, A.CoreSeat>>, disabled: {A.items_disabled(A.current_items(world, seats)) == True{} : Bool}) -> {A.ref_grab_entries(world, seats, new_round, entries) == Nil{} : List<&2, D.Seat>}:
  +rules : D.ItemRules = A.current_items(world, seats)
  extracted : {A.ref_grab_entries(world, seats, new_round, entries) == A.grab_entries(world, seats, new_round, entries, rules) : List<&2, D.Seat>} = loadproof.grab_entries_extracted(world, seats, new_round, entries)
  off : {A.grab_entries(world, seats, new_round, entries, rules) == A.grab_entries(world, seats, new_round, entries, A.items_off(rules)) : List<&2, D.Seat>} = Equal.cong(D.ItemRules, List<&2, D.Seat>, rules => A.grab_entries(world, seats, new_round, entries, rules), rules, A.items_off(rules), loadproof.items_off_id(rules, disabled))
  empty : {A.grab_entries(world, seats, new_round, entries, A.items_off(rules)) == Nil{} : List<&2, D.Seat>} = loadproof.grab_off_empty(world, seats, new_round, entries, rules)
  Equal.trans(List<&2, D.Seat>, A.ref_grab_entries(world, seats, new_round, entries), A.grab_entries(world, seats, new_round, entries, rules), Nil{}, extracted, Equal.trans(List<&2, D.Seat>, A.grab_entries(world, seats, new_round, entries, rules), A.grab_entries(world, seats, new_round, entries, A.items_off(rules)), Nil{}, off, empty))

def loadproof.grab_seats_empty(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +new_round: Bool, +amount: Nat, disabled: {A.items_disabled(A.current_items(world, seats)) == True{} : Bool}) -> {A.ref_grab_seats(world, seats, new_round, amount) == Nil{} : List<&2, D.Seat>}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, count, saw, gun, shown, deck}:
      match seats:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          match amount:
            case 0n:
              {==}
            case 1n+k:
              loadproof.grab_entries_empty(world, seats, new_round, D.ring.entries(A.CoreSeat, seats), disabled)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
          match amount:
            case 0n:
              {==}
            case 1n+k:
              loadproof.grab_entries_empty(world, seats, new_round, D.ring.entries(A.CoreSeat, seats), disabled)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          match amount:
            case 0n:
              {==}
            case 1n+k:
              loadproof.grab_entries_empty(world, seats, new_round, D.ring.entries(A.CoreSeat, seats), disabled)


# No-item scope: with every item disabled in the current round, pools are
# empty, nobody begins grabbing, and distribution falls through to loading.
# Phase 6 generalizes these.

def noitems.closed(+rule: D.ItemRule, dealt: Bool, own: Nat, total: Nat, disabled: {Q.item.disabled(rule) == True{} : Bool}) -> {I.stock.open(rule, dealt, own, total) == False{} : Bool}:
  match rule:
    case D.ItemRule{True{}, per_player, on_table}:
      Empty.absurd({I.stock.open(rule, dealt, own, total) == False{} : Bool}, false_true_absurd(disabled))
    case D.ItemRule{False{}, per_player, on_table}:
      {==}

def noitems.pool_go(+items: List<&2, D.Item>, +rules: D.ItemRules, +table: D.Table, +players: S.Players, +grabs: S.Grabs, +seat: D.Seat, +disabled: {Q.items.disabled(rules) == True{} : Bool}) -> {I.pool.go(items, rules, table, players, grabs, seat) == Nil{} : List<&2, D.Item>}:
  match items:
    case Nil{}:
      {==}
    case +item <> +rest:
      %Equal.sym(Bool, I.stock.open(D.rules.item(rules, item), D.item.dealt_at(table, item), I.owned(players, grabs, seat, item), I.owned.table(D.table.seats(table), players, grabs, item)), False{}, noitems.closed(D.rules.item(rules, item), D.item.dealt_at(table, item), I.owned(players, grabs, seat, item), I.owned.table(D.table.seats(table), players, grabs, item), loadproof.disabled_selected(rules, item, disabled))) : {I.keep(D.Item, _, item, I.pool.go(rest, rules, table, players, grabs, seat)) == Nil{} : List<&2, D.Item>}
      noitems.pool_go(rest, rules, table, players, grabs, seat, disabled)

def noitems.pool(+state: S.State, +seat: D.Seat, +disabled: {Q.items.disabled(I.round.items(Q.world.rules(S.state.world(state)))) == True{} : Bool}) -> {I.pool(state, seat) == Nil{} : List<&2, D.Item>}:
  noitems.pool_go(D.item.order(), I.round.items(Q.world.rules(S.state.world(state))), S.world.table(S.state.world(state)), S.state.players(state), S.state.grabs(state), seat, disabled)

def noitems.begin_go(+seats: List<&2, D.Seat>, +state: S.State, +new_round: Bool, +disabled: {Q.items.disabled(I.round.items(Q.world.rules(S.state.world(state)))) == True{} : Bool}) -> {I.begin.go(seats, state, new_round) == Nil{} : List<&2, D.Seat>}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> +rest:
      +can : Bool = I.begin.can(new_round, I.seat.health(S.state.players(state), seat), I.seat.slots(S.state.players(state), seat))
      %Equal.sym(List<&2, D.Item>, I.pool(state, seat), Nil{}, noitems.pool(state, seat, disabled)) : {I.keep(D.Seat, Bool.and(can, I.has_items(_)), seat, I.begin.go(rest, state, new_round)) == Nil{} : List<&2, D.Seat>}
      %Equal.sym(Bool, Bool.and(can, False{}), False{}, loadproof.and_false_right(can)) : {I.keep(D.Seat, _, seat, I.begin.go(rest, state, new_round)) == Nil{} : List<&2, D.Seat>}
      noitems.begin_go(rest, state, new_round, disabled)

def noitems.begin_seats(+state: S.State, +new_round: Bool, +amount: Nat, +disabled: {Q.items.disabled(I.round.items(Q.world.rules(S.state.world(state)))) == True{} : Bool}) -> {I.begin.seats(state, new_round, amount) == Nil{} : List<&2, D.Seat>}:
  match amount:
    case 0n:
      {==}
    case 1n+more:
      noitems.begin_go(D.table.seats(S.world.table(S.state.world(state))), state, new_round, disabled)

def noitems.distribute_skip(+state: S.State, +new_round: Bool, +amount: Nat, +disabled: {Q.items.disabled(I.round.items(Q.world.rules(S.state.world(state)))) == True{} : Bool}) -> {M.distribute.begin(state, I.begin.seats(state, new_round, amount)) == M.load.begin(state) : S.State}:
  %Equal.sym(List<&2, D.Seat>, I.begin.seats(state, new_round, amount), Nil{}, noitems.begin_seats(state, new_round, amount, disabled)) : {M.distribute.begin(state, _) == M.load.begin(state) : S.State}
  {==}

def noitems.items_found(+found: Maybe<&2, D.RoundRules>) -> {I.round.items(Q.value.or(D.RoundRules, found, D.config.default_round())) == A.support.items(A.ref_rules_found(found)) : D.ItemRules}:
  match found:
    case Some{D.RoundRules{health, loads, items}}:
      {==}
    case None{}:
      {==}

def noitems.machine_disabled(+world: S.World, +seats: A.Seats(), disabled: {A.items_disabled(A.current_items(world, seats)) == True{} : Bool}) -> {Q.items.disabled(I.round.items(Q.world.rules(world))) == True{} : Bool}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      Equal.trans(Bool, Q.items.disabled(I.round.items(Q.world.rules(world))), Q.items.disabled(A.support.items(A.ref_rules_found(D.plan.round(plan, round)))), True{}, Equal.cong(D.ItemRules, Bool, items => Q.items.disabled(items), I.round.items(Q.world.rules(world)), A.support.items(A.ref_rules_found(D.plan.round(plan, round))), noitems.items_found(D.plan.round(plan, round))), disabled)

def noitems.reset_rules(+world: S.World) -> {Q.world.rules(S.world.set_direction(S.world.set_checking_first_death(world, True{}), D.Clockwise{})) == Q.world.rules(world) : D.RoundRules}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      {==}

def noitems.reload_skip(+state: S.State, +disabled: {Q.items.disabled(I.round.items(Q.world.rules(S.state.world(state)))) == True{} : Bool}) -> {M.reload.begin(state) == M.load.begin(state) : S.State}:
  noitems.distribute_skip(state, False{}, S.world.item_amount(S.state.world(state)), disabled)

# An empty gun with no winner reloads without an amount draw: nobody could grab.
def noitems.reload_unwanted(+state: S.State, +disabled: {Q.items.disabled(I.round.items(Q.world.rules(S.state.world(state)))) == True{} : Bool}) -> {I.reload.wanted(state, None{}) == False{} : Bool}:
  %Equal.sym(List<&2, D.Seat>, I.begin.seats(state, False{}, 1n), Nil{}, noitems.begin_seats(state, False{}, 1n, disabled)) : {Bool.and(I.gun.empty(S.world.gun(S.state.world(state))), Bool.and(I.winnerless(None{}), I.has_seats(_))) == False{} : Bool}
  loadproof.and_false_right(I.gun.empty(S.world.gun(S.state.world(state))))

def noitems.stable_disabled(+world: S.World, +seats: A.Seats(), +stable: A.Stable(world, seats)) -> {Q.items.disabled(I.round.items(Q.world.rules(world))) == True{} : Bool}:
  match stable:
    case Tuple{world_eq, Tuple{supported, bounded}}:
      noitems.machine_disabled(world, seats, SupportProof.current_disabled(world, seats, supported, bounded))

# round.reset with no items skips distribution and loads.
def noitems.reset_skip(+state: S.State, +disabled: {Q.items.disabled(I.round.items(Q.world.rules(S.state.world(state)))) == True{} : Bool}) -> {M.round.reset(state) == M.load.begin(A.reset.state(state)) : S.State}:
  match state:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      reset_disabled : {Q.items.disabled(I.round.items(Q.world.rules(S.state.world(A.reset.state(state))))) == True{} : Bool} = Equal.trans(Bool, Q.items.disabled(I.round.items(Q.world.rules(S.world.set_direction(S.world.set_checking_first_death(world, True{}), D.Clockwise{})))), Q.items.disabled(I.round.items(Q.world.rules(world))), True{}, Equal.cong(D.RoundRules, Bool, rules => Q.items.disabled(I.round.items(rules)), Q.world.rules(S.world.set_direction(S.world.set_checking_first_death(world, True{}), D.Clockwise{})), Q.world.rules(world), noitems.reset_rules(world)), disabled)
      Equal.trans(S.State, M.round.reset(state), M.distribute.begin(A.reset.state(state), I.begin.seats(A.reset.state(state), True{}, A.reset.amount(state))), M.load.begin(A.reset.state(state)), {==}, noitems.distribute_skip(A.reset.state(state), True{}, A.reset.amount(state), reset_disabled))

def loadproof.round_reset_to_load(+fuel: Nat, +world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +notes: List<&2, D.Note>, disabled: {A.items_disabled(A.current_items(A.world_for(world, seats), seats)) == True{} : Bool}) -> {A.ref_reset(5n+fuel, A.world_for(world, seats), seats, notes) == A.ref_load_begin(fuel, A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, S.world.round_health(A.world_for(world, seats))), A.reset_notes(A.world_for(world, seats), notes)) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          %Equal.sym(List<&2, D.Seat>, A.ref_grab_seats(A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), True{}, amount), Nil{}, loadproof.grab_seats_empty(A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), True{}, amount, disabled)) : {A.ref_begin_grabbing(1n+fuel, A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), A.reset_notes(A.world_for(world, seats), notes), _) == A.ref_load_begin(fuel, A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), A.reset_notes(A.world_for(world, seats), notes)) : A.Ref()}
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
          %Equal.sym(List<&2, D.Seat>, A.ref_grab_seats(A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), True{}, amount), Nil{}, loadproof.grab_seats_empty(A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), True{}, amount, disabled)) : {A.ref_begin_grabbing(1n+fuel, A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), A.reset_notes(A.world_for(world, seats), notes), _) == A.ref_load_begin(fuel, A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), A.reset_notes(A.world_for(world, seats), notes)) : A.Ref()}
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          %Equal.sym(List<&2, D.Seat>, A.ref_grab_seats(A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), True{}, amount), Nil{}, loadproof.grab_seats_empty(A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), True{}, amount, disabled)) : {A.ref_begin_grabbing(1n+fuel, A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), A.reset_notes(A.world_for(world, seats), notes), _) == A.ref_load_begin(fuel, A.reset_world(A.world_for(world, seats)), A.reset_seats(seats, hp), A.reset_notes(A.world_for(world, seats), notes)) : A.Ref()}
          {==}


def loadproof.machine_reset_load(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>) -> {M.load.begin(A.reset.state(A.pack(A.world_for(world, seats), seats, phase, notes))) == A.machine_load_after_reset(A.world_for(world, seats), seats, phase, notes) : S.State}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          {==}

def loadproof.machine_reset(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, disabled: {A.items_disabled(A.current_items(A.world_for(world, seats), seats)) == True{} : Bool}) -> {A.machine_round_reset(A.world_for(world, seats), seats, phase, notes) == A.machine_load_after_reset(A.world_for(world, seats), seats, phase, notes) : S.State}:
  Equal.trans(S.State, A.machine_round_reset(A.world_for(world, seats), seats, phase, notes), M.load.begin(A.reset.state(A.pack(A.world_for(world, seats), seats, phase, notes))), A.machine_load_after_reset(A.world_for(world, seats), seats, phase, notes), noitems.reset_skip(A.pack(A.world_for(world, seats), seats, phase, notes), noitems.machine_disabled(A.world_for(world, seats), seats, disabled)), loadproof.machine_reset_load(world, seats, phase, notes))


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


def loadproof.shuffle_done(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +load: D.Load, +shells: List<&2, D.Shell>, +extra: Nat) -> {A.ref_shuffle_silent(8n+extra, world, seats, load, shells, 0n, notes) == A.ref(A.machine_shuffle(world, seats, phase, notes, load, shells, 0n)) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, +recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      GrantProof.grant_six_dispatches(A.shuffle_world(world, load, shells), seats, recipient, phase, A.loaded_notes(notes, load), extra)



def loadproof.step_ref_commutes(+state: S.State) -> {A.ref_stepped(A.ref(state)) == A.machine_ref_step(state) : A.RefStep()}:
  match state:
    case S.State{world, players, phase, notes, grabs}:
      {==}

def loadproof.swap_final_machine(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, notes: List<&2, D.Note>, +n: Nat) -> {A.swap_answer(world, seats, load, shells, 1n, notes, n) == A.machine_ref_step(A.machine_shuffle(world, seats, S.NeedSwap{load, shells, 1n}, Nil{}, load, A.machine_swap(shells, 1n, A.swap_value(0n, n)), 0n)) : A.RefStep()}:
  {==}

def loadproof.swap_final_reference(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +notes: List<&2, D.Note>, +n: Nat) -> {A.ref_swap_final_answer(world, seats, load, shells, notes, n) == A.machine_ref_step(A.machine_shuffle(world, seats, S.NeedSwap{load, shells, 1n}, Nil{}, load, A.ref_swap(shells, 1n, A.swap_value(0n, n)), 0n)) : A.RefStep()}:
  +after : S.State = A.machine_shuffle(world, seats, S.NeedSwap{load, shells, 1n}, Nil{}, load, A.ref_swap(shells, 1n, A.swap_value(0n, n)), 0n)
  closure : {A.ref_swap_final_answer(world, seats, load, shells, notes, n) == A.ref_stepped(A.ref(after)) : A.RefStep()} = Equal.cong(A.Ref(), A.RefStep(), state => A.ref_stepped(state), A.ref_shuffle_silent(96n, world, seats, load, A.ref_swap(shells, 1n, A.swap_value(0n, n)), 0n, Nil{}), A.ref(after), loadproof.shuffle_done(world, seats, S.NeedSwap{load, shells, 1n}, Nil{}, load, A.ref_swap(shells, 1n, A.swap_value(0n, n)), 88n))
  Equal.trans(A.RefStep(), A.ref_swap_final_answer(world, seats, load, shells, notes, n), A.ref_stepped(A.ref(after)), A.machine_ref_step(after), closure, loadproof.step_ref_commutes(after))

def loadproof.swap_final_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +notes: List<&2, D.Note>, +n: Nat) -> {A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, 1n, notes)), n) == A.swap_answer(world, seats, load, shells, 1n, notes, n) : A.RefStep()}:
  +phase : S.Phase = S.NeedSwap{load, shells, 1n}
  +j : Nat = A.swap_value(0n, n)
  +ref_after : S.State = A.machine_shuffle(world, seats, phase, Nil{}, load, A.ref_swap(shells, 1n, j), 0n)
  +machine_after : S.State = A.machine_shuffle(world, seats, phase, Nil{}, load, A.machine_swap(shells, 1n, j), 0n)
  first : {A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, 1n, notes)), n) == A.ref_swap_final_answer(world, seats, load, shells, notes, n) : A.RefStep()} = loadproof.swap_input_roundtrip(world, seats, load, shells, 1n, notes, n)
  second : {A.ref_swap_final_answer(world, seats, load, shells, notes, n) == A.machine_ref_step(ref_after) : A.RefStep()} = loadproof.swap_final_reference(world, seats, load, shells, notes, n)
  third : {A.machine_ref_step(ref_after) == A.machine_ref_step(machine_after) : A.RefStep()} = Equal.cong(List<&2, D.Shell>, A.RefStep(), next => A.machine_ref_step(A.machine_shuffle(world, seats, phase, Nil{}, load, next, 0n)), A.ref_swap(shells, 1n, j), A.machine_swap(shells, 1n, j), loadproof.swap_shells(shells, 1n, j))
  last : {A.machine_ref_step(machine_after) == A.swap_answer(world, seats, load, shells, 1n, notes, n) : A.RefStep()} = Equal.sym(A.RefStep(), A.swap_answer(world, seats, load, shells, 1n, notes, n), A.machine_ref_step(machine_after), loadproof.swap_final_machine(world, seats, load, shells, notes, n))
  prefix : {A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, 1n, notes)), n) == A.machine_ref_step(ref_after) : A.RefStep()} = Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, 1n, notes)), n), A.ref_swap_final_answer(world, seats, load, shells, notes, n), A.machine_ref_step(ref_after), first, second)
  suffix : {A.machine_ref_step(ref_after) == A.swap_answer(world, seats, load, shells, 1n, notes, n) : A.RefStep()} = Equal.trans(A.RefStep(), A.machine_ref_step(ref_after), A.machine_ref_step(machine_after), A.swap_answer(world, seats, load, shells, 1n, notes, n), third, last)
  Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.swap_state(world, seats, load, shells, 1n, notes)), n), A.machine_ref_step(ref_after), A.swap_answer(world, seats, load, shells, 1n, notes, n), prefix, suffix)


def loadproof.shuffle_synced(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>) -> {S.world.table(A.shuffle_world(A.world_for(world, seats), load, shells)) == D.ring.table(A.CoreSeat, seats) : D.Table}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      {==}

def loadproof.shuffle_done_point(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +load: D.Load, +shells: List<&2, D.Shell>, +extra: Nat) -> {A.machine_point(A.machine_shuffle(A.world_for(world, seats), seats, phase, notes, load, shells, 0n)) == A.ref_point(A.ref_shuffle_silent(8n+extra, A.world_for(world, seats), seats, load, shells, 0n, notes)) : D.Point}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, +recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      GrantProof.grant_six_point(A.shuffle_world(A.world_for(world, seats), load, shells), seats, recipient, phase, A.loaded_notes(notes, load), extra, loadproof.shuffle_synced(world, seats, load, shells))

def loadproof.swap_final_actual(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, notes: List<&2, D.Note>, +n: Nat) -> {A.machine_swap_state(world, seats, load, shells, 1n, notes, n) == A.machine_shuffle(world, seats, S.NeedSwap{load, shells, 1n}, Nil{}, load, A.machine_swap(shells, 1n, A.swap_value(0n, n)), 0n) : S.State}:
  {==}

def loadproof.swap_final_point_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +notes: List<&2, D.Note>, +n: Nat) -> {A.swap_point(A.world_for(world, seats), seats, load, shells, 1n, notes, n) == A.ref_step_point(A.ref_answer(A.ref(A.swap_state(A.world_for(world, seats), seats, load, shells, 1n, notes)), n)) : D.Point}:
  +synced : S.World = A.world_for(world, seats)
  +phase : S.Phase = S.NeedSwap{load, shells, 1n}
  +j : Nat = A.swap_value(0n, n)
  +machine_after : S.State = A.machine_shuffle(synced, seats, phase, Nil{}, load, A.machine_swap(shells, 1n, j), 0n)
  +ref_after : S.State = A.machine_shuffle(synced, seats, phase, Nil{}, load, A.ref_swap(shells, 1n, j), 0n)
  actual : {A.swap_point(synced, seats, load, shells, 1n, notes, n) == A.machine_point(machine_after) : D.Point} = Equal.cong(S.State, D.Point, state => A.machine_point(state), A.machine_swap_state(synced, seats, load, shells, 1n, notes, n), machine_after, loadproof.swap_final_actual(synced, seats, load, shells, notes, n))
  order : {A.machine_point(machine_after) == A.machine_point(ref_after) : D.Point} = Equal.cong(List<&2, D.Shell>, D.Point, next => A.machine_point(A.machine_shuffle(synced, seats, phase, Nil{}, load, next, 0n)), A.machine_swap(shells, 1n, j), A.ref_swap(shells, 1n, j), Equal.sym(List<&2, D.Shell>, A.ref_swap(shells, 1n, j), A.machine_swap(shells, 1n, j), loadproof.swap_shells(shells, 1n, j)))
  closure : {A.machine_point(ref_after) == A.ref_step_point(A.ref_swap_final_answer(synced, seats, load, shells, notes, n)) : D.Point} = Equal.trans(D.Point, A.machine_point(ref_after), A.ref_point(A.ref_shuffle_silent(96n, synced, seats, load, A.ref_swap(shells, 1n, j), 0n, Nil{})), A.ref_step_point(A.ref_swap_final_answer(synced, seats, load, shells, notes, n)), loadproof.shuffle_done_point(world, seats, phase, Nil{}, load, A.ref_swap(shells, 1n, j), 88n), Equal.sym(D.Point, A.ref_step_point(A.ref_swap_final_answer(synced, seats, load, shells, notes, n)), A.ref_point(A.ref_shuffle_silent(96n, synced, seats, load, A.ref_swap(shells, 1n, j), 0n, Nil{})), A.ref_step_point_commutes(A.ref_shuffle_silent(96n, synced, seats, load, A.ref_swap(shells, 1n, j), 0n, Nil{}))))
  input : {A.ref_step_point(A.ref_swap_final_answer(synced, seats, load, shells, notes, n)) == A.ref_step_point(A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 1n, notes)), n)) : D.Point} = Equal.cong(A.RefStep(), D.Point, result => A.ref_step_point(result), A.ref_swap_final_answer(synced, seats, load, shells, notes, n), A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 1n, notes)), n), Equal.sym(A.RefStep(), A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 1n, notes)), n), A.ref_swap_final_answer(synced, seats, load, shells, notes, n), loadproof.swap_input_roundtrip(synced, seats, load, shells, 1n, notes, n)))
  prefix : {A.swap_point(synced, seats, load, shells, 1n, notes, n) == A.machine_point(ref_after) : D.Point} = Equal.trans(D.Point, A.swap_point(synced, seats, load, shells, 1n, notes, n), A.machine_point(machine_after), A.machine_point(ref_after), actual, order)
  suffix : {A.machine_point(ref_after) == A.ref_step_point(A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 1n, notes)), n)) : D.Point} = Equal.trans(D.Point, A.machine_point(ref_after), A.ref_step_point(A.ref_swap_final_answer(synced, seats, load, shells, notes, n)), A.ref_step_point(A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 1n, notes)), n)), closure, input)
  Equal.trans(D.Point, A.swap_point(synced, seats, load, shells, 1n, notes, n), A.machine_point(ref_after), A.ref_step_point(A.ref_answer(A.ref(A.swap_state(synced, seats, load, shells, 1n, notes)), n)), prefix, suffix)


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


def loadproof.raw_state_exact(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>) -> {A.raw_state(world, seats, phase, notes) == A.ref(A.pack(world, seats, phase, notes)) : A.Ref()}:
  Equal.sym(A.Ref(), A.ref(A.pack(world, seats, phase, notes)), A.raw_state(world, seats, phase, notes), Equal.cong(A.Seats(), A.Ref(), restored => A.raw_state(world, restored, phase, notes), seats, seats, {==}))

def loadproof.shuffle_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +load: D.Load, +shells: List<&2, D.Shell>, +i: Nat, +extra: Nat) -> {A.ref_shuffle_silent(8n+extra, world, seats, load, shells, i, notes) == A.ref(A.machine_shuffle(world, seats, phase, notes, load, shells, i)) : A.Ref()}:
  match i:
    case 0n:
      loadproof.shuffle_done(world, seats, phase, notes, load, shells, extra)
    case 1n+rest:
      width : {A.ref_shuffle_silent(8n+extra, world, seats, load, shells, i, notes) == A.raw_state(world, seats, S.NeedSwap{load, shells, i}, notes) : A.Ref()} = Equal.cong(Nat, A.Ref(), width => A.raw_swap_width(world, seats, load, shells, i, width, notes), rest, A.subtract_zero(rest), subtract_zero_backwards(rest))
      Equal.trans(A.Ref(), A.ref_shuffle_silent(8n+extra, world, seats, load, shells, i, notes), A.raw_state(world, seats, S.NeedSwap{load, shells, i}, notes), A.ref(A.machine_shuffle(world, seats, phase, notes, load, shells, i)), width, loadproof.raw_state_exact(world, seats, S.NeedSwap{load, shells, i}, notes))

def loadproof.host_deck(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>) -> {A.ref_host_deck(world, seats) == A.batches(S.world.deck(world)) : List<&2, A.RefBatch()>}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, +deck}:
      match table deck:
        case D.TwoSeats{} S.Decks{a, b, c}:
          {==}
        case D.ThreeSeats{} S.Decks{a, b, c}:
          {==}
        case D.FourSeats{} S.Decks{a, b, c}:
          {==}


def loadproof.host_setdeck(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +new_deck: List<&2, S.Batch>) -> {A.ref_set_deck(world, seats, A.batches(new_deck)) == A.host(S.world.set_deck(world, new_deck), seats) : A.RefHost()}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, +deck}:
      match table deck:
        case D.TwoSeats{} S.Decks{a, b, c}:
          {==}
        case D.ThreeSeats{} S.Decks{a, b, c}:
          {==}
        case D.FourSeats{} S.Decks{a, b, c}:
          {==}

def loadproof.removed_host(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +index: Nat) -> {A.ref_removed_host(world, seats, index) == A.host(A.machine_remove_world(world, index), seats) : A.RefHost()}:
  projected : {A.ref_removed_host(world, seats, index) == A.ref_set_deck(world, seats, A.ref_batch_remove(S.world.deck(world), index)) : A.RefHost()} = Equal.cong(List<&2, A.RefBatch()>, A.RefHost(), deck => A.ref_set_deck(world, seats, A.ref_remove_deck(deck, index)), A.ref_host_deck(world, seats), A.batches(S.world.deck(world)), loadproof.host_deck(world, seats))
  removed : {A.ref_set_deck(world, seats, A.ref_batch_remove(S.world.deck(world), index)) == A.ref_set_deck(world, seats, A.machine_batch_remove(S.world.deck(world), index)) : A.RefHost()} = Equal.cong(List<&2, A.RefBatch()>, A.RefHost(), deck => A.ref_set_deck(world, seats, deck), A.ref_batch_remove(S.world.deck(world), index), A.machine_batch_remove(S.world.deck(world), index), loadproof.batch_remove(S.world.deck(world), index))
  updated : {A.ref_set_deck(world, seats, A.machine_batch_remove(S.world.deck(world), index)) == A.host(A.machine_remove_world(world, index), seats) : A.RefHost()} = loadproof.host_setdeck(world, seats, A.machine_deck_remove(S.world.deck(world), index))
  Equal.trans(A.RefHost(), A.ref_removed_host(world, seats, index), A.ref_set_deck(world, seats, A.ref_batch_remove(S.world.deck(world), index)), A.host(A.machine_remove_world(world, index), seats), projected, Equal.trans(A.RefHost(), A.ref_set_deck(world, seats, A.ref_batch_remove(S.world.deck(world), index)), A.ref_set_deck(world, seats, A.machine_batch_remove(S.world.deck(world), index)), A.host(A.machine_remove_world(world, index), seats), removed, updated))


def loadproof.actual_world_load(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +sampled: D.Load) -> {A.ref_load_actual(A.ref_world_load(world, seats), sampled) == A.machine_load_actual(A.machine_world_load(world), sampled) : D.Load}:
  rules : {A.ref_load_actual(A.ref_world_load(world, seats), sampled) == A.ref_load_actual(A.machine_world_load(world), sampled) : D.Load} = Equal.cong(D.LoadRule, D.Load, rule => A.ref_load_actual(rule, sampled), A.ref_world_load(world, seats), A.machine_world_load(world), loadproof.world_load(world, seats))
  Equal.trans(D.Load, A.ref_load_actual(A.ref_world_load(world, seats), sampled), A.ref_load_actual(A.machine_world_load(world), sampled), A.machine_load_actual(A.machine_world_load(world), sampled), rules, loadproof.load_actual(A.machine_world_load(world), sampled))

def loadproof.batch_found_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +index: Nat, +selected: Maybe<&2, S.Batch>, +extra: Nat) -> {A.ref_batch_found(8n+extra, world, seats, index, selected, notes) == A.ref(A.machine_batch_found(world, seats, phase, notes, index, selected)) : A.Ref()}:
  match selected:
    case None{}:
      loadproof.raw_state_exact(world, seats, S.Blocked{}, notes)
    case Some{S.Batch{id, +sampled}}:
      +updated : S.World = A.machine_remove_world(world, index)
      +reference_load : D.Load = A.ref_load_actual(A.ref_world_load(world, seats), sampled)
      +load : D.Load = A.machine_load_actual(A.machine_world_load(world), sampled)
      +shells : List<&2, D.Shell> = A.machine_load_shells(load)
      +i : Nat = A.machine_predecessor(List.length(&2, D.Shell, shells))
      +first : A.Ref() = A.ref_batch_continuation(8n+extra, A.host(updated, seats), reference_load, notes)
      +second : A.Ref() = A.ref_batch_continuation(8n+extra, A.host(updated, seats), load, notes)
      +third : A.Ref() = A.ref_shuffle_silent(8n+extra, updated, seats, load, shells, A.ref_predecessor(List.length(&2, D.Shell, shells)), notes)
      +fourth : A.Ref() = A.ref_shuffle_silent(8n+extra, updated, seats, load, shells, i, notes)
      +last : A.Ref() = A.ref(A.machine_batch_found(world, seats, phase, notes, index, selected))
      host : {A.ref_batch_found(8n+extra, world, seats, index, selected, notes) == first : A.Ref()} = Equal.cong(A.RefHost(), A.Ref(), h => A.ref_batch_continuation(8n+extra, h, reference_load, notes), A.ref_removed_host(world, seats, index), A.host(updated, seats), loadproof.removed_host(world, seats, index))
      custom : {first == second : A.Ref()} = Equal.cong(D.Load, A.Ref(), load => A.ref_batch_continuation(8n+extra, A.host(updated, seats), load, notes), reference_load, load, loadproof.actual_world_load(world, seats, sampled))
      chamber : {second == third : A.Ref()} = Equal.cong(List<&2, D.Shell>, A.Ref(), shells => A.ref_shuffle_silent(8n+extra, updated, seats, load, shells, A.ref_predecessor(List.length(&2, D.Shell, shells)), notes), A.ref_load_shells(load), shells, loadproof.load_shells(load))
      bound : {third == fourth : A.Ref()} = Equal.cong(Nat, A.Ref(), i => A.ref_shuffle_silent(8n+extra, updated, seats, load, shells, i, notes), A.ref_predecessor(List.length(&2, D.Shell, shells)), i, loadproof.predecessor(List.length(&2, D.Shell, shells)))
      closed : {fourth == last : A.Ref()} = loadproof.shuffle_matches(updated, seats, phase, notes, load, shells, i, extra)
      tail : {third == last : A.Ref()} = Equal.trans(A.Ref(), third, fourth, last, bound, closed)
      middle : {second == last : A.Ref()} = Equal.trans(A.Ref(), second, third, last, chamber, tail)
      start : {first == last : A.Ref()} = Equal.trans(A.Ref(), first, second, last, custom, middle)
      Equal.trans(A.Ref(), A.ref_batch_found(8n+extra, world, seats, index, selected, notes), first, last, host, start)


def loadproof.batch_lookup(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +index: Nat) -> {A.ref_host_batch_nth(world, seats, index) == A.found_batch(A.machine_batch_lookup(world, index)) : Maybe<&2, A.RefBatch()>}:
  projected : {A.ref_host_batch_nth(world, seats, index) == A.ref_batch_nth(S.world.deck(world), index) : Maybe<&2, A.RefBatch()>} = Equal.cong(List<&2, A.RefBatch()>, Maybe<&2, A.RefBatch()>, deck => A.ref_nth_batch(deck, index), A.ref_host_deck(world, seats), A.batches(S.world.deck(world)), loadproof.host_deck(world, seats))
  Equal.trans(Maybe<&2, A.RefBatch()>, A.ref_host_batch_nth(world, seats, index), A.ref_batch_nth(S.world.deck(world), index), A.found_batch(A.machine_batch_lookup(world, index)), projected, loadproof.batch_nth(S.world.deck(world), index))

def loadproof.batch_chosen_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +index: Nat, +extra: Nat) -> {A.ref_batch_chosen(9n+extra, world, seats, index, notes) == A.ref(A.machine_batch(world, seats, phase, notes, index)) : A.Ref()}:
  selected : {A.ref_batch_chosen(9n+extra, world, seats, index, notes) == A.ref_batch_found(8n+extra, world, seats, index, A.machine_batch_lookup(world, index), notes) : A.Ref()} = Equal.cong(Maybe<&2, A.RefBatch()>, A.Ref(), selected => A.ref_batch_found_ref(8n+extra, world, seats, index, selected, notes), A.ref_host_batch_nth(world, seats, index), A.found_batch(A.machine_batch_lookup(world, index)), loadproof.batch_lookup(world, seats, index))
  Equal.trans(A.Ref(), A.ref_batch_chosen(9n+extra, world, seats, index, notes), A.ref_batch_found(8n+extra, world, seats, index, A.machine_batch_lookup(world, index), notes), A.ref(A.machine_batch(world, seats, phase, notes, index)), selected, loadproof.batch_found_matches(world, seats, phase, notes, index, A.machine_batch_lookup(world, index), extra))


def loadproof.canonical_point(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>) -> {A.machine_point(A.canonical_state(world, seats, phase, notes)) == A.ref_point(A.ref(A.canonical_state(world, seats, phase, notes))) : D.Point}:
  +state : S.State = A.canonical_state(world, seats, phase, notes)
  request : {A.machine_request(state) == A.ref_request(A.ref(state)) : D.Request} = law.legal_exact(world, seats, phase, notes)
  board : {A.machine_board(state) == A.ref_board(A.ref(state)) : D.Board} = boards_match(world, seats, A.canonical_phase(phase, seats), notes)
  Equal.trans(D.Point, A.machine_point(state), D.Point{A.ref_request(A.ref(state)), A.machine_board(state)}, A.ref_point(A.ref(state)), Equal.cong(D.Request, D.Point, request => D.Point{request, A.machine_board(state)}, A.machine_request(state), A.ref_request(A.ref(state)), request), Equal.cong(D.Board, D.Point, board => D.Point{A.ref_request(A.ref(state)), board}, A.machine_board(state), A.ref_board(A.ref(state)), board))


def loadproof.batch_answer_width_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +width: Nat, +notes: List<&2, D.Note>, +n: Nat) -> {A.ref_batch_answer_width(world, seats, width, notes, n) == A.machine_batch_answer_width(world, seats, width, notes, n) : A.RefStep()}:
  +after : S.State = A.machine_batch(world, seats, S.NeedBatch{}, Nil{}, A.batch_value(width, n))
  closure : {A.ref_batch_answer_width(world, seats, width, notes, n) == A.ref_stepped(A.ref(after)) : A.RefStep()} = Equal.cong(A.Ref(), A.RefStep(), state => A.ref_stepped(state), A.ref_batch_chosen(96n, world, seats, A.batch_value(width, n), Nil{}), A.ref(after), loadproof.batch_chosen_matches(world, seats, S.NeedBatch{}, Nil{}, A.batch_value(width, n), 87n))
  Equal.trans(A.RefStep(), A.ref_batch_answer_width(world, seats, width, notes, n), A.ref_stepped(A.ref(after)), A.machine_batch_answer_width(world, seats, width, notes, n), closure, loadproof.step_ref_commutes(after))


def loadproof.batch_answer_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +notes: List<&2, D.Note>, +n: Nat) -> {A.ref_answer(A.ref(A.pack(world, seats, S.NeedBatch{}, notes)), n) == A.batch_answer(world, seats, notes, n) : A.RefStep()}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, +deck}:
      match table deck:
        case D.TwoSeats{} S.Decks{Nil{}, b, c}:
          {==}
        case D.TwoSeats{} S.Decks{S.Batch{id0, load0} <> Nil{}, b, c}:
          {==}
        case D.TwoSeats{} S.Decks{S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest, b, c}:
          input : {A.ref_answer(A.ref(A.pack(world, seats, S.NeedBatch{}, notes)), n) == A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n) : A.RefStep()} = Equal.cong(A.Seats(), A.RefStep(), restored => A.ref_answer(A.raw_state(world, restored, S.NeedBatch{}, notes), n), seats, seats, {==})
          range : {A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n) == A.ref_batch_answer_width(world, seats, List.length(&2, S.Batch, rest), notes, n) : A.RefStep()} = Equal.cong(Nat, A.RefStep(), width => A.ref_batch_answer_width(world, seats, width, notes, n), A.ref_batch_length(rest), List.length(&2, S.Batch, rest), batch_length(rest))
          tail : {A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n) == A.batch_answer(world, seats, notes, n) : A.RefStep()} = Equal.trans(A.RefStep(), A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n), A.ref_batch_answer_width(world, seats, List.length(&2, S.Batch, rest), notes, n), A.batch_answer(world, seats, notes, n), range, loadproof.batch_answer_width_matches(world, seats, List.length(&2, S.Batch, rest), notes, n))
          Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.pack(world, seats, S.NeedBatch{}, notes)), n), A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n), A.batch_answer(world, seats, notes, n), input, tail)
        case D.ThreeSeats{} S.Decks{a, Nil{}, c}:
          {==}
        case D.ThreeSeats{} S.Decks{a, S.Batch{id0, load0} <> Nil{}, c}:
          {==}
        case D.ThreeSeats{} S.Decks{a, S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest, c}:
          input : {A.ref_answer(A.ref(A.pack(world, seats, S.NeedBatch{}, notes)), n) == A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n) : A.RefStep()} = Equal.cong(A.Seats(), A.RefStep(), restored => A.ref_answer(A.raw_state(world, restored, S.NeedBatch{}, notes), n), seats, seats, {==})
          range : {A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n) == A.ref_batch_answer_width(world, seats, List.length(&2, S.Batch, rest), notes, n) : A.RefStep()} = Equal.cong(Nat, A.RefStep(), width => A.ref_batch_answer_width(world, seats, width, notes, n), A.ref_batch_length(rest), List.length(&2, S.Batch, rest), batch_length(rest))
          tail : {A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n) == A.batch_answer(world, seats, notes, n) : A.RefStep()} = Equal.trans(A.RefStep(), A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n), A.ref_batch_answer_width(world, seats, List.length(&2, S.Batch, rest), notes, n), A.batch_answer(world, seats, notes, n), range, loadproof.batch_answer_width_matches(world, seats, List.length(&2, S.Batch, rest), notes, n))
          Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.pack(world, seats, S.NeedBatch{}, notes)), n), A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n), A.batch_answer(world, seats, notes, n), input, tail)
        case D.FourSeats{} S.Decks{a, b, Nil{}}:
          {==}
        case D.FourSeats{} S.Decks{a, b, S.Batch{id0, load0} <> Nil{}}:
          {==}
        case D.FourSeats{} S.Decks{a, b, S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest}:
          input : {A.ref_answer(A.ref(A.pack(world, seats, S.NeedBatch{}, notes)), n) == A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n) : A.RefStep()} = Equal.cong(A.Seats(), A.RefStep(), restored => A.ref_answer(A.raw_state(world, restored, S.NeedBatch{}, notes), n), seats, seats, {==})
          range : {A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n) == A.ref_batch_answer_width(world, seats, List.length(&2, S.Batch, rest), notes, n) : A.RefStep()} = Equal.cong(Nat, A.RefStep(), width => A.ref_batch_answer_width(world, seats, width, notes, n), A.ref_batch_length(rest), List.length(&2, S.Batch, rest), batch_length(rest))
          tail : {A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n) == A.batch_answer(world, seats, notes, n) : A.RefStep()} = Equal.trans(A.RefStep(), A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n), A.ref_batch_answer_width(world, seats, List.length(&2, S.Batch, rest), notes, n), A.batch_answer(world, seats, notes, n), range, loadproof.batch_answer_width_matches(world, seats, List.length(&2, S.Batch, rest), notes, n))
          Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.pack(world, seats, S.NeedBatch{}, notes)), n), A.ref_answer(A.raw_state(world, seats, S.NeedBatch{}, notes), n), A.batch_answer(world, seats, notes, n), input, tail)


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

def loadproof.refill_host(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>) -> {A.ref_refill_host(world, seats) == A.host(A.machine_refill_world(world), seats) : A.RefHost()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      Equal.cong(A.RefDecks(), A.RefHost(), decks => A.ref_set_decks(world, seats, decks), A.ref_full_decks(), A.machine_full_decks(), loadproof.full_decks())


def loadproof.ready_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +extra: Nat) -> {A.ref_ready(9n+extra, world, seats, notes) == A.ref(A.machine_ready(world, seats, phase, notes)) : A.Ref()}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, +deck}:
      match table deck:
        case D.TwoSeats{} S.Decks{Nil{}, b, c}:
          loadproof.raw_state_exact(world, seats, S.Blocked{}, notes)
        case D.TwoSeats{} S.Decks{S.Batch{id0, load0} <> Nil{}, b, c}:
          loadproof.batch_chosen_matches(world, seats, phase, notes, 0n, extra)
        case D.TwoSeats{} S.Decks{S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest, b, c}:
          loadproof.raw_state_exact(world, seats, S.NeedBatch{}, notes)
        case D.ThreeSeats{} S.Decks{a, Nil{}, c}:
          loadproof.raw_state_exact(world, seats, S.Blocked{}, notes)
        case D.ThreeSeats{} S.Decks{a, S.Batch{id0, load0} <> Nil{}, c}:
          loadproof.batch_chosen_matches(world, seats, phase, notes, 0n, extra)
        case D.ThreeSeats{} S.Decks{a, S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest, c}:
          loadproof.raw_state_exact(world, seats, S.NeedBatch{}, notes)
        case D.FourSeats{} S.Decks{a, b, Nil{}}:
          loadproof.raw_state_exact(world, seats, S.Blocked{}, notes)
        case D.FourSeats{} S.Decks{a, b, S.Batch{id0, load0} <> Nil{}}:
          loadproof.batch_chosen_matches(world, seats, phase, notes, 0n, extra)
        case D.FourSeats{} S.Decks{a, b, S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest}:
          loadproof.raw_state_exact(world, seats, S.NeedBatch{}, notes)


def loadproof.select_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +extra: Nat) -> {A.ref_select(10n+extra, world, seats, notes) == A.ref(A.machine_refill(world, seats, phase, notes)) : A.Ref()}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, +deck}:
      match table deck:
        case D.TwoSeats{} S.Decks{Nil{}, b, c}:
          +refilled : S.World = A.machine_refill_world(world)
          host : {A.ref_select(10n+extra, world, seats, notes) == A.ref_ready(9n+extra, refilled, seats, notes) : A.Ref()} = Equal.cong(A.RefHost(), A.Ref(), h => A.ref_ready_host(9n+extra, h, notes), A.ref_refill_host(world, seats), A.host(refilled, seats), loadproof.refill_host(world, seats))
          Equal.trans(A.Ref(), A.ref_select(10n+extra, world, seats, notes), A.ref_ready(9n+extra, refilled, seats, notes), A.ref(A.machine_refill(world, seats, phase, notes)), host, loadproof.ready_matches(refilled, seats, phase, notes, extra))
        case D.TwoSeats{} S.Decks{S.Batch{id0, load0} <> Nil{}, b, c}:
          loadproof.ready_matches(world, seats, phase, notes, extra)
        case D.TwoSeats{} S.Decks{S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest, b, c}:
          loadproof.ready_matches(world, seats, phase, notes, extra)
        case D.ThreeSeats{} S.Decks{a, Nil{}, c}:
          +refilled : S.World = A.machine_refill_world(world)
          host : {A.ref_select(10n+extra, world, seats, notes) == A.ref_ready(9n+extra, refilled, seats, notes) : A.Ref()} = Equal.cong(A.RefHost(), A.Ref(), h => A.ref_ready_host(9n+extra, h, notes), A.ref_refill_host(world, seats), A.host(refilled, seats), loadproof.refill_host(world, seats))
          Equal.trans(A.Ref(), A.ref_select(10n+extra, world, seats, notes), A.ref_ready(9n+extra, refilled, seats, notes), A.ref(A.machine_refill(world, seats, phase, notes)), host, loadproof.ready_matches(refilled, seats, phase, notes, extra))
        case D.ThreeSeats{} S.Decks{a, S.Batch{id0, load0} <> Nil{}, c}:
          loadproof.ready_matches(world, seats, phase, notes, extra)
        case D.ThreeSeats{} S.Decks{a, S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest, c}:
          loadproof.ready_matches(world, seats, phase, notes, extra)
        case D.FourSeats{} S.Decks{a, b, Nil{}}:
          +refilled : S.World = A.machine_refill_world(world)
          host : {A.ref_select(10n+extra, world, seats, notes) == A.ref_ready(9n+extra, refilled, seats, notes) : A.Ref()} = Equal.cong(A.RefHost(), A.Ref(), h => A.ref_ready_host(9n+extra, h, notes), A.ref_refill_host(world, seats), A.host(refilled, seats), loadproof.refill_host(world, seats))
          Equal.trans(A.Ref(), A.ref_select(10n+extra, world, seats, notes), A.ref_ready(9n+extra, refilled, seats, notes), A.ref(A.machine_refill(world, seats, phase, notes)), host, loadproof.ready_matches(refilled, seats, phase, notes, extra))
        case D.FourSeats{} S.Decks{a, b, S.Batch{id0, load0} <> Nil{}}:
          loadproof.ready_matches(world, seats, phase, notes, extra)
        case D.FourSeats{} S.Decks{a, b, S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest}:
          loadproof.ready_matches(world, seats, phase, notes, extra)


def loadproof.load_begin_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +extra: Nat) -> {A.ref_load_begin(11n+extra, world, seats, notes) == A.ref(A.machine_load_begin(world, seats, phase, notes)) : A.Ref()}:
  match world:
    case S.World{config, before, round, +index, +first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      +updated : S.World = A.loaded_world(world)
      increment : {A.ref_load_begin(11n+extra, world, seats, notes) == A.ref_select(10n+extra, updated, seats, notes) : A.Ref()} = Equal.cong(Nat, A.Ref(), index => A.ref_loading_next(10n+extra, world, seats, notes, index), A.ref_next_load(first, index), A.machine_next_load(first, index), loadproof.load_next(first, index))
      Equal.trans(A.Ref(), A.ref_load_begin(11n+extra, world, seats, notes), A.ref_select(10n+extra, updated, seats, notes), A.ref(A.machine_load_begin(world, seats, phase, notes)), increment, loadproof.select_matches(updated, seats, phase, notes, extra))


def loadproof.reset_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +extra: Nat, +disabled: {A.items_disabled(A.current_items(A.world_for(world, seats), seats)) == True{} : Bool}) -> {A.ref_reset(16n+extra, A.world_for(world, seats), seats, notes) == A.ref(A.machine_round_reset(A.world_for(world, seats), seats, phase, notes)) : A.Ref()}:
  +w : S.World = A.world_for(world, seats)
  +reset_world : S.World = A.reset_world(w)
  +reset_seats : A.Seats() = A.reset_seats(seats, S.world.round_health(w))
  +reset_notes : List<&2, D.Note> = A.reset_notes(w, notes)
  +load : A.Ref() = A.ref_load_begin(11n+extra, reset_world, reset_seats, reset_notes)
  +loaded : A.Ref() = A.ref(A.machine_load_after_reset(w, seats, phase, notes))
  source : {A.ref_reset(16n+extra, w, seats, notes) == load : A.Ref()} = loadproof.round_reset_to_load(11n+extra, world, seats, notes, disabled)
  target : {load == A.ref(A.machine_round_reset(w, seats, phase, notes)) : A.Ref()} = Equal.trans(A.Ref(), load, loaded, A.ref(A.machine_round_reset(w, seats, phase, notes)), loadproof.load_begin_matches(reset_world, reset_seats, phase, reset_notes, extra), Equal.cong(S.State, A.Ref(), state => A.ref(state), A.machine_load_after_reset(w, seats, phase, notes), A.machine_round_reset(w, seats, phase, notes), Equal.sym(S.State, A.machine_round_reset(w, seats, phase, notes), A.machine_load_after_reset(w, seats, phase, notes), loadproof.machine_reset(world, seats, phase, notes, disabled))))
  Equal.trans(A.Ref(), A.ref_reset(16n+extra, w, seats, notes), load, A.ref(A.machine_round_reset(w, seats, phase, notes)), source, target)


def loadproof.amount_rule_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +rule: D.AmountRule, +notes: List<&2, D.Note>, +extra: Nat, disabled: {A.items_disabled(A.current_items(A.world_for(world, seats), seats)) == True{} : Bool}) -> {A.ref_amount_rule_state(16n+extra, A.world_for(world, seats), seats, rule, notes) == A.ref(A.machine_amount_rule_state(A.world_for(world, seats), seats, phase, rule, notes)) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match rule:
        case D.RandomAmount{}:
          loadproof.raw_state_exact(A.world_for(world, seats), seats, S.NeedAmount{}, notes)
        case D.FixedAmount{+value}:
          loadproof.reset_matches(A.amount_world(world, value), seats, phase, notes, extra, disabled)

def loadproof.amount_begin_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +extra: Nat, disabled: {A.items_disabled(A.current_items(A.world_for(world, seats), seats)) == True{} : Bool}) -> {A.ref_amount_begin(17n+extra, A.world_for(world, seats), seats, notes) == A.ref(A.machine_amount_begin(A.world_for(world, seats), seats, phase, notes)) : A.Ref()}:
  +w : S.World = A.world_for(world, seats)
  +rule : D.AmountRule = A.current_amount(w)
  rules : {A.ref_amount_begin(17n+extra, w, seats, notes) == A.ref_amount_rule_state(16n+extra, w, seats, rule, notes) : A.Ref()} = Equal.cong(D.AmountRule, A.Ref(), rule => A.ref_amount_rule_state(16n+extra, w, seats, rule, notes), A.ref_amount_rule(A.ref_world_load(w, seats)), rule, loadproof.current_amount_matches(w, seats))
  Equal.trans(A.Ref(), A.ref_amount_begin(17n+extra, w, seats, notes), A.ref_amount_rule_state(16n+extra, w, seats, rule, notes), A.ref(A.machine_amount_begin(w, seats, phase, notes)), rules, loadproof.amount_rule_matches(world, seats, phase, rule, notes, extra, disabled))


def loadproof.amount_answer_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +notes: List<&2, D.Note>, +n: Nat, disabled: {A.items_disabled(A.current_items(A.world_for(world, seats), seats)) == True{} : Bool}) -> {A.ref_answer(A.ref(A.amount_state(A.world_for(world, seats), seats, notes)), n) == A.amount_answer(A.world_for(world, seats), seats, notes, n) : A.RefStep()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      +w : S.World = A.world_for(world, seats)
      +value : Nat = A.amount_value(w, n)
      +updated : S.World = A.amount_world(w, value)
      +after : S.State = A.machine_round_reset(updated, seats, S.NeedAmount{}, Nil{})
      input : {A.ref_answer(A.ref(A.amount_state(w, seats, notes)), n) == A.ref_answer(A.raw_state(w, seats, S.NeedAmount{}, notes), n) : A.RefStep()} = Equal.cong(A.Seats(), A.RefStep(), restored => A.ref_answer(A.raw_state(w, restored, S.NeedAmount{}, notes), n), seats, seats, {==})
      closure : {A.ref_answer(A.raw_state(w, seats, S.NeedAmount{}, notes), n) == A.ref_stepped(A.ref(after)) : A.RefStep()} = Equal.cong(A.Ref(), A.RefStep(), state => A.ref_stepped(state), A.ref_reset(96n, updated, seats, Nil{}), A.ref(after), loadproof.reset_matches(A.amount_world(world, value), seats, S.NeedAmount{}, Nil{}, 80n, disabled))
      target : {A.ref_answer(A.raw_state(w, seats, S.NeedAmount{}, notes), n) == A.amount_answer(w, seats, notes, n) : A.RefStep()} = Equal.trans(A.RefStep(), A.ref_answer(A.raw_state(w, seats, S.NeedAmount{}, notes), n), A.ref_stepped(A.ref(after)), A.amount_answer(w, seats, notes, n), closure, loadproof.step_ref_commutes(after))
      Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.amount_state(w, seats, notes)), n), A.ref_answer(A.raw_state(w, seats, S.NeedAmount{}, notes), n), A.amount_answer(w, seats, notes, n), input, target)

def loadproof.health_answer_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +notes: List<&2, D.Note>, +n: Nat, disabled: {A.items_disabled(A.current_items(A.world_for(world, seats), seats)) == True{} : Bool}) -> {A.ref_answer(A.ref(A.health_state(A.world_for(world, seats), seats, notes)), n) == A.health_answer(A.world_for(world, seats), seats, notes, n) : A.RefStep()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      +w : S.World = A.world_for(world, seats)
      +value : Nat = A.health_value(w, n)
      +updated : S.World = A.health_world(w, value)
      +after : S.State = A.machine_amount_begin(updated, seats, S.NeedHealth{}, Nil{})
      input : {A.ref_answer(A.ref(A.health_state(w, seats, notes)), n) == A.ref_answer(A.raw_state(w, seats, S.NeedHealth{}, notes), n) : A.RefStep()} = Equal.cong(A.Seats(), A.RefStep(), restored => A.ref_answer(A.raw_state(w, restored, S.NeedHealth{}, notes), n), seats, seats, {==})
      closure : {A.ref_answer(A.raw_state(w, seats, S.NeedHealth{}, notes), n) == A.ref_stepped(A.ref(after)) : A.RefStep()} = Equal.cong(A.Ref(), A.RefStep(), state => A.ref_stepped(state), A.ref_amount_begin(96n, updated, seats, Nil{}), A.ref(after), loadproof.amount_begin_matches(A.health_world(world, value), seats, S.NeedHealth{}, Nil{}, 79n, disabled))
      target : {A.ref_answer(A.raw_state(w, seats, S.NeedHealth{}, notes), n) == A.health_answer(w, seats, notes, n) : A.RefStep()} = Equal.trans(A.RefStep(), A.ref_answer(A.raw_state(w, seats, S.NeedHealth{}, notes), n), A.ref_stepped(A.ref(after)), A.health_answer(w, seats, notes, n), closure, loadproof.step_ref_commutes(after))
      Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.health_state(w, seats, notes)), n), A.ref_answer(A.raw_state(w, seats, S.NeedHealth{}, notes), n), A.health_answer(w, seats, notes, n), input, target)


def loadproof.round_health(+rules: D.RoundRules) -> {A.ref_round_health(rules) == A.machine_round_health(rules) : D.HealthRule}:
  match rules:
    case D.RoundRules{health, loads, items}:
      {==}

def loadproof.current_health_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>) -> {A.ref_current_health(world, seats) == A.machine_current_health(world) : D.HealthRule}:
  rules : {A.ref_current_health(world, seats) == A.ref_round_health(A.machine_world_rules(world)) : D.HealthRule} = Equal.cong(D.RoundRules, D.HealthRule, rules => A.ref_round_health(rules), A.ref_world_rules(world, seats), A.machine_world_rules(world), loadproof.world_rules(world, seats))
  Equal.trans(D.HealthRule, A.ref_current_health(world, seats), A.ref_round_health(A.machine_world_rules(world)), A.machine_current_health(world), rules, loadproof.round_health(A.machine_world_rules(world)))

def loadproof.health_rule_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +rule: D.HealthRule, +notes: List<&2, D.Note>, +extra: Nat, disabled: {A.items_disabled(A.current_items(A.world_for(world, seats), seats)) == True{} : Bool}) -> {A.ref_health_rule_state(17n+extra, A.world_for(world, seats), seats, rule, notes) == A.ref(A.machine_health_rule_state(A.world_for(world, seats), seats, phase, rule, notes)) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match rule:
        case D.RandomHealth{}:
          loadproof.raw_state_exact(A.world_for(world, seats), seats, S.NeedHealth{}, notes)
        case D.FixedHealth{+value}:
          loadproof.amount_begin_matches(A.health_world(world, D.pos.nat(value)), seats, phase, notes, extra, disabled)

def loadproof.health_begin_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +extra: Nat, disabled: {A.items_disabled(A.current_items(A.world_for(world, seats), seats)) == True{} : Bool}) -> {A.ref_health_begin(18n+extra, A.world_for(world, seats), seats, notes) == A.ref(A.machine_health_begin(A.world_for(world, seats), seats, phase, notes)) : A.Ref()}:
  +w : S.World = A.world_for(world, seats)
  +rule : D.HealthRule = A.machine_current_health(w)
  rules : {A.ref_health_begin(18n+extra, w, seats, notes) == A.ref_health_rule_state(17n+extra, w, seats, rule, notes) : A.Ref()} = Equal.cong(D.HealthRule, A.Ref(), rule => A.ref_health_rule_state(17n+extra, w, seats, rule, notes), A.ref_current_health(w, seats), rule, loadproof.current_health_matches(w, seats))
  Equal.trans(A.Ref(), A.ref_health_begin(18n+extra, w, seats, notes), A.ref_health_rule_state(17n+extra, w, seats, rule, notes), A.ref(A.machine_health_begin(w, seats, phase, notes)), rules, loadproof.health_rule_matches(world, seats, phase, rule, notes, extra, disabled))

def loadproof.next_round(+before: Bool, +index: Nat) -> {A.ref_next_round(before, index) == A.machine_next_round(before, index) : Nat}:
  match before:
    case True{}:
      {==}
    case False{}:
      {==}


def loadproof.first_chosen_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +seat: D.Seat, +extra: Nat, disabled: {A.items_disabled(A.current_items(A.world_for(A.first_world(world, seat), seats), seats)) == True{} : Bool}) -> {A.ref_first_chosen(19n+extra, A.world_for(world, seats), seats, seat, notes) == A.ref(A.machine_first_chosen(A.world_for(world, seats), seats, phase, notes, seat)) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, +before, +round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      +w : S.World = A.world_for(world, seats)
      +updated : S.World = A.first_world(w, seat)
      source : {A.ref_first_chosen(19n+extra, w, seats, seat, notes) == A.ref_health_begin(18n+extra, updated, seats, notes) : A.Ref()} = Equal.cong(Nat, A.Ref(), index => A.ref_first_next(18n+extra, w, seats, seat, notes, index), A.ref_next_round(before, round), A.machine_next_round(before, round), loadproof.next_round(before, round))
      Equal.trans(A.Ref(), A.ref_first_chosen(19n+extra, w, seats, seat, notes), A.ref_health_begin(18n+extra, updated, seats, notes), A.ref(A.machine_first_chosen(w, seats, phase, notes, seat)), source, loadproof.health_begin_matches(A.first_world(world, seat), seats, phase, notes, extra, disabled))

def loadproof.seat_nth(+seats: List<&2, D.Seat>, +index: Nat) -> {A.ref_seat_nth(seats, index) == A.machine_seat_nth(seats, index) : Maybe<&2, D.Seat>}:
  match seats index:
    case Nil{} _:
      {==}
    case seat <> rest 0n:
      {==}
    case seat <> +rest 1n+k:
      loadproof.seat_nth(rest, k)

def loadproof.seat_default(+seat: Maybe<&2, D.Seat>) -> {A.ref_seat_default(seat) == A.machine_seat_default(seat) : D.Seat}:
  match seat:
    case None{}:
      {==}
    case Some{seat}:
      {==}

def loadproof.first_seat(+table: D.Table, +value: Nat) -> {A.ref_first_seat(table, value) == A.machine_first_seat(table, value) : D.Seat}:
  found : {A.ref_first_seat(table, value) == A.ref_seat_default(A.machine_seat_nth(D.table.seats(table), value)) : D.Seat} = Equal.cong(Maybe<&2, D.Seat>, D.Seat, seat => A.ref_seat_default(seat), A.ref_seat_nth(D.table.seats(table), value), A.machine_seat_nth(D.table.seats(table), value), loadproof.seat_nth(D.table.seats(table), value))
  Equal.trans(D.Seat, A.ref_first_seat(table, value), A.ref_seat_default(A.machine_seat_nth(D.table.seats(table), value)), A.machine_first_seat(table, value), found, loadproof.seat_default(A.machine_seat_nth(D.table.seats(table), value)))

def loadproof.first_range(+table: D.Table) -> {A.ref_first_range(table) == A.machine_first_range(table) : D.Range}:
  match table:
    case D.TwoSeats{}:
      {==}
    case D.ThreeSeats{}:
      {==}
    case D.FourSeats{}:
      {==}


def loadproof.first_answer_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +notes: List<&2, D.Note>, +n: Nat, disabled: {A.items_disabled(A.current_items(A.first_answer_world(world, seats, n), seats)) == True{} : Bool}) -> {A.ref_answer(A.ref(A.first_state(A.world_for(world, seats), seats, notes)), n) == A.first_answer(A.world_for(world, seats), seats, notes, n) : A.RefStep()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      +w : S.World = A.world_for(world, seats)
      +table : D.Table = S.world.table(w)
      +value : Nat = A.first_value(w, n)
      +seat : D.Seat = A.machine_first_seat(table, value)
      +after : S.State = A.machine_first_chosen(w, seats, S.NeedFirst{}, Nil{}, seat)
      +raw_answer : A.RefStep() = A.ref_answer(A.raw_state(w, seats, S.NeedFirst{}, notes), n)
      +range_answer : A.RefStep() = A.ref_first_answer_range(w, seats, notes, n, A.machine_first_range(table))
      +chosen_answer : A.RefStep() = A.ref_stepped(A.ref_first_chosen(96n, w, seats, seat, Nil{}))
      +mapped_answer : A.RefStep() = A.ref_stepped(A.ref(after))
      input : {A.ref_answer(A.ref(A.first_state(w, seats, notes)), n) == raw_answer : A.RefStep()} = Equal.cong(A.Seats(), A.RefStep(), restored => A.ref_answer(A.raw_state(w, restored, S.NeedFirst{}, notes), n), seats, seats, {==})
      range : {raw_answer == range_answer : A.RefStep()} = Equal.cong(D.Range, A.RefStep(), range => A.ref_first_answer_range(w, seats, notes, n, range), A.ref_first_range(table), A.machine_first_range(table), loadproof.first_range(table))
      chosen : {range_answer == chosen_answer : A.RefStep()} = Equal.cong(D.Seat, A.RefStep(), seat => A.ref_stepped(A.ref_first_chosen(96n, w, seats, seat, Nil{})), A.ref_first_seat(table, value), seat, loadproof.first_seat(table, value))
      closed : {chosen_answer == mapped_answer : A.RefStep()} = Equal.cong(A.Ref(), A.RefStep(), state => A.ref_stepped(state), A.ref_first_chosen(96n, w, seats, seat, Nil{}), A.ref(after), loadproof.first_chosen_matches(world, seats, S.NeedFirst{}, Nil{}, seat, 77n, disabled))
      tail : {chosen_answer == A.first_answer(w, seats, notes, n) : A.RefStep()} = Equal.trans(A.RefStep(), chosen_answer, mapped_answer, A.first_answer(w, seats, notes, n), closed, loadproof.step_ref_commutes(after))
      middle : {range_answer == A.first_answer(w, seats, notes, n) : A.RefStep()} = Equal.trans(A.RefStep(), range_answer, chosen_answer, A.first_answer(w, seats, notes, n), chosen, tail)
      head : {raw_answer == A.first_answer(w, seats, notes, n) : A.RefStep()} = Equal.trans(A.RefStep(), raw_answer, range_answer, A.first_answer(w, seats, notes, n), range, middle)
      Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.first_state(w, seats, notes)), n), raw_answer, A.first_answer(w, seats, notes, n), input, head)

def bounded_fields(+before: Nat, +after: Nat, +before_config: D.Config, +after_config: D.Config, index_eq: {after == before : Nat}, config_eq: {after_config == before_config : D.Config}, bounded: {Nat.is_lt(before, D.plan.length(A.preserve.plan(before_config))) == True{} : Bool}) -> {Nat.is_lt(after, D.plan.length(A.preserve.plan(after_config))) == True{} : Bool}:
  Equal.trans(Bool, Nat.is_lt(after, D.plan.length(A.preserve.plan(after_config))), Nat.is_lt(before, D.plan.length(A.preserve.plan(after_config))), True{}, Equal.cong(Nat, Bool, index => Nat.is_lt(index, D.plan.length(A.preserve.plan(after_config))), after, before, index_eq), Equal.trans(Bool, Nat.is_lt(before, D.plan.length(A.preserve.plan(after_config))), Nat.is_lt(before, D.plan.length(A.preserve.plan(before_config))), True{}, Equal.cong(D.Config, Bool, config => Nat.is_lt(before, D.plan.length(A.preserve.plan(config))), after_config, before_config, config_eq), bounded))

def stable_fields(+before: S.World, +after: S.World, +seats: A.Seats(), +config_eq: {S.world.config(after) == S.world.config(before) : D.Config}, index_eq: {S.world.round_index(after) == S.world.round_index(before) : Nat}, stable: A.Stable(before, seats)) -> A.Stable(after, seats):
  match before after:
    case S.World{D.Config{bt, bp}, bb, br, bi, bf, bh, ba, bu, bd, be, bc, bm, bs, bg, bl, bk} S.World{D.Config{at, ap}, ab, ar, ai, af, ah, aa, au, ad, ae, ac, am, ass, ag, al, ak}:
      match stable:
        case Tuple{world_eq, Tuple{supported, bounded}}:
          (GrantProof.world_for_identity(after, seats, Equal.trans(D.Table, at, bt, D.ring.table(A.CoreSeat, seats), Equal.cong(D.Config, D.Table, config => Q.config.table(config), D.Config{at, ap}, D.Config{bt, bp}, config_eq), Equal.sym(D.Table, D.ring.table(A.CoreSeat, seats), bt, Equal.cong(S.World, D.Table, w => S.world.table(w), A.world_for(before, seats), before, world_eq)))), (Equal.trans(Bool, Q.config.no_items(D.Config{at, ap}), Q.config.no_items(D.Config{bt, bp}), True{}, Equal.cong(D.Config, Bool, config => Q.config.no_items(config), D.Config{at, ap}, D.Config{bt, bp}, config_eq), supported), bounded_fields(br, ar, D.Config{bt, bp}, D.Config{at, ap}, index_eq, config_eq, bounded)))

def stable_hidden(+world: S.World, +seats: A.Seats(), +load: D.Load, +shells: List<&2, D.Shell>, stable: A.Stable(world, seats)) -> A.Stable(S.world.set_shown(S.world.set_gun(world, shells), load), seats):
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      stable_fields(world, S.world.set_shown(S.world.set_gun(world, shells), load), seats, {==}, {==}, stable)

def stable_deck(+world: S.World, +seats: A.Seats(), +deck: List<&2, S.Batch>, stable: A.Stable(world, seats)) -> A.Stable(S.world.set_deck(world, deck), seats):
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, old}:
      stable_fields(world, S.world.set_deck(world, deck), seats, {==}, {==}, stable)

def shuffle_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +load: D.Load, +shells: List<&2, D.Shell>, i: Nat, stable: A.Stable(world, seats)) -> A.Valid(M.shuffle(A.pack(world, seats, phase, notes), load, shells, i)):
  match i:
    case 0n:
      grant_valid(Q.jam_rank(A.players.free(seats)), S.world.set_shown(S.world.set_gun(world, shells), load), seats, phase, List.append(&2, D.Note, notes, [D.Shown{D.Loaded{load}}]), S.world.first_turn(S.world.set_shown(S.world.set_gun(world, shells), load)), stable_hidden(world, seats, load, shells, stable))
    case 1n+rest:
      pack_valid(world, seats, S.NeedSwap{load, shells, 1n+rest}, notes, stable, {==}, {==})

def batch_found_valid(+selected: Maybe<&2, S.Batch>, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +index: Nat, stable: A.Stable(world, seats)) -> A.Valid(M.batch.found(A.pack(world, seats, phase, notes), index, selected)):
  match selected:
    case None{}:
      pack_valid(world, seats, S.Blocked{}, notes, stable, {==}, {==})
    case Some{S.Batch{id, +sampled}}:
      +load : D.Load = Q.load.actual(Q.world.load_rule(world), sampled)
      +shells : List<&2, D.Shell> = Q.load.shells(load)
      +deck : List<&2, S.Batch> = Q.remove(S.Batch, S.world.deck(world), index)
      shuffle_valid(S.world.set_deck(world, deck), seats, phase, notes, load, shells, Q.predecessor(List.length(&2, D.Shell, shells)), stable_deck(world, seats, deck, stable))

def batch_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +index: Nat, stable: A.Stable(world, seats)) -> A.Valid(M.batch(A.pack(world, seats, phase, notes), index)):
  batch_found_valid(Q.nth(S.Batch, S.world.deck(world), index), world, seats, phase, notes, index, stable)

def stable_from_valid(+world: S.World, +players: S.Players, +phase: S.Phase, +notes: A.Notes(), +grabs: S.Grabs, valid: A.Valid(S.State{world, players, phase, notes, grabs})) -> A.Stable(world, A.core(players)):
  match valid:
    case Tuple{normal, Tuple{supported, Tuple{bounded, ready}}}:
      (Equal.cong(S.State, S.World, state => S.state.world(state), A.normalize(S.State{world, players, phase, notes, grabs}), S.State{world, players, phase, notes, grabs}, normal), (supported, bounded))

def players_from_valid(+world: S.World, +players: S.Players, +phase: S.Phase, +notes: A.Notes(), +grabs: S.Grabs, valid: A.Valid(S.State{world, players, phase, notes, grabs})) -> {A.players.free(A.core(players)) == players : S.Players}:
  match valid:
    case Tuple{normal, rest}:
      Equal.cong(S.State, S.Players, state => S.state.players(state), A.normalize(S.State{world, players, phase, notes, grabs}), S.State{world, players, phase, notes, grabs}, normal)

def grabs_from_valid(+world: S.World, +players: S.Players, +phase: S.Phase, +notes: A.Notes(), +grabs: S.Grabs, valid: A.Valid(S.State{world, players, phase, notes, grabs})) -> {A.grabs(A.core(players)) == grabs : S.Grabs}:
  match valid:
    case Tuple{normal, rest}:
      Equal.cong(S.State, S.Grabs, state => S.state.grabs(state), A.normalize(S.State{world, players, phase, notes, grabs}), S.State{world, players, phase, notes, grabs}, normal)

def input_pack(+world: S.World, +players: S.Players, +phase: S.Phase, +notes: A.Notes(), +grabs: S.Grabs, +valid: A.Valid(S.State{world, players, phase, notes, grabs})) -> {A.pack(world, A.core(players), phase, notes) == S.State{world, players, phase, notes, grabs} : S.State}:
  Equal.trans(S.State, A.pack(world, A.core(players), phase, notes), S.State{world, players, phase, notes, A.grabs(A.core(players))}, S.State{world, players, phase, notes, grabs}, Equal.cong(S.Players, S.State, ps => S.State{world, ps, phase, notes, A.grabs(A.core(players))}, A.players.free(A.core(players)), players, players_from_valid(world, players, phase, notes, grabs, valid)), Equal.cong(S.Grabs, S.State, g => S.State{world, players, phase, notes, g}, A.grabs(A.core(players)), grabs, grabs_from_valid(world, players, phase, notes, grabs, valid)))

def batch_resolved_valid(resolved: D.Resolved, +world: S.World, +seats: A.Seats(), stable: A.Stable(world, seats)) -> A.Valid(M.answer.resolved(A.pack(world, seats, S.NeedBatch{}, Nil{}), resolved)):
  match resolved:
    case D.Drawn{value}:
      batch_valid(world, seats, S.NeedBatch{}, Nil{}, value, stable)
    case D.Chose{choice}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})
    case D.Unanswerable{}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})

def swap_resolved_valid(resolved: D.Resolved, +world: S.World, +seats: A.Seats(), +load: D.Load, +shells: List<&2, D.Shell>, +i: Nat, stable: A.Stable(world, seats)) -> A.Valid(M.answer.resolved(A.pack(world, seats, S.NeedSwap{load, shells, 1n+i}, Nil{}), resolved)):
  match resolved:
    case D.Drawn{value}:
      shuffle_valid(world, seats, S.NeedSwap{load, shells, 1n+i}, Nil{}, load, Q.swap(shells, 1n+i, value), Q.predecessor(1n+i), stable)
    case D.Chose{choice}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})
    case D.Unanswerable{}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})

def stepped_state(+step: D.Stepped<&2, S.State>) -> {A.machine_step_state(step) == M.stepped.state(step) : S.State}:
  match step:
    case D.Stepped{state, notes}:
      {==}

def answer_batch_request_valid(request: D.Request, +world: S.World, +seats: A.Seats(), +notes: A.Notes(), +n: Nat, stable: A.Stable(world, seats)) -> A.Valid(A.machine_step_state(M.answer.request(A.pack(world, seats, S.NeedBatch{}, notes), n, request))):
  match request:
    case D.Finished{}:
      pack_valid(world, seats, S.NeedBatch{}, notes, stable, {==}, {==})
    case D.Stuck{}:
      pack_valid(world, seats, S.NeedBatch{}, notes, stable, {==}, {==})
    case D.Draw{kind, range}:
      batch_resolved_valid(D.resolve(request, n), world, seats, stable)
    case D.Choose{menus}:
      batch_resolved_valid(D.resolve(request, n), world, seats, stable)

def answer_swap_request_valid(request: D.Request, +world: S.World, +seats: A.Seats(), +load: D.Load, +shells: List<&2, D.Shell>, +i: Nat, +notes: A.Notes(), +n: Nat, stable: A.Stable(world, seats)) -> A.Valid(A.machine_step_state(M.answer.request(A.pack(world, seats, S.NeedSwap{load, shells, 1n+i}, notes), n, request))):
  match request:
    case D.Finished{}:
      pack_valid(world, seats, S.NeedSwap{load, shells, 1n+i}, notes, stable, {==}, {==})
    case D.Stuck{}:
      pack_valid(world, seats, S.NeedSwap{load, shells, 1n+i}, notes, stable, {==}, {==})
    case D.Draw{kind, range}:
      swap_resolved_valid(D.resolve(request, n), world, seats, load, shells, i, stable)
    case D.Choose{menus}:
      swap_resolved_valid(D.resolve(request, n), world, seats, load, shells, i, stable)

def answer_batch_valid(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedBatch{}, notes, grabs})) -> A.Valid(A.next(S.State{world, players, S.NeedBatch{}, notes, grabs}, n)):
  %input_pack(world, players, S.NeedBatch{}, notes, grabs, valid) : A.Valid(A.next(_, n))
  answer_batch_request_valid(M.request(A.pack(world, A.core(players), S.NeedBatch{}, notes)), world, A.core(players), notes, n, stable_from_valid(world, players, S.NeedBatch{}, notes, grabs, valid))

def answer_swap_valid(+world: S.World, +players: S.Players, +load: D.Load, +shells: List<&2, D.Shell>, +i: Nat, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedSwap{load, shells, 1n+i}, notes, grabs})) -> A.Valid(A.next(S.State{world, players, S.NeedSwap{load, shells, 1n+i}, notes, grabs}, n)):
  %input_pack(world, players, S.NeedSwap{load, shells, 1n+i}, notes, grabs, valid) : A.Valid(A.next(_, n))
  answer_swap_request_valid(M.request(A.pack(world, A.core(players), S.NeedSwap{load, shells, 1n+i}, notes)), world, A.core(players), load, shells, i, notes, n, stable_from_valid(world, players, S.NeedSwap{load, shells, 1n+i}, notes, grabs, valid))

def load_ready_valid(+deck: List<&2, S.Batch>, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats)) -> A.Valid(M.load.ready(A.pack(world, seats, phase, notes), deck)):
  match deck:
    case Nil{}:
      pack_valid(world, seats, S.Blocked{}, notes, stable, {==}, {==})
    case only <> Nil{}:
      batch_valid(world, seats, phase, notes, 0n, stable)
    case a <> b <> rest:
      pack_valid(world, seats, S.NeedBatch{}, notes, stable, {==}, {==})

def stable_refill(+world: S.World, +seats: A.Seats(), stable: A.Stable(world, seats)) -> A.Stable(S.world.set_decks(world, Q.decks.full()), seats):
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      stable_fields(world, S.world.set_decks(world, Q.decks.full()), seats, {==}, {==}, stable)

def load_refill_valid(+deck: List<&2, S.Batch>, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats)) -> A.Valid(M.load.refill(A.pack(world, seats, phase, notes), deck)):
  match deck:
    case Nil{}:
      load_ready_valid(S.world.deck(S.world.set_decks(world, Q.decks.full())), S.world.set_decks(world, Q.decks.full()), seats, phase, notes, stable_refill(world, seats, stable))
    case a <> rest:
      load_ready_valid(deck, world, seats, phase, notes, stable)

def stable_load(+world: S.World, +seats: A.Seats(), stable: A.Stable(world, seats)) -> A.Stable(A.preserve.load_world(world), seats):
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      stable_fields(world, A.preserve.load_world(world), seats, {==}, {==}, stable)

def load_begin_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats)) -> A.Valid(M.load.begin(A.pack(world, seats, phase, notes))):
  load_refill_valid(S.world.deck(A.preserve.load_world(world)), A.preserve.load_world(world), seats, phase, notes, stable_load(world, seats, stable))

def reset_pack_load(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes()) -> {M.load.begin(A.reset.state(A.pack(A.world_for(world, seats), seats, phase, notes))) == M.load.begin(A.pack(A.preserve.reset_world(A.world_for(world, seats)), A.preserve.reset_seats(seats, S.world.round_health(A.world_for(world, seats))), phase, A.preserve.reset_notes(A.world_for(world, seats), notes))) : S.State}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          {==}

def reset_pack_synced(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +disabled: {Q.items.disabled(I.round.items(Q.world.rules(A.world_for(world, seats)))) == True{} : Bool}) -> {M.round.reset(A.pack(A.world_for(world, seats), seats, phase, notes)) == M.load.begin(A.pack(A.preserve.reset_world(A.world_for(world, seats)), A.preserve.reset_seats(seats, S.world.round_health(A.world_for(world, seats))), phase, A.preserve.reset_notes(A.world_for(world, seats), notes))) : S.State}:
  Equal.trans(S.State, M.round.reset(A.pack(A.world_for(world, seats), seats, phase, notes)), M.load.begin(A.reset.state(A.pack(A.world_for(world, seats), seats, phase, notes))), M.load.begin(A.pack(A.preserve.reset_world(A.world_for(world, seats)), A.preserve.reset_seats(seats, S.world.round_health(A.world_for(world, seats))), phase, A.preserve.reset_notes(A.world_for(world, seats), notes))), noitems.reset_skip(A.pack(A.world_for(world, seats), seats, phase, notes), disabled), reset_pack_load(world, seats, phase, notes))

def reset_pack(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +eq: {A.world_for(world, seats) == world : S.World}, disabled: {Q.items.disabled(I.round.items(Q.world.rules(world))) == True{} : Bool}) -> {M.round.reset(A.pack(world, seats, phase, notes)) == M.load.begin(A.pack(A.preserve.reset_world(world), A.preserve.reset_seats(seats, S.world.round_health(world)), phase, A.preserve.reset_notes(world, notes))) : S.State}:
  %eq : {M.round.reset(A.pack(_, seats, phase, notes)) == M.load.begin(A.pack(A.preserve.reset_world(_), A.preserve.reset_seats(seats, S.world.round_health(_)), phase, A.preserve.reset_notes(_, notes))) : S.State}
  reset_pack_synced(world, seats, phase, notes, Equal.trans(Bool, Q.items.disabled(I.round.items(Q.world.rules(A.world_for(world, seats)))), Q.items.disabled(I.round.items(Q.world.rules(world))), True{}, Equal.cong(S.World, Bool, w => Q.items.disabled(I.round.items(Q.world.rules(w))), A.world_for(world, seats), world, eq), disabled))

def reset_shape(+seats: A.Seats(), +hp: Nat) -> {D.ring.table(A.CoreSeat, A.preserve.reset_seats(seats, hp)) == D.ring.table(A.CoreSeat, seats) : D.Table}:
  match seats:
    case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      {==}
    case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
      {==}
    case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
      {==}

def stable_reset_world(+world: S.World, +seats: A.Seats(), stable: A.Stable(world, seats)) -> A.Stable(A.preserve.reset_world(world), seats):
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      stable_fields(world, A.preserve.reset_world(world), seats, {==}, {==}, stable)

def reset_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +stable: A.Stable(world, seats)) -> A.Valid(M.round.reset(A.pack(world, seats, phase, notes))):
  match stable:
    case Tuple{world_eq, Tuple{supported, bounded}}:
      %Equal.sym(S.State, M.round.reset(A.pack(world, seats, phase, notes)), M.load.begin(A.pack(A.preserve.reset_world(world), A.preserve.reset_seats(seats, S.world.round_health(world)), phase, A.preserve.reset_notes(world, notes))), reset_pack(world, seats, phase, notes, world_eq, noitems.machine_disabled(world, seats, SupportProof.current_disabled(world, seats, supported, bounded)))) : A.Valid(_)
      load_begin_valid(A.preserve.reset_world(world), A.preserve.reset_seats(seats, S.world.round_health(world)), phase, A.preserve.reset_notes(world, notes), stable_shape(A.preserve.reset_world(world), seats, A.preserve.reset_seats(seats, S.world.round_health(world)), reset_shape(seats, S.world.round_health(world)), stable_reset_world(world, seats, stable)))

def stable_amount(+world: S.World, +seats: A.Seats(), +amount: Nat, stable: A.Stable(world, seats)) -> A.Stable(S.world.set_item_amount(world, amount), seats):
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, old, saw, gun, shown, deck}:
      stable_fields(world, S.world.set_item_amount(world, amount), seats, {==}, {==}, stable)

def amount_chosen_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +amount: Nat, stable: A.Stable(world, seats)) -> A.Valid(M.amount.chosen(A.pack(world, seats, phase, notes), amount)):
  reset_valid(S.world.set_item_amount(world, amount), seats, phase, notes, stable_amount(world, seats, amount, stable))

def amount_rule_valid(rule: D.AmountRule, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats)) -> A.Valid(M.amount.rule(A.pack(world, seats, phase, notes), rule)):
  match rule:
    case D.RandomAmount{}:
      pack_valid(world, seats, S.NeedAmount{}, notes, stable, {==}, {==})
    case D.FixedAmount{amount}:
      amount_chosen_valid(world, seats, phase, notes, amount, stable)

def amount_begin_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats)) -> A.Valid(M.amount.begin(A.pack(world, seats, phase, notes))):
  amount_rule_valid(Q.load.amount(Q.world.load_rule(world)), world, seats, phase, notes, stable)

def stable_health(+world: S.World, +seats: A.Seats(), +health: Nat, stable: A.Stable(world, seats)) -> A.Stable(S.world.set_round_health(world, health), seats):
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      stable_fields(world, S.world.set_round_health(world, health), seats, {==}, {==}, stable)

def health_chosen_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +health: Nat, stable: A.Stable(world, seats)) -> A.Valid(M.health.chosen(A.pack(world, seats, phase, notes), health)):
  amount_begin_valid(S.world.set_round_health(world, health), seats, phase, notes, stable_health(world, seats, health, stable))

def health_rule_valid(rule: D.HealthRule, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats)) -> A.Valid(M.health.rule(A.pack(world, seats, phase, notes), rule)):
  match rule:
    case D.RandomHealth{}:
      pack_valid(world, seats, S.NeedHealth{}, notes, stable, {==}, {==})
    case D.FixedHealth{health}:
      health_chosen_valid(world, seats, phase, notes, D.pos.nat(health), stable)

def health_begin_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats)) -> A.Valid(M.health.begin(A.pack(world, seats, phase, notes))):
  health_rule_valid(Q.round.health(Q.world.rules(world)), world, seats, phase, notes, stable)

def stable_first(+world: S.World, +seats: A.Seats(), +seat: D.Seat, stable: A.Stable(world, seats), ready: {A.round_ready(S.NeedFirst{}, world) == True{} : Bool}) -> A.Stable(A.preserve.first_world(world, seat), seats):
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match stable:
        case Tuple{world_eq, Tuple{supported, bounded}}:
          (Equal.cong(S.World, S.World, w => A.preserve.first_world(w, seat), A.world_for(world, seats), world, world_eq), (supported, ready))

def first_chosen_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +seat: D.Seat, stable: A.Stable(world, seats), ready: {A.round_ready(S.NeedFirst{}, world) == True{} : Bool}) -> A.Valid(M.first.chosen(A.pack(world, seats, phase, notes), seat)):
  health_begin_valid(A.preserve.first_world(world, seat), seats, phase, notes, stable_first(world, seats, seat, stable, ready))

def setup_canonical(phase: A.SetupPhase, +seats: A.Seats()) -> {A.canonical_phase(A.preserve.phase(phase), seats) == A.preserve.phase(phase) : S.Phase}:
  match phase:
    case A.SetupFirst{}:
      {==}
    case A.SetupHealth{}:
      {==}
    case A.SetupAmount{}:
      {==}

def setup_resolved_valid(phase: A.SetupPhase, resolved: D.Resolved, +world: S.World, +seats: A.Seats(), stable: A.Stable(world, seats), ready: {A.round_ready(A.preserve.phase(phase), world) == True{} : Bool}) -> A.Valid(M.answer.resolved(A.pack(world, seats, A.preserve.phase(phase), Nil{}), resolved)):
  match phase resolved:
    case A.SetupFirst{} D.Drawn{value}:
      first_chosen_valid(world, seats, S.NeedFirst{}, Nil{}, Q.value.or(D.Seat, Q.nth(D.Seat, D.table.seats(S.world.table(world)), value), D.Seat0{}), stable, ready)
    case A.SetupHealth{} D.Drawn{value}:
      health_chosen_valid(world, seats, S.NeedHealth{}, Nil{}, value, stable)
    case A.SetupAmount{} D.Drawn{value}:
      amount_chosen_valid(world, seats, S.NeedAmount{}, Nil{}, value, stable)
    case A.SetupFirst{} D.Chose{choice}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})
    case A.SetupHealth{} D.Chose{choice}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})
    case A.SetupAmount{} D.Chose{choice}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})
    case A.SetupFirst{} D.Unanswerable{}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})
    case A.SetupHealth{} D.Unanswerable{}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})
    case A.SetupAmount{} D.Unanswerable{}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})

def setup_answer_request_valid(+phase: A.SetupPhase, request: D.Request, +world: S.World, +seats: A.Seats(), +notes: A.Notes(), +n: Nat, stable: A.Stable(world, seats), ready: {A.round_ready(A.preserve.phase(phase), world) == True{} : Bool}) -> A.Valid(A.machine_step_state(M.answer.request(A.pack(world, seats, A.preserve.phase(phase), notes), n, request))):
  match request:
    case D.Finished{}:
      pack_valid(world, seats, A.preserve.phase(phase), notes, stable, setup_canonical(phase, seats), ready)
    case D.Stuck{}:
      pack_valid(world, seats, A.preserve.phase(phase), notes, stable, setup_canonical(phase, seats), ready)
    case D.Draw{kind, range}:
      setup_resolved_valid(phase, D.resolve(request, n), world, seats, stable, ready)
    case D.Choose{menus}:
      setup_resolved_valid(phase, D.resolve(request, n), world, seats, stable, ready)

def valid_ready(+world: S.World, +players: S.Players, +phase: S.Phase, +notes: A.Notes(), +grabs: S.Grabs, valid: A.Valid(S.State{world, players, phase, notes, grabs})) -> {A.round_ready(phase, world) == True{} : Bool}:
  match valid:
    case Tuple{normal, Tuple{supported, Tuple{bounded, ready}}}:
      ready

def setup_answer_valid(+phase: A.SetupPhase, +world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, A.preserve.phase(phase), notes, grabs})) -> A.Valid(A.next(S.State{world, players, A.preserve.phase(phase), notes, grabs}, n)):
  %input_pack(world, players, A.preserve.phase(phase), notes, grabs, valid) : A.Valid(A.next(_, n))
  setup_answer_request_valid(phase, M.request(A.pack(world, A.core(players), A.preserve.phase(phase), notes)), world, A.core(players), notes, n, stable_from_valid(world, players, A.preserve.phase(phase), notes, grabs, valid), valid_ready(world, players, A.preserve.phase(phase), notes, grabs, valid))

def answer_first_valid(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedFirst{}, notes, grabs})) -> A.Valid(A.next(S.State{world, players, S.NeedFirst{}, notes, grabs}, n)):
  setup_answer_valid(A.SetupFirst{}, world, players, notes, grabs, n, valid)

def answer_health_valid(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedHealth{}, notes, grabs})) -> A.Valid(A.next(S.State{world, players, S.NeedHealth{}, notes, grabs}, n)):
  setup_answer_valid(A.SetupHealth{}, world, players, notes, grabs, n, valid)

def answer_amount_valid(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedAmount{}, notes, grabs})) -> A.Valid(A.next(S.State{world, players, S.NeedAmount{}, notes, grabs}, n)):
  setup_answer_valid(A.SetupAmount{}, world, players, notes, grabs, n, valid)

def plan_nonempty(plan: D.Plan) -> {Nat.is_lt(0n, D.plan.length(plan)) == True{} : Bool}:
  match plan:
    case D.OneRound{a}:
      {==}
    case D.TwoRounds{a, b}:
      {==}
    case D.ThreeRounds{a, b, c}:
      {==}

def initial_normal(+config: D.Config) -> {A.normalize(M.initial(config)) == M.initial(config) : S.State}:
  match config:
    case D.Config{D.TwoSeats{}, plan}:
      {==}
    case D.Config{D.ThreeSeats{}, plan}:
      {==}
    case D.Config{D.FourSeats{}, plan}:
      {==}

def initial_valid(+config: D.Config, supported: {Q.config.no_items(config) == True{} : Bool}) -> A.Valid(M.initial(config)):
  match config:
    case D.Config{table, +plan}:
      (initial_normal(config), (supported, (plan_nonempty(plan), plan_nonempty(plan))))

def start_valid(+config: D.Config, +supported: {Q.config.no_items(config) == True{} : Bool}) -> A.Valid(A.machine_step_state(M.start(config))):
  match config:
    case D.Config{table, plan}:
      initial_valid(config, supported)

def point_stepped(+step: D.Stepped<&2, S.State>) -> {A.point_of_ref(A.machine_step_state(step)) == A.ref_step_point(A.stepped(step)) : D.Point}:
  match step:
    case D.Stepped{state, notes}:
      {==}

def simulation_build(+state: S.State, +n: Nat, +result: {A.ref_answer(A.ref(state), n) == A.stepped(M.answer(state, n)) : A.RefStep()}, +valid: A.Valid(A.next(state, n))) -> A.Simulation(state, n):
  (result, (Equal.trans(D.Point, A.machine_point(A.next(state, n)), A.point_of_ref(A.next(state, n)), A.ref_step_point(A.ref_answer(A.ref(state), n)), point.valid(A.next(state, n), valid), Equal.trans(D.Point, A.point_of_ref(A.next(state, n)), A.ref_step_point(A.stepped(M.answer(state, n))), A.ref_step_point(A.ref_answer(A.ref(state), n)), point_stepped(M.answer(state, n)), Equal.cong(A.RefStep(), D.Point, A.ref_step_point, A.stepped(M.answer(state, n)), A.ref_answer(A.ref(state), n), Equal.sym(A.RefStep(), A.ref_answer(A.ref(state), n), A.stepped(M.answer(state, n)), result)))), valid))

def first_override_valid(first_death: Maybe<&2, D.Seat>, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats), ready: {A.round_ready(S.NeedFirst{}, world) == True{} : Bool}) -> A.Valid(M.first.override(A.pack(world, seats, phase, notes), first_death)):
  match first_death:
    case None{}:
      pack_valid(world, seats, S.NeedFirst{}, notes, stable, {==}, ready)
    case Some{seat}:
      first_chosen_valid(world, seats, phase, notes, seat, stable, ready)


def first_begin_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), stable: A.Stable(world, seats), ready: {A.round_ready(S.NeedFirst{}, world) == True{} : Bool}) -> A.Valid(M.first.begin(A.pack(world, seats, phase, notes))):
  first_override_valid(S.world.first_death(world), world, seats, phase, notes, stable, ready)

def idleproof.idle_machine_guard(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +allowed: Bool) -> {S.state.stepped(M.answer.idle(A.idle(world, seats, seat, Nil{}), seat, D.NonEmpty{S.TakeGun{}, Nil{}}, 0n, allowed)) == A.idle.expected(world, seats, seat, allowed) : D.Stepped<&2, S.State>}:
  match allowed:
    case False{}:
      {==}
    case True{}:
      {==}

def idleproof.idle_machine_present(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes(), +n: Nat, +present: A.seated(world, seat)) -> {M.answer(A.idle(world, seats, seat, notes), n) == A.idle.expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)) : D.Stepped<&2, S.State>}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %Equal.sym(D.Request, P.pickup_request(table, seat), D.Choose{D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}])}, P.pickup_request_choose(table, seat, present)) : {M.answer.request(A.idle(world, seats, seat, notes), n, _) == A.idle.expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)) : D.Stepped<&2, S.State>}
      %P.pickup_choose_resolved_backwards(table, seat, n, present) : {S.state.stepped(M.answer.resolved(S.state.set_notes(A.idle(world, seats, seat, notes), Nil{}), _)) == A.idle.expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)) : D.Stepped<&2, S.State>}
      %P.seat_self_backwards(seat) : {S.state.stepped(M.answer.idle(A.idle(world, seats, seat, Nil{}), seat, D.NonEmpty{S.TakeGun{}, Nil{}}, 0n, Bool.and(_, A.idle.machine_guard(world, seats, seat)))) == A.idle.expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)) : D.Stepped<&2, S.State>}
      idleproof.idle_machine_guard(world, seats, seat, A.idle.machine_guard(world, seats, seat))

def idleproof.idle_permission(+world: S.World, +seats: A.Seats(), +seat: D.Seat) -> {A.idle.permission(world, seats, seat) == Q.value.or(Bool, D.ring.get(Bool, S.players.has_turn(A.players.free(seats)), seat), False{}) : Bool}:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
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

def idleproof.idle_current(+world: S.World, +seat: D.Seat) -> {A.idle.current(world, seat) == Q.current(S.world.turn(world), seat) : Bool}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, +turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match turn:
        case None{}:
          {==}
        case Some{current}:
          {==}

def idleproof.and_true(+value: Bool) -> {Bool.and(value, True{}) == value : Bool}:
  match value:
    case False{}:
      {==}
    case True{}:
      {==}

def idleproof.idle_guards(+world: S.World, +seats: A.Seats(), +seat: D.Seat) -> {A.raw_accepted(world, seats, seat) == A.idle.machine_guard(world, seats, seat) : Bool}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      Equal.trans(Bool, A.raw_accepted(world, seats, seat), Bool.and(A.idle.current(world, seat), A.idle.permission(world, seats, seat)), A.idle.machine_guard(world, seats, seat), Equal.cong(Bool, Bool, permission => Bool.and(A.idle.current(world, seat), permission), Bool.and(A.idle.permission(world, seats, seat), True{}), A.idle.permission(world, seats, seat), idleproof.and_true(A.idle.permission(world, seats, seat))), Equal.trans(Bool, Bool.and(A.idle.current(world, seat), A.idle.permission(world, seats, seat)), Bool.and(Q.current(S.world.turn(world), seat), A.idle.permission(world, seats, seat)), A.idle.machine_guard(world, seats, seat), Equal.cong(Bool, Bool, current => Bool.and(current, A.idle.permission(world, seats, seat)), A.idle.current(world, seat), Q.current(S.world.turn(world), seat), idleproof.idle_current(world, seat)), Equal.cong(Bool, Bool, permission => Bool.and(Q.current(S.world.turn(world), seat), permission), A.idle.permission(world, seats, seat), Q.value.or(Bool, D.ring.get(Bool, S.players.has_turn(A.players.free(seats)), seat), False{}), idleproof.idle_permission(world, seats, seat))))

def idleproof.idle_ref_guard(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +allowed: Bool) -> {A.ref_idle_accepting(world, seats, seat, allowed) == A.idle.ref_expected(world, seats, seat, allowed) : A.RefStep()}:
  match allowed:
    case False{}:
      {==}
    case True{}:
      {==}

def idleproof.idle_ref_present(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes(), +n: Nat, +present: A.seated(world, seat)) -> {A.ref_answer(A.ref_idle_choose(world, seats, seat, notes), n) == A.idle.ref_expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)) : A.RefStep()}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %P.pickup_choose_resolved_backwards(table, seat, n, present) : {A.ref_idle_resolved(world, seats, seat, _) == A.idle.ref_expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)) : A.RefStep()}
      Equal.trans(A.RefStep(), A.ref_idle_accepting(world, seats, seat, A.raw_accepted(world, seats, seat)), A.ref_idle_accepting(world, seats, seat, A.idle.machine_guard(world, seats, seat)), A.idle.ref_expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)), Equal.cong(Bool, A.RefStep(), guard => A.ref_idle_accepting(world, seats, seat, guard), A.raw_accepted(world, seats, seat), A.idle.machine_guard(world, seats, seat), idleproof.idle_guards(world, seats, seat)), idleproof.idle_ref_guard(world, seats, seat, A.idle.machine_guard(world, seats, seat)))

def idleproof.idle_expected_bridge(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +allowed: Bool) -> {A.idle.ref_expected(world, seats, seat, allowed) == A.stepped(A.idle.expected(world, seats, seat, allowed)) : A.RefStep()}:
  match world allowed:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} False{}:
      Equal.cong(A.Seats(), A.RefStep(), restored => A.idle.ref_expected(world, restored, seat, False{}), seats, seats, {==})
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} True{}:
      Equal.cong(A.Seats(), A.RefStep(), restored => A.idle.ref_expected(world, restored, seat, True{}), seats, seats, {==})

def idleproof.idle_present_matches(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes(), +n: Nat, +present: A.seated(world, seat)) -> {A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n) == A.stepped(M.answer(A.idle(world, seats, seat, notes), n)) : A.RefStep()}:
  Equal.trans(A.RefStep(), A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n), A.ref_answer(A.raw_idle(world, seats, seat, notes), n), A.stepped(M.answer(A.idle(world, seats, seat, notes), n)), input_roundtrip(world, seats, seat, notes, n), Equal.trans(A.RefStep(), A.ref_answer(A.raw_idle(world, seats, seat, notes), n), A.ref_answer(A.ref_idle_choose(world, seats, seat, notes), n), A.stepped(M.answer(A.idle(world, seats, seat, notes), n)), Equal.cong(A.Ref(), A.RefStep(), state => A.ref_answer(state, n), A.raw_idle(world, seats, seat, notes), A.ref_idle_choose(world, seats, seat, notes), ref_idle_canonical(world, seats, seat, notes, present)), Equal.trans(A.RefStep(), A.ref_answer(A.ref_idle_choose(world, seats, seat, notes), n), A.idle.ref_expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)), A.stepped(M.answer(A.idle(world, seats, seat, notes), n)), idleproof.idle_ref_present(world, seats, seat, notes, n, present), Equal.trans(A.RefStep(), A.idle.ref_expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)), A.stepped(A.idle.expected(world, seats, seat, A.idle.machine_guard(world, seats, seat))), A.stepped(M.answer(A.idle(world, seats, seat, notes), n)), idleproof.idle_expected_bridge(world, seats, seat, A.idle.machine_guard(world, seats, seat)), Equal.cong(D.Stepped<&2, S.State>, A.RefStep(), A.stepped, A.idle.expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)), M.answer(A.idle(world, seats, seat, notes), n), Equal.sym(D.Stepped<&2, S.State>, M.answer(A.idle(world, seats, seat, notes), n), A.idle.expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)), idleproof.idle_machine_present(world, seats, seat, notes, n, present)))))))

def idleproof.idle_all_matches(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes(), +n: Nat) -> {A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n) == A.stepped(M.answer(A.idle(world, seats, seat, notes), n)) : A.RefStep()}:
  match world seat:
    case S.World{D.Config{D.TwoSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat0{}:
      {==}
    case S.World{D.Config{D.TwoSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat1{}:
      idleproof.idle_present_matches(world, seats, seat, notes, n, Unit{})
    case S.World{D.Config{D.TwoSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat2{}:
      {==}
    case S.World{D.Config{D.TwoSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat3{}:
      idleproof.idle_present_matches(world, seats, seat, notes, n, Unit{})
    case S.World{D.Config{D.ThreeSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat0{}:
      idleproof.idle_present_matches(world, seats, seat, notes, n, Unit{})
    case S.World{D.Config{D.ThreeSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat1{}:
      idleproof.idle_present_matches(world, seats, seat, notes, n, Unit{})
    case S.World{D.Config{D.ThreeSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat2{}:
      idleproof.idle_present_matches(world, seats, seat, notes, n, Unit{})
    case S.World{D.Config{D.ThreeSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat3{}:
      {==}
    case S.World{D.Config{D.FourSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat0{}:
      idleproof.idle_present_matches(world, seats, seat, notes, n, Unit{})
    case S.World{D.Config{D.FourSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat1{}:
      idleproof.idle_present_matches(world, seats, seat, notes, n, Unit{})
    case S.World{D.Config{D.FourSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat2{}:
      idleproof.idle_present_matches(world, seats, seat, notes, n, Unit{})
    case S.World{D.Config{D.FourSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat3{}:
      idleproof.idle_present_matches(world, seats, seat, notes, n, Unit{})

def idleproof.idle_expected_valid(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +allowed: Bool, stable: A.Stable(world, seats)) -> A.Valid(A.machine_step_state(A.idle.expected(world, seats, seat, allowed))):
  match allowed:
    case False{}:
      pack_valid(world, seats, S.Blocked{}, Nil{}, stable, {==}, {==})
    case True{}:
      pack_valid(world, seats, S.Aim{seat, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, [D.Shown{D.PickedUp{seat}}], stable, {==}, {==})

def idleproof.idle_present_valid(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes(), +n: Nat, +present: A.seated(world, seat), stable: A.Stable(world, seats)) -> A.Valid(A.next(A.idle(world, seats, seat, notes), n)):
  %Equal.sym(D.Stepped<&2, S.State>, M.answer(A.idle(world, seats, seat, notes), n), A.idle.expected(world, seats, seat, A.idle.machine_guard(world, seats, seat)), idleproof.idle_machine_present(world, seats, seat, notes, n, present)) : A.Valid(A.machine_step_state(_))
  idleproof.idle_expected_valid(world, seats, seat, A.idle.machine_guard(world, seats, seat), stable)

def idleproof.idle_all_valid(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes(), +n: Nat, stable: A.Stable(world, seats)) -> A.Valid(A.next(A.idle(world, seats, seat, notes), n)):
  match world seat:
    case S.World{D.Config{D.TwoSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat0{}:
      pack_valid(world, seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes, stable, {==}, {==})
    case S.World{D.Config{D.TwoSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat1{}:
      idleproof.idle_present_valid(world, seats, seat, notes, n, Unit{}, stable)
    case S.World{D.Config{D.TwoSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat2{}:
      pack_valid(world, seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes, stable, {==}, {==})
    case S.World{D.Config{D.TwoSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat3{}:
      idleproof.idle_present_valid(world, seats, seat, notes, n, Unit{}, stable)
    case S.World{D.Config{D.ThreeSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat0{}:
      idleproof.idle_present_valid(world, seats, seat, notes, n, Unit{}, stable)
    case S.World{D.Config{D.ThreeSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat1{}:
      idleproof.idle_present_valid(world, seats, seat, notes, n, Unit{}, stable)
    case S.World{D.Config{D.ThreeSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat2{}:
      idleproof.idle_present_valid(world, seats, seat, notes, n, Unit{}, stable)
    case S.World{D.Config{D.ThreeSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat3{}:
      pack_valid(world, seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes, stable, {==}, {==})
    case S.World{D.Config{D.FourSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat0{}:
      idleproof.idle_present_valid(world, seats, seat, notes, n, Unit{}, stable)
    case S.World{D.Config{D.FourSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat1{}:
      idleproof.idle_present_valid(world, seats, seat, notes, n, Unit{}, stable)
    case S.World{D.Config{D.FourSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat2{}:
      idleproof.idle_present_valid(world, seats, seat, notes, n, Unit{}, stable)
    case S.World{D.Config{D.FourSeats{}, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck} D.Seat3{}:
      idleproof.idle_present_valid(world, seats, seat, notes, n, Unit{}, stable)

def first_supported(+world: S.World, +seats: A.Seats(), +notes: A.Notes(), +n: Nat, supported: {Q.config.no_items(S.world.config(A.world_for(world, seats))) == True{} : Bool}, ready: {A.round_ready(S.NeedFirst{}, A.world_for(world, seats)) == True{} : Bool}) -> {A.ref_answer(A.ref(A.first_state(A.world_for(world, seats), seats, notes)), n) == A.first_answer(A.world_for(world, seats), seats, notes, n) : A.RefStep()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      loadproof.first_answer_matches(world, seats, notes, n, SupportProof.current_disabled(A.first_answer_world(world, seats, n), seats, supported, ready))

def first_valid(+world: S.World, +seats: A.Seats(), +notes: A.Notes(), +n: Nat, valid: A.Valid(A.canonical_state(world, seats, S.NeedFirst{}, notes))) -> {A.ref_answer(A.ref(A.first_state(A.world_for(world, seats), seats, notes)), n) == A.first_answer(A.world_for(world, seats), seats, notes, n) : A.RefStep()}:
  match valid:
    case (structural, (supported, (bounded, ready))):
      first_supported(world, seats, notes, n, supported, ready)


def first_begin_matches(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +extra: Nat, +supported: {Q.config.no_items(S.world.config(A.world_for(world, seats))) == True{} : Bool}, +ready: {A.round_ready(S.NeedFirst{}, A.world_for(world, seats)) == True{} : Bool}) -> {A.ref_first_begin(21n+extra, A.world_for(world, seats), seats, notes) == A.ref(A.machine_first_begin(A.world_for(world, seats), seats, phase, notes)) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, +died, checking, amount, saw, gun, shown, deck}:
      match died:
        case None{}:
          loadproof.raw_state_exact(A.world_for(world, seats), seats, S.NeedFirst{}, notes)
        case Some{+seat}:
          loadproof.first_chosen_matches(world, seats, phase, notes, seat, extra, SupportProof.current_disabled(A.world_for(A.first_world(world, seat), seats), seats, supported, ready))

def start_build(+config: D.Config, +supported: {Q.config.no_items(config) == True{} : Bool}) -> A.StartSimulation(config):
  +result : {A.ref_start(config) == A.stepped(M.start(config)) : A.RefStep()} = law.start_result_matches(config, supported)
  +valid : A.Valid(A.machine_step_state(M.start(config))) = start_valid(config, supported)
  (result, (Equal.trans(D.Point, A.ref_step_point(A.ref_start(config)), A.ref_step_point(A.stepped(M.start(config))), A.machine_point(A.machine_step_state(M.start(config))), Equal.cong(A.RefStep(), D.Point, A.ref_step_point, A.ref_start(config), A.stepped(M.start(config)), result), Equal.trans(D.Point, A.ref_step_point(A.stepped(M.start(config))), A.point_of_ref(A.machine_step_state(M.start(config))), A.machine_point(A.machine_step_state(M.start(config))), Equal.sym(D.Point, A.point_of_ref(A.machine_step_state(M.start(config))), A.ref_step_point(A.stepped(M.start(config))), point_stepped(M.start(config))), Equal.sym(D.Point, A.machine_point(A.machine_step_state(M.start(config))), A.point_of_ref(A.machine_step_state(M.start(config))), point.valid(A.machine_step_state(M.start(config)), valid)))), valid))

def law.start_matches(+config: D.Config, +supported: {Q.config.no_items(config) == True{} : Bool}) -> A.StartSimulation(config):
  start_build(config, supported)

def result_original(+state: S.State, +n: Nat, +valid: A.Valid(state), result: {A.ref_answer(A.ref(A.normalize(state)), n) == A.stepped(M.answer(A.normalize(state), n)) : A.RefStep()}) -> {A.ref_answer(A.ref(state), n) == A.stepped(M.answer(state, n)) : A.RefStep()}:
  match valid:
    case Tuple{normal, rest}:
      %normal : {A.ref_answer(A.ref(_), n) == A.stepped(M.answer(_, n)) : A.RefStep()}
      result

def current_disabled_valid(+world: S.World, +players: S.Players, +phase: S.Phase, +notes: A.Notes(), +grabs: S.Grabs, valid: A.Valid(S.State{world, players, phase, notes, grabs})) -> {A.items_disabled(A.current_items(A.world_for(world, A.core(players)), A.core(players))) == True{} : Bool}:
  match valid:
    case Tuple{normal, Tuple{supported, Tuple{bounded, ready}}}:
      world_eq : {A.world_for(world, A.core(players)) == world : S.World} = Equal.cong(S.State, S.World, S.state.world, A.normalize(S.State{world, players, phase, notes, grabs}), S.State{world, players, phase, notes, grabs}, normal)
      Equal.trans(Bool, A.items_disabled(A.current_items(A.world_for(world, A.core(players)), A.core(players))), A.items_disabled(A.current_items(world, A.core(players))), True{}, Equal.cong(S.World, Bool, changed => A.items_disabled(A.current_items(changed, A.core(players))), A.world_for(world, A.core(players)), world, world_eq), SupportProof.current_disabled(world, A.core(players), supported, bounded))

def step_batch(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedBatch{}, notes, grabs})) -> A.Simulation(S.State{world, players, S.NeedBatch{}, notes, grabs}, n):
  simulation_build(S.State{world, players, S.NeedBatch{}, notes, grabs}, n, result_original(S.State{world, players, S.NeedBatch{}, notes, grabs}, n, valid, loadproof.batch_answer_matches(A.world_for(world, A.core(players)), A.core(players), notes, n)), answer_batch_valid(world, players, notes, grabs, n, valid))

def step_health(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedHealth{}, notes, grabs})) -> A.Simulation(S.State{world, players, S.NeedHealth{}, notes, grabs}, n):
  simulation_build(S.State{world, players, S.NeedHealth{}, notes, grabs}, n, result_original(S.State{world, players, S.NeedHealth{}, notes, grabs}, n, valid, loadproof.health_answer_matches(world, A.core(players), notes, n, current_disabled_valid(world, players, S.NeedHealth{}, notes, grabs, valid))), answer_health_valid(world, players, notes, grabs, n, valid))

def step_amount(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedAmount{}, notes, grabs})) -> A.Simulation(S.State{world, players, S.NeedAmount{}, notes, grabs}, n):
  simulation_build(S.State{world, players, S.NeedAmount{}, notes, grabs}, n, result_original(S.State{world, players, S.NeedAmount{}, notes, grabs}, n, valid, loadproof.amount_answer_matches(world, A.core(players), notes, n, current_disabled_valid(world, players, S.NeedAmount{}, notes, grabs, valid))), answer_amount_valid(world, players, notes, grabs, n, valid))

def step_swap_last(+world: S.World, +players: S.Players, +load: D.Load, +shells: List<&2, D.Shell>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedSwap{load, shells, 1n}, notes, grabs})) -> A.Simulation(S.State{world, players, S.NeedSwap{load, shells, 1n}, notes, grabs}, n):
  simulation_build(S.State{world, players, S.NeedSwap{load, shells, 1n}, notes, grabs}, n, result_original(S.State{world, players, S.NeedSwap{load, shells, 1n}, notes, grabs}, n, valid, loadproof.swap_final_matches(A.world_for(world, A.core(players)), A.core(players), load, shells, notes, n)), answer_swap_valid(world, players, load, shells, 0n, notes, grabs, n, valid))

def step_swap_more(+world: S.World, +players: S.Players, +load: D.Load, +shells: List<&2, D.Shell>, +extra: Nat, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedSwap{load, shells, 2n+extra}, notes, grabs})) -> A.Simulation(S.State{world, players, S.NeedSwap{load, shells, 2n+extra}, notes, grabs}, n):
  simulation_build(S.State{world, players, S.NeedSwap{load, shells, 2n+extra}, notes, grabs}, n, result_original(S.State{world, players, S.NeedSwap{load, shells, 2n+extra}, notes, grabs}, n, valid, loadproof.swap_remaining_matches(A.world_for(world, A.core(players)), A.core(players), load, shells, extra, notes, n)), answer_swap_valid(world, players, load, shells, 1n+extra, notes, grabs, n, valid))

def step_first(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedFirst{}, notes, grabs})) -> A.Simulation(S.State{world, players, S.NeedFirst{}, notes, grabs}, n):
  match valid:
    case Tuple{+normal, Tuple{supported, Tuple{bounded, ready}}}:
      canonical_valid : A.Valid(A.normalize(S.State{world, players, S.NeedFirst{}, notes, grabs})) =
        %Equal.sym(S.State, A.normalize(S.State{world, players, S.NeedFirst{}, notes, grabs}), S.State{world, players, S.NeedFirst{}, notes, grabs}, normal) : A.Valid(_)
        valid
      simulation_build(S.State{world, players, S.NeedFirst{}, notes, grabs}, n, result_original(S.State{world, players, S.NeedFirst{}, notes, grabs}, n, valid, first_valid(world, A.core(players), notes, n, canonical_valid)), answer_first_valid(world, players, notes, grabs, n, valid))

def stable_normalized(+world: S.World, +seats: A.Seats(), +stable: A.Stable(world, seats)) -> A.Stable(A.world_for(world, seats), seats):
  match stable:
    case Tuple{+world_eq, rest}:
      %Equal.sym(S.World, A.world_for(world, seats), world, world_eq) : A.Stable(_, seats)
      stable

def idle_raw_valid(+world: S.World, +players: S.Players, +actor: D.Seat, +options: D.NonEmpty<&2, S.IdleOption>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.Idle{actor, options}, notes, grabs})) -> A.Valid(A.next(S.State{world, players, S.Idle{actor, options}, notes, grabs}, n)):
  match valid:
    case Tuple{+normal, rest}:
      %normal : A.Valid(A.next(_, n))
      idleproof.idle_all_valid(A.world_for(world, A.core(players)), A.core(players), actor, notes, n, stable_normalized(world, A.core(players), stable_from_valid(world, players, S.Idle{actor, options}, notes, grabs, valid)))

def step_idle(+world: S.World, +players: S.Players, +actor: D.Seat, +options: D.NonEmpty<&2, S.IdleOption>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.Idle{actor, options}, notes, grabs})) -> A.Simulation(S.State{world, players, S.Idle{actor, options}, notes, grabs}, n):
  simulation_build(S.State{world, players, S.Idle{actor, options}, notes, grabs}, n, result_original(S.State{world, players, S.Idle{actor, options}, notes, grabs}, n, valid, idleproof.idle_all_matches(A.world_for(world, A.core(players)), A.core(players), actor, notes, n)), idle_raw_valid(world, players, actor, options, notes, grabs, n, valid))

def step_ended(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, valid: A.Valid(S.State{world, players, S.Ended{}, notes, grabs})) -> A.Simulation(S.State{world, players, S.Ended{}, notes, grabs}, n):
  simulation_build(S.State{world, players, S.Ended{}, notes, grabs}, n, {==}, valid)

def step_blocked(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, valid: A.Valid(S.State{world, players, S.Blocked{}, notes, grabs})) -> A.Simulation(S.State{world, players, S.Blocked{}, notes, grabs}, n):
  simulation_build(S.State{world, players, S.Blocked{}, notes, grabs}, n, {==}, valid)

def step_swap_zero(+world: S.World, +players: S.Players, +load: D.Load, +shells: List<&2, D.Shell>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, valid: A.Valid(S.State{world, players, S.NeedSwap{load, shells, 0n}, notes, grabs})) -> A.Simulation(S.State{world, players, S.NeedSwap{load, shells, 0n}, notes, grabs}, n):
  match valid:
    case Tuple{normal, rest}:
      impossible : {False{} == True{} : Bool} = Equal.cong(S.State, Bool, A.zero_swap, A.normalize(S.State{world, players, S.NeedSwap{load, shells, 0n}, notes, grabs}), S.State{world, players, S.NeedSwap{load, shells, 0n}, notes, grabs}, normal)
      Empty.absurd(A.Simulation(S.State{world, players, S.NeedSwap{load, shells, 0n}, notes, grabs}, n), false_true_absurd(impossible))

def step_item_phase(+world: S.World, +players: S.Players, +phase: S.Phase, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, valid: A.Valid(S.State{world, players, phase, notes, grabs}), canonical: {A.item_phase(A.normalize(S.State{world, players, phase, notes, grabs})) == False{} : Bool}, item: {A.item_phase(S.State{world, players, phase, notes, grabs}) == True{} : Bool}) -> A.Simulation(S.State{world, players, phase, notes, grabs}, n):
  match valid:
    case Tuple{normal, rest}:
      impossible : {False{} == True{} : Bool} = Equal.trans(Bool, False{}, A.item_phase(A.normalize(S.State{world, players, phase, notes, grabs})), True{}, Equal.sym(Bool, A.item_phase(A.normalize(S.State{world, players, phase, notes, grabs})), False{}, canonical), Equal.trans(Bool, A.item_phase(A.normalize(S.State{world, players, phase, notes, grabs})), A.item_phase(S.State{world, players, phase, notes, grabs}), True{}, Equal.cong(S.State, Bool, A.item_phase, A.normalize(S.State{world, players, phase, notes, grabs}), S.State{world, players, phase, notes, grabs}, normal), item))
      Empty.absurd(A.Simulation(S.State{world, players, phase, notes, grabs}, n), false_true_absurd(impossible))

def aimproof.living_entries(+entries: List<&2, D.At<&2, A.CoreSeat>>) -> {A.turn.machine_living(entries) == A.turn.source_living(entries) : List<&2, D.Seat>}:
  match entries:
    case Nil{}:
      {==}
    case D.At{seat, A.CoreSeat{0n, jam, checked, cash, sl, turn}} <> +rest:
      aimproof.living_entries(rest)
    case D.At{+seat, A.CoreSeat{1n+hp, jam, checked, cash, sl, turn}} <> +rest:
      Equal.cong(List<&2, D.Seat>, List<&2, D.Seat>, tail => seat <> tail, A.turn.machine_living(rest), A.turn.source_living(rest), aimproof.living_entries(rest))

def aimproof.only_matches(seats: List<&2, D.Seat>) -> {Q.winner.only(seats) == A.turn.source_only(seats) : Maybe<&2, D.Seat>}:
  match seats:
    case Nil{}:
      {==}
    case seat <> Nil{}:
      {==}
    case seat <> next <> rest:
      {==}

def aimproof.winner_raw(+world: S.World, +seats: A.Seats()) -> {Q.winner(A.seats.health(seats)) == A.turn.source_winner(world, seats) : Maybe<&2, D.Seat>}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          Equal.trans(Maybe<&2, D.Seat>, Q.winner(A.seats.health(seats)), Q.winner.only(A.turn.source_living(D.ring.entries(A.CoreSeat, seats))), A.turn.source_winner(world, seats), Equal.cong(List<&2, D.Seat>, Maybe<&2, D.Seat>, Q.winner.only, A.turn.machine_living(D.ring.entries(A.CoreSeat, seats)), A.turn.source_living(D.ring.entries(A.CoreSeat, seats)), aimproof.living_entries(D.ring.entries(A.CoreSeat, seats))), aimproof.only_matches(A.turn.source_living(D.ring.entries(A.CoreSeat, seats))))
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}}:
          Equal.trans(Maybe<&2, D.Seat>, Q.winner(A.seats.health(seats)), Q.winner.only(A.turn.source_living(D.ring.entries(A.CoreSeat, seats))), A.turn.source_winner(world, seats), Equal.cong(List<&2, D.Seat>, Maybe<&2, D.Seat>, Q.winner.only, A.turn.machine_living(D.ring.entries(A.CoreSeat, seats)), A.turn.source_living(D.ring.entries(A.CoreSeat, seats)), aimproof.living_entries(D.ring.entries(A.CoreSeat, seats))), aimproof.only_matches(A.turn.source_living(D.ring.entries(A.CoreSeat, seats))))
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}}:
          Equal.trans(Maybe<&2, D.Seat>, Q.winner(A.seats.health(seats)), Q.winner.only(A.turn.source_living(D.ring.entries(A.CoreSeat, seats))), A.turn.source_winner(world, seats), Equal.cong(List<&2, D.Seat>, Maybe<&2, D.Seat>, Q.winner.only, A.turn.machine_living(D.ring.entries(A.CoreSeat, seats)), A.turn.source_living(D.ring.entries(A.CoreSeat, seats)), aimproof.living_entries(D.ring.entries(A.CoreSeat, seats))), aimproof.only_matches(A.turn.source_living(D.ring.entries(A.CoreSeat, seats))))

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

def aimproof.recipient_matches(passing: Bool, current: D.Seat, next: D.Seat) -> {M.turn.recipient(passing, current, next) == A.turn.source_recipient(passing, current, next) : D.Seat}:
  match passing:
    case False{}:
      {==}
    case True{}:
      {==}

def aimproof.false_and(value: Bool) -> {Bool.and(False{}, value) == False{} : Bool}:
  match value:
    case False{}:
      {==}
    case True{}:
      {==}

def aimproof.false_and_backwards(+value: Bool) -> {False{} == Bool.and(False{}, value) : Bool}:
  %aimproof.false_and(value) : {_ == Bool.and(False{}, value) : Bool}
  {==}

def aimproof.dead_probe(value: Bool) -> {Bool.or(False{}, Bool.and(False{}, value)) == False{} : Bool}:
  match value:
    case False{}:
      {==}
    case True{}:
      {==}

def aimproof.dead_probe_backwards(+value: Bool) -> {False{} == Bool.or(False{}, Bool.and(False{}, value)) : Bool}:
  %aimproof.dead_probe(value) : {_ == Bool.or(False{}, Bool.and(False{}, value)) : Bool}
  {==}

def aimproof.random_nonreload(+world: S.World, +seats: A.Seats(), +from: D.Seat, +passing: Bool, +notes: A.Notes(), +fuel: Nat) -> {A.turn.ref_rule(world, seats, from, passing, False{}, None{}, notes, fuel, D.RandomAmount{}) == A.turn.ref_main(world, seats, from, passing, False{}, None{}, notes, fuel) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %aimproof.dead_probe_backwards(A.turn.ref_probe(world, seats)) : {A.turn.ref_live(world, seats, from, passing, False{}, None{}, notes, fuel, _) == A.turn.ref_main(world, seats, from, passing, False{}, None{}, notes, fuel) : A.Ref()}
      {==}

def aimproof.next_recipient_matches(+world: S.World, +seats: A.Seats(), +from: D.Seat, +passing: Bool) -> {M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from)) == A.turn.source_recipient(passing, from, A.ref_turn(world, seats, from)) : D.Seat}:
  Equal.trans(D.Seat, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from)), M.turn.recipient(passing, from, A.ref_turn(world, seats, from)), A.turn.source_recipient(passing, from, A.ref_turn(world, seats, from)), Equal.cong(D.Seat, D.Seat, next => M.turn.recipient(passing, from, next), Q.next_turn(A.seats.health(seats), S.world.direction(world), from), A.ref_turn(world, seats, from), turn_raw(world, seats, from)), aimproof.recipient_matches(passing, from, A.ref_turn(world, seats, from)))

def aimproof.positive_pass(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +k: Nat, +recipient: D.Seat) -> {A.turn.ref_pass(world, seats, from, passing, notes, k, recipient) == A.turn.positive_result(world, seats, phase, notes, recipient) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, old_recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      GrantProof.grant_six_dispatches(S.world.set_first_turn(world, recipient), seats, recipient, phase, notes, k)

def aimproof.positive_main(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +k: Nat) -> {A.turn.ref_main(world, seats, from, passing, False{}, None{}, notes, 7n+k) == A.turn.positive_result(world, seats, phase, notes, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %aimproof.next_recipient_matches(world, seats, from, passing) : {A.turn.ref_pass(world, seats, from, passing, notes, k, _) == A.turn.positive_result(world, seats, phase, notes, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))) : A.Ref()}
      aimproof.positive_pass(world, seats, phase, notes, from, passing, k, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from)))

def aimproof.winner_none_backwards(+seats: A.Seats(), nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}) -> {None{} == Q.winner(A.seats.health(seats)) : Maybe<&2, D.Seat>}:
  %nonwinning : {_ == Q.winner(A.seats.health(seats)) : Maybe<&2, D.Seat>}
  {==}

def aimproof.positive_amount(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +shell: D.Shell, +rest: List<&2, D.Shell>, +k: Nat, rule: D.AmountRule, +nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}) -> {A.turn.ref_rule(S.world.set_gun(world, shell <> rest), seats, from, passing, False{}, None{}, notes, 7n+k, rule) == A.turn.machine_amount_case(S.world.set_gun(world, shell <> rest), seats, phase, notes, from, passing, rule) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match rule:
        case D.RandomAmount{}:
          %aimproof.winner_none_backwards(seats, nonwinning) : {A.turn.ref_rule(S.world.set_gun(world, shell <> rest), seats, from, passing, False{}, None{}, notes, 7n+k, rule) == A.turn.machine_winner_case(S.world.set_gun(world, shell <> rest), seats, phase, notes, from, passing, _) : A.Ref()}
          Equal.trans(A.Ref(), A.turn.ref_rule(S.world.set_gun(world, shell <> rest), seats, from, passing, False{}, None{}, notes, 7n+k, rule), A.turn.ref_main(S.world.set_gun(world, shell <> rest), seats, from, passing, False{}, None{}, notes, 7n+k), A.turn.positive_result(S.world.set_gun(world, shell <> rest), seats, phase, notes, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), aimproof.random_nonreload(S.world.set_gun(world, shell <> rest), seats, from, passing, notes, 7n+k), aimproof.positive_main(S.world.set_gun(world, shell <> rest), seats, phase, notes, from, passing, k))
        case D.FixedAmount{+amount}:
          %aimproof.winner_none_backwards(seats, nonwinning) : {A.turn.ref_rule(S.world.set_gun(world, shell <> rest), seats, from, passing, False{}, None{}, notes, 7n+k, rule) == A.turn.machine_winner_case(S.world.set_item_amount(S.world.set_gun(world, shell <> rest), amount), seats, phase, notes, from, passing, _) : A.Ref()}
          aimproof.positive_main(S.world.set_item_amount(S.world.set_gun(world, shell <> rest), amount), seats, phase, notes, from, passing, k)

def aimproof.positive_end_none(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +shell: D.Shell, +rest: List<&2, D.Shell>, +k: Nat, nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}) -> {A.turn.ref_end(S.world.set_gun(world, shell <> rest), seats, from, passing, False{}, None{}, notes, 8n+k) == A.ref(M.turn.end(A.pack(S.world.set_gun(world, shell <> rest), seats, phase, notes), from, passing)) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %aimproof.amount_rule_matches(S.world.set_gun(world, shell <> rest), seats) : {A.turn.ref_rule(S.world.set_gun(world, shell <> rest), seats, from, passing, False{}, None{}, notes, 7n+k, _) == A.ref(M.turn.end(A.pack(S.world.set_gun(world, shell <> rest), seats, phase, notes), from, passing)) : A.Ref()}
      aimproof.positive_amount(world, seats, phase, notes, from, passing, shell, rest, k, Q.load.amount(Q.world.load_rule(S.world.set_gun(world, shell <> rest))), nonwinning)

def aimproof.source_winner_none(+world: S.World, +seats: A.Seats(), nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}) -> {A.turn.source_winner(world, seats) == None{} : Maybe<&2, D.Seat>}:
  Equal.trans(Maybe<&2, D.Seat>, A.turn.source_winner(world, seats), Q.winner(A.seats.health(seats)), None{}, Equal.sym(Maybe<&2, D.Seat>, Q.winner(A.seats.health(seats)), A.turn.source_winner(world, seats), aimproof.winner_raw(world, seats)), nonwinning)

def aimproof.source_winner_none_backwards(+world: S.World, +seats: A.Seats(), nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}) -> {None{} == A.turn.source_winner(world, seats) : Maybe<&2, D.Seat>}:
  %aimproof.source_winner_none(world, seats, nonwinning) : {_ == A.turn.source_winner(world, seats) : Maybe<&2, D.Seat>}
  {==}

def aimproof.positive_end_matches(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +shell: D.Shell, +rest: List<&2, D.Shell>, +k: Nat, +nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}) -> {A.turn.ref_actual(S.world.set_gun(world, shell <> rest), seats, from, passing, False{}, notes, 8n+k) == A.ref(M.turn.end(A.pack(S.world.set_gun(world, shell <> rest), seats, phase, notes), from, passing)) : A.Ref()}:
  %aimproof.source_winner_none_backwards(S.world.set_gun(world, shell <> rest), seats, nonwinning) : {A.turn.ref_end(S.world.set_gun(world, shell <> rest), seats, from, passing, False{}, _, notes, 8n+k) == A.ref(M.turn.end(A.pack(S.world.set_gun(world, shell <> rest), seats, phase, notes), from, passing)) : A.Ref()}
  aimproof.positive_end_none(world, seats, phase, notes, from, passing, shell, rest, k, nonwinning)

def aimproof.positive_amount_preserves(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +shell: D.Shell, +rest: List<&2, D.Shell>, rule: D.AmountRule, +nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}, +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}) -> A.Valid(A.turn.machine_amount_state(S.world.set_gun(world, shell <> rest), seats, phase, notes, from, passing, rule)):
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match rule:
        case D.RandomAmount{}:
          %aimproof.winner_none_backwards(seats, nonwinning) : A.Valid(M.turn.winner(A.pack(S.world.set_gun(world, shell <> rest), seats, phase, notes), from, passing, _))
          grant_preserves(S.world.set_first_turn(S.world.set_gun(world, shell <> rest), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, phase, notes, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from)), synced, supported, bounded)
        case D.FixedAmount{+amount}:
          %aimproof.winner_none_backwards(seats, nonwinning) : A.Valid(M.turn.winner(A.pack(S.world.set_item_amount(S.world.set_gun(world, shell <> rest), amount), seats, phase, notes), from, passing, _))
          grant_preserves(S.world.set_first_turn(S.world.set_item_amount(S.world.set_gun(world, shell <> rest), amount), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, phase, notes, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from)), synced, supported, bounded)

def aimproof.positive_end_preserves(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +shell: D.Shell, +rest: List<&2, D.Shell>, nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}, synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}, supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}) -> A.Valid(M.turn.end(A.pack(S.world.set_gun(world, shell <> rest), seats, phase, notes), from, passing)):
  aimproof.positive_amount_preserves(world, seats, phase, notes, from, passing, shell, rest, Q.load.amount(Q.world.load_rule(S.world.set_gun(world, shell <> rest))), nonwinning, synced, supported, bounded)

def aimproof.shoot_loaded_factor(+state: S.State, +shooter: D.Seat, +target: D.Seat, +shell: D.Shell, +rest: List<&2, D.Shell>) -> {M.shoot.loaded(state, shooter, target, shell, rest) == M.turn.end(A.shot.prefix(state, shooter, target, shell, rest), shooter, Q.shot.passes(shell, D.seat.eq(shooter, target))) : S.State}:
  {==}

def aimproof.players_health_write(+seats: A.Seats(), +seat: D.Seat, +hp: Nat) -> {S.players.set_health(A.players.free(seats), D.ring.set(Nat, A.seats.health(seats), seat, hp)) == A.players.free(A.shot.health_write(seats, seat, hp)) : S.Players}:
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

def aimproof.players_turn_write(+seats: A.Seats(), +seat: D.Seat, +turn: Bool) -> {S.players.set_has_turn(A.players.free(seats), D.ring.set(Bool, A.seats.has_turn(seats), seat, turn)) == A.players.free(A.shot.turn_write(seats, seat, turn)) : S.Players}:
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

def aimproof.players_cash_write(+seats: A.Seats(), +seat: D.Seat, +prize: U32) -> {S.players.set_cash(A.players.free(seats), D.ring.set(U32, A.seats.cash(seats), seat, U32.add(Q.value.or(U32, D.ring.get(U32, A.seats.cash(seats), seat), 0), prize))) == A.players.free(A.shot.cash_write(seats, seat, prize)) : S.Players}:
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

def aimproof.empty_probe(+world: S.World, +seats: A.Seats(), disabled: {Q.items.disabled(A.support.current_items(world, seats)) == True{} : Bool}) -> {A.turn.ref_probe(world, seats) == False{} : Bool}:
  Equal.cong(List<&2, D.Seat>, Bool, A.turn.ref_probe_list, A.ref_grab_seats(world, seats, False{}, 1n), Nil{}, loadproof.grab_seats_empty(world, seats, False{}, 1n, disabled))

def aimproof.empty_probe_backwards(+world: S.World, +seats: A.Seats(), disabled: {Q.items.disabled(A.support.current_items(world, seats)) == True{} : Bool}) -> {False{} == A.turn.ref_probe(world, seats) : Bool}:
  %aimproof.empty_probe(world, seats, disabled) : {_ == A.turn.ref_probe(world, seats) : Bool}
  {==}

def aimproof.random_reload(+world: S.World, +seats: A.Seats(), +from: D.Seat, +passing: Bool, +notes: A.Notes(), +fuel: Nat, disabled: {Q.items.disabled(A.support.current_items(world, seats)) == True{} : Bool}) -> {A.turn.ref_rule(world, seats, from, passing, True{}, None{}, notes, fuel, D.RandomAmount{}) == A.turn.ref_main(world, seats, from, passing, True{}, None{}, notes, fuel) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %aimproof.empty_probe_backwards(world, seats, disabled) : {A.turn.ref_live(world, seats, from, passing, True{}, None{}, notes, fuel, Bool.or(False{}, Bool.and(True{}, _))) == A.turn.ref_main(world, seats, from, passing, True{}, None{}, notes, fuel) : A.Ref()}
      {==}

def aimproof.reload_pass(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +k: Nat, +recipient: D.Seat, +disabled: {Q.items.disabled(A.support.current_items(world, seats)) == True{} : Bool}) -> {A.turn.ref_reload_pass(world, seats, from, passing, notes, k, recipient) == A.turn.reload_result(world, seats, phase, notes, recipient) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, old_recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %Equal.sym(List<&2, D.Seat>, A.ref_grab_seats(S.world.set_first_turn(world, recipient), seats, False{}, amount), Nil{}, loadproof.grab_seats_empty(S.world.set_first_turn(world, recipient), seats, False{}, amount, disabled)) : {A.turn.ref_reload_grab(S.world.set_first_turn(world, recipient), seats, from, passing, notes, 12n+k, _) == A.turn.reload_result(world, seats, phase, notes, recipient) : A.Ref()}
      Equal.trans(A.Ref(), A.turn.ref_reload_grab(S.world.set_first_turn(world, recipient), seats, from, passing, notes, 12n+k, Nil{}), A.ref(M.load.begin(A.pack(S.world.set_first_turn(world, recipient), seats, phase, notes))), A.turn.reload_result(world, seats, phase, notes, recipient), loadproof.load_begin_matches(S.world.set_first_turn(world, recipient), seats, phase, notes, k), Equal.cong(S.State, A.Ref(), state => A.ref(state), M.load.begin(A.pack(S.world.set_first_turn(world, recipient), seats, phase, notes)), M.reload.begin(A.pack(S.world.set_first_turn(world, recipient), seats, phase, notes)), Equal.sym(S.State, M.reload.begin(A.pack(S.world.set_first_turn(world, recipient), seats, phase, notes)), M.load.begin(A.pack(S.world.set_first_turn(world, recipient), seats, phase, notes)), noitems.reload_skip(A.pack(S.world.set_first_turn(world, recipient), seats, phase, notes), noitems.machine_disabled(world, seats, disabled)))))

def aimproof.reload_main(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +k: Nat, +disabled: {Q.items.disabled(A.support.current_items(world, seats)) == True{} : Bool}) -> {A.turn.ref_main(world, seats, from, passing, True{}, None{}, notes, 13n+k) == A.turn.reload_result(world, seats, phase, notes, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %aimproof.next_recipient_matches(world, seats, from, passing) : {A.turn.ref_reload_pass(world, seats, from, passing, notes, k, _) == A.turn.reload_result(world, seats, phase, notes, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))) : A.Ref()}
      aimproof.reload_pass(world, seats, phase, notes, from, passing, k, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from)), disabled)

def aimproof.reload_amount(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +k: Nat, rule: D.AmountRule, +nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}, +disabled: {Q.items.disabled(A.support.current_items(world, seats)) == True{} : Bool}) -> {A.turn.ref_rule(S.world.set_gun(world, Nil{}), seats, from, passing, True{}, None{}, notes, 13n+k, rule) == A.turn.machine_amount_case(S.world.set_gun(world, Nil{}), seats, phase, notes, from, passing, rule) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match rule:
        case D.RandomAmount{}:
          %aimproof.winner_none_backwards(seats, nonwinning) : {A.turn.ref_rule(S.world.set_gun(world, Nil{}), seats, from, passing, True{}, None{}, notes, 13n+k, rule) == A.ref(M.turn.live(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), from, passing, _, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes))), I.reload.wanted(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), _)))) : A.Ref()}
          %Equal.sym(Bool, I.reload.wanted(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), None{}), False{}, noitems.reload_unwanted(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), noitems.machine_disabled(world, seats, disabled))) : {A.turn.ref_rule(S.world.set_gun(world, Nil{}), seats, from, passing, True{}, None{}, notes, 13n+k, rule) == A.ref(M.turn.live(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), from, passing, None{}, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes))), _))) : A.Ref()}
          Equal.trans(A.Ref(), A.turn.ref_rule(S.world.set_gun(world, Nil{}), seats, from, passing, True{}, None{}, notes, 13n+k, rule), A.turn.ref_main(S.world.set_gun(world, Nil{}), seats, from, passing, True{}, None{}, notes, 13n+k), A.turn.reload_result(S.world.set_gun(world, Nil{}), seats, phase, notes, M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), aimproof.random_reload(S.world.set_gun(world, Nil{}), seats, from, passing, notes, 13n+k, disabled), aimproof.reload_main(S.world.set_gun(world, Nil{}), seats, phase, notes, from, passing, k, disabled))
        case D.FixedAmount{+amount}:
          %aimproof.winner_none_backwards(seats, nonwinning) : {A.turn.ref_rule(S.world.set_gun(world, Nil{}), seats, from, passing, True{}, None{}, notes, 13n+k, rule) == A.turn.machine_winner_case(S.world.set_item_amount(S.world.set_gun(world, Nil{}), amount), seats, phase, notes, from, passing, _) : A.Ref()}
          aimproof.reload_main(S.world.set_item_amount(S.world.set_gun(world, Nil{}), amount), seats, phase, notes, from, passing, k, disabled)

def aimproof.reload_end_none(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +k: Nat, +nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}, disabled: {Q.items.disabled(A.support.current_items(world, seats)) == True{} : Bool}) -> {A.turn.ref_end(S.world.set_gun(world, Nil{}), seats, from, passing, True{}, None{}, notes, 14n+k) == A.ref(M.turn.end(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), from, passing)) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %aimproof.amount_rule_matches(S.world.set_gun(world, Nil{}), seats) : {A.turn.ref_rule(S.world.set_gun(world, Nil{}), seats, from, passing, True{}, None{}, notes, 13n+k, _) == A.ref(M.turn.end(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), from, passing)) : A.Ref()}
      aimproof.reload_amount(world, seats, phase, notes, from, passing, k, Q.load.amount(Q.world.load_rule(S.world.set_gun(world, Nil{}))), nonwinning, disabled)

def aimproof.reload_end_matches(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +k: Nat, +nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}, +disabled: {Q.items.disabled(A.support.current_items(world, seats)) == True{} : Bool}) -> {A.turn.ref_actual(S.world.set_gun(world, Nil{}), seats, from, passing, True{}, notes, 14n+k) == A.ref(M.turn.end(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), from, passing)) : A.Ref()}:
  %aimproof.source_winner_none_backwards(S.world.set_gun(world, Nil{}), seats, nonwinning) : {A.turn.ref_end(S.world.set_gun(world, Nil{}), seats, from, passing, True{}, _, notes, 14n+k) == A.ref(M.turn.end(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), from, passing)) : A.Ref()}
  aimproof.reload_end_none(world, seats, phase, notes, from, passing, k, nonwinning, disabled)

def aimproof.reload_amount_preserves(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, rule: D.AmountRule, +nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}, +stable: A.Stable(world, seats)) -> A.Valid(A.turn.machine_amount_state(S.world.set_gun(world, Nil{}), seats, phase, notes, from, passing, rule)):
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match rule:
        case D.RandomAmount{}:
          %aimproof.winner_none_backwards(seats, nonwinning) : A.Valid(M.turn.live(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), from, passing, _, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes))), I.reload.wanted(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), _))))
          %Equal.sym(Bool, I.reload.wanted(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), None{}), False{}, noitems.reload_unwanted(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), noitems.stable_disabled(world, seats, stable))) : A.Valid(M.turn.live(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), from, passing, None{}, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes))), _)))
          %Equal.sym(S.State, M.reload.begin(A.pack(S.world.set_first_turn(S.world.set_gun(world, Nil{}), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, phase, notes)), M.load.begin(A.pack(S.world.set_first_turn(S.world.set_gun(world, Nil{}), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, phase, notes)), noitems.reload_skip(A.pack(S.world.set_first_turn(S.world.set_gun(world, Nil{}), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, phase, notes), noitems.stable_disabled(world, seats, stable))) : A.Valid(_)
          load_begin_valid(S.world.set_first_turn(S.world.set_gun(world, Nil{}), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, phase, notes, stable_fields(world, S.world.set_first_turn(S.world.set_gun(world, Nil{}), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, {==}, {==}, stable))
        case D.FixedAmount{+amount}:
          %aimproof.winner_none_backwards(seats, nonwinning) : A.Valid(M.turn.winner(A.pack(S.world.set_item_amount(S.world.set_gun(world, Nil{}), amount), seats, phase, notes), from, passing, _))
          %Equal.sym(S.State, M.reload.begin(A.pack(S.world.set_first_turn(S.world.set_item_amount(S.world.set_gun(world, Nil{}), amount), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, phase, notes)), M.load.begin(A.pack(S.world.set_first_turn(S.world.set_item_amount(S.world.set_gun(world, Nil{}), amount), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, phase, notes)), noitems.reload_skip(A.pack(S.world.set_first_turn(S.world.set_item_amount(S.world.set_gun(world, Nil{}), amount), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, phase, notes), noitems.stable_disabled(world, seats, stable))) : A.Valid(_)
          load_begin_valid(S.world.set_first_turn(S.world.set_item_amount(S.world.set_gun(world, Nil{}), amount), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, phase, notes, stable_fields(world, S.world.set_first_turn(S.world.set_item_amount(S.world.set_gun(world, Nil{}), amount), M.turn.recipient(passing, from, Q.next_turn(A.seats.health(seats), S.world.direction(world), from))), seats, {==}, {==}, stable))

def aimproof.reload_end_preserves(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, nonwinning: {Q.winner(A.seats.health(seats)) == None{} : Maybe<&2, D.Seat>}, stable: A.Stable(world, seats)) -> A.Valid(M.turn.end(A.pack(S.world.set_gun(world, Nil{}), seats, phase, notes), from, passing)):
  aimproof.reload_amount_preserves(world, seats, phase, notes, from, passing, Q.load.amount(Q.world.load_rule(S.world.set_gun(world, Nil{}))), nonwinning, stable)

def aimproof.win_factor(+state: S.State, +seat: D.Seat) -> {M.win(state, seat) == M.win.final(A.win.awarded(state, seat), A.final_condition(S.state.world(state))) : S.State}:
  {==}

def aimproof.cash_shape(+seats: A.Seats(), +seat: D.Seat, prize: U32) -> {D.ring.table(A.CoreSeat, A.shot.cash_write(seats, seat, prize)) == D.ring.table(A.CoreSeat, seats) : D.Table}:
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


def aimproof.awarded_pack(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +seat: D.Seat) -> {A.win.awarded(A.pack(world, seats, phase, notes), seat) == A.pack(world, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), phase, A.win.award_notes(world, seat, notes)) : S.State}:
  Equal.trans(S.State, A.win.awarded(A.pack(world, seats, phase, notes), seat), S.State{world, A.players.free(A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world)))), phase, A.win.award_notes(world, seat, notes), A.grabs(seats)}, A.pack(world, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), phase, A.win.award_notes(world, seat, notes)), Equal.cong(S.Players, S.State, ps => S.State{world, ps, phase, A.win.award_notes(world, seat, notes), A.grabs(seats)}, S.players.set_cash(A.players.free(seats), D.ring.set(U32, A.seats.cash(seats), seat, U32.add(Q.value.or(U32, D.ring.get(U32, A.seats.cash(seats), seat), 0), D.prize(S.world.round_index(world))))), A.players.free(A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world)))), aimproof.players_cash_write(seats, seat, D.prize(S.world.round_index(world)))), Equal.cong(D.Table, S.State, table => S.State{world, A.players.free(A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world)))), phase, A.win.award_notes(world, seat, notes), A.grabs.empty(table)}, D.ring.table(A.CoreSeat, seats), D.ring.table(A.CoreSeat, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world)))), Equal.sym(D.Table, D.ring.table(A.CoreSeat, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world)))), D.ring.table(A.CoreSeat, seats), aimproof.cash_shape(seats, seat, D.prize(S.world.round_index(world))))))

def ran_point_commutes(+ran: D.Ran<&2, S.State>) -> {A.ref_ran_point(A.ran(ran)) == A.point_of_ref(A.machine_ran_state(ran)) : D.Point}:
  match ran:
    case D.Ran{state, notes, tape}:
      {==}

def merge_final_state(+step: D.Stepped<&2, S.State>, +ran: D.Ran<&2, S.State>) -> {A.machine_ran_state(M.run.merge(step, ran)) == A.machine_ran_state(ran) : S.State}:
  match step ran:
    case D.Stepped{before, first} D.Ran{state, notes, tape}:
      {==}

def merge_final_valid(+step: D.Stepped<&2, S.State>, +ran: D.Ran<&2, S.State>, valid: A.Valid(A.machine_ran_state(ran))) -> A.Valid(A.machine_ran_state(M.run.merge(step, ran))):
  %Equal.sym(S.State, A.machine_ran_state(M.run.merge(step, ran)), A.machine_ran_state(ran), merge_final_state(step, ran)) : A.Valid(_)
  valid

def next_valid_transport(+step: D.Stepped<&2, S.State>, valid: A.Valid(A.machine_step_state(step))) -> A.Valid(M.stepped.state(step)):
  match step:
    case D.Stepped{state, notes}:
      valid

def run_valid_successor(+fuel: Nat, +state: S.State, +n: Nat, +tape: List<&2, Nat>, simulation: A.Simulation(state, n), recur: A.RunValidHypothesis(fuel)) -> A.Valid(A.machine_ran_state(M.run.merge(M.answer(state, n), M.run(fuel, M.stepped.state(M.answer(state, n)), tape)))):
  merge_final_valid(M.answer(state, n), M.run(fuel, M.stepped.state(M.answer(state, n)), tape), recur(M.stepped.state(M.answer(state, n)), tape, next_valid_transport(M.answer(state, n), A.simulation.next(state, n, simulation))))

def run_valid_zero(request: D.Request, +state: S.State, tape: List<&2, Nat>, valid: A.Valid(state)) -> A.Valid(A.machine_ran_state(M.run.request(0n, request, state, tape))):
  match request tape:
    case D.Finished{} Nil{}:
      valid
    case D.Finished{} n <> rest:
      valid
    case D.Stuck{} Nil{}:
      valid
    case D.Stuck{} n <> rest:
      valid
    case D.Draw{kind, range} Nil{}:
      valid
    case D.Draw{kind, range} n <> rest:
      valid
    case D.Choose{menus} Nil{}:
      valid
    case D.Choose{menus} n <> rest:
      valid

def aimstep.synced_world(+world: S.World, +seats: A.Seats(), synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> {A.world_for(world, seats) == world : S.World}:
  match world:
    case S.World{D.Config{+table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      Equal.cong(D.Table, S.World, tb => S.World{D.Config{tb, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.ring.table(A.CoreSeat, seats), table, Equal.sym(D.Table, table, D.ring.table(A.CoreSeat, seats), synced))

def aimstep.stable_synced(+world: S.World, +seats: A.Seats(), synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}, supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}) -> A.Stable(world, seats):
  (aimstep.synced_world(world, seats, synced), (supported, bounded))

def aimstep.machine_final_gate(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes()) -> {A.machine_win_gate(world, seats, seat, phase, notes, True{}) == A.expected_win(world, seats, seat, notes) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
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

def aimstep.machine_final_closed(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), final: {A.final_condition(world) == True{} : Bool}) -> {A.ref(M.win(A.pack(world, seats, phase, notes), seat)) == A.expected_win(world, seats, seat, notes) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %true_backwards(A.final_condition(world), final) : {A.machine_win_gate(world, seats, seat, phase, notes, _) == A.expected_win(world, seats, seat, notes) : A.Ref()}
      aimstep.machine_final_gate(world, seats, seat, phase, notes)

def aimstep.loop_award(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes()) -> {A.aim.loop_state(world, seats, seat, notes) == A.aim.loop_expected(world, seats, seat, notes) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
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

def aimstep.win_final_eq(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +final: {A.final_condition(world) == True{} : Bool}) -> {A.ref_win(world, seats, seat, notes, 87n) == A.ref(M.win(A.pack(world, seats, phase, notes), seat)) : A.Ref()}:
  Equal.trans(A.Ref(), A.ref_win(world, seats, seat, notes, 87n), A.expected_win(world, seats, seat, notes), A.ref(M.win(A.pack(world, seats, phase, notes), seat)), ShotProof.ref_final_closed(world, seats, seat, notes, 83n, final), Equal.sym(A.Ref(), A.ref(M.win(A.pack(world, seats, phase, notes), seat)), A.expected_win(world, seats, seat, notes), aimstep.machine_final_closed(world, seats, seat, phase, notes, final)))

def aimstep.win_final_valid(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), final: {A.final_condition(world) == True{} : Bool}, +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> A.Valid(M.win(A.pack(world, seats, phase, notes), seat)):
  %true_backwards(A.final_condition(world), final) : A.Valid(M.win.final(A.win.awarded(A.pack(world, seats, phase, notes), seat), _))
  %Equal.sym(S.State, A.win.awarded(A.pack(world, seats, phase, notes), seat), A.pack(world, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), phase, A.win.award_notes(world, seat, notes)), aimproof.awarded_pack(world, seats, phase, notes, seat)) : A.Valid(S.state.emit(S.state.set_phase(_, S.Ended{}), D.MatchConcluded{}))
  pack_valid(world, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), S.Ended{}, List.append(&2, D.Note, A.win.award_notes(world, seat, notes), [D.Shown{D.MatchConcluded{}}]), stable_shape(world, seats, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), aimproof.cash_shape(seats, seat, D.prize(S.world.round_index(world))), aimstep.stable_synced(world, seats, synced, supported, bounded)), {==}, {==})

def aimstep.win_nonfinal_eq(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +nonfinal: {A.final_condition(world) == False{} : Bool}, +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> {A.ref_win(world, seats, seat, notes, 87n) == A.ref(M.win(A.pack(world, seats, phase, notes), seat)) : A.Ref()}:
  match world:
    case S.World{D.Config{table, +plan}, +before, +round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %Equal.sym(Bool, A.final_condition(world), False{}, nonfinal) : {A.ref_win_gate(world, seats, seat, notes, 83n, _) == A.ref(M.win.final(A.win.awarded(A.pack(world, seats, phase, notes), seat), _)) : A.Ref()}
      %Equal.sym(A.Ref(), A.aim.loop_state(world, seats, seat, notes), A.aim.loop_expected(world, seats, seat, notes), aimstep.loop_award(world, seats, seat, notes)) : {A.ref_settle(85n, _) == A.ref(M.first.begin(A.win.awarded(A.pack(world, seats, phase, notes), seat))) : A.Ref()}
      %Equal.sym(S.State, A.win.awarded(A.pack(world, seats, phase, notes), seat), A.pack(world, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), phase, A.win.award_notes(world, seat, notes)), aimproof.awarded_pack(world, seats, phase, notes, seat)) : {A.ref_settle(85n, A.aim.loop_expected(world, seats, seat, notes)) == A.ref(M.first.begin(_)) : A.Ref()}
      %aimstep.synced_world(world, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), Equal.trans(D.Table, S.world.table(world), D.ring.table(A.CoreSeat, seats), D.ring.table(A.CoreSeat, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world)))), synced, Equal.sym(D.Table, D.ring.table(A.CoreSeat, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world)))), D.ring.table(A.CoreSeat, seats), aimproof.cash_shape(seats, seat, D.prize(S.world.round_index(world)))))) : {A.ref_first_begin(85n, _, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), A.win.award_notes(world, seat, notes)) == A.ref(A.machine_first_begin(_, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), phase, A.win.award_notes(world, seat, notes))) : A.Ref()}
      first_begin_matches(world, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), phase, A.win.award_notes(world, seat, notes), 64n, supported, SupportProof.nonfinal_next(before, plan, round, bounded, nonfinal))

def aimstep.win_nonfinal_valid(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +nonfinal: {A.final_condition(world) == False{} : Bool}, +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> A.Valid(M.win(A.pack(world, seats, phase, notes), seat)):
  match world:
    case S.World{D.Config{table, +plan}, +before, +round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %Equal.sym(Bool, A.final_condition(world), False{}, nonfinal) : A.Valid(M.win.final(A.win.awarded(A.pack(world, seats, phase, notes), seat), _))
      %Equal.sym(S.State, A.win.awarded(A.pack(world, seats, phase, notes), seat), A.pack(world, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), phase, A.win.award_notes(world, seat, notes)), aimproof.awarded_pack(world, seats, phase, notes, seat)) : A.Valid(M.first.begin(_))
      first_begin_valid(world, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), phase, A.win.award_notes(world, seat, notes), stable_shape(world, seats, A.shot.cash_write(seats, seat, D.prize(S.world.round_index(world))), aimproof.cash_shape(seats, seat, D.prize(S.world.round_index(world))), aimstep.stable_synced(world, seats, synced, supported, bounded)), SupportProof.nonfinal_next(before, plan, round, bounded, nonfinal))

def aimstep.win_case(+final: Bool, +world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +final_eq: {A.final_condition(world) == final : Bool}, +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> Sigma<&2, &2, {A.ref_win(world, seats, seat, notes, 87n) == A.ref(M.win(A.pack(world, seats, phase, notes), seat)) : A.Ref()}, _ => A.Valid(M.win(A.pack(world, seats, phase, notes), seat))>:
  match final:
    case True{}:
      (aimstep.win_final_eq(world, seats, seat, phase, notes, final_eq), aimstep.win_final_valid(world, seats, seat, phase, notes, final_eq, supported, bounded, synced))
    case False{}:
      (aimstep.win_nonfinal_eq(world, seats, seat, phase, notes, final_eq, supported, bounded, synced), aimstep.win_nonfinal_valid(world, seats, seat, phase, notes, final_eq, supported, bounded, synced))

def aimstep.win_any(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +phase: S.Phase, +notes: A.Notes(), +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> Sigma<&2, &2, {A.ref_win(world, seats, seat, notes, 87n) == A.ref(M.win(A.pack(world, seats, phase, notes), seat)) : A.Ref()}, _ => A.Valid(M.win(A.pack(world, seats, phase, notes), seat))>:
  aimstep.win_case(A.final_condition(world), world, seats, seat, phase, notes, {==}, supported, bounded, synced)

def aimstep.win_rule(+rule: D.AmountRule, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +empty: Bool, +seat: D.Seat, +winning: {Q.winner(A.seats.health(seats)) == Some{seat} : Maybe<&2, D.Seat>}, +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> Sigma<&2, &2, {A.turn.ref_rule(world, seats, from, passing, empty, Some{seat}, notes, 88n, rule) == A.ref(A.turn.machine_amount_state(world, seats, phase, notes, from, passing, rule)) : A.Ref()}, _ => A.Valid(A.turn.machine_amount_state(world, seats, phase, notes, from, passing, rule))>:
  match rule world:
    case D.RandomAmount{} S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %Equal.sym(Maybe<&2, D.Seat>, Q.winner(A.seats.health(seats)), Some{seat}, winning) : Sigma<&2, &2, {A.turn.ref_rule(world, seats, from, passing, empty, Some{seat}, notes, 88n, rule) == A.ref(M.turn.live(A.pack(world, seats, phase, notes), from, passing, _, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(A.pack(world, seats, phase, notes))), I.reload.wanted(A.pack(world, seats, phase, notes), _)))) : A.Ref()}, _ => A.Valid(M.turn.live(A.pack(world, seats, phase, notes), from, passing, _, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(A.pack(world, seats, phase, notes))), I.reload.wanted(A.pack(world, seats, phase, notes), _))))>
      %Equal.sym(Bool, Bool.and(I.gun.empty(S.world.gun(world)), False{}), False{}, loadproof.and_false_right(I.gun.empty(S.world.gun(world)))) : Sigma<&2, &2, {A.turn.ref_rule(world, seats, from, passing, empty, Some{seat}, notes, 88n, rule) == A.ref(M.turn.live(A.pack(world, seats, phase, notes), from, passing, Some{seat}, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(A.pack(world, seats, phase, notes))), _))) : A.Ref()}, _ => A.Valid(M.turn.live(A.pack(world, seats, phase, notes), from, passing, Some{seat}, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(A.pack(world, seats, phase, notes))), _)))>
      aimstep.win_any(world, seats, seat, phase, notes, supported, bounded, synced)
    case D.FixedAmount{+value} S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %Equal.sym(Maybe<&2, D.Seat>, Q.winner(A.seats.health(seats)), Some{seat}, winning) : Sigma<&2, &2, {A.turn.ref_rule(world, seats, from, passing, empty, Some{seat}, notes, 88n, rule) == A.ref(M.turn.winner(A.pack(S.world.set_item_amount(world, value), seats, phase, notes), from, passing, _)) : A.Ref()}, _ => A.Valid(M.turn.winner(A.pack(S.world.set_item_amount(world, value), seats, phase, notes), from, passing, _))>
      aimstep.win_any(S.world.set_item_amount(world, value), seats, seat, phase, notes, supported, bounded, synced)

def aimstep.win_end(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +seat: D.Seat, +winning: {Q.winner(A.seats.health(seats)) == Some{seat} : Maybe<&2, D.Seat>}, +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> Sigma<&2, &2, {A.ref_settle(89n, A.aim.ue_state(world, seats, notes, from, passing)) == A.ref(M.turn.end(A.pack(world, seats, phase, notes), from, passing)) : A.Ref()}, _ => A.Valid(M.turn.end(A.pack(world, seats, phase, notes), from, passing))>:
  %Equal.trans(Maybe<&2, D.Seat>, Some{seat}, Q.winner(A.seats.health(seats)), A.turn.source_winner(world, seats), Equal.sym(Maybe<&2, D.Seat>, Q.winner(A.seats.health(seats)), Some{seat}, winning), aimproof.winner_raw(world, seats)) : Sigma<&2, &2, {A.turn.ref_rule(world, seats, from, passing, Nat.is_eq(List.length(&2, D.Shell, S.world.gun(world)), 0n), _, notes, 88n, A.turn.source_amount_rule(world, seats)) == A.ref(M.turn.end(A.pack(world, seats, phase, notes), from, passing)) : A.Ref()}, _ => A.Valid(M.turn.end(A.pack(world, seats, phase, notes), from, passing))>
  %aimproof.amount_rule_matches(world, seats) : Sigma<&2, &2, {A.turn.ref_rule(world, seats, from, passing, Nat.is_eq(List.length(&2, D.Shell, S.world.gun(world)), 0n), Some{seat}, notes, 88n, _) == A.ref(A.turn.machine_amount_state(world, seats, phase, notes, from, passing, Q.load.amount(Q.world.load_rule(world)))) : A.Ref()}, _ => A.Valid(A.turn.machine_amount_state(world, seats, phase, notes, from, passing, Q.load.amount(Q.world.load_rule(world))))>
  aimstep.win_rule(Q.load.amount(Q.world.load_rule(world)), world, seats, phase, notes, from, passing, Nat.is_eq(List.length(&2, D.Shell, S.world.gun(world)), 0n), seat, winning, supported, bounded, synced)

def aimstep.tail_winner(+winner: Maybe<&2, D.Seat>, +world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +found: {Q.winner(A.seats.health(seats)) == winner : Maybe<&2, D.Seat>}, +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> Sigma<&2, &2, {A.ref_settle(89n, A.aim.ue_state(world, seats, notes, from, passing)) == A.ref(M.turn.end(A.pack(world, seats, phase, notes), from, passing)) : A.Ref()}, _ => A.Valid(M.turn.end(A.pack(world, seats, phase, notes), from, passing))>:
  match winner world:
    case None{} S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}:
      (aimproof.reload_end_matches(world, seats, phase, notes, from, passing, 75n, found, SupportProof.current_disabled(world, seats, supported, bounded)), aimproof.reload_end_preserves(world, seats, phase, notes, from, passing, found, aimstep.stable_synced(world, seats, synced, supported, bounded)))
    case None{} S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, +shell <> +rest, shown, deck}:
      (aimproof.positive_end_matches(world, seats, phase, notes, from, passing, shell, rest, 81n, found), aimproof.positive_end_preserves(world, seats, phase, notes, from, passing, shell, rest, found, synced, supported, bounded))
    case Some{+seat} world:
      aimstep.win_end(world, seats, phase, notes, from, passing, seat, found, supported, bounded, synced)

def aimstep.tail(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +from: D.Seat, +passing: Bool, +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> Sigma<&2, &2, {A.ref_settle(89n, A.aim.ue_state(world, seats, notes, from, passing)) == A.ref(M.turn.end(A.pack(world, seats, phase, notes), from, passing)) : A.Ref()}, _ => A.Valid(M.turn.end(A.pack(world, seats, phase, notes), from, passing))>:
  aimstep.tail_winner(Q.winner(A.seats.health(seats)), world, seats, phase, notes, from, passing, {==}, supported, bounded, synced)

# Split shape, shooter, target, shell and the written health so the reference chain DeathRequest..CheckIfEndingTurn computes; every leaf is the same tail call.
def aimstep.mid(+world: S.World, +seats: A.Seats(), +actor: D.Seat, +target: D.Seat, +shell: D.Shell, +rest: List<&2, D.Shell>, +phase: S.Phase, +hp: Nat, +d: Nat, +dmg: D.Damage, present_a: P.seated(D.ring.table(A.CoreSeat, seats), actor), present_t: P.seated(D.ring.table(A.CoreSeat, seats), target), +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> Sigma<&2, &2, {A.ref_settle(A.aim.mid_fuel(A.aim.self_live(actor, target, shell)), A.aim.rs_mid(world, seats, actor, target, shell, rest, hp, d, dmg)) == A.ref(M.turn.end(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg), actor, Q.shot.passes(shell, D.seat.eq(actor, target)))) : A.Ref()}, _ => A.Valid(M.turn.end(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg), actor, Q.shot.passes(shell, D.seat.eq(actor, target))))>:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, False{}, amount, saw, gun, shown, deck}:
      match seats actor target:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat0{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat1{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat2{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat3{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat0{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat2{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat0{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat1{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat2{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat3{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat0{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat2{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat3{}:
          match present_t:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat3{}:
          match present_t:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat3{}:
          match present_t:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat0{}:
          match present_a:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat1{}:
          match present_a:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat2{}:
          match present_a:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat3{}:
          match present_a:
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, True{}, amount, saw, gun, shown, deck}:
      match seats actor target:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat0{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat1{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat2{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat3{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat0{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat2{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat0{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat1{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat2{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat3{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat0{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat2{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat3{}:
          match present_t:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat3{}:
          match present_t:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat3{}:
          match present_t:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat0{}:
          match present_a:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat1{}:
          match present_a:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat2{}:
          match present_a:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat3{}:
          match present_a:
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat0{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat1{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat2{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat3{}:
          match shell hp:
            case D.Blank{} _:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 0n:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)
            case D.Live{} 1n+x:
              aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)

def aimstep.r1(+world: S.World, +seats: A.Seats(), +actor: D.Seat, +target: D.Seat, +shell: D.Shell, +rest: List<&2, D.Shell>, +index: Nat, present_a: P.seated(D.ring.table(A.CoreSeat, seats), actor), present_t: P.seated(D.ring.table(A.CoreSeat, seats), target)) -> {A.ref_settle(96n, A.aim.psv(S.world.set_gun(world, shell <> rest), seats, actor, target, index)) == A.ref_settle(A.aim.mid_fuel(A.aim.self_live(actor, target, shell)), A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.ref_hp(world, seats, target, shell), A.ref_subtract(A.aim.before(seats, target), A.aim.ref_hp(world, seats, target, shell)), A.aim.ref_damage(world))) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats actor target:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat0{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat1{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat2{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat3{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat0{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat1{}:
          match shell:
            case D.Live{}:
              {==}
            case D.Blank{}:
              {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat2{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat3{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat0{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat1{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat2{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat3{}:
          match present_a:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat0{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat2{}:
          match present_t:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat3{}:
          match shell:
            case D.Live{}:
              {==}
            case D.Blank{}:
              {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat0{}:
          match shell:
            case D.Live{}:
              {==}
            case D.Blank{}:
              {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{} D.Seat3{}:
          match present_t:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat1{}:
          match shell:
            case D.Live{}:
              {==}
            case D.Blank{}:
              {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{} D.Seat3{}:
          match present_t:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat2{}:
          match shell:
            case D.Live{}:
              {==}
            case D.Blank{}:
              {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{} D.Seat3{}:
          match present_t:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat0{}:
          match present_a:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat1{}:
          match present_a:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat2{}:
          match present_a:
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{} D.Seat3{}:
          match present_a:
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat0{}:
          match shell:
            case D.Live{}:
              {==}
            case D.Blank{}:
              {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat1{}:
          match shell:
            case D.Live{}:
              {==}
            case D.Blank{}:
              {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat2{}:
          match shell:
            case D.Live{}:
              {==}
            case D.Blank{}:
              {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{} D.Seat3{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{} D.Seat3{}:
          match shell:
            case D.Live{}:
              {==}
            case D.Blank{}:
              {==}

def aimstep.bridge(+world: S.World, +seats: A.Seats(), +actor: D.Seat, +target: D.Seat, +shell: D.Shell, +rest: List<&2, D.Shell>) -> {A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.ref_hp(world, seats, target, shell), A.ref_subtract(A.aim.before(seats, target), A.aim.ref_hp(world, seats, target, shell)), A.aim.ref_damage(world)) == A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world)) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, False{}, gun, shown, deck}:
      %ShotProof.health_matches(shell, A.aim.before(seats, target), D.Single{}) : {A.aim.rs_mid(world, seats, actor, target, shell, rest, _, A.ref_subtract(A.aim.before(seats, target), _), D.Single{}) == A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), D.Single{}) : A.Ref()}
      %ShotProof.subtract_matches(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)) : {A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.machine_hp(world, seats, target, shell), _, D.Single{}) == A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), D.Single{}) : A.Ref()}
      {==}
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, True{}, gun, shown, deck}:
      %ShotProof.health_matches(shell, A.aim.before(seats, target), D.Double{}) : {A.aim.rs_mid(world, seats, actor, target, shell, rest, _, A.ref_subtract(A.aim.before(seats, target), _), D.Double{}) == A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), D.Double{}) : A.Ref()}
      %ShotProof.subtract_matches(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)) : {A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.machine_hp(world, seats, target, shell), _, D.Double{}) == A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), D.Double{}) : A.Ref()}
      {==}

def aimstep.shot_glue(+world: S.World, +seats: A.Seats(), +actor: D.Seat, +target: D.Seat, +index: Nat, +shell: D.Shell, +rest: List<&2, D.Shell>, +phase: S.Phase, present_a: P.seated(D.ring.table(A.CoreSeat, seats), actor), present_t: P.seated(D.ring.table(A.CoreSeat, seats), target), bundle: Sigma<&2, &2, {A.ref_settle(A.aim.mid_fuel(A.aim.self_live(actor, target, shell)), A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world))) == A.ref(M.turn.end(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)))) : A.Ref()}, _ => A.Valid(M.turn.end(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world)), actor, Q.shot.passes(shell, D.seat.eq(actor, target))))>) -> Sigma<&2, &2, {A.ref_settle(96n, A.aim.psv(S.world.set_gun(world, shell <> rest), seats, actor, target, index)) == A.ref(M.turn.end(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)))) : A.Ref()}, _ => A.Valid(M.turn.end(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world)), actor, Q.shot.passes(shell, D.seat.eq(actor, target))))>:
  match bundle:
    case Tuple{eq, valid}:
      (Equal.trans(A.Ref(), A.ref_settle(96n, A.aim.psv(S.world.set_gun(world, shell <> rest), seats, actor, target, index)), A.ref_settle(A.aim.mid_fuel(A.aim.self_live(actor, target, shell)), A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.ref_hp(world, seats, target, shell), A.ref_subtract(A.aim.before(seats, target), A.aim.ref_hp(world, seats, target, shell)), A.aim.ref_damage(world))), A.ref(M.turn.end(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)))), aimstep.r1(world, seats, actor, target, shell, rest, index, present_a, present_t), Equal.trans(A.Ref(), A.ref_settle(A.aim.mid_fuel(A.aim.self_live(actor, target, shell)), A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.ref_hp(world, seats, target, shell), A.ref_subtract(A.aim.before(seats, target), A.aim.ref_hp(world, seats, target, shell)), A.aim.ref_damage(world))), A.ref_settle(A.aim.mid_fuel(A.aim.self_live(actor, target, shell)), A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world))), A.ref(M.turn.end(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world)), actor, Q.shot.passes(shell, D.seat.eq(actor, target)))), Equal.cong(A.Ref(), A.Ref(), state => A.ref_settle(A.aim.mid_fuel(A.aim.self_live(actor, target, shell)), state), A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.ref_hp(world, seats, target, shell), A.ref_subtract(A.aim.before(seats, target), A.aim.ref_hp(world, seats, target, shell)), A.aim.ref_damage(world)), A.aim.rs_mid(world, seats, actor, target, shell, rest, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world)), aimstep.bridge(world, seats, actor, target, shell, rest)), eq)), valid)

def aimstep.shot(+world: S.World, +seats: A.Seats(), +actor: D.Seat, +target: D.Seat, +index: Nat, +shell: D.Shell, +rest: List<&2, D.Shell>, +phase: S.Phase, +present_a: P.seated(D.ring.table(A.CoreSeat, seats), actor), +present_t: P.seated(D.ring.table(A.CoreSeat, seats), target), +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> Sigma<&2, &2, {A.ref_settle(96n, A.aim.psv(S.world.set_gun(world, shell <> rest), seats, actor, target, index)) == A.ref(M.shoot.loaded(A.pack(S.world.set_gun(world, shell <> rest), seats, phase, Nil{}), actor, target, shell, rest)) : A.Ref()}, _ => A.Valid(M.shoot.loaded(A.pack(S.world.set_gun(world, shell <> rest), seats, phase, Nil{}), actor, target, shell, rest))>:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      aimstep.shot_glue(world, seats, actor, target, index, shell, rest, phase, present_a, present_t, aimstep.mid(world, seats, actor, target, shell, rest, phase, A.aim.machine_hp(world, seats, target, shell), Q.subtract(A.aim.before(seats, target), A.aim.machine_hp(world, seats, target, shell)), A.aim.machine_damage(world), present_a, present_t, supported, bounded, synced))

def aimstep.pick_shot(+world: S.World, +seats: A.Seats(), +actor: D.Seat, +target: D.Seat, +index: Nat, +shell: D.Shell, +rest: List<&2, D.Shell>, bundle: Sigma<&2, &2, {A.ref_settle(96n, A.aim.psv(S.world.set_gun(world, shell <> rest), seats, actor, target, index)) == A.ref(M.shoot.loaded(A.pack(S.world.set_gun(world, shell <> rest), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, Nil{}), actor, target, shell, rest)) : A.Ref()}, _ => A.Valid(M.shoot.loaded(A.pack(S.world.set_gun(world, shell <> rest), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, Nil{}), actor, target, shell, rest))>) -> Sigma<&2, &2, {A.ref_stepped(A.ref_settle(96n, A.aim.psv(S.world.set_gun(world, shell <> rest), seats, actor, target, index))) == A.machine_ref_step(M.shoot.loaded(A.pack(S.world.set_gun(world, shell <> rest), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, Nil{}), actor, target, shell, rest)) : A.RefStep()}, _ => A.Valid(M.shoot.loaded(A.pack(S.world.set_gun(world, shell <> rest), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, Nil{}), actor, target, shell, rest))>:
  match bundle:
    case Tuple{eq, valid}:
      (Equal.trans(A.RefStep(), A.ref_stepped(A.ref_settle(96n, A.aim.psv(S.world.set_gun(world, shell <> rest), seats, actor, target, index))), A.ref_stepped(A.ref(M.shoot.loaded(A.pack(S.world.set_gun(world, shell <> rest), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, Nil{}), actor, target, shell, rest))), A.machine_ref_step(M.shoot.loaded(A.pack(S.world.set_gun(world, shell <> rest), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, Nil{}), actor, target, shell, rest)), Equal.cong(A.Ref(), A.RefStep(), A.ref_stepped, A.ref_settle(96n, A.aim.psv(S.world.set_gun(world, shell <> rest), seats, actor, target, index)), A.ref(M.shoot.loaded(A.pack(S.world.set_gun(world, shell <> rest), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, Nil{}), actor, target, shell, rest)), eq), loadproof.step_ref_commutes(M.shoot.loaded(A.pack(S.world.set_gun(world, shell <> rest), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, Nil{}), actor, target, shell, rest))), valid)

def aimstep.pick_allowed(+allowed: Bool, +world: S.World, +seats: A.Seats(), +actor: D.Seat, +target: D.Seat, +index: Nat, +selected: {Q.target.nth(Q.targets(D.ring.entries(Nat, A.seats.health(seats))), index) == Some{S.Target{target}} : Maybe<&2, S.TargetOption>}, +present_a: P.seated(D.ring.table(A.CoreSeat, seats), actor), +present_t: P.seated(D.ring.table(A.CoreSeat, seats), target), +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> Sigma<&2, &2, {A.aim.ref_accepting(world, seats, actor, D.Choice{actor, index, D.Shoot{target}}, allowed) == A.stepped(S.state.stepped(M.answer.aim(A.aim.state(world, seats, actor, Nil{}), actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats))), index, allowed))) : A.RefStep()}, _ => A.Valid(M.answer.aim(A.aim.state(world, seats, actor, Nil{}), actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats))), index, allowed))>:
  match allowed world:
    case False{} S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      (Equal.cong(A.Seats(), A.RefStep(), restored => A.ref_stepped(A.raw_state(world, restored, S.Blocked{}, Nil{})), seats, seats, {==}), pack_valid(world, seats, S.Blocked{}, Nil{}, aimstep.stable_synced(world, seats, synced, supported, bounded), {==}, {==}))
    case True{} S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}:
      %Equal.sym(Maybe<&2, S.TargetOption>, Q.target.nth(Q.targets(D.ring.entries(Nat, A.seats.health(seats))), index), Some{S.Target{target}}, selected) : Sigma<&2, &2, {A.aim.ref_accepting(world, seats, actor, D.Choice{actor, index, D.Shoot{target}}, True{}) == A.stepped(S.state.stepped(M.aim.selected(A.aim.state(world, seats, actor, Nil{}), actor, _))) : A.RefStep()}, _ => A.Valid(M.aim.selected(A.aim.state(world, seats, actor, Nil{}), actor, _))>
      (Equal.cong(A.Seats(), A.RefStep(), restored => A.ref_stepped(A.raw_state(world, restored, S.Blocked{}, Nil{})), seats, seats, {==}), pack_valid(world, seats, S.Blocked{}, Nil{}, aimstep.stable_synced(world, seats, synced, supported, bounded), {==}, {==}))
    case True{} S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, +shell <> +rest, shown, deck}:
      %Equal.sym(Maybe<&2, S.TargetOption>, Q.target.nth(Q.targets(D.ring.entries(Nat, A.seats.health(seats))), index), Some{S.Target{target}}, selected) : Sigma<&2, &2, {A.aim.ref_accepting(world, seats, actor, D.Choice{actor, index, D.Shoot{target}}, True{}) == A.stepped(S.state.stepped(M.aim.selected(A.aim.state(world, seats, actor, Nil{}), actor, _))) : A.RefStep()}, _ => A.Valid(M.aim.selected(A.aim.state(world, seats, actor, Nil{}), actor, _))>
      aimstep.pick_shot(world, seats, actor, target, index, shell, rest, aimstep.shot(world, seats, actor, target, index, shell, rest, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, present_a, present_t, supported, bounded, synced))

def aimstep.pick(+world: S.World, +seats: A.Seats(), +actor: D.Seat, +target: D.Seat, +index: Nat, +selected: {Q.target.nth(Q.targets(D.ring.entries(Nat, A.seats.health(seats))), index) == Some{S.Target{target}} : Maybe<&2, S.TargetOption>}, +present_a: P.seated(D.ring.table(A.CoreSeat, seats), actor), +present_t: P.seated(D.ring.table(A.CoreSeat, seats), target), +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +synced: {S.world.table(world) == D.ring.table(A.CoreSeat, seats) : D.Table}) -> Sigma<&2, &2, {A.aim.ref_pick(world, seats, actor, D.Choice{actor, index, D.Shoot{target}}) == A.stepped(S.state.stepped(M.answer.aim(A.aim.state(world, seats, actor, Nil{}), actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats))), index, Q.accepted(A.aim.state(world, seats, actor, Nil{}), actor)))) : A.RefStep()}, _ => A.Valid(M.answer.aim(A.aim.state(world, seats, actor, Nil{}), actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats))), index, Q.accepted(A.aim.state(world, seats, actor, Nil{}), actor)))>:
  %idleproof.idle_guards(world, seats, actor) : Sigma<&2, &2, {A.aim.ref_pick(world, seats, actor, D.Choice{actor, index, D.Shoot{target}}) == A.stepped(S.state.stepped(M.answer.aim(A.aim.state(world, seats, actor, Nil{}), actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats))), index, _))) : A.RefStep()}, _ => A.Valid(M.answer.aim(A.aim.state(world, seats, actor, Nil{}), actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats))), index, _))>
  aimstep.pick_allowed(A.raw_accepted(world, seats, actor), world, seats, actor, target, index, selected, present_a, present_t, supported, bounded, synced)

def aimstep.front_stable(+world: S.World, +seats: A.Seats(), supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}) -> A.Stable(A.world_for(world, seats), seats):
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      ({==}, (supported, bounded))

# Split the ring shape, each seat health (0n or 1n+_) and the tape answer until the menu, the chosen index and the target are concrete.
def aimstep.front(+world: S.World, +seats: A.Seats(), +actor: D.Seat, +notes: A.Notes(), +n: Nat, +supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}) -> Sigma<&2, &2, {A.ref_answer(A.ref(A.aim.state(A.world_for(world, seats), seats, actor, notes)), n) == A.stepped(M.answer(A.aim.state(A.world_for(world, seats), seats, actor, notes), n)) : A.RefStep()}, _ => A.Valid(A.next(A.aim.state(A.world_for(world, seats), seats, actor, notes), n))>:
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats actor:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Duo{A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat1{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Duo{A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Duo{A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Duo{A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Duo{A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat3{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Duo{A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Duo{A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Duo{A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat0{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat1{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat2{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat0{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 3n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 4n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 3n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat1{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 3n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 4n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 3n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat2{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 3n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 4n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 3n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat3{}:
          ({==}, pack_valid(A.world_for(world, seats), seats, S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{0n, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{0n, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{0n, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{0n, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
        case D.Quad{A.CoreSeat{1n+h0, j0, c0, p0, s0, t0}, A.CoreSeat{1n+h1, j1, c1, p1, s1, t1}, A.CoreSeat{1n+h2, j2, c2, p2, s2, t2}, A.CoreSeat{1n+h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          match n:
            case 0n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat0{}, 0n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 1n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat1{}, 1n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 2n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat2{}, 2n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 3n:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 3n, {==}, Unit{}, Unit{}, supported, bounded, {==})
            case 4n+more:
              aimstep.pick(A.world_for(world, seats), seats, actor, D.Seat3{}, 3n, {==}, Unit{}, Unit{}, supported, bounded, {==})

def aimstep.next_valid(+state: S.State, +n: Nat, normal: {A.normalize(state) == state : S.State}, next_valid: A.Valid(A.next(A.normalize(state), n))) -> A.Valid(A.next(state, n)):
  %normal : A.Valid(A.next(_, n))
  next_valid

def aimstep.finish(+world: S.World, +players: S.Players, +actor: D.Seat, +targets: List<&2, S.TargetOption>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.Aim{actor, targets}, notes, grabs}), +normal: {A.normalize(S.State{world, players, S.Aim{actor, targets}, notes, grabs}) == S.State{world, players, S.Aim{actor, targets}, notes, grabs} : S.State}, bundle: Sigma<&2, &2, {A.ref_answer(A.ref(A.aim.state(A.world_for(world, A.core(players)), A.core(players), actor, notes)), n) == A.stepped(M.answer(A.aim.state(A.world_for(world, A.core(players)), A.core(players), actor, notes), n)) : A.RefStep()}, _ => A.Valid(A.next(A.aim.state(A.world_for(world, A.core(players)), A.core(players), actor, notes), n))>) -> A.Simulation(S.State{world, players, S.Aim{actor, targets}, notes, grabs}, n):
  match bundle:
    case Tuple{eq, next_valid}:
      simulation_build(S.State{world, players, S.Aim{actor, targets}, notes, grabs}, n, result_original(S.State{world, players, S.Aim{actor, targets}, notes, grabs}, n, valid, eq), aimstep.next_valid(S.State{world, players, S.Aim{actor, targets}, notes, grabs}, n, normal, next_valid))


def step_aim(+world: S.World, +players: S.Players, +actor: D.Seat, +targets: List<&2, S.TargetOption>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.Aim{actor, targets}, notes, grabs})) -> A.Simulation(S.State{world, players, S.Aim{actor, targets}, notes, grabs}, n):
  match valid:
    case Tuple{+normal, Tuple{+supported, Tuple{+bounded, ready}}}:
      aimstep.finish(world, players, actor, targets, notes, grabs, n, valid, normal, aimstep.front(world, A.core(players), actor, notes, n, supported, bounded))
