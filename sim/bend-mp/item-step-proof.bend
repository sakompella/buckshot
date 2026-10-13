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
