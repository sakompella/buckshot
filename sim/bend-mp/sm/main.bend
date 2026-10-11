import Base
import ../domain.bend as D
import ./state.bend as S
import ./rules.bend as G
import ./point.bend as P

def request(state: S.State) -> D.Request:
  P.request(state)

def stage(state: S.State) -> D.Stage:
  P.stage(state)

def point(state: S.State) -> D.Point:
  P.point(state)

def pickup(state: S.State, +seat: D.Seat) -> S.State:
  match state:
    case S.State{world, +players, _, notes}:
      S.State{world, players, S.Aim{seat, G.targets(D.ring.entries(Nat, S.players.health(players)))}, List.append(&2, D.Note, notes, [D.Shown{D.PickedUp{seat}}])}

def pickup.selected(state: S.State, seat: D.Seat, selected: Maybe<&2, S.IdleOption>) -> S.State:
  match selected:
    case Some{S.TakeGun{}}:
      pickup(state, seat)
    case None{}:
      S.state.set_phase(state, S.Blocked{})

def pickup.same(state: S.State, seat: D.Seat, options: D.NonEmpty<&2, S.IdleOption>, index: Nat, same: Bool) -> S.State:
  match same:
    case True{}:
      pickup.selected(state, seat, G.idle.nth(D.nonempty.list(S.IdleOption, options), index))
    case False{}:
      S.state.set_phase(state, S.Blocked{})

def pickup.choice(state: S.State, +seat: D.Seat, options: D.NonEmpty<&2, S.IdleOption>, choice: D.Choice) -> S.State:
  match choice:
    case D.Choice{chosen, index, _}:
      pickup.same(state, seat, options, index, D.seat.eq(seat, chosen))

def pickup.resolved(state: S.State, seat: D.Seat, options: D.NonEmpty<&2, S.IdleOption>, resolved: D.Resolved) -> S.State:
  match resolved:
    case D.Chose{choice}:
      pickup.choice(state, seat, options, choice)
    case _:
      S.state.set_phase(state, S.Blocked{})

def pickup_slice(+state: S.State, n: Nat) -> D.Stepped<&2, S.State>:
  match state:
    case S.State{world, players, S.Idle{seat, options}, notes}:
      S.state.stepped(pickup.resolved(S.state.set_notes(state, Nil{}), seat, options, D.resolve(request(state), n)))
    case _:
      D.Stepped{state, Nil{}}

def replace_hidden(+state: S.State, gun: List<&2, D.Shell>, decks: S.Decks) -> S.State:
  S.state.set_world(state, S.world.set_decks(S.world.set_gun(S.state.world(state), gun), decks))

def give_turn(+state: S.State, +seat: D.Seat) -> S.State:
  +players : S.Players = S.state.players(state)
  players : S.Players = S.players.set_has_turn(players, D.ring.set(Bool, S.players.has_turn(players), seat, True{}))
  S.state.emit(S.state.set_phase(S.state.set_players(state, players), S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}), D.TurnGiven{seat})

def grant.step(rank: Nat, +state: S.State, +seat: D.Seat, result: S.JamResult) -> S.State:
  match rank result:
    case rank S.Act{players}:
      give_turn(S.state.set_players(state, players), seat)
    case rank S.Lift{players}:
      give_turn(S.state.emit(S.state.set_players(state, players), D.JamLifted{seat}), seat)
    case 0n S.Skip{players}:
      S.state.set_phase(S.state.set_players(state, players), S.Blocked{})
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
      S.state.set_phase(state, S.Blocked{})
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
      S.state.set_phase(state, S.Blocked{})
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
  S.State{S.World{config, True{}, 0n, 0n, False{}, 0n, D.Seat0{}, None{}, D.Clockwise{}, None{}, False{}, 0n, False{}, Nil{}, D.Load{0n, 0n}, G.decks.full()}, S.Players{D.ring.fill(Nat, table, 100n), D.ring.fill(Bool, table, False{}), D.ring.fill(Bool, table, False{}), D.ring.fill(U32, table, 0), D.ring.fill(D.Slots, table, D.slots.empty()), D.ring.fill(Bool, table, False{})}, S.NeedFirst{}, Nil{}}

def round.reset(+state: S.State) -> S.State:
  +world : S.World = S.state.world(state)
  +table : D.Table = S.world.table(world)
  +players : S.Players = S.state.players(state)
  players : S.Players = S.players.set_jammed(players, D.ring.fill(Bool, table, False{}))
  players : S.Players = S.players.set_health(players, D.ring.fill(Nat, table, S.world.round_health(world)))
  players : S.Players = S.players.set_slots(players, D.ring.fill(D.Slots, table, D.slots.empty()))
  +world : S.World = S.world.set_direction(S.world.set_checking_first_death(world, True{}), D.Clockwise{})
  load.begin(S.state.emit(S.state.set_players(S.state.set_world(state, world), players), D.RoundBegan{S.world.round_index(world), S.world.round_health(world), S.world.first_turn(world)}))

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

def start.supported(state: S.State, supported: Bool) -> D.Stepped<&2, S.State>:
  match supported:
    case True{}:
      S.state.stepped(first.begin(state))
    case False{}:
      S.state.stepped(S.state.set_phase(state, S.Blocked{}))

