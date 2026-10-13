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
import ./sm/point.bend as V
import ./grab-proof.bend as GP
import ./core-proof.bend as C

# Internal lemmas toward step_matches for item configs, under A.ValidItems.
# Bodies marked generated in tools/proof_cases.py are owned by that script.

# The no-item Valid is a special case of ValidItems: its normal form packs
# empty slots, initial Grabs and a world tied to the seat ring.

def items.idle_uses(+world: S.World, +seats: A.Seats(), +seat: D.Seat, +notes: A.Notes()) -> {I.uses(A.pack(A.world_for(world, seats), seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes), seat) == Nil{} : List<&2, S.IdleOption>}:
  match seats seat:
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}} D.Seat0{}:
      {==}
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}} D.Seat1{}:
      {==}
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}} D.Seat2{}:
      {==}
    case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}} D.Seat3{}:
      {==}
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}} D.Seat0{}:
      {==}
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}} D.Seat1{}:
      {==}
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}} D.Seat2{}:
      {==}
    case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}} D.Seat3{}:
      {==}
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}} D.Seat0{}:
      {==}
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}} D.Seat1{}:
      {==}
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}} D.Seat2{}:
      {==}
    case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}} D.Seat3{}:
      {==}

def items.pack_shape(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes()) -> A.Shape(A.pack(A.world_for(world, seats), seats, phase, notes)):
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match seats:
        case D.Duo{S.Seat{h1, j1, p1, s1}, S.Seat{h3, j3, p3, s3}}:
          ({==}, ({==}, ({==}, ({==}, {==}))))
        case D.Trio{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}}:
          ({==}, ({==}, ({==}, ({==}, {==}))))
        case D.Quad{S.Seat{h0, j0, p0, s0}, S.Seat{h1, j1, p1, s1}, S.Seat{h2, j2, p2, s2}, S.Seat{h3, j3, p3, s3}}:
          ({==}, ({==}, ({==}, ({==}, {==}))))

def items.pack_valid(+world: S.World, +seats: A.Seats(), +phase: S.Phase, +notes: A.Notes(), +bounded: {Nat.is_lt(S.world.round_index(world), D.plan.length(S.world.plan(world))) == True{} : Bool}, +ready: {A.phase_ready(phase, world) == True{} : Bool}) -> A.ValidItems(A.pack(A.world_for(world, seats), seats, A.canonical_phase(phase), notes)):
  match world:
    case S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}:
      match phase:
        case S.NeedFirst{}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.NeedFirst{}, notes), (bounded, ready)))
        case S.NeedHealth{}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.NeedHealth{}, notes), (bounded, ready)))
        case S.NeedAmount{}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.NeedAmount{}, notes), (bounded, ready)))
        case S.NeedBatch{}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.NeedBatch{}, notes), (bounded, ready)))
        case S.NeedSwap{_, _, 0n}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.NeedSwap{+swap_load, +shells, 1n+i}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.NeedSwap{swap_load, shells, 1n+i}, notes), (bounded, ready)))
        case S.Idle{+seat, options}:
          (Equal.cong(List<&2, S.IdleOption>, S.State, xs => S.State{A.world_for(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats), A.players.free(seats), S.Idle{seat, D.NonEmpty{S.TakeGun{}, xs}}, notes, A.grabs(seats)}, I.uses(A.pack(A.world_for(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats), seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes), seat), Nil{}, items.idle_uses(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, seat, notes)), (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}, notes), (bounded, ready)))
        case S.Aim{+seat}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Aim{seat}, notes), (bounded, ready)))
        case S.Ended{}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Ended{}, notes), (bounded, ready)))
        case S.Blocked{+holder}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{holder}, notes), (bounded, ready)))
        case S.NeedTurnAmount{_, _, _}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.Grab{_}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.NeedItem{_, _, _, _}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.NeedPhone{_, _, _}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.JamPick{_, _}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))
        case S.StealPick{_, _}:
          ({==}, (items.pack_shape(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, seats, S.Blocked{None{}}, notes), (bounded, {==})))

def valid.items(+s: S.State, +valid: A.Valid(s)) -> A.ValidItems(s):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match valid:
        case Tuple{normal, Tuple{_, Tuple{bounded, ready}}}:
          %normal : A.ValidItems(_)
          items.pack_valid(world, players, phase, notes, bounded, ready)

# Part 1 of SimulationItems at the handout's request points: the
# reference's answer equals the machine's, mapped.

def stepped.ref(+x: R.RefState, +out: S.State, +e: {x == A.ref(out) : R.RefState}) -> {R.stepped(x) == A.stepped(S.state.stepped(out)) : A.RefStep()}:
  match out:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      Equal.cong(R.RefState, A.RefStep(), y => R.stepped(y), x, A.ref(S.State{world, players, phase, notes, grabs}), e)

# The Grab menus of a world, seat ring and Grabs, and the Grab request point
# whose stored menus are them (the ValidItems normal form).
def needs.at(+world: S.World, +players: S.Players, +grabs: S.Grabs) -> D.Ring<&2, List<&2, S.GrabOption>>:
  I.grab.needs(S.State{world, players, S.Ended{}, Nil{}, grabs})

def grab.at(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs) -> S.State:
  S.State{world, players, S.Grab{needs.at(world, players, grabs)}, notes, grabs}

def grab.ref(+world: S.World, +players: S.Players, +grabs: S.Grabs) -> R.RefState:
  R.RefState{A.ref_host(grab.at(world, players, Nil{}, grabs)), R.Await{D.Choose{I.grab.menus(needs.at(world, players, grabs))}, D.Distributing{}, R.ItemGrab_Packet{}}, Nil{}}

def grab.take.answer(+world: S.World, +players: S.Players, +grabs: S.Grabs, +seat: D.Seat, +index: Nat, +sel: GP.Selected(needs.at(world, players, grabs), D.Choice{seat, index, D.Grab{}}), +ctx: GP.Ctx(grab.at(world, players, Nil{}, grabs)), load: GP.LoadClosure()) -> {R.stepped(R.settle(96n, R.answer.move(grab.ref(world, players, grabs), D.Choice{seat, index, D.Grab{}}))) == A.stepped(S.state.stepped(M.answer.choice(grab.at(world, players, Nil{}, grabs), D.Choice{seat, index, D.Grab{}}))) : A.RefStep()}:
  +s : S.State = grab.at(world, players, Nil{}, grabs)
  +accepted : {R.VerifyPacket.grab(H.host.props(A.ref_host(s), seat), D.Grab{}) == True{} : Bool} = GP.accept.at(s, seat, index, D.Grab{}, GP.ctx.shape(s, ctx), sel)
  +verified : {R.stepped(R.settle(96n, R.answer.move(grab.ref(world, players, grabs), D.Choice{seat, index, D.Grab{}}))) == R.stepped(A.close(95n, s, R.GetItemToGrab{seat})) : A.RefStep()} = Equal.cong(Bool, A.RefStep(), b => R.stepped(R.settle(96n, R.answer.move.accepted(grab.ref(world, players, grabs), D.Choice{seat, index, D.Grab{}}, b))), R.VerifyPacket.grab(H.host.props(A.ref_host(s), seat), D.Grab{}), True{}, accepted)
  +closed : {R.stepped(A.close(95n, s, R.GetItemToGrab{seat})) == A.stepped(S.state.stepped(M.grab.take(s, seat))) : A.RefStep()} = stepped.ref(A.close(95n, s, R.GetItemToGrab{seat}), M.grab.take(s, seat), GP.take.close(s, seat, ctx, load, 81n))
  +picked : {A.stepped(S.state.stepped(M.answer.choice(s, D.Choice{seat, index, D.Grab{}}))) == A.stepped(S.state.stepped(M.grab.take(s, seat))) : A.RefStep()} = Equal.cong(Maybe<&2, S.GrabOption>, A.RefStep(), o => A.stepped(S.state.stepped(M.grab.selected(s, seat, o))), I.grab.nth(Q.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs.at(world, players, grabs), seat), Nil{}), index), Some{S.TakeItem{}}, sel)
  Equal.trans(A.RefStep(), R.stepped(R.settle(96n, R.answer.move(grab.ref(world, players, grabs), D.Choice{seat, index, D.Grab{}}))), R.stepped(A.close(95n, s, R.GetItemToGrab{seat})), A.stepped(S.state.stepped(M.answer.choice(s, D.Choice{seat, index, D.Grab{}}))), verified, Equal.trans(A.RefStep(), R.stepped(A.close(95n, s, R.GetItemToGrab{seat})), A.stepped(S.state.stepped(M.grab.take(s, seat))), A.stepped(S.state.stepped(M.answer.choice(s, D.Choice{seat, index, D.Grab{}}))), closed, Equal.sym(A.RefStep(), A.stepped(S.state.stepped(M.answer.choice(s, D.Choice{seat, index, D.Grab{}}))), A.stepped(S.state.stepped(M.grab.take(s, seat))), picked)))

