import Base
import ./rational.bend as R
import ./state.bend as S
import ./model.bend as M
import ./heuristic.bend as H

type Answer is Data:
  Answer{move: Maybe<&2, Nat>, value: R.Q, path: List<&2, Nat>, nodes: Nat}

type Task is Data:
  Error{message: String}
  Return{answer: Answer}
  Node{depth: Nat, state: S.State, alpha: R.Q, beta: R.Q}
  Moves{depth: Nat, state: S.State, alpha: R.Q, beta: R.Q, moves: List<&2, Nat>, best: Answer}
  Outcomes{depth: Nat, state: S.State, alpha: R.Q, beta: R.Q, moves: List<&2, Nat>, move: Nat, outcomes: List<&2, M.Outcome>, best: Answer, expected: R.Q, line: List<&2, Nat>}

def value(answer: Answer) -> R.Q:
  match answer:
    case Answer{_, v, _, _}: v

def nodes(answer: Answer) -> Nat:
  match answer:
    case Answer{_, _, _, n}: n

def path(answer: Answer) -> List<&2, Nat>:
  match answer:
    case Answer{_, _, p, _}: p

def counted(answer: Answer) -> Answer:
  match answer:
    case Answer{m, v, p, n}: Answer{m, v, p, 1n+n}

def with_nodes(answer: Answer, n: Nat) -> Answer:
  match answer:
    case Answer{m, v, p, _}: Answer{m, v, p, n}

def update(+p: Bool, +m: Nat, +best: Answer, +child: Answer) -> Answer:
  +better : Bool = Bool.pick(Bool, p, R.lt(value(best), value(child)), R.lt(value(child), value(best)))
  +chosen : Answer = Bool.pick(Answer, better, Answer{Some{m}, value(child), m <> path(child), 0n}, best)
  with_nodes(chosen, Nat.add(nodes(best), nodes(child)))

def leaf(result: Result<&2, &2, String, R.Q>) -> Task:
  match result:
    case Fail{e}: Error{e}
    case Done{v}: Return{Answer{None{}, v, Nil{}, 0n}}

def prepare.moves(result: Result<&2, &2, String, List<&2, Nat>>, +depth: Nat, +s: S.State, alpha: R.Q, beta: R.Q) -> Task:
  match result:
    case Fail{e}: Error{e}
    case Done{ms}:
      +default : Nat = Bool.pick(Nat, S.player(s), M.player(), M.dealer())
      best : Answer = Answer{Some{default}, Bool.pick(R.Q, S.player(s), R.neg(R.nat(1000000n)), R.nat(1000000n)), [default], 0n}
      Moves{depth, s, alpha, beta, ms, best}

def prepare.node(terminal: Bool, +fixed: Bool, +depth: Nat, +s: S.State, +alpha: R.Q, +beta: R.Q) -> Task:
  match terminal:
    case True{}: leaf(H.terminal(fixed, s))
    case False{}: prepare.moves(H.moves(fixed, s), depth, s, alpha, beta)

def prepare.outcomes(result: Result<&2, &2, String, List<&2, M.Outcome>>, depth: Nat, s: S.State, alpha: R.Q, beta: R.Q, rest: List<&2, Nat>, m: Nat, best: Answer) -> Task:
  match result:
    case Fail{e}: Error{e}
    case Done{xs}:
      match xs:
        case Nil{}: Moves{depth, s, alpha, beta, rest, best}
        case x <> tail: Outcomes{depth, s, alpha, beta, rest, m, x <> tail, best, R.nat(0n), Nil{}}

