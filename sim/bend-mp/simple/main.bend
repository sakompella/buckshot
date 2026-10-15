import Base
import ../domain.bend as D
import ./state.bend as T
import ../sm/state.bend as S
import ../sm/rules.bend as G
import ./point.bend as P
import ../sm/items.bend as I

def request(state: T.State) -> T.Request:
  P.request(state)

def stage(state: T.State) -> D.Stage:
  P.stage(state)

def point(state: T.State) -> T.Point:
  P.point(state)

def pickup(state: T.State, seat: D.Seat) -> T.State:
  T.state.emit(state, D.PickedUp{seat})

def replace_hidden(+state: T.State, gun: List<&2, D.Shell>, decks: S.Decks) -> T.State:
  T.state.set_world(state, S.world.set_decks(S.world.set_gun(T.state.world(state), gun), decks))

def give_turn(+state: T.State, +seat: D.Seat) -> T.State:
  T.state.emit(T.state.set_phase(state, T.Idle{seat}), D.TurnGiven{seat})

def grant.step(rank: Nat, +state: T.State, +seat: D.Seat, result: S.JamResult) -> T.State:
  match rank result:
    case rank S.Act{players}:
      give_turn(T.state.set_players(state, players), seat)
    case rank S.Lift{players}:
      give_turn(T.state.emit(T.state.set_players(state, players), D.JamLifted{seat}), seat)
    case 0n S.Skip{players}:
      T.state.set_phase(T.state.set_players(state, players), T.Blocked{None{}})
    case 1n+rest S.Skip{+players}:
      +world : S.World = T.state.world(state)
      next : D.Seat = G.next_turn(S.players.health(players), S.world.direction(world), seat)
      +next : D.Seat = next
      state : T.State = T.state.set_world(T.state.set_players(state, players), S.world.set_turn(world, Some{next}))
      grant.step(rest, T.state.emit(state, D.TurnSkipped{seat}), next, G.jam(players, next))

def grant.bound(rank: Nat, +state: T.State, +seat: D.Seat) -> T.State:
  +state : T.State = T.state.set_world(state, S.world.set_turn(T.state.world(state), Some{seat}))
  grant.step(rank, state, seat, G.jam(T.state.players(state), seat))

def grant(+state: T.State, seat: D.Seat) -> T.State:
  grant.bound(G.jam_rank(T.state.players(state)), state, seat)

def shuffle(+state: T.State, +load: D.Load, shells: List<&2, D.Shell>, i: Nat) -> T.State:
  match i:
    case 0n:
      +world : S.World = S.world.set_shown(S.world.set_gun(T.state.world(state), shells), load)
      grant(T.state.emit(T.state.set_world(state, world), D.Loaded{load}), S.world.first_turn(world))
    case 1n+rest:
      T.state.set_phase(state, T.NeedSwap{load, shells, 1n+rest})

def batch.found(+state: T.State, +index: Nat, selected: Maybe<&2, S.Batch>) -> T.State:
  match selected:
    case None{}:
      T.state.set_phase(state, T.Blocked{None{}})
    case Some{S.Batch{_, sampled}}:
      +world : S.World = T.state.world(state)
      +load : D.Load = G.load.actual(G.world.load_rule(world), sampled)
      +shells : List<&2, D.Shell> = G.load.shells(load)
      world : S.World = S.world.set_deck(world, G.remove(S.Batch, S.world.deck(world), index))
      shuffle(T.state.set_world(state, world), load, shells, G.predecessor(List.length(&2, D.Shell, shells)))

def batch(+state: T.State, +index: Nat) -> T.State:
  batch.found(state, index, G.nth(S.Batch, S.world.deck(T.state.world(state)), index))

def load.ready(state: T.State, deck: List<&2, S.Batch>) -> T.State:
  match deck:
    case Nil{}:
      T.state.set_phase(state, T.Blocked{None{}})
    case only <> Nil{}:
      batch(state, 0n)
    case first <> next <> rest:
      T.state.set_phase(state, T.NeedBatch{})

def load.refill(+state: T.State, deck: List<&2, S.Batch>) -> T.State:
  match deck:
    case Nil{}:
      +world : S.World = S.world.set_decks(T.state.world(state), G.decks.full())
      load.ready(T.state.set_world(state, world), S.world.deck(world))
    case deck:
      load.ready(state, deck)

