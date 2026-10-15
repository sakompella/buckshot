import Base
import ./domain.bend as D
import ./abstract.bend as A
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./sm/items.bend as I
import ./sm/rules.bend as G
import ./simple/main.bend as N
import ./simple/state.bend as T
import ./simple/point.bend as P
import ./simple-abstract.bend as SA

# Proof tools for the simple machine's step: a simple function and its sm
# twin, run on the same records, agree. Notes are a snoc log on the simple
# side, so a run on a log with an earlier part `a` is the run on the later
# part with `a` put back in front (the frame), and the sm run on the later
# part's notes is the simple run embedded (the step).

def log.join(a: T.Log, b: T.Log) -> T.Log:
  match b:
    case T.Empty{}:
      a
    case T.Snoc{earlier, note}:
      T.Snoc{log.join(a, earlier), note}

def shift(a: T.Log, t: T.State) -> T.State:
  match t:
    case T.State{w, p, ph, l, g}:
      T.State{w, p, ph, log.join(a, l), g}

def calm(phase: T.Phase) -> Bool:
  match phase:
    case T.Stalled{}:
      False{}
    case _:
      True{}

# The sm run reached the simple run's state, not a stalled one.
def Direct(+u: T.State, +y: S.State) -> Data:
  Sigma<&2, &2, {y == SA.embed(u) : S.State}, _ => A.Holds(calm(T.state.phase(u)))>

# The sm run reached the simple run's state, or it opened a distribution at
# m, which the simple run then plays out.
def Rel(+u: T.State, +y: S.State) -> Data:
  Either<&2, &2, Direct(u, y), Sigma<&2, &2, T.State, m => Sigma<&2, &2, {y == SA.embed(T.state.set_phase(m, T.Stalled{})) : S.State}, _ => Sigma<&2, &2, {u == N.grab.distribute(m, S.world.first_turn(T.state.world(m))) : T.State}, _ => {S.grabs.distributing(T.state.grabs(m)) == True{} : Bool}>>>>

def Corr(-ft: T.State -> T.State, -fs: S.State -> S.State, a: T.Log, w: S.World, p: S.Players, ph: T.Phase, l: T.Log, g: S.Grabs, q: S.Phase) -> Data:
  Sigma<&2, &2, {ft(T.State{w, p, ph, log.join(a, l), g}) == shift(a, ft(T.State{w, p, ph, l, g})) : T.State}, _ => Rel(ft(T.State{w, p, ph, l, g}), fs(S.State{w, p, q, T.log.list(l), g}))>

def dist.set(+x: S.Grabs, +b: Bool) -> {S.grabs.distributing(S.grabs.set_distributing(x, b)) == b : Bool}:
  match x:
    case S.Grabs{d, gr, h, gt, i}:
      {==}

def DCorr(-ft: T.State -> T.State, -fs: S.State -> S.State, a: T.Log, w: S.World, p: S.Players, ph: T.Phase, l: T.Log, g: S.Grabs, q: S.Phase) -> Data:
  Sigma<&2, &2, {ft(T.State{w, p, ph, log.join(a, l), g}) == shift(a, ft(T.State{w, p, ph, l, g})) : T.State}, _ => Direct(ft(T.State{w, p, ph, l, g}), fs(S.State{w, p, q, T.log.list(l), g}))>

def dcorr.corr(-ft: T.State -> T.State, -fs: S.State -> S.State, +a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, c: DCorr(ft, fs, a, w, p, ph, l, g, q)) -> Corr(ft, fs, a, w, p, ph, l, g, q):
  match c:
    case Tuple{frame, direct}:
      (frame, Inl{direct})

def dframe.of(-ft: T.State -> T.State, -fs: S.State -> S.State, +a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, c: DCorr(ft, fs, a, w, p, ph, l, g, q)) -> {ft(T.State{w, p, ph, log.join(a, l), g}) == shift(a, ft(T.State{w, p, ph, l, g})) : T.State}:
  match c:
    case Tuple{e, _}:
      e

def direct.of(-ft: T.State -> T.State, -fs: S.State -> S.State, +a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, c: DCorr(ft, fs, a, w, p, ph, l, g, q)) -> Direct(ft(T.State{w, p, ph, l, g}), fs(S.State{w, p, q, T.log.list(l), g})):
  match c:
    case Tuple{_, d}:
      d

def give_turn.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat) -> DCorr(t => N.give_turn(t, seat), x => M.give_turn(x, seat), a, w, p, ph, l, g, q):
  ({==}, ({==}, {==}))

def grant_step.c(rank: Nat, +a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, result: S.JamResult) -> DCorr(t => N.grant.step(rank, t, seat, result), x => M.grant.step(rank, x, seat, result), a, w, p, ph, l, g, q):
  match rank result:
    case rank S.Act{players}:
      ({==}, ({==}, {==}))
    case rank S.Lift{players}:
      ({==}, ({==}, {==}))
    case 0n S.Skip{players}:
      ({==}, ({==}, {==}))
    case 1n+rest S.Skip{+players}:
      +next : D.Seat = G.next_turn(S.players.health(players), S.world.direction(w), seat)
      grant_step.c(rest, a, S.world.set_turn(w, Some{next}), players, ph, T.Snoc{l, D.Shown{D.TurnSkipped{seat}}}, g, q, next, G.jam(players, next))

def grant.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat) -> DCorr(t => N.grant(t, seat), x => M.grant(x, seat), a, w, p, ph, l, g, q):
  grant_step.c(G.jam_rank(p), a, S.world.set_turn(w, Some{seat}), p, ph, l, g, q, seat, G.jam(p, seat))

