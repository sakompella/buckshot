import Base
import ../domain.bend as D
import ./state.bend as S
import ./rules.bend as G
import ./snapshot.bend as T
import ./items.bend as I

type StartPhase is Data:
  BeginRound{}
  FirstChosen{seat: D.Seat}

type SequencePhase is Data:
  SelectBatch{}
  BatchChosen{index: Nat}
  Shuffle{load: D.Load, shells: List<&2, D.Shell>, steps: Nat}

type Shot is Data:
  Shot{shooter: D.Seat, target: D.Seat, shell: D.Shell, damage: D.Damage, after_length: Nat}

type TurnEnd is Data:
  TurnEnd{from: D.Seat, passing: Bool, empty: Bool, winner: Maybe<&2, D.Seat>}

type ItemUse is Data:
  ItemUse{seat: D.Seat, owner: D.Seat, slot: D.Slot, item: D.Item, ending: Bool, phone: Maybe<&2, D.Secret>}

type Continuation is Data:
  FirstSeatResult{}
  StartingHealthResult{}
  ItemAmountResult{next: Frame}
  SequenceBatchResult{}
  ShuffleSwapResult{load: D.Load, shells: List<&2, D.Shell>, i: Nat}
  PlayerMove{mode: D.Mode}
  GrabAnswer{}
  ItemChoiceResult{seat: D.Seat, pool: List<&2, D.Item>}
  PhoneIndexResult{packet: ItemUse}

type Frame is Data:
  StartRound{phase: StartPhase}
  ChooseFirstSeat{}
  DrawHealth{}
  DrawItemAmount{next: Frame}
  RoundSetup{}
  UnjamAll{}
  ShowRoundHealth{}
  ClearInventories{}
  BeginGrabbing{seats: List<&2, D.Seat>}
  StartLoad{}
  DrawShells{phase: SequencePhase}
  LoadGun{}
  AdvanceTurn{seat: D.Seat}
  GrantTurn{seat: D.Seat}
  PickUpGun{seat: D.Seat}
  CheckMove{choice: D.Choice}
  ResolveShot{shot: Shot}
  ShotOutcome{shot: Shot}
  ApplyDamage{shot: Shot}
  EjectShell{shot: Shot}
  RestoreBarrel{next: Frame}
  CheckTurnEnd{shot: Shot}
  EndTurn{packet: TurnEnd}
  FinishTurn{packet: TurnEnd}
  WinRound{seat: D.Seat}
  AfterWin{}
  ConcludeMatch{}
  EndMatch{}
  PickGrabItem{seat: D.Seat}
  GrabItem{seat: D.Seat, item: D.Item}
  PlacingLast{seat: D.Seat, slot: D.Slot}
  CheckGrabsDone{next: Frame}
  IneligibleGrabbers{seat: D.Seat, slot: D.Slot}
  EndIneligibleGrabs{seats: List<&2, D.Seat>, next: Frame}
  PlaceItem{seat: D.Seat, slot: D.Slot}
  ContinueGrabs{}
  ItemTurnCheck{seat: D.Seat, owner: D.Seat, slot: D.Slot, item: D.Item}
  PhoneReveal{packet: ItemUse}
  _RevealShell{packet: ItemUse, index: Nat}
  SlotUse{packet: ItemUse}
  RemoveItem{packet: ItemUse}
  ApplyItem{packet: ItemUse}
  SawBarrel{seat: D.Seat}
  BeginSteal{seat: D.Seat}
  ItemTarget{seat: D.Seat, target: D.Seat}
  ApplyJam{seat: D.Seat, target: D.Seat}
  EndItemUse{seat: D.Seat, ending: Bool}
  Await{request: D.Request, stage: D.Stage, continuation: Continuation}

type RefState is Data:
  RefState{host: S.Host, frame: Frame, notes: List<&2, D.Note>}

type TracePoint is Data:
  TracePoint{request: D.Request, state: T.Snapshot}

type TraceEnd is Data:
  EndFinished{}
  EndStuck{}
  EndTapeExhausted{}

type Trace is Data:
  Trace{points: List<&2, TracePoint>, end: TraceEnd}

def frame(+state: RefState, +next: Frame) -> RefState:
  match state:
    case RefState{host, _, notes}:
      RefState{host, next, notes}

def host(+state: RefState) -> S.Host:
  match state:
    case RefState{host, _, _}:
      host

def with_host(+state: RefState, +host: S.Host) -> RefState:
  match state:
    case RefState{_, frame, notes}:
      RefState{host, frame, notes}

def emit(+state: RefState, +event: D.GameEvent) -> RefState:
  match state:
    case RefState{host, frame, notes}:
      RefState{host, frame, List.append(&2, D.Note, notes, [D.Shown{event}])}

def grab_menu(props: S.Props, progress: S.GrabProgress, distributing: Bool) -> List<&2, D.Move>:
  match distributing:
    case True{}:
      I.grab_moves(props, progress)
    case False{}:
      I.grab_moves(props, S.GrabProgress{I.progress.count(progress), False{}})

def grab_menus(+entries: List<&2, D.At<&2, S.Props>>, +h: S.Host, +menus: D.Ring<&2, List<&2, D.Move>>) -> D.Ring<&2, List<&2, D.Move>>:
  match entries:
    case Nil{}:
      menus
    case D.At{+seat, props} <> rest:
      grab_menus(rest, h, D.ring.set(List<&2, D.Move>, menus, seat, grab_menu(props, S.host.progress(h, seat), S.host.distributing(h))))

def AdvanceIndex(+first: Bool, +old: Nat) -> Nat:
  match first:
    case True{}:
      0n
    case False{}:
      G.next_index(old)

def shot_moves(+seats: List<&2, D.Seat>) -> List<&2, D.Move>:
  match seats:
    case Nil{}:
      Nil{}
    case seat <> rest:
      D.Shoot{seat} <> shot_moves(rest)

def shot.target(+shot: Shot) -> D.Seat:
  match shot:
    case Shot{_, target, _, _, _}:
      target

def gun.tail(+gun: List<&2, D.Shell>) -> List<&2, D.Shell>:
  match gun:
    case Nil{}:
      Nil{}
    case shell <> rest:
      rest

def TurnEnd.reload(+packet: TurnEnd) -> Bool:
  match packet:
    case TurnEnd{_, _, empty, None{}}:
      empty
    case _:
      False{}

def FinishTurn.recipient(+passing: Bool, +from: D.Seat, +next: D.Seat) -> D.Seat:
  match passing:
    case True{}:
      next
    case False{}:
      from

def request(+state: RefState) -> D.Request:
  match state:
    case RefState{_, Await{request, _, _}, _}:
      request
    case _:
      D.Stuck{}

def stage(+state: RefState) -> D.Stage:
  match state:
    case RefState{_, Await{_, stage, _}, _}:
      stage
    case _:
      D.Setup{}

