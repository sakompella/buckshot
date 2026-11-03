import Base
import ../domain.bend as D
import ../driver.bend as R

# Smoke test for check.sh: 64 matches at each table size finish, with
# nothing stuck and no fuel spent. Items are on.

def items() -> Bool:
  True{}

def line(label: String, totals: R.Totals) -> String:
  match totals:
    case R.Totals{played, matches, rounds, +stuck, +exhausted}:
      "smoke " ++ label ++ " finished=" ++ U32.show((played - stuck - exhausted : U32)) ++ " stuck=" ++ U32.show(stuck) ++ " exhausted=" ++ U32.show(exhausted)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(line("2", R.batch(6n, 20000n, D.TwoSeats{}, items(), D.Duo{R.DoNBrain{}, R.StoryBrain{}}, 1, 11)))
    IO.print(line("3", R.batch(6n, 20000n, D.ThreeSeats{}, items(), D.Trio{R.DoNBrain{}, R.StoryBrain{}, R.StoryBrain{}}, 1, 12)))
    IO.print(line("4", R.batch(6n, 20000n, D.FourSeats{}, items(), D.Quad{R.DoNBrain{}, R.DoNBrain{}, R.StoryBrain{}, R.StoryBrain{}}, 1, 13)))
