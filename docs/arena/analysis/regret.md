# Regret

How good each agent move was, by the minimax search of the Rust evaluator in `sim/rust/` ([ADR-0052](../../adr/0052-rust-evaluator.md)), which is checked against the Bend minimax player in `sim/bend-mp/player/` ([ADR-0043](../../adr/0043-minimax-player.md)). For every agent decision the search scores each legal move from the deciding player's own information. Regret is the best move's score minus the chosen move's score. `tools/arena/score_regret.py` scores every replay-validated decision of the analysis database that has no row yet, or the matches or decisions a list names. [net-points.md](net-points.md) sums it per match and seat.

Until 2026-11-08 the rows came from the Bend player, through `web/scripts/arena-regret.ts`. That script is removed. The Bend rows stay in the older files and in the sections below that were measured with them.

## Production scoring

Since 2026-11-08 the production rows come from the Rust evaluator. `tools/arena/score_regret.py` (the wrap-up's regret step) builds `buckshot-search` with the `f64` and `seats-2` features (arena matches have two seats; the parser refuses wider tables) and runs `--unpruned` at depth 6 and 20,000 nodes (the f64 build's only evaluator is `bounded-v1-f64`, so the CLI takes no `--evaluator`). Unpruned, every move's value is exact at the depth reached, which the replay's move list needs. Every decision gets a sampled-reload row (256 deals). A regret file holds one run (evaluator, depth, budget, reload rule, samples), and the production file is the one `PRODUCTION` in `tools/arena/analysis/regret.py` names, now `derived/regret-rust-bounded-v1-sampled256.sqlite`: the viewer, the export, the certain-mistakes database and every doc table on these pages read it, and each stops on a file with more than one run; `score_regret.py` itself stops, before scoring, on an output file that holds another run. Static-reload rows (`--out`) are for research only. The positions come from `web/scripts/rust-search-inputs.ts`, which replays each match as described below. Their `evaluator` is `bounded-v1-f64-unpruned`, the evaluator's declared algorithm version (see The evaluator id), and an `evaluator_build` table records each run's commit, source hash, binary hash, row count and time. `ms` is empty: the search runs decisions in parallel and times none alone. The older Bend rows (`regret.sqlite`, player `a3962092b561cfb4`, and `regret-sampled256-native.sqlite`, `09c5bda32435eda8`) stay as they were.

The budget means something else here. `bounded-v1` counts nodes only: it has no fuel, and a memo hit costs nothing. So at the same 20,000 nodes it finishes deeper iterations than the Bend player on the decisions the old budget cut short. Before the switch, 2,000 random static rows and 2,000 random sampled rows were scored both ways:

- Static: on the 1,566 decisions where both reached the same depth, every move's value agreed within 1 millionth, and one best move differed, on a tie within 1 millionth. Rust went deeper on 434 (21.7%) and never shallower. All 434 were rows the old budget had stopped at depth 2 to 5. There the best move differed in 113 and the regret in 195, by a point or more in 112 and by 5 or more in 25.
- Sampled: on the 1,933 at the same depth, values agreed within 1 millionth and regrets within 2, with no best move changed. Rust went deeper on 67 (3.4%), changing the best move in 12 and the regret in 13, by 5 points or more in 4.
- Mean regret over the sample hardly moved: 2.359 points against 2.362 static, 1.608 against 1.611 sampled. 78 moves lost 15 points or more, against 80.

The full rescore of 2026-11-08 (snapshot of the analysis database that day) wrote 181,311 static rows (181,308 searched, the same 3 invalid as before) and 62,045 sampled rows (3 invalid), 598 more sampled decisions than the old file covered. Its time is in Runtime. The budget now stops 29% of static searches before depth 6 (39% before) and 0.6% of sampled ones (3.3% before). Mean regret is 2.31 points static (2.30 before) and 1.74 sampled (1.75 before).

The rescore of 2026-11-09 (evaluator `bounded-v1-f64-unpruned-0e62fbca19077e85`) scored all 184,388 agent decisions both ways, every one searched: sampled in 82 minutes, static in 2, on 6 threads. Mean regret over every row is 1.87 points sampled and 2.31 static. From then on the production run is the sampled one alone. Until 2026-11-11 the id carried a hash of the Rust sources, so every refactor forced a full rescore, as follows. Later changes to the Rust sources gave the evaluator a new id, `bounded-v1-f64-unpruned-39a1a62064e75de8`, so the tournament 11 wrap-up rescored all 185,710 decisions, sampled, into a new file in 89 minutes on 6 threads; the 184,388 decisions both runs cover got the same values. The Rust cleanups that followed gave it the id `bounded-v1-f64-unpruned-c89fc327422c68ac`, and the re-import of 2026-11-10 rescored all 185,710 decisions into a new file in 92 minutes on 6 threads; every row got the same values. The Rust CLI cleanup (dropping `--stats` and the f64 build's `--evaluator`) gave it the id `bounded-v1-f64-unpruned-ced80df221f27e04`, and the re-import of 2026-11-11 rescored all 185,710 decisions into a new file in 102 minutes on 6 threads; every row got the same values. Since then the id is the declared version alone: the `ced80df2` rows were re-keyed to `bounded-v1-f64-unpruned` without a rescore (the sources still hash to `ced80df2` and the golden set passes), into `derived/regret-rust-bounded-v1-sampled256.sqlite`, whose `evaluator_build` keeps the source hash in `sources_sha256`.

### The evaluator id

The id is `BoundedV1::ID` (`sim/rust/search/src/searcher.rs`) plus `-unpruned`: `bounded-v1-f64-unpruned`. It names the algorithm, not the build. `sim/rust/search/tests/golden/` holds 300 production decisions, drawn at random from the `ced80df2` run, as positions only (the number line the player reads, move labels and scores, no match ids or names). The f64 build must reproduce every score, best move, depth, cut and node count bit for bit, on both table builds (`sim/rust/check.sh` runs it in release). So a refactor that keeps the golden set keeps the id and needs no rescore. A change meant to move a value (the search, the leaf evaluation, the rules) bumps the version in `BoundedV1::ID` and in `CLI_EVALUATOR` (`score_regret.py` stops when they differ), and regenerates the golden set from the new rows; the bumped id then needs a full rescore into a new file. The source hash stays in `evaluator_build` as build metadata.

## How it is measured

`tools/arena/score_regret.py` takes the agent decisions of the replay-validated matches of the analysis database ([database.md](../database.md)) that its output has no row for. `web/scripts/rust-search-inputs.ts` replays each match through `replayOf`, as `arena-knowledge.ts` does. Before each agent move it builds the position as the deciding player sees it: the match configuration, the public board, and the player's whole log (every public event and its own secrets, in the order it heard them), with the menu in the player's move order and the shells left. The hidden gun and other players' secrets never enter. TypeScript only marshals these values into numbers (`web/src/analysis/native-input.ts`). `buckshot-search` scores every move of each position, and the script turns each result into a row. Forced grabs and fallback moves are not scored: only decisions made by an agent are. The Bend player (`sim/bend-mp/analysis.bend`) stays the source of the rules and is the reference the Rust search is checked against ([ADR-0052](../../adr/0052-rust-evaluator.md)).

A score is the deciding player's chance of winning the current round, in millionths. Divide by 10,000 for a percentage; a regret of 10,000 is one percentage point. Opponents are modelled as minimizing it from public information.

- **Searched:** the search finished at least one depth. Regret is set, and is 0 for the best move.
- **Fallback:** no depth finished, because the node budget ran out first or the run asked for depth 0. Every move gets the same static value; the regret is NULL, never 0.
- **Invalid:** only in the older Bend rows and the rows written before 2026-11-09: the player could not build a belief from the log, or the Rust parser refused the position. The 3 invalid rows of the 2026-11-08 rescore are item grabs of match `4f16575f…` (ordinals 60, 72 and 81) whose run log records them as the agent's; a menu of one move is no choice, so the scorer no longer takes them.

**Bend and Rust must agree.** For every decision the scorer checks that Rust's root moves (each line's `code`, as `show.move` prints it) are Bend's menu, move by move, and that neither side refuses the position. On any difference it writes no row: it writes one JSON dump per disagreement into `<output>-bugs/` next to the output database (match id, ordinal, the input line exactly as fed to `buckshot-search` and its command, Bend's menu and codes, Rust's whole row, the evaluator id, features, binary hash and commit), prints their paths and exits non-zero after that input file.
- **Exact:** both the best and the chosen score are 0 or 1,000,000. Only a settled round gives those scores: a win, or a loss, which a dead player's 0 always is. Treat only exact rows as solved. `exact = 0` means not proven exact, not heuristic. Take both players at 1 health with one live and one blank shell left. Shooting the other player settles the round on every path, but its score of 500,000 is a mix of a win and a loss, so the row is not marked exact. The search does not report which values are settled.

