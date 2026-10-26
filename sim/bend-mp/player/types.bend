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

type Line is Data:
  Line{index: Nat, move: T.Move, score: U32, pv: List<&2, T.Move>}

type Analysis is Data:
  Analysed{lines: List<&2, Line>, best: Nat, score: U32, nodes: Nat, depth: Nat, limited: Bool}
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
    case Line{_, _, score, _}:
      score

def line.index(line: Line) -> Nat:
  match line:
    case Line{index, _, _, _}:
      index

def line.move(line: Line) -> T.Move:
  match line:
    case Line{_, move, _, _}:
      move

def line.pv(line: Line) -> List<&2, T.Move>:
  match line:
    case Line{_, _, _, pv}:
      pv
