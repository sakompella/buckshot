import Base
import ./domain.bend as D
import ./ref/main.bend as R
import ./ref/state.bend as H
import ./ref/rules.bend as G
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./sm/rules.bend as Q
import ./sm/items.bend as I
import ./primitive.bend as P
import ./ref/items.bend as RI

def CoreSeat() -> Data:
  S.Seat


def players(+seats: D.Ring<&2, CoreSeat>) -> S.Players:
  seats

# A free seat: unjammed (only an item jams), inventory empty.
def seat.free(+seat: CoreSeat) -> CoreSeat:
  S.Seat{S.seat.health(seat), S.Free{}, S.seat.cash(seat), D.slots.empty()}

# The jam_skip_once law's seat: its jam kept, inventory empty.
def seat.jams(+seat: CoreSeat) -> CoreSeat:
  S.Seat{S.seat.health(seat), S.seat.jam(seat), S.seat.cash(seat), D.slots.empty()}

# The seats as free seats, whatever they hold.
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

# The seats' health and jams, read through the free-seat and jam-law
# views so they stay definitionally equal to those views' fields.
def seats.health(+seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, Nat>:
  S.players.health(players.free(seats))

def seats.jam(+seats: D.Ring<&2, CoreSeat>) -> D.Ring<&2, S.Jam>:
  S.players.jam(players.jams(seats))

# The reference's (is_jammed, jammer_checked) pair of a jam. Free reads as
# (False, False); the reference clears the bit when a jam lifts (ADR-0018).
def jam.checked(jam: S.Jam) -> Bool:
  match jam:
    case S.JammedSkipped{}:
      True{}
    case _:
      False{}

# Host props of a free seat: unjammed, empty slots, not grabbing.
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

# The Host of free seats whose turn holder is holder.
def host.held(world: S.World, +seats: D.Ring<&2, CoreSeat>, holder: Maybe<&2, D.Seat>) -> H.Host:
  host.at(world, core(players.free(seats)), grabs(seats), holder)

# The Host of free seats between requests or at a phase no seat acts in.
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

def Seats() -> Data:
  D.Ring<&2, CoreSeat>

def Notes() -> Data:
  List<&2, D.Note>

def RefStep() -> Data:
  D.Stepped<&2, R.RefState>

def Ref() -> Data:
  R.RefState

def ref_answer(state: R.RefState, n: Nat) -> D.Stepped<&2, R.RefState>:
  R.answer(state, n)


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

def machine_step_state(result: D.Stepped<&2, S.State>) -> S.State:
  match result:
    case D.Stepped{state, _}:
      state

def ref_step_point(result: D.Stepped<&2, R.RefState>) -> D.Point:
  match result:
    case D.Stepped{state, _}:
      R.point(state)

def machine_point(state: S.State) -> D.Point:
  M.point(state)


def machine_request(state: S.State) -> D.Request:
  M.request(state)

def ref_request(state: R.RefState) -> D.Request:
  R.request(state)

def observation(state: S.State, seat: D.Seat) -> D.Obs:
  D.observe(M.point(state), seat)

def ref_observation(state: R.RefState, seat: D.Seat) -> D.Obs:
  D.observe(R.point(state), seat)


def ref_batch_length(deck: List<&2, S.Batch>) -> Nat:
  List.length(&2, H.Batch, batches(deck))

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


def verify(state: R.RefState, choice: D.Choice) -> Bool:
  R.VerifyPacket(state, choice)

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
def back.idle_options(moves: List<&2, D.Move>) -> List<&2, S.IdleOption>:
  match moves:
    case Nil{}:
      Nil{}
    case D.PickUp{} <> rest:
      S.TakeGun{} <> back.idle_options(rest)
    case D.UseItem{slot, item} <> rest:
      S.UseAt{slot, item} <> back.idle_options(rest)
    case _ <> rest:
      back.idle_options(rest)

def back.jams(moves: List<&2, D.Move>) -> List<&2, S.JamOption>:
  match moves:
    case Nil{}:
      Nil{}
    case D.JamTarget{seat} <> rest:
      S.JamAt{seat} <> back.jams(rest)
    case _ <> rest:
      back.jams(rest)

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

def ref.jam_moves(+h: H.Host, +seat: D.Seat) -> List<&2, D.Move>:
  RI.jam_moves(RI.jam_targets(D.ring.entries(H.Props, H.host.seats(h)), seat))

def ref.steal_moves(+h: H.Host, +seat: D.Seat) -> List<&2, D.Move>:
  RI.steal_moves(D.ring.entries(H.Props, H.host.seats(h)), h, seat)

def ref.grab_menus(+h: H.Host) -> D.Ring<&2, List<&2, D.Move>>:
  R.grab_menus(D.ring.entries(H.Props, H.host.seats(h)), h, D.ring.fill(List<&2, D.Move>, H.host.table(h), Nil{}))

# The seat whose has_turn is set: the holder of a blocked machine.
def back.holder(seats: List<&2, D.At<&2, H.Props>>) -> Maybe<&2, D.Seat>:
  match seats:
    case Nil{}:
      None{}
    case D.At{seat, H.Props{_, _, _, _, _, _, _, True{}}} <> _:
      Some{seat}
    case _ <> rest:
      back.holder(rest)

def back.terminal(stage: D.Stage, request: D.Request, +h: H.Host) -> S.Phase:
  match stage:
    case D.MatchOver{}:
      match request:
        case D.Finished{}:
          S.Ended{}
        case _:
          S.Blocked{None{}}
    case _:
      S.Blocked{back.holder(D.ring.entries(H.Props, H.host.seats(h)))}

def back.play(stage: D.Stage, mode: D.Mode, request: D.Request, +h: H.Host) -> S.Phase:
  match stage:
    case D.Playing{+seat, D.Idle{}}:
      match mode:
        case D.Idle{}:
          S.Idle{seat, D.NonEmpty{S.TakeGun{}, back.idle_options(ref.use_moves(h, seat))}}
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
          S.JamPick{seat, back.jams(ref.jam_moves(h, seat))}
        case _:
          S.Blocked{None{}}
    case D.Playing{+seat, D.Stealing{}}:
      match mode:
        case D.Stealing{}:
          S.StealPick{seat, back.steals(ref.steal_moves(h, seat))}
        case _:
          S.Blocked{None{}}
    case _:
      back.terminal(stage, request, h)

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

# The inverse of ref at every valid state (the law state_roundtrip).
def back(state: R.RefState) -> S.State:
  match state:
    case R.RefState{+h, frame, notes}:
      S.State{back.world(h), players(back.seats(H.host.seats(h))), back.phase(frame, h), notes, back.grabs(h)}

def RefHost() -> Data:
  H.Host

def RefBatches() -> Data:
  List<&2, H.Batch>

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

def ref_subtract(left: Nat, right: Nat) -> Nat:
  G.subtract(left, right)

def ref_shot_health(shell: D.Shell, hp: Nat, damage: D.Damage) -> Nat:
  G.shell.health(shell, hp, damage)

def ref_shot_passes(shell: D.Shell, same: Bool) -> Bool:
  Bool.not(Bool.and(same, Bool.not(G.shell.live(shell))))

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

def next(state: S.State, n: Nat) -> S.State:
  machine_step_state(M.answer(state, n))

def ref_run(fuel: Nat, state: R.RefState, tape: List<&2, Nat>) -> D.Ran<&2, R.RefState>:
  R.run(fuel, state, tape)

def RefRan() -> Data:
  D.Ran<&2, R.RefState>

def point_of_ref(state: S.State) -> D.Point:
  R.point(ref(state))

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


# The state M.round.reset hands to item distribution, as round.reset builds it.
def reset.state(+state: S.State) -> S.State:
  +world : S.World = S.state.world(state)
  players : S.Players = S.players.reset(S.state.players(state), S.world.round_health(world))
  +world : S.World = S.world.set_direction(S.world.set_checking_first_death(world, True{}), D.Clockwise{})
  S.state.emit(S.state.set_players(S.state.set_world(state, world), players), D.RoundBegan{S.world.round_index(world), S.world.round_health(world), S.world.first_turn(world)})

def ref_next_load(first: Bool, index: Nat) -> Nat:
  R.IncrementActiveSequenceIndex(first, index)

def machine_next_load(first: Bool, index: Nat) -> Nat:
  Q.load.next(first, index)

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

def machine_ran_state(ran: D.Ran<&2, S.State>) -> S.State:
  match ran:
    case D.Ran{state, _, _}:
      state

# ============================================================================
# Every-config interface: the request-point invariant Valid and the claims
# built on it.
# ============================================================================

# A Bool fact as a proposition.
def Holds(b: Bool) -> Data:
  {b == True{} : Bool}

def bounded(+s: S.State) -> Bool:
  Nat.is_lt(S.world.round_index(S.state.world(s)), D.plan.length(S.world.plan(S.state.world(s))))

# Item-config normal form: the stored menus of Idle, JamPick, StealPick and
# Grab equal their recomputation, since the reference checks ownership and the
# grab flags where the machine does not, and a menu at a seat outside the table
# leaves no trace in the reference's request; a swap at index 0 is Blocked.
# NeedItem and NeedPhone data need no tie (both models read the stored values).
def canonical_phase_items(+s: S.State, phase: S.Phase) -> S.Phase:
  match phase:
    case S.Idle{+seat, _}:
      S.Idle{seat, D.NonEmpty{S.TakeGun{}, I.uses(s, seat)}}
    case S.NeedSwap{load, shells, 0n}:
      S.Blocked{None{}}
    case S.Grab{_}:
      S.Grab{I.grab.needs(s)}
    case S.JamPick{+seat, _}:
      S.JamPick{seat, I.jam.for(s, seat)}
    case S.StealPick{+seat, _}:
      S.StealPick{seat, I.steal.for(s, seat)}
    case phase:
      phase

def normalize_items(+s: S.State) -> S.State:
  S.state.set_phase(s, canonical_phase_items(s, S.state.phase(s)))

# Whether a seat sits at the table (P.seated as a Bool).
def table.has(table: D.Table, seat: D.Seat) -> Bool:
  match table seat:
    case D.TwoSeats{} D.Seat1{}:
      True{}
    case D.TwoSeats{} D.Seat3{}:
      True{}
    case D.ThreeSeats{} D.Seat0{}:
      True{}
    case D.ThreeSeats{} D.Seat1{}:
      True{}
    case D.ThreeSeats{} D.Seat2{}:
      True{}
    case D.FourSeats{} _:
      True{}
    case _ _:
      False{}

def table.has.seated(+table: D.Table, +seat: D.Seat, +seated: P.seated(table, seat)) -> Holds(table.has(table, seat)):
  match table seat:
    case D.TwoSeats{} D.Seat1{}:
      {==}
    case D.TwoSeats{} D.Seat3{}:
      {==}
    case D.ThreeSeats{} D.Seat0{}:
      {==}
    case D.ThreeSeats{} D.Seat1{}:
      {==}
    case D.ThreeSeats{} D.Seat2{}:
      {==}
    case D.FourSeats{} D.Seat0{}:
      {==}
    case D.FourSeats{} D.Seat1{}:
      {==}
    case D.FourSeats{} D.Seat2{}:
      {==}
    case D.FourSeats{} D.Seat3{}:
      {==}
    case D.TwoSeats{} D.Seat0{}:
      match seated:
    case D.TwoSeats{} D.Seat2{}:
      match seated:
    case D.ThreeSeats{} D.Seat3{}:
      match seated:

# phase_ready, every Playing phase's seat holds world.turn, and a blocked
# holder and a phone draw's seat sit at the table: the reference checks the
# turn on a move, JamPick and NeedPhone resume to Idle, the reference keeps a
# blocked holder only in its seats' has_turn, and a failed phone draw blocks
# with its seat as the holder.
def items_ready(phase: S.Phase, +world: S.World) -> Bool:
  match phase:
    case S.JamPick{seat, _}:
      R.current.eq(S.world.turn(world), seat)
    case S.StealPick{seat, _}:
      R.current.eq(S.world.turn(world), seat)
    case S.NeedPhone{+seat, _, _}:
      Bool.and(R.current.eq(S.world.turn(world), seat), table.has(S.world.table(world), seat))
    case S.Blocked{Some{seat}}:
      table.has(S.world.table(world), seat)
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
def Valid(+s: S.State) -> Data:
  Sigma<&2, &2, {normalize_items(s) == s : S.State}, _ => Sigma<&2, &2, Shape(s), _ => Sigma<&2, &2, Holds(bounded(s)), _ => Holds(items_ready(S.state.phase(s), S.state.world(s)))>>>

def valid.normal(+s: S.State, valid: Valid(s)) -> {normalize_items(s) == s : S.State}:
  match valid:
    case Tuple{x, _}:
      x

def valid.shape(+s: S.State, valid: Valid(s)) -> Shape(s):
  match valid:
    case Tuple{_, Tuple{x, _}}:
      x

def valid.ready(+s: S.State, valid: Valid(s)) -> Holds(items_ready(S.state.phase(s), S.state.world(s))):
  match valid:
    case Tuple{_, Tuple{_, Tuple{_, x}}}:
      x

def Simulation(+state: S.State, +n: Nat) -> Data:
  Sigma<&2, &2, {ref_answer(ref(state), n) == stepped(M.answer(state, n)) : RefStep()}, _ => Sigma<&2, &2, {machine_point(next(state, n)) == ref_step_point(ref_answer(ref(state), n)) : D.Point}, _ => Valid(next(state, n))>>


def simulation.step(+state: S.State, +n: Nat, simulation: Simulation(state, n)) -> {ref_answer(ref(state), n) == stepped(M.answer(state, n)) : RefStep()}:
  match simulation:
    case Tuple{eq, _}:
      eq

def simulation.next(+state: S.State, +n: Nat, simulation: Simulation(state, n)) -> Valid(next(state, n)):
  match simulation:
    case Tuple{_, Tuple{_, valid}}:
      valid

def StartSimulation(+config: D.Config) -> Data:
  Sigma<&2, &2, {ref_start(config) == stepped(M.start(config)) : RefStep()}, _ => Sigma<&2, &2, {ref_step_point(ref_start(config)) == machine_point(machine_step_state(M.start(config))) : D.Point}, _ => Valid(machine_step_state(M.start(config)))>>

def RunHypothesis(+fuel: Nat) -> Type:
  @+state:S.State -> @+tape:List<&2, Nat> -> @+valid:Valid(state) -> {ref_run(fuel, ref(state), tape) == ran(M.run(fuel, state, tape)) : RefRan()}

def RunValidHypothesis(+fuel: Nat) -> Type:
  @+state:S.State -> @+tape:List<&2, Nat> -> @+valid:Valid(state) -> Valid(machine_ran_state(M.run(fuel, state, tape)))

# A game from a config: the start's notes, then the run on the tape.
def ref_game(fuel: Nat, +config: D.Config, tape: List<&2, Nat>) -> D.Ran<&2, R.RefState>:
  ref_merge(ref_start(config), ref_run(fuel, ref_next(ref_start(config)), tape))

def machine_game(fuel: Nat, +config: D.Config, tape: List<&2, Nat>) -> D.Ran<&2, S.State>:
  machine_merge(M.start(config), M.run(fuel, M.stepped.state(M.start(config)), tape))

# The reference closure of a frame from a machine state's host and notes.
def close(fuel: Nat, +s: S.State, f: R.Frame) -> R.RefState:
  R.settle(fuel, R.RefState{ref_host(s), f, S.state.notes(s)})

def Closure(+N: Nat, +s: S.State, +f: R.Frame, +out: S.State) -> Type:
  @+k:Nat -> {close(Nat.add(N, k), s, f) == ref(out) : R.RefState}
