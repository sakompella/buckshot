import Base
import ../domain.bend as D
import ../simple/state.bend as T
import ../simple/main.bend as M
import ./types.bend as A
import ./belief.bend as B
import ./evaluation.bend as E
import ../sm/items.bend as I
import ./deal.bend as L
import ./memo.bend as N

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

# While grouping, a group's outs are kept last first.
def group.added(group: Group, +out: Out) -> Group:
  match group:
    case Group{key, outs, mass}:
      Group{key, out <> outs, F32.add(mass, out.weight(out))}

def group.ordered(groups: List<&2, Group>) -> List<&2, Group>:
  match groups:
    case Nil{}:
      Nil{}
    case Group{key, outs, mass} <> rest:
      Group{key, List.reverse(&2, Out, outs), mass} <> group.ordered(rest)

# Whether the first group has this key.
def group.first_is(+groups: List<&2, Group>, +key: List<&2, Seen>) -> Bool:
  match groups:
    case Nil{}:
      False{}
    case Group{other, _, _} <> _:
      seen.eq(other, key)

# `same` tells whether the first of `groups` has the key.
def group.insert(groups: List<&2, Group>, same: Bool, +out: Out, +key: List<&2, Seen>) -> List<&2, Group>:
  match groups same:
    case Nil{} _:
      [Group{key, [out], out.weight(out)}]
    case group <> rest True{}:
      group.added(group, out) <> rest
    case group <> +rest False{}:
      group <> group.insert(rest, group.first_is(rest, key), out, key)

# Groups in order of first appearance.
def group(outs: List<&2, Out>, +private: Bool, +groups: List<&2, Group>) -> List<&2, Group>:
  match outs:
    case Nil{}:
      group.ordered(groups)
    case +out <> rest:
      +key : List<&2, Seen> = out.key(out, private)
      group(rest, private, group.insert(groups, group.first_is(groups, key), out, key))

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
  Scored{index: Nat, move: T.Move, public: U32, private: U32, pv: List<&2, T.Move>, reach: A.Reach}

# A result carries the tally on: the nodes spent so far and the memo.
type Searched is Data:
  Value{public: U32, private: U32, pv: List<&2, T.Move>, tally: N.Tally, reach: A.Reach}
  Scores{scored: List<&2, Scored>, tally: N.Tally}
  Spent{tally: N.Tally}

# The branch sums so far, the most likely private branch's PV, and the
# branches' reach.
type Sum is Data:
  Sum{public: F32, private: F32, pv: List<&2, T.Move>, pv_p: F32, reach: A.Reach}

# Whether a decision's value goes into the memo once it is found: under `key`,
# with the depth it was searched to and the nodes spent before it began.
type Keep is Data:
  Forget{}
  Keep{key: String, depth: Nat, start: Nat}

type Task is Data:
  Known{result: Searched}
  Node{depth: Nat, public: List<&2, A.World>, private: List<&2, A.World>, tally: N.Tally}
  Decide{mine: Bool, keep: Keep, moves: Task}
  Moves{depth: Nat, public: List<&2, A.World>, private: List<&2, A.World>, options: List<&2, Option>, scored: List<&2, Scored>, tally: N.Tally}
  Scoring{depth: Nat, public: List<&2, A.World>, private: List<&2, A.World>, option: Option, result: Searched, options: List<&2, Option>, scored: List<&2, Scored>}
  Branches{depth: Nat, branches: List<&2, Branch>, sum: Sum, tally: N.Tally}
  Adding{depth: Nat, public_p: F32, private_p: F32, result: Searched, branches: List<&2, Branch>, sum: Sum}

def searched.tally(result: Searched) -> N.Tally:
  match result:
    case Value{_, _, _, tally, _}:
      tally
    case Scores{_, tally}:
      tally
    case Spent{tally}:
      tally

def task.tally(task: Task) -> N.Tally:
  match task:
    case Known{result}:
      searched.tally(result)
    case Node{_, _, _, tally}:
      tally
    case Decide{_, _, moves}:
      task.tally(moves)
    case Moves{_, _, _, _, _, tally}:
      tally
    case Scoring{_, _, _, _, result, _, _}:
      searched.tally(result)
    case Branches{_, _, _, tally}:
      tally
    case Adding{_, _, _, result, _, _}:
      searched.tally(result)

