import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/items.bend as I
import ./sm/main.bend as M
import ./sm/rules.bend as Q
import ./ref/main.bend as R
import ./ref/state.bend as H
import ./ref/rules.bend as G
import ./ref/items.bend as RI
import ./core-proof.bend as C
import ./grab-proof.bend as GP
import ./item-step-proof.bend as ISP
import ./load-proof.bend as LP
import ./turn-proof.bend as T
import ./primitive.bend as P

# Item use from a seat that holds the turn: CheckIfEndingTurnAfterItemUse
# onward against item.use, for every item. The use clears the seat's turn
# flag except for the jammer and adrenaline, which open a selection.

def hh(+s: S.State, +seat: D.Seat) -> H.Host:
  A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), Some{seat})

def clear.claim(+s: S.State, +seat: D.Seat) -> Type:
  {H.host.set_props(hh(s, seat), seat, H.props.set_turn(H.host.props(hh(s, seat), seat), False{})) == T.qh(s) : H.Host}

def clear.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> clear.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(clear.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(clear.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(clear.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(clear.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(clear.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(clear.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))

def keep.claim(+s: S.State, +seat: D.Seat) -> Type:
  {H.host.set_props(hh(s, seat), seat, H.props.set_turn(H.host.props(hh(s, seat), seat), True{})) == hh(s, seat) : H.Host}

def keep.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> keep.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(keep.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(keep.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(keep.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(keep.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(keep.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(keep.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))

def slots.claim(+s: S.State, +seat: D.Seat, +slot: D.Slot, +hold: Maybe<&2, D.Seat>) -> Type:
  {H.host.set_props(A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), hold), seat, H.props.set_slots(H.host.props(A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), hold), seat), I.slots.put(RI.props.slots(H.host.props(A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), hold), seat)), slot, None{}))) == A.host.at(S.state.world(s), S.players.set_slots(S.state.players(s), seat, I.slots.put(I.seat.slots(S.state.players(s), seat), slot, None{})), S.state.grabs(s), hold) : H.Host}

def slots.write(+s: S.State, +seat: D.Seat, +slot: D.Slot, +hold: Maybe<&2, D.Seat>, +shape: A.Shape(s)) -> slots.claim(s, seat, slot, hold):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(slots.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, slot, hold), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(slots.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, slot, hold), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(slots.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, slot, hold), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(slots.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, slot, hold), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(slots.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, slot, hold), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(slots.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, slot, hold), GP.clash.three_four(e_players))

def heal.claim(+s: S.State, +seat: D.Seat) -> Type:
  {H.host.set_props(T.qh(s), seat, H.props.set_health(H.host.props(T.qh(s), seat), 1n+I.seat.health(S.state.players(s), seat))) == T.qh(S.state.set_players(s, S.players.set_health(S.state.players(s), seat, 1n+I.seat.health(S.state.players(s), seat)))) : H.Host}

def heal.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> heal.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(heal.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(heal.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(heal.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(heal.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(heal.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(heal.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))

def slot.set.eq(+sl: D.Slots, +slot: D.Slot, +v: Maybe<&2, D.Item>) -> {RI.slots.set(sl, slot, v) == I.slots.put(sl, slot, v) : D.Slots}:
  match sl slot:
    case D.Slots{+a, +b, +c, +d, +e, +f, +g, +h} D.Slot0{}:
      {==}
    case D.Slots{+a, +b, +c, +d, +e, +f, +g, +h} D.Slot1{}:
      {==}
    case D.Slots{+a, +b, +c, +d, +e, +f, +g, +h} D.Slot2{}:
      {==}
    case D.Slots{+a, +b, +c, +d, +e, +f, +g, +h} D.Slot3{}:
      {==}
    case D.Slots{+a, +b, +c, +d, +e, +f, +g, +h} D.Slot4{}:
      {==}
    case D.Slots{+a, +b, +c, +d, +e, +f, +g, +h} D.Slot5{}:
      {==}
    case D.Slots{+a, +b, +c, +d, +e, +f, +g, +h} D.Slot6{}:
      {==}
    case D.Slots{+a, +b, +c, +d, +e, +f, +g, +h} D.Slot7{}:
      {==}

# EndItemInteraction: the seat gets its turn back and the Idle menu, or the
# turn ends (the beer ejected the last shell).
def resume.close(+s: S.State, +seat: D.Seat, +k: Nat, +shape: A.Shape(s)) -> {R.settle(1n+k, R.RefState{T.qh(s), R.EndItemInteraction{seat, False{}}, S.state.notes(s)}) == A.ref(M.item.resume(s, seat)) : R.RefState}:
  match s:
    case S.State{+w, +p, +ph, +n, +g}:
      +st : S.State = S.State{w, p, ph, n, g}
      +out : S.State = M.item.resume(st, seat)
      +h0 : H.Host = T.qh(st)
      +h1 : H.Host = hh(st, seat)
      +granted : {LP.give.after(h0, seat, n) == LP.idle.menu(h1, seat, n) : R.RefState} = Equal.cong(H.Host, R.RefState, h => LP.idle.menu(h, seat, n), H.host.set_props(h0, seat, H.props.set_turn(H.host.props(h0, seat), True{})), h1, LP.give.eq(st, seat, shape))
      +menu : {LP.idle.menu(h1, seat, n) == A.ref(out) : R.RefState} = Equal.cong(List<&2, D.Move>, R.RefState, xs => LP.idle.at(h1, seat, xs, n), RI.use_moves(I.slot.order(), h1, seat), Q.idle.moves(I.uses(st, seat)), LP.uses.eq(out, seat, ISP.shape.move(w, p, ph, n, g, S.state.phase(out), n, shape)))
      +hs : H.Host = H.host.set_props(h0, seat, H.props.set_turn(H.host.props(h0, seat), True{}))
      +waited : {R.settle(k, LP.give.after(h0, seat, n)) == LP.give.after(h0, seat, n) : R.RefState} = LP.settle.await(k, hs, D.request.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, H.host.table(hs), Nil{}), seat, D.PickUp{} <> RI.use_moves(I.slot.order(), hs, seat))), D.Playing{seat, D.Idle{}}, R.PlayerMove{D.Idle{}}, n)
      Equal.trans(R.RefState, R.settle(k, LP.give.after(h0, seat, n)), LP.give.after(h0, seat, n), A.ref(out), waited, Equal.trans(R.RefState, LP.give.after(h0, seat, n), LP.idle.menu(h1, seat, n), A.ref(out), granted, menu))

def end.close(+ending: Bool, +s: S.State, +seat: D.Seat, +k: Nat, +shape: A.Shape(s), win: T.WinClosure()) -> {R.settle(Nat.add(26n, k), R.RefState{T.qh(s), R.EndItemInteraction{seat, ending}, S.state.notes(s)}) == A.ref(M.item.end(s, seat, ending)) : R.RefState}:
  match ending:
    case True{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          T.packet.close(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, True{}, None{}, k, shape, win)
    case False{}:
      resume.close(s, seat, Nat.add(25n, k), shape)

def flag(+item: D.Item) -> Bool:
  Bool.or(D.item.eq(item, D.Jammer{}), D.item.eq(item, D.Adrenaline{}))

def turned.host(+h: H.Host, +seat: D.Seat, +b: Bool) -> H.Host:
  H.host.set_props(h, seat, H.props.set_turn(H.host.props(h, seat), b))

def removed.host(+h: H.Host, +owner: D.Seat, +slot: D.Slot) -> H.Host:
  H.host.set_props(h, owner, H.props.set_slots(H.host.props(h, owner), RI.slots.set(RI.props.slots(H.host.props(h, owner)), slot, None{})))

def removed(+s: S.State, +owner: D.Seat, +slot: D.Slot) -> S.State:
  S.state.set_players(s, S.players.set_slots(S.state.players(s), owner, I.slots.put(I.seat.slots(S.state.players(s), owner), slot, None{})))

def used(+s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item) -> S.State:
  S.state.emit(removed(s, owner, slot), D.Used{seat, owner, slot, item})

def removed.eq(+s: S.State, +owner: D.Seat, +slot: D.Slot, +hold: Maybe<&2, D.Seat>, +shape: A.Shape(s)) -> {removed.host(A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), hold), owner, slot) == A.host.at(S.state.world(s), S.state.players(removed(s, owner, slot)), S.state.grabs(s), hold) : H.Host}:
  match s:
    case S.State{+w, +p, +ph, +n, +g}:
      +st : S.State = S.State{w, p, ph, n, g}
      +h : H.Host = A.host.at(w, p, g, hold)
      +inv : D.Slots = RI.props.slots(H.host.props(h, owner))
      Equal.trans(H.Host, removed.host(h, owner, slot), H.host.set_props(h, owner, H.props.set_slots(H.host.props(h, owner), I.slots.put(inv, slot, None{}))), A.host.at(w, S.players.set_slots(p, owner, I.slots.put(I.seat.slots(p, owner), slot, None{})), g, hold), Equal.cong(D.Slots, H.Host, x => H.host.set_props(h, owner, H.props.set_slots(H.host.props(h, owner), x)), RI.slots.set(inv, slot, None{}), I.slots.put(inv, slot, None{}), slot.set.eq(inv, slot, None{})), slots.write(st, owner, slot, hold, shape))

def item.packet(+seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +ending: Bool, +phone: Maybe<&2, D.Secret>) -> R.ItemPacket:
  R.ItemPacket{seat, owner, slot, item, ending, phone}

# ReceivePacket_InteractWithItem and RemoveItemFromInventory: the turn flag
# write (b) and the slot clear, as the host of the machine's consumed state.
def prefix(+item: D.Item, +s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +ending: Bool, +phone: Maybe<&2, D.Secret>, +k: Nat, +b: Bool, +hold: Maybe<&2, D.Seat>, +e_flag: {flag(item) == b : Bool}, +e_hold: {turned.host(hh(s, seat), seat, b) == A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), hold) : H.Host}, +shape: A.Shape(s)) -> {R.settle(2n+k, R.RefState{hh(s, seat), R.ReceivePacket_InteractWithItem{item.packet(seat, owner, slot, item, ending, phone)}, S.state.notes(s)}) == R.settle(k, R.RefState{A.host.at(S.state.world(s), S.state.players(removed(s, owner, slot)), S.state.grabs(s), hold), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, item, ending, phone)}, S.state.notes(used(s, seat, owner, slot, item))}) : R.RefState}:
  match s:
    case S.State{+w, +p, +ph, +n, +g}:
      +st : S.State = S.State{w, p, ph, n, g}
      +pkt : R.ItemPacket = item.packet(seat, owner, slot, item, ending, phone)
      +told : A.Notes() = S.state.notes(used(st, seat, owner, slot, item))
      +at : H.Host = A.host.at(w, p, g, hold)
      +e1 : {R.settle(k, R.RefState{removed.host(turned.host(hh(st, seat), seat, flag(item)), owner, slot), R.ChangeGameStateWithItem{pkt}, told}) == R.settle(k, R.RefState{removed.host(turned.host(hh(st, seat), seat, b), owner, slot), R.ChangeGameStateWithItem{pkt}, told}) : R.RefState} = Equal.cong(Bool, R.RefState, x => R.settle(k, R.RefState{removed.host(turned.host(hh(st, seat), seat, x), owner, slot), R.ChangeGameStateWithItem{pkt}, told}), flag(item), b, e_flag)
      +e2 : {R.settle(k, R.RefState{removed.host(turned.host(hh(st, seat), seat, b), owner, slot), R.ChangeGameStateWithItem{pkt}, told}) == R.settle(k, R.RefState{removed.host(at, owner, slot), R.ChangeGameStateWithItem{pkt}, told}) : R.RefState} = Equal.cong(H.Host, R.RefState, h => R.settle(k, R.RefState{removed.host(h, owner, slot), R.ChangeGameStateWithItem{pkt}, told}), turned.host(hh(st, seat), seat, b), at, e_hold)
      +e3 : {R.settle(k, R.RefState{removed.host(at, owner, slot), R.ChangeGameStateWithItem{pkt}, told}) == R.settle(k, R.RefState{A.host.at(w, S.state.players(removed(st, owner, slot)), g, hold), R.ChangeGameStateWithItem{pkt}, told}) : R.RefState} = Equal.cong(H.Host, R.RefState, h => R.settle(k, R.RefState{h, R.ChangeGameStateWithItem{pkt}, told}), removed.host(at, owner, slot), A.host.at(w, S.state.players(removed(st, owner, slot)), g, hold), removed.eq(st, owner, slot, hold, shape))
      Equal.trans(R.RefState, R.settle(k, R.RefState{removed.host(turned.host(hh(st, seat), seat, flag(item)), owner, slot), R.ChangeGameStateWithItem{pkt}, told}), R.settle(k, R.RefState{removed.host(turned.host(hh(st, seat), seat, b), owner, slot), R.ChangeGameStateWithItem{pkt}, told}), R.settle(k, R.RefState{A.host.at(w, S.state.players(removed(st, owner, slot)), g, hold), R.ChangeGameStateWithItem{pkt}, told}), e1, Equal.trans(R.RefState, R.settle(k, R.RefState{removed.host(turned.host(hh(st, seat), seat, b), owner, slot), R.ChangeGameStateWithItem{pkt}, told}), R.settle(k, R.RefState{removed.host(at, owner, slot), R.ChangeGameStateWithItem{pkt}, told}), R.settle(k, R.RefState{A.host.at(w, S.state.players(removed(st, owner, slot)), g, hold), R.ChangeGameStateWithItem{pkt}, told}), e2, e3))

