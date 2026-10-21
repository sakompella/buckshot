import Base
import ./rational.bend as R
import ./state.bend as S
import ./model.bend as M

def held(+s: S.State, item: Nat) -> Bool:
  S.has(S.inventory(s, S.player(s)), item)

def obvious.last(+s: S.State, +self: Nat) -> Maybe<&2, Nat>:
  Bool.pick(Maybe<&2, Nat>, Bool.and(held(s, M.handcuffs()), Nat.is_le(S.blank(s), 1n)), Some{M.handcuffs()}, None{})

def obvious.heal(+s: S.State, +self: Nat) -> Maybe<&2, Nat>:
  Bool.pick(Maybe<&2, Nat>, Bool.and(held(s, M.cigarettes()), Nat.is_ne(S.hp(s, S.player(s)), S.maximum(s))), Some{M.cigarettes()}, obvious.last(s, self))

def obvious.glass(+s: S.State, +self: Nat) -> Maybe<&2, Nat>:
  Bool.pick(Maybe<&2, Nat>, Bool.and(held(s, M.glass()), Bool.and(Nat.is_eq(S.chamber(s), 0n), Bool.and(Nat.is_gt(S.live(s), 0n), Nat.is_gt(S.blank(s), 0n)))), Some{M.glass()}, obvious.heal(s, self))

def obvious.blank(+s: S.State, +self: Nat) -> Maybe<&2, Nat>:
  Bool.pick(Maybe<&2, Nat>, Bool.or(Nat.is_eq(S.chamber(s), 2n), Nat.is_eq(S.live(s), 0n)), Some{self}, obvious.glass(s, self))

def obvious(+fixed: Bool, +s: S.State) -> Maybe<&2, Nat>:
  +self : Nat = Bool.pick(Nat, S.player(s), M.player(), M.dealer())
  +other : Nat = Bool.pick(Nat, S.player(s), M.dealer(), M.player())
  +hp : Nat = Bool.pick(Nat, fixed, S.hp(s, Bool.not(S.player(s))), S.dealer_hp(s))
  +saw : Bool = Bool.and(Nat.is_ge(hp, 2n), Bool.and(held(s, M.saw()), Bool.not(S.sawed(s))))
  Bool.pick(Maybe<&2, Nat>, Bool.or(Nat.is_eq(S.chamber(s), 1n), Nat.is_eq(S.blank(s), 0n)), Some{Bool.pick(Nat, saw, M.saw(), other)}, obvious.blank(s, self))

def redundant(+s: S.State, m: Nat) -> Bool:
  match m:
    case 0n:
      Bool.or(Bool.and(Bool.not(S.player(s)), S.sawed(s)), Bool.or(Bool.and(S.player(s), Nat.is_eq(S.chamber(s), 2n)), Bool.and(Bool.not(S.player(s)), Nat.is_eq(S.chamber(s), 1n))))
    case 1n: True{}
    case 2n: Nat.is_eq(List.length(&2, Nat, S.inventory(s, Bool.not(S.player(s)))), 0n)
    case 5n: Nat.is_eq(S.hp(s, Bool.not(S.player(s))), S.maximum(s))
    case 6n:
      Bool.or(Nat.is_eq(S.hp(s, S.player(s)), S.maximum(s)), Bool.and(held(s, M.cigarettes()), Nat.is_eq(S.hp(s, S.player(s)), Nat.sub(S.maximum(s), 1n))))
    case 7n: Nat.is_gt(S.cuffs(s), 0n)
    case 8n: Bool.or(Nat.is_eq(S.live(s), 0n), Nat.is_eq(S.hp(s, Bool.not(S.player(s))), 1n))
    case 9n: Nat.is_eq(S.chamber(s), 1n)
    case _: Bool.or(Nat.is_ne(S.chamber(s), 0n), Bool.or(Nat.is_eq(S.live(s), 0n), Nat.is_eq(S.blank(s), 0n)))

def sf.sum(+n: Nat, +l: Nat, +total: Nat) -> R.Q:
  match n:
    case 0n: R.nat(0n)
    case 1n+k:
      R.add(R.mul(R.sub(R.nat(l), R.nat(1n)), R.ratio(1n, Nat.sub(total, n))), sf.sum(k, l, total))

