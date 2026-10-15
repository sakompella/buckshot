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
import ./core-proof.bend as C
import ./grab-proof.bend as GP
import ./ref/items.bend as RI
import ./grant-proof.bend as GrantProof
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

def valid.blocked(+s: S.State, +vpre: VPre(s)) -> A.Valid(S.state.set_phase(s, S.Blocked{None{}})):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match vpre:
        case Tuple{+shape, +bounded}:
          ({==}, (ISP.shape.move(world, players, phase, notes, grabs, S.Blocked{None{}}, notes, shape), (bounded, {==})))

def valid.give(+s: S.State, +seat: D.Seat, +vpre: VPre(s), +turn: {S.world.turn(S.state.world(s)) == Some{seat} : Maybe<&2, D.Seat>}) -> A.Valid(M.give_turn(s, seat)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match vpre:
        case Tuple{+shape, +bounded}:
          +ready : {R.current.eq(S.world.turn(world), seat) == True{} : Bool} = Equal.trans(Bool, R.current.eq(S.world.turn(world), seat), R.current.eq(Some{seat}, seat), True{}, Equal.cong(Maybe<&2, D.Seat>, Bool, t => R.current.eq(t, seat), S.world.turn(world), Some{seat}, turn), seat.refl(seat))
          ({==}, (ISP.shape.move(world, players, phase, notes, grabs, S.Idle{seat, D.NonEmpty{S.TakeGun{}, I.uses(S.State{world, players, phase, notes, grabs}, seat)}}, List.append(&2, D.Note, notes, [D.Shown{D.TurnGiven{seat}}]), shape), (bounded, ready)))

def valid.step(+rank: Nat, +jam: S.Jam, +s: S.State, +seat: D.Seat, +vpre: VPre(s), +turned_to: {S.world.turn(S.state.world(s)) == Some{seat} : Maybe<&2, D.Seat>}) -> A.Valid(M.grant.step(rank, s, seat, Q.jam.state(S.state.players(s), seat, jam))):
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

def valid.grant(+s: S.State, +seat: D.Seat, +vpre: VPre(s)) -> A.Valid(M.grant(s, seat)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
      +turned : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, Some{seat}, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, g_taking, g_holding, g_granted, g_intake}}
      valid.step(Q.jam_rank(players), Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(players), seat), S.Free{}), turned, seat, vpre, {==})

def valid.shuffle(+i: Nat, +s: S.State, +ld: D.Load, +sh: List<&2, D.Shell>, +vpre: VPre(s)) -> A.Valid(M.shuffle(s, ld, sh, i)):
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

def valid.found(+selected: Maybe<&2, S.Batch>, +s: S.State, +index: Nat, +vpre: VPre(s)) -> A.Valid(M.batch.found(s, index, selected)):
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

def valid.ready(+cards: List<&2, S.Batch>, +s: S.State, +vpre: VPre(s)) -> A.Valid(M.load.ready(s, cards)):
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

def valid.refill(+cards: List<&2, S.Batch>, +s: S.State, +vpre: VPre(s)) -> A.Valid(M.load.refill(s, cards)):
  match cards:
    case Nil{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
          +full : S.World = S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())
          valid.ready(S.world.deck(full), S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, g_taking, g_holding, g_granted, g_intake}}, full), vpre)
    case +a <> +rest:
      valid.ready(a <> rest, s, vpre)

def valid.load(+s: S.State, +pre: ISP.Pre(s)) -> A.Valid(M.load.begin(s)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +g_taking, +g_holding, +g_granted, +g_intake}}:
      match pre:
        case Tuple{Tuple{+shape, _}, +bounded}:
          +world : S.World = S.world.set_first_sequence(S.world.set_load_index(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.load.next(first, load)), False{})
          valid.refill(S.world.deck(world), S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, g_taking, g_holding, g_granted, g_intake}}, world), (shape, bounded))

def load.valid() -> ISP.LoadValid():
  +s => +pre => valid.load(s, pre)

# The Idle item menu (R.idle_items) against the machine's options
# (I.uses): jam targets, steal options, then the per-slot use check.

def alive.eq(+hp: Nat) -> {G.alive(hp) == Q.alive(hp) : Bool}:
  match hp:
    case 0n:
      {==}
    case 1n+k:
      {==}

def not.not(+b: Bool) -> {Bool.not(Bool.not(b)) == b : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def jam.cell(+b: Bool, +seat: D.Seat, +rest_r: List<&2, D.Seat>, +rest_m: List<&2, S.JamOption>, +ih: {RI.jam_moves(rest_r) == I.jam.moves(rest_m) : List<&2, D.Move>}) -> {RI.jam_moves(G.turn_ring.put(b, seat, rest_r)) == I.jam.moves(I.keep(S.JamOption, b, S.JamAt{seat}, rest_m)) : List<&2, D.Move>}:
  match b:
    case True{}:
      Equal.cong(List<&2, D.Move>, List<&2, D.Move>, xs => D.JamTarget{seat} <> xs, RI.jam_moves(rest_r), I.jam.moves(rest_m), ih)
    case False{}:
      ih

def jam.seats(+seats: List<&2, D.Seat>, +s: S.State, +by: D.Seat) -> {RI.jam_moves(RI.jam_targets(GP.lens.entries(seats, s), by)) == I.jam.moves(I.jam.options(ISP.health.lens(seats, s), S.state.players(s), by)) : List<&2, D.Move>}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> +rest:
      +hp : Nat = I.seat.health(S.state.players(s), seat)
      +other : Bool = Bool.not(D.seat.eq(seat, by))
      +free : Bool = Bool.not(I.seat.jammed(S.state.players(s), seat))
      +rest_r : List<&2, D.Seat> = RI.jam_targets(GP.lens.entries(rest, s), by)
      +alive : {RI.jam_moves(G.turn_ring.put(Bool.and(other, Bool.and(G.alive(hp), free)), seat, rest_r)) == RI.jam_moves(G.turn_ring.put(Bool.and(other, Bool.and(Q.alive(hp), free)), seat, rest_r)) : List<&2, D.Move>} = Equal.cong(Bool, List<&2, D.Move>, a => RI.jam_moves(G.turn_ring.put(Bool.and(other, Bool.and(a, free)), seat, rest_r)), G.alive(hp), Q.alive(hp), alive.eq(hp))
      Equal.trans(List<&2, D.Move>, RI.jam_moves(G.turn_ring.put(Bool.and(other, Bool.and(G.alive(hp), free)), seat, rest_r)), RI.jam_moves(G.turn_ring.put(Bool.and(other, Bool.and(Q.alive(hp), free)), seat, rest_r)), I.jam.moves(I.jam.options(ISP.health.lens(seat <> rest, s), S.state.players(s), by)), alive, jam.cell(Bool.and(other, Bool.and(Q.alive(hp), free)), seat, rest_r, I.jam.options(ISP.health.lens(rest, s), S.state.players(s), by), jam.seats(rest, s, by)))

def jam.eq(+s: S.State, +by: D.Seat, +shape: A.Shape(s)) -> {RI.jam_moves(RI.jam_targets(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), by)) == I.jam.moves(I.jam.for(s, by)) : List<&2, D.Move>}:
  +seats : List<&2, D.Seat> = D.table.seats(S.world.table(S.state.world(s)))
  +lensed : {RI.jam_moves(RI.jam_targets(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), by)) == RI.jam_moves(RI.jam_targets(GP.lens.entries(seats, s), by)) : List<&2, D.Move>} = Equal.cong(List<&2, D.At<&2, H.Props>>, List<&2, D.Move>, xs => RI.jam_moves(RI.jam_targets(xs, by)), D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), GP.lens.entries(seats, s), Equal.sym(List<&2, D.At<&2, H.Props>>, GP.lens.entries(seats, s), D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), GP.entries.eq(s, shape)))
  +healths : {I.jam.moves(I.jam.options(ISP.health.lens(seats, s), S.state.players(s), by)) == I.jam.moves(I.jam.for(s, by)) : List<&2, D.Move>} = Equal.cong(List<&2, D.At<&2, Nat>>, List<&2, D.Move>, xs => I.jam.moves(I.jam.options(xs, S.state.players(s), by)), ISP.health.lens(seats, s), D.ring.entries(Nat, S.players.health(S.state.players(s))), Equal.sym(List<&2, D.At<&2, Nat>>, D.ring.entries(Nat, S.players.health(S.state.players(s))), ISP.health.lens(seats, s), ISP.health.eq(s, shape)))
  Equal.trans(List<&2, D.Move>, RI.jam_moves(RI.jam_targets(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), by)), RI.jam_moves(RI.jam_targets(GP.lens.entries(seats, s), by)), I.jam.moves(I.jam.for(s, by)), lensed, Equal.trans(List<&2, D.Move>, RI.jam_moves(RI.jam_targets(GP.lens.entries(seats, s), by)), I.jam.moves(I.jam.options(ISP.health.lens(seats, s), S.state.players(s), by)), I.jam.moves(I.jam.for(s, by)), jam.seats(seats, s, by), healths))

def targets.nonempty(+ts: List<&2, D.Seat>) -> {G.nonempty(D.Seat, ts) == G.nonempty(D.Move, RI.jam_moves(ts)) : Bool}:
  match ts:
    case Nil{}:
      {==}
    case t <> rest:
      {==}

def options.any(+opts: List<&2, S.JamOption>) -> {G.nonempty(D.Move, I.jam.moves(opts)) == I.jam.any(opts) : Bool}:
  match opts:
    case Nil{}:
      {==}
    case S.JamAt{t} <> rest:
      {==}

def targets.eq(+s: S.State, +by: D.Seat, +shape: A.Shape(s)) -> {RI.CheckIfJammerHasEligibleTargets(A.ref_host(s), by) == I.jam.any(I.jam.for(s, by)) : Bool}:
  +ts : List<&2, D.Seat> = RI.jam_targets(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), by)
  Equal.trans(Bool, G.nonempty(D.Seat, ts), G.nonempty(D.Move, RI.jam_moves(ts)), I.jam.any(I.jam.for(s, by)), targets.nonempty(ts), Equal.trans(Bool, G.nonempty(D.Move, RI.jam_moves(ts)), G.nonempty(D.Move, I.jam.moves(I.jam.for(s, by))), I.jam.any(I.jam.for(s, by)), Equal.cong(List<&2, D.Move>, Bool, xs => G.nonempty(D.Move, xs), RI.jam_moves(ts), I.jam.moves(I.jam.for(s, by)), jam.eq(s, by, shape)), options.any(I.jam.for(s, by))))

