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


# StealPick: the stolen item's use. The stored picks are the recomputed
# ones (the item normal form), so every pick names an item its owner holds.

def steal.picks(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat) -> List<&2, S.StealOption>:
  I.steal.for(S.State{w, p, S.Ended{}, Nil{}, g}, seat)


def steal.at(+w: S.World, +p: S.Players, +seat: D.Seat, +n: A.Notes(), +g: S.Grabs) -> S.State:
  S.State{w, p, S.StealPick{seat, steal.picks(w, p, g, seat)}, n, g}


def steal.ref(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat) -> R.RefState:
  R.RefState{U.hh(steal.at(w, p, seat, Nil{}, g), seat), R.Await{D.Choose{U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat)))}, D.Playing{seat, D.Stealing{}}, R.PlayerMove{D.Stealing{}}}, Nil{}}


def StealSel(+picks: List<&2, S.StealOption>, +i: Nat, +m: D.Move) -> Data:
  match m:
    case D.Steal{+owner, +slot, +item}:
      {I.steal.nth(picks, i) == Some{S.Pick{owner, slot, item}} : Maybe<&2, S.StealOption>}
    case _:
      Empty


def steal.sel.tail(+o: S.StealOption, +os: List<&2, S.StealOption>, +j: Nat, +m: D.Move, +sel: StealSel(os, j, m)) -> StealSel(o <> os, 1n+j, m):
  match m:
    case D.Steal{+owner, +slot, +item}:
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
    case D.JamTarget{x}:
      match sel:


def steal.sel(+picks: List<&2, S.StealOption>, +i: Nat, +m: D.Move, +e: {Q.nth(D.Move, I.steal.moves(picks), i) == Some{m} : Maybe<&2, D.Move>}) -> StealSel(picks, i, m):
  match picks i:
    case Nil{} i:
      GP.absurd(StealSel(Nil{}, i, m), U.none.some(m, e))
    case S.Pick{+owner, +slot, +item} <> +os 0n:
      %U.some.inj(D.Move, D.Steal{owner, slot, item}, m, e) : StealSel(S.Pick{owner, slot, item} <> os, 0n, _)
      {==}
    case S.Pick{+owner, +slot, +item} <> +os 1n+j:
      steal.sel.tail(S.Pick{owner, slot, item}, os, j, m, steal.sel(os, j, m, e))

# Every steal pick names an item its owner holds in that slot.

def PickOk(+p: S.Players, +o: S.StealOption) -> Data:
  match o:
    case S.Pick{+owner, +slot, +item}:
      {D.slots.get(I.seat.slots(p, owner), slot) == Some{item} : Maybe<&2, D.Item>}


def AllOk(+p: S.Players, +xs: List<&2, S.StealOption>) -> Data:
  match xs:
    case Nil{}:
      Unit
    case +x <> +rest:
      Sigma<&2, &2, PickOk(p, x), _ => AllOk(p, rest)>


def EntriesOk(+p: S.Players, +es: List<&2, D.At<&2, D.Slots>>) -> Data:
  match es:
    case Nil{}:
      Unit
    case D.At{+o, +inv} <> +rest:
      Sigma<&2, &2, {I.seat.slots(p, o) == inv : D.Slots}, _ => EntriesOk(p, rest)>


def entries.claim(+s: S.State) -> Type:
  EntriesOk(S.state.players(s), D.ring.entries(D.Slots, S.players.slots(S.state.players(s))))