The reload rule says how a search values a reload it stops at. `static` is the static evaluation before the draw. `sampled` averages that evaluation over `--samples` deals (256 by default) drawn at random as the machine asks for them, seeded by the state the deal starts from, so a rerun gives the same rows. Both rules search the same tree and spend the same nodes, so where no line reaches a reload they give the same scores. Production scores every decision `sampled`. The `static` rule is for research and costs almost nothing, so `--out` can still write it. Both rules work at two seats only.

The Bend player had a third rule, `expected-deal`: the static evaluation averaged over every distinct deal of the reload (item amount, the items each seat takes, the batch and the shuffle, each weighted by its chance, with deals counted as multisets). It was exact but too slow for a run over many decisions (see Runtime), so the sampled rule replaced it: on real leaves it was about 700 times faster and agreed with the exact value within its standard error. The Rust search has no `expected-deal` rule.

## The `regret` table

`score_regret.py` writes the `regret` table of the derived database named by `--sampled-out` (sampled rows, the production run) and of the one named by `--out` (static rows, for research), creating each if needed and leaving other tables alone, so a file can share tables with the knowledge database. It also writes an `evaluator_build` table: for each run, the evaluator id, settings, source commit (`+dirty` if `sim/rust` has uncommitted changes), features, binary hash, decisions scored, seconds, threads and `sources_sha256`, the hash of the Rust sources, Cargo files and features. Rows are keyed by match, ordinal, evaluator, depth limit, budget, reload rule and sample count. The script reads the keys already in the file and scores only the agent decisions without one, so a rerun continues where it stopped, and after an import only the new matches are scored. Rows are committed every 512, so an interrupted run loses at most that many and scores them again. Two runs must not write one file at the same time. Only a version bump changes the evaluator id (see The evaluator id); then every decision counts as unscored: a regret database holds one run, and a changed evaluator needs a full rescore into a new file.

| Column | Meaning |
|---|---|
| `match_id`, `ordinal` | The decision, as in the analysis database's `decisions`. |
| `player`, `label` | The deciding player's letter and the move it chose. |
| `evaluator` | `bounded-v1-f64-unpruned`, the declared version (rows before 2026-11-11 add a hash of the Rust sources; the Bend rows: a hash of the compiled player). Never mix rows with different values. |
| `max_depth`, `budget` | The run's depth limit (decisions, by every player) and node budget (nodes expanded; in the Bend rows, a fuel count). |
| `reload`, `samples` | `static` or `sampled`, and the deals per leaf of a sampled run (0 for static); `samples > 0` exactly when `reload` is `sampled`. The Bend rows can also be `expected-deal`. A file holds one run, so the viewer and the Python reports read every row of the file they are given. |
| `status` | `searched` or `fallback` (`invalid` in older rows). |
| `values_json` | Every legal move with its score, in the player's move order. |
| `best`, `best_score`, `chosen_score`, `regret`, `exact` | Set only when searched. Ties go to the first move. `exact` is 1 when proven exact, 0 when not proven (see above). |
| `depth`, `limited` | The depth the search finished, and whether the budget stopped it there. |
| `nodes`, `ms` | Nodes expanded and milliseconds spent on the decision (`ms` is empty in the Rust rows: the search runs decisions in parallel and times none alone). |

## Runtime

With the Rust evaluator (depth 6, 20,000 nodes), the full rescore of 2026-11-08 wrote 181,311 static rows and 62,045 sampled rows in 26 minutes on the local server with 6 search threads: 6 minutes writing the inputs (6 processes), 3.4 minutes of static search and 16.5 of sampled. The Bend player needed about 17 hours for the static rows alone in one process (below). After an import, only the new matches are scored, so a wrap-up spends minutes here.

### The Bend player, measured in October 2026 (historical)

These numbers are from the Bend player and `arena-regret.ts`, both removed from the production path on 2026-11-08. They are kept as the record of what the exact and sampled reload rules cost.

With the defaults, depth 6 and a budget of 20,000 nodes, 7 matches (352 decisions) on the local server took 344 ms per decision on average: median 274 ms, 95th percentile 804 ms, max 1,070 ms. 39% of the searches were stopped by the budget, at depth 2 to 5. At that rate the 179,642 agent decisions take about 17 hours in one process.

The expected-deal rule is far slower, because each reload leaf enumerates the deal exactly. On 12 agent shots from finished two-seat matches, 6 with 2 shells left and 6 with 3, sampled with a fixed seed, at depth 6 and 20,000 nodes on the local server:

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

    nice -n 10 python3 tools/arena/score_regret.py --db <buckshot.sqlite> --sampled-out <derived>/regret-rust-<version>-sampled256.sqlite [--out <static rows>] [--depth 6] [--budget 20000] [--samples 256] [--threads N] [--jobs N]

It scores the agent decisions of replay-validated matches that the files have no row for, so it continues an interrupted run and scores only new matches after an import. `--matches <file>` (match names, one per line) and `--decisions <file>` (one `<match id> <ordinal>` line per decision, the ids of the analysis database) limit it to those; every named decision must be an agent decision of a replay-validated match, or it stops. Give `--sampled-out`, `--out` or both. `--work DIR` keeps the inputs and logs. It prints a JSON summary: the evaluator id, the decisions, and rows and seconds per reload rule.

The wrap-up (`tools/arena/wrap_tournament.py`) runs the same code in its `regret` step. It copies the live production file to a staged file, scores the new matches of its snapshot into it with the sampled rule, and stops unless the staged file still holds one run. Its certain, export and doc steps read the same file. A second run in the staged file means the evaluator version changed: rescore everything into a new file (`--regret` names it, by default the `PRODUCTION` file) instead.

Rows scored by the removed Bend player cannot be extended: the old files (`regret.sqlite`, hash `a3962092b561cfb4`, and `regret-sampled256-native.sqlite`) hold a different evaluator. The Rust evaluator reproduces the Bend rows within 1 millionth where both reach the same depth (see Production scoring), and `sim/rust/search/tests/production/` pins it to them. `sim/rust/search/tests/golden/` pins the current evaluator to the production Rust rows.

The summary tables below come from the regret and knowledge databases, read only, in a few seconds:

    python3 tools/arena/analysis/regret.py [--regret <production file>] [--knowledge <derived>/knowledge.sqlite] [--doc docs/arena/analysis/regret.md]

