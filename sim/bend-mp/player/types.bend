import Base
import ../domain.bend as D
import ../simple/state.bend as T

type Position is Data:
  Position{config: D.Config, board: D.Board, log: List<&2, D.Heard>, me: D.Seat}

type Level is Data:
  Level{depth: Nat, budget: Nat, gap: U32, seed: U32}

# How a leaf at a reload is valued: by the static evaluation before the draw,
# by that evaluation's expectation over every distinct deal, or by its mean
# over `count` deals drawn at random (deal.bend).
type Reload is Data:
  Static{}
  ExpectedDeal{}
  Sampled{count: Nat}

# How the search reuses a node it has already finished (memo.bend). Off
# searches every node again. Charged reuses the value but spends the nodes the
# first search did, so it scores and counts exactly as Off. Free reuses it for
# no nodes, so the same budget reaches further.
type Memo is Data:
  Off{}
  Charged{}
  Free{}

# What the leaves below a value were: every one the end of the round
# (Settled), the end of the round or a reload (Reloads), or some ran out of
# depth (Cut). Only a Cut value can change with more depth.
type Reach is Data:
  Settled{}
  Reloads{}
  Cut{}

# The decision nodes and reload leaves the memo holds, and how often each was
# reused. All zero when the memo is off.
type Cached is Data:
  Cached{entries: Nat, hits: Nat, deals: Nat, deal_hits: Nat}

type Line is Data:
  Line{index: Nat, move: T.Move, score: U32, pv: List<&2, T.Move>, reach: Reach}

type Analysis is Data:
  Analysed{lines: List<&2, Line>, best: Nat, score: U32, nodes: Nat, depth: Nat, limited: Bool, cached: Cached}
  Invalid{reason: String, nodes: Nat}

type Pick is Data:
  Picked{index: Nat, move: T.Move, analysis: Analysis}
  Unavailable{analysis: Analysis}

type World is Data:
  World{state: T.State, weight: F32}

type Belief is Data:
  Belief{public: List<&2, World>, private: List<&2, World>, me: D.Seat, round: Nat}

def line.score(line: Line) -> U32:
  match line:
    case Line{_, _, score, _, _}:
      score

def line.index(line: Line) -> Nat:
  match line:
    case Line{index, _, _, _, _}:
      index

def line.move(line: Line) -> T.Move:
  match line:
    case Line{_, move, _, _, _}:
      move

def line.pv(line: Line) -> List<&2, T.Move>:
  match line:
    case Line{_, _, _, pv, _}:
      pv
