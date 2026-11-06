import Base
import ../domain.bend as D

type Batch is Data:
  Batch{id: Nat, load: D.Load}

type Decks is Data:
  Decks{two: List<&2, Batch>, three: List<&2, Batch>, four: List<&2, Batch>}

type IdleOption is Data:
  TakeGun{}
  UseAt{slot: D.Slot, item: D.Item}

type TargetOption is Data:
  Target{seat: D.Seat}

type GrabOption is Data:
  TakeItem{}
  PutAt{slot: D.Slot}

type JamOption is Data:
  JamAt{seat: D.Seat}

type StealOption is Data:
  Pick{owner: D.Seat, slot: D.Slot, item: D.Item}

type Phase is Data:
  NeedFirst{}
  NeedHealth{}
  NeedAmount{}
  NeedBatch{}
  NeedSwap{load: D.Load, shells: List<&2, D.Shell>, i: Nat}
  Idle{seat: D.Seat, options: D.NonEmpty<&2, IdleOption>}
  Aim{seat: D.Seat}
  Ended{}
  # Stuck. holder is the seat that still held the turn when the machine stuck.
  Blocked{holder: Maybe<&2, D.Seat>}
  NeedTurnAmount{from: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>}
  Grab{needs: D.Ring<&2, List<&2, GrabOption>>}
  NeedItem{seat: D.Seat, first: D.Item, second: D.Item, rest: List<&2, D.Item>}
  NeedPhone{seat: D.Seat, owner: D.Seat, slot: D.Slot}
  JamPick{seat: D.Seat, targets: List<&2, JamOption>}
  StealPick{seat: D.Seat, picks: List<&2, StealOption>}

type World is Data:
  World{config: D.Config, before_round: Bool, round_index: Nat, load_index: Nat, first_sequence: Bool, round_health: Nat, first_turn: D.Seat, turn: Maybe<&2, D.Seat>, direction: D.Direction, first_death: Maybe<&2, D.Seat>, checking_first_death: Bool, item_amount: Nat, sawed: Bool, gun: List<&2, D.Shell>, shown: D.Load, decks: Decks}

# A seat's jammer state. A jammed seat loses its next turn (JammedSkipped
# records that skip) and gets the turn after that, which lifts the jam.
type Jam is Data:
  Free{}
  Jammed{}
  JammedSkipped{}

# One seat's record. cash is the sum of D.prize over the rounds the seat won.
type Seat is Data:
  Seat{health: Nat, jam: Jam, cash: U32, slots: D.Slots}

# One record per seated socket, in the ring of the table.
def Players() -> Data:
  D.Ring<&2, Seat>

# Item distribution flags. A seat's grant count and intake survive the
# distribution that set them, until that seat begins grabbing again.
# Invariant (abstract.bend grab.seat): a holding seat is grabbing with intake
# closed, and a grabbing seat's grants stay within the item amount.
type Grabs is Data:
  Grabs{distributing: Bool, grabbing: D.Ring<&2, Bool>, holding: D.Ring<&2, Maybe<&2, D.Item>>, granted: D.Ring<&2, Nat>, intake: D.Ring<&2, Bool>}

type State is Data:
  State{world: World, players: Players, phase: Phase, notes: List<&2, D.Note>, grabs: Grabs}