With `--doc` it rewrites the tables at the end of this page. `tools/arena/analysis/reload_bias.py` draws the stratified lists (`sample`) and rewrites the tables of the Reload bias section from a `sampled` run (`report --doc`), reading the sampled and static runs read only. The by-round tables come from `tools/arena/analysis/by_round.py`, which also reads the analysis database for round winners (`--db`) and rewrites the tables of the last section the same way. `tools/arena/analysis/regret_depth.py` does the same for the Deeper search section: `sample` draws the lists, and `report --doc` rewrites its tables from the deep run (`regret-depth.sqlite`). The Reload bias and Deeper search runs were scored with the removed Bend player (depth 8 and 200,000 nodes for the deep one), so they cannot be rerun as written. The Reload bias report still reads its stored rows. The Deeper search report stops: its depth 8 rows and the production depth 6 rows were scored by different evaluators (`regret_depth.py` checks), so its tables below are the earlier result and are not regenerated. `tools/arena/analysis/round_improvement.py` rewrites the within-match tables of the By round section (`--doc`, and `--svg DIR` for its figures). `python3 -m unittest discover -s tools/arena/analysis` runs its tests.

`bun scripts/arena-regret-consistency.ts <regret file>`, from `web/`, checks every searched row, read only: `values_json` decodes, its top score is `best_score`, the chosen move is in it with `chosen_score`, and `regret` is `best_score` minus `chosen_score`. It prints the count of each mismatch and fails on any. The viewer's replay reads the same rows and refuses a match with a malformed one.

## Results

Scope: 3,536 scored matches with no DeepSeek seat, from the 3,557-match snapshot of 2026-11-04. This is a casual pass over the full run, with counts and means and no intervals. It covers the 179,642 agent decisions of those matches (DeepSeek is left out as in [matchups.md](matchups.md)). Every one has a row, every row was searched, and none fell back. The rows of the run also hold DeepSeek's matches and unfinished ones. All rows come from one run, sampled reload with 256 deals (see Production scoring). A config is a model with its effort, pooled over the tournaments it played in. Regret is in percentage points of the round win chance, as above. Mean regret over all decisions is 1.9 points and the 90th percentile 4.0. 11.3% of the decisions are exact.

1. **Regret and the ratings agree at the ends.**
   - At medium effort the mean regret is Opus 0.9, Astra 0.9, Sol 1.0, Haiku 5.5 1.6, Sonnet 1.7, Terra 2.2, Luna 3.4 and Haiku 4.5 4.0 points. Terra 6.1 (1,976 decisions) is 1.4.
   - The cross-model ratings in [matchups.md](matchups.md) put the same three on top (Astra first) and Luna and Haiku 4.5 at the bottom, in the other order. The four in between overlap in rating, and regret does not separate them further. Regret uses no match results, so it agrees from the other side.
2. **More effort mostly lowers regret. Sol and Opus barely move.**
   - Haiku 5.5 goes from 3.2 at off to 0.7 at max, Sonnet from 1.9 to 0.6, Luna from 3.4 to 1.7, Terra from 2.5 at low to 1.0 at max. Haiku 4.5 moves less, from 5.0 at off to 4.0 at high. The steps are not always in order: Luna is 3.4 at off and 3.8 at low. The 90th percentile falls with it: Haiku 5.5 6.5 to 1.9, Sonnet 4.2 to 1.5.
   - Sol (0.7 to 1.1) and Opus from off to xhigh (0.8 to 1.1) change by 0.4 points or less. Opus max, with 2,180 decisions from 80 matches, and Sonnet max are 0.6, the lowest cells of the table. Sol is flat in the rating sweep too. Opus is not: its xhigh rating is far above its low, yet its regret moves by 0.3 points. Regret does not explain that gap.

**Near reloads.** Regret concentrates in shots with two or three shells left in the gun.
- Those shots average 2.9 and 3.1 points, with a 90th percentile of 5.5 and 9.3. A shot with one shell left averages 1.5 and one with five left 1.9.
- Item moves stay between 0.8 and 2.3 at every distance, lowest with two shells left. In this cut they show no sign of a reload effect.
- The node budget does not explain the rise. It stopped 1.0% and 12.5% of the searches with two and three shells left, against 0.0% at one shell left.
- This shows where regret is, not why. These rows already value a reload over sampled deals, so the static leaf's bias (the Reload bias section below) is not the cause; with the static leaf the same shots averaged 4.5 and 3.7. Real mistakes on near-even shells remain a cause.

## Reload bias

This section and Deeper search measure fixed samples drawn from the 2026-10-26 run of 125,150 decisions (tournaments 1 to 4). They were not redrawn for tournaments 5 and later, and their sizes and weights below are that run's.

This measures the bias of the static leaf near reloads. 2,853 agent decisions of the run above were scored again with the `sampled` rule (64 deals per leaf, depth 6, 20,000 nodes) and set beside the static score of the same decision, matched by match, ordinal, depth and budget. The sample covers two-seat matches only, with no DeepSeek seat, and is stratified by shells left in the gun, shot or item move, and model. The means below weight each stratum by its size in the whole run of 125,150 decisions, and the intervals are 95%. Both rules search the same tree, so every difference comes from the leaf. On 38 decisions scored with 256 deals as well, 64 deals gave a similar mean regret to 256, 0.04 ± 0.07 points more. That is a mean over 38 decisions. It does not show that the two agree on every chosen move or in the tail. The exact rule of #4 takes hours per decision (see Runtime), so this uses the sampled rule, which matched the exact value on 24 leaves within noise. It is still the static evaluation after a drawn deal and not the truth. Lower regret under it means the static leaf and the draw disagree, and the draw sees more.

1. **A reload is in reach for most decisions.**
   - In 78.7% of all decisions the gun holds no more shells than the depth the static search reached, so some line of the search empties it. Shots and item moves with 1 to 3 shells left are always in reach. With 6 left, 9% of shots and 0.5% of item moves are.
   - Where none is in reach the two rules gave the same scores in all 222 sampled decisions. Where one is, a score changed in 2,379 of 2,631 sampled decisions (90%). Over all decisions the best move changed in 11%.
2. **The static leaf overstates regret near reloads, by about 0.4 points overall.**
   - Mean regret falls from 2.50 to 2.07 points (-0.43 ± 0.08). With 3 or fewer shells left it falls by 0.64 ± 0.12 from 2.73, and with 4 or more by 0.16 ± 0.10 from 2.19.
   - The largest cell is shots with 2 shells left, from 4.59 to 3.35 (-1.24 ± 0.35), and the best move changes in 17%. Item moves with 2 left fall from 1.73 to 0.94 (-0.79 ± 0.22). Shots overall move by -0.46 ± 0.12 and item moves by -0.40 ± 0.11, so item moves are not the main victim.
   - About half of the extra regret that 2-shell shots show over 1-shell shots is the leaf (2.21 static, 1.18 sampled). The other half stays, so the leaf does not explain the bump on its own.
3. **Model rankings hold.** Every model's mean regret falls by 0.3 to 0.6 points. The order is the same except that the top two, Opus and Sol, swap (1.19 and 1.22 static, 0.86 and 0.84 sampled), a gap within noise.
4. **Moves that spend an item score lower under the sampled rule, and shots at the opponent higher.** Over the sampled moves whose score changed, unweighted, the mean shift is -2.6 points for steals, -2.0 for cigarettes, -1.8 for the magnifying glass, -1.2 for beer, -0.7 for the handsaw and -0.2 for the inverter, and +0.3 for shooting the opponent. The shift does not follow the item weights of the evaluation. Beer, at 25, moves more than the handsaw, at 65. So a term for the value of coming items would not obviously recover it.