def entries.ok(+s: S.State, +shape: A.Shape(s)) -> entries.claim(s):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          ({==}, ({==}, Unit{}))
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(entries.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(entries.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          ({==}, ({==}, ({==}, Unit{})))
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(entries.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(entries.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          ({==}, ({==}, ({==}, ({==}, Unit{}))))
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(entries.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(entries.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.three_four(e_players))


def ok.keep(+p: S.Players, +b: Bool, +x: S.StealOption, +rest: List<&2, S.StealOption>, +h: PickOk(p, x), +ar: AllOk(p, rest)) -> AllOk(p, I.keep(S.StealOption, b, x, rest)):
  match b:
    case True{}:
      (h, ar)
    case False{}:
      ar


def ok.here(+p: S.Players, +found: Maybe<&2, D.Item>, +inv: D.Slots, +owner: D.Seat, +sl: D.Slot, +sw: Bool, +tg: Bool, +rest: List<&2, S.StealOption>, +ef: {D.slots.get(inv, sl) == found : Maybe<&2, D.Item>}, +e_inv: {I.seat.slots(p, owner) == inv : D.Slots}, +ar: AllOk(p, rest)) -> AllOk(p, I.steal.here(found, owner, sl, sw, tg, rest)):
  match found:
    case None{}:
      ar
    case Some{+item}:
      ok.keep(p, I.steal.fits(item, sw, tg), S.Pick{owner, sl, item}, rest, Equal.trans(Maybe<&2, D.Item>, D.slots.get(I.seat.slots(p, owner), sl), D.slots.get(inv, sl), Some{item}, Equal.cong(D.Slots, Maybe<&2, D.Item>, z => D.slots.get(z, sl), I.seat.slots(p, owner), inv, e_inv), ef), ar)


def ok.slots(+p: S.Players, +slots: List<&2, D.Slot>, +inv: D.Slots, +owner: D.Seat, +sw: Bool, +tg: Bool, +e_inv: {I.seat.slots(p, owner) == inv : D.Slots}) -> AllOk(p, I.steal.slots(slots, inv, owner, sw, tg)):
  match slots:
    case Nil{}:
      Unit{}
    case +sl <> +rest:
      ok.here(p, D.slots.get(inv, sl), inv, owner, sl, sw, tg, I.steal.slots(rest, inv, owner, sw, tg), {==}, e_inv, ok.slots(p, rest, inv, owner, sw, tg, e_inv))


def ok.append(+p: S.Players, +xs: List<&2, S.StealOption>, +ys: List<&2, S.StealOption>, +ax: AllOk(p, xs), +ay: AllOk(p, ys)) -> AllOk(p, List.append(&2, S.StealOption, xs, ys)):
  match xs:
    case Nil{}:
      ay
    case +x <> +rest:
      match ax:
        case Tuple{+h, +more}:
          (h, ok.append(p, rest, ys, more, ay))


def ok.owner(+p: S.Players, +own: Bool, +o: D.Seat, +inv: D.Slots, +sw: Bool, +tg: Bool, +rest: List<&2, S.StealOption>, +e_inv: {I.seat.slots(p, o) == inv : D.Slots}, +ar: AllOk(p, rest)) -> AllOk(p, I.steal.owner(own, o, inv, sw, tg, rest)):
  match own:
    case True{}:
      ar
    case False{}:
      ok.append(p, I.steal.slots(I.slot.order(), inv, o, sw, tg), rest, ok.slots(p, I.slot.order(), inv, o, sw, tg, e_inv), ar)


def ok.owners(+p: S.Players, +es: List<&2, D.At<&2, D.Slots>>, +thief: D.Seat, +sw: Bool, +tg: Bool, +eo: EntriesOk(p, es)) -> AllOk(p, I.steal.owners(es, thief, sw, tg)):
  match es:
    case Nil{}:
      Unit{}
    case D.At{+o, +inv} <> +rest:
      match eo:
        case Tuple{+e_inv, +more}:
          ok.owner(p, D.seat.eq(o, thief), o, inv, sw, tg, I.steal.owners(rest, thief, sw, tg), e_inv, ok.owners(p, rest, thief, sw, tg, more))


def steal.none(+m: Maybe<&2, S.StealOption>) -> Type:
  match m:
    case None{}:
      Empty
    case Some{x}:
      Unit


def steal.clash(+b: S.StealOption, +e: {None{} == Some{b} : Maybe<&2, S.StealOption>}) -> Empty:
  %Equal.sym(Maybe<&2, S.StealOption>, None{}, Some{b}, e) : steal.none(_)
  Unit{}


def ok.nth(+p: S.Players, +xs: List<&2, S.StealOption>, +i: Nat, +o: S.StealOption, +all: AllOk(p, xs), +e: {I.steal.nth(xs, i) == Some{o} : Maybe<&2, S.StealOption>}) -> PickOk(p, o):
  match xs i:
    case Nil{} i:
      GP.absurd(PickOk(p, o), steal.clash(o, e))
    case +x <> +rest 0n:
      match all:
        case Tuple{+here, _}:
          %U.some.inj(S.StealOption, x, o, e) : PickOk(p, _)
          here
    case +x <> +rest 1n+j:
      match all:
        case Tuple{_, +more}:
          ok.nth(p, rest, j, o, more, e)


def steal.owned(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +i: Nat, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +sel: {I.steal.nth(steal.picks(w, p, g, seat), i) == Some{S.Pick{owner, slot, item}} : Maybe<&2, S.StealOption>}, +shape: A.Shape(steal.at(w, p, seat, Nil{}, g))) -> {G.alive(G.item.count(G.slots.list(RI.props.slots(H.host.props(U.hh(steal.at(w, p, seat, Nil{}, g), seat), owner))), item)) == True{} : Bool}:
  +st : S.State = steal.at(w, p, seat, Nil{}, g)
  +all : AllOk(p, steal.picks(w, p, g, seat)) = ok.owners(p, D.ring.entries(D.Slots, S.players.slots(p)), seat, S.world.sawed(w), I.jam.any(I.jam.for(S.State{w, p, S.Ended{}, Nil{}, g}, seat)), entries.ok(st, shape))
  +held : {D.slots.get(I.seat.slots(p, owner), slot) == Some{item} : Maybe<&2, D.Item>} = ok.nth(p, steal.picks(w, p, g, seat), i, S.Pick{owner, slot, item}, all, sel)
  Equal.trans(Bool, G.alive(G.item.count(G.slots.list(RI.props.slots(H.host.props(U.hh(st, seat), owner))), item)), G.alive(G.item.count(G.slots.list(I.seat.slots(p, owner)), item)), True{}, Equal.cong(D.Slots, Bool, x => G.alive(G.item.count(G.slots.list(x), item)), RI.props.slots(H.host.props(U.hh(st, seat), owner)), I.seat.slots(p, owner), GP.slots.eq(st, owner, shape)), U.count.slot(I.seat.slots(p, owner), slot, item, held))


def steal.move.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +i: Nat, +m: D.Move, +sel: StealSel(steal.picks(w, p, g, seat), i, m), +seated: P.seated(S.world.table(w), seat), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(steal.at(w, p, seat, Nil{}, g)), win: T.WinClosure()) -> {R.stepped(R.settle(96n, R.answer.move(steal.ref(w, p, g, seat), D.Choice{seat, i, m}))) == A.stepped(S.state.stepped(M.answer.choice(steal.at(w, p, seat, Nil{}, g), D.Choice{seat, i, m}))) : A.RefStep()}:
  match w m:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.Steal{+owner, +slot, +item}:
      +st : S.State = steal.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g)
      +out : S.State = M.item.use(st, seat, owner, slot, item)
      +own : Bool = G.alive(G.item.count(G.slots.list(RI.props.slots(H.host.props(U.hh(st, seat), owner))), item))
      +e_v : {R.VerifyPacket(steal.ref(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), D.Choice{seat, i, D.Steal{owner, slot, item}}) == True{} : Bool} = U.and.cong_true(R.current.eq(turn, seat), Bool.and(R.props.has_turn(H.host.props(U.hh(st, seat), seat)), own), ready, U.and.cong_true(R.props.has_turn(H.host.props(U.hh(st, seat), seat)), own, U.held.turn(st, seat, shape, seated), steal.owned(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, g, i, owner, slot, item, sel, shape)))
      +done : {R.stepped(R.settle(96n, R.answer.move.accepted(steal.ref(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), D.Choice{seat, i, D.Steal{owner, slot, item}}, True{}))) == A.stepped(S.state.stepped(out)) : A.RefStep()} = U.stepped.ref.local(R.settle(95n, R.RefState{U.hh(st, seat), R.CheckIfEndingTurnAfterItemUse{seat, owner, slot, item}, Nil{}}), out, U.use.close(item, st, seat, owner, slot, 62n, shape, win))
      Equal.trans(A.RefStep(), R.stepped(R.settle(96n, R.answer.move(steal.ref(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), D.Choice{seat, i, D.Steal{owner, slot, item}}))), A.stepped(S.state.stepped(out)), A.stepped(S.state.stepped(M.answer.choice(st, D.Choice{seat, i, D.Steal{owner, slot, item}}))), U.verify.accept(steal.ref(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), D.Choice{seat, i, D.Steal{owner, slot, item}}, out, e_v, done), Equal.cong(Maybe<&2, S.StealOption>, A.RefStep(), o => A.stepped(S.state.stepped(M.steal.selected(st, seat, o))), Some{S.Pick{owner, slot, item}}, I.steal.nth(steal.picks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), i), Equal.sym(Maybe<&2, S.StealOption>, I.steal.nth(steal.picks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat), i), Some{S.Pick{owner, slot, item}}, sel)))
    case +w2 D.PickUp{}:
      match sel:
    case +w2 D.Shoot{x}:
      match sel:
    case +w2 D.UseItem{a, b}:
      match sel:
    case +w2 D.Grab{}:
      match sel:
    case +w2 D.Place{x}:
      match sel:
    case +w2 D.JamTarget{x}:
      match sel:

def steal.picked.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +picked: Maybe<&2, D.Choice>, +pk: U.Pick(seat, S.world.table(w), I.steal.moves(steal.picks(w, p, g, seat)), picked), +e_any: {D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))))) == True{} : Bool}, +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(steal.at(w, p, seat, Nil{}, g)), win: T.WinClosure()) -> {R.stepped(R.settle(96n, R.answer.resolved(steal.ref(w, p, g, seat), R.PlayerMove{D.Stealing{}}, D.resolve.choice(picked)))) == A.stepped(S.state.stepped(M.answer.resolved(steal.at(w, p, seat, Nil{}, g), D.resolve.choice(picked)))) : A.RefStep()}:
  match picked:
    case None{}:
      GP.absurd({R.stepped(R.settle(96n, R.answer.resolved(steal.ref(w, p, g, seat), R.PlayerMove{D.Stealing{}}, D.resolve.choice(None{})))) == A.stepped(S.state.stepped(M.answer.resolved(steal.at(w, p, seat, Nil{}, g), D.resolve.choice(None{})))) : A.RefStep()}, T.clash.false_true(Equal.trans(Bool, False{}, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))))), True{}, Equal.sym(Bool, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))))), False{}, pk), e_any)))
    case Some{D.Choice{+s, +i, +m}}:
      match pk:
        case Tuple{+e_s, Tuple{+e_nth, +seated}}:
          Equal.trans(A.RefStep(), R.stepped(R.settle(96n, R.answer.move(steal.ref(w, p, g, seat), D.Choice{s, i, m}))), R.stepped(R.settle(96n, R.answer.move(steal.ref(w, p, g, seat), D.Choice{seat, i, m}))), A.stepped(S.state.stepped(M.answer.choice(steal.at(w, p, seat, Nil{}, g), D.Choice{seat, i, m}))), Equal.cong(D.Seat, A.RefStep(), x => R.stepped(R.settle(96n, R.answer.move(steal.ref(w, p, g, seat), D.Choice{x, i, m}))), s, seat, e_s), steal.move.answer(w, p, seat, g, i, m, steal.sel(steal.picks(w, p, g, seat), i, m, e_nth), seated, ready, shape, win))