def shuffle.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +load: D.Load, +shells: List<&2, D.Shell>, i: Nat) -> DCorr(t => N.shuffle(t, load, shells, i), x => M.shuffle(x, load, shells, i), a, w, p, ph, l, g, q):
  match i:
    case 0n:
      +world : S.World = S.world.set_shown(S.world.set_gun(w, shells), load)
      grant.c(a, world, p, ph, T.Snoc{l, D.Shown{D.Loaded{load}}}, g, q, S.world.first_turn(world))
    case 1n+rest:
      ({==}, ({==}, {==}))

def batch_found.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +index: Nat, selected: Maybe<&2, S.Batch>) -> DCorr(t => N.batch.found(t, index, selected), x => M.batch.found(x, index, selected), a, w, p, ph, l, g, q):
  match selected:
    case None{}:
      ({==}, ({==}, {==}))
    case Some{S.Batch{_, sampled}}:
      +load : D.Load = G.load.actual(G.world.load_rule(w), sampled)
      +shells : List<&2, D.Shell> = G.load.shells(load)
      shuffle.c(a, S.world.set_deck(w, G.remove(S.Batch, S.world.deck(w), index)), p, ph, l, g, q, load, shells, G.predecessor(List.length(&2, D.Shell, shells)))

def batch.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +index: Nat) -> DCorr(t => N.batch(t, index), x => M.batch(x, index), a, w, p, ph, l, g, q):
  batch_found.c(a, w, p, ph, l, g, q, index, G.nth(S.Batch, S.world.deck(w), index))

def load_ready.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, deck: List<&2, S.Batch>) -> DCorr(t => N.load.ready(t, deck), x => M.load.ready(x, deck), a, w, p, ph, l, g, q):
  match deck:
    case Nil{}:
      ({==}, ({==}, {==}))
    case only <> Nil{}:
      batch.c(a, w, p, ph, l, g, q, 0n)
    case first <> next <> rest:
      ({==}, ({==}, {==}))

def load_refill.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, deck: List<&2, S.Batch>) -> DCorr(t => N.load.refill(t, deck), x => M.load.refill(x, deck), a, w, p, ph, l, g, q):
  match deck:
    case Nil{}:
      +world : S.World = S.world.set_decks(w, G.decks.full())
      load_ready.c(a, world, p, ph, l, g, q, S.world.deck(world))
    case first <> rest:
      load_ready.c(a, w, p, ph, l, g, q, first <> rest)

def load_begin.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase) -> DCorr(t => N.load.begin(t), x => M.load.begin(x), a, w, p, ph, l, g, q):
  +world : S.World = S.world.set_first_sequence(S.world.set_load_index(w, G.load.next(S.world.first_sequence(w), S.world.load_index(w))), False{})
  load_refill.c(a, world, p, ph, l, g, q, S.world.deck(world))

def frame.of(-ft: T.State -> T.State, -fs: S.State -> S.State, +a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, c: Corr(ft, fs, a, w, p, ph, l, g, q)) -> {ft(T.State{w, p, ph, log.join(a, l), g}) == shift(a, ft(T.State{w, p, ph, l, g})) : T.State}:
  match c:
    case Tuple{e, _}:
      e

def rel.of(-ft: T.State -> T.State, -fs: S.State -> S.State, +a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, c: Corr(ft, fs, a, w, p, ph, l, g, q)) -> Rel(ft(T.State{w, p, ph, l, g}), fs(S.State{w, p, q, T.log.list(l), g})):
  match c:
    case Tuple{_, r}:
      r

# The distribution loop's frame, by the fuel.
def FrameHyp(fuel: Nat) -> Type:
  @+a:T.Log -> @+w:S.World -> @+p:S.Players -> @+ph:T.Phase -> @+l:T.Log -> @+g:S.Grabs -> @+next:N.Distribution -> {N.grab.loop(fuel, T.State{w, p, ph, log.join(a, l), g}, next) == shift(a, N.grab.loop(fuel, T.State{w, p, ph, l, g}, next)) : T.State}

def check_done.frame(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, done: Bool) -> {N.grab.check.done(T.State{w, p, ph, log.join(a, l), g}, done) == shift(a, N.grab.check.done(T.State{w, p, ph, l, g}, done)) : T.State}:
  match done:
    case True{}:
      {==}
    case False{}:
      {==}

def check.frame(+a: T.Log, +t: T.State) -> {N.grab.check(shift(a, t)) == shift(a, N.grab.check(t)) : T.State}:
  match t:
    case T.State{+w, +p, +ph, +l, +g}:
      check_done.frame(a, w, p, ph, l, g, Bool.and(S.grabs.distributing(g), I.finished(S.State{w, p, S.Blocked{None{}}, Nil{}, g})))

