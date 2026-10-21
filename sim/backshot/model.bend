import Base
import ./rational.bend as R
import ./state.bend as S

# Shells: 0 unknown, 1 live, 2 blank. Moves 0/1 shoot Dealer/Player.
# Item moves use the same number as their inventory entry.
def dealer() -> Nat: 0n
def player() -> Nat: 1n
def adrenaline() -> Nat: 2n
def beer() -> Nat: 3n
def phone() -> Nat: 4n
def cigarettes() -> Nat: 5n
def medicine() -> Nat: 6n
def handcuffs() -> Nat: 7n
def saw() -> Nat: 8n
def inverter() -> Nat: 9n
def glass() -> Nat: 10n

type Outcome is Data:
  Outcome{probability: R.Q, state: S.State}

def move.name(m: Nat) -> String:
  match m:
    case 0n: "dealer"
    case 1n: "player"
    case 2n: "adrenaline"
    case 3n: "beer"
    case 4n: "phone"
    case 5n: "cigarettes"
    case 6n: "medicine"
    case 7n: "handcuff"
    case 8n: "saw"
    case 9n: "inverter"
    case _: "glass"

def stealable(xs: List<&2, Nat>, +s: S.State) -> Bool:
  match xs:
    case Nil{}: False{}
    case +m <> rest:
      Bool.or(Bool.and(Nat.is_ne(m, adrenaline()), Bool.and(Bool.or(Nat.is_ne(m, saw()), Bool.not(S.sawed(s))), Bool.or(Nat.is_ne(m, handcuffs()), Nat.is_eq(S.cuffs(s), 0n)))), stealable(rest, s))

def allowed(+fixed: Bool, +s: S.State, +m: Nat) -> Bool:
  +item : Bool = S.has(S.inventory(s, S.owner(s)), m)
  +cuffs : Bool = Bool.or(Nat.is_ne(m, handcuffs()), Nat.is_eq(S.cuffs(s), 0n))
  +saw_ok : Bool = Bool.or(Nat.is_ne(m, saw()), Bool.not(S.sawed(s)))
  +adrenaline_ok : Bool = Bool.or(Nat.is_ne(m, adrenaline()), Bool.and(Bool.not(S.pending(s)), stealable(S.inventory(s, Bool.not(S.player(s))), s)))
  Bool.and(item, Bool.and(cuffs, Bool.and(saw_ok, Bool.or(Bool.not(fixed), adrenaline_ok))))

def candidates.items(xs: List<&2, Nat>, +fixed: Bool, +s: S.State) -> List<&2, Nat>:
  match xs:
    case Nil{}: Nil{}
    case +m <> rest:
      +tail : List<&2, Nat> = candidates.items(rest, fixed, s)
      Bool.pick(List<&2, Nat>, allowed(fixed, s, m), m <> tail, tail)

def candidates(+fixed: Bool, +s: S.State) -> List<&2, Nat>:
  items : List<&2, Nat> = candidates.items([adrenaline(), beer(), phone(), cigarettes(), medicine(), handcuffs(), saw(), inverter(), glass()], fixed, s)
  shots : List<&2, Nat> = Bool.pick(List<&2, Nat>, S.player(s), [dealer(), player()], [player(), dealer()])
  List.append(&2, Nat, items, Bool.pick(List<&2, Nat>, S.pending(s), Nil{}, shots))

def live_probability.at(+fixed: Bool, +s: S.State, shell: Nat) -> R.Q:
  match shell:
    case 1n: R.nat(1n)
    case 2n:
      Bool.pick(R.Q, fixed, R.nat(0n), R.ratio(S.live(s), Nat.add(S.live(s), S.blank(s))))
    case _: R.ratio(S.live(s), Nat.add(S.live(s), S.blank(s)))

def live_probability(+fixed: Bool, +s: S.State, +shell: Nat) -> R.Q:
  Bool.pick(R.Q, Nat.is_eq(Nat.add(S.live(s), S.blank(s)), 0n), Bool.pick(R.Q, Bool.and(fixed, Nat.is_eq(shell, 1n)), R.nat(1n), R.nat(0n)), live_probability.at(fixed, s, shell))

