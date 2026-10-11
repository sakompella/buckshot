import Base

type Shell is Data:
  Live{}
  Blank{}
type Item is Data:
  Saw{}
  Glass{}
  Jammer{}
  Cigs{}
  Beer{}
  Phone{}
  Adrenaline{}
  Inverter{}
type Side is Data:
  A{}
  B{}
type Target is Data:
  Self{}
  Opp{}
type Action is Data:
  Use{item: Item}
  Steal{item: Item}
  Shoot{target: Target}
type PlayerState is Data:
  Player{hp: Nat, items: List<&2, Item>, jammed: Bool, checked: Bool}
type Obs is Data:
  Obs{side: Side, own: PlayerState, opp: PlayerState, max_hp: Nat, live: Nat, blank: Nat, remaining: Nat, sawed: Bool}
type GameEvent is Data:
  Reveal{side: Side, index: Nat, shell: Shell}
  Fired{side: Side, target: Target, shell: Shell, damage: Nat}
  Ejected{side: Side, shell: Shell}
  Inverted{side: Side, shell: Shell}
  Used{side: Side, item: Item, stolen: Bool}
  Reloaded{live: Nat, blank: Nat}
  Skipped{side: Side}
  RoundStarted{number: Nat, max_hp: Nat, first: Side}
  RoundWon{side: Side, prize: U32}
  MatchWon{side: Side}
  Exhausted{}
type Load is Data:
  Load{live: Nat, blank: Nat}
type Game is Data:
  Game{a: PlayerState, b: PlayerState, turn: Side, max_hp: Nat, shells: List<&2, Shell>, deck: List<&2, Load>, seed: U32, counter: U32, sawed: Bool, round: Nat, wins_a: U32, wins_b: U32, cash_a: U32, cash_b: U32, done: Bool}

def other(side: Side) -> Side:
  match side:
    case A{}:
      B{}
    case B{}:
      A{}
def side_eq(a: Side, b: Side) -> Bool:
  match a b:
    case A{} A{}:
      True{}
    case B{} B{}:
      True{}
    case _ _:
      False{}
def shell_eq(a: Shell, b: Shell) -> Bool:
  match a b:
    case Live{} Live{}:
      True{}
    case Blank{} Blank{}:
      True{}
    case _ _:
      False{}
def item_code(item: Item) -> U32:
  match item:
    case Saw{}:
      0
    case Glass{}:
      1
    case Jammer{}:
      2
    case Cigs{}:
      3
    case Beer{}:
      4
    case Phone{}:
      5
    case Adrenaline{}:
      6
    case Inverter{}:
      7
def item_eq(a: Item, b: Item) -> Bool:
  U32.is_eq(item_code(a), item_code(b))
def has_item(items: List<&2, Item>, +item: Item) -> Bool:
  List.contains(~Item, ~item_eq, items, item)
def count_item(items: List<&2, Item>, +item: Item) -> Nat:
  match items:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(Bool.pick(Nat, item_eq(h, item), 1n, 0n), count_item(t, item))
def shell_count(shells: List<&2, Shell>, +shell: Shell) -> Nat:
  match shells:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(Bool.pick(Nat, shell_eq(h, shell), 1n, 0n), shell_count(t, shell))
def remove_item.fin(hit: Bool, h: Item, t: List<&2, Item>, r: List<&2, Item>) -> List<&2, Item>:
  match hit:
    case True{}:
      t
    case False{}:
      h <> r
def remove_item(items: List<&2, Item>, +item: Item) -> List<&2, Item>:
  match items:
    case Nil{}:
      Nil{}
    case +h <> +t:
      remove_item.fin(item_eq(h, item), h, t, remove_item(t, item))
def select_player(side: Side, a: PlayerState, b: PlayerState) -> PlayerState:
  match side:
    case A{}:
      a
    case B{}:
      b