def props.briefcase(+grab: Bool, +holding: Maybe<&2, D.Item>) -> D.Briefcase:
  match grab holding:
    case True{} Some{item}:
      D.Holding{item}
    case True{} None{}:
      D.Grabbing{}
    case False{} _:
      D.NotGrabbing{}

def stepped(+state: RefState) -> D.Stepped<&2, RefState>:
  match state:
    case RefState{host, frame, +notes}:
      D.Stepped{RefState{host, frame, notes}, notes}

def stepped.state(+stepped: D.Stepped<&2, RefState>) -> RefState:
  match stepped:
    case D.Stepped{state, _}:
      state

def run.merge(+stepped: D.Stepped<&2, RefState>, +ran: D.Ran<&2, RefState>) -> D.Ran<&2, RefState>:
  match stepped ran:
    case D.Stepped{_, first} D.Ran{state, rest, tape}:
      D.Ran{state, List.append(&2, D.Note, first, rest), tape}

def trace.prepend(+point: TracePoint, +trace: Trace) -> Trace:
  match trace:
    case Trace{points, end}:
      Trace{point <> points, end}

def props.has_turn(+props: S.Props) -> Bool:
  match props:
    case S.Props{_, _, _, _, _, _, _, turn}:
      turn

def current.eq(+turn: Maybe<&2, D.Seat>, +seat: D.Seat) -> Bool:
  match turn:
    case Some{current}:
      D.seat.eq(current, seat)
    case None{}:
      False{}

def MoveAllowed.mode(+mode: D.Mode, +move: D.Move) -> Bool:
  match mode move:
    case D.Aiming{} D.PickUp{}:
      False{}
    case _ D.PickUp{}:
      True{}
    case D.Aiming{} D.Shoot{target}:
      True{}
    case _ D.UseItem{slot, item}:
      True{}
    case D.Stealing{} D.Steal{owner, slot, item}:
      True{}
    case D.Jamming{} D.JamTarget{target}:
      True{}
    case _ _:
      False{}

def DrawItemAmount.stage(+next: Frame) -> D.Stage:
  match next:
    case RoundSetup{}:
      D.Setup{}
    case _:
      D.Distributing{}

def stuck(+state: RefState) -> RefState:
  frame(state, Await{D.Stuck{}, D.Setup{}, PlayerMove{D.Idle{}}})

def await_draw(+state: RefState, +label: D.Label, +range: D.Range, +stage: D.Stage, +continuation: Continuation) -> RefState:
  frame(state, Await{D.Draw{label, range}, stage, continuation})

def idle(+state: RefState, +seat: D.Seat, +mode: D.Mode, +moves: List<&2, D.Move>) -> RefState:
  frame(state, Await{D.request.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, S.host.table(host(state)), Nil{}), seat, moves)), D.Playing{seat, mode}, PlayerMove{mode}})

def StartRound(+state: RefState, +phase: StartPhase) -> RefState:
  match phase:
    case BeginRound{}:
      frame(state, ChooseFirstSeat{})
    case FirstChosen{seat}:
      +h : S.Host = host(state)
      +h : S.Host = S.host.set_round_index(h, G.next_round(S.host.before_round(h), S.host.round_index(h)))
      +h : S.Host = S.host.set_before_round(h, False{})
      +h : S.Host = S.host.set_first_turn(h, seat)
      +h : S.Host = S.host.set_first_sequence(h, True{})
      frame(with_host(state, h), DrawHealth{})

# Install the packet's first-death checking and CW writes before nested
# unjam/health/clear calls. Cosmetic revival and indicators are omitted.
def RoundSetup(+state: RefState) -> RefState:
  +h : S.Host = S.host.set_checking_first_death(host(state), True{})
  +h : S.Host = S.host.set_direction(h, D.Clockwise{})
  frame(with_host(state, h), UnjamAll{})

def BeginGrabbing(+state: RefState, +seats: List<&2, D.Seat>) -> RefState:
  match seats:
    case Nil{}:
      frame(state, StartLoad{})
    case +seat <> +rest:
      +h : S.Host = S.host.set_distributing(I.begin_grab(seat <> rest, host(state)), True{})
      state : RefState = emit(with_host(state, h), D.GrabbingBegan{seat <> rest})
      frame(state, Await{D.request.choose(grab_menus(D.ring.entries(S.Props, S.host.seats(h)), h, D.ring.fill(List<&2, D.Move>, S.host.table(h), Nil{}))), D.Distributing{}, GrabAnswer{}})

def StartLoad(+state: RefState) -> RefState:
  +h : S.Host = host(state)
  +h : S.Host = S.host.set_load_index(h, AdvanceIndex(S.host.first_sequence(h), S.host.load_index(h)))
  +h : S.Host = S.host.set_first_sequence(h, False{})
  frame(with_host(state, h), DrawShells{SelectBatch{}})

def LoadGun(+state: RefState) -> RefState:
  frame(emit(state, D.Loaded{S.host.shown(host(state))}), AdvanceTurn{S.host.first_turn(host(state))})

def AdvanceTurn.props(+state: RefState, +seat: D.Seat, +props: S.Props) -> RefState:
  match props:
    case S.Props{hp, True{}, False{}, cash, slots, grab, holding, turn}:
      +h : S.Host = S.host.set_props(host(state), seat, S.Props{hp, True{}, True{}, cash, slots, grab, holding, turn})
      frame(emit(with_host(state, h), D.TurnSkipped{seat}), AdvanceTurn{G.NextTurn(h, seat)})
    case S.Props{hp, True{}, True{}, cash, slots, grab, holding, turn}:
      +h : S.Host = S.host.set_props(host(state), seat, S.Props{hp, False{}, True{}, cash, slots, grab, holding, turn})
      frame(emit(with_host(state, h), D.JamLifted{seat}), GrantTurn{seat})
    case _:
      frame(state, GrantTurn{seat})

def ResolveShot.grow(+state: RefState, +shot: Shot, +self_live: Bool) -> RefState:
  match self_live:
    case True{}:
      frame(state, RestoreBarrel{ShotOutcome{shot}})
    case False{}:
      frame(state, ShotOutcome{shot})

def ShotOutcome(+state: RefState, +shot: Shot) -> RefState:
  match shot:
    case Shot{shooter, +target, +shell, damage, length}:
      +h : S.Host = host(state)
      +old : Nat = S.props.health(S.host.props(h, target))
      +hp : Nat = G.shell.health(shell, old, damage)
      +h : S.Host = S.host.set_props(h, target, S.props.set_health(S.host.props(h, target), hp))
      state : RefState = emit(with_host(state, h), D.Fired{shooter, target, shell, damage, G.subtract(old, hp), hp})
      frame(state, ApplyDamage{shot})

