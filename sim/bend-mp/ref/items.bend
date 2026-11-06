import Base
import ../domain.bend as D
import ./state.bend as S
import ./rules.bend as G

def slots.set(slots: D.Slots, slot: D.Slot, value: Maybe<&2, D.Item>) -> D.Slots:
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

def slots.all() -> List<&2, D.Slot>:
  [D.Slot0{}, D.Slot1{}, D.Slot2{}, D.Slot3{}, D.Slot4{}, D.Slot5{}, D.Slot6{}, D.Slot7{}]

def props.slots(props: S.Props) -> D.Slots:
  match props:
    case S.Props{_, _, _, _, slots, _, _, _}:
      slots

def props.holding(props: S.Props) -> Maybe<&2, D.Item>:
  match props:
    case S.Props{_, _, _, _, _, _, holding, _}:
      holding

def props.grabbing(props: S.Props) -> Bool:
  match props:
    case S.Props{_, _, _, _, _, grab, _, _}:
      grab

def progress.count(progress: S.GrabProgress) -> Nat:
  match progress:
    case S.GrabProgress{count, _}:
      count

def progress.intake(progress: S.GrabProgress) -> Bool:
  match progress:
    case S.GrabProgress{_, intake}:
      intake

def begin_grab(seats: List<&2, D.Seat>, +host: S.Host) -> S.Host:
  match seats:
    case Nil{}:
      host
    case +seat <> rest:
      h : S.Host = S.host.set_props(host, seat, S.props.grab(S.host.props(host, seat)))
      begin_grab(rest, S.host.set_progress(h, seat, S.GrabProgress{0n, True{}}))

def place_moves.here(value: Maybe<&2, D.Item>, slot: D.Slot, rest: List<&2, D.Move>) -> List<&2, D.Move>:
  match value:
    case None{}:
      D.Place{slot} <> rest
    case _:
      rest

def place_moves(slots: List<&2, D.Slot>, +inventory: D.Slots) -> List<&2, D.Move>:
  match slots:
    case Nil{}:
      Nil{}
    case +slot <> rest:
      place_moves.here(D.slots.get(inventory, slot), slot, place_moves(rest, inventory))

def grab_moves(props: S.Props, progress: S.GrabProgress) -> List<&2, D.Move>:
  match props progress:
    case S.Props{_, _, _, _, slots, True{}, Some{item}, _} _:
      place_moves(slots.all(), slots)
    case S.Props{_, _, _, _, _, True{}, None{}, _} S.GrabProgress{_, True{}}:
      [D.Grab{}]
    case _ _:
      Nil{}

def occupied(xs: List<&2, Maybe<&2, D.Item>>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case None{} <> rest:
      occupied(rest)
    case Some{item} <> rest:
      1n+occupied(rest)

def IsPlacingLastItem(+host: S.Host, +seat: D.Seat) -> Bool:
  Bool.or(Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), host, seat))), Bool.or(Nat.is_eq(1n+occupied(G.slots.list(props.slots(S.host.props(host, seat)))), 8n), Bool.not(Nat.is_lt(progress.count(S.host.progress(host, seat)), S.host.item_amount(host)))))

def all_ended(entries: List<&2, D.At<&2, S.Props>>) -> Bool:
  match entries:
    case Nil{}:
      True{}
    case D.At{_, props} <> rest:
      Bool.and(Bool.not(props.grabbing(props)), all_ended(rest))

def all_empty(entries: List<&2, D.At<&2, S.Props>>, +host: S.Host) -> Bool:
  match entries:
    case Nil{}:
      True{}
    case D.At{seat, _} <> rest:
      Bool.and(Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), host, seat))), all_empty(rest, host))

# D55 M1 retains the two whole-table predicates. Holders are not ended by
# the noneligible pass, even when their pool is empty.
def CheckIfItemGrabbingFinishedForAllUsers(+host: S.Host) -> Bool:
  Bool.or(all_ended(D.ring.entries(S.Props, S.host.seats(host))), all_empty(D.ring.entries(S.Props, S.host.seats(host)), host))

def GetSocketArrayToEndItemGrabbingOn(entries: List<&2, D.At<&2, S.Props>>, +host: S.Host, +placing: D.Seat) -> List<&2, D.Seat>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+seat, S.Props{_, _, _, _, _, True{}, None{}, _}} <> rest:
      G.turn_ring.put(Bool.and(Bool.not(D.seat.eq(seat, placing)), Bool.not(G.nonempty(D.Item, G.GetItemToGrab.pool(D.item.order(), host, seat)))), seat, GetSocketArrayToEndItemGrabbingOn(rest, host, placing))
    case entry <> rest:
      GetSocketArrayToEndItemGrabbingOn(rest, host, placing)

def jam_target(props: S.Props) -> Bool:
  match props:
    case S.Props{hp, jam, _, _, _, _, _, _}:
      Bool.and(G.alive(hp), Bool.not(jam))

