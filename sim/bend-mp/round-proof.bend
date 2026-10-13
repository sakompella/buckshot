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
import ./use-proof.bend as U
import ./shot-proof.bend as SP
import ./aim-proof.bend as AP

# The win and the round start with items: WinRoutine onward to the next
# round's grab start. Each closure is stated from qh(s), so it holds from any
# phase; the fuel counts the reference's silent frames down to
# BeginItemGrabbingForSockets (T.distribute.close).

def reset.host(+h: H.Host) -> H.Host:
  +h1 : H.Host = H.host.set_direction(H.host.set_checking_first_death(h, True{}), D.Clockwise{})
  +h2 : H.Host = H.host.set_seats(h1, G.round_seats(D.ring.entries(H.Props, H.host.seats(h1)), G.DisableJam{}, H.host.seats(h1)))
  +h3 : H.Host = H.host.set_seats(h2, G.round_seats(D.ring.entries(H.Props, H.host.seats(h2)), G.RestoreHealth{H.host.round_health(h2)}, H.host.seats(h2)))
  H.host.set_seats(h3, G.round_seats(D.ring.entries(H.Props, H.host.seats(h3)), G.ClearSlots{}, H.host.seats(h3)))


def reset.claim(+s: S.State) -> Type:
  {reset.host(T.qh(s)) == T.qh(A.reset.state(s)) : H.Host}


def reset.eq(+s: S.State, +shape: A.Shape(s)) -> reset.claim(s):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(reset.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(reset.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(reset.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(reset.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(reset.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(reset.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.three_four(e_players))


def reset.table(+p: S.Players, +h: Nat) -> {D.ring.table(S.Seat, S.players.reset(p, h)) == D.ring.table(S.Seat, p) : D.Table}:
  match p:
    case D.Duo{+a, +b}:
      {==}
    case D.Trio{+a, +b, +c}:
      {==}
    case D.Quad{+a, +b, +c, +d}:
      {==}


def shape.reset(+s: S.State, +shape: A.Shape(s)) -> A.Shape(A.reset.state(s)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      +shape_w : A.Shape(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, D.Clockwise{}, died, True{}, amount, saw, gun, shown, deck}, p, ph, n, g}) = AP.shape.world(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, D.Clockwise{}, died, True{}, amount, saw, gun, shown, deck}, p, ph, n, g, {==}, shape)
      +shape_p : A.Shape(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, D.Clockwise{}, died, True{}, amount, saw, gun, shown, deck}, S.players.reset(p, rh), ph, n, g}) = U.shape.players(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, D.Clockwise{}, died, True{}, amount, saw, gun, shown, deck}, p, ph, n, g}, S.players.reset(p, rh), reset.table(p, rh), shape_w)
      ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, D.Clockwise{}, died, True{}, amount, saw, gun, shown, deck}, S.players.reset(p, rh), ph, n, g, ph, List.append(&2, D.Note, n, [D.Shown{D.RoundBegan{round, rh, recipient}}]), shape_p)