def load.begin(+state: T.State) -> T.State:
  +world : S.World = T.state.world(state)
  world : S.World = S.world.set_load_index(world, G.load.next(S.world.first_sequence(world), S.world.load_index(world)))
  +world : S.World = S.world.set_first_sequence(world, False{})
  load.refill(T.state.set_world(state, world), S.world.deck(world))

def initial(+config: D.Config) -> T.State:
  +table : D.Table = G.config.table(config)
  T.State{S.World{config, True{}, 0n, 0n, False{}, 0n, D.Seat0{}, None{}, D.Clockwise{}, None{}, False{}, 0n, False{}, Nil{}, D.Load{0n, 0n}, G.decks.full()}, D.ring.fill(S.Seat, table, S.Seat{100n, S.Free{}, 0, D.slots.empty()}), T.NeedFirst{}, T.Empty{}, S.Grabs{False{}, D.ring.fill(Bool, table, False{}), D.ring.fill(Maybe<&2, D.Item>, table, None{}), D.ring.fill(Nat, table, 0n), D.ring.fill(Bool, table, False{})}}

# Item distribution (D05, D06, D22, D37 grabbing rows, D55 M1, D56). The
# simple machine hands items out by itself, one take or place per pass. Each
# pass reads the pure rule I.grab.needs (who may take or place, and where):
# the last seat to act places a granted item in its first free slot;
# otherwise the next seat after it, in socket order, that may only take,
# takes. So items go one per seat in turn.

type Distribution is Data:
  Taking{seat: D.Seat}
  Placing{seat: D.Seat, slot: D.Slot}
  Drawing{}
  Loading{}
  NoTaker{}

def grab.check.done(+state: T.State, done: Bool) -> T.State:
  match done:
    case True{}:
      T.state.emit(T.state.set_grabs(state, S.grabs.set_distributing(T.state.grabs(state), False{})), D.DistributionDone{})
    case False{}:
      state

def grab.check(+state: T.State) -> T.State:
  grab.check.done(state, Bool.and(S.grabs.distributing(T.state.grabs(state)), I.finished(T.state.records(state))))

def grab.end_all(seats: List<&2, D.Seat>, +state: T.State) -> T.State:
  match seats:
    case Nil{}:
      state
    case +seat <> rest:
      grab.end_all(rest, T.state.emit(T.state.set_grabs(state, I.grabs.close(T.state.grabs(state), seat)), D.GrabbingEnded{seat}))

def grab.put.held(+state: T.State, +seat: D.Seat, +slot: D.Slot, held: Maybe<&2, D.Item>) -> T.State:
  match held:
    case None{}:
      T.state.set_phase(state, T.Blocked{None{}})
    case Some{+item}:
      +players : S.Players = T.state.players(state)
      players : S.Players = S.players.set_slots(players, seat, I.slots.put(I.seat.slots(players, seat), slot, Some{item}))
      +state : T.State = T.state.set_grabs(T.state.set_players(state, players), I.grabs.placed(T.state.grabs(state), seat))
      T.state.emit(state, D.Placed{seat, slot, item})

def grab.put(+state: T.State, +seat: D.Seat, +slot: D.Slot) -> T.State:
  grab.put.held(state, seat, slot, I.seat.holding(T.state.grabs(state), seat))

# A last placement ends the seat, checks completion, ends the noneligible
# empty-handed grabbers, and (M1) checks completion again before placing.
def grab.place.last(+state: T.State, +seat: D.Seat, +slot: D.Slot, last: Bool) -> T.State:
  match last:
    case True{}:
      +state : T.State = grab.check(T.state.emit(T.state.set_grabs(state, I.grabs.close(T.state.grabs(state), seat)), D.GrabbingEnded{seat}))
      +state : T.State = grab.end_all(I.stalled.seats(T.state.records(state), seat), state)
      grab.put(grab.check(state), seat, slot)
    case False{}:
      grab.put(state, seat, slot)

def grab.place(+state: T.State, +seat: D.Seat, +slot: D.Slot) -> T.State:
  grab.place.last(state, seat, slot, I.placing.last(T.state.records(state), seat))

