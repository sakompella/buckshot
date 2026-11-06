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

# The Idle moves: each simple move is a chain of moves sm offers.

def and.l(+a: Bool, +b: Bool, +e: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}:
      e
    case True{}:
      {==}

def and.r(+a: Bool, +b: Bool, +e: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}:
      Wk.absurd({b == True{} : Bool}, Wk.bool.clash(e))
    case True{}:
      e

def move.eq.sound(+a: D.Move, +b: D.Move, +e: {D.move.eq(a, b) == True{} : Bool}) -> {a == b : D.Move}:
  match a b:
    case D.PickUp{} D.PickUp{}:
      {==}
    case D.PickUp{} D.Shoot{+s2}:
      Wk.absurd({D.PickUp{} == D.Shoot{s2} : D.Move}, Wk.bool.clash(e))
    case D.PickUp{} D.UseItem{+s2, +i2}:
      Wk.absurd({D.PickUp{} == D.UseItem{s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.PickUp{} D.Grab{}:
      Wk.absurd({D.PickUp{} == D.Grab{} : D.Move}, Wk.bool.clash(e))
    case D.PickUp{} D.Place{+s2}:
      Wk.absurd({D.PickUp{} == D.Place{s2} : D.Move}, Wk.bool.clash(e))
    case D.PickUp{} D.JamTarget{+s2}:
      Wk.absurd({D.PickUp{} == D.JamTarget{s2} : D.Move}, Wk.bool.clash(e))
    case D.PickUp{} D.Steal{+o2, +s2, +i2}:
      Wk.absurd({D.PickUp{} == D.Steal{o2, s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.Shoot{+s1} D.PickUp{}:
      Wk.absurd({D.Shoot{s1} == D.PickUp{} : D.Move}, Wk.bool.clash(e))
    case D.Shoot{+s1} D.Shoot{+s2}:
      Equal.cong(D.Seat, D.Move, x => D.Shoot{x}, s1, s2, Wk.seat.eq.sound(s1, s2, e))
    case D.Shoot{+s1} D.UseItem{+s2, +i2}:
      Wk.absurd({D.Shoot{s1} == D.UseItem{s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.Shoot{+s1} D.Grab{}:
      Wk.absurd({D.Shoot{s1} == D.Grab{} : D.Move}, Wk.bool.clash(e))
    case D.Shoot{+s1} D.Place{+s2}:
      Wk.absurd({D.Shoot{s1} == D.Place{s2} : D.Move}, Wk.bool.clash(e))
    case D.Shoot{+s1} D.JamTarget{+s2}:
      Wk.absurd({D.Shoot{s1} == D.JamTarget{s2} : D.Move}, Wk.bool.clash(e))
    case D.Shoot{+s1} D.Steal{+o2, +s2, +i2}:
      Wk.absurd({D.Shoot{s1} == D.Steal{o2, s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.UseItem{+s1, +i1} D.PickUp{}:
      Wk.absurd({D.UseItem{s1, i1} == D.PickUp{} : D.Move}, Wk.bool.clash(e))
    case D.UseItem{+s1, +i1} D.Shoot{+s2}:
      Wk.absurd({D.UseItem{s1, i1} == D.Shoot{s2} : D.Move}, Wk.bool.clash(e))
    case D.UseItem{+s1, +i1} D.UseItem{+s2, +i2}:
      %Equal.sym(D.Slot, s1, s2, Wk.slot.eq.sound(s1, s2, and.l(D.slot.eq(s1, s2), D.item.eq(i1, i2), e))) : {D.UseItem{_, i1} == D.UseItem{s2, i2} : D.Move}
      Equal.cong(D.Item, D.Move, x => D.UseItem{s2, x}, i1, i2, Wk.item.eq.sound(i1, i2, and.r(D.slot.eq(s1, s2), D.item.eq(i1, i2), e)))
    case D.UseItem{+s1, +i1} D.Grab{}:
      Wk.absurd({D.UseItem{s1, i1} == D.Grab{} : D.Move}, Wk.bool.clash(e))
    case D.UseItem{+s1, +i1} D.Place{+s2}:
      Wk.absurd({D.UseItem{s1, i1} == D.Place{s2} : D.Move}, Wk.bool.clash(e))
    case D.UseItem{+s1, +i1} D.JamTarget{+s2}:
      Wk.absurd({D.UseItem{s1, i1} == D.JamTarget{s2} : D.Move}, Wk.bool.clash(e))
    case D.UseItem{+s1, +i1} D.Steal{+o2, +s2, +i2}:
      Wk.absurd({D.UseItem{s1, i1} == D.Steal{o2, s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.Grab{} D.PickUp{}:
      Wk.absurd({D.Grab{} == D.PickUp{} : D.Move}, Wk.bool.clash(e))
    case D.Grab{} D.Shoot{+s2}:
      Wk.absurd({D.Grab{} == D.Shoot{s2} : D.Move}, Wk.bool.clash(e))
    case D.Grab{} D.UseItem{+s2, +i2}:
      Wk.absurd({D.Grab{} == D.UseItem{s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.Grab{} D.Grab{}:
      {==}
    case D.Grab{} D.Place{+s2}:
      Wk.absurd({D.Grab{} == D.Place{s2} : D.Move}, Wk.bool.clash(e))
    case D.Grab{} D.JamTarget{+s2}:
      Wk.absurd({D.Grab{} == D.JamTarget{s2} : D.Move}, Wk.bool.clash(e))
    case D.Grab{} D.Steal{+o2, +s2, +i2}:
      Wk.absurd({D.Grab{} == D.Steal{o2, s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.Place{+s1} D.PickUp{}:
      Wk.absurd({D.Place{s1} == D.PickUp{} : D.Move}, Wk.bool.clash(e))
    case D.Place{+s1} D.Shoot{+s2}:
      Wk.absurd({D.Place{s1} == D.Shoot{s2} : D.Move}, Wk.bool.clash(e))
    case D.Place{+s1} D.UseItem{+s2, +i2}:
      Wk.absurd({D.Place{s1} == D.UseItem{s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.Place{+s1} D.Grab{}:
      Wk.absurd({D.Place{s1} == D.Grab{} : D.Move}, Wk.bool.clash(e))
    case D.Place{+s1} D.Place{+s2}:
      Equal.cong(D.Slot, D.Move, x => D.Place{x}, s1, s2, Wk.slot.eq.sound(s1, s2, e))
    case D.Place{+s1} D.JamTarget{+s2}:
      Wk.absurd({D.Place{s1} == D.JamTarget{s2} : D.Move}, Wk.bool.clash(e))
    case D.Place{+s1} D.Steal{+o2, +s2, +i2}:
      Wk.absurd({D.Place{s1} == D.Steal{o2, s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.JamTarget{+s1} D.PickUp{}:
      Wk.absurd({D.JamTarget{s1} == D.PickUp{} : D.Move}, Wk.bool.clash(e))
    case D.JamTarget{+s1} D.Shoot{+s2}:
      Wk.absurd({D.JamTarget{s1} == D.Shoot{s2} : D.Move}, Wk.bool.clash(e))
    case D.JamTarget{+s1} D.UseItem{+s2, +i2}:
      Wk.absurd({D.JamTarget{s1} == D.UseItem{s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.JamTarget{+s1} D.Grab{}:
      Wk.absurd({D.JamTarget{s1} == D.Grab{} : D.Move}, Wk.bool.clash(e))
    case D.JamTarget{+s1} D.Place{+s2}:
      Wk.absurd({D.JamTarget{s1} == D.Place{s2} : D.Move}, Wk.bool.clash(e))
    case D.JamTarget{+s1} D.JamTarget{+s2}:
      Equal.cong(D.Seat, D.Move, x => D.JamTarget{x}, s1, s2, Wk.seat.eq.sound(s1, s2, e))
    case D.JamTarget{+s1} D.Steal{+o2, +s2, +i2}:
      Wk.absurd({D.JamTarget{s1} == D.Steal{o2, s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.Steal{+o1, +s1, +i1} D.PickUp{}:
      Wk.absurd({D.Steal{o1, s1, i1} == D.PickUp{} : D.Move}, Wk.bool.clash(e))
    case D.Steal{+o1, +s1, +i1} D.Shoot{+s2}:
      Wk.absurd({D.Steal{o1, s1, i1} == D.Shoot{s2} : D.Move}, Wk.bool.clash(e))
    case D.Steal{+o1, +s1, +i1} D.UseItem{+s2, +i2}:
      Wk.absurd({D.Steal{o1, s1, i1} == D.UseItem{s2, i2} : D.Move}, Wk.bool.clash(e))
    case D.Steal{+o1, +s1, +i1} D.Grab{}:
      Wk.absurd({D.Steal{o1, s1, i1} == D.Grab{} : D.Move}, Wk.bool.clash(e))
    case D.Steal{+o1, +s1, +i1} D.Place{+s2}:
      Wk.absurd({D.Steal{o1, s1, i1} == D.Place{s2} : D.Move}, Wk.bool.clash(e))
    case D.Steal{+o1, +s1, +i1} D.JamTarget{+s2}:
      Wk.absurd({D.Steal{o1, s1, i1} == D.JamTarget{s2} : D.Move}, Wk.bool.clash(e))
    case D.Steal{+o1, +s1, +i1} D.Steal{+o2, +s2, +i2}:
      %Equal.sym(D.Seat, o1, o2, Wk.seat.eq.sound(o1, o2, and.l(D.seat.eq(o1, o2), Bool.and(D.slot.eq(s1, s2), D.item.eq(i1, i2)), e))) : {D.Steal{_, s1, i1} == D.Steal{o2, s2, i2} : D.Move}
      %Equal.sym(D.Slot, s1, s2, Wk.slot.eq.sound(s1, s2, and.l(D.slot.eq(s1, s2), D.item.eq(i1, i2), and.r(D.seat.eq(o1, o2), Bool.and(D.slot.eq(s1, s2), D.item.eq(i1, i2)), e)))) : {D.Steal{o2, _, i1} == D.Steal{o2, s2, i2} : D.Move}
      Equal.cong(D.Item, D.Move, x => D.Steal{o2, s2, x}, i1, i2, Wk.item.eq.sound(i1, i2, and.r(D.slot.eq(s1, s2), D.item.eq(i1, i2), and.r(D.seat.eq(o1, o2), Bool.and(D.slot.eq(s1, s2), D.item.eq(i1, i2)), e))))

def move.eq.refl(+a: D.Move) -> {D.move.eq(a, a) == True{} : Bool}:
  match a:
    case D.PickUp{}:
      {==}
    case D.Shoot{+s}:
      Wk.seat.eq.refl(s)
    case D.UseItem{+s, +i}:
      %Equal.sym(Bool, D.slot.eq(s, s), True{}, Wk.slot.eq.refl(s)) : {Bool.and(_, D.item.eq(i, i)) == True{} : Bool}
      Wk.item.eq.refl(i)
    case D.Grab{}:
      {==}
    case D.Place{+s}:
      Wk.slot.eq.refl(s)
    case D.JamTarget{+s}:
      Wk.seat.eq.refl(s)
    case D.Steal{+o, +s, +i}:
      %Equal.sym(Bool, D.seat.eq(o, o), True{}, Wk.seat.eq.refl(o)) : {Bool.and(_, Bool.and(D.slot.eq(s, s), D.item.eq(i, i))) == True{} : Bool}
      %Equal.sym(Bool, D.slot.eq(s, s), True{}, Wk.slot.eq.refl(s)) : {Bool.and(_, D.item.eq(i, i)) == True{} : Bool}
      Wk.item.eq.refl(i)

def FindAt(+ms: List<&2, D.Move>, +m: D.Move, +mv: D.Move, +k: Nat) -> Data:
  Sigma<&2, &2, {D.clamp(k, List.length(&2, D.Move, ms)) == k : Nat}, _ => {Wk.menu.at(k, ms, m) == mv : D.Move}>

def find.succ(+ms2: List<&2, D.Move>, +m2: D.Move, +m: D.Move, +mv: D.Move, +j: Nat, ih: FindAt(ms2, m2, mv, j)) -> FindAt(m2 <> ms2, m, mv, 1n+j):
  match ih:
    case Tuple{+ec, +ea}:
      (Equal.cong(Nat, Nat, x => 1n+x, D.clamp(j, List.length(&2, D.Move, ms2)), j, ec), ea)

def find.go(ms: List<&2, D.Move>, +m: D.Move, +mv: D.Move, +k: Nat, b: Bool, +eb: {D.move.eq(m, mv) == b : Bool}, r: Maybe<&2, Nat>, +er: {D.menu.find(ms, mv) == r : Maybe<&2, Nat>}, +found: {D.menu.find.here(b, r) == Some{k} : Maybe<&2, Nat>}) -> FindAt(ms, m, mv, k):
  match ms b r:
    case Nil{} True{} r:
      %Wk.some.inj(Nat, 0n, k, found) : FindAt(Nil{}, m, mv, _)
      ({==}, move.eq.sound(m, mv, eb))
    case +m2 <> +ms2 True{} r:
      %Wk.some.inj(Nat, 0n, k, found) : FindAt(m2 <> ms2, m, mv, _)
      ({==}, move.eq.sound(m, mv, eb))
    case Nil{} False{} None{}:
      Wk.absurd(FindAt(Nil{}, m, mv, k), Wk.maybe.clash(Nat, k, found))
    case Nil{} False{} Some{j}:
      Wk.absurd(FindAt(Nil{}, m, mv, k), Wk.maybe.clash(Nat, j, er))
    case m2 <> ms2 False{} None{}:
      Wk.absurd(FindAt(m2 <> ms2, m, mv, k), Wk.maybe.clash(Nat, k, found))
    case +m2 <> +ms2 False{} Some{+j}:
      %Wk.some.inj(Nat, 1n+j, k, found) : FindAt(m2 <> ms2, m, mv, _)
      find.succ(ms2, m2, m, mv, j, find.go(ms2, m2, mv, j, D.move.eq(m2, mv), {==}, D.menu.find(ms2, mv), {==}, er))

def find.at(+m: D.Move, +ms: List<&2, D.Move>, +mv: D.Move, +k: Nat, +found: {D.menu.find(m <> ms, mv) == Some{k} : Maybe<&2, Nat>}) -> FindAt(ms, m, mv, k):
  find.go(ms, m, mv, k, D.move.eq(m, mv), {==}, D.menu.find(ms, mv), {==}, found)

def Seated(+table: D.Table, +seat: D.Seat) -> Data:
  {P.seated(D.ring.get(Bool, D.ring.fill(Bool, table, True{}), seat)) == True{} : Bool}

def seat.menu.get(table: D.Table, seat: D.Seat, +ms: List<&2, D.Move>, seated: Seated(table, seat)) -> {D.ring.get(List<&2, D.Move>, D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, ms), seat) == Some{ms} : Maybe<&2, List<&2, D.Move>>}:
  match table seat:
    case D.TwoSeats{} D.Seat0{}:
      Wk.absurd({D.ring.get(List<&2, D.Move>, D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, D.TwoSeats{}, Nil{}), D.Seat0{}, ms), D.Seat0{}) == Some{ms} : Maybe<&2, List<&2, D.Move>>}, Wk.bool.clash(seated))
    case D.TwoSeats{} D.Seat1{}:
      {==}
    case D.TwoSeats{} D.Seat2{}:
      Wk.absurd({D.ring.get(List<&2, D.Move>, D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, D.TwoSeats{}, Nil{}), D.Seat2{}, ms), D.Seat2{}) == Some{ms} : Maybe<&2, List<&2, D.Move>>}, Wk.bool.clash(seated))
    case D.TwoSeats{} D.Seat3{}:
      {==}
    case D.ThreeSeats{} D.Seat0{}:
      {==}
    case D.ThreeSeats{} D.Seat1{}:
      {==}
    case D.ThreeSeats{} D.Seat2{}:
      {==}
    case D.ThreeSeats{} D.Seat3{}:
      Wk.absurd({D.ring.get(List<&2, D.Move>, D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, D.ThreeSeats{}, Nil{}), D.Seat3{}, ms), D.Seat3{}) == Some{ms} : Maybe<&2, List<&2, D.Move>>}, Wk.bool.clash(seated))
    case D.FourSeats{} D.Seat0{}:
      {==}
    case D.FourSeats{} D.Seat1{}:
      {==}
    case D.FourSeats{} D.Seat2{}:
      {==}
    case D.FourSeats{} D.Seat3{}:
      {==}

# A seat's move at index k of its menu: the tape answer, and the choice sm
# resolves it to.
def MenuStep(+table: D.Table, +seat: D.Seat, +moves: List<&2, D.Move>, +mv: D.Move, +k: Nat) -> Data:
  Sigma<&2, &2, Nat, n => Sigma<&2, &2, {SA.walk.legal(G.seat.menu(table, seat, moves), SA.ChoiceStep{seat, mv}) == Some{n} : Maybe<&2, Nat>}, _ => {D.resolve(G.seat.menu(table, seat, moves), n) == D.Chose{D.Choice{seat, k, mv}} : D.Resolved}>>

def step.fix(+table: D.Table, +seat: D.Seat, +m: D.Move, +ms: List<&2, D.Move>, +mv: D.Move, +k: Nat, at: FindAt(ms, m, mv, k), walked: Wk.Walked(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, m <> ms), seat, mv, m, ms, k)) -> MenuStep(table, seat, m <> ms, mv, k):
  match at walked:
    case Tuple{+ec, +ea} Tuple{+n, Tuple{+legal, +res}}:
      +c : Nat = D.clamp(k, List.length(&2, D.Move, ms))
      +e1 : {D.Chose{D.Choice{seat, Nat.add(c, 0n), Wk.menu.at(c, ms, m)}} == D.Chose{D.Choice{seat, Nat.add(k, 0n), Wk.menu.at(k, ms, m)}} : D.Resolved} = Equal.cong(Nat, D.Resolved, x => D.Chose{D.Choice{seat, Nat.add(x, 0n), Wk.menu.at(x, ms, m)}}, c, k, ec)
      +e2 : {D.Chose{D.Choice{seat, Nat.add(k, 0n), Wk.menu.at(k, ms, m)}} == D.Chose{D.Choice{seat, k, Wk.menu.at(k, ms, m)}} : D.Resolved} = Equal.cong(Nat, D.Resolved, x => D.Chose{D.Choice{seat, x, Wk.menu.at(k, ms, m)}}, Nat.add(k, 0n), k, Wk.add_zero(k))
      +e3 : {D.Chose{D.Choice{seat, k, Wk.menu.at(k, ms, m)}} == D.Chose{D.Choice{seat, k, mv}} : D.Resolved} = Equal.cong(D.Move, D.Resolved, x => D.Chose{D.Choice{seat, k, x}}, Wk.menu.at(k, ms, m), mv, ea)
      +req : D.Request = G.seat.menu(table, seat, m <> ms)
      (n, (legal, Equal.trans(D.Resolved, D.resolve(req, n), D.Chose{D.Choice{seat, Nat.add(c, 0n), Wk.menu.at(c, ms, m)}}, D.Chose{D.Choice{seat, k, mv}}, res, Equal.trans(D.Resolved, D.Chose{D.Choice{seat, Nat.add(c, 0n), Wk.menu.at(c, ms, m)}}, D.Chose{D.Choice{seat, Nat.add(k, 0n), Wk.menu.at(k, ms, m)}}, D.Chose{D.Choice{seat, k, mv}}, e1, Equal.trans(D.Resolved, D.Chose{D.Choice{seat, Nat.add(k, 0n), Wk.menu.at(k, ms, m)}}, D.Chose{D.Choice{seat, k, Wk.menu.at(k, ms, m)}}, D.Chose{D.Choice{seat, k, mv}}, e2, e3)))))

def menu.step(+table: D.Table, +seat: D.Seat, moves: List<&2, D.Move>, +mv: D.Move, +k: Nat, +seated: Seated(table, seat), +found: {D.menu.find(moves, mv) == Some{k} : Maybe<&2, Nat>}) -> MenuStep(table, seat, moves, mv, k):
  match moves:
    case Nil{}:
      Wk.absurd(MenuStep(table, seat, Nil{}, mv, k), Wk.maybe.clash(Nat, k, found))
    case +m <> +ms:
      +ring : D.Ring<&2, List<&2, D.Move>> = D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, m <> ms)
      step.fix(table, seat, m, ms, mv, k, find.at(m, ms, mv, k, found), Wk.choose.walk(ring, seat, mv, m, ms, k, seat.menu.get(table, seat, m <> ms, seated), found))

def In(-A: Data, +x: A, xs: List<&2, A>) -> Data:
  match xs:
    case Nil{}:
      Empty
    case y <> ys:
      Either<&2, &2, {x == y : A}, In(A, x, ys)>

def tgt.mv(x: S.TargetOption) -> D.Move:
  match x:
    case S.Target{s}:
      D.Shoot{s}

def tgt.un(m: D.Move) -> S.TargetOption:
  match m:
    case D.Shoot{s}:
      S.Target{s}
    case _:
      S.Target{D.Seat0{}}

def tgt.back(+x: S.TargetOption) -> {tgt.un(tgt.mv(x)) == x : S.TargetOption}:
  match x:
    case S.Target{s}:
      {==}

def tgt.inj(+y: S.TargetOption, +x: S.TargetOption, +e: {tgt.mv(y) == tgt.mv(x) : D.Move}) -> {y == x : S.TargetOption}:
  Equal.trans(S.TargetOption, y, tgt.un(tgt.mv(x)), x, Equal.trans(S.TargetOption, y, tgt.un(tgt.mv(y)), tgt.un(tgt.mv(x)), Equal.sym(S.TargetOption, tgt.un(tgt.mv(y)), y, tgt.back(y)), Equal.cong(D.Move, S.TargetOption, tgt.un, tgt.mv(y), tgt.mv(x), e)), tgt.back(x))

def tgt.moves.cons(+y: S.TargetOption, +ys: List<&2, S.TargetOption>) -> {G.aim.moves(y <> ys) == tgt.mv(y) <> G.aim.moves(ys) : List<&2, D.Move>}:
  match y:
    case S.Target{s}:
      {==}

def tgt.R(+xs: List<&2, S.TargetOption>, +x: S.TargetOption) -> Data:
  Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(G.aim.moves(xs), tgt.mv(x)) == Some{k} : Maybe<&2, Nat>}, e0 => {G.target.nth(xs, k) == Some{x} : Maybe<&2, S.TargetOption>}>>

def tgt.hit(+y: S.TargetOption, +ys: List<&2, S.TargetOption>, +x: S.TargetOption, +eb: {D.move.eq(tgt.mv(y), tgt.mv(x)) == True{} : Bool}) -> tgt.R(y <> ys, x):
  %Equal.sym(List<&2, D.Move>, G.aim.moves(y <> ys), tgt.mv(y) <> G.aim.moves(ys), tgt.moves.cons(y, ys)) : Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(_, tgt.mv(x)) == Some{k} : Maybe<&2, Nat>}, e0 => {G.target.nth(y <> ys, k) == Some{x} : Maybe<&2, S.TargetOption>}>>
  %Equal.sym(Bool, D.move.eq(tgt.mv(y), tgt.mv(x)), True{}, eb) : Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find.here(_, D.menu.find(G.aim.moves(ys), tgt.mv(x))) == Some{k} : Maybe<&2, Nat>}, e0 => {G.target.nth(y <> ys, k) == Some{x} : Maybe<&2, S.TargetOption>}>>
  (0n, ({==}, Equal.cong(S.TargetOption, Maybe<&2, S.TargetOption>, v => Some{v}, y, x, tgt.inj(y, x, move.eq.sound(tgt.mv(y), tgt.mv(x), eb)))))

def tgt.cons(+y: S.TargetOption, +ys: List<&2, S.TargetOption>, +x: S.TargetOption, b: Bool, +eb: {D.move.eq(tgt.mv(y), tgt.mv(x)) == b : Bool}, ih: tgt.R(ys, x)) -> tgt.R(y <> ys, x):
  match b ih:
    case True{} _:
      tgt.hit(y, ys, x, eb)
    case False{} Tuple{+k, Tuple{+e1, +e2}}:
      %Equal.sym(List<&2, D.Move>, G.aim.moves(y <> ys), tgt.mv(y) <> G.aim.moves(ys), tgt.moves.cons(y, ys)) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find(_, tgt.mv(x)) == Some{j} : Maybe<&2, Nat>}, e0 => {G.target.nth(y <> ys, j) == Some{x} : Maybe<&2, S.TargetOption>}>>
      %Equal.sym(Bool, D.move.eq(tgt.mv(y), tgt.mv(x)), False{}, eb) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find.here(_, D.menu.find(G.aim.moves(ys), tgt.mv(x))) == Some{j} : Maybe<&2, Nat>}, e0 => {G.target.nth(y <> ys, j) == Some{x} : Maybe<&2, S.TargetOption>}>>
      %Equal.sym(Maybe<&2, Nat>, D.menu.find(G.aim.moves(ys), tgt.mv(x)), Some{k}, e1) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find.here(False{}, _) == Some{j} : Maybe<&2, Nat>}, e0 => {G.target.nth(y <> ys, j) == Some{x} : Maybe<&2, S.TargetOption>}>>
      (1n+k, ({==}, e2))

def tgt.head(+y: S.TargetOption, +ys: List<&2, S.TargetOption>, +x: S.TargetOption, +e: {x == y : S.TargetOption}) -> tgt.R(y <> ys, x):
  %Equal.sym(S.TargetOption, x, y, e) : tgt.R(y <> ys, _)
  tgt.hit(y, ys, y, move.eq.refl(tgt.mv(y)))

def tgt.find(xs: List<&2, S.TargetOption>, +x: S.TargetOption, mem: In(S.TargetOption, x, xs)) -> tgt.R(xs, x):
  match xs mem:
    case Nil{} _:
      match mem:
    case +y <> +ys Inl{+e}:
      tgt.head(y, ys, x, e)
    case +y <> +ys Inr{+rest}:
      tgt.cons(y, ys, x, D.move.eq(tgt.mv(y), tgt.mv(x)), {==}, tgt.find(ys, x, rest))

def opt.mv(x: S.IdleOption) -> D.Move:
  match x:
    case S.TakeGun{}:
      D.PickUp{}
    case S.UseAt{slot, item}:
      D.UseItem{slot, item}

def opt.un(m: D.Move) -> S.IdleOption:
  match m:
    case D.PickUp{}:
      S.TakeGun{}
    case D.UseItem{slot, item}:
      S.UseAt{slot, item}
    case _:
      S.TakeGun{}

def opt.back(+x: S.IdleOption) -> {opt.un(opt.mv(x)) == x : S.IdleOption}:
  match x:
    case S.TakeGun{}:
      {==}
    case S.UseAt{slot, item}:
      {==}

def opt.inj(+y: S.IdleOption, +x: S.IdleOption, +e: {opt.mv(y) == opt.mv(x) : D.Move}) -> {y == x : S.IdleOption}:
  Equal.trans(S.IdleOption, y, opt.un(opt.mv(x)), x, Equal.trans(S.IdleOption, y, opt.un(opt.mv(y)), opt.un(opt.mv(x)), Equal.sym(S.IdleOption, opt.un(opt.mv(y)), y, opt.back(y)), Equal.cong(D.Move, S.IdleOption, opt.un, opt.mv(y), opt.mv(x), e)), opt.back(x))

def opt.moves.cons(+y: S.IdleOption, +ys: List<&2, S.IdleOption>) -> {G.idle.moves(y <> ys) == opt.mv(y) <> G.idle.moves(ys) : List<&2, D.Move>}:
  match y:
    case S.TakeGun{}:
      {==}
    case S.UseAt{slot, item}:
      {==}

def opt.R(+xs: List<&2, S.IdleOption>, +x: S.IdleOption) -> Data:
  Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(G.idle.moves(xs), opt.mv(x)) == Some{k} : Maybe<&2, Nat>}, e0 => {G.idle.nth(xs, k) == Some{x} : Maybe<&2, S.IdleOption>}>>

def opt.hit(+y: S.IdleOption, +ys: List<&2, S.IdleOption>, +x: S.IdleOption, +eb: {D.move.eq(opt.mv(y), opt.mv(x)) == True{} : Bool}) -> opt.R(y <> ys, x):
  %Equal.sym(List<&2, D.Move>, G.idle.moves(y <> ys), opt.mv(y) <> G.idle.moves(ys), opt.moves.cons(y, ys)) : Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(_, opt.mv(x)) == Some{k} : Maybe<&2, Nat>}, e0 => {G.idle.nth(y <> ys, k) == Some{x} : Maybe<&2, S.IdleOption>}>>
  %Equal.sym(Bool, D.move.eq(opt.mv(y), opt.mv(x)), True{}, eb) : Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find.here(_, D.menu.find(G.idle.moves(ys), opt.mv(x))) == Some{k} : Maybe<&2, Nat>}, e0 => {G.idle.nth(y <> ys, k) == Some{x} : Maybe<&2, S.IdleOption>}>>
  (0n, ({==}, Equal.cong(S.IdleOption, Maybe<&2, S.IdleOption>, v => Some{v}, y, x, opt.inj(y, x, move.eq.sound(opt.mv(y), opt.mv(x), eb)))))

def opt.cons(+y: S.IdleOption, +ys: List<&2, S.IdleOption>, +x: S.IdleOption, b: Bool, +eb: {D.move.eq(opt.mv(y), opt.mv(x)) == b : Bool}, ih: opt.R(ys, x)) -> opt.R(y <> ys, x):
  match b ih:
    case True{} _:
      opt.hit(y, ys, x, eb)
    case False{} Tuple{+k, Tuple{+e1, +e2}}:
      %Equal.sym(List<&2, D.Move>, G.idle.moves(y <> ys), opt.mv(y) <> G.idle.moves(ys), opt.moves.cons(y, ys)) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find(_, opt.mv(x)) == Some{j} : Maybe<&2, Nat>}, e0 => {G.idle.nth(y <> ys, j) == Some{x} : Maybe<&2, S.IdleOption>}>>
      %Equal.sym(Bool, D.move.eq(opt.mv(y), opt.mv(x)), False{}, eb) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find.here(_, D.menu.find(G.idle.moves(ys), opt.mv(x))) == Some{j} : Maybe<&2, Nat>}, e0 => {G.idle.nth(y <> ys, j) == Some{x} : Maybe<&2, S.IdleOption>}>>
      %Equal.sym(Maybe<&2, Nat>, D.menu.find(G.idle.moves(ys), opt.mv(x)), Some{k}, e1) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find.here(False{}, _) == Some{j} : Maybe<&2, Nat>}, e0 => {G.idle.nth(y <> ys, j) == Some{x} : Maybe<&2, S.IdleOption>}>>
      (1n+k, ({==}, e2))

def opt.head(+y: S.IdleOption, +ys: List<&2, S.IdleOption>, +x: S.IdleOption, +e: {x == y : S.IdleOption}) -> opt.R(y <> ys, x):
  %Equal.sym(S.IdleOption, x, y, e) : opt.R(y <> ys, _)
  opt.hit(y, ys, y, move.eq.refl(opt.mv(y)))

def opt.find(xs: List<&2, S.IdleOption>, +x: S.IdleOption, mem: In(S.IdleOption, x, xs)) -> opt.R(xs, x):
  match xs mem:
    case Nil{} _:
      match mem:
    case +y <> +ys Inl{+e}:
      opt.head(y, ys, x, e)
    case +y <> +ys Inr{+rest}:
      opt.cons(y, ys, x, D.move.eq(opt.mv(y), opt.mv(x)), {==}, opt.find(ys, x, rest))

def jmo.mv(x: S.JamOption) -> D.Move:
  match x:
    case S.JamAt{s}:
      D.JamTarget{s}

def jmo.un(m: D.Move) -> S.JamOption:
  match m:
    case D.JamTarget{s}:
      S.JamAt{s}
    case _:
      S.JamAt{D.Seat0{}}

def jmo.back(+x: S.JamOption) -> {jmo.un(jmo.mv(x)) == x : S.JamOption}:
  match x:
    case S.JamAt{s}:
      {==}

def jmo.inj(+y: S.JamOption, +x: S.JamOption, +e: {jmo.mv(y) == jmo.mv(x) : D.Move}) -> {y == x : S.JamOption}:
  Equal.trans(S.JamOption, y, jmo.un(jmo.mv(x)), x, Equal.trans(S.JamOption, y, jmo.un(jmo.mv(y)), jmo.un(jmo.mv(x)), Equal.sym(S.JamOption, jmo.un(jmo.mv(y)), y, jmo.back(y)), Equal.cong(D.Move, S.JamOption, jmo.un, jmo.mv(y), jmo.mv(x), e)), jmo.back(x))

def jmo.moves.cons(+y: S.JamOption, +ys: List<&2, S.JamOption>) -> {I.jam.moves(y <> ys) == jmo.mv(y) <> I.jam.moves(ys) : List<&2, D.Move>}:
  match y:
    case S.JamAt{s}:
      {==}

def jmo.R(+xs: List<&2, S.JamOption>, +x: S.JamOption) -> Data:
  Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(I.jam.moves(xs), jmo.mv(x)) == Some{k} : Maybe<&2, Nat>}, e0 => {I.jam.nth(xs, k) == Some{x} : Maybe<&2, S.JamOption>}>>

def jmo.hit(+y: S.JamOption, +ys: List<&2, S.JamOption>, +x: S.JamOption, +eb: {D.move.eq(jmo.mv(y), jmo.mv(x)) == True{} : Bool}) -> jmo.R(y <> ys, x):
  %Equal.sym(List<&2, D.Move>, I.jam.moves(y <> ys), jmo.mv(y) <> I.jam.moves(ys), jmo.moves.cons(y, ys)) : Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(_, jmo.mv(x)) == Some{k} : Maybe<&2, Nat>}, e0 => {I.jam.nth(y <> ys, k) == Some{x} : Maybe<&2, S.JamOption>}>>
  %Equal.sym(Bool, D.move.eq(jmo.mv(y), jmo.mv(x)), True{}, eb) : Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find.here(_, D.menu.find(I.jam.moves(ys), jmo.mv(x))) == Some{k} : Maybe<&2, Nat>}, e0 => {I.jam.nth(y <> ys, k) == Some{x} : Maybe<&2, S.JamOption>}>>
  (0n, ({==}, Equal.cong(S.JamOption, Maybe<&2, S.JamOption>, v => Some{v}, y, x, jmo.inj(y, x, move.eq.sound(jmo.mv(y), jmo.mv(x), eb)))))

def jmo.cons(+y: S.JamOption, +ys: List<&2, S.JamOption>, +x: S.JamOption, b: Bool, +eb: {D.move.eq(jmo.mv(y), jmo.mv(x)) == b : Bool}, ih: jmo.R(ys, x)) -> jmo.R(y <> ys, x):
  match b ih:
    case True{} _:
      jmo.hit(y, ys, x, eb)
    case False{} Tuple{+k, Tuple{+e1, +e2}}:
      %Equal.sym(List<&2, D.Move>, I.jam.moves(y <> ys), jmo.mv(y) <> I.jam.moves(ys), jmo.moves.cons(y, ys)) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find(_, jmo.mv(x)) == Some{j} : Maybe<&2, Nat>}, e0 => {I.jam.nth(y <> ys, j) == Some{x} : Maybe<&2, S.JamOption>}>>
      %Equal.sym(Bool, D.move.eq(jmo.mv(y), jmo.mv(x)), False{}, eb) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find.here(_, D.menu.find(I.jam.moves(ys), jmo.mv(x))) == Some{j} : Maybe<&2, Nat>}, e0 => {I.jam.nth(y <> ys, j) == Some{x} : Maybe<&2, S.JamOption>}>>
      %Equal.sym(Maybe<&2, Nat>, D.menu.find(I.jam.moves(ys), jmo.mv(x)), Some{k}, e1) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find.here(False{}, _) == Some{j} : Maybe<&2, Nat>}, e0 => {I.jam.nth(y <> ys, j) == Some{x} : Maybe<&2, S.JamOption>}>>
      (1n+k, ({==}, e2))

def jmo.head(+y: S.JamOption, +ys: List<&2, S.JamOption>, +x: S.JamOption, +e: {x == y : S.JamOption}) -> jmo.R(y <> ys, x):
  %Equal.sym(S.JamOption, x, y, e) : jmo.R(y <> ys, _)
  jmo.hit(y, ys, y, move.eq.refl(jmo.mv(y)))

def jmo.find(xs: List<&2, S.JamOption>, +x: S.JamOption, mem: In(S.JamOption, x, xs)) -> jmo.R(xs, x):
  match xs mem:
    case Nil{} _:
      match mem:
    case +y <> +ys Inl{+e}:
      jmo.head(y, ys, x, e)
    case +y <> +ys Inr{+rest}:
      jmo.cons(y, ys, x, D.move.eq(jmo.mv(y), jmo.mv(x)), {==}, jmo.find(ys, x, rest))

def stl.mv(x: S.StealOption) -> D.Move:
  match x:
    case S.Pick{owner, slot, item}:
      D.Steal{owner, slot, item}

def stl.un(m: D.Move) -> S.StealOption:
  match m:
    case D.Steal{owner, slot, item}:
      S.Pick{owner, slot, item}
    case _:
      S.Pick{D.Seat0{}, D.Slot0{}, D.Saw{}}

def stl.back(+x: S.StealOption) -> {stl.un(stl.mv(x)) == x : S.StealOption}:
  match x:
    case S.Pick{owner, slot, item}:
      {==}

def stl.inj(+y: S.StealOption, +x: S.StealOption, +e: {stl.mv(y) == stl.mv(x) : D.Move}) -> {y == x : S.StealOption}:
  Equal.trans(S.StealOption, y, stl.un(stl.mv(x)), x, Equal.trans(S.StealOption, y, stl.un(stl.mv(y)), stl.un(stl.mv(x)), Equal.sym(S.StealOption, stl.un(stl.mv(y)), y, stl.back(y)), Equal.cong(D.Move, S.StealOption, stl.un, stl.mv(y), stl.mv(x), e)), stl.back(x))

def stl.moves.cons(+y: S.StealOption, +ys: List<&2, S.StealOption>) -> {I.steal.moves(y <> ys) == stl.mv(y) <> I.steal.moves(ys) : List<&2, D.Move>}:
  match y:
    case S.Pick{owner, slot, item}:
      {==}

def stl.R(+xs: List<&2, S.StealOption>, +x: S.StealOption) -> Data:
  Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(I.steal.moves(xs), stl.mv(x)) == Some{k} : Maybe<&2, Nat>}, e0 => {I.steal.nth(xs, k) == Some{x} : Maybe<&2, S.StealOption>}>>

def stl.hit(+y: S.StealOption, +ys: List<&2, S.StealOption>, +x: S.StealOption, +eb: {D.move.eq(stl.mv(y), stl.mv(x)) == True{} : Bool}) -> stl.R(y <> ys, x):
  %Equal.sym(List<&2, D.Move>, I.steal.moves(y <> ys), stl.mv(y) <> I.steal.moves(ys), stl.moves.cons(y, ys)) : Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(_, stl.mv(x)) == Some{k} : Maybe<&2, Nat>}, e0 => {I.steal.nth(y <> ys, k) == Some{x} : Maybe<&2, S.StealOption>}>>
  %Equal.sym(Bool, D.move.eq(stl.mv(y), stl.mv(x)), True{}, eb) : Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find.here(_, D.menu.find(I.steal.moves(ys), stl.mv(x))) == Some{k} : Maybe<&2, Nat>}, e0 => {I.steal.nth(y <> ys, k) == Some{x} : Maybe<&2, S.StealOption>}>>
  (0n, ({==}, Equal.cong(S.StealOption, Maybe<&2, S.StealOption>, v => Some{v}, y, x, stl.inj(y, x, move.eq.sound(stl.mv(y), stl.mv(x), eb)))))

def stl.cons(+y: S.StealOption, +ys: List<&2, S.StealOption>, +x: S.StealOption, b: Bool, +eb: {D.move.eq(stl.mv(y), stl.mv(x)) == b : Bool}, ih: stl.R(ys, x)) -> stl.R(y <> ys, x):
  match b ih:
    case True{} _:
      stl.hit(y, ys, x, eb)
    case False{} Tuple{+k, Tuple{+e1, +e2}}:
      %Equal.sym(List<&2, D.Move>, I.steal.moves(y <> ys), stl.mv(y) <> I.steal.moves(ys), stl.moves.cons(y, ys)) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find(_, stl.mv(x)) == Some{j} : Maybe<&2, Nat>}, e0 => {I.steal.nth(y <> ys, j) == Some{x} : Maybe<&2, S.StealOption>}>>
      %Equal.sym(Bool, D.move.eq(stl.mv(y), stl.mv(x)), False{}, eb) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find.here(_, D.menu.find(I.steal.moves(ys), stl.mv(x))) == Some{j} : Maybe<&2, Nat>}, e0 => {I.steal.nth(y <> ys, j) == Some{x} : Maybe<&2, S.StealOption>}>>
      %Equal.sym(Maybe<&2, Nat>, D.menu.find(I.steal.moves(ys), stl.mv(x)), Some{k}, e1) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, {D.menu.find.here(False{}, _) == Some{j} : Maybe<&2, Nat>}, e0 => {I.steal.nth(y <> ys, j) == Some{x} : Maybe<&2, S.StealOption>}>>
      (1n+k, ({==}, e2))

def stl.head(+y: S.StealOption, +ys: List<&2, S.StealOption>, +x: S.StealOption, +e: {x == y : S.StealOption}) -> stl.R(y <> ys, x):
  %Equal.sym(S.StealOption, x, y, e) : stl.R(y <> ys, _)
  stl.hit(y, ys, y, move.eq.refl(stl.mv(y)))

def stl.find(xs: List<&2, S.StealOption>, +x: S.StealOption, mem: In(S.StealOption, x, xs)) -> stl.R(xs, x):
  match xs mem:
    case Nil{} _:
      match mem:
    case +y <> +ys Inl{+e}:
      stl.head(y, ys, x, e)
    case +y <> +ys Inr{+rest}:
      stl.cons(y, ys, x, D.move.eq(stl.mv(y), stl.mv(x)), {==}, stl.find(ys, x, rest))

def Sub(-A: Data, xs: List<&2, A>, +full: List<&2, A>) -> Data:
  match xs:
    case Nil{}:
      Unit
    case y <> ys:
      Sigma<&2, &2, In(A, y, full), e0 => Sub(A, ys, full)>

def sub.weaken(-A: Data, xs: List<&2, A>, +full: List<&2, A>, +y: A, sub: Sub(A, xs, full)) -> Sub(A, xs, y <> full):
  match xs sub:
    case Nil{} _:
      Unit{}
    case x <> rest Tuple{m, more}:
      (Inr{m}, sub.weaken(A, rest, full, y, more))

def sub.refl(-A: Data, +xs: List<&2, A>) -> Sub(A, xs, xs):
  match xs:
    case Nil{}:
      Unit{}
    case +y <> +ys:
      (Inl{{==}}, sub.weaken(A, ys, ys, y, sub.refl(A, ys)))

# What a simple Idle option needs of sm's menus: tg the aim targets, us the
# Idle options, js the jam targets and ks the steal picks.
def Legal(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, option: T.IdleOption) -> Data:
  match option:
    case T.ShootAt{t}:
      In(S.TargetOption, S.Target{t}, tg)
    case T.UseSlot{slot, item}:
      Sigma<&2, &2, In(S.IdleOption, S.UseAt{slot, item}, us), e0 => C.Plain(item)>
    case T.JamWith{slot, t}:
      Sigma<&2, &2, In(S.IdleOption, S.UseAt{slot, D.Jammer{}}, us), e0 => In(S.JamOption, S.JamAt{t}, js)>
    case T.StealWith{adr, owner, slot, item}:
      Sigma<&2, &2, In(S.IdleOption, S.UseAt{adr, D.Adrenaline{}}, us), e0 => Sigma<&2, &2, In(S.StealOption, S.Pick{owner, slot, item}, ks), e1 => C.Plain(item)>>
    case T.StealJamWith{adr, owner, slot, t}:
      Sigma<&2, &2, In(S.IdleOption, S.UseAt{adr, D.Adrenaline{}}, us), e0 => Sigma<&2, &2, In(S.StealOption, S.Pick{owner, slot, D.Jammer{}}, ks), e1 => In(S.JamOption, S.JamAt{t}, js)>>

def All(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, xs: List<&2, T.IdleOption>) -> Data:
  match xs:
    case Nil{}:
      Unit
    case x <> rest:
      Sigma<&2, &2, Legal(tg, us, js, ks, x), e0 => All(tg, us, js, ks, rest)>

def all.append(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +xs: List<&2, T.IdleOption>, +ys: List<&2, T.IdleOption>, ax: All(tg, us, js, ks, xs), ay: All(tg, us, js, ks, ys)) -> All(tg, us, js, ks, List.append(&2, T.IdleOption, xs, ys)):
  match xs ax:
    case Nil{} _:
      ay
    case +x <> +rest Tuple{+lx, +arest}:
      (lx, all.append(tg, us, js, ks, rest, ys, arest, ay))

def all.keep(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, b: Bool, +x: T.IdleOption, +rest: List<&2, T.IdleOption>, lx: Legal(tg, us, js, ks, x), ar: All(tg, us, js, ks, rest)) -> All(tg, us, js, ks, I.keep(T.IdleOption, b, x, rest)):
  match b:
    case True{}:
      (lx, ar)
    case False{}:
      ar

def shots.all(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, ts: List<&2, S.TargetOption>, sub: Sub(S.TargetOption, ts, tg)) -> All(tg, us, js, ks, P.shots(ts)):
  match ts:
    case Nil{}:
      Unit{}
    case S.Target{+t} <> +rest:
      match sub:
        case Tuple{m, more}:
          (m, shots.all(tg, us, js, ks, rest, more))

def plain.of(item: D.Item, +h: Bool, e: {Bool.not(Bool.or(P.item.chained(item), h)) == True{} : Bool}) -> C.Plain(item):
  match item:
    case D.Saw{}:
      Unit{}
    case D.Glass{}:
      Unit{}
    case D.Jammer{}:
      Wk.absurd(C.Plain(D.Jammer{}), Wk.bool.clash(e))
    case D.Cigarettes{}:
      Unit{}
    case D.Beer{}:
      Unit{}
    case D.Phone{}:
      Unit{}
    case D.Inverter{}:
      Unit{}
    case D.Adrenaline{}:
      Wk.absurd(C.Plain(D.Adrenaline{}), Wk.bool.clash(e))
    case D.Remote{}:
      Unit{}

def use.cell(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +slot: D.Slot, +item: D.Item, +h: Bool, b: Bool, +eb: {Bool.not(Bool.or(P.item.chained(item), h)) == b : Bool}, m: In(S.IdleOption, S.UseAt{slot, item}, us), +rest: List<&2, T.IdleOption>, ar: All(tg, us, js, ks, rest)) -> All(tg, us, js, ks, I.keep(T.IdleOption, b, T.UseSlot{slot, item}, rest)):
  match b:
    case True{}:
      ((m, plain.of(item, h, eb)), ar)
    case False{}:
      ar

def use.all(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, uses: List<&2, S.IdleOption>, +seen: List<&2, D.Item>, sub: Sub(S.IdleOption, uses, us)) -> All(tg, us, js, ks, P.use.options(uses, seen)):
  match uses sub:
    case Nil{} _:
      Unit{}
    case S.UseAt{+slot, +item} <> +rest Tuple{m, more}:
      +h : Bool = P.items.has(seen, item)
      use.cell(tg, us, js, ks, slot, item, h, Bool.not(Bool.or(P.item.chained(item), h)), {==}, m, P.use.options(rest, item <> seen), use.all(tg, us, js, ks, rest, item <> seen, more))
    case S.TakeGun{} <> rest Tuple{m, more}:
      use.all(tg, us, js, ks, rest, seen, more)

def sub.in(-A: Data, xs: List<&2, A>, +full: List<&2, A>, +x: A, sub: Sub(A, xs, full), m: In(A, x, xs)) -> In(A, x, full):
  match xs sub m:
    case Nil{} _ _:
      match m:
    case +y <> ys Tuple{+hy, more} Inl{+e}:
      %Equal.sym(A, x, y, e) : In(A, _, full)
      hy
    case y <> ys Tuple{hy, more} Inr{+rest}:
      sub.in(A, ys, full, x, more, rest)

def head.eq(uses: List<&2, S.IdleOption>, +item: D.Item) -> Bool:
  match uses:
    case S.UseAt{_, found} <> _:
      D.item.eq(found, item)
    case _:
      False{}

def pick.eq(+b: Bool, +b2: Bool, eb: {b == b2 : Bool}, +yes: Maybe<&2, D.Slot>, +no: Maybe<&2, D.Slot>) -> {Bool.pick(Maybe<&2, D.Slot>, b, yes, no) == Bool.pick(Maybe<&2, D.Slot>, b2, yes, no) : Maybe<&2, D.Slot>}:
  Equal.cong(Bool, Maybe<&2, D.Slot>, v => Bool.pick(Maybe<&2, D.Slot>, v, yes, no), b, b2, eb)

def first.go(uses: List<&2, S.IdleOption>, +item: D.Item, +slot: D.Slot, b: Bool, +eb: {head.eq(uses, item) == b : Bool}, +e: {P.use.first(uses, item) == Some{slot} : Maybe<&2, D.Slot>}) -> In(S.IdleOption, S.UseAt{slot, item}, uses):
  match uses b:
    case Nil{} _:
      Wk.absurd(Empty, Wk.maybe.clash(D.Slot, slot, e))
    case S.UseAt{+s, +found} <> +rest True{}:
      +e1 : {Some{s} == Some{slot} : Maybe<&2, D.Slot>} = Equal.trans(Maybe<&2, D.Slot>, Some{s}, Bool.pick(Maybe<&2, D.Slot>, D.item.eq(found, item), Some{s}, P.use.first(rest, item)), Some{slot}, Equal.sym(Maybe<&2, D.Slot>, Bool.pick(Maybe<&2, D.Slot>, D.item.eq(found, item), Some{s}, P.use.first(rest, item)), Some{s}, pick.eq(D.item.eq(found, item), True{}, eb, Some{s}, P.use.first(rest, item))), e)
      %Wk.some.inj(D.Slot, s, slot, e1) : Either<&2, &2, {S.UseAt{_, item} == S.UseAt{s, found} : S.IdleOption}, In(S.IdleOption, S.UseAt{_, item}, rest)>
      %Wk.item.eq.sound(found, item, eb) : Either<&2, &2, {S.UseAt{s, _} == S.UseAt{s, found} : S.IdleOption}, In(S.IdleOption, S.UseAt{s, _}, rest)>
      Inl{{==}}
    case S.UseAt{+s, +found} <> +rest False{}:
      +e1 : {P.use.first(rest, item) == Some{slot} : Maybe<&2, D.Slot>} = Equal.trans(Maybe<&2, D.Slot>, P.use.first(rest, item), Bool.pick(Maybe<&2, D.Slot>, D.item.eq(found, item), Some{s}, P.use.first(rest, item)), Some{slot}, Equal.sym(Maybe<&2, D.Slot>, Bool.pick(Maybe<&2, D.Slot>, D.item.eq(found, item), Some{s}, P.use.first(rest, item)), P.use.first(rest, item), pick.eq(D.item.eq(found, item), False{}, eb, Some{s}, P.use.first(rest, item))), e)
      Inr{first.go(rest, item, slot, head.eq(rest, item), {==}, e1)}
    case S.TakeGun{} <> +rest b:
      Inr{first.go(rest, item, slot, head.eq(rest, item), {==}, e)}

def first.in(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +uses: List<&2, S.IdleOption>, +item: D.Item, +slot: D.Slot, +sub: Sub(S.IdleOption, uses, us), +e: {P.use.first(uses, item) == Some{slot} : Maybe<&2, D.Slot>}) -> In(S.IdleOption, S.UseAt{slot, item}, us):
  sub.in(S.IdleOption, uses, us, S.UseAt{slot, item}, sub, first.go(uses, item, slot, head.eq(uses, item), {==}, e))

def jt.all(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +slot: D.Slot, +mu: In(S.IdleOption, S.UseAt{slot, D.Jammer{}}, us), ts: List<&2, S.JamOption>, sub: Sub(S.JamOption, ts, js)) -> All(tg, us, js, ks, P.jam.targets(slot, ts)):
  match ts sub:
    case Nil{} _:
      Unit{}
    case S.JamAt{+t} <> rest Tuple{m, more}:
      ((mu, m), jt.all(tg, us, js, ks, slot, mu, rest, more))

def jam.all(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +uses: List<&2, S.IdleOption>, +usub: Sub(S.IdleOption, uses, us), mj: Maybe<&2, D.Slot>, +emj: {P.use.first(uses, D.Jammer{}) == mj : Maybe<&2, D.Slot>}, +ts: List<&2, S.JamOption>, +tsub: Sub(S.JamOption, ts, js)) -> All(tg, us, js, ks, P.jam.options(mj, ts)):
  match mj:
    case None{}:
      Unit{}
    case Some{+slot}:
      jt.all(tg, us, js, ks, slot, first.in(tg, us, js, ks, uses, D.Jammer{}, slot, usub, emj), ts, tsub)

def steal.cell(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +adr: D.Slot, +mu: In(S.IdleOption, S.UseAt{adr, D.Adrenaline{}}, us), +owner: D.Seat, +slot: D.Slot, +item: D.Item, +h: Bool, b: Bool, +eb: {Bool.not(Bool.or(P.item.chained(item), h)) == b : Bool}, m: In(S.StealOption, S.Pick{owner, slot, item}, ks), +rest: List<&2, T.IdleOption>, ar: All(tg, us, js, ks, rest)) -> All(tg, us, js, ks, I.keep(T.IdleOption, b, T.StealWith{adr, owner, slot, item}, rest)):
  match b:
    case True{}:
      ((mu, (m, plain.of(item, h, eb))), ar)
    case False{}:
      ar

def sp.all(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +adr: D.Slot, +mu: In(S.IdleOption, S.UseAt{adr, D.Adrenaline{}}, us), picks: List<&2, S.StealOption>, +seen: List<&2, D.At<&2, D.Item>>, sub: Sub(S.StealOption, picks, ks)) -> All(tg, us, js, ks, P.steal.picks(adr, picks, seen)):
  match picks sub:
    case Nil{} _:
      Unit{}
    case S.Pick{+owner, +slot, +item} <> +rest Tuple{m, more}:
      +h : Bool = P.picks.has(seen, owner, item)
      steal.cell(tg, us, js, ks, adr, mu, owner, slot, item, h, Bool.not(Bool.or(P.item.chained(item), h)), {==}, m, P.steal.picks(adr, rest, D.At{owner, item} <> seen), sp.all(tg, us, js, ks, adr, mu, rest, D.At{owner, item} <> seen, more))

def sjt.all(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +adr: D.Slot, +mu: In(S.IdleOption, S.UseAt{adr, D.Adrenaline{}}, us), +owner: D.Seat, +slot: D.Slot, +mk: In(S.StealOption, S.Pick{owner, slot, D.Jammer{}}, ks), ts: List<&2, S.JamOption>, sub: Sub(S.JamOption, ts, js)) -> All(tg, us, js, ks, P.steal_jam.targets(adr, owner, slot, ts)):
  match ts sub:
    case Nil{} _:
      Unit{}
    case S.JamAt{+t} <> rest Tuple{m, more}:
      ((mu, (mk, m)), sjt.all(tg, us, js, ks, adr, mu, owner, slot, mk, rest, more))

def pick.cast(+ks: List<&2, S.StealOption>, +owner: D.Seat, +slot: D.Slot, +item: D.Item, e: {item == D.Jammer{} : D.Item}, m: In(S.StealOption, S.Pick{owner, slot, item}, ks)) -> In(S.StealOption, S.Pick{owner, slot, D.Jammer{}}, ks):
  %e : In(S.StealOption, S.Pick{owner, slot, _}, ks)
  m

def sjh.all(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +adr: D.Slot, +mu: In(S.IdleOption, S.UseAt{adr, D.Adrenaline{}}, us), +owner: D.Seat, +slot: D.Slot, +item: D.Item, +h: Bool, take: Bool, +et: {Bool.and(D.item.eq(item, D.Jammer{}), h) == take : Bool}, m: In(S.StealOption, S.Pick{owner, slot, item}, ks), +ts: List<&2, S.JamOption>, +tsub: Sub(S.JamOption, ts, js)) -> All(tg, us, js, ks, P.steal_jam.here(take, adr, owner, slot, ts)):
  match take:
    case False{}:
      Unit{}
    case True{}:
      sjt.all(tg, us, js, ks, adr, mu, owner, slot, pick.cast(ks, owner, slot, item, Wk.item.eq.sound(item, D.Jammer{}, and.l(D.item.eq(item, D.Jammer{}), h, et)), m), ts, tsub)

def sjp.all(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +adr: D.Slot, +mu: In(S.IdleOption, S.UseAt{adr, D.Adrenaline{}}, us), picks: List<&2, S.StealOption>, +ts: List<&2, S.JamOption>, +tsub: Sub(S.JamOption, ts, js), +seen: List<&2, D.Seat>, sub: Sub(S.StealOption, picks, ks)) -> All(tg, us, js, ks, P.steal_jam.picks(adr, picks, ts, seen)):
  match picks sub:
    case Nil{} _:
      Unit{}
    case S.Pick{+owner, +slot, +item} <> +rest Tuple{m, more}:
      +jammer : Bool = D.item.eq(item, D.Jammer{})
      +h : Bool = Bool.not(P.seats.has(seen, owner))
      all.append(tg, us, js, ks, P.steal_jam.here(Bool.and(jammer, h), adr, owner, slot, ts), P.steal_jam.picks(adr, rest, ts, I.keep(D.Seat, jammer, owner, seen)), sjh.all(tg, us, js, ks, adr, mu, owner, slot, item, h, Bool.and(jammer, h), {==}, m, ts, tsub), sjp.all(tg, us, js, ks, adr, mu, rest, ts, tsub, I.keep(D.Seat, jammer, owner, seen), more))

def steal.all(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +uses: List<&2, S.IdleOption>, +usub: Sub(S.IdleOption, uses, us), ma: Maybe<&2, D.Slot>, +ema: {P.use.first(uses, D.Adrenaline{}) == ma : Maybe<&2, D.Slot>}, +picks: List<&2, S.StealOption>, +ksub: Sub(S.StealOption, picks, ks), +ts: List<&2, S.JamOption>, +tsub: Sub(S.JamOption, ts, js)) -> All(tg, us, js, ks, List.append(&2, T.IdleOption, P.steal.options(ma, picks), P.steal_jam.options(ma, picks, ts))):
  match ma:
    case None{}:
      Unit{}
    case Some{+adr}:
      +mu : In(S.IdleOption, S.UseAt{adr, D.Adrenaline{}}, us) = first.in(tg, us, js, ks, uses, D.Adrenaline{}, adr, usub, ema)
      all.append(tg, us, js, ks, P.steal.picks(adr, picks, Nil{}), P.steal_jam.picks(adr, picks, ts, Nil{}), sp.all(tg, us, js, ks, adr, mu, picks, Nil{}, ksub), sjp.all(tg, us, js, ks, adr, mu, picks, ts, tsub, Nil{}, ksub))

def Rec(+w: S.World, +p: S.Players, +g: S.Grabs) -> S.State:
  S.State{w, p, S.Blocked{None{}}, Nil{}, g}

def Uses(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat) -> List<&2, S.IdleOption>:
  I.uses(Rec(w, p, g), seat)

# Every option of the simple Idle menu is legal for sm's menus at the state.
def options.all(+w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +seat: D.Seat) -> All(G.aim.targets(p), S.TakeGun{} <> Uses(w, p, g, seat), I.jam.for(Rec(w, p, g), seat), I.steal.for(Rec(w, p, g), seat), P.options(T.State{w, p, ph, l, g}, seat)):
  +uses : List<&2, S.IdleOption> = Uses(w, p, g, seat)
  +tg : List<&2, S.TargetOption> = G.aim.targets(p)
  +us : List<&2, S.IdleOption> = S.TakeGun{} <> uses
  +js : List<&2, S.JamOption> = I.jam.for(Rec(w, p, g), seat)
  +ks : List<&2, S.StealOption> = I.steal.for(Rec(w, p, g), seat)
  +usub : Sub(S.IdleOption, uses, us) = sub.weaken(S.IdleOption, uses, uses, S.TakeGun{}, sub.refl(S.IdleOption, uses))
  +ma : Maybe<&2, D.Slot> = P.use.first(uses, D.Adrenaline{})
  +a1 : All(tg, us, js, ks, P.shots(tg)) = shots.all(tg, us, js, ks, tg, sub.refl(S.TargetOption, tg))
  +a2 : All(tg, us, js, ks, P.use.options(uses, Nil{})) = use.all(tg, us, js, ks, uses, Nil{}, usub)
  +a3 : All(tg, us, js, ks, P.jam.options(P.use.first(uses, D.Jammer{}), js)) = jam.all(tg, us, js, ks, uses, usub, P.use.first(uses, D.Jammer{}), {==}, js, sub.refl(S.JamOption, js))
  +a4 : All(tg, us, js, ks, List.append(&2, T.IdleOption, P.steal.options(ma, ks), P.steal_jam.options(ma, ks, js))) = steal.all(tg, us, js, ks, uses, usub, ma, {==}, ks, sub.refl(S.StealOption, ks), js, sub.refl(S.JamOption, js))
  all.append(tg, us, js, ks, P.shots(tg), List.append(&2, T.IdleOption, P.use.options(uses, Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(uses, D.Jammer{}), js), List.append(&2, T.IdleOption, P.steal.options(ma, ks), P.steal_jam.options(ma, ks, js)))), a1, all.append(tg, us, js, ks, P.use.options(uses, Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(uses, D.Jammer{}), js), List.append(&2, T.IdleOption, P.steal.options(ma, ks), P.steal_jam.options(ma, ks, js))), a2, all.append(tg, us, js, ks, P.jam.options(P.use.first(uses, D.Jammer{}), js), List.append(&2, T.IdleOption, P.steal.options(ma, ks), P.steal_jam.options(ma, ks, js)), a3, a4)))