def end_all.frame(seats: List<&2, D.Seat>, +a: T.Log, +t: T.State) -> {N.grab.end_all(seats, shift(a, t)) == shift(a, N.grab.end_all(seats, t)) : T.State}:
  match seats t:
    case Nil{} T.State{w, p, ph, l, g}:
      {==}
    case +seat <> rest T.State{+w, +p, +ph, +l, +g}:
      end_all.frame(rest, a, T.State{w, p, ph, T.Snoc{l, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})

def put_held.frame(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, held: Maybe<&2, D.Item>) -> {N.grab.put.held(T.State{w, p, ph, log.join(a, l), g}, seat, slot, held) == shift(a, N.grab.put.held(T.State{w, p, ph, l, g}, seat, slot, held)) : T.State}:
  match held:
    case None{}:
      {==}
    case Some{item}:
      {==}

def put.frame(+a: T.Log, +t: T.State, +seat: D.Seat, +slot: D.Slot) -> {N.grab.put(shift(a, t), seat, slot) == shift(a, N.grab.put(t, seat, slot)) : T.State}:
  match t:
    case T.State{+w, +p, +ph, +l, +g}:
      put_held.frame(a, w, p, ph, l, g, seat, slot, I.seat.holding(g, seat))

# What a last placement does after it ends the seat and checks completion.
def place.tail(+t: T.State, +seat: D.Seat, +slot: D.Slot) -> T.State:
  N.grab.put(N.grab.check(N.grab.end_all(I.stalled.seats(T.state.records(t), seat), t)), seat, slot)

def place_tail.frame(+a: T.Log, +t: T.State, +seat: D.Seat, +slot: D.Slot) -> {place.tail(shift(a, t), seat, slot) == shift(a, place.tail(t, seat, slot)) : T.State}:
  match t:
    case T.State{+w, +p, +ph, +l, +g}:
      +seats : List<&2, D.Seat> = I.stalled.seats(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, seat)
      +ended : T.State = N.grab.end_all(seats, T.State{w, p, ph, l, g})
      +checked : T.State = N.grab.check(ended)
      +e1 : {N.grab.check(N.grab.end_all(seats, shift(a, T.State{w, p, ph, l, g}))) == N.grab.check(shift(a, ended)) : T.State} = Equal.cong(T.State, T.State, x => N.grab.check(x), N.grab.end_all(seats, shift(a, T.State{w, p, ph, l, g})), shift(a, ended), end_all.frame(seats, a, T.State{w, p, ph, l, g}))
      +e2 : {N.grab.check(N.grab.end_all(seats, shift(a, T.State{w, p, ph, l, g}))) == shift(a, checked) : T.State} = Equal.trans(T.State, N.grab.check(N.grab.end_all(seats, shift(a, T.State{w, p, ph, l, g}))), N.grab.check(shift(a, ended)), shift(a, checked), e1, check.frame(a, ended))
      +e3 : {N.grab.put(N.grab.check(N.grab.end_all(seats, shift(a, T.State{w, p, ph, l, g}))), seat, slot) == N.grab.put(shift(a, checked), seat, slot) : T.State} = Equal.cong(T.State, T.State, x => N.grab.put(x, seat, slot), N.grab.check(N.grab.end_all(seats, shift(a, T.State{w, p, ph, l, g}))), shift(a, checked), e2)
      Equal.trans(T.State, N.grab.put(N.grab.check(N.grab.end_all(seats, shift(a, T.State{w, p, ph, l, g}))), seat, slot), N.grab.put(shift(a, checked), seat, slot), shift(a, N.grab.put(checked, seat, slot)), e3, put.frame(a, checked, seat, slot))

def place_last.frame(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, last: Bool) -> {N.grab.place.last(T.State{w, p, ph, log.join(a, l), g}, seat, slot, last) == shift(a, N.grab.place.last(T.State{w, p, ph, l, g}, seat, slot, last)) : T.State}:
  match last:
    case True{}:
      +first : T.State = T.State{w, p, ph, T.Snoc{l, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}
      +e1 : {place.tail(N.grab.check(shift(a, first)), seat, slot) == place.tail(shift(a, N.grab.check(first)), seat, slot) : T.State} = Equal.cong(T.State, T.State, x => place.tail(x, seat, slot), N.grab.check(shift(a, first)), shift(a, N.grab.check(first)), check.frame(a, first))
      Equal.trans(T.State, place.tail(N.grab.check(shift(a, first)), seat, slot), place.tail(shift(a, N.grab.check(first)), seat, slot), shift(a, place.tail(N.grab.check(first), seat, slot)), e1, place_tail.frame(a, N.grab.check(first), seat, slot))
    case False{}:
      put.frame(a, T.State{w, p, ph, l, g}, seat, slot)

def place.frame(+a: T.Log, +t: T.State, +seat: D.Seat, +slot: D.Slot) -> {N.grab.place(shift(a, t), seat, slot) == shift(a, N.grab.place(t, seat, slot)) : T.State}:
  match t:
    case T.State{+w, +p, +ph, +l, +g}:
      place_last.frame(a, w, p, ph, l, g, seat, slot, I.placing.last(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, seat))

# The loop after a grab move, from any state.
def after.frame(+fuel: Nat, ih: FrameHyp(fuel), +a: T.Log, +t: T.State, +seat: D.Seat) -> {N.grab.loop(fuel, shift(a, t), N.grab.continue(T.state.records(shift(a, t)), seat)) == shift(a, N.grab.loop(fuel, t, N.grab.continue(T.state.records(t), seat))) : T.State}:
  match t:
    case T.State{+w, +p, +ph, +l, +g}:
      ih(a, w, p, ph, l, g, N.grab.continue(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, seat))

def take.frame(+fuel: Nat, ih: FrameHyp(fuel), +a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +seat: D.Seat, pool: List<&2, D.Item>) -> {N.grab.loop(fuel, N.grab.pool(T.State{w, p, ph, log.join(a, l), g}, seat, pool), N.grab.next(T.state.records(N.grab.pool(T.State{w, p, ph, log.join(a, l), g}, seat, pool)), pool, seat)) == shift(a, N.grab.loop(fuel, N.grab.pool(T.State{w, p, ph, l, g}, seat, pool), N.grab.next(T.state.records(N.grab.pool(T.State{w, p, ph, l, g}, seat, pool)), pool, seat))) : T.State}:
  match pool:
    case Nil{}:
      ih(a, w, p, ph, T.Snoc{l, D.Told{seat, D.EmptyBriefcase{}}}, g, N.grab.continue(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, seat))
    case +item <> Nil{}:
      +given : S.Grabs = I.grabs.give(g, seat, item)
      ih(a, w, p, ph, T.Snoc{l, D.Shown{D.Granted{seat, item}}}, given, N.grab.continue(S.State{w, p, S.Blocked{None{}}, Nil{}, given}, seat))
    case first <> second <> rest:
      ih(a, w, p, T.NeedItem{seat, first, second, rest}, l, g, N.Drawing{})

def loop.frame.step(+fuel: Nat, ih: FrameHyp(fuel), +a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, next: N.Distribution) -> {N.grab.loop(1n+fuel, T.State{w, p, ph, log.join(a, l), g}, next) == shift(a, N.grab.loop(1n+fuel, T.State{w, p, ph, l, g}, next)) : T.State}:
  match next:
    case N.Drawing{}:
      {==}
    case N.Loading{}:
      dframe.of(t => N.load.begin(t), x => M.load.begin(x), a, w, p, ph, l, g, S.Blocked{None{}}, load_begin.c(a, w, p, ph, l, g, S.Blocked{None{}}))
    case N.NoTaker{}:
      {==}
    case N.Taking{+seat}:
      +opened : S.Grabs = I.grabs.stop_intake(g, seat)
      take.frame(fuel, ih, a, w, p, ph, l, opened, seat, I.pool(S.State{w, p, S.Blocked{None{}}, Nil{}, opened}, seat))
    case N.Placing{+seat, +slot}:
      +e1 : {N.grab.loop(fuel, N.grab.place(shift(a, T.State{w, p, ph, l, g}), seat, slot), N.grab.continue(T.state.records(N.grab.place(shift(a, T.State{w, p, ph, l, g}), seat, slot)), seat)) == N.grab.loop(fuel, shift(a, N.grab.place(T.State{w, p, ph, l, g}, seat, slot)), N.grab.continue(T.state.records(shift(a, N.grab.place(T.State{w, p, ph, l, g}, seat, slot))), seat)) : T.State} = Equal.cong(T.State, T.State, x => N.grab.loop(fuel, x, N.grab.continue(T.state.records(x), seat)), N.grab.place(shift(a, T.State{w, p, ph, l, g}), seat, slot), shift(a, N.grab.place(T.State{w, p, ph, l, g}, seat, slot)), place.frame(a, T.State{w, p, ph, l, g}, seat, slot))
      Equal.trans(T.State, N.grab.loop(fuel, N.grab.place(shift(a, T.State{w, p, ph, l, g}), seat, slot), N.grab.continue(T.state.records(N.grab.place(shift(a, T.State{w, p, ph, l, g}), seat, slot)), seat)), N.grab.loop(fuel, shift(a, N.grab.place(T.State{w, p, ph, l, g}, seat, slot)), N.grab.continue(T.state.records(shift(a, N.grab.place(T.State{w, p, ph, l, g}, seat, slot))), seat)), shift(a, N.grab.loop(fuel, N.grab.place(T.State{w, p, ph, l, g}, seat, slot), N.grab.continue(T.state.records(N.grab.place(T.State{w, p, ph, l, g}, seat, slot)), seat))), e1, after.frame(fuel, ih, a, N.grab.place(T.State{w, p, ph, l, g}, seat, slot), seat))

def loop.frame.zero(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, next: N.Distribution) -> {N.grab.loop(0n, T.State{w, p, ph, log.join(a, l), g}, next) == shift(a, N.grab.loop(0n, T.State{w, p, ph, l, g}, next)) : T.State}:
  match next:
    case N.Drawing{}:
      {==}
    case N.Loading{}:
      dframe.of(t => N.load.begin(t), x => M.load.begin(x), a, w, p, ph, l, g, S.Blocked{None{}}, load_begin.c(a, w, p, ph, l, g, S.Blocked{None{}}))
    case N.NoTaker{}:
      {==}
    case N.Taking{seat}:
      {==}
    case N.Placing{seat, slot}:
      {==}

def loop.frame(fuel: Nat) -> FrameHyp(fuel):
  match fuel:
    case 0n:
      +a => +w => +p => +ph => +l => +g => +next => loop.frame.zero(a, w, p, ph, l, g, next)
    case 1n+(+rest):
      +a => +w => +p => +ph => +l => +g => +next => loop.frame.step(rest, loop.frame(rest), a, w, p, ph, l, g, next)

def begin_go.indep(seats: List<&2, D.Seat>, +w: S.World, +p: S.Players, +g: S.Grabs, +q1: S.Phase, +n1: List<&2, D.Note>, +q2: S.Phase, +n2: List<&2, D.Note>, +nr: Bool) -> {I.begin.go(seats, S.State{w, p, q1, n1, g}, nr) == I.begin.go(seats, S.State{w, p, q2, n2, g}, nr) : List<&2, D.Seat>}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> rest:
      Equal.cong(List<&2, D.Seat>, List<&2, D.Seat>, xs => I.keep(D.Seat, Bool.and(I.begin.can(nr, I.seat.health(p, seat), I.seat.slots(p, seat)), I.has_items(I.pool(S.State{w, p, q1, n1, g}, seat))), seat, xs), I.begin.go(rest, S.State{w, p, q1, n1, g}, nr), I.begin.go(rest, S.State{w, p, q2, n2, g}, nr), begin_go.indep(rest, w, p, g, q1, n1, q2, n2, nr))

def begin_seats.indep(amount: Nat, +w: S.World, +p: S.Players, +g: S.Grabs, +q1: S.Phase, +n1: List<&2, D.Note>, +q2: S.Phase, +n2: List<&2, D.Note>, +nr: Bool) -> {I.begin.seats(S.State{w, p, q1, n1, g}, nr, amount) == I.begin.seats(S.State{w, p, q2, n2, g}, nr, amount) : List<&2, D.Seat>}:
  match amount:
    case 0n:
      {==}
    case 1n+k:
      begin_go.indep(D.table.seats(S.world.table(w)), w, p, g, q1, n1, q2, n2, nr)

def distribute_begin.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, seats: List<&2, D.Seat>) -> Corr(t => N.distribute.begin(t, seats), x => M.distribute.begin(x, seats), a, w, p, ph, l, g, q):
  match seats:
    case Nil{}:
      dcorr.corr(t => N.load.begin(t), x => M.load.begin(x), a, w, p, ph, l, g, q, load_begin.c(a, w, p, ph, l, g, q))
    case +seat <> +rest:
      +opened : S.Grabs = S.grabs.set_distributing(I.grabs.open_all(seat <> rest, g), True{})
      +began : T.Log = T.Snoc{l, D.Shown{D.GrabbingBegan{seat <> rest}}}
      (loop.frame(N.grab.fuel(S.world.table(w)))(a, w, p, ph, began, opened, N.grab.continue(S.State{w, p, S.Blocked{None{}}, Nil{}, opened}, S.world.first_turn(w))), Inr{(T.State{w, p, ph, began, opened}, ({==}, ({==}, dist.set(I.grabs.open_all(seat <> rest, g), True{}))))})

def round_reset.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase) -> Corr(t => N.round.reset(t), x => M.round.reset(x), a, w, p, ph, l, g, q):
  +players : S.Players = S.players.reset(p, S.world.round_health(w))
  +world : S.World = S.world.set_direction(S.world.set_checking_first_death(w, True{}), D.Clockwise{})
  +began : T.Log = T.Snoc{l, D.Shown{D.RoundBegan{S.world.round_index(world), S.world.round_health(world), S.world.first_turn(world)}}}
  +seats : List<&2, D.Seat> = I.begin.seats(S.State{world, players, S.Blocked{None{}}, Nil{}, g}, True{}, S.world.item_amount(world))
  %begin_seats.indep(S.world.item_amount(world), world, players, g, S.Blocked{None{}}, Nil{}, q, T.log.list(began), True{}) : Corr(t => N.distribute.begin(t, seats), x => M.distribute.begin(x, _), a, world, players, ph, began, g, q)
  distribute_begin.c(a, world, players, ph, began, g, q, seats)