**Recommendation (2026-10, superseded).** Keep the static leaf as the default. Since the 2026-11-09 rescore the production run uses the sampled leaf for every decision (Production scoring), which the Rust evaluator made cheap.
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
- Reloads are leaves: a search stops at the next reload. Under the static rule a move that empties the gun is valued before the next load is drawn. Production averages that value over 256 sampled deals, but still stops at the next choice.
- The static evaluation's item weights are untrained starting values, so heuristic regrets carry its biases. Read small regrets with care.
- Regret is a mean over decisions, not over matches. Decisions of one match are not independent, and a config's opponents differ between tournaments. Treat gaps of a few tenths of a point as noise.
- The intervals in Deeper search cover only the sampled decisions of this fixed run. They do not cover matches, seed blocks, tournaments or future play.
- A regret of 0 means the chosen move tied the best score at the depth reached, not that it was proven right. Only the 11% of exact rows are.
- 29% of the searches were stopped by the budget at depth 1 to 5. With five or more shells left most are, so those rows compare shallower searches. A search to depth 8 with ten times the budget gives similar mean regrets and the same observed model order in a sample of this run (Deeper search), but still stops 30% of the time.

## Tables

<!-- tables:start -->
217,292 searched decisions; 0 left out for having no search; 3 agent decisions with no row.

### Regret by config

| model | effort | decisions | mean regret | 90th percentile | exact |
|---|---|---|---|---|---|
| claude-opus-5-5 | off/low | 4,021 | 1.0 | 2.5 | 12.1% |
| claude-opus-5-5 | medium | 8,528 | 0.9 | 2.5 | 12.9% |
| claude-opus-5-5 | high | 1,985 | 0.9 | 2.4 | 11.8% |
| claude-opus-5-5 | xhigh | 4,313 | 0.7 | 2.0 | 11.9% |
| claude-opus-5-5 | max | 2,180 | 0.6 | 1.5 | 13.7% |
| gpt-6.1-sol | low | 2,284 | 1.1 | 2.6 | 12.1% |
| gpt-6.1-sol | medium | 6,746 | 1.0 | 2.6 | 12.8% |
| gpt-6.1-sol | high | 2,458 | 0.8 | 2.5 | 12.4% |
| gpt-6.1-sol | xhigh | 2,527 | 0.7 | 2.0 | 13.3% |
| gpt-6.1-sol | max | 3,686 | 0.7 | 2.2 | 11.3% |
| gpt-6-astra | off | 2,103 | 1.0 | 2.4 | 11.9% |
| gpt-6-astra | low | 1,992 | 0.9 | 2.1 | 13.6% |
| gpt-6-astra | medium | 6,298 | 0.9 | 2.4 | 13.2% |
| gpt-6-astra | high | 2,641 | 1.0 | 2.6 | 13.3% |
| gpt-6.1-terra | off/low | 5,907 | 1.8 | 3.6 | 12.4% |
| gpt-6.1-terra | medium | 3,208 | 1.4 | 2.9 | 13.2% |
| gpt-6.1-terra | high | 2,162 | 1.1 | 2.8 | 11.9% |
| gpt-6.1-terra | xhigh | 2,694 | 1.0 | 2.4 | 13.1% |
| gpt-6.1-terra | max | 2,963 | 0.7 | 2.1 | 13.5% |
| claude-sonnet-5-5 | off | 3,996 | 1.9 | 4.2 | 11.4% |
| claude-sonnet-5-5 | low | 3,682 | 1.9 | 4.4 | 11.2% |
| claude-sonnet-5-5 | medium | 8,949 | 1.7 | 3.8 | 12.4% |
| claude-sonnet-5-5 | high | 3,930 | 1.2 | 3.1 | 11.1% |
| claude-sonnet-5-5 | xhigh | 4,455 | 0.9 | 2.4 | 13.1% |
| claude-sonnet-5-5 | max | 3,572 | 0.6 | 1.5 | 14.8% |
| gpt-5.6-terra | low | 2,127 | 2.5 | 5.6 | 10.4% |
| gpt-5.6-terra | medium | 6,108 | 2.2 | 4.6 | 11.1% |
| gpt-5.6-terra | high | 2,166 | 2.2 | 4.4 | 11.4% |
| gpt-5.6-terra | xhigh | 2,409 | 1.5 | 3.5 | 11.4% |
| gpt-5.6-terra | max | 2,489 | 1.0 | 2.5 | 10.2% |
| claude-haiku-5-5 | off | 16,317 | 3.2 | 6.6 | 9.3% |
| claude-haiku-5-5 | low | 7,108 | 1.8 | 4.1 | 10.5% |
| claude-haiku-5-5 | medium | 11,252 | 1.6 | 3.7 | 11.6% |
| claude-haiku-5-5 | high | 5,605 | 1.3 | 3.2 | 11.2% |
| claude-haiku-5-5 | xhigh | 3,935 | 0.9 | 2.7 | 11.4% |
| claude-haiku-5-5 | max | 2,825 | 0.7 | 1.9 | 13.3% |
| gpt-6-luna | off/low | 11,380 | 3.5 | 8.8 | 7.7% |
| gpt-6-luna | medium | 10,792 | 3.4 | 8.4 | 8.7% |
| gpt-6-luna | high | 6,136 | 2.5 | 5.8 | 11.6% |
| gpt-6-luna | xhigh | 3,251 | 2.0 | 4.1 | 13.7% |
| gpt-6-luna | max | 3,244 | 1.7 | 3.9 | 13.2% |
| claude-haiku-4-5-20251001 | off | 3,272 | 5.0 | 12.8 | 7.1% |
| claude-haiku-4-5-20251001 | minimal/low | 7,585 | 3.9 | 9.4 | 6.7% |
| claude-haiku-4-5-20251001 | medium | 8,550 | 4.0 | 9.7 | 7.5% |
| claude-haiku-4-5-20251001 | high | 3,461 | 4.0 | 9.6 | 7.4% |
| all |  | 217,292 | 2.0 | 4.2 | 11.0% |

### Regret by shells left in the gun

| shells left | stopped by budget | shots | mean | 90th percentile | item moves | mean | 90th percentile |
|---|---|---|---|---|---|---|---|
| 1 | 0.0% | 21,956 | 1.6 | 3.8 | 9,589 | 1.4 | 3.8 |
| 2 | 1.1% | 22,506 | 3.2 | 6.6 | 18,443 | 0.9 | 2.1 |
| 3 | 12.7% | 21,841 | 3.3 | 10.1 | 26,448 | 1.3 | 2.8 |
| 4 | 37.8% | 17,322 | 2.5 | 7.5 | 24,829 | 1.4 | 3.7 |
| 5 | 67.4% | 12,159 | 2.1 | 6.6 | 20,972 | 1.9 | 4.7 |
| 6 | 89.2% | 6,838 | 1.9 | 5.8 | 14,389 | 2.4 | 5.0 |
<!-- tables:end -->

## By round

Does a model play the short early rounds differently from the later, item-heavy ones? This is a casual pass, with counts in brackets and no intervals, over the same 3,536 finished matches with no DeepSeek seat. The last subsection follows each seat within its own match, with intervals. It was not regenerated for tournaments 7, 8 and 9 and covers 2,722 matches. Round winners come from the replayed match events. Rounds are numbered from 1. A win rate is the share of its rounds a config won, against whoever it met, so it also reflects the opponents' strength.

1. **No config's win rate clearly changes by round.**
   - Pooled over efforts, a model's win rate moves by 4 points or less between rounds for all nine models. Astra goes from 59.3% to 61.5% and 60.1% over 494, and Haiku 4.5, the largest mover, from 41.3% to 37.7% and 39.2% over 892.
   - Per config the cells hold 80 to 342 rounds, so gaps of 10 points are common at 110 rounds and say little. The largest swings are Haiku 4.5 high, at 42.2%, 51.1% and 33.3% over 135 rounds, Astra off at 61.3%, 62.5% and 45.0% over 80, Terra 6.1 off at 56.2%, 66.2% and 48.8% over 80, and Haiku 5.5 max at 51.4%, 67.6% and 56.8% over 111. Haiku 5.5 off falls from 45.0% to 36.6% and 38.1% over 202. None is a steady trend across the other efforts.
