import Base
import ../domain.bend as D
import ./state.bend as S
import ./rules.bend as G
import ./point.bend as P
import ./items.bend as I

def request(state: S.State) -> D.Request:
  P.request(state)

def stage(state: S.State) -> D.Stage:
  P.stage(state)

def point(state: S.State) -> D.Point:
  P.point(state)

def pickup(state: S.State, +seat: D.Seat) -> S.State:
  match state:
    case S.State{world, +players, _, notes, grabs}:
      S.State{world, players, S.Aim{seat}, List.append(&2, D.Note, notes, [D.Shown{D.PickedUp{seat}}]), grabs}

def replace_hidden(+state: S.State, gun: List<&2, D.Shell>, decks: S.Decks) -> S.State:
  S.state.set_world(state, S.world.set_decks(S.world.set_gun(S.state.world(state), gun), decks))

def give_turn(+state: S.State, +seat: D.Seat) -> S.State:
  S.state.emit(S.state.set_phase(state, S.Idle{seat, D.NonEmpty{S.TakeGun{}, I.uses(state, seat)}}), D.TurnGiven{seat})

def grant.step(rank: Nat, +state: S.State, +seat: D.Seat, result: S.JamResult) -> S.State:
  match rank result:
    case rank S.Act{players}:
      give_turn(S.state.set_players(state, players), seat)
    case rank S.Lift{players}:
      give_turn(S.state.emit(S.state.set_players(state, players), D.JamLifted{seat}), seat)
    case 0n S.Skip{players}:
      S.state.set_phase(S.state.set_players(state, players), S.Blocked{None{}})
    case 1n+rest S.Skip{+players}:
      +world : S.World = S.state.world(state)
      next : D.Seat = G.next_turn(S.players.health(players), S.world.direction(world), seat)
      +next : D.Seat = next
      state : S.State = S.state.set_world(S.state.set_players(state, players), S.world.set_turn(world, Some{next}))
      grant.step(rest, S.state.emit(state, D.TurnSkipped{seat}), next, G.jam(players, next))

def grant.bound(rank: Nat, +state: S.State, +seat: D.Seat) -> S.State:
  +state : S.State = S.state.set_world(state, S.world.set_turn(S.state.world(state), Some{seat}))
  grant.step(rank, state, seat, G.jam(S.state.players(state), seat))

def grant(+state: S.State, seat: D.Seat) -> S.State:
  grant.bound(G.jam_rank(S.state.players(state)), state, seat)

def shuffle(+state: S.State, +load: D.Load, shells: List<&2, D.Shell>, i: Nat) -> S.State:
  match i:
    case 0n:
      +world : S.World = S.world.set_shown(S.world.set_gun(S.state.world(state), shells), load)
      grant(S.state.emit(S.state.set_world(state, world), D.Loaded{load}), S.world.first_turn(world))
    case 1n+rest:
      S.state.set_phase(state, S.NeedSwap{load, shells, 1n+rest})

def batch.found(+state: S.State, +index: Nat, selected: Maybe<&2, S.Batch>) -> S.State:
  match selected:
    case None{}:
      S.state.set_phase(state, S.Blocked{None{}})
    case Some{S.Batch{_, sampled}}:
      +world : S.World = S.state.world(state)
      +load : D.Load = G.load.actual(G.world.load_rule(world), sampled)
      +shells : List<&2, D.Shell> = G.load.shells(load)
      world : S.World = S.world.set_deck(world, G.remove(S.Batch, S.world.deck(world), index))
      shuffle(S.state.set_world(state, world), load, shells, G.predecessor(List.length(&2, D.Shell, shells)))

def batch(+state: S.State, +index: Nat) -> S.State:
  batch.found(state, index, G.nth(S.Batch, S.world.deck(S.state.world(state)), index))

def load.ready(state: S.State, deck: List<&2, S.Batch>) -> S.State:
  match deck:
    case Nil{}:
      S.state.set_phase(state, S.Blocked{None{}})
    case only <> Nil{}:
      batch(state, 0n)
    case first <> next <> rest:
      S.state.set_phase(state, S.NeedBatch{})

