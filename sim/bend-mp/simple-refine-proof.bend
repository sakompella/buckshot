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

# One simple answer against sm walking its chain: the rest of a chain after
# its first steps, then the chain's first steps.

def budget.eq(table: D.Table) -> {SA.budget(table) == N.grab.fuel(table) : Nat}:
  match table:
    case D.TwoSeats{}:
      {==}
    case D.ThreeSeats{}:
      {==}
    case D.FourSeats{}:
      {==}

def start.some(step: Maybe<&2, SA.Step>, +y: S.State, +f: Nat) -> {SA.sched.start(step, y, f) == SA.sched.go(f, step, y) : List<&2, SA.Step>}:
  match step:
    case None{}:
      Equal.sym(List<&2, SA.Step>, SA.sched.go(f, None{}, y), Nil{}, L.sched.none(f, y))
    case Some{s}:
      {==}

def direct.sched(+u: T.State, +y: S.State, +after: D.Seat, +f1: Nat, +f2: Nat, direct: C.Direct(u, y)) -> {SA.sched.start(SA.sched.decide(y, after), y, f1) == SA.sched.go(f2, SA.sched.decide(y, after), y) : List<&2, SA.Step>}:
  match direct:
    case Tuple{+eq, +calm}:
      %Equal.sym(S.State, y, SA.embed(u), eq) : {SA.sched.start(SA.sched.decide(_, after), _, f1) == SA.sched.go(f2, SA.sched.decide(_, after), _) : List<&2, SA.Step>}
      %Equal.sym(Maybe<&2, SA.Step>, SA.sched.decide(SA.embed(u), after), None{}, L.calm.none(u, after, calm)) : {SA.sched.start(_, SA.embed(u), f1) == SA.sched.go(f2, _, SA.embed(u)) : List<&2, SA.Step>}
      Equal.sym(List<&2, SA.Step>, SA.sched.go(f2, None{}, SA.embed(u)), Nil{}, L.sched.none(f2, SA.embed(u)))

def sched.cont(+w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +after: D.Seat, dist: Bool, hold: Bool) -> {SA.sched(M.grab.continue.ready(S.State{w, p, q, T.log.list(l), g}, dist, hold), after) == SA.sched.go(N.grab.fuel(S.world.table(w)), SA.sched.decide(M.grab.continue.ready(S.State{w, p, q, T.log.list(l), g}, dist, hold), after), M.grab.continue.ready(S.State{w, p, q, T.log.list(l), g}, dist, hold)) : List<&2, SA.Step>}:
  match dist hold:
    case False{} False{}:
      direct.sched(N.load.begin(T.State{w, p, ph, l, g}), M.load.begin(S.State{w, p, q, T.log.list(l), g}), after, SA.budget(S.world.table(S.state.world(M.load.begin(S.State{w, p, q, T.log.list(l), g})))), N.grab.fuel(S.world.table(w)), C.direct.of(t => N.load.begin(t), x => M.load.begin(x), T.Empty{}, w, p, ph, l, g, q, C.load_begin.c(T.Empty{}, w, p, ph, l, g, q)))
    case False{} True{}:
      %Equal.sym(Nat, SA.budget(S.world.table(w)), N.grab.fuel(S.world.table(w)), budget.eq(S.world.table(w))) : {SA.sched.start(SA.sched.decide(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, after), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, _) == SA.sched.go(N.grab.fuel(S.world.table(w)), SA.sched.decide(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, after), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}) : List<&2, SA.Step>}
      start.some(SA.sched.decide(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, after), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, N.grab.fuel(S.world.table(w)))
    case True{} hold:
      %Equal.sym(Nat, SA.budget(S.world.table(w)), N.grab.fuel(S.world.table(w)), budget.eq(S.world.table(w))) : {SA.sched.start(SA.sched.decide(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, after), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, _) == SA.sched.go(N.grab.fuel(S.world.table(w)), SA.sched.decide(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, after), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}) : List<&2, SA.Step>}
      start.some(SA.sched.decide(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, after), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, N.grab.fuel(S.world.table(w)))