def steal.any.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +any: Bool, +e: {D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))))) == any : Bool}, +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(steal.at(w, p, seat, Nil{}, g)), win: T.WinClosure()) -> {R.answer(R.RefState{U.hh(steal.at(w, p, seat, n0, g), seat), R.Await{D.request.choose.any(any, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat)))), D.Playing{seat, D.Stealing{}}, R.PlayerMove{D.Stealing{}}}, n0}, n) == A.stepped(M.answer.request(steal.at(w, p, seat, n0, g), n, D.request.choose.any(any, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat)))))) : A.RefStep()}:
  match w any:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} True{}:
      steal.picked.answer(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, g, D.choose(U.menu.of(table, seat, I.steal.moves(steal.picks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat))), n), U.pick.choose(table, seat, I.steal.moves(steal.picks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)), n), e, ready, shape, win)
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} False{}:
      Equal.cong(Bool, A.RefStep(), b => D.Stepped{R.RefState{U.hh(steal.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, n0, g), seat), R.Await{D.request.choose.any(b, U.menu.of(table, seat, I.steal.moves(steal.picks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)))), D.Playing{seat, D.Stealing{}}, R.PlayerMove{D.Stealing{}}}, n0}, Nil{}}, False{}, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(table, seat, I.steal.moves(steal.picks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat))))), Equal.sym(Bool, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(table, seat, I.steal.moves(steal.picks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat))))), False{}, e))

