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

# JamPick: the jam choice, the jammer write, then the resume.

def jam.at(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +n: A.Notes(), +g: S.Grabs) -> S.State:
  S.State{w, p, S.JamPick{seat, targets}, n, g}


def jam.ref(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat, +targets: List<&2, S.JamOption>) -> R.RefState:
  R.RefState{U.hh(jam.at(w, p, seat, targets, Nil{}, g), seat), R.Await{D.Choose{U.menu.of(S.world.table(w), seat, I.jam.moves(targets))}, D.Playing{seat, D.Jamming{}}, R.PlayerMove{D.Jamming{}}}, Nil{}}


def JamSel(+targets: List<&2, S.JamOption>, +i: Nat, +m: D.Move) -> Data:
  match m:
    case D.JamTarget{+t}:
      {I.jam.nth(targets, i) == Some{S.JamAt{t}} : Maybe<&2, S.JamOption>}
    case _:
      Empty


def jam.sel.tail(+o: S.JamOption, +os: List<&2, S.JamOption>, +j: Nat, +m: D.Move, +sel: JamSel(os, j, m)) -> JamSel(o <> os, 1n+j, m):
  match m:
    case D.JamTarget{+t}:
      sel
    case D.PickUp{}:
      match sel:
    case D.Shoot{x}:
      match sel:
    case D.UseItem{a, b}:
      match sel:
    case D.Grab{}:
      match sel:
    case D.Place{x}:
      match sel:
    case D.Steal{a, b, c}:
      match sel:


def jam.sel(+targets: List<&2, S.JamOption>, +i: Nat, +m: D.Move, +e: {Q.nth(D.Move, I.jam.moves(targets), i) == Some{m} : Maybe<&2, D.Move>}) -> JamSel(targets, i, m):
  match targets i:
    case Nil{} i:
      GP.absurd(JamSel(Nil{}, i, m), U.none.some(m, e))
    case S.JamAt{+t} <> +os 0n:
      %U.some.inj(D.Move, D.JamTarget{t}, m, e) : JamSel(S.JamAt{t} <> os, 0n, _)
      {==}
    case S.JamAt{+t} <> +os 1n+j:
      jam.sel.tail(S.JamAt{t}, os, j, m, jam.sel(os, j, m, e))


def jam.claim(+s: S.State, +seat: D.Seat) -> Type:
  {H.host.set_props(T.qh(s), seat, H.props.jam(H.host.props(T.qh(s), seat))) == T.qh(S.state.set_players(s, S.players.set_jam(S.state.players(s), seat, S.Jammed{}))) : H.Host}