def cont.claim(+w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +after: D.Seat) -> L.Fin.of(N.grab.loop(N.grab.fuel(S.world.table(w)), T.State{w, p, ph, l, g}, N.grab.continue(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, after)), M.grab.continue(S.State{w, p, q, T.log.list(l), g}), SA.walk.go(SA.sched(M.grab.continue(S.State{w, p, q, T.log.list(l), g}), after), M.grab.continue(S.State{w, p, q, T.log.list(l), g}))):
  %Equal.sym(List<&2, SA.Step>, SA.sched(M.grab.continue(S.State{w, p, q, T.log.list(l), g}), after), SA.sched.go(N.grab.fuel(S.world.table(w)), SA.sched.decide(M.grab.continue(S.State{w, p, q, T.log.list(l), g}), after), M.grab.continue(S.State{w, p, q, T.log.list(l), g})), sched.cont(w, p, ph, l, g, q, after, S.grabs.distributing(g), I.holders(D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(g))))) : L.Fin.of(N.grab.loop(N.grab.fuel(S.world.table(w)), T.State{w, p, ph, l, g}, N.grab.continue(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, after)), M.grab.continue(S.State{w, p, q, T.log.list(l), g}), SA.walk.go(_, M.grab.continue(S.State{w, p, q, T.log.list(l), g})))
  L.loop.lemma(N.grab.fuel(S.world.table(w)))(w, p, ph, l, g, q, after)

def cont.grab(+w: S.World, +p: S.Players, +q: S.Phase, +n: List<&2, D.Note>, +g: S.Grabs, ed: {S.grabs.distributing(g) == True{} : Bool}) -> {M.grab.continue(S.State{w, p, q, n, g}) == S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, q, n, g})}, n, g} : S.State}:
  %Equal.sym(Bool, S.grabs.distributing(g), True{}, ed) : {M.grab.continue.ready(S.State{w, p, q, n, g}, _, I.holders(D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(g)))) == S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, q, n, g})}, n, g} : S.State}
  {==}

def RestOf(+u: T.State, +y: S.State) -> Data:
  L.Fin.of(u, y, SA.walk.go(SA.sched(y, S.world.first_turn(S.state.world(y))), y))

def rest.inr(+u: T.State, +y: S.State, +m: T.State, ey: {y == SA.embed(T.state.set_phase(m, T.Stalled{})) : S.State}, eu: {u == N.grab.distribute(m, S.world.first_turn(T.state.world(m))) : T.State}, ed: {S.grabs.distributing(T.state.grabs(m)) == True{} : Bool}) -> RestOf(u, y):
  match m:
    case T.State{+w, +p, +ph, +l, +g}:
      %Equal.sym(S.State, y, SA.embed(T.State{w, p, T.Stalled{}, l, g}), ey) : RestOf(u, _)
      %Equal.sym(T.State, u, N.grab.distribute(T.State{w, p, ph, l, g}, S.world.first_turn(w)), eu) : RestOf(_, SA.embed(T.State{w, p, T.Stalled{}, l, g}))
      %cont.grab(w, p, S.Blocked{None{}}, T.log.list(l), g, ed) : L.Fin.of(N.grab.distribute(T.State{w, p, ph, l, g}, S.world.first_turn(w)), _, SA.walk.go(SA.sched(_, S.world.first_turn(w)), _))
      cont.claim(w, p, ph, l, g, S.Blocked{None{}}, S.world.first_turn(w))

def rest.claim(+u: T.State, +y: S.State, rel: C.Rel(u, y)) -> RestOf(u, y):
  match rel:
    case Inl{+direct}:
      +after : D.Seat = S.world.first_turn(S.state.world(y))
      %Equal.sym(List<&2, SA.Step>, SA.sched.start(SA.sched.decide(y, after), y, SA.budget(S.world.table(S.state.world(y)))), SA.sched.go(0n, SA.sched.decide(y, after), y), direct.sched(u, y, after, SA.budget(S.world.table(S.state.world(y))), 0n, direct)) : L.Fin.of(u, y, SA.walk.go(_, y))
      L.claim.direct(0n, u, y, after, direct)
    case Inr{Tuple{+m, Tuple{+ey, Tuple{+eu, +ed}}}}:
      rest.inr(u, y, m, ey, eu, ed)

def Top(+u: T.State, walked: Maybe<&2, D.Stepped<&2, S.State>>) -> Data:
  match walked:
    case None{}:
      Empty
    case Some{D.Stepped{z, d}}:
      Sigma<&2, &2, {L.NS(z) == L.NS(SA.embed(u)) : S.State}, _ => {T.state.notes(u) == d : List<&2, D.Note>}>

def top.merge(+u: T.State, +x1: S.State, walked: Maybe<&2, D.Stepped<&2, S.State>>, fin: L.Fin.of(u, x1, walked)) -> Top(u, SA.walk.merge(D.Stepped{x1, S.state.notes(x1)}, walked)):
  match walked:
    case None{}:
      match fin:
    case Some{D.Stepped{z, d}}:
      fin

