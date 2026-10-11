import Base
import ../domain.bend as D

type Props is Data:
  Props{health: Nat, jammed: Bool, jam_checked: Bool, cash: U32, slots: D.Slots, grabbing: Bool, holding: Maybe<&2, D.Item>, has_turn: Bool}

type Batch is Data:
  Batch{id: Nat, load: D.Load}

# Resource identities survive equal compositions and round changes (D14, D21).
type Decks is Data:
  Decks{two: List<&2, Batch>, three: List<&2, Batch>, four: List<&2, Batch>}

type Host is Data:
  Host{config: D.Config, before_round: Bool, round_index: Nat, load_index: Nat, first_sequence: Bool, round_health: Nat, first_turn: D.Seat, turn: Maybe<&2, D.Seat>, direction: D.Direction, first_death: Maybe<&2, D.Seat>, checking_first_death: Bool, item_amount: Nat, distributing: Bool, sawed: Bool, gun: List<&2, D.Shell>, shown: D.Load, decks: Decks, seats: D.Ring<&2, Props>}

def host.before_round(host: Host) -> Bool:
  match host:
    case Host{_, before_round, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      before_round

def host.set_before_round(host: Host, value: Bool) -> Host:
  match host:
    case Host{config, _, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}:
      Host{config, value, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}

def host.round_index(host: Host) -> Nat:
  match host:
    case Host{_, _, round_index, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      round_index

def host.set_round_index(host: Host, value: Nat) -> Host:
  match host:
    case Host{config, before_round, _, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}:
      Host{config, before_round, value, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}

def host.load_index(host: Host) -> Nat:
  match host:
    case Host{_, _, _, load_index, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      load_index

def host.set_load_index(host: Host, value: Nat) -> Host:
  match host:
    case Host{config, before_round, round_index, _, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}:
      Host{config, before_round, round_index, value, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}

def host.first_sequence(host: Host) -> Bool:
  match host:
    case Host{_, _, _, _, first_sequence, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      first_sequence

def host.set_first_sequence(host: Host, value: Bool) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, _, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, value, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}

def host.round_health(host: Host) -> Nat:
  match host:
    case Host{_, _, _, _, _, round_health, _, _, _, _, _, _, _, _, _, _, _, _}:
      round_health

def host.set_round_health(host: Host, value: Nat) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, _, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, value, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}

def host.first_turn(host: Host) -> D.Seat:
  match host:
    case Host{_, _, _, _, _, _, first_turn, _, _, _, _, _, _, _, _, _, _, _}:
      first_turn

def host.set_first_turn(host: Host, value: D.Seat) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, _, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, value, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}

def host.turn(host: Host) -> Maybe<&2, D.Seat>:
  match host:
    case Host{_, _, _, _, _, _, _, turn, _, _, _, _, _, _, _, _, _, _}:
      turn

def host.set_turn(host: Host, value: Maybe<&2, D.Seat>) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, _, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, value, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}

def host.direction(host: Host) -> D.Direction:
  match host:
    case Host{_, _, _, _, _, _, _, _, direction, _, _, _, _, _, _, _, _, _}:
      direction

def host.set_direction(host: Host, value: D.Direction) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, _, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, value, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}

def host.first_death(host: Host) -> Maybe<&2, D.Seat>:
  match host:
    case Host{_, _, _, _, _, _, _, _, _, first_death, _, _, _, _, _, _, _, _}:
      first_death

def host.set_first_death(host: Host, value: Maybe<&2, D.Seat>) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, _, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, value, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, seats}

def host.checking_first_death(host: Host) -> Bool:
  match host:
    case Host{_, _, _, _, _, _, _, _, _, _, checking_first_death, _, _, _, _, _, _, _}:
      checking_first_death

def host.set_checking_first_death(host: Host, value: Bool) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, _, item_amount, distributing, sawed, gun, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, value, item_amount, distributing, sawed, gun, shown, decks, seats}

def host.item_amount(host: Host) -> Nat:
  match host:
    case Host{_, _, _, _, _, _, _, _, _, _, _, item_amount, _, _, _, _, _, _}:
      item_amount

def host.set_item_amount(host: Host, value: Nat) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, _, distributing, sawed, gun, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, value, distributing, sawed, gun, shown, decks, seats}

def host.distributing(host: Host) -> Bool:
  match host:
    case Host{_, _, _, _, _, _, _, _, _, _, _, _, distributing, _, _, _, _, _}:
      distributing

def host.set_distributing(host: Host, value: Bool) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, _, sawed, gun, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, value, sawed, gun, shown, decks, seats}

def host.sawed(host: Host) -> Bool:
  match host:
    case Host{_, _, _, _, _, _, _, _, _, _, _, _, _, sawed, _, _, _, _}:
      sawed

def host.set_sawed(host: Host, value: Bool) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, _, gun, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, value, gun, shown, decks, seats}

def host.gun(host: Host) -> List<&2, D.Shell>:
  match host:
    case Host{_, _, _, _, _, _, _, _, _, _, _, _, _, _, gun, _, _, _}:
      gun

def host.set_gun(host: Host, value: List<&2, D.Shell>) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, _, shown, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, value, shown, decks, seats}

def host.shown(host: Host) -> D.Load:
  match host:
    case Host{_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, shown, _, _}:
      shown

def host.set_shown(host: Host, value: D.Load) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, _, decks, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, value, decks, seats}

def host.decks(host: Host) -> Decks:
  match host:
    case Host{_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, decks, _}:
      decks

def host.set_decks(host: Host, value: Decks) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, _, seats}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, value, seats}

def host.seats(host: Host) -> D.Ring<&2, Props>:
  match host:
    case Host{_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, seats}:
      seats

