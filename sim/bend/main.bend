import Base
import ./controller.bend as C
import ./driver.bend as D
import ./view.bend as V

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Verbose match. A = DoN, B = story. Seed 20261011.")
    IO.print(V.render_match(D.verbose_match(20261011, C.DoN{}, C.Story{})))
    IO.print("Independent matches per matchup = 16384. Three rounds per match.")
    IO.print(V.render_counts("story vs story", D.batch(14n, C.Story{}, C.Story{}, 1, 100)))
    IO.print(V.render_counts("DoN vs DoN", D.batch(14n, C.DoN{}, C.DoN{}, 1, 200)))
    IO.print(V.render_counts("DoN vs story", D.batch(14n, C.DoN{}, C.Story{}, 1, 300)))