def shape.removed(+s: S.State, +owner: D.Seat, +slot: D.Slot, +shape: A.Shape(s)) -> A.Shape(removed(s, owner, slot)):
  match s:
    case S.State{+world, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match shape:
        case Tuple{+e_players, +rest}:
          +written : S.Seat = S.seat.set_slots(S.players.seat(players, owner), I.slots.put(I.seat.slots(players, owner), slot, None{}))
          (Equal.trans(D.Table, D.ring.table(S.Seat, D.ring.set(S.Seat, players, owner, written)), D.ring.table(S.Seat, players), S.world.table(world), GP.set_table(S.Seat, players, owner, written), e_players), rest)

def shape.players(+s: S.State, +p2: S.Players, +e: {D.ring.table(S.Seat, p2) == D.ring.table(S.Seat, S.state.players(s)) : D.Table}, +shape: A.Shape(s)) -> A.Shape(S.state.set_players(s, p2)):
  match s:
    case S.State{+world, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match shape:
        case Tuple{+e_players, +rest}:
          (Equal.trans(D.Table, D.ring.table(S.Seat, p2), D.ring.table(S.Seat, players), S.world.table(world), e, e_players), rest)

def health.at(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> {H.props.health(H.host.props(T.qh(s), seat)) == I.seat.health(S.state.players(s), seat) : Nat}:
  Equal.cong(H.Props, Nat, x => H.props.health(x), H.host.props(T.qh(s), seat), LP.pprops.with(s, seat, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{})), LP.pprops.eq(s, seat, shape))

def flip.eq(+d: D.Direction) -> {RI.FlipTurnOrder(d) == I.flip(d) : D.Direction}:
  match d:
    case D.Clockwise{}:
      {==}
    case D.CounterClockwise{}:
      {==}

def invert.eq(+shell: D.Shell) -> {RI.inverted(shell) == I.invert(shell) : D.Shell}:
  match shell:
    case D.Live{}:
      {==}
    case D.Blank{}:
      {==}

def ending.eq(+item: D.Item, +length: Nat) -> {RI.CheckIfEndingTurnAfterItemUse(item, length) == I.ends_turn(item, length) : Bool}:
  match item:
    case D.Saw{}:
      {==}
    case D.Glass{}:
      {==}
    case D.Jammer{}:
      {==}
    case D.Cigarettes{}:
      {==}
    case D.Beer{}:
      {==}
    case D.Phone{}:
      {==}
    case D.Inverter{}:
      {==}
    case D.Adrenaline{}:
      {==}
    case D.Remote{}:
      {==}

def heal.split(+b: Bool, +s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +ending: Bool, +phone: Maybe<&2, D.Secret>, +k: Nat, +shape: A.Shape(s)) -> {R.settle(27n+k, R.ChangeGameStateWithItem.heal(R.RefState{T.qh(s), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Cigarettes{}, ending, phone)}, S.state.notes(s)}, seat, b)) == A.ref(M.item.heal(s, seat, b)) : R.RefState}:
  match b:
    case True{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +hp : Nat = I.seat.health(p, seat)
          +p3 : S.Players = S.players.set_health(p, seat, 1n+hp)
          +s3 : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p3, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +told : A.Notes() = List.append(&2, D.Note, n, [D.Shown{D.Healed{seat, 1n+hp}}])
          +read : {R.settle(26n+k, R.RefState{H.host.set_props(T.qh(st), seat, H.props.set_health(H.host.props(T.qh(st), seat), 1n+H.props.health(H.host.props(T.qh(st), seat)))), R.EndItemInteraction{seat, False{}}, List.append(&2, D.Note, n, [D.Shown{D.Healed{seat, 1n+H.props.health(H.host.props(T.qh(st), seat))}}])}) == R.settle(26n+k, R.RefState{H.host.set_props(T.qh(st), seat, H.props.set_health(H.host.props(T.qh(st), seat), 1n+hp)), R.EndItemInteraction{seat, False{}}, told}) : R.RefState} = Equal.cong(Nat, R.RefState, x => R.settle(26n+k, R.RefState{H.host.set_props(T.qh(st), seat, H.props.set_health(H.host.props(T.qh(st), seat), 1n+x)), R.EndItemInteraction{seat, False{}}, List.append(&2, D.Note, n, [D.Shown{D.Healed{seat, 1n+x}}])}), H.props.health(H.host.props(T.qh(st), seat)), hp, health.at(st, seat, shape))
          +wrote : {R.settle(26n+k, R.RefState{H.host.set_props(T.qh(st), seat, H.props.set_health(H.host.props(T.qh(st), seat), 1n+hp)), R.EndItemInteraction{seat, False{}}, told}) == R.settle(26n+k, R.RefState{T.qh(s3), R.EndItemInteraction{seat, False{}}, told}) : R.RefState} = Equal.cong(H.Host, R.RefState, h => R.settle(26n+k, R.RefState{h, R.EndItemInteraction{seat, False{}}, told}), H.host.set_props(T.qh(st), seat, H.props.set_health(H.host.props(T.qh(st), seat), 1n+hp)), T.qh(s3), heal.eq(st, seat, shape))
          +shape3 : A.Shape(s3) = shape.players(st, p3, GP.set_table(S.Seat, p, seat, S.seat.set_health(S.players.seat(p, seat), 1n+hp)), shape)
          Equal.trans(R.RefState, R.settle(26n+k, R.RefState{H.host.set_props(T.qh(st), seat, H.props.set_health(H.host.props(T.qh(st), seat), 1n+H.props.health(H.host.props(T.qh(st), seat)))), R.EndItemInteraction{seat, False{}}, List.append(&2, D.Note, n, [D.Shown{D.Healed{seat, 1n+H.props.health(H.host.props(T.qh(st), seat))}}])}), R.settle(26n+k, R.RefState{H.host.set_props(T.qh(st), seat, H.props.set_health(H.host.props(T.qh(st), seat), 1n+hp)), R.EndItemInteraction{seat, False{}}, told}), A.ref(M.item.heal(st, seat, True{})), read, Equal.trans(R.RefState, R.settle(26n+k, R.RefState{H.host.set_props(T.qh(st), seat, H.props.set_health(H.host.props(T.qh(st), seat), 1n+hp)), R.EndItemInteraction{seat, False{}}, told}), R.settle(26n+k, R.RefState{T.qh(s3), R.EndItemInteraction{seat, False{}}, told}), A.ref(M.item.heal(st, seat, True{})), wrote, resume.close(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p3, ph, told, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, 25n+k, shape3)))
    case False{}:
      resume.close(s, seat, 26n+k, shape)

def consume.via(+item: D.Item, +s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +ending: Bool, +phone: Maybe<&2, D.Secret>, +k: Nat, +b: Bool, +hold: Maybe<&2, D.Seat>, +e_flag: {flag(item) == b : Bool}, +e_hold: {turned.host(hh(s, seat), seat, b) == A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), hold) : H.Host}, +shape: A.Shape(s), +rest: {R.settle(28n+k, R.RefState{A.host.at(S.state.world(s), S.state.players(removed(s, owner, slot)), S.state.grabs(s), hold), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, item, ending, phone)}, S.state.notes(used(s, seat, owner, slot, item))}) == A.ref(M.item.consume(s, seat, owner, slot, item, ending, phone)) : R.RefState}) -> {R.settle(Nat.add(30n, k), R.RefState{hh(s, seat), R.ReceivePacket_InteractWithItem{item.packet(seat, owner, slot, item, ending, phone)}, S.state.notes(s)}) == A.ref(M.item.consume(s, seat, owner, slot, item, ending, phone)) : R.RefState}:
  Equal.trans(R.RefState, R.settle(2n+(28n+k), R.RefState{hh(s, seat), R.ReceivePacket_InteractWithItem{item.packet(seat, owner, slot, item, ending, phone)}, S.state.notes(s)}), R.settle(28n+k, R.RefState{A.host.at(S.state.world(s), S.state.players(removed(s, owner, slot)), S.state.grabs(s), hold), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, item, ending, phone)}, S.state.notes(used(s, seat, owner, slot, item))}), A.ref(M.item.consume(s, seat, owner, slot, item, ending, phone)), prefix(item, s, seat, owner, slot, ending, phone, 28n+k, b, hold, e_flag, e_hold, shape), rest)