def sawed.eq(+s: S.State) -> {H.host.sawed(A.ref_host(s)) == S.world.sawed(S.state.world(s)) : Bool}:
  match s:
    case S.State{S.World{config, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}:
      {==}

def fits.eq(+h: H.Host, +thief: D.Seat, +item: D.Item, +sawed: Bool, +targets: Bool, +e_saw: {H.host.sawed(h) == sawed : Bool}, +e_targets: {RI.CheckIfJammerHasEligibleTargets(h, thief) == targets : Bool}) -> {RI.valid_steal(h, thief, item) == I.steal.fits(item, sawed, targets) : Bool}:
  match item:
    case D.Adrenaline{}:
      {==}
    case D.Saw{}:
      Equal.cong(Bool, Bool, b => Bool.not(b), H.host.sawed(h), sawed, e_saw)
    case D.Jammer{}:
      e_targets
    case D.Glass{}:
      {==}
    case D.Cigarettes{}:
      {==}
    case D.Beer{}:
      {==}
    case D.Phone{}:
      {==}
    case D.Inverter{}:
      {==}
    case D.Remote{}:
      {==}

def steal.keep(+b: Bool, +owner: D.Seat, +slot: D.Slot, +item: D.Item, +rest_r: List<&2, D.Move>, +rest_m: List<&2, S.StealOption>, +ih: {rest_r == I.steal.moves(rest_m) : List<&2, D.Move>}) -> {RI.use_moves.put(b, D.Steal{owner, slot, item}, rest_r) == I.steal.moves(I.keep(S.StealOption, b, S.Pick{owner, slot, item}, rest_m)) : List<&2, D.Move>}:
  match b:
    case True{}:
      Equal.cong(List<&2, D.Move>, List<&2, D.Move>, xs => D.Steal{owner, slot, item} <> xs, rest_r, I.steal.moves(rest_m), ih)
    case False{}:
      ih

def steal.cell(+found: Maybe<&2, D.Item>, +h: H.Host, +thief: D.Seat, +owner: D.Seat, +slot: D.Slot, +sawed: Bool, +targets: Bool, +rest_r: List<&2, D.Move>, +rest_m: List<&2, S.StealOption>, +ih: {rest_r == I.steal.moves(rest_m) : List<&2, D.Move>}, +e_saw: {H.host.sawed(h) == sawed : Bool}, +e_targets: {RI.CheckIfJammerHasEligibleTargets(h, thief) == targets : Bool}) -> {RI.steal_slots.here(found, h, thief, owner, slot, rest_r) == I.steal.moves(I.steal.here(found, owner, slot, sawed, targets, rest_m)) : List<&2, D.Move>}:
  match found:
    case None{}:
      ih
    case Some{+item}:
      +fits : {RI.use_moves.put(RI.valid_steal(h, thief, item), D.Steal{owner, slot, item}, rest_r) == RI.use_moves.put(I.steal.fits(item, sawed, targets), D.Steal{owner, slot, item}, rest_r) : List<&2, D.Move>} = Equal.cong(Bool, List<&2, D.Move>, b => RI.use_moves.put(b, D.Steal{owner, slot, item}, rest_r), RI.valid_steal(h, thief, item), I.steal.fits(item, sawed, targets), fits.eq(h, thief, item, sawed, targets, e_saw, e_targets))
      Equal.trans(List<&2, D.Move>, RI.use_moves.put(RI.valid_steal(h, thief, item), D.Steal{owner, slot, item}, rest_r), RI.use_moves.put(I.steal.fits(item, sawed, targets), D.Steal{owner, slot, item}, rest_r), I.steal.moves(I.steal.here(Some{item}, owner, slot, sawed, targets, rest_m)), fits, steal.keep(I.steal.fits(item, sawed, targets), owner, slot, item, rest_r, rest_m, ih))

def steal.slots.eq(+slots: List<&2, D.Slot>, +h: H.Host, +thief: D.Seat, +owner: D.Seat, +inv: D.Slots, +sawed: Bool, +targets: Bool, +e_inv: {RI.props.slots(H.host.props(h, owner)) == inv : D.Slots}, +e_saw: {H.host.sawed(h) == sawed : Bool}, +e_targets: {RI.CheckIfJammerHasEligibleTargets(h, thief) == targets : Bool}) -> {RI.steal_slots(slots, h, thief, owner) == I.steal.moves(I.steal.slots(slots, inv, owner, sawed, targets)) : List<&2, D.Move>}:
  match slots:
    case Nil{}:
      {==}
    case +slot <> +rest:
      +rest_r : List<&2, D.Move> = RI.steal_slots(rest, h, thief, owner)
      +read : {RI.steal_slots.here(D.slots.get(RI.props.slots(H.host.props(h, owner)), slot), h, thief, owner, slot, rest_r) == RI.steal_slots.here(D.slots.get(inv, slot), h, thief, owner, slot, rest_r) : List<&2, D.Move>} = Equal.cong(D.Slots, List<&2, D.Move>, sl => RI.steal_slots.here(D.slots.get(sl, slot), h, thief, owner, slot, rest_r), RI.props.slots(H.host.props(h, owner)), inv, e_inv)
      Equal.trans(List<&2, D.Move>, RI.steal_slots.here(D.slots.get(RI.props.slots(H.host.props(h, owner)), slot), h, thief, owner, slot, rest_r), RI.steal_slots.here(D.slots.get(inv, slot), h, thief, owner, slot, rest_r), I.steal.moves(I.steal.slots(slot <> rest, inv, owner, sawed, targets)), read, steal.cell(D.slots.get(inv, slot), h, thief, owner, slot, sawed, targets, rest_r, I.steal.slots(rest, inv, owner, sawed, targets), steal.slots.eq(rest, h, thief, owner, inv, sawed, targets, e_inv, e_saw, e_targets), e_saw, e_targets))

def moves.append(+xs: List<&2, S.StealOption>, +ys: List<&2, S.StealOption>) -> {List.append(&2, D.Move, I.steal.moves(xs), I.steal.moves(ys)) == I.steal.moves(List.append(&2, S.StealOption, xs, ys)) : List<&2, D.Move>}:
  match xs:
    case Nil{}:
      {==}
    case S.Pick{owner, slot, item} <> +rest:
      Equal.cong(List<&2, D.Move>, List<&2, D.Move>, zs => D.Steal{owner, slot, item} <> zs, List.append(&2, D.Move, I.steal.moves(rest), I.steal.moves(ys)), I.steal.moves(List.append(&2, S.StealOption, rest, ys)), moves.append(rest, ys))

def slots.lens(seats: List<&2, D.Seat>, +s: S.State) -> List<&2, D.At<&2, D.Slots>>:
  match seats:
    case Nil{}:
      Nil{}
    case +seat <> rest:
      D.At{seat, I.seat.slots(S.state.players(s), seat)} <> slots.lens(rest, s)

def inventory.claim(+s: S.State) -> Type:
  {D.ring.entries(D.Slots, S.players.slots(S.state.players(s))) == slots.lens(D.table.seats(S.world.table(S.state.world(s))), s) : List<&2, D.At<&2, D.Slots>>}

def inventory.eq(+s: S.State, +shape: A.Shape(s)) -> inventory.claim(s):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(inventory.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(inventory.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(inventory.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(inventory.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(inventory.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(inventory.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.three_four(e_players))

def owner.cell(+b: Bool, +owner: D.Seat, +h: H.Host, +thief: D.Seat, +inv: D.Slots, +sawed: Bool, +targets: Bool, +rest_r: List<&2, D.Move>, +rest_m: List<&2, S.StealOption>, +ih: {rest_r == I.steal.moves(rest_m) : List<&2, D.Move>}, +e_inv: {RI.props.slots(H.host.props(h, owner)) == inv : D.Slots}, +e_saw: {H.host.sawed(h) == sawed : Bool}, +e_targets: {RI.CheckIfJammerHasEligibleTargets(h, thief) == targets : Bool}) -> {RI.steal_moves.here(b, h, thief, owner, rest_r) == I.steal.moves(I.steal.owner(b, owner, inv, sawed, targets, rest_m)) : List<&2, D.Move>}:
  match b:
    case True{}:
      ih
    case False{}:
      +mine : List<&2, S.StealOption> = I.steal.slots(I.slot.order(), inv, owner, sawed, targets)
      +left : {List.append(&2, D.Move, RI.steal_slots(I.slot.order(), h, thief, owner), rest_r) == List.append(&2, D.Move, I.steal.moves(mine), rest_r) : List<&2, D.Move>} = Equal.cong(List<&2, D.Move>, List<&2, D.Move>, xs => List.append(&2, D.Move, xs, rest_r), RI.steal_slots(I.slot.order(), h, thief, owner), I.steal.moves(mine), steal.slots.eq(I.slot.order(), h, thief, owner, inv, sawed, targets, e_inv, e_saw, e_targets))
      +right : {List.append(&2, D.Move, I.steal.moves(mine), rest_r) == List.append(&2, D.Move, I.steal.moves(mine), I.steal.moves(rest_m)) : List<&2, D.Move>} = Equal.cong(List<&2, D.Move>, List<&2, D.Move>, ys => List.append(&2, D.Move, I.steal.moves(mine), ys), rest_r, I.steal.moves(rest_m), ih)
      Equal.trans(List<&2, D.Move>, List.append(&2, D.Move, RI.steal_slots(I.slot.order(), h, thief, owner), rest_r), List.append(&2, D.Move, I.steal.moves(mine), rest_r), I.steal.moves(List.append(&2, S.StealOption, mine, rest_m)), left, Equal.trans(List<&2, D.Move>, List.append(&2, D.Move, I.steal.moves(mine), rest_r), List.append(&2, D.Move, I.steal.moves(mine), I.steal.moves(rest_m)), I.steal.moves(List.append(&2, S.StealOption, mine, rest_m)), right, moves.append(mine, rest_m)))

def owners.seats(+seats: List<&2, D.Seat>, +s: S.State, +thief: D.Seat, +sawed: Bool, +targets: Bool, +shape: A.Shape(s), +e_saw: {H.host.sawed(A.ref_host(s)) == sawed : Bool}, +e_targets: {RI.CheckIfJammerHasEligibleTargets(A.ref_host(s), thief) == targets : Bool}) -> {RI.steal_moves(GP.lens.entries(seats, s), A.ref_host(s), thief) == I.steal.moves(I.steal.owners(slots.lens(seats, s), thief, sawed, targets)) : List<&2, D.Move>}:
  match seats:
    case Nil{}:
      {==}
    case +owner <> +rest:
      owner.cell(D.seat.eq(owner, thief), owner, A.ref_host(s), thief, I.seat.slots(S.state.players(s), owner), sawed, targets, RI.steal_moves(GP.lens.entries(rest, s), A.ref_host(s), thief), I.steal.owners(slots.lens(rest, s), thief, sawed, targets), owners.seats(rest, s, thief, sawed, targets, shape, e_saw, e_targets), GP.slots.eq(s, owner, shape), e_saw, e_targets)

def steal.eq(+s: S.State, +thief: D.Seat, +shape: A.Shape(s)) -> {RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), thief) == I.steal.moves(I.steal.for(s, thief)) : List<&2, D.Move>}:
  +seats : List<&2, D.Seat> = D.table.seats(S.world.table(S.state.world(s)))
  +sawed : Bool = S.world.sawed(S.state.world(s))
  +targets : Bool = I.jam.any(I.jam.for(s, thief))
  +lensed : {RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), thief) == RI.steal_moves(GP.lens.entries(seats, s), A.ref_host(s), thief) : List<&2, D.Move>} = Equal.cong(List<&2, D.At<&2, H.Props>>, List<&2, D.Move>, xs => RI.steal_moves(xs, A.ref_host(s), thief), D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), GP.lens.entries(seats, s), Equal.sym(List<&2, D.At<&2, H.Props>>, GP.lens.entries(seats, s), D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), GP.entries.eq(s, shape)))
  +slotted : {I.steal.moves(I.steal.owners(slots.lens(seats, s), thief, sawed, targets)) == I.steal.moves(I.steal.for(s, thief)) : List<&2, D.Move>} = Equal.cong(List<&2, D.At<&2, D.Slots>>, List<&2, D.Move>, xs => I.steal.moves(I.steal.owners(xs, thief, sawed, targets)), slots.lens(seats, s), D.ring.entries(D.Slots, S.players.slots(S.state.players(s))), Equal.sym(List<&2, D.At<&2, D.Slots>>, D.ring.entries(D.Slots, S.players.slots(S.state.players(s))), slots.lens(seats, s), inventory.eq(s, shape)))
  Equal.trans(List<&2, D.Move>, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), thief), RI.steal_moves(GP.lens.entries(seats, s), A.ref_host(s), thief), I.steal.moves(I.steal.for(s, thief)), lensed, Equal.trans(List<&2, D.Move>, RI.steal_moves(GP.lens.entries(seats, s), A.ref_host(s), thief), I.steal.moves(I.steal.owners(slots.lens(seats, s), thief, sawed, targets)), I.steal.moves(I.steal.for(s, thief)), owners.seats(seats, s, thief, sawed, targets, shape, sawed.eq(s), targets.eq(s, thief, shape)), slotted))

def picks.any(+opts: List<&2, S.StealOption>) -> {G.nonempty(D.Move, I.steal.moves(opts)) == I.steal.any(opts) : Bool}:
  match opts:
    case Nil{}:
      {==}
    case S.Pick{owner, slot, item} <> rest:
      {==}

