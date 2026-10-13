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
import ./grab-proof.bend as GP
import ./item-step-proof.bend as ISP

# L11: the load closure from an item state (M.load.begin against the
# reference's MainRoutine_LoadShotgun), and its end state is valid.

# LoadValid: the load closure ends at a valid request point. VPre is the
# part of Pre the load reads: Shape and the round bound. The load writes the
# world but never its config or round index.

def VPre(+s: S.State) -> Data:
  Sigma<&2, &2, A.Shape(s), _ => A.Holds(A.bounded(s))>

def seat.refl(+seat: D.Seat) -> {D.seat.eq(seat, seat) == True{} : Bool}:
  match seat:
    case D.Seat0{}:
      {==}
    case D.Seat1{}:
      {==}
    case D.Seat2{}:
      {==}
    case D.Seat3{}:
      {==}

def vpre.phase(+s: S.State, +phase2: S.Phase, +notes2: A.Notes(), +vpre: VPre(s)) -> VPre(S.State{S.state.world(s), S.state.players(s), phase2, notes2, S.state.grabs(s)}):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match vpre:
        case Tuple{+shape, +bounded}:
          (ISP.shape.move(world, players, phase, notes, grabs, phase2, notes2, shape), bounded)

def vpre.jam(+s: S.State, +seat: D.Seat, +jam: S.Jam, +vpre: VPre(s)) -> VPre(S.state.set_players(s, S.players.set_jam(S.state.players(s), seat, jam))):
  match s:
    case S.State{+world, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match vpre:
        case Tuple{Tuple{+e_players, +rest}, +bounded}:
          +written : S.Seat = S.seat.set_jam(S.players.seat(players, seat), jam)
          ((Equal.trans(D.Table, D.ring.table(S.Seat, D.ring.set(S.Seat, players, seat, written)), D.ring.table(S.Seat, players), S.world.table(world), GP.set_table(S.Seat, players, seat, written), e_players), rest), bounded)

def valid.blocked(+s: S.State, +vpre: VPre(s)) -> A.ValidItems(S.state.set_phase(s, S.Blocked{None{}})):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match vpre:
        case Tuple{+shape, +bounded}:
          ({==}, (ISP.shape.move(world, players, phase, notes, grabs, S.Blocked{None{}}, notes, shape), (bounded, {==})))

def valid.give(+s: S.State, +seat: D.Seat, +vpre: VPre(s), +turn: {S.world.turn(S.state.world(s)) == Some{seat} : Maybe<&2, D.Seat>}) -> A.ValidItems(M.give_turn(s, seat)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match vpre:
        case Tuple{+shape, +bounded}:
          +ready : {R.current.eq(S.world.turn(world), seat) == True{} : Bool} = Equal.trans(Bool, R.current.eq(S.world.turn(world), seat), R.current.eq(Some{seat}, seat), True{}, Equal.cong(Maybe<&2, D.Seat>, Bool, t => R.current.eq(t, seat), S.world.turn(world), Some{seat}, turn), seat.refl(seat))
          ({==}, (ISP.shape.move(world, players, phase, notes, grabs, S.Idle{seat, D.NonEmpty{S.TakeGun{}, I.uses(S.State{world, players, phase, notes, grabs}, seat)}}, List.append(&2, D.Note, notes, [D.Shown{D.TurnGiven{seat}}]), shape), (bounded, ready)))

def valid.step(+rank: Nat, +jam: S.Jam, +s: S.State, +seat: D.Seat, +vpre: VPre(s), +turned_to: {S.world.turn(S.state.world(s)) == Some{seat} : Maybe<&2, D.Seat>}) -> A.ValidItems(M.grant.step(rank, s, seat, Q.jam.state(S.state.players(s), seat, jam))):
  match rank jam:
    case rank S.Free{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          valid.give(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, seat, vpre, turned_to)
    case rank S.JammedSkipped{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          +lifted : S.State = S.state.set_players(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.players.set_jam(players, seat, S.Free{}))
          valid.give(S.state.emit(lifted, D.JamLifted{seat}), seat, vpre.phase(lifted, phase, List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}]), vpre.jam(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, seat, S.Free{}, vpre)), turned_to)
    case 0n S.Jammed{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          valid.blocked(S.state.set_players(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.players.set_jam(players, seat, S.JammedSkipped{})), vpre.jam(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, seat, S.JammedSkipped{}, vpre))
    case 1n+rest S.Jammed{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
          +skipped : S.Players = S.players.set_jam(players, seat, S.JammedSkipped{})
          +next : D.Seat = Q.next_turn(S.players.health(skipped), direction, seat)
          +moved : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, Some{next}, direction, died, checking, amount, saw, gun, shown, deck}, skipped, phase, List.append(&2, D.Note, notes, [D.Shown{D.TurnSkipped{seat}}]), S.Grabs{dist, g_taking, g_holding, g_granted, g_intake}}
          valid.step(rest, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(skipped), next), S.Free{}), moved, next, vpre.jam(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, g_taking, g_holding, g_granted, g_intake}}, seat, S.JammedSkipped{}, vpre), {==})