# The item's effect after the slot is cleared, per item, from the host the
# turn-flag write leaves.
def consume.close(+item: D.Item, +s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +ending: Bool, +phone: Maybe<&2, D.Secret>, +k: Nat, +shape: A.Shape(s), win: T.WinClosure()) -> {R.settle(Nat.add(30n, k), R.RefState{hh(s, seat), R.ReceivePacket_InteractWithItem{item.packet(seat, owner, slot, item, ending, phone)}, S.state.notes(s)}) == A.ref(M.item.consume(s, seat, owner, slot, item, ending, phone)) : R.RefState}:
  match item:
    case D.Saw{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +s1 : S.State = used(st, seat, owner, slot, D.Saw{})
          +shape1 : A.Shape(s1) = shape.removed(st, owner, slot, shape)
          +rest : {R.settle(28n+k, R.RefState{A.host.at(S.state.world(s1), S.state.players(s1), S.state.grabs(s1), None{}), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Saw{}, ending, phone)}, S.state.notes(s1)}) == A.ref(M.item.effect(s1, seat, D.Saw{}, ending, phone)) : R.RefState} = resume.close(S.state.set_world(s1, S.world.set_sawed(S.state.world(s1), True{})), seat, 25n+k, shape1)
          consume.via(D.Saw{}, st, seat, owner, slot, ending, phone, k, False{}, None{}, {==}, clear.eq(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, shape), shape, rest)
    case D.Jammer{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +s1 : S.State = used(st, seat, owner, slot, D.Jammer{})
          +shape1 : A.Shape(s1) = shape.removed(st, owner, slot, shape)
          +out : S.State = S.state.set_phase(s1, S.JamPick{seat, I.jam.for(s1, seat)})
          +rest : {R.settle(28n+k, R.RefState{A.host.at(S.state.world(s1), S.state.players(s1), S.state.grabs(s1), Some{seat}), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Jammer{}, ending, phone)}, S.state.notes(s1)}) == A.ref(M.item.effect(s1, seat, D.Jammer{}, ending, phone)) : R.RefState} = Equal.cong(List<&2, D.Move>, R.RefState, xs => R.RefState{hh(s1, seat), A.idle.frame(hh(s1, seat), seat, D.Jamming{}, xs), S.state.notes(s1)}, RI.jam_moves(RI.jam_targets(D.ring.entries(H.Props, H.host.seats(hh(s1, seat))), seat)), I.jam.moves(I.jam.for(s1, seat)), LP.jam.eq(out, seat, shape1))
          consume.via(D.Jammer{}, st, seat, owner, slot, ending, phone, k, True{}, Some{seat}, {==}, keep.eq(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, shape), shape, rest)
    case D.Cigarettes{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +s1 : S.State = used(st, seat, owner, slot, D.Cigarettes{})
          +shape1 : A.Shape(s1) = shape.removed(st, owner, slot, shape)
          +read : {R.settle(27n+k, R.ChangeGameStateWithItem.heal(R.RefState{T.qh(s1), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Cigarettes{}, ending, phone)}, S.state.notes(s1)}, seat, Nat.is_lt(H.props.health(H.host.props(T.qh(s1), seat)), rh))) == R.settle(27n+k, R.ChangeGameStateWithItem.heal(R.RefState{T.qh(s1), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Cigarettes{}, ending, phone)}, S.state.notes(s1)}, seat, Nat.is_lt(I.seat.health(S.state.players(s1), seat), rh))) : R.RefState} = Equal.cong(Nat, R.RefState, x => R.settle(27n+k, R.ChangeGameStateWithItem.heal(R.RefState{T.qh(s1), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Cigarettes{}, ending, phone)}, S.state.notes(s1)}, seat, Nat.is_lt(x, rh))), H.props.health(H.host.props(T.qh(s1), seat)), I.seat.health(S.state.players(s1), seat), health.at(s1, seat, shape1))
          +rest : {R.settle(28n+k, R.RefState{A.host.at(S.state.world(s1), S.state.players(s1), S.state.grabs(s1), None{}), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Cigarettes{}, ending, phone)}, S.state.notes(s1)}) == A.ref(M.item.effect(s1, seat, D.Cigarettes{}, ending, phone)) : R.RefState} = Equal.trans(R.RefState, R.settle(27n+k, R.ChangeGameStateWithItem.heal(R.RefState{T.qh(s1), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Cigarettes{}, ending, phone)}, S.state.notes(s1)}, seat, Nat.is_lt(H.props.health(H.host.props(T.qh(s1), seat)), rh))), R.settle(27n+k, R.ChangeGameStateWithItem.heal(R.RefState{T.qh(s1), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Cigarettes{}, ending, phone)}, S.state.notes(s1)}, seat, Nat.is_lt(I.seat.health(S.state.players(s1), seat), rh))), A.ref(M.item.effect(s1, seat, D.Cigarettes{}, ending, phone)), read, heal.split(Nat.is_lt(I.seat.health(S.state.players(s1), seat), rh), s1, seat, owner, slot, ending, phone, k, shape1))
          consume.via(D.Cigarettes{}, st, seat, owner, slot, ending, phone, k, False{}, None{}, {==}, clear.eq(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, shape), shape, rest)
    case D.Adrenaline{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +s1 : S.State = used(st, seat, owner, slot, D.Adrenaline{})
          +shape1 : A.Shape(s1) = shape.removed(st, owner, slot, shape)
          +out : S.State = S.state.set_phase(s1, S.StealPick{seat, I.steal.for(s1, seat)})
          +rest : {R.settle(28n+k, R.RefState{A.host.at(S.state.world(s1), S.state.players(s1), S.state.grabs(s1), Some{seat}), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Adrenaline{}, ending, phone)}, S.state.notes(s1)}) == A.ref(M.item.effect(s1, seat, D.Adrenaline{}, ending, phone)) : R.RefState} = Equal.cong(List<&2, D.Move>, R.RefState, xs => R.RefState{hh(s1, seat), A.idle.frame(hh(s1, seat), seat, D.Stealing{}, xs), S.state.notes(s1)}, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(hh(s1, seat))), hh(s1, seat), seat), I.steal.moves(I.steal.for(s1, seat)), LP.steal.eq(out, seat, shape1))
          consume.via(D.Adrenaline{}, st, seat, owner, slot, ending, phone, k, True{}, Some{seat}, {==}, keep.eq(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, shape), shape, rest)
    case D.Remote{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +s1 : S.State = used(st, seat, owner, slot, D.Remote{})
          +shape1 : A.Shape(s1) = shape.removed(st, owner, slot, shape)
          +d : D.Direction = S.world.direction(S.state.world(s1))
          +flipped : {R.settle(27n+k, R.RefState{H.host.set_direction(T.qh(s1), RI.FlipTurnOrder(d)), R.EndItemInteraction{seat, False{}}, List.append(&2, D.Note, S.state.notes(s1), [D.Shown{D.DirectionFlipped{RI.FlipTurnOrder(d)}}])}) == R.settle(27n+k, R.RefState{H.host.set_direction(T.qh(s1), I.flip(d)), R.EndItemInteraction{seat, False{}}, List.append(&2, D.Note, S.state.notes(s1), [D.Shown{D.DirectionFlipped{I.flip(d)}}])}) : R.RefState} = Equal.cong(D.Direction, R.RefState, x => R.settle(27n+k, R.RefState{H.host.set_direction(T.qh(s1), x), R.EndItemInteraction{seat, False{}}, List.append(&2, D.Note, S.state.notes(s1), [D.Shown{D.DirectionFlipped{x}}])}), RI.FlipTurnOrder(d), I.flip(d), flip.eq(d))
          +rest : {R.settle(28n+k, R.RefState{A.host.at(S.state.world(s1), S.state.players(s1), S.state.grabs(s1), None{}), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Remote{}, ending, phone)}, S.state.notes(s1)}) == A.ref(M.item.effect(s1, seat, D.Remote{}, ending, phone)) : R.RefState} = Equal.trans(R.RefState, R.settle(27n+k, R.RefState{H.host.set_direction(T.qh(s1), RI.FlipTurnOrder(d)), R.EndItemInteraction{seat, False{}}, List.append(&2, D.Note, S.state.notes(s1), [D.Shown{D.DirectionFlipped{RI.FlipTurnOrder(d)}}])}), R.settle(27n+k, R.RefState{H.host.set_direction(T.qh(s1), I.flip(d)), R.EndItemInteraction{seat, False{}}, List.append(&2, D.Note, S.state.notes(s1), [D.Shown{D.DirectionFlipped{I.flip(d)}}])}), A.ref(M.item.effect(s1, seat, D.Remote{}, ending, phone)), flipped, resume.close(S.state.emit(S.state.set_world(s1, S.world.set_direction(S.state.world(s1), I.flip(d))), D.DirectionFlipped{I.flip(d)}), seat, 26n+k, shape1))
          consume.via(D.Remote{}, st, seat, owner, slot, ending, phone, k, False{}, None{}, {==}, clear.eq(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, shape), shape, rest)
    case D.Phone{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match phone:
            case None{}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              consume.via(D.Phone{}, st, seat, owner, slot, ending, None{}, k, False{}, None{}, {==}, clear.eq(st, seat, shape), shape, {==})
            case Some{+secret}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Phone{})
              +shape1 : A.Shape(s1) = shape.removed(st, owner, slot, shape)
              consume.via(D.Phone{}, st, seat, owner, slot, ending, Some{secret}, k, False{}, None{}, {==}, clear.eq(st, seat, shape), shape, resume.close(S.state.tell(s1, seat, secret), seat, 26n+k, shape1))
    case D.Glass{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          consume.via(D.Glass{}, st, seat, owner, slot, ending, phone, k, False{}, None{}, {==}, clear.eq(st, seat, shape), shape, {==})
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +shell <> +tail, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, shell <> tail, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +s1 : S.State = used(st, seat, owner, slot, D.Glass{})
          +shape1 : A.Shape(s1) = shape.removed(st, owner, slot, shape)
          +rest : {R.settle(28n+k, R.RefState{A.host.at(S.state.world(s1), S.state.players(s1), S.state.grabs(s1), None{}), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Glass{}, ending, phone)}, S.state.notes(s1)}) == A.ref(M.item.effect(s1, seat, D.Glass{}, ending, phone)) : R.RefState} = end.close(ending, S.state.tell(s1, seat, D.Glimpse{shell}), seat, 1n+k, shape1, win)
          consume.via(D.Glass{}, st, seat, owner, slot, ending, phone, k, False{}, None{}, {==}, clear.eq(st, seat, shape), shape, rest)
    case D.Beer{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          consume.via(D.Beer{}, st, seat, owner, slot, ending, phone, k, False{}, None{}, {==}, clear.eq(st, seat, shape), shape, {==})
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +shell <> +tail, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, shell <> tail, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +s1 : S.State = used(st, seat, owner, slot, D.Beer{})
          +shape1 : A.Shape(s1) = shape.removed(st, owner, slot, shape)
          +rest : {R.settle(28n+k, R.RefState{A.host.at(S.state.world(s1), S.state.players(s1), S.state.grabs(s1), None{}), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Beer{}, ending, phone)}, S.state.notes(s1)}) == A.ref(M.item.effect(s1, seat, D.Beer{}, ending, phone)) : R.RefState} = end.close(ending, S.state.emit(S.state.set_world(s1, S.world.set_gun(S.state.world(s1), tail)), D.Ejected{seat, shell}), seat, 1n+k, shape1, win)
          consume.via(D.Beer{}, st, seat, owner, slot, ending, phone, k, False{}, None{}, {==}, clear.eq(st, seat, shape), shape, rest)
    case D.Inverter{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          consume.via(D.Inverter{}, st, seat, owner, slot, ending, phone, k, False{}, None{}, {==}, clear.eq(st, seat, shape), shape, {==})
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +shell <> +tail, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, shell <> tail, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
          +s1 : S.State = used(st, seat, owner, slot, D.Inverter{})
          +shape1 : A.Shape(s1) = shape.removed(st, owner, slot, shape)
          +flipped : {R.settle(27n+k, R.RefState{H.host.set_gun(T.qh(s1), RI.inverted(shell) <> tail), R.EndItemInteraction{seat, ending}, List.append(&2, D.Note, S.state.notes(s1), [D.Shown{D.Inverted{seat}}])}) == R.settle(27n+k, R.RefState{H.host.set_gun(T.qh(s1), I.invert(shell) <> tail), R.EndItemInteraction{seat, ending}, List.append(&2, D.Note, S.state.notes(s1), [D.Shown{D.Inverted{seat}}])}) : R.RefState} = Equal.cong(D.Shell, R.RefState, x => R.settle(27n+k, R.RefState{H.host.set_gun(T.qh(s1), x <> tail), R.EndItemInteraction{seat, ending}, List.append(&2, D.Note, S.state.notes(s1), [D.Shown{D.Inverted{seat}}])}), RI.inverted(shell), I.invert(shell), invert.eq(shell))
          +rest : {R.settle(28n+k, R.RefState{A.host.at(S.state.world(s1), S.state.players(s1), S.state.grabs(s1), None{}), R.ChangeGameStateWithItem{item.packet(seat, owner, slot, D.Inverter{}, ending, phone)}, S.state.notes(s1)}) == A.ref(M.item.effect(s1, seat, D.Inverter{}, ending, phone)) : R.RefState} = Equal.trans(R.RefState, R.settle(27n+k, R.RefState{H.host.set_gun(T.qh(s1), RI.inverted(shell) <> tail), R.EndItemInteraction{seat, ending}, List.append(&2, D.Note, S.state.notes(s1), [D.Shown{D.Inverted{seat}}])}), R.settle(27n+k, R.RefState{H.host.set_gun(T.qh(s1), I.invert(shell) <> tail), R.EndItemInteraction{seat, ending}, List.append(&2, D.Note, S.state.notes(s1), [D.Shown{D.Inverted{seat}}])}), A.ref(M.item.effect(s1, seat, D.Inverter{}, ending, phone)), flipped, end.close(ending, S.state.emit(S.state.set_world(s1, S.world.set_gun(S.state.world(s1), I.invert(shell) <> tail)), D.Inverted{seat}), seat, 1n+k, shape1, win))
          consume.via(D.Inverter{}, st, seat, owner, slot, ending, phone, k, False{}, None{}, {==}, clear.eq(st, seat, shape), shape, rest)

# The phone: the verbal index and its shell (D28), then the use.
def found.close(+found: Maybe<&2, D.Shell>, +s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +position: Nat, +index: Nat, +k: Nat, +shape: A.Shape(s), win: T.WinClosure()) -> {R.settle(Nat.add(30n, k), R._GetBurnerPhone_Shell.found(R.RefState{hh(s, seat), R._GetBurnerPhone_Shell{item.packet(seat, owner, slot, D.Phone{}, False{}, None{}), index}, S.state.notes(s)}, item.packet(seat, owner, slot, D.Phone{}, False{}, None{}), position, found)) == A.ref(M.item.clue.found(s, seat, owner, slot, position, found)) : R.RefState}:
  match found:
    case None{}:
      match s:
        case S.State{+w, +p, +ph, +n, +g}:
          {==}
    case Some{+shell}:
      consume.close(D.Phone{}, s, seat, owner, slot, False{}, Some{D.Clue{position, shell}}, k, shape, win)

def clue.close(+s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +index: Nat, +k: Nat, +shape: A.Shape(s), win: T.WinClosure()) -> {R.settle(Nat.add(31n, k), R.RefState{hh(s, seat), R._GetBurnerPhone_Shell{item.packet(seat, owner, slot, D.Phone{}, False{}, None{}), index}, S.state.notes(s)}) == A.ref(M.item.clue(s, seat, owner, slot, index)) : R.RefState}:
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}
      +position : Nat = D.clamp(1n+index, D.phone.cap())
      +rs : R.RefState = R.RefState{hh(st, seat), R._GetBurnerPhone_Shell{item.packet(seat, owner, slot, D.Phone{}, False{}, None{}), index}, n}
      +e_at : {G.subtract(position, 1n) == Q.predecessor(position) : Nat} = C.loadproof.predecessor(position)
      +e_nth : {G.nth(D.Shell, gun, G.subtract(position, 1n)) == Q.nth(D.Shell, gun, Q.predecessor(position)) : Maybe<&2, D.Shell>} = Equal.trans(Maybe<&2, D.Shell>, G.nth(D.Shell, gun, G.subtract(position, 1n)), G.nth(D.Shell, gun, Q.predecessor(position)), Q.nth(D.Shell, gun, Q.predecessor(position)), Equal.cong(Nat, Maybe<&2, D.Shell>, i => G.nth(D.Shell, gun, i), G.subtract(position, 1n), Q.predecessor(position), e_at), ISP.nth.eq(D.Shell, gun, Q.predecessor(position)))
      Equal.trans(R.RefState, R.settle(Nat.add(30n, k), R._GetBurnerPhone_Shell.found(rs, item.packet(seat, owner, slot, D.Phone{}, False{}, None{}), position, G.nth(D.Shell, gun, G.subtract(position, 1n)))), R.settle(Nat.add(30n, k), R._GetBurnerPhone_Shell.found(rs, item.packet(seat, owner, slot, D.Phone{}, False{}, None{}), position, Q.nth(D.Shell, gun, Q.predecessor(position)))), A.ref(M.item.clue(st, seat, owner, slot, index)), Equal.cong(Maybe<&2, D.Shell>, R.RefState, x => R.settle(Nat.add(30n, k), R._GetBurnerPhone_Shell.found(rs, item.packet(seat, owner, slot, D.Phone{}, False{}, None{}), position, x)), G.nth(D.Shell, gun, G.subtract(position, 1n)), Q.nth(D.Shell, gun, Q.predecessor(position)), e_nth), found.close(Q.nth(D.Shell, gun, Q.predecessor(position)), st, seat, owner, slot, position, index, k, shape, win))

