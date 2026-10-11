import Base
import ../domain.bend as D
import ./state.bend as S

def targets(entries: List<&2, D.At<&2, Nat>>) -> List<&2, S.TargetOption>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{seat, 0n} <> rest:
      targets(rest)
    case D.At{seat, 1n+hp} <> rest:
      S.Target{seat} <> targets(rest)

def idle.moves(options: List<&2, S.IdleOption>) -> List<&2, D.Move>:
  match options:
    case Nil{}:
      Nil{}
    case S.TakeGun{} <> rest:
      D.PickUp{} <> idle.moves(rest)

def aim.moves(options: List<&2, S.TargetOption>) -> List<&2, D.Move>:
  match options:
    case Nil{}:
      Nil{}
    case S.Target{seat} <> rest:
      D.Shoot{seat} <> aim.moves(rest)

def idle.nth(options: List<&2, S.IdleOption>, n: Nat) -> Maybe<&2, S.IdleOption>:
  match options n:
    case Nil{} _:
      None{}
    case option <> rest 0n:
      Some{option}
    case option <> rest 1n+n:
      idle.nth(rest, n)

def target.nth(options: List<&2, S.TargetOption>, n: Nat) -> Maybe<&2, S.TargetOption>:
  match options n:
    case Nil{} _:
      None{}
    case option <> rest 0n:
      Some{option}
    case option <> rest 1n+n:
      target.nth(rest, n)

def seat.menu(table: D.Table, seat: D.Seat, moves: List<&2, D.Move>) -> D.Request:
  D.request.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, moves))

def value.or(-A: Data, value: Maybe<&2, A>, fallback: A) -> A:
  match value:
    case Some{x}:
      x
    case None{}:
      fallback

def alive(hp: Nat) -> Bool:
  match hp:
    case 0n:
      False{}
    case 1n+rest:
      True{}

def seats.keep(keep: Bool, seat: D.Seat, rest: List<&2, D.Seat>) -> List<&2, D.Seat>:
  match keep:
    case True{}:
      seat <> rest
    case False{}:
      rest

def turn_candidates(entries: List<&2, D.At<&2, Nat>>, +current: D.Seat) -> List<&2, D.Seat>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+seat, hp} <> rest:
      seats.keep(Bool.or(alive(hp), D.seat.eq(seat, current)), seat, turn_candidates(rest, current))

def successor.pick(same: Bool, next: D.Seat, later: D.Seat) -> D.Seat:
  match same:
    case True{}:
      next
    case False{}:
      later

def successor.go(seats: List<&2, D.Seat>, +current: D.Seat, +wrap: D.Seat) -> D.Seat:
  match seats:
    case Nil{}:
      wrap
    case seat <> Nil{}:
      wrap
    case +seat <> +next <> rest:
      successor.pick(D.seat.eq(seat, current), next, successor.go(next <> rest, current, wrap))

def successor(seats: List<&2, D.Seat>, +current: D.Seat) -> D.Seat:
  match seats:
    case Nil{}:
      current
    case +head <> rest:
      successor.go(head <> rest, current, head)

def traversal(direction: D.Direction, seats: List<&2, D.Seat>, current: D.Seat) -> D.Seat:
  match direction:
    case D.Clockwise{}:
      successor(seats, current)
    case D.CounterClockwise{}:
      successor(List.reverse(&2, D.Seat, seats), current)

def next_turn(health: D.Ring<&2, Nat>, direction: D.Direction, +current: D.Seat) -> D.Seat:
  traversal(direction, turn_candidates(D.ring.entries(Nat, health), current), current)

def jam.flags(+players: S.Players, +seat: D.Seat, jammed: Bool, checked: Bool) -> S.JamResult:
  match jammed checked:
    case False{} _:
      S.Act{players}
    case True{} False{}:
      S.Skip{S.players.set_checked(players, D.ring.set(Bool, S.players.checked(players), seat, True{}))}
    case True{} True{}:
      S.Lift{S.players.set_jammed(players, D.ring.set(Bool, S.players.jammed(players), seat, False{}))}