def valid.grant(+s: S.State, +seat: D.Seat, +vpre: VPre(s)) -> A.ValidItems(M.grant(s, seat)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
      +turned : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, Some{seat}, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, g_taking, g_holding, g_granted, g_intake}}
      valid.step(Q.jam_rank(players), Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(players), seat), S.Free{}), turned, seat, vpre, {==})

def valid.shuffle(+i: Nat, +s: S.State, +ld: D.Load, +sh: List<&2, D.Shell>, +vpre: VPre(s)) -> A.ValidItems(M.shuffle(s, ld, sh, i)):
  match i:
    case 0n:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
          +loaded : S.State = S.state.emit(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, g_taking, g_holding, g_granted, g_intake}}, S.world.set_shown(S.world.set_gun(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, sh), ld)), D.Loaded{ld})
          valid.grant(loaded, recipient, vpre)
    case 1n+rest:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              ({==}, (shape, (bounded, {==})))

def valid.found(+selected: Maybe<&2, S.Batch>, +s: S.State, +index: Nat, +vpre: VPre(s)) -> A.ValidItems(M.batch.found(s, index, selected)):
  match selected:
    case None{}:
      valid.blocked(s, vpre)
    case Some{S.Batch{id, +sampled}}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
          +ld : D.Load = Q.load.actual(Q.world.load_rule(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}), sampled)
          +sh : List<&2, D.Shell> = Q.load.shells(ld)
          +removed : S.State = S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, g_taking, g_holding, g_granted, g_intake}}, S.world.set_deck(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.remove(S.Batch, S.world.deck(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}), index)))
          valid.shuffle(Q.predecessor(List.length(&2, D.Shell, sh)), removed, ld, sh, vpre)

def valid.ready(+cards: List<&2, S.Batch>, +s: S.State, +vpre: VPre(s)) -> A.ValidItems(M.load.ready(s, cards)):
  match cards:
    case Nil{}:
      valid.blocked(s, vpre)
    case only <> Nil{}:
      valid.found(Q.nth(S.Batch, S.world.deck(S.state.world(s)), 0n), s, 0n, vpre)
    case a <> b <> rest:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
          match vpre:
            case Tuple{+shape, +bounded}:
              ({==}, (shape, (bounded, {==})))

def valid.refill(+cards: List<&2, S.Batch>, +s: S.State, +vpre: VPre(s)) -> A.ValidItems(M.load.refill(s, cards)):
  match cards:
    case Nil{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
          +full : S.World = S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())
          valid.ready(S.world.deck(full), S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, g_taking, g_holding, g_granted, g_intake}}, full), vpre)
    case +a <> +rest:
      valid.ready(a <> rest, s, vpre)

def valid.load(+s: S.State, +pre: ISP.Pre(s)) -> A.ValidItems(M.load.begin(s)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
      match pre:
        case Tuple{Tuple{+shape, _}, +bounded}:
          +world : S.World = S.world.set_first_sequence(S.world.set_load_index(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.load.next(first, load)), False{})
          valid.refill(S.world.deck(world), S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, g_taking, g_holding, g_granted, g_intake}}, world), (shape, bounded))

def load.valid() -> ISP.LoadValid():
  +s => +pre => valid.load(s, pre)
