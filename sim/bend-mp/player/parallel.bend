import Base
import ../domain.bend as D
import ../simple/state.bend as T
import ../simple/main.bend as M
import ./types.bend as A
import ./belief.bend as B
import ./evaluation.bend as E
import ./deal.bend as L
import ./memo.bend as N
import ./search.bend as S

# PROTOTYPE (proto/parallel-search): the search of search.bend, unchanged
# except in two places that let a native build share work across threads.
# search.bend and deal.bend stay as they are, so the JS player and its
# evaluator id do not change.
#
# 1. A sampled reload leaf draws its deals in a balanced fork tree, then sums
#    their values in the order deal.bend's sample.sum does, so every score is
#    bit-identical to the sequential leaf.
# 2. With `fan`, each iteration of the deepening searches the root moves in
#    parallel, each with its own memo kept across depths. Each move starts
#    from the nodes spent before the iteration; the iteration finishes only if
#    the sum of what the moves spent fits the budget. Under Off and Charged a
#    move's spend does not depend on the moves searched before it, so scores,
#    depth and `limited` equal the sequential search's. Under Free they may
#    not. Node counts of a limited run and the memo counts differ.

# The static value of deal `k` from one start, as sample.sum draws it.
def deal.at(+state: T.State, +seed: U32, +me: D.Seat, +k: Nat) -> F32:
  L.deal.value(L.sample.deal(L.deal.fuel(), M.request(state), state, L.mix(U32.xor(seed, U32.from_nat(k))), 0), me)

# The values of deals lo+n-1 down to lo, in that order, split in halves.
def deals(fuel: Nat, +n: Nat, +lo: Nat, +state: T.State, +seed: U32, +me: D.Seat) -> List<&2, F32>:
  match fuel n:
    case _ 0n:
      Nil{}
    case _ 1n:
      [deal.at(state, seed, me, lo)]
    case 1n+(+f) _:
      +half : Nat = Nat.div(n, 2n)
      high low = deals(f, Nat.sub(n, half), Nat.add(lo, half), state, seed, me) deals(f, half, lo, state, seed, me)
      List.append(&2, F32, high, low)
    case 0n _:
      Nil{}

def values.sum(values: List<&2, F32>, +sum: F32) -> F32:
  match values:
    case Nil{}:
      sum
    case value <> rest:
      values.sum(rest, F32.add(sum, value))

# deal.bend's sampled.starts, with the deals of each start drawn in parallel.
def sampled.starts(starts: List<&2, L.Dealt>, +count: Nat, +me: D.Seat, sums: L.Sums) -> L.Sums:
  match starts:
    case Nil{}:
      sums
    case L.Dealt{+state, public, private} <> rest:
      +sum : F32 = values.sum(deals(count, count, 0n, state, L.key.seed(L.key(state, True{}), 2166136261), me), 0.0)
      sampled.starts(rest, count, me, L.sums.scaled(sums, public, private, F32.div(sum, F32.from_nat(count))))

def sampled(+public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat, +count: Nat) -> L.Sums:
  sampled.starts(Map.values(&2, L.Dealt, L.starts(public, private)), count, me, L.Sums{0.0, 0.0})

def deal.sums(reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat) -> L.Sums:
  match reload:
    case A.Sampled{count}:
      sampled(public, private, me, count)
    case _:
      L.expected(public, private, me)

def deal.found(found: Maybe<&2, N.Stored>, tally: N.Tally, +key: String, +reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat) -> S.Task:
  match found:
    case Some{N.Deal{sums}}:
      S.node.expected(sums, private, N.tally.deal_hit(tally))
    case _:
      +sums : L.Sums = deal.sums(reload, public, private, me)
      S.node.expected(sums, private, N.keep(tally, key, N.Deal{sums}))

def deal.taken(taken: N.Tally & Maybe<&2, N.Stored>, +key: String, +reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat) -> S.Task:
  (tally, found) = taken
  deal.found(found, tally, key, reload, public, private, me)

# A deal leaf's value depends on its beliefs alone, so the memo keeps it
# whatever the depth.

def node.dealt(memo: A.Memo, +reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, tally: N.Tally, +me: D.Seat) -> S.Task:
  match memo:
    case A.Off{}:
      S.node.expected(deal.sums(reload, public, private, me), private, tally)
    case _:
      +key : String = SCon{Chr{0}, N.key(public, private)}
      deal.taken(N.find(tally, key), key, reload, public, private, me)

