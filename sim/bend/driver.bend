import Base
import ./model.bend as M
import ./controller.bend as C

type Entry is Data:
  Opened{events: List<&2, M.GameEvent>}
  Acted{obs: M.Obs, events: List<&2, M.GameEvent>}
  RanOut{}
type RunState is Data:
  RunState{game: M.Game, mem_a: C.Mem, mem_b: C.Mem, trace: List<&2, Entry>}
type Played is Data:
  Played{game: M.Game, trace: List<&2, Entry>}
type Counts is Data:
  Counts{played: U32, match_a: U32, round_a: U32, exhausted: U32}
def policy(side: M.Side, a: C.Policy, b: C.Policy) -> C.Policy:
  match side:
    case M.A{}:
      a
    case M.B{}:
      b
def memory(side: M.Side, a: C.Mem, b: C.Mem) -> C.Mem:
  match side:
    case M.A{}:
      a
    case M.B{}:
      b
def record_act(verbose: Bool, trace: List<&2, Entry>, +g: M.Game, events: List<&2, M.GameEvent>) -> List<&2, Entry>:
  match verbose:
    case False{}:
      trace
    case True{}:
      Acted{M.observe(g,M.current(g)),events} <> trace
def tick.events(pair: M.Game & List<&2, M.GameEvent>, st: RunState, +a: C.Policy, +b: C.Policy, verbose: Bool) -> RunState:
  (g,+events) = pair
  RunState{old,ma,mb,trace} = st
  RunState{g,C.update(a,M.A{},ma,events),C.update(b,M.B{},mb,events),record_act(verbose,trace,old,events)}
def tick.decision(pair: M.Action & C.Mem, st: RunState, +a: C.Policy, +b: C.Policy, verbose: Bool) -> RunState:
  (action,+mem) = pair
  RunState{+g,ma,mb,trace} = st
  +side: M.Side = M.current(g)
  st1: RunState = RunState{g,memory(side,mem,ma),memory(side,mb,mem),trace}
  tick.events(M.step(g,action),st1,a,b,verbose)
def tick.coin(pair: M.Game & Bool, st: RunState, +a: C.Policy, +b: C.Policy, verbose: Bool) -> RunState:
  (+g,coin) = pair
  RunState{old,+ma,+mb,trace} = st
  +side: M.Side = M.current(g)
  tick.decision(C.decide(policy(side,a,b),M.observe(g,side),memory(side,ma,mb),coin),RunState{g,ma,mb,trace},a,b,verbose)
def tick(+st: RunState, a: C.Policy, b: C.Policy, verbose: Bool) -> RunState:
  RunState{g,ma,mb,trace} = st
  tick.coin(M.coin(g),st,a,b,verbose)
def exhausted(verbose: Bool, st: RunState) -> RunState:
  match verbose:
    case False{}:
      st
    case True{}:
      RunState{g,ma,mb,trace} = st
      RunState{g,ma,mb,RanOut{} <> trace}
def play(fuel: Nat, +st: RunState, +a: C.Policy, +b: C.Policy, +verbose: Bool) -> RunState:
  match fuel:
    case 0n:
      exhausted(verbose,st)
    case 1n+f:
      match st:
        case RunState{M.Game{pa,pb,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,True{}},ma,mb,trace}:
          st
        case RunState{M.Game{pa,pb,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,cash_a,cash_b,False{}},ma,mb,trace}:
          play(f,tick(st,a,b,verbose),a,b,verbose)
def initial.trace(verbose: Bool, events: List<&2, M.GameEvent>) -> List<&2, Entry>:
  match verbose:
    case True{}:
      [Opened{events}]
    case False{}:
      []
def initial(pair: M.Game & List<&2, M.GameEvent>, +a: C.Policy, +b: C.Policy, verbose: Bool) -> RunState:
  (g,+events) = pair
  RunState{g,C.update(a,M.A{},C.fresh(),events),C.update(b,M.B{},C.fresh(),events),initial.trace(verbose,events)}
def match_run(seed: U32, +a: C.Policy, +b: C.Policy, +verbose: Bool) -> RunState:
  play(4096n,initial(M.start(seed),a,b,verbose),a,b,verbose)
def played(st: RunState) -> Played:
  RunState{g,ma,mb,trace} = st
  Played{g,List.reverse(&2,Entry,trace)}
def verbose_match(seed: U32, +a: C.Policy, +b: C.Policy) -> Played:
  played(match_run(seed,a,b,True{}))
def counts(st: RunState) -> Counts:
  RunState{g,ma,mb,trace} = st
  M.Game{pa,pb,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,+cash_a,+cash_b,done} = g
  Counts{1,Bool.to_u32(U32.is_gt(cash_a,cash_b)),wins_a,Bool.to_u32(Bool.not(done))}
def add_counts(a: Counts, b: Counts) -> Counts:
  Counts{ap,am,ar,ae} = a
  Counts{bp,bm,br,be} = b
  Counts{(ap + bp : U32),(am + bm : U32),(ar + br : U32),(ae + be : U32)}
def batch(depth: Nat, +a: C.Policy, +b: C.Policy, +id: U32, +salt: U32) -> Counts:
  match depth:
    case 0n:
      counts(match_run(M.mix(U32.xor(id,salt)),a,b,False{}))
    case 1n++p:
      +left: U32 = U32.shln(id,1n)
      l r = batch(p,a,b,left,salt) batch(p,a,b,(left + 1 : U32),salt)
      add_counts(l,r)
