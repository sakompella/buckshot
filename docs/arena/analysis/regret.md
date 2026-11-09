# Regret

How good each agent move was, by the minimax search of the Rust evaluator in `sim/rust/` ([ADR-0052](../../adr/0052-rust-evaluator.md)), which is checked against the Bend minimax player in `sim/bend-mp/player/` ([ADR-0043](../../adr/0043-minimax-player.md)). For every agent decision the search scores each legal move from the deciding player's own information. Regret is the best move's score minus the chosen move's score. `tools/arena/score_regret.py` scores every replay-validated decision of the analysis database that has no row yet, or the matches or decisions a list names. [net-points.md](net-points.md) sums it per match and seat.

Until 2026-11-08 the rows came from the Bend player, through `web/scripts/arena-regret.ts`. That script is removed. The Bend rows stay in the older files and in the sections below that were measured with them.

## Production scoring

Since 2026-11-08 the production rows come from the Rust evaluator. `tools/arena/score_regret.py` (the wrap-up's regret step) builds `buckshot-search` with the `f64` and `seats-2` features (arena matches have two seats; the parser refuses wider tables) and runs `--evaluator bounded-v1-f64 --unpruned` at depth 6 and 20,000 nodes. Unpruned, every move's value is exact at the depth reached, which the replay's move list needs. Every decision gets a static-reload row in `derived/regret-rust.sqlite`, and every decision with 2 or fewer shells left also gets a sampled-reload row (256 deals) in `derived/regret-rust-sampled256.sqlite`; the viewer and the export prefer the sampled row (`--regret-sampled`, [accuracy.md](accuracy.md)). The positions come from `web/scripts/rust-search-inputs.ts`, which replays each match as described below. Their `evaluator` is `bounded-v1-f64-unpruned-<hex>`, the hex a hash of the Rust sources, Cargo files and features, and an `evaluator_build` table records each id's commit, binary hash, row count and time. `ms` is empty: the search runs decisions in parallel and times none alone. The older Bend rows (`regret.sqlite`, player `a3962092b561cfb4`, and `regret-sampled256-native.sqlite`, `09c5bda32435eda8`) stay as they were.

The budget means something else here. `bounded-v1` counts nodes only: it has no fuel, and a memo hit costs nothing. So at the same 20,000 nodes it finishes deeper iterations than the Bend player on the decisions the old budget cut short. Before the switch, 2,000 random static rows and 2,000 random sampled rows were scored both ways:

- Static: on the 1,566 decisions where both reached the same depth, every move's value agreed within 1 millionth, and one best move differed, on a tie within 1 millionth. Rust went deeper on 434 (21.7%) and never shallower. All 434 were rows the old budget had stopped at depth 2 to 5. There the best move differed in 113 and the regret in 195, by a point or more in 112 and by 5 or more in 25.
- Sampled: on the 1,933 at the same depth, values agreed within 1 millionth and regrets within 2, with no best move changed. Rust went deeper on 67 (3.4%), changing the best move in 12 and the regret in 13, by 5 points or more in 4.
- Mean regret over the sample hardly moved: 2.359 points against 2.362 static, 1.608 against 1.611 sampled. 78 moves lost 15 points or more, against 80.

The full rescore of 2026-11-08 (snapshot of the analysis database that day) wrote 181,311 static rows (181,308 searched, the same 3 invalid as before) and 62,045 sampled rows (3 invalid), 598 more sampled decisions than the old file covered. Its time is in Runtime. The budget now stops 29% of static searches before depth 6 (39% before) and 0.6% of sampled ones (3.3% before). Mean regret is 2.31 points static (2.30 before) and 1.74 sampled (1.75 before).

## How it is measured

`tools/arena/score_regret.py` takes the agent decisions of the replay-validated matches of the analysis database ([database.md](../database.md)) that its output has no row for. `web/scripts/rust-search-inputs.ts` replays each match through `replayOf`, as `arena-knowledge.ts` does. Before each agent move it builds the position as the deciding player sees it: the match configuration, the public board, and the player's whole log (every public event and its own secrets, in the order it heard them), with the menu in the player's move order and the shells left. The hidden gun and other players' secrets never enter. TypeScript only marshals these values into numbers (`web/src/analysis/native-input.ts`). `buckshot-search` scores every move of each position, and the script turns each result into a row. Forced grabs and fallback moves are not scored: only decisions made by an agent are. The Bend player (`sim/bend-mp/analysis.bend`) stays the source of the rules and is the reference the Rust search is checked against ([ADR-0052](../../adr/0052-rust-evaluator.md)).

A score is the deciding player's chance of winning the current round, in millionths. Divide by 10,000 for a percentage; a regret of 10,000 is one percentage point. Opponents are modelled as minimizing it from public information.

- **Searched:** the search finished at least one depth. Regret is set, and is 0 for the best move.
- **Fallback:** no depth finished, because the node budget ran out first or the run asked for depth 0. Every move gets the same static value; the regret is NULL, never 0.
- **Invalid:** only in the older Bend rows and the rows written before 2026-11-09: the player could not build a belief from the log, or the Rust parser refused the position. The 3 invalid rows of the 2026-11-08 rescore are item grabs of match `4f16575f…` (ordinals 60, 72 and 81) whose run log records them as the agent's; a menu of one move is no choice, so the scorer no longer takes them.

**Bend and Rust must agree.** For every decision the scorer checks that Rust's root moves (each line's `code`, as `show.move` prints it) are Bend's menu, move by move, and that neither side refuses the position. On any difference it writes no row: it writes one JSON dump per disagreement into `<output>-bugs/` next to the output database (match id, ordinal, the input line exactly as fed to `buckshot-search` and its command, Bend's menu and codes, Rust's whole row, the evaluator id, features, binary hash and commit), prints their paths and exits non-zero after that input file.
- **Exact:** both the best and the chosen score are 0 or 1,000,000. Only a settled round gives those scores: a win, or a loss, which a dead player's 0 always is. Treat only exact rows as solved. `exact = 0` means not proven exact, not heuristic. Take both players at 1 health with one live and one blank shell left. Shooting the other player settles the round on every path, but its score of 500,000 is a mix of a win and a loss, so the row is not marked exact. The search does not report which values are settled.