def jam.write(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> jam.claim(s, seat):
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
              GP.absurd(jam.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(jam.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
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
              GP.absurd(jam.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(jam.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
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
              GP.absurd(jam.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(jam.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))


def jammed(+s: S.State, +seat: D.Seat, +t: D.Seat) -> S.State:
  S.state.emit(S.state.set_players(s, S.players.set_jam(S.state.players(s), t, S.Jammed{})), D.JamApplied{seat, t})


def jam.host(+s: S.State, +seat: D.Seat, +t: D.Seat) -> H.Host:
  +h0 : H.Host = U.turned.host(U.hh(s, seat), seat, False{})
  H.host.set_props(h0, t, H.props.jam(H.host.props(h0, t)))


def jam.close(+s: S.State, +seat: D.Seat, +t: D.Seat, +k: Nat, +shape: A.Shape(s)) -> {R.settle(1n+k, R.RefState{jam.host(s, seat, t), R.EndItemInteraction{seat, False{}}, S.state.notes(jammed(s, seat, t))}) == A.ref(M.item.resume(jammed(s, seat, t), seat)) : R.RefState}:
  match s:
    case S.State{+w, +p, +ph, +n, +g}:
      +st : S.State = S.State{w, p, ph, n, g}
      +told : A.Notes() = S.state.notes(jammed(st, seat, t))
      +e_turn : {R.settle(1n+k, R.RefState{jam.host(st, seat, t), R.EndItemInteraction{seat, False{}}, told}) == R.settle(1n+k, R.RefState{H.host.set_props(T.qh(st), t, H.props.jam(H.host.props(T.qh(st), t))), R.EndItemInteraction{seat, False{}}, told}) : R.RefState} = Equal.cong(H.Host, R.RefState, x => R.settle(1n+k, R.RefState{H.host.set_props(x, t, H.props.jam(H.host.props(x, t))), R.EndItemInteraction{seat, False{}}, told}), U.turned.host(U.hh(st, seat), seat, False{}), T.qh(st), U.clear.eq(st, seat, shape))
      +e_jam : {R.settle(1n+k, R.RefState{H.host.set_props(T.qh(st), t, H.props.jam(H.host.props(T.qh(st), t))), R.EndItemInteraction{seat, False{}}, told}) == R.settle(1n+k, R.RefState{T.qh(jammed(st, seat, t)), R.EndItemInteraction{seat, False{}}, told}) : R.RefState} = Equal.cong(H.Host, R.RefState, x => R.settle(1n+k, R.RefState{x, R.EndItemInteraction{seat, False{}}, told}), H.host.set_props(T.qh(st), t, H.props.jam(H.host.props(T.qh(st), t))), T.qh(jammed(st, seat, t)), jam.write(st, t, shape))
      +shape1 : A.Shape(jammed(st, seat, t)) = ISP.shape.move(w, S.players.set_jam(p, t, S.Jammed{}), ph, n, g, ph, told, LP.shape.jam(st, t, S.Jammed{}, shape))
      Equal.trans(R.RefState, R.settle(1n+k, R.RefState{jam.host(st, seat, t), R.EndItemInteraction{seat, False{}}, told}), R.settle(1n+k, R.RefState{H.host.set_props(T.qh(st), t, H.props.jam(H.host.props(T.qh(st), t))), R.EndItemInteraction{seat, False{}}, told}), A.ref(M.item.resume(jammed(st, seat, t), seat)), e_turn, Equal.trans(R.RefState, R.settle(1n+k, R.RefState{H.host.set_props(T.qh(st), t, H.props.jam(H.host.props(T.qh(st), t))), R.EndItemInteraction{seat, False{}}, told}), R.settle(1n+k, R.RefState{T.qh(jammed(st, seat, t)), R.EndItemInteraction{seat, False{}}, told}), A.ref(M.item.resume(jammed(st, seat, t), seat)), e_jam, U.resume.close(jammed(st, seat, t), seat, k, shape1)))


def jam.move.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +g: S.Grabs, +i: Nat, +m: D.Move, +sel: JamSel(targets, i, m), +seated: P.seated(S.world.table(w), seat), +shape: A.Shape(jam.at(w, p, seat, targets, Nil{}, g))) -> {R.stepped(R.settle(96n, R.answer.move(jam.ref(w, p, g, seat, targets), D.Choice{seat, i, m}))) == A.stepped(S.state.stepped(M.answer.choice(jam.at(w, p, seat, targets, Nil{}, g), D.Choice{seat, i, m}))) : A.RefStep()}:
  match m:
    case D.JamTarget{+t}:
      +st : S.State = jam.at(w, p, seat, targets, Nil{}, g)
      +out : S.State = M.jam.selected(st, seat, Some{S.JamAt{t}})
      +e_v : {R.VerifyPacket(jam.ref(w, p, g, seat, targets), D.Choice{seat, i, D.JamTarget{t}}) == True{} : Bool} = U.and.cong_true(D.seat.eq(seat, seat), R.props.has_turn(H.host.props(U.hh(st, seat), seat)), LP.seat.refl(seat), U.held.turn(st, seat, shape, seated))
      +done : {R.stepped(R.settle(96n, R.answer.move.accepted(jam.ref(w, p, g, seat, targets), D.Choice{seat, i, D.JamTarget{t}}, True{}))) == A.stepped(S.state.stepped(out)) : A.RefStep()} = U.stepped.ref.local(R.settle(93n, R.RefState{jam.host(st, seat, t), R.EndItemInteraction{seat, False{}}, S.state.notes(jammed(st, seat, t))}), out, jam.close(st, seat, t, 92n, shape))
      Equal.trans(A.RefStep(), R.stepped(R.settle(96n, R.answer.move(jam.ref(w, p, g, seat, targets), D.Choice{seat, i, D.JamTarget{t}}))), A.stepped(S.state.stepped(out)), A.stepped(S.state.stepped(M.answer.choice(st, D.Choice{seat, i, D.JamTarget{t}}))), U.verify.accept(jam.ref(w, p, g, seat, targets), D.Choice{seat, i, D.JamTarget{t}}, out, e_v, done), Equal.cong(Maybe<&2, S.JamOption>, A.RefStep(), o => A.stepped(S.state.stepped(M.jam.selected(st, seat, o))), Some{S.JamAt{t}}, I.jam.nth(targets, i), Equal.sym(Maybe<&2, S.JamOption>, I.jam.nth(targets, i), Some{S.JamAt{t}}, sel)))
    case D.PickUp{}:
      match sel:
    case D.Shoot{x}:
      match sel:
    case D.UseItem{a, b}:
      match sel:
    case D.Grab{}:
      match sel:
    case D.Place{x}:
      match sel:
    case D.Steal{a, b, c}:
      match sel:

def jam.picked.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +g: S.Grabs, +picked: Maybe<&2, D.Choice>, +pk: U.Pick(seat, S.world.table(w), I.jam.moves(targets), picked), +e_any: {D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.jam.moves(targets)))) == True{} : Bool}, +shape: A.Shape(jam.at(w, p, seat, targets, Nil{}, g))) -> {R.stepped(R.settle(96n, R.answer.resolved(jam.ref(w, p, g, seat, targets), R.PlayerMove{D.Jamming{}}, D.resolve.choice(picked)))) == A.stepped(S.state.stepped(M.answer.resolved(jam.at(w, p, seat, targets, Nil{}, g), D.resolve.choice(picked)))) : A.RefStep()}:
  match picked:
    case None{}:
      GP.absurd({R.stepped(R.settle(96n, R.answer.resolved(jam.ref(w, p, g, seat, targets), R.PlayerMove{D.Jamming{}}, D.resolve.choice(None{})))) == A.stepped(S.state.stepped(M.answer.resolved(jam.at(w, p, seat, targets, Nil{}, g), D.resolve.choice(None{})))) : A.RefStep()}, T.clash.false_true(Equal.trans(Bool, False{}, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.jam.moves(targets)))), True{}, Equal.sym(Bool, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.jam.moves(targets)))), False{}, pk), e_any)))
    case Some{D.Choice{+s, +i, +m}}:
      match pk:
        case Tuple{+e_s, Tuple{+e_nth, +seated}}:
          Equal.trans(A.RefStep(), R.stepped(R.settle(96n, R.answer.move(jam.ref(w, p, g, seat, targets), D.Choice{s, i, m}))), R.stepped(R.settle(96n, R.answer.move(jam.ref(w, p, g, seat, targets), D.Choice{seat, i, m}))), A.stepped(S.state.stepped(M.answer.choice(jam.at(w, p, seat, targets, Nil{}, g), D.Choice{seat, i, m}))), Equal.cong(D.Seat, A.RefStep(), x => R.stepped(R.settle(96n, R.answer.move(jam.ref(w, p, g, seat, targets), D.Choice{x, i, m}))), s, seat, e_s), jam.move.answer(w, p, seat, targets, g, i, m, jam.sel(targets, i, m, e_nth), seated, shape))

