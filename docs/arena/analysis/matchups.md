# Matchup analysis

Ratings, pair effects, seat and round 1 starter effects for the scored arena matches, from the analysis database ([database.md](../database.md)). All scored matches are two-player. Every rate shows numerator/denominator, a win share counts a split by its share, and every interval is a 95% bootstrap that draws whole units, never single matches or seat swaps: seed blocks (the two seat-swapped matches of one pair and seed) for ratings, and seeds (every block played at a seed, in any pairing) for the headline seat and starter figures. The tables below the line "Tables" are generated: `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` rewrites them, with a fixed RNG seed, in about 70 minutes under `nice`. Nothing here reads provenance or account data.

**DeepSeek is left out.** Every match with deepseek-v4.1-flash (20 scored matches) is dropped from all cohorts, fits, seat and starter figures and tables, because its free tier refused requests, so its games are not a random sample of what was scheduled. That leaves 2,471 scored matches, with data as of 2026-10-26. Every finding below uses these.

## Findings

**Ratings are pooled.** One Bradley-Terry fit covers every scored match of every tournament, so all 38 configs share one Elo scale with the mean at 0, as in the viewer. Tournament 4 gave every config games against other models, so no rating leans on an assumption that effort gaps carry across opponents. `results.md` and the viewer show the same ratings. A second fit on pot share (a config's cash over the match's cash, which credits the round prizes a loser banks) gives the cash rating. Cohorts are only a way to group matches. A cohort is one kind of comparison, pooled over every tournament: Cross-model (every match between different models) or one model's efforts (every match of that model against itself), as in the viewer. There are eight: Cross-model and the efforts of Haiku 4.5, Haiku 5.5, Luna, Opus, Sol, Sonnet and Terra.
- **Coverage.** The Cross-model cohort has 38 configs and 891 matches over 174 of the 703 pairs, 2 to 41 matches per pair. Each effort cohort is a round robin with 20 matches per pair, except Opus efforts, which plays 4 of its 6 pairs. Tournament 4 has 288 matches in 144 seat-swapped blocks: 37 configs, each playing 5 others (10 matches) on seeds 3000 to 3009.
- **Cross-model medium configs**, win rating (95% CI by seed blocks): astra +174 (+129 to +226), opus +98 (+50 to +148), sol +84 (+41 to +130), sonnet +43 (+1 to +87), haiku 5.5 +42 (+5 to +82), terra -25 (-71 to +17), haiku 4.5 -138 (-190 to -88), luna -226 (-290 to -175). Astra stands above and luna and haiku 4.5 below; the five in between overlap. Drawing seeds instead of blocks moves the intervals modestly.
- **Top and bottom of all 38.** Opus xhigh +205 (+125 to +290), Sonnet max +191 (+110 to +283), astra +174 and Sol max +164 lead. Luna low -317, luna off -311 and haiku 4.5 off -302 trail. Effort configs have 30 to 110 matches each, so their intervals are about 150 to 200 Elo wide.
- **Effort.** Within each model the top level is xhigh or max in six of seven models with a sweep or effort tournament: luna xhigh +0 and max -18 against medium -226, sonnet max +191 against medium +43, haiku 5.5 xhigh +130, terra max +34, sol max +164, Opus xhigh +205. Haiku 4.5 has no such level; its top is minimal (-133) and medium (-138). Off or low is the bottom level in six of seven: luna low -317, haiku 4.5 off -302, haiku 5.5 off -72, sonnet low -14, terra low -59 and Opus low -1. Sol is the exception: medium +84 sits at the bottom of a flat range up to +164, and the intervals overlap. The order of neighbouring levels is mostly inside the intervals.
- **Cash.** Cash ratings spread about two thirds as far as win ratings (+128 to -205 against +205 to -317), because losers bank round prizes. Pot shares run from 31.4% (luna low) to 64.7% (luna xhigh). The two ratings agree on the leaders (Sonnet max +128, Opus xhigh +109, Sol max +108) and the trailers (luna low -205). A config can win less than it earns: Opus low wins 43.3% of its 30 matches yet takes 55.8% of the pot (cash +67, win -1), and terra high wins 44.4% and takes 49.6% (cash +13, win -42). Haiku 5.5 xhigh is the reverse: 62.7% of wins, 54.0% of the pot, cash +29 against win +130.

**Matchup effects: none worth keeping.** The observed pair share minus the share fitted by the pooled ratings is small and is reported as a descriptive residual. It is not a test: the ratings are regularized, so residuals are forced (a pair at the end of a chain of pairs is pulled to its fit), and the bootstrap range around a residual is not a calibrated interval around zero. The largest Cross-model residual over a pair of 20 matches or more is haiku 4.5 against sonnet (2/20 observed against 26% fitted). Pairs of 2 matches are too thin to read.
- The test is held-out prediction. Whole seed blocks were held out (5 repeats of 10-fold cross-validation, with the shrinkage chosen inside each training set from 0 to 1.6, so no held-out block picks it). In every tested cohort the nested pair-effect model scored no better than ratings alone: the gain per match is between -0.0060 and +0.0000 nats, and the lower end of its interval is never above 0. The shrinkage chose 0 (ratings only) in most folds for Cross-model, Haiku 5.5, Luna, Opus and Terra. So **no cohort keeps pair effects**. Cross-model now holds tournament 4's one-block pairs and the 41-match Opus xhigh against Astra pair.
- The same holds when the ratings also have a seat term and a round 1 starter term, which on their own lower the Cross-model loss from 0.6210 to 0.6008 per match.
- Reverse pairs, described and not tested: for the entrant seated first, a real matchup effect should show the opposite sign when A sat first and when B sat first. 125 of 253 pairs (49.4%) do, with a correlation of -0.17 between the A-first effect and minus the B-first effect (a negative value means the two orders lean the same way). The signs are not independent (the two orders of a block share a seed, seeds are reused across pairings, and the ratings are fitted jointly), so no test is made. The two entrants' effects in a pair sum to zero to rounding (6e-17) because every match's shares sum to 1.
- With 20 matches per pair in the effort cohorts and 2 in most of Cross-model, only large pair effects could show.