def player(+g: Game, side: Side) -> PlayerState:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  select_player(side,a,b)
def current(+g: Game) -> Side:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  turn
def observe(+g: Game, +side: Side) -> Obs:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  Obs{side,player(g,side),player(g,other(side)),max_hp,shell_count(shells,Live{}),shell_count(shells,Blank{}),List.length(&2,Shell,shells),sawed}
def mix(+x: U32) -> U32:
  +x1 : U32 = U32.xor(x,U32.shrn(x,16n))
  +x2 : U32 = U32.mul(x1,2146121005)
  +x3 : U32 = U32.xor(x2,U32.shrn(x2,15n))
  +x4 : U32 = U32.mul(x3,2221713035)
  U32.xor(x4,U32.shrn(x4,16n))

def set_turn(g: Game, value: Side) -> Game:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  Game{a,b,value,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done}

def set_shells(g: Game, value: List<&2, Shell>) -> Game:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  Game{a,b,turn,max_hp,value,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done}

def set_deck(g: Game, value: List<&2, Load>) -> Game:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  Game{a,b,turn,max_hp,shells,value,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done}

def set_counter(g: Game, value: U32) -> Game:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  Game{a,b,turn,max_hp,shells,deck,seed,value,sawed,round,wins_a,wins_b,cash_a,cash_b,done}

def set_sawed(g: Game, value: Bool) -> Game:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  Game{a,b,turn,max_hp,shells,deck,seed,counter,value,round,wins_a,wins_b,cash_a,cash_b,done}

def set_done(g: Game, value: Bool) -> Game:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,value}

def put_player(g: Game, +side: Side, +p: PlayerState) -> Game:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  Game{select_player(side,p,a),select_player(side,b,p),turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done}
def random(+g: Game, bound: U32) -> Game & U32:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  (set_counter(g,(counter + 1 : U32)), U32.mod(mix(U32.xor(seed,mix(counter))),bound))
def coin.result(pair: Game & U32) -> Game & Bool:
  (g,r) = pair
  (g,U32.is_eq(r,1))
def coin(g: Game) -> Game & Bool:
  coin.result(random(g,2))
def damage_hp(hp: Nat, damage: Nat) -> Nat:
  Nat.sub(hp,damage)
def heal_hp(+hp: Nat, +max_hp: Nat) -> Nat:
  Bool.pick(Nat,Nat.is_lt(hp,max_hp),1n+hp,max_hp)
def hurt(p: PlayerState, damage: Nat) -> PlayerState:
  Player{hp,items,jammed,checked} = p
  Player{damage_hp(hp,damage),items,jammed,checked}
def remove_from(p: PlayerState, item: Item) -> PlayerState:
  Player{hp,items,jammed,checked} = p
  Player{hp,remove_item(items,item),jammed,checked}
def heal(p: PlayerState, max_hp: Nat) -> PlayerState:
  Player{hp,items,jammed,checked} = p
  Player{heal_hp(hp,max_hp),items,jammed,checked}
def jam(p: PlayerState) -> PlayerState:
  Player{hp,items,jammed,checked} = p
  Player{hp,items,True{},False{}}
def default_deck() -> List<&2, Load>:
  [Load{1n,2n},Load{2n,1n},Load{2n,2n},Load{3n,2n},Load{1n,1n},Load{2n,3n},Load{3n,3n},Load{3n,1n},Load{4n,2n}]
def refill(deck: List<&2, Load>) -> List<&2, Load>:
  match deck:
    case Nil{}:
      default_deck()
    case h <> t:
      h <> t
def take_load.put(h: Load, pair: Load & List<&2, Load>) -> Load & List<&2, Load>:
  (load,rest) = pair
  (load,h <> rest)
def take_load(xs: List<&2, Load>, index: Nat) -> Load & List<&2, Load>:
  match xs index:
    case Nil{} _:
      (Load{1n,1n},Nil{})
    case h <> t 0n:
      (h,t)
    case h <> t 1n+p:
      take_load.put(h,take_load(t,p))
