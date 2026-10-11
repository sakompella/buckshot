import Base
import ./model.bend as M

type Policy is Data:
  Story{}
  DoN{}
  AlwaysOpp{}
type PhoneKnowledge is Data:
  Seen{index: Nat, shell: M.Shell}
type Mem is Data:
  Mem{known: Maybe<&2, M.Shell>, target: Maybe<&2, M.Target>, phone: List<&2, PhoneKnowledge>, sawed: Bool, pending_shot: Bool}

def fresh() -> Mem:
  Mem{None{}, None{}, Nil{}, False{}, False{}}

def shell_target(shell: M.Shell) -> M.Target:
  match shell:
    case M.Live{}:
      M.Opp{}
    case M.Blank{}:
      M.Self{}

def learn(mem: Mem, +shell: M.Shell) -> Mem:
  match mem:
    case Mem{_, _, phone, sawed, pending}:
      Mem{Some{shell}, Some{shell_target(shell)}, phone, sawed, pending}

def knows(mem: Mem) -> Bool:
  match mem:
    case Mem{None{}, _, _, _, _}:
      False{}
    case Mem{Some{_}, _, _, _, _}:
      True{}

def known_is(mem: Mem, shell: M.Shell) -> Bool:
  match mem:
    case Mem{None{}, _, _, _, _}:
      False{}
    case Mem{Some{known}, _, _, _, _}:
      M.shell_eq(known, shell)

def is_sawed(mem: Mem) -> Bool:
  match mem:
    case Mem{_, _, _, sawed, _}:
      sawed

def phone_remove(xs: List<&2, PhoneKnowledge>, +index: Nat) -> List<&2, PhoneKnowledge>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Seen{+i, shell}, tail}:
      +rest: List<&2, PhoneKnowledge> = phone_remove(tail, index)
      Bool.pick(List<&2, PhoneKnowledge>, Nat.is_eq(i, index), rest, Seen{i, shell} <> rest)

def phone_shift(xs: List<&2, PhoneKnowledge>) -> List<&2, PhoneKnowledge>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Seen{0n, _}, tail}:
      phone_shift(tail)
    case Con{Seen{1n+i, shell}, tail}:
      Seen{i, shell} <> phone_shift(tail)

def phone_invert(xs: List<&2, PhoneKnowledge>) -> List<&2, PhoneKnowledge>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Seen{0n, M.Live{}}, tail}:
      Seen{0n, M.Blank{}} <> phone_invert(tail)
    case Con{Seen{0n, M.Blank{}}, tail}:
      Seen{0n, M.Live{}} <> phone_invert(tail)
    case Con{Seen{1n+i, shell}, tail}:
      Seen{1n+i, shell} <> phone_invert(tail)

def phone_chamber(xs: List<&2, PhoneKnowledge>) -> Maybe<&2, M.Shell>:
  match xs:
    case Nil{}:
      None{}
    case Con{Seen{0n, shell}, _}:
      Some{shell}
    case Con{Seen{1n+_, _}, tail}:
      phone_chamber(tail)

def unknown_counts(xs: List<&2, PhoneKnowledge>, live: Nat, blank: Nat) -> Nat & Nat:
  match xs:
    case Nil{}:
      (live, blank)
    case Con{Seen{_, M.Live{}}, tail}:
      unknown_counts(tail, Nat.sub(live, 1n), blank)
    case Con{Seen{_, M.Blank{}}, tail}:
      unknown_counts(tail, live, Nat.sub(blank, 1n))

def learn_from_counts(counts: Nat & Nat, +mem: Mem) -> Mem:
  match counts:
    case (0n, _):
      learn(mem, M.Blank{})
    case (1n+_, 0n):
      learn(mem, M.Live{})
    case (1n+_, 1n+_):
      mem

def deduce_chamber(chamber: Maybe<&2, M.Shell>, +phone: List<&2, PhoneKnowledge>, live: Nat, blank: Nat, mem: Mem) -> Mem:
  match chamber:
    case Some{shell}:
      learn(mem, shell)
    case None{}:
      learn_from_counts(unknown_counts(phone, live, blank), mem)

def deduce_unless_known(known: Bool, obs: M.Obs, +mem: Mem) -> Mem:
  match known:
    case True{}:
      mem
    case False{}:
      match obs mem:
        case M.Obs{_, _, _, _, live, blank, _, _} Mem{_, _, +phone, _, _}:
          deduce_chamber(phone_chamber(phone), phone, live, blank, mem)

def prepare_policy(policy: Policy, +obs: M.Obs, +mem: Mem) -> Mem:
  match policy:
    case DoN{}:
      deduce_unless_known(knows(mem), obs, mem)
    case _:
      mem

