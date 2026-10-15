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

# simple_complete: a legal player gesture from an Idle point that uses first
# slots is a simple move's chain, or its start.

def LegalInv(+table: D.Table, +seat: D.Seat, +ms: List<&2, D.Move>, +s2: D.Seat, +mv: D.Move) -> Data:
  Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(ms, mv) == Some{k} : Maybe<&2, Nat>}, e0 => Sigma<&2, &2, {s2 == seat : D.Seat}, e1 => Id.Seated(table, seat)>>>

def legal.hit(+seat: D.Seat, +m: D.Move, +ms2: List<&2, D.Move>, +mv: D.Move, +n: Nat, r: Maybe<&2, Nat>, +er: {D.menu.find(m <> ms2, mv) == r : Maybe<&2, Nat>}, e: {SA.walk.index(D.Prompt{seat, 0n, D.NonEmpty{m, ms2}}, r) == Some{n} : Maybe<&2, Nat>}) -> Sigma<&2, &2, Nat, k => {D.menu.find(m <> ms2, mv) == Some{k} : Maybe<&2, Nat>}>:
  match r:
    case None{}:
      Wk.absurd(Sigma<&2, &2, Nat, k => {D.menu.find(m <> ms2, mv) == Some{k} : Maybe<&2, Nat>}>, Wk.maybe.clash(Nat, n, e))
    case Some{+k}:
      (k, er)

def inv.pack(+table: D.Table, +seat: D.Seat, +ms: List<&2, D.Move>, +mv: D.Move, hit: Sigma<&2, &2, Nat, k => {D.menu.find(ms, mv) == Some{k} : Maybe<&2, Nat>}>) -> Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(ms, mv) == Some{k} : Maybe<&2, Nat>}, e0 => Sigma<&2, &2, {seat == seat : D.Seat}, e1 => {True{} == True{} : Bool}>>>:
  match hit:
    case Tuple{+k, +ek}:
      (k, (ek, ({==}, {==})))