def grab.place.answer(+world: S.World, +players: S.Players, +grabs: S.Grabs, +seat: D.Seat, +index: Nat, +slot: D.Slot, +sel: GP.Selected(needs.at(world, players, grabs), D.Choice{seat, index, D.Place{slot}}), +ctx: GP.Ctx(grab.at(world, players, Nil{}, grabs)), load: GP.LoadClosure()) -> {R.stepped(R.settle(96n, R.answer.move(grab.ref(world, players, grabs), D.Choice{seat, index, D.Place{slot}}))) == A.stepped(S.state.stepped(M.answer.choice(grab.at(world, players, Nil{}, grabs), D.Choice{seat, index, D.Place{slot}}))) : A.RefStep()}:
  +s : S.State = grab.at(world, players, Nil{}, grabs)
  +accepted : {R.VerifyPacket.grab(H.host.props(A.ref_host(s), seat), D.Place{slot}) == True{} : Bool} = GP.accept.at(s, seat, index, D.Place{slot}, GP.ctx.shape(s, ctx), sel)
  +verified : {R.stepped(R.settle(96n, R.answer.move(grab.ref(world, players, grabs), D.Choice{seat, index, D.Place{slot}}))) == R.stepped(A.close(95n, s, R.IsPlacingLastItem{seat, slot})) : A.RefStep()} = Equal.cong(Bool, A.RefStep(), b => R.stepped(R.settle(96n, R.answer.move.accepted(grab.ref(world, players, grabs), D.Choice{seat, index, D.Place{slot}}, b))), R.VerifyPacket.grab(H.host.props(A.ref_host(s), seat), D.Place{slot}), True{}, accepted)
  +closed : {R.stepped(A.close(95n, s, R.IsPlacingLastItem{seat, slot})) == A.stepped(S.state.stepped(M.grab.place(s, seat, slot))) : A.RefStep()} = stepped.ref(A.close(95n, s, R.IsPlacingLastItem{seat, slot}), M.grab.place(s, seat, slot), GP.place.close(s, seat, slot, ctx, load, 73n))
  +picked : {A.stepped(S.state.stepped(M.answer.choice(s, D.Choice{seat, index, D.Place{slot}}))) == A.stepped(S.state.stepped(M.grab.place(s, seat, slot))) : A.RefStep()} = Equal.cong(Maybe<&2, S.GrabOption>, A.RefStep(), o => A.stepped(S.state.stepped(M.grab.selected(s, seat, o))), I.grab.nth(Q.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs.at(world, players, grabs), seat), Nil{}), index), Some{S.PutAt{slot}}, sel)
  Equal.trans(A.RefStep(), R.stepped(R.settle(96n, R.answer.move(grab.ref(world, players, grabs), D.Choice{seat, index, D.Place{slot}}))), R.stepped(A.close(95n, s, R.IsPlacingLastItem{seat, slot})), A.stepped(S.state.stepped(M.answer.choice(s, D.Choice{seat, index, D.Place{slot}}))), verified, Equal.trans(A.RefStep(), R.stepped(A.close(95n, s, R.IsPlacingLastItem{seat, slot})), A.stepped(S.state.stepped(M.grab.place(s, seat, slot))), A.stepped(S.state.stepped(M.answer.choice(s, D.Choice{seat, index, D.Place{slot}}))), closed, Equal.sym(A.RefStep(), A.stepped(S.state.stepped(M.answer.choice(s, D.Choice{seat, index, D.Place{slot}}))), A.stepped(S.state.stepped(M.grab.place(s, seat, slot))), picked)))

# Shape reads only the world, the seat ring and the Grabs rings.
def shape.move(+world: S.World, +players: S.Players, +phase: S.Phase, +notes: A.Notes(), +grabs: S.Grabs, +phase2: S.Phase, +notes2: A.Notes(), +shape: A.Shape(S.State{world, players, phase, notes, grabs})) -> A.Shape(S.State{world, players, phase2, notes2, grabs}):
  match grabs:
    case S.Grabs{+dist, +taking, +holding, +granted, +intake}:
      shape

def grab.choice.answer(+world: S.World, +players: S.Players, +grabs: S.Grabs, +seat: D.Seat, +index: Nat, +move: D.Move, +sel: GP.Selected(needs.at(world, players, grabs), D.Choice{seat, index, move}), +ctx: GP.Ctx(grab.at(world, players, Nil{}, grabs)), load: GP.LoadClosure()) -> {R.stepped(R.settle(96n, R.answer.move(grab.ref(world, players, grabs), D.Choice{seat, index, move}))) == A.stepped(S.state.stepped(M.answer.choice(grab.at(world, players, Nil{}, grabs), D.Choice{seat, index, move}))) : A.RefStep()}:
  match move:
    case D.Grab{}:
      grab.take.answer(world, players, grabs, seat, index, sel, ctx, load)
    case D.Place{+slot}:
      grab.place.answer(world, players, grabs, seat, index, slot, sel, ctx, load)
    case D.PickUp{}:
      match sel:
    case D.Shoot{target}:
      match sel:
    case D.UseItem{slot, item}:
      match sel:
    case D.JamTarget{target}:
      match sel:
    case D.Steal{owner, slot, item}:
      match sel:

def grab.picked.answer(+world: S.World, +players: S.Players, +grabs: S.Grabs, +picked: Maybe<&2, D.Choice>, +sel: GP.MaybeSelected(needs.at(world, players, grabs), picked), +ctx: GP.Ctx(grab.at(world, players, Nil{}, grabs)), load: GP.LoadClosure()) -> {R.stepped(R.settle(96n, R.answer.resolved(grab.ref(world, players, grabs), R.ItemGrab_Packet{}, D.resolve.choice(picked)))) == A.stepped(S.state.stepped(M.answer.resolved(grab.at(world, players, Nil{}, grabs), D.resolve.choice(picked)))) : A.RefStep()}:
  match picked:
    case None{}:
      {==}
    case Some{+choice}:
      match choice:
        case D.Choice{+seat, +index, +move}:
          grab.choice.answer(world, players, grabs, seat, index, move, sel, ctx, load)