def jam.any.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +any: Bool, +e: {D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.jam.moves(targets)))) == any : Bool}, +shape: A.Shape(jam.at(w, p, seat, targets, Nil{}, g))) -> {R.answer(R.RefState{U.hh(jam.at(w, p, seat, targets, n0, g), seat), R.Await{D.request.choose.any(any, U.menu.of(S.world.table(w), seat, I.jam.moves(targets))), D.Playing{seat, D.Jamming{}}, R.PlayerMove{D.Jamming{}}}, n0}, n) == A.stepped(M.answer.request(jam.at(w, p, seat, targets, n0, g), n, D.request.choose.any(any, U.menu.of(S.world.table(w), seat, I.jam.moves(targets))))) : A.RefStep()}:
  match w any:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} True{}:
      jam.picked.answer(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, targets, g, D.choose(U.menu.of(table, seat, I.jam.moves(targets)), n), U.pick.choose(table, seat, I.jam.moves(targets), n), e, shape)
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} False{}:
      Equal.cong(Bool, A.RefStep(), b => D.Stepped{R.RefState{U.hh(jam.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, targets, n0, g), seat), R.Await{D.request.choose.any(b, U.menu.of(table, seat, I.jam.moves(targets))), D.Playing{seat, D.Jamming{}}, R.PlayerMove{D.Jamming{}}}, n0}, Nil{}}, False{}, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(table, seat, I.jam.moves(targets)))), Equal.sym(Bool, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(table, seat, I.jam.moves(targets)))), False{}, e))

def jam.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +shape: A.Shape(jam.at(w, p, seat, targets, n0, g))) -> {A.ref_answer(A.ref(jam.at(w, p, seat, targets, n0, g)), n) == A.stepped(M.answer(jam.at(w, p, seat, targets, n0, g), n)) : A.RefStep()}:
  match w:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      jam.any.answer(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, targets, n0, g, n, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(table, seat, I.jam.moves(targets)))), {==}, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.JamPick{seat, targets}, n0, g, S.JamPick{seat, targets}, Nil{}, shape))