# CheckIfEndingTurnAfterItemUse onward: the use from a seat that holds the
# turn, by its own slot (Idle) or another seat's (StealPick).
def use.close(+item: D.Item, +s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +k: Nat, +shape: A.Shape(s), win: T.WinClosure()) -> {R.settle(Nat.add(33n, k), R.RefState{hh(s, seat), R.CheckIfEndingTurnAfterItemUse{seat, owner, slot, item}, S.state.notes(s)}) == A.ref(M.item.use(s, seat, owner, slot, item)) : R.RefState}:
  match item:
    case D.Saw{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          consume.close(D.Saw{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, 2n+k, shape, win)
    case D.Glass{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          consume.close(D.Glass{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, 2n+k, shape, win)
    case D.Jammer{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          consume.close(D.Jammer{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, 2n+k, shape, win)
    case D.Cigarettes{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          consume.close(D.Cigarettes{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, 2n+k, shape, win)
    case D.Beer{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          consume.close(D.Beer{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, Nat.is_eq(List.length(&2, D.Shell, gun), 1n), None{}, 2n+k, shape, win)
    case D.Inverter{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          consume.close(D.Inverter{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, 2n+k, shape, win)
    case D.Adrenaline{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          consume.close(D.Adrenaline{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, 2n+k, shape, win)
    case D.Remote{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          consume.close(D.Remote{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, 2n+k, shape, win)
    case D.Phone{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, +g}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, g}
          consume.close(D.Phone{}, st, seat, owner, slot, False{}, Some{D.NoClue{}}, 1n+k, shape, win)
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> Nil{}, +shown, +deck}, +p, +ph, +n, +g}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> Nil{}, shown, deck}, p, ph, n, g}
          consume.close(D.Phone{}, st, seat, owner, slot, False{}, Some{D.NoClue{}}, 1n+k, shape, win)
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> Nil{}, +shown, +deck}, +p, +ph, +n, +g}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> b <> Nil{}, shown, deck}, p, ph, n, g}
          consume.close(D.Phone{}, st, seat, owner, slot, False{}, Some{D.NoClue{}}, 1n+k, shape, win)
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> +c <> Nil{}, +shown, +deck}, +p, +ph, +n, +g}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> b <> c <> Nil{}, shown, deck}, p, ph, n, g}
          clue.close(st, seat, owner, slot, 2n, k, shape, win)
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> +c <> +d <> +more, +shown, +deck}, +p, +ph, +n, +g}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> b <> c <> d <> more, shown, deck}, p, ph, n, g}
          {==}

# A single seat's menu (Idle, Aim, JamPick, StealPick): a resolved choice
# names that seat, a move of its menu, and a seat at the table; an empty
# menu resolves to nothing.

def OnSeat(+seat: D.Seat, +table: D.Table, +moves: List<&2, D.Move>, +c: D.Choice) -> Data:
  match c:
    case D.Choice{+s, +i, +m}:
      Sigma<&2, &2, {s == seat : D.Seat}, _ => Sigma<&2, &2, {Q.nth(D.Move, moves, i) == Some{m} : Maybe<&2, D.Move>}, _ => P.seated(table, seat)>>

def AllOn(+seat: D.Seat, +table: D.Table, +moves: List<&2, D.Move>, +cs: List<&2, D.Choice>) -> Data:
  match cs:
    case Nil{}:
      Unit
    case +c <> +rest:
      Sigma<&2, &2, OnSeat(seat, table, moves, c), _ => AllOn(seat, table, moves, rest)>

def menu.of(+table: D.Table, +seat: D.Seat, +moves: List<&2, D.Move>) -> D.Ring<&2, List<&2, D.Move>>:
  D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, moves)

def Pick(+seat: D.Seat, +table: D.Table, +moves: List<&2, D.Move>, +picked: Maybe<&2, D.Choice>) -> Data:
  match picked:
    case None{}:
      {D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(table, seat, moves))) == False{} : Bool}
    case Some{+c}:
      OnSeat(seat, table, moves, c)

def mskip(+i: Nat, +xs: List<&2, D.Move>) -> List<&2, D.Move>:
  match i:
    case 0n:
      xs
    case 1n+k:
      match xs:
        case Nil{}:
          Nil{}
        case x <> +rest:
          mskip(k, rest)

def mlist.is_nil(xs: List<&2, D.Move>) -> Type:
  match xs:
    case Nil{}:
      Unit
    case _:
      Empty

def mclash.nil_cons(+x: D.Move, +rest: List<&2, D.Move>, e: {Nil{} == x <> rest : List<&2, D.Move>}) -> Empty:
  %e : mlist.is_nil(_)
  Unit{}

def mskip.head(+xs: List<&2, D.Move>, +i: Nat, +o: D.Move, +os: List<&2, D.Move>, +e: {mskip(i, xs) == o <> os : List<&2, D.Move>}) -> {Q.nth(D.Move, xs, i) == Some{o} : Maybe<&2, D.Move>}:
  match xs i:
    case Nil{} 0n:
      GP.absurd({Q.nth(D.Move, Nil{}, 0n) == Some{o} : Maybe<&2, D.Move>}, mclash.nil_cons(o, os, e))
    case +x <> +rest 0n:
      %Equal.sym(List<&2, D.Move>, x <> rest, o <> os, e) : {Q.nth(D.Move, _, 0n) == Some{o} : Maybe<&2, D.Move>}
      {==}
    case Nil{} 1n+k:
      GP.absurd({Q.nth(D.Move, Nil{}, 1n+k) == Some{o} : Maybe<&2, D.Move>}, mclash.nil_cons(o, os, e))
    case x <> +rest 1n+k:
      mskip.head(rest, k, o, os, e)

def mskip.tail(+xs: List<&2, D.Move>, +i: Nat, +o: D.Move, +os: List<&2, D.Move>, +e: {mskip(i, xs) == o <> os : List<&2, D.Move>}) -> {mskip(1n+i, xs) == os : List<&2, D.Move>}:
  match xs i:
    case Nil{} 0n:
      GP.absurd({mskip(1n, Nil{}) == os : List<&2, D.Move>}, mclash.nil_cons(o, os, e))
    case +x <> +rest 0n:
      %Equal.sym(List<&2, D.Move>, x <> rest, o <> os, e) : {mskip(1n, _) == os : List<&2, D.Move>}
      {==}
    case Nil{} 1n+k:
      GP.absurd({mskip(2n+k, Nil{}) == os : List<&2, D.Move>}, mclash.nil_cons(o, os, e))
    case x <> +rest 1n+k:
      mskip.tail(rest, k, o, os, e)