# PacketSort_StartRound .. ClearUserInventories, then the grab start.
def reset.close(+s: S.State, +k: Nat, +shape: A.Shape(s)) -> {R.settle(Nat.add(16n, k), R.RefState{T.qh(s), R.PacketSort_StartRound{}, S.state.notes(s)}) == A.ref(M.round.reset(s)) : R.RefState}:
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}
      +s1 : S.State = A.reset.state(st)
      +shape1 : A.Shape(s1) = shape.reset(st, shape)
      +told : A.Notes() = S.state.notes(s1)
      +e_host : {R.settle(Nat.add(12n, k), R.RefState{reset.host(T.qh(st)), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(reset.host(T.qh(st)), True{}, H.host.item_amount(reset.host(T.qh(st))))}, told}) == R.settle(Nat.add(12n, k), R.RefState{T.qh(s1), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(T.qh(s1), True{}, H.host.item_amount(T.qh(s1)))}, told}) : R.RefState} = Equal.cong(H.Host, R.RefState, x => R.settle(Nat.add(12n, k), R.RefState{x, R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(x, True{}, H.host.item_amount(x))}, told}), reset.host(T.qh(st)), T.qh(s1), reset.eq(st, shape))
      +e_seats : {R.settle(Nat.add(12n, k), R.RefState{T.qh(s1), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(T.qh(s1), True{}, amount)}, told}) == R.settle(Nat.add(12n, k), R.RefState{T.qh(s1), R.BeginItemGrabbingForSockets{I.begin.seats(s1, True{}, amount)}, told}) : R.RefState} = Equal.cong(List<&2, D.Seat>, R.RefState, xs => R.settle(Nat.add(12n, k), R.RefState{T.qh(s1), R.BeginItemGrabbingForSockets{xs}, told}), G.GetSocketsToBeginItemGrabbingOn(T.qh(s1), True{}, amount), I.begin.seats(s1, True{}, amount), T.begin.eq(s1, True{}, amount, shape1))
      Equal.trans(R.RefState, R.settle(Nat.add(12n, k), R.RefState{reset.host(T.qh(st)), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(reset.host(T.qh(st)), True{}, H.host.item_amount(reset.host(T.qh(st))))}, told}), R.settle(Nat.add(12n, k), R.RefState{T.qh(s1), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(T.qh(s1), True{}, amount)}, told}), A.ref(M.round.reset(st)), e_host, Equal.trans(R.RefState, R.settle(Nat.add(12n, k), R.RefState{T.qh(s1), R.BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(T.qh(s1), True{}, amount)}, told}), R.settle(Nat.add(12n, k), R.RefState{T.qh(s1), R.BeginItemGrabbingForSockets{I.begin.seats(s1, True{}, amount)}, told}), A.ref(M.round.reset(st)), e_seats, T.distribute.close(I.begin.seats(s1, True{}, amount), s1, k, shape1)))


def arule.close(+rule: D.AmountRule, +s: S.State, +k: Nat, +shape: A.Shape(s)) -> {R.settle(Nat.add(16n, k), R.GetRandomItemGrabAmount.rule(R.RefState{T.qh(s), R.GetRandomItemGrabAmount{R.PacketSort_StartRound{}}, S.state.notes(s)}, R.PacketSort_StartRound{}, rule)) == A.ref(M.amount.rule(s, rule)) : R.RefState}:
  match rule s:
    case D.RandomAmount{} S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      {==}
    case D.FixedAmount{+x} S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      reset.close(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, x, saw, gun, shown, deck}, p, ph, n, g}, k, AP.shape.world(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, x, saw, gun, shown, deck}, p, ph, n, g, {==}, shape))


# GetRandomItemGrabAmount at a round start: the item amount, drawn or fixed.
def amount.close(+s: S.State, +k: Nat, +shape: A.Shape(s)) -> {R.settle(Nat.add(17n, k), R.RefState{T.qh(s), R.GetRandomItemGrabAmount{R.PacketSort_StartRound{}}, S.state.notes(s)}) == A.ref(M.amount.begin(s)) : R.RefState}:
  +rs : R.RefState = R.RefState{T.qh(s), R.GetRandomItemGrabAmount{R.PacketSort_StartRound{}}, S.state.notes(s)}
  Equal.trans(R.RefState, R.settle(Nat.add(16n, k), R.GetRandomItemGrabAmount.rule(rs, R.PacketSort_StartRound{}, G.load.amount(H.host.load_rule(T.qh(s))))), R.settle(Nat.add(16n, k), R.GetRandomItemGrabAmount.rule(rs, R.PacketSort_StartRound{}, Q.load.amount(Q.world.load_rule(S.state.world(s))))), A.ref(M.amount.begin(s)), Equal.cong(D.AmountRule, R.RefState, r => R.settle(Nat.add(16n, k), R.GetRandomItemGrabAmount.rule(rs, R.PacketSort_StartRound{}, r)), G.load.amount(H.host.load_rule(T.qh(s))), Q.load.amount(Q.world.load_rule(S.state.world(s))), T.rule.eq(s)), arule.close(Q.load.amount(Q.world.load_rule(S.state.world(s))), s, k, shape))


def found.eq(+m: Maybe<&2, D.RoundRules>) -> {H.rules.found(m) == Q.value.or(D.RoundRules, m, D.config.default_round()) : D.RoundRules}:
  match m:
    case None{}:
      {==}
    case Some{+r}:
      {==}


def healthof.eq(+r: D.RoundRules) -> {H.rules.health(r) == Q.round.health(r) : D.HealthRule}:
  match r:
    case D.RoundRules{+h, +l, +i}:
      {==}