def steals.eq(+s: S.State, +thief: D.Seat, +shape: A.Shape(s)) -> {G.nonempty(D.Move, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), thief)) == I.steal.any(I.steal.for(s, thief)) : Bool}:
  Equal.trans(Bool, G.nonempty(D.Move, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), thief)), G.nonempty(D.Move, I.steal.moves(I.steal.for(s, thief))), I.steal.any(I.steal.for(s, thief)), Equal.cong(List<&2, D.Move>, Bool, xs => G.nonempty(D.Move, xs), RI.steal_moves(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), A.ref_host(s), thief), I.steal.moves(I.steal.for(s, thief)), steal.eq(s, thief, shape)), picks.any(I.steal.for(s, thief)))

def use.fit(+h: H.Host, +seat: D.Seat, +item: D.Item, +sawed: Bool, +targets: Bool, +steals: Bool, +e_saw: {H.host.sawed(h) == sawed : Bool}, +e_targets: {RI.CheckIfJammerHasEligibleTargets(h, seat) == targets : Bool}, +e_steals: {G.nonempty(D.Move, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(h)), h, seat)) == steals : Bool}) -> {Bool.not(RI.GetPropertyInvalidItems(h, seat, item)) == I.use.fits(item, sawed, targets, steals) : Bool}:
  match item:
    case D.Adrenaline{}:
      Equal.trans(Bool, Bool.not(Bool.not(G.nonempty(D.Move, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(h)), h, seat)))), G.nonempty(D.Move, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(h)), h, seat)), steals, not.not(G.nonempty(D.Move, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(h)), h, seat))), e_steals)
    case D.Saw{}:
      Equal.trans(Bool, Bool.not(Bool.not(Bool.not(H.host.sawed(h)))), Bool.not(H.host.sawed(h)), Bool.not(sawed), not.not(Bool.not(H.host.sawed(h))), Equal.cong(Bool, Bool, b => Bool.not(b), H.host.sawed(h), sawed, e_saw))
    case D.Jammer{}:
      Equal.trans(Bool, Bool.not(Bool.not(RI.CheckIfJammerHasEligibleTargets(h, seat))), RI.CheckIfJammerHasEligibleTargets(h, seat), targets, not.not(RI.CheckIfJammerHasEligibleTargets(h, seat)), e_targets)
    case D.Glass{}:
      {==}
    case D.Cigarettes{}:
      {==}
    case D.Beer{}:
      {==}
    case D.Phone{}:
      {==}
    case D.Inverter{}:
      {==}
    case D.Remote{}:
      {==}

def use.keep(+b: Bool, +slot: D.Slot, +item: D.Item, +rest_r: List<&2, D.Move>, +rest_m: List<&2, S.IdleOption>, +ih: {rest_r == Q.idle.moves(rest_m) : List<&2, D.Move>}) -> {RI.use_moves.put(b, D.UseItem{slot, item}, rest_r) == Q.idle.moves(I.keep(S.IdleOption, b, S.UseAt{slot, item}, rest_m)) : List<&2, D.Move>}:
  match b:
    case True{}:
      Equal.cong(List<&2, D.Move>, List<&2, D.Move>, xs => D.UseItem{slot, item} <> xs, rest_r, Q.idle.moves(rest_m), ih)
    case False{}:
      ih

def use.cell(+found: Maybe<&2, D.Item>, +h: H.Host, +seat: D.Seat, +slot: D.Slot, +sawed: Bool, +targets: Bool, +steals: Bool, +rest_r: List<&2, D.Move>, +rest_m: List<&2, S.IdleOption>, +ih: {rest_r == Q.idle.moves(rest_m) : List<&2, D.Move>}, +e_saw: {H.host.sawed(h) == sawed : Bool}, +e_targets: {RI.CheckIfJammerHasEligibleTargets(h, seat) == targets : Bool}, +e_steals: {G.nonempty(D.Move, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(h)), h, seat)) == steals : Bool}) -> {RI.use_moves.here(found, h, seat, slot, rest_r) == Q.idle.moves(I.use.here(found, slot, sawed, targets, steals, rest_m)) : List<&2, D.Move>}:
  match found:
    case None{}:
      ih
    case Some{+item}:
      +fits : {RI.use_moves.put(Bool.not(RI.GetPropertyInvalidItems(h, seat, item)), D.UseItem{slot, item}, rest_r) == RI.use_moves.put(I.use.fits(item, sawed, targets, steals), D.UseItem{slot, item}, rest_r) : List<&2, D.Move>} = Equal.cong(Bool, List<&2, D.Move>, b => RI.use_moves.put(b, D.UseItem{slot, item}, rest_r), Bool.not(RI.GetPropertyInvalidItems(h, seat, item)), I.use.fits(item, sawed, targets, steals), use.fit(h, seat, item, sawed, targets, steals, e_saw, e_targets, e_steals))
      Equal.trans(List<&2, D.Move>, RI.use_moves.put(Bool.not(RI.GetPropertyInvalidItems(h, seat, item)), D.UseItem{slot, item}, rest_r), RI.use_moves.put(I.use.fits(item, sawed, targets, steals), D.UseItem{slot, item}, rest_r), Q.idle.moves(I.use.here(Some{item}, slot, sawed, targets, steals, rest_m)), fits, use.keep(I.use.fits(item, sawed, targets, steals), slot, item, rest_r, rest_m, ih))

def use.slots.eq(+slots: List<&2, D.Slot>, +h: H.Host, +seat: D.Seat, +inv: D.Slots, +sawed: Bool, +targets: Bool, +steals: Bool, +e_inv: {RI.props.slots(H.host.props(h, seat)) == inv : D.Slots}, +e_saw: {H.host.sawed(h) == sawed : Bool}, +e_targets: {RI.CheckIfJammerHasEligibleTargets(h, seat) == targets : Bool}, +e_steals: {G.nonempty(D.Move, RI.steal_moves(D.ring.entries(H.Props, H.host.seats(h)), h, seat)) == steals : Bool}) -> {RI.use_moves(slots, h, seat) == Q.idle.moves(I.use.slots(slots, inv, sawed, targets, steals)) : List<&2, D.Move>}:
  match slots:
    case Nil{}:
      {==}
    case +slot <> +rest:
      +rest_r : List<&2, D.Move> = RI.use_moves(rest, h, seat)
      +read : {RI.use_moves.here(D.slots.get(RI.props.slots(H.host.props(h, seat)), slot), h, seat, slot, rest_r) == RI.use_moves.here(D.slots.get(inv, slot), h, seat, slot, rest_r) : List<&2, D.Move>} = Equal.cong(D.Slots, List<&2, D.Move>, sl => RI.use_moves.here(D.slots.get(sl, slot), h, seat, slot, rest_r), RI.props.slots(H.host.props(h, seat)), inv, e_inv)
      Equal.trans(List<&2, D.Move>, RI.use_moves.here(D.slots.get(RI.props.slots(H.host.props(h, seat)), slot), h, seat, slot, rest_r), RI.use_moves.here(D.slots.get(inv, slot), h, seat, slot, rest_r), Q.idle.moves(I.use.slots(slot <> rest, inv, sawed, targets, steals)), read, use.cell(D.slots.get(inv, slot), h, seat, slot, sawed, targets, steals, rest_r, I.use.slots(rest, inv, sawed, targets, steals), use.slots.eq(rest, h, seat, inv, sawed, targets, steals, e_inv, e_saw, e_targets, e_steals), e_saw, e_targets, e_steals))

# The Idle item menu: the reference renders exactly the machine's options.
def uses.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> {RI.use_moves(I.slot.order(), A.ref_host(s), seat) == Q.idle.moves(I.uses(s, seat)) : List<&2, D.Move>}:
  use.slots.eq(I.slot.order(), A.ref_host(s), seat, I.seat.slots(S.state.players(s), seat), S.world.sawed(S.state.world(s)), I.jam.any(I.jam.for(s, seat)), I.steal.any(I.steal.for(s, seat)), GP.slots.eq(s, seat, shape), sawed.eq(s), targets.eq(s, seat, shape), steals.eq(s, seat, shape))

# The grant chain (PassTurn, GiveTurnPermissions) from a state no seat holds
# the turn in.

def quiet.host(+s: S.State, +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {A.ref_host(s) == A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), None{}) : H.Host}:
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      Equal.cong(Maybe<&2, D.Seat>, H.Host, x => A.host.at(world, players, grabs, x), A.turn.holder(phase), None{}, quiet)

def give.claim(+s: S.State, +seat: D.Seat) -> Type:
  {H.host.set_props(A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), None{}), seat, H.props.set_turn(H.host.props(A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), None{}), seat), True{})) == A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), Some{seat}) : H.Host}

def give.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> give.claim(s, seat):
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
              GP.absurd(give.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(give.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
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
              GP.absurd(give.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(give.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
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
              GP.absurd(give.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(give.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))

def idle.at(+h: H.Host, +seat: D.Seat, +moves: List<&2, D.Move>, +notes: A.Notes()) -> R.RefState:
  R.RefState{h, R.Await{D.request.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, H.host.table(h), Nil{}), seat, D.PickUp{} <> moves)), D.Playing{seat, D.Idle{}}, R.PlayerMove{D.Idle{}}}, notes}

def settle.await(+k: Nat, +h: H.Host, +request: D.Request, +stage: D.Stage, +continuation: R.Continuation, +notes: A.Notes()) -> {R.settle(k, R.RefState{h, R.Await{request, stage, continuation}, notes}) == R.RefState{h, R.Await{request, stage, continuation}, notes} : R.RefState}:
  match k:
    case 0n:
      {==}
    case 1n+j:
      {==}

def idle.menu(+h: H.Host, +seat: D.Seat, +notes: A.Notes()) -> R.RefState:
  idle.at(h, seat, RI.use_moves(I.slot.order(), h, seat), notes)

def give.after(+h: H.Host, +seat: D.Seat, +notes: A.Notes()) -> R.RefState:
  idle.menu(H.host.set_props(h, seat, H.props.set_turn(H.host.props(h, seat), True{})), seat, notes)

def give.close(+s: S.State, +seat: D.Seat, +k: Nat, +shape: A.Shape(s), +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {R.settle(1n+k, R.RefState{A.ref_host(s), R.GiveTurnPermissions{seat}, S.state.notes(s)}) == A.ref(M.give_turn(s, seat)) : R.RefState}:
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      +st : S.State = S.State{world, players, phase, notes, grabs}
      +given : S.State = M.give_turn(st, seat)
      +told : A.Notes() = List.append(&2, D.Note, notes, [D.Shown{D.TurnGiven{seat}}])
      +h0 : H.Host = A.host.at(world, players, grabs, None{})
      +h1 : H.Host = A.host.at(world, players, grabs, Some{seat})
      +quieted : {give.after(A.ref_host(st), seat, told) == give.after(h0, seat, told) : R.RefState} = Equal.cong(H.Host, R.RefState, h => give.after(h, seat, told), A.ref_host(st), h0, quiet.host(st, quiet))
      +granted : {give.after(h0, seat, told) == idle.menu(h1, seat, told) : R.RefState} = Equal.cong(H.Host, R.RefState, h => idle.menu(h, seat, told), H.host.set_props(h0, seat, H.props.set_turn(H.host.props(h0, seat), True{})), h1, give.eq(st, seat, shape))
      +menu : {idle.menu(h1, seat, told) == A.ref(given) : R.RefState} = Equal.cong(List<&2, D.Move>, R.RefState, xs => idle.at(h1, seat, xs, told), RI.use_moves(I.slot.order(), h1, seat), Q.idle.moves(I.uses(st, seat)), uses.eq(given, seat, ISP.shape.move(world, players, phase, notes, grabs, S.state.phase(given), told, shape)))
      +hs : H.Host = H.host.set_props(A.ref_host(st), seat, H.props.set_turn(H.host.props(A.ref_host(st), seat), True{}))
      +waited : {R.settle(k, give.after(A.ref_host(st), seat, told)) == give.after(A.ref_host(st), seat, told) : R.RefState} = settle.await(k, hs, D.request.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, H.host.table(hs), Nil{}), seat, D.PickUp{} <> RI.use_moves(I.slot.order(), hs, seat))), D.Playing{seat, D.Idle{}}, R.PlayerMove{D.Idle{}}, told)
      Equal.trans(R.RefState, R.settle(k, give.after(A.ref_host(st), seat, told)), give.after(A.ref_host(st), seat, told), A.ref(given), waited, Equal.trans(R.RefState, give.after(A.ref_host(st), seat, told), give.after(h0, seat, told), A.ref(given), quieted, Equal.trans(R.RefState, give.after(h0, seat, told), idle.menu(h1, seat, told), A.ref(given), granted, menu)))

