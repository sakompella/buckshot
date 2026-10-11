import Base
import ./model.bend as M
import ./controller.bend as C
import ./view.bend as V

type RunState is Data:
  RunState{game: M.Game, mem_a: C.Mem, mem_b: C.Mem, trace: String}
type Counts is Data:
  Counts{match_a: U32, round_a: U32, exhausted: U32}
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
def trace_step(verbose: Bool, trace: String, +g: M.Game, events: List<&2, M.GameEvent>) -> String:
  match verbose:
    case False{}:
      trace
    case True{}:
      trace ++ V.render_table(M.observe(g,M.current(g))) ++ "\n" ++ V.render_events(events)
def tick.events(pair: M.Game & List<&2, M.GameEvent>, st: RunState, +a: C.Policy, +b: C.Policy, verbose: Bool) -> RunState:
  (g,+events) = pair
  RunState{old,ma,mb,trace} = st
  RunState{g,C.update(a,M.A{},ma,events),C.update(b,M.B{},mb,events),trace_step(verbose,trace,old,events)}
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
      RunState{g,ma,mb,trace ++ V.render_event(M.Exhausted{}) ++ "\n"}
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
def initial.trace(verbose: Bool, events: List<&2, M.GameEvent>) -> String:
  match verbose:
    case True{}:
      V.render_events(events)
    case False{}:
      ""
def initial(pair: M.Game & List<&2, M.GameEvent>, +a: C.Policy, +b: C.Policy, verbose: Bool) -> RunState:
  (g,+events) = pair
  RunState{g,C.update(a,M.A{},C.fresh(),events),C.update(b,M.B{},C.fresh(),events),initial.trace(verbose,events)}
def match_run(seed: U32, +a: C.Policy, +b: C.Policy, +verbose: Bool) -> RunState:
  play(4096n,initial(M.start(seed),a,b,verbose),a,b,verbose)
def counts(st: RunState) -> Counts:
  RunState{g,ma,mb,trace} = st
  M.Game{pa,pb,turn,max_hp,shells,deck,seed,counter,sawed,round,wins_a,wins_b,+cash_a,+cash_b,done} = g
  Counts{Bool.to_u32(U32.is_gt(cash_a,cash_b)),wins_a,Bool.to_u32(Bool.not(done))}
def add_counts(a: Counts, b: Counts) -> Counts:
  Counts{am,ar,ae} = a
  Counts{bm,br,be} = b
  Counts{(am + bm : U32),(ar + br : U32),(ae + be : U32)}
def batch(depth: Nat, +a: C.Policy, +b: C.Policy, +id: U32, +salt: U32) -> Counts:
  match depth:
    case 0n:
      counts(match_run(M.mix(U32.xor(id,salt)),a,b,False{}))
    case 1n++p:
      +left: U32 = U32.shln(id,1n)
      l r = batch(p,a,b,left,salt) batch(p,a,b,(left + 1 : U32),salt)
      add_counts(l,r)
def hundredths.small(small: Bool, n: U32) -> String:
  match small:
    case True{}:
      "0" ++ U32.show(n)
    case False{}:
      U32.show(n)
def hundredths(+n: U32) -> String:
  hundredths.small(U32.is_lt(n,10),n)
def percent(+wins: U32, +total: U32) -> String:
  +basis: U32 = U32.div(U32.mul(wins,10000),total)
  U32.show(U32.div(basis,100)) ++ "." ++ hundredths(U32.mod(basis,100)) ++ "%"
def show_counts(label: String, c: Counts) -> String:
  Counts{+matches,+rounds,exhausted} = c
  label ++ "  match A " ++ percent(matches,16384) ++ " (" ++ U32.show(matches) ++ "/16384)  round A " ++ percent(rounds,49152) ++ " (" ++ U32.show(rounds) ++ "/49152)  exhausted " ++ U32.show(exhausted)
def show_match(st: RunState) -> String:
  RunState{g,ma,mb,trace} = st
  trace ++ V.render_summary(g)
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Verbose match. A = DoN, B = story. Seed 20261011.")
    IO.print(show_match(match_run(20261011,C.DoN{},C.Story{},True{})))
    IO.print("Independent matches per matchup = 16384. Three rounds per match.")
    IO.print(show_counts("story vs story",batch(14n,C.Story{},C.Story{},1,100)))
    IO.print(show_counts("DoN vs DoN",batch(14n,C.DoN{},C.DoN{},1,200)))
    IO.print(show_counts("DoN vs story",batch(14n,C.DoN{},C.Story{},1,300)))
