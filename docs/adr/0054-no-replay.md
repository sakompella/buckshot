# No match replay

The Replay page is gone, as the game table was (ADR-0053). The site is the benchmark only: matches in lists are no longer links, `/replay/<match id>` parses as not found in the local viewer and the online build, and the `/api/match` route the page read is deleted.

What the importer and the benchmark pages use stays: `web/src/arena/replay.ts` (the importer's code hash covers it), the analysis module, and the `Shell`, `MoveRegret` and story schemas of the API. The replay-only UI code is deleted, not hidden: the page (`web/src/arena-viewer/page/replay.ts`), the table drawing (`web/src/board.ts`, `web/src/board-view.ts`, `web/src/table.css`), the board, shell, gun and bolt icons, the regret-coverage script and the replay part of the check script.

## Consequences

- The URL is the arena's filter and open leaderboard row only; nothing pushes a history entry any more.
- Bringing the replay back means restoring its files from the history before this ADR and re-adding its route and API shape; the importer is untouched, so old matches stay replayable in principle.
- Other sites' links to `/replay/<match id>` lead to the arena's not-found view.