def steal.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +shape: A.Shape(steal.at(w, p, seat, n0, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, win: T.WinClosure()) -> {A.ref_answer(A.ref(steal.at(w, p, seat, n0, g)), n) == A.stepped(M.answer(steal.at(w, p, seat, n0, g), n)) : A.RefStep()}:
  match w:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      steal.any.answer(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, n0, g, n, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(table, seat, I.steal.moves(steal.picks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat))))), {==}, ready, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.StealPick{seat, steal.picks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)}, n0, g, S.StealPick{seat, steal.picks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, g, seat)}, Nil{}, shape), win)

def valid.steal.move(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +i: Nat, +m: D.Move, +sel: StealSel(steal.picks(w, p, g, seat), i, m), +vpre: LP.VPre(steal.at(w, p, seat, Nil{}, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(A.machine_step_state(S.state.stepped(M.answer.choice(steal.at(w, p, seat, Nil{}, g), D.Choice{seat, i, m})))):
  match m:
    case D.Steal{+owner, +slot, +item}:
      %Equal.sym(Maybe<&2, S.StealOption>, I.steal.nth(steal.picks(w, p, g, seat), i), Some{S.Pick{owner, slot, item}}, sel) : A.ValidItems(A.machine_step_state(S.state.stepped(M.steal.selected(steal.at(w, p, seat, Nil{}, g), seat, _))))
      U.valid.use(item, steal.at(w, p, seat, Nil{}, g), seat, owner, slot, vpre, ready, winv)
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
    case D.JamTarget{x}:
      match sel:

def valid.steal.picked(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +picked: Maybe<&2, D.Choice>, +pk: U.Pick(seat, S.world.table(w), I.steal.moves(steal.picks(w, p, g, seat)), picked), +e_any: {D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))))) == True{} : Bool}, +vpre: LP.VPre(steal.at(w, p, seat, Nil{}, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(A.machine_step_state(S.state.stepped(M.answer.resolved(steal.at(w, p, seat, Nil{}, g), D.resolve.choice(picked))))):
  match picked:
    case None{}:
      GP.absurd(A.ValidItems(A.machine_step_state(S.state.stepped(M.answer.resolved(steal.at(w, p, seat, Nil{}, g), D.resolve.choice(None{}))))), T.clash.false_true(Equal.trans(Bool, False{}, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))))), True{}, Equal.sym(Bool, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))))), False{}, pk), e_any)))
    case Some{D.Choice{+s, +i, +m}}:
      match pk:
        case Tuple{+e_s, Tuple{+e_nth, +seated}}:
          valid.steal.move(w, p, seat, g, i, m, steal.sel(steal.picks(w, p, g, seat), i, m, e_nth), vpre, ready, winv)