def grab.any.answer(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +any: Bool, +e: {D.menus.any(D.ring.entries(List<&2, D.Move>, I.grab.menus(needs.at(world, players, grabs)))) == any : Bool}, +ctx: GP.Ctx(grab.at(world, players, Nil{}, grabs)), load: GP.LoadClosure()) -> {R.answer(R.RefState{A.ref_host(grab.at(world, players, notes, grabs)), R.Await{D.request.choose.any(any, I.grab.menus(needs.at(world, players, grabs))), D.Distributing{}, R.ItemGrab_Packet{}}, notes}, n) == A.stepped(M.answer.request(grab.at(world, players, notes, grabs), n, D.request.choose.any(any, I.grab.menus(needs.at(world, players, grabs))))) : A.RefStep()}:
  match any:
    case True{}:
      grab.picked.answer(world, players, grabs, D.choose(I.grab.menus(needs.at(world, players, grabs)), n), GP.sel.choose(needs.at(world, players, grabs), n), ctx, load)
    case False{}:
      Equal.cong(Bool, A.RefStep(), b => D.Stepped{R.RefState{A.ref_host(grab.at(world, players, notes, grabs)), R.Await{D.request.choose.any(b, I.grab.menus(needs.at(world, players, grabs))), D.Distributing{}, R.ItemGrab_Packet{}}, notes}, Nil{}}, False{}, D.menus.any(D.ring.entries(List<&2, D.Move>, I.grab.menus(needs.at(world, players, grabs)))), Equal.sym(Bool, D.menus.any(D.ring.entries(List<&2, D.Move>, I.grab.menus(needs.at(world, players, grabs)))), False{}, e))

def grab.answer(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +shape: A.Shape(grab.at(world, players, notes, grabs)), load: GP.LoadClosure()) -> {A.ref_answer(A.ref(grab.at(world, players, notes, grabs)), n) == A.stepped(M.answer(grab.at(world, players, notes, grabs), n)) : A.RefStep()}:
  grab.any.answer(world, players, notes, grabs, n, D.menus.any(D.ring.entries(List<&2, D.Move>, I.grab.menus(needs.at(world, players, grabs)))), {==}, (shape.move(world, players, S.Grab{needs.at(world, players, grabs)}, notes, grabs, S.Grab{needs.at(world, players, grabs)}, Nil{}, shape), {==}), load)

def nth.eq(-X: Data, +xs: List<&2, X>, +i: Nat) -> {G.nth(X, xs, i) == Q.nth(X, xs, i) : Maybe<&2, X>}:
  match xs i:
    case Nil{} _:
      {==}
    case x <> rest 0n:
      {==}
    case x <> +rest 1n+k:
      nth.eq(X, rest, k)

def item.at(+world: S.World, +players: S.Players, +seat: D.Seat, +first: D.Item, +second: D.Item, +rest: List<&2, D.Item>, +notes: A.Notes(), +grabs: S.Grabs) -> S.State:
  S.State{world, players, S.NeedItem{seat, first, second, rest}, notes, grabs}

def item.answer(+world: S.World, +players: S.Players, +seat: D.Seat, +first: D.Item, +second: D.Item, +rest: List<&2, D.Item>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +shape: A.Shape(item.at(world, players, seat, first, second, rest, notes, grabs)), load: GP.LoadClosure()) -> {A.ref_answer(A.ref(item.at(world, players, seat, first, second, rest, notes, grabs)), n) == A.stepped(M.answer(item.at(world, players, seat, first, second, rest, notes, grabs), n)) : A.RefStep()}:
  +s : S.State = item.at(world, players, seat, first, second, rest, Nil{}, grabs)
  +pool : List<&2, D.Item> = first <> second <> rest
  +value : Nat = D.draw.value(D.Range{0n, List.length(&2, D.Item, rest)}, n)
  +f : R.Frame = R.Await{D.Draw{D.ItemChoice{}, D.Range{0n, List.length(&2, D.Item, rest)}}, D.Distributing{}, R.ItemChoiceResult{seat, pool}}
  +ctx : GP.Ctx(s) = (shape.move(world, players, S.NeedItem{seat, first, second, rest}, notes, grabs, S.NeedItem{seat, first, second, rest}, Nil{}, shape), {==})
  +found : {R.stepped(R.settle(96n, R.GetItemToGrab.selected(R.RefState{A.ref_host(s), f, Nil{}}, seat, G.nth(D.Item, pool, value)))) == R.stepped(R.settle(96n, R.GetItemToGrab.selected(R.RefState{A.ref_host(s), f, Nil{}}, seat, Q.nth(D.Item, pool, value)))) : A.RefStep()} = Equal.cong(Maybe<&2, D.Item>, A.RefStep(), x => R.stepped(R.settle(96n, R.GetItemToGrab.selected(R.RefState{A.ref_host(s), f, Nil{}}, seat, x))), G.nth(D.Item, pool, value), Q.nth(D.Item, pool, value), nth.eq(D.Item, pool, value))
  +closed : {R.stepped(R.settle(96n, R.GetItemToGrab.selected(R.RefState{A.ref_host(s), f, Nil{}}, seat, Q.nth(D.Item, pool, value)))) == A.stepped(S.state.stepped(M.grab.chosen(s, seat, Q.nth(D.Item, pool, value)))) : A.RefStep()} = stepped.ref(R.settle(96n, R.GetItemToGrab.selected(R.RefState{A.ref_host(s), f, Nil{}}, seat, Q.nth(D.Item, pool, value))), M.grab.chosen(s, seat, Q.nth(D.Item, pool, value)), GP.chosen.close(s, seat, Q.nth(D.Item, pool, value), f, ctx, load, 83n))
  Equal.trans(A.RefStep(), R.stepped(R.settle(96n, R.GetItemToGrab.selected(R.RefState{A.ref_host(s), f, Nil{}}, seat, G.nth(D.Item, pool, value)))), R.stepped(R.settle(96n, R.GetItemToGrab.selected(R.RefState{A.ref_host(s), f, Nil{}}, seat, Q.nth(D.Item, pool, value)))), A.stepped(S.state.stepped(M.grab.chosen(s, seat, Q.nth(D.Item, pool, value)))), found, closed)

# Part 3: the handout's successors are valid request points. Pre is a
# closure context plus the round bound, which no handout write touches.

def Pre(+s: S.State) -> Data:
  Sigma<&2, &2, GP.Ctx(s), _ => A.Holds(A.bounded(s))>

def LoadValid() -> Type:
  @+s:S.State -> @+pre:Pre(s) -> A.ValidItems(M.load.begin(s))

