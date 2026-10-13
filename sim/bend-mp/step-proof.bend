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
import ./LAWS.bend as Laws
import ./core-proof.bend as C

def step_swap(+world: S.World, +players: S.Players, +load: D.Load, +shells: List<&2, D.Shell>, +i: Nat, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedSwap{load, shells, i}, notes, grabs})) -> A.Simulation(S.State{world, players, S.NeedSwap{load, shells, i}, notes, grabs}, n):
  match i:
    case 0n:
      C.step_swap_zero(world, players, load, shells, notes, grabs, n, valid)
    case 1n:
      C.step_swap_last(world, players, load, shells, notes, grabs, n, valid)
    case 2n+extra:
      C.step_swap_more(world, players, load, shells, extra, notes, grabs, n, valid)

def step_phase(+world: S.World, +players: S.Players, +phase: S.Phase, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, phase, notes, grabs})) -> A.Simulation(S.State{world, players, phase, notes, grabs}, n):
  match phase:
    case S.NeedFirst{}:
      C.step_first(world, players, notes, grabs, n, valid)
    case S.NeedHealth{}:
      C.step_health(world, players, notes, grabs, n, valid)
    case S.NeedAmount{}:
      C.step_amount(world, players, notes, grabs, n, valid)
    case S.NeedBatch{}:
      C.step_batch(world, players, notes, grabs, n, valid)
    case S.NeedSwap{+load, +shells, +i}:
      step_swap(world, players, load, shells, i, notes, grabs, n, valid)
    case S.Idle{+actor, +options}:
      C.step_idle(world, players, actor, options, notes, grabs, n, valid)
    case S.Aim{+actor, +targets}:
      C.step_aim(world, players, actor, targets, notes, grabs, n, valid)
    case S.Ended{}:
      C.step_ended(world, players, notes, grabs, n, valid)
    case S.Blocked{+holder}:
      C.step_blocked(world, players, holder, notes, grabs, n, valid)
    case S.NeedTurnAmount{from, passing, winner}:
      C.step_item_phase(world, players, S.NeedTurnAmount{from, passing, winner}, notes, grabs, n, valid, {==}, {==})
    case S.Grab{needs}:
      C.step_item_phase(world, players, S.Grab{needs}, notes, grabs, n, valid, {==}, {==})
    case S.NeedItem{seat, first, second, rest}:
      C.step_item_phase(world, players, S.NeedItem{seat, first, second, rest}, notes, grabs, n, valid, {==}, {==})
    case S.NeedPhone{seat, owner, slot}:
      C.step_item_phase(world, players, S.NeedPhone{seat, owner, slot}, notes, grabs, n, valid, {==}, {==})
    case S.JamPick{seat, targets}:
      C.step_item_phase(world, players, S.JamPick{seat, targets}, notes, grabs, n, valid, {==}, {==})
    case S.StealPick{seat, picks}:
      C.step_item_phase(world, players, S.StealPick{seat, picks}, notes, grabs, n, valid, {==}, {==})

def step(+state: S.State, +n: Nat, +valid: A.Valid(state)) -> A.Simulation(state, n):
  match state:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      step_phase(world, players, phase, notes, grabs, n, valid)

def run_request(+fuel: Nat, request: D.Request, +state: S.State, +tape: List<&2, Nat>, +valid: A.Valid(state), recur: A.RunHypothesis(fuel)) -> {A.ref_driver(1n+fuel, request, A.ref(state), tape) == A.ran(M.run.request(1n+fuel, request, state, tape)) : A.RefRan()}:
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
      C.run_successor(fuel, state, n, rest, step(state, n, valid), recur)
    case D.Choose{menus} +n <> +rest:
      C.run_successor(fuel, state, n, rest, step(state, n, valid), recur)

def run_lift(+fuel: Nat) -> A.RunHypothesis(fuel):
  match fuel:
    case 0n:
      +state => +tape => +valid => C.run_glue(0n, state, tape, valid, C.run_zero(A.machine_request(state), state, tape))
    case 1n+rest:
      +state => +tape => +valid => C.run_glue(1n+rest, state, tape, valid, run_request(rest, A.machine_request(state), state, tape, valid, run_lift(rest)))

def run_valid_request(+fuel: Nat, request: D.Request, +state: S.State, tape: List<&2, Nat>, +valid: A.Valid(state), recur: A.RunValidHypothesis(fuel)) -> A.Valid(A.machine_ran_state(M.run.request(1n+fuel, request, state, tape))):
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
      C.run_valid_successor(fuel, state, n, rest, step(state, n, valid), recur)
    case D.Choose{menus} +n <> +rest:
      C.run_valid_successor(fuel, state, n, rest, step(state, n, valid), recur)

def run_valid(+fuel: Nat) -> A.RunValidHypothesis(fuel):
  match fuel:
    case 0n:
      +state => +tape => valid => C.run_valid_zero(M.request(state), state, tape, valid)
    case 1n+rest:
      +state => +tape => +valid => run_valid_request(rest, M.request(state), state, tape, valid, run_valid(rest))

def run_final_point(+fuel: Nat, +state: S.State, +tape: List<&2, Nat>, +valid: A.Valid(state)) -> {A.machine_point(A.machine_ran_state(M.run(fuel, state, tape))) == A.ref_ran_point(A.ref_run(fuel, A.ref(state), tape)) : D.Point}:
  Equal.trans(D.Point, A.machine_point(A.machine_ran_state(M.run(fuel, state, tape))), A.point_of_ref(A.machine_ran_state(M.run(fuel, state, tape))), A.ref_ran_point(A.ref_run(fuel, A.ref(state), tape)), C.point.valid(A.machine_ran_state(M.run(fuel, state, tape)), run_valid(fuel, state, tape, valid)), Equal.trans(D.Point, A.point_of_ref(A.machine_ran_state(M.run(fuel, state, tape))), A.ref_ran_point(A.ran(M.run(fuel, state, tape))), A.ref_ran_point(A.ref_run(fuel, A.ref(state), tape)), Equal.sym(D.Point, A.ref_ran_point(A.ran(M.run(fuel, state, tape))), A.point_of_ref(A.machine_ran_state(M.run(fuel, state, tape))), C.ran_point_commutes(M.run(fuel, state, tape))), Equal.cong(A.RefRan(), D.Point, ran => A.ref_ran_point(ran), A.ran(M.run(fuel, state, tape)), A.ref_run(fuel, A.ref(state), tape), Equal.sym(A.RefRan(), A.ref_run(fuel, A.ref(state), tape), A.ran(M.run(fuel, state, tape)), run_lift(fuel, state, tape, valid)))))


def Laws.step_matches(state, n, valid):
  step(state, n, valid)

def Laws.run_matches(fuel, state, tape, valid):
  run_lift(fuel)(state, tape, valid)