def load.refill(+state: S.State, deck: List<&2, S.Batch>) -> S.State:
  match deck:
    case Nil{}:
      +world : S.World = S.world.set_decks(S.state.world(state), G.decks.full())
      load.ready(S.state.set_world(state, world), S.world.deck(world))
    case deck:
      load.ready(state, deck)

def load.begin(+state: S.State) -> S.State:
  +world : S.World = S.state.world(state)
  world : S.World = S.world.set_load_index(world, G.load.next(S.world.first_sequence(world), S.world.load_index(world)))
  +world : S.World = S.world.set_first_sequence(world, False{})
  load.refill(S.state.set_world(state, world), S.world.deck(world))

def initial(+config: D.Config) -> S.State:
  +table : D.Table = G.config.table(config)
  S.State{S.World{config, True{}, 0n, 0n, False{}, 0n, D.Seat0{}, None{}, D.Clockwise{}, None{}, False{}, 0n, False{}, Nil{}, D.Load{0n, 0n}, G.decks.full()}, D.ring.fill(S.Seat, table, S.Seat{100n, S.Free{}, 0, D.slots.empty()}), S.NeedFirst{}, Nil{}, S.Grabs{False{}, D.ring.fill(Bool, table, False{}), D.ring.fill(Maybe<&2, D.Item>, table, None{}), D.ring.fill(Nat, table, 0n), D.ring.fill(Bool, table, False{})}}

# Item distribution (D05, D06, D22, D37 grabbing rows, D55 M1, D56).

def distribute.begin(+state: S.State, seats: List<&2, D.Seat>) -> S.State:
  match seats:
    case Nil{}:
      load.begin(state)
    case +seat <> +rest:
      +grabs : S.Grabs = S.grabs.set_distributing(I.grabs.open_all(seat <> rest, S.state.grabs(state)), True{})
      +state : S.State = S.state.emit(S.state.set_grabs(state, grabs), D.GrabbingBegan{seat <> rest})
      S.state.set_phase(state, S.Grab{I.grab.needs(state)})

def grab.continue.ready(+state: S.State, distributing: Bool, holders: Bool) -> S.State:
  match distributing holders:
    case False{} False{}:
      load.begin(state)
    case _ _:
      S.state.set_phase(state, S.Grab{I.grab.needs(state)})

def grab.continue(+state: S.State) -> S.State:
  +grabs : S.Grabs = S.state.grabs(state)
  grab.continue.ready(state, S.grabs.distributing(grabs), I.holders(D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(grabs))))

def grab.give(+state: S.State, +seat: D.Seat, +item: D.Item) -> S.State:
  grab.continue(S.state.emit(S.state.set_grabs(state, I.grabs.give(S.state.grabs(state), seat, item)), D.Granted{seat, item}))

def grab.chosen(+state: S.State, +seat: D.Seat, found: Maybe<&2, D.Item>) -> S.State:
  match found:
    case Some{item}:
      grab.give(state, seat, item)
    case None{}:
      grab.continue(S.state.tell(state, seat, D.EmptyBriefcase{}))

def grab.pool(+state: S.State, +seat: D.Seat, pool: List<&2, D.Item>) -> S.State:
  match pool:
    case Nil{}:
      grab.chosen(state, seat, None{})
    case item <> Nil{}:
      grab.give(state, seat, item)
    case first <> second <> rest:
      S.state.set_phase(state, S.NeedItem{seat, first, second, rest})

def grab.take(+state: S.State, +seat: D.Seat) -> S.State:
  +state : S.State = S.state.set_grabs(state, I.grabs.stop_intake(S.state.grabs(state), seat))
  grab.pool(state, seat, I.pool(state, seat))

def grab.check.done(+state: S.State, done: Bool) -> S.State:
  match done:
    case True{}:
      S.state.emit(S.state.set_grabs(state, S.grabs.set_distributing(S.state.grabs(state), False{})), D.DistributionDone{})
    case False{}:
      state