def on.of(+seat: D.Seat, +table: D.Table, +moves: List<&2, D.Move>, +opts: List<&2, D.Move>, +i: Nat, +suffix: {mskip(i, moves) == opts : List<&2, D.Move>}, +seated: P.seated(table, seat)) -> AllOn(seat, table, moves, D.choices.of(opts, seat, i)):
  match opts:
    case Nil{}:
      Unit{}
    case +m <> +ms:
      ((({==}, (mskip.head(moves, i, m, ms, suffix), seated))), on.of(seat, table, moves, ms, 1n+i, mskip.tail(moves, i, m, ms, suffix), seated))

def on.append(+seat: D.Seat, +table: D.Table, +moves: List<&2, D.Move>, +xs: List<&2, D.Choice>, +ys: List<&2, D.Choice>, +ax: AllOn(seat, table, moves, xs), +ay: AllOn(seat, table, moves, ys)) -> AllOn(seat, table, moves, List.append(&2, D.Choice, xs, ys)):
  match xs:
    case Nil{}:
      ay
    case +x <> +rest:
      match ax:
        case Tuple{+here, +more}:
          (here, on.append(seat, table, moves, rest, ys, more, ay))

def on.nth(+seat: D.Seat, +table: D.Table, +moves: List<&2, D.Move>, +cs: List<&2, D.Choice>, +c: D.Choice, +n: Nat, +ax: AllOn(seat, table, moves, c <> cs)) -> Pick(seat, table, moves, D.choices.nth(c <> cs, n)):
  match cs n:
    case Nil{} 0n:
      match ax:
        case Tuple{+here, _}:
          here
    case Nil{} 1n+k:
      match ax:
        case Tuple{+here, _}:
          here
    case +d <> +rest 0n:
      match ax:
        case Tuple{+here, _}:
          here
    case +d <> +rest 1n+k:
      match ax:
        case Tuple{_, +more}:
          on.nth(seat, table, moves, rest, d, k, more)

def on.seated(+seat: D.Seat, +table: D.Table, +m: D.Move, +ms: List<&2, D.Move>, +n: Nat, +seated: P.seated(table, seat)) -> Pick(seat, table, m <> ms, D.choices.nth(List.append(&2, D.Choice, D.choices.of(m <> ms, seat, 0n), Nil{}), n)):
  on.nth(seat, table, m <> ms, List.append(&2, D.Choice, D.choices.of(ms, seat, 1n), Nil{}), D.Choice{seat, 0n, m}, n, (({==}, ({==}, seated)), on.append(seat, table, m <> ms, D.choices.of(ms, seat, 1n), Nil{}, on.of(seat, table, m <> ms, ms, 1n, {==}, seated), Unit{})))

def pick.choose(+table: D.Table, +seat: D.Seat, +moves: List<&2, D.Move>, +n: Nat) -> Pick(seat, table, moves, D.choose(menu.of(table, seat, moves), n)):
  match table seat:
    case D.TwoSeats{} D.Seat0{}:
      {==}
    case D.TwoSeats{} D.Seat1{}:
      match moves:
        case Nil{}:
          {==}
        case +m <> +ms:
          on.seated(D.Seat1{}, D.TwoSeats{}, m, ms, n, Unit{})
    case D.TwoSeats{} D.Seat2{}:
      {==}
    case D.TwoSeats{} D.Seat3{}:
      match moves:
        case Nil{}:
          {==}
        case +m <> +ms:
          on.seated(D.Seat3{}, D.TwoSeats{}, m, ms, n, Unit{})
    case D.ThreeSeats{} D.Seat0{}:
      match moves:
        case Nil{}:
          {==}
        case +m <> +ms:
          on.seated(D.Seat0{}, D.ThreeSeats{}, m, ms, n, Unit{})
    case D.ThreeSeats{} D.Seat1{}:
      match moves:
        case Nil{}:
          {==}
        case +m <> +ms:
          on.seated(D.Seat1{}, D.ThreeSeats{}, m, ms, n, Unit{})
    case D.ThreeSeats{} D.Seat2{}:
      match moves:
        case Nil{}:
          {==}
        case +m <> +ms:
          on.seated(D.Seat2{}, D.ThreeSeats{}, m, ms, n, Unit{})
    case D.ThreeSeats{} D.Seat3{}:
      {==}
    case D.FourSeats{} D.Seat0{}:
      match moves:
        case Nil{}:
          {==}
        case +m <> +ms:
          on.seated(D.Seat0{}, D.FourSeats{}, m, ms, n, Unit{})
    case D.FourSeats{} D.Seat1{}:
      match moves:
        case Nil{}:
          {==}
        case +m <> +ms:
          on.seated(D.Seat1{}, D.FourSeats{}, m, ms, n, Unit{})
    case D.FourSeats{} D.Seat2{}:
      match moves:
        case Nil{}:
          {==}
        case +m <> +ms:
          on.seated(D.Seat2{}, D.FourSeats{}, m, ms, n, Unit{})
    case D.FourSeats{} D.Seat3{}:
      match moves:
        case Nil{}:
          {==}
        case +m <> +ms:
          on.seated(D.Seat3{}, D.FourSeats{}, m, ms, n, Unit{})

# The Idle answer with items: PickUp to Aim, or an item use.

def held.turn.claim(+s: S.State, +seat: D.Seat) -> Type:
  {R.props.has_turn(H.host.props(hh(s, seat), seat)) == True{} : Bool}