def node.reload(reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, tally: N.Tally, +me: D.Seat, +memo: A.Memo) -> S.Task:
  match reload:
    case A.Static{}:
      S.node.leaf(public, private, tally, A.Reloads{}, me)
    case +reload:
      node.dealt(memo, reload, public, private, tally, me)

def node.request(request: T.Request, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, tally: N.Tally, +me: D.Seat, +reload: A.Reload, +memo: A.Memo, +budget: Nat) -> S.Task:
  match request depth:
    case T.Choose{seat, D.NonEmpty{move, rest}} 1n+child:
      S.node.choose(memo, D.seat.eq(seat, me), child, public, private, S.options.of(move <> rest, 0n), tally, budget)
    case T.Draw{_, _} _:
      node.reload(reload, public, private, tally, me, memo)
    case _ _:
      S.node.leaf(public, private, tally, A.Cut{}, me)

# A move that won the round is a leaf with its exact value, even when the
# next round began without a draw and already waits on a choice.

def node.ended(ended: Maybe<&2, U32>, +state: T.State, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, tally: N.Tally, +me: D.Seat, +reload: A.Reload, +memo: A.Memo, +budget: Nat) -> S.Task:
  match ended:
    case Some{_}:
      S.node.leaf(public, private, tally, A.Settled{}, me)
    case None{}:
      node.request(M.request(state), depth, public, private, tally, me, reload, memo, budget)

# What a node does: a choice with depth left is a decision; the end of the
# round, a reload or no depth left is evaluated. RoundWon is public, so the
# first world's notes speak for every world.

def node.task(depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, tally: N.Tally, +me: D.Seat, +reload: A.Reload, +memo: A.Memo, +budget: Nat) -> S.Task:
  match public:
    case Nil{}:
      S.Known{S.Value{0, 0, Nil{}, tally, A.Settled{}}}
    case A.World{+state, _} <> _:
      node.ended(E.exact(T.state.notes(state), me), state, depth, public, private, tally, me, reload, memo, budget)

# A move costs one node per world it is played in. A move the budget cannot
# pay for spends the iteration.

