# Matchup analysis

Ratings, pair effects, seat and round 1 starter effects for the scored arena matches, from the analysis database ([database.md](../database.md)). All 2,138 scored matches are two-player. Every rate shows numerator/denominator, a win share counts a split by its share, and every interval is a 95% bootstrap that draws whole seed blocks (the two seat-swapped matches of one pair and seed), never single matches or swaps. The tables below the line "Tables" are generated: `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` rewrites them, with a fixed RNG seed, in about 7 minutes under `nice`. Nothing here reads provenance or account data.

## Findings

**Cohorts and coverage.** Matches are compared only inside a cohort: tournament 1's medium cross-model games, each model's own effort sweep (six of them), tournament 2's Opus effort games, and tournament 3. Each cohort's schedule is connected, so each has one ranking, and no two cohorts share a scale.
- The cross-model cohort has 9 entrants and 517 matches over 29 of the 36 pairs. The 7 missing pairs are DeepSeek against terra, luna, sol and astra, and terra against haiku 4.5, opus and astra. DeepSeek has only 20 matches against 4 opponents (its other 123 scheduled matches were never scored), so its rating of -4 has a 95% interval of -153 to +140 and `results.md` leaves it out.
- Every sweep is a full round robin with 20 matches per pair. Opus effort plays 4 of its 6 pairs, and max has no scored match.
- The ratings are Bradley-Terry fits on the shares. With the prior (standard deviation 1), seat term and entrants of `results.md` (no DeepSeek) the fit reproduces its eight ratings exactly (158, 92, 65, 55, 36, -41, -129, -235), which checks the fit.

