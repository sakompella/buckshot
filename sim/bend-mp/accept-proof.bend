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
import ./grab-proof.bend as GP
import ./item-step-proof.bend as ISP
import ./turn-proof.bend as T
import ./use-proof.bend as U
import ./primitive.bend as P
import ./load-proof.bend as LP
import ./aim-proof.bend as AP
import ./pick-proof.bend as PK

# legal_accepted for every config: at a valid state, every move the machine
# offers passes the host's VerifyPacket. The VerifyPacket facts are the ones
# the step proofs use (U.idle.*.verify and the like); here the offered choice
# is read back from the request, by the phase.

def Accepts(+s: S.State, +n: Nat, +choice: D.Choice) -> Type:
  @+selected:{D.resolve(M.request(s), n) == D.Chose{choice} : D.Resolved} -> {R.VerifyPacket(A.ref(s), choice) == True{} : Bool}

def resolved.chose(r: D.Resolved) -> Bool:
  match r:
    case D.Chose{_}:
      True{}
    case _:
      False{}

def resolved.choice(r: D.Resolved, fallback: D.Choice) -> D.Choice:
  match r:
    case D.Chose{c}:
      c
    case _:
      fallback

def unanswerable(+choice: D.Choice, +sel: {D.Unanswerable{} == D.Chose{choice} : D.Resolved}) -> Empty:
  T.clash.false_true(Equal.cong(D.Resolved, Bool, resolved.chose, D.Unanswerable{}, D.Chose{choice}, sel))

def drawn(+v: Nat, +choice: D.Choice, +sel: {D.Drawn{v} == D.Chose{choice} : D.Resolved}) -> Empty:
  T.clash.false_true(Equal.cong(D.Resolved, Bool, resolved.chose, D.Drawn{v}, D.Chose{choice}, sel))

def chose.inj(+c: D.Choice, +choice: D.Choice, +sel: {D.Chose{c} == D.Chose{choice} : D.Resolved}) -> {c == choice : D.Choice}:
  Equal.cong(D.Resolved, D.Choice, r => resolved.choice(r, c), D.Chose{c}, D.Chose{choice}, sel)

# A single seat's menu resolves only to a choice of that seat and one of its
# moves (U.pick.choose).
def picked.on(+seat: D.Seat, +table: D.Table, +moves: List<&2, D.Move>, +picked: Maybe<&2, D.Choice>, +pk: U.Pick(seat, table, moves, picked), +choice: D.Choice, +sel: {D.resolve.choice(picked) == D.Chose{choice} : D.Resolved}) -> U.OnSeat(seat, table, moves, choice):
  match picked:
    case None{}:
      GP.absurd(U.OnSeat(seat, table, moves, choice), unanswerable(choice, sel))
    case Some{+c}:
      %chose.inj(c, choice, sel) : U.OnSeat(seat, table, moves, _)
      pk

def any.on(+seat: D.Seat, +table: D.Table, +moves: List<&2, D.Move>, +n: Nat, +choice: D.Choice, +any: Bool, +sel: {D.resolve(D.request.choose.any(any, U.menu.of(table, seat, moves)), n) == D.Chose{choice} : D.Resolved}) -> U.OnSeat(seat, table, moves, choice):
  match any:
    case True{}:
      picked.on(seat, table, moves, D.choose(U.menu.of(table, seat, moves), n), U.pick.choose(table, seat, moves, n), choice, sel)
    case False{}:
      GP.absurd(U.OnSeat(seat, table, moves, choice), unanswerable(choice, sel))

def seat.on(+table: D.Table, +seat: D.Seat, +moves: List<&2, D.Move>, +n: Nat, +choice: D.Choice, +sel: {D.resolve(Q.seat.menu(table, seat, moves), n) == D.Chose{choice} : D.Resolved}) -> U.OnSeat(seat, table, moves, choice):
  any.on(seat, table, moves, n, choice, D.menus.any(D.ring.entries(List<&2, D.Move>, U.menu.of(table, seat, moves))), sel)