def pre.stop(+s: S.State, +seat: D.Seat, +pre: Pre(s)) -> Pre(GP.stop.state(s, seat)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match pre:
        case Tuple{+ctx, +bounded}:
          (GP.ctx.stop(S.State{world, players, phase, notes, grabs}, seat, ctx), bounded)

def pre.give(+s: S.State, +seat: D.Seat, +item: D.Item, +pre: Pre(s)) -> Pre(GP.give.state(s, seat, item)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match pre:
        case Tuple{+ctx, +bounded}:
          (GP.ctx.give(S.State{world, players, phase, notes, grabs}, seat, item, ctx), bounded)

def pre.close(+s: S.State, +seat: D.Seat, +pre: Pre(s)) -> Pre(GP.close.state(s, seat)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match pre:
        case Tuple{+ctx, +bounded}:
          (GP.ctx.close(S.State{world, players, phase, notes, grabs}, seat, ctx), bounded)

def pre.put(+s: S.State, +seat: D.Seat, +fresh: D.Slots, +pre: Pre(s)) -> Pre(GP.put.state(s, seat, fresh)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match pre:
        case Tuple{+ctx, +bounded}:
          (GP.ctx.put(S.State{world, players, phase, notes, grabs}, seat, fresh, ctx), bounded)

def pre.done(+s: S.State, +pre: Pre(s)) -> Pre(GP.done.state(s)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match pre:
        case Tuple{+ctx, +bounded}:
          (GP.ctx.done(S.State{world, players, phase, notes, grabs}, ctx), bounded)

def pre.emit(+s: S.State, +event: D.GameEvent, +pre: Pre(s)) -> Pre(S.state.emit(s, event)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match pre:
        case Tuple{+ctx, +bounded}:
          (GP.ctx.emit(S.State{world, players, phase, notes, grabs}, event, ctx), bounded)

def pre.tell(+s: S.State, +seat: D.Seat, +secret: D.Secret, +pre: Pre(s)) -> Pre(S.state.tell(s, seat, secret)):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match pre:
        case Tuple{+ctx, +bounded}:
          (GP.ctx.tell(S.State{world, players, phase, notes, grabs}, seat, secret, ctx), bounded)

def pre.check.done(+s: S.State, +b: Bool, +pre: Pre(s)) -> Pre(M.grab.check.done(s, b)):
  match b:
    case True{}:
      pre.emit(GP.done.state(s), D.DistributionDone{}, pre.done(s, pre))
    case False{}:
      pre

def pre.check(+s: S.State, +pre: Pre(s)) -> Pre(M.grab.check(s)):
  pre.check.done(s, Bool.and(S.grabs.distributing(S.state.grabs(s)), I.finished(s)), pre)

def pre.end_all(+seats: List<&2, D.Seat>, +s: S.State, +pre: Pre(s)) -> Pre(M.grab.end_all(seats, s)):
  match seats:
    case Nil{}:
      pre
    case +seat <> +rest:
      pre.end_all(rest, S.state.emit(GP.close.state(s, seat), D.GrabbingEnded{seat}), pre.emit(GP.close.state(s, seat), D.GrabbingEnded{seat}, pre.close(s, seat, pre)))

# The request points the handout stops at.

def grab.point.valid(+s: S.State, +pre: Pre(s)) -> A.ValidItems(S.state.set_phase(s, S.Grab{I.grab.needs(s)})):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match pre:
        case Tuple{Tuple{+shape, _}, +bounded}:
          ({==}, (shape.move(world, players, phase, notes, grabs, S.Grab{I.grab.needs(S.State{world, players, phase, notes, grabs})}, notes, shape), (bounded, {==})))

def item.point.valid(+s: S.State, +seat: D.Seat, +first: D.Item, +second: D.Item, +rest: List<&2, D.Item>, +pre: Pre(s)) -> A.ValidItems(S.state.set_phase(s, S.NeedItem{seat, first, second, rest})):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match pre:
        case Tuple{Tuple{+shape, _}, +bounded}:
          ({==}, (shape.move(world, players, phase, notes, grabs, S.NeedItem{seat, first, second, rest}, notes, shape), (bounded, {==})))

def blocked.point.valid(+s: S.State, +pre: Pre(s)) -> A.ValidItems(S.state.set_phase(s, S.Blocked{None{}})):
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      match pre:
        case Tuple{Tuple{+shape, _}, +bounded}:
          ({==}, (shape.move(world, players, phase, notes, grabs, S.Blocked{None{}}, notes, shape), (bounded, {==})))

# The handout's closures end at valid request points.

def continue.ready.valid(+s: S.State, +d: Bool, +held: Bool, +pre: Pre(s), load: LoadValid()) -> A.ValidItems(M.grab.continue.ready(s, d, held)):
  match d held:
    case False{} False{}:
      load(s, pre)
    case True{} True{}:
      grab.point.valid(s, pre)
    case True{} False{}:
      grab.point.valid(s, pre)
    case False{} True{}:
      grab.point.valid(s, pre)

def continue.valid(+s: S.State, +pre: Pre(s), load: LoadValid()) -> A.ValidItems(M.grab.continue(s)):
  continue.ready.valid(s, S.grabs.distributing(S.state.grabs(s)), I.holders(D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(S.state.grabs(s)))), pre, load)

def give.valid(+s: S.State, +seat: D.Seat, +item: D.Item, +pre: Pre(s), load: LoadValid()) -> A.ValidItems(M.grab.give(s, seat, item)):
  continue.valid(S.state.emit(GP.give.state(s, seat, item), D.Granted{seat, item}), pre.emit(GP.give.state(s, seat, item), D.Granted{seat, item}, pre.give(s, seat, item, pre)), load)

def chosen.valid(+s: S.State, +seat: D.Seat, +found: Maybe<&2, D.Item>, +pre: Pre(s), load: LoadValid()) -> A.ValidItems(M.grab.chosen(s, seat, found)):
  match found:
    case Some{+item}:
      give.valid(s, seat, item, pre, load)
    case None{}:
      continue.valid(S.state.tell(s, seat, D.EmptyBriefcase{}), pre.tell(s, seat, D.EmptyBriefcase{}, pre), load)

def pool.valid(+s: S.State, +seat: D.Seat, +pool: List<&2, D.Item>, +pre: Pre(s), load: LoadValid()) -> A.ValidItems(M.grab.pool(s, seat, pool)):
  match pool:
    case Nil{}:
      chosen.valid(s, seat, None{}, pre, load)
    case +item <> Nil{}:
      give.valid(s, seat, item, pre, load)
    case +first <> +second <> +rest:
      item.point.valid(s, seat, first, second, rest, pre)

def take.valid(+s: S.State, +seat: D.Seat, +pre: Pre(s), load: LoadValid()) -> A.ValidItems(M.grab.take(s, seat)):
  pool.valid(GP.stop.state(s, seat), seat, I.pool(GP.stop.state(s, seat), seat), pre.stop(s, seat, pre), load)

def put.held.valid(+s: S.State, +seat: D.Seat, +slot: D.Slot, +held: Maybe<&2, D.Item>, +pre: Pre(s), load: LoadValid()) -> A.ValidItems(M.grab.put.held(s, seat, slot, held)):
  match held:
    case None{}:
      blocked.point.valid(s, pre)
    case Some{+item}:
      +fresh : D.Slots = I.slots.put(I.seat.slots(S.state.players(s), seat), slot, Some{item})
      continue.valid(S.state.emit(GP.put.state(s, seat, fresh), D.Placed{seat, slot, item}), pre.emit(GP.put.state(s, seat, fresh), D.Placed{seat, slot, item}, pre.put(s, seat, fresh, pre)), load)

def put.valid(+s: S.State, +seat: D.Seat, +slot: D.Slot, +pre: Pre(s), load: LoadValid()) -> A.ValidItems(M.grab.put(s, seat, slot)):
  put.held.valid(s, seat, slot, I.seat.holding(S.state.grabs(s), seat), pre, load)

def place.last.valid(+s: S.State, +seat: D.Seat, +slot: D.Slot, +last: Bool, +pre: Pre(s), load: LoadValid()) -> A.ValidItems(M.grab.place.last(s, seat, slot, last)):
  match last:
    case False{}:
      put.valid(s, seat, slot, pre, load)
    case True{}:
      +s0 : S.State = S.state.emit(GP.close.state(s, seat), D.GrabbingEnded{seat})
      +s1 : S.State = M.grab.check(s0)
      +pre1 : Pre(s1) = pre.check(s0, pre.emit(GP.close.state(s, seat), D.GrabbingEnded{seat}, pre.close(s, seat, pre)))
      +s2 : S.State = M.grab.end_all(I.stalled.seats(s1, seat), s1)
      put.valid(M.grab.check(s2), seat, slot, pre.check(s2, pre.end_all(I.stalled.seats(s1, seat), s1, pre1)), load)

def place.valid(+s: S.State, +seat: D.Seat, +slot: D.Slot, +pre: Pre(s), load: LoadValid()) -> A.ValidItems(M.grab.place(s, seat, slot)):
  place.last.valid(s, seat, slot, I.placing.last(s, seat), pre, load)

# The successor of a Grab or NeedItem answer is valid.

def grab.move.valid(+world: S.World, +players: S.Players, +grabs: S.Grabs, +seat: D.Seat, +index: Nat, +move: D.Move, +sel: GP.Selected(needs.at(world, players, grabs), D.Choice{seat, index, move}), +pre: Pre(grab.at(world, players, Nil{}, grabs)), load: LoadValid()) -> A.ValidItems(M.answer.choice(grab.at(world, players, Nil{}, grabs), D.Choice{seat, index, move})):
  match move:
    case D.Grab{}:
      %Equal.sym(Maybe<&2, S.GrabOption>, I.grab.nth(Q.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs.at(world, players, grabs), seat), Nil{}), index), Some{S.TakeItem{}}, sel) : A.ValidItems(M.grab.selected(grab.at(world, players, Nil{}, grabs), seat, _))
      take.valid(grab.at(world, players, Nil{}, grabs), seat, pre, load)
    case D.Place{+slot}:
      %Equal.sym(Maybe<&2, S.GrabOption>, I.grab.nth(Q.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs.at(world, players, grabs), seat), Nil{}), index), Some{S.PutAt{slot}}, sel) : A.ValidItems(M.grab.selected(grab.at(world, players, Nil{}, grabs), seat, _))
      place.valid(grab.at(world, players, Nil{}, grabs), seat, slot, pre, load)
    case D.PickUp{}:
      match sel:
    case D.Shoot{target}:
      match sel:
    case D.UseItem{slot, item}:
      match sel:
    case D.JamTarget{target}:
      match sel:
    case D.Steal{owner, slot, item}:
      match sel:

def grab.picked.valid(+world: S.World, +players: S.Players, +grabs: S.Grabs, +picked: Maybe<&2, D.Choice>, +sel: GP.MaybeSelected(needs.at(world, players, grabs), picked), +pre: Pre(grab.at(world, players, Nil{}, grabs)), load: LoadValid()) -> A.ValidItems(M.answer.resolved(grab.at(world, players, Nil{}, grabs), D.resolve.choice(picked))):
  match picked:
    case None{}:
      blocked.point.valid(grab.at(world, players, Nil{}, grabs), pre)
    case Some{+choice}:
      match choice:
        case D.Choice{+seat, +index, +move}:
          grab.move.valid(world, players, grabs, seat, index, move, sel, pre, load)

def grab.any.valid(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +any: Bool, +valid: A.ValidItems(grab.at(world, players, notes, grabs)), +pre: Pre(grab.at(world, players, Nil{}, grabs)), load: LoadValid()) -> A.ValidItems(A.machine_step_state(M.answer.request(grab.at(world, players, notes, grabs), n, D.request.choose.any(any, I.grab.menus(needs.at(world, players, grabs)))))):
  match any:
    case True{}:
      grab.picked.valid(world, players, grabs, D.choose(I.grab.menus(needs.at(world, players, grabs)), n), GP.sel.choose(needs.at(world, players, grabs), n), pre, load)
    case False{}:
      valid

def pre.at(+world: S.World, +players: S.Players, +phase: S.Phase, +notes: A.Notes(), +grabs: S.Grabs, +quiet: {A.turn.holder(phase) == None{} : Maybe<&2, D.Seat>}, +valid: A.ValidItems(S.State{world, players, phase, notes, grabs})) -> Pre(S.State{world, players, phase, Nil{}, grabs}):
  match valid:
    case Tuple{_, Tuple{+shape, Tuple{+bounded, _}}}:
      ((shape.move(world, players, phase, notes, grabs, phase, Nil{}, shape), quiet), bounded)

def grab.valid(+world: S.World, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.ValidItems(grab.at(world, players, notes, grabs)), load: LoadValid()) -> A.ValidItems(A.next(grab.at(world, players, notes, grabs), n)):
  grab.any.valid(world, players, notes, grabs, n, D.menus.any(D.ring.entries(List<&2, D.Move>, I.grab.menus(needs.at(world, players, grabs)))), valid, pre.at(world, players, S.Grab{needs.at(world, players, grabs)}, notes, grabs, {==}, valid), load)

def item.valid(+world: S.World, +players: S.Players, +seat: D.Seat, +first: D.Item, +second: D.Item, +rest: List<&2, D.Item>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.ValidItems(item.at(world, players, seat, first, second, rest, notes, grabs)), load: LoadValid()) -> A.ValidItems(A.next(item.at(world, players, seat, first, second, rest, notes, grabs), n)):
  chosen.valid(item.at(world, players, seat, first, second, rest, Nil{}, grabs), seat, Q.nth(D.Item, first <> second <> rest, D.draw.value(D.Range{0n, List.length(&2, D.Item, rest)}, n)), pre.at(world, players, S.NeedItem{seat, first, second, rest}, notes, grabs, {==}, valid), load)

# Part 2: the machine's Point equals the reference's at a valid state.

def view.parts(+hp: Nat, +jam: Bool, +checked: Bool, +cash: U32, +sl: D.Slots, +g: Bool, +o: Maybe<&2, D.Item>, +t: Bool) -> {D.SeatView{D.counter.of(jam, hp), sl, cash, I.briefcase(g, o)} == R.props.view(H.Props{hp, jam, checked, cash, sl, g, o, t}) : D.SeatView}:
  match g o:
    case False{} o:
      {==}
    case True{} None{}:
      {==}
    case True{} Some{item}:
      {==}

def view.claim(+s: S.State, +seat: D.Seat) -> Type:
  {V.seat.view(S.state.players(s), S.state.grabs(s), seat) == R.props.view(GP.lens.props(s, seat)) : D.SeatView}

def view.eq(+s: S.State, +seat: D.Seat, +shape: A.Shape(s)) -> view.claim(s, seat):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs seat:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, +intake} D.Seat0{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, +intake} D.Seat1{}:
          view.parts(h1, S.jam.jammed(j1), A.jam.checked(j1), c1, s1, g1, o1, A.turn.held(A.turn.holder(phase), D.Seat1{}))
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, +intake} D.Seat2{}:
          {==}
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Duo{+g1, +g3}, D.Duo{+o1, +o3}, +granted, +intake} D.Seat3{}:
          view.parts(h3, S.jam.jammed(j3), A.jam.checked(j3), c3, s3, g3, o3, A.turn.held(A.turn.holder(phase), D.Seat3{}))
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_two(e_players))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat), GP.clash.three_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat), GP.clash.four_two(e_grabbing))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat), GP.clash.three_two(e_holding))
        case D.TwoSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat), GP.clash.four_two(e_holding))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat0{}:
          view.parts(h0, S.jam.jammed(j0), A.jam.checked(j0), c0, s0, g0, o0, A.turn.held(A.turn.holder(phase), D.Seat0{}))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat1{}:
          view.parts(h1, S.jam.jammed(j1), A.jam.checked(j1), c1, s1, g1, o1, A.turn.held(A.turn.holder(phase), D.Seat1{}))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat2{}:
          view.parts(h2, S.jam.jammed(j2), A.jam.checked(j2), c2, s2, g2, o2, A.turn.held(A.turn.holder(phase), D.Seat2{}))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, D.Trio{+o0, +o1, +o2}, +granted, +intake} D.Seat3{}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.four_three(e_players))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat), GP.clash.two_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Quad{g0, g1, g2, g3}, holding, granted, intake}}, seat), GP.clash.four_three(e_grabbing))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat), GP.clash.two_three(e_holding))
        case D.ThreeSeats{} +players S.Grabs{+dist, +grabbing, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Quad{o0, o1, o2, o3}, granted, intake}}, seat), GP.clash.four_three(e_holding))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat0{}:
          view.parts(h0, S.jam.jammed(j0), A.jam.checked(j0), c0, s0, g0, o0, A.turn.held(A.turn.holder(phase), D.Seat0{}))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat1{}:
          view.parts(h1, S.jam.jammed(j1), A.jam.checked(j1), c1, s1, g1, o1, A.turn.held(A.turn.holder(phase), D.Seat1{}))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat2{}:
          view.parts(h2, S.jam.jammed(j2), A.jam.checked(j2), c2, s2, g2, o2, A.turn.held(A.turn.holder(phase), D.Seat2{}))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, D.Quad{+g0, +g1, +g2, +g3}, D.Quad{+o0, +o1, +o2, +o3}, +granted, +intake} D.Seat3{}:
          view.parts(h3, S.jam.jammed(j3), A.jam.checked(j3), c3, s3, g3, o3, A.turn.held(A.turn.holder(phase), D.Seat3{}))
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}, seat), GP.clash.three_four(e_players))
        case D.FourSeats{} +players S.Grabs{+dist, D.Duo{+g1, +g3}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Duo{g1, g3}, holding, granted, intake}}, seat), GP.clash.two_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, D.Trio{+g0, +g1, +g2}, +holding, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, D.Trio{g0, g1, g2}, holding, granted, intake}}, seat), GP.clash.three_four(e_grabbing))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Duo{+o1, +o3}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Duo{o1, o3}, granted, intake}}, seat), GP.clash.two_four(e_holding))
        case D.FourSeats{} +players S.Grabs{+dist, +grabbing, D.Trio{+o0, +o1, +o2}, +granted, +intake} +seat:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(view.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, S.Grabs{dist, grabbing, D.Trio{o0, o1, o2}, granted, intake}}, seat), GP.clash.three_four(e_holding))

