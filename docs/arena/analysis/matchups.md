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
| Cross-model | 49 | 1860 | 575 / 710 | 477/1176 | 1 / 2 / 41 | yes | 1860 completed, 5 partial (skipped), 138 skipped (skipped), 789 unstarted |
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
| claude-opus-5-5-max | 59/80 = 73.8% | +218 | +137 to +318 | +137 to +323 | 64.4% | +118 | +76 to +161 |
| gpt-6.1-terra-max | 58/80 = 72.5% | +202 | +120 to +296 | +119 to +294 | 66.0% | +121 | +78 to +166 |
| gpt-6-astra-high | 57/80 = 71.2% | +179 | +98 to +274 | +97 to +276 | 66.1% | +116 | +77 to +160 |
| claude-sonnet-5-5-max | 94/140 = 67.1% | +173 | +102 to +242 | +85 to +285 | 62.3% | +107 | +70 to +143 |
| claude-opus-5-5-xhigh | 82/150 = 54.7% | +170 | +118 to +233 | +115 to +225 | 53.4% | +100 | +72 to +131 |
| gpt-6.1-terra-xhigh | 56/80 = 70.0% | +157 | +83 to +254 | +77 to +249 | 59.7% | +59 | +18 to +107 |
| gpt-6-astra | 169/254 = 66.5% | +149 | +108 to +195 | +108 to +195 | 60.2% | +84 | +60 to +107 |
| claude-opus-5-5-high | 47/80 = 58.8% | +147 | +70 to +231 | +62 to +244 | 54.7% | +77 | +33 to +124 |
| gpt-6.1-sol-max | 70/122 = 57.4% | +143 | +89 to +202 | +82 to +208 | 54.9% | +95 | +65 to +127 |
| gpt-6-astra-low | 52/80 = 65.0% | +123 | +52 to +209 | +50 to +206 | 59.4% | +63 | +28 to +103 |
| claude-sonnet-5-5-xhigh | 96/160 = 60.0% | +122 | +66 to +179 | +62 to +188 | 54.7% | +56 | +27 to +85 |
| claude-opus-5-5-off | 50/80 = 62.5% | +108 | +30 to +193 | +26 to +189 | 58.8% | +63 | +22 to +107 |
| gpt-6.1-terra | 50/80 = 62.5% | +103 | +26 to +185 | +29 to +189 | 57.7% | +49 | +10 to +89 |
| gpt-6-astra-low-recall | 51/80 = 63.7% | +102 | +24 to +186 | +23 to +188 | 55.9% | +31 | -9 to +74 |
| gpt-6.1-terra-off | 52/80 = 65.0% | +91 | +13 to +176 | +14 to +175 | 56.9% | +25 | -13 to +67 |
| gpt-6.1-sol-low | 51/98 = 52.0% | +90 | +15 to +165 | +24 to +163 | 50.9% | +60 | +19 to +100 |
| gpt-6.1-sol-xhigh | 52/101 = 51.5% | +87 | +15 to +155 | +19 to +155 | 52.4% | +68 | +28 to +104 |
| claude-opus-5-5 | 169/294 = 57.5% | +85 | +44 to +129 | +42 to +131 | 54.2% | +46 | +26 to +66 |
| gpt-6.1-terra-high | 51/80 = 63.7% | +85 | +4 to +176 | +6 to +179 | 59.7% | +47 | +6 to +92 |
| claude-haiku-5-5-max | 68/111 = 61.3% | +72 | +11 to +137 | -7 to +166 | 58.7% | +44 | +13 to +75 |
| gpt-6.1-sol | 155/271 = 57.2% | +65 | +26 to +107 | +9 to +126 | 56.8% | +55 | +32 to +76 |
| claude-haiku-5-5-xhigh | 86/158 = 54.4% | +61 | +10 to +118 | +5 to +116 | 50.4% | +12 | -15 to +39 |
| gpt-6.1-sol-high | 47/99 = 47.5% | +60 | -2 to +128 | -11 to +125 | 48.0% | +41 | +5 to +79 |
| gpt-6.1-terra-low | 45/80 = 56.2% | +48 | -36 to +128 | -32 to +131 | 55.5% | +31 | -6 to +67 |
| claude-sonnet-5-5-high | 75/161 = 46.6% | +35 | -28 to +92 | -27 to +100 | 46.9% | +7 | -26 to +40 |
| claude-haiku-5-5-high | 89/173 = 51.4% | +32 | -21 to +88 | -13 to +80 | 50.3% | +5 | -23 to +33 |
| claude-sonnet-5-5 | 159/324 = 49.1% | +10 | -31 to +48 | -38 to +56 | 49.5% | +2 | -19 to +22 |
| gpt-5.6-terra-xhigh | 53/93 = 57.0% | +7 | -75 to +89 | -77 to +90 | 55.1% | +32 | -6 to +72 |
| gpt-5.6-terra-max | 52/90 = 57.8% | +2 | -82 to +85 | -63 to +71 | 53.8% | +19 | -28 to +62 |
| claude-haiku-5-5 | 172/342 = 50.3% | +1 | -34 to +34 | -32 to +31 | 50.3% | -4 | -23 to +15 |
| claude-haiku-5-5-low | 98/194 = 50.5% | -1 | -54 to +54 | -49 to +53 | 51.3% | -3 | -29 to +25 |
| claude-opus-5-5-low | 33/80 = 41.2% | -7 | -84 to +68 | -89 to +70 | 49.4% | +23 | -16 to +64 |
| claude-sonnet-5-5-off | 65/164 = 39.6% | -14 | -73 to +40 | -73 to +35 | 42.4% | -22 | -53 to +8 |
| gpt-6-luna-xhigh | 79/115 = 68.7% | -26 | -109 to +54 | -96 to +39 | 63.6% | -9 | -54 to +35 |
| gpt-6-luna-max | 75/112 = 67.0% | -44 | -125 to +38 | -118 to +32 | 63.2% | -14 | -61 to +32 |
| gpt-5.6-terra | 119/259 = 45.9% | -61 | -109 to -16 | -112 to -14 | 48.0% | -24 | -47 to -1 |
| claude-sonnet-5-5-low | 50/159 = 31.4% | -67 | -133 to -8 | -129 to -9 | 39.5% | -40 | -74 to -8 |
| gpt-5.6-terra-high | 40/91 = 44.0% | -75 | -157 to +1 | -140 to -17 | 49.5% | -4 | -44 to +35 |
| gpt-5.6-terra-low | 37/91 = 40.7% | -93 | -179 to -19 | -166 to -21 | 45.5% | -25 | -69 to +13 |
| gpt-6-luna-high | 67/112 = 59.8% | -100 | -188 to -10 | -200 to +12 | 55.5% | -67 | -106 to -26 |
| claude-haiku-5-5-off | 75/202 = 37.1% | -137 | -192 to -84 | -195 to -90 | 39.8% | -100 | -128 to -73 |
| claude-haiku-4-5-20251001 | 114/340 = 33.5% | -198 | -249 to -154 | -252 to -156 | 38.3% | -122 | -144 to -99 |
| claude-haiku-4-5-20251001-minimal | 57/143 = 39.9% | -234 | -309 to -170 | -304 to -176 | 42.5% | -139 | -174 to -106 |
| claude-haiku-4-5-20251001-low | 55/149 = 36.9% | -250 | -324 to -185 | -321 to -191 | 41.9% | -139 | -173 to -105 |
| gpt-6-luna | 74/282 = 26.2% | -262 | -322 to -209 | -317 to -211 | 34.1% | -154 | -180 to -129 |
| claude-haiku-4-5-20251001-high | 47/135 = 34.8% | -280 | -358 to -215 | -381 to -205 | 42.0% | -147 | -181 to -115 |
| gpt-6-luna-off | 29/110 = 26.4% | -341 | -437 to -260 | -456 to -241 | 33.8% | -207 | -257 to -162 |
| gpt-6-luna-low | 28/110 = 25.5% | -346 | -460 to -254 | -418 to -291 | 31.4% | -222 | -278 to -176 |
| claude-haiku-4-5-20251001-off | 28/125 = 22.4% | -388 | -478 to -313 | -488 to -308 | 32.6% | -216 | -255 to -181 |

With a seat term and a round 1 starter term in the fit (position 1 -2 Elo, the starter +51 Elo) the largest rating change is 17.3 Elo.


### Observed pairs against the pooled ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below. Every resample refits the pooled ratings.