def Picked(+tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, +xs: List<&2, T.IdleOption>, +i: Nat) -> Data:
  Sigma<&2, &2, T.IdleOption, x => Sigma<&2, &2, {P.option.nth(xs, i) == Some{x} : Maybe<&2, T.IdleOption>}, e0 => Legal(tg, us, js, ks, x)>>

# The choice index a simple Idle answer reads always picks an option.
def pick.at(os: List<&2, T.IdleOption>, n: Nat, +o: T.IdleOption, +tg: List<&2, S.TargetOption>, +us: List<&2, S.IdleOption>, +js: List<&2, S.JamOption>, +ks: List<&2, S.StealOption>, all: All(tg, us, js, ks, o <> os)) -> Picked(tg, us, js, ks, o <> os, D.clamp(n, List.length(&2, T.Move, P.moves(os)))):
  match os n all:
    case Nil{} 0n Tuple{lo, _}:
      (o, ({==}, lo))
    case Nil{} 1n+k Tuple{lo, _}:
      (o, ({==}, lo))
    case o2 <> os2 0n Tuple{lo, _}:
      (o, ({==}, lo))
    case +o2 <> +os2 1n+k Tuple{lo, more}:
      pick.at(os2, k, o2, tg, us, js, ks, more)

# Emptying a slot changes no seat's health or jam, and a thief's own slots
# are not among its steal picks.
def jamfor.slots(+w: S.World, p: S.Players, +q1: S.Phase, +n1: List<&2, D.Note>, +q2: S.Phase, +n2: List<&2, D.Note>, +g: S.Grabs, s: D.Seat, +x: D.Slots, +by: D.Seat) -> {I.jam.for(S.State{w, S.players.set_slots(p, s, x), q1, n1, g}, by) == I.jam.for(S.State{w, p, q2, n2, g}, by) : List<&2, S.JamOption>}:
  match p s:
    case D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat0{}:
      {==}
    case D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat1{}:
      {==}
    case D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat2{}:
      {==}
    case D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat3{}:
      {==}
    case D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} D.Seat0{}:
      {==}
    case D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} D.Seat1{}:
      {==}
    case D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} D.Seat2{}:
      {==}
    case D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} D.Seat3{}:
      {==}
    case D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat0{}:
      {==}
    case D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat1{}:
      {==}
    case D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat2{}:
      {==}
    case D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat3{}:
      {==}

