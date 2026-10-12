import Base
import ../domain.bend as D

# Story-mode dealer AI (Buckshot multiplayer).
#
# One pure controller for one seat, ported from the verified two-player dealer
# policy (sim/bend/controller.bend, sim/python/dealer_vs_dealer.py). It sees
# only D.Prompt (its legal moves), D.Obs (the public board) and D.Heard (public
# events plus its own secrets); it keeps its own Mem.
#
# The story policy has no upgrades: fair coins, the dealer's item rules only.
#
# Multiplayer adaptations:
#   - Intent is a move; prompt.index finds it in the menu. If it is not there
#     the pick is 0, the menu's first move.
#   - "The opponent" is the living opponent with the lowest health (a jammed
#     seat's health is hidden, so it counts as the round's starting health),
#     ties to the lowest socket. Shooting and jamming both use it.
#   - The hybrid decided and shot in one step. Here Idle decides: it uses an
#     item or takes the gun, and remembers the aim; Aiming shoots at that aim.
#   - Items come in inventory (slot) order. Adrenaline is a UseItem and the
#     steal is its own prompt: the first eligible item among the Steal moves.
#   - Remote is never used. Grabs: take every Grab, place in the first slot.
#   - The saw flag is read from the gun on the board, so a saw used by anyone
#     counts. Live and blank counts are tracked from Loaded, Fired and Ejected
#     (all public); another seat's inverter makes them unknown until the next
#     load, and unknown counts disable every use of them.
#   - Any shot clears the known chamber. After its own beer the story policy
#     keeps its (now stale) known shell, as the hybrid does.

type Aim is Data:
  AtSelf{}
  AtOpp{}

type Seen is Data:
  Seen{index: Nat, shell: D.Shell}

# known: the chamber shell. aim: where the next shot goes. phone: later shells
# learned from the phone, index 0 being the chamber. counts: shells left.
# pending: a saw was chosen, so ignore items and shoot. steal_saw: the
# adrenaline in use is meant to steal the saw.
type Mem is Data:
  Mem{known: Maybe<&2, D.Shell>, aim: Maybe<&2, Aim>, phone: List<&2, Seen>, counts: Maybe<&2, D.Load>, pending: Bool, steal_saw: Bool}

def fresh() -> Mem:
  Mem{None{}, None{}, Nil{}, None{}, False{}, False{}}

def mem.known(mem: Mem) -> Maybe<&2, D.Shell>:
  match mem:
    case Mem{known, _, _, _, _, _}:
      known

def mem.aim(mem: Mem) -> Maybe<&2, Aim>:
  match mem:
    case Mem{_, aim, _, _, _, _}:
      aim

def mem.phone(mem: Mem) -> List<&2, Seen>:
  match mem:
    case Mem{_, _, phone, _, _, _}:
      phone

def mem.counts(mem: Mem) -> Maybe<&2, D.Load>:
  match mem:
    case Mem{_, _, _, counts, _, _}:
      counts

def mem.pending(mem: Mem) -> Bool:
  match mem:
    case Mem{_, _, _, _, pending, _}:
      pending

def mem.steal_saw(mem: Mem) -> Bool:
  match mem:
    case Mem{_, _, _, _, _, steal_saw}:
      steal_saw

def mem.set_known(mem: Mem, value: Maybe<&2, D.Shell>) -> Mem:
  match mem:
    case Mem{_, aim, phone, counts, pending, steal_saw}:
      Mem{value, aim, phone, counts, pending, steal_saw}

def mem.set_aim(mem: Mem, value: Maybe<&2, Aim>) -> Mem:
  match mem:
    case Mem{known, _, phone, counts, pending, steal_saw}:
      Mem{known, value, phone, counts, pending, steal_saw}

def mem.set_phone(mem: Mem, value: List<&2, Seen>) -> Mem:
  match mem:
    case Mem{known, aim, _, counts, pending, steal_saw}:
      Mem{known, aim, value, counts, pending, steal_saw}

def mem.set_counts(mem: Mem, value: Maybe<&2, D.Load>) -> Mem:
  match mem:
    case Mem{known, aim, phone, _, pending, steal_saw}:
      Mem{known, aim, phone, value, pending, steal_saw}

