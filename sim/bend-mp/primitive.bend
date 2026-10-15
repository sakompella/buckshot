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