def stealfor.slots(+w: S.World, p: S.Players, +q1: S.Phase, +n1: List<&2, D.Note>, +q2: S.Phase, +n2: List<&2, D.Note>, +g: S.Grabs, thief: D.Seat, +x: D.Slots) -> {I.steal.for(S.State{w, S.players.set_slots(p, thief, x), q1, n1, g}, thief) == I.steal.for(S.State{w, p, q2, n2, g}, thief) : List<&2, S.StealOption>}:
  match p thief:
    case D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat0{}:
      {==}
    case D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat1{}:
      {==}
    case D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat2{}:
      {==}
    case D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat3{}:
      {==}
    case D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} D.Seat0{}:
      {==}
    case D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} D.Seat1{}:
      {==}
    case D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} D.Seat2{}:
      {==}
    case D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} D.Seat3{}:
      {==}
    case D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat0{}:
      {==}
    case D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat1{}:
      {==}
    case D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat2{}:
      {==}
    case D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} D.Seat3{}:
      {==}

def walk.cons(+x: S.State, +step: SA.Step, +rest: List<&2, SA.Step>, +k: Nat, +x1: S.State, legal: {SA.walk.legal(M.request(x), step) == Some{k} : Maybe<&2, Nat>}, answered: {M.answer(x, k) == S.state.stepped(x1) : D.Stepped<&2, S.State>}) -> {SA.walk.go(step <> rest, x) == SA.walk.merge(S.state.stepped(x1), SA.walk.go(rest, x1)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  %Equal.sym(Maybe<&2, Nat>, SA.walk.legal(M.request(x), step), Some{k}, legal) : {SA.walk.answer(_, x, next => SA.walk.go(rest, next)) == SA.walk.merge(S.state.stepped(x1), SA.walk.go(rest, x1)) : Maybe<&2, D.Stepped<&2, S.State>>}
  %Equal.sym(D.Stepped<&2, S.State>, M.answer(x, k), S.state.stepped(x1), answered) : {SA.walk.merge(_, SA.walk.go(rest, M.stepped.state(_))) == SA.walk.merge(S.state.stepped(x1), SA.walk.go(rest, x1)) : Maybe<&2, D.Stepped<&2, S.State>>}
  {==}

def IdleGoal(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, sel: Maybe<&2, T.IdleOption>) -> Data:
  {SA.walk(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.chain.rest(T.State{w, p, T.Idle{seat}, l, g}, SA.option.steps(seat, sel), SA.walk.go(SA.option.steps(seat, sel), SA.embed(T.State{w, p, T.Idle{seat}, l, g})))) == SA.lift(T.state.stepped(N.pickup.selected(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, sel))) : Maybe<&2, D.Stepped<&2, S.State>>}

# A simple Idle move whose sm steps reach xl, then the grab moves after it.
def opt.finish(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +o: T.IdleOption, +f: SA.Step, +fr: List<&2, SA.Step>, +xl: S.State, +d: List<&2, D.Note>, +eo: {SA.option.steps(seat, Some{o}) == f <> fr : List<&2, SA.Step>}, ewalk: {SA.walk.go(f <> fr, SA.embed(T.State{w, p, T.Idle{seat}, l, g})) == Some{D.Stepped{xl, d}} : Maybe<&2, D.Stepped<&2, S.State>>}, top: Rf.Top(N.pickup.selected(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, Some{o}), SA.walk.go(f <> List.append(&2, SA.Step, fr, SA.sched(xl, S.world.first_turn(S.state.world(xl)))), SA.embed(T.State{w, p, T.Idle{seat}, l, g})))) -> IdleGoal(w, p, l, g, seat, Some{o}):
  %Equal.sym(List<&2, SA.Step>, SA.option.steps(seat, Some{o}), f <> fr, eo) : {SA.walk(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.chain.rest(T.State{w, p, T.Idle{seat}, l, g}, _, SA.walk.go(_, SA.embed(T.State{w, p, T.Idle{seat}, l, g})))) == SA.lift(T.state.stepped(N.pickup.selected(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, Some{o}))) : Maybe<&2, D.Stepped<&2, S.State>>}
  %Equal.sym(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.go(f <> fr, SA.embed(T.State{w, p, T.Idle{seat}, l, g})), Some{D.Stepped{xl, d}}, ewalk) : {SA.walk(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.chain.rest(T.State{w, p, T.Idle{seat}, l, g}, f <> fr, _)) == SA.lift(T.state.stepped(N.pickup.selected(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, Some{o}))) : Maybe<&2, D.Stepped<&2, S.State>>}
  Rf.top.notes(N.pickup.selected(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, Some{o}), SA.walk.go(f <> List.append(&2, SA.Step, fr, SA.sched(xl, S.world.first_turn(S.state.world(xl)))), SA.embed(T.State{w, p, T.Idle{seat}, l, g})), top)

def idle.nth.sel(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat, +k: Nat, +mv: D.Move, +o: S.IdleOption, enth: {G.idle.nth(S.TakeGun{} <> Uses(w, p, g, seat), k) == Some{o} : Maybe<&2, S.IdleOption>}) -> {M.answer.choice(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, D.Choice{seat, k, mv}) == M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{o}) : S.State}:
  %Equal.sym(Maybe<&2, S.IdleOption>, G.idle.nth(S.TakeGun{} <> Uses(w, p, g, seat), k), Some{o}, enth) : {M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, _) == M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{o}) : S.State}
  {==}

