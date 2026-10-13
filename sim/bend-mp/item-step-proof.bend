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