def jam.is_jammed(+j: S.Jam) -> Type:
  match j:
    case S.Jammed{}:
      Empty
    case _:
      Unit

def jam.clash(+e: {S.Free{} == S.Jammed{} : S.Jam}) -> Empty:
  %e : jam.is_jammed(_)
  Unit{}

def jam.clash.skipped(+e: {S.JammedSkipped{} == S.Jammed{} : S.Jam}) -> Empty:
  %e : jam.is_jammed(_)
  Unit{}

def rank.at(+a: Nat, +j: S.Jam, +r: Nat, +e: {j == S.Jammed{} : S.Jam}) -> {Nat.add(a, Nat.add(Q.jam_rank.bit(j), r)) == 1n+Nat.add(a, r) : Nat}:
  match j:
    case S.Jammed{}:
      GP.add.succ(a, r)
    case S.Free{}:
      GP.absurd({Nat.add(a, Nat.add(Q.jam_rank.bit(S.Free{}), r)) == 1n+Nat.add(a, r) : Nat}, jam.clash(e))
    case S.JammedSkipped{}:
      GP.absurd({Nat.add(a, Nat.add(Q.jam_rank.bit(S.JammedSkipped{}), r)) == 1n+Nat.add(a, r) : Nat}, jam.clash.skipped(e))

# A skip checks one unchecked jam, so the machine's rank bound drops by one.
def rank.claim(+s: S.State, +seat: D.Seat) -> Type:
  {Q.jam_rank(S.state.players(s)) == 1n+Q.jam_rank(S.players.set_jam(S.state.players(s), seat, S.JammedSkipped{})) : Nat}

def rank.skip(+s: S.State, +seat: D.Seat, +shape: A.Shape(s), +e: {Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{}) == S.Jammed{} : S.Jam}) -> rank.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          GP.absurd(rank.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, D.Seat0{}), jam.clash(e))
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          rank.at(0n, j1, Nat.add(Q.jam_rank.bit(j3), 0n), e)
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          GP.absurd(rank.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, D.Seat2{}), jam.clash(e))
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          Equal.trans(Nat, Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j3), 0n)), Nat.add(Q.jam_rank.bit(j1), 1n+0n), 1n+Nat.add(Q.jam_rank.bit(j1), 0n), Equal.cong(Nat, Nat, x => Nat.add(Q.jam_rank.bit(j1), x), Nat.add(Q.jam_rank.bit(j3), 0n), 1n+0n, rank.at(0n, j3, 0n, e)), GP.add.succ(Q.jam_rank.bit(j1), 0n))
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(rank.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(rank.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          rank.at(0n, j0, Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n)), e)
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          Equal.trans(Nat, Nat.add(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n))), Nat.add(Q.jam_rank.bit(j0), 1n+Nat.add(Q.jam_rank.bit(j2), 0n)), 1n+Nat.add(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j2), 0n)), Equal.cong(Nat, Nat, x => Nat.add(Q.jam_rank.bit(j0), x), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n)), 1n+Nat.add(Q.jam_rank.bit(j2), 0n), rank.at(0n, j1, Nat.add(Q.jam_rank.bit(j2), 0n), e)), GP.add.succ(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j2), 0n)))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          Equal.trans(Nat, Nat.add(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n))), Nat.add(Q.jam_rank.bit(j0), 1n+Nat.add(Q.jam_rank.bit(j1), 0n)), 1n+Nat.add(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), 0n)), Equal.cong(Nat, Nat, x => Nat.add(Q.jam_rank.bit(j0), x), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n)), 1n+Nat.add(Q.jam_rank.bit(j1), 0n), Equal.trans(Nat, Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n)), Nat.add(Q.jam_rank.bit(j1), 1n+0n), 1n+Nat.add(Q.jam_rank.bit(j1), 0n), Equal.cong(Nat, Nat, x => Nat.add(Q.jam_rank.bit(j1), x), Nat.add(Q.jam_rank.bit(j2), 0n), 1n+0n, rank.at(0n, j2, 0n, e)), GP.add.succ(Q.jam_rank.bit(j1), 0n))), GP.add.succ(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), 0n)))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          GP.absurd(rank.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, D.Seat3{}), jam.clash(e))
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(rank.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(rank.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat0{}:
          rank.at(0n, j0, Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n))), e)
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat1{}:
          Equal.trans(Nat, Nat.add(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n)))), Nat.add(Q.jam_rank.bit(j0), 1n+Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n))), 1n+Nat.add(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n))), Equal.cong(Nat, Nat, x => Nat.add(Q.jam_rank.bit(j0), x), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n))), 1n+Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n)), rank.at(0n, j1, Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n)), e)), GP.add.succ(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n))))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat2{}:
          Equal.trans(Nat, Nat.add(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n)))), Nat.add(Q.jam_rank.bit(j0), 1n+Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j3), 0n))), 1n+Nat.add(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j3), 0n))), Equal.cong(Nat, Nat, x => Nat.add(Q.jam_rank.bit(j0), x), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n))), 1n+Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j3), 0n)), Equal.trans(Nat, Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n))), Nat.add(Q.jam_rank.bit(j1), 1n+Nat.add(Q.jam_rank.bit(j3), 0n)), 1n+Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j3), 0n)), Equal.cong(Nat, Nat, x => Nat.add(Q.jam_rank.bit(j1), x), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n)), 1n+Nat.add(Q.jam_rank.bit(j3), 0n), rank.at(0n, j2, Nat.add(Q.jam_rank.bit(j3), 0n), e)), GP.add.succ(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j3), 0n)))), GP.add.succ(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j3), 0n))))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} D.Seat3{}:
          Equal.trans(Nat, Nat.add(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n)))), Nat.add(Q.jam_rank.bit(j0), 1n+Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n))), 1n+Nat.add(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n))), Equal.cong(Nat, Nat, x => Nat.add(Q.jam_rank.bit(j0), x), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n))), 1n+Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n)), Equal.trans(Nat, Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n))), Nat.add(Q.jam_rank.bit(j1), 1n+Nat.add(Q.jam_rank.bit(j2), 0n)), 1n+Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n)), Equal.cong(Nat, Nat, x => Nat.add(Q.jam_rank.bit(j1), x), Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n)), 1n+Nat.add(Q.jam_rank.bit(j2), 0n), Equal.trans(Nat, Nat.add(Q.jam_rank.bit(j2), Nat.add(Q.jam_rank.bit(j3), 0n)), Nat.add(Q.jam_rank.bit(j2), 1n+0n), 1n+Nat.add(Q.jam_rank.bit(j2), 0n), Equal.cong(Nat, Nat, x => Nat.add(Q.jam_rank.bit(j2), x), Nat.add(Q.jam_rank.bit(j3), 0n), 1n+0n, rank.at(0n, j3, 0n, e)), GP.add.succ(Q.jam_rank.bit(j2), 0n))), GP.add.succ(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n)))), GP.add.succ(Q.jam_rank.bit(j0), Nat.add(Q.jam_rank.bit(j1), Nat.add(Q.jam_rank.bit(j2), 0n))))
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(rank.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(rank.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))

# The reference props of a seat at a quiet host, in machine readers.
def pprops.with(+s: S.State, +seat: D.Seat, +jam: S.Jam) -> H.Props:
  +players : S.Players = S.state.players(s)
  +grabs : S.Grabs = S.state.grabs(s)
  H.Props{I.seat.health(players, seat), S.jam.jammed(jam), A.jam.checked(jam), Q.value.or(U32, D.ring.get(U32, S.players.cash(players), seat), 0), I.seat.slots(players, seat), I.seat.grabbing(grabs, seat), I.seat.holding(grabs, seat), False{}}

def pprops.claim(+s: S.State, +seat: D.Seat) -> Type:
  {H.host.props(A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), None{}), seat) == pprops.with(s, seat, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{})) : H.Props}

def pprops.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> pprops.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, +intake} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, +intake} D.Seat1{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, +intake} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, +intake} D.Seat3{}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat), GP.clash.three_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat), GP.clash.four_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat), GP.clash.three_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat), GP.clash.four_two(e_holding))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat0{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat1{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat2{}:
          {==}
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat), GP.clash.two_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat), GP.clash.four_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat), GP.clash.two_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat), GP.clash.four_three(e_holding))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat0{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat1{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat2{}:
          {==}
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat3{}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat), GP.clash.two_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat), GP.clash.three_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat), GP.clash.two_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(pprops.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat), GP.clash.three_four(e_holding))

def jamw.claim(+s: S.State, +seat: D.Seat, +jam: S.Jam) -> Type:
  {H.host.set_props(A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), None{}), seat, pprops.with(s, seat, jam)) == A.host.at(S.state.world(s), S.players.set_jam(S.state.players(s), seat, jam), S.state.grabs(s), None{}) : H.Host}

def jamw.eq(+s: S.State, +seat: D.Seat, +jam: S.Jam, +shape: A.Shape(s)) -> jamw.claim(s, seat, jam):
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
              GP.absurd(jamw.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, jam), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(jamw.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, jam), GP.clash.four_two(e_players))
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
              GP.absurd(jamw.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, jam), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(jamw.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, jam), GP.clash.four_three(e_players))
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
              GP.absurd(jamw.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, jam), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(jamw.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat, jam), GP.clash.three_four(e_players))

def next.claim(+s: S.State, +seat: D.Seat) -> Type:
  {G.GetNextTurn_Socket(A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), None{}), seat) == Q.next_turn(S.players.health(S.state.players(s)), S.world.direction(S.state.world(s)), seat) : D.Seat}

def next.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> next.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          Equal.sym(D.Seat, Q.next_turn(A.seats.health(S.state.players(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}})), S.world.direction(S.state.world(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}})), seat), A.ref_turn(S.state.world(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), S.state.players(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), seat), GrantProof.turn_raw(S.state.world(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), S.state.players(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), seat))
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(next.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(next.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          Equal.sym(D.Seat, Q.next_turn(A.seats.health(S.state.players(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}})), S.world.direction(S.state.world(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}})), seat), A.ref_turn(S.state.world(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), S.state.players(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), seat), GrantProof.turn_raw(S.state.world(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), S.state.players(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), seat))
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(next.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(next.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          Equal.sym(D.Seat, Q.next_turn(A.seats.health(S.state.players(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}})), S.world.direction(S.state.world(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}})), seat), A.ref_turn(S.state.world(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), S.state.players(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), seat), GrantProof.turn_raw(S.state.world(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), S.state.players(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), seat))
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(next.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(next.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))

def nat.is_succ(+n: Nat) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+m:
      Empty

def nat.clash(+x: Nat, +e: {0n == 1n+x : Nat}) -> Empty:
  %e : nat.is_succ(_)
  Unit{}