def hrule.eq(+s: S.State) -> {H.rules.health(H.host.rules(T.qh(s))) == Q.round.health(Q.world.rules(S.state.world(s))) : D.HealthRule}:
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      +m : Maybe<&2, D.RoundRules> = D.plan.round(plan, round)
      Equal.trans(D.HealthRule, H.rules.health(H.rules.found(m)), H.rules.health(Q.value.or(D.RoundRules, m, D.config.default_round())), Q.round.health(Q.value.or(D.RoundRules, m, D.config.default_round())), Equal.cong(D.RoundRules, D.HealthRule, r => H.rules.health(r), H.rules.found(m), Q.value.or(D.RoundRules, m, D.config.default_round()), found.eq(m)), healthof.eq(Q.value.or(D.RoundRules, m, D.config.default_round())))


def hrule.close(+rule: D.HealthRule, +s: S.State, +k: Nat, +shape: A.Shape(s)) -> {R.settle(Nat.add(17n, k), R.GenerateRandomRound.rule(R.RefState{T.qh(s), R.GenerateRandomRound{}, S.state.notes(s)}, rule)) == A.ref(M.health.rule(s, rule)) : R.RefState}:
  match rule s:
    case D.RandomHealth{} S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      {==}
    case D.FixedHealth{+x} S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      amount.close(S.State{S.World{D.Config{table, plan}, before, round, load, first, D.pos.nat(x), recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, k, AP.shape.world(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, S.World{D.Config{table, plan}, before, round, load, first, D.pos.nat(x), recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g, {==}, shape))


# GenerateRandomRound: the round's starting health, drawn or fixed.
def health.close(+s: S.State, +k: Nat, +shape: A.Shape(s)) -> {R.settle(Nat.add(18n, k), R.RefState{T.qh(s), R.GenerateRandomRound{}, S.state.notes(s)}) == A.ref(M.health.begin(s)) : R.RefState}:
  +rs : R.RefState = R.RefState{T.qh(s), R.GenerateRandomRound{}, S.state.notes(s)}
  Equal.trans(R.RefState, R.settle(Nat.add(17n, k), R.GenerateRandomRound.rule(rs, H.rules.health(H.host.rules(T.qh(s))))), R.settle(Nat.add(17n, k), R.GenerateRandomRound.rule(rs, Q.round.health(Q.world.rules(S.state.world(s))))), A.ref(M.health.begin(s)), Equal.cong(D.HealthRule, R.RefState, r => R.settle(Nat.add(17n, k), R.GenerateRandomRound.rule(rs, r)), H.rules.health(H.host.rules(T.qh(s))), Q.round.health(Q.world.rules(S.state.world(s))), hrule.eq(s)), hrule.close(Q.round.health(Q.world.rules(S.state.world(s))), s, k, shape))


# MainRoutine_StartRound with the first seat chosen: the round index moves on.
def fc.close(+s: S.State, +seat: D.Seat, +k: Nat, +shape: A.Shape(s)) -> {R.settle(Nat.add(19n, k), R.RefState{T.qh(s), R.MainRoutine_StartRound{R.FirstChosen{seat}}, S.state.notes(s)}) == A.ref(M.first.chosen(s, seat)) : R.RefState}:
  match s:
    case S.State{+w, +p, +ph, +n, +g}:
      match w:
        case S.World{D.Config{+table, +plan}, True{}, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
          health.close(S.State{S.World{D.Config{table, plan}, False{}, 0n, load, True{}, rh, seat, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, k, AP.shape.world(S.World{D.Config{table, plan}, True{}, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, S.World{D.Config{table, plan}, False{}, 0n, load, True{}, rh, seat, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g, {==}, shape))
        case S.World{D.Config{+table, +plan}, False{}, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
          health.close(S.State{S.World{D.Config{table, plan}, False{}, 1n+round, load, True{}, rh, seat, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, k, AP.shape.world(S.World{D.Config{table, plan}, False{}, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, S.World{D.Config{table, plan}, False{}, 1n+round, load, True{}, rh, seat, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g, {==}, shape))


# GetFirstTurn_Socket: the first seat, drawn or the first death's.
def first.close(+s: S.State, +k: Nat, +shape: A.Shape(s)) -> {R.settle(Nat.add(20n, k), R.RefState{T.qh(s), R.GetFirstTurn_Socket{}, S.state.notes(s)}) == A.ref(M.first.begin(s)) : R.RefState}:
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, None{}, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      {==}
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, Some{+seat}, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      fc.close(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, Some{seat}, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, seat, k, shape)


def award.claim(+s: S.State, +seat: D.Seat, +prize: U32) -> Type:
  {H.host.set_props(T.qh(s), seat, H.props.award(H.host.props(T.qh(s), seat), prize)) == T.qh(S.state.set_players(s, S.players.set_cash(S.state.players(s), seat, U32.add(Q.value.or(U32, D.ring.get(U32, S.players.cash(S.state.players(s)), seat), 0), prize)))) : H.Host}


def award.eq(+s: S.State, +seat: D.Seat, +prize: U32, +shape: A.Shape(s)) -> award.claim(s, seat, prize):
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
              GP.absurd(award.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, prize), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(award.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, prize), GP.clash.four_two(e_players))
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
              GP.absurd(award.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, prize), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(award.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, prize), GP.clash.four_three(e_players))
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
              GP.absurd(award.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, prize), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(award.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, prize), GP.clash.three_four(e_players))


# LoopBackAfterWinRoutine: the match ends after the plan's last round.
def lb.close(+final: Bool, +s: S.State, +k: Nat, +shape: A.Shape(s)) -> {R.settle(Nat.add(21n, k), R.LoopBackAfterWinRoutine.final(R.RefState{T.qh(s), R.LoopBackAfterWinRoutine{}, S.state.notes(s)}, final)) == A.ref(M.win.final(s, final)) : R.RefState}:
  match final s:
    case True{} S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      {==}
    case False{} S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      first.close(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}, k, shape)


# WinRoutine onward: the prize, then the match end or the next round.
def win.close(+s: S.State, +seat: D.Seat, +shape: A.Shape(s), +k: Nat) -> {R.settle(Nat.add(23n, k), R.RefState{T.qh(s), R.WinRoutine{seat}, S.state.notes(s)}) == A.ref(M.win(s, seat)) : R.RefState}:
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +p, +ph, +n, +g}:
      +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, ph, n, g}
      +p1 : S.Players = S.players.set_cash(p, seat, U32.add(Q.value.or(U32, D.ring.get(U32, S.players.cash(p), seat), 0), D.prize(round)))
      +s1 : S.State = S.state.emit(S.state.set_players(st, p1), D.RoundWon{seat, D.prize(round)})
      +told : A.Notes() = S.state.notes(s1)
      +shape1 : A.Shape(s1) = ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p1, ph, n, g, ph, told, U.shape.players(st, p1, GP.set_table(S.Seat, p, seat, S.seat.set_cash(S.players.seat(p, seat), U32.add(Q.value.or(U32, D.ring.get(U32, S.players.cash(p), seat), 0), D.prize(round)))), shape))
      +e_award : {R.settle(Nat.add(22n, k), R.RefState{H.host.set_props(T.qh(st), seat, H.props.award(H.host.props(T.qh(st), seat), D.prize(round))), R.LoopBackAfterWinRoutine{}, told}) == R.settle(Nat.add(22n, k), R.RefState{T.qh(s1), R.LoopBackAfterWinRoutine{}, told}) : R.RefState} = Equal.cong(H.Host, R.RefState, x => R.settle(Nat.add(22n, k), R.RefState{x, R.LoopBackAfterWinRoutine{}, told}), H.host.set_props(T.qh(st), seat, H.props.award(H.host.props(T.qh(st), seat), D.prize(round))), T.qh(s1), award.eq(st, seat, D.prize(round), shape))
      Equal.trans(R.RefState, R.settle(Nat.add(22n, k), R.RefState{H.host.set_props(T.qh(st), seat, H.props.award(H.host.props(T.qh(st), seat), D.prize(round))), R.LoopBackAfterWinRoutine{}, told}), R.settle(Nat.add(22n, k), R.RefState{T.qh(s1), R.LoopBackAfterWinRoutine{}, told}), A.ref(M.win(st, seat)), e_award, lb.close(Nat.is_eq(1n+round, D.plan.length(plan)), s1, k, shape1))


# The win premise of the turn-end and item proofs, discharged.
def win.closure() -> T.WinClosure():
  +s => +seat => +shape => +k => win.close(s, seat, shape, k)

