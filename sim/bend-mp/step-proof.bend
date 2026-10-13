import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/main.bend as M
import ./LAWS.bend as Laws
import ./core-proof.bend as C
import ./item-step-proof.bend as ISP
import ./items-proof.bend as Items

# The run, start and game laws over the item invariant A.ValidItems, from
# the one-answer step (items-proof.bend) by induction on the fuel.

def request.of(point: D.Point) -> D.Request:
  match point:
    case D.Point{request, _}:
      request

def valid.request(+state: S.State, +valid: A.ValidItems(state)) -> {A.machine_request(state) == A.ref_request(A.ref(state)) : D.Request}:
  Equal.cong(D.Point, D.Request, request.of, A.machine_point(state), A.point_of_ref(state), ISP.point.items(state, valid))

def merge_final_valid(+step: D.Stepped<&2, S.State>, +ran: D.Ran<&2, S.State>, valid: A.ValidItems(A.machine_ran_state(ran))) -> A.ValidItems(A.machine_ran_state(M.run.merge(step, ran))):
  %Equal.sym(S.State, A.machine_ran_state(M.run.merge(step, ran)), A.machine_ran_state(ran), C.merge_final_state(step, ran)) : A.ValidItems(_)
  valid

def next_valid_transport(+step: D.Stepped<&2, S.State>, valid: A.ValidItems(A.machine_step_state(step))) -> A.ValidItems(M.stepped.state(step)):
  match step:
    case D.Stepped{state, notes}:
      valid

def run_glue(+fuel: Nat, +state: S.State, +tape: List<&2, Nat>, +valid: A.ValidItems(state), lifted: {A.ref_driver(fuel, A.machine_request(state), A.ref(state), tape) == A.ran(M.run(fuel, state, tape)) : A.RefRan()}) -> {A.ref_run(fuel, A.ref(state), tape) == A.ran(M.run(fuel, state, tape)) : A.RefRan()}:
  Equal.trans(A.RefRan(), A.ref_run(fuel, A.ref(state), tape), A.ref_driver(fuel, A.machine_request(state), A.ref(state), tape), A.ran(M.run(fuel, state, tape)), Equal.trans(A.RefRan(), A.ref_run(fuel, A.ref(state), tape), A.ref_driver(fuel, A.ref_request(A.ref(state)), A.ref(state), tape), A.ref_driver(fuel, A.machine_request(state), A.ref(state), tape), C.ref_run_driver(fuel, state, tape), Equal.cong(D.Request, A.RefRan(), request => A.ref_driver(fuel, request, A.ref(state), tape), A.ref_request(A.ref(state)), A.machine_request(state), Equal.sym(D.Request, A.machine_request(state), A.ref_request(A.ref(state)), valid.request(state, valid)))), lifted)

def run_successor(+fuel: Nat, +state: S.State, +n: Nat, +tape: List<&2, Nat>, +simulation: A.SimulationItems(state, n), recur: A.RunHypothesis(fuel)) -> {A.ref_merge(A.ref_answer(A.ref(state), n), A.ref_run(fuel, A.ref_next(A.ref_answer(A.ref(state), n)), tape)) == A.ran(A.machine_merge(M.answer(state, n), M.run(fuel, M.stepped.state(M.answer(state, n)), tape))) : A.RefRan()}:
  Equal.trans(A.RefRan(), A.ref_merge(A.ref_answer(A.ref(state), n), A.ref_run(fuel, A.ref_next(A.ref_answer(A.ref(state), n)), tape)), A.ref_merge(A.stepped(M.answer(state, n)), A.ref_run(fuel, A.ref_next(A.stepped(M.answer(state, n))), tape)), A.ran(A.machine_merge(M.answer(state, n), M.run(fuel, M.stepped.state(M.answer(state, n)), tape))), Equal.cong(A.RefStep(), A.RefRan(), next => A.ref_merge(next, A.ref_run(fuel, A.ref_next(next), tape)), A.ref_answer(A.ref(state), n), A.stepped(M.answer(state, n)), A.simulation.step(state, n, simulation)), C.merge_lift(M.answer(state, n), fuel, tape, C.next_run_transport(M.answer(state, n), fuel, tape, recur(A.next(state, n), tape, A.simulation.next(state, n, simulation)))))

