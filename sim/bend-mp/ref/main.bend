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

type EndPacket is Data:
  EndPacket{from: D.Seat, passing: Bool, empty: Bool, winner: Maybe<&2, D.Seat>}

type ItemPacket is Data:
  ItemPacket{seat: D.Seat, owner: D.Seat, slot: D.Slot, item: D.Item, ending: Bool, phone: Maybe<&2, D.Secret>}

type Continuation is Data:
  FirstSeatResult{}
  StartingHealthResult{}
  ItemAmountResult{next: Frame}
  SequenceBatchResult{}
  ShuffleSwapResult{load: D.Load, shells: List<&2, D.Shell>, i: Nat}
  PlayerMove{mode: D.Mode}
  ItemGrab_Packet{}
  ItemChoiceResult{seat: D.Seat, pool: List<&2, D.Item>}
  PhoneIndexResult{packet: ItemPacket}

type Frame is Data:
  MainRoutine_StartRound{phase: StartPhase}
  GetFirstTurn_Socket{}
  GenerateRandomRound{}
  GetRandomItemGrabAmount{next: Frame}
  PacketSort_StartRound{}
  UnJamAllUsers{}
  SetupHealthIndicators{}
  ClearUserInventories{}
  BeginItemGrabbingForSockets{seats: List<&2, D.Seat>}
  MainRoutine_LoadShotgun{}
  GenerateRandomSequence{phase: SequencePhase}
  LoadShotgun{}
  PassTurn{seat: D.Seat}
  GiveTurnPermissions{seat: D.Seat}
  ReceivePacket_PickUpShotgun{seat: D.Seat}
  PacketSort_Verification{choice: D.Choice}
  ReceivePacket_Shoot{shot: Shot}
  ShootingOutcome{shot: Shot}
  DeathRequest{shot: Shot}
  RemoveFirstShellFromSequence{shot: Shot}
  ShotgunBarrel_Grow{next: Frame}
  CheckIfEndingTurn{shot: Shot}
  UserEndTurn_Packet{packet: EndPacket}
  MainRoutine_UserEndTurn{packet: EndPacket}
  WinRoutine{seat: D.Seat}
  LoopBackAfterWinRoutine{}
  GameConclusion_Packet{}
  GameConclusion{}
  GetItemToGrab{seat: D.Seat}
  ReceivePacket_GrabItem{seat: D.Seat, item: D.Item}
  IsPlacingLastItem{seat: D.Seat, slot: D.Slot}
  CheckIfItemGrabbingFinishedForAllUsers{next: Frame}
  GetSocketArrayToEndItemGrabbingOn{seat: D.Seat, slot: D.Slot}
  EndItemGrabbingAfterNonEligible{seats: List<&2, D.Seat>, next: Frame}
  ReceivePacket_PlaceItem{seat: D.Seat, slot: D.Slot}
  ContinueItemGrabbing{}
  CheckIfEndingTurnAfterItemUse{seat: D.Seat, owner: D.Seat, slot: D.Slot, item: D.Item}
  GetBurnerPhone_VerbalIndex{packet: ItemPacket}
  _GetBurnerPhone_Shell{packet: ItemPacket, index: Nat}
  ReceivePacket_InteractWithItem{packet: ItemPacket}
  RemoveItemFromInventory{packet: ItemPacket}
  ChangeGameStateWithItem{packet: ItemPacket}
  ShotgunBarrel_Remove{seat: D.Seat}
  BeginItemStealing{seat: D.Seat}
  ReceivePacket_InteractWithItem_Secondary{seat: D.Seat, target: D.Seat}
  Jammer_Enable{seat: D.Seat, target: D.Seat}
  EndItemInteraction{seat: D.Seat, ending: Bool}
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

def IncrementActiveSequenceIndex(+first: Bool, +old: Nat) -> Nat:
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

def EndPacket.reload(+packet: EndPacket) -> Bool:
  match packet:
    case EndPacket{_, _, empty, None{}}:
      empty
    case _:
      False{}

def MainRoutine_UserEndTurn.recipient(+passing: Bool, +from: D.Seat, +next: D.Seat) -> D.Seat:
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

def VerifyPacket.mode(+mode: D.Mode, +move: D.Move) -> Bool:
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

def GetRandomItemGrabAmount.stage(+next: Frame) -> D.Stage:
  match next:
    case PacketSort_StartRound{}:
      D.Setup{}
    case _:
      D.Distributing{}

def stuck(+state: RefState) -> RefState:
  frame(state, Await{D.Stuck{}, D.Setup{}, PlayerMove{D.Idle{}}})

def await_draw(+state: RefState, +label: D.Label, +range: D.Range, +stage: D.Stage, +continuation: Continuation) -> RefState:
  frame(state, Await{D.Draw{label, range}, stage, continuation})

def idle(+state: RefState, +seat: D.Seat, +mode: D.Mode, +moves: List<&2, D.Move>) -> RefState:
  frame(state, Await{D.request.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, S.host.table(host(state)), Nil{}), seat, moves)), D.Playing{seat, mode}, PlayerMove{mode}})

def MainRoutine_StartRound(+state: RefState, +phase: StartPhase) -> RefState:
  match phase:
    case BeginRound{}:
      frame(state, GetFirstTurn_Socket{})
    case FirstChosen{seat}:
      +h : S.Host = host(state)
      +h : S.Host = S.host.set_round_index(h, G.next_round(S.host.before_round(h), S.host.round_index(h)))
      +h : S.Host = S.host.set_before_round(h, False{})
      +h : S.Host = S.host.set_first_turn(h, seat)
      +h : S.Host = S.host.set_first_sequence(h, True{})
      frame(with_host(state, h), GenerateRandomRound{})

# Install the packet's first-death checking and CW writes before nested
# unjam/health/clear calls. Cosmetic revival and indicators are omitted.
def PacketSort_StartRound(+state: RefState) -> RefState:
  +h : S.Host = S.host.set_checking_first_death(host(state), True{})
  +h : S.Host = S.host.set_direction(h, D.Clockwise{})
  frame(with_host(state, h), UnJamAllUsers{})

