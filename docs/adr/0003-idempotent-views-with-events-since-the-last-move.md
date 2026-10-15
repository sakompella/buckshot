# Agent views are idempotent and carry the events since the player's last move

A player's view is computed from the match log alone. Until some player moves, every `get_game` returns the same view. It carries the events since the player's previous turn ended, starting with that player's own last move, plus the secrets that player heard. No per-agent cursor or "seen" state exists, so a lost or repeated reply loses nothing. And the views a player moves from, followed by its final view, add up to its whole log with no gaps or repeats. The arena sends log entries its own way, through the store; see ADR-0011.

## Considered Options

- Marking events as delivered once read: then a retry after a lost reply drops events, and the server keeps per-agent state.
- Always sending the whole log: correct, but it grows every turn and buries the new events.