def idle.step(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +n1: Nat, +k: Nat, +mv: D.Move, +o: S.IdleOption, res: {D.resolve(M.request(SA.embed(T.State{w, p, T.Idle{seat}, l, g})), n1) == D.Chose{D.Choice{seat, k, mv}} : D.Resolved}, enth: {G.idle.nth(S.TakeGun{} <> Uses(w, p, g, seat), k) == Some{o} : Maybe<&2, S.IdleOption>}) -> {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{o})) : D.Stepped<&2, S.State>}:
  Equal.trans(D.Stepped<&2, S.State>, M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1), S.state.stepped(M.answer.choice(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, D.Choice{seat, k, mv})), S.state.stepped(M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{o})), L.choose.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1, M.request(SA.embed(T.State{w, p, T.Idle{seat}, l, g})), D.Choice{seat, k, mv}, res), Equal.cong(S.State, D.Stepped<&2, S.State>, y => S.state.stepped(y), M.answer.choice(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, D.Choice{seat, k, mv}), M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{o}), idle.nth.sel(w, p, g, seat, k, mv, o, enth)))

def case.use.step(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, +item: D.Item, +plain: C.Plain(item), +k: Nat, +enth: {G.idle.nth(S.TakeGun{} <> Uses(w, p, g, seat), k) == Some{S.UseAt{slot, item}} : Maybe<&2, S.IdleOption>}, ms: MenuStep(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Uses(w, p, g, seat)), D.UseItem{slot, item}, k)) -> IdleGoal(w, p, l, g, seat, Some{T.UseSlot{slot, item}}):
  match ms:
    case Tuple{+n1, Tuple{+legal, +res}}:
      +answered : {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item)) : D.Stepped<&2, S.State>} = idle.step(w, p, l, g, seat, n1, k, D.UseItem{slot, item}, S.UseAt{slot, item}, res, enth)
      +rel : C.Rel(N.item.use(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, seat, slot, item), M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item)) = C.rel.of(t => N.item.use(t, seat, seat, slot, item), y => M.item.use(y, seat, seat, slot, item), T.Empty{}, w, p, T.Idle{seat}, T.Empty{}, g, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, C.item_use.c(T.Empty{}, w, p, T.Idle{seat}, T.Empty{}, g, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, seat, seat, slot, item, plain))
      +rest : List<&2, SA.Step> = SA.sched(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item), S.world.first_turn(S.state.world(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item))))
      opt.finish(w, p, l, g, seat, T.UseSlot{slot, item}, SA.ChoiceStep{seat, D.UseItem{slot, item}}, Nil{}, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item), List.append(&2, D.Note, S.state.notes(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item)), Nil{}), {==}, walk.cons(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, D.UseItem{slot, item}}, Nil{}, n1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item), legal, answered), Rf.top.first(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, D.UseItem{slot, item}}, rest, n1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item), N.item.use(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, seat, slot, item), legal, answered, Rf.rest.claim(N.item.use(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, seat, slot, item), M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item), rel)))