def amount_chosen.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +value: Nat) -> Corr(t => N.amount.chosen(t, value), x => M.amount.chosen(x, value), a, w, p, ph, l, g, q):
  round_reset.c(a, S.world.set_item_amount(w, value), p, ph, l, g, q)

def amount_rule.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, rule: D.AmountRule) -> Corr(t => N.amount.rule(t, rule), x => M.amount.rule(x, rule), a, w, p, ph, l, g, q):
  match rule:
    case D.RandomAmount{}:
      ({==}, Inl{({==}, {==})})
    case D.FixedAmount{+amount}:
      amount_chosen.c(a, w, p, ph, l, g, q, amount)

def amount_begin.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase) -> Corr(t => N.amount.begin(t), x => M.amount.begin(x), a, w, p, ph, l, g, q):
  amount_rule.c(a, w, p, ph, l, g, q, G.load.amount(G.world.load_rule(w)))

def health_chosen.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +value: Nat) -> Corr(t => N.health.chosen(t, value), x => M.health.chosen(x, value), a, w, p, ph, l, g, q):
  amount_begin.c(a, S.world.set_round_health(w, value), p, ph, l, g, q)

def health_rule.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, rule: D.HealthRule) -> Corr(t => N.health.rule(t, rule), x => M.health.rule(x, rule), a, w, p, ph, l, g, q):
  match rule:
    case D.RandomHealth{}:
      ({==}, Inl{({==}, {==})})
    case D.FixedHealth{+health}:
      health_chosen.c(a, w, p, ph, l, g, q, D.pos.nat(health))