def prepare_single(single: Bool, policy: Policy, +obs: M.Obs, mem: Mem) -> Mem:
  match single:
    case True{}:
      match obs:
        case M.Obs{_, _, _, _, live, _, _, _}:
          learn(mem, Bool.pick(M.Shell, Nat.is_eq(live, 0n), M.Blank{}, M.Live{}))
    case False{}:
      prepare_policy(policy, obs, mem)

def prepare(policy: Policy, +obs: M.Obs, mem: Mem) -> Mem:
  match obs:
    case M.Obs{_, _, _, _, _, _, remaining, _}:
      prepare_single(Nat.is_eq(remaining, 1n), policy, obs, mem)

def coin_flip(policy: Policy, obs: M.Obs, coin: Bool) -> Bool:
  match policy:
    case DoN{}:
      match obs:
        case M.Obs{_, _, _, _, +live, +blank, _, _}:
          Bool.pick(Bool, Nat.is_eq(live, blank), coin, Nat.is_gt(live, blank))
    case _:
      coin

def eligible(obs: M.Obs, +mem: Mem, item: M.Item) -> Bool:
  match obs:
    case M.Obs{_, M.Player{hp, _, _, _}, M.Player{_, _, jammed, _}, max_hp, _, _, +remaining, _}:
      match item:
        case M.Glass{}:
          Bool.not(knows(mem)) && Nat.is_ne(remaining, 1n)
        case M.Cigs{}:
          Nat.is_lt(hp, max_hp)
        case M.Beer{}:
          Bool.not(known_is(mem, M.Live{})) && Nat.is_ne(remaining, 1n)
        case M.Jammer{}:
          Bool.not(jammed) && Nat.is_ne(remaining, 1n)
        case M.Saw{}:
          Bool.not(is_sawed(mem)) && known_is(mem, M.Live{})
        case M.Phone{}:
          Nat.is_gt(remaining, 2n)
        case M.Inverter{}:
          known_is(mem, M.Blank{})
        case M.Adrenaline{}:
          False{}

def first_item(xs: List<&2, M.Item>, +obs: M.Obs, +mem: Mem) -> Maybe<&2, M.Item>:
  match xs:
    case Nil{}:
      None{}
    case Con{+item, tail}:
      Bool.pick(Maybe<&2, M.Item>, eligible(obs, mem, item), Some{item}, first_item(tail, obs, mem))

def own_items(obs: M.Obs) -> List<&2, M.Item>:
  match obs:
    case M.Obs{_, M.Player{_, items, _, _}, _, _, _, _, _, _}:
      items

def opp_items(obs: M.Obs) -> List<&2, M.Item>:
  match obs:
    case M.Obs{_, _, M.Player{_, items, _, _}, _, _, _, _, _}:
      items

def item_action(+obs: M.Obs, +item: M.Item) -> M.Action:
  Bool.pick(M.Action, M.has_item(own_items(obs), item), M.Use{item}, M.Steal{item})

def scan_opp(adrenaline: Bool, +obs: M.Obs, mem: Mem) -> Maybe<&2, M.Item>:
  match adrenaline:
    case True{}:
      first_item(opp_items(obs), obs, mem)
    case False{}:
      None{}

def scan_own(choice: Maybe<&2, M.Item>, +obs: M.Obs, mem: Mem) -> Maybe<&2, M.Item>:
  match choice:
    case Some{item}:
      Some{item}
    case None{}:
      scan_opp(M.has_item(own_items(obs), M.Adrenaline{}), obs, mem)

def available_saw(+obs: M.Obs) -> Bool:
  M.has_item(own_items(obs), M.Saw{}) || (M.has_item(own_items(obs), M.Adrenaline{}) && M.has_item(opp_items(obs), M.Saw{}))

def fallback_pending(mem: Mem) -> Mem:
  match mem:
    case Mem{known, _, phone, sawed, _}:
      Mem{known, Some{M.Opp{}}, phone, sawed, True{}}

def shoot_target(target: Maybe<&2, M.Target>, coin: Bool, mem: Mem) -> M.Action & Mem:
  match target:
    case Some{chosen}:
      (M.Shoot{chosen}, mem)
    case None{}:
      (M.Shoot{Bool.pick(M.Target, coin, M.Opp{}, M.Self{})}, mem)

def shoot(+mem: Mem, coin: Bool) -> M.Action & Mem:
  match mem:
    case Mem{_, target, _, _, _}:
      shoot_target(target, coin, mem)

def fallback_coin(coin: Bool, obs: M.Obs, mem: Mem) -> M.Action & Mem:
  match coin:
    case False{}:
      (M.Shoot{M.Self{}}, mem)
    case True{}:
      (item_action(obs, M.Saw{}), fallback_pending(mem))