def node.leaf(+public: List<&2, A.World>, private: List<&2, A.World>, tally: N.Tally, reach: A.Reach, +me: D.Seat) -> Task:
  +value : U32 = static(public, me)
  Known{Value{value, static.private(private, me, value), Nil{}, tally, reach}}

# With no private worlds the private value is the public one, as in static.private.
def expected.private(worlds: List<&2, A.World>, +private: F32, +public: U32) -> U32:
  match worlds:
    case Nil{}:
      public
    case _:
      millionths(private)

def node.expected(sums: L.Sums, private: List<&2, A.World>, tally: N.Tally) -> Task:
  match sums:
    case L.Sums{public, of_private}:
      +value : U32 = millionths(public)
      Known{Value{value, expected.private(private, of_private, value), Nil{}, tally, A.Reloads{}}}

def deal.sums(reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat) -> L.Sums:
  match reload:
    case A.Sampled{count}:
      L.sampled(public, private, me, count)
    case _:
      L.expected(public, private, me)

def deal.found(found: Maybe<&2, N.Stored>, tally: N.Tally, +key: String, +reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat) -> Task:
  match found:
    case Some{N.Deal{sums}}:
      node.expected(sums, private, N.tally.deal_hit(tally))
    case _:
      +sums : L.Sums = deal.sums(reload, public, private, me)
      node.expected(sums, private, N.keep(tally, key, N.Deal{sums}))

def deal.taken(taken: N.Tally & Maybe<&2, N.Stored>, +key: String, +reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat) -> Task:
  (tally, found) = taken
  deal.found(found, tally, key, reload, public, private, me)

# A deal leaf's value depends on its beliefs alone, so the memo keeps it
# whatever the depth.
def node.dealt(memo: A.Memo, +reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, tally: N.Tally, +me: D.Seat) -> Task:
  match memo:
    case A.Off{}:
      node.expected(deal.sums(reload, public, private, me), private, tally)
    case _:
      +key : String = SCon{Chr{0}, N.key(public, private)}
      deal.taken(N.find(tally, key), key, reload, public, private, me)

def node.reload(reload: A.Reload, +public: List<&2, A.World>, +private: List<&2, A.World>, tally: N.Tally, +me: D.Seat, +memo: A.Memo) -> Task:
  match reload:
    case A.Static{}:
      node.leaf(public, private, tally, A.Reloads{}, me)
    case +reload:
      node.dealt(memo, reload, public, private, tally, me)

def choose.search(+tally: N.Tally, +key: String, +mine: Bool, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>) -> Task:
  Decide{mine, Keep{key, depth, N.tally.nodes(tally)}, Moves{depth, public, private, options, Nil{}, tally}}

def choose.hit(fits: Bool, +entry: N.Entry, tally: N.Tally, +charge: Nat, +key: String, +mine: Bool, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>) -> Task:
  match fits entry:
    case True{} N.Entry{public_v, private_v, pv, reach, _, _}:
      Known{Value{public_v, private_v, pv, N.tally.hit(tally, charge), reach}}
    case False{} _:
      choose.search(tally, key, mine, depth, public, private, options)

# An entry serves a node when its value holds at the node's depth and, unless
# reuse is free, the nodes its search spent still fit the budget. When they do
# not, searching again spends the budget just where an unmemoized search would.
def choose.entry(+entry: N.Entry, +tally: N.Tally, +key: String, +memo: A.Memo, +mine: Bool, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +budget: Nat) -> Task:
  match entry:
    case N.Entry{_, _, _, reach, searched, cost}:
      +charge : Nat = N.entry.cost(memo, cost)
      +fits : Bool = Bool.and(N.entry.serves(reach, searched, depth), Nat.is_le(Nat.add(N.tally.nodes(tally), charge), budget))
      choose.hit(fits, entry, tally, charge, key, mine, depth, public, private, options)

def choose.found(found: Maybe<&2, N.Stored>, tally: N.Tally, +key: String, +memo: A.Memo, +mine: Bool, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +budget: Nat) -> Task:
  match found:
    case Some{N.Decision{entry}}:
      choose.entry(entry, tally, key, memo, mine, depth, public, private, options, budget)
    case _:
      choose.search(tally, key, mine, depth, public, private, options)