def mem.set_pending(mem: Mem, value: Bool) -> Mem:
  match mem:
    case Mem{known, aim, phone, counts, _, steal_saw}:
      Mem{known, aim, phone, counts, value, steal_saw}

def mem.set_steal_saw(mem: Mem, value: Bool) -> Mem:
  match mem:
    case Mem{known, aim, phone, counts, pending, _}:
      Mem{known, aim, phone, counts, pending, value}

def shell.eq(a: D.Shell, b: D.Shell) -> Bool:
  match a b:
    case D.Live{} D.Live{}:
      True{}
    case D.Blank{} D.Blank{}:
      True{}
    case _ _:
      False{}

def shell.flip(shell: D.Shell) -> D.Shell:
  match shell:
    case D.Live{}:
      D.Blank{}
    case D.Blank{}:
      D.Live{}

def aim.of(shell: D.Shell) -> Aim:
  match shell:
    case D.Live{}:
      AtOpp{}
    case D.Blank{}:
      AtSelf{}

def or0(found: Maybe<&2, Nat>) -> Nat:
  match found:
    case Some{k}:
      k
    case None{}:
      0n

# Memory
# ======

def learn(+mem: Mem, +shell: D.Shell) -> Mem:
  mem.set_aim(mem.set_known(mem, Some{shell}), Some{aim.of(shell)})

def knows.of(known: Maybe<&2, D.Shell>) -> Bool:
  match known:
    case Some{shell}:
      True{}
    case None{}:
      False{}

def knows(mem: Mem) -> Bool:
  knows.of(mem.known(mem))

def known_is.of(known: Maybe<&2, D.Shell>, shell: D.Shell) -> Bool:
  match known:
    case None{}:
      False{}
    case Some{found}:
      shell.eq(found, shell)

def known_is(mem: Mem, shell: D.Shell) -> Bool:
  known_is.of(mem.known(mem), shell)

def phone_remove(xs: List<&2, Seen>, +index: Nat) -> List<&2, Seen>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Seen{+i, shell}, tail}:
      +rest : List<&2, Seen> = phone_remove(tail, index)
      Bool.pick(List<&2, Seen>, Nat.is_eq(i, index), rest, Seen{i, shell} <> rest)

# Drop the chamber's entry and renumber: a shell left the gun.
def phone_shift(xs: List<&2, Seen>) -> List<&2, Seen>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Seen{0n, _}, tail}:
      phone_shift(tail)
    case Con{Seen{1n+i, shell}, tail}:
      Seen{i, shell} <> phone_shift(tail)

# Flip the chamber's entry: the inverter changed that shell.
def phone_invert(xs: List<&2, Seen>) -> List<&2, Seen>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Seen{0n, D.Live{}}, tail}:
      Seen{0n, D.Blank{}} <> phone_invert(tail)
    case Con{Seen{0n, D.Blank{}}, tail}:
      Seen{0n, D.Live{}} <> phone_invert(tail)
    case Con{Seen{1n+i, shell}, tail}:
      Seen{1n+i, shell} <> phone_invert(tail)

def reveal(+index: Nat, shell: D.Shell, +mem: Mem) -> Mem:
  match index:
    case 0n:
      learn(mem, shell)
    case 1n+i:
      mem.set_phone(mem, Seen{index, shell} <> phone_remove(mem.phone(mem), index))

def counts.drop(counts: Maybe<&2, D.Load>, shell: D.Shell) -> Maybe<&2, D.Load>:
  match counts shell:
    case Some{D.Load{live, blank}} D.Live{}:
      Some{D.Load{Nat.sub(live, 1n), blank}}
    case Some{D.Load{live, blank}} D.Blank{}:
      Some{D.Load{live, Nat.sub(blank, 1n)}}
    case None{} _:
      None{}

def counts.swing(counts: Maybe<&2, D.Load>, to: D.Shell) -> Maybe<&2, D.Load>:
  match counts to:
    case Some{D.Load{live, blank}} D.Live{}:
      Some{D.Load{1n+live, Nat.sub(blank, 1n)}}
    case Some{D.Load{live, blank}} D.Blank{}:
      Some{D.Load{Nat.sub(live, 1n), 1n+blank}}
    case None{} _:
      None{}

