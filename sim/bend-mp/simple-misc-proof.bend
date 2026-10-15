import Base
import ./domain.bend as D
import ./abstract.bend as A
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./sm/items.bend as I
import ./sm/rules.bend as G
import ./sm/point.bend as V
import ./simple/main.bend as N
import ./simple/state.bend as T
import ./simple/point.bend as P
import ./simple-abstract.bend as SA
import ./simple-step-proof.bend as C
import ./simple-walk-proof.bend as Wk
import ./simple-loop-proof.bend as L
import ./simple-refine-proof.bend as Rf
import ./simple-idle-proof.bend as Id

# The start, roundtrip, observation and privacy laws.

def start.eq(+config: D.Config) -> {SA.lift(N.start(config)) == Some{M.start(config)} : Maybe<&2, D.Stepped<&2, S.State>>}:
  match config:
    case D.Config{D.TwoSeats{}, plan}:
      {==}
    case D.Config{D.ThreeSeats{}, plan}:
      {==}
    case D.Config{D.FourSeats{}, plan}:
      {==}

def go.snoc(xs: List<&2, D.Note>, +acc: T.Log, +x: D.Note) -> {SA.log.of.go(List.append(&2, D.Note, xs, [x]), acc) == T.Snoc{SA.log.of.go(xs, acc), x} : T.Log}:
  match xs:
    case Nil{}:
      {==}
    case +y <> ys:
      go.snoc(ys, T.Snoc{acc, y}, x)

def log.back(+l: T.Log) -> {SA.log.of(T.log.list(l)) == l : T.Log}:
  match l:
    case T.Empty{}:
      {==}
    case T.Snoc{+e, +x}:
      Equal.trans(T.Log, SA.log.of.go(List.append(&2, D.Note, T.log.list(e), [x]), T.Empty{}), T.Snoc{SA.log.of(T.log.list(e)), x}, T.Snoc{e, x}, go.snoc(T.log.list(e), T.Empty{}, x), Equal.cong(T.Log, T.Log, v => T.Snoc{v, x}, SA.log.of(T.log.list(e)), e, log.back(e)))

def phase.back(+ph: T.Phase, +r: S.State) -> {SA.back.phase(SA.embed.phase(ph, r)) == ph : T.Phase}:
  match ph:
    case T.NeedFirst{}:
      {==}
    case T.NeedHealth{}:
      {==}
    case T.NeedAmount{}:
      {==}
    case T.NeedBatch{}:
      {==}
    case T.NeedSwap{a, b, c}:
      {==}
    case T.Idle{a}:
      {==}
    case T.Ended{}:
      {==}
    case T.Blocked{a}:
      {==}
    case T.Stalled{}:
      {==}
    case T.NeedTurnAmount{a, b, c}:
      {==}
    case T.NeedItem{a, b, c, d}:
      {==}
    case T.NeedPhone{a, b, c}:
      {==}

def roundtrip(+s: T.State) -> {SA.back(SA.embed(s)) == s : T.State}:
  match s:
    case T.State{+w, +p, +ph, +l, +g}:
      +r : S.State = T.state.records(T.State{w, p, ph, l, g})
      %Equal.sym(T.Phase, SA.back.phase(SA.embed.phase(ph, r)), ph, phase.back(ph, r)) : {T.State{w, p, _, SA.log.of(T.log.list(l)), g} == T.State{w, p, ph, l, g} : T.State}
      Equal.cong(T.Log, T.State, v => T.State{w, p, ph, v, g}, SA.log.of(T.log.list(l)), l, log.back(l))

def view.eq(p: S.Players, +g: S.Grabs, seat: D.Seat) -> {P.seat.view(p, g, seat) == V.seat.view(p, g, seat) : D.SeatView}:
  match p seat:
    case D.Duo{a, b} D.Seat0{}:
      {==}
    case D.Duo{a, b} D.Seat1{}:
      {==}
    case D.Duo{a, b} D.Seat2{}:
      {==}
    case D.Duo{a, b} D.Seat3{}:
      {==}
    case D.Trio{a, b, c} D.Seat0{}:
      {==}
    case D.Trio{a, b, c} D.Seat1{}:
      {==}
    case D.Trio{a, b, c} D.Seat2{}:
      {==}
    case D.Trio{a, b, c} D.Seat3{}:
      {==}
    case D.Quad{a, b, c, d} D.Seat0{}:
      {==}
    case D.Quad{a, b, c, d} D.Seat1{}:
      {==}
    case D.Quad{a, b, c, d} D.Seat2{}:
      {==}
    case D.Quad{a, b, c, d} D.Seat3{}:
      {==}

