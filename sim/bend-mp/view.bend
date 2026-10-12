import Base
import ./domain.bend as D
import ./driver.bend as R

# Plain-text rendering of notes and batch totals.
def seat_name(seat: D.Seat) -> String:
  "seat " ++ U32.show(R.seat.code(seat))

def shell_name(shell: D.Shell) -> String:
  match shell:
    case D.Live{}:
      "live"
    case D.Blank{}:
      "blank"

def item_name(item: D.Item) -> String:
  match item:
    case D.Saw{}:
      "handsaw"
    case D.Glass{}:
      "magnifying glass"
    case D.Jammer{}:
      "jammer"
    case D.Cigarettes{}:
      "cigarettes"
    case D.Beer{}:
      "beer"
    case D.Phone{}:
      "burner phone"
    case D.Inverter{}:
      "inverter"
    case D.Adrenaline{}:
      "adrenaline"
    case D.Remote{}:
      "remote"

def slot_name(slot: D.Slot) -> String:
  "slot " ++ Nat.show(D.slot.code(slot))

def direction_name(direction: D.Direction) -> String:
  match direction:
    case D.Clockwise{}:
      "clockwise"
    case D.CounterClockwise{}:
      "counter-clockwise"

def used_text.by(own: Bool, +seat: D.Seat, owner: D.Seat, slot: D.Slot, item: D.Item) -> String:
  match own:
    case True{}:
      seat_name(seat) ++ " uses " ++ item_name(item) ++ " (" ++ slot_name(slot) ++ ")"
    case False{}:
      seat_name(seat) ++ " steals " ++ item_name(item) ++ " from " ++ seat_name(owner) ++ " (" ++ slot_name(slot) ++ ") and uses it"

def used_text(+seat: D.Seat, +owner: D.Seat, slot: D.Slot, item: D.Item) -> String:
  used_text.by(D.seat.eq(seat, owner), seat, owner, slot, item)

def event_text(event: D.GameEvent) -> String:
  match event:
    case D.RoundBegan{round, health, first}:
      "Round " ++ Nat.show(1n+round) ++ ": health " ++ Nat.show(health) ++ ", " ++ seat_name(first) ++ " goes first"
    case D.GrabbingBegan{seats}:
      "Items are handed out"
    case D.Granted{seat, item}:
      "  " ++ seat_name(seat) ++ " takes " ++ item_name(item)
    case D.Placed{seat, slot, item}:
      "  " ++ seat_name(seat) ++ " places " ++ item_name(item) ++ " in " ++ slot_name(slot)
    case D.GrabbingEnded{seat}:
      "  " ++ seat_name(seat) ++ " is done grabbing"
    case D.DistributionDone{}:
      "Items are placed"
    case D.Loaded{D.Load{live, blank}}:
      "Loaded: " ++ Nat.show(live) ++ " live, " ++ Nat.show(blank) ++ " blank"
    case D.TurnSkipped{seat}:
      seat_name(seat) ++ " is jammed: turn skipped"
    case D.JamLifted{seat}:
      seat_name(seat) ++ " shakes off the jam"
    case D.TurnGiven{seat}:
      "Turn: " ++ seat_name(seat)
    case D.PickedUp{seat}:
      seat_name(seat) ++ " picks up the gun"
    case D.Fired{shooter, target, shell, captured, applied, health}:
      seat_name(shooter) ++ " shoots " ++ seat_name(target) ++ ": " ++ shell_name(shell) ++ ", damage " ++ Nat.show(applied) ++ ", health " ++ Nat.show(health)
    case D.Died{seat}:
      seat_name(seat) ++ " dies"
    case D.Used{seat, owner, slot, item}:
      used_text(seat, owner, slot, item)
    case D.Healed{seat, health}:
      seat_name(seat) ++ " heals to " ++ Nat.show(health)
    case D.Ejected{seat, shell}:
      seat_name(seat) ++ " ejects a " ++ shell_name(shell) ++ " shell"
    case D.Inverted{seat}:
      seat_name(seat) ++ " inverts the chamber"
    case D.JamApplied{by, target}:
      seat_name(by) ++ " jams " ++ seat_name(target)
    case D.DirectionFlipped{direction}:
      "Turn order is now " ++ direction_name(direction)
    case D.RoundWon{seat, prize}:
      seat_name(seat) ++ " wins the round: " ++ U32.show(prize)
    case D.MatchConcluded{}:
      "Match concluded"

