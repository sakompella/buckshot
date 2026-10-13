import Base
import ./domain.bend as D
import ./ref/main.bend as R
import ./ref/state.bend as H
import ./ref/rules.bend as G
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./sm/rules.bend as Q
import ./sm/point.bend as V
import ./sm/items.bend as I
import ./primitive.bend as P
import ./ref/items.bend as RI

def CoreSeat() -> Data:
  S.Seat


def seats.slots(seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, D.Slots>:
  S.players.slots(seats)

def players(+seats: D.Ring<&2, CoreSeat>) -> S.Players:
  seats

# The no-item scope's seat: unjammed (only an item jams), inventory empty.
def seat.free(+seat: CoreSeat) -> CoreSeat:
  S.Seat{S.seat.health(seat), S.Free{}, S.seat.cash(seat), D.slots.empty()}

# The jam_skip_once law's seat: its jam kept, inventory empty.
def seat.jams(+seat: CoreSeat) -> CoreSeat:
  S.Seat{S.seat.health(seat), S.seat.jam(seat), S.seat.cash(seat), D.slots.empty()}

# The no-item scope's Players, whatever the seats say.
def players.free(+seats: D.Ring<&2, CoreSeat>) -> S.Players:
  match seats:
    case D.Duo{a, b}:
      D.Duo{seat.free(a), seat.free(b)}
    case D.Trio{a, b, c}:
      D.Trio{seat.free(a), seat.free(b), seat.free(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.free(a), seat.free(b), seat.free(c), seat.free(d)}

def players.jams(+seats: D.Ring<&2, CoreSeat>) -> S.Players:
  match seats:
    case D.Duo{a, b}:
      D.Duo{seat.jams(a), seat.jams(b)}
    case D.Trio{a, b, c}:
      D.Trio{seat.jams(a), seat.jams(b), seat.jams(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.jams(a), seat.jams(b), seat.jams(c), seat.jams(d)}

# The seats' health, cash and jams, read through the no-item and jam-law
# views so they stay definitionally equal to those views' fields.
def seats.health(+seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, Nat>:
  S.players.health(players.free(seats))

def seats.jam(+seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, S.Jam>:
  S.players.jam(players.jams(seats))

def seats.cash(+seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, U32>:
  S.players.cash(players.free(seats))

# The reference's (is_jammed, jammer_checked) pair of a jam. Free reads as
# (False, False); the reference clears the bit when a jam lifts (D57).
def jam.checked(jam: S.Jam) -> Bool:
  match jam:
    case S.JammedSkipped{}:
      True{}
    case _:
      False{}

# Host props of one seat in the no-item scope: unjammed, empty slots, not grabbing.
def seat.props(seat: CoreSeat) -> H.Props:
  match seat:
    case S.Seat{hp, _, cash, sl}:
      H.Props{hp, False{}, False{}, cash, D.slots.empty(), False{}, None{}, False{}}

# The reference's per-seat has_turn, derived from the phase: only the seat a
# Playing request waits on holds it (Godot clears it on a shot and when an
# item takes effect), and a Blocked machine keeps the seat that held it when
# it stuck.
def turn.holder(phase: S.Phase) -> Maybe<&2, D.Seat>:
  match phase:
    case S.Idle{seat, _}:
      Some{seat}
    case S.Aim{seat}:
      Some{seat}
    case S.NeedPhone{seat, _, _}:
      Some{seat}
    case S.JamPick{seat, _}:
      Some{seat}
    case S.StealPick{seat, _}:
      Some{seat}
    case S.Blocked{holder}:
      holder
    case _:
      None{}

def turn.held(holder: Maybe<&2, D.Seat>, at: D.Seat) -> Bool:
  match holder:
    case None{}:
      False{}
    case Some{seat}:
      D.seat.eq(seat, at)

# Host props of one seat for every config: its slots, its Grabs flags and
# whether it holds the turn.
def seat.props.at(seat: CoreSeat, +grabs: S.Grabs, +holder: Maybe<&2, D.Seat>, +at: D.Seat) -> H.Props:
  match seat:
    case S.Seat{hp, +jam, cash, slots}:
      H.Props{hp, S.jam.jammed(jam), jam.checked(jam), cash, slots, I.seat.grabbing(grabs, at), I.seat.holding(grabs, at), turn.held(holder, at)}

def props.at(seats: D.Ring<&2, CoreSeat>, +grabs: S.Grabs, +holder: Maybe<&2, D.Seat>) -> D.Ring<&2, H.Props>:
  match seats:
    case D.Duo{a, b}:
      D.Duo{seat.props.at(a, grabs, holder, D.Seat1{}), seat.props.at(b, grabs, holder, D.Seat3{})}
    case D.Trio{a, b, c}:
      D.Trio{seat.props.at(a, grabs, holder, D.Seat0{}), seat.props.at(b, grabs, holder, D.Seat1{}), seat.props.at(c, grabs, holder, D.Seat2{})}
    case D.Quad{a, b, c, d}:
      D.Quad{seat.props.at(a, grabs, holder, D.Seat0{}), seat.props.at(b, grabs, holder, D.Seat1{}), seat.props.at(c, grabs, holder, D.Seat2{}), seat.props.at(d, grabs, holder, D.Seat3{})}

def progress.of(+grabs: S.Grabs, +at: D.Seat) -> H.GrabProgress:
  H.GrabProgress{I.seat.granted(grabs, at), I.seat.intake(grabs, at)}

# The reference's per-seat grab progress, in the shape of the seat ring.
def progress.at(seats: D.Ring<&2, CoreSeat>, +grabs: S.Grabs) -> D.Ring<&2, H.GrabProgress>:
  match seats:
    case D.Duo{_, _}:
      D.Duo{progress.of(grabs, D.Seat1{}), progress.of(grabs, D.Seat3{})}
    case D.Trio{_, _, _}:
      D.Trio{progress.of(grabs, D.Seat0{}), progress.of(grabs, D.Seat1{}), progress.of(grabs, D.Seat2{})}
    case D.Quad{_, _, _, _}:
      D.Quad{progress.of(grabs, D.Seat0{}), progress.of(grabs, D.Seat1{}), progress.of(grabs, D.Seat2{}), progress.of(grabs, D.Seat3{})}

def value.or(-A: Data, found: Maybe<&2, A>, fallback: A) -> A:
  match found:
    case Some{x}:
      x
    case None{}:
      fallback

def core(+players: S.Players) -> D.Ring<&2, CoreSeat>:
  players

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

def grabs.empty(+table: D.Table) -> S.Grabs:
  S.Grabs{False{}, D.ring.fill(Bool, table, False{}), D.ring.fill(Maybe<&2, D.Item>, table, None{}), D.ring.fill(Nat, table, 0n), D.ring.fill(Bool, table, False{})}

def grabs(seats: D.Ring<&2, CoreSeat>) -> S.Grabs:
  grabs.empty(D.ring.table(CoreSeat, seats))

# Every-config reference Host: the machine World, the seats' props, and the
# Grabs flags zipped into props (grabbing, holding) and progress (granted, intake).
def host.at(world: S.World, +seats: D.Ring<&2, CoreSeat>, +grabs: S.Grabs, +holder: Maybe<&2, D.Seat>) -> H.Host:
  match world:
    case S.World{+config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      H.Host{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, S.grabs.distributing(grabs), saw, gun, shown, decks(deck), props.at(seats, grabs, holder), progress.at(seats, grabs)}

# No-item scope: the Host of pack(world, seats, phase, _) whose phase's
# turn.holder is holder. It is ref(pack(..))'s host by definition, so the two
# never need a roundtrip rewrite.
def host.held(world: S.World, +seats: D.Ring<&2, CoreSeat>, holder: Maybe<&2, D.Seat>) -> H.Host:
  host.at(world, core(players.free(seats)), grabs(seats), holder)

# The no-item Host between requests or at a phase no seat acts in.
def host(world: S.World, +seats: D.Ring<&2, CoreSeat>) -> H.Host:
  host.held(world, seats, None{})

def props(+seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, H.Props>:
  props.at(core(players.free(seats)), grabs(seats), None{})

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
    case S.Idle{seat, options}:
      idle.frame(h, seat, D.Idle{}, Q.idle.moves(D.nonempty.list(S.IdleOption, options)))
    case S.Aim{seat}:
      idle.frame(h, seat, D.Aiming{}, R.shot_moves(G.living(D.ring.entries(H.Props, H.host.seats(h)))))
    case S.Ended{}:
      R.Await{D.Finished{}, D.MatchOver{}, R.PlayerMove{D.Idle{}}}
    case S.Blocked{_}:
      R.Await{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}
    case S.NeedTurnAmount{from, passing, winner}:
      R.Await{D.Draw{D.ItemAmount{}, D.table.amount_range(H.host.table(h))}, D.Distributing{}, R.ItemAmountResult{R.MainRoutine_UserEndTurn{R.EndPacket{from, passing, Nat.is_eq(List.length(&2, D.Shell, H.host.gun(h)), 0n), winner}}}}
    case S.Grab{needs}:
      R.Await{D.request.choose(I.grab.menus(needs)), D.Distributing{}, R.ItemGrab_Packet{}}
    case S.NeedItem{seat, first, second, +rest}:
      R.Await{D.Draw{D.ItemChoice{}, D.Range{0n, List.length(&2, D.Item, rest)}}, D.Distributing{}, R.ItemChoiceResult{seat, first <> second <> rest}}
    case S.NeedPhone{+seat, owner, slot}:
      R.Await{I.phone.request(List.length(&2, D.Shell, H.host.gun(h))), D.Playing{seat, D.Idle{}}, R.PhoneIndexResult{R.ItemPacket{seat, owner, slot, D.Phone{}, False{}, None{}}}}
    case S.JamPick{seat, targets}:
      idle.frame(h, seat, D.Jamming{}, I.jam.moves(targets))
    case S.StealPick{seat, picks}:
      idle.frame(h, seat, D.Stealing{}, I.steal.moves(picks))

# The reference view of a machine state, for every config: the Host carries
# the slots and the Grabs flags, and the frame is the phase's Await.
def ref(state: S.State) -> R.RefState:
  match state:
    case S.State{world, players, +phase, notes, grabs}:
      +h : H.Host = host.at(world, core(players), grabs, turn.holder(phase))
      R.RefState{h, frame(phase, h), notes}

def stepped(result: D.Stepped<&2, S.State>) -> D.Stepped<&2, R.RefState>:
  match result:
    case D.Stepped{state, notes}:
      D.Stepped{ref(state), notes}

def ran(result: D.Ran<&2, S.State>) -> D.Ran<&2, R.RefState>:
  match result:
    case D.Ran{state, notes, tape}:
      D.Ran{ref(state), notes, tape}

# A machine state from its parts, for every config.
def assemble(world: S.World, +seats: D.Ring<&2, CoreSeat>, grabs: S.Grabs, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  S.State{world, players(seats), phase, notes, grabs}

# No-item scope (B1): empty slots and the initial Grabs, whatever the seats'
# slots say. The laws and the B1 proofs are stated over pack.
def pack(world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  S.State{world, players.free(seats), phase, notes, grabs(seats)}


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
  +h : H.Host = host.held(world, seats, Some{seat})
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
  +h : H.Host = host.held(world, seats, Some{seat})
  R.RefState{h, R.Await{D.Choose{D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, H.host.table(h), Nil{}), seat, [D.PickUp{}])}, D.Playing{seat, D.Idle{}}, R.PlayerMove{D.Idle{}}}, notes}

def ref_idle_request(+world: S.World, seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>, request: D.Request) -> R.RefState:
  R.RefState{host.held(world, seats, Some{seat}), R.Await{request, D.Playing{seat, D.Idle{}}, R.PlayerMove{D.Idle{}}}, notes}

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
    case D.At{seat, S.Seat{hp, _, _, sl}} <> rest:
      D.At{seat, hp} <> health_entries(rest)

def props_entries(entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, D.At<&2, H.Props>>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{seat, props} <> rest:
      D.At{seat, seat.props(props)} <> props_entries(rest)

def machine_shots_entries(entries: List<&2, D.At<&2, CoreSeat>>) -> List<&2, D.Move>:
  Q.aim.moves(Q.targets(health_entries(entries)))

# Host props of the entries when holder holds the turn.
def props_entries.held(entries: List<&2, D.At<&2, CoreSeat>>, +holder: Maybe<&2, D.Seat>) -> List<&2, D.At<&2, H.Props>>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+seat, S.Seat{hp, +jam, cash, sl}} <> rest:
      D.At{seat, H.Props{hp, S.jam.jammed(jam), jam.checked(jam), cash, D.slots.empty(), False{}, None{}, turn.held(holder, seat)}} <> props_entries.held(rest, holder)

def ref_shots_entries(entries: List<&2, D.At<&2, CoreSeat>>, holder: Maybe<&2, D.Seat>) -> List<&2, D.Move>:
  R.shot_moves(G.living(props_entries.held(entries, holder)))

def machine_shots(seats: D.Ring<&2, CoreSeat>) -> List<&2, D.Move>:
  Q.aim.moves(Q.targets(D.ring.entries(Nat, seats.health(seats))))

def ref_shots(+seats: D.Ring<&2, CoreSeat>, holder: Maybe<&2, D.Seat>) -> List<&2, D.Move>:
  R.shot_moves(G.living(D.ring.entries(H.Props, props.at(core(players.free(seats)), grabs(seats), holder))))

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
  pack(world, seats, S.Aim{seat}, [D.Shown{D.PickedUp{seat}}])

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
      S.Aim{seat}

def play_state(world: S.World, +seats: D.Ring<&2, CoreSeat>, seat: D.Seat, aiming: Bool, notes: List<&2, D.Note>) -> S.State:
  pack(world, seats, play_phase(seat, aiming, seats), notes)

def machine_request(state: S.State) -> D.Request:
  M.request(state)

def ref_request(state: R.RefState) -> D.Request:
  R.request(state)

def play_request_with_moves(world: S.World, +seat: D.Seat, moves: List<&2, D.Move>) -> D.Request:
  Q.seat.menu(S.world.table(world), seat, moves)


def raw_state(world: S.World, seats: D.Ring<&2, CoreSeat>, +phase: S.Phase, notes: List<&2, D.Note>) -> R.RefState:
  +h : H.Host = host.held(world, seats, turn.holder(phase))
  R.RefState{h, frame(phase, h), notes}


def machine_stage(phase: S.Phase) -> D.Stage:
  V.phase.stage(phase)

def ref_phase_stage(+world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> D.Stage:
  R.stage(raw_state(world, seats, phase, notes))

def seat.view(seat: CoreSeat) -> D.SeatView:
  match seat:
    case S.Seat{hp, jam, cash, sl}:
      D.SeatView{D.counter.of(False{}, hp), D.slots.empty(), cash, D.NotGrabbing{}}

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


# B1 normal phase: an Idle phase offers only the gun, and a swap at index 0 or a
# phase outside the no-item scope becomes Blocked.
def canonical_phase(phase: S.Phase) -> S.Phase:
  match phase:
    case S.Idle{seat, _}:
      S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}
    case S.NeedSwap{load, shells, 0n}:
      S.Blocked{None{}}
    case S.NeedTurnAmount{_, _, _}:
      S.Blocked{None{}}
    case S.Grab{_}:
      S.Blocked{None{}}
    case S.NeedItem{_, _, _, _}:
      S.Blocked{None{}}
    case S.NeedPhone{_, _, _}:
      S.Blocked{None{}}
    case S.JamPick{_, _}:
      S.Blocked{None{}}
    case S.StealPick{_, _}:
      S.Blocked{None{}}
    case phase:
      phase

def canonical_state(+world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  pack(world_for(world, seats), seats, canonical_phase(phase), notes)

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


# The only moves the core machine offers: pick up when idle, shoot when aiming.
def core_move(mode: D.Mode, move: D.Move) -> Bool:
  match mode move:
    case D.Idle{} D.PickUp{}:
      True{}
    case D.Aiming{} D.Shoot{target}:
      True{}
    case _ _:
      False{}

def choices_shape(+mode: D.Mode, choices: List<&2, D.Choice>) -> Bool:
  match choices:
    case Nil{}:
      True{}
    case D.Choice{seat, index, move} <> rest:
      Bool.and(core_move(mode, move), choices_shape(mode, rest))

def maybe_shape(mode: D.Mode, choice: Maybe<&2, D.Choice>) -> Bool:
  match choice:
    case None{}:
      True{}
    case Some{D.Choice{seat, index, move}}:
      core_move(mode, move)

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
      core_move(mode, move)
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
      S.Aim{seat}
    case Ended{}:
      S.Ended{}
    case Blocked{}:
      S.Blocked{None{}}

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
    case H.Host{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, _, saw, gun, shown, deck, _, _}:
      S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, back.decks(deck)}

def back.jam(jammed: Bool, checked: Bool) -> S.Jam:
  match jammed checked:
    case False{} _:
      S.Free{}
    case True{} False{}:
      S.Jammed{}
    case True{} True{}:
      S.JammedSkipped{}

def back.props(seat: H.Props) -> CoreSeat:
  match seat:
    case H.Props{hp, jammed, checked, cash, slots, _, _, _}:
      S.Seat{hp, back.jam(jammed, checked), cash, slots}

def back.seats(seats: D.Ring<&2, H.Props>) -> D.Ring<&2, CoreSeat>:
  match seats:
    case D.Duo{a, b}:
      D.Duo{back.props(a), back.props(b)}
    case D.Trio{a, b, c}:
      D.Trio{back.props(a), back.props(b), back.props(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{back.props(a), back.props(b), back.props(c), back.props(d)}

def back.grabbing(seats: D.Ring<&2, H.Props>) -> D.Ring<&2, Bool>:
  match seats:
    case D.Duo{a, b}:
      D.Duo{RI.props.grabbing(a), RI.props.grabbing(b)}
    case D.Trio{a, b, c}:
      D.Trio{RI.props.grabbing(a), RI.props.grabbing(b), RI.props.grabbing(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{RI.props.grabbing(a), RI.props.grabbing(b), RI.props.grabbing(c), RI.props.grabbing(d)}

def back.holding(seats: D.Ring<&2, H.Props>) -> D.Ring<&2, Maybe<&2, D.Item>>:
  match seats:
    case D.Duo{a, b}:
      D.Duo{RI.props.holding(a), RI.props.holding(b)}
    case D.Trio{a, b, c}:
      D.Trio{RI.props.holding(a), RI.props.holding(b), RI.props.holding(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{RI.props.holding(a), RI.props.holding(b), RI.props.holding(c), RI.props.holding(d)}

def back.granted(progress: D.Ring<&2, H.GrabProgress>) -> D.Ring<&2, Nat>:
  match progress:
    case D.Duo{a, b}:
      D.Duo{RI.progress.count(a), RI.progress.count(b)}
    case D.Trio{a, b, c}:
      D.Trio{RI.progress.count(a), RI.progress.count(b), RI.progress.count(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{RI.progress.count(a), RI.progress.count(b), RI.progress.count(c), RI.progress.count(d)}

def back.intake(progress: D.Ring<&2, H.GrabProgress>) -> D.Ring<&2, Bool>:
  match progress:
    case D.Duo{a, b}:
      D.Duo{RI.progress.intake(a), RI.progress.intake(b)}
    case D.Trio{a, b, c}:
      D.Trio{RI.progress.intake(a), RI.progress.intake(b), RI.progress.intake(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{RI.progress.intake(a), RI.progress.intake(b), RI.progress.intake(c), RI.progress.intake(d)}

def back.grabs(+h: H.Host) -> S.Grabs:
  S.Grabs{H.host.distributing(h), back.grabbing(H.host.seats(h)), back.holding(H.host.seats(h)), back.granted(H.host.grabs(h)), back.intake(H.host.grabs(h))}

# Typed option lists recovered from the reference's rendered moves.
def back.uses(moves: List<&2, D.Move>) -> List<&2, S.IdleOption>:
  match moves:
    case Nil{}:
      Nil{}
    case D.UseItem{slot, item} <> rest:
      S.UseAt{slot, item} <> back.uses(rest)
    case _ <> rest:
      back.uses(rest)

def back.jams(seats: List<&2, D.Seat>) -> List<&2, S.JamOption>:
  match seats:
    case Nil{}:
      Nil{}
    case seat <> rest:
      S.JamAt{seat} <> back.jams(rest)

def back.steals(moves: List<&2, D.Move>) -> List<&2, S.StealOption>:
  match moves:
    case Nil{}:
      Nil{}
    case D.Steal{owner, slot, item} <> rest:
      S.Pick{owner, slot, item} <> back.steals(rest)
    case _ <> rest:
      back.steals(rest)

def back.grab_options(moves: List<&2, D.Move>) -> List<&2, S.GrabOption>:
  match moves:
    case Nil{}:
      Nil{}
    case D.Grab{} <> rest:
      S.TakeItem{} <> back.grab_options(rest)
    case D.Place{slot} <> rest:
      S.PutAt{slot} <> back.grab_options(rest)
    case _ <> rest:
      back.grab_options(rest)

def back.needs(menus: D.Ring<&2, List<&2, D.Move>>) -> D.Ring<&2, List<&2, S.GrabOption>>:
  match menus:
    case D.Duo{a, b}:
      D.Duo{back.grab_options(a), back.grab_options(b)}
    case D.Trio{a, b, c}:
      D.Trio{back.grab_options(a), back.grab_options(b), back.grab_options(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{back.grab_options(a), back.grab_options(b), back.grab_options(c), back.grab_options(d)}

# The reference's own renderings, as the Await frames hold them.
def ref.use_moves(+h: H.Host, +seat: D.Seat) -> List<&2, D.Move>:
  RI.use_moves(RI.slots.all(), h, seat)

def ref.jam_targets(+h: H.Host, +seat: D.Seat) -> List<&2, D.Seat>:
  RI.jam_targets(D.ring.entries(H.Props, H.host.seats(h)), seat)

def ref.steal_moves(+h: H.Host, +seat: D.Seat) -> List<&2, D.Move>:
  RI.steal_moves(D.ring.entries(H.Props, H.host.seats(h)), h, seat)

def ref.grab_menus(+h: H.Host) -> D.Ring<&2, List<&2, D.Move>>:
  R.grab_menus(D.ring.entries(H.Props, H.host.seats(h)), h, D.ring.fill(List<&2, D.Move>, H.host.table(h), Nil{}))

def back.terminal(stage: D.Stage, request: D.Request) -> S.Phase:
  match stage:
    case D.MatchOver{}:
      match request:
        case D.Finished{}:
          S.Ended{}
        case _:
          S.Blocked{None{}}
    case _:
      S.Blocked{None{}}

def back.play(stage: D.Stage, mode: D.Mode, request: D.Request, +h: H.Host) -> S.Phase:
  match stage:
    case D.Playing{+seat, D.Idle{}}:
      match mode:
        case D.Idle{}:
          S.Idle{seat, D.NonEmpty{S.TakeGun{}, back.uses(ref.use_moves(h, seat))}}
        case _:
          S.Blocked{None{}}
    case D.Playing{seat, D.Aiming{}}:
      match mode:
        case D.Aiming{}:
          S.Aim{seat}
        case _:
          S.Blocked{None{}}
    case D.Playing{+seat, D.Jamming{}}:
      match mode:
        case D.Jamming{}:
          S.JamPick{seat, back.jams(ref.jam_targets(h, seat))}
        case _:
          S.Blocked{None{}}
    case D.Playing{+seat, D.Stealing{}}:
      match mode:
        case D.Stealing{}:
          S.StealPick{seat, back.steals(ref.steal_moves(h, seat))}
        case _:
          S.Blocked{None{}}
    case _:
      back.terminal(stage, request)

# The two ItemAmountResult continuations: a round start, or a turn end.
def back.amount(next: R.Frame) -> S.Phase:
  match next:
    case R.PacketSort_StartRound{}:
      S.NeedAmount{}
    case R.MainRoutine_UserEndTurn{R.EndPacket{from, passing, _, winner}}:
      S.NeedTurnAmount{from, passing, winner}
    case _:
      S.Blocked{None{}}

def back.item_choice(seat: D.Seat, pool: List<&2, D.Item>) -> S.Phase:
  match pool:
    case first <> second <> rest:
      S.NeedItem{seat, first, second, rest}
    case _:
      S.Blocked{None{}}

def back.phone(packet: R.ItemPacket) -> S.Phase:
  match packet:
    case R.ItemPacket{seat, owner, slot, _, _, _}:
      S.NeedPhone{seat, owner, slot}

def back.await(continuation: R.Continuation, stage: D.Stage, request: D.Request, +h: H.Host) -> S.Phase:
  match continuation:
    case R.FirstSeatResult{}:
      S.NeedFirst{}
    case R.StartingHealthResult{}:
      S.NeedHealth{}
    case R.ItemAmountResult{next}:
      back.amount(next)
    case R.SequenceBatchResult{}:
      S.NeedBatch{}
    case R.ShuffleSwapResult{load, shells, i}:
      S.NeedSwap{load, shells, i}
    case R.PlayerMove{mode}:
      back.play(stage, mode, request, h)
    case R.ItemGrab_Packet{}:
      S.Grab{back.needs(ref.grab_menus(h))}
    case R.ItemChoiceResult{seat, pool}:
      back.item_choice(seat, pool)
    case R.PhoneIndexResult{packet}:
      back.phone(packet)

def back.phase(frame: R.Frame, +h: H.Host) -> S.Phase:
  match frame:
    case R.Await{request, stage, continuation}:
      back.await(continuation, stage, request, h)
    case _:
      S.Blocked{None{}}

# The inverse of ref at request points, for every config.
def back(state: R.RefState) -> S.State:
  match state:
    case R.RefState{+h, frame, notes}:
      S.State{back.world(h), players(back.seats(H.host.seats(h))), back.phase(frame, h), notes, back.grabs(h)}

def batches_roundtrip(deck: List<&2, S.Batch>) -> List<&2, S.Batch>:
  back.batches(batches(deck))

def decks_roundtrip(deck: S.Decks) -> S.Decks:
  back.decks(decks(deck))

def world_roundtrip(world: S.World, seats: D.Ring<&2, CoreSeat>, holder: Maybe<&2, D.Seat>) -> S.World:
  back.world(host.held(world, seats, holder))

def grabs_roundtrip(world: S.World, +seats: D.Ring<&2, CoreSeat>, holder: Maybe<&2, D.Seat>) -> S.Grabs:
  back.grabs(host.held(world, seats, holder))

def idle_options_roundtrip(world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> List<&2, S.IdleOption>:
  back.uses(ref.use_moves(host.held(world, seats, Some{seat}), seat))

def seats_roundtrip(+seats: D.Ring<&2, CoreSeat>, holder: Maybe<&2, D.Seat>) -> D.Ring<&2, CoreSeat>:
  back.seats(props.at(core(players.free(seats)), grabs(seats), holder))

def phase_roundtrip(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +phase: RequestPhase) -> S.Phase:
  +h : H.Host = host.held(world, seats, turn.holder(request_phase(phase, seats)))
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
  +holder : Maybe<&2, D.Seat> = turn.holder(request_phase(phase, seats))
  S.State{world_roundtrip(world, seats, holder), players(seats_roundtrip(seats, holder)), phase_roundtrip(world, seats, phase), notes, grabs_roundtrip(world, seats, holder)}

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



# The jam_skip_once law's view of a grant: the machine's jam step (Q.jam) on
# the seats' jams, read back as seats.
type GrantCase is Data:
  GrantAct{seats: D.Ring<&2, CoreSeat>}
  GrantLift{seats: D.Ring<&2, CoreSeat>}
  GrantSkip{seats: D.Ring<&2, CoreSeat>}

def grant.case(result: S.JamResult) -> GrantCase:
  match result:
    case S.Act{players}:
      GrantAct{core(players)}
    case S.Lift{players}:
      GrantLift{core(players)}
    case S.Skip{players}:
      GrantSkip{core(players)}

def grant.jam(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> GrantCase:
  grant.case(Q.jam(players.jams(seats), seat))

# The reference Host of seats with their jams and empty inventories.
def host.jams(world: S.World, +seats: D.Ring<&2, CoreSeat>) -> H.Host:
  host.at(world, core(players.jams(seats)), grabs(seats), None{})

def grant.pass(world: S.World, +seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host.jams(world, seats), R.PassTurn{seat}, notes}

def grant.give.jams(world: S.World, +seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host.jams(world, seats), R.GiveTurnPermissions{seat}, notes}

def grant.dispatch(state: R.RefState) -> R.RefState:
  R.dispatch(state)

def grant.settle(fuel: Nat, state: R.RefState) -> R.RefState:
  R.settle(fuel, state)

def grant.pass_case(+world: S.World, result: GrantCase, +seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  match result:
    case GrantAct{seats}:
      grant.give.jams(S.world.set_turn(world, Some{seat}), seats, seat, notes)
    case GrantLift{seats}:
      grant.give.jams(S.world.set_turn(world, Some{seat}), seats, seat, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]))
    case GrantSkip{+seats}:
      +turned : S.World = S.world.set_turn(world, Some{seat})
      grant.pass(turned, seats, G.GetNextTurn_Socket(host.jams(turned, seats), seat), List.append(&2, D.Note, notes, [D.Shown{D.TurnSkipped{seat}}]))

def grant.clear_at(+seats: D.Ring<&2, CoreSeat>, seat: D.Seat, props: CoreSeat) -> D.Ring<&2, CoreSeat>:
  match props:
    case S.Seat{hp, _, cash, sl}:
      D.ring.set(CoreSeat, seats, seat, S.Seat{hp, S.Free{}, cash, sl})

def grant.clear(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> D.Ring<&2, CoreSeat>:
  grant.clear_at(seats, seat, value.or(CoreSeat, D.ring.get(CoreSeat, seats, seat), S.Seat{100n, S.Free{}, 0, D.slots.empty()}))

def grant.once_claim(result: GrantCase, +seat: D.Seat) -> Type:
  match result:
    case GrantSkip{+after}:
      {D.ring.get(S.Jam, seats.jam(after), seat) == Some{S.JammedSkipped{}} : Maybe<&2, S.Jam>} & {grant.jam(after, seat) == GrantLift{grant.clear(after, seat)} : GrantCase} & {grant.jam(grant.clear(after, seat), seat) == GrantAct{grant.clear(after, seat)} : GrantCase}
    case GrantLift{+after}:
      {D.ring.get(S.Jam, seats.jam(after), seat) == Some{S.Free{}} : Maybe<&2, S.Jam>} & {grant.jam(after, seat) == GrantAct{after} : GrantCase}
    case GrantAct{_}:
      Unit

# No-item scope: every seat is Free, so a grant gives the turn at once.
def grant.pass.free(world: S.World, +seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host(world, seats), R.PassTurn{seat}, notes}

def grant.give(world: S.World, seats: D.Ring<&2, CoreSeat>, seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host(world, seats), R.GiveTurnPermissions{seat}, notes}

def grant.given(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, seat: D.Seat) -> S.State:
  M.give_turn(pack(world, seats, phase, notes), seat)

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
  players : S.Players = S.players.set_cash(players, seat, U32.add(cash, prize))
  ref(M.win.final(S.state.emit(S.state.set_players(state, players), D.RoundWon{seat, prize}), final))

def finished(h: H.Host, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{h, R.Await{D.Finished{}, D.MatchOver{}, R.PlayerMove{D.Idle{}}}, notes}

def win_notes(+world: S.World, +seat: D.Seat, notes: List<&2, D.Note>) -> List<&2, D.Note>:
  List.append(&2, D.Note, List.append(&2, D.Note, notes, [D.Shown{D.RoundWon{seat, D.prize(S.world.round_index(world))}}]), [D.Shown{D.MatchConcluded{}}])

def machine_health_write(+world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, +seat: D.Seat, health: Nat) -> S.State:
  +players : S.Players = players.free(seats)
  pack : S.State = pack(world, seats, phase, notes)
  S.state.set_players(pack, S.players.set_health(players, seat, health))

def ref_health_write(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +phase: S.Phase, notes: List<&2, D.Note>, +seat: D.Seat, health: Nat) -> R.RefState:
  +h : H.Host = host.held(world, seats, turn.holder(phase))
  R.with_host(raw_state(world, seats, phase, notes), H.host.set_props(h, seat, H.props.set_health(H.host.props(h, seat), health)))

def ref_written_death(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, +target: D.Seat, shell: D.Shell, +health: Nat) -> Prefix:
  prefix(R.DeathRequest.health(ref_health_write(world, seats, phase, notes, target, health), R.Shot{D.Seat0{}, target, shell, D.Single{}, 0n}, health))

def normalize(state: S.State) -> S.State:
  match state:
    case S.State{world, players, phase, notes, _}:
      canonical_state(world, core(players), phase, notes)

# What a phase asks of the World: NeedFirst has a round left to begin, and the
# seat an Idle or Aim phase waits on holds world.turn.
def phase_ready(phase: S.Phase, +world: S.World) -> Bool:
  match phase:
    case S.NeedFirst{}:
      Nat.is_lt(Q.round.next(S.world.before_round(world), S.world.round_index(world)), D.plan.length(S.world.plan(world)))
    case S.Idle{seat, _}:
      R.current.eq(S.world.turn(world), seat)
    case S.Aim{seat}:
      R.current.eq(S.world.turn(world), seat)
    case _:
      True{}

def Valid(+state: S.State) -> Data:
  Sigma<&2, &2, {normalize(state) == state : S.State}, _ => Sigma<&2, &2, {Q.config.no_items(S.world.config(S.state.world(state))) == True{} : Bool}, _ => Sigma<&2, &2, {Nat.is_lt(S.world.round_index(S.state.world(state)), D.plan.length(S.world.plan(S.state.world(state)))) == True{} : Bool}, _ => {phase_ready(S.state.phase(state), S.state.world(state)) == True{} : Bool}>>>

def next(state: S.State, n: Nat) -> S.State:
  machine_step_state(M.answer(state, n))

def Simulation(+state: S.State, +n: Nat) -> Data:
  Sigma<&2, &2, {ref_answer(ref(state), n) == stepped(M.answer(state, n)) : RefStep()}, _ => Sigma<&2, &2, {machine_point(next(state, n)) == ref_step_point(ref_answer(ref(state), n)) : D.Point}, _ => Valid(next(state, n))>>

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
    case S.State{world, players, +phase, _, grabs}:
      pending(frame(phase, host.at(world, core(players), grabs, turn.holder(phase))))

def ref_host(state: S.State) -> H.Host:
  match state:
    case S.State{world, players, phase, _, grabs}:
      host.at(world, core(players), grabs, turn.holder(phase))

def ref_deck(+state: S.State) -> List<&2, H.Batch>:
  H.host.deck(ref_host(state))

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
    case S.Seat{_, _, cash, sl}:
      S.Seat{health, S.Free{}, cash, sl}

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


# The state M.round.reset hands to item distribution, as round.reset builds it.
def reset.state(+state: S.State) -> S.State:
  +world : S.World = S.state.world(state)
  players : S.Players = S.players.reset(S.state.players(state), S.world.round_health(world))
  +world : S.World = S.world.set_direction(S.world.set_checking_first_death(world, True{}), D.Clockwise{})
  S.state.emit(S.state.set_players(S.state.set_world(state, world), players), D.RoundBegan{S.world.round_index(world), S.world.round_health(world), S.world.first_turn(world)})

def reset.amount(+state: S.State) -> Nat:
  S.world.item_amount(S.world.set_direction(S.world.set_checking_first_death(S.state.world(state), True{}), D.Clockwise{}))

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
    case D.Duo{S.Seat{_, _, p1, s1}, S.Seat{_, _, p3, s3}}:
      D.Duo{S.Seat{hp, S.Free{}, p1, s1}, S.Seat{hp, S.Free{}, p3, s3}}
    case D.Trio{S.Seat{_, _, p0, s0}, S.Seat{_, _, p1, s1}, S.Seat{_, _, p2, s2}}:
      D.Trio{S.Seat{hp, S.Free{}, p0, s0}, S.Seat{hp, S.Free{}, p1, s1}, S.Seat{hp, S.Free{}, p2, s2}}
    case D.Quad{S.Seat{_, _, p0, s0}, S.Seat{_, _, p1, s1}, S.Seat{_, _, p2, s2}, S.Seat{_, _, p3, s3}}:
      D.Quad{S.Seat{hp, S.Free{}, p0, s0}, S.Seat{hp, S.Free{}, p1, s1}, S.Seat{hp, S.Free{}, p2, s2}, S.Seat{hp, S.Free{}, p3, s3}}

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

def idle.expected(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat) -> D.Stepped<&2, S.State>:
  S.state.stepped(aim_successor(world, seats, seat))

def idle.current(world: S.World, seat: D.Seat) -> Bool:
  R.current.eq(S.world.turn(world), seat)


def ref_first_begin(fuel: Nat, world: S.World, seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.MainRoutine_StartRound{R.BeginRound{}}, notes})

def machine_first_begin(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>) -> S.State:
  M.first.begin(pack(world, seats, phase, notes))

def StartSimulation(+config: D.Config) -> Data:
  Sigma<&2, &2, {ref_start(config) == stepped(M.start(config)) : RefStep()}, _ => Sigma<&2, &2, {ref_step_point(ref_start(config)) == machine_point(machine_step_state(M.start(config))) : D.Point}, _ => Valid(machine_step_state(M.start(config)))>>

def zero_swap(state: S.State) -> Bool:
  match state:
    case S.State{world, players, S.NeedSwap{load, shells, 0n}, notes, grabs}:
      True{}
    case _:
      False{}
# Item phases are outside the no-item scope: the normal form maps them to Blocked.
def item_phase(state: S.State) -> Bool:
  match state:
    case S.State{_, _, S.NeedTurnAmount{_, _, _}, _, _}:
      True{}
    case S.State{_, _, S.Grab{_}, _, _}:
      True{}
    case S.State{_, _, S.NeedItem{_, _, _, _}, _, _}:
      True{}
    case S.State{_, _, S.NeedPhone{_, _, _}, _, _}:
      True{}
    case S.State{_, _, S.JamPick{_, _}, _, _}:
      True{}
    case S.State{_, _, S.StealPick{_, _}, _, _}:
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

# What M.turn.end reaches once the packet's amount rule is known
# (turn.packet with its rule abstracted).
def turn.machine_amount_state(world: S.World, +seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, from: D.Seat, passing: Bool, +rule: D.AmountRule) -> S.State:
  +state : S.State = pack(world, seats, phase, notes)
  +winner : Maybe<&2, D.Seat> = Q.winner(seats.health(seats))
  M.turn.live(state, from, passing, winner, rule, I.amount.live(rule, S.grabs.distributing(S.state.grabs(state)), I.reload.wanted(state, winner)))

def turn.machine_amount_case(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, from: D.Seat, passing: Bool, rule: D.AmountRule) -> R.RefState:
  ref(turn.machine_amount_state(world, seats, phase, notes, from, passing, rule))

def shot.prefix(+state: S.State, +shooter: D.Seat, +target: D.Seat, +shell: D.Shell, rest: List<&2, D.Shell>) -> S.State:
  +world : S.World = S.state.world(state)
  +ps : S.Players = S.state.players(state)
  +damage : D.Damage = Q.captured(S.world.sawed(world))
  +before : Nat = Q.value.or(Nat, D.ring.get(Nat, S.players.health(ps), target), 100n)
  +health : Nat = Q.shot.health(shell, before, damage)
  +ps : S.Players = S.players.set_health(ps, target, health)
  world : S.World = S.world.set_sawed(S.world.set_gun(world, rest), False{})
  state : S.State = S.state.emit(S.state.set_players(S.state.set_world(state, world), ps), D.Fired{shooter, target, shell, damage, Q.subtract(before, health), health})
  M.death(state, target, shell, health)

def shot.health_at(seat: CoreSeat, hp: Nat) -> CoreSeat:
  match seat:
    case S.Seat{_, jam, cash, sl}:
      S.Seat{hp, jam, cash, sl}

def shot.health_write(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, hp: Nat) -> D.Ring<&2, CoreSeat>:
  D.ring.set(CoreSeat, seats, seat, shot.health_at(value.or(CoreSeat, D.ring.get(CoreSeat, seats, seat), S.Seat{100n, S.Free{}, 0, D.slots.empty()}), hp))

def shot.cash_at(seat: CoreSeat, prize: U32) -> CoreSeat:
  match seat:
    case S.Seat{hp, jam, cash, sl}:
      S.Seat{hp, jam, U32.add(cash, prize), sl}

def shot.cash_write(+seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, prize: U32) -> D.Ring<&2, CoreSeat>:
  D.ring.set(CoreSeat, seats, seat, shot.cash_at(value.or(CoreSeat, D.ring.get(CoreSeat, seats, seat), S.Seat{100n, S.Free{}, 0, D.slots.empty()}), prize))

def turn.ref_probe_list(seats: List<&2, D.Seat>) -> Bool:
  G.nonempty(D.Seat, seats)

def turn.ref_reload_grab(world: S.World, seats: D.Ring<&2, CoreSeat>, from: D.Seat, passing: Bool, notes: List<&2, D.Note>, fuel: Nat, grabbers: List<&2, D.Seat>) -> R.RefState:
  R.settle(fuel, R.RefState{host(world, seats), R.BeginItemGrabbingForSockets{grabbers}, notes})

def turn.ref_reload_pass(world: S.World, seats: D.Ring<&2, CoreSeat>, +from: D.Seat, +passing: Bool, notes: List<&2, D.Note>, k: Nat, recipient: D.Seat) -> R.RefState:
  R.settle(12n+k, R.MainRoutine_UserEndTurn.pass(R.RefState{host(world, seats), R.MainRoutine_UserEndTurn{R.EndPacket{from, passing, True{}, None{}}}, notes}, True{}, recipient))

def turn.reload_result(world: S.World, seats: D.Ring<&2, CoreSeat>, phase: S.Phase, notes: List<&2, D.Note>, recipient: D.Seat) -> R.RefState:
  ref(M.reload.begin(pack(S.world.set_first_turn(world, recipient), seats, phase, notes)))

def win.awarded(+state: S.State, +seat: D.Seat) -> S.State:
  +world : S.World = S.state.world(state)
  +ps : S.Players = S.state.players(state)
  +prize : U32 = D.prize(S.world.round_index(world))
  cash : U32 = Q.value.or(U32, D.ring.get(U32, S.players.cash(ps), seat), 0)
  ps : S.Players = S.players.set_cash(ps, seat, U32.add(cash, prize))
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
  pack(world, seats, S.Aim{seat}, notes)

def aim.menus(+world: S.World, seats: D.Ring<&2, CoreSeat>, +actor: D.Seat) -> D.Ring<&2, List<&2, D.Move>>:
  D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, S.world.table(world), Nil{}), actor, ref_shots(seats, Some{actor}))

def aim.ref_await(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +actor: D.Seat) -> R.RefState:
  R.RefState{host.held(world, seats, Some{actor}), R.Await{D.Choose{aim.menus(world, seats, actor)}, D.Playing{actor, D.Aiming{}}, R.PlayerMove{D.Aiming{}}}, Nil{}}

def aim.ref_pick(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +actor: D.Seat, choice: D.Choice) -> D.Stepped<&2, R.RefState>:
  R.stepped(R.settle(96n, R.answer.move(aim.ref_await(world, seats, actor), choice)))

def aim.ref_accepting(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +actor: D.Seat, choice: D.Choice, accepted: Bool) -> D.Stepped<&2, R.RefState>:
  R.stepped(R.settle(96n, R.answer.move.accepted(aim.ref_await(world, seats, actor), choice, accepted)))

def aim.psv(world: S.World, seats: D.Ring<&2, CoreSeat>, +actor: D.Seat, target: D.Seat, index: Nat) -> R.RefState:
  R.RefState{host.held(world, seats, Some{actor}), R.PacketSort_Verification{D.Choice{actor, index, D.Shoot{target}}}, Nil{}}

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
  R.RefState{host(aim.so_world(S.world.set_gun(world, shell <> rest), aim.self_live(actor, target, shell)), shot.health_write(seats, target, hp)), R.DeathRequest{R.Shot{actor, target, shell, dmg, List.length(&2, D.Shell, rest)}}, [D.Shown{D.Fired{actor, target, shell, dmg, d, hp}}]}

def aim.ms_mid(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +actor: D.Seat, +target: D.Seat, +shell: D.Shell, rest: List<&2, D.Shell>, phase: S.Phase, +hp: Nat, d: Nat, +dmg: D.Damage) -> S.State:
  M.death(S.State{S.world.set_sawed(S.world.set_gun(world, rest), False{}), S.players.set_health(players.free(seats), target, hp), phase, [D.Shown{D.Fired{actor, target, shell, dmg, d, hp}}], grabs(seats)}, target, shell, hp)

def aim.ue_state(+world: S.World, +seats: D.Ring<&2, CoreSeat>, notes: List<&2, D.Note>, +from: D.Seat, +passing: Bool) -> R.RefState:
  R.RefState{host(world, seats), R.UserEndTurn_Packet{R.EndPacket{from, passing, Nat.is_eq(List.length(&2, D.Shell, S.world.gun(world)), 0n), turn.source_winner(world, seats)}}, notes}

def aim.loop_state(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.frame(R.WinRoutine(raw_win(world, seats, seat, notes), seat), R.MainRoutine_StartRound{R.BeginRound{}})

def aim.loop_expected(+world: S.World, +seats: D.Ring<&2, CoreSeat>, +seat: D.Seat, notes: List<&2, D.Note>) -> R.RefState:
  R.RefState{host(world, shot.cash_write(seats, seat, D.prize(S.world.round_index(world)))), R.MainRoutine_StartRound{R.BeginRound{}}, win.award_notes(world, seat, notes)}


# ============================================================================
# Every-config interface. ValidItems is the request-point invariant for item
# configs; the B1 Valid above keeps the no-item scope until the laws are lifted.
# ============================================================================

def RefFrame() -> Data:
  R.Frame

def RefItemPacket() -> Data:
  R.ItemPacket

def RefEndPacket() -> Data:
  R.EndPacket

def RefShot() -> Data:
  R.Shot

def Grabs() -> Data:
  S.Grabs

# A Bool fact as a proposition.
def Holds(b: Bool) -> Data:
  {b == True{} : Bool}

def gun_length(+s: S.State) -> Nat:
  List.length(&2, D.Shell, S.world.gun(S.state.world(s)))

def bounded(+s: S.State) -> Bool:
  Nat.is_lt(S.world.round_index(S.state.world(s)), D.plan.length(S.world.plan(S.state.world(s))))

# Item-config normal form: the stored menus of Idle, StealPick and Grab equal
# their recomputation, since the reference checks ownership and the grab flags
# where the machine does not; a swap at index 0 is Blocked. NeedItem, JamPick
# and NeedPhone data need no tie (both models read the stored values).
def canonical_phase_items(+s: S.State, phase: S.Phase) -> S.Phase:
  match phase:
    case S.Idle{+seat, _}:
      S.Idle{seat, D.NonEmpty{S.TakeGun{}, I.uses(s, seat)}}
    case S.NeedSwap{load, shells, 0n}:
      S.Blocked{None{}}
    case S.Grab{_}:
      S.Grab{I.grab.needs(s)}
    case S.StealPick{+seat, _}:
      S.StealPick{seat, I.steal.for(s, seat)}
    case phase:
      phase

def normalize_items(+s: S.State) -> S.State:
  S.state.set_phase(s, canonical_phase_items(s, S.state.phase(s)))

# phase_ready, and every Playing phase's seat holds world.turn: the reference
# checks the turn on a move, and JamPick and NeedPhone resume to Idle.
def items_ready(phase: S.Phase, +world: S.World) -> Bool:
  match phase:
    case S.JamPick{seat, _}:
      R.current.eq(S.world.turn(world), seat)
    case S.StealPick{seat, _}:
      R.current.eq(S.world.turn(world), seat)
    case S.NeedPhone{seat, _, _}:
      R.current.eq(S.world.turn(world), seat)
    case phase:
      phase_ready(phase, world)

def ring_shape(-X: Data, ring: D.Ring<&2, X>, +world: S.World) -> Data:
  {D.ring.table(X, ring) == S.world.table(world) : D.Table}

# The seat ring and every Grabs ring have the config's table constructor.
def Shape(+s: S.State) -> Data:
  match s:
    case S.State{+world, players, _, _, S.Grabs{_, taking, holding, granted, intake}}:
      Sigma<&2, &2, ring_shape(S.Seat, players, world), _ => Sigma<&2, &2, ring_shape(Bool, taking, world), _ => Sigma<&2, &2, ring_shape(Maybe<&2, D.Item>, holding, world), _ => Sigma<&2, &2, ring_shape(Nat, granted, world), _ => ring_shape(Bool, intake, world)>>>>

# The request-point invariant for every config: the item normal form, the
# table tie, the round bound and the phase's turn facts.
def ValidItems(+s: S.State) -> Data:
  Sigma<&2, &2, {normalize_items(s) == s : S.State}, _ => Sigma<&2, &2, Shape(s), _ => Sigma<&2, &2, Holds(bounded(s)), _ => Holds(items_ready(S.state.phase(s), S.state.world(s)))>>>

def valid_items.normal(+s: S.State, valid: ValidItems(s)) -> {normalize_items(s) == s : S.State}:
  match valid:
    case Tuple{x, _}:
      x

def valid_items.shape(+s: S.State, valid: ValidItems(s)) -> Shape(s):
  match valid:
    case Tuple{_, Tuple{x, _}}:
      x

def valid_items.bounded(+s: S.State, valid: ValidItems(s)) -> Holds(bounded(s)):
  match valid:
    case Tuple{_, Tuple{_, Tuple{x, _}}}:
      x

def valid_items.ready(+s: S.State, valid: ValidItems(s)) -> Holds(items_ready(S.state.phase(s), S.state.world(s))):
  match valid:
    case Tuple{_, Tuple{_, Tuple{_, x}}}:
      x

def SimulationItems(+state: S.State, +n: Nat) -> Data:
  Sigma<&2, &2, {ref_answer(ref(state), n) == stepped(M.answer(state, n)) : RefStep()}, _ => Sigma<&2, &2, {machine_point(next(state, n)) == ref_step_point(ref_answer(ref(state), n)) : D.Point}, _ => ValidItems(next(state, n))>>


# The reference closure of a frame from a machine state's host and notes.
def close(fuel: Nat, +s: S.State, f: R.Frame) -> R.RefState:
  R.settle(fuel, R.RefState{ref_host(s), f, S.state.notes(s)})

def Closure(+N: Nat, +s: S.State, +f: R.Frame, +out: S.State) -> Type:
  @+k:Nat -> {close(Nat.add(N, k), s, f) == ref(out) : R.RefState}

# Packets and the nested frames the closure table names.
def end_packet(+s: S.State, from: D.Seat, passing: Bool, winner: Maybe<&2, D.Seat>) -> R.EndPacket:
  R.EndPacket{from, passing, Nat.is_eq(gun_length(s), 0n), winner}

def item_packet(seat: D.Seat, owner: D.Seat, slot: D.Slot, item: D.Item, ending: Bool, phone: Maybe<&2, D.Secret>) -> R.ItemPacket:
  R.ItemPacket{seat, owner, slot, item, ending, phone}

def phone_packet(seat: D.Seat, owner: D.Seat, slot: D.Slot) -> R.ItemPacket:
  R.ItemPacket{seat, owner, slot, D.Phone{}, False{}, None{}}

def shot(shooter: D.Seat, target: D.Seat, shell: D.Shell, damage: D.Damage, after_length: Nat) -> R.Shot:
  R.Shot{shooter, target, shell, damage, after_length}

def frame_Shuffle(load: D.Load, shells: List<&2, D.Shell>, i: Nat) -> R.Frame:
  R.GenerateRandomSequence{R.Shuffle{load, shells, i}}

def frame_BatchChosen(index: Nat) -> R.Frame:
  R.GenerateRandomSequence{R.BatchChosen{index}}

def frame_SelectBatch() -> R.Frame:
  R.GenerateRandomSequence{R.SelectBatch{}}

def frame_BeginRound() -> R.Frame:
  R.MainRoutine_StartRound{R.BeginRound{}}

def frame_FirstChosen(seat: D.Seat) -> R.Frame:
  R.MainRoutine_StartRound{R.FirstChosen{seat}}

def frame_PhoneShell(packet: R.ItemPacket, index: Nat) -> R.Frame:
  R._GetBurnerPhone_Shell{packet, index}

# Closure contexts: equality-only facts about the state a continuation runs
# on. They hold Shape and the seated actors; a closure proof that needs more
# takes it as an extra premise. Caps and inventories are never here.
def Context(+s: S.State) -> Data:
  Shape(s)

def SeatContext(+s: S.State, +seat: D.Seat) -> Data:
  Sigma<&2, &2, Shape(s), _ => P.seated(S.world.table(S.state.world(s)), seat)>

def PairContext(+s: S.State, +seat: D.Seat, +other: D.Seat) -> Data:
  Sigma<&2, &2, Shape(s), _ => Sigma<&2, &2, P.seated(S.world.table(S.state.world(s)), seat), _ => P.seated(S.world.table(S.state.world(s)), other)>>

def context.shape(+s: S.State, ok: Context(s)) -> Shape(s):
  ok

def seat_context.shape(+s: S.State, +seat: D.Seat, ok: SeatContext(s, seat)) -> Shape(s):
  match ok:
    case Tuple{x, _}:
      x

def seat_context.seated(+s: S.State, +seat: D.Seat, ok: SeatContext(s, seat)) -> P.seated(S.world.table(S.state.world(s)), seat):
  match ok:
    case Tuple{_, x}:
      x

def pair_context.shape(+s: S.State, +seat: D.Seat, +other: D.Seat, ok: PairContext(s, seat, other)) -> Shape(s):
  match ok:
    case Tuple{x, _}:
      x

def pair_context.seated(+s: S.State, +seat: D.Seat, +other: D.Seat, ok: PairContext(s, seat, other)) -> P.seated(S.world.table(S.state.world(s)), seat):
  match ok:
    case Tuple{_, Tuple{x, _}}:
      x

def pair_context.other(+s: S.State, +seat: D.Seat, +other: D.Seat, ok: PairContext(s, seat, other)) -> P.seated(S.world.table(S.state.world(s)), other):
  match ok:
    case Tuple{_, Tuple{_, x}}:
      x

# Named contexts of the closure recipes (proof-plan section 2).
def GiveContext(+s: S.State, +seat: D.Seat) -> Data:
  SeatContext(s, seat)

def GrantContext(+s: S.State, +seat: D.Seat) -> Data:
  SeatContext(s, seat)

def ShuffleContext(+s: S.State) -> Data:
  Context(s)

def BatchContext(+s: S.State) -> Data:
  Context(s)

def LoadContext(+s: S.State) -> Data:
  Context(s)

def BeginContext(+s: S.State) -> Data:
  Context(s)

def ResetContext(+s: S.State) -> Data:
  Context(s)

def AmountContext(+s: S.State) -> Data:
  Context(s)

def HealthContext(+s: S.State) -> Data:
  Context(s)

def FirstChosenContext(+s: S.State, +seat: D.Seat) -> Data:
  SeatContext(s, seat)

def FirstContext(+s: S.State) -> Data:
  Context(s)

def WinContext(+s: S.State, +seat: D.Seat) -> Data:
  SeatContext(s, seat)

def TurnContext(+s: S.State, +from: D.Seat) -> Data:
  SeatContext(s, from)

def EndItemContext(+s: S.State, +seat: D.Seat) -> Data:
  SeatContext(s, seat)

def ItemContext(+s: S.State, +seat: D.Seat, +owner: D.Seat) -> Data:
  PairContext(s, seat, owner)

def JamContext(+s: S.State, +seat: D.Seat, +target: D.Seat) -> Data:
  PairContext(s, seat, target)

def GrabContext(+s: S.State, +seat: D.Seat) -> Data:
  SeatContext(s, seat)

# BEGIN GENERATED REF API (tools/ref_api.py)

def frame_MainRoutine_StartRound(phase: R.StartPhase) -> R.Frame:
  R.MainRoutine_StartRound{phase}

def frame_GetFirstTurn_Socket() -> R.Frame:
  R.GetFirstTurn_Socket{}

def frame_GenerateRandomRound() -> R.Frame:
  R.GenerateRandomRound{}

def frame_GetRandomItemGrabAmount(next: R.Frame) -> R.Frame:
  R.GetRandomItemGrabAmount{next}

def frame_PacketSort_StartRound() -> R.Frame:
  R.PacketSort_StartRound{}

def frame_UnJamAllUsers() -> R.Frame:
  R.UnJamAllUsers{}

def frame_SetupHealthIndicators() -> R.Frame:
  R.SetupHealthIndicators{}

def frame_ClearUserInventories() -> R.Frame:
  R.ClearUserInventories{}

def frame_BeginItemGrabbingForSockets(seats: List<&2, D.Seat>) -> R.Frame:
  R.BeginItemGrabbingForSockets{seats}

def frame_MainRoutine_LoadShotgun() -> R.Frame:
  R.MainRoutine_LoadShotgun{}

def frame_GenerateRandomSequence(phase: R.SequencePhase) -> R.Frame:
  R.GenerateRandomSequence{phase}

def frame_LoadShotgun() -> R.Frame:
  R.LoadShotgun{}

def frame_PassTurn(seat: D.Seat) -> R.Frame:
  R.PassTurn{seat}

def frame_GiveTurnPermissions(seat: D.Seat) -> R.Frame:
  R.GiveTurnPermissions{seat}

def frame_ReceivePacket_PickUpShotgun(seat: D.Seat) -> R.Frame:
  R.ReceivePacket_PickUpShotgun{seat}

def frame_PacketSort_Verification(choice: D.Choice) -> R.Frame:
  R.PacketSort_Verification{choice}

def frame_ReceivePacket_Shoot(shot: R.Shot) -> R.Frame:
  R.ReceivePacket_Shoot{shot}

def frame_ShootingOutcome(shot: R.Shot) -> R.Frame:
  R.ShootingOutcome{shot}

def frame_DeathRequest(shot: R.Shot) -> R.Frame:
  R.DeathRequest{shot}

def frame_RemoveFirstShellFromSequence(shot: R.Shot) -> R.Frame:
  R.RemoveFirstShellFromSequence{shot}

def frame_ShotgunBarrel_Grow(next: R.Frame) -> R.Frame:
  R.ShotgunBarrel_Grow{next}

def frame_CheckIfEndingTurn(shot: R.Shot) -> R.Frame:
  R.CheckIfEndingTurn{shot}

def frame_UserEndTurn_Packet(packet: R.EndPacket) -> R.Frame:
  R.UserEndTurn_Packet{packet}

def frame_MainRoutine_UserEndTurn(packet: R.EndPacket) -> R.Frame:
  R.MainRoutine_UserEndTurn{packet}

def frame_WinRoutine(seat: D.Seat) -> R.Frame:
  R.WinRoutine{seat}

def frame_LoopBackAfterWinRoutine() -> R.Frame:
  R.LoopBackAfterWinRoutine{}

def frame_GameConclusion_Packet() -> R.Frame:
  R.GameConclusion_Packet{}

def frame_GameConclusion() -> R.Frame:
  R.GameConclusion{}

def frame_GetItemToGrab(seat: D.Seat) -> R.Frame:
  R.GetItemToGrab{seat}

def frame_ReceivePacket_GrabItem(seat: D.Seat, item: D.Item) -> R.Frame:
  R.ReceivePacket_GrabItem{seat, item}

def frame_IsPlacingLastItem(seat: D.Seat, slot: D.Slot) -> R.Frame:
  R.IsPlacingLastItem{seat, slot}

def frame_CheckIfItemGrabbingFinishedForAllUsers(next: R.Frame) -> R.Frame:
  R.CheckIfItemGrabbingFinishedForAllUsers{next}

def frame_GetSocketArrayToEndItemGrabbingOn(seat: D.Seat, slot: D.Slot) -> R.Frame:
  R.GetSocketArrayToEndItemGrabbingOn{seat, slot}

def frame_EndItemGrabbingAfterNonEligible(seats: List<&2, D.Seat>, next: R.Frame) -> R.Frame:
  R.EndItemGrabbingAfterNonEligible{seats, next}

def frame_ReceivePacket_PlaceItem(seat: D.Seat, slot: D.Slot) -> R.Frame:
  R.ReceivePacket_PlaceItem{seat, slot}

def frame_ContinueItemGrabbing() -> R.Frame:
  R.ContinueItemGrabbing{}

def frame_CheckIfEndingTurnAfterItemUse(seat: D.Seat, owner: D.Seat, slot: D.Slot, item: D.Item) -> R.Frame:
  R.CheckIfEndingTurnAfterItemUse{seat, owner, slot, item}

def frame_GetBurnerPhone_VerbalIndex(packet: R.ItemPacket) -> R.Frame:
  R.GetBurnerPhone_VerbalIndex{packet}

def frame_GetBurnerPhone_Shell(packet: R.ItemPacket, index: Nat) -> R.Frame:
  R._GetBurnerPhone_Shell{packet, index}

def frame_ReceivePacket_InteractWithItem(packet: R.ItemPacket) -> R.Frame:
  R.ReceivePacket_InteractWithItem{packet}

def frame_RemoveItemFromInventory(packet: R.ItemPacket) -> R.Frame:
  R.RemoveItemFromInventory{packet}

def frame_ChangeGameStateWithItem(packet: R.ItemPacket) -> R.Frame:
  R.ChangeGameStateWithItem{packet}

def frame_ShotgunBarrel_Remove(seat: D.Seat) -> R.Frame:
  R.ShotgunBarrel_Remove{seat}

def frame_BeginItemStealing(seat: D.Seat) -> R.Frame:
  R.BeginItemStealing{seat}

def frame_ReceivePacket_InteractWithItem_Secondary(seat: D.Seat, target: D.Seat) -> R.Frame:
  R.ReceivePacket_InteractWithItem_Secondary{seat, target}

def frame_Jammer_Enable(seat: D.Seat, target: D.Seat) -> R.Frame:
  R.Jammer_Enable{seat, target}

def frame_EndItemInteraction(seat: D.Seat, ending: Bool) -> R.Frame:
  R.EndItemInteraction{seat, ending}

def frame_Await(request: D.Request, stage: D.Stage, continuation: R.Continuation) -> R.Frame:
  R.Await{request, stage, continuation}

def cont_FirstSeatResult() -> R.Continuation:
  R.FirstSeatResult{}

def cont_StartingHealthResult() -> R.Continuation:
  R.StartingHealthResult{}

def cont_ItemAmountResult(next: R.Frame) -> R.Continuation:
  R.ItemAmountResult{next}

def cont_SequenceBatchResult() -> R.Continuation:
  R.SequenceBatchResult{}

def cont_ShuffleSwapResult(load: D.Load, shells: List<&2, D.Shell>, i: Nat) -> R.Continuation:
  R.ShuffleSwapResult{load, shells, i}

def cont_PlayerMove(mode: D.Mode) -> R.Continuation:
  R.PlayerMove{mode}

def cont_ItemGrab_Packet() -> R.Continuation:
  R.ItemGrab_Packet{}

def cont_ItemChoiceResult(seat: D.Seat, pool: List<&2, D.Item>) -> R.Continuation:
  R.ItemChoiceResult{seat, pool}

def cont_PhoneIndexResult(packet: R.ItemPacket) -> R.Continuation:
  R.PhoneIndexResult{packet}

def ref_main.frame(+state: R.RefState, +next: R.Frame) -> R.RefState:
  R.frame(state, next)

def ref_main.host(+state: R.RefState) -> H.Host:
  R.host(state)

def ref_main.with_host(+state: R.RefState, +host: H.Host) -> R.RefState:
  R.with_host(state, host)

def ref_main.emit(+state: R.RefState, +event: D.GameEvent) -> R.RefState:
  R.emit(state, event)

def ref_main.grab_menu(props: H.Props, progress: H.GrabProgress, distributing: Bool) -> List<&2, D.Move>:
  R.grab_menu(props, progress, distributing)

def ref_main.grab_menus(+entries: List<&2, D.At<&2, H.Props>>, +h: H.Host, +menus: D.Ring<&2, List<&2, D.Move>>) -> D.Ring<&2, List<&2, D.Move>>:
  R.grab_menus(entries, h, menus)

def ref_main.IncrementActiveSequenceIndex(+first: Bool, +old: Nat) -> Nat:
  R.IncrementActiveSequenceIndex(first, old)

def ref_main.shot_moves(+seats: List<&2, D.Seat>) -> List<&2, D.Move>:
  R.shot_moves(seats)

def ref_main.shot.target(+shot: R.Shot) -> D.Seat:
  R.shot.target(shot)

def ref_main.gun.tail(+gun: List<&2, D.Shell>) -> List<&2, D.Shell>:
  R.gun.tail(gun)

def ref_main.EndPacket.reload(+packet: R.EndPacket) -> Bool:
  R.EndPacket.reload(packet)

def ref_main.MainRoutine_UserEndTurn.recipient(+passing: Bool, +from: D.Seat, +next: D.Seat) -> D.Seat:
  R.MainRoutine_UserEndTurn.recipient(passing, from, next)

def ref_main.request(+state: R.RefState) -> D.Request:
  R.request(state)

def ref_main.stage(+state: R.RefState) -> D.Stage:
  R.stage(state)

def ref_main.props.briefcase(+grab: Bool, +holding: Maybe<&2, D.Item>) -> D.Briefcase:
  R.props.briefcase(grab, holding)

def ref_main.stepped(+state: R.RefState) -> D.Stepped<&2, R.RefState>:
  R.stepped(state)

def ref_main.stepped.state(+stepped: D.Stepped<&2, R.RefState>) -> R.RefState:
  R.stepped.state(stepped)

def ref_main.run.merge(+stepped: D.Stepped<&2, R.RefState>, +ran: D.Ran<&2, R.RefState>) -> D.Ran<&2, R.RefState>:
  R.run.merge(stepped, ran)

def ref_main.trace.prepend(+point: R.TracePoint, +trace: R.Trace) -> R.Trace:
  R.trace.prepend(point, trace)

def ref_main.props.has_turn(+props: H.Props) -> Bool:
  R.props.has_turn(props)

def ref_main.current.eq(+turn: Maybe<&2, D.Seat>, +seat: D.Seat) -> Bool:
  R.current.eq(turn, seat)

def ref_main.VerifyPacket.mode(+mode: D.Mode, +move: D.Move) -> Bool:
  R.VerifyPacket.mode(mode, move)

def ref_main.GetRandomItemGrabAmount.stage(+next: R.Frame) -> D.Stage:
  R.GetRandomItemGrabAmount.stage(next)

def ref_main.stuck(+state: R.RefState) -> R.RefState:
  R.stuck(state)

def ref_main.await_draw(+state: R.RefState, +label: D.Label, +range: D.Range, +stage: D.Stage, +continuation: R.Continuation) -> R.RefState:
  R.await_draw(state, label, range, stage, continuation)

def ref_main.idle(+state: R.RefState, +seat: D.Seat, +mode: D.Mode, +moves: List<&2, D.Move>) -> R.RefState:
  R.idle(state, seat, mode, moves)

def ref_main.MainRoutine_StartRound(+state: R.RefState, +phase: R.StartPhase) -> R.RefState:
  R.MainRoutine_StartRound(state, phase)

def ref_main.PacketSort_StartRound(+state: R.RefState) -> R.RefState:
  R.PacketSort_StartRound(state)

def ref_main.BeginItemGrabbingForSockets(+state: R.RefState, +seats: List<&2, D.Seat>) -> R.RefState:
  R.BeginItemGrabbingForSockets(state, seats)

def ref_main.MainRoutine_LoadShotgun(+state: R.RefState) -> R.RefState:
  R.MainRoutine_LoadShotgun(state)

def ref_main.LoadShotgun(+state: R.RefState) -> R.RefState:
  R.LoadShotgun(state)

def ref_main.PassTurn.props(+state: R.RefState, +seat: D.Seat, +props: H.Props) -> R.RefState:
  R.PassTurn.props(state, seat, props)

def ref_main.ReceivePacket_Shoot.grow(+state: R.RefState, +shot: R.Shot, +self_live: Bool) -> R.RefState:
  R.ReceivePacket_Shoot.grow(state, shot, self_live)

def ref_main.ShootingOutcome(+state: R.RefState, +shot: R.Shot) -> R.RefState:
  R.ShootingOutcome(state, shot)

def ref_main.DeathRequest.first(+state: R.RefState, +seat: D.Seat, +checking: Bool) -> R.RefState:
  R.DeathRequest.first(state, seat, checking)

def ref_main.ShotgunBarrel_Grow(+state: R.RefState, +next: R.Frame) -> R.RefState:
  R.ShotgunBarrel_Grow(state, next)

def ref_main.CheckIfEndingTurn(+state: R.RefState, +shot: R.Shot) -> R.RefState:
  R.CheckIfEndingTurn(state, shot)

def ref_main.UserEndTurn_Packet.live(+state: R.RefState, +packet: R.EndPacket, +live: Bool) -> R.RefState:
  R.UserEndTurn_Packet.live(state, packet, live)

def ref_main.MainRoutine_UserEndTurn.pass(+state: R.RefState, +empty: Bool, +recipient: D.Seat) -> R.RefState:
  R.MainRoutine_UserEndTurn.pass(state, empty, recipient)

def ref_main.WinRoutine(+state: R.RefState, +seat: D.Seat) -> R.RefState:
  R.WinRoutine(state, seat)

def ref_main.LoopBackAfterWinRoutine.final(+state: R.RefState, +final: Bool) -> R.RefState:
  R.LoopBackAfterWinRoutine.final(state, final)

def ref_main.GameConclusion_Packet(+state: R.RefState) -> R.RefState:
  R.GameConclusion_Packet(state)

def ref_main.GameConclusion(+state: R.RefState) -> R.RefState:
  R.GameConclusion(state)

def ref_main.props.view(+props: H.Props) -> D.SeatView:
  R.props.view(props)

def ref_main.VerifyPacket.grab(props: H.Props, move: D.Move) -> Bool:
  R.VerifyPacket.grab(props, move)

def ref_main.VerifyPacket.ownership(host: H.Host, seat: D.Seat, move: D.Move) -> Bool:
  R.VerifyPacket.ownership(host, seat, move)

def ref_main.VerifyPacket(+state: R.RefState, +choice: D.Choice) -> Bool:
  R.VerifyPacket(state, choice)

def ref_main.RemoveFirstShellFromSequence.self(+state: R.RefState, +shot: R.Shot, +self_live: Bool) -> R.RefState:
  R.RemoveFirstShellFromSequence.self(state, shot, self_live)

def ref_main.round_write(+state: R.RefState, write: G.RoundSeatWrite, next: R.Frame) -> R.RefState:
  R.round_write(state, write, next)

def ref_main.GetFirstTurn_Socket.override(+state: R.RefState, +override: Maybe<&2, D.Seat>) -> R.RefState:
  R.GetFirstTurn_Socket.override(state, override)

def ref_main.GenerateRandomRound.rule(+state: R.RefState, +rule: D.HealthRule) -> R.RefState:
  R.GenerateRandomRound.rule(state, rule)

def ref_main.GetRandomItemGrabAmount.rule(+state: R.RefState, +next: R.Frame, +rule: D.AmountRule) -> R.RefState:
  R.GetRandomItemGrabAmount.rule(state, next, rule)

def ref_main.GenerateRandomSequence.request(+state: R.RefState, +deck: List<&2, H.Batch>) -> R.RefState:
  R.GenerateRandomSequence.request(state, deck)

def ref_main.GenerateRandomSequence.batch(+state: R.RefState, +index: Nat, +selected: Maybe<&2, H.Batch>) -> R.RefState:
  R.GenerateRandomSequence.batch(state, index, selected)

def ref_main.PassTurn(+state: R.RefState, +seat: D.Seat) -> R.RefState:
  R.PassTurn(state, seat)

def ref_main.idle_items(+state: R.RefState, +seat: D.Seat) -> R.RefState:
  R.idle_items(state, seat)

def ref_main.GiveTurnPermissions(+state: R.RefState, +seat: D.Seat) -> R.RefState:
  R.GiveTurnPermissions(state, seat)

def ref_main.ReceivePacket_PickUpShotgun(+state: R.RefState, +seat: D.Seat) -> R.RefState:
  R.ReceivePacket_PickUpShotgun(state, seat)

def ref_main.PacketSort_Verification.shell(+state: R.RefState, +shooter: D.Seat, +target: D.Seat, +gun: List<&2, D.Shell>) -> R.RefState:
  R.PacketSort_Verification.shell(state, shooter, target, gun)

def ref_main.DeathRequest.health(+state: R.RefState, +shot: R.Shot, +hp: Nat) -> R.RefState:
  R.DeathRequest.health(state, shot, hp)

def ref_main.UserEndTurn_Packet.amount(+state: R.RefState, +packet: R.EndPacket, +rule: D.AmountRule) -> R.RefState:
  R.UserEndTurn_Packet.amount(state, packet, rule)

def ref_main.MainRoutine_UserEndTurn(+state: R.RefState, +packet: R.EndPacket) -> R.RefState:
  R.MainRoutine_UserEndTurn(state, packet)

def ref_main.LoopBackAfterWinRoutine(+state: R.RefState) -> R.RefState:
  R.LoopBackAfterWinRoutine(state)

def ref_main.seat_views(+entries: List<&2, D.At<&2, H.Props>>, +views: D.Ring<&2, D.SeatView>) -> D.Ring<&2, D.SeatView>:
  R.seat_views(entries, views)

def ref_main.tell(+state: R.RefState, +seat: D.Seat, +secret: D.Secret) -> R.RefState:
  R.tell(state, seat, secret)

def ref_main.GetItemToGrab.selected(+state: R.RefState, +seat: D.Seat, found: Maybe<&2, D.Item>) -> R.RefState:
  R.GetItemToGrab.selected(state, seat, found)

def ref_main.answer.draw(+state: R.RefState, +value: Nat, +continuation: R.Continuation) -> R.RefState:
  R.answer.draw(state, value, continuation)

def ref_main.ReceivePacket_Shoot(+state: R.RefState, +shot: R.Shot) -> R.RefState:
  R.ReceivePacket_Shoot(state, shot)

def ref_main.answer.move.accepted(+state: R.RefState, +choice: D.Choice, +accepted: Bool) -> R.RefState:
  R.answer.move.accepted(state, choice, accepted)

def ref_main.RemoveFirstShellFromSequence.grow(+state: R.RefState, +shot: R.Shot) -> R.RefState:
  R.RemoveFirstShellFromSequence.grow(state, shot)

def ref_main.UnJamAllUsers(state: R.RefState) -> R.RefState:
  R.UnJamAllUsers(state)

def ref_main.SetupHealthIndicators(+state: R.RefState) -> R.RefState:
  R.SetupHealthIndicators(state)

def ref_main.ClearUserInventories(+state: R.RefState) -> R.RefState:
  R.ClearUserInventories(state)

def ref_main.RemoveFirstShellFromSequence(+state: R.RefState, +shot: R.Shot) -> R.RefState:
  R.RemoveFirstShellFromSequence(state, shot)

def ref_main.answer.move(+state: R.RefState, +choice: D.Choice) -> R.RefState:
  R.answer.move(state, choice)

def ref_main.GetFirstTurn_Socket(+state: R.RefState) -> R.RefState:
  R.GetFirstTurn_Socket(state)

def ref_main.GenerateRandomRound(+state: R.RefState) -> R.RefState:
  R.GenerateRandomRound(state)

def ref_main.GetRandomItemGrabAmount(+state: R.RefState, +next: R.Frame) -> R.RefState:
  R.GetRandomItemGrabAmount(state, next)

def ref_main.GenerateRandomSequence.refill(+state: R.RefState, +deck: List<&2, H.Batch>) -> R.RefState:
  R.GenerateRandomSequence.refill(state, deck)

def ref_main.DeathRequest(+state: R.RefState, +shot: R.Shot) -> R.RefState:
  R.DeathRequest(state, shot)

def ref_main.UserEndTurn_Packet(+state: R.RefState, +packet: R.EndPacket) -> R.RefState:
  R.UserEndTurn_Packet(state, packet)

def ref_main.board(+state: R.RefState) -> D.Board:
  R.board(state)

def ref_main.PacketSort_Verification.choice(+state: R.RefState, +choice: D.Choice) -> R.RefState:
  R.PacketSort_Verification.choice(state, choice)

def ref_main.answer.resolved(+state: R.RefState, +continuation: R.Continuation, +resolved: D.Resolved) -> R.RefState:
  R.answer.resolved(state, continuation, resolved)

def ref_main.GenerateRandomSequence(+state: R.RefState, +phase: R.SequencePhase) -> R.RefState:
  R.GenerateRandomSequence(state, phase)

def ref_main.point(+state: R.RefState) -> D.Point:
  R.point(state)

def ref_main.PacketSort_Verification(+state: R.RefState, +choice: D.Choice) -> R.RefState:
  R.PacketSort_Verification(state, choice)

def ref_main.ContinueItemGrabbing.ready(+state: R.RefState, distributing: Bool, holders: Bool) -> R.RefState:
  R.ContinueItemGrabbing.ready(state, distributing, holders)

def ref_main.ContinueItemGrabbing(+state: R.RefState) -> R.RefState:
  R.ContinueItemGrabbing(state)

def ref_main.GetItemToGrab.pool(+state: R.RefState, +seat: D.Seat, pool: List<&2, D.Item>) -> R.RefState:
  R.GetItemToGrab.pool(state, seat, pool)

def ref_main.GetItemToGrab(+state: R.RefState, +seat: D.Seat) -> R.RefState:
  R.GetItemToGrab(state, seat)

def ref_main.ReceivePacket_GrabItem(+state: R.RefState, +seat: D.Seat, +item: D.Item) -> R.RefState:
  R.ReceivePacket_GrabItem(state, seat, item)

def ref_main.IsPlacingLastItem.last(+state: R.RefState, +seat: D.Seat, +slot: D.Slot, last: Bool) -> R.RefState:
  R.IsPlacingLastItem.last(state, seat, slot, last)

def ref_main.IsPlacingLastItem(+state: R.RefState, +seat: D.Seat, slot: D.Slot) -> R.RefState:
  R.IsPlacingLastItem(state, seat, slot)

def ref_main.CheckIfItemGrabbingFinishedForAllUsers.result(+state: R.RefState, next: R.Frame, complete: Bool) -> R.RefState:
  R.CheckIfItemGrabbingFinishedForAllUsers.result(state, next, complete)

def ref_main.CheckIfItemGrabbingFinishedForAllUsers(+state: R.RefState, next: R.Frame) -> R.RefState:
  R.CheckIfItemGrabbingFinishedForAllUsers(state, next)

def ref_main.GetSocketArrayToEndItemGrabbingOn(+state: R.RefState, +seat: D.Seat, +slot: D.Slot) -> R.RefState:
  R.GetSocketArrayToEndItemGrabbingOn(state, seat, slot)

def ref_main.EndItemGrabbingAfterNonEligible(+state: R.RefState, seats: List<&2, D.Seat>, next: R.Frame) -> R.RefState:
  R.EndItemGrabbingAfterNonEligible(state, seats, next)

def ref_main.ReceivePacket_PlaceItem.held(+state: R.RefState, +seat: D.Seat, +slot: D.Slot, held: Maybe<&2, D.Item>) -> R.RefState:
  R.ReceivePacket_PlaceItem.held(state, seat, slot, held)

def ref_main.ReceivePacket_PlaceItem(+state: R.RefState, +seat: D.Seat, slot: D.Slot) -> R.RefState:
  R.ReceivePacket_PlaceItem(state, seat, slot)

def ref_main.CheckIfEndingTurnAfterItemUse.phone(+state: R.RefState, packet: R.ItemPacket, item: D.Item) -> R.RefState:
  R.CheckIfEndingTurnAfterItemUse.phone(state, packet, item)

def ref_main.CheckIfEndingTurnAfterItemUse(+state: R.RefState, +seat: D.Seat, owner: D.Seat, slot: D.Slot, +item: D.Item) -> R.RefState:
  R.CheckIfEndingTurnAfterItemUse(state, seat, owner, slot, item)

def ref_main.packet.phone(packet: R.ItemPacket, phone: D.Secret) -> R.ItemPacket:
  R.packet.phone(packet, phone)

def ref_main.packet.seat(packet: R.ItemPacket) -> D.Seat:
  R.packet.seat(packet)

def ref_main.GetBurnerPhone_VerbalIndex.length(+state: R.RefState, +packet: R.ItemPacket, length: Nat) -> R.RefState:
  R.GetBurnerPhone_VerbalIndex.length(state, packet, length)

def ref_main.GetBurnerPhone_VerbalIndex(+state: R.RefState, packet: R.ItemPacket) -> R.RefState:
  R.GetBurnerPhone_VerbalIndex(state, packet)

def ref_main._GetBurnerPhone_Shell.found(+state: R.RefState, packet: R.ItemPacket, index: Nat, found: Maybe<&2, D.Shell>) -> R.RefState:
  R._GetBurnerPhone_Shell.found(state, packet, index, found)

def ref_main._GetBurnerPhone_Shell(+state: R.RefState, packet: R.ItemPacket, index: Nat) -> R.RefState:
  R._GetBurnerPhone_Shell(state, packet, index)

def ref_main.ReceivePacket_InteractWithItem(+state: R.RefState, +packet: R.ItemPacket) -> R.RefState:
  R.ReceivePacket_InteractWithItem(state, packet)

def ref_main.RemoveItemFromInventory(+state: R.RefState, +packet: R.ItemPacket) -> R.RefState:
  R.RemoveItemFromInventory(state, packet)

def ref_main.ChangeGameStateWithItem.shell(+state: R.RefState, +seat: D.Seat, item: D.Item, ending: Bool, +shell: D.Shell, rest: List<&2, D.Shell>) -> R.RefState:
  R.ChangeGameStateWithItem.shell(state, seat, item, ending, shell, rest)

def ref_main.ChangeGameStateWithItem.head(+state: R.RefState, +seat: D.Seat, +item: D.Item, ending: Bool, gun: List<&2, D.Shell>) -> R.RefState:
  R.ChangeGameStateWithItem.head(state, seat, item, ending, gun)

def ref_main.ChangeGameStateWithItem.heal(+state: R.RefState, +seat: D.Seat, heal: Bool) -> R.RefState:
  R.ChangeGameStateWithItem.heal(state, seat, heal)

def ref_main.ChangeGameStateWithItem.phone(+state: R.RefState, +seat: D.Seat, result: Maybe<&2, D.Secret>) -> R.RefState:
  R.ChangeGameStateWithItem.phone(state, seat, result)

def ref_main.ChangeGameStateWithItem(+state: R.RefState, packet: R.ItemPacket) -> R.RefState:
  R.ChangeGameStateWithItem(state, packet)

def ref_main.ShotgunBarrel_Remove(+state: R.RefState, seat: D.Seat) -> R.RefState:
  R.ShotgunBarrel_Remove(state, seat)

def ref_main.BeginItemStealing(+state: R.RefState, +seat: D.Seat) -> R.RefState:
  R.BeginItemStealing(state, seat)

def ref_main.ReceivePacket_InteractWithItem_Secondary(+state: R.RefState, +seat: D.Seat, target: D.Seat) -> R.RefState:
  R.ReceivePacket_InteractWithItem_Secondary(state, seat, target)

def ref_main.Jammer_Enable(+state: R.RefState, +seat: D.Seat, +target: D.Seat) -> R.RefState:
  R.Jammer_Enable(state, seat, target)

def ref_main.EndItemInteraction(+state: R.RefState, +seat: D.Seat, ending: Bool) -> R.RefState:
  R.EndItemInteraction(state, seat, ending)

def ref_main.dispatch(+state: R.RefState) -> R.RefState:
  R.dispatch(state)

def ref_main.settle(+fuel: Nat, +state: R.RefState) -> R.RefState:
  R.settle(fuel, state)

def ref_main.start(+config: D.Config) -> D.Stepped<&2, R.RefState>:
  R.start(config)

def ref_main.answer.await(+state: R.RefState, +n: Nat) -> R.RefState:
  R.answer.await(state, n)

def ref_main.answer(+state: R.RefState, +n: Nat) -> D.Stepped<&2, R.RefState>:
  R.answer(state, n)

def ref_main.run(+fuel: Nat, +state: R.RefState, +tape: List<&2, Nat>) -> D.Ran<&2, R.RefState>:
  R.run(fuel, state, tape)

def ref_main.trace.points(+tape: List<&2, Nat>, +state: R.RefState) -> R.Trace:
  R.trace.points(tape, state)

def ref_main.trace(+config: D.Config, +tape: List<&2, Nat>) -> R.Trace:
  R.trace(config, tape)

def ref_items.slots.set(slots: D.Slots, slot: D.Slot, value: Maybe<&2, D.Item>) -> D.Slots:
  RI.slots.set(slots, slot, value)

def ref_items.slots.all() -> List<&2, D.Slot>:
  RI.slots.all()

def ref_items.props.slots(props: H.Props) -> D.Slots:
  RI.props.slots(props)

def ref_items.props.holding(props: H.Props) -> Maybe<&2, D.Item>:
  RI.props.holding(props)

def ref_items.props.grabbing(props: H.Props) -> Bool:
  RI.props.grabbing(props)

def ref_items.progress.count(progress: H.GrabProgress) -> Nat:
  RI.progress.count(progress)

def ref_items.progress.intake(progress: H.GrabProgress) -> Bool:
  RI.progress.intake(progress)

def ref_items.begin_grab(seats: List<&2, D.Seat>, +host: H.Host) -> H.Host:
  RI.begin_grab(seats, host)

def ref_items.place_moves.here(value: Maybe<&2, D.Item>, slot: D.Slot, rest: List<&2, D.Move>) -> List<&2, D.Move>:
  RI.place_moves.here(value, slot, rest)

def ref_items.place_moves(slots: List<&2, D.Slot>, +inventory: D.Slots) -> List<&2, D.Move>:
  RI.place_moves(slots, inventory)

def ref_items.grab_moves(props: H.Props, progress: H.GrabProgress) -> List<&2, D.Move>:
  RI.grab_moves(props, progress)

def ref_items.occupied(xs: List<&2, Maybe<&2, D.Item>>) -> Nat:
  RI.occupied(xs)

def ref_items.IsPlacingLastItem(+host: H.Host, +seat: D.Seat) -> Bool:
  RI.IsPlacingLastItem(host, seat)

def ref_items.all_ended(entries: List<&2, D.At<&2, H.Props>>) -> Bool:
  RI.all_ended(entries)

def ref_items.all_empty(entries: List<&2, D.At<&2, H.Props>>, +host: H.Host) -> Bool:
  RI.all_empty(entries, host)

def ref_items.CheckIfItemGrabbingFinishedForAllUsers(+host: H.Host) -> Bool:
  RI.CheckIfItemGrabbingFinishedForAllUsers(host)

def ref_items.GetSocketArrayToEndItemGrabbingOn(entries: List<&2, D.At<&2, H.Props>>, +host: H.Host, +placing: D.Seat) -> List<&2, D.Seat>:
  RI.GetSocketArrayToEndItemGrabbingOn(entries, host, placing)

def ref_items.jam_target(props: H.Props) -> Bool:
  RI.jam_target(props)

def ref_items.jam_targets(entries: List<&2, D.At<&2, H.Props>>, +by: D.Seat) -> List<&2, D.Seat>:
  RI.jam_targets(entries, by)

def ref_items.CheckIfJammerHasEligibleTargets(+host: H.Host, seat: D.Seat) -> Bool:
  RI.CheckIfJammerHasEligibleTargets(host, seat)

def ref_items.valid_steal(+host: H.Host, +seat: D.Seat, item: D.Item) -> Bool:
  RI.valid_steal(host, seat, item)

def ref_items.use_moves.put(keep: Bool, move: D.Move, rest: List<&2, D.Move>) -> List<&2, D.Move>:
  RI.use_moves.put(keep, move, rest)

def ref_items.steal_slots.here(found: Maybe<&2, D.Item>, host: H.Host, thief: D.Seat, owner: D.Seat, slot: D.Slot, rest: List<&2, D.Move>) -> List<&2, D.Move>:
  RI.steal_slots.here(found, host, thief, owner, slot, rest)

def ref_items.steal_slots(slots: List<&2, D.Slot>, +host: H.Host, +thief: D.Seat, +owner: D.Seat) -> List<&2, D.Move>:
  RI.steal_slots(slots, host, thief, owner)

def ref_items.steal_moves.here(self: Bool, host: H.Host, thief: D.Seat, owner: D.Seat, rest: List<&2, D.Move>) -> List<&2, D.Move>:
  RI.steal_moves.here(self, host, thief, owner, rest)

def ref_items.steal_moves(entries: List<&2, D.At<&2, H.Props>>, +host: H.Host, +thief: D.Seat) -> List<&2, D.Move>:
  RI.steal_moves(entries, host, thief)

def ref_items.GetPropertyInvalidItems(+host: H.Host, +seat: D.Seat, item: D.Item) -> Bool:
  RI.GetPropertyInvalidItems(host, seat, item)

def ref_items.use_moves.here(found: Maybe<&2, D.Item>, host: H.Host, seat: D.Seat, slot: D.Slot, rest: List<&2, D.Move>) -> List<&2, D.Move>:
  RI.use_moves.here(found, host, seat, slot, rest)

def ref_items.use_moves(slots: List<&2, D.Slot>, +host: H.Host, +seat: D.Seat) -> List<&2, D.Move>:
  RI.use_moves(slots, host, seat)

def ref_items.jam_moves(seats: List<&2, D.Seat>) -> List<&2, D.Move>:
  RI.jam_moves(seats)

def ref_items.FlipTurnOrder(direction: D.Direction) -> D.Direction:
  RI.FlipTurnOrder(direction)

def ref_items.inverted(shell: D.Shell) -> D.Shell:
  RI.inverted(shell)

def ref_items.CheckIfEndingTurnAfterItemUse(item: D.Item, length: Nat) -> Bool:
  RI.CheckIfEndingTurnAfterItemUse(item, length)

def ref_items.holders(entries: List<&2, D.At<&2, H.Props>>) -> Bool:
  RI.holders(entries)

def ref_rules.nth(-A: Data, xs: List<&2, A>, n: Nat) -> Maybe<&2, A>:
  G.nth(A, xs, n)

def ref_rules.set(-A: Data, xs: List<&2, A>, n: Nat, value: A) -> List<&2, A>:
  G.set(A, xs, n, value)

def ref_rules.remove(-A: Data, xs: List<&2, A>, n: Nat) -> List<&2, A>:
  G.remove(A, xs, n)

def ref_rules.seat.default(found: Maybe<&2, D.Seat>) -> D.Seat:
  G.seat.default(found)

def ref_rules.next_index(index: Nat) -> Nat:
  G.next_index(index)

def ref_rules.next_round(before: Bool, index: Nat) -> Nat:
  G.next_round(before, index)

def ref_rules.alive(hp: Nat) -> Bool:
  G.alive(hp)

def ref_rules.turn_ring.put(keep: Bool, seat: D.Seat, rest: List<&2, D.Seat>) -> List<&2, D.Seat>:
  G.turn_ring.put(keep, seat, rest)

def ref_rules.after.pick(hit: Bool, next: D.Seat, rest: D.Seat) -> D.Seat:
  G.after.pick(hit, next, rest)

def ref_rules.health.after(hp: Nat, damage: D.Damage) -> Nat:
  G.health.after(hp, damage)

def ref_rules.damage(sawed: Bool) -> D.Damage:
  G.damage(sawed)

def ref_rules.shell.live(shell: D.Shell) -> Bool:
  G.shell.live(shell)

def ref_rules.subtract(a: Nat, b: Nat) -> Nat:
  G.subtract(a, b)

def ref_rules.CheckIfUserHasWon.result(xs: List<&2, D.Seat>) -> Maybe<&2, D.Seat>:
  G.CheckIfUserHasWon.result(xs)

def ref_rules.slots.list(slots: D.Slots) -> List<&2, Maybe<&2, D.Item>>:
  G.slots.list(slots)

def ref_rules.item.count.bool(hit: Bool) -> Nat:
  G.item.count.bool(hit)

def ref_rules.eligible.rule(rule: D.ItemRule, dealt: Bool, own: Nat, total: Nat) -> Bool:
  G.eligible.rule(rule, dealt, own, total)

def ref_rules.GetItemToGrab.put(keep: Bool, item: D.Item, rest: List<&2, D.Item>) -> List<&2, D.Item>:
  G.GetItemToGrab.put(keep, item, rest)

def ref_rules.nonempty(-A: Data, xs: List<&2, A>) -> Bool:
  G.nonempty(A, xs)

def ref_rules.slots.full(xs: List<&2, Maybe<&2, D.Item>>) -> Bool:
  G.slots.full(xs)

def ref_rules.replicate(n: Nat, +shell: D.Shell) -> List<&2, D.Shell>:
  G.replicate(n, shell)

def ref_rules.load.custom(rule: D.LoadRule, random: D.Load) -> D.Load:
  G.load.custom(rule, random)

def ref_rules.load.amount(rule: D.LoadRule) -> D.AmountRule:
  G.load.amount(rule)

def ref_rules.turn_ring(entries: List<&2, D.At<&2, H.Props>>, +current: D.Seat) -> List<&2, D.Seat>:
  G.turn_ring(entries, current)

def ref_rules.after(xs: List<&2, D.Seat>, +current: D.Seat, +wrap: D.Seat) -> D.Seat:
  G.after(xs, current, wrap)

def ref_rules.shell.health(shell: D.Shell, hp: Nat, damage: D.Damage) -> Nat:
  G.shell.health(shell, hp, damage)

def ref_rules.living(entries: List<&2, D.At<&2, H.Props>>) -> List<&2, D.Seat>:
  G.living(entries)

def ref_rules.item.count.here(slot: Maybe<&2, D.Item>, +item: D.Item) -> Nat:
  G.item.count.here(slot, item)

def ref_rules.props.can_grab(props: H.Props, new_round: Bool) -> Bool:
  G.props.can_grab(props, new_round)

def ref_rules.load.shells(load: D.Load) -> List<&2, D.Shell>:
  G.load.shells(load)

def ref_rules.swap.found(xs: List<&2, D.Shell>, i: Nat, j: Nat, a: Maybe<&2, D.Shell>, b: Maybe<&2, D.Shell>) -> List<&2, D.Shell>:
  G.swap.found(xs, i, j, a, b)

def ref_rules.traversal(xs: List<&2, D.Seat>, +current: D.Seat) -> D.Seat:
  G.traversal(xs, current)

def ref_rules.CheckIfUserHasWon(host: H.Host) -> Maybe<&2, D.Seat>:
  G.CheckIfUserHasWon(host)

def ref_rules.item.count(xs: List<&2, Maybe<&2, D.Item>>, +item: D.Item) -> Nat:
  G.item.count(xs, item)

def ref_rules.swap(+xs: List<&2, D.Shell>, +i: Nat, +j: Nat) -> List<&2, D.Shell>:
  G.swap(xs, i, j)

def ref_rules.directed(direction: D.Direction, xs: List<&2, D.Seat>, current: D.Seat) -> D.Seat:
  G.directed(direction, xs, current)

def ref_rules.props.item_count(props: H.Props, +item: D.Item) -> Nat:
  G.props.item_count(props, item)

def ref_rules.GetNextTurn_Socket(+host: H.Host, +current: D.Seat) -> D.Seat:
  G.GetNextTurn_Socket(host, current)

def ref_rules.table.item_count(entries: List<&2, D.At<&2, H.Props>>, +item: D.Item) -> Nat:
  G.table.item_count(entries, item)

def ref_rules.GetItemToGrab.pool(xs: List<&2, D.Item>, +host: H.Host, +seat: D.Seat) -> List<&2, D.Item>:
  G.GetItemToGrab.pool(xs, host, seat)

def ref_rules.GetSocketsToBeginItemGrabbingOn.go(entries: List<&2, D.At<&2, H.Props>>, +host: H.Host, +new_round: Bool) -> List<&2, D.Seat>:
  G.GetSocketsToBeginItemGrabbingOn.go(entries, host, new_round)

def ref_rules.GetSocketsToBeginItemGrabbingOn(+host: H.Host, new_round: Bool, amount: Nat) -> List<&2, D.Seat>:
  G.GetSocketsToBeginItemGrabbingOn(host, new_round, amount)

def ref_rules.round_seat_write(props: H.Props, write: G.RoundSeatWrite) -> H.Props:
  G.round_seat_write(props, write)

def ref_rules.round_seats(entries: List<&2, D.At<&2, H.Props>>, +write: G.RoundSeatWrite, seats: D.Ring<&2, H.Props>) -> D.Ring<&2, H.Props>:
  G.round_seats(entries, write, seats)

def ref_state.host.before_round(host: H.Host) -> Bool:
  H.host.before_round(host)

def ref_state.host.set_before_round(host: H.Host, value: Bool) -> H.Host:
  H.host.set_before_round(host, value)

def ref_state.host.round_index(host: H.Host) -> Nat:
  H.host.round_index(host)

def ref_state.host.set_round_index(host: H.Host, value: Nat) -> H.Host:
  H.host.set_round_index(host, value)

def ref_state.host.load_index(host: H.Host) -> Nat:
  H.host.load_index(host)

def ref_state.host.set_load_index(host: H.Host, value: Nat) -> H.Host:
  H.host.set_load_index(host, value)

def ref_state.host.first_sequence(host: H.Host) -> Bool:
  H.host.first_sequence(host)

def ref_state.host.set_first_sequence(host: H.Host, value: Bool) -> H.Host:
  H.host.set_first_sequence(host, value)

def ref_state.host.round_health(host: H.Host) -> Nat:
  H.host.round_health(host)

def ref_state.host.set_round_health(host: H.Host, value: Nat) -> H.Host:
  H.host.set_round_health(host, value)

def ref_state.host.first_turn(host: H.Host) -> D.Seat:
  H.host.first_turn(host)

def ref_state.host.set_first_turn(host: H.Host, value: D.Seat) -> H.Host:
  H.host.set_first_turn(host, value)

def ref_state.host.turn(host: H.Host) -> Maybe<&2, D.Seat>:
  H.host.turn(host)

def ref_state.host.set_turn(host: H.Host, value: Maybe<&2, D.Seat>) -> H.Host:
  H.host.set_turn(host, value)

def ref_state.host.direction(host: H.Host) -> D.Direction:
  H.host.direction(host)

def ref_state.host.set_direction(host: H.Host, value: D.Direction) -> H.Host:
  H.host.set_direction(host, value)

def ref_state.host.first_death(host: H.Host) -> Maybe<&2, D.Seat>:
  H.host.first_death(host)

def ref_state.host.set_first_death(host: H.Host, value: Maybe<&2, D.Seat>) -> H.Host:
  H.host.set_first_death(host, value)

def ref_state.host.checking_first_death(host: H.Host) -> Bool:
  H.host.checking_first_death(host)

def ref_state.host.set_checking_first_death(host: H.Host, value: Bool) -> H.Host:
  H.host.set_checking_first_death(host, value)

def ref_state.host.item_amount(host: H.Host) -> Nat:
  H.host.item_amount(host)

def ref_state.host.set_item_amount(host: H.Host, value: Nat) -> H.Host:
  H.host.set_item_amount(host, value)

def ref_state.host.distributing(host: H.Host) -> Bool:
  H.host.distributing(host)

def ref_state.host.set_distributing(host: H.Host, value: Bool) -> H.Host:
  H.host.set_distributing(host, value)

def ref_state.host.sawed(host: H.Host) -> Bool:
  H.host.sawed(host)

def ref_state.host.set_sawed(host: H.Host, value: Bool) -> H.Host:
  H.host.set_sawed(host, value)

def ref_state.host.gun(host: H.Host) -> List<&2, D.Shell>:
  H.host.gun(host)

def ref_state.host.set_gun(host: H.Host, value: List<&2, D.Shell>) -> H.Host:
  H.host.set_gun(host, value)

def ref_state.host.shown(host: H.Host) -> D.Load:
  H.host.shown(host)

def ref_state.host.set_shown(host: H.Host, value: D.Load) -> H.Host:
  H.host.set_shown(host, value)

def ref_state.host.decks(host: H.Host) -> H.Decks:
  H.host.decks(host)

def ref_state.host.set_decks(host: H.Host, value: H.Decks) -> H.Host:
  H.host.set_decks(host, value)

def ref_state.host.seats(host: H.Host) -> D.Ring<&2, H.Props>:
  H.host.seats(host)

def ref_state.host.set_seats(host: H.Host, value: D.Ring<&2, H.Props>) -> H.Host:
  H.host.set_seats(host, value)

def ref_state.props.initial() -> H.Props:
  H.props.initial()

def ref_state.props.health(props: H.Props) -> Nat:
  H.props.health(props)

def ref_state.props.set_health(props: H.Props, health: Nat) -> H.Props:
  H.props.set_health(props, health)

def ref_state.props.set_turn(props: H.Props, turn: Bool) -> H.Props:
  H.props.set_turn(props, turn)

def ref_state.props.grab(props: H.Props) -> H.Props:
  H.props.grab(props)

def ref_state.props.award(props: H.Props, prize: U32) -> H.Props:
  H.props.award(props, prize)

def ref_state.host.table(host: H.Host) -> D.Table:
  H.host.table(host)

def ref_state.host.plan(host: H.Host) -> D.Plan:
  H.host.plan(host)

def ref_state.rules.found(found: Maybe<&2, D.RoundRules>) -> D.RoundRules:
  H.rules.found(found)

def ref_state.host.rules(+host: H.Host) -> D.RoundRules:
  H.host.rules(host)

def ref_state.rules.health(rules: D.RoundRules) -> D.HealthRule:
  H.rules.health(rules)

def ref_state.rules.items(rules: D.RoundRules) -> D.ItemRules:
  H.rules.items(rules)

def ref_state.rules.load(rules: D.RoundRules, index: Nat) -> D.LoadRule:
  H.rules.load(rules, index)

def ref_state.host.load_rule(+host: H.Host) -> D.LoadRule:
  H.host.load_rule(host)

def ref_state.host.props.found(found: Maybe<&2, H.Props>) -> H.Props:
  H.host.props.found(found)

def ref_state.host.props(host: H.Host, seat: D.Seat) -> H.Props:
  H.host.props(host, seat)

def ref_state.host.set_props(+host: H.Host, seat: D.Seat, props: H.Props) -> H.Host:
  H.host.set_props(host, seat, props)

def ref_state.batches(xs: List<&2, D.Load>, +index: Nat) -> List<&2, H.Batch>:
  H.batches(xs, index)

def ref_state.MakeSequenceCopies() -> H.Decks:
  H.MakeSequenceCopies()

def ref_state.GetSelectedSequenceCopy(decks: H.Decks, table: D.Table) -> List<&2, H.Batch>:
  H.GetSelectedSequenceCopy(decks, table)

def ref_state.decks.set(decks: H.Decks, table: D.Table, deck: List<&2, H.Batch>) -> H.Decks:
  H.decks.set(decks, table, deck)

def ref_state.host.deck(+host: H.Host) -> List<&2, H.Batch>:
  H.host.deck(host)

def ref_state.host.set_deck(+host: H.Host, deck: List<&2, H.Batch>) -> H.Host:
  H.host.set_deck(host, deck)

def ref_state.config.table(config: D.Config) -> D.Table:
  H.config.table(config)

def ref_state.host.initial(+config: D.Config) -> H.Host:
  H.host.initial(config)

def ref_state.props.unjam(props: H.Props) -> H.Props:
  H.props.unjam(props)

def ref_state.props.clear_slots(props: H.Props) -> H.Props:
  H.props.clear_slots(props)

def ref_state.host.grabs(host: H.Host) -> D.Ring<&2, H.GrabProgress>:
  H.host.grabs(host)

def ref_state.host.set_grabs(host: H.Host, grabs: D.Ring<&2, H.GrabProgress>) -> H.Host:
  H.host.set_grabs(host, grabs)

def ref_state.progress.found(found: Maybe<&2, H.GrabProgress>) -> H.GrabProgress:
  H.progress.found(found)

def ref_state.host.progress(host: H.Host, seat: D.Seat) -> H.GrabProgress:
  H.host.progress(host, seat)

def ref_state.host.set_progress(+host: H.Host, seat: D.Seat, progress: H.GrabProgress) -> H.Host:
  H.host.set_progress(host, seat, progress)

def ref_state.props.set_slots(props: H.Props, slots: D.Slots) -> H.Props:
  H.props.set_slots(props, slots)

def ref_state.props.set_holding(props: H.Props, holding: Maybe<&2, D.Item>) -> H.Props:
  H.props.set_holding(props, holding)

def ref_state.props.end_grab(props: H.Props) -> H.Props:
  H.props.end_grab(props)

def ref_state.props.jam(props: H.Props) -> H.Props:
  H.props.jam(props)

# END GENERATED REF API