#### Astra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-astra vs gpt-6-astra-high | 1/2 = 50.0% | 45.8% | +4.2 | -8.1 to +19.0 |
| gpt-6-astra vs gpt-6-astra-low | 2/2 = 100.0% | 53.8% | +46.2 | +33.6 to +57.7 |
| gpt-6-astra-high vs gpt-6-astra-low | 2/2 = 100.0% | 58.0% | +42.0 | +26.3 to +58.3 |
| gpt-6-astra-high vs gpt-6-astra-low-recall | 0/1 = 0.0% | 60.8% | -60.8 | -75.2 to -44.1 |
| gpt-6-astra-low vs gpt-6-astra-low-recall | 2/2 = 100.0% | 53.0% | +47.0 | +30.7 to +61.6 |
#### Cross-model

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-5-5 | 8/31 = 25.8% | 24.2% | +1.6 | -10.6 to +13.7 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-high | 1/12 = 8.3% | 21.0% | -12.7 | -26.1 to +4.8 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-low | 4/14 = 28.6% | 24.3% | +4.3 | -17.9 to +25.1 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-max | 0/2 = 0.0% | 17.5% | -17.5 | -24.6 to -11.8 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-off | 5/12 = 41.7% | 41.2% | +0.4 | -29.1 to +31.1 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-xhigh | 1/2 = 50.0% | 18.3% | +31.7 | +25.1 to +37.1 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5 | 7/20 = 35.0% | 16.4% | +18.6 | -1.4 to +38.1 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-high | 0/1 = 0.0% | 12.1% | -12.1 | -18.4 to -7.2 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-low | 0/2 = 0.0% | 25.0% | -25.0 | -34.9 to -16.1 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-max | 0/2 = 0.0% | 8.4% | -8.4 | -13.2 to -4.6 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-off | 1/3 = 33.3% | 14.6% | +18.7 | -18.5 to +86.5 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5 | 2/20 = 10.0% | 23.2% | -13.2 | -25.5 to +1.0 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-high | 0/2 = 0.0% | 20.8% | -20.8 | -28.6 to -14.3 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-low | 0/2 = 0.0% | 32.0% | -32.0 | -41.4 to -23.0 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 10.6% | -10.6 | -15.6 to -6.7 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-off | 0/4 = 0.0% | 25.7% | -25.7 | -34.5 to -18.2 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-xhigh | 0/2 = 0.0% | 13.6% | -13.6 | -19.0 to -9.1 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra | 6/20 = 30.0% | 31.2% | -1.2 | -16.5 to +14.2 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-low | 0/2 = 0.0% | 35.3% | -35.3 | -47.5 to -24.0 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-max | 0/2 = 0.0% | 24.0% | -24.0 | -34.5 to -15.0 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-xhigh | 1/2 = 50.0% | 23.5% | +26.5 | +15.8 to +34.5 |
| claude-haiku-4-5-20251001 vs gpt-6-astra | 3/20 = 15.0% | 11.9% | +3.1 | -11.0 to +18.3 |
| claude-haiku-4-5-20251001 vs gpt-6-astra-high | 0/3 = 0.0% | 10.2% | -10.2 | -16.0 to -5.7 |
| claude-haiku-4-5-20251001 vs gpt-6-astra-low | 1/3 = 33.3% | 13.6% | +19.7 | -17.0 to +87.8 |
| claude-haiku-4-5-20251001 vs gpt-6-astra-low-recall | 0/3 = 0.0% | 15.1% | -15.1 | -22.5 to -9.2 |
| claude-haiku-4-5-20251001 vs gpt-6-luna | 12/20 = 60.0% | 59.1% | +0.9 | -25.8 to +24.8 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-high | 1/2 = 50.0% | 36.3% | +13.7 | -0.9 to +26.1 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-off | 2/2 = 100.0% | 69.5% | +30.5 | +18.5 to +42.0 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 27.1% | +22.9 | +9.7 to +31.8 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol | 6/20 = 30.0% | 18.0% | +12.0 | -6.4 to +33.4 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-high | 1/2 = 50.0% | 18.4% | +31.6 | +23.1 to +37.6 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-low | 1/2 = 50.0% | 16.0% | +34.0 | +25.3 to +39.6 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 16.3% | +33.7 | +25.7 to +39.6 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra | 1/3 = 33.3% | 15.0% | +18.3 | -19.4 to +86.2 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-high | 0/4 = 0.0% | 16.4% | -16.4 | -24.6 to -9.8 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-low | 1/3 = 33.3% | 19.5% | +13.8 | -25.3 to +81.6 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-max | 0/3 = 0.0% | 9.1% | -9.1 | -14.3 to -5.0 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-off | 0/4 = 0.0% | 15.9% | -15.9 | -23.5 to -9.6 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 11.5% | -11.5 | -17.3 to -6.4 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5 | 0/1 = 0.0% | 16.6% | -16.6 | -23.1 to -11.1 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-high | 0/1 = 0.0% | 14.2% | -14.2 | -20.8 to -8.8 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-max | 0/1 = 0.0% | 11.6% | -11.6 | -17.7 to -7.1 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-off | 2/10 = 20.0% | 30.4% | -10.4 | -34.3 to +15.0 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-xhigh | 0/1 = 0.0% | 12.3% | -12.3 | -18.2 to -7.5 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-low | 0/1 = 0.0% | 17.2% | -17.2 | -26.6 to -10.1 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-max | 0/2 = 0.0% | 5.4% | -5.4 | -9.4 to -2.7 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-off | 1/2 = 50.0% | 9.7% | +40.3 | -12.4 to +93.1 |
| claude-haiku-4-5-20251001-high vs claude-sonnet-5-5 | 0/2 = 0.0% | 15.9% | -15.9 | -22.7 to -10.2 |
| claude-haiku-4-5-20251001-high vs gpt-5.6-terra | 0/2 = 0.0% | 22.0% | -22.0 | -30.6 to -14.2 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra | 0/2 = 0.0% | 7.8% | -7.8 | -11.4 to -4.7 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-high | 0/2 = 0.0% | 6.6% | -6.6 | -11.2 to -3.4 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-low | 0/2 = 0.0% | 8.9% | -8.9 | -14.7 to -4.7 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-low-recall | 0/3 = 0.0% | 10.0% | -10.0 | -16.4 to -5.3 |
| claude-haiku-4-5-20251001-high vs gpt-6-luna | 0/2 = 0.0% | 47.4% | -47.4 | -58.3 to -33.5 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-sol | 0/2 = 0.0% | 12.0% | -12.0 | -17.3 to -7.8 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra | 1/3 = 33.3% | 9.9% | +23.4 | -13.1 to +91.5 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-high | 0/4 = 0.0% | 10.9% | -10.9 | -17.8 to -5.7 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-low | 0/3 = 0.0% | 13.1% | -13.1 | -21.4 to -7.0 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-max | 0/2 = 0.0% | 5.9% | -5.9 | -10.3 to -3.0 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-off | 0/4 = 0.0% | 10.5% | -10.5 | -17.4 to -5.7 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 7.5% | -7.5 | -12.3 to -3.8 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5 | 1/3 = 33.3% | 19.1% | +14.2 | -23.4 to +34.8 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5-low | 2/11 = 18.2% | 19.2% | -1.0 | -20.9 to +29.9 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5-off | 4/11 = 36.4% | 34.2% | +2.1 | -30.6 to +46.2 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5 | 0/2 = 0.0% | 12.7% | -12.7 | -18.6 to -8.0 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-high | 0/1 = 0.0% | 9.3% | -9.3 | -15.6 to -4.8 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-low | 0/1 = 0.0% | 19.8% | -19.8 | -29.8 to -11.9 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-max | 0/2 = 0.0% | 6.3% | -6.3 | -10.7 to -3.2 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-off | 0/3 = 0.0% | 11.3% | -11.3 | -18.2 to -6.1 |
| claude-haiku-4-5-20251001-low vs gpt-5.6-terra | 1/2 = 50.0% | 25.1% | +24.9 | +14.6 to +32.3 |
| claude-haiku-4-5-20251001-low vs gpt-6-astra-high | 0/3 = 0.0% | 7.8% | -7.8 | -12.9 to -4.1 |
| claude-haiku-4-5-20251001-low vs gpt-6-astra-low | 0/3 = 0.0% | 10.5% | -10.5 | -16.7 to -5.7 |
| claude-haiku-4-5-20251001-low vs gpt-6-astra-low-recall | 1/3 = 33.3% | 11.6% | +21.7 | -15.2 to +89.7 |
| claude-haiku-4-5-20251001-low vs gpt-6-luna | 2/2 = 100.0% | 51.7% | +48.3 | +34.5 to +60.2 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-sol | 0/2 = 0.0% | 14.0% | -14.0 | -19.6 to -9.1 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra | 0/3 = 0.0% | 11.6% | -11.6 | -18.7 to -6.5 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-high | 0/4 = 0.0% | 12.7% | -12.7 | -20.6 to -6.9 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-low | 2/3 = 66.7% | 15.2% | +51.5 | -15.3 to +89.5 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-max | 0/3 = 0.0% | 6.9% | -6.9 | -11.9 to -3.6 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-off | 1/4 = 25.0% | 12.3% | +12.7 | -16.3 to +85.9 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 8.8% | -8.8 | -14.0 to -4.6 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5 | 1/2 = 50.0% | 20.6% | +29.4 | +22.0 to +36.0 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5-low | 0/10 = 0.0% | 20.7% | -20.7 | -29.5 to -13.2 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5-off | 3/11 = 27.3% | 36.3% | -9.0 | -35.3 to +12.8 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5 | 1/2 = 50.0% | 13.7% | +36.3 | +29.8 to +40.9 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5-low | 0/1 = 0.0% | 21.3% | -21.3 | -32.1 to -12.7 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5-max | 0/2 = 0.0% | 6.9% | -6.9 | -11.7 to -3.5 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5-off | 0/2 = 0.0% | 12.2% | -12.2 | -19.3 to -6.7 |
| claude-haiku-4-5-20251001-minimal vs claude-sonnet-5-5 | 1/2 = 50.0% | 19.7% | +30.3 | +21.8 to +36.4 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra | 0/2 = 0.0% | 9.9% | -9.9 | -14.7 to -6.3 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra-high | 0/3 = 0.0% | 8.5% | -8.5 | -14.1 to -4.4 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra-low | 0/2 = 0.0% | 11.3% | -11.3 | -18.4 to -6.1 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra-low-recall | 0/3 = 0.0% | 12.6% | -12.6 | -20.6 to -7.2 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-luna | 1/2 = 50.0% | 54.0% | -4.0 | -15.6 to +9.7 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra | 0/3 = 0.0% | 12.6% | -12.6 | -19.9 to -7.0 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-high | 3/4 = 75.0% | 13.7% | +61.3 | -8.7 to +91.2 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-low | 0/3 = 0.0% | 16.4% | -16.4 | -25.9 to -9.4 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-max | 1/2 = 50.0% | 7.5% | +42.5 | -9.7 to +94.6 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-off | 0/4 = 0.0% | 13.3% | -13.3 | -20.6 to -7.5 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 9.5% | -9.5 | -15.4 to -4.9 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5 | 1/2 = 50.0% | 9.6% | +40.4 | +34.6 to +43.9 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5-off | 3/11 = 27.3% | 19.0% | +8.3 | -19.4 to +44.3 |
| claude-haiku-4-5-20251001-off vs claude-opus-5-5-max | 0/1 = 0.0% | 3.0% | -3.0 | -5.5 to -1.4 |
| claude-haiku-4-5-20251001-off vs claude-opus-5-5-off | 0/2 = 0.0% | 5.4% | -5.4 | -10.1 to -2.7 |
| claude-haiku-4-5-20251001-off vs claude-sonnet-5-5 | 1/2 = 50.0% | 9.2% | +40.8 | +35.0 to +44.3 |
| claude-haiku-4-5-20251001-off vs gpt-5.6-terra | 0/2 = 0.0% | 13.2% | -13.2 | -20.1 to -7.9 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra | 0/2 = 0.0% | 4.3% | -4.3 | -7.2 to -2.4 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-high | 0/2 = 0.0% | 3.7% | -3.7 | -6.6 to -1.8 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-low | 0/2 = 0.0% | 5.0% | -5.0 | -9.0 to -2.5 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-low-recall | 0/2 = 0.0% | 5.6% | -5.6 | -9.9 to -2.8 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-sol | 0/2 = 0.0% | 6.8% | -6.8 | -10.9 to -3.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra | 0/2 = 0.0% | 5.6% | -5.6 | -9.9 to -2.8 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-high | 0/3 = 0.0% | 6.2% | -6.2 | -10.8 to -2.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-low | 0/2 = 0.0% | 7.5% | -7.5 | -13.1 to -3.8 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-max | 0/2 = 0.0% | 3.2% | -3.2 | -6.1 to -1.5 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-off | 0/3 = 0.0% | 5.9% | -5.9 | -10.5 to -2.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 4.2% | -4.2 | -7.3 to -2.0 |
| claude-haiku-5-5 vs claude-opus-5-5 | 7/20 = 35.0% | 38.1% | -3.1 | -18.7 to +11.0 |
| claude-haiku-5-5 vs claude-opus-5-5-high | 0/2 = 0.0% | 30.1% | -30.1 | -40.5 to -20.0 |
| claude-haiku-5-5 vs claude-opus-5-5-low | 1/2 = 50.0% | 51.2% | -1.2 | -12.7 to +10.7 |
| claude-haiku-5-5 vs claude-opus-5-5-max | 1/3 = 33.3% | 22.2% | +11.1 | -27.1 to +33.5 |
| claude-haiku-5-5 vs claude-opus-5-5-off | 2/4 = 50.0% | 35.0% | +15.0 | -36.4 to +68.5 |
| claude-haiku-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 48.7% | +11.3 | -6.8 to +29.5 |
| claude-haiku-5-5 vs claude-sonnet-5-5-high | 1/4 = 25.0% | 45.1% | -20.1 | -51.6 to +9.7 |
| claude-haiku-5-5 vs claude-sonnet-5-5-low | 2/2 = 100.0% | 59.6% | +40.4 | +29.6 to +49.2 |
| claude-haiku-5-5 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 27.1% | -27.1 | -36.0 to -18.6 |
| claude-haiku-5-5 vs claude-sonnet-5-5-off | 1/2 = 50.0% | 52.1% | -2.1 | -11.9 to +7.5 |
| claude-haiku-5-5 vs claude-sonnet-5-5-xhigh | 1/4 = 25.0% | 33.1% | -8.1 | -38.4 to +21.5 |
| claude-haiku-5-5 vs gpt-5.6-terra | 13/20 = 65.0% | 58.7% | +6.3 | -7.9 to +22.5 |
| claude-haiku-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 60.7% | +39.3 | +27.1 to +50.0 |
| claude-haiku-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 63.1% | -13.1 | -23.9 to -1.2 |
| claude-haiku-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 49.8% | +50.2 | +36.0 to +60.8 |
| claude-haiku-5-5 vs gpt-6-astra | 6/20 = 30.0% | 29.8% | +0.2 | -16.1 to +15.7 |
| claude-haiku-5-5 vs gpt-6-astra-high | 1/4 = 25.0% | 26.4% | -1.4 | -32.1 to +68.9 |
| claude-haiku-5-5 vs gpt-6-astra-low | 2/4 = 50.0% | 33.1% | +16.9 | -33.8 to +71.2 |
| claude-haiku-5-5 vs gpt-6-astra-low-recall | 3/4 = 75.0% | 35.8% | +39.2 | -28.3 to +72.4 |
| claude-haiku-5-5 vs gpt-6-luna | 19/20 = 95.0% | 81.9% | +13.1 | +1.1 to +22.2 |
| claude-haiku-5-5 vs gpt-6-luna-high | 1/2 = 50.0% | 64.1% | -14.1 | -25.3 to +0.2 |
| claude-haiku-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.0% | +12.0 | +6.1 to +18.8 |
| claude-haiku-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 56.3% | -6.3 | -18.6 to +6.3 |
| claude-haiku-5-5 vs gpt-6.1-sol | 10/20 = 50.0% | 40.8% | +9.2 | -4.7 to +24.3 |
| claude-haiku-5-5 vs gpt-6.1-sol-high | 2/4 = 50.0% | 41.5% | +8.5 | -1.5 to +18.3 |
| claude-haiku-5-5 vs gpt-6.1-sol-low | 0/2 = 0.0% | 37.4% | -37.4 | -47.2 to -27.4 |
| claude-haiku-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 30.5% | +19.5 | +11.1 to +26.9 |
| claude-haiku-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 37.8% | +12.2 | +1.7 to +21.5 |
| claude-haiku-5-5 vs gpt-6.1-terra | 1/4 = 25.0% | 35.7% | -10.7 | -42.4 to +59.1 |
| claude-haiku-5-5 vs gpt-6.1-terra-high | 1/4 = 25.0% | 38.1% | -13.1 | -45.1 to +53.0 |
| claude-haiku-5-5 vs gpt-6.1-terra-low | 0/4 = 0.0% | 43.2% | -43.2 | -55.9 to -31.3 |
| claude-haiku-5-5 vs gpt-6.1-terra-max | 1/4 = 25.0% | 23.9% | +1.1 | -30.1 to +69.2 |
| claude-haiku-5-5 vs gpt-6.1-terra-off | 1/4 = 25.0% | 37.2% | -12.2 | -44.0 to +55.6 |
| claude-haiku-5-5 vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 28.9% | -28.9 | -39.4 to -18.4 |
| claude-haiku-5-5-high vs claude-opus-5-5 | 1/2 = 50.0% | 42.4% | +7.6 | -2.4 to +16.9 |
| claude-haiku-5-5-high vs claude-opus-5-5-high | 0/2 = 0.0% | 34.1% | -34.1 | -46.9 to -22.5 |
| claude-haiku-5-5-high vs claude-opus-5-5-low | 3/3 = 100.0% | 55.6% | +44.4 | +31.9 to +57.1 |
| claude-haiku-5-5-high vs claude-opus-5-5-max | 0/4 = 0.0% | 25.5% | -25.5 | -36.7 to -15.3 |
| claude-haiku-5-5-high vs claude-opus-5-5-off | 3/4 = 75.0% | 39.2% | +35.8 | -30.8 to +69.5 |
| claude-haiku-5-5-high vs claude-sonnet-5-5 | 2/4 = 50.0% | 53.2% | -3.2 | -57.3 to +51.4 |
| claude-haiku-5-5-high vs gpt-6-astra | 0/2 = 0.0% | 33.7% | -33.7 | -42.2 to -25.2 |
| claude-haiku-5-5-high vs gpt-6-astra-high | 2/4 = 50.0% | 30.0% | +20.0 | -31.6 to +73.6 |
| claude-haiku-5-5-high vs gpt-6-astra-low | 1/4 = 25.0% | 37.2% | -12.2 | -44.8 to +54.8 |
| claude-haiku-5-5-high vs gpt-6-astra-low-recall | 1/4 = 25.0% | 40.0% | -15.0 | -48.4 to +48.2 |
| claude-haiku-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 84.4% | -34.4 | -39.6 to -27.4 |
| claude-haiku-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 45.2% | -45.2 | -53.8 to -34.9 |
| claude-haiku-5-5-high vs gpt-6.1-terra | 2/4 = 50.0% | 39.9% | +10.1 | -46.8 to +61.0 |
| claude-haiku-5-5-high vs gpt-6.1-terra-high | 2/4 = 50.0% | 42.4% | +7.6 | -46.1 to +62.0 |
| claude-haiku-5-5-high vs gpt-6.1-terra-low | 2/4 = 50.0% | 47.6% | +2.4 | -50.8 to +56.3 |
| claude-haiku-5-5-high vs gpt-6.1-terra-max | 0/4 = 0.0% | 27.3% | -27.3 | -39.8 to -16.7 |
| claude-haiku-5-5-high vs gpt-6.1-terra-off | 1/3 = 33.3% | 41.5% | -8.2 | -49.7 to +58.6 |
| claude-haiku-5-5-high vs gpt-6.1-terra-xhigh | 2/4 = 50.0% | 32.8% | +17.2 | -34.1 to +70.1 |
| claude-haiku-5-5-low vs claude-opus-5-5 | 2/2 = 100.0% | 37.9% | +62.1 | +51.5 to +70.2 |
| claude-haiku-5-5-low vs claude-opus-5-5-high | 1/2 = 50.0% | 30.0% | +20.0 | -35.9 to +76.6 |
| claude-haiku-5-5-low vs claude-opus-5-5-low | 0/2 = 0.0% | 51.0% | -51.0 | -63.7 to -37.5 |
| claude-haiku-5-5-low vs claude-opus-5-5-max | 1/3 = 33.3% | 22.1% | +11.2 | -28.1 to +80.3 |
| claude-haiku-5-5-low vs claude-opus-5-5-off | 1/4 = 25.0% | 34.8% | -9.8 | -42.8 to +51.8 |
| claude-haiku-5-5-low vs claude-sonnet-5-5 | 1/2 = 50.0% | 48.5% | +1.5 | -8.5 to +10.6 |
| claude-haiku-5-5-low vs gpt-5.6-terra | 1/2 = 50.0% | 58.5% | -8.5 | -17.8 to +1.7 |
| claude-haiku-5-5-low vs gpt-6-astra | 0/2 = 0.0% | 29.6% | -29.6 | -38.2 to -21.8 |
| claude-haiku-5-5-low vs gpt-6-astra-high | 0/4 = 0.0% | 26.2% | -26.2 | -38.6 to -16.3 |
| claude-haiku-5-5-low vs gpt-6-astra-low | 0/4 = 0.0% | 32.9% | -32.9 | -45.2 to -21.7 |
| claude-haiku-5-5-low vs gpt-6-astra-low-recall | 3/4 = 75.0% | 35.6% | +39.4 | -27.9 to +73.4 |
| claude-haiku-5-5-low vs gpt-6-luna | 1/2 = 50.0% | 81.8% | -31.8 | -37.9 to -24.4 |
| claude-haiku-5-5-low vs gpt-6.1-sol | 2/2 = 100.0% | 40.6% | +59.4 | +48.6 to +68.2 |
| claude-haiku-5-5-low vs gpt-6.1-terra | 3/4 = 75.0% | 35.5% | +39.5 | -26.3 to +73.1 |
| claude-haiku-5-5-low vs gpt-6.1-terra-high | 3/4 = 75.0% | 37.9% | +37.1 | -25.4 to +71.5 |
| claude-haiku-5-5-low vs gpt-6.1-terra-low | 1/4 = 25.0% | 43.0% | -18.0 | -51.8 to +9.7 |
| claude-haiku-5-5-low vs gpt-6.1-terra-max | 1/4 = 25.0% | 23.8% | +1.2 | -30.4 to +66.9 |
| claude-haiku-5-5-low vs gpt-6.1-terra-off | 3/4 = 75.0% | 37.1% | +37.9 | -26.8 to +71.8 |
| claude-haiku-5-5-low vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 28.8% | -28.8 | -40.0 to -17.7 |
| claude-haiku-5-5-max vs claude-opus-5-5 | 2/2 = 100.0% | 48.1% | +51.9 | +40.0 to +61.4 |
| claude-haiku-5-5-max vs claude-sonnet-5-5 | 1/2 = 50.0% | 58.8% | -8.8 | -18.7 to +1.9 |
| claude-haiku-5-5-max vs gpt-5.6-terra | 1/2 = 50.0% | 68.2% | -18.2 | -27.5 to -8.4 |
| claude-haiku-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 50.9% | -0.9 | -11.6 to +9.2 |
| claude-haiku-5-5-off vs claude-opus-5-5-high | 0/1 = 0.0% | 16.4% | -16.4 | -24.9 to -9.6 |
| claude-haiku-5-5-off vs claude-opus-5-5-low | 0/2 = 0.0% | 32.2% | -32.2 | -43.3 to -21.3 |
| claude-haiku-5-5-off vs claude-opus-5-5-max | 0/2 = 0.0% | 11.5% | -11.5 | -18.1 to -6.2 |
| claude-haiku-5-5-off vs claude-opus-5-5-off | 0/3 = 0.0% | 19.6% | -19.6 | -28.7 to -12.1 |
| claude-haiku-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 39.2% | +10.8 | +0.6 to +19.9 |
| claude-haiku-5-5-off vs gpt-6-astra | 0/2 = 0.0% | 16.2% | -16.2 | -21.8 to -11.0 |
| claude-haiku-5-5-off vs gpt-6-astra-high | 1/3 = 33.3% | 14.0% | +19.3 | -18.1 to +87.2 |
| claude-haiku-5-5-off vs gpt-6-astra-low | 0/3 = 0.0% | 18.3% | -18.3 | -27.1 to -10.8 |
| claude-haiku-5-5-off vs gpt-6-astra-low-recall | 1/4 = 25.0% | 20.2% | +4.8 | -25.6 to +72.2 |
| claude-haiku-5-5-off vs gpt-6-luna | 1/2 = 50.0% | 67.3% | -17.3 | -26.6 to -6.5 |
| claude-haiku-5-5-off vs gpt-6.1-sol | 0/2 = 0.0% | 23.8% | -23.8 | -31.4 to -16.7 |
| claude-haiku-5-5-off vs gpt-6.1-terra | 0/3 = 0.0% | 20.1% | -20.1 | -29.6 to -12.4 |
| claude-haiku-5-5-off vs gpt-6.1-terra-high | 0/4 = 0.0% | 21.8% | -21.8 | -32.8 to -13.2 |
| claude-haiku-5-5-off vs gpt-6.1-terra-low | 2/3 = 66.7% | 25.6% | +41.0 | -25.3 to +81.0 |
| claude-haiku-5-5-off vs gpt-6.1-terra-max | 0/3 = 0.0% | 12.5% | -12.5 | -19.8 to -6.9 |
| claude-haiku-5-5-off vs gpt-6.1-terra-off | 0/4 = 0.0% | 21.2% | -21.2 | -31.5 to -12.8 |
| claude-haiku-5-5-off vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 15.6% | -15.6 | -23.4 to -8.8 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5 | 0/2 = 0.0% | 46.6% | -46.6 | -55.6 to -37.0 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-high | 0/2 = 0.0% | 38.0% | -38.0 | -51.5 to -25.4 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-low | 2/3 = 66.7% | 59.8% | +6.9 | -61.0 to +46.9 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-max | 0/3 = 0.0% | 28.9% | -28.9 | -41.1 to -17.5 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-off | 0/4 = 0.0% | 43.3% | -43.3 | -56.2 to -30.2 |
| claude-haiku-5-5-xhigh vs claude-sonnet-5-5 | 1/2 = 50.0% | 57.4% | -7.4 | -16.5 to +1.8 |
| claude-haiku-5-5-xhigh vs gpt-6-astra | 0/2 = 0.0% | 37.6% | -37.6 | -47.0 to -28.5 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-high | 1/4 = 25.0% | 33.7% | -8.7 | -41.7 to +51.6 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-low | 1/4 = 25.0% | 41.2% | -16.2 | -49.4 to +52.1 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-low-recall | 3/4 = 75.0% | 44.1% | +30.9 | -34.1 to +64.0 |
| claude-haiku-5-5-xhigh vs gpt-6-luna | 2/2 = 100.0% | 86.5% | +13.5 | +8.4 to +19.1 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra | 3/4 = 75.0% | 44.1% | +30.9 | -34.6 to +64.6 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-high | 2/4 = 50.0% | 46.6% | +3.4 | -48.1 to +56.4 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-low | 1/4 = 25.0% | 51.9% | -26.9 | -61.1 to +40.5 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-max | 0/4 = 0.0% | 30.9% | -30.9 | -43.5 to -19.7 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-off | 1/3 = 33.3% | 45.7% | -12.4 | -53.3 to +55.8 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-xhigh | 2/4 = 50.0% | 36.6% | +13.4 | -40.1 to +66.8 |
| claude-opus-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 60.7% | -0.7 | -19.9 to +19.0 |
| claude-opus-5-5 vs claude-sonnet-5-5-high | 2/2 = 100.0% | 57.2% | +42.8 | +32.0 to +51.8 |
| claude-opus-5-5 vs claude-sonnet-5-5-low | 2/4 = 50.0% | 70.6% | -20.6 | -75.2 to +33.2 |
| claude-opus-5-5 vs claude-sonnet-5-5-max | 2/2 = 100.0% | 37.7% | +62.3 | +49.9 to +71.6 |
| claude-opus-5-5 vs claude-sonnet-5-5-off | 1/2 = 50.0% | 63.8% | -13.8 | -22.7 to -4.4 |
| claude-opus-5-5 vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 44.6% | +55.4 | +44.5 to +63.9 |
| claude-opus-5-5 vs gpt-5.6-terra | 12/20 = 60.0% | 69.8% | -9.8 | -22.4 to +3.2 |
| claude-opus-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 71.6% | +28.4 | +18.5 to +37.6 |
| claude-opus-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 73.6% | -23.6 | -32.6 to -13.0 |
| claude-opus-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 61.7% | +38.3 | +25.8 to +49.4 |
| claude-opus-5-5 vs gpt-5.6-terra-xhigh | 2/2 = 100.0% | 61.0% | +39.0 | +26.2 to +50.3 |
| claude-opus-5-5 vs gpt-6-astra | 9/20 = 45.0% | 40.8% | +4.2 | -7.9 to +14.4 |
| claude-opus-5-5 vs gpt-6-astra-high | 2/4 = 50.0% | 36.8% | +13.2 | -38.6 to +68.5 |
| claude-opus-5-5 vs gpt-6-astra-low | 2/4 = 50.0% | 44.6% | +5.4 | -46.5 to +58.7 |
| claude-opus-5-5 vs gpt-6-astra-low-recall | 2/4 = 50.0% | 47.5% | +2.5 | -50.9 to +56.1 |
| claude-opus-5-5 vs gpt-6-luna | 16/20 = 80.0% | 88.1% | -8.1 | -29.7 to +10.2 |
| claude-opus-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 92.3% | +7.7 | +4.0 to +13.3 |
| claude-opus-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 67.7% | -17.7 | -27.8 to -4.1 |
| claude-opus-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 65.5% | -15.5 | -26.2 to -2.8 |
| claude-opus-5-5 vs gpt-6.1-sol | 12/20 = 60.0% | 52.8% | +7.2 | -11.4 to +25.6 |
| claude-opus-5-5 vs gpt-6.1-sol-high | 2/2 = 100.0% | 53.6% | +46.4 | +35.3 to +56.1 |
| claude-opus-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 49.3% | +0.7 | -11.0 to +12.2 |
| claude-opus-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 41.7% | +8.3 | -1.3 to +17.5 |
| claude-opus-5-5 vs gpt-6.1-sol-xhigh | 2/4 = 50.0% | 49.7% | +0.3 | -10.7 to +11.3 |
| claude-opus-5-5 vs gpt-6.1-terra | 2/3 = 66.7% | 47.4% | +19.2 | -4.7 to +60.7 |
| claude-opus-5-5 vs gpt-6.1-terra-high | 0/3 = 0.0% | 50.0% | -50.0 | -62.9 to -36.0 |
| claude-opus-5-5 vs gpt-6.1-terra-low | 3/4 = 75.0% | 55.2% | +19.8 | -39.6 to +53.2 |
| claude-opus-5-5 vs gpt-6.1-terra-max | 1/4 = 25.0% | 33.8% | -8.8 | -42.3 to +55.8 |
| claude-opus-5-5 vs gpt-6.1-terra-off | 1/3 = 33.3% | 49.1% | -15.8 | -57.8 to +53.8 |
| claude-opus-5-5 vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 39.8% | -6.5 | -47.7 to +63.1 |
| claude-opus-5-5-high vs claude-sonnet-5-5 | 1/2 = 50.0% | 68.7% | -18.7 | -28.4 to -7.2 |
| claude-opus-5-5-high vs claude-sonnet-5-5-high | 2/2 = 100.0% | 65.6% | +34.4 | +22.0 to +47.3 |
| claude-opus-5-5-high vs claude-sonnet-5-5-low | 2/2 = 100.0% | 77.4% | +22.6 | +13.4 to +33.9 |
| claude-opus-5-5-high vs claude-sonnet-5-5-off | 2/2 = 100.0% | 71.6% | +28.4 | +18.0 to +40.4 |
| claude-opus-5-5-high vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 53.4% | +46.6 | +32.1 to +59.6 |
| claude-opus-5-5-high vs gpt-6-astra | 1/2 = 50.0% | 49.6% | +0.4 | -11.9 to +12.8 |
| claude-opus-5-5-high vs gpt-6-astra-high | 0/1 = 0.0% | 45.4% | -45.4 | -60.9 to -28.1 |
| claude-opus-5-5-high vs gpt-6-astra-low-recall | 0/1 = 0.0% | 56.3% | -56.3 | -70.3 to -40.0 |
| claude-opus-5-5-high vs gpt-6-luna | 2/2 = 100.0% | 91.3% | +8.7 | +4.8 to +14.7 |
| claude-opus-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 61.5% | -61.5 | -71.8 to -48.1 |
| claude-opus-5-5-high vs gpt-6.1-terra-low | 1/1 = 100.0% | 63.8% | +36.2 | +21.8 to +50.0 |
| claude-opus-5-5-high vs gpt-6.1-terra-max | 1/1 = 100.0% | 42.1% | +57.9 | +40.7 to +72.3 |
| claude-opus-5-5-low vs claude-sonnet-5-5 | 2/3 = 66.7% | 47.5% | +19.1 | -4.3 to +60.2 |
| claude-opus-5-5-low vs claude-sonnet-5-5-high | 2/3 = 66.7% | 44.0% | +22.7 | -45.2 to +64.2 |
| claude-opus-5-5-low vs claude-sonnet-5-5-low | 1/2 = 50.0% | 58.5% | -8.5 | -65.7 to +50.1 |
| claude-opus-5-5-low vs claude-sonnet-5-5-off | 0/3 = 0.0% | 50.9% | -50.9 | -64.5 to -38.3 |
| claude-opus-5-5-low vs claude-sonnet-5-5-xhigh | 0/3 = 0.0% | 32.1% | -32.1 | -45.0 to -21.8 |
| claude-opus-5-5-low vs gpt-5.6-terra | 0/2 = 0.0% | 57.6% | -57.6 | -67.8 to -43.8 |
| claude-opus-5-5-low vs gpt-6-astra-high | 0/1 = 0.0% | 25.5% | -25.5 | -38.3 to -14.4 |
| claude-opus-5-5-low vs gpt-6-astra-low | 0/1 = 0.0% | 32.1% | -32.1 | -45.1 to -19.6 |
| claude-opus-5-5-low vs gpt-6-astra-low-recall | 0/1 = 0.0% | 34.7% | -34.7 | -48.8 to -21.5 |
| claude-opus-5-5-low vs gpt-6-luna | 2/2 = 100.0% | 81.2% | +18.8 | +11.1 to +27.3 |
| claude-opus-5-5-low vs gpt-6.1-terra-max | 0/1 = 0.0% | 23.1% | -23.1 | -36.6 to -13.2 |
| claude-opus-5-5-low vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 28.0% | +72.0 | +56.9 to +83.4 |
| claude-opus-5-5-max vs claude-sonnet-5-5 | 3/3 = 100.0% | 76.8% | +23.2 | +13.9 to +33.5 |
| claude-opus-5-5-max vs claude-sonnet-5-5-high | 3/4 = 75.0% | 74.2% | +0.8 | -66.4 to +33.2 |
| claude-opus-5-5-max vs claude-sonnet-5-5-low | 2/3 = 66.7% | 83.8% | -17.1 | -85.6 to +21.1 |
| claude-opus-5-5-max vs claude-sonnet-5-5-off | 3/3 = 100.0% | 79.2% | +20.8 | +11.8 to +31.2 |
| claude-opus-5-5-max vs claude-sonnet-5-5-xhigh | 2/3 = 66.7% | 63.4% | +3.2 | -64.6 to +45.2 |
| claude-opus-5-5-max vs gpt-6-astra | 1/2 = 50.0% | 59.8% | -9.8 | -22.6 to +3.3 |
| claude-opus-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 70.7% | -20.7 | -31.0 to -8.8 |
| claude-opus-5-5-max vs gpt-6.1-terra | 1/2 = 50.0% | 66.0% | -16.0 | -28.5 to -0.2 |
| claude-opus-5-5-off vs claude-sonnet-5-5 | 3/4 = 75.0% | 63.8% | +11.2 | -56.3 to +43.5 |
| claude-opus-5-5-off vs claude-sonnet-5-5-high | 2/4 = 50.0% | 60.4% | -10.4 | -64.9 to +40.6 |
| claude-opus-5-5-off vs claude-sonnet-5-5-low | 3/3 = 100.0% | 73.3% | +26.7 | +16.8 to +38.0 |
| claude-opus-5-5-off vs claude-sonnet-5-5-off | 3/4 = 75.0% | 66.9% | +8.1 | -68.2 to +40.1 |
| claude-opus-5-5-off vs claude-sonnet-5-5-xhigh | 2/4 = 50.0% | 47.9% | +2.1 | -50.8 to +53.8 |
| claude-opus-5-5-off vs gpt-6-astra-high | 1/1 = 100.0% | 40.0% | +60.0 | +42.8 to +73.5 |
| claude-opus-5-5-off vs gpt-6-astra-low | 1/1 = 100.0% | 47.9% | +52.1 | +36.4 to +65.7 |
| claude-opus-5-5-off vs gpt-6-astra-low-recall | 0/1 = 0.0% | 50.8% | -50.8 | -65.0 to -35.3 |
| claude-opus-5-5-off vs gpt-6-luna-xhigh | 1/2 = 50.0% | 68.5% | -18.5 | -30.9 to -2.3 |
| claude-opus-5-5-off vs gpt-6.1-terra | 1/1 = 100.0% | 50.8% | +49.2 | +33.4 to +64.0 |
| claude-opus-5-5-off vs gpt-6.1-terra-low | 1/1 = 100.0% | 58.5% | +41.5 | +26.3 to +55.7 |
| claude-opus-5-5-off vs gpt-6.1-terra-max | 0/1 = 0.0% | 36.9% | -36.9 | -52.1 to -21.9 |
| claude-opus-5-5-off vs gpt-6.1-terra-off | 1/1 = 100.0% | 52.4% | +47.6 | +31.5 to +62.8 |
| claude-opus-5-5-off vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 43.1% | -43.1 | -57.5 to -27.7 |
| claude-opus-5-5-xhigh vs claude-sonnet-5-5-max | 2/10 = 20.0% | 49.6% | -29.6 | -55.7 to -4.0 |
| claude-opus-5-5-xhigh vs gpt-6-astra | 22/41 = 53.7% | 52.9% | +0.7 | -11.2 to +12.4 |
| claude-opus-5-5-xhigh vs gpt-6-astra-high | 2/4 = 50.0% | 48.7% | +1.3 | -51.5 to +53.7 |
| claude-opus-5-5-xhigh vs gpt-6-astra-low | 2/4 = 50.0% | 56.7% | -6.7 | -59.0 to +47.4 |
| claude-opus-5-5-xhigh vs gpt-6-astra-low-recall | 2/4 = 50.0% | 59.6% | -9.6 | -62.7 to +43.4 |
| claude-opus-5-5-xhigh vs gpt-6.1-sol-max | 4/10 = 40.0% | 53.8% | -13.8 | -36.3 to +1.9 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra | 2/3 = 66.7% | 59.5% | +7.1 | -61.4 to +49.5 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-high | 1/3 = 33.3% | 62.0% | -28.6 | -71.0 to +39.7 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-low | 3/3 = 100.0% | 66.8% | +33.2 | +21.7 to +45.9 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-max | 5/5 = 100.0% | 45.5% | +54.5 | +40.8 to +68.9 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-off | 1/3 = 33.3% | 61.1% | -27.8 | -69.8 to +39.6 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 51.9% | -18.6 | -60.1 to +48.3 |
| claude-sonnet-5-5 vs gpt-5.6-terra | 11/20 = 55.0% | 60.0% | -5.0 | -28.1 to +18.6 |
| claude-sonnet-5-5 vs gpt-5.6-terra-high | 1/2 = 50.0% | 62.0% | -12.0 | -22.6 to -0.3 |
| claude-sonnet-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.3% | -14.3 | -24.6 to -2.3 |
| claude-sonnet-5-5 vs gpt-5.6-terra-xhigh | 0/2 = 0.0% | 50.4% | -50.4 | -61.7 to -36.7 |
| claude-sonnet-5-5 vs gpt-6-astra | 7/20 = 35.0% | 30.9% | +4.1 | -11.4 to +17.9 |
| claude-sonnet-5-5 vs gpt-6-astra-high | 3/4 = 75.0% | 27.4% | +47.6 | -25.3 to +79.2 |
| claude-sonnet-5-5 vs gpt-6-astra-low | 1/4 = 25.0% | 34.3% | -9.3 | -41.4 to +68.7 |
| claude-sonnet-5-5 vs gpt-6-astra-low-recall | 2/4 = 50.0% | 37.0% | +13.0 | -40.0 to +66.8 |
| claude-sonnet-5-5 vs gpt-6-luna | 17/20 = 85.0% | 82.7% | +2.3 | -14.1 to +15.5 |
| claude-sonnet-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.6% | +11.4 | +6.1 to +19.0 |
| claude-sonnet-5-5 vs gpt-6-luna-off | 2/2 = 100.0% | 88.3% | +11.7 | +6.7 to +18.0 |
| claude-sonnet-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 55.2% | -5.2 | -17.6 to +8.1 |
| claude-sonnet-5-5 vs gpt-6.1-sol | 8/20 = 40.0% | 42.1% | -2.1 | -19.6 to +16.8 |
| claude-sonnet-5-5 vs gpt-6.1-sol-high | 1/2 = 50.0% | 42.8% | +7.2 | -3.1 to +17.2 |
| claude-sonnet-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 38.6% | +11.4 | +0.1 to +22.0 |
| claude-sonnet-5-5 vs gpt-6.1-sol-max | 0/2 = 0.0% | 31.7% | -31.7 | -39.4 to -23.5 |
| claude-sonnet-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 39.1% | +10.9 | -0.3 to +20.3 |
| claude-sonnet-5-5 vs gpt-6.1-terra | 1/4 = 25.0% | 36.9% | -11.9 | -43.1 to +53.6 |
| claude-sonnet-5-5 vs gpt-6.1-terra-high | 0/4 = 0.0% | 39.3% | -39.3 | -51.6 to -27.0 |
| claude-sonnet-5-5 vs gpt-6.1-terra-low | 2/4 = 50.0% | 44.5% | +5.5 | -46.2 to +58.8 |
| claude-sonnet-5-5 vs gpt-6.1-terra-max | 1/4 = 25.0% | 24.9% | +0.1 | -31.4 to +71.1 |
| claude-sonnet-5-5 vs gpt-6.1-terra-off | 2/4 = 50.0% | 38.5% | +11.5 | -39.6 to +64.8 |
| claude-sonnet-5-5 vs gpt-6.1-terra-xhigh | 3/4 = 75.0% | 30.0% | +45.0 | -21.1 to +78.4 |
| claude-sonnet-5-5-high vs gpt-5.6-terra | 1/2 = 50.0% | 63.4% | -13.4 | -22.5 to -2.3 |
| claude-sonnet-5-5-high vs gpt-6-astra | 2/2 = 100.0% | 34.1% | +65.9 | +55.7 to +73.9 |
| claude-sonnet-5-5-high vs gpt-6-astra-high | 2/4 = 50.0% | 30.4% | +19.6 | -31.7 to +72.9 |
| claude-sonnet-5-5-high vs gpt-6-astra-low | 2/4 = 50.0% | 37.6% | +12.4 | -39.3 to +66.6 |
| claude-sonnet-5-5-high vs gpt-6-astra-low-recall | 0/4 = 0.0% | 40.4% | -40.4 | -53.6 to -27.4 |
| claude-sonnet-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 84.7% | -34.7 | -39.9 to -27.1 |
| claude-sonnet-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 45.6% | -45.6 | -54.9 to -34.4 |
| claude-sonnet-5-5-high vs gpt-6.1-terra | 1/3 = 33.3% | 40.3% | -7.0 | -48.4 to +59.8 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-high | 3/3 = 100.0% | 42.8% | +57.2 | +43.6 to +70.7 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-low | 1/4 = 25.0% | 48.0% | -23.0 | -58.4 to +47.4 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-max | 1/4 = 25.0% | 27.7% | -2.7 | -35.7 to +61.2 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-off | 1/3 = 33.3% | 41.9% | -8.6 | -50.0 to +58.7 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 33.1% | -33.1 | -46.6 to -20.4 |
| claude-sonnet-5-5-low vs gpt-6-astra | 0/2 = 0.0% | 22.3% | -22.3 | -30.3 to -15.4 |
| claude-sonnet-5-5-low vs gpt-6-astra-high | 0/4 = 0.0% | 19.5% | -19.5 | -30.0 to -10.9 |
| claude-sonnet-5-5-low vs gpt-6-astra-low | 0/4 = 0.0% | 25.1% | -25.1 | -35.8 to -15.6 |
| claude-sonnet-5-5-low vs gpt-6-astra-low-recall | 0/4 = 0.0% | 27.4% | -27.4 | -39.8 to -16.9 |
| claude-sonnet-5-5-low vs gpt-6-luna | 1/2 = 50.0% | 75.4% | -25.4 | -33.3 to -15.2 |
| claude-sonnet-5-5-low vs gpt-6.1-sol | 1/2 = 50.0% | 31.8% | +18.2 | +8.5 to +27.1 |
| claude-sonnet-5-5-low vs gpt-6.1-terra | 1/4 = 25.0% | 27.3% | -2.3 | -35.1 to +25.6 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-high | 1/4 = 25.0% | 29.4% | -4.4 | -36.9 to +61.5 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-low | 3/4 = 75.0% | 34.0% | +41.0 | -23.1 to +74.4 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-max | 1/3 = 33.3% | 17.6% | +15.8 | -22.1 to +83.7 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-off | 0/4 = 0.0% | 28.7% | -28.7 | -41.0 to -17.9 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-xhigh | 1/4 = 25.0% | 21.6% | +3.4 | -27.1 to +72.6 |
| claude-sonnet-5-5-max vs gpt-6-astra | 4/10 = 40.0% | 53.3% | -13.3 | -36.2 to +4.4 |
| claude-sonnet-5-5-max vs gpt-6-luna | 2/2 = 100.0% | 92.4% | +7.6 | +4.6 to +11.9 |
| claude-sonnet-5-5-max vs gpt-6.1-sol | 2/2 = 100.0% | 65.0% | +35.0 | +24.5 to +45.0 |
| claude-sonnet-5-5-max vs gpt-6.1-sol-max | 6/10 = 60.0% | 54.2% | +5.8 | -11.0 to +30.4 |
| claude-sonnet-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 56.7% | -6.7 | -16.2 to +3.9 |
| claude-sonnet-5-5-off vs gpt-6-astra | 2/2 = 100.0% | 28.1% | +71.9 | +62.1 to +78.7 |
| claude-sonnet-5-5-off vs gpt-6-astra-high | 0/4 = 0.0% | 24.8% | -24.8 | -36.1 to -14.7 |
| claude-sonnet-5-5-off vs gpt-6-astra-low | 1/4 = 25.0% | 31.3% | -6.3 | -37.9 to +60.5 |
| claude-sonnet-5-5-off vs gpt-6-astra-low-recall | 1/4 = 25.0% | 33.9% | -8.9 | -42.9 to +54.4 |
| claude-sonnet-5-5-off vs gpt-6-luna | 2/2 = 100.0% | 80.7% | +19.3 | +12.7 to +27.1 |
| claude-sonnet-5-5-off vs gpt-6.1-sol | 1/2 = 50.0% | 38.8% | +11.2 | +1.6 to +20.3 |
| claude-sonnet-5-5-off vs gpt-6.1-terra | 0/4 = 0.0% | 33.8% | -33.8 | -46.5 to -22.2 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-high | 0/4 = 0.0% | 36.2% | -36.2 | -49.0 to -23.3 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-low | 1/4 = 25.0% | 41.1% | -16.1 | -50.2 to +48.1 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-max | 1/4 = 25.0% | 22.5% | +2.5 | -27.9 to +72.8 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-off | 1/4 = 25.0% | 35.3% | -10.3 | -43.3 to +52.8 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-xhigh | 1/4 = 25.0% | 27.3% | -2.3 | -34.1 to +68.5 |
| claude-sonnet-5-5-xhigh vs gpt-5.6-terra | 2/2 = 100.0% | 74.2% | +25.8 | +18.1 to +34.0 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra | 1/2 = 50.0% | 46.1% | +3.9 | -6.2 to +13.7 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-high | 1/4 = 25.0% | 42.0% | -17.0 | -51.4 to +48.2 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-low | 3/4 = 75.0% | 50.0% | +25.0 | -43.4 to +60.8 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-low-recall | 4/4 = 100.0% | 52.9% | +47.1 | +34.3 to +61.2 |
| claude-sonnet-5-5-xhigh vs gpt-6-luna | 2/2 = 100.0% | 90.1% | +9.9 | +6.2 to +14.3 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 58.2% | -8.2 | -17.1 to +2.1 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra | 2/3 = 66.7% | 52.8% | +13.8 | -53.7 to +56.2 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-high | 2/3 = 66.7% | 55.4% | +11.3 | -56.1 to +55.2 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-low | 2/4 = 50.0% | 60.5% | -10.5 | -64.3 to +42.3 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-max | 2/4 = 50.0% | 38.8% | +11.2 | -41.4 to +64.2 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-off | 3/3 = 100.0% | 54.5% | +45.5 | +32.5 to +59.9 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-xhigh | 2/3 = 66.7% | 45.1% | +21.5 | -2.6 to +64.8 |
| gpt-5.6-terra vs gpt-6-astra | 5/20 = 25.0% | 23.0% | +2.0 | -12.5 to +18.5 |
| gpt-5.6-terra vs gpt-6-astra-low-recall | 0/1 = 0.0% | 28.1% | -28.1 | -39.4 to -18.2 |
| gpt-5.6-terra vs gpt-6-luna | 15/20 = 75.0% | 76.1% | -1.1 | -22.9 to +18.6 |
| gpt-5.6-terra vs gpt-6-luna-high | 2/2 = 100.0% | 55.7% | +44.3 | +30.1 to +57.3 |
| gpt-5.6-terra vs gpt-6-luna-low | 1/2 = 50.0% | 83.8% | -33.8 | -40.6 to -23.6 |
| gpt-5.6-terra vs gpt-6-luna-max | 2/2 = 100.0% | 47.6% | +52.4 | +37.7 to +63.8 |
| gpt-5.6-terra vs gpt-6-luna-off | 2/2 = 100.0% | 83.4% | +16.6 | +9.6 to +25.7 |
| gpt-5.6-terra vs gpt-6.1-sol | 6/20 = 30.0% | 32.6% | -2.6 | -18.1 to +13.2 |
| gpt-5.6-terra vs gpt-6.1-sol-high | 0/2 = 0.0% | 33.3% | -33.3 | -42.3 to -23.4 |
| gpt-5.6-terra vs gpt-6.1-sol-low | 0/2 = 0.0% | 29.6% | -29.6 | -40.1 to -19.9 |
| gpt-5.6-terra vs gpt-6.1-sol-max | 0/2 = 0.0% | 23.6% | -23.6 | -30.6 to -16.4 |
| gpt-5.6-terra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 30.0% | -30.0 | -40.1 to -21.1 |
| gpt-5.6-terra vs gpt-6.1-terra-off | 0/1 = 0.0% | 29.4% | -29.4 | -40.3 to -19.1 |
| gpt-5.6-terra vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 22.3% | -22.3 | -31.6 to -13.4 |
| gpt-5.6-terra-high vs gpt-6-astra-low-recall | 0/1 = 0.0% | 26.5% | -26.5 | -40.1 to -14.7 |
| gpt-5.6-terra-high vs gpt-6-luna | 1/2 = 50.0% | 74.6% | -24.6 | -32.9 to -12.0 |
| gpt-5.6-terra-high vs gpt-6.1-sol | 1/2 = 50.0% | 30.8% | +19.2 | +7.9 to +28.6 |
| gpt-5.6-terra-low vs gpt-6-astra | 0/2 = 0.0% | 19.9% | -19.9 | -28.4 to -12.4 |
| gpt-5.6-terra-low vs gpt-6.1-terra-high | 0/1 = 0.0% | 26.4% | -26.4 | -39.2 to -15.2 |
| gpt-5.6-terra-max vs gpt-6-astra | 1/2 = 50.0% | 30.0% | +20.0 | +7.7 to +29.9 |
| gpt-5.6-terra-max vs gpt-6-luna | 2/2 = 100.0% | 82.0% | +18.0 | +10.7 to +27.1 |
| gpt-5.6-terra-xhigh vs gpt-6-astra | 0/2 = 0.0% | 30.6% | -30.6 | -40.7 to -20.2 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-high | 1/1 = 100.0% | 27.1% | +72.9 | +56.3 to +84.3 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-low | 1/1 = 100.0% | 33.9% | +66.1 | +49.9 to +78.8 |
| gpt-5.6-terra-xhigh vs gpt-6.1-sol | 0/2 = 0.0% | 41.7% | -41.7 | -53.4 to -28.9 |
| gpt-5.6-terra-xhigh vs gpt-6.1-terra-low | 0/1 = 0.0% | 44.1% | -44.1 | -59.4 to -28.4 |
| gpt-6-astra vs gpt-6-luna | 19/20 = 95.0% | 91.4% | +3.6 | -7.7 to +11.0 |
| gpt-6-astra vs gpt-6-luna-high | 1/2 = 50.0% | 80.8% | -30.8 | -38.0 to -20.1 |
| gpt-6-astra vs gpt-6-luna-max | 2/2 = 100.0% | 75.3% | +24.7 | +15.7 to +35.5 |
| gpt-6-astra vs gpt-6-luna-off | 2/2 = 100.0% | 94.4% | +5.6 | +3.1 to +9.0 |
| gpt-6-astra vs gpt-6-luna-xhigh | 1/2 = 50.0% | 73.3% | -23.3 | -32.1 to -11.5 |
| gpt-6-astra vs gpt-6.1-sol | 12/20 = 60.0% | 61.9% | -1.9 | -21.1 to +15.1 |
| gpt-6-astra vs gpt-6.1-sol-high | 1/2 = 50.0% | 62.6% | -12.6 | -21.7 to -1.8 |
| gpt-6-astra vs gpt-6.1-sol-low | 3/4 = 75.0% | 58.5% | +16.5 | -13.7 to +48.3 |
| gpt-6-astra vs gpt-6.1-sol-max | 6/10 = 60.0% | 50.9% | +9.1 | -6.5 to +31.9 |
| gpt-6-astra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 58.9% | -58.9 | -67.9 to -47.1 |
| gpt-6-astra vs gpt-6.1-terra-max | 0/1 = 0.0% | 42.6% | -42.6 | -55.4 to -28.3 |
| gpt-6-astra-high vs gpt-6.1-sol | 1/2 = 50.0% | 65.8% | -15.8 | -27.0 to -3.1 |
| gpt-6-astra-high vs gpt-6.1-sol-high | 1/1 = 100.0% | 66.4% | +33.6 | +20.3 to +46.7 |
| gpt-6-astra-high vs gpt-6.1-terra | 0/1 = 0.0% | 60.8% | -60.8 | -74.1 to -43.8 |
| gpt-6-astra-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 63.2% | +36.8 | +21.9 to +52.7 |
| gpt-6-astra-high vs gpt-6.1-terra-low | 2/2 = 100.0% | 67.9% | +32.1 | +18.4 to +46.3 |
| gpt-6-astra-high vs gpt-6.1-terra-max | 1/2 = 50.0% | 46.7% | +3.3 | -57.0 to +61.9 |
| gpt-6-astra-high vs gpt-6.1-terra-off | 1/1 = 100.0% | 62.3% | +37.7 | +22.8 to +52.8 |
| gpt-6-astra-high vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 53.2% | -53.2 | -68.3 to -34.9 |
| gpt-6-astra-low vs gpt-6-luna | 2/2 = 100.0% | 90.2% | +9.8 | +5.4 to +15.2 |
| gpt-6-astra-low vs gpt-6.1-sol | 1/2 = 50.0% | 58.2% | -8.2 | -19.5 to +3.7 |
| gpt-6-astra-low vs gpt-6.1-sol-low | 0/1 = 0.0% | 54.7% | -54.7 | -69.0 to -39.8 |
| gpt-6-astra-low vs gpt-6.1-terra | 1/1 = 100.0% | 52.9% | +47.1 | +30.6 to +61.4 |
| gpt-6-astra-low vs gpt-6.1-terra-high | 1/1 = 100.0% | 55.4% | +44.6 | +28.5 to +59.7 |
| gpt-6-astra-low vs gpt-6.1-terra-low | 0/1 = 0.0% | 60.5% | -60.5 | -74.1 to -44.2 |
| gpt-6-astra-low vs gpt-6.1-terra-max | 0/2 = 0.0% | 38.9% | -38.9 | -55.1 to -24.1 |
| gpt-6-astra-low vs gpt-6.1-terra-off | 0/1 = 0.0% | 54.5% | -54.5 | -68.6 to -38.4 |
| gpt-6-astra-low vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 45.2% | +54.8 | +38.0 to +69.9 |
| gpt-6-astra-low-recall vs gpt-6-luna-xhigh | 1/1 = 100.0% | 67.7% | +32.3 | +19.3 to +46.4 |
| gpt-6-astra-low-recall vs gpt-6.1-sol | 0/1 = 0.0% | 55.3% | -55.3 | -66.8 to -42.2 |
| gpt-6-astra-low-recall vs gpt-6.1-terra | 0/1 = 0.0% | 49.9% | -49.9 | -64.4 to -34.1 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-high | 1/1 = 100.0% | 52.5% | +47.5 | +31.0 to +63.1 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-low | 2/2 = 100.0% | 57.7% | +42.3 | +26.8 to +57.6 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-max | 0/1 = 0.0% | 36.1% | -36.1 | -51.1 to -22.1 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-off | 1/1 = 100.0% | 51.6% | +48.4 | +32.5 to +64.1 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 42.3% | +7.7 | -50.0 to +67.4 |
| gpt-6-luna vs gpt-6.1-sol | 3/20 = 15.0% | 13.2% | +1.8 | -12.6 to +16.5 |
| gpt-6-luna vs gpt-6.1-sol-high | 1/2 = 50.0% | 13.5% | +36.5 | +29.7 to +41.6 |
| gpt-6-luna vs gpt-6.1-sol-low | 0/2 = 0.0% | 11.6% | -11.6 | -18.3 to -6.7 |
| gpt-6-luna vs gpt-6.1-sol-max | 0/2 = 0.0% | 8.8% | -8.8 | -13.2 to -5.6 |
| gpt-6-luna vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 11.8% | -11.8 | -18.1 to -7.0 |
| gpt-6-luna-high vs gpt-6.1-sol | 1/2 = 50.0% | 27.8% | +22.2 | +8.5 to +32.3 |
| gpt-6-luna-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 25.6% | +74.4 | +57.2 to +85.3 |
| gpt-6-luna-high vs gpt-6.1-terra-off | 0/1 = 0.0% | 24.9% | -24.9 | -39.2 to -13.5 |
| gpt-6-luna-low vs gpt-6.1-sol | 0/2 = 0.0% | 8.6% | -8.6 | -14.1 to -4.3 |
| gpt-6-luna-max vs gpt-6.1-sol | 0/2 = 0.0% | 34.8% | -34.8 | -46.4 to -22.9 |
| gpt-6-luna-max vs gpt-6.1-terra-off | 1/2 = 50.0% | 31.5% | +18.5 | +3.4 to +30.6 |
| gpt-6-luna-off vs gpt-6.1-sol | 1/2 = 50.0% | 8.8% | +41.2 | +35.5 to +44.8 |
| gpt-6-luna-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 37.1% | +12.9 | +1.2 to +23.4 |
| gpt-6-luna-xhigh vs gpt-6.1-terra-low | 1/2 = 50.0% | 39.4% | +10.6 | -5.7 to +24.6 |
| gpt-6.1-sol vs gpt-6.1-terra | 1/2 = 50.0% | 44.6% | +5.4 | -7.5 to +17.1 |
| gpt-6.1-sol vs gpt-6.1-terra-low | 1/1 = 100.0% | 52.4% | +47.6 | +34.1 to +60.1 |
| gpt-6.1-sol vs gpt-6.1-terra-max | 1/1 = 100.0% | 31.3% | +68.7 | +55.3 to +78.0 |
| gpt-6.1-sol-high vs gpt-6.1-terra | 1/2 = 50.0% | 43.9% | +6.1 | -7.6 to +19.5 |
| gpt-6.1-sol-low vs gpt-6.1-terra-max | 1/1 = 100.0% | 34.5% | +65.5 | +49.8 to +78.0 |
| gpt-6.1-sol-max vs gpt-6.1-terra-max | 1/2 = 50.0% | 41.7% | +8.3 | -5.8 to +21.7 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-high | 1/2 = 50.0% | 50.3% | -0.3 | -15.1 to +14.9 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-max | 0/1 = 0.0% | 34.1% | -34.1 | -46.5 to -20.8 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 40.1% | +9.9 | -3.2 to +23.0 |
#### Haiku 4.5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-high | 9/20 = 45.0% | 61.6% | -16.6 | -32.6 to -1.4 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-low | 12/20 = 60.0% | 57.4% | +2.6 | -15.8 to +20.2 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-minimal | 10/20 = 50.0% | 55.2% | -5.2 | -25.2 to +14.2 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 74.9% | +5.1 | -10.1 to +20.5 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-low | 8/20 = 40.0% | 45.7% | -5.7 | -23.4 to +11.5 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal | 11/20 = 55.0% | 43.4% | +11.6 | -6.9 to +31.7 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 65.1% | -0.1 | -18.4 to +17.4 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-minimal | 6/20 = 30.0% | 47.7% | -17.7 | -37.9 to +1.0 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-off | 15/20 = 75.0% | 68.9% | +6.1 | -9.2 to +22.8 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 70.8% | -5.8 | -27.5 to +14.8 |
#### Haiku 5.5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-5-5 vs claude-haiku-5-5-high | 7/20 = 35.0% | 45.5% | -10.5 | -25.3 to +3.4 |
| claude-haiku-5-5 vs claude-haiku-5-5-low | 8/20 = 40.0% | 50.2% | -10.2 | -28.9 to +7.7 |
| claude-haiku-5-5 vs claude-haiku-5-5-max | 9/20 = 45.0% | 39.9% | +5.1 | -11.1 to +22.2 |
| claude-haiku-5-5 vs claude-haiku-5-5-off | 14/20 = 70.0% | 68.8% | +1.2 | -14.1 to +16.7 |
| claude-haiku-5-5 vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 41.3% | -6.3 | -26.3 to +12.7 |
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 54.7% | +10.3 | -8.9 to +30.7 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 44.3% | +0.7 | -19.1 to +21.3 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 72.5% | -7.5 | -21.9 to +7.2 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 45.8% | -15.8 | -32.1 to -1.4 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 39.7% | -4.7 | -22.4 to +13.9 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 68.6% | -13.6 | -36.7 to +6.6 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 41.2% | -1.2 | -16.4 to +11.9 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 76.8% | +3.2 | -11.8 to +17.2 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 51.5% | -6.5 | -24.2 to +9.1 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 24.2% | +0.8 | -16.8 to +20.9 |
#### Luna efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-luna vs gpt-6-luna-high | 8/20 = 40.0% | 28.3% | +11.7 | -8.7 to +33.7 |
| gpt-6-luna vs gpt-6-luna-low | 12/20 = 60.0% | 61.9% | -1.9 | -24.0 to +20.0 |
| gpt-6-luna vs gpt-6-luna-max | 5/20 = 25.0% | 22.2% | +2.8 | -12.3 to +18.4 |
| gpt-6-luna vs gpt-6-luna-off | 12/20 = 60.0% | 61.2% | -1.2 | -21.7 to +18.6 |
| gpt-6-luna vs gpt-6-luna-xhigh | 2/20 = 10.0% | 20.5% | -10.5 | -23.0 to +2.4 |
| gpt-6-luna-high vs gpt-6-luna-low | 14/20 = 70.0% | 80.5% | -10.5 | -27.2 to +3.5 |
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 41.9% | -6.9 | -26.6 to +12.3 |
| gpt-6-luna-high vs gpt-6-luna-off | 18/20 = 90.0% | 80.0% | +10.0 | -3.4 to +22.9 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 39.5% | +15.5 | -2.5 to +36.2 |
| gpt-6-luna-low vs gpt-6-luna-max | 2/20 = 10.0% | 14.9% | -4.9 | -16.8 to +8.9 |
| gpt-6-luna-low vs gpt-6-luna-off | 8/20 = 40.0% | 49.3% | -9.3 | -27.5 to +5.9 |
| gpt-6-luna-low vs gpt-6-luna-xhigh | 3/20 = 15.0% | 13.7% | +1.3 | -13.3 to +21.7 |
| gpt-6-luna-max vs gpt-6-luna-off | 16/20 = 80.0% | 84.7% | -4.7 | -19.2 to +8.6 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 47.5% | +2.5 | -11.8 to +16.6 |
| gpt-6-luna-off vs gpt-6-luna-xhigh | 2/20 = 10.0% | 14.0% | -4.0 | -15.2 to +9.3 |
#### Opus efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5 vs claude-opus-5-5-high | 9/20 = 45.0% | 41.2% | +3.8 | -15.3 to +24.5 |
| claude-opus-5-5 vs claude-opus-5-5-low | 13/20 = 65.0% | 63.0% | +2.0 | -12.3 to +17.7 |
| claude-opus-5-5 vs claude-opus-5-5-max | 4/10 = 40.0% | 31.7% | +8.3 | -25.5 to +46.0 |
| claude-opus-5-5 vs claude-opus-5-5-off | 3/4 = 75.0% | 46.7% | +28.3 | +0.6 to +62.4 |
| claude-opus-5-5 vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 38.0% | -3.0 | -19.2 to +11.7 |
| claude-opus-5-5-high vs claude-opus-5-5-low | 1/2 = 50.0% | 70.8% | -20.8 | -76.9 to +36.8 |
| claude-opus-5-5-high vs claude-opus-5-5-max | 1/2 = 50.0% | 39.8% | +10.2 | -48.5 to +69.1 |
| claude-opus-5-5-high vs claude-opus-5-5-off | 3/5 = 60.0% | 55.5% | +4.5 | -46.2 to +48.0 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 46.6% | -11.6 | -30.5 to +5.6 |
| claude-opus-5-5-low vs claude-opus-5-5-max | 3/10 = 30.0% | 21.4% | +8.6 | -20.6 to +49.6 |
| claude-opus-5-5-low vs claude-opus-5-5-off | 3/5 = 60.0% | 33.9% | +26.1 | -25.5 to +70.7 |
| claude-opus-5-5-low vs claude-opus-5-5-xhigh | 0/3 = 0.0% | 26.5% | -26.5 | -37.0 to -17.1 |
| claude-opus-5-5-max vs claude-opus-5-5-off | 2/2 = 100.0% | 65.3% | +34.7 | +20.1 to +49.6 |
| claude-opus-5-5-max vs claude-opus-5-5-xhigh | 5/10 = 50.0% | 56.9% | -6.9 | -36.2 to +21.1 |
| claude-opus-5-5-off vs claude-opus-5-5-xhigh | 3/4 = 75.0% | 41.2% | +33.8 | -28.2 to +67.6 |
#### Sol efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-sol vs gpt-6.1-sol-high | 12/20 = 60.0% | 50.7% | +9.3 | -3.3 to +23.6 |
| gpt-6.1-sol vs gpt-6.1-sol-low | 7/20 = 35.0% | 46.5% | -11.5 | -29.5 to +6.9 |
| gpt-6.1-sol vs gpt-6.1-sol-max | 8/20 = 40.0% | 39.0% | +1.0 | -17.0 to +19.1 |
| gpt-6.1-sol vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 46.9% | +3.1 | -18.2 to +24.2 |
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 45.7% | +14.3 | -1.9 to +31.8 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 38.3% | +6.7 | -11.2 to +26.4 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 46.2% | -1.2 | -17.1 to +14.5 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 42.4% | -12.4 | -32.2 to +5.5 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 50.5% | +9.5 | -6.0 to +27.0 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 58.1% | -8.1 | -23.9 to +4.9 |
#### Sonnet efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-sonnet-5-5 vs claude-sonnet-5-5-high | 7/20 = 35.0% | 46.4% | -11.4 | -30.8 to +8.3 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-low | 11/20 = 55.0% | 60.9% | -5.9 | -27.5 to +15.0 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-max | 8/20 = 40.0% | 28.1% | +11.9 | -5.3 to +29.9 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-off | 10/20 = 50.0% | 53.4% | -3.4 | -23.0 to +16.1 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 34.3% | +10.7 | -9.5 to +32.8 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 64.2% | -9.2 | -34.4 to +14.2 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 31.1% | +8.9 | -11.5 to +30.0 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 56.9% | +13.1 | -1.8 to +30.5 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 37.6% | -12.6 | -31.4 to +6.6 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 20.1% | -5.1 | -18.8 to +9.7 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 42.4% | +7.6 | -9.6 to +27.5 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 25.1% | -5.1 | -20.9 to +9.5 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 74.5% | -4.5 | -29.1 to +16.5 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 57.2% | +7.8 | -10.7 to +26.5 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 31.3% | +23.7 | +12.8 to +37.1 |
#### Terra 6.1 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-terra vs gpt-6.1-terra-high | 1/3 = 33.3% | 52.6% | -19.2 | -62.4 to +7.3 |
| gpt-6.1-terra vs gpt-6.1-terra-low | 2/3 = 66.7% | 57.8% | +8.9 | -17.1 to +51.6 |
| gpt-6.1-terra vs gpt-6.1-terra-max | 0/1 = 0.0% | 36.2% | -36.2 | -51.4 to -21.9 |
| gpt-6.1-terra vs gpt-6.1-terra-off | 2/3 = 66.7% | 51.7% | +15.0 | -10.2 to +58.1 |
| gpt-6.1-terra vs gpt-6.1-terra-xhigh | 3/3 = 100.0% | 42.3% | +57.7 | +41.3 to +71.4 |
| gpt-6.1-terra-high vs gpt-6.1-terra-low | 0/1 = 0.0% | 55.2% | -55.2 | -70.8 to -38.0 |
| gpt-6.1-terra-high vs gpt-6.1-terra-max | 0/1 = 0.0% | 33.8% | -33.8 | -49.9 to -20.1 |
| gpt-6.1-terra-high vs gpt-6.1-terra-off | 1/2 = 50.0% | 49.1% | +0.9 | -57.8 to +59.4 |
| gpt-6.1-terra-high vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 39.8% | -6.5 | -48.2 to +67.5 |
| gpt-6.1-terra-low vs gpt-6.1-terra-max | 1/1 = 100.0% | 29.3% | +70.7 | +53.8 to +82.3 |
| gpt-6.1-terra-low vs gpt-6.1-terra-off | 3/3 = 100.0% | 43.9% | +56.1 | +39.4 to +71.3 |
| gpt-6.1-terra-low vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 34.9% | -34.9 | -49.1 to -19.9 |
| gpt-6.1-terra-max vs gpt-6.1-terra-off | 0/1 = 0.0% | 65.4% | -65.4 | -78.0 to -47.8 |
| gpt-6.1-terra-max vs gpt-6.1-terra-xhigh | 3/3 = 100.0% | 56.4% | +43.6 | +27.9 to +60.1 |
| gpt-6.1-terra-off vs gpt-6.1-terra-xhigh | 0/2 = 0.0% | 40.7% | -40.7 | -56.6 to -25.5 |
#### Terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-5.6-terra vs gpt-5.6-terra-high | 10/20 = 50.0% | 52.1% | -2.1 | -17.0 to +11.3 |
| gpt-5.6-terra vs gpt-5.6-terra-low | 11/20 = 55.0% | 54.6% | +0.4 | -16.6 to +16.6 |
| gpt-5.6-terra vs gpt-5.6-terra-max | 8/20 = 40.0% | 41.1% | -1.1 | -19.6 to +20.1 |
| gpt-5.6-terra vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 40.4% | -5.4 | -20.6 to +9.5 |
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 52.5% | -7.5 | -26.6 to +9.7 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.1% | +0.9 | -16.9 to +17.0 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 38.4% | +11.6 | -6.3 to +34.9 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 36.7% | +3.3 | -16.2 to +22.9 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 36.0% | -16.0 | -32.6 to -2.3 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 49.3% | +5.7 | -11.8 to +23.3 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| Astra efforts | - | - | - | - | - | - | 7 seed blocks, under the minimum of 10: the fit with seat and starter terms can be singular on so few, so not tested |
| Cross-model | 0.5858 | 0.5861 | -0.0003 | -0.0005 to -0.0001 | 0: 36, 0.1: 3, 0.2: 10, 0.4: 1 | tau=0.1: 0.5859, tau=0.2: 0.5862, tau=0.4: 0.5875, tau=0.8: 0.5933, tau=1.6: 0.6139 | not kept |
| Cross-model (seat and starter terms) | 0.5767 | 0.5769 | -0.0002 | -0.0004 to -0.0000 | 0: 41, 0.1: 3, 0.2: 5, 0.4: 1 | tau=0.1: 0.5768, tau=0.2: 0.5771, tau=0.4: 0.5783, tau=0.8: 0.5838, tau=1.6: 0.6043 | not kept |
| Haiku 4.5 efforts | 0.6741 | 0.6788 | -0.0047 | -0.0098 to -0.0003 | 0: 24, 0.1: 1, 0.2: 13, 0.4: 11, 0.8: 1 | tau=0.1: 0.6740, tau=0.2: 0.6738, tau=0.4: 0.6752, tau=0.8: 0.6808, tau=1.6: 0.6867 | not kept |
| Haiku 4.5 efforts (seat and starter terms) | 0.6724 | 0.6766 | -0.0042 | -0.0107 to +0.0019 | 0: 21, 0.1: 4, 0.2: 8, 0.4: 15, 0.8: 2 | tau=0.1: 0.6722, tau=0.2: 0.6720, tau=0.4: 0.6734, tau=0.8: 0.6798, tau=1.6: 0.6865 | not kept |
| Haiku 5.5 efforts | 0.6626 | 0.6639 | -0.0013 | -0.0029 to +0.0001 | 0: 43, 0.1: 1, 0.2: 2, 0.4: 4 | tau=0.1: 0.6630, tau=0.2: 0.6640, tau=0.4: 0.6677, tau=0.8: 0.6751, tau=1.6: 0.6810 | not kept |
| Haiku 5.5 efforts (seat and starter terms) | 0.6371 | 0.6378 | -0.0007 | -0.0015 to -0.0001 | 0: 45, 0.1: 2, 0.2: 2, 0.4: 1 | tau=0.1: 0.6374, tau=0.2: 0.6385, tau=0.4: 0.6425, tau=0.8: 0.6505, tau=1.6: 0.6573 | not kept |
| Luna efforts | 0.5746 | 0.5777 | -0.0031 | -0.0056 to -0.0008 | 0: 29, 0.1: 7, 0.2: 7, 0.4: 7 | tau=0.1: 0.5747, tau=0.2: 0.5752, tau=0.4: 0.5778, tau=0.8: 0.5853, tau=1.6: 0.5941 | not kept |
| Luna efforts (seat and starter terms) | 0.5821 | 0.5854 | -0.0033 | -0.0063 to -0.0008 | 0: 32, 0.1: 2, 0.2: 11, 0.4: 4, 0.8: 1 | tau=0.1: 0.5821, tau=0.2: 0.5822, tau=0.4: 0.5840, tau=0.8: 0.5911, tau=1.6: 0.6003 | not kept |
| Opus efforts | 0.6995 | 0.7092 | -0.0097 | -0.0191 to -0.0028 | 0: 46, 0.2: 2, 0.8: 1, 1.6: 1 | tau=0.1: 0.7001, tau=0.2: 0.7019, tau=0.4: 0.7073, tau=0.8: 0.7194, tau=1.6: 0.7410 | not kept |
| Opus efforts (seat and starter terms) | 0.7080 | 0.7157 | -0.0077 | -0.0140 to -0.0027 | 0: 47, 0.1: 1, 0.8: 1, 1.6: 1 | tau=0.1: 0.7087, tau=0.2: 0.7105, tau=0.4: 0.7162, tau=0.8: 0.7288, tau=1.6: 0.7497 | not kept |
| Sol efforts | 0.7059 | 0.7089 | -0.0031 | -0.0087 to +0.0016 | 0: 12, 0.1: 10, 0.2: 13, 0.4: 15 | tau=0.1: 0.7058, tau=0.2: 0.7058, tau=0.4: 0.7078, tau=0.8: 0.7147, tau=1.6: 0.7212 | not kept |
| Sol efforts (seat and starter terms) | 0.7088 | 0.7112 | -0.0024 | -0.0079 to +0.0026 | 0: 17, 0.1: 6, 0.2: 12, 0.4: 14, 0.8: 1 | tau=0.1: 0.7085, tau=0.2: 0.7080, tau=0.4: 0.7085, tau=0.8: 0.7134, tau=1.6: 0.7186 | not kept |
| Sonnet efforts | 0.6726 | 0.6746 | -0.0020 | -0.0075 to +0.0035 | 0: 7, 0.1: 6, 0.2: 16, 0.4: 21 | tau=0.1: 0.6722, tau=0.2: 0.6716, tau=0.4: 0.6723, tau=0.8: 0.6787, tau=1.6: 0.6865 | not kept |
| Sonnet efforts (seat and starter terms) | 0.6706 | 0.6725 | -0.0020 | -0.0078 to +0.0032 | 0: 10, 0.1: 6, 0.2: 13, 0.4: 21 | tau=0.1: 0.6702, tau=0.2: 0.6697, tau=0.4: 0.6707, tau=0.8: 0.6776, tau=1.6: 0.6856 | not kept |
| Terra 6.1 efforts | 0.8144 | 0.8388 | -0.0244 | -0.1052 to +0.0381 | 0: 5, 0.2: 1, 0.4: 6, 0.8: 17, 1.6: 21 | tau=0.1: 0.8140, tau=0.2: 0.8128, tau=0.4: 0.8090, tau=0.8: 0.8018, tau=1.6: 0.8137 | not kept |
| Terra 6.1 efforts (seat and starter terms) | 0.9434 | 0.9515 | -0.0080 | -0.0774 to +0.0504 | 0: 11, 0.1: 1, 0.2: 1, 0.4: 7, 0.8: 17, 1.6: 13 | tau=0.1: 0.9428, tau=0.2: 0.9410, tau=0.4: 0.9348, tau=0.8: 0.9227, tau=1.6: 0.9366 | not kept |
| Terra efforts | 0.6904 | 0.6930 | -0.0026 | -0.0044 to -0.0008 | 0: 33, 0.1: 3, 0.2: 8, 0.4: 6 | tau=0.1: 0.6908, tau=0.2: 0.6920, tau=0.4: 0.6962, tau=0.8: 0.7041, tau=1.6: 0.7104 | not kept |
| Terra efforts (seat and starter terms) | 0.7018 | 0.7041 | -0.0024 | -0.0040 to -0.0008 | 0: 39, 0.1: 2, 0.2: 6, 0.4: 3 | tau=0.1: 0.7022, tau=0.2: 0.7036, tau=0.4: 0.7084, tau=0.8: 0.7178, tau=1.6: 0.7256 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| Cross-model | 233/414 = 56.3% | -0.10 |
| Haiku 4.5 efforts | 7/10 = 70.0% | +0.05 |
| Haiku 5.5 efforts | 5/15 = 33.3% | -0.44 |
| Luna efforts | 7/15 = 46.7% | -0.09 |
| Opus efforts | 4/15 = 26.7% | -0.31 |
| Sol efforts | 6/10 = 60.0% | -0.18 |
| Sonnet efforts | 6/15 = 40.0% | -0.04 |
| Terra 6.1 efforts | 6/8 = 75.0% | +0.58 |
| Terra efforts | 4/10 = 40.0% | -0.15 |
| all cohorts pooled | 278/512 = 54.3% | -0.09 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 1.3e-16, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 3537 of 3537 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 1392 blocks, 128 seeds (753 matches in half blocks left out) | 1392/2784 = 50.0% | 43.8% to 56.6% | 48.1% to 51.9% |
| Astra efforts: 2 blocks, 1 seeds (5 matches in half blocks left out) | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% |
| Cross-model: 575 blocks, 118 seeds (710 matches in half blocks left out) | 544/1150 = 47.3% | 40.2% to 54.3% | 44.3% to 50.1% |
| Haiku 4.5 efforts: 100 blocks, 10 seeds | 105/200 = 52.5% | 43.0% to 60.5% | 45.5% to 59.0% |
| Haiku 5.5 efforts: 150 blocks, 10 seeds | 142/300 = 47.3% | 35.0% to 59.7% | 41.7% to 53.3% |
| Luna efforts: 150 blocks, 10 seeds | 160/300 = 53.3% | 47.0% to 59.3% | 48.3% to 58.3% |
| Opus efforts: 58 blocks, 18 seeds (21 matches in half blocks left out) | 61/116 = 52.6% | 39.4% to 67.2% | 43.1% to 62.1% |
| Sol efforts: 100 blocks, 10 seeds | 111/200 = 55.5% | 43.0% to 68.0% | 48.0% to 62.5% |
| Sonnet efforts: 150 blocks, 10 seeds | 162/300 = 54.0% | 43.0% to 64.3% | 48.3% to 59.3% |
| Terra 6.1 efforts: 7 blocks, 7 seeds (17 matches in half blocks left out) | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% |
| Terra efforts: 100 blocks, 10 seeds | 96/200 = 48.0% | 36.0% to 58.5% | 40.5% to 55.5% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 1578/2784 = 56.7% | 50.8% to 62.3% | 54.9% to 58.5% | 673/1392 |
| Astra efforts | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% | 2/2 |
| Cross-model | 668/1150 = 58.1% | 51.8% to 63.5% | 55.4% to 60.7% | 261/575 |
| Haiku 4.5 efforts | 115/200 = 57.5% | 50.5% to 66.0% | 51.0% to 64.0% | 50/100 |
| Haiku 5.5 efforts | 186/300 = 62.0% | 51.0% to 71.7% | 56.3% to 67.3% | 75/150 |
| Luna efforts | 152/300 = 50.7% | 44.3% to 57.0% | 46.0% to 55.7% | 75/150 |
| Opus efforts | 67/116 = 57.8% | 44.2% to 70.9% | 48.3% to 66.4% | 31/58 |
| Sol efforts | 107/200 = 53.5% | 40.0% to 66.0% | 45.5% to 61.0% | 50/100 |
| Sonnet efforts | 164/300 = 54.7% | 43.7% to 65.0% | 49.3% to 60.3% | 75/150 |
| Terra 6.1 efforts | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% | 4/7 |
| Terra efforts | 108/200 = 54.0% | 42.5% to 64.5% | 46.5% to 61.5% | 50/100 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +0.2 | -5.8 to +5.8 | -1.6 to +2.0 | +6.7 | +0.5 to +12.6 | +4.9 to +8.5 |
| Cross-model | -2.0 | -7.7 to +3.7 | -4.8 to +0.8 | +7.9 | +1.6 to +13.3 | +5.2 to +10.6 |
| Haiku 4.5 efforts | +2.5 | -6.6 to +9.5 | -4.3 to +8.9 | +7.5 | +1.0 to +16.5 | +0.7 to +14.2 |
| Haiku 5.5 efforts | -2.7 | -13.8 to +7.8 | -8.2 to +3.2 | +12.0 | +0.7 to +22.3 | +6.5 to +17.5 |
| Luna efforts | +3.3 | -3.5 to +9.6 | -1.6 to +8.3 | +0.7 | -5.6 to +7.4 | -4.1 to +5.7 |
| Opus efforts | +2.1 | -11.1 to +16.3 | -7.3 to +11.3 | +7.6 | -6.2 to +20.9 | -1.7 to +16.5 |
| Sol efforts | +5.5 | -7.5 to +19.0 | -2.1 to +12.6 | +3.5 | -10.0 to +16.2 | -4.0 to +10.9 |
| Sonnet efforts | +4.0 | -7.2 to +14.5 | -1.7 to +9.4 | +4.7 | -6.7 to +15.3 | -0.7 to +10.4 |
| Terra 6.1 efforts | +6.2 | -20.8 to +33.3 | -20.8 to +35.4 | +6.2 | -20.8 to +33.3 | -20.8 to +35.0 |
| Terra efforts | -2.0 | -14.3 to +8.8 | -9.3 to +5.5 | +4.0 | -7.7 to +15.4 | -3.5 to +11.3 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| claude-haiku-4-5-20251001: 262 blocks, 73 seeds | 258/524 = 49.2% | 43.7% to 54.7% | 45.2% to 53.4% |
| claude-haiku-5-5: 328 blocks, 82 seeds | 309/656 = 47.1% | 39.5% to 55.4% | 43.0% to 51.1% |
| claude-opus-5-5: 203 blocks, 57 seeds | 198/406 = 48.8% | 40.2% to 57.7% | 43.6% to 53.9% |
| claude-sonnet-5-5: 299 blocks, 41 seeds | 303/598 = 50.7% | 43.1% to 58.6% | 46.7% to 54.5% |
| gpt-5.6-terra: 208 blocks, 19 seeds | 217/416 = 52.2% | 43.3% to 61.4% | 46.9% to 57.0% |
| gpt-6-astra: 134 blocks, 47 seeds | 129/268 = 48.1% | 39.3% to 58.2% | 42.2% to 54.1% |
| gpt-6-luna: 269 blocks, 27 seeds | 266/538 = 49.4% | 44.3% to 54.3% | 45.9% to 53.0% |
| gpt-6.1-sol: 242 blocks, 39 seeds | 235/484 = 48.6% | 39.6% to 57.6% | 43.6% to 53.3% |
| gpt-6.1-terra: 22 blocks, 12 seeds | 21/44 = 47.7% | 27.8% to 64.0% | 31.8% to 63.7% |

