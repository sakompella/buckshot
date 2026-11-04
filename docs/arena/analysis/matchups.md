# Matchup analysis

Ratings, pair effects, seat and round 1 starter effects for the scored arena matches, from the analysis database ([database.md](../database.md)). All scored matches are two-player. Every rate shows numerator/denominator, a win share counts a split by its share, and every interval is a 95% bootstrap that draws whole units, never single matches or seat swaps: seed blocks (the two seat-swapped matches of one pair and seed) for ratings, and seeds (every block played at a seed, in any pairing) for the headline seat and starter figures. The tables below the line "Tables" are generated: `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` rewrites them, with a fixed RNG seed, in about 70 minutes under `nice` on the 2,915-match snapshot. Nothing here reads provenance or account data.

**DeepSeek is left out.** Every match with deepseek-v4.1-flash (20 scored matches) is dropped from all cohorts, fits, seat and starter figures and tables, because its free tier refused requests, so its games are not a random sample of what was scheduled. That leaves 2,895 scored matches from the 2,915-match snapshot of 2026-11-04. Every finding below uses these.

## Findings

**Ratings are pooled.** One Bradley-Terry fit covers every scored match of every tournament, so all 49 configs share one Elo scale with the mean at 0, as in the viewer. Tournament 4 gave every older config games against other models, so no rating leans on an assumption that effort gaps carry across opponents. Ten newer configs have only 20 to 26 matches against changing opponents, so their intervals are 235 to 390 Elo wide and their point ratings mostly reflect the prior pulling a thin record. `results.md` and the viewer show the same ratings. A second fit on pot share (a config's cash over the match's cash, which credits the round prizes a loser banks) gives the cash rating. Cohorts are only a way to group matches. A cohort is one kind of comparison, pooled over every tournament: Cross-model (every match between different models) or one model's efforts (every match of that model against itself), as in the viewer. There are ten: Cross-model and the efforts of Astra, Haiku 4.5, Haiku 5.5, Luna, Opus, Sol, Sonnet, Terra and Terra 6.1.
- **Coverage.** The Cross-model cohort has 49 entrants and 1,255 matches over 329 of the 1,176 pairs, 1 to 41 matches per pair. Each older effort cohort is a round robin with 20 matches per pair. Opus efforts plays 10 of its 15 pairs (2 to 20 matches each), Terra 6.1 efforts 9 of 15 (1 to 2 matches each) and Astra efforts 4 of 6 (1 to 2 matches each). Tournament 5 is finished; the scheduled matches it did not play stay unstarted in the table below.
- **Cross-model medium configs**, win rating (95% CI by seed blocks): astra +153 (+111 to +201), opus +83 (+40 to +128), sol +71 (+30 to +116), sonnet +22 (-20 to +65), haiku 5.5 +21 (-16 to +57), terra -51 (-97 to -8), haiku 4.5 -177 (-228 to -131), luna -252 (-317 to -201). Astra stands above and luna and haiku 4.5 below; the middle ones overlap. Drawing seeds instead of blocks moves the intervals modestly.
- **Top and bottom.** Among configs with 80 or more matches, Sonnet max +190 (+124 to +262), Opus xhigh +156 (+91 to +223), astra +153 and Sol max +148 lead. Haiku 4.5 off -349, luna low -338 and luna off -333 trail. Opus max (40 matches, +144, +35 to +267) sits with the leaders. Terra 6.1 max (20 matches, +272, +123 to +511) rates highest but its interval is too wide to place it. Effort configs from the older tournaments have 90 to 165 matches each, so their intervals are about 120 to 210 Elo wide.
- **Effort.** Within each model the top level is xhigh or max in every model with a sweep or effort tournament, Opus included: luna xhigh -18 and max -38 against medium -252, sonnet max +190 against medium +22, haiku 5.5 xhigh +104, terra xhigh +13 (max +10), sol max +148, Opus max +144 and xhigh +156 against medium +83. Haiku 4.5 has no such level; its top is medium (-177) and minimal (-202). Off or low is the bottom level in the older sweeps: luna low -338, haiku 4.5 off -349, haiku 5.5 off -95, sonnet low -27, terra low -86 and Opus low -9. Opus off (+112, 26 matches, -4 to +239) is not at the bottom, but its interval is wide. Sol is the exception: high +63 sits at the bottom of a flat range up to +148 (medium +71), and the intervals overlap. Terra 6.1 has max on top and no clear order below it (max +272, low +81, xhigh +55, medium +33, off +8, high -64), and every effort has an interval 235 to 390 Elo wide. The order of neighbouring levels is mostly inside the intervals.
- **Cash.** Cash ratings spread less than win ratings among configs with 80 or more matches (+117 to -220 against +190 to -349), because losers bank round prizes. The two ratings agree on the leaders (Sonnet max +117, Sol max +98, Opus xhigh +92) and the trailers (luna low -220). A config can win less than it earns: Opus low wins 39.6% of its 48 matches yet takes 51.4% of the pot (cash +50, win -9), and terra high wins 44.0% and takes 49.5% (cash +0, win -67). Haiku 5.5 xhigh is the reverse: 61.2% of wins, 53.2% of the pot, cash +19 against win +104.

**Matchup effects: none worth keeping.** The observed pair share minus the share fitted by the pooled ratings is small and is reported as a descriptive residual. It is not a test: the ratings are regularized, so residuals are forced (a pair at the end of a chain of pairs is pulled to its fit), and the bootstrap range around a residual is not a calibrated interval around zero. The largest Cross-model residual over a pair of 20 matches or more is haiku 4.5 against opus (+16.8 points). Pairs of 2 matches are too thin to read.
- The test is held-out prediction. Whole seed blocks were held out (5 repeats of 10-fold cross-validation, with the shrinkage chosen inside each training set from 0 to 1.6, so no held-out block picks it). Pair effects are fitted only for pairs seen in more than one seed block: a pair confined to one block has no training data when that block is held out, so its games still count in the test score but it gets no pair term. Terra 6.1 efforts has 9 seed blocks and Astra efforts 4, under the minimum of 10 this test needs (the fit with seat and starter terms can be singular on so few), so neither is tested. In every other cohort the nested pair-effect model scored no better than ratings alone: the gain per match is between -0.0073 and -0.0001 nats, and the lower end of its interval is never above 0. The shrinkage chose 0 (ratings only) in most folds for Cross-model, Haiku 5.5, Luna, Opus and Terra. So **no tested cohort keeps pair effects**. Cross-model holds tournament 4's one-block pairs, tournament 5's and the 41-match Opus xhigh against Astra pair.
- The same holds when the ratings also have a seat term and a round 1 starter term, which on their own lower the Cross-model loss from 0.6191 to 0.6069 per match.
- Reverse pairs, described and not tested: for the entrant seated first, a real matchup effect should show the opposite sign when A sat first and when B sat first. 110 of 231 pairs (47.6%) do, with a correlation of -0.23 between the A-first effect and minus the B-first effect (a negative value means the two orders lean the same way). The signs are not independent (the two orders of a block share a seed, seeds are reused across pairings, and the ratings are fitted jointly), so no test is made. The two entrants' effects in a pair sum to zero to rounding (6e-17) because every match's shares sum to 1.
- With 20 matches per pair in the effort cohorts and 2 in most of Cross-model, only large pair effects could show.

