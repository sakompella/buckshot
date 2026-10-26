# Matchup analysis

Ratings, pair effects, seat and round 1 starter effects for the scored arena matches, from the analysis database ([database.md](../database.md)). All scored matches are two-player. Every rate shows numerator/denominator, a win share counts a split by its share, and every interval is a 95% bootstrap that draws whole units, never single matches or seat swaps: seed blocks (the two seat-swapped matches of one pair and seed) for ratings, and seeds (every block played at a seed, in any pairing) for the headline seat and starter figures. The tables below the line "Tables" are generated: `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` rewrites them, with a fixed RNG seed, in about 6 minutes under `nice`. Nothing here reads provenance or account data.

**DeepSeek is left out.** Every match with deepseek-v4.1-flash (20 scored matches) is dropped from all cohorts, fits, seat and starter figures and tables, because its free tier refused requests, so its games are not a random sample of what was scheduled. That leaves 2,471 scored matches.

## Findings

**Ratings are pooled.** One Bradley-Terry fit covers every scored match of every tournament, so all 38 configs share one Elo scale with the mean at 0, as in the viewer. Tournament 4 gave every config games against other models, so no rating leans on an assumption that effort gaps carry across opponents. `results.md` and the viewer show the same ratings. A second fit on pot share (a config's cash over the match's cash, which credits the round prizes a loser banks) gives the cash rating. Cohorts, now only a way to group matches, are: tournament 1's cross-model games, each model's own effort sweep (six of them), tournament 2's Opus effort games, tournament 3 and tournament 4's cross-model samples.
- **Coverage.** The cross-model cohort has 9 configs and 562 matches over 29 of the 36 pairs. Eight are the medium configs; Sonnet max only has 2 games there (both lost to Opus). Every sweep is a full round robin with 20 matches per pair. Opus effort plays 4 of its 6 pairs. Tournament 4 has 288 matches in 144 seat-swapped blocks: 37 configs, each playing 5 others (10 matches) on seeds 3000 to 3009.
- **Cross-model medium configs**, win rating (95% CI by seed blocks): astra +174 (+129 to +226), opus +98 (+50 to +148), sol +84 (+41 to +130), sonnet +43 (+1 to +87), haiku 5.5 +42 (+5 to +82), terra -25 (-71 to +17), haiku 4.5 -138 (-190 to -88), luna -226 (-290 to -175). Astra stands above and luna and haiku 4.5 below; the five in between overlap. Drawing seeds instead of blocks moves the intervals modestly.
- **Top and bottom of all 38.** Opus xhigh +205 (+125 to +290), Sonnet max +191 (+110 to +283), astra +174 and Sol max +164 lead. Luna low -317, luna off -311 and haiku 4.5 off -302 trail. Effort configs have 30 to 110 matches each, so their intervals are about 150 to 200 Elo wide.
- **Effort.** Within each model the top level is xhigh or max in six of seven models with a sweep or effort tournament: luna xhigh +0 and max -18 against medium -226, sonnet max +191 against medium +43, haiku 5.5 xhigh +130, terra max +34, sol max +164, Opus xhigh +205. Haiku 4.5 has no such level; its top is minimal (-133) and medium (-138). Off or low is the bottom level in six of seven: luna low -317, haiku 4.5 off -302, haiku 5.5 off -72, sonnet low -14, terra low -59 and Opus low -1. Sol is the exception: medium +84 sits at the bottom of a flat range up to +164, and the intervals overlap. The order of neighbouring levels is mostly inside the intervals.
- **Cash.** Cash ratings spread about two thirds as far as win ratings (+128 to -205 against +205 to -317), because losers bank round prizes. Pot shares run from 31.4% (luna low) to 64.7% (luna xhigh). The two ratings agree on the leaders (Sonnet max +128, Opus xhigh +109, Sol max +108) and the trailers (luna low -205). A config can win less than it earns: Opus low wins 43.3% of its 30 matches yet takes 55.8% of the pot (cash +67, win -1), and terra high wins 44.4% and takes 49.6% (cash +13, win -42). Haiku 5.5 xhigh is the reverse: 62.7% of wins, 54.0% of the pot, cash +29 against win +130.

**Matchup effects: none worth keeping.** The observed pair share minus the share fitted by the pooled ratings is small and is reported as a descriptive residual. It is not a test: the ratings are regularized, so residuals are forced (a pair at the end of a chain of pairs is pulled to its fit), and the bootstrap range around a residual is not a calibrated interval around zero. The largest cross-model residual over a full 20-match pair is haiku 4.5 against sonnet (2/20 observed against 26% fitted); the pair of 2 Opus against Sonnet max games is too thin to read.
- The test is held-out prediction. Whole seed blocks were held out (5 repeats of 10-fold cross-validation, with the shrinkage chosen inside each training set from 0 to 1.6, so no held-out block picks it). In every tested cohort the nested pair-effect model scored no better than ratings alone: the gain per match is between -0.0067 and -0.0001 nats, and the lower end of its interval is never above 0. The shrinkage chose 0 (ratings only) in most folds for the cross-model cohort, haiku 5.5, terra and Opus. So **no cohort keeps pair effects**. Tournament 3 has one pair, and tournament 4 has one seat-swapped block per pair, so neither is tested.
- The same holds when the ratings also have a seat term and a round 1 starter term, which on their own lower the cross-model loss from 0.5954 to 0.5793 per match.
- Reverse pairs, described and not tested: for the entrant seated first, a real matchup effect should show the opposite sign when A sat first and when B sat first. 44 of 108 pairs (40.7%) do, with a correlation of -0.22 between the A-first effect and minus the B-first effect (a negative value means the two orders lean the same way). The signs are not independent (the two orders of a block share a seed, seeds are reused across pairings, and the ratings are fitted jointly), so no test is made. The two entrants' effects in a pair sum to zero to rounding (4e-17) because every match's shares sum to 1.
- With 20 matches per pair, only large pair effects could show.

