import Base
import ./domain.bend as D
import ./abstract.bend as A
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./sm/items.bend as I
import ./sm/rules.bend as G
import ./sm/point.bend as V
import ./simple/main.bend as N
import ./simple/state.bend as T
import ./simple/point.bend as P
import ./simple-abstract.bend as SA
import ./simple-step-proof.bend as C
import ./simple-walk-proof.bend as Wk
import ./simple-loop-proof.bend as L
import ./simple-refine-proof.bend as Rf
import ./simple-idle-proof.bend as Id
import ./items-proof.bend as Items
import ./core-proof.bend as Core
import ./simple-misc-proof.bend as Mi

# Validity of the simple machine's states, from sm's step law: every sm
# answer from a valid state is valid, and a simple answer is sm's walk.

def canon.notes(+w: S.World, +p: S.Players, ph: S.Phase, +n: List<&2, D.Note>, +d: List<&2, D.Note>, +g: S.Grabs) -> {A.canonical_phase_items(S.State{w, p, ph, d, g}, ph) == A.canonical_phase_items(S.State{w, p, ph, n, g}, ph) : S.Phase}:
  match ph:
    case S.NeedFirst{}:
      {==}
    case S.NeedHealth{}:
      {==}
    case S.NeedAmount{}:
      {==}
    case S.NeedBatch{}:
      {==}
    case S.NeedSwap{a, b, 0n}:
      {==}
    case S.NeedSwap{a, b, 1n+k}:
      {==}
    case S.Idle{a, b}:
      {==}
    case S.Aim{a}:
      {==}
    case S.Ended{}:
      {==}
    case S.Blocked{a}:
      {==}
    case S.NeedTurnAmount{a, b, c}:
      {==}
    case S.Grab{a}:
      {==}
    case S.NeedItem{a, b, c, d}:
      {==}
    case S.NeedPhone{a, b, c}:
      {==}
    case S.JamPick{a, b}:
      {==}
    case S.StealPick{a, b}:
      {==}

def valid.notes(+w: S.World, +p: S.Players, +ph: S.Phase, +n: List<&2, D.Note>, +d: List<&2, D.Note>, g: S.Grabs, valid: A.Valid(S.State{w, p, ph, n, g})) -> A.Valid(S.State{w, p, ph, d, g}):
  match g:
    case S.Grabs{+g0, +g1, +g2, +g3, +g4}:
      match valid:
        case Tuple{+en, rest}:
          +ec : {A.canonical_phase_items(S.State{w, p, ph, n, S.Grabs{g0, g1, g2, g3, g4}}, ph) == ph : S.Phase} = Equal.cong(S.State, S.Phase, S.state.phase, A.normalize_items(S.State{w, p, ph, n, S.Grabs{g0, g1, g2, g3, g4}}), S.State{w, p, ph, n, S.Grabs{g0, g1, g2, g3, g4}}, en)
          (Equal.cong(S.Phase, S.State, x => S.State{w, p, x, d, S.Grabs{g0, g1, g2, g3, g4}}, A.canonical_phase_items(S.State{w, p, ph, d, S.Grabs{g0, g1, g2, g3, g4}}, ph), ph, Equal.trans(S.Phase, A.canonical_phase_items(S.State{w, p, ph, d, S.Grabs{g0, g1, g2, g3, g4}}, ph), A.canonical_phase_items(S.State{w, p, ph, n, S.Grabs{g0, g1, g2, g3, g4}}, ph), ph, canon.notes(w, p, ph, n, d, S.Grabs{g0, g1, g2, g3, g4}), ec)), rest)

def start.valid(+config: D.Config) -> A.Valid(M.stepped.state(M.start(config))):
  match config:
    case D.Config{D.TwoSeats{}, +plan}:
      ({==}, (({==}, ({==}, ({==}, ({==}, {==})))), (Core.plan_nonempty(plan), Core.plan_nonempty(plan))))
    case D.Config{D.ThreeSeats{}, +plan}:
      ({==}, (({==}, ({==}, ({==}, ({==}, {==})))), (Core.plan_nonempty(plan), Core.plan_nonempty(plan))))
    case D.Config{D.FourSeats{}, +plan}:
      ({==}, (({==}, ({==}, ({==}, ({==}, {==})))), (Core.plan_nonempty(plan), Core.plan_nonempty(plan))))