type ShuffleState is Data:
  ShuffleState{game: Game, shell: Shell, live: Nat, blank: Nat}
def shuffled.next(pair: Game & U32, +live: Nat, +blank: Nat) -> ShuffleState:
  (g,r) = pair
  +is_live : Bool = U32.is_lt(r,U32.from_nat(live))
  ShuffleState{g,Bool.pick(Shell,is_live,Live{},Blank{}),Bool.pick(Nat,is_live,Nat.sub(live,1n),live),Bool.pick(Nat,is_live,blank,Nat.sub(blank,1n))}
def shuffled.put(shell: Shell, pair: Game & List<&2, Shell>) -> Game & List<&2, Shell>:
  (g,tail) = pair
  (g,shell <> tail)
def shuffled(fuel: Nat, st: ShuffleState) -> Game & List<&2, Shell>:
  match fuel:
    case 0n:
      ShuffleState{g,shell,live,blank} = st
      (g,Nil{})
    case 1n+0n:
      ShuffleState{g,shell,live,blank} = st
      (g,[shell])
    case 1n+1n+f:
      ShuffleState{g,shell,+live,+blank} = st
      shuffled.put(shell,shuffled(1n+f,shuffled.next(random(g,U32.from_nat(Nat.add(live,blank))),live,blank)))
def item_cap(item: Item) -> Nat:
  match item:
    case Saw{}:
      2n
    case Glass{}:
      2n
    case Jammer{}:
      1n
    case Cigs{}:
      1n
    case Beer{}:
      8n
    case Phone{}:
      8n
    case Adrenaline{}:
      4n
    case Inverter{}:
      4n
def available(item: Item, +own: List<&2, Item>, +opp: List<&2, Item>) -> Bool:
  +it : Item = item
  Bool.and(Nat.is_lt(count_item(own,it),item_cap(it)),Bool.or(Bool.not(item_eq(it,Jammer{})),Bool.not(has_item(opp,Jammer{}))))
def item_pool(candidates: List<&2, Item>, +own: List<&2, Item>, +opp: List<&2, Item>) -> List<&2, Item>:
  match candidates:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.filter.put(Item,h,item_pool(t,own,opp),available(h,own,opp))
def get_item(xs: List<&2, Item>, index: Nat) -> Item:
  match xs index:
    case Nil{} _:
      Beer{}
    case h <> t 0n:
      h
    case h <> t 1n+p:
      get_item(t,p)
def get_shell(xs: List<&2, Shell>, index: Nat) -> Shell:
  match xs index:
    case Nil{} _:
      Blank{}
    case h <> t 0n:
      h
    case h <> t 1n+p:
      get_shell(t,p)
def add_item(p: PlayerState, item: Item) -> PlayerState:
  Player{hp,items,jammed,checked} = p
  Player{hp,List.append(&2,Item,items,[item]),jammed,checked}
def give_item.result(pair: Game & U32, +side: Side, pool: List<&2, Item>) -> Game:
  (+g,r) = pair
  put_player(g,side,add_item(player(g,side),get_item(pool,U32.to_nat(r))))
def give_item.ready(ready: Bool, g: Game, side: Side, +pool: List<&2, Item>) -> Game:
  match ready:
    case False{}:
      g
    case True{}:
      give_item.result(random(g,U32.from_nat(List.length(&2,Item,pool))),side,pool)
def give_item.players(own: PlayerState, opp: PlayerState, g: Game, side: Side) -> Game:
  Player{hp,+items,jammed,checked} = own
  Player{ohp,oi,oj,oc} = opp
  +pool : List<&2, Item> = item_pool([Saw{},Glass{},Jammer{},Cigs{},Beer{},Phone{},Adrenaline{},Inverter{}],items,oi)
  give_item.ready(Bool.and(Nat.is_gt(hp,0n),Bool.and(Nat.is_lt(List.length(&2,Item,items),8n),Bool.not(List.is_empty(&2,Item,pool)))),g,side,pool)
