import Base
import ./rational.bend as R

type State is Data:
  State{player: Bool, maximum: Nat, dealer_hp: Nat, player_hp: Nat, live: Nat, blank: Nat, slots: List<&2, Nat>, cuffs: Nat, cuff_owner: Bool, sawed: Bool, pending: Bool, inverted: Bool, weight: R.Q, dealer_items: List<&2, Nat>, player_items: List<&2, Nat>}

def player(s: State) -> Bool:
  match s:
    case State{player, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      player

def set_player(s: State, value: Bool) -> State:
  match s:
    case State{_, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}:
      State{value, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}

def maximum(s: State) -> Nat:
  match s:
    case State{_, maximum, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      maximum

def set_maximum(s: State, value: Nat) -> State:
  match s:
    case State{player, _, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}:
      State{player, value, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}

def dealer_hp(s: State) -> Nat:
  match s:
    case State{_, _, dealer_hp, _, _, _, _, _, _, _, _, _, _, _, _}:
      dealer_hp

def set_dealer_hp(s: State, value: Nat) -> State:
  match s:
    case State{player, maximum, _, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}:
      State{player, maximum, value, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}

def player_hp(s: State) -> Nat:
  match s:
    case State{_, _, _, player_hp, _, _, _, _, _, _, _, _, _, _, _}:
      player_hp

def set_player_hp(s: State, value: Nat) -> State:
  match s:
    case State{player, maximum, dealer_hp, _, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}:
      State{player, maximum, dealer_hp, value, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}

def live(s: State) -> Nat:
  match s:
    case State{_, _, _, _, live, _, _, _, _, _, _, _, _, _, _}:
      live

def set_live(s: State, value: Nat) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, _, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}:
      State{player, maximum, dealer_hp, player_hp, value, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}

def blank(s: State) -> Nat:
  match s:
    case State{_, _, _, _, _, blank, _, _, _, _, _, _, _, _, _}:
      blank

def set_blank(s: State, value: Nat) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, live, _, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}:
      State{player, maximum, dealer_hp, player_hp, live, value, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}

def slots(s: State) -> List<&2, Nat>:
  match s:
    case State{_, _, _, _, _, _, slots, _, _, _, _, _, _, _, _}:
      slots

def set_slots(s: State, value: List<&2, Nat>) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, live, blank, _, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}:
      State{player, maximum, dealer_hp, player_hp, live, blank, value, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}

def cuffs(s: State) -> Nat:
  match s:
    case State{_, _, _, _, _, _, _, cuffs, _, _, _, _, _, _, _}:
      cuffs

def set_cuffs(s: State, value: Nat) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, live, blank, slots, _, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}:
      State{player, maximum, dealer_hp, player_hp, live, blank, slots, value, cuff_owner, sawed, pending, inverted, weight, dealer_items, player_items}

def cuff_owner(s: State) -> Bool:
  match s:
    case State{_, _, _, _, _, _, _, _, cuff_owner, _, _, _, _, _, _}:
      cuff_owner

def set_cuff_owner(s: State, value: Bool) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, _, sawed, pending, inverted, weight, dealer_items, player_items}:
      State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, value, sawed, pending, inverted, weight, dealer_items, player_items}

def sawed(s: State) -> Bool:
  match s:
    case State{_, _, _, _, _, _, _, _, _, sawed, _, _, _, _, _}:
      sawed

def set_sawed(s: State, value: Bool) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, _, pending, inverted, weight, dealer_items, player_items}:
      State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, value, pending, inverted, weight, dealer_items, player_items}

def pending(s: State) -> Bool:
  match s:
    case State{_, _, _, _, _, _, _, _, _, _, pending, _, _, _, _}:
      pending

def set_pending(s: State, value: Bool) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, _, inverted, weight, dealer_items, player_items}:
      State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, value, inverted, weight, dealer_items, player_items}

def inverted(s: State) -> Bool:
  match s:
    case State{_, _, _, _, _, _, _, _, _, _, _, inverted, _, _, _}:
      inverted

def set_inverted(s: State, value: Bool) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, _, weight, dealer_items, player_items}:
      State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, value, weight, dealer_items, player_items}

def weight(s: State) -> R.Q:
  match s:
    case State{_, _, _, _, _, _, _, _, _, _, _, _, weight, _, _}:
      weight

def set_weight(s: State, value: R.Q) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, _, dealer_items, player_items}:
      State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, value, dealer_items, player_items}