def top.first(+x: S.State, +step: SA.Step, +rest: List<&2, SA.Step>, +k: Nat, +x1: S.State, +u: T.State, legal: {SA.walk.legal(M.request(x), step) == Some{k} : Maybe<&2, Nat>}, answered: {M.answer(x, k) == S.state.stepped(x1) : D.Stepped<&2, S.State>}, fin: L.Fin.of(u, x1, SA.walk.go(rest, x1))) -> Top(u, SA.walk.go(step <> rest, x)):
  %Equal.sym(Maybe<&2, Nat>, SA.walk.legal(M.request(x), step), Some{k}, legal) : Top(u, SA.walk.answer(_, x, next => SA.walk.go(rest, next)))
  %Equal.sym(D.Stepped<&2, S.State>, M.answer(x, k), S.state.stepped(x1), answered) : Top(u, SA.walk.merge(_, SA.walk.go(rest, M.stepped.state(_))))
  top.merge(u, x1, SA.walk.go(rest, x1), fin)

def mid.merge(+a: T.Log, +u: T.State, +x: S.State, +x1: S.State, walked: Maybe<&2, D.Stepped<&2, S.State>>, ea: {T.log.list(a) == S.state.notes(x) : List<&2, D.Note>}, fin: L.Fin.of(u, x1, walked)) -> L.Fin.of(C.shift(a, u), x, SA.walk.merge(D.Stepped{x1, S.state.notes(x1)}, walked)):
  match walked:
    case None{}:
      match fin:
    case Some{D.Stepped{+z, +d}}:
      match fin:
        case Tuple{+ns, +nt}:
          +e1 : {L.NS(z) == L.NS(SA.embed(C.shift(a, u))) : S.State} = Equal.trans(S.State, L.NS(z), L.NS(SA.embed(u)), L.NS(SA.embed(C.shift(a, u))), ns, Equal.sym(S.State, L.NS(SA.embed(C.shift(a, u))), L.NS(SA.embed(u)), L.ns.shift(a, u)))
          +e2 : {List.append(&2, D.Note, T.log.list(a), T.state.notes(u)) == List.append(&2, D.Note, S.state.notes(x), List.append(&2, D.Note, S.state.notes(x1), d)) : List<&2, D.Note>} = Equal.trans(List<&2, D.Note>, List.append(&2, D.Note, T.log.list(a), T.state.notes(u)), List.append(&2, D.Note, S.state.notes(x), T.state.notes(u)), List.append(&2, D.Note, S.state.notes(x), List.append(&2, D.Note, S.state.notes(x1), d)), Equal.cong(List<&2, D.Note>, List<&2, D.Note>, xs => List.append(&2, D.Note, xs, T.state.notes(u)), T.log.list(a), S.state.notes(x), ea), Equal.cong(List<&2, D.Note>, List<&2, D.Note>, xs => List.append(&2, D.Note, S.state.notes(x), xs), T.state.notes(u), List.append(&2, D.Note, S.state.notes(x1), d), nt))
          (e1, Equal.trans(List<&2, D.Note>, T.state.notes(C.shift(a, u)), List.append(&2, D.Note, T.log.list(a), T.state.notes(u)), List.append(&2, D.Note, S.state.notes(x), List.append(&2, D.Note, S.state.notes(x1), d)), L.notes.shift(a, u), e2))

def fin.mid(+x: S.State, +step: SA.Step, +rest: List<&2, SA.Step>, +k: Nat, +x1: S.State, +u: T.State, +a: T.Log, legal: {SA.walk.legal(M.request(x), step) == Some{k} : Maybe<&2, Nat>}, answered: {M.answer(x, k) == S.state.stepped(x1) : D.Stepped<&2, S.State>}, ea: {T.log.list(a) == S.state.notes(x) : List<&2, D.Note>}, fin: L.Fin.of(u, x1, SA.walk.go(rest, x1))) -> L.Fin.of(C.shift(a, u), x, SA.walk.go(step <> rest, x)):
  %Equal.sym(Maybe<&2, Nat>, SA.walk.legal(M.request(x), step), Some{k}, legal) : L.Fin.of(C.shift(a, u), x, SA.walk.answer(_, x, next => SA.walk.go(rest, next)))
  %Equal.sym(D.Stepped<&2, S.State>, M.answer(x, k), S.state.stepped(x1), answered) : L.Fin.of(C.shift(a, u), x, SA.walk.merge(_, SA.walk.go(rest, M.stepped.state(_))))
  mid.merge(a, u, x, x1, SA.walk.go(rest, x1), ea, fin)

