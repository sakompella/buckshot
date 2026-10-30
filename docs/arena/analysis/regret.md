# Regret

How good each agent move was, by the minimax player in `sim/bend-mp/player/` ([ADR-0043](../../adr/0043-minimax-player.md)). For every agent decision the player scores each legal move from the deciding player's own information. Regret is the best move's score minus the chosen move's score. The script scores one match, every match of the analysis database split over shards, or the decisions a list names.

## How it is measured

`web/scripts/arena-regret.ts` replays each replay-validated match of the analysis database ([database.md](../database.md)) through `replayOf`, as `arena-knowledge.ts` does. Before each agent move it builds the player's input: the match configuration, the public board, and the deciding player's whole log (every public event and its own secrets, in the order it heard them). The hidden gun and other players' secrets never enter. TypeScript only marshals these values into `analyse` (through `sim/bend-mp/analysis.bend`) and reads the scores back. Forced grabs and fallback moves are not scored.

A score is the deciding player's chance of winning the current round, in millionths. Divide by 10,000 for a percentage; a regret of 10,000 is one percentage point. Opponents are modelled as minimizing it from public information.

- **Searched:** the search finished at least one depth. Regret is set, and is 0 for the best move.
- **Fallback:** no depth finished, because the node budget ran out first or the run asked for depth 0. Every move gets the same static value; the regret is NULL, never 0.
- **Invalid:** the player could not build a belief from the log; the reason is stored and there is no regret.
- **Exact:** both the best and the chosen score are 0 or 1,000,000. Only a settled round gives those scores: a win, or a loss, which a dead player's 0 always is. Treat only exact rows as solved. `exact = 0` means not proven exact, not heuristic. Take both players at 1 health with one live and one blank shell left. Shooting the other player settles the round on every path, but its score of 500,000 is a mix of a win and a loss, so the row is not marked exact. The search does not report which values are settled, and changing the evaluator is out of scope for #3.

