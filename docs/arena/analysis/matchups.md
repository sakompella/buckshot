# Matchup analysis

Ratings, pair effects, seat and round 1 starter effects for the scored arena matches, from the analysis database ([database.md](../database.md)). All scored matches are two-player. Every rate shows numerator/denominator, a win share counts a split by its share, and every interval is a 95% bootstrap that draws whole units, never single matches or seat swaps: seed blocks (the two seat-swapped matches of one pair and seed) for ratings, and seeds (every block played at a seed, in any pairing) for the headline seat and starter figures. The tables below the line "Tables" are generated: `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` rewrites them, with a fixed RNG seed. Nothing here reads provenance or account data.

**DeepSeek is left out.** Every match with deepseek-v4.1-flash (20 scored matches) is dropped from all cohorts, fits, seat and starter figures and tables, because its free tier refused requests, so its games are not a random sample of what was scheduled. That leaves 3,537 scored matches from the 3,557-match snapshot of 2026-11-04. Every finding below uses these.

## Findings

**Ratings are pooled.** One Bradley-Terry fit covers every scored match of every tournament, so all 49 configs share one Elo scale with the mean at 0, as in the viewer. Tournament 4 gave every older config games against other models, so no rating leans on an assumption that effort gaps carry across opponents. The 13 newest configs have 80 matches each against changing opponents, so their intervals are 152 to 181 Elo wide. `results.md` and the viewer show the same ratings. A second fit on pot share (a config's cash over the match's cash, which credits the round prizes a loser banks) gives the cash rating. Cohorts are only a way to group matches. A cohort is one kind of comparison, pooled over every tournament: Cross-model (every match between different models) or one model's efforts (every match of that model against itself), as in the viewer. There are ten: Cross-model and the efforts of Astra, Haiku 4.5, Haiku 5.5, Luna, Opus, Sol, Sonnet, Terra and Terra 6.1.
- **Coverage.** The Cross-model cohort has 49 entrants and 1,860 matches over 477 of the 1,176 pairs, 1 to 41 matches per pair. Each older effort cohort is a round robin with 20 matches per pair. Opus efforts plays all 15 pairs (2 to 20 matches each), Terra 6.1 efforts all 15 (1 to 3 matches each) and Astra efforts 5 of 6 (1 to 2 matches each). Tournament 5 is finished; the scheduled matches it did not play stay unstarted in the table below.
- **Cross-model medium configs**, win rating (95% CI by seed blocks): astra +149 (+108 to +195), opus +85 (+44 to +129), sol +65 (+26 to +107), sonnet +10 (-31 to +48), haiku 5.5 +1 (-34 to +34), terra -61 (-109 to -16), haiku 4.5 -198 (-249 to -154), luna -262 (-322 to -209). Astra stands above and luna and haiku 4.5 below; the middle ones overlap. Drawing seeds instead of blocks moves the intervals modestly.
- **Top and bottom.** Every config has 80 or more matches. Opus max +218 (+137 to +318), Terra 6.1 max +202 (+120 to +296), Astra high +179 (+98 to +274), Sonnet max +173 (+102 to +242) and Opus xhigh +170 (+118 to +233) lead, and their intervals overlap. Haiku 4.5 off -388, luna low -346 and luna off -341 trail. Intervals are 68 to 206 Elo wide.
- **Effort.** Within each model the top level is xhigh or max in every model with a sweep or effort tournament, Opus included: luna xhigh -26 and max -44 against medium -262, sonnet max +173 against medium +10, haiku 5.5 max +72 (xhigh +61) against medium +1, terra xhigh +7 (max +2) against medium -61, sol max +143 against medium +65, Opus max +218 and xhigh +170 against medium +85, Terra 6.1 max +202 and xhigh +157 against medium +103. Haiku 4.5 has no such level; its top is medium (-198) and minimal (-234). Off or low is the bottom level in the older sweeps: luna low -346, haiku 4.5 off -388, haiku 5.5 off -137, sonnet low -67, terra low -93 and Opus low -7. Opus off (+108, 80 matches, +30 to +193) is above medium. Sol is the exception: high +60 sits at the bottom of a range up to +143 (medium +65), and the intervals overlap. Terra 6.1 runs max +202, xhigh +157, medium +103, off +91, high +85, low +48, and every effort has an interval 159 to 176 Elo wide. The order of neighbouring levels is mostly inside the intervals.
- **Cash.** Cash ratings spread less than win ratings among configs with 80 or more matches (+121 to -222 against +218 to -388), because losers bank round prizes. The two ratings agree on the leaders (Terra 6.1 max +121, Opus max +118, Astra high +116) and the trailers (luna low -222, haiku 4.5 off -216). A config can win less than it earns: Opus low wins 41.2% of its 80 matches yet takes 49.4% of the pot (cash +23, win -7), and terra high wins 44.0% and takes 49.5% (cash -4, win -75). Haiku 5.5 xhigh is the reverse: 54.4% of wins, 50.4% of the pot, cash +12 against win +61.

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
- **Recommendation:** a starter term is worth keeping as an option for future ratings. It lowers held-out loss a lot (Cross-model 0.5858 to 0.5767 per match) and moves the pooled ratings by up to 17.3 Elo. The headline fits stay without it.

**Tournament 3 (Opus xhigh against Astra medium).**
- **41 matches** (21 seed blocks, seed 3030 half): Opus 22/41 = 53.7% (39.0% to 68.3%); Elo gap +25 (-84 to +132), in a fit of the two alone.
- **40 matches** (20 complete seed pairs): Opus 22/40 = 55.0% (40.0% to 70.0%); gap +35 (-70 to +146). Opus won both matches on 6 seeds, split on 10 and lost both on 4.
- **Matched with Opus medium against Astra** on seeds 3000 to 3009, which is the same for 40 and 41 matches: 10/20 against 9/20, +5.0 points (-15.0 to +25.0, seeds drawn).
- Inconclusive either way, as `results.md` says.

## Method
- **Ratings:** the first-seated entrant wins with probability 1/(1 + exp(-(theta_first - theta_second))), and a share w counts as w wins and 1 - w losses. One fit covers every scored match of every tournament. A mean-zero Gaussian prior on theta (standard deviation 3) regularizes the fit; it also shrinks rating differences slightly. Ratings are reported on the Elo scale with the mean of the configs at 0, which is what `web/src/arena-viewer/page/ratings.ts` computes. The win rating counts win shares; the cash rating is the same fit on pot shares. Intervals draw seed blocks 2,000 times, refitting each draw (the viewer draws 200, so its intervals differ by a few Elo).
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
| Astra efforts | 4 | 9 | 2 / 5 | 5/6 | 1 / 2 / 2 | yes | 9 completed, 13 unstarted |
| Cross-model | 51 | 1980 | 635 / 710 | 483/1275 | 1 / 2 / 41 | yes | 1860 completed, 5 partial (skipped), 138 skipped (skipped), 789 unstarted |
| Haiku 4.5 efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| Haiku 5.5 efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Luna efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Opus efforts | 6 | 137 | 58 / 21 | 15/15 | 2 / 5 / 20 | yes | 137 completed, 21 unstarted |
| Sol efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| Sonnet efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Terra 6.1 efforts | 6 | 31 | 7 / 17 | 15/15 | 1 / 2 / 3 | yes | 31 completed, 33 unstarted |
| Terra efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |

### Pooled ratings

| config | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) | pot share | cash rating (Elo, mean 0) | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5-max | 59/80 = 73.8% | +215 | +135 to +316 | +134 to +331 | 64.4% | +117 | +74 to +163 |
| gpt-6.1-terra-max | 58/80 = 72.5% | +199 | +117 to +297 | +118 to +300 | 66.0% | +120 | +81 to +165 |
| gpt-6-astra-high | 57/80 = 71.2% | +177 | +99 to +271 | +94 to +269 | 66.1% | +115 | +78 to +160 |
| claude-sonnet-5-5-max | 94/140 = 67.1% | +169 | +108 to +240 | +84 to +278 | 62.3% | +105 | +71 to +141 |
| claude-opus-5-5-xhigh | 82/150 = 54.7% | +166 | +115 to +224 | +113 to +226 | 53.4% | +98 | +71 to +128 |
| gpt-6.1-terra-xhigh | 56/80 = 70.0% | +155 | +77 to +249 | +73 to +251 | 59.7% | +58 | +14 to +104 |
| gpt-6-astra | 169/254 = 66.5% | +147 | +107 to +191 | +107 to +193 | 60.2% | +83 | +60 to +104 |
| claude-opus-5-5-high | 47/80 = 58.8% | +142 | +67 to +227 | +59 to +243 | 54.7% | +76 | +33 to +124 |
| gpt-6.1-sol-max | 70/122 = 57.4% | +141 | +83 to +200 | +77 to +203 | 54.9% | +94 | +62 to +128 |
| gpt-6-astra-low | 52/80 = 65.0% | +121 | +51 to +205 | +46 to +205 | 59.4% | +62 | +24 to +104 |
| claude-sonnet-5-5-xhigh | 96/160 = 60.0% | +119 | +67 to +178 | +60 to +182 | 54.7% | +55 | +26 to +82 |
| engine-d6s | 37/60 = 61.7% | +111 | +36 to +201 | +52 to +187 | 57.4% | +65 | +23 to +110 |
| claude-opus-5-5-off | 50/80 = 62.5% | +106 | +29 to +187 | +26 to +186 | 58.8% | +62 | +22 to +101 |
| gpt-6.1-terra | 50/80 = 62.5% | +101 | +26 to +186 | +25 to +186 | 57.7% | +48 | +9 to +90 |
| gpt-6-astra-low-recall | 51/80 = 63.7% | +100 | +22 to +185 | +19 to +188 | 55.9% | +30 | -12 to +73 |
| gpt-6.1-terra-off | 52/80 = 65.0% | +89 | +10 to +178 | +11 to +174 | 56.9% | +24 | -17 to +68 |
| gpt-6.1-sol-low | 51/98 = 52.0% | +88 | +14 to +158 | +21 to +156 | 50.9% | +59 | +19 to +99 |
| gpt-6.1-sol-xhigh | 52/101 = 51.5% | +84 | +18 to +151 | +18 to +151 | 52.4% | +67 | +28 to +105 |
| gpt-6.1-terra-high | 51/80 = 63.7% | +83 | +4 to +176 | -2 to +171 | 59.7% | +46 | +5 to +94 |
| claude-opus-5-5 | 188/334 = 56.3% | +76 | +39 to +117 | +40 to +118 | 53.8% | +43 | +24 to +62 |
| claude-haiku-5-5-max | 68/111 = 61.3% | +72 | +12 to +137 | -9 to +165 | 58.7% | +44 | +15 to +75 |
| gpt-6.1-sol | 155/271 = 57.2% | +63 | +19 to +106 | +7 to +126 | 56.8% | +54 | +31 to +76 |
| claude-haiku-5-5-xhigh | 86/158 = 54.4% | +61 | +9 to +116 | +4 to +111 | 50.4% | +12 | -14 to +40 |
| gpt-6.1-sol-high | 47/99 = 47.5% | +58 | -8 to +126 | -13 to +122 | 48.0% | +40 | +1 to +79 |
| gpt-6.1-terra-low | 45/80 = 56.2% | +46 | -36 to +131 | -40 to +128 | 55.5% | +30 | -8 to +68 |
| claude-sonnet-5-5-high | 75/161 = 46.6% | +32 | -33 to +97 | -30 to +93 | 46.9% | +6 | -28 to +39 |
| claude-haiku-5-5-high | 89/173 = 51.4% | +31 | -22 to +87 | -14 to +78 | 50.3% | +5 | -22 to +32 |
| claude-haiku-5-5 | 193/382 = 50.5% | +7 | -25 to +37 | -23 to +37 | 50.3% | -1 | -19 to +15 |
| gpt-5.6-terra-xhigh | 53/93 = 57.0% | +5 | -79 to +90 | -77 to +81 | 55.1% | +31 | -12 to +72 |
| claude-sonnet-5-5 | 175/364 = 48.1% | +4 | -34 to +42 | -45 to +51 | 48.8% | -1 | -22 to +18 |
| gpt-5.6-terra-max | 52/90 = 57.8% | +0 | -83 to +87 | -63 to +70 | 53.8% | +18 | -22 to +63 |
| claude-haiku-5-5-low | 98/194 = 50.5% | -1 | -55 to +53 | -51 to +53 | 51.3% | -3 | -32 to +24 |
| engine-d2 | 27/60 = 45.0% | -6 | -103 to +85 | -108 to +90 | 46.2% | -13 | -56 to +28 |
| claude-opus-5-5-low | 33/80 = 41.2% | -11 | -91 to +66 | -91 to +66 | 49.4% | +22 | -18 to +59 |
| claude-sonnet-5-5-off | 65/164 = 39.6% | -17 | -75 to +37 | -74 to +31 | 42.4% | -24 | -54 to +4 |
| gpt-6-luna-xhigh | 79/115 = 68.7% | -29 | -105 to +51 | -96 to +38 | 63.6% | -11 | -56 to +35 |
| gpt-6-luna-max | 75/112 = 67.0% | -46 | -126 to +38 | -121 to +31 | 63.2% | -15 | -60 to +31 |
| gpt-5.6-terra | 119/259 = 45.9% | -63 | -108 to -19 | -113 to -16 | 48.0% | -25 | -47 to -3 |
| claude-sonnet-5-5-low | 50/159 = 31.4% | -70 | -138 to -11 | -132 to -18 | 39.5% | -41 | -73 to -11 |
| gpt-5.6-terra-high | 40/91 = 44.0% | -78 | -155 to +0 | -143 to -22 | 49.5% | -5 | -44 to +36 |
| gpt-5.6-terra-low | 37/91 = 40.7% | -95 | -176 to -19 | -164 to -24 | 45.5% | -26 | -67 to +14 |
| gpt-6-luna-high | 67/112 = 59.8% | -102 | -197 to -11 | -197 to +10 | 55.5% | -68 | -109 to -27 |
| claude-haiku-5-5-off | 75/202 = 37.1% | -137 | -194 to -84 | -200 to -89 | 39.8% | -100 | -127 to -72 |
| claude-haiku-4-5-20251001 | 114/340 = 33.5% | -200 | -249 to -158 | -250 to -159 | 38.3% | -122 | -148 to -101 |
| claude-haiku-4-5-20251001-minimal | 57/143 = 39.9% | -236 | -310 to -170 | -308 to -178 | 42.5% | -140 | -175 to -107 |
| claude-haiku-4-5-20251001-low | 55/149 = 36.9% | -251 | -325 to -188 | -327 to -189 | 41.9% | -140 | -174 to -107 |
| gpt-6-luna | 74/282 = 26.2% | -264 | -325 to -213 | -316 to -214 | 34.1% | -155 | -184 to -131 |
| claude-haiku-4-5-20251001-high | 47/135 = 34.8% | -282 | -354 to -219 | -384 to -205 | 42.0% | -147 | -182 to -115 |
| gpt-6-luna-off | 29/110 = 26.4% | -343 | -445 to -261 | -461 to -241 | 33.8% | -209 | -258 to -162 |
| gpt-6-luna-low | 28/110 = 25.5% | -348 | -456 to -252 | -423 to -291 | 31.4% | -223 | -274 to -174 |
| claude-haiku-4-5-20251001-off | 28/125 = 22.4% | -390 | -479 to -319 | -494 to -308 | 32.6% | -217 | -255 to -185 |