def case.use(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +slot: D.Slot, +item: D.Item, +plain: C.Plain(item), found: opt.R(S.TakeGun{} <> Uses(w, p, g, seat), S.UseAt{slot, item})) -> IdleGoal(w, p, l, g, seat, Some{T.UseSlot{slot, item}}):
  match found:
    case Tuple{+k, Tuple{+efind, +enth}}:
      case.use.step(w, p, l, g, seat, slot, item, plain, k, enth, menu.step(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Uses(w, p, g, seat)), D.UseItem{slot, item}, k, seated, efind))

def top.cast(+u1: T.State, +u2: T.State, e: {u2 == u1 : T.State}, +walked: Maybe<&2, D.Stepped<&2, S.State>>, top: Rf.Top(u2, walked)) -> Rf.Top(u1, walked):
  %e : Rf.Top(_, walked)
  top

def aim.sel(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat, +k: Nat, +t: D.Seat, enth: {G.target.nth(G.aim.targets(p), k) == Some{S.Target{t}} : Maybe<&2, S.TargetOption>}) -> {M.answer.choice(S.State{w, p, S.Aim{seat}, Nil{}, g}, D.Choice{seat, k, D.Shoot{t}}) == M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t) : S.State}:
  %Equal.sym(Maybe<&2, S.TargetOption>, G.target.nth(G.aim.targets(p), k), Some{S.Target{t}}, enth) : {M.aim.selected(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, _) == M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t) : S.State}
  {==}