# A choice step sm accepts at a one-seat menu is that seat's, and its move is
# in the menu.
def legal.inv(table: D.Table, seat: D.Seat, s2: D.Seat, ms: List<&2, D.Move>, +mv: D.Move, +n: Nat, e: {SA.walk.legal(G.seat.menu(table, seat, ms), SA.ChoiceStep{s2, mv}) == Some{n} : Maybe<&2, Nat>}) -> LegalInv(table, seat, ms, s2, mv):
  match table seat s2 ms:
    case D.TwoSeats{} D.Seat0{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat0{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat0{} D.Seat0{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat0{}, m <> ms2, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat0{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat0{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat0{} D.Seat1{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat0{}, m <> ms2, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat0{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat0{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat0{} D.Seat2{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat0{}, m <> ms2, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat0{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat0{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat0{} D.Seat3{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat0{}, m <> ms2, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat1{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat1{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat1{} D.Seat0{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat1{}, m <> ms2, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat1{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat1{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat1{} D.Seat1{} +m <> +ms2:
      inv.pack(D.TwoSeats{}, D.Seat1{}, m <> ms2, mv, legal.hit(D.Seat1{}, m, ms2, mv, n, D.menu.find(m <> ms2, mv), {==}, e))
    case D.TwoSeats{} D.Seat1{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat1{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat1{} D.Seat2{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat1{}, m <> ms2, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat1{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat1{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat1{} D.Seat3{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat1{}, m <> ms2, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat2{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat2{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat2{} D.Seat0{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat2{}, m <> ms2, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat2{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat2{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat2{} D.Seat1{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat2{}, m <> ms2, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat2{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat2{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat2{} D.Seat2{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat2{}, m <> ms2, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat2{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat2{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat2{} D.Seat3{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat2{}, m <> ms2, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat3{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat3{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat3{} D.Seat0{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat3{}, m <> ms2, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat3{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat3{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat3{} D.Seat1{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat3{}, m <> ms2, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat3{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat3{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat3{} D.Seat2{} +m <> +ms2:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat3{}, m <> ms2, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat3{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.TwoSeats{}, D.Seat3{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.TwoSeats{} D.Seat3{} D.Seat3{} +m <> +ms2:
      inv.pack(D.TwoSeats{}, D.Seat3{}, m <> ms2, mv, legal.hit(D.Seat3{}, m, ms2, mv, n, D.menu.find(m <> ms2, mv), {==}, e))
    case D.ThreeSeats{} D.Seat0{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat0{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat0{} D.Seat0{} +m <> +ms2:
      inv.pack(D.ThreeSeats{}, D.Seat0{}, m <> ms2, mv, legal.hit(D.Seat0{}, m, ms2, mv, n, D.menu.find(m <> ms2, mv), {==}, e))
    case D.ThreeSeats{} D.Seat0{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat0{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat0{} D.Seat1{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat0{}, m <> ms2, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat0{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat0{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat0{} D.Seat2{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat0{}, m <> ms2, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat0{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat0{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat0{} D.Seat3{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat0{}, m <> ms2, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat1{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat1{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat1{} D.Seat0{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat1{}, m <> ms2, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat1{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat1{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat1{} D.Seat1{} +m <> +ms2:
      inv.pack(D.ThreeSeats{}, D.Seat1{}, m <> ms2, mv, legal.hit(D.Seat1{}, m, ms2, mv, n, D.menu.find(m <> ms2, mv), {==}, e))
    case D.ThreeSeats{} D.Seat1{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat1{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat1{} D.Seat2{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat1{}, m <> ms2, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat1{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat1{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat1{} D.Seat3{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat1{}, m <> ms2, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat2{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat2{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat2{} D.Seat0{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat2{}, m <> ms2, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat2{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat2{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat2{} D.Seat1{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat2{}, m <> ms2, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat2{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat2{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat2{} D.Seat2{} +m <> +ms2:
      inv.pack(D.ThreeSeats{}, D.Seat2{}, m <> ms2, mv, legal.hit(D.Seat2{}, m, ms2, mv, n, D.menu.find(m <> ms2, mv), {==}, e))
    case D.ThreeSeats{} D.Seat2{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat2{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat2{} D.Seat3{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat2{}, m <> ms2, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat3{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat3{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat3{} D.Seat0{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat3{}, m <> ms2, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat3{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat3{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat3{} D.Seat1{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat3{}, m <> ms2, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat3{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat3{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat3{} D.Seat2{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat3{}, m <> ms2, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat3{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat3{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.ThreeSeats{} D.Seat3{} D.Seat3{} +m <> +ms2:
      Wk.absurd(LegalInv(D.ThreeSeats{}, D.Seat3{}, m <> ms2, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat0{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat0{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat0{} D.Seat0{} +m <> +ms2:
      inv.pack(D.FourSeats{}, D.Seat0{}, m <> ms2, mv, legal.hit(D.Seat0{}, m, ms2, mv, n, D.menu.find(m <> ms2, mv), {==}, e))
    case D.FourSeats{} D.Seat0{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat0{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat0{} D.Seat1{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat0{}, m <> ms2, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat0{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat0{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat0{} D.Seat2{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat0{}, m <> ms2, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat0{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat0{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat0{} D.Seat3{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat0{}, m <> ms2, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat1{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat1{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat1{} D.Seat0{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat1{}, m <> ms2, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat1{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat1{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat1{} D.Seat1{} +m <> +ms2:
      inv.pack(D.FourSeats{}, D.Seat1{}, m <> ms2, mv, legal.hit(D.Seat1{}, m, ms2, mv, n, D.menu.find(m <> ms2, mv), {==}, e))
    case D.FourSeats{} D.Seat1{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat1{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat1{} D.Seat2{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat1{}, m <> ms2, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat1{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat1{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat1{} D.Seat3{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat1{}, m <> ms2, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat2{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat2{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat2{} D.Seat0{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat2{}, m <> ms2, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat2{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat2{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat2{} D.Seat1{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat2{}, m <> ms2, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat2{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat2{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat2{} D.Seat2{} +m <> +ms2:
      inv.pack(D.FourSeats{}, D.Seat2{}, m <> ms2, mv, legal.hit(D.Seat2{}, m, ms2, mv, n, D.menu.find(m <> ms2, mv), {==}, e))
    case D.FourSeats{} D.Seat2{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat2{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat2{} D.Seat3{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat2{}, m <> ms2, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat3{} D.Seat0{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat3{}, Nil{}, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat3{} D.Seat0{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat3{}, m <> ms2, D.Seat0{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat3{} D.Seat1{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat3{}, Nil{}, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat3{} D.Seat1{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat3{}, m <> ms2, D.Seat1{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat3{} D.Seat2{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat3{}, Nil{}, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat3{} D.Seat2{} +m <> +ms2:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat3{}, m <> ms2, D.Seat2{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat3{} D.Seat3{} Nil{}:
      Wk.absurd(LegalInv(D.FourSeats{}, D.Seat3{}, Nil{}, D.Seat3{}, mv), Wk.maybe.clash(Nat, n, e))
    case D.FourSeats{} D.Seat3{} D.Seat3{} +m <> +ms2:
      inv.pack(D.FourSeats{}, D.Seat3{}, m <> ms2, mv, legal.hit(D.Seat3{}, m, ms2, mv, n, D.menu.find(m <> ms2, mv), {==}, e))

def tgt.Inv(+xs: List<&2, S.TargetOption>, +mv: D.Move, +k: Nat) -> Data:
  Sigma<&2, &2, S.TargetOption, o => Sigma<&2, &2, {G.target.nth(xs, k) == Some{o} : Maybe<&2, S.TargetOption>}, e0 => Sigma<&2, &2, {Id.tgt.mv(o) == mv : D.Move}, e1 => Id.In(S.TargetOption, o, xs)>>>

def tgt.inv.tail(+y: S.TargetOption, +ys: List<&2, S.TargetOption>, +mv: D.Move, +j: Nat, inv: tgt.Inv(ys, mv, j)) -> tgt.Inv(y <> ys, mv, 1n+j):
  match inv:
    case Tuple{+o, Tuple{+en, Tuple{+em, +mem}}}:
      (o, (en, (em, Inr{mem})))

def tgt.inv.cons(+y: S.TargetOption, +ys: List<&2, S.TargetOption>, +mv: D.Move, +k: Nat, b: Bool, +eb: {D.move.eq(Id.tgt.mv(y), mv) == b : Bool}, r: Maybe<&2, Nat>, +er: {D.menu.find(G.aim.moves(ys), mv) == r : Maybe<&2, Nat>}, found: {D.menu.find.here(b, r) == Some{k} : Maybe<&2, Nat>}, ih: @+j:Nat -> @e:{D.menu.find(G.aim.moves(ys), mv) == Some{j} : Maybe<&2, Nat>} -> tgt.Inv(ys, mv, j)) -> tgt.Inv(y <> ys, mv, k):
  match b r:
    case True{} r:
      %Wk.some.inj(Nat, 0n, k, found) : tgt.Inv(y <> ys, mv, _)
      (y, ({==}, (Id.move.eq.sound(Id.tgt.mv(y), mv, eb), Inl{{==}})))
    case False{} None{}:
      Wk.absurd(tgt.Inv(y <> ys, mv, k), Wk.maybe.clash(Nat, k, found))
    case False{} Some{+j}:
      %Wk.some.inj(Nat, 1n+j, k, found) : tgt.Inv(y <> ys, mv, _)
      tgt.inv.tail(y, ys, mv, j, ih(j, er))

def tgt.inv(xs: List<&2, S.TargetOption>, +mv: D.Move, +k: Nat, e: {D.menu.find(G.aim.moves(xs), mv) == Some{k} : Maybe<&2, Nat>}) -> tgt.Inv(xs, mv, k):
  match xs:
    case Nil{}:
      Wk.absurd(tgt.Inv(Nil{}, mv, k), Wk.maybe.clash(Nat, k, e))
    case +y <> +ys:
      +e2 : {D.menu.find(Id.tgt.mv(y) <> G.aim.moves(ys), mv) == Some{k} : Maybe<&2, Nat>} = Equal.trans(Maybe<&2, Nat>, D.menu.find(Id.tgt.mv(y) <> G.aim.moves(ys), mv), D.menu.find(G.aim.moves(y <> ys), mv), Some{k}, Equal.cong(List<&2, D.Move>, Maybe<&2, Nat>, z => D.menu.find(z, mv), Id.tgt.mv(y) <> G.aim.moves(ys), G.aim.moves(y <> ys), Equal.sym(List<&2, D.Move>, G.aim.moves(y <> ys), Id.tgt.mv(y) <> G.aim.moves(ys), Id.tgt.moves.cons(y, ys))), e)
      tgt.inv.cons(y, ys, mv, k, D.move.eq(Id.tgt.mv(y), mv), {==}, D.menu.find(G.aim.moves(ys), mv), {==}, e2, +j => e3 => tgt.inv(ys, mv, j, e3))

def opt.Inv(+xs: List<&2, S.IdleOption>, +mv: D.Move, +k: Nat) -> Data:
  Sigma<&2, &2, S.IdleOption, o => Sigma<&2, &2, {G.idle.nth(xs, k) == Some{o} : Maybe<&2, S.IdleOption>}, e0 => Sigma<&2, &2, {Id.opt.mv(o) == mv : D.Move}, e1 => Id.In(S.IdleOption, o, xs)>>>

def opt.inv.tail(+y: S.IdleOption, +ys: List<&2, S.IdleOption>, +mv: D.Move, +j: Nat, inv: opt.Inv(ys, mv, j)) -> opt.Inv(y <> ys, mv, 1n+j):
  match inv:
    case Tuple{+o, Tuple{+en, Tuple{+em, +mem}}}:
      (o, (en, (em, Inr{mem})))

def opt.inv.cons(+y: S.IdleOption, +ys: List<&2, S.IdleOption>, +mv: D.Move, +k: Nat, b: Bool, +eb: {D.move.eq(Id.opt.mv(y), mv) == b : Bool}, r: Maybe<&2, Nat>, +er: {D.menu.find(G.idle.moves(ys), mv) == r : Maybe<&2, Nat>}, found: {D.menu.find.here(b, r) == Some{k} : Maybe<&2, Nat>}, ih: @+j:Nat -> @e:{D.menu.find(G.idle.moves(ys), mv) == Some{j} : Maybe<&2, Nat>} -> opt.Inv(ys, mv, j)) -> opt.Inv(y <> ys, mv, k):
  match b r:
    case True{} r:
      %Wk.some.inj(Nat, 0n, k, found) : opt.Inv(y <> ys, mv, _)
      (y, ({==}, (Id.move.eq.sound(Id.opt.mv(y), mv, eb), Inl{{==}})))
    case False{} None{}:
      Wk.absurd(opt.Inv(y <> ys, mv, k), Wk.maybe.clash(Nat, k, found))
    case False{} Some{+j}:
      %Wk.some.inj(Nat, 1n+j, k, found) : opt.Inv(y <> ys, mv, _)
      opt.inv.tail(y, ys, mv, j, ih(j, er))

def opt.inv(xs: List<&2, S.IdleOption>, +mv: D.Move, +k: Nat, e: {D.menu.find(G.idle.moves(xs), mv) == Some{k} : Maybe<&2, Nat>}) -> opt.Inv(xs, mv, k):
  match xs:
    case Nil{}:
      Wk.absurd(opt.Inv(Nil{}, mv, k), Wk.maybe.clash(Nat, k, e))
    case +y <> +ys:
      +e2 : {D.menu.find(Id.opt.mv(y) <> G.idle.moves(ys), mv) == Some{k} : Maybe<&2, Nat>} = Equal.trans(Maybe<&2, Nat>, D.menu.find(Id.opt.mv(y) <> G.idle.moves(ys), mv), D.menu.find(G.idle.moves(y <> ys), mv), Some{k}, Equal.cong(List<&2, D.Move>, Maybe<&2, Nat>, z => D.menu.find(z, mv), Id.opt.mv(y) <> G.idle.moves(ys), G.idle.moves(y <> ys), Equal.sym(List<&2, D.Move>, G.idle.moves(y <> ys), Id.opt.mv(y) <> G.idle.moves(ys), Id.opt.moves.cons(y, ys))), e)
      opt.inv.cons(y, ys, mv, k, D.move.eq(Id.opt.mv(y), mv), {==}, D.menu.find(G.idle.moves(ys), mv), {==}, e2, +j => e3 => opt.inv(ys, mv, j, e3))

def jmo.Inv(+xs: List<&2, S.JamOption>, +mv: D.Move, +k: Nat) -> Data:
  Sigma<&2, &2, S.JamOption, o => Sigma<&2, &2, {I.jam.nth(xs, k) == Some{o} : Maybe<&2, S.JamOption>}, e0 => Sigma<&2, &2, {Id.jmo.mv(o) == mv : D.Move}, e1 => Id.In(S.JamOption, o, xs)>>>

def jmo.inv.tail(+y: S.JamOption, +ys: List<&2, S.JamOption>, +mv: D.Move, +j: Nat, inv: jmo.Inv(ys, mv, j)) -> jmo.Inv(y <> ys, mv, 1n+j):
  match inv:
    case Tuple{+o, Tuple{+en, Tuple{+em, +mem}}}:
      (o, (en, (em, Inr{mem})))

def jmo.inv.cons(+y: S.JamOption, +ys: List<&2, S.JamOption>, +mv: D.Move, +k: Nat, b: Bool, +eb: {D.move.eq(Id.jmo.mv(y), mv) == b : Bool}, r: Maybe<&2, Nat>, +er: {D.menu.find(I.jam.moves(ys), mv) == r : Maybe<&2, Nat>}, found: {D.menu.find.here(b, r) == Some{k} : Maybe<&2, Nat>}, ih: @+j:Nat -> @e:{D.menu.find(I.jam.moves(ys), mv) == Some{j} : Maybe<&2, Nat>} -> jmo.Inv(ys, mv, j)) -> jmo.Inv(y <> ys, mv, k):
  match b r:
    case True{} r:
      %Wk.some.inj(Nat, 0n, k, found) : jmo.Inv(y <> ys, mv, _)
      (y, ({==}, (Id.move.eq.sound(Id.jmo.mv(y), mv, eb), Inl{{==}})))
    case False{} None{}:
      Wk.absurd(jmo.Inv(y <> ys, mv, k), Wk.maybe.clash(Nat, k, found))
    case False{} Some{+j}:
      %Wk.some.inj(Nat, 1n+j, k, found) : jmo.Inv(y <> ys, mv, _)
      jmo.inv.tail(y, ys, mv, j, ih(j, er))

def jmo.inv(xs: List<&2, S.JamOption>, +mv: D.Move, +k: Nat, e: {D.menu.find(I.jam.moves(xs), mv) == Some{k} : Maybe<&2, Nat>}) -> jmo.Inv(xs, mv, k):
  match xs:
    case Nil{}:
      Wk.absurd(jmo.Inv(Nil{}, mv, k), Wk.maybe.clash(Nat, k, e))
    case +y <> +ys:
      +e2 : {D.menu.find(Id.jmo.mv(y) <> I.jam.moves(ys), mv) == Some{k} : Maybe<&2, Nat>} = Equal.trans(Maybe<&2, Nat>, D.menu.find(Id.jmo.mv(y) <> I.jam.moves(ys), mv), D.menu.find(I.jam.moves(y <> ys), mv), Some{k}, Equal.cong(List<&2, D.Move>, Maybe<&2, Nat>, z => D.menu.find(z, mv), Id.jmo.mv(y) <> I.jam.moves(ys), I.jam.moves(y <> ys), Equal.sym(List<&2, D.Move>, I.jam.moves(y <> ys), Id.jmo.mv(y) <> I.jam.moves(ys), Id.jmo.moves.cons(y, ys))), e)
      jmo.inv.cons(y, ys, mv, k, D.move.eq(Id.jmo.mv(y), mv), {==}, D.menu.find(I.jam.moves(ys), mv), {==}, e2, +j => e3 => jmo.inv(ys, mv, j, e3))

def stl.Inv(+xs: List<&2, S.StealOption>, +mv: D.Move, +k: Nat) -> Data:
  Sigma<&2, &2, S.StealOption, o => Sigma<&2, &2, {I.steal.nth(xs, k) == Some{o} : Maybe<&2, S.StealOption>}, e0 => Sigma<&2, &2, {Id.stl.mv(o) == mv : D.Move}, e1 => Id.In(S.StealOption, o, xs)>>>

def stl.inv.tail(+y: S.StealOption, +ys: List<&2, S.StealOption>, +mv: D.Move, +j: Nat, inv: stl.Inv(ys, mv, j)) -> stl.Inv(y <> ys, mv, 1n+j):
  match inv:
    case Tuple{+o, Tuple{+en, Tuple{+em, +mem}}}:
      (o, (en, (em, Inr{mem})))

def stl.inv.cons(+y: S.StealOption, +ys: List<&2, S.StealOption>, +mv: D.Move, +k: Nat, b: Bool, +eb: {D.move.eq(Id.stl.mv(y), mv) == b : Bool}, r: Maybe<&2, Nat>, +er: {D.menu.find(I.steal.moves(ys), mv) == r : Maybe<&2, Nat>}, found: {D.menu.find.here(b, r) == Some{k} : Maybe<&2, Nat>}, ih: @+j:Nat -> @e:{D.menu.find(I.steal.moves(ys), mv) == Some{j} : Maybe<&2, Nat>} -> stl.Inv(ys, mv, j)) -> stl.Inv(y <> ys, mv, k):
  match b r:
    case True{} r:
      %Wk.some.inj(Nat, 0n, k, found) : stl.Inv(y <> ys, mv, _)
      (y, ({==}, (Id.move.eq.sound(Id.stl.mv(y), mv, eb), Inl{{==}})))
    case False{} None{}:
      Wk.absurd(stl.Inv(y <> ys, mv, k), Wk.maybe.clash(Nat, k, found))
    case False{} Some{+j}:
      %Wk.some.inj(Nat, 1n+j, k, found) : stl.Inv(y <> ys, mv, _)
      stl.inv.tail(y, ys, mv, j, ih(j, er))

def stl.inv(xs: List<&2, S.StealOption>, +mv: D.Move, +k: Nat, e: {D.menu.find(I.steal.moves(xs), mv) == Some{k} : Maybe<&2, Nat>}) -> stl.Inv(xs, mv, k):
  match xs:
    case Nil{}:
      Wk.absurd(stl.Inv(Nil{}, mv, k), Wk.maybe.clash(Nat, k, e))
    case +y <> +ys:
      +e2 : {D.menu.find(Id.stl.mv(y) <> I.steal.moves(ys), mv) == Some{k} : Maybe<&2, Nat>} = Equal.trans(Maybe<&2, Nat>, D.menu.find(Id.stl.mv(y) <> I.steal.moves(ys), mv), D.menu.find(I.steal.moves(y <> ys), mv), Some{k}, Equal.cong(List<&2, D.Move>, Maybe<&2, Nat>, z => D.menu.find(z, mv), Id.stl.mv(y) <> I.steal.moves(ys), I.steal.moves(y <> ys), Equal.sym(List<&2, D.Move>, I.steal.moves(y <> ys), Id.stl.mv(y) <> I.steal.moves(ys), Id.stl.moves.cons(y, ys))), e)
      stl.inv.cons(y, ys, mv, k, D.move.eq(Id.stl.mv(y), mv), {==}, D.menu.find(I.steal.moves(ys), mv), {==}, e2, +j => e3 => stl.inv(ys, mv, j, e3))

def draw.notlegal(table: D.Table, seat: D.Seat, ms: List<&2, D.Move>, +a: Nat, +n: Nat, e: {SA.walk.legal(G.seat.menu(table, seat, ms), SA.DrawStep{a}) == Some{n} : Maybe<&2, Nat>}) -> Empty:
  match table seat ms:
    case D.TwoSeats{} D.Seat0{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.TwoSeats{} D.Seat0{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.TwoSeats{} D.Seat1{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.TwoSeats{} D.Seat1{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.TwoSeats{} D.Seat2{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.TwoSeats{} D.Seat2{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.TwoSeats{} D.Seat3{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.TwoSeats{} D.Seat3{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.ThreeSeats{} D.Seat0{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.ThreeSeats{} D.Seat0{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.ThreeSeats{} D.Seat1{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.ThreeSeats{} D.Seat1{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.ThreeSeats{} D.Seat2{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.ThreeSeats{} D.Seat2{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.ThreeSeats{} D.Seat3{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.ThreeSeats{} D.Seat3{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.FourSeats{} D.Seat0{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.FourSeats{} D.Seat0{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.FourSeats{} D.Seat1{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.FourSeats{} D.Seat1{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.FourSeats{} D.Seat2{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.FourSeats{} D.Seat2{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)
    case D.FourSeats{} D.Seat3{} Nil{}:
      Wk.maybe.clash(Nat, n, e)
    case D.FourSeats{} D.Seat3{} m <> ms2:
      Wk.maybe.clash(Nat, n, e)

def ChooseStep(+table: D.Table, +seat: D.Seat, +ms: List<&2, D.Move>, +s2: D.Seat, +mv: D.Move, +n: Nat) -> Data:
  Sigma<&2, &2, Nat, k => Sigma<&2, &2, {D.menu.find(ms, mv) == Some{k} : Maybe<&2, Nat>}, e0 => Sigma<&2, &2, {s2 == seat : D.Seat}, e1 => Sigma<&2, &2, Id.Seated(table, seat), e2 => {D.resolve(G.seat.menu(table, seat, ms), n) == D.Chose{D.Choice{seat, k, mv}} : D.Resolved}>>>>

def choose.fix(+table: D.Table, +seat: D.Seat, +ms: List<&2, D.Move>, +mv: D.Move, +n: Nat, +k: Nat, +ek: {D.menu.find(ms, mv) == Some{k} : Maybe<&2, Nat>}, +seated: Id.Seated(table, seat), +e: {SA.walk.legal(G.seat.menu(table, seat, ms), SA.ChoiceStep{seat, mv}) == Some{n} : Maybe<&2, Nat>}, step: Id.MenuStep(table, seat, ms, mv, k)) -> ChooseStep(table, seat, ms, seat, mv, n):
  match step:
    case Tuple{+n2, Tuple{+legal2, +res2}}:
      +en : {n2 == n : Nat} = Wk.some.inj(Nat, n2, n, Equal.trans(Maybe<&2, Nat>, Some{n2}, SA.walk.legal(G.seat.menu(table, seat, ms), SA.ChoiceStep{seat, mv}), Some{n}, Equal.sym(Maybe<&2, Nat>, SA.walk.legal(G.seat.menu(table, seat, ms), SA.ChoiceStep{seat, mv}), Some{n2}, legal2), e))
      (k, (ek, ({==}, (seated, Equal.trans(D.Resolved, D.resolve(G.seat.menu(table, seat, ms), n), D.resolve(G.seat.menu(table, seat, ms), n2), D.Chose{D.Choice{seat, k, mv}}, Equal.cong(Nat, D.Resolved, v => D.resolve(G.seat.menu(table, seat, ms), v), n, n2, Equal.sym(Nat, n2, n, en)), res2)))))

def choose.inv(+table: D.Table, +seat: D.Seat, +ms: List<&2, D.Move>, +s2: D.Seat, +mv: D.Move, +n: Nat, +e: {SA.walk.legal(G.seat.menu(table, seat, ms), SA.ChoiceStep{s2, mv}) == Some{n} : Maybe<&2, Nat>}, inv: LegalInv(table, seat, ms, s2, mv)) -> ChooseStep(table, seat, ms, s2, mv, n):
  match inv:
    case Tuple{+k, Tuple{+ek, Tuple{+es, +seated}}}:
      %Equal.sym(D.Seat, s2, seat, es) : ChooseStep(table, seat, ms, _, mv, n)
      choose.fix(table, seat, ms, mv, n, k, ek, seated, Equal.trans(Maybe<&2, Nat>, SA.walk.legal(G.seat.menu(table, seat, ms), SA.ChoiceStep{seat, mv}), SA.walk.legal(G.seat.menu(table, seat, ms), SA.ChoiceStep{s2, mv}), Some{n}, Equal.cong(D.Seat, Maybe<&2, Nat>, x => SA.walk.legal(G.seat.menu(table, seat, ms), SA.ChoiceStep{x, mv}), seat, s2, Equal.sym(D.Seat, s2, seat, es)), e), Id.menu.step(table, seat, ms, mv, k, seated, ek))

def choose.step(+table: D.Table, +seat: D.Seat, +ms: List<&2, D.Move>, +s2: D.Seat, +mv: D.Move, +n: Nat, +e: {SA.walk.legal(G.seat.menu(table, seat, ms), SA.ChoiceStep{s2, mv}) == Some{n} : Maybe<&2, Nat>}) -> ChooseStep(table, seat, ms, s2, mv, n):
  choose.inv(table, seat, ms, s2, mv, n, e, legal.inv(table, seat, s2, ms, mv, n, e))

def embed.notpick(+u: T.State) -> {SA.pick.phase(S.state.phase(SA.embed(u))) == False{} : Bool}:
  match u:
    case T.State{w, p, ph, l, g}:
      match ph:
        case T.NeedFirst{}:
          {==}
        case T.NeedHealth{}:
          {==}
        case T.NeedAmount{}:
          {==}
        case T.NeedBatch{}:
          {==}
        case T.NeedSwap{a, b, c}:
          {==}
        case T.Idle{a}:
          {==}
        case T.Ended{}:
          {==}
        case T.Blocked{a}:
          {==}
        case T.Stalled{}:
          {==}
        case T.NeedTurnAmount{a, b, c}:
          {==}
        case T.NeedItem{a, b, c, d}:
          {==}
        case T.NeedPhone{a, b, c}:
          {==}

def rel.notpick(+u: T.State, +y: S.State, rel: C.Rel(u, y)) -> {SA.pick.phase(S.state.phase(y)) == False{} : Bool}:
  match rel:
    case Inl{Tuple{+ey, _}}:
      %Equal.sym(S.State, y, SA.embed(u), ey) : {SA.pick.phase(S.state.phase(_)) == False{} : Bool}
      embed.notpick(u)
    case Inr{Tuple{+m, Tuple{+ey, _}}}:
      %Equal.sym(S.State, y, SA.embed(T.state.set_phase(m, T.Stalled{})), ey) : {SA.pick.phase(S.state.phase(_)) == False{} : Bool}
      embed.notpick(T.state.set_phase(m, T.Stalled{}))

# Every Idle option uses first slots: its item's first slot among the uses,
# and a steal's owner's first slot holding the item among the picks.

def bool.clash2(e: {True{} == False{} : Bool}) -> Empty:
  Wk.bool.clash(Equal.sym(Bool, True{}, False{}, e))

def not.true(+b: Bool, e: {Bool.not(b) == True{} : Bool}) -> {b == False{} : Bool}:
  match b:
    case True{}:
      Wk.absurd({True{} == False{} : Bool}, Wk.bool.clash(e))
    case False{}:
      {==}

def or.false.l(+a: Bool, +b: Bool, e: {Bool.or(a, b) == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case True{}:
      Wk.absurd({True{} == False{} : Bool}, bool.clash2(e))
    case False{}:
      {==}

def or.false.r(+a: Bool, +b: Bool, e: {Bool.or(a, b) == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case True{}:
      Wk.absurd({b == False{} : Bool}, bool.clash2(e))
    case False{}:
      e

def Canon(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, o: T.IdleOption) -> Data:
  match o:
    case T.ShootAt{t}:
      Unit
    case T.UseSlot{s, i}:
      {P.use.first(us, i) == Some{s} : Maybe<&2, D.Slot>}
    case T.JamWith{s, t}:
      {P.use.first(us, D.Jammer{}) == Some{s} : Maybe<&2, D.Slot>}
    case T.StealWith{a, ow, s, i}:
      Sigma<&2, &2, {P.use.first(us, D.Adrenaline{}) == Some{a} : Maybe<&2, D.Slot>}, e0 => {SA.steal.first(ks, ow, i) == Some{s} : Maybe<&2, D.Slot>}>
    case T.StealJamWith{a, ow, s, t}:
      Sigma<&2, &2, {P.use.first(us, D.Adrenaline{}) == Some{a} : Maybe<&2, D.Slot>}, e0 => {SA.steal.first(ks, ow, D.Jammer{}) == Some{s} : Maybe<&2, D.Slot>}>

def CAll(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, xs: List<&2, T.IdleOption>) -> Data:
  match xs:
    case Nil{}:
      Unit
    case x <> rest:
      Sigma<&2, &2, Canon(us, ks, x), e0 => CAll(us, ks, rest)>

def call.append(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, +xs: List<&2, T.IdleOption>, +ys: List<&2, T.IdleOption>, ax: CAll(us, ks, xs), ay: CAll(us, ks, ys)) -> CAll(us, ks, List.append(&2, T.IdleOption, xs, ys)):
  match xs ax:
    case Nil{} _:
      ay
    case +x <> +rest Tuple{+cx, +arest}:
      (cx, call.append(us, ks, rest, ys, arest, ay))

def call.shots(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, ts: List<&2, S.TargetOption>) -> CAll(us, ks, P.shots(ts)):
  match ts:
    case Nil{}:
      Unit{}
    case S.Target{t} <> rest:
      (Unit{}, call.shots(us, ks, rest))

def UC(+xs: List<&2, S.IdleOption>, +seen: List<&2, D.Item>, o: T.IdleOption) -> Data:
  match o:
    case T.UseSlot{s, i}:
      Sigma<&2, &2, {P.items.has(seen, i) == False{} : Bool}, e0 => {P.use.first(xs, i) == Some{s} : Maybe<&2, D.Slot>}>
    case _:
      Empty

def UCAll(+xs: List<&2, S.IdleOption>, +seen: List<&2, D.Item>, os: List<&2, T.IdleOption>) -> Data:
  match os:
    case Nil{}:
      Unit
    case o <> rest:
      Sigma<&2, &2, UC(xs, seen, o), e0 => UCAll(xs, seen, rest)>

def uc.skip(+rest: List<&2, S.IdleOption>, +seen: List<&2, D.Item>, os: List<&2, T.IdleOption>, a: UCAll(rest, seen, os)) -> UCAll(S.TakeGun{} <> rest, seen, os):
  match os a:
    case Nil{} _:
      Unit{}
    case T.UseSlot{+s, +i} <> +more Tuple{+c, +am}:
      (c, uc.skip(rest, seen, more, am))
    case T.ShootAt{t} <> more Tuple{c, am}:
      match c:
    case T.JamWith{s, t} <> more Tuple{c, am}:
      match c:
    case T.StealWith{x, y, z, v} <> more Tuple{c, am}:
      match c:
    case T.StealJamWith{x, y, z, v} <> more Tuple{c, am}:
      match c:


def uc.weaken(+s0: D.Slot, +i0: D.Item, +rest: List<&2, S.IdleOption>, +seen: List<&2, D.Item>, os: List<&2, T.IdleOption>, a: UCAll(rest, i0 <> seen, os)) -> UCAll(S.UseAt{s0, i0} <> rest, seen, os):
  match os a:
    case Nil{} _:
      Unit{}
    case T.UseSlot{+s, +i} <> +more Tuple{Tuple{+h, +f}, +am}:
      +el : {D.item.eq(i0, i) == False{} : Bool} = or.false.l(D.item.eq(i0, i), P.items.has(seen, i), h)
      +f2 : {P.use.first(S.UseAt{s0, i0} <> rest, i) == Some{s} : Maybe<&2, D.Slot>} = Equal.trans(Maybe<&2, D.Slot>, Bool.pick(Maybe<&2, D.Slot>, D.item.eq(i0, i), Some{s0}, P.use.first(rest, i)), Bool.pick(Maybe<&2, D.Slot>, False{}, Some{s0}, P.use.first(rest, i)), Some{s}, Id.pick.eq(D.item.eq(i0, i), False{}, el, Some{s0}, P.use.first(rest, i)), f)
      ((or.false.r(D.item.eq(i0, i), P.items.has(seen, i), h), f2), uc.weaken(s0, i0, rest, seen, more, am))
    case T.ShootAt{t} <> more Tuple{c, am}:
      match c:
    case T.JamWith{s, t} <> more Tuple{c, am}:
      match c:
    case T.StealWith{x, y, z, v} <> more Tuple{c, am}:
      match c:
    case T.StealJamWith{x, y, z, v} <> more Tuple{c, am}:
      match c:

def uc.cell(+s0: D.Slot, +i0: D.Item, +rest: List<&2, S.IdleOption>, +seen: List<&2, D.Item>, b: Bool, +eb: {Bool.not(Bool.or(P.item.chained(i0), P.items.has(seen, i0))) == b : Bool}, +tail: List<&2, T.IdleOption>, at: UCAll(S.UseAt{s0, i0} <> rest, seen, tail)) -> UCAll(S.UseAt{s0, i0} <> rest, seen, I.keep(T.IdleOption, b, T.UseSlot{s0, i0}, tail)):
  match b:
    case True{}:
      +eo : {Bool.or(P.item.chained(i0), P.items.has(seen, i0)) == False{} : Bool} = not.true(Bool.or(P.item.chained(i0), P.items.has(seen, i0)), eb)
      +f : {P.use.first(S.UseAt{s0, i0} <> rest, i0) == Some{s0} : Maybe<&2, D.Slot>} = Id.pick.eq(D.item.eq(i0, i0), True{}, Wk.item.eq.refl(i0), Some{s0}, P.use.first(rest, i0))
      ((or.false.r(P.item.chained(i0), P.items.has(seen, i0), eo), f), at)
    case False{}:
      at

def uc.all(xs: List<&2, S.IdleOption>, +seen: List<&2, D.Item>) -> UCAll(xs, seen, P.use.options(xs, seen)):
  match xs:
    case Nil{}:
      Unit{}
    case S.UseAt{+s0, +i0} <> +rest:
      +tail : List<&2, T.IdleOption> = P.use.options(rest, i0 <> seen)
      uc.cell(s0, i0, rest, seen, Bool.not(Bool.or(P.item.chained(i0), P.items.has(seen, i0))), {==}, tail, uc.weaken(s0, i0, rest, seen, tail, uc.all(rest, i0 <> seen)))
    case S.TakeGun{} <> +rest:
      uc.skip(rest, seen, P.use.options(rest, seen), uc.all(rest, seen))

def uc.map(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, os: List<&2, T.IdleOption>, a: UCAll(us, Nil{}, os)) -> CAll(us, ks, os):
  match os a:
    case Nil{} _:
      Unit{}
    case T.UseSlot{+s, +i} <> +more Tuple{Tuple{h, +f}, +am}:
      (f, uc.map(us, ks, more, am))
    case T.ShootAt{t} <> more Tuple{c, am}:
      match c:
    case T.JamWith{s, t} <> more Tuple{c, am}:
      match c:
    case T.StealWith{x, y, z, v} <> more Tuple{c, am}:
      match c:
    case T.StealJamWith{x, y, z, v} <> more Tuple{c, am}:
      match c:

def and.tt(+a: Bool, +b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {Bool.and(a, b) == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, ea) : {Bool.and(_, b) == True{} : Bool}
  eb

def and.ff.r(+a: Bool, +b: Bool, eb: {b == False{} : Bool}) -> {Bool.and(a, b) == False{} : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      eb

def and.ff.l(+a: Bool, +b: Bool, ea: {a == False{} : Bool}) -> {Bool.and(a, b) == False{} : Bool}:
  %Equal.sym(Bool, a, False{}, ea) : {Bool.and(_, b) == False{} : Bool}
  {==}

def first.hit(+o0: D.Seat, +s0: D.Slot, +i0: D.Item, +rest: List<&2, S.StealOption>, +ow: D.Seat, +i: D.Item, e: {Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, i)) == True{} : Bool}) -> {SA.steal.first(S.Pick{o0, s0, i0} <> rest, ow, i) == Some{s0} : Maybe<&2, D.Slot>}:
  Id.pick.eq(Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, i)), True{}, e, Some{s0}, SA.steal.first(rest, ow, i))

def first.miss(+o0: D.Seat, +s0: D.Slot, +i0: D.Item, +rest: List<&2, S.StealOption>, +ow: D.Seat, +i: D.Item, +s: D.Slot, e: {Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, i)) == False{} : Bool}, f: {SA.steal.first(rest, ow, i) == Some{s} : Maybe<&2, D.Slot>}) -> {SA.steal.first(S.Pick{o0, s0, i0} <> rest, ow, i) == Some{s} : Maybe<&2, D.Slot>}:
  Equal.trans(Maybe<&2, D.Slot>, SA.steal.first(S.Pick{o0, s0, i0} <> rest, ow, i), SA.steal.first(rest, ow, i), Some{s}, Id.pick.eq(Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, i)), False{}, e, Some{s0}, SA.steal.first(rest, ow, i)), f)

def SP(+ps: List<&2, S.StealOption>, +seen: List<&2, D.At<&2, D.Item>>, +adr: D.Slot, o: T.IdleOption) -> Data:
  match o:
    case T.StealWith{a, ow, s, i}:
      Sigma<&2, &2, {a == adr : D.Slot}, e0 => Sigma<&2, &2, {P.picks.has(seen, ow, i) == False{} : Bool}, e1 => {SA.steal.first(ps, ow, i) == Some{s} : Maybe<&2, D.Slot>}>>
    case _:
      Empty

def SPAll(+ps: List<&2, S.StealOption>, +seen: List<&2, D.At<&2, D.Item>>, +adr: D.Slot, os: List<&2, T.IdleOption>) -> Data:
  match os:
    case Nil{}:
      Unit
    case o <> rest:
      Sigma<&2, &2, SP(ps, seen, adr, o), e0 => SPAll(ps, seen, adr, rest)>

def sp.weaken(+o0: D.Seat, +s0: D.Slot, +i0: D.Item, +rest: List<&2, S.StealOption>, +seen: List<&2, D.At<&2, D.Item>>, +adr: D.Slot, os: List<&2, T.IdleOption>, a: SPAll(rest, D.At{o0, i0} <> seen, adr, os)) -> SPAll(S.Pick{o0, s0, i0} <> rest, seen, adr, os):
  match os a:
    case Nil{} _:
      Unit{}
    case T.StealWith{+x, +ow, +s, +i} <> +more Tuple{Tuple{+ea, Tuple{+h, +f}}, +am}:
      +c : Bool = Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, i))
      ((ea, (or.false.r(c, P.picks.has(seen, ow, i), h), first.miss(o0, s0, i0, rest, ow, i, s, or.false.l(c, P.picks.has(seen, ow, i), h), f))), sp.weaken(o0, s0, i0, rest, seen, adr, more, am))
    case T.ShootAt{t} <> more Tuple{c, am}:
      match c:
    case T.UseSlot{s, i} <> more Tuple{c, am}:
      match c:
    case T.JamWith{s, t} <> more Tuple{c, am}:
      match c:
    case T.StealJamWith{x, y, z, v} <> more Tuple{c, am}:
      match c:

def sp.cell(+o0: D.Seat, +s0: D.Slot, +i0: D.Item, +rest: List<&2, S.StealOption>, +seen: List<&2, D.At<&2, D.Item>>, +adr: D.Slot, b: Bool, +eb: {Bool.not(Bool.or(P.item.chained(i0), P.picks.has(seen, o0, i0))) == b : Bool}, +tail: List<&2, T.IdleOption>, at: SPAll(S.Pick{o0, s0, i0} <> rest, seen, adr, tail)) -> SPAll(S.Pick{o0, s0, i0} <> rest, seen, adr, I.keep(T.IdleOption, b, T.StealWith{adr, o0, s0, i0}, tail)):
  match b:
    case True{}:
      +eo : {Bool.or(P.item.chained(i0), P.picks.has(seen, o0, i0)) == False{} : Bool} = not.true(Bool.or(P.item.chained(i0), P.picks.has(seen, o0, i0)), eb)
      (({==}, (or.false.r(P.item.chained(i0), P.picks.has(seen, o0, i0), eo), first.hit(o0, s0, i0, rest, o0, i0, and.tt(D.seat.eq(o0, o0), D.item.eq(i0, i0), Wk.seat.eq.refl(o0), Wk.item.eq.refl(i0))))), at)
    case False{}:
      at

def sp.all(+adr: D.Slot, ps: List<&2, S.StealOption>, +seen: List<&2, D.At<&2, D.Item>>) -> SPAll(ps, seen, adr, P.steal.picks(adr, ps, seen)):
  match ps:
    case Nil{}:
      Unit{}
    case S.Pick{+o0, +s0, +i0} <> +rest:
      +tail : List<&2, T.IdleOption> = P.steal.picks(adr, rest, D.At{o0, i0} <> seen)
      sp.cell(o0, s0, i0, rest, seen, adr, Bool.not(Bool.or(P.item.chained(i0), P.picks.has(seen, o0, i0))), {==}, tail, sp.weaken(o0, s0, i0, rest, seen, adr, tail, sp.all(adr, rest, D.At{o0, i0} <> seen)))

def adr.eq(+us: List<&2, S.IdleOption>, +adr: D.Slot, +a: D.Slot, ema: {P.use.first(us, D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>}, ea: {a == adr : D.Slot}) -> {P.use.first(us, D.Adrenaline{}) == Some{a} : Maybe<&2, D.Slot>}:
  Equal.trans(Maybe<&2, D.Slot>, P.use.first(us, D.Adrenaline{}), Some{adr}, Some{a}, ema, Equal.cong(D.Slot, Maybe<&2, D.Slot>, v => Some{v}, adr, a, Equal.sym(D.Slot, a, adr, ea)))

def sp.map(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, +adr: D.Slot, +ema: {P.use.first(us, D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>}, os: List<&2, T.IdleOption>, a: SPAll(ks, Nil{}, adr, os)) -> CAll(us, ks, os):
  match os a:
    case Nil{} _:
      Unit{}
    case T.StealWith{+x, +ow, +s, +i} <> +more Tuple{Tuple{+ea, Tuple{h, +f}}, +am}:
      ((adr.eq(us, adr, x, ema, ea), f), sp.map(us, ks, adr, ema, more, am))
    case T.ShootAt{t} <> more Tuple{c, am}:
      match c:
    case T.UseSlot{s, i} <> more Tuple{c, am}:
      match c:
    case T.JamWith{s, t} <> more Tuple{c, am}:
      match c:
    case T.StealJamWith{x, y, z, v} <> more Tuple{c, am}:
      match c:

def SJ(+ps: List<&2, S.StealOption>, +seen: List<&2, D.Seat>, +adr: D.Slot, o: T.IdleOption) -> Data:
  match o:
    case T.StealJamWith{a, ow, s, t}:
      Sigma<&2, &2, {a == adr : D.Slot}, e0 => Sigma<&2, &2, {P.seats.has(seen, ow) == False{} : Bool}, e1 => {SA.steal.first(ps, ow, D.Jammer{}) == Some{s} : Maybe<&2, D.Slot>}>>
    case _:
      Empty

def SJAll(+ps: List<&2, S.StealOption>, +seen: List<&2, D.Seat>, +adr: D.Slot, os: List<&2, T.IdleOption>) -> Data:
  match os:
    case Nil{}:
      Unit
    case o <> rest:
      Sigma<&2, &2, SJ(ps, seen, adr, o), e0 => SJAll(ps, seen, adr, rest)>

def sjall.append(+ps: List<&2, S.StealOption>, +seen: List<&2, D.Seat>, +adr: D.Slot, +xs: List<&2, T.IdleOption>, +ys: List<&2, T.IdleOption>, ax: SJAll(ps, seen, adr, xs), ay: SJAll(ps, seen, adr, ys)) -> SJAll(ps, seen, adr, List.append(&2, T.IdleOption, xs, ys)):
  match xs ax:
    case Nil{} _:
      ay
    case +x <> +rest Tuple{+cx, +arest}:
      (cx, sjall.append(ps, seen, adr, rest, ys, arest, ay))

def sj.targets(+adr: D.Slot, +o0: D.Seat, +s0: D.Slot, ts: List<&2, S.JamOption>, +ps: List<&2, S.StealOption>, +seen: List<&2, D.Seat>, +h: {P.seats.has(seen, o0) == False{} : Bool}, +f: {SA.steal.first(ps, o0, D.Jammer{}) == Some{s0} : Maybe<&2, D.Slot>}) -> SJAll(ps, seen, adr, P.steal_jam.targets(adr, o0, s0, ts)):
  match ts:
    case Nil{}:
      Unit{}
    case S.JamAt{t} <> rest:
      (({==}, (h, f)), sj.targets(adr, o0, s0, rest, ps, seen, h, f))

def sj.here(+o0: D.Seat, +s0: D.Slot, +i0: D.Item, +rest: List<&2, S.StealOption>, +seen: List<&2, D.Seat>, +adr: D.Slot, +ts: List<&2, S.JamOption>, take: Bool, +et: {Bool.and(D.item.eq(i0, D.Jammer{}), Bool.not(P.seats.has(seen, o0))) == take : Bool}) -> SJAll(S.Pick{o0, s0, i0} <> rest, seen, adr, P.steal_jam.here(take, adr, o0, s0, ts)):
  match take:
    case False{}:
      Unit{}
    case True{}:
      +ej : {D.item.eq(i0, D.Jammer{}) == True{} : Bool} = Id.and.l(D.item.eq(i0, D.Jammer{}), Bool.not(P.seats.has(seen, o0)), et)
      +h : {P.seats.has(seen, o0) == False{} : Bool} = not.true(P.seats.has(seen, o0), Id.and.r(D.item.eq(i0, D.Jammer{}), Bool.not(P.seats.has(seen, o0)), et))
      sj.targets(adr, o0, s0, ts, S.Pick{o0, s0, i0} <> rest, seen, h, first.hit(o0, s0, i0, rest, o0, D.Jammer{}, and.tt(D.seat.eq(o0, o0), D.item.eq(i0, D.Jammer{}), Wk.seat.eq.refl(o0), ej)))

def sj.weaken.t(+o0: D.Seat, +s0: D.Slot, +i0: D.Item, +rest: List<&2, S.StealOption>, +seen: List<&2, D.Seat>, +adr: D.Slot, os: List<&2, T.IdleOption>, a: SJAll(rest, o0 <> seen, adr, os)) -> SJAll(S.Pick{o0, s0, i0} <> rest, seen, adr, os):
  match os a:
    case Nil{} _:
      Unit{}
    case T.StealJamWith{+x, +ow, +s, +t} <> +more Tuple{Tuple{+ea, Tuple{+h, +f}}, +am}:
      +es : {D.seat.eq(o0, ow) == False{} : Bool} = or.false.l(D.seat.eq(o0, ow), P.seats.has(seen, ow), h)
      ((ea, (or.false.r(D.seat.eq(o0, ow), P.seats.has(seen, ow), h), first.miss(o0, s0, i0, rest, ow, D.Jammer{}, s, and.ff.l(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{}), es), f))), sj.weaken.t(o0, s0, i0, rest, seen, adr, more, am))
    case T.ShootAt{t} <> more Tuple{c, am}:
      match c:
    case T.UseSlot{s, i} <> more Tuple{c, am}:
      match c:
    case T.JamWith{s, t} <> more Tuple{c, am}:
      match c:
    case T.StealWith{x, y, z, v} <> more Tuple{c, am}:
      match c:

def sj.weaken.f(+o0: D.Seat, +s0: D.Slot, +i0: D.Item, +rest: List<&2, S.StealOption>, +seen: List<&2, D.Seat>, +adr: D.Slot, +ej: {D.item.eq(i0, D.Jammer{}) == False{} : Bool}, os: List<&2, T.IdleOption>, a: SJAll(rest, seen, adr, os)) -> SJAll(S.Pick{o0, s0, i0} <> rest, seen, adr, os):
  match os a:
    case Nil{} _:
      Unit{}
    case T.StealJamWith{+x, +ow, +s, +t} <> +more Tuple{Tuple{+ea, Tuple{+h, +f}}, +am}:
      ((ea, (h, first.miss(o0, s0, i0, rest, ow, D.Jammer{}, s, and.ff.r(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{}), ej), f))), sj.weaken.f(o0, s0, i0, rest, seen, adr, ej, more, am))
    case T.ShootAt{t} <> more Tuple{c, am}:
      match c:
    case T.UseSlot{s, i} <> more Tuple{c, am}:
      match c:
    case T.JamWith{s, t} <> more Tuple{c, am}:
      match c:
    case T.StealWith{x, y, z, v} <> more Tuple{c, am}:
      match c:

def sj.weaken(+o0: D.Seat, +s0: D.Slot, +i0: D.Item, +rest: List<&2, S.StealOption>, +seen: List<&2, D.Seat>, +adr: D.Slot, j: Bool, +ej: {D.item.eq(i0, D.Jammer{}) == j : Bool}, +os: List<&2, T.IdleOption>, a: SJAll(rest, I.keep(D.Seat, j, o0, seen), adr, os)) -> SJAll(S.Pick{o0, s0, i0} <> rest, seen, adr, os):
  match j:
    case True{}:
      sj.weaken.t(o0, s0, i0, rest, seen, adr, os, a)
    case False{}:
      sj.weaken.f(o0, s0, i0, rest, seen, adr, ej, os, a)

def sj.all(+adr: D.Slot, ps: List<&2, S.StealOption>, +ts: List<&2, S.JamOption>, +seen: List<&2, D.Seat>) -> SJAll(ps, seen, adr, P.steal_jam.picks(adr, ps, ts, seen)):
  match ps:
    case Nil{}:
      Unit{}
    case S.Pick{+o0, +s0, +i0} <> +rest:
      +jammer : Bool = D.item.eq(i0, D.Jammer{})
      +take : Bool = Bool.and(jammer, Bool.not(P.seats.has(seen, o0)))
      +seen2 : List<&2, D.Seat> = I.keep(D.Seat, jammer, o0, seen)
      sjall.append(S.Pick{o0, s0, i0} <> rest, seen, adr, P.steal_jam.here(take, adr, o0, s0, ts), P.steal_jam.picks(adr, rest, ts, seen2), sj.here(o0, s0, i0, rest, seen, adr, ts, take, {==}), sj.weaken(o0, s0, i0, rest, seen, adr, jammer, {==}, P.steal_jam.picks(adr, rest, ts, seen2), sj.all(adr, rest, ts, seen2)))

def sj.map(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, +adr: D.Slot, +ema: {P.use.first(us, D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>}, os: List<&2, T.IdleOption>, a: SJAll(ks, Nil{}, adr, os)) -> CAll(us, ks, os):
  match os a:
    case Nil{} _:
      Unit{}
    case T.StealJamWith{+x, +ow, +s, +t} <> +more Tuple{Tuple{+ea, Tuple{h, +f}}, +am}:
      ((adr.eq(us, adr, x, ema, ea), f), sj.map(us, ks, adr, ema, more, am))
    case T.ShootAt{t} <> more Tuple{c, am}:
      match c:
    case T.UseSlot{s, i} <> more Tuple{c, am}:
      match c:
    case T.JamWith{s, t} <> more Tuple{c, am}:
      match c:
    case T.StealWith{x, y, z, v} <> more Tuple{c, am}:
      match c:

def call.jt(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, +slot: D.Slot, +ej: {P.use.first(us, D.Jammer{}) == Some{slot} : Maybe<&2, D.Slot>}, ts: List<&2, S.JamOption>) -> CAll(us, ks, P.jam.targets(slot, ts)):
  match ts:
    case Nil{}:
      Unit{}
    case S.JamAt{t} <> rest:
      (ej, call.jt(us, ks, slot, ej, rest))

def call.jam(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, mj: Maybe<&2, D.Slot>, +emj: {P.use.first(us, D.Jammer{}) == mj : Maybe<&2, D.Slot>}, +ts: List<&2, S.JamOption>) -> CAll(us, ks, P.jam.options(mj, ts)):
  match mj:
    case None{}:
      Unit{}
    case Some{+slot}:
      call.jt(us, ks, slot, emj, ts)

def call.steal(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, ma: Maybe<&2, D.Slot>, +ema: {P.use.first(us, D.Adrenaline{}) == ma : Maybe<&2, D.Slot>}, +ts: List<&2, S.JamOption>) -> CAll(us, ks, List.append(&2, T.IdleOption, P.steal.options(ma, ks), P.steal_jam.options(ma, ks, ts))):
  match ma:
    case None{}:
      Unit{}
    case Some{+adr}:
      call.append(us, ks, P.steal.picks(adr, ks, Nil{}), P.steal_jam.picks(adr, ks, ts, Nil{}), sp.map(us, ks, adr, ema, P.steal.picks(adr, ks, Nil{}), sp.all(adr, ks, Nil{})), sj.map(us, ks, adr, ema, P.steal_jam.picks(adr, ks, ts, Nil{}), sj.all(adr, ks, ts, Nil{})))

# Every Idle option of the simple menu uses first slots.
def options.canon(+w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +seat: D.Seat) -> CAll(Id.Uses(w, p, g, seat), I.steal.for(Id.Rec(w, p, g), seat), P.options(T.State{w, p, ph, l, g}, seat)):
  +us : List<&2, S.IdleOption> = Id.Uses(w, p, g, seat)
  +ks : List<&2, S.StealOption> = I.steal.for(Id.Rec(w, p, g), seat)
  +js : List<&2, S.JamOption> = I.jam.for(Id.Rec(w, p, g), seat)
  +ma : Maybe<&2, D.Slot> = P.use.first(us, D.Adrenaline{})
  +rest3 : List<&2, T.IdleOption> = List.append(&2, T.IdleOption, P.steal.options(ma, ks), P.steal_jam.options(ma, ks, js))
  +rest2 : List<&2, T.IdleOption> = List.append(&2, T.IdleOption, P.jam.options(P.use.first(us, D.Jammer{}), js), rest3)
  +rest1 : List<&2, T.IdleOption> = List.append(&2, T.IdleOption, P.use.options(us, Nil{}), rest2)
  call.append(us, ks, P.shots(G.aim.targets(p)), rest1, call.shots(us, ks, G.aim.targets(p)), call.append(us, ks, P.use.options(us, Nil{}), rest2, uc.map(us, ks, P.use.options(us, Nil{}), uc.all(us, Nil{})), call.append(us, ks, P.jam.options(P.use.first(us, D.Jammer{}), js), rest3, call.jam(us, ks, P.use.first(us, D.Jammer{}), {==}, js), call.steal(us, ks, ma, {==}, js))))

def IdxF(+opts: List<&2, T.IdleOption>, +m: T.Move) -> Data:
  Sigma<&2, &2, Nat, k => Sigma<&2, &2, T.IdleOption, o => Sigma<&2, &2, {SA.move.index(P.moves(opts), m) == Some{k} : Maybe<&2, Nat>}, e0 => Sigma<&2, &2, {P.option.nth(opts, k) == Some{o} : Maybe<&2, T.IdleOption>}, e1 => {SA.move.same(P.option.move(o), m) == True{} : Bool}>>>>

def idx.head(+y: T.IdleOption, +ys: List<&2, T.IdleOption>, +m: T.Move, +hb: {SA.move.same(P.option.move(y), m) == True{} : Bool}) -> IdxF(y <> ys, m):
  %Equal.sym(Bool, SA.move.same(P.option.move(y), m), True{}, hb) : Sigma<&2, &2, Nat, k => Sigma<&2, &2, T.IdleOption, o => Sigma<&2, &2, {D.menu.find.here(_, SA.move.index(P.moves(ys), m)) == Some{k} : Maybe<&2, Nat>}, e0 => Sigma<&2, &2, {P.option.nth(y <> ys, k) == Some{o} : Maybe<&2, T.IdleOption>}, e1 => {SA.move.same(P.option.move(o), m) == True{} : Bool}>>>>
  (0n, (y, ({==}, ({==}, hb))))

def idx.cons(+y: T.IdleOption, +ys: List<&2, T.IdleOption>, +m: T.Move, b: Bool, +eb: {SA.move.same(P.option.move(y), m) == b : Bool}, ih: IdxF(ys, m)) -> IdxF(y <> ys, m):
  match b ih:
    case True{} _:
      idx.head(y, ys, m, eb)
    case False{} Tuple{+k, Tuple{+o, Tuple{+ek, Tuple{+en, +hs}}}}:
      %Equal.sym(Bool, SA.move.same(P.option.move(y), m), False{}, eb) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, T.IdleOption, x => Sigma<&2, &2, {D.menu.find.here(_, SA.move.index(P.moves(ys), m)) == Some{j} : Maybe<&2, Nat>}, e0 => Sigma<&2, &2, {P.option.nth(y <> ys, j) == Some{x} : Maybe<&2, T.IdleOption>}, e1 => {SA.move.same(P.option.move(x), m) == True{} : Bool}>>>>
      %Equal.sym(Maybe<&2, Nat>, SA.move.index(P.moves(ys), m), Some{k}, ek) : Sigma<&2, &2, Nat, j => Sigma<&2, &2, T.IdleOption, x => Sigma<&2, &2, {D.menu.find.here(False{}, _) == Some{j} : Maybe<&2, Nat>}, e0 => Sigma<&2, &2, {P.option.nth(y <> ys, j) == Some{x} : Maybe<&2, T.IdleOption>}, e1 => {SA.move.same(P.option.move(x), m) == True{} : Bool}>>>>
      (1n+k, (o, ({==}, (en, hs))))

def same.cast(+o0: T.IdleOption, +y: T.IdleOption, +m: T.Move, e: {o0 == y : T.IdleOption}, hm: {SA.move.same(P.option.move(o0), m) == True{} : Bool}) -> {SA.move.same(P.option.move(y), m) == True{} : Bool}:
  %e : {SA.move.same(P.option.move(_), m) == True{} : Bool}
  hm

def idx.find(opts: List<&2, T.IdleOption>, +o0: T.IdleOption, +m: T.Move, mem: Id.In(T.IdleOption, o0, opts), +hm: {SA.move.same(P.option.move(o0), m) == True{} : Bool}) -> IdxF(opts, m):
  match opts mem:
    case Nil{} _:
      match mem:
    case +y <> +ys Inl{+e}:
      idx.head(y, ys, m, same.cast(o0, y, m, e, hm))
    case +y <> +ys Inr{+rest}:
      idx.cons(y, ys, m, SA.move.same(P.option.move(y), m), {==}, idx.find(ys, o0, m, rest, hm))

def canon.nth(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, opts: List<&2, T.IdleOption>, k: Nat, +o: T.IdleOption, e: {P.option.nth(opts, k) == Some{o} : Maybe<&2, T.IdleOption>}, a: CAll(us, ks, opts)) -> Canon(us, ks, o):
  match opts k a:
    case Nil{} k _:
      Wk.absurd(Canon(us, ks, o), Wk.maybe.clash(T.IdleOption, o, e))
    case +x <> rest 0n Tuple{+cx, _}:
      %Wk.some.inj(T.IdleOption, x, o, e) : Canon(us, ks, _)
      cx
    case x <> rest 1n+j Tuple{_, +ar}:
      canon.nth(us, ks, rest, j, o, e, ar)

def idx.clamp(ms: List<&2, T.Move>, +m0: T.Move, +m: T.Move, +k: Nat, b: Bool, r: Maybe<&2, Nat>, +er: {SA.move.index(ms, m) == r : Maybe<&2, Nat>}, +found: {D.menu.find.here(b, r) == Some{k} : Maybe<&2, Nat>}) -> {D.clamp(k, List.length(&2, T.Move, ms)) == k : Nat}:
  match ms b r:
    case ms True{} r:
      %Wk.some.inj(Nat, 0n, k, found) : {D.clamp(_, List.length(&2, T.Move, ms)) == _ : Nat}
      {==}
    case Nil{} False{} None{}:
      Wk.absurd({D.clamp(k, 0n) == k : Nat}, Wk.maybe.clash(Nat, k, found))
    case Nil{} False{} Some{j}:
      Wk.absurd({D.clamp(k, 0n) == k : Nat}, Wk.maybe.clash(Nat, j, er))
    case m2 <> ms2 False{} None{}:
      Wk.absurd({D.clamp(k, 1n+List.length(&2, T.Move, ms2)) == k : Nat}, Wk.maybe.clash(Nat, k, found))
    case +m2 <> +ms2 False{} Some{+j}:
      %Wk.some.inj(Nat, 1n+j, k, found) : {D.clamp(_, 1n+List.length(&2, T.Move, ms2)) == _ : Nat}
      Equal.cong(Nat, Nat, x => 1n+x, D.clamp(j, List.length(&2, T.Move, ms2)), j, idx.clamp(ms2, m2, m, j, SA.move.same(m2, m), SA.move.index(ms2, m), {==}, er))

def step.same.refl(+x: SA.Step) -> {SA.step.same(x, x) == True{} : Bool}:
  match x:
    case SA.DrawStep{+a}:
      Wk.nat_eq.refl(a)
    case SA.ChoiceStep{+s, +mv}:
      and.tt(D.seat.eq(s, s), D.move.eq(mv, mv), Wk.seat.eq.refl(s), Id.move.eq.refl(mv))

def prefix.app(xs: List<&2, SA.Step>, +ys: List<&2, SA.Step>) -> {SA.prefix(xs, List.append(&2, SA.Step, xs, ys)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +rest:
      and.tt(SA.step.same(x, x), SA.prefix(rest, List.append(&2, SA.Step, rest, ys)), step.same.refl(x), prefix.app(rest, ys))

def prefix.refl(+xs: List<&2, SA.Step>) -> {SA.prefix(xs, xs) == True{} : Bool}:
  %Wk.append_nil(SA.Step, xs) : {SA.prefix(xs, _) == True{} : Bool}
  prefix.app(xs, Nil{})

def prefix.rest(+s: T.State, +x: SA.Step, +xr: List<&2, SA.Step>, walked: Maybe<&2, D.Stepped<&2, S.State>>) -> {SA.prefix(x <> xr, SA.chain.rest(s, x <> xr, walked)) == True{} : Bool}:
  match walked:
    case None{}:
      prefix.refl(x <> xr)
    case Some{D.Stepped{+r, _}}:
      prefix.app(x <> xr, SA.sched(r, SA.chain.after(T.state.phase(s), r)))

def GoalSel(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +g0: SA.Step, +gr: List<&2, SA.Step>, sel: Maybe<&2, T.IdleOption>) -> Data:
  {SA.prefix(g0 <> gr, SA.chain.rest(T.State{w, p, T.Idle{seat}, l, g}, SA.option.steps(seat, sel), SA.walk.go(SA.option.steps(seat, sel), SA.embed(T.State{w, p, T.Idle{seat}, l, g})))) == True{} : Bool}

def rec.sel(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +g0: SA.Step, +gr: List<&2, SA.Step>, +o: T.IdleOption, est: {SA.option.steps(seat, Some{o}) == g0 <> gr : List<&2, SA.Step>}) -> GoalSel(w, p, l, g, seat, g0, gr, Some{o}):
  %Equal.sym(List<&2, SA.Step>, SA.option.steps(seat, Some{o}), g0 <> gr, est) : {SA.prefix(g0 <> gr, SA.chain.rest(T.State{w, p, T.Idle{seat}, l, g}, _, SA.walk.go(_, SA.embed(T.State{w, p, T.Idle{seat}, l, g})))) == True{} : Bool}
  prefix.rest(T.State{w, p, T.Idle{seat}, l, g}, g0, gr, SA.walk.go(g0 <> gr, SA.embed(T.State{w, p, T.Idle{seat}, l, g})))

def rec.req(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +g0: SA.Step, +gr: List<&2, SA.Step>, +m: T.Move, +k: Nat, +o: T.IdleOption, +ek: {SA.move.index(P.moves(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat)), m) == Some{k} : Maybe<&2, Nat>}, +enth: {P.option.nth(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), k) == Some{o} : Maybe<&2, T.IdleOption>}, +est: {SA.option.steps(seat, Some{o}) == g0 <> gr : List<&2, SA.Step>}, +seated: Id.Seated(S.world.table(w), seat), sd: Bool, +esd: {P.seated(D.ring.get(Bool, D.ring.fill(Bool, S.world.table(w), True{}), seat)) == sd : Bool}, opts: List<&2, T.IdleOption>, +eo: {P.options(T.State{w, p, T.Idle{seat}, l, g}, seat) == opts : List<&2, T.IdleOption>}) -> {SA.prefix(g0 <> gr, SA.chain.rest(T.State{w, p, T.Idle{seat}, l, g}, SA.chain.first(T.State{w, p, T.Idle{seat}, l, g}, k, P.idle.request(sd, seat, P.moves(opts))), SA.walk.go(SA.chain.first(T.State{w, p, T.Idle{seat}, l, g}, k, P.idle.request(sd, seat, P.moves(opts))), SA.embed(T.State{w, p, T.Idle{seat}, l, g})))) == True{} : Bool}:
  match sd opts:
    case False{} opts:
      Wk.absurd({SA.prefix(g0 <> gr, SA.chain.rest(T.State{w, p, T.Idle{seat}, l, g}, SA.chain.first(T.State{w, p, T.Idle{seat}, l, g}, k, P.idle.request(False{}, seat, P.moves(opts))), SA.walk.go(SA.chain.first(T.State{w, p, T.Idle{seat}, l, g}, k, P.idle.request(False{}, seat, P.moves(opts))), SA.embed(T.State{w, p, T.Idle{seat}, l, g})))) == True{} : Bool}, bool.clash2(Equal.trans(Bool, True{}, P.seated(D.ring.get(Bool, D.ring.fill(Bool, S.world.table(w), True{}), seat)), False{}, Equal.sym(Bool, P.seated(D.ring.get(Bool, D.ring.fill(Bool, S.world.table(w), True{}), seat)), True{}, seated), esd)))
    case True{} Nil{}:
      Wk.absurd({SA.prefix(g0 <> gr, SA.chain.rest(T.State{w, p, T.Idle{seat}, l, g}, SA.chain.first(T.State{w, p, T.Idle{seat}, l, g}, k, P.idle.request(True{}, seat, P.moves(Nil{}))), SA.walk.go(SA.chain.first(T.State{w, p, T.Idle{seat}, l, g}, k, P.idle.request(True{}, seat, P.moves(Nil{}))), SA.embed(T.State{w, p, T.Idle{seat}, l, g})))) == True{} : Bool}, Wk.maybe.clash(Nat, k, Equal.trans(Maybe<&2, Nat>, None{}, SA.move.index(P.moves(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat)), m), Some{k}, Equal.cong(List<&2, T.IdleOption>, Maybe<&2, Nat>, xs => SA.move.index(P.moves(xs), m), Nil{}, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), Equal.sym(List<&2, T.IdleOption>, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), Nil{}, eo)), ek)))
    case True{} +o0 <> +os:
      +L : Nat = List.length(&2, T.Move, P.moves(os))
      +ek2 : {SA.move.index(P.moves(o0 <> os), m) == Some{k} : Maybe<&2, Nat>} = Equal.trans(Maybe<&2, Nat>, SA.move.index(P.moves(o0 <> os), m), SA.move.index(P.moves(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat)), m), Some{k}, Equal.cong(List<&2, T.IdleOption>, Maybe<&2, Nat>, xs => SA.move.index(P.moves(xs), m), o0 <> os, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), Equal.sym(List<&2, T.IdleOption>, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), o0 <> os, eo)), ek)
      +ec : {D.clamp(k, L) == k : Nat} = idx.clamp(P.moves(os), P.option.move(o0), m, k, SA.move.same(P.option.move(o0), m), SA.move.index(P.moves(os), m), {==}, ek2)
      +esel : {P.option.nth(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), D.clamp(k, L)) == Some{o} : Maybe<&2, T.IdleOption>} = Equal.trans(Maybe<&2, T.IdleOption>, P.option.nth(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), D.clamp(k, L)), P.option.nth(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), k), Some{o}, Equal.cong(Nat, Maybe<&2, T.IdleOption>, i => P.option.nth(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), i), D.clamp(k, L), k, ec), enth)
      %Equal.sym(Maybe<&2, T.IdleOption>, P.option.nth(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), D.clamp(k, L)), Some{o}, esel) : GoalSel(w, p, l, g, seat, g0, gr, _)
      rec.sel(w, p, l, g, seat, g0, gr, o, est)

def back.found(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +g0: SA.Step, +gr: List<&2, SA.Step>, +m: T.Move, +seated: Id.Seated(S.world.table(w), seat), fix: @+o:T.IdleOption -> @c:Canon(Id.Uses(w, p, g, seat), I.steal.for(Id.Rec(w, p, g), seat), o) -> @h:{SA.move.same(P.option.move(o), m) == True{} : Bool} -> {SA.option.steps(seat, Some{o}) == g0 <> gr : List<&2, SA.Step>}, found: IdxF(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), m)) -> {SA.recovered.at(SA.menu.index(T.State{w, p, T.Idle{seat}, l, g}, m), T.State{w, p, T.Idle{seat}, l, g}, g0 <> gr) == True{} : Bool}:
  match found:
    case Tuple{+k, Tuple{+o, Tuple{+ek, Tuple{+enth, +hs}}}}:
      +canon : Canon(Id.Uses(w, p, g, seat), I.steal.for(Id.Rec(w, p, g), seat), o) = canon.nth(Id.Uses(w, p, g, seat), I.steal.for(Id.Rec(w, p, g), seat), P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), k, o, enth, options.canon(w, p, T.Idle{seat}, l, g, seat))
      %Equal.sym(Maybe<&2, Nat>, SA.move.index(P.moves(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat)), m), Some{k}, ek) : {SA.recovered.at(_, T.State{w, p, T.Idle{seat}, l, g}, g0 <> gr) == True{} : Bool}
      rec.req(w, p, l, g, seat, g0, gr, m, k, o, ek, enth, fix(o, canon, hs), seated, P.seated(D.ring.get(Bool, D.ring.fill(Bool, S.world.table(w), True{}), seat)), {==}, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), {==})

def back(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +g0: SA.Step, +gr: List<&2, SA.Step>, +m: T.Move, +seated: Id.Seated(S.world.table(w), seat), +o0: T.IdleOption, mem: Id.In(T.IdleOption, o0, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat)), +hm: {SA.move.same(P.option.move(o0), m) == True{} : Bool}, fix: @+o:T.IdleOption -> @c:Canon(Id.Uses(w, p, g, seat), I.steal.for(Id.Rec(w, p, g), seat), o) -> @h:{SA.move.same(P.option.move(o), m) == True{} : Bool} -> {SA.option.steps(seat, Some{o}) == g0 <> gr : List<&2, SA.Step>}) -> {SA.recovered.at(SA.menu.index(T.State{w, p, T.Idle{seat}, l, g}, m), T.State{w, p, T.Idle{seat}, l, g}, g0 <> gr) == True{} : Bool}:
  back.found(w, p, l, g, seat, g0, gr, m, seated, fix, idx.find(P.options(T.State{w, p, T.Idle{seat}, l, g}, seat), o0, m, mem, hm))

def in.left(-A: Data, +x: A, xs: List<&2, A>, +ys: List<&2, A>, m: Id.In(A, x, xs)) -> Id.In(A, x, List.append(&2, A, xs, ys)):
  match xs m:
    case Nil{} _:
      match m:
    case y <> rest Inl{e}:
      Inl{e}
    case y <> rest Inr{mr}:
      Inr{in.left(A, x, rest, ys, mr)}

def in.right(-A: Data, +x: A, xs: List<&2, A>, +ys: List<&2, A>, m: Id.In(A, x, ys)) -> Id.In(A, x, List.append(&2, A, xs, ys)):
  match xs:
    case Nil{}:
      m
    case y <> rest:
      Inr{in.right(A, x, rest, ys, m)}

def in.keep(+x: T.IdleOption, b: Bool, +y: T.IdleOption, +rest: List<&2, T.IdleOption>, m: Id.In(T.IdleOption, x, rest)) -> Id.In(T.IdleOption, x, I.keep(T.IdleOption, b, y, rest)):
  match b:
    case True{}:
      Inr{m}
    case False{}:
      m

def tgt.proj(o: S.TargetOption) -> D.Seat:
  match o:
    case S.Target{s}:
      s

def in.shots(+t: D.Seat, ts: List<&2, S.TargetOption>, m: Id.In(S.TargetOption, S.Target{t}, ts)) -> Id.In(T.IdleOption, T.ShootAt{t}, P.shots(ts)):
  match ts m:
    case Nil{} _:
      match m:
    case S.Target{+u} <> rest Inl{+e}:
      Inl{Equal.cong(D.Seat, T.IdleOption, v => T.ShootAt{v}, t, u, Equal.cong(S.TargetOption, D.Seat, tgt.proj, S.Target{t}, S.Target{u}, e))}
    case S.Target{u} <> rest Inr{mr}:
      Inr{in.shots(t, rest, mr)}

def jmo.proj(o: S.JamOption) -> D.Seat:
  match o:
    case S.JamAt{s}:
      s

def in.jt(+slot: D.Slot, +t: D.Seat, ts: List<&2, S.JamOption>, m: Id.In(S.JamOption, S.JamAt{t}, ts)) -> Id.In(T.IdleOption, T.JamWith{slot, t}, P.jam.targets(slot, ts)):
  match ts m:
    case Nil{} _:
      match m:
    case S.JamAt{+u} <> rest Inl{+e}:
      Inl{Equal.cong(D.Seat, T.IdleOption, v => T.JamWith{slot, v}, t, u, Equal.cong(S.JamOption, D.Seat, jmo.proj, S.JamAt{t}, S.JamAt{u}, e))}
    case S.JamAt{u} <> rest Inr{mr}:
      Inr{in.jt(slot, t, rest, mr)}

def in.sjt(+adr: D.Slot, +ow: D.Seat, +slot: D.Slot, +t: D.Seat, ts: List<&2, S.JamOption>, m: Id.In(S.JamOption, S.JamAt{t}, ts)) -> Id.In(T.IdleOption, T.StealJamWith{adr, ow, slot, t}, P.steal_jam.targets(adr, ow, slot, ts)):
  match ts m:
    case Nil{} _:
      match m:
    case S.JamAt{+u} <> rest Inl{+e}:
      Inl{Equal.cong(D.Seat, T.IdleOption, v => T.StealJamWith{adr, ow, slot, v}, t, u, Equal.cong(S.JamOption, D.Seat, jmo.proj, S.JamAt{t}, S.JamAt{u}, e))}
    case S.JamAt{u} <> rest Inr{mr}:
      Inr{in.sjt(adr, ow, slot, t, rest, mr)}

def slot.is.some(m: Maybe<&2, D.Slot>, +slot: D.Slot, e: {SA.slot.is(m, slot) == True{} : Bool}) -> {m == Some{slot} : Maybe<&2, D.Slot>}:
  match m:
    case None{}:
      Wk.absurd({None{} == Some{slot} : Maybe<&2, D.Slot>}, Wk.bool.clash(e))
    case Some{+s}:
      Equal.cong(D.Slot, Maybe<&2, D.Slot>, v => Some{v}, s, slot, Wk.slot.eq.sound(s, slot, e))

def or.ff(+a: Bool, +b: Bool, ea: {a == False{} : Bool}, eb: {b == False{} : Bool}) -> {Bool.or(a, b) == False{} : Bool}:
  %Equal.sym(Bool, a, False{}, ea) : {Bool.or(_, b) == False{} : Bool}
  eb

def pick.true(+b: Bool, +eb: {b == True{} : Bool}, +y: Maybe<&2, D.Slot>, +n: Maybe<&2, D.Slot>, +z: Maybe<&2, D.Slot>, e: {Bool.pick(Maybe<&2, D.Slot>, b, y, n) == z : Maybe<&2, D.Slot>}) -> {y == z : Maybe<&2, D.Slot>}:
  Equal.trans(Maybe<&2, D.Slot>, y, Bool.pick(Maybe<&2, D.Slot>, b, y, n), z, Equal.sym(Maybe<&2, D.Slot>, Bool.pick(Maybe<&2, D.Slot>, b, y, n), y, Id.pick.eq(b, True{}, eb, y, n)), e)

def pick.false(+b: Bool, +eb: {b == False{} : Bool}, +y: Maybe<&2, D.Slot>, +n: Maybe<&2, D.Slot>, +z: Maybe<&2, D.Slot>, e: {Bool.pick(Maybe<&2, D.Slot>, b, y, n) == z : Maybe<&2, D.Slot>}) -> {n == z : Maybe<&2, D.Slot>}:
  Equal.trans(Maybe<&2, D.Slot>, n, Bool.pick(Maybe<&2, D.Slot>, b, y, n), z, Equal.sym(Maybe<&2, D.Slot>, Bool.pick(Maybe<&2, D.Slot>, b, y, n), n, Id.pick.eq(b, False{}, eb, y, n)), e)

def some.slot(+a: D.Slot, +b: D.Slot, e: {Some{a} == Some{b} : Maybe<&2, D.Slot>}) -> {a == b : D.Slot}:
  Wk.some.inj(D.Slot, a, b, e)

def use.hit(+s0: D.Slot, +i0: D.Item, +tail: List<&2, T.IdleOption>, +seen: List<&2, D.Item>, +slot: D.Slot, +item: D.Item, +ei: {i0 == item : D.Item}, +es: {s0 == slot : D.Slot}, +eh: {P.items.has(seen, item) == False{} : Bool}, +ec: {P.item.chained(item) == False{} : Bool}) -> Id.In(T.IdleOption, T.UseSlot{slot, item}, I.keep(T.IdleOption, Bool.not(Bool.or(P.item.chained(i0), P.items.has(seen, i0))), T.UseSlot{s0, i0}, tail)):
  %Equal.sym(D.Item, i0, item, ei) : Id.In(T.IdleOption, T.UseSlot{slot, item}, I.keep(T.IdleOption, Bool.not(Bool.or(P.item.chained(_), P.items.has(seen, _))), T.UseSlot{s0, _}, tail))
  %Equal.sym(D.Slot, s0, slot, es) : Id.In(T.IdleOption, T.UseSlot{slot, item}, I.keep(T.IdleOption, Bool.not(Bool.or(P.item.chained(item), P.items.has(seen, item))), T.UseSlot{_, item}, tail))
  %Equal.sym(Bool, P.item.chained(item), False{}, ec) : Id.In(T.IdleOption, T.UseSlot{slot, item}, I.keep(T.IdleOption, Bool.not(Bool.or(_, P.items.has(seen, item))), T.UseSlot{slot, item}, tail))
  %Equal.sym(Bool, P.items.has(seen, item), False{}, eh) : Id.In(T.IdleOption, T.UseSlot{slot, item}, I.keep(T.IdleOption, Bool.not(Bool.or(False{}, _)), T.UseSlot{slot, item}, tail))
  Inl{{==}}

def in.use.cell(+s0: D.Slot, +i0: D.Item, +rest: List<&2, S.IdleOption>, +seen: List<&2, D.Item>, +slot: D.Slot, +item: D.Item, b: Bool, +eb: {D.item.eq(i0, item) == b : Bool}, +ef: {Bool.pick(Maybe<&2, D.Slot>, D.item.eq(i0, item), Some{s0}, P.use.first(rest, item)) == Some{slot} : Maybe<&2, D.Slot>}, +eh: {P.items.has(seen, item) == False{} : Bool}, +ec: {P.item.chained(item) == False{} : Bool}, ih: @ef2:{P.use.first(rest, item) == Some{slot} : Maybe<&2, D.Slot>} -> @eh2:{P.items.has(i0 <> seen, item) == False{} : Bool} -> Id.In(T.IdleOption, T.UseSlot{slot, item}, P.use.options(rest, i0 <> seen))) -> Id.In(T.IdleOption, T.UseSlot{slot, item}, I.keep(T.IdleOption, Bool.not(Bool.or(P.item.chained(i0), P.items.has(seen, i0))), T.UseSlot{s0, i0}, P.use.options(rest, i0 <> seen))):
  match b:
    case True{}:
      use.hit(s0, i0, P.use.options(rest, i0 <> seen), seen, slot, item, Wk.item.eq.sound(i0, item, eb), some.slot(s0, slot, pick.true(D.item.eq(i0, item), eb, Some{s0}, P.use.first(rest, item), Some{slot}, ef)), eh, ec)
    case False{}:
      in.keep(T.UseSlot{slot, item}, Bool.not(Bool.or(P.item.chained(i0), P.items.has(seen, i0))), T.UseSlot{s0, i0}, P.use.options(rest, i0 <> seen), ih(pick.false(D.item.eq(i0, item), eb, Some{s0}, P.use.first(rest, item), Some{slot}, ef), or.ff(D.item.eq(i0, item), P.items.has(seen, item), eb, eh)))

def in.use(xs: List<&2, S.IdleOption>, +seen: List<&2, D.Item>, +slot: D.Slot, +item: D.Item, ef: {P.use.first(xs, item) == Some{slot} : Maybe<&2, D.Slot>}, +eh: {P.items.has(seen, item) == False{} : Bool}, +ec: {P.item.chained(item) == False{} : Bool}) -> Id.In(T.IdleOption, T.UseSlot{slot, item}, P.use.options(xs, seen)):
  match xs:
    case Nil{}:
      Wk.absurd(Empty, Wk.maybe.clash(D.Slot, slot, ef))
    case S.TakeGun{} <> rest:
      in.use(rest, seen, slot, item, ef, eh, ec)
    case S.UseAt{+s0, +i0} <> +rest:
      in.use.cell(s0, i0, rest, seen, slot, item, D.item.eq(i0, item), {==}, ef, eh, ec, ef2 => eh2 => in.use(rest, i0 <> seen, slot, item, ef2, eh2, ec))

def steal.hit(+adr: D.Slot, +o0: D.Seat, +s0: D.Slot, +i0: D.Item, +tail: List<&2, T.IdleOption>, +seen: List<&2, D.At<&2, D.Item>>, +ow: D.Seat, +s: D.Slot, +i: D.Item, +eo: {o0 == ow : D.Seat}, +ei: {i0 == i : D.Item}, +es: {s0 == s : D.Slot}, +eh: {P.picks.has(seen, ow, i) == False{} : Bool}, +ec: {P.item.chained(i) == False{} : Bool}) -> Id.In(T.IdleOption, T.StealWith{adr, ow, s, i}, I.keep(T.IdleOption, Bool.not(Bool.or(P.item.chained(i0), P.picks.has(seen, o0, i0))), T.StealWith{adr, o0, s0, i0}, tail)):
  %Equal.sym(D.Seat, o0, ow, eo) : Id.In(T.IdleOption, T.StealWith{adr, ow, s, i}, I.keep(T.IdleOption, Bool.not(Bool.or(P.item.chained(i0), P.picks.has(seen, _, i0))), T.StealWith{adr, _, s0, i0}, tail))
  %Equal.sym(D.Item, i0, i, ei) : Id.In(T.IdleOption, T.StealWith{adr, ow, s, i}, I.keep(T.IdleOption, Bool.not(Bool.or(P.item.chained(_), P.picks.has(seen, ow, _))), T.StealWith{adr, ow, s0, _}, tail))
  %Equal.sym(D.Slot, s0, s, es) : Id.In(T.IdleOption, T.StealWith{adr, ow, s, i}, I.keep(T.IdleOption, Bool.not(Bool.or(P.item.chained(i), P.picks.has(seen, ow, i))), T.StealWith{adr, ow, _, i}, tail))
  %Equal.sym(Bool, P.item.chained(i), False{}, ec) : Id.In(T.IdleOption, T.StealWith{adr, ow, s, i}, I.keep(T.IdleOption, Bool.not(Bool.or(_, P.picks.has(seen, ow, i))), T.StealWith{adr, ow, s, i}, tail))
  %Equal.sym(Bool, P.picks.has(seen, ow, i), False{}, eh) : Id.In(T.IdleOption, T.StealWith{adr, ow, s, i}, I.keep(T.IdleOption, Bool.not(Bool.or(False{}, _)), T.StealWith{adr, ow, s, i}, tail))
  Inl{{==}}

def in.steal.cell(+adr: D.Slot, +o0: D.Seat, +s0: D.Slot, +i0: D.Item, +rest: List<&2, S.StealOption>, +seen: List<&2, D.At<&2, D.Item>>, +ow: D.Seat, +s: D.Slot, +i: D.Item, b: Bool, +eb: {Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, i)) == b : Bool}, +ef: {Bool.pick(Maybe<&2, D.Slot>, Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, i)), Some{s0}, SA.steal.first(rest, ow, i)) == Some{s} : Maybe<&2, D.Slot>}, +eh: {P.picks.has(seen, ow, i) == False{} : Bool}, +ec: {P.item.chained(i) == False{} : Bool}, ih: @ef2:{SA.steal.first(rest, ow, i) == Some{s} : Maybe<&2, D.Slot>} -> @eh2:{P.picks.has(D.At{o0, i0} <> seen, ow, i) == False{} : Bool} -> Id.In(T.IdleOption, T.StealWith{adr, ow, s, i}, P.steal.picks(adr, rest, D.At{o0, i0} <> seen))) -> Id.In(T.IdleOption, T.StealWith{adr, ow, s, i}, I.keep(T.IdleOption, Bool.not(Bool.or(P.item.chained(i0), P.picks.has(seen, o0, i0))), T.StealWith{adr, o0, s0, i0}, P.steal.picks(adr, rest, D.At{o0, i0} <> seen))):
  match b:
    case True{}:
      +c : Bool = Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, i))
      steal.hit(adr, o0, s0, i0, P.steal.picks(adr, rest, D.At{o0, i0} <> seen), seen, ow, s, i, Wk.seat.eq.sound(o0, ow, Id.and.l(D.seat.eq(o0, ow), D.item.eq(i0, i), eb)), Wk.item.eq.sound(i0, i, Id.and.r(D.seat.eq(o0, ow), D.item.eq(i0, i), eb)), some.slot(s0, s, pick.true(c, eb, Some{s0}, SA.steal.first(rest, ow, i), Some{s}, ef)), eh, ec)
    case False{}:
      +c : Bool = Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, i))
      in.keep(T.StealWith{adr, ow, s, i}, Bool.not(Bool.or(P.item.chained(i0), P.picks.has(seen, o0, i0))), T.StealWith{adr, o0, s0, i0}, P.steal.picks(adr, rest, D.At{o0, i0} <> seen), ih(pick.false(c, eb, Some{s0}, SA.steal.first(rest, ow, i), Some{s}, ef), or.ff(c, P.picks.has(seen, ow, i), eb, eh)))

def in.steal(+adr: D.Slot, ps: List<&2, S.StealOption>, +seen: List<&2, D.At<&2, D.Item>>, +ow: D.Seat, +s: D.Slot, +i: D.Item, ef: {SA.steal.first(ps, ow, i) == Some{s} : Maybe<&2, D.Slot>}, +eh: {P.picks.has(seen, ow, i) == False{} : Bool}, +ec: {P.item.chained(i) == False{} : Bool}) -> Id.In(T.IdleOption, T.StealWith{adr, ow, s, i}, P.steal.picks(adr, ps, seen)):
  match ps:
    case Nil{}:
      Wk.absurd(Empty, Wk.maybe.clash(D.Slot, s, ef))
    case S.Pick{+o0, +s0, +i0} <> +rest:
      in.steal.cell(adr, o0, s0, i0, rest, seen, ow, s, i, Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, i)), {==}, ef, eh, ec, ef2 => eh2 => in.steal(adr, rest, D.At{o0, i0} <> seen, ow, s, i, ef2, eh2, ec))

def and.true.r(+a: Bool, e: {Bool.and(a, True{}) == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case True{}:
      Wk.absurd({True{} == False{} : Bool}, bool.clash2(e))
    case False{}:
      {==}

def sj.eh(+o0: D.Seat, +i0: D.Item, +seen: List<&2, D.Seat>, +ow: D.Seat, j: Bool, +ej: {D.item.eq(i0, D.Jammer{}) == j : Bool}, +eb: {Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{})) == False{} : Bool}, +eh: {P.seats.has(seen, ow) == False{} : Bool}) -> {P.seats.has(I.keep(D.Seat, D.item.eq(i0, D.Jammer{}), o0, seen), ow) == False{} : Bool}:
  match j:
    case True{}:
      %Equal.sym(Bool, D.item.eq(i0, D.Jammer{}), True{}, ej) : {P.seats.has(I.keep(D.Seat, _, o0, seen), ow) == False{} : Bool}
      +eb2 : {Bool.and(D.seat.eq(o0, ow), True{}) == False{} : Bool} = Equal.trans(Bool, Bool.and(D.seat.eq(o0, ow), True{}), Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{})), False{}, Equal.cong(Bool, Bool, v => Bool.and(D.seat.eq(o0, ow), v), True{}, D.item.eq(i0, D.Jammer{}), Equal.sym(Bool, D.item.eq(i0, D.Jammer{}), True{}, ej)), eb)
      or.ff(D.seat.eq(o0, ow), P.seats.has(seen, ow), and.true.r(D.seat.eq(o0, ow), eb2), eh)
    case False{}:
      %Equal.sym(Bool, D.item.eq(i0, D.Jammer{}), False{}, ej) : {P.seats.has(I.keep(D.Seat, _, o0, seen), ow) == False{} : Bool}
      eh

def sj.hit(+adr: D.Slot, +o0: D.Seat, +s0: D.Slot, +i0: D.Item, +tail: List<&2, T.IdleOption>, +seen: List<&2, D.Seat>, +ts: List<&2, S.JamOption>, +ow: D.Seat, +s: D.Slot, +t: D.Seat, +eo: {o0 == ow : D.Seat}, +ei: {i0 == D.Jammer{} : D.Item}, +es: {s0 == s : D.Slot}, +eh: {P.seats.has(seen, ow) == False{} : Bool}, +mj: Id.In(S.JamOption, S.JamAt{t}, ts)) -> Id.In(T.IdleOption, T.StealJamWith{adr, ow, s, t}, List.append(&2, T.IdleOption, P.steal_jam.here(Bool.and(D.item.eq(i0, D.Jammer{}), Bool.not(P.seats.has(seen, o0))), adr, o0, s0, ts), tail)):
  %Equal.sym(D.Seat, o0, ow, eo) : Id.In(T.IdleOption, T.StealJamWith{adr, ow, s, t}, List.append(&2, T.IdleOption, P.steal_jam.here(Bool.and(D.item.eq(i0, D.Jammer{}), Bool.not(P.seats.has(seen, _))), adr, _, s0, ts), tail))
  %Equal.sym(D.Item, i0, D.Jammer{}, ei) : Id.In(T.IdleOption, T.StealJamWith{adr, ow, s, t}, List.append(&2, T.IdleOption, P.steal_jam.here(Bool.and(D.item.eq(_, D.Jammer{}), Bool.not(P.seats.has(seen, ow))), adr, ow, s0, ts), tail))
  %Equal.sym(D.Slot, s0, s, es) : Id.In(T.IdleOption, T.StealJamWith{adr, ow, s, t}, List.append(&2, T.IdleOption, P.steal_jam.here(Bool.and(D.item.eq(D.Jammer{}, D.Jammer{}), Bool.not(P.seats.has(seen, ow))), adr, ow, _, ts), tail))
  %Equal.sym(Bool, P.seats.has(seen, ow), False{}, eh) : Id.In(T.IdleOption, T.StealJamWith{adr, ow, s, t}, List.append(&2, T.IdleOption, P.steal_jam.here(Bool.and(D.item.eq(D.Jammer{}, D.Jammer{}), Bool.not(_)), adr, ow, s, ts), tail))
  in.left(T.IdleOption, T.StealJamWith{adr, ow, s, t}, P.steal_jam.targets(adr, ow, s, ts), tail, in.sjt(adr, ow, s, t, ts, mj))

def in.sj.cell(+adr: D.Slot, +o0: D.Seat, +s0: D.Slot, +i0: D.Item, +rest: List<&2, S.StealOption>, +seen: List<&2, D.Seat>, +ts: List<&2, S.JamOption>, +ow: D.Seat, +s: D.Slot, +t: D.Seat, b: Bool, +eb: {Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{})) == b : Bool}, +ef: {Bool.pick(Maybe<&2, D.Slot>, Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{})), Some{s0}, SA.steal.first(rest, ow, D.Jammer{})) == Some{s} : Maybe<&2, D.Slot>}, +eh: {P.seats.has(seen, ow) == False{} : Bool}, +mj: Id.In(S.JamOption, S.JamAt{t}, ts), ih: @ef2:{SA.steal.first(rest, ow, D.Jammer{}) == Some{s} : Maybe<&2, D.Slot>} -> @eh2:{P.seats.has(I.keep(D.Seat, D.item.eq(i0, D.Jammer{}), o0, seen), ow) == False{} : Bool} -> Id.In(T.IdleOption, T.StealJamWith{adr, ow, s, t}, P.steal_jam.picks(adr, rest, ts, I.keep(D.Seat, D.item.eq(i0, D.Jammer{}), o0, seen)))) -> Id.In(T.IdleOption, T.StealJamWith{adr, ow, s, t}, List.append(&2, T.IdleOption, P.steal_jam.here(Bool.and(D.item.eq(i0, D.Jammer{}), Bool.not(P.seats.has(seen, o0))), adr, o0, s0, ts), P.steal_jam.picks(adr, rest, ts, I.keep(D.Seat, D.item.eq(i0, D.Jammer{}), o0, seen)))):
  match b:
    case True{}:
      sj.hit(adr, o0, s0, i0, P.steal_jam.picks(adr, rest, ts, I.keep(D.Seat, D.item.eq(i0, D.Jammer{}), o0, seen)), seen, ts, ow, s, t, Wk.seat.eq.sound(o0, ow, Id.and.l(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{}), eb)), Wk.item.eq.sound(i0, D.Jammer{}, Id.and.r(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{}), eb)), some.slot(s0, s, pick.true(Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{})), eb, Some{s0}, SA.steal.first(rest, ow, D.Jammer{}), Some{s}, ef)), eh, mj)
    case False{}:
      in.right(T.IdleOption, T.StealJamWith{adr, ow, s, t}, P.steal_jam.here(Bool.and(D.item.eq(i0, D.Jammer{}), Bool.not(P.seats.has(seen, o0))), adr, o0, s0, ts), P.steal_jam.picks(adr, rest, ts, I.keep(D.Seat, D.item.eq(i0, D.Jammer{}), o0, seen)), ih(pick.false(Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{})), eb, Some{s0}, SA.steal.first(rest, ow, D.Jammer{}), Some{s}, ef), sj.eh(o0, i0, seen, ow, D.item.eq(i0, D.Jammer{}), {==}, eb, eh)))

def in.sj(+adr: D.Slot, ps: List<&2, S.StealOption>, +ts: List<&2, S.JamOption>, +seen: List<&2, D.Seat>, +ow: D.Seat, +s: D.Slot, +t: D.Seat, ef: {SA.steal.first(ps, ow, D.Jammer{}) == Some{s} : Maybe<&2, D.Slot>}, +eh: {P.seats.has(seen, ow) == False{} : Bool}, +mj: Id.In(S.JamOption, S.JamAt{t}, ts)) -> Id.In(T.IdleOption, T.StealJamWith{adr, ow, s, t}, P.steal_jam.picks(adr, ps, ts, seen)):
  match ps:
    case Nil{}:
      Wk.absurd(Empty, Wk.maybe.clash(D.Slot, s, ef))
    case S.Pick{+o0, +s0, +i0} <> +rest:
      in.sj.cell(adr, o0, s0, i0, rest, seen, ts, ow, s, t, Bool.and(D.seat.eq(o0, ow), D.item.eq(i0, D.Jammer{})), {==}, ef, eh, mj, ef2 => eh2 => in.sj(adr, rest, ts, I.keep(D.Seat, D.item.eq(i0, D.Jammer{}), o0, seen), ow, s, t, ef2, eh2, mj))

def opts.shoot(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +t: D.Seat, mem: Id.In(S.TargetOption, S.Target{t}, G.aim.targets(p))) -> Id.In(T.IdleOption, T.ShootAt{t}, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat)):
  in.left(T.IdleOption, T.ShootAt{t}, P.shots(G.aim.targets(p)), List.append(&2, T.IdleOption, P.use.options(Id.Uses(w, p, g, seat), Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat))))), in.shots(t, G.aim.targets(p), mem))

def opts.use(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, +item: D.Item, ef: {P.use.first(Id.Uses(w, p, g, seat), item) == Some{slot} : Maybe<&2, D.Slot>}, +ec: {P.item.chained(item) == False{} : Bool}) -> Id.In(T.IdleOption, T.UseSlot{slot, item}, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat)):
  in.right(T.IdleOption, T.UseSlot{slot, item}, P.shots(G.aim.targets(p)), List.append(&2, T.IdleOption, P.use.options(Id.Uses(w, p, g, seat), Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat))))), in.left(T.IdleOption, T.UseSlot{slot, item}, P.use.options(Id.Uses(w, p, g, seat), Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat)))), in.use(Id.Uses(w, p, g, seat), Nil{}, slot, item, ef, {==}, ec)))

def jam.cast(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, +t: D.Seat, ef: {P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}) == Some{slot} : Maybe<&2, D.Slot>}, m: Id.In(T.IdleOption, T.JamWith{slot, t}, P.jam.targets(slot, I.jam.for(Id.Rec(w, p, g), seat)))) -> Id.In(T.IdleOption, T.JamWith{slot, t}, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat))):
  %Equal.sym(Maybe<&2, D.Slot>, P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), Some{slot}, ef) : Id.In(T.IdleOption, T.JamWith{slot, t}, P.jam.options(_, I.jam.for(Id.Rec(w, p, g), seat)))
  m

def opts.jam(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, +t: D.Seat, ef: {P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}) == Some{slot} : Maybe<&2, D.Slot>}, mj: Id.In(S.JamOption, S.JamAt{t}, I.jam.for(Id.Rec(w, p, g), seat))) -> Id.In(T.IdleOption, T.JamWith{slot, t}, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat)):
  in.right(T.IdleOption, T.JamWith{slot, t}, P.shots(G.aim.targets(p)), List.append(&2, T.IdleOption, P.use.options(Id.Uses(w, p, g, seat), Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat))))), in.right(T.IdleOption, T.JamWith{slot, t}, P.use.options(Id.Uses(w, p, g, seat), Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat)))), in.left(T.IdleOption, T.JamWith{slot, t}, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat))), jam.cast(w, p, l, g, seat, slot, t, ef, in.jt(slot, t, I.jam.for(Id.Rec(w, p, g), seat), mj)))))

def steal.cast(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +adr: D.Slot, +x: T.IdleOption, ea: {P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>}, m: Id.In(T.IdleOption, x, P.steal.picks(adr, I.steal.for(Id.Rec(w, p, g), seat), Nil{}))) -> Id.In(T.IdleOption, x, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat))):
  %Equal.sym(Maybe<&2, D.Slot>, P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), Some{adr}, ea) : Id.In(T.IdleOption, x, P.steal.options(_, I.steal.for(Id.Rec(w, p, g), seat)))
  m

def sj.cast(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +adr: D.Slot, +x: T.IdleOption, ea: {P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>}, m: Id.In(T.IdleOption, x, P.steal_jam.picks(adr, I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat), Nil{}))) -> Id.In(T.IdleOption, x, P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat))):
  %Equal.sym(Maybe<&2, D.Slot>, P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), Some{adr}, ea) : Id.In(T.IdleOption, x, P.steal_jam.options(_, I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat)))
  m

def opts.steal(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +adr: D.Slot, +ow: D.Seat, +s: D.Slot, +i: D.Item, ea: {P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>}, ef: {SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, i) == Some{s} : Maybe<&2, D.Slot>}, +ec: {P.item.chained(i) == False{} : Bool}) -> Id.In(T.IdleOption, T.StealWith{adr, ow, s, i}, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat)):
  in.right(T.IdleOption, T.StealWith{adr, ow, s, i}, P.shots(G.aim.targets(p)), List.append(&2, T.IdleOption, P.use.options(Id.Uses(w, p, g, seat), Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat))))), in.right(T.IdleOption, T.StealWith{adr, ow, s, i}, P.use.options(Id.Uses(w, p, g, seat), Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat)))), in.right(T.IdleOption, T.StealWith{adr, ow, s, i}, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat))), in.left(T.IdleOption, T.StealWith{adr, ow, s, i}, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat)), steal.cast(w, p, l, g, seat, adr, T.StealWith{adr, ow, s, i}, ea, in.steal(adr, I.steal.for(Id.Rec(w, p, g), seat), Nil{}, ow, s, i, ef, {==}, ec))))))

def opts.sj(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +adr: D.Slot, +ow: D.Seat, +s: D.Slot, +t: D.Seat, ea: {P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>}, ef: {SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, D.Jammer{}) == Some{s} : Maybe<&2, D.Slot>}, +mj: Id.In(S.JamOption, S.JamAt{t}, I.jam.for(Id.Rec(w, p, g), seat))) -> Id.In(T.IdleOption, T.StealJamWith{adr, ow, s, t}, P.options(T.State{w, p, T.Idle{seat}, l, g}, seat)):
  in.right(T.IdleOption, T.StealJamWith{adr, ow, s, t}, P.shots(G.aim.targets(p)), List.append(&2, T.IdleOption, P.use.options(Id.Uses(w, p, g, seat), Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat))))), in.right(T.IdleOption, T.StealJamWith{adr, ow, s, t}, P.use.options(Id.Uses(w, p, g, seat), Nil{}), List.append(&2, T.IdleOption, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat)))), in.right(T.IdleOption, T.StealJamWith{adr, ow, s, t}, P.jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), I.jam.for(Id.Rec(w, p, g), seat)), List.append(&2, T.IdleOption, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat))), in.right(T.IdleOption, T.StealJamWith{adr, ow, s, t}, P.steal.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat)), P.steal_jam.options(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat)), sj.cast(w, p, l, g, seat, adr, T.StealJamWith{adr, ow, s, t}, ea, in.sj(adr, I.steal.for(Id.Rec(w, p, g), seat), I.jam.for(Id.Rec(w, p, g), seat), Nil{}, ow, s, t, ef, {==}, mj))))))

def fix.shoot(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, +seat: D.Seat, +t: D.Seat, o: T.IdleOption, c: Canon(us, ks, o), h: {SA.move.same(P.option.move(o), T.Shoot{t}) == True{} : Bool}) -> {SA.option.steps(seat, Some{o}) == [SA.ChoiceStep{seat, D.PickUp{}}, SA.ChoiceStep{seat, D.Shoot{t}}] : List<&2, SA.Step>}:
  match o:
    case T.ShootAt{+u}:
      %Equal.sym(D.Seat, u, t, Wk.seat.eq.sound(u, t, h)) : {SA.option.steps(seat, Some{T.ShootAt{_}}) == [SA.ChoiceStep{seat, D.PickUp{}}, SA.ChoiceStep{seat, D.Shoot{t}}] : List<&2, SA.Step>}
      {==}
    case T.UseSlot{x1, x2}:
      Wk.absurd({SA.option.steps(seat, Some{T.UseSlot{x1, x2}}) == [SA.ChoiceStep{seat, D.PickUp{}}, SA.ChoiceStep{seat, D.Shoot{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.JamWith{x1, x2}:
      Wk.absurd({SA.option.steps(seat, Some{T.JamWith{x1, x2}}) == [SA.ChoiceStep{seat, D.PickUp{}}, SA.ChoiceStep{seat, D.Shoot{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.StealWith{x1, x2, x3, x4}:
      Wk.absurd({SA.option.steps(seat, Some{T.StealWith{x1, x2, x3, x4}}) == [SA.ChoiceStep{seat, D.PickUp{}}, SA.ChoiceStep{seat, D.Shoot{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.StealJamWith{x1, x2, x3, x4}:
      Wk.absurd({SA.option.steps(seat, Some{T.StealJamWith{x1, x2, x3, x4}}) == [SA.ChoiceStep{seat, D.PickUp{}}, SA.ChoiceStep{seat, D.Shoot{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))

def fix.use(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, +seat: D.Seat, +slot: D.Slot, +item: D.Item, +efirst: {SA.slot.is(P.use.first(us, item), slot) == True{} : Bool}, o: T.IdleOption, c: Canon(us, ks, o), h: {SA.move.same(P.option.move(o), T.Use{item}) == True{} : Bool}) -> {SA.option.steps(seat, Some{o}) == [SA.ChoiceStep{seat, D.UseItem{slot, item}}] : List<&2, SA.Step>}:
  match o:
    case T.UseSlot{+s, +i}:
      +ei : {i == item : D.Item} = Wk.item.eq.sound(i, item, h)
      +c2 : {P.use.first(us, item) == Some{s} : Maybe<&2, D.Slot>} = Equal.trans(Maybe<&2, D.Slot>, P.use.first(us, item), P.use.first(us, i), Some{s}, Equal.cong(D.Item, Maybe<&2, D.Slot>, v => P.use.first(us, v), item, i, Equal.sym(D.Item, i, item, ei)), c)
      +es : {s == slot : D.Slot} = some.slot(s, slot, Equal.trans(Maybe<&2, D.Slot>, Some{s}, P.use.first(us, item), Some{slot}, Equal.sym(Maybe<&2, D.Slot>, P.use.first(us, item), Some{s}, c2), slot.is.some(P.use.first(us, item), slot, efirst)))
      %Equal.sym(D.Item, i, item, ei) : {SA.option.steps(seat, Some{T.UseSlot{s, _}}) == [SA.ChoiceStep{seat, D.UseItem{slot, item}}] : List<&2, SA.Step>}
      %Equal.sym(D.Slot, s, slot, es) : {SA.option.steps(seat, Some{T.UseSlot{_, item}}) == [SA.ChoiceStep{seat, D.UseItem{slot, item}}] : List<&2, SA.Step>}
      {==}
    case T.ShootAt{x1}:
      Wk.absurd({SA.option.steps(seat, Some{T.ShootAt{x1}}) == [SA.ChoiceStep{seat, D.UseItem{slot, item}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.JamWith{x1, x2}:
      Wk.absurd({SA.option.steps(seat, Some{T.JamWith{x1, x2}}) == [SA.ChoiceStep{seat, D.UseItem{slot, item}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.StealWith{x1, x2, x3, x4}:
      Wk.absurd({SA.option.steps(seat, Some{T.StealWith{x1, x2, x3, x4}}) == [SA.ChoiceStep{seat, D.UseItem{slot, item}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.StealJamWith{x1, x2, x3, x4}:
      Wk.absurd({SA.option.steps(seat, Some{T.StealJamWith{x1, x2, x3, x4}}) == [SA.ChoiceStep{seat, D.UseItem{slot, item}}] : List<&2, SA.Step>}, Wk.bool.clash(h))

def fix.jam(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, +seat: D.Seat, +slot: D.Slot, +t: D.Seat, +efirst: {SA.slot.is(P.use.first(us, D.Jammer{}), slot) == True{} : Bool}, o: T.IdleOption, c: Canon(us, ks, o), h: {SA.move.same(P.option.move(o), T.Jam{t}) == True{} : Bool}) -> {SA.option.steps(seat, Some{o}) == [SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}:
  match o:
    case T.JamWith{+s, +u}:
      +es : {s == slot : D.Slot} = some.slot(s, slot, Equal.trans(Maybe<&2, D.Slot>, Some{s}, P.use.first(us, D.Jammer{}), Some{slot}, Equal.sym(Maybe<&2, D.Slot>, P.use.first(us, D.Jammer{}), Some{s}, c), slot.is.some(P.use.first(us, D.Jammer{}), slot, efirst)))
      %Equal.sym(D.Seat, u, t, Wk.seat.eq.sound(u, t, h)) : {SA.option.steps(seat, Some{T.JamWith{s, _}}) == [SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}
      %Equal.sym(D.Slot, s, slot, es) : {SA.option.steps(seat, Some{T.JamWith{_, t}}) == [SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}
      {==}
    case T.ShootAt{x1}:
      Wk.absurd({SA.option.steps(seat, Some{T.ShootAt{x1}}) == [SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.UseSlot{x1, x2}:
      Wk.absurd({SA.option.steps(seat, Some{T.UseSlot{x1, x2}}) == [SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.StealWith{x1, x2, x3, x4}:
      Wk.absurd({SA.option.steps(seat, Some{T.StealWith{x1, x2, x3, x4}}) == [SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.StealJamWith{x1, x2, x3, x4}:
      Wk.absurd({SA.option.steps(seat, Some{T.StealJamWith{x1, x2, x3, x4}}) == [SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))

def fix.steal(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, +seat: D.Seat, +adr: D.Slot, +ow: D.Seat, +sl: D.Slot, +i: D.Item, +eadr: {P.use.first(us, D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>}, +esl: {SA.steal.first(ks, ow, i) == Some{sl} : Maybe<&2, D.Slot>}, o: T.IdleOption, c: Canon(us, ks, o), +h: {SA.move.same(P.option.move(o), T.Steal{ow, i}) == True{} : Bool}) -> {SA.option.steps(seat, Some{o}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}] : List<&2, SA.Step>}:
  match o c:
    case T.StealWith{+a, +ow2, +s, +i2} Tuple{+ca, +cs}:
      +eo : {ow2 == ow : D.Seat} = Wk.seat.eq.sound(ow2, ow, Id.and.l(D.seat.eq(ow2, ow), D.item.eq(i2, i), h))
      +ei : {i2 == i : D.Item} = Wk.item.eq.sound(i2, i, Id.and.r(D.seat.eq(ow2, ow), D.item.eq(i2, i), h))
      +ea : {a == adr : D.Slot} = some.slot(a, adr, Equal.trans(Maybe<&2, D.Slot>, Some{a}, P.use.first(us, D.Adrenaline{}), Some{adr}, Equal.sym(Maybe<&2, D.Slot>, P.use.first(us, D.Adrenaline{}), Some{a}, ca), eadr))
      +cs2 : {SA.steal.first(ks, ow, i) == Some{s} : Maybe<&2, D.Slot>} = Equal.trans(Maybe<&2, D.Slot>, SA.steal.first(ks, ow, i), SA.steal.first(ks, ow2, i2), Some{s}, Equal.trans(Maybe<&2, D.Slot>, SA.steal.first(ks, ow, i), SA.steal.first(ks, ow2, i), SA.steal.first(ks, ow2, i2), Equal.cong(D.Seat, Maybe<&2, D.Slot>, v => SA.steal.first(ks, v, i), ow, ow2, Equal.sym(D.Seat, ow2, ow, eo)), Equal.cong(D.Item, Maybe<&2, D.Slot>, v => SA.steal.first(ks, ow2, v), i, i2, Equal.sym(D.Item, i2, i, ei))), cs)
      +es : {s == sl : D.Slot} = some.slot(s, sl, Equal.trans(Maybe<&2, D.Slot>, Some{s}, SA.steal.first(ks, ow, i), Some{sl}, Equal.sym(Maybe<&2, D.Slot>, SA.steal.first(ks, ow, i), Some{s}, cs2), esl))
      %Equal.sym(D.Slot, a, adr, ea) : {SA.option.steps(seat, Some{T.StealWith{_, ow2, s, i2}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}] : List<&2, SA.Step>}
      %Equal.sym(D.Seat, ow2, ow, eo) : {SA.option.steps(seat, Some{T.StealWith{adr, _, s, i2}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}] : List<&2, SA.Step>}
      %Equal.sym(D.Slot, s, sl, es) : {SA.option.steps(seat, Some{T.StealWith{adr, ow, _, i2}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}] : List<&2, SA.Step>}
      %Equal.sym(D.Item, i2, i, ei) : {SA.option.steps(seat, Some{T.StealWith{adr, ow, sl, _}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}] : List<&2, SA.Step>}
      {==}
    case T.ShootAt{x1} c:
      Wk.absurd({SA.option.steps(seat, Some{T.ShootAt{x1}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.UseSlot{x1, x2} c:
      Wk.absurd({SA.option.steps(seat, Some{T.UseSlot{x1, x2}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.JamWith{x1, x2} c:
      Wk.absurd({SA.option.steps(seat, Some{T.JamWith{x1, x2}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.StealJamWith{x1, x2, x3, x4} c:
      Wk.absurd({SA.option.steps(seat, Some{T.StealJamWith{x1, x2, x3, x4}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}] : List<&2, SA.Step>}, Wk.bool.clash(h))

def fix.sj(+us: List<&2, S.IdleOption>, +ks: List<&2, S.StealOption>, +seat: D.Seat, +adr: D.Slot, +ow: D.Seat, +sl: D.Slot, +t: D.Seat, +eadr: {P.use.first(us, D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>}, +esl: {SA.steal.first(ks, ow, D.Jammer{}) == Some{sl} : Maybe<&2, D.Slot>}, o: T.IdleOption, c: Canon(us, ks, o), +h: {SA.move.same(P.option.move(o), T.StealJam{ow, t}) == True{} : Bool}) -> {SA.option.steps(seat, Some{o}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}:
  match o c:
    case T.StealJamWith{+a, +ow2, +s, +u} Tuple{+ca, +cs}:
      +eo : {ow2 == ow : D.Seat} = Wk.seat.eq.sound(ow2, ow, Id.and.l(D.seat.eq(ow2, ow), D.seat.eq(u, t), h))
      +eu : {u == t : D.Seat} = Wk.seat.eq.sound(u, t, Id.and.r(D.seat.eq(ow2, ow), D.seat.eq(u, t), h))
      +ea : {a == adr : D.Slot} = some.slot(a, adr, Equal.trans(Maybe<&2, D.Slot>, Some{a}, P.use.first(us, D.Adrenaline{}), Some{adr}, Equal.sym(Maybe<&2, D.Slot>, P.use.first(us, D.Adrenaline{}), Some{a}, ca), eadr))
      +cs2 : {SA.steal.first(ks, ow, D.Jammer{}) == Some{s} : Maybe<&2, D.Slot>} = Equal.trans(Maybe<&2, D.Slot>, SA.steal.first(ks, ow, D.Jammer{}), SA.steal.first(ks, ow2, D.Jammer{}), Some{s}, Equal.cong(D.Seat, Maybe<&2, D.Slot>, v => SA.steal.first(ks, v, D.Jammer{}), ow, ow2, Equal.sym(D.Seat, ow2, ow, eo)), cs)
      +es : {s == sl : D.Slot} = some.slot(s, sl, Equal.trans(Maybe<&2, D.Slot>, Some{s}, SA.steal.first(ks, ow, D.Jammer{}), Some{sl}, Equal.sym(Maybe<&2, D.Slot>, SA.steal.first(ks, ow, D.Jammer{}), Some{s}, cs2), esl))
      %Equal.sym(D.Slot, a, adr, ea) : {SA.option.steps(seat, Some{T.StealJamWith{_, ow2, s, u}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}
      %Equal.sym(D.Seat, ow2, ow, eo) : {SA.option.steps(seat, Some{T.StealJamWith{adr, _, s, u}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}
      %Equal.sym(D.Slot, s, sl, es) : {SA.option.steps(seat, Some{T.StealJamWith{adr, ow, _, u}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}
      %Equal.sym(D.Seat, u, t, eu) : {SA.option.steps(seat, Some{T.StealJamWith{adr, ow, sl, _}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}
      {==}
    case T.ShootAt{x1} c:
      Wk.absurd({SA.option.steps(seat, Some{T.ShootAt{x1}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.UseSlot{x1, x2} c:
      Wk.absurd({SA.option.steps(seat, Some{T.UseSlot{x1, x2}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.JamWith{x1, x2} c:
      Wk.absurd({SA.option.steps(seat, Some{T.JamWith{x1, x2}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))
    case T.StealWith{x1, x2, x3, x4} c:
      Wk.absurd({SA.option.steps(seat, Some{T.StealWith{x1, x2, x3, x4}}) == [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}] : List<&2, SA.Step>}, Wk.bool.clash(h))

# The gesture side: a legal gesture from Idle has one of the five shapes.

def eg.cast(+r: List<&2, SA.Step>, +a: D.Stepped<&2, S.State>, +b: D.Stepped<&2, S.State>, e: {a == b : D.Stepped<&2, S.State>}, eg: {Bool.and(SA.gesture.then(r, M.stepped.state(a)), SA.gesture.go(r, M.stepped.state(a))) == True{} : Bool}) -> {Bool.and(SA.gesture.then(r, M.stepped.state(b)), SA.gesture.go(r, M.stepped.state(b))) == True{} : Bool}:
  %e : {Bool.and(SA.gesture.then(r, M.stepped.state(_)), SA.gesture.go(r, M.stepped.state(_))) == True{} : Bool}
  eg

def recov.cast(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +st: SA.Step, +sb: SA.Step, +r: List<&2, SA.Step>, e: {sb == st : SA.Step}, goal: {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, sb <> r) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, st <> r) == True{} : Bool}:
  %e : {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, _ <> r) == True{} : Bool}
  goal

def first.cast(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +st: SA.Step, +sb: SA.Step, +r: List<&2, SA.Step>, e: {st == sb : SA.Step}, ef: {SA.first_slots(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), st <> r) == True{} : Bool}) -> {SA.first_slots(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), sb <> r) == True{} : Bool}:
  %e : {SA.first_slots(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), _ <> r) == True{} : Bool}
  ef

def end.shoot(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +t: D.Seat, +mem: Id.In(S.TargetOption, S.Target{t}, G.aim.targets(p))) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, [SA.ChoiceStep{seat, D.PickUp{}}, SA.ChoiceStep{seat, D.Shoot{t}}]) == True{} : Bool}:
  back(w, p, l, g, seat, SA.ChoiceStep{seat, D.PickUp{}}, [SA.ChoiceStep{seat, D.Shoot{t}}], T.Shoot{t}, seated, T.ShootAt{t}, opts.shoot(w, p, l, g, seat, t, mem), Wk.seat.eq.refl(t), +o => c => h => fix.shoot(Id.Uses(w, p, g, seat), I.steal.for(Id.Rec(w, p, g), seat), seat, t, o, c, h))

def end.use(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +slot: D.Slot, +item: D.Item, +erec: {SA.recover([SA.ChoiceStep{seat, D.UseItem{slot, item}}]) == Some{T.Use{item}} : Maybe<&2, T.Move>}, +efirst: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), item), slot) == True{} : Bool}, +ec: {P.item.chained(item) == False{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, [SA.ChoiceStep{seat, D.UseItem{slot, item}}]) == True{} : Bool}:
  %Equal.sym(Maybe<&2, T.Move>, SA.recover([SA.ChoiceStep{seat, D.UseItem{slot, item}}]), Some{T.Use{item}}, erec) : {SA.recovered.move(_, T.State{w, p, T.Idle{seat}, l, g}, [SA.ChoiceStep{seat, D.UseItem{slot, item}}]) == True{} : Bool}
  back(w, p, l, g, seat, SA.ChoiceStep{seat, D.UseItem{slot, item}}, Nil{}, T.Use{item}, seated, T.UseSlot{slot, item}, opts.use(w, p, l, g, seat, slot, item, slot.is.some(P.use.first(Id.Uses(w, p, g, seat), item), slot, efirst), ec), Wk.item.eq.refl(item), +o => c => h => fix.use(Id.Uses(w, p, g, seat), I.steal.for(Id.Rec(w, p, g), seat), seat, slot, item, efirst, o, c, h))

def end.jam(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +slot: D.Slot, +t: D.Seat, +efirst: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), slot) == True{} : Bool}, +mj: Id.In(S.JamOption, S.JamAt{t}, I.jam.for(Id.Rec(w, p, g), seat))) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, [SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}]) == True{} : Bool}:
  back(w, p, l, g, seat, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}, [SA.ChoiceStep{seat, D.JamTarget{t}}], T.Jam{t}, seated, T.JamWith{slot, t}, opts.jam(w, p, l, g, seat, slot, t, slot.is.some(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), slot, efirst), mj), Wk.seat.eq.refl(t), +o => c => h => fix.jam(Id.Uses(w, p, g, seat), I.steal.for(Id.Rec(w, p, g), seat), seat, slot, t, efirst, o, c, h))

def end.steal(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +ow: D.Seat, +sl: D.Slot, +i: D.Item, +erec: {SA.recover([SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}]) == Some{T.Steal{ow, i}} : Maybe<&2, T.Move>}, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +esl: {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, i), sl) == True{} : Bool}, +ec: {P.item.chained(i) == False{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}]) == True{} : Bool}:
  +ea : {P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>} = slot.is.some(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr, eadr)
  +es : {SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, i) == Some{sl} : Maybe<&2, D.Slot>} = slot.is.some(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, i), sl, esl)
  %Equal.sym(Maybe<&2, T.Move>, SA.recover([SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}]), Some{T.Steal{ow, i}}, erec) : {SA.recovered.move(_, T.State{w, p, T.Idle{seat}, l, g}, [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}]) == True{} : Bool}
  back(w, p, l, g, seat, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, [SA.ChoiceStep{seat, D.Steal{ow, sl, i}}], T.Steal{ow, i}, seated, T.StealWith{adr, ow, sl, i}, opts.steal(w, p, l, g, seat, adr, ow, sl, i, ea, es, ec), and.tt(D.seat.eq(ow, ow), D.item.eq(i, i), Wk.seat.eq.refl(ow), Wk.item.eq.refl(i)), +o => c => h => fix.steal(Id.Uses(w, p, g, seat), I.steal.for(Id.Rec(w, p, g), seat), seat, adr, ow, sl, i, ea, es, o, c, h))

def end.sj(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +ow: D.Seat, +sl: D.Slot, +t: D.Seat, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +esl: {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, D.Jammer{}), sl) == True{} : Bool}, +mj: Id.In(S.JamOption, S.JamAt{t}, I.jam.for(Id.Rec(w, p, g), seat))) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, [SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}]) == True{} : Bool}:
  +ea : {P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}) == Some{adr} : Maybe<&2, D.Slot>} = slot.is.some(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr, eadr)
  +es : {SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, D.Jammer{}) == Some{sl} : Maybe<&2, D.Slot>} = slot.is.some(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, D.Jammer{}), sl, esl)
  back(w, p, l, g, seat, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, [SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}}, SA.ChoiceStep{seat, D.JamTarget{t}}], T.StealJam{ow, t}, seated, T.StealJamWith{adr, ow, sl, t}, opts.sj(w, p, l, g, seat, adr, ow, sl, t, ea, es, mj), and.tt(D.seat.eq(ow, ow), D.seat.eq(t, t), Wk.seat.eq.refl(ow), Wk.seat.eq.refl(t)), +o => c => h => fix.sj(Id.Uses(w, p, g, seat), I.steal.for(Id.Rec(w, p, g), seat), seat, adr, ow, sl, t, ea, es, o, c, h))

def res.cast(+table: D.Table, +seat: D.Seat, +ms: List<&2, D.Move>, +n: Nat, +k: Nat, +mv: D.Move, +mvb: D.Move, e: {mv == mvb : D.Move}, res: {D.resolve(G.seat.menu(table, seat, ms), n) == D.Chose{D.Choice{seat, k, mv}} : D.Resolved}) -> {D.resolve(G.seat.menu(table, seat, ms), n) == D.Chose{D.Choice{seat, k, mvb}} : D.Resolved}:
  %e : {D.resolve(G.seat.menu(table, seat, ms), n) == D.Chose{D.Choice{seat, k, _}} : D.Resolved}
  res

def notpick.clash(+y: S.State, +x: Bool, np: {SA.pick.phase(S.state.phase(y)) == False{} : Bool}, e: {Bool.and(SA.pick.phase(S.state.phase(y)), x) == True{} : Bool}) -> Empty:
  Wk.bool.clash(Equal.trans(Bool, False{}, Bool.and(SA.pick.phase(S.state.phase(y)), x), True{}, Equal.cong(Bool, Bool, b => Bool.and(b, x), False{}, SA.pick.phase(S.state.phase(y)), Equal.sym(Bool, SA.pick.phase(S.state.phase(y)), False{}, np)), e))

def pick.end(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +t: D.Seat, +mem: Id.In(S.TargetOption, S.Target{t}, G.aim.targets(p)), r2: List<&2, SA.Step>, eg2: {Bool.and(SA.gesture.then(r2, M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)), SA.gesture.go(r2, M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> SA.ChoiceStep{seat, D.Shoot{t}} <> r2) == True{} : Bool}:
  match r2:
    case Nil{}:
      end.shoot(w, p, l, g, seat, seated, t, mem)
    case +st3 <> +r3:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> SA.ChoiceStep{seat, D.Shoot{t}} <> st3 <> r3) == True{} : Bool}, notpick.clash(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t), SA.gesture.go(st3 <> r3, M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)), rel.notpick(N.shoot(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, t), M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t), Id.shoot.rel(w, p, g, seat, t)), eg2))

def pick.t(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +s3: D.Seat, +mv2: D.Move, +r2: List<&2, SA.Step>, +n2: Nat, +k2: Nat, +es3: {s3 == seat : D.Seat}, +res2: {D.resolve(G.seat.menu(S.world.table(w), seat, G.aim.moves(G.aim.targets(p))), n2) == D.Chose{D.Choice{seat, k2, mv2}} : D.Resolved}, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2)))) == True{} : Bool}, inv: tgt.Inv(G.aim.targets(p), mv2, k2)) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> SA.ChoiceStep{s3, mv2} <> r2) == True{} : Bool}:
  match inv:
    case Tuple{S.Target{+t}, Tuple{+enth2, Tuple{+emv2, +mem2}}}:
      +res3 : {D.resolve(G.seat.menu(S.world.table(w), seat, G.aim.moves(G.aim.targets(p))), n2) == D.Chose{D.Choice{seat, k2, D.Shoot{t}}} : D.Resolved} = res.cast(S.world.table(w), seat, G.aim.moves(G.aim.targets(p)), n2, k2, mv2, D.Shoot{t}, Equal.sym(D.Move, D.Shoot{t}, mv2, emv2), res2)
      +answered2 : {M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2) == S.state.stepped(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)) : D.Stepped<&2, S.State>} = Equal.trans(D.Stepped<&2, S.State>, M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2), S.state.stepped(M.answer.choice(S.State{w, p, S.Aim{seat}, Nil{}, g}, D.Choice{seat, k2, D.Shoot{t}})), S.state.stepped(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)), L.choose.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2, M.request(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat)), D.Choice{seat, k2, D.Shoot{t}}, res3), Equal.cong(S.State, D.Stepped<&2, S.State>, y => S.state.stepped(y), M.answer.choice(S.State{w, p, S.Aim{seat}, Nil{}, g}, D.Choice{seat, k2, D.Shoot{t}}), M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t), Id.aim.sel(w, p, g, seat, k2, t, enth2)))
      %Equal.sym(D.Seat, s3, seat, es3) : {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> SA.ChoiceStep{_, mv2} <> r2) == True{} : Bool}
      %emv2 : {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> SA.ChoiceStep{seat, _} <> r2) == True{} : Bool}
      pick.end(w, p, l, g, seat, seated, t, mem2, r2, eg.cast(r2, M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2), S.state.stepped(M.shoot(S.State{w, p, S.Aim{seat}, Nil{}, g}, seat, t)), answered2, eg))

def pick.c(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +s3: D.Seat, +mv2: D.Move, +r2: List<&2, SA.Step>, +n2: Nat, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2)))) == True{} : Bool}, cs: ChooseStep(S.world.table(w), seat, G.aim.moves(G.aim.targets(p)), s3, mv2, n2)) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> SA.ChoiceStep{s3, mv2} <> r2) == True{} : Bool}:
  match cs:
    case Tuple{+k2, Tuple{+ek2, Tuple{+es3, Tuple{_, +res2}}}}:
      pick.t(w, p, l, g, seat, seated, s3, mv2, r2, n2, k2, es3, res2, eg, tgt.inv(G.aim.targets(p), mv2, k2, ek2))

def pick.s(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), st2: SA.Step, +r2: List<&2, SA.Step>, +n2: Nat, +el2: {SA.walk.legal(M.request(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat)), st2) == Some{n2} : Maybe<&2, Nat>}, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), n2)))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> st2 <> r2) == True{} : Bool}:
  match st2:
    case SA.DrawStep{+a}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> SA.DrawStep{a} <> r2) == True{} : Bool}, draw.notlegal(S.world.table(w), seat, G.aim.moves(G.aim.targets(p)), a, n2, el2))
    case SA.ChoiceStep{+s3, +mv2}:
      pick.c(w, p, l, g, seat, seated, s3, mv2, r2, n2, eg, choose.step(S.world.table(w), seat, G.aim.moves(G.aim.targets(p)), s3, mv2, n2, el2))

def pick.l(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +st2: SA.Step, +r2: List<&2, SA.Step>, l2: Maybe<&2, Nat>, +el2: {SA.walk.legal(M.request(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat)), st2) == l2 : Maybe<&2, Nat>}, eg: {SA.gesture.answer(l2, M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat), +next => Bool.and(SA.gesture.then(r2, next), SA.gesture.go(r2, next))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> st2 <> r2) == True{} : Bool}:
  match l2:
    case None{}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> st2 <> r2) == True{} : Bool}, Wk.bool.clash(eg))
    case Some{+n2}:
      pick.s(w, p, l, g, seat, seated, st2, r2, n2, el2, eg)

def cont.pick(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), r1: List<&2, SA.Step>, eg: {Bool.and(SA.gesture.then(r1, M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat)), SA.gesture.go(r1, M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.PickUp{}} <> r1) == True{} : Bool}:
  match r1:
    case Nil{}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, [SA.ChoiceStep{seat, D.PickUp{}}]) == True{} : Bool}, Wk.bool.clash(eg))
    case +st2 <> +r2:
      pick.l(w, p, l, g, seat, seated, st2, r2, SA.walk.legal(M.request(M.pickup(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat)), st2), {==}, eg)

def cont.plain(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +slot: D.Slot, +item: D.Item, +erec: {SA.recover([SA.ChoiceStep{seat, D.UseItem{slot, item}}]) == Some{T.Use{item}} : Maybe<&2, T.Move>}, +efirst: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), item), slot) == True{} : Bool}, +ec: {P.item.chained(item) == False{} : Bool}, +plain: C.Plain(item), r1: List<&2, SA.Step>, eg: {Bool.and(SA.gesture.then(r1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item)), SA.gesture.go(r1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, item}} <> r1) == True{} : Bool}:
  match r1:
    case Nil{}:
      end.use(w, p, l, g, seat, seated, slot, item, erec, efirst, ec)
    case +st2 <> +r2:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, item}} <> st2 <> r2) == True{} : Bool}, notpick.clash(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item), SA.gesture.go(st2 <> r2, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item)), rel.notpick(N.item.use(T.State{w, p, T.Idle{seat}, T.Empty{}, g}, seat, seat, slot, item), M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, item), Id.use.rel(T.Empty{}, w, p, T.Idle{seat}, g, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, seat, seat, slot, item, plain)), eg))

def jam.end(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +slot: D.Slot, +t: D.Seat, +efirst: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), slot) == True{} : Bool}, +mem: Id.In(S.JamOption, S.JamAt{t}, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)), r2: List<&2, SA.Step>, eg2: {Bool.and(SA.gesture.then(r2, M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), SA.gesture.go(r2, M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> SA.ChoiceStep{seat, D.JamTarget{t}} <> r2) == True{} : Bool}:
  match r2:
    case Nil{}:
      end.jam(w, p, l, g, seat, seated, slot, t, efirst, Id.in.cast(S.JamOption, S.JamAt{t}, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat), I.jam.for(Id.Rec(w, p, g), seat), Id.jamfor.slots(w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], S.Blocked{None{}}, Nil{}, g, seat, I.slots.put(I.seat.slots(p, seat), slot, None{}), seat), mem))
    case +st3 <> +r3:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> SA.ChoiceStep{seat, D.JamTarget{t}} <> st3 <> r3) == True{} : Bool}, notpick.clash(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), SA.gesture.go(st3 <> r3, M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), {==}, eg2))

def jam.t(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +slot: D.Slot, +efirst: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), slot) == True{} : Bool}, +s3: D.Seat, +mv2: D.Move, +r2: List<&2, SA.Step>, +n2: Nat, +k2: Nat, +es3: {s3 == seat : D.Seat}, +res2: {D.resolve(G.seat.menu(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat))), n2) == D.Chose{D.Choice{seat, k2, mv2}} : D.Resolved}, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2)))) == True{} : Bool}, inv: jmo.Inv(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat), mv2, k2)) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> SA.ChoiceStep{s3, mv2} <> r2) == True{} : Bool}:
  match inv:
    case Tuple{S.JamAt{+t}, Tuple{+enth2, Tuple{+emv2, +mem2}}}:
      +res3 : {D.resolve(G.seat.menu(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat))), n2) == D.Chose{D.Choice{seat, k2, D.JamTarget{t}}} : D.Resolved} = res.cast(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)), n2, k2, mv2, D.JamTarget{t}, Equal.sym(D.Move, D.JamTarget{t}, mv2, emv2), res2)
      +answered2 : {M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2) == S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})) : D.Stepped<&2, S.State>} = Equal.trans(D.Stepped<&2, S.State>, M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2), S.state.stepped(M.answer.choice(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, D.Choice{seat, k2, D.JamTarget{t}})), S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), L.choose.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2, M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), D.Choice{seat, k2, D.JamTarget{t}}, res3), Equal.cong(S.State, D.Stepped<&2, S.State>, y => S.state.stepped(y), M.answer.choice(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, D.Choice{seat, k2, D.JamTarget{t}}), M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), Id.jam.sel(w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), g, seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat), k2, t, enth2)))
      %Equal.sym(D.Seat, s3, seat, es3) : {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> SA.ChoiceStep{_, mv2} <> r2) == True{} : Bool}
      %emv2 : {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> SA.ChoiceStep{seat, _} <> r2) == True{} : Bool}
      jam.end(w, p, l, g, seat, seated, slot, t, efirst, mem2, r2, eg.cast(r2, M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2), S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), answered2, eg))