def branch(+fixed: Bool, +s: S.State, +shell: Nat, +p: R.Q, +decrement: Bool) -> S.State:
  +drop : Bool = Bool.and(decrement, Bool.or(Bool.not(fixed), Nat.is_eq(S.chamber(s), 0n)))
  +next : S.State = S.set_live(S.set_blank(s, Nat.sub(S.blank(s), Bool.pick(Nat, Bool.and(drop, Nat.is_eq(shell, 2n)), 1n, 0n))), Nat.sub(S.live(s), Bool.pick(Nat, Bool.and(drop, Nat.is_eq(shell, 1n)), 1n, 0n)))
  S.set_weight(next, Bool.pick(R.Q, fixed, R.nat(1n), R.mul(S.weight(s), p)))

def pass.fixed(+s: S.State, +destination: Bool) -> S.State:
  +blocked : Bool = Bool.and(Nat.is_eq(S.cuffs(s), 2n), S.same(destination, S.cuff_owner(s)))
  +lift : Bool = Bool.and(Nat.is_eq(S.cuffs(s), 1n), S.same(destination, S.cuff_owner(s)))
  S.set_player(S.set_cuffs(s, Bool.pick(Nat, blocked, 1n, Bool.pick(Nat, lift, 0n, S.cuffs(s)))), Bool.pick(Bool, blocked, Bool.not(destination), destination))

def shoot(+fixed: Bool, +s: S.State, +target: Bool, +shell: Nat) -> S.State:
  +live : Bool = Nat.is_eq(shell, 1n)
  +damage : Nat = Bool.pick(Nat, live, Bool.pick(Nat, S.sawed(s), 2n, 1n), 0n)
  +next : S.State = S.set_slots(S.set_sawed(S.set_hp(s, target, Nat.sub(S.hp(s, target), damage)), False{}), S.shift(S.slots(s)))
  +destination : Bool = Bool.pick(Bool, live, Bool.not(S.player(s)), target)
  +refturn : Bool = Bool.pick(Bool, live, Bool.pick(Bool, Nat.is_gt(S.cuffs(s), 0n), S.player(s), Bool.not(S.player(s))), target)
  Bool.pick(S.State, fixed, pass.fixed(next, destination), S.set_player(S.set_cuffs(next, Nat.sub(S.cuffs(s), 1n)), refturn))

def reveal(+s: S.State, index: Nat, shell: Nat) -> S.State:
  S.set_slots(s, S.put(S.slots(s), index, shell))

def invert.known(+s: S.State, shell: Nat) -> S.State:
  reveal(s, 0n, Bool.pick(Nat, Nat.is_eq(shell, 1n), 2n, 1n))

def effect(+fixed: Bool, +s: S.State, m: Nat, +shell: Nat) -> S.State:
  match m:
    case 0n: shoot(fixed, s, False{}, shell)
    case 1n: shoot(fixed, s, True{}, shell)
    case 3n: S.consume(S.set_slots(s, S.shift(S.slots(s))), Bool.pick(Nat, fixed, beer(), glass()))
    case 10n: S.consume(reveal(s, 0n, shell), glass())
    case 9n: S.consume(invert.known(s, shell), inverter())
    case _: s

def shell.flip(shell: Nat) -> Nat:
  Bool.pick(Nat, Nat.is_eq(shell, 1n), 2n, 1n)

def chamber_probability(+s: S.State) -> R.Q:
  +p : R.Q = live_probability(True{}, s, S.chamber(s))
  Bool.pick(R.Q, S.inverted(s), R.sub(R.nat(1n), p), p)

def shot_branch(+fixed: Bool, +s: S.State, +shell: Nat, p: R.Q, decrement: Bool) -> S.State:
  +underlying : Nat = Bool.pick(Nat, Bool.and(fixed, S.inverted(s)), shell.flip(shell), shell)
  +next : S.State = branch(fixed, s, underlying, p, decrement)
  Bool.pick(S.State, fixed, S.set_inverted(next, False{}), next)

def two(+fixed: Bool, +s: S.State, +m: Nat) -> List<&2, Outcome>:
  +p : R.Q = Bool.pick(R.Q, fixed, chamber_probability(s), live_probability(False{}, s, S.chamber(s)))
  +b : R.Q = R.sub(R.nat(1n), p)
  +dec : Bool = Bool.or(Bool.not(fixed), Nat.is_eq(m, 0n))
  +dec : Bool = Bool.or(dec, Bool.or(Nat.is_eq(m, 1n), Nat.is_eq(m, beer())))
  [Outcome{p, effect(fixed, shot_branch(fixed, s, 1n, p, dec), m, 1n)}, Outcome{b, effect(fixed, shot_branch(fixed, s, 2n, b, dec), m, 2n)}]