def secret_text(secret: D.Secret) -> String:
  match secret:
    case D.Glimpse{shell}:
      "sees the chamber: " ++ shell_name(shell)
    case D.Clue{position, shell}:
      "hears shell " ++ Nat.show(position) ++ " is " ++ shell_name(shell)
    case D.NoClue{}:
      "hears nothing useful"
    case D.EmptyBriefcase{}:
      "finds an empty briefcase"

def note_text(note: D.Note) -> String:
  match note:
    case D.Shown{event}:
      event_text(event)
    case D.Told{seat, secret}:
      "  (" ++ seat_name(seat) ++ " " ++ secret_text(secret) ++ ")"

def notes_text(notes: List<&2, D.Note>) -> String:
  match notes:
    case Nil{}:
      ""
    case note <> rest:
      note_text(note) ++ "\n" ++ notes_text(rest)

def outcome_text(outcome: R.Outcome) -> String:
  match outcome:
    case R.Concluded{}:
      "Outcome: concluded"
    case R.Wedged{}:
      "Outcome: STUCK"
    case R.OutOfFuel{}:
      "Outcome: OUT OF FUEL"

def cash_text(entries: List<&2, D.At<&2, U32>>) -> String:
  match entries:
    case Nil{}:
      ""
    case D.At{seat, cash} <> rest:
      seat_name(seat) ++ " cash " ++ U32.show(cash) ++ "; " ++ cash_text(rest)

def run_text(run: R.Run, outcome: R.Outcome) -> String:
  match run:
    case R.Run{state, minds, heard, rng, rounds, cash, verbose, trace}:
      notes_text(trace) ++ outcome_text(outcome) ++ "\n" ++ cash_text(D.ring.entries(U32, cash))

def played_text(played: R.Played) -> String:
  match played:
    case R.Played{run, outcome}:
      run_text(run, outcome)

def rate_text.permille(wins: U32, played: U32, +permille: U32) -> String:
  U32.show(wins) ++ "/" ++ U32.show(played) ++ " (" ++ U32.show(U32.div(permille, 10)) ++ "." ++ U32.show(U32.mod(permille, 10)) ++ "%)"

# "wins of played (xx.x%)"
def rate_text(+wins: U32, +played: U32) -> String:
  rate_text.permille(wins, played, U32.div(U32.mul(1000, wins), Bool.pick(U32, U32.is_eq(played, 0), 1, played)))

def seat_rates(entries: List<&2, D.At<&2, U32>>, +played: U32) -> String:
  match entries:
    case Nil{}:
      ""
    case D.At{seat, wins} <> rest:
      seat_name(seat) ++ " " ++ rate_text(wins, played) ++ "  " ++ seat_rates(rest, played)

def sum_wins(entries: List<&2, D.At<&2, U32>>) -> U32:
  match entries:
    case Nil{}:
      0
    case D.At{seat, wins} <> rest:
      U32.add(wins, sum_wins(rest))

def totals_text(totals: R.Totals) -> String:
  match totals:
    case R.Totals{+played, matches, +rounds, stuck, exhausted}:
      "  match wins: " ++ seat_rates(D.ring.entries(U32, matches), played) ++ "\n  round wins: " ++ seat_rates(D.ring.entries(U32, rounds), sum_wins(D.ring.entries(U32, rounds))) ++ "\n  stuck " ++ U32.show(stuck) ++ ", out of fuel " ++ U32.show(exhausted)

def render_totals(label: String, totals: R.Totals) -> String:
  label ++ "\n" ++ totals_text(totals)
