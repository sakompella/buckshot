import Base
import ../domain.bend as D
import ./state.bend as S
import ./rules.bend as G

# None projects to the source's pre-round -1 and pre-passage socket 5. These
# sentinels cannot occur in domain.Point's playable seat or round fields.
type Snapshot is Data:
  Snapshot{round_index: Maybe<&2, Nat>, load_index: Nat, turn: Maybe<&2, D.Seat>, direction: D.Direction, sawed: Bool, first_death: Maybe<&2, D.Seat>, item_amount: Nat, gun: List<&2, D.Shell>, deck: List<&2, Nat>, seats: D.Ring<&2, SeatSnapshot>}

type SeatSnapshot is Data:
  SeatSnapshot{health: Nat, jammed: Bool, jam_checked: Bool, cash: U32, slots: List<&2, Maybe<&2, D.Item>>, grabbing: Bool, holding: Maybe<&2, D.Item>}

def seat_snapshot(props: S.Props) -> SeatSnapshot:
  match props:
    case S.Props{hp, jam, checked, cash, slots, grab, holding, _}:
      SeatSnapshot{hp, jam, checked, cash, G.slots.list(slots), grab, holding}

def seat_snapshots(entries: List<&2, D.At<&2, S.Props>>, seats: D.Ring<&2, SeatSnapshot>) -> D.Ring<&2, SeatSnapshot>:
  match entries:
    case Nil{}:
      seats
    case D.At{seat, props} <> rest:
      seat_snapshots(rest, D.ring.set(SeatSnapshot, seats, seat, seat_snapshot(props)))

def deck_ids(deck: List<&2, S.Batch>) -> List<&2, Nat>:
  match deck:
    case Nil{}:
      Nil{}
    case S.Batch{id, _} <> rest:
      id <> deck_ids(rest)

def round_index(before: Bool, index: Nat) -> Maybe<&2, Nat>:
  match before:
    case True{}:
      None{}
    case False{}:
      Some{index}

def snapshot(+host: S.Host) -> Snapshot:
  Snapshot{round_index(S.host.before_round(host), S.host.round_index(host)), S.host.load_index(host), S.host.turn(host), S.host.direction(host), S.host.sawed(host), S.host.first_death(host), S.host.item_amount(host), S.host.gun(host), deck_ids(S.host.deck(host)), seat_snapshots(D.ring.entries(S.Props, S.host.seats(host)), D.ring.fill(SeatSnapshot, S.host.table(host), seat_snapshot(S.props.initial())))}