def host.set_seats(host: Host, value: D.Ring<&2, Props>) -> Host:
  match host:
    case Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, _}:
      Host{config, before_round, round_index, load_index, first_sequence, round_health, first_turn, turn, direction, first_death, checking_first_death, item_amount, distributing, sawed, gun, shown, decks, value}

def props.initial() -> Props:
  Props{100n, False{}, False{}, 0, D.slots.empty(), False{}, None{}, False{}}

def props.health(props: Props) -> Nat:
  match props:
    case Props{health, _, _, _, _, _, _, _}:
      health

def props.set_health(props: Props, health: Nat) -> Props:
  match props:
    case Props{_, jam, checked, cash, slots, grab, holding, turn}:
      Props{health, jam, checked, cash, slots, grab, holding, turn}

def props.set_turn(props: Props, turn: Bool) -> Props:
  match props:
    case Props{hp, jam, checked, cash, slots, grab, holding, _}:
      Props{hp, jam, checked, cash, slots, grab, holding, turn}

def props.grab(props: Props) -> Props:
  match props:
    case Props{hp, jam, checked, cash, slots, _, _, turn}:
      Props{hp, jam, checked, cash, slots, True{}, None{}, turn}

def props.award(props: Props, prize: U32) -> Props:
  match props:
    case Props{hp, jam, checked, cash, slots, grab, holding, turn}:
      Props{hp, jam, checked, U32.add(cash, prize), slots, grab, holding, turn}

def host.table(host: Host) -> D.Table:
  match host:
    case Host{D.Config{table, _}, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      table

def host.plan(host: Host) -> D.Plan:
  match host:
    case Host{D.Config{_, plan}, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      plan

def rules.found(found: Maybe<&2, D.RoundRules>) -> D.RoundRules:
  match found:
    case Some{rules}:
      rules
    case None{}:
      D.config.default_round()

def host.rules(+host: Host) -> D.RoundRules:
  rules.found(D.plan.round(host.plan(host), host.round_index(host)))

def rules.health(rules: D.RoundRules) -> D.HealthRule:
  match rules:
    case D.RoundRules{health, _, _}:
      health

def rules.items(rules: D.RoundRules) -> D.ItemRules:
  match rules:
    case D.RoundRules{_, _, items}:
      items

def rules.load(rules: D.RoundRules, index: Nat) -> D.LoadRule:
  match rules index:
    case D.RoundRules{_, D.LoadRules{a, b, c, d}, _} 0n:
      a
    case D.RoundRules{_, D.LoadRules{a, b, c, d}, _} 1n:
      b
    case D.RoundRules{_, D.LoadRules{a, b, c, d}, _} 2n:
      c
    case D.RoundRules{_, D.LoadRules{a, b, c, d}, _} _:
      d

def host.load_rule(+host: Host) -> D.LoadRule:
  rules.load(host.rules(host), host.load_index(host))

def host.props.found(found: Maybe<&2, Props>) -> Props:
  match found:
    case Some{props}:
      props
    case None{}:
      props.initial()

def host.props(host: Host, seat: D.Seat) -> Props:
  host.props.found(D.ring.get(Props, host.seats(host), seat))

def host.set_props(+host: Host, seat: D.Seat, props: Props) -> Host:
  host.set_seats(host, D.ring.set(Props, host.seats(host), seat, props))

def batches(xs: List<&2, D.Load>, +index: Nat) -> List<&2, Batch>:
  match xs:
    case Nil{}:
      Nil{}
    case load <> rest:
      Batch{index, load} <> batches(rest, 1n+index)

def MakeSequenceCopies() -> Decks:
  Decks{batches(D.table.deck(D.TwoSeats{}), 0n), batches(D.table.deck(D.ThreeSeats{}), 0n), batches(D.table.deck(D.FourSeats{}), 0n)}

def GetSelectedSequenceCopy(decks: Decks, table: D.Table) -> List<&2, Batch>:
  match decks table:
    case Decks{a, b, c} D.TwoSeats{}:
      a
    case Decks{a, b, c} D.ThreeSeats{}:
      b
    case Decks{a, b, c} D.FourSeats{}:
      c

def decks.set(decks: Decks, table: D.Table, deck: List<&2, Batch>) -> Decks:
  match decks table:
    case Decks{a, b, c} D.TwoSeats{}:
      Decks{deck, b, c}
    case Decks{a, b, c} D.ThreeSeats{}:
      Decks{a, deck, c}
    case Decks{a, b, c} D.FourSeats{}:
      Decks{a, b, deck}

def host.deck(+host: Host) -> List<&2, Batch>:
  GetSelectedSequenceCopy(host.decks(host), host.table(host))

def host.set_deck(+host: Host, deck: List<&2, Batch>) -> Host:
  host.set_decks(host, decks.set(host.decks(host), host.table(host), deck))

def config.table(config: D.Config) -> D.Table:
  match config:
    case D.Config{table, _}:
      table

def host.initial(+config: D.Config) -> Host:
  Host{config, True{}, 0n, 0n, False{}, 0n, D.Seat0{}, None{}, D.Clockwise{}, None{}, False{}, 0n, False{}, False{}, Nil{}, D.Load{0n, 0n}, MakeSequenceCopies(), D.ring.fill(Props, config.table(config), props.initial())}

def props.unjam(props: Props) -> Props:
  match props:
    case Props{hp, _, checked, cash, slots, grab, holding, turn}:
      Props{hp, False{}, checked, cash, slots, grab, holding, turn}

def props.clear_slots(props: Props) -> Props:
  match props:
    case Props{hp, jam, checked, cash, _, grab, holding, turn}:
      Props{hp, jam, checked, cash, D.slots.empty(), grab, holding, turn}