def run_valid_zero(request: D.Request, +state: S.State, tape: List<&2, Nat>, valid: A.ValidItems(state)) -> A.ValidItems(A.machine_ran_state(M.run.request(0n, request, state, tape))):
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

def run_valid_successor(+fuel: Nat, +state: S.State, +n: Nat, +tape: List<&2, Nat>, simulation: A.SimulationItems(state, n), recur: A.RunValidHypothesis(fuel)) -> A.ValidItems(A.machine_ran_state(M.run.merge(M.answer(state, n), M.run(fuel, M.stepped.state(M.answer(state, n)), tape)))):
  merge_final_valid(M.answer(state, n), M.run(fuel, M.stepped.state(M.answer(state, n)), tape), recur(M.stepped.state(M.answer(state, n)), tape, next_valid_transport(M.answer(state, n), A.simulation.next(state, n, simulation))))

def run_request(+fuel: Nat, request: D.Request, +state: S.State, +tape: List<&2, Nat>, +valid: A.ValidItems(state), recur: A.RunHypothesis(fuel)) -> {A.ref_driver(1n+fuel, request, A.ref(state), tape) == A.ran(M.run.request(1n+fuel, request, state, tape)) : A.RefRan()}:
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
    case D.Choose{menus} Nil{}:
      {==}
    case D.Draw{kind, range} +n <> +rest:
      run_successor(fuel, state, n, rest, Items.step.items(state, n, valid), recur)
    case D.Choose{menus} +n <> +rest:
      run_successor(fuel, state, n, rest, Items.step.items(state, n, valid), recur)

def run_lift(+fuel: Nat) -> A.RunHypothesis(fuel):
  match fuel:
    case 0n:
      +state => +tape => +valid => run_glue(0n, state, tape, valid, C.run_zero(A.machine_request(state), state, tape))
    case 1n+rest:
      +state => +tape => +valid => run_glue(1n+rest, state, tape, valid, run_request(rest, A.machine_request(state), state, tape, valid, run_lift(rest)))

def run_valid_request(+fuel: Nat, request: D.Request, +state: S.State, tape: List<&2, Nat>, +valid: A.ValidItems(state), recur: A.RunValidHypothesis(fuel)) -> A.ValidItems(A.machine_ran_state(M.run.request(1n+fuel, request, state, tape))):
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
    case D.Choose{menus} Nil{}:
      valid
    case D.Draw{kind, range} +n <> +rest:
      run_valid_successor(fuel, state, n, rest, Items.step.items(state, n, valid), recur)
    case D.Choose{menus} +n <> +rest:
      run_valid_successor(fuel, state, n, rest, Items.step.items(state, n, valid), recur)

def run_valid(+fuel: Nat) -> A.RunValidHypothesis(fuel):
  match fuel:
    case 0n:
      +state => +tape => valid => run_valid_zero(M.request(state), state, tape, valid)
    case 1n+rest:
      +state => +tape => +valid => run_valid_request(rest, M.request(state), state, tape, valid, run_valid(rest))

def observe.valid(+state: S.State, +valid: A.ValidItems(state), +seat: D.Seat) -> {(A.observation(state, seat), A.heard(state, seat)) == (A.ref_observation(A.ref(state), seat), A.ref_heard(A.ref(state), seat)) : D.Obs & List<&2, D.Heard>}:
  match state:
    case S.State{+w, +p, +ph, +notes, +g}:
      Equal.cong(D.Point, D.Obs & List<&2, D.Heard>, point => (D.observe(point, seat), D.hear(notes, seat)), A.machine_point(S.State{w, p, ph, notes, g}), A.point_of_ref(S.State{w, p, ph, notes, g}), ISP.point.items(S.State{w, p, ph, notes, g}, valid))

