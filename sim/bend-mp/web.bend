import Base
import ./domain.bend as D
import ./sm/main.bend as M
import ./sm/state.bend as S

# The JS entry for the web UI (web/src/bend.ts is its only caller). Rooted
# here, these defs export under bare names; domain constructors carry the
# "domain." prefix. Each def is a thin, stable name over the machine so the UI
# never reaches into sm/ internals.
#
# Seam: when sim/bend-mp/ai/*.bend and driver.bend land, import them here and
# export the AI decision and the driver's seeded source next to these.

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