def choose.taken(taken: N.Tally & Maybe<&2, N.Stored>, +key: String, +memo: A.Memo, +mine: Bool, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +budget: Nat) -> Task:
  (tally, found) = taken
  choose.found(found, tally, key, memo, mine, depth, public, private, options, budget)

def node.choose(memo: A.Memo, +mine: Bool, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, tally: N.Tally, +budget: Nat) -> Task:
  match memo:
    case A.Off{}:
      Decide{mine, Forget{}, Moves{depth, public, private, options, Nil{}, tally}}
    case +memo:
      +key : String = SCon{Chr{1}, N.key(public, private)}
      choose.taken(N.find(tally, key), key, memo, mine, depth, public, private, options, budget)

# Only a reload leaves a node at a draw: the phone's draw is expanded by
# settle, and a round's opening draws follow its end, which is a leaf first.
def node.request(request: T.Request, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, tally: N.Tally, +me: D.Seat, +reload: A.Reload, +memo: A.Memo, +budget: Nat) -> Task:
  match request depth:
    case T.Choose{seat, D.NonEmpty{move, rest}} 1n+child:
      node.choose(memo, D.seat.eq(seat, me), child, public, private, options.of(move <> rest, 0n), tally, budget)
    case T.Draw{_, _} _:
      node.reload(reload, public, private, tally, me, memo)
    case _ _:
      node.leaf(public, private, tally, A.Cut{}, me)

# A move that won the round is a leaf with its exact value, even when the
# next round began without a draw and already waits on a choice.
def node.ended(ended: Maybe<&2, U32>, +state: T.State, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, tally: N.Tally, +me: D.Seat, +reload: A.Reload, +memo: A.Memo, +budget: Nat) -> Task:
  match ended:
    case Some{_}:
      node.leaf(public, private, tally, A.Settled{}, me)
    case None{}:
      node.request(M.request(state), depth, public, private, tally, me, reload, memo, budget)

# What a node does: a choice with depth left is a decision; the end of the
# round, a reload or no depth left is evaluated. RoundWon is public, so the
# first world's notes speak for every world.
def node.task(depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, tally: N.Tally, +me: D.Seat, +reload: A.Reload, +memo: A.Memo, +budget: Nat) -> Task:
  match public:
    case Nil{}:
      Known{Value{0, 0, Nil{}, tally, A.Settled{}}}
    case A.World{+state, _} <> _:
      node.ended(E.exact(T.state.notes(state), me), state, depth, public, private, tally, me, reload, memo, budget)

# A move costs one node per world it is played in. A move the budget cannot
# pay for spends the iteration.
def moves.branches(fits: Bool, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +index: Nat, tally: N.Tally, +spent: Nat, +me: D.Seat) -> Task:
  match fits:
    case False{}:
      Known{Spent{tally}}
    case True{}:
      Branches{depth, outcomes(public, private, index, me), Sum{0.0, 0.0, Nil{}, F32.neg(1.0), A.Settled{}}, N.tally.spend(tally, spent)}

def moves.task(+depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +index: Nat, +tally: N.Tally, +me: D.Seat, +budget: Nat) -> Task:
  +spent : Nat = Nat.add(N.tally.nodes(tally), Nat.add(List.length(&2, A.World, public), List.length(&2, A.World, private)))
  moves.branches(Nat.is_le(spent, budget), depth, public, private, index, tally, spent, me)

def scoring.next(+depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, option: Option, result: Searched, options: List<&2, Option>, scored: List<&2, Scored>) -> Task:
  match option result:
    case Option{index, +move} Value{public_v, private_v, pv, tally, reach}:
      Moves{depth, public, private, options, Scored{index, move, public_v, private_v, move <> pv, reach} <> scored, tally}
    case _ Spent{tally}:
      Known{Spent{tally}}
    case _ Scores{_, tally}:
      Known{Spent{tally}}

def sum.add(sum: Sum, +public_p: F32, +private_p: F32, +public: U32, +private: U32, pv: List<&2, T.Move>, reach: A.Reach) -> Sum:
  match sum:
    case Sum{sp, sq, best, +best_p, reached}:
      +more : F32 = F32.add(sp, F32.mul(public_p, U32.to_f32(public)))
      +less : F32 = F32.add(sq, F32.mul(private_p, U32.to_f32(private)))
      +joined : A.Reach = N.reach.join(reached, reach)
      Bool.pick(Sum, F32.is_gt(private_p, best_p), Sum{more, less, pv, private_p, joined}, Sum{more, less, best, best_p, joined})