def tally.check(counts: Maybe<&2, D.Load>, remaining: Nat) -> Maybe<&2, D.Load>:
  match counts:
    case None{}:
      None{}
    case Some{D.Load{+live, +blank}}:
      Bool.pick(Maybe<&2, D.Load>, Nat.is_eq(Nat.add(live, blank), remaining), Some{D.Load{live, blank}}, None{})

# The counts, only while they agree with the number of shells left.
def tally(mem: Mem, remaining: Nat) -> Maybe<&2, D.Load>:
  tally.check(mem.counts(mem), remaining)

def shot_gone(+mem: Mem, shell: D.Shell) -> Mem:
  +next : Mem = mem.set_phone(mem, phone_shift(mem.phone(mem)))
  mem.set_counts(next, counts.drop(mem.counts(next), shell))

# Any shot ends the aim: the chamber is gone.
def fired(+mem: Mem, shell: D.Shell) -> Mem:
  +gone : Mem = shot_gone(mem, shell)
  Mem{None{}, None{}, mem.phone(gone), mem.counts(gone), False{}, False{}}

def beer_reset(mem: Mem) -> Mem:
  mem

def ejected(mine: Bool, +mem: Mem, shell: D.Shell) -> Mem:
  +gone : Mem = shot_gone(mem, shell)
  Bool.pick(Mem, mine, beer_reset(gone), mem.set_aim(mem.set_known(gone, None{}), None{}))

def inverted.known(known: Maybe<&2, D.Shell>, +mem: Mem) -> Mem:
  match known:
    case None{}:
      mem.set_counts(mem, None{})
    case Some{+shell}:
      +turned : D.Shell = shell.flip(shell)
      learn(mem.set_counts(mem, counts.swing(mem.counts(mem), turned)), turned)

def inverted.phone(mine: Bool, +flipped: Mem) -> Mem:
  match mine:
    case False{}:
      mem.set_aim(mem.set_known(mem.set_counts(flipped, None{}), None{}), None{})
    case True{}:
      inverted.known(mem.known(flipped), flipped)

def inverted(mine: Bool, +mem: Mem) -> Mem:
  inverted.phone(mine, mem.set_phone(mem, phone_invert(mem.phone(mem))))

def on_event(event: D.GameEvent, +me: D.Seat, +mem: Mem) -> Mem:
  match event:
    case D.RoundBegan{round, health, first}:
      fresh()
    case D.Loaded{load}:
      mem.set_counts(fresh(), Some{load})
    case D.Fired{shooter, target, shell, captured, applied, health}:
      fired(mem, shell)
    case D.Ejected{seat, shell}:
      ejected(D.seat.eq(seat, me), mem, shell)
    case D.Inverted{seat}:
      inverted(D.seat.eq(seat, me), mem)
    case _:
      mem

# A clue's position counts from 1 at the chamber.
def on_clue(position: Nat, shell: D.Shell, mem: Mem) -> Mem:
  match position:
    case 0n:
      mem
    case 1n+index:
      reveal(index, shell, mem)

def on_secret(secret: D.Secret, +mem: Mem) -> Mem:
  match secret:
    case D.Glimpse{shell}:
      learn(mem, shell)
    case D.Clue{position, shell}:
      on_clue(position, shell, mem)
    case _:
      mem

def hear_one(heard: D.Heard, +me: D.Seat, mem: Mem) -> Mem:
  match heard:
    case D.Witnessed{event}:
      on_event(event, me, mem)
    case D.Learned{secret}:
      on_secret(secret, mem)

def update(heard: List<&2, D.Heard>, +me: D.Seat, mem: Mem) -> Mem:
  match heard:
    case Nil{}:
      mem
    case h <> rest:
      update(rest, me, hear_one(h, me, mem))

# What the board shows this seat
# ==============================

type Held is Data:
  Held{slot: D.Slot, item: D.Item}

type Loot is Data:
  Loot{owner: D.Seat, slot: D.Slot, item: D.Item}

type Ctx is Data:
  Ctx{me: D.Seat, max_hp: Nat, hp: Nat, remaining: Nat, sawed: Bool, seats: D.Ring<&2, D.SeatView>, mine: List<&2, Held>, loot: List<&2, Loot>, opp_free: Bool}

