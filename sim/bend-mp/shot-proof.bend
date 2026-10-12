import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/main.bend as M
import ./sm/rules.bend as Q

def true_backwards(+value: Bool, accepted: {value == True{} : Bool}) -> {True{} == value : Bool}:
  %accepted : {_ == value : Bool}
  {==}

def subtract_matches(+left: Nat, +right: Nat) -> {Q.subtract(left, right) == A.ref_subtract(left, right) : Nat}:
  match left right:
    case 0n 0n:
      {==}
    case 0n 1n+right:
      {==}
    case 1n+left 0n:
      {==}
    case 1n+left 1n+right:
      subtract_matches(left, right)

def subtract_zero(hp: Nat) -> {Q.subtract(hp, 0n) == hp : Nat}:
  match hp:
    case 0n:
      {==}
    case 1n+hp:
      {==}

def health_matches(shell: D.Shell, hp: Nat, damage: D.Damage) -> {Q.shot.health(shell, hp, damage) == A.ref_shot_health(shell, hp, damage) : Nat}:
  match shell hp damage:
    case D.Blank{} _ _:
      {==}
    case D.Live{} 0n D.Single{}:
      {==}
    case D.Live{} 0n D.Double{}:
      {==}
    case D.Live{} 1n+hp D.Single{}:
      subtract_zero(hp)
    case D.Live{} 1n+0n D.Double{}:
      {==}
    case D.Live{} 1n+1n+hp D.Double{}:
      subtract_zero(hp)

def passes_matches(shell: D.Shell, same: Bool) -> {Q.shot.passes(shell, same) == A.ref_shot_passes(shell, same) : Bool}:
  match shell same:
    case D.Live{} False{}:
      {==}
    case D.Live{} True{}:
      {==}
    case D.Blank{} False{}:
      {==}
    case D.Blank{} True{}:
      {==}

def death_first_matches(+state: S.State, +seat: D.Seat, +checking: Bool) -> {A.machine_prefix(M.death.remember(state, seat, checking)) == A.ref_death_first(state, seat, checking) : A.Prefix}:
  match state:
    case S.State{S.World{config, before, round, index, first, hp, recipient, turn, direction, died, check, amount, saw, gun, shown, deck}, players, phase, notes, grabs}:
      match checking:
        case False{}:
          {==}
        case True{}:
          {==}

