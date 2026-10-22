# Matchup analysis

Ratings, pair effects, seat and round 1 starter effects for the scored arena matches, from the analysis database ([database.md](../database.md)). All scored matches are two-player. Every rate shows numerator/denominator, a win share counts a split by its share, and every interval is a 95% bootstrap that draws whole units, never single matches or seat swaps: seed blocks (the two seat-swapped matches of one pair and seed) for ratings, and seeds (every block played at a seed, in any pairing) for the headline seat and starter figures. The tables below the line "Tables" are generated: `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` rewrites them, with a fixed RNG seed, in about 7 minutes under `nice`. Nothing here reads provenance or account data.

**DeepSeek is left out.** Every match with deepseek-v4.1-flash (20 scored matches) is dropped from all cohorts, fits, seat and starter figures and tables, because its free tier refused requests, so its games are not a random sample of what was scheduled. That leaves 2,118 scored matches.

## Findings

**Cohorts and coverage.** Matches are compared only inside a cohort: tournament 1's medium cross-model games, each model's own effort sweep (six of them), tournament 2's Opus effort games, and tournament 3. Each cohort's schedule is connected, so each has one ranking, and no two cohorts share a scale.
- The cross-model cohort has 8 entrants and 497 matches over 25 of the 28 pairs; terra did not play haiku 4.5, opus or astra. Haiku 4.5 against astra has 17 matches rather than 20.
- Every sweep is a full round robin with 20 matches per pair. Opus effort plays 4 of its 6 pairs, and max has no scored match.
- The ratings are Bradley-Terry fits on the shares. With the prior (standard deviation 1) and seat term of `results.md`, the fit reproduces its eight cross-model ratings exactly (158, 92, 65, 55, 36, -41, -129, -235), which checks the fit.

**Ratings.** Cross-model, on an Elo scale with the cohort mean at 0: astra +165 (95% CI +118 to +220), opus +96 (+40 to +158), sol +67 (+21 to +116), haiku 5.5 +57 (+18 to +100), sonnet +37 (-13 to +90), terra -44 (-117 to +27), haiku 4.5 -134 (-208 to -68), luna -244 (-329 to -176). Astra, haiku 4.5 and luna stand apart as the extremes; the five in between overlap. Drawing seeds instead of blocks moves the intervals modestly.
- Within the sweeps, xhigh or max is the top level in five of six models (haiku 4.5 has no such level; its top is medium, then minimal). Off or low is the bottom level in five of six: luna max +152 and xhigh +152 against low -159 and off -152; sonnet max +111 against low -92. Sol is flat: every level sits within about 70 Elo and the intervals overlap. The order of neighbouring levels is mostly inside the intervals.
- Opus xhigh +109 (+40 to +191) against low -114 (-221 to -29), with medium -9 and high +14 between.

**Matchup effects: none worth keeping.** The observed pair share minus the fitted expectation is small and is reported as a descriptive residual. It is not a test: the ratings are regularized, so residuals are forced (a pair at the end of a chain of pairs is pulled to its fit), and the bootstrap range around a residual is not a calibrated interval around zero. The largest cross-model residual is haiku 4.5 against sonnet (2/20 observed against 27% fitted).
- The test is held-out prediction. Whole seed blocks were held out (5 repeats of 10-fold cross-validation, with the shrinkage chosen inside each training set from 0 to 1.6, so no held-out block picks it). In every cohort the nested pair-effect model scored no better than ratings alone: the gain per match is between -0.0055 and -0.0002 nats, and the lower end of its interval is never above 0. The shrinkage chose 0 (ratings only) in most folds for the cross-model cohort, haiku 5.5, terra and Opus. So **no cohort keeps pair effects**.
- The same holds when the ratings also have a seat term and a round 1 starter term, which on their own lower the cross-model loss from 0.5936 to 0.5675 per match.
- Reverse pairs, described and not tested: for the entrant seated first, a real matchup effect should show the opposite sign when A sat first and when B sat first. 45 of 104 pairs (43.3%) do, with a correlation of -0.17 between the A-first effect and minus the B-first effect (a negative value means the two orders lean the same way). The signs are not independent (the two orders of a block share a seed, seeds are reused across pairings, and the ratings are fitted jointly), so no test is made. The two entrants' effects in a pair sum to zero to rounding (9e-17) because every match's shares sum to 1.
- With 20 matches per pair, only large pair effects could show.

