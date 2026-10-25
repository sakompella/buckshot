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

The summary tables below come from the regret and knowledge databases, read only, in a few seconds:

    python3 tools/arena/analysis/regret.py [--regret <derived>/regret.sqlite] [--knowledge <derived>/knowledge.sqlite] [--doc docs/arena/analysis/regret.md]

With `--doc` it rewrites the tables at the end of this page. `python3 -m unittest discover -s tools/arena/analysis` runs its tests.

## Results

This is a casual pass over the full run, with counts and means and no intervals. It covers the 110,880 agent decisions of the 2,181 finished matches in the database now with no DeepSeek seat (DeepSeek is left out as in [matchups.md](matchups.md)). Every one has a row, every row was searched, and none fell back. The 112,546 rows of the run also hold DeepSeek's matches and unfinished ones. A config is a model with its effort, pooled over the tournaments it played in. Regret is in percentage points of the round win chance, as above. Mean regret over all decisions is 2.5 points and the 90th percentile 6.8. 11% of the decisions are exact.

1. **Regret and the ratings agree at the ends.**
   - At medium effort the mean regret is Opus 1.1, Sol 1.4, Astra 1.4, Sonnet 2.0, Haiku 5.5 2.0, Terra 2.7, Luna 4.0 and Haiku 4.5 4.9 points.
   - The cross-model ratings in [matchups.md](matchups.md) put the same three on top (Astra first) and Luna and Haiku 4.5 at the bottom, in the other order. The five in between overlap in rating, and regret does not separate them further. Regret uses no match results, so it agrees from the other side.
2. **More effort mostly lowers regret. Sol and Opus barely move.**
   - Haiku 5.5 goes from 3.7 at off to 1.0 at max, Sonnet from 2.3 to 0.9, Luna from 4.0 to 2.2, Terra from 3.1 at low to 1.5 at max. Haiku 4.5 moves less, from 6.0 at off to 4.5 at high. The steps are not always in order: Luna is 4.0 at off and 4.3 at low. The 90th percentile falls with it: Haiku 5.5 10.1 to 3.2, Sonnet 7.2 to 2.7.
   - Sol (1.2 to 1.5) and Opus (1.0 to 1.2) change by 0.3 points or less. Sol is flat in the rating sweep too. Opus is not: its xhigh rating is far above its low, yet its regret moves by 0.2 points. Regret does not explain that gap.