def views.eq(seats: List<&2, D.Seat>, +p: S.Players, +g: S.Grabs, +v: D.Ring<&2, D.SeatView>) -> {P.seat.views(seats, p, g, v) == V.seat.views(seats, p, g, v) : D.Ring<&2, D.SeatView>}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> rest:
      %Equal.sym(D.SeatView, P.seat.view(p, g, seat), V.seat.view(p, g, seat), view.eq(p, g, seat)) : {P.seat.views(rest, p, g, D.ring.set(D.SeatView, v, seat, _)) == V.seat.views(rest, p, g, D.ring.set(D.SeatView, v, seat, V.seat.view(p, g, seat))) : D.Ring<&2, D.SeatView>}
      views.eq(rest, p, g, D.ring.set(D.SeatView, v, seat, V.seat.view(p, g, seat)))

def stage.eq(ph: T.Phase, +r: S.State) -> {P.phase.stage(ph) == V.phase.stage(SA.embed.phase(ph, r)) : D.Stage}:
  match ph:
    case T.NeedFirst{}:
      {==}
    case T.NeedHealth{}:
      {==}
    case T.NeedAmount{}:
      {==}
    case T.NeedBatch{}:
      {==}
    case T.NeedSwap{a, b, c}:
      {==}
    case T.Idle{a}:
      {==}
    case T.Ended{}:
      {==}
    case T.Blocked{a}:
      {==}
    case T.Stalled{}:
      {==}
    case T.NeedTurnAmount{a, b, c}:
      {==}
    case T.NeedItem{a, b, c, d}:
      {==}
    case T.NeedPhone{a, b, c}:
      {==}

