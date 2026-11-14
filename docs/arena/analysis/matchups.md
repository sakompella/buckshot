# Matchup analysis

Ratings, pair effects, seat and round 1 starter effects for the scored arena matches, from the analysis database ([database.md](../database.md)). All scored matches are two-player. Every rate shows numerator/denominator, a win share counts a split by its share, and every interval is a bootstrap that draws whole units, never single matches or seat swaps: seed blocks (the two seat-swapped matches of one pair and seed) for ratings, and seeds (every block played at a seed, in any pairing) for the headline seat and starter figures. Rating intervals are 90% (about one in ten true values falls outside); the other intervals are 95%. The tables below the line "Tables" are generated: `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` rewrites them, with a fixed RNG seed. Nothing here reads provenance or account data.

**DeepSeek is left out.** Every match with deepseek-v4.1-flash (20 scored matches) is dropped from all cohorts, fits, seat and starter figures and tables, because its free tier refused requests, so its games are not a random sample of what was scheduled. That leaves 3,537 scored matches from the 3,557-match snapshot of 2026-11-04. Every finding below uses these.

## Findings

**Ratings are pooled.** One Bradley-Terry fit covers every scored match of every tournament, so all 49 configs share one Elo scale with the depth-7 search engine (Engine/7/2000000/sampled) at 0, as in the viewer, so a new config does not move the others. Tournament 4 gave every older config games against other models, so no rating leans on an assumption that effort gaps carry across opponents. The 13 newest configs have 80 matches each against changing opponents, so their intervals are 205 to 234 Elo wide. `results.md` and the viewer rank by the luck-adjusted Round Elo (see below); the match ratings here are a derived view of the same results, about 1.6 times as wide. A second fit on pot share (a config's cash over the match's cash, which credits the round prizes a loser banks) gives the cash rating. Cohorts are only a way to group matches. A cohort is one kind of comparison, pooled over every tournament: Cross-model (every match between different models) or one model's efforts (every match of that model against itself), as in the viewer. There are ten: Cross-model and the efforts of Astra, Haiku 4.5, Haiku 5.5, Luna, Opus, Sol, Sonnet, Terra and Terra 6.1.
- **Coverage.** The Cross-model cohort has 49 entrants and 1,860 matches over 477 of the 1,176 pairs, 1 to 41 matches per pair. Each older effort cohort is a round robin with 20 matches per pair. Opus efforts plays all 15 pairs (2 to 20 matches each), Terra 6.1 efforts all 15 (1 to 3 matches each) and Astra efforts 5 of 6 (1 to 2 matches each). Tournament 5 is finished; the scheduled matches it did not play stay unstarted in the table below.
- **Cross-model medium configs**, win rating (95% CI by seed blocks): astra +190 (+110 to +278), opus +117 (+41 to +196), sol +107 (+26 to +196), haiku 5.5 +48 (-26 to +128), sonnet +45 (-29 to +131), terra -19 (-104 to +68), haiku 4.5 -145 (-225 to -64), luna -219 (-317 to -126). Astra leads and luna and haiku 4.5 trail; neighbouring intervals overlap. Drawing seeds instead of blocks moves the intervals modestly.
- **Top and bottom.** Every config has 80 or more matches. Opus max +258 (+155 to +387), Terra 6.1 max +243 (+137 to +360), Astra high +220 (+118 to +352), Sonnet max +213 (+119 to +321) and Opus xhigh +209 (+122 to +308) lead, and their intervals overlap. Haiku 4.5 off -342, luna low -304 and luna off -299 trail. Intervals are 154 to 258 Elo wide.
- **Effort.** Within each model the top level is xhigh or max in every model with a sweep or effort tournament, Opus included: luna xhigh +16 and max -1 against medium -219, sonnet max +213 against medium +45, haiku 5.5 max +115 (xhigh +104) against medium +48, terra xhigh +49 (max +44) against medium -19, sol max +184 against medium +107, Opus max +258 and xhigh +209 against medium +117, Terra 6.1 max +243 and xhigh +198 against medium +145. Haiku 4.5 has no such level; its top is medium (-145) and minimal (-188). Off or low is the bottom level in the older sweeps: luna low -304, haiku 4.5 off -342, haiku 5.5 off -95, sonnet low -27, terra low -51 and Opus low +32. Opus off (+149, 80 matches, +48 to +263) is above medium. Sol is the exception: high +101 sits at the bottom of a range up to +184 (medium +107), and the intervals overlap. Terra 6.1 runs max +243, xhigh +198, medium +145, off +133, high +127, low +90, and every effort has an interval 217 to 231 Elo wide. The order of neighbouring levels is mostly inside the intervals.
- **Cash.** Cash ratings spread less than win ratings among configs with 80 or more matches (+149 to -193 against +258 to -342), because losers bank round prizes. The two ratings agree on the leaders (Terra 6.1 max +149, Opus max +146, Astra high +145) and the trailers (luna low -193, haiku 4.5 off -186). A config can win less than it earns: Opus low wins 41.2% of its 80 matches yet takes 49.4% of the pot (cash +51, win +32), and terra high wins 44.0% and takes 49.5% (cash +25, win -34). Haiku 5.5 xhigh is the reverse: 54.4% of wins, 50.4% of the pot, cash +42 against win +104.

**Matchup effects: none worth keeping.** The observed pair share minus the share fitted by the pooled ratings is small and is reported as a descriptive residual. It is not a test: the ratings are regularized, so residuals are forced (a pair at the end of a chain of pairs is pulled to its fit), and the bootstrap range around a residual is not a calibrated interval around zero. The largest Cross-model residual over a pair of 20 matches or more is haiku 4.5 against opus (+18.6 points). Pairs of 2 matches are too thin to read.
- The test is held-out prediction. Whole seed blocks were held out (5 repeats of 10-fold cross-validation, with the shrinkage chosen inside each training set from 0 to 1.6, so no held-out block picks it). Pair effects are fitted only for pairs seen in more than one seed block: a pair confined to one block has no training data when that block is held out, so its games still count in the test score but it gets no pair term. Astra efforts has 7 seed blocks, under the minimum of 10 this test needs (the fit with seat and starter terms can be singular on so few), so it is not tested. In every other cohort the nested pair-effect model scored no better than ratings alone: the gain per match is between -0.0244 and -0.0003 nats, and the lower end of its interval is never above 0. The shrinkage chose 0 (ratings only) in most folds for Cross-model, Haiku 5.5, Luna, Opus and Terra. So **no tested cohort keeps pair effects**. Cross-model holds tournament 4's one-block pairs, tournament 5's and the 41-match Opus xhigh against Astra pair.
- The same holds when the ratings also have a seat term and a round 1 starter term, which on their own lower the Cross-model loss from 0.5858 to 0.5767 per match.
- Reverse pairs, described and not tested: for the entrant seated first, a real matchup effect should show the opposite sign when A sat first and when B sat first. 233 of 414 pairs (56.3%) do, with a correlation of -0.10 between the A-first effect and minus the B-first effect (a negative value means the two orders lean the same way). The signs are not independent (the two orders of a block share a seed, seeds are reused across pairings, and the ratings are fitted jointly), so no test is made. The two entrants' effects in a pair sum to zero to rounding (1.3e-16) because every match's shares sum to 1.
- With 20 matches per pair in the effort cohorts and 2 in most of Cross-model, only large pair effects could show.