def views.seats(+seats: List<&2, D.Seat>, +s: S.State, +views: D.Ring<&2, D.SeatView>, +shape: A.Shape(s)) -> {R.seat_views(GP.lens.entries(seats, s), views) == V.seat.views(seats, S.state.players(s), S.state.grabs(s), views) : D.Ring<&2, D.SeatView>}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> +rest:
      +machine : D.Ring<&2, D.SeatView> = D.ring.set(D.SeatView, views, seat, V.seat.view(S.state.players(s), S.state.grabs(s), seat))
      +written : {R.seat_views(GP.lens.entries(rest, s), D.ring.set(D.SeatView, views, seat, R.props.view(GP.lens.props(s, seat)))) == R.seat_views(GP.lens.entries(rest, s), machine) : D.Ring<&2, D.SeatView>} = Equal.cong(D.SeatView, D.Ring<&2, D.SeatView>, v => R.seat_views(GP.lens.entries(rest, s), D.ring.set(D.SeatView, views, seat, v)), R.props.view(GP.lens.props(s, seat)), V.seat.view(S.state.players(s), S.state.grabs(s), seat), Equal.sym(D.SeatView, V.seat.view(S.state.players(s), S.state.grabs(s), seat), R.props.view(GP.lens.props(s, seat)), view.eq(s, seat, shape)))
      Equal.trans(D.Ring<&2, D.SeatView>, R.seat_views(GP.lens.entries(seat <> rest, s), views), R.seat_views(GP.lens.entries(rest, s), machine), V.seat.views(seat <> rest, S.state.players(s), S.state.grabs(s), views), written, views.seats(rest, s, machine, shape))