def setn(+z: S.State, +d: List<&2, D.Note>) -> {S.state.set_notes(z, d) == S.state.set_notes(L.NS(z), d) : S.State}:
  match z:
    case S.State{w, p, ph, n, g}:
      {==}

def embed.notes(+u: T.State) -> {S.state.set_notes(L.NS(SA.embed(u)), T.state.notes(u)) == SA.embed(u) : S.State}:
  match u:
    case T.State{w, p, ph, l, g}:
      {==}

def top.notes(+u: T.State, walked: Maybe<&2, D.Stepped<&2, S.State>>, top: Top(u, walked)) -> {SA.walk.notes(walked) == Some{D.Stepped{SA.embed(u), T.state.notes(u)}} : Maybe<&2, D.Stepped<&2, S.State>>}:
  match walked:
    case None{}:
      match top:
    case Some{D.Stepped{+z, +d}}:
      match top:
        case Tuple{+ns, +nt}:
          %Equal.sym(List<&2, D.Note>, T.state.notes(u), d, nt) : {Some{D.Stepped{S.state.set_notes(z, d), d}} == Some{D.Stepped{SA.embed(u), _}} : Maybe<&2, D.Stepped<&2, S.State>>}
          +e : {S.state.set_notes(z, d) == SA.embed(u) : S.State} = Equal.trans(S.State, S.state.set_notes(z, d), S.state.set_notes(L.NS(z), d), SA.embed(u), setn(z, d), Equal.trans(S.State, S.state.set_notes(L.NS(z), d), S.state.set_notes(L.NS(SA.embed(u)), d), SA.embed(u), Equal.cong(S.State, S.State, x => S.state.set_notes(x, d), L.NS(z), L.NS(SA.embed(u)), ns), Equal.trans(S.State, S.state.set_notes(L.NS(SA.embed(u)), d), S.state.set_notes(L.NS(SA.embed(u)), T.state.notes(u)), SA.embed(u), Equal.cong(List<&2, D.Note>, S.State, x => S.state.set_notes(L.NS(SA.embed(u)), x), d, T.state.notes(u), Equal.sym(List<&2, D.Note>, T.state.notes(u), d, nt)), embed.notes(u))))
          Equal.cong(S.State, Maybe<&2, D.Stepped<&2, S.State>>, x => Some{D.Stepped{x, d}}, S.state.set_notes(z, d), SA.embed(u), e)