def WV(steps: List<&2, SA.Step>) -> Type:
  @+x:S.State -> @+valid:A.Valid(x) -> @+z:S.State -> @+d:List<&2, D.Note> -> @e:{SA.walk.go(steps, x) == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>} -> A.Valid(z)

def stepped.first(st: Maybe<&2, D.Stepped<&2, S.State>>, +fallback: S.State) -> S.State:
  match st:
    case Some{D.Stepped{s, n}}:
      s
    case None{}:
      fallback

def some.state(+a: S.State, +n: List<&2, D.Note>, +z: S.State, +d: List<&2, D.Note>, e: {Some{D.Stepped{a, n}} == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> {a == z : S.State}:
  Equal.cong(Maybe<&2, D.Stepped<&2, S.State>>, S.State, r => stepped.first(r, a), Some{D.Stepped{a, n}}, Some{D.Stepped{z, d}}, e)

def valid.cast(+a: S.State, +z: S.State, e: {a == z : S.State}, valid: A.Valid(a)) -> A.Valid(z):
  %e : A.Valid(_)
  valid

def next.valid(+step: D.Stepped<&2, S.State>, valid: A.Valid(A.machine_step_state(step))) -> A.Valid(M.stepped.state(step)):
  match step:
    case D.Stepped{state, notes}:
      valid

def merge.inv(st0: D.Stepped<&2, S.State>, rr: Maybe<&2, D.Stepped<&2, S.State>>, +z: S.State, +d: List<&2, D.Note>, e: {SA.walk.merge(st0, rr) == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> Sigma<&2, &2, List<&2, D.Note>, d2 => {rr == Some{D.Stepped{z, d2}} : Maybe<&2, D.Stepped<&2, S.State>>}>:
  match st0 rr:
    case D.Stepped{a, f} None{}:
      Wk.absurd(Sigma<&2, &2, List<&2, D.Note>, d2 => {None{} == Some{D.Stepped{z, d2}} : Maybe<&2, D.Stepped<&2, S.State>>}>, Wk.maybe.clash(D.Stepped<&2, S.State>, D.Stepped{z, d}, e))
    case D.Stepped{a, +f} Some{D.Stepped{+s, +n}}:
      +es : {s == z : S.State} = some.state(s, List.append(&2, D.Note, f, n), z, d, e)
      (n, Equal.cong(S.State, Maybe<&2, D.Stepped<&2, S.State>>, v => Some{D.Stepped{v, n}}, s, z, es))

def valid.after(+x1: S.State, +rest: List<&2, SA.Step>, ih: WV(rest), +v1: A.Valid(x1), +z: S.State, found: Sigma<&2, &2, List<&2, D.Note>, d2 => {SA.walk.go(rest, x1) == Some{D.Stepped{z, d2}} : Maybe<&2, D.Stepped<&2, S.State>>}>) -> A.Valid(z):
  match found:
    case Tuple{+d2, +e2}:
      ih(x1, v1, z, d2, e2)

def valid.ans(+x: S.State, +valid: A.Valid(x), +rest: List<&2, SA.Step>, ih: WV(rest), r: Maybe<&2, Nat>, +z: S.State, +d: List<&2, D.Note>, e: {SA.walk.answer(r, x, next => SA.walk.go(rest, next)) == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> A.Valid(z):
  match r:
    case None{}:
      Wk.absurd(A.Valid(z), Wk.maybe.clash(D.Stepped<&2, S.State>, D.Stepped{z, d}, e))
    case Some{+k}:
      valid.after(M.stepped.state(M.answer(x, k)), rest, ih, next.valid(M.answer(x, k), A.simulation.next(x, k, Items.step.items(x, k, valid))), z, merge.inv(M.answer(x, k), SA.walk.go(rest, M.stepped.state(M.answer(x, k))), z, d, e))

def valid.go(steps: List<&2, SA.Step>) -> WV(steps):
  match steps:
    case Nil{}:
      +x => +valid => +z => +d => e => valid.cast(x, z, some.state(x, Nil{}, z, d, e), valid)
    case +st <> +rest:
      +x => +valid => +z => +d => e => valid.ans(x, valid, rest, valid.go(rest), SA.walk.legal(M.request(x), st), z, d, e)

def setn.valid(z: S.State, +d: List<&2, D.Note>, valid: A.Valid(z)) -> A.Valid(S.state.set_notes(z, d)):
  match z:
    case S.State{+w, +p, +ph, +n, +g}:
      valid.notes(w, p, ph, n, d, g, valid)

def walknotes.valid(+x: S.State, +valid: A.Valid(x), +steps: List<&2, SA.Step>, r: Maybe<&2, D.Stepped<&2, S.State>>, +er: {SA.walk.go(steps, x) == r : Maybe<&2, D.Stepped<&2, S.State>>}, +z: S.State, +d: List<&2, D.Note>, e: {SA.walk.notes(r) == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> A.Valid(z):
  match r:
    case None{}:
      Wk.absurd(A.Valid(z), Wk.maybe.clash(D.Stepped<&2, S.State>, D.Stepped{z, d}, e))
    case Some{D.Stepped{+z2, +d2}}:
      valid.cast(S.state.set_notes(z2, d2), z, some.state(S.state.set_notes(z2, d2), d2, z, d, e), setn.valid(z2, d2, valid.go(steps)(x, valid, z2, d2, er)))

def walk.valid(steps: List<&2, SA.Step>, +x: S.State, +valid: A.Valid(x), +z: S.State, +d: List<&2, D.Note>, e: {SA.walk(x, steps) == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> A.Valid(z):
  match steps:
    case Nil{}:
      valid.cast(x, z, some.state(x, Nil{}, z, d, e), valid)
    case +st <> +rest:
      walknotes.valid(x, valid, st <> rest, SA.walk.go(st <> rest, x), {==}, z, d, e)

def notes.of(st: D.Stepped<&2, T.State>) -> List<&2, D.Note>:
  match st:
    case D.Stepped{_, n}:
      n

def lift.inv(+st: D.Stepped<&2, T.State>) -> {SA.lift(st) == Some{D.Stepped{SA.embed(N.stepped.state(st)), notes.of(st)}} : Maybe<&2, D.Stepped<&2, S.State>>}:
  match st:
    case D.Stepped{s, n}:
      {==}

def simple.valid(+s: T.State, +valid: A.Valid(SA.embed(s)), +n: Nat) -> A.Valid(SA.embed(N.stepped.state(N.answer(s, n)))):
  +ans : D.Stepped<&2, T.State> = N.answer(s, n)
  walk.valid(SA.chain(s, n), SA.embed(s), valid, SA.embed(N.stepped.state(ans)), notes.of(ans), Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk(SA.embed(s), SA.chain(s, n)), SA.lift(ans), Some{D.Stepped{SA.embed(N.stepped.state(ans)), notes.of(ans)}}, Id.refines(s, n), lift.inv(ans)))

def SRV(fuel: Nat) -> Type:
  @+state:T.State -> @+tape:List<&2, Nat> -> @+valid:A.Valid(SA.embed(state)) -> A.Valid(SA.embed(SA.ran.state(N.run(fuel, state, tape))))

def merge.state(st: D.Stepped<&2, T.State>, r: D.Ran<&2, T.State>) -> {SA.ran.state(N.run.merge(st, r)) == SA.ran.state(r) : T.State}:
  match st r:
    case D.Stepped{a, f} D.Ran{s, n, t}:
      {==}

def ran.valid.cast(+a: T.State, +b: T.State, e: {a == b : T.State}, valid: A.Valid(SA.embed(b))) -> A.Valid(SA.embed(a)):
  %Equal.sym(T.State, a, b, e) : A.Valid(SA.embed(_))
  valid

def run.zero(request: T.Request, +state: T.State, tape: List<&2, Nat>, +valid: A.Valid(SA.embed(state))) -> A.Valid(SA.embed(SA.ran.state(N.run.request(0n, request, state, tape)))):
  match request tape:
    case T.Finished{} Nil{}:
      valid
    case T.Finished{} m <> ms:
      valid
    case T.Stuck{} Nil{}:
      valid
    case T.Stuck{} m <> ms:
      valid
    case T.Draw{a, b} Nil{}:
      valid
    case T.Draw{a, b} m <> ms:
      valid
    case T.Choose{a, b} Nil{}:
      valid
    case T.Choose{a, b} m <> ms:
      valid

def run.succ(+f: Nat, request: T.Request, +state: T.State, tape: List<&2, Nat>, +valid: A.Valid(SA.embed(state)), recur: SRV(f)) -> A.Valid(SA.embed(SA.ran.state(N.run.request(1n+f, request, state, tape)))):
  match request tape:
    case T.Finished{} Nil{}:
      valid
    case T.Finished{} m <> ms:
      valid
    case T.Stuck{} Nil{}:
      valid
    case T.Stuck{} m <> ms:
      valid
    case T.Draw{a, b} Nil{}:
      valid
    case T.Choose{a, b} Nil{}:
      valid
    case T.Draw{a, b} +n <> +rest:
      +next : T.State = N.stepped.state(N.answer(state, n))
      ran.valid.cast(SA.ran.state(N.run.merge(N.answer(state, n), N.run(f, next, rest))), SA.ran.state(N.run(f, next, rest)), merge.state(N.answer(state, n), N.run(f, next, rest)), recur(next, rest, simple.valid(state, valid, n)))
    case T.Choose{a, b} +n <> +rest:
      +next : T.State = N.stepped.state(N.answer(state, n))
      ran.valid.cast(SA.ran.state(N.run.merge(N.answer(state, n), N.run(f, next, rest))), SA.ran.state(N.run(f, next, rest)), merge.state(N.answer(state, n), N.run(f, next, rest)), recur(next, rest, simple.valid(state, valid, n)))

def run.valid(fuel: Nat) -> SRV(fuel):
  match fuel:
    case 0n:
      +state => +tape => +valid => run.zero(N.request(state), state, tape, valid)
    case 1n+(+f):
      +state => +tape => +valid => run.succ(f, N.request(state), state, tape, valid, run.valid(f))

def start.embed(+config: D.Config) -> {SA.embed(N.stepped.state(N.start(config))) == M.stepped.state(M.start(config)) : S.State}:
  some.state(SA.embed(N.stepped.state(N.start(config))), notes.of(N.start(config)), M.stepped.state(M.start(config)), S.state.notes(M.stepped.state(M.start(config))), Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, Some{D.Stepped{SA.embed(N.stepped.state(N.start(config))), notes.of(N.start(config))}}, SA.lift(N.start(config)), Some{M.start(config)}, Equal.sym(Maybe<&2, D.Stepped<&2, S.State>>, SA.lift(N.start(config)), Some{D.Stepped{SA.embed(N.stepped.state(N.start(config))), notes.of(N.start(config))}}, lift.inv(N.start(config))), Mi.start.eq(config)))

def reachable.valid(fuel: Nat, +config: D.Config, +tape: List<&2, Nat>) -> A.Valid(SA.embed(SA.ran.state(N.run(fuel, N.stepped.state(N.start(config)), tape)))):
  run.valid(fuel)(N.stepped.state(N.start(config)), tape, valid.cast(M.stepped.state(M.start(config)), SA.embed(N.stepped.state(N.start(config))), Equal.sym(S.State, SA.embed(N.stepped.state(N.start(config))), M.stepped.state(M.start(config)), start.embed(config)), start.valid(config)))
