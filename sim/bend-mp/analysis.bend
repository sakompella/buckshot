import Base
import ./domain.bend as D
import ./player/main.bend as P
import ./player/types.bend as A
import ./player/belief.bend as B

# The minimax player's exports for the arena's analysis scripts
# (web/src/analysis/player.ts is the only caller). Rooted here beside web.bend,
# domain values carry the rules build's "domain." tags, so a board or config
# from that build passes in unchanged.

def analyse(position: A.Position, depth: Nat, budget: Nat, reload: A.Reload, memo: A.Memo) -> A.Analysis:
  P.analyse(position, depth, budget, reload, memo)

# Every shell order a log allows, with multiplicity: from the public events
# alone, or with the player's own clues too.
def orders(log: List<&2, D.Heard>, private: Bool) -> List<&2, List<&2, D.Shell>>:
  B.orders.log(log, private, Nil{})