def grab.give(+state: T.State, +seat: D.Seat, +item: D.Item) -> T.State:
  T.state.emit(T.state.set_grabs(state, I.grabs.give(T.state.grabs(state), seat, item)), D.Granted{seat, item})

def grab.chosen(+state: T.State, +seat: D.Seat, found: Maybe<&2, D.Item>) -> T.State:
  match found:
    case Some{item}:
      grab.give(state, seat, item)
    case None{}:
      T.state.tell(state, seat, D.EmptyBriefcase{})

def grab.pool(+state: T.State, +seat: D.Seat, pool: List<&2, D.Item>) -> T.State:
  match pool:
    case Nil{}:
      grab.chosen(state, seat, None{})
    case item <> Nil{}:
      grab.give(state, seat, item)
    case first <> second <> rest:
      T.state.set_phase(state, T.NeedItem{seat, first, second, rest})

def grab.takes(options: List<&2, S.GrabOption>) -> Bool:
  match options:
    case S.TakeItem{} <> Nil{}:
      True{}
    case _:
      False{}

def grab.taker(seats: List<&2, D.Seat>, +needs: D.Ring<&2, List<&2, S.GrabOption>>) -> Distribution:
  match seats:
    case Nil{}:
      NoTaker{}
    case +seat <> rest:
      Bool.pick(Distribution, grab.takes(G.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs, seat), Nil{})), Taking{seat}, grab.taker(rest, needs))

# The seats after `after` in socket order, cycling, `after` last.
def seats.after(seats: List<&2, D.Seat>, +after: D.Seat, +before: List<&2, D.Seat>) -> List<&2, D.Seat>:
  match seats:
    case Nil{}:
      before
    case +seat <> +rest:
      +upto : List<&2, D.Seat> = List.append(&2, D.Seat, before, [seat])
      Bool.pick(List<&2, D.Seat>, D.seat.eq(seat, after), List.append(&2, D.Seat, rest, upto), seats.after(rest, after, upto))

def grab.act.own(own: List<&2, S.GrabOption>, +seats: List<&2, D.Seat>, +needs: D.Ring<&2, List<&2, S.GrabOption>>, +after: D.Seat) -> Distribution:
  match own:
    case S.PutAt{slot} <> _:
      Placing{after, slot}
    case _:
      grab.taker(seats, needs)

def grab.act(+records: S.State, +after: D.Seat) -> Distribution:
  +needs : D.Ring<&2, List<&2, S.GrabOption>> = I.grab.needs(records)
  +seats : List<&2, D.Seat> = seats.after(D.table.seats(S.world.table(S.state.world(records))), after, Nil{})
  grab.act.own(G.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs, after), Nil{}), seats, needs, after)

def grab.continue.ready(+records: S.State, +after: D.Seat, distributing: Bool, holders: Bool) -> Distribution:
  match distributing holders:
    case False{} False{}:
      Loading{}
    case _ _:
      grab.act(records, after)

# What follows a grab move, read from the records as sm's grab.continue
# reads them: loading once the distribution is done and no item is held,
# else the next grab move.
def grab.continue(+records: S.State, +after: D.Seat) -> Distribution:
  +grabs : S.Grabs = S.state.grabs(records)
  grab.continue.ready(records, after, S.grabs.distributing(grabs), I.holders(D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(grabs))))

# A take from a pool of two or more waits for the item draw.
def grab.next(+records: S.State, pool: List<&2, D.Item>, +after: D.Seat) -> Distribution:
  match pool:
    case first <> second <> rest:
      Drawing{}
    case _:
      grab.continue(records, after)