def valid.steal.any(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +any: Bool, +e: {D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))))) == any : Bool}, +valid: A.ValidItems(steal.at(w, p, seat, n0, g)), +vpre: LP.VPre(steal.at(w, p, seat, Nil{}, g)), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, winv: T.WinValid()) -> A.ValidItems(A.machine_step_state(M.answer.request(steal.at(w, p, seat, n0, g), n, D.request.choose.any(any, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))))))):
  match any:
    case True{}:
      valid.steal.picked(w, p, seat, g, D.choose(U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))), n), U.pick.choose(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat)), n), e, vpre, ready, winv)
    case False{}:
      valid

def valid.steal(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +valid: A.ValidItems(steal.at(w, p, seat, n0, g)), winv: T.WinValid()) -> A.ValidItems(A.next(steal.at(w, p, seat, n0, g), n)):
  match valid:
    case Tuple{+normal, Tuple{+shape, Tuple{+bounded, +ready}}}:
      +vpre : LP.VPre(steal.at(w, p, seat, Nil{}, g)) = (ISP.shape.move(w, p, S.StealPick{seat, steal.picks(w, p, g, seat)}, n0, g, S.StealPick{seat, steal.picks(w, p, g, seat)}, Nil{}, shape), bounded)
      valid.steal.any(w, p, seat, n0, g, n, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(S.world.table(w), seat, I.steal.moves(steal.picks(w, p, g, seat))))), {==}, (normal, (shape, (bounded, ready))), vpre, ready, winv)