def ApplyDamage.first(+state: RefState, +seat: D.Seat, +checking: Bool) -> RefState:
  match checking:
    case True{}:
      +h : S.Host = S.host.set_first_death(host(state), Some{seat})
      with_host(state, S.host.set_checking_first_death(h, False{}))
    case False{}:
      state

def RestoreBarrel(+state: RefState, +next: Frame) -> RefState:
  frame(with_host(state, S.host.set_sawed(host(state), False{})), next)

def CheckTurnEnd(+state: RefState, +shot: Shot) -> RefState:
  match shot:
    case Shot{+shooter, target, shell, damage, +length}:
      frame(state, EndTurn{TurnEnd{shooter, Bool.not(Bool.and(D.seat.eq(shooter, target), Bool.not(G.shell.live(shell)))), Nat.is_eq(length, 0n), G.RoundWinner(host(state))}})

def EndTurn.live(+state: RefState, +packet: TurnEnd, +live: Bool) -> RefState:
  match live:
    case True{}:
      frame(state, DrawItemAmount{FinishTurn{packet}})
    case False{}:
      frame(state, FinishTurn{packet})

def FinishTurn.pass(+state: RefState, +empty: Bool, +recipient: D.Seat) -> RefState:
  match empty:
    case True{}:
      +h : S.Host = S.host.set_first_turn(host(state), recipient)
      frame(with_host(state, h), BeginGrabbing{G.GrabSeats(h, False{}, S.host.item_amount(h))})
    case False{}:
      frame(with_host(state, S.host.set_first_turn(host(state), recipient)), AdvanceTurn{recipient})

def WinRound(+state: RefState, +seat: D.Seat) -> RefState:
  +prize : U32 = D.prize(S.host.round_index(host(state)))
  +h : S.Host = S.host.set_props(host(state), seat, S.props.award(S.host.props(host(state), seat), prize))
  frame(emit(with_host(state, h), D.RoundWon{seat, prize}), AfterWin{})

def AfterWin.final(+state: RefState, +final: Bool) -> RefState:
  match final:
    case True{}:
      frame(state, ConcludeMatch{})
    case False{}:
      frame(state, StartRound{BeginRound{}})

def ConcludeMatch(+state: RefState) -> RefState:
  frame(state, EndMatch{})

def EndMatch(+state: RefState) -> RefState:
  frame(emit(state, D.MatchConcluded{}), Await{D.Finished{}, D.MatchOver{}, PlayerMove{D.Idle{}}})

def props.view(+props: S.Props) -> D.SeatView:
  match props:
    case S.Props{hp, jam, _, cash, slots, grab, holding, _}:
      D.SeatView{D.counter.of(jam, hp), slots, cash, props.briefcase(grab, holding)}

# Audit API. Yield the trace-schema state as Bend data, including hidden
# chamber order and deck identities. This is not a player observation.
def snapshot(+state: RefState) -> T.Snapshot:
  T.snapshot(host(state))

# D32 host acceptance is broader than D37 menus. Continuation modes stand
# for holding/viewing/stealing flags under the no-overlap contract.
def MoveAllowed.grab(props: S.Props, move: D.Move) -> Bool:
  match props move:
    case S.Props{_, _, _, _, _, True{}, None{}, _} D.Grab{}:
      True{}
    case S.Props{_, _, _, _, _, True{}, Some{item}, _} D.Place{slot}:
      True{}
    case _ _:
      False{}

def MoveAllowed.ownership(host: S.Host, seat: D.Seat, move: D.Move) -> Bool:
  match move:
    case D.UseItem{slot, item}:
      G.alive(G.item.count(G.slots.list(I.props.slots(S.host.props(host, seat))), item))
    case D.Steal{owner, slot, item}:
      G.alive(G.item.count(G.slots.list(I.props.slots(S.host.props(host, owner))), item))
    case _:
      True{}

def MoveAllowed(+state: RefState, +choice: D.Choice) -> Bool:
  match state choice:
    case RefState{+h, Await{request, stage, GrabAnswer{}}, notes} D.Choice{seat, index, move}:
      MoveAllowed.grab(S.host.props(h, seat), move)
    case RefState{+h, Await{request, D.Playing{viewing, mode}, PlayerMove{D.Jamming{}}}, notes} D.Choice{+seat, index, D.JamTarget{target}}:
      Bool.and(D.seat.eq(viewing, seat), props.has_turn(S.host.props(h, seat)))
    case RefState{+h, Await{request, stage, PlayerMove{+mode}}, notes} D.Choice{+seat, index, +move}:
      Bool.and(current.eq(S.host.turn(h), seat), Bool.and(props.has_turn(S.host.props(h, seat)), Bool.and(MoveAllowed.mode(mode, move), MoveAllowed.ownership(h, seat, move))))
    case _ _:
      False{}

def EjectShell.self(+state: RefState, +shot: Shot, +self_live: Bool) -> RefState:
  match self_live:
    case True{}:
      frame(state, CheckTurnEnd{shot})
    case False{}:
      frame(state, RestoreBarrel{CheckTurnEnd{shot}})

def round_write(+state: RefState, write: G.RoundSeatWrite, next: Frame) -> RefState:
  +h : S.Host = host(state)
  +h : S.Host = S.host.set_seats(h, G.round_seats(D.ring.entries(S.Props, S.host.seats(h)), write, S.host.seats(h)))
  frame(with_host(state, h), next)

def ChooseFirstSeat.override(+state: RefState, +override: Maybe<&2, D.Seat>) -> RefState:
  match override:
    case Some{seat}:
      frame(state, StartRound{FirstChosen{seat}})
    case None{}:
      await_draw(state, D.FirstSeat{}, D.Range{0n, G.subtract(D.table.count(S.host.table(host(state))), 2n)}, D.Setup{}, FirstSeatResult{})

def DrawHealth.rule(+state: RefState, +rule: D.HealthRule) -> RefState:
  match rule:
    case D.RandomHealth{}:
      await_draw(state, D.StartingHealth{}, D.table.health_range(S.host.table(host(state))), D.Setup{}, StartingHealthResult{})
    case D.FixedHealth{health}:
      frame(with_host(state, S.host.set_round_health(host(state), D.pos.nat(health))), DrawItemAmount{RoundSetup{}})

def DrawItemAmount.rule(+state: RefState, +next: Frame, +rule: D.AmountRule) -> RefState:
  match rule:
    case D.RandomAmount{}:
      await_draw(state, D.ItemAmount{}, D.table.amount_range(S.host.table(host(state))), DrawItemAmount.stage(next), ItemAmountResult{next})
    case D.FixedAmount{amount}:
      frame(with_host(state, S.host.set_item_amount(host(state), amount)), next)

def DrawShells.request(+state: RefState, +deck: List<&2, S.Batch>) -> RefState:
  match deck:
    case Nil{}:
      stuck(state)
    case batch <> Nil{}:
      frame(state, DrawShells{BatchChosen{0n}})
    case batch <> next <> rest:
      await_draw(state, D.SequenceBatch{}, D.Range{0n, List.length(&2, S.Batch, rest)}, D.Loading{}, SequenceBatchResult{})