def give_item(+g: Game, +side: Side) -> Game:
  give_item.players(player(g,side),player(g,other(side)),g,side)
def grab_items.pair(pair: Game & Bool) -> Game:
  (g,c) = pair
  +first : Side = Bool.pick(Side,c,A{},B{})
  g2 : Game = give_item(g,first)
  give_item(g2,other(first))
def grab_items(n: Nat, g: Game) -> Game:
  match n:
    case 0n:
      g
    case 1n+p:
      grab_items(p,grab_items.pair(coin(g)))
def reload.items(pair: Game & U32, live: Nat, blank: Nat) -> Game & List<&2, GameEvent>:
  (g,n) = pair
  (grab_items(Nat.add(2n,U32.to_nat(n)),g),[Reloaded{live,blank}])
def reload.shuffled(pair: Game & List<&2, Shell>, rest: List<&2, Load>, live: Nat, blank: Nat) -> Game & List<&2, GameEvent>:
  (g,seq) = pair
  g1 : Game = set_deck(set_shells(g,seq),rest)
  reload.items(random(g1,3),live,blank)
def reload.load(pair: Load & List<&2, Load>, g: Game) -> Game & List<&2, GameEvent>:
  (load,rest) = pair
  Load{+live,+blank} = load
  reload.shuffled(shuffled(Nat.add(live,blank),shuffled.next(random(g,U32.from_nat(Nat.add(live,blank))),live,blank)),rest,live,blank)
def reload.draw(pair: Game & U32, deck: List<&2, Load>) -> Game & List<&2, GameEvent>:
  (g,r) = pair
  reload.load(take_load(deck,U32.to_nat(r)),g)
def reload(+g: Game) -> Game & List<&2, GameEvent>:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  +deck1 : List<&2, Load> = refill(deck)
  reload.draw(random(g,U32.from_nat(List.length(&2,Load,deck1))),deck1)

def prepend_events(events: List<&2, GameEvent>, pair: Game & List<&2, GameEvent>) -> Game & List<&2, GameEvent>:
  (g,rest) = pair
  (g,List.append(&2,GameEvent,events,rest))
type TurnStatus is Data:
  TurnStatus{game: Game, skipped: Bool, events: List<&2, GameEvent>}
def turn_status.player(p: PlayerState, +g: Game, +side: Side) -> TurnStatus:
  match p:
    case Player{hp,items,False{},checked}:
      TurnStatus{g,False{},Nil{}}
    case Player{hp,items,True{},False{}}:
      TurnStatus{set_turn(put_player(g,side,Player{hp,items,True{},True{}}),other(side)),True{},[Skipped{side}]}
    case Player{hp,items,True{},True{}}:
      TurnStatus{put_player(g,side,Player{hp,items,False{},True{}}),False{},Nil{}}
def turn_status(+g: Game) -> TurnStatus:
  turn_status.player(player(g,current(g)),g,current(g))
def begin_turn(fuel: Nat, st: TurnStatus) -> Game & List<&2, GameEvent>:
  match fuel:
    case 0n:
      TurnStatus{g,skipped,events} = st
      (g,events)
    case 1n+f:
      match st:
        case TurnStatus{g,False{},events}:
          (g,events)
        case TurnStatus{g,True{},events}:
          prepend_events(events,begin_turn(f,turn_status(g)))
def reload_if_empty.shells(shells: List<&2, Shell>, g: Game) -> Game & List<&2, GameEvent>:
  match shells:
    case Nil{}:
      reload(g)
    case h <> t:
      (g,Nil{})
def reload_if_empty(+g: Game) -> Game & List<&2, GameEvent>:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  reload_if_empty.shells(shells,g)
def flow_turn(pair: Game & List<&2, GameEvent>) -> Game & List<&2, GameEvent>:
  (g,events) = pair
  prepend_events(events,begin_turn(4n,turn_status(g)))