2. **Regret is flat across rounds, except that round 1 shots are a little worse.**
   - Mean regret over all moves is 1.9, 1.8 and 1.9 points in rounds 1, 2 and 3. In every round the same three, Opus, Sol and Astra, are lowest and Haiku 4.5 is highest.
   - Shots cost 2.5 points in round 1 against 2.2 and 2.3 later. Item moves stay at 1.3 to 1.5. The table does not say why. Decisions of one match are not independent, so the gap is small evidence.
   - Round 3 is a dead rubber when one seat leads 2-0: the prizes are 70k, 75k and 80k, so the winner is settled. That is 1,852 of 3,709 round 3s. Models play them a little worse, not much. Mean regret per decision in round 3, live against dead: Opus 0.82 and 0.88, Sol 0.72 and 0.90, Astra 0.78 and 1.11 points (production run). The trailing player wins exactly half of them (926 of 1,852), so there is no sign that the leader coasts or the trailer gives up. Round Elo keeps dead rubbers in, which is defensible at this size of difference. The table "Round 3 minus round 1 regret, by whether round 3 still decides the match" splits the regret change by it.

<!-- by-round:start -->
12,786 rounds of finished matches.

### Win rate and regret by round, per model

| model | effort | round 1 win rate | round 1 mean regret | round 2 win rate | round 2 mean regret | round 3 win rate | round 3 mean regret |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 | all | 54.7% (824) | 0.8 (6,767) | 54.7% (824) | 0.9 (7,361) | 54.6% (824) | 0.9 (6,899) |
| gpt-6.1-sol | all | 53.4% (711) | 0.8 (5,427) | 54.4% (711) | 0.9 (6,354) | 53.2% (711) | 0.8 (5,920) |
| gpt-6-astra | all | 58.9% (514) | 0.9 (4,206) | 61.1% (514) | 0.9 (4,365) | 60.3% (514) | 0.9 (4,463) |
| gpt-6.1-terra | all | 60.7% (656) | 1.3 (5,708) | 56.9% (656) | 1.4 (5,517) | 58.2% (656) | 1.3 (5,709) |
| claude-sonnet-5-5 | all | 48.5% (1,164) | 1.5 (8,720) | 48.4% (1,164) | 1.4 (10,366) | 49.3% (1,164) | 1.3 (9,498) |
| gpt-5.6-terra | all | 48.9% (624) | 2.0 (4,764) | 49.5% (624) | 1.9 (5,273) | 50.8% (624) | 1.9 (5,262) |
| claude-haiku-5-5 | all | 45.1% (1,882) | 2.1 (14,938) | 47.2% (1,882) | 1.9 (15,949) | 47.9% (1,882) | 2.0 (16,155) |
| gpt-6-luna | all | 38.2% (1,239) | 3.2 (10,997) | 42.2% (1,239) | 2.9 (12,148) | 41.6% (1,239) | 2.9 (11,658) |
| claude-haiku-4-5-20251001 | all | 41.2% (910) | 4.1 (7,459) | 37.9% (910) | 3.9 (7,919) | 39.3% (910) | 4.3 (7,490) |
| all |  | - | 2.1 (68,986) | - | 1.9 (75,252) | - | 2.0 (73,054) |

### Mean regret by round and kind of move

| round | all moves | shots | item moves |
|---|---|---|---|
| 1 | 2.1 (68,986) | 2.7 (33,153) | 1.4 (35,833) |
| 2 | 1.9 (75,252) | 2.4 (35,235) | 1.5 (40,017) |
| 3 | 2.0 (73,054) | 2.5 (34,234) | 1.5 (38,820) |

### Win rate and regret by round, per config