# step_matches at StealPick with items, given the win's closure and validity.
def step.steal(+world: S.World, +players: S.Players, +actor: D.Seat, +picks: List<&2, S.StealOption>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.ValidItems(S.State{world, players, S.StealPick{actor, picks}, notes, grabs}), win: T.WinClosure(), winv: T.WinValid()) -> A.SimulationItems(S.State{world, players, S.StealPick{actor, picks}, notes, grabs}, n):
  +normal : A.ValidItems(steal.at(world, players, actor, notes, grabs)) = ISP.valid.normalized(S.State{world, players, S.StealPick{actor, picks}, notes, grabs}, valid)
  %A.valid_items.normal(S.State{world, players, S.StealPick{actor, picks}, notes, grabs}, valid) : A.SimulationItems(_, n)
  ISP.simulation.items(steal.at(world, players, actor, notes, grabs), n, steal.answer(world, players, actor, notes, grabs, n, A.valid_items.shape(steal.at(world, players, actor, notes, grabs), normal), A.valid_items.ready(steal.at(world, players, actor, notes, grabs), normal), win), valid.steal(world, players, actor, notes, grabs, n, normal, winv))


# NeedPhone: the burner phone's shell index, then the clue. A gun under four
# shells has no index to draw (Stuck on both sides).

def phone.at(+w: S.World, +p: S.Players, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +n: A.Notes(), +g: S.Grabs) -> S.State:
  S.State{w, p, S.NeedPhone{seat, owner, slot}, n, g}


def phone.answer(+w: S.World, +p: S.Players, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +shape: A.Shape(phone.at(w, p, seat, owner, slot, n0, g)), win: T.WinClosure()) -> {A.ref_answer(A.ref(phone.at(w, p, seat, owner, slot, n0, g)), n) == A.stepped(M.answer(phone.at(w, p, seat, owner, slot, n0, g), n)) : A.RefStep()}:
  match w:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}:
      {==}
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> Nil{}, +shown, +deck}:
      {==}
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> Nil{}, +shown, +deck}:
      {==}
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> +c <> Nil{}, +shown, +deck}:
      {==}
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> +c <> +d <> +rest, +shown, +deck}:
      +st : S.State = phone.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> b <> c <> d <> rest, shown, deck}, p, seat, owner, slot, Nil{}, g)
      U.stepped.ref.local(R.settle(96n, R.RefState{U.hh(st, seat), R._GetBurnerPhone_Shell{U.item.packet(seat, owner, slot, D.Phone{}, False{}, None{}), D.draw.value(D.Range{2n, List.length(&2, D.Shell, rest)}, n)}, Nil{}}), M.item.clue(st, seat, owner, slot, D.draw.value(D.Range{2n, List.length(&2, D.Shell, rest)}, n)), U.clue.close(st, seat, owner, slot, D.draw.value(D.Range{2n, List.length(&2, D.Shell, rest)}, n), 65n, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> b <> c <> d <> rest, shown, deck}, p, S.NeedPhone{seat, owner, slot}, n0, g, S.NeedPhone{seat, owner, slot}, Nil{}, shape), win))


def valid.phone(+w: S.World, +p: S.Players, +seat: D.Seat, +owner: D.Seat, +slot: D.Slot, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +valid: A.ValidItems(phone.at(w, p, seat, owner, slot, n0, g)), winv: T.WinValid()) -> A.ValidItems(A.next(phone.at(w, p, seat, owner, slot, n0, g), n)):
  match w:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, Nil{}, +shown, +deck}:
      valid
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> Nil{}, +shown, +deck}:
      valid
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> Nil{}, +shown, +deck}:
      valid
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> +c <> Nil{}, +shown, +deck}:
      valid
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +a <> +b <> +c <> +d <> +rest, +shown, +deck}:
      match valid:
        case Tuple{+normal, Tuple{+shape, Tuple{+bounded, +ready}}}:
          +st : S.State = phone.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> b <> c <> d <> rest, shown, deck}, p, seat, owner, slot, Nil{}, g)
          U.valid.clue(st, seat, owner, slot, D.draw.value(D.Range{2n, List.length(&2, D.Shell, rest)}, n), (ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, a <> b <> c <> d <> rest, shown, deck}, p, S.NeedPhone{seat, owner, slot}, n0, g, S.NeedPhone{seat, owner, slot}, Nil{}, shape), bounded), ready, winv)