**Seat and starter.** Whoever opens round 1 (read from the public line `Round 1 begins ... Player X starts.` of each match's events) also fired the first shot in 2118 of 2118 matches. The seed decides that position, and both matches of a block share it.
- **Position 1:** 1074/2114 = 50.8% over 1,057 complete blocks at 29 seeds (95% CI by seeds 43.2% to 58.6%; by seed blocks 48.5% to 53.0%). Cross-model 232/494 = 47.0% (38.0% to 57.2% by seeds). Tournament 3 24/40 = 60.0% (45.0% to 72.6%).
- **Starter:** the player who opens round 1 won 1200/2114 = 56.8% (50.2% to 63.9% by seeds; 54.7% to 58.8% by seed blocks). The overall starter association stands: it is about 7 points above even.
- **Split:** the position and starter effects below are a descriptive additive split of block shares by which position starts. Every one of the 29 complete-block seeds has exactly one starter position, so a starter effect cannot be told from a seed effect. The split describes these seed blocks; only the seeds-drawn intervals reach beyond them. Starter +6.8 points overall (seeds -0.1 to +14.1; blocks +4.8 to +8.9), +10.5 cross-model (+1.8 to +18.8; blocks +6.1 to +14.8). Position +1.1 overall (-6.4 to +7.6 by seeds).
- **It depends on the seed.** The starter won 154/210 = 73.3% of matches at seed 3000 and 14/44 = 31.8% at seed 3005. Counting each of the 19 seeds with 10 or more blocks once, the starter's mean share is 57.6% (51.4% to 63.8%, seeds drawn). Starter figures are therefore not reported per model: a model's blocks cover a handful of seeds, so they say as much about those seeds as about the model. Position 1 per model is in the tables and sits near 50% for every model.
- By code, the starter effect is +11.0 under `51b8366684f0` and +5.4 under `9e7d7ff22891` (seeds -0.7 to +21.6 and -2.5 to +13.4); position -3.1 and +2.5 (by seeds -14.6 to +7.7 and -6.9 to +10.4).
- **Recommendation:** a starter term is worth keeping as an option for future ratings. It lowers held-out loss a lot (cross-model 0.5936 to 0.5675 per match) and moves cross-model ratings by up to 15.7 Elo. The headline fits stay without it.

**Tournament 3 (Opus xhigh against Astra medium).**
- **41 matches** (21 seed blocks, seed 3030 half): Opus 22/41 = 53.7% (38.1% to 69.0%); Elo gap +25 (-84 to +132).
- **40 matches** (20 complete seed pairs): Opus 22/40 = 55.0% (40.0% to 70.0%); gap +35 (-70 to +146). Opus won both matches on 6 seeds, split on 10 and lost both on 4.
- **Matched with Opus medium against Astra** on seeds 3000 to 3009, which is the same for 40 and 41 matches: 10/20 against 9/20, +5.0 points (-15.0 to +25.0, seeds drawn).
- By code: `9e7d7ff22891` 21/38 = 55.3% and `3c9b98f8b3f4` 1/3 (the last match of seed 3029's pair and seed 3030's). Inconclusive either way, as `results.md` says.

## Method
- **Ratings:** the first-seated entrant wins with probability 1/(1 + exp(-(theta_first - theta_second))), and a win share w counts as w wins and 1 - w losses. A mean-zero Gaussian prior on theta (standard deviation 3) regularizes the fit; it also shrinks rating differences slightly. Ratings are reported on the Elo scale with the cohort mean at 0. Intervals draw seed blocks 2,000 times.
- **Observed against fitted:** for each pair, the observed share of the alphabetically first entrant minus the sum of its fitted win probabilities over the pair's matches, as a share, with each resample refitted. Descriptive only (see above).
- **Pair effects:** a term delta per pair with a prior of standard deviation tau, tau in {0 (ratings only), 0.1, 0.2, 0.4, 0.8, 1.6}. Scored by mean log loss on held-out blocks (5 repeats of 10-fold cross-validation); the nested row picks tau by 5-fold cross-validation inside each training set. The verdict needs the lower end of the 95% interval of the gain (drawn over blocks) above 0.
- **Seat and starter:** for a complete block, position 1's share is the mean over its two matches, which cancels who the entrants are. The starter's share is taken the same way. The two effects are the position and starter terms of an additive split of those block shares by which position starts, weighting the two starts equally. Headline intervals draw seeds.

## Limits
- **Shared seeds.** The seed block id includes the pairing, but every pairing of a tournament plays the same seeds (tournament 1's cross-model games use 10 seeds, each sweep 10), so blocks of different pairings share deals. Seed-block intervals therefore understate the uncertainty of position and starter effects, which is why the seeds-drawn interval is the headline there (about 10 to 19 clusters, so it is rough). Rating intervals hardly change.
- **Unmatched blocks.** Half blocks (4 matches: 3 haiku 4.5 against astra, and tournament 3's seed 3030) cannot be matched and are left out of every seat figure.
- **Power.** The held-out test can rule out large pair effects only; "none kept" is not "none exist". Cohorts with 40 blocks (Opus effort) are the weakest, and a pair-effect model with 4 pairs is almost saturated.
- **Code hashes.** The cross-model cohort mixes `51b8366684f0` (417 matches) and `9e7d7ff22891` (80); three sweeps and tournament 3 also carry a few old-code or new-code matches. Refitting on the main code alone moves no remaining rating by more than 11.4 Elo (largest: haiku 4.5 sweep), inside the intervals.
- **Position and starter overlap** because the seed fixes the starter's position, and tournament 1's seeds 3000 to 3009 start position 2 six times in ten.
- **No replays.** Everything comes from standings, seating and the public round 1 line; no moves were reviewed.

## Tables

<!-- tables:start -->
### Schedule coverage

| cohort | entrants | scored matches | complete / half blocks | pairs played | matches per pair min / median / max | matches by code hash | connected | scheduled by status |
|---|---|---|---|---|---|---|---|---|
| cpa-tiers medium cross-model | 8 | 497 | 247 / 3 | 25/28 | 17 / 20 / 20 | `51b8366684f0` 417, `9e7d7ff22891` 80 | yes | 497 completed, 3 partial (skipped) |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | `51b8366684f0` 12, `9e7d7ff22891` 188 | yes | 200 completed |
| cpa-tiers sweep claude-haiku-5-5 | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | `51b8366684f0` 20, `9e7d7ff22891` 280 | yes | 300 completed |
| cpa-tiers sweep claude-sonnet-5-5 | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | `51b8366684f0` 5, `9e7d7ff22891` 295 | yes | 300 completed |
| cpa-tiers sweep gpt-5.6-terra | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | `9e7d7ff22891` 200 | yes | 200 completed |
| cpa-tiers sweep gpt-6-luna | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | `9e7d7ff22891` 300 | yes | 300 completed |
| cpa-tiers sweep gpt-6.1-sol | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | `9e7d7ff22891` 200 | yes | 200 completed |
| opus-effort | 4 | 80 | 40 / 0 | 4/6 | 20 / 20 / 20 | `9e7d7ff22891` 80 | yes | 80 completed |
| tournament 3 | 2 | 41 | 20 / 1 | 1/1 | 41 / 41 / 41 | `3c9b98f8b3f4` 3, `9e7d7ff22891` 38 | yes | 41 completed, 5 partial (skipped), 14 unstarted |

Matches outside every cohort: 0.

### Ratings and observed pairs

#### cpa-tiers medium cross-model: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| gpt-6-astra | 84/117 = 71.8% | +165 | +118 to +220 | +121 to +211 |
| claude-opus-5-5 | 75/120 = 62.5% | +96 | +40 to +158 | +30 to +170 |
| gpt-6.1-sol | 83/140 = 59.3% | +67 | +21 to +116 | +17 to +130 |
| claude-haiku-5-5 | 81/140 = 57.9% | +57 | +18 to +100 | +27 to +90 |
| claude-sonnet-5-5 | 77/140 = 55.0% | +37 | -13 to +90 | -14 to +90 |
| gpt-5.6-terra | 37/80 = 46.2% | -44 | -117 to +27 | -147 to +47 |
| claude-haiku-4-5-20251001 | 35/117 = 29.9% | -134 | -208 to -68 | -204 to -73 |
| gpt-6-luna | 25/140 = 17.9% | -244 | -329 to -176 | -314 to -187 |

With a seat term and a round 1 starter term in the fit (position 1 -12 Elo, the starter +96 Elo) the largest rating change is 15.7 Elo. Fitting only the 417 matches under code `51b8366684f0` (leaving out 80 matches and the entrant gpt-5.6-terra) moves no remaining rating by more than 7.4 Elo.


#### cpa-tiers medium cross-model: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below.

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-5-5 | 6/20 = 30.0% | 25.0% | +5.0 | -10.1 to +20.7 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5 | 7/20 = 35.0% | 21.1% | +13.9 | -3.6 to +32.2 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5 | 2/20 = 10.0% | 27.2% | -17.2 | -31.0 to -4.3 |
| claude-haiku-4-5-20251001 vs gpt-6-astra | 2/17 = 11.8% | 15.2% | -3.4 | -16.5 to +10.9 |
| claude-haiku-4-5-20251001 vs gpt-6-luna | 12/20 = 60.0% | 65.3% | -5.3 | -29.4 to +16.2 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol | 6/20 = 30.0% | 24.0% | +6.0 | -12.1 to +27.6 |
| claude-haiku-5-5 vs claude-opus-5-5 | 7/20 = 35.0% | 44.5% | -9.5 | -24.2 to +4.3 |
| claude-haiku-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 52.8% | +7.2 | -9.5 to +25.3 |
| claude-haiku-5-5 vs gpt-5.6-terra | 13/20 = 65.0% | 64.1% | +0.9 | -12.5 to +15.7 |
| claude-haiku-5-5 vs gpt-6-astra | 6/20 = 30.0% | 35.0% | -5.0 | -20.2 to +8.3 |
| claude-haiku-5-5 vs gpt-6-luna | 19/20 = 95.0% | 84.9% | +10.1 | -1.2 to +20.1 |
| claude-haiku-5-5 vs gpt-6.1-sol | 10/20 = 50.0% | 48.6% | +1.4 | -12.6 to +15.5 |
| claude-opus-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 58.3% | +1.7 | -15.1 to +18.8 |
| claude-opus-5-5 vs gpt-6-astra | 9/20 = 45.0% | 40.2% | +4.8 | -7.8 to +15.6 |
| claude-opus-5-5 vs gpt-6-luna | 16/20 = 80.0% | 87.6% | -7.6 | -29.6 to +9.3 |
| claude-opus-5-5 vs gpt-6.1-sol | 12/20 = 60.0% | 54.1% | +5.9 | -10.5 to +23.8 |
| claude-sonnet-5-5 vs gpt-5.6-terra | 11/20 = 55.0% | 61.4% | -6.4 | -27.1 to +12.6 |
| claude-sonnet-5-5 vs gpt-6-astra | 7/20 = 35.0% | 32.5% | +2.5 | -11.8 to +16.5 |
| claude-sonnet-5-5 vs gpt-6-luna | 17/20 = 85.0% | 83.5% | +1.5 | -12.8 to +15.5 |
| claude-sonnet-5-5 vs gpt-6.1-sol | 8/20 = 40.0% | 45.8% | -5.8 | -23.6 to +10.8 |
| gpt-5.6-terra vs gpt-6-luna | 15/20 = 75.0% | 76.0% | -1.0 | -18.8 to +16.2 |
| gpt-5.6-terra vs gpt-6.1-sol | 6/20 = 30.0% | 34.6% | -4.6 | -19.6 to +9.1 |
| gpt-6-astra vs gpt-6-luna | 19/20 = 95.0% | 91.3% | +3.7 | -6.9 to +11.2 |
| gpt-6-astra vs gpt-6.1-sol | 12/20 = 60.0% | 63.7% | -3.7 | -20.0 to +12.2 |
| gpt-6-luna vs gpt-6.1-sol | 3/20 = 15.0% | 14.3% | +0.7 | -12.3 to +16.1 |
#### cpa-tiers sweep claude-haiku-4-5-20251001: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 | 47/80 = 58.8% | +51 | -1 to +109 | +1 to +106 |
| claude-haiku-4-5-20251001-minimal | 46/80 = 57.5% | +44 | -24 to +114 | -6 to +92 |
| claude-haiku-4-5-20251001-high | 43/80 = 53.8% | +22 | -37 to +87 | -65 to +111 |
| claude-haiku-4-5-20251001-low | 41/80 = 51.2% | +8 | -50 to +67 | -35 to +52 |
| claude-haiku-4-5-20251001-off | 23/80 = 28.7% | -126 | -201 to -65 | -206 to -56 |

With a seat term and a round 1 starter term in the fit (position 1 +19 Elo, the starter +57 Elo) the largest rating change is 3.5 Elo. Fitting only the 188 matches under code `9e7d7ff22891` (leaving out 12 matches) moves no remaining rating by more than 11.4 Elo.


#### cpa-tiers sweep claude-haiku-4-5-20251001: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below.

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-high | 9/20 = 45.0% | 54.1% | -9.1 | -25.0 to +4.9 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-low | 12/20 = 60.0% | 56.2% | +3.8 | -11.4 to +20.1 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-minimal | 10/20 = 50.0% | 51.0% | -1.0 | -17.8 to +15.3 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 73.5% | +6.5 | -7.8 to +21.9 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-low | 8/20 = 40.0% | 52.1% | -12.1 | -30.1 to +3.3 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal | 11/20 = 55.0% | 46.9% | +8.1 | -10.0 to +26.2 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 70.1% | -5.1 | -22.3 to +10.9 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-minimal | 6/20 = 30.0% | 44.9% | -14.9 | -34.3 to +2.6 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-off | 15/20 = 75.0% | 68.4% | +6.6 | -7.5 to +21.6 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 72.7% | -7.7 | -29.0 to +10.1 |
#### cpa-tiers sweep claude-haiku-5-5: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| claude-haiku-5-5-xhigh | 65/100 = 65.0% | +92 | +42 to +149 | +48 to +133 |
| claude-haiku-5-5-max | 60/100 = 60.0% | +61 | +8 to +113 | -12 to +143 |
| claude-haiku-5-5-high | 54/100 = 54.0% | +24 | -22 to +78 | +0 to +48 |
| claude-haiku-5-5 | 45/100 = 45.0% | -30 | -82 to +17 | -80 to +13 |
| claude-haiku-5-5-low | 45/100 = 45.0% | -30 | -85 to +27 | -67 to +6 |
| claude-haiku-5-5-off | 31/100 = 31.0% | -117 | -180 to -66 | -171 to -77 |

With a seat term and a round 1 starter term in the fit (position 1 -22 Elo, the starter +94 Elo) the largest rating change is 8.5 Elo. Fitting only the 280 matches under code `9e7d7ff22891` (leaving out 20 matches) moves no remaining rating by more than 10.0 Elo.


#### cpa-tiers sweep claude-haiku-5-5: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below.

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-5-5 vs claude-haiku-5-5-high | 7/20 = 35.0% | 42.3% | -7.3 | -21.8 to +6.1 |
| claude-haiku-5-5 vs claude-haiku-5-5-low | 8/20 = 40.0% | 50.0% | -10.0 | -27.1 to +6.4 |
| claude-haiku-5-5 vs claude-haiku-5-5-max | 9/20 = 45.0% | 37.3% | +7.7 | -7.2 to +22.7 |
| claude-haiku-5-5 vs claude-haiku-5-5-off | 14/20 = 70.0% | 62.4% | +7.6 | -5.5 to +23.3 |
| claude-haiku-5-5 vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 33.2% | +1.8 | -14.7 to +19.9 |
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 57.7% | +7.3 | -9.0 to +24.9 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 44.8% | +0.2 | -18.3 to +19.3 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 69.3% | -4.3 | -18.1 to +9.1 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 40.4% | -10.4 | -26.7 to +2.9 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 37.3% | -2.3 | -19.8 to +15.2 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 62.4% | -7.4 | -25.3 to +10.6 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 33.2% | +6.8 | -6.2 to +19.8 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 73.6% | +6.4 | -8.0 to +21.1 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 45.5% | -0.5 | -15.7 to +15.1 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 23.1% | +1.9 | -15.0 to +20.9 |
#### cpa-tiers sweep claude-sonnet-5-5: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| claude-sonnet-5-5-max | 68/100 = 68.0% | +111 | +52 to +178 | +24 to +221 |
| claude-sonnet-5-5-xhigh | 58/100 = 58.0% | +48 | -6 to +104 | -12 to +114 |
| claude-sonnet-5-5-high | 51/100 = 51.0% | +6 | -63 to +66 | -42 to +60 |
| claude-sonnet-5-5 | 45/100 = 45.0% | -30 | -89 to +26 | -109 to +47 |
| claude-sonnet-5-5-off | 43/100 = 43.0% | -42 | -99 to +16 | -85 to +0 |
| claude-sonnet-5-5-low | 35/100 = 35.0% | -92 | -153 to -34 | -142 to -48 |

With a seat term and a round 1 starter term in the fit (position 1 +30 Elo, the starter +35 Elo) the largest rating change is 1.9 Elo. Fitting only the 295 matches under code `9e7d7ff22891` (leaving out 5 matches) moves no remaining rating by more than 5.9 Elo.


#### cpa-tiers sweep claude-sonnet-5-5: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below.

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-sonnet-5-5 vs claude-sonnet-5-5-high | 7/20 = 35.0% | 44.9% | -9.9 | -28.7 to +7.6 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-low | 11/20 = 55.0% | 58.8% | -3.8 | -22.6 to +14.7 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-max | 8/20 = 40.0% | 30.8% | +9.2 | -7.8 to +27.5 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-off | 10/20 = 50.0% | 51.7% | -1.7 | -19.6 to +16.5 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 39.0% | +6.0 | -11.7 to +25.9 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 63.6% | -8.6 | -31.1 to +11.3 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 35.4% | +4.6 | -14.5 to +25.4 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 56.9% | +13.1 | -1.2 to +31.1 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 44.0% | -19.0 | -37.4 to -1.3 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 23.8% | -8.8 | -22.9 to +4.7 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 42.9% | +7.1 | -9.7 to +25.7 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 31.0% | -11.0 | -27.3 to +3.9 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 70.7% | -0.7 | -22.5 to +20.3 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 58.9% | +6.1 | -11.9 to +24.0 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 37.3% | +17.7 | +5.8 to +31.4 |
#### cpa-tiers sweep gpt-5.6-terra: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| gpt-5.6-terra-xhigh | 48/80 = 60.0% | +57 | +3 to +117 | +0 to +104 |
| gpt-5.6-terra-max | 47/80 = 58.8% | +50 | -10 to +117 | +0 to +105 |
| gpt-5.6-terra-high | 37/80 = 46.2% | -21 | -84 to +38 | -71 to +22 |
| gpt-5.6-terra | 36/80 = 45.0% | -28 | -81 to +22 | -74 to +22 |
| gpt-5.6-terra-low | 32/80 = 40.0% | -57 | -121 to +1 | -120 to +7 |

With a seat term and a round 1 starter term in the fit (position 1 -15 Elo, the starter +29 Elo) the largest rating change is 0.5 Elo.


#### cpa-tiers sweep gpt-5.6-terra: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below.

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-5.6-terra vs gpt-5.6-terra-high | 10/20 = 50.0% | 49.0% | +1.0 | -13.2 to +15.1 |
| gpt-5.6-terra vs gpt-5.6-terra-low | 11/20 = 55.0% | 54.1% | +0.9 | -14.8 to +15.9 |
| gpt-5.6-terra vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.0% | +1.0 | -16.4 to +19.4 |
| gpt-5.6-terra vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 38.0% | -3.0 | -17.2 to +10.2 |
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 55.1% | -10.1 | -29.0 to +8.0 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 40.0% | +0.0 | -15.7 to +16.5 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 39.0% | +11.0 | -7.3 to +29.4 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 35.2% | +4.8 | -11.9 to +24.8 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 34.2% | -14.2 | -30.2 to -0.2 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 49.0% | +6.0 | -8.1 to +22.9 |
#### cpa-tiers sweep gpt-6-luna: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| gpt-6-luna-max | 72/100 = 72.0% | +152 | +96 to +219 | +113 to +200 |
| gpt-6-luna-xhigh | 72/100 = 72.0% | +152 | +95 to +224 | +111 to +203 |
| gpt-6-luna-high | 62/100 = 62.0% | +81 | +16 to +154 | +15 to +159 |
| gpt-6-luna | 39/100 = 39.0% | -74 | -146 to -8 | -162 to +1 |
| gpt-6-luna-off | 28/100 = 28.0% | -152 | -219 to -95 | -221 to -92 |
| gpt-6-luna-low | 27/100 = 27.0% | -159 | -240 to -93 | -194 to -135 |

With a seat term and a round 1 starter term in the fit (position 1 +31 Elo, the starter +6 Elo) the largest rating change is 1.1 Elo.


#### cpa-tiers sweep gpt-6-luna: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below.

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-luna vs gpt-6-luna-high | 8/20 = 40.0% | 29.2% | +10.8 | -8.5 to +31.4 |
| gpt-6-luna vs gpt-6-luna-low | 12/20 = 60.0% | 62.1% | -2.1 | -23.6 to +19.7 |
| gpt-6-luna vs gpt-6-luna-max | 5/20 = 25.0% | 21.5% | +3.5 | -11.3 to +19.0 |
| gpt-6-luna vs gpt-6-luna-off | 12/20 = 60.0% | 61.1% | -1.1 | -20.7 to +17.1 |
| gpt-6-luna vs gpt-6-luna-xhigh | 2/20 = 10.0% | 21.5% | -11.5 | -24.9 to +1.0 |
| gpt-6-luna-high vs gpt-6-luna-low | 14/20 = 70.0% | 79.9% | -9.9 | -25.2 to +5.5 |
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 39.9% | -4.9 | -24.3 to +14.9 |
| gpt-6-luna-high vs gpt-6-luna-off | 18/20 = 90.0% | 79.2% | +10.8 | -2.5 to +23.8 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 39.9% | +15.1 | -2.1 to +35.0 |
| gpt-6-luna-low vs gpt-6-luna-max | 2/20 = 10.0% | 14.3% | -4.3 | -16.0 to +8.4 |
| gpt-6-luna-low vs gpt-6-luna-off | 8/20 = 40.0% | 48.9% | -8.9 | -26.1 to +7.5 |
| gpt-6-luna-low vs gpt-6-luna-xhigh | 3/20 = 15.0% | 14.3% | +0.7 | -14.2 to +19.7 |
| gpt-6-luna-max vs gpt-6-luna-off | 16/20 = 80.0% | 85.2% | -5.2 | -20.1 to +9.2 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 50.0% | +0.0 | -14.2 to +14.9 |
| gpt-6-luna-off vs gpt-6-luna-xhigh | 2/20 = 10.0% | 14.8% | -4.8 | -16.2 to +8.3 |
#### cpa-tiers sweep gpt-6.1-sol: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| gpt-6.1-sol-max | 47/80 = 58.8% | +49 | -7 to +107 | -14 to +109 |
| gpt-6.1-sol-low | 39/80 = 48.8% | -7 | -67 to +51 | -58 to +49 |
| gpt-6.1-sol-xhigh | 39/80 = 48.8% | -7 | -61 to +49 | -58 to +42 |
| gpt-6.1-sol-high | 38/80 = 47.5% | -14 | -69 to +37 | -57 to +28 |
| gpt-6.1-sol | 37/80 = 46.2% | -21 | -82 to +37 | -72 to +29 |

With a seat term and a round 1 starter term in the fit (position 1 +39 Elo, the starter +25 Elo) the largest rating change is 0.9 Elo.


#### cpa-tiers sweep gpt-6.1-sol: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below.

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-sol vs gpt-6.1-sol-high | 12/20 = 60.0% | 49.0% | +11.0 | -2.0 to +25.7 |
| gpt-6.1-sol vs gpt-6.1-sol-low | 7/20 = 35.0% | 48.0% | -13.0 | -31.7 to +2.7 |
| gpt-6.1-sol vs gpt-6.1-sol-max | 8/20 = 40.0% | 40.1% | -0.1 | -16.5 to +15.8 |
| gpt-6.1-sol vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 48.0% | +2.0 | -16.5 to +22.0 |
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 49.0% | +11.0 | -5.4 to +29.1 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 41.0% | +4.0 | -12.5 to +21.4 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 49.0% | -4.0 | -19.2 to +10.3 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 42.0% | -12.0 | -30.2 to +4.3 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 50.0% | +10.0 | -6.0 to +26.6 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 58.0% | -8.0 | -23.2 to +5.6 |
#### opus-effort: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| claude-opus-5-5-xhigh | 26/40 = 65.0% | +109 | +36 to +194 | +28 to +206 |
| claude-opus-5-5-high | 18/40 = 45.0% | +14 | -68 to +107 | -51 to +78 |
| claude-opus-5-5 | 29/60 = 48.3% | -9 | -70 to +47 | -69 to +65 |
| claude-opus-5-5-low | 7/20 = 35.0% | -114 | -228 to -30 | -196 to -60 |

With a seat term and a round 1 starter term in the fit (position 1 +19 Elo, the starter +57 Elo) the largest rating change is 3.2 Elo.


#### opus-effort: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below.

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5 vs claude-opus-5-5-high | 9/20 = 45.0% | 46.7% | -1.7 | -13.9 to +10.3 |
| claude-opus-5-5 vs claude-opus-5-5-low | 13/20 = 65.0% | 64.6% | +0.4 | +0.1 to +1.0 |
| claude-opus-5-5 vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 33.7% | +1.3 | -9.9 to +12.9 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 36.7% | -1.7 | -14.4 to +9.9 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| cpa-tiers medium cross-model | 0.5936 | 0.5940 | -0.0004 | -0.0008 to -0.0001 | 0: 45, 0.1: 1, 0.2: 3, 0.4: 1 | tau=0.1: 0.5938, tau=0.2: 0.5944, tau=0.4: 0.5970, tau=0.8: 0.6038, tau=1.6: 0.6118 | not kept |
| cpa-tiers medium cross-model (seat and starter terms) | 0.5675 | 0.5677 | -0.0002 | -0.0006 to +0.0002 | 0: 47, 0.1: 1, 0.2: 1, 0.4: 1 | tau=0.1: 0.5677, tau=0.2: 0.5685, tau=0.4: 0.5715, tau=0.8: 0.5792, tau=1.6: 0.5883 | not kept |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 0.6735 | 0.6791 | -0.0055 | -0.0119 to -0.0000 | 0: 23, 0.1: 7, 0.2: 4, 0.4: 14, 0.8: 2 | tau=0.1: 0.6736, tau=0.2: 0.6741, tau=0.4: 0.6771, tau=0.8: 0.6851, tau=1.6: 0.6922 | not kept |
| cpa-tiers sweep claude-haiku-4-5-20251001 (seat and starter terms) | 0.6713 | 0.6752 | -0.0039 | -0.0086 to +0.0007 | 0: 22, 0.1: 6, 0.2: 8, 0.4: 13, 0.8: 1 | tau=0.1: 0.6713, tau=0.2: 0.6717, tau=0.4: 0.6744, tau=0.8: 0.6821, tau=1.6: 0.6894 | not kept |
| cpa-tiers sweep claude-haiku-5-5 | 0.6641 | 0.6645 | -0.0004 | -0.0009 to +0.0000 | 0: 43, 0.1: 2, 0.2: 5 | tau=0.1: 0.6645, tau=0.2: 0.6656, tau=0.4: 0.6698, tau=0.8: 0.6783, tau=1.6: 0.6852 | not kept |
| cpa-tiers sweep claude-haiku-5-5 (seat and starter terms) | 0.6414 | 0.6422 | -0.0008 | -0.0015 to -0.0002 | 0: 43, 0.1: 4, 0.2: 2, 0.4: 1 | tau=0.1: 0.6418, tau=0.2: 0.6431, tau=0.4: 0.6476, tau=0.8: 0.6568, tau=1.6: 0.6644 | not kept |
| cpa-tiers sweep claude-sonnet-5-5 | 0.6738 | 0.6784 | -0.0045 | -0.0115 to +0.0013 | 0: 13, 0.1: 5, 0.2: 13, 0.4: 16, 0.8: 3 | tau=0.1: 0.6733, tau=0.2: 0.6724, tau=0.4: 0.6722, tau=0.8: 0.6769, tau=1.6: 0.6831 | not kept |
| cpa-tiers sweep claude-sonnet-5-5 (seat and starter terms) | 0.6697 | 0.6737 | -0.0040 | -0.0096 to +0.0013 | 0: 12, 0.1: 4, 0.2: 15, 0.4: 17, 0.8: 2 | tau=0.1: 0.6694, tau=0.2: 0.6691, tau=0.4: 0.6706, tau=0.8: 0.6779, tau=1.6: 0.6860 | not kept |
| cpa-tiers sweep gpt-5.6-terra | 0.6904 | 0.6924 | -0.0020 | -0.0037 to -0.0005 | 0: 39, 0.1: 2, 0.2: 6, 0.4: 3 | tau=0.1: 0.6907, tau=0.2: 0.6916, tau=0.4: 0.6951, tau=0.8: 0.7024, tau=1.6: 0.7084 | not kept |
| cpa-tiers sweep gpt-5.6-terra (seat and starter terms) | 0.7001 | 0.7032 | -0.0031 | -0.0057 to -0.0007 | 0: 37, 0.1: 1, 0.2: 5, 0.4: 7 | tau=0.1: 0.7004, tau=0.2: 0.7014, tau=0.4: 0.7051, tau=0.8: 0.7125, tau=1.6: 0.7186 | not kept |
| cpa-tiers sweep gpt-6-luna | 0.5777 | 0.5826 | -0.0050 | -0.0083 to -0.0016 | 0: 32, 0.1: 3, 0.2: 6, 0.4: 8, 0.8: 1 | tau=0.1: 0.5777, tau=0.2: 0.5782, tau=0.4: 0.5808, tau=0.8: 0.5893, tau=1.6: 0.6003 | not kept |
| cpa-tiers sweep gpt-6-luna (seat and starter terms) | 0.5816 | 0.5832 | -0.0017 | -0.0037 to +0.0001 | 0: 33, 0.1: 3, 0.2: 8, 0.4: 6 | tau=0.1: 0.5816, tau=0.2: 0.5818, tau=0.4: 0.5838, tau=0.8: 0.5912, tau=1.6: 0.6014 | not kept |
| cpa-tiers sweep gpt-6.1-sol | 0.7073 | 0.7127 | -0.0054 | -0.0125 to +0.0006 | 0: 18, 0.1: 6, 0.2: 8, 0.4: 14, 0.8: 3, 1.6: 1 | tau=0.1: 0.7070, tau=0.2: 0.7063, tau=0.4: 0.7067, tau=0.8: 0.7112, tau=1.6: 0.7162 | not kept |
| cpa-tiers sweep gpt-6.1-sol (seat and starter terms) | 0.7064 | 0.7083 | -0.0019 | -0.0085 to +0.0042 | 0: 18, 0.1: 2, 0.2: 11, 0.4: 18, 0.8: 1 | tau=0.1: 0.7060, tau=0.2: 0.7053, tau=0.4: 0.7054, tau=0.8: 0.7098, tau=1.6: 0.7151 | not kept |
| opus-effort | 0.6895 | 0.6903 | -0.0008 | -0.0024 to +0.0003 | 0: 48, 0.2: 1, 0.8: 1 | tau=0.1: 0.6899, tau=0.2: 0.6909, tau=0.4: 0.6935, tau=0.8: 0.6971, tau=1.6: 0.6994 | not kept |
| opus-effort (seat and starter terms) | 0.7175 | 0.7218 | -0.0043 | -0.0105 to -0.0003 | 0: 46, 0.1: 1, 0.4: 1, 0.8: 1, 1.6: 1 | tau=0.1: 0.7181, tau=0.2: 0.7196, tau=0.4: 0.7237, tau=0.8: 0.7298, tau=1.6: 0.7339 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| cpa-tiers medium cross-model | 10/25 = 40.0% | -0.17 |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 7/10 = 70.0% | +0.05 |
| cpa-tiers sweep claude-haiku-5-5 | 5/15 = 33.3% | -0.44 |
| cpa-tiers sweep claude-sonnet-5-5 | 6/15 = 40.0% | -0.04 |
| cpa-tiers sweep gpt-5.6-terra | 4/10 = 40.0% | -0.15 |
| cpa-tiers sweep gpt-6-luna | 7/15 = 46.7% | -0.09 |
| cpa-tiers sweep gpt-6.1-sol | 6/10 = 60.0% | -0.18 |
| opus-effort | 0/4 = 0.0% | -0.99 |
| all cohorts pooled | 45/104 = 43.3% | -0.17 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 8.9e-17, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 2118 of 2118 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 1057 blocks, 29 seeds (4 matches in half blocks left out) | 1074/2114 = 50.8% | 43.2% to 58.6% | 48.5% to 53.0% |
| cpa-tiers medium cross-model: 247 blocks, 19 seeds (3 matches in half blocks left out) | 232/494 = 47.0% | 38.0% to 57.2% | 42.7% to 51.2% |
| cpa-tiers sweep claude-haiku-4-5-20251001: 100 blocks, 10 seeds | 105/200 = 52.5% | 43.0% to 60.0% | 46.0% to 59.5% |
| cpa-tiers sweep claude-haiku-5-5: 150 blocks, 10 seeds | 142/300 = 47.3% | 34.7% to 60.3% | 41.3% to 53.7% |
| cpa-tiers sweep claude-sonnet-5-5: 150 blocks, 10 seeds | 162/300 = 54.0% | 43.0% to 65.0% | 48.7% to 59.7% |
| cpa-tiers sweep gpt-5.6-terra: 100 blocks, 10 seeds | 96/200 = 48.0% | 36.5% to 58.5% | 40.5% to 55.5% |
| cpa-tiers sweep gpt-6-luna: 150 blocks, 10 seeds | 160/300 = 53.3% | 47.3% to 59.0% | 48.3% to 58.0% |
| cpa-tiers sweep gpt-6.1-sol: 100 blocks, 10 seeds | 111/200 = 55.5% | 43.0% to 68.0% | 48.5% to 63.0% |
| opus-effort: 40 blocks, 10 seeds | 42/80 = 52.5% | 33.8% to 71.2% | 41.2% to 65.0% |
| tournament 3: 20 blocks, 20 seeds (1 matches in half blocks left out) | 24/40 = 60.0% | 45.0% to 72.6% | 45.0% to 75.0% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 1200/2114 = 56.8% | 50.2% to 63.9% | 54.7% to 58.8% | 508/1057 |
| cpa-tiers medium cross-model | 300/494 = 60.7% | 52.8% to 68.3% | 56.5% to 64.8% | 103/247 |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 115/200 = 57.5% | 50.5% to 65.5% | 50.5% to 64.5% | 50/100 |
| cpa-tiers sweep claude-haiku-5-5 | 186/300 = 62.0% | 51.7% to 72.0% | 56.3% to 67.7% | 75/150 |
| cpa-tiers sweep claude-sonnet-5-5 | 164/300 = 54.7% | 43.3% to 65.0% | 49.3% to 60.0% | 75/150 |
| cpa-tiers sweep gpt-5.6-terra | 108/200 = 54.0% | 42.5% to 64.5% | 46.5% to 61.5% | 50/100 |
| cpa-tiers sweep gpt-6-luna | 152/300 = 50.7% | 44.0% to 57.3% | 45.7% to 55.3% | 75/150 |
| cpa-tiers sweep gpt-6.1-sol | 107/200 = 53.5% | 40.5% to 66.5% | 46.5% to 61.0% | 50/100 |
| opus-effort | 46/80 = 57.5% | 40.0% to 75.0% | 45.0% to 70.0% | 20/40 |
| tournament 3 | 22/40 = 55.0% | 40.0% to 70.0% | 40.0% to 70.0% | 10/20 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +1.1 | -6.4 to +7.6 | -1.2 to +3.2 | +6.8 | -0.1 to +14.1 | +4.8 to +8.9 |
| cpa-tiers medium cross-model | -1.3 | -9.8 to +7.5 | -5.5 to +2.8 | +10.5 | +1.8 to +18.8 | +6.1 to +14.8 |
| cpa-tiers sweep claude-haiku-4-5-20251001 | +2.5 | -7.0 to +9.0 | -4.2 to +9.5 | +7.5 | +0.6 to +16.5 | +0.5 to +14.6 |
| cpa-tiers sweep claude-haiku-5-5 | -2.7 | -13.8 to +8.0 | -8.4 to +3.3 | +12.0 | +0.7 to +22.7 | +6.2 to +17.7 |
| cpa-tiers sweep claude-sonnet-5-5 | +4.0 | -7.9 to +15.0 | -1.4 to +9.6 | +4.7 | -7.1 to +15.3 | -0.8 to +10.0 |
| cpa-tiers sweep gpt-5.6-terra | -2.0 | -14.5 to +8.5 | -9.5 to +5.6 | +4.0 | -7.7 to +15.2 | -3.7 to +11.4 |
| cpa-tiers sweep gpt-6-luna | +3.3 | -3.0 to +9.6 | -1.7 to +8.2 | +0.7 | -5.8 to +7.3 | -4.4 to +5.4 |
| cpa-tiers sweep gpt-6.1-sol | +5.5 | -7.5 to +18.9 | -1.7 to +12.9 | +3.5 | -10.0 to +17.1 | -3.6 to +11.0 |
| opus-effort | +2.5 | -16.7 to +21.9 | -8.8 to +14.1 | +7.5 | -11.9 to +26.2 | -4.9 to +19.8 |
| tournament 3 | +10.0 | -5.8 to +24.0 | -5.5 to +24.7 | +5.0 | -9.5 to +20.0 | -9.4 to +20.0 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| claude-haiku-4-5-20251001: 157 blocks, 19 seeds | 159/314 = 50.6% | 42.3% to 57.7% | 45.2% to 56.1% |
| claude-haiku-5-5: 220 blocks, 19 seeds | 209/440 = 47.5% | 36.6% to 58.5% | 42.7% to 52.5% |
| claude-opus-5-5: 120 blocks, 29 seeds | 117/240 = 48.8% | 38.1% to 60.5% | 42.1% to 55.8% |
| claude-sonnet-5-5: 220 blocks, 19 seeds | 231/440 = 52.5% | 43.4% to 61.1% | 48.2% to 57.3% |
| gpt-5.6-terra: 140 blocks, 10 seeds | 139/280 = 49.6% | 38.9% to 60.7% | 43.6% to 56.1% |
| gpt-6-astra: 77 blocks, 20 seeds | 72/154 = 46.8% | 35.1% to 60.2% | 38.3% to 55.2% |
| gpt-6-luna: 220 blocks, 19 seeds | 227/440 = 51.6% | 47.0% to 56.0% | 48.0% to 55.2% |
| gpt-6.1-sol: 170 blocks, 19 seeds | 176/340 = 51.8% | 41.5% to 62.1% | 46.2% to 57.9% |

#### Per code hash, all cohorts

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| code `51b8366684f0`: 225 blocks, 10 seeds | 198/450 = 44.0% | 34.0% to 55.8% | 39.6% to 48.4% |
| code `9e7d7ff22891`: 830 blocks, 28 seeds | 873/1660 = 52.6% | 43.9% to 61.0% | 50.2% to 54.8% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| code `51b8366684f0` | 278/450 = 61.8% | 52.2% to 69.9% | 57.6% to 66.0% | 83/225 |
| code `9e7d7ff22891` | 921/1660 = 55.5% | 47.7% to 63.3% | 53.1% to 57.8% | 425/830 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| code `51b8366684f0` | -3.1 | -14.6 to +7.7 | -7.8 to +1.3 | +11.0 | -0.7 to +21.6 | +6.3 to +15.5 |
| code `9e7d7ff22891` | +2.5 | -6.9 to +10.4 | +0.1 to +4.7 | +5.4 | -2.5 to +13.4 | +3.0 to +7.8 |
Codes with fewer than 10 complete blocks (`3c9b98f8b3f4` has 1, and 1 block mixes two codes) are left out.

#### Per seed, all cohorts

Cohorts reuse seeds 3000 to 3018 (tournament 3 adds 3020 to 3029), so a seed's starter result pools many pairings.

| seed | position that starts | complete blocks | starter wins/matches = share |
|---|---|---|---|
| 3000 | 2 | 105 | 154/210 = 73.3% |
| 3001 | 2 | 22 | 32/44 = 72.7% |
| 3002 | 2 | 22 | 21/44 = 47.7% |
| 3003 | 2 | 22 | 22/44 = 50.0% |
| 3004 | 1 | 22 | 36/44 = 81.8% |
| 3005 | 1 | 22 | 14/44 = 31.8% |
| 3006 | 1 | 22 | 26/44 = 59.1% |
| 3007 | 2 | 21 | 33/42 = 78.6% |
| 3008 | 2 | 21 | 23/42 = 54.8% |
| 3009 | 1 | 21 | 25/42 = 59.5% |
| 3010 | 1 | 83 | 111/166 = 66.9% |
| 3011 | 1 | 83 | 113/166 = 68.1% |
| 3012 | 2 | 83 | 73/166 = 44.0% |
| 3013 | 2 | 83 | 78/166 = 47.0% |
| 3014 | 1 | 83 | 65/166 = 39.2% |
| 3015 | 1 | 83 | 121/166 = 72.9% |
| 3016 | 1 | 83 | 69/166 = 41.6% |
| 3017 | 2 | 83 | 84/166 = 50.6% |
| 3018 | 2 | 83 | 90/166 = 54.2% |
| 3020 | 2 | 1 | 0/2 = 0.0% |
| 3021 | 2 | 1 | 1/2 = 50.0% |
| 3022 | 2 | 1 | 1/2 = 50.0% |
| 3023 | 1 | 1 | 2/2 = 100.0% |
| 3024 | 1 | 1 | 2/2 = 100.0% |
| 3025 | 1 | 1 | 1/2 = 50.0% |
| 3026 | 1 | 1 | 1/2 = 50.0% |
| 3027 | 1 | 1 | 2/2 = 100.0% |
| 3028 | 1 | 1 | 0/2 = 0.0% |
| 3029 | 2 | 1 | 0/2 = 0.0% |
| the 19 seeds with 10 or more blocks, each once |  | 1047 | mean of seed shares 57.6% (95% CI 51.4% to 63.8%, seeds drawn) |

### Tournament 3

| scored matches | Opus xhigh wins/matches = share | 95% CI (seed blocks drawn, wins over matches) | mean of block shares (a block counts once) | 95% CI | Opus minus Astra, Elo (95% CI) | blocks Opus both / split / Astra both |
|---|---|---|---|---|---|---|
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 38.1% to 69.0% | 52.4% | 35.7% to 69.0% | +25 (-84 to +132) | 6 / 10 / 4 |
| 40 matches, 20 complete seed pairs | 22/40 = 55.0% | 40.0% to 70.0% | 55.0% | 40.0% to 70.0% | +35 (-70 to +146) | 6 / 10 / 4 |

The 41-match estimate adds seed 3030's one scored match, which Astra won, to the 40 matches of complete pairs.

#### Matched against Opus medium vs Astra on the same seeds (tournament 1)

| matched seeds | Opus xhigh wins | Opus medium wins | difference in share (95% CI, seeds drawn) |
|---|---|---|---|
| 10 seeds, 20 matches each | 10/20 | 9/20 | +5.0 pp (-15.0 to +25.0) |

The matched seeds are 3000 to 3009, so the matched estimate is the same whether tournament 3 counts 40 or 41 matches.

#### By code hash

| code hash | Opus xhigh wins/matches = share |
|---|---|
| `3c9b98f8b3f4` | 1/3 = 33.3% |
| `9e7d7ff22891` | 21/38 = 55.3% |
<!-- tables:end -->