def grab.check(+state: S.State) -> S.State:
  grab.check.done(state, Bool.and(S.grabs.distributing(S.state.grabs(state)), I.finished(state)))

def grab.end_all(seats: List<&2, D.Seat>, +state: S.State) -> S.State:
  match seats:
    case Nil{}:
      state
    case +seat <> rest:
      grab.end_all(rest, S.state.emit(S.state.set_grabs(state, I.grabs.close(S.state.grabs(state), seat)), D.GrabbingEnded{seat}))

def grab.put.held(+state: S.State, +seat: D.Seat, +slot: D.Slot, held: Maybe<&2, D.Item>) -> S.State:
  match held:
    case None{}:
      S.state.set_phase(state, S.Blocked{None{}})
    case Some{+item}:
      +players : S.Players = S.state.players(state)
      players : S.Players = S.players.set_slots(players, seat, I.slots.put(I.seat.slots(players, seat), slot, Some{item}))
      +state : S.State = S.state.set_grabs(S.state.set_players(state, players), I.grabs.placed(S.state.grabs(state), seat))
      grab.continue(S.state.emit(state, D.Placed{seat, slot, item}))

def grab.put(+state: S.State, +seat: D.Seat, +slot: D.Slot) -> S.State:
  grab.put.held(state, seat, slot, I.seat.holding(S.state.grabs(state), seat))

# A last placement ends the seat, checks completion, ends the noneligible
# empty-handed grabbers, and (M1) checks completion again before placing.
def grab.place.last(+state: S.State, +seat: D.Seat, +slot: D.Slot, last: Bool) -> S.State:
  match last:
    case True{}:
      +state : S.State = grab.check(S.state.emit(S.state.set_grabs(state, I.grabs.close(S.state.grabs(state), seat)), D.GrabbingEnded{seat}))
      +state : S.State = grab.end_all(I.stalled.seats(state, seat), state)
      grab.put(grab.check(state), seat, slot)
    case False{}:
      grab.put(state, seat, slot)

def grab.place(+state: S.State, +seat: D.Seat, +slot: D.Slot) -> S.State:
  grab.place.last(state, seat, slot, I.placing.last(state, seat))

def grab.selected(+state: S.State, +seat: D.Seat, selected: Maybe<&2, S.GrabOption>) -> S.State:
  match selected:
    case Some{S.TakeItem{}}:
      grab.take(state, seat)
    case Some{S.PutAt{slot}}:
      grab.place(state, seat, slot)
    case None{}:
      S.state.set_phase(state, S.Blocked{None{}})

def round.reset(+state: S.State) -> S.State:
  +world : S.World = S.state.world(state)
  players : S.Players = S.players.reset(S.state.players(state), S.world.round_health(world))
  +world : S.World = S.world.set_direction(S.world.set_checking_first_death(world, True{}), D.Clockwise{})
  +state : S.State = S.state.emit(S.state.set_players(S.state.set_world(state, world), players), D.RoundBegan{S.world.round_index(world), S.world.round_health(world), S.world.first_turn(world)})
  distribute.begin(state, I.begin.seats(state, True{}, S.world.item_amount(world)))

def amount.chosen(+state: S.State, value: Nat) -> S.State:
  round.reset(S.state.set_world(state, S.world.set_item_amount(S.state.world(state), value)))

def amount.rule(state: S.State, rule: D.AmountRule) -> S.State:
  match rule:
    case D.RandomAmount{}:
      S.state.set_phase(state, S.NeedAmount{})
    case D.FixedAmount{amount}:
      amount.chosen(state, amount)

def amount.begin(+state: S.State) -> S.State:
  amount.rule(state, G.load.amount(G.world.load_rule(S.state.world(state))))

def health.chosen(+state: S.State, value: Nat) -> S.State:
  amount.begin(S.state.set_world(state, S.world.set_round_health(S.state.world(state), value)))

