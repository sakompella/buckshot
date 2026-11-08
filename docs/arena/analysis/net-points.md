# Net points

How many round wins a seat's moves gave up per match, by the minimax player's reading ([regret.md](regret.md)), and how that compares with the Round Elo and with who actually won the rounds. A casual pass over the 3,536 finished matches with no DeepSeek seat of the 2026-11-04 run, one scoring build (the Rust `bounded-v1-f64-unpruned-bdf020cc78a6842c`, depth 6, 20,000 nodes, static reload; [regret.md](regret.md#production-scoring)). The scripts write the tables below. The two plots are not committed: they go to `_work/wip/net-points/plots/` (`--plots`), and their data is the config table and the round-margin table.

## Definition

- **Round-win equivalents lost** (the headline): a seat's own loss in a match is the sum of its regret over its searched decisions, in rounds. A regret is a drop in the chance of winning the round, so 100 points is one round. Lower is better. This is not "rounds forfeited": it adds up chances over a match, and a chance given up and then regained is counted twice, so a seat can lose more than 3.
- **Net points** of a seat in a match: the opponent's loss minus its own. Positive means the opponent gave up more. It is a difference of two estimates, each made from that seat's own information and a public-only model of the opponent. It is not a count of rounds gained.
- **Largest gap**: the biggest single regret of a seat in a match, in points.
- Only matches where every agent decision has a searched row count. Missing analysis is never zero. Of the 3,537 finished matches, 1 was left out for that and none for unreadable round winners.
- Intervals are 95% over seed blocks (both seat orders of one seed together), 2,000 resamples.

## Results

1. **Own loss tracks Round Elo closely: -0.95 over the 49 configs with at least 20 matches.**
   - Interval -0.95 to -0.90 (blocks resampled, ratings refitted). Spearman -0.87.
   - It runs from 0.21 per match for Sonnet max to 1.50 for Haiku 4.5 off, so a config gives up between a fifth of a round and one and a half rounds per match.
   - Opus sits at 0.23 to 0.33 at every effort, Sol at 0.30 to 0.36 and Astra at 0.32 to 0.37. Haiku 5.5 goes from 0.92 at off to 0.25 at max. Haiku 4.5 is between 1.11 and 1.50 at every effort and Luna between 0.63 (max) and 1.27 (low).
   - Gaps of 0.05 between neighbours are inside the intervals. The correlation uses no match results on the loss side, but Round Elo is itself fitted on round results, so this says the two agree, not that one causes the other.
2. **Net points do not rank configs: +0.80 with Round Elo (Spearman +0.66).**
   - Each config meets different opponents (Haiku 4.5 mostly faces strong models, Opus max faces weak ones), and net is relative to them. Use net inside one matchup only.
   - Over the 108 pairings with at least 10 complete seed blocks, a pairing's mean net and its mean round margin correlate at +0.86. Ten blocks per pairing is thin, so the single pairings below are noisy, but the pattern across pairings is not.
3. **A match's net points predict its round margin, weakly.**
   - Each net point goes with 0.81 rounds of margin (interval 0.72 to 0.90), R² 0.071, correlation 0.27. Round margin is -3, -1, 1 or 3 and a match has three rounds, so most of a match is luck and the unseen shell order.
   - The binned means rise cleanly: -1.25 rounds of margin when net is below -1, +0.84 when it is above +1.
   - A margin of 2 per net point would be a literal reading of the regrets. The observed 0.81 says the minimax player's chances are a pessimistic yardstick against real opponents, as expected.
4. **A big miss in a match is common, a certain win thrown away is not.**
   - 70.7% of seats have a miss of at least 10 points somewhere in a match, 29.1% at least 25, 7.8% at least 50 and 1.4% a full 100. A deeper search with a sampled reload leaf should recheck the biggest ones before anyone shows them as highlights: regret.md shows single decisions move by a point or more in 13% of cases.

## Under a deeper search

The 2,880 decisions of the Deeper search section of [regret.md](regret.md) were rescored at depth 8 with 200,000 nodes. Scaling each model's change in regret by each config's own mix of shells left and shot-or-item, and by its decisions per match, gives the change in loss per match.

- **Nothing moves, except Haiku 4.5.** Seven of eight models change by 0.03 rounds per match or less, with intervals of ±0.03 to ±0.07 (decisions only: these leave out matches and tournaments). Haiku 4.5 rises by 0.07 ± 0.04, from 1.19 to 1.26. The largest change in any config is +0.07.
- **The correlation with Round Elo barely changes** (-0.956 to -0.947) and the ordering of configs is the same (Spearman 0.993 between the two). Terra 6.1 has no sample and is left out. Every effort of a model is given the model's change, which is an assumption.
- **The leaf matters more than the depth.** The Reload bias section of regret.md puts the static leaf's overstatement at 0.43 points per decision over the run, about 0.1 round per match at roughly 25 decisions a match. That is three times the depth effect for seven of the eight models, and it lowers every model's regret by 0.3 to 0.6 points.

### What "max depth" would cost

The round cannot be searched to its end: every search stops at the next reload, which deals random items, so "to the end of the round" means to the reload. With 3 or fewer shells left the depth 8 search with 200,000 nodes is stopped by the budget in at most 6% of shots and 24% of item moves, so most lines already end at the reload. A timed test of 120 decisions (20 for each of shells left 1 to 3, shot or item move, drawn from the depth 8 sample) ran to the reload with depth 16 and 2,000,000 nodes, static leaf, on hp:

- Six searches stopped on the budget; the rest finished at depth 16 or earlier (mean 15.7).
- The best move's label was the same as at depth 8 in all 120. The regret differed from depth 8 in 1 decision and from production in 3. Mean regret was 2.42 at depth 16, 2.42 at depth 8 and 2.31 at depth 6, which is noise at this size.
- Time: mean 5.4 s, median 0.12 s, 95th percentile 66 s, maximum 78 s. The cost sits in the 3-shell item moves (mean 19.6 s, four of its 20 stopped by the budget).

So running to the reload with 3 or fewer shells left is not cheap and does not settle anything the production search leaves open. The cost table prices each setting over all decisions from the stored runs' time per cell. The "to the reload" row rests on 20 timed decisions per cell and a heavy tail, so read it as 100 to 200 hours, not 145. Hours are CPU hours in one process; the second column divides by 8, which is an assumption about how many shards to run.

- The sampled leaf for 3 or fewer shells left, the setting that moves the numbers, costs about 640 CPU hours, 80 hours on 8 processes. Scoring only 2 or fewer shells left costs about 170 CPU hours by the same cells.
- Production is 14 hours. Depth 8 everywhere is 128.
- Suggestion: keep depth 6 with 20,000 nodes for the headline. If a tighter number is wanted, spend the hours on the sampled leaf for 2 or fewer shells left, not on depth.

<!-- net-points:start -->
3,536 finished matches with no DeepSeek seat (3,556 with it, used for the ratings, which cover 50 configs). Left out: 0 matches whose round winners did not match the final cash and 1 with an agent decision that has no searched row. 49 configs have at least 20 matches. Intervals are 95%, 2,000 resamples of seed blocks.

### Round-win equivalents lost, by config

| model | effort | matches | round-win equivalents lost per match | per round | largest gap (points) | Round Elo |
|---|---|---|---|---|---|---|
| claude-sonnet-5-5 | max | 140 | 0.21 (0.18 to 0.24) | 0.07 | 9.4 | +107 |
| claude-opus-5-5 | max | 80 | 0.23 (0.20 to 0.27) | 0.08 | 9.9 | +121 |
| claude-haiku-5-5 | max | 111 | 0.25 (0.21 to 0.29) | 0.08 | 10.6 | +43 |
| claude-opus-5-5 | high | 80 | 0.25 (0.22 to 0.28) | 0.08 | 10.2 | +78 |
| claude-opus-5-5 | xhigh | 150 | 0.25 (0.22 to 0.28) | 0.08 | 9.9 | +101 |
| claude-haiku-5-5 | xhigh | 158 | 0.28 (0.25 to 0.30) | 0.09 | 11.5 | +11 |
| claude-opus-5-5 | medium | 294 | 0.28 (0.26 to 0.31) | 0.09 | 11.3 | +48 |
| gpt-6.1-sol | xhigh | 101 | 0.30 (0.26 to 0.35) | 0.10 | 10.7 | +67 |
| claude-sonnet-5-5 | xhigh | 160 | 0.31 (0.27 to 0.36) | 0.10 | 11.8 | +58 |
| gpt-6-astra | low | 80 | 0.32 (0.27 to 0.37) | 0.11 | 13.5 | +62 |
| claude-opus-5-5 | off | 80 | 0.32 (0.28 to 0.37) | 0.11 | 12.8 | +63 |
| gpt-6-astra | medium | 254 | 0.33 (0.30 to 0.35) | 0.11 | 13.7 | +83 |
| claude-opus-5-5 | low | 80 | 0.33 (0.28 to 0.39) | 0.11 | 13.9 | +25 |
| gpt-6.1-sol | high | 99 | 0.33 (0.28 to 0.39) | 0.11 | 11.7 | +43 |
| gpt-6.1-sol | max | 122 | 0.33 (0.29 to 0.38) | 0.11 | 11.2 | +96 |
| gpt-6.1-sol | medium | 271 | 0.34 (0.32 to 0.37) | 0.11 | 13.5 | +55 |
| gpt-6.1-sol | low | 98 | 0.36 (0.32 to 0.41) | 0.12 | 14.1 | +61 |
| gpt-6.1-terra | xhigh | 80 | 0.36 (0.31 to 0.42) | 0.12 | 15.0 | +59 |
| gpt-6-astra | off | 80 | 0.37 (0.32 to 0.41) | 0.12 | 14.7 | +35 |
| claude-haiku-5-5 | high | 173 | 0.37 (0.34 to 0.41) | 0.12 | 14.8 | +6 |
| gpt-6-astra | high | 80 | 0.37 (0.33 to 0.43) | 0.12 | 14.6 | +118 |
| gpt-6.1-terra | max | 80 | 0.38 (0.33 to 0.42) | 0.13 | 12.9 | +124 |
| gpt-5.6-terra | max | 90 | 0.40 (0.35 to 0.44) | 0.13 | 15.9 | +17 |
| claude-sonnet-5-5 | high | 161 | 0.40 (0.36 to 0.44) | 0.13 | 14.3 | +9 |
| gpt-6.1-terra | high | 80 | 0.40 (0.35 to 0.45) | 0.13 | 14.3 | +50 |
| gpt-6.1-terra | medium | 80 | 0.44 (0.37 to 0.50) | 0.15 | 18.7 | +49 |
| gpt-6.1-terra | low | 80 | 0.46 (0.40 to 0.53) | 0.15 | 20.9 | +31 |
| claude-haiku-5-5 | medium | 342 | 0.49 (0.46 to 0.53) | 0.16 | 19.0 | -4 |
| claude-sonnet-5-5 | medium | 324 | 0.50 (0.46 to 0.53) | 0.17 | 19.1 | +1 |
| gpt-5.6-terra | xhigh | 93 | 0.52 (0.46 to 0.58) | 0.17 | 18.6 | +32 |
| claude-sonnet-5-5 | low | 159 | 0.54 (0.49 to 0.59) | 0.18 | 19.8 | -38 |
| gpt-6.1-terra | off | 79 | 0.55 (0.47 to 0.64) | 0.18 | 22.0 | +29 |
| claude-sonnet-5-5 | off | 164 | 0.56 (0.51 to 0.61) | 0.19 | 19.7 | -21 |
| claude-haiku-5-5 | low | 193 | 0.58 (0.53 to 0.63) | 0.19 | 21.8 | -4 |
| gpt-6-luna | max | 112 | 0.63 (0.55 to 0.71) | 0.21 | 22.8 | -18 |
| gpt-5.6-terra | high | 91 | 0.63 (0.55 to 0.72) | 0.21 | 22.4 | -5 |
| gpt-5.6-terra | medium | 259 | 0.64 (0.59 to 0.68) | 0.21 | 24.8 | -25 |
| gpt-6-luna | xhigh | 115 | 0.69 (0.62 to 0.76) | 0.23 | 26.1 | -13 |
| gpt-5.6-terra | low | 91 | 0.73 (0.64 to 0.83) | 0.24 | 26.4 | -27 |
| gpt-6-luna | high | 112 | 0.89 (0.80 to 0.98) | 0.30 | 29.9 | -71 |
| claude-haiku-5-5 | off | 202 | 0.92 (0.84 to 1.00) | 0.31 | 33.5 | -99 |
| gpt-6-luna | medium | 282 | 1.09 (1.03 to 1.16) | 0.36 | 35.3 | -156 |
| claude-haiku-4-5-20251001 | medium | 340 | 1.11 (1.03 to 1.18) | 0.37 | 37.7 | -121 |
| claude-haiku-4-5-20251001 | high | 135 | 1.16 (1.03 to 1.27) | 0.39 | 39.0 | -145 |
| claude-haiku-4-5-20251001 | minimal | 143 | 1.16 (1.05 to 1.27) | 0.39 | 38.1 | -140 |
| claude-haiku-4-5-20251001 | low | 149 | 1.17 (1.06 to 1.30) | 0.39 | 37.8 | -140 |
| gpt-6-luna | off | 110 | 1.17 (1.06 to 1.28) | 0.39 | 34.2 | -212 |
| gpt-6-luna | low | 110 | 1.27 (1.14 to 1.41) | 0.42 | 37.9 | -225 |
| claude-haiku-4-5-20251001 | off | 125 | 1.50 (1.38 to 1.61) | 0.50 | 47.0 | -217 |

### Against Round Elo

| measure per config | Pearson | 95% interval | Spearman |
|---|---|---|---|
| own points lost per match | -0.95 | -0.95 to -0.90 | -0.87 |
| net points per match | +0.80 | 0.71 to 0.82 | +0.66 |

### Net points within a matchup

108 pairings have at least 10 complete seed blocks. Across them, net points and round margin per match correlate at +0.86. The ten largest nets:

| config | against | complete seed blocks | net points per match (positive: the first gave up less) | round margin per match |
|---|---|---|---|---|
| claude-haiku-5-5 medium | gpt-6-luna medium | 10 | +0.91 (0.72 to 1.11) | +1.50 |
| claude-opus-5-5 medium | gpt-6-luna medium | 10 | +0.89 (0.72 to 1.05) | +1.20 |
| gpt-6-astra medium | gpt-6-luna medium | 10 | +0.79 (0.60 to 0.94) | +1.90 |
| claude-haiku-4-5-20251001 medium | claude-sonnet-5-5 medium | 10 | -0.73 (-1.02 to -0.45) | -1.60 |
| claude-haiku-5-5 off | claude-haiku-5-5 xhigh | 10 | -0.67 (-0.90 to -0.40) | -0.90 |
| claude-haiku-4-5-20251001 medium | claude-opus-5-5 medium | 10 | -0.65 (-0.94 to -0.38) | -0.70 |
| claude-haiku-4-5-20251001 medium | gpt-6.1-sol medium | 10 | -0.64 (-0.92 to -0.40) | -1.00 |
| gpt-6-luna medium | gpt-6.1-sol medium | 10 | -0.61 (-0.76 to -0.44) | -1.30 |
| claude-haiku-4-5-20251001 medium | claude-haiku-5-5 medium | 15 | -0.60 (-0.78 to -0.41) | -1.33 |
| claude-haiku-5-5 medium | claude-haiku-5-5 off | 10 | +0.58 (0.43 to 0.73) | +0.90 |

### Largest gap per match

| largest gap in a match, at least (points) | share of seats |
|---|---|
| 10 | 70.7% |
| 25 | 29.1% |
| 50 | 7.8% |
| 100 | 1.4% |

### Round margin on net points, per match

3,536 matches. Round margin of the first seat = +0.001 + 0.81 × its net points; R² 0.071, slope interval 0.72 to 0.90.

| net points of the first seat | matches | mean net points | mean round margin |
|---|---|---|---|
| below -1 | 159 | -1.40 | -1.25 |
| -1 to -0.5 | 394 | -0.70 | -0.68 |
| -0.5 to -0.2 | 635 | -0.33 | -0.21 |
| -0.2 to 0.2 | 1,294 | -0.00 | +0.03 |
| 0.2 to 0.5 | 577 | +0.34 | +0.31 |
| 0.5 to 1 | 337 | +0.70 | +0.56 |
| 1 and above | 140 | +1.39 | +0.84 |

### Under a deeper search

The stored depth 8 sample, scaled to 43 configs: Pearson against Round Elo -0.956 at depth 6 and -0.947 with the shifts; Spearman between the two orderings +0.993; the largest change in one config's points lost per match is +0.07.

| model | seat matches | points lost per match at depth 6 | at depth 8 | change |
|---|---|---|---|---|
| gpt-6-astra | 494 | 0.34 | 0.34 | +0.00 ± 0.06 |
| claude-opus-5-5 | 764 | 0.28 | 0.29 | +0.01 ± 0.03 |
| gpt-6.1-sol | 691 | 0.34 | 0.33 | -0.01 ± 0.06 |
| gpt-5.6-terra | 624 | 0.60 | 0.60 | +0.00 ± 0.07 |
| claude-sonnet-5-5 | 1,108 | 0.44 | 0.41 | -0.02 ± 0.04 |
| claude-haiku-5-5 | 1,179 | 0.51 | 0.52 | +0.01 ± 0.07 |
| gpt-6-luna | 841 | 0.98 | 0.95 | -0.03 ± 0.04 |
| claude-haiku-4-5-20251001 | 892 | 1.19 | 1.26 | +0.07 ± 0.04 |
<!-- net-points:end -->

### Cost of rescoring 138,013 decisions (2026-11-02 run)

This table was not regenerated: the 2026-11-04 run did not rerun the timed settings, so it still prices the 138,013 decisions of the 2026-11-02 snapshot.

| setting | CPU hours | on 8 processes |
|---|---|---|
| production: depth 6, 20,000 nodes, static leaf | 14 | 2 |
| depth 8, 200,000 nodes everywhere | 128 | 16 |
| depth 8, 200,000 nodes with 4 or more shells left, production below | 108 | 14 |
| to the reload (depth 16, 2,000,000 nodes) with 3 or fewer shells left, production above | 145 | 18 |
| as above, and depth 8, 200,000 nodes with 4 or more | 239 | 30 |
| sampled leaf, 64 deals, depth 6 with 3 or fewer shells left, production above | 642 | 80 |


## Limits

- Net points and loss are estimates under a heuristic leaf: the item weights are untrained and a reload is a leaf (see [regret.md](regret.md)). Gaps of a few hundredths of a round are noise.
- Decisions of one match are not independent, and a config's opponents differ between tournaments. The intervals cover seed blocks of this run, not new tournaments.
- The cost table prices the stored runs' time per cell. The "to the reload" row uses a 120-decision test. The sampled-leaf row uses the 2,853-decision reload-bias run, both from the 2026-10-26 sample.
- The depth change is the earlier sample's, applied to later tournaments' configs with the same model.

## Reproduce

    python3 tools/arena/analysis/net_points.py [--db PATH] [--regret PATH] [--knowledge PATH] [--deep PATH] [--sampled PATH] [--unbounded PATH] [--plots DIR] [--doc docs/arena/analysis/net-points.md]

The timed test is `arena-regret.ts` from `web/` with `--depth 16 --budget 2000000 --reload static --decisions <list>` on 20 decisions for each of shells left 1 to 3, shots and item moves, drawn from the depth 8 sample. `--unbounded` reads its output file; `--sampled` reads `reload-bias.sqlite`. Without those two the cost table is left out. `python3 -m unittest discover -s tools/arena/analysis` runs the tests.