def valid.jam.move(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +g: S.Grabs, +i: Nat, +m: D.Move, +sel: JamSel(targets, i, m), +vpre: LP.VPre(jam.at(w, p, seat, targets, Nil{}, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}) -> A.ValidItems(A.machine_step_state(S.state.stepped(M.answer.choice(jam.at(w, p, seat, targets, Nil{}, g), D.Choice{seat, i, m})))):
  match m:
    case D.JamTarget{+t}:
      +st : S.State = jam.at(w, p, seat, targets, Nil{}, g)
      +vpre1 : LP.VPre(jammed(st, seat, t)) = LP.vpre.phase(S.state.set_players(st, S.players.set_jam(p, t, S.Jammed{})), S.JamPick{seat, targets}, S.state.notes(jammed(st, seat, t)), LP.vpre.jam(st, t, S.Jammed{}, vpre))
      %Equal.sym(Maybe<&2, S.JamOption>, I.jam.nth(targets, i), Some{S.JamAt{t}}, sel) : A.ValidItems(A.machine_step_state(S.state.stepped(M.jam.selected(st, seat, _))))
      U.valid.resume(jammed(st, seat, t), seat, vpre1, ready)
    case D.PickUp{}:
      match sel:
    case D.Shoot{x}:
      match sel:
    case D.UseItem{a, b}:
      match sel:
    case D.Grab{}:
      match sel:
    case D.Place{x}:
      match sel:
    case D.Steal{a, b, c}:
      match sel:

def valid.jam.picked(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +g: S.Grabs, +picked: Maybe<&2, D.Choice>, +pk: U.Pick(seat, S.world.table(w), I.jam.moves(targets), picked), +e_any: {D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.jam.moves(targets)))) == True{} : Bool}, +vpre: LP.VPre(jam.at(w, p, seat, targets, Nil{}, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}) -> A.ValidItems(A.machine_step_state(S.state.stepped(M.answer.resolved(jam.at(w, p, seat, targets, Nil{}, g), D.resolve.choice(picked))))):
  match picked:
    case None{}:
      GP.absurd(A.ValidItems(A.machine_step_state(S.state.stepped(M.answer.resolved(jam.at(w, p, seat, targets, Nil{}, g), D.resolve.choice(None{}))))), T.clash.false_true(Equal.trans(Bool, False{}, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.jam.moves(targets)))), True{}, Equal.sym(Bool, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.jam.moves(targets)))), False{}, pk), e_any)))
    case Some{D.Choice{+s, +i, +m}}:
      match pk:
        case Tuple{+e_s, Tuple{+e_nth, +seated}}:
          valid.jam.move(w, p, seat, targets, g, i, m, jam.sel(targets, i, m, e_nth), vpre, ready)

def valid.jam.any(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +any: Bool, +e: {D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.jam.moves(targets)))) == any : Bool}, +valid: A.ValidItems(jam.at(w, p, seat, targets, n0, g)), +vpre: LP.VPre(jam.at(w, p, seat, targets, Nil{}, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}) -> A.ValidItems(A.machine_step_state(M.answer.request(jam.at(w, p, seat, targets, n0, g), n, D.request.choose.any(any, U.menu.of(S.world.table(w), seat, I.jam.moves(targets)))))):
  match any:
    case True{}:
      valid.jam.picked(w, p, seat, targets, g, D.choose(U.menu.of(S.world.table(w), seat, I.jam.moves(targets)), n), U.pick.choose(S.world.table(w), seat, I.jam.moves(targets), n), e, vpre, ready)
    case False{}:
      valid

def valid.jam(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +valid: A.ValidItems(jam.at(w, p, seat, targets, n0, g))) -> A.ValidItems(A.next(jam.at(w, p, seat, targets, n0, g), n)):
  match valid:
    case Tuple{+normal, Tuple{+shape, Tuple{+bounded, +ready}}}:
      +vpre : LP.VPre(jam.at(w, p, seat, targets, Nil{}, g)) = (ISP.shape.move(w, p, S.JamPick{seat, targets}, n0, g, S.JamPick{seat, targets}, Nil{}, shape), bounded)
      valid.jam.any(w, p, seat, targets, n0, g, n, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.jam.moves(targets)))), {==}, (normal, (shape, (bounded, ready))), vpre, ready)

# step_matches at JamPick with items.
def step.jam(+world: S.World, +players: S.Players, +actor: D.Seat, +targets: List<&2, S.JamOption>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.ValidItems(S.State{world, players, S.JamPick{actor, targets}, notes, grabs})) -> A.SimulationItems(S.State{world, players, S.JamPick{actor, targets}, notes, grabs}, n):
  ISP.simulation.items(jam.at(world, players, actor, targets, notes, grabs), n, jam.answer(world, players, actor, targets, notes, grabs, n, A.valid_items.shape(jam.at(world, players, actor, targets, notes, grabs), valid)), valid.jam(world, players, actor, targets, notes, grabs, n, valid))