With a seat term and a round 1 starter term in the fit (position 1 +1 Elo, the starter +51 Elo) the largest rating change is 17.5 Elo.


### Observed pairs against the pooled ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below. Every resample refits the pooled ratings.

#### Astra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-astra vs gpt-6-astra-high | 1/2 = 50.0% | 45.7% | +4.3 | -8.1 to +17.8 |
| gpt-6-astra vs gpt-6-astra-low | 2/2 = 100.0% | 53.7% | +46.3 | +33.9 to +57.1 |
| gpt-6-astra-high vs gpt-6-astra-low | 2/2 = 100.0% | 58.0% | +42.0 | +26.8 to +57.4 |
| gpt-6-astra-high vs gpt-6-astra-low-recall | 0/1 = 0.0% | 60.8% | -60.8 | -75.0 to -43.5 |
| gpt-6-astra-low vs gpt-6-astra-low-recall | 2/2 = 100.0% | 52.9% | +47.1 | +31.3 to +62.8 |
#### Cross-model

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-5-5 | 8/31 = 25.8% | 23.4% | +2.4 | -10.0 to +14.1 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-high | 1/12 = 8.3% | 20.9% | -12.6 | -25.7 to +6.3 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-low | 4/14 = 28.6% | 24.2% | +4.4 | -17.2 to +24.0 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-max | 0/2 = 0.0% | 17.3% | -17.3 | -23.5 to -11.3 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-off | 5/12 = 41.7% | 41.1% | +0.6 | -28.6 to +29.7 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-xhigh | 1/2 = 50.0% | 18.2% | +31.8 | +25.5 to +37.1 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5 | 7/20 = 35.0% | 17.0% | +18.0 | -0.1 to +36.3 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-high | 0/1 = 0.0% | 12.3% | -12.3 | -18.5 to -7.2 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-low | 0/2 = 0.0% | 25.3% | -25.3 | -35.2 to -16.3 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-max | 0/2 = 0.0% | 8.4% | -8.4 | -13.2 to -4.4 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-off | 1/3 = 33.3% | 14.7% | +18.6 | -18.3 to +86.5 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5 | 2/20 = 10.0% | 23.6% | -13.6 | -25.8 to +0.6 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-high | 0/2 = 0.0% | 20.9% | -20.9 | -29.2 to -13.8 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-low | 0/2 = 0.0% | 32.2% | -32.2 | -41.5 to -22.5 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 10.7% | -10.7 | -15.4 to -6.6 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-off | 0/4 = 0.0% | 25.9% | -25.9 | -34.0 to -18.4 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-xhigh | 0/2 = 0.0% | 13.7% | -13.7 | -19.0 to -9.1 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra | 6/20 = 30.0% | 31.3% | -1.3 | -17.3 to +14.2 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-low | 0/2 = 0.0% | 35.4% | -35.4 | -46.7 to -24.0 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-max | 0/2 = 0.0% | 24.1% | -24.1 | -33.9 to -14.5 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-xhigh | 1/2 = 50.0% | 23.6% | +26.4 | +15.8 to +35.2 |
| claude-haiku-4-5-20251001 vs gpt-6-astra | 3/20 = 15.0% | 12.0% | +3.0 | -10.9 to +17.2 |
| claude-haiku-4-5-20251001 vs gpt-6-astra-high | 0/3 = 0.0% | 10.3% | -10.3 | -15.9 to -5.6 |
| claude-haiku-4-5-20251001 vs gpt-6-astra-low | 1/3 = 33.3% | 13.7% | +19.7 | -17.8 to +87.4 |
| claude-haiku-4-5-20251001 vs gpt-6-astra-low-recall | 0/3 = 0.0% | 15.1% | -15.1 | -22.8 to -8.9 |
| claude-haiku-4-5-20251001 vs gpt-6-luna | 12/20 = 60.0% | 59.2% | +0.8 | -26.7 to +25.1 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-high | 1/2 = 50.0% | 36.3% | +13.7 | -1.5 to +25.8 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-off | 2/2 = 100.0% | 69.6% | +30.4 | +18.6 to +43.2 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 27.2% | +22.8 | +11.5 to +32.0 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol | 6/20 = 30.0% | 18.1% | +11.9 | -6.6 to +34.9 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-high | 1/2 = 50.0% | 18.5% | +31.5 | +22.9 to +37.4 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-low | 1/2 = 50.0% | 16.1% | +33.9 | +25.8 to +39.5 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 16.3% | +33.7 | +25.8 to +38.9 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra | 1/3 = 33.3% | 15.1% | +18.3 | -19.0 to +85.9 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-high | 0/4 = 0.0% | 16.4% | -16.4 | -24.8 to -9.4 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-low | 1/3 = 33.3% | 19.5% | +13.8 | -25.1 to +82.6 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-max | 0/3 = 0.0% | 9.1% | -9.1 | -14.9 to -5.0 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-off | 0/4 = 0.0% | 15.9% | -15.9 | -23.7 to -9.4 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 11.5% | -11.5 | -17.5 to -6.7 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5 | 0/1 = 0.0% | 16.0% | -16.0 | -22.9 to -10.8 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-high | 0/1 = 0.0% | 14.2% | -14.2 | -20.5 to -8.7 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-max | 0/1 = 0.0% | 11.5% | -11.5 | -17.7 to -6.7 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-off | 2/10 = 20.0% | 30.3% | -10.3 | -33.9 to +14.6 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-xhigh | 0/1 = 0.0% | 12.2% | -12.2 | -18.1 to -7.4 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-low | 0/1 = 0.0% | 17.4% | -17.4 | -27.5 to -10.3 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-max | 0/2 = 0.0% | 5.4% | -5.4 | -9.4 to -2.6 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-off | 1/2 = 50.0% | 9.7% | +40.3 | -12.0 to +92.9 |
| claude-haiku-4-5-20251001-high vs claude-sonnet-5-5 | 0/2 = 0.0% | 16.2% | -16.2 | -22.6 to -10.7 |
| claude-haiku-4-5-20251001-high vs gpt-5.6-terra | 0/2 = 0.0% | 22.1% | -22.1 | -30.5 to -14.4 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra | 0/2 = 0.0% | 7.8% | -7.8 | -11.7 to -4.8 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-high | 0/2 = 0.0% | 6.7% | -6.7 | -11.3 to -3.4 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-low | 0/2 = 0.0% | 9.0% | -9.0 | -14.3 to -4.9 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-low-recall | 0/3 = 0.0% | 10.0% | -10.0 | -16.8 to -5.5 |
| claude-haiku-4-5-20251001-high vs gpt-6-luna | 0/2 = 0.0% | 47.5% | -47.5 | -59.2 to -34.0 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-sol | 0/2 = 0.0% | 12.1% | -12.1 | -17.7 to -7.6 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra | 1/3 = 33.3% | 10.0% | +23.4 | -13.1 to +90.9 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-high | 0/4 = 0.0% | 10.9% | -10.9 | -17.6 to -5.8 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-low | 0/3 = 0.0% | 13.2% | -13.2 | -21.7 to -7.3 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-max | 0/2 = 0.0% | 5.9% | -5.9 | -10.1 to -3.0 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-off | 0/4 = 0.0% | 10.6% | -10.6 | -17.3 to -5.6 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 7.5% | -7.5 | -12.6 to -4.0 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5 | 1/3 = 33.3% | 18.5% | +14.9 | -22.7 to +35.0 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5-low | 2/11 = 18.2% | 19.1% | -1.0 | -20.8 to +30.6 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5-off | 4/11 = 36.4% | 34.1% | +2.3 | -30.7 to +44.0 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5 | 0/2 = 0.0% | 13.2% | -13.2 | -18.5 to -8.4 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-high | 0/1 = 0.0% | 9.4% | -9.4 | -15.2 to -5.3 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-low | 0/1 = 0.0% | 20.1% | -20.1 | -30.7 to -12.1 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-max | 0/2 = 0.0% | 6.4% | -6.4 | -10.9 to -3.1 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-off | 0/3 = 0.0% | 11.3% | -11.3 | -18.3 to -6.2 |
| claude-haiku-4-5-20251001-low vs gpt-5.6-terra | 1/2 = 50.0% | 25.3% | +24.7 | +15.0 to +32.9 |
| claude-haiku-4-5-20251001-low vs gpt-6-astra-high | 0/3 = 0.0% | 7.8% | -7.8 | -13.1 to -4.0 |
| claude-haiku-4-5-20251001-low vs gpt-6-astra-low | 0/3 = 0.0% | 10.5% | -10.5 | -16.7 to -5.7 |
| claude-haiku-4-5-20251001-low vs gpt-6-astra-low-recall | 1/3 = 33.3% | 11.7% | +21.7 | -15.1 to +89.2 |
| claude-haiku-4-5-20251001-low vs gpt-6-luna | 2/2 = 100.0% | 51.8% | +48.2 | +34.8 to +59.7 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-sol | 0/2 = 0.0% | 14.1% | -14.1 | -20.5 to -9.2 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra | 0/3 = 0.0% | 11.6% | -11.6 | -18.5 to -6.5 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-high | 0/4 = 0.0% | 12.7% | -12.7 | -20.1 to -6.7 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-low | 2/3 = 66.7% | 15.3% | +51.4 | -14.8 to +89.6 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-max | 0/3 = 0.0% | 7.0% | -7.0 | -12.0 to -3.6 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-off | 1/4 = 25.0% | 12.3% | +12.7 | -15.9 to +82.0 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 8.8% | -8.8 | -14.5 to -4.6 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5 | 1/2 = 50.0% | 19.9% | +30.1 | +22.0 to +36.7 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5-low | 0/10 = 0.0% | 20.6% | -20.6 | -29.1 to -13.4 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5-off | 3/11 = 27.3% | 36.2% | -8.9 | -34.4 to +12.8 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5 | 1/2 = 50.0% | 14.2% | +35.8 | +28.9 to +40.6 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5-low | 0/1 = 0.0% | 21.6% | -21.6 | -32.8 to -12.7 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5-max | 0/2 = 0.0% | 7.0% | -7.0 | -11.5 to -3.5 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5-off | 0/2 = 0.0% | 12.3% | -12.3 | -19.2 to -6.8 |
| claude-haiku-4-5-20251001-minimal vs claude-sonnet-5-5 | 1/2 = 50.0% | 20.1% | +29.9 | +21.8 to +36.3 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra | 0/2 = 0.0% | 10.0% | -10.0 | -14.5 to -6.2 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra-high | 0/3 = 0.0% | 8.5% | -8.5 | -14.0 to -4.3 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra-low | 0/2 = 0.0% | 11.4% | -11.4 | -17.9 to -6.2 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra-low-recall | 0/3 = 0.0% | 12.6% | -12.6 | -20.6 to -6.7 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-luna | 1/2 = 50.0% | 54.1% | -4.1 | -16.9 to +8.2 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra | 0/3 = 0.0% | 12.6% | -12.6 | -20.1 to -7.0 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-high | 3/4 = 75.0% | 13.8% | +61.2 | -7.2 to +91.3 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-low | 0/3 = 0.0% | 16.5% | -16.5 | -26.5 to -9.5 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-max | 1/2 = 50.0% | 7.6% | +42.4 | -9.6 to +94.8 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-off | 0/4 = 0.0% | 13.3% | -13.3 | -21.3 to -7.3 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 9.6% | -9.6 | -15.8 to -5.0 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5 | 1/2 = 50.0% | 9.3% | +40.7 | +35.8 to +44.3 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5-off | 3/11 = 27.3% | 18.9% | +8.3 | -19.3 to +42.7 |
| claude-haiku-4-5-20251001-off vs claude-opus-5-5-max | 0/1 = 0.0% | 3.0% | -3.0 | -5.3 to -1.3 |
| claude-haiku-4-5-20251001-off vs claude-opus-5-5-off | 0/2 = 0.0% | 5.5% | -5.5 | -9.3 to -2.8 |
| claude-haiku-4-5-20251001-off vs claude-sonnet-5-5 | 1/2 = 50.0% | 9.4% | +40.6 | +35.5 to +44.2 |
| claude-haiku-4-5-20251001-off vs gpt-5.6-terra | 0/2 = 0.0% | 13.2% | -13.2 | -19.7 to -7.8 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra | 0/2 = 0.0% | 4.4% | -4.4 | -6.7 to -2.4 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-high | 0/2 = 0.0% | 3.7% | -3.7 | -6.5 to -1.8 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-low | 0/2 = 0.0% | 5.0% | -5.0 | -8.7 to -2.5 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-low-recall | 0/2 = 0.0% | 5.6% | -5.6 | -9.9 to -2.8 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-sol | 0/2 = 0.0% | 6.9% | -6.9 | -10.5 to -3.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra | 0/2 = 0.0% | 5.6% | -5.6 | -9.7 to -2.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-high | 0/3 = 0.0% | 6.2% | -6.2 | -10.5 to -2.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-low | 0/2 = 0.0% | 7.5% | -7.5 | -13.0 to -3.7 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-max | 0/2 = 0.0% | 3.3% | -3.3 | -5.9 to -1.5 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-off | 0/3 = 0.0% | 6.0% | -6.0 | -10.2 to -3.0 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 4.2% | -4.2 | -7.2 to -2.0 |
| claude-haiku-5-5 vs claude-opus-5-5 | 7/20 = 35.0% | 40.1% | -5.1 | -22.0 to +9.6 |
| claude-haiku-5-5 vs claude-opus-5-5-high | 0/2 = 0.0% | 31.4% | -31.4 | -41.6 to -20.8 |
| claude-haiku-5-5 vs claude-opus-5-5-low | 1/2 = 50.0% | 52.6% | -2.6 | -13.7 to +9.0 |
| claude-haiku-5-5 vs claude-opus-5-5-max | 1/3 = 33.3% | 23.2% | +10.2 | -27.7 to +32.3 |
| claude-haiku-5-5 vs claude-opus-5-5-off | 2/4 = 50.0% | 36.1% | +13.9 | -36.9 to +67.0 |
| claude-haiku-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 50.3% | +9.7 | -9.9 to +29.2 |
| claude-haiku-5-5 vs claude-sonnet-5-5-high | 1/4 = 25.0% | 46.4% | -21.4 | -52.3 to +9.9 |
| claude-haiku-5-5 vs claude-sonnet-5-5-low | 2/2 = 100.0% | 60.9% | +39.1 | +29.5 to +48.2 |
| claude-haiku-5-5 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 28.2% | -28.2 | -36.5 to -19.3 |
| claude-haiku-5-5 vs claude-sonnet-5-5-off | 1/2 = 50.0% | 53.4% | -3.4 | -12.3 to +5.5 |
| claude-haiku-5-5 vs claude-sonnet-5-5-xhigh | 1/4 = 25.0% | 34.3% | -9.3 | -39.0 to +20.7 |
| claude-haiku-5-5 vs engine-d2 | 11/20 = 55.0% | 51.8% | +3.2 | -17.2 to +24.5 |
| claude-haiku-5-5 vs engine-d6s | 10/20 = 50.0% | 35.3% | +14.7 | +2.2 to +29.4 |
| claude-haiku-5-5 vs gpt-5.6-terra | 13/20 = 65.0% | 59.8% | +5.2 | -8.8 to +19.4 |
| claude-haiku-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 61.9% | +38.1 | +26.8 to +49.4 |
| claude-haiku-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.2% | -14.2 | -24.1 to -2.0 |
| claude-haiku-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 51.0% | +49.0 | +36.3 to +61.2 |
| claude-haiku-5-5 vs gpt-6-astra | 6/20 = 30.0% | 30.9% | -0.9 | -17.0 to +13.9 |
| claude-haiku-5-5 vs gpt-6-astra-high | 1/4 = 25.0% | 27.3% | -2.3 | -34.3 to +60.1 |
| claude-haiku-5-5 vs gpt-6-astra-low | 2/4 = 50.0% | 34.1% | +15.9 | -35.5 to +68.5 |
| claude-haiku-5-5 vs gpt-6-astra-low-recall | 3/4 = 75.0% | 36.8% | +38.2 | -28.9 to +71.3 |
| claude-haiku-5-5 vs gpt-6-luna | 19/20 = 95.0% | 82.6% | +12.4 | +0.8 to +21.4 |
| claude-haiku-5-5 vs gpt-6-luna-high | 1/2 = 50.0% | 65.2% | -15.2 | -26.8 to -0.5 |
| claude-haiku-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.5% | +11.5 | +6.2 to +18.9 |
| claude-haiku-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 57.5% | -7.5 | -18.8 to +6.2 |
| claude-haiku-5-5 vs gpt-6.1-sol | 10/20 = 50.0% | 42.0% | +8.0 | -5.3 to +22.8 |
| claude-haiku-5-5 vs gpt-6.1-sol-high | 2/4 = 50.0% | 42.7% | +7.3 | -2.9 to +16.7 |
| claude-haiku-5-5 vs gpt-6.1-sol-low | 0/2 = 0.0% | 38.5% | -38.5 | -48.2 to -28.2 |
| claude-haiku-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 31.6% | +18.4 | +10.2 to +25.9 |
| claude-haiku-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 39.0% | +11.0 | +1.0 to +20.8 |
| claude-haiku-5-5 vs gpt-6.1-terra | 1/4 = 25.0% | 36.8% | -11.8 | -43.3 to +58.9 |
| claude-haiku-5-5 vs gpt-6.1-terra-high | 1/4 = 25.0% | 39.2% | -14.2 | -46.3 to +56.0 |
| claude-haiku-5-5 vs gpt-6.1-terra-low | 0/4 = 0.0% | 44.3% | -44.3 | -56.6 to -32.1 |
| claude-haiku-5-5 vs gpt-6.1-terra-max | 1/4 = 25.0% | 24.8% | +0.2 | -30.7 to +71.1 |
| claude-haiku-5-5 vs gpt-6.1-terra-off | 1/4 = 25.0% | 38.3% | -13.3 | -45.7 to +57.2 |
| claude-haiku-5-5 vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 29.9% | -29.9 | -40.4 to -19.3 |
| claude-haiku-5-5-high vs claude-opus-5-5 | 1/2 = 50.0% | 43.6% | +6.4 | -3.3 to +14.9 |
| claude-haiku-5-5-high vs claude-opus-5-5-high | 0/2 = 0.0% | 34.6% | -34.6 | -47.2 to -22.8 |
| claude-haiku-5-5-high vs claude-opus-5-5-low | 3/3 = 100.0% | 56.1% | +43.9 | +30.7 to +56.8 |
| claude-haiku-5-5-high vs claude-opus-5-5-max | 0/4 = 0.0% | 25.8% | -25.8 | -37.5 to -15.2 |
| claude-haiku-5-5-high vs claude-opus-5-5-off | 3/4 = 75.0% | 39.5% | +35.5 | -28.7 to +69.0 |
| claude-haiku-5-5-high vs claude-sonnet-5-5 | 2/4 = 50.0% | 53.9% | -3.9 | -58.8 to +51.0 |
| claude-haiku-5-5-high vs gpt-6-astra | 0/2 = 0.0% | 34.0% | -34.0 | -42.8 to -25.1 |
| claude-haiku-5-5-high vs gpt-6-astra-high | 2/4 = 50.0% | 30.2% | +19.8 | -30.8 to +73.2 |
| claude-haiku-5-5-high vs gpt-6-astra-low | 1/4 = 25.0% | 37.4% | -12.4 | -45.2 to +52.9 |
| claude-haiku-5-5-high vs gpt-6-astra-low-recall | 1/4 = 25.0% | 40.2% | -15.2 | -49.4 to +51.0 |
| claude-haiku-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 84.6% | -34.6 | -39.8 to -27.0 |
| claude-haiku-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 45.5% | -45.5 | -54.4 to -35.3 |
| claude-haiku-5-5-high vs gpt-6.1-terra | 2/4 = 50.0% | 40.1% | +9.9 | -46.4 to +58.8 |
| claude-haiku-5-5-high vs gpt-6.1-terra-high | 2/4 = 50.0% | 42.6% | +7.4 | -43.6 to +61.9 |
| claude-haiku-5-5-high vs gpt-6.1-terra-low | 2/4 = 50.0% | 47.9% | +2.1 | -49.3 to +56.1 |
| claude-haiku-5-5-high vs gpt-6.1-terra-max | 0/4 = 0.0% | 27.6% | -27.6 | -39.3 to -16.7 |
| claude-haiku-5-5-high vs gpt-6.1-terra-off | 1/3 = 33.3% | 41.7% | -8.4 | -49.5 to +61.4 |
| claude-haiku-5-5-high vs gpt-6.1-terra-xhigh | 2/4 = 50.0% | 33.0% | +17.0 | -34.8 to +69.8 |
| claude-haiku-5-5-low vs claude-opus-5-5 | 2/2 = 100.0% | 39.0% | +61.0 | +51.2 to +69.3 |
| claude-haiku-5-5-low vs claude-opus-5-5-high | 1/2 = 50.0% | 30.5% | +19.5 | -35.8 to +76.7 |
| claude-haiku-5-5-low vs claude-opus-5-5-low | 0/2 = 0.0% | 51.5% | -51.5 | -64.6 to -38.6 |
| claude-haiku-5-5-low vs claude-opus-5-5-max | 1/3 = 33.3% | 22.4% | +10.9 | -28.1 to +79.2 |
| claude-haiku-5-5-low vs claude-opus-5-5-off | 1/4 = 25.0% | 35.1% | -10.1 | -43.2 to +57.8 |
| claude-haiku-5-5-low vs claude-sonnet-5-5 | 1/2 = 50.0% | 49.2% | +0.8 | -8.3 to +10.0 |
| claude-haiku-5-5-low vs gpt-5.6-terra | 1/2 = 50.0% | 58.8% | -8.8 | -18.0 to +1.3 |
| claude-haiku-5-5-low vs gpt-6-astra | 0/2 = 0.0% | 29.9% | -29.9 | -37.7 to -21.2 |
| claude-haiku-5-5-low vs gpt-6-astra-high | 0/4 = 0.0% | 26.5% | -26.5 | -38.2 to -16.1 |
| claude-haiku-5-5-low vs gpt-6-astra-low | 0/4 = 0.0% | 33.2% | -33.2 | -45.0 to -22.2 |
| claude-haiku-5-5-low vs gpt-6-astra-low-recall | 3/4 = 75.0% | 35.8% | +39.2 | -27.2 to +72.6 |
| claude-haiku-5-5-low vs gpt-6-luna | 1/2 = 50.0% | 82.0% | -32.0 | -37.6 to -24.1 |
| claude-haiku-5-5-low vs gpt-6.1-sol | 2/2 = 100.0% | 40.9% | +59.1 | +48.6 to +67.0 |
| claude-haiku-5-5-low vs gpt-6.1-terra | 3/4 = 75.0% | 35.7% | +39.3 | -23.4 to +72.0 |
| claude-haiku-5-5-low vs gpt-6.1-terra-high | 3/4 = 75.0% | 38.1% | +36.9 | -27.9 to +71.0 |
| claude-haiku-5-5-low vs gpt-6.1-terra-low | 1/4 = 25.0% | 43.2% | -18.2 | -53.0 to +9.3 |
| claude-haiku-5-5-low vs gpt-6.1-terra-max | 1/4 = 25.0% | 24.0% | +1.0 | -30.7 to +70.7 |
| claude-haiku-5-5-low vs gpt-6.1-terra-off | 3/4 = 75.0% | 37.3% | +37.7 | -29.7 to +71.9 |
| claude-haiku-5-5-low vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 29.0% | -29.0 | -40.7 to -18.3 |
| claude-haiku-5-5-max vs claude-opus-5-5 | 2/2 = 100.0% | 49.4% | +50.6 | +39.5 to +60.4 |
| claude-haiku-5-5-max vs claude-sonnet-5-5 | 1/2 = 50.0% | 59.7% | -9.7 | -19.0 to +0.2 |
| claude-haiku-5-5-max vs gpt-5.6-terra | 1/2 = 50.0% | 68.5% | -18.5 | -26.8 to -8.7 |
| claude-haiku-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 51.4% | -1.4 | -11.7 to +9.0 |
| claude-haiku-5-5-off vs claude-opus-5-5-high | 0/1 = 0.0% | 16.7% | -16.7 | -24.9 to -9.9 |
| claude-haiku-5-5-off vs claude-opus-5-5-low | 0/2 = 0.0% | 32.7% | -32.7 | -45.6 to -22.0 |
| claude-haiku-5-5-off vs claude-opus-5-5-max | 0/2 = 0.0% | 11.7% | -11.7 | -18.4 to -6.1 |
| claude-haiku-5-5-off vs claude-opus-5-5-off | 0/3 = 0.0% | 19.8% | -19.8 | -29.1 to -12.3 |
| claude-haiku-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 39.5% | +10.5 | +0.4 to +19.6 |
| claude-haiku-5-5-off vs gpt-6-astra | 0/2 = 0.0% | 16.4% | -16.4 | -22.1 to -11.3 |
| claude-haiku-5-5-off vs gpt-6-astra-high | 1/3 = 33.3% | 14.1% | +19.2 | -18.0 to +87.0 |
| claude-haiku-5-5-off vs gpt-6-astra-low | 0/3 = 0.0% | 18.5% | -18.5 | -27.1 to -11.1 |
| claude-haiku-5-5-off vs gpt-6-astra-low-recall | 1/4 = 25.0% | 20.4% | +4.6 | -26.3 to +73.6 |
| claude-haiku-5-5-off vs gpt-6-luna | 1/2 = 50.0% | 67.5% | -17.5 | -26.8 to -6.6 |
| claude-haiku-5-5-off vs gpt-6.1-sol | 0/2 = 0.0% | 24.0% | -24.0 | -31.9 to -17.3 |
| claude-haiku-5-5-off vs gpt-6.1-terra | 0/3 = 0.0% | 20.3% | -20.3 | -30.0 to -12.3 |
| claude-haiku-5-5-off vs gpt-6.1-terra-high | 0/4 = 0.0% | 22.0% | -22.0 | -32.9 to -12.8 |
| claude-haiku-5-5-off vs gpt-6.1-terra-low | 2/3 = 66.7% | 25.8% | +40.8 | -26.6 to +80.7 |
| claude-haiku-5-5-off vs gpt-6.1-terra-max | 0/3 = 0.0% | 12.6% | -12.6 | -20.3 to -6.9 |
| claude-haiku-5-5-off vs gpt-6.1-terra-off | 0/4 = 0.0% | 21.4% | -21.4 | -31.8 to -13.1 |
| claude-haiku-5-5-off vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 15.7% | -15.7 | -24.2 to -8.9 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5 | 0/2 = 0.0% | 47.8% | -47.8 | -56.8 to -38.4 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-high | 0/2 = 0.0% | 38.5% | -38.5 | -51.4 to -25.7 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-low | 2/3 = 66.7% | 60.3% | +6.4 | -60.0 to +47.6 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-max | 0/3 = 0.0% | 29.2% | -29.2 | -42.2 to -17.7 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-off | 0/4 = 0.0% | 43.6% | -43.6 | -56.8 to -30.8 |
| claude-haiku-5-5-xhigh vs claude-sonnet-5-5 | 1/2 = 50.0% | 58.1% | -8.1 | -17.1 to +0.8 |
| claude-haiku-5-5-xhigh vs gpt-6-astra | 0/2 = 0.0% | 37.9% | -37.9 | -46.8 to -28.7 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-high | 1/4 = 25.0% | 34.0% | -9.0 | -41.8 to +54.1 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-low | 1/4 = 25.0% | 41.5% | -16.5 | -48.6 to +52.0 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-low-recall | 3/4 = 75.0% | 44.4% | +30.6 | -37.5 to +63.7 |
| claude-haiku-5-5-xhigh vs gpt-6-luna | 2/2 = 100.0% | 86.7% | +13.3 | +8.6 to +19.2 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra | 3/4 = 75.0% | 44.3% | +30.7 | -36.7 to +65.1 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-high | 2/4 = 50.0% | 46.8% | +3.2 | -49.3 to +56.3 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-low | 1/4 = 25.0% | 52.1% | -27.1 | -61.4 to +38.0 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-max | 0/4 = 0.0% | 31.1% | -31.1 | -44.1 to -19.9 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-off | 1/3 = 33.3% | 45.9% | -12.6 | -55.0 to +55.2 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-xhigh | 2/4 = 50.0% | 36.9% | +13.1 | -39.7 to +66.3 |
| claude-opus-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 60.2% | -0.2 | -19.1 to +19.4 |
| claude-opus-5-5 vs claude-sonnet-5-5-high | 2/2 = 100.0% | 56.4% | +43.6 | +32.5 to +54.2 |
| claude-opus-5-5 vs claude-sonnet-5-5-low | 2/4 = 50.0% | 70.0% | -20.0 | -74.3 to +34.2 |
| claude-opus-5-5 vs claude-sonnet-5-5-max | 2/2 = 100.0% | 37.0% | +63.0 | +51.4 to +72.0 |
| claude-opus-5-5 vs claude-sonnet-5-5-off | 1/2 = 50.0% | 63.1% | -13.1 | -21.5 to -3.9 |
| claude-opus-5-5 vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 43.8% | +56.2 | +46.1 to +64.3 |
| claude-opus-5-5 vs engine-d2 | 12/20 = 60.0% | 61.7% | -1.7 | -18.9 to +14.9 |
| claude-opus-5-5 vs engine-d6s | 7/20 = 35.0% | 45.0% | -10.0 | -27.0 to +5.0 |
| claude-opus-5-5 vs gpt-5.6-terra | 12/20 = 60.0% | 69.0% | -9.0 | -20.6 to +5.1 |
| claude-opus-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 70.8% | +29.2 | +19.6 to +39.2 |
| claude-opus-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 72.8% | -22.8 | -31.9 to -11.7 |
| claude-opus-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 60.9% | +39.1 | +26.6 to +52.2 |
| claude-opus-5-5 vs gpt-5.6-terra-xhigh | 2/2 = 100.0% | 60.2% | +39.8 | +27.5 to +52.5 |
| claude-opus-5-5 vs gpt-6-astra | 9/20 = 45.0% | 40.0% | +5.0 | -7.8 to +15.3 |
| claude-opus-5-5 vs gpt-6-astra-high | 2/4 = 50.0% | 36.0% | +14.0 | -35.6 to +66.2 |
| claude-opus-5-5 vs gpt-6-astra-low | 2/4 = 50.0% | 43.7% | +6.3 | -46.2 to +58.8 |
| claude-opus-5-5 vs gpt-6-astra-low-recall | 2/4 = 50.0% | 46.6% | +3.4 | -49.2 to +57.7 |
| claude-opus-5-5 vs gpt-6-luna | 16/20 = 80.0% | 87.7% | -7.7 | -30.3 to +10.7 |
| claude-opus-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 92.0% | +8.0 | +4.1 to +13.7 |
| claude-opus-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 66.9% | -16.9 | -27.8 to -3.5 |
| claude-opus-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 64.7% | -14.7 | -24.5 to -2.5 |
| claude-opus-5-5 vs gpt-6.1-sol | 12/20 = 60.0% | 51.9% | +8.1 | -9.2 to +27.2 |
| claude-opus-5-5 vs gpt-6.1-sol-high | 2/2 = 100.0% | 52.7% | +47.3 | +35.7 to +57.4 |
| claude-opus-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 48.4% | +1.6 | -10.3 to +12.8 |
| claude-opus-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 40.9% | +9.1 | -0.5 to +17.6 |
| claude-opus-5-5 vs gpt-6.1-sol-xhigh | 2/4 = 50.0% | 48.9% | +1.1 | -10.0 to +11.4 |
| claude-opus-5-5 vs gpt-6.1-terra | 2/3 = 66.7% | 46.5% | +20.2 | -3.9 to +61.8 |
| claude-opus-5-5 vs gpt-6.1-terra-high | 0/3 = 0.0% | 49.0% | -49.0 | -61.4 to -34.5 |
| claude-opus-5-5 vs gpt-6.1-terra-low | 3/4 = 75.0% | 54.3% | +20.7 | -45.8 to +55.3 |
| claude-opus-5-5 vs gpt-6.1-terra-max | 1/4 = 25.0% | 33.0% | -8.0 | -40.4 to +59.4 |
| claude-opus-5-5 vs gpt-6.1-terra-off | 1/3 = 33.3% | 48.1% | -14.8 | -56.6 to +55.4 |
| claude-opus-5-5 vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 38.9% | -5.6 | -45.8 to +60.4 |
| claude-opus-5-5-high vs claude-sonnet-5-5 | 1/2 = 50.0% | 68.9% | -18.9 | -28.7 to -7.3 |
| claude-opus-5-5-high vs claude-sonnet-5-5-high | 2/2 = 100.0% | 65.4% | +34.6 | +22.6 to +48.2 |
| claude-opus-5-5-high vs claude-sonnet-5-5-low | 2/2 = 100.0% | 77.3% | +22.7 | +13.5 to +33.4 |
| claude-opus-5-5-high vs claude-sonnet-5-5-off | 2/2 = 100.0% | 71.4% | +28.6 | +18.6 to +40.0 |
| claude-opus-5-5-high vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 53.3% | +46.7 | +33.1 to +60.4 |
| claude-opus-5-5-high vs gpt-6-astra | 1/2 = 50.0% | 49.4% | +0.6 | -11.6 to +12.3 |
| claude-opus-5-5-high vs gpt-6-astra-high | 0/1 = 0.0% | 45.1% | -45.1 | -60.2 to -28.6 |
| claude-opus-5-5-high vs gpt-6-astra-low-recall | 0/1 = 0.0% | 56.0% | -56.0 | -70.6 to -39.5 |
| claude-opus-5-5-high vs gpt-6-luna | 2/2 = 100.0% | 91.2% | +8.8 | +4.7 to +13.6 |
| claude-opus-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 61.2% | -61.2 | -72.0 to -47.7 |
| claude-opus-5-5-high vs gpt-6.1-terra-low | 1/1 = 100.0% | 63.5% | +36.5 | +22.2 to +50.9 |
| claude-opus-5-5-high vs gpt-6.1-terra-max | 1/1 = 100.0% | 41.9% | +58.1 | +40.7 to +71.3 |
| claude-opus-5-5-low vs claude-sonnet-5-5 | 2/3 = 66.7% | 47.8% | +18.9 | -4.9 to +59.5 |
| claude-opus-5-5-low vs claude-sonnet-5-5-high | 2/3 = 66.7% | 43.9% | +22.8 | -44.5 to +65.4 |
| claude-opus-5-5-low vs claude-sonnet-5-5-low | 1/2 = 50.0% | 58.4% | -8.4 | -65.3 to +47.8 |
| claude-opus-5-5-low vs claude-sonnet-5-5-off | 0/3 = 0.0% | 50.8% | -50.8 | -63.8 to -37.0 |
| claude-opus-5-5-low vs claude-sonnet-5-5-xhigh | 0/3 = 0.0% | 32.0% | -32.0 | -44.1 to -21.3 |
| claude-opus-5-5-low vs gpt-5.6-terra | 0/2 = 0.0% | 57.4% | -57.4 | -68.1 to -43.0 |
| claude-opus-5-5-low vs gpt-6-astra-high | 0/1 = 0.0% | 25.3% | -25.3 | -38.4 to -13.9 |
| claude-opus-5-5-low vs gpt-6-astra-low | 0/1 = 0.0% | 31.9% | -31.9 | -45.4 to -19.1 |
| claude-opus-5-5-low vs gpt-6-astra-low-recall | 0/1 = 0.0% | 34.5% | -34.5 | -48.5 to -20.8 |
| claude-opus-5-5-low vs gpt-6-luna | 2/2 = 100.0% | 81.1% | +18.9 | +11.3 to +27.4 |
| claude-opus-5-5-low vs gpt-6.1-terra-max | 0/1 = 0.0% | 22.9% | -22.9 | -35.1 to -12.5 |
| claude-opus-5-5-low vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 27.8% | +72.2 | +57.6 to +83.1 |
| claude-opus-5-5-max vs claude-sonnet-5-5 | 3/3 = 100.0% | 77.1% | +22.9 | +13.8 to +32.4 |
| claude-opus-5-5-max vs claude-sonnet-5-5-high | 3/4 = 75.0% | 74.2% | +0.8 | -62.4 to +33.8 |
| claude-opus-5-5-max vs claude-sonnet-5-5-low | 2/3 = 66.7% | 83.8% | -17.1 | -85.5 to +21.2 |
| claude-opus-5-5-max vs claude-sonnet-5-5-off | 3/3 = 100.0% | 79.1% | +20.9 | +11.6 to +31.4 |
| claude-opus-5-5-max vs claude-sonnet-5-5-xhigh | 2/3 = 66.7% | 63.4% | +3.3 | -64.9 to +45.9 |
| claude-opus-5-5-max vs gpt-6-astra | 1/2 = 50.0% | 59.7% | -9.7 | -23.5 to +3.9 |
| claude-opus-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 70.6% | -20.6 | -31.0 to -8.7 |
| claude-opus-5-5-max vs gpt-6.1-terra | 1/2 = 50.0% | 65.8% | -15.8 | -28.6 to -0.2 |
| claude-opus-5-5-off vs claude-sonnet-5-5 | 3/4 = 75.0% | 64.2% | +10.8 | -51.7 to +42.3 |
| claude-opus-5-5-off vs claude-sonnet-5-5-high | 2/4 = 50.0% | 60.5% | -10.5 | -64.4 to +42.4 |
| claude-opus-5-5-off vs claude-sonnet-5-5-low | 3/3 = 100.0% | 73.4% | +26.6 | +16.6 to +39.2 |
| claude-opus-5-5-off vs claude-sonnet-5-5-off | 3/4 = 75.0% | 67.0% | +8.0 | -67.9 to +39.9 |
| claude-opus-5-5-off vs claude-sonnet-5-5-xhigh | 2/4 = 50.0% | 48.0% | +2.0 | -51.1 to +54.8 |
| claude-opus-5-5-off vs gpt-6-astra-high | 1/1 = 100.0% | 39.9% | +60.1 | +43.8 to +74.1 |
| claude-opus-5-5-off vs gpt-6-astra-low | 1/1 = 100.0% | 47.9% | +52.1 | +35.9 to +66.7 |
| claude-opus-5-5-off vs gpt-6-astra-low-recall | 0/1 = 0.0% | 50.8% | -50.8 | -66.4 to -34.4 |
| claude-opus-5-5-off vs gpt-6-luna-xhigh | 1/2 = 50.0% | 68.4% | -18.4 | -30.1 to -3.6 |
| claude-opus-5-5-off vs gpt-6.1-terra | 1/1 = 100.0% | 50.7% | +49.3 | +33.2 to +64.5 |
| claude-opus-5-5-off vs gpt-6.1-terra-low | 1/1 = 100.0% | 58.5% | +41.5 | +26.7 to +55.5 |
| claude-opus-5-5-off vs gpt-6.1-terra-max | 0/1 = 0.0% | 36.9% | -36.9 | -52.9 to -22.5 |
| claude-opus-5-5-off vs gpt-6.1-terra-off | 1/1 = 100.0% | 52.4% | +47.6 | +32.2 to +62.9 |
| claude-opus-5-5-off vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 43.0% | -43.0 | -58.1 to -27.4 |
| claude-opus-5-5-xhigh vs claude-sonnet-5-5-max | 2/10 = 20.0% | 49.6% | -29.6 | -54.6 to -4.1 |
| claude-opus-5-5-xhigh vs gpt-6-astra | 22/41 = 53.7% | 52.8% | +0.8 | -11.1 to +12.4 |
| claude-opus-5-5-xhigh vs gpt-6-astra-high | 2/4 = 50.0% | 48.5% | +1.5 | -52.3 to +56.0 |
| claude-opus-5-5-xhigh vs gpt-6-astra-low | 2/4 = 50.0% | 56.5% | -6.5 | -60.2 to +47.0 |
| claude-opus-5-5-xhigh vs gpt-6-astra-low-recall | 2/4 = 50.0% | 59.4% | -9.4 | -61.4 to +42.7 |
| claude-opus-5-5-xhigh vs gpt-6.1-sol-max | 4/10 = 40.0% | 53.7% | -13.7 | -36.3 to +1.2 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra | 2/3 = 66.7% | 59.3% | +7.4 | -60.2 to +48.8 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-high | 1/3 = 33.3% | 61.7% | -28.4 | -70.0 to +39.7 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-low | 3/3 = 100.0% | 66.6% | +33.4 | +21.8 to +46.8 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-max | 5/5 = 100.0% | 45.3% | +54.7 | +40.2 to +69.4 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-off | 1/3 = 33.3% | 60.9% | -27.5 | -69.4 to +40.2 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 51.7% | -18.4 | -60.4 to +49.5 |
| claude-sonnet-5-5 vs engine-d2 | 10/20 = 50.0% | 51.5% | -1.5 | -19.6 to +16.0 |
| claude-sonnet-5-5 vs engine-d6s | 6/20 = 30.0% | 35.0% | -5.0 | -20.1 to +8.2 |
| claude-sonnet-5-5 vs gpt-5.6-terra | 11/20 = 55.0% | 59.5% | -4.5 | -28.5 to +20.4 |
| claude-sonnet-5-5 vs gpt-5.6-terra-high | 1/2 = 50.0% | 61.6% | -11.6 | -22.0 to +1.1 |
| claude-sonnet-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 63.9% | -13.9 | -24.5 to -2.1 |
| claude-sonnet-5-5 vs gpt-5.6-terra-xhigh | 0/2 = 0.0% | 49.9% | -49.9 | -61.7 to -35.3 |
| claude-sonnet-5-5 vs gpt-6-astra | 7/20 = 35.0% | 30.6% | +4.4 | -10.8 to +18.5 |
| claude-sonnet-5-5 vs gpt-6-astra-high | 3/4 = 75.0% | 27.0% | +48.0 | -25.2 to +80.5 |
| claude-sonnet-5-5 vs gpt-6-astra-low | 1/4 = 25.0% | 33.8% | -8.8 | -40.1 to +67.5 |
| claude-sonnet-5-5 vs gpt-6-astra-low-recall | 2/4 = 50.0% | 36.5% | +13.5 | -40.2 to +66.8 |
| claude-sonnet-5-5 vs gpt-6-luna | 17/20 = 85.0% | 82.4% | +2.6 | -12.4 to +16.6 |
| claude-sonnet-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.4% | +11.6 | +6.3 to +19.3 |
| claude-sonnet-5-5 vs gpt-6-luna-off | 2/2 = 100.0% | 88.1% | +11.9 | +6.6 to +18.3 |
| claude-sonnet-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 54.7% | -4.7 | -16.5 to +7.7 |
| claude-sonnet-5-5 vs gpt-6.1-sol | 8/20 = 40.0% | 41.6% | -1.6 | -20.8 to +17.0 |
| claude-sonnet-5-5 vs gpt-6.1-sol-high | 1/2 = 50.0% | 42.3% | +7.7 | -3.4 to +17.7 |
| claude-sonnet-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 38.2% | +11.8 | -0.0 to +21.5 |
| claude-sonnet-5-5 vs gpt-6.1-sol-max | 0/2 = 0.0% | 31.3% | -31.3 | -39.0 to -23.0 |
| claude-sonnet-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 38.7% | +11.3 | +0.8 to +20.8 |
| claude-sonnet-5-5 vs gpt-6.1-terra | 1/4 = 25.0% | 36.4% | -11.4 | -43.5 to +55.6 |
| claude-sonnet-5-5 vs gpt-6.1-terra-high | 0/4 = 0.0% | 38.8% | -38.8 | -51.2 to -26.3 |
| claude-sonnet-5-5 vs gpt-6.1-terra-low | 2/4 = 50.0% | 44.0% | +6.0 | -45.7 to +60.1 |
| claude-sonnet-5-5 vs gpt-6.1-terra-max | 1/4 = 25.0% | 24.5% | +0.5 | -31.0 to +69.4 |
| claude-sonnet-5-5 vs gpt-6.1-terra-off | 2/4 = 50.0% | 38.0% | +12.0 | -40.4 to +65.8 |
| claude-sonnet-5-5 vs gpt-6.1-terra-xhigh | 3/4 = 75.0% | 29.6% | +45.4 | -22.9 to +77.6 |
| claude-sonnet-5-5-high vs gpt-5.6-terra | 1/2 = 50.0% | 63.3% | -13.3 | -23.2 to -2.7 |
| claude-sonnet-5-5-high vs gpt-6-astra | 2/2 = 100.0% | 34.0% | +66.0 | +54.1 to +74.2 |
| claude-sonnet-5-5-high vs gpt-6-astra-high | 2/4 = 50.0% | 30.3% | +19.7 | -33.2 to +75.3 |
| claude-sonnet-5-5-high vs gpt-6-astra-low | 2/4 = 50.0% | 37.5% | +12.5 | -39.8 to +66.4 |
| claude-sonnet-5-5-high vs gpt-6-astra-low-recall | 0/4 = 0.0% | 40.3% | -40.3 | -55.0 to -26.5 |
| claude-sonnet-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 84.6% | -34.6 | -39.7 to -26.3 |
| claude-sonnet-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 45.5% | -45.5 | -56.2 to -34.7 |
| claude-sonnet-5-5-high vs gpt-6.1-terra | 1/3 = 33.3% | 40.2% | -6.8 | -49.0 to +60.7 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-high | 3/3 = 100.0% | 42.6% | +57.4 | +42.4 to +71.3 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-low | 1/4 = 25.0% | 47.9% | -22.9 | -57.8 to +37.8 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-max | 1/4 = 25.0% | 27.6% | -2.6 | -35.1 to +66.6 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-off | 1/3 = 33.3% | 41.8% | -8.4 | -50.4 to +60.0 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 33.0% | -33.0 | -47.4 to -20.7 |
| claude-sonnet-5-5-low vs gpt-6-astra | 0/2 = 0.0% | 22.3% | -22.3 | -29.8 to -15.5 |
| claude-sonnet-5-5-low vs gpt-6-astra-high | 0/4 = 0.0% | 19.4% | -19.4 | -29.6 to -11.1 |
| claude-sonnet-5-5-low vs gpt-6-astra-low | 0/4 = 0.0% | 25.0% | -25.0 | -36.1 to -15.4 |
| claude-sonnet-5-5-low vs gpt-6-astra-low-recall | 0/4 = 0.0% | 27.3% | -27.3 | -39.3 to -16.6 |
| claude-sonnet-5-5-low vs gpt-6-luna | 1/2 = 50.0% | 75.3% | -25.3 | -33.3 to -13.9 |
| claude-sonnet-5-5-low vs gpt-6.1-sol | 1/2 = 50.0% | 31.7% | +18.3 | +8.2 to +27.0 |
| claude-sonnet-5-5-low vs gpt-6.1-terra | 1/4 = 25.0% | 27.2% | -2.2 | -35.0 to +24.5 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-high | 1/4 = 25.0% | 29.2% | -4.2 | -36.5 to +59.7 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-low | 3/4 = 75.0% | 33.8% | +41.2 | -20.7 to +75.0 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-max | 1/3 = 33.3% | 17.5% | +15.9 | -22.7 to +83.8 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-off | 0/4 = 0.0% | 28.5% | -28.5 | -40.8 to -17.9 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-xhigh | 1/4 = 25.0% | 21.5% | +3.5 | -27.5 to +69.7 |
| claude-sonnet-5-5-max vs gpt-6-astra | 4/10 = 40.0% | 53.2% | -13.2 | -36.6 to +3.6 |
| claude-sonnet-5-5-max vs gpt-6-luna | 2/2 = 100.0% | 92.4% | +7.6 | +4.5 to +11.4 |
| claude-sonnet-5-5-max vs gpt-6.1-sol | 2/2 = 100.0% | 64.8% | +35.2 | +25.1 to +43.8 |
| claude-sonnet-5-5-max vs gpt-6.1-sol-max | 6/10 = 60.0% | 54.1% | +5.9 | -10.7 to +28.9 |
| claude-sonnet-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 56.6% | -6.6 | -16.2 to +4.2 |
| claude-sonnet-5-5-off vs gpt-6-astra | 2/2 = 100.0% | 28.1% | +71.9 | +62.4 to +78.6 |
| claude-sonnet-5-5-off vs gpt-6-astra-high | 0/4 = 0.0% | 24.7% | -24.7 | -36.1 to -15.0 |
| claude-sonnet-5-5-off vs gpt-6-astra-low | 1/4 = 25.0% | 31.2% | -6.2 | -38.7 to +55.5 |
| claude-sonnet-5-5-off vs gpt-6-astra-low-recall | 1/4 = 25.0% | 33.8% | -8.8 | -42.2 to +50.1 |
| claude-sonnet-5-5-off vs gpt-6-luna | 2/2 = 100.0% | 80.6% | +19.4 | +12.8 to +27.1 |
| claude-sonnet-5-5-off vs gpt-6.1-sol | 1/2 = 50.0% | 38.7% | +11.3 | +1.6 to +20.0 |
| claude-sonnet-5-5-off vs gpt-6.1-terra | 0/4 = 0.0% | 33.7% | -33.7 | -45.9 to -22.0 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-high | 0/4 = 0.0% | 36.0% | -36.0 | -48.9 to -22.9 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-low | 1/4 = 25.0% | 41.0% | -16.0 | -49.7 to +51.9 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-max | 1/4 = 25.0% | 22.4% | +2.6 | -28.4 to +73.9 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-off | 1/4 = 25.0% | 35.2% | -10.2 | -43.8 to +57.8 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-xhigh | 1/4 = 25.0% | 27.2% | -2.2 | -33.9 to +65.6 |
| claude-sonnet-5-5-xhigh vs gpt-5.6-terra | 2/2 = 100.0% | 74.1% | +25.9 | +18.1 to +33.9 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra | 1/2 = 50.0% | 46.1% | +3.9 | -5.8 to +13.6 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-high | 1/4 = 25.0% | 41.8% | -16.8 | -50.9 to +48.8 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-low | 3/4 = 75.0% | 49.8% | +25.2 | -40.4 to +59.0 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-low-recall | 4/4 = 100.0% | 52.8% | +47.2 | +34.0 to +61.3 |
| claude-sonnet-5-5-xhigh vs gpt-6-luna | 2/2 = 100.0% | 90.1% | +9.9 | +6.1 to +14.2 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 58.1% | -8.1 | -17.2 to +1.5 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra | 2/3 = 66.7% | 52.7% | +14.0 | -51.8 to +55.7 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-high | 2/3 = 66.7% | 55.2% | +11.4 | -57.4 to +54.9 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-low | 2/4 = 50.0% | 60.4% | -10.4 | -64.3 to +42.8 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-max | 2/4 = 50.0% | 38.7% | +11.3 | -39.6 to +64.5 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-off | 3/3 = 100.0% | 54.3% | +45.7 | +32.6 to +60.5 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-xhigh | 2/3 = 66.7% | 45.0% | +21.7 | -4.1 to +63.1 |
| gpt-5.6-terra vs gpt-6-astra | 5/20 = 25.0% | 23.0% | +2.0 | -13.8 to +18.2 |
| gpt-5.6-terra vs gpt-6-astra-low-recall | 0/1 = 0.0% | 28.1% | -28.1 | -39.3 to -17.9 |
| gpt-5.6-terra vs gpt-6-luna | 15/20 = 75.0% | 76.1% | -1.1 | -22.8 to +17.6 |
| gpt-5.6-terra vs gpt-6-luna-high | 2/2 = 100.0% | 55.6% | +44.4 | +29.2 to +57.4 |
| gpt-5.6-terra vs gpt-6-luna-low | 1/2 = 50.0% | 83.8% | -33.8 | -40.7 to -23.0 |
| gpt-5.6-terra vs gpt-6-luna-max | 2/2 = 100.0% | 47.6% | +52.4 | +38.3 to +64.4 |
| gpt-5.6-terra vs gpt-6-luna-off | 2/2 = 100.0% | 83.4% | +16.6 | +9.6 to +24.7 |
| gpt-5.6-terra vs gpt-6.1-sol | 6/20 = 30.0% | 32.7% | -2.7 | -20.1 to +12.5 |
| gpt-5.6-terra vs gpt-6.1-sol-high | 0/2 = 0.0% | 33.3% | -33.3 | -43.2 to -23.6 |
| gpt-5.6-terra vs gpt-6.1-sol-low | 0/2 = 0.0% | 29.6% | -29.6 | -39.6 to -20.1 |
| gpt-5.6-terra vs gpt-6.1-sol-max | 0/2 = 0.0% | 23.7% | -23.7 | -30.9 to -16.4 |
| gpt-5.6-terra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 30.0% | -30.0 | -39.3 to -20.6 |
| gpt-5.6-terra vs gpt-6.1-terra-off | 0/1 = 0.0% | 29.4% | -29.4 | -41.9 to -18.1 |
| gpt-5.6-terra vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 22.2% | -22.2 | -32.0 to -13.6 |
| gpt-5.6-terra-high vs gpt-6-astra-low-recall | 0/1 = 0.0% | 26.4% | -26.4 | -40.2 to -15.2 |
| gpt-5.6-terra-high vs gpt-6-luna | 1/2 = 50.0% | 74.5% | -24.5 | -33.3 to -12.6 |
| gpt-5.6-terra-high vs gpt-6.1-sol | 1/2 = 50.0% | 30.8% | +19.2 | +7.7 to +27.9 |
| gpt-5.6-terra-low vs gpt-6-astra | 0/2 = 0.0% | 19.9% | -19.9 | -28.2 to -12.7 |
| gpt-5.6-terra-low vs gpt-6.1-terra-high | 0/1 = 0.0% | 26.4% | -26.4 | -39.6 to -13.8 |
| gpt-5.6-terra-max vs gpt-6-astra | 1/2 = 50.0% | 30.0% | +20.0 | +6.7 to +29.8 |
| gpt-5.6-terra-max vs gpt-6-luna | 2/2 = 100.0% | 82.0% | +18.0 | +10.2 to +27.0 |
| gpt-5.6-terra-xhigh vs gpt-6-astra | 0/2 = 0.0% | 30.6% | -30.6 | -41.5 to -20.2 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-high | 1/1 = 100.0% | 27.1% | +72.9 | +56.8 to +84.2 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-low | 1/1 = 100.0% | 33.9% | +66.1 | +49.6 to +78.8 |
| gpt-5.6-terra-xhigh vs gpt-6.1-sol | 0/2 = 0.0% | 41.7% | -41.7 | -53.9 to -28.5 |
| gpt-5.6-terra-xhigh vs gpt-6.1-terra-low | 0/1 = 0.0% | 44.0% | -44.0 | -60.3 to -27.6 |
| gpt-6-astra vs gpt-6-luna | 19/20 = 95.0% | 91.4% | +3.6 | -8.0 to +10.7 |
| gpt-6-astra vs gpt-6-luna-high | 1/2 = 50.0% | 80.7% | -30.7 | -38.2 to -18.8 |
| gpt-6-astra vs gpt-6-luna-max | 2/2 = 100.0% | 75.2% | +24.8 | +15.4 to +35.5 |
| gpt-6-astra vs gpt-6-luna-off | 2/2 = 100.0% | 94.4% | +5.6 | +3.0 to +9.2 |
| gpt-6-astra vs gpt-6-luna-xhigh | 1/2 = 50.0% | 73.3% | -23.3 | -31.6 to -11.6 |
| gpt-6-astra vs gpt-6.1-sol | 12/20 = 60.0% | 61.8% | -1.8 | -19.0 to +16.9 |
| gpt-6-astra vs gpt-6.1-sol-high | 1/2 = 50.0% | 62.5% | -12.5 | -22.2 to -1.8 |
| gpt-6-astra vs gpt-6.1-sol-low | 3/4 = 75.0% | 58.4% | +16.6 | -14.7 to +48.9 |
| gpt-6-astra vs gpt-6.1-sol-max | 6/10 = 60.0% | 50.9% | +9.1 | -7.0 to +31.2 |
| gpt-6-astra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 58.9% | -58.9 | -68.4 to -46.9 |
| gpt-6-astra vs gpt-6.1-terra-max | 0/1 = 0.0% | 42.5% | -42.5 | -56.2 to -29.1 |
| gpt-6-astra-high vs gpt-6.1-sol | 1/2 = 50.0% | 65.8% | -15.8 | -27.2 to -3.7 |
| gpt-6-astra-high vs gpt-6.1-sol-high | 1/1 = 100.0% | 66.5% | +33.5 | +20.2 to +46.4 |
| gpt-6-astra-high vs gpt-6.1-terra | 0/1 = 0.0% | 60.7% | -60.7 | -74.0 to -43.7 |
| gpt-6-astra-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 63.1% | +36.9 | +22.1 to +53.4 |
| gpt-6-astra-high vs gpt-6.1-terra-low | 2/2 = 100.0% | 67.9% | +32.1 | +18.7 to +46.7 |
| gpt-6-astra-high vs gpt-6.1-terra-max | 1/2 = 50.0% | 46.7% | +3.3 | -56.0 to +61.8 |
| gpt-6-astra-high vs gpt-6.1-terra-off | 1/1 = 100.0% | 62.3% | +37.7 | +23.2 to +52.5 |
| gpt-6-astra-high vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 53.2% | -53.2 | -68.1 to -35.4 |
| gpt-6-astra-low vs gpt-6-luna | 2/2 = 100.0% | 90.2% | +9.8 | +5.5 to +15.3 |
| gpt-6-astra-low vs gpt-6.1-sol | 1/2 = 50.0% | 58.2% | -8.2 | -20.3 to +3.7 |
| gpt-6-astra-low vs gpt-6.1-sol-low | 0/1 = 0.0% | 54.7% | -54.7 | -69.5 to -39.1 |
| gpt-6-astra-low vs gpt-6.1-terra | 1/1 = 100.0% | 52.8% | +47.2 | +31.6 to +61.5 |
| gpt-6-astra-low vs gpt-6.1-terra-high | 1/1 = 100.0% | 55.4% | +44.6 | +29.4 to +60.3 |
| gpt-6-astra-low vs gpt-6.1-terra-low | 0/1 = 0.0% | 60.5% | -60.5 | -73.6 to -44.0 |
| gpt-6-astra-low vs gpt-6.1-terra-max | 0/2 = 0.0% | 38.9% | -38.9 | -55.0 to -24.4 |
| gpt-6-astra-low vs gpt-6.1-terra-off | 0/1 = 0.0% | 54.5% | -54.5 | -69.1 to -37.6 |
| gpt-6-astra-low vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 45.1% | +54.9 | +38.2 to +69.5 |
| gpt-6-astra-low-recall vs gpt-6-luna-xhigh | 1/1 = 100.0% | 67.7% | +32.3 | +19.5 to +46.8 |
| gpt-6-astra-low-recall vs gpt-6.1-sol | 0/1 = 0.0% | 55.3% | -55.3 | -68.0 to -41.8 |
| gpt-6-astra-low-recall vs gpt-6.1-terra | 0/1 = 0.0% | 49.9% | -49.9 | -64.7 to -33.4 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-high | 1/1 = 100.0% | 52.5% | +47.5 | +31.5 to +64.1 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-low | 2/2 = 100.0% | 57.7% | +42.3 | +27.1 to +58.2 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-max | 0/1 = 0.0% | 36.1% | -36.1 | -52.0 to -21.0 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-off | 1/1 = 100.0% | 51.5% | +48.5 | +32.0 to +62.8 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 42.2% | +7.8 | -52.0 to +67.0 |
| gpt-6-luna vs gpt-6.1-sol | 3/20 = 15.0% | 13.2% | +1.8 | -11.9 to +16.8 |
| gpt-6-luna vs gpt-6.1-sol-high | 1/2 = 50.0% | 13.5% | +36.5 | +29.4 to +41.2 |
| gpt-6-luna vs gpt-6.1-sol-low | 0/2 = 0.0% | 11.7% | -11.7 | -18.1 to -7.0 |
| gpt-6-luna vs gpt-6.1-sol-max | 0/2 = 0.0% | 8.9% | -8.9 | -12.8 to -5.4 |
| gpt-6-luna vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 11.9% | -11.9 | -17.7 to -7.4 |
| gpt-6-luna-high vs gpt-6.1-sol | 1/2 = 50.0% | 27.9% | +22.1 | +8.8 to +32.5 |
| gpt-6-luna-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 25.6% | +74.4 | +57.6 to +85.7 |
| gpt-6-luna-high vs gpt-6.1-terra-off | 0/1 = 0.0% | 24.9% | -24.9 | -38.2 to -13.0 |
| gpt-6-luna-low vs gpt-6.1-sol | 0/2 = 0.0% | 8.6% | -8.6 | -14.7 to -4.5 |
| gpt-6-luna-max vs gpt-6.1-sol | 0/2 = 0.0% | 34.8% | -34.8 | -47.0 to -23.3 |
| gpt-6-luna-max vs gpt-6.1-terra-off | 1/2 = 50.0% | 31.5% | +18.5 | +3.6 to +30.7 |
| gpt-6-luna-off vs gpt-6.1-sol | 1/2 = 50.0% | 8.8% | +41.2 | +35.5 to +44.8 |
| gpt-6-luna-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 37.1% | +12.9 | -0.7 to +23.6 |
| gpt-6-luna-xhigh vs gpt-6.1-terra-low | 1/2 = 50.0% | 39.4% | +10.6 | -5.7 to +24.6 |
| gpt-6.1-sol vs gpt-6.1-terra | 1/2 = 50.0% | 44.6% | +5.4 | -7.1 to +17.4 |
| gpt-6.1-sol vs gpt-6.1-terra-low | 1/1 = 100.0% | 52.4% | +47.6 | +34.8 to +60.9 |
| gpt-6.1-sol vs gpt-6.1-terra-max | 1/1 = 100.0% | 31.3% | +68.7 | +55.0 to +79.7 |
| gpt-6.1-sol-high vs gpt-6.1-terra | 1/2 = 50.0% | 43.9% | +6.1 | -7.3 to +20.0 |
| gpt-6.1-sol-low vs gpt-6.1-terra-max | 1/1 = 100.0% | 34.5% | +65.5 | +49.6 to +78.6 |
| gpt-6.1-sol-max vs gpt-6.1-terra-max | 1/2 = 50.0% | 41.6% | +8.4 | -5.7 to +22.3 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-high | 1/2 = 50.0% | 50.2% | -0.2 | -13.2 to +15.5 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-max | 0/1 = 0.0% | 34.0% | -34.0 | -47.8 to -19.8 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 40.0% | +10.0 | -4.7 to +23.1 |
#### Haiku 4.5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-high | 9/20 = 45.0% | 61.6% | -16.6 | -34.1 to -0.8 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-low | 12/20 = 60.0% | 57.4% | +2.6 | -16.9 to +20.5 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-minimal | 10/20 = 50.0% | 55.2% | -5.2 | -23.4 to +12.5 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 74.9% | +5.1 | -9.9 to +20.5 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-low | 8/20 = 40.0% | 45.7% | -5.7 | -23.8 to +12.2 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal | 11/20 = 55.0% | 43.4% | +11.6 | -7.4 to +32.1 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 65.1% | -0.1 | -17.0 to +17.9 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-minimal | 6/20 = 30.0% | 47.7% | -17.7 | -37.5 to +1.7 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-off | 15/20 = 75.0% | 68.9% | +6.1 | -9.1 to +20.8 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 70.8% | -5.8 | -27.0 to +14.7 |
#### Haiku 5.5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-5-5 vs claude-haiku-5-5-high | 7/20 = 35.0% | 46.4% | -11.4 | -27.5 to +3.0 |
| claude-haiku-5-5 vs claude-haiku-5-5-low | 8/20 = 40.0% | 51.1% | -11.1 | -29.7 to +6.7 |
| claude-haiku-5-5 vs claude-haiku-5-5-max | 9/20 = 45.0% | 40.6% | +4.4 | -11.9 to +21.0 |
| claude-haiku-5-5 vs claude-haiku-5-5-off | 14/20 = 70.0% | 69.5% | +0.5 | -15.0 to +16.8 |
| claude-haiku-5-5 vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 42.2% | -7.2 | -27.4 to +11.4 |
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 54.7% | +10.3 | -9.2 to +28.9 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 44.1% | +0.9 | -19.3 to +19.8 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 72.5% | -7.5 | -21.3 to +7.6 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 45.7% | -15.7 | -32.2 to -1.2 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 39.6% | -4.6 | -21.8 to +14.2 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 68.6% | -13.6 | -35.2 to +6.2 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 41.1% | -1.1 | -15.5 to +11.9 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 76.9% | +3.1 | -11.5 to +17.2 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 51.6% | -6.6 | -23.5 to +9.1 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 24.2% | +0.8 | -17.3 to +21.1 |
#### Luna efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-luna vs gpt-6-luna-high | 8/20 = 40.0% | 28.3% | +11.7 | -9.5 to +33.8 |
| gpt-6-luna vs gpt-6-luna-low | 12/20 = 60.0% | 61.9% | -1.9 | -25.7 to +19.1 |
| gpt-6-luna vs gpt-6-luna-max | 5/20 = 25.0% | 22.2% | +2.8 | -12.2 to +18.0 |
| gpt-6-luna vs gpt-6-luna-off | 12/20 = 60.0% | 61.2% | -1.2 | -21.5 to +19.1 |
| gpt-6-luna vs gpt-6-luna-xhigh | 2/20 = 10.0% | 20.5% | -10.5 | -22.4 to +3.3 |
| gpt-6-luna-high vs gpt-6-luna-low | 14/20 = 70.0% | 80.5% | -10.5 | -25.1 to +4.5 |
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 42.0% | -7.0 | -27.3 to +12.9 |
| gpt-6-luna-high vs gpt-6-luna-off | 18/20 = 90.0% | 80.0% | +10.0 | -3.1 to +22.4 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 39.6% | +15.4 | -2.4 to +34.9 |
| gpt-6-luna-low vs gpt-6-luna-max | 2/20 = 10.0% | 14.9% | -4.9 | -17.0 to +7.6 |
| gpt-6-luna-low vs gpt-6-luna-off | 8/20 = 40.0% | 49.3% | -9.3 | -27.4 to +6.2 |
| gpt-6-luna-low vs gpt-6-luna-xhigh | 3/20 = 15.0% | 13.7% | +1.3 | -13.5 to +22.8 |
| gpt-6-luna-max vs gpt-6-luna-off | 16/20 = 80.0% | 84.7% | -4.7 | -20.1 to +8.3 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 47.5% | +2.5 | -10.8 to +17.6 |
| gpt-6-luna-off vs gpt-6-luna-xhigh | 2/20 = 10.0% | 14.0% | -4.0 | -14.9 to +9.5 |
#### Opus efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5 vs claude-opus-5-5-high | 9/20 = 45.0% | 40.6% | +4.4 | -15.2 to +24.8 |
| claude-opus-5-5 vs claude-opus-5-5-low | 13/20 = 65.0% | 62.4% | +2.6 | -11.0 to +18.6 |
| claude-opus-5-5 vs claude-opus-5-5-max | 4/10 = 40.0% | 31.1% | +8.9 | -26.8 to +43.1 |
| claude-opus-5-5 vs claude-opus-5-5-off | 3/4 = 75.0% | 45.8% | +29.2 | +2.2 to +64.1 |
| claude-opus-5-5 vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 37.4% | -2.4 | -17.7 to +12.0 |
| claude-opus-5-5-high vs claude-opus-5-5-low | 1/2 = 50.0% | 70.8% | -20.8 | -77.5 to +34.4 |
| claude-opus-5-5-high vs claude-opus-5-5-max | 1/2 = 50.0% | 39.7% | +10.3 | -47.8 to +67.6 |
| claude-opus-5-5-high vs claude-opus-5-5-off | 3/5 = 60.0% | 55.2% | +4.8 | -37.1 to +48.6 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 46.6% | -11.6 | -30.4 to +5.5 |
| claude-opus-5-5-low vs claude-opus-5-5-max | 3/10 = 30.0% | 21.4% | +8.6 | -20.5 to +48.2 |
| claude-opus-5-5-low vs claude-opus-5-5-off | 3/5 = 60.0% | 33.8% | +26.2 | -23.7 to +71.4 |
| claude-opus-5-5-low vs claude-opus-5-5-xhigh | 0/3 = 0.0% | 26.5% | -26.5 | -37.0 to -17.0 |
| claude-opus-5-5-max vs claude-opus-5-5-off | 2/2 = 100.0% | 65.2% | +34.8 | +20.5 to +49.9 |
| claude-opus-5-5-max vs claude-opus-5-5-xhigh | 5/10 = 50.0% | 56.9% | -6.9 | -36.2 to +20.7 |
| claude-opus-5-5-off vs claude-opus-5-5-xhigh | 3/4 = 75.0% | 41.4% | +33.6 | -26.2 to +67.1 |
#### Sol efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-sol vs gpt-6.1-sol-high | 12/20 = 60.0% | 50.7% | +9.3 | -2.8 to +23.7 |
| gpt-6.1-sol vs gpt-6.1-sol-low | 7/20 = 35.0% | 46.5% | -11.5 | -30.9 to +7.1 |
| gpt-6.1-sol vs gpt-6.1-sol-max | 8/20 = 40.0% | 39.0% | +1.0 | -16.3 to +19.2 |
| gpt-6.1-sol vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 46.9% | +3.1 | -18.2 to +25.5 |
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 45.7% | +14.3 | -1.9 to +33.2 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 38.3% | +6.7 | -11.5 to +25.3 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 46.2% | -1.2 | -16.2 to +14.2 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 42.4% | -12.4 | -30.0 to +5.9 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 50.5% | +9.5 | -6.0 to +27.4 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 58.1% | -8.1 | -21.9 to +5.1 |
#### Sonnet efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-sonnet-5-5 vs claude-sonnet-5-5-high | 7/20 = 35.0% | 46.1% | -11.1 | -30.4 to +8.7 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-low | 11/20 = 55.0% | 60.6% | -5.6 | -27.5 to +15.3 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-max | 8/20 = 40.0% | 27.9% | +12.1 | -6.1 to +30.9 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-off | 10/20 = 50.0% | 53.0% | -3.0 | -23.3 to +15.1 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 34.0% | +11.0 | -10.1 to +33.3 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 64.3% | -9.3 | -33.8 to +15.8 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 31.2% | +8.8 | -10.9 to +31.5 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 56.9% | +13.1 | -2.4 to +29.9 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 37.6% | -12.6 | -31.3 to +8.0 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 20.1% | -5.1 | -19.7 to +9.8 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 42.4% | +7.6 | -12.5 to +27.2 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 25.1% | -5.1 | -20.5 to +10.6 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 74.5% | -4.5 | -28.0 to +17.6 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 57.1% | +7.9 | -10.9 to +28.9 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 31.3% | +23.7 | +13.2 to +37.4 |
#### Terra 6.1 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-terra vs gpt-6.1-terra-high | 1/3 = 33.3% | 52.6% | -19.2 | -61.6 to +7.0 |
| gpt-6.1-terra vs gpt-6.1-terra-low | 2/3 = 66.7% | 57.8% | +8.9 | -16.9 to +52.3 |
| gpt-6.1-terra vs gpt-6.1-terra-max | 0/1 = 0.0% | 36.2% | -36.2 | -52.9 to -21.5 |
| gpt-6.1-terra vs gpt-6.1-terra-off | 2/3 = 66.7% | 51.6% | +15.0 | -10.1 to +59.4 |
| gpt-6.1-terra vs gpt-6.1-terra-xhigh | 3/3 = 100.0% | 42.3% | +57.7 | +40.4 to +71.9 |
| gpt-6.1-terra-high vs gpt-6.1-terra-low | 0/1 = 0.0% | 55.3% | -55.3 | -70.3 to -37.7 |
| gpt-6.1-terra-high vs gpt-6.1-terra-max | 0/1 = 0.0% | 33.9% | -33.9 | -50.1 to -20.4 |
| gpt-6.1-terra-high vs gpt-6.1-terra-off | 1/2 = 50.0% | 49.1% | +0.9 | -57.7 to +60.3 |
| gpt-6.1-terra-high vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 39.9% | -6.5 | -48.6 to +68.3 |
| gpt-6.1-terra-low vs gpt-6.1-terra-max | 1/1 = 100.0% | 29.3% | +70.7 | +52.7 to +82.4 |
| gpt-6.1-terra-low vs gpt-6.1-terra-off | 3/3 = 100.0% | 43.8% | +56.2 | +40.2 to +71.8 |
| gpt-6.1-terra-low vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 34.9% | -34.9 | -49.5 to -20.6 |
| gpt-6.1-terra-max vs gpt-6.1-terra-off | 0/1 = 0.0% | 65.3% | -65.3 | -78.1 to -46.8 |
| gpt-6.1-terra-max vs gpt-6.1-terra-xhigh | 3/3 = 100.0% | 56.4% | +43.6 | +27.9 to +59.7 |
| gpt-6.1-terra-off vs gpt-6.1-terra-xhigh | 0/2 = 0.0% | 40.7% | -40.7 | -56.4 to -25.6 |
#### Terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-5.6-terra vs gpt-5.6-terra-high | 10/20 = 50.0% | 52.1% | -2.1 | -16.8 to +11.8 |
| gpt-5.6-terra vs gpt-5.6-terra-low | 11/20 = 55.0% | 54.6% | +0.4 | -15.4 to +16.0 |
| gpt-5.6-terra vs gpt-5.6-terra-max | 8/20 = 40.0% | 41.1% | -1.1 | -19.3 to +19.7 |
| gpt-5.6-terra vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 40.4% | -5.4 | -21.4 to +8.7 |
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 52.5% | -7.5 | -26.4 to +9.7 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.1% | +0.9 | -16.4 to +16.8 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 38.4% | +11.6 | -6.9 to +31.9 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 36.7% | +3.3 | -16.1 to +24.0 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 36.0% | -16.0 | -31.0 to -2.6 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 49.3% | +5.7 | -10.0 to +22.2 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| Astra efforts | - | - | - | - | - | - | 7 seed blocks, under the minimum of 10: the fit with seat and starter terms can be singular on so few, so not tested |
| Cross-model | 0.5924 | 0.5926 | -0.0003 | -0.0004 to -0.0001 | 0: 44, 0.1: 2, 0.2: 3, 0.4: 1 | tau=0.1: 0.5925, tau=0.2: 0.5928, tau=0.4: 0.5941, tau=0.8: 0.5999, tau=1.6: 0.6199 | not kept |
| Cross-model (seat and starter terms) | 0.5826 | 0.5826 | -0.0001 | -0.0001 to +0.0000 | 0: 42, 0.1: 5, 0.2: 3 | tau=0.1: 0.5827, tau=0.2: 0.5829, tau=0.4: 0.5841, tau=0.8: 0.5894, tau=1.6: 0.6081 | not kept |
| Haiku 4.5 efforts | 0.6728 | 0.6763 | -0.0034 | -0.0068 to -0.0004 | 0: 26, 0.1: 7, 0.2: 9, 0.4: 8 | tau=0.1: 0.6728, tau=0.2: 0.6730, tau=0.4: 0.6754, tau=0.8: 0.6830, tau=1.6: 0.6906 | not kept |
| Haiku 4.5 efforts (seat and starter terms) | 0.6748 | 0.6796 | -0.0047 | -0.0095 to -0.0001 | 0: 20, 0.1: 5, 0.2: 10, 0.4: 13, 0.8: 2 | tau=0.1: 0.6747, tau=0.2: 0.6748, tau=0.4: 0.6768, tau=0.8: 0.6838, tau=1.6: 0.6910 | not kept |
| Haiku 5.5 efforts | 0.6640 | 0.6643 | -0.0004 | -0.0007 to -0.0001 | 0: 43, 0.1: 4, 0.2: 3 | tau=0.1: 0.6644, tau=0.2: 0.6655, tau=0.4: 0.6696, tau=0.8: 0.6778, tau=1.6: 0.6843 | not kept |
| Haiku 5.5 efforts (seat and starter terms) | 0.6388 | 0.6396 | -0.0007 | -0.0013 to -0.0002 | 0: 44, 0.1: 3, 0.2: 2, 0.4: 1 | tau=0.1: 0.6391, tau=0.2: 0.6401, tau=0.4: 0.6436, tau=0.8: 0.6512, tau=1.6: 0.6578 | not kept |
| Luna efforts | 0.5781 | 0.5799 | -0.0018 | -0.0037 to -0.0001 | 0: 32, 0.1: 2, 0.2: 12, 0.4: 4 | tau=0.1: 0.5783, tau=0.2: 0.5788, tau=0.4: 0.5818, tau=0.8: 0.5904, tau=1.6: 0.6008 | not kept |
| Luna efforts (seat and starter terms) | 0.5791 | 0.5828 | -0.0037 | -0.0072 to -0.0006 | 0: 26, 0.1: 7, 0.2: 8, 0.4: 8, 0.8: 1 | tau=0.1: 0.5792, tau=0.2: 0.5798, tau=0.4: 0.5827, tau=0.8: 0.5919, tau=1.6: 0.6039 | not kept |
| Opus efforts | 0.6960 | 0.7005 | -0.0045 | -0.0085 to -0.0014 | 0: 46, 0.2: 1, 0.4: 1, 0.8: 2 | tau=0.1: 0.6968, tau=0.2: 0.6988, tau=0.4: 0.7050, tau=0.8: 0.7189, tau=1.6: 0.7422 | not kept |
| Opus efforts (seat and starter terms) | 0.7092 | 0.7135 | -0.0043 | -0.0099 to -0.0006 | 0: 48, 0.1: 1, 1.6: 1 | tau=0.1: 0.7099, tau=0.2: 0.7119, tau=0.4: 0.7177, tau=0.8: 0.7303, tau=1.6: 0.7521 | not kept |
| Sol efforts | 0.7054 | 0.7104 | -0.0050 | -0.0119 to +0.0010 | 0: 19, 0.1: 1, 0.2: 12, 0.4: 13, 0.8: 5 | tau=0.1: 0.7052, tau=0.2: 0.7050, tau=0.4: 0.7064, tau=0.8: 0.7125, tau=1.6: 0.7188 | not kept |
| Sol efforts (seat and starter terms) | 0.7094 | 0.7154 | -0.0060 | -0.0124 to -0.0008 | 0: 17, 0.1: 9, 0.2: 10, 0.4: 13, 0.8: 1 | tau=0.1: 0.7093, tau=0.2: 0.7093, tau=0.4: 0.7114, tau=0.8: 0.7184, tau=1.6: 0.7253 | not kept |
| Sonnet efforts | 0.6729 | 0.6772 | -0.0043 | -0.0098 to +0.0011 | 0: 12, 0.1: 3, 0.2: 14, 0.4: 20, 0.8: 1 | tau=0.1: 0.6726, tau=0.2: 0.6724, tau=0.4: 0.6740, tau=0.8: 0.6812, tau=1.6: 0.6891 | not kept |
| Sonnet efforts (seat and starter terms) | 0.6737 | 0.6785 | -0.0048 | -0.0123 to +0.0013 | 0: 15, 0.1: 5, 0.2: 13, 0.4: 15, 0.8: 2 | tau=0.1: 0.6733, tau=0.2: 0.6728, tau=0.4: 0.6737, tau=0.8: 0.6808, tau=1.6: 0.6894 | not kept |
| Terra 6.1 efforts | 0.8497 | 0.8678 | -0.0181 | -0.1104 to +0.0517 | 0: 9, 0.2: 1, 0.4: 8, 0.8: 16, 1.6: 16 | tau=0.1: 0.8491, tau=0.2: 0.8472, tau=0.4: 0.8408, tau=0.8: 0.8261, tau=1.6: 0.8269 | not kept |
| Terra 6.1 efforts (seat and starter terms) | 0.9542 | 0.9855 | -0.0313 | -0.1208 to +0.0361 | 0: 9, 0.4: 5, 0.8: 20, 1.6: 16 | tau=0.1: 0.9536, tau=0.2: 0.9518, tau=0.4: 0.9458, tau=0.8: 0.9345, tau=1.6: 0.9503 | not kept |
| Terra efforts | 0.6940 | 0.6950 | -0.0010 | -0.0020 to -0.0001 | 0: 42, 0.1: 1, 0.2: 5, 0.4: 2 | tau=0.1: 0.6942, tau=0.2: 0.6948, tau=0.4: 0.6976, tau=0.8: 0.7041, tau=1.6: 0.7101 | not kept |
| Terra efforts (seat and starter terms) | 0.6978 | 0.7004 | -0.0026 | -0.0044 to -0.0008 | 0: 35, 0.1: 4, 0.2: 6, 0.4: 5 | tau=0.1: 0.6981, tau=0.2: 0.6990, tau=0.4: 0.7026, tau=0.8: 0.7100, tau=1.6: 0.7161 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| Cross-model | 236/420 = 56.2% | -0.10 |
| Haiku 4.5 efforts | 7/10 = 70.0% | +0.05 |
| Haiku 5.5 efforts | 5/15 = 33.3% | -0.44 |
| Luna efforts | 7/15 = 46.7% | -0.09 |
| Opus efforts | 4/15 = 26.7% | -0.31 |
| Sol efforts | 6/10 = 60.0% | -0.18 |
| Sonnet efforts | 6/15 = 40.0% | -0.04 |
| Terra 6.1 efforts | 6/8 = 75.0% | +0.58 |
| Terra efforts | 4/10 = 40.0% | -0.15 |
| all cohorts pooled | 281/518 = 54.2% | -0.09 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 8.9e-17, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 3657 of 3657 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 1452 blocks, 128 seeds (753 matches in half blocks left out) | 1462/2904 = 50.3% | 43.8% to 57.2% | 48.5% to 52.1% |
| Astra efforts: 2 blocks, 1 seeds (5 matches in half blocks left out) | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% |
| Cross-model: 635 blocks, 118 seeds (710 matches in half blocks left out) | 614/1270 = 48.3% | 41.7% to 55.7% | 45.7% to 51.0% |
| Haiku 4.5 efforts: 100 blocks, 10 seeds | 105/200 = 52.5% | 42.0% to 60.0% | 45.5% to 59.5% |
| Haiku 5.5 efforts: 150 blocks, 10 seeds | 142/300 = 47.3% | 34.7% to 59.7% | 41.3% to 53.7% |
| Luna efforts: 150 blocks, 10 seeds | 160/300 = 53.3% | 47.0% to 59.0% | 49.0% to 58.3% |
| Opus efforts: 58 blocks, 18 seeds (21 matches in half blocks left out) | 61/116 = 52.6% | 38.6% to 66.4% | 43.1% to 62.1% |
| Sol efforts: 100 blocks, 10 seeds | 111/200 = 55.5% | 42.5% to 68.0% | 48.0% to 63.0% |
| Sonnet efforts: 150 blocks, 10 seeds | 162/300 = 54.0% | 42.7% to 64.3% | 48.3% to 59.3% |
| Terra 6.1 efforts: 7 blocks, 7 seeds (17 matches in half blocks left out) | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% |
| Terra efforts: 100 blocks, 10 seeds | 96/200 = 48.0% | 36.0% to 58.5% | 40.5% to 55.5% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 1650/2904 = 56.8% | 50.6% to 62.4% | 55.0% to 58.6% | 703/1452 |
| Astra efforts | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% | 2/2 |
| Cross-model | 740/1270 = 58.3% | 52.5% to 63.5% | 55.4% to 61.0% | 291/635 |
| Haiku 4.5 efforts | 115/200 = 57.5% | 50.5% to 65.5% | 51.0% to 64.5% | 50/100 |
| Haiku 5.5 efforts | 186/300 = 62.0% | 51.7% to 72.0% | 56.0% to 67.3% | 75/150 |
| Luna efforts | 152/300 = 50.7% | 44.3% to 57.0% | 46.0% to 55.7% | 75/150 |
| Opus efforts | 67/116 = 57.8% | 44.4% to 71.1% | 48.3% to 67.2% | 31/58 |
| Sol efforts | 107/200 = 53.5% | 40.0% to 66.5% | 46.0% to 61.5% | 50/100 |
| Sonnet efforts | 164/300 = 54.7% | 43.7% to 65.3% | 49.3% to 60.0% | 75/150 |
| Terra 6.1 efforts | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% | 4/7 |
| Terra efforts | 108/200 = 54.0% | 42.5% to 64.5% | 46.5% to 61.0% | 50/100 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +0.6 | -5.7 to +6.3 | -1.3 to +2.3 | +6.8 | +0.5 to +12.6 | +5.0 to +8.6 |
| Cross-model | -1.0 | -6.9 to +4.8 | -3.6 to +1.6 | +8.2 | +1.9 to +13.4 | +5.4 to +10.9 |
| Haiku 4.5 efforts | +2.5 | -6.3 to +9.5 | -4.1 to +9.6 | +7.5 | +0.6 to +16.0 | +1.0 to +14.4 |
| Haiku 5.5 efforts | -2.7 | -13.6 to +7.4 | -8.3 to +3.2 | +12.0 | +1.0 to +22.3 | +6.1 to +17.4 |
| Luna efforts | +3.3 | -3.3 to +9.7 | -1.3 to +8.2 | +0.7 | -5.8 to +7.3 | -4.0 to +5.6 |
| Opus efforts | +2.1 | -12.1 to +15.5 | -7.6 to +11.4 | +7.6 | -6.0 to +21.6 | -2.1 to +17.2 |
| Sol efforts | +5.5 | -7.8 to +19.2 | -2.2 to +13.0 | +3.5 | -10.0 to +17.0 | -3.8 to +11.2 |
| Sonnet efforts | +4.0 | -7.9 to +14.6 | -1.7 to +9.1 | +4.7 | -7.1 to +15.8 | -0.7 to +10.1 |
| Terra 6.1 efforts | +6.2 | -20.8 to +35.0 | -20.8 to +35.0 | +6.2 | -20.8 to +35.0 | -20.8 to +33.3 |
| Terra efforts | -2.0 | -14.8 to +8.5 | -9.3 to +5.3 | +4.0 | -8.1 to +15.0 | -3.5 to +11.2 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| claude-haiku-4-5-20251001: 262 blocks, 73 seeds | 258/524 = 49.2% | 43.7% to 54.7% | 45.4% to 53.4% |
| claude-haiku-5-5: 348 blocks, 82 seeds | 332/696 = 47.7% | 39.6% to 56.4% | 44.0% to 51.4% |
| claude-opus-5-5: 223 blocks, 57 seeds | 223/446 = 50.0% | 42.2% to 58.8% | 45.1% to 55.2% |
| claude-sonnet-5-5: 319 blocks, 41 seeds | 325/638 = 50.9% | 43.2% to 58.4% | 47.2% to 54.5% |
| engine-d2: 30 blocks, 10 seeds | 41/60 = 68.3% | 55.0% to 83.3% | 58.3% to 78.3% |
| engine-d6s: 30 blocks, 10 seeds | 29/60 = 48.3% | 30.0% to 66.7% | 35.0% to 61.7% |
| gpt-5.6-terra: 208 blocks, 19 seeds | 217/416 = 52.2% | 43.2% to 61.0% | 47.1% to 57.2% |
| gpt-6-astra: 134 blocks, 47 seeds | 129/268 = 48.1% | 39.2% to 58.1% | 42.2% to 54.1% |
| gpt-6-luna: 269 blocks, 27 seeds | 266/538 = 49.4% | 44.4% to 54.5% | 45.9% to 53.0% |
| gpt-6.1-sol: 242 blocks, 39 seeds | 235/484 = 48.6% | 39.9% to 57.5% | 43.6% to 53.3% |
| gpt-6.1-terra: 22 blocks, 12 seeds | 21/44 = 47.7% | 28.6% to 63.6% | 29.5% to 63.6% |

