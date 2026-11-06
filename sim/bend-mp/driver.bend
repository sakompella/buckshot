import Base
import ./domain.bend as D
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./ai/story.bend as Story
import ./ai/don.bend as Don

# The controller of a match. It makes no game decisions: it answers the
# machine's random draws from a counter-hashed game stream, asks the seat that
# acts for a decision (one grab per seat in turn when several can), lifts the AI's
# index to a tape answer with prompt.answer, applies it with the machine's
# answer, and routes the notes to each seat with hear. Every AI has its own
# random stream, a counter hashed with the match seed and its socket.

# Controllers
# ===========

type Brain is Data:
  StoryBrain{}
  DoNBrain{}

type Mind is Data:
  StoryMind{mem: Story.Mem}
  DonMind{mem: Don.Mem}

def mind.of(brain: Brain) -> Mind:
  match brain:
    case StoryBrain{}:
      StoryMind{Story.fresh()}
    case DoNBrain{}:
      DonMind{Don.fresh()}

def minds.of(brains: D.Ring<&2, Brain>) -> D.Ring<&2, Mind>:
  match brains:
    case D.Duo{a, b}:
      D.Duo{mind.of(a), mind.of(b)}
    case D.Trio{a, b, c}:
      D.Trio{mind.of(a), mind.of(b), mind.of(c)}
    case D.Quad{a, b, c, d}:
      D.Quad{mind.of(a), mind.of(b), mind.of(c), mind.of(d)}

def think.story(decision: D.Decision<&2, Story.Mem>) -> D.Decision<&2, Mind>:
  match decision:
    case D.Decision{pick, memory}:
      D.Decision{pick, StoryMind{memory}}

def think.don(decision: D.Decision<&2, Don.Mem>) -> D.Decision<&2, Mind>:
  match decision:
    case D.Decision{pick, memory}:
      D.Decision{pick, DonMind{memory}}

def think(mind: Mind, prompt: D.Prompt, obs: D.Obs, heard: List<&2, D.Heard>, coin: U32) -> D.Decision<&2, Mind>:
  match mind:
    case StoryMind{mem}:
      think.story(Story.decide(prompt, obs, heard, mem, coin))
    case DonMind{mem}:
      think.don(Don.decide(prompt, obs, heard, mem, coin))

# Hearing eagerly is the same as passing the backlog to think: every decide
# starts by updating its memory with the heard notes. The web UI uses this.
def hear.mind(mind: Mind, heard: List<&2, D.Heard>, +seat: D.Seat) -> Mind:
  match mind:
    case StoryMind{mem}:
      StoryMind{Story.update(heard, seat, mem)}
    case DonMind{mem}:
      DonMind{Don.update(heard, seat, mem)}

# Randomness
# ==========

def mix(+x: U32) -> U32:
  +x1 : U32 = U32.xor(x, U32.shrn(x, 16n))
  +x2 : U32 = U32.mul(x1, 2146121005)
  +x3 : U32 = U32.xor(x2, U32.shrn(x2, 15n))
  +x4 : U32 = U32.mul(x3, 2221713035)
  U32.xor(x4, U32.shrn(x4, 16n))

def seat.code(seat: D.Seat) -> U32:
  match seat:
    case D.Seat0{}:
      0
    case D.Seat1{}:
      1
    case D.Seat2{}:
      2
    case D.Seat3{}:
      3

def or.default(-A: Data, found: Maybe<&2, A>, +fallback: A) -> A:
  match found:
    case Some{x}:
      x
    case None{}:
      fallback

# seats: how many words each seat's AI has drawn so far.
type Rng is Data:
  Rng{seed: U32, game: U32, seats: D.Ring<&2, U32>}

# The next game word: it answers a machine draw.
def rng.draw(rng: Rng) -> Rng & U32:
  match rng:
    case Rng{+seed, +game, seats}:
      (Rng{seed, (game + 1 : U32), seats}, mix(U32.xor(seed, mix(game))))

# Word number count of one seat's own stream, for the mixed match seed.
def coin.word(+seed: U32, +seat: D.Seat, +count: U32) -> U32:
  mix(U32.xor(mix(U32.xor(seed, U32.mul(2654435769, (1 + seat.code(seat) : U32)))), mix(count)))