def shape.jam(+s: S.State, +seat: D.Seat, +jam: S.Jam, +shape: A.Shape(s)) -> A.Shape(S.state.set_players(s, S.players.set_jam(S.state.players(s), seat, jam))):
  match s:
    case S.State{+world, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      match shape:
        case Tuple{+e_players, +rest}:
          +written : S.Seat = S.seat.set_jam(S.players.seat(players, seat), jam)
          (Equal.trans(D.Table, D.ring.table(S.Seat, D.ring.set(S.Seat, players, seat, written)), D.ring.table(S.Seat, players), S.world.table(world), GP.set_table(S.Seat, players, seat, written), e_players), rest)

def turned(+s: S.State, +seat: D.Seat) -> S.State:
  S.state.set_world(s, S.world.set_turn(S.state.world(s), Some{seat}))

# A jam write at a quiet host is the reference host of the written seat ring.
def jamw.host(+s: S.State, +seat: D.Seat, +jam: S.Jam, +event: D.GameEvent, +shape: A.Shape(s), +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {H.host.set_props(A.ref_host(s), seat, pprops.with(s, seat, jam)) == A.ref_host(S.state.emit(S.state.set_players(s, S.players.set_jam(S.state.players(s), seat, jam)), event)) : H.Host}:
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      +st : S.State = S.State{world, players, phase, notes, grabs}
      +h0 : H.Host = A.host.at(world, players, grabs, None{})
      Equal.trans(H.Host, H.host.set_props(A.ref_host(st), seat, pprops.with(st, seat, jam)), H.host.set_props(h0, seat, pprops.with(st, seat, jam)), A.ref_host(S.state.emit(S.state.set_players(st, S.players.set_jam(players, seat, jam)), event)), Equal.cong(H.Host, H.Host, h => H.host.set_props(h, seat, pprops.with(st, seat, jam)), A.ref_host(st), h0, quiet.host(st, quiet)), Equal.trans(H.Host, H.host.set_props(h0, seat, pprops.with(st, seat, jam)), A.host.at(world, S.players.set_jam(players, seat, jam), grabs, None{}), A.ref_host(S.state.emit(S.state.set_players(st, S.players.set_jam(players, seat, jam)), event)), jamw.eq(st, seat, jam, shape), Equal.sym(H.Host, A.ref_host(S.state.emit(S.state.set_players(st, S.players.set_jam(players, seat, jam)), event)), A.host.at(world, S.players.set_jam(players, seat, jam), grabs, None{}), quiet.host(S.state.emit(S.state.set_players(st, S.players.set_jam(players, seat, jam)), event), quiet))))

def props.at.quiet(+s: S.State, +seat: D.Seat, +jam: S.Jam, +shape: A.Shape(s), +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}, +e_jam: {Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{}) == jam : S.Jam}) -> {H.host.props(A.ref_host(s), seat) == pprops.with(s, seat, jam) : H.Props}:
  +h0 : H.Host = A.host.at(S.state.world(s), S.state.players(s), S.state.grabs(s), None{})
  Equal.trans(H.Props, H.host.props(A.ref_host(s), seat), H.host.props(h0, seat), pprops.with(s, seat, jam), Equal.cong(H.Host, H.Props, h => H.host.props(h, seat), A.ref_host(s), h0, quiet.host(s, quiet)), Equal.trans(H.Props, H.host.props(h0, seat), pprops.with(s, seat, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{})), pprops.with(s, seat, jam), pprops.eq(s, seat, shape), Equal.cong(S.Jam, H.Props, j => pprops.with(s, seat, j), Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{}), jam, e_jam)))

def pass.at(+fuel: Nat, +h: H.Host, +seat: D.Seat, +notes: A.Notes()) -> R.RefState:
  R.settle(fuel, R.RefState{h, R.PassTurn{G.GetNextTurn_Socket(h, seat)}, notes})

def shape.turn(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> A.Shape(turned(s, seat)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      shape

def step.act(+rank: Nat, +t: S.State, +seat: D.Seat, +p: S.Players) -> {A.ref(M.give_turn(S.state.set_players(t, p), seat)) == A.ref(M.grant.step(rank, t, seat, S.Act{p})) : R.RefState}:
  match rank:
    case 0n:
      {==}
    case 1n+r:
      {==}

def step.lift(+rank: Nat, +t: S.State, +seat: D.Seat, +p: S.Players) -> {A.ref(M.give_turn(S.state.emit(S.state.set_players(t, p), D.JamLifted{seat}), seat)) == A.ref(M.grant.step(rank, t, seat, S.Lift{p})) : R.RefState}:
  match rank:
    case 0n:
      {==}
    case 1n+r:
      {==}

def nat.pred(+n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+m:
      m

# PassTurn from a quiet state: the reference's jam checks follow the
# machine's grant step, one dispatch per skipped seat.
def pass.close(+rank: Nat, +jam: S.Jam, +s: S.State, +seat: D.Seat, +k: Nat, +shape: A.Shape(s), +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}, +e_jam: {Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s)), seat), S.Free{}) == jam : S.Jam}, +e_rank: {Q.jam_rank(S.state.players(s)) == rank : Nat}) -> {R.settle(Nat.add(2n, Nat.add(rank, k)), R.RefState{A.ref_host(s), R.PassTurn{seat}, S.state.notes(s)}) == A.ref(M.grant.step(rank, turned(s, seat), seat, Q.jam.state(S.state.players(s), seat, jam))) : R.RefState}:
  match rank jam:
    case rank S.Free{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          +t : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, Some{seat}, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}
          +shape_t : A.Shape(t) = shape.turn(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, seat, shape)
          +rs : R.RefState = R.RefState{A.ref_host(t), R.PassTurn{seat}, notes}
          +read : {R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, H.host.props(A.ref_host(t), seat))) == R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, pprops.with(t, seat, S.Free{}))) : R.RefState} = Equal.cong(H.Props, R.RefState, p => R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, p)), H.host.props(A.ref_host(t), seat), pprops.with(t, seat, S.Free{}), props.at.quiet(t, seat, S.Free{}, shape_t, quiet, e_jam))
          Equal.trans(R.RefState, R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, H.host.props(A.ref_host(t), seat))), R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, pprops.with(t, seat, S.Free{}))), A.ref(M.grant.step(rank, t, seat, S.Act{players})), read, Equal.trans(R.RefState, R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, pprops.with(t, seat, S.Free{}))), A.ref(M.give_turn(S.state.set_players(t, players), seat)), A.ref(M.grant.step(rank, t, seat, S.Act{players})), give.close(t, seat, Nat.add(rank, k), shape_t, quiet), step.act(rank, t, seat, players)))
    case rank S.JammedSkipped{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          +t : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, Some{seat}, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}
          +shape_t : A.Shape(t) = shape.turn(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, seat, shape)
          +rs : R.RefState = R.RefState{A.ref_host(t), R.PassTurn{seat}, notes}
          +lifted : S.State = S.state.emit(S.state.set_players(t, S.players.set_jam(players, seat, S.Free{})), D.JamLifted{seat})
          +told : A.Notes() = List.append(&2, D.Note, notes, [D.Shown{D.JamLifted{seat}}])
          +read : {R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, H.host.props(A.ref_host(t), seat))) == R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, pprops.with(t, seat, S.JammedSkipped{}))) : R.RefState} = Equal.cong(H.Props, R.RefState, p => R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, p)), H.host.props(A.ref_host(t), seat), pprops.with(t, seat, S.JammedSkipped{}), props.at.quiet(t, seat, S.JammedSkipped{}, shape_t, quiet, e_jam))
          +written : {R.settle(1n+Nat.add(rank, k), R.RefState{H.host.set_props(A.ref_host(t), seat, pprops.with(t, seat, S.Free{})), R.GiveTurnPermissions{seat}, told}) == R.settle(1n+Nat.add(rank, k), R.RefState{A.ref_host(lifted), R.GiveTurnPermissions{seat}, told}) : R.RefState} = Equal.cong(H.Host, R.RefState, h => R.settle(1n+Nat.add(rank, k), R.RefState{h, R.GiveTurnPermissions{seat}, told}), H.host.set_props(A.ref_host(t), seat, pprops.with(t, seat, S.Free{})), A.ref_host(lifted), jamw.host(t, seat, S.Free{}, D.JamLifted{seat}, shape_t, quiet))
          +shaped : A.Shape(lifted) = ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, Some{seat}, direction, died, checking, amount, saw, gun, shown, deck}, S.players.set_jam(players, seat, S.Free{}), phase, notes, grabs, phase, told, shape.jam(t, seat, S.Free{}, shape_t))
          Equal.trans(R.RefState, R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, H.host.props(A.ref_host(t), seat))), R.settle(1n+Nat.add(rank, k), R.PassTurn.props(rs, seat, pprops.with(t, seat, S.JammedSkipped{}))), A.ref(M.grant.step(rank, t, seat, S.Lift{S.players.set_jam(players, seat, S.Free{})})), read, Equal.trans(R.RefState, R.settle(1n+Nat.add(rank, k), R.RefState{H.host.set_props(A.ref_host(t), seat, pprops.with(t, seat, S.Free{})), R.GiveTurnPermissions{seat}, told}), R.settle(1n+Nat.add(rank, k), R.RefState{A.ref_host(lifted), R.GiveTurnPermissions{seat}, told}), A.ref(M.grant.step(rank, t, seat, S.Lift{S.players.set_jam(players, seat, S.Free{})})), written, Equal.trans(R.RefState, R.settle(1n+Nat.add(rank, k), R.RefState{A.ref_host(lifted), R.GiveTurnPermissions{seat}, told}), A.ref(M.give_turn(lifted, seat)), A.ref(M.grant.step(rank, t, seat, S.Lift{S.players.set_jam(players, seat, S.Free{})})), give.close(lifted, seat, Nat.add(rank, k), shaped, quiet), step.lift(rank, t, seat, S.players.set_jam(players, seat, S.Free{})))))
    case 0n S.Jammed{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          +down : {0n == 1n+Q.jam_rank(S.players.set_jam(players, seat, S.JammedSkipped{})) : Nat} = Equal.trans(Nat, 0n, Q.jam_rank(players), 1n+Q.jam_rank(S.players.set_jam(players, seat, S.JammedSkipped{})), Equal.sym(Nat, Q.jam_rank(players), 0n, e_rank), rank.skip(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, seat, shape, e_jam))
          GP.absurd({R.settle(Nat.add(2n, Nat.add(0n, k)), R.RefState{A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), R.PassTurn{seat}, notes}) == A.ref(M.grant.step(0n, turned(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, seat), seat, Q.jam.state(players, seat, S.Jammed{}))) : R.RefState}, nat.clash(Q.jam_rank(S.players.set_jam(players, seat, S.JammedSkipped{})), down))
    case 1n+r S.Jammed{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          +t : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, Some{seat}, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}
          +shape_t : A.Shape(t) = shape.turn(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, seat, shape)
          +rs : R.RefState = R.RefState{A.ref_host(t), R.PassTurn{seat}, notes}
          +fuel : Nat = Nat.add(2n, Nat.add(r, k))
          +skipped : S.Players = S.players.set_jam(players, seat, S.JammedSkipped{})
          +told : A.Notes() = List.append(&2, D.Note, notes, [D.Shown{D.TurnSkipped{seat}}])
          +s1 : S.State = S.state.emit(S.state.set_players(t, skipped), D.TurnSkipped{seat})
          +shape_s1 : A.Shape(s1) = ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, Some{seat}, direction, died, checking, amount, saw, gun, shown, deck}, skipped, phase, notes, grabs, phase, told, shape.jam(t, seat, S.JammedSkipped{}, shape_t))
          +next : D.Seat = Q.next_turn(S.players.health(skipped), direction, seat)
          +h2 : H.Host = H.host.set_props(A.ref_host(t), seat, pprops.with(t, seat, S.JammedSkipped{}))
          +read : {R.settle(1n+Nat.add(1n+r, k), R.PassTurn.props(rs, seat, H.host.props(A.ref_host(t), seat))) == pass.at(fuel, h2, seat, told) : R.RefState} = Equal.cong(H.Props, R.RefState, p => R.settle(1n+Nat.add(1n+r, k), R.PassTurn.props(rs, seat, p)), H.host.props(A.ref_host(t), seat), pprops.with(t, seat, S.Jammed{}), props.at.quiet(t, seat, S.Jammed{}, shape_t, quiet, e_jam))
          +written : {pass.at(fuel, h2, seat, told) == pass.at(fuel, A.ref_host(s1), seat, told) : R.RefState} = Equal.cong(H.Host, R.RefState, h => pass.at(fuel, h, seat, told), h2, A.ref_host(s1), jamw.host(t, seat, S.JammedSkipped{}, D.TurnSkipped{seat}, shape_t, quiet))
          +seat_eq : {G.GetNextTurn_Socket(A.ref_host(s1), seat) == next : D.Seat} = Equal.trans(D.Seat, G.GetNextTurn_Socket(A.ref_host(s1), seat), G.GetNextTurn_Socket(A.host.at(S.state.world(s1), skipped, grabs, None{}), seat), next, Equal.cong(H.Host, D.Seat, h => G.GetNextTurn_Socket(h, seat), A.ref_host(s1), A.host.at(S.state.world(s1), skipped, grabs, None{}), quiet.host(s1, quiet)), next.eq(s1, seat, shape_s1))
          +nexted : {pass.at(fuel, A.ref_host(s1), seat, told) == R.settle(fuel, R.RefState{A.ref_host(s1), R.PassTurn{next}, told}) : R.RefState} = Equal.cong(D.Seat, R.RefState, x => R.settle(fuel, R.RefState{A.ref_host(s1), R.PassTurn{x}, told}), G.GetNextTurn_Socket(A.ref_host(s1), seat), next, seat_eq)
          +ranked : {1n+Q.jam_rank(skipped) == 1n+r : Nat} = Equal.trans(Nat, 1n+Q.jam_rank(skipped), Q.jam_rank(players), 1n+r, Equal.sym(Nat, Q.jam_rank(players), 1n+Q.jam_rank(skipped), rank.skip(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, seat, shape, e_jam)), e_rank)
          +rest_rank : {Q.jam_rank(skipped) == r : Nat} = Equal.cong(Nat, Nat, n => nat.pred(n), 1n+Q.jam_rank(skipped), 1n+r, ranked)
          +rec : {R.settle(fuel, R.RefState{A.ref_host(s1), R.PassTurn{next}, told}) == A.ref(M.grant.step(r, turned(s1, next), next, Q.jam.state(skipped, next, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s1)), next), S.Free{})))) : R.RefState} = pass.close(r, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s1)), next), S.Free{}), s1, next, k, shape_s1, quiet, {==}, rest_rank)
          Equal.trans(R.RefState, R.settle(1n+Nat.add(1n+r, k), R.PassTurn.props(rs, seat, H.host.props(A.ref_host(t), seat))), pass.at(fuel, h2, seat, told), A.ref(M.grant.step(r, turned(s1, next), next, Q.jam.state(skipped, next, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s1)), next), S.Free{})))), read, Equal.trans(R.RefState, pass.at(fuel, h2, seat, told), pass.at(fuel, A.ref_host(s1), seat, told), A.ref(M.grant.step(r, turned(s1, next), next, Q.jam.state(skipped, next, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s1)), next), S.Free{})))), written, Equal.trans(R.RefState, pass.at(fuel, A.ref_host(s1), seat, told), R.settle(fuel, R.RefState{A.ref_host(s1), R.PassTurn{next}, told}), A.ref(M.grant.step(r, turned(s1, next), next, Q.jam.state(skipped, next, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(S.state.players(s1)), next), S.Free{})))), nexted, rec)))