def from.top(+s: T.State, +n: Nat, +first: SA.Step, +rest: List<&2, SA.Step>, +u: T.State, echain: {SA.chain(s, n) == first <> rest : List<&2, SA.Step>}, eans: {N.answer(s, n) == T.state.stepped(u) : D.Stepped<&2, T.State>}, top: Top(u, SA.walk.go(first <> rest, SA.embed(s)))) -> {SA.walk(SA.embed(s), SA.chain(s, n)) == SA.lift(N.answer(s, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  %Equal.sym(List<&2, SA.Step>, SA.chain(s, n), first <> rest, echain) : {SA.walk(SA.embed(s), _) == SA.lift(N.answer(s, n)) : Maybe<&2, D.Stepped<&2, S.State>>}
  %Equal.sym(D.Stepped<&2, T.State>, N.answer(s, n), T.state.stepped(u), eans) : {SA.walk(SA.embed(s), first <> rest) == SA.lift(_) : Maybe<&2, D.Stepped<&2, S.State>>}
  top.notes(u, SA.walk.go(first <> rest, SA.embed(s)), top)

# A draw: one sm draw, then the grab moves of a distribution it opened.
def draw.case(+s: T.State, +n: Nat, +x1: S.State, +u: T.State, rel: C.Rel(u, x1), echain: {SA.chain(s, n) == SA.DrawStep{n} <> SA.sched(x1, S.world.first_turn(S.state.world(x1))) : List<&2, SA.Step>}, eans: {N.answer(s, n) == T.state.stepped(u) : D.Stepped<&2, T.State>}, legal: {SA.walk.legal(M.request(SA.embed(s)), SA.DrawStep{n}) == Some{n} : Maybe<&2, Nat>}, answered: {M.answer(SA.embed(s), n) == S.state.stepped(x1) : D.Stepped<&2, S.State>}) -> {SA.walk(SA.embed(s), SA.chain(s, n)) == SA.lift(N.answer(s, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  +rest : List<&2, SA.Step> = SA.sched(x1, S.world.first_turn(S.state.world(x1)))
  from.top(s, n, SA.DrawStep{n}, rest, u, echain, eans, top.first(SA.embed(s), SA.DrawStep{n}, rest, n, x1, u, legal, answered, rest.claim(u, x1, rel)))

def draw.health(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +n: Nat) -> {SA.walk(SA.embed(T.State{w, p, T.NeedHealth{}, l, g}), SA.chain(T.State{w, p, T.NeedHealth{}, l, g}, n)) == SA.lift(N.answer(T.State{w, p, T.NeedHealth{}, l, g}, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  +v : Nat = D.draw.value(D.table.health_range(S.world.table(w)), n)
  draw.case(T.State{w, p, T.NeedHealth{}, l, g}, n, M.health.chosen(S.State{w, p, S.NeedHealth{}, Nil{}, g}, v), N.health.chosen(T.State{w, p, T.NeedHealth{}, T.Empty{}, g}, v), C.rel.of(t => N.health.chosen(t, v), x => M.health.chosen(x, v), T.Empty{}, w, p, T.NeedHealth{}, T.Empty{}, g, S.NeedHealth{}, C.health_chosen.c(T.Empty{}, w, p, T.NeedHealth{}, T.Empty{}, g, S.NeedHealth{}, v)), {==}, {==}, {==}, {==})

def draw.amount(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +n: Nat) -> {SA.walk(SA.embed(T.State{w, p, T.NeedAmount{}, l, g}), SA.chain(T.State{w, p, T.NeedAmount{}, l, g}, n)) == SA.lift(N.answer(T.State{w, p, T.NeedAmount{}, l, g}, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  +v : Nat = D.draw.value(D.table.amount_range(S.world.table(w)), n)
  draw.case(T.State{w, p, T.NeedAmount{}, l, g}, n, M.amount.chosen(S.State{w, p, S.NeedAmount{}, Nil{}, g}, v), N.amount.chosen(T.State{w, p, T.NeedAmount{}, T.Empty{}, g}, v), C.rel.of(t => N.amount.chosen(t, v), x => M.amount.chosen(x, v), T.Empty{}, w, p, T.NeedAmount{}, T.Empty{}, g, S.NeedAmount{}, C.amount_chosen.c(T.Empty{}, w, p, T.NeedAmount{}, T.Empty{}, g, S.NeedAmount{}, v)), {==}, {==}, {==}, {==})

def draw.turn(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +n: Nat, +from: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>) -> {SA.walk(SA.embed(T.State{w, p, T.NeedTurnAmount{from, passing, winner}, l, g}), SA.chain(T.State{w, p, T.NeedTurnAmount{from, passing, winner}, l, g}, n)) == SA.lift(N.answer(T.State{w, p, T.NeedTurnAmount{from, passing, winner}, l, g}, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  +v : Nat = D.draw.value(D.table.amount_range(S.world.table(w)), n)
  draw.case(T.State{w, p, T.NeedTurnAmount{from, passing, winner}, l, g}, n, M.turn.winner(S.State{S.world.set_item_amount(w, v), p, S.NeedTurnAmount{from, passing, winner}, Nil{}, g}, from, passing, winner), N.turn.winner(T.State{S.world.set_item_amount(w, v), p, T.NeedTurnAmount{from, passing, winner}, T.Empty{}, g}, from, passing, winner), C.rel.of(t => N.turn.winner(t, from, passing, winner), x => M.turn.winner(x, from, passing, winner), T.Empty{}, S.world.set_item_amount(w, v), p, T.NeedTurnAmount{from, passing, winner}, T.Empty{}, g, S.NeedTurnAmount{from, passing, winner}, C.turn_winner.c(T.Empty{}, S.world.set_item_amount(w, v), p, T.NeedTurnAmount{from, passing, winner}, T.Empty{}, g, S.NeedTurnAmount{from, passing, winner}, from, passing, winner)), {==}, {==}, {==}, {==})

def draw.swap(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +n: Nat, +load: D.Load, +shells: List<&2, D.Shell>, i: Nat) -> {SA.walk(SA.embed(T.State{w, p, T.NeedSwap{load, shells, i}, l, g}), SA.chain(T.State{w, p, T.NeedSwap{load, shells, i}, l, g}, n)) == SA.lift(N.answer(T.State{w, p, T.NeedSwap{load, shells, i}, l, g}, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match i:
    case 0n:
      {==}
    case 1n+(+extra):
      +v : Nat = D.draw.value(D.Range{0n, extra}, n)
      draw.case(T.State{w, p, T.NeedSwap{load, shells, 1n+extra}, l, g}, n, M.shuffle(S.State{w, p, S.NeedSwap{load, shells, 1n+extra}, Nil{}, g}, load, G.swap(shells, 1n+extra, v), G.predecessor(1n+extra)), N.shuffle(T.State{w, p, T.NeedSwap{load, shells, 1n+extra}, T.Empty{}, g}, load, G.swap(shells, 1n+extra, v), G.predecessor(1n+extra)), C.rel.of(t => N.shuffle(t, load, G.swap(shells, 1n+extra, v), G.predecessor(1n+extra)), x => M.shuffle(x, load, G.swap(shells, 1n+extra, v), G.predecessor(1n+extra)), T.Empty{}, w, p, T.NeedSwap{load, shells, 1n+extra}, T.Empty{}, g, S.NeedSwap{load, shells, 1n+extra}, C.dcorr.corr(t => N.shuffle(t, load, G.swap(shells, 1n+extra, v), G.predecessor(1n+extra)), x => M.shuffle(x, load, G.swap(shells, 1n+extra, v), G.predecessor(1n+extra)), T.Empty{}, w, p, T.NeedSwap{load, shells, 1n+extra}, T.Empty{}, g, S.NeedSwap{load, shells, 1n+extra}, C.shuffle.c(T.Empty{}, w, p, T.NeedSwap{load, shells, 1n+extra}, T.Empty{}, g, S.NeedSwap{load, shells, 1n+extra}, load, G.swap(shells, 1n+extra, v), G.predecessor(1n+extra)))), {==}, {==}, {==}, {==})

def draw.batch(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +n: Nat) -> {SA.walk(SA.embed(T.State{w, p, T.NeedBatch{}, l, g}), SA.chain(T.State{w, p, T.NeedBatch{}, l, g}, n)) == SA.lift(N.answer(T.State{w, p, T.NeedBatch{}, l, g}, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match w:
    case S.World{D.Config{D.TwoSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+two, +three, +four}}:
        match two:
          case Nil{}:
            {==}
          case b1 <> Nil{}:
            {==}
          case +b1 <> +b2 <> +brest:
            +v : Nat = D.draw.value(D.Range{0n, List.length(&2, S.Batch, brest)}, n)
            draw.case(T.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{(b1 <> b2 <> brest), three, four}}, p, T.NeedBatch{}, l, g}, n, M.batch(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{(b1 <> b2 <> brest), three, four}}, p, S.NeedBatch{}, Nil{}, g}, v), N.batch(T.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{(b1 <> b2 <> brest), three, four}}, p, T.NeedBatch{}, T.Empty{}, g}, v), C.rel.of(t => N.batch(t, v), x => M.batch(x, v), T.Empty{}, S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{(b1 <> b2 <> brest), three, four}}, p, T.NeedBatch{}, T.Empty{}, g, S.NeedBatch{}, C.dcorr.corr(t => N.batch(t, v), x => M.batch(x, v), T.Empty{}, S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{(b1 <> b2 <> brest), three, four}}, p, T.NeedBatch{}, T.Empty{}, g, S.NeedBatch{}, C.batch.c(T.Empty{}, S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{(b1 <> b2 <> brest), three, four}}, p, T.NeedBatch{}, T.Empty{}, g, S.NeedBatch{}, v))), {==}, {==}, {==}, {==})
    case S.World{D.Config{D.ThreeSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+two, +three, +four}}:
        match three:
          case Nil{}:
            {==}
          case b1 <> Nil{}:
            {==}
          case +b1 <> +b2 <> +brest:
            +v : Nat = D.draw.value(D.Range{0n, List.length(&2, S.Batch, brest)}, n)
            draw.case(T.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, (b1 <> b2 <> brest), four}}, p, T.NeedBatch{}, l, g}, n, M.batch(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, (b1 <> b2 <> brest), four}}, p, S.NeedBatch{}, Nil{}, g}, v), N.batch(T.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, (b1 <> b2 <> brest), four}}, p, T.NeedBatch{}, T.Empty{}, g}, v), C.rel.of(t => N.batch(t, v), x => M.batch(x, v), T.Empty{}, S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, (b1 <> b2 <> brest), four}}, p, T.NeedBatch{}, T.Empty{}, g, S.NeedBatch{}, C.dcorr.corr(t => N.batch(t, v), x => M.batch(x, v), T.Empty{}, S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, (b1 <> b2 <> brest), four}}, p, T.NeedBatch{}, T.Empty{}, g, S.NeedBatch{}, C.batch.c(T.Empty{}, S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, (b1 <> b2 <> brest), four}}, p, T.NeedBatch{}, T.Empty{}, g, S.NeedBatch{}, v))), {==}, {==}, {==}, {==})
    case S.World{D.Config{D.FourSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+two, +three, +four}}:
        match four:
          case Nil{}:
            {==}
          case b1 <> Nil{}:
            {==}
          case +b1 <> +b2 <> +brest:
            +v : Nat = D.draw.value(D.Range{0n, List.length(&2, S.Batch, brest)}, n)
            draw.case(T.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, (b1 <> b2 <> brest)}}, p, T.NeedBatch{}, l, g}, n, M.batch(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, (b1 <> b2 <> brest)}}, p, S.NeedBatch{}, Nil{}, g}, v), N.batch(T.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, (b1 <> b2 <> brest)}}, p, T.NeedBatch{}, T.Empty{}, g}, v), C.rel.of(t => N.batch(t, v), x => M.batch(x, v), T.Empty{}, S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, (b1 <> b2 <> brest)}}, p, T.NeedBatch{}, T.Empty{}, g, S.NeedBatch{}, C.dcorr.corr(t => N.batch(t, v), x => M.batch(x, v), T.Empty{}, S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, (b1 <> b2 <> brest)}}, p, T.NeedBatch{}, T.Empty{}, g, S.NeedBatch{}, C.batch.c(T.Empty{}, S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, (b1 <> b2 <> brest)}}, p, T.NeedBatch{}, T.Empty{}, g, S.NeedBatch{}, v))), {==}, {==}, {==}, {==})

