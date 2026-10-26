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

With `--doc` it rewrites the tables at the end of this page. The by-round tables come from `tools/arena/analysis/by_round.py`, which also reads the analysis database for round winners (`--db`) and rewrites the tables of the last section the same way. `python3 -m unittest discover -s tools/arena/analysis` runs its tests.

## Results

This is a casual pass over the full run, with counts and means and no intervals. It covers the 125,150 agent decisions of the 2,471 finished matches in the database now with no DeepSeek seat (DeepSeek is left out as in [matchups.md](matchups.md)). Every one has a row, every row was searched, and none fell back. The 126,816 rows of the run also hold DeepSeek's matches and unfinished ones. A config is a model with its effort, pooled over the tournaments it played in. Regret is in percentage points of the round win chance, as above. Mean regret over all decisions is 2.5 points and the 90th percentile 6.8. 11% of the decisions are exact.

1. **Regret and the ratings agree at the ends.**
   - At medium effort the mean regret is Opus 1.1, Sol 1.4, Astra 1.4, Haiku 5.5 1.9, Sonnet 2.0, Terra 2.7, Luna 4.0 and Haiku 4.5 4.8 points.
   - The cross-model ratings in [matchups.md](matchups.md) put the same three on top (Astra first) and Luna and Haiku 4.5 at the bottom, in the other order. The five in between overlap in rating, and regret does not separate them further. Regret uses no match results, so it agrees from the other side.
2. **More effort mostly lowers regret. Sol and Opus barely move.**
   - Haiku 5.5 goes from 3.8 at off to 1.0 at max, Sonnet from 2.3 to 0.8, Luna from 4.0 to 2.2, Terra from 3.1 at low to 1.5 at max. Haiku 4.5 moves less, from 6.0 at off to 4.5 at high. The steps are not always in order: Luna is 4.0 at off and 4.4 at low. The 90th percentile falls with it: Haiku 5.5 10.4 to 3.2, Sonnet 7.3 to 2.6.
   - Sol (1.2 to 1.5) and Opus (1.0 to 1.2) change by 0.3 points or less. Sol is flat in the rating sweep too. Opus is not: its xhigh rating is far above its low, yet its regret moves by 0.2 points. Regret does not explain that gap.

