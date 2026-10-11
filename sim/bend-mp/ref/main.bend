import Base
import ../domain.bend as D
import ./state.bend as S
import ./rules.bend as G
import ./snapshot.bend as T

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

type Continuation is Data:
  FirstSeatResult{}
  StartingHealthResult{}
  ItemAmountResult{next: Frame}
  SequenceBatchResult{}
  ShuffleSwapResult{load: D.Load, shells: List<&2, D.Shell>, i: Nat}
  PlayerMove{mode: D.Mode}
  ItemGrab_Packet{}

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

def grab_menus(+entries: List<&2, D.At<&2, S.Props>>, +menus: D.Ring<&2, List<&2, D.Move>>) -> D.Ring<&2, List<&2, D.Move>>:
  match entries:
    case Nil{}:
      menus
    case D.At{seat, S.Props{_, _, _, _, _, True{}, _, _}} <> rest:
      grab_menus(rest, D.ring.set(List<&2, D.Move>, menus, seat, [D.Grab{}]))
    case D.At{seat, _} <> rest:
      grab_menus(rest, menus)

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
    case D.Idle{} D.PickUp{}:
      True{}
    case D.Aiming{} D.Shoot{target}:
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
      h : S.Host = S.host.set_round_index(h, G.next_round(S.host.before_round(h), S.host.round_index(h)))
      h : S.Host = S.host.set_before_round(h, False{})
      h : S.Host = S.host.set_first_turn(h, seat)
      h : S.Host = S.host.set_first_sequence(h, True{})
      frame(with_host(state, h), GenerateRandomRound{})

# Install the packet's first-death checking and CW writes before nested
# unjam/health/clear calls. Cosmetic revival and indicators are omitted.
def PacketSort_StartRound(+state: RefState) -> RefState:
  h : S.Host = S.host.set_checking_first_death(host(state), True{})
  h : S.Host = S.host.set_direction(h, D.Clockwise{})
  frame(with_host(state, h), UnJamAllUsers{})

# Phase 5 fills ItemGrab_Packet. Nonempty pools expose their true grab flags
# and Grab request rather than silently pretending distribution completed.
def BeginItemGrabbingForSockets(+state: RefState, +seats: List<&2, D.Seat>) -> RefState:
  match seats:
    case Nil{}:
      frame(state, MainRoutine_LoadShotgun{})
    case +seat <> +rest:
      +h : S.Host = S.host.set_distributing(G.begin_grab(seat <> rest, host(state)), True{})
      state : RefState = emit(with_host(state, h), D.GrabbingBegan{seat <> rest})
      frame(state, Await{D.request.choose(grab_menus(D.ring.entries(S.Props, S.host.seats(h)), D.ring.fill(List<&2, D.Move>, S.host.table(h), Nil{}))), D.Distributing{}, ItemGrab_Packet{}})

def MainRoutine_LoadShotgun(+state: RefState) -> RefState:
  +h : S.Host = host(state)
  h : S.Host = S.host.set_load_index(h, IncrementActiveSequenceIndex(S.host.first_sequence(h), S.host.load_index(h)))
  h : S.Host = S.host.set_first_sequence(h, False{})
  frame(with_host(state, h), GenerateRandomSequence{SelectBatch{}})

def LoadShotgun(+state: RefState) -> RefState:
  frame(emit(state, D.Loaded{S.host.shown(host(state))}), PassTurn{S.host.first_turn(host(state))})

def PassTurn.props(+state: RefState, +seat: D.Seat, +props: S.Props) -> RefState:
  match props:
    case S.Props{hp, True{}, False{}, cash, slots, grab, holding, turn}:
      +h : S.Host = S.host.set_props(host(state), seat, S.Props{hp, True{}, True{}, cash, slots, grab, holding, turn})
      frame(emit(with_host(state, h), D.TurnSkipped{seat}), PassTurn{G.GetNextTurn_Socket(h, seat)})
    case S.Props{hp, True{}, True{}, cash, slots, grab, holding, turn}:
      h : S.Host = S.host.set_props(host(state), seat, S.Props{hp, False{}, True{}, cash, slots, grab, holding, turn})
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
      h : S.Host = S.host.set_props(h, target, S.props.set_health(S.host.props(h, target), hp))
      state : RefState = emit(with_host(state, h), D.Fired{shooter, target, shell, damage, G.subtract(old, hp), hp})
      frame(state, DeathRequest{shot})