def heal(+fixed: Bool, +s: S.State, +amount: Nat) -> S.State:
  +hp : Nat = Nat.add(S.hp(s, S.player(s)), amount)
  S.set_hp(s, S.player(s), Bool.pick(Nat, fixed, Bool.pick(Nat, Nat.is_lt(S.hp(s, S.player(s)), S.maximum(s)), Nat.min(S.maximum(s), hp), S.hp(s, S.player(s))), Nat.max(S.maximum(s), hp)))

def medicine.outcomes(+fixed: Bool, +s: S.State) -> List<&2, Outcome>:
  +p : R.Q = Bool.pick(R.Q, fixed, R.ratio(1n, 2n), R.ratio(2n, 5n))
  +q : R.Q = R.sub(R.nat(1n), p)
  +good : S.State = heal(fixed, s, 2n)
  +good : S.State = Bool.pick(S.State, fixed, good, S.set_hp(S.set_live(good, Nat.sub(S.live(s), 1n)), S.player(s), Nat.sub(S.hp(good, S.player(s)), 1n)))
  +bad : S.State = S.set_hp(s, S.player(s), Bool.pick(Nat, fixed, Nat.sub(S.hp(s, S.player(s)), 1n), 0n))
  +bad : S.State = Bool.pick(S.State, fixed, bad, S.set_blank(bad, Nat.sub(S.blank(s), 1n)))
  [Outcome{p, S.consume(S.set_weight(good, Bool.pick(R.Q, fixed, R.nat(1n), R.mul(S.weight(s), p))), medicine())}, Outcome{q, S.consume(S.set_weight(bad, Bool.pick(R.Q, fixed, R.nat(1n), R.mul(S.weight(s), q))), medicine())}]

def phone.outcome(+fixed: Bool, +s: S.State, +i: Nat, +shell: Nat, +count: Nat) -> Outcome:
  +p : R.Q = Bool.pick(R.Q, fixed, R.mul(R.ratio(1n, count), live_probability(fixed, s, S.nth(S.slots(s), i))), R.ratio(1n, count))
  +p : R.Q = Bool.pick(R.Q, Bool.and(fixed, Nat.is_eq(shell, 2n)), R.mul(R.ratio(1n, count), R.sub(R.nat(1n), live_probability(fixed, s, S.nth(S.slots(s), i)))), p)
  +next : S.State = reveal(s, i, shell)
  +unknown : Bool = Bool.and(fixed, Nat.is_eq(S.nth(S.slots(s), i), 0n))
  +next : S.State = S.set_live(S.set_blank(next, Nat.sub(S.blank(s), Bool.pick(Nat, Bool.and(unknown, Nat.is_eq(shell, 2n)), 1n, 0n))), Nat.sub(S.live(s), Bool.pick(Nat, Bool.and(unknown, Nat.is_eq(shell, 1n)), 1n, 0n)))
  Outcome{p, S.consume(S.set_weight(next, Bool.pick(R.Q, fixed, R.nat(1n), R.mul(S.weight(s), p))), phone())}

def phone.loop(left: Nat, +fixed: Bool, +s: S.State, +i: Nat, +count: Nat) -> List<&2, Outcome>:
  match left:
    case 0n: Nil{}
    case 1n+k:
      phone.outcome(fixed, s, i, 1n, count) <> phone.outcome(fixed, s, i, 2n, count) <> phone.loop(k, fixed, s, 1n+i, count)

def phone.player(+s: S.State, total: Nat) -> List<&2, Outcome>:
  match total:
    case 0n: [Outcome{R.nat(1n), S.consume(s, phone())}]
    case 1n: [Outcome{R.nat(1n), S.consume(s, phone())}]
    case 2n+ +extra: phone.loop(1n+extra, True{}, s, 1n, 1n+extra)

def phone.fixed(+s: S.State, +total: Nat) -> List<&2, Outcome>:
  +dealer_no_clue : Bool = Bool.and(Bool.not(S.player(s)), Nat.is_le(total, 2n))
  Bool.pick(List<&2, Outcome>, dealer_no_clue, [Outcome{R.nat(1n), S.consume(s, phone())}], phone.player(s, total))