def BeginItemGrabbingForSockets(+state: RefState, +seats: List<&2, D.Seat>) -> RefState:
  match seats:
    case Nil{}:
      frame(state, MainRoutine_LoadShotgun{})
    case +seat <> +rest:
      +h : S.Host = S.host.set_distributing(I.begin_grab(seat <> rest, host(state)), True{})
      state : RefState = emit(with_host(state, h), D.GrabbingBegan{seat <> rest})
      frame(state, Await{D.request.choose(grab_menus(D.ring.entries(S.Props, S.host.seats(h)), h, D.ring.fill(List<&2, D.Move>, S.host.table(h), Nil{}))), D.Distributing{}, ItemGrab_Packet{}})

def MainRoutine_LoadShotgun(+state: RefState) -> RefState:
  +h : S.Host = host(state)
  +h : S.Host = S.host.set_load_index(h, IncrementActiveSequenceIndex(S.host.first_sequence(h), S.host.load_index(h)))
  +h : S.Host = S.host.set_first_sequence(h, False{})
  frame(with_host(state, h), GenerateRandomSequence{SelectBatch{}})

def LoadShotgun(+state: RefState) -> RefState:
  frame(emit(state, D.Loaded{S.host.shown(host(state))}), PassTurn{S.host.first_turn(host(state))})

def PassTurn.props(+state: RefState, +seat: D.Seat, +props: S.Props) -> RefState:
  match props:
    case S.Props{hp, True{}, False{}, cash, slots, grab, holding, turn}:
      +h : S.Host = S.host.set_props(host(state), seat, S.Props{hp, True{}, True{}, cash, slots, grab, holding, turn})
      frame(emit(with_host(state, h), D.TurnSkipped{seat}), PassTurn{G.GetNextTurn_Socket(h, seat)})
    case S.Props{hp, True{}, True{}, cash, slots, grab, holding, turn}:
      +h : S.Host = S.host.set_props(host(state), seat, S.Props{hp, False{}, True{}, cash, slots, grab, holding, turn})
      frame(emit(with_host(state, h), D.JamLifted{seat}), GiveTurnPermissions{seat})
    case _:
      frame(state, GiveTurnPermissions{seat})

def ReceivePacket_Shoot.grow(+state: RefState, +shot: Shot, +self_live: Bool) -> RefState:
  match self_live:
    case True{}:
      frame(state, ShotgunBarrel_Grow{ShootingOutcome{shot}})
    case False{}:
      frame(state, ShootingOutcome{shot})

def ShootingOutcome(+state: RefState, +shot: Shot) -> RefState:
  match shot:
    case Shot{shooter, +target, +shell, damage, length}:
      +h : S.Host = host(state)
      +old : Nat = S.props.health(S.host.props(h, target))
      +hp : Nat = G.shell.health(shell, old, damage)
      +h : S.Host = S.host.set_props(h, target, S.props.set_health(S.host.props(h, target), hp))
      state : RefState = emit(with_host(state, h), D.Fired{shooter, target, shell, damage, G.subtract(old, hp), hp})
      frame(state, DeathRequest{shot})

def DeathRequest.first(+state: RefState, +seat: D.Seat, +checking: Bool) -> RefState:
  match checking:
    case True{}:
      +h : S.Host = S.host.set_first_death(host(state), Some{seat})
      with_host(state, S.host.set_checking_first_death(h, False{}))
    case False{}:
      state

def ShotgunBarrel_Grow(+state: RefState, +next: Frame) -> RefState:
  frame(with_host(state, S.host.set_sawed(host(state), False{})), next)

def CheckIfEndingTurn(+state: RefState, +shot: Shot) -> RefState:
  match shot:
    case Shot{+shooter, target, shell, damage, +length}:
      frame(state, UserEndTurn_Packet{EndPacket{shooter, Bool.not(Bool.and(D.seat.eq(shooter, target), Bool.not(G.shell.live(shell)))), Nat.is_eq(length, 0n), G.CheckIfUserHasWon(host(state))}})

def UserEndTurn_Packet.live(+state: RefState, +packet: EndPacket, +live: Bool) -> RefState:
  match live:
    case True{}:
      frame(state, GetRandomItemGrabAmount{MainRoutine_UserEndTurn{packet}})
    case False{}:
      frame(state, MainRoutine_UserEndTurn{packet})

def MainRoutine_UserEndTurn.pass(+state: RefState, +empty: Bool, +recipient: D.Seat) -> RefState:
  match empty:
    case True{}:
      +h : S.Host = S.host.set_first_turn(host(state), recipient)
      frame(with_host(state, h), BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(h, False{}, S.host.item_amount(h))})
    case False{}:
      frame(with_host(state, S.host.set_first_turn(host(state), recipient)), PassTurn{recipient})

def WinRoutine(+state: RefState, +seat: D.Seat) -> RefState:
  +prize : U32 = D.prize(S.host.round_index(host(state)))
  +h : S.Host = S.host.set_props(host(state), seat, S.props.award(S.host.props(host(state), seat), prize))
  frame(emit(with_host(state, h), D.RoundWon{seat, prize}), LoopBackAfterWinRoutine{})

def LoopBackAfterWinRoutine.final(+state: RefState, +final: Bool) -> RefState:
  match final:
    case True{}:
      frame(state, GameConclusion_Packet{})
    case False{}:
      frame(state, MainRoutine_StartRound{BeginRound{}})

def GameConclusion_Packet(+state: RefState) -> RefState:
  frame(state, GameConclusion{})

def GameConclusion(+state: RefState) -> RefState:
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
def VerifyPacket.grab(props: S.Props, move: D.Move) -> Bool:
  match props move:
    case S.Props{_, _, _, _, _, True{}, None{}, _} D.Grab{}:
      True{}
    case S.Props{_, _, _, _, _, True{}, Some{item}, _} D.Place{slot}:
      True{}
    case _ _:
      False{}

