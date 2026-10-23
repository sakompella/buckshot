# Regret

How good each agent move was, by the minimax player in `sim/bend-mp/player/` ([ADR-0043](../../adr/0043-minimax-player.md)). For every agent decision the player scores each legal move from the deciding player's own information. Regret is the best move's score minus the chosen move's score. The script scores one match, or every match of the analysis database, split over shards.

## How it is measured

`web/scripts/arena-regret.ts` replays each replay-validated match of the analysis database ([database.md](../database.md)) through `replayOf`, as `arena-knowledge.ts` does. Before each agent move it builds the player's input: the match configuration, the public board, and the deciding player's whole log (every public event and its own secrets, in the order it heard them). The hidden gun and other players' secrets never enter. TypeScript only marshals these values into `analyse` (through `sim/bend-mp/analysis.bend`) and reads the scores back. Forced grabs and fallback moves are not scored.

A score is the deciding player's chance of winning the current round, in millionths. Divide by 10,000 for a percentage; a regret of 10,000 is one percentage point. Opponents are modelled as minimizing it from public information.

- **Searched:** the search finished at least one depth. Regret is set, and is 0 for the best move.
- **Fallback:** no depth finished, because the node budget ran out first or the run asked for depth 0. Every move gets the same static value; the regret is NULL, never 0.
- **Invalid:** the player could not build a belief from the log; the reason is stored and there is no regret.
- **Exact:** both the best and the chosen score are 0 or 1,000,000. Only a settled round gives those scores: a win, or a loss, which a dead player's 0 always is. Treat only exact rows as solved. `exact = 0` means not proven exact, not heuristic. Take both players at 1 health with one live and one blank shell left. Shooting the other player settles the round on every path, but its score of 500,000 is a mix of a win and a loss, so the row is not marked exact. The search does not report which values are settled, and changing the evaluator is out of scope for #3.

## The `regret` table

The script writes to the `regret` table of the derived database named by `--out`, creating it if needed and leaving other tables alone, so it can share a file with the knowledge tables. Rows are keyed by match, ordinal, player version, depth limit and budget. Each row is committed as it is scored, and a rerun skips the decisions already scored with the same key, so an interrupted run resumes where it stopped, and new matches are the only work left after an import. Runs with other settings sit beside it. Shards may write one file together: it is in WAL mode and each write waits up to 30 s for the other.

| Column | Meaning |
|---|---|
| `match_id`, `ordinal` | The decision, as in the analysis database's `decisions`. |
| `player`, `label` | The deciding player's letter and the move it chose. |
| `evaluator` | A hash of the compiled player. Never mix rows with different values. |
| `max_depth`, `budget` | The run's depth limit (decisions, by every player) and node budget. |
| `status` | `searched`, `fallback` or `invalid`. |
| `values_json` | Every legal move with its score, in the machine's order. |
| `best`, `best_score`, `chosen_score`, `regret`, `exact` | Set only when searched. Ties go to the first move. `exact` is 1 when proven exact, 0 when not proven (see above). |
| `depth`, `limited` | The depth the search finished, and whether the budget stopped it there. |
| `nodes`, `ms` | Nodes expanded and milliseconds spent on the decision. |

## Runtime

With the defaults, depth 6 and a budget of 20,000 nodes, 7 matches (352 decisions) on hp-server took 344 ms per decision on average: median 274 ms, 95th percentile 804 ms, max 1,070 ms. 39% of the searches were stopped by the budget, at depth 2 to 5. At that rate the 112,546 agent decisions take about 11 hours in one process.

## Reproduce

From `web/`, after `bun run rules`:

    nice -n 10 bun scripts/arena-regret.ts --db <buckshot.sqlite> --out <derived>.sqlite --match <match name> [--depth 6] [--budget 20000]
    nice -n 10 bun scripts/arena-regret.ts --db <buckshot.sqlite> --out <derived>.sqlite --all [--shard K/N] [--depth 6] [--budget 20000]

`--all` takes every replay-validated match in tournament and match name order. `--shard K/N` (K from 1) keeps every Nth match, so N processes can run side by side on one `--out` file. A match that fails is logged and skipped, the shard exits 1 at the end, and a rerun retries it. Progress is one stderr line per match.

`web/test/regret.test.ts` checks known positions: a forced win, a certain loss, a round-ending shot, the fallback, and another player's secret. It also runs the script on recorded matches that reach a forced win and a certain loss, and checks the stored rows, on a faux match imported from an arena run, and on two shards writing one file.

## Limits

- The value is the chance of winning the round, not the match's cash.
- Reloads are leaves: a move that empties the gun is valued before the next load is drawn.
- The static evaluation's item weights are untrained starting values, so heuristic regrets carry its biases. Read small regrets with care.
