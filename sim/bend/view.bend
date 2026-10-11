import Base
import ./model.bend as M
import ./driver.bend as D

def side_name(side: M.Side) -> String:
  match side:
    case M.A{}:
      "A"
    case M.B{}:
      "B"

def shell_name(shell: M.Shell) -> String:
  match shell:
    case M.Live{}:
      "live"
    case M.Blank{}:
      "blank"

def item_name(item: M.Item) -> String:
  match item:
    case M.Saw{}:
      "handsaw"
    case M.Glass{}:
      "magnifying glass"
    case M.Jammer{}:
      "jammer"
    case M.Cigs{}:
      "cigarettes"
    case M.Beer{}:
      "beer"
    case M.Phone{}:
      "phone"
    case M.Adrenaline{}:
      "adrenaline"
    case M.Inverter{}:
      "inverter"

def target_name(target: M.Target) -> String:
  match target:
    case M.Self{}:
      "self"
    case M.Opp{}:
      "opponent"

def use_verb(stolen: Bool) -> String:
  match stolen:
    case True{}:
      " steals and uses "
    case False{}:
      " uses "

def render_event(event: M.GameEvent) -> String:
  match event:
    case M.Reveal{side, index, shell}:
      side_name(side) ++ " sees shell[" ++ Nat.show(index) ++ "] = " ++ shell_name(shell)
    case M.Fired{side, target, shell, damage}:
      side_name(side) ++ " shoots " ++ target_name(target) ++ ", " ++ shell_name(shell) ++ ", damage " ++ Nat.show(damage)
    case M.Ejected{side, shell}:
      side_name(side) ++ " ejects " ++ shell_name(shell)
    case M.Inverted{side, shell}:
      side_name(side) ++ " inverts chamber to " ++ shell_name(shell)
    case M.Used{side, item, stolen}:
      side_name(side) ++ use_verb(stolen) ++ item_name(item)
    case M.Reloaded{live, blank}:
      "Reloaded with " ++ Nat.show(live) ++ " live and " ++ Nat.show(blank) ++ " blank"
    case M.Skipped{side}:
      side_name(side) ++ " skips a jammed turn"
    case M.RoundStarted{number, max_hp, first}:
      "Round " ++ Nat.show(number) ++ " starts, max HP " ++ Nat.show(max_hp) ++ ", first " ++ side_name(first)
    case M.RoundWon{side, prize}:
      side_name(side) ++ " wins round, prize $" ++ U32.show(prize)
    case M.MatchWon{side}:
      side_name(side) ++ " wins match"
    case M.Exhausted{}:
      "Simulation fuel exhausted"

def render_events(events: List<&2, M.GameEvent>) -> String:
  match events:
    case Nil{}:
      ""
    case Con{event, rest}:
      render_event(event) ++ "\n" ++ render_events(rest)

def item_tail(items: List<&2, M.Item>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{item, rest}:
      ", " ++ item_name(item) ++ item_tail(rest)

def render_items(items: List<&2, M.Item>) -> String:
  match items:
    case Nil{}:
      "none"
    case Con{item, rest}:
      item_name(item) ++ item_tail(rest)

def jam_status(jammed: Bool, checked: Bool) -> String:
  match jammed checked:
    case False{} _:
      "clear"
    case True{} False{}:
      "jammed, skip pending"
    case True{} True{}:
      "jammed, skip checked"

def render_player(player: M.PlayerState) -> String:
  match player:
    case M.Player{hp, items, jammed, checked}:
      "HP " ++ Nat.show(hp) ++ "; items [" ++ render_items(items) ++ "]; " ++ jam_status(jammed, checked)

def saw_status(sawed: Bool) -> String:
  match sawed:
    case False{}:
      "normal"
    case True{}:
      "sawed"

def render_table(obs: M.Obs) -> String:
  match obs:
    case M.Obs{side, own, opp, max_hp, live, blank, remaining, sawed}:
      "Table for " ++ side_name(side) ++ ", max HP " ++ Nat.show(max_hp) ++ "\n" ++
      "Own: " ++ render_player(own) ++ "\n" ++
      "Opponent: " ++ render_player(opp) ++ "\n" ++
      "Gun: " ++ Nat.show(live) ++ " live, " ++ Nat.show(blank) ++ " blank, " ++ Nat.show(remaining) ++ " remaining, " ++ saw_status(sawed)

def winner_name(done: Bool, cash_order: Cmp) -> String:
  match done cash_order:
    case False{} _:
      "undecided, match unfinished"
    case True{} LT{}:
      "B"
    case True{} EQ{}:
      "tie"
    case True{} GT{}:
      "A"

def render_summary(+g: M.Game) -> String:
  match g:
    case M.Game{a, b, turn, max_hp, shells, deck, seed, counter, sawed, round, wins_a, wins_b, cash_a, cash_b, done}:
      "Match summary\n" ++
      "A: $" ++ U32.show(cash_a) ++ ", rounds won " ++ U32.show(wins_a) ++ "\n" ++
      "B: $" ++ U32.show(cash_b) ++ ", rounds won " ++ U32.show(wins_b) ++ "\n" ++
      "Winner: " ++ winner_name(done, U32.cmp(cash_a, cash_b))

def render_entry(entry: D.Entry) -> String:
  match entry:
    case D.Opened{events}:
      render_events(events)
    case D.Acted{obs, events}:
      render_table(obs) ++ "\n" ++ render_events(events)
    case D.RanOut{}:
      render_event(M.Exhausted{}) ++ "\n"

def render_trace(entries: List<&2, D.Entry>) -> String:
  match entries:
    case Nil{}:
      ""
    case entry <> rest:
      render_entry(entry) ++ render_trace(rest)

def render_match(played: D.Played) -> String:
  D.Played{+g, trace} = played
  render_trace(trace) ++ render_summary(g)

def hundredths.small(small: Bool, n: U32) -> String:
  match small:
    case True{}:
      "0" ++ U32.show(n)
    case False{}:
      U32.show(n)

def hundredths(+n: U32) -> String:
  hundredths.small(U32.is_lt(n, 10), n)

def percent(+wins: U32, +total: U32) -> String:
  +basis: U32 = U32.div(U32.mul(wins, 10000), total)
  U32.show(U32.div(basis, 100)) ++ "." ++ hundredths(U32.mod(basis, 100)) ++ "%"

def render_counts(label: String, counts: D.Counts) -> String:
  D.Counts{+played, +matches, +rounds, exhausted} = counts
  +rounds_played: U32 = U32.mul(played, 3)
  label ++ "  match A " ++ percent(matches, played) ++ " (" ++ U32.show(matches) ++ "/" ++ U32.show(played) ++ ")  round A " ++ percent(rounds, rounds_played) ++ " (" ++ U32.show(rounds) ++ "/" ++ U32.show(rounds_played) ++ ")  exhausted " ++ U32.show(exhausted)