**Seat and starter.** Whoever opens round 1 (read from the public line `Round 1 begins ... Player X starts.` of each match's events) also fired the first shot in 2895 of 2895 matches. The seed decides that position, and both matches of a block share it.
- **Position 1:** 1392/2784 = 50.0% over 1,392 complete blocks at 128 seeds (95% CI by seeds 43.5% to 56.3%; by seed blocks 48.2% to 51.8%). Cross-model 544/1150 = 47.3% (40.6% to 54.6% by seeds).
- **Starter:** the player who opens round 1 won 1578/2784 = 56.7% (50.6% to 62.3% by seeds; 54.8% to 58.5% by seed blocks). The overall starter association stands: it is about 7 points above even.
- **Split:** the position and starter effects below are a descriptive additive split of block shares by which position starts. Every complete-block seed has exactly one starter position, so a starter effect cannot be told from a seed effect. The split describes these seed blocks; only the seeds-drawn intervals reach beyond them. Starter +6.7 points overall (seeds +0.6 to +12.2; blocks +4.8 to +8.5), +7.9 Cross-model (+1.9 to +13.4; blocks +5.1 to +10.5). Position +0.2 overall (-5.7 to +5.7 by seeds).
- **It depends on the seed.** The starter won 173/244 = 70.9% of matches at seed 3000 and 28/74 = 37.8% at seed 3005. Counting each of the 19 seeds with 10 or more blocks once, the starter's mean share is 57.7% (51.7% to 63.8%, seeds drawn). Starter figures are therefore not reported per model: a model's blocks cover a handful of seeds, so they say as much about those seeds as about the model. Position 1 per model is in the tables.
- **Recommendation:** a starter term is worth keeping as an option for future ratings. It lowers held-out loss a lot (Cross-model 0.6191 to 0.6069 per match) and moves the pooled ratings by up to 49.0 Elo. The headline fits stay without it.

**Tournament 3 (Opus xhigh against Astra medium).**
- **41 matches** (21 seed blocks, seed 3030 half): Opus 22/41 = 53.7% (38.5% to 68.3%); Elo gap +25 (-84 to +139), in a fit of the two alone.
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
- **Unmatched blocks.** Half blocks (111 matches, 105 of them Cross-model) cannot be matched and are left out of every seat figure.
- **Power.** The held-out test can rule out large pair effects only; "none kept" is not "none exist". Cohorts with 58 blocks (Opus efforts) are the weakest, and a pair-effect model with 4 pairs is almost saturated.
- **Thin cells.** Tournament 4 has one seat-swapped block (2 matches) per pair, so one pair says little; its value is that it links every config to the others. Sonnet max's cross-model rating rests on 8 tournament-4 matches, 2 tournament-1 games and the 30 top-four matches of tournament 5.
- **Position and starter overlap** because the seed fixes the starter's position, and tournament 1's seeds 3000 to 3009 start position 2 six times in ten.
- **No replays.** Everything comes from standings, cash, seating and the public round 1 line; no moves were reviewed.

## Tables

<!-- tables:start -->
### Schedule coverage

| cohort | entrants | scored matches | complete / half blocks | pairs played | matches per pair min / median / max | connected | scheduled by status |
|---|---|---|---|---|---|---|---|
| Astra efforts | 4 | 6 | 2 / 2 | 4/6 | 1 / 1.5 / 2 | yes | 6 completed, 10 unstarted |
| Cross-model | 49 | 1255 | 575 / 105 | 329/1176 | 1 / 2 / 41 | yes | 1255 completed, 5 partial (skipped), 138 skipped (skipped), 184 unstarted |
| Haiku 4.5 efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| Haiku 5.5 efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Luna efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Opus efforts | 6 | 118 | 58 / 2 | 10/15 | 2 / 10 / 20 | yes | 118 completed, 2 unstarted |
| Sol efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| Sonnet efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Terra 6.1 efforts | 6 | 16 | 7 / 2 | 9/15 | 1 / 2 / 2 | yes | 16 completed, 18 unstarted |
| Terra efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |

### Pooled ratings

| config | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) | pot share | cash rating (Elo, mean 0) | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|---|
| gpt-6.1-terra-max | 15/20 = 75.0% | +272 | +123 to +511 | +124 to +483 | 69.8% | +192 | +96 to +325 |
| claude-sonnet-5-5-max | 94/140 = 67.1% | +190 | +124 to +262 | +102 to +295 | 62.3% | +117 | +82 to +155 |
| claude-opus-5-5-xhigh | 60/112 = 53.6% | +156 | +91 to +223 | +94 to +222 | 52.4% | +92 | +56 to +126 |
| gpt-6-astra | 169/254 = 66.5% | +153 | +111 to +201 | +112 to +199 | 60.2% | +85 | +62 to +110 |
| gpt-6.1-sol-max | 70/122 = 57.4% | +148 | +87 to +207 | +85 to +214 | 54.9% | +98 | +63 to +131 |
| claude-opus-5-5-max | 24/40 = 60.0% | +144 | +35 to +267 | +21 to +276 | 55.0% | +89 | +30 to +147 |
| gpt-6-astra-low-recall | 13/20 = 65.0% | +133 | -11 to +312 | -20 to +323 | 61.3% | +92 | +18 to +178 |
| claude-sonnet-5-5-xhigh | 72/122 = 59.0% | +117 | +53 to +187 | +45 to +199 | 54.3% | +55 | +20 to +91 |
| gpt-6-astra-high | 11/20 = 55.0% | +113 | -34 to +283 | -37 to +273 | 55.1% | +84 | +1 to +172 |
| claude-opus-5-5-off | 15/26 = 57.7% | +112 | -4 to +239 | -8 to +249 | 55.1% | +70 | +5 to +131 |
| claude-haiku-5-5-xhigh | 71/116 = 61.2% | +104 | +37 to +174 | +34 to +171 | 53.2% | +19 | -14 to +54 |
| claude-haiku-5-5-max | 68/111 = 61.3% | +100 | +30 to +172 | +18 to +200 | 58.7% | +50 | +16 to +83 |
| gpt-6.1-sol-low | 51/98 = 52.0% | +93 | +17 to +169 | +29 to +158 | 50.9% | +62 | +21 to +104 |
| gpt-6.1-sol-xhigh | 52/101 = 51.5% | +87 | +20 to +155 | +20 to +154 | 52.4% | +68 | +31 to +105 |
| claude-opus-5-5-high | 27/57 = 47.4% | +84 | -16 to +179 | -25 to +192 | 47.3% | +41 | -12 to +93 |
| claude-opus-5-5 | 158/269 = 58.7% | +83 | +40 to +128 | +36 to +131 | 54.7% | +46 | +23 to +68 |
| gpt-6.1-terra-low | 11/20 = 55.0% | +81 | -53 to +229 | -59 to +236 | 52.1% | +37 | -41 to +111 |
| gpt-6.1-sol | 155/271 = 57.2% | +71 | +30 to +116 | +14 to +132 | 56.8% | +57 | +34 to +81 |
| claude-sonnet-5-5-high | 63/123 = 51.2% | +68 | -8 to +144 | -5 to +143 | 49.7% | +28 | -14 to +69 |
| gpt-6.1-sol-high | 47/99 = 47.5% | +63 | -3 to +132 | -11 to +123 | 48.0% | +43 | +3 to +83 |
| claude-haiku-5-5-high | 73/130 = 56.2% | +59 | -4 to +122 | +6 to +111 | 53.8% | +16 | -19 to +50 |
| gpt-6.1-terra-xhigh | 10/20 = 50.0% | +55 | -116 to +239 | -113 to +238 | 44.9% | +2 | -106 to +110 |
| claude-sonnet-5-5-off | 57/121 = 47.1% | +40 | -32 to +108 | -24 to +107 | 47.0% | +9 | -29 to +46 |
| gpt-6.1-terra | 10/21 = 47.6% | +33 | -89 to +146 | -93 to +143 | 48.4% | +13 | -50 to +79 |
| claude-haiku-5-5-low | 84/153 = 54.9% | +22 | -41 to +82 | -36 to +85 | 53.6% | -3 | -36 to +29 |
| claude-sonnet-5-5 | 147/292 = 50.3% | +22 | -20 to +65 | -23 to +67 | 50.5% | +10 | -12 to +33 |
| claude-haiku-5-5 | 164/311 = 52.7% | +21 | -16 to +57 | -13 to +56 | 51.7% | +3 | -18 to +23 |
| gpt-6-astra-low | 9/20 = 45.0% | +18 | -138 to +146 | -143 to +154 | 50.1% | +38 | -32 to +119 |
| gpt-5.6-terra-xhigh | 53/93 = 57.0% | +13 | -66 to +93 | -70 to +90 | 55.1% | +35 | -6 to +76 |
| gpt-5.6-terra-max | 52/90 = 57.8% | +10 | -77 to +97 | -62 to +75 | 53.8% | +22 | -24 to +66 |
| gpt-6.1-terra-off | 11/20 = 55.0% | +8 | -136 to +169 | -133 to +160 | 50.0% | -23 | -103 to +59 |
| claude-opus-5-5-low | 19/48 = 39.6% | -9 | -109 to +83 | -118 to +89 | 51.4% | +50 | -3 to +100 |
| gpt-6-luna-xhigh | 79/115 = 68.7% | -18 | -99 to +63 | -87 to +49 | 63.6% | -7 | -50 to +38 |
| claude-sonnet-5-5-low | 44/121 = 36.4% | -27 | -103 to +41 | -97 to +43 | 42.0% | -21 | -60 to +18 |
| gpt-6-luna-max | 75/112 = 67.0% | -38 | -120 to +50 | -113 to +36 | 63.2% | -13 | -59 to +32 |
| gpt-5.6-terra | 119/259 = 45.9% | -51 | -97 to -8 | -102 to -9 | 48.0% | -20 | -43 to +3 |
| gpt-6.1-terra-high | 9/20 = 45.0% | -64 | -227 to +100 | -232 to +95 | 51.4% | -16 | -112 to +86 |
| gpt-5.6-terra-high | 40/91 = 44.0% | -67 | -152 to +11 | -134 to -14 | 49.5% | +0 | -43 to +39 |
| gpt-5.6-terra-low | 37/91 = 40.7% | -86 | -168 to -9 | -159 to -11 | 45.5% | -23 | -62 to +19 |
| gpt-6-luna-high | 67/112 = 59.8% | -94 | -185 to -2 | -192 to +13 | 55.5% | -65 | -107 to -25 |
| claude-haiku-5-5-off | 71/165 = 43.0% | -95 | -159 to -32 | -157 to -35 | 42.8% | -93 | -127 to -60 |
| claude-haiku-4-5-20251001 | 110/308 = 35.7% | -177 | -228 to -131 | -231 to -131 | 39.6% | -119 | -145 to -93 |
| claude-haiku-4-5-20251001-minimal | 54/112 = 48.2% | -202 | -285 to -124 | -275 to -135 | 47.1% | -142 | -185 to -101 |
| claude-haiku-4-5-20251001-low | 51/115 = 44.3% | -224 | -301 to -156 | -303 to -152 | 47.7% | -137 | -177 to -100 |
| claude-haiku-4-5-20251001-high | 45/106 = 42.5% | -247 | -328 to -175 | -361 to -155 | 46.7% | -149 | -190 to -111 |
| gpt-6-luna | 74/282 = 26.2% | -252 | -317 to -201 | -305 to -205 | 34.1% | -151 | -178 to -126 |
| gpt-6-luna-off | 29/110 = 26.4% | -333 | -437 to -248 | -446 to -235 | 33.8% | -205 | -254 to -159 |
| gpt-6-luna-low | 28/110 = 25.5% | -338 | -448 to -242 | -406 to -280 | 31.4% | -220 | -269 to -170 |
| claude-haiku-4-5-20251001-off | 28/101 = 27.7% | -349 | -451 to -264 | -458 to -254 | 36.1% | -217 | -262 to -175 |

With a seat term and a round 1 starter term in the fit (position 1 -0 Elo, the starter +53 Elo) the largest rating change is 49.0 Elo.


### Observed pairs against the pooled ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below. Every resample refits the pooled ratings.