# The machine's rank bound fits the load closure: at most four seats skip.
def gap.bit(+jam: S.Jam) -> Nat:
  match jam:
    case S.Jammed{}:
      0n
    case _:
      1n

def gap.entries(+entries: List<&2, D.At<&2, S.Jam>>) -> Nat:
  match entries:
    case Nil{}:
      0n
    case D.At{seat, jam} <> rest:
      Nat.add(gap.bit(jam), gap.entries(rest))

def rank.count(+entries: List<&2, D.At<&2, S.Jam>>) -> {Nat.add(Q.jam_rank.entries(entries), gap.entries(entries)) == List.length(&2, D.At<&2, S.Jam>, entries) : Nat}:
  match entries:
    case Nil{}:
      {==}
    case D.At{+seat, +jam} <> +rest:
      match jam:
        case S.Jammed{}:
          Equal.cong(Nat, Nat, n => 1n+n, Nat.add(Q.jam_rank.entries(rest), gap.entries(rest)), List.length(&2, D.At<&2, S.Jam>, rest), rank.count(rest))
        case S.Free{}:
          Equal.trans(Nat, Nat.add(Q.jam_rank.entries(rest), 1n+gap.entries(rest)), 1n+Nat.add(Q.jam_rank.entries(rest), gap.entries(rest)), 1n+List.length(&2, D.At<&2, S.Jam>, rest), GP.add.succ(Q.jam_rank.entries(rest), gap.entries(rest)), Equal.cong(Nat, Nat, n => 1n+n, Nat.add(Q.jam_rank.entries(rest), gap.entries(rest)), List.length(&2, D.At<&2, S.Jam>, rest), rank.count(rest)))
        case S.JammedSkipped{}:
          Equal.trans(Nat, Nat.add(Q.jam_rank.entries(rest), 1n+gap.entries(rest)), 1n+Nat.add(Q.jam_rank.entries(rest), gap.entries(rest)), 1n+List.length(&2, D.At<&2, S.Jam>, rest), GP.add.succ(Q.jam_rank.entries(rest), gap.entries(rest)), Equal.cong(Nat, Nat, n => 1n+n, Nat.add(Q.jam_rank.entries(rest), gap.entries(rest)), List.length(&2, D.At<&2, S.Jam>, rest), rank.count(rest)))

def table.gap(+jams: D.Ring<&2, S.Jam>) -> Nat:
  match jams:
    case D.Duo{a, b}:
      2n
    case D.Trio{a, b, c}:
      1n
    case D.Quad{a, b, c, d}:
      0n

def ring.room(+jams: D.Ring<&2, S.Jam>) -> {Nat.add(List.length(&2, D.At<&2, S.Jam>, D.ring.entries(S.Jam, jams)), table.gap(jams)) == 4n : Nat}:
  match jams:
    case D.Duo{a, b}:
      {==}
    case D.Trio{a, b, c}:
      {==}
    case D.Quad{a, b, c, d}:
      {==}

def rank.slack(+players: S.Players) -> Nat:
  +jams : D.Ring<&2, S.Jam> = S.players.jam(players)
  Nat.add(gap.entries(D.ring.entries(S.Jam, jams)), table.gap(jams))

# After the five load dispatches, the grant chain has 2 + rank + k' fuel.
def rank.fuel(+players: S.Players, +k: Nat) -> {Nat.add(6n, k) == Nat.add(2n, Nat.add(Q.jam_rank(players), Nat.add(rank.slack(players), k))) : Nat}:
  +jams : D.Ring<&2, S.Jam> = S.players.jam(players)
  +xs : List<&2, D.At<&2, S.Jam>> = D.ring.entries(S.Jam, jams)
  +r : Nat = Q.jam_rank.entries(xs)
  +g : Nat = gap.entries(xs)
  +t : Nat = table.gap(jams)
  +len : Nat = List.length(&2, D.At<&2, S.Jam>, xs)
  +four : {Nat.add(r, Nat.add(g, t)) == 4n : Nat} = Equal.trans(Nat, Nat.add(r, Nat.add(g, t)), Nat.add(Nat.add(r, g), t), 4n, Equal.sym(Nat, Nat.add(Nat.add(r, g), t), Nat.add(r, Nat.add(g, t)), GP.add.assoc(r, g, t)), Equal.trans(Nat, Nat.add(Nat.add(r, g), t), Nat.add(len, t), 4n, Equal.cong(Nat, Nat, n => Nat.add(n, t), Nat.add(r, g), len, rank.count(xs)), ring.room(jams)))
  +moved : {Nat.add(4n, k) == Nat.add(r, Nat.add(Nat.add(g, t), k)) : Nat} = Equal.trans(Nat, Nat.add(4n, k), Nat.add(Nat.add(r, Nat.add(g, t)), k), Nat.add(r, Nat.add(Nat.add(g, t), k)), Equal.cong(Nat, Nat, n => Nat.add(n, k), 4n, Nat.add(r, Nat.add(g, t)), Equal.sym(Nat, Nat.add(r, Nat.add(g, t)), 4n, four)), GP.add.assoc(r, Nat.add(g, t), k))
  Equal.cong(Nat, Nat, n => Nat.add(2n, n), Nat.add(4n, k), Nat.add(r, Nat.add(Nat.add(g, t), k)), moved)

# The load prefix (MainRoutine_LoadShotgun .. LoadShotgun) against
# M.load.begin, each stage at the fuel left when the reference reaches it.

def deck.eq(+s: S.State) -> {H.host.deck(A.ref_host(s)) == A.batches(S.world.deck(S.state.world(s))) : List<&2, H.Batch>}:
  match s:
    case S.State{S.World{D.Config{D.TwoSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+a, +b, +c}}, +players, +phase, +notes, +grabs}:
      {==}
    case S.State{S.World{D.Config{D.ThreeSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+a, +b, +c}}, +players, +phase, +notes, +grabs}:
      {==}
    case S.State{S.World{D.Config{D.FourSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+a, +b, +c}}, +players, +phase, +notes, +grabs}:
      {==}

def removed(+s: S.State, +index: Nat) -> S.State:
  +world : S.World = S.state.world(s)
  S.state.set_world(s, S.world.set_deck(world, Q.remove(S.Batch, S.world.deck(world), index)))

def removed.host(+s: S.State, +index: Nat) -> {H.host.set_deck(A.ref_host(s), G.remove(H.Batch, H.host.deck(A.ref_host(s)), index)) == A.ref_host(removed(s, index)) : H.Host}:
  match s:
    case S.State{S.World{D.Config{D.TwoSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+a, +b, +c}}, +players, +phase, +notes, +grabs}:
      Equal.cong(List<&2, H.Batch>, H.Host, d => H.host.set_decks(A.host.at(S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{a, b, c}}, players, grabs, A.turn.holder(phase)), H.Decks{d, A.batches(b), A.batches(c)}), G.remove(H.Batch, A.batches(a), index), A.batches(Q.remove(S.Batch, a, index)), C.loadproof.batch_remove(a, index))
    case S.State{S.World{D.Config{D.ThreeSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+a, +b, +c}}, +players, +phase, +notes, +grabs}:
      Equal.cong(List<&2, H.Batch>, H.Host, d => H.host.set_decks(A.host.at(S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{a, b, c}}, players, grabs, A.turn.holder(phase)), H.Decks{A.batches(a), d, A.batches(c)}), G.remove(H.Batch, A.batches(b), index), A.batches(Q.remove(S.Batch, b, index)), C.loadproof.batch_remove(b, index))
    case S.State{S.World{D.Config{D.FourSeats{}, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+a, +b, +c}}, +players, +phase, +notes, +grabs}:
      Equal.cong(List<&2, H.Batch>, H.Host, d => H.host.set_decks(A.host.at(S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{a, b, c}}, players, grabs, A.turn.holder(phase)), H.Decks{A.batches(a), A.batches(b), d}), G.remove(H.Batch, A.batches(c), index), A.batches(Q.remove(S.Batch, c, index)), C.loadproof.batch_remove(c, index))

def sub.one(+r: Nat) -> {G.subtract(1n+r, 1n) == r : Nat}:
  match r:
    case 0n:
      {==}
    case 1n+q:
      {==}

def shape.loaded(+s: S.State, +ld: D.Load, +sh: List<&2, D.Shell>, +shape: A.Shape(s)) -> A.Shape(S.state.set_world(s, S.world.set_shown(S.world.set_gun(S.state.world(s), sh), ld))):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      shape

def swap.at(+h: H.Host, +ld: D.Load, +sh: List<&2, D.Shell>, +width: Nat, +n: Nat, +notes: A.Notes()) -> R.RefState:
  R.RefState{h, R.Await{D.Draw{D.ShuffleSwap{}, D.Range{0n, width}}, D.Loading{}, R.ShuffleSwapResult{ld, sh, n}}, notes}