def start(+config: D.Config) -> D.Stepped<&2, S.State>:
  start.supported(initial(config), G.config.no_items(config))

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
  players : S.Players = S.players.set_cash(players, D.ring.set(U32, S.players.cash(players), seat, U32.add(cash, prize)))
  win.final(S.state.emit(S.state.set_players(state, players), D.RoundWon{seat, prize}), Nat.is_eq(1n+S.world.round_index(world), D.plan.length(S.world.plan(world))))

def turn.recipient(passing: Bool, current: D.Seat, next: D.Seat) -> D.Seat:
  match passing:
    case False{}:
      current
    case True{}:
      next

def turn.continue(+state: S.State, +recipient: D.Seat, gun: List<&2, D.Shell>) -> S.State:
  match gun:
    case Nil{}:
      load.begin(S.state.set_world(state, S.world.set_first_turn(S.state.world(state), recipient)))
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

def turn.amount(+state: S.State, shooter: D.Seat, passing: Bool, rule: D.AmountRule) -> S.State:
  match rule:
    case D.RandomAmount{}:
      turn.winner(state, shooter, passing, G.winner(S.players.health(S.state.players(state))))
    case D.FixedAmount{amount}:
      +state : S.State = S.state.set_world(state, S.world.set_item_amount(S.state.world(state), amount))
      turn.winner(state, shooter, passing, G.winner(S.players.health(S.state.players(state))))

def turn.end(+state: S.State, shooter: D.Seat, passing: Bool) -> S.State:
  turn.amount(state, shooter, passing, G.load.amount(G.world.load_rule(S.state.world(state))))

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
  +players : S.Players = S.players.set_health(players, D.ring.set(Nat, S.players.health(players), target, health))
  +players : S.Players = S.players.set_has_turn(players, D.ring.set(Bool, S.players.has_turn(players), shooter, False{}))
  world : S.World = S.world.set_sawed(S.world.set_gun(world, rest), False{})
  state : S.State = S.state.emit(S.state.set_players(S.state.set_world(state, world), players), D.Fired{shooter, target, shell, damage, G.subtract(before, health), health})
  turn.end(death(state, target, shell, health), shooter, G.shot.passes(shell, D.seat.eq(shooter, target)))

def shoot.gun(state: S.State, shooter: D.Seat, target: D.Seat, gun: List<&2, D.Shell>) -> S.State:
  match gun:
    case Nil{}:
      S.state.set_phase(state, S.Blocked{})
    case shell <> rest:
      shoot.loaded(state, shooter, target, shell, rest)

def shoot(+state: S.State, shooter: D.Seat, target: D.Seat) -> S.State:
  shoot.gun(state, shooter, target, S.world.gun(S.state.world(state)))

def aim.selected(state: S.State, shooter: D.Seat, selected: Maybe<&2, S.TargetOption>) -> S.State:
  match selected:
    case Some{S.Target{target}}:
      shoot(state, shooter, target)
    case None{}:
      S.state.set_phase(state, S.Blocked{})

def answer.idle(state: S.State, seat: D.Seat, options: D.NonEmpty<&2, S.IdleOption>, index: Nat, allowed: Bool) -> S.State:
  match allowed:
    case True{}:
      pickup.selected(state, seat, G.idle.nth(D.nonempty.list(S.IdleOption, options), index))
    case False{}:
      S.state.set_phase(state, S.Blocked{})

def answer.aim(state: S.State, seat: D.Seat, targets: List<&2, S.TargetOption>, index: Nat, allowed: Bool) -> S.State:
  match allowed:
    case True{}:
      aim.selected(state, seat, G.target.nth(targets, index))
    case False{}:
      S.state.set_phase(state, S.Blocked{})

def answer.choice(+state: S.State, choice: D.Choice) -> S.State:
  match state choice:
    case S.State{world, players, S.Idle{+seat, options}, notes} D.Choice{chosen, index, _}:
      answer.idle(state, seat, options, index, Bool.and(D.seat.eq(seat, chosen), G.accepted(state, seat)))
    case S.State{world, players, S.Aim{+seat, targets}, notes} D.Choice{chosen, index, _}:
      answer.aim(state, seat, targets, index, Bool.and(D.seat.eq(seat, chosen), G.accepted(state, seat)))
    case _ _:
      S.state.set_phase(state, S.Blocked{})

def answer.draw(+state: S.State, value: Nat) -> S.State:
  match state:
    case S.State{world, players, S.NeedFirst{}, notes}:
      first.chosen(state, G.value.or(D.Seat, G.nth(D.Seat, D.table.seats(S.world.table(world)), value), D.Seat0{}))
    case S.State{world, players, S.NeedHealth{}, notes}:
      health.chosen(state, value)
    case S.State{world, players, S.NeedAmount{}, notes}:
      amount.chosen(state, value)
    case S.State{world, players, S.NeedBatch{}, notes}:
      batch(state, value)
    case S.State{world, players, S.NeedSwap{load, shells, +i}, notes}:
      shuffle(state, load, G.swap(shells, i, value), G.predecessor(i))
    case _:
      S.state.set_phase(state, S.Blocked{})

def answer.resolved(state: S.State, resolved: D.Resolved) -> S.State:
  match resolved:
    case D.Drawn{value}:
      answer.draw(state, value)
    case D.Chose{choice}:
      answer.choice(state, choice)
    case D.Unanswerable{}:
      S.state.set_phase(state, S.Blocked{})

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