def jam.c(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +slot: D.Slot, +efirst: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), slot) == True{} : Bool}, +s3: D.Seat, +mv2: D.Move, +r2: List<&2, SA.Step>, +n2: Nat, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2)))) == True{} : Bool}, cs: ChooseStep(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)), s3, mv2, n2)) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> SA.ChoiceStep{s3, mv2} <> r2) == True{} : Bool}:
  match cs:
    case Tuple{+k2, Tuple{+ek2, Tuple{+es3, Tuple{_, +res2}}}}:
      jam.t(w, p, l, g, seat, seated, slot, efirst, s3, mv2, r2, n2, k2, es3, res2, eg, jmo.inv(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat), mv2, k2, ek2))

def jam.s(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +slot: D.Slot, +efirst: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), slot) == True{} : Bool}, st2: SA.Step, +r2: List<&2, SA.Step>, +n2: Nat, +el2: {SA.walk.legal(M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), st2) == Some{n2} : Maybe<&2, Nat>}, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), n2)))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> st2 <> r2) == True{} : Bool}:
  match st2:
    case SA.DrawStep{+a}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> SA.DrawStep{a} <> r2) == True{} : Bool}, draw.notlegal(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)), a, n2, el2))
    case SA.ChoiceStep{+s3, +mv2}:
      jam.c(w, p, l, g, seat, seated, slot, efirst, s3, mv2, r2, n2, eg, choose.step(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), slot, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, slot, D.Jammer{}}}], g}, seat)), s3, mv2, n2, el2))