**Seat and starter.** Whoever opens round 1 (read from the public line `Round 1 begins ... Player X starts.` of each match's events) also fired the first shot in 3537 of 3537 matches. The seed decides that position, and both matches of a block share it.
- **Position 1:** 1392/2784 = 50.0% over 1,392 complete blocks at 128 seeds (95% CI by seeds 43.8% to 56.6%; by seed blocks 48.1% to 51.9%). Cross-model 544/1150 = 47.3% (40.2% to 54.3% by seeds).
- **Starter:** the player who opens round 1 won 1578/2784 = 56.7% (50.8% to 62.3% by seeds; 54.9% to 58.5% by seed blocks). The overall starter association stands: it is about 7 points above even.
- **Split:** the position and starter effects below are a descriptive additive split of block shares by which position starts. Every complete-block seed has exactly one starter position, so a starter effect cannot be told from a seed effect. The split describes these seed blocks; only the seeds-drawn intervals reach beyond them. Starter +6.7 points overall (seeds +0.5 to +12.6; blocks +4.9 to +8.5), +7.9 Cross-model (+1.6 to +13.3; blocks +5.2 to +10.6). Position +0.2 overall (-5.8 to +5.8 by seeds).
- **It depends on the seed.** The starter won 173/244 = 70.9% of matches at seed 3000 and 28/74 = 37.8% at seed 3005. Counting each of the 19 seeds with 10 or more blocks once, the starter's mean share is 57.7% (51.7% to 63.8%, seeds drawn). Starter figures are therefore not reported per model: a model's blocks cover a handful of seeds, so they say as much about those seeds as about the model. Position 1 per model is in the tables.
- **Recommendation:** a starter term is worth keeping as an option for future ratings. It lowers held-out loss a lot (Cross-model 0.5858 to 0.5767 per match) and moves the pooled ratings by up to 17.4 Elo. The headline fits stay without it.

**Tournament 3 (Opus xhigh against Astra medium).**
- **41 matches** (21 seed blocks, seed 3030 half): Opus 22/41 = 53.7% (39.0% to 68.3%); Elo gap +25 (-84 to +132), in a fit of the two alone.
- **40 matches** (20 complete seed pairs): Opus 22/40 = 55.0% (40.0% to 70.0%); gap +35 (-70 to +146). Opus won both matches on 6 seeds, split on 10 and lost both on 4.
- **Matched with Opus medium against Astra** on seeds 3000 to 3009, which is the same for 40 and 41 matches: 10/20 against 9/20, +5.0 points (-15.0 to +25.0, seeds drawn).
- Inconclusive either way, as `results.md` says.

## Method
- **Ratings:** the first-seated entrant wins with probability 1/(1 + exp(-(theta_first - theta_second))), and a share w counts as w wins and 1 - w losses. One fit covers every scored match of every tournament. A mean-zero Gaussian prior on theta (standard deviation 3) regularizes the fit; it also shrinks rating differences slightly. Ratings are reported on the Elo scale with the depth-7 search engine (Engine/7/2000000/sampled) at 0, which is what `web/src/arena-viewer/page/ratings.ts` computes. The win rating counts win shares; the cash rating is the same fit on pot shares. Intervals draw seed blocks 2,000 times, refitting each draw, as the viewer does. Each draw is centred on the mean entrant and moved by the point fit's shift, so an interval leaves out the engine's own noise; the engine's interval is the uncertainty of the 0.
- **Observed against fitted:** for each pair in a cohort, the observed share of the alphabetically first entrant minus the sum of its pooled-fit win probabilities over the pair's matches, as a share, with each resample refitted. Descriptive only (see above).
- **Pair effects:** a term delta per pair with a prior of standard deviation tau, tau in {0 (ratings only), 0.1, 0.2, 0.4, 0.8, 1.6}, fitted within a cohort. Scored by mean log loss on held-out blocks (5 repeats of 10-fold cross-validation); the nested row picks tau by 5-fold cross-validation inside each training set. The verdict needs the lower end of the 95% interval of the gain (drawn over blocks) above 0.
- **Seat and starter:** for a complete block, position 1's share is the mean over its two matches, which cancels who the entrants are. The starter's share is taken the same way. The two effects are the position and starter terms of an additive split of those block shares by which position starts, weighting the two starts equally. Headline intervals draw seeds.

## Limits
- **Shared seeds.** The seed block id includes the pairing, but every pairing of a tournament plays the same seeds (tournament 1's cross-model games use 10 seeds, each sweep 10, tournament 4 the same 10, tournament 5 mostly its own seeds from 4000 up with one block each), so blocks of different pairings share deals. Seed-block intervals therefore understate the uncertainty of position and starter effects, which is why the seeds-drawn interval is the headline there (about 10 to 19 well-filled seeds plus many one-block seeds, so it is rough). Rating intervals hardly change.
- **Unmatched blocks.** Half blocks (753 matches, 710 of them Cross-model) cannot be matched and are left out of every seat figure.
- **Power.** The held-out test can rule out large pair effects only; "none kept" is not "none exist". Terra 6.1 efforts (7 complete blocks) is the weakest cohort tested, and Astra efforts has too few blocks to test.
- **Thin cells.** Tournament 4 has one seat-swapped block (2 matches) per pair, so one pair says little; its value is that it links every config to the others. Sonnet max's cross-model rating rests on 8 tournament-4 matches, 2 tournament-1 games and the 30 top-four matches of tournament 5.
- **Position and starter overlap** because the seed fixes the starter's position, and tournament 1's seeds 3000 to 3009 start position 2 six times in ten.
- **No replays.** Everything comes from standings, cash, seating and the public round 1 line; no moves were reviewed.

## Tables

<!-- tables:start -->
### Schedule coverage

| cohort | entrants | scored matches | complete / half blocks | pairs played | matches per pair min / median / max | connected | scheduled by status |
|---|---|---|---|---|---|---|---|
| Cross-model | 48 | 4432 | 1861 / 710 | 444/1128 | 1 / 3 / 1040 | yes | 3312 completed, 2 partial, 5 partial (skipped), 138 skipped (skipped), 973 unstarted |
| claude-haiku-4-5-20251001 efforts | 4 | 200 | 100 / 0 | 7/6 | 20 / 20 / 40 | yes | 200 completed |
| claude-haiku-5-5 efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| claude-opus-5-5 efforts | 5 | 137 | 58 / 21 | 11/10 | 2 / 10 / 24 | yes | 137 completed, 21 unstarted |
| claude-sonnet-5-5 efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| gpt-5.6-terra efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| gpt-6-astra efforts | 4 | 9 | 2 / 5 | 5/6 | 1 / 2 / 2 | yes | 9 completed, 13 unstarted |
| gpt-6-luna efforts | 5 | 300 | 150 / 0 | 11/10 | 20 / 20 / 40 | yes | 300 completed |
| gpt-6.1-sol efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| gpt-6.1-terra efforts | 5 | 31 | 7 / 17 | 11/10 | 1 / 3 / 6 | yes | 31 completed, 33 unstarted |

### Pooled ratings

| config | wins/matches = win share | rating (Elo, depth-7 engine at 0) | 90% CI, seed blocks drawn | 90% CI, seeds drawn (sensitivity) | pot share | cash rating (Elo, depth-7 engine at 0) | 90% CI, seed blocks drawn |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5-max | 59/82 = 72.0% | +27 | -36 to +105 | -41 to +116 | 63.2% | +10 | -26 to +48 |
| gpt-6.1-terra-max | 68/100 = 68.0% | +10 | -51 to +76 | -49 to +74 | 62.4% | +10 | -24 to +45 |
| gpt-6-astra-high | 68/100 = 68.0% | +2 | -55 to +63 | -55 to +67 | 64.0% | +17 | -12 to +48 |
| Engine/7/2000000/sampled | 829/1120 = 74.0% | +0 | -28 to +27 | -29 to +28 | 65.3% | +0 | -14 to +14 |
| claude-sonnet-5-5-max | 96/142 = 67.6% | -1 | -54 to +56 | -71 to +82 | 62.6% | +8 | -22 to +37 |
| Engine/6/20000/sampled | 127/236 = 53.8% | -16 | -52 to +23 | -51 to +23 | 52.8% | -4 | -23 to +17 |
| claude-opus-5-5-xhigh | 89/170 = 52.4% | -26 | -70 to +21 | -68 to +21 | 52.4% | -7 | -30 to +15 |
| gpt-6-astra-medium | 169/254 = 66.5% | -30 | -63 to +6 | -62 to +6 | 60.2% | -17 | -35 to +2 |
| gpt-6.1-sol-max | 80/142 = 56.3% | -33 | -75 to +9 | -78 to +15 | 54.5% | -4 | -27 to +19 |
| gpt-6.1-terra-xhigh | 71/102 = 69.6% | -35 | -91 to +27 | -90 to +26 | 60.2% | -42 | -74 to -9 |
| claude-opus-5-5-high | 47/80 = 58.8% | -42 | -105 to +28 | -114 to +33 | 54.7% | -28 | -66 to +11 |
| claude-sonnet-5-5-xhigh | 105/176 = 59.7% | -50 | -92 to -4 | -101 to +8 | 53.7% | -47 | -69 to -24 |
| gpt-6.1-terra-medium | 87/130 = 66.9% | -57 | -106 to -3 | -109 to -1 | 59.8% | -43 | -71 to -15 |
| gpt-6-astra-low | 52/80 = 65.0% | -59 | -121 to +9 | -122 to +9 | 59.4% | -40 | -72 to -6 |
| gpt-6-astra-off | 51/80 = 63.7% | -80 | -146 to -9 | -144 to -5 | 55.9% | -72 | -106 to -39 |
| gpt-6.1-sol-low | 51/98 = 52.0% | -87 | -148 to -25 | -141 to -26 | 50.9% | -41 | -72 to -8 |
| gpt-6.1-sol-xhigh | 52/101 = 51.5% | -91 | -145 to -34 | -144 to -35 | 52.4% | -33 | -63 to -1 |
| claude-opus-5-5-medium | 188/334 = 56.3% | -96 | -127 to -64 | -124 to -63 | 53.8% | -55 | -71 to -39 |
| gpt-6.1-terra-high | 51/82 = 62.2% | -109 | -177 to -33 | -180 to -35 | 59.1% | -59 | -94 to -20 |
| gpt-6.1-sol-medium | 155/271 = 57.2% | -110 | -145 to -73 | -156 to -59 | 56.8% | -45 | -64 to -25 |
| claude-haiku-5-5-max | 68/111 = 61.3% | -111 | -163 to -58 | -176 to -36 | 58.7% | -59 | -83 to -34 |
| gpt-6.1-sol-high | 47/99 = 47.5% | -116 | -169 to -62 | -175 to -61 | 48.0% | -59 | -90 to -28 |
| claude-haiku-5-5-xhigh | 86/158 = 54.4% | -122 | -164 to -77 | -171 to -81 | 50.4% | -92 | -113 to -68 |
| gpt-6.1-terra-off/low | 145/242 = 59.9% | -125 | -164 to -86 | -163 to -89 | 55.3% | -84 | -103 to -65 |
| claude-opus-5-5-off/low | 83/160 = 51.9% | -137 | -182 to -88 | -184 to -89 | 54.1% | -64 | -89 to -39 |
| claude-sonnet-5-5-high | 75/161 = 46.6% | -145 | -196 to -91 | -195 to -97 | 46.9% | -96 | -123 to -68 |
| claude-haiku-5-5-high | 118/223 = 52.9% | -149 | -188 to -109 | -186 to -112 | 50.8% | -98 | -119 to -77 |
| claude-haiku-5-5-medium | 229/444 = 51.6% | -165 | -191 to -139 | -189 to -143 | 50.6% | -101 | -114 to -87 |
| claude-sonnet-5-5-medium | 175/364 = 48.1% | -169 | -200 to -137 | -209 to -131 | 48.8% | -100 | -116 to -84 |
| gpt-5.6-terra-xhigh | 53/93 = 57.0% | -170 | -236 to -103 | -241 to -109 | 55.1% | -69 | -102 to -37 |
| gpt-5.6-terra-max | 52/90 = 57.8% | -175 | -247 to -105 | -230 to -120 | 53.8% | -82 | -117 to -46 |
| gpt-6-luna-xhigh | 79/115 = 68.7% | -187 | -246 to -128 | -231 to -141 | 63.6% | -100 | -133 to -66 |
| claude-sonnet-5-5-off | 65/164 = 39.6% | -194 | -240 to -147 | -241 to -152 | 42.4% | -126 | -150 to -100 |
| claude-haiku-5-5-low | 137/278 = 49.3% | -194 | -232 to -158 | -230 to -159 | 51.0% | -109 | -128 to -90 |
| Engine/2/20000 | 1056/2334 = 45.2% | -197 | -220 to -175 | -221 to -175 | 47.3% | -118 | -130 to -107 |
| gpt-6-luna-max | 75/112 = 67.0% | -203 | -261 to -140 | -254 to -153 | 63.2% | -104 | -138 to -69 |
| gpt-5.6-terra-medium | 119/259 = 45.9% | -234 | -273 to -200 | -273 to -196 | 48.0% | -123 | -141 to -105 |
| gpt-6-luna-high | 116/218 = 53.2% | -242 | -291 to -194 | -292 to -191 | 51.6% | -147 | -170 to -124 |
| claude-sonnet-5-5-low | 50/159 = 31.4% | -247 | -304 to -197 | -297 to -202 | 39.5% | -143 | -171 to -116 |
| gpt-5.6-terra-high | 40/91 = 44.0% | -252 | -318 to -189 | -306 to -207 | 49.5% | -105 | -139 to -71 |
| gpt-5.6-terra-low | 37/91 = 40.7% | -270 | -341 to -209 | -332 to -210 | 45.5% | -127 | -163 to -95 |
| claude-haiku-5-5-off | 221/668 = 33.1% | -328 | -358 to -301 | -357 to -302 | 38.4% | -204 | -219 to -190 |
| claude-haiku-4-5-20251001-medium | 123/358 = 34.4% | -362 | -396 to -329 | -403 to -330 | 38.6% | -218 | -236 to -201 |
| claude-haiku-4-5-20251001-minimal/low | 112/292 = 38.4% | -409 | -455 to -370 | -455 to -372 | 42.2% | -236 | -260 to -216 |
| gpt-6-luna-medium | 101/398 = 25.4% | -421 | -462 to -387 | -458 to -388 | 33.9% | -246 | -265 to -230 |
| claude-haiku-4-5-20251001-high | 47/135 = 34.8% | -453 | -512 to -400 | -530 to -390 | 42.0% | -247 | -275 to -222 |
| gpt-6-luna-off/low | 77/396 = 19.4% | -503 | -551 to -462 | -553 to -463 | 28.7% | -302 | -325 to -281 |
| claude-haiku-4-5-20251001-off | 28/125 = 22.4% | -561 | -633 to -497 | -649 to -492 | 32.6% | -317 | -346 to -289 |

With a seat term and a round 1 starter term in the fit (position 1 +23 Elo, the starter +36 Elo) the largest rating change is 11.0 Elo.


### Observed pairs against the pooled ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below. Every resample refits the pooled ratings.

#### Cross-model

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| Engine/2/20000 vs Engine/7/2000000/sampled | 250/1040 = 24.0% | 24.3% | -0.3 | -0.8 to +0.3 |
| Engine/2/20000 vs claude-haiku-4-5-20251001-medium | 9/18 = 50.0% | 72.1% | -22.1 | -45.1 to +0.8 |
| Engine/2/20000 vs claude-haiku-5-5-high | 21/50 = 42.0% | 43.1% | -1.1 | -13.2 to +11.3 |
| Engine/2/20000 vs claude-haiku-5-5-low | 45/84 = 53.6% | 49.6% | +3.9 | -4.8 to +12.8 |
| Engine/2/20000 vs claude-haiku-5-5-medium | 35/82 = 42.7% | 45.4% | -2.7 | -11.8 to +6.3 |
| Engine/2/20000 vs claude-haiku-5-5-off | 320/466 = 68.7% | 68.0% | +0.6 | -1.2 to +2.4 |
| Engine/2/20000 vs claude-opus-5-5-medium | 8/20 = 40.0% | 35.8% | +4.2 | -14.6 to +22.9 |
| Engine/2/20000 vs claude-sonnet-5-5-medium | 10/20 = 50.0% | 45.9% | +4.1 | -15.9 to +24.4 |
| Engine/2/20000 vs gpt-6-luna-high | 57/106 = 53.8% | 56.4% | -2.6 | -8.5 to +3.4 |
| Engine/2/20000 vs gpt-6-luna-medium | 89/116 = 76.7% | 78.4% | -1.7 | -7.5 to +3.7 |
| Engine/2/20000 vs gpt-6-luna-off/low | 156/176 = 88.6% | 85.4% | +3.3 | -0.6 to +6.9 |
| Engine/2/20000 vs gpt-6.1-terra-high | 2/2 = 100.0% | 37.6% | +62.4 | +49.6 to +73.3 |
| Engine/2/20000 vs gpt-6.1-terra-medium | 13/50 = 26.0% | 30.8% | -4.8 | -14.6 to +5.2 |
| Engine/2/20000 vs gpt-6.1-terra-off/low | 34/82 = 41.5% | 39.8% | +1.7 | -5.8 to +9.5 |
| Engine/2/20000 vs gpt-6.1-terra-xhigh | 7/22 = 31.8% | 28.2% | +3.6 | -10.7 to +19.7 |
| Engine/6/20000/sampled vs Engine/7/2000000/sampled | 41/80 = 51.2% | 47.6% | +3.6 | -3.8 to +10.7 |
| Engine/6/20000/sampled vs claude-haiku-5-5-medium | 10/20 = 50.0% | 70.2% | -20.2 | -35.6 to -5.2 |
| Engine/6/20000/sampled vs claude-opus-5-5-medium | 13/20 = 65.0% | 61.2% | +3.8 | -16.3 to +23.0 |
| Engine/6/20000/sampled vs claude-opus-5-5-xhigh | 13/20 = 65.0% | 51.4% | +13.6 | -6.3 to +33.5 |
| Engine/6/20000/sampled vs claude-sonnet-5-5-medium | 14/20 = 70.0% | 70.6% | -0.6 | -16.5 to +14.8 |
| Engine/6/20000/sampled vs claude-sonnet-5-5-xhigh | 7/16 = 43.8% | 54.8% | -11.1 | -33.0 to +9.9 |
| Engine/6/20000/sampled vs gpt-6-astra-high | 9/20 = 45.0% | 47.4% | -2.4 | -20.0 to +14.0 |
| Engine/6/20000/sampled vs gpt-6.1-sol-max | 10/20 = 50.0% | 52.4% | -2.4 | -20.4 to +15.8 |
| Engine/6/20000/sampled vs gpt-6.1-terra-max | 10/20 = 50.0% | 46.2% | +3.8 | -14.6 to +22.3 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-high | 0/1 = 0.0% | 14.8% | -14.8 | -21.0 to -9.5 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-max | 0/1 = 0.0% | 12.2% | -12.2 | -18.6 to -7.4 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-medium | 0/1 = 0.0% | 16.0% | -16.0 | -22.5 to -10.8 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-off | 2/10 = 20.0% | 32.8% | -12.8 | -35.7 to +14.7 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-xhigh | 0/1 = 0.0% | 13.0% | -13.0 | -18.8 to -8.1 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-max | 0/2 = 0.0% | 5.9% | -5.9 | -10.0 to -3.0 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-off/low | 1/3 = 33.3% | 13.9% | +19.4 | -17.7 to +87.6 |
| claude-haiku-4-5-20251001-high vs claude-sonnet-5-5-medium | 0/2 = 0.0% | 16.3% | -16.3 | -22.4 to -10.5 |
| claude-haiku-4-5-20251001-high vs gpt-5.6-terra-medium | 0/2 = 0.0% | 22.1% | -22.1 | -30.2 to -14.8 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-high | 0/2 = 0.0% | 6.8% | -6.8 | -10.9 to -3.8 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-low | 0/2 = 0.0% | 9.4% | -9.4 | -15.1 to -5.2 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-medium | 0/2 = 0.0% | 8.0% | -8.0 | -11.9 to -5.0 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-off | 0/3 = 0.0% | 10.4% | -10.4 | -17.1 to -5.7 |
| claude-haiku-4-5-20251001-high vs gpt-6-luna-medium | 0/2 = 0.0% | 45.4% | -45.4 | -55.4 to -34.1 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 12.2% | -12.2 | -17.8 to -7.8 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-high | 0/4 = 0.0% | 12.1% | -12.1 | -19.7 to -6.8 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-max | 0/2 = 0.0% | 6.5% | -6.5 | -10.8 to -3.6 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-medium | 1/3 = 33.3% | 9.3% | +24.1 | -11.7 to +92.3 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-off/low | 0/7 = 0.0% | 13.2% | -13.2 | -18.9 to -8.6 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 8.3% | -8.3 | -13.4 to -4.8 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-high | 1/12 = 8.3% | 22.7% | -14.4 | -26.9 to +4.9 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-low | 4/14 = 28.6% | 27.6% | +1.0 | -20.1 to +21.9 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-max | 0/2 = 0.0% | 19.1% | -19.1 | -25.9 to -13.2 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-medium | 8/31 = 25.8% | 24.3% | +1.5 | -11.6 to +13.6 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-off | 5/12 = 41.7% | 45.2% | -3.5 | -36.5 to +26.9 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-xhigh | 1/2 = 50.0% | 20.1% | +29.9 | +23.0 to +35.1 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-high | 0/1 = 0.0% | 13.7% | -13.7 | -20.2 to -8.3 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-max | 0/2 = 0.0% | 9.6% | -9.6 | -15.0 to -5.5 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-medium | 7/20 = 35.0% | 17.8% | +17.2 | -2.6 to +37.4 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-off/low | 1/5 = 20.0% | 21.5% | -1.5 | -26.0 to +74.4 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-high | 0/2 = 0.0% | 22.3% | -22.3 | -29.8 to -15.5 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-low | 0/2 = 0.0% | 34.1% | -34.1 | -43.6 to -24.9 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-max | 0/2 = 0.0% | 11.1% | -11.1 | -16.1 to -7.3 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-medium | 2/20 = 10.0% | 24.7% | -14.7 | -26.8 to -0.2 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-off | 0/4 = 0.0% | 27.5% | -27.5 | -35.6 to -20.1 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-xhigh | 0/2 = 0.0% | 14.2% | -14.2 | -19.1 to -10.0 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-low | 0/2 = 0.0% | 37.0% | -37.0 | -48.7 to -26.4 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-max | 0/2 = 0.0% | 25.4% | -25.4 | -36.4 to -16.0 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-medium | 6/20 = 30.0% | 32.4% | -2.4 | -18.5 to +13.5 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-xhigh | 1/2 = 50.0% | 24.9% | +25.1 | +13.9 to +33.1 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-high | 0/3 = 0.0% | 11.0% | -11.0 | -16.2 to -6.9 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-low | 1/3 = 33.3% | 14.9% | +18.4 | -19.2 to +86.1 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-medium | 3/20 = 15.0% | 12.9% | +2.1 | -11.8 to +17.6 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-off | 0/3 = 0.0% | 16.5% | -16.5 | -25.1 to -10.0 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-high | 1/2 = 50.0% | 33.3% | +16.7 | +7.9 to +25.0 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-medium | 12/20 = 60.0% | 58.4% | +1.6 | -24.9 to +27.6 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-off/low | 2/2 = 100.0% | 69.3% | +30.7 | +22.8 to +38.5 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 26.7% | +23.3 | +13.2 to +31.2 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 19.6% | +30.4 | +22.3 to +36.4 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-low | 1/2 = 50.0% | 17.1% | +32.9 | +24.8 to +38.4 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-medium | 6/20 = 30.0% | 19.0% | +11.0 | -8.1 to +32.5 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 17.4% | +32.6 | +24.9 to +37.8 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-high | 0/4 = 0.0% | 18.9% | -18.9 | -27.7 to -11.5 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-max | 0/3 = 0.0% | 10.5% | -10.5 | -15.9 to -6.5 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-medium | 1/3 = 33.3% | 14.7% | +18.6 | -18.6 to +86.7 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-off/low | 1/7 = 14.3% | 20.4% | -6.1 | -23.9 to +28.4 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 13.2% | -13.2 | -19.0 to -8.4 |
| claude-haiku-4-5-20251001-minimal/low vs claude-haiku-5-5-low | 2/21 = 9.5% | 22.6% | -13.0 | -24.8 to +2.4 |
| claude-haiku-4-5-20251001-minimal/low vs claude-haiku-5-5-medium | 2/5 = 40.0% | 19.7% | +20.3 | -20.4 to +33.9 |
| claude-haiku-4-5-20251001-minimal/low vs claude-haiku-5-5-off | 7/22 = 31.8% | 38.6% | -6.8 | -25.6 to +13.2 |
| claude-haiku-4-5-20251001-minimal/low vs claude-opus-5-5-high | 0/1 = 0.0% | 10.8% | -10.8 | -16.7 to -6.2 |
| claude-haiku-4-5-20251001-minimal/low vs claude-opus-5-5-max | 0/4 = 0.0% | 7.5% | -7.5 | -12.1 to -4.1 |
| claude-haiku-4-5-20251001-minimal/low vs claude-opus-5-5-medium | 1/4 = 25.0% | 14.2% | +10.8 | -16.6 to +38.5 |
| claude-haiku-4-5-20251001-minimal/low vs claude-opus-5-5-off/low | 0/7 = 0.0% | 17.3% | -17.3 | -23.8 to -11.5 |
| claude-haiku-4-5-20251001-minimal/low vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 20.1% | +29.9 | +23.5 to +35.0 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-5.6-terra-medium | 1/2 = 50.0% | 26.8% | +23.2 | +14.6 to +30.1 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6-astra-high | 0/6 = 0.0% | 8.6% | -8.6 | -13.0 to -5.2 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6-astra-low | 0/5 = 0.0% | 11.8% | -11.8 | -17.9 to -6.9 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6-astra-medium | 0/2 = 0.0% | 10.1% | -10.1 | -13.5 to -7.0 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6-astra-off | 1/6 = 16.7% | 13.1% | +3.6 | -16.9 to +41.6 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6-luna-medium | 3/4 = 75.0% | 51.8% | +23.2 | -7.5 to +54.2 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-sol-medium | 0/2 = 0.0% | 15.2% | -15.2 | -20.3 to -10.6 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-terra-high | 3/8 = 37.5% | 15.1% | +22.4 | -11.7 to +58.8 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-terra-max | 1/5 = 20.0% | 8.2% | +11.8 | -10.6 to +61.0 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-terra-medium | 0/6 = 0.0% | 11.7% | -11.7 | -16.9 to -7.5 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-terra-off/low | 3/14 = 21.4% | 16.4% | +5.1 | -15.2 to +27.9 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-terra-xhigh | 0/6 = 0.0% | 10.4% | -10.4 | -15.7 to -6.5 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5-medium | 1/2 = 50.0% | 9.3% | +40.7 | +35.6 to +44.1 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5-off | 3/11 = 27.3% | 20.8% | +6.5 | -21.5 to +42.7 |
| claude-haiku-4-5-20251001-off vs claude-opus-5-5-max | 0/1 = 0.0% | 3.3% | -3.3 | -5.7 to -1.5 |
| claude-haiku-4-5-20251001-off vs claude-opus-5-5-off/low | 0/2 = 0.0% | 8.0% | -8.0 | -12.8 to -4.5 |
| claude-haiku-4-5-20251001-off vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 9.5% | +40.5 | +34.9 to +44.3 |
| claude-haiku-4-5-20251001-off vs gpt-5.6-terra-medium | 0/2 = 0.0% | 13.2% | -13.2 | -19.9 to -7.9 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-high | 0/2 = 0.0% | 3.8% | -3.8 | -6.5 to -2.0 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-low | 0/2 = 0.0% | 5.3% | -5.3 | -9.3 to -2.6 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-medium | 0/2 = 0.0% | 4.5% | -4.5 | -7.1 to -2.6 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-off | 0/2 = 0.0% | 5.9% | -5.9 | -10.3 to -3.0 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-sol-medium | 0/2 = 0.0% | 6.9% | -6.9 | -11.1 to -4.1 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-high | 0/3 = 0.0% | 6.9% | -6.9 | -12.1 to -3.3 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-max | 0/2 = 0.0% | 3.6% | -3.6 | -6.4 to -1.8 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-medium | 0/2 = 0.0% | 5.2% | -5.2 | -8.7 to -2.8 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-off/low | 0/5 = 0.0% | 7.5% | -7.5 | -11.9 to -4.3 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 4.6% | -4.6 | -7.8 to -2.4 |
| claude-haiku-5-5-high vs claude-opus-5-5-high | 0/2 = 0.0% | 35.1% | -35.1 | -46.6 to -24.0 |
| claude-haiku-5-5-high vs claude-opus-5-5-max | 0/4 = 0.0% | 26.6% | -26.6 | -38.0 to -16.6 |
| claude-haiku-5-5-high vs claude-opus-5-5-medium | 1/2 = 50.0% | 42.4% | +7.6 | -0.6 to +16.0 |
| claude-haiku-5-5-high vs claude-opus-5-5-off/low | 6/7 = 85.7% | 48.3% | +37.4 | +3.4 to +59.3 |
| claude-haiku-5-5-high vs claude-sonnet-5-5-medium | 2/4 = 50.0% | 52.8% | -2.8 | -57.6 to +50.7 |
| claude-haiku-5-5-high vs gpt-6-astra-high | 2/4 = 50.0% | 29.6% | +20.4 | -31.5 to +73.8 |
| claude-haiku-5-5-high vs gpt-6-astra-low | 1/4 = 25.0% | 37.4% | -12.4 | -45.2 to +53.6 |
| claude-haiku-5-5-high vs gpt-6-astra-medium | 0/2 = 0.0% | 33.5% | -33.5 | -41.4 to -25.4 |
| claude-haiku-5-5-high vs gpt-6-astra-off | 1/4 = 25.0% | 40.2% | -15.2 | -48.7 to +38.6 |
| claude-haiku-5-5-high vs gpt-6-luna-medium | 1/2 = 50.0% | 82.7% | -32.7 | -37.5 to -26.9 |
| claude-haiku-5-5-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 44.4% | -44.4 | -53.1 to -35.1 |
| claude-haiku-5-5-high vs gpt-6.1-terra-high | 2/4 = 50.0% | 44.3% | +5.7 | -47.7 to +58.8 |
| claude-haiku-5-5-high vs gpt-6.1-terra-max | 0/4 = 0.0% | 28.6% | -28.6 | -39.6 to -19.0 |
| claude-haiku-5-5-high vs gpt-6.1-terra-medium | 2/4 = 50.0% | 37.0% | +13.0 | -42.5 to +63.9 |
| claude-haiku-5-5-high vs gpt-6.1-terra-off/low | 3/7 = 42.9% | 46.6% | -3.7 | -45.0 to +39.5 |
| claude-haiku-5-5-high vs gpt-6.1-terra-xhigh | 2/4 = 50.0% | 34.2% | +15.8 | -36.7 to +69.2 |
| claude-haiku-5-5-low vs claude-opus-5-5-high | 1/2 = 50.0% | 29.4% | +20.6 | -35.3 to +76.5 |
| claude-haiku-5-5-low vs claude-opus-5-5-max | 1/3 = 33.3% | 21.8% | +11.5 | -27.5 to +80.0 |
| claude-haiku-5-5-low vs claude-opus-5-5-medium | 2/2 = 100.0% | 36.1% | +63.9 | +55.6 to +70.6 |
| claude-haiku-5-5-low vs claude-opus-5-5-off/low | 1/6 = 16.7% | 41.8% | -25.1 | -49.2 to +12.6 |
| claude-haiku-5-5-low vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 46.3% | +3.7 | -4.1 to +11.6 |
| claude-haiku-5-5-low vs gpt-5.6-terra-medium | 1/2 = 50.0% | 55.7% | -5.7 | -14.7 to +2.7 |
| claude-haiku-5-5-low vs gpt-6-astra-high | 0/4 = 0.0% | 24.4% | -24.4 | -33.2 to -16.0 |
| claude-haiku-5-5-low vs gpt-6-astra-low | 0/4 = 0.0% | 31.4% | -31.4 | -42.8 to -21.0 |
| claude-haiku-5-5-low vs gpt-6-astra-medium | 0/2 = 0.0% | 27.9% | -27.9 | -35.0 to -21.1 |
| claude-haiku-5-5-low vs gpt-6-astra-off | 3/4 = 75.0% | 34.1% | +40.9 | -22.4 to +73.9 |
| claude-haiku-5-5-low vs gpt-6-luna-medium | 1/2 = 50.0% | 78.7% | -28.7 | -33.9 to -22.5 |
| claude-haiku-5-5-low vs gpt-6.1-sol-medium | 2/2 = 100.0% | 38.0% | +62.0 | +52.7 to +69.8 |
| claude-haiku-5-5-low vs gpt-6.1-terra-high | 3/4 = 75.0% | 37.9% | +37.1 | -26.0 to +71.7 |
| claude-haiku-5-5-low vs gpt-6.1-terra-max | 1/4 = 25.0% | 23.6% | +1.4 | -29.4 to +69.3 |
| claude-haiku-5-5-low vs gpt-6.1-terra-medium | 3/4 = 75.0% | 31.2% | +43.8 | -24.9 to +74.9 |
| claude-haiku-5-5-low vs gpt-6.1-terra-off/low | 4/8 = 50.0% | 40.2% | +9.8 | -27.2 to +42.5 |
| claude-haiku-5-5-low vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 28.5% | -28.5 | -38.7 to -19.5 |
| claude-haiku-5-5-max vs claude-opus-5-5-medium | 2/2 = 100.0% | 47.8% | +52.2 | +41.1 to +61.6 |
| claude-haiku-5-5-max vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 58.2% | -8.2 | -17.5 to +2.7 |
| claude-haiku-5-5-max vs gpt-5.6-terra-medium | 1/2 = 50.0% | 67.1% | -17.1 | -25.9 to -7.4 |
| claude-haiku-5-5-max vs gpt-6.1-sol-medium | 1/2 = 50.0% | 49.8% | +0.2 | -10.1 to +10.6 |
| claude-haiku-5-5-medium vs claude-opus-5-5-high | 0/2 = 0.0% | 33.0% | -33.0 | -43.1 to -22.8 |
| claude-haiku-5-5-medium vs claude-opus-5-5-max | 1/3 = 33.3% | 24.9% | +8.4 | -29.8 to +30.7 |
| claude-haiku-5-5-medium vs claude-opus-5-5-medium | 7/20 = 35.0% | 40.2% | -5.2 | -21.0 to +8.9 |
| claude-haiku-5-5-medium vs claude-opus-5-5-off/low | 3/6 = 50.0% | 46.0% | +4.0 | -40.7 to +50.2 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-high | 1/4 = 25.0% | 47.2% | -22.2 | -53.3 to +8.6 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-low | 2/2 = 100.0% | 61.6% | +38.4 | +28.9 to +48.0 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-max | 0/2 = 0.0% | 28.0% | -28.0 | -36.2 to -19.8 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-medium | 12/20 = 60.0% | 50.5% | +9.5 | -9.0 to +26.8 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-off | 1/2 = 50.0% | 54.1% | -4.1 | -12.5 to +5.1 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-xhigh | 1/4 = 25.0% | 34.0% | -9.0 | -38.5 to +20.2 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-high | 2/2 = 100.0% | 62.3% | +37.7 | +26.3 to +48.4 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.6% | -14.6 | -25.0 to -2.9 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-max | 2/2 = 100.0% | 51.4% | +48.6 | +35.0 to +60.7 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-medium | 13/20 = 65.0% | 59.9% | +5.1 | -9.8 to +20.4 |
| claude-haiku-5-5-medium vs gpt-6-astra-high | 1/4 = 25.0% | 27.7% | -2.7 | -34.3 to +65.6 |
| claude-haiku-5-5-medium vs gpt-6-astra-low | 2/4 = 50.0% | 35.2% | +14.8 | -35.7 to +68.8 |
| claude-haiku-5-5-medium vs gpt-6-astra-medium | 6/20 = 30.0% | 31.5% | -1.5 | -17.6 to +13.7 |
| claude-haiku-5-5-medium vs gpt-6-astra-off | 3/4 = 75.0% | 38.0% | +37.0 | -31.2 to +70.4 |
| claude-haiku-5-5-medium vs gpt-6-luna-high | 1/2 = 50.0% | 60.9% | -10.9 | -18.9 to -1.8 |
| claude-haiku-5-5-medium vs gpt-6-luna-max | 1/2 = 50.0% | 55.5% | -5.5 | -15.6 to +6.0 |
| claude-haiku-5-5-medium vs gpt-6-luna-medium | 19/20 = 95.0% | 81.4% | +13.6 | +2.5 to +21.7 |
| claude-haiku-5-5-medium vs gpt-6-luna-off/low | 2/2 = 100.0% | 87.5% | +12.5 | +9.1 to +16.3 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-high | 2/4 = 50.0% | 43.0% | +7.0 | -3.2 to +16.3 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-low | 0/2 = 0.0% | 39.0% | -39.0 | -49.0 to -28.7 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-max | 1/2 = 50.0% | 31.9% | +18.1 | +10.4 to +24.8 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-medium | 10/20 = 50.0% | 42.1% | +7.9 | -7.7 to +24.0 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 39.5% | +10.5 | +0.7 to +20.0 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-high | 1/4 = 25.0% | 42.0% | -17.0 | -50.4 to +50.9 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-max | 1/4 = 25.0% | 26.8% | -1.8 | -33.5 to +64.8 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-medium | 1/4 = 25.0% | 34.9% | -9.9 | -40.9 to +55.1 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-off/low | 1/8 = 12.5% | 44.3% | -31.8 | -49.9 to -2.3 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 32.1% | -32.1 | -41.9 to -22.6 |
| claude-haiku-5-5-off vs claude-opus-5-5-high | 0/1 = 0.0% | 16.1% | -16.1 | -23.5 to -10.4 |
| claude-haiku-5-5-off vs claude-opus-5-5-max | 0/2 = 0.0% | 11.5% | -11.5 | -17.0 to -6.8 |
| claude-haiku-5-5-off vs claude-opus-5-5-off/low | 0/5 = 0.0% | 25.0% | -25.0 | -32.4 to -18.4 |
| claude-haiku-5-5-off vs gpt-5.6-terra-medium | 1/2 = 50.0% | 36.8% | +13.2 | +4.7 to +19.9 |
| claude-haiku-5-5-off vs gpt-6-astra-high | 1/3 = 33.3% | 13.0% | +20.3 | -16.2 to +88.4 |
| claude-haiku-5-5-off vs gpt-6-astra-low | 0/3 = 0.0% | 17.5% | -17.5 | -24.9 to -11.1 |
| claude-haiku-5-5-off vs gpt-6-astra-medium | 0/2 = 0.0% | 15.2% | -15.2 | -19.4 to -11.4 |
| claude-haiku-5-5-off vs gpt-6-astra-off | 1/4 = 25.0% | 19.3% | +5.7 | -24.7 to +79.3 |
| claude-haiku-5-5-off vs gpt-6-luna-medium | 1/2 = 50.0% | 63.1% | -13.1 | -19.9 to -6.1 |
| claude-haiku-5-5-off vs gpt-6.1-sol-medium | 0/2 = 0.0% | 22.1% | -22.1 | -28.0 to -16.7 |
| claude-haiku-5-5-off vs gpt-6.1-terra-high | 0/4 = 0.0% | 22.1% | -22.1 | -31.3 to -13.6 |
| claude-haiku-5-5-off vs gpt-6.1-terra-max | 0/3 = 0.0% | 12.5% | -12.5 | -18.4 to -8.1 |
| claude-haiku-5-5-off vs gpt-6.1-terra-medium | 0/3 = 0.0% | 17.3% | -17.3 | -23.4 to -12.0 |
| claude-haiku-5-5-off vs gpt-6.1-terra-off/low | 2/7 = 28.6% | 23.7% | +4.9 | -25.4 to +46.1 |
| claude-haiku-5-5-off vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 15.6% | -15.6 | -21.7 to -10.4 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-high | 0/2 = 0.0% | 38.6% | -38.6 | -51.7 to -26.5 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-max | 0/3 = 0.0% | 29.7% | -29.7 | -42.2 to -19.0 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-medium | 0/2 = 0.0% | 46.2% | -46.2 | -54.4 to -37.2 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-off/low | 2/7 = 28.6% | 52.1% | -23.5 | -55.8 to +14.9 |
| claude-haiku-5-5-xhigh vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 56.6% | -6.6 | -15.7 to +2.6 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-high | 1/4 = 25.0% | 32.9% | -7.9 | -39.8 to +59.6 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-low | 1/4 = 25.0% | 41.0% | -16.0 | -49.9 to +51.5 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-medium | 0/2 = 0.0% | 37.0% | -37.0 | -46.0 to -27.8 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-off | 3/4 = 75.0% | 43.9% | +31.1 | -27.5 to +66.0 |
| claude-haiku-5-5-xhigh vs gpt-6-luna-medium | 2/2 = 100.0% | 84.8% | +15.2 | +10.6 to +20.2 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-high | 2/4 = 50.0% | 48.1% | +1.9 | -51.1 to +54.2 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-max | 0/4 = 0.0% | 31.8% | -31.8 | -43.0 to -21.7 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-medium | 3/4 = 75.0% | 40.7% | +34.3 | -34.0 to +66.6 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-off/low | 2/7 = 28.6% | 50.4% | -21.8 | -53.8 to +16.2 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-xhigh | 2/4 = 50.0% | 37.7% | +12.3 | -39.4 to +65.6 |
| claude-opus-5-5-high vs claude-sonnet-5-5-high | 2/2 = 100.0% | 64.4% | +35.6 | +23.2 to +49.2 |
| claude-opus-5-5-high vs claude-sonnet-5-5-low | 2/2 = 100.0% | 76.5% | +23.5 | +14.7 to +34.8 |
| claude-opus-5-5-high vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 67.5% | -17.5 | -27.3 to -6.3 |
| claude-opus-5-5-high vs claude-sonnet-5-5-off | 2/2 = 100.0% | 70.5% | +29.5 | +19.0 to +41.9 |
| claude-opus-5-5-high vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 51.1% | +48.9 | +35.0 to +61.4 |
| claude-opus-5-5-high vs gpt-6-astra-high | 0/1 = 0.0% | 43.8% | -43.8 | -57.9 to -29.6 |
| claude-opus-5-5-high vs gpt-6-astra-medium | 1/2 = 50.0% | 48.2% | +1.8 | -11.1 to +12.6 |
| claude-opus-5-5-high vs gpt-6-astra-off | 0/1 = 0.0% | 55.4% | -55.4 | -69.6 to -38.8 |
| claude-opus-5-5-high vs gpt-6-luna-medium | 2/2 = 100.0% | 89.9% | +10.1 | +6.0 to +15.6 |
| claude-opus-5-5-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 59.6% | -59.6 | -69.9 to -46.4 |
| claude-opus-5-5-high vs gpt-6.1-terra-max | 1/1 = 100.0% | 42.6% | +57.4 | +41.2 to +70.9 |
| claude-opus-5-5-high vs gpt-6.1-terra-off/low | 1/1 = 100.0% | 61.8% | +38.2 | +25.9 to +49.7 |
| claude-opus-5-5-max vs claude-sonnet-5-5-high | 3/4 = 75.0% | 72.9% | +2.1 | -66.2 to +34.0 |
| claude-opus-5-5-max vs claude-sonnet-5-5-low | 2/3 = 66.7% | 82.9% | -16.2 | -84.9 to +21.7 |
| claude-opus-5-5-max vs claude-sonnet-5-5-max | 0/2 = 0.0% | 54.0% | -54.0 | -66.6 to -38.9 |
| claude-opus-5-5-max vs claude-sonnet-5-5-medium | 3/3 = 100.0% | 75.5% | +24.5 | +15.4 to +33.9 |
| claude-opus-5-5-max vs claude-sonnet-5-5-off | 3/3 = 100.0% | 78.1% | +21.9 | +12.9 to +32.1 |
| claude-opus-5-5-max vs claude-sonnet-5-5-xhigh | 2/3 = 66.7% | 60.9% | +5.8 | -62.6 to +46.5 |
| claude-opus-5-5-max vs gpt-6-astra-medium | 1/2 = 50.0% | 58.1% | -8.1 | -20.6 to +4.1 |
| claude-opus-5-5-max vs gpt-6.1-sol-medium | 1/2 = 50.0% | 68.7% | -18.7 | -29.6 to -7.1 |
| claude-opus-5-5-max vs gpt-6.1-terra-medium | 1/2 = 50.0% | 61.8% | -11.8 | -24.4 to +2.8 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-high | 2/2 = 100.0% | 57.1% | +42.9 | +32.5 to +52.8 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-low | 2/4 = 50.0% | 70.5% | -20.5 | -75.1 to +33.5 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-max | 2/2 = 100.0% | 36.7% | +63.3 | +52.0 to +71.9 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-medium | 12/20 = 60.0% | 60.4% | -0.4 | -19.5 to +18.3 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-off | 1/2 = 50.0% | 63.7% | -13.7 | -21.5 to -4.7 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 43.4% | +56.6 | +46.7 to +65.0 |
| claude-opus-5-5-medium vs gpt-5.6-terra-high | 2/2 = 100.0% | 71.1% | +28.9 | +19.1 to +38.4 |
| claude-opus-5-5-medium vs gpt-5.6-terra-low | 1/2 = 50.0% | 73.1% | -23.1 | -32.0 to -12.3 |
| claude-opus-5-5-medium vs gpt-5.6-terra-max | 2/2 = 100.0% | 61.2% | +38.8 | +26.4 to +50.5 |
| claude-opus-5-5-medium vs gpt-5.6-terra-medium | 12/20 = 60.0% | 69.0% | -9.0 | -21.1 to +4.8 |
| claude-opus-5-5-medium vs gpt-5.6-terra-xhigh | 2/2 = 100.0% | 60.5% | +39.5 | +27.0 to +51.1 |
| claude-opus-5-5-medium vs gpt-6-astra-high | 2/4 = 50.0% | 36.3% | +13.7 | -36.8 to +65.9 |
| claude-opus-5-5-medium vs gpt-6-astra-low | 2/4 = 50.0% | 44.8% | +5.2 | -46.4 to +56.7 |
| claude-opus-5-5-medium vs gpt-6-astra-medium | 9/20 = 45.0% | 40.6% | +4.4 | -8.2 to +14.1 |
| claude-opus-5-5-medium vs gpt-6-astra-off | 2/4 = 50.0% | 47.7% | +2.3 | -50.5 to +56.2 |
| claude-opus-5-5-medium vs gpt-6-luna-max | 1/2 = 50.0% | 65.0% | -15.0 | -25.2 to -3.1 |
| claude-opus-5-5-medium vs gpt-6-luna-medium | 16/20 = 80.0% | 86.7% | -6.7 | -30.5 to +11.6 |
| claude-opus-5-5-medium vs gpt-6-luna-off/low | 2/2 = 100.0% | 91.3% | +8.7 | +5.9 to +11.8 |
| claude-opus-5-5-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 62.8% | -12.8 | -22.0 to -1.8 |
| claude-opus-5-5-medium vs gpt-6.1-sol-high | 2/2 = 100.0% | 53.0% | +47.0 | +36.1 to +55.8 |
| claude-opus-5-5-medium vs gpt-6.1-sol-low | 1/2 = 50.0% | 48.8% | +1.2 | -10.5 to +12.5 |
| claude-opus-5-5-medium vs gpt-6.1-sol-max | 1/2 = 50.0% | 41.1% | +8.9 | -0.3 to +16.7 |
| claude-opus-5-5-medium vs gpt-6.1-sol-medium | 12/20 = 60.0% | 52.0% | +8.0 | -11.7 to +26.6 |
| claude-opus-5-5-medium vs gpt-6.1-sol-xhigh | 2/4 = 50.0% | 49.3% | +0.7 | -9.4 to +11.3 |
| claude-opus-5-5-medium vs gpt-6.1-terra-high | 0/3 = 0.0% | 51.9% | -51.9 | -64.1 to -37.7 |
| claude-opus-5-5-medium vs gpt-6.1-terra-max | 1/4 = 25.0% | 35.3% | -10.3 | -42.8 to +55.5 |
| claude-opus-5-5-medium vs gpt-6.1-terra-medium | 2/3 = 66.7% | 44.4% | +22.2 | -1.1 to +62.3 |
| claude-opus-5-5-medium vs gpt-6.1-terra-off/low | 4/7 = 57.1% | 54.3% | +2.9 | -38.1 to +44.5 |
| claude-opus-5-5-medium vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 41.4% | -8.0 | -47.8 to +59.8 |
| claude-opus-5-5-off/low vs claude-sonnet-5-5-high | 4/7 = 57.1% | 51.2% | +6.0 | -37.6 to +46.3 |
| claude-opus-5-5-off/low vs claude-sonnet-5-5-low | 4/5 = 80.0% | 65.3% | +14.7 | -32.0 to +42.0 |
| claude-opus-5-5-off/low vs claude-sonnet-5-5-medium | 5/7 = 71.4% | 54.6% | +16.9 | -14.5 to +48.5 |
| claude-opus-5-5-off/low vs claude-sonnet-5-5-off | 3/7 = 42.9% | 58.1% | -15.2 | -61.1 to +26.8 |
| claude-opus-5-5-off/low vs claude-sonnet-5-5-xhigh | 2/7 = 28.6% | 37.7% | -9.1 | -40.7 to +28.6 |
| claude-opus-5-5-off/low vs gpt-5.6-terra-medium | 0/2 = 0.0% | 63.7% | -63.7 | -72.0 to -53.1 |
| claude-opus-5-5-off/low vs gpt-6-astra-high | 1/2 = 50.0% | 31.0% | +19.0 | -37.4 to +75.2 |
| claude-opus-5-5-off/low vs gpt-6-astra-low | 1/2 = 50.0% | 39.0% | +11.0 | -45.5 to +67.9 |
| claude-opus-5-5-off/low vs gpt-6-astra-off | 0/2 = 0.0% | 41.8% | -41.8 | -55.4 to -28.4 |
| claude-opus-5-5-off/low vs gpt-6-luna-medium | 2/2 = 100.0% | 83.7% | +16.3 | +11.1 to +22.2 |
| claude-opus-5-5-off/low vs gpt-6-luna-xhigh | 1/2 = 50.0% | 57.1% | -7.1 | -18.5 to +5.8 |
| claude-opus-5-5-off/low vs gpt-6.1-terra-max | 0/2 = 0.0% | 30.0% | -30.0 | -41.4 to -19.7 |
| claude-opus-5-5-off/low vs gpt-6.1-terra-medium | 1/1 = 100.0% | 38.7% | +61.3 | +49.6 to +71.7 |
| claude-opus-5-5-off/low vs gpt-6.1-terra-off/low | 2/2 = 100.0% | 48.3% | +51.7 | +40.8 to +61.5 |
| claude-opus-5-5-off/low vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 35.7% | +14.3 | -41.5 to +72.0 |
| claude-opus-5-5-xhigh vs claude-sonnet-5-5-max | 2/10 = 20.0% | 46.3% | -26.3 | -51.8 to -1.1 |
| claude-opus-5-5-xhigh vs gpt-6-astra-high | 2/4 = 50.0% | 46.0% | +4.0 | -49.4 to +55.9 |
| claude-opus-5-5-xhigh vs gpt-6-astra-low | 2/4 = 50.0% | 54.7% | -4.7 | -58.5 to +47.7 |
| claude-opus-5-5-xhigh vs gpt-6-astra-medium | 22/41 = 53.7% | 50.5% | +3.2 | -8.4 to +15.4 |
| claude-opus-5-5-xhigh vs gpt-6-astra-off | 2/4 = 50.0% | 57.6% | -7.6 | -62.0 to +45.2 |
| claude-opus-5-5-xhigh vs gpt-6.1-sol-max | 4/10 = 40.0% | 50.9% | -10.9 | -33.3 to +4.8 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-high | 1/3 = 33.3% | 61.7% | -28.3 | -70.1 to +38.8 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-max | 5/5 = 100.0% | 44.8% | +55.2 | +42.1 to +68.1 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-medium | 2/3 = 66.7% | 54.4% | +12.3 | -54.4 to +53.6 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-off/low | 4/6 = 66.7% | 63.9% | +2.8 | -39.4 to +38.8 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 51.2% | -17.9 | -58.8 to +51.4 |
| claude-sonnet-5-5-high vs gpt-5.6-terra-medium | 1/2 = 50.0% | 62.6% | -12.6 | -22.3 to -2.0 |
| claude-sonnet-5-5-high vs gpt-6-astra-high | 2/4 = 50.0% | 30.0% | +20.0 | -32.6 to +72.9 |
| claude-sonnet-5-5-high vs gpt-6-astra-low | 2/4 = 50.0% | 37.9% | +12.1 | -39.9 to +65.0 |
| claude-sonnet-5-5-high vs gpt-6-astra-medium | 2/2 = 100.0% | 34.0% | +66.0 | +55.4 to +74.0 |
| claude-sonnet-5-5-high vs gpt-6-astra-off | 0/4 = 0.0% | 40.7% | -40.7 | -55.2 to -27.3 |
| claude-sonnet-5-5-high vs gpt-6-luna-medium | 1/2 = 50.0% | 83.0% | -33.0 | -38.5 to -25.7 |
| claude-sonnet-5-5-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 44.9% | -44.9 | -55.1 to -34.0 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-high | 3/3 = 100.0% | 44.8% | +55.2 | +40.6 to +68.9 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-max | 1/4 = 25.0% | 29.1% | -4.1 | -36.7 to +66.4 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-medium | 1/3 = 33.3% | 37.6% | -4.2 | -45.8 to +63.8 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-off/low | 2/7 = 28.6% | 47.1% | -18.6 | -51.7 to +20.1 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 34.7% | -34.7 | -47.3 to -23.2 |
| claude-sonnet-5-5-low vs gpt-6-astra-high | 0/4 = 0.0% | 19.3% | -19.3 | -28.5 to -11.7 |
| claude-sonnet-5-5-low vs gpt-6-astra-low | 0/4 = 0.0% | 25.3% | -25.3 | -35.9 to -15.7 |
| claude-sonnet-5-5-low vs gpt-6-astra-medium | 0/2 = 0.0% | 22.2% | -22.2 | -29.7 to -14.9 |
| claude-sonnet-5-5-low vs gpt-6-astra-off | 0/4 = 0.0% | 27.6% | -27.6 | -40.3 to -17.6 |
| claude-sonnet-5-5-low vs gpt-6-luna-medium | 1/2 = 50.0% | 73.1% | -23.1 | -30.9 to -13.1 |
| claude-sonnet-5-5-low vs gpt-6.1-sol-medium | 1/2 = 50.0% | 31.2% | +18.8 | +9.4 to +27.6 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-high | 1/4 = 25.0% | 31.1% | -6.1 | -38.9 to +65.2 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-max | 1/3 = 33.3% | 18.5% | +14.8 | -23.8 to +83.6 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-medium | 1/4 = 25.0% | 25.1% | -0.1 | -31.2 to +26.7 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-off/low | 3/8 = 37.5% | 33.1% | +4.4 | -30.8 to +48.9 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-xhigh | 1/4 = 25.0% | 22.8% | +2.2 | -28.3 to +71.5 |
| claude-sonnet-5-5-max vs gpt-6-astra-medium | 4/10 = 40.0% | 54.2% | -14.2 | -39.2 to +2.2 |
| claude-sonnet-5-5-max vs gpt-6-luna-medium | 2/2 = 100.0% | 91.8% | +8.2 | +5.1 to +12.1 |
| claude-sonnet-5-5-max vs gpt-6.1-sol-max | 6/10 = 60.0% | 54.6% | +5.4 | -12.4 to +29.0 |
| claude-sonnet-5-5-max vs gpt-6.1-sol-medium | 2/2 = 100.0% | 65.2% | +34.8 | +24.8 to +44.4 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-high | 1/2 = 50.0% | 61.8% | -11.8 | -22.0 to +0.9 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.1% | -14.1 | -25.0 to -2.9 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-medium | 11/20 = 55.0% | 59.4% | -4.4 | -29.5 to +18.4 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-xhigh | 0/2 = 0.0% | 50.2% | -50.2 | -61.5 to -36.8 |
| claude-sonnet-5-5-medium vs gpt-6-astra-high | 3/4 = 75.0% | 27.3% | +47.7 | -26.6 to +78.8 |
| claude-sonnet-5-5-medium vs gpt-6-astra-low | 1/4 = 25.0% | 34.7% | -9.7 | -41.7 to +65.8 |
| claude-sonnet-5-5-medium vs gpt-6-astra-medium | 7/20 = 35.0% | 31.0% | +4.0 | -11.1 to +18.5 |
| claude-sonnet-5-5-medium vs gpt-6-astra-off | 2/4 = 50.0% | 37.5% | +12.5 | -39.3 to +66.2 |
| claude-sonnet-5-5-medium vs gpt-6-luna-medium | 17/20 = 85.0% | 81.0% | +4.0 | -11.9 to +18.0 |
| claude-sonnet-5-5-medium vs gpt-6-luna-off/low | 4/4 = 100.0% | 87.3% | +12.7 | +8.8 to +17.2 |
| claude-sonnet-5-5-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 52.6% | -2.6 | -13.0 to +8.9 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 42.5% | +7.5 | -2.9 to +17.7 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-low | 1/2 = 50.0% | 38.5% | +11.5 | +0.7 to +22.2 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-max | 0/2 = 0.0% | 31.4% | -31.4 | -39.3 to -23.8 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-medium | 8/20 = 40.0% | 41.6% | -1.6 | -20.1 to +17.0 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 39.0% | +11.0 | -0.4 to +20.7 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-high | 0/4 = 0.0% | 41.5% | -41.5 | -54.1 to -28.7 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-max | 1/4 = 25.0% | 26.3% | -1.3 | -32.5 to +69.0 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-medium | 1/4 = 25.0% | 34.4% | -9.4 | -40.2 to +62.2 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-off/low | 4/8 = 50.0% | 43.8% | +6.2 | -29.1 to +43.0 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-xhigh | 3/4 = 75.0% | 31.7% | +43.3 | -25.2 to +75.2 |
| claude-sonnet-5-5-off vs gpt-5.6-terra-medium | 1/2 = 50.0% | 55.8% | -5.8 | -15.8 to +4.1 |
| claude-sonnet-5-5-off vs gpt-6-astra-high | 0/4 = 0.0% | 24.5% | -24.5 | -34.6 to -16.4 |
| claude-sonnet-5-5-off vs gpt-6-astra-low | 1/4 = 25.0% | 31.5% | -6.5 | -38.7 to +49.2 |
| claude-sonnet-5-5-off vs gpt-6-astra-medium | 2/2 = 100.0% | 28.0% | +72.0 | +62.5 to +78.4 |
| claude-sonnet-5-5-off vs gpt-6-astra-off | 1/4 = 25.0% | 34.2% | -9.2 | -41.9 to +58.2 |
| claude-sonnet-5-5-off vs gpt-6-luna-medium | 2/2 = 100.0% | 78.7% | +21.3 | +15.0 to +28.4 |
| claude-sonnet-5-5-off vs gpt-6.1-sol-medium | 1/2 = 50.0% | 38.1% | +11.9 | +2.2 to +20.5 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-high | 0/4 = 0.0% | 38.0% | -38.0 | -51.4 to -25.3 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-max | 1/4 = 25.0% | 23.6% | +1.4 | -30.2 to +71.4 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-medium | 0/4 = 0.0% | 31.3% | -31.3 | -41.9 to -21.7 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-off/low | 2/8 = 25.0% | 40.3% | -15.3 | -42.9 to +21.1 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-xhigh | 1/4 = 25.0% | 28.6% | -3.6 | -35.6 to +65.1 |
| claude-sonnet-5-5-xhigh vs gpt-5.6-terra-medium | 2/2 = 100.0% | 74.3% | +25.7 | +18.1 to +33.2 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-high | 1/4 = 25.0% | 42.6% | -17.6 | -50.8 to +50.2 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-low | 3/4 = 75.0% | 51.3% | +23.7 | -39.9 to +57.6 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-medium | 1/2 = 50.0% | 47.1% | +2.9 | -7.0 to +12.3 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-off | 4/4 = 100.0% | 54.3% | +45.7 | +32.9 to +59.1 |
| claude-sonnet-5-5-xhigh vs gpt-6-luna-medium | 2/2 = 100.0% | 89.4% | +10.6 | +7.1 to +14.6 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-sol-medium | 1/2 = 50.0% | 58.5% | -8.5 | -17.9 to +1.4 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-high | 2/3 = 66.7% | 58.4% | +8.2 | -60.6 to +49.6 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-max | 2/4 = 50.0% | 41.5% | +8.5 | -44.1 to +61.3 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-medium | 2/3 = 66.7% | 51.0% | +15.7 | -53.5 to +57.0 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-off/low | 5/7 = 71.4% | 60.7% | +10.7 | -24.8 to +41.9 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-xhigh | 2/3 = 66.7% | 47.9% | +18.8 | -5.4 to +59.0 |
| gpt-5.6-terra-high vs gpt-6-astra-off | 0/1 = 0.0% | 27.0% | -27.0 | -40.2 to -16.1 |
| gpt-5.6-terra-high vs gpt-6-luna-medium | 1/2 = 50.0% | 72.6% | -22.6 | -31.1 to -10.8 |
| gpt-5.6-terra-high vs gpt-6.1-sol-medium | 1/2 = 50.0% | 30.6% | +19.4 | +7.5 to +28.7 |
| gpt-5.6-terra-low vs gpt-6-astra-medium | 0/2 = 0.0% | 20.1% | -20.1 | -28.3 to -12.1 |
| gpt-5.6-terra-low vs gpt-6.1-terra-high | 0/1 = 0.0% | 28.4% | -28.4 | -42.1 to -16.1 |
| gpt-5.6-terra-max vs gpt-6-astra-medium | 1/2 = 50.0% | 30.3% | +19.7 | +6.0 to +29.4 |
| gpt-5.6-terra-max vs gpt-6-luna-medium | 2/2 = 100.0% | 80.5% | +19.5 | +11.8 to +28.6 |
| gpt-5.6-terra-medium vs gpt-6-astra-medium | 5/20 = 25.0% | 23.5% | +1.5 | -14.5 to +17.7 |
| gpt-5.6-terra-medium vs gpt-6-astra-off | 0/1 = 0.0% | 29.1% | -29.1 | -40.4 to -19.1 |
| gpt-5.6-terra-medium vs gpt-6-luna-high | 2/2 = 100.0% | 51.0% | +49.0 | +38.3 to +59.4 |
| gpt-5.6-terra-medium vs gpt-6-luna-max | 2/2 = 100.0% | 45.5% | +54.5 | +41.2 to +64.7 |
| gpt-5.6-terra-medium vs gpt-6-luna-medium | 15/20 = 75.0% | 74.5% | +0.5 | -21.0 to +20.2 |
| gpt-5.6-terra-medium vs gpt-6-luna-off/low | 3/4 = 75.0% | 82.5% | -7.5 | -36.1 to +21.1 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-high | 0/2 = 0.0% | 33.6% | -33.6 | -43.6 to -23.8 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-low | 0/2 = 0.0% | 30.0% | -30.0 | -39.7 to -20.6 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-max | 0/2 = 0.0% | 23.9% | -23.9 | -30.6 to -16.7 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-medium | 6/20 = 30.0% | 32.8% | -2.8 | -18.2 to +12.5 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 30.4% | -30.4 | -39.5 to -21.1 |
| gpt-5.6-terra-medium vs gpt-6.1-terra-off/low | 0/1 = 0.0% | 34.8% | -34.8 | -43.3 to -26.4 |
| gpt-5.6-terra-medium vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 24.1% | -24.1 | -32.8 to -15.7 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-high | 1/1 = 100.0% | 27.1% | +72.9 | +58.9 to +83.4 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-low | 1/1 = 100.0% | 34.6% | +65.4 | +48.6 to +78.9 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-medium | 0/2 = 0.0% | 30.8% | -30.8 | -42.1 to -20.3 |
| gpt-5.6-terra-xhigh vs gpt-6.1-sol-medium | 0/2 = 0.0% | 41.4% | -41.4 | -52.9 to -28.8 |
| gpt-5.6-terra-xhigh vs gpt-6.1-terra-off/low | 0/1 = 0.0% | 43.6% | -43.6 | -56.9 to -30.8 |
| gpt-6-astra-high vs gpt-6.1-sol-high | 1/1 = 100.0% | 66.3% | +33.7 | +22.3 to +46.2 |
| gpt-6-astra-high vs gpt-6.1-sol-medium | 1/2 = 50.0% | 65.5% | -15.5 | -25.5 to -4.6 |
| gpt-6-astra-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 65.4% | +34.6 | +21.8 to +49.1 |
| gpt-6-astra-high vs gpt-6.1-terra-max | 1/2 = 50.0% | 48.8% | +1.2 | -56.7 to +58.3 |
| gpt-6-astra-high vs gpt-6.1-terra-medium | 0/1 = 0.0% | 58.3% | -58.3 | -71.0 to -44.2 |
| gpt-6-astra-high vs gpt-6.1-terra-off/low | 3/3 = 100.0% | 67.5% | +32.5 | +22.3 to +43.3 |
| gpt-6-astra-high vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 55.3% | -55.3 | -68.5 to -40.3 |
| gpt-6-astra-low vs gpt-6-luna-medium | 2/2 = 100.0% | 88.9% | +11.1 | +6.4 to +16.5 |
| gpt-6-astra-low vs gpt-6.1-sol-low | 0/1 = 0.0% | 54.0% | -54.0 | -67.4 to -38.5 |
| gpt-6-astra-low vs gpt-6.1-sol-medium | 1/2 = 50.0% | 57.2% | -7.2 | -19.0 to +4.7 |
| gpt-6-astra-low vs gpt-6.1-terra-high | 1/1 = 100.0% | 57.1% | +42.9 | +27.7 to +57.7 |
| gpt-6-astra-low vs gpt-6.1-terra-max | 0/2 = 0.0% | 40.2% | -40.2 | -55.2 to -25.9 |
| gpt-6-astra-low vs gpt-6.1-terra-medium | 1/1 = 100.0% | 49.7% | +50.3 | +35.1 to +63.3 |
| gpt-6-astra-low vs gpt-6.1-terra-off/low | 0/2 = 0.0% | 59.4% | -59.4 | -70.8 to -46.7 |
| gpt-6-astra-low vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 46.5% | +53.5 | +37.1 to +67.4 |
| gpt-6-astra-medium vs gpt-6-luna-high | 1/2 = 50.0% | 77.2% | -27.2 | -33.6 to -18.9 |
| gpt-6-astra-medium vs gpt-6-luna-max | 2/2 = 100.0% | 73.1% | +26.9 | +18.3 to +36.2 |
| gpt-6-astra-medium vs gpt-6-luna-medium | 19/20 = 95.0% | 90.5% | +4.5 | -6.7 to +11.4 |
| gpt-6-astra-medium vs gpt-6-luna-off/low | 2/2 = 100.0% | 93.9% | +6.1 | +4.1 to +8.5 |
| gpt-6-astra-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 71.2% | -21.2 | -29.5 to -10.9 |
| gpt-6-astra-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 62.2% | -12.2 | -21.5 to -2.2 |
| gpt-6-astra-medium vs gpt-6.1-sol-low | 3/4 = 75.0% | 58.2% | +16.8 | -14.7 to +47.6 |
| gpt-6-astra-medium vs gpt-6.1-sol-max | 6/10 = 60.0% | 50.4% | +9.6 | -5.6 to +32.1 |
| gpt-6-astra-medium vs gpt-6.1-sol-medium | 12/20 = 60.0% | 61.3% | -1.3 | -19.7 to +16.4 |
| gpt-6-astra-medium vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 58.7% | -58.7 | -67.6 to -47.2 |
| gpt-6-astra-medium vs gpt-6.1-terra-max | 0/1 = 0.0% | 44.3% | -44.3 | -56.0 to -32.0 |
| gpt-6-astra-off vs gpt-6-luna-xhigh | 1/1 = 100.0% | 65.0% | +35.0 | +22.3 to +49.4 |
| gpt-6-astra-off vs gpt-6.1-sol-medium | 0/1 = 0.0% | 54.3% | -54.3 | -66.6 to -40.3 |
| gpt-6-astra-off vs gpt-6.1-terra-high | 1/1 = 100.0% | 54.2% | +45.8 | +29.6 to +62.4 |
| gpt-6-astra-off vs gpt-6.1-terra-max | 0/1 = 0.0% | 37.4% | -37.4 | -51.8 to -23.2 |
| gpt-6-astra-off vs gpt-6.1-terra-medium | 0/1 = 0.0% | 46.7% | -46.7 | -61.9 to -32.4 |
| gpt-6-astra-off vs gpt-6.1-terra-off/low | 3/3 = 100.0% | 56.5% | +43.5 | +30.9 to +56.4 |
| gpt-6-astra-off vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 43.6% | +6.4 | -50.7 to +64.0 |
| gpt-6-luna-high vs gpt-6.1-sol-medium | 1/2 = 50.0% | 31.9% | +18.1 | +8.8 to +26.2 |
| gpt-6-luna-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 31.8% | +68.2 | +54.0 to +79.5 |
| gpt-6-luna-high vs gpt-6.1-terra-off/low | 0/1 = 0.0% | 33.9% | -33.9 | -43.9 to -24.7 |
| gpt-6-luna-max vs gpt-6.1-sol-medium | 0/2 = 0.0% | 36.9% | -36.9 | -47.9 to -26.0 |
| gpt-6-luna-max vs gpt-6.1-terra-off/low | 1/2 = 50.0% | 39.0% | +11.0 | -1.8 to +21.0 |
| gpt-6-luna-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 14.7% | +35.3 | +28.6 to +39.7 |
| gpt-6-luna-medium vs gpt-6.1-sol-low | 0/2 = 0.0% | 12.8% | -12.8 | -18.7 to -7.8 |
| gpt-6-luna-medium vs gpt-6.1-sol-max | 0/2 = 0.0% | 9.7% | -9.7 | -13.4 to -6.7 |
| gpt-6-luna-medium vs gpt-6.1-sol-medium | 3/20 = 15.0% | 14.3% | +0.7 | -13.4 to +16.0 |
| gpt-6-luna-medium vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 13.0% | -13.0 | -18.8 to -8.3 |
| gpt-6-luna-off/low vs gpt-6.1-sol-medium | 1/4 = 25.0% | 9.4% | +15.6 | -11.2 to +42.5 |
| gpt-6-luna-xhigh vs gpt-6.1-sol-medium | 1/2 = 50.0% | 39.1% | +10.9 | -0.9 to +21.3 |
| gpt-6-luna-xhigh vs gpt-6.1-terra-off/low | 1/2 = 50.0% | 41.2% | +8.8 | -3.5 to +19.6 |
| gpt-6.1-sol-high vs gpt-6.1-terra-medium | 1/2 = 50.0% | 41.5% | +8.5 | -3.3 to +20.0 |
| gpt-6.1-sol-low vs gpt-6.1-terra-max | 1/1 = 100.0% | 36.4% | +63.6 | +48.0 to +75.8 |
| gpt-6.1-sol-max vs gpt-6.1-terra-max | 1/2 = 50.0% | 43.9% | +6.1 | -6.0 to +18.8 |
| gpt-6.1-sol-medium vs gpt-6.1-terra-max | 1/1 = 100.0% | 33.4% | +66.6 | +54.3 to +76.2 |
| gpt-6.1-sol-medium vs gpt-6.1-terra-medium | 1/2 = 50.0% | 42.4% | +7.6 | -2.8 to +18.6 |
| gpt-6.1-sol-medium vs gpt-6.1-terra-off/low | 1/1 = 100.0% | 52.2% | +47.8 | +38.6 to +56.6 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-high | 1/2 = 50.0% | 52.6% | -2.6 | -17.5 to +12.5 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-max | 0/1 = 0.0% | 35.9% | -35.9 | -49.6 to -23.5 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 42.0% | +8.0 | -5.5 to +19.8 |
#### claude-haiku-4-5-20251001 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-medium | 11/20 = 55.0% | 37.2% | +17.8 | +2.6 to +35.1 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal/low | 19/40 = 47.5% | 43.7% | +3.8 | -6.6 to +15.0 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 65.0% | -0.0 | -18.9 to +17.3 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-4-5-20251001-minimal/low | 22/40 = 55.0% | 56.7% | -1.7 | -13.8 to +10.2 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 75.9% | +4.1 | -11.7 to +18.6 |
| claude-haiku-4-5-20251001-minimal/low vs claude-haiku-4-5-20251001-minimal/low | 20/40 = 50.0% | 50.0% | +0.0 | +0.0 to +0.0 |
| claude-haiku-4-5-20251001-minimal/low vs claude-haiku-4-5-20251001-off | 28/40 = 70.0% | 70.6% | -0.6 | -11.7 to +10.2 |
#### claude-haiku-5-5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 56.5% | +8.5 | -12.8 to +27.4 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 44.5% | +0.5 | -19.4 to +20.8 |
| claude-haiku-5-5-high vs claude-haiku-5-5-medium | 13/20 = 65.0% | 52.3% | +12.7 | -1.7 to +28.9 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 73.7% | -8.7 | -23.9 to +6.8 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 46.2% | -16.2 | -32.4 to -1.3 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 38.2% | -3.2 | -22.9 to +15.6 |
| claude-haiku-5-5-low vs claude-haiku-5-5-medium | 12/20 = 60.0% | 45.8% | +14.2 | -3.9 to +34.3 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 68.4% | -13.4 | -34.7 to +8.6 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 39.8% | +0.2 | -14.3 to +12.7 |
| claude-haiku-5-5-max vs claude-haiku-5-5-medium | 11/20 = 55.0% | 57.7% | -2.7 | -19.4 to +14.0 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 77.8% | +2.2 | -13.6 to +17.2 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 51.7% | -6.7 | -22.8 to +9.4 |
| claude-haiku-5-5-medium vs claude-haiku-5-5-off | 14/20 = 70.0% | 71.9% | -1.9 | -17.8 to +13.6 |
| claude-haiku-5-5-medium vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 43.9% | -8.9 | -27.8 to +12.8 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 23.4% | +1.6 | -18.4 to +23.7 |
#### claude-opus-5-5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5-high vs claude-opus-5-5-max | 1/2 = 50.0% | 40.2% | +9.8 | -47.2 to +68.0 |
| claude-opus-5-5-high vs claude-opus-5-5-medium | 11/20 = 55.0% | 57.7% | -2.7 | -22.4 to +16.6 |
| claude-opus-5-5-high vs claude-opus-5-5-off/low | 4/7 = 57.1% | 63.3% | -6.2 | -41.6 to +34.1 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 47.8% | -12.8 | -33.1 to +5.3 |
| claude-opus-5-5-max vs claude-opus-5-5-medium | 6/10 = 60.0% | 66.9% | -6.9 | -45.6 to +29.2 |
| claude-opus-5-5-max vs claude-opus-5-5-off/low | 9/12 = 75.0% | 72.0% | +3.0 | -26.2 to +29.5 |
| claude-opus-5-5-max vs claude-opus-5-5-xhigh | 5/10 = 50.0% | 57.6% | -7.6 | -36.4 to +21.5 |
| claude-opus-5-5-medium vs claude-opus-5-5-off/low | 16/24 = 66.7% | 55.9% | +10.7 | -2.0 to +25.1 |
| claude-opus-5-5-medium vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 40.2% | -5.2 | -20.9 to +9.2 |
| claude-opus-5-5-off/low vs claude-opus-5-5-off/low | 5/10 = 50.0% | 50.0% | +0.0 | +0.0 to +0.0 |
| claude-opus-5-5-off/low vs claude-opus-5-5-xhigh | 3/7 = 42.9% | 34.6% | +8.3 | -31.3 to +48.9 |
#### claude-sonnet-5-5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 64.3% | -9.3 | -32.7 to +13.7 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 30.3% | +9.7 | -10.1 to +33.7 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-medium | 13/20 = 65.0% | 53.4% | +11.6 | -8.8 to +31.7 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 56.9% | +13.1 | -1.9 to +29.7 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 36.6% | -11.6 | -31.0 to +8.1 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 19.5% | -4.5 | -18.6 to +10.1 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-medium | 9/20 = 45.0% | 38.9% | +6.1 | -15.0 to +26.7 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 42.4% | +7.6 | -10.8 to +26.6 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 24.3% | -4.3 | -19.2 to +11.6 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-medium | 12/20 = 60.0% | 72.5% | -12.5 | -31.8 to +5.5 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 75.2% | -5.2 | -30.5 to +15.2 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 57.0% | +8.0 | -11.6 to +26.9 |
| claude-sonnet-5-5-medium vs claude-sonnet-5-5-off | 10/20 = 50.0% | 53.6% | -3.6 | -22.9 to +15.3 |
| claude-sonnet-5-5-medium vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 33.5% | +11.5 | -8.9 to +34.2 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 30.4% | +24.6 | +14.7 to +37.4 |
#### gpt-5.6-terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 52.5% | -7.5 | -26.2 to +9.7 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.1% | +0.9 | -16.6 to +17.6 |
| gpt-5.6-terra-high vs gpt-5.6-terra-medium | 10/20 = 50.0% | 47.5% | +2.5 | -11.6 to +16.7 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 38.4% | +11.6 | -6.9 to +30.1 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 36.7% | +3.3 | -15.7 to +22.2 |
| gpt-5.6-terra-low vs gpt-5.6-terra-medium | 9/20 = 45.0% | 45.0% | +0.0 | -15.0 to +17.1 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 36.0% | -16.0 | -33.1 to -1.2 |
| gpt-5.6-terra-max vs gpt-5.6-terra-medium | 12/20 = 60.0% | 58.5% | +1.5 | -19.1 to +21.7 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 49.3% | +5.7 | -10.9 to +22.4 |
| gpt-5.6-terra-medium vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 40.8% | -5.8 | -20.4 to +8.9 |
#### gpt-6-astra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-astra-high vs gpt-6-astra-low | 2/2 = 100.0% | 58.7% | +41.3 | +27.7 to +56.6 |
| gpt-6-astra-high vs gpt-6-astra-medium | 1/2 = 50.0% | 54.5% | -4.5 | -16.6 to +7.1 |
| gpt-6-astra-high vs gpt-6-astra-off | 0/1 = 0.0% | 61.5% | -61.5 | -74.6 to -45.6 |
| gpt-6-astra-low vs gpt-6-astra-medium | 0/2 = 0.0% | 45.8% | -45.8 | -58.1 to -33.3 |
| gpt-6-astra-low vs gpt-6-astra-off | 2/2 = 100.0% | 53.0% | +47.0 | +31.1 to +62.5 |
#### gpt-6-luna efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 44.5% | -9.5 | -29.7 to +13.2 |
| gpt-6-luna-high vs gpt-6-luna-medium | 12/20 = 60.0% | 73.8% | -13.8 | -37.3 to +8.8 |
| gpt-6-luna-high vs gpt-6-luna-off/low | 32/40 = 80.0% | 81.9% | -1.9 | -11.8 to +8.8 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 42.2% | +12.8 | -5.4 to +33.1 |
| gpt-6-luna-max vs gpt-6-luna-medium | 15/20 = 75.0% | 77.8% | -2.8 | -18.8 to +12.1 |
| gpt-6-luna-max vs gpt-6-luna-off/low | 34/40 = 85.0% | 84.9% | +0.1 | -8.8 to +8.5 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 47.7% | +2.3 | -11.7 to +16.4 |
| gpt-6-luna-medium vs gpt-6-luna-off/low | 24/40 = 60.0% | 61.6% | -1.6 | -17.9 to +13.1 |
| gpt-6-luna-medium vs gpt-6-luna-xhigh | 2/20 = 10.0% | 20.6% | -10.6 | -23.1 to +3.2 |
| gpt-6-luna-off/low vs gpt-6-luna-off/low | 20/40 = 50.0% | 50.0% | +0.0 | +0.0 to +0.0 |
| gpt-6-luna-off/low vs gpt-6-luna-xhigh | 5/40 = 12.5% | 13.9% | -1.4 | -10.3 to +8.3 |
#### gpt-6.1-sol efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 45.8% | +14.2 | -2.0 to +32.5 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 38.2% | +6.8 | -12.1 to +26.5 |
| gpt-6.1-sol-high vs gpt-6.1-sol-medium | 8/20 = 40.0% | 49.1% | -9.1 | -22.9 to +3.6 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 46.4% | -1.4 | -18.5 to +14.4 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 42.3% | -12.3 | -31.4 to +6.4 |
| gpt-6.1-sol-low vs gpt-6.1-sol-medium | 13/20 = 65.0% | 53.2% | +11.8 | -6.8 to +30.8 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 50.5% | +9.5 | -6.9 to +24.7 |
| gpt-6.1-sol-max vs gpt-6.1-sol-medium | 12/20 = 60.0% | 60.9% | -0.9 | -19.3 to +18.1 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 58.3% | -8.3 | -23.1 to +5.5 |
| gpt-6.1-sol-medium vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 47.3% | +2.7 | -17.9 to +23.6 |
#### gpt-6.1-terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-terra-high vs gpt-6.1-terra-max | 0/1 = 0.0% | 33.5% | -33.5 | -48.3 to -21.1 |
| gpt-6.1-terra-high vs gpt-6.1-terra-medium | 2/3 = 66.7% | 42.5% | +24.1 | -1.4 to +66.2 |
| gpt-6.1-terra-high vs gpt-6.1-terra-off/low | 1/3 = 33.3% | 52.3% | -19.0 | -61.4 to +49.9 |
| gpt-6.1-terra-high vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 39.5% | -6.2 | -47.0 to +67.2 |
| gpt-6.1-terra-max vs gpt-6.1-terra-medium | 1/1 = 100.0% | 59.5% | +40.5 | +27.6 to +53.6 |
| gpt-6.1-terra-max vs gpt-6.1-terra-off/low | 0/2 = 0.0% | 68.5% | -68.5 | -78.1 to -57.3 |
| gpt-6.1-terra-max vs gpt-6.1-terra-xhigh | 3/3 = 100.0% | 56.4% | +43.6 | +29.4 to +56.8 |
| gpt-6.1-terra-medium vs gpt-6.1-terra-off/low | 4/6 = 66.7% | 59.7% | +6.9 | -13.0 to +44.0 |
| gpt-6.1-terra-medium vs gpt-6.1-terra-xhigh | 3/3 = 100.0% | 46.9% | +53.1 | +39.8 to +65.7 |
| gpt-6.1-terra-off/low vs gpt-6.1-terra-off/low | 3/6 = 50.0% | 50.0% | +0.0 | +0.0 to +0.0 |
| gpt-6.1-terra-off/low vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 37.3% | -37.3 | -47.9 to -26.7 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| Cross-model | 0.5890 | 0.5891 | -0.0001 | -0.0001 to -0.0000 | 0: 46, 0.1: 3, 0.2: 1 | tau=0.1: 0.5891, tau=0.2: 0.5895, tau=0.4: 0.5907, tau=0.8: 0.5945, tau=1.6: 0.6038 | not kept |
| Cross-model (seat and starter terms) | 0.5831 | 0.5831 | -0.0000 | -0.0000 to +0.0000 | 0: 48, 0.1: 2 | tau=0.1: 0.5832, tau=0.2: 0.5836, tau=0.4: 0.5848, tau=0.8: 0.5887, tau=1.6: 0.5984 | not kept |
| claude-haiku-4-5-20251001 efforts | 0.6676 | 0.6681 | -0.0005 | -0.0015 to +0.0005 | 0: 46, 0.1: 1, 0.4: 2, 0.8: 1 | tau=0.1: 0.6680, tau=0.2: 0.6690, tau=0.4: 0.6715, tau=0.8: 0.6753, tau=1.6: 0.6783 | not kept |
| claude-haiku-4-5-20251001 efforts (seat and starter terms) | 0.6692 | 0.6709 | -0.0017 | -0.0042 to -0.0001 | 0: 44, 0.1: 2, 0.2: 1, 0.4: 2, 0.8: 1 | tau=0.1: 0.6696, tau=0.2: 0.6707, tau=0.4: 0.6735, tau=0.8: 0.6779, tau=1.6: 0.6814 | not kept |
| claude-haiku-5-5 efforts | 0.6634 | 0.6639 | -0.0005 | -0.0008 to -0.0001 | 0: 45, 0.1: 2, 0.2: 3 | tau=0.1: 0.6638, tau=0.2: 0.6648, tau=0.4: 0.6686, tau=0.8: 0.6761, tau=1.6: 0.6820 | not kept |
| claude-haiku-5-5 efforts (seat and starter terms) | 0.6404 | 0.6412 | -0.0008 | -0.0015 to -0.0002 | 0: 47, 0.2: 2, 0.4: 1 | tau=0.1: 0.6406, tau=0.2: 0.6414, tau=0.4: 0.6445, tau=0.8: 0.6517, tau=1.6: 0.6582 | not kept |
| claude-opus-5-5 efforts | 0.6861 | 0.6863 | -0.0002 | -0.0006 to +0.0000 | 0: 49, 0.2: 1 | tau=0.1: 0.6870, tau=0.2: 0.6895, tau=0.4: 0.6977, tau=0.8: 0.7164, tau=1.6: 0.7432 | not kept |
| claude-opus-5-5 efforts (seat and starter terms) | 0.7007 | 0.7007 | +0.0000 | +0.0000 to +0.0000 | 0: 50 | tau=0.1: 0.7015, tau=0.2: 0.7038, tau=0.4: 0.7113, tau=0.8: 0.7286, tau=1.6: 0.7532 | not kept |
| claude-sonnet-5-5 efforts | 0.6752 | 0.6794 | -0.0042 | -0.0102 to +0.0009 | 0: 20, 0.1: 4, 0.2: 12, 0.4: 12, 0.8: 2 | tau=0.1: 0.6748, tau=0.2: 0.6741, tau=0.4: 0.6747, tau=0.8: 0.6815, tau=1.6: 0.6898 | not kept |
| claude-sonnet-5-5 efforts (seat and starter terms) | 0.6686 | 0.6715 | -0.0029 | -0.0089 to +0.0025 | 0: 14, 0.1: 3, 0.2: 17, 0.4: 14, 0.8: 2 | tau=0.1: 0.6682, tau=0.2: 0.6673, tau=0.4: 0.6672, tau=0.8: 0.6723, tau=1.6: 0.6790 | not kept |
| gpt-5.6-terra efforts | 0.6901 | 0.6923 | -0.0021 | -0.0048 to +0.0004 | 0: 37, 0.1: 2, 0.2: 6, 0.4: 4, 0.8: 1 | tau=0.1: 0.6904, tau=0.2: 0.6912, tau=0.4: 0.6943, tau=0.8: 0.7008, tau=1.6: 0.7063 | not kept |
| gpt-5.6-terra efforts (seat and starter terms) | 0.6972 | 0.6996 | -0.0024 | -0.0044 to -0.0006 | 0: 37, 0.1: 6, 0.2: 2, 0.4: 5 | tau=0.1: 0.6975, tau=0.2: 0.6982, tau=0.4: 0.7015, tau=0.8: 0.7090, tau=1.6: 0.7160 | not kept |
| gpt-6-astra efforts | - | - | - | - | - | - | 7 seed blocks, under the minimum of 10: the fit with seat and starter terms can be singular on so few, so not tested |
| gpt-6-luna efforts | 0.5718 | 0.5758 | -0.0040 | -0.0079 to -0.0007 | 0: 41, 0.1: 1, 0.2: 2, 0.4: 3, 0.8: 3 | tau=0.1: 0.5719, tau=0.2: 0.5723, tau=0.4: 0.5740, tau=0.8: 0.5784, tau=1.6: 0.5855 | not kept |
| gpt-6-luna efforts (seat and starter terms) | 0.5752 | 0.5784 | -0.0032 | -0.0067 to +0.0001 | 0: 32, 0.1: 3, 0.2: 5, 0.4: 7, 0.8: 3 | tau=0.1: 0.5753, tau=0.2: 0.5755, tau=0.4: 0.5767, tau=0.8: 0.5800, tau=1.6: 0.5857 | not kept |
| gpt-6.1-sol efforts | 0.7081 | 0.7097 | -0.0016 | -0.0081 to +0.0044 | 0: 11, 0.1: 7, 0.2: 14, 0.4: 16, 0.8: 2 | tau=0.1: 0.7078, tau=0.2: 0.7074, tau=0.4: 0.7081, tau=0.8: 0.7130, tau=1.6: 0.7182 | not kept |
| gpt-6.1-sol efforts (seat and starter terms) | 0.7081 | 0.7122 | -0.0042 | -0.0114 to +0.0020 | 0: 17, 0.1: 4, 0.2: 15, 0.4: 12, 0.8: 2 | tau=0.1: 0.7078, tau=0.2: 0.7075, tau=0.4: 0.7088, tau=0.8: 0.7156, tau=1.6: 0.7231 | not kept |
| gpt-6.1-terra efforts | 0.8312 | 0.7682 | +0.0630 | -0.0662 to +0.1880 | 0: 3, 0.2: 1, 0.4: 1, 0.8: 6, 1.6: 39 | tau=0.1: 0.8295, tau=0.2: 0.8247, tau=0.4: 0.8073, tau=0.8: 0.7603, tau=1.6: 0.7077 | not kept |
| gpt-6.1-terra efforts (seat and starter terms) | 0.9527 | 0.8948 | +0.0579 | -0.0596 to +0.1646 | 0: 3, 0.1: 1, 0.8: 10, 1.6: 36 | tau=0.1: 0.9511, tau=0.2: 0.9466, tau=0.4: 0.9305, tau=0.8: 0.8885, tau=1.6: 0.8526 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| Cross-model | 204/397 = 51.4% | -0.11 |
| claude-haiku-4-5-20251001 efforts | 3/7 = 42.9% | -0.29 |
| claude-haiku-5-5 efforts | 5/15 = 33.3% | -0.45 |
| claude-opus-5-5 efforts | 1/11 = 9.1% | -0.81 |
| claude-sonnet-5-5 efforts | 6/15 = 40.0% | -0.04 |
| gpt-5.6-terra efforts | 4/10 = 40.0% | -0.15 |
| gpt-6-luna efforts | 4/11 = 36.4% | -0.19 |
| gpt-6.1-sol efforts | 6/10 = 60.0% | -0.18 |
| gpt-6.1-terra efforts | 5/7 = 71.4% | +0.76 |
| all cohorts pooled | 238/483 = 49.3% | -0.11 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 1.1e-16, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 6109 of 6109 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 2678 blocks, 1328 seeds (753 matches in half blocks left out) | 2859/5356 = 53.4% | 49.6% to 57.2% | 52.1% to 54.6% |
| Cross-model: 1861 blocks, 1318 seeds (710 matches in half blocks left out) | 2011/3722 = 54.0% | 51.2% to 57.0% | 52.6% to 55.5% |
| claude-haiku-4-5-20251001 efforts: 100 blocks, 10 seeds | 105/200 = 52.5% | 42.5% to 60.0% | 45.5% to 59.5% |
| claude-haiku-5-5 efforts: 150 blocks, 10 seeds | 142/300 = 47.3% | 34.7% to 60.0% | 41.3% to 53.3% |
| claude-opus-5-5 efforts: 58 blocks, 18 seeds (21 matches in half blocks left out) | 61/116 = 52.6% | 38.9% to 66.7% | 43.1% to 62.1% |
| claude-sonnet-5-5 efforts: 150 blocks, 10 seeds | 162/300 = 54.0% | 43.0% to 64.3% | 48.7% to 59.3% |
| gpt-5.6-terra efforts: 100 blocks, 10 seeds | 96/200 = 48.0% | 36.5% to 59.0% | 40.5% to 55.5% |
| gpt-6-astra efforts: 2 blocks, 1 seeds (5 matches in half blocks left out) | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% |
| gpt-6-luna efforts: 150 blocks, 10 seeds | 160/300 = 53.3% | 47.3% to 59.3% | 48.7% to 58.0% |
| gpt-6.1-sol efforts: 100 blocks, 10 seeds | 111/200 = 55.5% | 43.5% to 68.5% | 48.0% to 63.0% |
| gpt-6.1-terra efforts: 7 blocks, 7 seeds (17 matches in half blocks left out) | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 2911/5356 = 54.4% | 51.0% to 58.0% | 53.0% to 55.7% | 1334/2678 |
| Cross-model | 2001/3722 = 53.8% | 51.3% to 56.3% | 52.3% to 55.3% | 922/1861 |
| claude-haiku-4-5-20251001 efforts | 115/200 = 57.5% | 50.0% to 65.5% | 50.5% to 64.5% | 50/100 |
| claude-haiku-5-5 efforts | 186/300 = 62.0% | 51.3% to 72.3% | 56.3% to 67.7% | 75/150 |
| claude-opus-5-5 efforts | 67/116 = 57.8% | 44.1% to 70.5% | 48.3% to 67.2% | 31/58 |
| claude-sonnet-5-5 efforts | 164/300 = 54.7% | 43.0% to 65.0% | 49.0% to 60.0% | 75/150 |
| gpt-5.6-terra efforts | 108/200 = 54.0% | 43.0% to 64.5% | 46.5% to 61.5% | 50/100 |
| gpt-6-astra efforts | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% | 2/2 |
| gpt-6-luna efforts | 152/300 = 50.7% | 44.3% to 57.3% | 46.0% to 55.7% | 75/150 |
| gpt-6.1-sol efforts | 107/200 = 53.5% | 40.5% to 66.5% | 46.0% to 61.0% | 50/100 |
| gpt-6.1-terra efforts | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% | 4/7 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +3.4 | -0.1 to +6.8 | +2.1 to +4.7 | +4.4 | +0.9 to +7.7 | +3.0 to +5.7 |
| Cross-model | +4.1 | +1.4 to +6.8 | +2.6 to +5.5 | +3.8 | +1.1 to +6.4 | +2.3 to +5.3 |
| claude-haiku-4-5-20251001 efforts | +2.5 | -6.5 to +9.5 | -4.2 to +9.3 | +7.5 | +0.4 to +16.3 | +0.7 to +14.5 |
| claude-haiku-5-5 efforts | -2.7 | -13.9 to +7.6 | -8.2 to +3.0 | +12.0 | +0.7 to +23.1 | +6.3 to +17.7 |
| claude-opus-5-5 efforts | +2.1 | -11.7 to +15.8 | -7.4 to +11.8 | +7.6 | -6.4 to +20.6 | -1.7 to +17.0 |
| claude-sonnet-5-5 efforts | +4.0 | -7.7 to +14.4 | -1.6 to +9.3 | +4.7 | -7.5 to +15.3 | -0.9 to +10.1 |
| gpt-5.6-terra efforts | -2.0 | -14.0 to +8.8 | -9.5 to +5.4 | +4.0 | -7.8 to +14.8 | -3.4 to +11.3 |
| gpt-6-luna efforts | +3.3 | -3.3 to +9.4 | -1.6 to +8.1 | +0.7 | -5.7 to +7.4 | -4.1 to +5.6 |
| gpt-6.1-sol efforts | +5.5 | -7.0 to +19.6 | -2.2 to +13.1 | +3.5 | -9.8 to +16.5 | -3.8 to +11.1 |
| gpt-6.1-terra efforts | +6.2 | -20.8 to +33.4 | -20.0 to +33.3 | +6.2 | -20.8 to +35.0 | -20.8 to +33.3 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| Engine/2/20000: 1167 blocks, 1129 seeds | 1349/2334 = 57.8% | 56.0% to 59.6% | 56.0% to 59.6% |
| Engine/6/20000/sampled: 118 blocks, 90 seeds | 117/236 = 49.6% | 41.2% to 57.5% | 42.4% to 56.4% |
| Engine/7/2000000/sampled: 560 blocks, 560 seeds | 639/1120 = 57.1% | 54.6% to 59.4% | 54.6% to 59.3% |
| claude-haiku-4-5-20251001: 271 blocks, 73 seeds | 270/542 = 49.8% | 43.7% to 55.5% | 45.9% to 53.9% |
| claude-haiku-5-5: 679 blocks, 404 seeds | 715/1358 = 52.7% | 47.9% to 57.4% | 50.1% to 55.4% |
| claude-opus-5-5: 234 blocks, 68 seeds | 231/468 = 49.4% | 41.4% to 57.5% | 44.4% to 54.1% |
| claude-sonnet-5-5: 328 blocks, 42 seeds | 335/656 = 51.1% | 43.7% to 58.5% | 47.3% to 54.6% |
| gpt-5.6-terra: 208 blocks, 19 seeds | 217/416 = 52.2% | 43.3% to 61.5% | 47.4% to 57.5% |
| gpt-6-astra: 144 blocks, 57 seeds | 138/288 = 47.9% | 39.7% to 57.3% | 42.0% to 53.8% |
| gpt-6-luna: 468 blocks, 226 seeds | 479/936 = 51.2% | 47.8% to 54.5% | 48.6% to 53.8% |
| gpt-6.1-sol: 252 blocks, 49 seeds | 249/504 = 49.4% | 41.6% to 58.1% | 44.6% to 54.2% |
| gpt-6.1-terra: 110 blocks, 100 seeds | 131/220 = 59.5% | 52.8% to 66.0% | 52.3% to 66.4% |

#### Per seed, all cohorts

Cohorts reuse seeds 3000 to 3018 (tournament 3 adds 3020 to 3029, and tournament 5 many seeds from 4000 up, most with one block), so a seed's starter result pools many pairings.

| seed | position that starts | complete blocks | starter wins/matches = share |
|---|---|---|---|
| 3000 | 2 | 131 | 184/262 = 70.2% |
| 3001 | 2 | 36 | 54/72 = 75.0% |
| 3002 | 2 | 36 | 38/72 = 52.8% |
| 3003 | 2 | 36 | 34/72 = 47.2% |
| 3004 | 1 | 37 | 57/74 = 77.0% |
| 3005 | 1 | 37 | 28/74 = 37.8% |
| 3006 | 1 | 36 | 39/72 = 54.2% |
| 3007 | 2 | 37 | 60/74 = 81.1% |
| 3008 | 2 | 37 | 42/74 = 56.8% |
| 3009 | 1 | 37 | 45/74 = 60.8% |
| 3010 | 1 | 95 | 133/190 = 70.0% |
| 3011 | 1 | 95 | 132/190 = 69.5% |
| 3012 | 2 | 95 | 84/190 = 44.2% |
| 3013 | 2 | 95 | 90/190 = 47.4% |
| 3014 | 1 | 95 | 73/190 = 38.4% |
| 3015 | 1 | 95 | 142/190 = 74.7% |
| 3016 | 1 | 95 | 77/190 = 40.5% |
| 3017 | 2 | 94 | 88/188 = 46.8% |
| 3018 | 2 | 92 | 99/184 = 53.8% |
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
| 4000 | 1 | 3 | 2/6 = 33.3% |
| 4001 | 2 | 3 | 3/6 = 50.0% |
| 4002 | 2 | 3 | 3/6 = 50.0% |
| 4003 | 1 | 3 | 5/6 = 83.3% |
| 4004 | 1 | 3 | 4/6 = 66.7% |
| 4005 | 1 | 1 | 0/2 = 0.0% |
| 4006 | 1 | 1 | 0/2 = 0.0% |
| 4008 | 2 | 1 | 1/2 = 50.0% |
| 4009 | 2 | 1 | 2/2 = 100.0% |
| 4010 | 2 | 1 | 2/2 = 100.0% |
| 4011 | 1 | 1 | 0/2 = 0.0% |
| 4012 | 2 | 1 | 1/2 = 50.0% |
| 4013 | 2 | 1 | 2/2 = 100.0% |
| 4016 | 1 | 1 | 0/2 = 0.0% |
| 4017 | 1 | 1 | 1/2 = 50.0% |
| 4018 | 2 | 2 | 2/4 = 50.0% |
| 4019 | 1 | 2 | 3/4 = 75.0% |
| 4020 | 2 | 3 | 5/6 = 83.3% |
| 4021 | 1 | 4 | 3/8 = 37.5% |
| 4022 | 1 | 3 | 2/6 = 33.3% |
| 4023 | 1 | 3 | 4/6 = 66.7% |
| 4024 | 1 | 3 | 4/6 = 66.7% |
| 4025 | 2 | 2 | 3/4 = 75.0% |
| 4026 | 2 | 3 | 4/6 = 66.7% |
| 4027 | 2 | 2 | 3/4 = 75.0% |
| 4028 | 2 | 5 | 10/10 = 100.0% |
| 4029 | 2 | 5 | 6/10 = 60.0% |
| 4030 | 1 | 5 | 6/10 = 60.0% |
| 4031 | 1 | 5 | 8/10 = 80.0% |
| 4032 | 1 | 5 | 3/10 = 30.0% |
| 4033 | 2 | 2 | 4/4 = 100.0% |
| 4034 | 1 | 2 | 1/4 = 25.0% |
| 4035 | 2 | 2 | 1/4 = 25.0% |
| 4036 | 1 | 2 | 4/4 = 100.0% |
| 4037 | 2 | 1 | 1/2 = 50.0% |
| 4038 | 1 | 2 | 1/4 = 25.0% |
| 4039 | 1 | 3 | 4/6 = 66.7% |
| 4043 | 2 | 3 | 2/6 = 33.3% |
| 4044 | 2 | 2 | 2/4 = 50.0% |
| 4045 | 1 | 1 | 0/2 = 0.0% |
| 4046 | 1 | 1 | 2/2 = 100.0% |
| 4047 | 1 | 1 | 2/2 = 100.0% |
| 4048 | 2 | 1 | 2/2 = 100.0% |
| 4051 | 2 | 1 | 1/2 = 50.0% |
| 4053 | 2 | 1 | 2/2 = 100.0% |
| 4054 | 1 | 2 | 3/4 = 75.0% |
| 4059 | 1 | 1 | 2/2 = 100.0% |
| 4060 | 2 | 1 | 0/2 = 0.0% |
| 4061 | 1 | 1 | 1/2 = 50.0% |
| 9000 | 1 | 1 | 1/2 = 50.0% |
| 9001 | 1 | 1 | 2/2 = 100.0% |
| 9002 | 1 | 1 | 0/2 = 0.0% |
| 9004 | 2 | 1 | 1/2 = 50.0% |
| 9005 | 2 | 1 | 1/2 = 50.0% |
| 9020 | 2 | 1 | 0/2 = 0.0% |
| 9021 | 1 | 1 | 1/2 = 50.0% |
| 9022 | 2 | 1 | 1/2 = 50.0% |
| 9025 | 1 | 1 | 1/2 = 50.0% |
| 9028 | 1 | 1 | 1/2 = 50.0% |
| 9040 | 2 | 1 | 0/2 = 0.0% |
| 9041 | 1 | 1 | 1/2 = 50.0% |
| 9042 | 2 | 1 | 1/2 = 50.0% |
| 9044 | 1 | 1 | 0/2 = 0.0% |
| 9045 | 1 | 1 | 0/2 = 0.0% |
| 9060 | 2 | 1 | 1/2 = 50.0% |
| 9061 | 2 | 1 | 0/2 = 0.0% |
| 9063 | 1 | 1 | 1/2 = 50.0% |
| 9064 | 1 | 1 | 1/2 = 50.0% |
| 9067 | 1 | 1 | 0/2 = 0.0% |
| 9080 | 1 | 1 | 1/2 = 50.0% |
| 9081 | 2 | 1 | 1/2 = 50.0% |
| 9082 | 1 | 1 | 0/2 = 0.0% |
| 9083 | 2 | 1 | 0/2 = 0.0% |
| 9087 | 1 | 1 | 2/2 = 100.0% |
| 9100 | 2 | 1 | 2/2 = 100.0% |
| 9101 | 2 | 1 | 1/2 = 50.0% |
| 9103 | 1 | 1 | 1/2 = 50.0% |
| 9105 | 1 | 1 | 1/2 = 50.0% |
| 9106 | 1 | 1 | 1/2 = 50.0% |
| 9120 | 2 | 1 | 0/2 = 0.0% |
| 9121 | 2 | 1 | 1/2 = 50.0% |
| 9125 | 1 | 1 | 1/2 = 50.0% |
| 9128 | 1 | 1 | 0/2 = 0.0% |
| 9131 | 1 | 1 | 1/2 = 50.0% |
| 9140 | 1 | 1 | 1/2 = 50.0% |
| 9141 | 1 | 1 | 0/2 = 0.0% |
| 9142 | 2 | 1 | 1/2 = 50.0% |
| 9143 | 1 | 1 | 1/2 = 50.0% |
| 9144 | 2 | 1 | 1/2 = 50.0% |
| 9160 | 1 | 1 | 1/2 = 50.0% |
| 9161 | 1 | 1 | 1/2 = 50.0% |
| 9162 | 2 | 1 | 1/2 = 50.0% |
| 9163 | 2 | 1 | 1/2 = 50.0% |
| 9167 | 1 | 1 | 1/2 = 50.0% |
| 9180 | 2 | 1 | 1/2 = 50.0% |
| 9181 | 1 | 1 | 1/2 = 50.0% |
| 9182 | 1 | 1 | 1/2 = 50.0% |
| 9183 | 1 | 1 | 1/2 = 50.0% |
| 9184 | 2 | 1 | 0/2 = 0.0% |
| 12000 | 1 | 1 | 1/2 = 50.0% |
| 12001 | 2 | 1 | 1/2 = 50.0% |
| 12002 | 2 | 1 | 0/2 = 0.0% |
| 12003 | 1 | 1 | 1/2 = 50.0% |
| 12004 | 2 | 1 | 2/2 = 100.0% |
| 12005 | 1 | 1 | 2/2 = 100.0% |
| 12006 | 2 | 1 | 1/2 = 50.0% |
| 12007 | 1 | 1 | 2/2 = 100.0% |
| 12008 | 1 | 1 | 2/2 = 100.0% |
| 12009 | 1 | 1 | 0/2 = 0.0% |
| 12010 | 2 | 1 | 2/2 = 100.0% |
| 12011 | 2 | 1 | 2/2 = 100.0% |
| 12012 | 1 | 1 | 1/2 = 50.0% |
| 12013 | 1 | 1 | 2/2 = 100.0% |
| 12014 | 2 | 1 | 0/2 = 0.0% |
| 12015 | 1 | 1 | 0/2 = 0.0% |
| 12016 | 2 | 1 | 1/2 = 50.0% |
| 12017 | 1 | 1 | 1/2 = 50.0% |
| 12018 | 1 | 1 | 0/2 = 0.0% |
| 12019 | 1 | 1 | 2/2 = 100.0% |
| 12020 | 2 | 1 | 0/2 = 0.0% |
| 12021 | 1 | 1 | 2/2 = 100.0% |
| 12022 | 2 | 1 | 0/2 = 0.0% |
| 12023 | 1 | 1 | 1/2 = 50.0% |
| 12024 | 2 | 1 | 1/2 = 50.0% |
| 12025 | 2 | 1 | 1/2 = 50.0% |
| 12026 | 1 | 1 | 2/2 = 100.0% |
| 12027 | 1 | 1 | 1/2 = 50.0% |
| 12028 | 1 | 1 | 2/2 = 100.0% |
| 12029 | 2 | 1 | 2/2 = 100.0% |
| 12030 | 2 | 1 | 1/2 = 50.0% |
| 12031 | 2 | 1 | 1/2 = 50.0% |
| 12032 | 1 | 1 | 0/2 = 0.0% |
| 12033 | 1 | 1 | 0/2 = 0.0% |
| 12034 | 1 | 1 | 0/2 = 0.0% |
| 12035 | 1 | 1 | 1/2 = 50.0% |
| 12036 | 1 | 1 | 1/2 = 50.0% |
| 12037 | 2 | 1 | 0/2 = 0.0% |
| 12038 | 2 | 1 | 2/2 = 100.0% |
| 12039 | 1 | 1 | 1/2 = 50.0% |
| 14000 | 1 | 1 | 1/2 = 50.0% |
| 14001 | 2 | 1 | 0/2 = 0.0% |
| 14002 | 2 | 1 | 0/2 = 0.0% |
| 14003 | 1 | 1 | 1/2 = 50.0% |
| 14004 | 1 | 1 | 1/2 = 50.0% |
| 14005 | 2 | 1 | 0/2 = 0.0% |
| 14006 | 2 | 1 | 1/2 = 50.0% |
| 14007 | 1 | 1 | 1/2 = 50.0% |
| 14008 | 1 | 1 | 2/2 = 100.0% |
| 14009 | 2 | 1 | 1/2 = 50.0% |
| 14010 | 2 | 1 | 0/2 = 0.0% |
| 14011 | 2 | 1 | 0/2 = 0.0% |
| 14012 | 1 | 1 | 1/2 = 50.0% |
| 14013 | 2 | 1 | 1/2 = 50.0% |
| 14014 | 1 | 1 | 1/2 = 50.0% |
| 14015 | 1 | 1 | 1/2 = 50.0% |
| 14016 | 2 | 1 | 2/2 = 100.0% |
| 14017 | 1 | 1 | 1/2 = 50.0% |
| 14018 | 1 | 1 | 2/2 = 100.0% |
| 14019 | 1 | 1 | 2/2 = 100.0% |
| 14020 | 1 | 1 | 2/2 = 100.0% |
| 14021 | 2 | 1 | 1/2 = 50.0% |
| 14022 | 2 | 1 | 1/2 = 50.0% |
| 14023 | 2 | 1 | 0/2 = 0.0% |
| 14024 | 1 | 1 | 1/2 = 50.0% |
| 14025 | 2 | 1 | 1/2 = 50.0% |
| 14026 | 2 | 1 | 1/2 = 50.0% |
| 14027 | 2 | 1 | 2/2 = 100.0% |
| 14028 | 1 | 1 | 1/2 = 50.0% |
| 14029 | 1 | 1 | 1/2 = 50.0% |
| 14030 | 1 | 1 | 1/2 = 50.0% |
| 14031 | 1 | 1 | 2/2 = 100.0% |
| 14032 | 2 | 1 | 1/2 = 50.0% |
| 14033 | 2 | 1 | 0/2 = 0.0% |
| 14034 | 2 | 1 | 2/2 = 100.0% |
| 14035 | 2 | 1 | 2/2 = 100.0% |
| 14036 | 1 | 1 | 1/2 = 50.0% |
| 14037 | 1 | 1 | 1/2 = 50.0% |
| 14038 | 2 | 1 | 1/2 = 50.0% |
| 14039 | 2 | 1 | 1/2 = 50.0% |
| 14040 | 2 | 1 | 0/2 = 0.0% |
| 14041 | 2 | 1 | 1/2 = 50.0% |
| 14042 | 2 | 1 | 1/2 = 50.0% |
| 14043 | 1 | 1 | 2/2 = 100.0% |
| 14044 | 1 | 1 | 1/2 = 50.0% |
| 14045 | 1 | 1 | 1/2 = 50.0% |
| 14046 | 1 | 1 | 1/2 = 50.0% |
| 14047 | 2 | 1 | 1/2 = 50.0% |
| 14048 | 2 | 1 | 1/2 = 50.0% |
| 14049 | 2 | 1 | 0/2 = 0.0% |
| 14050 | 1 | 1 | 2/2 = 100.0% |
| 14051 | 2 | 1 | 1/2 = 50.0% |
| 14052 | 1 | 1 | 1/2 = 50.0% |
| 14053 | 1 | 1 | 2/2 = 100.0% |
| 14054 | 2 | 1 | 1/2 = 50.0% |
| 14055 | 1 | 1 | 1/2 = 50.0% |
| 14056 | 1 | 1 | 2/2 = 100.0% |
| 14057 | 2 | 1 | 1/2 = 50.0% |
| 14058 | 2 | 1 | 1/2 = 50.0% |
| 14059 | 2 | 1 | 1/2 = 50.0% |
| 14060 | 2 | 1 | 1/2 = 50.0% |
| 14061 | 2 | 1 | 0/2 = 0.0% |
| 14062 | 1 | 1 | 1/2 = 50.0% |
| 14063 | 1 | 1 | 2/2 = 100.0% |
| 14064 | 2 | 1 | 1/2 = 50.0% |
| 14065 | 1 | 1 | 2/2 = 100.0% |
| 14066 | 1 | 1 | 0/2 = 0.0% |
| 14067 | 2 | 1 | 2/2 = 100.0% |
| 14068 | 2 | 1 | 0/2 = 0.0% |
| 14069 | 2 | 1 | 1/2 = 50.0% |
| 14070 | 2 | 1 | 1/2 = 50.0% |
| 14071 | 2 | 1 | 1/2 = 50.0% |
| 14072 | 1 | 1 | 2/2 = 100.0% |
| 14073 | 2 | 1 | 1/2 = 50.0% |
| 14074 | 1 | 1 | 1/2 = 50.0% |
| 14075 | 1 | 1 | 1/2 = 50.0% |
| 14076 | 2 | 1 | 1/2 = 50.0% |
| 14077 | 2 | 1 | 1/2 = 50.0% |
| 14078 | 1 | 1 | 1/2 = 50.0% |
| 14079 | 1 | 1 | 1/2 = 50.0% |
| 14080 | 2 | 1 | 2/2 = 100.0% |
| 14081 | 2 | 1 | 1/2 = 50.0% |
| 14082 | 1 | 1 | 1/2 = 50.0% |
| 14083 | 2 | 1 | 1/2 = 50.0% |
| 14084 | 1 | 1 | 2/2 = 100.0% |
| 14085 | 2 | 1 | 0/2 = 0.0% |
| 14086 | 2 | 1 | 0/2 = 0.0% |
| 14087 | 2 | 1 | 1/2 = 50.0% |
| 14088 | 1 | 1 | 2/2 = 100.0% |
| 14089 | 2 | 1 | 0/2 = 0.0% |
| 14090 | 2 | 1 | 1/2 = 50.0% |
| 14091 | 1 | 1 | 1/2 = 50.0% |
| 14092 | 1 | 1 | 1/2 = 50.0% |
| 14093 | 1 | 1 | 2/2 = 100.0% |
| 14094 | 1 | 1 | 2/2 = 100.0% |
| 14095 | 1 | 1 | 2/2 = 100.0% |
| 14096 | 2 | 1 | 1/2 = 50.0% |
| 14097 | 2 | 1 | 1/2 = 50.0% |
| 14098 | 2 | 1 | 1/2 = 50.0% |
| 14099 | 1 | 1 | 1/2 = 50.0% |
| 14100 | 1 | 1 | 1/2 = 50.0% |
| 14101 | 2 | 1 | 2/2 = 100.0% |
| 14102 | 1 | 1 | 1/2 = 50.0% |
| 14103 | 1 | 1 | 1/2 = 50.0% |
| 14104 | 1 | 1 | 0/2 = 0.0% |
| 14105 | 1 | 1 | 1/2 = 50.0% |
| 14106 | 2 | 1 | 1/2 = 50.0% |
| 14107 | 1 | 1 | 1/2 = 50.0% |
| 14108 | 1 | 1 | 1/2 = 50.0% |
| 14109 | 2 | 1 | 1/2 = 50.0% |
| 14110 | 1 | 1 | 1/2 = 50.0% |
| 14111 | 2 | 1 | 2/2 = 100.0% |
| 14112 | 2 | 1 | 0/2 = 0.0% |
| 14113 | 2 | 1 | 2/2 = 100.0% |
| 14114 | 2 | 1 | 2/2 = 100.0% |
| 14115 | 1 | 1 | 2/2 = 100.0% |
| 14116 | 2 | 1 | 1/2 = 50.0% |
| 14117 | 2 | 1 | 1/2 = 50.0% |
| 14118 | 2 | 1 | 1/2 = 50.0% |
| 14119 | 1 | 1 | 1/2 = 50.0% |
| 14120 | 2 | 1 | 0/2 = 0.0% |
| 14121 | 1 | 1 | 2/2 = 100.0% |
| 14122 | 2 | 1 | 1/2 = 50.0% |
| 14123 | 1 | 1 | 1/2 = 50.0% |
| 14124 | 2 | 1 | 0/2 = 0.0% |
| 14125 | 2 | 1 | 1/2 = 50.0% |
| 14126 | 1 | 1 | 0/2 = 0.0% |
| 14127 | 1 | 1 | 1/2 = 50.0% |
| 14128 | 2 | 1 | 0/2 = 0.0% |
| 14129 | 2 | 1 | 1/2 = 50.0% |
| 14130 | 1 | 1 | 2/2 = 100.0% |
| 14131 | 2 | 1 | 1/2 = 50.0% |
| 14132 | 1 | 1 | 1/2 = 50.0% |
| 14133 | 1 | 1 | 2/2 = 100.0% |
| 14134 | 1 | 1 | 1/2 = 50.0% |
| 14135 | 2 | 1 | 1/2 = 50.0% |
| 14136 | 2 | 1 | 0/2 = 0.0% |
| 14137 | 2 | 1 | 1/2 = 50.0% |
| 14138 | 2 | 1 | 1/2 = 50.0% |
| 14139 | 2 | 1 | 0/2 = 0.0% |
| 14140 | 1 | 1 | 1/2 = 50.0% |
| 14141 | 2 | 1 | 2/2 = 100.0% |
| 14142 | 2 | 1 | 1/2 = 50.0% |
| 14143 | 1 | 1 | 2/2 = 100.0% |
| 14144 | 2 | 1 | 1/2 = 50.0% |
| 14145 | 1 | 1 | 2/2 = 100.0% |
| 14146 | 1 | 1 | 2/2 = 100.0% |
| 14147 | 1 | 1 | 1/2 = 50.0% |
| 14148 | 2 | 1 | 1/2 = 50.0% |
| 14149 | 2 | 1 | 0/2 = 0.0% |
| 14150 | 2 | 1 | 1/2 = 50.0% |
| 14151 | 2 | 1 | 1/2 = 50.0% |
| 14152 | 2 | 1 | 1/2 = 50.0% |
| 14153 | 1 | 1 | 1/2 = 50.0% |
| 14154 | 2 | 1 | 1/2 = 50.0% |
| 14155 | 1 | 1 | 1/2 = 50.0% |
| 14156 | 1 | 1 | 1/2 = 50.0% |
| 14157 | 1 | 1 | 2/2 = 100.0% |
| 14158 | 1 | 1 | 1/2 = 50.0% |
| 14159 | 1 | 1 | 1/2 = 50.0% |
| 14160 | 2 | 1 | 1/2 = 50.0% |
| 14161 | 2 | 1 | 1/2 = 50.0% |
| 14162 | 1 | 1 | 1/2 = 50.0% |
| 14163 | 2 | 1 | 0/2 = 0.0% |
| 14164 | 1 | 1 | 1/2 = 50.0% |
| 14165 | 1 | 1 | 1/2 = 50.0% |
| 14166 | 1 | 1 | 1/2 = 50.0% |
| 14167 | 1 | 1 | 1/2 = 50.0% |
| 14168 | 2 | 1 | 1/2 = 50.0% |
| 14169 | 1 | 1 | 1/2 = 50.0% |
| 14170 | 1 | 1 | 0/2 = 0.0% |
| 14171 | 1 | 1 | 2/2 = 100.0% |
| 14172 | 2 | 1 | 0/2 = 0.0% |
| 14173 | 1 | 1 | 1/2 = 50.0% |
| 14174 | 1 | 1 | 1/2 = 50.0% |
| 14175 | 1 | 1 | 2/2 = 100.0% |
| 14176 | 2 | 1 | 1/2 = 50.0% |
| 14177 | 1 | 1 | 1/2 = 50.0% |
| 14178 | 1 | 1 | 2/2 = 100.0% |
| 14179 | 2 | 1 | 0/2 = 0.0% |
| 14180 | 1 | 1 | 2/2 = 100.0% |
| 14181 | 1 | 1 | 1/2 = 50.0% |
| 14182 | 2 | 1 | 2/2 = 100.0% |
| 14183 | 2 | 1 | 1/2 = 50.0% |
| 14184 | 1 | 1 | 1/2 = 50.0% |
| 14185 | 1 | 1 | 1/2 = 50.0% |
| 14186 | 1 | 1 | 1/2 = 50.0% |
| 14187 | 1 | 1 | 1/2 = 50.0% |
| 14188 | 1 | 1 | 1/2 = 50.0% |
| 14189 | 2 | 1 | 1/2 = 50.0% |
| 14190 | 1 | 1 | 1/2 = 50.0% |
| 14191 | 1 | 1 | 0/2 = 0.0% |
| 14192 | 1 | 1 | 1/2 = 50.0% |
| 14193 | 2 | 1 | 1/2 = 50.0% |
| 14194 | 1 | 1 | 2/2 = 100.0% |
| 14195 | 2 | 1 | 2/2 = 100.0% |
| 14196 | 2 | 1 | 1/2 = 50.0% |
| 14197 | 2 | 1 | 1/2 = 50.0% |
| 14198 | 2 | 1 | 0/2 = 0.0% |
| 14199 | 2 | 1 | 1/2 = 50.0% |
| 14200 | 2 | 1 | 0/2 = 0.0% |
| 14201 | 2 | 1 | 1/2 = 50.0% |
| 14202 | 1 | 1 | 2/2 = 100.0% |
| 14203 | 1 | 1 | 1/2 = 50.0% |
| 14204 | 1 | 1 | 2/2 = 100.0% |
| 14205 | 1 | 1 | 2/2 = 100.0% |
| 14206 | 1 | 1 | 2/2 = 100.0% |
| 14207 | 1 | 1 | 1/2 = 50.0% |
| 14208 | 2 | 1 | 1/2 = 50.0% |
| 14209 | 2 | 1 | 1/2 = 50.0% |
| 14210 | 1 | 1 | 1/2 = 50.0% |
| 14211 | 2 | 1 | 0/2 = 0.0% |
| 14212 | 1 | 1 | 1/2 = 50.0% |
| 14213 | 2 | 1 | 1/2 = 50.0% |
| 14214 | 2 | 1 | 1/2 = 50.0% |
| 14215 | 2 | 1 | 1/2 = 50.0% |
| 14216 | 1 | 1 | 1/2 = 50.0% |
| 14217 | 1 | 1 | 0/2 = 0.0% |
| 14218 | 2 | 1 | 1/2 = 50.0% |
| 14219 | 1 | 1 | 2/2 = 100.0% |
| 14220 | 1 | 1 | 1/2 = 50.0% |
| 14221 | 2 | 1 | 1/2 = 50.0% |
| 14222 | 2 | 1 | 1/2 = 50.0% |
| 14223 | 1 | 1 | 2/2 = 100.0% |
| 14224 | 2 | 1 | 2/2 = 100.0% |
| 14225 | 1 | 1 | 2/2 = 100.0% |
| 14226 | 1 | 1 | 1/2 = 50.0% |
| 14227 | 2 | 1 | 1/2 = 50.0% |
| 14228 | 1 | 1 | 0/2 = 0.0% |
| 14229 | 2 | 1 | 1/2 = 50.0% |
| 14230 | 1 | 1 | 1/2 = 50.0% |
| 14231 | 1 | 1 | 1/2 = 50.0% |
| 14232 | 1 | 1 | 1/2 = 50.0% |
| 14233 | 1 | 1 | 1/2 = 50.0% |
| 14234 | 1 | 1 | 2/2 = 100.0% |
| 14235 | 1 | 1 | 1/2 = 50.0% |
| 14236 | 1 | 1 | 2/2 = 100.0% |
| 14237 | 1 | 1 | 1/2 = 50.0% |
| 14238 | 1 | 1 | 2/2 = 100.0% |
| 14239 | 2 | 1 | 1/2 = 50.0% |
| 14240 | 2 | 1 | 2/2 = 100.0% |
| 14241 | 2 | 1 | 1/2 = 50.0% |
| 14242 | 1 | 1 | 1/2 = 50.0% |
| 14243 | 2 | 1 | 1/2 = 50.0% |
| 14244 | 1 | 1 | 1/2 = 50.0% |
| 14245 | 2 | 1 | 1/2 = 50.0% |
| 14246 | 1 | 1 | 1/2 = 50.0% |
| 14247 | 1 | 1 | 0/2 = 0.0% |
| 14248 | 1 | 1 | 1/2 = 50.0% |
| 14249 | 1 | 1 | 2/2 = 100.0% |
| 14250 | 2 | 1 | 1/2 = 50.0% |
| 14251 | 2 | 1 | 2/2 = 100.0% |
| 14252 | 2 | 1 | 1/2 = 50.0% |
| 14253 | 2 | 1 | 0/2 = 0.0% |
| 14254 | 2 | 1 | 0/2 = 0.0% |
| 14255 | 1 | 1 | 1/2 = 50.0% |
| 14256 | 1 | 1 | 1/2 = 50.0% |
| 14257 | 1 | 1 | 2/2 = 100.0% |
| 14258 | 2 | 1 | 0/2 = 0.0% |
| 14259 | 2 | 1 | 0/2 = 0.0% |
| 14260 | 1 | 1 | 1/2 = 50.0% |
| 14261 | 2 | 1 | 0/2 = 0.0% |
| 14262 | 1 | 1 | 1/2 = 50.0% |
| 14263 | 2 | 1 | 0/2 = 0.0% |
| 14264 | 1 | 1 | 1/2 = 50.0% |
| 14265 | 1 | 1 | 2/2 = 100.0% |
| 14266 | 2 | 1 | 1/2 = 50.0% |
| 14267 | 1 | 1 | 1/2 = 50.0% |
| 14268 | 1 | 1 | 0/2 = 0.0% |
| 14269 | 1 | 1 | 1/2 = 50.0% |
| 14270 | 2 | 1 | 2/2 = 100.0% |
| 14271 | 1 | 1 | 1/2 = 50.0% |
| 14272 | 2 | 1 | 0/2 = 0.0% |
| 14273 | 1 | 1 | 0/2 = 0.0% |
| 14274 | 2 | 1 | 2/2 = 100.0% |
| 14275 | 2 | 1 | 1/2 = 50.0% |
| 14276 | 1 | 1 | 1/2 = 50.0% |
| 14277 | 1 | 1 | 2/2 = 100.0% |
| 14278 | 1 | 1 | 1/2 = 50.0% |
| 14279 | 1 | 1 | 1/2 = 50.0% |
| 14280 | 2 | 1 | 1/2 = 50.0% |
| 14281 | 2 | 1 | 1/2 = 50.0% |
| 14282 | 2 | 1 | 0/2 = 0.0% |
| 14283 | 2 | 1 | 2/2 = 100.0% |
| 14284 | 1 | 1 | 1/2 = 50.0% |
| 14285 | 1 | 1 | 2/2 = 100.0% |
| 14286 | 2 | 1 | 0/2 = 0.0% |
| 14287 | 2 | 1 | 0/2 = 0.0% |
| 14288 | 1 | 1 | 2/2 = 100.0% |
| 14289 | 2 | 1 | 0/2 = 0.0% |
| 14290 | 1 | 1 | 1/2 = 50.0% |
| 14291 | 1 | 1 | 1/2 = 50.0% |
| 14292 | 2 | 1 | 0/2 = 0.0% |
| 14293 | 2 | 1 | 0/2 = 0.0% |
| 14294 | 1 | 1 | 2/2 = 100.0% |
| 14295 | 2 | 1 | 1/2 = 50.0% |
| 14296 | 1 | 1 | 2/2 = 100.0% |
| 14297 | 1 | 1 | 1/2 = 50.0% |
| 14298 | 2 | 1 | 1/2 = 50.0% |
| 14299 | 1 | 1 | 1/2 = 50.0% |
| 14300 | 1 | 1 | 2/2 = 100.0% |
| 14301 | 2 | 1 | 1/2 = 50.0% |
| 14302 | 1 | 1 | 1/2 = 50.0% |
| 14303 | 1 | 1 | 1/2 = 50.0% |
| 14304 | 1 | 1 | 1/2 = 50.0% |
| 14305 | 2 | 1 | 1/2 = 50.0% |
| 14306 | 2 | 1 | 1/2 = 50.0% |
| 14307 | 1 | 1 | 1/2 = 50.0% |
| 14308 | 2 | 1 | 1/2 = 50.0% |
| 14309 | 1 | 1 | 1/2 = 50.0% |
| 14310 | 2 | 1 | 0/2 = 0.0% |
| 14311 | 2 | 1 | 2/2 = 100.0% |
| 14312 | 2 | 1 | 1/2 = 50.0% |
| 14313 | 2 | 1 | 2/2 = 100.0% |
| 14314 | 1 | 1 | 1/2 = 50.0% |
| 14315 | 1 | 1 | 1/2 = 50.0% |
| 14316 | 2 | 1 | 1/2 = 50.0% |
| 14317 | 2 | 1 | 1/2 = 50.0% |
| 14318 | 2 | 1 | 1/2 = 50.0% |
| 14319 | 1 | 1 | 1/2 = 50.0% |
| 14320 | 2 | 1 | 1/2 = 50.0% |
| 14321 | 1 | 1 | 2/2 = 100.0% |
| 14322 | 1 | 1 | 1/2 = 50.0% |
| 14323 | 2 | 1 | 0/2 = 0.0% |
| 14324 | 2 | 1 | 0/2 = 0.0% |
| 14325 | 2 | 1 | 1/2 = 50.0% |
| 14326 | 2 | 1 | 1/2 = 50.0% |
| 14327 | 2 | 1 | 1/2 = 50.0% |
| 14328 | 2 | 1 | 1/2 = 50.0% |
| 14329 | 1 | 1 | 1/2 = 50.0% |
| 14330 | 2 | 1 | 1/2 = 50.0% |
| 14331 | 1 | 1 | 1/2 = 50.0% |
| 14332 | 2 | 1 | 0/2 = 0.0% |
| 14333 | 2 | 1 | 1/2 = 50.0% |
| 14334 | 2 | 1 | 1/2 = 50.0% |
| 14335 | 2 | 1 | 1/2 = 50.0% |
| 14336 | 1 | 1 | 2/2 = 100.0% |
| 14337 | 1 | 1 | 2/2 = 100.0% |
| 14338 | 2 | 1 | 1/2 = 50.0% |
| 14339 | 1 | 1 | 0/2 = 0.0% |
| 14340 | 2 | 1 | 1/2 = 50.0% |
| 14341 | 1 | 1 | 1/2 = 50.0% |
| 14342 | 2 | 1 | 1/2 = 50.0% |
| 14343 | 1 | 1 | 1/2 = 50.0% |
| 14344 | 1 | 1 | 1/2 = 50.0% |
| 14345 | 2 | 1 | 1/2 = 50.0% |
| 14346 | 1 | 1 | 1/2 = 50.0% |
| 14347 | 1 | 1 | 1/2 = 50.0% |
| 14348 | 1 | 1 | 1/2 = 50.0% |
| 14349 | 2 | 1 | 1/2 = 50.0% |
| 14350 | 2 | 1 | 1/2 = 50.0% |
| 14351 | 2 | 1 | 1/2 = 50.0% |
| 14352 | 1 | 1 | 2/2 = 100.0% |
| 14353 | 1 | 1 | 1/2 = 50.0% |
| 14354 | 1 | 1 | 2/2 = 100.0% |
| 14355 | 1 | 1 | 2/2 = 100.0% |
| 14356 | 1 | 1 | 0/2 = 0.0% |
| 14357 | 1 | 1 | 1/2 = 50.0% |
| 14358 | 2 | 1 | 2/2 = 100.0% |
| 14359 | 2 | 1 | 1/2 = 50.0% |
| 14360 | 2 | 1 | 1/2 = 50.0% |
| 14361 | 2 | 1 | 1/2 = 50.0% |
| 14362 | 2 | 1 | 0/2 = 0.0% |
| 14363 | 1 | 1 | 1/2 = 50.0% |
| 14364 | 2 | 1 | 1/2 = 50.0% |
| 14365 | 1 | 1 | 2/2 = 100.0% |
| 14366 | 2 | 1 | 2/2 = 100.0% |
| 14367 | 1 | 1 | 1/2 = 50.0% |
| 14368 | 2 | 1 | 1/2 = 50.0% |
| 14369 | 2 | 1 | 1/2 = 50.0% |
| 14370 | 1 | 1 | 0/2 = 0.0% |
| 14371 | 1 | 1 | 1/2 = 50.0% |
| 14372 | 1 | 1 | 0/2 = 0.0% |
| 14373 | 2 | 1 | 1/2 = 50.0% |
| 14374 | 1 | 1 | 1/2 = 50.0% |
| 14375 | 1 | 1 | 1/2 = 50.0% |
| 14376 | 1 | 1 | 2/2 = 100.0% |
| 14377 | 1 | 1 | 0/2 = 0.0% |
| 14378 | 2 | 1 | 1/2 = 50.0% |
| 14379 | 2 | 1 | 0/2 = 0.0% |
| 14380 | 1 | 1 | 1/2 = 50.0% |
| 14381 | 2 | 1 | 1/2 = 50.0% |
| 14382 | 2 | 1 | 1/2 = 50.0% |
| 14383 | 1 | 1 | 1/2 = 50.0% |
| 14384 | 2 | 1 | 1/2 = 50.0% |
| 14385 | 1 | 1 | 0/2 = 0.0% |
| 14386 | 1 | 1 | 1/2 = 50.0% |
| 14387 | 1 | 1 | 0/2 = 0.0% |
| 14388 | 1 | 1 | 1/2 = 50.0% |
| 14389 | 2 | 1 | 0/2 = 0.0% |
| 14390 | 2 | 1 | 2/2 = 100.0% |
| 14391 | 1 | 1 | 1/2 = 50.0% |
| 14392 | 1 | 1 | 0/2 = 0.0% |
| 14393 | 1 | 1 | 1/2 = 50.0% |
| 14394 | 1 | 1 | 2/2 = 100.0% |
| 14395 | 2 | 1 | 1/2 = 50.0% |
| 14396 | 1 | 1 | 1/2 = 50.0% |
| 14397 | 2 | 1 | 1/2 = 50.0% |
| 14398 | 2 | 1 | 1/2 = 50.0% |
| 14399 | 1 | 1 | 1/2 = 50.0% |
| 14400 | 1 | 1 | 2/2 = 100.0% |
| 14401 | 1 | 1 | 1/2 = 50.0% |
| 14402 | 1 | 1 | 0/2 = 0.0% |
| 14403 | 2 | 1 | 0/2 = 0.0% |
| 14404 | 2 | 1 | 0/2 = 0.0% |
| 14405 | 1 | 1 | 1/2 = 50.0% |
| 14406 | 2 | 1 | 0/2 = 0.0% |
| 14407 | 1 | 1 | 1/2 = 50.0% |
| 14408 | 2 | 1 | 1/2 = 50.0% |
| 14409 | 1 | 1 | 1/2 = 50.0% |
| 14410 | 1 | 1 | 1/2 = 50.0% |
| 14411 | 1 | 1 | 1/2 = 50.0% |
| 14412 | 1 | 1 | 1/2 = 50.0% |
| 14413 | 2 | 1 | 1/2 = 50.0% |
| 14414 | 2 | 1 | 0/2 = 0.0% |
| 14415 | 2 | 1 | 1/2 = 50.0% |
| 14416 | 1 | 1 | 1/2 = 50.0% |
| 14417 | 2 | 1 | 1/2 = 50.0% |
| 14418 | 2 | 1 | 1/2 = 50.0% |
| 14419 | 2 | 1 | 1/2 = 50.0% |
| 14420 | 2 | 1 | 1/2 = 50.0% |
| 14421 | 1 | 1 | 1/2 = 50.0% |
| 14422 | 2 | 1 | 1/2 = 50.0% |
| 14423 | 2 | 1 | 1/2 = 50.0% |
| 14424 | 1 | 1 | 1/2 = 50.0% |
| 14425 | 2 | 1 | 1/2 = 50.0% |
| 14426 | 2 | 1 | 1/2 = 50.0% |
| 14427 | 2 | 1 | 0/2 = 0.0% |
| 14428 | 2 | 1 | 1/2 = 50.0% |
| 14429 | 2 | 1 | 1/2 = 50.0% |
| 14430 | 1 | 1 | 1/2 = 50.0% |
| 14431 | 1 | 1 | 2/2 = 100.0% |
| 14432 | 1 | 1 | 1/2 = 50.0% |
| 14433 | 1 | 1 | 1/2 = 50.0% |
| 14434 | 2 | 1 | 1/2 = 50.0% |
| 14435 | 1 | 1 | 1/2 = 50.0% |
| 14436 | 1 | 1 | 1/2 = 50.0% |
| 14437 | 2 | 1 | 1/2 = 50.0% |
| 14438 | 1 | 1 | 1/2 = 50.0% |
| 14439 | 1 | 1 | 2/2 = 100.0% |
| 14440 | 2 | 1 | 2/2 = 100.0% |
| 14441 | 1 | 1 | 0/2 = 0.0% |
| 14442 | 2 | 1 | 2/2 = 100.0% |
| 14443 | 1 | 1 | 2/2 = 100.0% |
| 14444 | 2 | 1 | 2/2 = 100.0% |
| 14445 | 1 | 1 | 1/2 = 50.0% |
| 14446 | 2 | 1 | 1/2 = 50.0% |
| 14447 | 2 | 1 | 1/2 = 50.0% |
| 14448 | 1 | 1 | 2/2 = 100.0% |
| 14449 | 2 | 1 | 1/2 = 50.0% |
| 14450 | 1 | 1 | 1/2 = 50.0% |
| 14451 | 2 | 1 | 1/2 = 50.0% |
| 14452 | 2 | 1 | 1/2 = 50.0% |
| 14453 | 2 | 1 | 1/2 = 50.0% |
| 14454 | 1 | 1 | 1/2 = 50.0% |
| 14455 | 1 | 1 | 1/2 = 50.0% |
| 14456 | 2 | 1 | 1/2 = 50.0% |
| 14457 | 1 | 1 | 1/2 = 50.0% |
| 14458 | 2 | 1 | 0/2 = 0.0% |
| 14459 | 1 | 1 | 1/2 = 50.0% |
| 14460 | 2 | 1 | 1/2 = 50.0% |
| 14461 | 1 | 1 | 1/2 = 50.0% |
| 14462 | 1 | 1 | 2/2 = 100.0% |
| 14463 | 2 | 1 | 1/2 = 50.0% |
| 14464 | 2 | 1 | 0/2 = 0.0% |
| 14465 | 1 | 1 | 1/2 = 50.0% |
| 14466 | 2 | 1 | 1/2 = 50.0% |
| 14467 | 2 | 1 | 1/2 = 50.0% |
| 14468 | 1 | 1 | 2/2 = 100.0% |
| 14469 | 2 | 1 | 1/2 = 50.0% |
| 14470 | 1 | 1 | 2/2 = 100.0% |
| 14471 | 2 | 1 | 0/2 = 0.0% |
| 14472 | 1 | 1 | 1/2 = 50.0% |
| 14473 | 2 | 1 | 1/2 = 50.0% |
| 14474 | 2 | 1 | 1/2 = 50.0% |
| 14475 | 1 | 1 | 1/2 = 50.0% |
| 14476 | 1 | 1 | 1/2 = 50.0% |
| 14477 | 1 | 1 | 2/2 = 100.0% |
| 14478 | 2 | 1 | 2/2 = 100.0% |
| 14479 | 1 | 1 | 2/2 = 100.0% |
| 14480 | 2 | 1 | 0/2 = 0.0% |
| 14481 | 2 | 1 | 1/2 = 50.0% |
| 14482 | 1 | 1 | 1/2 = 50.0% |
| 14483 | 1 | 1 | 2/2 = 100.0% |
| 14484 | 1 | 1 | 1/2 = 50.0% |
| 14485 | 1 | 1 | 1/2 = 50.0% |
| 14486 | 1 | 1 | 1/2 = 50.0% |
| 14487 | 1 | 1 | 1/2 = 50.0% |
| 14488 | 2 | 1 | 1/2 = 50.0% |
| 14489 | 1 | 1 | 2/2 = 100.0% |
| 14490 | 1 | 1 | 1/2 = 50.0% |
| 14491 | 1 | 1 | 1/2 = 50.0% |
| 14492 | 2 | 1 | 2/2 = 100.0% |
| 14493 | 2 | 1 | 0/2 = 0.0% |
| 14494 | 1 | 1 | 1/2 = 50.0% |
| 14495 | 2 | 1 | 1/2 = 50.0% |
| 14496 | 2 | 1 | 1/2 = 50.0% |
| 14497 | 2 | 1 | 1/2 = 50.0% |
| 14498 | 2 | 1 | 2/2 = 100.0% |
| 14499 | 1 | 1 | 2/2 = 100.0% |
| 14500 | 1 | 1 | 2/2 = 100.0% |
| 14501 | 2 | 1 | 1/2 = 50.0% |
| 14502 | 2 | 1 | 1/2 = 50.0% |
| 14503 | 2 | 1 | 2/2 = 100.0% |
| 14504 | 2 | 1 | 0/2 = 0.0% |
| 14505 | 1 | 1 | 0/2 = 0.0% |
| 14506 | 1 | 1 | 1/2 = 50.0% |
| 14507 | 2 | 1 | 1/2 = 50.0% |
| 14508 | 2 | 1 | 1/2 = 50.0% |
| 14509 | 2 | 1 | 1/2 = 50.0% |
| 14510 | 2 | 1 | 1/2 = 50.0% |
| 14511 | 1 | 1 | 2/2 = 100.0% |
| 14512 | 1 | 1 | 2/2 = 100.0% |
| 14513 | 1 | 1 | 1/2 = 50.0% |
| 14514 | 1 | 1 | 2/2 = 100.0% |
| 14515 | 1 | 1 | 1/2 = 50.0% |
| 14516 | 1 | 1 | 1/2 = 50.0% |
| 14517 | 1 | 1 | 2/2 = 100.0% |
| 14518 | 2 | 1 | 1/2 = 50.0% |
| 14519 | 2 | 1 | 1/2 = 50.0% |
| 15000 | 2 | 1 | 2/2 = 100.0% |
| 15001 | 2 | 1 | 1/2 = 50.0% |
| 15002 | 1 | 1 | 0/2 = 0.0% |
| 15003 | 1 | 1 | 1/2 = 50.0% |
| 15004 | 1 | 1 | 0/2 = 0.0% |
| 15005 | 2 | 1 | 1/2 = 50.0% |
| 15006 | 2 | 1 | 1/2 = 50.0% |
| 15007 | 2 | 1 | 1/2 = 50.0% |
| 15008 | 1 | 1 | 1/2 = 50.0% |
| 15009 | 2 | 1 | 1/2 = 50.0% |
| 15010 | 1 | 1 | 0/2 = 0.0% |
| 15011 | 2 | 1 | 0/2 = 0.0% |
| 15012 | 2 | 1 | 1/2 = 50.0% |
| 15013 | 2 | 1 | 1/2 = 50.0% |
| 15014 | 1 | 1 | 2/2 = 100.0% |
| 15015 | 2 | 1 | 1/2 = 50.0% |
| 15016 | 2 | 1 | 2/2 = 100.0% |
| 15017 | 1 | 1 | 0/2 = 0.0% |
| 15018 | 2 | 1 | 2/2 = 100.0% |
| 15019 | 2 | 1 | 2/2 = 100.0% |
| 15020 | 2 | 1 | 0/2 = 0.0% |
| 15021 | 1 | 1 | 1/2 = 50.0% |
| 15022 | 1 | 1 | 1/2 = 50.0% |
| 15023 | 1 | 1 | 2/2 = 100.0% |
| 15024 | 1 | 1 | 2/2 = 100.0% |
| 15025 | 1 | 1 | 1/2 = 50.0% |
| 15026 | 1 | 1 | 2/2 = 100.0% |
| 15027 | 1 | 1 | 2/2 = 100.0% |
| 15028 | 2 | 1 | 2/2 = 100.0% |
| 15029 | 1 | 1 | 1/2 = 50.0% |
| 15030 | 1 | 1 | 2/2 = 100.0% |
| 15031 | 2 | 1 | 2/2 = 100.0% |
| 15032 | 1 | 1 | 0/2 = 0.0% |
| 15033 | 1 | 1 | 1/2 = 50.0% |
| 15034 | 1 | 1 | 0/2 = 0.0% |
| 15035 | 1 | 1 | 2/2 = 100.0% |
| 15036 | 2 | 1 | 1/2 = 50.0% |
| 15037 | 1 | 1 | 0/2 = 0.0% |
| 15038 | 2 | 1 | 1/2 = 50.0% |
| 15039 | 2 | 1 | 0/2 = 0.0% |
| 22000 | 2 | 1 | 1/2 = 50.0% |
| 22001 | 2 | 1 | 0/2 = 0.0% |
| 22002 | 2 | 1 | 1/2 = 50.0% |
| 22003 | 2 | 1 | 0/2 = 0.0% |
| 22004 | 2 | 1 | 0/2 = 0.0% |
| 22005 | 1 | 1 | 2/2 = 100.0% |
| 22006 | 2 | 1 | 0/2 = 0.0% |
| 22007 | 2 | 1 | 2/2 = 100.0% |
| 22008 | 2 | 1 | 1/2 = 50.0% |
| 22009 | 1 | 1 | 2/2 = 100.0% |
| 22010 | 1 | 1 | 1/2 = 50.0% |
| 22011 | 1 | 1 | 1/2 = 50.0% |
| 22012 | 1 | 1 | 1/2 = 50.0% |
| 22013 | 1 | 1 | 2/2 = 100.0% |
| 22014 | 1 | 1 | 2/2 = 100.0% |
| 22015 | 2 | 1 | 1/2 = 50.0% |
| 22016 | 1 | 1 | 1/2 = 50.0% |
| 22017 | 1 | 1 | 0/2 = 0.0% |
| 22018 | 2 | 1 | 1/2 = 50.0% |
| 22019 | 1 | 1 | 1/2 = 50.0% |
| 22020 | 2 | 1 | 1/2 = 50.0% |
| 22021 | 1 | 1 | 1/2 = 50.0% |
| 22022 | 1 | 1 | 1/2 = 50.0% |
| 22023 | 2 | 1 | 1/2 = 50.0% |
| 22024 | 2 | 1 | 1/2 = 50.0% |
| 22025 | 2 | 1 | 1/2 = 50.0% |
| 22026 | 1 | 1 | 1/2 = 50.0% |
| 22027 | 1 | 1 | 1/2 = 50.0% |
| 22028 | 2 | 1 | 1/2 = 50.0% |
| 22029 | 2 | 1 | 0/2 = 0.0% |
| 22030 | 2 | 1 | 0/2 = 0.0% |
| 22031 | 2 | 1 | 0/2 = 0.0% |
| 22032 | 1 | 1 | 0/2 = 0.0% |
| 22033 | 1 | 1 | 2/2 = 100.0% |
| 22034 | 1 | 1 | 1/2 = 50.0% |
| 22035 | 1 | 1 | 1/2 = 50.0% |
| 22036 | 2 | 1 | 0/2 = 0.0% |
| 22037 | 1 | 1 | 1/2 = 50.0% |
| 22038 | 1 | 1 | 2/2 = 100.0% |
| 22039 | 2 | 1 | 0/2 = 0.0% |
| 22040 | 1 | 1 | 0/2 = 0.0% |
| 22041 | 1 | 1 | 1/2 = 50.0% |
| 22042 | 1 | 1 | 0/2 = 0.0% |
| 22043 | 1 | 1 | 1/2 = 50.0% |
| 22044 | 2 | 1 | 0/2 = 0.0% |
| 22045 | 2 | 1 | 1/2 = 50.0% |
| 22046 | 1 | 1 | 1/2 = 50.0% |
| 22047 | 1 | 1 | 2/2 = 100.0% |
| 22048 | 2 | 1 | 1/2 = 50.0% |
| 22049 | 1 | 1 | 2/2 = 100.0% |
| 22050 | 1 | 1 | 1/2 = 50.0% |
| 22051 | 1 | 1 | 1/2 = 50.0% |
| 22052 | 2 | 1 | 1/2 = 50.0% |
| 22053 | 1 | 1 | 1/2 = 50.0% |
| 22054 | 2 | 1 | 0/2 = 0.0% |
| 22055 | 2 | 1 | 1/2 = 50.0% |
| 22056 | 1 | 1 | 2/2 = 100.0% |
| 22057 | 1 | 1 | 2/2 = 100.0% |
| 22058 | 1 | 1 | 2/2 = 100.0% |
| 22059 | 1 | 1 | 1/2 = 50.0% |
| 22060 | 1 | 1 | 1/2 = 50.0% |
| 22061 | 2 | 1 | 1/2 = 50.0% |
| 22062 | 2 | 1 | 0/2 = 0.0% |
| 22063 | 1 | 1 | 1/2 = 50.0% |
| 22064 | 2 | 1 | 0/2 = 0.0% |
| 22065 | 1 | 1 | 1/2 = 50.0% |
| 22066 | 2 | 1 | 1/2 = 50.0% |
| 22067 | 1 | 1 | 2/2 = 100.0% |
| 22068 | 1 | 1 | 2/2 = 100.0% |
| 22069 | 1 | 1 | 2/2 = 100.0% |
| 22070 | 2 | 1 | 1/2 = 50.0% |
| 22071 | 2 | 1 | 0/2 = 0.0% |
| 22072 | 1 | 1 | 1/2 = 50.0% |
| 22073 | 2 | 1 | 0/2 = 0.0% |
| 22074 | 1 | 1 | 2/2 = 100.0% |
| 22075 | 1 | 1 | 1/2 = 50.0% |
| 22076 | 1 | 1 | 2/2 = 100.0% |
| 22077 | 1 | 1 | 0/2 = 0.0% |
| 22078 | 2 | 1 | 1/2 = 50.0% |
| 22079 | 1 | 1 | 1/2 = 50.0% |
| 22080 | 1 | 1 | 2/2 = 100.0% |
| 22081 | 2 | 1 | 2/2 = 100.0% |
| 22082 | 2 | 1 | 1/2 = 50.0% |
| 22083 | 2 | 1 | 0/2 = 0.0% |
| 22084 | 1 | 1 | 1/2 = 50.0% |
| 22085 | 1 | 1 | 1/2 = 50.0% |
| 22086 | 1 | 1 | 1/2 = 50.0% |
| 22087 | 2 | 1 | 0/2 = 0.0% |
| 22088 | 1 | 1 | 2/2 = 100.0% |
| 22089 | 1 | 1 | 1/2 = 50.0% |
| 22090 | 2 | 1 | 1/2 = 50.0% |
| 22091 | 2 | 1 | 2/2 = 100.0% |
| 22092 | 2 | 1 | 1/2 = 50.0% |
| 22093 | 1 | 1 | 1/2 = 50.0% |
| 22094 | 1 | 1 | 1/2 = 50.0% |
| 22095 | 1 | 1 | 1/2 = 50.0% |
| 22096 | 2 | 1 | 1/2 = 50.0% |
| 22097 | 1 | 1 | 2/2 = 100.0% |
| 22098 | 2 | 1 | 2/2 = 100.0% |
| 22099 | 1 | 1 | 1/2 = 50.0% |
| 22100 | 2 | 1 | 1/2 = 50.0% |
| 22101 | 2 | 1 | 1/2 = 50.0% |
| 22102 | 2 | 1 | 1/2 = 50.0% |
| 22103 | 2 | 1 | 1/2 = 50.0% |
| 22104 | 2 | 1 | 1/2 = 50.0% |
| 22105 | 1 | 1 | 1/2 = 50.0% |
| 22106 | 2 | 1 | 1/2 = 50.0% |
| 22107 | 2 | 1 | 1/2 = 50.0% |
| 22108 | 1 | 1 | 1/2 = 50.0% |
| 22109 | 1 | 1 | 1/2 = 50.0% |
| 22110 | 2 | 1 | 1/2 = 50.0% |
| 22111 | 2 | 1 | 0/2 = 0.0% |
| 22112 | 1 | 1 | 1/2 = 50.0% |
| 22113 | 1 | 1 | 1/2 = 50.0% |
| 22114 | 2 | 1 | 1/2 = 50.0% |
| 22115 | 2 | 1 | 0/2 = 0.0% |
| 22116 | 2 | 1 | 1/2 = 50.0% |
| 22117 | 2 | 1 | 1/2 = 50.0% |
| 22118 | 2 | 1 | 1/2 = 50.0% |
| 22119 | 2 | 1 | 1/2 = 50.0% |
| 22120 | 1 | 1 | 1/2 = 50.0% |
| 22121 | 1 | 1 | 1/2 = 50.0% |
| 22122 | 2 | 1 | 1/2 = 50.0% |
| 22123 | 1 | 1 | 1/2 = 50.0% |
| 22124 | 2 | 1 | 1/2 = 50.0% |
| 22125 | 2 | 1 | 1/2 = 50.0% |
| 22126 | 1 | 1 | 1/2 = 50.0% |
| 22127 | 2 | 1 | 1/2 = 50.0% |
| 22128 | 2 | 1 | 1/2 = 50.0% |
| 22129 | 1 | 1 | 2/2 = 100.0% |
| 22130 | 1 | 1 | 1/2 = 50.0% |
| 22131 | 2 | 1 | 1/2 = 50.0% |
| 22132 | 1 | 1 | 2/2 = 100.0% |
| 22133 | 2 | 1 | 1/2 = 50.0% |
| 22134 | 1 | 1 | 2/2 = 100.0% |
| 22135 | 2 | 1 | 0/2 = 0.0% |
| 22136 | 2 | 1 | 0/2 = 0.0% |
| 22137 | 2 | 1 | 0/2 = 0.0% |
| 22138 | 1 | 1 | 2/2 = 100.0% |
| 22139 | 2 | 1 | 0/2 = 0.0% |
| 22140 | 1 | 1 | 0/2 = 0.0% |
| 22141 | 2 | 1 | 2/2 = 100.0% |
| 22142 | 1 | 1 | 1/2 = 50.0% |
| 22143 | 1 | 1 | 2/2 = 100.0% |
| 22144 | 2 | 1 | 2/2 = 100.0% |
| 22145 | 1 | 1 | 2/2 = 100.0% |
| 22146 | 2 | 1 | 0/2 = 0.0% |
| 22147 | 2 | 1 | 1/2 = 50.0% |
| 22148 | 1 | 1 | 1/2 = 50.0% |
| 22149 | 2 | 1 | 1/2 = 50.0% |
| 22150 | 1 | 1 | 2/2 = 100.0% |
| 22151 | 1 | 1 | 1/2 = 50.0% |
| 22152 | 1 | 1 | 1/2 = 50.0% |
| 22153 | 2 | 1 | 1/2 = 50.0% |
| 22154 | 1 | 1 | 0/2 = 0.0% |
| 22155 | 2 | 1 | 1/2 = 50.0% |
| 22156 | 1 | 1 | 1/2 = 50.0% |
| 22157 | 1 | 1 | 2/2 = 100.0% |
| 22158 | 2 | 1 | 1/2 = 50.0% |
| 22159 | 2 | 1 | 1/2 = 50.0% |
| 22160 | 2 | 1 | 2/2 = 100.0% |
| 22161 | 2 | 1 | 0/2 = 0.0% |
| 22162 | 1 | 1 | 1/2 = 50.0% |
| 22163 | 1 | 1 | 1/2 = 50.0% |
| 22164 | 2 | 1 | 0/2 = 0.0% |
| 22165 | 1 | 1 | 0/2 = 0.0% |
| 22166 | 2 | 1 | 2/2 = 100.0% |
| 22167 | 2 | 1 | 0/2 = 0.0% |
| 22168 | 1 | 1 | 1/2 = 50.0% |
| 22169 | 2 | 1 | 0/2 = 0.0% |
| 22170 | 1 | 1 | 2/2 = 100.0% |
| 22171 | 2 | 1 | 1/2 = 50.0% |
| 22172 | 1 | 1 | 1/2 = 50.0% |
| 22173 | 1 | 1 | 1/2 = 50.0% |
| 22174 | 2 | 1 | 0/2 = 0.0% |
| 22175 | 2 | 1 | 0/2 = 0.0% |
| 22176 | 2 | 1 | 2/2 = 100.0% |
| 22177 | 1 | 1 | 1/2 = 50.0% |
| 22178 | 1 | 1 | 0/2 = 0.0% |
| 22179 | 1 | 1 | 1/2 = 50.0% |
| 22180 | 1 | 1 | 1/2 = 50.0% |
| 22181 | 1 | 1 | 2/2 = 100.0% |
| 22182 | 1 | 1 | 1/2 = 50.0% |
| 22183 | 2 | 1 | 1/2 = 50.0% |
| 22184 | 2 | 1 | 1/2 = 50.0% |
| 22185 | 2 | 1 | 1/2 = 50.0% |
| 22186 | 2 | 1 | 2/2 = 100.0% |
| 22187 | 2 | 1 | 0/2 = 0.0% |
| 22188 | 1 | 1 | 1/2 = 50.0% |
| 22189 | 2 | 1 | 2/2 = 100.0% |
| 22190 | 1 | 1 | 1/2 = 50.0% |
| 22191 | 1 | 1 | 1/2 = 50.0% |
| 22192 | 1 | 1 | 2/2 = 100.0% |
| 22193 | 2 | 1 | 2/2 = 100.0% |
| 22194 | 2 | 1 | 1/2 = 50.0% |
| 22195 | 2 | 1 | 1/2 = 50.0% |
| 22196 | 2 | 1 | 0/2 = 0.0% |
| 22197 | 1 | 1 | 0/2 = 0.0% |
| 22198 | 2 | 1 | 1/2 = 50.0% |
| 22199 | 1 | 1 | 1/2 = 50.0% |
| 22200 | 2 | 1 | 1/2 = 50.0% |
| 22201 | 2 | 1 | 0/2 = 0.0% |
| 22202 | 2 | 1 | 1/2 = 50.0% |
| 22203 | 2 | 1 | 1/2 = 50.0% |
| 22204 | 2 | 1 | 1/2 = 50.0% |
| 22205 | 2 | 1 | 2/2 = 100.0% |
| 22206 | 2 | 1 | 1/2 = 50.0% |
| 22207 | 2 | 1 | 1/2 = 50.0% |
| 22208 | 2 | 1 | 2/2 = 100.0% |
| 22209 | 1 | 1 | 2/2 = 100.0% |
| 22210 | 2 | 1 | 2/2 = 100.0% |
| 22211 | 2 | 1 | 2/2 = 100.0% |
| 22212 | 1 | 1 | 1/2 = 50.0% |
| 22213 | 2 | 1 | 1/2 = 50.0% |
| 22214 | 2 | 1 | 1/2 = 50.0% |
| 22215 | 2 | 1 | 1/2 = 50.0% |
| 22216 | 2 | 1 | 1/2 = 50.0% |
| 22217 | 1 | 1 | 1/2 = 50.0% |
| 22218 | 2 | 1 | 1/2 = 50.0% |
| 22219 | 1 | 1 | 1/2 = 50.0% |
| 22220 | 2 | 1 | 2/2 = 100.0% |
| 22221 | 1 | 1 | 2/2 = 100.0% |
| 22222 | 2 | 1 | 1/2 = 50.0% |
| 22223 | 2 | 1 | 0/2 = 0.0% |
| 22224 | 2 | 1 | 0/2 = 0.0% |
| 22225 | 1 | 1 | 1/2 = 50.0% |
| 22226 | 2 | 1 | 0/2 = 0.0% |
| 22227 | 1 | 1 | 1/2 = 50.0% |
| 22228 | 2 | 1 | 1/2 = 50.0% |
| 22229 | 1 | 1 | 1/2 = 50.0% |
| 22230 | 1 | 1 | 1/2 = 50.0% |
| 22231 | 1 | 1 | 1/2 = 50.0% |
| 22232 | 1 | 1 | 1/2 = 50.0% |
| 22233 | 1 | 1 | 1/2 = 50.0% |
| 22234 | 2 | 1 | 1/2 = 50.0% |
| 22235 | 2 | 1 | 1/2 = 50.0% |
| 22236 | 1 | 1 | 2/2 = 100.0% |
| 22237 | 2 | 1 | 1/2 = 50.0% |
| 22238 | 1 | 1 | 1/2 = 50.0% |
| 22239 | 2 | 1 | 0/2 = 0.0% |
| 22240 | 2 | 1 | 0/2 = 0.0% |
| 22241 | 2 | 1 | 2/2 = 100.0% |
| 22242 | 2 | 1 | 0/2 = 0.0% |
| 22243 | 1 | 1 | 1/2 = 50.0% |
| 22244 | 1 | 1 | 1/2 = 50.0% |
| 22245 | 2 | 1 | 1/2 = 50.0% |
| 22246 | 2 | 1 | 1/2 = 50.0% |
| 22247 | 1 | 1 | 1/2 = 50.0% |
| 22248 | 2 | 1 | 1/2 = 50.0% |
| 22249 | 2 | 1 | 1/2 = 50.0% |
| 22250 | 1 | 1 | 1/2 = 50.0% |
| 22251 | 2 | 1 | 1/2 = 50.0% |
| 22252 | 2 | 1 | 0/2 = 0.0% |
| 22253 | 2 | 1 | 2/2 = 100.0% |
| 22254 | 1 | 1 | 1/2 = 50.0% |
| 22255 | 2 | 1 | 1/2 = 50.0% |
| 22256 | 1 | 1 | 1/2 = 50.0% |
| 22257 | 2 | 1 | 1/2 = 50.0% |
| 22258 | 2 | 1 | 1/2 = 50.0% |
| 22259 | 2 | 1 | 1/2 = 50.0% |
| 22260 | 1 | 1 | 1/2 = 50.0% |
| 22261 | 2 | 1 | 1/2 = 50.0% |
| 22262 | 2 | 1 | 1/2 = 50.0% |
| 22263 | 1 | 1 | 1/2 = 50.0% |
| 22264 | 1 | 1 | 0/2 = 0.0% |
| 22265 | 2 | 1 | 1/2 = 50.0% |
| 22266 | 1 | 1 | 1/2 = 50.0% |
| 22267 | 2 | 1 | 0/2 = 0.0% |
| 22268 | 2 | 1 | 1/2 = 50.0% |
| 22269 | 1 | 1 | 1/2 = 50.0% |
| 22270 | 1 | 1 | 1/2 = 50.0% |
| 22271 | 1 | 1 | 1/2 = 50.0% |
| 22272 | 1 | 1 | 1/2 = 50.0% |
| 22273 | 2 | 1 | 0/2 = 0.0% |
| 22274 | 2 | 1 | 1/2 = 50.0% |
| 22275 | 1 | 1 | 1/2 = 50.0% |
| 22276 | 1 | 1 | 0/2 = 0.0% |
| 22277 | 2 | 1 | 2/2 = 100.0% |
| 22278 | 2 | 1 | 2/2 = 100.0% |
| 22279 | 2 | 1 | 1/2 = 50.0% |
| 22280 | 2 | 1 | 2/2 = 100.0% |
| 22281 | 1 | 1 | 2/2 = 100.0% |
| 22282 | 1 | 1 | 1/2 = 50.0% |
| 22283 | 1 | 1 | 0/2 = 0.0% |
| 22284 | 2 | 1 | 2/2 = 100.0% |
| 22285 | 1 | 1 | 1/2 = 50.0% |
| 22286 | 1 | 1 | 1/2 = 50.0% |
| 22287 | 1 | 1 | 1/2 = 50.0% |
| 22288 | 2 | 1 | 1/2 = 50.0% |
| 22289 | 1 | 1 | 1/2 = 50.0% |
| 22290 | 2 | 1 | 1/2 = 50.0% |
| 22291 | 2 | 1 | 1/2 = 50.0% |
| 22292 | 2 | 1 | 1/2 = 50.0% |
| 22293 | 2 | 1 | 0/2 = 0.0% |
| 22294 | 2 | 1 | 0/2 = 0.0% |
| 22295 | 2 | 1 | 1/2 = 50.0% |
| 22296 | 1 | 1 | 1/2 = 50.0% |
| 22297 | 1 | 1 | 2/2 = 100.0% |
| 22298 | 1 | 1 | 2/2 = 100.0% |
| 22299 | 2 | 1 | 1/2 = 50.0% |
| 22300 | 2 | 1 | 2/2 = 100.0% |
| 22301 | 1 | 1 | 1/2 = 50.0% |
| 22302 | 1 | 1 | 0/2 = 0.0% |
| 22303 | 2 | 1 | 1/2 = 50.0% |
| 22304 | 1 | 1 | 2/2 = 100.0% |
| 22305 | 2 | 1 | 1/2 = 50.0% |
| 22306 | 2 | 1 | 1/2 = 50.0% |
| 22307 | 2 | 1 | 1/2 = 50.0% |
| 22308 | 2 | 1 | 0/2 = 0.0% |
| 22309 | 1 | 1 | 1/2 = 50.0% |
| 22310 | 1 | 1 | 1/2 = 50.0% |
| 22311 | 1 | 1 | 1/2 = 50.0% |
| 22312 | 2 | 1 | 0/2 = 0.0% |
| 22313 | 1 | 1 | 0/2 = 0.0% |
| 22314 | 2 | 1 | 2/2 = 100.0% |
| 22315 | 1 | 1 | 2/2 = 100.0% |
| 22316 | 1 | 1 | 0/2 = 0.0% |
| 22317 | 2 | 1 | 0/2 = 0.0% |
| 22318 | 1 | 1 | 0/2 = 0.0% |
| 22319 | 2 | 1 | 0/2 = 0.0% |
| 22320 | 1 | 1 | 1/2 = 50.0% |
| 22321 | 1 | 1 | 0/2 = 0.0% |
| 22322 | 1 | 1 | 2/2 = 100.0% |
| 22323 | 2 | 1 | 1/2 = 50.0% |
| 22324 | 1 | 1 | 2/2 = 100.0% |
| 22325 | 1 | 1 | 1/2 = 50.0% |
| 22326 | 1 | 1 | 2/2 = 100.0% |
| 22327 | 1 | 1 | 2/2 = 100.0% |
| 22328 | 1 | 1 | 1/2 = 50.0% |
| 22329 | 1 | 1 | 0/2 = 0.0% |
| 22330 | 2 | 1 | 2/2 = 100.0% |
| 22331 | 1 | 1 | 2/2 = 100.0% |
| 22332 | 2 | 1 | 0/2 = 0.0% |
| 22333 | 2 | 1 | 0/2 = 0.0% |
| 22334 | 1 | 1 | 0/2 = 0.0% |
| 22335 | 2 | 1 | 2/2 = 100.0% |
| 22336 | 1 | 1 | 2/2 = 100.0% |
| 22337 | 1 | 1 | 1/2 = 50.0% |
| 22338 | 2 | 1 | 1/2 = 50.0% |
| 22339 | 2 | 1 | 1/2 = 50.0% |
| 22340 | 2 | 1 | 1/2 = 50.0% |
| 22341 | 2 | 1 | 1/2 = 50.0% |
| 22342 | 2 | 1 | 1/2 = 50.0% |
| 22343 | 1 | 1 | 1/2 = 50.0% |
| 22344 | 2 | 1 | 1/2 = 50.0% |
| 22345 | 1 | 1 | 0/2 = 0.0% |
| 22346 | 2 | 1 | 0/2 = 0.0% |
| 22347 | 1 | 1 | 1/2 = 50.0% |
| 22348 | 2 | 1 | 2/2 = 100.0% |
| 22349 | 2 | 1 | 1/2 = 50.0% |
| 22350 | 2 | 1 | 1/2 = 50.0% |
| 22351 | 2 | 1 | 0/2 = 0.0% |
| 22352 | 1 | 1 | 1/2 = 50.0% |
| 22353 | 2 | 1 | 1/2 = 50.0% |
| 22354 | 2 | 1 | 0/2 = 0.0% |
| 22355 | 1 | 1 | 1/2 = 50.0% |
| 22356 | 1 | 1 | 1/2 = 50.0% |
| 22357 | 2 | 1 | 2/2 = 100.0% |
| 22358 | 2 | 1 | 1/2 = 50.0% |
| 22359 | 2 | 1 | 1/2 = 50.0% |
| 22360 | 1 | 1 | 2/2 = 100.0% |
| 22361 | 1 | 1 | 0/2 = 0.0% |
| 22362 | 1 | 1 | 2/2 = 100.0% |
| 22363 | 1 | 1 | 1/2 = 50.0% |
| 22364 | 2 | 1 | 1/2 = 50.0% |
| 22365 | 2 | 1 | 0/2 = 0.0% |
| 22366 | 1 | 1 | 1/2 = 50.0% |
| 22367 | 2 | 1 | 0/2 = 0.0% |
| 22368 | 1 | 1 | 1/2 = 50.0% |
| 22369 | 1 | 1 | 1/2 = 50.0% |
| 22370 | 2 | 1 | 1/2 = 50.0% |
| 22371 | 2 | 1 | 1/2 = 50.0% |
| 22372 | 1 | 1 | 1/2 = 50.0% |
| 22373 | 1 | 1 | 1/2 = 50.0% |
| 22374 | 1 | 1 | 1/2 = 50.0% |
| 22375 | 1 | 1 | 1/2 = 50.0% |
| 22376 | 2 | 1 | 0/2 = 0.0% |
| 22377 | 1 | 1 | 1/2 = 50.0% |
| 22378 | 1 | 1 | 0/2 = 0.0% |
| 22379 | 2 | 1 | 0/2 = 0.0% |
| 22380 | 2 | 1 | 1/2 = 50.0% |
| 22381 | 1 | 1 | 2/2 = 100.0% |
| 22382 | 2 | 1 | 2/2 = 100.0% |
| 22383 | 1 | 1 | 1/2 = 50.0% |
| 22384 | 1 | 1 | 1/2 = 50.0% |
| 22385 | 2 | 1 | 0/2 = 0.0% |
| 22386 | 1 | 1 | 1/2 = 50.0% |
| 22387 | 1 | 1 | 0/2 = 0.0% |
| 22388 | 2 | 1 | 1/2 = 50.0% |
| 22389 | 1 | 1 | 1/2 = 50.0% |
| 22390 | 2 | 1 | 0/2 = 0.0% |
| 22391 | 2 | 1 | 1/2 = 50.0% |
| 22392 | 1 | 1 | 1/2 = 50.0% |
| 22393 | 2 | 1 | 2/2 = 100.0% |
| 22394 | 1 | 1 | 1/2 = 50.0% |
| 22395 | 1 | 1 | 1/2 = 50.0% |
| 22396 | 2 | 1 | 0/2 = 0.0% |
| 22397 | 2 | 1 | 2/2 = 100.0% |
| 22398 | 1 | 1 | 2/2 = 100.0% |
| 22399 | 1 | 1 | 1/2 = 50.0% |
| 22400 | 2 | 1 | 1/2 = 50.0% |
| 22401 | 1 | 1 | 1/2 = 50.0% |
| 22402 | 1 | 1 | 1/2 = 50.0% |
| 22403 | 2 | 1 | 1/2 = 50.0% |
| 22404 | 2 | 1 | 1/2 = 50.0% |
| 22405 | 2 | 1 | 0/2 = 0.0% |
| 22406 | 1 | 1 | 1/2 = 50.0% |
| 22407 | 1 | 1 | 1/2 = 50.0% |
| 22408 | 1 | 1 | 2/2 = 100.0% |
| 22409 | 2 | 1 | 2/2 = 100.0% |
| 22410 | 1 | 1 | 2/2 = 100.0% |
| 22411 | 2 | 1 | 1/2 = 50.0% |
| 22412 | 2 | 1 | 2/2 = 100.0% |
| 22413 | 2 | 1 | 1/2 = 50.0% |
| 22414 | 1 | 1 | 0/2 = 0.0% |
| 22415 | 2 | 1 | 1/2 = 50.0% |
| 22416 | 1 | 1 | 0/2 = 0.0% |
| 22417 | 2 | 1 | 0/2 = 0.0% |
| 22418 | 2 | 1 | 1/2 = 50.0% |
| 22419 | 1 | 1 | 0/2 = 0.0% |
| 22420 | 2 | 1 | 2/2 = 100.0% |
| 22421 | 1 | 1 | 1/2 = 50.0% |
| 22422 | 1 | 1 | 1/2 = 50.0% |
| 22423 | 2 | 1 | 0/2 = 0.0% |
| 22424 | 1 | 1 | 2/2 = 100.0% |
| 22425 | 1 | 1 | 1/2 = 50.0% |
| 22426 | 1 | 1 | 1/2 = 50.0% |
| 22427 | 1 | 1 | 2/2 = 100.0% |
| 22428 | 2 | 1 | 1/2 = 50.0% |
| 22429 | 1 | 1 | 1/2 = 50.0% |
| 22430 | 1 | 1 | 1/2 = 50.0% |
| 22431 | 1 | 1 | 2/2 = 100.0% |
| 22432 | 2 | 1 | 1/2 = 50.0% |
| 22433 | 1 | 1 | 1/2 = 50.0% |
| 22434 | 1 | 1 | 1/2 = 50.0% |
| 22435 | 1 | 1 | 1/2 = 50.0% |
| 22436 | 2 | 1 | 0/2 = 0.0% |
| 22437 | 2 | 1 | 1/2 = 50.0% |
| 22438 | 1 | 1 | 2/2 = 100.0% |
| 22439 | 1 | 1 | 1/2 = 50.0% |
| 22440 | 2 | 1 | 2/2 = 100.0% |
| 22441 | 1 | 1 | 2/2 = 100.0% |
| 22442 | 1 | 1 | 1/2 = 50.0% |
| 22443 | 1 | 1 | 1/2 = 50.0% |
| 22444 | 2 | 1 | 1/2 = 50.0% |
| 22445 | 1 | 1 | 1/2 = 50.0% |
| 22446 | 2 | 1 | 1/2 = 50.0% |
| 22447 | 1 | 1 | 1/2 = 50.0% |
| 22448 | 1 | 1 | 1/2 = 50.0% |
| 22449 | 1 | 1 | 2/2 = 100.0% |
| 22450 | 1 | 1 | 1/2 = 50.0% |
| 22451 | 1 | 1 | 1/2 = 50.0% |
| 22452 | 1 | 1 | 0/2 = 0.0% |
| 22453 | 1 | 1 | 2/2 = 100.0% |
| 22454 | 1 | 1 | 2/2 = 100.0% |
| 22455 | 2 | 1 | 0/2 = 0.0% |
| 22456 | 1 | 1 | 1/2 = 50.0% |
| 22457 | 2 | 1 | 0/2 = 0.0% |
| 22458 | 1 | 1 | 1/2 = 50.0% |
| 22459 | 1 | 1 | 2/2 = 100.0% |
| 22460 | 2 | 1 | 1/2 = 50.0% |
| 22461 | 2 | 1 | 0/2 = 0.0% |
| 22462 | 1 | 1 | 2/2 = 100.0% |
| 22463 | 2 | 1 | 0/2 = 0.0% |
| 22464 | 1 | 1 | 1/2 = 50.0% |
| 22465 | 2 | 1 | 1/2 = 50.0% |
| 22466 | 1 | 1 | 2/2 = 100.0% |
| 22467 | 1 | 1 | 2/2 = 100.0% |
| 22468 | 1 | 1 | 1/2 = 50.0% |
| 22469 | 1 | 1 | 1/2 = 50.0% |
| 22470 | 1 | 1 | 1/2 = 50.0% |
| 22471 | 1 | 1 | 1/2 = 50.0% |
| 22472 | 2 | 1 | 1/2 = 50.0% |
| 22473 | 1 | 1 | 2/2 = 100.0% |
| 22474 | 1 | 1 | 2/2 = 100.0% |
| 22475 | 1 | 1 | 1/2 = 50.0% |
| 22476 | 1 | 1 | 1/2 = 50.0% |
| 22477 | 1 | 1 | 1/2 = 50.0% |
| 22478 | 1 | 1 | 1/2 = 50.0% |
| 22479 | 1 | 1 | 2/2 = 100.0% |
| 22480 | 2 | 1 | 1/2 = 50.0% |
| 22481 | 2 | 1 | 1/2 = 50.0% |
| 22482 | 1 | 1 | 1/2 = 50.0% |
| 22483 | 2 | 1 | 1/2 = 50.0% |
| 22484 | 1 | 1 | 2/2 = 100.0% |
| 22485 | 1 | 1 | 1/2 = 50.0% |
| 22486 | 1 | 1 | 1/2 = 50.0% |
| 22487 | 2 | 1 | 2/2 = 100.0% |
| 22488 | 2 | 1 | 0/2 = 0.0% |
| 22489 | 2 | 1 | 0/2 = 0.0% |
| 22490 | 2 | 1 | 0/2 = 0.0% |
| 22491 | 2 | 1 | 1/2 = 50.0% |
| 22492 | 2 | 1 | 1/2 = 50.0% |
| 22493 | 1 | 1 | 2/2 = 100.0% |
| 22494 | 1 | 1 | 1/2 = 50.0% |
| 22495 | 1 | 1 | 0/2 = 0.0% |
| 22496 | 2 | 1 | 2/2 = 100.0% |
| 22497 | 2 | 1 | 0/2 = 0.0% |
| 22498 | 2 | 1 | 0/2 = 0.0% |
| 22499 | 2 | 1 | 0/2 = 0.0% |
| 22500 | 2 | 1 | 1/2 = 50.0% |
| 22501 | 2 | 1 | 1/2 = 50.0% |
| 22502 | 1 | 1 | 1/2 = 50.0% |
| 22503 | 2 | 1 | 0/2 = 0.0% |
| 22504 | 1 | 1 | 1/2 = 50.0% |
| 22505 | 2 | 1 | 0/2 = 0.0% |
| 22506 | 1 | 1 | 1/2 = 50.0% |
| 22507 | 1 | 1 | 1/2 = 50.0% |
| 22508 | 1 | 1 | 2/2 = 100.0% |
| 22509 | 1 | 1 | 1/2 = 50.0% |
| 22510 | 1 | 1 | 2/2 = 100.0% |
| 22511 | 2 | 1 | 1/2 = 50.0% |
| 22512 | 1 | 1 | 0/2 = 0.0% |
| 22513 | 2 | 1 | 0/2 = 0.0% |
| 22514 | 1 | 1 | 1/2 = 50.0% |
| 22515 | 2 | 1 | 0/2 = 0.0% |
| 22516 | 2 | 1 | 0/2 = 0.0% |
| 22517 | 2 | 1 | 0/2 = 0.0% |
| 22518 | 1 | 1 | 0/2 = 0.0% |
| 22519 | 1 | 1 | 0/2 = 0.0% |
| 22520 | 1 | 1 | 0/2 = 0.0% |
| 22521 | 2 | 1 | 0/2 = 0.0% |
| 22522 | 2 | 1 | 1/2 = 50.0% |
| 22523 | 2 | 1 | 0/2 = 0.0% |
| 22524 | 1 | 1 | 2/2 = 100.0% |
| 22525 | 1 | 1 | 0/2 = 0.0% |
| 22526 | 1 | 1 | 2/2 = 100.0% |
| 22527 | 2 | 1 | 2/2 = 100.0% |
| 22528 | 2 | 1 | 1/2 = 50.0% |
| 22529 | 1 | 1 | 2/2 = 100.0% |
| 22530 | 1 | 1 | 0/2 = 0.0% |
| 22531 | 2 | 1 | 1/2 = 50.0% |
| 22532 | 1 | 1 | 1/2 = 50.0% |
| 22533 | 2 | 1 | 1/2 = 50.0% |
| 22534 | 1 | 1 | 2/2 = 100.0% |
| 22535 | 2 | 1 | 2/2 = 100.0% |
| 22536 | 1 | 1 | 0/2 = 0.0% |
| 22537 | 1 | 1 | 1/2 = 50.0% |
| 22538 | 1 | 1 | 0/2 = 0.0% |
| 22539 | 1 | 1 | 1/2 = 50.0% |
| 22540 | 1 | 1 | 1/2 = 50.0% |
| 22541 | 2 | 1 | 2/2 = 100.0% |
| 22542 | 1 | 1 | 1/2 = 50.0% |
| 22543 | 1 | 1 | 1/2 = 50.0% |
| 22544 | 2 | 1 | 1/2 = 50.0% |
| 22545 | 2 | 1 | 0/2 = 0.0% |
| 22546 | 2 | 1 | 2/2 = 100.0% |
| 22547 | 1 | 1 | 1/2 = 50.0% |
| 22548 | 1 | 1 | 1/2 = 50.0% |
| 22549 | 2 | 1 | 0/2 = 0.0% |
| 22550 | 1 | 1 | 1/2 = 50.0% |
| 22551 | 2 | 1 | 2/2 = 100.0% |
| 22552 | 1 | 1 | 1/2 = 50.0% |
| 22553 | 2 | 1 | 1/2 = 50.0% |
| 22554 | 1 | 1 | 1/2 = 50.0% |
| 22555 | 2 | 1 | 1/2 = 50.0% |
| 22556 | 1 | 1 | 1/2 = 50.0% |
| 22557 | 1 | 1 | 2/2 = 100.0% |
| 22558 | 1 | 1 | 2/2 = 100.0% |
| 22559 | 1 | 1 | 1/2 = 50.0% |
| 22560 | 1 | 1 | 2/2 = 100.0% |
| 22561 | 2 | 1 | 1/2 = 50.0% |
| 22562 | 2 | 1 | 1/2 = 50.0% |
| 22563 | 2 | 1 | 0/2 = 0.0% |
| 22564 | 1 | 1 | 0/2 = 0.0% |
| 22565 | 1 | 1 | 1/2 = 50.0% |
| 22566 | 1 | 1 | 2/2 = 100.0% |
| 22567 | 1 | 1 | 1/2 = 50.0% |
| 22568 | 1 | 1 | 1/2 = 50.0% |
| 22569 | 1 | 1 | 2/2 = 100.0% |
| 22570 | 2 | 1 | 1/2 = 50.0% |
| 22571 | 2 | 1 | 1/2 = 50.0% |
| 22572 | 1 | 1 | 1/2 = 50.0% |
| 22573 | 2 | 1 | 1/2 = 50.0% |
| 22574 | 2 | 1 | 1/2 = 50.0% |
| 22575 | 2 | 1 | 2/2 = 100.0% |
| 22576 | 1 | 1 | 1/2 = 50.0% |
| 22577 | 2 | 1 | 0/2 = 0.0% |
| 22578 | 2 | 1 | 1/2 = 50.0% |
| 22579 | 1 | 1 | 2/2 = 100.0% |
| 22580 | 2 | 1 | 0/2 = 0.0% |
| 22581 | 2 | 1 | 1/2 = 50.0% |
| 22582 | 1 | 1 | 1/2 = 50.0% |
| 22583 | 2 | 1 | 1/2 = 50.0% |
| 22584 | 2 | 1 | 0/2 = 0.0% |
| 22585 | 2 | 1 | 2/2 = 100.0% |
| 22586 | 2 | 1 | 1/2 = 50.0% |
| 22587 | 2 | 1 | 1/2 = 50.0% |
| 22588 | 2 | 1 | 2/2 = 100.0% |
| 22589 | 1 | 1 | 2/2 = 100.0% |
| 22590 | 1 | 1 | 1/2 = 50.0% |
| 22591 | 1 | 1 | 2/2 = 100.0% |
| 22592 | 1 | 1 | 1/2 = 50.0% |
| 22593 | 2 | 1 | 1/2 = 50.0% |
| 22594 | 2 | 1 | 1/2 = 50.0% |
| 22595 | 1 | 1 | 1/2 = 50.0% |
| 22596 | 2 | 1 | 1/2 = 50.0% |
| 22597 | 1 | 1 | 2/2 = 100.0% |
| 22598 | 1 | 1 | 1/2 = 50.0% |
| 30000 | 2 | 1 | 1/2 = 50.0% |
| the 19 seeds with 10 or more blocks, each once |  | 1311 | mean of seed shares 57.8% (95% CI 51.7% to 64.1%, seeds drawn) |

### Tournament 3

| scored matches | Opus xhigh wins/matches = share | 95% CI (seed blocks drawn, wins over matches) | mean of block shares (a block counts once) | 95% CI | Opus minus Astra, Elo (95% CI) | blocks Opus both / split / Astra both |
|---|---|---|---|---|---|---|
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 38.1% to 68.3% | 52.4% | 38.0% to 66.7% | +25 (-77 to +139) | 6 / 10 / 4 |
| 40 matches, 20 complete seed pairs | 22/40 = 55.0% | 40.0% to 70.0% | 55.0% | 40.0% to 70.0% | +35 (-70 to +146) | 6 / 10 / 4 |

The 41-match estimate adds seed 3030's one scored match, which Astra won, to the 40 matches of complete pairs.

#### Matched against Opus medium vs Astra on the same seeds (tournament 1)

| matched seeds | Opus xhigh wins | Opus medium wins | difference in share (95% CI, seeds drawn) |
|---|---|---|---|
| 10 seeds, 20 matches each | 10/20 | 9/20 | +5.0 pp (-15.0 to +25.0) |

The matched seeds are 3000 to 3009, so the matched estimate is the same whether tournament 3 counts 40 or 41 matches.
<!-- tables:end -->

## Luck-adjusted Round Elo

The leaderboard's Luck-adjusted Elo is Round Elo fitted on round results with the luck of each round's chance events taken out
(`tools/arena/analysis/aivat.py`, an AIVAT-style correction). At each chance event the correction is the expected value of the
outcomes minus the value of the one that came, sum_o P(o) V(o) - V(realised), in round wins:

- **Shots.** P(live) is the chamber's chance given both players' clues together: no move depends on more than that, so the shell
  order is uniform over the orders those clues allow. V is gradient boosting on the public state after the shot (both healths,
  shells and expected lives left, who moves, item counts, round); a shot that ends the round has its exact 0 or 1.
- **Loads.** The two-seat deck of nine compositions is drawn without replacement and refilled when empty, across rounds; P is
  the count left over the deck's size (every recorded load fits the deck). V is a logistic on the health gap and the composition.
- **Round 1's first seat**, a coin flip. V is each starter's mean round 1 result.
- **Item deals.** Each granted item is a uniform draw from the items its seat may still get, under the per-seat and table caps of
  the rules (`ItemRules` in `sim/bend-mp/domain.bend`). The pool is rebuilt from the public events, and a grant outside it stops
  the run (every recorded grant fits). V is a logistic on both inventories, the health gap and who moves first, fitted on the
  state after each deal.
- **Shells shown by items:** glass (the chamber), beer (the shell it ejects) and the phone (a later shell). V is the search's
  value from the regret file: for glass and beer, the value after the reveal and the other shell's value, inferred from the
  chosen move's value and the mover's live chance; for the phone, the chosen move's value minus the value after it. The search's
  values drift with the position, which would credit skill as luck, so each term has its out-of-fold prediction from the state
  before the event removed. Only rounds the search scored throughout get these terms.

There are no decision terms, since the models' policies are unknown. The luck file depends on the regret file, so the wrap-up
rebuilds it after the regret step. The corrections have mean zero for any V that depends only on the history before the event and its outcome, so they leave the
strengths the same in expectation. Each V is fitted out of fold (five folds by seed), so no round is corrected by a model that saw
it. The bias test checks the mean zero: per config, the mean correction per round against zero, with standard errors clustered by
seed, and its correlation with Round Elo fitted on the other half of the seeds. The wrap-up writes the corrections to
`derived/luck.sqlite` (per match and player) and the viewer and the export add them to the round wins before the Round Elo fit, with
the same seed-block bootstrap. The table below is the same fit in Python.

<!-- luck:start -->
6,109 matches, 18,327 rounds. The median 90% half-width falls from ±25 to ±20 Elo (variance of a match's round share 0.085 → 0.058). Spearman rank correlation with the raw ratings 0.972, largest rank change 10. The intervals are measured against the mean config and moved so Engine/7/2000000/sampled reads 0, so they leave out its own noise; its own luck-adjusted interval, -11 to +11, is the uncertainty of that 0.

Bias test: the mean correction per round of each config, seed-clustered, gives chi2 43.5 on 48 configs (p 0.66). Its correlation with Round Elo fitted on the other half of the seeds (20 random halvings) is -0.05.

| config | matches | rounds | Round Elo [90%] | luck-adjusted [90%] |
|---|---|---|---|---|
| gpt-6.1-terra-max | 100 | 300 | +13 [-20, +47] | +20 [-4, +44] |
| claude-sonnet-5-5-max | 142 | 426 | +8 [-22, +37] | +18 [-4, +41] |
| Engine/7/2000000/sampled | 1120 | 3360 | +0 [-13, +14] | +0 [-11, +11] |
| Engine/6/20000/sampled | 236 | 708 | -2 [-21, +19] | -0 [-16, +16] |
| claude-opus-5-5-max | 82 | 246 | +12 [-24, +51] | -3 [-33, +28] |
| claude-opus-5-5-xhigh | 170 | 510 | -7 [-31, +16] | -9 [-27, +7] |
| gpt-6-astra-high | 100 | 300 | +19 [-11, +50] | -11 [-33, +12] |
| gpt-6.1-sol-max | 142 | 426 | -3 [-26, +21] | -20 [-39, -2] |
| gpt-6-astra-medium | 254 | 762 | -17 [-36, +2] | -29 [-43, -14] |
| gpt-6.1-sol-xhigh | 101 | 303 | -33 [-64, -3] | -39 [-62, -16] |
| claude-sonnet-5-5-xhigh | 176 | 528 | -45 [-67, -22] | -46 [-63, -29] |
| gpt-6.1-sol-low | 98 | 294 | -38 [-72, -6] | -48 [-71, -24] |
| gpt-6-astra-low | 80 | 240 | -41 [-72, -10] | -48 [-75, -20] |
| gpt-6-astra-off | 80 | 240 | -69 [-105, -34] | -48 [-77, -20] |
| claude-opus-5-5-high | 80 | 240 | -28 [-64, +10] | -52 [-76, -27] |
| gpt-6.1-terra-high | 82 | 246 | -57 [-92, -18] | -57 [-85, -23] |
| claude-haiku-5-5-max | 111 | 333 | -60 [-86, -35] | -58 [-81, -33] |
| claude-opus-5-5-medium | 334 | 1002 | -55 [-70, -39] | -58 [-71, -47] |
| gpt-6.1-terra-medium | 130 | 390 | -43 [-71, -13] | -59 [-78, -40] |
| gpt-6.1-terra-xhigh | 102 | 306 | -42 [-73, -11] | -59 [-79, -37] |
| gpt-6.1-sol-medium | 271 | 813 | -44 [-64, -25] | -60 [-74, -46] |
| gpt-5.6-terra-max | 90 | 270 | -83 [-119, -46] | -65 [-95, -35] |
| claude-opus-5-5-off/low | 160 | 480 | -64 [-89, -39] | -69 [-86, -49] |
| gpt-6.1-sol-high | 99 | 297 | -57 [-88, -25] | -71 [-91, -49] |
| gpt-5.6-terra-xhigh | 93 | 279 | -69 [-102, -36] | -78 [-107, -48] |
| claude-haiku-5-5-xhigh | 158 | 474 | -93 [-116, -70] | -83 [-102, -64] |
| gpt-6.1-terra-off/low | 242 | 726 | -84 [-102, -64] | -90 [-107, -75] |
| claude-sonnet-5-5-high | 161 | 483 | -94 [-122, -67] | -94 [-115, -74] |
| claude-sonnet-5-5-medium | 364 | 1092 | -101 [-116, -85] | -97 [-110, -85] |
| gpt-5.6-terra-high | 91 | 273 | -105 [-139, -71] | -102 [-131, -72] |
| claude-haiku-5-5-high | 223 | 669 | -98 [-121, -78] | -105 [-122, -90] |
| claude-haiku-5-5-medium | 444 | 1332 | -101 [-114, -87] | -110 [-121, -100] |
| gpt-5.6-terra-medium | 259 | 777 | -124 [-142, -104] | -117 [-132, -101] |
| Engine/2/20000 | 2334 | 7002 | -118 [-129, -107] | -121 [-129, -112] |
| claude-haiku-5-5-low | 278 | 834 | -110 [-129, -91] | -122 [-138, -107] |
| gpt-5.6-terra-low | 91 | 273 | -127 [-162, -93] | -123 [-153, -93] |
| claude-sonnet-5-5-low | 159 | 477 | -141 [-169, -112] | -125 [-147, -104] |
| gpt-6-luna-max | 112 | 336 | -107 [-141, -72] | -131 [-158, -103] |
| claude-sonnet-5-5-off | 164 | 492 | -124 [-149, -100] | -132 [-155, -111] |
| gpt-6-luna-xhigh | 115 | 345 | -103 [-135, -70] | -137 [-160, -115] |
| gpt-6-luna-high | 218 | 654 | -150 [-173, -127] | -160 [-179, -140] |
| claude-haiku-5-5-off | 668 | 2004 | -205 [-219, -191] | -208 [-220, -196] |
| claude-haiku-4-5-20251001-medium | 358 | 1074 | -218 [-237, -200] | -236 [-252, -222] |
| gpt-6-luna-medium | 398 | 1194 | -247 [-265, -231] | -251 [-265, -238] |
| claude-haiku-4-5-20251001-high | 135 | 405 | -247 [-275, -222] | -254 [-279, -230] |
| claude-haiku-4-5-20251001-minimal/low | 292 | 876 | -241 [-262, -221] | -255 [-273, -238] |
| gpt-6-luna-off/low | 396 | 1188 | -306 [-327, -283] | -306 [-323, -289] |
| claude-haiku-4-5-20251001-off | 125 | 375 | -319 [-351, -290] | -306 [-330, -284] |
<!-- luck:end -->

## Elo from play and move quality

The leaderboard's second rating column (`web/src/arena-viewer/page/play-and-moves.ts`) combines each language-model config's
headline rating with the rating its points lost per move predict. Across the configs the headline rating lies close to a line in
points lost per move (on 3,709 matches: Elo = 126 - 71 x points lost per move, centred on the mean config, correlation -0.96).
A config's true distance from the line has a spread of its own, about 17 Elo. The line and the spread are fitted together by
maximum likelihood, each config weighted by the variance of its rating (from its 90% interval) plus the spread plus the slope
squared times the variance of its points lost (clustered by seed block). Each config then takes the precision-weighted mean of its
rating and the line's prediction, so a config with few matches leans on its move scores and one with many on its results. The
median 90% half-width falls from about ±26 to ±20 Elo.

It is checked out of sample by splitting the seeds in half 30 times: the combination fitted on one half is closer to the other
half's luck-adjusted Elo than that half's own rating (RMS error after removing the other half's noise: 16 against 21 Elo over all
configs, 17 against 23 over the top 20, 24 against 29 over the top 6). It trusts the move scorer. Every top-six config sits 23 to
53 Elo above its line prediction and is pulled down 8 to 27; out of sample the top six end up about 15 Elo too low, where results
alone are about 11 too high. Model families differ around the line (spread about 15 Elo), but a family term did not help out of
sample, nor did fitting the line only on configs with many matches. The headline stays the results-only rating.

## Minimax self-play

The Bend minimax player plays itself under the arena's rules (`web/scripts/arena-selfplay.ts`, tables from `tools/arena/analysis/selfplay.py`). Each seed is played twice: once as the seed starts it, once with the first draw answered for the other seat, so the other seat starts round 1. Equal best moves are broken at random from seed, swap and rep.

| run | matches | round 1 starter wins round 1 | round 1 starter wins match |
|---|---|---|---|
| depth 2 | 2000 (1000 seeds) | 53.8% (50.7 to 56.5) | 50.5% (48.0 to 53.1) |
| depth 3 | 2000 (1000 seeds) | 56.8% (54.0 to 59.5) | 52.6% (50.0 to 55.1) |
| depth 4 | 200 (100 seeds) | 56.5% (48.0 to 64.5) | 57.5% (50.0 to 65.0) |

Intervals are 95% bootstraps over whole seeds. What the data show:

- The seat that starts round 1 won round 1 a little more than half the time in all three runs. The match share is closer to even at depth 2 and 3, and its interval reaches 50% at every depth. The smaller match edge may come from the other seat starting round 2; this is a guess, not tested.
- Seat position (first or second in the table) won 46.5 to 50.3% of matches; the depth 4 interval is 40.5 to 52.5%. This does not show that position is worth nothing.
- Seeds differ visibly: the observed shares of single seeds spread widely. The two games of a seed share a random stream, so the table gives the observed spread only, with no test or interval for a seed effect.
- On the 19 arena seeds (depth 3, 10 reps each way) the bot's starter share and the arena's starter share correlate +0.44 over seeds. That is a description of 19 seeds. Seeds 3003 and 3007 were won by the starter in almost every match, and 3006, 3014 and 3017 almost never.

Limits. These are conditional self-play shares of this finite-budget bot (depth 2 to 4, 20000 nodes, static evaluation), not the game's value and not a causal effect of starting. Both seats run the same bot, and after the swap the later chance draws and choices may differ, so a swap pair is two related matches that share initial conditions and a random stream, not the same deal. Repeats on one seed differ only in tie breaks and are also not independent. At depth 3, 6% of decisions and at depth 4, 17% stopped on the budget. The seed is the unit for every interval.