def DeathRequest.first(+state: RefState, +seat: D.Seat, +checking: Bool) -> RefState:
  match checking:
    case True{}:
      h : S.Host = S.host.set_first_death(host(state), Some{seat})
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
  h : S.Host = S.host.set_props(host(state), seat, S.props.award(S.host.props(host(state), seat), prize))
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

# D32 core guards. Holding is the idle/aiming continuation, not a second flag.
# Target health is a D37 menu filter and is absent from this host predicate.
def VerifyPacket(+state: RefState, +choice: D.Choice) -> Bool:
  match state choice:
    case RefState{+h, Await{request, stage, PlayerMove{mode}}, notes} D.Choice{+seat, index, move}:
      Bool.and(current.eq(S.host.turn(h), seat), Bool.and(props.has_turn(S.host.props(h, seat)), VerifyPacket.mode(mode, move)))
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
  h : S.Host = S.host.set_seats(h, G.round_seats(D.ring.entries(S.Props, S.host.seats(h)), write, S.host.seats(h)))
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
      h : S.Host = S.host.set_deck(h, G.remove(S.Batch, S.host.deck(h), index))
      frame(with_host(state, h), GenerateRandomSequence{Shuffle{load, shells, G.subtract(List.length(&2, D.Shell, shells), 1n)}})

def PassTurn(+state: RefState, +seat: D.Seat) -> RefState:
  +h : S.Host = S.host.set_turn(host(state), Some{seat})
  PassTurn.props(with_host(state, h), seat, S.host.props(h, seat))

def GiveTurnPermissions(+state: RefState, +seat: D.Seat) -> RefState:
  h : S.Host = S.host.set_props(host(state), seat, S.props.set_turn(S.host.props(host(state), seat), True{}))
  idle(emit(with_host(state, h), D.TurnGiven{seat}), seat, D.Idle{}, [D.PickUp{}])

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

def answer.draw(+state: RefState, +value: Nat, +continuation: Continuation) -> RefState:
  match continuation:
    case FirstSeatResult{}:
      frame(state, MainRoutine_StartRound{FirstChosen{G.seat.default(G.nth(D.Seat, D.table.seats(S.host.table(host(state))), value))}})
    case StartingHealthResult{}:
      frame(with_host(state, S.host.set_round_health(host(state), value)), GetRandomItemGrabAmount{PacketSort_StartRound{}})
    case ItemAmountResult{next}:
      frame(with_host(state, S.host.set_item_amount(host(state), value)), next)
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
      h : S.Host = S.host.set_props(h, shooter, S.props.set_turn(S.host.props(h, shooter), False{}))
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

# M3 moves only new-round selection after scheduled slot/count clearing.
# Phase 5 adds source-conditional count resets at this function.
def ClearUserInventories(+state: RefState) -> RefState:
  +cleared : RefState = round_write(state, G.ClearSlots{}, MainRoutine_LoadShotgun{})
  +h : S.Host = host(cleared)
  frame(cleared, BeginItemGrabbingForSockets{G.GetSocketsToBeginItemGrabbingOn(h, True{}, S.host.item_amount(h))})

def RemoveFirstShellFromSequence(+state: RefState, +shot: Shot) -> RefState:
  h : S.Host = S.host.set_gun(host(state), gun.tail(S.host.gun(host(state))))
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
    case _:
      stuck(state)

def answer.resolved(+state: RefState, +continuation: Continuation, +resolved: D.Resolved) -> RefState:
  match continuation resolved:
    case continuation D.Drawn{value}:
      answer.draw(state, value, continuation)
    case PlayerMove{mode} D.Chose{choice}:
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
      h : S.Host = S.host.set_gun(host(state), shells)
      h : S.Host = S.host.set_shown(h, load)
      frame(with_host(state, h), LoadShotgun{})
    case Shuffle{load, shells, 1n+i}:
      await_draw(state, D.ShuffleSwap{}, D.Range{0n, i}, D.Loading{}, ShuffleSwapResult{load, shells, 1n+i})

# Public API. Point excludes the private chamber order and resource deck.
def point(+state: RefState) -> D.Point:
  D.Point{request(state), board(state)}

def PacketSort_Verification(+state: RefState, +choice: D.Choice) -> RefState:
  PacketSort_Verification.choice(state, choice)

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
