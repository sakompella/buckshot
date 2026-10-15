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
import ./simple-valid-proof.bend as Vd

# simple_run_refines: sm walking the chains of a simple run ends at the run's
# end, holding the run's notes.

def pre(+d: List<&2, D.Note>, r: Maybe<&2, D.Stepped<&2, S.State>>) -> Maybe<&2, D.Stepped<&2, S.State>>:
  match r:
    case None{}:
      None{}
    case Some{D.Stepped{s, e}}:
      Some{D.Stepped{s, List.append(&2, D.Note, d, e)}}

def pre.nil(+r: Maybe<&2, D.Stepped<&2, S.State>>) -> {pre(Nil{}, r) == r : Maybe<&2, D.Stepped<&2, S.State>>}:
  match r:
    case None{}:
      {==}
    case Some{D.Stepped{s, e}}:
      {==}

def merge.pre(+a: S.State, +f: List<&2, D.Note>, +d: List<&2, D.Note>, +r: Maybe<&2, D.Stepped<&2, S.State>>) -> {SA.walk.merge(D.Stepped{a, f}, pre(d, r)) == pre(List.append(&2, D.Note, f, d), r) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match r:
    case None{}:
      {==}
    case Some{D.Stepped{+s, +e}}:
      Equal.cong(List<&2, D.Note>, Maybe<&2, D.Stepped<&2, S.State>>, x => Some{D.Stepped{s, x}}, List.append(&2, D.Note, f, List.append(&2, D.Note, d, e)), List.append(&2, D.Note, List.append(&2, D.Note, f, d), e), Equal.sym(List<&2, D.Note>, List.append(&2, D.Note, List.append(&2, D.Note, f, d), e), List.append(&2, D.Note, f, List.append(&2, D.Note, d, e)), Wk.append_assoc(D.Note, f, d, e)))

def notes.second(st: Maybe<&2, D.Stepped<&2, S.State>>) -> List<&2, D.Note>:
  match st:
    case Some{D.Stepped{s, n}}:
      n
    case None{}:
      Nil{}

def some.notes(+a: S.State, +n: List<&2, D.Note>, +z: S.State, +d: List<&2, D.Note>, e: {Some{D.Stepped{a, n}} == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> {n == d : List<&2, D.Note>}:
  Equal.cong(Maybe<&2, D.Stepped<&2, S.State>>, List<&2, D.Note>, notes.second, Some{D.Stepped{a, n}}, Some{D.Stepped{z, d}}, e)

def GA(xs: List<&2, SA.Step>) -> Type:
  @+ys:List<&2, SA.Step> -> @+x:S.State -> @+z:S.State -> @+d:List<&2, D.Note> -> @e:{SA.walk.go(xs, x) == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>} -> {SA.walk.go(List.append(&2, SA.Step, xs, ys), x) == pre(d, SA.walk.go(ys, z)) : Maybe<&2, D.Stepped<&2, S.State>>}

def ga.rest(+r: List<&2, SA.Step>, ih: GA(r), +ys: List<&2, SA.Step>, +a: S.State, +f: List<&2, D.Note>, rr: Maybe<&2, D.Stepped<&2, S.State>>, +er: {SA.walk.go(r, a) == rr : Maybe<&2, D.Stepped<&2, S.State>>}, +z: S.State, +d: List<&2, D.Note>, +e: {SA.walk.merge(D.Stepped{a, f}, rr) == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> {SA.walk.merge(D.Stepped{a, f}, SA.walk.go(List.append(&2, SA.Step, r, ys), a)) == pre(d, SA.walk.go(ys, z)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match rr:
    case None{}:
      Wk.absurd({SA.walk.merge(D.Stepped{a, f}, SA.walk.go(List.append(&2, SA.Step, r, ys), a)) == pre(d, SA.walk.go(ys, z)) : Maybe<&2, D.Stepped<&2, S.State>>}, Wk.maybe.clash(D.Stepped<&2, S.State>, D.Stepped{z, d}, e))
    case Some{D.Stepped{+z2, +d2}}:
      +ez : {z2 == z : S.State} = Vd.some.state(z2, List.append(&2, D.Note, f, d2), z, d, e)
      +ed : {List.append(&2, D.Note, f, d2) == d : List<&2, D.Note>} = some.notes(z2, List.append(&2, D.Note, f, d2), z, d, e)
      %Equal.sym(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.go(List.append(&2, SA.Step, r, ys), a), pre(d2, SA.walk.go(ys, z2)), ih(ys, a, z2, d2, er)) : {SA.walk.merge(D.Stepped{a, f}, _) == pre(d, SA.walk.go(ys, z)) : Maybe<&2, D.Stepped<&2, S.State>>}
      %ez : {SA.walk.merge(D.Stepped{a, f}, pre(d2, SA.walk.go(ys, z2))) == pre(d, SA.walk.go(ys, _)) : Maybe<&2, D.Stepped<&2, S.State>>}
      %ed : {SA.walk.merge(D.Stepped{a, f}, pre(d2, SA.walk.go(ys, z2))) == pre(_, SA.walk.go(ys, z2)) : Maybe<&2, D.Stepped<&2, S.State>>}
      merge.pre(a, f, d2, SA.walk.go(ys, z2))

def ga.step(+r: List<&2, SA.Step>, ih: GA(r), +ys: List<&2, SA.Step>, st0: D.Stepped<&2, S.State>, +z: S.State, +d: List<&2, D.Note>, e: {SA.walk.merge(st0, SA.walk.go(r, M.stepped.state(st0))) == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> {SA.walk.merge(st0, SA.walk.go(List.append(&2, SA.Step, r, ys), M.stepped.state(st0))) == pre(d, SA.walk.go(ys, z)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match st0:
    case D.Stepped{+a, +f}:
      ga.rest(r, ih, ys, a, f, SA.walk.go(r, a), {==}, z, d, e)

def ga.ans(+st: SA.Step, +r: List<&2, SA.Step>, ih: GA(r), +ys: List<&2, SA.Step>, +x: S.State, l: Maybe<&2, Nat>, +z: S.State, +d: List<&2, D.Note>, e: {SA.walk.answer(l, x, next => SA.walk.go(r, next)) == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> {SA.walk.answer(l, x, next => SA.walk.go(List.append(&2, SA.Step, r, ys), next)) == pre(d, SA.walk.go(ys, z)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match l:
    case None{}:
      Wk.absurd({None{} == pre(d, SA.walk.go(ys, z)) : Maybe<&2, D.Stepped<&2, S.State>>}, Wk.maybe.clash(D.Stepped<&2, S.State>, D.Stepped{z, d}, e))
    case Some{+k}:
      ga.step(r, ih, ys, M.answer(x, k), z, d, e)

def ga.nil(+ys: List<&2, SA.Step>, +x: S.State, +z: S.State, +d: List<&2, D.Note>, +e: {Some{D.Stepped{x, Nil{}}} == Some{D.Stepped{z, d}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> {SA.walk.go(ys, x) == pre(d, SA.walk.go(ys, z)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  +ex : {x == z : S.State} = Vd.some.state(x, Nil{}, z, d, e)
  +ed : {Nil{} == d : List<&2, D.Note>} = some.notes(x, Nil{}, z, d, e)
  %ed : {SA.walk.go(ys, x) == pre(_, SA.walk.go(ys, z)) : Maybe<&2, D.Stepped<&2, S.State>>}
  %ex : {SA.walk.go(ys, x) == pre(Nil{}, SA.walk.go(ys, _)) : Maybe<&2, D.Stepped<&2, S.State>>}
  Equal.sym(Maybe<&2, D.Stepped<&2, S.State>>, pre(Nil{}, SA.walk.go(ys, x)), SA.walk.go(ys, x), pre.nil(SA.walk.go(ys, x)))

def go.append(xs: List<&2, SA.Step>) -> GA(xs):
  match xs:
    case Nil{}:
      +ys => +x => +z => +d => e => ga.nil(ys, x, z, d, e)
    case +st <> +r:
      +ys => +x => +z => +d => e => ga.ans(st, r, go.append(r), ys, x, SA.walk.legal(M.request(x), st), z, d, e)

def ns.set(+z: S.State, +d: List<&2, D.Note>) -> {L.NS(S.state.set_notes(z, d)) == L.NS(z) : S.State}:
  match z:
    case S.State{w, p, ph, n, g}:
      {==}

def setset(+a: S.State, +y: List<&2, D.Note>, +x: List<&2, D.Note>) -> {S.state.set_notes(S.state.set_notes(a, y), x) == S.state.set_notes(a, x) : S.State}:
  match a:
    case S.State{w, p, ph, n, g}:
      {==}

def legal.disc(r: D.Request) -> Data:
  match r:
    case D.Finished{}:
      Unit
    case D.Stuck{}:
      Unit
    case _:
      Empty

def rf.legal.clash(+r: D.Request, +st: SA.Step, +k: Nat, el: {SA.walk.legal(r, st) == Some{k} : Maybe<&2, Nat>}, other: legal.disc(r)) -> Empty:
  match r st:
    case D.Finished{} SA.DrawStep{a}:
      Wk.maybe.clash(Nat, k, el)
    case D.Finished{} SA.ChoiceStep{s, m}:
      Wk.maybe.clash(Nat, k, el)
    case D.Stuck{} SA.DrawStep{a}:
      Wk.maybe.clash(Nat, k, el)
    case D.Stuck{} SA.ChoiceStep{s, m}:
      Wk.maybe.clash(Nat, k, el)
    case D.Draw{a, b} st:
      match other:
    case D.Choose{m} st:
      match other:

def ans.ns(r: D.Request, +w: S.World, +p: S.Players, +ph: S.Phase, +nn: List<&2, D.Note>, +g: S.Grabs, +st: SA.Step, +k: Nat, el: {SA.walk.legal(r, st) == Some{k} : Maybe<&2, Nat>}) -> {M.answer.request(S.State{w, p, ph, nn, g}, k, r) == M.answer.request(S.State{w, p, ph, Nil{}, g}, k, r) : D.Stepped<&2, S.State>}:
  match r st:
    case D.Finished{} st:
      Wk.absurd({D.Stepped{S.State{w, p, ph, nn, g}, Nil{}} == D.Stepped{S.State{w, p, ph, Nil{}, g}, Nil{}} : D.Stepped<&2, S.State>}, rf.legal.clash(D.Finished{}, st, k, el, Unit{}))
    case D.Stuck{} st:
      Wk.absurd({D.Stepped{S.State{w, p, ph, nn, g}, Nil{}} == D.Stepped{S.State{w, p, ph, Nil{}, g}, Nil{}} : D.Stepped<&2, S.State>}, rf.legal.clash(D.Stuck{}, st, k, el, Unit{}))
    case D.Draw{a, b} st:
      {==}
    case D.Choose{m} st:
      {==}

def ns.ans(+w: S.World, +p: S.Players, +ph: S.Phase, +nn: List<&2, D.Note>, +g: S.Grabs, +st: SA.Step, +r: List<&2, SA.Step>, l: Maybe<&2, Nat>, +el: {SA.walk.legal(M.request(S.State{w, p, ph, nn, g}), st) == l : Maybe<&2, Nat>}) -> {SA.walk.answer(l, S.State{w, p, ph, nn, g}, next => SA.walk.go(r, next)) == SA.walk.answer(l, S.State{w, p, ph, Nil{}, g}, next => SA.walk.go(r, next)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match l:
    case None{}:
      {==}
    case Some{+k}:
      Equal.cong(D.Stepped<&2, S.State>, Maybe<&2, D.Stepped<&2, S.State>>, y => SA.walk.merge(y, SA.walk.go(r, M.stepped.state(y))), M.answer(S.State{w, p, ph, nn, g}, k), M.answer(S.State{w, p, ph, Nil{}, g}, k), ans.ns(M.request(S.State{w, p, ph, nn, g}), w, p, ph, nn, g, st, k, el))

def go.ns(+st: SA.Step, +r: List<&2, SA.Step>, +z: S.State) -> {SA.walk.go(st <> r, z) == SA.walk.go(st <> r, L.NS(z)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match z:
    case S.State{+w, +p, +ph, +nn, +g}:
      ns.ans(w, p, ph, nn, g, st, r, SA.walk.legal(M.request(S.State{w, p, ph, nn, g}), st), {==})

def notes.pre(+d: List<&2, D.Note>, ys: List<&2, SA.Step>, +z: S.State, +z2: S.State, +ens: {L.NS(z) == L.NS(z2) : S.State}) -> {SA.walk.notes(pre(d, SA.walk.go(ys, z))) == SA.walk.notes(pre(d, SA.walk.go(ys, z2))) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match ys:
    case Nil{}:
      +x : List<&2, D.Note> = List.append(&2, D.Note, d, Nil{})
      +e : {S.state.set_notes(z, x) == S.state.set_notes(z2, x) : S.State} = Equal.trans(S.State, S.state.set_notes(z, x), S.state.set_notes(L.NS(z), x), S.state.set_notes(z2, x), Rf.setn(z, x), Equal.trans(S.State, S.state.set_notes(L.NS(z), x), S.state.set_notes(L.NS(z2), x), S.state.set_notes(z2, x), Equal.cong(S.State, S.State, v => S.state.set_notes(v, x), L.NS(z), L.NS(z2), ens), Equal.sym(S.State, S.state.set_notes(z2, x), S.state.set_notes(L.NS(z2), x), Rf.setn(z2, x))))
      Equal.cong(S.State, Maybe<&2, D.Stepped<&2, S.State>>, v => Some{D.Stepped{v, x}}, S.state.set_notes(z, x), S.state.set_notes(z2, x), e)
    case +st <> +r:
      +e : {SA.walk.go(st <> r, z) == SA.walk.go(st <> r, z2) : Maybe<&2, D.Stepped<&2, S.State>>} = Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.go(st <> r, z), SA.walk.go(st <> r, L.NS(z)), SA.walk.go(st <> r, z2), go.ns(st, r, z), Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.go(st <> r, L.NS(z)), SA.walk.go(st <> r, L.NS(z2)), SA.walk.go(st <> r, z2), Equal.cong(S.State, Maybe<&2, D.Stepped<&2, S.State>>, v => SA.walk.go(st <> r, v), L.NS(z), L.NS(z2), ens), Equal.sym(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.go(st <> r, z2), SA.walk.go(st <> r, L.NS(z2)), go.ns(st, r, z2))))
      Equal.cong(Maybe<&2, D.Stepped<&2, S.State>>, Maybe<&2, D.Stepped<&2, S.State>>, v => SA.walk.notes(pre(d, v)), SA.walk.go(st <> r, z), SA.walk.go(st <> r, z2), e)

def pre.ran(+d: List<&2, D.Note>, r: Maybe<&2, D.Stepped<&2, S.State>>, +e: S.State, +n2: List<&2, D.Note>, +ih: {SA.walk.notes(r) == Some{D.Stepped{S.state.set_notes(e, n2), n2}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> {SA.walk.notes(pre(d, r)) == Some{D.Stepped{S.state.set_notes(e, List.append(&2, D.Note, d, n2)), List.append(&2, D.Note, d, n2)}} : Maybe<&2, D.Stepped<&2, S.State>>}:
  match r:
    case None{}:
      Wk.absurd({None{} == Some{D.Stepped{S.state.set_notes(e, List.append(&2, D.Note, d, n2)), List.append(&2, D.Note, d, n2)}} : Maybe<&2, D.Stepped<&2, S.State>>}, Wk.maybe.clash(D.Stepped<&2, S.State>, D.Stepped{S.state.set_notes(e, n2), n2}, ih))
    case Some{D.Stepped{+z, +n1}}:
      +en : {n1 == n2 : List<&2, D.Note>} = some.notes(S.state.set_notes(z, n1), n1, S.state.set_notes(e, n2), n2, ih)
      +es : {S.state.set_notes(z, n1) == S.state.set_notes(e, n2) : S.State} = Vd.some.state(S.state.set_notes(z, n1), n1, S.state.set_notes(e, n2), n2, ih)
      +es2 : {S.state.set_notes(z, n2) == S.state.set_notes(e, n2) : S.State} = Equal.trans(S.State, S.state.set_notes(z, n2), S.state.set_notes(z, n1), S.state.set_notes(e, n2), Equal.cong(List<&2, D.Note>, S.State, v => S.state.set_notes(z, v), n2, n1, Equal.sym(List<&2, D.Note>, n1, n2, en)), es)
      +x : List<&2, D.Note> = List.append(&2, D.Note, d, n2)
      +ex : {S.state.set_notes(z, x) == S.state.set_notes(e, x) : S.State} = Equal.trans(S.State, S.state.set_notes(z, x), S.state.set_notes(S.state.set_notes(z, n2), x), S.state.set_notes(e, x), Equal.sym(S.State, S.state.set_notes(S.state.set_notes(z, n2), x), S.state.set_notes(z, x), setset(z, n2, x)), Equal.trans(S.State, S.state.set_notes(S.state.set_notes(z, n2), x), S.state.set_notes(S.state.set_notes(e, n2), x), S.state.set_notes(e, x), Equal.cong(S.State, S.State, v => S.state.set_notes(v, x), S.state.set_notes(z, n2), S.state.set_notes(e, n2), es2), setset(e, n2, x)))
      %Equal.sym(List<&2, D.Note>, n1, n2, en) : {Some{D.Stepped{S.state.set_notes(z, List.append(&2, D.Note, d, _)), List.append(&2, D.Note, d, _)}} == Some{D.Stepped{S.state.set_notes(e, x), x}} : Maybe<&2, D.Stepped<&2, S.State>>}
      Equal.cong(S.State, Maybe<&2, D.Stepped<&2, S.State>>, v => Some{D.Stepped{v, x}}, S.state.set_notes(z, x), S.state.set_notes(e, x), ex)

def WN(+r: Maybe<&2, D.Stepped<&2, S.State>>, +z0: S.State, +d0: List<&2, D.Note>) -> Data:
  Sigma<&2, &2, S.State, z => Sigma<&2, &2, {r == Some{D.Stepped{z, d0}} : Maybe<&2, D.Stepped<&2, S.State>>}, e0 => {S.state.set_notes(z, d0) == z0 : S.State}>>

def wn.inv(r: Maybe<&2, D.Stepped<&2, S.State>>, +z0: S.State, +d0: List<&2, D.Note>, +e: {SA.walk.notes(r) == Some{D.Stepped{z0, d0}} : Maybe<&2, D.Stepped<&2, S.State>>}) -> WN(r, z0, d0):
  match r:
    case None{}:
      Wk.absurd(WN(None{}, z0, d0), Wk.maybe.clash(D.Stepped<&2, S.State>, D.Stepped{z0, d0}, e))
    case Some{D.Stepped{+z, +n}}:
      +en : {n == d0 : List<&2, D.Note>} = some.notes(S.state.set_notes(z, n), n, z0, d0, e)
      %en : WN(Some{D.Stepped{z, n}}, z0, _)
      (z, ({==}, Vd.some.state(S.state.set_notes(z, n), n, z0, d0, e)))

def step.cons(+x: S.State, +c: SA.Step, +cr: List<&2, SA.Step>, +c2: List<&2, SA.Step>, +u: T.State, +n1: List<&2, D.Note>, +e: T.State, +n2: List<&2, D.Note>, ih: {SA.walk.notes(SA.walk.go(c2, SA.embed(u))) == Some{D.Stepped{S.state.set_notes(SA.embed(e), n2), n2}} : Maybe<&2, D.Stepped<&2, S.State>>}, inv: WN(SA.walk.go(c <> cr, x), SA.embed(u), n1)) -> {SA.walk.notes(SA.walk.go(List.append(&2, SA.Step, c <> cr, c2), x)) == Some{D.Stepped{S.state.set_notes(SA.embed(e), List.append(&2, D.Note, n1, n2)), List.append(&2, D.Note, n1, n2)}} : Maybe<&2, D.Stepped<&2, S.State>>}:
  match inv:
    case Tuple{+z, Tuple{+er, +ez}}:
      +ga : {SA.walk.go(List.append(&2, SA.Step, c <> cr, c2), x) == pre(n1, SA.walk.go(c2, z)) : Maybe<&2, D.Stepped<&2, S.State>>} = go.append(c <> cr)(c2, x, z, n1, er)
      +ens : {L.NS(z) == L.NS(SA.embed(u)) : S.State} = Equal.trans(S.State, L.NS(z), L.NS(S.state.set_notes(z, n1)), L.NS(SA.embed(u)), Equal.sym(S.State, L.NS(S.state.set_notes(z, n1)), L.NS(z), ns.set(z, n1)), Equal.cong(S.State, S.State, v => L.NS(v), S.state.set_notes(z, n1), SA.embed(u), ez))
      +np : {SA.walk.notes(pre(n1, SA.walk.go(c2, z))) == SA.walk.notes(pre(n1, SA.walk.go(c2, SA.embed(u)))) : Maybe<&2, D.Stepped<&2, S.State>>} = notes.pre(n1, c2, z, SA.embed(u), ens)
      +pr : {SA.walk.notes(pre(n1, SA.walk.go(c2, SA.embed(u)))) == Some{D.Stepped{S.state.set_notes(SA.embed(e), List.append(&2, D.Note, n1, n2)), List.append(&2, D.Note, n1, n2)}} : Maybe<&2, D.Stepped<&2, S.State>>} = pre.ran(n1, SA.walk.go(c2, SA.embed(u)), SA.embed(e), n2, ih)
      Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.notes(SA.walk.go(List.append(&2, SA.Step, c <> cr, c2), x)), SA.walk.notes(pre(n1, SA.walk.go(c2, z))), Some{D.Stepped{S.state.set_notes(SA.embed(e), List.append(&2, D.Note, n1, n2)), List.append(&2, D.Note, n1, n2)}}, Equal.cong(Maybe<&2, D.Stepped<&2, S.State>>, Maybe<&2, D.Stepped<&2, S.State>>, v => SA.walk.notes(v), SA.walk.go(List.append(&2, SA.Step, c <> cr, c2), x), pre(n1, SA.walk.go(c2, z)), ga), Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.notes(pre(n1, SA.walk.go(c2, z))), SA.walk.notes(pre(n1, SA.walk.go(c2, SA.embed(u)))), Some{D.Stepped{S.state.set_notes(SA.embed(e), List.append(&2, D.Note, n1, n2)), List.append(&2, D.Note, n1, n2)}}, np, pr))

def step.run(+x: S.State, chain: List<&2, SA.Step>, +c2: List<&2, SA.Step>, st: D.Stepped<&2, T.State>, r: D.Ran<&2, T.State>, +href: {SA.walk(x, chain) == SA.lift(st) : Maybe<&2, D.Stepped<&2, S.State>>}, ih: {SA.walk.notes(SA.walk.go(c2, SA.embed(N.stepped.state(st)))) == SA.ran(r) : Maybe<&2, D.Stepped<&2, S.State>>}) -> {SA.walk.notes(SA.walk.go(List.append(&2, SA.Step, chain, c2), x)) == SA.ran(N.run.merge(st, r)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match chain st r:
    case Nil{} D.Stepped{+u, +n1} D.Ran{+e, +n2, t}:
      +ex : {x == SA.embed(u) : S.State} = Vd.some.state(x, Nil{}, SA.embed(u), n1, href)
      +en : {Nil{} == n1 : List<&2, D.Note>} = some.notes(x, Nil{}, SA.embed(u), n1, href)
      %Equal.sym(S.State, x, SA.embed(u), ex) : {SA.walk.notes(SA.walk.go(c2, _)) == Some{D.Stepped{S.state.set_notes(SA.embed(e), List.append(&2, D.Note, n1, n2)), List.append(&2, D.Note, n1, n2)}} : Maybe<&2, D.Stepped<&2, S.State>>}
      %en : {SA.walk.notes(SA.walk.go(c2, SA.embed(u))) == Some{D.Stepped{S.state.set_notes(SA.embed(e), List.append(&2, D.Note, _, n2)), List.append(&2, D.Note, _, n2)}} : Maybe<&2, D.Stepped<&2, S.State>>}
      ih
    case +c <> +cr D.Stepped{+u, +n1} D.Ran{+e, +n2, t}:
      step.cons(x, c, cr, c2, u, n1, e, n2, ih, wn.inv(SA.walk.go(c <> cr, x), SA.embed(u), n1, href))

def RRH(fuel: Nat) -> Type:
  @+s:T.State -> @+tape:List<&2, Nat> -> {SA.replay(SA.embed(s), SA.chains(fuel, s, tape)) == SA.ran(N.run(fuel, s, tape)) : Maybe<&2, D.Stepped<&2, S.State>>}

def rr.zero(request: T.Request, +s: T.State, tape: List<&2, Nat>) -> {SA.replay(SA.embed(s), SA.chains.request(0n, request, s, tape)) == SA.ran(N.run.request(0n, request, s, tape)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match request tape:
    case T.Finished{} Nil{}:
      {==}
    case T.Finished{} m <> ms:
      {==}
    case T.Stuck{} Nil{}:
      {==}
    case T.Stuck{} m <> ms:
      {==}
    case T.Draw{a, b} Nil{}:
      {==}
    case T.Draw{a, b} m <> ms:
      {==}
    case T.Choose{a, b} Nil{}:
      {==}
    case T.Choose{a, b} m <> ms:
      {==}

def rr.succ(+f: Nat, request: T.Request, +s: T.State, tape: List<&2, Nat>, recur: RRH(f)) -> {SA.replay(SA.embed(s), SA.chains.request(1n+f, request, s, tape)) == SA.ran(N.run.request(1n+f, request, s, tape)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match request tape:
    case T.Finished{} Nil{}:
      {==}
    case T.Finished{} m <> ms:
      {==}
    case T.Stuck{} Nil{}:
      {==}
    case T.Stuck{} m <> ms:
      {==}
    case T.Draw{a, b} Nil{}:
      {==}
    case T.Choose{a, b} Nil{}:
      {==}
    case T.Draw{a, b} +n <> +rest:
      +next : T.State = N.stepped.state(N.answer(s, n))
      step.run(SA.embed(s), SA.chain(s, n), SA.chains.request(f, P.request(next), next, rest), N.answer(s, n), N.run.request(f, P.request(next), next, rest), Id.refines(s, n), recur(next, rest))
    case T.Choose{a, b} +n <> +rest:
      +next : T.State = N.stepped.state(N.answer(s, n))
      step.run(SA.embed(s), SA.chain(s, n), SA.chains.request(f, P.request(next), next, rest), N.answer(s, n), N.run.request(f, P.request(next), next, rest), Id.refines(s, n), recur(next, rest))

def run.refines(fuel: Nat) -> RRH(fuel):
  match fuel:
    case 0n:
      +s => +tape => rr.zero(N.request(s), s, tape)
    case 1n+(+f):
      +s => +tape => rr.succ(f, N.request(s), s, tape, run.refines(f))