def health_begin.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase) -> Corr(t => N.health.begin(t), x => M.health.begin(x), a, w, p, ph, l, g, q):
  health_rule.c(a, w, p, ph, l, g, q, G.round.health(G.world.rules(w)))

def first_chosen.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat) -> Corr(t => N.first.chosen(t, seat), x => M.first.chosen(x, seat), a, w, p, ph, l, g, q):
  +world : S.World = S.world.set_first_turn(S.world.set_before_round(S.world.set_round_index(w, G.round.next(S.world.before_round(w), S.world.round_index(w))), False{}), seat)
  health_begin.c(a, S.world.set_first_sequence(world, True{}), p, ph, l, g, q)

def first_override.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, died: Maybe<&2, D.Seat>) -> Corr(t => N.first.override(t, died), x => M.first.override(x, died), a, w, p, ph, l, g, q):
  match died:
    case None{}:
      ({==}, Inl{({==}, {==})})
    case Some{+seat}:
      first_chosen.c(a, w, p, ph, l, g, q, seat)

def first_begin.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase) -> Corr(t => N.first.begin(t), x => M.first.begin(x), a, w, p, ph, l, g, q):
  first_override.c(a, w, p, ph, l, g, q, S.world.first_death(w))

def win_final.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, final: Bool) -> Corr(t => N.win.final(t, final), x => M.win.final(x, final), a, w, p, ph, l, g, q):
  match final:
    case True{}:
      ({==}, Inl{({==}, {==})})
    case False{}:
      first_begin.c(a, w, p, ph, l, g, q)

def win.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat) -> Corr(t => N.win(t, seat), x => M.win(x, seat), a, w, p, ph, l, g, q):
  +prize : U32 = D.prize(S.world.round_index(w))
  +players : S.Players = S.players.set_cash(p, seat, U32.add(G.value.or(U32, D.ring.get(U32, S.players.cash(p), seat), 0), prize))
  win_final.c(a, w, players, ph, T.Snoc{l, D.Shown{D.RoundWon{seat, prize}}}, g, q, Nat.is_eq(1n+S.world.round_index(w), D.plan.length(S.world.plan(w))))