def fallback(can_saw: Bool, +policy: Policy, +obs: M.Obs, mem: Mem, coin: Bool) -> M.Action & Mem:
  match can_saw:
    case True{}:
      fallback_coin(coin_flip(policy, obs, coin), obs, mem)
    case False{}:
      shoot(mem, coin_flip(policy, obs, coin))

def choose(choice: Maybe<&2, M.Item>, +policy: Policy, +obs: M.Obs, +mem: Mem, coin: Bool) -> M.Action & Mem:
  match choice:
    case Some{item}:
      (item_action(obs, item), mem)
    case None{}:
      fallback(available_saw(obs) && Bool.not(is_sawed(mem)) && Bool.not(known_is(mem, M.Blank{})), policy, obs, mem, coin)

def decide_ready(policy: Policy, +obs: M.Obs, +mem: Mem, coin: Bool) -> M.Action & Mem:
  match policy:
    case AlwaysOpp{}:
      (M.Shoot{M.Opp{}}, mem)
    case +brain:
      +ready: Mem = prepare(brain, obs, mem)
      choose(scan_own(first_item(own_items(obs), obs, ready), obs, ready), brain, obs, ready, coin)

def decide(policy: Policy, obs: M.Obs, +mem: Mem, coin: Bool) -> M.Action & Mem:
  match mem:
    case Mem{_, _, _, _, True{}}:
      (M.Shoot{M.Opp{}}, mem)
    case Mem{_, _, _, _, False{}}:
      decide_ready(policy, obs, mem, coin)

def remember(mem: Mem, +index: Nat, shell: M.Shell) -> Mem:
  match mem:
    case Mem{known, target, phone, sawed, pending}:
      Mem{known, target, Seen{index, shell} <> phone_remove(phone, index), sawed, pending}

def reveal(index: Nat, shell: M.Shell, mem: Mem) -> Mem:
  match index:
    case 0n:
      learn(mem, shell)
    case 1n+i:
      remember(mem, 1n+i, shell)

def shift(mem: Mem) -> Mem:
  match mem:
    case Mem{known, target, phone, sawed, pending}:
      Mem{known, target, phone_shift(phone), sawed, pending}

def invert_phone(mem: Mem) -> Mem:
  match mem:
    case Mem{known, target, phone, sawed, pending}:
      Mem{known, target, phone_invert(phone), sawed, pending}

def reset_shot(mem: Mem) -> Mem:
  match mem:
    case Mem{_, _, phone, _, _}:
      Mem{None{}, None{}, phone, False{}, False{}}

def beer_reset(policy: Policy, mem: Mem) -> Mem:
  match policy:
    case DoN{}:
      match mem:
        case Mem{_, target, phone, sawed, pending}:
          Mem{None{}, target, phone, sawed, pending}
    case _:
      mem

def used(item: M.Item, mem: Mem) -> Mem:
  match item:
    case M.Saw{}:
      match mem:
        case Mem{known, target, phone, _, pending}:
          Mem{known, target, phone, True{}, pending}
    case _:
      mem

def update_event(event: M.GameEvent, policy: Policy, +side: M.Side, +mem: Mem) -> Mem:
  match event:
    case M.Reveal{actor, index, shell}:
      Bool.pick(Mem, M.side_eq(side, actor), reveal(index, shell, mem), mem)
    case M.Fired{actor, _, _, _}:
      +shifted: Mem = shift(mem)
      Bool.pick(Mem, M.side_eq(side, actor), reset_shot(shifted), shifted)
    case M.Ejected{actor, _}:
      +shifted: Mem = shift(mem)
      Bool.pick(Mem, M.side_eq(side, actor), beer_reset(policy, shifted), shifted)
    case M.Inverted{actor, shell}:
      +inverted: Mem = invert_phone(mem)
      Bool.pick(Mem, M.side_eq(side, actor), learn(inverted, shell), inverted)
    case M.Used{actor, item, _}:
      Bool.pick(Mem, M.side_eq(side, actor), used(item, mem), mem)
    case M.Reloaded{_, _}:
      fresh()
    case M.RoundStarted{_, _, _}:
      fresh()
    case _:
      mem

def update_events(events: List<&2, M.GameEvent>, +policy: Policy, +side: M.Side, mem: Mem) -> Mem:
  match events:
    case Nil{}:
      mem
    case Con{event, tail}:
      update_events(tail, policy, side, update_event(event, policy, side, mem))

def update(policy: Policy, side: M.Side, mem: Mem, events: List<&2, M.GameEvent>) -> Mem:
  update_events(events, policy, side, mem)