`--reload` picks how a search values a reload it stops at ([#4](https://github.com/sakompella/buckshot/issues/4)). `static`, the default, is the static evaluation before the draw. `expected-deal` averages that evaluation over every distinct deal of the reload: the item amount, the items each seat takes, the batch and the shuffle, each answered with every value by the rules machine and weighted by its chance. Deals are counted as multisets: where items sit in the slots and the order of the shells do not tell two deals apart, since the static evaluation reads neither. `sampled` averages it over `--samples` deals (256 by default) drawn at random as the machine asks for them, so from the same distribution. The draws are seeded by the state the deal starts from, so a rerun gives the same rows. Both deal rules work at two seats only; at three or four every decision is invalid. Every rule searches the same tree and spends the same nodes, so where no line reaches a reload they give the same scores.

The exact rule is the reference and the sampled rule is the one to run over many decisions ([#17](https://github.com/sakompella/buckshot/issues/17)): on real leaves it is about 700 times faster and agrees with the exact value within its standard error (see Runtime).

## The `regret` table

The script writes to the `regret` table of the derived database named by `--out`, creating it if needed and leaving other tables alone, so it can share a file with the knowledge tables. Rows are keyed by match, ordinal, player version, depth limit, budget, reload rule and sample count. Each row is committed as it is scored, and a rerun skips the decisions already scored with the same key, so an interrupted run resumes where it stopped, and new matches are the only work left after an import. Runs with other settings sit beside it. Shards may write one file together: it is in WAL mode and each write waits up to 30 s for the other.

| Column | Meaning |
|---|---|
| `match_id`, `ordinal` | The decision, as in the analysis database's `decisions`. |
| `player`, `label` | The deciding player's letter and the move it chose. |
| `evaluator` | A hash of the compiled player. Never mix rows with different values. |
| `max_depth`, `budget` | The run's depth limit (decisions, by every player) and node budget. |
| `reload`, `samples` | `static`, `expected-deal` or `sampled`, and the deals per leaf of a sampled run (0 for the other rules). A table from before these columns (as on `main` before them) is rebuilt with every old row `static` the next time the script opens it; the viewer and the Python reports read this column, so run the script once on an older file before they read it. The reports take `--reload` (default `static`) and, for a sampled run, `--samples` (default 256), and read one run's rows. |
| `status` | `searched`, `fallback` or `invalid`. |
| `values_json` | Every legal move with its score, in the machine's order. |
| `best`, `best_score`, `chosen_score`, `regret`, `exact` | Set only when searched. Ties go to the first move. `exact` is 1 when proven exact, 0 when not proven (see above). |
| `depth`, `limited` | The depth the search finished, and whether the budget stopped it there. |
| `nodes`, `ms` | Nodes expanded and milliseconds spent on the decision. |

## Runtime

With the defaults, depth 6 and a budget of 20,000 nodes, 7 matches (352 decisions) on hp-server took 344 ms per decision on average: median 274 ms, 95th percentile 804 ms, max 1,070 ms. 39% of the searches were stopped by the budget, at depth 2 to 5. At that rate the 112,546 agent decisions take about 11 hours in one process.

The expected-deal rule is far slower, because each reload leaf enumerates the deal exactly. On 12 agent shots from finished two-seat matches, 6 with 2 shells left and 6 with 3, sampled with a fixed seed, at depth 6 and 20,000 nodes on hp-server:

- One reload leaf took 39 to 114 s, median 88 s. Nearly all of it goes to dealing the items; drawing the load and valuing the deals take about a second.
- A search reached 28 to 138 reload leaves with 2 shells left (6 to 34 distinct), and 70 to 2,053 with 3 (9 to 387 distinct).
- So one decision takes about 50 minutes to 4 hours with 2 shells left, and 1.5 to 36 hours with 3. The static rule took 5 to 305 ms on the same decisions.

Even valuing each distinct leaf once per search would leave 10 minutes to 7 hours per decision. The rule is exact but suits single positions, not a run over many decisions.

The sampled rule with 256 deals, on the same 12 decisions:

- One reload leaf took 100 to 221 ms, median 126 ms, against 39 to 128 s for the exact value.
- One decision took 3 to 16 s with 2 shells left and 10 to 251 s with 3. That is about 120 ms per reload leaf the search reaches. Leaves are not cached within a search.
- On two leaves of each decision, 24 in all, the sampled value was within one standard error of the exact one 18 times and within two 23 times. The largest gap was 2.3 standard errors. One leaf's standard error was 0.13 to 0.28 points.
- The best move was the same as under the static rule in all 12 decisions, but the scores of the moves that reach a reload changed. The sums are 32-bit floats, which differ from an exact sum by up to about 200 millionths on a full deal, well under one point.

## Reproduce

After an import, score only the new decisions: write the agent decisions with no row yet to a list (`<match id> <ordinal>` lines) and pass it to `--decisions`. Rows are keyed by the player's `evaluator` hash, and the reports refuse a file whose rows have several. When the player's source has changed since the old rows were scored, rebuild the old player (the same Bend release on the `sim/bend-mp/analysis.bend` of the commit that scored them, in a detached worktree) and score the new decisions with it, or rescore everything. The 2026-10-30 refresh did the first: the old rows' hash `a3962092b561cfb4` is Bend 2.0.36 on `sim/bend-mp/analysis.bend` at commit `03978b0`, and the 62 new matches were scored by that commit's own `arena-regret.ts`.

From `web/`, after `bun run rules`:

    nice -n 10 bun scripts/arena-regret.ts --db <buckshot.sqlite> --out <derived>.sqlite --match <match name> [--depth 6] [--budget 20000] [--reload static] [--samples 256]
    nice -n 10 bun scripts/arena-regret.ts --db <buckshot.sqlite> --out <derived>.sqlite --all [--shard K/N] [--depth 6] [--budget 20000] [--reload static] [--samples 256]
    nice -n 10 bun scripts/arena-regret.ts --db <buckshot.sqlite> --out <derived>.sqlite --decisions <list> [--depth 6] [--budget 20000] [--reload static] [--samples 256]

`--decisions` takes a text file with one `<match id> <ordinal>` line per decision, the ids of the analysis database. Each must be an agent decision of a replay-validated match, or the script stops before scoring. `--all` takes every replay-validated match in tournament and match name order. `--shard K/N` (K from 1) keeps every Nth match, so N processes can run side by side on one `--out` file. A match that fails is logged and skipped, the shard exits 1 at the end, and a rerun retries it. Progress is one stderr line per match.

`web/test/regret.test.ts` checks known positions: a forced win, a certain loss, a round-ending shot, the fallback, and another player's secret. It also runs the script on recorded matches that reach a forced win and a certain loss, and checks the stored rows, on a faux match imported from an arena run, and on two shards writing one file.

The summary tables below come from the regret and knowledge databases, read only, in a few seconds:

    python3 tools/arena/analysis/regret.py [--regret <derived>/regret.sqlite] [--knowledge <derived>/knowledge.sqlite] [--doc docs/arena/analysis/regret.md]

With `--doc` it rewrites the tables at the end of this page. `tools/arena/analysis/reload_bias.py` draws the stratified lists for `--decisions` (`sample`) and rewrites the tables of the Reload bias section from a `sampled` run (`report --doc`), reading the sampled and static runs read only. The by-round tables come from `tools/arena/analysis/by_round.py`, which also reads the analysis database for round winners (`--db`) and rewrites the tables of the last section the same way. `tools/arena/analysis/regret_depth.py` does the same for the Deeper search section: `sample` draws the lists, to run with `--depth 8 --budget 200000`, and `report --doc` rewrites its tables from the deep run (`regret-depth.sqlite`). `python3 -m unittest discover -s tools/arena/analysis` runs its tests.

`bun scripts/arena-regret-consistency.ts <derived>/regret.sqlite`, from `web/`, checks every searched row of every run, read only: `values_json` decodes, its top score is `best_score`, the chosen move is in it with `chosen_score`, and `regret` is `best_score` minus `chosen_score`. It prints the count of each mismatch and fails on any. The viewer's replay reads the same rows and refuses a match with a malformed one.

## Results

Scope: 2,533 scored matches with no DeepSeek seat, from the 2,553-match snapshot of 2026-10-30. This is a casual pass over the full run, with counts and means and no intervals. It covers the 128,332 agent decisions of those matches (DeepSeek is left out as in [matchups.md](matchups.md)). Every one has a row, every row was searched, and none fell back. The 129,998 rows of the run also hold DeepSeek's matches and unfinished ones. All rows come from one player build (see Reproduce). A config is a model with its effort, pooled over the tournaments it played in. Regret is in percentage points of the round win chance, as above. Mean regret over all decisions is 2.4 points and the 90th percentile 6.7. 10.8% of the decisions are exact.

1. **Regret and the ratings agree at the ends.**
   - At medium effort the mean regret is Opus 1.1, Sol 1.4, Astra 1.4, Haiku 5.5 1.9, Sonnet 2.0, Terra 2.7, Luna 4.0 and Haiku 4.5 4.8 points. Terra 6.1 (new, 323 decisions) is 2.4.
   - The cross-model ratings in [matchups.md](matchups.md) put the same three on top (Astra first) and Luna and Haiku 4.5 at the bottom, in the other order. The five in between overlap in rating, and regret does not separate them further. Regret uses no match results, so it agrees from the other side.
2. **More effort mostly lowers regret. Sol and Opus barely move.**
   - Haiku 5.5 goes from 3.8 at off to 1.0 at max, Sonnet from 2.3 to 0.8, Luna from 4.0 to 2.2, Terra from 3.1 at low to 1.5 at max. Haiku 4.5 moves less, from 6.0 at off to 4.5 at high. The steps are not always in order: Luna is 4.0 at off and 4.4 at low. The 90th percentile falls with it: Haiku 5.5 10.4 to 3.2, Sonnet 7.2 to 2.6.
   - Sol (1.2 to 1.5) and Opus from off to xhigh (1.0 to 1.2) change by 0.3 points or less. Opus max, new in tournament 5 with 209 decisions from 8 matches, is 0.6, the lowest cell of the table. Sol is flat in the rating sweep too. Opus is not: its xhigh rating is far above its low, yet its regret moves by 0.2 points. Regret does not explain that gap.

**Near reloads (for [#4](https://github.com/sakompella/buckshot/issues/4)).** Regret concentrates in shots with two or three shells left in the gun.
- Those shots average 4.7 and 4.0 points, with a 90th percentile of 15.3 and 13.2. A shot with one shell left averages 1.8 and one with five left 2.0.
- Item moves stay between 1.7 and 2.3 at every distance. In this cut they show no sign of a reload effect.
- The node budget does not explain the rise. It stopped 6% and 28% of the searches with two and three shells left, against 0.1% at one shell left.
- This shows where regret is, not why. A shot with two left ends the search at the reload one shot later, so the static leaf is a possible cause. Real mistakes on near-even shells are another. The table cannot tell them apart, which is what #4 measures. The Reload bias section below has the answer.

## Reload bias

This section and Deeper search measure fixed samples drawn from the 2026-10-26 run of 125,150 decisions (tournaments 1 to 4). They were not redrawn for tournament 5, and their sizes and weights below are that run's.

This measures the bias of the static leaf near reloads ([#4](https://github.com/sakompella/buckshot/issues/4), [#17](https://github.com/sakompella/buckshot/issues/17)). 2,853 agent decisions of the run above were scored again with the `sampled` rule (64 deals per leaf, depth 6, 20,000 nodes) and set beside the static score of the same decision, matched by match, ordinal, depth and budget. The sample covers two-seat matches only, with no DeepSeek seat, and is stratified by shells left in the gun, shot or item move, and model. The means below weight each stratum by its size in the whole run of 125,150 decisions, and the intervals are 95%. Both rules search the same tree, so every difference comes from the leaf. On 38 decisions scored with 256 deals as well, 64 deals gave a similar mean regret to 256, 0.04 ± 0.07 points more. That is a mean over 38 decisions. It does not show that the two agree on every chosen move or in the tail. The exact rule of #4 takes hours per decision (see Runtime), so this uses the sampled rule, which matched the exact value on 24 leaves within noise. It is still the static evaluation after a drawn deal and not the truth. Lower regret under it means the static leaf and the draw disagree, and the draw sees more.

1. **A reload is in reach for most decisions.**
   - In 78.7% of all decisions the gun holds no more shells than the depth the static search reached, so some line of the search empties it. Shots and item moves with 1 to 3 shells left are always in reach. With 6 left, 9% of shots and 0.5% of item moves are.
   - Where none is in reach the two rules gave the same scores in all 222 sampled decisions. Where one is, a score changed in 2,379 of 2,631 sampled decisions (90%). Over all decisions the best move changed in 11%.
2. **The static leaf overstates regret near reloads, by about 0.4 points overall.**
   - Mean regret falls from 2.50 to 2.07 points (-0.43 ± 0.08). With 3 or fewer shells left it falls by 0.64 ± 0.12 from 2.73, and with 4 or more by 0.16 ± 0.10 from 2.19.
   - The largest cell is shots with 2 shells left, from 4.59 to 3.35 (-1.24 ± 0.35), and the best move changes in 17%. Item moves with 2 left fall from 1.73 to 0.94 (-0.79 ± 0.22). Shots overall move by -0.46 ± 0.12 and item moves by -0.40 ± 0.11, so item moves are not the main victim.
   - About half of the extra regret that 2-shell shots show over 1-shell shots is the leaf (2.21 static, 1.18 sampled). The other half stays, so the leaf does not explain the bump on its own.
3. **Model rankings hold.** Every model's mean regret falls by 0.3 to 0.6 points. The order is the same except that the top two, Opus and Sol, swap (1.19 and 1.22 static, 0.86 and 0.84 sampled), a gap within noise.
4. **Moves that spend an item score lower under the sampled rule, and shots at the opponent higher.** Over the sampled moves whose score changed, unweighted, the mean shift is -2.6 points for steals, -2.0 for cigarettes, -1.8 for the magnifying glass, -1.2 for beer, -0.7 for the handsaw and -0.2 for the inverter, and +0.3 for shooting the opponent. The shift does not follow the item weights of the evaluation. Beer, at 25, moves more than the handsaw, at 65. So a term for the value of coming items would not obviously recover it.

**Recommendation.** Keep the static leaf as the default.
- The bias shows below 4 shells left, but it does not change which models look good. The guess that item moves are the most affected is not borne out, since shots are as affected.
- Do not add an expected item value to the leaf. Nothing here says that term is the missing part, and the shifts above do not track item weights.
- Do not search the draws over the whole run. The sampled rule took 27.6 s per decision on average over this sample against 0.24 s static. Weighted to the run, that is about 1,000 hours in one process, about 170 for the 43,069 decisions with 2 or fewer shells left.
- When a number for decisions with 1 to 3 shells left is quoted, read static regret as high by 0.6 points on average over 1 to 3 shells left. The gap is 0.2 to 0.4 at 1 shell, 0.8 to 1.2 at 2 and 0.5 to 0.6 at 3. Or score that subset with `--reload sampled`.

<!-- reload-bias:start -->
2,853 decisions scored under both rules, drawn from the run's 125,150. 0 searched a different tree under the two rules.
A score changed in 2,379 of 2,631 scored decisions where the gun held no more shells than the static search finished decisions, and in 0 of 222 where it held more.
On 38 decisions scored with 256 samples as well, mean regret with 64 minus with 256 is +0.04 ± 0.07 points.

### By shells left in the gun

| kind | shells left | decisions | reload within depth | scored | score changed | static regret | sampled regret | sampled minus static | best move changed |
|---|---|---|---|---|---|---|---|---|---|
| shot | 1 | 13,361 | 100.0% | 303 | 96.9% | 2.38 | 2.17 | -0.22 ± 0.29 | 19.3% |
| shot | 2 | 13,018 | 100.0% | 553 | 90.9% | 4.59 | 3.35 | -1.24 ± 0.35 | 17.1% |
| shot | 3 | 12,592 | 100.0% | 553 | 91.5% | 3.45 | 2.87 | -0.58 ± 0.24 | 13.1% |
| shot | 4 | 9,969 | 96.1% | 217 | 80.0% | 2.47 | 2.45 | -0.02 ± 0.27 | 10.8% |
| shot | 5 | 6,868 | 62.6% | 118 | 48.0% | 2.78 | 2.60 | -0.18 ± 0.22 | 1.6% |
| shot | 6 | 3,928 | 9.4% | 52 | 6.3% | 4.10 | 4.10 | +0.00 ± 0.01 | 0.0% |
| shot | all | 59,736 | 89.1% | 1,796 | 80.1% | 3.26 | 2.80 | -0.46 ± 0.12 | 12.8% |
| item move | 1 | 5,923 | 100.0% | 203 | 100.0% | 2.22 | 1.82 | -0.40 ± 0.45 | 14.3% |
| item move | 2 | 10,767 | 100.0% | 353 | 94.2% | 1.73 | 0.94 | -0.79 ± 0.22 | 13.8% |
| item move | 3 | 15,190 | 100.0% | 244 | 93.2% | 1.78 | 1.24 | -0.54 ± 0.29 | 21.3% |
| item move | 4 | 13,997 | 77.5% | 129 | 52.0% | 1.70 | 1.22 | -0.48 ± 0.31 | 5.2% |
| item move | 5 | 11,602 | 21.5% | 83 | 13.6% | 1.81 | 1.76 | -0.05 ± 0.11 | 0.4% |
| item move | 6 | 7,935 | 0.5% | 45 | 0.0% | 1.80 | 1.80 | +0.00 ± 0.00 | 0.0% |
| item move | all | 65,414 | 69.2% | 1,057 | 59.7% | 1.80 | 1.40 | -0.40 ± 0.11 | 9.7% |

### By model

| model | scored | static regret | rank | sampled regret | rank |
|---|---|---|---|---|---|
| claude-opus-5-5 | 347 | 1.19 | 1 | 0.86 | 2 |
| gpt-6.1-sol | 348 | 1.22 | 2 | 0.84 | 1 |
| gpt-5.6-terra | 365 | 1.84 | 3 | 1.40 | 3 |
| gpt-6-astra | 359 | 1.94 | 4 | 1.44 | 4 |
| claude-sonnet-5-5 | 355 | 2.03 | 5 | 1.62 | 5 |
| claude-haiku-5-5 | 360 | 2.20 | 6 | 1.87 | 6 |
| gpt-6-luna | 358 | 3.34 | 7 | 2.84 | 7 |
| claude-haiku-4-5-20251001 | 361 | 5.19 | 8 | 4.60 | 8 |
<!-- reload-bias:end -->

## Deeper search

This checks whether regret holds up when the search goes deeper. 40% of the production searches (depth 6, 20,000 nodes) stop on the budget before depth 6. 2,880 agent decisions of the run above were scored again at depth 8 with 200,000 nodes, ten times the budget, under the static reload rule. Each is set beside the production score of the same decision, matched by match and ordinal. The sample covers two-seat matches with no DeepSeek seat and is stratified by shells left in the gun, shot or item move, and model. As in the reload-bias run, the means weight each stratum by its size in the whole run of 125,150 decisions. The intervals are 95% normal intervals over decisions, stratified, for this fixed run only. They leave out variation between matches, seed blocks and tournaments, so they do not say how the numbers would move on new matches. The new build rescored 120 of the decisions at depth 6 and 20,000 nodes, and every score, node count and depth matched the production rows. The deep run took 3.3 CPU hours, 4.1 s per decision on average against 0.34 s for production. Both searches use the static leaf, so this tests the horizon only. It does not test the leaf, which the Reload bias section does.

1. **The chosen best move's label changes in 13.0 ± 1.2% of decisions, mostly with 4 or more shells left.**
   - With 3 or fewer shells left it changes in 3.8% of decisions, and with 4 or more in 25.0%. With 1 or 2 shells left almost nothing changes, since the reload ends every line within depth 6.
   - Item moves change most: 16% of those with 3 shells left, 29% with 4, 34% with 5 and 37% with 6. Shots with 4 to 6 left change in 11% to 15%.
   - In 8.9% of decisions the deep search scores the production search's chosen best move strictly lower than its own best move, by 3.0 points on average. In the other 4.1% the old chosen best move ties the deep best, so only the label switched. This compares chosen labels, not the sets of tied best moves, so it does not show whether either set changed.
2. **Mean regret moves little in this sample.**
   - It goes from 2.56 to 2.63 points (+0.07 ± 0.10). An interval that holds zero does not show the means are equal. Shots change by +0.18 ± 0.12 and item moves by -0.04 ± 0.15. The share of agent moves with zero regret is 64.8% at depth 6 and 66.4% at depth 8.
   - Single decisions move more than the mean does. 13.4% change by at least a point, 6.6% up and 6.8% down, so they cancel.
   - No cell by shells left moves outside its interval except shots with 5 left (+0.52 ± 0.38), one of 12 cells. Decisions whose production search stopped on the budget change by +0.16 ± 0.23, and those that reached depth 6 by +0.01 ± 0.06. These two means weight each limit status by its own size in each stratum.
3. **The sample's model order is the same at both depths.** All eight models keep their rank in the point estimates. The intervals overlap for neighbours, so this is no proof that the order is stable: rank uncertainty was not computed. Each mean moves by 0.07 points or less, except Haiku 4.5, which rises by 0.51 ± 0.31 from 6.05 to 6.56. The top two are Astra and Opus at 1.09 and 1.12, as close as before.
4. **The budget still stops 30% of the searches, most of them with many shells left.** The population-weighted estimate for this fixed run is 29.9% budget-limited at depth 8, against 40.2% at depth 6.
   - Shots with 1 to 3 shells left are stopped in under 7% of searches, with 4 left in 22.5%, with 5 left in 43.6% and with 6 left in 75.6%. Item moves are stopped in 24% with 3 left, 50% with 4, 84% with 5 and 95% with 6.
   - The searches gain 2.0 decisions of depth on average. With 5 or 6 shells left most still end before depth 8, so those rows compare horizons of about 6 and 7.

**Reading it.** In this fixed run, depth 8 with ten times the budget gives similar mean regrets and the same observed model order as the production run. Depth and budget changed together and the budget still stops 30% of the searches, so this does not separate their effects, show that regret is free of the node budget, or show that the ranking would hold on new matches. Production keeps depth 6 with 20,000 nodes as the cheaper setting, not as a setting shown to be sufficient. A single item move with 4 or more shells left is another matter. Its best move changes in a third of cases under a deeper search, so read its regret as a mean over many decisions, never as a verdict on one.

<!-- regret-depth:start -->
2,880 decisions scored at depth 8 with 200,000 nodes and at depth 6 with 20,000, drawn from the run's 125,150.
Over the run the chosen best move's label changes in 13.0% of decisions, and in 8.9% the deep search scores the old chosen best move strictly lower than its own. Mean regret goes from 2.56 to 2.63 points (+0.07 ± 0.10).
The budget still stops 29.9% of the depth 8 searches, against 40.2% at depth 6.

### By shells left in the gun

| kind | shells left | decisions | scored | depth 6 limited | depth 8 limited | extra depth | regret at 6 | regret at 8 | 8 minus 6 | best label changed | chosen best strictly worse at 8 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| shot | 1 | 13,361 | 140 | 0.0% | 0.0% | 2.00 | 1.40 | 1.40 | +0.00 ± 0.00 | 0.0% | 0.0% |
| shot | 2 | 13,018 | 200 | 2.2% | 0.7% | 2.02 | 6.15 | 6.15 | +0.00 ± 0.00 | 0.0% | 0.0% |
| shot | 3 | 12,592 | 280 | 12.1% | 6.4% | 2.06 | 4.62 | 4.83 | +0.21 ± 0.41 | 1.4% | 0.2% |
| shot | 4 | 9,969 | 280 | 33.7% | 22.5% | 2.10 | 2.89 | 3.30 | +0.41 ± 0.42 | 11.0% | 8.1% |
| shot | 5 | 6,868 | 280 | 71.7% | 43.6% | 2.21 | 1.62 | 2.14 | +0.52 ± 0.38 | 15.1% | 13.1% |
| shot | 6 | 3,928 | 260 | 89.7% | 75.6% | 2.05 | 1.80 | 1.94 | +0.14 ± 0.38 | 11.5% | 11.1% |
| shot | all | 59,736 | 1,440 | 22.8% | 15.2% | 2.06 | 3.41 | 3.60 | +0.18 ± 0.12 | 4.6% | 3.6% |
| item move | 1 | 5,923 | 140 | 0.0% | 0.0% | 2.00 | 2.59 | 2.59 | +0.00 ± 0.00 | 0.0% | 0.0% |
| item move | 2 | 10,767 | 200 | 10.5% | 4.5% | 2.08 | 1.30 | 1.39 | +0.09 ± 0.14 | 0.5% | 0.0% |
| item move | 3 | 15,190 | 280 | 42.1% | 23.8% | 2.21 | 1.39 | 1.39 | +0.00 ± 0.29 | 16.2% | 6.9% |
| item move | 4 | 13,997 | 280 | 73.3% | 50.1% | 2.21 | 1.87 | 1.74 | -0.13 ± 0.41 | 29.1% | 21.9% |
| item move | 5 | 11,602 | 280 | 95.3% | 83.6% | 1.92 | 2.27 | 2.27 | +0.01 ± 0.49 | 34.4% | 26.1% |
| item move | 6 | 7,935 | 260 | 99.4% | 95.0% | 1.54 | 1.69 | 1.47 | -0.21 ± 0.40 | 37.2% | 23.6% |
| item move | all | 65,414 | 1,440 | 56.1% | 43.3% | 2.04 | 1.78 | 1.74 | -0.04 ± 0.15 | 20.7% | 13.8% |

### By how the production search ended

| production search | scored | regret at 6 | regret at 8 | 8 minus 6 | best label changed | depth 8 limited |
|---|---|---|---|---|---|---|
| reached depth 6 | 1,445 | 2.75 | 2.75 | +0.01 ± 0.06 | 0.8% | 0.0% |
| stopped by the budget | 1,435 | 2.27 | 2.43 | +0.16 ± 0.23 | 31.4% | 75.0% |

### By model

| model | scored | regret at 6 | rank | regret at 8 | rank | 8 minus 6 |
|---|---|---|---|---|---|---|
| gpt-6-astra | 362 | 1.16 | 1 | 1.09 | 1 | -0.07 ± 0.25 |
| claude-opus-5-5 | 358 | 1.18 | 2 | 1.12 | 2 | -0.06 ± 0.19 |
| gpt-6.1-sol | 358 | 1.50 | 3 | 1.45 | 3 | -0.05 ± 0.23 |
| claude-sonnet-5-5 | 362 | 1.62 | 4 | 1.58 | 4 | -0.04 ± 0.20 |
| claude-haiku-5-5 | 358 | 1.82 | 5 | 1.87 | 5 | +0.05 ± 0.32 |
| gpt-5.6-terra | 362 | 2.31 | 6 | 2.38 | 6 | +0.07 ± 0.28 |
| gpt-6-luna | 362 | 3.47 | 7 | 3.52 | 7 | +0.04 ± 0.24 |
| claude-haiku-4-5-20251001 | 358 | 6.05 | 8 | 6.56 | 8 | +0.51 ± 0.31 |
<!-- regret-depth:end -->

## Limits

- The value is the chance of winning the round, not the match's cash.
- Reloads are leaves: with the default rule a move that empties the gun is valued before the next load is drawn. The expected-deal rule averages over the deal, but still stops at the next choice.
- The static evaluation's item weights are untrained starting values, so heuristic regrets carry its biases. Read small regrets with care.
- Regret is a mean over decisions, not over matches. Decisions of one match are not independent, and a config's opponents differ between tournaments. Treat gaps of a few tenths of a point as noise.
- The intervals in Deeper search cover only the sampled decisions of this fixed run. They do not cover matches, seed blocks, tournaments or future play.
- A regret of 0 means the chosen move tied the best score at the depth reached, not that it was proven right. Only the 11% of exact rows are.
- 40% of the searches were stopped by the budget at depth 1 to 5. With four or more shells left most are, so those rows compare shallower searches. A search to depth 8 with ten times the budget gives similar mean regrets and the same observed model order in a sample of this run (Deeper search), but still stops 30% of the time.

## Tables

<!-- tables:start -->
128,332 searched decisions; 0 left out for having no search; 0 agent decisions with no row.

### Regret by config

| model | effort | decisions | mean regret | 90th percentile | exact |
|---|---|---|---|---|---|
| claude-opus-5-5 | off | 186 | 1.2 | 3.2 | 12.4% |
| claude-opus-5-5 | low | 795 | 1.2 | 3.8 | 10.2% |
| claude-opus-5-5 | medium | 6,312 | 1.1 | 3.5 | 12.1% |
| claude-opus-5-5 | high | 1,198 | 1.1 | 3.9 | 8.8% |
| claude-opus-5-5 | xhigh | 2,024 | 1.0 | 3.4 | 11.6% |
| claude-opus-5-5 | max | 209 | 0.6 | 2.7 | 17.2% |
| gpt-6-astra | low | 146 | 1.4 | 4.3 | 11.6% |
| gpt-6-astra | medium | 5,393 | 1.4 | 3.9 | 13.1% |
| gpt-6-astra | high | 125 | 0.8 | 2.9 | 16.0% |
| gpt-6.1-sol | low | 2,085 | 1.5 | 4.6 | 11.4% |
| gpt-6.1-sol | medium | 6,611 | 1.4 | 4.3 | 12.3% |
| gpt-6.1-sol | high | 2,199 | 1.3 | 4.5 | 12.0% |
| gpt-6.1-sol | xhigh | 2,346 | 1.2 | 4.2 | 12.5% |
| gpt-6.1-sol | max | 2,379 | 1.4 | 4.6 | 12.6% |
| claude-sonnet-5-5 | off | 2,715 | 2.3 | 7.2 | 11.3% |
| claude-sonnet-5-5 | low | 2,654 | 2.2 | 6.6 | 11.3% |
| claude-sonnet-5-5 | medium | 6,890 | 2.0 | 6.0 | 12.4% |
| claude-sonnet-5-5 | high | 2,729 | 1.7 | 5.3 | 11.0% |
| claude-sonnet-5-5 | xhigh | 2,719 | 1.0 | 3.6 | 12.5% |
| claude-sonnet-5-5 | max | 2,801 | 0.8 | 2.6 | 15.5% |
| gpt-6.1-terra | off | 132 | 2.2 | 5.9 | 15.2% |
| gpt-6.1-terra | low | 174 | 2.0 | 7.0 | 13.2% |
| gpt-6.1-terra | medium | 323 | 2.4 | 6.8 | 13.6% |
| gpt-6.1-terra | high | 185 | 1.4 | 5.2 | 5.9% |
| gpt-6.1-terra | xhigh | 196 | 1.4 | 4.4 | 8.2% |
| gpt-6.1-terra | max | 143 | 1.4 | 5.1 | 11.2% |
| claude-haiku-5-5 | off | 2,601 | 3.8 | 10.4 | 8.0% |
| claude-haiku-5-5 | low | 2,826 | 2.3 | 6.2 | 9.8% |
| claude-haiku-5-5 | medium | 6,992 | 1.9 | 5.3 | 11.7% |
| claude-haiku-5-5 | high | 2,782 | 1.5 | 4.4 | 10.4% |
| claude-haiku-5-5 | xhigh | 2,750 | 1.1 | 3.6 | 12.2% |
| claude-haiku-5-5 | max | 2,811 | 1.0 | 3.2 | 12.9% |
| gpt-5.6-terra | low | 2,111 | 3.1 | 9.7 | 9.9% |
| gpt-5.6-terra | medium | 6,038 | 2.7 | 7.7 | 10.5% |
| gpt-5.6-terra | high | 2,144 | 2.6 | 8.0 | 11.0% |
| gpt-5.6-terra | xhigh | 2,334 | 2.0 | 5.9 | 10.6% |
| gpt-5.6-terra | max | 2,489 | 1.5 | 4.3 | 9.8% |
| gpt-6-luna | off | 3,162 | 4.0 | 11.8 | 7.1% |
| gpt-6-luna | low | 3,183 | 4.4 | 13.2 | 8.9% |
| gpt-6-luna | medium | 7,539 | 4.0 | 12.2 | 8.8% |
| gpt-6-luna | high | 3,087 | 3.2 | 10.2 | 11.5% |
| gpt-6-luna | xhigh | 3,144 | 2.5 | 6.9 | 13.3% |
| gpt-6-luna | max | 3,195 | 2.2 | 6.3 | 12.3% |
| claude-haiku-4-5-20251001 | off | 2,402 | 6.0 | 17.6 | 6.3% |
| claude-haiku-4-5-20251001 | minimal | 2,334 | 4.6 | 13.6 | 6.6% |
| claude-haiku-4-5-20251001 | low | 2,345 | 4.9 | 15.1 | 8.5% |
| claude-haiku-4-5-20251001 | medium | 6,120 | 4.8 | 14.2 | 7.5% |
| claude-haiku-4-5-20251001 | high | 2,274 | 4.5 | 12.3 | 8.2% |
| all |  | 128,332 | 2.4 | 6.7 | 10.8% |

### Regret by shells left in the gun

| shells left | stopped by budget | shots | mean | 90th percentile | item moves | mean | 90th percentile |
|---|---|---|---|---|---|---|---|
| 1 | 0.1% | 13,712 | 1.8 | 3.4 | 6,083 | 1.9 | 6.6 |
| 2 | 6.1% | 13,352 | 4.7 | 15.3 | 11,032 | 1.7 | 5.4 |
| 3 | 27.7% | 12,903 | 4.0 | 13.2 | 15,556 | 1.7 | 5.2 |
| 4 | 56.6% | 10,205 | 2.7 | 8.2 | 14,354 | 1.8 | 5.4 |
| 5 | 85.0% | 7,045 | 2.0 | 7.1 | 11,913 | 2.0 | 5.1 |
| 6 | 96.6% | 4,025 | 1.8 | 5.2 | 8,152 | 2.3 | 4.5 |
<!-- tables:end -->

## By round

Does a model play the short early rounds differently from the later, item-heavy ones? This is a casual pass for [#14](https://github.com/sakompella/buckshot/issues/14), with counts in brackets and no intervals. It covers the same 2,533 finished matches with no DeepSeek seat. Round winners come from the public lines of the match events, as the viewer reads them; the last round's winner is inferred from final cash when its line is missing. Rounds are numbered from 1. A win rate is the share of its rounds a config won, against whoever it met, so it also reflects the opponents' strength.

1. **No config's win rate clearly changes by round.**
   - Pooled over efforts, a model's win rate moves by 4 points or less between rounds for seven of the nine models. Astra goes from 58.0% to 61.9% and 62.8% over 231 rounds, Terra 6.1 from 45.5% to 50.0% over 44, and Haiku 4.5 from 46.8% to 42.9% and back to 44.5% over 616.
   - Per config the cells hold 4 to 280 rounds, so gaps of 10 points are common at 110 rounds and say little, and Terra 6.1's cells (4 to 12 rounds) say almost nothing. The largest runs are Haiku 5.5 off, at 47.3%, 31.8% and 29.1% over 110 rounds each, and Haiku 5.5 max at 50.9%, 68.2% and 56.4%. Neither is a steady trend across the other efforts.
2. **Regret is flat across rounds, except that round 1 shots are a little worse.**
   - Mean regret over all moves is 2.5, 2.3 and 2.4 points in rounds 1, 2 and 3. In every round the same three, Opus, Astra and Sol, are lowest and Haiku 4.5 is highest.
   - Shots cost 3.3 points in round 1 against 2.8 and 3.0 later. Item moves stay at 1.8 to 1.9. The table does not say why. Decisions of one match are not independent, so the gap is small evidence.
   - Round 3 is often a dead rubber, since prizes are 70k, 75k and 80k and a 2-0 lead settles the winner. No table here splits round 3 regret by the lead; an earlier one-off check of that was not scripted and is removed.

<!-- by-round:start -->
7,599 rounds of finished matches; 0 matches left out because their round winners did not match the final cash.

### Win rate and regret by round, per model

| model | effort | round 1 win rate | round 1 mean regret | round 2 win rate | round 2 mean regret | round 3 win rate | round 3 mean regret |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 | all | 55.0% (429) | 1.0 (3,468) | 54.8% (429) | 1.1 (3,746) | 52.7% (429) | 1.2 (3,510) |
| gpt-6-astra | all | 58.0% (231) | 1.5 (1,802) | 61.9% (231) | 1.2 (1,965) | 62.8% (231) | 1.4 (1,897) |
| gpt-6.1-sol | all | 53.6% (632) | 1.3 (4,773) | 55.1% (632) | 1.4 (5,690) | 53.2% (632) | 1.4 (5,157) |
| claude-sonnet-5-5 | all | 50.8% (836) | 1.9 (6,190) | 50.6% (836) | 1.7 (7,537) | 51.9% (836) | 1.6 (6,781) |
| gpt-6.1-terra | all | 45.5% (44) | 1.8 (400) | 47.7% (44) | 2.0 (356) | 50.0% (44) | 1.8 (397) |
| claude-haiku-5-5 | all | 51.2% (834) | 2.0 (6,474) | 50.8% (834) | 1.8 (7,214) | 48.8% (834) | 2.1 (7,074) |
| gpt-5.6-terra | all | 48.9% (616) | 2.6 (4,709) | 50.0% (616) | 2.4 (5,207) | 50.6% (616) | 2.3 (5,200) |
| gpt-6-luna | all | 43.8% (828) | 3.8 (7,270) | 44.3% (828) | 3.3 (8,345) | 45.5% (828) | 3.4 (7,695) |
| claude-haiku-4-5-20251001 | all | 46.8% (616) | 4.9 (5,056) | 42.9% (616) | 4.6 (5,387) | 44.5% (616) | 5.2 (5,032) |
| all |  | - | 2.5 (40,142) | - | 2.3 (45,447) | - | 2.4 (42,743) |

### Mean regret by round and kind of move

| round | all moves | shots | item moves |
|---|---|---|---|
| 1 | 2.5 (40,142) | 3.3 (19,720) | 1.8 (20,422) |
| 2 | 2.3 (45,447) | 2.8 (21,358) | 1.9 (24,089) |
| 3 | 2.4 (42,743) | 3.0 (20,164) | 1.9 (22,579) |

### Win rate and regret by round, per config

| model | effort | round 1 win rate | round 1 mean regret | round 2 win rate | round 2 mean regret | round 3 win rate | round 3 mean regret |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 | off | 62.5% (8) | 1.3 (86) | 37.5% (8) | 1.7 (46) | 75.0% (8) | 0.7 (54) |
| claude-opus-5-5 | low | 47.1% (34) | 1.4 (261) | 64.7% (34) | 1.2 (293) | 50.0% (34) | 0.9 (241) |
| claude-opus-5-5 | medium | 56.5% (248) | 1.1 (2,023) | 55.2% (248) | 1.1 (2,200) | 52.0% (248) | 1.3 (2,089) |
| claude-opus-5-5 | high | 48.0% (50) | 1.0 (350) | 54.0% (50) | 1.0 (450) | 42.0% (50) | 1.2 (398) |
| claude-opus-5-5 | xhigh | 56.8% (81) | 0.9 (666) | 50.6% (81) | 1.1 (703) | 56.8% (81) | 1.0 (655) |
| claude-opus-5-5 | max | 62.5% (8) | 0.7 (82) | 62.5% (8) | 0.7 (54) | 87.5% (8) | 0.5 (73) |
| gpt-6-astra | low | 50.0% (8) | 1.5 (49) | 50.0% (8) | 1.5 (57) | 50.0% (8) | 1.1 (40) |
| gpt-6-astra | medium | 58.4% (219) | 1.5 (1,724) | 62.6% (219) | 1.2 (1,872) | 62.6% (219) | 1.4 (1,797) |
| gpt-6-astra | high | 50.0% (4) | 1.1 (29) | 50.0% (4) | 0.4 (36) | 100.0% (4) | 0.8 (60) |
| gpt-6.1-sol | low | 53.3% (90) | 1.3 (649) | 47.8% (90) | 1.9 (766) | 48.9% (90) | 1.4 (670) |
| gpt-6.1-sol | medium | 55.6% (266) | 1.5 (2,144) | 60.5% (266) | 1.4 (2,326) | 53.4% (266) | 1.4 (2,141) |
| gpt-6.1-sol | high | 53.3% (90) | 1.4 (644) | 48.9% (90) | 1.2 (878) | 44.4% (90) | 1.4 (677) |
| gpt-6.1-sol | xhigh | 48.9% (94) | 1.2 (684) | 50.0% (94) | 1.3 (838) | 58.5% (94) | 1.2 (824) |
| gpt-6.1-sol | max | 53.3% (92) | 1.0 (652) | 57.6% (92) | 1.6 (882) | 59.8% (92) | 1.4 (845) |
| claude-sonnet-5-5 | off | 50.9% (112) | 2.4 (823) | 39.3% (112) | 2.4 (1,007) | 46.4% (112) | 2.0 (885) |
| claude-sonnet-5-5 | low | 46.4% (112) | 2.4 (738) | 35.7% (112) | 2.0 (994) | 44.6% (112) | 2.2 (922) |
| claude-sonnet-5-5 | medium | 45.3% (278) | 2.4 (2,027) | 54.3% (278) | 1.9 (2,534) | 53.6% (278) | 1.8 (2,329) |
| claude-sonnet-5-5 | high | 50.9% (112) | 1.8 (860) | 55.4% (112) | 1.6 (1,047) | 45.5% (112) | 1.7 (822) |
| claude-sonnet-5-5 | xhigh | 58.0% (112) | 1.1 (866) | 49.1% (112) | 1.1 (990) | 52.7% (112) | 0.8 (863) |
| claude-sonnet-5-5 | max | 61.8% (110) | 0.8 (876) | 64.5% (110) | 0.8 (965) | 66.4% (110) | 0.9 (960) |
| gpt-6.1-terra | off | 33.3% (6) | 2.6 (42) | 66.7% (6) | 1.8 (53) | 33.3% (6) | 2.2 (37) |
| gpt-6.1-terra | low | 66.7% (6) | 1.6 (54) | 50.0% (6) | 1.9 (48) | 66.7% (6) | 2.4 (72) |
| gpt-6.1-terra | medium | 41.7% (12) | 2.7 (99) | 41.7% (12) | 2.5 (102) | 75.0% (12) | 1.9 (122) |
| gpt-6.1-terra | high | 37.5% (8) | 1.2 (65) | 37.5% (8) | 2.0 (55) | 25.0% (8) | 1.2 (65) |
| gpt-6.1-terra | xhigh | 37.5% (8) | 1.3 (73) | 37.5% (8) | 1.4 (57) | 37.5% (8) | 1.6 (66) |
| gpt-6.1-terra | max | 75.0% (4) | 1.5 (67) | 75.0% (4) | 1.7 (41) | 50.0% (4) | 0.8 (35) |
| claude-haiku-5-5 | off | 47.3% (110) | 4.3 (805) | 31.8% (110) | 3.1 (903) | 29.1% (110) | 4.0 (893) |
| claude-haiku-5-5 | low | 50.9% (112) | 2.0 (886) | 42.9% (112) | 2.4 (956) | 52.7% (112) | 2.4 (984) |
| claude-haiku-5-5 | medium | 52.1% (280) | 2.0 (2,155) | 52.5% (280) | 1.8 (2,427) | 48.9% (280) | 2.1 (2,410) |
| claude-haiku-5-5 | high | 51.8% (112) | 1.5 (878) | 51.8% (112) | 1.5 (953) | 51.8% (112) | 1.6 (951) |
| claude-haiku-5-5 | xhigh | 52.7% (110) | 1.0 (877) | 55.5% (110) | 1.0 (951) | 53.6% (110) | 1.2 (922) |
| claude-haiku-5-5 | max | 50.9% (110) | 1.1 (873) | 68.2% (110) | 0.9 (1,024) | 56.4% (110) | 1.0 (914) |
| gpt-5.6-terra | low | 42.2% (90) | 3.5 (643) | 46.7% (90) | 2.9 (732) | 47.8% (90) | 3.0 (736) |
| gpt-5.6-terra | medium | 46.9% (256) | 3.0 (1,887) | 49.6% (256) | 2.6 (2,099) | 48.4% (256) | 2.4 (2,052) |
| gpt-5.6-terra | high | 50.0% (90) | 2.7 (699) | 48.9% (90) | 2.3 (732) | 50.0% (90) | 2.8 (713) |
| gpt-5.6-terra | xhigh | 56.7% (90) | 1.8 (730) | 54.4% (90) | 2.1 (783) | 53.3% (90) | 2.2 (821) |
| gpt-5.6-terra | max | 52.2% (90) | 1.3 (750) | 51.1% (90) | 1.5 (861) | 57.8% (90) | 1.5 (878) |
| gpt-6-luna | off | 30.0% (110) | 5.1 (996) | 35.5% (110) | 3.6 (1,111) | 35.5% (110) | 3.5 (1,055) |
| gpt-6-luna | low | 30.0% (110) | 4.8 (1,030) | 39.1% (110) | 4.1 (1,157) | 25.5% (110) | 4.2 (996) |
| gpt-6-luna | medium | 36.2% (276) | 4.3 (2,284) | 32.6% (276) | 3.9 (2,702) | 34.4% (276) | 3.8 (2,553) |
| gpt-6-luna | high | 52.7% (110) | 3.0 (957) | 55.5% (110) | 3.3 (1,122) | 58.2% (110) | 3.4 (1,008) |
| gpt-6-luna | xhigh | 63.4% (112) | 2.5 (1,005) | 60.7% (112) | 2.4 (1,065) | 68.8% (112) | 2.6 (1,074) |
| gpt-6-luna | max | 61.8% (110) | 2.2 (998) | 60.0% (110) | 2.1 (1,188) | 67.3% (110) | 2.3 (1,009) |
| claude-haiku-4-5-20251001 | off | 36.7% (90) | 6.1 (764) | 33.3% (90) | 5.3 (827) | 38.9% (90) | 6.7 (811) |
| claude-haiku-4-5-20251001 | minimal | 51.1% (90) | 5.2 (806) | 46.7% (90) | 4.2 (810) | 52.2% (90) | 4.5 (718) |
| claude-haiku-4-5-20251001 | low | 48.9% (90) | 4.7 (767) | 47.8% (90) | 4.6 (803) | 56.7% (90) | 5.4 (775) |
| claude-haiku-4-5-20251001 | medium | 46.5% (256) | 4.7 (1,990) | 38.3% (256) | 4.8 (2,114) | 40.6% (256) | 4.7 (2,016) |
| claude-haiku-4-5-20251001 | high | 51.1% (90) | 4.3 (729) | 56.7% (90) | 4.0 (833) | 41.1% (90) | 5.3 (712) |
| all |  | - | 2.5 (40,142) | - | 2.3 (45,447) | - | 2.4 (42,743) |
<!-- by-round:end -->