def idle.verify(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +i: Nat, +m: D.Move, +sel: U.IdleSel(D.nonempty.list(S.IdleOption, U.idle.opts(w, p, g, seat)), i, m), +seated: P.seated(S.world.table(w), seat), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(U.idle.at(w, p, seat, Nil{}, g))) -> {R.VerifyPacket(U.idle.ref(w, p, g, seat), D.Choice{seat, i, m}) == True{} : Bool}:
  match m:
    case D.PickUp{}:
      U.idle.pickup.verify(w, p, seat, g, i, seated, ready, shape)
    case D.UseItem{+slot, +item}:
      U.idle.use.verify(w, p, seat, g, i, slot, item, sel, seated, ready, shape)
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

def idle.on(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +choice: D.Choice, +on: U.OnSeat(seat, S.world.table(w), U.idle.moves(w, p, g, seat), choice), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(U.idle.at(w, p, seat, Nil{}, g))) -> {R.VerifyPacket(A.ref(U.idle.at(w, p, seat, n0, g)), choice) == True{} : Bool}:
  match choice:
    case D.Choice{+s, +i, +m}:
      match on:
        case Tuple{+e_s, Tuple{+e_nth, +seated}}:
          %Equal.sym(D.Seat, s, seat, e_s) : {R.VerifyPacket(A.ref(U.idle.at(w, p, seat, n0, g)), D.Choice{_, i, m}) == True{} : Bool}
          idle.verify(w, p, seat, g, i, m, U.idle.sel(D.nonempty.list(S.IdleOption, U.idle.opts(w, p, g, seat)), i, m, e_nth), seated, ready, shape)

def accept.idle(+w: S.World, +p: S.Players, +seat: D.Seat, +options: D.NonEmpty<&2, S.IdleOption>, +notes: A.Notes(), +g: S.Grabs, +n: Nat, +choice: D.Choice, +valid: A.Valid(S.State{w, p, S.Idle{seat, options}, notes, g})) -> Accepts(S.State{w, p, S.Idle{seat, options}, notes, g}, n, choice):
  +normal : A.Valid(U.idle.at(w, p, seat, notes, g)) = ISP.valid.normalized(S.State{w, p, S.Idle{seat, options}, notes, g}, valid)
  %A.valid.normal(S.State{w, p, S.Idle{seat, options}, notes, g}, valid) : Accepts(_, n, choice)
  +selected => idle.on(w, p, seat, notes, g, choice, seat.on(S.world.table(w), seat, U.idle.moves(w, p, g, seat), n, choice, selected), A.valid.ready(U.idle.at(w, p, seat, notes, g), normal), ISP.shape.move(w, p, S.Idle{seat, U.idle.opts(w, p, g, seat)}, notes, g, S.Idle{seat, U.idle.opts(w, p, g, seat)}, Nil{}, A.valid.shape(U.idle.at(w, p, seat, notes, g), normal)))

def aim.verify(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +i: Nat, +m: D.Move, +sel: AP.AimSel(Q.aim.targets(p), i, m), +seated: P.seated(S.world.table(w), seat), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(AP.aim.at(w, p, seat, Nil{}, g))) -> {R.VerifyPacket(AP.aim.ref(w, p, g, seat), D.Choice{seat, i, m}) == True{} : Bool}:
  match w m:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.Shoot{+t}:
      +st : S.State = AP.aim.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g)
      U.and.cong_true(R.current.eq(turn, seat), Bool.and(R.props.has_turn(H.host.props(U.hh(st, seat), seat)), True{}), ready, U.and.cong_true(R.props.has_turn(H.host.props(U.hh(st, seat), seat)), True{}, U.held.turn(st, seat, shape, seated), {==}))
    case +w2 D.PickUp{}:
      match sel:
    case +w2 D.UseItem{a, b}:
      match sel:
    case +w2 D.Grab{}:
      match sel:
    case +w2 D.Place{x}:
      match sel:
    case +w2 D.JamTarget{x}:
      match sel:
    case +w2 D.Steal{a, b, c}:
      match sel:

def aim.on(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +choice: D.Choice, +on: U.OnSeat(seat, S.world.table(w), AP.aim.moves(p), choice), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(AP.aim.at(w, p, seat, Nil{}, g))) -> {R.VerifyPacket(A.ref(AP.aim.at(w, p, seat, n0, g)), choice) == True{} : Bool}:
  match choice:
    case D.Choice{+s, +i, +m}:
      match on:
        case Tuple{+e_s, Tuple{+e_nth, +seated}}:
          %Equal.sym(D.Seat, s, seat, e_s) : {R.VerifyPacket(A.ref(AP.aim.at(w, p, seat, n0, g)), D.Choice{_, i, m}) == True{} : Bool}
          aim.verify(w, p, seat, g, i, m, AP.aim.sel(Q.aim.targets(p), i, m, e_nth), seated, ready, shape)

def accept.aim(+w: S.World, +p: S.Players, +seat: D.Seat, +notes: A.Notes(), +g: S.Grabs, +n: Nat, +choice: D.Choice, +valid: A.Valid(AP.aim.at(w, p, seat, notes, g))) -> Accepts(AP.aim.at(w, p, seat, notes, g), n, choice):
  +selected => aim.on(w, p, seat, notes, g, choice, seat.on(S.world.table(w), seat, AP.aim.moves(p), n, choice, selected), A.valid.ready(AP.aim.at(w, p, seat, notes, g), valid), ISP.shape.move(w, p, S.Aim{seat}, notes, g, S.Aim{seat}, Nil{}, A.valid.shape(AP.aim.at(w, p, seat, notes, g), valid)))

def jam.verify(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +n0: A.Notes(), +g: S.Grabs, +i: Nat, +m: D.Move, +sel: PK.JamSel(targets, i, m), +seated: P.seated(S.world.table(w), seat), +shape: A.Shape(PK.jam.at(w, p, seat, targets, Nil{}, g))) -> {R.VerifyPacket(A.ref(PK.jam.at(w, p, seat, targets, n0, g)), D.Choice{seat, i, m}) == True{} : Bool}:
  match m:
    case D.JamTarget{+t}:
      +st : S.State = PK.jam.at(w, p, seat, targets, Nil{}, g)
      U.and.cong_true(D.seat.eq(seat, seat), R.props.has_turn(H.host.props(U.hh(st, seat), seat)), LP.seat.refl(seat), U.held.turn(st, seat, shape, seated))
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

def jam.on(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +n0: A.Notes(), +g: S.Grabs, +choice: D.Choice, +on: U.OnSeat(seat, S.world.table(w), I.jam.moves(targets), choice), +shape: A.Shape(PK.jam.at(w, p, seat, targets, Nil{}, g))) -> {R.VerifyPacket(A.ref(PK.jam.at(w, p, seat, targets, n0, g)), choice) == True{} : Bool}:
  match choice:
    case D.Choice{+s, +i, +m}:
      match on:
        case Tuple{+e_s, Tuple{+e_nth, +seated}}:
          %Equal.sym(D.Seat, s, seat, e_s) : {R.VerifyPacket(A.ref(PK.jam.at(w, p, seat, targets, n0, g)), D.Choice{_, i, m}) == True{} : Bool}
          jam.verify(w, p, seat, targets, n0, g, i, m, PK.jam.sel(targets, i, m, e_nth), seated, shape)

def accept.jam(+w: S.World, +p: S.Players, +seat: D.Seat, +targets: List<&2, S.JamOption>, +notes: A.Notes(), +g: S.Grabs, +n: Nat, +choice: D.Choice, +valid: A.Valid(PK.jam.at(w, p, seat, targets, notes, g))) -> Accepts(PK.jam.at(w, p, seat, targets, notes, g), n, choice):
  +selected => jam.on(w, p, seat, targets, notes, g, choice, seat.on(S.world.table(w), seat, I.jam.moves(targets), n, choice, selected), ISP.shape.move(w, p, S.JamPick{seat, targets}, notes, g, S.JamPick{seat, targets}, Nil{}, A.valid.shape(PK.jam.at(w, p, seat, targets, notes, g), valid)))