def counter.hp(counter: D.Counter, max_hp: Nat) -> Nat:
  match counter:
    case D.Unjammed{health}:
      health
    case D.Jammed{}:
      max_hp

def counter.alive(counter: D.Counter) -> Bool:
  match counter:
    case D.Unjammed{health}:
      Nat.is_ne(health, 0n)
    case D.Jammed{}:
      True{}

def counter.free(counter: D.Counter) -> Bool:
  match counter:
    case D.Unjammed{health}:
      Nat.is_ne(health, 0n)
    case D.Jammed{}:
      False{}

def held.add(slot: D.Slot, item: Maybe<&2, D.Item>, rest: List<&2, Held>) -> List<&2, Held>:
  match item:
    case None{}:
      rest
    case Some{found}:
      Held{slot, found} <> rest

def held.of(slots: D.Slots) -> List<&2, Held>:
  match slots:
    case D.Slots{a, b, c, d, e, f, g, h}:
      held.add(D.Slot0{}, a, held.add(D.Slot1{}, b, held.add(D.Slot2{}, c, held.add(D.Slot3{}, d, held.add(D.Slot4{}, e, held.add(D.Slot5{}, f, held.add(D.Slot6{}, g, held.add(D.Slot7{}, h, Nil{}))))))))

def loot.add(+owner: D.Seat, helds: List<&2, Held>, rest: List<&2, Loot>) -> List<&2, Loot>:
  match helds:
    case Nil{}:
      rest
    case Held{slot, item} <> more:
      Loot{owner, slot, item} <> loot.add(owner, more, rest)

def loot.row(skip: Bool, +seat: D.Seat, slots: D.Slots, rest: List<&2, Loot>) -> List<&2, Loot>:
  match skip:
    case True{}:
      rest
    case False{}:
      loot.add(seat, held.of(slots), rest)

# Living opponents' items, by owner then slot.
def loot.of(entries: List<&2, D.At<&2, D.SeatView>>, +me: D.Seat) -> List<&2, Loot>:
  match entries:
    case Nil{}:
      Nil{}
    case D.At{+seat, D.SeatView{+counter, slots, cash, briefcase}} <> rest:
      loot.row(Bool.or(D.seat.eq(seat, me), Bool.not(counter.alive(counter))), seat, slots, loot.of(rest, me))

# Some opponent is alive and not jammed.
def free.of(entries: List<&2, D.At<&2, D.SeatView>>, +me: D.Seat) -> Bool:
  match entries:
    case Nil{}:
      False{}
    case D.At{+seat, D.SeatView{counter, slots, cash, briefcase}} <> rest:
      Bool.or(Bool.and(Bool.not(D.seat.eq(seat, me)), counter.free(counter)), free.of(rest, me))

def ctx.build(+me: D.Seat, +max_hp: Nat, remaining: Nat, sawed: Bool, +seats: D.Ring<&2, D.SeatView>, own: Maybe<&2, D.SeatView>) -> Ctx:
  match own:
    case Some{D.SeatView{counter, slots, cash, briefcase}}:
      +entries : List<&2, D.At<&2, D.SeatView>> = D.ring.entries(D.SeatView, seats)
      Ctx{me, max_hp, counter.hp(counter, max_hp), remaining, sawed, seats, held.of(slots), loot.of(entries, me), free.of(entries, me)}
    case None{}:
      Ctx{me, max_hp, max_hp, remaining, sawed, seats, Nil{}, Nil{}, False{}}

def ctx.of(obs: D.Obs) -> Ctx:
  match obs:
    case D.Obs{+me, D.Board{D.RoundView{index, rounds, max_hp}, +seats, D.GunView{shown, remaining, sawed}, direction, stage}}:
      ctx.build(me, max_hp, remaining, sawed, seats, D.ring.get(D.SeatView, seats, me))

def ctx.me(ctx: Ctx) -> D.Seat:
  match ctx:
    case Ctx{me, max_hp, hp, remaining, sawed, seats, mine, loot, opp_free}:
      me

def ctx.remaining(ctx: Ctx) -> Nat:
  match ctx:
    case Ctx{me, max_hp, hp, remaining, sawed, seats, mine, loot, opp_free}:
      remaining