def start.valid(+config: D.Config) -> A.ValidItems(A.machine_step_state(M.start(config))):
  match config:
    case D.Config{D.TwoSeats{}, +plan}:
      ({==}, (({==}, ({==}, ({==}, ({==}, {==})))), (C.plan_nonempty(plan), C.plan_nonempty(plan))))
    case D.Config{D.ThreeSeats{}, +plan}:
      ({==}, (({==}, ({==}, ({==}, ({==}, {==})))), (C.plan_nonempty(plan), C.plan_nonempty(plan))))
    case D.Config{D.FourSeats{}, +plan}:
      ({==}, (({==}, ({==}, ({==}, ({==}, {==})))), (C.plan_nonempty(plan), C.plan_nonempty(plan))))

def start.result(+config: D.Config) -> {A.ref_start(config) == A.stepped(M.start(config)) : A.RefStep()}:
  match config:
    case D.Config{D.TwoSeats{}, plan}:
      {==}
    case D.Config{D.ThreeSeats{}, plan}:
      {==}
    case D.Config{D.FourSeats{}, plan}:
      {==}

def start.simulation(+config: D.Config) -> A.StartSimulation(config):
  +result : {A.ref_start(config) == A.stepped(M.start(config)) : A.RefStep()} = start.result(config)
  +valid : A.ValidItems(A.machine_step_state(M.start(config))) = start.valid(config)
  (result, (Equal.trans(D.Point, A.ref_step_point(A.ref_start(config)), A.ref_step_point(A.stepped(M.start(config))), A.machine_point(A.machine_step_state(M.start(config))), Equal.cong(A.RefStep(), D.Point, A.ref_step_point, A.ref_start(config), A.stepped(M.start(config)), result), Equal.trans(D.Point, A.ref_step_point(A.stepped(M.start(config))), A.point_of_ref(A.machine_step_state(M.start(config))), A.machine_point(A.machine_step_state(M.start(config))), Equal.sym(D.Point, A.point_of_ref(A.machine_step_state(M.start(config))), A.ref_step_point(A.stepped(M.start(config))), C.point_stepped(M.start(config))), Equal.sym(D.Point, A.machine_point(A.machine_step_state(M.start(config))), A.point_of_ref(A.machine_step_state(M.start(config))), ISP.point.items(A.machine_step_state(M.start(config)), valid)))), valid))

def start.state_valid(+config: D.Config) -> A.ValidItems(M.stepped.state(M.start(config))):
  next_valid_transport(M.start(config), start.valid(config))

def Laws.step_matches(state, n, valid):
  Items.step.items(state, n, valid)

def Laws.run_matches(fuel, state, tape, valid):
  run_lift(fuel)(state, tape, valid)

def Laws.reachable_valid(fuel, config, tape):
  run_valid(fuel)(M.stepped.state(M.start(config)), tape, start.state_valid(config))

def Laws.legal_exact(state, valid):
  valid.request(state, valid)

def Laws.observe_matches(state, valid, seat):
  observe.valid(state, valid, seat)

def Laws.start_result_matches(config):
  start.result(config)

def Laws.start_matches(config):
  start.simulation(config)

def Laws.games_match(fuel, config, tape):
  +start : D.Stepped<&2, S.State> = M.start(config)
  +run : {A.ref_run(fuel, A.ref(M.stepped.state(start)), tape) == A.ran(M.run(fuel, M.stepped.state(start), tape)) : A.RefRan()} = run_lift(fuel)(M.stepped.state(start), tape, start.state_valid(config))
  Equal.trans(A.RefRan(), A.ref_game(fuel, config, tape), A.ref_merge(A.stepped(start), A.ref_run(fuel, A.ref_next(A.stepped(start)), tape)), A.ran(A.machine_game(fuel, config, tape)), Equal.cong(A.RefStep(), A.RefRan(), first => A.ref_merge(first, A.ref_run(fuel, A.ref_next(first), tape)), A.ref_start(config), A.stepped(start), start.result(config)), C.merge_lift(start, fuel, tape, run))