def jam_targets(entries: List<&2, D.At<&2, S.Props>>, +by: D.Seat) -> List<&2, D.Seat>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+seat, props} <> rest:
      G.turn_ring.put(Bool.and(Bool.not(D.seat.eq(seat, by)), jam_target(props)), seat, jam_targets(rest, by))

def CheckIfJammerHasEligibleTargets(+host: S.Host, seat: D.Seat) -> Bool:
  G.nonempty(D.Seat, jam_targets(D.ring.entries(S.Props, S.host.seats(host)), seat))

# D55 M4 is a prospective stealing-mode mask, not the raw partial
# adrenaline scan. Jammer targets are relative to the thief.
def valid_steal(+host: S.Host, +seat: D.Seat, item: D.Item) -> Bool:
  match item:
    case D.Adrenaline{}:
      False{}
    case D.Saw{}:
      Bool.not(S.host.sawed(host))
    case D.Jammer{}:
      CheckIfJammerHasEligibleTargets(host, seat)
    case _:
      True{}

def use_moves.put(keep: Bool, move: D.Move, rest: List<&2, D.Move>) -> List<&2, D.Move>:
  match keep:
    case True{}:
      move <> rest
    case False{}:
      rest

def steal_slots.here(found: Maybe<&2, D.Item>, host: S.Host, thief: D.Seat, owner: D.Seat, slot: D.Slot, rest: List<&2, D.Move>) -> List<&2, D.Move>:
  match found:
    case None{}:
      rest
    case Some{+item}:
      use_moves.put(valid_steal(host, thief, item), D.Steal{owner, slot, item}, rest)

def steal_slots(slots: List<&2, D.Slot>, +host: S.Host, +thief: D.Seat, +owner: D.Seat) -> List<&2, D.Move>:
  match slots:
    case Nil{}:
      Nil{}
    case +slot <> rest:
      steal_slots.here(D.slots.get(props.slots(S.host.props(host, owner)), slot), host, thief, owner, slot, steal_slots(rest, host, thief, owner))

def steal_moves.here(self: Bool, host: S.Host, thief: D.Seat, owner: D.Seat, rest: List<&2, D.Move>) -> List<&2, D.Move>:
  match self:
    case True{}:
      rest
    case False{}:
      List.append(&2, D.Move, steal_slots(slots.all(), host, thief, owner), rest)

def steal_moves(entries: List<&2, D.At<&2, S.Props>>, +host: S.Host, +thief: D.Seat) -> List<&2, D.Move>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+owner, _} <> rest:
      steal_moves.here(D.seat.eq(owner, thief), host, thief, owner, steal_moves(rest, host, thief))

def GetPropertyInvalidItems(+host: S.Host, +seat: D.Seat, item: D.Item) -> Bool:
  match item:
    case D.Adrenaline{}:
      Bool.not(G.nonempty(D.Move, steal_moves(D.ring.entries(S.Props, S.host.seats(host)), host, seat)))
    case item:
      Bool.not(valid_steal(host, seat, item))

def use_moves.here(found: Maybe<&2, D.Item>, host: S.Host, seat: D.Seat, slot: D.Slot, rest: List<&2, D.Move>) -> List<&2, D.Move>:
  match found:
    case None{}:
      rest
    case Some{+item}:
      use_moves.put(Bool.not(GetPropertyInvalidItems(host, seat, item)), D.UseItem{slot, item}, rest)

def use_moves(slots: List<&2, D.Slot>, +host: S.Host, +seat: D.Seat) -> List<&2, D.Move>:
  match slots:
    case Nil{}:
      Nil{}
    case +slot <> rest:
      use_moves.here(D.slots.get(props.slots(S.host.props(host, seat)), slot), host, seat, slot, use_moves(rest, host, seat))

def jam_moves(seats: List<&2, D.Seat>) -> List<&2, D.Move>:
  match seats:
    case Nil{}:
      Nil{}
    case seat <> rest:
      D.JamTarget{seat} <> jam_moves(rest)

def FlipTurnOrder(direction: D.Direction) -> D.Direction:
  match direction:
    case D.Clockwise{}:
      D.CounterClockwise{}
    case D.CounterClockwise{}:
      D.Clockwise{}

def inverted(shell: D.Shell) -> D.Shell:
  match shell:
    case D.Live{}:
      D.Blank{}
    case D.Blank{}:
      D.Live{}

def CheckIfEndingTurnAfterItemUse(item: D.Item, length: Nat) -> Bool:
  match item:
    case D.Beer{}:
      Nat.is_eq(length, 1n)
    case _:
      False{}

def holders(entries: List<&2, D.At<&2, S.Props>>) -> Bool:
  match entries:
    case Nil{}:
      False{}
    case D.At{_, S.Props{_, _, _, _, _, _, Some{item}, _}} <> rest:
      True{}
    case entry <> rest:
      holders(rest)