def stage.batch(+h: H.Host, +deck: List<&2, H.Batch>, +notes: A.Notes()) -> {R.stage(R.RefState{h, A.batch.frame(deck), notes}) == D.Loading{} : D.Stage}:
  match deck:
    case Nil{}:
      {==}
    case a <> Nil{}:
      {==}
    case a <> b <> rest:
      {==}

def stage.eq(+phase: S.Phase, +h: H.Host, +notes: A.Notes()) -> {V.phase.stage(phase) == R.stage(R.RefState{h, A.frame(phase, h), notes}) : D.Stage}:
  match phase:
    case S.NeedFirst{}:
      {==}
    case S.NeedHealth{}:
      {==}
    case S.NeedAmount{}:
      {==}
    case S.NeedBatch{}:
      Equal.sym(D.Stage, R.stage(R.RefState{h, A.batch.frame(H.host.deck(h)), notes}), D.Loading{}, stage.batch(h, H.host.deck(h), notes))
    case S.NeedSwap{load, shells, i}:
      {==}
    case S.Idle{seat, options}:
      {==}
    case S.Aim{seat}:
      {==}
    case S.Ended{}:
      {==}
    case S.Blocked{holder}:
      {==}
    case S.NeedTurnAmount{from, passing, winner}:
      {==}
    case S.Grab{needs}:
      {==}
    case S.NeedItem{seat, first, second, rest}:
      {==}
    case S.NeedPhone{seat, owner, slot}:
      {==}
    case S.JamPick{seat, targets}:
      {==}
    case S.StealPick{seat, picks}:
      {==}

# The board of a state from its seat views and stage.
def board.with(+s: S.State, views: D.Ring<&2, D.SeatView>, stage: D.Stage) -> D.Board:
  +world : S.World = S.state.world(s)
  D.Board{D.RoundView{S.world.round_index(world), D.plan.length(S.world.plan(world)), S.world.round_health(world)}, views, D.GunView{S.world.shown(world), List.length(&2, D.Shell, S.world.gun(world)), S.world.sawed(world)}, S.world.direction(world), stage}

def board.eq(+s: S.State, +shape: A.Shape(s)) -> {V.board(s) == R.board(A.ref(s)) : D.Board}:
  match s:
    case S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, +players, +phase, +notes, +grabs}:
      +st : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, players, phase, notes, grabs}
      +fill : D.Ring<&2, D.SeatView> = D.ring.fill(D.SeatView, table, R.props.view(H.props.initial()))
      +views_m : D.Ring<&2, D.SeatView> = V.seat.views(D.table.seats(table), players, grabs, fill)
      +views_r : D.Ring<&2, D.SeatView> = R.seat_views(D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), fill)
      +lensed : {R.seat_views(GP.lens.entries(D.table.seats(table), st), fill) == views_r : D.Ring<&2, D.SeatView>} = Equal.cong(List<&2, D.At<&2, H.Props>>, D.Ring<&2, D.SeatView>, xs => R.seat_views(xs, fill), GP.lens.entries(D.table.seats(table), st), D.ring.entries(H.Props, H.host.seats(A.ref_host(st))), GP.entries.eq(st, shape))
      +views : {views_m == views_r : D.Ring<&2, D.SeatView>} = Equal.trans(D.Ring<&2, D.SeatView>, views_m, R.seat_views(GP.lens.entries(D.table.seats(table), st), fill), views_r, Equal.sym(D.Ring<&2, D.SeatView>, R.seat_views(GP.lens.entries(D.table.seats(table), st), fill), views_m, views.seats(D.table.seats(table), st, fill, shape)), lensed)
      +staged : {V.phase.stage(phase) == R.stage(A.ref(st)) : D.Stage} = stage.eq(phase, A.ref_host(st), notes)
      Equal.trans(D.Board, board.with(st, views_m, V.phase.stage(phase)), board.with(st, views_r, V.phase.stage(phase)), board.with(st, views_r, R.stage(A.ref(st))), Equal.cong(D.Ring<&2, D.SeatView>, D.Board, v => board.with(st, v, V.phase.stage(phase)), views_m, views_r, views), Equal.cong(D.Stage, D.Board, x => board.with(st, views_r, x), V.phase.stage(phase), R.stage(A.ref(st)), staged))

