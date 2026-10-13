import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/main.bend as M
import ./sm/rules.bend as Q

law core_roundtrip:
  for +seats: A.Seats()
  {A.core(A.players(seats)) == seats : A.Seats()}

law pickup_matches:
  for +world: A.World()
  for +seats: A.Seats()
  for +seat: A.Seat()
  for +notes: A.Notes()
  for +n: Nat
  for +present: A.seated(world, seat)
  for accepted: {A.pickup_accepted(world, seats, seat, notes) == True{} : Bool}
  {A.ref_answer(A.ref(A.idle(world, seats, seat, notes)), n) == A.pickup_step(world, seats, seat, notes, n) : A.RefStep()}


law pickup_point_matches:
  for +world: A.World()
  for +seats: A.Seats()
  for +seat: A.Seat()
  for +notes: A.Notes()
  for +n: Nat
  for +present: A.seated(A.world_for(world, seats), seat)
  for accepted: {A.pickup_accepted(A.world_for(world, seats), seats, seat, notes) == True{} : Bool}
  {A.pickup_point(A.world_for(world, seats), seats, seat, notes, n) == A.ref_step_point(A.ref_answer(A.ref(A.idle(A.world_for(world, seats), seats, seat, notes)), n)) : A.RefPoint()}


law legal_play_exact:
  for +world: A.World()
  for +seats: A.Seats()
  for +seat: A.Seat()
  for +aiming: Bool
  for +notes: A.Notes()
  {A.machine_request(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)) == A.ref_request(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes))) : D.Request}


law observe_matches:
  for +world: A.World()
  for +seats: A.Seats()
  for +phase: A.Phase()
  for +notes: A.Notes()
  for +seat: A.Seat()
  {(A.observation(A.pack(A.world_for(world, seats), seats, phase, notes), seat), A.heard(A.pack(A.world_for(world, seats), seats, phase, notes), seat)) == (A.ref_observation(A.ref(A.pack(A.world_for(world, seats), seats, phase, notes)), seat), A.ref_heard(A.ref(A.pack(A.world_for(world, seats), seats, phase, notes)), seat)) : D.Obs & List<&2, D.Heard>}


law legal_exact:
  for +world: A.World()
  for +seats: A.Seats()
  for +phase: A.Phase()
  for +notes: A.Notes()
  {A.machine_request(A.canonical_state(world, seats, phase, notes)) == A.ref_request(A.ref(A.canonical_state(world, seats, phase, notes))) : D.Request}


law legal_accepted:
  for +world: A.World()
  for +seats: A.Seats()
  for +seat: A.Seat()
  for +aiming: Bool
  for +notes: A.Notes()
  for +n: Nat
  for +choice: D.Choice
  for present: A.seated(A.world_for(world, seats), seat)
  for selected: {D.resolve(A.machine_request(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)), n) == D.Chose{choice} : D.Resolved}
  for current: {A.current_matches(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)), A.choice_seat(choice)) == True{} : Bool}
  for permission: {A.has_turn(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)), A.choice_seat(choice)) == True{} : Bool}
  {A.verify(A.ref(A.play_state(A.world_for(world, seats), seats, seat, aiming, notes)), choice) == True{} : Bool}

law state_roundtrip:
  for +world: S.World
  for +seats: A.Seats()
  for +phase: A.RequestPhase
  for +notes: A.Notes()
  {A.back(A.ref(A.pack(world, seats, A.request_phase(phase, seats), notes))) == A.pack(world, seats, A.request_phase(phase, seats), notes) : S.State}


law turn_traversal:
  for +world: S.World
  for +seats: D.Ring<&2, A.CoreSeat>
  for +current: D.Seat
  {Q.next_turn(A.seats.health(seats), S.world.direction(world), current) == A.ref_turn(world, seats, current) : D.Seat}

law start_result_matches:
  for +config: D.Config
  for supported: {Q.config.no_items(config) == True{} : Bool}
  {A.ref_start(config) == A.stepped(M.start(config)) : A.RefStep()}

law privacy:
  for +state: S.State
  for +gun: List<&2, D.Shell>
  for decks: S.Decks
  for +seat: D.Seat
  for same_length: {List.length(&2, D.Shell, S.world.gun(S.state.world(state))) == List.length(&2, D.Shell, gun) : Nat}
  {(D.observe(M.point(state), seat), D.hear(S.state.notes(state), seat)) == (D.observe(M.point(M.replace_hidden(state, gun, decks)), seat), D.hear(S.state.notes(M.replace_hidden(state, gun, decks)), seat)) : D.Obs & List<&2, D.Heard>}


law jam_skip_once:
  for +world: S.World
  for +seats: A.Seats()
  for +seat: D.Seat
  for +notes: A.Notes()
  ({A.grant.dispatch(A.grant.pass(world, seats, seat, notes)) == A.grant.pass_case(world, A.grant.jam(seats, seat), seat, notes) : A.Ref()} & A.grant.once_claim(A.grant.jam(seats, seat), seat))


law start_matches:
  for +config: D.Config
  for +supported: {Q.config.no_items(config) == True{} : Bool}
  A.StartSimulation(config)


# One answer at a valid request point: the reference (answer plus its bounded
# silent closure) and the machine reach corresponding request points with the
# same notes, the same Point, and the machine still valid.
law step_matches:
  for +state: S.State
  for +n: Nat
  for +valid: A.Valid(state)
  Sigma<&2, &2, {A.ref_answer(A.ref(state), n) == A.stepped(M.answer(state, n)) : A.RefStep()}, _ => Sigma<&2, &2, {M.point(A.next(state, n)) == A.ref_step_point(A.ref_answer(A.ref(state), n)) : D.Point}, _ => A.Valid(A.next(state, n))>>

law run_matches:
  for fuel: Nat
  for +state: S.State
  for +tape: List<&2, Nat>
  for +valid: A.Valid(state)
  {A.ref_run(fuel, A.ref(state), tape) == A.ran(M.run(fuel, state, tape)) : A.RefRan()}

# Every state the machine reaches from a no-item start is valid.
law reachable_valid:
  for fuel: Nat
  for +config: D.Config
  for +supported: {Q.config.no_items(config) == True{} : Bool}
  for +tape: List<&2, Nat>
  A.Valid(A.machine_ran_state(M.run(fuel, M.stepped.state(M.start(config)), tape)))