# Each seat takes at most 9 times (a take fills a slot or closes its intake)
# and places at most 8 times, so the fuel below is never spent; spent fuel
# stalls the machine as a seat with no move would.
def grab.loop(fuel: Nat, +state: T.State, next: Distribution) -> T.State:
  match fuel next:
    case _ Drawing{}:
      state
    case _ Loading{}:
      load.begin(state)
    case _ NoTaker{}:
      T.state.set_phase(state, T.Stalled{})
    case 0n Taking{_}:
      T.state.set_phase(state, T.Stalled{})
    case 0n Placing{_, _}:
      T.state.set_phase(state, T.Stalled{})
    case 1n+fuel Taking{+seat}:
      +opened : T.State = T.state.set_grabs(state, I.grabs.stop_intake(T.state.grabs(state), seat))
      +pool : List<&2, D.Item> = I.pool(T.state.records(opened), seat)
      +taken : T.State = grab.pool(opened, seat, pool)
      grab.loop(fuel, taken, grab.next(T.state.records(taken), pool, seat))
    case 1n+fuel Placing{+seat, +slot}:
      +placed : T.State = grab.place(state, seat, slot)
      grab.loop(fuel, placed, grab.continue(T.state.records(placed), seat))

def grab.fuel(table: D.Table) -> Nat:
  match table:
    case D.TwoSeats{}:
      34n
    case D.ThreeSeats{}:
      51n
    case D.FourSeats{}:
      68n

def grab.distribute(+state: T.State, +after: D.Seat) -> T.State:
  grab.loop(grab.fuel(S.world.table(T.state.world(state))), state, grab.continue(T.state.records(state), after))

def distribute.begin(+state: T.State, seats: List<&2, D.Seat>) -> T.State:
  match seats:
    case Nil{}:
      load.begin(state)
    case +seat <> +rest:
      +grabs : S.Grabs = S.grabs.set_distributing(I.grabs.open_all(seat <> rest, T.state.grabs(state)), True{})
      +state : T.State = T.state.emit(T.state.set_grabs(state, grabs), D.GrabbingBegan{seat <> rest})
      grab.distribute(state, S.world.first_turn(T.state.world(state)))

def round.reset(+state: T.State) -> T.State:
  +world : S.World = T.state.world(state)
  players : S.Players = S.players.reset(T.state.players(state), S.world.round_health(world))
  +world : S.World = S.world.set_direction(S.world.set_checking_first_death(world, True{}), D.Clockwise{})
  +state : T.State = T.state.emit(T.state.set_players(T.state.set_world(state, world), players), D.RoundBegan{S.world.round_index(world), S.world.round_health(world), S.world.first_turn(world)})
  distribute.begin(state, I.begin.seats(T.state.records(state), True{}, S.world.item_amount(world)))

def amount.chosen(+state: T.State, value: Nat) -> T.State:
  round.reset(T.state.set_world(state, S.world.set_item_amount(T.state.world(state), value)))

def amount.rule(state: T.State, rule: D.AmountRule) -> T.State:
  match rule:
    case D.RandomAmount{}:
      T.state.set_phase(state, T.NeedAmount{})
    case D.FixedAmount{amount}:
      amount.chosen(state, amount)

def amount.begin(+state: T.State) -> T.State:
  amount.rule(state, G.load.amount(G.world.load_rule(T.state.world(state))))

def health.chosen(+state: T.State, value: Nat) -> T.State:
  amount.begin(T.state.set_world(state, S.world.set_round_health(T.state.world(state), value)))

def health.rule(state: T.State, rule: D.HealthRule) -> T.State:
  match rule:
    case D.RandomHealth{}:
      T.state.set_phase(state, T.NeedHealth{})
    case D.FixedHealth{health}:
      health.chosen(state, D.pos.nat(health))

def health.begin(+state: T.State) -> T.State:
  health.rule(state, G.round.health(G.world.rules(T.state.world(state))))

def first.chosen(+state: T.State, seat: D.Seat) -> T.State:
  +world : S.World = T.state.world(state)
  world : S.World = S.world.set_round_index(world, G.round.next(S.world.before_round(world), S.world.round_index(world)))
  world : S.World = S.world.set_before_round(world, False{})
  world : S.World = S.world.set_first_turn(world, seat)
  health.begin(T.state.set_world(state, S.world.set_first_sequence(world, True{})))

def first.override(state: T.State, first_death: Maybe<&2, D.Seat>) -> T.State:
  match first_death:
    case None{}:
      T.state.set_phase(state, T.NeedFirst{})
    case Some{seat}:
      first.chosen(state, seat)

def first.begin(+state: T.State) -> T.State:
  first.override(state, S.world.first_death(T.state.world(state)))