def held.turn(+s: S.State, +seat: D.Seat, +shape: A.Shape(s), +seated: P.seated(S.world.table(S.state.world(s)), seat)) -> held.turn.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          match seated:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          match seated:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(held.turn.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(held.turn.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          match seated:
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(held.turn.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(held.turn.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(held.turn.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(held.turn.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))

def IdleSel(+opts: List<&2, S.IdleOption>, +i: Nat, +m: D.Move) -> Data:
  match m:
    case D.PickUp{}:
      {Q.idle.nth(opts, i) == Some{S.TakeGun{}} : Maybe<&2, S.IdleOption>}
    case D.UseItem{+slot, +item}:
      {Q.idle.nth(opts, i) == Some{S.UseAt{slot, item}} : Maybe<&2, S.IdleOption>}
    case _:
      Empty

def some.inj(-X: Data, +a: X, +b: X, +e: {Some{a} == Some{b} : Maybe<&2, X>}) -> {a == b : X}:
  Equal.cong(Maybe<&2, X>, X, x => Q.value.or(X, x, a), Some{a}, Some{b}, e)

def move.none(+m: Maybe<&2, D.Move>) -> Type:
  match m:
    case None{}:
      Empty
    case Some{x}:
      Unit

def none.some(+b: D.Move, +e: {None{} == Some{b} : Maybe<&2, D.Move>}) -> Empty:
  %Equal.sym(Maybe<&2, D.Move>, None{}, Some{b}, e) : move.none(_)
  Unit{}

def idle.sel.tail(+o: S.IdleOption, +os: List<&2, S.IdleOption>, +j: Nat, +m: D.Move, +sel: IdleSel(os, j, m)) -> IdleSel(o <> os, 1n+j, m):
  match m:
    case D.PickUp{}:
      sel
    case D.UseItem{+slot, +item}:
      sel
    case D.Shoot{t}:
      match sel:
    case D.Grab{}:
      match sel:
    case D.Place{x}:
      match sel:
    case D.JamTarget{t}:
      match sel:
    case D.Steal{a, b, c}:
      match sel:

def idle.sel(+opts: List<&2, S.IdleOption>, +i: Nat, +m: D.Move, +e: {Q.nth(D.Move, Q.idle.moves(opts), i) == Some{m} : Maybe<&2, D.Move>}) -> IdleSel(opts, i, m):
  match opts i:
    case Nil{} i:
      GP.absurd(IdleSel(Nil{}, i, m), none.some(m, e))
    case S.TakeGun{} <> +os 0n:
      %some.inj(D.Move, D.PickUp{}, m, e) : IdleSel(S.TakeGun{} <> os, 0n, _)
      {==}
    case S.UseAt{+slot, +item} <> +os 0n:
      %some.inj(D.Move, D.UseItem{slot, item}, m, e) : IdleSel(S.UseAt{slot, item} <> os, 0n, _)
      {==}
    case S.TakeGun{} <> +os 1n+j:
      idle.sel.tail(S.TakeGun{}, os, j, m, idle.sel(os, j, m, e))
    case S.UseAt{+slot, +item} <> +os 1n+j:
      idle.sel.tail(S.UseAt{slot, item}, os, j, m, idle.sel(os, j, m, e))

# An item use offered at Idle is in the seat's slot, so the reference's
# ownership check passes.

def opt.none(+m: Maybe<&2, S.IdleOption>) -> Type:
  match m:
    case None{}:
      Empty
    case Some{x}:
      Unit

def opt.clash(+b: S.IdleOption, +e: {None{} == Some{b} : Maybe<&2, S.IdleOption>}) -> Empty:
  %Equal.sym(Maybe<&2, S.IdleOption>, None{}, Some{b}, e) : opt.none(_)
  Unit{}

def opt.slot(+o: Maybe<&2, S.IdleOption>) -> D.Slot:
  match o:
    case Some{S.UseAt{slot, _}}:
      slot
    case _:
      D.Slot0{}

def opt.item(+o: Maybe<&2, S.IdleOption>) -> D.Item:
  match o:
    case Some{S.UseAt{_, item}}:
      item
    case _:
      D.Saw{}

def UseIH(+r: List<&2, S.IdleOption>, +inv: D.Slots, +slot: D.Slot, +item: D.Item) -> Type:
  @+j:Nat -> @+e:{Q.idle.nth(r, j) == Some{S.UseAt{slot, item}} : Maybe<&2, S.IdleOption>} -> {D.slots.get(inv, slot) == Some{item} : Maybe<&2, D.Item>}

def use.mem.keep(+b: Bool, +x: D.Item, +sl0: D.Slot, +r: List<&2, S.IdleOption>, +inv: D.Slots, +slot: D.Slot, +item: D.Item, +ef: {D.slots.get(inv, sl0) == Some{x} : Maybe<&2, D.Item>}, ih: UseIH(r, inv, slot, item), +i: Nat, +e: {Q.idle.nth(I.keep(S.IdleOption, b, S.UseAt{sl0, x}, r), i) == Some{S.UseAt{slot, item}} : Maybe<&2, S.IdleOption>}) -> {D.slots.get(inv, slot) == Some{item} : Maybe<&2, D.Item>}:
  match b i:
    case False{} i:
      ih(i, e)
    case True{} 0n:
      +e_slot : {sl0 == slot : D.Slot} = Equal.cong(Maybe<&2, S.IdleOption>, D.Slot, o => opt.slot(o), Some{S.UseAt{sl0, x}}, Some{S.UseAt{slot, item}}, e)
      +e_item : {x == item : D.Item} = Equal.cong(Maybe<&2, S.IdleOption>, D.Item, o => opt.item(o), Some{S.UseAt{sl0, x}}, Some{S.UseAt{slot, item}}, e)
      Equal.trans(Maybe<&2, D.Item>, D.slots.get(inv, slot), D.slots.get(inv, sl0), Some{item}, Equal.cong(D.Slot, Maybe<&2, D.Item>, z => D.slots.get(inv, z), slot, sl0, Equal.sym(D.Slot, sl0, slot, e_slot)), Equal.trans(Maybe<&2, D.Item>, D.slots.get(inv, sl0), Some{x}, Some{item}, ef, Equal.cong(D.Item, Maybe<&2, D.Item>, z => Some{z}, x, item, e_item)))
    case True{} 1n+j:
      ih(j, e)

def use.mem.step(+found: Maybe<&2, D.Item>, +sl0: D.Slot, +r: List<&2, S.IdleOption>, +inv: D.Slots, +sw: Bool, +tg: Bool, +st: Bool, +slot: D.Slot, +item: D.Item, +ef: {D.slots.get(inv, sl0) == found : Maybe<&2, D.Item>}, ih: UseIH(r, inv, slot, item), +i: Nat, +e: {Q.idle.nth(I.use.here(found, sl0, sw, tg, st, r), i) == Some{S.UseAt{slot, item}} : Maybe<&2, S.IdleOption>}) -> {D.slots.get(inv, slot) == Some{item} : Maybe<&2, D.Item>}:
  match found:
    case None{}:
      ih(i, e)
    case Some{+x}:
      use.mem.keep(I.use.fits(x, sw, tg, st), x, sl0, r, inv, slot, item, ef, ih, i, e)

def use.mem(+slots: List<&2, D.Slot>, +inv: D.Slots, +sw: Bool, +tg: Bool, +st: Bool, +slot: D.Slot, +item: D.Item, +i: Nat, +e: {Q.idle.nth(I.use.slots(slots, inv, sw, tg, st), i) == Some{S.UseAt{slot, item}} : Maybe<&2, S.IdleOption>}) -> {D.slots.get(inv, slot) == Some{item} : Maybe<&2, D.Item>}:
  match slots:
    case Nil{}:
      GP.absurd({D.slots.get(inv, slot) == Some{item} : Maybe<&2, D.Item>}, opt.clash(S.UseAt{slot, item}, e))
    case +sl0 <> +rest:
      use.mem.step(D.slots.get(inv, sl0), sl0, I.use.slots(rest, inv, sw, tg, st), inv, sw, tg, st, slot, item, {==}, +j => +e2 => use.mem(rest, inv, sw, tg, st, slot, item, j, e2), i, e)

def alive.add(+a: Nat, +b: Nat, +e: {G.alive(b) == True{} : Bool}) -> {G.alive(Nat.add(a, b)) == True{} : Bool}:
  match a:
    case 0n:
      e
    case 1n+x:
      {==}

def item.self(+item: D.Item, +c: Nat) -> {G.alive(Nat.add(G.item.count.here(Some{item}, item), c)) == True{} : Bool}:
  match item:
    case D.Saw{}:
      {==}
    case D.Glass{}:
      {==}
    case D.Jammer{}:
      {==}
    case D.Cigarettes{}:
      {==}
    case D.Beer{}:
      {==}
    case D.Phone{}:
      {==}
    case D.Inverter{}:
      {==}
    case D.Adrenaline{}:
      {==}
    case D.Remote{}:
      {==}

def cell.none(+m: Maybe<&2, Maybe<&2, D.Item>>) -> Type:
  match m:
    case None{}:
      Empty
    case Some{x}:
      Unit

def cell.clash(+b: Maybe<&2, D.Item>, +e: {None{} == Some{b} : Maybe<&2, Maybe<&2, D.Item>>}) -> Empty:
  %Equal.sym(Maybe<&2, Maybe<&2, D.Item>>, None{}, Some{b}, e) : cell.none(_)
  Unit{}

def count.pos(+xs: List<&2, Maybe<&2, D.Item>>, +item: D.Item, +k: Nat, +e: {Q.nth(Maybe<&2, D.Item>, xs, k) == Some{Some{item}} : Maybe<&2, Maybe<&2, D.Item>>}) -> {G.alive(G.item.count(xs, item)) == True{} : Bool}:
  match xs k:
    case Nil{} k:
      GP.absurd({G.alive(G.item.count(Nil{}, item)) == True{} : Bool}, cell.clash(Some{item}, e))
    case +x <> +rest 0n:
      %Equal.sym(Maybe<&2, D.Item>, x, Some{item}, some.inj(Maybe<&2, D.Item>, x, Some{item}, e)) : {G.alive(G.item.count(_ <> rest, item)) == True{} : Bool}
      item.self(item, G.item.count(rest, item))
    case +x <> +rest 1n+j:
      alive.add(G.item.count.here(x, item), G.item.count(rest, item), count.pos(rest, item, j, e))

def count.slot(+sl: D.Slots, +slot: D.Slot, +item: D.Item, +e: {D.slots.get(sl, slot) == Some{item} : Maybe<&2, D.Item>}) -> {G.alive(G.item.count(G.slots.list(sl), item)) == True{} : Bool}:
  match sl slot:
    case D.Slots{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7} D.Slot0{}:
      count.pos([c0, c1, c2, c3, c4, c5, c6, c7], item, 0n, Equal.cong(Maybe<&2, D.Item>, Maybe<&2, Maybe<&2, D.Item>>, x => Some{x}, c0, Some{item}, e))
    case D.Slots{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7} D.Slot1{}:
      count.pos([c0, c1, c2, c3, c4, c5, c6, c7], item, 1n, Equal.cong(Maybe<&2, D.Item>, Maybe<&2, Maybe<&2, D.Item>>, x => Some{x}, c1, Some{item}, e))
    case D.Slots{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7} D.Slot2{}:
      count.pos([c0, c1, c2, c3, c4, c5, c6, c7], item, 2n, Equal.cong(Maybe<&2, D.Item>, Maybe<&2, Maybe<&2, D.Item>>, x => Some{x}, c2, Some{item}, e))
    case D.Slots{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7} D.Slot3{}:
      count.pos([c0, c1, c2, c3, c4, c5, c6, c7], item, 3n, Equal.cong(Maybe<&2, D.Item>, Maybe<&2, Maybe<&2, D.Item>>, x => Some{x}, c3, Some{item}, e))
    case D.Slots{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7} D.Slot4{}:
      count.pos([c0, c1, c2, c3, c4, c5, c6, c7], item, 4n, Equal.cong(Maybe<&2, D.Item>, Maybe<&2, Maybe<&2, D.Item>>, x => Some{x}, c4, Some{item}, e))
    case D.Slots{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7} D.Slot5{}:
      count.pos([c0, c1, c2, c3, c4, c5, c6, c7], item, 5n, Equal.cong(Maybe<&2, D.Item>, Maybe<&2, Maybe<&2, D.Item>>, x => Some{x}, c5, Some{item}, e))
    case D.Slots{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7} D.Slot6{}:
      count.pos([c0, c1, c2, c3, c4, c5, c6, c7], item, 6n, Equal.cong(Maybe<&2, D.Item>, Maybe<&2, Maybe<&2, D.Item>>, x => Some{x}, c6, Some{item}, e))
    case D.Slots{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7} D.Slot7{}:
      count.pos([c0, c1, c2, c3, c4, c5, c6, c7], item, 7n, Equal.cong(Maybe<&2, D.Item>, Maybe<&2, Maybe<&2, D.Item>>, x => Some{x}, c7, Some{item}, e))

def and.cong_true(+a: Bool, +b: Bool, +ea: {a == True{} : Bool}, +eb: {b == True{} : Bool}) -> {Bool.and(a, b) == True{} : Bool}:
  T.and.cong(a, True{}, b, True{}, ea, eb)

def stepped.ref.local(+x: R.RefState, +out: S.State, +e: {x == A.ref(out) : R.RefState}) -> {R.stepped(x) == A.stepped(S.state.stepped(out)) : A.RefStep()}:
  ISP.stepped.ref(x, out, e)

def idle.opts(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat) -> D.NonEmpty<&2, S.IdleOption>:
  D.NonEmpty{S.TakeGun{}, I.uses(S.State{w, p, S.Ended{}, Nil{}, g}, seat)}

def idle.at(+w: S.World, +p: S.Players, +seat: D.Seat, +n: A.Notes(), +g: S.Grabs) -> S.State:
  S.State{w, p, S.Idle{seat, idle.opts(w, p, g, seat)}, n, g}

def idle.moves(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat) -> List<&2, D.Move>:
  Q.idle.moves(D.nonempty.list(S.IdleOption, idle.opts(w, p, g, seat)))

def idle.ref(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat) -> R.RefState:
  R.RefState{hh(idle.at(w, p, seat, Nil{}, g), seat), R.Await{D.Choose{menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat))}, D.Playing{seat, D.Idle{}}, R.PlayerMove{D.Idle{}}}, Nil{}}

def opt.is_take(+m: Maybe<&2, S.IdleOption>) -> Type:
  match m:
    case Some{S.TakeGun{}}:
      Empty
    case _:
      Unit

def opt.take_use(+slot: D.Slot, +item: D.Item, +e: {Some{S.TakeGun{}} == Some{S.UseAt{slot, item}} : Maybe<&2, S.IdleOption>}) -> Empty:
  %Equal.sym(Maybe<&2, S.IdleOption>, Some{S.TakeGun{}}, Some{S.UseAt{slot, item}}, e) : opt.is_take(_)
  Unit{}

def verify.accept(+rs: R.RefState, +choice: D.Choice, +out: S.State, +e: {R.VerifyPacket(rs, choice) == True{} : Bool}, +rest: {R.stepped(R.settle(96n, R.answer.move.accepted(rs, choice, True{}))) == A.stepped(S.state.stepped(out)) : A.RefStep()}) -> {R.stepped(R.settle(96n, R.answer.move(rs, choice))) == A.stepped(S.state.stepped(out)) : A.RefStep()}:
  Equal.trans(A.RefStep(), R.stepped(R.settle(96n, R.answer.move.accepted(rs, choice, R.VerifyPacket(rs, choice)))), R.stepped(R.settle(96n, R.answer.move.accepted(rs, choice, True{}))), A.stepped(S.state.stepped(out)), Equal.cong(Bool, A.RefStep(), b => R.stepped(R.settle(96n, R.answer.move.accepted(rs, choice, b))), R.VerifyPacket(rs, choice), True{}, e), rest)

def idle.use.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +i: Nat, +slot: D.Slot, +item: D.Item, +sel: {Q.idle.nth(D.nonempty.list(S.IdleOption, idle.opts(w, p, g, seat)), i) == Some{S.UseAt{slot, item}} : Maybe<&2, S.IdleOption>}, +seated: P.seated(S.world.table(w), seat), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(idle.at(w, p, seat, Nil{}, g)), win: T.WinClosure()) -> {R.stepped(R.settle(96n, R.answer.move(idle.ref(w, p, g, seat), D.Choice{seat, i, D.UseItem{slot, item}}))) == A.stepped(S.state.stepped(M.item.use(idle.at(w, p, seat, Nil{}, g), seat, seat, slot, item))) : A.RefStep()}:
  match w i:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} 0n:
      GP.absurd({R.stepped(R.settle(96n, R.answer.move(idle.ref(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), D.Choice{seat, 0n, D.UseItem{slot, item}}))) == A.stepped(S.state.stepped(M.item.use(idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g), seat, seat, slot, item))) : A.RefStep()}, opt.take_use(slot, item, sel))
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} 1n+j:
      +st : S.State = idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g)
      +inv : D.Slots = I.seat.slots(p, seat)
      +owned : {G.alive(G.item.count(G.slots.list(inv), item)) == True{} : Bool} = count.slot(inv, slot, item, use.mem(I.slot.order(), inv, saw, I.jam.any(I.jam.for(st, seat)), I.steal.any(I.steal.for(st, seat)), slot, item, j, sel))
      +e_own : {G.alive(G.item.count(G.slots.list(RI.props.slots(H.host.props(hh(idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g), seat), seat))), item)) == True{} : Bool} = Equal.trans(Bool, G.alive(G.item.count(G.slots.list(RI.props.slots(H.host.props(hh(idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g), seat), seat))), item)), G.alive(G.item.count(G.slots.list(inv), item)), True{}, Equal.cong(D.Slots, Bool, x => G.alive(G.item.count(G.slots.list(x), item)), RI.props.slots(H.host.props(hh(st, seat), seat)), inv, GP.slots.eq(st, seat, shape)), owned)
      +e_v : {R.VerifyPacket(idle.ref(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), D.Choice{seat, 1n+j, D.UseItem{slot, item}}) == True{} : Bool} = and.cong_true(R.current.eq(turn, seat), Bool.and(R.props.has_turn(H.host.props(hh(st, seat), seat)), G.alive(G.item.count(G.slots.list(RI.props.slots(H.host.props(hh(idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g), seat), seat))), item))), ready, and.cong_true(R.props.has_turn(H.host.props(hh(st, seat), seat)), G.alive(G.item.count(G.slots.list(RI.props.slots(H.host.props(hh(idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g), seat), seat))), item)), held.turn(idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g), seat, shape, seated), e_own))
      verify.accept(idle.ref(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), D.Choice{seat, 1n+j, D.UseItem{slot, item}}, M.item.use(st, seat, seat, slot, item), e_v, stepped.ref.local(R.settle(95n, R.RefState{hh(st, seat), R.CheckIfEndingTurnAfterItemUse{seat, seat, slot, item}, Nil{}}), M.item.use(st, seat, seat, slot, item), use.close(item, st, seat, seat, slot, 62n, shape, win)))

