import Base
import ./types.bend as A
import ./search.bend as S
import ./policy.bend as P

# The player's export table (see README.md). Analysis and play share one search.

def analyse(position: A.Position, depth: Nat, budget: Nat, reload: A.Reload, memo: A.Memo) -> A.Analysis:
  S.analyse(position, depth, budget, reload, memo)

def choose(position: A.Position, level: A.Level) -> A.Pick:
  P.choose(position, level)

def regret(analysis: A.Analysis, index: Nat) -> Maybe<&2, U32>:
  P.regret(analysis, index)
