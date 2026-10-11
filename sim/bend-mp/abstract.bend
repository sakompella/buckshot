import Base
import ./domain.bend as D
import ./ref/main.bend as R
import ./ref/state.bend as H
import ./ref/rules.bend as G
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./sm/rules.bend as Q
import ./sm/point.bend as V
import ./primitive.bend as P

type CoreSeat is Data:
  CoreSeat{health: Nat, jammed: Bool, checked: Bool, cash: U32, slots: D.Slots, has_turn: Bool}

def seats.health(seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, Nat>:
  match seats:
    case D.Duo{CoreSeat{a, _, _, _, _, _}, CoreSeat{b, _, _, _, _, _}}:
      D.Duo{a, b}
    case D.Trio{CoreSeat{a, _, _, _, _, _}, CoreSeat{b, _, _, _, _, _}, CoreSeat{c, _, _, _, _, _}}:
      D.Trio{a, b, c}
    case D.Quad{CoreSeat{a, _, _, _, _, _}, CoreSeat{b, _, _, _, _, _}, CoreSeat{c, _, _, _, _, _}, CoreSeat{d, _, _, _, _, _}}:
      D.Quad{a, b, c, d}

def seats.jammed(seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, Bool>:
  match seats:
    case D.Duo{CoreSeat{_, a, _, _, _, _}, CoreSeat{_, b, _, _, _, _}}:
      D.Duo{a, b}
    case D.Trio{CoreSeat{_, a, _, _, _, _}, CoreSeat{_, b, _, _, _, _}, CoreSeat{_, c, _, _, _, _}}:
      D.Trio{a, b, c}
    case D.Quad{CoreSeat{_, a, _, _, _, _}, CoreSeat{_, b, _, _, _, _}, CoreSeat{_, c, _, _, _, _}, CoreSeat{_, d, _, _, _, _}}:
      D.Quad{a, b, c, d}

def seats.checked(seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, Bool>:
  match seats:
    case D.Duo{CoreSeat{_, _, a, _, _, _}, CoreSeat{_, _, b, _, _, _}}:
      D.Duo{a, b}
    case D.Trio{CoreSeat{_, _, a, _, _, _}, CoreSeat{_, _, b, _, _, _}, CoreSeat{_, _, c, _, _, _}}:
      D.Trio{a, b, c}
    case D.Quad{CoreSeat{_, _, a, _, _, _}, CoreSeat{_, _, b, _, _, _}, CoreSeat{_, _, c, _, _, _}, CoreSeat{_, _, d, _, _, _}}:
      D.Quad{a, b, c, d}

def seats.cash(seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, U32>:
  match seats:
    case D.Duo{CoreSeat{_, _, _, a, _, _}, CoreSeat{_, _, _, b, _, _}}:
      D.Duo{a, b}
    case D.Trio{CoreSeat{_, _, _, a, _, _}, CoreSeat{_, _, _, b, _, _}, CoreSeat{_, _, _, c, _, _}}:
      D.Trio{a, b, c}
    case D.Quad{CoreSeat{_, _, _, a, _, _}, CoreSeat{_, _, _, b, _, _}, CoreSeat{_, _, _, c, _, _}, CoreSeat{_, _, _, d, _, _}}:
      D.Quad{a, b, c, d}

def seats.slots(seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, D.Slots>:
  match seats:
    case D.Duo{CoreSeat{_, _, _, _, a, _}, CoreSeat{_, _, _, _, b, _}}:
      D.Duo{a, b}
    case D.Trio{CoreSeat{_, _, _, _, a, _}, CoreSeat{_, _, _, _, b, _}, CoreSeat{_, _, _, _, c, _}}:
      D.Trio{a, b, c}
    case D.Quad{CoreSeat{_, _, _, _, a, _}, CoreSeat{_, _, _, _, b, _}, CoreSeat{_, _, _, _, c, _}, CoreSeat{_, _, _, _, d, _}}:
      D.Quad{a, b, c, d}

def seats.has_turn(seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, Bool>:
  match seats:
    case D.Duo{CoreSeat{_, _, _, _, _, a}, CoreSeat{_, _, _, _, _, b}}:
      D.Duo{a, b}
    case D.Trio{CoreSeat{_, _, _, _, _, a}, CoreSeat{_, _, _, _, _, b}, CoreSeat{_, _, _, _, _, c}}:
      D.Trio{a, b, c}
    case D.Quad{CoreSeat{_, _, _, _, _, a}, CoreSeat{_, _, _, _, _, b}, CoreSeat{_, _, _, _, _, c}, CoreSeat{_, _, _, _, _, d}}:
      D.Quad{a, b, c, d}

def players(+seats: D.Ring<&2, CoreSeat>) -> S.Players:
  S.Players{seats.health(seats), seats.jammed(seats), seats.checked(seats), seats.cash(seats), seats.slots(seats), seats.has_turn(seats)}

def seat.props(seat: CoreSeat) -> H.Props:
  match seat:
    case CoreSeat{hp, jam, checked, cash, slots, turn}:
      H.Props{hp, jam, checked, cash, slots, False{}, None{}, turn}

def props(seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, H.Props>:
  match seats:
    case D.Duo{a, b}:
      D.Duo{seat.props(a), seat.props(b)}
    case D.Trio{a, b, c}:
      D.Trio{seat.props(a), seat.props(b), seat.props(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.props(a), seat.props(b), seat.props(c), seat.props(d)}

def value.or(-A: Data, found: Maybe<&2, A>, fallback: A) -> A:
  match found:
    case Some{x}:
      x
    case None{}:
      fallback

def core.at(+players: S.Players, +seat: D.Seat, hp: Nat) -> CoreSeat:
  CoreSeat{hp, value.or(Bool, D.ring.get(Bool, S.players.jammed(players), seat), False{}), value.or(Bool, D.ring.get(Bool, S.players.checked(players), seat), False{}), value.or(U32, D.ring.get(U32, S.players.cash(players), seat), 0), value.or(D.Slots, D.ring.get(D.Slots, S.players.slots(players), seat), D.slots.empty()), value.or(Bool, D.ring.get(Bool, S.players.has_turn(players), seat), False{})}

def core.health(health: D.Ring<&2, Nat>, +players: S.Players) -> D.Ring<&2, CoreSeat>:
  match health:
    case D.Duo{a, b}:
      D.Duo{core.at(players, D.Seat1{}, a), core.at(players, D.Seat3{}, b)}
    case D.Trio{a, b, c}:
      D.Trio{core.at(players, D.Seat0{}, a), core.at(players, D.Seat1{}, b), core.at(players, D.Seat2{}, c)}
    case D.Quad{a, b, c, d}:
      D.Quad{core.at(players, D.Seat0{}, a), core.at(players, D.Seat1{}, b), core.at(players, D.Seat2{}, c), core.at(players, D.Seat3{}, d)}

def core(+players: S.Players) -> D.Ring<&2, CoreSeat>:
  core.health(S.players.health(players), players)

def batches(deck: List<&2, S.Batch>) -> List<&2, H.Batch>:
  match deck:
    case Nil{}:
      Nil{}
    case S.Batch{id, load} <> rest:
      H.Batch{id, load} <> batches(rest)

def decks(decks: S.Decks) -> H.Decks:
  match decks:
    case S.Decks{a, b, c}:
      H.Decks{batches(a), batches(b), batches(c)}

def host(world: S.World, seats: D.Ring<&2, CoreSeat>) -> H.Host:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      H.Host{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, False{}, saw, gun, shown, decks(deck), props(seats)}

def idle.frame(+h: H.Host, +seat: D.Seat, +mode: D.Mode, moves: List<&2, D.Move>) -> R.Frame:
  R.Await{D.request.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, H.host.table(h), Nil{}), seat, moves)), D.Playing{seat, mode}, R.PlayerMove{mode}}

def batch.frame(deck: List<&2, H.Batch>) -> R.Frame:
  match deck:
    case a <> b <> rest:
      R.Await{D.Draw{D.SequenceBatch{}, D.Range{0n, List.length(&2, H.Batch, rest)}}, D.Loading{}, R.SequenceBatchResult{}}
    case _:
      R.Await{D.Stuck{}, D.Loading{}, R.SequenceBatchResult{}}

def frame(phase: S.Phase, +h: H.Host) -> R.Frame:
  match phase:
    case S.NeedFirst{}:
      R.Await{D.Draw{D.FirstSeat{}, D.Range{0n, G.subtract(D.table.count(H.host.table(h)), 2n)}}, D.Setup{}, R.FirstSeatResult{}}
    case S.NeedHealth{}:
      R.Await{D.Draw{D.StartingHealth{}, D.table.health_range(H.host.table(h))}, D.Setup{}, R.StartingHealthResult{}}
    case S.NeedAmount{}:
      R.Await{D.Draw{D.ItemAmount{}, D.table.amount_range(H.host.table(h))}, D.Setup{}, R.ItemAmountResult{R.PacketSort_StartRound{}}}
    case S.NeedBatch{}:
      batch.frame(H.host.deck(h))
    case S.NeedSwap{load, shells, +i}:
      R.Await{D.Draw{D.ShuffleSwap{}, D.Range{0n, G.subtract(i, 1n)}}, D.Loading{}, R.ShuffleSwapResult{load, shells, i}}
    case S.Idle{seat, _}:
      idle.frame(h, seat, D.Idle{}, [D.PickUp{}])
    case S.Aim{seat, _}:
      idle.frame(h, seat, D.Aiming{}, R.shot_moves(G.living(D.ring.entries(H.Props, H.host.seats(h)))))
    case S.Ended{}:
      R.Await{D.Finished{}, D.MatchOver{}, R.PlayerMove{D.Idle{}}}
    case S.Blocked{}:
      R.Await{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}

def ref(state: S.State) -> R.RefState:
  match state:
    case S.State{world, seats, phase, notes}:
      +h : H.Host = host(world, core(seats))
      R.RefState{h, frame(phase, h), notes}

def stepped(result: D.Stepped<&2, S.State>) -> D.Stepped<&2, R.RefState>:
  match result:
    case D.Stepped{state, notes}:
      D.Stepped{ref(state), notes}

def ran(result: D.Ran<&2, S.State>) -> D.Ran<&2, R.RefState>:
  match result:
    case D.Ran{state, notes, tape}:
      D.Ran{ref(state), notes, tape}

def pack(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  S.State{world, players(seats), phase, notes}


def World() -> Data:
  S.World

def Seat() -> Data:
  D.Seat

def Seats() -> Data:
  D.Ring<&2, CoreSeat>

def Notes() -> Data:
  List<&2, D.Note>

def table(world: S.World) -> D.Table:
  S.world.table(world)

def idle(world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> S.State:
  pack(world, seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes)

def pickup_step(world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>, n: Nat) -> D.Stepped<&2, R.RefState>:
  stepped(M.pickup_slice(idle(world, seats, seat, notes), n))

def pickup_choice(seat: D.Seat) -> D.Choice:
  D.Choice{seat, 0n, D.PickUp{}}

def pickup_accepted(world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>) -> Bool:
  R.VerifyPacket(ref(idle(world, seats, seat, notes)), pickup_choice(seat))


def seated(+world: S.World, seat: D.Seat) -> Data:
  P.seated(table(world), seat)


def RefStep() -> Data:
  D.Stepped<&2, R.RefState>

def Phase() -> Data:
  S.Phase

def raw_idle(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  +h : H.Host = host(world, seats)
  R.RefState{h, idle.frame(h, seat, D.Idle{}, [D.PickUp{}]), notes}

def expected_pickup(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> D.Stepped<&2, R.RefState>:
  R.stepped(R.ReceivePacket_PickUpShotgun(raw_idle(world, seats, seat, Nil{}), seat))



def Ref() -> Data:
  R.RefState

def ref_answer(state: R.RefState, n: Nat) -> D.Stepped<&2, R.RefState>:
  R.answer(state, n)


def ref_stepped(state: R.RefState) -> D.Stepped<&2, R.RefState>:
  R.stepped(state)

def ref_idle_choose(+world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  +h : H.Host = host(world, seats)
  R.RefState{h, R.Await{D.Choose{D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, H.host.table(h), Nil{}), seat, [D.PickUp{}])}, D.Playing{seat, D.Idle{}}, R.PlayerMove{D.Idle{}}}, notes}

def ref_idle_request(+world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>, request: D.Request) -> R.RefState:
  R.RefState{host(world, seats), R.Await{request, D.Playing{seat, D.Idle{}}, R.PlayerMove{D.Idle{}}}, notes}

def ref_idle_resolved(+world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, resolved: D.Resolved) -> D.Stepped<&2, R.RefState>:
  +state : R.RefState = ref_idle_choose(world, seats, seat, Nil{})
  R.stepped(R.settle(96n, R.answer.resolved(state, R.PlayerMove{D.Idle{}}, resolved)))

def raw_accepted(+world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> Bool:
  R.VerifyPacket(ref_idle_choose(world, seats, seat, Nil{}), pickup_choice(seat))

def ref_idle_accepting(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, accepted: Bool) -> D.Stepped<&2, R.RefState>:
  R.stepped(R.settle(96n, R.answer.move.accepted(ref_idle_choose(world, seats, seat, Nil{}), pickup_choice(seat), accepted)))


def machine_pickup_resolved(world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, resolved: D.Resolved) -> D.Stepped<&2, R.RefState>:
  stepped(S.state.stepped(M.pickup.resolved(idle(world, seats, seat, Nil{}), seat, D.NonEmpty{S.TakeGun{}, Nil{}}, resolved)))

def machine_pickup_same(world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, same: Bool) -> D.Stepped<&2, R.RefState>:
  stepped(S.state.stepped(M.pickup.same(idle(world, seats, seat, Nil{}), seat, D.NonEmpty{S.TakeGun{}, Nil{}}, 0n, same)))


def health_entries(entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, D.At<&2, Nat>>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{seat, CoreSeat{hp, _, _, _, _, _}} <> rest:
      D.At{seat, hp} <> health_entries(rest)

def props_entries(entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, D.At<&2, H.Props>>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{seat, props} <> rest:
      D.At{seat, seat.props(props)} <> props_entries(rest)

def machine_shots_entries(entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, D.Move>:
  Q.aim.moves(Q.targets(health_entries(entries)))

def ref_shots_entries(entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, D.Move>:
  R.shot_moves(G.living(props_entries(entries)))

def machine_shots(seats: D.Ring<&2, CoreSeat>) -> List<&2, D.Move>:
  Q.aim.moves(Q.targets(D.ring.entries(Nat, seats.health(seats))))

def ref_shots(seats: D.Ring<&2, CoreSeat>) -> List<&2, D.Move>:
  R.shot_moves(G.living(D.ring.entries(H.Props, props(seats))))

def machine_step_state(result: D.Stepped<&2, S.State>) -> S.State:
  match result:
    case D.Stepped{state, _}:
      state

def machine_pickup_state(world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>, n: Nat) -> S.State:
  machine_step_state(M.pickup_slice(idle(world, seats, seat, notes), n))

def pickup_point(world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>, n: Nat) -> D.Point:
  M.point(machine_pickup_state(world, seats, seat, notes, n))

def ref_point(state: R.RefState) -> D.Point:
  R.point(state)

def ref_step_point(result: D.Stepped<&2, R.RefState>) -> D.Point:
  match result:
    case D.Stepped{state, _}:
      R.point(state)

def RefPoint() -> Data:
  D.Point


def aim_successor(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> S.State:
  pack(world, seats, S.Aim{seat, Q.targets(D.ring.entries(Nat, seats.health(seats)))}, [D.Shown{D.PickedUp{seat}}])

def machine_pickup_resolved_state(world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, resolved: D.Resolved) -> S.State:
  M.pickup.resolved(idle(world, seats, seat, Nil{}), seat, D.NonEmpty{S.TakeGun{}, Nil{}}, resolved)

def machine_pickup_same_state(world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, same: Bool) -> S.State:
  M.pickup.same(idle(world, seats, seat, Nil{}), seat, D.NonEmpty{S.TakeGun{}, Nil{}}, 0n, same)

def machine_point(state: S.State) -> D.Point:
  M.point(state)


def world_for(+world: S.World, +seats: D.Ring<&2, CoreSeat>) -> S.World:
  S.world.set_config(world, D.Config{D.ring.table(CoreSeat, seats), S.world.plan(world)})

def point_board(point: D.Point) -> D.Board:
  match point:
    case D.Point{_, board}:
      board

def successor_point_with_moves(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, moves: List<&2, D.Move>) -> D.Point:
  D.Point{Q.seat.menu(S.world.table(world), seat, moves), point_board(M.point(aim_successor(world, seats, seat)))}


def play_phase(+seat: D.Seat, aiming: Bool, seats: D.Ring<&2, CoreSeat>) -> S.Phase:
  match aiming:
    case False{}:
      S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}
    case True{}:
      S.Aim{seat, Q.targets(D.ring.entries(Nat, seats.health(seats)))}

def play_state(world: S.World, +seats: D.Ring<&2, CoreSeat>, seat: D.Seat, aiming: Bool, notes: List<&2, D.Note>) -> S.State:
  pack(world, seats, play_phase(seat, aiming, seats), notes)

def machine_request(state: S.State) -> D.Request:
  M.request(state)

def ref_request(state: R.RefState) -> D.Request:
  R.request(state)

def play_request_with_moves(world: S.World, +seat: D.Seat, moves: List<&2, D.Move>) -> D.Request:
  Q.seat.menu(S.world.table(world), seat, moves)


def raw_state(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> R.RefState:
  +h : H.Host = host(world, seats)
  R.RefState{h, frame(phase, h), notes}


def machine_stage(phase: S.Phase) -> D.Stage:
  V.phase.stage(phase)

def ref_phase_stage(+world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> D.Stage:
  R.stage(raw_state(world, seats, phase, notes))

def seat.view(seat: CoreSeat) -> D.SeatView:
  match seat:
    case CoreSeat{hp, jam, _, cash, slots, _}:
      D.SeatView{D.counter.of(jam, hp), slots, cash, D.NotGrabbing{}}

def seat.views(seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, D.SeatView>:
  match seats:
    case D.Duo{a, b}:
      D.Duo{seat.view(a), seat.view(b)}
    case D.Trio{a, b, c}:
      D.Trio{seat.view(a), seat.view(b), seat.view(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.view(a), seat.view(b), seat.view(c), seat.view(d)}

def board_at(+world: S.World, seats: D.Ring<&2, CoreSeat>, stage: D.Stage) -> D.Board:
  D.Board{D.RoundView{S.world.round_index(world), D.plan.length(S.world.plan(world)), S.world.round_health(world)}, seat.views(seats), D.GunView{S.world.shown(world), List.length(&2, D.Shell, S.world.gun(world)), S.world.sawed(world)}, S.world.direction(world), stage}

def machine_board(state: S.State) -> D.Board:
  V.board(state)

def ref_board(state: R.RefState) -> D.Board:
  R.board(state)

def observation(state: S.State, seat: D.Seat) -> D.Obs:
  D.observe(M.point(state), seat)

def ref_observation(state: R.RefState, seat: D.Seat) -> D.Obs:
  D.observe(R.point(state), seat)


def batch_stage(deck: List<&2, H.Batch>) -> D.Stage:
  R.stage(R.RefState{H.host.initial(D.config.default(D.TwoSeats{})), batch.frame(deck), Nil{}})


def batch_frame_stage(+h: H.Host, deck: List<&2, H.Batch>, notes: List<&2, D.Note>) -> {R.stage(R.RefState{h, batch.frame(deck), notes}) == D.Loading{} : D.Stage}:
  match deck:
    case Nil{}:
      {==}
    case a <> Nil{}:
      {==}
    case a <> b <> rest:
      {==}

def batch_stage_matches(+world: S.World, +seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> {ref_phase_stage(world, seats, S.NeedBatch{}, notes) == D.Loading{} : D.Stage}:
  batch_frame_stage(host(world, seats), H.host.deck(host(world, seats)), notes)


def canonical_phase(phase: S.Phase, +seats: D.Ring<&2, CoreSeat>) -> S.Phase:
  match phase:
    case S.Idle{seat, _}:
      S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}
    case S.Aim{seat, _}:
      S.Aim{seat, Q.targets(D.ring.entries(Nat, seats.health(seats)))}
    case S.NeedSwap{load, shells, 0n}:
      S.Blocked{}
    case phase:
      phase

def canonical_state(+world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  pack(world_for(world, seats), seats, canonical_phase(phase, seats), notes)

def ref_batch_length(deck: List<&2, S.Batch>) -> Nat:
  List.length(&2, H.Batch, batches(deck))

def ref_batch_request(world: S.World, seats: D.Ring<&2, CoreSeat>, deck: List<&2, S.Batch>, notes: List<&2, D.Note>) -> D.Request:
  R.request(R.RefState{host(world, seats), batch.frame(batches(deck)), notes})

def machine_batch_request(deck: List<&2, S.Batch>) -> D.Request:
  V.batch.request(List.length(&2, S.Batch, deck))


def heard(state: S.State, seat: D.Seat) -> List<&2, D.Heard>:
  D.hear(S.state.notes(state), seat)

def ref_notes(state: R.RefState) -> List<&2, D.Note>:
  match state:
    case R.RefState{_, _, notes}:
      notes

def ref_heard(state: R.RefState, seat: D.Seat) -> List<&2, D.Heard>:
  D.hear(ref_notes(state), seat)


def subtract_zero(n: Nat) -> Nat:
  G.subtract(n, 0n)


def packet_mode(mode: D.Mode, move: D.Move) -> Bool:
  R.VerifyPacket.mode(mode, move)

def choices_shape(+mode: D.Mode, choices: List<&2, D.Choice>) -> Bool:
  match choices:
    case Nil{}:
      True{}
    case D.Choice{seat, index, move} <> rest:
      Bool.and(packet_mode(mode, move), choices_shape(mode, rest))

def maybe_shape(mode: D.Mode, choice: Maybe<&2, D.Choice>) -> Bool:
  match choice:
    case None{}:
      True{}
    case Some{D.Choice{seat, index, move}}:
      packet_mode(mode, move)

def menu_choices(+world: S.World, +seat: D.Seat, moves: List<&2, D.Move>) -> List<&2, D.Choice>:
  D.choices.flatten(D.ring.entries(List<&2, D.Move>, D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, S.world.table(world), Nil{}), seat, moves)))

def verify(state: R.RefState, choice: D.Choice) -> Bool:
  R.VerifyPacket(state, choice)

def choice_seat(choice: D.Choice) -> D.Seat:
  match choice:
    case D.Choice{seat, _, _}:
      seat

def choice_move(choice: D.Choice) -> D.Move:
  match choice:
    case D.Choice{_, _, move}:
      move

def current_matches(state: R.RefState, seat: D.Seat) -> Bool:
  R.current.eq(H.host.turn(R.host(state)), seat)

def has_turn(state: R.RefState, seat: D.Seat) -> Bool:
  R.props.has_turn(H.host.props(R.host(state), seat))


def resolved_shape(mode: D.Mode, resolved: D.Resolved) -> Bool:
  match resolved:
    case D.Chose{D.Choice{seat, index, move}}:
      packet_mode(mode, move)
    case _:
      True{}

def play_mode(aiming: Bool) -> D.Mode:
  match aiming:
    case False{}:
      D.Idle{}
    case True{}:
      D.Aiming{}

def play_moves(aiming: Bool, seats: D.Ring<&2, CoreSeat>) -> List<&2, D.Move>:
  match aiming:
    case False{}:
      [D.PickUp{}]
    case True{}:
      machine_shots(seats)

def play_menus(+world: S.World, +seat: D.Seat, moves: List<&2, D.Move>) -> D.Ring<&2, List<&2, D.Move>>:
  D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, S.world.table(world), Nil{}), seat, moves)

def Request() -> Data:
  D.Request


def target_choices(options: List<&2, S.TargetOption>, +seat: D.Seat, index: Nat) -> List<&2, D.Choice>:
  D.choices.of(Q.aim.moves(options), seat, index)

def target_options(seats: D.Ring<&2, CoreSeat>) -> List<&2, S.TargetOption>:
  Q.targets(D.ring.entries(Nat, seats.health(seats)))


def resolved_choice_shape(mode: D.Mode, picked: Maybe<&2, D.Choice>) -> Bool:
  resolved_shape(mode, D.resolve.choice(picked))

def smart_request_shape(mode: D.Mode, +menus: D.Ring<&2, List<&2, D.Move>>, n: Nat, any: Bool) -> Bool:
  resolved_shape(mode, D.resolve(D.request.choose.any(any, menus), n))

def resolved_pick_shape(aiming: Bool, choice: D.Choice) -> Bool:
  resolved_shape(play_mode(aiming), D.Chose{choice})


def ref_shell_nth(shells: List<&2, D.Shell>, index: Nat) -> Maybe<&2, D.Shell>:
  G.nth(D.Shell, shells, index)

def machine_shell_nth(shells: List<&2, D.Shell>, index: Nat) -> Maybe<&2, D.Shell>:
  Q.nth(D.Shell, shells, index)

def ref_shell_set(shells: List<&2, D.Shell>, index: Nat, shell: D.Shell) -> List<&2, D.Shell>:
  G.set(D.Shell, shells, index, shell)

def machine_shell_set(shells: List<&2, D.Shell>, index: Nat, shell: D.Shell) -> List<&2, D.Shell>:
  Q.replace(D.Shell, shells, index, shell)

def ref_swap(shells: List<&2, D.Shell>, i: Nat, j: Nat) -> List<&2, D.Shell>:
  G.swap(shells, i, j)

def machine_swap(shells: List<&2, D.Shell>, i: Nat, j: Nat) -> List<&2, D.Shell>:
  Q.swap(shells, i, j)

def ref_swap_found(shells: List<&2, D.Shell>, i: Nat, j: Nat, x: Maybe<&2, D.Shell>, y: Maybe<&2, D.Shell>) -> List<&2, D.Shell>:
  G.swap.found(shells, i, j, x, y)

def machine_swap_found(shells: List<&2, D.Shell>, i: Nat, j: Nat, x: Maybe<&2, D.Shell>, y: Maybe<&2, D.Shell>) -> List<&2, D.Shell>:
  Q.swap.found(shells, i, j, x, y)


type RequestPhase is Data:
  First{}
  Health{}
  Amount{}
  Batch{}
  Swap{load: D.Load, shells: List<&2, D.Shell>, i: Nat}
  Idle{seat: D.Seat}
  Aim{seat: D.Seat}
  Ended{}
  Blocked{}

def request_phase(phase: RequestPhase, seats: D.Ring<&2, CoreSeat>) -> S.Phase:
  match phase:
    case First{}:
      S.NeedFirst{}
    case Health{}:
      S.NeedHealth{}
    case Amount{}:
      S.NeedAmount{}
    case Batch{}:
      S.NeedBatch{}
    case Swap{load, shells, i}:
      S.NeedSwap{load, shells, i}
    case Idle{seat}:
      S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}
    case Aim{seat}:
      S.Aim{seat, Q.targets(D.ring.entries(Nat, seats.health(seats)))}
    case Ended{}:
      S.Ended{}
    case Blocked{}:
      S.Blocked{}

def canonical(world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: RequestPhase, notes: List<&2, D.Note>) -> S.State:
  pack(world, seats, request_phase(phase, seats), notes)

def back.batches(deck: List<&2, H.Batch>) -> List<&2, S.Batch>:
  match deck:
    case Nil{}:
      Nil{}
    case H.Batch{id, load} <> rest:
      S.Batch{id, load} <> back.batches(rest)

def back.decks(deck: H.Decks) -> S.Decks:
  match deck:
    case H.Decks{a, b, c}:
      S.Decks{back.batches(a), back.batches(b), back.batches(c)}

def back.world(h: H.Host) -> S.World:
  match h:
    case H.Host{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, _, saw, gun, shown, deck, _}:
      S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, back.decks(deck)}

def back.props(seat: H.Props) -> CoreSeat:
  match seat:
    case H.Props{hp, jam, checked, cash, slots, _, _, turn}:
      CoreSeat{hp, jam, checked, cash, slots, turn}

def back.seats(seats: D.Ring<&2, H.Props>) -> D.Ring<&2, CoreSeat>:
  match seats:
    case D.Duo{a, b}:
      D.Duo{back.props(a), back.props(b)}
    case D.Trio{a, b, c}:
      D.Trio{back.props(a), back.props(b), back.props(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{back.props(a), back.props(b), back.props(c), back.props(d)}

def back.targets(seats: List<&2, D.Seat>) -> List<&2, S.TargetOption>:
  match seats:
    case Nil{}:
      Nil{}
    case seat <> rest:
      S.Target{seat} <> back.targets(rest)

def back.terminal(stage: D.Stage, request: D.Request) -> S.Phase:
  match stage:
    case D.MatchOver{}:
      match request:
        case D.Finished{}:
          S.Ended{}
        case _:
          S.Blocked{}
    case _:
      S.Blocked{}

def back.play(stage: D.Stage, mode: D.Mode, request: D.Request, h: H.Host) -> S.Phase:
  match stage:
    case D.Playing{seat, D.Idle{}}:
      match mode:
        case D.Idle{}:
          S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}
        case _:
          S.Blocked{}
    case D.Playing{seat, D.Aiming{}}:
      match mode:
        case D.Aiming{}:
          S.Aim{seat, back.targets(G.living(D.ring.entries(H.Props, H.host.seats(h))))}
        case _:
          S.Blocked{}
    case _:
      back.terminal(stage, request)

def back.await(continuation: R.Continuation, stage: D.Stage, request: D.Request, h: H.Host) -> S.Phase:
  match continuation:
    case R.FirstSeatResult{}:
      S.NeedFirst{}
    case R.StartingHealthResult{}:
      S.NeedHealth{}
    case R.ItemAmountResult{_}:
      S.NeedAmount{}
    case R.SequenceBatchResult{}:
      S.NeedBatch{}
    case R.ShuffleSwapResult{load, shells, i}:
      S.NeedSwap{load, shells, i}
    case R.PlayerMove{mode}:
      back.play(stage, mode, request, h)
    case _:
      back.terminal(stage, request)

def back.phase(frame: R.Frame, h: H.Host) -> S.Phase:
  match frame:
    case R.Await{request, stage, continuation}:
      back.await(continuation, stage, request, h)
    case _:
      S.Blocked{}

def back(state: R.RefState) -> S.State:
  match state:
    case R.RefState{+h, frame, notes}:
      S.State{back.world(h), players(back.seats(H.host.seats(h))), back.phase(frame, h), notes}

def batches_roundtrip(deck: List<&2, S.Batch>) -> List<&2, S.Batch>:
  back.batches(batches(deck))

def decks_roundtrip(deck: S.Decks) -> S.Decks:
  back.decks(decks(deck))

def world_roundtrip(world: S.World, seats: D.Ring<&2, CoreSeat>) -> S.World:
  back.world(host(world, seats))

def seats_roundtrip(seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, CoreSeat>:
  back.seats(props(seats))

def ref_targets_entries(entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, S.TargetOption>:
  back.targets(G.living(props_entries(entries)))

def machine_targets_entries(entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, S.TargetOption>:
  Q.targets(health_entries(entries))

def ref_targets(seats: D.Ring<&2, CoreSeat>) -> List<&2, S.TargetOption>:
  back.targets(G.living(D.ring.entries(H.Props, props(seats))))

def machine_targets(seats: D.Ring<&2, CoreSeat>) -> List<&2, S.TargetOption>:
  Q.targets(D.ring.entries(Nat, seats.health(seats)))

def phase_roundtrip(+world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: RequestPhase) -> S.Phase:
  +h : H.Host = host(world, seats)
  back.phase(frame(request_phase(phase, seats), h), h)

def raw_canonical(world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: RequestPhase, notes: List<&2, D.Note>) -> R.RefState:
  raw_state(world, seats, request_phase(phase, seats), notes)


def RefHost() -> Data:
  H.Host

def RefBatches() -> Data:
  List<&2, H.Batch>

def selected_deck(+world: S.World, seats: D.Ring<&2, CoreSeat>) -> List<&2, H.Batch>:
  H.host.deck(host(world, seats))

def batch_phase(deck: List<&2, H.Batch>, h: H.Host) -> S.Phase:
  back.phase(batch.frame(deck), h)


def restored_parts(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +phase: RequestPhase, notes: List<&2, D.Note>) -> S.State:
  S.State{world_roundtrip(world, seats), players(seats_roundtrip(seats)), phase_roundtrip(world, seats, phase), notes}

def ref_turn(world: S.World, seats: D.Ring<&2, CoreSeat>, current: D.Seat) -> D.Seat:
  G.GetNextTurn_Socket(host(world, seats), current)

def turn_entries_machine(entries: List<&2, D.At<&2, CoreSeat>>, current: D.Seat) -> List<&2, D.Seat>:
  Q.turn_candidates(health_entries(entries), current)

def turn_entries_ref(entries: List<&2, D.At<&2, CoreSeat>>, current: D.Seat) -> List<&2, D.Seat>:
  G.turn_ring(props_entries(entries), current)

def ref_keep(keep: Bool, seat: D.Seat, rest: List<&2, D.Seat>) -> List<&2, D.Seat>:
  G.turn_ring.put(keep, seat, rest)

def ref_alive(hp: Nat) -> Bool:
  G.alive(hp)

def ref_pick(hit: Bool, next: D.Seat, rest: D.Seat) -> D.Seat:
  G.after.pick(hit, next, rest)

def ref_successor_go(seats: List<&2, D.Seat>, current: D.Seat, wrap: D.Seat) -> D.Seat:
  G.after(seats, current, wrap)

def ref_successor(seats: List<&2, D.Seat>, current: D.Seat) -> D.Seat:
  G.traversal(seats, current)

def ref_directed(direction: D.Direction, seats: List<&2, D.Seat>, current: D.Seat) -> D.Seat:
  G.directed(direction, seats, current)

def turn_candidates_ref(seats: D.Ring<&2, CoreSeat>, current: D.Seat) -> List<&2, D.Seat>:
  G.turn_ring(D.ring.entries(H.Props, props(seats)), current)

def ref_start(config: D.Config) -> D.Stepped<&2, R.RefState>:
  R.start(config)

def machine_supported_start(config: D.Config, supported: Bool) -> D.Stepped<&2, R.RefState>:
  stepped(M.start.supported(M.initial(config), supported))


type GrantCase is Data:
  GrantAct{seats: D.Ring<&2, CoreSeat>}
  GrantLift{seats: D.Ring<&2, CoreSeat>}
  GrantSkip{seats: D.Ring<&2, CoreSeat>}

def grant.jam_at(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, props: CoreSeat) -> GrantCase:
  match props:
    case CoreSeat{hp, False{}, checked, cash, slots, turn}:
      GrantAct{seats}
    case CoreSeat{hp, True{}, False{}, cash, slots, turn}:
      GrantSkip{D.ring.set(CoreSeat, seats, seat, CoreSeat{hp, True{}, True{}, cash, slots, turn})}
    case CoreSeat{hp, True{}, True{}, cash, slots, turn}:
      GrantLift{D.ring.set(CoreSeat, seats, seat, CoreSeat{hp, False{}, True{}, cash, slots, turn})}

def grant.jam(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> GrantCase:
  grant.jam_at(seats, seat, value.or(CoreSeat, D.ring.get(CoreSeat, seats, seat), CoreSeat{100n, False{}, False{}, 0, D.slots.empty(), False{}}))

def grant.players(result: GrantCase) -> S.JamResult:
  match result:
    case GrantAct{seats}:
      S.Act{players(seats)}
    case GrantLift{seats}:
      S.Lift{players(seats)}
    case GrantSkip{seats}:
      S.Skip{players(seats)}

def grant.rank(seats: D.Ring<&2, CoreSeat>) -> Nat:
  Q.jam_rank(players(seats))

def grant.pass(world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host(world, seats), R.PassTurn{seat}, notes}

def grant.give(world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host(world, seats), R.GiveTurnPermissions{seat}, notes}

def grant.dispatch(state: R.RefState) -> R.RefState:
  R.dispatch(state)

def grant.settle(fuel: Nat, state: R.RefState) -> R.RefState:
  R.settle(fuel, state)

def grant.pass_case(+world: S.World, result: GrantCase, +seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  match result:
    case GrantAct{seats}:
      grant.give(S.world.set_turn(world, Some{seat}), seats, seat, notes)
    case GrantLift{seats}:
      grant.give(S.world.set_turn(world, Some{seat}), seats, seat, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]))
    case GrantSkip{+seats}:
      +turned : S.World = S.world.set_turn(world, Some{seat})
      grant.pass(turned, seats, ref_turn(turned, seats, seat), List.append(&2, D.Note, notes, [D.Shown{D.TurnSkipped{seat}}]))

def grant.machine(rank: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, seat: D.Seat) -> S.State:
  M.grant.bound(rank, pack(world, seats, phase, notes), seat)

def grant.machine_case(rank: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, +seat: D.Seat, result: GrantCase) -> S.State:
  M.grant.step(rank, pack(S.world.set_turn(world, Some{seat}), seats, phase, notes), seat, grant.players(result))

def grant.given(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, seat: D.Seat) -> S.State:
  M.give_turn(pack(world, seats, phase, notes), seat)


def grant.sum(prefix: List<&2, Nat>, tail: Nat) -> Nat:
  match prefix:
    case Nil{}:
      tail
    case x <> rest:
      Nat.add(x, grant.sum(rest, tail))

def grant.rank_claim(+seats: D.Ring<&2, CoreSeat>, result: GrantCase) -> Data:
  match result:
    case GrantSkip{after}:
      {grant.rank(seats) == 1n+grant.rank(after) : Nat}
    case _:
      Unit


def grant.clear_at(+seats: D.Ring<&2, CoreSeat>, seat: D.Seat, props: CoreSeat) -> D.Ring<&2, CoreSeat>:
  match props:
    case CoreSeat{hp, _, checked, cash, slots, turn}:
      D.ring.set(CoreSeat, seats, seat, CoreSeat{hp, False{}, checked, cash, slots, turn})

def grant.clear(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> D.Ring<&2, CoreSeat>:
  grant.clear_at(seats, seat, value.or(CoreSeat, D.ring.get(CoreSeat, seats, seat), CoreSeat{100n, False{}, False{}, 0, D.slots.empty(), False{}}))

def grant.once_claim(result: GrantCase, +seat: D.Seat) -> Type:
  match result:
    case GrantSkip{+after}:
      {D.ring.get(Bool, seats.checked(after), seat) == Some{True{}} : Maybe<&2, Bool>} & {D.ring.get(Bool, seats.jammed(after), seat) == Some{True{}} : Maybe<&2, Bool>} & {grant.jam(after, seat) == GrantLift{grant.clear(after, seat)} : GrantCase} & {grant.jam(grant.clear(after, seat), seat) == GrantAct{grant.clear(after, seat)} : GrantCase}
    case GrantLift{+after}:
      {D.ring.get(Bool, seats.checked(after), seat) == Some{True{}} : Maybe<&2, Bool>} & {D.ring.get(Bool, seats.jammed(after), seat) == Some{False{}} : Maybe<&2, Bool>} & {grant.jam(after, seat) == GrantAct{after} : GrantCase}
    case GrantAct{_}:
      Unit


def grant.Hypothesis(+rank: Nat) -> Type:
  @+world:S.World -> @+seats:D.Ring<&2, CoreSeat> -> @+seat:D.Seat -> @+phase:S.Phase -> @+notes:List<&2, D.Note> -> @+extra:Nat -> @budget:{rank == grant.rank(seats) : Nat} -> {grant.settle(2n+Nat.add(rank, extra), grant.pass(world, seats, seat, notes)) == ref(grant.machine(rank, world, seats, phase, notes, seat)) : R.RefState}


def grant.limit(amount: Nat, bound: Nat) -> Data:
  match amount bound:
    case 0n _:
      Unit
    case 1n+amount 1n+bound:
      grant.limit(amount, bound)
    case 1n+amount 0n:
      Empty


def grant.zero_claim(n: Nat) -> Data:
  match n:
    case 0n:
      Unit
    case 1n+rest:
      Empty


def grant.pred(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+rest:
      rest


def grant.shape_claim(result: GrantCase, table: D.Table) -> Data:
  match result:
    case GrantAct{after}:
      {D.ring.table(CoreSeat, after) == table : D.Table}
    case GrantLift{after}:
      {D.ring.table(CoreSeat, after) == table : D.Table}
    case GrantSkip{after}:
      {D.ring.table(CoreSeat, after) == table : D.Table}

def grant.PointHypothesis(+rank: Nat) -> Type:
  @+world:S.World -> @+seats:D.Ring<&2, CoreSeat> -> @+seat:D.Seat -> @+phase:S.Phase -> @+notes:List<&2, D.Note> -> @budget:{rank == grant.rank(seats) : Nat} -> @synced:{S.world.table(world) == D.ring.table(CoreSeat, seats) : D.Table} -> {M.point(grant.machine(rank, world, seats, phase, notes, seat)) == R.point(ref(grant.machine(rank, world, seats, phase, notes, seat))) : D.Point}

def ref_subtract(left: Nat, right: Nat) -> Nat:
  G.subtract(left, right)

def ref_shot_health(shell: D.Shell, hp: Nat, damage: D.Damage) -> Nat:
  G.shell.health(shell, hp, damage)

def ref_shot_passes(shell: D.Shell, same: Bool) -> Bool:
  Bool.not(Bool.and(same, Bool.not(G.shell.live(shell))))

type Prefix is Data:
  Prefix{host: H.Host, notes: List<&2, D.Note>}

def prefix(state: R.RefState) -> Prefix:
  match state:
    case R.RefState{host, _, notes}:
      Prefix{host, notes}

def machine_prefix(state: S.State) -> Prefix:
  prefix(ref(state))

def ref_death_first(state: S.State, seat: D.Seat, checking: Bool) -> Prefix:
  prefix(R.DeathRequest.first(ref(state), seat, checking))

def ref_death(state: S.State, target: D.Seat, shell: D.Shell, health: Nat) -> Prefix:
  prefix(R.DeathRequest.health(ref(state), R.Shot{D.Seat0{}, target, shell, D.Single{}, 0n}, health))

def final_condition(+world: S.World) -> Bool:
  Nat.is_eq(1n+S.world.round_index(world), D.plan.length(S.world.plan(world)))

def raw_win(world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host(world, seats), R.WinRoutine{seat}, notes}

def won_host(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> H.Host:
  +h : H.Host = host(world, seats)
  H.host.set_props(h, seat, H.props.award(H.host.props(h, seat), D.prize(S.world.round_index(world))))

def expected_win(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{won_host(world, seats, seat), R.Await{D.Finished{}, D.MatchOver{}, R.PlayerMove{D.Idle{}}}, List.append(&2, D.Note, List.append(&2, D.Note, notes, [D.Shown{D.RoundWon{seat, D.prize(S.world.round_index(world))}}]), [D.Shown{D.MatchConcluded{}}])}

def ref_win(world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>, fuel: Nat) -> R.RefState:
  R.settle(fuel, raw_win(world, seats, seat, notes))

def ref_win_gate(world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>, k: Nat, final: Bool) -> R.RefState:
  R.settle(2n+k, R.LoopBackAfterWinRoutine.final(R.WinRoutine(raw_win(world, seats, seat, notes), seat), final))

def ref_finished(h: H.Host, notes: List<&2, D.Note>, fuel: Nat) -> R.RefState:
  R.settle(fuel, R.RefState{h, R.Await{D.Finished{}, D.MatchOver{}, R.PlayerMove{D.Idle{}}}, notes})

def machine_win_gate(+world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, phase: S.Phase, notes: List<&2, D.Note>, final: Bool) -> R.RefState:
  +state : S.State = pack(world, seats, phase, notes)
  +players : S.Players = S.state.players(state)
  +prize : U32 = D.prize(S.world.round_index(world))
  cash : U32 = Q.value.or(U32, D.ring.get(U32, S.players.cash(players), seat), 0)
  players : S.Players = S.players.set_cash(players, D.ring.set(U32, S.players.cash(players), seat, U32.add(cash, prize)))
  ref(M.win.final(S.state.emit(S.state.set_players(state, players), D.RoundWon{seat, prize}), final))

def finished(h: H.Host, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{h, R.Await{D.Finished{}, D.MatchOver{}, R.PlayerMove{D.Idle{}}}, notes}

def win_notes(+world: S.World, +seat: D.Seat, notes: List<&2, D.Note>) -> List<&2, D.Note>:
  List.append(&2, D.Note, List.append(&2, D.Note, notes, [D.Shown{D.RoundWon{seat, D.prize(S.world.round_index(world))}}]), [D.Shown{D.MatchConcluded{}}])

def machine_health_write(+world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, +seat: D.Seat, health: Nat) -> S.State:
  +players : S.Players = players(seats)
  pack : S.State = pack(world, seats, phase, notes)
  S.state.set_players(pack, S.players.set_health(players, D.ring.set(Nat, S.players.health(players), seat, health)))

def ref_health_write(+world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, +seat: D.Seat, health: Nat) -> R.RefState:
  +h : H.Host = host(world, seats)
  R.with_host(raw_state(world, seats, phase, notes), H.host.set_props(h, seat, H.props.set_health(H.host.props(h, seat), health)))

def ref_written_death(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, +target: D.Seat, shell: D.Shell, +health: Nat) -> Prefix:
  prefix(R.DeathRequest.health(ref_health_write(world, seats, phase, notes, target, health), R.Shot{D.Seat0{}, target, shell, D.Single{}, 0n}, health))

def normalize(state: S.State) -> S.State:
  match state:
    case S.State{world, players, phase, notes}:
      canonical_state(world, core(players), phase, notes)

def round_ready(phase: S.Phase, +world: S.World) -> Bool:
  match phase:
    case S.NeedFirst{}:
      Nat.is_lt(Q.round.next(S.world.before_round(world), S.world.round_index(world)), D.plan.length(S.world.plan(world)))
    case _:
      True{}

def Valid(+state: S.State) -> Data:
  Sigma<&2, &2, {normalize(state) == state : S.State}, _ => Sigma<&2, &2, {Q.config.no_items(S.world.config(S.state.world(state))) == True{} : Bool}, _ => Sigma<&2, &2, {Nat.is_lt(S.world.round_index(S.state.world(state)), D.plan.length(S.world.plan(S.state.world(state)))) == True{} : Bool}, _ => {round_ready(S.state.phase(state), S.state.world(state)) == True{} : Bool}>>>

def next(state: S.State, n: Nat) -> S.State:
  machine_step_state(M.answer(state, n))

def Simulation(+state: S.State, +n: Nat) -> Data:
  Sigma<&2, &2, {ref_answer(ref(state), n) == stepped(M.answer(state, n)) : RefStep()}, _ => Sigma<&2, &2, {machine_point(next(state, n)) == ref_step_point(ref_answer(ref(state), n)) : D.Point}, _ => Valid(next(state, n))>>

def StepOracle() -> Type:
  @+state: S.State -> @+n: Nat -> @+valid: Valid(state) -> Simulation(state, n)

def ref_run(fuel: Nat, state: R.RefState, tape: List<&2, Nat>) -> D.Ran<&2, R.RefState>:
  R.run(fuel, state, tape)

def RefRan() -> Data:
  D.Ran<&2, R.RefState>

def observation_board(pair: D.Obs & List<&2, D.Heard>) -> D.Board:
  match pair:
    case (D.Obs{seat, board}, heard):
      board

def point_of_ref(state: S.State) -> D.Point:
  R.point(ref(state))

def support.round(plan: D.Plan, index: Nat) -> D.RoundRules:
  H.rules.found(D.plan.round(plan, index))

def support.current_items(world: S.World, seats: D.Ring<&2, CoreSeat>) -> D.ItemRules:
  H.rules.items(H.host.rules(host(world, seats)))

def support.items(round: D.RoundRules) -> D.ItemRules:
  H.rules.items(round)


def valid.norm(+state: S.State, valid: Valid(state)) -> {normalize(state) == state : S.State}:
  match valid:
    case Tuple{eq, _}:
      eq

def simulation.step(+state: S.State, +n: Nat, simulation: Simulation(state, n)) -> {ref_answer(ref(state), n) == stepped(M.answer(state, n)) : RefStep()}:
  match simulation:
    case Tuple{eq, _}:
      eq

def simulation.next(+state: S.State, +n: Nat, simulation: Simulation(state, n)) -> Valid(next(state, n)):
  match simulation:
    case Tuple{_, Tuple{_, valid}}:
      valid

def ref_driver(fuel: Nat, request: D.Request, +state: R.RefState, tape: List<&2, Nat>) -> D.Ran<&2, R.RefState>:
  match fuel request tape:
    case _ D.Finished{} tape:
      D.Ran{state, Nil{}, tape}
    case _ D.Stuck{} tape:
      D.Ran{state, Nil{}, tape}
    case 0n _ tape:
      D.Ran{state, Nil{}, tape}
    case _ _ Nil{}:
      D.Ran{state, Nil{}, Nil{}}
    case 1n+fuel _ n <> rest:
      +next : D.Stepped<&2, R.RefState> = R.answer(state, n)
      R.run.merge(next, R.run(fuel, R.stepped.state(next), rest))

def RefContinuation() -> Data:
  R.Continuation

def ref_await(h: H.Host, request: D.Request, stage: D.Stage, continuation: R.Continuation, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{h, R.Await{request, stage, continuation}, notes}

def ref_merge(step: D.Stepped<&2, R.RefState>, ran: D.Ran<&2, R.RefState>) -> D.Ran<&2, R.RefState>:
  R.run.merge(step, ran)

def ref_next(step: D.Stepped<&2, R.RefState>) -> R.RefState:
  R.stepped.state(step)

def machine_merge(step: D.Stepped<&2, S.State>, ran: D.Ran<&2, S.State>) -> D.Ran<&2, S.State>:
  M.run.merge(step, ran)


type Pending is Data:
  Pending{request: D.Request, stage: D.Stage, continuation: R.Continuation}

def pending(frame: R.Frame) -> Pending:
  match frame:
    case R.Await{request, stage, continuation}:
      Pending{request, stage, continuation}
    case _:
      Pending{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}

def pending.state(h: H.Host, pending: Pending, notes: List<&2, D.Note>) -> R.RefState:
  match pending:
    case Pending{request, stage, continuation}:
      ref_await(h, request, stage, continuation, notes)

def pending.request(pending: Pending) -> D.Request:
  match pending:
    case Pending{request, _, _}:
      request

def ref_pending(+state: S.State) -> Pending:
  match state:
    case S.State{world, players, phase, _}:
      pending(frame(phase, host(world, core(players))))

def ref_host(state: S.State) -> H.Host:
  match state:
    case S.State{world, players, _, _}:
      host(world, core(players))

def exposed_ref(+state: S.State) -> R.RefState:
  pending.state(ref_host(state), ref_pending(state), S.state.notes(state))

def pending.batch_raw(h: H.Host, deck: List<&2, H.Batch>, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{h, batch.frame(deck), notes}

def pending.batch_exposed(h: H.Host, deck: List<&2, H.Batch>, notes: List<&2, D.Note>) -> R.RefState:
  pending.state(h, pending(batch.frame(deck)), notes)


def RunHypothesis(+fuel: Nat) -> Type:
  @+state:S.State -> @+tape:List<&2, Nat> -> @+valid:Valid(state) -> {ref_run(fuel, ref(state), tape) == ran(M.run(fuel, state, tape)) : RefRan()}


def Stable(+world: S.World, +seats: D.Ring<&2, CoreSeat>) -> Data:
  Sigma<&2, &2, {world_for(world, seats) == world : S.World}, _ => Sigma<&2, &2, {Q.config.no_items(S.world.config(world)) == True{} : Bool}, _ => {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}>>

def preserve.turn_at(+seats: D.Ring<&2, CoreSeat>, seat: D.Seat, props: CoreSeat) -> D.Ring<&2, CoreSeat>:
  match props:
    case CoreSeat{hp, jam, checked, cash, slots, _}:
      D.ring.set(CoreSeat, seats, seat, CoreSeat{hp, jam, checked, cash, slots, True{}})

def preserve.turn(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> D.Ring<&2, CoreSeat>:
  preserve.turn_at(seats, seat, value.or(CoreSeat, D.ring.get(CoreSeat, seats, seat), CoreSeat{100n, False{}, False{}, 0, D.slots.empty(), False{}}))

def preserve.GrantHypothesis(+rank: Nat) -> Type:
  @+world:S.World -> @+seats:D.Ring<&2, CoreSeat> -> @+phase:S.Phase -> @+notes:List<&2, D.Note> -> @+seat:D.Seat -> @+stable:Stable(world, seats) -> Valid(M.grant.bound(rank, pack(world, seats, phase, notes), seat))

def preserve.norm(+state: S.State, valid: Valid(state)) -> {normalize(state) == state : S.State}:
  match valid:
    case Tuple{eq, _}:
      eq

def items_disabled(items: D.ItemRules) -> Bool:
  Q.items.disabled(items)

def item_disabled(items: D.ItemRules, item: D.Item) -> Bool:
  Q.item.disabled(D.rules.item(items, item))

def disabled_rule(rule: D.ItemRule) -> Bool:
  Q.item.disabled(rule)

def eligible_rule(rule: D.ItemRule, dealt: Bool, own: Nat, total: Nat) -> Bool:
  G.eligible.rule(rule, dealt, own, total)



def current_items(+world: S.World, seats: D.Ring<&2, CoreSeat>) -> D.ItemRules:
  H.rules.items(H.host.rules(host(world, seats)))

def pool_rule(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, +item: D.Item) -> Bool:
  G.eligible.rule(D.rules.item(current_items(world, seats), item), D.item.dealt_at(H.host.table(host(world, seats)), item), G.props.item_count(H.host.props(host(world, seats), seat), item), G.table.item_count(D.ring.entries(H.Props, H.host.seats(host(world, seats))), item))

def ref_pool(+world: S.World, +seats: D.Ring<&2, CoreSeat>, seat: D.Seat, items: List<&2, D.Item>) -> List<&2, D.Item>:
  G.GetItemToGrab.pool(items, host(world, seats), seat)

def ref_pool_step(+world: S.World, +seats: D.Ring<&2, CoreSeat>, seat: D.Seat, item: D.Item, rest: List<&2, D.Item>, keep: Bool) -> List<&2, D.Item>:
  G.GetItemToGrab.put(keep, item, ref_pool(world, seats, seat, rest))


def pool_own(+world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, +item: D.Item) -> Nat:
  G.props.item_count(H.host.props(host(world, seats), seat), item)

def pool_total(+world: S.World, seats: D.Ring<&2, CoreSeat>, +item: D.Item) -> Nat:
  G.table.item_count(D.ring.entries(H.Props, H.host.seats(host(world, seats))), item)


def pool_dealt(world: S.World, seats: D.Ring<&2, CoreSeat>, item: D.Item) -> Bool:
  D.item.dealt_at(H.host.table(host(world, seats)), item)


def rule_off(rule: D.ItemRule) -> D.ItemRule:
  match rule:
    case D.ItemRule{_, cap, global_cap}:
      D.ItemRule{False{}, cap, global_cap}

def items_off(items: D.ItemRules) -> D.ItemRules:
  match items:
    case D.ItemRules{a, b, c, d, e, f, g, h, i}:
      D.ItemRules{rule_off(a), rule_off(b), rule_off(c), rule_off(d), rule_off(e), rule_off(f), rule_off(g), rule_off(h), rule_off(i)}

def pool_rules(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, items: List<&2, D.Item>, +rules: D.ItemRules) -> List<&2, D.Item>:
  match items:
    case Nil{}:
      Nil{}
    case +item <> rest:
      G.GetItemToGrab.put(G.eligible.rule(D.rules.item(rules, item), pool_dealt(world, seats, item), pool_own(world, seats, seat, item), pool_total(world, seats, item)), item, pool_rules(world, seats, seat, rest, rules))

def pool_put(keep: Bool, item: D.Item, rest: List<&2, D.Item>) -> List<&2, D.Item>:
  G.GetItemToGrab.put(keep, item, rest)


def swap_state(world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, i: Nat, notes: List<&2, D.Note>) -> S.State:
  pack(world, seats, S.NeedSwap{load, shells, i}, notes)

def swap_answer(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +i: Nat, +notes: List<&2, D.Note>, n: Nat) -> D.Stepped<&2, R.RefState>:
  stepped(M.answer(swap_state(world, seats, load, shells, i, notes), n))

def swap_point(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +i: Nat, +notes: List<&2, D.Note>, n: Nat) -> D.Point:
  M.point(M.stepped.state(M.answer(swap_state(world, seats, load, shells, i, notes), n)))

def raw_swap(world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, i: Nat, notes: List<&2, D.Note>) -> R.RefState:
  raw_state(world, seats, S.NeedSwap{load, shells, i}, notes)

def ref_swap_step(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, +i: Nat, +j: Nat) -> D.Stepped<&2, R.RefState>:
  R.stepped(R.settle(96n, R.answer.draw(raw_swap(world, seats, load, shells, i, Nil{}), j, R.ShuffleSwapResult{load, shells, i})))

def ref_swap_index(i: Nat) -> Nat:
  G.subtract(i, 1n)

def swap_raw_result(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +load: D.Load, shells: List<&2, D.Shell>, i: Nat) -> D.Stepped<&2, R.RefState>:
  R.stepped(raw_swap(world, seats, load, shells, i, Nil{}))


def ref_shuffle_step(world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, i: Nat) -> D.Stepped<&2, R.RefState>:
  R.stepped(R.settle(96n, R.RefState{host(world, seats), R.GenerateRandomSequence{R.Shuffle{load, shells, i}}, Nil{}}))


def raw_swap_width(world: S.World, seats: D.Ring<&2, CoreSeat>, +load: D.Load, +shells: List<&2, D.Shell>, i: Nat, width: Nat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host(world, seats), R.Await{D.Draw{D.ShuffleSwap{}, D.Range{0n, width}}, D.Loading{}, R.ShuffleSwapResult{load, shells, i}}, notes}

def ref_swap_answer_width(world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, i: Nat, width: Nat, notes: List<&2, D.Note>, n: Nat) -> D.Stepped<&2, R.RefState>:
  R.answer(raw_swap_width(world, seats, load, shells, i, width, notes), n)

def swap_value(width: Nat, n: Nat) -> Nat:
  D.draw.value(D.Range{0n, width}, n)

def machine_swap_state(world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, i: Nat, notes: List<&2, D.Note>, n: Nat) -> S.State:
  M.stepped.state(M.answer(swap_state(world, seats, load, shells, i, notes), n))

def swap_result_state(world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, i: Nat) -> S.State:
  swap_state(world, seats, load, shells, i, Nil{})

def swap_result_state_stepped(world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, i: Nat) -> D.Stepped<&2, R.RefState>:
  stepped(S.state.stepped(swap_result_state(world, seats, load, shells, i)))


def swap_raw_result_width(world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, i: Nat, width: Nat) -> D.Stepped<&2, R.RefState>:
  R.stepped(raw_swap_width(world, seats, load, shells, i, width, Nil{}))


def machine_ref_step(state: S.State) -> D.Stepped<&2, R.RefState>:
  stepped(S.state.stepped(state))

def step_point(result: D.Stepped<&2, S.State>) -> D.Point:
  M.point(M.stepped.state(result))

def machine_answer(state: S.State, n: Nat) -> D.Stepped<&2, S.State>:
  M.answer(state, n)


def ref_rules_found(found: Maybe<&2, D.RoundRules>) -> D.RoundRules:
  H.rules.found(found)

def machine_rules_found(found: Maybe<&2, D.RoundRules>) -> D.RoundRules:
  Q.value.or(D.RoundRules, found, D.config.default_round())

def ref_round_load(round: D.RoundRules, index: Nat) -> D.LoadRule:
  H.rules.load(round, index)

def machine_round_load(round: D.RoundRules, index: Nat) -> D.LoadRule:
  Q.round.load(round, index)

def ref_world_rules(world: S.World, seats: D.Ring<&2, CoreSeat>) -> D.RoundRules:
  H.host.rules(host(world, seats))

def machine_world_rules(world: S.World) -> D.RoundRules:
  Q.world.rules(world)

def ref_world_load(world: S.World, seats: D.Ring<&2, CoreSeat>) -> D.LoadRule:
  H.host.load_rule(host(world, seats))

def machine_world_load(world: S.World) -> D.LoadRule:
  Q.world.load_rule(world)


def health_state(world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> S.State:
  pack(world, seats, S.NeedHealth{}, notes)

def health_world(world: S.World, value: Nat) -> S.World:
  S.world.set_round_health(world, value)

def ref_amount_rule(rule: D.LoadRule) -> D.AmountRule:
  G.load.amount(rule)

def machine_amount_rule(rule: D.LoadRule) -> D.AmountRule:
  Q.load.amount(rule)

def current_amount(world: S.World) -> D.AmountRule:
  Q.load.amount(Q.world.load_rule(world))

def ref_health_value(+world: S.World, +seats: D.Ring<&2, CoreSeat>, value: Nat) -> D.Stepped<&2, R.RefState>:
  R.stepped(R.settle(96n, R.RefState{host(health_world(world, value), seats), R.GetRandomItemGrabAmount{R.PacketSort_StartRound{}}, Nil{}}))

def machine_health_value(+world: S.World, seats: D.Ring<&2, CoreSeat>, value: Nat) -> D.Stepped<&2, R.RefState>:
  machine_ref_step(M.health.chosen(health_state(world, seats, Nil{}), value))

def ref_amount_await(world: S.World, seats: D.Ring<&2, CoreSeat>) -> D.Stepped<&2, R.RefState>:
  R.stepped(raw_state(world, seats, S.NeedAmount{}, Nil{}))

def machine_amount_await(world: S.World, seats: D.Ring<&2, CoreSeat>) -> D.Stepped<&2, R.RefState>:
  machine_ref_step(pack(world, seats, S.NeedAmount{}, Nil{}))

def ref_amount_from_rule(world: S.World, seats: D.Ring<&2, CoreSeat>, rule: D.AmountRule) -> D.Stepped<&2, R.RefState>:
  R.stepped(R.settle(95n, R.GetRandomItemGrabAmount.rule(R.RefState{host(world, seats), R.GetRandomItemGrabAmount{R.PacketSort_StartRound{}}, Nil{}}, R.PacketSort_StartRound{}, rule)))

def machine_amount_from_rule(world: S.World, seats: D.Ring<&2, CoreSeat>, rule: D.AmountRule) -> D.Stepped<&2, R.RefState>:
  machine_ref_step(M.amount.rule(pack(world, seats, S.NeedHealth{}, Nil{}), rule))


def can_grab(props: CoreSeat, new_round: Bool) -> Bool:
  G.props.can_grab(seat.props(props), new_round)

def pool_nonempty(items: List<&2, D.Item>) -> Bool:
  G.nonempty(D.Item, items)

def grab_entries(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +new_round: Bool, entries: List<&2, D.At<&2, CoreSeat>>, +rules: D.ItemRules) -> List<&2, D.Seat>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+seat, props} <> rest:
      G.turn_ring.put(Bool.and(can_grab(props, new_round), pool_nonempty(pool_rules(world, seats, seat, D.item.order(), rules))), seat, grab_entries(world, seats, new_round, rest, rules))

def grab_put(keep: Bool, seat: D.Seat, rest: List<&2, D.Seat>) -> List<&2, D.Seat>:
  G.turn_ring.put(keep, seat, rest)

def ref_grab_entries(+world: S.World, +seats: D.Ring<&2, CoreSeat>, new_round: Bool, entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, D.Seat>:
  G.GetSocketsToBeginItemGrabbingOn.go(props_entries(entries), host(world, seats), new_round)

def ref_grab_seats(+world: S.World, +seats: D.Ring<&2, CoreSeat>, new_round: Bool, amount: Nat) -> List<&2, D.Seat>:
  G.GetSocketsToBeginItemGrabbingOn(host(world, seats), new_round, amount)


def reset_world(world: S.World) -> S.World:
  S.world.set_direction(S.world.set_checking_first_death(world, True{}), D.Clockwise{})

def reset_seat(seat: CoreSeat, health: Nat) -> CoreSeat:
  match seat:
    case CoreSeat{_, _, checked, cash, _, turn}:
      CoreSeat{health, False{}, checked, cash, D.slots.empty(), turn}

def reset_seats(seats: D.Ring<&2, CoreSeat>, +health: Nat) -> D.Ring<&2, CoreSeat>:
  match seats:
    case D.Duo{a, b}:
      D.Duo{reset_seat(a, health), reset_seat(b, health)}
    case D.Trio{a, b, c}:
      D.Trio{reset_seat(a, health), reset_seat(b, health), reset_seat(c, health)}
    case D.Quad{a, b, c, d}:
      D.Quad{reset_seat(a, health), reset_seat(b, health), reset_seat(c, health), reset_seat(d, health)}

def reset_notes(+world: S.World, notes: List<&2, D.Note>) -> List<&2, D.Note>:
  List.append(&2, D.Note, notes, [D.Shown{D.RoundBegan{S.world.round_index(world), S.world.round_health(world), S.world.first_turn(world)}}])

def ref_reset(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.PacketSort_StartRound{}, notes})

def ref_load_begin(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.MainRoutine_LoadShotgun{}, notes})

def ref_begin_grabbing(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>, selected: List<&2, D.Seat>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.BeginItemGrabbingForSockets{selected}, notes})


def machine_round_reset(world: S.World, seats: D.Ring<&2, CoreSeat>, +phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  M.round.reset(pack(world, seats, phase, notes))

def machine_load_after_reset(+world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: S.Phase, +notes: List<&2, D.Note>) -> S.State:
  M.load.begin(pack(reset_world(world), reset_seats(seats, S.world.round_health(world)), phase, reset_notes(world, notes)))

def ref_next_load(first: Bool, index: Nat) -> Nat:
  R.IncrementActiveSequenceIndex(first, index)

def machine_next_load(first: Bool, index: Nat) -> Nat:
  Q.load.next(first, index)

def loaded_world(+world: S.World) -> S.World:
  S.world.set_first_sequence(S.world.set_load_index(world, Q.load.next(S.world.first_sequence(world), S.world.load_index(world))), False{})

def machine_load_begin(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  M.load.begin(pack(world, seats, phase, notes))

def machine_need_batch(world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> S.State:
  pack(world, seats, S.NeedBatch{}, notes)

def shuffle_world(world: S.World, +load: D.Load, shells: List<&2, D.Shell>) -> S.World:
  S.world.set_shown(S.world.set_gun(world, shells), load)

def loaded_notes(notes: List<&2, D.Note>, load: D.Load) -> List<&2, D.Note>:
  List.append(&2, D.Note, notes, [D.Shown{D.Loaded{load}}])

def ref_shuffle_silent(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, i: Nat, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.GenerateRandomSequence{R.Shuffle{load, shells, i}}, notes})

def machine_shuffle(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, load: D.Load, shells: List<&2, D.Shell>, i: Nat) -> S.State:
  M.shuffle(pack(world, seats, phase, notes), load, shells, i)


def ref_swap_final_answer(world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, notes: List<&2, D.Note>, n: Nat) -> D.Stepped<&2, R.RefState>:
  R.answer(raw_swap(world, seats, load, shells, 1n, notes), n)

def ref_shuffle_stepped(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, load: D.Load, shells: List<&2, D.Shell>, notes: List<&2, D.Note>) -> D.Stepped<&2, R.RefState>:
  R.stepped(ref_shuffle_silent(fuel, world, seats, load, shells, 0n, notes))


def ref_step_point_commutes(+state: R.RefState) -> {ref_step_point(R.stepped(state)) == R.point(state) : D.Point}:
  match state:
    case R.RefState{host, frame, notes}:
      {==}


def ref_load_actual(rule: D.LoadRule, sampled: D.Load) -> D.Load:
  G.load.custom(rule, sampled)

def machine_load_actual(rule: D.LoadRule, sampled: D.Load) -> D.Load:
  Q.load.actual(rule, sampled)

def ref_shell_repeat(n: Nat, shell: D.Shell) -> List<&2, D.Shell>:
  G.replicate(n, shell)

def machine_shell_repeat(n: Nat, shell: D.Shell) -> List<&2, D.Shell>:
  Q.repeat(n, shell)

def ref_load_shells(load: D.Load) -> List<&2, D.Shell>:
  G.load.shells(load)

def machine_load_shells(load: D.Load) -> List<&2, D.Shell>:
  Q.load.shells(load)

def ref_predecessor(n: Nat) -> Nat:
  G.subtract(n, 1n)

def machine_predecessor(n: Nat) -> Nat:
  Q.predecessor(n)

def RefBatch() -> Data:
  H.Batch

def ref_batch(batch: S.Batch) -> H.Batch:
  match batch:
    case S.Batch{id, load}:
      H.Batch{id, load}

def found_batch(batch: Maybe<&2, S.Batch>) -> Maybe<&2, H.Batch>:
  match batch:
    case None{}:
      None{}
    case Some{batch}:
      Some{ref_batch(batch)}

def ref_batch_nth(deck: List<&2, S.Batch>, index: Nat) -> Maybe<&2, H.Batch>:
  G.nth(H.Batch, batches(deck), index)

def machine_batch_nth(deck: List<&2, S.Batch>, index: Nat) -> Maybe<&2, H.Batch>:
  found_batch(Q.nth(S.Batch, deck, index))

def ref_batch_remove(deck: List<&2, S.Batch>, index: Nat) -> List<&2, H.Batch>:
  G.remove(H.Batch, batches(deck), index)

def machine_batch_remove(deck: List<&2, S.Batch>, index: Nat) -> List<&2, H.Batch>:
  batches(Q.remove(S.Batch, deck, index))


def ref_host_deck(world: S.World, seats: D.Ring<&2, CoreSeat>) -> List<&2, H.Batch>:
  H.host.deck(host(world, seats))

def ref_remove_deck(deck: List<&2, H.Batch>, index: Nat) -> List<&2, H.Batch>:
  G.remove(H.Batch, deck, index)

def machine_remove_world(+world: S.World, index: Nat) -> S.World:
  S.world.set_deck(world, Q.remove(S.Batch, S.world.deck(world), index))

def ref_shuffle_pending(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, load: D.Load, shells: List<&2, D.Shell>, i: Nat) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.GenerateRandomSequence{R.Shuffle{load, shells, i}}, notes})


def ref_set_deck(+world: S.World, seats: D.Ring<&2, CoreSeat>, deck: List<&2, H.Batch>) -> H.Host:
  H.host.set_deck(host(world, seats), deck)

def ref_removed_host(+world: S.World, +seats: D.Ring<&2, CoreSeat>, index: Nat) -> H.Host:
  H.host.set_deck(host(world, seats), G.remove(H.Batch, H.host.deck(host(world, seats)), index))

def ref_batch_continuation(fuel: Nat, h: H.Host, +load: D.Load, notes: List<&2, D.Note>) -> R.RefState:
  +shells : List<&2, D.Shell> = G.load.shells(load)
  R.settle(fuel, R.RefState{h, R.GenerateRandomSequence{R.Shuffle{load, shells, G.subtract(List.length(&2, D.Shell, shells), 1n)}}, notes})

def ref_batch_found(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, +index: Nat, selected: Maybe<&2, S.Batch>, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.GenerateRandomSequence.batch(R.RefState{host(world, seats), R.GenerateRandomSequence{R.BatchChosen{index}}, notes}, index, found_batch(selected)))

def machine_batch_found(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, index: Nat, selected: Maybe<&2, S.Batch>) -> S.State:
  M.batch.found(pack(world, seats, phase, notes), index, selected)


def machine_deck_remove(deck: List<&2, S.Batch>, index: Nat) -> List<&2, S.Batch>:
  Q.remove(S.Batch, deck, index)


def ref_host_batch_nth(+world: S.World, seats: D.Ring<&2, CoreSeat>, index: Nat) -> Maybe<&2, H.Batch>:
  G.nth(H.Batch, H.host.deck(host(world, seats)), index)

def ref_nth_batch(deck: List<&2, H.Batch>, index: Nat) -> Maybe<&2, H.Batch>:
  G.nth(H.Batch, deck, index)

def machine_batch_lookup(+world: S.World, index: Nat) -> Maybe<&2, S.Batch>:
  Q.nth(S.Batch, S.world.deck(world), index)

def ref_batch_found_ref(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, +index: Nat, selected: Maybe<&2, H.Batch>, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.GenerateRandomSequence.batch(R.RefState{host(world, seats), R.GenerateRandomSequence{R.BatchChosen{index}}, notes}, index, selected))

def ref_batch_chosen(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, index: Nat, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.GenerateRandomSequence{R.BatchChosen{index}}, notes})

def machine_batch(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, index: Nat) -> S.State:
  M.batch(pack(world, seats, phase, notes), index)


def raw_batch_width(world: S.World, seats: D.Ring<&2, CoreSeat>, width: Nat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host(world, seats), R.Await{D.Draw{D.SequenceBatch{}, D.Range{0n, width}}, D.Loading{}, R.SequenceBatchResult{}}, notes}

def ref_batch_answer_width(world: S.World, seats: D.Ring<&2, CoreSeat>, width: Nat, notes: List<&2, D.Note>, n: Nat) -> D.Stepped<&2, R.RefState>:
  R.answer(raw_batch_width(world, seats, width, notes), n)

def machine_batch_answer_width(world: S.World, seats: D.Ring<&2, CoreSeat>, +width: Nat, notes: List<&2, D.Note>, n: Nat) -> D.Stepped<&2, R.RefState>:
  stepped(M.answer.request(pack(world, seats, S.NeedBatch{}, notes), n, D.Draw{D.SequenceBatch{}, D.Range{0n, width}}))

def batch_answer(world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>, n: Nat) -> D.Stepped<&2, R.RefState>:
  stepped(M.answer(pack(world, seats, S.NeedBatch{}, notes), n))

def batch_value(width: Nat, n: Nat) -> Nat:
  D.clamp(n, 1n+width)


def RefDecks() -> Data:
  H.Decks

def ref_generated_batches(loads: List<&2, D.Load>, index: Nat) -> List<&2, H.Batch>:
  H.batches(loads, index)

def machine_generated_batches(loads: List<&2, D.Load>, index: Nat) -> List<&2, H.Batch>:
  batches(Q.batches(loads, index))

def ref_decks3(a: List<&2, H.Batch>, b: List<&2, H.Batch>, c: List<&2, H.Batch>) -> H.Decks:
  H.Decks{a, b, c}

def ref_full_decks() -> H.Decks:
  H.MakeSequenceCopies()

def machine_full_decks() -> H.Decks:
  decks(Q.decks.full())

def ref_refill_host(world: S.World, seats: D.Ring<&2, CoreSeat>) -> H.Host:
  H.host.set_decks(host(world, seats), H.MakeSequenceCopies())

def ref_set_decks(world: S.World, seats: D.Ring<&2, CoreSeat>, decks: H.Decks) -> H.Host:
  H.host.set_decks(host(world, seats), decks)

def machine_refill_world(world: S.World) -> S.World:
  S.world.set_decks(world, Q.decks.full())


def ref_ready(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> R.RefState:
  +h : H.Host = host(world, seats)
  R.settle(fuel, R.GenerateRandomSequence.request(R.RefState{h, R.GenerateRandomSequence{R.SelectBatch{}}, notes}, H.host.deck(h)))

def ref_ready_host(fuel: Nat, +h: H.Host, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.GenerateRandomSequence.request(R.RefState{h, R.GenerateRandomSequence{R.SelectBatch{}}, notes}, H.host.deck(h)))

def machine_ready(+world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  M.load.ready(pack(world, seats, phase, notes), S.world.deck(world))

def ref_select(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.GenerateRandomSequence{R.SelectBatch{}}, notes})

def machine_refill(+world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  M.load.refill(pack(world, seats, phase, notes), S.world.deck(world))


def ref_loading_next(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>, index: Nat) -> R.RefState:
  +h : H.Host = H.host.set_first_sequence(H.host.set_load_index(host(world, seats), index), False{})
  R.settle(fuel, R.RefState{h, R.GenerateRandomSequence{R.SelectBatch{}}, notes})


def amount_world(world: S.World, value: Nat) -> S.World:
  S.world.set_item_amount(world, value)


def ref_amount_begin(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.GetRandomItemGrabAmount{R.PacketSort_StartRound{}}, notes})

def ref_amount_rule_state(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, rule: D.AmountRule, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.GetRandomItemGrabAmount.rule(R.RefState{host(world, seats), R.GetRandomItemGrabAmount{R.PacketSort_StartRound{}}, notes}, R.PacketSort_StartRound{}, rule))

def machine_amount_rule_state(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, rule: D.AmountRule, notes: List<&2, D.Note>) -> S.State:
  M.amount.rule(pack(world, seats, phase, notes), rule)

def machine_amount_begin(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  M.amount.begin(pack(world, seats, phase, notes))


def amount_state(world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> S.State:
  pack(world, seats, S.NeedAmount{}, notes)

def amount_answer(world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>, n: Nat) -> D.Stepped<&2, R.RefState>:
  stepped(M.answer(amount_state(world, seats, notes), n))

def amount_value(+world: S.World, n: Nat) -> Nat:
  D.draw.value(D.table.amount_range(S.world.table(world)), n)

def health_answer(world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>, n: Nat) -> D.Stepped<&2, R.RefState>:
  stepped(M.answer(health_state(world, seats, notes), n))

def health_value(+world: S.World, n: Nat) -> Nat:
  D.draw.value(D.table.health_range(S.world.table(world)), n)


def ref_round_health(rules: D.RoundRules) -> D.HealthRule:
  H.rules.health(rules)

def machine_round_health(rules: D.RoundRules) -> D.HealthRule:
  Q.round.health(rules)

def ref_current_health(world: S.World, seats: D.Ring<&2, CoreSeat>) -> D.HealthRule:
  H.rules.health(H.host.rules(host(world, seats)))

def machine_current_health(world: S.World) -> D.HealthRule:
  Q.round.health(Q.world.rules(world))

def ref_health_begin(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.GenerateRandomRound{}, notes})

def ref_health_rule_state(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, rule: D.HealthRule, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.GenerateRandomRound.rule(R.RefState{host(world, seats), R.GenerateRandomRound{}, notes}, rule))

def machine_health_rule_state(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, rule: D.HealthRule, notes: List<&2, D.Note>) -> S.State:
  M.health.rule(pack(world, seats, phase, notes), rule)

def machine_health_begin(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  M.health.begin(pack(world, seats, phase, notes))

def ref_next_round(before: Bool, index: Nat) -> Nat:
  G.next_round(before, index)

def machine_next_round(before: Bool, index: Nat) -> Nat:
  Q.round.next(before, index)

def first_world(+world: S.World, seat: D.Seat) -> S.World:
  +world : S.World = S.world.set_round_index(world, Q.round.next(S.world.before_round(world), S.world.round_index(world)))
  world : S.World = S.world.set_before_round(world, False{})
  S.world.set_first_sequence(S.world.set_first_turn(world, seat), True{})


def ref_first_chosen(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.MainRoutine_StartRound{R.FirstChosen{seat}}, notes})

def ref_first_next(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>, index: Nat) -> R.RefState:
  h : H.Host = H.host.set_round_index(host(world, seats), index)
  h : H.Host = H.host.set_before_round(h, False{})
  h : H.Host = H.host.set_first_turn(h, seat)
  h : H.Host = H.host.set_first_sequence(h, True{})
  R.settle(fuel, R.RefState{h, R.GenerateRandomRound{}, notes})

def machine_first_chosen(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, seat: D.Seat) -> S.State:
  M.first.chosen(pack(world, seats, phase, notes), seat)

def ref_seat_nth(seats: List<&2, D.Seat>, index: Nat) -> Maybe<&2, D.Seat>:
  G.nth(D.Seat, seats, index)

def machine_seat_nth(seats: List<&2, D.Seat>, index: Nat) -> Maybe<&2, D.Seat>:
  Q.nth(D.Seat, seats, index)

def ref_seat_default(seat: Maybe<&2, D.Seat>) -> D.Seat:
  G.seat.default(seat)

def machine_seat_default(seat: Maybe<&2, D.Seat>) -> D.Seat:
  Q.value.or(D.Seat, seat, D.Seat0{})

def ref_first_seat(table: D.Table, value: Nat) -> D.Seat:
  ref_seat_default(ref_seat_nth(D.table.seats(table), value))

def machine_first_seat(table: D.Table, value: Nat) -> D.Seat:
  machine_seat_default(machine_seat_nth(D.table.seats(table), value))

def ref_first_range(table: D.Table) -> D.Range:
  D.Range{0n, G.subtract(D.table.count(table), 2n)}

def machine_first_range(table: D.Table) -> D.Range:
  V.first.range(table)

def first_value(world: S.World, n: Nat) -> Nat:
  D.draw.value(V.first.range(S.world.table(world)), n)

def first_answer_world(world: S.World, seats: D.Ring<&2, CoreSeat>, n: Nat) -> S.World:
  +w : S.World = world_for(world, seats)
  first_world(w, machine_first_seat(S.world.table(w), first_value(w, n)))

def first_state(world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> S.State:
  pack(world, seats, S.NeedFirst{}, notes)

def first_answer(world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>, n: Nat) -> D.Stepped<&2, R.RefState>:
  stepped(M.answer(first_state(world, seats, notes), n))

def ref_first_answer_range(world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>, n: Nat, range: D.Range) -> D.Stepped<&2, R.RefState>:
  R.answer(R.RefState{host(world, seats), R.Await{D.Draw{D.FirstSeat{}, range}, D.Setup{}, R.FirstSeatResult{}}, notes}, n)

def preserve.plan(config: D.Config) -> D.Plan:
  match config:
    case D.Config{_, plan}:
      plan


def preserve.reset_seats(seats: D.Ring<&2, CoreSeat>, +hp: Nat) -> D.Ring<&2, CoreSeat>:
  match seats:
    case D.Duo{CoreSeat{_, _, c1, p1, _, t1}, CoreSeat{_, _, c3, p3, _, t3}}:
      D.Duo{CoreSeat{hp, False{}, c1, p1, D.slots.empty(), t1}, CoreSeat{hp, False{}, c3, p3, D.slots.empty(), t3}}
    case D.Trio{CoreSeat{_, _, c0, p0, _, t0}, CoreSeat{_, _, c1, p1, _, t1}, CoreSeat{_, _, c2, p2, _, t2}}:
      D.Trio{CoreSeat{hp, False{}, c0, p0, D.slots.empty(), t0}, CoreSeat{hp, False{}, c1, p1, D.slots.empty(), t1}, CoreSeat{hp, False{}, c2, p2, D.slots.empty(), t2}}
    case D.Quad{CoreSeat{_, _, c0, p0, _, t0}, CoreSeat{_, _, c1, p1, _, t1}, CoreSeat{_, _, c2, p2, _, t2}, CoreSeat{_, _, c3, p3, _, t3}}:
      D.Quad{CoreSeat{hp, False{}, c0, p0, D.slots.empty(), t0}, CoreSeat{hp, False{}, c1, p1, D.slots.empty(), t1}, CoreSeat{hp, False{}, c2, p2, D.slots.empty(), t2}, CoreSeat{hp, False{}, c3, p3, D.slots.empty(), t3}}

def preserve.reset_world(world: S.World) -> S.World:
  S.world.set_direction(S.world.set_checking_first_death(world, True{}), D.Clockwise{})

def preserve.reset_notes(+world: S.World, notes: List<&2, D.Note>) -> List<&2, D.Note>:
  +world : S.World = preserve.reset_world(world)
  List.append(&2, D.Note, notes, [D.Shown{D.RoundBegan{S.world.round_index(world), S.world.round_health(world), S.world.first_turn(world)}}])

def preserve.load_world(+world: S.World) -> S.World:
  S.world.set_first_sequence(S.world.set_load_index(world, Q.load.next(S.world.first_sequence(world), S.world.load_index(world))), False{})

def preserve.first_world(+world: S.World, seat: D.Seat) -> S.World:
  S.world.set_first_sequence(S.world.set_first_turn(S.world.set_before_round(S.world.set_round_index(world, Q.round.next(S.world.before_round(world), S.world.round_index(world))), False{}), seat), True{})


type SetupPhase is Data:
  SetupFirst{}
  SetupHealth{}
  SetupAmount{}

def preserve.phase(phase: SetupPhase) -> S.Phase:
  match phase:
    case SetupFirst{}:
      S.NeedFirst{}
    case SetupHealth{}:
      S.NeedHealth{}
    case SetupAmount{}:
      S.NeedAmount{}

def idle.normal(+world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> S.State:
  canonical_state(world, seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes)

def idle.machine_guard(+world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> Bool:
  Q.accepted(idle(world, seats, seat, Nil{}), seat)

def idle.expected(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, allowed: Bool) -> D.Stepped<&2, S.State>:
  match allowed:
    case True{}:
      S.state.stepped(aim_successor(world, seats, seat))
    case False{}:
      S.state.stepped(pack(world, seats, S.Blocked{}, Nil{}))

def idle.permission(+world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat) -> Bool:
  R.props.has_turn(H.host.props(host(world, seats), seat))

def idle.current(world: S.World, seat: D.Seat) -> Bool:
  R.current.eq(S.world.turn(world), seat)

def idle.ref_expected(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, allowed: Bool) -> D.Stepped<&2, R.RefState>:
  match allowed:
    case True{}:
      expected_pickup(world, seats, seat)
    case False{}:
      R.stepped(R.stuck(ref_idle_choose(world, seats, seat, Nil{})))


def ref_first_begin(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.MainRoutine_StartRound{R.BeginRound{}}, notes})

def machine_first_begin(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  M.first.begin(pack(world, seats, phase, notes))

def StartSimulation(+config: D.Config) -> Data:
  Sigma<&2, &2, {ref_start(config) == stepped(M.start(config)) : RefStep()}, _ => Sigma<&2, &2, {ref_step_point(ref_start(config)) == machine_point(machine_step_state(M.start(config))) : D.Point}, _ => Valid(machine_step_state(M.start(config)))>>

def zero_swap(state: S.State) -> Bool:
  match state:
    case S.State{world, players, S.NeedSwap{load, shells, 0n}, notes}:
      True{}
    case _:
      False{}
def turn.machine_living(entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, D.Seat>:
  Q.living(health_entries(entries))

def turn.source_living(entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, D.Seat>:
  G.living(props_entries(entries))

def turn.source_only(seats: List<&2, D.Seat>) -> Maybe<&2, D.Seat>:
  G.CheckIfUserHasWon.result(seats)

def turn.source_winner(world: S.World, seats: D.Ring<&2, CoreSeat>) -> Maybe<&2, D.Seat>:
  G.CheckIfUserHasWon(host(world, seats))

def turn.source_rules_found(found: Maybe<&2, D.RoundRules>) -> D.RoundRules:
  H.rules.found(found)

def turn.source_rules(world: S.World, seats: D.Ring<&2, CoreSeat>) -> D.RoundRules:
  H.host.rules(host(world, seats))

def turn.source_load(round: D.RoundRules, index: Nat) -> D.LoadRule:
  H.rules.load(round, index)

def turn.source_load_rule(world: S.World, seats: D.Ring<&2, CoreSeat>) -> D.LoadRule:
  H.host.load_rule(host(world, seats))

def turn.source_amount_rule(world: S.World, seats: D.Ring<&2, CoreSeat>) -> D.AmountRule:
  G.load.amount(H.host.load_rule(host(world, seats)))

def turn.source_amount_of(rule: D.LoadRule) -> D.AmountRule:
  G.load.amount(rule)

def turn.source_recipient(passing: Bool, current: D.Seat, next: D.Seat) -> D.Seat:
  R.MainRoutine_UserEndTurn.recipient(passing, current, next)

def turn.ref_end(world: S.World, seats: D.Ring<&2, CoreSeat>, from: D.Seat, passing: Bool, empty: Bool, winner: Maybe<&2, D.Seat>, notes: List<&2, D.Note>, fuel: Nat) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.UserEndTurn_Packet{R.EndPacket{from, passing, empty, winner}}, notes})

def turn.ref_rule(world: S.World, seats: D.Ring<&2, CoreSeat>, +from: D.Seat, +passing: Bool, +empty: Bool, +winner: Maybe<&2, D.Seat>, notes: List<&2, D.Note>, fuel: Nat, rule: D.AmountRule) -> R.RefState:
  R.settle(fuel, R.UserEndTurn_Packet.amount(R.RefState{host(world, seats), R.UserEndTurn_Packet{R.EndPacket{from, passing, empty, winner}}, notes}, R.EndPacket{from, passing, empty, winner}, rule))

def turn.ref_main(world: S.World, seats: D.Ring<&2, CoreSeat>, from: D.Seat, passing: Bool, empty: Bool, winner: Maybe<&2, D.Seat>, notes: List<&2, D.Note>, fuel: Nat) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.MainRoutine_UserEndTurn{R.EndPacket{from, passing, empty, winner}}, notes})

def turn.ref_live(world: S.World, seats: D.Ring<&2, CoreSeat>, +from: D.Seat, +passing: Bool, +empty: Bool, +winner: Maybe<&2, D.Seat>, notes: List<&2, D.Note>, fuel: Nat, live: Bool) -> R.RefState:
  R.settle(fuel, R.UserEndTurn_Packet.live(R.RefState{host(world, seats), R.UserEndTurn_Packet{R.EndPacket{from, passing, empty, winner}}, notes}, R.EndPacket{from, passing, empty, winner}, live))

def turn.ref_probe(world: S.World, seats: D.Ring<&2, CoreSeat>) -> Bool:
  G.nonempty(D.Seat, G.GetSocketsToBeginItemGrabbingOn(host(world, seats), False{}, 1n))

def turn.ref_pass(world: S.World, seats: D.Ring<&2, CoreSeat>, +from: D.Seat, +passing: Bool, notes: List<&2, D.Note>, k: Nat, recipient: D.Seat) -> R.RefState:
  R.settle(6n+k, R.MainRoutine_UserEndTurn.pass(R.RefState{host(world, seats), R.MainRoutine_UserEndTurn{R.EndPacket{from, passing, False{}, None{}}}, notes}, False{}, recipient))

def turn.positive_result(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, +recipient: D.Seat) -> R.RefState:
  ref(M.grant(pack(S.world.set_first_turn(world, recipient), seats, phase, notes), recipient))

def turn.machine_winner_case(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, from: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>) -> R.RefState:
  ref(M.turn.winner(pack(world, seats, phase, notes), from, passing, winner))

def turn.ref_actual(+world: S.World, +seats: D.Ring<&2, CoreSeat>, from: D.Seat, passing: Bool, empty: Bool, notes: List<&2, D.Note>, fuel: Nat) -> R.RefState:
  turn.ref_end(world, seats, from, passing, empty, turn.source_winner(world, seats), notes, fuel)

def turn.machine_amount_case(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, from: D.Seat, passing: Bool, rule: D.AmountRule) -> R.RefState:
  ref(M.turn.amount(pack(world, seats, phase, notes), from, passing, rule))

def shot.prefix(+state: S.State, +shooter: D.Seat, +target: D.Seat, +shell: D.Shell, rest: List<&2, D.Shell>) -> S.State:
  +world : S.World = S.state.world(state)
  +ps : S.Players = S.state.players(state)
  +damage : D.Damage = Q.captured(S.world.sawed(world))
  +before : Nat = Q.value.or(Nat, D.ring.get(Nat, S.players.health(ps), target), 100n)
  +health : Nat = Q.shot.health(shell, before, damage)
  +ps : S.Players = S.players.set_health(ps, D.ring.set(Nat, S.players.health(ps), target, health))
  +ps : S.Players = S.players.set_has_turn(ps, D.ring.set(Bool, S.players.has_turn(ps), shooter, False{}))
  world : S.World = S.world.set_sawed(S.world.set_gun(world, rest), False{})
  state : S.State = S.state.emit(S.state.set_players(S.state.set_world(state, world), ps), D.Fired{shooter, target, shell, damage, Q.subtract(before, health), health})
  M.death(state, target, shell, health)

def shot.health_at(seat: CoreSeat, hp: Nat) -> CoreSeat:
  match seat:
    case CoreSeat{_, jam, checked, cash, slots, turn}:
      CoreSeat{hp, jam, checked, cash, slots, turn}

def shot.health_write(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, hp: Nat) -> D.Ring<&2, CoreSeat>:
  D.ring.set(CoreSeat, seats, seat, shot.health_at(value.or(CoreSeat, D.ring.get(CoreSeat, seats, seat), CoreSeat{100n, False{}, False{}, 0, D.slots.empty(), False{}}), hp))

def shot.turn_at(seat: CoreSeat, turn: Bool) -> CoreSeat:
  match seat:
    case CoreSeat{hp, jam, checked, cash, slots, _}:
      CoreSeat{hp, jam, checked, cash, slots, turn}

def shot.turn_write(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, turn: Bool) -> D.Ring<&2, CoreSeat>:
  D.ring.set(CoreSeat, seats, seat, shot.turn_at(value.or(CoreSeat, D.ring.get(CoreSeat, seats, seat), CoreSeat{100n, False{}, False{}, 0, D.slots.empty(), False{}}), turn))

def shot.cash_at(seat: CoreSeat, prize: U32) -> CoreSeat:
  match seat:
    case CoreSeat{hp, jam, checked, cash, slots, turn}:
      CoreSeat{hp, jam, checked, U32.add(cash, prize), slots, turn}

def shot.cash_write(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, prize: U32) -> D.Ring<&2, CoreSeat>:
  D.ring.set(CoreSeat, seats, seat, shot.cash_at(value.or(CoreSeat, D.ring.get(CoreSeat, seats, seat), CoreSeat{100n, False{}, False{}, 0, D.slots.empty(), False{}}), prize))

def turn.ref_probe_list(seats: List<&2, D.Seat>) -> Bool:
  G.nonempty(D.Seat, seats)

def turn.ref_reload_grab(world: S.World, seats: D.Ring<&2, CoreSeat>, from: D.Seat, passing: Bool, notes: List<&2, D.Note>, fuel: Nat, grabbers: List<&2, D.Seat>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.BeginItemGrabbingForSockets{grabbers}, notes})

def turn.ref_reload_pass(world: S.World, seats: D.Ring<&2, CoreSeat>, +from: D.Seat, +passing: Bool, notes: List<&2, D.Note>, k: Nat, recipient: D.Seat) -> R.RefState:
  R.settle(12n+k, R.MainRoutine_UserEndTurn.pass(R.RefState{host(world, seats), R.MainRoutine_UserEndTurn{R.EndPacket{from, passing, True{}, None{}}}, notes}, True{}, recipient))

def turn.reload_result(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, recipient: D.Seat) -> R.RefState:
  ref(M.load.begin(pack(S.world.set_first_turn(world, recipient), seats, phase, notes)))

def win.awarded(+state: S.State, +seat: D.Seat) -> S.State:
  +world : S.World = S.state.world(state)
  +ps : S.Players = S.state.players(state)
  +prize : U32 = D.prize(S.world.round_index(world))
  cash : U32 = Q.value.or(U32, D.ring.get(U32, S.players.cash(ps), seat), 0)
  ps : S.Players = S.players.set_cash(ps, D.ring.set(U32, S.players.cash(ps), seat, U32.add(cash, prize)))
  S.state.emit(S.state.set_players(state, ps), D.RoundWon{seat, prize})

def win.source_gate(world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>, k: Nat, final: Bool) -> R.RefState:
  R.settle(21n+k, R.LoopBackAfterWinRoutine.final(R.WinRoutine(raw_win(world, seats, seat, notes), seat), final))

def win.award_notes(+world: S.World, +seat: D.Seat, notes: List<&2, D.Note>) -> List<&2, D.Note>:
  List.append(&2, D.Note, notes, [D.Shown{D.RoundWon{seat, D.prize(S.world.round_index(world))}}])

def win.source_awarded(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, phase: S.Phase, notes: List<&2, D.Note>) -> R.RefState:
  R.WinRoutine(raw_win(world, seats, seat, notes), seat)


def machine_ran_state(ran: D.Ran<&2, S.State>) -> S.State:
  match ran:
    case D.Ran{state, _, _}:
      state

def ref_ran_point(ran: D.Ran<&2, R.RefState>) -> D.Point:
  match ran:
    case D.Ran{state, _, _}:
      R.point(state)

def RunValidHypothesis(+fuel: Nat) -> Type:
  @+state:S.State -> @+tape:List<&2, Nat> -> @+valid:Valid(state) -> Valid(machine_ran_state(M.run(fuel, state, tape)))


# Aim step: the reference and machine pieces of one shot, named for the proof.
def aim.state(world: S.World, +seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> S.State:
  pack(world, seats, S.Aim{seat, Q.targets(D.ring.entries(Nat, seats.health(seats)))}, notes)

def aim.menus(+world: S.World, seats: D.Ring<&2, CoreSeat>, actor: D.Seat) -> D.Ring<&2, List<&2, D.Move>>:
  D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, S.world.table(world), Nil{}), actor, ref_shots(seats))

def aim.ref_await(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +actor: D.Seat) -> R.RefState:
  R.RefState{host(world, seats), R.Await{D.Choose{aim.menus(world, seats, actor)}, D.Playing{actor, D.Aiming{}}, R.PlayerMove{D.Aiming{}}}, Nil{}}

def aim.ref_pick(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +actor: D.Seat, choice: D.Choice) -> D.Stepped<&2, R.RefState>:
  R.stepped(R.settle(96n, R.answer.move(aim.ref_await(world, seats, actor), choice)))

def aim.ref_accepting(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +actor: D.Seat, choice: D.Choice, accepted: Bool) -> D.Stepped<&2, R.RefState>:
  R.stepped(R.settle(96n, R.answer.move.accepted(aim.ref_await(world, seats, actor), choice, accepted)))

def aim.psv(world: S.World, seats: D.Ring<&2, CoreSeat>, actor: D.Seat, target: D.Seat, index: Nat) -> R.RefState:
  R.RefState{host(world, seats), R.PacketSort_Verification{D.Choice{actor, index, D.Shoot{target}}}, Nil{}}

def ref_settle(fuel: Nat, state: R.RefState) -> R.RefState:
  R.settle(fuel, state)

def aim.so_world(+world: S.World, self_live: Bool) -> S.World:
  match self_live:
    case True{}:
      S.world.set_sawed(world, False{})
    case False{}:
      world

def aim.self_live(actor: D.Seat, target: D.Seat, shell: D.Shell) -> Bool:
  Bool.and(D.seat.eq(actor, target), G.shell.live(shell))

def aim.mid_fuel(self_live: Bool) -> Nat:
  match self_live:
    case True{}:
      92n
    case False{}:
      93n

def aim.before(seats: D.Ring<&2, CoreSeat>, target: D.Seat) -> Nat:
  Q.value.or(Nat, D.ring.get(Nat, seats.health(seats), target), 100n)

def aim.ref_damage(+world: S.World) -> D.Damage:
  G.damage(S.world.sawed(world))

def aim.machine_damage(+world: S.World) -> D.Damage:
  Q.captured(S.world.sawed(world))

def aim.ref_hp(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +target: D.Seat, +shell: D.Shell) -> Nat:
  ref_shot_health(shell, aim.before(seats, target), aim.ref_damage(world))

def aim.machine_hp(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +target: D.Seat, +shell: D.Shell) -> Nat:
  Q.shot.health(shell, aim.before(seats, target), aim.machine_damage(world))

def aim.rs_mid(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +actor: D.Seat, +target: D.Seat, +shell: D.Shell, +rest: List<&2, D.Shell>, +hp: Nat, d: Nat, +dmg: D.Damage) -> R.RefState:
  R.RefState{host(aim.so_world(S.world.set_gun(world, shell <> rest), aim.self_live(actor, target, shell)), shot.turn_write(shot.health_write(seats, target, hp), actor, False{})), R.DeathRequest{R.Shot{actor, target, shell, dmg, List.length(&2, D.Shell, rest)}}, [D.Shown{D.Fired{actor, target, shell, dmg, d, hp}}]}

def aim.ms_mid(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +actor: D.Seat, +target: D.Seat, +shell: D.Shell, rest: List<&2, D.Shell>, phase: S.Phase, +hp: Nat, d: Nat, +dmg: D.Damage) -> S.State:
  M.death(S.State{S.world.set_sawed(S.world.set_gun(world, rest), False{}), S.players.set_has_turn(S.players.set_health(players(seats), D.ring.set(Nat, seats.health(seats), target, hp)), D.ring.set(Bool, seats.has_turn(seats), actor, False{})), phase, [D.Shown{D.Fired{actor, target, shell, dmg, d, hp}}]}, target, shell, hp)

def aim.ue_state(+world: S.World, +seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>, +from: D.Seat, +passing: Bool) -> R.RefState:
  R.RefState{host(world, seats), R.UserEndTurn_Packet{R.EndPacket{from, passing, Nat.is_eq(List.length(&2, D.Shell, S.world.gun(world)), 0n), turn.source_winner(world, seats)}}, notes}

def aim.loop_state(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.frame(R.WinRoutine(raw_win(world, seats, seat, notes), seat), R.MainRoutine_StartRound{R.BeginRound{}})

def aim.loop_expected(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host(world, shot.cash_write(seats, seat, D.prize(S.world.round_index(world)))), R.MainRoutine_StartRound{R.BeginRound{}}, win.award_notes(world, seat, notes)}
