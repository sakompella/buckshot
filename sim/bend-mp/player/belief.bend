import Base
import ../domain.bend as D
import ../sm/state.bend as S
import ../sm/rules.bend as G
import ../sm/items.bend as I
import ../simple/state.bend as T
import ../simple/main.bend as M
import ../simple/point.bend as P
import ./types.bend as A

def shell.eq(a: D.Shell, b: D.Shell) -> Bool:
  match a b:
    case D.Live{} D.Live{}:
      True{}
    case D.Blank{} D.Blank{}:
      True{}
    case _ _:
      False{}

def shells.prepend(+shell: D.Shell, orders: List<&2, List<&2, D.Shell>>) -> List<&2, List<&2, D.Shell>>:
  match orders:
    case Nil{}:
      Nil{}
    case order <> rest:
      (shell <> order) <> shells.prepend(shell, rest)

# The first argument is the total shells still to place, not a search ply.
def orders(fuel: Nat, live: Nat, blank: Nat) -> List<&2, List<&2, D.Shell>>:
  match fuel live blank:
    case 0n 0n 0n:
      [Nil{}]
    case 1n+fuel 0n 1n+blank:
      shells.prepend(D.Blank{}, orders(fuel, 0n, blank))
    case 1n+fuel 1n+live 0n:
      shells.prepend(D.Live{}, orders(fuel, live, 0n))
    case 1n+(+fuel) 1n+(+live) 1n+(+blank):
      List.append(&2, List<&2, D.Shell>, shells.prepend(D.Live{}, orders(fuel, live, 1n+blank)), shells.prepend(D.Blank{}, orders(fuel, 1n+live, blank)))
    case _ _ _:
      Nil{}

def orders.load(load: D.Load) -> List<&2, List<&2, D.Shell>>:
  match load:
    case D.Load{+live, +blank}:
      orders(Nat.add(live, blank), live, blank)

def filter.clue(order: List<&2, D.Shell>, position: Nat, +shell: D.Shell) -> Bool:
  match order position:
    case Nil{} _:
      False{}
    case first <> _ 0n:
      shell.eq(first, shell)
    case _ <> rest 1n+position:
      filter.clue(rest, position, shell)

def orders.clue(orders: List<&2, List<&2, D.Shell>>, +position: Nat, +shell: D.Shell) -> List<&2, List<&2, D.Shell>>:
  match orders:
    case Nil{}:
      Nil{}
    case +order <> rest:
      I.keep(List<&2, D.Shell>, filter.clue(order, position, shell), order, orders.clue(rest, position, shell))

def orders.pop(orders: List<&2, List<&2, D.Shell>>, +shell: D.Shell) -> List<&2, List<&2, D.Shell>>:
  match orders:
    case Nil{}:
      Nil{}
    case Nil{} <> rest:
      orders.pop(rest, shell)
    case (first <> tail) <> rest:
      I.keep(List<&2, D.Shell>, shell.eq(first, shell), tail, orders.pop(rest, shell))

def orders.invert(orders: List<&2, List<&2, D.Shell>>) -> List<&2, List<&2, D.Shell>>:
  match orders:
    case Nil{}:
      Nil{}
    case Nil{} <> rest:
      orders.invert(rest)
    case (shell <> tail) <> rest:
      (I.invert(shell) <> tail) <> orders.invert(rest)

# Repeated tails retain multiplicity, which is their posterior probability.
def orders.event(event: D.GameEvent, current: List<&2, List<&2, D.Shell>>) -> List<&2, List<&2, D.Shell>>:
  match event:
    case D.Loaded{load}:
      orders.load(load)
    case D.Fired{_, _, shell, _, _, _}:
      orders.pop(current, shell)
    case D.Ejected{_, shell}:
      orders.pop(current, shell)
    case D.Inverted{_}:
      orders.invert(current)
    case _:
      current

def orders.secret(secret: D.Secret, current: List<&2, List<&2, D.Shell>>) -> List<&2, List<&2, D.Shell>>:
  match secret:
    case D.Glimpse{shell}:
      orders.clue(current, 0n, shell)
    case D.Clue{position, shell}:
      orders.clue(current, G.predecessor(position), shell)
    case _:
      current