**Seat and starter.** Whoever opens round 1 (read from the public line `Round 1 begins ... Player X starts.` of each match's events) also fired the first shot in 2471 of 2471 matches. The seed decides that position, and both matches of a block share it.
- **Position 1:** 1245/2470 = 50.4% over 1,235 complete blocks at 29 seeds (95% CI by seeds 43.1% to 57.6%; by seed blocks 48.5% to 52.4%). Cross-model 276/562 = 49.1% (41.2% to 58.7% by seeds). Tournament 3 24/40 = 60.0% (45.0% to 75.0%). Tournament 4 127/288 = 44.1% (33.3% to 54.5%).
- **Starter:** the player who opens round 1 won 1411/2470 = 57.1% (51.0% to 63.6% by seeds; 55.2% to 59.1% by seed blocks). The overall starter association stands: it is about 7 points above even.
- **Split:** the position and starter effects below are a descriptive additive split of block shares by which position starts. Every one of the 29 complete-block seeds has exactly one starter position, so a starter effect cannot be told from a seed effect. The split describes these seed blocks; only the seeds-drawn intervals reach beyond them. Starter +7.2 points overall (seeds +0.8 to +13.8; blocks +5.3 to +9.1), +9.5 cross-model (+1.4 to +17.8; blocks +5.6 to +13.5), +10.7 in tournament 4 (+2.5 to +18.8). Position +0.8 overall (-5.9 to +7.0 by seeds).
- **It depends on the seed.** The starter won 173/244 = 70.9% of matches at seed 3000 and 28/74 = 37.8% at seed 3005. Counting each of the 19 seeds with 10 or more blocks once, the starter's mean share is 57.7% (51.7% to 63.8%, seeds drawn). Starter figures are therefore not reported per model: a model's blocks cover a handful of seeds, so they say as much about those seeds as about the model. Position 1 per model is in the tables and sits near 50% for every model.
- **Recommendation:** a starter term is worth keeping as an option for future ratings. It lowers held-out loss a lot (cross-model 0.5954 to 0.5793 per match) and moves the pooled ratings by up to 7.4 Elo. The headline fits stay without it.

**Tournament 3 (Opus xhigh against Astra medium).**
- **41 matches** (21 seed blocks, seed 3030 half): Opus 22/41 = 53.7% (38.1% to 69.0%); Elo gap +25 (-81 to +132), in a fit of the two alone.
- **40 matches** (20 complete seed pairs): Opus 22/40 = 55.0% (40.0% to 70.0%); gap +35 (-70 to +146). Opus won both matches on 6 seeds, split on 10 and lost both on 4.
- **Matched with Opus medium against Astra** on seeds 3000 to 3009, which is the same for 40 and 41 matches: 10/20 against 9/20, +5.0 points (-15.1 to +25.0, seeds drawn).
- Inconclusive either way, as `results.md` says.

## Method
- **Ratings:** the first-seated entrant wins with probability 1/(1 + exp(-(theta_first - theta_second))), and a share w counts as w wins and 1 - w losses. One fit covers every scored match of every tournament. A mean-zero Gaussian prior on theta (standard deviation 3) regularizes the fit; it also shrinks rating differences slightly. Ratings are reported on the Elo scale with the mean of the configs at 0, which is what `web/src/arena-viewer/page/ratings.ts` computes. The win rating counts win shares; the cash rating is the same fit on pot shares. Intervals draw seed blocks 2,000 times, refitting each draw (the viewer draws 200, so its intervals differ by a few Elo).
- **Observed against fitted:** for each pair in a cohort, the observed share of the alphabetically first entrant minus the sum of its pooled-fit win probabilities over the pair's matches, as a share, with each resample refitted. Descriptive only (see above).
- **Pair effects:** a term delta per pair with a prior of standard deviation tau, tau in {0 (ratings only), 0.1, 0.2, 0.4, 0.8, 1.6}, fitted within a cohort. Scored by mean log loss on held-out blocks (5 repeats of 10-fold cross-validation); the nested row picks tau by 5-fold cross-validation inside each training set. The verdict needs the lower end of the 95% interval of the gain (drawn over blocks) above 0.
- **Seat and starter:** for a complete block, position 1's share is the mean over its two matches, which cancels who the entrants are. The starter's share is taken the same way. The two effects are the position and starter terms of an additive split of those block shares by which position starts, weighting the two starts equally. Headline intervals draw seeds.

## Limits
- **Shared seeds.** The seed block id includes the pairing, but every pairing of a tournament plays the same seeds (tournament 1's cross-model games use 10 seeds, each sweep 10, tournament 4 the same 10), so blocks of different pairings share deals. Seed-block intervals therefore understate the uncertainty of position and starter effects, which is why the seeds-drawn interval is the headline there (about 10 to 19 clusters, so it is rough). Rating intervals hardly change.
- **Unmatched blocks.** One half block (tournament 3's seed 3030, 1 match) cannot be matched and is left out of every seat figure.
- **Power.** The held-out test can rule out large pair effects only; "none kept" is not "none exist". Cohorts with 40 blocks (Opus effort) are the weakest, and a pair-effect model with 4 pairs is almost saturated.
- **Thin cells.** Tournament 4 has one seat-swapped block (2 matches) per pair, so one pair says little; its value is that it links every config to the others. Sonnet max's rating rests on its 8 tournament-4 matches and 2 tournament-1 games.
- **Position and starter overlap** because the seed fixes the starter's position, and tournament 1's seeds 3000 to 3009 start position 2 six times in ten.
- **No replays.** Everything comes from standings, cash, seating and the public round 1 line; no moves were reviewed.

## Tables

<!-- tables:start -->
### Schedule coverage

| cohort | entrants | scored matches | complete / half blocks | pairs played | matches per pair min / median / max | connected | scheduled by status |
|---|---|---|---|---|---|---|---|
| cpa-tiers cross-model | 9 | 562 | 281 / 0 | 29/36 | 2 / 20 / 20 | yes | 562 completed, 138 skipped (skipped) |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| cpa-tiers sweep claude-haiku-5-5 | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| cpa-tiers sweep claude-sonnet-5-5 | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| cpa-tiers sweep gpt-5.6-terra | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| cpa-tiers sweep gpt-6-luna | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| cpa-tiers sweep gpt-6.1-sol | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| opus-effort | 4 | 80 | 40 / 0 | 4/6 | 20 / 20 / 20 | yes | 80 completed |
| tournament 3 | 2 | 41 | 20 / 1 | 1/1 | 41 / 41 / 41 | yes | 41 completed, 5 partial (skipped), 14 unstarted |
| tournament 4 | 37 | 288 | 144 / 0 | 144/666 | 2 / 2 / 2 | yes | 288 completed |

Matches outside every cohort: 0.

### Pooled ratings

| config | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) | pot share | cash rating (Elo, mean 0) | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5-xhigh | 48/81 = 59.3% | +205 | +125 to +290 | +131 to +280 | 54.7% | +109 | +62 to +154 |
| claude-sonnet-5-5-max | 76/110 = 69.1% | +191 | +110 to +283 | +83 to +345 | 64.3% | +128 | +83 to +178 |
| gpt-6-astra | 149/219 = 68.0% | +174 | +129 to +226 | +129 to +223 | 61.3% | +96 | +71 to +123 |
| gpt-6.1-sol-max | 55/90 = 61.1% | +164 | +86 to +247 | +76 to +255 | 56.8% | +108 | +63 to +154 |
| claude-haiku-5-5-xhigh | 69/110 = 62.7% | +130 | +60 to +208 | +58 to +205 | 54.0% | +29 | -6 to +66 |
| claude-sonnet-5-5-xhigh | 63/110 = 57.3% | +121 | +51 to +203 | +44 to +207 | 52.9% | +63 | +25 to +102 |
| claude-haiku-5-5-max | 67/110 = 60.9% | +119 | +53 to +195 | +54 to +208 | 58.6% | +58 | +23 to +94 |
| claude-opus-5-5-high | 24/50 = 48.0% | +113 | +9 to +218 | +0 to +224 | 47.9% | +54 | +3 to +106 |
| gpt-6.1-sol-xhigh | 46/90 = 51.1% | +109 | +31 to +195 | +25 to +194 | 51.7% | +81 | +36 to +125 |
| gpt-6.1-sol-low | 45/90 = 50.0% | +102 | +19 to +184 | +27 to +176 | 49.9% | +70 | +21 to +113 |
| claude-opus-5-5 | 140/238 = 58.8% | +98 | +50 to +148 | +46 to +150 | 55.1% | +57 | +33 to +82 |
| gpt-6.1-sol-high | 44/90 = 48.9% | +89 | +16 to +166 | +9 to +163 | 48.7% | +59 | +15 to +103 |
| gpt-6.1-sol | 145/256 = 56.6% | +84 | +41 to +130 | +27 to +147 | 56.3% | +66 | +42 to +90 |
| claude-sonnet-5-5-high | 57/110 = 51.8% | +79 | -3 to +169 | +0 to +158 | 50.2% | +41 | -5 to +88 |
| claude-haiku-5-5-high | 58/110 = 52.7% | +67 | -4 to +143 | +9 to +121 | 52.4% | +20 | -18 to +59 |
| claude-sonnet-5-5-off | 50/110 = 45.5% | +46 | -24 to +119 | -25 to +118 | 46.0% | +19 | -21 to +60 |
| claude-sonnet-5-5 | 142/276 = 51.4% | +43 | +1 to +87 | +2 to +88 | 51.5% | +28 | +6 to +52 |
| claude-haiku-5-5 | 146/278 = 52.5% | +42 | +5 to +82 | +13 to +77 | 51.1% | +12 | -8 to +33 |
| claude-haiku-5-5-low | 53/110 = 48.2% | +41 | -37 to +114 | -21 to +113 | 48.9% | +0 | -42 to +42 |
| gpt-5.6-terra-max | 52/90 = 57.8% | +34 | -53 to +123 | -26 to +97 | 53.8% | +36 | -8 to +83 |
| gpt-5.6-terra-xhigh | 51/90 = 56.7% | +32 | -51 to +112 | -47 to +107 | 54.7% | +45 | +5 to +83 |
| gpt-6-luna-xhigh | 77/110 = 70.0% | +0 | -80 to +84 | -70 to +67 | 64.7% | +8 | -38 to +53 |
| claude-opus-5-5-low | 13/30 = 43.3% | -1 | -121 to +98 | -123 to +101 | 55.8% | +67 | -6 to +133 |
| claude-sonnet-5-5-low | 40/110 = 36.4% | -14 | -100 to +66 | -88 to +65 | 42.4% | -4 | -49 to +38 |
| gpt-6-luna-max | 74/110 = 67.3% | -18 | -102 to +67 | -95 to +56 | 63.2% | -1 | -48 to +46 |
| gpt-5.6-terra | 119/256 = 46.5% | -25 | -71 to +17 | -68 to +19 | 48.3% | -4 | -26 to +18 |
| gpt-5.6-terra-high | 40/90 = 44.4% | -42 | -120 to +35 | -108 to +12 | 49.6% | +13 | -25 to +53 |
| gpt-5.6-terra-low | 37/90 = 41.1% | -59 | -138 to +15 | -126 to +9 | 45.7% | -8 | -50 to +32 |
| claude-haiku-5-5-off | 34/110 = 30.9% | -72 | -152 to -3 | -138 to -8 | 35.7% | -82 | -122 to -44 |
| gpt-6-luna-high | 66/110 = 60.0% | -74 | -166 to +20 | -171 to +26 | 55.6% | -52 | -92 to -11 |
| claude-haiku-4-5-20251001-minimal | 50/90 = 55.6% | -133 | -223 to -54 | -203 to -64 | 50.0% | -106 | -155 to -62 |
| claude-haiku-4-5-20251001 | 98/256 = 38.3% | -138 | -190 to -88 | -193 to -95 | 41.7% | -89 | -116 to -61 |
| claude-haiku-4-5-20251001-low | 45/90 = 50.0% | -168 | -252 to -91 | -243 to -92 | 51.3% | -99 | -145 to -57 |
| claude-haiku-4-5-20251001-high | 43/90 = 47.8% | -181 | -269 to -94 | -292 to -83 | 49.4% | -109 | -154 to -64 |
| gpt-6-luna | 73/272 = 26.8% | -226 | -290 to -175 | -275 to -181 | 34.6% | -134 | -161 to -108 |
| claude-haiku-4-5-20251001-off | 25/90 = 27.8% | -302 | -404 to -217 | -404 to -204 | 36.3% | -184 | -230 to -138 |
| gpt-6-luna-off | 29/110 = 26.4% | -311 | -408 to -228 | -422 to -221 | 33.8% | -191 | -238 to -144 |
| gpt-6-luna-low | 28/110 = 25.5% | -317 | -428 to -227 | -387 to -261 | 31.4% | -205 | -257 to -157 |

With a seat term and a round 1 starter term in the fit (position 1 +6 Elo, the starter +58 Elo) the largest rating change is 7.4 Elo.


### Observed pairs against the pooled ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below. Every resample refits the pooled ratings.

#### cpa-tiers cross-model

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-5-5 | 6/20 = 30.0% | 26.1% | +3.9 | -11.7 to +19.2 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5 | 7/20 = 35.0% | 20.5% | +14.5 | -4.1 to +34.3 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5 | 2/20 = 10.0% | 26.1% | -16.1 | -29.0 to -1.4 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra | 6/20 = 30.0% | 34.3% | -4.3 | -20.7 to +10.9 |
| claude-haiku-4-5-20251001 vs gpt-6-astra | 3/20 = 15.0% | 14.2% | +0.8 | -13.3 to +17.1 |
| claude-haiku-4-5-20251001 vs gpt-6-luna | 12/20 = 60.0% | 62.5% | -2.5 | -28.8 to +20.1 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol | 6/20 = 30.0% | 21.8% | +8.2 | -11.4 to +29.0 |
| claude-haiku-5-5 vs claude-opus-5-5 | 7/20 = 35.0% | 42.1% | -7.1 | -22.8 to +6.8 |
| claude-haiku-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 49.9% | +10.1 | -8.0 to +28.5 |
| claude-haiku-5-5 vs gpt-5.6-terra | 13/20 = 65.0% | 59.6% | +5.4 | -8.9 to +20.5 |
| claude-haiku-5-5 vs gpt-6-astra | 6/20 = 30.0% | 31.9% | -1.9 | -16.7 to +12.9 |
| claude-haiku-5-5 vs gpt-6-luna | 19/20 = 95.0% | 82.5% | +12.5 | +1.9 to +21.5 |
| claude-haiku-5-5 vs gpt-6.1-sol | 10/20 = 50.0% | 44.0% | +6.0 | -7.8 to +20.0 |
| claude-opus-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 57.8% | +2.2 | -15.3 to +20.1 |
| claude-opus-5-5 vs claude-sonnet-5-5-max | 2/2 = 100.0% | 36.9% | +63.1 | +48.4 to +74.2 |
| claude-opus-5-5 vs gpt-5.6-terra | 12/20 = 60.0% | 67.0% | -7.0 | -19.8 to +7.4 |
| claude-opus-5-5 vs gpt-6-astra | 9/20 = 45.0% | 39.2% | +5.8 | -5.9 to +16.9 |
| claude-opus-5-5 vs gpt-6-luna | 16/20 = 80.0% | 86.6% | -6.6 | -28.1 to +11.2 |
| claude-opus-5-5 vs gpt-6.1-sol | 12/20 = 60.0% | 51.9% | +8.1 | -10.2 to +26.7 |
| claude-sonnet-5-5 vs gpt-5.6-terra | 11/20 = 55.0% | 59.7% | -4.7 | -29.6 to +20.4 |
| claude-sonnet-5-5 vs gpt-6-astra | 7/20 = 35.0% | 32.0% | +3.0 | -12.9 to +16.7 |
| claude-sonnet-5-5 vs gpt-6-luna | 17/20 = 85.0% | 82.5% | +2.5 | -11.9 to +16.3 |
| claude-sonnet-5-5 vs gpt-6.1-sol | 8/20 = 40.0% | 44.1% | -4.1 | -22.0 to +14.2 |
| gpt-5.6-terra vs gpt-6-astra | 5/20 = 25.0% | 24.1% | +0.9 | -15.3 to +16.1 |
| gpt-5.6-terra vs gpt-6-luna | 15/20 = 75.0% | 76.1% | -1.1 | -25.0 to +18.0 |
| gpt-5.6-terra vs gpt-6.1-sol | 6/20 = 30.0% | 34.8% | -4.8 | -20.2 to +10.5 |
| gpt-6-astra vs gpt-6-luna | 19/20 = 95.0% | 90.9% | +4.1 | -7.0 to +11.5 |
| gpt-6-astra vs gpt-6.1-sol | 12/20 = 60.0% | 62.6% | -2.6 | -21.0 to +14.6 |
| gpt-6-luna vs gpt-6.1-sol | 3/20 = 15.0% | 14.3% | +0.7 | -12.6 to +15.5 |
#### cpa-tiers sweep claude-haiku-4-5-20251001

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-high | 9/20 = 45.0% | 56.2% | -11.2 | -28.2 to +3.8 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-low | 12/20 = 60.0% | 54.4% | +5.6 | -12.0 to +22.4 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-minimal | 10/20 = 50.0% | 49.3% | +0.7 | -16.0 to +17.0 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 72.0% | +8.0 | -6.5 to +22.6 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-low | 8/20 = 40.0% | 48.2% | -8.2 | -25.1 to +7.7 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal | 11/20 = 55.0% | 43.1% | +11.9 | -7.4 to +32.3 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 66.8% | -1.8 | -19.1 to +16.7 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-minimal | 6/20 = 30.0% | 44.9% | -14.9 | -33.9 to +2.9 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-off | 15/20 = 75.0% | 68.3% | +6.7 | -8.1 to +22.5 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 72.6% | -7.6 | -28.5 to +11.4 |
#### cpa-tiers sweep claude-haiku-5-5

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-5-5 vs claude-haiku-5-5-high | 7/20 = 35.0% | 46.4% | -11.4 | -27.4 to +2.5 |
| claude-haiku-5-5 vs claude-haiku-5-5-low | 8/20 = 40.0% | 50.3% | -10.3 | -29.4 to +8.1 |
| claude-haiku-5-5 vs claude-haiku-5-5-max | 9/20 = 45.0% | 39.2% | +5.8 | -9.6 to +20.6 |
| claude-haiku-5-5 vs claude-haiku-5-5-off | 14/20 = 70.0% | 65.9% | +4.1 | -10.3 to +19.6 |
| claude-haiku-5-5 vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 37.7% | -2.7 | -18.7 to +16.7 |
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 53.8% | +11.2 | -6.3 to +27.7 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 42.7% | +2.3 | -15.0 to +21.5 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 69.1% | -4.1 | -18.6 to +10.6 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 41.1% | -11.1 | -26.8 to +2.6 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 39.0% | -4.0 | -22.0 to +14.2 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 65.7% | -10.7 | -30.1 to +7.4 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 37.5% | +2.5 | -11.1 to +16.4 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 75.0% | +5.0 | -9.9 to +20.0 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 48.4% | -3.4 | -19.3 to +12.2 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 23.8% | +1.2 | -16.7 to +21.0 |
#### cpa-tiers sweep claude-sonnet-5-5

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-sonnet-5-5 vs claude-sonnet-5-5-high | 7/20 = 35.0% | 44.8% | -9.8 | -29.1 to +8.7 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-low | 11/20 = 55.0% | 58.1% | -3.1 | -23.4 to +16.9 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-max | 8/20 = 40.0% | 29.9% | +10.1 | -6.6 to +28.8 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-off | 10/20 = 50.0% | 49.6% | +0.4 | -18.6 to +20.3 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 38.9% | +6.1 | -13.1 to +26.5 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 63.1% | -8.1 | -31.1 to +14.0 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 34.5% | +5.5 | -15.2 to +24.6 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 54.8% | +15.2 | -0.3 to +32.4 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 44.0% | -19.0 | -39.3 to +0.8 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 23.5% | -8.5 | -23.0 to +6.3 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 41.5% | +8.5 | -9.9 to +27.2 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 31.5% | -11.5 | -27.9 to +2.7 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 69.7% | +0.3 | -21.9 to +20.6 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 59.9% | +5.1 | -12.8 to +22.7 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 39.3% | +15.7 | +4.1 to +29.1 |
#### cpa-tiers sweep gpt-5.6-terra

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-5.6-terra vs gpt-5.6-terra-high | 10/20 = 50.0% | 52.4% | -2.4 | -16.7 to +11.6 |
| gpt-5.6-terra vs gpt-5.6-terra-low | 11/20 = 55.0% | 54.8% | +0.2 | -15.9 to +16.3 |
| gpt-5.6-terra vs gpt-5.6-terra-max | 8/20 = 40.0% | 41.6% | -1.6 | -21.7 to +18.0 |
| gpt-5.6-terra vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 41.8% | -6.8 | -23.4 to +7.7 |
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 52.4% | -7.4 | -25.5 to +9.6 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.3% | +0.7 | -15.7 to +17.2 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 39.5% | +10.5 | -9.6 to +30.0 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 37.0% | +3.0 | -15.8 to +23.3 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 37.2% | -17.2 | -33.2 to -3.0 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 50.2% | +4.8 | -11.1 to +22.6 |
#### cpa-tiers sweep gpt-6-luna

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-luna vs gpt-6-luna-high | 8/20 = 40.0% | 29.4% | +10.6 | -9.2 to +32.6 |
| gpt-6-luna vs gpt-6-luna-low | 12/20 = 60.0% | 62.7% | -2.7 | -25.6 to +19.3 |
| gpt-6-luna vs gpt-6-luna-max | 5/20 = 25.0% | 23.2% | +1.8 | -14.5 to +17.1 |
| gpt-6-luna vs gpt-6-luna-off | 12/20 = 60.0% | 62.0% | -2.0 | -21.7 to +17.7 |
| gpt-6-luna vs gpt-6-luna-xhigh | 2/20 = 10.0% | 21.4% | -11.4 | -24.0 to +1.3 |
| gpt-6-luna-high vs gpt-6-luna-low | 14/20 = 70.0% | 80.2% | -10.2 | -25.5 to +4.6 |
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 42.0% | -7.0 | -27.3 to +13.0 |
| gpt-6-luna-high vs gpt-6-luna-off | 18/20 = 90.0% | 79.7% | +10.3 | -3.5 to +23.2 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 39.5% | +15.5 | -1.2 to +36.2 |
| gpt-6-luna-low vs gpt-6-luna-max | 2/20 = 10.0% | 15.2% | -5.2 | -16.7 to +8.6 |
| gpt-6-luna-low vs gpt-6-luna-off | 8/20 = 40.0% | 49.2% | -9.2 | -26.7 to +7.6 |
| gpt-6-luna-low vs gpt-6-luna-xhigh | 3/20 = 15.0% | 13.9% | +1.1 | -13.6 to +20.3 |
| gpt-6-luna-max vs gpt-6-luna-off | 16/20 = 80.0% | 84.4% | -4.4 | -19.4 to +9.9 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 47.4% | +2.6 | -11.9 to +17.3 |
| gpt-6-luna-off vs gpt-6-luna-xhigh | 2/20 = 10.0% | 14.3% | -4.3 | -15.4 to +9.4 |
#### cpa-tiers sweep gpt-6.1-sol

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-sol vs gpt-6.1-sol-high | 12/20 = 60.0% | 49.3% | +10.7 | -2.1 to +25.1 |
| gpt-6.1-sol vs gpt-6.1-sol-low | 7/20 = 35.0% | 47.5% | -12.5 | -29.9 to +5.4 |
| gpt-6.1-sol vs gpt-6.1-sol-max | 8/20 = 40.0% | 38.7% | +1.3 | -15.5 to +18.0 |
| gpt-6.1-sol vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 46.5% | +3.5 | -15.2 to +24.9 |
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 48.2% | +11.8 | -3.5 to +29.7 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 39.4% | +5.6 | -11.8 to +24.1 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 47.1% | -2.1 | -18.5 to +13.1 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 41.1% | -11.1 | -29.9 to +6.3 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 49.0% | +11.0 | -4.6 to +29.1 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 57.9% | -7.9 | -22.7 to +5.9 |
#### opus-effort

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5 vs claude-opus-5-5-high | 9/20 = 45.0% | 47.8% | -2.8 | -19.8 to +13.3 |
| claude-opus-5-5 vs claude-opus-5-5-low | 13/20 = 65.0% | 63.8% | +1.2 | -9.9 to +11.6 |
| claude-opus-5-5 vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 35.1% | -0.1 | -13.7 to +13.8 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 37.1% | -2.1 | -17.7 to +13.0 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| cpa-tiers cross-model | 0.5954 | 0.5958 | -0.0004 | -0.0006 to -0.0002 | 0: 46, 0.1: 1, 0.2: 3 | tau=0.1: 0.5958, tau=0.2: 0.5967, tau=0.4: 0.6004, tau=0.8: 0.6083, tau=1.6: 0.6166 | not kept |
| cpa-tiers cross-model (seat and starter terms) | 0.5793 | 0.5793 | -0.0001 | -0.0002 to +0.0000 | 0: 49, 0.2: 1 | tau=0.1: 0.5796, tau=0.2: 0.5807, tau=0.4: 0.5845, tau=0.8: 0.5930, tau=1.6: 0.6020 | not kept |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 0.6720 | 0.6736 | -0.0016 | -0.0049 to +0.0012 | 0: 24, 0.1: 4, 0.2: 15, 0.4: 7 | tau=0.1: 0.6718, tau=0.2: 0.6714, tau=0.4: 0.6725, tau=0.8: 0.6779, tau=1.6: 0.6840 | not kept |
| cpa-tiers sweep claude-haiku-4-5-20251001 (seat and starter terms) | 0.6725 | 0.6793 | -0.0067 | -0.0128 to -0.0017 | 0: 24, 0.1: 2, 0.2: 11, 0.4: 11, 0.8: 2 | tau=0.1: 0.6725, tau=0.2: 0.6727, tau=0.4: 0.6751, tau=0.8: 0.6828, tau=1.6: 0.6903 | not kept |
| cpa-tiers sweep claude-haiku-5-5 | 0.6631 | 0.6635 | -0.0004 | -0.0006 to -0.0001 | 0: 45, 0.1: 4, 0.2: 1 | tau=0.1: 0.6635, tau=0.2: 0.6647, tau=0.4: 0.6688, tau=0.8: 0.6765, tau=1.6: 0.6827 | not kept |
| cpa-tiers sweep claude-haiku-5-5 (seat and starter terms) | 0.6371 | 0.6377 | -0.0005 | -0.0009 to -0.0002 | 0: 42, 0.1: 4, 0.2: 4 | tau=0.1: 0.6375, tau=0.2: 0.6385, tau=0.4: 0.6422, tau=0.8: 0.6503, tau=1.6: 0.6574 | not kept |
| cpa-tiers sweep claude-sonnet-5-5 | 0.6707 | 0.6734 | -0.0027 | -0.0080 to +0.0024 | 0: 7, 0.1: 9, 0.2: 15, 0.4: 18, 0.8: 1 | tau=0.1: 0.6704, tau=0.2: 0.6699, tau=0.4: 0.6709, tau=0.8: 0.6773, tau=1.6: 0.6845 | not kept |
| cpa-tiers sweep claude-sonnet-5-5 (seat and starter terms) | 0.6693 | 0.6729 | -0.0036 | -0.0084 to +0.0008 | 0: 14, 0.1: 5, 0.2: 14, 0.4: 16, 0.8: 1 | tau=0.1: 0.6690, tau=0.2: 0.6684, tau=0.4: 0.6693, tau=0.8: 0.6759, tau=1.6: 0.6840 | not kept |
| cpa-tiers sweep gpt-5.6-terra | 0.6942 | 0.6996 | -0.0054 | -0.0089 to -0.0024 | 0: 37, 0.1: 3, 0.4: 9, 0.8: 1 | tau=0.1: 0.6945, tau=0.2: 0.6954, tau=0.4: 0.6991, tau=0.8: 0.7067, tau=1.6: 0.7131 | not kept |
| cpa-tiers sweep gpt-5.6-terra (seat and starter terms) | 0.7037 | 0.7060 | -0.0023 | -0.0042 to -0.0006 | 0: 33, 0.1: 4, 0.2: 9, 0.4: 4 | tau=0.1: 0.7040, tau=0.2: 0.7050, tau=0.4: 0.7085, tau=0.8: 0.7155, tau=1.6: 0.7212 | not kept |
| cpa-tiers sweep gpt-6-luna | 0.5763 | 0.5814 | -0.0051 | -0.0087 to -0.0021 | 0: 29, 0.1: 3, 0.2: 8, 0.4: 9, 0.8: 1 | tau=0.1: 0.5765, tau=0.2: 0.5771, tau=0.4: 0.5806, tau=0.8: 0.5902, tau=1.6: 0.6019 | not kept |
| cpa-tiers sweep gpt-6-luna (seat and starter terms) | 0.5781 | 0.5824 | -0.0043 | -0.0070 to -0.0015 | 0: 32, 0.1: 2, 0.2: 8, 0.4: 8 | tau=0.1: 0.5783, tau=0.2: 0.5790, tau=0.4: 0.5821, tau=0.8: 0.5909, tau=1.6: 0.6009 | not kept |
| cpa-tiers sweep gpt-6.1-sol | 0.7044 | 0.7109 | -0.0065 | -0.0151 to +0.0000 | 0: 16, 0.1: 5, 0.2: 14, 0.4: 12, 0.8: 3 | tau=0.1: 0.7041, tau=0.2: 0.7038, tau=0.4: 0.7046, tau=0.8: 0.7092, tau=1.6: 0.7138 | not kept |
| cpa-tiers sweep gpt-6.1-sol (seat and starter terms) | 0.7095 | 0.7131 | -0.0036 | -0.0092 to +0.0014 | 0: 17, 0.1: 4, 0.2: 13, 0.4: 14, 0.8: 2 | tau=0.1: 0.7092, tau=0.2: 0.7087, tau=0.4: 0.7093, tau=0.8: 0.7141, tau=1.6: 0.7192 | not kept |
| opus-effort | 0.6923 | 0.6939 | -0.0015 | -0.0042 to +0.0004 | 0: 46, 0.2: 1, 0.8: 2, 1.6: 1 | tau=0.1: 0.6928, tau=0.2: 0.6940, tau=0.4: 0.6973, tau=0.8: 0.7018, tau=1.6: 0.7046 | not kept |
| opus-effort (seat and starter terms) | 0.7131 | 0.7141 | -0.0009 | -0.0022 to +0.0000 | 0: 47, 0.1: 1, 0.4: 2 | tau=0.1: 0.7137, tau=0.2: 0.7152, tau=0.4: 0.7191, tau=0.8: 0.7246, tau=1.6: 0.7282 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| cpa-tiers cross-model | 9/29 = 31.0% | -0.38 |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 7/10 = 70.0% | +0.05 |
| cpa-tiers sweep claude-haiku-5-5 | 5/15 = 33.3% | -0.44 |
| cpa-tiers sweep claude-sonnet-5-5 | 6/15 = 40.0% | -0.04 |
| cpa-tiers sweep gpt-5.6-terra | 4/10 = 40.0% | -0.15 |
| cpa-tiers sweep gpt-6-luna | 7/15 = 46.7% | -0.09 |
| cpa-tiers sweep gpt-6.1-sol | 6/10 = 60.0% | -0.18 |
| opus-effort | 0/4 = 0.0% | -0.99 |
| all cohorts pooled | 44/108 = 40.7% | -0.22 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 4.4e-17, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 2471 of 2471 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 1235 blocks, 29 seeds (1 matches in half blocks left out) | 1245/2470 = 50.4% | 43.1% to 57.6% | 48.5% to 52.4% |
| cpa-tiers cross-model: 281 blocks, 19 seeds | 276/562 = 49.1% | 41.2% to 58.7% | 45.2% to 53.2% |
| cpa-tiers sweep claude-haiku-4-5-20251001: 100 blocks, 10 seeds | 105/200 = 52.5% | 42.0% to 60.0% | 45.5% to 59.0% |
| cpa-tiers sweep claude-haiku-5-5: 150 blocks, 10 seeds | 142/300 = 47.3% | 34.7% to 59.7% | 41.3% to 53.3% |
| cpa-tiers sweep claude-sonnet-5-5: 150 blocks, 10 seeds | 162/300 = 54.0% | 42.7% to 64.3% | 48.3% to 59.3% |
| cpa-tiers sweep gpt-5.6-terra: 100 blocks, 10 seeds | 96/200 = 48.0% | 37.0% to 59.5% | 40.5% to 55.5% |
| cpa-tiers sweep gpt-6-luna: 150 blocks, 10 seeds | 160/300 = 53.3% | 47.3% to 59.3% | 48.7% to 58.0% |
| cpa-tiers sweep gpt-6.1-sol: 100 blocks, 10 seeds | 111/200 = 55.5% | 43.5% to 68.0% | 48.0% to 63.0% |
| opus-effort: 40 blocks, 10 seeds | 42/80 = 52.5% | 33.8% to 72.5% | 41.2% to 65.0% |
| tournament 3: 20 blocks, 20 seeds (1 matches in half blocks left out) | 24/40 = 60.0% | 45.0% to 75.0% | 45.0% to 75.0% |
| tournament 4: 144 blocks, 10 seeds | 127/288 = 44.1% | 33.3% to 54.5% | 38.9% to 49.3% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 1411/2470 = 57.1% | 51.0% to 63.6% | 55.2% to 59.1% | 583/1235 |
| cpa-tiers cross-model | 334/562 = 59.4% | 51.7% to 66.5% | 55.5% to 63.3% | 119/281 |
| cpa-tiers sweep claude-haiku-4-5-20251001 | 115/200 = 57.5% | 50.5% to 66.5% | 51.0% to 64.5% | 50/100 |
| cpa-tiers sweep claude-haiku-5-5 | 186/300 = 62.0% | 52.0% to 72.0% | 56.3% to 68.0% | 75/150 |
| cpa-tiers sweep claude-sonnet-5-5 | 164/300 = 54.7% | 43.0% to 64.7% | 49.3% to 60.0% | 75/150 |
| cpa-tiers sweep gpt-5.6-terra | 108/200 = 54.0% | 43.0% to 64.5% | 47.5% to 61.0% | 50/100 |
| cpa-tiers sweep gpt-6-luna | 152/300 = 50.7% | 44.7% to 57.3% | 46.0% to 55.3% | 75/150 |
| cpa-tiers sweep gpt-6.1-sol | 107/200 = 53.5% | 40.5% to 66.0% | 46.0% to 61.0% | 50/100 |
| opus-effort | 46/80 = 57.5% | 38.8% to 76.2% | 46.2% to 68.8% | 20/40 |
| tournament 3 | 22/40 = 55.0% | 40.0% to 70.0% | 40.0% to 70.0% | 10/20 |
| tournament 4 | 177/288 = 61.5% | 53.2% to 69.9% | 56.2% to 67.0% | 59/144 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +0.8 | -5.9 to +7.0 | -1.1 to +2.8 | +7.2 | +0.8 to +13.8 | +5.3 to +9.1 |
| cpa-tiers cross-model | +0.6 | -6.7 to +9.4 | -3.4 to +4.6 | +9.5 | +1.4 to +17.8 | +5.6 to +13.5 |
| cpa-tiers sweep claude-haiku-4-5-20251001 | +2.5 | -6.7 to +9.5 | -4.5 to +8.9 | +7.5 | +0.4 to +16.9 | +0.9 to +14.3 |
| cpa-tiers sweep claude-haiku-5-5 | -2.7 | -13.7 to +7.6 | -8.1 to +3.0 | +12.0 | +1.3 to +22.8 | +6.3 to +18.0 |
| cpa-tiers sweep claude-sonnet-5-5 | +4.0 | -7.5 to +14.7 | -1.5 to +9.4 | +4.7 | -7.5 to +15.1 | -0.6 to +10.2 |
| cpa-tiers sweep gpt-5.6-terra | -2.0 | -13.7 to +9.4 | -9.3 to +5.5 | +4.0 | -7.7 to +15.0 | -2.6 to +11.3 |
| cpa-tiers sweep gpt-6-luna | +3.3 | -3.0 to +9.8 | -1.6 to +8.2 | +0.7 | -5.4 to +7.3 | -4.0 to +5.4 |
| cpa-tiers sweep gpt-6.1-sol | +5.5 | -7.5 to +18.6 | -2.0 to +12.9 | +3.5 | -10.1 to +16.9 | -3.8 to +11.0 |
| opus-effort | +2.5 | -16.7 to +22.5 | -9.0 to +14.1 | +7.5 | -12.5 to +26.1 | -4.3 to +18.9 |
| tournament 3 | +10.0 | -5.2 to +25.0 | -5.0 to +25.0 | +5.0 | -10.0 to +18.8 | -10.1 to +20.0 |
| tournament 4 | -4.0 | -11.9 to +4.2 | -8.9 to +1.0 | +10.7 | +2.5 to +18.8 | +5.4 to +16.1 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| claude-haiku-4-5-20251001: 208 blocks, 19 seeds | 206/416 = 49.5% | 42.8% to 56.1% | 45.2% to 53.8% |
| claude-haiku-5-5: 264 blocks, 19 seeds | 249/528 = 47.2% | 37.2% to 57.1% | 42.6% to 51.7% |
| claude-opus-5-5: 159 blocks, 29 seeds | 160/318 = 50.3% | 40.2% to 61.4% | 44.3% to 56.0% |
| claude-sonnet-5-5: 263 blocks, 19 seeds | 267/526 = 50.8% | 42.2% to 58.9% | 46.8% to 54.9% |
| gpt-5.6-terra: 208 blocks, 19 seeds | 217/416 = 52.2% | 43.0% to 61.1% | 47.1% to 57.2% |
| gpt-6-astra: 109 blocks, 29 seeds | 105/218 = 48.2% | 38.7% to 60.4% | 41.7% to 54.6% |
| gpt-6-luna: 261 blocks, 19 seeds | 260/522 = 49.8% | 44.8% to 55.0% | 46.2% to 53.6% |
| gpt-6.1-sol: 208 blocks, 19 seeds | 208/416 = 50.0% | 40.3% to 60.0% | 45.0% to 55.3% |

#### Per seed, all cohorts

Cohorts reuse seeds 3000 to 3018 (tournament 3 adds 3020 to 3029), so a seed's starter result pools many pairings.

| seed | position that starts | complete blocks | starter wins/matches = share |
|---|---|---|---|
| 3000 | 2 | 122 | 173/244 = 70.9% |
| 3001 | 2 | 36 | 54/72 = 75.0% |
| 3002 | 2 | 36 | 38/72 = 52.8% |
| 3003 | 2 | 36 | 34/72 = 47.2% |
| 3004 | 1 | 37 | 57/74 = 77.0% |
| 3005 | 1 | 37 | 28/74 = 37.8% |
| 3006 | 1 | 36 | 39/72 = 54.2% |
| 3007 | 2 | 37 | 60/74 = 81.1% |
| 3008 | 2 | 37 | 42/74 = 56.8% |
| 3009 | 1 | 37 | 45/74 = 60.8% |
| 3010 | 1 | 86 | 115/172 = 66.9% |
| 3011 | 1 | 86 | 119/172 = 69.2% |
| 3012 | 2 | 86 | 75/172 = 43.6% |
| 3013 | 2 | 86 | 80/172 = 46.5% |
| 3014 | 1 | 86 | 67/172 = 39.0% |
| 3015 | 1 | 86 | 127/172 = 73.8% |
| 3016 | 1 | 86 | 71/172 = 41.3% |
| 3017 | 2 | 86 | 85/172 = 49.4% |
| 3018 | 2 | 86 | 92/172 = 53.5% |
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
| the 19 seeds with 10 or more blocks, each once |  | 1225 | mean of seed shares 57.7% (95% CI 51.7% to 63.8%, seeds drawn) |

### Tournament 3

| scored matches | Opus xhigh wins/matches = share | 95% CI (seed blocks drawn, wins over matches) | mean of block shares (a block counts once) | 95% CI | Opus minus Astra, Elo (95% CI) | blocks Opus both / split / Astra both |
|---|---|---|---|---|---|---|
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 38.1% to 69.0% | 52.4% | 35.7% to 69.0% | +25 (-81 to +132) | 6 / 10 / 4 |
| 40 matches, 20 complete seed pairs | 22/40 = 55.0% | 40.0% to 70.0% | 55.0% | 40.0% to 70.0% | +35 (-70 to +146) | 6 / 10 / 4 |

The 41-match estimate adds seed 3030's one scored match, which Astra won, to the 40 matches of complete pairs.

#### Matched against Opus medium vs Astra on the same seeds (tournament 1)

| matched seeds | Opus xhigh wins | Opus medium wins | difference in share (95% CI, seeds drawn) |
|---|---|---|---|
| 10 seeds, 20 matches each | 10/20 | 9/20 | +5.0 pp (-15.1 to +25.0) |

The matched seeds are 3000 to 3009, so the matched estimate is the same whether tournament 3 counts 40 or 41 matches.
<!-- tables:end -->