def VerifyPacket.ownership(host: S.Host, seat: D.Seat, move: D.Move) -> Bool:
  match move:
    case D.UseItem{slot, item}:
      G.alive(G.item.count(G.slots.list(I.props.slots(S.host.props(host, seat))), item))
    case D.Steal{owner, slot, item}:
      G.alive(G.item.count(G.slots.list(I.props.slots(S.host.props(host, owner))), item))
    case _:
      True{}

def VerifyPacket(+state: RefState, +choice: D.Choice) -> Bool:
  match state choice:
    case RefState{+h, Await{request, stage, ItemGrab_Packet{}}, notes} D.Choice{seat, index, move}:
      VerifyPacket.grab(S.host.props(h, seat), move)
    case RefState{+h, Await{request, D.Playing{viewing, mode}, PlayerMove{D.Jamming{}}}, notes} D.Choice{+seat, index, D.JamTarget{target}}:
      Bool.and(D.seat.eq(viewing, seat), props.has_turn(S.host.props(h, seat)))
    case RefState{+h, Await{request, stage, PlayerMove{+mode}}, notes} D.Choice{+seat, index, +move}:
      Bool.and(current.eq(S.host.turn(h), seat), Bool.and(props.has_turn(S.host.props(h, seat)), Bool.and(VerifyPacket.mode(mode, move), VerifyPacket.ownership(h, seat, move))))
    case _ _:
      False{}

def RemoveFirstShellFromSequence.self(+state: RefState, +shot: Shot, +self_live: Bool) -> RefState:
  match self_live:
    case True{}:
      frame(state, CheckIfEndingTurn{shot})
    case False{}:
      frame(state, ShotgunBarrel_Grow{CheckIfEndingTurn{shot}})

def round_write(+state: RefState, write: G.RoundSeatWrite, next: Frame) -> RefState:
  +h : S.Host = host(state)
  +h : S.Host = S.host.set_seats(h, G.round_seats(D.ring.entries(S.Props, S.host.seats(h)), write, S.host.seats(h)))
  frame(with_host(state, h), next)

def GetFirstTurn_Socket.override(+state: RefState, +override: Maybe<&2, D.Seat>) -> RefState:
  match override:
    case Some{seat}:
      frame(state, MainRoutine_StartRound{FirstChosen{seat}})
    case None{}:
      await_draw(state, D.FirstSeat{}, D.Range{0n, G.subtract(D.table.count(S.host.table(host(state))), 2n)}, D.Setup{}, FirstSeatResult{})

def GenerateRandomRound.rule(+state: RefState, +rule: D.HealthRule) -> RefState:
  match rule:
    case D.RandomHealth{}:
      await_draw(state, D.StartingHealth{}, D.table.health_range(S.host.table(host(state))), D.Setup{}, StartingHealthResult{})
    case D.FixedHealth{health}:
      frame(with_host(state, S.host.set_round_health(host(state), D.pos.nat(health))), GetRandomItemGrabAmount{PacketSort_StartRound{}})

def GetRandomItemGrabAmount.rule(+state: RefState, +next: Frame, +rule: D.AmountRule) -> RefState:
  match rule:
    case D.RandomAmount{}:
      await_draw(state, D.ItemAmount{}, D.table.amount_range(S.host.table(host(state))), GetRandomItemGrabAmount.stage(next), ItemAmountResult{next})
    case D.FixedAmount{amount}:
      frame(with_host(state, S.host.set_item_amount(host(state), amount)), next)

def GenerateRandomSequence.request(+state: RefState, +deck: List<&2, S.Batch>) -> RefState:
  match deck:
    case Nil{}:
      stuck(state)
    case batch <> Nil{}:
      frame(state, GenerateRandomSequence{BatchChosen{0n}})
    case batch <> next <> rest:
      await_draw(state, D.SequenceBatch{}, D.Range{0n, List.length(&2, S.Batch, rest)}, D.Loading{}, SequenceBatchResult{})

def GenerateRandomSequence.batch(+state: RefState, +index: Nat, +selected: Maybe<&2, S.Batch>) -> RefState:
  match selected:
    case None{}:
      stuck(state)
    case Some{S.Batch{id, sampled}}:
      +h : S.Host = host(state)
      +load : D.Load = G.load.custom(S.host.load_rule(h), sampled)
      +shells : List<&2, D.Shell> = G.load.shells(load)
      +h : S.Host = S.host.set_deck(h, G.remove(S.Batch, S.host.deck(h), index))
      frame(with_host(state, h), GenerateRandomSequence{Shuffle{load, shells, G.subtract(List.length(&2, D.Shell, shells), 1n)}})

