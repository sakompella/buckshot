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