# The next word of one seat's own stream.
def rng.coin(rng: Rng, +seat: D.Seat) -> Rng & U32:
  match rng:
    case Rng{+seed, game, +seats}:
      +count : U32 = or.default(U32, D.ring.get(U32, seats, seat), 0)
      (Rng{seed, game, D.ring.set(U32, seats, seat, (count + 1 : U32))}, coin.word(seed, seat, count))

# The tape answer for a draw: one of its range's values, as a Nat.
def draw.answer(range: D.Range, word: U32) -> Nat:
  match range:
    case D.Range{lo, extra}:
      U32.to_nat(U32.mod(word, U32.from_nat(2n+extra)))

# Matches
# =======

# Every item off. config(table, True) is the default customization.
def config.no_items() -> D.ItemRules:
  +off : D.ItemRule = D.ItemRule{False{}, 0n, 0n}
  D.ItemRules{off, off, off, off, off, off, off, off, off}

def config(table: D.Table, items: Bool) -> D.Config:
  match items:
    case True{}:
      D.config.default(table)
    case False{}:
      +load : D.LoadRule = D.LoadRule{D.RandomShells{}, D.RandomAmount{}}
      +round : D.RoundRules = D.RoundRules{D.RandomHealth{}, D.LoadRules{load, load, load, load}, config.no_items(), D.Boxed{}}
      D.Config{table, D.ThreeRounds{round, round, round}}

type Run is Data:
  Run{state: S.State, minds: D.Ring<&2, Mind>, heard: D.Ring<&2, List<&2, D.Heard>>, rng: Rng, rounds: D.Ring<&2, U32>, cash: D.Ring<&2, U32>, verbose: Bool, trace: List<&2, D.Note>}

type Outcome is Data:
  Concluded{}
  Wedged{}
  OutOfFuel{}

type Played is Data:
  Played{run: Run, outcome: Outcome}

type Score is Data:
  Score{rounds: D.Ring<&2, U32>, cash: D.Ring<&2, U32>}

def bump(+ring: D.Ring<&2, U32>, +seat: D.Seat, amount: U32) -> D.Ring<&2, U32>:
  D.ring.set(U32, ring, seat, U32.add(or.default(U32, D.ring.get(U32, ring, seat), 0), amount))

def score(notes: List<&2, D.Note>, +rounds: D.Ring<&2, U32>, +cash: D.Ring<&2, U32>) -> Score:
  match notes:
    case Nil{}:
      Score{rounds, cash}
    case D.Shown{D.RoundWon{+seat, prize}} <> rest:
      score(rest, bump(rounds, seat, 1), bump(cash, seat, prize))
    case note <> rest:
      score(rest, rounds, cash)

def heard.add(+notes: List<&2, D.Note>, heard: D.Ring<&2, List<&2, D.Heard>>) -> D.Ring<&2, List<&2, D.Heard>>:
  match heard:
    case D.Duo{a, b}:
      D.Duo{List.append(&2, D.Heard, a, D.hear(notes, D.Seat1{})), List.append(&2, D.Heard, b, D.hear(notes, D.Seat3{}))}
    case D.Trio{a, b, c}:
      D.Trio{List.append(&2, D.Heard, a, D.hear(notes, D.Seat0{})), List.append(&2, D.Heard, b, D.hear(notes, D.Seat1{})), List.append(&2, D.Heard, c, D.hear(notes, D.Seat2{}))}
    case D.Quad{a, b, c, d}:
      D.Quad{List.append(&2, D.Heard, a, D.hear(notes, D.Seat0{})), List.append(&2, D.Heard, b, D.hear(notes, D.Seat1{})), List.append(&2, D.Heard, c, D.hear(notes, D.Seat2{})), List.append(&2, D.Heard, d, D.hear(notes, D.Seat3{}))}

def trace.add(verbose: Bool, trace: List<&2, D.Note>, notes: List<&2, D.Note>) -> List<&2, D.Note>:
  match verbose:
    case True{}:
      List.append(&2, D.Note, trace, notes)
    case False{}:
      trace

def step.scored(scored: Score, state: S.State, minds: D.Ring<&2, Mind>, heard: D.Ring<&2, List<&2, D.Heard>>, rng: Rng, verbose: Bool, trace: List<&2, D.Note>) -> Run:
  match scored:
    case Score{rounds, cash}:
      Run{state, minds, heard, rng, rounds, cash, verbose, trace}