def steal.verify(+w: S.World, +p: S.Players, +seat: D.Seat, +g: S.Grabs, +i: Nat, +m: D.Move, +sel: PK.StealSel(PK.steal.picks(w, p, g, seat), i, m), +seated: P.seated(S.world.table(w), seat), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(PK.steal.at(w, p, seat, Nil{}, g))) -> {R.VerifyPacket(PK.steal.ref(w, p, g, seat), D.Choice{seat, i, m}) == True{} : Bool}:
  match w m:
    case S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck} D.Steal{+owner, +slot, +item}:
      +st : S.State = PK.steal.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, Nil{}, g)
      +own : Bool = G.alive(G.item.count(G.slots.list(RI.props.slots(H.host.props(U.hh(st, seat), owner))), item))
      U.and.cong_true(R.current.eq(turn, seat), Bool.and(R.props.has_turn(H.host.props(U.hh(st, seat), seat)), own), ready, U.and.cong_true(R.props.has_turn(H.host.props(U.hh(st, seat), seat)), own, U.held.turn(st, seat, shape, seated), PK.steal.owned(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, p, seat, g, i, owner, slot, item, sel, shape)))
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

def steal.on(+w: S.World, +p: S.Players, +seat: D.Seat, +n0: A.Notes(), +g: S.Grabs, +choice: D.Choice, +on: U.OnSeat(seat, S.world.table(w), I.steal.moves(PK.steal.picks(w, p, g, seat)), choice), +ready: {R.current.eq(S.world.turn(w), seat) == True{} : Bool}, +shape: A.Shape(PK.steal.at(w, p, seat, Nil{}, g))) -> {R.VerifyPacket(A.ref(PK.steal.at(w, p, seat, n0, g)), choice) == True{} : Bool}:
  match choice:
    case D.Choice{+s, +i, +m}:
      match on:
        case Tuple{+e_s, Tuple{+e_nth, +seated}}:
          %Equal.sym(D.Seat, s, seat, e_s) : {R.VerifyPacket(A.ref(PK.steal.at(w, p, seat, n0, g)), D.Choice{_, i, m}) == True{} : Bool}
          steal.verify(w, p, seat, g, i, m, PK.steal.sel(PK.steal.picks(w, p, g, seat), i, m, e_nth), seated, ready, shape)

def accept.steal(+w: S.World, +p: S.Players, +seat: D.Seat, +picks: List<&2, S.StealOption>, +notes: A.Notes(), +g: S.Grabs, +n: Nat, +choice: D.Choice, +valid: A.Valid(S.State{w, p, S.StealPick{seat, picks}, notes, g})) -> Accepts(S.State{w, p, S.StealPick{seat, picks}, notes, g}, n, choice):
  +normal : A.Valid(PK.steal.at(w, p, seat, notes, g)) = ISP.valid.normalized(S.State{w, p, S.StealPick{seat, picks}, notes, g}, valid)
  %A.valid.normal(S.State{w, p, S.StealPick{seat, picks}, notes, g}, valid) : Accepts(_, n, choice)
  +selected => steal.on(w, p, seat, notes, g, choice, seat.on(S.world.table(w), seat, I.steal.moves(PK.steal.picks(w, p, g, seat)), n, choice, selected), A.valid.ready(PK.steal.at(w, p, seat, notes, g), normal), ISP.shape.move(w, p, S.StealPick{seat, PK.steal.picks(w, p, g, seat)}, notes, g, S.StealPick{seat, PK.steal.picks(w, p, g, seat)}, Nil{}, A.valid.shape(PK.steal.at(w, p, seat, notes, g), normal)))