#### Per seed, all cohorts

Cohorts reuse seeds 3000 to 3018 (tournament 3 adds 3020 to 3029, and tournament 5 many seeds from 4000 up, most with one block), so a seed's starter result pools many pairings.

| seed | position that starts | complete blocks | starter wins/matches = share |
|---|---|---|---|
| 3000 | 2 | 128 | 180/256 = 70.3% |
| 3001 | 2 | 36 | 54/72 = 75.0% |
| 3002 | 2 | 36 | 38/72 = 52.8% |
| 3003 | 2 | 36 | 34/72 = 47.2% |
| 3004 | 1 | 37 | 57/74 = 77.0% |
| 3005 | 1 | 37 | 28/74 = 37.8% |
| 3006 | 1 | 36 | 39/72 = 54.2% |
| 3007 | 2 | 37 | 60/74 = 81.1% |
| 3008 | 2 | 37 | 42/74 = 56.8% |
| 3009 | 1 | 37 | 45/74 = 60.8% |
| 3010 | 1 | 92 | 127/184 = 69.0% |
| 3011 | 1 | 92 | 129/184 = 70.1% |
| 3012 | 2 | 92 | 82/184 = 44.6% |
| 3013 | 2 | 92 | 87/184 = 47.3% |
| 3014 | 1 | 92 | 70/184 = 38.0% |
| 3015 | 1 | 92 | 138/184 = 75.0% |
| 3016 | 1 | 92 | 76/184 = 41.3% |
| 3017 | 2 | 92 | 88/184 = 47.8% |
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
| the 19 seeds with 10 or more blocks, each once |  | 1285 | mean of seed shares 57.9% (95% CI 51.8% to 64.1%, seeds drawn) |

