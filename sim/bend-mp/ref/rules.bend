import Base
import ../domain.bend as D
import ./state.bend as S

type RoundSeatWrite is Data:
  DisableJam{}
  RestoreHealth{health: Nat}
  ClearSlots{}


def nth(-A: Data, xs: List<&2, A>, n: Nat) -> Maybe<&2, A>:
  match xs n:
    case Nil{} _:
      None{}
    case x <> rest 0n:
      Some{x}
    case x <> rest 1n+k:
      nth(A, rest, k)

def set(-A: Data, xs: List<&2, A>, n: Nat, value: A) -> List<&2, A>:
  match xs n:
    case Nil{} _:
      Nil{}
    case x <> rest 0n:
      value <> rest
    case x <> rest 1n+k:
      x <> set(A, rest, k, value)

def remove(-A: Data, xs: List<&2, A>, n: Nat) -> List<&2, A>:
  match xs n:
    case Nil{} _:
      Nil{}
    case x <> rest 0n:
      rest
    case x <> rest 1n+k:
      x <> remove(A, rest, k)

def seat.default(found: Maybe<&2, D.Seat>) -> D.Seat:
  match found:
    case Some{s}:
      s
    case None{}:
      D.Seat0{}

def next_index(index: Nat) -> Nat:
  match index:
    case 0n:
      1n
    case 1n:
      2n
    case 2n:
      3n
    case _:
      0n

def next_round(before: Bool, index: Nat) -> Nat:
  match before:
    case True{}:
      0n
    case False{}:
      1n+index

def alive(hp: Nat) -> Bool:
  match hp:
    case 0n:
      False{}
    case _:
      True{}

def turn_ring.put(keep: Bool, seat: D.Seat, rest: List<&2, D.Seat>) -> List<&2, D.Seat>:
  match keep:
    case True{}:
      seat <> rest
    case False{}:
      rest

def after.pick(hit: Bool, next: D.Seat, rest: D.Seat) -> D.Seat:
  match hit:
    case True{}:
      next
    case False{}:
      rest

def health.after(hp: Nat, damage: D.Damage) -> Nat:
  match hp damage:
    case 0n _:
      0n
    case 1n+h D.Single{}:
      h
    case 1n+0n D.Double{}:
      0n
    case 1n+1n+h D.Double{}:
      h

def damage(sawed: Bool) -> D.Damage:
  match sawed:
    case True{}:
      D.Double{}
    case False{}:
      D.Single{}

def shell.live(shell: D.Shell) -> Bool:
  match shell:
    case D.Live{}:
      True{}
    case D.Blank{}:
      False{}

def subtract(a: Nat, b: Nat) -> Nat:
  match a b:
    case 0n _:
      0n
    case a 0n:
      a
    case 1n+a 1n+b:
      subtract(a, b)

def CheckIfUserHasWon.result(xs: List<&2, D.Seat>) -> Maybe<&2, D.Seat>:
  match xs:
    case seat <> Nil{}:
      Some{seat}
    case _:
      None{}

def slots.list(slots: D.Slots) -> List<&2, Maybe<&2, D.Item>>:
  match slots:
    case D.Slots{a, b, c, d, e, f, g, h, _}:
      [a, b, c, d, e, f, g, h]

def item.count.bool(hit: Bool) -> Nat:
  match hit:
    case True{}:
      1n
    case False{}:
      0n

def eligible.rule(rule: D.ItemRule, dealt: Bool, own: Nat, total: Nat) -> Bool:
  match rule:
    case D.ItemRule{enabled, cap, global_cap}:
      Bool.and(enabled, Bool.and(dealt, Bool.and(Nat.is_lt(own, cap), Nat.is_lt(total, global_cap))))

def GetItemToGrab.put(keep: Bool, item: D.Item, rest: List<&2, D.Item>) -> List<&2, D.Item>:
  match keep:
    case True{}:
      item <> rest
    case False{}:
      rest