def health.rule(state: S.State, rule: D.HealthRule) -> S.State:
  match rule:
    case D.RandomHealth{}:
      S.state.set_phase(state, S.NeedHealth{})
    case D.FixedHealth{health}:
      health.chosen(state, D.pos.nat(health))

def health.begin(+state: S.State) -> S.State:
  health.rule(state, G.round.health(G.world.rules(S.state.world(state))))

def first.chosen(+state: S.State, seat: D.Seat) -> S.State:
  +world : S.World = S.state.world(state)
  world : S.World = S.world.set_round_index(world, G.round.next(S.world.before_round(world), S.world.round_index(world)))
  world : S.World = S.world.set_before_round(world, False{})
  world : S.World = S.world.set_first_turn(world, seat)
  health.begin(S.state.set_world(state, S.world.set_first_sequence(world, True{})))

def first.override(state: S.State, first_death: Maybe<&2, D.Seat>) -> S.State:
  match first_death:
    case None{}:
      S.state.set_phase(state, S.NeedFirst{})
    case Some{seat}:
      first.chosen(state, seat)

def first.begin(+state: S.State) -> S.State:
  first.override(state, S.world.first_death(S.state.world(state)))

def start(+config: D.Config) -> D.Stepped<&2, S.State>:
  S.state.stepped(first.begin(initial(config)))

def win.final(state: S.State, final: Bool) -> S.State:
  match final:
    case True{}:
      S.state.emit(S.state.set_phase(state, S.Ended{}), D.MatchConcluded{})
    case False{}:
      first.begin(state)

def win(+state: S.State, +seat: D.Seat) -> S.State:
  +world : S.World = S.state.world(state)
  +players : S.Players = S.state.players(state)
  +prize : U32 = D.prize(S.world.round_index(world))
  cash : U32 = G.value.or(U32, D.ring.get(U32, S.players.cash(players), seat), 0)
  players : S.Players = S.players.set_cash(players, seat, U32.add(cash, prize))
  win.final(S.state.emit(S.state.set_players(state, players), D.RoundWon{seat, prize}), Nat.is_eq(1n+S.world.round_index(world), D.plan.length(S.world.plan(world))))

def turn.recipient(passing: Bool, current: D.Seat, next: D.Seat) -> D.Seat:
  match passing:
    case False{}:
      current
    case True{}:
      next

def reload.begin(+state: S.State) -> S.State:
  distribute.begin(state, I.begin.seats(state, False{}, S.world.item_amount(S.state.world(state))))

def turn.continue(+state: S.State, +recipient: D.Seat, gun: List<&2, D.Shell>) -> S.State:
  match gun:
    case Nil{}:
      reload.begin(S.state.set_world(state, S.world.set_first_turn(S.state.world(state), recipient)))
    case shell <> rest:
      grant(S.state.set_world(state, S.world.set_first_turn(S.state.world(state), recipient)), recipient)

def turn.winner(+state: S.State, +shooter: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>) -> S.State:
  match winner:
    case Some{seat}:
      win(state, seat)
    case None{}:
      +world : S.World = S.state.world(state)
      recipient : D.Seat = turn.recipient(passing, shooter, G.next_turn(S.players.health(S.state.players(state)), S.world.direction(world), shooter))
      turn.continue(state, recipient, S.world.gun(world))

def turn.amount(+state: S.State, shooter: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>, rule: D.AmountRule) -> S.State:
  match rule:
    case D.RandomAmount{}:
      turn.winner(state, shooter, passing, winner)
    case D.FixedAmount{amount}:
      +state : S.State = S.state.set_world(state, S.world.set_item_amount(S.state.world(state), amount))
      turn.winner(state, shooter, passing, winner)

def turn.live(+state: S.State, shooter: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>, rule: D.AmountRule, live: Bool) -> S.State:
  match live:
    case True{}:
      S.state.set_phase(state, S.NeedTurnAmount{shooter, passing, winner})
    case False{}:
      turn.amount(state, shooter, passing, winner, rule)