def search(fuel: Nat, task: S.Task, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> S.Searched:
  match fuel task:
    case 0n task:
      S.Spent{S.task.tally(task)}
    case _ S.Known{result}:
      result
    case 1n+(+fuel) S.Node{depth, public, private, tally}:
      search(fuel, node.task(depth, public, private, tally, me, reload, memo, budget), me, budget, reload, memo)
    case 1n+(+fuel) S.Decide{mine, kept, moves}:
      S.keep(kept, S.decide(mine, search(fuel, moves, me, budget, reload, memo)))
    case _ S.Moves{_, _, _, Nil{}, scored, tally}:
      S.Scores{List.reverse(&2, S.Scored, scored), tally}
    case 1n+(+fuel) S.Moves{+depth, +public, +private, S.Option{+index, move} <> options, scored, tally}:
      +branches : S.Task = S.moves.task(depth, public, private, index, tally, me, budget)
      search(fuel, S.Scoring{depth, public, private, S.Option{index, move}, search(fuel, branches, me, budget, reload, memo), options, scored}, me, budget, reload, memo)
    case 1n+(+fuel) S.Scoring{depth, public, private, option, result, options, scored}:
      search(fuel, S.scoring.next(depth, public, private, option, result, options, scored), me, budget, reload, memo)
    case _ S.Branches{_, Nil{}, sum, tally}:
      S.sum.value(sum, tally)
    case 1n+(+fuel) S.Branches{+depth, S.Branch{public, private, public_p, private_p} <> branches, sum, tally}:
      search(fuel, S.Adding{depth, public_p, private_p, search(fuel, S.Node{depth, public, private, tally}, me, budget, reload, memo), branches, sum}, me, budget, reload, memo)
    case 1n+(+fuel) S.Adding{depth, public_p, private_p, result, branches, sum}:
      search(fuel, S.adding.next(depth, public_p, private_p, result, branches, sum), me, budget, reload, memo)

def deepen(steps: Nat, attempt: S.Searched, completed: A.Analysis, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, S.Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> A.Analysis:
  match steps attempt:
    case _ S.Spent{tally}:
      S.analysis.limited(completed, tally)
    case 0n S.Scores{scored, tally}:
      S.analysed(S.lines.of(scored), tally, depth, False{})
    case 1n+rest S.Scores{scored, +tally}:
      +next : S.Searched = search(S.fuel(budget), S.Moves{depth, public, private, options, Nil{}, tally}, me, budget, reload, memo)
      deepen(rest, next, S.analysed(S.lines.of(scored), tally, depth, False{}), 1n+depth, public, private, options, me, budget, reload, memo)
    case _ S.Value{_, _, _, tally, _}:
      S.analysis.limited(completed, tally)

def root(depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, S.Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> A.Analysis:
  match depth:
    case 0n:
      S.analysed(S.lines.static(options, S.static(private, me)), N.tally.new(), 0n, False{})
    case 1n+rest:
      +first : S.Searched = search(S.fuel(budget), S.Moves{0n, public, private, options, Nil{}, N.tally.new()}, me, budget, reload, memo)
      deepen(rest, first, S.analysed(S.lines.static(options, S.static(private, me)), N.tally.new(), 0n, True{}), 1n, public, private, options, me, budget, reload, memo)


# A root move and its own memo, kept across the iterations of deepening.
type Arm is Data:
  Arm{option: S.Option, tally: N.Tally}

type Ran is Data:
  Ran{option: S.Option, result: S.Searched}

# One finished iteration: the moves' scores and arms, and the summed tally.
type Round is Data:
  Finished{scored: List<&2, S.Scored>, arms: List<&2, Arm>, tally: N.Tally}
  Overspent{tally: N.Tally}

def arms.of(options: List<&2, S.Option>) -> List<&2, Arm>:
  match options:
    case Nil{}:
      Nil{}
    case option <> rest:
      Arm{option, N.tally.new()} <> arms.of(rest)

def arm.run(arm: Arm, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +start: Nat, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> Ran:
  match arm:
    case Arm{S.Option{+index, move}, tally}:
      +task : S.Task = S.moves.task(depth, public, private, index, N.tally.spend(tally, start), me, budget)
      Ran{S.Option{index, move}, search(S.fuel(budget), task, me, budget, reload, memo)}

def arms.run(arms: List<&2, Arm>, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +start: Nat, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> List<&2, Ran>:
  match arms:
    case Nil{}:
      Nil{}
    case arm <> rest:
      ran rans = arm.run(arm, depth, public, private, start, me, budget, reload, memo) arms.run(rest, depth, public, private, start, me, budget, reload, memo)
      ran <> rans

def tally.sum(tally: N.Tally, +nodes: Nat, total: N.Tally) -> N.Tally:
  match tally total:
    case N.Tally{_, _, entries, hits, deals, deal_hits} N.Tally{_, memo, e, h, d, dh}:
      N.Tally{nodes, memo, Nat.add(entries, e), Nat.add(hits, h), Nat.add(deals, d), Nat.add(deal_hits, dh)}

def round.end(over: Bool, +budget: Nat, scored: List<&2, S.Scored>, arms: List<&2, Arm>, +total: N.Tally) -> Round:
  match over:
    case True{}:
      Overspent{total}
    case False{}:
      Bool.pick(Round, Nat.is_le(N.tally.nodes(total), budget), Finished{List.reverse(&2, S.Scored, scored), List.reverse(&2, Arm, arms), total}, Overspent{total})

# Adds each move's spend since `start` to the total, in the moves' order.
def round.of(rans: List<&2, Ran>, +start: Nat, +budget: Nat, +over: Bool, scored: List<&2, S.Scored>, arms: List<&2, Arm>, +total: N.Tally) -> Round:
  match rans:
    case Nil{}:
      round.end(over, budget, scored, arms, total)
    case Ran{S.Option{+index, +move}, S.Value{public_v, private_v, pv, +tally, reach}} <> rest:
      +nodes : Nat = Nat.add(N.tally.nodes(total), Nat.sub(N.tally.nodes(tally), start))
      round.of(rest, start, budget, over, S.Scored{index, move, public_v, private_v, move <> pv, reach} <> scored, Arm{S.Option{index, move}, tally} <> arms, tally.sum(tally, nodes, total))
    case Ran{_, S.Spent{+tally}} <> rest:
      round.of(rest, start, budget, True{}, scored, arms, tally.sum(tally, Nat.add(N.tally.nodes(total), Nat.sub(N.tally.nodes(tally), start)), total))
    case Ran{_, S.Scores{_, +tally}} <> rest:
      round.of(rest, start, budget, True{}, scored, arms, tally.sum(tally, Nat.add(N.tally.nodes(total), Nat.sub(N.tally.nodes(tally), start)), total))

def round(arms: List<&2, Arm>, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +start: Nat, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> Round:
  round.of(arms.run(arms, depth, public, private, start, me, budget, reload, memo), start, budget, False{}, Nil{}, Nil{}, N.Tally{start, Map.new(&2, List<&2, N.Kept>), 0n, 0n, 0n, 0n})

# deepen, over rounds.
def deepen.fan(steps: Nat, attempt: Round, completed: A.Analysis, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> A.Analysis:
  match steps attempt:
    case _ Overspent{tally}:
      S.analysis.limited(completed, tally)
    case 0n Finished{scored, _, tally}:
      S.analysed(S.lines.of(scored), tally, depth, False{})
    case 1n+rest Finished{scored, arms, +tally}:
      +next : Round = round(arms, depth, public, private, N.tally.nodes(tally), me, budget, reload, memo)
      deepen.fan(rest, next, S.analysed(S.lines.of(scored), tally, depth, False{}), 1n+depth, public, private, me, budget, reload, memo)

def root.fan(depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, S.Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> A.Analysis:
  match depth:
    case 0n:
      S.analysed(S.lines.static(options, S.static(private, me)), N.tally.new(), 0n, False{})
    case 1n+rest:
      +first : Round = round(arms.of(options), 0n, public, private, 0n, me, budget, reload, memo)
      deepen.fan(rest, first, S.analysed(S.lines.static(options, S.static(private, me)), N.tally.new(), 0n, True{}), 1n, public, private, me, budget, reload, memo)

def root.pick(fan: Bool, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, S.Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> A.Analysis:
  match fan:
    case True{}:
      root.fan(depth, public, private, options, me, budget, reload, memo)
    case False{}:
      root(depth, public, private, options, me, budget, reload, memo)

def root.turn(mine: Bool, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, S.Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo, +fan: Bool) -> A.Analysis:
  match mine:
    case True{}:
      root.pick(fan, depth, public, private, options, me, budget, reload, memo)
    case False{}:
      A.Invalid{"it is not this player's turn", 0n}

def root.request(request: T.Request, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo, +fan: Bool) -> A.Analysis:
  match request:
    case T.Choose{seat, D.NonEmpty{move, rest}}:
      root.turn(D.seat.eq(seat, me), depth, public, private, S.options.of(move <> rest, 0n), me, budget, reload, memo, fan)
    case _:
      A.Invalid{"the position is not a choice", 0n}

def root.belief(public: List<&2, A.World>, +private: List<&2, A.World>, depth: Nat, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo, +fan: Bool) -> A.Analysis:
  match public:
    case Nil{}:
      A.Invalid{"public log has no consistent shell/deck belief", 0n}
    case A.World{+state, +weight} <> +rest:
      root.request(M.request(state), depth, A.World{state, weight} <> rest, private, me, budget, reload, memo, fan)

def analyse.built(built: B.Built, depth: Nat, +budget: Nat, +reload: A.Reload, +memo: A.Memo, +fan: Bool) -> A.Analysis:
  match built:
    case B.Built{A.Belief{public, private, me, _}}:
      root.belief(public, private, depth, me, budget, reload, memo, fan)
    case B.Rejected{reason}:
      A.Invalid{reason, 0n}

def analyse.dealt(table: D.Table, +position: A.Position, depth: Nat, +budget: Nat, +reload: A.Reload, +memo: A.Memo, +fan: Bool) -> A.Analysis:
  match table:
    case D.TwoSeats{}:
      analyse.built(B.build(position), depth, budget, reload, memo, fan)
    case D.ThreeSeats{}:
      A.Invalid{"a leaf that deals the reload takes two seats only", 0n}
    case D.FourSeats{}:
      A.Invalid{"a leaf that deals the reload takes two seats only", 0n}

def analyse.table(table: D.Table, +position: A.Position, depth: Nat, +budget: Nat, +reload: A.Reload, +memo: A.Memo, +fan: Bool) -> A.Analysis:
  match reload:
    case A.Static{}:
      analyse.built(B.build(position), depth, budget, reload, memo, fan)
    case A.ExpectedDeal{}:
      analyse.dealt(table, position, depth, budget, reload, memo, fan)
    case A.Sampled{0n}:
      A.Invalid{"the sampled leaf needs at least one deal", 0n}
    case A.Sampled{1n+more}:
      analyse.dealt(table, position, depth, budget, A.Sampled{1n+more}, memo, fan)

def analyse(position: A.Position, depth: Nat, +budget: Nat, +reload: A.Reload, +memo: A.Memo, +fan: Bool) -> A.Analysis:
  match position:
    case A.Position{D.Config{+table, plan}, board, log, me}:
      analyse.table(table, A.Position{D.Config{table, plan}, board, log, me}, depth, budget, reload, memo, fan)
