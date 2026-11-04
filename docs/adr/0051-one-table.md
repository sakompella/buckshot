# One table for Play and Replay

Play and Replay draw the same table (`web/src/board-view.ts`), styled by `web/src/table.css`, which both pages' stylesheets follow. The table takes a seat table and the legal moves of the seat to act, each move a chain of steps (`TableMove`, the agents' move model) with its label, plus an optional click handler and an optional chosen move:

- **Play** passes Bend's legal moves for the human seat, each one step, and a click handler; a click sends the move's index.
- **Replay** passes no handler. It marks every thing the chosen move acts on (an item, the gun, a seat) and shows the shells as the mover counts them, with the chamber it knows.

The positions come from the rules, not from the decision rows: for a match whose seed, controllers and letters are in its manifest, the viewer replays the match through `replayOf` and attaches to each decision the board before it, the mover's legal moves (`agentMoves`) and the chosen move's index. Matches that do not replay show a note instead of the table. Replaying a long match takes up to two seconds, so the viewer keeps the encoded detail of the last 32 matches it sent.

The Replay table faces the match's first seat at every move, so seats do not swap places while scrubbing; the acting seat's counter is lit.

## Considered Options

- **Replay in the page:** the bundle would carry Bend's runtime into the arena page and replay on every open; the server already has both.
- **Keep the arena's own table (seat cards and a shell row):** it showed counts but not the items' places, the gun or the legal moves, and it would drift from Play's look.
- **Facing the mover:** the table would flip at every turn.

## Consequences

- The match detail's JSON carries the board, so it uses the codec form of its schema (`MatchDetailJson`); Options in board slots do not survive plain JSON.
- The online build (ADR-0050) has no Replay and draws only Play's table.
- `analysis/regret.ts` still matches candidate moves to decisions by label.