def reload_begin.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase) -> Corr(t => N.reload.begin(t), x => M.reload.begin(x), a, w, p, ph, l, g, q):
  +seats : List<&2, D.Seat> = I.begin.seats(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, False{}, S.world.item_amount(w))
  %begin_seats.indep(S.world.item_amount(w), w, p, g, S.Blocked{None{}}, Nil{}, q, T.log.list(l), False{}) : Corr(t => N.distribute.begin(t, seats), x => M.distribute.begin(x, _), a, w, p, ph, l, g, q)
  distribute_begin.c(a, w, p, ph, l, g, q, seats)

def turn_continue.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +recipient: D.Seat, gun: List<&2, D.Shell>) -> Corr(t => N.turn.continue(t, recipient, gun), x => M.turn.continue(x, recipient, gun), a, w, p, ph, l, g, q):
  match gun:
    case Nil{}:
      reload_begin.c(a, S.world.set_first_turn(w, recipient), p, ph, l, g, q)
    case shell <> rest:
      dcorr.corr(t => N.grant(t, recipient), x => M.grant(x, recipient), a, S.world.set_first_turn(w, recipient), p, ph, l, g, q, grant.c(a, S.world.set_first_turn(w, recipient), p, ph, l, g, q, recipient))

def turn_winner.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +shooter: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>) -> Corr(t => N.turn.winner(t, shooter, passing, winner), x => M.turn.winner(x, shooter, passing, winner), a, w, p, ph, l, g, q):
  match passing winner:
    case _ Some{+seat}:
      win.c(a, w, p, ph, l, g, q, seat)
    case False{} None{}:
      turn_continue.c(a, w, p, ph, l, g, q, shooter, S.world.gun(w))
    case True{} None{}:
      turn_continue.c(a, w, p, ph, l, g, q, G.next_turn(S.players.health(p), S.world.direction(w), shooter), S.world.gun(w))

def turn_amount.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +shooter: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>, rule: D.AmountRule) -> Corr(t => N.turn.amount(t, shooter, passing, winner, rule), x => M.turn.amount(x, shooter, passing, winner, rule), a, w, p, ph, l, g, q):
  match rule:
    case D.RandomAmount{}:
      turn_winner.c(a, w, p, ph, l, g, q, shooter, passing, winner)
    case D.FixedAmount{amount}:
      turn_winner.c(a, S.world.set_item_amount(w, amount), p, ph, l, g, q, shooter, passing, winner)

def turn_live.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +shooter: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>, +rule: D.AmountRule, live: Bool) -> Corr(t => N.turn.live(t, shooter, passing, winner, rule, live), x => M.turn.live(x, shooter, passing, winner, rule, live), a, w, p, ph, l, g, q):
  match live:
    case True{}:
      ({==}, Inl{({==}, {==})})
    case False{}:
      turn_amount.c(a, w, p, ph, l, g, q, shooter, passing, winner, rule)

def reload_wanted.indep(+w: S.World, +p: S.Players, +g: S.Grabs, +q1: S.Phase, +n1: List<&2, D.Note>, +q2: S.Phase, +n2: List<&2, D.Note>, +winner: Maybe<&2, D.Seat>) -> {I.reload.wanted(S.State{w, p, q1, n1, g}, winner) == I.reload.wanted(S.State{w, p, q2, n2, g}, winner) : Bool}:
  Equal.cong(List<&2, D.Seat>, Bool, xs => Bool.and(I.gun.empty(S.world.gun(w)), Bool.and(I.winnerless(winner), I.has_seats(xs))), I.begin.seats(S.State{w, p, q1, n1, g}, False{}, 1n), I.begin.seats(S.State{w, p, q2, n2, g}, False{}, 1n), begin_seats.indep(1n, w, p, g, q1, n1, q2, n2, False{}))

def turn_packet.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +shooter: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>) -> Corr(t => N.turn.packet(t, shooter, passing, winner), x => M.turn.packet(x, shooter, passing, winner), a, w, p, ph, l, g, q):
  +rule : D.AmountRule = G.load.amount(G.world.load_rule(w))
  +wanted : Bool = I.reload.wanted(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, winner)
  %reload_wanted.indep(w, p, g, S.Blocked{None{}}, Nil{}, q, T.log.list(l), winner) : Corr(t => N.turn.live(t, shooter, passing, winner, rule, I.amount.live(rule, S.grabs.distributing(g), wanted)), x => M.turn.live(x, shooter, passing, winner, rule, I.amount.live(rule, S.grabs.distributing(g), _)), a, w, p, ph, l, g, q)
  turn_live.c(a, w, p, ph, l, g, q, shooter, passing, winner, rule, I.amount.live(rule, S.grabs.distributing(g), wanted))

def turn_end.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +shooter: D.Seat, +passing: Bool) -> Corr(t => N.turn.end(t, shooter, passing), x => M.turn.end(x, shooter, passing), a, w, p, ph, l, g, q):
  turn_packet.c(a, w, p, ph, l, g, q, shooter, passing, G.winner(S.players.health(p)))

def death_died.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +target: D.Seat, +shooter: D.Seat, +passing: Bool, checking: Bool) -> Corr(t => N.turn.end(T.state.emit(N.death.remember(t, target, checking), D.Died{target}), shooter, passing), x => M.turn.end(S.state.emit(M.death.remember(x, target, checking), D.Died{target}), shooter, passing), a, w, p, ph, l, g, q):
  match checking:
    case False{}:
      turn_end.c(a, w, p, ph, T.Snoc{l, D.Shown{D.Died{target}}}, g, q, shooter, passing)
    case True{}:
      turn_end.c(a, S.world.set_checking_first_death(S.world.set_first_death(w, Some{target}), False{}), p, ph, T.Snoc{l, D.Shown{D.Died{target}}}, g, q, shooter, passing)