def single(+fixed: Bool, +s: S.State, m: Nat) -> List<&2, Outcome>:
  match m:
    case 2n:
      Bool.pick(List<&2, Outcome>, S.pending(s), Nil{}, [Outcome{R.nat(1n), S.set_pending(S.set_inventory(s, S.player(s), S.remove(S.inventory(s, S.player(s)), adrenaline(), False{})), True{})}])
    case 5n: [Outcome{R.nat(1n), S.consume(heal(fixed, s, 1n), cigarettes())}]
    case 6n: medicine.outcomes(fixed, s)
    case 7n: [Outcome{R.nat(1n), S.consume(S.set_cuff_owner(S.set_cuffs(s, 2n), Bool.not(S.player(s))), handcuffs())}]
    case 8n: [Outcome{R.nat(1n), S.consume(S.set_sawed(s, True{}), saw())}]
    case 9n:
      Bool.pick(List<&2, Outcome>, S.inverted(s), Nil{}, [Outcome{R.nat(1n), S.consume(S.set_inverted(s, True{}), inverter())}])
    case 4n:
      Bool.pick(List<&2, Outcome>, fixed, phone.fixed(s, S.total(s)), phone.loop(Nat.add(S.live(s), S.blank(s)), False{}, s, 0n, Nat.add(S.live(s), S.blank(s))))
    case _: two(fixed, s, m)

def outcome.positive(outcome: Outcome) -> Bool:
  match outcome:
    case Outcome{p, _}: R.lt(R.nat(0n), p)

def positive(xs: List<&2, Outcome>) -> List<&2, Outcome>:
  match xs:
    case Nil{}: Nil{}
    case +x <> rest:
      +tail : List<&2, Outcome> = positive(rest)
      Bool.pick(List<&2, Outcome>, outcome.positive(x), x <> tail, tail)

def glass.fixed(+s: S.State, +shell: Nat, +p: R.Q) -> Outcome:
  +drop : Bool = Nat.is_eq(S.chamber(s), 0n)
  +underlying : Nat = Bool.pick(Nat, S.inverted(s), shell.flip(shell), shell)
  +next : S.State = S.set_live(S.set_blank(s, Nat.sub(S.blank(s), Bool.pick(Nat, Bool.and(drop, Nat.is_eq(underlying, 2n)), 1n, 0n))), Nat.sub(S.live(s), Bool.pick(Nat, Bool.and(drop, Nat.is_eq(underlying, 1n)), 1n, 0n)))
  Outcome{p, S.consume(S.set_inverted(reveal(next, 0n, shell), False{}), glass())}

def outcomes.fixed(+s: S.State, +m: Nat) -> List<&2, Outcome>:
  match m:
    case 9n:
      # Unknown inversion changes no information; a latent flag flips its next draw.
      +known : Bool = Nat.is_ne(S.chamber(s), 0n)
      +next : S.State = Bool.pick(S.State, known, invert.known(s, S.chamber(s)), S.set_inverted(s, Bool.not(S.inverted(s))))
      [Outcome{R.nat(1n), S.consume(next, inverter())}]
    case 10n:
      +p : R.Q = chamber_probability(s)
      [glass.fixed(s, 1n, p), glass.fixed(s, 2n, R.sub(R.nat(1n), p))]
    case _: single(True{}, s, m)

def outcomes(+fixed: Bool, +s: S.State, +m: Nat) -> Result<&2, &2, String, List<&2, Outcome>>:
  +beer_error : Bool = Bool.and(Bool.not(fixed), Bool.and(Nat.is_eq(m, beer()), Bool.not(S.has(S.inventory(s, S.owner(s)), glass()))))
  +phone_error : Bool = Bool.and(Bool.not(fixed), Bool.and(Nat.is_eq(m, phone()), Nat.is_gt(Nat.add(S.live(s), S.blank(s)), 8n)))
  +xs : List<&2, Outcome> = Bool.pick(List<&2, Outcome>, fixed, positive(outcomes.fixed(s, m)), single(False{}, s, m))
  Bool.pick(Result<&2, &2, String, List<&2, Outcome>>, beer_error, Fail{"item not found"}, Bool.pick(Result<&2, &2, String, List<&2, Outcome>>, phone_error, Fail{"phone index out of range"}, Done{xs}))