#### Astra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-astra vs gpt-6-astra-high | 1/2 = 50.0% | 55.7% | -5.7 | -23.5 to +17.3 |
| gpt-6-astra vs gpt-6-astra-low | 2/2 = 100.0% | 68.5% | +31.5 | +13.7 to +45.3 |
| gpt-6-astra-high vs gpt-6-astra-low | 1/1 = 100.0% | 63.3% | +36.7 | +12.4 to +59.5 |
| gpt-6-astra-low vs gpt-6-astra-low-recall | 1/1 = 100.0% | 34.0% | +66.0 | +37.3 to +85.6 |
#### Cross-model

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-5-5 | 8/31 = 25.8% | 24.2% | +1.6 | -10.3 to +13.9 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-high | 1/12 = 8.3% | 20.4% | -12.1 | -25.5 to +7.2 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-low | 4/14 = 28.6% | 24.1% | +4.5 | -16.3 to +24.3 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-max | 0/2 = 0.0% | 16.8% | -16.8 | -23.4 to -10.9 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-off | 5/12 = 41.7% | 38.4% | +3.2 | -25.6 to +34.8 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-xhigh | 1/2 = 50.0% | 16.6% | +33.4 | +26.3 to +38.8 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5 | 7/20 = 35.0% | 18.2% | +16.8 | -2.3 to +36.9 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-low | 0/2 = 0.0% | 27.5% | -27.5 | -40.1 to -16.8 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5 | 2/20 = 10.0% | 24.2% | -14.2 | -26.4 to +1.0 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-high | 0/2 = 0.0% | 19.6% | -19.6 | -28.9 to -12.4 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-low | 0/2 = 0.0% | 29.6% | -29.6 | -40.6 to -20.0 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 10.8% | -10.8 | -16.0 to -6.5 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-off | 0/4 = 0.0% | 22.3% | -22.3 | -31.2 to -14.9 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-xhigh | 0/2 = 0.0% | 15.5% | -15.5 | -22.3 to -9.9 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra | 6/20 = 30.0% | 32.6% | -2.6 | -18.7 to +13.4 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-low | 0/2 = 0.0% | 37.2% | -37.2 | -48.9 to -25.1 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-max | 0/2 = 0.0% | 25.4% | -25.4 | -35.7 to -15.7 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-xhigh | 1/2 = 50.0% | 25.0% | +25.0 | +14.2 to +33.4 |
| claude-haiku-4-5-20251001 vs gpt-6-astra | 3/20 = 15.0% | 13.0% | +2.0 | -12.5 to +19.3 |
| claude-haiku-4-5-20251001 vs gpt-6-astra-low-recall | 0/1 = 0.0% | 14.4% | -14.4 | -28.5 to -5.4 |
| claude-haiku-4-5-20251001 vs gpt-6-luna | 12/20 = 60.0% | 60.5% | -0.5 | -25.6 to +24.6 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-high | 1/2 = 50.0% | 38.3% | +11.7 | -2.3 to +24.5 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-off | 2/2 = 100.0% | 71.0% | +29.0 | +17.0 to +40.2 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 28.6% | +21.4 | +9.0 to +30.6 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol | 6/20 = 30.0% | 19.3% | +10.7 | -8.7 to +32.7 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-high | 1/2 = 50.0% | 20.1% | +29.9 | +21.1 to +36.4 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-low | 1/2 = 50.0% | 17.4% | +32.6 | +23.4 to +38.7 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 18.0% | +32.0 | +24.2 to +37.7 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-high | 0/1 = 0.0% | 34.2% | -34.2 | -55.5 to -15.2 |
| claude-haiku-4-5-20251001 vs gpt-6.1-terra-off | 0/1 = 0.0% | 25.7% | -25.7 | -42.6 to -10.3 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5 | 0/1 = 0.0% | 17.6% | -17.6 | -25.0 to -11.4 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-high | 0/1 = 0.0% | 14.7% | -14.7 | -22.2 to -8.8 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-max | 0/1 = 0.0% | 11.9% | -11.9 | -18.9 to -6.6 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-off | 2/10 = 20.0% | 29.5% | -9.5 | -33.0 to +16.7 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-xhigh | 0/1 = 0.0% | 11.7% | -11.7 | -18.1 to -6.8 |
| claude-haiku-4-5-20251001-high vs claude-sonnet-5-5 | 0/2 = 0.0% | 17.6% | -17.6 | -25.2 to -11.0 |
| claude-haiku-4-5-20251001-high vs gpt-5.6-terra | 0/2 = 0.0% | 24.4% | -24.4 | -33.5 to -15.8 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra | 0/2 = 0.0% | 9.1% | -9.1 | -14.1 to -5.4 |
| claude-haiku-4-5-20251001-high vs gpt-6-luna | 0/2 = 0.0% | 50.6% | -50.6 | -62.3 to -36.5 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-sol | 0/2 = 0.0% | 13.8% | -13.8 | -20.7 to -8.2 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-high | 0/1 = 0.0% | 25.8% | -25.8 | -47.9 to -10.2 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-off | 0/1 = 0.0% | 18.8% | -18.8 | -34.8 to -7.0 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5 | 1/3 = 33.3% | 19.7% | +13.7 | -23.9 to +34.8 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5-low | 2/11 = 18.2% | 19.5% | -1.4 | -20.9 to +29.3 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5-off | 4/11 = 36.4% | 32.3% | +4.1 | -27.7 to +50.6 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5 | 0/2 = 0.0% | 14.6% | -14.6 | -21.3 to -8.8 |
| claude-haiku-4-5-20251001-low vs gpt-5.6-terra | 1/2 = 50.0% | 27.0% | +23.0 | +12.8 to +31.4 |
| claude-haiku-4-5-20251001-low vs gpt-6-luna | 2/2 = 100.0% | 54.0% | +46.0 | +32.5 to +57.2 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-sol | 0/2 = 0.0% | 15.5% | -15.5 | -22.4 to -9.8 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-high | 0/1 = 0.0% | 28.5% | -28.5 | -48.5 to -11.6 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-off | 0/1 = 0.0% | 20.9% | -20.9 | -37.4 to -7.6 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5 | 1/2 = 50.0% | 21.7% | +28.3 | +19.4 to +35.5 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5-low | 0/10 = 0.0% | 21.6% | -21.6 | -31.9 to -13.6 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5-off | 3/11 = 27.3% | 35.2% | -7.9 | -33.1 to +14.0 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5 | 1/2 = 50.0% | 16.2% | +33.8 | +24.3 to +39.7 |
| claude-haiku-4-5-20251001-minimal vs claude-sonnet-5-5 | 1/2 = 50.0% | 21.7% | +28.3 | +18.6 to +35.7 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra | 0/2 = 0.0% | 11.5% | -11.5 | -17.5 to -7.0 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-luna | 1/2 = 50.0% | 57.1% | -7.1 | -20.3 to +6.3 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-high | 1/1 = 100.0% | 31.1% | +68.9 | +41.0 to +84.0 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5 | 1/2 = 50.0% | 10.7% | +39.3 | +33.3 to +43.5 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5-off | 3/11 = 27.3% | 18.9% | +8.4 | -19.1 to +43.8 |
| claude-haiku-4-5-20251001-off vs claude-sonnet-5-5 | 1/2 = 50.0% | 10.6% | +39.4 | +32.9 to +43.6 |
| claude-haiku-4-5-20251001-off vs gpt-5.6-terra | 0/2 = 0.0% | 15.3% | -15.3 | -23.6 to -8.7 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra | 0/2 = 0.0% | 5.3% | -5.3 | -8.6 to -2.8 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-sol | 0/2 = 0.0% | 8.2% | -8.2 | -13.1 to -4.4 |
| claude-haiku-5-5 vs claude-opus-5-5 | 7/20 = 35.0% | 41.1% | -6.1 | -21.4 to +8.0 |
| claude-haiku-5-5 vs claude-opus-5-5-high | 0/2 = 0.0% | 41.0% | -41.0 | -53.3 to -27.3 |
| claude-haiku-5-5 vs claude-opus-5-5-low | 1/2 = 50.0% | 54.3% | -4.3 | -18.7 to +9.6 |
| claude-haiku-5-5 vs claude-opus-5-5-max | 1/2 = 50.0% | 33.0% | +17.0 | +0.5 to +29.6 |
| claude-haiku-5-5 vs claude-opus-5-5-off | 1/2 = 50.0% | 37.2% | +12.8 | -4.8 to +27.7 |
| claude-haiku-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 49.9% | +10.1 | -9.4 to +30.1 |
| claude-haiku-5-5 vs claude-sonnet-5-5-high | 1/4 = 25.0% | 43.3% | -18.3 | -51.0 to +12.8 |
| claude-haiku-5-5 vs claude-sonnet-5-5-low | 2/2 = 100.0% | 56.8% | +43.2 | +30.9 to +54.1 |
| claude-haiku-5-5 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 27.4% | -27.4 | -35.9 to -18.6 |
| claude-haiku-5-5 vs claude-sonnet-5-5-off | 1/2 = 50.0% | 47.3% | +2.7 | -8.7 to +13.1 |
| claude-haiku-5-5 vs claude-sonnet-5-5-xhigh | 1/4 = 25.0% | 36.4% | -11.4 | -41.6 to +19.3 |
| claude-haiku-5-5 vs gpt-5.6-terra | 13/20 = 65.0% | 60.2% | +4.8 | -8.7 to +20.3 |
| claude-haiku-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 62.4% | +37.6 | +26.4 to +48.0 |
| claude-haiku-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.9% | -14.9 | -24.3 to -3.4 |
| claude-haiku-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 51.6% | +48.4 | +35.1 to +59.6 |
| claude-haiku-5-5 vs gpt-6-astra | 6/20 = 30.0% | 31.9% | -1.9 | -17.6 to +12.3 |
| claude-haiku-5-5 vs gpt-6-astra-high | 0/1 = 0.0% | 37.1% | -37.1 | -56.1 to -16.8 |
| claude-haiku-5-5 vs gpt-6-astra-low | 1/2 = 50.0% | 50.4% | -0.4 | -19.7 to +16.6 |
| claude-haiku-5-5 vs gpt-6-astra-low-recall | 1/1 = 100.0% | 34.4% | +65.6 | +42.6 to +82.1 |
| claude-haiku-5-5 vs gpt-6-luna | 19/20 = 95.0% | 82.7% | +12.3 | +1.0 to +20.9 |
| claude-haiku-5-5 vs gpt-6-luna-high | 1/2 = 50.0% | 65.9% | -15.9 | -26.9 to -1.8 |
| claude-haiku-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.7% | +11.3 | +6.0 to +18.4 |
| claude-haiku-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 58.3% | -8.3 | -18.9 to +5.2 |
| claude-haiku-5-5 vs gpt-6.1-sol | 10/20 = 50.0% | 42.8% | +7.2 | -8.4 to +21.1 |
| claude-haiku-5-5 vs gpt-6.1-sol-high | 2/4 = 50.0% | 44.0% | +6.0 | -4.9 to +16.7 |
| claude-haiku-5-5 vs gpt-6.1-sol-low | 0/2 = 0.0% | 39.7% | -39.7 | -50.2 to -28.9 |
| claude-haiku-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 32.5% | +17.5 | +7.6 to +25.3 |
| claude-haiku-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 40.6% | +9.4 | -1.5 to +18.8 |
| claude-haiku-5-5 vs gpt-6.1-terra-high | 0/1 = 0.0% | 61.9% | -61.9 | -78.1 to -36.5 |
| claude-haiku-5-5 vs gpt-6.1-terra-low | 0/1 = 0.0% | 41.4% | -41.4 | -59.6 to -21.9 |
| claude-haiku-5-5 vs gpt-6.1-terra-off | 1/1 = 100.0% | 51.9% | +48.1 | +27.6 to +66.5 |
| claude-haiku-5-5 vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 45.1% | -45.1 | -67.2 to -19.4 |
| claude-haiku-5-5-high vs claude-opus-5-5 | 1/2 = 50.0% | 46.5% | +3.5 | -7.9 to +14.7 |
| claude-haiku-5-5-high vs claude-opus-5-5-off | 1/1 = 100.0% | 42.5% | +57.5 | +37.1 to +72.9 |
| claude-haiku-5-5-high vs claude-sonnet-5-5 | 2/4 = 50.0% | 55.4% | -5.4 | -60.5 to +49.6 |
| claude-haiku-5-5-high vs gpt-6-astra | 0/2 = 0.0% | 36.8% | -36.8 | -46.6 to -26.2 |
| claude-haiku-5-5-high vs gpt-6-astra-low-recall | 0/1 = 0.0% | 39.5% | -39.5 | -60.2 to -17.8 |
| claude-haiku-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 85.7% | -35.7 | -40.5 to -28.8 |
| claude-haiku-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 48.3% | -48.3 | -58.5 to -37.5 |
| claude-haiku-5-5-high vs gpt-6.1-terra | 2/2 = 100.0% | 53.8% | +46.2 | +26.0 to +57.3 |
| claude-haiku-5-5-high vs gpt-6.1-terra-max | 0/1 = 0.0% | 22.7% | -22.7 | -40.8 to -6.5 |
| claude-haiku-5-5-low vs claude-opus-5-5 | 2/2 = 100.0% | 41.3% | +58.7 | +47.5 to +67.9 |
| claude-haiku-5-5-low vs claude-sonnet-5-5 | 1/2 = 50.0% | 50.1% | -0.1 | -10.3 to +11.4 |
| claude-haiku-5-5-low vs gpt-5.6-terra | 1/2 = 50.0% | 60.4% | -10.4 | -20.3 to +0.5 |
| claude-haiku-5-5-low vs gpt-6-astra | 0/2 = 0.0% | 32.0% | -32.0 | -41.6 to -22.6 |
| claude-haiku-5-5-low vs gpt-6-astra-low-recall | 0/1 = 0.0% | 34.5% | -34.5 | -56.0 to -15.9 |
| claude-haiku-5-5-low vs gpt-6-luna | 1/2 = 50.0% | 82.8% | -32.8 | -38.7 to -24.8 |
| claude-haiku-5-5-low vs gpt-6.1-sol | 2/2 = 100.0% | 43.0% | +57.0 | +46.4 to +66.7 |
| claude-haiku-5-5-low vs gpt-6.1-terra-high | 1/1 = 100.0% | 62.1% | +37.9 | +17.0 to +59.9 |
| claude-haiku-5-5-low vs gpt-6.1-terra-low | 1/2 = 50.0% | 41.6% | +8.4 | -11.5 to +26.0 |
| claude-haiku-5-5-low vs gpt-6.1-terra-off | 1/1 = 100.0% | 52.1% | +47.9 | +27.3 to +66.7 |
| claude-haiku-5-5-low vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 45.3% | -45.3 | -67.0 to -20.8 |
| claude-haiku-5-5-max vs claude-opus-5-5 | 2/2 = 100.0% | 52.4% | +47.6 | +35.5 to +57.7 |
| claude-haiku-5-5-max vs claude-sonnet-5-5 | 1/2 = 50.0% | 61.1% | -11.1 | -21.4 to +0.4 |
| claude-haiku-5-5-max vs gpt-5.6-terra | 1/2 = 50.0% | 70.5% | -20.5 | -29.2 to -10.5 |
| claude-haiku-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 54.2% | -4.2 | -15.4 to +8.0 |
| claude-haiku-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 43.7% | +6.3 | -4.9 to +16.4 |
| claude-haiku-5-5-off vs gpt-6-astra | 0/2 = 0.0% | 19.3% | -19.3 | -26.7 to -13.0 |
| claude-haiku-5-5-off vs gpt-6-luna | 1/2 = 50.0% | 71.1% | -21.1 | -30.0 to -11.1 |
| claude-haiku-5-5-off vs gpt-6.1-sol | 0/2 = 0.0% | 27.7% | -27.7 | -36.8 to -19.5 |
| claude-haiku-5-5-off vs gpt-6.1-terra-high | 0/1 = 0.0% | 45.5% | -45.5 | -65.1 to -21.8 |
| claude-haiku-5-5-off vs gpt-6.1-terra-off | 0/1 = 0.0% | 35.6% | -35.6 | -55.1 to -16.3 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5 | 0/2 = 0.0% | 52.9% | -52.9 | -63.5 to -40.8 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-off | 0/1 = 0.0% | 48.9% | -48.9 | -65.6 to -28.9 |
| claude-haiku-5-5-xhigh vs claude-sonnet-5-5 | 1/2 = 50.0% | 61.6% | -11.6 | -21.7 to -0.5 |
| claude-haiku-5-5-xhigh vs gpt-6-astra | 0/2 = 0.0% | 43.0% | -43.0 | -53.3 to -31.8 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-high | 0/1 = 0.0% | 48.7% | -48.7 | -68.5 to -25.1 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-low-recall | 1/1 = 100.0% | 45.8% | +54.2 | +30.5 to +74.0 |
| claude-haiku-5-5-xhigh vs gpt-6-luna | 2/2 = 100.0% | 88.5% | +11.5 | +6.9 to +17.2 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-low | 0/1 = 0.0% | 53.3% | -53.3 | -71.8 to -29.4 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-max | 0/1 = 0.0% | 27.5% | -27.5 | -48.9 to -8.6 |
| claude-opus-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 58.8% | +1.2 | -17.8 to +19.9 |
| claude-opus-5-5 vs claude-sonnet-5-5-high | 2/2 = 100.0% | 52.3% | +47.7 | +34.4 to +59.9 |
| claude-opus-5-5 vs claude-sonnet-5-5-low | 2/4 = 50.0% | 65.4% | -15.4 | -70.5 to +39.6 |
| claude-opus-5-5 vs claude-sonnet-5-5-max | 2/2 = 100.0% | 35.2% | +64.8 | +53.0 to +74.0 |
| claude-opus-5-5 vs claude-sonnet-5-5-off | 1/2 = 50.0% | 56.3% | -6.3 | -17.6 to +5.1 |
| claude-opus-5-5 vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 45.1% | +54.9 | +43.1 to +64.9 |
| claude-opus-5-5 vs gpt-5.6-terra | 12/20 = 60.0% | 68.4% | -8.4 | -20.4 to +6.0 |
| claude-opus-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 70.4% | +29.6 | +19.4 to +40.9 |
| claude-opus-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 72.6% | -22.6 | -31.4 to -11.0 |
| claude-opus-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 60.5% | +39.5 | +26.8 to +51.4 |
| claude-opus-5-5 vs gpt-5.6-terra-xhigh | 2/2 = 100.0% | 60.0% | +40.0 | +27.4 to +51.3 |
| claude-opus-5-5 vs gpt-6-astra | 9/20 = 45.0% | 40.2% | +4.8 | -6.8 to +14.9 |
| claude-opus-5-5 vs gpt-6-astra-high | 1/2 = 50.0% | 45.8% | +4.2 | -17.4 to +22.9 |
| claude-opus-5-5 vs gpt-6-astra-low | 1/2 = 50.0% | 59.3% | -9.3 | -26.5 to +8.0 |
| claude-opus-5-5 vs gpt-6-astra-low-recall | 1/1 = 100.0% | 42.9% | +57.1 | +35.3 to +76.6 |
| claude-opus-5-5 vs gpt-6-luna | 16/20 = 80.0% | 87.3% | -7.3 | -29.6 to +10.6 |
| claude-opus-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 91.9% | +8.1 | +4.2 to +13.9 |
| claude-opus-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 66.8% | -16.8 | -27.4 to -3.0 |
| claude-opus-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 64.2% | -14.2 | -25.2 to -1.5 |
| claude-opus-5-5 vs gpt-6.1-sol | 12/20 = 60.0% | 51.8% | +8.2 | -10.3 to +26.4 |
| claude-opus-5-5 vs gpt-6.1-sol-high | 2/2 = 100.0% | 53.0% | +47.0 | +35.1 to +56.6 |
| claude-opus-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 48.6% | +1.4 | -10.6 to +12.2 |
| claude-opus-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 40.9% | +9.1 | -1.0 to +18.0 |
| claude-opus-5-5 vs gpt-6.1-sol-xhigh | 2/4 = 50.0% | 49.5% | +0.5 | -10.4 to +11.3 |
| claude-opus-5-5 vs gpt-6.1-terra | 1/2 = 50.0% | 57.2% | -7.2 | -22.1 to +8.9 |
| claude-opus-5-5 vs gpt-6.1-terra-low | 1/1 = 100.0% | 50.3% | +49.7 | +30.3 to +67.7 |
| claude-opus-5-5 vs gpt-6.1-terra-max | 0/1 = 0.0% | 25.2% | -25.2 | -44.0 to -7.9 |
| claude-opus-5-5-high vs claude-sonnet-5-5 | 1/2 = 50.0% | 58.9% | -8.9 | -21.1 to +5.7 |
| claude-opus-5-5-high vs gpt-6-astra | 1/2 = 50.0% | 40.2% | +9.8 | -4.2 to +21.2 |
| claude-opus-5-5-high vs gpt-6-astra-high | 0/1 = 0.0% | 45.9% | -45.9 | -67.3 to -20.0 |
| claude-opus-5-5-high vs gpt-6-astra-low-recall | 0/1 = 0.0% | 43.0% | -43.0 | -63.9 to -18.6 |
| claude-opus-5-5-high vs gpt-6-luna | 2/2 = 100.0% | 87.3% | +12.7 | +6.8 to +20.5 |
| claude-opus-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 51.8% | -51.8 | -64.2 to -36.2 |
| claude-opus-5-5-high vs gpt-6.1-terra-low | 1/1 = 100.0% | 50.4% | +49.6 | +26.7 to +70.3 |
| claude-opus-5-5-high vs gpt-6.1-terra-max | 1/1 = 100.0% | 25.3% | +74.7 | +48.4 to +89.2 |
| claude-opus-5-5-low vs claude-sonnet-5-5 | 1/2 = 50.0% | 45.6% | +4.4 | -9.8 to +18.8 |
| claude-opus-5-5-low vs gpt-5.6-terra | 0/2 = 0.0% | 56.0% | -56.0 | -67.4 to -38.1 |
| claude-opus-5-5-low vs gpt-6-astra-high | 0/1 = 0.0% | 33.2% | -33.2 | -53.5 to -13.6 |
| claude-opus-5-5-low vs gpt-6-astra-low | 0/1 = 0.0% | 46.1% | -46.1 | -65.9 to -24.5 |
| claude-opus-5-5-low vs gpt-6-astra-low-recall | 0/1 = 0.0% | 30.6% | -30.6 | -51.3 to -11.7 |
| claude-opus-5-5-low vs gpt-6-luna | 2/2 = 100.0% | 80.2% | +19.8 | +10.9 to +31.1 |
| claude-opus-5-5-low vs gpt-6.1-terra-max | 0/1 = 0.0% | 16.5% | -16.5 | -34.4 to -4.5 |
| claude-opus-5-5-low vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 40.9% | +59.1 | +30.7 to +79.9 |
| claude-opus-5-5-max vs claude-sonnet-5-5 | 2/2 = 100.0% | 66.9% | +33.1 | +18.0 to +48.2 |
| claude-opus-5-5-max vs gpt-6-astra | 1/2 = 50.0% | 48.7% | +1.3 | -14.7 to +16.7 |
| claude-opus-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 60.3% | -10.3 | -25.3 to +6.6 |
| claude-opus-5-5-max vs gpt-6.1-terra | 1/2 = 50.0% | 65.4% | -15.4 | -31.7 to +4.9 |
| claude-opus-5-5-off vs claude-sonnet-5-5-high | 1/1 = 100.0% | 56.3% | +43.7 | +23.9 to +61.6 |
| claude-opus-5-5-off vs claude-sonnet-5-5-off | 2/2 = 100.0% | 60.2% | +39.8 | +21.8 to +54.9 |
| claude-opus-5-5-off vs claude-sonnet-5-5-xhigh | 0/1 = 0.0% | 49.2% | -49.2 | -66.7 to -29.1 |
| claude-opus-5-5-off vs gpt-6-astra-high | 1/1 = 100.0% | 49.9% | +50.1 | +25.5 to +72.8 |
| claude-opus-5-5-off vs gpt-6-astra-low | 1/1 = 100.0% | 63.2% | +36.8 | +14.2 to +56.5 |
| claude-opus-5-5-off vs gpt-6-astra-low-recall | 0/1 = 0.0% | 46.9% | -46.9 | -68.3 to -20.3 |
| claude-opus-5-5-off vs gpt-6-luna-xhigh | 1/2 = 50.0% | 67.9% | -17.9 | -32.9 to +0.3 |
| claude-opus-5-5-off vs gpt-6.1-terra | 1/1 = 100.0% | 61.2% | +38.8 | +18.8 to +59.0 |
| claude-opus-5-5-off vs gpt-6.1-terra-low | 1/1 = 100.0% | 54.4% | +45.6 | +21.3 to +66.3 |
| claude-opus-5-5-off vs gpt-6.1-terra-max | 0/1 = 0.0% | 28.4% | -28.4 | -50.6 to -8.4 |
| claude-opus-5-5-off vs gpt-6.1-terra-off | 1/1 = 100.0% | 64.5% | +35.5 | +15.8 to +58.9 |
| claude-opus-5-5-off vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 58.1% | -58.1 | -78.9 to -28.1 |
| claude-opus-5-5-xhigh vs claude-sonnet-5-5-max | 2/10 = 20.0% | 45.1% | -25.1 | -51.0 to -0.7 |
| claude-opus-5-5-xhigh vs gpt-6-astra | 22/41 = 53.7% | 50.4% | +3.2 | -7.0 to +14.1 |
| claude-opus-5-5-xhigh vs gpt-6.1-sol-max | 4/10 = 40.0% | 51.2% | -11.2 | -33.8 to +5.2 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-max | 1/1 = 100.0% | 33.8% | +66.2 | +41.8 to +84.1 |
| claude-sonnet-5-5 vs gpt-5.6-terra | 11/20 = 55.0% | 60.3% | -5.3 | -30.8 to +17.4 |
| claude-sonnet-5-5 vs gpt-5.6-terra-high | 1/2 = 50.0% | 62.5% | -12.5 | -24.3 to -0.8 |
| claude-sonnet-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 65.0% | -15.0 | -25.6 to -3.1 |
| claude-sonnet-5-5 vs gpt-5.6-terra-xhigh | 0/2 = 0.0% | 51.2% | -51.2 | -62.1 to -37.7 |
| claude-sonnet-5-5 vs gpt-6-astra | 7/20 = 35.0% | 32.0% | +3.0 | -11.7 to +16.9 |
| claude-sonnet-5-5 vs gpt-6-astra-high | 2/2 = 100.0% | 37.2% | +62.8 | +38.7 to +76.2 |
| claude-sonnet-5-5 vs gpt-6-astra-low | 0/2 = 0.0% | 50.5% | -50.5 | -66.8 to -30.7 |
| claude-sonnet-5-5 vs gpt-6-astra-low-recall | 0/1 = 0.0% | 34.5% | -34.5 | -54.8 to -15.1 |
| claude-sonnet-5-5 vs gpt-6-luna | 17/20 = 85.0% | 82.8% | +2.2 | -13.3 to +15.7 |
| claude-sonnet-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.8% | +11.2 | +6.0 to +18.4 |
| claude-sonnet-5-5 vs gpt-6-luna-off | 2/2 = 100.0% | 88.5% | +11.5 | +6.2 to +18.1 |
| claude-sonnet-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 55.7% | -5.7 | -17.8 to +7.4 |
| claude-sonnet-5-5 vs gpt-6.1-sol | 8/20 = 40.0% | 42.9% | -2.9 | -22.3 to +14.9 |
| claude-sonnet-5-5 vs gpt-6.1-sol-high | 1/2 = 50.0% | 44.1% | +5.9 | -5.4 to +17.1 |
| claude-sonnet-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 39.8% | +10.2 | -2.0 to +21.6 |
| claude-sonnet-5-5 vs gpt-6.1-sol-max | 0/2 = 0.0% | 32.6% | -32.6 | -41.8 to -23.8 |
| claude-sonnet-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 40.7% | +9.3 | -2.7 to +19.2 |
| claude-sonnet-5-5 vs gpt-6.1-terra-high | 0/1 = 0.0% | 62.0% | -62.0 | -78.6 to -36.4 |
| claude-sonnet-5-5 vs gpt-6.1-terra-low | 0/1 = 0.0% | 41.5% | -41.5 | -59.1 to -22.4 |
| claude-sonnet-5-5 vs gpt-6.1-terra-max | 0/1 = 0.0% | 19.1% | -19.1 | -35.7 to -5.5 |
| claude-sonnet-5-5 vs gpt-6.1-terra-off | 1/1 = 100.0% | 52.0% | +48.0 | +25.7 to +66.8 |
| claude-sonnet-5-5 vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 45.2% | +54.8 | +28.6 to +74.9 |
| claude-sonnet-5-5-high vs gpt-5.6-terra | 1/2 = 50.0% | 66.4% | -16.4 | -26.8 to -4.1 |
| claude-sonnet-5-5-high vs gpt-6-astra | 2/2 = 100.0% | 38.0% | +62.0 | +49.3 to +71.8 |
| claude-sonnet-5-5-high vs gpt-6-astra-high | 1/1 = 100.0% | 43.5% | +56.5 | +32.0 to +76.9 |
| claude-sonnet-5-5-high vs gpt-6-astra-low-recall | 0/1 = 0.0% | 40.7% | -40.7 | -60.9 to -16.5 |
| claude-sonnet-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 86.3% | -36.3 | -41.5 to -28.2 |
| claude-sonnet-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 49.5% | -49.5 | -60.1 to -35.8 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-high | 2/2 = 100.0% | 68.0% | +32.0 | +13.6 to +49.7 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-low | 0/1 = 0.0% | 48.1% | -48.1 | -66.5 to -26.9 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-max | 0/1 = 0.0% | 23.5% | -23.5 | -44.4 to -6.9 |
| claude-sonnet-5-5-low vs gpt-6-astra | 0/2 = 0.0% | 26.2% | -26.2 | -35.8 to -17.0 |
| claude-sonnet-5-5-low vs gpt-6-astra-low-recall | 0/1 = 0.0% | 28.5% | -28.5 | -49.4 to -11.5 |
| claude-sonnet-5-5-low vs gpt-6-luna | 1/2 = 50.0% | 78.5% | -28.5 | -36.3 to -17.3 |
| claude-sonnet-5-5-low vs gpt-6.1-sol | 1/2 = 50.0% | 36.2% | +13.8 | +2.9 to +23.9 |
| claude-sonnet-5-5-low vs gpt-6.1-terra | 1/2 = 50.0% | 41.5% | +8.5 | -10.1 to +23.7 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-high | 1/1 = 100.0% | 55.3% | +44.7 | +23.0 to +66.6 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-off | 0/2 = 0.0% | 45.0% | -45.0 | -61.4 to -20.5 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 38.4% | +61.6 | +32.6 to +80.4 |
| claude-sonnet-5-5-max vs gpt-6-astra | 4/10 = 40.0% | 55.3% | -15.3 | -42.2 to +1.8 |
| claude-sonnet-5-5-max vs gpt-6-luna | 2/2 = 100.0% | 92.7% | +7.3 | +4.2 to +11.3 |
| claude-sonnet-5-5-max vs gpt-6.1-sol | 2/2 = 100.0% | 66.4% | +33.6 | +23.7 to +43.3 |
| claude-sonnet-5-5-max vs gpt-6.1-sol-max | 6/10 = 60.0% | 56.1% | +3.9 | -13.6 to +27.9 |
| claude-sonnet-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 62.7% | -12.7 | -22.8 to +0.0 |
| claude-sonnet-5-5-off vs gpt-6-astra | 2/2 = 100.0% | 34.3% | +65.7 | +54.0 to +74.4 |
| claude-sonnet-5-5-off vs gpt-6-astra-low-recall | 1/1 = 100.0% | 36.9% | +63.1 | +37.7 to +80.9 |
| claude-sonnet-5-5-off vs gpt-6-luna | 2/2 = 100.0% | 84.2% | +15.8 | +9.7 to +24.0 |
| claude-sonnet-5-5-off vs gpt-6.1-sol | 1/2 = 50.0% | 45.5% | +4.5 | -6.6 to +15.9 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-low | 0/1 = 0.0% | 44.1% | -44.1 | -63.2 to -23.1 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 47.8% | +52.2 | +26.8 to +73.3 |
| claude-sonnet-5-5-xhigh vs gpt-5.6-terra | 2/2 = 100.0% | 72.5% | +27.5 | +18.7 to +36.5 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra | 1/2 = 50.0% | 44.9% | +5.1 | -6.2 to +15.5 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-high | 0/1 = 0.0% | 50.7% | -50.7 | -70.2 to -24.6 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-low | 1/1 = 100.0% | 63.9% | +36.1 | +17.7 to +53.5 |
| claude-sonnet-5-5-xhigh vs gpt-6-luna | 2/2 = 100.0% | 89.3% | +10.7 | +6.4 to +15.7 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 56.6% | -6.6 | -17.3 to +4.2 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-max | 0/1 = 0.0% | 29.1% | -29.1 | -50.4 to -8.7 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 58.9% | -8.9 | -27.3 to +14.9 |
| gpt-5.6-terra vs gpt-6-astra | 5/20 = 25.0% | 23.6% | +1.4 | -14.1 to +16.7 |
| gpt-5.6-terra vs gpt-6-astra-low-recall | 0/1 = 0.0% | 25.7% | -25.7 | -43.7 to -9.8 |
| gpt-5.6-terra vs gpt-6-luna | 15/20 = 75.0% | 76.0% | -1.0 | -22.5 to +17.1 |
| gpt-5.6-terra vs gpt-6-luna-high | 2/2 = 100.0% | 56.2% | +43.8 | +29.1 to +57.5 |
| gpt-5.6-terra vs gpt-6-luna-low | 1/2 = 50.0% | 83.9% | -33.9 | -40.8 to -22.7 |
| gpt-5.6-terra vs gpt-6-luna-max | 2/2 = 100.0% | 48.1% | +51.9 | +37.8 to +64.0 |
| gpt-5.6-terra vs gpt-6-luna-off | 2/2 = 100.0% | 83.5% | +16.5 | +9.3 to +25.6 |
| gpt-5.6-terra vs gpt-6.1-sol | 6/20 = 30.0% | 33.1% | -3.1 | -19.7 to +12.4 |
| gpt-5.6-terra vs gpt-6.1-sol-high | 0/2 = 0.0% | 34.2% | -34.2 | -44.1 to -23.9 |
| gpt-5.6-terra vs gpt-6.1-sol-low | 0/2 = 0.0% | 30.3% | -30.3 | -39.8 to -20.6 |
| gpt-5.6-terra vs gpt-6.1-sol-max | 0/2 = 0.0% | 24.2% | -24.2 | -31.5 to -16.7 |
| gpt-5.6-terra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 31.2% | -31.2 | -40.6 to -21.6 |
| gpt-5.6-terra vs gpt-6.1-terra-off | 0/1 = 0.0% | 41.6% | -41.6 | -61.4 to -19.9 |
| gpt-5.6-terra vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 35.2% | -35.2 | -57.0 to -14.8 |
| gpt-5.6-terra-high vs gpt-6-astra-low-recall | 0/1 = 0.0% | 24.0% | -24.0 | -43.2 to -9.1 |
| gpt-5.6-terra-high vs gpt-6-luna | 1/2 = 50.0% | 74.3% | -24.3 | -33.4 to -11.8 |
| gpt-5.6-terra-high vs gpt-6.1-sol | 1/2 = 50.0% | 31.1% | +18.9 | +7.0 to +28.9 |
| gpt-5.6-terra-low vs gpt-6-astra | 0/2 = 0.0% | 20.2% | -20.2 | -28.8 to -12.8 |
| gpt-5.6-terra-low vs gpt-6.1-terra-high | 0/1 = 0.0% | 46.8% | -46.8 | -66.7 to -21.5 |
| gpt-5.6-terra-max vs gpt-6-astra | 1/2 = 50.0% | 30.5% | +19.5 | +6.3 to +29.4 |
| gpt-5.6-terra-max vs gpt-6-luna | 2/2 = 100.0% | 81.8% | +18.2 | +10.1 to +28.4 |
| gpt-5.6-terra-xhigh vs gpt-6-astra | 0/2 = 0.0% | 30.9% | -30.9 | -41.7 to -21.2 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-high | 1/1 = 100.0% | 36.1% | +63.9 | +37.8 to +81.1 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-low | 1/1 = 100.0% | 49.3% | +50.7 | +26.7 to +68.1 |
| gpt-5.6-terra-xhigh vs gpt-6.1-sol | 0/2 = 0.0% | 41.7% | -41.7 | -53.1 to -30.4 |
| gpt-5.6-terra-xhigh vs gpt-6.1-terra-low | 0/1 = 0.0% | 40.4% | -40.4 | -60.2 to -19.6 |
| gpt-6-astra vs gpt-6-luna | 19/20 = 95.0% | 91.1% | +3.9 | -7.5 to +10.9 |
| gpt-6-astra vs gpt-6-luna-high | 1/2 = 50.0% | 80.5% | -30.5 | -38.2 to -19.6 |
| gpt-6-astra vs gpt-6-luna-max | 2/2 = 100.0% | 75.0% | +25.0 | +15.6 to +35.8 |
| gpt-6-astra vs gpt-6-luna-off | 2/2 = 100.0% | 94.2% | +5.8 | +3.1 to +9.4 |
| gpt-6-astra vs gpt-6-luna-xhigh | 1/2 = 50.0% | 72.8% | -22.8 | -31.8 to -10.6 |
| gpt-6-astra vs gpt-6.1-sol | 12/20 = 60.0% | 61.5% | -1.5 | -19.9 to +16.2 |
| gpt-6-astra vs gpt-6.1-sol-high | 1/2 = 50.0% | 62.7% | -12.7 | -21.8 to -1.5 |
| gpt-6-astra vs gpt-6.1-sol-low | 3/4 = 75.0% | 58.5% | +16.5 | -14.6 to +47.8 |
| gpt-6-astra vs gpt-6.1-sol-max | 6/10 = 60.0% | 50.8% | +9.2 | -6.5 to +31.6 |
| gpt-6-astra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 59.4% | -59.4 | -68.3 to -48.1 |
| gpt-6-astra vs gpt-6.1-terra-max | 0/1 = 0.0% | 33.4% | -33.4 | -53.6 to -9.9 |
| gpt-6-astra-high vs gpt-6.1-sol | 1/2 = 50.0% | 55.9% | -5.9 | -24.9 to +14.3 |
| gpt-6-astra-high vs gpt-6.1-sol-high | 1/1 = 100.0% | 57.2% | +42.8 | +20.6 to +62.7 |
| gpt-6-astra-high vs gpt-6.1-terra-low | 1/1 = 100.0% | 54.5% | +45.5 | +18.1 to +68.8 |
| gpt-6-astra-high vs gpt-6.1-terra-max | 0/1 = 0.0% | 28.5% | -28.5 | -55.6 to -8.0 |
| gpt-6-astra-low vs gpt-6-luna | 2/2 = 100.0% | 82.5% | +17.5 | +8.3 to +32.4 |
| gpt-6-astra-low vs gpt-6.1-sol | 1/2 = 50.0% | 42.4% | +7.6 | -10.0 to +25.3 |
| gpt-6-astra-low vs gpt-6.1-sol-low | 0/1 = 0.0% | 39.3% | -39.3 | -56.4 to -18.5 |
| gpt-6-astra-low vs gpt-6.1-terra-max | 0/1 = 0.0% | 18.8% | -18.8 | -38.9 to -4.4 |
| gpt-6-astra-low-recall vs gpt-6-luna-xhigh | 1/1 = 100.0% | 70.5% | +29.5 | +11.9 to +49.4 |
| gpt-6-astra-low-recall vs gpt-6.1-sol | 0/1 = 0.0% | 58.8% | -58.8 | -78.6 to -35.6 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-low | 1/1 = 100.0% | 57.4% | +42.6 | +16.5 to +67.3 |
| gpt-6-astra-low-recall vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 61.1% | -61.1 | -82.4 to -26.9 |
| gpt-6-luna vs gpt-6.1-sol | 3/20 = 15.0% | 13.5% | +1.5 | -12.5 to +16.8 |
| gpt-6-luna vs gpt-6.1-sol-high | 1/2 = 50.0% | 14.1% | +35.9 | +28.3 to +40.8 |
| gpt-6-luna vs gpt-6.1-sol-low | 0/2 = 0.0% | 12.1% | -12.1 | -18.5 to -7.0 |
| gpt-6-luna vs gpt-6.1-sol-max | 0/2 = 0.0% | 9.1% | -9.1 | -13.7 to -5.7 |
| gpt-6-luna vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 12.5% | -12.5 | -18.9 to -7.5 |
| gpt-6-luna-high vs gpt-6.1-sol | 1/2 = 50.0% | 27.9% | +22.1 | +8.9 to +32.4 |
| gpt-6-luna-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 45.6% | +54.4 | +28.4 to +74.9 |
| gpt-6-luna-high vs gpt-6.1-terra-off | 0/1 = 0.0% | 35.8% | -35.8 | -56.3 to -15.0 |
| gpt-6-luna-low vs gpt-6.1-sol | 0/2 = 0.0% | 8.7% | -8.7 | -14.2 to -4.4 |
| gpt-6-luna-max vs gpt-6.1-sol | 0/2 = 0.0% | 34.8% | -34.8 | -46.6 to -23.4 |
| gpt-6-luna-max vs gpt-6.1-terra-off | 1/2 = 50.0% | 43.5% | +6.5 | -13.3 to +25.7 |
| gpt-6-luna-off vs gpt-6.1-sol | 1/2 = 50.0% | 8.9% | +41.1 | +35.1 to +45.0 |
| gpt-6-luna-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 37.4% | +12.6 | -0.2 to +23.8 |
| gpt-6-luna-xhigh vs gpt-6.1-terra-low | 1/2 = 50.0% | 36.1% | +13.9 | -7.3 to +30.3 |
| gpt-6.1-sol vs gpt-6.1-terra | 1/2 = 50.0% | 55.5% | -5.5 | -20.7 to +10.4 |
| gpt-6.1-sol vs gpt-6.1-terra-low | 1/1 = 100.0% | 48.6% | +51.4 | +30.3 to +68.8 |
| gpt-6.1-sol vs gpt-6.1-terra-max | 1/1 = 100.0% | 23.9% | +76.1 | +54.9 to +89.6 |
| gpt-6.1-sol-high vs gpt-6.1-terra | 1/2 = 50.0% | 54.3% | -4.3 | -20.2 to +13.0 |
| gpt-6.1-sol-low vs gpt-6.1-terra-max | 1/1 = 100.0% | 26.3% | +73.7 | +50.0 to +88.0 |
| gpt-6.1-sol-max vs gpt-6.1-terra-max | 1/2 = 50.0% | 32.8% | +17.2 | -4.7 to +35.7 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-high | 1/2 = 50.0% | 70.4% | -20.4 | -35.2 to +1.9 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-max | 0/1 = 0.0% | 25.6% | -25.6 | -45.5 to -8.1 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 54.6% | -4.6 | -26.3 to +19.5 |
#### Haiku 4.5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-high | 9/20 = 45.0% | 59.9% | -14.9 | -32.3 to +0.6 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-low | 12/20 = 60.0% | 56.7% | +3.3 | -13.9 to +22.9 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-minimal | 10/20 = 50.0% | 53.5% | -3.5 | -21.6 to +14.3 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 72.9% | +7.1 | -8.2 to +22.8 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-low | 8/20 = 40.0% | 46.7% | -6.7 | -23.8 to +10.3 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal | 11/20 = 55.0% | 43.5% | +11.5 | -7.2 to +31.9 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 64.2% | +0.8 | -17.0 to +18.9 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-minimal | 6/20 = 30.0% | 46.8% | -16.8 | -36.4 to +1.9 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-off | 15/20 = 75.0% | 67.2% | +7.8 | -6.3 to +23.6 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 70.0% | -5.0 | -25.9 to +13.8 |
#### Haiku 5.5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-5-5 vs claude-haiku-5-5-high | 7/20 = 35.0% | 44.5% | -9.5 | -25.7 to +4.7 |
| claude-haiku-5-5 vs claude-haiku-5-5-low | 8/20 = 40.0% | 49.8% | -9.8 | -28.0 to +6.4 |
| claude-haiku-5-5 vs claude-haiku-5-5-max | 9/20 = 45.0% | 38.8% | +6.2 | -10.5 to +22.1 |
| claude-haiku-5-5 vs claude-haiku-5-5-off | 14/20 = 70.0% | 66.1% | +3.9 | -11.0 to +20.2 |
| claude-haiku-5-5 vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 38.3% | -3.3 | -21.1 to +16.8 |
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 55.3% | +9.7 | -8.3 to +29.3 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 44.1% | +0.9 | -17.7 to +20.6 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 70.9% | -5.9 | -20.2 to +8.3 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 43.6% | -13.6 | -29.3 to +0.7 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 38.9% | -3.9 | -22.1 to +14.3 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 66.3% | -11.3 | -32.5 to +8.0 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 38.4% | +1.6 | -13.3 to +14.0 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 75.5% | +4.5 | -9.7 to +19.4 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 49.5% | -4.5 | -20.3 to +10.7 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 24.1% | +0.9 | -17.4 to +18.9 |
#### Luna efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-luna vs gpt-6-luna-high | 8/20 = 40.0% | 28.8% | +11.2 | -8.5 to +36.1 |
| gpt-6-luna vs gpt-6-luna-low | 12/20 = 60.0% | 62.2% | -2.2 | -25.8 to +18.7 |
| gpt-6-luna vs gpt-6-luna-max | 5/20 = 25.0% | 22.6% | +2.4 | -12.5 to +18.1 |
| gpt-6-luna vs gpt-6-luna-off | 12/20 = 60.0% | 61.5% | -1.5 | -22.7 to +18.2 |
| gpt-6-luna vs gpt-6-luna-xhigh | 2/20 = 10.0% | 20.7% | -10.7 | -23.2 to +2.8 |
| gpt-6-luna-high vs gpt-6-luna-low | 14/20 = 70.0% | 80.3% | -10.3 | -24.4 to +4.6 |
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 42.0% | -7.0 | -29.2 to +13.2 |
| gpt-6-luna-high vs gpt-6-luna-off | 18/20 = 90.0% | 79.8% | +10.2 | -2.5 to +23.2 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 39.2% | +15.8 | -1.8 to +35.6 |
| gpt-6-luna-low vs gpt-6-luna-max | 2/20 = 10.0% | 15.1% | -5.1 | -17.0 to +8.5 |
| gpt-6-luna-low vs gpt-6-luna-off | 8/20 = 40.0% | 49.3% | -9.3 | -27.2 to +7.6 |
| gpt-6-luna-low vs gpt-6-luna-xhigh | 3/20 = 15.0% | 13.7% | +1.3 | -13.6 to +20.7 |
| gpt-6-luna-max vs gpt-6-luna-off | 16/20 = 80.0% | 84.5% | -4.5 | -18.7 to +9.1 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 47.2% | +2.8 | -11.8 to +17.6 |
| gpt-6-luna-off vs gpt-6-luna-xhigh | 2/20 = 10.0% | 14.0% | -4.0 | -15.4 to +10.0 |
#### Opus efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5 vs claude-opus-5-5-high | 9/20 = 45.0% | 49.9% | -4.9 | -23.6 to +13.1 |
| claude-opus-5-5 vs claude-opus-5-5-low | 13/20 = 65.0% | 63.0% | +2.0 | -11.8 to +15.6 |
| claude-opus-5-5 vs claude-opus-5-5-max | 4/10 = 40.0% | 41.4% | -1.4 | -33.0 to +33.4 |
| claude-opus-5-5 vs claude-opus-5-5-off | 1/2 = 50.0% | 45.9% | +4.1 | -12.1 to +20.7 |
| claude-opus-5-5 vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 39.8% | -4.8 | -20.9 to +9.2 |
| claude-opus-5-5-high vs claude-opus-5-5-off | 1/3 = 33.3% | 46.0% | -12.7 | -58.5 to +15.7 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 39.8% | -4.8 | -21.2 to +11.9 |
| claude-opus-5-5-low vs claude-opus-5-5-max | 3/10 = 30.0% | 29.4% | +0.6 | -27.7 to +32.1 |
| claude-opus-5-5-low vs claude-opus-5-5-off | 2/3 = 66.7% | 33.3% | +33.4 | +7.9 to +77.9 |
| claude-opus-5-5-max vs claude-opus-5-5-xhigh | 5/10 = 50.0% | 48.2% | +1.8 | -26.8 to +29.3 |
#### Sol efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-sol vs gpt-6.1-sol-high | 12/20 = 60.0% | 51.2% | +8.8 | -3.7 to +22.6 |
| gpt-6.1-sol vs gpt-6.1-sol-low | 7/20 = 35.0% | 46.8% | -11.8 | -30.1 to +7.4 |
| gpt-6.1-sol vs gpt-6.1-sol-max | 8/20 = 40.0% | 39.2% | +0.8 | -17.7 to +19.3 |
| gpt-6.1-sol vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 47.8% | +2.2 | -17.0 to +24.6 |
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 45.6% | +14.4 | -1.2 to +32.3 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 38.0% | +7.0 | -10.9 to +26.4 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 46.5% | -1.5 | -17.7 to +13.4 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 42.3% | -12.3 | -30.1 to +5.6 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 51.0% | +9.0 | -6.9 to +25.9 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 58.7% | -8.7 | -23.6 to +4.6 |
#### Sonnet efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-sonnet-5-5 vs claude-sonnet-5-5-high | 7/20 = 35.0% | 43.4% | -8.4 | -27.6 to +11.5 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-low | 11/20 = 55.0% | 56.9% | -1.9 | -22.9 to +18.0 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-max | 8/20 = 40.0% | 27.5% | +12.5 | -5.2 to +31.5 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-off | 10/20 = 50.0% | 47.4% | +2.6 | -14.9 to +21.7 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 36.5% | +8.5 | -10.7 to +29.5 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 63.3% | -8.3 | -32.3 to +13.5 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 33.1% | +6.9 | -13.2 to +28.0 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 54.0% | +16.0 | +0.8 to +34.0 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 42.9% | -17.9 | -36.6 to +0.4 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 22.3% | -7.3 | -22.0 to +6.9 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 40.5% | +9.5 | -6.8 to +29.0 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 30.3% | -10.3 | -26.0 to +4.7 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 70.4% | -0.4 | -22.5 to +19.6 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 60.3% | +4.7 | -13.3 to +23.1 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 39.0% | +16.0 | +4.9 to +29.4 |
#### Terra 6.1 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-terra vs gpt-6.1-terra-high | 1/2 = 50.0% | 63.6% | -13.6 | -31.1 to +11.2 |
| gpt-6.1-terra vs gpt-6.1-terra-low | 1/2 = 50.0% | 43.1% | +6.9 | -13.5 to +25.0 |
| gpt-6.1-terra vs gpt-6.1-terra-off | 1/2 = 50.0% | 53.6% | -3.6 | -24.0 to +19.0 |
| gpt-6.1-terra vs gpt-6.1-terra-xhigh | 2/2 = 100.0% | 46.8% | +53.2 | +22.9 to +71.1 |
| gpt-6.1-terra-high vs gpt-6.1-terra-off | 0/1 = 0.0% | 39.9% | -39.9 | -64.7 to -14.1 |
| gpt-6.1-terra-high vs gpt-6.1-terra-xhigh | 0/2 = 0.0% | 33.6% | -33.6 | -55.9 to -11.2 |
| gpt-6.1-terra-low vs gpt-6.1-terra-off | 2/2 = 100.0% | 60.4% | +39.6 | +16.0 to +58.6 |
| gpt-6.1-terra-max vs gpt-6.1-terra-xhigh | 2/2 = 100.0% | 77.8% | +22.2 | +5.2 to +43.2 |
| gpt-6.1-terra-off vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 43.2% | -43.2 | -68.4 to -16.7 |
#### Terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-5.6-terra vs gpt-5.6-terra-high | 10/20 = 50.0% | 52.3% | -2.3 | -17.7 to +11.6 |
| gpt-5.6-terra vs gpt-5.6-terra-low | 11/20 = 55.0% | 55.0% | -0.0 | -16.7 to +15.7 |
| gpt-5.6-terra vs gpt-5.6-terra-max | 8/20 = 40.0% | 41.3% | -1.3 | -20.6 to +19.4 |
| gpt-5.6-terra vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 40.8% | -5.8 | -20.7 to +8.3 |
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 52.7% | -7.7 | -26.3 to +9.6 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.1% | +0.9 | -15.8 to +17.9 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 38.6% | +11.4 | -8.2 to +33.2 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 36.6% | +3.4 | -15.2 to +23.7 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 36.1% | -16.1 | -31.4 to -1.3 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 49.5% | +5.5 | -9.2 to +21.8 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| Astra efforts | - | - | - | - | - | - | 4 seed blocks, under the minimum of 10: the fit with seat and starter terms can be singular on so few, so not tested |
| Cross-model | 0.6191 | 0.6192 | -0.0001 | -0.0001 to -0.0000 | 0: 48, 0.1: 1, 0.2: 1 | tau=0.1: 0.6193, tau=0.2: 0.6199, tau=0.4: 0.6223, tau=0.8: 0.6287, tau=1.6: 0.6392 | not kept |
| Cross-model (seat and starter terms) | 0.6069 | 0.6070 | -0.0001 | -0.0001 to -0.0000 | 0: 46, 0.1: 3, 0.2: 1 | tau=0.1: 0.6071, tau=0.2: 0.6077, tau=0.4: 0.6100, tau=0.8: 0.6165, tau=1.6: 0.6275 | not kept |
| Haiku 4.5 efforts | 0.6684 | 0.6722 | -0.0038 | -0.0091 to +0.0013 | 0: 20, 0.1: 3, 0.2: 12, 0.4: 15 | tau=0.1: 0.6682, tau=0.2: 0.6679, tau=0.4: 0.6689, tau=0.8: 0.6741, tau=1.6: 0.6796 | not kept |
| Haiku 4.5 efforts (seat and starter terms) | 0.6708 | 0.6729 | -0.0021 | -0.0058 to +0.0011 | 0: 22, 0.1: 7, 0.2: 12, 0.4: 9 | tau=0.1: 0.6706, tau=0.2: 0.6703, tau=0.4: 0.6712, tau=0.8: 0.6764, tau=1.6: 0.6822 | not kept |
| Haiku 5.5 efforts | 0.6618 | 0.6635 | -0.0018 | -0.0029 to -0.0007 | 0: 42, 0.1: 1, 0.2: 3, 0.4: 4 | tau=0.1: 0.6621, tau=0.2: 0.6632, tau=0.4: 0.6671, tau=0.8: 0.6749, tau=1.6: 0.6812 | not kept |
| Haiku 5.5 efforts (seat and starter terms) | 0.6379 | 0.6386 | -0.0007 | -0.0013 to -0.0001 | 0: 42, 0.1: 3, 0.2: 4, 0.4: 1 | tau=0.1: 0.6384, tau=0.2: 0.6398, tau=0.4: 0.6446, tau=0.8: 0.6541, tau=1.6: 0.6619 | not kept |
| Luna efforts | 0.5743 | 0.5762 | -0.0019 | -0.0042 to +0.0003 | 0: 29, 0.1: 4, 0.2: 10, 0.4: 7 | tau=0.1: 0.5743, tau=0.2: 0.5745, tau=0.4: 0.5766, tau=0.8: 0.5839, tau=1.6: 0.5929 | not kept |
| Luna efforts (seat and starter terms) | 0.5791 | 0.5832 | -0.0041 | -0.0078 to -0.0011 | 0: 32, 0.1: 3, 0.2: 8, 0.4: 6, 0.8: 1 | tau=0.1: 0.5792, tau=0.2: 0.5795, tau=0.4: 0.5818, tau=0.8: 0.5898, tau=1.6: 0.6004 | not kept |
| Opus efforts | 0.7021 | 0.7036 | -0.0015 | -0.0035 to +0.0000 | 0: 46, 0.1: 1, 0.2: 1, 0.4: 1, 0.8: 1 | tau=0.1: 0.7028, tau=0.2: 0.7049, tau=0.4: 0.7111, tau=0.8: 0.7232, tau=1.6: 0.7374 | not kept |
| Opus efforts (seat and starter terms) | 0.7148 | 0.7150 | -0.0002 | -0.0005 to -0.0000 | 0: 49, 0.2: 1 | tau=0.1: 0.7157, tau=0.2: 0.7181, tau=0.4: 0.7253, tau=0.8: 0.7390, tau=1.6: 0.7550 | not kept |
| Sol efforts | 0.7061 | 0.7098 | -0.0037 | -0.0097 to +0.0021 | 0: 15, 0.1: 4, 0.2: 16, 0.4: 13, 0.8: 2 | tau=0.1: 0.7059, tau=0.2: 0.7056, tau=0.4: 0.7068, tau=0.8: 0.7126, tau=1.6: 0.7185 | not kept |
| Sol efforts (seat and starter terms) | 0.7089 | 0.7162 | -0.0073 | -0.0167 to +0.0007 | 0: 25, 0.1: 1, 0.2: 9, 0.4: 11, 0.8: 4 | tau=0.1: 0.7086, tau=0.2: 0.7083, tau=0.4: 0.7093, tau=0.8: 0.7143, tau=1.6: 0.7194 | not kept |
| Sonnet efforts | 0.6709 | 0.6753 | -0.0044 | -0.0102 to +0.0007 | 0: 11, 0.1: 3, 0.2: 17, 0.4: 18, 0.8: 1 | tau=0.1: 0.6706, tau=0.2: 0.6703, tau=0.4: 0.6717, tau=0.8: 0.6792, tau=1.6: 0.6874 | not kept |
| Sonnet efforts (seat and starter terms) | 0.6701 | 0.6724 | -0.0023 | -0.0079 to +0.0027 | 0: 12, 0.1: 4, 0.2: 15, 0.4: 18, 0.8: 1 | tau=0.1: 0.6697, tau=0.2: 0.6689, tau=0.4: 0.6693, tau=0.8: 0.6753, tau=1.6: 0.6828 | not kept |
| Terra 6.1 efforts | - | - | - | - | - | - | 9 seed blocks, under the minimum of 10: the fit with seat and starter terms can be singular on so few, so not tested |
| Terra efforts | 0.6923 | 0.6974 | -0.0051 | -0.0096 to -0.0015 | 0: 37, 0.1: 1, 0.2: 4, 0.4: 6, 0.8: 2 | tau=0.1: 0.6926, tau=0.2: 0.6936, tau=0.4: 0.6972, tau=0.8: 0.7045, tau=1.6: 0.7105 | not kept |
| Terra efforts (seat and starter terms) | 0.6977 | 0.7016 | -0.0039 | -0.0073 to -0.0012 | 0: 38, 0.1: 1, 0.2: 7, 0.4: 3, 0.8: 1 | tau=0.1: 0.6980, tau=0.2: 0.6990, tau=0.4: 0.7027, tau=0.8: 0.7104, tau=1.6: 0.7170 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| Cross-model | 110/231 = 47.6% | -0.23 |
| Haiku 4.5 efforts | 7/10 = 70.0% | +0.05 |
| Haiku 5.5 efforts | 5/15 = 33.3% | -0.44 |
| Luna efforts | 7/15 = 46.7% | -0.09 |
| Opus efforts | 2/10 = 20.0% | -0.79 |
| Sol efforts | 6/10 = 60.0% | -0.18 |
| Sonnet efforts | 6/15 = 40.0% | -0.04 |
| Terra efforts | 4/10 = 40.0% | -0.15 |
| all cohorts pooled | 147/316 = 46.5% | -0.24 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 5.6e-17, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 2895 of 2895 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 1392 blocks, 128 seeds (111 matches in half blocks left out) | 1392/2784 = 50.0% | 43.5% to 56.3% | 48.2% to 51.8% |
| Astra efforts: 2 blocks, 1 seeds (2 matches in half blocks left out) | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% |
| Cross-model: 575 blocks, 118 seeds (105 matches in half blocks left out) | 544/1150 = 47.3% | 40.6% to 54.6% | 44.3% to 50.1% |
| Haiku 4.5 efforts: 100 blocks, 10 seeds | 105/200 = 52.5% | 42.5% to 60.5% | 45.5% to 60.0% |
| Haiku 5.5 efforts: 150 blocks, 10 seeds | 142/300 = 47.3% | 34.7% to 59.7% | 41.3% to 53.3% |
| Luna efforts: 150 blocks, 10 seeds | 160/300 = 53.3% | 47.3% to 59.0% | 48.7% to 58.3% |
| Opus efforts: 58 blocks, 18 seeds (2 matches in half blocks left out) | 61/116 = 52.6% | 38.4% to 65.7% | 43.1% to 62.1% |
| Sol efforts: 100 blocks, 10 seeds | 111/200 = 55.5% | 43.0% to 68.0% | 48.5% to 62.5% |
| Sonnet efforts: 150 blocks, 10 seeds | 162/300 = 54.0% | 42.3% to 64.0% | 48.7% to 59.7% |
| Terra 6.1 efforts: 7 blocks, 7 seeds (2 matches in half blocks left out) | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% |
| Terra efforts: 100 blocks, 10 seeds | 96/200 = 48.0% | 37.0% to 59.0% | 40.5% to 55.5% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 1578/2784 = 56.7% | 50.6% to 62.3% | 54.8% to 58.5% | 673/1392 |
| Astra efforts | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% | 2/2 |
| Cross-model | 668/1150 = 58.1% | 52.1% to 63.5% | 55.3% to 60.8% | 261/575 |
| Haiku 4.5 efforts | 115/200 = 57.5% | 50.5% to 65.5% | 51.0% to 64.0% | 50/100 |
| Haiku 5.5 efforts | 186/300 = 62.0% | 51.3% to 72.0% | 56.0% to 67.7% | 75/150 |
| Luna efforts | 152/300 = 50.7% | 44.7% to 57.0% | 45.7% to 55.7% | 75/150 |
| Opus efforts | 67/116 = 57.8% | 44.7% to 71.2% | 48.3% to 67.2% | 31/58 |
| Sol efforts | 107/200 = 53.5% | 40.5% to 66.5% | 46.0% to 61.0% | 50/100 |
| Sonnet efforts | 164/300 = 54.7% | 42.3% to 65.0% | 49.3% to 60.0% | 75/150 |
| Terra 6.1 efforts | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% | 4/7 |
| Terra efforts | 108/200 = 54.0% | 43.0% to 64.5% | 47.0% to 61.5% | 50/100 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +0.2 | -5.7 to +5.7 | -1.5 to +2.0 | +6.7 | +0.6 to +12.2 | +4.8 to +8.5 |
| Cross-model | -2.0 | -7.6 to +4.1 | -4.9 to +0.8 | +7.9 | +1.9 to +13.4 | +5.1 to +10.5 |
| Haiku 4.5 efforts | +2.5 | -6.5 to +9.2 | -4.5 to +9.7 | +7.5 | +0.6 to +16.5 | +0.8 to +14.2 |
| Haiku 5.5 efforts | -2.7 | -14.2 to +7.7 | -8.6 to +2.7 | +12.0 | +0.6 to +22.6 | +6.2 to +17.6 |
| Luna efforts | +3.3 | -3.1 to +9.7 | -1.4 to +8.3 | +0.7 | -5.3 to +7.5 | -4.3 to +5.7 |
| Opus efforts | +2.1 | -11.9 to +14.8 | -7.6 to +11.2 | +7.6 | -5.7 to +21.3 | -1.9 to +17.2 |
| Sol efforts | +5.5 | -7.7 to +19.0 | -1.6 to +12.6 | +3.5 | -10.1 to +17.5 | -4.0 to +10.7 |
| Sonnet efforts | +4.0 | -8.3 to +14.7 | -1.3 to +9.6 | +4.7 | -7.7 to +14.9 | -0.7 to +10.0 |
| Terra 6.1 efforts | +6.2 | -20.1 to +35.0 | -20.8 to +33.3 | +6.2 | -20.8 to +33.5 | -20.8 to +33.3 |
| Terra efforts | -2.0 | -14.2 to +9.5 | -9.2 to +5.6 | +4.0 | -8.0 to +15.0 | -3.1 to +11.3 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| claude-haiku-4-5-20251001: 262 blocks, 73 seeds | 258/524 = 49.2% | 43.5% to 54.9% | 45.4% to 53.4% |
| claude-haiku-5-5: 328 blocks, 82 seeds | 309/656 = 47.1% | 39.4% to 55.0% | 43.3% to 51.1% |
| claude-opus-5-5: 203 blocks, 57 seeds | 198/406 = 48.8% | 40.3% to 57.5% | 43.3% to 53.9% |
| claude-sonnet-5-5: 299 blocks, 41 seeds | 303/598 = 50.7% | 43.3% to 58.2% | 46.8% to 54.5% |
| gpt-5.6-terra: 208 blocks, 19 seeds | 217/416 = 52.2% | 42.7% to 61.4% | 47.1% to 57.2% |
| gpt-6-astra: 134 blocks, 47 seeds | 129/268 = 48.1% | 39.0% to 58.3% | 41.8% to 54.1% |
| gpt-6-luna: 269 blocks, 27 seeds | 266/538 = 49.4% | 44.3% to 54.5% | 45.9% to 53.2% |
| gpt-6.1-sol: 242 blocks, 39 seeds | 235/484 = 48.6% | 39.9% to 57.3% | 44.0% to 53.3% |
| gpt-6.1-terra: 22 blocks, 12 seeds | 21/44 = 47.7% | 28.9% to 63.6% | 29.5% to 65.9% |

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
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 38.5% to 68.3% | 52.4% | 38.1% to 66.7% | +25 (-84 to +139) | 6 / 10 / 4 |
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
