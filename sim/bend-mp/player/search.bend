import Base
import ../domain.bend as D
import ../simple/state.bend as T
import ../simple/main.bend as M
import ./types.bend as A
import ./belief.bend as B
import ./evaluation.bend as E
import ../sm/items.bend as I
import ./deal.bend as L

# Bounded paranoid expectiminimax over a belief (ADR-0043). A node holds the
# public belief and the searcher's private belief. The searcher maximizes its
# private value; every opponent picks the move that minimizes the public
# value, so it never uses the searcher's clues.

# What in one world's notes depends on its hidden shells and deck. After the
# same move, worlds of one belief hear the same notes exactly when these agree:
# every other event follows from the public state and the move.
type Seen is Data:
  Shell{shell: D.Shell}
  Load{load: D.Load}
  Glimpse{shell: D.Shell}
  Clue{position: Nat, shell: D.Shell}

def seen.event(event: D.GameEvent, rest: List<&2, Seen>) -> List<&2, Seen>:
  match event:
    case D.Fired{_, _, shell, _, _, _}:
      Shell{shell} <> rest
    case D.Ejected{_, shell}:
      Shell{shell} <> rest
    case D.Loaded{load}:
      Load{load} <> rest
    case _:
      rest

def seen.secret(secret: D.Secret, rest: List<&2, Seen>) -> List<&2, Seen>:
  match secret:
    case D.Glimpse{shell}:
      Glimpse{shell} <> rest
    case D.Clue{position, shell}:
      Clue{position, shell} <> rest
    case _:
      rest

def seen.told(mine: Bool, secret: D.Secret, rest: List<&2, Seen>) -> List<&2, Seen>:
  match mine:
    case True{}:
      seen.secret(secret, rest)
    case False{}:
      rest

# With private False only public events count; with True also me's secrets.
def seen(notes: List<&2, D.Note>, +me: D.Seat, +private: Bool) -> List<&2, Seen>:
  match notes:
    case Nil{}:
      Nil{}
    case D.Shown{event} <> rest:
      seen.event(event, seen(rest, me, private))
    case D.Told{seat, secret} <> rest:
      seen.told(Bool.and(private, D.seat.eq(seat, me)), secret, seen(rest, me, private))

def seen.same(a: Seen, b: Seen) -> Bool:
  match a b:
    case Shell{x} Shell{y}:
      B.shell.eq(x, y)
    case Load{x} Load{y}:
      B.load.eq(x, y)
    case Glimpse{x} Glimpse{y}:
      B.shell.eq(x, y)
    case Clue{i, x} Clue{j, y}:
      Bool.and(Nat.is_eq(i, j), B.shell.eq(x, y))
    case _ _:
      False{}

