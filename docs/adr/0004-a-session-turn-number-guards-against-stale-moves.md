# A session turn number guards against stale moves

`play_move` takes the `turn` of the view the move was chosen from and refuses any other. The turn is one counter per session. It advances with every accepted move by any player and with every new match, so it never repeats in a server process or page load. That one number refuses a move repeated after it was played, a move chosen from an earlier view, and a move from a finished match after a rematch with the same seed. No tokens are issued and no acknowledgements are tracked per agent.

## Considered Options

- Per-view tokens or nonces: per-agent state, and nothing they catch that the turn misses.
- A per-match turn: a rematch with the same seed repeats it, so a late move from the old match would play in the new one.