| model | effort | round 1 win rate | round 1 mean regret | round 2 win rate | round 2 mean regret | round 3 win rate | round 3 mean regret |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 | off/low | 55.0% (160) | 1.1 (1,400) | 54.4% (160) | 1.0 (1,348) | 53.1% (160) | 0.9 (1,273) |
| claude-opus-5-5 | medium | 53.9% (334) | 0.8 (2,730) | 54.2% (334) | 0.9 (2,967) | 53.3% (334) | 0.9 (2,831) |
| claude-opus-5-5 | high | 48.8% (80) | 0.9 (538) | 60.0% (80) | 0.8 (754) | 55.0% (80) | 0.9 (693) |
| claude-opus-5-5 | xhigh | 51.8% (170) | 0.6 (1,359) | 50.6% (170) | 0.9 (1,544) | 54.7% (170) | 0.7 (1,410) |
| claude-opus-5-5 | max | 70.0% (80) | 0.4 (740) | 61.3% (80) | 0.7 (748) | 62.5% (80) | 0.7 (692) |
| gpt-6.1-sol | low | 55.1% (98) | 0.8 (717) | 48.0% (98) | 1.4 (822) | 50.0% (98) | 0.9 (745) |
| gpt-6.1-sol | medium | 55.7% (271) | 1.0 (2,183) | 60.9% (271) | 0.9 (2,386) | 53.9% (271) | 1.0 (2,177) |
| gpt-6.1-sol | high | 51.5% (99) | 1.0 (732) | 46.5% (99) | 0.8 (946) | 46.5% (99) | 0.7 (780) |
| gpt-6.1-sol | xhigh | 47.5% (101) | 0.7 (750) | 50.5% (101) | 0.7 (884) | 58.4% (101) | 0.6 (893) |
| gpt-6.1-sol | max | 53.5% (142) | 0.5 (1,045) | 54.9% (142) | 0.8 (1,316) | 54.9% (142) | 0.7 (1,325) |
| gpt-6-astra | off | 61.3% (80) | 0.9 (677) | 62.5% (80) | 0.9 (685) | 45.0% (80) | 1.1 (741) |
| gpt-6-astra | low | 51.2% (80) | 0.9 (670) | 62.5% (80) | 1.0 (668) | 63.7% (80) | 0.8 (654) |
| gpt-6-astra | medium | 57.5% (254) | 1.0 (2,000) | 61.0% (254) | 0.9 (2,167) | 61.8% (254) | 0.9 (2,131) |
| gpt-6-astra | high | 67.0% (100) | 0.9 (859) | 59.0% (100) | 1.0 (845) | 66.0% (100) | 0.9 (937) |
| gpt-6.1-terra | off/low | 55.0% (242) | 1.7 (1,991) | 57.9% (242) | 1.9 (1,999) | 53.3% (242) | 1.9 (1,917) |
| gpt-6.1-terra | medium | 59.2% (130) | 1.4 (1,100) | 56.2% (130) | 1.6 (1,059) | 63.8% (130) | 1.2 (1,049) |
| gpt-6.1-terra | high | 67.1% (82) | 1.1 (745) | 54.9% (82) | 1.2 (684) | 56.1% (82) | 1.1 (733) |
| gpt-6.1-terra | xhigh | 63.7% (102) | 1.0 (935) | 52.0% (102) | 1.0 (820) | 64.7% (102) | 1.0 (939) |
| gpt-6.1-terra | max | 68.0% (100) | 0.6 (937) | 62.0% (100) | 0.8 (955) | 58.0% (100) | 0.7 (1,071) |
| claude-sonnet-5-5 | off | 45.1% (164) | 1.9 (1,184) | 39.6% (164) | 2.0 (1,473) | 42.7% (164) | 1.7 (1,339) |
| claude-sonnet-5-5 | low | 45.3% (159) | 2.1 (1,123) | 34.6% (159) | 1.7 (1,315) | 39.0% (159) | 1.9 (1,244) |
| claude-sonnet-5-5 | medium | 43.1% (364) | 2.0 (2,647) | 50.5% (364) | 1.7 (3,282) | 52.2% (364) | 1.4 (3,020) |
| claude-sonnet-5-5 | high | 47.2% (161) | 1.3 (1,261) | 52.2% (161) | 1.2 (1,472) | 41.6% (161) | 1.3 (1,197) |
| claude-sonnet-5-5 | xhigh | 58.5% (176) | 1.0 (1,408) | 49.4% (176) | 0.9 (1,591) | 53.4% (176) | 0.8 (1,456) |
| claude-sonnet-5-5 | max | 58.6% (140) | 0.5 (1,097) | 62.9% (140) | 0.6 (1,233) | 65.0% (140) | 0.6 (1,242) |
| gpt-5.6-terra | low | 42.9% (91) | 2.8 (649) | 46.2% (91) | 2.4 (738) | 47.3% (91) | 2.4 (740) |
| gpt-5.6-terra | medium | 46.7% (259) | 2.4 (1,903) | 49.0% (259) | 2.2 (2,129) | 48.3% (259) | 2.0 (2,076) |
| gpt-5.6-terra | high | 49.5% (91) | 2.2 (701) | 48.4% (91) | 2.1 (741) | 50.5% (91) | 2.2 (724) |
| gpt-5.6-terra | xhigh | 57.0% (93) | 1.3 (761) | 53.8% (93) | 1.5 (804) | 54.8% (93) | 1.7 (844) |
| gpt-5.6-terra | max | 52.2% (90) | 0.9 (750) | 51.1% (90) | 1.1 (861) | 57.8% (90) | 1.1 (878) |
| claude-haiku-5-5 | off | 36.7% (668) | 3.5 (5,201) | 37.6% (668) | 3.0 (5,526) | 40.7% (668) | 3.2 (5,590) |
| claude-haiku-5-5 | low | 48.6% (278) | 1.8 (2,226) | 50.0% (278) | 1.9 (2,377) | 54.0% (278) | 1.8 (2,505) |
| claude-haiku-5-5 | medium | 50.7% (444) | 1.6 (3,547) | 52.5% (444) | 1.5 (3,806) | 48.6% (444) | 1.5 (3,899) |
| claude-haiku-5-5 | high | 51.1% (223) | 1.3 (1,802) | 49.3% (223) | 1.2 (1,884) | 52.0% (223) | 1.3 (1,919) |
| claude-haiku-5-5 | xhigh | 46.2% (158) | 0.8 (1,284) | 51.3% (158) | 0.8 (1,330) | 53.2% (158) | 1.1 (1,321) |
| claude-haiku-5-5 | max | 51.4% (111) | 0.8 (878) | 67.6% (111) | 0.6 (1,026) | 56.8% (111) | 0.7 (921) |
| gpt-6-luna | off/low | 25.3% (396) | 4.1 (3,598) | 33.3% (396) | 3.3 (4,019) | 27.3% (396) | 3.4 (3,763) |
| gpt-6-luna | medium | 32.9% (398) | 3.6 (3,311) | 34.7% (398) | 3.4 (3,757) | 33.9% (398) | 3.2 (3,724) |
| gpt-6-luna | high | 45.9% (218) | 2.5 (2,025) | 53.7% (218) | 2.6 (2,064) | 54.6% (218) | 2.5 (2,047) |
| gpt-6-luna | xhigh | 63.5% (115) | 1.9 (1,052) | 59.1% (115) | 1.9 (1,097) | 67.8% (115) | 2.2 (1,102) |
| gpt-6-luna | max | 61.6% (112) | 1.7 (1,011) | 60.7% (112) | 1.6 (1,211) | 67.0% (112) | 1.9 (1,022) |
| claude-haiku-4-5-20251001 | off | 34.4% (125) | 5.0 (1,085) | 28.0% (125) | 4.5 (1,102) | 35.2% (125) | 5.7 (1,085) |
| claude-haiku-4-5-20251001 | minimal/low | 41.1% (292) | 4.0 (2,503) | 39.4% (292) | 3.6 (2,641) | 45.9% (292) | 4.1 (2,441) |
| claude-haiku-4-5-20251001 | medium | 43.3% (358) | 4.1 (2,750) | 35.2% (358) | 4.1 (2,938) | 37.7% (358) | 3.9 (2,862) |
| claude-haiku-4-5-20251001 | high | 42.2% (135) | 3.8 (1,121) | 51.1% (135) | 3.4 (1,238) | 33.3% (135) | 4.8 (1,102) |
| all |  | - | 2.1 (68,986) | - | 1.9 (75,252) | - | 2.0 (73,054) |
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
4,987 finished matches, 8,524 seats. A regret change counts only the seats that moved in both rounds. Negative regret change is better; win changes are in percentage points of rounds won.

### Change within a match, per model

| model | seats | regret, round 2 minus 1 | regret, round 3 minus 1 | round 3: verdict | win, round 2 minus 1 (points) | win, round 3 minus 1 (points) | shot with a proven live: self-shots, round 3 minus 1 (points) |
|---|---|---|---|---|---|---|---|
| gpt-6-luna | 1,198 | -0.43 (-0.76 to -0.12) | -0.57 (-0.87 to -0.26) | better | +4.0 (+1.6 to +6.5) | +3.4 (+1.0 to +5.9) | -3.9 (-6.5 to -1.3) |
| claude-sonnet-5-5 | 1,099 | -0.34 (-0.59 to -0.09) | -0.42 (-0.68 to -0.17) | better | -0.1 (-2.6 to +2.6) | +0.9 (-1.8 to +3.4) | +0.0 (-0.4 to +0.5) |
| claude-haiku-5-5 | 1,825 | -0.25 (-0.44 to -0.07) | -0.14 (-0.34 to +0.05) | flat | +2.1 (-0.3 to +4.6) | +2.8 (+0.4 to +5.2) | +0.4 (-0.1 to +0.9) |
| gpt-5.6-terra | 585 | -0.22 (-0.57 to +0.12) | -0.14 (-0.47 to +0.20) | flat | +0.6 (-1.8 to +3.2) | +1.9 (-1.1 to +5.1) | -0.5 (-1.9 to +0.7) |
| gpt-6.1-sol | 679 | +0.14 (-0.01 to +0.30) | -0.09 (-0.21 to +0.03) | flat | +1.0 (-1.9 to +3.8) | -0.3 (-3.1 to +2.4) | +0.0 (+0.0 to +0.0) |
| gpt-6-astra | 498 | -0.09 (-0.28 to +0.11) | -0.08 (-0.27 to +0.10) | flat | +2.1 (-3.2 to +7.5) | +1.4 (-3.6 to +6.3) | +0.0 (+0.0 to +0.0) |
| claude-opus-5-5 | 779 | +0.03 (-0.11 to +0.16) | +0.02 (-0.11 to +0.16) | flat | +0.0 (-3.7 to +3.8) | -0.1 (-3.8 to +3.6) | +0.0 (+0.0 to +0.1) |
| claude-haiku-4-5-20251001 | 895 | -0.33 (-0.75 to +0.09) | +0.07 (-0.42 to +0.54) | flat | -3.3 (-6.2 to -0.2) | -1.9 (-5.0 to +1.1) | -0.7 (-2.5 to +1.1) |
| gpt-6.1-terra | 640 | +0.10 (-0.15 to +0.34) | +0.20 (-0.10 to +0.52) | flat | -3.8 (-8.8 to +1.2) | -2.4 (-7.3 to +2.7) | +0.3 (+0.0 to +0.8) |
| all | 8,198 | -0.20 (-0.29 to -0.11) | -0.17 (-0.26 to -0.07) | better | +0.7 (+0.1 to +1.3) | +1.0 (+0.5 to +1.6) | -0.5 (-0.9 to -0.1) |

### Where the regret change sits, round 3 minus round 1