def start(+config: D.Config) -> D.Stepped<&2, T.State>:
  T.state.stepped(first.begin(initial(config)))

def win.final(state: T.State, final: Bool) -> T.State:
  match final:
    case True{}:
      T.state.emit(T.state.set_phase(state, T.Ended{}), D.MatchConcluded{})
    case False{}:
      first.begin(state)

def win(+state: T.State, +seat: D.Seat) -> T.State:
  +world : S.World = T.state.world(state)
  +players : S.Players = T.state.players(state)
  +prize : U32 = D.prize(S.world.round_index(world))
  cash : U32 = G.value.or(U32, D.ring.get(U32, S.players.cash(players), seat), 0)
  players : S.Players = S.players.set_cash(players, seat, U32.add(cash, prize))
  win.final(T.state.emit(T.state.set_players(state, players), D.RoundWon{seat, prize}), Nat.is_eq(1n+S.world.round_index(world), D.plan.length(S.world.plan(world))))

def turn.recipient(passing: Bool, current: D.Seat, next: D.Seat) -> D.Seat:
  match passing:
    case False{}:
      current
    case True{}:
      next

def reload.begin(+state: T.State) -> T.State:
  distribute.begin(state, I.begin.seats(T.state.records(state), False{}, S.world.item_amount(T.state.world(state))))

def turn.continue(+state: T.State, +recipient: D.Seat, gun: List<&2, D.Shell>) -> T.State:
  match gun:
    case Nil{}:
      reload.begin(T.state.set_world(state, S.world.set_first_turn(T.state.world(state), recipient)))
    case shell <> rest:
      grant(T.state.set_world(state, S.world.set_first_turn(T.state.world(state), recipient)), recipient)

def turn.winner(+state: T.State, +shooter: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>) -> T.State:
  match winner:
    case Some{seat}:
      win(state, seat)
    case None{}:
      +world : S.World = T.state.world(state)
      recipient : D.Seat = turn.recipient(passing, shooter, G.next_turn(S.players.health(T.state.players(state)), S.world.direction(world), shooter))
      turn.continue(state, recipient, S.world.gun(world))

def turn.amount(+state: T.State, shooter: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>, rule: D.AmountRule) -> T.State:
  match rule:
    case D.RandomAmount{}:
      turn.winner(state, shooter, passing, winner)
    case D.FixedAmount{amount}:
      +state : T.State = T.state.set_world(state, S.world.set_item_amount(T.state.world(state), amount))
      turn.winner(state, shooter, passing, winner)

def turn.live(+state: T.State, shooter: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>, rule: D.AmountRule, live: Bool) -> T.State:
  match live:
    case True{}:
      T.state.set_phase(state, T.NeedTurnAmount{shooter, passing, winner})
    case False{}:
      turn.amount(state, shooter, passing, winner, rule)

# UserEndTurn_Packet: the packet's winner is the shot's winner check, or
# None after beer ejects the last shell.
def turn.packet(+state: T.State, shooter: D.Seat, passing: Bool, +winner: Maybe<&2, D.Seat>) -> T.State:
  +rule : D.AmountRule = G.load.amount(G.world.load_rule(T.state.world(state)))
  turn.live(state, shooter, passing, winner, rule, I.amount.live(rule, S.grabs.distributing(T.state.grabs(state)), I.reload.wanted(T.state.records(state), winner)))

def turn.end(+state: T.State, shooter: D.Seat, passing: Bool) -> T.State:
  turn.packet(state, shooter, passing, G.winner(S.players.health(T.state.players(state))))

def death.remember(+state: T.State, seat: D.Seat, checking: Bool) -> T.State:
  match checking:
    case False{}:
      state
    case True{}:
      world : S.World = S.world.set_checking_first_death(S.world.set_first_death(T.state.world(state), Some{seat}), False{})
      T.state.set_world(state, world)

def death(+state: T.State, +target: D.Seat, shell: D.Shell, health: Nat) -> T.State:
  match shell health:
    case D.Live{} 0n:
      T.state.emit(death.remember(state, target, S.world.checking_first_death(T.state.world(state))), D.Died{target})
    case _ _:
      state