# step_matches at NeedPhone with items, given the win's closure and validity.
def step.phone(+world: S.World, +players: S.Players, +actor: D.Seat, +owner: D.Seat, +slot: D.Slot, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.ValidItems(S.State{world, players, S.NeedPhone{actor, owner, slot}, notes, grabs}), win: T.WinClosure(), winv: T.WinValid()) -> A.SimulationItems(S.State{world, players, S.NeedPhone{actor, owner, slot}, notes, grabs}, n):
  ISP.simulation.items(phone.at(world, players, actor, owner, slot, notes, grabs), n, phone.answer(world, players, actor, owner, slot, notes, grabs, n, A.valid_items.shape(phone.at(world, players, actor, owner, slot, notes, grabs), valid), win), valid.phone(world, players, actor, owner, slot, notes, grabs, n, valid, winv))


# NeedTurnAmount: the item amount for the grab round that ends a turn, then
# the turn end (MainRoutine_UserEndTurn).

def amount.at(+w: S.World, +p: S.Players, +from: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>, +n: A.Notes(), +g: S.Grabs) -> S.State:
  S.State{w, p, S.NeedTurnAmount{from, passing, winner}, n, g}


def amount.answer(+w: S.World, +p: S.Players, +from: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +shape: A.Shape(amount.at(w, p, from, passing, winner, n0, g)), win: T.WinClosure()) -> {A.ref_answer(A.ref(amount.at(w, p, from, passing, winner, n0, g)), n) == A.stepped(M.answer(amount.at(w, p, from, passing, winner, n0, g), n)) : A.RefStep()}:
  match w:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      +s2 : S.State = S.state.set_world(amount.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, from, passing, winner, Nil{}, g), S.world.set_item_amount(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.draw.value(D.table.amount_range(table), n)))
      U.stepped.ref.local(R.settle(96n, R.RefState{T.qh(s2), R.MainRoutine_UserEndTurn{T.end.packet(s2, from, passing, winner)}, Nil{}}), M.turn.winner(s2, from, passing, winner), T.main.close(winner, s2, from, passing, 72n, AP.shape.world(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, S.world.set_item_amount(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.draw.value(D.table.amount_range(table), n)), p, S.NeedTurnAmount{from, passing, winner}, Nil{}, g, {==}, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedTurnAmount{from, passing, winner}, n0, g, S.NeedTurnAmount{from, passing, winner}, Nil{}, shape)), win))


def valid.amount(+w: S.World, +p: S.Players, +from: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>, +n0: A.Notes(), +g: S.Grabs, +n: Nat, +valid: A.ValidItems(amount.at(w, p, from, passing, winner, n0, g)), winv: T.WinValid()) -> A.ValidItems(A.next(amount.at(w, p, from, passing, winner, n0, g), n)):
  match w:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}:
      match valid:
        case Tuple{+normal, Tuple{+shape, Tuple{+bounded, +ready}}}:
          T.valid.main(winner, S.state.set_world(amount.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, from, passing, winner, Nil{}, g), S.world.set_item_amount(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.draw.value(D.table.amount_range(table), n))), from, passing, (AP.shape.world(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, S.world.set_item_amount(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.draw.value(D.table.amount_range(table), n)), p, S.NeedTurnAmount{from, passing, winner}, Nil{}, g, {==}, ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, S.NeedTurnAmount{from, passing, winner}, n0, g, S.NeedTurnAmount{from, passing, winner}, Nil{}, shape)), bounded), winv)

# step_matches at NeedTurnAmount with items, given the win's closure and validity.
def step.amount(+world: S.World, +players: S.Players, +from: D.Seat, +passing: Bool, +winner: Maybe<&2, D.Seat>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.ValidItems(S.State{world, players, S.NeedTurnAmount{from, passing, winner}, notes, grabs}), win: T.WinClosure(), winv: T.WinValid()) -> A.SimulationItems(S.State{world, players, S.NeedTurnAmount{from, passing, winner}, notes, grabs}, n):
  ISP.simulation.items(amount.at(world, players, from, passing, winner, notes, grabs), n, amount.answer(world, players, from, passing, winner, notes, grabs, n, A.valid_items.shape(amount.at(world, players, from, passing, winner, notes, grabs), valid), win), valid.amount(world, players, from, passing, winner, notes, grabs, n, valid, winv))

