import Base
import ./domain.bend as D
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./driver.bend as R
import ./ai/story.bend as Story
import ./ai/don.bend as Don

# The JS entry for the web UI (web/src/bend.ts is its only caller). Rooted
# here, these defs export under bare names; domain constructors carry the
# "domain." prefix. Each def is a thin, stable name over the machine so the UI
# never reaches into sm/ internals.
#
# The AI seats use the driver's own entry points (R.mind.of, R.think,
# R.coin.word), so the web and the driver cannot drift.

def items.off() -> D.ItemRules:
  +off : D.ItemRule = D.ItemRule{False{}, 0n, 0n}
  D.ItemRules{off, off, off, off, off, off, off, off, off}

def round.of(items: Bool) -> D.RoundRules:
  match items:
    case True{}:
      D.config.default_round()
    case False{}:
      +load : D.LoadRule = D.LoadRule{D.RandomShells{}, D.RandomAmount{}}
      D.RoundRules{D.RandomHealth{}, D.LoadRules{load, load, load, load}, items.off()}

# The default three-round match; with items False every item is disabled.
def config(table: D.Table, items: Bool) -> D.Config:
  +round : D.RoundRules = round.of(items)
  D.Config{table, D.ThreeRounds{round, round, round}}

def start(config: D.Config) -> D.Stepped<&2, S.State>:
  M.start(config)

def point(state: S.State) -> D.Point:
  M.point(state)

def answer(state: S.State, n: Nat) -> D.Stepped<&2, S.State>:
  M.answer(state, n)

# Every active seat's prompt at the state's current request point.
def prompts(state: S.State) -> List<&2, D.Prompt>:
  D.prompts(M.request(state))

def prompt.answer(prompt: D.Prompt, k: Nat) -> Nat:
  D.prompt.answer(prompt, k)

def hear(notes: List<&2, D.Note>, seat: D.Seat) -> List<&2, D.Heard>:
  D.hear(notes, seat)

def public_events(notes: List<&2, D.Note>) -> List<&2, D.GameEvent>:
  D.public_events(notes)

# AI seats
# ========

# A fresh AI memory (a Mind) for the story AI or for DoN.
def mind.story() -> R.Mind:
  R.StoryMind{Story.fresh()}

def mind.don() -> R.Mind:
  R.DonMind{Don.fresh()}

# The memory after the seat heard these notes.
def mind.hear(mind: R.Mind, notes: List<&2, D.Note>, +seat: D.Seat) -> R.Mind:
  R.hear.mind(mind, D.hear(notes, seat), seat)

# One decision for a prompt at a state: the driver's own think, with the seat's
# observation taken from the state and nothing left in the backlog.
def mind.decide(+state: S.State, +prompt: D.Prompt, mind: R.Mind, coin: U32) -> D.Decision<&2, R.Mind>:
  R.think(mind, prompt, D.observe(M.point(state), R.prompt.seat(prompt)), Nil{}, coin)

# Word number count of a seat's own random stream for a match seed.
def mind.coin(seed: U32, +seat: D.Seat, count: U32) -> U32:
  R.coin.word(R.mix(seed), seat, count)