def death_matches(+state: S.State, +target: D.Seat, +shell: D.Shell, +hp: Nat) -> {A.machine_prefix(M.death(state, target, shell, hp)) == A.ref_death(state, target, shell, hp) : A.Prefix}:
  match state:
    case S.State{S.World{config, before, round, index, first, health, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}:
      match checking shell hp:
        case False{} D.Blank{} _:
          {==}
        case True{} D.Blank{} _:
          {==}
        case False{} D.Live{} 1n+hp:
          {==}
        case True{} D.Live{} 1n+hp:
          {==}
        case False{} D.Live{} 0n:
          {==}
        case True{} D.Live{} 0n:
          {==}

def finished_stable(+fuel: Nat, +h: A.RefHost(), +notes: List<&2, D.Note>) -> {A.ref_finished(h, notes, fuel) == A.finished(h, notes) : A.Ref()}:
  match fuel:
    case 0n:
      {==}
    case 1n+k:
      {==}

def ref_final_gate(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, +k: Nat) -> {A.ref_win_gate(world, seats, seat, notes, k, True{}) == A.expected_win(world, seats, seat, notes) : A.Ref()}:
  match world:
    case S.World{config, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      finished_stable(k, A.won_host(world, seats, seat), A.win_notes(world, seat, notes))

def ref_final_closed(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, +k: Nat, final: {A.final_condition(world) == True{} : Bool}) -> {A.ref_win(world, seats, seat, notes, 4n+k) == A.expected_win(world, seats, seat, notes) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %true_backwards(A.final_condition(world), final) : {A.ref_win_gate(world, seats, seat, notes, k, _) == A.expected_win(world, seats, seat, notes) : A.Ref()}
      ref_final_gate(world, seats, seat, notes, k)

def machine_final_gate(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +phase: S.Phase, +notes: List<&2, D.Note>, present: A.seated(A.world_for(world, seats), seat)) -> {A.machine_win_gate(world, seats, seat, phase, notes, True{}) == A.expected_win(world, seats, seat, notes) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats seat:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match present:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match present:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
          match present:
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}

def machine_final_closed(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +phase: S.Phase, +notes: List<&2, D.Note>, +present: A.seated(A.world_for(world, seats), seat), final: {A.final_condition(world) == True{} : Bool}) -> {A.ref(M.win(A.pack(world, seats, phase, notes), seat)) == A.expected_win(world, seats, seat, notes) : A.Ref()}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      %true_backwards(A.final_condition(world), final) : {A.machine_win_gate(world, seats, seat, phase, notes, _) == A.expected_win(world, seats, seat, notes) : A.Ref()}
      machine_final_gate(world, seats, seat, phase, notes, present)

def ref_final_backwards(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +notes: List<&2, D.Note>, +k: Nat, final: {A.final_condition(world) == True{} : Bool}) -> {A.expected_win(world, seats, seat, notes) == A.ref_win(world, seats, seat, notes, 4n+k) : A.Ref()}:
  %ref_final_closed(world, seats, seat, notes, k, final) : {_ == A.ref_win(world, seats, seat, notes, 4n+k) : A.Ref()}
  {==}

def final_win_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +seat: D.Seat, +phase: S.Phase, +notes: List<&2, D.Note>, +k: Nat, +present: A.seated(A.world_for(world, seats), seat), +final: {A.final_condition(world) == True{} : Bool}) -> {A.ref(M.win(A.pack(world, seats, phase, notes), seat)) == A.ref_win(world, seats, seat, notes, 4n+k) : A.Ref()}:
  %ref_final_backwards(world, seats, seat, notes, k, final) : {A.ref(M.win(A.pack(world, seats, phase, notes), seat)) == _ : A.Ref()}
  machine_final_closed(world, seats, seat, phase, notes, present, final)

def health_write_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +seat: D.Seat, +hp: Nat, present: A.seated(A.world_for(world, seats), seat)) -> {A.machine_prefix(A.machine_health_write(world, seats, phase, notes, seat, hp)) == A.prefix(A.ref_health_write(world, seats, phase, notes, seat, hp)) : A.Prefix}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats seat:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match present:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match present:
        case D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{}:
          {==}
        case D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
          match present:
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}

def written_live_death_matches(+world: S.World, +seats: D.Ring<&2, A.CoreSeat>, +phase: S.Phase, +notes: List<&2, D.Note>, +target: D.Seat, present: A.seated(A.world_for(world, seats), target)) -> {A.machine_prefix(M.death(A.machine_health_write(world, seats, phase, notes, target, 0n), target, D.Live{}, 0n)) == A.ref_written_death(world, seats, phase, notes, target, D.Live{}, 0n) : A.Prefix}:
  match world:
    case S.World{D.Config{table, plan}, before, round, index, first, hp, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match checking seats target:
        case False{} D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match present:
        case False{} D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case False{} D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match present:
        case False{} D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}
        case False{} D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          {==}
        case False{} D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          {==}
        case False{} D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{}:
          {==}
        case False{} D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
          match present:
        case False{} D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case False{} D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case False{} D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case False{} D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}
        case True{} D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          match present:
        case True{} D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case True{} D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          match present:
        case True{} D.Duo{A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}
        case True{} D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat0{}:
          {==}
        case True{} D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat1{}:
          {==}
        case True{} D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat2{}:
          {==}
        case True{} D.Trio{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}} D.Seat3{}:
          match present:
        case True{} D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat0{}:
          {==}
        case True{} D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat1{}:
          {==}
        case True{} D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat2{}:
          {==}
        case True{} D.Quad{A.CoreSeat{h0, j0, c0, p0, s0, t0}, A.CoreSeat{h1, j1, c1, p1, s1, t1}, A.CoreSeat{h2, j2, c2, p2, s2, t2}, A.CoreSeat{h3, j3, c3, p3, s3, t3}} D.Seat3{}:
          {==}