def DrawShells.batch(+state: RefState, +index: Nat, +selected: Maybe<&2, S.Batch>) -> RefState:
  match selected:
    case None{}:
      stuck(state)
    case Some{S.Batch{id, sampled}}:
      +h : S.Host = host(state)
      +load : D.Load = G.load.custom(S.host.load_rule(h), sampled)
      +shells : List<&2, D.Shell> = G.load.shells(load)
      +h : S.Host = S.host.set_deck(h, G.remove(S.Batch, S.host.deck(h), index))
      frame(with_host(state, h), DrawShells{Shuffle{load, shells, G.subtract(List.length(&2, D.Shell, shells), 1n)}})

def AdvanceTurn(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = S.host.set_turn(host(state), Some{seat})
  AdvanceTurn.props(with_host(state, h), seat, S.host.props(h, seat))

def idle_items(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = host(state)
  idle(state, seat, D.Idle{}, D.PickUp{} <> I.use_moves(I.slots.all(), h, seat))

def GrantTurn(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = S.host.set_props(host(state), seat, S.props.set_turn(S.host.props(host(state), seat), True{}))
  idle_items(emit(with_host(state, h), D.TurnGiven{seat}), seat)

def PickUpGun(+state: RefState, +seat: D.Seat) -> RefState:
  idle(emit(state, D.PickedUp{seat}), seat, D.Aiming{}, shot_moves(G.living(D.ring.entries(S.Props, S.host.seats(host(state))))))

def CheckMove.shell(+state: RefState, +shooter: D.Seat, +target: D.Seat, +gun: List<&2, D.Shell>) -> RefState:
  match gun:
    case Nil{}:
      stuck(state)
    case +shell <> rest:
      +h : S.Host = host(state)
      +shot : Shot = Shot{shooter, target, shell, G.damage(S.host.sawed(h)), List.length(&2, D.Shell, rest)}
      frame(state, ResolveShot{shot})

def ApplyDamage.health(+state: RefState, +shot: Shot, +hp: Nat) -> RefState:
  match shot hp:
    case Shot{shooter, +target, D.Live{}, damage, length} 0n:
      state : RefState = ApplyDamage.first(state, target, S.host.checking_first_death(host(state)))
      frame(emit(state, D.Died{target}), EjectShell{Shot{shooter, target, D.Live{}, damage, length}})
    case shot _:
      frame(state, EjectShell{shot})

def EndTurn.amount(+state: RefState, +packet: TurnEnd, +rule: D.AmountRule) -> RefState:
  match rule:
    case D.FixedAmount{amount}:
      frame(with_host(state, S.host.set_item_amount(host(state), amount)), FinishTurn{packet})
    case D.RandomAmount{}:
      +h : S.Host = host(state)
      EndTurn.live(state, packet, Bool.or(S.host.distributing(h), Bool.and(TurnEnd.reload(packet), G.nonempty(D.Seat, G.GrabSeats(h, False{}, 1n)))))

def FinishTurn(+state: RefState, +packet: TurnEnd) -> RefState:
  match packet:
    case TurnEnd{from, passing, empty, Some{winner}}:
      frame(state, WinRound{winner})
    case TurnEnd{+from, passing, empty, None{}}:
      +h : S.Host = host(state)
      FinishTurn.pass(state, empty, FinishTurn.recipient(passing, from, G.NextTurn(h, from)))

def AfterWin(+state: RefState) -> RefState:
  AfterWin.final(state, Nat.is_eq(1n+S.host.round_index(host(state)), D.plan.length(S.host.plan(host(state)))))

def seat_views(+entries: List<&2, D.At<&2, S.Props>>, +views: D.Ring<&2, D.SeatView>) -> D.Ring<&2, D.SeatView>:
  match entries:
    case Nil{}:
      views
    case D.At{seat, props} <> rest:
      seat_views(rest, D.ring.set(D.SeatView, views, seat, props.view(props)))

def tell(+state: RefState, +seat: D.Seat, +secret: D.Secret) -> RefState:
  match state:
    case RefState{host, frame, notes}:
      RefState{host, frame, List.append(&2, D.Note, notes, [D.Told{seat, secret}])}

def PickGrabItem.selected(+state: RefState, +seat: D.Seat, found: Maybe<&2, D.Item>) -> RefState:
  match found:
    case Some{item}:
      frame(state, GrabItem{seat, item})
    case None{}:
      frame(tell(state, seat, D.EmptyBriefcase{}), ContinueGrabs{})

def answer.draw(+state: RefState, +value: Nat, +continuation: Continuation) -> RefState:
  match continuation:
    case FirstSeatResult{}:
      frame(state, StartRound{FirstChosen{G.seat.default(G.nth(D.Seat, D.table.seats(S.host.table(host(state))), value))}})
    case StartingHealthResult{}:
      frame(with_host(state, S.host.set_round_health(host(state), value)), DrawItemAmount{RoundSetup{}})
    case ItemAmountResult{next}:
      frame(with_host(state, S.host.set_item_amount(host(state), value)), next)
    case ItemChoiceResult{seat, pool}:
      PickGrabItem.selected(state, seat, G.nth(D.Item, pool, value))
    case PhoneIndexResult{packet}:
      frame(state, _RevealShell{packet, value})
    case SequenceBatchResult{}:
      frame(state, DrawShells{BatchChosen{value}})
    case ShuffleSwapResult{load, shells, +i}:
      frame(state, DrawShells{Shuffle{load, G.swap(shells, i, value), G.subtract(i, 1n)}})
    case _:
      stuck(state)

def ResolveShot(+state: RefState, +shot: Shot) -> RefState:
  match shot:
    case Shot{+shooter, target, shell, damage, length}:
      +h : S.Host = host(state)
      +h : S.Host = S.host.set_props(h, shooter, S.props.set_turn(S.host.props(h, shooter), False{}))
      ResolveShot.grow(with_host(state, h), shot, Bool.and(D.seat.eq(shooter, target), G.shell.live(shell)))

def answer.move.accepted(+state: RefState, +choice: D.Choice, +accepted: Bool) -> RefState:
  match accepted:
    case True{}:
      frame(state, CheckMove{choice})
    case False{}:
      stuck(state)

# Self-live uses D51's FP representative. Grow already preceded damage. TP
# moves that write after outcome, with no normal request between the writes.
def EjectShell.grow(+state: RefState, +shot: Shot) -> RefState:
  match shot:
    case Shot{+shooter, target, D.Live{}, damage, length}:
      EjectShell.self(state, Shot{shooter, target, D.Live{}, damage, length}, D.seat.eq(shooter, target))
    case shot:
      frame(state, RestoreBarrel{CheckTurnEnd{shot}})

def UnjamAll(state: RefState) -> RefState:
  round_write(state, G.DisableJam{}, ShowRoundHealth{})

def ShowRoundHealth(+state: RefState) -> RefState:
  +h : S.Host = host(state)
  state : RefState = round_write(state, G.RestoreHealth{S.host.round_health(h)}, ClearInventories{})
  emit(state, D.RoundBegan{S.host.round_index(h), S.host.round_health(h), S.host.first_turn(h)})

# M3 selects only after slot/count clearing. Under normal play, grant
# counts equal placed plus held inventory; an empty clear cannot erase any.
def ClearInventories(+state: RefState) -> RefState:
  +cleared : RefState = round_write(state, G.ClearSlots{}, StartLoad{})
  +h : S.Host = host(cleared)
  frame(cleared, BeginGrabbing{G.GrabSeats(h, True{}, S.host.item_amount(h))})

def EjectShell(+state: RefState, +shot: Shot) -> RefState:
  +h : S.Host = S.host.set_gun(host(state), gun.tail(S.host.gun(host(state))))
  EjectShell.grow(with_host(state, h), shot)

def answer.move(+state: RefState, +choice: D.Choice) -> RefState:
  answer.move.accepted(state, choice, MoveAllowed(state, choice))

def ChooseFirstSeat(+state: RefState) -> RefState:
  ChooseFirstSeat.override(state, S.host.first_death(host(state)))

def DrawHealth(+state: RefState) -> RefState:
  DrawHealth.rule(state, S.rules.health(S.host.rules(host(state))))

def DrawItemAmount(+state: RefState, +next: Frame) -> RefState:
  DrawItemAmount.rule(state, next, G.load.amount(S.host.load_rule(host(state))))

def DrawShells.refill(+state: RefState, +deck: List<&2, S.Batch>) -> RefState:
  match deck:
    case Nil{}:
      +h : S.Host = S.host.set_decks(host(state), S.FreshDecks())
      DrawShells.request(with_host(state, h), S.host.deck(h))
    case deck:
      DrawShells.request(state, deck)

def ApplyDamage(+state: RefState, +shot: Shot) -> RefState:
  ApplyDamage.health(state, shot, S.props.health(S.host.props(host(state), shot.target(shot))))

def EndTurn(+state: RefState, +packet: TurnEnd) -> RefState:
  EndTurn.amount(state, packet, G.load.amount(S.host.load_rule(host(state))))

def board(+state: RefState) -> D.Board:
  +h : S.Host = host(state)
  seats : D.Ring<&2, D.SeatView> = seat_views(D.ring.entries(S.Props, S.host.seats(h)), D.ring.fill(D.SeatView, S.host.table(h), props.view(S.props.initial())))
  D.Board{D.RoundView{S.host.round_index(h), D.plan.length(S.host.plan(h)), S.host.round_health(h)}, seats, D.GunView{S.host.shown(h), List.length(&2, D.Shell, S.host.gun(h)), S.host.sawed(h)}, S.host.direction(h), stage(state)}

def CheckMove.choice(+state: RefState, +choice: D.Choice) -> RefState:
  match choice:
    case D.Choice{seat, index, D.PickUp{}}:
      frame(state, PickUpGun{seat})
    case D.Choice{shooter, index, D.Shoot{target}}:
      CheckMove.shell(state, shooter, target, S.host.gun(host(state)))
    case D.Choice{seat, index, D.Grab{}}:
      frame(state, PickGrabItem{seat})
    case D.Choice{seat, index, D.Place{slot}}:
      frame(state, PlacingLast{seat, slot})
    case D.Choice{seat, index, D.UseItem{slot, item}}:
      frame(state, ItemTurnCheck{seat, seat, slot, item})
    case D.Choice{seat, index, D.Steal{owner, slot, item}}:
      frame(state, ItemTurnCheck{seat, owner, slot, item})
    case D.Choice{seat, index, D.JamTarget{target}}:
      frame(state, ItemTarget{seat, target})

def answer.resolved(+state: RefState, +continuation: Continuation, +resolved: D.Resolved) -> RefState:
  match continuation resolved:
    case continuation D.Drawn{value}:
      answer.draw(state, value, continuation)
    case PlayerMove{mode} D.Chose{choice}:
      answer.move(state, choice)
    case GrabAnswer{} D.Chose{choice}:
      answer.move(state, choice)
    case _ _:
      stuck(state)

def DrawShells(+state: RefState, +phase: SequencePhase) -> RefState:
  match phase:
    case SelectBatch{}:
      DrawShells.refill(state, S.host.deck(host(state)))
    case BatchChosen{+index}:
      DrawShells.batch(state, index, G.nth(S.Batch, S.host.deck(host(state)), index))
    case Shuffle{load, shells, 0n}:
      +h : S.Host = S.host.set_gun(host(state), shells)
      +h : S.Host = S.host.set_shown(h, load)
      frame(with_host(state, h), LoadGun{})
    case Shuffle{load, shells, 1n+i}:
      await_draw(state, D.ShuffleSwap{}, D.Range{0n, i}, D.Loading{}, ShuffleSwapResult{load, shells, 1n+i})

# Public API. Point excludes the private chamber order and resource deck.
def point(+state: RefState) -> D.Point:
  D.Point{request(state), board(state)}

def CheckMove(+state: RefState, +choice: D.Choice) -> RefState:
  CheckMove.choice(state, choice)

def ContinueGrabs.ready(+state: RefState, distributing: Bool, holders: Bool) -> RefState:
  match distributing holders:
    case False{} False{}:
      frame(state, StartLoad{})
    case _ _:
      +h : S.Host = host(state)
      frame(state, Await{D.request.choose(grab_menus(D.ring.entries(S.Props, S.host.seats(h)), h, D.ring.fill(List<&2, D.Move>, S.host.table(h), Nil{}))), D.Distributing{}, GrabAnswer{}})

def ContinueGrabs(+state: RefState) -> RefState:
  +h : S.Host = host(state)
  ContinueGrabs.ready(state, S.host.distributing(h), I.holders(D.ring.entries(S.Props, S.host.seats(h))))

def PickGrabItem.pool(+state: RefState, +seat: D.Seat, pool: List<&2, D.Item>) -> RefState:
  match pool:
    case Nil{}:
      PickGrabItem.selected(state, seat, None{})
    case item <> Nil{}:
      frame(state, GrabItem{seat, item})
    case item <> next <> +rest:
      await_draw(state, D.ItemChoice{}, D.Range{0n, List.length(&2, D.Item, rest)}, D.Distributing{}, ItemChoiceResult{seat, item <> next <> rest})

def PickGrabItem(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = host(state)
  +h : S.Host = S.host.set_progress(h, seat, S.GrabProgress{I.progress.count(S.host.progress(h, seat)), False{}})
  PickGrabItem.pool(with_host(state, h), seat, G.PickGrabItem.pool(D.item.order(), h, seat))

def GrabItem(+state: RefState, +seat: D.Seat, +item: D.Item) -> RefState:
  +h : S.Host = S.host.set_props(host(state), seat, S.props.set_holding(S.host.props(host(state), seat), Some{item}))
  +h : S.Host = S.host.set_progress(h, seat, S.GrabProgress{1n+I.progress.count(S.host.progress(h, seat)), False{}})
  frame(emit(with_host(state, h), D.Granted{seat, item}), ContinueGrabs{})

def PlacingLast.last(+state: RefState, +seat: D.Seat, +slot: D.Slot, last: Bool) -> RefState:
  match last:
    case True{}:
      +h : S.Host = S.host.set_props(host(state), seat, S.props.end_grab(S.host.props(host(state), seat)))
      frame(emit(with_host(state, h), D.GrabbingEnded{seat}), CheckGrabsDone{IneligibleGrabbers{seat, slot}})
    case False{}:
      frame(state, PlaceItem{seat, slot})

def PlacingLast(+state: RefState, +seat: D.Seat, slot: D.Slot) -> RefState:
  PlacingLast.last(state, seat, slot, I.PlacingLast(host(state), seat))

# The distribution flag is the completion latch. It changes at the first
# true source predicate, not when the deferred load starts.
def CheckGrabsDone.result(+state: RefState, next: Frame, complete: Bool) -> RefState:
  match complete:
    case True{}:
      frame(emit(with_host(state, S.host.set_distributing(host(state), False{})), D.DistributionDone{}), next)
    case False{}:
      frame(state, next)

def CheckGrabsDone(+state: RefState, next: Frame) -> RefState:
  +h : S.Host = host(state)
  CheckGrabsDone.result(state, next, Bool.and(S.host.distributing(h), I.CheckGrabsDone(h)))

def IneligibleGrabbers(+state: RefState, +seat: D.Seat, +slot: D.Slot) -> RefState:
  +h : S.Host = host(state)
  frame(state, EndIneligibleGrabs{I.IneligibleGrabbers(D.ring.entries(S.Props, S.host.seats(h)), h, seat), CheckGrabsDone{PlaceItem{seat, slot}}})

def EndIneligibleGrabs(+state: RefState, seats: List<&2, D.Seat>, next: Frame) -> RefState:
  match seats:
    case Nil{}:
      frame(state, next)
    case +seat <> rest:
      +h : S.Host = S.host.set_props(host(state), seat, S.props.end_grab(S.host.props(host(state), seat)))
      frame(emit(with_host(state, h), D.GrabbingEnded{seat}), EndIneligibleGrabs{rest, next})

def PlaceItem.held(+state: RefState, +seat: D.Seat, +slot: D.Slot, held: Maybe<&2, D.Item>) -> RefState:
  match held:
    case None{}:
      stuck(state)
    case Some{+item}:
      +h : S.Host = host(state)
      +props : S.Props = S.host.props(h, seat)
      +props : S.Props = S.props.set_slots(props, I.slots.set(I.props.slots(props), slot, Some{item}))
      +props : S.Props = S.props.set_holding(props, None{})
      +h : S.Host = S.host.set_props(h, seat, props)
      +h : S.Host = S.host.set_progress(h, seat, S.GrabProgress{I.progress.count(S.host.progress(h, seat)), I.props.grabbing(props)})
      frame(emit(with_host(state, h), D.Placed{seat, slot, item}), ContinueGrabs{})

def PlaceItem(+state: RefState, +seat: D.Seat, slot: D.Slot) -> RefState:
  PlaceItem.held(state, seat, slot, I.props.holding(S.host.props(host(state), seat)))

def ItemTurnCheck.phone(+state: RefState, packet: ItemUse, item: D.Item) -> RefState:
  match item:
    case D.Phone{}:
      frame(state, PhoneReveal{packet})
    case _:
      frame(state, SlotUse{packet})

def ItemTurnCheck(+state: RefState, +seat: D.Seat, owner: D.Seat, slot: D.Slot, +item: D.Item) -> RefState:
  +packet : ItemUse = ItemUse{seat, owner, slot, item, I.ItemTurnCheck(item, List.length(&2, D.Shell, S.host.gun(host(state)))), None{}}
  ItemTurnCheck.phone(state, packet, item)

def packet.phone(packet: ItemUse, phone: D.Secret) -> ItemUse:
  match packet:
    case ItemUse{seat, owner, slot, item, ending, _}:
      ItemUse{seat, owner, slot, item, ending, Some{phone}}

def packet.seat(packet: ItemUse) -> D.Seat:
  match packet:
    case ItemUse{seat, _, _, _, _, _}:
      seat
def PhoneReveal.length(+state: RefState, +packet: ItemUse, length: Nat) -> RefState:
  match length:
    case 0n:
      frame(state, SlotUse{packet.phone(packet, D.NoClue{})})
    case 1n:
      frame(state, SlotUse{packet.phone(packet, D.NoClue{})})
    case 2n:
      frame(state, SlotUse{packet.phone(packet, D.NoClue{})})
    case 3n:
      frame(state, _RevealShell{packet, 2n})
    case 4n+extra:
      await_draw(state, D.PhoneIndex{}, D.Range{2n, extra}, D.Playing{packet.seat(packet), D.Idle{}}, PhoneIndexResult{packet})

def PhoneReveal(+state: RefState, packet: ItemUse) -> RefState:
  PhoneReveal.length(state, packet, List.length(&2, D.Shell, S.host.gun(host(state))))

def _RevealShell.found(+state: RefState, packet: ItemUse, index: Nat, found: Maybe<&2, D.Shell>) -> RefState:
  match found:
    case None{}:
      stuck(state)
    case Some{shell}:
      frame(state, SlotUse{packet.phone(packet, D.Clue{index, shell})})

def _RevealShell(+state: RefState, packet: ItemUse, index: Nat) -> RefState:
  +verbal : Nat = D.clamp(1n+index, D.phone.cap())
  _RevealShell.found(state, packet, verbal, G.nth(D.Shell, S.host.gun(host(state)), G.subtract(verbal, 1n)))

def SlotUse(+state: RefState, +packet: ItemUse) -> RefState:
  match packet:
    case ItemUse{+seat, owner, slot, +item, ending, phone}:
      +h : S.Host = S.host.set_props(host(state), seat, S.props.set_turn(S.host.props(host(state), seat), Bool.or(D.item.eq(item, D.Jammer{}), D.item.eq(item, D.Adrenaline{}))))
      frame(with_host(state, h), RemoveItem{packet})

def RemoveItem(+state: RefState, +packet: ItemUse) -> RefState:
  match packet:
    case ItemUse{seat, +owner, +slot, item, ending, phone}:
      +h : S.Host = host(state)
      +h : S.Host = S.host.set_props(h, owner, S.props.set_slots(S.host.props(h, owner), I.slots.set(I.props.slots(S.host.props(h, owner)), slot, None{})))
      frame(emit(with_host(state, h), D.Used{seat, owner, slot, item}), ApplyItem{packet})

def ApplyItem.shell(+state: RefState, +seat: D.Seat, item: D.Item, ending: Bool, +shell: D.Shell, rest: List<&2, D.Shell>) -> RefState:
  match item:
    case D.Glass{}:
      frame(tell(state, seat, D.Glimpse{shell}), EndItemUse{seat, ending})
    case D.Beer{}:
      frame(emit(with_host(state, S.host.set_gun(host(state), rest)), D.Ejected{seat, shell}), EndItemUse{seat, ending})
    case D.Inverter{}:
      frame(emit(with_host(state, S.host.set_gun(host(state), I.inverted(shell) <> rest)), D.Inverted{seat}), EndItemUse{seat, ending})
    case _:
      stuck(state)

def ApplyItem.head(+state: RefState, +seat: D.Seat, +item: D.Item, ending: Bool, gun: List<&2, D.Shell>) -> RefState:
  match gun:
    case Nil{}:
      stuck(state)
    case +shell <> rest:
      ApplyItem.shell(state, seat, item, ending, shell, rest)

def ApplyItem.heal(+state: RefState, +seat: D.Seat, heal: Bool) -> RefState:
  match heal:
    case True{}:
      +h : S.Host = host(state)
      +hp : Nat = 1n+S.props.health(S.host.props(h, seat))
      +h : S.Host = S.host.set_props(h, seat, S.props.set_health(S.host.props(h, seat), hp))
      frame(emit(with_host(state, h), D.Healed{seat, hp}), EndItemUse{seat, False{}})
    case False{}:
      frame(state, EndItemUse{seat, False{}})

def ApplyItem.phone(+state: RefState, +seat: D.Seat, result: Maybe<&2, D.Secret>) -> RefState:
  match result:
    case None{}:
      stuck(state)
    case Some{secret}:
      frame(tell(state, seat, secret), EndItemUse{seat, False{}})

def ApplyItem(+state: RefState, packet: ItemUse) -> RefState:
  match packet:
    case ItemUse{+seat, owner, slot, D.Saw{}, ending, phone}:
      frame(state, SawBarrel{seat})
    case ItemUse{+seat, owner, slot, D.Jammer{}, ending, phone}:
      +h : S.Host = host(state)
      idle(state, seat, D.Jamming{}, I.jam_moves(I.jam_targets(D.ring.entries(S.Props, S.host.seats(h)), seat)))
    case ItemUse{+seat, owner, slot, D.Cigarettes{}, ending, phone}:
      +h : S.Host = host(state)
      ApplyItem.heal(state, seat, Nat.is_lt(S.props.health(S.host.props(h, seat)), S.host.round_health(h)))
    case ItemUse{seat, owner, slot, D.Phone{}, ending, phone}:
      ApplyItem.phone(state, seat, phone)
    case ItemUse{seat, owner, slot, D.Adrenaline{}, ending, phone}:
      frame(state, BeginSteal{seat})
    case ItemUse{+seat, owner, slot, D.Remote{}, ending, phone}:
      +direction : D.Direction = I.FlipDirection(S.host.direction(host(state)))
      frame(emit(with_host(state, S.host.set_direction(host(state), direction)), D.DirectionFlipped{direction}), EndItemUse{seat, False{}})
    case ItemUse{seat, owner, slot, item, ending, phone}:
      ApplyItem.head(state, seat, item, ending, S.host.gun(host(state)))

def SawBarrel(+state: RefState, seat: D.Seat) -> RefState:
  frame(with_host(state, S.host.set_sawed(host(state), True{})), EndItemUse{seat, False{}})

def BeginSteal(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = host(state)
  idle(state, seat, D.Stealing{}, I.steal_moves(D.ring.entries(S.Props, S.host.seats(h)), h, seat))

def ItemTarget(+state: RefState, +seat: D.Seat, target: D.Seat) -> RefState:
  +h : S.Host = S.host.set_props(host(state), seat, S.props.set_turn(S.host.props(host(state), seat), False{}))
  frame(with_host(state, h), ApplyJam{seat, target})

def ApplyJam(+state: RefState, +seat: D.Seat, +target: D.Seat) -> RefState:
  +h : S.Host = S.host.set_props(host(state), target, S.props.jam(S.host.props(host(state), target)))
  frame(emit(with_host(state, h), D.JamApplied{seat, target}), EndItemUse{seat, False{}})

def EndItemUse(+state: RefState, +seat: D.Seat, ending: Bool) -> RefState:
  match ending:
    case True{}:
      frame(state, EndTurn{TurnEnd{seat, True{}, Nat.is_eq(List.length(&2, D.Shell, S.host.gun(host(state))), 0n), None{}}})
    case False{}:
      +h : S.Host = S.host.set_props(host(state), seat, S.props.set_turn(S.host.props(host(state), seat), True{}))
      idle_items(with_host(state, h), seat)
def dispatch(+state: RefState) -> RefState:
  match state:
    case RefState{host, StartRound{phase}, notes}:
      StartRound(RefState{host, StartRound{phase}, notes}, phase)
    case RefState{host, ChooseFirstSeat{}, notes}:
      ChooseFirstSeat(state)
    case RefState{host, DrawHealth{}, notes}:
      DrawHealth(state)
    case RefState{host, DrawItemAmount{next}, notes}:
      DrawItemAmount(state, next)
    case RefState{host, RoundSetup{}, notes}:
      RoundSetup(state)
    case RefState{host, UnjamAll{}, notes}:
      UnjamAll(state)
    case RefState{host, ShowRoundHealth{}, notes}:
      ShowRoundHealth(state)
    case RefState{host, ClearInventories{}, notes}:
      ClearInventories(state)
    case RefState{host, BeginGrabbing{seats}, notes}:
      BeginGrabbing(state, seats)
    case RefState{host, StartLoad{}, notes}:
      StartLoad(state)
    case RefState{host, DrawShells{phase}, notes}:
      DrawShells(state, phase)
    case RefState{host, LoadGun{}, notes}:
      LoadGun(state)
    case RefState{host, AdvanceTurn{seat}, notes}:
      AdvanceTurn(state, seat)
    case RefState{host, GrantTurn{seat}, notes}:
      GrantTurn(state, seat)
    case RefState{host, PickUpGun{seat}, notes}:
      PickUpGun(state, seat)
    case RefState{host, CheckMove{choice}, notes}:
      CheckMove(state, choice)
    case RefState{host, ResolveShot{shot}, notes}:
      ResolveShot(state, shot)
    case RefState{host, ShotOutcome{shot}, notes}:
      ShotOutcome(state, shot)
    case RefState{host, ApplyDamage{shot}, notes}:
      ApplyDamage(state, shot)
    case RefState{host, EjectShell{shot}, notes}:
      EjectShell(state, shot)
    case RefState{host, RestoreBarrel{next}, notes}:
      RestoreBarrel(state, next)
    case RefState{host, CheckTurnEnd{shot}, notes}:
      CheckTurnEnd(state, shot)
    case RefState{host, EndTurn{packet}, notes}:
      EndTurn(state, packet)
    case RefState{host, FinishTurn{packet}, notes}:
      FinishTurn(state, packet)
    case RefState{host, WinRound{seat}, notes}:
      WinRound(state, seat)
    case RefState{host, AfterWin{}, notes}:
      AfterWin(state)
    case RefState{host, ConcludeMatch{}, notes}:
      ConcludeMatch(state)
    case RefState{host, EndMatch{}, notes}:
      EndMatch(state)
    case RefState{host, PickGrabItem{seat}, notes}:
      PickGrabItem(state, seat)
    case RefState{host, GrabItem{seat, item}, notes}:
      GrabItem(state, seat, item)
    case RefState{host, PlacingLast{seat, slot}, notes}:
      PlacingLast(state, seat, slot)
    case RefState{host, CheckGrabsDone{next}, notes}:
      CheckGrabsDone(state, next)
    case RefState{host, IneligibleGrabbers{seat, slot}, notes}:
      IneligibleGrabbers(state, seat, slot)
    case RefState{host, EndIneligibleGrabs{seats, next}, notes}:
      EndIneligibleGrabs(state, seats, next)
    case RefState{host, PlaceItem{seat, slot}, notes}:
      PlaceItem(state, seat, slot)
    case RefState{host, ContinueGrabs{}, notes}:
      ContinueGrabs(state)
    case RefState{host, ItemTurnCheck{seat, owner, slot, item}, notes}:
      ItemTurnCheck(state, seat, owner, slot, item)
    case RefState{host, PhoneReveal{packet}, notes}:
      PhoneReveal(state, packet)
    case RefState{host, _RevealShell{packet, index}, notes}:
      _RevealShell(state, packet, index)
    case RefState{host, SlotUse{packet}, notes}:
      SlotUse(state, packet)
    case RefState{host, RemoveItem{packet}, notes}:
      RemoveItem(state, packet)
    case RefState{host, ApplyItem{packet}, notes}:
      ApplyItem(state, packet)
    case RefState{host, SawBarrel{seat}, notes}:
      SawBarrel(state, seat)
    case RefState{host, BeginSteal{seat}, notes}:
      BeginSteal(state, seat)
    case RefState{host, ItemTarget{seat, target}, notes}:
      ItemTarget(state, seat, target)
    case RefState{host, ApplyJam{seat, target}, notes}:
      ApplyJam(state, seat, target)
    case RefState{host, EndItemUse{seat, ending}, notes}:
      EndItemUse(state, seat, ending)
    case RefState{host, Await{request, stage, continuation}, notes}:
      state

# Requests consume no silent fuel. 96 calls cover the core shot/next-round
# chain and four unchecked jams plus return to a checked jam. Exhaustion
# produces Stuck; every answered request starts a fresh closure bound.
def settle(+fuel: Nat, +state: RefState) -> RefState:
  match fuel state:
    case _ RefState{host, Await{request, stage, continuation}, notes}:
      RefState{host, Await{request, stage, continuation}, notes}
    case 0n state:
      stuck(state)
    case 1n+fuel state:
      settle(fuel, dispatch(state))

# Public API. Setup closes to the first request without reading the tape.
def start(+config: D.Config) -> D.Stepped<&2, RefState>:
  stepped(settle(96n, RefState{S.host.initial(config), StartRound{BeginRound{}}, Nil{}}))

def answer.await(+state: RefState, +n: Nat) -> RefState:
  match state:
    case RefState{host, Await{D.Finished{}, stage, continuation}, notes}:
      RefState{host, Await{D.Finished{}, stage, continuation}, Nil{}}
    case RefState{host, Await{D.Stuck{}, stage, continuation}, notes}:
      RefState{host, Await{D.Stuck{}, stage, continuation}, Nil{}}
    case RefState{host, Await{+request, stage, +continuation}, notes}:
      settle(96n, answer.resolved(RefState{host, Await{request, stage, continuation}, Nil{}}, continuation, D.resolve(request, n)))
    case _:
      stuck(state)

# Public API. Resolve one request through domain.resolve, then close silently.
# Finished and Stuck return the identical state with no notes.
def answer(+state: RefState, +n: Nat) -> D.Stepped<&2, RefState>:
  match state:
    case RefState{host, Await{D.Finished{}, stage, continuation}, notes}:
      D.Stepped{state, Nil{}}
    case RefState{host, Await{D.Stuck{}, stage, continuation}, notes}:
      D.Stepped{state, Nil{}}
    case _:
      stepped(answer.await(state, n))

# Public API. Fuel counts tape answers, not silent calls. Return the unread
# tape at Finished, Stuck, tape exhaustion or fuel zero, with ordered notes.
def run(+fuel: Nat, +state: RefState, +tape: List<&2, Nat>) -> D.Ran<&2, RefState>:
  match fuel state tape:
    case _ RefState{host, Await{D.Finished{}, stage, continuation}, notes} tape:
      D.Ran{RefState{host, Await{D.Finished{}, stage, continuation}, notes}, Nil{}, tape}
    case _ RefState{host, Await{D.Stuck{}, stage, continuation}, notes} tape:
      D.Ran{RefState{host, Await{D.Stuck{}, stage, continuation}, notes}, Nil{}, tape}
    case 0n state tape:
      D.Ran{state, Nil{}, tape}
    case _ state Nil{}:
      D.Ran{state, Nil{}, Nil{}}
    case 1n+fuel +state n <> rest:
      +next : D.Stepped<&2, RefState> = answer(state, n)
      run.merge(next, run(fuel, stepped.state(next), rest))

def trace.points(+tape: List<&2, Nat>, +state: RefState) -> Trace:
  match tape state:
    case _ RefState{host, Await{D.Finished{}, stage, continuation}, notes}:
      Trace{[TracePoint{D.Finished{}, snapshot(state)}], EndFinished{}}
    case _ RefState{host, Await{D.Stuck{}, stage, continuation}, notes}:
      Trace{[TracePoint{D.Stuck{}, snapshot(state)}], EndStuck{}}
    case Nil{} state:
      Trace{[TracePoint{request(state), snapshot(state)}], EndTapeExhausted{}}
    case n <> rest state:
      trace.prepend(TracePoint{request(state), snapshot(state)}, trace.points(rest, stepped.state(answer(state, n))))

# Comparator API. Yield request/state points through Finished, Stuck or tape
# exhaustion. Include the final point; its request reads no tape answer.
def trace(+config: D.Config, +tape: List<&2, Nat>) -> Trace:
  trace.points(tape, stepped.state(start(config)))