def ctx.sawed(ctx: Ctx) -> Bool:
  match ctx:
    case Ctx{me, max_hp, hp, remaining, sawed, seats, mine, loot, opp_free}:
      sawed

def ctx.mine(ctx: Ctx) -> List<&2, Held>:
  match ctx:
    case Ctx{me, max_hp, hp, remaining, sawed, seats, mine, loot, opp_free}:
      mine

def ctx.loot(ctx: Ctx) -> List<&2, Loot>:
  match ctx:
    case Ctx{me, max_hp, hp, remaining, sawed, seats, mine, loot, opp_free}:
      loot

# Which items to use
# ==================

def eligible.item(item: D.Item, max_hp: Nat, hp: Nat, remaining: Nat, sawed: Bool, opp_free: Bool, mem: Mem) -> Bool:
  match item:
    case D.Glass{}:
      Bool.not(knows(mem)) && Nat.is_ne(remaining, 1n)
    case D.Cigarettes{}:
      Nat.is_lt(hp, max_hp)
    case D.Beer{}:
      Bool.not(known_is(mem, D.Live{})) && Nat.is_ne(remaining, 1n)
    case D.Jammer{}:
      opp_free && Nat.is_ne(remaining, 1n)
    case D.Saw{}:
      Bool.not(sawed) && known_is(mem, D.Live{})
    case D.Phone{}:
      Nat.is_gt(remaining, 2n)
    case D.Inverter{}:
      known_is(mem, D.Blank{})
    case D.Adrenaline{}:
      False{}
    case D.Remote{}:
      False{}

def eligible(ctx: Ctx, mem: Mem, item: D.Item) -> Bool:
  match ctx:
    case Ctx{me, max_hp, hp, remaining, sawed, seats, mine, loot, opp_free}:
      eligible.item(item, max_hp, hp, remaining, sawed, opp_free, mem)

def first_held(helds: List<&2, Held>, +ctx: Ctx, +mem: Mem) -> Maybe<&2, Held>:
  match helds:
    case Nil{}:
      None{}
    case Held{slot, +item} <> rest:
      Bool.pick(Maybe<&2, Held>, eligible(ctx, mem, item), Some{Held{slot, item}}, first_held(rest, ctx, mem))

def first_loot(loots: List<&2, Loot>, +ctx: Ctx, +mem: Mem) -> Maybe<&2, Loot>:
  match loots:
    case Nil{}:
      None{}
    case Loot{owner, slot, +item} <> rest:
      Bool.pick(Maybe<&2, Loot>, eligible(ctx, mem, item), Some{Loot{owner, slot, item}}, first_loot(rest, ctx, mem))

def find_held(helds: List<&2, Held>, +wanted: D.Item) -> Maybe<&2, Held>:
  match helds:
    case Nil{}:
      None{}
    case Held{slot, +item} <> rest:
      Bool.pick(Maybe<&2, Held>, D.item.eq(item, wanted), Some{Held{slot, item}}, find_held(rest, wanted))

def has_loot(loots: List<&2, Loot>, +wanted: D.Item) -> Bool:
  match loots:
    case Nil{}:
      False{}
    case Loot{owner, slot, +item} <> rest:
      Bool.or(D.item.eq(item, wanted), has_loot(rest, wanted))

# Turn planning (Idle)
# ====================

type Plan is Data:
  Use{slot: D.Slot, item: D.Item}
  Fire{}

type Planned is Data:
  Planned{plan: Plan, mem: Mem}

def planned.mem(planned: Planned) -> Mem:
  match planned:
    case Planned{plan, mem}:
      mem

# The saw's route: an own saw, else an own adrenaline when an opponent has one.
def saw_route(own: Maybe<&2, Held>, adrenaline: Maybe<&2, Held>, stealable: Bool) -> Maybe<&2, Plan>:
  match own adrenaline stealable:
    case Some{Held{slot, item}} _ _:
      Some{Use{slot, item}}
    case None{} Some{Held{slot, item}} True{}:
      Some{Use{slot, item}}
    case _ _ _:
      None{}