def adding.next(+depth: Nat, +public_p: F32, +private_p: F32, result: Searched, branches: List<&2, Branch>, sum: Sum) -> Task:
  match result:
    case Value{public, private, pv, tally, reach}:
      Branches{depth, branches, sum.add(sum, public_p, private_p, public, private, pv, reach), tally}
    case Spent{tally}:
      Known{Spent{tally}}
    case Scores{_, tally}:
      Known{Spent{tally}}

def sum.value(sum: Sum, tally: N.Tally) -> Searched:
  match sum:
    case Sum{public, private, pv, _, reach}:
      Value{millionths(public), millionths(private), pv, tally, reach}

def scored.public(s: Scored) -> U32:
  match s:
    case Scored{_, _, value, _, _, _}:
      value

def scored.private(s: Scored) -> U32:
  match s:
    case Scored{_, _, _, value, _, _}:
      value

# Every move counts: more depth could change any of them, and so the choice.
def scored.reach(scored: List<&2, Scored>, reach: A.Reach) -> A.Reach:
  match scored:
    case Nil{}:
      reach
    case Scored{_, _, _, _, _, r} <> rest:
      scored.reach(rest, N.reach.join(reach, r))

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

def decide.chosen(mine: Bool, chosen: Scored, +public_best: U32, tally: N.Tally, reach: A.Reach) -> Searched:
  match mine chosen:
    case True{} Scored{_, _, _, private, pv, _}:
      Value{public_best, private, pv, tally, reach}
    case False{} Scored{_, _, public, private, pv, _}:
      Value{public, private, pv, tally, reach}

# The searcher takes its best private value, and the public believes it
# takes its best public one. An opponent takes the lowest public value.
def decide(mine: Bool, result: Searched) -> Searched:
  match mine result:
    case +mine Scores{+first <> +rest, tally}:
      decide.chosen(mine, Bool.pick(Scored, mine, pick.max(rest, first), pick.min(rest, first)), public.max(rest, scored.public(first)), tally, scored.reach(rest, scored.reach([first], A.Settled{})))
    case _ Scores{Nil{}, tally}:
      Spent{tally}
    case _ result:
      result

# A found value goes into the memo with the nodes its search spent.
def keep(keep: Keep, result: Searched) -> Searched:
  match keep result:
    case Keep{key, depth, start} Value{+public, +private, +pv, +tally, +reach}:
      +entry : N.Entry = N.Entry{public, private, pv, reach, depth, Nat.sub(N.tally.nodes(tally), start)}
      Value{public, private, pv, N.keep(tally, key, N.Decision{entry}), reach}
    case _ result:
      result