def jam.l(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +slot: D.Slot, +efirst: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), slot) == True{} : Bool}, +st2: SA.Step, +r2: List<&2, SA.Step>, l2: Maybe<&2, Nat>, +el2: {SA.walk.legal(M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), st2) == l2 : Maybe<&2, Nat>}, eg: {SA.gesture.answer(l2, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}), +next => Bool.and(SA.gesture.then(r2, next), SA.gesture.go(r2, next))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> st2 <> r2) == True{} : Bool}:
  match l2:
    case None{}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> st2 <> r2) == True{} : Bool}, Wk.bool.clash(eg))
    case Some{+n2}:
      jam.s(w, p, l, g, seat, seated, slot, efirst, st2, r2, n2, el2, eg)

def cont.jam(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +slot: D.Slot, +efirst: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Jammer{}), slot) == True{} : Bool}, r1: List<&2, SA.Step>, eg: {Bool.and(SA.gesture.then(r1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), SA.gesture.go(r1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{}))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}} <> r1) == True{} : Bool}:
  match r1:
    case Nil{}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, [SA.ChoiceStep{seat, D.UseItem{slot, D.Jammer{}}}]) == True{} : Bool}, Wk.bool.clash(eg))
    case +st2 <> +r2:
      jam.l(w, p, l, g, seat, seated, slot, efirst, st2, r2, SA.walk.legal(M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, slot, D.Jammer{})), st2), {==}, eg)