def nonempty(-A: Data, xs: List<&2, A>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case _:
      True{}

def slots.full(xs: List<&2, Maybe<&2, D.Item>>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case None{} <> rest:
      False{}
    case Some{item} <> rest:
      slots.full(rest)

def replicate(n: Nat, +shell: D.Shell) -> List<&2, D.Shell>:
  match n:
    case 0n:
      Nil{}
    case 1n+k:
      shell <> replicate(k, shell)

def load.custom(rule: D.LoadRule, random: D.Load) -> D.Load:
  match rule:
    case D.LoadRule{D.RandomShells{}, _}:
      random
    case D.LoadRule{D.FixedShells{live, blank}, _}:
      D.Load{live, D.pos.nat(blank)}
    case D.LoadRule{D.AllLive{live}, _}:
      D.Load{D.pos.nat(live), 0n}

def load.amount(rule: D.LoadRule) -> D.AmountRule:
  match rule:
    case D.LoadRule{_, amount}:
      amount

def turn_ring(entries: List<&2, D.At<&2, S.Props>>, +current: D.Seat) -> List<&2, D.Seat>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+seat, props} <> rest:
      turn_ring.put(Bool.or(D.seat.eq(seat, current), alive(S.props.health(props))), seat, turn_ring(rest, current))

def after(xs: List<&2, D.Seat>, +current: D.Seat, +wrap: D.Seat) -> D.Seat:
  match xs:
    case Nil{}:
      wrap
    case +seat <> Nil{}:
      wrap
    case +seat <> +next <> rest:
      after.pick(D.seat.eq(seat, current), next, after(next <> rest, current, wrap))

def shell.health(shell: D.Shell, hp: Nat, damage: D.Damage) -> Nat:
  match shell:
    case D.Live{}:
      health.after(hp, damage)
    case D.Blank{}:
      hp

def living(entries: List<&2, D.At<&2, S.Props>>) -> List<&2, D.Seat>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{seat, props} <> rest:
      turn_ring.put(alive(S.props.health(props)), seat, living(rest))

def item.count.here(slot: Maybe<&2, D.Item>, +item: D.Item) -> Nat:
  match slot:
    case None{}:
      0n
    case Some{actual}:
      item.count.bool(D.item.eq(actual, item))

def props.can_grab(props: S.Props, new_round: Bool) -> Bool:
  match props:
    case S.Props{hp, _, _, _, slots, _, _, _}:
      Bool.or(new_round, Bool.and(alive(hp), Bool.not(slots.full(slots.list(slots)))))

def load.shells(load: D.Load) -> List<&2, D.Shell>:
  match load:
    case D.Load{live, blank}:
      List.append(&2, D.Shell, replicate(live, D.Live{}), replicate(blank, D.Blank{}))

def swap.found(xs: List<&2, D.Shell>, i: Nat, j: Nat, a: Maybe<&2, D.Shell>, b: Maybe<&2, D.Shell>) -> List<&2, D.Shell>:
  match a b:
    case Some{x} Some{y}:
      set(D.Shell, set(D.Shell, xs, i, y), j, x)
    case _ _:
      xs

def traversal(xs: List<&2, D.Seat>, +current: D.Seat) -> D.Seat:
  match xs:
    case Nil{}:
      current
    case +head <> rest:
      after(head <> rest, current, head)

def CheckIfUserHasWon(host: S.Host) -> Maybe<&2, D.Seat>:
  CheckIfUserHasWon.result(living(D.ring.entries(S.Props, S.host.seats(host))))

def item.count(xs: List<&2, Maybe<&2, D.Item>>, +item: D.Item) -> Nat:
  match xs:
    case Nil{}:
      0n
    case slot <> rest:
      Nat.add(item.count.here(slot, item), item.count(rest, item))

def swap(+xs: List<&2, D.Shell>, +i: Nat, +j: Nat) -> List<&2, D.Shell>:
  swap.found(xs, i, j, nth(D.Shell, xs, i), nth(D.Shell, xs, j))

def directed(direction: D.Direction, xs: List<&2, D.Seat>, current: D.Seat) -> D.Seat:
  match direction:
    case D.Clockwise{}:
      traversal(xs, current)
    case D.CounterClockwise{}:
      traversal(List.reverse(&2, D.Seat, xs), current)

def props.item_count(props: S.Props, +item: D.Item) -> Nat:
  match props:
    case S.Props{_, _, _, _, slots, _, holding, _}:
      Nat.add(item.count(slots.list(slots), item), item.count.here(holding, item))

# D45 includes a dead current socket, sorts socket IDs and traverses only
# that socket plus living seats in the current direction.
def GetNextTurn_Socket(+host: S.Host, +current: D.Seat) -> D.Seat:
  directed(S.host.direction(host), turn_ring(D.ring.entries(S.Props, S.host.seats(host)), current), current)

def table.item_count(entries: List<&2, D.At<&2, S.Props>>, +item: D.Item) -> Nat:
  match entries:
    case Nil{}:
      0n
    case D.At{_, props} <> rest:
      Nat.add(props.item_count(props, item), table.item_count(rest, item))

def GetItemToGrab.pool(xs: List<&2, D.Item>, +host: S.Host, +seat: D.Seat) -> List<&2, D.Item>:
  match xs:
    case Nil{}:
      Nil{}
    case +item <> rest:
      GetItemToGrab.put(eligible.rule(D.rules.item(S.rules.items(S.host.rules(host)), item), D.item.dealt_at(S.host.table(host), item), props.item_count(S.host.props(host, seat), item), table.item_count(D.ring.entries(S.Props, S.host.seats(host)), item)), item, GetItemToGrab.pool(rest, host, seat))

def GetSocketsToBeginItemGrabbingOn.go(entries: List<&2, D.At<&2, S.Props>>, +host: S.Host, +new_round: Bool) -> List<&2, D.Seat>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+seat, props} <> rest:
      turn_ring.put(Bool.and(props.can_grab(props, new_round), nonempty(D.Item, GetItemToGrab.pool(D.item.order(), host, seat))), seat, GetSocketsToBeginItemGrabbingOn.go(rest, host, new_round))

# Random reload preflight may use a positive amount probe (D12). Actual
# selection uses the freshly stored amount, including its zero guard.
def GetSocketsToBeginItemGrabbingOn(+host: S.Host, new_round: Bool, amount: Nat) -> List<&2, D.Seat>:
  match amount:
    case 0n:
      Nil{}
    case _:
      GetSocketsToBeginItemGrabbingOn.go(D.ring.entries(S.Props, S.host.seats(host)), host, new_round)

def round_seat_write(props: S.Props, write: RoundSeatWrite) -> S.Props:
  match write:
    case DisableJam{}:
      S.props.unjam(props)
    case RestoreHealth{health}:
      S.props.set_health(props, health)
    case ClearSlots{}:
      S.props.clear_slots(props)

def round_seats(entries: List<&2, D.At<&2, S.Props>>, +write: RoundSeatWrite, seats: D.Ring<&2, S.Props>) -> D.Ring<&2, S.Props>:
  match entries:
    case Nil{}:
      seats
    case D.At{seat, props} <> rest:
      round_seats(rest, write, D.ring.set(S.Props, seats, seat, round_seat_write(props, write)))