def shoot.frame(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat, +t: D.Seat) -> {N.shoot(T.State{w, p, T.Idle{seat}, T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, g}, seat, t) == C.shift(T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t)) : T.State}:
  C.frame.of(v => N.shoot(v, seat, t), y => M.shoot(y, seat, t), T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, w, p, T.Idle{seat}, T.Empty{}, g, S.Aim{seat}, C.shoot.c(T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, w, p, T.Idle{seat}, T.Empty{}, g, S.Aim{seat}, seat, t))

def shoot.rel(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat, +t: D.Seat) -> C.Rel(N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t), M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)):
  C.rel.of(v => N.shoot(v, seat, t), y => M.shoot(y, seat, t), T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, w, p, T.Idle{seat}, T.Empty{}, g, S.Aim{seat}, C.shoot.c(T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, w, p, T.Idle{seat}, T.Empty{}, g, S.Aim{seat}, seat, t))

def case.shoot.two(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +t: D.Seat, +n1: Nat, +legal1: {SA.walk.legal(M.request(SA.embed(T.State{w, p, T.Idle{seat}, l, g})), SA.ChoiceStep{seat, D.PickUp{}}) == Some{n1} : Maybe<&2, Nat>}, +answered1: {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat)) : D.Stepped<&2, S.State>}, +k: Nat, +enth: {G.target.nth(G.aim.targets(p), k) == Some{S.Target{t}} : Maybe<&2, S.TargetOption>}, ms: MenuStep(S.world.table(w), seat, G.aim.moves(G.aim.targets(p)), D.Shoot{t}, k)) -> IdleGoal(w, p, l, g, seat, Some{T.ShootAt{t}}):
  match ms:
    case Tuple{+n2, Tuple{+legal2, +res2}}:
      +answered2 : {M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2) == S.state.stepped(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)) : D.Stepped<&2, S.State>} = Equal.trans(D.Stepped<&2, S.State>, M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2), S.state.stepped(M.answer.choice(S.State{w, p, S.Aim{seat}, Nil{}, g}, D.Choice{seat, k, D.Shoot{t}})), S.state.stepped(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)), L.choose.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2, M.request(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat)), D.Choice{seat, k, D.Shoot{t}}, res2), Equal.cong(S.State, D.Stepped<&2, S.State>, y => S.state.stepped(y), M.answer.choice(S.State{w, p, S.Aim{seat}, Nil{}, g}, D.Choice{seat, k, D.Shoot{t}}), M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t), aim.sel(w, p, g, seat, k, t, enth)))
      +rest : List<&2, SA.Step> = SA.sched(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t), S.world.first_turn(S.state.world(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t))))
      +fin2 : Rf.RestOf(N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t), M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)) = Rf.rest.claim(N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t), M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t), shoot.rel(w, p, g, seat, t))
      +fin1 : L.Fin.of(C.shift(T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t)), M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat), SA.walk.go(SA.ChoiceStep{seat, D.Shoot{t}} <> rest, M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat))) = Rf.fin.mid(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat), SA.ChoiceStep{seat, D.Shoot{t}}, rest, n2, M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t), N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t), T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, legal2, answered2, {==}, fin2)
      +top : Rf.Top(C.shift(T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t)), SA.walk.go(SA.ChoiceStep{seat, D.PickUp{}} <> SA.ChoiceStep{seat, D.Shoot{t}} <> rest, SA.embed(T.State{w, p, T.Idle{seat}, l, g}))) = Rf.top.first(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, D.PickUp{}}, SA.ChoiceStep{seat, D.Shoot{t}} <> rest, n1, M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat), C.shift(T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t)), legal1, answered1, fin1)
      +ewalk : {SA.walk.go([SA.ChoiceStep{seat, D.PickUp{}}, SA.ChoiceStep{seat, D.Shoot{t}}], SA.embed(T.State{w, p, T.Idle{seat}, l, g})) == SA.walk.merge(S.state.stepped(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat)), SA.walk.merge(S.state.stepped(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)), SA.walk.go(Nil{}, M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)))) : Maybe<&2, D.Stepped<&2, S.State>>} = Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.go([SA.ChoiceStep{seat, D.PickUp{}}, SA.ChoiceStep{seat, D.Shoot{t}}], SA.embed(T.State{w, p, T.Idle{seat}, l, g})), SA.walk.merge(S.state.stepped(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat)), SA.walk.go([SA.ChoiceStep{seat, D.Shoot{t}}], M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat))), SA.walk.merge(S.state.stepped(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat)), SA.walk.merge(S.state.stepped(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)), SA.walk.go(Nil{}, M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)))), walk.cons(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, D.PickUp{}}, [SA.ChoiceStep{seat, D.Shoot{t}}], n1, M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat), legal1, answered1), Equal.cong(Maybe<&2, D.Stepped<&2, S.State>>, Maybe<&2, D.Stepped<&2, S.State>>, r => SA.walk.merge(S.state.stepped(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat)), r), SA.walk.go([SA.ChoiceStep{seat, D.Shoot{t}}], M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat)), SA.walk.merge(S.state.stepped(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)), SA.walk.go(Nil{}, M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t))), walk.cons(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat), SA.ChoiceStep{seat, D.Shoot{t}}, Nil{}, n2, M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t), legal2, answered2)))
      opt.finish(w, p, l, g, seat, T.ShootAt{t}, SA.ChoiceStep{seat, D.PickUp{}}, [SA.ChoiceStep{seat, D.Shoot{t}}], M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t), List.append(&2, D.Note, S.state.notes(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat)), List.append(&2, D.Note, S.state.notes(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)), Nil{})), {==}, ewalk, top.cast(N.pickup.selected(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, Some{T.ShootAt{t}}), C.shift(T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t)), Equal.sym(T.State, N.pickup.selected(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, Some{T.ShootAt{t}}), C.shift(T.Snoc{T.Empty{}, D.Shown{D.PickedUp{seat}}}, N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t)), shoot.frame(w, p, g, seat, t)), SA.walk.go(SA.ChoiceStep{seat, D.PickUp{}} <> SA.ChoiceStep{seat, D.Shoot{t}} <> rest, SA.embed(T.State{w, p, T.Idle{seat}, l, g})), top))

def case.shoot.one(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +t: D.Seat, found: tgt.R(G.aim.targets(p), S.Target{t}), ms: MenuStep(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Uses(w, p, g, seat)), D.PickUp{}, 0n)) -> IdleGoal(w, p, l, g, seat, Some{T.ShootAt{t}}):
  match found ms:
    case Tuple{+k, Tuple{+efind, +enth}} Tuple{+n1, Tuple{+legal1, +res1}}:
      +answered1 : {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat)) : D.Stepped<&2, S.State>} = idle.step(w, p, l, g, seat, n1, 0n, D.PickUp{}, S.TakeGun{}, res1, {==})
      case.shoot.two(w, p, l, g, seat, t, n1, legal1, answered1, k, enth, menu.step(S.world.table(w), seat, G.aim.moves(G.aim.targets(p)), D.Shoot{t}, k, seated, efind))

def case.shoot(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +t: D.Seat, mem: In(S.TargetOption, S.Target{t}, G.aim.targets(p))) -> IdleGoal(w, p, l, g, seat, Some{T.ShootAt{t}}):
  case.shoot.one(w, p, l, g, seat, seated, t, tgt.find(G.aim.targets(p), S.Target{t}, mem), menu.step(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Uses(w, p, g, seat)), D.PickUp{}, 0n, seated, {==}))

def in.cast(-A: Data, +x: A, +xs: List<&2, A>, +ys: List<&2, A>, e: {xs == ys : List<&2, A>}, m: In(A, x, xs)) -> In(A, x, ys):
  %e : In(A, x, _)
  m

def jam.sel(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat, +ts: List<&2, S.JamOption>, +k: Nat, +t: D.Seat, enth: {I.jam.nth(ts, k) == Some{S.JamAt{t}} : Maybe<&2, S.JamOption>}) -> {M.answer.choice(S.State{w, p, S.JamPick{seat, ts}, Nil{}, g}, D.Choice{seat, k, D.JamTarget{t}}) == M.jam.selected(S.State{w, p, S.JamPick{seat, ts}, Nil{}, g}, seat, Some{S.JamAt{t}}) : S.State}:
  %Equal.sym(Maybe<&2, S.JamOption>, I.jam.nth(ts, k), Some{S.JamAt{t}}, enth) : {M.jam.selected(S.State{w, p, S.JamPick{seat, ts}, Nil{}, g}, seat, _) == M.jam.selected(S.State{w, p, S.JamPick{seat, ts}, Nil{}, g}, seat, Some{S.JamAt{t}}) : S.State}
  {==}

def case.jam.two(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, +t: D.Seat, +n1: Nat, +legal1: {SA.walk.legal(M.request(SA.embed(T.State{w, p, T.Idle{seat}, l, g})), SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}) == Some{n1} : Maybe<&2, Nat>}, +answered1: {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})) : D.Stepped<&2, S.State>}, +k: Nat, +enth: {I.jam.nth(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat), k) == Some{S.JamAt{t}} : Maybe<&2, S.JamOption>}, ms: MenuStep(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)), D.JamTarget{t}, k)) -> IdleGoal(w, p, l, g, seat, Some{T.JamWith{slot, t}}):
  match ms:
    case Tuple{+n2, Tuple{+legal2, +res2}}:
      +answered2 : {M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2) == S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})) : D.Stepped<&2, S.State>} = Equal.trans(D.Stepped<&2, S.State>, M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2), S.state.stepped(M.answer.choice(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, D.Choice{seat, k, D.JamTarget{t}})), S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), L.choose.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2, M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), D.Choice{seat, k, D.JamTarget{t}}, res2), Equal.cong(S.State, D.Stepped<&2, S.State>, y => S.state.stepped(y), M.answer.choice(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, D.Choice{seat, k, D.JamTarget{t}}), M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), jam.sel(w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), g, seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat), k, t, enth)))
      +rest : List<&2, SA.Step> = SA.sched(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), S.world.first_turn(S.state.world(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}))))
      +fin2 : Rf.RestOf(N.jam.selected(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t), M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})) = Rf.rest.claim(N.jam.selected(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t), M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), Inl{({==}, {==})})
      +fin1 : L.Fin.of(C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}}, N.jam.selected(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t)), M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), SA.walk.go(SA.ChoiceStep{seat, D.JamTarget{t}} <> rest, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}))) = Rf.fin.mid(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), SA.ChoiceStep{seat, D.JamTarget{t}}, rest, n2, M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), N.jam.selected(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t), T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}}, legal2, answered2, {==}, fin2)
      +top : Rf.Top(C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}}, N.jam.selected(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t)), SA.walk.go(SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> SA.ChoiceStep{seat, D.JamTarget{t}} <> rest, SA.embed(T.State{w, p, T.Idle{seat}, l, g}))) = Rf.top.first(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}} <> rest, n1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}}, N.jam.selected(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t)), legal1, answered1, fin1)
      +ewalk : {SA.walk.go([SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}], SA.embed(T.State{w, p, T.Idle{seat}, l, g})) == SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), SA.walk.merge(S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), SA.walk.go(Nil{}, M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})))) : Maybe<&2, D.Stepped<&2, S.State>>} = Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.go([SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}], SA.embed(T.State{w, p, T.Idle{seat}, l, g})), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), SA.walk.go([SA.ChoiceStep{seat, D.JamTarget{t}}], M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}))), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), SA.walk.merge(S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), SA.walk.go(Nil{}, M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})))), walk.cons(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, [SA.ChoiceStep{seat, D.JamTarget{t}}], n1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), legal1, answered1), Equal.cong(Maybe<&2, D.Stepped<&2, S.State>>, Maybe<&2, D.Stepped<&2, S.State>>, r => SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), r), SA.walk.go([SA.ChoiceStep{seat, D.JamTarget{t}}], M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), SA.walk.merge(S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), SA.walk.go(Nil{}, M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}))), walk.cons(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), SA.ChoiceStep{seat, D.JamTarget{t}}, Nil{}, n2, M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), legal2, answered2)))
      opt.finish(w, p, l, g, seat, T.JamWith{slot, t}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, [SA.ChoiceStep{seat, D.JamTarget{t}}], M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), List.append(&2, D.Note, S.state.notes(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), List.append(&2, D.Note, S.state.notes(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), Nil{})), {==}, ewalk, top)

def case.jam.mid(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +slot: D.Slot, +t: D.Seat, +mj: In(S.JamOption, S.JamAt{t}, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)), +k: Nat, +enth: {G.idle.nth(S.TakeGun{} <> Uses(w, p, g, seat), k) == Some{S.UseAt{slot, D.Jammer{}}} : Maybe<&2, S.IdleOption>}, ms: MenuStep(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Uses(w, p, g, seat)), D.UseItem{slot, D.Jammer{}}, k), found2: jmo.R(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat), S.JamAt{t})) -> IdleGoal(w, p, l, g, seat, Some{T.JamWith{slot, t}}):
  match ms found2:
    case Tuple{+n1, Tuple{+legal1, +res1}} Tuple{+k2, Tuple{+efind2, +enth2}}:
      +answered1 : {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})) : D.Stepped<&2, S.State>} = idle.step(w, p, l, g, seat, n1, k, D.UseItem{slot, D.Jammer{}}, S.UseAt{slot, D.Jammer{}}, res1, enth)
      case.jam.two(w, p, l, g, seat, slot, t, n1, legal1, answered1, k2, enth2, menu.step(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)), D.JamTarget{t}, k2, seated, efind2))

def case.jam.found(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +slot: D.Slot, +t: D.Seat, found: opt.R(S.TakeGun{} <> Uses(w, p, g, seat), S.UseAt{slot, D.Jammer{}}), mj: In(S.JamOption, S.JamAt{t}, I.jam.for(Rec(w, p, g), seat))) -> IdleGoal(w, p, l, g, seat, Some{T.JamWith{slot, t}}):
  match found:
    case Tuple{+k, Tuple{+efind, +enth}}:
      +mj1 : In(S.JamOption, S.JamAt{t}, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)) = in.cast(S.JamOption, S.JamAt{t}, I.jam.for(Rec(w, p, g), seat), I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat), Equal.sym(List<&2, S.JamOption>, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat), I.jam.for(Rec(w, p, g), seat), jamfor.slots(w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], S.Blocked{None{}}, Nil{}, g, seat, I.slots.put(I.seat.slots(p, seat), slot, None{}), seat)), mj)
      case.jam.mid(w, p, l, g, seat, seated, slot, t, mj1, k, enth, menu.step(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Uses(w, p, g, seat)), D.UseItem{slot, D.Jammer{}}, k, seated, efind), jmo.find(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat), S.JamAt{t}, mj1))