**Seat and starter.** Whoever opens round 1 (read from the public line `Round 1 begins ... Player X starts.` of each match's events) also fired the first shot in 2471 of 2471 matches. The seed decides that position, and both matches of a block share it.
- **Position 1:** 1245/2470 = 50.4% over 1,235 complete blocks at 29 seeds (95% CI by seeds 43.2% to 57.8%; by seed blocks 48.4% to 52.3%). Cross-model 427/890 = 48.0% (39.8% to 57.2% by seeds).
- **Starter:** the player who opens round 1 won 1411/2470 = 57.1% (50.7% to 63.5% by seeds; 55.1% to 59.1% by seed blocks). The overall starter association stands: it is about 7 points above even.
- **Split:** the position and starter effects below are a descriptive additive split of block shares by which position starts. Every one of the 29 complete-block seeds has exactly one starter position, so a starter effect cannot be told from a seed effect. The split describes these seed blocks; only the seeds-drawn intervals reach beyond them. Starter +7.2 points overall (seeds +0.3 to +13.7; blocks +5.2 to +9.1), +9.8 Cross-model (+1.7 to +17.5; blocks +6.6 to +12.9). Position +0.8 overall (-5.7 to +7.3 by seeds).
- **It depends on the seed.** The starter won 173/244 = 70.9% of matches at seed 3000 and 28/74 = 37.8% at seed 3005. Counting each of the 19 seeds with 10 or more blocks once, the starter's mean share is 57.7% (51.7% to 63.8%, seeds drawn). Starter figures are therefore not reported per model: a model's blocks cover a handful of seeds, so they say as much about those seeds as about the model. Position 1 per model is in the tables and sits near 50% for every model.
- **Recommendation:** a starter term is worth keeping as an option for future ratings. It lowers held-out loss a lot (Cross-model 0.6210 to 0.6008 per match) and moves the pooled ratings by up to 7.4 Elo. The headline fits stay without it.

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
- **Power.** The held-out test can rule out large pair effects only; "none kept" is not "none exist". Cohorts with 40 blocks (Opus efforts) are the weakest, and a pair-effect model with 4 pairs is almost saturated.
- **Thin cells.** Tournament 4 has one seat-swapped block (2 matches) per pair, so one pair says little; its value is that it links every config to the others. Sonnet max's rating rests on its 8 tournament-4 matches and 2 tournament-1 games.
- **Position and starter overlap** because the seed fixes the starter's position, and tournament 1's seeds 3000 to 3009 start position 2 six times in ten.
- **No replays.** Everything comes from standings, cash, seating and the public round 1 line; no moves were reviewed.

## Tables

<!-- tables:start -->
### Schedule coverage

| cohort | entrants | scored matches | complete / half blocks | pairs played | matches per pair min / median / max | connected | scheduled by status |
|---|---|---|---|---|---|---|---|
| Cross-model | 38 | 891 | 445 / 1 | 174/703 | 2 / 2 / 41 | yes | 891 completed, 5 partial (skipped), 138 skipped (skipped), 14 unstarted |
| Haiku 4.5 efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| Haiku 5.5 efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Luna efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Opus efforts | 4 | 80 | 40 / 0 | 4/6 | 20 / 20 / 20 | yes | 80 completed |
| Sol efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| Sonnet efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Terra efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |

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

#### Cross-model

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-5-5 | 6/20 = 30.0% | 26.1% | +3.9 | -11.7 to +19.2 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-high | 0/2 = 0.0% | 23.5% | -23.5 | -32.4 to -15.1 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-low | 0/2 = 0.0% | 26.3% | -26.3 | -36.6 to -17.3 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-max | 0/2 = 0.0% | 18.6% | -18.6 | -27.0 to -11.4 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-off | 1/2 = 50.0% | 40.7% | +9.3 | -4.1 to +20.4 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-xhigh | 1/2 = 50.0% | 17.6% | +32.4 | +23.4 to +38.8 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5 | 7/20 = 35.0% | 20.5% | +14.5 | -4.1 to +34.3 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-low | 0/2 = 0.0% | 31.3% | -31.3 | -45.4 to -18.0 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5 | 2/20 = 10.0% | 26.1% | -16.1 | -29.0 to -1.4 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-high | 0/2 = 0.0% | 22.3% | -22.3 | -32.0 to -13.3 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-low | 0/2 = 0.0% | 32.8% | -32.8 | -45.8 to -21.6 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 13.1% | -13.1 | -20.7 to -7.4 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-off | 0/2 = 0.0% | 25.8% | -25.8 | -35.3 to -16.4 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra | 6/20 = 30.0% | 34.3% | -4.3 | -20.7 to +10.9 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-low | 0/2 = 0.0% | 38.8% | -38.8 | -51.2 to -26.8 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-max | 0/2 = 0.0% | 27.1% | -27.1 | -39.2 to -16.5 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-xhigh | 1/2 = 50.0% | 27.3% | +22.7 | +9.5 to +32.2 |
| claude-haiku-4-5-20251001 vs gpt-6-astra | 3/20 = 15.0% | 14.2% | +0.8 | -13.3 to +17.1 |
| claude-haiku-4-5-20251001 vs gpt-6-luna | 12/20 = 60.0% | 62.5% | -2.5 | -28.8 to +20.1 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-high | 1/2 = 50.0% | 41.0% | +9.0 | -6.2 to +22.8 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-off | 2/2 = 100.0% | 73.1% | +26.9 | +15.7 to +39.4 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 31.1% | +18.9 | +5.7 to +29.0 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol | 6/20 = 30.0% | 21.8% | +8.2 | -11.4 to +29.0 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-high | 1/2 = 50.0% | 21.3% | +28.7 | +18.2 to +35.7 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 19.5% | +30.5 | +20.3 to +37.9 |
| claude-haiku-4-5-20251001-high vs claude-sonnet-5-5 | 0/2 = 0.0% | 21.6% | -21.6 | -31.8 to -13.3 |
| claude-haiku-4-5-20251001-high vs gpt-5.6-terra | 0/2 = 0.0% | 29.0% | -29.0 | -40.6 to -18.7 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra | 0/2 = 0.0% | 11.5% | -11.5 | -17.9 to -6.2 |
| claude-haiku-4-5-20251001-high vs gpt-6-luna | 0/2 = 0.0% | 56.5% | -56.5 | -69.8 to -40.3 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-sol | 0/2 = 0.0% | 17.8% | -17.8 | -27.0 to -10.9 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5 | 1/2 = 50.0% | 22.9% | +27.1 | +16.5 to +34.9 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5 | 0/2 = 0.0% | 17.8% | -17.8 | -26.2 to -10.9 |
| claude-haiku-4-5-20251001-low vs gpt-5.6-terra | 1/2 = 50.0% | 30.5% | +19.5 | +7.4 to +29.3 |
| claude-haiku-4-5-20251001-low vs gpt-6-luna | 2/2 = 100.0% | 58.3% | +41.7 | +27.8 to +54.0 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-sol | 0/2 = 0.0% | 18.9% | -18.9 | -27.9 to -11.3 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5 | 1/2 = 50.0% | 26.7% | +23.3 | +11.5 to +32.6 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5 | 1/2 = 50.0% | 21.0% | +29.0 | +18.2 to +36.4 |
| claude-haiku-4-5-20251001-minimal vs claude-sonnet-5-5 | 1/2 = 50.0% | 26.6% | +23.4 | +11.8 to +32.7 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra | 0/2 = 0.0% | 14.6% | -14.6 | -21.9 to -8.2 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-luna | 1/2 = 50.0% | 63.1% | -13.1 | -25.7 to +2.4 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5 | 1/2 = 50.0% | 12.1% | +37.9 | +30.3 to +42.9 |
| claude-haiku-4-5-20251001-off vs claude-sonnet-5-5 | 1/2 = 50.0% | 12.1% | +37.9 | +30.3 to +42.7 |
| claude-haiku-4-5-20251001-off vs gpt-5.6-terra | 0/2 = 0.0% | 16.9% | -16.9 | -25.5 to -9.6 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra | 0/2 = 0.0% | 6.1% | -6.1 | -10.0 to -3.0 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-sol | 0/2 = 0.0% | 9.8% | -9.8 | -15.4 to -5.0 |
| claude-haiku-5-5 vs claude-opus-5-5 | 7/20 = 35.0% | 42.1% | -7.1 | -22.8 to +6.8 |
| claude-haiku-5-5 vs claude-opus-5-5-high | 0/2 = 0.0% | 40.0% | -40.0 | -54.5 to -25.5 |
| claude-haiku-5-5 vs claude-opus-5-5-low | 1/2 = 50.0% | 56.2% | -6.2 | -21.7 to +8.6 |
| claude-haiku-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 49.9% | +10.1 | -8.0 to +28.5 |
| claude-haiku-5-5 vs claude-sonnet-5-5-high | 0/2 = 0.0% | 44.7% | -44.7 | -56.3 to -30.6 |
| claude-haiku-5-5 vs claude-sonnet-5-5-low | 2/2 = 100.0% | 58.0% | +42.0 | +28.6 to +53.2 |
| claude-haiku-5-5 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 29.8% | -29.8 | -41.4 to -18.7 |
| claude-haiku-5-5 vs claude-sonnet-5-5-off | 1/2 = 50.0% | 49.5% | +0.5 | -11.8 to +11.5 |
| claude-haiku-5-5 vs claude-sonnet-5-5-xhigh | 1/2 = 50.0% | 38.8% | +11.2 | -0.8 to +22.1 |
| claude-haiku-5-5 vs gpt-5.6-terra | 13/20 = 65.0% | 59.6% | +5.4 | -8.9 to +20.5 |
| claude-haiku-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 61.9% | +38.1 | +26.7 to +48.4 |
| claude-haiku-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.2% | -14.2 | -24.6 to -3.1 |
| claude-haiku-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 51.2% | +48.8 | +34.6 to +60.4 |
| claude-haiku-5-5 vs gpt-6-astra | 6/20 = 30.0% | 31.9% | -1.9 | -16.7 to +12.9 |
| claude-haiku-5-5 vs gpt-6-luna | 19/20 = 95.0% | 82.5% | +12.5 | +1.9 to +21.5 |
| claude-haiku-5-5 vs gpt-6-luna-high | 1/2 = 50.0% | 66.2% | -16.2 | -27.4 to -1.2 |
| claude-haiku-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.8% | +11.2 | +5.8 to +18.1 |
| claude-haiku-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 58.7% | -8.7 | -20.6 to +5.2 |
| claude-haiku-5-5 vs gpt-6.1-sol | 10/20 = 50.0% | 44.0% | +6.0 | -7.8 to +20.0 |
| claude-haiku-5-5 vs gpt-6.1-sol-high | 1/2 = 50.0% | 43.4% | +6.6 | -5.7 to +17.5 |
| claude-haiku-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 33.2% | +16.8 | +4.1 to +26.9 |
| claude-haiku-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 40.6% | +9.4 | -3.7 to +20.5 |
| claude-haiku-5-5-high vs claude-opus-5-5 | 1/2 = 50.0% | 45.7% | +4.3 | -8.1 to +16.4 |
| claude-haiku-5-5-high vs claude-sonnet-5-5 | 0/2 = 0.0% | 53.5% | -53.5 | -64.0 to -39.5 |
| claude-haiku-5-5-high vs gpt-6-astra | 0/2 = 0.0% | 35.1% | -35.1 | -45.3 to -24.2 |
| claude-haiku-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 84.4% | -34.4 | -40.1 to -26.2 |
| claude-haiku-5-5-low vs claude-opus-5-5 | 2/2 = 100.0% | 41.9% | +58.1 | +44.3 to +68.5 |
| claude-haiku-5-5-low vs claude-sonnet-5-5 | 1/2 = 50.0% | 49.6% | +0.4 | -12.1 to +12.3 |
| claude-haiku-5-5-low vs gpt-5.6-terra | 1/2 = 50.0% | 59.4% | -9.4 | -20.7 to +2.8 |
| claude-haiku-5-5-low vs gpt-6.1-sol | 2/2 = 100.0% | 43.8% | +56.2 | +43.5 to +66.3 |
| claude-haiku-5-5-max vs claude-opus-5-5 | 2/2 = 100.0% | 53.1% | +46.9 | +34.6 to +57.3 |
| claude-haiku-5-5-max vs claude-sonnet-5-5 | 1/2 = 50.0% | 60.7% | -10.7 | -20.9 to +0.9 |
| claude-haiku-5-5-max vs gpt-5.6-terra | 1/2 = 50.0% | 69.6% | -19.6 | -28.7 to -9.5 |
| claude-haiku-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 54.9% | -4.9 | -16.9 to +6.6 |
| claude-haiku-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 43.3% | +6.7 | -5.0 to +17.9 |
| claude-haiku-5-5-off vs gpt-6-astra | 0/2 = 0.0% | 19.5% | -19.5 | -27.7 to -11.8 |
| claude-haiku-5-5-off vs gpt-6-luna | 1/2 = 50.0% | 70.8% | -20.8 | -29.8 to -8.5 |
| claude-haiku-5-5-off vs gpt-6.1-sol | 0/2 = 0.0% | 28.9% | -28.9 | -38.5 to -18.7 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5 | 0/2 = 0.0% | 54.6% | -54.6 | -64.9 to -41.8 |
| claude-haiku-5-5-xhigh vs claude-sonnet-5-5 | 1/2 = 50.0% | 62.2% | -12.2 | -23.2 to -1.0 |
| claude-haiku-5-5-xhigh vs gpt-6-astra | 0/2 = 0.0% | 43.7% | -43.7 | -54.7 to -30.7 |
| claude-haiku-5-5-xhigh vs gpt-6-luna | 2/2 = 100.0% | 88.6% | +11.4 | +6.7 to +17.1 |
| claude-opus-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 57.8% | +2.2 | -15.3 to +20.1 |
| claude-opus-5-5 vs claude-sonnet-5-5-low | 0/2 = 0.0% | 65.5% | -65.5 | -76.0 to -51.5 |
| claude-opus-5-5 vs claude-sonnet-5-5-max | 2/2 = 100.0% | 36.9% | +63.1 | +48.4 to +74.2 |
| claude-opus-5-5 vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 46.6% | +53.4 | +39.3 to +64.7 |
| claude-opus-5-5 vs gpt-5.6-terra | 12/20 = 60.0% | 67.0% | -7.0 | -19.8 to +7.4 |
| claude-opus-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 69.0% | +31.0 | +20.6 to +42.0 |
| claude-opus-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 71.1% | -21.1 | -30.2 to -10.1 |
| claude-opus-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 59.1% | +40.9 | +27.9 to +54.6 |
| claude-opus-5-5 vs gpt-5.6-terra-xhigh | 2/2 = 100.0% | 59.3% | +40.7 | +27.9 to +52.5 |
| claude-opus-5-5 vs gpt-6-astra | 9/20 = 45.0% | 39.2% | +5.8 | -5.9 to +16.9 |
| claude-opus-5-5 vs gpt-6-luna | 16/20 = 80.0% | 86.6% | -6.6 | -28.1 to +11.2 |
| claude-opus-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 91.6% | +8.4 | +4.3 to +14.5 |
| claude-opus-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 66.1% | -16.1 | -26.4 to -2.0 |
| claude-opus-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 63.7% | -13.7 | -24.3 to +0.4 |
| claude-opus-5-5 vs gpt-6.1-sol | 12/20 = 60.0% | 51.9% | +8.1 | -10.2 to +26.7 |
| claude-opus-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 49.4% | +0.6 | -12.8 to +13.2 |
| claude-opus-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 40.6% | +9.4 | -3.5 to +20.8 |
| claude-opus-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 48.4% | +1.6 | -10.4 to +15.1 |
| claude-opus-5-5-high vs claude-sonnet-5-5 | 1/2 = 50.0% | 59.9% | -9.9 | -24.1 to +5.5 |
| claude-opus-5-5-high vs gpt-6-astra | 1/2 = 50.0% | 41.3% | +8.7 | -6.0 to +21.5 |
| claude-opus-5-5-high vs gpt-6-luna | 2/2 = 100.0% | 87.6% | +12.4 | +6.3 to +20.8 |
| claude-opus-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 54.1% | -54.1 | -67.0 to -37.1 |
| claude-opus-5-5-low vs claude-sonnet-5-5 | 1/2 = 50.0% | 43.7% | +6.3 | -8.6 to +21.6 |
| claude-opus-5-5-low vs gpt-5.6-terra | 0/2 = 0.0% | 53.5% | -53.5 | -64.6 to -33.5 |
| claude-opus-5-5-low vs gpt-6-luna | 2/2 = 100.0% | 78.5% | +21.5 | +11.5 to +34.8 |
| claude-opus-5-5-xhigh vs gpt-6-astra | 22/41 = 53.7% | 54.4% | -0.7 | -9.3 to +7.6 |
| claude-sonnet-5-5 vs gpt-5.6-terra | 11/20 = 55.0% | 59.7% | -4.7 | -29.6 to +20.4 |
| claude-sonnet-5-5 vs gpt-5.6-terra-high | 1/2 = 50.0% | 62.0% | -12.0 | -23.0 to +0.2 |
| claude-sonnet-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.2% | -14.2 | -25.3 to -2.3 |
| claude-sonnet-5-5 vs gpt-5.6-terra-xhigh | 0/2 = 0.0% | 51.5% | -51.5 | -62.6 to -37.8 |
| claude-sonnet-5-5 vs gpt-6-astra | 7/20 = 35.0% | 32.0% | +3.0 | -12.9 to +16.7 |
| claude-sonnet-5-5 vs gpt-6-luna | 17/20 = 85.0% | 82.5% | +2.5 | -11.9 to +16.3 |
| claude-sonnet-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.8% | +11.2 | +5.7 to +18.1 |
| claude-sonnet-5-5 vs gpt-6-luna-off | 2/2 = 100.0% | 88.5% | +11.5 | +6.3 to +18.0 |
| claude-sonnet-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 56.2% | -6.2 | -18.6 to +6.7 |
| claude-sonnet-5-5 vs gpt-6.1-sol | 8/20 = 40.0% | 44.1% | -4.1 | -22.0 to +14.2 |
| claude-sonnet-5-5 vs gpt-6.1-sol-high | 1/2 = 50.0% | 43.4% | +6.6 | -4.5 to +18.1 |
| claude-sonnet-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 41.7% | +8.3 | -4.7 to +19.4 |
| claude-sonnet-5-5 vs gpt-6.1-sol-max | 0/2 = 0.0% | 33.3% | -33.3 | -44.1 to -22.1 |
| claude-sonnet-5-5-high vs gpt-5.6-terra | 1/2 = 50.0% | 64.6% | -14.6 | -25.7 to -1.2 |
| claude-sonnet-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 85.3% | -35.3 | -41.1 to -26.5 |
| claude-sonnet-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 49.3% | -49.3 | -61.6 to -35.0 |
| claude-sonnet-5-5-low vs gpt-6-astra | 0/2 = 0.0% | 25.4% | -25.4 | -36.2 to -15.3 |
| claude-sonnet-5-5-low vs gpt-6-luna | 1/2 = 50.0% | 77.3% | -27.3 | -35.6 to -14.9 |
| claude-sonnet-5-5-max vs gpt-6-luna | 2/2 = 100.0% | 91.7% | +8.3 | +4.3 to +13.9 |
| claude-sonnet-5-5-max vs gpt-6.1-sol | 2/2 = 100.0% | 64.9% | +35.1 | +22.9 to +46.7 |
| claude-sonnet-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 60.1% | -10.1 | -20.9 to +2.0 |
| claude-sonnet-5-5-off vs gpt-6-astra | 2/2 = 100.0% | 32.4% | +67.6 | +55.1 to +76.9 |
| claude-sonnet-5-5-off vs gpt-6.1-sol | 1/2 = 50.0% | 44.5% | +5.5 | -6.7 to +17.2 |
| claude-sonnet-5-5-xhigh vs gpt-5.6-terra | 2/2 = 100.0% | 69.9% | +30.1 | +19.5 to +40.7 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra | 1/2 = 50.0% | 42.5% | +7.5 | -5.9 to +19.4 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 55.3% | -5.3 | -17.7 to +7.0 |
| gpt-5.6-terra vs gpt-6-astra | 5/20 = 25.0% | 24.1% | +0.9 | -15.3 to +16.1 |
| gpt-5.6-terra vs gpt-6-luna | 15/20 = 75.0% | 76.1% | -1.1 | -25.0 to +18.0 |
| gpt-5.6-terra vs gpt-6-luna-high | 2/2 = 100.0% | 57.0% | +43.0 | +29.1 to +57.2 |
| gpt-5.6-terra vs gpt-6-luna-low | 1/2 = 50.0% | 84.3% | -34.3 | -40.8 to -23.7 |
| gpt-5.6-terra vs gpt-6-luna-max | 2/2 = 100.0% | 49.0% | +51.0 | +36.5 to +63.6 |
| gpt-5.6-terra vs gpt-6-luna-off | 2/2 = 100.0% | 83.9% | +16.1 | +9.4 to +24.8 |
| gpt-5.6-terra vs gpt-6.1-sol | 6/20 = 30.0% | 34.8% | -4.8 | -20.2 to +10.5 |
| gpt-5.6-terra vs gpt-6.1-sol-high | 0/2 = 0.0% | 34.2% | -34.2 | -44.8 to -23.1 |
| gpt-5.6-terra vs gpt-6.1-sol-low | 0/2 = 0.0% | 32.5% | -32.5 | -44.3 to -21.2 |
| gpt-5.6-terra vs gpt-6.1-sol-max | 0/2 = 0.0% | 25.2% | -25.2 | -35.1 to -15.7 |
| gpt-5.6-terra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 31.6% | -31.6 | -42.7 to -20.4 |
| gpt-5.6-terra-high vs gpt-6-luna | 1/2 = 50.0% | 74.3% | -24.3 | -32.8 to -11.8 |
| gpt-5.6-terra-high vs gpt-6.1-sol | 1/2 = 50.0% | 32.6% | +17.4 | +6.1 to +27.7 |
| gpt-5.6-terra-low vs gpt-6-astra | 0/2 = 0.0% | 20.8% | -20.8 | -29.2 to -12.7 |
| gpt-5.6-terra-max vs gpt-6-astra | 1/2 = 50.0% | 30.9% | +19.1 | +6.0 to +29.1 |
| gpt-5.6-terra-max vs gpt-6-luna | 2/2 = 100.0% | 81.7% | +18.3 | +10.2 to +28.5 |
| gpt-5.6-terra-xhigh vs gpt-6-astra | 0/2 = 0.0% | 30.7% | -30.7 | -41.3 to -20.0 |
| gpt-5.6-terra-xhigh vs gpt-6.1-sol | 0/2 = 0.0% | 42.6% | -42.6 | -54.1 to -29.4 |
| gpt-6-astra vs gpt-6-luna | 19/20 = 95.0% | 90.9% | +4.1 | -7.0 to +11.5 |
| gpt-6-astra vs gpt-6-luna-high | 1/2 = 50.0% | 80.7% | -30.7 | -37.8 to -18.9 |
| gpt-6-astra vs gpt-6-luna-max | 2/2 = 100.0% | 75.2% | +24.8 | +15.6 to +36.3 |
| gpt-6-astra vs gpt-6-luna-off | 2/2 = 100.0% | 94.2% | +5.8 | +3.0 to +9.8 |
| gpt-6-astra vs gpt-6-luna-xhigh | 1/2 = 50.0% | 73.1% | -23.1 | -32.3 to -11.2 |
| gpt-6-astra vs gpt-6.1-sol | 12/20 = 60.0% | 62.6% | -2.6 | -21.0 to +14.6 |
| gpt-6-astra vs gpt-6.1-sol-low | 2/2 = 100.0% | 60.3% | +39.7 | +26.9 to +52.6 |
| gpt-6-astra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 59.3% | -59.3 | -69.5 to -44.0 |
| gpt-6-luna vs gpt-6.1-sol | 3/20 = 15.0% | 14.3% | +0.7 | -12.6 to +15.5 |
| gpt-6-luna vs gpt-6.1-sol-high | 1/2 = 50.0% | 14.0% | +36.0 | +28.0 to +41.6 |
| gpt-6-luna vs gpt-6.1-sol-low | 0/2 = 0.0% | 13.1% | -13.1 | -21.0 to -7.2 |
| gpt-6-luna vs gpt-6.1-sol-max | 0/2 = 0.0% | 9.6% | -9.6 | -15.2 to -5.4 |
| gpt-6-luna-high vs gpt-6.1-sol | 1/2 = 50.0% | 28.6% | +21.4 | +7.8 to +31.3 |
| gpt-6-luna-low vs gpt-6.1-sol | 0/2 = 0.0% | 9.0% | -9.0 | -14.7 to -4.6 |
| gpt-6-luna-max vs gpt-6.1-sol | 0/2 = 0.0% | 35.7% | -35.7 | -47.5 to -23.0 |
| gpt-6-luna-off vs gpt-6.1-sol | 1/2 = 50.0% | 9.3% | +40.7 | +34.5 to +44.7 |
| gpt-6-luna-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 38.1% | +11.9 | -1.2 to +22.9 |
#### Haiku 4.5 efforts

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
#### Haiku 5.5 efforts

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
#### Luna efforts

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
#### Opus efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5 vs claude-opus-5-5-high | 9/20 = 45.0% | 47.8% | -2.8 | -19.8 to +13.3 |
| claude-opus-5-5 vs claude-opus-5-5-low | 13/20 = 65.0% | 63.8% | +1.2 | -9.9 to +11.6 |
| claude-opus-5-5 vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 35.1% | -0.1 | -13.7 to +13.8 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 37.1% | -2.1 | -17.7 to +13.0 |
#### Sol efforts

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
#### Sonnet efforts

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
#### Terra efforts

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

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| Cross-model | 0.6210 | 0.6211 | -0.0001 | -0.0002 to -0.0000 | 0: 48, 0.1: 1, 0.2: 1 | tau=0.1: 0.6213, tau=0.2: 0.6221, tau=0.4: 0.6248, tau=0.8: 0.6307, tau=1.6: 0.6367 | not kept |
| Cross-model (seat and starter terms) | 0.6008 | 0.6008 | +0.0000 | +0.0000 to +0.0000 | 0: 50 | tau=0.1: 0.6011, tau=0.2: 0.6018, tau=0.4: 0.6045, tau=0.8: 0.6108, tau=1.6: 0.6185 | not kept |
| Haiku 4.5 efforts | 0.6716 | 0.6770 | -0.0054 | -0.0121 to +0.0002 | 0: 18, 0.1: 2, 0.2: 12, 0.4: 17, 0.8: 1 | tau=0.1: 0.6715, tau=0.2: 0.6714, tau=0.4: 0.6728, tau=0.8: 0.6788, tau=1.6: 0.6850 | not kept |
| Haiku 4.5 efforts (seat and starter terms) | 0.6757 | 0.6818 | -0.0060 | -0.0119 to -0.0006 | 0: 22, 0.1: 1, 0.2: 13, 0.4: 12, 0.8: 2 | tau=0.1: 0.6757, tau=0.2: 0.6760, tau=0.4: 0.6783, tau=0.8: 0.6855, tau=1.6: 0.6923 | not kept |
| Haiku 5.5 efforts | 0.6626 | 0.6629 | -0.0004 | -0.0007 to -0.0000 | 0: 43, 0.1: 1, 0.2: 6 | tau=0.1: 0.6630, tau=0.2: 0.6642, tau=0.4: 0.6685, tau=0.8: 0.6769, tau=1.6: 0.6838 | not kept |
| Haiku 5.5 efforts (seat and starter terms) | 0.6409 | 0.6417 | -0.0008 | -0.0015 to -0.0002 | 0: 45, 0.1: 1, 0.2: 3, 0.4: 1 | tau=0.1: 0.6412, tau=0.2: 0.6421, tau=0.4: 0.6456, tau=0.8: 0.6531, tau=1.6: 0.6595 | not kept |
| Luna efforts | 0.5743 | 0.5774 | -0.0030 | -0.0061 to -0.0003 | 0: 29, 0.1: 4, 0.2: 7, 0.4: 10 | tau=0.1: 0.5744, tau=0.2: 0.5748, tau=0.4: 0.5774, tau=0.8: 0.5854, tau=1.6: 0.5957 | not kept |
| Luna efforts (seat and starter terms) | 0.5768 | 0.5805 | -0.0036 | -0.0069 to -0.0006 | 0: 23, 0.1: 7, 0.2: 8, 0.4: 12 | tau=0.1: 0.5770, tau=0.2: 0.5777, tau=0.4: 0.5809, tau=0.8: 0.5902, tau=1.6: 0.6018 | not kept |
| Opus efforts | 0.6909 | 0.6946 | -0.0037 | -0.0076 to -0.0010 | 0: 43, 0.2: 4, 0.4: 1, 0.8: 1, 1.6: 1 | tau=0.1: 0.6915, tau=0.2: 0.6931, tau=0.4: 0.6974, tau=0.8: 0.7033, tau=1.6: 0.7070 | not kept |
| Opus efforts (seat and starter terms) | 0.7016 | 0.7065 | -0.0049 | -0.0089 to -0.0017 | 0: 46, 0.8: 3, 1.6: 1 | tau=0.1: 0.7022, tau=0.2: 0.7037, tau=0.4: 0.7077, tau=0.8: 0.7133, tau=1.6: 0.7169 | not kept |
| Sol efforts | 0.7039 | 0.7058 | -0.0019 | -0.0082 to +0.0036 | 0: 18, 0.1: 5, 0.2: 8, 0.4: 19 | tau=0.1: 0.7036, tau=0.2: 0.7030, tau=0.4: 0.7032, tau=0.8: 0.7072, tau=1.6: 0.7117 | not kept |
| Sol efforts (seat and starter terms) | 0.7082 | 0.7116 | -0.0034 | -0.0100 to +0.0030 | 0: 16, 0.1: 2, 0.2: 9, 0.4: 23 | tau=0.1: 0.7081, tau=0.2: 0.7082, tau=0.4: 0.7104, tau=0.8: 0.7175, tau=1.6: 0.7241 | not kept |
| Sonnet efforts | 0.6732 | 0.6749 | -0.0017 | -0.0061 to +0.0027 | 0: 14, 0.1: 7, 0.2: 17, 0.4: 11, 0.8: 1 | tau=0.1: 0.6728, tau=0.2: 0.6719, tau=0.4: 0.6721, tau=0.8: 0.6778, tau=1.6: 0.6850 | not kept |
| Sonnet efforts (seat and starter terms) | 0.6740 | 0.6754 | -0.0014 | -0.0071 to +0.0039 | 0: 8, 0.1: 4, 0.2: 16, 0.4: 22 | tau=0.1: 0.6736, tau=0.2: 0.6731, tau=0.4: 0.6741, tau=0.8: 0.6813, tau=1.6: 0.6895 | not kept |
| Terra efforts | 0.6937 | 0.6945 | -0.0008 | -0.0022 to +0.0005 | 0: 36, 0.1: 6, 0.2: 5, 0.4: 3 | tau=0.1: 0.6939, tau=0.2: 0.6945, tau=0.4: 0.6974, tau=0.8: 0.7040, tau=1.6: 0.7099 | not kept |
| Terra efforts (seat and starter terms) | 0.6948 | 0.6969 | -0.0020 | -0.0034 to -0.0007 | 0: 37, 0.1: 3, 0.2: 9, 0.4: 1 | tau=0.1: 0.6953, tau=0.2: 0.6966, tau=0.4: 0.7012, tau=0.8: 0.7100, tau=1.6: 0.7170 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| Cross-model | 90/174 = 51.7% | -0.17 |
| Haiku 4.5 efforts | 7/10 = 70.0% | +0.05 |
| Haiku 5.5 efforts | 5/15 = 33.3% | -0.44 |
| Luna efforts | 7/15 = 46.7% | -0.09 |
| Opus efforts | 0/4 = 0.0% | -0.99 |
| Sol efforts | 6/10 = 60.0% | -0.18 |
| Sonnet efforts | 6/15 = 40.0% | -0.04 |
| Terra efforts | 4/10 = 40.0% | -0.15 |
| all cohorts pooled | 125/253 = 49.4% | -0.17 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 5.6e-17, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 2471 of 2471 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 1235 blocks, 29 seeds (1 matches in half blocks left out) | 1245/2470 = 50.4% | 43.2% to 57.8% | 48.4% to 52.3% |
| Cross-model: 445 blocks, 29 seeds (1 matches in half blocks left out) | 427/890 = 48.0% | 39.8% to 57.2% | 44.7% to 51.1% |
| Haiku 4.5 efforts: 100 blocks, 10 seeds | 105/200 = 52.5% | 42.5% to 60.0% | 45.5% to 59.0% |
| Haiku 5.5 efforts: 150 blocks, 10 seeds | 142/300 = 47.3% | 34.3% to 60.0% | 41.3% to 53.0% |
| Luna efforts: 150 blocks, 10 seeds | 160/300 = 53.3% | 46.7% to 59.3% | 48.7% to 58.0% |
| Opus efforts: 40 blocks, 10 seeds | 42/80 = 52.5% | 33.8% to 71.2% | 40.0% to 65.0% |
| Sol efforts: 100 blocks, 10 seeds | 111/200 = 55.5% | 43.5% to 68.5% | 48.0% to 63.0% |
| Sonnet efforts: 150 blocks, 10 seeds | 162/300 = 54.0% | 43.3% to 64.3% | 48.7% to 59.3% |
| Terra efforts: 100 blocks, 10 seeds | 96/200 = 48.0% | 36.5% to 58.5% | 40.5% to 55.0% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 1411/2470 = 57.1% | 50.7% to 63.5% | 55.1% to 59.1% | 583/1235 |
| Cross-model | 533/890 = 59.9% | 52.3% to 66.8% | 56.7% to 62.9% | 188/445 |
| Haiku 4.5 efforts | 115/200 = 57.5% | 50.0% to 66.0% | 50.5% to 64.0% | 50/100 |
| Haiku 5.5 efforts | 186/300 = 62.0% | 51.7% to 72.0% | 56.3% to 68.0% | 75/150 |
| Luna efforts | 152/300 = 50.7% | 44.7% to 57.3% | 46.0% to 55.7% | 75/150 |
| Opus efforts | 46/80 = 57.5% | 40.0% to 75.0% | 46.2% to 68.8% | 20/40 |
| Sol efforts | 107/200 = 53.5% | 41.0% to 66.5% | 46.0% to 61.0% | 50/100 |
| Sonnet efforts | 164/300 = 54.7% | 43.0% to 64.3% | 49.0% to 60.3% | 75/150 |
| Terra efforts | 108/200 = 54.0% | 43.0% to 64.5% | 47.0% to 61.0% | 50/100 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +0.8 | -5.7 to +7.3 | -1.2 to +2.7 | +7.2 | +0.3 to +13.7 | +5.2 to +9.1 |
| Cross-model | -0.5 | -7.6 to +8.0 | -3.5 to +2.6 | +9.8 | +1.7 to +17.5 | +6.6 to +12.9 |
| Haiku 4.5 efforts | +2.5 | -6.9 to +9.5 | -4.5 to +9.3 | +7.5 | +0.9 to +17.0 | +0.6 to +14.3 |
| Haiku 5.5 efforts | -2.7 | -14.3 to +7.8 | -8.3 to +2.9 | +12.0 | +1.0 to +22.7 | +6.4 to +17.9 |
| Luna efforts | +3.3 | -3.3 to +9.6 | -1.4 to +8.1 | +0.7 | -5.6 to +7.3 | -4.0 to +5.7 |
| Opus efforts | +2.5 | -16.1 to +21.7 | -9.5 to +14.3 | +7.5 | -11.3 to +26.0 | -4.2 to +18.6 |
| Sol efforts | +5.5 | -7.5 to +18.8 | -2.0 to +13.0 | +3.5 | -9.9 to +16.7 | -3.8 to +10.8 |
| Sonnet efforts | +4.0 | -7.5 to +14.7 | -1.4 to +9.3 | +4.7 | -7.2 to +14.7 | -1.1 to +10.2 |
| Terra efforts | -2.0 | -14.2 to +8.8 | -9.8 to +5.1 | +4.0 | -7.8 to +15.3 | -2.9 to +11.2 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| claude-haiku-4-5-20251001: 208 blocks, 19 seeds | 206/416 = 49.5% | 42.8% to 56.1% | 45.0% to 53.8% |
| claude-haiku-5-5: 264 blocks, 19 seeds | 249/528 = 47.2% | 37.6% to 56.9% | 42.8% to 51.7% |
| claude-opus-5-5: 159 blocks, 29 seeds | 160/318 = 50.3% | 39.6% to 61.8% | 44.7% to 56.0% |
| claude-sonnet-5-5: 263 blocks, 19 seeds | 267/526 = 50.8% | 42.5% to 59.1% | 46.6% to 54.9% |
| gpt-5.6-terra: 208 blocks, 19 seeds | 217/416 = 52.2% | 43.1% to 61.5% | 47.1% to 57.0% |
| gpt-6-astra: 109 blocks, 29 seeds | 105/218 = 48.2% | 37.9% to 60.5% | 41.7% to 54.6% |
| gpt-6-luna: 261 blocks, 19 seeds | 260/522 = 49.8% | 44.9% to 54.6% | 46.4% to 53.4% |
| gpt-6.1-sol: 208 blocks, 19 seeds | 208/416 = 50.0% | 40.7% to 60.1% | 45.0% to 55.3% |

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
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 38.5% to 69.0% | 52.4% | 38.1% to 69.0% | +25 (-81 to +132) | 6 / 10 / 4 |
| 40 matches, 20 complete seed pairs | 22/40 = 55.0% | 40.0% to 70.0% | 55.0% | 40.0% to 70.0% | +35 (-70 to +146) | 6 / 10 / 4 |

The 41-match estimate adds seed 3030's one scored match, which Astra won, to the 40 matches of complete pairs.

#### Matched against Opus medium vs Astra on the same seeds (tournament 1)

| matched seeds | Opus xhigh wins | Opus medium wins | difference in share (95% CI, seeds drawn) |
|---|---|---|---|
| 10 seeds, 20 matches each | 10/20 | 9/20 | +5.0 pp (-15.0 to +25.0) |

The matched seeds are 3000 to 3009, so the matched estimate is the same whether tournament 3 counts 40 or 41 matches.
<!-- tables:end -->