# Take the machine's output: route the notes, count round wins and cash.
def step.stepped(stepped: D.Stepped<&2, S.State>, minds: D.Ring<&2, Mind>, heard: D.Ring<&2, List<&2, D.Heard>>, rng: Rng, rounds: D.Ring<&2, U32>, cash: D.Ring<&2, U32>, +verbose: Bool, trace: List<&2, D.Note>) -> Run:
  match stepped:
    case D.Stepped{state, +notes}:
      step.scored(score(notes, rounds, cash), state, minds, heard.add(notes, heard), rng, verbose, trace.add(verbose, trace, notes))

def step.drew(drawn: Rng & U32, range: D.Range, +state: S.State, minds: D.Ring<&2, Mind>, heard: D.Ring<&2, List<&2, D.Heard>>, rounds: D.Ring<&2, U32>, cash: D.Ring<&2, U32>, verbose: Bool, trace: List<&2, D.Note>) -> Run:
  (rng, word) = drawn
  step.stepped(M.answer(state, draw.answer(range, word)), minds, heard, rng, rounds, cash, verbose, trace)

def step.draw(range: D.Range, run: Run) -> Run:
  match run:
    case Run{state, minds, heard, rng, rounds, cash, verbose, trace}:
      step.drew(rng.draw(rng), range, state, minds, heard, rounds, cash, verbose, trace)

def prompt.seat(prompt: D.Prompt) -> D.Seat:
  match prompt:
    case D.Prompt{seat, first, menu}:
      seat

# One decision applied: the AI's index becomes a tape answer, and the machine
# answers it.
def step.applied(decision: D.Decision<&2, Mind>, prompt: D.Prompt, +seat: D.Seat, run: Run) -> Run:
  match decision run:
    case D.Decision{pick, mind} Run{state, minds, heard, rng, rounds, cash, verbose, trace}:
      step.stepped(M.answer(state, D.prompt.answer(prompt, pick)), D.ring.set(Mind, minds, seat, mind), heard, rng, rounds, cash, verbose, trace)

def step.asked(asked: Rng & U32, +prompt: D.Prompt, +seat: D.Seat, +state: S.State, mind: Mind, backlog: List<&2, D.Heard>, minds: D.Ring<&2, Mind>, heard: D.Ring<&2, List<&2, D.Heard>>, rounds: D.Ring<&2, U32>, cash: D.Ring<&2, U32>, verbose: Bool, trace: List<&2, D.Note>) -> Run:
  (rng, coin) = asked
  step.applied(think(mind, prompt, D.observe(M.point(state), seat), backlog, coin), prompt, seat, Run{state, minds, D.ring.set(List<&2, D.Heard>, heard, seat, Nil{}), rng, rounds, cash, verbose, trace})

def step.prompt(+prompt: D.Prompt, run: Run) -> Run:
  match run:
    case Run{state, minds, +heard, rng, rounds, cash, verbose, trace}:
      +seat : D.Seat = prompt.seat(prompt)
      +minds : D.Ring<&2, Mind> = minds
      step.asked(rng.coin(rng, seat), prompt, seat, state, or.default(Mind, D.ring.get(Mind, minds, seat), StoryMind{Story.fresh()}), or.default(List<&2, D.Heard>, D.ring.get(List<&2, D.Heard>, heard, seat), Nil{}), minds, heard, rounds, cash, verbose, trace)

def run.state(run: Run) -> S.State:
  match run:
    case Run{state, _, _, _, _, _, _, _}:
      state

def seat.rank(seat: D.Seat) -> Nat:
  match seat:
    case D.Seat0{}:
      0n
    case D.Seat1{}:
      1n
    case D.Seat2{}:
      2n
    case D.Seat3{}:
      3n

def prompt.holds(prompt: D.Prompt) -> Bool:
  match prompt:
    case D.Prompt{_, _, D.NonEmpty{D.Place{_}, _}}:
      True{}
    case _:
      False{}

def prompt.granted(+grabs: S.Grabs, prompt: D.Prompt) -> Nat:
  or.default(Nat, D.ring.get(Nat, S.grabs.granted(grabs), prompt.seat(prompt)), 0n)