def after_saw(+mem: Mem, plan: Plan) -> Mem:
  match plan:
    case Use{slot, item}:
      mem.set_steal_saw(mem.set_aim(mem.set_pending(mem, True{}), Some{AtOpp{}}), D.item.eq(item, D.Adrenaline{}))
    case Fire{}:
      mem

def shoot.aim(aim: Maybe<&2, Aim>, +mem: Mem, coin: Bool) -> Planned:
  match aim:
    case Some{chosen}:
      Planned{Fire{}, mem}
    case None{}:
      Planned{Fire{}, mem.set_aim(mem, Some{Bool.pick(Aim, coin, AtOpp{}, AtSelf{})})}

def shoot(+mem: Mem, coin: Bool) -> Planned:
  shoot.aim(mem.aim(mem), mem, coin)

def fallback.flip(+plan: Plan, +mem: Mem, flip: Bool) -> Planned:
  match flip:
    case False{}:
      Planned{Fire{}, mem.set_aim(mem, Some{AtSelf{}})}
    case True{}:
      Planned{plan, after_saw(mem, plan)}

def fallback.route(route: Maybe<&2, Plan>, +mem: Mem, flip: Bool, can: Bool) -> Planned:
  match route can:
    case Some{plan} True{}:
      fallback.flip(plan, mem, flip)
    case _ _:
      shoot(mem, flip)

def coin_flip(mem: Mem, remaining: Nat, coin: Bool) -> Bool:
  coin

def fallback(+ctx: Ctx, +mem: Mem, coin: Bool) -> Planned:
  +flip : Bool = coin_flip(mem, ctx.remaining(ctx), coin)
  +can : Bool = Bool.not(ctx.sawed(ctx)) && Bool.not(known_is(mem, D.Blank{}))
  +mine : List<&2, Held> = ctx.mine(ctx)
  fallback.route(saw_route(find_held(mine, D.Saw{}), find_held(mine, D.Adrenaline{}), has_loot(ctx.loot(ctx), D.Saw{})), mem, flip, can)

def idle.steal(loot: Maybe<&2, Loot>, slot: D.Slot, +ctx: Ctx, +mem: Mem, coin: Bool) -> Planned:
  match loot:
    case Some{found}:
      Planned{Use{slot, D.Adrenaline{}}, mem}
    case None{}:
      fallback(ctx, mem, coin)

def idle.adrenaline(adrenaline: Maybe<&2, Held>, +ctx: Ctx, +mem: Mem, coin: Bool) -> Planned:
  match adrenaline:
    case Some{Held{slot, item}}:
      idle.steal(first_loot(ctx.loot(ctx), ctx, mem), slot, ctx, mem, coin)
    case None{}:
      fallback(ctx, mem, coin)

def idle.own(choice: Maybe<&2, Held>, +ctx: Ctx, +mem: Mem, coin: Bool) -> Planned:
  match choice:
    case Some{Held{slot, item}}:
      Planned{Use{slot, item}, mem}
    case None{}:
      idle.adrenaline(find_held(ctx.mine(ctx), D.Adrenaline{}), ctx, mem, coin)

def idle.pending(pending: Bool, +ctx: Ctx, +mem: Mem, coin: Bool) -> Planned:
  match pending:
    case True{}:
      Planned{Fire{}, mem.set_aim(mem, Some{AtOpp{}})}
    case False{}:
      idle.own(first_held(ctx.mine(ctx), ctx, mem), ctx, mem, coin)

def idle(+ctx: Ctx, +mem: Mem, coin: Bool) -> Planned:
  idle.pending(mem.pending(mem), ctx, mem, coin)

# Targets
# =======

type Cand is Data:
  Cand{move: D.Move, key: Nat}

def target.key.counter(counter: D.Counter, max_hp: Nat) -> Nat:
  match counter:
    case D.Unjammed{0n}:
      1000n
    case D.Unjammed{1n+health}:
      1n+health
    case D.Jammed{}:
      max_hp

def target.key.view(view: Maybe<&2, D.SeatView>, max_hp: Nat) -> Nat:
  match view:
    case Some{D.SeatView{counter, slots, cash, briefcase}}:
      target.key.counter(counter, max_hp)
    case None{}:
      1000n