def case.jam(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +slot: D.Slot, +t: D.Seat, mu: In(S.IdleOption, S.UseAt{slot, D.Jammer{}}, S.TakeGun{} <> Uses(w, p, g, seat)), mj: In(S.JamOption, S.JamAt{t}, I.jam.for(Rec(w, p, g), seat))) -> IdleGoal(w, p, l, g, seat, Some{T.JamWith{slot, t}}):
  case.jam.found(w, p, l, g, seat, seated, slot, t, opt.find(S.TakeGun{} <> Uses(w, p, g, seat), S.UseAt{slot, D.Jammer{}}, mu), mj)

def steal.sel(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat, +ks: List<&2, S.StealOption>, +k: Nat, +owner: D.Seat, +slot: D.Slot, +item: D.Item, enth: {I.steal.nth(ks, k) == Some{S.Pick{owner, slot, item}} : Maybe<&2, S.StealOption>}) -> {M.answer.choice(S.State{w, p, S.StealPick{seat, ks}, Nil{}, g}, D.Choice{seat, k, D.Steal{owner, slot, item}}) == M.item.use(S.State{w, p, S.StealPick{seat, ks}, Nil{}, g}, seat, owner, slot, item) : S.State}:
  %Equal.sym(Maybe<&2, S.StealOption>, I.steal.nth(ks, k), Some{S.Pick{owner, slot, item}}, enth) : {M.steal.selected(S.State{w, p, S.StealPick{seat, ks}, Nil{}, g}, seat, _) == M.item.use(S.State{w, p, S.StealPick{seat, ks}, Nil{}, g}, seat, owner, slot, item) : S.State}
  {==}

def steal.answered(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +adr: D.Slot, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +n2: Nat, +k: Nat, res2: {D.resolve(M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), n2) == D.Chose{D.Choice{seat, k, D.Steal{owner, slot, item}}} : D.Resolved}, enth: {I.steal.nth(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), k) == Some{S.Pick{owner, slot, item}} : Maybe<&2, S.StealOption>}) -> {M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2) == S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item)) : D.Stepped<&2, S.State>}:
  Equal.trans(D.Stepped<&2, S.State>, M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2), S.state.stepped(M.answer.choice(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, D.Choice{seat, k, D.Steal{owner, slot, item}})), S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item)), L.choose.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2, M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), D.Choice{seat, k, D.Steal{owner, slot, item}}, res2), Equal.cong(S.State, D.Stepped<&2, S.State>, y => S.state.stepped(y), M.answer.choice(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, D.Choice{seat, k, D.Steal{owner, slot, item}}), M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item), steal.sel(w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), g, seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), k, owner, slot, item, enth)))

def use.frame(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +plain: C.Plain(item)) -> {N.item.use(T.State{w, p, ph, a, g}, seat, owner, slot, item) == C.shift(a, N.item.use(T.State{w, p, ph, T.Empty{}, g}, seat, owner, slot, item)) : T.State}:
  C.frame.of(v => N.item.use(v, seat, owner, slot, item), y => M.item.use(y, seat, owner, slot, item), a, w, p, ph, T.Empty{}, g, q, C.item_use.c(a, w, p, ph, T.Empty{}, g, q, seat, owner, slot, item, plain))

def use.rel(+a: T.Log, +w: S.World, +p: S.Players, +ph: T.Phase, +g: S.Grabs, +q: S.Phase, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +plain: C.Plain(item)) -> C.Rel(N.item.use(T.State{w, p, ph, T.Empty{}, g}, seat, owner, slot, item), M.item.use(S.State{w, p, q, Nil{}, g}, seat, owner, slot, item)):
  C.rel.of(v => N.item.use(v, seat, owner, slot, item), y => M.item.use(y, seat, owner, slot, item), a, w, p, ph, T.Empty{}, g, q, C.item_use.c(a, w, p, ph, T.Empty{}, g, q, seat, owner, slot, item, plain))

def case.steal.two(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +adr: D.Slot, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +plain: C.Plain(item), +n1: Nat, +legal1: {SA.walk.legal(M.request(SA.embed(T.State{w, p, T.Idle{seat}, l, g})), SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}) == Some{n1} : Maybe<&2, Nat>}, +answered1: {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})) : D.Stepped<&2, S.State>}, +k: Nat, +enth: {I.steal.nth(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), k) == Some{S.Pick{owner, slot, item}} : Maybe<&2, S.StealOption>}, ms: MenuStep(S.world.table(w), seat, I.steal.moves(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)), D.Steal{owner, slot, item}, k)) -> IdleGoal(w, p, l, g, seat, Some{T.StealWith{adr, owner, slot, item}}):
  match ms:
    case Tuple{+n2, Tuple{+legal2, +res2}}:
      +answered2 : {M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2) == S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item)) : D.Stepped<&2, S.State>} = steal.answered(w, p, l, g, seat, adr, owner, slot, item, n2, k, res2, enth)
      +q : S.Phase = S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}
      +rest : List<&2, SA.Step> = SA.sched(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item), S.world.first_turn(S.state.world(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item))))
      +fin2 : Rf.RestOf(N.item.use(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, T.Empty{}, g}, seat, owner, slot, item), M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item)) = Rf.rest.claim(N.item.use(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, T.Empty{}, g}, seat, owner, slot, item), M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item), use.rel(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, g, q, seat, owner, slot, item, plain))
      +fin1 : L.Fin.of(C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, N.item.use(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, T.Empty{}, g}, seat, owner, slot, item)), M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), SA.walk.go(SA.ChoiceStep{seat, D.Steal{owner, slot, item}} <> rest, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}))) = Rf.fin.mid(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), SA.ChoiceStep{seat, D.Steal{owner, slot, item}}, rest, n2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item), N.item.use(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, T.Empty{}, g}, seat, owner, slot, item), T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, legal2, answered2, {==}, fin2)
      +top : Rf.Top(C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, N.item.use(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, T.Empty{}, g}, seat, owner, slot, item)), SA.walk.go(SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{owner, slot, item}} <> rest, SA.embed(T.State{w, p, T.Idle{seat}, l, g}))) = Rf.top.first(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{owner, slot, item}} <> rest, n1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, N.item.use(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, T.Empty{}, g}, seat, owner, slot, item)), legal1, answered1, fin1)
      +ewalk : {SA.walk.go([SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{owner, slot, item}}], SA.embed(T.State{w, p, T.Idle{seat}, l, g})) == SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item)), SA.walk.go(Nil{}, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item)))) : Maybe<&2, D.Stepped<&2, S.State>>} = Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.go([SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{owner, slot, item}}], SA.embed(T.State{w, p, T.Idle{seat}, l, g})), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.walk.go([SA.ChoiceStep{seat, D.Steal{owner, slot, item}}], M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}))), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item)), SA.walk.go(Nil{}, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item)))), walk.cons(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, [SA.ChoiceStep{seat, D.Steal{owner, slot, item}}], n1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), legal1, answered1), Equal.cong(Maybe<&2, D.Stepped<&2, S.State>>, Maybe<&2, D.Stepped<&2, S.State>>, r => SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), r), SA.walk.go([SA.ChoiceStep{seat, D.Steal{owner, slot, item}}], M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item)), SA.walk.go(Nil{}, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item))), walk.cons(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), SA.ChoiceStep{seat, D.Steal{owner, slot, item}}, Nil{}, n2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item), legal2, answered2)))
      +U : T.State = N.pickup.selected(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, Some{T.StealWith{adr, owner, slot, item}})
      opt.finish(w, p, l, g, seat, T.StealWith{adr, owner, slot, item}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, [SA.ChoiceStep{seat, D.Steal{owner, slot, item}}], M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item), List.append(&2, D.Note, S.state.notes(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), List.append(&2, D.Note, S.state.notes(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, item)), Nil{})), {==}, ewalk, top.cast(U, C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, N.item.use(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, T.Empty{}, g}, seat, owner, slot, item)), Equal.sym(T.State, U, C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, N.item.use(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, T.Empty{}, g}, seat, owner, slot, item)), use.frame(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, g, q, seat, owner, slot, item, plain)), SA.walk.go(SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{owner, slot, item}} <> rest, SA.embed(T.State{w, p, T.Idle{seat}, l, g})), top))

def case.steal.mid(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +adr: D.Slot, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +plain: C.Plain(item), +k: Nat, +enth: {G.idle.nth(S.TakeGun{} <> Uses(w, p, g, seat), k) == Some{S.UseAt{adr, D.Adrenaline{}}} : Maybe<&2, S.IdleOption>}, ms: MenuStep(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Uses(w, p, g, seat)), D.UseItem{adr, D.Adrenaline{}}, k), found2: stl.R(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), S.Pick{owner, slot, item})) -> IdleGoal(w, p, l, g, seat, Some{T.StealWith{adr, owner, slot, item}}):
  match ms found2:
    case Tuple{+n1, Tuple{+legal1, +res1}} Tuple{+k2, Tuple{+efind2, +enth2}}:
      +answered1 : {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})) : D.Stepped<&2, S.State>} = idle.step(w, p, l, g, seat, n1, k, D.UseItem{adr, D.Adrenaline{}}, S.UseAt{adr, D.Adrenaline{}}, res1, enth)
      case.steal.two(w, p, l, g, seat, adr, owner, slot, item, plain, n1, legal1, answered1, k2, enth2, menu.step(S.world.table(w), seat, I.steal.moves(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)), D.Steal{owner, slot, item}, k2, seated, efind2))

def picks.cast(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat, +adr: D.Slot, +x: S.StealOption, m: In(S.StealOption, x, I.steal.for(Rec(w, p, g), seat))) -> In(S.StealOption, x, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)):
  in.cast(S.StealOption, x, I.steal.for(Rec(w, p, g), seat), I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), Equal.sym(List<&2, S.StealOption>, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), I.steal.for(Rec(w, p, g), seat), stealfor.slots(w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], S.Blocked{None{}}, Nil{}, g, seat, I.slots.put(I.seat.slots(p, seat), adr, None{}))), m)

def case.steal.found(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +adr: D.Slot, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +plain: C.Plain(item), found: opt.R(S.TakeGun{} <> Uses(w, p, g, seat), S.UseAt{adr, D.Adrenaline{}}), mk: In(S.StealOption, S.Pick{owner, slot, item}, I.steal.for(Rec(w, p, g), seat))) -> IdleGoal(w, p, l, g, seat, Some{T.StealWith{adr, owner, slot, item}}):
  match found:
    case Tuple{+k, Tuple{+efind, +enth}}:
      +mk1 : In(S.StealOption, S.Pick{owner, slot, item}, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)) = picks.cast(w, p, g, seat, adr, S.Pick{owner, slot, item}, mk)
      case.steal.mid(w, p, l, g, seat, seated, adr, owner, slot, item, plain, k, enth, menu.step(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Uses(w, p, g, seat)), D.UseItem{adr, D.Adrenaline{}}, k, seated, efind), stl.find(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), S.Pick{owner, slot, item}, mk1))

def case.steal(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +adr: D.Slot, +owner: D.Seat, +slot: D.Slot, +item: D.Item, mu: In(S.IdleOption, S.UseAt{adr, D.Adrenaline{}}, S.TakeGun{} <> Uses(w, p, g, seat)), mk: In(S.StealOption, S.Pick{owner, slot, item}, I.steal.for(Rec(w, p, g), seat)), plain: C.Plain(item)) -> IdleGoal(w, p, l, g, seat, Some{T.StealWith{adr, owner, slot, item}}):
  case.steal.found(w, p, l, g, seat, seated, adr, owner, slot, item, plain, opt.find(S.TakeGun{} <> Uses(w, p, g, seat), S.UseAt{adr, D.Adrenaline{}}, mu), mk)

def case.sj.three(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +adr: D.Slot, +owner: D.Seat, +slot: D.Slot, +t: D.Seat, +n1: Nat, +legal1: {SA.walk.legal(M.request(SA.embed(T.State{w, p, T.Idle{seat}, l, g})), SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}) == Some{n1} : Maybe<&2, Nat>}, +answered1: {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})) : D.Stepped<&2, S.State>}, +n2: Nat, +legal2: {SA.walk.legal(M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}) == Some{n2} : Maybe<&2, Nat>}, +answered2: {M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2) == S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})) : D.Stepped<&2, S.State>}, +k: Nat, +enth: {I.jam.nth(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat), k) == Some{S.JamAt{t}} : Maybe<&2, S.JamOption>}, ms: MenuStep(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)), D.JamTarget{t}, k)) -> IdleGoal(w, p, l, g, seat, Some{T.StealJamWith{adr, owner, slot, t}}):
  match ms:
    case Tuple{+n3, Tuple{+legal3, +res3}}:
      +answered3 : {M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{}), n3) == S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})) : D.Stepped<&2, S.State>} = Equal.trans(D.Stepped<&2, S.State>, M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{}), n3), S.state.stepped(M.answer.choice(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, D.Choice{seat, k, D.JamTarget{t}})), S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), L.choose.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{}), n3, M.request(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})), D.Choice{seat, k, D.JamTarget{t}}, res3), Equal.cong(S.State, D.Stepped<&2, S.State>, y => S.state.stepped(y), M.answer.choice(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, D.Choice{seat, k, D.JamTarget{t}}), M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), jam.sel(w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), g, seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat), k, t, enth)))
      +rest : List<&2, SA.Step> = SA.sched(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), S.world.first_turn(S.state.world(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}))))
      +fin3 : Rf.RestOf(N.jam.selected(T.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t), M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})) = Rf.rest.claim(N.jam.selected(T.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t), M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), Inl{({==}, {==})})
      +fin2 : L.Fin.of(C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}}, N.jam.selected(T.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t)), M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{}), SA.walk.go(SA.ChoiceStep{seat, D.JamTarget{t}} <> rest, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{}))) = Rf.fin.mid(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{}), SA.ChoiceStep{seat, D.JamTarget{t}}, rest, n3, M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), N.jam.selected(T.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t), T.Snoc{T.Empty{}, D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}}, legal3, answered3, {==}, fin3)
      +fin1 : L.Fin.of(C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}}, N.jam.selected(T.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t))), M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), SA.walk.go(SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}} <> SA.ChoiceStep{seat, D.JamTarget{t}} <> rest, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}))) = Rf.fin.mid(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}} <> rest, n2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{}), C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}}, N.jam.selected(T.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t)), T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, legal2, answered2, {==}, fin2)
      +top : Rf.Top(C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}}, N.jam.selected(T.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t))), SA.walk.go(SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}} <> SA.ChoiceStep{seat, D.JamTarget{t}} <> rest, SA.embed(T.State{w, p, T.Idle{seat}, l, g}))) = Rf.top.first(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}} <> SA.ChoiceStep{seat, D.JamTarget{t}} <> rest, n1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, C.shift(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}}, N.jam.selected(T.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), T.Idle{seat}, T.Empty{}, g}, seat, t))), legal1, answered1, fin1)
      +ewalk : {SA.walk.go([SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}], SA.embed(T.State{w, p, T.Idle{seat}, l, g})) == SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})), SA.walk.merge(S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), SA.walk.go(Nil{}, M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}))))) : Maybe<&2, D.Stepped<&2, S.State>>} = Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.go([SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}], SA.embed(T.State{w, p, T.Idle{seat}, l, g})), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.walk.go([SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}], M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}))), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})), SA.walk.merge(S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), SA.walk.go(Nil{}, M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}))))), walk.cons(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, [SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}], n1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), legal1, answered1), Equal.cong(Maybe<&2, D.Stepped<&2, S.State>>, Maybe<&2, D.Stepped<&2, S.State>>, r => SA.walk.merge(S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), r), SA.walk.go([SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}], M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})), SA.walk.merge(S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), SA.walk.go(Nil{}, M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})))), Equal.trans(Maybe<&2, D.Stepped<&2, S.State>>, SA.walk.go([SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}], M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})), SA.walk.go([SA.ChoiceStep{seat, D.JamTarget{t}}], M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{}))), SA.walk.merge(S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})), SA.walk.merge(S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), SA.walk.go(Nil{}, M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})))), walk.cons(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}, [SA.ChoiceStep{seat, D.JamTarget{t}}], n2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{}), legal2, answered2), Equal.cong(Maybe<&2, D.Stepped<&2, S.State>>, Maybe<&2, D.Stepped<&2, S.State>>, r => SA.walk.merge(S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})), r), SA.walk.go([SA.ChoiceStep{seat, D.JamTarget{t}}], M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})), SA.walk.merge(S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), SA.walk.go(Nil{}, M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}))), walk.cons(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{}), SA.ChoiceStep{seat, D.JamTarget{t}}, Nil{}, n3, M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), legal3, answered3)))))
      opt.finish(w, p, l, g, seat, T.StealJamWith{adr, owner, slot, t}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, [SA.ChoiceStep{seat, D.Steal{owner, slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}], M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), List.append(&2, D.Note, S.state.notes(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), List.append(&2, D.Note, S.state.notes(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})), List.append(&2, D.Note, S.state.notes(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), Nil{}))), {==}, ewalk, top)