def seen.eq(a: List<&2, Seen>, b: List<&2, Seen>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case x <> xs y <> ys:
      Bool.and(seen.same(x, y), seen.eq(xs, ys))
    case _ _:
      False{}

# One world after a move, with what the public and the searcher observed.
type Out is Data:
  Out{state: T.State, weight: F32, public: List<&2, Seen>, private: List<&2, Seen>}

def out.of(+state: T.State, +notes: List<&2, D.Note>, +weight: F32, +me: D.Seat) -> Out:
  Out{state, weight, seen(notes, me, False{}), seen(notes, me, True{})}

def phone.answered(stepped: D.Stepped<&2, T.State>, notes: List<&2, D.Note>, +weight: F32, +me: D.Seat) -> Out:
  match stepped:
    case D.Stepped{state, later}:
      out.of(state, List.append(&2, D.Note, notes, later), weight, me)

# Each phone index is an equally likely draw: answer k is the k-th value.
def phone.draws(count: Nat, +state: T.State, +notes: List<&2, D.Note>, +weight: F32, +me: D.Seat) -> List<&2, Out>:
  match count:
    case 0n:
      Nil{}
    case 1n+(+k):
      phone.answered(M.answer(state, k), notes, weight, me) <> phone.draws(k, state, notes, weight, me)

# A move ends at a choice, a draw or the end of the round. Only the phone's
# draw is expanded here; the draws of a reload are left to the evaluation.
def settle(request: T.Request, +state: T.State, +notes: List<&2, D.Note>, +weight: F32, +me: D.Seat) -> List<&2, Out>:
  match request:
    case T.Draw{D.PhoneIndex{}, D.Range{_, extra}}:
      +count : Nat = 2n+extra
      phone.draws(count, state, notes, F32.div(weight, F32.from_nat(count)), me)
    case _:
      [out.of(state, notes, weight, me)]

def play.stepped(stepped: D.Stepped<&2, T.State>, +weight: F32, +me: D.Seat) -> List<&2, Out>:
  match stepped:
    case D.Stepped{+state, notes}:
      settle(M.request(state), state, notes, weight, me)

def play(worlds: List<&2, A.World>, +index: Nat, +me: D.Seat) -> List<&2, Out>:
  match worlds:
    case Nil{}:
      Nil{}
    case A.World{state, +weight} <> rest:
      List.append(&2, Out, play.stepped(M.answer(state, index), weight, me), play(rest, index, me))

def out.key(out: Out, private: Bool) -> List<&2, Seen>:
  match out private:
    case Out{_, _, public, _} False{}:
      public
    case Out{_, _, _, key} True{}:
      key

def out.weight(out: Out) -> F32:
  match out:
    case Out{_, weight, _, _}:
      weight

type Group is Data:
  Group{key: List<&2, Seen>, outs: List<&2, Out>, mass: F32}

def group.added(group: Group, +out: Out) -> Group:
  match group:
    case Group{key, outs, mass}:
      Group{key, List.append(&2, Out, outs, [out]), F32.add(mass, out.weight(out))}

def group.key(group: Group) -> List<&2, Seen>:
  match group:
    case Group{key, _, _}:
      key

def group.insert(groups: List<&2, Group>, +out: Out, +key: List<&2, Seen>) -> List<&2, Group>:
  match groups:
    case Nil{}:
      [Group{key, [out], out.weight(out)}]
    case +group <> +rest:
      Bool.pick(List<&2, Group>, seen.eq(group.key(group), key), group.added(group, out) <> rest, group <> group.insert(rest, out, key))

# Groups in order of first appearance.
def group(outs: List<&2, Out>, +private: Bool, groups: List<&2, Group>) -> List<&2, Group>:
  match outs:
    case Nil{}:
      groups
    case +out <> rest:
      group(rest, private, group.insert(groups, out, out.key(out, private)))

def outs.matching(outs: List<&2, Out>, +key: List<&2, Seen>) -> List<&2, Out>:
  match outs:
    case Nil{}:
      Nil{}
    case +out <> rest:
      I.keep(Out, seen.eq(out.key(out, False{}), key), out, outs.matching(rest, key))

def worlds.of(outs: List<&2, Out>, +mass: F32) -> List<&2, A.World>:
  match outs:
    case Nil{}:
      Nil{}
    case Out{state, weight, _, _} <> rest:
      A.World{state, F32.div(weight, mass)} <> worlds.of(rest, mass)

# One observation after a move: the public belief and one of the searcher's
# private beliefs inside it, each normalized, and their probabilities. A
# public observation with several private ones gives its public probability
# to the first, so each probability column sums to one.
type Branch is Data:
  Branch{public: List<&2, A.World>, private: List<&2, A.World>, public_p: F32, private_p: F32}

def branches.private(groups: List<&2, Group>, +public: List<&2, A.World>, +public_p: F32) -> List<&2, Branch>:
  match groups:
    case Nil{}:
      Nil{}
    case Group{_, outs, +mass} <> rest:
      Branch{public, worlds.of(outs, mass), public_p, mass} <> branches.private(rest, public, 0.0)

def branches.public(+public: List<&2, A.World>, +public_p: F32, groups: List<&2, Group>) -> List<&2, Branch>:
  match groups:
    case Nil{}:
      [Branch{public, Nil{}, public_p, 0.0}]
    case groups:
      branches.private(groups, public, public_p)

def branches.of(groups: List<&2, Group>, +private: List<&2, Out>) -> List<&2, Branch>:
  match groups:
    case Nil{}:
      Nil{}
    case Group{+key, outs, +mass} <> rest:
      List.append(&2, Branch, branches.public(worlds.of(outs, mass), mass, group(outs.matching(private, key), True{}, Nil{})), branches.of(rest, private))

# The observations after move `index`, from normalized beliefs.
def outcomes(+public: List<&2, A.World>, +private: List<&2, A.World>, +index: Nat, +me: D.Seat) -> List<&2, Branch>:
  branches.of(group(play(public, index, me), False{}, Nil{}), play(private, index, me))

def millionths(x: F32) -> U32:
  U32.min(1000000, F32.to_u32(F32.add(x, 0.5)))

def static(+worlds: List<&2, A.World>, +me: D.Seat) -> U32:
  millionths(E.sum(worlds, me, E.known(worlds)))

# A belief with no private worlds is a public observation the searcher's
# clues rule out; its private value has no weight and copies the public one.
def static.private(worlds: List<&2, A.World>, +me: D.Seat, +public: U32) -> U32:
  match worlds:
    case Nil{}:
      public
    case +worlds:
      static(worlds, me)

type Option is Data:
  Option{index: Nat, move: T.Move}

def options.of(moves: List<&2, T.Move>, +index: Nat) -> List<&2, Option>:
  match moves:
    case Nil{}:
      Nil{}
    case move <> rest:
      Option{index, move} <> options.of(rest, 1n+index)

# One move's score at a node: the public value (what opponents believe) and
# the private value (what the searcher believes), and the decisions that follow.
type Scored is Data:
  Scored{index: Nat, move: T.Move, public: U32, private: U32, pv: List<&2, T.Move>}

type Searched is Data:
  Value{public: U32, private: U32, pv: List<&2, T.Move>, nodes: Nat}
  Scores{scored: List<&2, Scored>, nodes: Nat}
  Spent{nodes: Nat}

# The branch sums so far, and the most likely private branch's PV.
type Sum is Data:
  Sum{public: F32, private: F32, pv: List<&2, T.Move>, pv_p: F32}

type Task is Data:
  Known{result: Searched}
  Node{depth: Nat, public: List<&2, A.World>, private: List<&2, A.World>, nodes: Nat}
  Decide{mine: Bool, moves: Task}
  Moves{depth: Nat, public: List<&2, A.World>, private: List<&2, A.World>, options: List<&2, Option>, scored: List<&2, Scored>, nodes: Nat}
  Scoring{depth: Nat, public: List<&2, A.World>, private: List<&2, A.World>, option: Option, result: Searched, options: List<&2, Option>, scored: List<&2, Scored>}
  Branches{depth: Nat, branches: List<&2, Branch>, sum: Sum, nodes: Nat}
  Adding{depth: Nat, public_p: F32, private_p: F32, result: Searched, branches: List<&2, Branch>, sum: Sum}

def task.nodes(task: Task) -> Nat:
  match task:
    case Known{Value{_, _, _, nodes}}:
      nodes
    case Known{Scores{_, nodes}}:
      nodes
    case Known{Spent{nodes}}:
      nodes
    case Node{_, _, _, nodes}:
      nodes
    case Decide{_, moves}:
      task.nodes(moves)
    case Moves{_, _, _, _, _, nodes}:
      nodes
    case Branches{_, _, _, nodes}:
      nodes
    case _:
      0n

def node.leaf(+public: List<&2, A.World>, private: List<&2, A.World>, +nodes: Nat, +me: D.Seat) -> Task:
  +value : U32 = static(public, me)
  Known{Value{value, static.private(private, me, value), Nil{}, nodes}}

# With no private worlds the private value is the public one, as in static.private.
def expected.private(worlds: List<&2, A.World>, +private: F32, +public: U32) -> U32:
  match worlds:
    case Nil{}:
      public
    case _:
      millionths(private)

def node.expected(sums: L.Sums, private: List<&2, A.World>, +nodes: Nat) -> Task:
  match sums:
    case L.Sums{public, of_private}:
      +value : U32 = millionths(public)
      Known{Value{value, expected.private(private, of_private, value), Nil{}, nodes}}

def node.reload(reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, +nodes: Nat, +me: D.Seat) -> Task:
  match reload:
    case A.Static{}:
      node.leaf(public, private, nodes, me)
    case A.ExpectedDeal{}:
      node.expected(L.expected(public, private, me), private, nodes)
    case A.Sampled{count}:
      node.expected(L.sampled(public, private, me, count), private, nodes)

# Only a reload leaves a node at a draw: the phone's draw is expanded by
# settle, and a round's opening draws follow its end, which is a leaf first.
def node.request(request: T.Request, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +nodes: Nat, +me: D.Seat, +reload: A.Reload) -> Task:
  match request depth:
    case T.Choose{seat, D.NonEmpty{move, rest}} 1n+child:
      Decide{D.seat.eq(seat, me), Moves{child, public, private, options.of(move <> rest, 0n), Nil{}, nodes}}
    case T.Draw{_, _} _:
      node.reload(reload, public, private, nodes, me)
    case _ _:
      node.leaf(public, private, nodes, me)

# A move that won the round is a leaf with its exact value, even when the
# next round began without a draw and already waits on a choice.
def node.ended(ended: Maybe<&2, U32>, +state: T.State, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +nodes: Nat, +me: D.Seat, +reload: A.Reload) -> Task:
  match ended:
    case Some{_}:
      node.leaf(public, private, nodes, me)
    case None{}:
      node.request(M.request(state), depth, public, private, nodes, me, reload)

# What a node does: a choice with depth left is a decision; the end of the
# round, a reload or no depth left is evaluated. RoundWon is public, so the
# first world's notes speak for every world.
def node.task(depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +nodes: Nat, +me: D.Seat, +reload: A.Reload) -> Task:
  match public:
    case Nil{}:
      Known{Value{0, 0, Nil{}, nodes}}
    case A.World{+state, _} <> _:
      node.ended(E.exact(T.state.notes(state), me), state, depth, public, private, nodes, me, reload)

# A move costs one node per world it is played in. A move the budget cannot
# pay for spends the iteration.
def moves.branches(fits: Bool, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +index: Nat, +nodes: Nat, +spent: Nat, +me: D.Seat) -> Task:
  match fits:
    case False{}:
      Known{Spent{nodes}}
    case True{}:
      Branches{depth, outcomes(public, private, index, me), Sum{0.0, 0.0, Nil{}, F32.neg(1.0)}, spent}

def moves.task(+depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +index: Nat, +nodes: Nat, +me: D.Seat, +budget: Nat) -> Task:
  +spent : Nat = Nat.add(nodes, Nat.add(List.length(&2, A.World, public), List.length(&2, A.World, private)))
  moves.branches(Nat.is_le(spent, budget), depth, public, private, index, nodes, spent, me)

def scoring.next(+depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, option: Option, result: Searched, options: List<&2, Option>, scored: List<&2, Scored>) -> Task:
  match option result:
    case Option{index, +move} Value{public_v, private_v, pv, nodes}:
      Moves{depth, public, private, options, Scored{index, move, public_v, private_v, move <> pv} <> scored, nodes}
    case _ Spent{nodes}:
      Known{Spent{nodes}}
    case _ Scores{_, nodes}:
      Known{Spent{nodes}}

def sum.add(sum: Sum, +public_p: F32, +private_p: F32, +public: U32, +private: U32, pv: List<&2, T.Move>) -> Sum:
  match sum:
    case Sum{sp, sq, best, +best_p}:
      +more : F32 = F32.add(sp, F32.mul(public_p, U32.to_f32(public)))
      +less : F32 = F32.add(sq, F32.mul(private_p, U32.to_f32(private)))
      Bool.pick(Sum, F32.is_gt(private_p, best_p), Sum{more, less, pv, private_p}, Sum{more, less, best, best_p})

def adding.next(+depth: Nat, +public_p: F32, +private_p: F32, result: Searched, branches: List<&2, Branch>, sum: Sum) -> Task:
  match result:
    case Value{public, private, pv, nodes}:
      Branches{depth, branches, sum.add(sum, public_p, private_p, public, private, pv), nodes}
    case Spent{nodes}:
      Known{Spent{nodes}}
    case Scores{_, nodes}:
      Known{Spent{nodes}}

def sum.value(sum: Sum, +nodes: Nat) -> Searched:
  match sum:
    case Sum{public, private, pv, _}:
      Value{millionths(public), millionths(private), pv, nodes}

def scored.public(s: Scored) -> U32:
  match s:
    case Scored{_, _, value, _, _}:
      value

def scored.private(s: Scored) -> U32:
  match s:
    case Scored{_, _, _, value, _}:
      value

# Ties keep the first canonical move.
def pick.max(scored: List<&2, Scored>, +best: Scored) -> Scored:
  match scored:
    case Nil{}:
      best
    case +s <> rest:
      pick.max(rest, Bool.pick(Scored, U32.is_gt(scored.private(s), scored.private(best)), s, best))

def pick.min(scored: List<&2, Scored>, +best: Scored) -> Scored:
  match scored:
    case Nil{}:
      best
    case +s <> rest:
      pick.min(rest, Bool.pick(Scored, U32.is_lt(scored.public(s), scored.public(best)), s, best))

def public.max(scored: List<&2, Scored>, +best: U32) -> U32:
  match scored:
    case Nil{}:
      best
    case s <> rest:
      public.max(rest, U32.max(best, scored.public(s)))

def decide.chosen(mine: Bool, chosen: Scored, +public_best: U32, +nodes: Nat) -> Searched:
  match mine chosen:
    case True{} Scored{_, _, _, private, pv}:
      Value{public_best, private, pv, nodes}
    case False{} Scored{_, _, public, private, pv}:
      Value{public, private, pv, nodes}

# The searcher takes its best private value, and the public believes it
# takes its best public one. An opponent takes the lowest public value.
def decide(mine: Bool, result: Searched) -> Searched:
  match mine result:
    case +mine Scores{+first <> +rest, +nodes}:
      decide.chosen(mine, Bool.pick(Scored, mine, pick.max(rest, first), pick.min(rest, first)), public.max(rest, scored.public(first)), nodes)
    case _ Scores{Nil{}, nodes}:
      Spent{nodes}
    case _ result:
      result

# One def runs every step, so the recursion has one fuel. Each step spends a
# unit, and a step that cannot run spends the iteration.
def search(fuel: Nat, task: Task, +me: D.Seat, +budget: Nat, +reload: A.Reload) -> Searched:
  match fuel task:
    case 0n task:
      Spent{task.nodes(task)}
    case _ Known{result}:
      result
    case 1n+(+fuel) Node{depth, public, private, nodes}:
      search(fuel, node.task(depth, public, private, nodes, me, reload), me, budget, reload)
    case 1n+(+fuel) Decide{mine, moves}:
      decide(mine, search(fuel, moves, me, budget, reload))
    case _ Moves{_, _, _, Nil{}, scored, nodes}:
      Scores{List.reverse(&2, Scored, scored), nodes}
    case 1n+(+fuel) Moves{+depth, +public, +private, Option{+index, move} <> options, scored, nodes}:
      +branches : Task = moves.task(depth, public, private, index, nodes, me, budget)
      search(fuel, Scoring{depth, public, private, Option{index, move}, search(fuel, branches, me, budget, reload), options, scored}, me, budget, reload)
    case 1n+(+fuel) Scoring{depth, public, private, option, result, options, scored}:
      search(fuel, scoring.next(depth, public, private, option, result, options, scored), me, budget, reload)
    case _ Branches{_, Nil{}, sum, nodes}:
      sum.value(sum, nodes)
    case 1n+(+fuel) Branches{+depth, Branch{public, private, public_p, private_p} <> branches, sum, nodes}:
      search(fuel, Adding{depth, public_p, private_p, search(fuel, Node{depth, public, private, nodes}, me, budget, reload), branches, sum}, me, budget, reload)
    case 1n+(+fuel) Adding{depth, public_p, private_p, result, branches, sum}:
      search(fuel, adding.next(depth, public_p, private_p, result, branches, sum), me, budget, reload)

def line.of(scored: Scored) -> A.Line:
  match scored:
    case Scored{index, move, _, private, pv}:
      A.Line{index, move, private, pv}

def lines.of(scored: List<&2, Scored>) -> List<&2, A.Line>:
  match scored:
    case Nil{}:
      Nil{}
    case s <> rest:
      line.of(s) <> lines.of(rest)

def line.best(lines: List<&2, A.Line>, +best: A.Line) -> A.Line:
  match lines:
    case Nil{}:
      best
    case +line <> rest:
      line.best(rest, Bool.pick(A.Line, U32.is_gt(A.line.score(line), A.line.score(best)), line, best))

def analysed(+lines: List<&2, A.Line>, nodes: Nat, depth: Nat, limited: Bool) -> A.Analysis:
  match lines:
    case Nil{}:
      A.Invalid{"no legal move", nodes}
    case +first <> rest:
      +best : A.Line = line.best(rest, first)
      A.Analysed{lines, A.line.index(best), A.line.score(best), nodes, depth, limited}

def analysis.limited(analysis: A.Analysis, nodes: Nat) -> A.Analysis:
  match analysis:
    case A.Analysed{lines, best, score, _, depth, _}:
      A.Analysed{lines, best, score, nodes, depth, True{}}
    case A.Invalid{reason, _}:
      A.Invalid{reason, nodes}

# Every move scores the static value of the belief, with no move played.
def lines.static(options: List<&2, Option>, +score: U32) -> List<&2, A.Line>:
  match options:
    case Nil{}:
      Nil{}
    case Option{index, +move} <> rest:
      A.Line{index, move, score, [move]} <> lines.static(rest, score)

def fuel(budget: Nat) -> Nat:
  Nat.add(Nat.mul(budget, 8n), 64n)

# Iterative deepening. `attempt` is the search to `depth` decisions; only a
# finished one replaces `completed`, and the node count runs on across depths.
def deepen(steps: Nat, attempt: Searched, completed: A.Analysis, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload) -> A.Analysis:
  match steps attempt:
    case _ Spent{nodes}:
      analysis.limited(completed, nodes)
    case 0n Scores{scored, nodes}:
      analysed(lines.of(scored), nodes, depth, False{})
    case 1n+rest Scores{scored, +nodes}:
      +next : Searched = search(fuel(budget), Moves{depth, public, private, options, Nil{}, nodes}, me, budget, reload)
      deepen(rest, next, analysed(lines.of(scored), nodes, depth, False{}), 1n+depth, public, private, options, me, budget, reload)
    case _ Value{_, _, _, nodes}:
      analysis.limited(completed, nodes)

def root(depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload) -> A.Analysis:
  match depth:
    case 0n:
      analysed(lines.static(options, static(private, me)), 0n, 0n, False{})
    case 1n+rest:
      +first : Searched = search(fuel(budget), Moves{0n, public, private, options, Nil{}, 0n}, me, budget, reload)
      deepen(rest, first, analysed(lines.static(options, static(private, me)), 0n, 0n, True{}), 1n, public, private, options, me, budget, reload)

def root.turn(mine: Bool, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload) -> A.Analysis:
  match mine:
    case True{}:
      root(depth, public, private, options, me, budget, reload)
    case False{}:
      A.Invalid{"it is not this player's turn", 0n}

def root.request(request: T.Request, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat, +budget: Nat, +reload: A.Reload) -> A.Analysis:
  match request:
    case T.Choose{seat, D.NonEmpty{move, rest}}:
      root.turn(D.seat.eq(seat, me), depth, public, private, options.of(move <> rest, 0n), me, budget, reload)
    case _:
      A.Invalid{"the position is not a choice", 0n}

def root.belief(public: List<&2, A.World>, +private: List<&2, A.World>, depth: Nat, +me: D.Seat, +budget: Nat, +reload: A.Reload) -> A.Analysis:
  match public:
    case Nil{}:
      A.Invalid{"public log has no consistent shell/deck belief", 0n}
    case A.World{+state, +weight} <> +rest:
      root.request(M.request(state), depth, A.World{state, weight} <> rest, private, me, budget, reload)

def analyse.built(built: B.Built, depth: Nat, +budget: Nat, +reload: A.Reload) -> A.Analysis:
  match built:
    case B.Built{A.Belief{public, private, me, _}}:
      root.belief(public, private, depth, me, budget, reload)
    case B.Rejected{reason}:
      A.Invalid{reason, 0n}

def analyse.dealt(table: D.Table, +position: A.Position, depth: Nat, +budget: Nat, +reload: A.Reload) -> A.Analysis:
  match table:
    case D.TwoSeats{}:
      analyse.built(B.build(position), depth, budget, reload)
    case D.ThreeSeats{}:
      A.Invalid{"a leaf that deals the reload takes two seats only", 0n}
    case D.FourSeats{}:
      A.Invalid{"a leaf that deals the reload takes two seats only", 0n}

def analyse.table(table: D.Table, +position: A.Position, depth: Nat, +budget: Nat, +reload: A.Reload) -> A.Analysis:
  match reload:
    case A.Static{}:
      analyse.built(B.build(position), depth, budget, reload)
    case A.ExpectedDeal{}:
      analyse.dealt(table, position, depth, budget, reload)
    case A.Sampled{0n}:
      A.Invalid{"the sampled leaf needs at least one deal", 0n}
    case A.Sampled{1n+more}:
      analyse.dealt(table, position, depth, budget, A.Sampled{1n+more})

def analyse(position: A.Position, depth: Nat, +budget: Nat, +reload: A.Reload) -> A.Analysis:
  match position:
    case A.Position{D.Config{+table, plan}, board, log, me}:
      analyse.table(table, A.Position{D.Config{table, plan}, board, log, me}, depth, budget, reload)