# The prompts of the seats after `first` in socket order, then the rest.
def prompts.after(prompts: List<&2, D.Prompt>, +first: D.Seat, +before: List<&2, D.Prompt>) -> List<&2, D.Prompt>:
  match prompts:
    case Nil{}:
      before
    case +prompt <> +rest:
      Bool.pick(List<&2, D.Prompt>, Nat.is_lt(seat.rank(first), seat.rank(prompt.seat(prompt))), List.append(&2, D.Prompt, prompt <> rest, before), prompts.after(rest, first, List.append(&2, D.Prompt, before, [prompt])))

def prompt.better.holding(+grabs: S.Grabs, +best: D.Prompt, +next: D.Prompt, best_holds: Bool, next_holds: Bool) -> D.Prompt:
  match best_holds next_holds:
    case True{} _:
      best
    case False{} True{}:
      next
    case False{} False{}:
      Bool.pick(D.Prompt, Nat.is_lt(prompt.granted(grabs, next), prompt.granted(grabs, best)), next, best)

def prompt.better(+grabs: S.Grabs, +best: D.Prompt, +next: D.Prompt) -> D.Prompt:
  prompt.better.holding(grabs, best, next, prompt.holds(best), prompt.holds(next))

def prompt.best(prompts: List<&2, D.Prompt>, +grabs: S.Grabs, +best: D.Prompt) -> D.Prompt:
  match prompts:
    case Nil{}:
      best
    case next <> rest:
      prompt.best(rest, grabs, prompt.better(grabs, best, next))

# Several seats can grab at once while items are handed out. A seat holding an
# item places it; otherwise the seat with the fewest grants this distribution
# grabs, ties going to the first seat after the first shooter in socket order.
# That is one grab per seat in turn, the simple machine's order (ADR-0033).
def prompt.first(+grabs: S.Grabs, ordered: List<&2, D.Prompt>) -> Maybe<&2, D.Prompt>:
  match ordered:
    case Nil{}:
      None{}
    case head <> rest:
      Some{prompt.best(rest, grabs, head)}

def prompt.next(+state: S.State, prompts: List<&2, D.Prompt>) -> Maybe<&2, D.Prompt>:
  prompt.first(S.state.grabs(state), prompts.after(prompts, S.world.first_turn(S.state.world(state)), Nil{}))

def step.chosen(next: Maybe<&2, D.Prompt>, run: Run) -> Run:
  match next:
    case None{}:
      run
    case Some{prompt}:
      step.prompt(prompt, run)

def step.choose(prompts: List<&2, D.Prompt>, +run: Run) -> Run:
  step.chosen(prompt.next(run.state(run), prompts), run)

def run.request(run: Run) -> D.Request:
  match run:
    case Run{state, minds, heard, rng, rounds, cash, verbose, trace}:
      M.request(state)

# Play until the machine concludes or is stuck, or the fuel (one per answer) is
# spent.
def play(fuel: Nat, request: D.Request, +run: Run) -> Played:
  match fuel request:
    case _ D.Finished{}:
      Played{run, Concluded{}}
    case _ D.Stuck{}:
      Played{run, Wedged{}}
    case 0n _:
      Played{run, OutOfFuel{}}
    case 1n+rest D.Draw{label, range}:
      +next : Run = step.draw(range, run)
      play(rest, run.request(next), next)
    case 1n+rest D.Choose{menus}:
      +next : Run = step.choose(D.prompts(D.Choose{menus}), run)
      play(rest, run.request(next), next)

def start.run(stepped: D.Stepped<&2, S.State>, +brains: D.Ring<&2, Brain>, +seed: U32, verbose: Bool) -> Run:
  +table : D.Table = D.ring.table(Brain, brains)
  step.stepped(stepped, minds.of(brains), D.ring.fill(List<&2, D.Heard>, table, Nil{}), Rng{mix(seed), 0, D.ring.fill(U32, table, 0)}, D.ring.fill(U32, table, 0), D.ring.fill(U32, table, 0), verbose, Nil{})

def match_start(stepped: D.Stepped<&2, S.State>, fuel: Nat, brains: D.Ring<&2, Brain>, seed: U32, verbose: Bool) -> Played:
  +run : Run = start.run(stepped, brains, seed, verbose)
  play(fuel, run.request(run), run)