def shot_end.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +target: D.Seat, +shooter: D.Seat, +passing: Bool, shell: D.Shell, health: Nat) -> Corr(t => N.turn.end(N.death(t, target, shell, health), shooter, passing), x => M.turn.end(M.death(x, target, shell, health), shooter, passing), a, w, p, ph, l, g, q):
  match shell health:
    case D.Live{} 0n:
      death_died.c(a, w, p, ph, l, g, q, target, shooter, passing, S.world.checking_first_death(w))
    case D.Live{} 1n+left:
      turn_end.c(a, w, p, ph, l, g, q, shooter, passing)
    case D.Blank{} health:
      turn_end.c(a, w, p, ph, l, g, q, shooter, passing)

def shoot_loaded.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +shooter: D.Seat, +target: D.Seat, +shell: D.Shell, +rest: List<&2, D.Shell>) -> Corr(t => N.shoot.loaded(t, shooter, target, shell, rest), x => M.shoot.loaded(x, shooter, target, shell, rest), a, w, p, ph, l, g, q):
  +damage : D.Damage = G.captured(S.world.sawed(w))
  +before : Nat = G.value.or(Nat, D.ring.get(Nat, S.players.health(p), target), 100n)
  +health : Nat = G.shot.health(shell, before, damage)
  +players : S.Players = S.players.set_health(p, target, health)
  +world : S.World = S.world.set_sawed(S.world.set_gun(w, rest), False{})
  shot_end.c(a, world, players, ph, T.Snoc{l, D.Shown{D.Fired{shooter, target, shell, damage, G.subtract(before, health), health}}}, g, q, target, shooter, G.shot.passes(shell, D.seat.eq(shooter, target)), shell, health)

def shoot_gun.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +shooter: D.Seat, +target: D.Seat, gun: List<&2, D.Shell>) -> Corr(t => N.shoot.gun(t, shooter, target, gun), x => M.shoot.gun(x, shooter, target, gun), a, w, p, ph, l, g, q):
  match gun:
    case Nil{}:
      ({==}, Inl{({==}, {==})})
    case +shell <> +rest:
      shoot_loaded.c(a, w, p, ph, l, g, q, shooter, target, shell, rest)

def shoot.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +shooter: D.Seat, +target: D.Seat) -> Corr(t => N.shoot(t, shooter, target), x => M.shoot(x, shooter, target), a, w, p, ph, l, g, q):
  shoot_gun.c(a, w, p, ph, l, g, q, shooter, target, S.world.gun(w))

# An item whose use is a whole sm move: neither jammer nor adrenaline, whose
# sm use opens a pick.
def Plain(item: D.Item) -> Data:
  match item:
    case D.Jammer{}:
      Empty
    case D.Adrenaline{}:
      Empty
    case _:
      Unit

def item_end.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, ending: Bool) -> Corr(t => N.item.end(t, seat, ending), x => M.item.end(x, seat, ending), a, w, p, ph, l, g, q):
  match ending:
    case True{}:
      turn_packet.c(a, w, p, ph, l, g, q, seat, True{}, None{})
    case False{}:
      ({==}, Inl{({==}, {==})})

def item_chamber.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, item: D.Item, +ending: Bool, +shell: D.Shell, +rest: List<&2, D.Shell>) -> Corr(t => N.item.chamber(t, seat, item, ending, shell, rest), x => M.item.chamber(x, seat, item, ending, shell, rest), a, w, p, ph, l, g, q):
  match item:
    case D.Glass{}:
      item_end.c(a, w, p, ph, T.Snoc{l, D.Told{seat, D.Glimpse{shell}}}, g, q, seat, ending)
    case D.Beer{}:
      item_end.c(a, S.world.set_gun(w, rest), p, ph, T.Snoc{l, D.Shown{D.Ejected{seat, shell}}}, g, q, seat, ending)
    case D.Inverter{}:
      item_end.c(a, S.world.set_gun(w, I.invert(shell) <> rest), p, ph, T.Snoc{l, D.Shown{D.Inverted{seat}}}, g, q, seat, ending)
    case D.Saw{}:
      ({==}, Inl{({==}, {==})})
    case D.Jammer{}:
      ({==}, Inl{({==}, {==})})
    case D.Cigarettes{}:
      ({==}, Inl{({==}, {==})})
    case D.Phone{}:
      ({==}, Inl{({==}, {==})})
    case D.Adrenaline{}:
      ({==}, Inl{({==}, {==})})
    case D.Remote{}:
      ({==}, Inl{({==}, {==})})

def item_shell.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, +item: D.Item, +ending: Bool, gun: List<&2, D.Shell>) -> Corr(t => N.item.shell(t, seat, item, ending, gun), x => M.item.shell(x, seat, item, ending, gun), a, w, p, ph, l, g, q):
  match gun:
    case Nil{}:
      ({==}, Inl{({==}, {==})})
    case +shell <> +rest:
      item_chamber.c(a, w, p, ph, l, g, q, seat, item, ending, shell, rest)

def item_heal.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, heal: Bool) -> Corr(t => N.item.heal(t, seat, heal), x => M.item.heal(x, seat, heal), a, w, p, ph, l, g, q):
  match heal:
    case True{}:
      ({==}, Inl{({==}, {==})})
    case False{}:
      ({==}, Inl{({==}, {==})})

def item_tell.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, phone: Maybe<&2, D.Secret>) -> Corr(t => N.item.tell(t, seat, phone), x => M.item.tell(x, seat, phone), a, w, p, ph, l, g, q):
  match phone:
    case None{}:
      ({==}, Inl{({==}, {==})})
    case Some{secret}:
      ({==}, Inl{({==}, {==})})