def jam(+players: S.Players, +seat: D.Seat) -> S.JamResult:
  jam.flags(players, seat, value.or(Bool, D.ring.get(Bool, S.players.jammed(players), seat), False{}), value.or(Bool, D.ring.get(Bool, S.players.checked(players), seat), False{}))

def jam_rank.bit(jammed: Bool, checked: Bool) -> Nat:
  match jammed checked:
    case True{} False{}:
      1n
    case _ _:
      0n

def jam_rank.entries(entries: List<&2, D.At<&2, Bool>>, +checked: D.Ring<&2, Bool>) -> Nat:
  match entries:
    case Nil{}:
      0n
    case D.At{seat, jammed} <> rest:
      Nat.add(jam_rank.bit(jammed, value.or(Bool, D.ring.get(Bool, checked, seat), False{})), jam_rank.entries(rest, checked))

def jam_rank(+players: S.Players) -> Nat:
  jam_rank.entries(D.ring.entries(Bool, S.players.jammed(players)), S.players.checked(players))

def nth(-A: Data, xs: List<&2, A>, n: Nat) -> Maybe<&2, A>:
  match xs n:
    case Nil{} _:
      None{}
    case x <> rest 0n:
      Some{x}
    case x <> rest 1n+n:
      nth(A, rest, n)

def replace(-A: Data, xs: List<&2, A>, n: Nat, value: A) -> List<&2, A>:
  match xs n:
    case Nil{} _:
      Nil{}
    case x <> rest 0n:
      value <> rest
    case x <> rest 1n+n:
      x <> replace(A, rest, n, value)

def remove(-A: Data, xs: List<&2, A>, n: Nat) -> List<&2, A>:
  match xs n:
    case Nil{} _:
      Nil{}
    case x <> rest 0n:
      rest
    case x <> rest 1n+n:
      x <> remove(A, rest, n)

def swap.found(xs: List<&2, D.Shell>, i: Nat, j: Nat, a: Maybe<&2, D.Shell>, b: Maybe<&2, D.Shell>) -> List<&2, D.Shell>:
  match a b:
    case Some{x} Some{y}:
      replace(D.Shell, replace(D.Shell, xs, i, y), j, x)
    case _ _:
      xs

def swap(+xs: List<&2, D.Shell>, +i: Nat, +j: Nat) -> List<&2, D.Shell>:
  swap.found(xs, i, j, nth(D.Shell, xs, i), nth(D.Shell, xs, j))

