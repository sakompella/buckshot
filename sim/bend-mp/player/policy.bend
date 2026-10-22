import Base
import ./types.bend as A
import ./search.bend as S

# The difficulty knob (ADR-0043): depth and budget bound the search, and a
# seeded uniform pick among moves within `gap` of the best weakens play.

def mix(+x: U32) -> U32:
  +x1 : U32 = U32.xor(x, U32.shrn(x, 16n))
  +x2 : U32 = U32.mul(x1, 2146121005)
  +x3 : U32 = U32.xor(x2, U32.shrn(x2, 15n))
  +x4 : U32 = U32.mul(x3, 2221713035)
  U32.xor(x4, U32.shrn(x4, 16n))

def near.keep(kept: Bool, line: A.Line, rest: List<&2, A.Line>) -> List<&2, A.Line>:
  match kept:
    case True{}:
      line <> rest
    case False{}:
      rest

def near(lines: List<&2, A.Line>, +floor: U32) -> List<&2, A.Line>:
  match lines:
    case Nil{}:
      Nil{}
    case +line <> rest:
      near.keep(U32.is_ge(A.line.score(line), floor), line, near(rest, floor))

def picked(found: Maybe<&2, A.Line>, +analysis: A.Analysis) -> A.Pick:
  match found:
    case Some{+line}:
      A.Picked{A.line.index(line), A.line.move(line), analysis}
    case None{}:
      A.Unavailable{analysis}

def pick.near(+near: List<&2, A.Line>, +seed: U32, +analysis: A.Analysis) -> A.Pick:
  +k : U32 = U32.mod(mix(seed), U32.max(1, U32.from_nat(List.length(&2, A.Line, near))))
  picked(List.get(&2, A.Line, near, U32.to_nat(k)), analysis)

def pick(+analysis: A.Analysis, +gap: U32, +seed: U32) -> A.Pick:
  match analysis:
    case A.Analysed{lines, _, +score, _, _, _}:
      pick.near(near(lines, U32.sub(score, U32.min(gap, score))), seed, analysis)
    case A.Invalid{_, _}:
      A.Unavailable{analysis}

def choose(+position: A.Position, level: A.Level) -> A.Pick:
  match level:
    case A.Level{depth, budget, gap, seed}:
      pick(S.analyse(position, depth, budget), gap, seed)

def line.at(lines: List<&2, A.Line>, +index: Nat) -> Maybe<&2, A.Line>:
  match lines:
    case Nil{}:
      None{}
    case +line <> rest:
      Bool.pick(Maybe<&2, A.Line>, Nat.is_eq(A.line.index(line), index), Some{line}, line.at(rest, index))

def regret.of(found: Maybe<&2, A.Line>, +best: U32) -> Maybe<&2, U32>:
  match found:
    case Some{line}:
      Some{U32.sub(best, A.line.score(line))}
    case None{}:
      None{}

# Best score minus the chosen move's score; no score for an index that names
# no legal move, rather than clamping it to another one.
def regret(analysis: A.Analysis, +index: Nat) -> Maybe<&2, U32>:
  match analysis:
    case A.Analysed{lines, _, score, _, _, _}:
      regret.of(line.at(lines, index), score)
    case A.Invalid{_, _}:
      None{}