# UserEndTurn_Packet: the packet's winner is the shot's winner check, or
# None after beer ejects the last shell.
def turn.packet(+state: S.State, shooter: D.Seat, passing: Bool, +winner: Maybe<&2, D.Seat>) -> S.State:
  +rule : D.AmountRule = G.load.amount(G.world.load_rule(S.state.world(state)))
  turn.live(state, shooter, passing, winner, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(state)), I.reload.wanted(state, winner)))

def turn.end(+state: S.State, shooter: D.Seat, passing: Bool) -> S.State:
  turn.packet(state, shooter, passing, G.winner(S.players.health(S.state.players(state))))

def death.remember(+state: S.State, seat: D.Seat, checking: Bool) -> S.State:
  match checking:
    case False{}:
      state
    case True{}:
      world : S.World = S.world.set_checking_first_death(S.world.set_first_death(S.state.world(state), Some{seat}), False{})
      S.state.set_world(state, world)

def death(+state: S.State, +target: D.Seat, shell: D.Shell, health: Nat) -> S.State:
  match shell health:
    case D.Live{} 0n:
      S.state.emit(death.remember(state, target, S.world.checking_first_death(S.state.world(state))), D.Died{target})
    case _ _:
      state

def shoot.loaded(+state: S.State, +shooter: D.Seat, +target: D.Seat, +shell: D.Shell, rest: List<&2, D.Shell>) -> S.State:
  +world : S.World = S.state.world(state)
  +players : S.Players = S.state.players(state)
  +damage : D.Damage = G.captured(S.world.sawed(world))
  +before : Nat = G.value.or(Nat, D.ring.get(Nat, S.players.health(players), target), 100n)
  +health : Nat = G.shot.health(shell, before, damage)
  +players : S.Players = S.players.set_health(players, target, health)
  world : S.World = S.world.set_sawed(S.world.set_gun(world, rest), False{})
  state : S.State = S.state.emit(S.state.set_players(S.state.set_world(state, world), players), D.Fired{shooter, target, shell, damage, G.subtract(before, health), health})
  turn.end(death(state, target, shell, health), shooter, G.shot.passes(shell, D.seat.eq(shooter, target)))

def shoot.gun(state: S.State, shooter: D.Seat, target: D.Seat, gun: List<&2, D.Shell>) -> S.State:
  match gun:
    case Nil{}:
      S.state.set_phase(state, S.Blocked{Some{shooter}})
    case shell <> rest:
      shoot.loaded(state, shooter, target, shell, rest)

def shoot(+state: S.State, shooter: D.Seat, target: D.Seat) -> S.State:
  shoot.gun(state, shooter, target, S.world.gun(S.state.world(state)))

def aim.selected(state: S.State, shooter: D.Seat, selected: Maybe<&2, S.TargetOption>) -> S.State:
  match selected:
    case Some{S.Target{target}}:
      shoot(state, shooter, target)
    case None{}:
      S.state.set_phase(state, S.Blocked{Some{shooter}})

# Item use (D17, D18, D28, D29, D37). A use or steal consumes the slot,
# then applies the effect; jammer and adrenaline open a selection phase.

def item.resume(+state: S.State, +seat: D.Seat) -> S.State:
  S.state.set_phase(state, S.Idle{seat, D.NonEmpty{S.TakeGun{}, I.uses(state, seat)}})

def item.end(+state: S.State, +seat: D.Seat, ending: Bool) -> S.State:
  match ending:
    case True{}:
      turn.packet(state, seat, True{}, None{})
    case False{}:
      item.resume(state, seat)

def item.chamber(+state: S.State, +seat: D.Seat, item: D.Item, ending: Bool, +shell: D.Shell, rest: List<&2, D.Shell>) -> S.State:
  match item:
    case D.Glass{}:
      item.end(S.state.tell(state, seat, D.Glimpse{shell}), seat, ending)
    case D.Beer{}:
      +state : S.State = S.state.set_world(state, S.world.set_gun(S.state.world(state), rest))
      item.end(S.state.emit(state, D.Ejected{seat, shell}), seat, ending)
    case D.Inverter{}:
      +state : S.State = S.state.set_world(state, S.world.set_gun(S.state.world(state), I.invert(shell) <> rest))
      item.end(S.state.emit(state, D.Inverted{seat}), seat, ending)
    case _:
      S.state.set_phase(state, S.Blocked{None{}})