def draw.phone(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +n: Nat, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot) -> {SA.walk(SA.embed(T.State{w, p, T.NeedPhone{seat, owner, slot}, l, g}), SA.chain(T.State{w, p, T.NeedPhone{seat, owner, slot}, l, g}, n)) == SA.lift(N.answer(T.State{w, p, T.NeedPhone{seat, owner, slot}, l, g}, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match w:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      match gun:
        case Nil{}:
          {==}
        case s1 <> Nil{}:
          {==}
        case s1 <> s2 <> Nil{}:
          {==}
        case s1 <> s2 <> s3 <> Nil{}:
          {==}
        case +s1 <> +s2 <> +s3 <> +s4 <> +srest:
          +v : Nat = D.draw.value(D.Range{2n, List.length(&2, D.Shell, srest)}, n)
          draw.case(T.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, s1 <> s2 <> s3 <> s4 <> srest, shown, deck}, p, T.NeedPhone{seat, owner, slot}, l, g}, n, M.item.clue(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, s1 <> s2 <> s3 <> s4 <> srest, shown, deck}, p, S.NeedPhone{seat, owner, slot}, Nil{}, g}, seat, owner, slot, v), N.item.clue(T.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, s1 <> s2 <> s3 <> s4 <> srest, shown, deck}, p, T.NeedPhone{seat, owner, slot}, T.Empty{}, g}, seat, owner, slot, v), C.rel.of(t => N.item.clue(t, seat, owner, slot, v), x => M.item.clue(x, seat, owner, slot, v), T.Empty{}, S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, s1 <> s2 <> s3 <> s4 <> srest, shown, deck}, p, T.NeedPhone{seat, owner, slot}, T.Empty{}, g, S.NeedPhone{seat, owner, slot}, C.item_clue.c(T.Empty{}, S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, s1 <> s2 <> s3 <> s4 <> srest, shown, deck}, p, T.NeedPhone{seat, owner, slot}, T.Empty{}, g, S.NeedPhone{seat, owner, slot}, seat, owner, slot, v)), {==}, {==}, {==}, {==})