#### Per seed, all cohorts

Cohorts reuse seeds 3000 to 3018 (tournament 3 adds 3020 to 3029, and tournament 5 many seeds from 4000 up, most with one block), so a seed's starter result pools many pairings.

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
| the 19 seeds with 10 or more blocks, each once |  | 1225 | mean of seed shares 57.7% (95% CI 51.7% to 63.8%, seeds drawn) |

### Tournament 3

| scored matches | Opus xhigh wins/matches = share | 95% CI (seed blocks drawn, wins over matches) | mean of block shares (a block counts once) | 95% CI | Opus minus Astra, Elo (95% CI) | blocks Opus both / split / Astra both |
|---|---|---|---|---|---|---|
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 39.0% to 68.3% | 52.4% | 38.1% to 66.7% | +25 (-84 to +132) | 6 / 10 / 4 |
| 40 matches, 20 complete seed pairs | 22/40 = 55.0% | 40.0% to 70.0% | 55.0% | 40.0% to 70.0% | +35 (-70 to +146) | 6 / 10 / 4 |

The 41-match estimate adds seed 3030's one scored match, which Astra won, to the 40 matches of complete pairs.

#### Matched against Opus medium vs Astra on the same seeds (tournament 1)

| matched seeds | Opus xhigh wins | Opus medium wins | difference in share (95% CI, seeds drawn) |
|---|---|---|---|
| 10 seeds, 20 matches each | 10/20 | 9/20 | +5.0 pp (-15.0 to +25.0) |

The matched seeds are 3000 to 3009, so the matched estimate is the same whether tournament 3 counts 40 or 41 matches.
<!-- tables:end -->

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