def dealer_items(s: State) -> List<&2, Nat>:
  match s:
    case State{_, _, _, _, _, _, _, _, _, _, _, _, _, dealer_items, _}:
      dealer_items

def set_dealer_items(s: State, value: List<&2, Nat>) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, _, player_items}:
      State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, value, player_items}

def player_items(s: State) -> List<&2, Nat>:
  match s:
    case State{_, _, _, _, _, _, _, _, _, _, _, _, _, _, player_items}:
      player_items

def set_player_items(s: State, value: List<&2, Nat>) -> State:
  match s:
    case State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, _}:
      State{player, maximum, dealer_hp, player_hp, live, blank, slots, cuffs, cuff_owner, sawed, pending, inverted, weight, dealer_items, value}

def same(+a: Bool, +b: Bool) -> Bool:
  Bool.or(Bool.and(a, b), Bool.and(Bool.not(a), Bool.not(b)))

def hp(+s: State, side: Bool) -> Nat:
  Bool.pick(Nat, side, player_hp(s), dealer_hp(s))

def set_hp(+s: State, side: Bool, +n: Nat) -> State:
  Bool.pick(State, side, set_player_hp(s, n), set_dealer_hp(s, n))

def inventory(+s: State, side: Bool) -> List<&2, Nat>:
  Bool.pick(List<&2, Nat>, side, player_items(s), dealer_items(s))

def set_inventory(+s: State, side: Bool, +xs: List<&2, Nat>) -> State:
  Bool.pick(State, side, set_player_items(s, xs), set_dealer_items(s, xs))

def owner(+s: State) -> Bool:
  Bool.not(same(player(s), pending(s)))

def has(xs: List<&2, Nat>, +n: Nat) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case x <> rest:
      Bool.or(Nat.is_eq(x, n), has(rest, n))

def remove(xs: List<&2, Nat>, +n: Nat, +done: Bool) -> List<&2, Nat>:
  match xs:
    case Nil{}:
      Nil{}
    case +x <> rest:
      +drop : Bool = Bool.and(Bool.not(done), Nat.is_eq(x, n))
      +tail : List<&2, Nat> = remove(rest, n, Bool.or(done, drop))
      Bool.pick(List<&2, Nat>, drop, tail, x <> tail)

def nth(xs: List<&2, Nat>, n: Nat) -> Nat:
  match xs n:
    case Nil{} _:
      0n
    case x <> rest 0n:
      x
    case x <> rest 1n+k:
      nth(rest, k)

def put(xs: List<&2, Nat>, n: Nat, value: Nat) -> List<&2, Nat>:
  match xs n:
    case Nil{} _:
      Nil{}
    case x <> rest 0n:
      value <> rest
    case x <> rest 1n+k:
      x <> put(rest, k, value)

def known(xs: List<&2, Nat>, +shell: Nat) -> Nat:
  match xs:
    case Nil{}:
      0n
    case x <> rest:
      Nat.add(Bool.pick(Nat, Nat.is_eq(x, shell), 1n, 0n), known(rest, shell))

def shift(xs: List<&2, Nat>) -> List<&2, Nat>:
  match xs:
    case Nil{}:
      Nil{}
    case x <> rest:
      List.append(&2, Nat, rest, [0n])

def chamber(+s: State) -> Nat:
  nth(slots(s), 0n)

def total(+s: State) -> Nat:
  Nat.add(Nat.add(live(s), blank(s)), Nat.add(known(slots(s), 1n), known(slots(s), 2n)))

def consume(+s: State, item: Nat) -> State:
  set_pending(set_inventory(s, owner(s), remove(inventory(s, owner(s)), item, False{})), False{})

def initial(+fixed: Bool, +p: Bool, maximum: Nat, dh: Nat, ph: Nat, +l: Nat, +b: Nat, +shell: Nat, c: Nat, saw: Bool, di: List<&2, Nat>, pi: List<&2, Nat>) -> State:
  State{p, maximum, dh, ph, Nat.sub(l, Bool.pick(Nat, Bool.and(fixed, Nat.is_eq(shell, 1n)), 1n, 0n)), Nat.sub(b, Bool.pick(Nat, Bool.and(fixed, Nat.is_eq(shell, 2n)), 1n, 0n)), [shell, 0n, 0n, 0n, 0n, 0n, 0n, 0n], c, Bool.not(p), saw, False{}, False{}, R.nat(1n), di, pi}