def item.shell(+state: S.State, +seat: D.Seat, item: D.Item, ending: Bool, gun: List<&2, D.Shell>) -> S.State:
  match gun:
    case Nil{}:
      S.state.set_phase(state, S.Blocked{None{}})
    case +shell <> rest:
      item.chamber(state, seat, item, ending, shell, rest)

def item.heal(+state: S.State, +seat: D.Seat, heal: Bool) -> S.State:
  match heal:
    case True{}:
      +players : S.Players = S.state.players(state)
      +hp : Nat = 1n+I.seat.health(players, seat)
      +state : S.State = S.state.set_players(state, S.players.set_health(players, seat, hp))
      item.resume(S.state.emit(state, D.Healed{seat, hp}), seat)
    case False{}:
      item.resume(state, seat)

def item.tell(+state: S.State, +seat: D.Seat, phone: Maybe<&2, D.Secret>) -> S.State:
  match phone:
    case None{}:
      S.state.set_phase(state, S.Blocked{None{}})
    case Some{secret}:
      item.resume(S.state.tell(state, seat, secret), seat)

def item.effect(+state: S.State, +seat: D.Seat, item: D.Item, ending: Bool, phone: Maybe<&2, D.Secret>) -> S.State:
  match item:
    case D.Saw{}:
      item.resume(S.state.set_world(state, S.world.set_sawed(S.state.world(state), True{})), seat)
    case D.Jammer{}:
      S.state.set_phase(state, S.JamPick{seat, I.jam.for(state, seat)})
    case D.Cigarettes{}:
      item.heal(state, seat, Nat.is_lt(I.seat.health(S.state.players(state), seat), S.world.round_health(S.state.world(state))))
    case D.Phone{}:
      item.tell(state, seat, phone)
    case D.Adrenaline{}:
      S.state.set_phase(state, S.StealPick{seat, I.steal.for(state, seat)})
    case D.Remote{}:
      +direction : D.Direction = I.flip(S.world.direction(S.state.world(state)))
      item.resume(S.state.emit(S.state.set_world(state, S.world.set_direction(S.state.world(state), direction)), D.DirectionFlipped{direction}), seat)
    case D.Glass{}:
      item.shell(state, seat, D.Glass{}, ending, S.world.gun(S.state.world(state)))
    case D.Beer{}:
      item.shell(state, seat, D.Beer{}, ending, S.world.gun(S.state.world(state)))
    case D.Inverter{}:
      item.shell(state, seat, D.Inverter{}, ending, S.world.gun(S.state.world(state)))

def item.consume(+state: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item, ending: Bool, phone: Maybe<&2, D.Secret>) -> S.State:
  +players : S.Players = S.state.players(state)
  players : S.Players = S.players.set_slots(players, owner, I.slots.put(I.seat.slots(players, owner), slot, None{}))
  item.effect(S.state.emit(S.state.set_players(state, players), D.Used{seat, owner, slot, item}), seat, item, ending, phone)

def item.clue.found(+state: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +position: Nat, found: Maybe<&2, D.Shell>) -> S.State:
  match found:
    case None{}:
      S.state.set_phase(state, S.Blocked{Some{seat}})
    case Some{shell}:
      item.consume(state, seat, owner, slot, D.Phone{}, False{}, Some{D.Clue{position, shell}})

# The phone announces drawn index plus one, capped at the seventh shell (D28).
def item.clue(+state: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, index: Nat) -> S.State:
  +position : Nat = D.clamp(1n+index, D.phone.cap())
  item.clue.found(state, seat, owner, slot, position, G.nth(D.Shell, S.world.gun(S.state.world(state)), G.predecessor(position)))