def prepare.child(result: Result<&2, &2, String, Answer>, +fixed: Bool, +depth: Nat, +s: S.State, +alpha: R.Q, +beta: R.Q, +ms: List<&2, Nat>, +m: Nat, +rest: List<&2, M.Outcome>, +best: Answer, expected: R.Q, +line: List<&2, Nat>, probability: R.Q) -> Task:
  match result:
    case Fail{e}: Error{e}
    case Done{+answer}:
      +next : Answer = Bool.pick(Answer, fixed, with_nodes(best, Nat.add(nodes(best), nodes(answer))), update(S.player(s), m, best, answer))
      +a : R.Q = Bool.pick(R.Q, Bool.and(Bool.not(fixed), S.player(s)), R.max(alpha, value(next)), alpha)
      +b : R.Q = Bool.pick(R.Q, Bool.and(Bool.not(fixed), Bool.not(S.player(s))), R.min(beta, value(next)), beta)
      +cut : Bool = Bool.and(Bool.not(fixed), Bool.not(R.lt(a, b)))
      +sum : R.Q = R.add(expected, R.mul(probability, value(answer)))
      +representative : List<&2, Nat> = Bool.pick(List<&2, Nat>, Nat.is_eq(List.length(&2, Nat, line), 0n), path(answer), line)
      Bool.pick(Task, cut, Return{counted(next)}, Outcomes{depth, s, a, b, ms, m, rest, next, sum, representative})

# Fuel counts interpreter frames on one line, not visited tree nodes.
def walk(fuel: Nat, +fixed: Bool, task: Task) -> Result<&2, &2, String, Answer>:
  match fuel task:
    case _ Error{e}: Fail{e}
    case _ Return{answer}: Done{answer}
    case 0n _: Fail{"internal search budget exhausted"}
    case 1n+ +left Node{+depth, +s, +alpha, +beta}:
      +terminal : Bool = Bool.or(Nat.is_eq(depth, 0n), Bool.or(Nat.is_eq(S.player_hp(s), 0n), Bool.or(Nat.is_eq(S.dealer_hp(s), 0n), Bool.pick(Bool, fixed, Nat.is_eq(S.total(s), 0n), Nat.is_eq(S.live(s), 0n)))))
      walk(left, fixed, prepare.node(terminal, fixed, depth, s, alpha, beta))
    case 1n+ +left Moves{+depth, +s, +alpha, +beta, ms, +best}:
      match ms:
        case Nil{}: Done{counted(best)}
        case +m <> +rest:
          +valid : Bool = S.has(M.candidates(fixed, s), m)
          +skip : Task = Moves{depth, s, alpha, beta, rest, best}
          walk(left, fixed, Bool.pick(Task, valid, prepare.outcomes(M.outcomes(fixed, s, m), depth, s, alpha, beta, rest, m, best), skip))
    case 1n+ +left Outcomes{+depth, +s, +alpha, +beta, +ms, +m, xs, +best, +expected, +line}:
      match xs:
        case Nil{}:
          +next : Answer = Bool.pick(Answer, fixed, update(S.player(s), m, best, Answer{Some{m}, expected, line, 0n}), best)
          walk(left, fixed, Moves{depth, s, alpha, beta, ms, next})
        case M.Outcome{+probability, child} <> +rest:
          +next_depth : Nat = Bool.pick(Nat, Nat.is_le(m, 1n), Nat.sub(depth, 1n), depth)
          result : Result<&2, &2, String, Answer> = walk(left, fixed, Node{next_depth, child, Bool.pick(R.Q, fixed, R.neg(R.nat(1000000n)), alpha), Bool.pick(R.Q, fixed, R.nat(1000000n), beta)})
          walk(left, fixed, prepare.child(result, fixed, depth, s, alpha, beta, ms, m, rest, best, expected, line, probability))

def search(+fixed: Bool, +depth: Nat, +s: S.State) -> Result<&2, &2, String, Answer>:
  +items : Nat = Nat.add(List.length(&2, Nat, S.player_items(s)), List.length(&2, Nat, S.dealer_items(s)))
  +budget : Nat = Nat.mul(256n, Nat.add(2n, Nat.add(depth, items)))
  walk(budget, fixed, Node{depth, s, R.neg(R.nat(1000000n)), R.nat(1000000n)})