# Sort key of a seat as a target: dead seats last.
def target.key(ctx: Ctx, seat: D.Seat) -> Nat:
  match ctx:
    case Ctx{me, max_hp, hp, remaining, sawed, seats, mine, loot, opp_free}:
      target.key.view(D.ring.get(D.SeatView, seats, seat), max_hp)

def cand.make(self: Bool, move: D.Move, key: Nat) -> Maybe<&2, Cand>:
  match self:
    case True{}:
      None{}
    case False{}:
      Some{Cand{move, key}}

def candidate(+ctx: Ctx, move: D.Move) -> Maybe<&2, Cand>:
  match move:
    case D.Shoot{+target}:
      cand.make(D.seat.eq(target, ctx.me(ctx)), D.Shoot{target}, target.key(ctx, target))
    case D.JamTarget{+target}:
      cand.make(D.seat.eq(target, ctx.me(ctx)), D.JamTarget{target}, target.key(ctx, target))
    case _:
      None{}

def cand.better(best: Maybe<&2, Cand>, next: Maybe<&2, Cand>) -> Maybe<&2, Cand>:
  match best next:
    case None{} next:
      next
    case best None{}:
      best
    case Some{Cand{move, +key}} Some{Cand{other, +found}}:
      Bool.pick(Maybe<&2, Cand>, Nat.is_lt(found, key), Some{Cand{other, found}}, Some{Cand{move, key}})

def cand.move(best: Maybe<&2, Cand>) -> Maybe<&2, D.Move>:
  match best:
    case None{}:
      None{}
    case Some{Cand{move, key}}:
      Some{move}

# The first move aimed at the weakest living opponent (strictly lower keys win,
# so ties keep the lowest socket).
def lowest(moves: List<&2, D.Move>, +ctx: Ctx, best: Maybe<&2, Cand>) -> Maybe<&2, D.Move>:
  match moves:
    case Nil{}:
      cand.move(best)
    case move <> rest:
      lowest(rest, ctx, cand.better(best, candidate(ctx, move)))

def prompt.moves(prompt: D.Prompt) -> List<&2, D.Move>:
  match prompt:
    case D.Prompt{seat, first, menu}:
      D.nonempty.list(D.Move, menu)

def lowest.pick(found: Maybe<&2, D.Move>, +prompt: D.Prompt) -> Nat:
  match found:
    case Some{move}:
      or0(D.prompt.index(prompt, move))
    case None{}:
      0n

def aim_at_opponent(+prompt: D.Prompt, +ctx: Ctx) -> Nat:
  lowest.pick(lowest(prompt.moves(prompt), ctx, None{}), prompt)

# Prompts
# =======

def move.rank(move: D.Move) -> Nat:
  match move:
    case D.UseItem{slot, item}:
      0n
    case D.PickUp{}:
      1n
    case D.Shoot{target}:
      2n
    case D.Grab{}:
      3n
    case D.Place{slot}:
      3n
    case D.JamTarget{target}:
      4n
    case D.Steal{owner, slot, item}:
      5n

def rank.max(+a: Nat, +b: Nat) -> Nat:
  Bool.pick(Nat, Nat.is_gt(a, b), a, b)

# The kind of decision a menu asks for; the highest-ranked move wins.
def menu.rank(moves: List<&2, D.Move>) -> Nat:
  match moves:
    case Nil{}:
      0n
    case move <> rest:
      rank.max(move.rank(move), menu.rank(rest))

def steal.ok(only_saw: Bool, item: D.Item, eligible: Bool) -> Bool:
  match only_saw:
    case True{}:
      D.item.eq(item, D.Saw{})
    case False{}:
      eligible

def steal.first(moves: List<&2, D.Move>, +ctx: Ctx, +mem: Mem, +only_saw: Bool) -> Maybe<&2, D.Move>:
  match moves:
    case Nil{}:
      None{}
    case D.Steal{owner, slot, +item} <> rest:
      Bool.pick(Maybe<&2, D.Move>, steal.ok(only_saw, item, eligible(ctx, mem, item)), Some{D.Steal{owner, slot, item}}, steal.first(rest, ctx, mem, only_saw))
    case move <> rest:
      steal.first(rest, ctx, mem, only_saw)