def in.split.tail(-A: Data, +x: A, +y: A, +rest: List<&2, A>, +ys: List<&2, A>, r: Either<&2, &2, Id.In(A, x, rest), Id.In(A, x, ys)>) -> Either<&2, &2, Id.In(A, x, y <> rest), Id.In(A, x, ys)>:
  match r:
    case Inl{a}:
      Inl{Inr{a}}
    case Inr{b}:
      Inr{b}

def in.split(-A: Data, +x: A, xs: List<&2, A>, +ys: List<&2, A>, m: Id.In(A, x, List.append(&2, A, xs, ys))) -> Either<&2, &2, Id.In(A, x, xs), Id.In(A, x, ys)>:
  match xs m:
    case Nil{} m:
      Inr{m}
    case y <> rest Inl{e}:
      Inl{Inl{e}}
    case +y <> +rest Inr{mr}:
      in.split.tail(A, x, y, rest, ys, in.split(A, x, rest, ys, mr))

def stl.item(o: S.StealOption) -> D.Item:
  match o:
    case S.Pick{_, _, i}:
      i

def keep.noadr(+o: D.Seat, +s: D.Slot, b: Bool, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +ne: {D.item.eq(item, D.Adrenaline{}) == False{} : Bool}, +rest: List<&2, S.StealOption>, m: Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, I.keep(S.StealOption, b, S.Pick{owner, slot, item}, rest))) -> Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, rest):
  match b m:
    case False{} m:
      m
    case True{} Inl{+e}:
      +ei : {D.Adrenaline{} == item : D.Item} = Equal.cong(S.StealOption, D.Item, stl.item, S.Pick{o, s, D.Adrenaline{}}, S.Pick{owner, slot, item}, e)
      Wk.absurd(Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, rest), bool.clash2(Equal.trans(Bool, D.item.eq(D.Adrenaline{}, D.Adrenaline{}), D.item.eq(item, D.Adrenaline{}), False{}, Equal.cong(D.Item, Bool, v => D.item.eq(v, D.Adrenaline{}), D.Adrenaline{}, item, ei), ne)))
    case True{} Inr{r}:
      r