def kill.player(+s: S.State, +l: Nat, +b: Nat, +total: Nat) -> R.Q:
  +a : R.Q = Bool.pick(R.Q, Nat.is_gt(total, 1n), R.mul(R.sub(R.nat(Nat.mul(2n, l)), R.nat(1n)), R.ratio(1n, Nat.mul(2n, Nat.sub(total, 1n)))), R.nat(1n))
  +sf : R.Q = Bool.pick(R.Q, Nat.is_gt(b, 0n), R.mul(R.ratio(1n, b), R.add(R.nat(1n), sf.sum(Nat.sub(b, 1n), l, total))), R.nat(1n))
  +beer : Bool = S.has(M.candidates(False{}, s), M.beer())
  +c : R.Q = Bool.pick(R.Q, beer, Bool.pick(R.Q, Nat.is_gt(total, 2n), R.mul(R.sub(R.nat(Nat.mul(4n, l)), R.nat(3n)), R.ratio(1n, Nat.mul(4n, Nat.sub(total, 2n)))), R.nat(1n)), Bool.pick(R.Q, Nat.is_gt(b, 0n), R.ratio(l, total), R.nat(1n)))
  R.min(a, R.min(sf, c))

def kill(+s: S.State) -> R.Q:
  +l : Nat = S.live(s)
  +b : Nat = S.blank(s)
  +total : Nat = Nat.add(l, b)
  Bool.pick(R.Q, S.player(s), kill.player(s, l, b, total), Bool.pick(R.Q, Nat.is_gt(b, 0n), R.ratio(l, total), R.nat(1n)))

def terminal(+fixed: Bool, +s: S.State) -> Result<&2, &2, String, R.Q>:
  +hp : Nat = Nat.add(S.player_hp(s), S.dealer_hp(s))
  +ratio : R.Q = R.ratio(S.player_hp(s), hp)
  +reference : R.Q = R.mul(R.mul(R.sub(R.nat(1n), kill(s)), ratio), S.weight(s))
  +fixed_value : R.Q = Bool.pick(R.Q, Nat.is_eq(S.dealer_hp(s), 0n), R.nat(1n), Bool.pick(R.Q, Nat.is_eq(S.player_hp(s), 0n), R.nat(0n), ratio))
  Bool.pick(Result<&2, &2, String, R.Q>, Bool.and(Nat.is_eq(hp, 0n), Bool.not(fixed)), Fail{"divide by zero"}, Done{Bool.pick(R.Q, fixed, Bool.pick(R.Q, Nat.is_eq(hp, 0n), R.ratio(1n, 2n), fixed_value), reference)})

def attacks(+s: S.State, +m: Nat) -> Bool:
  Bool.or(Bool.and(S.player(s), Nat.is_eq(m, M.dealer())), Bool.and(Bool.not(S.player(s)), Nat.is_eq(m, M.player())))

def signed(+s: S.State, +n: Nat) -> R.Q:
  Bool.pick(R.Q, S.player(s), R.nat(n), R.neg(R.nat(n)))

def known(+s: S.State, +m: Nat, shell: Nat) -> R.Q:
  match shell:
    case 1n:
      Bool.pick(R.Q, attacks(s, m), signed(s, 200n), Bool.pick(R.Q, S.player(s), R.neg(R.nat(1000000n)), R.nat(1000000n)))
    case 2n:
      Bool.pick(R.Q, Bool.or(Bool.and(S.player(s), Nat.is_eq(m, M.player())), Bool.and(Bool.not(S.player(s)), Nat.is_eq(m, M.dealer()))), signed(s, 100n), Bool.pick(R.Q, S.player(s), R.neg(R.nat(1000000n)), R.nat(1000000n)))
    case _:
      R.mul(R.ratio(S.live(s), Nat.add(S.live(s), S.blank(s))), R.nat(Bool.pick(Nat, attacks(s, m), 100n, 1n)))

def usage(+s: S.State, m: Nat) -> R.Q:
  match m:
    case 3n: R.nat(Bool.pick(Nat, Bool.and(Nat.is_eq(S.chamber(s), 0n), Nat.is_lt(S.live(s), S.blank(s))), 250n, 0n))
    case 5n: R.mul(R.nat(150n), R.sub(R.nat(S.maximum(s)), R.nat(S.hp(s, S.player(s)))))
    case 7n: R.nat(Bool.pick(Nat, Nat.is_eq(Nat.add(S.live(s), S.blank(s)), 2n), 250n, 100n))
    case 8n: R.nat(Bool.pick(Nat, Nat.is_eq(S.chamber(s), 1n), 250n, Bool.pick(Nat, Nat.is_ge(S.live(s), S.blank(s)), 100n, 0n)))
    case 10n: R.nat(2500n)
    case _: R.nat(0n)