def PassTurn(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = S.host.set_turn(host(state), Some{seat})
  PassTurn.props(with_host(state, h), seat, S.host.props(h, seat))

def idle_items(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = host(state)
  idle(state, seat, D.Idle{}, D.PickUp{} <> I.use_moves(I.slots.all(), h, seat))

def GiveTurnPermissions(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = S.host.set_props(host(state), seat, S.props.set_turn(S.host.props(host(state), seat), True{}))
  idle_items(emit(with_host(state, h), D.TurnGiven{seat}), seat)

def ReceivePacket_PickUpShotgun(+state: RefState, +seat: D.Seat) -> RefState:
  idle(emit(state, D.PickedUp{seat}), seat, D.Aiming{}, shot_moves(G.living(D.ring.entries(S.Props, S.host.seats(host(state))))))

def PacketSort_Verification.shell(+state: RefState, +shooter: D.Seat, +target: D.Seat, +gun: List<&2, D.Shell>) -> RefState:
  match gun:
    case Nil{}:
      stuck(state)
    case +shell <> rest:
      +h : S.Host = host(state)
      +shot : Shot = Shot{shooter, target, shell, G.damage(S.host.sawed(h)), List.length(&2, D.Shell, rest)}
      frame(state, ReceivePacket_Shoot{shot})

def DeathRequest.health(+state: RefState, +shot: Shot, +hp: Nat) -> RefState:
  match shot hp:
    case Shot{shooter, +target, D.Live{}, damage, length} 0n:
      state : RefState = DeathRequest.first(state, target, S.host.checking_first_death(host(state)))
      frame(emit(state, D.Died{target}), RemoveFirstShellFromSequence{Shot{shooter, target, D.Live{}, damage, length}})
    case shot _:
      frame(state, RemoveFirstShellFromSequence{shot})

def UserEndTurn_Packet.amount(+state: RefState, +packet: EndPacket, +rule: D.AmountRule) -> RefState:
  match rule:
    case D.FixedAmount{amount}:
      frame(with_host(state, S.host.set_item_amount(host(state), amount)), MainRoutine_UserEndTurn{packet})
    case D.RandomAmount{}:
      +h : S.Host = host(state)
      UserEndTurn_Packet.live(state, packet, Bool.or(S.host.distributing(h), Bool.and(EndPacket.reload(packet), G.nonempty(D.Seat, G.GetSocketsToBeginItemGrabbingOn(h, False{}, 1n)))))

def MainRoutine_UserEndTurn(+state: RefState, +packet: EndPacket) -> RefState:
  match packet:
    case EndPacket{from, passing, empty, Some{winner}}:
      frame(state, WinRoutine{winner})
    case EndPacket{+from, passing, empty, None{}}:
      +h : S.Host = host(state)
      MainRoutine_UserEndTurn.pass(state, empty, MainRoutine_UserEndTurn.recipient(passing, from, G.GetNextTurn_Socket(h, from)))

def LoopBackAfterWinRoutine(+state: RefState) -> RefState:
  LoopBackAfterWinRoutine.final(state, Nat.is_eq(1n+S.host.round_index(host(state)), D.plan.length(S.host.plan(host(state)))))

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

def GetItemToGrab.selected(+state: RefState, +seat: D.Seat, found: Maybe<&2, D.Item>) -> RefState:
  match found:
    case Some{item}:
      frame(state, ReceivePacket_GrabItem{seat, item})
    case None{}:
      frame(tell(state, seat, D.EmptyBriefcase{}), ContinueItemGrabbing{})

def answer.draw(+state: RefState, +value: Nat, +continuation: Continuation) -> RefState:
  match continuation:
    case FirstSeatResult{}:
      frame(state, MainRoutine_StartRound{FirstChosen{G.seat.default(G.nth(D.Seat, D.table.seats(S.host.table(host(state))), value))}})
    case StartingHealthResult{}:
      frame(with_host(state, S.host.set_round_health(host(state), value)), GetRandomItemGrabAmount{PacketSort_StartRound{}})
    case ItemAmountResult{next}:
      frame(with_host(state, S.host.set_item_amount(host(state), value)), next)
    case ItemChoiceResult{seat, pool}:
      GetItemToGrab.selected(state, seat, G.nth(D.Item, pool, value))
    case PhoneIndexResult{packet}:
      frame(state, _GetBurnerPhone_Shell{packet, value})
    case SequenceBatchResult{}:
      frame(state, GenerateRandomSequence{BatchChosen{value}})
    case ShuffleSwapResult{load, shells, +i}:
      frame(state, GenerateRandomSequence{Shuffle{load, G.swap(shells, i, value), G.subtract(i, 1n)}})
    case _:
      stuck(state)

def ReceivePacket_Shoot(+state: RefState, +shot: Shot) -> RefState:
  match shot:
    case Shot{+shooter, target, shell, damage, length}:
      +h : S.Host = host(state)
      +h : S.Host = S.host.set_props(h, shooter, S.props.set_turn(S.host.props(h, shooter), False{}))
      ReceivePacket_Shoot.grow(with_host(state, h), shot, Bool.and(D.seat.eq(shooter, target), G.shell.live(shell)))

def answer.move.accepted(+state: RefState, +choice: D.Choice, +accepted: Bool) -> RefState:
  match accepted:
    case True{}:
      frame(state, PacketSort_Verification{choice})
    case False{}:
      stuck(state)

# Self-live uses D51's FP representative. Grow already preceded damage. TP
# moves that write after outcome, with no normal request between the writes.
def RemoveFirstShellFromSequence.grow(+state: RefState, +shot: Shot) -> RefState:
  match shot:
    case Shot{+shooter, target, D.Live{}, damage, length}:
      RemoveFirstShellFromSequence.self(state, Shot{shooter, target, D.Live{}, damage, length}, D.seat.eq(shooter, target))
    case shot:
      frame(state, ShotgunBarrel_Grow{CheckIfEndingTurn{shot}})

def UnJamAllUsers(state: RefState) -> RefState:
  round_write(state, G.DisableJam{}, SetupHealthIndicators{})

def SetupHealthIndicators(+state: RefState) -> RefState:
  +h : S.Host = host(state)
  state : RefState = round_write(state, G.RestoreHealth{S.host.round_health(h)}, ClearUserInventories{})
  emit(state, D.RoundBegan{S.host.round_index(h), S.host.round_health(h), S.host.first_turn(h)})

# M3 selects only after slot/count clearing. Under normal play, grant
# counts equal placed plus held inventory; an empty clear cannot erase any.
def ClearUserInventories(+state: RefState) -> RefState:
  +cleared : RefState = round_write(state, G.ClearSlots{}, MainRoutine_LoadShotgun{})
  +h : S.Host = host(cleared)
  frame(cleared, BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(h, True{}, S.host.item_amount(h))})

def RemoveFirstShellFromSequence(+state: RefState, +shot: Shot) -> RefState:
  +h : S.Host = S.host.set_gun(host(state), gun.tail(S.host.gun(host(state))))
  RemoveFirstShellFromSequence.grow(with_host(state, h), shot)

def answer.move(+state: RefState, +choice: D.Choice) -> RefState:
  answer.move.accepted(state, choice, VerifyPacket(state, choice))

def GetFirstTurn_Socket(+state: RefState) -> RefState:
  GetFirstTurn_Socket.override(state, S.host.first_death(host(state)))

def GenerateRandomRound(+state: RefState) -> RefState:
  GenerateRandomRound.rule(state, S.rules.health(S.host.rules(host(state))))

def GetRandomItemGrabAmount(+state: RefState, +next: Frame) -> RefState:
  GetRandomItemGrabAmount.rule(state, next, G.load.amount(S.host.load_rule(host(state))))

def GenerateRandomSequence.refill(+state: RefState, +deck: List<&2, S.Batch>) -> RefState:
  match deck:
    case Nil{}:
      +h : S.Host = S.host.set_decks(host(state), S.MakeSequenceCopies())
      GenerateRandomSequence.request(with_host(state, h), S.host.deck(h))
    case deck:
      GenerateRandomSequence.request(state, deck)

def DeathRequest(+state: RefState, +shot: Shot) -> RefState:
  DeathRequest.health(state, shot, S.props.health(S.host.props(host(state), shot.target(shot))))

def UserEndTurn_Packet(+state: RefState, +packet: EndPacket) -> RefState:
  UserEndTurn_Packet.amount(state, packet, G.load.amount(S.host.load_rule(host(state))))

def board(+state: RefState) -> D.Board:
  +h : S.Host = host(state)
  seats : D.Ring<&2, D.SeatView> = seat_views(D.ring.entries(S.Props, S.host.seats(h)), D.ring.fill(D.SeatView, S.host.table(h), props.view(S.props.initial())))
  D.Board{D.RoundView{S.host.round_index(h), D.plan.length(S.host.plan(h)), S.host.round_health(h)}, seats, D.GunView{S.host.shown(h), List.length(&2, D.Shell, S.host.gun(h)), S.host.sawed(h)}, S.host.direction(h), stage(state)}

def PacketSort_Verification.choice(+state: RefState, +choice: D.Choice) -> RefState:
  match choice:
    case D.Choice{seat, index, D.PickUp{}}:
      frame(state, ReceivePacket_PickUpShotgun{seat})
    case D.Choice{shooter, index, D.Shoot{target}}:
      PacketSort_Verification.shell(state, shooter, target, S.host.gun(host(state)))
    case D.Choice{seat, index, D.Grab{}}:
      frame(state, GetItemToGrab{seat})
    case D.Choice{seat, index, D.Place{slot}}:
      frame(state, IsPlacingLastItem{seat, slot})
    case D.Choice{seat, index, D.UseItem{slot, item}}:
      frame(state, CheckIfEndingTurnAfterItemUse{seat, seat, slot, item})
    case D.Choice{seat, index, D.Steal{owner, slot, item}}:
      frame(state, CheckIfEndingTurnAfterItemUse{seat, owner, slot, item})
    case D.Choice{seat, index, D.JamTarget{target}}:
      frame(state, ReceivePacket_InteractWithItem_Secondary{seat, target})

def answer.resolved(+state: RefState, +continuation: Continuation, +resolved: D.Resolved) -> RefState:
  match continuation resolved:
    case continuation D.Drawn{value}:
      answer.draw(state, value, continuation)
    case PlayerMove{mode} D.Chose{choice}:
      answer.move(state, choice)
    case ItemGrab_Packet{} D.Chose{choice}:
      answer.move(state, choice)
    case _ _:
      stuck(state)

def GenerateRandomSequence(+state: RefState, +phase: SequencePhase) -> RefState:
  match phase:
    case SelectBatch{}:
      GenerateRandomSequence.refill(state, S.host.deck(host(state)))
    case BatchChosen{+index}:
      GenerateRandomSequence.batch(state, index, G.nth(S.Batch, S.host.deck(host(state)), index))
    case Shuffle{load, shells, 0n}:
      +h : S.Host = S.host.set_gun(host(state), shells)
      +h : S.Host = S.host.set_shown(h, load)
      frame(with_host(state, h), LoadShotgun{})
    case Shuffle{load, shells, 1n+i}:
      await_draw(state, D.ShuffleSwap{}, D.Range{0n, i}, D.Loading{}, ShuffleSwapResult{load, shells, 1n+i})

# Public API. Point excludes the private chamber order and resource deck.
def point(+state: RefState) -> D.Point:
  D.Point{request(state), board(state)}

def PacketSort_Verification(+state: RefState, +choice: D.Choice) -> RefState:
  PacketSort_Verification.choice(state, choice)

def ContinueItemGrabbing.ready(+state: RefState, distributing: Bool, holders: Bool) -> RefState:
  match distributing holders:
    case False{} False{}:
      frame(state, MainRoutine_LoadShotgun{})
    case _ _:
      +h : S.Host = host(state)
      frame(state, Await{D.request.choose(grab_menus(D.ring.entries(S.Props, S.host.seats(h)), h, D.ring.fill(List<&2, D.Move>, S.host.table(h), Nil{}))), D.Distributing{}, ItemGrab_Packet{}})

def ContinueItemGrabbing(+state: RefState) -> RefState:
  +h : S.Host = host(state)
  ContinueItemGrabbing.ready(state, S.host.distributing(h), I.holders(D.ring.entries(S.Props, S.host.seats(h))))

def GetItemToGrab.pool(+state: RefState, +seat: D.Seat, pool: List<&2, D.Item>) -> RefState:
  match pool:
    case Nil{}:
      GetItemToGrab.selected(state, seat, None{})
    case item <> Nil{}:
      frame(state, ReceivePacket_GrabItem{seat, item})
    case item <> next <> +rest:
      await_draw(state, D.ItemChoice{}, D.Range{0n, List.length(&2, D.Item, rest)}, D.Distributing{}, ItemChoiceResult{seat, item <> next <> rest})

def GetItemToGrab(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = host(state)
  +h : S.Host = S.host.set_progress(h, seat, S.GrabProgress{I.progress.count(S.host.progress(h, seat)), False{}})
  GetItemToGrab.pool(with_host(state, h), seat, G.GetItemToGrab.pool(D.item.order(), h, seat))

def ReceivePacket_GrabItem(+state: RefState, +seat: D.Seat, +item: D.Item) -> RefState:
  +h : S.Host = S.host.set_props(host(state), seat, S.props.set_holding(S.host.props(host(state), seat), Some{item}))
  +h : S.Host = S.host.set_progress(h, seat, S.GrabProgress{1n+I.progress.count(S.host.progress(h, seat)), False{}})
  frame(emit(with_host(state, h), D.Granted{seat, item}), ContinueItemGrabbing{})

def IsPlacingLastItem.last(+state: RefState, +seat: D.Seat, +slot: D.Slot, last: Bool) -> RefState:
  match last:
    case True{}:
      +h : S.Host = S.host.set_props(host(state), seat, S.props.end_grab(S.host.props(host(state), seat)))
      frame(emit(with_host(state, h), D.GrabbingEnded{seat}), CheckIfItemGrabbingFinishedForAllUsers{GetSocketArrayToEndItemGrabbingOn{seat, slot}})
    case False{}:
      frame(state, ReceivePacket_PlaceItem{seat, slot})

def IsPlacingLastItem(+state: RefState, +seat: D.Seat, slot: D.Slot) -> RefState:
  IsPlacingLastItem.last(state, seat, slot, I.IsPlacingLastItem(host(state), seat))

# The distribution flag is the completion latch. It changes at the first
# true source predicate, not when the deferred load starts.
def CheckIfItemGrabbingFinishedForAllUsers.result(+state: RefState, next: Frame, complete: Bool) -> RefState:
  match complete:
    case True{}:
      frame(emit(with_host(state, S.host.set_distributing(host(state), False{})), D.DistributionDone{}), next)
    case False{}:
      frame(state, next)

def CheckIfItemGrabbingFinishedForAllUsers(+state: RefState, next: Frame) -> RefState:
  +h : S.Host = host(state)
  CheckIfItemGrabbingFinishedForAllUsers.result(state, next, Bool.and(S.host.distributing(h), I.CheckIfItemGrabbingFinishedForAllUsers(h)))

def GetSocketArrayToEndItemGrabbingOn(+state: RefState, +seat: D.Seat, +slot: D.Slot) -> RefState:
  +h : S.Host = host(state)
  frame(state, EndItemGrabbingAfterNonEligible{I.GetSocketArrayToEndItemGrabbingOn(D.ring.entries(S.Props, S.host.seats(h)), h, seat), CheckIfItemGrabbingFinishedForAllUsers{ReceivePacket_PlaceItem{seat, slot}}})

def EndItemGrabbingAfterNonEligible(+state: RefState, seats: List<&2, D.Seat>, next: Frame) -> RefState:
  match seats:
    case Nil{}:
      frame(state, next)
    case +seat <> rest:
      +h : S.Host = S.host.set_props(host(state), seat, S.props.end_grab(S.host.props(host(state), seat)))
      frame(emit(with_host(state, h), D.GrabbingEnded{seat}), EndItemGrabbingAfterNonEligible{rest, next})

def ReceivePacket_PlaceItem.held(+state: RefState, +seat: D.Seat, +slot: D.Slot, held: Maybe<&2, D.Item>) -> RefState:
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
      frame(emit(with_host(state, h), D.Placed{seat, slot, item}), ContinueItemGrabbing{})

def ReceivePacket_PlaceItem(+state: RefState, +seat: D.Seat, slot: D.Slot) -> RefState:
  ReceivePacket_PlaceItem.held(state, seat, slot, I.props.holding(S.host.props(host(state), seat)))

def CheckIfEndingTurnAfterItemUse.phone(+state: RefState, packet: ItemPacket, item: D.Item) -> RefState:
  match item:
    case D.Phone{}:
      frame(state, GetBurnerPhone_VerbalIndex{packet})
    case _:
      frame(state, ReceivePacket_InteractWithItem{packet})

def CheckIfEndingTurnAfterItemUse(+state: RefState, +seat: D.Seat, owner: D.Seat, slot: D.Slot, +item: D.Item) -> RefState:
  +packet : ItemPacket = ItemPacket{seat, owner, slot, item, I.CheckIfEndingTurnAfterItemUse(item, List.length(&2, D.Shell, S.host.gun(host(state)))), None{}}
  CheckIfEndingTurnAfterItemUse.phone(state, packet, item)

def packet.phone(packet: ItemPacket, phone: D.Secret) -> ItemPacket:
  match packet:
    case ItemPacket{seat, owner, slot, item, ending, _}:
      ItemPacket{seat, owner, slot, item, ending, Some{phone}}

def packet.seat(packet: ItemPacket) -> D.Seat:
  match packet:
    case ItemPacket{seat, _, _, _, _, _}:
      seat
def GetBurnerPhone_VerbalIndex.length(+state: RefState, +packet: ItemPacket, length: Nat) -> RefState:
  match length:
    case 0n:
      frame(state, ReceivePacket_InteractWithItem{packet.phone(packet, D.NoClue{})})
    case 1n:
      frame(state, ReceivePacket_InteractWithItem{packet.phone(packet, D.NoClue{})})
    case 2n:
      frame(state, ReceivePacket_InteractWithItem{packet.phone(packet, D.NoClue{})})
    case 3n:
      frame(state, _GetBurnerPhone_Shell{packet, 2n})
    case 4n+extra:
      await_draw(state, D.PhoneIndex{}, D.Range{2n, extra}, D.Playing{packet.seat(packet), D.Idle{}}, PhoneIndexResult{packet})

def GetBurnerPhone_VerbalIndex(+state: RefState, packet: ItemPacket) -> RefState:
  GetBurnerPhone_VerbalIndex.length(state, packet, List.length(&2, D.Shell, S.host.gun(host(state))))

def _GetBurnerPhone_Shell.found(+state: RefState, packet: ItemPacket, index: Nat, found: Maybe<&2, D.Shell>) -> RefState:
  match found:
    case None{}:
      stuck(state)
    case Some{shell}:
      frame(state, ReceivePacket_InteractWithItem{packet.phone(packet, D.Clue{index, shell})})

def _GetBurnerPhone_Shell(+state: RefState, packet: ItemPacket, index: Nat) -> RefState:
  +verbal : Nat = D.clamp(1n+index, D.phone.cap())
  _GetBurnerPhone_Shell.found(state, packet, verbal, G.nth(D.Shell, S.host.gun(host(state)), G.subtract(verbal, 1n)))

def ReceivePacket_InteractWithItem(+state: RefState, +packet: ItemPacket) -> RefState:
  match packet:
    case ItemPacket{+seat, owner, slot, +item, ending, phone}:
      +h : S.Host = S.host.set_props(host(state), seat, S.props.set_turn(S.host.props(host(state), seat), Bool.or(D.item.eq(item, D.Jammer{}), D.item.eq(item, D.Adrenaline{}))))
      frame(with_host(state, h), RemoveItemFromInventory{packet})

def RemoveItemFromInventory(+state: RefState, +packet: ItemPacket) -> RefState:
  match packet:
    case ItemPacket{seat, +owner, +slot, item, ending, phone}:
      +h : S.Host = host(state)
      +h : S.Host = S.host.set_props(h, owner, S.props.set_slots(S.host.props(h, owner), I.slots.set(I.props.slots(S.host.props(h, owner)), slot, None{})))
      frame(emit(with_host(state, h), D.Used{seat, owner, slot, item}), ChangeGameStateWithItem{packet})

def ChangeGameStateWithItem.shell(+state: RefState, +seat: D.Seat, item: D.Item, ending: Bool, +shell: D.Shell, rest: List<&2, D.Shell>) -> RefState:
  match item:
    case D.Glass{}:
      frame(tell(state, seat, D.Glimpse{shell}), EndItemInteraction{seat, ending})
    case D.Beer{}:
      frame(emit(with_host(state, S.host.set_gun(host(state), rest)), D.Ejected{seat, shell}), EndItemInteraction{seat, ending})
    case D.Inverter{}:
      frame(emit(with_host(state, S.host.set_gun(host(state), I.inverted(shell) <> rest)), D.Inverted{seat}), EndItemInteraction{seat, ending})
    case _:
      stuck(state)

def ChangeGameStateWithItem.head(+state: RefState, +seat: D.Seat, +item: D.Item, ending: Bool, gun: List<&2, D.Shell>) -> RefState:
  match gun:
    case Nil{}:
      stuck(state)
    case +shell <> rest:
      ChangeGameStateWithItem.shell(state, seat, item, ending, shell, rest)

def ChangeGameStateWithItem.heal(+state: RefState, +seat: D.Seat, heal: Bool) -> RefState:
  match heal:
    case True{}:
      +h : S.Host = host(state)
      +hp : Nat = 1n+S.props.health(S.host.props(h, seat))
      +h : S.Host = S.host.set_props(h, seat, S.props.set_health(S.host.props(h, seat), hp))
      frame(emit(with_host(state, h), D.Healed{seat, hp}), EndItemInteraction{seat, False{}})
    case False{}:
      frame(state, EndItemInteraction{seat, False{}})

def ChangeGameStateWithItem.phone(+state: RefState, +seat: D.Seat, result: Maybe<&2, D.Secret>) -> RefState:
  match result:
    case None{}:
      stuck(state)
    case Some{secret}:
      frame(tell(state, seat, secret), EndItemInteraction{seat, False{}})

def ChangeGameStateWithItem(+state: RefState, packet: ItemPacket) -> RefState:
  match packet:
    case ItemPacket{+seat, owner, slot, D.Saw{}, ending, phone}:
      frame(state, ShotgunBarrel_Remove{seat})
    case ItemPacket{+seat, owner, slot, D.Jammer{}, ending, phone}:
      +h : S.Host = host(state)
      idle(state, seat, D.Jamming{}, I.jam_moves(I.jam_targets(D.ring.entries(S.Props, S.host.seats(h)), seat)))
    case ItemPacket{+seat, owner, slot, D.Cigarettes{}, ending, phone}:
      +h : S.Host = host(state)
      ChangeGameStateWithItem.heal(state, seat, Nat.is_lt(S.props.health(S.host.props(h, seat)), S.host.round_health(h)))
    case ItemPacket{seat, owner, slot, D.Phone{}, ending, phone}:
      ChangeGameStateWithItem.phone(state, seat, phone)
    case ItemPacket{seat, owner, slot, D.Adrenaline{}, ending, phone}:
      frame(state, BeginItemStealing{seat})
    case ItemPacket{+seat, owner, slot, D.Remote{}, ending, phone}:
      +direction : D.Direction = I.FlipTurnOrder(S.host.direction(host(state)))
      frame(emit(with_host(state, S.host.set_direction(host(state), direction)), D.DirectionFlipped{direction}), EndItemInteraction{seat, False{}})
    case ItemPacket{seat, owner, slot, item, ending, phone}:
      ChangeGameStateWithItem.head(state, seat, item, ending, S.host.gun(host(state)))

def ShotgunBarrel_Remove(+state: RefState, seat: D.Seat) -> RefState:
  frame(with_host(state, S.host.set_sawed(host(state), True{})), EndItemInteraction{seat, False{}})

def BeginItemStealing(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = host(state)
  idle(state, seat, D.Stealing{}, I.steal_moves(D.ring.entries(S.Props, S.host.seats(h)), h, seat))

def ReceivePacket_InteractWithItem_Secondary(+state: RefState, +seat: D.Seat, target: D.Seat) -> RefState:
  +h : S.Host = S.host.set_props(host(state), seat, S.props.set_turn(S.host.props(host(state), seat), False{}))
  frame(with_host(state, h), Jammer_Enable{seat, target})

def Jammer_Enable(+state: RefState, +seat: D.Seat, +target: D.Seat) -> RefState:
  +h : S.Host = S.host.set_props(host(state), target, S.props.jam(S.host.props(host(state), target)))
  frame(emit(with_host(state, h), D.JamApplied{seat, target}), EndItemInteraction{seat, False{}})

def EndItemInteraction(+state: RefState, +seat: D.Seat, ending: Bool) -> RefState:
  match ending:
    case True{}:
      frame(state, UserEndTurn_Packet{EndPacket{seat, True{}, Nat.is_eq(List.length(&2, D.Shell, S.host.gun(host(state))), 0n), None{}}})
    case False{}:
      +h : S.Host = S.host.set_props(host(state), seat, S.props.set_turn(S.host.props(host(state), seat), True{}))
      idle_items(with_host(state, h), seat)
def dispatch(+state: RefState) -> RefState:
  match state:
    case RefState{host, MainRoutine_StartRound{phase}, notes}:
      MainRoutine_StartRound(RefState{host, MainRoutine_StartRound{phase}, notes}, phase)
    case RefState{host, GetFirstTurn_Socket{}, notes}:
      GetFirstTurn_Socket(state)
    case RefState{host, GenerateRandomRound{}, notes}:
      GenerateRandomRound(state)
    case RefState{host, GetRandomItemGrabAmount{next}, notes}:
      GetRandomItemGrabAmount(state, next)
    case RefState{host, PacketSort_StartRound{}, notes}:
      PacketSort_StartRound(state)
    case RefState{host, UnJamAllUsers{}, notes}:
      UnJamAllUsers(state)
    case RefState{host, SetupHealthIndicators{}, notes}:
      SetupHealthIndicators(state)
    case RefState{host, ClearUserInventories{}, notes}:
      ClearUserInventories(state)
    case RefState{host, BeginItemGrabbingForSockets{seats}, notes}:
      BeginItemGrabbingForSockets(state, seats)
    case RefState{host, MainRoutine_LoadShotgun{}, notes}:
      MainRoutine_LoadShotgun(state)
    case RefState{host, GenerateRandomSequence{phase}, notes}:
      GenerateRandomSequence(state, phase)
    case RefState{host, LoadShotgun{}, notes}:
      LoadShotgun(state)
    case RefState{host, PassTurn{seat}, notes}:
      PassTurn(state, seat)
    case RefState{host, GiveTurnPermissions{seat}, notes}:
      GiveTurnPermissions(state, seat)
    case RefState{host, ReceivePacket_PickUpShotgun{seat}, notes}:
      ReceivePacket_PickUpShotgun(state, seat)
    case RefState{host, PacketSort_Verification{choice}, notes}:
      PacketSort_Verification(state, choice)
    case RefState{host, ReceivePacket_Shoot{shot}, notes}:
      ReceivePacket_Shoot(state, shot)
    case RefState{host, ShootingOutcome{shot}, notes}:
      ShootingOutcome(state, shot)
    case RefState{host, DeathRequest{shot}, notes}:
      DeathRequest(state, shot)
    case RefState{host, RemoveFirstShellFromSequence{shot}, notes}:
      RemoveFirstShellFromSequence(state, shot)
    case RefState{host, ShotgunBarrel_Grow{next}, notes}:
      ShotgunBarrel_Grow(state, next)
    case RefState{host, CheckIfEndingTurn{shot}, notes}:
      CheckIfEndingTurn(state, shot)
    case RefState{host, UserEndTurn_Packet{packet}, notes}:
      UserEndTurn_Packet(state, packet)
    case RefState{host, MainRoutine_UserEndTurn{packet}, notes}:
      MainRoutine_UserEndTurn(state, packet)
    case RefState{host, WinRoutine{seat}, notes}:
      WinRoutine(state, seat)
    case RefState{host, LoopBackAfterWinRoutine{}, notes}:
      LoopBackAfterWinRoutine(state)
    case RefState{host, GameConclusion_Packet{}, notes}:
      GameConclusion_Packet(state)
    case RefState{host, GameConclusion{}, notes}:
      GameConclusion(state)
    case RefState{host, GetItemToGrab{seat}, notes}:
      GetItemToGrab(state, seat)
    case RefState{host, ReceivePacket_GrabItem{seat, item}, notes}:
      ReceivePacket_GrabItem(state, seat, item)
    case RefState{host, IsPlacingLastItem{seat, slot}, notes}:
      IsPlacingLastItem(state, seat, slot)
    case RefState{host, CheckIfItemGrabbingFinishedForAllUsers{next}, notes}:
      CheckIfItemGrabbingFinishedForAllUsers(state, next)
    case RefState{host, GetSocketArrayToEndItemGrabbingOn{seat, slot}, notes}:
      GetSocketArrayToEndItemGrabbingOn(state, seat, slot)
    case RefState{host, EndItemGrabbingAfterNonEligible{seats, next}, notes}:
      EndItemGrabbingAfterNonEligible(state, seats, next)
    case RefState{host, ReceivePacket_PlaceItem{seat, slot}, notes}:
      ReceivePacket_PlaceItem(state, seat, slot)
    case RefState{host, ContinueItemGrabbing{}, notes}:
      ContinueItemGrabbing(state)
    case RefState{host, CheckIfEndingTurnAfterItemUse{seat, owner, slot, item}, notes}:
      CheckIfEndingTurnAfterItemUse(state, seat, owner, slot, item)
    case RefState{host, GetBurnerPhone_VerbalIndex{packet}, notes}:
      GetBurnerPhone_VerbalIndex(state, packet)
    case RefState{host, _GetBurnerPhone_Shell{packet, index}, notes}:
      _GetBurnerPhone_Shell(state, packet, index)
    case RefState{host, ReceivePacket_InteractWithItem{packet}, notes}:
      ReceivePacket_InteractWithItem(state, packet)
    case RefState{host, RemoveItemFromInventory{packet}, notes}:
      RemoveItemFromInventory(state, packet)
    case RefState{host, ChangeGameStateWithItem{packet}, notes}:
      ChangeGameStateWithItem(state, packet)
    case RefState{host, ShotgunBarrel_Remove{seat}, notes}:
      ShotgunBarrel_Remove(state, seat)
    case RefState{host, BeginItemStealing{seat}, notes}:
      BeginItemStealing(state, seat)
    case RefState{host, ReceivePacket_InteractWithItem_Secondary{seat, target}, notes}:
      ReceivePacket_InteractWithItem_Secondary(state, seat, target)
    case RefState{host, Jammer_Enable{seat, target}, notes}:
      Jammer_Enable(state, seat, target)
    case RefState{host, EndItemInteraction{seat, ending}, notes}:
      EndItemInteraction(state, seat, ending)
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
  stepped(settle(96n, RefState{S.host.initial(config), MainRoutine_StartRound{BeginRound{}}, Nil{}}))

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
