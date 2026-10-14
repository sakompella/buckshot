import Base
import ./domain.bend as D

def seated(table: D.Table, seat: D.Seat) -> Data:
  match table seat:
    case D.TwoSeats{} D.Seat1{}:
      Unit
    case D.TwoSeats{} D.Seat3{}:
      Unit
    case D.ThreeSeats{} D.Seat0{}:
      Unit
    case D.ThreeSeats{} D.Seat1{}:
      Unit
    case D.ThreeSeats{} D.Seat2{}:
      Unit
    case D.FourSeats{} _:
      Unit
    case _ _:
      Empty

def append_nil_choices(+xs: List<&2, D.Choice>) -> {List.append(&2, D.Choice, xs, Nil{}) == xs : List<&2, D.Choice>}:
  match xs:
    case Nil{}:
      {==}
    case +choice <> +rest:
      Equal.cong(List<&2, D.Choice>, List<&2, D.Choice>, tail => choice <> tail, List.append(&2, D.Choice, rest, Nil{}), rest, append_nil_choices(rest))

law one_menu_choices:
  for +table: D.Table
  for +seat: D.Seat
  for +moves: List<&2, D.Move>
  for present: seated(table, seat)
  {D.choices.flatten(D.ring.entries(List<&2, D.Move>, D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, moves))) == D.choices.of(moves, seat, 0n) : List<&2, D.Choice>}

def one_menu_choices(table, seat, moves, present):
  match table seat:
    case D.TwoSeats{} D.Seat0{}:
      match present:
    case D.TwoSeats{} D.Seat1{}:
      append_nil_choices(D.choices.of(moves, D.Seat1{}, 0n))
    case D.TwoSeats{} D.Seat2{}:
      match present:
    case D.TwoSeats{} D.Seat3{}:
      append_nil_choices(D.choices.of(moves, D.Seat3{}, 0n))
    case D.ThreeSeats{} D.Seat0{}:
      append_nil_choices(D.choices.of(moves, D.Seat0{}, 0n))
    case D.ThreeSeats{} D.Seat1{}:
      append_nil_choices(D.choices.of(moves, D.Seat1{}, 0n))
    case D.ThreeSeats{} D.Seat2{}:
      append_nil_choices(D.choices.of(moves, D.Seat2{}, 0n))
    case D.ThreeSeats{} D.Seat3{}:
      match present:
    case D.FourSeats{} D.Seat0{}:
      append_nil_choices(D.choices.of(moves, D.Seat0{}, 0n))
    case D.FourSeats{} D.Seat1{}:
      append_nil_choices(D.choices.of(moves, D.Seat1{}, 0n))
    case D.FourSeats{} D.Seat2{}:
      append_nil_choices(D.choices.of(moves, D.Seat2{}, 0n))
    case D.FourSeats{} D.Seat3{}:
      append_nil_choices(D.choices.of(moves, D.Seat3{}, 0n))