The reload rule says how a search values a reload it stops at ([#4](https://github.com/sakompella/buckshot/issues/4)). `static` is the static evaluation before the draw. `sampled` averages that evaluation over `--samples` deals (256 by default) drawn at random as the machine asks for them, seeded by the state the deal starts from, so a rerun gives the same rows. Both rules search the same tree and spend the same nodes, so where no line reaches a reload they give the same scores. Production scores every decision `static`, and the decisions with 2 or fewer shells left also `sampled`, since a reload is near only then. Both rules work at two seats only.

The Bend player had a third rule, `expected-deal`: the static evaluation averaged over every distinct deal of the reload (item amount, the items each seat takes, the batch and the shuffle, each weighted by its chance, with deals counted as multisets). It was exact but too slow for a run over many decisions (see Runtime), so the sampled rule ([#17](https://github.com/sakompella/buckshot/issues/17)) replaced it: on real leaves it was about 700 times faster and agreed with the exact value within its standard error. The Rust search has no `expected-deal` rule.

## The `regret` table

`score_regret.py` writes the `regret` table of the derived database named by `--out` (static rows) and of the one named by `--sampled-out` (sampled rows), creating each if needed and leaving other tables alone, so a file can share tables with the knowledge database. It also writes an `evaluator_build` table: for each run, the evaluator id, settings, source commit (`+dirty` if `sim/rust` has uncommitted changes), features, binary hash, decisions scored, seconds and threads. Rows are keyed by match, ordinal, evaluator, depth limit, budget, reload rule and sample count. The script reads the keys already in the file and scores only the agent decisions without one, so a rerun continues where it stopped, and after an import only the new matches are scored. Rows are committed every 512, so an interrupted run loses at most that many and scores them again. Two runs must not write one file at the same time. A change to the Rust sources, Cargo files or features changes the evaluator id, so every decision then counts as unscored: a regret database holds one evaluator group, and a changed evaluator needs a full rescore into new files.

| Column | Meaning |
|---|---|
| `match_id`, `ordinal` | The decision, as in the analysis database's `decisions`. |
| `player`, `label` | The deciding player's letter and the move it chose. |
| `evaluator` | `bounded-v1-f64-unpruned-<hash of the Rust sources, Cargo files and features>` (the Bend rows: a hash of the compiled player). Never mix rows with different values. |
| `max_depth`, `budget` | The run's depth limit (decisions, by every player) and node budget (nodes expanded; in the Bend rows, a fuel count). |
| `reload`, `samples` | `static` or `sampled`, and the deals per leaf of a sampled run (0 for static); `samples > 0` exactly when `reload` is `sampled`. The Bend rows can also be `expected-deal`. The viewer and the Python reports read one run's rows: they take `--reload` (default `static`) and, for a sampled run, `--samples` (default 256). |
| `status` | `searched` or `fallback` (`invalid` in older rows). |
| `values_json` | Every legal move with its score, in the player's move order. |
| `best`, `best_score`, `chosen_score`, `regret`, `exact` | Set only when searched. Ties go to the first move. `exact` is 1 when proven exact, 0 when not proven (see above). |
| `depth`, `limited` | The depth the search finished, and whether the budget stopped it there. |
| `nodes`, `ms` | Nodes expanded and milliseconds spent on the decision (`ms` is empty in the Rust rows: the search runs decisions in parallel and times none alone). |

## Runtime

With the Rust evaluator (depth 6, 20,000 nodes), the full rescore of 2026-11-08 wrote 181,311 static rows and 62,045 sampled rows in 26 minutes on hp-server with 6 search threads: 6 minutes writing the inputs (6 processes), 3.4 minutes of static search and 16.5 of sampled. The Bend player needed about 17 hours for the static rows alone in one process (below). After an import, only the new matches are scored, so a wrap-up spends minutes here.

### The Bend player, measured in October 2026 (historical)

These numbers are from the Bend player and `arena-regret.ts`, both removed from the production path on 2026-11-08. They are kept as the record of what the exact and sampled reload rules cost.

With the defaults, depth 6 and a budget of 20,000 nodes, 7 matches (352 decisions) on hp-server took 344 ms per decision on average: median 274 ms, 95th percentile 804 ms, max 1,070 ms. 39% of the searches were stopped by the budget, at depth 2 to 5. At that rate the 179,642 agent decisions take about 17 hours in one process.

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

From the repository root, inside `nix develop` (bun, cargo and Bend on PATH):

    nice -n 10 python3 tools/arena/score_regret.py --db <buckshot.sqlite> --out <derived>/regret-rust.sqlite --sampled-out <derived>/regret-rust-sampled256.sqlite [--depth 6] [--budget 20000] [--samples 256] [--threads N] [--jobs N]

It scores the agent decisions of replay-validated matches that the files have no row for, so it continues an interrupted run and scores only new matches after an import. `--matches <file>` (match names, one per line) and `--decisions <file>` (one `<match id> <ordinal>` line per decision, the ids of the analysis database) limit it to those; every named decision must be an agent decision of a replay-validated match, or it stops. Give `--out`, `--sampled-out` or both. `--sampled-max-shells` (default 2) sets which decisions get a sampled row. `--work DIR` keeps the inputs and logs. It prints a JSON summary: the evaluator id, the decisions, and rows and seconds per reload rule.

The wrap-up (`tools/arena/wrap_tournament.py`) runs the same code in its `regret` step. It copies the live static and sampled databases to staged files, scores the new matches of its snapshot into them, and stops unless each staged file still holds one evaluator group. A staged file with a different evaluator means the Rust sources changed: rescore everything into new files (`--regret` and `--regret-sampled` name them) instead.

Rows scored by the removed Bend player cannot be extended: the old files (`regret.sqlite`, hash `a3962092b561cfb4`, and `regret-sampled256-native.sqlite`) hold a different evaluator. The Rust evaluator reproduces the Bend rows within 1 millionth where both reach the same depth (see Production scoring), and `sim/rust/search/tests/production/` pins it to them.

The summary tables below come from the regret and knowledge databases, read only, in a few seconds:

    python3 tools/arena/analysis/regret.py [--regret <derived>/regret.sqlite] [--knowledge <derived>/knowledge.sqlite] [--doc docs/arena/analysis/regret.md]

With `--doc` it rewrites the tables at the end of this page. `tools/arena/analysis/reload_bias.py` draws the stratified lists (`sample`) and rewrites the tables of the Reload bias section from a `sampled` run (`report --doc`), reading the sampled and static runs read only. The by-round tables come from `tools/arena/analysis/by_round.py`, which also reads the analysis database for round winners (`--db`) and rewrites the tables of the last section the same way. `tools/arena/analysis/regret_depth.py` does the same for the Deeper search section: `sample` draws the lists, and `report --doc` rewrites its tables from the deep run (`regret-depth.sqlite`). The Reload bias and Deeper search runs were scored with the removed Bend player (depth 8 and 200,000 nodes for the deep one), so they cannot be rerun as written. The Reload bias report still reads its stored rows. The Deeper search report stops: its depth 8 rows and the production depth 6 rows were scored by different evaluators (`regret_depth.py` checks), so its tables below are the earlier result and are not regenerated. `tools/arena/analysis/round_improvement.py` rewrites the within-match tables of the By round section (`--doc`, and `--svg DIR` for its figures). `python3 -m unittest discover -s tools/arena/analysis` runs its tests.

`bun scripts/arena-regret-consistency.ts <derived>/regret.sqlite`, from `web/`, checks every searched row of every run, read only: `values_json` decodes, its top score is `best_score`, the chosen move is in it with `chosen_score`, and `regret` is `best_score` minus `chosen_score`. It prints the count of each mismatch and fails on any. The viewer's replay reads the same rows and refuses a match with a malformed one.

## Results

Scope: 3,536 scored matches with no DeepSeek seat, from the 3,557-match snapshot of 2026-11-04. This is a casual pass over the full run, with counts and means and no intervals. It covers the 179,642 agent decisions of those matches (DeepSeek is left out as in [matchups.md](matchups.md)). Every one has a row, every row was searched, and none fell back. The rows of the run also hold DeepSeek's matches and unfinished ones. All rows come from one player build (see Reproduce). A config is a model with its effort, pooled over the tournaments it played in. Regret is in percentage points of the round win chance, as above. Mean regret over all decisions is 2.3 points and the 90th percentile 6.4. 11.3% of the decisions are exact.

1. **Regret and the ratings agree at the ends.**
   - At medium effort the mean regret is Opus 1.1, Astra 1.3, Sol 1.4, Haiku 5.5 2.0, Sonnet 2.0, Terra 2.7, Luna 4.0 and Haiku 4.5 4.6 points. Terra 6.1 (1,976 decisions) is 1.8.
   - The cross-model ratings in [matchups.md](matchups.md) put the same three on top (Astra first) and Luna and Haiku 4.5 at the bottom, in the other order. The four in between overlap in rating, and regret does not separate them further. Regret uses no match results, so it agrees from the other side.
2. **More effort mostly lowers regret. Sol and Opus barely move.**
   - Haiku 5.5 goes from 3.8 at off to 1.0 at max, Sonnet from 2.3 to 0.8, Luna from 4.1 to 2.2, Terra from 3.1 at low to 1.4 at max. Haiku 4.5 moves less, from 5.7 at off to 4.5 at high. The steps are not always in order: Luna is 4.1 at off and 4.4 at low. The 90th percentile falls with it: Haiku 5.5 10.7 to 3.2, Sonnet 7.3 to 2.4.
   - Sol (1.2 to 1.6) and Opus from off to xhigh (1.0 to 1.4) change by 0.4 points or less. Opus max, with 2,180 decisions from 80 matches, is 0.9. Sonnet max, at 0.8, is the lowest cell of the table. Sol is flat in the rating sweep too. Opus is not: its xhigh rating is far above its low, yet its regret moves by 0.4 points. Regret does not explain that gap.

**Near reloads (for [#4](https://github.com/sakompella/buckshot/issues/4)).** Regret concentrates in shots with two or three shells left in the gun.
- Those shots average 4.5 and 3.8 points, with a 90th percentile of 14.6 and 12.3. A shot with one shell left averages 1.5 and one with five left 2.0.
- Item moves stay between 1.6 and 2.3 at every distance. In this cut they show no sign of a reload effect.
- The node budget does not explain the rise. It stopped 1.0% and 12.5% of the searches with two and three shells left, against 0.0% at one shell left.
- This shows where regret is, not why. A shot with two left ends the search at the reload one shot later, so the static leaf is a possible cause. Real mistakes on near-even shells are another. The table cannot tell them apart, which is what #4 measures. The Reload bias section below has the answer.

## Reload bias

This section and Deeper search measure fixed samples drawn from the 2026-10-26 run of 125,150 decisions (tournaments 1 to 4). They were not redrawn for tournaments 5 and later, and their sizes and weights below are that run's.

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
- 29% of the searches were stopped by the budget at depth 1 to 5. With five or more shells left most are, so those rows compare shallower searches. A search to depth 8 with ten times the budget gives similar mean regrets and the same observed model order in a sample of this run (Deeper search), but still stops 30% of the time.

## Tables

<!-- tables:start -->
179,642 searched decisions; 3 left out for having no search; 0 agent decisions with no row.

### Regret by config

| model | effort | decisions | mean regret | 90th percentile | exact |
|---|---|---|---|---|---|
| claude-opus-5-5 | off | 2,080 | 1.2 | 4.0 | 13.2% |
| claude-opus-5-5 | low | 1,941 | 1.4 | 3.8 | 11.1% |
| claude-opus-5-5 | medium | 7,483 | 1.1 | 3.5 | 12.9% |
| claude-opus-5-5 | high | 1,985 | 1.0 | 3.4 | 11.7% |
| claude-opus-5-5 | xhigh | 3,747 | 1.0 | 3.3 | 12.2% |
| claude-opus-5-5 | max | 2,180 | 0.9 | 2.8 | 13.7% |
| gpt-6-astra | off | 2,103 | 1.4 | 4.4 | 12.0% |
| gpt-6-astra | low | 1,992 | 1.3 | 3.6 | 13.5% |
| gpt-6-astra | medium | 6,298 | 1.3 | 3.9 | 13.2% |
| gpt-6-astra | high | 2,157 | 1.4 | 4.3 | 13.3% |
| gpt-6.1-sol | low | 2,284 | 1.6 | 4.6 | 11.9% |
| gpt-6.1-sol | medium | 6,746 | 1.4 | 4.3 | 12.9% |
| gpt-6.1-sol | high | 2,458 | 1.3 | 4.6 | 12.4% |
| gpt-6.1-sol | xhigh | 2,527 | 1.2 | 4.2 | 13.3% |
| gpt-6.1-sol | max | 3,151 | 1.3 | 4.4 | 12.0% |
| gpt-6.1-terra | off | 1,934 | 2.3 | 6.9 | 12.5% |
| gpt-6.1-terra | low | 1,883 | 2.0 | 6.0 | 14.0% |
| gpt-6.1-terra | medium | 1,976 | 1.8 | 5.1 | 13.6% |
| gpt-6.1-terra | high | 2,118 | 1.5 | 4.9 | 11.7% |
| gpt-6.1-terra | xhigh | 2,079 | 1.4 | 4.0 | 13.5% |
| gpt-6.1-terra | max | 2,444 | 1.2 | 3.9 | 13.6% |
| claude-sonnet-5-5 | off | 3,996 | 2.3 | 7.3 | 11.4% |
| claude-sonnet-5-5 | low | 3,682 | 2.3 | 7.3 | 11.2% |
| claude-sonnet-5-5 | medium | 7,944 | 2.0 | 6.2 | 12.5% |
| claude-sonnet-5-5 | high | 3,930 | 1.6 | 5.2 | 11.1% |
| claude-sonnet-5-5 | xhigh | 4,068 | 1.2 | 3.8 | 13.3% |
| claude-sonnet-5-5 | max | 3,572 | 0.8 | 2.4 | 14.8% |
| claude-haiku-5-5 | off | 4,888 | 3.8 | 10.7 | 9.7% |
| claude-haiku-5-5 | low | 5,014 | 2.3 | 6.4 | 10.4% |
| claude-haiku-5-5 | medium | 8,515 | 2.0 | 5.5 | 11.9% |
| claude-haiku-5-5 | high | 4,294 | 1.5 | 4.3 | 10.8% |
| claude-haiku-5-5 | xhigh | 3,935 | 1.1 | 3.6 | 11.4% |
| claude-haiku-5-5 | max | 2,825 | 1.0 | 3.2 | 13.4% |
| gpt-5.6-terra | low | 2,127 | 3.1 | 10.1 | 10.4% |
| gpt-5.6-terra | medium | 6,108 | 2.7 | 7.9 | 11.1% |
| gpt-5.6-terra | high | 2,166 | 2.7 | 8.3 | 11.4% |
| gpt-5.6-terra | xhigh | 2,409 | 2.0 | 5.8 | 11.3% |
| gpt-5.6-terra | max | 2,489 | 1.4 | 4.2 | 10.1% |
| gpt-6-luna | off | 3,162 | 4.1 | 11.9 | 7.4% |
| gpt-6-luna | low | 3,183 | 4.4 | 13.4 | 9.4% |
| gpt-6-luna | medium | 7,691 | 4.0 | 12.3 | 9.2% |
| gpt-6-luna | high | 3,129 | 3.2 | 9.9 | 12.2% |
| gpt-6-luna | xhigh | 3,251 | 2.4 | 6.8 | 13.7% |
| gpt-6-luna | max | 3,244 | 2.2 | 6.5 | 13.1% |
| claude-haiku-4-5-20251001 | off | 3,272 | 5.7 | 16.5 | 7.1% |
| claude-haiku-4-5-20251001 | minimal | 3,687 | 4.5 | 12.7 | 6.4% |
| claude-haiku-4-5-20251001 | low | 3,898 | 4.5 | 13.0 | 7.0% |
| claude-haiku-4-5-20251001 | medium | 8,136 | 4.6 | 13.5 | 7.4% |
| claude-haiku-4-5-20251001 | high | 3,461 | 4.5 | 12.6 | 7.4% |
| all |  | 179,642 | 2.3 | 6.4 | 11.3% |

### Regret by shells left in the gun

| shells left | stopped by budget | shots | mean | 90th percentile | item moves | mean | 90th percentile |
|---|---|---|---|---|---|---|---|
| 1 | 0.0% | 19,201 | 1.5 | 2.8 | 8,366 | 1.8 | 6.1 |
| 2 | 1.0% | 18,639 | 4.5 | 14.6 | 15,241 | 1.6 | 5.0 |
| 3 | 12.5% | 18,004 | 3.8 | 12.3 | 21,742 | 1.6 | 4.7 |
| 4 | 37.5% | 14,227 | 2.6 | 7.9 | 20,102 | 1.8 | 5.4 |
| 5 | 66.7% | 9,950 | 2.0 | 6.5 | 16,921 | 2.0 | 5.1 |
| 6 | 89.1% | 5,653 | 1.7 | 4.6 | 11,596 | 2.3 | 4.8 |
<!-- tables:end -->

## By round

Does a model play the short early rounds differently from the later, item-heavy ones? This is a casual pass for [#14](https://github.com/sakompella/buckshot/issues/14), with counts in brackets and no intervals, over the same 3,536 finished matches with no DeepSeek seat. The last subsection follows each seat within its own match, with intervals. It was not regenerated for tournaments 7, 8 and 9 and covers 2,722 matches. Round winners come from the public lines of the match events, as the viewer reads them; the last round's winner is inferred from final cash when its line is missing. Rounds are numbered from 1. A win rate is the share of its rounds a config won, against whoever it met, so it also reflects the opponents' strength.

1. **No config's win rate clearly changes by round.**
   - Pooled over efforts, a model's win rate moves by 4 points or less between rounds for all nine models. Astra goes from 59.3% to 61.5% and 60.1% over 494, and Haiku 4.5, the largest mover, from 41.3% to 37.7% and 39.2% over 892.
   - Per config the cells hold 80 to 342 rounds, so gaps of 10 points are common at 110 rounds and say little. The largest swings are Haiku 4.5 high, at 42.2%, 51.1% and 33.3% over 135 rounds, Astra off at 61.3%, 62.5% and 45.0% over 80, Terra 6.1 off at 56.2%, 66.2% and 48.8% over 80, and Haiku 5.5 max at 51.4%, 67.6% and 56.8% over 111. Haiku 5.5 off falls from 45.0% to 36.6% and 38.1% over 202. None is a steady trend across the other efforts.
2. **Regret is flat across rounds, except that round 1 shots are a little worse.**
   - Mean regret over all moves is 2.4, 2.3 and 2.3 points in rounds 1, 2 and 3. In every round the same three, Opus, Astra and Sol, are lowest and Haiku 4.5 is highest.
   - Shots cost 3.1 points in round 1 against 2.7 and 2.8 later. Item moves stay at 1.7 to 1.9. The table does not say why. Decisions of one match are not independent, so the gap is small evidence.
   - Round 3 is often a dead rubber, since prizes are 70k, 75k and 80k and a 2-0 lead settles the winner. No table here splits round 3 regret by the lead; an earlier one-off check of that was not scripted and is removed.

<!-- by-round:start -->
10,611 rounds of finished matches.

### Win rate and regret by round, per model

| model | effort | round 1 win rate | round 1 mean regret | round 2 win rate | round 2 mean regret | round 3 win rate | round 3 mean regret |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 | all | 56.0% (764) | 1.0 (6,300) | 55.0% (764) | 1.1 (6,712) | 54.6% (764) | 1.1 (6,404) |
| gpt-6-astra | all | 59.3% (494) | 1.3 (4,050) | 61.5% (494) | 1.3 (4,224) | 60.1% (494) | 1.4 (4,276) |
| gpt-6.1-sol | all | 53.4% (691) | 1.3 (5,253) | 54.8% (691) | 1.4 (6,178) | 53.0% (691) | 1.4 (5,735) |
| gpt-6.1-terra | all | 60.2% (480) | 1.7 (4,170) | 59.6% (480) | 1.7 (4,078) | 58.1% (480) | 1.6 (4,186) |
| claude-sonnet-5-5 | all | 48.6% (1,108) | 1.9 (8,358) | 48.9% (1,108) | 1.7 (9,841) | 49.4% (1,108) | 1.7 (8,993) |
| claude-haiku-5-5 | all | 49.1% (1,180) | 2.1 (9,338) | 49.9% (1,180) | 1.9 (10,052) | 49.3% (1,180) | 2.1 (10,081) |
| gpt-5.6-terra | all | 48.9% (624) | 2.6 (4,764) | 49.5% (624) | 2.4 (5,273) | 50.8% (624) | 2.3 (5,262) |
| gpt-6-luna | all | 43.6% (841) | 3.8 (7,399) | 44.2% (841) | 3.3 (8,459) | 45.4% (841) | 3.4 (7,802) |
| claude-haiku-4-5-20251001 | all | 41.3% (892) | 4.7 (7,317) | 37.7% (892) | 4.6 (7,788) | 39.2% (892) | 5.0 (7,349) |
| all |  | - | 2.4 (56,949) | - | 2.3 (62,605) | - | 2.3 (60,088) |

### Mean regret by round and kind of move

| round | all moves | shots | item moves |
|---|---|---|---|
| 1 | 2.4 (56,949) | 3.1 (27,727) | 1.7 (29,222) |
| 2 | 2.3 (62,605) | 2.7 (29,507) | 1.8 (33,098) |
| 3 | 2.3 (60,088) | 2.8 (28,440) | 1.9 (31,648) |

### Win rate and regret by round, per config

| model | effort | round 1 win rate | round 1 mean regret | round 2 win rate | round 2 mean regret | round 3 win rate | round 3 mean regret |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 | off | 58.8% (80) | 1.3 (704) | 56.2% (80) | 1.3 (715) | 61.3% (80) | 1.1 (661) |
| claude-opus-5-5 | low | 51.2% (80) | 1.6 (696) | 52.5% (80) | 1.4 (633) | 45.0% (80) | 1.1 (612) |
| claude-opus-5-5 | medium | 56.1% (294) | 1.0 (2,449) | 53.7% (294) | 1.1 (2,547) | 53.1% (294) | 1.2 (2,487) |
| claude-opus-5-5 | high | 48.8% (80) | 0.9 (538) | 60.0% (80) | 1.0 (754) | 55.0% (80) | 1.1 (693) |
| claude-opus-5-5 | xhigh | 53.3% (150) | 0.8 (1,173) | 52.0% (150) | 1.1 (1,315) | 54.7% (150) | 1.1 (1,259) |
| claude-opus-5-5 | max | 70.0% (80) | 0.6 (740) | 61.3% (80) | 1.0 (748) | 62.5% (80) | 0.9 (692) |
| gpt-6-astra | off | 61.3% (80) | 1.2 (677) | 62.5% (80) | 1.4 (685) | 45.0% (80) | 1.6 (741) |
| gpt-6-astra | low | 51.2% (80) | 1.2 (670) | 62.5% (80) | 1.4 (668) | 63.7% (80) | 1.2 (654) |
| gpt-6-astra | medium | 57.5% (254) | 1.4 (2,000) | 61.0% (254) | 1.2 (2,167) | 61.8% (254) | 1.4 (2,131) |
| gpt-6-astra | high | 71.2% (80) | 1.5 (703) | 61.3% (80) | 1.4 (704) | 66.2% (80) | 1.3 (750) |
| gpt-6.1-sol | low | 55.1% (98) | 1.2 (717) | 48.0% (98) | 2.0 (822) | 50.0% (98) | 1.5 (745) |
| gpt-6.1-sol | medium | 55.7% (271) | 1.4 (2,183) | 60.9% (271) | 1.4 (2,386) | 53.9% (271) | 1.4 (2,177) |
| gpt-6.1-sol | high | 51.5% (99) | 1.4 (732) | 46.5% (99) | 1.3 (946) | 46.5% (99) | 1.3 (780) |
| gpt-6.1-sol | xhigh | 47.5% (101) | 1.1 (750) | 50.5% (101) | 1.2 (884) | 58.4% (101) | 1.3 (893) |
| gpt-6.1-sol | max | 53.3% (122) | 1.0 (871) | 57.4% (122) | 1.4 (1,140) | 54.1% (122) | 1.3 (1,140) |
| gpt-6.1-terra | off | 56.2% (80) | 2.3 (629) | 66.2% (80) | 2.2 (721) | 48.8% (80) | 2.4 (584) |
| gpt-6.1-terra | low | 50.0% (80) | 1.9 (642) | 61.3% (80) | 1.9 (611) | 55.0% (80) | 2.1 (630) |
| gpt-6.1-terra | medium | 53.8% (80) | 1.8 (660) | 55.0% (80) | 1.9 (660) | 63.7% (80) | 1.6 (656) |
| gpt-6.1-terra | high | 68.8% (80) | 1.5 (736) | 56.2% (80) | 1.6 (666) | 55.0% (80) | 1.4 (716) |
| gpt-6.1-terra | xhigh | 60.0% (80) | 1.5 (703) | 52.5% (80) | 1.4 (634) | 66.2% (80) | 1.4 (742) |
| gpt-6.1-terra | max | 72.5% (80) | 1.1 (800) | 66.2% (80) | 1.4 (786) | 60.0% (80) | 1.2 (858) |
| claude-sonnet-5-5 | off | 45.1% (164) | 2.3 (1,184) | 39.6% (164) | 2.4 (1,473) | 42.7% (164) | 2.1 (1,339) |
| claude-sonnet-5-5 | low | 45.3% (159) | 2.4 (1,123) | 34.6% (159) | 2.2 (1,315) | 39.0% (159) | 2.4 (1,244) |
| claude-sonnet-5-5 | medium | 42.9% (324) | 2.3 (2,387) | 52.8% (324) | 2.0 (2,905) | 52.2% (324) | 1.8 (2,652) |
| claude-sonnet-5-5 | high | 47.2% (161) | 1.7 (1,261) | 52.2% (161) | 1.5 (1,472) | 41.6% (161) | 1.7 (1,197) |
| claude-sonnet-5-5 | xhigh | 60.0% (160) | 1.3 (1,306) | 49.4% (160) | 1.2 (1,443) | 55.0% (160) | 1.1 (1,319) |
| claude-sonnet-5-5 | max | 58.6% (140) | 0.7 (1,097) | 62.9% (140) | 0.8 (1,233) | 65.0% (140) | 1.0 (1,242) |
| claude-haiku-5-5 | off | 45.0% (202) | 4.0 (1,542) | 36.6% (202) | 3.5 (1,623) | 38.1% (202) | 4.0 (1,723) |
| claude-haiku-5-5 | low | 50.5% (194) | 2.2 (1,596) | 47.9% (194) | 2.3 (1,687) | 55.2% (194) | 2.3 (1,731) |
| claude-haiku-5-5 | medium | 50.0% (342) | 2.1 (2,672) | 52.6% (342) | 1.9 (2,907) | 48.2% (342) | 2.0 (2,936) |
| claude-haiku-5-5 | high | 51.4% (173) | 1.5 (1,366) | 49.7% (173) | 1.5 (1,479) | 49.7% (173) | 1.5 (1,449) |
| claude-haiku-5-5 | xhigh | 46.2% (158) | 1.0 (1,284) | 51.3% (158) | 1.0 (1,330) | 53.2% (158) | 1.3 (1,321) |
| claude-haiku-5-5 | max | 51.4% (111) | 1.1 (878) | 67.6% (111) | 0.8 (1,026) | 56.8% (111) | 1.0 (921) |
| gpt-5.6-terra | low | 42.9% (91) | 3.4 (649) | 46.2% (91) | 3.0 (738) | 47.3% (91) | 3.0 (740) |
| gpt-5.6-terra | medium | 46.7% (259) | 3.0 (1,903) | 49.0% (259) | 2.7 (2,129) | 48.3% (259) | 2.4 (2,076) |
| gpt-5.6-terra | high | 49.5% (91) | 2.7 (701) | 48.4% (91) | 2.5 (741) | 50.5% (91) | 2.8 (724) |
| gpt-5.6-terra | xhigh | 57.0% (93) | 1.8 (761) | 53.8% (93) | 2.0 (804) | 54.8% (93) | 2.2 (844) |
| gpt-5.6-terra | max | 52.2% (90) | 1.3 (750) | 51.1% (90) | 1.4 (861) | 57.8% (90) | 1.5 (878) |
| gpt-6-luna | off | 30.0% (110) | 5.1 (996) | 35.5% (110) | 3.7 (1,111) | 35.5% (110) | 3.6 (1,055) |
| gpt-6-luna | low | 30.0% (110) | 4.8 (1,030) | 39.1% (110) | 4.1 (1,157) | 25.5% (110) | 4.3 (996) |
| gpt-6-luna | medium | 35.8% (282) | 4.4 (2,341) | 32.3% (282) | 4.0 (2,742) | 34.4% (282) | 3.7 (2,608) |
| gpt-6-luna | high | 51.8% (112) | 2.9 (969) | 56.2% (112) | 3.1 (1,141) | 58.0% (112) | 3.4 (1,019) |
| gpt-6-luna | xhigh | 63.5% (115) | 2.4 (1,052) | 59.1% (115) | 2.3 (1,097) | 67.8% (115) | 2.6 (1,102) |
| gpt-6-luna | max | 61.6% (112) | 2.2 (1,011) | 60.7% (112) | 2.0 (1,211) | 67.0% (112) | 2.3 (1,022) |
| claude-haiku-4-5-20251001 | off | 34.4% (125) | 5.5 (1,085) | 28.0% (125) | 5.2 (1,102) | 35.2% (125) | 6.4 (1,085) |
| claude-haiku-4-5-20251001 | minimal | 41.3% (143) | 4.9 (1,245) | 39.9% (143) | 4.2 (1,286) | 46.2% (143) | 4.5 (1,156) |
| claude-haiku-4-5-20251001 | low | 40.9% (149) | 4.2 (1,258) | 38.9% (149) | 4.4 (1,355) | 45.6% (149) | 4.9 (1,285) |
| claude-haiku-4-5-20251001 | medium | 43.5% (340) | 4.6 (2,608) | 34.4% (340) | 4.8 (2,807) | 37.4% (340) | 4.5 (2,721) |
| claude-haiku-4-5-20251001 | high | 42.2% (135) | 4.2 (1,121) | 51.1% (135) | 4.0 (1,238) | 33.3% (135) | 5.3 (1,102) |
| all |  | - | 2.4 (56,949) | - | 2.3 (62,605) | - | 2.3 (60,088) |
<!-- by-round:end -->

### Within a match

Do models get better, or worse, from round 1 to rounds 2 and 3 of the same match? The tables above compare configs across different matches, so match-to-match luck sits in them. This compares each seat with itself: its round 2 and round 3 value minus its round 1 value, for mean regret, round win and shooting itself on a proven live shell ([certain-mistakes.md](certain-mistakes.md)). The changes are averaged per model and per config. Each interval is 95%, from resampling seed blocks, so the two seats of a match and its seat swap move together. A regret change counts only the seats that moved in both rounds. Regret is first adjusted: each move's regret minus the mean regret of all moves of the same model, shot or item move, and shells left in the gun. Later rounds have more items and other chamber lengths, and this keeps that from passing as a change. Unadjusted means differ from adjusted ones by about 0.1 points or less. The data is the 2,722 matches of the database before tournaments 7 and 9, including tournament 6, so these tables cover fewer matches than the two above. Two figures come from the same run: `round-change-by-model.svg` (a small panel per model, rounds 1 to 3, regret and win) and `round-change-by-config.svg` (every config's round 3 change). They are not committed, as the repo holds no images. `round_improvement.py --svg DIR` writes them.

1. **Two models get better, and the gain is in shots.**
   - Luna's regret falls by 0.54 points by round 2 and 0.70 (-1.10 to -0.31) by round 3. Its shots fall by 1.41 and its item moves do not change. It also shoots itself less on a proven live shell: seat by seat that rate drops by 4.7 points (-7.7 to -1.6).
   - Sonnet falls by 0.39 (-0.68 to -0.10) by round 3, shots -0.54, item moves flat.
   - Both clear the multiple-comparison check below. Their round 1 regrets are 3.8 and 1.9 points, so each change is about a fifth of its level.
2. **Within these models the gain sits at low and middle effort.**
   - Luna off falls by 2.29 (-3.44 to -1.24), the biggest change in the data, and Luna medium by 0.82. At high, xhigh and max it stays within 0.1 of zero. Sonnet medium falls by 0.61.
   - Two configs get a little worse by round 3: Sonnet max (+0.33, +0.10 to +0.58) and Opus medium (+0.33, +0.05 to +0.62). Both have regrets near 1 point, there is little to lose, and neither survives the check below. Read them as flat.
3. **The other six models show no change, with different strength of evidence.**
   - Opus (+0.15, -0.02 to +0.33) and Sol (+0.02, -0.13 to +0.17) are flat to within a third of a point. Sol's regret is 0.21 higher in round 2 (+0.03 to +0.40) and back to round 1 by round 3. Sol low (+1.01) and Sol max (+0.41) carry that round 2 rise through the check below, but their round 3 changes are +0.07 and +0.16, flat.
   - Astra, Terra 5.6, Haiku 5.5 and Haiku 4.5 have intervals of 0.25 to 0.55 points either side, so a change of that size is not ruled out. Haiku 4.5 leans worse (+0.37, -0.17 to +0.92) and Haiku 5.5 dips in round 2 and returns (-0.25, then +0.09). Terra 6.1 has 70 seats and an interval over 1.4 points wide, which says nothing.
4. **Win rate does not follow regret.**
   - No model's round 3 win rate moves outside its interval. Luna gains 1.7 points (-0.5 to +3.7) and Sonnet 0.6 (-2.1 to +3.1). Haiku 4.5's round 2 is 3.8 points lower (-6.2 to -1.4), the one interval off zero among 16 (8 models, 2 rounds), where chance gives about 0.8. A win change also holds the opponent's change and who opens the round, so it is a weaker test of the model itself.
5. **Round 1 shots are a little worse for everyone.** Over all seats, adjusted regret is lower by 0.19 in round 2 and 0.13 (-0.25 to 0.00) in round 3. Shots are lower by 0.31 (-0.52 to -0.11) and item moves higher by 0.09 (+0.01 to +0.17). This is the pattern in the table above, now inside matches. The drops of Luna and Sonnet are larger than this common one.
6. **How many configs can be tested.** 36 of 49 configs have 80 or more seats with a regret in both rounds. The other 13 are all 6 Terra 6.1 configs, Astra off, low and high, and Opus off, low, high and max (4 to 46 seats), and are not tested. With about 100 seats an interval is about 1 point either side of the mean, and with 270 seats 0.5 to 0.7 for the noisier models. Config-level tests only see changes over about a point at most efforts.
7. **How much is chance.** Each of the 36 configs has a 95% interval, so about 1.8 should miss zero by chance alone, 0.9 on each side. Round 3 against round 1 shows 4 better and 2 worse, and round 2 against round 1 shows 3 better and 2 worse, so a little more than chance, and the config list is not a clean map. After a Benjamini-Hochberg correction at 5%, which caps the share of false findings among those kept, one config survives for round 3, Luna off, and three for round 2: Luna off, Sol low and Sol max (the last two worse). At model level 8 models are testable and about 0.4 should miss zero per delta; Luna (both rounds) and Sonnet (round 3) survive. Anything else here is suggestive.
8. **Stakes.** Round 3 is a dead rubber when one seat leads 2-0. Luna's change is -1.03 in matches already decided and -0.33 in level ones, and Sonnet's is -0.21 and -0.61, the other way. Whether a match is level depends on how rounds 1 and 2 went, so this split carries that selection. It shows no common story.

This says what changes, not why. It could be learning from the earlier rounds, warming up on round 1, or both. It does not show that the models would improve over a longer match. Opponents differ between tournaments, and the adjustment covers shells left and the kind of move only, not health or items held.

<!-- round-improvement:start -->
2,722 finished matches, 5,444 seats. A regret change counts only the seats that moved in both rounds. Negative regret change is better; win changes are in percentage points of rounds won.

### Change within a match, per model

| model | seats | regret, round 2 minus 1 | regret, round 3 minus 1 | round 3: verdict | win, round 2 minus 1 (points) | win, round 3 minus 1 (points) | shot with a proven live: self-shots, round 3 minus 1 (points) |
|---|---|---|---|---|---|---|---|
| gpt-6-luna | 811 | -0.54 (-0.91 to -0.16) | -0.70 (-1.10 to -0.31) | better | +0.4 (-1.7 to +2.6) | +1.7 (-0.5 to +3.7) | -4.7 (-7.7 to -1.6) |
| claude-sonnet-5-5 | 852 | -0.24 (-0.56 to +0.07) | -0.39 (-0.68 to -0.10) | better | -0.6 (-3.0 to +1.6) | +0.6 (-2.1 to +3.1) | +0.1 (-0.4 to +0.6) |
| gpt-6.1-terra | 70 | -0.72 (-1.58 to +0.11) | -0.26 (-0.95 to +0.50) | flat | +9.7 (-1.3 to +22.2) | +6.9 (-5.6 to +20.7) | +0.0 (+0.0 to +0.0) |
| gpt-5.6-terra | 578 | -0.31 (-0.68 to +0.02) | -0.17 (-0.54 to +0.18) | flat | +1.1 (-1.4 to +3.6) | +1.8 (-1.1 to +5.1) | -0.6 (-1.8 to +0.6) |
| gpt-6-astra | 273 | -0.25 (-0.50 to +0.03) | -0.16 (-0.45 to +0.13) | flat | +2.8 (-3.6 to +9.3) | +3.9 (-2.2 to +9.9) | +0.0 (+0.0 to +0.0) |
| gpt-6.1-sol | 654 | +0.21 (+0.03 to +0.40) | +0.02 (-0.13 to +0.17) | flat | +1.5 (-1.3 to +4.4) | -0.3 (-3.2 to +2.5) | +0.0 (+0.0 to +0.0) |
| claude-haiku-5-5 | 848 | -0.25 (-0.50 to -0.02) | +0.09 (-0.15 to +0.32) | flat | -0.5 (-2.7 to +1.8) | -2.1 (-4.6 to +0.4) | +0.6 (-0.1 to +1.4) |
| claude-opus-5-5 | 510 | +0.08 (-0.07 to +0.22) | +0.15 (-0.02 to +0.33) | flat | -0.4 (-4.5 to +3.8) | -1.7 (-5.8 to +2.4) | +0.1 (+0.0 to +0.2) |
| claude-haiku-4-5-20251001 | 628 | -0.01 (-0.56 to +0.56) | +0.37 (-0.17 to +0.92) | flat | -3.8 (-6.2 to -1.4) | -2.7 (-5.5 to +0.3) | +0.1 (-2.3 to +2.3) |
| all | 5,224 | -0.19 (-0.31 to -0.06) | -0.13 (-0.25 to -0.00) | better | +0.0 (+0.0 to +0.0) | +0.0 (+0.0 to +0.0) | -0.6 (-1.1 to -0.1) |

### Where the regret change sits, round 3 minus round 1

| model | all moves, raw regret | all moves, adjusted | shots, adjusted | item moves, adjusted |
|---|---|---|---|---|
| gpt-6-luna | -0.77 (-1.18 to -0.38) | -0.70 (-1.10 to -0.31) | -1.41 (-2.11 to -0.72) | +0.16 (-0.06 to +0.37) |
| claude-sonnet-5-5 | -0.42 (-0.73 to -0.13) | -0.39 (-0.68 to -0.10) | -0.54 (-0.97 to -0.12) | +0.03 (-0.15 to +0.21) |
| gpt-6.1-terra | -0.29 (-1.03 to +0.50) | -0.26 (-0.95 to +0.50) | +0.01 (-1.40 to +1.66) | -0.44 (-0.96 to +0.05) |
| gpt-5.6-terra | -0.21 (-0.54 to +0.17) | -0.17 (-0.54 to +0.18) | -0.30 (-0.83 to +0.22) | -0.10 (-0.37 to +0.15) |
| gpt-6-astra | -0.15 (-0.43 to +0.13) | -0.16 (-0.45 to +0.13) | -0.12 (-0.59 to +0.37) | -0.08 (-0.35 to +0.19) |
| gpt-6.1-sol | +0.03 (-0.11 to +0.18) | +0.02 (-0.13 to +0.17) | -0.07 (-0.37 to +0.21) | +0.05 (-0.15 to +0.25) |
| claude-haiku-5-5 | +0.06 (-0.20 to +0.29) | +0.09 (-0.15 to +0.32) | -0.20 (-0.72 to +0.32) | +0.25 (+0.08 to +0.43) |
| claude-opus-5-5 | +0.14 (-0.03 to +0.32) | +0.15 (-0.02 to +0.33) | +0.20 (-0.07 to +0.49) | +0.08 (-0.12 to +0.29) |
| claude-haiku-4-5-20251001 | +0.25 (-0.33 to +0.83) | +0.37 (-0.17 to +0.92) | +0.47 (-0.50 to +1.36) | +0.24 (-0.03 to +0.51) |
| all | -0.17 (-0.30 to -0.04) | -0.13 (-0.25 to -0.00) | -0.31 (-0.51 to -0.11) | +0.09 (+0.01 to +0.17) |

### Round 3 minus round 1 regret, by whether round 3 still decides the match

| model | level: seats | level: change | decided: seats | decided: change |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 | 315 | +0.68 (-0.08 to +1.44) | 313 | +0.05 (-0.73 to +0.85) |
| claude-haiku-5-5 | 457 | +0.11 (-0.20 to +0.42) | 391 | +0.05 (-0.34 to +0.44) |
| claude-opus-5-5 | 245 | +0.24 (-0.05 to +0.55) | 265 | +0.06 (-0.14 to +0.26) |
| claude-sonnet-5-5 | 382 | -0.61 (-1.02 to -0.20) | 470 | -0.21 (-0.57 to +0.14) |
| gpt-5.6-terra | 316 | +0.00 (-0.45 to +0.46) | 262 | -0.37 (-0.89 to +0.19) |
| gpt-6-astra | 132 | -0.11 (-0.44 to +0.20) | 141 | -0.21 (-0.63 to +0.22) |
| gpt-6-luna | 386 | -0.33 (-0.88 to +0.23) | 425 | -1.03 (-1.61 to -0.49) |
| gpt-6.1-sol | 348 | +0.08 (-0.14 to +0.29) | 306 | -0.05 (-0.25 to +0.15) |
| gpt-6.1-terra | 33 | +0.66 (-0.75 to +2.18) | 37 | -1.08 (-2.19 to -0.10) |

### Change within a match, per config

| model | effort | seats | regret, round 2 minus 1 | regret, round 3 minus 1 | win, round 2 minus 1 (points) | win, round 3 minus 1 (points) | round 3 regret |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 | off | 89 | -0.35 (-1.81 to +1.18) | +0.30 (-1.16 to +1.78) | -3.3 (-18.7 to +12.0) | +3.3 (-8.7 to +14.4) | flat |
| claude-haiku-4-5-20251001 | minimal | 90 | -0.30 (-1.49 to +0.86) | -0.14 (-1.29 to +1.12) | -5.5 (-19.8 to +8.7) | +0.0 (-14.1 to +12.2) | flat |
| claude-haiku-4-5-20251001 | low | 92 | +0.17 (-0.95 to +1.35) | +1.13 (-0.18 to +2.50) | +0.0 (-13.7 to +12.8) | +5.4 (-5.4 to +16.1) | flat |
| claude-haiku-4-5-20251001 | medium | 265 | +0.28 (-0.60 to +1.03) | +0.08 (-0.72 to +0.87) | -8.6 (-15.4 to -2.2) | -6.0 (-13.1 to +1.5) | flat |
| claude-haiku-4-5-20251001 | high | 92 | -0.39 (-1.63 to +0.86) | +1.01 (-0.48 to +2.51) | +7.4 (-6.2 to +20.4) | -9.6 (-21.1 to +3.2) | flat |
| claude-haiku-5-5 | off | 110 | -1.24 (-2.55 to -0.07) | -0.63 (-1.84 to +0.55) | -14.2 (-27.4 to -0.9) | -16.8 (-28.8 to -3.6) | flat |
| claude-haiku-5-5 | low | 116 | +0.19 (-0.43 to +0.79) | +0.42 (-0.17 to +1.00) | -7.4 (-19.0 to +3.4) | +4.1 (-8.3 to +16.8) | flat |
| claude-haiku-5-5 | medium | 292 | -0.32 (-0.66 to +0.03) | +0.01 (-0.36 to +0.39) | +0.7 (-6.8 to +7.8) | -3.4 (-10.9 to +4.7) | flat |
| claude-haiku-5-5 | high | 114 | +0.09 (-0.31 to +0.48) | +0.30 (-0.08 to +0.70) | -0.8 (-12.0 to +10.2) | -1.7 (-13.6 to +9.2) | flat |
| claude-haiku-5-5 | xhigh | 107 | -0.01 (-0.34 to +0.30) | +0.32 (-0.07 to +0.74) | +1.8 (-9.0 to +12.6) | +1.8 (-8.8 to +13.4) | flat |
| claude-haiku-5-5 | max | 109 | -0.16 (-0.45 to +0.11) | +0.20 (-0.12 to +0.58) | +16.2 (+6.3 to +26.1) | +5.4 (-4.5 to +15.5) | flat |
| claude-opus-5-5 | off | 20 | +0.04 (-1.26 to +1.12) | -0.73 (-1.57 to -0.07) | -4.3 (-31.8 to +25.0) | +4.3 (-18.2 to +27.3) | too few seats |
| claude-opus-5-5 | low | 42 | -0.54 (-1.14 to +0.01) | -0.56 (-1.05 to -0.12) | +11.4 (-4.8 to +27.3) | +4.5 (-11.9 to +20.5) | too few seats |
| claude-opus-5-5 | medium | 257 | +0.11 (-0.08 to +0.31) | +0.33 (+0.05 to +0.62) | -0.4 (-8.2 to +7.8) | -4.1 (-11.5 to +3.7) | worse |
| claude-opus-5-5 | high | 46 | +0.04 (-0.33 to +0.43) | +0.18 (-0.25 to +0.65) | +5.7 (-7.4 to +18.9) | -5.7 (-19.6 to +9.3) | too few seats |
| claude-opus-5-5 | xhigh | 105 | +0.24 (-0.04 to +0.52) | +0.14 (-0.13 to +0.42) | -4.5 (-15.2 to +7.3) | +1.8 (-8.9 to +12.6) | flat |
| claude-opus-5-5 | max | 40 | +0.14 (-0.22 to +0.49) | +0.16 (-0.08 to +0.41) | -7.5 (-27.5 to +12.5) | +0.0 (-15.0 to +15.0) | too few seats |
| claude-sonnet-5-5 | off | 112 | +0.16 (-1.06 to +1.42) | -0.79 (-1.83 to +0.18) | -10.9 (-21.0 to -0.8) | -5.9 (-16.9 to +5.1) | flat |
| claude-sonnet-5-5 | low | 111 | -0.22 (-1.14 to +0.80) | -0.02 (-0.85 to +0.85) | -12.6 (-22.0 to -3.3) | -5.0 (-17.0 to +8.4) | flat |
| claude-sonnet-5-5 | medium | 273 | -0.42 (-1.00 to +0.13) | -0.61 (-1.14 to -0.14) | +9.0 (+2.1 to +15.7) | +8.3 (+0.7 to +15.9) | better |
| claude-sonnet-5-5 | high | 113 | -0.48 (-1.22 to +0.20) | -0.43 (-1.12 to +0.22) | +1.7 (-9.2 to +10.9) | -8.3 (-18.0 to +0.9) | flat |
| claude-sonnet-5-5 | xhigh | 113 | -0.34 (-0.99 to +0.23) | -0.61 (-1.30 to +0.00) | -9.2 (-19.2 to +0.8) | -4.2 (-16.7 to +7.6) | flat |
| claude-sonnet-5-5 | max | 130 | +0.11 (-0.07 to +0.30) | +0.33 (+0.10 to +0.58) | +4.3 (-5.0 to +13.6) | +6.4 (-4.3 to +17.1) | worse |
| gpt-5.6-terra | low | 82 | -0.77 (-1.75 to +0.20) | -0.50 (-1.65 to +0.65) | +4.4 (-8.9 to +18.9) | +5.6 (-6.7 to +16.7) | flat |
| gpt-5.6-terra | medium | 241 | -0.64 (-1.23 to -0.08) | -0.64 (-1.22 to -0.06) | +2.7 (-4.7 to +10.5) | +1.6 (-7.0 to +10.2) | better |
| gpt-5.6-terra | high | 85 | -0.16 (-0.93 to +0.66) | +0.65 (-0.44 to +1.92) | -1.1 (-14.4 to +12.2) | +0.0 (-13.3 to +13.3) | flat |
| gpt-5.6-terra | xhigh | 86 | +0.35 (-0.31 to +0.94) | +0.32 (-0.21 to +0.83) | -2.2 (-15.6 to +11.1) | -3.3 (-16.7 to +10.0) | flat |
| gpt-5.6-terra | max | 84 | +0.27 (-0.15 to +0.69) | +0.22 (-0.16 to +0.59) | -1.1 (-14.4 to +11.1) | +5.6 (-5.6 to +16.7) | flat |
| gpt-6-astra | off | 6 | - | - | - | - | too few seats |
| gpt-6-astra | low | 13 | - | - | - | - | too few seats |
| gpt-6-astra | medium | 246 | -0.27 (-0.55 to +0.00) | -0.16 (-0.46 to +0.16) | +3.6 (-3.2 to +10.6) | +4.3 (-2.4 to +10.3) | flat |
| gpt-6-astra | high | 8 | - | - | - | - | too few seats |
| gpt-6-luna | off | 104 | -1.93 (-3.02 to -0.88) | -2.29 (-3.44 to -1.24) | +5.5 (-7.3 to +18.2) | +5.5 (-6.4 to +16.4) | better |
| gpt-6-luna | low | 103 | -0.83 (-2.00 to +0.29) | -0.97 (-2.23 to +0.20) | +9.1 (-3.6 to +21.8) | -4.5 (-14.5 to +6.4) | flat |
| gpt-6-luna | medium | 277 | -0.64 (-1.35 to +0.09) | -0.82 (-1.50 to -0.16) | -3.5 (-10.3 to +3.9) | -1.4 (-8.9 to +5.3) | better |
| gpt-6-luna | high | 106 | +0.14 (-0.93 to +1.06) | -0.09 (-1.31 to +1.01) | +2.7 (-9.1 to +14.5) | +5.5 (-8.2 to +19.1) | flat |
| gpt-6-luna | xhigh | 110 | +0.23 (-0.72 to +1.08) | +0.06 (-0.81 to +0.91) | -4.4 (-14.9 to +6.1) | +4.4 (-7.0 to +14.9) | flat |
| gpt-6-luna | max | 111 | -0.13 (-0.81 to +0.56) | +0.02 (-0.58 to +0.60) | -0.9 (-12.5 to +10.7) | +5.4 (-7.1 to +17.0) | flat |
| gpt-6.1-sol | low | 90 | +1.01 (+0.50 to +1.59) | +0.07 (-0.40 to +0.47) | -6.2 (-14.6 to +2.1) | -4.2 (-14.6 to +7.3) | flat |
| gpt-6.1-sol | medium | 261 | -0.06 (-0.40 to +0.32) | -0.15 (-0.41 to +0.09) | +4.8 (-1.9 to +12.2) | -2.2 (-8.9 to +4.4) | flat |
| gpt-6.1-sol | high | 92 | +0.01 (-0.38 to +0.40) | +0.10 (-0.27 to +0.48) | -4.1 (-14.3 to +6.1) | -4.1 (-15.3 to +7.1) | flat |
| gpt-6.1-sol | xhigh | 96 | +0.10 (-0.19 to +0.37) | +0.16 (-0.17 to +0.47) | +2.0 (-8.0 to +12.0) | +11.0 (+1.0 to +21.0) | flat |
| gpt-6.1-sol | max | 115 | +0.41 (+0.15 to +0.68) | +0.16 (-0.15 to +0.48) | +4.1 (-5.7 to +13.9) | +0.8 (-9.8 to +10.7) | flat |
| gpt-6.1-terra | off | 11 | - | - | - | - | too few seats |
| gpt-6.1-terra | low | 11 | - | - | - | - | too few seats |
| gpt-6.1-terra | medium | 20 | -0.84 (-2.66 to +1.23) | -1.02 (-2.63 to +0.69) | +9.5 (-10.5 to +30.0) | +33.3 (+4.5 to +61.9) | too few seats |
| gpt-6.1-terra | high | 10 | - | - | - | - | too few seats |
| gpt-6.1-terra | xhigh | 14 | - | - | - | - | too few seats |
| gpt-6.1-terra | max | 4 | - | - | - | - | too few seats |

### What chance alone would give

36 of 49 configs have 80 or more seats with a regret in rounds 1 and 3. Per delta, with a 95% interval, about 0.9 should land on each side by chance alone.
- regret, round 2 minus 1: 3 better, 2 worse, 31 flat. 3 survive Benjamini-Hochberg at 5%.
- regret, round 3 minus 1: 4 better, 2 worse, 30 flat. 1 survive Benjamini-Hochberg at 5%.
- win, round 2 minus 1: 2 better, 4 worse, 30 flat. 0 survive Benjamini-Hochberg at 5%.
- win, round 3 minus 1: 2 better, 1 worse, 33 flat. 0 survive Benjamini-Hochberg at 5%.

8 of 9 models have 80 or more seats with a regret in rounds 1 and 3. Per delta, with a 95% interval, about 0.2 should land on each side by chance alone.
- regret, round 2 minus 1: 2 better, 1 worse, 5 flat. 1 survive Benjamini-Hochberg at 5%.
- regret, round 3 minus 1: 2 better, 0 worse, 6 flat. 2 survive Benjamini-Hochberg at 5%.
- win, round 2 minus 1: 0 better, 1 worse, 7 flat. 1 survive Benjamini-Hochberg at 5%.
- win, round 3 minus 1: 0 better, 0 worse, 8 flat. 0 survive Benjamini-Hochberg at 5%.
<!-- round-improvement:end -->