**Near reloads (for [#4](https://github.com/sakompella/buckshot/issues/4)).** Regret concentrates in shots with two or three shells left in the gun.
- Those shots average 4.7 and 4.0 points, with a 90th percentile of 15.5 and 13.3. A shot with one shell left averages 1.8 and one with five left 2.1.
- Item moves stay between 1.7 and 2.3 at every distance. In this cut they show no sign of a reload effect.
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
125,150 searched decisions; 0 left out for having no search; 0 agent decisions with no row.

### Regret by config

| model | effort | decisions | mean regret | 90th percentile | exact |
|---|---|---|---|---|---|
| claude-opus-5-5 | low | 680 | 1.2 | 4.0 | 10.1% |
| claude-opus-5-5 | medium | 6,074 | 1.1 | 3.5 | 12.2% |
| claude-opus-5-5 | high | 1,198 | 1.1 | 3.9 | 8.8% |
| claude-opus-5-5 | xhigh | 2,024 | 1.0 | 3.4 | 11.6% |
| gpt-6-astra | medium | 5,393 | 1.4 | 3.9 | 13.1% |
| gpt-6.1-sol | low | 2,085 | 1.5 | 4.6 | 11.4% |
| gpt-6.1-sol | medium | 6,351 | 1.4 | 4.3 | 12.2% |
| gpt-6.1-sol | high | 2,199 | 1.3 | 4.5 | 12.0% |
| gpt-6.1-sol | xhigh | 2,195 | 1.2 | 4.2 | 12.4% |
| gpt-6.1-sol | max | 2,309 | 1.4 | 4.6 | 12.9% |
| claude-sonnet-5-5 | off | 2,659 | 2.3 | 7.3 | 11.4% |
| claude-sonnet-5-5 | low | 2,614 | 2.2 | 6.6 | 11.4% |
| claude-sonnet-5-5 | medium | 6,836 | 2.0 | 6.0 | 12.5% |
| claude-sonnet-5-5 | high | 2,690 | 1.7 | 5.4 | 10.9% |
| claude-sonnet-5-5 | xhigh | 2,668 | 1.0 | 3.6 | 12.3% |
| claude-sonnet-5-5 | max | 2,801 | 0.8 | 2.6 | 15.5% |
| claude-haiku-5-5 | off | 2,601 | 3.8 | 10.4 | 8.0% |
| claude-haiku-5-5 | low | 2,771 | 2.3 | 6.2 | 9.7% |
| claude-haiku-5-5 | medium | 6,957 | 1.9 | 5.3 | 11.6% |
| claude-haiku-5-5 | high | 2,746 | 1.5 | 4.4 | 10.5% |
| claude-haiku-5-5 | xhigh | 2,750 | 1.1 | 3.6 | 12.2% |
| claude-haiku-5-5 | max | 2,811 | 1.0 | 3.2 | 12.9% |
| gpt-5.6-terra | low | 2,111 | 3.1 | 9.7 | 9.9% |
| gpt-5.6-terra | medium | 6,038 | 2.7 | 7.7 | 10.5% |
| gpt-5.6-terra | high | 2,144 | 2.6 | 8.0 | 11.0% |
| gpt-5.6-terra | xhigh | 2,334 | 2.0 | 5.9 | 10.6% |
| gpt-5.6-terra | max | 2,489 | 1.5 | 4.3 | 9.8% |
| gpt-6-luna | off | 3,162 | 4.0 | 11.8 | 7.1% |
| gpt-6-luna | low | 3,183 | 4.4 | 13.2 | 8.9% |
| gpt-6-luna | medium | 7,436 | 4.0 | 12.2 | 9.0% |
| gpt-6-luna | high | 3,087 | 3.2 | 10.2 | 11.5% |
| gpt-6-luna | xhigh | 3,084 | 2.5 | 7.0 | 13.5% |
| gpt-6-luna | max | 3,195 | 2.2 | 6.3 | 12.3% |
| claude-haiku-4-5-20251001 | off | 2,402 | 6.0 | 17.6 | 6.3% |
| claude-haiku-4-5-20251001 | minimal | 2,334 | 4.6 | 13.6 | 6.6% |
| claude-haiku-4-5-20251001 | low | 2,345 | 4.9 | 15.1 | 8.5% |
| claude-haiku-4-5-20251001 | medium | 6,120 | 4.8 | 14.2 | 7.5% |
| claude-haiku-4-5-20251001 | high | 2,274 | 4.5 | 12.3 | 8.2% |
| all |  | 125,150 | 2.5 | 6.8 | 10.8% |

### Regret by shells left in the gun

| shells left | stopped by budget | shots | mean | 90th percentile | item moves | mean | 90th percentile |
|---|---|---|---|---|---|---|---|
| 1 | 0.1% | 13,361 | 1.8 | 3.6 | 5,923 | 1.9 | 6.7 |
| 2 | 6.1% | 13,018 | 4.7 | 15.5 | 10,767 | 1.7 | 5.5 |
| 3 | 27.8% | 12,592 | 4.0 | 13.3 | 15,190 | 1.7 | 5.2 |
| 4 | 56.6% | 9,969 | 2.7 | 8.2 | 13,997 | 1.8 | 5.4 |
| 5 | 85.1% | 6,868 | 2.1 | 7.2 | 11,602 | 2.0 | 5.2 |
| 6 | 96.6% | 3,928 | 1.8 | 5.4 | 7,935 | 2.3 | 4.5 |
<!-- tables:end -->

## By round

Does a model play the short early rounds differently from the later, item-heavy ones? This is a casual pass for [#14](https://github.com/sakompella/buckshot/issues/14), with counts in brackets and no intervals. It covers the same 2,471 finished matches with no DeepSeek seat. Round winners come from the public lines of the match events, as the viewer reads them; the last round's winner is inferred from final cash when its line is missing. Rounds are numbered from 1. A win rate is the share of its rounds a config won, against whoever it met, so it also reflects the opponents' strength.

1. **No config's win rate clearly changes by round.**
   - Pooled over efforts, a model's win rate moves by 4 points or less between rounds for six of the eight models. Astra goes from 58.4% to 62.6% over 219 rounds, and Haiku 4.5 from 46.8% to 42.9% and back to 44.5% over 616.
   - Per config the cells hold 30 to 280 rounds, so gaps of 10 points are common at 110 rounds and say little. The largest runs are Haiku 5.5 off, at 47.3%, 31.8% and 29.1% over 110 rounds each, and Haiku 5.5 max at 50.9%, 68.2% and 56.4%. Neither is a steady trend across the other efforts.
2. **Regret is flat across rounds, except that round 1 shots are a little worse.**
   - Mean regret over all moves is 2.6, 2.4 and 2.5 points in rounds 1, 2 and 3. Models keep their order in every round: the same three, Opus, Astra and Sol, are lowest and Haiku 4.5 is highest.
   - Shots cost 3.4 points in round 1 against 2.9 and 3.1 later. Item moves stay at 1.8 to 1.9. The table does not say why. Decisions of one match are not independent, so the gap is small evidence.
   - Round 3 is often a dead rubber, since prizes are 70k, 75k and 80k and a 2-0 lead settles the winner ([patterns.md](patterns.md)). A one-off check outside the script finds round 3 regret no worse after a 2-0 lead than after a 1-1 split: 2.5 points over 20,905 decisions against 2.4 over 21,039.

<!-- by-round:start -->
7,413 rounds of finished matches; 0 matches left out because their round winners did not match the final cash.

### Win rate and regret by round, per model

| model | effort | round 1 win rate | round 1 mean regret | round 2 win rate | round 2 mean regret | round 3 win rate | round 3 mean regret |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 | all | 55.1% (399) | 1.0 (3,186) | 54.9% (399) | 1.1 (3,518) | 52.6% (399) | 1.2 (3,272) |
| gpt-6-astra | all | 58.4% (219) | 1.5 (1,724) | 62.6% (219) | 1.2 (1,872) | 62.6% (219) | 1.4 (1,797) |
| gpt-6.1-sol | all | 53.2% (616) | 1.3 (4,604) | 55.0% (616) | 1.4 (5,548) | 52.8% (616) | 1.4 (4,987) |
| claude-sonnet-5-5 | all | 51.0% (826) | 1.9 (6,078) | 50.6% (826) | 1.7 (7,472) | 52.2% (826) | 1.6 (6,718) |
| claude-haiku-5-5 | all | 51.2% (828) | 2.0 (6,424) | 50.7% (828) | 1.7 (7,168) | 49.2% (828) | 2.1 (7,044) |
| gpt-5.6-terra | all | 48.9% (616) | 2.6 (4,709) | 50.0% (616) | 2.4 (5,207) | 50.6% (616) | 2.3 (5,200) |
| gpt-6-luna | all | 43.9% (822) | 3.8 (7,230) | 44.5% (822) | 3.3 (8,305) | 45.6% (822) | 3.4 (7,612) |
| claude-haiku-4-5-20251001 | all | 46.8% (616) | 4.9 (5,056) | 42.9% (616) | 4.6 (5,387) | 44.5% (616) | 5.2 (5,032) |
| all |  | - | 2.6 (39,011) | - | 2.4 (44,477) | - | 2.5 (41,662) |

### Mean regret by round and kind of move

| round | all moves | shots | item moves |
|---|---|---|---|
| 1 | 2.6 (39,011) | 3.4 (19,198) | 1.8 (19,813) |
| 2 | 2.4 (44,477) | 2.9 (20,900) | 1.9 (23,577) |
| 3 | 2.5 (41,662) | 3.1 (19,638) | 1.9 (22,024) |

### Win rate and regret by round, per config

| model | effort | round 1 win rate | round 1 mean regret | round 2 win rate | round 2 mean regret | round 3 win rate | round 3 mean regret |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 | low | 46.7% (30) | 1.4 (223) | 63.3% (30) | 1.2 (252) | 56.7% (30) | 0.9 (205) |
| claude-opus-5-5 | medium | 57.1% (238) | 1.1 (1,947) | 55.5% (238) | 1.1 (2,113) | 52.9% (238) | 1.3 (2,014) |
| claude-opus-5-5 | high | 48.0% (50) | 1.0 (350) | 54.0% (50) | 1.0 (450) | 42.0% (50) | 1.2 (398) |
| claude-opus-5-5 | xhigh | 56.8% (81) | 0.9 (666) | 50.6% (81) | 1.1 (703) | 56.8% (81) | 1.0 (655) |
| gpt-6-astra | medium | 58.4% (219) | 1.5 (1,724) | 62.6% (219) | 1.2 (1,872) | 62.6% (219) | 1.4 (1,797) |
| gpt-6.1-sol | low | 53.3% (90) | 1.3 (649) | 47.8% (90) | 1.9 (766) | 48.9% (90) | 1.4 (670) |
| gpt-6.1-sol | medium | 55.1% (256) | 1.5 (2,063) | 60.9% (256) | 1.3 (2,241) | 53.1% (256) | 1.4 (2,047) |
| gpt-6.1-sol | high | 53.3% (90) | 1.4 (644) | 48.9% (90) | 1.2 (878) | 44.4% (90) | 1.4 (677) |
| gpt-6.1-sol | xhigh | 47.8% (90) | 1.2 (629) | 48.9% (90) | 1.3 (802) | 57.8% (90) | 1.2 (764) |
| gpt-6.1-sol | max | 53.3% (90) | 1.0 (619) | 57.8% (90) | 1.6 (861) | 58.9% (90) | 1.4 (829) |
| claude-sonnet-5-5 | off | 51.8% (110) | 2.5 (795) | 39.1% (110) | 2.5 (991) | 47.3% (110) | 2.0 (873) |
| claude-sonnet-5-5 | low | 46.4% (110) | 2.4 (726) | 35.5% (110) | 2.0 (979) | 45.5% (110) | 2.2 (909) |
| claude-sonnet-5-5 | medium | 45.7% (276) | 2.4 (2,000) | 54.3% (276) | 2.0 (2,526) | 54.0% (276) | 1.8 (2,310) |
| claude-sonnet-5-5 | high | 50.9% (110) | 1.8 (846) | 55.5% (110) | 1.6 (1,034) | 44.5% (110) | 1.7 (810) |
| claude-sonnet-5-5 | xhigh | 57.3% (110) | 1.1 (835) | 49.1% (110) | 1.2 (977) | 52.7% (110) | 0.9 (856) |
| claude-sonnet-5-5 | max | 61.8% (110) | 0.8 (876) | 64.5% (110) | 0.8 (965) | 66.4% (110) | 0.9 (960) |
| claude-haiku-5-5 | off | 47.3% (110) | 4.3 (805) | 31.8% (110) | 3.1 (903) | 29.1% (110) | 4.0 (893) |
| claude-haiku-5-5 | low | 50.0% (110) | 2.0 (866) | 42.7% (110) | 2.4 (935) | 53.6% (110) | 2.5 (970) |
| claude-haiku-5-5 | medium | 52.2% (278) | 2.0 (2,140) | 52.2% (278) | 1.8 (2,411) | 49.3% (278) | 2.1 (2,406) |
| claude-haiku-5-5 | high | 52.7% (110) | 1.5 (863) | 51.8% (110) | 1.5 (944) | 52.7% (110) | 1.6 (939) |
| claude-haiku-5-5 | xhigh | 52.7% (110) | 1.0 (877) | 55.5% (110) | 1.0 (951) | 53.6% (110) | 1.2 (922) |
| claude-haiku-5-5 | max | 50.9% (110) | 1.1 (873) | 68.2% (110) | 0.9 (1,024) | 56.4% (110) | 1.0 (914) |
| gpt-5.6-terra | low | 42.2% (90) | 3.5 (643) | 46.7% (90) | 2.9 (732) | 47.8% (90) | 3.0 (736) |
| gpt-5.6-terra | medium | 46.9% (256) | 3.0 (1,887) | 49.6% (256) | 2.6 (2,099) | 48.4% (256) | 2.4 (2,052) |
| gpt-5.6-terra | high | 50.0% (90) | 2.7 (699) | 48.9% (90) | 2.3 (732) | 50.0% (90) | 2.8 (713) |
| gpt-5.6-terra | xhigh | 56.7% (90) | 1.8 (730) | 54.4% (90) | 2.1 (783) | 53.3% (90) | 2.2 (821) |
| gpt-5.6-terra | max | 52.2% (90) | 1.3 (750) | 51.1% (90) | 1.5 (861) | 57.8% (90) | 1.5 (878) |
| gpt-6-luna | off | 30.0% (110) | 5.1 (996) | 35.5% (110) | 3.6 (1,111) | 35.5% (110) | 3.5 (1,055) |
| gpt-6-luna | low | 30.0% (110) | 4.8 (1,030) | 39.1% (110) | 4.1 (1,157) | 25.5% (110) | 4.2 (996) |
| gpt-6-luna | medium | 36.4% (272) | 4.3 (2,258) | 33.1% (272) | 3.9 (2,680) | 34.6% (272) | 3.8 (2,498) |
| gpt-6-luna | high | 52.7% (110) | 3.0 (957) | 55.5% (110) | 3.3 (1,122) | 58.2% (110) | 3.4 (1,008) |
| gpt-6-luna | xhigh | 63.6% (110) | 2.5 (991) | 60.9% (110) | 2.3 (1,047) | 69.1% (110) | 2.6 (1,046) |
| gpt-6-luna | max | 61.8% (110) | 2.2 (998) | 60.0% (110) | 2.1 (1,188) | 67.3% (110) | 2.3 (1,009) |
| claude-haiku-4-5-20251001 | off | 36.7% (90) | 6.1 (764) | 33.3% (90) | 5.3 (827) | 38.9% (90) | 6.7 (811) |
| claude-haiku-4-5-20251001 | minimal | 51.1% (90) | 5.2 (806) | 46.7% (90) | 4.2 (810) | 52.2% (90) | 4.5 (718) |
| claude-haiku-4-5-20251001 | low | 48.9% (90) | 4.7 (767) | 47.8% (90) | 4.6 (803) | 56.7% (90) | 5.4 (775) |
| claude-haiku-4-5-20251001 | medium | 46.5% (256) | 4.7 (1,990) | 38.3% (256) | 4.8 (2,114) | 40.6% (256) | 4.7 (2,016) |
| claude-haiku-4-5-20251001 | high | 51.1% (90) | 4.3 (729) | 56.7% (90) | 4.0 (833) | 41.1% (90) | 5.3 (712) |
| all |  | - | 2.6 (39,011) | - | 2.4 (44,477) | - | 2.5 (41,662) |
<!-- by-round:end -->