| model | all moves, raw regret | all moves, adjusted | shots, adjusted | item moves, adjusted |
|---|---|---|---|---|
| gpt-6-luna | -0.61 (-0.93 to -0.31) | -0.57 (-0.87 to -0.26) | -1.12 (-1.69 to -0.49) | +0.11 (-0.07 to +0.27) |
| claude-sonnet-5-5 | -0.44 (-0.72 to -0.18) | -0.42 (-0.68 to -0.17) | -0.63 (-0.99 to -0.27) | +0.07 (-0.07 to +0.21) |
| claude-haiku-5-5 | -0.15 (-0.34 to +0.03) | -0.14 (-0.34 to +0.05) | -0.36 (-0.76 to +0.04) | +0.05 (-0.07 to +0.18) |
| gpt-5.6-terra | -0.18 (-0.53 to +0.14) | -0.14 (-0.47 to +0.20) | -0.43 (-0.97 to +0.11) | +0.10 (-0.11 to +0.29) |
| gpt-6.1-sol | -0.07 (-0.20 to +0.05) | -0.09 (-0.21 to +0.03) | -0.22 (-0.48 to +0.04) | +0.03 (-0.09 to +0.15) |
| gpt-6-astra | -0.03 (-0.21 to +0.16) | -0.08 (-0.27 to +0.10) | +0.07 (-0.24 to +0.39) | -0.11 (-0.27 to +0.05) |
| claude-opus-5-5 | +0.01 (-0.12 to +0.15) | +0.02 (-0.11 to +0.16) | -0.05 (-0.29 to +0.19) | +0.12 (-0.02 to +0.26) |
| claude-haiku-4-5-20251001 | +0.01 (-0.45 to +0.48) | +0.07 (-0.42 to +0.54) | +0.03 (-0.78 to +0.78) | +0.17 (-0.04 to +0.39) |
| gpt-6.1-terra | +0.18 (-0.12 to +0.51) | +0.20 (-0.10 to +0.52) | +0.32 (-0.10 to +0.78) | -0.01 (-0.19 to +0.16) |
| all | -0.19 (-0.28 to -0.09) | -0.17 (-0.26 to -0.07) | -0.35 (-0.53 to -0.18) | +0.07 (+0.01 to +0.12) |

### Round 3 minus round 1 regret, by whether round 3 still decides the match

| model | level: seats | level: change | decided: seats | decided: change |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 | 433 | +0.18 (-0.46 to +0.84) | 462 | -0.04 (-0.64 to +0.60) |
| claude-haiku-5-5 | 948 | -0.09 (-0.37 to +0.16) | 877 | -0.19 (-0.48 to +0.09) |
| claude-opus-5-5 | 374 | +0.10 (-0.12 to +0.32) | 405 | -0.05 (-0.23 to +0.11) |
| claude-sonnet-5-5 | 503 | -0.45 (-0.81 to -0.09) | 596 | -0.40 (-0.72 to -0.09) |
| gpt-5.6-terra | 319 | +0.06 (-0.33 to +0.47) | 266 | -0.37 (-0.87 to +0.18) |
| gpt-6-astra | 242 | -0.22 (-0.46 to +0.02) | 256 | +0.06 (-0.19 to +0.31) |
| gpt-6-luna | 567 | -0.27 (-0.70 to +0.13) | 631 | -0.83 (-1.26 to -0.42) |
| gpt-6.1-sol | 364 | -0.10 (-0.29 to +0.08) | 315 | -0.08 (-0.24 to +0.07) |
| gpt-6.1-terra | 309 | +0.19 (-0.11 to +0.50) | 331 | +0.21 (-0.31 to +0.74) |

### Change within a match, per config