def world.before_round(value: World) -> Bool:
  match value:
    case World{_, before_round, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      before_round

def world.set_before_round(value: World, replacement: Bool) -> World:
  match value:
    case World{config, _, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}:
      World{config, replacement, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}

def world.round_index(value: World) -> Nat:
  match value:
    case World{_, _, round_index, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      round_index

def world.set_round_index(value: World, replacement: Nat) -> World:
  match value:
    case World{config, before_round, _, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}:
      World{config, before_round, replacement, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}

def world.load_index(value: World) -> Nat:
  match value:
    case World{_, _, _, load_index, _, _, _, _, _, _, _, _, _, _, _, _}:
      load_index

def world.set_load_index(value: World, replacement: Nat) -> World:
  match value:
    case World{config, before_round, round_index, _, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}:
      World{config, before_round, round_index, replacement, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}

def world.first_sequence(value: World) -> Bool:
  match value:
    case World{_, _, _, _, first_sequence, _, _, _, _, _, _, _, _, _, _, _}:
      first_sequence

def world.set_first_sequence(value: World, replacement: Bool) -> World:
  match value:
    case World{config, before_round, round_index, load_index, _, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}:
      World{config, before_round, round_index, load_index, replacement, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}

def world.round_health(value: World) -> Nat:
  match value:
    case World{_, _, _, _, _, round_health, _, _, _, _, _, _, _, _, _, _}:
      round_health

def world.set_round_health(value: World, replacement: Nat) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, _, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}:
      World{config, before_round, round_index, load_index, first_sequence, replacement, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}

def world.first_turn(value: World) -> D.Seat:
  match value:
    case World{_, _, _, _, _, _, first_turn, _, _, _, _, _, _, _, _, _}:
      first_turn

def world.set_first_turn(value: World, replacement: D.Seat) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, round_health, _, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}:
      World{config, before_round, round_index, load_index, first_sequence, round_health, replacement, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}

def world.turn(value: World) -> Maybe<&2, D.Seat>:
  match value:
    case World{_, _, _, _, _, _, _, turn, _, _, _, _, _, _, _, _}:
      turn

def world.set_turn(value: World, replacement: Maybe<&2, D.Seat>) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, _, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}:
      World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, replacement, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}

def world.direction(value: World) -> D.Direction:
  match value:
    case World{_, _, _, _, _, _, _, _, direction, _, _, _, _, _, _, _}:
      direction

def world.set_direction(value: World, replacement: D.Direction) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, _, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}:
      World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, replacement, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}

def world.first_death(value: World) -> Maybe<&2, D.Seat>:
  match value:
    case World{_, _, _, _, _, _, _, _, _, first_death, _, _, _, _, _, _}:
      first_death

def world.set_first_death(value: World, replacement: Maybe<&2, D.Seat>) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, _, checking_first_death, item_amount, sawed, gun, shown, decks}:
      World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, replacement, checking_first_death, item_amount, sawed, gun, shown, decks}

def world.checking_first_death(value: World) -> Bool:
  match value:
    case World{_, _, _, _, _, _, _, _, _, _, checking_first_death, _, _, _, _, _}:
      checking_first_death

def world.set_checking_first_death(value: World, replacement: Bool) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, _, item_amount, sawed, gun, shown, decks}:
      World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, replacement, item_amount, sawed, gun, shown, decks}

def world.item_amount(value: World) -> Nat:
  match value:
    case World{_, _, _, _, _, _, _, _, _, _, _, item_amount, _, _, _, _}:
      item_amount

def world.set_item_amount(value: World, replacement: Nat) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, _, sawed, gun, shown, decks}:
      World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, replacement, sawed, gun, shown, decks}

def world.sawed(value: World) -> Bool:
  match value:
    case World{_, _, _, _, _, _, _, _, _, _, _, _, sawed, _, _, _}:
      sawed

def world.set_sawed(value: World, replacement: Bool) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, _, gun, shown, decks}:
      World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, replacement, gun, shown, decks}

def world.gun(value: World) -> List<&2, D.Shell>:
  match value:
    case World{_, _, _, _, _, _, _, _, _, _, _, _, _, gun, _, _}:
      gun

def world.set_gun(value: World, replacement: List<&2, D.Shell>) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, _, shown, decks}:
      World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, replacement, shown, decks}

def world.shown(value: World) -> D.Load:
  match value:
    case World{_, _, _, _, _, _, _, _, _, _, _, _, _, _, shown, _}:
      shown

def world.set_shown(value: World, replacement: D.Load) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, _, decks}:
      World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, replacement, decks}

def world.decks(value: World) -> Decks:
  match value:
    case World{_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, decks}:
      decks

def world.set_decks(value: World, replacement: Decks) -> World:
  match value:
    case World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, _}:
      World{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, replacement}

def seat.health(seat: Seat) -> Nat:
  match seat:
    case Seat{value, _, _, _}:
      value

def seat.jam(seat: Seat) -> Jam:
  match seat:
    case Seat{_, value, _, _}:
      value

def seat.cash(seat: Seat) -> U32:
  match seat:
    case Seat{_, _, value, _}:
      value

