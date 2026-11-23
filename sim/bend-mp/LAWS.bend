import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/main.bend as M
import ./sm/rules.bend as Q

# What a seat sees of the machine's board is what it sees of the reference's:
# a corollary of the Point equality that step_matches proves. The heard half
# holds by definition, since A.ref copies the machine's notes. That the notes
# are right, and go only to the seats that may hear them, rests on
# step_matches, which checks each step's notes against the reference.
law observe_matches:
  for +state: S.State
  for +valid: A.Valid(state)
  for +seat: D.Seat
  {(A.observation(state, seat), A.heard(state, seat)) == (A.ref_observation(A.ref(state), seat), A.ref_heard(A.ref(state), seat)) : D.Obs & List<&2, D.Heard>}


law legal_exact:
  for +state: S.State
  for +valid: A.Valid(state)
  {A.machine_request(state) == A.ref_request(A.ref(state)) : D.Request}


# Every move the machine offers at a valid state passes the host's
# MoveAllowed.
law legal_accepted:
  for +state: S.State
  for +valid: A.Valid(state)
  for +n: Nat
  for +choice: D.Choice
  for selected: {D.resolve(A.machine_request(state), n) == D.Chose{choice} : D.Resolved}
  {A.verify(A.ref(state), choice) == True{} : Bool}


# A.back inverts A.ref at every valid state: the mapping loses nothing.
law state_roundtrip:
  for +state: S.State
  for +valid: A.Valid(state)
  {A.back(A.ref(state)) == state : S.State}


law turn_traversal:
  for +world: S.World
  for +seats: D.Ring<&2, A.CoreSeat>
  for +current: D.Seat
  {Q.next_turn(A.seats.health(seats), S.world.direction(world), current) == A.ref_turn(world, seats, current) : D.Seat}

law start_result_matches:
  for +config: D.Config
  {A.ref_start(config) == A.stepped(M.start(config)) : A.RefStep()}

# Replacing the hidden gun (with one of the same length) and the decks leaves
# what every seat sees of the board unchanged. The heard half holds by
# construction: M.replace_hidden changes only the gun and the decks, not the
# notes. Which notes a step writes is checked by step_matches against the
# reference, not by this law.
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

# Every state the machine reaches from a start is valid.
law reachable_valid:
  for fuel: Nat
  for +config: D.Config
  for +tape: List<&2, Nat>
  A.Valid(A.machine_ran_state(M.run(fuel, M.stepped.state(M.start(config)), tape)))

# Every machine game is a reference game, and the reverse: for every config
# and tape, the reference's game equals the machine's read through A.ran.
law games_match:
  for +fuel: Nat
  for +config: D.Config
  for +tape: List<&2, Nat>
  {A.ref_game(fuel, config, tape) == A.ran(A.machine_game(fuel, config, tape)) : A.RefRan()}