| model | effort | seats | regret, round 2 minus 1 | regret, round 3 minus 1 | win, round 2 minus 1 (points) | win, round 3 minus 1 (points) | round 3 regret |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 | off | 121 | -1.11 (-2.38 to +0.17) | -0.21 (-1.53 to +1.10) | -6.4 (-18.1 to +5.8) | +0.8 (-9.8 to +11.5) | flat |
| claude-haiku-4-5-20251001 | minimal/low | 289 | -0.40 (-1.05 to +0.27) | +0.25 (-0.50 to +1.05) | -1.7 (-8.2 to +5.0) | +4.8 (-1.7 to +11.0) | flat |
| claude-haiku-4-5-20251001 | medium | 353 | +0.11 (-0.58 to +0.73) | -0.26 (-0.92 to +0.40) | -8.1 (-14.3 to -1.7) | -5.6 (-11.9 to +0.6) | flat |
| claude-haiku-4-5-20251001 | high | 132 | -0.61 (-1.74 to +0.39) | +0.80 (-0.43 to +2.13) | +8.9 (-3.2 to +20.6) | -8.9 (-18.5 to +1.4) | flat |
| claude-haiku-5-5 | off | 644 | -0.62 (-1.06 to -0.17) | -0.46 (-0.91 to -0.00) | +0.9 (-4.3 to +5.8) | +4.0 (-0.9 to +8.5) | better |
| claude-haiku-5-5 | low | 271 | +0.02 (-0.37 to +0.39) | +0.06 (-0.35 to +0.45) | +1.4 (-6.7 to +9.6) | +5.4 (-2.5 to +13.3) | flat |
| claude-haiku-5-5 | medium | 431 | -0.14 (-0.42 to +0.12) | -0.10 (-0.39 to +0.19) | +1.8 (-4.5 to +8.0) | -2.0 (-7.9 to +4.0) | flat |
| claude-haiku-5-5 | high | 218 | -0.04 (-0.36 to +0.28) | -0.01 (-0.32 to +0.30) | -1.8 (-10.7 to +7.2) | +0.9 (-8.1 to +9.8) | flat |
| claude-haiku-5-5 | xhigh | 152 | +0.05 (-0.20 to +0.29) | +0.29 (+0.00 to +0.56) | +5.1 (-4.0 to +14.4) | +7.0 (-2.5 to +17.1) | worse |
| claude-haiku-5-5 | max | 109 | -0.05 (-0.26 to +0.17) | +0.25 (-0.08 to +0.59) | +16.2 (+6.3 to +26.1) | +5.4 (-4.5 to +15.3) | flat |
| claude-opus-5-5 | off/low | 152 | -0.17 (-0.58 to +0.27) | -0.45 (-0.80 to -0.11) | -0.6 (-10.3 to +8.5) | -1.9 (-11.2 to +7.6) | better |
| claude-opus-5-5 | medium | 317 | +0.05 (-0.16 to +0.24) | +0.17 (-0.06 to +0.41) | +0.3 (-7.0 to +7.5) | -0.6 (-7.3 to +6.4) | flat |
| claude-opus-5-5 | high | 71 | -0.08 (-0.40 to +0.24) | +0.05 (-0.32 to +0.46) | +11.2 (+0.0 to +23.5) | +6.2 (-6.1 to +19.5) | too few seats |
| claude-opus-5-5 | xhigh | 161 | +0.17 (-0.05 to +0.39) | +0.01 (-0.20 to +0.21) | -1.2 (-10.7 to +8.8) | +2.9 (-6.7 to +12.3) | flat |
| claude-opus-5-5 | max | 78 | +0.13 (-0.08 to +0.34) | +0.29 (+0.04 to +0.59) | -8.8 (-22.4 to +5.2) | -7.5 (-19.3 to +3.7) | too few seats |
| claude-sonnet-5-5 | off | 153 | -0.18 (-1.01 to +0.62) | -0.62 (-1.43 to +0.10) | -5.5 (-14.1 to +4.3) | -2.4 (-12.1 to +7.5) | flat |
| claude-sonnet-5-5 | low | 151 | -0.32 (-1.00 to +0.41) | +0.07 (-0.61 to +0.76) | -10.7 (-19.6 to -1.9) | -6.3 (-16.9 to +4.4) | flat |
| claude-sonnet-5-5 | medium | 346 | -0.49 (-0.97 to -0.05) | -0.80 (-1.25 to -0.36) | +7.4 (+0.8 to +13.8) | +9.1 (+1.9 to +16.4) | better |
| claude-sonnet-5-5 | high | 152 | -0.50 (-1.02 to -0.01) | -0.34 (-0.94 to +0.27) | +5.0 (-4.2 to +13.8) | -5.6 (-14.9 to +3.6) | flat |
| claude-sonnet-5-5 | xhigh | 167 | -0.42 (-0.91 to +0.03) | -0.43 (-0.97 to +0.04) | -9.1 (-18.6 to +0.0) | -5.1 (-14.1 to +3.9) | flat |
| claude-sonnet-5-5 | max | 130 | +0.16 (+0.00 to +0.34) | +0.20 (+0.00 to +0.43) | +4.3 (-5.7 to +12.9) | +6.4 (-4.3 to +17.1) | worse |
| gpt-5.6-terra | low | 83 | -0.66 (-1.63 to +0.29) | -0.42 (-1.59 to +0.68) | +3.3 (-10.0 to +17.6) | +4.4 (-7.6 to +15.6) | flat |
| gpt-5.6-terra | medium | 243 | -0.43 (-1.04 to +0.15) | -0.55 (-1.16 to +0.01) | +2.3 (-5.0 to +10.1) | +1.5 (-6.8 to +10.0) | flat |
| gpt-5.6-terra | high | 86 | -0.16 (-0.92 to +0.60) | +0.44 (-0.61 to +1.61) | -1.1 (-14.3 to +12.1) | +1.1 (-13.2 to +14.3) | flat |
| gpt-5.6-terra | xhigh | 89 | +0.28 (-0.28 to +0.79) | +0.37 (-0.15 to +0.91) | -3.2 (-16.0 to +9.7) | -2.2 (-15.4 to +10.8) | flat |
| gpt-5.6-terra | max | 84 | +0.22 (-0.14 to +0.62) | +0.22 (-0.10 to +0.52) | -1.1 (-14.4 to +12.2) | +5.6 (-5.6 to +17.8) | flat |
| gpt-6-astra | off | 77 | -0.15 (-0.73 to +0.35) | +0.17 (-0.40 to +0.65) | +1.2 (-12.5 to +17.5) | -16.2 (-31.2 to +0.0) | too few seats |
| gpt-6-astra | low | 78 | -0.01 (-0.43 to +0.43) | -0.18 (-0.58 to +0.18) | +11.2 (-3.8 to +26.6) | +12.5 (-2.4 to +26.5) | too few seats |
| gpt-6-astra | medium | 247 | -0.21 (-0.46 to +0.04) | -0.11 (-0.38 to +0.18) | +3.5 (-3.2 to +10.3) | +4.3 (-2.0 to +10.7) | flat |
| gpt-6-astra | high | 96 | +0.20 (-0.22 to +0.64) | -0.11 (-0.43 to +0.20) | -8.0 (-20.8 to +5.0) | -1.0 (-13.0 to +11.9) | flat |
| gpt-6-luna | off/low | 376 | -1.17 (-1.77 to -0.57) | -1.15 (-1.75 to -0.61) | +8.1 (+2.3 to +14.0) | +2.0 (-3.7 to +7.8) | better |
| gpt-6-luna | medium | 390 | -0.35 (-0.96 to +0.30) | -0.66 (-1.20 to -0.17) | +1.8 (-4.5 to +7.8) | +1.0 (-5.3 to +6.8) | better |
| gpt-6-luna | high | 210 | +0.15 (-0.43 to +0.74) | -0.09 (-0.74 to +0.54) | +7.8 (-0.9 to +17.1) | +8.7 (-0.5 to +17.8) | flat |
| gpt-6-luna | xhigh | 111 | +0.36 (-0.64 to +1.30) | +0.24 (-0.65 to +1.06) | -4.3 (-15.1 to +6.0) | +4.3 (-7.0 to +15.7) | flat |
| gpt-6-luna | max | 111 | -0.10 (-0.79 to +0.55) | +0.03 (-0.62 to +0.66) | -0.9 (-12.5 to +9.8) | +5.4 (-6.2 to +17.0) | flat |
| gpt-6.1-sol | low | 92 | +0.90 (+0.38 to +1.52) | -0.02 (-0.39 to +0.35) | -7.1 (-16.0 to +2.0) | -5.1 (-15.5 to +6.2) | flat |
| gpt-6.1-sol | medium | 263 | -0.07 (-0.35 to +0.23) | -0.17 (-0.39 to +0.06) | +5.2 (-1.8 to +12.2) | -1.8 (-8.5 to +4.4) | flat |
| gpt-6.1-sol | high | 93 | -0.05 (-0.35 to +0.22) | -0.21 (-0.48 to +0.05) | -5.1 (-14.3 to +5.0) | -5.1 (-16.2 to +6.0) | flat |
| gpt-6.1-sol | xhigh | 97 | -0.03 (-0.22 to +0.17) | -0.13 (-0.32 to +0.05) | +3.0 (-7.8 to +13.0) | +10.9 (+1.0 to +20.6) | flat |
| gpt-6.1-sol | max | 134 | +0.30 (+0.13 to +0.47) | +0.12 (-0.07 to +0.31) | +1.4 (-7.7 to +10.6) | +1.4 (-7.7 to +10.6) | flat |
| gpt-6.1-terra | off/low | 236 | +0.17 (-0.38 to +0.74) | +0.58 (-0.12 to +1.40) | +2.9 (-5.7 to +12.0) | -1.7 (-10.0 to +6.8) | flat |
| gpt-6.1-terra | medium | 127 | -0.05 (-0.62 to +0.48) | -0.19 (-0.73 to +0.39) | -3.1 (-14.2 to +8.5) | +4.6 (-7.1 to +17.3) | flat |
| gpt-6.1-terra | high | 81 | +0.22 (-0.22 to +0.67) | -0.05 (-0.44 to +0.36) | -12.2 (-26.2 to +1.3) | -11.0 (-25.3 to +3.6) | flat |
| gpt-6.1-terra | xhigh | 101 | -0.09 (-0.52 to +0.33) | -0.00 (-0.44 to +0.43) | -11.8 (-24.0 to +1.0) | +1.0 (-12.4 to +14.0) | flat |
| gpt-6.1-terra | max | 95 | +0.23 (+0.02 to +0.43) | +0.20 (-0.03 to +0.44) | -6.0 (-18.4 to +7.3) | -10.0 (-22.0 to +2.1) | flat |

### What chance alone would give

41 of 45 configs have 80 or more seats with a regret in rounds 1 and 3. Per delta, with a 95% interval, about 1.0 should land on each side by chance alone.
- regret, round 2 minus 1: 4 better, 4 worse, 33 flat. 3 survive Benjamini-Hochberg at 5%.
- regret, round 3 minus 1: 5 better, 2 worse, 34 flat. 2 survive Benjamini-Hochberg at 5%.
- win, round 2 minus 1: 3 better, 2 worse, 36 flat. 0 survive Benjamini-Hochberg at 5%.
- win, round 3 minus 1: 2 better, 0 worse, 39 flat. 0 survive Benjamini-Hochberg at 5%.

9 of 9 models have 80 or more seats with a regret in rounds 1 and 3. Per delta, with a 95% interval, about 0.2 should land on each side by chance alone.
- regret, round 2 minus 1: 3 better, 0 worse, 6 flat. 3 survive Benjamini-Hochberg at 5%.
- regret, round 3 minus 1: 2 better, 0 worse, 7 flat. 2 survive Benjamini-Hochberg at 5%.
- win, round 2 minus 1: 1 better, 1 worse, 7 flat. 1 survive Benjamini-Hochberg at 5%.
- win, round 3 minus 1: 2 better, 0 worse, 7 flat. 0 survive Benjamini-Hochberg at 5%.
<!-- round-improvement:end -->