def idle.move.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +i: Nat, +m: D.Move, +sel: IdleSel(D.nonempty.list(S.IdleOption, idle.opts(w, p, g, seat)), i, m), +seated: P.seated(S.world.table(w), seat), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(idle.at(w, p, seat, Nil{}, g)), win: T.WinClosure()) -> {R.stepped(R.settle(96n, R.answer.move(idle.ref(w, p, g, seat), D.Choice{seat, i, m}))) == A.stepped(S.state.stepped(M.answer.choice(idle.at(w, p, seat, Nil{}, g), D.Choice{seat, i, m}))) : A.RefStep()}:
  match w m:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.PickUp{}:
      +st : S.State = idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g)
      +e_v : {R.VerifyPacket(idle.ref(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), D.Choice{seat, i, D.PickUp{}}) == True{} : Bool} = and.cong_true(R.current.eq(turn, seat), Bool.and(R.props.has_turn(H.host.props(hh(st, seat), seat)), True{}), ready, and.cong_true(R.props.has_turn(H.host.props(hh(st, seat), seat)), True{}, held.turn(idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g), seat, shape, seated), {==}))
      +picked : {A.stepped(S.state.stepped(M.pickup(st, seat))) == A.stepped(S.state.stepped(M.answer.choice(st, D.Choice{seat, i, D.PickUp{}}))) : A.RefStep()} = Equal.cong(Maybe<&2, S.IdleOption>, A.RefStep(), o => A.stepped(S.state.stepped(M.pickup.selected(st, seat, o))), Some{S.TakeGun{}}, Q.idle.nth(D.nonempty.list(S.IdleOption, idle.opts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)), i), Equal.sym(Maybe<&2, S.IdleOption>, Q.idle.nth(D.nonempty.list(S.IdleOption, idle.opts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)), i), Some{S.TakeGun{}}, sel))
      verify.accept(idle.ref(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), D.Choice{seat, i, D.PickUp{}}, M.answer.choice(st, D.Choice{seat, i, D.PickUp{}}), e_v, picked)
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.UseItem{+slot, +item}:
      +st : S.State = idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g)
      +picked : {A.stepped(S.state.stepped(M.item.use(st, seat, seat, slot, item))) == A.stepped(S.state.stepped(M.answer.choice(st, D.Choice{seat, i, D.UseItem{slot, item}}))) : A.RefStep()} = Equal.cong(Maybe<&2, S.IdleOption>, A.RefStep(), o => A.stepped(S.state.stepped(M.pickup.selected(st, seat, o))), Some{S.UseAt{slot, item}}, Q.idle.nth(D.nonempty.list(S.IdleOption, idle.opts(w, p, g, seat)), i), Equal.sym(Maybe<&2, S.IdleOption>, Q.idle.nth(D.nonempty.list(S.IdleOption, idle.opts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)), i), Some{S.UseAt{slot, item}}, sel))
      Equal.trans(A.RefStep(), R.stepped(R.settle(96n, R.answer.move(idle.ref(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), D.Choice{seat, i, D.UseItem{slot, item}}))), A.stepped(S.state.stepped(M.item.use(st, seat, seat, slot, item))), A.stepped(S.state.stepped(M.answer.choice(st, D.Choice{seat, i, D.UseItem{slot, item}}))), idle.use.answer(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, g, i, slot, item, sel, seated, ready, shape, win), picked)
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.Shoot{t}:
      match sel:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.Grab{}:
      match sel:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.Place{x}:
      match sel:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.JamTarget{t}:
      match sel:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.Steal{a, b, c}:
      match sel:

def idle.picked.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +picked: Maybe<&2, D.Choice>, +pk: Pick(seat, S.world.table(w), idle.moves(w, p, g, seat), picked), +e_any: {D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)))) == True{} : Bool}, +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(idle.at(w, p, seat, Nil{}, g)), win: T.WinClosure()) -> {R.stepped(R.settle(96n, R.answer.resolved(idle.ref(w, p, g, seat), R.PlayerMove{D.Idle{}}, D.resolve.choice(picked)))) == A.stepped(S.state.stepped(M.answer.resolved(idle.at(w, p, seat, Nil{}, g), D.resolve.choice(picked)))) : A.RefStep()}:
  match picked:
    case None{}:
      GP.absurd({R.stepped(R.settle(96n, R.answer.resolved(idle.ref(w, p, g, seat), R.PlayerMove{D.Idle{}}, D.resolve.choice(None{})))) == A.stepped(S.state.stepped(M.answer.resolved(idle.at(w, p, seat, Nil{}, g), D.resolve.choice(None{})))) : A.RefStep()}, T.clash.false_true(Equal.trans(Bool, False{}, D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)))), True{}, Equal.sym(Bool, D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)))), False{}, pk), e_any)))
    case Some{D.Choice{+s, +i, +m}}:
      match pk:
        case Tuple{+e_s, Tuple{+e_nth, +seated}}:
          Equal.trans(A.RefStep(), R.stepped(R.settle(96n, R.answer.move(idle.ref(w, p, g, seat), D.Choice{s, i, m}))), R.stepped(R.settle(96n, R.answer.move(idle.ref(w, p, g, seat), D.Choice{seat, i, m}))), A.stepped(S.state.stepped(M.answer.choice(idle.at(w, p, seat, Nil{}, g), D.Choice{seat, i, m}))), Equal.cong(D.Seat, A.RefStep(), x => R.stepped(R.settle(96n, R.answer.move(idle.ref(w, p, g, seat), D.Choice{x, i, m}))), s, seat, e_s), idle.move.answer(w, p, seat, g, i, m, idle.sel(D.nonempty.list(S.IdleOption, idle.opts(w, p, g, seat)), i, m, e_nth), seated, ready, shape, win))

def idle.any.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +any: Bool, +e: {D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)))) == any : Bool}, +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(idle.at(w, p, seat, Nil{}, g)), win: T.WinClosure()) -> {R.answer(R.RefState{hh(idle.at(w, p, seat, n0, g), seat), R.Await{D.request.choose.any(any, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat))), D.Playing{seat, D.Idle{}}, R.PlayerMove{D.Idle{}}}, n0}, n) == A.stepped(M.answer.request(idle.at(w, p, seat, n0, g), n, D.request.choose.any(any, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat))))) : A.RefStep()}:
  match w any:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} True{}:
      idle.picked.answer(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, g, D.choose(menu.of(table, seat, idle.moves(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)), n), pick.choose(table, seat, idle.moves(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), n), e, ready, shape, win)
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} False{}:
      Equal.cong(Bool, A.RefStep(), b => D.Stepped{R.RefState{hh(idle.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, n0, g), seat), R.Await{D.request.choose.any(b, menu.of(table, seat, idle.moves(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat))), D.Playing{seat, D.Idle{}}, R.PlayerMove{D.Idle{}}}, n0}, Nil{}}, False{}, D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(table, seat, idle.moves(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)))), Equal.sym(Bool, D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(table, seat, idle.moves(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)))), False{}, e))

def idle.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +shape: A.Shape(idle.at(w, p, seat, n0, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, win: T.WinClosure()) -> {A.ref_answer(A.ref(idle.at(w, p, seat, n0, g)), n) == A.stepped(M.answer(idle.at(w, p, seat, n0, g), n)) : A.RefStep()}:
  match w:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      +menu : D.Ring<&2, List<&2, D.Move>> = menu.of(table, seat, idle.moves(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat))
      idle.any.answer(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, n0, g, n, D.menus.any(D.ring.entries(List<&2, D.Move>, menu)), {==}, ready, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.Idle{seat, idle.opts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)}, n0, g, S.Idle{seat, idle.opts(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)}, Nil{}, shape), win)

# Part 3 for item use: the successors are valid; the seat keeps world.turn
# throughout, so Idle, JamPick, StealPick and NeedPhone are ready.

def valid.resume(+s: S.State, +seat: D.Seat, +vpre: LP.VPre(s), +ready: {R.current.eq(S.world.turn(S.state.world(s)), seat) == True{} : Bool}) -> A.ValidItems(M.item.resume(s, seat)):
  match s:
    case S.State{+w, +p, +ph, +n, +g}:
      match vpre:
        case Tuple{+shape, +bounded}:
          ({==}, (ISP.shape.move(w, p, ph, n, g, S.Idle{seat, D.NonEmpty{S.TakeGun{}, I.uses(S.State{w, p, ph, n, g}, seat)}}, n, shape), (bounded, ready)))