**Near reloads (for [#4](https://github.com/sakompella/buckshot/issues/4)).** Regret concentrates in shots with two or three shells left in the gun.
- Those shots average 4.7 and 4.0 points, with a 90th percentile of 15.5 and 13.4. A shot with one shell left averages 1.9 and one with five left 2.1.
- Item moves stay between 1.7 and 2.4 at every distance. In this cut they show no sign of a reload effect.
- The node budget does not explain the rise. It stopped 6% and 28% of the searches with two and three shells left, against 0.1% at one shell left.
- This shows where regret is, not why. A shot with two left ends the search at the reload one shot later, so the static leaf is a possible cause. Real mistakes on near-even shells are another. The table cannot tell them apart, which is what #4 measures. Sample shots at two and three shells left first.

## Limits

- The value is the chance of winning the round, not the match's cash.
- Reloads are leaves: a move that empties the gun is valued before the next load is drawn.
- The static evaluation's item weights are untrained starting values, so heuristic regrets carry its biases. Read small regrets with care.
- Regret is a mean over decisions, not over matches. Decisions of one match are not independent, and a config's opponents differ between tournaments. Treat gaps of a few tenths of a point as noise.
- A regret of 0 means the chosen move tied the best score at the depth reached, not that it was proven right. Only the 11% of exact rows are.
- 40% of the searches were stopped by the budget at depth 1 to 5. With four or more shells left most are, so those rows compare shallower searches.

## Tables

<!-- tables:start -->
110,880 searched decisions; 0 left out for having no search; 0 agent decisions with no row.

### Regret by config

| model | effort | decisions | mean regret | 90th percentile | exact |
|---|---|---|---|---|---|
| claude-opus-5-5 | low | 468 | 1.2 | 4.0 | 9.2% |
| claude-opus-5-5 | medium | 5,047 | 1.1 | 3.5 | 12.0% |
| claude-opus-5-5 | high | 970 | 1.0 | 3.8 | 7.3% |
| claude-opus-5-5 | xhigh | 2,024 | 1.0 | 3.4 | 11.6% |
| gpt-6.1-sol | low | 1,851 | 1.5 | 4.6 | 10.6% |
| gpt-6.1-sol | medium | 5,401 | 1.4 | 4.3 | 12.2% |
| gpt-6.1-sol | high | 1,951 | 1.3 | 4.5 | 11.5% |
| gpt-6.1-sol | xhigh | 1,963 | 1.2 | 4.2 | 11.9% |
| gpt-6.1-sol | max | 2,054 | 1.3 | 4.6 | 12.3% |
| gpt-6-astra | medium | 4,492 | 1.4 | 4.0 | 12.4% |
| claude-sonnet-5-5 | off | 2,415 | 2.3 | 7.2 | 11.4% |
| claude-sonnet-5-5 | low | 2,338 | 2.2 | 6.6 | 11.2% |
| claude-sonnet-5-5 | medium | 6,001 | 2.0 | 6.1 | 12.4% |
| claude-sonnet-5-5 | high | 2,455 | 1.7 | 5.3 | 10.5% |
| claude-sonnet-5-5 | xhigh | 2,439 | 1.0 | 3.5 | 12.1% |
| claude-sonnet-5-5 | max | 2,568 | 0.9 | 2.7 | 15.4% |
| claude-haiku-5-5 | off | 2,387 | 3.7 | 10.1 | 8.0% |
| claude-haiku-5-5 | low | 2,513 | 2.2 | 6.1 | 9.1% |
| claude-haiku-5-5 | medium | 6,058 | 2.0 | 5.4 | 11.7% |
| claude-haiku-5-5 | high | 2,513 | 1.5 | 4.4 | 10.9% |
| claude-haiku-5-5 | xhigh | 2,534 | 1.1 | 3.6 | 12.0% |
| claude-haiku-5-5 | max | 2,573 | 1.0 | 3.2 | 12.4% |
| gpt-5.6-terra | low | 1,852 | 3.1 | 10.0 | 9.6% |
| gpt-5.6-terra | medium | 5,193 | 2.7 | 7.8 | 10.3% |
| gpt-5.6-terra | high | 1,886 | 2.6 | 7.9 | 11.6% |
| gpt-5.6-terra | xhigh | 2,030 | 2.1 | 6.1 | 10.4% |
| gpt-5.6-terra | max | 2,170 | 1.5 | 4.2 | 10.0% |
| gpt-6-luna | off | 2,888 | 4.0 | 11.8 | 7.4% |
| gpt-6-luna | low | 2,920 | 4.3 | 13.0 | 8.7% |
| gpt-6-luna | medium | 6,606 | 4.0 | 12.1 | 8.8% |
| gpt-6-luna | high | 2,829 | 3.2 | 9.9 | 11.5% |
| gpt-6-luna | xhigh | 2,792 | 2.5 | 6.9 | 13.5% |
| gpt-6-luna | max | 2,936 | 2.2 | 6.4 | 12.7% |
| claude-haiku-4-5-20251001 | off | 2,173 | 6.0 | 17.6 | 6.5% |
| claude-haiku-4-5-20251001 | minimal | 2,080 | 4.7 | 13.8 | 6.6% |
| claude-haiku-4-5-20251001 | low | 2,125 | 5.1 | 16.3 | 8.8% |
| claude-haiku-4-5-20251001 | medium | 5,302 | 4.9 | 14.5 | 7.5% |
| claude-haiku-4-5-20251001 | high | 2,083 | 4.5 | 12.5 | 8.4% |
| all |  | 110,880 | 2.5 | 6.8 | 10.7% |

### Regret by shells left in the gun

| shells left | stopped by budget | shots | mean | 90th percentile | item moves | mean | 90th percentile |
|---|---|---|---|---|---|---|---|
| 1 | 0.1% | 11,831 | 1.9 | 4.0 | 5,312 | 2.0 | 6.7 |
| 2 | 6.2% | 11,525 | 4.7 | 15.5 | 9,516 | 1.7 | 5.6 |
| 3 | 27.9% | 11,192 | 4.0 | 13.4 | 13,414 | 1.7 | 5.3 |
| 4 | 56.6% | 8,795 | 2.7 | 8.2 | 12,354 | 1.8 | 5.4 |
| 5 | 85.5% | 6,073 | 2.1 | 7.0 | 10,374 | 2.0 | 5.1 |
| 6 | 96.6% | 3,469 | 1.9 | 5.7 | 7,025 | 2.4 | 4.5 |
<!-- tables:end -->