def decide.steal(+prompt: D.Prompt, +ctx: Ctx, +mem: Mem) -> D.Decision<&2, Mem>:
  +wanted : Maybe<&2, D.Move> = steal.first(prompt.moves(prompt), ctx, mem, mem.steal_saw(mem))
  D.Decision{lowest.pick(wanted, prompt), mem.set_steal_saw(mem, False{})}

def decide.jam(+prompt: D.Prompt, +ctx: Ctx, mem: Mem) -> D.Decision<&2, Mem>:
  D.Decision{aim_at_opponent(prompt, ctx), mem}

def decide.grab(prompt: D.Prompt, mem: Mem) -> D.Decision<&2, Mem>:
  D.Decision{or0(D.prompt.index(prompt, D.Grab{})), mem}

def idle.done(+prompt: D.Prompt, planned: Planned) -> D.Decision<&2, Mem>:
  match planned:
    case Planned{Use{slot, item}, mem}:
      D.Decision{or0(D.prompt.index(prompt, D.UseItem{slot, item})), mem}
    case Planned{Fire{}, mem}:
      D.Decision{or0(D.prompt.index(prompt, D.PickUp{})), mem}

# One shell left: it is the one the counts name.
def known_single(counts: Maybe<&2, D.Load>, +mem: Mem) -> Mem:
  match counts:
    case Some{D.Load{live, blank}}:
      learn(mem, Bool.pick(D.Shell, Nat.is_eq(live, 0n), D.Blank{}, D.Live{}))
    case None{}:
      mem

# Policy hooks. Story: no upgrades.

def prepare.single(single: Bool, +mem: Mem, remaining: Nat) -> Mem:
  match single:
    case True{}:
      known_single(tally(mem, remaining), mem)
    case False{}:
      mem

def prepare(+remaining: Nat, +mem: Mem) -> Mem:
  prepare.single(Nat.is_eq(remaining, 1n), mem, remaining)

def decide.idle(+prompt: D.Prompt, +ctx: Ctx, mem: Mem, coin: Bool) -> D.Decision<&2, Mem>:
  +ready : Mem = prepare(ctx.remaining(ctx), mem)
  idle.done(prompt, idle(ctx, ready, coin))

def aim.at(aim: Maybe<&2, Aim>, +prompt: D.Prompt, +ctx: Ctx, mem: Mem) -> D.Decision<&2, Mem>:
  match aim:
    case Some{AtSelf{}}:
      D.Decision{or0(D.prompt.index(prompt, D.Shoot{ctx.me(ctx)})), mem}
    case _:
      D.Decision{aim_at_opponent(prompt, ctx), mem}

def decide.aim(+prompt: D.Prompt, +ctx: Ctx, mem: Mem, coin: Bool) -> D.Decision<&2, Mem>:
  +ready : Mem = prepare(ctx.remaining(ctx), mem)
  +aimed : Mem = planned.mem(shoot(ready, coin_flip(ready, ctx.remaining(ctx), coin)))
  aim.at(mem.aim(aimed), prompt, ctx, aimed)

def decide.rank(rank: Nat, +prompt: D.Prompt, +ctx: Ctx, +mem: Mem, coin: Bool) -> D.Decision<&2, Mem>:
  match rank:
    case 5n:
      decide.steal(prompt, ctx, prepare(ctx.remaining(ctx), mem))
    case 4n:
      decide.jam(prompt, ctx, mem)
    case 3n:
      decide.grab(prompt, mem)
    case 2n:
      decide.aim(prompt, ctx, mem, coin)
    case 1n:
      decide.idle(prompt, ctx, mem, coin)
    case _:
      D.Decision{0n, mem}

# The seat's decision for one prompt: heard events first, then the move.
# `pick` indexes prompt.menu; `coin` is this seat's own random word.
def decide(+prompt: D.Prompt, obs: D.Obs, heard: List<&2, D.Heard>, mem: Mem, coin: U32) -> D.Decision<&2, Mem>:
  +ctx : Ctx = ctx.of(obs)
  +current : Mem = update(heard, ctx.me(ctx), mem)
  decide.rank(menu.rank(prompt.moves(prompt)), prompt, ctx, current, U32.is_eq(U32.mod(coin, 2), 1))