def item.phone(+state: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, length: Nat) -> S.State:
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
      S.state.set_phase(state, S.NeedPhone{seat, owner, slot})

def item.route(+state: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, item: D.Item, ending: Bool, length: Nat) -> S.State:
  match item:
    case D.Phone{}:
      item.phone(state, seat, owner, slot, length)
    case item:
      item.consume(state, seat, owner, slot, item, ending, None{})

def item.use(+state: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item) -> S.State:
  +length : Nat = List.length(&2, D.Shell, S.world.gun(S.state.world(state)))
  item.route(state, seat, owner, slot, item, I.ends_turn(item, length), length)

def jam.selected(+state: S.State, +seat: D.Seat, selected: Maybe<&2, S.JamOption>) -> S.State:
  match selected:
    case Some{S.JamAt{+target}}:
      +players : S.Players = S.state.players(state)
      players : S.Players = S.players.set_jam(players, target, S.Jammed{})
      item.resume(S.state.emit(S.state.set_players(state, players), D.JamApplied{seat, target}), seat)
    case None{}:
      S.state.set_phase(state, S.Blocked{Some{seat}})

def steal.selected(+state: S.State, +seat: D.Seat, selected: Maybe<&2, S.StealOption>) -> S.State:
  match selected:
    case Some{S.Pick{owner, slot, item}}:
      item.use(state, seat, owner, slot, item)
    case None{}:
      S.state.set_phase(state, S.Blocked{Some{seat}})

def pickup.selected(state: S.State, +seat: D.Seat, selected: Maybe<&2, S.IdleOption>) -> S.State:
  match selected:
    case Some{S.TakeGun{}}:
      pickup(state, seat)
    case Some{S.UseAt{slot, item}}:
      item.use(state, seat, seat, slot, item)
    case None{}:
      S.state.set_phase(state, S.Blocked{Some{seat}})

def pickup.same(state: S.State, seat: D.Seat, options: D.NonEmpty<&2, S.IdleOption>, index: Nat, same: Bool) -> S.State:
  match same:
    case True{}:
      pickup.selected(state, seat, G.idle.nth(D.nonempty.list(S.IdleOption, options), index))
    case False{}:
      S.state.set_phase(state, S.Blocked{Some{seat}})

def pickup.choice(state: S.State, +seat: D.Seat, options: D.NonEmpty<&2, S.IdleOption>, choice: D.Choice) -> S.State:
  match choice:
    case D.Choice{chosen, index, _}:
      pickup.same(state, seat, options, index, D.seat.eq(seat, chosen))

def pickup.resolved(state: S.State, seat: D.Seat, options: D.NonEmpty<&2, S.IdleOption>, resolved: D.Resolved) -> S.State:
  match resolved:
    case D.Chose{choice}:
      pickup.choice(state, seat, options, choice)
    case _:
      S.state.set_phase(state, S.Blocked{Some{seat}})

def pickup_slice(+state: S.State, n: Nat) -> D.Stepped<&2, S.State>:
  match state:
    case S.State{world, players, S.Idle{seat, options}, notes, grabs}:
      S.state.stepped(pickup.resolved(S.state.set_notes(state, Nil{}), seat, options, D.resolve(request(state), n)))
    case _:
      D.Stepped{state, Nil{}}

def answer.choice(+state: S.State, choice: D.Choice) -> S.State:
  match state choice:
    case S.State{world, players, S.Idle{+seat, options}, notes, grabs} D.Choice{_, index, _}:
      pickup.selected(state, seat, G.idle.nth(D.nonempty.list(S.IdleOption, options), index))
    case S.State{world, +players, S.Aim{+seat}, notes, grabs} D.Choice{_, index, _}:
      aim.selected(state, seat, G.target.nth(G.aim.targets(players), index))
    case S.State{world, players, S.Grab{needs}, notes, grabs} D.Choice{+chosen, index, _}:
      grab.selected(state, chosen, I.grab.nth(G.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs, chosen), Nil{}), index))
    case S.State{world, players, S.JamPick{+seat, targets}, notes, grabs} D.Choice{_, index, _}:
      jam.selected(state, seat, I.jam.nth(targets, index))
    case S.State{world, players, S.StealPick{+seat, picks}, notes, grabs} D.Choice{_, index, _}:
      steal.selected(state, seat, I.steal.nth(picks, index))
    case _ _:
      S.state.set_phase(state, S.Blocked{None{}})