**Ratings.** Cross-model, on an Elo scale with the cohort mean at 0: astra +166 (95% CI +118 to +222), opus +104 (+49 to +167), sol +67 (+14 to +120), haiku 5.5 +50 (+8 to +97), sonnet +39 (-15 to +100), terra -45 (-126 to +30), haiku 4.5 -133 (-212 to -67), luna -243 (-331 to -173). Astra, haiku 4.5 and luna stand apart as the extremes; the five in between overlap. Drawing seeds instead of blocks moves the intervals modestly (haiku 5.5's lower end then crosses 0).
- Within the sweeps, xhigh or max is the top level in five of six models (haiku 4.5 has no such level; its top is medium, then minimal). Off or low is the bottom level in five of six: luna max +152 and xhigh +152 against low -159 and off -152; sonnet max +111 against low -92. Sol is flat: every level sits within about 70 Elo and the intervals overlap. The order of neighbouring levels is mostly inside the intervals.
- Opus xhigh +109 (+40 to +191) against low -114 (-221 to -29), with medium -9 and high +14 between.

**Matchup effects: none worth keeping.** Observed pair share minus the fitted expectation is small: of the 108 pairs, 6 have a 95% interval that excludes 0, where chance alone would give about 5. The largest is opus against DeepSeek (4/4 against a fitted 65%, 4 matches), then haiku 4.5 against sonnet (2/20 against a fitted 27%).
- To test whether pair effects help, whole seed blocks were held out (5 repeats of 10-fold cross-validation, with the shrinkage chosen inside each training set from 0 to 1.6, so no held-out block picks it). In every cohort the nested pair-effect model scored no better than ratings alone: the gain per match is between -0.0072 and -0.0003 nats, and the lower end of its interval is never above 0. The shrinkage chose 0 (ratings only) in most folds for the cross-model cohort, haiku 5.5, terra and Opus. So **no cohort keeps pair effects**; the "observed minus fitted" columns are noise-sized.
- The same holds when the ratings also have a seat term and a round 1 starter term, which on their own lower the cross-model loss from 0.5965 to 0.5686 per match.
- Reverse pairs: for the entrant seated first, a real matchup effect should show the opposite sign when A sat first and when B sat first. Across all cohorts 46 of 108 pairs (42.6%) do, sign-test p 0.15; half is what no effect gives. The fewer-than-half is the two orders of a block sharing a seed (a deal that favours the opener favours the first seat of both matches), not a matchup effect. At the pair level the two entrants' effects sum to zero to rounding (4e-17) because every match's shares sum to 1.
- This test has little power for one pair: 20 matches per pair give an interval of about ±20 percentage points, so only large pair effects would show.

**Seat advantage: none by position, a clear one for the opener.** Whoever opens round 1 (read from the public line `Round 1 begins ... Player X starts.` of each match's events) also fired the first shot in 2138 of 2138 matches. The seed decides that position, and both matches of a block share it.
- **Position 1:** 1078/2130 = 50.6% (95% CI 48.5% to 52.7%) over 1,065 complete blocks; cross-model 236/510 = 46.3% (42.2% to 50.6%); tournament 3 24/40 = 60.0% (45.0% to 75.0%). Holding the starter equal, no cohort's position effect has an interval that excludes 0 (all cohorts +0.9 points, -1.2 to +3.0).
- **Starter:** the player who opens round 1 won 1212/2130 = 56.9% (54.7% to 59.0%; drawing seeds, 50.4% to 63.9%). Holding position equal, the starter edge is +6.9 percentage points (+4.8 to +9.0 by blocks, +0.4 to +14.0 by seeds). Cross-model it is +10.9 (+6.8 to +14.8).
- **By model**, starter edge in points: astra +12.1, haiku 5.5 +10.5, opus +10.2, haiku 4.5 +9.0, sol +8.4, sonnet +6.5, terra +6.1, luna +2.1 (-1.7 to +5.7). Luna alone shows no clear edge. A block counts for every model in it, so this says how big the edge is in a model's games, not which model uses it better.
- **By seed it varies a lot:** the starter won 73.1% of 216 matches at seed 3000 and 31.8% of 44 at seed 3005. Counting each of the 19 seeds with 10 or more blocks once, the starter's mean share is 57.7% (51.5% to 64.0%, seeds drawn).
- By code: starter +11.2 under `51b8366684f0` and +5.4 under `9e7d7ff22891`; position -3.4 (-8.1 to +0.9) and +2.5 (+0.1 to +4.8; by seeds -6.4 to +10.3), so the second just excludes 0 by blocks and not by seeds.

**Tournament 3 (Opus xhigh against Astra medium).**
- **41 matches** (21 seed blocks, seed 3030 half): Opus 22/41 = 53.7% (38.1% to 69.0%); Elo gap +25 (-77 to +139).
- **40 matches** (20 complete seed pairs): Opus 22/40 = 55.0% (40.0% to 70.0%); gap +35 (-70 to +146). Opus won both matches on 6 seeds, split on 10 and lost both on 4.
- **Matched with Opus medium against Astra** on seeds 3000 to 3009, which is the same for 40 and 41 matches: 10/20 against 9/20, +5.0 points (-15.0 to +25.0, seeds drawn).
- By code: `9e7d7ff22891` 21/38 = 55.3% and `3c9b98f8b3f4` 1/3 (the last match of seed 3029's pair and seed 3030's). Inconclusive either way, as `results.md` says.

## Method
- **Ratings:** the first-seated entrant wins with probability 1/(1 + exp(-(theta_first - theta_second))), and a win share w counts as w wins and 1 - w losses. A weak Gaussian prior on theta (standard deviation 3) fixes the scale; ratings are on the Elo scale with the cohort mean at 0. Intervals draw seed blocks 2,000 times.
- **Observed against fitted:** for each pair, the observed share of the alphabetically first entrant minus the sum of its fitted win probabilities over the pair's matches, as a share, with each resample refitted.
- **Pair effects:** a term delta per pair with a prior of standard deviation tau, tau in {0 (ratings only), 0.1, 0.2, 0.4, 0.8, 1.6}. Scored by mean log loss on held-out blocks (5 repeats of 10-fold cross-validation); the nested row picks tau by 5-fold cross-validation inside each training set. The verdict needs the lower end of the 95% interval of the gain (drawn over blocks) above 0.
- **Seat and starter:** for a complete block, position 1's share is the mean over its two matches, which cancels who the entrants are. The starter's share is taken the same way. The two effects are the position and starter terms of a linear split of those block shares by which position starts, weighting the two starts equally.

## Limits
- **Shared seeds.** The seed block id includes the pairing, but every pairing of a tournament plays the same seeds (tournament 1's cross-model games use 10 seeds, each sweep 10), so blocks of different pairings share deals. Block intervals therefore understate the uncertainty of position and starter effects; the second interval column draws seeds with every block of a seed (about 10 to 19 clusters, so it is rough). Rating intervals hardly change.
- **Unmatched blocks.** Half blocks (8 matches: 4 DeepSeek and 3 haiku 4.5 against astra, and tournament 3's seed 3030) cannot be matched and are left out of every seat figure.
- **Power.** The held-out test and the pair intervals can rule out large pair effects only; "none kept" is not "none exist". Cohorts with 40 blocks (Opus effort) are the weakest, and a pair-effect model with 4 pairs is almost saturated.
- **Code hashes.** The cross-model cohort mixes `51b8366684f0` (437 matches) and `9e7d7ff22891` (80); three sweeps and tournament 3 also carry a few old-code or new-code matches. Refitting on the main code alone moves no remaining rating by more than 11.4 Elo, inside the intervals. Adding a seat and a starter term moves cross-model ratings by up to 17.3 Elo, DeepSeek's mostly.
- **Position and starter overlap** because the seed fixes the starter's position, and tournament 1's seeds 3000 to 3009 start position 2 six times in ten. The effects above hold one fixed when estimating the other, weighting the two starter positions equally.
- **No replays.** Everything comes from standings, seating and the public round 1 line; no moves were reviewed.

## Tables

<!-- tables:start -->
### Schedule coverage

| cohort | entrants | scored matches | complete / half blocks | pairs played | matches per pair min / median / max | matches by code hash | connected | scheduled by status |
|---|---|---|---|---|---|---|---|---|
| cpa-tiers medium cross-model | 9 | 517 | 255 / 7 | 29/36 | 3 / 20 / 20 | `51b8366684f0` 437, `9e7d7ff22891` 80 | yes | 517 completed, 41 partial (skipped), 82 skipped (skipped) |
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
| gpt-6-astra | 84/117 = 71.8% | +166 | +118 to +222 | +101 to +217 |
| claude-opus-5-5 | 79/124 = 63.7% | +104 | +49 to +167 | +33 to +177 |
| gpt-6.1-sol | 83/140 = 59.3% | +67 | +14 to +120 | +10 to +136 |
| claude-haiku-5-5 | 84/148 = 56.8% | +50 | +8 to +97 | -3 to +81 |
| claude-sonnet-5-5 | 80/145 = 55.2% | +39 | -15 to +100 | -13 to +84 |
| deepseek-v4.1-flash | 9/20 = 45.0% | -4 | -153 to +140 | -224 to +421 |
| gpt-5.6-terra | 37/80 = 46.2% | -45 | -126 to +30 | -161 to +59 |
| claude-haiku-4-5-20251001 | 36/120 = 30.0% | -133 | -212 to -67 | -225 to -63 |
| gpt-6-luna | 25/140 = 17.9% | -243 | -331 to -173 | -327 to -178 |

With a seat term and a round 1 starter term in the fit (position 1 -16 Elo, the starter +100 Elo) the largest rating change is 17.3 Elo. Fitting only the 437 matches under code `51b8366684f0` (leaving out 80 matches and the entrant gpt-5.6-terra) moves no remaining rating by more than 7.4 Elo.


#### cpa-tiers medium cross-model: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points.

| pair | wins/matches = observed share | fitted share | difference (pp) | 95% CI |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-5-5 | 6/20 = 30.0% | 25.9% | +4.1 | -10.4 to +18.5 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5 | 7/20 = 35.0% | 20.3% | +14.7 | -1.7 to +33.8 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5 | 2/20 = 10.0% | 27.1% | -17.1 | -31.9 to -3.7 |
| claude-haiku-4-5-20251001 vs deepseek-v4.1-flash | 1/3 = 33.3% | 32.3% | +1.1 | -42.7 to +66.8 |
| claude-haiku-4-5-20251001 vs gpt-6-astra | 2/17 = 11.8% | 15.2% | -3.4 | -16.0 to +10.0 |
| claude-haiku-4-5-20251001 vs gpt-6-luna | 12/20 = 60.0% | 65.4% | -5.4 | -27.7 to +15.5 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol | 6/20 = 30.0% | 24.0% | +6.0 | -11.6 to +26.2 |
| claude-haiku-5-5 vs claude-opus-5-5 | 7/20 = 35.0% | 42.2% | -7.2 | -22.7 to +5.4 |
| claude-haiku-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 51.5% | +8.5 | -7.9 to +26.6 |
| claude-haiku-5-5 vs deepseek-v4.1-flash | 3/8 = 37.5% | 57.7% | -20.2 | -49.5 to +0.4 |
| claude-haiku-5-5 vs gpt-5.6-terra | 13/20 = 65.0% | 63.3% | +1.7 | -12.7 to +16.6 |
| claude-haiku-5-5 vs gpt-6-astra | 6/20 = 30.0% | 33.9% | -3.9 | -18.0 to +9.8 |
| claude-haiku-5-5 vs gpt-6-luna | 19/20 = 95.0% | 84.4% | +10.6 | +0.0 to +20.4 |
| claude-haiku-5-5 vs gpt-6.1-sol | 10/20 = 50.0% | 47.5% | +2.5 | -11.7 to +16.7 |
| claude-opus-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 59.3% | +0.7 | -16.5 to +17.5 |
| claude-opus-5-5 vs deepseek-v4.1-flash | 4/4 = 100.0% | 65.2% | +34.8 | +16.2 to +55.0 |
| claude-opus-5-5 vs gpt-6-astra | 9/20 = 45.0% | 41.3% | +3.7 | -7.6 to +14.7 |
| claude-opus-5-5 vs gpt-6-luna | 16/20 = 80.0% | 88.1% | -8.1 | -27.9 to +8.6 |
| claude-opus-5-5 vs gpt-6.1-sol | 12/20 = 60.0% | 55.3% | +4.7 | -13.4 to +21.9 |
| claude-sonnet-5-5 vs deepseek-v4.1-flash | 3/5 = 60.0% | 56.2% | +3.8 | -56.7 to +43.6 |
| claude-sonnet-5-5 vs gpt-5.6-terra | 11/20 = 55.0% | 61.8% | -6.8 | -29.3 to +13.1 |
| claude-sonnet-5-5 vs gpt-6-astra | 7/20 = 35.0% | 32.5% | +2.5 | -11.6 to +15.9 |
| claude-sonnet-5-5 vs gpt-6-luna | 17/20 = 85.0% | 83.5% | +1.5 | -13.4 to +15.3 |
| claude-sonnet-5-5 vs gpt-6.1-sol | 8/20 = 40.0% | 45.9% | -5.9 | -22.8 to +12.2 |
| gpt-5.6-terra vs gpt-6-luna | 15/20 = 75.0% | 75.8% | -0.8 | -18.8 to +16.3 |
| gpt-5.6-terra vs gpt-6.1-sol | 6/20 = 30.0% | 34.4% | -4.4 | -19.0 to +10.0 |
| gpt-6-astra vs gpt-6-luna | 19/20 = 95.0% | 91.3% | +3.7 | -8.4 to +11.1 |
| gpt-6-astra vs gpt-6.1-sol | 12/20 = 60.0% | 63.8% | -3.8 | -21.1 to +12.4 |
| gpt-6-luna vs gpt-6.1-sol | 3/20 = 15.0% | 14.3% | +0.7 | -12.9 to +15.0 |
#### cpa-tiers sweep claude-haiku-4-5-20251001: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 | 47/80 = 58.8% | +51 | +0 to +108 | +4 to +106 |
| claude-haiku-4-5-20251001-minimal | 46/80 = 57.5% | +44 | -20 to +118 | +0 to +95 |
| claude-haiku-4-5-20251001-high | 43/80 = 53.8% | +22 | -41 to +85 | -65 to +111 |
| claude-haiku-4-5-20251001-low | 41/80 = 51.2% | +8 | -49 to +66 | -36 to +53 |
| claude-haiku-4-5-20251001-off | 23/80 = 28.7% | -126 | -201 to -63 | -205 to -57 |

With a seat term and a round 1 starter term in the fit (position 1 +19 Elo, the starter +57 Elo) the largest rating change is 3.5 Elo. Fitting only the 188 matches under code `9e7d7ff22891` (leaving out 12 matches) moves no remaining rating by more than 11.4 Elo.


#### cpa-tiers sweep claude-haiku-4-5-20251001: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points.

| pair | wins/matches = observed share | fitted share | difference (pp) | 95% CI |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-high | 9/20 = 45.0% | 54.1% | -9.1 | -25.0 to +5.0 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-low | 12/20 = 60.0% | 56.2% | +3.8 | -12.0 to +19.8 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-minimal | 10/20 = 50.0% | 51.0% | -1.0 | -18.6 to +16.1 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 73.5% | +6.5 | -7.4 to +21.7 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-low | 8/20 = 40.0% | 52.1% | -12.1 | -29.0 to +3.3 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal | 11/20 = 55.0% | 46.9% | +8.1 | -9.1 to +27.9 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 70.1% | -5.1 | -21.5 to +11.1 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-minimal | 6/20 = 30.0% | 44.9% | -14.9 | -32.9 to +2.7 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-off | 15/20 = 75.0% | 68.4% | +6.6 | -7.8 to +21.7 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 72.7% | -7.7 | -27.0 to +11.0 |
#### cpa-tiers sweep claude-haiku-5-5: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| claude-haiku-5-5-xhigh | 65/100 = 65.0% | +92 | +41 to +148 | +49 to +134 |
| claude-haiku-5-5-max | 60/100 = 60.0% | +61 | +9 to +117 | -12 to +142 |
| claude-haiku-5-5-high | 54/100 = 54.0% | +24 | -24 to +73 | +0 to +48 |
| claude-haiku-5-5 | 45/100 = 45.0% | -30 | -80 to +18 | -80 to +13 |
| claude-haiku-5-5-low | 45/100 = 45.0% | -30 | -81 to +22 | -67 to +0 |
| claude-haiku-5-5-off | 31/100 = 31.0% | -117 | -179 to -64 | -171 to -78 |

With a seat term and a round 1 starter term in the fit (position 1 -22 Elo, the starter +94 Elo) the largest rating change is 8.5 Elo. Fitting only the 280 matches under code `9e7d7ff22891` (leaving out 20 matches) moves no remaining rating by more than 10.0 Elo.


#### cpa-tiers sweep claude-haiku-5-5: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points.

| pair | wins/matches = observed share | fitted share | difference (pp) | 95% CI |
|---|---|---|---|---|
| claude-haiku-5-5 vs claude-haiku-5-5-high | 7/20 = 35.0% | 42.3% | -7.3 | -22.7 to +5.5 |
| claude-haiku-5-5 vs claude-haiku-5-5-low | 8/20 = 40.0% | 50.0% | -10.0 | -27.5 to +5.9 |
| claude-haiku-5-5 vs claude-haiku-5-5-max | 9/20 = 45.0% | 37.3% | +7.7 | -7.6 to +23.3 |
| claude-haiku-5-5 vs claude-haiku-5-5-off | 14/20 = 70.0% | 62.4% | +7.6 | -5.5 to +22.4 |
| claude-haiku-5-5 vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 33.2% | +1.8 | -15.8 to +20.0 |
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 57.7% | +7.3 | -10.8 to +25.3 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 44.8% | +0.2 | -18.1 to +18.6 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 69.3% | -4.3 | -17.6 to +9.2 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 40.4% | -10.4 | -25.6 to +3.3 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 37.3% | -2.3 | -20.1 to +16.1 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 62.4% | -7.4 | -26.5 to +10.2 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 33.2% | +6.8 | -7.4 to +20.1 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 73.6% | +6.4 | -8.6 to +21.4 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 45.5% | -0.5 | -14.9 to +15.2 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 23.1% | +1.9 | -14.4 to +21.1 |
#### cpa-tiers sweep claude-sonnet-5-5: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| claude-sonnet-5-5-max | 68/100 = 68.0% | +111 | +50 to +182 | +30 to +220 |
| claude-sonnet-5-5-xhigh | 58/100 = 58.0% | +48 | -7 to +105 | -16 to +119 |
| claude-sonnet-5-5-high | 51/100 = 51.0% | +6 | -55 to +71 | -46 to +55 |
| claude-sonnet-5-5 | 45/100 = 45.0% | -30 | -86 to +28 | -108 to +47 |
| claude-sonnet-5-5-off | 43/100 = 43.0% | -42 | -101 to +14 | -85 to +0 |
| claude-sonnet-5-5-low | 35/100 = 35.0% | -92 | -155 to -33 | -146 to -43 |

With a seat term and a round 1 starter term in the fit (position 1 +30 Elo, the starter +35 Elo) the largest rating change is 1.9 Elo. Fitting only the 295 matches under code `9e7d7ff22891` (leaving out 5 matches) moves no remaining rating by more than 5.9 Elo.


#### cpa-tiers sweep claude-sonnet-5-5: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points.

| pair | wins/matches = observed share | fitted share | difference (pp) | 95% CI |
|---|---|---|---|---|
| claude-sonnet-5-5 vs claude-sonnet-5-5-high | 7/20 = 35.0% | 44.9% | -9.9 | -28.8 to +8.0 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-low | 11/20 = 55.0% | 58.8% | -3.8 | -23.2 to +15.2 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-max | 8/20 = 40.0% | 30.8% | +9.2 | -7.7 to +27.0 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-off | 10/20 = 50.0% | 51.7% | -1.7 | -20.2 to +15.6 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 39.0% | +6.0 | -12.8 to +25.2 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 63.6% | -8.6 | -31.6 to +12.5 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 35.4% | +4.6 | -14.9 to +26.1 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 56.9% | +13.1 | -1.7 to +30.6 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 44.0% | -19.0 | -37.7 to -1.1 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 23.8% | -8.8 | -24.1 to +5.5 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 42.9% | +7.1 | -10.1 to +25.1 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 31.0% | -11.0 | -27.6 to +3.5 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 70.7% | -0.7 | -22.3 to +19.6 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 58.9% | +6.1 | -11.7 to +24.7 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 37.3% | +17.7 | +6.1 to +31.1 |
#### cpa-tiers sweep gpt-5.6-terra: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| gpt-5.6-terra-xhigh | 48/80 = 60.0% | +57 | +3 to +117 | +0 to +104 |
| gpt-5.6-terra-max | 47/80 = 58.8% | +50 | -14 to +116 | -1 to +104 |
| gpt-5.6-terra-high | 37/80 = 46.2% | -21 | -79 to +41 | -65 to +22 |
| gpt-5.6-terra | 36/80 = 45.0% | -28 | -82 to +22 | -80 to +21 |
| gpt-5.6-terra-low | 32/80 = 40.0% | -57 | -121 to +1 | -121 to +7 |

With a seat term and a round 1 starter term in the fit (position 1 -15 Elo, the starter +29 Elo) the largest rating change is 0.5 Elo.


#### cpa-tiers sweep gpt-5.6-terra: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points.

| pair | wins/matches = observed share | fitted share | difference (pp) | 95% CI |
|---|---|---|---|---|
| gpt-5.6-terra vs gpt-5.6-terra-high | 10/20 = 50.0% | 49.0% | +1.0 | -12.8 to +13.7 |
| gpt-5.6-terra vs gpt-5.6-terra-low | 11/20 = 55.0% | 54.1% | +0.9 | -15.1 to +16.0 |
| gpt-5.6-terra vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.0% | +1.0 | -16.6 to +19.4 |
| gpt-5.6-terra vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 38.0% | -3.0 | -16.7 to +10.5 |
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 55.1% | -10.1 | -29.1 to +6.4 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 40.0% | +0.0 | -16.8 to +17.3 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 39.0% | +11.0 | -7.4 to +31.4 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 35.2% | +4.8 | -15.3 to +25.3 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 34.2% | -14.2 | -29.4 to -0.2 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 49.0% | +6.0 | -10.0 to +21.3 |
#### cpa-tiers sweep gpt-6-luna: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| gpt-6-luna-max | 72/100 = 72.0% | +152 | +90 to +223 | +113 to +207 |
| gpt-6-luna-xhigh | 72/100 = 72.0% | +152 | +94 to +222 | +111 to +201 |
| gpt-6-luna-high | 62/100 = 62.0% | +81 | +12 to +153 | +12 to +159 |
| gpt-6-luna | 39/100 = 39.0% | -74 | -149 to -6 | -161 to -5 |
| gpt-6-luna-off | 28/100 = 28.0% | -152 | -222 to -95 | -229 to -91 |
| gpt-6-luna-low | 27/100 = 27.0% | -159 | -239 to -90 | -196 to -137 |

With a seat term and a round 1 starter term in the fit (position 1 +31 Elo, the starter +6 Elo) the largest rating change is 1.1 Elo.


#### cpa-tiers sweep gpt-6-luna: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points.

| pair | wins/matches = observed share | fitted share | difference (pp) | 95% CI |
|---|---|---|---|---|
| gpt-6-luna vs gpt-6-luna-high | 8/20 = 40.0% | 29.2% | +10.8 | -8.9 to +32.0 |
| gpt-6-luna vs gpt-6-luna-low | 12/20 = 60.0% | 62.1% | -2.1 | -24.7 to +18.4 |
| gpt-6-luna vs gpt-6-luna-max | 5/20 = 25.0% | 21.5% | +3.5 | -11.0 to +18.2 |
| gpt-6-luna vs gpt-6-luna-off | 12/20 = 60.0% | 61.1% | -1.1 | -18.5 to +18.7 |
| gpt-6-luna vs gpt-6-luna-xhigh | 2/20 = 10.0% | 21.5% | -11.5 | -24.0 to +1.5 |
| gpt-6-luna-high vs gpt-6-luna-low | 14/20 = 70.0% | 79.9% | -9.9 | -25.4 to +5.1 |
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 39.9% | -4.9 | -24.7 to +15.1 |
| gpt-6-luna-high vs gpt-6-luna-off | 18/20 = 90.0% | 79.2% | +10.8 | -2.4 to +24.1 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 39.9% | +15.1 | -2.3 to +33.7 |
| gpt-6-luna-low vs gpt-6-luna-max | 2/20 = 10.0% | 14.3% | -4.3 | -16.2 to +8.6 |
| gpt-6-luna-low vs gpt-6-luna-off | 8/20 = 40.0% | 48.9% | -8.9 | -26.3 to +7.0 |
| gpt-6-luna-low vs gpt-6-luna-xhigh | 3/20 = 15.0% | 14.3% | +0.7 | -13.9 to +19.7 |
| gpt-6-luna-max vs gpt-6-luna-off | 16/20 = 80.0% | 85.2% | -5.2 | -20.1 to +9.3 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 50.0% | +0.0 | -14.7 to +15.3 |
| gpt-6-luna-off vs gpt-6-luna-xhigh | 2/20 = 10.0% | 14.8% | -4.8 | -16.8 to +8.3 |
#### cpa-tiers sweep gpt-6.1-sol: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| gpt-6.1-sol-max | 47/80 = 58.8% | +49 | -7 to +109 | -14 to +117 |
| gpt-6.1-sol-low | 39/80 = 48.8% | -7 | -68 to +51 | -59 to +49 |
| gpt-6.1-sol-xhigh | 39/80 = 48.8% | -7 | -65 to +49 | -57 to +36 |
| gpt-6.1-sol-high | 38/80 = 47.5% | -14 | -69 to +39 | -57 to +28 |
| gpt-6.1-sol | 37/80 = 46.2% | -21 | -77 to +38 | -79 to +28 |

With a seat term and a round 1 starter term in the fit (position 1 +39 Elo, the starter +25 Elo) the largest rating change is 0.9 Elo.


#### cpa-tiers sweep gpt-6.1-sol: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points.

| pair | wins/matches = observed share | fitted share | difference (pp) | 95% CI |
|---|---|---|---|---|
| gpt-6.1-sol vs gpt-6.1-sol-high | 12/20 = 60.0% | 49.0% | +11.0 | -1.8 to +25.9 |
| gpt-6.1-sol vs gpt-6.1-sol-low | 7/20 = 35.0% | 48.0% | -13.0 | -30.8 to +4.3 |
| gpt-6.1-sol vs gpt-6.1-sol-max | 8/20 = 40.0% | 40.1% | -0.1 | -16.0 to +16.0 |
| gpt-6.1-sol vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 48.0% | +2.0 | -16.1 to +22.2 |
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 49.0% | +11.0 | -4.9 to +27.0 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 41.0% | +4.0 | -12.5 to +22.5 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 49.0% | -4.0 | -18.8 to +10.7 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 42.0% | -12.0 | -30.1 to +4.6 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 50.0% | +10.0 | -5.3 to +27.3 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 58.0% | -8.0 | -22.9 to +6.1 |
#### opus-effort: ratings

| entrant | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|---|
| claude-opus-5-5-xhigh | 26/40 = 65.0% | +109 | +40 to +191 | +26 to +204 |
| claude-opus-5-5-high | 18/40 = 45.0% | +14 | -77 to +101 | -53 to +73 |
| claude-opus-5-5 | 29/60 = 48.3% | -9 | -71 to +52 | -69 to +65 |
| claude-opus-5-5-low | 7/20 = 35.0% | -114 | -221 to -29 | -195 to -60 |

With a seat term and a round 1 starter term in the fit (position 1 +19 Elo, the starter +57 Elo) the largest rating change is 3.2 Elo.


#### opus-effort: observed pairs against the fitted ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points.

| pair | wins/matches = observed share | fitted share | difference (pp) | 95% CI |
|---|---|---|---|---|
| claude-opus-5-5 vs claude-opus-5-5-high | 9/20 = 45.0% | 46.7% | -1.7 | -13.9 to +10.2 |
| claude-opus-5-5 vs claude-opus-5-5-low | 13/20 = 65.0% | 64.6% | +0.4 | +0.1 to +1.0 |
| claude-opus-5-5 vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 33.7% | +1.3 | -10.1 to +13.2 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 36.7% | -1.7 | -14.0 to +10.8 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| cpa-tiers medium cross-model | 0.5965 | 0.5968 | -0.0003 | -0.0007 to +0.0001 | 0: 42, 0.1: 4, 0.2: 3, 0.4: 1 | tau=0.1: 0.5967, tau=0.2: 0.5975, tau=0.4: 0.6005, tau=0.8: 0.6081, tau=1.6: 0.6176 | not kept |
| cpa-tiers medium cross-model (seat and starter terms) | 0.5686 | 0.5693 | -0.0007 | -0.0013 to -0.0002 | 0: 42, 0.1: 2, 0.2: 5, 0.4: 1 | tau=0.1: 0.5688, tau=0.2: 0.5693, tau=0.4: 0.5718, tau=0.8: 0.5785, tau=1.6: 0.5874 | not kept |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 0.6763 | 0.6795 | -0.0033 | -0.0085 to +0.0019 | 0: 22, 0.1: 3, 0.2: 12, 0.4: 11, 0.8: 2 | tau=0.1: 0.6761, tau=0.2: 0.6758, tau=0.4: 0.6770, tau=0.8: 0.6824, tau=1.6: 0.6881 | not kept |
| cpa-tiers sweep claude-haiku-4-5-20251001 (seat and starter terms) | 0.6732 | 0.6787 | -0.0055 | -0.0117 to -0.0003 | 0: 20, 0.1: 4, 0.2: 12, 0.4: 13, 0.8: 1 | tau=0.1: 0.6733, tau=0.2: 0.6738, tau=0.4: 0.6772, tau=0.8: 0.6863, tau=1.6: 0.6948 | not kept |
| cpa-tiers sweep claude-haiku-5-5 | 0.6630 | 0.6636 | -0.0006 | -0.0013 to -0.0000 | 0: 43, 0.1: 2, 0.2: 4, 0.4: 1 | tau=0.1: 0.6635, tau=0.2: 0.6649, tau=0.4: 0.6699, tau=0.8: 0.6793, tau=1.6: 0.6867 | not kept |
| cpa-tiers sweep claude-haiku-5-5 (seat and starter terms) | 0.6415 | 0.6418 | -0.0003 | -0.0007 to -0.0000 | 0: 44, 0.2: 6 | tau=0.1: 0.6420, tau=0.2: 0.6433, tau=0.4: 0.6480, tau=0.8: 0.6574, tau=1.6: 0.6652 | not kept |
| cpa-tiers sweep claude-sonnet-5-5 | 0.6724 | 0.6741 | -0.0016 | -0.0084 to +0.0042 | 0: 11, 0.1: 2, 0.2: 13, 0.4: 24 | tau=0.1: 0.6719, tau=0.2: 0.6710, tau=0.4: 0.6708, tau=0.8: 0.6759, tau=1.6: 0.6825 | not kept |
| cpa-tiers sweep claude-sonnet-5-5 (seat and starter terms) | 0.6672 | 0.6709 | -0.0037 | -0.0101 to +0.0024 | 0: 11, 0.2: 13, 0.4: 26 | tau=0.1: 0.6669, tau=0.2: 0.6666, tau=0.4: 0.6682, tau=0.8: 0.6759, tau=1.6: 0.6844 | not kept |
| cpa-tiers sweep gpt-5.6-terra | 0.6937 | 0.6947 | -0.0011 | -0.0024 to +0.0001 | 0: 38, 0.1: 7, 0.2: 3, 0.4: 2 | tau=0.1: 0.6939, tau=0.2: 0.6945, tau=0.4: 0.6972, tau=0.8: 0.7036, tau=1.6: 0.7091 | not kept |
| cpa-tiers sweep gpt-5.6-terra (seat and starter terms) | 0.7004 | 0.7030 | -0.0026 | -0.0047 to -0.0007 | 0: 37, 0.1: 1, 0.2: 9, 0.4: 3 | tau=0.1: 0.7007, tau=0.2: 0.7017, tau=0.4: 0.7058, tau=0.8: 0.7144, tau=1.6: 0.7221 | not kept |
| cpa-tiers sweep gpt-6-luna | 0.5746 | 0.5788 | -0.0042 | -0.0078 to -0.0008 | 0: 29, 0.1: 5, 0.2: 7, 0.4: 8, 0.8: 1 | tau=0.1: 0.5747, tau=0.2: 0.5751, tau=0.4: 0.5777, tau=0.8: 0.5863, tau=1.6: 0.5974 | not kept |
| cpa-tiers sweep gpt-6-luna (seat and starter terms) | 0.5788 | 0.5801 | -0.0013 | -0.0030 to +0.0002 | 0: 31, 0.1: 6, 0.2: 9, 0.4: 4 | tau=0.1: 0.5789, tau=0.2: 0.5792, tau=0.4: 0.5815, tau=0.8: 0.5892, tau=1.6: 0.5993 | not kept |
| cpa-tiers sweep gpt-6.1-sol | 0.7052 | 0.7097 | -0.0045 | -0.0103 to +0.0005 | 0: 21, 0.1: 3, 0.2: 16, 0.4: 8, 0.8: 2 | tau=0.1: 0.7051, tau=0.2: 0.7049, tau=0.4: 0.7067, tau=0.8: 0.7132, tau=1.6: 0.7197 | not kept |
| cpa-tiers sweep gpt-6.1-sol (seat and starter terms) | 0.7121 | 0.7193 | -0.0072 | -0.0151 to -0.0000 | 0: 16, 0.1: 5, 0.2: 14, 0.4: 12, 0.8: 3 | tau=0.1: 0.7121, tau=0.2: 0.7123, tau=0.4: 0.7148, tau=0.8: 0.7222, tau=1.6: 0.7292 | not kept |
| opus-effort | 0.6886 | 0.6911 | -0.0025 | -0.0057 to -0.0002 | 0: 46, 0.4: 2, 0.8: 1, 1.6: 1 | tau=0.1: 0.6890, tau=0.2: 0.6900, tau=0.4: 0.6927, tau=0.8: 0.6964, tau=1.6: 0.6987 | not kept |
| opus-effort (seat and starter terms) | 0.7059 | 0.7090 | -0.0032 | -0.0081 to +0.0001 | 0: 46, 0.8: 4 | tau=0.1: 0.7063, tau=0.2: 0.7074, tau=0.4: 0.7104, tau=0.8: 0.7146, tau=1.6: 0.7173 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first.

| cohort | pairs with opposite signs | sign-test p | correlation of A-first effect with minus B-first effect |
|---|---|---|---|
| cpa-tiers medium cross-model | 11/29 = 37.9% | 0.26 | +0.05 |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 7/10 = 70.0% | 0.34 | +0.05 |
| cpa-tiers sweep claude-haiku-5-5 | 5/15 = 33.3% | 0.30 | -0.44 |
| cpa-tiers sweep claude-sonnet-5-5 | 6/15 = 40.0% | 0.61 | -0.04 |
| cpa-tiers sweep gpt-5.6-terra | 4/10 = 40.0% | 0.75 | -0.15 |
| cpa-tiers sweep gpt-6-luna | 7/15 = 46.7% | 1.00 | -0.09 |
| cpa-tiers sweep gpt-6.1-sol | 6/10 = 60.0% | 0.75 | -0.18 |
| opus-effort | 0/4 = 0.0% | 0.12 | -0.99 |
| all cohorts pooled | 46/108 = 42.6% | 0.15 | -0.10 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 4.4e-17, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 2138 of 2138 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|
| all cohorts: 1065 blocks (8 matches in half blocks left out) | 1078/2130 = 50.6% | 48.5% to 52.7% | 42.9% to 58.3% |
| cpa-tiers medium cross-model: 255 blocks (7 matches in half blocks left out) | 236/510 = 46.3% | 42.2% to 50.6% | 37.6% to 56.5% |
| cpa-tiers sweep claude-haiku-4-5-20251001: 100 blocks | 105/200 = 52.5% | 45.0% to 59.5% | 42.5% to 60.0% |
| cpa-tiers sweep claude-haiku-5-5: 150 blocks | 142/300 = 47.3% | 41.3% to 53.3% | 34.7% to 59.7% |
| cpa-tiers sweep claude-sonnet-5-5: 150 blocks | 162/300 = 54.0% | 48.7% to 59.3% | 42.3% to 64.7% |
| cpa-tiers sweep gpt-5.6-terra: 100 blocks | 96/200 = 48.0% | 40.5% to 55.5% | 36.5% to 59.0% |
| cpa-tiers sweep gpt-6-luna: 150 blocks | 160/300 = 53.3% | 48.7% to 58.0% | 47.3% to 59.0% |
| cpa-tiers sweep gpt-6.1-sol: 100 blocks | 111/200 = 55.5% | 48.0% to 62.5% | 43.5% to 68.0% |
| opus-effort: 40 blocks | 42/80 = 52.5% | 40.0% to 65.0% | 35.0% to 72.5% |
| tournament 3: 20 blocks (1 matches in half blocks left out) | 24/40 = 60.0% | 45.0% to 75.0% | 45.0% to 75.0% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 1212/2130 = 56.9% | 54.7% to 59.0% | 50.4% to 63.9% | 508/1065 |
| cpa-tiers medium cross-model | 312/510 = 61.2% | 57.3% to 64.9% | 52.8% to 68.4% | 103/255 |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 115/200 = 57.5% | 50.5% to 64.0% | 50.0% to 65.5% | 50/100 |
| cpa-tiers sweep claude-haiku-5-5 | 186/300 = 62.0% | 56.3% to 68.0% | 52.0% to 72.3% | 75/150 |
| cpa-tiers sweep claude-sonnet-5-5 | 164/300 = 54.7% | 49.0% to 60.0% | 43.7% to 64.7% | 75/150 |
| cpa-tiers sweep gpt-5.6-terra | 108/200 = 54.0% | 47.0% to 61.5% | 42.5% to 64.0% | 50/100 |
| cpa-tiers sweep gpt-6-luna | 152/300 = 50.7% | 46.0% to 56.0% | 44.3% to 56.7% | 75/150 |
| cpa-tiers sweep gpt-6.1-sol | 107/200 = 53.5% | 46.0% to 61.0% | 40.0% to 66.0% | 50/100 |
| opus-effort | 46/80 = 57.5% | 45.0% to 70.0% | 40.0% to 75.0% | 20/40 |
| tournament 3 | 22/40 = 55.0% | 40.0% to 70.0% | 40.0% to 70.0% | 10/20 |

Position and starter effects with the other held equal, in percentage points:

| group | position effect | 95% CI, blocks | 95% CI, seeds (sensitivity) | starter effect | 95% CI, blocks | 95% CI, seeds (sensitivity) |
|---|---|---|---|---|---|---|
| all cohorts | +0.9 | -1.2 to +3.0 | -6.2 to +7.6 | +6.9 | +4.8 to +9.0 | +0.4 to +14.0 |
| cpa-tiers medium cross-model | -1.6 | -6.0 to +2.5 | -10.3 to +7.0 | +10.9 | +6.8 to +14.8 | +2.3 to +19.2 |
| cpa-tiers sweep claude-haiku-4-5-20251001 | +2.5 | -4.6 to +9.4 | -6.3 to +9.1 | +7.5 | +0.8 to +14.0 | +0.4 to +16.4 |
| cpa-tiers sweep claude-haiku-5-5 | -2.7 | -8.2 to +3.1 | -13.6 to +7.6 | +12.0 | +6.4 to +17.9 | +1.3 to +23.2 |
| cpa-tiers sweep claude-sonnet-5-5 | +4.0 | -1.5 to +9.2 | -7.9 to +15.0 | +4.7 | -0.9 to +10.0 | -6.3 to +14.8 |
| cpa-tiers sweep gpt-5.6-terra | -2.0 | -9.6 to +5.4 | -14.6 to +8.9 | +4.0 | -3.0 to +11.4 | -7.8 to +15.0 |
| cpa-tiers sweep gpt-6-luna | +3.3 | -1.4 to +8.0 | -3.3 to +9.6 | +0.7 | -3.9 to +5.8 | -5.4 to +7.0 |
| cpa-tiers sweep gpt-6.1-sol | +5.5 | -2.0 to +12.6 | -7.5 to +19.3 | +3.5 | -4.0 to +11.0 | -10.6 to +16.4 |
| opus-effort | +2.5 | -9.5 to +15.0 | -15.7 to +22.5 | +7.5 | -4.8 to +19.8 | -12.5 to +25.9 |
| tournament 3 | +10.0 | -4.7 to +24.7 | -5.0 to +25.0 | +5.0 | -10.0 to +20.2 | -10.1 to +20.0 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits.

Position 1:

| group | position 1 wins/matches = share | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|
| claude-haiku-4-5-20251001: 157 blocks | 159/314 = 50.6% | 45.2% to 55.7% | 42.0% to 58.2% |
| claude-haiku-5-5: 224 blocks | 210/448 = 46.9% | 42.0% to 52.0% | 35.8% to 57.5% |
| claude-opus-5-5: 122 blocks | 119/244 = 48.8% | 42.2% to 55.3% | 37.8% to 60.9% |
| claude-sonnet-5-5: 222 blocks | 232/444 = 52.3% | 47.7% to 56.8% | 43.7% to 60.9% |
| gpt-5.6-terra: 140 blocks | 139/280 = 49.6% | 43.9% to 55.7% | 38.6% to 60.4% |
| gpt-6-astra: 77 blocks | 72/154 = 46.8% | 39.0% to 55.2% | 34.9% to 60.2% |
| gpt-6-luna: 220 blocks | 227/440 = 51.6% | 47.7% to 55.5% | 47.0% to 56.2% |
| gpt-6.1-sol: 170 blocks | 176/340 = 51.8% | 45.9% to 57.4% | 41.6% to 62.6% |
| oc/deepseek-v4.1-flash-free: 8 blocks | 4/16 = 25.0% | 6.2% to 43.8% | 12.5% to 37.5% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) | blocks where position 1 starts |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 | 185/314 = 58.9% | 53.8% to 64.0% | 52.6% to 65.4% | 73/157 |
| claude-haiku-5-5 | 272/448 = 60.7% | 55.6% to 65.4% | 50.7% to 69.4% | 104/224 |
| claude-opus-5-5 | 147/244 = 60.2% | 53.7% to 66.8% | 50.0% to 69.8% | 54/122 |
| claude-sonnet-5-5 | 250/444 = 56.3% | 52.0% to 60.6% | 47.8% to 64.1% | 104/222 |
| gpt-5.6-terra | 157/280 = 56.1% | 50.0% to 62.1% | 46.1% to 66.1% | 70/140 |
| gpt-6-astra | 96/154 = 62.3% | 54.5% to 69.5% | 51.5% to 71.7% | 33/77 |
| gpt-6-luna | 229/440 = 52.0% | 48.2% to 55.7% | 47.3% to 56.8% | 104/220 |
| gpt-6.1-sol | 198/340 = 58.2% | 52.9% to 63.8% | 48.4% to 67.3% | 79/170 |
| oc/deepseek-v4.1-flash-free | 12/16 = 75.0% | 56.2% to 93.8% | 62.5% to 87.5% | 0/8 |

Position and starter effects with the other held equal, in percentage points:

| group | position effect | 95% CI, blocks | 95% CI, seeds (sensitivity) | starter effect | 95% CI, blocks | 95% CI, seeds (sensitivity) |
|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 | +1.3 | -3.8 to +6.3 | -5.3 to +7.4 | +9.0 | +3.9 to +14.2 | +2.8 to +15.4 |
| claude-haiku-5-5 | -2.4 | -7.1 to +2.5 | -11.9 to +6.7 | +10.5 | +5.3 to +15.4 | +0.1 to +19.3 |
| claude-opus-5-5 | -0.1 | -6.6 to +6.4 | -10.9 to +10.8 | +10.2 | +3.5 to +17.1 | -0.6 to +20.2 |
| claude-sonnet-5-5 | +2.7 | -1.9 to +7.1 | -5.5 to +10.7 | +6.5 | +2.1 to +10.9 | -2.3 to +14.4 |
| gpt-5.6-terra | -0.4 | -6.1 to +5.5 | -11.6 to +9.5 | +6.1 | -0.3 to +12.2 | -4.7 to +16.8 |
| gpt-6-astra | -1.5 | -9.3 to +6.5 | -12.1 to +10.3 | +12.1 | +3.8 to +19.7 | +0.7 to +22.1 |
| gpt-6-luna | +1.7 | -2.1 to +5.6 | -3.1 to +6.4 | +2.1 | -1.7 to +5.7 | -2.6 to +7.0 |
| gpt-6.1-sol | +2.4 | -3.3 to +7.9 | -7.2 to +12.2 | +8.4 | +3.2 to +14.1 | -1.6 to +17.6 |

#### Per code hash, all cohorts

Position 1:

| group | position 1 wins/matches = share | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) |
|---|---|---|---|
| code `51b8366684f0`: 233 blocks | 202/466 = 43.3% | 39.1% to 47.6% | 34.1% to 56.0% |
| code `9e7d7ff22891`: 830 blocks | 873/1660 = 52.6% | 50.2% to 55.0% | 44.3% to 60.8% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) | blocks where position 1 starts |
|---|---|---|---|---|
| code `51b8366684f0` | 290/466 = 62.2% | 57.9% to 66.5% | 52.8% to 70.2% | 83/233 |
| code `9e7d7ff22891` | 921/1660 = 55.5% | 53.2% to 57.9% | 47.6% to 64.0% | 425/830 |

Position and starter effects with the other held equal, in percentage points:

| group | position effect | 95% CI, blocks | 95% CI, seeds (sensitivity) | starter effect | 95% CI, blocks | 95% CI, seeds (sensitivity) |
|---|---|---|---|---|---|---|
| code `51b8366684f0` | -3.4 | -8.1 to +0.9 | -14.0 to +7.5 | +11.2 | +6.7 to +15.7 | -0.0 to +21.4 |
| code `9e7d7ff22891` | +2.5 | +0.1 to +4.8 | -6.4 to +10.3 | +5.4 | +3.2 to +7.8 | -2.8 to +14.4 |
Codes with fewer than 10 complete blocks (`3c9b98f8b3f4` has 1, and 1 block mixes two codes) are left out.

#### Per seed, all cohorts

Cohorts reuse seeds 3000 to 3018 (tournament 3 adds 3020 to 3029), so a seed's starter result pools many pairings.

| seed | position that starts | complete blocks | starter wins/matches = share |
|---|---|---|---|
| 3000 | 2 | 108 | 158/216 = 73.1% |
| 3001 | 2 | 25 | 37/50 = 74.0% |
| 3002 | 2 | 23 | 22/46 = 47.8% |
| 3003 | 2 | 23 | 24/46 = 52.2% |
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
| the 19 seeds with 10 or more blocks, each once |  | 1055 | mean of seed shares 57.7% (95% CI 51.5% to 64.0%, seeds drawn) |

### Tournament 3

| scored matches | Opus xhigh wins/matches = share | 95% CI (seed blocks drawn, wins over matches) | mean of block shares (a block counts once) | 95% CI | Opus minus Astra, Elo (95% CI) | blocks Opus both / split / Astra both |
|---|---|---|---|---|---|---|
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 38.1% to 69.0% | 52.4% | 35.7% to 69.0% | +25 (-77 to +139) | 6 / 10 / 4 |
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