def here.noadr(+o: D.Seat, +s: D.Slot, found: Maybe<&2, D.Item>, +owner: D.Seat, +slot: D.Slot, +sawed: Bool, +targets: Bool, +rest: List<&2, S.StealOption>, m: Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, I.steal.here(found, owner, slot, sawed, targets, rest))) -> Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, rest):
  match found:
    case None{}:
      m
    case Some{item}:
      match item:
        case D.Adrenaline{}:
          m
        case D.Saw{}:
          keep.noadr(o, s, I.steal.fits(D.Saw{}, sawed, targets), owner, slot, D.Saw{}, {==}, rest, m)
        case D.Glass{}:
          keep.noadr(o, s, I.steal.fits(D.Glass{}, sawed, targets), owner, slot, D.Glass{}, {==}, rest, m)
        case D.Jammer{}:
          keep.noadr(o, s, I.steal.fits(D.Jammer{}, sawed, targets), owner, slot, D.Jammer{}, {==}, rest, m)
        case D.Cigarettes{}:
          keep.noadr(o, s, I.steal.fits(D.Cigarettes{}, sawed, targets), owner, slot, D.Cigarettes{}, {==}, rest, m)
        case D.Beer{}:
          keep.noadr(o, s, I.steal.fits(D.Beer{}, sawed, targets), owner, slot, D.Beer{}, {==}, rest, m)
        case D.Phone{}:
          keep.noadr(o, s, I.steal.fits(D.Phone{}, sawed, targets), owner, slot, D.Phone{}, {==}, rest, m)
        case D.Inverter{}:
          keep.noadr(o, s, I.steal.fits(D.Inverter{}, sawed, targets), owner, slot, D.Inverter{}, {==}, rest, m)
        case D.Remote{}:
          keep.noadr(o, s, I.steal.fits(D.Remote{}, sawed, targets), owner, slot, D.Remote{}, {==}, rest, m)