def answer.draw(+state: S.State, value: Nat) -> S.State:
  match state:
    case S.State{world, players, S.NeedFirst{}, notes, grabs}:
      first.chosen(state, G.value.or(D.Seat, G.nth(D.Seat, D.table.seats(S.world.table(world)), value), D.Seat0{}))
    case S.State{world, players, S.NeedHealth{}, notes, grabs}:
      health.chosen(state, value)
    case S.State{world, players, S.NeedAmount{}, notes, grabs}:
      amount.chosen(state, value)
    case S.State{world, players, S.NeedBatch{}, notes, grabs}:
      batch(state, value)
    case S.State{world, players, S.NeedSwap{load, shells, +i}, notes, grabs}:
      shuffle(state, load, G.swap(shells, i, value), G.predecessor(i))
    case S.State{world, players, S.NeedTurnAmount{from, passing, winner}, notes, grabs}:
      turn.winner(S.state.set_world(state, S.world.set_item_amount(world, value)), from, passing, winner)
    case S.State{world, players, S.NeedItem{seat, first, second, rest}, notes, grabs}:
      grab.chosen(state, seat, G.nth(D.Item, first <> second <> rest, value))
    case S.State{world, players, S.NeedPhone{seat, owner, slot}, notes, grabs}:
      item.clue(state, seat, owner, slot, value)
    case _:
      S.state.set_phase(state, S.Blocked{None{}})

def answer.resolved(state: S.State, resolved: D.Resolved) -> S.State:
  match resolved:
    case D.Drawn{value}:
      answer.draw(state, value)
    case D.Chose{choice}:
      answer.choice(state, choice)
    case D.Unanswerable{}:
      S.state.set_phase(state, S.Blocked{None{}})

def answer.request(+state: S.State, n: Nat, request: D.Request) -> D.Stepped<&2, S.State>:
  match request:
    case D.Finished{}:
      D.Stepped{state, Nil{}}
    case D.Stuck{}:
      D.Stepped{state, Nil{}}
    case request:
      S.state.stepped(answer.resolved(S.state.set_notes(state, Nil{}), D.resolve(request, n)))

def answer(+state: S.State, n: Nat) -> D.Stepped<&2, S.State>:
  answer.request(state, n, request(state))

def stepped.state(stepped: D.Stepped<&2, S.State>) -> S.State:
  match stepped:
    case D.Stepped{state, _}:
      state

def run.merge(stepped: D.Stepped<&2, S.State>, ran: D.Ran<&2, S.State>) -> D.Ran<&2, S.State>:
  match stepped ran:
    case D.Stepped{_, first} D.Ran{state, rest, tape}:
      D.Ran{state, List.append(&2, D.Note, first, rest), tape}

def run.request(fuel: Nat, request: D.Request, +state: S.State, tape: List<&2, Nat>) -> D.Ran<&2, S.State>:
  match fuel request tape:
    case _ D.Finished{} tape:
      D.Ran{state, Nil{}, tape}
    case _ D.Stuck{} tape:
      D.Ran{state, Nil{}, tape}
    case 0n _ tape:
      D.Ran{state, Nil{}, tape}
    case _ _ Nil{}:
      D.Ran{state, Nil{}, Nil{}}
    case 1n+fuel _ n <> rest:
      +next : D.Stepped<&2, S.State> = answer(state, n)
      +state : S.State = stepped.state(next)
      run.merge(next, run.request(fuel, P.request(state), state, rest))

def run(fuel: Nat, +state: S.State, tape: List<&2, Nat>) -> D.Ran<&2, S.State>:
  run.request(fuel, request(state), state, tape)
