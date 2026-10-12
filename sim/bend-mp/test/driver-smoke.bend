import Base
import ../domain.bend as D
import ../driver.bend as R

# Smoke test for check.sh: 64 matches at each table size run to the end, with
# nothing stuck and no fuel spent. Items stay off until the machine supports
# them (flip items() in ../main.bend too).

def items() -> Bool:
  False{}

def line(label: String, totals: R.Totals) -> String:
  match totals:
    case R.Totals{played, matches, rounds, stuck, exhausted}:
      "smoke " ++ label ++ " played=" ++ U32.show(played) ++ " stuck=" ++ U32.show(stuck) ++ " exhausted=" ++ U32.show(exhausted)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(line("2", R.batch(6n, 20000n, D.TwoSeats{}, items(), D.Duo{R.DoNBrain{}, R.StoryBrain{}}, 1, 11)))
    IO.print(line("3", R.batch(6n, 20000n, D.ThreeSeats{}, items(), D.Trio{R.DoNBrain{}, R.StoryBrain{}, R.StoryBrain{}}, 1, 12)))
    IO.print(line("4", R.batch(6n, 20000n, D.FourSeats{}, items(), D.Quad{R.DoNBrain{}, R.DoNBrain{}, R.StoryBrain{}, R.StoryBrain{}}, 1, 13)))