### Tournament 3

| scored matches | Opus xhigh wins/matches = share | 95% CI (seed blocks drawn, wins over matches) | mean of block shares (a block counts once) | 95% CI | Opus minus Astra, Elo (95% CI) | blocks Opus both / split / Astra both |
|---|---|---|---|---|---|---|
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 38.1% to 68.3% | 52.4% | 35.7% to 66.7% | +25 (-81 to +133) | 6 / 10 / 4 |
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

There are no decision terms, since the models' policies are unknown, and no deal terms, since the logs lack the item pool. The
corrections have mean zero for any V that depends only on the history before the event and its outcome, so they leave the
strengths the same in expectation. Each V is fitted out of fold (five folds by seed), so no round is corrected by a model that saw
it. The bias test checks the mean zero: per config, the mean correction per round against zero, with standard errors clustered by
seed, and its correlation with Round Elo fitted on the other half of the seeds. The wrap-up writes the corrections to
`derived/luck.sqlite` (per match and player) and the viewer and the export add them to the round wins before the Round Elo fit, with
the same seed-block bootstrap. The table below is the same fit in Python.

<!-- luck:start -->
3,657 matches, 10,971 rounds. The median 95% half-width falls from ±36 to ±30 Elo (variance of a match's round share 0.083 → 0.064). Spearman rank correlation with the raw ratings 0.985, largest rank change 8.

Bias test: the mean correction per round of each config, seed-clustered, gives chi2 54.6 on 51 configs (p 0.34). Its correlation with Round Elo fitted on the other half of the seeds (20 random halvings) is -0.06.

| config | matches | rounds | Round Elo [95%] | luck-adjusted [95%] |
|---|---|---|---|---|
| gpt-6.1-terra-max | 80 | 240 | +123 [+80, +168] | +124 [+99, +160] |
| claude-sonnet-5-5-max | 140 | 420 | +105 [+73, +140] | +115 [+86, +150] |
| claude-opus-5-5-max | 80 | 240 | +119 [+68, +161] | +111 [+66, +146] |
| gpt-6-astra-high | 80 | 240 | +117 [+87, +159] | +104 [+73, +136] |
| claude-opus-5-5-xhigh | 150 | 450 | +99 [+65, +130] | +99 [+72, +127] |
| gpt-6.1-sol-max | 122 | 366 | +94 [+63, +126] | +94 [+71, +117] |
| engine-d6s | 60 | 180 | +68 [+29, +110] | +87 [+48, +124] |
| gpt-6.1-sol-xhigh | 101 | 303 | +66 [+32, +101] | +72 [+45, +97] |
| gpt-6-astra | 254 | 762 | +82 [+63, +104] | +72 [+53, +90] |
| claude-opus-5-5-high | 80 | 240 | +76 [+41, +124] | +69 [+39, +106] |
| gpt-6-astra-low | 80 | 240 | +61 [+27, +105] | +66 [+29, +105] |
| gpt-6.1-sol-low | 98 | 294 | +60 [+16, +103] | +63 [+27, +96] |
| gpt-6.1-sol-high | 99 | 297 | +41 [-1, +75] | +58 [+31, +84] |
| gpt-6.1-sol | 271 | 813 | +54 [+29, +78] | +57 [+39, +72] |
| gpt-6.1-terra-high | 80 | 240 | +49 [+15, +86] | +54 [+17, +92] |
| gpt-6.1-terra-xhigh | 80 | 240 | +58 [+19, +96] | +53 [+18, +83] |
| claude-sonnet-5-5-xhigh | 160 | 480 | +56 [+31, +88] | +53 [+25, +79] |
| gpt-6-astra-low-recall | 80 | 240 | +34 [-10, +73] | +53 [+19, +86] |
| claude-opus-5-5-off | 80 | 240 | +62 [+27, +103] | +52 [+20, +85] |
| claude-opus-5-5 | 334 | 1002 | +43 [+27, +64] | +47 [+33, +66] |
| claude-haiku-5-5-max | 111 | 333 | +44 [+16, +71] | +46 [+20, +70] |
| gpt-6.1-terra | 80 | 240 | +48 [+15, +92] | +39 [+8, +76] |
| claude-opus-5-5-low | 80 | 240 | +24 [-20, +60] | +28 [-9, +62] |
| gpt-5.6-terra-max | 90 | 270 | +16 [-24, +60] | +27 [-7, +64] |
| gpt-5.6-terra-xhigh | 93 | 279 | +30 [-6, +69] | +24 [-10, +57] |
| claude-haiku-5-5-xhigh | 158 | 474 | +11 [-12, +39] | +15 [-8, +39] |
| gpt-6.1-terra-low | 80 | 240 | +30 [-19, +65] | +14 [-23, +45] |
| gpt-6.1-terra-off | 80 | 240 | +26 [-11, +63] | +9 [-23, +58] |
| claude-sonnet-5-5 | 364 | 1092 | -2 [-23, +16] | +9 [-10, +26] |
| claude-haiku-5-5-high | 173 | 519 | +6 [-21, +36] | +6 [-16, +27] |
| claude-sonnet-5-5-high | 161 | 483 | +7 [-29, +38] | +4 [-27, +34] |
| engine-d2 | 60 | 180 | -14 [-59, +21] | -2 [-38, +31] |
| claude-haiku-5-5 | 382 | 1146 | -1 [-17, +18] | -7 [-21, +10] |
| gpt-5.6-terra-high | 91 | 273 | -6 [-48, +43] | -10 [-48, +33] |
| claude-haiku-5-5-low | 194 | 582 | -3 [-32, +26] | -16 [-43, +11] |
| gpt-5.6-terra | 259 | 777 | -26 [-48, -3] | -20 [-39, -2] |
| gpt-5.6-terra-low | 91 | 273 | -28 [-70, +20] | -22 [-67, +19] |
| gpt-6-luna-max | 112 | 336 | -19 [-65, +25] | -27 [-67, +8] |
| claude-sonnet-5-5-low | 159 | 477 | -40 [-76, -6] | -27 [-57, +3] |
| claude-sonnet-5-5-off | 164 | 492 | -23 [-55, +7] | -33 [-61, -5] |
| gpt-6-luna-xhigh | 115 | 345 | -14 [-64, +23] | -34 [-69, -5] |
| gpt-6-luna-high | 112 | 336 | -72 [-112, -32] | -86 [-116, -57] |
| claude-haiku-5-5-off | 202 | 606 | -99 [-125, -73] | -98 [-119, -76] |
| claude-haiku-4-5-20251001 | 340 | 1020 | -122 [-148, -101] | -129 [-152, -111] |
| claude-haiku-4-5-20251001-high | 135 | 405 | -146 [-180, -112] | -147 [-178, -118] |
| claude-haiku-4-5-20251001-low | 149 | 447 | -140 [-176, -101] | -150 [-183, -123] |
| claude-haiku-4-5-20251001-minimal | 143 | 429 | -141 [-175, -109] | -152 [-183, -122] |
| gpt-6-luna | 282 | 846 | -157 [-186, -137] | -154 [-182, -135] |
| gpt-6-luna-off | 110 | 330 | -213 [-261, -167] | -188 [-229, -141] |
| gpt-6-luna-low | 110 | 330 | -226 [-273, -174] | -209 [-250, -171] |
| claude-haiku-4-5-20251001-off | 125 | 375 | -218 [-257, -184] | -211 [-237, -180] |
<!-- luck:end -->

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