def run_match(fuel: Nat, +table: D.Table, items: Bool, brains: D.Ring<&2, Brain>, seed: U32, verbose: Bool) -> Played:
  match_start(M.start(config(table, items)), fuel, brains, seed, verbose)

# Batches
# =======

type Totals is Data:
  Totals{played: U32, matches: D.Ring<&2, U32>, rounds: D.Ring<&2, U32>, stuck: U32, exhausted: U32}

def ring.add(a: D.Ring<&2, U32>, b: D.Ring<&2, U32>) -> D.Ring<&2, U32>:
  match a b:
    case D.Duo{a1, a2} D.Duo{b1, b2}:
      D.Duo{(a1 + b1 : U32), (a2 + b2 : U32)}
    case D.Trio{a1, a2, a3} D.Trio{b1, b2, b3}:
      D.Trio{(a1 + b1 : U32), (a2 + b2 : U32), (a3 + b3 : U32)}
    case D.Quad{a1, a2, a3, a4} D.Quad{b1, b2, b3, b4}:
      D.Quad{(a1 + b1 : U32), (a2 + b2 : U32), (a3 + b3 : U32), (a4 + b4 : U32)}
    case a _:
      a

def totals.add(a: Totals, b: Totals) -> Totals:
  match a b:
    case Totals{ap, am, ar, as, ae} Totals{bp, bm, br, bs, be}:
      Totals{(ap + bp : U32), ring.add(am, bm), ring.add(ar, br), (as + bs : U32), (ae + be : U32)}

# The seat holding the most cash; the lowest socket keeps a tie.
def champion(entries: List<&2, D.At<&2, U32>>, +best: D.Seat, +top: U32) -> D.Seat:
  match entries:
    case Nil{}:
      best
    case D.At{+seat, +cash} <> rest:
      champion(rest, Bool.pick(D.Seat, U32.is_gt(cash, top), seat, best), Bool.pick(U32, U32.is_gt(cash, top), cash, top))

def champion.of(entries: List<&2, D.At<&2, U32>>) -> D.Seat:
  match entries:
    case Nil{}:
      D.Seat0{}
    case D.At{seat, cash} <> rest:
      champion(rest, seat, cash)

def won(outcome: Outcome, +cash: D.Ring<&2, U32>) -> D.Ring<&2, U32>:
  match outcome:
    case Concluded{}:
      D.ring.set(U32, D.ring.fill(U32, D.ring.table(U32, cash), 0), champion.of(D.ring.entries(U32, cash)), 1)
    case _:
      D.ring.fill(U32, D.ring.table(U32, cash), 0)

def outcome.wedged(outcome: Outcome) -> Bool:
  match outcome:
    case Wedged{}:
      True{}
    case _:
      False{}

def outcome.spent(outcome: Outcome) -> Bool:
  match outcome:
    case OutOfFuel{}:
      True{}
    case _:
      False{}

def totals.outcome(+outcome: Outcome, rounds: D.Ring<&2, U32>, +cash: D.Ring<&2, U32>) -> Totals:
  Totals{1, won(outcome, cash), rounds, Bool.to_u32(outcome.wedged(outcome)), Bool.to_u32(outcome.spent(outcome))}

def totals.of(played: Played) -> Totals:
  match played:
    case Played{Run{state, minds, heard, rng, +rounds, +cash, verbose, trace}, outcome}:
      totals.outcome(outcome, rounds, cash)

def match.seed(+id: U32, +salt: U32) -> U32:
  mix(U32.xor(id, salt))

# 2^depth independent matches as a fork tree, summed.
def batch(depth: Nat, +fuel: Nat, +table: D.Table, +items: Bool, +brains: D.Ring<&2, Brain>, +id: U32, +salt: U32) -> Totals:
  match depth:
    case 0n:
      totals.of(run_match(fuel, table, items, brains, match.seed(id, salt), False{}))
    case 1n++p:
      +left : U32 = U32.shln(id, 1n)
      l r = batch(p, fuel, table, items, brains, left, salt) batch(p, fuel, table, items, brains, (left + 1 : U32), salt)
      totals.add(l, r)

def verbose_match(fuel: Nat, table: D.Table, items: Bool, brains: D.Ring<&2, Brain>, seed: U32) -> Played:
  run_match(fuel, table, items, brains, seed, True{})