def draw.first(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +n: Nat) -> {SA.walk(SA.embed(T.State{w, p, T.NeedFirst{}, l, g}), SA.chain(T.State{w, p, T.NeedFirst{}, l, g}, n)) == SA.lift(N.answer(T.State{w, p, T.NeedFirst{}, l, g}, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match w:
    case S.World{D.Config{D.TwoSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      +seat : D.Seat = G.value.or(D.Seat, G.nth(D.Seat, D.table.seats(D.TwoSeats{}), D.draw.value(V.first.range(D.TwoSeats{}), n)), D.Seat0{})
      draw.case(T.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, l, g}, n, M.first.chosen(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedFirst{}, Nil{}, g}, seat), N.first.chosen(T.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, T.Empty{}, g}, seat), C.rel.of(t => N.first.chosen(t, seat), x => M.first.chosen(x, seat), T.Empty{}, S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, T.Empty{}, g, S.NeedFirst{}, C.first_chosen.c(T.Empty{}, S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, T.Empty{}, g, S.NeedFirst{}, seat)), {==}, {==}, {==}, {==})
    case S.World{D.Config{D.ThreeSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      +seat : D.Seat = G.value.or(D.Seat, G.nth(D.Seat, D.table.seats(D.ThreeSeats{}), D.draw.value(V.first.range(D.ThreeSeats{}), n)), D.Seat0{})
      draw.case(T.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, l, g}, n, M.first.chosen(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedFirst{}, Nil{}, g}, seat), N.first.chosen(T.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, T.Empty{}, g}, seat), C.rel.of(t => N.first.chosen(t, seat), x => M.first.chosen(x, seat), T.Empty{}, S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, T.Empty{}, g, S.NeedFirst{}, C.first_chosen.c(T.Empty{}, S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, T.Empty{}, g, S.NeedFirst{}, seat)), {==}, {==}, {==}, {==})
    case S.World{D.Config{D.FourSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      +seat : D.Seat = G.value.or(D.Seat, G.nth(D.Seat, D.table.seats(D.FourSeats{}), D.draw.value(V.first.range(D.FourSeats{}), n)), D.Seat0{})
      draw.case(T.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, l, g}, n, M.first.chosen(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedFirst{}, Nil{}, g}, seat), N.first.chosen(T.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, T.Empty{}, g}, seat), C.rel.of(t => N.first.chosen(t, seat), x => M.first.chosen(x, seat), T.Empty{}, S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, T.Empty{}, g, S.NeedFirst{}, C.first_chosen.c(T.Empty{}, S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, T.NeedFirst{}, T.Empty{}, g, S.NeedFirst{}, seat)), {==}, {==}, {==}, {==})