# One def runs every step, so the recursion has one fuel. Each step spends a
# unit, and a step that cannot run spends the iteration.
def search(fuel: Nat, task: Task, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> Searched:
  match fuel task:
    case 0n task:
      Spent{task.tally(task)}
    case _ Known{result}:
      result
    case 1n+(+fuel) Node{depth, public, private, tally}:
      search(fuel, node.task(depth, public, private, tally, me, reload, memo, budget), me, budget, reload, memo)
    case 1n+(+fuel) Decide{mine, kept, moves}:
      keep(kept, decide(mine, search(fuel, moves, me, budget, reload, memo)))
    case _ Moves{_, _, _, Nil{}, scored, tally}:
      Scores{List.reverse(&2, Scored, scored), tally}
    case 1n+(+fuel) Moves{+depth, +public, +private, Option{+index, move} <> options, scored, tally}:
      +branches : Task = moves.task(depth, public, private, index, tally, me, budget)
      search(fuel, Scoring{depth, public, private, Option{index, move}, search(fuel, branches, me, budget, reload, memo), options, scored}, me, budget, reload, memo)
    case 1n+(+fuel) Scoring{depth, public, private, option, result, options, scored}:
      search(fuel, scoring.next(depth, public, private, option, result, options, scored), me, budget, reload, memo)
    case _ Branches{_, Nil{}, sum, tally}:
      sum.value(sum, tally)
    case 1n+(+fuel) Branches{+depth, Branch{public, private, public_p, private_p} <> branches, sum, tally}:
      search(fuel, Adding{depth, public_p, private_p, search(fuel, Node{depth, public, private, tally}, me, budget, reload, memo), branches, sum}, me, budget, reload, memo)
    case 1n+(+fuel) Adding{depth, public_p, private_p, result, branches, sum}:
      search(fuel, adding.next(depth, public_p, private_p, result, branches, sum), me, budget, reload, memo)

def line.of(scored: Scored) -> A.Line:
  match scored:
    case Scored{index, move, _, private, pv, reach}:
      A.Line{index, move, private, pv, reach}

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

def analysed(+lines: List<&2, A.Line>, +tally: N.Tally, depth: Nat, limited: Bool) -> A.Analysis:
  match lines:
    case Nil{}:
      A.Invalid{"no legal move", N.tally.nodes(tally)}
    case +first <> rest:
      +best : A.Line = line.best(rest, first)
      A.Analysed{lines, A.line.index(best), A.line.score(best), N.tally.nodes(tally), depth, limited, N.tally.cached(tally)}

def analysis.limited(analysis: A.Analysis, +tally: N.Tally) -> A.Analysis:
  match analysis:
    case A.Analysed{lines, best, score, _, depth, _, _}:
      A.Analysed{lines, best, score, N.tally.nodes(tally), depth, True{}, N.tally.cached(tally)}
    case A.Invalid{reason, _}:
      A.Invalid{reason, N.tally.nodes(tally)}

# Every move scores the static value of the belief, with no move played.
def lines.static(options: List<&2, Option>, +score: U32) -> List<&2, A.Line>:
  match options:
    case Nil{}:
      Nil{}
    case Option{index, +move} <> rest:
      A.Line{index, move, score, [move], A.Cut{}} <> lines.static(rest, score)

def fuel(budget: Nat) -> Nat:
  Nat.add(Nat.mul(budget, 8n), 64n)

# Iterative deepening. `attempt` is the search to `depth` decisions; only a
# finished one replaces `completed`, and the tally runs on across depths.
def deepen(steps: Nat, attempt: Searched, completed: A.Analysis, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> A.Analysis:
  match steps attempt:
    case _ Spent{tally}:
      analysis.limited(completed, tally)
    case 0n Scores{scored, tally}:
      analysed(lines.of(scored), tally, depth, False{})
    case 1n+rest Scores{scored, +tally}:
      +next : Searched = search(fuel(budget), Moves{depth, public, private, options, Nil{}, tally}, me, budget, reload, memo)
      deepen(rest, next, analysed(lines.of(scored), tally, depth, False{}), 1n+depth, public, private, options, me, budget, reload, memo)
    case _ Value{_, _, _, tally, _}:
      analysis.limited(completed, tally)

def root(depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> A.Analysis:
  match depth:
    case 0n:
      analysed(lines.static(options, static(private, me)), N.tally.new(), 0n, False{})
    case 1n+rest:
      +first : Searched = search(fuel(budget), Moves{0n, public, private, options, Nil{}, N.tally.new()}, me, budget, reload, memo)
      deepen(rest, first, analysed(lines.static(options, static(private, me)), N.tally.new(), 0n, True{}), 1n, public, private, options, me, budget, reload, memo)

# Parallel root
# =============
#
# With `fan`, each iteration of the deepening searches the root moves in
# parallel, each with its own memo kept across depths. Each move starts from
# the nodes spent before the iteration; the iteration finishes only if the sum
# of what the moves spent fits the budget. Under Off and Charged a move's spend
# does not depend on the moves searched before it, so scores, depth and
# `limited` equal the sequential search's. Under Free they may not. Node counts
# of a limited run and the memo counts differ. Only native builds run the moves
# on separate threads; the JS player passes no fan.

type Arm is Data:
  Arm{option: Option, tally: N.Tally}

type Ran is Data:
  Ran{option: Option, result: Searched}

# One finished iteration: the moves' scores and arms, and the summed tally.
type Round is Data:
  Finished{scored: List<&2, Scored>, arms: List<&2, Arm>, tally: N.Tally}
  Overspent{tally: N.Tally}

def arms.of(options: List<&2, Option>) -> List<&2, Arm>:
  match options:
    case Nil{}:
      Nil{}
    case option <> rest:
      Arm{option, N.tally.new()} <> arms.of(rest)

def arm.run(arm: Arm, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +start: Nat, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> Ran:
  match arm:
    case Arm{Option{+index, move}, tally}:
      +task : Task = moves.task(depth, public, private, index, N.tally.spend(tally, start), me, budget)
      Ran{Option{index, move}, search(fuel(budget), task, me, budget, reload, memo)}

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

def round.end(over: Bool, +budget: Nat, scored: List<&2, Scored>, arms: List<&2, Arm>, +total: N.Tally) -> Round:
  match over:
    case True{}:
      Overspent{total}
    case False{}:
      Bool.pick(Round, Nat.is_le(N.tally.nodes(total), budget), Finished{List.reverse(&2, Scored, scored), List.reverse(&2, Arm, arms), total}, Overspent{total})

# Adds each move's spend since `start` to the total, in the moves' order.
def round.of(rans: List<&2, Ran>, +start: Nat, +budget: Nat, +over: Bool, scored: List<&2, Scored>, arms: List<&2, Arm>, +total: N.Tally) -> Round:
  match rans:
    case Nil{}:
      round.end(over, budget, scored, arms, total)
    case Ran{Option{+index, +move}, Value{public_v, private_v, pv, +tally, reach}} <> rest:
      +nodes : Nat = Nat.add(N.tally.nodes(total), Nat.sub(N.tally.nodes(tally), start))
      round.of(rest, start, budget, over, Scored{index, move, public_v, private_v, move <> pv, reach} <> scored, Arm{Option{index, move}, tally} <> arms, tally.sum(tally, nodes, total))
    case Ran{_, Spent{+tally}} <> rest:
      round.of(rest, start, budget, True{}, scored, arms, tally.sum(tally, Nat.add(N.tally.nodes(total), Nat.sub(N.tally.nodes(tally), start)), total))
    case Ran{_, Scores{_, +tally}} <> rest:
      round.of(rest, start, budget, True{}, scored, arms, tally.sum(tally, Nat.add(N.tally.nodes(total), Nat.sub(N.tally.nodes(tally), start)), total))

def round(arms: List<&2, Arm>, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +start: Nat, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> Round:
  round.of(arms.run(arms, depth, public, private, start, me, budget, reload, memo), start, budget, False{}, Nil{}, Nil{}, N.Tally{start, Map.new(&2, List<&2, N.Kept>), 0n, 0n, 0n, 0n})

# deepen, over rounds.
def deepen.fan(steps: Nat, attempt: Round, completed: A.Analysis, +depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> A.Analysis:
  match steps attempt:
    case _ Overspent{tally}:
      analysis.limited(completed, tally)
    case 0n Finished{scored, _, tally}:
      analysed(lines.of(scored), tally, depth, False{})
    case 1n+rest Finished{scored, arms, +tally}:
      +next : Round = round(arms, depth, public, private, N.tally.nodes(tally), me, budget, reload, memo)
      deepen.fan(rest, next, analysed(lines.of(scored), tally, depth, False{}), 1n+depth, public, private, me, budget, reload, memo)

def root.fan(depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> A.Analysis:
  match depth:
    case 0n:
      analysed(lines.static(options, static(private, me)), N.tally.new(), 0n, False{})
    case 1n+rest:
      +first : Round = round(arms.of(options), 0n, public, private, 0n, me, budget, reload, memo)
      deepen.fan(rest, first, analysed(lines.static(options, static(private, me)), N.tally.new(), 0n, True{}), 1n, public, private, me, budget, reload, memo)

def root.pick(fan: Bool, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo) -> A.Analysis:
  match fan:
    case True{}:
      root.fan(depth, public, private, options, me, budget, reload, memo)
    case False{}:
      root(depth, public, private, options, me, budget, reload, memo)

def root.turn(mine: Bool, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +options: List<&2, Option>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo, +fan: Bool) -> A.Analysis:
  match mine:
    case True{}:
      root.pick(fan, depth, public, private, options, me, budget, reload, memo)
    case False{}:
      A.Invalid{"it is not this player's turn", 0n}

def root.request(request: T.Request, depth: Nat, +public: List<&2, A.World>, +private: List<&2, A.World>, +me: D.Seat, +budget: Nat, +reload: A.Reload, +memo: A.Memo, +fan: Bool) -> A.Analysis:
  match request:
    case T.Choose{seat, D.NonEmpty{move, rest}}:
      root.turn(D.seat.eq(seat, me), depth, public, private, options.of(move <> rest, 0n), me, budget, reload, memo, fan)
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
