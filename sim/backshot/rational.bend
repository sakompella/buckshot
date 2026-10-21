import Base

# Reduced signed rationals. Denominators are positive at every public boundary.
type Q is Data:
  Q{negative: Bool, numerator: Nat, denominator: Nat}

def gcd(fuel: Nat, +a: Nat, +b: Nat) -> Nat:
  match fuel b:
    case _ 0n:
      a
    case 0n _:
      1n
    case 1n+k _:
      gcd(k, b, Nat.mod(a, b))

def reduce.zero(negative: Bool, numerator: Nat, denominator: Nat, +g: Nat) -> Q:
  match numerator:
    case 0n:
      Q{False{}, 0n, 1n}
    case n:
      Q{negative, Nat.div(n, g), Nat.div(denominator, g)}

def make(negative: Bool, +numerator: Nat, +denominator: Nat) -> Q:
  reduce.zero(negative, numerator, denominator, gcd(Nat.add(numerator, denominator), numerator, denominator))

def nat(n: Nat) -> Q:
  Q{False{}, n, 1n}

def neg(q: Q) -> Q:
  match q:
    case Q{sign, n, d}:
      make(Bool.not(sign), n, d)

def add.parts(+sa: Bool, +a: Nat, +sb: Bool, +b: Nat, d: Nat) -> Q:
  match sa sb:
    case False{} False{}:
      make(False{}, Nat.add(a, b), d)
    case True{} True{}:
      make(True{}, Nat.add(a, b), d)
    case False{} True{}:
      make(Nat.is_lt(a, b), Nat.add(Nat.sub(a, b), Nat.sub(b, a)), d)
    case True{} False{}:
      make(Nat.is_gt(a, b), Nat.add(Nat.sub(a, b), Nat.sub(b, a)), d)

def add(a: Q, b: Q) -> Q:
  match a b:
    case Q{sa, na, +da} Q{sb, nb, +db}:
      add.parts(sa, Nat.mul(na, db), sb, Nat.mul(nb, da), Nat.mul(da, db))

def sub(a: Q, b: Q) -> Q:
  add(a, neg(b))

def mul(a: Q, b: Q) -> Q:
  match a b:
    case Q{+sa, na, da} Q{+sb, nb, db}:
      make(Bool.not(Bool.or(Bool.and(sa, sb), Bool.and(Bool.not(sa), Bool.not(sb)))), Nat.mul(na, nb), Nat.mul(da, db))

def ratio(n: Nat, d: Nat) -> Q:
  match d:
    case 0n: nat(0n)
    case 1n+k: make(False{}, n, 1n+k)

def lt.parts(sa: Bool, a: Nat, sb: Bool, b: Nat) -> Bool:
  match sa sb:
    case True{} False{}:
      True{}
    case False{} True{}:
      False{}
    case True{} True{}:
      Nat.is_gt(a, b)
    case False{} False{}:
      Nat.is_lt(a, b)

def lt(a: Q, b: Q) -> Bool:
  match a b:
    case Q{sa, na, +da} Q{sb, nb, +db}:
      lt.parts(sa, Nat.mul(na, db), sb, Nat.mul(nb, da))

def min(+a: Q, +b: Q) -> Q:
  Bool.pick(Q, lt(a, b), a, b)

def max(+a: Q, +b: Q) -> Q:
  Bool.pick(Q, lt(a, b), b, a)

def show(q: Q) -> String:
  match q:
    case Q{negative, n, d}:
      Bool.pick(String, negative, "-", "") ++ Nat.show(n) ++ "/" ++ Nat.show(d)