def shuffle.close(+i: Nat, +s: S.State, +ld: D.Load, +sh: List<&2, D.Shell>, +k: Nat, +shape: A.Shape(s), +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {R.settle(Nat.add(8n, k), R.RefState{A.ref_host(s), R.GenerateRandomSequence{R.Shuffle{ld, sh, i}}, S.state.notes(s)}) == A.ref(M.shuffle(s, ld, sh, i)) : R.RefState}:
  match i:
    case 0n:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          +s5 : S.State = S.state.emit(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_shown(S.world.set_gun(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, sh), ld)), D.Loaded{ld})
          +rank : Nat = Q.jam_rank(players)
          +fuel : {Nat.add(6n, k) == Nat.add(2n, Nat.add(rank, Nat.add(rank.slack(players), k))) : Nat} = rank.fuel(players, k)
          +more : {R.settle(Nat.add(6n, k), R.RefState{A.ref_host(s5), R.PassTurn{recipient}, S.state.notes(s5)}) == R.settle(Nat.add(2n, Nat.add(rank, Nat.add(rank.slack(players), k))), R.RefState{A.ref_host(s5), R.PassTurn{recipient}, S.state.notes(s5)}) : R.RefState} = Equal.cong(Nat, R.RefState, n => R.settle(n, R.RefState{A.ref_host(s5), R.PassTurn{recipient}, S.state.notes(s5)}), Nat.add(6n, k), Nat.add(2n, Nat.add(rank, Nat.add(rank.slack(players), k))), fuel)
          Equal.trans(R.RefState, R.settle(Nat.add(6n, k), R.RefState{A.ref_host(s5), R.PassTurn{recipient}, S.state.notes(s5)}), R.settle(Nat.add(2n, Nat.add(rank, Nat.add(rank.slack(players), k))), R.RefState{A.ref_host(s5), R.PassTurn{recipient}, S.state.notes(s5)}), A.ref(M.grant.step(rank, turned(s5, recipient), recipient, Q.jam.state(players, recipient, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(players), recipient), S.Free{})))), more, pass.close(rank, Q.value.or(S.Jam, D.ring.get(S.Jam, S.players.jam(players), recipient), S.Free{}), s5, recipient, Nat.add(rank.slack(players), k), ISP.shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, sh, ld, deck}, players, phase, notes, grabs, phase, List.append(&2, D.Note, notes, [D.Shown{D.Loaded{ld}}]), shape.loaded(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, ld, sh, shape)), quiet, {==}, {==}))
    case 1n+r:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          +h0 : H.Host = A.host.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, grabs, None{})
          +waited : {R.settle(Nat.add(7n, k), swap.at(A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), ld, sh, r, 1n+r, notes)) == swap.at(A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), ld, sh, r, 1n+r, notes) : R.RefState} = settle.await(Nat.add(7n, k), A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), D.Draw{D.ShuffleSwap{}, D.Range{0n, r}}, D.Loading{}, R.ShuffleSwapResult{ld, sh, 1n+r}, notes)
          +held : {swap.at(A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), ld, sh, r, 1n+r, notes) == swap.at(h0, ld, sh, r, 1n+r, notes) : R.RefState} = Equal.cong(H.Host, R.RefState, h => swap.at(h, ld, sh, r, 1n+r, notes), A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), h0, quiet.host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, quiet))
          +width : {swap.at(h0, ld, sh, r, 1n+r, notes) == swap.at(h0, ld, sh, G.subtract(1n+r, 1n), 1n+r, notes) : R.RefState} = Equal.cong(Nat, R.RefState, w => swap.at(h0, ld, sh, w, 1n+r, notes), r, G.subtract(1n+r, 1n), Equal.sym(Nat, G.subtract(1n+r, 1n), r, sub.one(r)))
          Equal.trans(R.RefState, R.settle(Nat.add(7n, k), swap.at(A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), ld, sh, r, 1n+r, notes)), swap.at(A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), ld, sh, r, 1n+r, notes), swap.at(h0, ld, sh, G.subtract(1n+r, 1n), 1n+r, notes), waited, Equal.trans(R.RefState, swap.at(A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), ld, sh, r, 1n+r, notes), swap.at(h0, ld, sh, r, 1n+r, notes), swap.at(h0, ld, sh, G.subtract(1n+r, 1n), 1n+r, notes), held, width))

def blocked.close(+s: S.State, +fuel: Nat, +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {R.settle(fuel, R.RefState{A.ref_host(s), R.Await{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}, S.state.notes(s)}) == A.ref(S.state.set_phase(s, S.Blocked{None{}})) : R.RefState}:
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
      +waited : {R.settle(fuel, R.RefState{A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), R.Await{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}, notes}) == R.RefState{A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), R.Await{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}, notes} : R.RefState} = settle.await(fuel, A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}, notes)
      Equal.trans(R.RefState, R.settle(fuel, R.RefState{A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), R.Await{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}, notes}), R.RefState{A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), R.Await{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}, notes}, A.ref(S.state.set_phase(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.Blocked{None{}})), waited, Equal.cong(H.Host, R.RefState, h => R.RefState{h, R.Await{D.Stuck{}, D.Setup{}, R.PlayerMove{D.Idle{}}}, notes}, A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), A.host.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, grabs, None{}), quiet.host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, quiet)))

def shuffle.ref(+k: Nat, +h: H.Host, +notes: A.Notes(), +ld: D.Load) -> R.RefState:
  R.settle(Nat.add(8n, k), R.RefState{h, R.GenerateRandomSequence{R.Shuffle{ld, G.load.shells(ld), G.subtract(List.length(&2, D.Shell, G.load.shells(ld)), 1n)}}, notes})

def shuffle.shells(+k: Nat, +h: H.Host, +notes: A.Notes(), +ld: D.Load, +sh: List<&2, D.Shell>) -> R.RefState:
  R.settle(Nat.add(8n, k), R.RefState{h, R.GenerateRandomSequence{R.Shuffle{ld, sh, G.subtract(List.length(&2, D.Shell, sh), 1n)}}, notes})

def shuffle.width(+k: Nat, +h: H.Host, +notes: A.Notes(), +ld: D.Load, +sh: List<&2, D.Shell>, +w: Nat) -> R.RefState:
  R.settle(Nat.add(8n, k), R.RefState{h, R.GenerateRandomSequence{R.Shuffle{ld, sh, w}}, notes})

def shape.removed(+s: S.State, +index: Nat, +shape: A.Shape(s)) -> A.Shape(removed(s, index)):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      shape

def batch.found.close(+selected: Maybe<&2, S.Batch>, +s: S.State, +index: Nat, +k: Nat, +shape: A.Shape(s), +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {R.settle(Nat.add(8n, k), R.GenerateRandomSequence.batch(R.RefState{A.ref_host(s), R.GenerateRandomSequence{R.BatchChosen{index}}, S.state.notes(s)}, index, A.found_batch(selected))) == A.ref(M.batch.found(s, index, selected)) : R.RefState}:
  match selected:
    case None{}:
      blocked.close(s, Nat.add(8n, k), quiet)
    case Some{S.Batch{+id, +sampled}}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          +h0 : H.Host = A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs})
          +h2 : H.Host = H.host.set_deck(h0, G.remove(H.Batch, H.host.deck(h0), index))
          +ld_r : D.Load = G.load.custom(H.host.load_rule(h0), sampled)
          +ld : D.Load = Q.load.actual(Q.world.load_rule(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}), sampled)
          +sh : List<&2, D.Shell> = Q.load.shells(ld)
          +loaded : {shuffle.ref(k, h2, notes, ld_r) == shuffle.ref(k, h2, notes, ld) : R.RefState} = Equal.cong(D.Load, R.RefState, l => shuffle.ref(k, h2, notes, l), ld_r, ld, C.loadproof.actual_world_load(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, sampled))
          +shelled : {shuffle.ref(k, h2, notes, ld) == shuffle.shells(k, h2, notes, ld, sh) : R.RefState} = Equal.cong(List<&2, D.Shell>, R.RefState, xs => shuffle.shells(k, h2, notes, ld, xs), G.load.shells(ld), sh, C.loadproof.load_shells(ld))
          +narrowed : {shuffle.shells(k, h2, notes, ld, sh) == shuffle.width(k, h2, notes, ld, sh, Q.predecessor(List.length(&2, D.Shell, sh))) : R.RefState} = Equal.cong(Nat, R.RefState, w => shuffle.width(k, h2, notes, ld, sh, w), G.subtract(List.length(&2, D.Shell, sh), 1n), Q.predecessor(List.length(&2, D.Shell, sh)), C.loadproof.predecessor(List.length(&2, D.Shell, sh)))
          +hosted : {shuffle.width(k, h2, notes, ld, sh, Q.predecessor(List.length(&2, D.Shell, sh))) == shuffle.width(k, A.ref_host(removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index)), notes, ld, sh, Q.predecessor(List.length(&2, D.Shell, sh))) : R.RefState} = Equal.cong(H.Host, R.RefState, h => shuffle.width(k, h, notes, ld, sh, Q.predecessor(List.length(&2, D.Shell, sh))), h2, A.ref_host(removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index)), removed.host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index))
          +shaped : A.Shape(removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index)) = shape.removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index, shape)
          +rest : {shuffle.width(k, A.ref_host(removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index)), notes, ld, sh, Q.predecessor(List.length(&2, D.Shell, sh))) == A.ref(M.shuffle(removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index), ld, sh, Q.predecessor(List.length(&2, D.Shell, sh)))) : R.RefState} = shuffle.close(Q.predecessor(List.length(&2, D.Shell, sh)), removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index), ld, sh, k, shaped, quiet)
          Equal.trans(R.RefState, shuffle.ref(k, h2, notes, ld_r), shuffle.ref(k, h2, notes, ld), A.ref(M.shuffle(removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index), ld, sh, Q.predecessor(List.length(&2, D.Shell, sh)))), loaded, Equal.trans(R.RefState, shuffle.ref(k, h2, notes, ld), shuffle.shells(k, h2, notes, ld, sh), A.ref(M.shuffle(removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index), ld, sh, Q.predecessor(List.length(&2, D.Shell, sh)))), shelled, Equal.trans(R.RefState, shuffle.shells(k, h2, notes, ld, sh), shuffle.width(k, h2, notes, ld, sh, Q.predecessor(List.length(&2, D.Shell, sh))), A.ref(M.shuffle(removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index), ld, sh, Q.predecessor(List.length(&2, D.Shell, sh)))), narrowed, Equal.trans(R.RefState, shuffle.width(k, h2, notes, ld, sh, Q.predecessor(List.length(&2, D.Shell, sh))), shuffle.width(k, A.ref_host(removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index)), notes, ld, sh, Q.predecessor(List.length(&2, D.Shell, sh))), A.ref(M.shuffle(removed(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, index), ld, sh, Q.predecessor(List.length(&2, D.Shell, sh)))), hosted, rest))))


def batch.pick(+k: Nat, +s: S.State, +index: Nat, +m: Maybe<&2, H.Batch>) -> R.RefState:
  R.settle(Nat.add(8n, k), R.GenerateRandomSequence.batch(R.RefState{A.ref_host(s), R.GenerateRandomSequence{R.BatchChosen{index}}, S.state.notes(s)}, index, m))