def valid.end(+ending: Bool, +s: S.State, +seat: D.Seat, +vpre: LP.VPre(s), +ready: {R.current.eq(S.world.turn(S.state.world(s)), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(M.item.end(s, seat, ending)):
  match ending:
    case True{}:
      T.valid.packet(s, seat, True{}, None{}, vpre, winv)
    case False{}:
      valid.resume(s, seat, vpre, ready)

def valid.heal(+b: Bool, +s: S.State, +seat: D.Seat, +vpre: LP.VPre(s), +ready: {R.current.eq(S.world.turn(S.state.world(s)), seat) == True{} : Bool}) -> A.ValidItems(M.item.heal(s, seat, b)):
  match b:
    case True{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +hp : Nat = I.seat.health(p, seat)
              +p3 : S.Players = S.players.set_health(p, seat, 1n+hp)
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              valid.resume(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p3, ph, List.append(&2, D.Note, n, [D.Shown{D.Healed{seat, 1n+hp}}]), S.Grabs{dist, grabbing, holding, granted, intake}}, seat, (shape.players(st, p3, GP.set_table(S.Seat, p, seat, S.seat.set_health(S.players.seat(p, seat), 1n+hp)), shape), bounded), ready)
    case False{}:
      valid.resume(s, seat, vpre, ready)

def valid.consume(+item: D.Item, +s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +ending: Bool, +phone: Maybe<&2, D.Secret>, +vpre: LP.VPre(s), +ready: {R.current.eq(S.world.turn(S.state.world(s)), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(M.item.consume(s, seat, owner, slot, item, ending, phone)):
  match item:
    case D.Saw{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Saw{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              valid.resume(S.state.set_world(s1, S.world.set_sawed(S.state.world(s1), True{})), seat, vpre1, ready)
    case D.Jammer{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Jammer{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              ({==}, (shape.removed(st, owner, slot, shape), (bounded, ready)))
    case D.Adrenaline{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Adrenaline{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              ({==}, (shape.removed(st, owner, slot, shape), (bounded, ready)))
    case D.Cigarettes{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Cigarettes{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              valid.heal(Nat.is_lt(I.seat.health(S.state.players(s1), seat), rh), s1, seat, vpre1, ready)
    case D.Remote{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Remote{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              valid.resume(S.state.emit(S.state.set_world(s1, S.world.set_direction(S.state.world(s1), I.flip(direction))), D.DirectionFlipped{I.flip(direction)}), seat, vpre1, ready)
    case D.Phone{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match phone vpre:
            case None{} Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Phone{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              ({==}, (shape.removed(st, owner, slot, shape), (bounded, {==})))
            case Some{+secret} Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Phone{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              valid.resume(S.state.tell(s1, seat, secret), seat, vpre1, ready)
    case D.Glass{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Glass{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              ({==}, (shape.removed(st, owner, slot, shape), (bounded, {==})))
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +shell <> +tail, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, shell <> tail, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Glass{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              valid.end(ending, S.state.tell(s1, seat, D.Glimpse{shell}), seat, vpre1, ready, winv)
    case D.Beer{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Beer{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              ({==}, (shape.removed(st, owner, slot, shape), (bounded, {==})))
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +shell <> +tail, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, shell <> tail, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Beer{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              valid.end(ending, S.state.emit(S.state.set_world(s1, S.world.set_gun(S.state.world(s1), tail)), D.Ejected{seat, shell}), seat, vpre1, ready, winv)
    case D.Inverter{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Inverter{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              ({==}, (shape.removed(st, owner, slot, shape), (bounded, {==})))
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +shell <> +tail, +shown, +deck}, +p, +ph, +n, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, shell <> tail, shown, deck}, p, ph, n, S.Grabs{dist, grabbing, holding, granted, intake}}
              +s1 : S.State = used(st, seat, owner, slot, D.Inverter{})
              +vpre1 : LP.VPre(s1) = (shape.removed(st, owner, slot, shape), bounded)
              valid.end(ending, S.state.emit(S.state.set_world(s1, S.world.set_gun(S.state.world(s1), I.invert(shell) <> tail)), D.Inverted{seat}), seat, vpre1, ready, winv)

def valid.found(+found: Maybe<&2, D.Shell>, +s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +position: Nat, +vpre: LP.VPre(s), +ready: {R.current.eq(S.world.turn(S.state.world(s)), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(M.item.clue.found(s, seat, owner, slot, position, found)):
  match found:
    case None{}:
      match s:
        case S.State{+w, +p, +ph, +n, +g}:
          match vpre:
            case Tuple{+shape, +bounded}:
              ({==}, (ISP.shape.move(w, p, ph, n, g, S.Blocked{Some{seat}}, n, shape), (bounded, {==})))
    case Some{+shell}:
      valid.consume(D.Phone{}, s, seat, owner, slot, False{}, Some{D.Clue{position, shell}}, vpre, ready, winv)

def valid.clue(+s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +index: Nat, +vpre: LP.VPre(s), +ready: {R.current.eq(S.world.turn(S.state.world(s)), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(M.item.clue(s, seat, owner, slot, index)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      +position : Nat = D.clamp(1n+index, D.phone.cap())
      valid.found(Q.nth(D.Shell, gun, Q.predecessor(position)), S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, position, vpre, ready, winv)

def valid.use(+item: D.Item, +s: S.State, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +vpre: LP.VPre(s), +ready: {R.current.eq(S.world.turn(S.state.world(s)), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(M.item.use(s, seat, owner, slot, item)):
  match item:
    case D.Saw{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          valid.consume(D.Saw{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, vpre, ready, winv)
    case D.Glass{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          valid.consume(D.Glass{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, vpre, ready, winv)
    case D.Jammer{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          valid.consume(D.Jammer{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, vpre, ready, winv)
    case D.Cigarettes{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          valid.consume(D.Cigarettes{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, vpre, ready, winv)
    case D.Beer{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          valid.consume(D.Beer{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, Nat.is_eq(List.length(&2, D.Shell, gun), 1n), None{}, vpre, ready, winv)
    case D.Inverter{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          valid.consume(D.Inverter{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, vpre, ready, winv)
    case D.Adrenaline{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          valid.consume(D.Adrenaline{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, vpre, ready, winv)
    case D.Remote{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
          valid.consume(D.Remote{}, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, owner, slot, False{}, None{}, vpre, ready, winv)
    case D.Phone{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}, +p, +ph, +n, +g}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, Nil{}, shown, deck}, p, ph, n, g}
          valid.consume(D.Phone{}, st, seat, owner, slot, False{}, Some{D.NoClue{}}, vpre, ready, winv)
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> Nil{}, +shown, +deck}, +p, +ph, +n, +g}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> Nil{}, shown, deck}, p, ph, n, g}
          valid.consume(D.Phone{}, st, seat, owner, slot, False{}, Some{D.NoClue{}}, vpre, ready, winv)
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> Nil{}, +shown, +deck}, +p, +ph, +n, +g}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> b <> Nil{}, shown, deck}, p, ph, n, g}
          valid.consume(D.Phone{}, st, seat, owner, slot, False{}, Some{D.NoClue{}}, vpre, ready, winv)
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> +c <> Nil{}, +shown, +deck}, +p, +ph, +n, +g}:
          +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> b <> c <> Nil{}, shown, deck}, p, ph, n, g}
          valid.clue(st, seat, owner, slot, 2n, vpre, ready, winv)
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> +c <> +d <> +more, +shown, +deck}, +p, +ph, +n, +g}:
          match vpre:
            case Tuple{+shape, +bounded}:
              ({==}, (ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> b <> c <> d <> more, shown, deck}, p, ph, n, g, S.NeedPhone{seat, owner, slot}, n, shape), (bounded, ready)))

def valid.idle.move(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +i: Nat, +m: D.Move, +sel: IdleSel(D.nonempty.list(S.IdleOption, idle.opts(w, p, g, seat)), i, m), +vpre: LP.VPre(idle.at(w, p, seat, Nil{}, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(A.machine_step_state(S.state.stepped(M.answer.choice(idle.at(w, p, seat, Nil{}, g), D.Choice{seat, i, m})))):
  match m vpre:
    case D.PickUp{} Tuple{+shape, +bounded}:
      %Equal.sym(Maybe<&2, S.IdleOption>, Q.idle.nth(D.nonempty.list(S.IdleOption, idle.opts(w, p, g, seat)), i), Some{S.TakeGun{}}, sel) : A.ValidItems(M.pickup.selected(idle.at(w, p, seat, Nil{}, g), seat, _))
      ({==}, (ISP.shape.move(w, p, S.Idle{seat, idle.opts(w, p, g, seat)}, Nil{}, g, S.Aim{seat}, [D.Shown{D.PickedUp{seat}}], shape), (bounded, ready)))
    case D.UseItem{+slot, +item} vpre:
      %Equal.sym(Maybe<&2, S.IdleOption>, Q.idle.nth(D.nonempty.list(S.IdleOption, idle.opts(w, p, g, seat)), i), Some{S.UseAt{slot, item}}, sel) : A.ValidItems(M.pickup.selected(idle.at(w, p, seat, Nil{}, g), seat, _))
      valid.use(item, idle.at(w, p, seat, Nil{}, g), seat, seat, slot, vpre, ready, winv)
    case D.Shoot{t} vpre:
      match sel:
    case D.Grab{} vpre:
      match sel:
    case D.Place{x} vpre:
      match sel:
    case D.JamTarget{t} vpre:
      match sel:
    case D.Steal{a, b, c} vpre:
      match sel:

def valid.idle.picked(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +picked: Maybe<&2, D.Choice>, +pk: Pick(seat, S.world.table(w), idle.moves(w, p, g, seat), picked), +e_any: {D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)))) == True{} : Bool}, +vpre: LP.VPre(idle.at(w, p, seat, Nil{}, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(A.machine_step_state(S.state.stepped(M.answer.resolved(idle.at(w, p, seat, Nil{}, g), D.resolve.choice(picked))))):
  match picked:
    case None{}:
      GP.absurd(A.ValidItems(A.machine_step_state(S.state.stepped(M.answer.resolved(idle.at(w, p, seat, Nil{}, g), D.resolve.choice(None{}))))), T.clash.false_true(Equal.trans(Bool, False{}, D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)))), True{}, Equal.sym(Bool, D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)))), False{}, pk), e_any)))
    case Some{D.Choice{+s, +i, +m}}:
      match pk:
        case Tuple{+e_s, Tuple{+e_nth, +seated}}:
          valid.idle.move(w, p, seat, g, i, m, idle.sel(D.nonempty.list(S.IdleOption, idle.opts(w, p, g, seat)), i, m, e_nth), vpre, ready, winv)

def valid.idle.any(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +any: Bool, +e: {D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)))) == any : Bool}, +valid: A.ValidItems(idle.at(w, p, seat, n0, g)), +vpre: LP.VPre(idle.at(w, p, seat, Nil{}, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(A.machine_step_state(M.answer.request(idle.at(w, p, seat, n0, g), n, D.request.choose.any(any, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)))))):
  match any:
    case True{}:
      valid.idle.picked(w, p, seat, g, D.choose(menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)), n), pick.choose(S.world.table(w), seat, idle.moves(w, p, g, seat), n), e, vpre, ready, winv)
    case False{}:
      valid

def valid.idle(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +valid: A.ValidItems(idle.at(w, p, seat, n0, g)), winv: T.WinValid()) -> A.ValidItems(A.next(idle.at(w, p, seat, n0, g), n)):
  match valid:
    case Tuple{+normal, Tuple{+shape, Tuple{+bounded, +ready}}}:
      +vpre : LP.VPre(idle.at(w, p, seat, Nil{}, g)) = (ISP.shape.move(w, p, S.Idle{seat, idle.opts(w, p, g, seat)}, n0, g, S.Idle{seat, idle.opts(w, p, g, seat)}, Nil{}, shape), bounded)
      valid.idle.any(w, p, seat, n0, g, n, D.menus.any(D.ring.entries(List<&2, D.Move>, menu.of(S.world.table(w), seat, idle.moves(w, p, g, seat)))), {==}, (normal, (shape, (bounded, ready))), vpre, ready, winv)

# step_matches at Idle with items, given the win's closure and validity.
def step.idle(+world: S.World, +players: S.Players, +actor: D.Seat, +options: D.NonEmpty<&2, S.IdleOption>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.ValidItems(S.State{world, players, S.Idle{actor, options}, notes, grabs}), win: T.WinClosure(), winv: T.WinValid()) -> A.SimulationItems(S.State{world, players, S.Idle{actor, options}, notes, grabs}, n):
  +normal : A.ValidItems(idle.at(world, players, actor, notes, grabs)) = ISP.valid.normalized(S.State{world, players, S.Idle{actor, options}, notes, grabs}, valid)
  %A.valid_items.normal(S.State{world, players, S.Idle{actor, options}, notes, grabs}, valid) : A.SimulationItems(_, n)
  ISP.simulation.items(idle.at(world, players, actor, notes, grabs), n, idle.answer(world, players, actor, notes, grabs, n, A.valid_items.shape(idle.at(world, players, actor, notes, grabs), normal), A.valid_items.ready(idle.at(world, players, actor, notes, grabs), normal), win), valid.idle(world, players, actor, notes, grabs, n, normal, winv))