def slots.noadr(+o: D.Seat, +s: D.Slot, slots: List<&2, D.Slot>, +inv: D.Slots, +owner: D.Seat, +sawed: Bool, +targets: Bool, m: Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, I.steal.slots(slots, inv, owner, sawed, targets))) -> Empty:
  match slots:
    case Nil{}:
      m
    case +slot <> +rest:
      slots.noadr(o, s, rest, inv, owner, sawed, targets, here.noadr(o, s, D.slots.get(inv, slot), owner, slot, sawed, targets, I.steal.slots(rest, inv, owner, sawed, targets), m))

def owner.split(+o: D.Seat, +s: D.Slot, +inv: D.Slots, +owner: D.Seat, +sawed: Bool, +targets: Bool, +rest: List<&2, S.StealOption>, ih: @m:Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, rest) -> Empty, e: Either<&2, &2, Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, I.steal.slots(I.slot.order(), inv, owner, sawed, targets)), Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, rest)>) -> Empty:
  match e:
    case Inl{ml}:
      slots.noadr(o, s, I.slot.order(), inv, owner, sawed, targets, ml)
    case Inr{mr}:
      ih(mr)

def owner.noadr(+o: D.Seat, +s: D.Slot, own: Bool, +owner: D.Seat, +inv: D.Slots, +sawed: Bool, +targets: Bool, +rest: List<&2, S.StealOption>, ih: @m:Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, rest) -> Empty, m: Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, I.steal.owner(own, owner, inv, sawed, targets, rest))) -> Empty:
  match own:
    case True{}:
      ih(m)
    case False{}:
      owner.split(o, s, inv, owner, sawed, targets, rest, ih, in.split(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, I.steal.slots(I.slot.order(), inv, owner, sawed, targets), rest, m))

def owners.noadr(+o: D.Seat, +s: D.Slot, entries: List<&2, D.At<&2, D.Slots>>, +thief: D.Seat, +sawed: Bool, +targets: Bool, m: Id.In(S.StealOption, S.Pick{o, s, D.Adrenaline{}}, I.steal.owners(entries, thief, sawed, targets))) -> Empty:
  match entries:
    case Nil{}:
      m
    case D.At{+owner, +inv} <> +rest:
      owner.noadr(o, s, D.seat.eq(owner, thief), owner, inv, sawed, targets, I.steal.owners(rest, thief, sawed, targets), m2 => owners.noadr(o, s, rest, thief, sawed, targets, m2), m)

def sjx.end(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +ow: D.Seat, +sl: D.Slot, +esl: {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, D.Jammer{}), sl) == True{} : Bool}, +t: D.Seat, +mem: Id.In(S.JamOption, S.JamAt{t}, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)), r3: List<&2, SA.Step>, eg3: {Bool.and(SA.gesture.then(r3, M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), SA.gesture.go(r3, M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> SA.ChoiceStep{seat, D.JamTarget{t}} <> r3) == True{} : Bool}:
  match r3:
    case Nil{}:
      end.sj(w, p, l, g, seat, seated, adr, ow, sl, t, eadr, esl, Id.in.cast(S.JamOption, S.JamAt{t}, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat), I.jam.for(Id.Rec(w, p, g), seat), Equal.trans(List<&2, S.JamOption>, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat), I.jam.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Blocked{None{}}, Nil{}, g}, seat), I.jam.for(Id.Rec(w, p, g), seat), Id.jamfor.slots(w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], S.Blocked{None{}}, Nil{}, g, ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{}), seat), Id.jamfor.slots(w, p, S.Blocked{None{}}, Nil{}, S.Blocked{None{}}, Nil{}, g, seat, I.slots.put(I.seat.slots(p, seat), adr, None{}), seat)), mem))
    case +st4 <> +r4:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> SA.ChoiceStep{seat, D.JamTarget{t}} <> st4 <> r4) == True{} : Bool}, notpick.clash(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), SA.gesture.go(st4 <> r4, M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), {==}, eg3))

def sjx.t(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +ow: D.Seat, +sl: D.Slot, +esl: {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, D.Jammer{}), sl) == True{} : Bool}, +s3: D.Seat, +mv2: D.Move, +r2: List<&2, SA.Step>, +n2: Nat, +k2: Nat, +es3: {s3 == seat : D.Seat}, +res2: {D.resolve(G.seat.menu(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat))), n2) == D.Chose{D.Choice{seat, k2, mv2}} : D.Resolved}, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), n2)))) == True{} : Bool}, inv: jmo.Inv(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat), mv2, k2)) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> SA.ChoiceStep{s3, mv2} <> r2) == True{} : Bool}:
  match inv:
    case Tuple{S.JamAt{+t}, Tuple{+enth2, Tuple{+emv2, +mem2}}}:
      +res3 : {D.resolve(G.seat.menu(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat))), n2) == D.Chose{D.Choice{seat, k2, D.JamTarget{t}}} : D.Resolved} = res.cast(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)), n2, k2, mv2, D.JamTarget{t}, Equal.sym(D.Move, D.JamTarget{t}, mv2, emv2), res2)
      +answered : {M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), n2) == S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})) : D.Stepped<&2, S.State>} = Equal.trans(D.Stepped<&2, S.State>, M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), n2), S.state.stepped(M.answer.choice(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)}, Nil{}, g}, D.Choice{seat, k2, D.JamTarget{t}})), S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), L.choose.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), n2, M.request(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{})), D.Choice{seat, k2, D.JamTarget{t}}, res3), Equal.cong(S.State, D.Stepped<&2, S.State>, y => S.state.stepped(y), M.answer.choice(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)}, Nil{}, g}, D.Choice{seat, k2, D.JamTarget{t}}), M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}}), Id.jam.sel(w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), g, seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat), k2, t, enth2)))
      %Equal.sym(D.Seat, s3, seat, es3) : {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> SA.ChoiceStep{_, mv2} <> r2) == True{} : Bool}
      %emv2 : {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> SA.ChoiceStep{seat, _} <> r2) == True{} : Bool}
      sjx.end(w, p, l, g, seat, seated, adr, eadr, ow, sl, esl, t, mem2, r2, eg.cast(r2, M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), n2), S.state.stepped(M.jam.selected(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.JamPick{seat, I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)}, Nil{}, g}, seat, Some{S.JamAt{t}})), answered, eg))

def sjx.c(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +ow: D.Seat, +sl: D.Slot, +esl: {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, D.Jammer{}), sl) == True{} : Bool}, +s3: D.Seat, +mv2: D.Move, +r2: List<&2, SA.Step>, +n2: Nat, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), n2)))) == True{} : Bool}, cs: ChooseStep(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)), s3, mv2, n2)) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> SA.ChoiceStep{s3, mv2} <> r2) == True{} : Bool}:
  match cs:
    case Tuple{+k2, Tuple{+ek2, Tuple{+es3, Tuple{_, +res2}}}}:
      sjx.t(w, p, l, g, seat, seated, adr, eadr, ow, sl, esl, s3, mv2, r2, n2, k2, es3, res2, eg, jmo.inv(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat), mv2, k2, ek2))

def sjx.s(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +ow: D.Seat, +sl: D.Slot, +esl: {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, D.Jammer{}), sl) == True{} : Bool}, st2: SA.Step, +r2: List<&2, SA.Step>, +n2: Nat, +el2: {SA.walk.legal(M.request(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{})), st2) == Some{n2} : Maybe<&2, Nat>}, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), n2)))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> st2 <> r2) == True{} : Bool}:
  match st2:
    case SA.DrawStep{+a}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> SA.DrawStep{a} <> r2) == True{} : Bool}, draw.notlegal(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)), a, n2, el2))
    case SA.ChoiceStep{+s3, +mv2}:
      sjx.c(w, p, l, g, seat, seated, adr, eadr, ow, sl, esl, s3, mv2, r2, n2, eg, choose.step(S.world.table(w), seat, I.jam.moves(I.jam.for(S.State{w, S.players.set_slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow, I.slots.put(I.seat.slots(S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), ow), sl, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, [D.Shown{D.Used{seat, ow, sl, D.Jammer{}}}], g}, seat)), s3, mv2, n2, el2))