def board.eq(+w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs) -> {P.board(T.State{w, p, ph, l, g}) == V.board(SA.embed(T.State{w, p, ph, l, g})) : D.Board}:
  +e1 : {D.Board{D.RoundView{S.world.round_index(w), D.plan.length(S.world.plan(w)), S.world.round_health(w)}, P.seat.views(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), D.GunView{S.world.shown(w), List.length(&2, D.Shell, S.world.gun(w)), S.world.sawed(w)}, S.world.direction(w), P.phase.stage(ph)} == D.Board{D.RoundView{S.world.round_index(w), D.plan.length(S.world.plan(w)), S.world.round_health(w)}, V.seat.views(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), D.GunView{S.world.shown(w), List.length(&2, D.Shell, S.world.gun(w)), S.world.sawed(w)}, S.world.direction(w), P.phase.stage(ph)} : D.Board} = Equal.cong(D.Ring<&2, D.SeatView>, D.Board, v => D.Board{D.RoundView{S.world.round_index(w), D.plan.length(S.world.plan(w)), S.world.round_health(w)}, v, D.GunView{S.world.shown(w), List.length(&2, D.Shell, S.world.gun(w)), S.world.sawed(w)}, S.world.direction(w), P.phase.stage(ph)}, P.seat.views(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), V.seat.views(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), views.eq(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})))
  +e2 : {D.Board{D.RoundView{S.world.round_index(w), D.plan.length(S.world.plan(w)), S.world.round_health(w)}, V.seat.views(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), D.GunView{S.world.shown(w), List.length(&2, D.Shell, S.world.gun(w)), S.world.sawed(w)}, S.world.direction(w), P.phase.stage(ph)} == D.Board{D.RoundView{S.world.round_index(w), D.plan.length(S.world.plan(w)), S.world.round_health(w)}, V.seat.views(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), D.GunView{S.world.shown(w), List.length(&2, D.Shell, S.world.gun(w)), S.world.sawed(w)}, S.world.direction(w), V.phase.stage(SA.embed.phase(ph, S.State{w, p, S.Blocked{None{}}, Nil{}, g}))} : D.Board} = Equal.cong(D.Stage, D.Board, st => D.Board{D.RoundView{S.world.round_index(w), D.plan.length(S.world.plan(w)), S.world.round_health(w)}, V.seat.views(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), D.GunView{S.world.shown(w), List.length(&2, D.Shell, S.world.gun(w)), S.world.sawed(w)}, S.world.direction(w), st}, P.phase.stage(ph), V.phase.stage(SA.embed.phase(ph, S.State{w, p, S.Blocked{None{}}, Nil{}, g})), stage.eq(ph, S.State{w, p, S.Blocked{None{}}, Nil{}, g}))
  Equal.trans(D.Board, D.Board{D.RoundView{S.world.round_index(w), D.plan.length(S.world.plan(w)), S.world.round_health(w)}, P.seat.views(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), D.GunView{S.world.shown(w), List.length(&2, D.Shell, S.world.gun(w)), S.world.sawed(w)}, S.world.direction(w), P.phase.stage(ph)}, D.Board{D.RoundView{S.world.round_index(w), D.plan.length(S.world.plan(w)), S.world.round_health(w)}, V.seat.views(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), D.GunView{S.world.shown(w), List.length(&2, D.Shell, S.world.gun(w)), S.world.sawed(w)}, S.world.direction(w), P.phase.stage(ph)}, D.Board{D.RoundView{S.world.round_index(w), D.plan.length(S.world.plan(w)), S.world.round_health(w)}, V.seat.views(D.table.seats(S.world.table(w)), p, g, D.ring.fill(D.SeatView, S.world.table(w), D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), D.GunView{S.world.shown(w), List.length(&2, D.Shell, S.world.gun(w)), S.world.sawed(w)}, S.world.direction(w), V.phase.stage(SA.embed.phase(ph, S.State{w, p, S.Blocked{None{}}, Nil{}, g}))}, e1, e2)

def observe.eq(+s: T.State, +seat: D.Seat) -> {(D.Obs{seat, P.board(s)}, D.hear(T.state.notes(s), seat)) == (D.observe(M.point(SA.embed(s)), seat), D.hear(S.state.notes(SA.embed(s)), seat)) : D.Obs & List<&2, D.Heard>}:
  match s:
    case T.State{+w, +p, +ph, +l, +g}:
      Equal.cong(D.Board, D.Obs & List<&2, D.Heard>, b => (D.Obs{seat, b}, D.hear(T.log.list(l), seat)), P.board(T.State{w, p, ph, l, g}), V.board(SA.embed(T.State{w, p, ph, l, g})), board.eq(w, p, ph, l, g))

def privacy.eq(+s: T.State, +gun: List<&2, D.Shell>, decks: S.Decks, +seat: D.Seat, same_length: {List.length(&2, D.Shell, S.world.gun(T.state.world(s))) == List.length(&2, D.Shell, gun) : Nat}) -> {(D.Obs{seat, P.board(s)}, D.hear(T.state.notes(s), seat)) == (D.Obs{seat, P.board(N.replace_hidden(s, gun, decks))}, D.hear(T.state.notes(N.replace_hidden(s, gun, decks)), seat)) : D.Obs & List<&2, D.Heard>}:
  match s:
    case T.State{+w, +p, +ph, +l, +g}:
      match w:
        case S.World{D.Config{+table, +plan}, +before, +round, +index, +first, +hp, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +old, +shown, deck}:
          Equal.cong(Nat, D.Obs & List<&2, D.Heard>, len => (D.Obs{seat, D.Board{D.RoundView{round, D.plan.length(plan), hp}, P.seat.views(D.table.seats(table), p, g, D.ring.fill(D.SeatView, table, D.SeatView{D.Unjammed{100n}, D.slots.empty(), 0, D.NotGrabbing{}})), D.GunView{shown, len, saw}, direction, P.phase.stage(ph)}}, D.hear(T.log.list(l), seat)), List.length(&2, D.Shell, old), List.length(&2, D.Shell, gun), same_length)
