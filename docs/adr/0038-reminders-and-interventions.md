# Reminders and interventions

When a model ends its run on its turn without a legal `play_move`, the arena sends one fixed message, the same for every model: "It is still your turn; call play_move with one of the listed moves." If the run that follows also ends without a move, the arena plays for the player and logs the move as `by: "fallback"`. That is an intervention. Its move is a pick among the player's legal moves sorted by label, seeded by the SHA-256 of the match seed, the turn and the player, so seating and table order do not change it. A match with an intervention still counts, and the stats report each entrant's intervention rate beside its win rate. A provider error is not a missed move: the match stops as a fault, and a rerun resumes it (ADR-0009).

## Considered Options

- The first legal move, as before. Its target follows table order, so in `four-1` D's missed turn became "Shoot Player B" only because of where B sat.
- Forfeiting the match or the round: in a match of three or four, someone would have to be handed the win, and the rules have no such outcome.
- Several reminders, or reminders worded for the situation: each extra message is coaching that some models get and others do not.

## Consequences

The reminder is a user message in the conversation, journaled under the request id `turn-<n>-reminder`, and logged as a `reminder` line. An intervention line keeps `kind: "fallback"`, so run format 1 still holds. The reminder is no cure for a model that misreads the game; the clearer wording of a death ("is out for this round") is.