# Aim targets: the living seats, from the seat ring's health.
def health.lens(seats: List<&2, D.Seat>, +s: S.State) -> List<&2, D.At<&2, Nat>>:
  match seats:
    case Nil{}:
      Nil{}
    case +seat <> rest:
      D.At{seat, I.seat.health(S.state.players(s), seat)} <> health.lens(rest, s)

def health.claim(+s: S.State) -> Type:
  {D.ring.entries(Nat, S.players.health(S.state.players(s))) == health.lens(D.table.seats(S.world.table(S.state.world(s))), s) : List<&2, D.At<&2, Nat>>}

def health.eq(+s: S.State, +shape: A.Shape(s)) -> health.claim(s):
  match s:
    case S.State{S.World{D.Config{table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, +deck}, players, +phase, +notes, grabs}:
      match table players grabs:
        case D.TwoSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.TwoSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(health.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.three_two(e_players))
        case D.TwoSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(health.claim(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.four_two(e_players))
        case D.ThreeSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.ThreeSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(health.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.two_three(e_players))
        case D.ThreeSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(health.claim(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Quad{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.four_three(e_players))
        case D.FourSeats{} D.Quad{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          {==}
        case D.FourSeats{} D.Duo{S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h3, +j3, +c3, +s3}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(health.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Duo{S.Seat{h1, j1, c1, s1}, S.Seat{h3, j3, c3, s3}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.two_four(e_players))
        case D.FourSeats{} D.Trio{S.Seat{+h0, +j0, +c0, +s0}, S.Seat{+h1, +j1, +c1, +s1}, S.Seat{+h2, +j2, +c2, +s2}} S.Grabs{+dist, +grabbing, +holding, +granted, +intake}:
          match shape:
            case Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}:
              GP.absurd(health.claim(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck}, D.Trio{S.Seat{h0, j0, c0, s0}, S.Seat{h1, j1, c1, s1}, S.Seat{h2, j2, c2, s2}}, phase, notes, S.Grabs{dist, grabbing, holding, granted, intake}}), GP.clash.three_four(e_players))

def aim.cell(+seat: D.Seat, +props: H.Props, +rest_m: List<&2, D.At<&2, Nat>>, +rest_r: List<&2, D.At<&2, H.Props>>, +ih: {Q.aim.moves(Q.targets(rest_m)) == R.shot_moves(G.living(rest_r)) : List<&2, D.Move>}) -> {Q.aim.moves(Q.targets(D.At{seat, H.props.health(props)} <> rest_m)) == R.shot_moves(G.living(D.At{seat, props} <> rest_r)) : List<&2, D.Move>}:
  match props:
    case H.Props{+hp, +jam, +checked, +cash, +sl, +g, +o, +t}:
      match hp:
        case 0n:
          ih
        case 1n+k:
          Equal.cong(List<&2, D.Move>, List<&2, D.Move>, xs => D.Shoot{seat} <> xs, Q.aim.moves(Q.targets(rest_m)), R.shot_moves(G.living(rest_r)), ih)

def aim.seats(+seats: List<&2, D.Seat>, +s: S.State) -> {Q.aim.moves(Q.targets(health.lens(seats, s))) == R.shot_moves(G.living(GP.lens.entries(seats, s))) : List<&2, D.Move>}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> +rest:
      aim.cell(seat, GP.lens.props(s, seat), health.lens(rest, s), GP.lens.entries(rest, s), aim.seats(rest, s))

def aim.eq(+s: S.State, +shape: A.Shape(s)) -> {Q.aim.moves(Q.aim.targets(S.state.players(s))) == R.shot_moves(G.living(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))))) : List<&2, D.Move>}:
  +seats : List<&2, D.Seat> = D.table.seats(S.world.table(S.state.world(s)))
  +healths : {Q.aim.moves(Q.aim.targets(S.state.players(s))) == Q.aim.moves(Q.targets(health.lens(seats, s))) : List<&2, D.Move>} = Equal.cong(List<&2, D.At<&2, Nat>>, List<&2, D.Move>, xs => Q.aim.moves(Q.targets(xs)), D.ring.entries(Nat, S.players.health(S.state.players(s))), health.lens(seats, s), health.eq(s, shape))
  +lensed : {R.shot_moves(G.living(GP.lens.entries(seats, s))) == R.shot_moves(G.living(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))))) : List<&2, D.Move>} = Equal.cong(List<&2, D.At<&2, H.Props>>, List<&2, D.Move>, xs => R.shot_moves(G.living(xs)), GP.lens.entries(seats, s), D.ring.entries(H.Props, H.host.seats(A.ref_host(s))), GP.entries.eq(s, shape))
  Equal.trans(List<&2, D.Move>, Q.aim.moves(Q.aim.targets(S.state.players(s))), Q.aim.moves(Q.targets(health.lens(seats, s))), R.shot_moves(G.living(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))))), healths, Equal.trans(List<&2, D.Move>, Q.aim.moves(Q.targets(health.lens(seats, s))), R.shot_moves(G.living(GP.lens.entries(seats, s))), R.shot_moves(G.living(D.ring.entries(H.Props, H.host.seats(A.ref_host(s))))), aim.seats(seats, s), lensed))

def request.deck(+deck: List<&2, S.Batch>, +h: H.Host, +notes: A.Notes()) -> {V.batch.request(List.length(&2, S.Batch, deck)) == R.request(R.RefState{h, A.batch.frame(A.batches(deck)), notes}) : D.Request}:
  match deck:
    case Nil{}:
      {==}
    case S.Batch{id, load} <> Nil{}:
      {==}
    case S.Batch{id0, load0} <> S.Batch{id1, load1} <> +rest:
      Equal.cong(Nat, D.Request, extra => D.Draw{D.SequenceBatch{}, D.Range{0n, extra}}, List.length(&2, S.Batch, rest), A.ref_batch_length(rest), C.batch_length_backwards(rest))

def request.first(+table: D.Table) -> {V.first.range(table) == D.Range{0n, G.subtract(D.table.count(table), 2n)} : D.Range}:
  match table:
    case D.TwoSeats{}:
      {==}
    case D.ThreeSeats{}:
      {==}
    case D.FourSeats{}:
      {==}

def request.batch(+table: D.Table, +plan: D.Plan, +before: Bool, +round: Nat, +load: Nat, +first: Bool, +rh: Nat, +recipient: D.Seat, +turn: Maybe<&2, D.Seat>, +direction: D.Direction, +died: Maybe<&2, D.Seat>, +checking: Bool, +amount: Nat, +saw: Bool, +gun: List<&2, D.Shell>, +shown: D.Load, +two: List<&2, S.Batch>, +three: List<&2, S.Batch>, +four: List<&2, S.Batch>, +players: S.Players, +notes: A.Notes(), +grabs: S.Grabs) -> {V.request(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, four}}, players, S.NeedBatch{}, notes, grabs}) == R.request(A.ref(S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, four}}, players, S.NeedBatch{}, notes, grabs})) : D.Request}:
  match table:
    case D.TwoSeats{}:
      request.deck(two, A.ref_host(S.State{S.World{D.Config{D.TwoSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, four}}, players, S.NeedBatch{}, notes, grabs}), notes)
    case D.ThreeSeats{}:
      request.deck(three, A.ref_host(S.State{S.World{D.Config{D.ThreeSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, four}}, players, S.NeedBatch{}, notes, grabs}), notes)
    case D.FourSeats{}:
      request.deck(four, A.ref_host(S.State{S.World{D.Config{D.FourSeats{}, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, four}}, players, S.NeedBatch{}, notes, grabs}), notes)