def predecessor(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+n:
      n

def repeat(n: Nat, +shell: D.Shell) -> List<&2, D.Shell>:
  match n:
    case 0n:
      Nil{}
    case 1n+n:
      shell <> repeat(n, shell)

def load.shells(load: D.Load) -> List<&2, D.Shell>:
  match load:
    case D.Load{live, blank}:
      List.append(&2, D.Shell, repeat(live, D.Live{}), repeat(blank, D.Blank{}))

def rules.load(loads: D.LoadRules, index: Nat) -> D.LoadRule:
  match loads index:
    case D.LoadRules{a, _, _, _} 0n:
      a
    case D.LoadRules{_, b, _, _} 1n:
      b
    case D.LoadRules{_, _, c, _} 2n:
      c
    case D.LoadRules{_, _, _, d} _:
      d

def round.health(round: D.RoundRules) -> D.HealthRule:
  match round:
    case D.RoundRules{health, _, _}:
      health

def round.load(round: D.RoundRules, index: Nat) -> D.LoadRule:
  match round:
    case D.RoundRules{_, loads, _}:
      rules.load(loads, index)

def world.rules(+world: S.World) -> D.RoundRules:
  value.or(D.RoundRules, D.plan.round(S.world.plan(world), S.world.round_index(world)), D.config.default_round())

def world.load_rule(+world: S.World) -> D.LoadRule:
  round.load(world.rules(world), S.world.load_index(world))

def load.actual(rule: D.LoadRule, sampled: D.Load) -> D.Load:
  match rule:
    case D.LoadRule{D.RandomShells{}, _}:
      sampled
    case D.LoadRule{D.FixedShells{live, blank}, _}:
      D.Load{live, D.pos.nat(blank)}
    case D.LoadRule{D.AllLive{live}, _}:
      D.Load{D.pos.nat(live), 0n}

def load.amount(rule: D.LoadRule) -> D.AmountRule:
  match rule:
    case D.LoadRule{_, amount}:
      amount

def batches(loads: List<&2, D.Load>, +index: Nat) -> List<&2, S.Batch>:
  match loads:
    case Nil{}:
      Nil{}
    case load <> rest:
      S.Batch{index, load} <> batches(rest, 1n+index)

def decks.full() -> S.Decks:
  S.Decks{batches(D.table.deck(D.TwoSeats{}), 0n), batches(D.table.deck(D.ThreeSeats{}), 0n), batches(D.table.deck(D.FourSeats{}), 0n)}

def load.next(first: Bool, index: Nat) -> Nat:
  match first index:
    case True{} _:
      0n
    case False{} 0n:
      1n
    case False{} 1n:
      2n
    case False{} 2n:
      3n
    case False{} _:
      0n

def item.disabled(rule: D.ItemRule) -> Bool:
  match rule:
    case D.ItemRule{enabled, _, _}:
      Bool.not(enabled)

def items.disabled(items: D.ItemRules) -> Bool:
  match items:
    case D.ItemRules{a, b, c, d, e, f, g, h, i}:
      Bool.and(item.disabled(a), Bool.and(item.disabled(b), Bool.and(item.disabled(c), Bool.and(item.disabled(d), Bool.and(item.disabled(e), Bool.and(item.disabled(f), Bool.and(item.disabled(g), Bool.and(item.disabled(h), item.disabled(i)))))))))

def round.no_items(round: D.RoundRules) -> Bool:
  match round:
    case D.RoundRules{_, _, items}:
      items.disabled(items)

def plan.no_items(plan: D.Plan) -> Bool:
  match plan:
    case D.OneRound{a}:
      round.no_items(a)
    case D.TwoRounds{a, b}:
      Bool.and(round.no_items(a), round.no_items(b))
    case D.ThreeRounds{a, b, c}:
      Bool.and(round.no_items(a), Bool.and(round.no_items(b), round.no_items(c)))

def config.no_items(config: D.Config) -> Bool:
  match config:
    case D.Config{_, plan}:
      plan.no_items(plan)

def round.next(before: Bool, index: Nat) -> Nat:
  match before:
    case True{}:
      0n
    case False{}:
      1n+index

def config.table(config: D.Config) -> D.Table:
  match config:
    case D.Config{table, _}:
      table

def subtract(left: Nat, right: Nat) -> Nat:
  match left right:
    case 0n _:
      0n
    case left 0n:
      left
    case 1n+left 1n+right:
      subtract(left, right)

def captured(sawed: Bool) -> D.Damage:
  match sawed:
    case False{}:
      D.Single{}
    case True{}:
      D.Double{}

def shot.health(shell: D.Shell, hp: Nat, damage: D.Damage) -> Nat:
  match shell:
    case D.Blank{}:
      hp
    case D.Live{}:
      subtract(hp, D.damage.amount(damage))

def shot.passes(shell: D.Shell, same: Bool) -> Bool:
  match shell same:
    case D.Blank{} True{}:
      False{}
    case _ _:
      True{}

def living(entries: List<&2, D.At<&2, Nat>>) -> List<&2, D.Seat>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{seat, 0n} <> rest:
      living(rest)
    case D.At{seat, 1n+hp} <> rest:
      seat <> living(rest)

def winner.only(seats: List<&2, D.Seat>) -> Maybe<&2, D.Seat>:
  match seats:
    case seat <> Nil{}:
      Some{seat}
    case _:
      None{}

def winner(health: D.Ring<&2, Nat>) -> Maybe<&2, D.Seat>:
  winner.only(living(D.ring.entries(Nat, health)))

def current(turn: Maybe<&2, D.Seat>, seat: D.Seat) -> Bool:
  match turn:
    case None{}:
      False{}
    case Some{current}:
      D.seat.eq(current, seat)

def accepted(+state: S.State, +seat: D.Seat) -> Bool:
  Bool.and(current(S.world.turn(S.state.world(state)), seat), value.or(Bool, D.ring.get(Bool, S.players.has_turn(S.state.players(state)), seat), False{}))