def shoot.loaded(+state: T.State, +shooter: D.Seat, +target: D.Seat, +shell: D.Shell, rest: List<&2, D.Shell>) -> T.State:
  +world : S.World = T.state.world(state)
  +players : S.Players = T.state.players(state)
  +damage : D.Damage = G.captured(S.world.sawed(world))
  +before : Nat = G.value.or(Nat, D.ring.get(Nat, S.players.health(players), target), 100n)
  +health : Nat = G.shot.health(shell, before, damage)
  +players : S.Players = S.players.set_health(players, target, health)
  world : S.World = S.world.set_sawed(S.world.set_gun(world, rest), False{})
  state : T.State = T.state.emit(T.state.set_players(T.state.set_world(state, world), players), D.Fired{shooter, target, shell, damage, G.subtract(before, health), health})
  turn.end(death(state, target, shell, health), shooter, G.shot.passes(shell, D.seat.eq(shooter, target)))

def shoot.gun(state: T.State, shooter: D.Seat, target: D.Seat, gun: List<&2, D.Shell>) -> T.State:
  match gun:
    case Nil{}:
      T.state.set_phase(state, T.Blocked{Some{shooter}})
    case shell <> rest:
      shoot.loaded(state, shooter, target, shell, rest)

def shoot(+state: T.State, shooter: D.Seat, target: D.Seat) -> T.State:
  shoot.gun(state, shooter, target, S.world.gun(T.state.world(state)))

# Item use (D17, D18, D28, D29, D37). A use or steal consumes the slot,
# then applies the effect. A jammer's target and an adrenaline's steal are
# part of the same move, so those effects leave the rest to pickup.selected.

def item.resume(+state: T.State, +seat: D.Seat) -> T.State:
  T.state.set_phase(state, T.Idle{seat})

def item.end(+state: T.State, +seat: D.Seat, ending: Bool) -> T.State:
  match ending:
    case True{}:
      turn.packet(state, seat, True{}, None{})
    case False{}:
      item.resume(state, seat)

def item.chamber(+state: T.State, +seat: D.Seat, item: D.Item, ending: Bool, +shell: D.Shell, rest: List<&2, D.Shell>) -> T.State:
  match item:
    case D.Glass{}:
      item.end(T.state.tell(state, seat, D.Glimpse{shell}), seat, ending)
    case D.Beer{}:
      +state : T.State = T.state.set_world(state, S.world.set_gun(T.state.world(state), rest))
      item.end(T.state.emit(state, D.Ejected{seat, shell}), seat, ending)
    case D.Inverter{}:
      +state : T.State = T.state.set_world(state, S.world.set_gun(T.state.world(state), I.invert(shell) <> rest))
      item.end(T.state.emit(state, D.Inverted{seat}), seat, ending)
    case _:
      T.state.set_phase(state, T.Blocked{None{}})

def item.shell(+state: T.State, +seat: D.Seat, item: D.Item, ending: Bool, gun: List<&2, D.Shell>) -> T.State:
  match gun:
    case Nil{}:
      T.state.set_phase(state, T.Blocked{None{}})
    case +shell <> rest:
      item.chamber(state, seat, item, ending, shell, rest)

def item.heal(+state: T.State, +seat: D.Seat, heal: Bool) -> T.State:
  match heal:
    case True{}:
      +players : S.Players = T.state.players(state)
      +hp : Nat = 1n+I.seat.health(players, seat)
      +state : T.State = T.state.set_players(state, S.players.set_health(players, seat, hp))
      item.resume(T.state.emit(state, D.Healed{seat, hp}), seat)
    case False{}:
      item.resume(state, seat)

def item.tell(+state: T.State, +seat: D.Seat, phone: Maybe<&2, D.Secret>) -> T.State:
  match phone:
    case None{}:
      T.state.set_phase(state, T.Blocked{None{}})
    case Some{secret}:
      item.resume(T.state.tell(state, seat, secret), seat)