def sjx.l(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +ow: D.Seat, +sl: D.Slot, +esl: {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, D.Jammer{}), sl) == True{} : Bool}, +st2: SA.Step, +r2: List<&2, SA.Step>, l2: Maybe<&2, Nat>, +el2: {SA.walk.legal(M.request(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{})), st2) == l2 : Maybe<&2, Nat>}, eg: {SA.gesture.answer(l2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}), +next => Bool.and(SA.gesture.then(r2, next), SA.gesture.go(r2, next))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> st2 <> r2) == True{} : Bool}:
  match l2:
    case None{}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> st2 <> r2) == True{} : Bool}, Wk.bool.clash(eg))
    case Some{+n2}:
      sjx.s(w, p, l, g, seat, seated, adr, eadr, ow, sl, esl, st2, r2, n2, el2, eg)

def cont.sj(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +ow: D.Seat, +sl: D.Slot, +esl: {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, D.Jammer{}), sl) == True{} : Bool}, r2: List<&2, SA.Step>, eg: {Bool.and(SA.gesture.then(r2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{})), SA.gesture.go(r2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{}))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> r2) == True{} : Bool}:
  match r2:
    case Nil{}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Jammer{}}} <> Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
    case +st3 <> +r3:
      sjx.l(w, p, l, g, seat, seated, adr, eadr, ow, sl, esl, st3, r3, SA.walk.legal(M.request(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, D.Jammer{})), st3), {==}, eg)

def adr.plain(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +ow: D.Seat, +sl: D.Slot, +i: D.Item, +erec: {SA.recover([SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}}, SA.ChoiceStep{seat, D.Steal{ow, sl, i}}]) == Some{T.Steal{ow, i}} : Maybe<&2, T.Move>}, +esl: {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, i), sl) == True{} : Bool}, +ec: {P.item.chained(i) == False{} : Bool}, +plain: C.Plain(i), r2: List<&2, SA.Step>, eg2: {Bool.and(SA.gesture.then(r2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, i)), SA.gesture.go(r2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, i))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, i}} <> r2) == True{} : Bool}:
  match r2:
    case Nil{}:
      end.steal(w, p, l, g, seat, seated, adr, ow, sl, i, erec, eadr, esl, ec)
    case +st3 <> +r3:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, i}} <> st3 <> r3) == True{} : Bool}, notpick.clash(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, i), SA.gesture.go(st3 <> r3, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, i)), rel.notpick(N.item.use(T.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, T.Empty{}, g}, seat, ow, sl, i), M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, i), Id.use.rel(T.Snoc{T.Empty{}, D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}}, w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), T.Idle{seat}, g, S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, seat, ow, sl, i, plain)), eg2))

def adr.item(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +ow: D.Seat, +sl: D.Slot, i: D.Item, +esl: {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, i), sl) == True{} : Bool}, +mem: Id.In(S.StealOption, S.Pick{ow, sl, i}, I.steal.for(Id.Rec(w, p, g), seat)), r2: List<&2, SA.Step>, eg2: {Bool.and(SA.gesture.then(r2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, i)), SA.gesture.go(r2, M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, i))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, i}} <> r2) == True{} : Bool}:
  match i:
    case D.Adrenaline{}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, D.Steal{ow, sl, D.Adrenaline{}}} <> r2) == True{} : Bool}, owners.noadr(ow, sl, D.ring.entries(D.Slots, S.players.slots(p)), seat, S.world.sawed(w), I.jam.any(I.jam.for(Id.Rec(w, p, g), seat)), mem))
    case D.Jammer{}:
      cont.sj(w, p, l, g, seat, seated, adr, eadr, ow, sl, esl, r2, eg2)
    case D.Saw{}:
      adr.plain(w, p, l, g, seat, seated, adr, eadr, ow, sl, D.Saw{}, {==}, esl, {==}, Unit{}, r2, eg2)
    case D.Glass{}:
      adr.plain(w, p, l, g, seat, seated, adr, eadr, ow, sl, D.Glass{}, {==}, esl, {==}, Unit{}, r2, eg2)
    case D.Cigarettes{}:
      adr.plain(w, p, l, g, seat, seated, adr, eadr, ow, sl, D.Cigarettes{}, {==}, esl, {==}, Unit{}, r2, eg2)
    case D.Beer{}:
      adr.plain(w, p, l, g, seat, seated, adr, eadr, ow, sl, D.Beer{}, {==}, esl, {==}, Unit{}, r2, eg2)
    case D.Phone{}:
      adr.plain(w, p, l, g, seat, seated, adr, eadr, ow, sl, D.Phone{}, {==}, esl, {==}, Unit{}, r2, eg2)
    case D.Inverter{}:
      adr.plain(w, p, l, g, seat, seated, adr, eadr, ow, sl, D.Inverter{}, {==}, esl, {==}, Unit{}, r2, eg2)
    case D.Remote{}:
      adr.plain(w, p, l, g, seat, seated, adr, eadr, ow, sl, D.Remote{}, {==}, esl, {==}, Unit{}, r2, eg2)

def fs.cast(+s3: D.Seat, +mv2: D.Move, +mvb: D.Move, +r2: List<&2, SA.Step>, +ks: List<&2, S.StealOption>, e: {mv2 == mvb : D.Move}, ef: {SA.first.steal(SA.ChoiceStep{s3, mv2} <> r2, ks) == True{} : Bool}) -> {SA.first.steal(SA.ChoiceStep{s3, mvb} <> r2, ks) == True{} : Bool}:
  %e : {SA.first.steal(SA.ChoiceStep{s3, _} <> r2, ks) == True{} : Bool}
  ef

def adrx.t(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +s3: D.Seat, +mv2: D.Move, +r2: List<&2, SA.Step>, +ef: {SA.first.steal(SA.ChoiceStep{s3, mv2} <> r2, I.steal.for(Id.Rec(w, p, g), seat)) == True{} : Bool}, +n2: Nat, +k2: Nat, +es3: {s3 == seat : D.Seat}, +res2: {D.resolve(G.seat.menu(S.world.table(w), seat, I.steal.moves(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat))), n2) == D.Chose{D.Choice{seat, k2, mv2}} : D.Resolved}, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2)))) == True{} : Bool}, inv: stl.Inv(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), mv2, k2)) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{s3, mv2} <> r2) == True{} : Bool}:
  match inv:
    case Tuple{S.Pick{+ow, +sl, +i}, Tuple{+enth2, Tuple{+emv2, +mem2}}}:
      +mvs : D.Move = D.Steal{ow, sl, i}
      +res3 : {D.resolve(G.seat.menu(S.world.table(w), seat, I.steal.moves(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat))), n2) == D.Chose{D.Choice{seat, k2, D.Steal{ow, sl, i}}} : D.Resolved} = res.cast(S.world.table(w), seat, I.steal.moves(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)), n2, k2, mv2, D.Steal{ow, sl, i}, Equal.sym(D.Move, D.Steal{ow, sl, i}, mv2, emv2), res2)
      +answered : {M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2) == S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, i)) : D.Stepped<&2, S.State>} = Id.steal.answered(w, p, l, g, seat, adr, ow, sl, i, n2, k2, res3, enth2)
      +esl : {SA.slot.is(SA.steal.first(I.steal.for(Id.Rec(w, p, g), seat), ow, i), sl) == True{} : Bool} = fs.cast(s3, mv2, D.Steal{ow, sl, i}, r2, I.steal.for(Id.Rec(w, p, g), seat), Equal.sym(D.Move, D.Steal{ow, sl, i}, mv2, emv2), ef)
      +mks : Id.In(S.StealOption, S.Pick{ow, sl, i}, I.steal.for(Id.Rec(w, p, g), seat)) = Id.in.cast(S.StealOption, S.Pick{ow, sl, i}, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), I.steal.for(Id.Rec(w, p, g), seat), Id.stealfor.slots(w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], S.Blocked{None{}}, Nil{}, g, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), mem2)
      %Equal.sym(D.Seat, s3, seat, es3) : {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{_, mv2} <> r2) == True{} : Bool}
      %emv2 : {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{seat, _} <> r2) == True{} : Bool}
      adr.item(w, p, l, g, seat, seated, adr, eadr, ow, sl, i, esl, mks, r2, eg.cast(r2, M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2), S.state.stepped(M.item.use(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.StealPick{seat, I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)}, Nil{}, g}, seat, ow, sl, i)), answered, eg))

def adrx.c(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +s3: D.Seat, +mv2: D.Move, +r2: List<&2, SA.Step>, +ef: {SA.first.steal(SA.ChoiceStep{s3, mv2} <> r2, I.steal.for(Id.Rec(w, p, g), seat)) == True{} : Bool}, +n2: Nat, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2)))) == True{} : Bool}, cs: ChooseStep(S.world.table(w), seat, I.steal.moves(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)), s3, mv2, n2)) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.ChoiceStep{s3, mv2} <> r2) == True{} : Bool}:
  match cs:
    case Tuple{+k2, Tuple{+ek2, Tuple{+es3, Tuple{_, +res2}}}}:
      adrx.t(w, p, l, g, seat, seated, adr, eadr, s3, mv2, r2, ef, n2, k2, es3, res2, eg, stl.inv(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat), mv2, k2, ek2))

def adrx.s(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, st2: SA.Step, +r2: List<&2, SA.Step>, +ef: {SA.first.steal(st2 <> r2, I.steal.for(Id.Rec(w, p, g), seat)) == True{} : Bool}, +n2: Nat, +el2: {SA.walk.legal(M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), st2) == Some{n2} : Maybe<&2, Nat>}, eg: {Bool.and(SA.gesture.then(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2))), SA.gesture.go(r2, M.stepped.state(M.answer(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), n2)))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> st2 <> r2) == True{} : Bool}:
  match st2:
    case SA.DrawStep{+a}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> SA.DrawStep{a} <> r2) == True{} : Bool}, draw.notlegal(S.world.table(w), seat, I.steal.moves(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)), a, n2, el2))
    case SA.ChoiceStep{+s3, +mv2}:
      adrx.c(w, p, l, g, seat, seated, adr, eadr, s3, mv2, r2, ef, n2, eg, choose.step(S.world.table(w), seat, I.steal.moves(I.steal.for(S.State{w, S.players.set_slots(p, seat, I.slots.put(I.seat.slots(p, seat), adr, None{})), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, [D.Shown{D.Used{seat, seat, adr, D.Adrenaline{}}}], g}, seat)), s3, mv2, n2, el2))

def adrx.l(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, +st2: SA.Step, +r2: List<&2, SA.Step>, +ef: {SA.first.steal(st2 <> r2, I.steal.for(Id.Rec(w, p, g), seat)) == True{} : Bool}, l2: Maybe<&2, Nat>, +el2: {SA.walk.legal(M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), st2) == l2 : Maybe<&2, Nat>}, eg: {SA.gesture.answer(l2, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}), +next => Bool.and(SA.gesture.then(r2, next), SA.gesture.go(r2, next))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> st2 <> r2) == True{} : Bool}:
  match l2:
    case None{}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> st2 <> r2) == True{} : Bool}, Wk.bool.clash(eg))
    case Some{+n2}:
      adrx.s(w, p, l, g, seat, seated, adr, eadr, st2, r2, ef, n2, el2, eg)

def cont.adr(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +adr: D.Slot, +eadr: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), D.Adrenaline{}), adr) == True{} : Bool}, r1: List<&2, SA.Step>, +ef: {SA.first.steal(r1, I.steal.for(Id.Rec(w, p, g), seat)) == True{} : Bool}, eg: {Bool.and(SA.gesture.then(r1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), SA.gesture.go(r1, M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{}))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> r1) == True{} : Bool}:
  match r1:
    case Nil{}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{adr, D.Adrenaline{}}} <> Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
    case +st2 <> +r2:
      adrx.l(w, p, l, g, seat, seated, adr, eadr, st2, r2, ef, SA.walk.legal(M.request(M.item.use(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, seat, adr, D.Adrenaline{})), st2), {==}, eg)

def front.use(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +slot: D.Slot, item: D.Item, +efirst: {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), item), slot) == True{} : Bool}, +r1: List<&2, SA.Step>, +efs: {SA.first.steal(r1, I.steal.for(Id.Rec(w, p, g), seat)) == True{} : Bool}, eg: {Bool.and(SA.gesture.then(r1, M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{S.UseAt{slot, item}})), SA.gesture.go(r1, M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{S.UseAt{slot, item}}))) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, D.UseItem{slot, item}} <> r1) == True{} : Bool}:
  match item:
    case D.Jammer{}:
      cont.jam(w, p, l, g, seat, seated, slot, efirst, r1, eg)
    case D.Adrenaline{}:
      cont.adr(w, p, l, g, seat, seated, slot, efirst, r1, efs, eg)
    case D.Saw{}:
      cont.plain(w, p, l, g, seat, seated, slot, D.Saw{}, {==}, efirst, {==}, Unit{}, r1, eg)
    case D.Glass{}:
      cont.plain(w, p, l, g, seat, seated, slot, D.Glass{}, {==}, efirst, {==}, Unit{}, r1, eg)
    case D.Cigarettes{}:
      cont.plain(w, p, l, g, seat, seated, slot, D.Cigarettes{}, {==}, efirst, {==}, Unit{}, r1, eg)
    case D.Beer{}:
      cont.plain(w, p, l, g, seat, seated, slot, D.Beer{}, {==}, efirst, {==}, Unit{}, r1, eg)
    case D.Phone{}:
      cont.plain(w, p, l, g, seat, seated, slot, D.Phone{}, {==}, efirst, {==}, Unit{}, r1, eg)
    case D.Inverter{}:
      cont.plain(w, p, l, g, seat, seated, slot, D.Inverter{}, {==}, efirst, {==}, Unit{}, r1, eg)
    case D.Remote{}:
      cont.plain(w, p, l, g, seat, seated, slot, D.Remote{}, {==}, efirst, {==}, Unit{}, r1, eg)

def front.opt(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), o: S.IdleOption, +r1: List<&2, SA.Step>, eg: {Bool.and(SA.gesture.then(r1, M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{o})), SA.gesture.go(r1, M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{o}))) == True{} : Bool}, +ef: {SA.first_slots(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{seat, Id.opt.mv(o)} <> r1) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{seat, Id.opt.mv(o)} <> r1) == True{} : Bool}:
  match o:
    case S.TakeGun{}:
      cont.pick(w, p, l, g, seat, seated, r1, eg)
    case S.UseAt{+slot, +item}:
      +efirst : {SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), item), slot) == True{} : Bool} = Id.and.l(SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), item), slot), SA.first.steal(r1, I.steal.for(Id.Rec(w, p, g), seat)), ef)
      +efs : {SA.first.steal(r1, I.steal.for(Id.Rec(w, p, g), seat)) == True{} : Bool} = Id.and.r(SA.slot.is(P.use.first(Id.Uses(w, p, g, seat), item), slot), SA.first.steal(r1, I.steal.for(Id.Rec(w, p, g), seat)), ef)
      front.use(w, p, l, g, seat, seated, slot, item, efirst, r1, efs, eg)

def front.inv(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +seated: Id.Seated(S.world.table(w), seat), +s2: D.Seat, +mv: D.Move, +r1: List<&2, SA.Step>, +n1: Nat, +k: Nat, +es: {s2 == seat : D.Seat}, +res: {D.resolve(G.seat.menu(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Id.Uses(w, p, g, seat))), n1) == D.Chose{D.Choice{seat, k, mv}} : D.Resolved}, eg: {Bool.and(SA.gesture.then(r1, M.stepped.state(M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1))), SA.gesture.go(r1, M.stepped.state(M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1)))) == True{} : Bool}, +ef: {SA.first_slots(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{s2, mv} <> r1) == True{} : Bool}, inv: opt.Inv(S.TakeGun{} <> Id.Uses(w, p, g, seat), mv, k)) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{s2, mv} <> r1) == True{} : Bool}:
  match inv:
    case Tuple{+o, Tuple{+enth, Tuple{+emv, _}}}:
      +answered : {M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1) == S.state.stepped(M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{o})) : D.Stepped<&2, S.State>} = Id.idle.step(w, p, l, g, seat, n1, k, mv, o, res, enth)
      +est : {SA.ChoiceStep{s2, mv} == SA.ChoiceStep{seat, Id.opt.mv(o)} : SA.Step} = Equal.trans(SA.Step, SA.ChoiceStep{s2, mv}, SA.ChoiceStep{seat, mv}, SA.ChoiceStep{seat, Id.opt.mv(o)}, Equal.cong(D.Seat, SA.Step, x => SA.ChoiceStep{x, mv}, s2, seat, es), Equal.cong(D.Move, SA.Step, v => SA.ChoiceStep{seat, v}, mv, Id.opt.mv(o), Equal.sym(D.Move, Id.opt.mv(o), mv, emv)))
      recov.cast(w, p, l, g, seat, SA.ChoiceStep{s2, mv}, SA.ChoiceStep{seat, Id.opt.mv(o)}, r1, Equal.sym(SA.Step, SA.ChoiceStep{s2, mv}, SA.ChoiceStep{seat, Id.opt.mv(o)}, est), front.opt(w, p, l, g, seat, seated, o, r1, eg.cast(r1, M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1), S.state.stepped(M.pickup.selected(S.State{w, p, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Id.Uses(w, p, g, seat)}}, Nil{}, g}, seat, Some{o})), answered, eg), first.cast(w, p, l, g, seat, SA.ChoiceStep{s2, mv}, SA.ChoiceStep{seat, Id.opt.mv(o)}, r1, est, ef)))

def front.c(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +s2: D.Seat, +mv: D.Move, +r1: List<&2, SA.Step>, +n1: Nat, eg: {Bool.and(SA.gesture.then(r1, M.stepped.state(M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1))), SA.gesture.go(r1, M.stepped.state(M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1)))) == True{} : Bool}, +ef: {SA.first_slots(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), SA.ChoiceStep{s2, mv} <> r1) == True{} : Bool}, cs: ChooseStep(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Id.Uses(w, p, g, seat)), s2, mv, n1)) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.ChoiceStep{s2, mv} <> r1) == True{} : Bool}:
  match cs:
    case Tuple{+k, Tuple{+ek, Tuple{+es, Tuple{+seated, +res}}}}:
      front.inv(w, p, l, g, seat, seated, s2, mv, r1, n1, k, es, res, eg, ef, opt.inv(S.TakeGun{} <> Id.Uses(w, p, g, seat), mv, k, ek))

def front.s(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, st1: SA.Step, +r1: List<&2, SA.Step>, +n1: Nat, +el1: {SA.walk.legal(M.request(SA.embed(T.State{w, p, T.Idle{seat}, l, g})), st1) == Some{n1} : Maybe<&2, Nat>}, eg: {Bool.and(SA.gesture.then(r1, M.stepped.state(M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1))), SA.gesture.go(r1, M.stepped.state(M.answer(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), n1)))) == True{} : Bool}, +ef: {SA.first_slots(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), st1 <> r1) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, st1 <> r1) == True{} : Bool}:
  match st1:
    case SA.DrawStep{+a}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, SA.DrawStep{a} <> r1) == True{} : Bool}, draw.notlegal(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Id.Uses(w, p, g, seat)), a, n1, el1))
    case SA.ChoiceStep{+s2, +mv}:
      front.c(w, p, l, g, seat, s2, mv, r1, n1, eg, ef, choose.step(S.world.table(w), seat, G.idle.moves(S.TakeGun{} <> Id.Uses(w, p, g, seat)), s2, mv, n1, el1))

def front.l(+w: S.World, +p: S.Players, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +st1: SA.Step, +r1: List<&2, SA.Step>, l1: Maybe<&2, Nat>, +el1: {SA.walk.legal(M.request(SA.embed(T.State{w, p, T.Idle{seat}, l, g})), st1) == l1 : Maybe<&2, Nat>}, eg: {SA.gesture.answer(l1, SA.embed(T.State{w, p, T.Idle{seat}, l, g}), +next => Bool.and(SA.gesture.then(r1, next), SA.gesture.go(r1, next))) == True{} : Bool}, +ef: {SA.first_slots(SA.embed(T.State{w, p, T.Idle{seat}, l, g}), st1 <> r1) == True{} : Bool}) -> {SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, st1 <> r1) == True{} : Bool}:
  match l1:
    case None{}:
      Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, st1 <> r1) == True{} : Bool}, Wk.bool.clash(eg))
    case Some{+n1}:
      front.s(w, p, l, g, seat, st1, r1, n1, el1, eg, ef)

# simple_complete.
def complete(+s: T.State, steps: List<&2, SA.Step>, eg: {SA.gesture(SA.embed(s), steps) == True{} : Bool}, ef: {SA.first_slots(SA.embed(s), steps) == True{} : Bool}) -> {SA.recovered(s, steps) == True{} : Bool}:
  match s:
    case T.State{+w, +p, +ph, +l, +g}:
      match ph:
        case T.Idle{+seat}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.Idle{seat}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case +st1 <> +r1:
              front.l(w, p, l, g, seat, st1, r1, SA.walk.legal(M.request(SA.embed(T.State{w, p, T.Idle{seat}, l, g})), st1), {==}, eg, ef)
        case T.NeedFirst{}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedFirst{}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedFirst{}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
        case T.NeedHealth{}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedHealth{}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedHealth{}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
        case T.NeedAmount{}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedAmount{}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedAmount{}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
        case T.NeedBatch{}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedBatch{}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedBatch{}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
        case T.NeedSwap{a, b, c}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedSwap{a, b, c}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedSwap{a, b, c}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
        case T.Ended{}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.Ended{}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.Ended{}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
        case T.Blocked{a}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.Blocked{a}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.Blocked{a}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
        case T.Stalled{}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.Stalled{}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.Stalled{}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
        case T.NeedTurnAmount{a, b, c}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedTurnAmount{a, b, c}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedTurnAmount{a, b, c}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
        case T.NeedItem{a, b, c, d}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedItem{a, b, c, d}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedItem{a, b, c, d}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
        case T.NeedPhone{a, b, c}:
          match steps:
            case Nil{}:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedPhone{a, b, c}, l, g}, Nil{}) == True{} : Bool}, Wk.bool.clash(eg))
            case st <> rest:
              Wk.absurd({SA.recovered(T.State{w, p, T.NeedPhone{a, b, c}, l, g}, st <> rest) == True{} : Bool}, Wk.bool.clash(eg))
