import Base
import ../domain.bend as D
import ./state.bend as S
import ./rules.bend as G

# Item rules of the machine: inventories, distribution pools, and the typed
# option lists of the grab, idle, jammer and adrenaline phases (D22, D37, D55).
# Pure functions over machine state; main.bend sequences them.

def keep(-A: Data, kept: Bool, x: A, rest: List<&2, A>) -> List<&2, A>:
  match kept:
    case True{}:
      x <> rest
    case False{}:
      rest

def is_none(found: Maybe<&2, D.Item>) -> Bool:
  match found:
    case None{}:
      True{}
    case Some{item}:
      False{}

def has_items(xs: List<&2, D.Item>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case x <> rest:
      True{}

def has_seats(xs: List<&2, D.Seat>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case x <> rest:
      True{}

def slot.order() -> List<&2, D.Slot>:
  [D.Slot0{}, D.Slot1{}, D.Slot2{}, D.Slot3{}, D.Slot4{}, D.Slot5{}, D.Slot6{}, D.Slot7{}]

def slots.items(slots: D.Slots) -> List<&2, Maybe<&2, D.Item>>:
  match slots:
    case D.Slots{a, b, c, d, e, f, g, h, _}:
      [a, b, c, d, e, f, g, h]

def slots.put(slots: D.Slots, slot: D.Slot, value: Maybe<&2, D.Item>) -> D.Slots:
  match slots slot:
    case D.Slots{a, b, c, d, e, f, g, h, bx} D.Slot0{}:
      D.Slots{value, b, c, d, e, f, g, h, D.Boxed{}}
    case D.Slots{a, b, c, d, e, f, g, h, bx} D.Slot1{}:
      D.Slots{a, value, c, d, e, f, g, h, D.Boxed{}}
    case D.Slots{a, b, c, d, e, f, g, h, bx} D.Slot2{}:
      D.Slots{a, b, value, d, e, f, g, h, D.Boxed{}}
    case D.Slots{a, b, c, d, e, f, g, h, bx} D.Slot3{}:
      D.Slots{a, b, c, value, e, f, g, h, D.Boxed{}}
    case D.Slots{a, b, c, d, e, f, g, h, bx} D.Slot4{}:
      D.Slots{a, b, c, d, value, f, g, h, D.Boxed{}}
    case D.Slots{a, b, c, d, e, f, g, h, bx} D.Slot5{}:
      D.Slots{a, b, c, d, e, value, g, h, D.Boxed{}}
    case D.Slots{a, b, c, d, e, f, g, h, bx} D.Slot6{}:
      D.Slots{a, b, c, d, e, f, value, h, D.Boxed{}}
    case D.Slots{a, b, c, d, e, f, g, h, bx} D.Slot7{}:
      D.Slots{a, b, c, d, e, f, g, value, D.Boxed{}}

def occupied(xs: List<&2, Maybe<&2, D.Item>>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case None{} <> rest:
      occupied(rest)
    case Some{item} <> rest:
      1n+occupied(rest)

def bool.nat(b: Bool) -> Nat:
  match b:
    case True{}:
      1n
    case False{}:
      0n

def copies.one(found: Maybe<&2, D.Item>, +item: D.Item) -> Nat:
  match found:
    case None{}:
      0n
    case Some{actual}:
      bool.nat(D.item.eq(actual, item))

def copies(xs: List<&2, Maybe<&2, D.Item>>, +item: D.Item) -> Nat:
  match xs:
    case Nil{}:
      0n
    case x <> rest:
      Nat.add(copies.one(x, item), copies(rest, item))

# copies(slots.items(slots), item) without building the list.
def slots.copies(slots: D.Slots, +item: D.Item) -> Nat:
  match slots:
    case D.Slots{a, b, c, d, e, f, g, h, _}:
      Nat.add(copies.one(a, item), Nat.add(copies.one(b, item), Nat.add(copies.one(c, item), Nat.add(copies.one(d, item), Nat.add(copies.one(e, item), Nat.add(copies.one(f, item), Nat.add(copies.one(g, item), Nat.add(copies.one(h, item), 0n))))))))

# Per-seat reads. A seat missing from a ring reads as the initial value.

def seat.health(+players: S.Players, seat: D.Seat) -> Nat:
  G.value.or(Nat, D.ring.get(Nat, S.players.health(players), seat), 100n)

def seat.slots(+players: S.Players, seat: D.Seat) -> D.Slots:
  G.value.or(D.Slots, D.ring.get(D.Slots, S.players.slots(players), seat), D.slots.empty())

def seat.jammed(+players: S.Players, seat: D.Seat) -> Bool:
  S.jam.jammed(G.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(players), seat), S.Free{}))

def seat.grabbing(+grabs: S.Grabs, seat: D.Seat) -> Bool:
  G.value.or(Bool, D.ring.get(Bool, S.grabs.grabbing(grabs), seat), False{})

def seat.holding(+grabs: S.Grabs, seat: D.Seat) -> Maybe<&2, D.Item>:
  G.value.or(Maybe<&2, D.Item>, D.ring.get(Maybe<&2, D.Item>, S.grabs.holding(grabs), seat), None{})

def seat.granted(+grabs: S.Grabs, seat: D.Seat) -> Nat:
  G.value.or(Nat, D.ring.get(Nat, S.grabs.granted(grabs), seat), 0n)

def seat.intake(+grabs: S.Grabs, seat: D.Seat) -> Bool:
  G.value.or(Bool, D.ring.get(Bool, S.grabs.intake(grabs), seat), False{})

# Distribution flag writes, one per rule effect.

def grabs.open(grabs: S.Grabs, +seat: D.Seat) -> S.Grabs:
  match grabs:
    case S.Grabs{distributing, grabbing, holding, granted, intake}:
      S.Grabs{distributing, D.ring.set(Bool, grabbing, seat, True{}), D.ring.set(Maybe<&2, D.Item>, holding, seat, None{}), D.ring.set(Nat, granted, seat, 0n), D.ring.set(Bool, intake, seat, True{})}

def grabs.open_all(seats: List<&2, D.Seat>, grabs: S.Grabs) -> S.Grabs:
  match seats:
    case Nil{}:
      grabs
    case seat <> rest:
      grabs.open_all(rest, grabs.open(grabs, seat))

def grabs.stop_intake(grabs: S.Grabs, seat: D.Seat) -> S.Grabs:
  match grabs:
    case S.Grabs{distributing, grabbing, holding, granted, intake}:
      S.Grabs{distributing, grabbing, holding, granted, D.ring.set(Bool, intake, seat, False{})}

def grabs.give(+grabs: S.Grabs, +seat: D.Seat, item: D.Item) -> S.Grabs:
  match grabs:
    case S.Grabs{distributing, grabbing, holding, granted, intake}:
      S.Grabs{distributing, grabbing, D.ring.set(Maybe<&2, D.Item>, holding, seat, Some{item}), D.ring.set(Nat, granted, seat, 1n+seat.granted(grabs, seat)), D.ring.set(Bool, intake, seat, False{})}

def grabs.close(grabs: S.Grabs, seat: D.Seat) -> S.Grabs:
  match grabs:
    case S.Grabs{distributing, grabbing, holding, granted, intake}:
      S.Grabs{distributing, D.ring.set(Bool, grabbing, seat, False{}), holding, granted, intake}

# A placed item leaves the hand; intake reopens only while still grabbing.
def grabs.placed(+grabs: S.Grabs, +seat: D.Seat) -> S.Grabs:
  match grabs:
    case S.Grabs{distributing, grabbing, holding, granted, intake}:
      S.Grabs{distributing, grabbing, D.ring.set(Maybe<&2, D.Item>, holding, seat, None{}), granted, D.ring.set(Bool, intake, seat, seat.grabbing(grabs, seat))}

# Pools (D22). Held items count against both caps. The order is item.order().

# slots.copies(seat.slots(players, seat), item), read in place.
def seat.copies(+players: S.Players, +seat: D.Seat, +item: D.Item) -> Nat:
  match players seat:
    case D.Duo{S.Seat{_, _, _, a}, _} D.Seat1{}:
      slots.copies(a, item)
    case D.Duo{_, S.Seat{_, _, _, a}} D.Seat3{}:
      slots.copies(a, item)
    case D.Trio{S.Seat{_, _, _, a}, _, _} D.Seat0{}:
      slots.copies(a, item)
    case D.Trio{_, S.Seat{_, _, _, a}, _} D.Seat1{}:
      slots.copies(a, item)
    case D.Trio{_, _, S.Seat{_, _, _, a}} D.Seat2{}:
      slots.copies(a, item)
    case D.Quad{S.Seat{_, _, _, a}, _, _, _} D.Seat0{}:
      slots.copies(a, item)
    case D.Quad{_, S.Seat{_, _, _, a}, _, _} D.Seat1{}:
      slots.copies(a, item)
    case D.Quad{_, _, S.Seat{_, _, _, a}, _} D.Seat2{}:
      slots.copies(a, item)
    case D.Quad{_, _, _, S.Seat{_, _, _, a}} D.Seat3{}:
      slots.copies(a, item)
    case _ _:
      0n

def owned(+players: S.Players, +grabs: S.Grabs, +seat: D.Seat, +item: D.Item) -> Nat:
  Nat.add(seat.copies(players, seat, item), copies.one(seat.holding(grabs, seat), item))

def owned.table(seats: List<&2, D.Seat>, +players: S.Players, +grabs: S.Grabs, +item: D.Item) -> Nat:
  match seats:
    case Nil{}:
      0n
    case seat <> rest:
      Nat.add(owned(players, grabs, seat, item), owned.table(rest, players, grabs, item))

def stock.open(rule: D.ItemRule, dealt: Bool, own: Nat, total: Nat) -> Bool:
  match rule:
    case D.ItemRule{enabled, per_player, on_table}:
      Bool.and(enabled, Bool.and(dealt, Bool.and(Nat.is_lt(own, per_player), Nat.is_lt(total, on_table))))

def round.items(round: D.RoundRules) -> D.ItemRules:
  match round:
    case D.RoundRules{_, _, items, _}:
      items

# stock.open, reading the counts only for an enabled, dealt item, and the
# table's count only while the seat's own count is under its cap.
def stock.total(own_open: Bool, +total: Nat, +on_table: Nat) -> Bool:
  match own_open:
    case True{}:
      Nat.is_lt(total, on_table)
    case False{}:
      False{}

def stock.counted(rule: D.ItemRule, dealt: Bool, +players: S.Players, +grabs: S.Grabs, +seat: D.Seat, +item: D.Item, seats: List<&2, D.Seat>) -> Bool:
  match rule dealt:
    case D.ItemRule{True{}, per_player, on_table} True{}:
      stock.total(Nat.is_lt(owned(players, grabs, seat, item), per_player), owned.table(seats, players, grabs, item), on_table)
    case _ _:
      False{}

def pool.go(items: List<&2, D.Item>, +rules: D.ItemRules, +table: D.Table, +players: S.Players, +grabs: S.Grabs, +seat: D.Seat) -> List<&2, D.Item>:
  match items:
    case Nil{}:
      Nil{}
    case +item <> rest:
      keep(D.Item, stock.counted(D.rules.item(rules, item), D.item.dealt_at(table, item), players, grabs, seat, item, D.table.seats(table)), item, pool.go(rest, rules, table, players, grabs, seat))

def pool(+state: S.State, +seat: D.Seat) -> List<&2, D.Item>:
  +world : S.World = S.state.world(state)
  pool.go(D.item.order(), round.items(G.world.rules(world)), S.world.table(world), S.state.players(state), S.state.grabs(state), seat)

# Whether a seat's pool has an item; stops once one is found.
def pool.any(items: List<&2, D.Item>, found: Bool, +rules: D.ItemRules, +table: D.Table, +players: S.Players, +grabs: S.Grabs, +seat: D.Seat) -> Bool:
  match items found:
    case _ True{}:
      True{}
    case Nil{} False{}:
      False{}
    case +item <> rest False{}:
      pool.any(rest, stock.counted(D.rules.item(rules, item), D.item.dealt_at(table, item), players, grabs, seat, item, D.table.seats(table)), rules, table, players, grabs, seat)

def stocked(+state: S.State, +seat: D.Seat) -> Bool:
  +world : S.World = S.state.world(state)
  pool.any(D.item.order(), False{}, round.items(G.world.rules(world)), S.world.table(world), S.state.players(state), S.state.grabs(state), seat)

# Who begins grabbing. A new round ignores health and full slots (D46); the
# caller passes the stored amount, whose zero selects no one (D12).

def begin.can(new_round: Bool, hp: Nat, slots: D.Slots) -> Bool:
  Bool.or(new_round, Bool.and(G.alive(hp), Nat.is_lt(occupied(slots.items(slots)), 8n)))

def begin.go(seats: List<&2, D.Seat>, +state: S.State, +new_round: Bool) -> List<&2, D.Seat>:
  match seats:
    case Nil{}:
      Nil{}
    case +seat <> rest:
      +players : S.Players = S.state.players(state)
      keep(D.Seat, Bool.and(begin.can(new_round, seat.health(players, seat), seat.slots(players, seat)), stocked(state, seat)), seat, begin.go(rest, state, new_round))

def begin.seats(+state: S.State, new_round: Bool, amount: Nat) -> List<&2, D.Seat>:
  match amount:
    case 0n:
      Nil{}
    case _:
      begin.go(D.table.seats(S.world.table(S.state.world(state))), state, new_round)

# Grab phase options (D37 grabbing rows). After completion latches, intake is
# closed for everyone and only holders may still place (D56).

def puts.here(found: Maybe<&2, D.Item>, slot: D.Slot, rest: List<&2, S.GrabOption>) -> List<&2, S.GrabOption>:
  match found:
    case None{}:
      S.PutAt{slot} <> rest
    case Some{item}:
      rest

def puts(slots: List<&2, D.Slot>, +inventory: D.Slots) -> List<&2, S.GrabOption>:
  match slots:
    case Nil{}:
      Nil{}
    case +slot <> rest:
      puts.here(D.slots.get(inventory, slot), slot, puts(rest, inventory))

def grab.intake(open: Bool) -> List<&2, S.GrabOption>:
  match open:
    case True{}:
      [S.TakeItem{}]
    case False{}:
      Nil{}

def grab.offer(grabbing: Bool, holding: Maybe<&2, D.Item>, open: Bool, slots: D.Slots) -> List<&2, S.GrabOption>:
  match grabbing holding:
    case True{} Some{item}:
      puts(slot.order(), slots)
    case True{} None{}:
      grab.intake(open)
    case False{} _:
      Nil{}

def grab.needs.go(seats: List<&2, D.Seat>, +players: S.Players, +grabs: S.Grabs, needs: D.Ring<&2, List<&2, S.GrabOption>>) -> D.Ring<&2, List<&2, S.GrabOption>>:
  match seats:
    case Nil{}:
      needs
    case +seat <> rest:
      grab.needs.go(rest, players, grabs, D.ring.set(List<&2, S.GrabOption>, needs, seat, grab.offer(seat.grabbing(grabs, seat), seat.holding(grabs, seat), Bool.and(seat.intake(grabs, seat), S.grabs.distributing(grabs)), seat.slots(players, seat))))

def grab.needs(+state: S.State) -> D.Ring<&2, List<&2, S.GrabOption>>:
  +table : D.Table = S.world.table(S.state.world(state))
  grab.needs.go(D.table.seats(table), S.state.players(state), S.state.grabs(state), D.ring.fill(List<&2, S.GrabOption>, table, Nil{}))

def grab.moves(options: List<&2, S.GrabOption>) -> List<&2, D.Move>:
  match options:
    case Nil{}:
      Nil{}
    case S.TakeItem{} <> rest:
      D.Grab{} <> grab.moves(rest)
    case S.PutAt{slot} <> rest:
      D.Place{slot} <> grab.moves(rest)

def grab.menus(needs: D.Ring<&2, List<&2, S.GrabOption>>) -> D.Ring<&2, List<&2, D.Move>>:
  match needs:
    case D.Duo{a, b}:
      D.Duo{grab.moves(a), grab.moves(b)}
    case D.Trio{a, b, c}:
      D.Trio{grab.moves(a), grab.moves(b), grab.moves(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{grab.moves(a), grab.moves(b), grab.moves(c), grab.moves(d)}

def grab.nth(options: List<&2, S.GrabOption>, n: Nat) -> Maybe<&2, S.GrabOption>:
  match options n:
    case Nil{} _:
      None{}
    case option <> rest 0n:
      Some{option}
    case option <> rest 1n+n:
      grab.nth(rest, n)

# IsPlacingLastItem: the placing seat still holds its item here.
def placing.last(+state: S.State, +seat: D.Seat) -> Bool:
  +grabs : S.Grabs = S.state.grabs(state)
  Bool.or(Bool.not(stocked(state, seat)), Bool.or(Nat.is_eq(1n+occupied(slots.items(seat.slots(S.state.players(state), seat))), 8n), Bool.not(Nat.is_lt(seat.granted(grabs, seat), S.world.item_amount(S.state.world(state))))))

def finish.ended(entries: List<&2, D.At<&2, Bool>>) -> Bool:
  match entries:
    case Nil{}:
      True{}
    case D.At{seat, grabbing} <> rest:
      Bool.and(Bool.not(grabbing), finish.ended(rest))

def finish.empty(seats: List<&2, D.Seat>, +state: S.State) -> Bool:
  match seats:
    case Nil{}:
      True{}
    case seat <> rest:
      Bool.and(Bool.not(stocked(state, seat)), finish.empty(rest, state))

# Godot's completion predicate, unchanged: every seat stopped grabbing, or
# every seat's pool is empty. M1 re-runs it after the noneligible pass.
def finished(+state: S.State) -> Bool:
  Bool.or(finish.ended(D.ring.entries(Bool, S.grabs.grabbing(S.state.grabs(state)))), finish.empty(D.table.seats(S.world.table(S.state.world(state))), state))

# Empty-handed grabbers with an empty pool, other than the placing seat.
# Holders never qualify, even with an empty pool (M1).
def stalled(seats: List<&2, D.Seat>, +state: S.State, +placing: D.Seat) -> List<&2, D.Seat>:
  match seats:
    case Nil{}:
      Nil{}
    case +seat <> rest:
      +grabs : S.Grabs = S.state.grabs(state)
      keep(D.Seat, Bool.and(seat.grabbing(grabs, seat), Bool.and(is_none(seat.holding(grabs, seat)), Bool.and(Bool.not(D.seat.eq(seat, placing)), Bool.not(stocked(state, seat))))), seat, stalled(rest, state, placing))

def stalled.seats(+state: S.State, +placing: D.Seat) -> List<&2, D.Seat>:
  stalled(D.table.seats(S.world.table(S.state.world(state))), state, placing)

def holders(entries: List<&2, D.At<&2, Maybe<&2, D.Item>>>) -> Bool:
  match entries:
    case Nil{}:
      False{}
    case D.At{seat, None{}} <> rest:
      holders(rest)
    case D.At{seat, Some{item}} <> rest:
      True{}

def briefcase(grabbing: Bool, holding: Maybe<&2, D.Item>) -> D.Briefcase:
  match grabbing holding:
    case False{} _:
      D.NotGrabbing{}
    case True{} None{}:
      D.Grabbing{}
    case True{} Some{item}:
      D.Holding{item}

# The end-of-turn amount draw is live while distributing, or when an
# exhausted, winnerless gun would start a distribution (D12).
def amount.live(rule: D.AmountRule, distributing: Bool, reload: Bool) -> Bool:
  match rule:
    case D.RandomAmount{}:
      Bool.or(distributing, reload)
    case D.FixedAmount{amount}:
      False{}

def winnerless(winner: Maybe<&2, D.Seat>) -> Bool:
  match winner:
    case None{}:
      True{}
    case Some{seat}:
      False{}

def gun.empty(gun: List<&2, D.Shell>) -> Bool:
  match gun:
    case Nil{}:
      True{}
    case shell <> rest:
      False{}

# Strict Bool.and would ask begin.seats on every loaded gun; a loaded gun
# answers alone.
def reload.ready(gun: List<&2, D.Shell>, +state: S.State, winner: Maybe<&2, D.Seat>) -> Bool:
  match gun:
    case Nil{}:
      Bool.and(winnerless(winner), has_seats(begin.seats(state, False{}, 1n)))
    case _ <> _:
      False{}

def reload.wanted(+state: S.State, winner: Maybe<&2, D.Seat>) -> Bool:
  reload.ready(S.world.gun(S.state.world(state)), state, winner)

# Jammer targets (D37): living, unjammed seats other than the user.

def jam.options(entries: List<&2, D.At<&2, Nat>>, +players: S.Players, +by: D.Seat) -> List<&2, S.JamOption>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+seat, hp} <> rest:
      keep(S.JamOption, Bool.and(Bool.not(D.seat.eq(seat, by)), Bool.and(G.alive(hp), Bool.not(seat.jammed(players, seat)))), S.JamAt{seat}, jam.options(rest, players, by))

def jam.of(+players: S.Players, +by: D.Seat) -> List<&2, S.JamOption>:
  jam.options(D.ring.entries(Nat, S.players.health(players)), players, by)


def jam.for(+state: S.State, +by: D.Seat) -> List<&2, S.JamOption>:
  jam.of(S.state.players(state), by)
def jam.any(options: List<&2, S.JamOption>) -> Bool:
  match options:
    case Nil{}:
      False{}
    case option <> rest:
      True{}

def jam.moves(options: List<&2, S.JamOption>) -> List<&2, D.Move>:
  match options:
    case Nil{}:
      Nil{}
    case S.JamAt{seat} <> rest:
      D.JamTarget{seat} <> jam.moves(rest)

def jam.nth(options: List<&2, S.JamOption>, n: Nat) -> Maybe<&2, S.JamOption>:
  match options n:
    case Nil{} _:
      None{}
    case option <> rest 0n:
      Some{option}
    case option <> rest 1n+n:
      jam.nth(rest, n)

# Stealing mode (D37, D55 M4): adrenaline never, a saw only while the barrel
# is whole, a jammer only if the thief has a target, everything else always.
# Every other seat's occupied slot is a candidate, dead owners included.

def steal.fits(item: D.Item, sawed: Bool, targets: Bool) -> Bool:
  match item:
    case D.Adrenaline{}:
      False{}
    case D.Saw{}:
      Bool.not(sawed)
    case D.Jammer{}:
      targets
    case _:
      True{}

def steal.here(found: Maybe<&2, D.Item>, owner: D.Seat, slot: D.Slot, sawed: Bool, targets: Bool, rest: List<&2, S.StealOption>) -> List<&2, S.StealOption>:
  match found:
    case None{}:
      rest
    case Some{+item}:
      keep(S.StealOption, steal.fits(item, sawed, targets), S.Pick{owner, slot, item}, rest)

def steal.slots(slots: List<&2, D.Slot>, +inventory: D.Slots, +owner: D.Seat, +sawed: Bool, +targets: Bool) -> List<&2, S.StealOption>:
  match slots:
    case Nil{}:
      Nil{}
    case +slot <> rest:
      steal.here(D.slots.get(inventory, slot), owner, slot, sawed, targets, steal.slots(rest, inventory, owner, sawed, targets))

def steal.owner(own: Bool, owner: D.Seat, inventory: D.Slots, sawed: Bool, targets: Bool, rest: List<&2, S.StealOption>) -> List<&2, S.StealOption>:
  match own:
    case True{}:
      rest
    case False{}:
      List.append(&2, S.StealOption, steal.slots(slot.order(), inventory, owner, sawed, targets), rest)

def steal.owners(entries: List<&2, D.At<&2, D.Slots>>, +thief: D.Seat, +sawed: Bool, +targets: Bool) -> List<&2, S.StealOption>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+owner, inventory} <> rest:
      steal.owner(D.seat.eq(owner, thief), owner, inventory, sawed, targets, steal.owners(rest, thief, sawed, targets))

# steal.for, given whether the thief has a jam target.
def steal.with(+players: S.Players, +thief: D.Seat, +sawed: Bool, +targets: Bool) -> List<&2, S.StealOption>:
  steal.owners(D.ring.entries(D.Slots, S.players.slots(players)), thief, sawed, targets)

def steal.for(+state: S.State, +thief: D.Seat) -> List<&2, S.StealOption>:
  +players : S.Players = S.state.players(state)
  steal.with(players, thief, S.world.sawed(S.state.world(state)), jam.any(jam.of(players, thief)))

def steal.any(options: List<&2, S.StealOption>) -> Bool:
  match options:
    case Nil{}:
      False{}
    case option <> rest:
      True{}

def steal.moves(options: List<&2, S.StealOption>) -> List<&2, D.Move>:
  match options:
    case Nil{}:
      Nil{}
    case S.Pick{owner, slot, item} <> rest:
      D.Steal{owner, slot, item} <> steal.moves(rest)

def steal.nth(options: List<&2, S.StealOption>, n: Nat) -> Maybe<&2, S.StealOption>:
  match options n:
    case Nil{} _:
      None{}
    case option <> rest 0n:
      Some{option}
    case option <> rest 1n+n:
      steal.nth(rest, n)

# Ordinary item use (D37 invalid-ID mask with M4's adrenaline rule).

def use.fits(item: D.Item, sawed: Bool, targets: Bool, steals: Bool) -> Bool:
  match item:
    case D.Adrenaline{}:
      steals
    case D.Saw{}:
      Bool.not(sawed)
    case D.Jammer{}:
      targets
    case _:
      True{}

def use.here(found: Maybe<&2, D.Item>, slot: D.Slot, sawed: Bool, targets: Bool, steals: Bool, rest: List<&2, S.IdleOption>) -> List<&2, S.IdleOption>:
  match found:
    case None{}:
      rest
    case Some{+item}:
      keep(S.IdleOption, use.fits(item, sawed, targets, steals), S.UseAt{slot, item}, rest)

def use.slots(slots: List<&2, D.Slot>, +inventory: D.Slots, +sawed: Bool, +targets: Bool, +steals: Bool) -> List<&2, S.IdleOption>:
  match slots:
    case Nil{}:
      Nil{}
    case +slot <> rest:
      use.here(D.slots.get(inventory, slot), slot, sawed, targets, steals, use.slots(rest, inventory, sawed, targets, steals))

# uses, given the seat's jam targets and steals are known to exist or not.
def uses.with(+players: S.Players, +seat: D.Seat, +sawed: Bool, +targets: Bool, +steals: Bool) -> List<&2, S.IdleOption>:
  use.slots(slot.order(), seat.slots(players, seat), sawed, targets, steals)

def uses(+state: S.State, +seat: D.Seat) -> List<&2, S.IdleOption>:
  +players : S.Players = S.state.players(state)
  +sawed : Bool = S.world.sawed(S.state.world(state))
  +targets : Bool = jam.any(jam.of(players, seat))
  uses.with(players, seat, sawed, targets, steal.any(steal.with(players, seat, sawed, targets)))

# Item effect helpers.

def ends_turn(item: D.Item, length: Nat) -> Bool:
  match item:
    case D.Beer{}:
      Nat.is_eq(length, 1n)
    case _:
      False{}

def invert(shell: D.Shell) -> D.Shell:
  match shell:
    case D.Live{}:
      D.Blank{}
    case D.Blank{}:
      D.Live{}

def flip(direction: D.Direction) -> D.Direction:
  match direction:
    case D.Clockwise{}:
      D.CounterClockwise{}
    case D.CounterClockwise{}:
      D.Clockwise{}

# The phone draws a position only with at least four shells (D28).
def phone.request(length: Nat) -> D.Request:
  match length:
    case 1n+1n+1n+1n+extra:
      D.Draw{D.PhoneIndex{}, D.Range{2n, extra}}
    case _:
      D.Stuck{}