def item.effect(+state: T.State, +seat: D.Seat, item: D.Item, ending: Bool, phone: Maybe<&2, D.Secret>) -> T.State:
  match item:
    case D.Saw{}:
      item.resume(T.state.set_world(state, S.world.set_sawed(T.state.world(state), True{})), seat)
    case D.Jammer{}:
      state
    case D.Cigarettes{}:
      item.heal(state, seat, Nat.is_lt(I.seat.health(T.state.players(state), seat), S.world.round_health(T.state.world(state))))
    case D.Phone{}:
      item.tell(state, seat, phone)
    case D.Adrenaline{}:
      state
    case D.Remote{}:
      +direction : D.Direction = I.flip(S.world.direction(T.state.world(state)))
      item.resume(T.state.emit(T.state.set_world(state, S.world.set_direction(T.state.world(state), direction)), D.DirectionFlipped{direction}), seat)
    case D.Glass{}:
      item.shell(state, seat, D.Glass{}, ending, S.world.gun(T.state.world(state)))
    case D.Beer{}:
      item.shell(state, seat, D.Beer{}, ending, S.world.gun(T.state.world(state)))
    case D.Inverter{}:
      item.shell(state, seat, D.Inverter{}, ending, S.world.gun(T.state.world(state)))

def item.consume(+state: T.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item, ending: Bool, phone: Maybe<&2, D.Secret>) -> T.State:
  +players : S.Players = T.state.players(state)
  players : S.Players = S.players.set_slots(players, owner, I.slots.put(I.seat.slots(players, owner), slot, None{}))
  item.effect(T.state.emit(T.state.set_players(state, players), D.Used{seat, owner, slot, item}), seat, item, ending, phone)

def item.clue.found(+state: T.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +position: Nat, found: Maybe<&2, D.Shell>) -> T.State:
  match found:
    case None{}:
      T.state.set_phase(state, T.Blocked{Some{seat}})
    case Some{shell}:
      item.consume(state, seat, owner, slot, D.Phone{}, False{}, Some{D.Clue{position, shell}})

# The phone announces drawn index plus one, capped at the seventh shell (D28).
def item.clue(+state: T.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, index: Nat) -> T.State:
  +position : Nat = D.clamp(1n+index, D.phone.cap())
  item.clue.found(state, seat, owner, slot, position, G.nth(D.Shell, S.world.gun(T.state.world(state)), G.predecessor(position)))

def item.phone(+state: T.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, length: Nat) -> T.State:
  match length:
    case 0n:
      item.consume(state, seat, owner, slot, D.Phone{}, False{}, Some{D.NoClue{}})
    case 1n:
      item.consume(state, seat, owner, slot, D.Phone{}, False{}, Some{D.NoClue{}})
    case 2n:
      item.consume(state, seat, owner, slot, D.Phone{}, False{}, Some{D.NoClue{}})
    case 3n:
      item.clue(state, seat, owner, slot, 2n)
    case _:
      T.state.set_phase(state, T.NeedPhone{seat, owner, slot})

def item.route(+state: T.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, item: D.Item, ending: Bool, length: Nat) -> T.State:
  match item:
    case D.Phone{}:
      item.phone(state, seat, owner, slot, length)
    case item:
      item.consume(state, seat, owner, slot, item, ending, None{})

def item.use(+state: T.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item) -> T.State:
  +length : Nat = List.length(&2, D.Shell, S.world.gun(T.state.world(state)))
  item.route(state, seat, owner, slot, item, I.ends_turn(item, length), length)

def jam.selected(+state: T.State, +seat: D.Seat, +target: D.Seat) -> T.State:
  +players : S.Players = T.state.players(state)
  players : S.Players = S.players.set_jam(players, target, S.Jammed{})
  item.resume(T.state.emit(T.state.set_players(state, players), D.JamApplied{seat, target}), seat)

def pickup.selected(state: T.State, +seat: D.Seat, selected: Maybe<&2, T.IdleOption>) -> T.State:
  match selected:
    case Some{T.ShootAt{target}}:
      shoot(pickup(state, seat), seat, target)
    case Some{T.UseSlot{slot, item}}:
      item.use(state, seat, seat, slot, item)
    case Some{T.JamWith{slot, target}}:
      jam.selected(item.use(state, seat, seat, slot, D.Jammer{}), seat, target)
    case Some{T.StealWith{adrenaline, owner, slot, item}}:
      item.use(item.use(state, seat, seat, adrenaline, D.Adrenaline{}), seat, owner, slot, item)
    case Some{T.StealJamWith{adrenaline, owner, slot, target}}:
      jam.selected(item.use(item.use(state, seat, seat, adrenaline, D.Adrenaline{}), seat, owner, slot, D.Jammer{}), seat, target)
    case None{}:
      T.state.set_phase(state, T.Blocked{Some{seat}})