def case.sj.two(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +adr: D.Slot, +owner: D.Seat, +slot: D.Slot, +t: D.Seat, +n1: Nat, +legal1: {SA.walk.legal(M.request(SA.embed(T.State{w, p, T.Idle{seat}, l, g})), SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}) == Some{n1} : Maybe<&2, Nat>}, +answered1: {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})) : D.Stepped<&2, S.State>}, +k: Nat, +enth: {I.steal.nth(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), k) == Some{S.Pick{owner, slot, D.Jammer{}}} : Maybe<&2, S.StealOption>}, ms: MenuStep(S.world.table(w), seat, I.steal.moves(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)), D.Steal{owner, slot, D.Jammer{}}, k), found3: jmo.R(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat), S.JamAt{t})) -> IdleGoal(w, p, l, g, seat, Some{T.StealJamWith{adr, owner, slot, t}}):
  match ms found3:
    case Tuple{+n2, Tuple{+legal2, +res2}} Tuple{+k3, Tuple{+efind3, +enth3}}:
      +answered2 : {M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2) == S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, owner, slot, D.Jammer{})) : D.Stepped<&2, S.State>} = steal.answered(w, p, l, g, seat, adr, owner, slot, D.Jammer{}, n2, k, res2, enth)
      case.sj.three(w, p, l, g, seat, adr, owner, slot, t, n1, legal1, answered1, n2, legal2, answered2, k3, enth3, menu.step(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)), D.JamTarget{t}, k3, seated, efind3))

def case.sj.mid(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +adr: D.Slot, +owner: D.Seat, +slot: D.Slot, +t: D.Seat, +mj2: In(S.JamOption, S.JamAt{t}, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)), +k: Nat, +enth: {G.idle.nth(S.TakeGun{} <> Uses(w, p, g, seat), k) == Some{S.UseAt{adr, D.Adrenaline{}}} : Maybe<&2, S.IdleOption>}, ms: MenuStep(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Uses(w, p, g, seat)), D.UseItem{adr, D.Adrenaline{}}, k), found2: stl.R(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), S.Pick{owner, slot, D.Jammer{}})) -> IdleGoal(w, p, l, g, seat, Some{T.StealJamWith{adr, owner, slot, t}}):
  match ms found2:
    case Tuple{+n1, Tuple{+legal1, +res1}} Tuple{+k2, Tuple{+efind2, +enth2}}:
      +answered1 : {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})) : D.Stepped<&2, S.State>} = idle.step(w, p, l, g, seat, n1, k, D.UseItem{adr, D.Adrenaline{}}, S.UseAt{adr, D.Adrenaline{}}, res1, enth)
      case.sj.two(w, p, l, g, seat, seated, adr, owner, slot, t, n1, legal1, answered1, k2, enth2, menu.step(S.world.table(w), seat, I.steal.moves(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)), D.Steal{owner, slot, D.Jammer{}}, k2, seated, efind2), jmo.find(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat), S.JamAt{t}, mj2))

def case.sj.found(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +adr: D.Slot, +owner: D.Seat, +slot: D.Slot, +t: D.Seat, found: opt.R(S.TakeGun{} <> Uses(w, p, g, seat), S.UseAt{adr, D.Adrenaline{}}), mk: In(S.StealOption, S.Pick{owner, slot, D.Jammer{}}, I.steal.for(Rec(w, p, g), seat)), mj: In(S.JamOption, S.JamAt{t}, I.jam.for(Rec(w, p, g), seat))) -> IdleGoal(w, p, l, g, seat, Some{T.StealJamWith{adr, owner, slot, t}}):
  match found:
    case Tuple{+k, Tuple{+efind, +enth}}:
      +mk1 : In(S.StealOption, S.Pick{owner, slot, D.Jammer{}}, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)) = picks.cast(w, p, g, seat, adr, S.Pick{owner, slot, D.Jammer{}}, mk)
      +e2 : {I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat) == I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Blocked{None{}}, Nil{}, g}, seat) : List<&2, S.JamOption>} = jamfor.slots(w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], S.Blocked{None{}}, Nil{}, g, owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{}), seat)
      +e1 : {I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Blocked{None{}}, Nil{}, g}, seat) == I.jam.for(Rec(w, p, g), seat) : List<&2, S.JamOption>} = jamfor.slots(w, p, S.Blocked{None{}}, Nil{}, S.Blocked{None{}}, Nil{}, g, seat, I.slots.put(I.seat.slots(p, seat), adr, None{}), seat)
      +mj2 : In(S.JamOption, S.JamAt{t}, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat)) = in.cast(S.JamOption, S.JamAt{t}, I.jam.for(Rec(w, p, g), seat), I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat), Equal.sym(List<&2, S.JamOption>, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat), I.jam.for(Rec(w, p, g), seat), Equal.trans(List<&2, S.JamOption>, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), owner), slot, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, owner, slot, D.Jammer{}}}], g}, seat), I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Blocked{None{}}, Nil{}, g}, seat), I.jam.for(Rec(w, p, g), seat), e2, e1)), mj)
      case.sj.mid(w, p, l, g, seat, seated, adr, owner, slot, t, mj2, k, enth, menu.step(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Uses(w, p, g, seat)), D.UseItem{adr, D.Adrenaline{}}, k, seated, efind), stl.find(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), S.Pick{owner, slot, D.Jammer{}}, mk1))

def case.sj(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), +adr: D.Slot, +owner: D.Seat, +slot: D.Slot, +t: D.Seat, mu: In(S.IdleOption, S.UseAt{adr, D.Adrenaline{}}, S.TakeGun{} <> Uses(w, p, g, seat)), mk: In(S.StealOption, S.Pick{owner, slot, D.Jammer{}}, I.steal.for(Rec(w, p, g), seat)), mj: In(S.JamOption, S.JamAt{t}, I.jam.for(Rec(w, p, g), seat))) -> IdleGoal(w, p, l, g, seat, Some{T.StealJamWith{adr, owner, slot, t}}):
  case.sj.found(w, p, l, g, seat, seated, adr, owner, slot, t, opt.find(S.TakeGun{} <> Uses(w, p, g, seat), S.UseAt{adr, D.Adrenaline{}}, mu), mk, mj)

def case.opt(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Seated(S.world.table(w), seat), o: T.IdleOption, legal: Legal(G.aim.targets(p), S.TakeGun{} <> Uses(w, p, g, seat), I.jam.for(Rec(w, p, g), seat), I.steal.for(Rec(w, p, g), seat), o)) -> IdleGoal(w, p, l, g, seat, Some{o}):
  match o legal:
    case T.ShootAt{+t} mem:
      case.shoot(w, p, l, g, seat, seated, t, mem)
    case T.UseSlot{+slot, +item} Tuple{m, plain}:
      case.use(w, p, l, g, seat, seated, slot, item, plain, opt.find(S.TakeGun{} <> Uses(w, p, g, seat), S.UseAt{slot, item}, m))
    case T.JamWith{+slot, +t} Tuple{mu, mj}:
      case.jam(w, p, l, g, seat, seated, slot, t, mu, mj)
    case T.StealWith{+adr, +owner, +slot, +item} Tuple{mu, Tuple{mk, plain}}:
      case.steal(w, p, l, g, seat, seated, adr, owner, slot, item, mu, mk, plain)
    case T.StealJamWith{+adr, +owner, +slot, +t} Tuple{mu, Tuple{mk, mj}}:
      case.sj(w, p, l, g, seat, seated, adr, owner, slot, t, mu, mk, mj)

def idle.picked(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +n: Nat, +seated: Seated(S.world.table(w), seat), +opts: List<&2, T.IdleOption>, +c: Nat, +eo: {P.options(T.State{w, p, T.Idle{seat}, l, g}, seat) == opts : List<&2, T.IdleOption>}, picked: Picked(G.aim.targets(p), S.TakeGun{} <> Uses(w, p, g, seat), I.jam.for(Rec(w, p, g), seat), I.steal.for(Rec(w, p, g), seat), opts, c)) -> IdleGoal(w, p, l, g, seat, P.option.nth(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), c)):
  match picked:
    case Tuple{+x, Tuple{+enth, +lx}}:
      %Equal.sym(List<&2, T.IdleOption>, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), opts, eo) : IdleGoal(w, p, l, g, seat, P.option.nth(_, c))
      %Equal.sym(Maybe<&2, T.IdleOption>, P.option.nth(opts, c), Some{x}, enth) : IdleGoal(w, p, l, g, seat, _)
      case.opt(w, p, l, g, seat, seated, x, lx)

def idle.req(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +n: Nat, sd: Bool, +esd: {P.seated(D.ring.get(Bool, D.ring.fill(Bool, S.world.table(w), True{}), seat)) == sd : Bool}, opts: List<&2, T.IdleOption>, +eo: {P.options(T.State{w, p, T.Idle{seat}, l, g}, seat) == opts : List<&2, T.IdleOption>}, all: All(G.aim.targets(p), S.TakeGun{} <> Uses(w, p, g, seat), I.jam.for(Rec(w, p, g), seat), I.steal.for(Rec(w, p, g), seat), opts)) -> {SA.walk(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.chain.rest(T.State{w, p, T.Idle{seat}, l, g}, SA.chain.first(T.State{w, p, T.Idle{seat}, l, g}, n, P.idle.request(sd, seat, P.moves(opts))), SA.walk.go(SA.chain.first(T.State{w, p, T.Idle{seat}, l, g}, n, P.idle.request(sd, seat, P.moves(opts))), SA.embed(T.State{w, p, T.Idle{seat}, l, g})))) == SA.lift(N.answer.idle(T.State{w, p, T.Idle{seat}, l, g}, seat, sd, opts, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match sd opts:
    case False{} opts:
      {==}
    case True{} Nil{}:
      {==}
    case True{} +o <> +os:
      %eo : {SA.walk(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.chain.rest(T.State{w, p, T.Idle{seat}, l, g}, SA.chain.first(T.State{w, p, T.Idle{seat}, l, g}, n, P.idle.request(True{}, seat, P.moves(o <> os))), SA.walk.go(SA.chain.first(T.State{w, p, T.Idle{seat}, l, g}, n, P.idle.request(True{}, seat, P.moves(o <> os))), SA.embed(T.State{w, p, T.Idle{seat}, l, g})))) == SA.lift(T.state.stepped(N.pickup.selected(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, P.option.nth(_, D.clamp(n, List.length(&2, T.Move, P.moves(os))))))) : Maybe<&2, D.Stepped<&2, S.State>>}
      idle.picked(w, p, l, g, seat, n, esd, o <> os, D.clamp(n, List.length(&2, T.Move, P.moves(os))), eo, pick.at(os, n, o, G.aim.targets(p), S.TakeGun{} <> Uses(w, p, g, seat), I.jam.for(Rec(w, p, g), seat), I.steal.for(Rec(w, p, g), seat), all))

def idle.case(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +n: Nat) -> {SA.walk(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.chain(T.State{w, p, T.Idle{seat}, l, g}, n)) == SA.lift(N.answer(T.State{w, p, T.Idle{seat}, l, g}, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  idle.req(w, p, l, g, seat, n, P.seated(D.ring.get(Bool, D.ring.fill(Bool, S.world.table(w), True{}), seat)), {==}, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), {==}, options.all(w, p, T.Idle{seat}, l, g, seat))

# simple_refines: every simple answer is sm walking its chain.
def refines(+s: T.State, +n: Nat) -> {SA.walk(SA.embed(s), SA.chain(s, n)) == SA.lift(N.answer(s, n)) : Maybe<&2, D.Stepped<&2, S.State>>}:
  match s:
    case T.State{+w, +p, +ph, +l, +g}:
      match ph:
        case T.NeedFirst{}:
          Rf.draw.first(w, p, l, g, n)
        case T.NeedHealth{}:
          Rf.draw.health(w, p, l, g, n)
        case T.NeedAmount{}:
          Rf.draw.amount(w, p, l, g, n)
        case T.NeedBatch{}:
          Rf.draw.batch(w, p, l, g, n)
        case T.NeedSwap{+load, +shells, +i}:
          Rf.draw.swap(w, p, l, g, n, load, shells, i)
        case T.Idle{+seat}:
          idle.case(w, p, l, g, seat, n)
        case T.Ended{}:
          {==}
        case T.Blocked{holder}:
          {==}
        case T.Stalled{}:
          {==}
        case T.NeedTurnAmount{+from, +passing, +winner}:
          Rf.draw.turn(w, p, l, g, n, from, passing, winner)
        case T.NeedItem{+seat, +f1, +f2, +rest}:
          Rf.draw.item(w, p, l, g, n, seat, f1, f2, rest)
        case T.NeedPhone{+seat, +owner, +slot}:
          Rf.draw.phone(w, p, l, g, n, seat, owner, slot)