def seat.slots(seat: Seat) -> D.Slots:
  match seat:
    case Seat{_, _, _, value}:
      value

def players.health(players: Players) -> D.Ring<&2, Nat>:
  match players:
    case D.Duo{a, b}:
      D.Duo{seat.health(a), seat.health(b)}
    case D.Trio{a, b, c}:
      D.Trio{seat.health(a), seat.health(b), seat.health(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.health(a), seat.health(b), seat.health(c), seat.health(d)}

def players.jam(players: Players) -> D.Ring<&2, Jam>:
  match players:
    case D.Duo{a, b}:
      D.Duo{seat.jam(a), seat.jam(b)}
    case D.Trio{a, b, c}:
      D.Trio{seat.jam(a), seat.jam(b), seat.jam(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.jam(a), seat.jam(b), seat.jam(c), seat.jam(d)}

def players.cash(players: Players) -> D.Ring<&2, U32>:
  match players:
    case D.Duo{a, b}:
      D.Duo{seat.cash(a), seat.cash(b)}
    case D.Trio{a, b, c}:
      D.Trio{seat.cash(a), seat.cash(b), seat.cash(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.cash(a), seat.cash(b), seat.cash(c), seat.cash(d)}

def players.slots(players: Players) -> D.Ring<&2, D.Slots>:
  match players:
    case D.Duo{a, b}:
      D.Duo{seat.slots(a), seat.slots(b)}
    case D.Trio{a, b, c}:
      D.Trio{seat.slots(a), seat.slots(b), seat.slots(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.slots(a), seat.slots(b), seat.slots(c), seat.slots(d)}

# A seat missing from the ring reads as a fresh seat.
def seat.found(found: Maybe<&2, Seat>) -> Seat:
  match found:
    case Some{seat}:
      seat
    case None{}:
      Seat{100n, Free{}, 0, D.slots.empty()}

def players.seat(players: Players, seat: D.Seat) -> Seat:
  seat.found(D.ring.get(Seat, players, seat))

def seat.set_health(+seat: Seat, value: Nat) -> Seat:
  Seat{value, seat.jam(seat), seat.cash(seat), seat.slots(seat)}

def players.set_health(+players: Players, +seat: D.Seat, value: Nat) -> Players:
  D.ring.set(Seat, players, seat, seat.set_health(players.seat(players, seat), value))

def seat.set_jam(+seat: Seat, value: Jam) -> Seat:
  Seat{seat.health(seat), value, seat.cash(seat), seat.slots(seat)}

def players.set_jam(+players: Players, +seat: D.Seat, value: Jam) -> Players:
  D.ring.set(Seat, players, seat, seat.set_jam(players.seat(players, seat), value))

def seat.set_cash(+seat: Seat, value: U32) -> Seat:
  Seat{seat.health(seat), seat.jam(seat), value, seat.slots(seat)}

def players.set_cash(+players: Players, +seat: D.Seat, value: U32) -> Players:
  D.ring.set(Seat, players, seat, seat.set_cash(players.seat(players, seat), value))

def seat.set_slots(+seat: Seat, value: D.Slots) -> Seat:
  Seat{seat.health(seat), seat.jam(seat), seat.cash(seat), value}

def players.set_slots(+players: Players, +seat: D.Seat, value: D.Slots) -> Players:
  D.ring.set(Seat, players, seat, seat.set_slots(players.seat(players, seat), value))

# A new round: every seat at the round's health, free, with empty slots.
def seat.reset(seat: Seat, health: Nat) -> Seat:
  Seat{health, Free{}, seat.cash(seat), D.slots.empty()}

def players.reset(players: Players, +health: Nat) -> Players:
  match players:
    case D.Duo{a, b}:
      D.Duo{seat.reset(a, health), seat.reset(b, health)}
    case D.Trio{a, b, c}:
      D.Trio{seat.reset(a, health), seat.reset(b, health), seat.reset(c, health)}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.reset(a, health), seat.reset(b, health), seat.reset(c, health), seat.reset(d, health)}

def state.world(value: State) -> World:
  match value:
    case State{world, _, _, _, _}:
      world

def state.set_world(value: State, replacement: World) -> State:
  match value:
    case State{_, players, phase, notes, grabs}:
      State{replacement, players, phase, notes, grabs}

def state.players(value: State) -> Players:
  match value:
    case State{_, players, _, _, _}:
      players

def state.set_players(value: State, replacement: Players) -> State:
  match value:
    case State{world, _, phase, notes, grabs}:
      State{world, replacement, phase, notes, grabs}

def state.phase(value: State) -> Phase:
  match value:
    case State{_, _, phase, _, _}:
      phase

def state.set_phase(value: State, replacement: Phase) -> State:
  match value:
    case State{world, players, _, notes, grabs}:
      State{world, players, replacement, notes, grabs}

def state.notes(value: State) -> List<&2, D.Note>:
  match value:
    case State{_, _, _, notes, _}:
      notes

def state.set_notes(value: State, replacement: List<&2, D.Note>) -> State:
  match value:
    case State{world, players, phase, _, grabs}:
      State{world, players, phase, replacement, grabs}

def state.grabs(value: State) -> Grabs:
  match value:
    case State{_, _, _, _, grabs}:
      grabs

def state.set_grabs(value: State, replacement: Grabs) -> State:
  match value:
    case State{world, players, phase, notes, _}:
      State{world, players, phase, notes, replacement}

def grabs.distributing(value: Grabs) -> Bool:
  match value:
    case Grabs{distributing, _, _, _, _}:
      distributing

def grabs.set_distributing(value: Grabs, replacement: Bool) -> Grabs:
  match value:
    case Grabs{_, grabbing, holding, granted, intake}:
      Grabs{replacement, grabbing, holding, granted, intake}

def grabs.grabbing(value: Grabs) -> D.Ring<&2, Bool>:
  match value:
    case Grabs{_, grabbing, _, _, _}:
      grabbing

def grabs.holding(value: Grabs) -> D.Ring<&2, Maybe<&2, D.Item>>:
  match value:
    case Grabs{_, _, holding, _, _}:
      holding

def grabs.granted(value: Grabs) -> D.Ring<&2, Nat>:
  match value:
    case Grabs{_, _, _, granted, _}:
      granted

def grabs.intake(value: Grabs) -> D.Ring<&2, Bool>:
  match value:
    case Grabs{_, _, _, _, intake}:
      intake

def world.table(world: World) -> D.Table:
  match world:
    case World{D.Config{table, _}, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      table

def world.plan(world: World) -> D.Plan:
  match world:
    case World{D.Config{_, plan}, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      plan

def decks.get(decks: Decks, table: D.Table) -> List<&2, Batch>:
  match decks table:
    case Decks{a, _, _} D.TwoSeats{}:
      a
    case Decks{_, b, _} D.ThreeSeats{}:
      b
    case Decks{_, _, c} D.FourSeats{}:
      c

def decks.set(decks: Decks, table: D.Table, deck: List<&2, Batch>) -> Decks:
  match decks table:
    case Decks{_, b, c} D.TwoSeats{}:
      Decks{deck, b, c}
    case Decks{a, _, c} D.ThreeSeats{}:
      Decks{a, deck, c}
    case Decks{a, b, _} D.FourSeats{}:
      Decks{a, b, deck}

def world.deck(+world: World) -> List<&2, Batch>:
  decks.get(world.decks(world), world.table(world))

def world.set_deck(+world: World, deck: List<&2, Batch>) -> World:
  world.set_decks(world, decks.set(world.decks(world), world.table(world), deck))

def state.emit(+state: State, event: D.GameEvent) -> State:
  state.set_notes(state, List.append(&2, D.Note, state.notes(state), [D.Shown{event}]))

def state.tell(+state: State, seat: D.Seat, secret: D.Secret) -> State:
  state.set_notes(state, List.append(&2, D.Note, state.notes(state), [D.Told{seat, secret}]))

def state.stepped(+state: State) -> D.Stepped<&2, State>:
  D.Stepped{state, state.notes(state)}

def jam.jammed(jam: Jam) -> Bool:
  match jam:
    case Free{}:
      False{}
    case _:
      True{}

type JamResult is Data:
  Skip{players: Players}
  Lift{players: Players}
  Act{players: Players}