def answer.choice(+state: T.State, index: Nat) -> T.State:
  match state:
    case T.State{world, players, T.Idle{+seat}, notes, grabs}:
      pickup.selected(state, seat, P.option.nth(P.options(state, seat), index))
    case _:
      T.state.set_phase(state, T.Blocked{None{}})

def answer.draw(+state: T.State, value: Nat) -> T.State:
  match state:
    case T.State{world, players, T.NeedFirst{}, notes, grabs}:
      first.chosen(state, G.value.or(D.Seat, G.nth(D.Seat, D.table.seats(S.world.table(world)), value), D.Seat0{}))
    case T.State{world, players, T.NeedHealth{}, notes, grabs}:
      health.chosen(state, value)
    case T.State{world, players, T.NeedAmount{}, notes, grabs}:
      amount.chosen(state, value)
    case T.State{world, players, T.NeedBatch{}, notes, grabs}:
      batch(state, value)
    case T.State{world, players, T.NeedSwap{load, shells, +i}, notes, grabs}:
      shuffle(state, load, G.swap(shells, i, value), G.predecessor(i))
    case T.State{world, players, T.NeedTurnAmount{from, passing, winner}, notes, grabs}:
      turn.winner(T.state.set_world(state, S.world.set_item_amount(world, value)), from, passing, winner)
    case T.State{world, players, T.NeedItem{+seat, first, second, rest}, notes, grabs}:
      grab.distribute(grab.chosen(state, seat, G.nth(D.Item, first <> second <> rest, value)), seat)
    case T.State{world, players, T.NeedPhone{seat, owner, slot}, notes, grabs}:
      item.clue(state, seat, owner, slot, value)
    case _:
      T.state.set_phase(state, T.Blocked{None{}})

# A choice index past the end of the menu clamps to its last move.
def answer.request(+state: T.State, n: Nat, request: T.Request) -> D.Stepped<&2, T.State>:
  match request:
    case T.Finished{}:
      D.Stepped{state, Nil{}}
    case T.Stuck{}:
      D.Stepped{state, Nil{}}
    case T.Draw{_, range}:
      T.state.stepped(answer.draw(T.state.set_log(state, T.Empty{}), D.draw.value(range, n)))
    case T.Choose{_, D.NonEmpty{_, rest}}:
      T.state.stepped(answer.choice(T.state.set_log(state, T.Empty{}), D.clamp(n, List.length(&2, T.Move, rest))))

def answer(+state: T.State, n: Nat) -> D.Stepped<&2, T.State>:
  answer.request(state, n, request(state))

def stepped.state(stepped: D.Stepped<&2, T.State>) -> T.State:
  match stepped:
    case D.Stepped{state, _}:
      state

def run.merge(stepped: D.Stepped<&2, T.State>, ran: D.Ran<&2, T.State>) -> D.Ran<&2, T.State>:
  match stepped ran:
    case D.Stepped{_, first} D.Ran{state, rest, tape}:
      D.Ran{state, List.append(&2, D.Note, first, rest), tape}

def run.request(fuel: Nat, request: T.Request, +state: T.State, tape: List<&2, Nat>) -> D.Ran<&2, T.State>:
  match fuel request tape:
    case _ T.Finished{} tape:
      D.Ran{state, Nil{}, tape}
    case _ T.Stuck{} tape:
      D.Ran{state, Nil{}, tape}
    case 0n _ tape:
      D.Ran{state, Nil{}, tape}
    case _ _ Nil{}:
      D.Ran{state, Nil{}, Nil{}}
    case 1n+fuel _ n <> rest:
      +next : D.Stepped<&2, T.State> = answer(state, n)
      +state : T.State = stepped.state(next)
      run.merge(next, run.request(fuel, P.request(state), state, rest))

def run(fuel: Nat, +state: T.State, tape: List<&2, Nat>) -> D.Ran<&2, T.State>:
  run.request(fuel, request(state), state, tape)
