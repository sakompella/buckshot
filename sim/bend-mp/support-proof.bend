import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/rules.bend as Q

def false_true(+value: Bool, proof: {False{} == True{} : Bool}) -> {value == True{} : Bool}:
  match value:
    case False{}:
      proof
    case True{}:
      {==}

def and_left(+a: Bool, +b: Bool, proof: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a b:
    case False{} False{}:
      proof
    case False{} True{}:
      proof
    case True{} _:
      {==}

def and_right(+a: Bool, +b: Bool, proof: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a b:
    case False{} False{}:
      proof
    case False{} True{}:
      {==}
    case True{} _:
      proof

def lt_zero(+n: Nat) -> {Nat.is_lt(n, 0n) == False{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+rest:
      {==}

def bounded_zero(+n: Nat, bounded: {Nat.is_lt(n, 0n) == True{} : Bool}) -> {False{} == True{} : Bool}:
  Equal.trans(Bool, False{}, Nat.is_lt(n, 0n), True{}, Equal.sym(Bool, Nat.is_lt(n, 0n), False{}, lt_zero(n)), bounded)

def selected_members(+plan: D.Plan, +index: Nat, +supported: {Q.plan.no_items(plan) == True{} : Bool}, bounded: {Nat.is_lt(index, D.plan.length(plan)) == True{} : Bool}) -> {Q.round.no_items(A.support.round(plan, index)) == True{} : Bool}:
  match plan index:
    case D.OneRound{a} 0n:
      supported
    case D.OneRound{a} 1n+rest:
      false_true(Q.round.no_items(A.support.round(plan, index)), bounded_zero(rest, bounded))
    case D.TwoRounds{+a, +b} 0n:
      and_left(Q.round.no_items(a), Q.round.no_items(b), supported)
    case D.TwoRounds{+a, +b} 1n:
      and_right(Q.round.no_items(a), Q.round.no_items(b), supported)
    case D.TwoRounds{a, b} 2n+rest:
      false_true(Q.round.no_items(A.support.round(plan, index)), bounded_zero(rest, bounded))
    case D.ThreeRounds{+a, +b, +c} 0n:
      and_left(Q.round.no_items(a), Bool.and(Q.round.no_items(b), Q.round.no_items(c)), supported)
    case D.ThreeRounds{+a, +b, +c} 1n:
      and_left(Q.round.no_items(b), Q.round.no_items(c), and_right(Q.round.no_items(a), Bool.and(Q.round.no_items(b), Q.round.no_items(c)), supported))
    case D.ThreeRounds{+a, +b, +c} 2n:
      and_right(Q.round.no_items(b), Q.round.no_items(c), and_right(Q.round.no_items(a), Bool.and(Q.round.no_items(b), Q.round.no_items(c)), supported))
    case D.ThreeRounds{a, b, c} 3n+rest:
      false_true(Q.round.no_items(A.support.round(plan, index)), bounded_zero(rest, bounded))

def round_items(+round: D.RoundRules) -> {Q.items.disabled(A.support.items(round)) == Q.round.no_items(round) : Bool}:
  match round:
    case D.RoundRules{health, loads, items}:
      {==}

def current_disabled(+world: S.World, +seats: A.Seats(), supported: {Q.config.no_items(S.world.config(world)) == True{} : Bool}, bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}) -> {Q.items.disabled(A.support.current_items(world, seats)) == True{} : Bool}:
  match world:
    case S.World{D.Config{table, +plan}, before, +index, load_index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, decks}:
      Equal.trans(Bool, Q.items.disabled(A.support.current_items(world, seats)), Q.round.no_items(A.support.round(plan, index)), True{}, round_items(A.support.round(plan, index)), selected_members(plan, index, supported, bounded))

def zero_bound(+plan: D.Plan) -> {Nat.is_lt(0n, D.plan.length(plan)) == True{} : Bool}:
  match plan:
    case D.OneRound{a}:
      {==}
    case D.TwoRounds{a, b}:
      {==}
    case D.ThreeRounds{a, b, c}:
      {==}

def nonfinal_next(+before: Bool, +plan: D.Plan, +index: Nat, bounded: {Nat.is_lt(index, D.plan.length(plan)) == True{} : Bool}, nonfinal: {Nat.is_eq(1n+index, D.plan.length(plan)) == False{} : Bool}) -> {Nat.is_lt(Q.round.next(before, index), D.plan.length(plan)) == True{} : Bool}:
  match before:
    case True{}:
      zero_bound(plan)
    case False{}:
      match plan index:
        case D.OneRound{a} 0n:
          Equal.sym(Bool, True{}, False{}, nonfinal)
        case D.OneRound{a} 1n+rest:
          false_true(Nat.is_lt(1n+index, D.plan.length(plan)), bounded_zero(rest, bounded))
        case D.TwoRounds{a, b} 0n:
          {==}
        case D.TwoRounds{a, b} 1n:
          Equal.sym(Bool, True{}, False{}, nonfinal)
        case D.TwoRounds{a, b} 2n+rest:
          false_true(Nat.is_lt(1n+index, D.plan.length(plan)), bounded_zero(rest, bounded))
        case D.ThreeRounds{a, b, c} 0n:
          {==}
        case D.ThreeRounds{a, b, c} 1n:
          {==}
        case D.ThreeRounds{a, b, c} 2n:
          Equal.sym(Bool, True{}, False{}, nonfinal)
        case D.ThreeRounds{a, b, c} 3n+rest:
          false_true(Nat.is_lt(1n+index, D.plan.length(plan)), bounded_zero(rest, bounded))