def round_start.health(pair: Game & U32) -> Game & List<&2, GameEvent>:
  (+g,r) = pair
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  +hp : Nat = Nat.add(3n,U32.to_nat(r))
  g1 : Game = Game{Player{hp,Nil{},False{},False{}},Player{hp,Nil{},False{},False{}},turn,hp,Nil{},deck,seed,counter,False{},round,wins_a,wins_b,cash_a,cash_b,done}
  prepend_events([RoundStarted{round,hp,turn}],reload(g1))
def round_start(g: Game) -> Game & List<&2, GameEvent>:
  round_start.health(random(g,2))
def start.first(pair: Game & Bool) -> Game & List<&2, GameEvent>:
  (g,c) = pair
  round_start(set_turn(g,Bool.pick(Side,c,A{},B{})))
def start(seed: U32) -> Game & List<&2, GameEvent>:
  start.first(coin(Game{Player{0n,Nil{},False{},False{}},Player{0n,Nil{},False{},False{}},A{},0n,Nil{},Nil{},seed,0,False{},1n,0,0,0,0,False{}}))
def prize(round: Nat) -> U32:
  match round:
    case 1n+0n:
      70000
    case 1n+1n+0n:
      75000
    case _:
      80000
def round_finish.last(last: Bool, +g: Game, winner: Side, amount: U32) -> Game & List<&2, GameEvent>:
  match last:
    case False{}:
      prepend_events([RoundWon{winner,amount}],round_start(g))
    case True{}:
      Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
      (set_done(g,True{}),[RoundWon{winner,amount},MatchWon{Bool.pick(Side,U32.is_gt(cash_a,cash_b),A{},B{})}])
def round_finish(+g: Game, +winner: Side) -> Game & List<&2, GameEvent>:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  +is_a : Bool = side_eq(winner,A{})
  +amount : U32 = prize(round)
  g1 : Game = Game{a,b,other(winner),max_hp,shells,deck,seed,counter,False{},1n+round,(wins_a + Bool.to_u32(is_a) : U32),(wins_b + Bool.to_u32(Bool.not(is_a)) : U32),(cash_a + Bool.pick(U32,is_a,amount,0) : U32),(cash_b + Bool.pick(U32,is_a,0,amount) : U32),False{}}
  round_finish.last(Nat.is_eq(round,3n),g1,winner,amount)
def after_shot.players(a: PlayerState, b: PlayerState, g: Game) -> Game & List<&2, GameEvent>:
  match a b:
    case Player{0n,ai,aj,ac} _:
      round_finish(g,B{})
    case _ Player{0n,bi,bj,bc}:
      round_finish(g,A{})
    case _ _:
      flow_turn(reload_if_empty(g))
def after_shot(+g: Game) -> Game & List<&2, GameEvent>:
  after_shot.players(player(g,A{}),player(g,B{}),g)
def target_self(target: Target) -> Bool:
  match target:
    case Self{}:
      True{}
    case Opp{}:
      False{}
