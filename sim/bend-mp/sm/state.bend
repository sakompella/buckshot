import Base
import ../domain.bend as D

type Batch is Data:
  Batch{id: Nat, load: D.Load}

type Decks is Data:
  Decks{two: List<&2, Batch>, three: List<&2, Batch>, four: List<&2, Batch>}

type IdleOption is Data:
  TakeGun{}

type TargetOption is Data:
  Target{seat: D.Seat}

type Phase is Data:
  NeedFirst{}
  NeedHealth{}
  NeedAmount{}
  NeedBatch{}
  NeedSwap{load: D.Load, shells: List<&2, D.Shell>, i: Nat}
  Idle{seat: D.Seat, options: D.NonEmpty<&2, IdleOption>}
  Aim{seat: D.Seat, targets: List<&2, TargetOption>}
  Ended{}
  Blocked{}

type World is Data:
  World{config: D.Config, before_round: Bool, round_index: Nat, load_index: Nat, first_sequence: Bool, round_health: Nat, first_turn: D.Seat, turn: Maybe<&2, D.Seat>, direction: D.Direction, first_death: Maybe<&2, D.Seat>, checking_first_death: Bool, item_amount: Nat, sawed: Bool, gun: List<&2, D.Shell>, shown: D.Load, decks: Decks}

type Players is Data:
  Players{health: D.Ring<&2, Nat>, jammed: D.Ring<&2, Bool>, checked: D.Ring<&2, Bool>, cash: D.Ring<&2, U32>, slots: D.Ring<&2, D.Slots>, has_turn: D.Ring<&2, Bool>}

type State is Data:
  State{world: World, players: Players, phase: Phase, notes: List<&2, D.Note>}

def world.config(value: World) -> D.Config:
  match value:
    case World{config, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      config

def world.set_config(value: World, replacement: D.Config) -> World:
  match value:
    case World{_, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}:
      World{replacement, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, sawed, gun, shown, decks}

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

def players.health(value: Players) -> D.Ring<&2, Nat>:
  match value:
    case Players{health, _, _, _, _, _}:
      health

def players.set_health(value: Players, replacement: D.Ring<&2, Nat>) -> Players:
  match value:
    case Players{_, jammed, checked, cash, slots, has_turn}:
      Players{replacement, jammed, checked, cash, slots, has_turn}

def players.jammed(value: Players) -> D.Ring<&2, Bool>:
  match value:
    case Players{_, jammed, _, _, _, _}:
      jammed

def players.set_jammed(value: Players, replacement: D.Ring<&2, Bool>) -> Players:
  match value:
    case Players{health, _, checked, cash, slots, has_turn}:
      Players{health, replacement, checked, cash, slots, has_turn}

def players.checked(value: Players) -> D.Ring<&2, Bool>:
  match value:
    case Players{_, _, checked, _, _, _}:
      checked

def players.set_checked(value: Players, replacement: D.Ring<&2, Bool>) -> Players:
  match value:
    case Players{health, jammed, _, cash, slots, has_turn}:
      Players{health, jammed, replacement, cash, slots, has_turn}

def players.cash(value: Players) -> D.Ring<&2, U32>:
  match value:
    case Players{_, _, _, cash, _, _}:
      cash

def players.set_cash(value: Players, replacement: D.Ring<&2, U32>) -> Players:
  match value:
    case Players{health, jammed, checked, _, slots, has_turn}:
      Players{health, jammed, checked, replacement, slots, has_turn}

def players.slots(value: Players) -> D.Ring<&2, D.Slots>:
  match value:
    case Players{_, _, _, _, slots, _}:
      slots

def players.set_slots(value: Players, replacement: D.Ring<&2, D.Slots>) -> Players:
  match value:
    case Players{health, jammed, checked, cash, _, has_turn}:
      Players{health, jammed, checked, cash, replacement, has_turn}

def players.has_turn(value: Players) -> D.Ring<&2, Bool>:
  match value:
    case Players{_, _, _, _, _, has_turn}:
      has_turn

def players.set_has_turn(value: Players, replacement: D.Ring<&2, Bool>) -> Players:
  match value:
    case Players{health, jammed, checked, cash, slots, _}:
      Players{health, jammed, checked, cash, slots, replacement}

def state.world(value: State) -> World:
  match value:
    case State{world, _, _, _}:
      world

def state.set_world(value: State, replacement: World) -> State:
  match value:
    case State{_, players, phase, notes}:
      State{replacement, players, phase, notes}

def state.players(value: State) -> Players:
  match value:
    case State{_, players, _, _}:
      players

def state.set_players(value: State, replacement: Players) -> State:
  match value:
    case State{world, _, phase, notes}:
      State{world, replacement, phase, notes}

def state.phase(value: State) -> Phase:
  match value:
    case State{_, _, phase, _}:
      phase

def state.set_phase(value: State, replacement: Phase) -> State:
  match value:
    case State{world, players, _, notes}:
      State{world, players, replacement, notes}

def state.notes(value: State) -> List<&2, D.Note>:
  match value:
    case State{_, _, _, notes}:
      notes

def state.set_notes(value: State, replacement: List<&2, D.Note>) -> State:
  match value:
    case State{world, players, phase, _}:
      State{world, players, phase, replacement}

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

def state.emit(state: State, event: D.GameEvent) -> State:
  match state:
    case State{world, players, phase, notes}:
      State{world, players, phase, List.append(&2, D.Note, notes, [D.Shown{event}])}

def state.stepped(+state: State) -> D.Stepped<&2, State>:
  D.Stepped{state, state.notes(state)}

type JamResult is Data:
  Skip{players: Players}
  Lift{players: Players}
  Act{players: Players}