def item_effect.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, item: D.Item, +ending: Bool, +phone: Maybe<&2, D.Secret>, plain: Plain(item)) -> Corr(t => N.item.effect(t, seat, item, ending, phone), x => M.item.effect(x, seat, item, ending, phone), a, w, p, ph, l, g, q):
  match item:
    case D.Saw{}:
      ({==}, Inl{({==}, {==})})
    case D.Jammer{}:
      match plain:
    case D.Cigarettes{}:
      item_heal.c(a, w, p, ph, l, g, q, seat, Nat.is_lt(I.seat.health(p, seat), S.world.round_health(w)))
    case D.Phone{}:
      item_tell.c(a, w, p, ph, l, g, q, seat, phone)
    case D.Adrenaline{}:
      match plain:
    case D.Remote{}:
      ({==}, Inl{({==}, {==})})
    case D.Glass{}:
      item_shell.c(a, w, p, ph, l, g, q, seat, D.Glass{}, ending, S.world.gun(w))
    case D.Beer{}:
      item_shell.c(a, w, p, ph, l, g, q, seat, D.Beer{}, ending, S.world.gun(w))
    case D.Inverter{}:
      item_shell.c(a, w, p, ph, l, g, q, seat, D.Inverter{}, ending, S.world.gun(w))

def item_consume.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +ending: Bool, +phone: Maybe<&2, D.Secret>, plain: Plain(item)) -> Corr(t => N.item.consume(t, seat, owner, slot, item, ending, phone), x => M.item.consume(x, seat, owner, slot, item, ending, phone), a, w, p, ph, l, g, q):
  +players : S.Players = S.players.set_slots(p, owner, I.slots.put(I.seat.slots(p, owner), slot, None{}))
  item_effect.c(a, w, players, ph, T.Snoc{l, D.Shown{D.Used{seat, owner, slot, item}}}, g, q, seat, item, ending, phone, plain)

def item_clue_found.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +position: Nat, found: Maybe<&2, D.Shell>) -> Corr(t => N.item.clue.found(t, seat, owner, slot, position, found), x => M.item.clue.found(x, seat, owner, slot, position, found), a, w, p, ph, l, g, q):
  match found:
    case None{}:
      ({==}, Inl{({==}, {==})})
    case Some{+shell}:
      item_consume.c(a, w, p, ph, l, g, q, seat, owner, slot, D.Phone{}, False{}, Some{D.Clue{position, shell}}, Unit{})

def item_clue.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +index: Nat) -> Corr(t => N.item.clue(t, seat, owner, slot, index), x => M.item.clue(x, seat, owner, slot, index), a, w, p, ph, l, g, q):
  +position : Nat = D.clamp(1n+index, D.phone.cap())
  item_clue_found.c(a, w, p, ph, l, g, q, seat, owner, slot, position, G.nth(D.Shell, S.world.gun(w), G.predecessor(position)))

def item_phone.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, length: Nat) -> Corr(t => N.item.phone(t, seat, owner, slot, length), x => M.item.phone(x, seat, owner, slot, length), a, w, p, ph, l, g, q):
  match length:
    case 0n:
      item_consume.c(a, w, p, ph, l, g, q, seat, owner, slot, D.Phone{}, False{}, Some{D.NoClue{}}, Unit{})
    case 1n:
      item_consume.c(a, w, p, ph, l, g, q, seat, owner, slot, D.Phone{}, False{}, Some{D.NoClue{}}, Unit{})
    case 2n:
      item_consume.c(a, w, p, ph, l, g, q, seat, owner, slot, D.Phone{}, False{}, Some{D.NoClue{}}, Unit{})
    case 3n:
      item_clue.c(a, w, p, ph, l, g, q, seat, owner, slot, 2n)
    case 1n+1n+1n+1n+more:
      ({==}, Inl{({==}, {==})})

def item_route.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, item: D.Item, +ending: Bool, +length: Nat, plain: Plain(item)) -> Corr(t => N.item.route(t, seat, owner, slot, item, ending, length), x => M.item.route(x, seat, owner, slot, item, ending, length), a, w, p, ph, l, g, q):
  match item:
    case D.Phone{}:
      item_phone.c(a, w, p, ph, l, g, q, seat, owner, slot, length)
    case D.Saw{}:
      item_consume.c(a, w, p, ph, l, g, q, seat, owner, slot, D.Saw{}, ending, None{}, plain)
    case D.Jammer{}:
      match plain:
    case D.Cigarettes{}:
      item_consume.c(a, w, p, ph, l, g, q, seat, owner, slot, D.Cigarettes{}, ending, None{}, plain)
    case D.Adrenaline{}:
      match plain:
    case D.Remote{}:
      item_consume.c(a, w, p, ph, l, g, q, seat, owner, slot, D.Remote{}, ending, None{}, plain)
    case D.Glass{}:
      item_consume.c(a, w, p, ph, l, g, q, seat, owner, slot, D.Glass{}, ending, None{}, plain)
    case D.Beer{}:
      item_consume.c(a, w, p, ph, l, g, q, seat, owner, slot, D.Beer{}, ending, None{}, plain)
    case D.Inverter{}:
      item_consume.c(a, w, p, ph, l, g, q, seat, owner, slot, D.Inverter{}, ending, None{}, plain)

def item_use.c(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item, plain: Plain(item)) -> Corr(t => N.item.use(t, seat, owner, slot, item), x => M.item.use(x, seat, owner, slot, item), a, w, p, ph, l, g, q):
  +length : Nat = List.length(&2, D.Shell, S.world.gun(w))
  item_route.c(a, w, p, ph, l, g, q, seat, owner, slot, item, I.ends_turn(item, length), length, plain)