def score(+s: S.State, +m: Nat) -> R.Q:
  +base : R.Q = Bool.pick(R.Q, Nat.is_eq(S.player_hp(s), 0n), R.neg(R.nat(1000000n)), Bool.pick(R.Q, Nat.is_eq(S.dealer_hp(s), 0n), R.nat(1000000n), R.nat(0n)))
  +active : Bool = Nat.is_ne(Nat.add(S.live(s), S.blank(s)), 0n)
  +other : R.Q = Bool.pick(R.Q, Bool.and(Nat.is_eq(S.chamber(s), 0n), Bool.and(Nat.is_ge(S.live(s), S.blank(s)), attacks(s, m))), R.mul(R.nat(100n), R.sub(R.nat(S.live(s)), R.nat(S.blank(s)))), R.nat(0n))
  +penalty : Nat = Bool.pick(Nat, Bool.and(S.has(S.inventory(s, Bool.not(S.player(s))), M.saw()), Nat.is_le(S.hp(s, S.player(s)), 2n)), 150n, 0n)
  +low : Nat = Bool.pick(Nat, Nat.is_eq(S.hp(s, S.player(s)), 1n), 100n, 0n)
  R.add(R.sub(R.add(R.add(base, Bool.pick(R.Q, active, R.add(known(s, m, S.chamber(s)), other), R.nat(0n))), usage(s, m)), R.nat(Nat.add(penalty, low))), R.mul(R.nat(100n), R.ratio(S.player_hp(s), Nat.add(S.player_hp(s), S.dealer_hp(s)))))

type Ranked is Data:
  Ranked{move: Nat, key: R.Q}

def key(xs: List<&2, M.Outcome>, +p: Bool, +m: Nat, +best: R.Q) -> R.Q:
  match xs:
    case Nil{}: best
    case M.Outcome{_, s} <> rest:
      +v : R.Q = score(s, m)
      key(rest, p, m, Bool.pick(R.Q, p, R.max(best, v), R.min(best, v)))

def rank.result(xs: Result<&2, &2, String, List<&2, M.Outcome>>, +s: S.State, +m: Nat) -> Result<&2, &2, String, Ranked>:
  match xs:
    case Fail{e}: Fail{e}
    case Done{outcomes}:
      Done{Ranked{m, key(outcomes, S.player(s), m, Bool.pick(R.Q, S.player(s), R.neg(R.nat(1000000n)), R.nat(1000000n)))}}

def rank(+s: S.State, +m: Nat) -> Result<&2, &2, String, Ranked>:
  rank.result(M.outcomes(False{}, s, m), s, m)

def insert(xs: List<&2, Ranked>, +m: Nat, +v: R.Q) -> List<&2, Ranked>:
  match xs:
    case Nil{}: [Ranked{m, v}]
    case Ranked{+n, +w} <> +rest:
      Bool.pick(List<&2, Ranked>, R.lt(w, v), Ranked{n, w} <> insert(rest, m, v), Ranked{m, v} <> Ranked{n, w} <> rest)

def ranked.insert(result: Result<&2, &2, String, Ranked>, rest: Result<&2, &2, String, List<&2, Ranked>>) -> Result<&2, &2, String, List<&2, Ranked>>:
  match result rest:
    case Fail{e} _: Fail{e}
    case _ Fail{e}: Fail{e}
    case Done{Ranked{m, v}} Done{xs}: Done{insert(xs, m, v)}

def ordered(xs: List<&2, Nat>, +s: S.State) -> Result<&2, &2, String, List<&2, Ranked>>:
  match xs:
    case Nil{}: Done{Nil{}}
    case +m <> rest: ranked.insert(rank(s, m), ordered(rest, s))

def unrank(xs: List<&2, Ranked>, +s: S.State) -> List<&2, Nat>:
  match xs:
    case Nil{}: Nil{}
    case Ranked{+m, _} <> rest:
      +tail : List<&2, Nat> = unrank(rest, s)
      Bool.pick(List<&2, Nat>, redundant(s, m), tail, m <> tail)

def ordered.result(result: Result<&2, &2, String, List<&2, Ranked>>, s: S.State) -> Result<&2, &2, String, List<&2, Nat>>:
  match result:
    case Fail{e}: Fail{e}
    case Done{xs}: Done{unrank(xs, s)}

def moves.obvious(found: Maybe<&2, Nat>, +s: S.State) -> Result<&2, &2, String, List<&2, Nat>>:
  match found:
    case Some{m}: Done{[m]}
    case None{}: ordered.result(ordered(M.candidates(False{}, s), s), s)

def moves(+fixed: Bool, +s: S.State) -> Result<&2, &2, String, List<&2, Nat>>:
  Bool.pick(Result<&2, &2, String, List<&2, Nat>>, fixed, Done{M.candidates(True{}, s)}, moves.obvious(obvious(False{}, s), s))