def batch.close(+s: S.State, +index: Nat, +k: Nat, +shape: A.Shape(s), +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {R.settle(Nat.add(9n, k), R.RefState{A.ref_host(s), R.GenerateRandomSequence{R.BatchChosen{index}}, S.state.notes(s)}) == A.ref(M.batch(s, index)) : R.RefState}:
  +deck : List<&2, S.Batch> = S.world.deck(S.state.world(s))
  +read : {G.nth(H.Batch, H.host.deck(A.ref_host(s)), index) == A.found_batch(Q.nth(S.Batch, deck, index)) : Maybe<&2, H.Batch>} = Equal.trans(Maybe<&2, H.Batch>, G.nth(H.Batch, H.host.deck(A.ref_host(s)), index), G.nth(H.Batch, A.batches(deck), index), A.found_batch(Q.nth(S.Batch, deck, index)), Equal.cong(List<&2, H.Batch>, Maybe<&2, H.Batch>, d => G.nth(H.Batch, d, index), H.host.deck(A.ref_host(s)), A.batches(deck), deck.eq(s)), C.loadproof.batch_nth(deck, index))
  Equal.trans(R.RefState, batch.pick(k, s, index, G.nth(H.Batch, H.host.deck(A.ref_host(s)), index)), batch.pick(k, s, index, A.found_batch(Q.nth(S.Batch, deck, index))), A.ref(M.batch(s, index)), Equal.cong(Maybe<&2, H.Batch>, R.RefState, m => batch.pick(k, s, index, m), G.nth(H.Batch, H.host.deck(A.ref_host(s)), index), A.found_batch(Q.nth(S.Batch, deck, index)), read), batch.found.close(Q.nth(S.Batch, deck, index), s, index, k, shape, quiet))

def batch.at(+h: H.Host, +deck: List<&2, H.Batch>, +notes: A.Notes()) -> R.RefState:
  R.RefState{h, A.batch.frame(deck), notes}

def batch.host(+h: H.Host, +notes: A.Notes()) -> R.RefState:
  R.RefState{h, A.batch.frame(H.host.deck(h)), notes}

def ready.close(+cards: List<&2, S.Batch>, +s: S.State, +k: Nat, +shape: A.Shape(s), +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}, +e: {H.host.deck(A.ref_host(s)) == A.batches(cards) : List<&2, H.Batch>}) -> {R.settle(Nat.add(9n, k), R.GenerateRandomSequence.request(R.RefState{A.ref_host(s), R.GenerateRandomSequence{R.SelectBatch{}}, S.state.notes(s)}, A.batches(cards))) == A.ref(M.load.ready(s, cards)) : R.RefState}:
  match cards:
    case Nil{}:
      blocked.close(s, Nat.add(9n, k), quiet)
    case S.Batch{+id, +l} <> Nil{}:
      batch.close(s, 0n, k, shape, quiet)
    case S.Batch{+id0, +l0} <> S.Batch{+id1, +l1} <> +rest:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          +cards_r : List<&2, H.Batch> = A.batches(S.Batch{id0, l0} <> S.Batch{id1, l1} <> rest)
          +h : H.Host = A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs})
          +h0 : H.Host = A.host.at(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, grabs, None{})
          +waited : {R.settle(Nat.add(8n, k), batch.at(h, cards_r, notes)) == batch.at(h, cards_r, notes) : R.RefState} = settle.await(Nat.add(8n, k), h, D.Draw{D.SequenceBatch{}, D.Range{0n, List.length(&2, H.Batch, A.batches(rest))}}, D.Loading{}, R.SequenceBatchResult{}, notes)
          +decked : {batch.at(h, cards_r, notes) == batch.host(h, notes) : R.RefState} = Equal.cong(List<&2, H.Batch>, R.RefState, d => batch.at(h, d, notes), cards_r, H.host.deck(h), Equal.sym(List<&2, H.Batch>, H.host.deck(h), cards_r, e))
          +held : {batch.host(h, notes) == batch.host(h0, notes) : R.RefState} = Equal.cong(H.Host, R.RefState, x => batch.host(x, notes), h, h0, quiet.host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, quiet))
          Equal.trans(R.RefState, R.settle(Nat.add(8n, k), batch.at(h, cards_r, notes)), batch.at(h, cards_r, notes), batch.host(h0, notes), waited, Equal.trans(R.RefState, batch.at(h, cards_r, notes), batch.host(h, notes), batch.host(h0, notes), decked, held))

def shape.decks(+s: S.State, +d: S.Decks, +shape: A.Shape(s)) -> A.Shape(S.state.set_world(s, S.world.set_decks(S.state.world(s), d))):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      shape

def shape.begin(+s: S.State, +index: Nat, +shape: A.Shape(s)) -> A.Shape(S.state.set_world(s, S.world.set_first_sequence(S.world.set_load_index(S.state.world(s), index), False{}))):
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, S.Grabs{+dist, +grabbing, +holding, +granted, +intake}}:
      shape

def refill.at(+k: Nat, +s: S.State, +d: List<&2, H.Batch>) -> R.RefState:
  R.settle(Nat.add(9n, k), R.GenerateRandomSequence.refill(R.RefState{A.ref_host(s), R.GenerateRandomSequence{R.SelectBatch{}}, S.state.notes(s)}, d))

def ready.ref(+k: Nat, +h: H.Host, +notes: A.Notes()) -> R.RefState:
  R.settle(Nat.add(9n, k), R.GenerateRandomSequence.request(R.RefState{h, R.GenerateRandomSequence{R.SelectBatch{}}, notes}, H.host.deck(h)))

def ready.deck(+k: Nat, +s: S.State, +d: List<&2, H.Batch>) -> R.RefState:
  R.settle(Nat.add(9n, k), R.GenerateRandomSequence.request(R.RefState{A.ref_host(s), R.GenerateRandomSequence{R.SelectBatch{}}, S.state.notes(s)}, d))

def refill.close(+cards: List<&2, S.Batch>, +s: S.State, +k: Nat, +shape: A.Shape(s), +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}, +e: {H.host.deck(A.ref_host(s)) == A.batches(cards) : List<&2, H.Batch>}) -> {R.settle(Nat.add(10n, k), R.RefState{A.ref_host(s), R.GenerateRandomSequence{R.SelectBatch{}}, S.state.notes(s)}) == A.ref(M.load.refill(s, cards)) : R.RefState}:
  match cards:
    case Nil{}:
      match s:
        case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
          +read : {refill.at(k, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, H.host.deck(A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}))) == refill.at(k, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, Nil{}) : R.RefState} = Equal.cong(List<&2, H.Batch>, R.RefState, d => refill.at(k, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, d), H.host.deck(A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs})), Nil{}, e)
          +full : {refill.at(k, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, Nil{}) == ready.ref(k, A.ref_host(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full()))), notes) : R.RefState} = Equal.cong(H.Decks, R.RefState, d => ready.ref(k, H.host.set_decks(A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}), d), notes), H.MakeSequenceCopies(), A.decks(Q.decks.full()), C.loadproof.full_decks())
          +decked : {ready.ref(k, A.ref_host(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full()))), notes) == ready.deck(k, S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())), A.batches(S.world.deck(S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())))) : R.RefState} = Equal.cong(List<&2, H.Batch>, R.RefState, d => ready.deck(k, S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())), d), H.host.deck(A.ref_host(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())))), A.batches(S.world.deck(S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full()))), deck.eq(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full()))))
          +rest : {ready.deck(k, S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())), A.batches(S.world.deck(S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())))) == A.ref(M.load.ready(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())), S.world.deck(S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())))) : R.RefState} = ready.close(S.world.deck(S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())), S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())), k, shape.decks(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, Q.decks.full(), shape), quiet, deck.eq(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full()))))
          Equal.trans(R.RefState, refill.at(k, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, H.host.deck(A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}))), refill.at(k, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, Nil{}), A.ref(M.load.ready(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())), S.world.deck(S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())))), read, Equal.trans(R.RefState, refill.at(k, S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, Nil{}), ready.ref(k, A.ref_host(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full()))), notes), A.ref(M.load.ready(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())), S.world.deck(S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())))), full, Equal.trans(R.RefState, ready.ref(k, A.ref_host(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full()))), notes), ready.deck(k, S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())), A.batches(S.world.deck(S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())))), A.ref(M.load.ready(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())), S.world.deck(S.world.set_decks(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.decks.full())))), decked, rest)))
    case S.Batch{+id, +l} <> +rest:
      +read : {refill.at(k, s, H.host.deck(A.ref_host(s))) == refill.at(k, s, A.batches(S.Batch{id, l} <> rest)) : R.RefState} = Equal.cong(List<&2, H.Batch>, R.RefState, d => refill.at(k, s, d), H.host.deck(A.ref_host(s)), A.batches(S.Batch{id, l} <> rest), e)
      Equal.trans(R.RefState, refill.at(k, s, H.host.deck(A.ref_host(s))), refill.at(k, s, A.batches(S.Batch{id, l} <> rest)), A.ref(M.load.ready(s, S.Batch{id, l} <> rest)), read, ready.close(S.Batch{id, l} <> rest, s, k, shape, quiet, e))

def select.at(+k: Nat, +h: H.Host, +notes: A.Notes()) -> R.RefState:
  R.settle(Nat.add(10n, k), R.RefState{h, R.GenerateRandomSequence{R.SelectBatch{}}, notes})

# L11: the load closure, from MainRoutine_LoadShotgun to the next request.
def load.close(+s: S.State, +k: Nat, +shape: A.Shape(s), +quiet: {A.turn.holder(S.state.phase(s)) == None{} : Maybe<&2, D.Seat>}) -> {R.settle(Nat.add(11n, k), R.RefState{A.ref_host(s), R.MainRoutine_LoadShotgun{}, S.state.notes(s)}) == A.ref(M.load.begin(s)) : R.RefState}:
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, +players, +phase, +notes, +grabs}:
      +h : H.Host = A.ref_host(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs})
      +next : {select.at(k, H.host.set_first_sequence(H.host.set_load_index(h, R.IncrementActiveSequenceIndex(first, load)), False{}), notes) == select.at(k, A.ref_host(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_first_sequence(S.world.set_load_index(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.load.next(first, load)), False{}))), notes) : R.RefState} = Equal.cong(Nat, R.RefState, n => select.at(k, H.host.set_first_sequence(H.host.set_load_index(h, n), False{}), notes), R.IncrementActiveSequenceIndex(first, load), Q.load.next(first, load), C.loadproof.load_next(first, load))
      Equal.trans(R.RefState, select.at(k, H.host.set_first_sequence(H.host.set_load_index(h, R.IncrementActiveSequenceIndex(first, load)), False{}), notes), select.at(k, A.ref_host(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_first_sequence(S.world.set_load_index(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.load.next(first, load)), False{}))), notes), A.ref(M.load.begin(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs})), next, refill.close(S.world.deck(S.world.set_first_sequence(S.world.set_load_index(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.load.next(first, load)), False{})), S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_first_sequence(S.world.set_load_index(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.load.next(first, load)), False{})), k, shape.begin(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, Q.load.next(first, load), shape), quiet, deck.eq(S.state.set_world(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}, S.world.set_first_sequence(S.world.set_load_index(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, Q.load.next(first, load)), False{})))))

def load.close.ctx(+s: S.State, +ctx: GP.Ctx(s), +k: Nat) -> {A.close(Nat.add(11n, k), s, R.MainRoutine_LoadShotgun{}) == A.ref(M.load.begin(s)) : R.RefState}:
  match ctx:
    case Tuple{+shape, +quiet}:
      load.close(s, k, shape, quiet)

def load.closure() -> GP.LoadClosure():
  +s => +ctx => +k => load.close.ctx(s, ctx, k)

# step_matches at the Grab and NeedItem points, with the load closure and
# its validity proven above.
def step.grab(+world: S.World, +players: S.Players, +needs: D.Ring<&2, List<&2, S.GrabOption>>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.Grab{needs}, notes, grabs})) -> A.Simulation(S.State{world, players, S.Grab{needs}, notes, grabs}, n):
  ISP.step.grab(world, players, needs, notes, grabs, n, valid, load.closure(), load.valid())

def step.item(+world: S.World, +players: S.Players, +seat: D.Seat, +first: D.Item, +second: D.Item, +rest: List<&2, D.Item>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.Valid(S.State{world, players, S.NeedItem{seat, first, second, rest}, notes, grabs})) -> A.Simulation(S.State{world, players, S.NeedItem{seat, first, second, rest}, notes, grabs}, n):
  ISP.step.item(world, players, seat, first, second, rest, notes, grabs, n, valid, load.closure(), load.valid())