def orders.log(log: List<&2, D.Heard>, +private: Bool, +current: List<&2, List<&2, D.Shell>>) -> List<&2, List<&2, D.Shell>>:
  match log:
    case Nil{}:
      current
    case D.Witnessed{event} <> rest:
      orders.log(rest, private, orders.event(event, current))
    case D.Learned{secret} <> rest:
      orders.log(rest, private, Bool.pick(List<&2, List<&2, D.Shell>>, private, orders.secret(secret, current), current))

def seat.of(view: D.SeatView) -> S.Seat:
  match view:
    case D.SeatView{D.Unjammed{hp}, slots, cash, _}:
      S.Seat{hp, S.Free{}, cash, slots}
    case D.SeatView{D.Jammed{}, slots, cash, _}:
      S.Seat{0n, S.Jammed{}, cash, slots}

def players.of(views: D.Ring<&2, D.SeatView>) -> S.Players:
  match views:
    case D.Duo{a, b}:
      D.Duo{seat.of(a), seat.of(b)}
    case D.Trio{a, b, c}:
      D.Trio{seat.of(a), seat.of(b), seat.of(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.of(a), seat.of(b), seat.of(c), seat.of(d)}

def players.health_all(players: S.Players, health: Nat) -> S.Players:
  S.players.reset(players, health)

def players.event(event: D.GameEvent, +players: S.Players) -> S.Players:
  match event:
    case D.RoundBegan{_, hp, _}:
      players.health_all(players, hp)
    case D.Fired{_, target, _, _, _, hp}:
      S.players.set_health(players, target, hp)
    case D.Healed{seat, hp}:
      S.players.set_health(players, seat, hp)
    case D.JamApplied{_, target}:
      S.players.set_jam(players, target, S.Jammed{})
    case D.TurnSkipped{seat}:
      S.players.set_jam(players, seat, S.JammedSkipped{})
    case D.JamLifted{seat}:
      S.players.set_jam(players, seat, S.Free{})
    case _:
      players

# Only counters are replayed; visible slots and cash come from the board.
def players.log(log: List<&2, D.Heard>, players: S.Players) -> S.Players:
  match log:
    case Nil{}:
      players
    case D.Witnessed{event} <> rest:
      players.log(rest, players.event(event, players))
    case D.Learned{_} <> rest:
      players.log(rest, players)

def players.restore(entries: List<&2, D.At<&2, D.SeatView>>, players: S.Players) -> S.Players:
  match entries:
    case Nil{}:
      players
    case D.At{+seat, D.SeatView{_, slots, cash, _}} <> rest:
      players.restore(rest, S.players.set_cash(S.players.set_slots(players, seat, slots), seat, cash))

# The last shown batch resets the shell posterior. Older logs still recover
# hidden health behind a jammed counter and the public first-death rule.
def world.event(event: D.GameEvent, +world: S.World) -> S.World:
  match event:
    case D.RoundBegan{index, hp, first}:
      S.world.set_checking_first_death(S.world.set_first_sequence(S.world.set_load_index(S.world.set_first_turn(S.world.set_round_health(S.world.set_round_index(world, index), hp), first), 0n), True{}), True{})
    case D.Loaded{load}:
      S.world.set_first_sequence(S.world.set_load_index(S.world.set_shown(world, load), G.load.next(S.world.first_sequence(world), S.world.load_index(world))), False{})
    case _:
      world

type Deck is Data:
  Deck{mask: U32, weight: F32}

def batch.id(batch: S.Batch) -> Nat:
  match batch:
    case S.Batch{id, _}:
      id

def bit(index: Nat) -> U32:
  U32.shln(1, index)

def deck.full(table: D.Table) -> U32:
  U32.sub(U32.shln(1, List.length(&2, D.Load, D.table.deck(table))), 1)

def deck.batches(batches: List<&2, S.Batch>, +mask: U32) -> List<&2, S.Batch>:
  match batches:
    case Nil{}:
      Nil{}
    case +batch <> rest:
      I.keep(S.Batch, U32.is_ne(U32.and(mask, bit(batch.id(batch))), 0), batch, deck.batches(rest, mask))

def deck.first_is(+decks: List<&2, Deck>, +mask: U32) -> Bool:
  match decks:
    case Nil{}:
      False{}
    case Deck{found, _} <> _:
      U32.is_eq(found, mask)

# `same` tells whether the first of `decks` has the mask.
def deck.insert(decks: List<&2, Deck>, same: Bool, +mask: U32, +weight: F32) -> List<&2, Deck>:
  match decks same:
    case Nil{} _:
      [Deck{mask, weight}]
    case Deck{found, mass} <> rest True{}:
      Deck{found, F32.add(mass, weight)} <> rest
    case deck <> +rest False{}:
      deck <> deck.insert(rest, deck.first_is(rest, mask), mask, weight)

def deck.matched(shown: Bool, +acc: List<&2, Deck>, +mask: U32, +weight: F32) -> List<&2, Deck>:
  match shown:
    case True{}:
      deck.insert(acc, deck.first_is(acc, mask), mask, weight)
    case False{}:
      acc

def load.eq(a: D.Load, b: D.Load) -> Bool:
  match a b:
    case D.Load{al, ab} D.Load{bl, bb}:
      Bool.and(Nat.is_eq(al, bl), Nat.is_eq(ab, bb))

def deck.matches(batches: List<&2, S.Batch>, +rule: D.LoadRule, +shown: D.Load, +mask: U32, +weight: F32, +acc: List<&2, Deck>) -> List<&2, Deck>:
  match batches:
    case Nil{}:
      acc
    case S.Batch{id, sampled} <> rest:
      +actual : D.Load = G.load.actual(rule, sampled)
      deck.matches(rest, rule, shown, mask, weight, deck.matched(load.eq(actual, shown), acc, U32.xor(mask, bit(id)), weight))


def deck.load(decks: List<&2, Deck>, +table: D.Table, +rule: D.LoadRule, +shown: D.Load, acc: List<&2, Deck>) -> List<&2, Deck>:
  match decks:
    case Nil{}:
      acc
    case Deck{+mask, weight} <> rest:
      +mask : U32 = Bool.pick(U32, U32.is_eq(mask, 0), deck.full(table), mask)
      +batches : List<&2, S.Batch> = deck.batches(G.batches(D.table.deck(table), 0n), mask)
      deck.load(rest, table, rule, shown, deck.matches(batches, rule, shown, mask, F32.div(weight, F32.from_nat(List.length(&2, S.Batch, batches))), acc))

def deck.mass(decks: List<&2, Deck>) -> F32:
  match decks:
    case Nil{}:
      0.0
    case Deck{_, weight} <> rest:
      F32.add(weight, deck.mass(rest))

def deck.scaled(decks: List<&2, Deck>, +total: F32) -> List<&2, Deck>:
  match decks:
    case Nil{}:
      Nil{}
    case Deck{mask, weight} <> rest:
      Deck{mask, F32.div(weight, total)} <> deck.scaled(rest, total)

# Renormalizing after each load keeps the ratios between decks, which is all
# the posterior needs. Without it the product of draw probabilities over a
# long match underflows F32 to zero.
def deck.normalize(+decks: List<&2, Deck>) -> List<&2, Deck>:
  deck.scaled(decks, deck.mass(decks))

def deck.log(log: List<&2, D.Heard>, +world: S.World, decks: List<&2, Deck>) -> List<&2, Deck>:
  match log:
    case Nil{}:
      decks
    case D.Witnessed{D.Loaded{+load}} <> rest:
      +next : S.World = world.event(D.Loaded{load}, world)
      deck.log(rest, next, deck.normalize(deck.load(decks, S.world.table(world), G.world.load_rule(next), load, Nil{})))
    case D.Witnessed{event} <> rest:
      deck.log(rest, world.event(event, world), decks)
    case D.Learned{_} <> rest:
      deck.log(rest, world, decks)

def world.log(log: List<&2, D.Heard>, world: S.World) -> S.World:
  match log:
    case Nil{}:
      world
    case D.Witnessed{event} <> rest:
      world.log(rest, world.event(event, world))
    case D.Learned{_} <> rest:
      world.log(rest, world)

def state.of(config: D.Config, board: D.Board, +log: List<&2, D.Heard>, +me: D.Seat) -> T.State:
  match board:
    case D.Board{D.RoundView{index, _, hp}, +views, D.GunView{shown, _, sawed}, direction, D.Playing{+seat, D.Idle{}}}:
      +base : T.State = M.initial(config)
      +world : S.World = world.log(log, T.state.world(base))
      +world : S.World = S.world.set_turn(S.world.set_sawed(S.world.set_direction(S.world.set_shown(S.world.set_round_health(S.world.set_round_index(world, index), hp), shown), direction), sawed), Some{seat})
      players : S.Players = players.restore(D.ring.entries(D.SeatView, views), players.log(log, players.of(views)))
      T.State{world, players, T.Idle{seat}, T.Empty{}, T.state.grabs(base)}
    case _:
      M.initial(config)

def worlds.orders(orders: List<&2, List<&2, D.Shell>>, +state: T.State, +weight: F32) -> List<&2, A.World>:
  match orders:
    case Nil{}:
      Nil{}
    case order <> rest:
      A.World{T.state.set_world(state, S.world.set_gun(T.state.world(state), order)), weight} <> worlds.orders(rest, state, weight)

def worlds.decks(decks: List<&2, Deck>, +orders: List<&2, List<&2, D.Shell>>, +state: T.State) -> List<&2, A.World>:
  match decks:
    case Nil{}:
      Nil{}
    case Deck{mask, weight} <> rest:
      +world : S.World = T.state.world(state)
      +world : S.World = S.world.set_deck(world, deck.batches(G.batches(D.table.deck(S.world.table(world)), 0n), mask))
      List.append(&2, A.World, worlds.orders(orders, T.state.set_world(state, world), weight), worlds.decks(rest, orders, state))

def mass(worlds: List<&2, A.World>) -> F32:
  match worlds:
    case Nil{}:
      0.0
    case A.World{_, weight} <> rest:
      F32.add(weight, mass(rest))

def normalize.by(worlds: List<&2, A.World>, +total: F32) -> List<&2, A.World>:
  match worlds:
    case Nil{}:
      Nil{}
    case A.World{state, weight} <> rest:
      A.World{state, F32.div(weight, total)} <> normalize.by(rest, total)

def normalize(+worlds: List<&2, A.World>) -> List<&2, A.World>:
  normalize.by(worlds, mass(worlds))

type Built is Data:
  Built{belief: A.Belief}
  Rejected{reason: String}

def build.ready(public: List<&2, A.World>, private: List<&2, A.World>, me: D.Seat, round: Nat) -> Built:
  match public private:
    case Nil{} _:
      Rejected{"public log has no consistent shell/deck belief"}
    case _ Nil{}:
      Rejected{"private log has no consistent shell/deck belief"}
    case +public +private:
      Built{A.Belief{normalize(public), normalize(private), me, round}}

def build.bounded(ok: Bool, +position: A.Position) -> Built:
  match ok position:
    case False{} _:
      Rejected{"requires an Idle board and a shown load of at most ten shells"}
    case True{} A.Position{+config, +board, +log, +me}:
      +state : T.State = state.of(config, board, log, me)
      +decks : List<&2, Deck> = deck.log(log, T.state.world(M.initial(config)), [Deck{deck.full(G.config.table(config)), 1.0}])
      build.ready(worlds.decks(decks, orders.log(log, False{}, Nil{}), state), worlds.decks(decks, orders.log(log, True{}, Nil{}), state), me, S.world.round_index(T.state.world(state)))

def board.ready(board: D.Board) -> Bool:
  match board:
    case D.Board{_, _, D.GunView{D.Load{live, blank}, _, _}, _, D.Playing{_, D.Idle{}}}:
      Nat.is_le(Nat.add(live, blank), 10n)
    case _:
      False{}

def build(+position: A.Position) -> Built:
  match position:
    case A.Position{_, board, _, _}:
      build.bounded(board.ready(board), position)
