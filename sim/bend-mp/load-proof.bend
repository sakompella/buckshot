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
import ./ref/items.bend as RI
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