def item.fin(+w: S.World, +p: S.Players, +ph: T.Phase, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, found: Maybe<&2, D.Item>) -> L.Fin.of(N.grab.distribute(N.grab.chosen(T.State{w, p, ph, T.Empty{}, g}, seat, found), seat), M.grab.chosen(S.State{w, p, q, Nil{}, g}, seat, found), SA.walk.go(SA.sched(M.grab.chosen(S.State{w, p, q, Nil{}, g}, seat, found), seat), M.grab.chosen(S.State{w, p, q, Nil{}, g}, seat, found))):
  match found:
    case Some{+item}:
      cont.claim(w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.Granted{seat, item}}}, I.grabs.give(g, seat, item), q, seat)
    case None{}:
      cont.claim(w, p, ph, T.Snoc{T.Empty{}, D.Told{seat, D.EmptyBriefcase{}}}, g, q, seat)

def draw.item(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +n: Nat, +seat: D.Seat, +f1: D.Item, +f2: D.Item, +rest: List<&2, D.Item>) -> {SA.walk(SA.embed(T.State{w, p, T.NeedItem{seat, f1, f2, rest}, l, g}), SA.chain(T.State{w, p, T.NeedItem{seat, f1, f2, rest}, l, g}, n)) == SA.lift(N.answer(T.State{w, p, T.NeedItem{seat, f1, f2, rest}, l, g}, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  +found : Maybe<&2, D.Item> = G.nth(D.Item, f1 <> f2 <> rest, D.draw.value(D.Range{0n, List.length(&2, D.Item, rest)}, n))
  +sched : List<&2, SA.Step> = SA.sched(M.grab.chosen(S.State{w, p, S.NeedItem{seat, f1, f2, rest}, Nil{}, g}, seat, found), seat)
  from.top(T.State{w, p, T.NeedItem{seat, f1, f2, rest}, l, g}, n, SA.DrawStep{n}, sched, N.grab.distribute(N.grab.chosen(T.State{w, p, T.NeedItem{seat, f1, f2, rest}, T.Empty{}, g}, seat, found), seat), {==}, {==}, top.first(SA.embed(T.State{w, p, T.NeedItem{seat, f1, f2, rest}, l, g}), SA.DrawStep{n}, sched, n, M.grab.chosen(S.State{w, p, S.NeedItem{seat, f1, f2, rest}, Nil{}, g}, seat, found), N.grab.distribute(N.grab.chosen(T.State{w, p, T.NeedItem{seat, f1, f2, rest}, T.Empty{}, g}, seat, found), seat), {==}, {==}, item.fin(w, p, T.NeedItem{seat, f1, f2, rest}, g, S.NeedItem{seat, f1, f2, rest}, seat, found)))