def request.norm(+s: S.State, +shape: A.Shape(s)) -> {V.request(A.normalize_items(s)) == R.request(A.ref(A.normalize_items(s))) : D.Request}:
  match s:
    case S.State{S.World{D.Config{+table, +plan}, +before, +round, +load, +first, +rh, +recipient, +turn, +direction, +died, +checking, +amount, +saw, +gun, +shown, S.Decks{+two, +three, +four}}, +players, +phase, +notes, +grabs}:
      match phase:
        case S.NeedFirst{}:
          Equal.cong(D.Range, D.Request, r => D.Draw{D.FirstSeat{}, r}, V.first.range(table), D.Range{0n, G.subtract(D.table.count(table), 2n)}, request.first(table))
        case S.NeedHealth{}:
          {==}
        case S.NeedAmount{}:
          {==}
        case S.NeedBatch{}:
          request.batch(table, plan, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, two, three, four, players, notes, grabs)
        case S.NeedSwap{swap_load, shells, 0n}:
          {==}
        case S.NeedSwap{swap_load, shells, 1n+extra}:
          Equal.cong(Nat, D.Request, width => D.Draw{D.ShuffleSwap{}, D.Range{0n, width}}, extra, A.subtract_zero(extra), C.subtract_zero_backwards(extra))
        case S.Idle{seat, options}:
          {==}
        case S.Aim{+seat}:
          +aimed : S.State = S.State{S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, four}}, players, S.Aim{seat}, notes, grabs}
          Equal.cong(List<&2, D.Move>, D.Request, moves => D.request.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, moves)), Q.aim.moves(Q.aim.targets(players)), R.shot_moves(G.living(D.ring.entries(H.Props, H.host.seats(A.ref_host(aimed))))), aim.eq(aimed, shape.move(S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, S.Decks{two, three, four}}, players, S.Aim{seat}, notes, grabs, S.Aim{seat}, notes, shape)))
        case S.Ended{}:
          {==}
        case S.Blocked{holder}:
          {==}
        case S.NeedTurnAmount{from, passing, winner}:
          {==}
        case S.Grab{needs}:
          {==}
        case S.NeedItem{seat, first_item, second, rest}:
          {==}
        case S.NeedPhone{seat, owner, slot}:
          {==}
        case S.JamPick{seat, targets}:
          {==}
        case S.StealPick{seat, picks}:
          {==}

def point.norm(+s: S.State, +shape: A.Shape(s)) -> {V.point(A.normalize_items(s)) == R.point(A.ref(A.normalize_items(s))) : D.Point}:
  match s:
    case S.State{+world, +players, +phase, +notes, +grabs}:
      +normal : S.State = A.normalize_items(S.State{world, players, phase, notes, grabs})
      +requests : {V.request(normal) == R.request(A.ref(normal)) : D.Request} = request.norm(S.State{world, players, phase, notes, grabs}, shape)
      +boards : {V.board(normal) == R.board(A.ref(normal)) : D.Board} = board.eq(normal, shape.move(world, players, phase, notes, grabs, A.canonical_phase_items(S.State{world, players, phase, notes, grabs}, phase), notes, shape))
      Equal.trans(D.Point, D.Point{V.request(normal), V.board(normal)}, D.Point{R.request(A.ref(normal)), V.board(normal)}, D.Point{R.request(A.ref(normal)), R.board(A.ref(normal))}, Equal.cong(D.Request, D.Point, r => D.Point{r, V.board(normal)}, V.request(normal), R.request(A.ref(normal)), requests), Equal.cong(D.Board, D.Point, b => D.Point{R.request(A.ref(normal)), b}, V.board(normal), R.board(A.ref(normal)), boards))

def point.items(+s: S.State, +valid: A.ValidItems(s)) -> {A.machine_point(s) == A.point_of_ref(s) : D.Point}:
  +normal : {A.normalize_items(s) == s : S.State} = A.valid_items.normal(s, valid)
  Equal.trans(D.Point, A.machine_point(s), A.machine_point(A.normalize_items(s)), A.point_of_ref(s), Equal.cong(S.State, D.Point, x => A.machine_point(x), s, A.normalize_items(s), Equal.sym(S.State, A.normalize_items(s), s, normal)), Equal.trans(D.Point, A.machine_point(A.normalize_items(s)), A.point_of_ref(A.normalize_items(s)), A.point_of_ref(s), point.norm(s, A.valid_items.shape(s, valid)), Equal.cong(S.State, D.Point, x => A.point_of_ref(x), A.normalize_items(s), s, normal)))

# SimulationItems from part 1 and part 3; part 2 follows by point.items.
def simulation.items(+state: S.State, +n: Nat, +result: {A.ref_answer(A.ref(state), n) == A.stepped(M.answer(state, n)) : A.RefStep()}, +valid: A.ValidItems(A.next(state, n))) -> A.SimulationItems(state, n):
  (result, (Equal.trans(D.Point, A.machine_point(A.next(state, n)), A.point_of_ref(A.next(state, n)), A.ref_step_point(A.ref_answer(A.ref(state), n)), point.items(A.next(state, n), valid), Equal.trans(D.Point, A.point_of_ref(A.next(state, n)), A.ref_step_point(A.stepped(M.answer(state, n))), A.ref_step_point(A.ref_answer(A.ref(state), n)), C.point_stepped(M.answer(state, n)), Equal.cong(A.RefStep(), D.Point, x => A.ref_step_point(x), A.stepped(M.answer(state, n)), A.ref_answer(A.ref(state), n), Equal.sym(A.RefStep(), A.ref_answer(A.ref(state), n), A.stepped(M.answer(state, n)), result)))), valid))

def valid.normalized(+s: S.State, +valid: A.ValidItems(s)) -> A.ValidItems(A.normalize_items(s)):
  %Equal.sym(S.State, A.normalize_items(s), s, A.valid_items.normal(s, valid)) : A.ValidItems(_)
  valid

# step_matches at the handout's request points, under ValidItems, given the
# load closure (L11) and that it ends valid.

def step.grab(+world: S.World, +players: S.Players, +needs: D.Ring<&2, List<&2, S.GrabOption>>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.ValidItems(S.State{world, players, S.Grab{needs}, notes, grabs}), load: GP.LoadClosure(), loaded: LoadValid()) -> A.SimulationItems(S.State{world, players, S.Grab{needs}, notes, grabs}, n):
  +normal : A.ValidItems(grab.at(world, players, notes, grabs)) = valid.normalized(S.State{world, players, S.Grab{needs}, notes, grabs}, valid)
  %A.valid_items.normal(S.State{world, players, S.Grab{needs}, notes, grabs}, valid) : A.SimulationItems(_, n)
  simulation.items(grab.at(world, players, notes, grabs), n, grab.answer(world, players, notes, grabs, n, A.valid_items.shape(grab.at(world, players, notes, grabs), normal), load), grab.valid(world, players, notes, grabs, n, normal, loaded))

def step.item(+world: S.World, +players: S.Players, +seat: D.Seat, +first: D.Item, +second: D.Item, +rest: List<&2, D.Item>, +notes: A.Notes(), +grabs: S.Grabs, +n: Nat, +valid: A.ValidItems(S.State{world, players, S.NeedItem{seat, first, second, rest}, notes, grabs}), load: GP.LoadClosure(), loaded: LoadValid()) -> A.SimulationItems(S.State{world, players, S.NeedItem{seat, first, second, rest}, notes, grabs}, n):
  simulation.items(item.at(world, players, seat, first, second, rest, notes, grabs), n, item.answer(world, players, seat, first, second, rest, notes, grabs, n, A.valid_items.shape(item.at(world, players, seat, first, second, rest, notes, grabs), valid), load), item.valid(world, players, seat, first, second, rest, notes, grabs, n, valid, loaded))