def shot.shells(shells: List<&2, Shell>, +g: Game, +target: Target) -> Game & List<&2, GameEvent>:
  match shells:
    case Nil{}:
      reload(g)
    case +shell <> tail:
      Game{a,b,turn,max_hp,seq,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
      +damage : Nat = Bool.pick(Nat,sawed,2n,1n)
      +victim : Side = Bool.pick(Side,target_self(target),turn,other(turn))
      g1 : Game = put_player(g,victim,hurt(player(g,victim),Bool.pick(Nat,shell_eq(shell,Live{}),damage,0n)))
      +next : Side = Bool.pick(Side,Bool.and(target_self(target),shell_eq(shell,Blank{})),turn,other(turn))
      g2 : Game = set_turn(set_sawed(set_shells(g1,tail),False{}),next)
      prepend_events([Fired{turn,target,shell,damage}],after_shot(g2))

def beer.shells(shells: List<&2, Shell>, +g: Game) -> Game & List<&2, GameEvent>:
  match shells:
    case Nil{}:
      reload(g)
    case shell <> tail:
      prepend_events([Ejected{current(g),shell}],reload_if_empty(set_shells(g,tail)))
def phone.result(pair: Game & U32) -> Game & List<&2, GameEvent>:
  (+g,r) = pair
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  +index : Nat = 1n+U32.to_nat(r)
  (g,[Reveal{turn,index,get_shell(shells,index)}])
def use_effect(item: Item, +g: Game) -> Game & List<&2, GameEvent>:
  match item:
    case Saw{}:
      (set_sawed(g,True{}),Nil{})
    case Glass{}:
      Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
      (g,[Reveal{turn,0n,get_shell(shells,0n)}])
    case Jammer{}:
      +opp : Side = other(current(g))
      (put_player(g,opp,jam(player(g,opp))),Nil{})
    case Cigs{}:
      Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
      (put_player(g,turn,heal(player(g,turn),max_hp)),Nil{})
    case Beer{}:
      Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
      beer.shells(shells,g)
    case Phone{}:
      Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
      phone.result(random(g,U32.from_nat(Nat.sub(List.length(&2,Shell,shells),1n))))
    case Adrenaline{}:
      (g,Nil{})
    case Inverter{}:
      Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
      +new : Shell = Bool.pick(Shell,shell_eq(get_shell(shells,0n),Live{}),Blank{},Live{})
      (set_shells(g,new <> List.tail(&2,Shell,shells)),[Inverted{turn,new}])
def item_usable(item: Item, +g: Game) -> Bool:
  match item:
    case Phone{}:
      Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
      Nat.is_gt(List.length(&2,Shell,shells),2n)
    case Adrenaline{}:
      False{}
    case _:
      True{}
def player_has(p: PlayerState, item: Item) -> Bool:
  Player{hp,items,jammed,checked} = p
  has_item(items,item)
def use_checked(valid: Bool, +g: Game, +item: Item, +stolen: Bool) -> Game & List<&2, GameEvent>:
  match valid:
    case False{}:
      (g,Nil{})
    case True{}:
      +side : Side = current(g)
      +source : Side = Bool.pick(Side,stolen,other(side),side)
      +g1 : Game = put_player(g,source,remove_from(player(g,source),item))
      g2 : Game = Bool.pick(Game,stolen,put_player(g1,side,remove_from(player(g1,side),Adrenaline{})),g1)
      prepend_events([Used{side,item,stolen}],use_effect(item,g2))
def action_step(action: Action, +g: Game) -> Game & List<&2, GameEvent>:
  match action:
    case Use{+item}:
      use_checked(Bool.and(player_has(player(g,current(g)),item),item_usable(item,g)),g,item,False{})
    case Steal{+item}:
      use_checked(Bool.and(player_has(player(g,current(g)),Adrenaline{}),Bool.and(player_has(player(g,other(current(g))),item),item_usable(item,g))),g,item,True{})
    case Shoot{target}:
      Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
      shot.shells(shells,g,target)
def step.player(p: PlayerState, +g: Game, action: Action) -> Game & List<&2, GameEvent>:
  match p:
    case Player{hp,items,False{},checked}:
      action_step(action,g)
    case Player{hp,items,True{},False{}}:
      begin_turn(4n,turn_status(g))
    case Player{hp,items,True{},True{}}:
      action_step(action,put_player(g,current(g),Player{hp,items,False{},True{}}))
def step.done(done: Bool, +g: Game, action: Action) -> Game & List<&2, GameEvent>:
  match done:
    case True{}:
      (g,Nil{})
    case False{}:
      step.player(player(g,current(g)),g,action)
def step(+g: Game, action: Action) -> Game & List<&2, GameEvent>:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  step.done(done,g,action)
def ended(g: Game) -> Bool:
  Game{a,b,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,done} = g
  done
