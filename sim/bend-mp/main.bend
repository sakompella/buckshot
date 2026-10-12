import Base
import ./domain.bend as D
import ./driver.bend as R
import ./view.bend as V

# A stub: one verbose 2-seat match, then batches. All the work is in driver.bend.

# Flip to True once the machine supports items.
def items() -> Bool:
  False{}

def fuel() -> Nat:
  20000n

def duo(a: R.Brain, b: R.Brain) -> D.Ring<&2, R.Brain>:
  D.Duo{a, b}

def trio(a: R.Brain, b: R.Brain, c: R.Brain) -> D.Ring<&2, R.Brain>:
  D.Trio{a, b, c}

def quad(a: R.Brain, b: R.Brain, c: R.Brain, d: R.Brain) -> D.Ring<&2, R.Brain>:
  D.Quad{a, b, c, d}

def two(label: String, brains: D.Ring<&2, R.Brain>, salt: U32) -> String:
  V.render_totals(label, R.batch(14n, fuel(), D.TwoSeats{}, items(), brains, 1, salt))

def three(label: String, brains: D.Ring<&2, R.Brain>, salt: U32) -> String:
  V.render_totals(label, R.batch(14n, fuel(), D.ThreeSeats{}, items(), brains, 1, salt))

def four(label: String, brains: D.Ring<&2, R.Brain>, salt: U32) -> String:
  V.render_totals(label, R.batch(14n, fuel(), D.FourSeats{}, items(), brains, 1, salt))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Verbose match, 2 seats: seat 1 = DoN, seat 3 = story. Seed 20261011.")
    IO.print(V.played_text(R.verbose_match(fuel(), D.TwoSeats{}, items(), duo(R.DoNBrain{}, R.StoryBrain{}), 20261011)))
    IO.print("Independent matches per line = 16384. Three rounds per match.")
    IO.print(two("2 seats, story vs story", duo(R.StoryBrain{}, R.StoryBrain{}), 100))
    IO.print(two("2 seats, DoN vs DoN", duo(R.DoNBrain{}, R.DoNBrain{}), 200))
    IO.print(two("2 seats, DoN (seat 1) vs story (seat 3)", duo(R.DoNBrain{}, R.StoryBrain{}), 300))
    IO.print(two("2 seats, story (seat 1) vs DoN (seat 3)", duo(R.StoryBrain{}, R.DoNBrain{}), 400))
    IO.print(three("3 seats, DoN / story / story", trio(R.DoNBrain{}, R.StoryBrain{}, R.StoryBrain{}), 500))
    IO.print(three("3 seats, story / DoN / DoN", trio(R.StoryBrain{}, R.DoNBrain{}, R.DoNBrain{}), 600))
    IO.print(four("4 seats, DoN / DoN / story / story", quad(R.DoNBrain{}, R.DoNBrain{}, R.StoryBrain{}, R.StoryBrain{}), 700))
    IO.print(four("4 seats, story / story / DoN / DoN", quad(R.StoryBrain{}, R.StoryBrain{}, R.DoNBrain{}, R.DoNBrain{}), 800))
    IO.print(three("3 seats, all story", trio(R.StoryBrain{}, R.StoryBrain{}, R.StoryBrain{}), 900))
    IO.print(three("3 seats, all DoN", trio(R.DoNBrain{}, R.DoNBrain{}, R.DoNBrain{}), 1000))
    IO.print(four("4 seats, all story", quad(R.StoryBrain{}, R.StoryBrain{}, R.StoryBrain{}, R.StoryBrain{}), 1100))
    IO.print(four("4 seats, all DoN", quad(R.DoNBrain{}, R.DoNBrain{}, R.DoNBrain{}, R.DoNBrain{}), 1200))
