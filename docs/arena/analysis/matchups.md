# Matchup analysis

Ratings, pair effects, seat and round 1 starter effects for the scored arena matches, from the analysis database ([database.md](../database.md)). All scored matches are two-player. Every rate shows numerator/denominator, a win share counts a split by its share, and every interval is a 95% bootstrap that draws whole units, never single matches or seat swaps: seed blocks (the two seat-swapped matches of one pair and seed) for ratings, and seeds (every block played at a seed, in any pairing) for the headline seat and starter figures. The tables below the line "Tables" are generated: `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` rewrites them, with a fixed RNG seed. Nothing here reads provenance or account data.

**DeepSeek is left out.** Every match with deepseek-v4.1-flash (20 scored matches) is dropped from all cohorts, fits, seat and starter figures and tables, because its free tier refused requests, so its games are not a random sample of what was scheduled. That leaves 3,537 scored matches from the 3,557-match snapshot of 2026-11-04. Every finding below uses these.

## Findings

**Ratings are pooled.** One Bradley-Terry fit covers every scored match of every tournament, so all 49 configs share one Elo scale with the depth-2 search engine (Engine/2/20000) at 0, as in the viewer, so a new config does not move the others. Tournament 4 gave every older config games against other models, so no rating leans on an assumption that effort gaps carry across opponents. The 13 newest configs have 80 matches each against changing opponents, so their intervals are 205 to 234 Elo wide. `results.md` and the viewer rank by the luck-adjusted Round Elo (see below); the match ratings here are a derived view of the same results, about 1.6 times as wide. A second fit on pot share (a config's cash over the match's cash, which credits the round prizes a loser banks) gives the cash rating. Cohorts are only a way to group matches. A cohort is one kind of comparison, pooled over every tournament: Cross-model (every match between different models) or one model's efforts (every match of that model against itself), as in the viewer. There are ten: Cross-model and the efforts of Astra, Haiku 4.5, Haiku 5.5, Luna, Opus, Sol, Sonnet, Terra and Terra 6.1.
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
- **Ratings:** the first-seated entrant wins with probability 1/(1 + exp(-(theta_first - theta_second))), and a share w counts as w wins and 1 - w losses. One fit covers every scored match of every tournament. A mean-zero Gaussian prior on theta (standard deviation 3) regularizes the fit; it also shrinks rating differences slightly. Ratings are reported on the Elo scale with the depth-2 search engine (Engine/2/20000) at 0, which is what `web/src/arena-viewer/page/ratings.ts` computes. The win rating counts win shares; the cash rating is the same fit on pot shares. Intervals draw seed blocks 2,000 times, refitting each draw, as the viewer does. Each draw is centred on the mean entrant and moved by the point fit's shift, so an interval leaves out the engine's own noise; the engine's interval is the uncertainty of the 0.
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
| Cross-model | 47 | 3310 | 1300 / 710 | 441/1081 | 1 / 3 / 466 | yes | 3310 completed, 2 partial, 5 partial (skipped), 138 skipped (skipped), 935 unstarted |
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

| config | wins/matches = win share | rating (Elo, depth-2 engine at 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) | pot share | cash rating (Elo, depth-2 engine at 0) | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5-max | 59/80 = 73.8% | +231 | +156 to +326 | +156 to +340 | 64.4% | +132 | +90 to +176 |
| gpt-6.1-terra-max | 68/100 = 68.0% | +198 | +125 to +275 | +126 to +275 | 62.4% | +124 | +84 to +166 |
| gpt-6-astra-high | 68/100 = 68.0% | +190 | +125 to +268 | +122 to +267 | 64.0% | +131 | +94 to +168 |
| claude-sonnet-5-5-max | 94/140 = 67.1% | +183 | +120 to +251 | +101 to +289 | 62.3% | +119 | +83 to +154 |
| claude-opus-5-5-xhigh | 89/170 = 52.4% | +164 | +114 to +215 | +114 to +217 | 52.4% | +107 | +81 to +134 |
| gpt-6-astra-medium | 169/254 = 66.5% | +162 | +121 to +205 | +123 to +203 | 60.2% | +98 | +76 to +121 |
| Engine/6/20000/sampled | 86/156 = 55.1% | +160 | +109 to +216 | +109 to +221 | 53.4% | +102 | +72 to +133 |
| gpt-6.1-terra-xhigh | 71/102 = 69.6% | +158 | +91 to +231 | +93 to +233 | 60.2% | +74 | +37 to +111 |
| gpt-6.1-sol-max | 80/142 = 56.3% | +155 | +104 to +213 | +104 to +214 | 54.5% | +109 | +81 to +140 |
| claude-opus-5-5-high | 47/80 = 58.8% | +150 | +73 to +230 | +70 to +245 | 54.7% | +88 | +43 to +130 |
| claude-sonnet-5-5-xhigh | 105/176 = 59.7% | +139 | +86 to +193 | +81 to +207 | 53.7% | +67 | +39 to +94 |
| gpt-6.1-terra-medium | 87/130 = 66.9% | +138 | +73 to +203 | +76 to +204 | 59.8% | +74 | +39 to +109 |
| gpt-6-astra-low | 52/80 = 65.0% | +133 | +60 to +218 | +61 to +219 | 59.4% | +76 | +38 to +117 |
| gpt-6-astra-off | 51/80 = 63.7% | +113 | +39 to +202 | +37 to +199 | 55.9% | +44 | +4 to +86 |
| gpt-6.1-sol-low | 51/98 = 52.0% | +103 | +33 to +178 | +33 to +176 | 50.9% | +74 | +33 to +116 |
| gpt-6.1-sol-xhigh | 52/101 = 51.5% | +100 | +34 to +167 | +33 to +170 | 52.4% | +82 | +46 to +119 |
| claude-opus-5-5-medium | 188/334 = 56.3% | +96 | +58 to +134 | +60 to +134 | 53.8% | +60 | +42 to +79 |
| gpt-6.1-terra-high | 51/82 = 62.2% | +84 | +5 to +177 | +3 to +168 | 59.1% | +56 | +16 to +102 |
| claude-haiku-5-5-max | 68/111 = 61.3% | +83 | +20 to +147 | +7 to +172 | 58.7% | +58 | +26 to +88 |
| gpt-6.1-sol-medium | 155/271 = 57.2% | +82 | +43 to +124 | +28 to +143 | 56.8% | +71 | +49 to +93 |
| gpt-6.1-sol-high | 47/99 = 47.5% | +75 | +9 to +141 | +6 to +140 | 48.0% | +56 | +18 to +96 |
| claude-haiku-5-5-xhigh | 86/158 = 54.4% | +71 | +17 to +125 | +14 to +121 | 50.4% | +25 | -4 to +52 |
| gpt-6.1-terra-off/low | 145/242 = 59.9% | +69 | +25 to +115 | +21 to +114 | 55.3% | +33 | +12 to +56 |
| claude-opus-5-5-off/low | 83/160 = 51.9% | +56 | -3 to +116 | +0 to +116 | 54.1% | +52 | +22 to +81 |
| claude-haiku-5-5-high | 118/223 = 52.9% | +46 | -3 to +95 | +1 to +90 | 50.8% | +19 | -6 to +44 |
| claude-sonnet-5-5-high | 75/161 = 46.6% | +46 | -15 to +107 | -14 to +107 | 46.9% | +19 | -13 to +52 |
| claude-haiku-5-5-medium | 229/444 = 51.6% | +28 | -1 to +57 | +1 to +56 | 50.6% | +15 | +0 to +31 |
| claude-sonnet-5-5-medium | 175/364 = 48.1% | +22 | -14 to +62 | -27 to +67 | 48.8% | +15 | -4 to +35 |
| gpt-5.6-terra-xhigh | 53/93 = 57.0% | +22 | -55 to +106 | -52 to +104 | 55.1% | +47 | +7 to +89 |
| gpt-5.6-terra-max | 52/90 = 57.8% | +18 | -69 to +104 | -44 to +80 | 53.8% | +34 | -10 to +76 |
| gpt-6-luna-xhigh | 79/115 = 68.7% | +8 | -61 to +78 | -47 to +63 | 63.6% | +17 | -22 to +58 |
| claude-haiku-5-5-low | 137/278 = 49.3% | +0 | -47 to +46 | -43 to +43 | 51.0% | +8 | -16 to +31 |
| Engine/2/20000 | 806/1294 = 62.3% | +0 | -30 to +28 | -30 to +29 | 58.4% | +0 | -15 to +15 |
| claude-sonnet-5-5-off | 65/164 = 39.6% | -3 | -60 to +50 | -60 to +47 | 42.4% | -11 | -40 to +18 |
| gpt-6-luna-max | 75/112 = 67.0% | -8 | -81 to +69 | -71 to +55 | 63.2% | +13 | -29 to +54 |
| gpt-5.6-terra-medium | 119/259 = 45.9% | -42 | -86 to +1 | -89 to +3 | 48.0% | -8 | -30 to +16 |
| gpt-6-luna-high | 116/218 = 53.2% | -46 | -103 to +11 | -105 to +14 | 51.6% | -29 | -57 to -1 |
| claude-sonnet-5-5-low | 50/159 = 31.4% | -56 | -123 to +0 | -120 to -2 | 39.5% | -28 | -61 to +4 |
| gpt-5.6-terra-high | 40/91 = 44.0% | -60 | -140 to +16 | -124 to -8 | 49.5% | +11 | -30 to +54 |
| gpt-5.6-terra-low | 37/91 = 40.7% | -77 | -162 to -3 | -150 to -5 | 45.5% | -11 | -53 to +28 |
| claude-haiku-5-5-off | 221/668 = 33.1% | -132 | -166 to -99 | -171 to -102 | 38.4% | -86 | -104 to -69 |
| claude-haiku-4-5-20251001-medium | 123/358 = 34.4% | -169 | -214 to -129 | -218 to -131 | 38.6% | -102 | -124 to -80 |
| claude-haiku-4-5-20251001-minimal/low | 112/292 = 38.4% | -215 | -270 to -169 | -272 to -169 | 42.2% | -120 | -147 to -95 |
| gpt-6-luna-medium | 101/398 = 25.4% | -227 | -272 to -186 | -271 to -187 | 33.9% | -129 | -151 to -110 |
| claude-haiku-4-5-20251001-high | 47/135 = 34.8% | -259 | -334 to -197 | -365 to -190 | 42.0% | -131 | -164 to -100 |
| gpt-6-luna-off/low | 77/396 = 19.4% | -308 | -367 to -259 | -376 to -258 | 28.7% | -184 | -211 to -159 |
| claude-haiku-4-5-20251001-off | 28/125 = 22.4% | -367 | -454 to -291 | -470 to -282 | 32.6% | -200 | -236 to -167 |

With a seat term and a round 1 starter term in the fit (position 1 +15 Elo, the starter +39 Elo) the largest rating change is 14.3 Elo.


### Observed pairs against the pooled ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below. Every resample refits the pooled ratings.

#### Cross-model

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| Engine/2/20000 vs claude-haiku-4-5-20251001-medium | 9/18 = 50.0% | 72.5% | -22.5 | -45.0 to -1.1 |
| Engine/2/20000 vs claude-haiku-5-5-high | 21/50 = 42.0% | 43.5% | -1.5 | -13.6 to +11.0 |
| Engine/2/20000 vs claude-haiku-5-5-low | 45/84 = 53.6% | 50.0% | +3.6 | -4.7 to +12.0 |
| Engine/2/20000 vs claude-haiku-5-5-medium | 35/82 = 42.7% | 46.0% | -3.3 | -12.3 to +5.8 |
| Engine/2/20000 vs claude-haiku-5-5-off | 320/466 = 68.7% | 68.1% | +0.5 | -1.3 to +2.3 |
| Engine/2/20000 vs claude-opus-5-5-medium | 8/20 = 40.0% | 36.5% | +3.5 | -14.4 to +22.5 |
| Engine/2/20000 vs claude-sonnet-5-5-medium | 10/20 = 50.0% | 46.8% | +3.2 | -16.8 to +23.8 |
| Engine/2/20000 vs gpt-6-luna-high | 57/106 = 53.8% | 56.5% | -2.8 | -9.1 to +3.2 |
| Engine/2/20000 vs gpt-6-luna-medium | 89/116 = 76.7% | 78.7% | -1.9 | -7.5 to +3.4 |
| Engine/2/20000 vs gpt-6-luna-off/low | 156/176 = 88.6% | 85.5% | +3.2 | -0.6 to +6.8 |
| Engine/2/20000 vs gpt-6.1-terra-high | 2/2 = 100.0% | 38.2% | +61.8 | +49.0 to +73.0 |
| Engine/2/20000 vs gpt-6.1-terra-medium | 13/50 = 26.0% | 31.2% | -5.2 | -14.9 to +4.2 |
| Engine/2/20000 vs gpt-6.1-terra-off/low | 34/82 = 41.5% | 40.2% | +1.3 | -6.1 to +8.9 |
| Engine/2/20000 vs gpt-6.1-terra-xhigh | 7/22 = 31.8% | 28.7% | +3.1 | -10.2 to +16.8 |
| Engine/6/20000/sampled vs claude-haiku-5-5-medium | 10/20 = 50.0% | 68.1% | -18.1 | -33.1 to -4.2 |
| Engine/6/20000/sampled vs claude-opus-5-5-medium | 13/20 = 65.0% | 59.1% | +5.9 | -12.6 to +24.7 |
| Engine/6/20000/sampled vs claude-opus-5-5-xhigh | 13/20 = 65.0% | 49.5% | +15.5 | -3.0 to +34.2 |
| Engine/6/20000/sampled vs claude-sonnet-5-5-medium | 14/20 = 70.0% | 68.8% | +1.2 | -14.1 to +16.7 |
| Engine/6/20000/sampled vs claude-sonnet-5-5-xhigh | 7/16 = 43.8% | 53.0% | -9.2 | -28.8 to +11.4 |
| Engine/6/20000/sampled vs gpt-6-astra-high | 9/20 = 45.0% | 45.7% | -0.7 | -16.0 to +15.6 |
| Engine/6/20000/sampled vs gpt-6.1-sol-max | 10/20 = 50.0% | 50.7% | -0.7 | -18.7 to +17.0 |
| Engine/6/20000/sampled vs gpt-6.1-terra-max | 10/20 = 50.0% | 44.6% | +5.4 | -11.8 to +22.5 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-high | 0/1 = 0.0% | 14.7% | -14.7 | -21.0 to -9.4 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-max | 0/1 = 0.0% | 12.2% | -12.2 | -18.8 to -7.2 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-medium | 0/1 = 0.0% | 16.0% | -16.0 | -21.7 to -10.9 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-off | 2/10 = 20.0% | 32.5% | -12.5 | -34.9 to +15.8 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-xhigh | 0/1 = 0.0% | 13.0% | -13.0 | -19.0 to -7.9 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-max | 0/2 = 0.0% | 5.6% | -5.6 | -9.4 to -2.8 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-off/low | 1/3 = 33.3% | 14.0% | +19.3 | -17.4 to +87.2 |
| claude-haiku-4-5-20251001-high vs claude-sonnet-5-5-medium | 0/2 = 0.0% | 16.5% | -16.5 | -22.9 to -10.8 |
| claude-haiku-4-5-20251001-high vs gpt-5.6-terra-medium | 0/2 = 0.0% | 22.2% | -22.2 | -30.4 to -14.5 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-high | 0/2 = 0.0% | 7.0% | -7.0 | -11.2 to -3.9 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-low | 0/2 = 0.0% | 9.5% | -9.5 | -14.9 to -5.1 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-medium | 0/2 = 0.0% | 8.1% | -8.1 | -11.8 to -5.0 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-off | 0/3 = 0.0% | 10.5% | -10.5 | -16.8 to -5.6 |
| claude-haiku-4-5-20251001-high vs gpt-6-luna-medium | 0/2 = 0.0% | 45.3% | -45.3 | -55.3 to -33.2 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 12.3% | -12.3 | -17.4 to -7.7 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-high | 0/4 = 0.0% | 12.2% | -12.2 | -19.9 to -6.5 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-max | 0/2 = 0.0% | 6.7% | -6.7 | -10.9 to -3.6 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-medium | 1/3 = 33.3% | 9.2% | +24.1 | -11.6 to +92.0 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-off/low | 0/7 = 0.0% | 13.1% | -13.1 | -18.7 to -8.4 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 8.3% | -8.3 | -13.3 to -4.7 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-high | 1/12 = 8.3% | 22.6% | -14.2 | -27.6 to +6.0 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-low | 4/14 = 28.6% | 27.4% | +1.1 | -20.6 to +21.4 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-max | 0/2 = 0.0% | 19.0% | -19.0 | -26.0 to -12.8 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-medium | 8/31 = 25.8% | 24.4% | +1.4 | -10.2 to +13.5 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-off | 5/12 = 41.7% | 44.8% | -3.1 | -32.4 to +28.1 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-xhigh | 1/2 = 50.0% | 20.1% | +29.9 | +22.4 to +35.4 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-high | 0/1 = 0.0% | 13.8% | -13.8 | -20.5 to -8.4 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-max | 0/2 = 0.0% | 9.1% | -9.1 | -14.2 to -5.1 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-medium | 7/20 = 35.0% | 17.9% | +17.1 | -2.5 to +36.4 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-off/low | 1/5 = 20.0% | 21.5% | -1.5 | -26.6 to +75.7 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-high | 0/2 = 0.0% | 22.6% | -22.6 | -30.6 to -15.4 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-low | 0/2 = 0.0% | 34.4% | -34.4 | -44.0 to -24.5 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-max | 0/2 = 0.0% | 11.7% | -11.7 | -16.8 to -7.3 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-medium | 2/20 = 10.0% | 25.0% | -15.0 | -27.6 to -0.6 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-off | 0/4 = 0.0% | 27.8% | -27.8 | -37.0 to -20.2 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-xhigh | 0/2 = 0.0% | 14.5% | -14.5 | -19.5 to -10.1 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-low | 0/2 = 0.0% | 37.2% | -37.2 | -48.6 to -25.8 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-max | 0/2 = 0.0% | 25.5% | -25.5 | -35.9 to -15.9 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-medium | 6/20 = 30.0% | 32.6% | -2.6 | -18.5 to +11.7 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-xhigh | 1/2 = 50.0% | 25.0% | +25.0 | +13.2 to +33.0 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-high | 0/3 = 0.0% | 11.3% | -11.3 | -16.9 to -7.0 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-low | 1/3 = 33.3% | 15.0% | +18.3 | -19.0 to +86.4 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-medium | 3/20 = 15.0% | 13.0% | +2.0 | -11.9 to +17.7 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-off | 0/3 = 0.0% | 16.5% | -16.5 | -24.2 to -9.8 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-high | 1/2 = 50.0% | 33.0% | +17.0 | +7.5 to +25.5 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-medium | 12/20 = 60.0% | 58.3% | +1.7 | -25.7 to +27.2 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-off/low | 2/2 = 100.0% | 69.0% | +31.0 | +22.6 to +38.7 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 26.6% | +23.4 | +13.3 to +31.9 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 19.8% | +30.2 | +21.9 to +36.4 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-low | 1/2 = 50.0% | 17.3% | +32.7 | +24.7 to +38.6 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-medium | 6/20 = 30.0% | 19.1% | +10.9 | -8.4 to +32.9 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 17.6% | +32.4 | +24.2 to +38.0 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-high | 0/4 = 0.0% | 19.0% | -19.0 | -27.7 to -11.2 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-max | 0/3 = 0.0% | 10.8% | -10.8 | -16.4 to -6.8 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-medium | 1/3 = 33.3% | 14.6% | +18.7 | -18.6 to +86.7 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-off/low | 1/7 = 14.3% | 20.3% | -6.0 | -23.9 to +28.7 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 13.2% | -13.2 | -19.3 to -8.4 |
| claude-haiku-4-5-20251001-minimal/low vs claude-haiku-5-5-low | 2/21 = 9.5% | 22.4% | -12.9 | -24.6 to +2.9 |
| claude-haiku-4-5-20251001-minimal/low vs claude-haiku-5-5-medium | 2/5 = 40.0% | 19.8% | +20.2 | -20.7 to +33.8 |
| claude-haiku-4-5-20251001-minimal/low vs claude-haiku-5-5-off | 7/22 = 31.8% | 38.3% | -6.4 | -25.8 to +12.8 |
| claude-haiku-4-5-20251001-minimal/low vs claude-opus-5-5-high | 0/1 = 0.0% | 10.9% | -10.9 | -16.6 to -6.4 |
| claude-haiku-4-5-20251001-minimal/low vs claude-opus-5-5-max | 0/4 = 0.0% | 7.1% | -7.1 | -11.4 to -4.0 |
| claude-haiku-4-5-20251001-minimal/low vs claude-opus-5-5-medium | 1/4 = 25.0% | 14.3% | +10.7 | -16.9 to +38.1 |
| claude-haiku-4-5-20251001-minimal/low vs claude-opus-5-5-off/low | 0/7 = 0.0% | 17.3% | -17.3 | -24.1 to -11.8 |
| claude-haiku-4-5-20251001-minimal/low vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 20.3% | +29.7 | +23.2 to +35.2 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-5.6-terra-medium | 1/2 = 50.0% | 27.0% | +23.0 | +15.1 to +29.9 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6-astra-high | 0/6 = 0.0% | 8.8% | -8.8 | -13.7 to -5.2 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6-astra-low | 0/5 = 0.0% | 11.9% | -11.9 | -18.0 to -7.0 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6-astra-medium | 0/2 = 0.0% | 10.3% | -10.3 | -14.1 to -7.0 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6-astra-off | 1/6 = 16.7% | 13.2% | +3.5 | -17.2 to +40.6 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6-luna-medium | 3/4 = 75.0% | 51.6% | +23.4 | -7.3 to +54.4 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-sol-medium | 0/2 = 0.0% | 15.3% | -15.3 | -20.5 to -10.8 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-terra-high | 3/8 = 37.5% | 15.2% | +22.3 | -12.7 to +60.3 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-terra-max | 1/5 = 20.0% | 8.5% | +11.5 | -11.1 to +58.2 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-terra-medium | 0/6 = 0.0% | 11.6% | -11.6 | -17.4 to -7.6 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-terra-off/low | 3/14 = 21.4% | 16.3% | +5.1 | -14.9 to +27.2 |
| claude-haiku-4-5-20251001-minimal/low vs gpt-6.1-terra-xhigh | 0/6 = 0.0% | 10.4% | -10.4 | -15.8 to -6.6 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5-medium | 1/2 = 50.0% | 9.3% | +40.7 | +35.7 to +44.1 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5-off | 3/11 = 27.3% | 20.5% | +6.7 | -21.2 to +44.0 |
| claude-haiku-4-5-20251001-off vs claude-opus-5-5-max | 0/1 = 0.0% | 3.1% | -3.1 | -5.5 to -1.5 |
| claude-haiku-4-5-20251001-off vs claude-opus-5-5-off/low | 0/2 = 0.0% | 8.0% | -8.0 | -13.1 to -4.5 |
| claude-haiku-4-5-20251001-off vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 9.6% | +40.4 | +34.8 to +44.0 |
| claude-haiku-4-5-20251001-off vs gpt-5.6-terra-medium | 0/2 = 0.0% | 13.3% | -13.3 | -19.8 to -7.9 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-high | 0/2 = 0.0% | 3.9% | -3.9 | -6.7 to -2.0 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-low | 0/2 = 0.0% | 5.3% | -5.3 | -9.4 to -2.7 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-medium | 0/2 = 0.0% | 4.5% | -4.5 | -7.1 to -2.6 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-off | 0/2 = 0.0% | 5.9% | -5.9 | -10.2 to -2.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-sol-medium | 0/2 = 0.0% | 7.0% | -7.0 | -10.7 to -4.1 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-high | 0/3 = 0.0% | 6.9% | -6.9 | -12.1 to -3.4 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-max | 0/2 = 0.0% | 3.7% | -3.7 | -6.6 to -1.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-medium | 0/2 = 0.0% | 5.2% | -5.2 | -8.9 to -2.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-off/low | 0/5 = 0.0% | 7.5% | -7.5 | -12.0 to -4.3 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 4.6% | -4.6 | -7.9 to -2.4 |
| claude-haiku-5-5-high vs claude-opus-5-5-high | 0/2 = 0.0% | 35.4% | -35.4 | -48.2 to -23.7 |
| claude-haiku-5-5-high vs claude-opus-5-5-max | 0/4 = 0.0% | 25.6% | -25.6 | -36.7 to -15.4 |
| claude-haiku-5-5-high vs claude-opus-5-5-medium | 1/2 = 50.0% | 42.8% | +7.2 | -1.4 to +15.2 |
| claude-haiku-5-5-high vs claude-opus-5-5-off/low | 6/7 = 85.7% | 48.5% | +37.2 | +4.1 to +58.7 |
| claude-haiku-5-5-high vs claude-sonnet-5-5-medium | 2/4 = 50.0% | 53.3% | -3.3 | -57.8 to +51.3 |
| claude-haiku-5-5-high vs gpt-6-astra-high | 2/4 = 50.0% | 30.3% | +19.7 | -32.4 to +72.1 |
| claude-haiku-5-5-high vs gpt-6-astra-low | 1/4 = 25.0% | 37.7% | -12.7 | -45.6 to +43.8 |
| claude-haiku-5-5-high vs gpt-6-astra-medium | 0/2 = 0.0% | 33.9% | -33.9 | -41.9 to -25.8 |
| claude-haiku-5-5-high vs gpt-6-astra-off | 1/4 = 25.0% | 40.5% | -15.5 | -48.2 to +50.5 |
| claude-haiku-5-5-high vs gpt-6-luna-medium | 1/2 = 50.0% | 82.7% | -32.7 | -37.1 to -26.9 |
| claude-haiku-5-5-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 44.8% | -44.8 | -53.3 to -35.2 |
| claude-haiku-5-5-high vs gpt-6.1-terra-high | 2/4 = 50.0% | 44.5% | +5.5 | -47.3 to +58.4 |
| claude-haiku-5-5-high vs gpt-6.1-terra-max | 0/4 = 0.0% | 29.4% | -29.4 | -41.1 to -19.5 |
| claude-haiku-5-5-high vs gpt-6.1-terra-medium | 2/4 = 50.0% | 37.1% | +12.9 | -43.2 to +64.8 |
| claude-haiku-5-5-high vs gpt-6.1-terra-off/low | 3/7 = 42.9% | 46.7% | -3.8 | -43.9 to +37.1 |
| claude-haiku-5-5-high vs gpt-6.1-terra-xhigh | 2/4 = 50.0% | 34.3% | +15.7 | -36.4 to +68.1 |
| claude-haiku-5-5-low vs claude-opus-5-5-high | 1/2 = 50.0% | 29.7% | +20.3 | -35.9 to +76.5 |
| claude-haiku-5-5-low vs claude-opus-5-5-max | 1/3 = 33.3% | 20.9% | +12.4 | -26.8 to +79.9 |
| claude-haiku-5-5-low vs claude-opus-5-5-medium | 2/2 = 100.0% | 36.6% | +63.4 | +54.4 to +70.7 |
| claude-haiku-5-5-low vs claude-opus-5-5-off/low | 1/6 = 16.7% | 42.1% | -25.4 | -48.7 to +11.0 |
| claude-haiku-5-5-low vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 46.8% | +3.2 | -5.0 to +11.9 |
| claude-haiku-5-5-low vs gpt-5.6-terra-medium | 1/2 = 50.0% | 56.1% | -6.1 | -14.9 to +3.2 |
| claude-haiku-5-5-low vs gpt-6-astra-high | 0/4 = 0.0% | 25.1% | -25.1 | -34.8 to -16.9 |
| claude-haiku-5-5-low vs gpt-6-astra-low | 0/4 = 0.0% | 31.8% | -31.8 | -43.0 to -21.5 |
| claude-haiku-5-5-low vs gpt-6-astra-medium | 0/2 = 0.0% | 28.3% | -28.3 | -35.6 to -21.1 |
| claude-haiku-5-5-low vs gpt-6-astra-off | 3/4 = 75.0% | 34.4% | +40.6 | -29.3 to +73.5 |
| claude-haiku-5-5-low vs gpt-6-luna-medium | 1/2 = 50.0% | 78.7% | -28.7 | -33.9 to -22.3 |
| claude-haiku-5-5-low vs gpt-6.1-sol-medium | 2/2 = 100.0% | 38.5% | +61.5 | +52.1 to +68.9 |
| claude-haiku-5-5-low vs gpt-6.1-terra-high | 3/4 = 75.0% | 38.2% | +36.8 | -23.3 to +71.4 |
| claude-haiku-5-5-low vs gpt-6.1-terra-max | 1/4 = 25.0% | 24.3% | +0.7 | -29.7 to +70.2 |
| claude-haiku-5-5-low vs gpt-6.1-terra-medium | 3/4 = 75.0% | 31.2% | +43.8 | -23.4 to +75.0 |
| claude-haiku-5-5-low vs gpt-6.1-terra-off/low | 4/8 = 50.0% | 40.3% | +9.7 | -22.7 to +44.1 |
| claude-haiku-5-5-low vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 28.7% | -28.7 | -39.0 to -20.2 |
| claude-haiku-5-5-max vs claude-opus-5-5-medium | 2/2 = 100.0% | 48.2% | +51.8 | +40.0 to +61.2 |
| claude-haiku-5-5-max vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 58.7% | -8.7 | -17.5 to +2.7 |
| claude-haiku-5-5-max vs gpt-5.6-terra-medium | 1/2 = 50.0% | 67.3% | -17.3 | -25.7 to -6.5 |
| claude-haiku-5-5-max vs gpt-6.1-sol-medium | 1/2 = 50.0% | 50.2% | -0.2 | -10.6 to +9.8 |
| claude-haiku-5-5-medium vs claude-opus-5-5-high | 0/2 = 0.0% | 33.2% | -33.2 | -43.6 to -23.1 |
| claude-haiku-5-5-medium vs claude-opus-5-5-max | 1/3 = 33.3% | 23.7% | +9.6 | -28.9 to +31.9 |
| claude-haiku-5-5-medium vs claude-opus-5-5-medium | 7/20 = 35.0% | 40.4% | -5.4 | -22.1 to +8.8 |
| claude-haiku-5-5-medium vs claude-opus-5-5-off/low | 3/6 = 50.0% | 46.0% | +4.0 | -40.8 to +51.1 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-high | 1/4 = 25.0% | 47.5% | -22.5 | -53.2 to +7.8 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-low | 2/2 = 100.0% | 61.9% | +38.1 | +28.4 to +46.6 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-max | 0/2 = 0.0% | 29.1% | -29.1 | -37.4 to -20.9 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-medium | 12/20 = 60.0% | 50.8% | +9.2 | -9.4 to +28.2 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-off | 1/2 = 50.0% | 54.5% | -4.5 | -13.2 to +4.5 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-xhigh | 1/4 = 25.0% | 34.5% | -9.5 | -39.4 to +20.8 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-high | 2/2 = 100.0% | 62.4% | +37.6 | +26.1 to +48.4 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.7% | -14.7 | -25.4 to -3.3 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-max | 2/2 = 100.0% | 51.5% | +48.5 | +34.9 to +59.6 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-medium | 13/20 = 65.0% | 60.0% | +5.0 | -9.6 to +21.1 |
| claude-haiku-5-5-medium vs gpt-6-astra-high | 1/4 = 25.0% | 28.3% | -3.3 | -34.3 to +46.3 |
| claude-haiku-5-5-medium vs gpt-6-astra-low | 2/4 = 50.0% | 35.4% | +14.6 | -37.2 to +68.2 |
| claude-haiku-5-5-medium vs gpt-6-astra-medium | 6/20 = 30.0% | 31.7% | -1.7 | -16.7 to +14.5 |
| claude-haiku-5-5-medium vs gpt-6-astra-off | 3/4 = 75.0% | 38.1% | +36.9 | -30.6 to +70.0 |
| claude-haiku-5-5-medium vs gpt-6-luna-high | 1/2 = 50.0% | 60.5% | -10.5 | -18.5 to -1.3 |
| claude-haiku-5-5-medium vs gpt-6-luna-max | 1/2 = 50.0% | 55.2% | -5.2 | -15.9 to +6.0 |
| claude-haiku-5-5-medium vs gpt-6-luna-medium | 19/20 = 95.0% | 81.3% | +13.7 | +2.9 to +21.9 |
| claude-haiku-5-5-medium vs gpt-6-luna-off/low | 2/2 = 100.0% | 87.4% | +12.6 | +8.9 to +16.5 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-high | 2/4 = 50.0% | 43.4% | +6.6 | -3.8 to +16.3 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-low | 0/2 = 0.0% | 39.3% | -39.3 | -49.3 to -28.8 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-max | 1/2 = 50.0% | 32.5% | +17.5 | +9.4 to +24.6 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-medium | 10/20 = 50.0% | 42.3% | +7.7 | -6.4 to +22.7 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 39.8% | +10.2 | -1.0 to +19.4 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-high | 1/4 = 25.0% | 42.1% | -17.1 | -50.5 to +52.5 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-max | 1/4 = 25.0% | 27.3% | -2.3 | -32.9 to +64.6 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-medium | 1/4 = 25.0% | 34.8% | -9.8 | -40.8 to +57.4 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-off/low | 1/8 = 12.5% | 44.2% | -31.7 | -48.9 to -1.8 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 32.1% | -32.1 | -41.9 to -23.2 |
| claude-haiku-5-5-off vs claude-opus-5-5-high | 0/1 = 0.0% | 16.5% | -16.5 | -24.0 to -10.8 |
| claude-haiku-5-5-off vs claude-opus-5-5-max | 0/2 = 0.0% | 11.0% | -11.0 | -16.7 to -6.3 |
| claude-haiku-5-5-off vs claude-opus-5-5-off/low | 0/5 = 0.0% | 25.3% | -25.3 | -33.2 to -18.6 |
| claude-haiku-5-5-off vs gpt-5.6-terra-medium | 1/2 = 50.0% | 37.3% | +12.7 | +5.1 to +19.7 |
| claude-haiku-5-5-off vs gpt-6-astra-high | 1/3 = 33.3% | 13.5% | +19.8 | -17.0 to +87.6 |
| claude-haiku-5-5-off vs gpt-6-astra-low | 0/3 = 0.0% | 17.9% | -17.9 | -25.5 to -11.3 |
| claude-haiku-5-5-off vs gpt-6-astra-medium | 0/2 = 0.0% | 15.6% | -15.6 | -20.1 to -11.5 |
| claude-haiku-5-5-off vs gpt-6-astra-off | 1/4 = 25.0% | 19.6% | +5.4 | -24.7 to +76.4 |
| claude-haiku-5-5-off vs gpt-6-luna-medium | 1/2 = 50.0% | 63.3% | -13.3 | -19.6 to -6.8 |
| claude-haiku-5-5-off vs gpt-6.1-sol-medium | 0/2 = 0.0% | 22.6% | -22.6 | -28.3 to -17.5 |
| claude-haiku-5-5-off vs gpt-6.1-terra-high | 0/4 = 0.0% | 22.4% | -22.4 | -32.5 to -13.8 |
| claude-haiku-5-5-off vs gpt-6.1-terra-max | 0/3 = 0.0% | 13.0% | -13.0 | -19.3 to -8.3 |
| claude-haiku-5-5-off vs gpt-6.1-terra-medium | 0/3 = 0.0% | 17.5% | -17.5 | -24.3 to -12.5 |
| claude-haiku-5-5-off vs gpt-6.1-terra-off/low | 2/7 = 28.6% | 23.9% | +4.7 | -25.5 to +42.8 |
| claude-haiku-5-5-off vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 15.8% | -15.8 | -22.1 to -10.7 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-high | 0/2 = 0.0% | 38.9% | -38.9 | -51.6 to -26.4 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-max | 0/3 = 0.0% | 28.5% | -28.5 | -40.4 to -17.6 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-medium | 0/2 = 0.0% | 46.5% | -46.5 | -55.3 to -36.8 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-off/low | 2/7 = 28.6% | 52.2% | -23.7 | -55.9 to +11.4 |
| claude-haiku-5-5-xhigh vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 57.0% | -7.0 | -15.7 to +2.9 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-high | 1/4 = 25.0% | 33.6% | -8.6 | -41.6 to +56.1 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-low | 1/4 = 25.0% | 41.2% | -16.2 | -49.3 to +52.0 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-medium | 0/2 = 0.0% | 37.3% | -37.3 | -46.5 to -28.2 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-off | 3/4 = 75.0% | 44.1% | +30.9 | -35.1 to +66.5 |
| claude-haiku-5-5-xhigh vs gpt-6-luna-medium | 2/2 = 100.0% | 84.8% | +15.2 | +10.6 to +20.7 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-high | 2/4 = 50.0% | 48.2% | +1.8 | -51.6 to +58.0 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-max | 0/4 = 0.0% | 32.5% | -32.5 | -44.2 to -21.9 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-medium | 3/4 = 75.0% | 40.6% | +34.4 | -34.2 to +67.0 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-off/low | 2/7 = 28.6% | 50.4% | -21.8 | -53.8 to +17.3 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-xhigh | 2/4 = 50.0% | 37.8% | +12.2 | -40.8 to +65.5 |
| claude-opus-5-5-high vs claude-sonnet-5-5-high | 2/2 = 100.0% | 64.6% | +35.4 | +23.5 to +48.6 |
| claude-opus-5-5-high vs claude-sonnet-5-5-low | 2/2 = 100.0% | 76.6% | +23.4 | +14.4 to +34.7 |
| claude-opus-5-5-high vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 67.6% | -17.6 | -27.2 to -5.7 |
| claude-opus-5-5-high vs claude-sonnet-5-5-off | 2/2 = 100.0% | 70.7% | +29.3 | +19.1 to +41.2 |
| claude-opus-5-5-high vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 51.5% | +48.5 | +34.8 to +61.1 |
| claude-opus-5-5-high vs gpt-6-astra-high | 0/1 = 0.0% | 44.2% | -44.2 | -58.5 to -29.3 |
| claude-opus-5-5-high vs gpt-6-astra-medium | 1/2 = 50.0% | 48.3% | +1.7 | -10.1 to +13.2 |
| claude-opus-5-5-high vs gpt-6-astra-off | 0/1 = 0.0% | 55.3% | -55.3 | -68.8 to -38.2 |
| claude-opus-5-5-high vs gpt-6-luna-medium | 2/2 = 100.0% | 89.7% | +10.3 | +6.3 to +15.6 |
| claude-opus-5-5-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 59.6% | -59.6 | -69.2 to -46.4 |
| claude-opus-5-5-high vs gpt-6.1-terra-max | 1/1 = 100.0% | 43.1% | +56.9 | +40.8 to +69.7 |
| claude-opus-5-5-high vs gpt-6.1-terra-off/low | 1/1 = 100.0% | 61.4% | +38.6 | +26.9 to +50.0 |
| claude-opus-5-5-max vs claude-sonnet-5-5-high | 3/4 = 75.0% | 74.4% | +0.6 | -70.1 to +32.4 |
| claude-opus-5-5-max vs claude-sonnet-5-5-low | 2/3 = 66.7% | 84.0% | -17.3 | -85.7 to +20.6 |
| claude-opus-5-5-max vs claude-sonnet-5-5-medium | 3/3 = 100.0% | 76.9% | +23.1 | +14.3 to +33.1 |
| claude-opus-5-5-max vs claude-sonnet-5-5-off | 3/3 = 100.0% | 79.4% | +20.6 | +12.2 to +30.4 |
| claude-opus-5-5-max vs claude-sonnet-5-5-xhigh | 2/3 = 66.7% | 62.9% | +3.7 | -64.9 to +44.8 |
| claude-opus-5-5-max vs gpt-6-astra-medium | 1/2 = 50.0% | 59.9% | -9.9 | -22.2 to +2.2 |
| claude-opus-5-5-max vs gpt-6.1-sol-medium | 1/2 = 50.0% | 70.3% | -20.3 | -29.8 to -8.2 |
| claude-opus-5-5-max vs gpt-6.1-terra-medium | 1/2 = 50.0% | 63.2% | -13.2 | -26.2 to +0.5 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-high | 2/2 = 100.0% | 57.2% | +42.8 | +32.2 to +52.2 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-low | 2/4 = 50.0% | 70.6% | -20.6 | -75.0 to +33.5 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-max | 2/2 = 100.0% | 37.7% | +62.3 | +51.4 to +71.3 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-medium | 12/20 = 60.0% | 60.4% | -0.4 | -19.7 to +18.0 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-off | 1/2 = 50.0% | 63.9% | -13.9 | -22.2 to -4.4 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 43.8% | +56.2 | +46.5 to +64.9 |
| claude-opus-5-5-medium vs gpt-5.6-terra-high | 2/2 = 100.0% | 71.0% | +29.0 | +19.4 to +38.8 |
| claude-opus-5-5-medium vs gpt-5.6-terra-low | 1/2 = 50.0% | 73.1% | -23.1 | -31.0 to -12.5 |
| claude-opus-5-5-medium vs gpt-5.6-terra-max | 2/2 = 100.0% | 61.1% | +38.9 | +26.4 to +50.6 |
| claude-opus-5-5-medium vs gpt-5.6-terra-medium | 12/20 = 60.0% | 68.9% | -8.9 | -20.8 to +4.8 |
| claude-opus-5-5-medium vs gpt-5.6-terra-xhigh | 2/2 = 100.0% | 60.4% | +39.6 | +27.9 to +51.1 |
| claude-opus-5-5-medium vs gpt-6-astra-high | 2/4 = 50.0% | 36.8% | +13.2 | -38.4 to +65.7 |
| claude-opus-5-5-medium vs gpt-6-astra-low | 2/4 = 50.0% | 44.7% | +5.3 | -46.8 to +58.4 |
| claude-opus-5-5-medium vs gpt-6-astra-medium | 9/20 = 45.0% | 40.7% | +4.3 | -7.0 to +14.0 |
| claude-opus-5-5-medium vs gpt-6-astra-off | 2/4 = 50.0% | 47.6% | +2.4 | -50.0 to +56.3 |
| claude-opus-5-5-medium vs gpt-6-luna-max | 1/2 = 50.0% | 64.6% | -14.6 | -24.0 to -1.8 |
| claude-opus-5-5-medium vs gpt-6-luna-medium | 16/20 = 80.0% | 86.5% | -6.5 | -28.3 to +12.4 |
| claude-opus-5-5-medium vs gpt-6-luna-off/low | 2/2 = 100.0% | 91.1% | +8.9 | +6.0 to +12.1 |
| claude-opus-5-5-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 62.4% | -12.4 | -22.3 to -1.3 |
| claude-opus-5-5-medium vs gpt-6.1-sol-high | 2/2 = 100.0% | 53.1% | +46.9 | +36.1 to +56.8 |
| claude-opus-5-5-medium vs gpt-6.1-sol-low | 1/2 = 50.0% | 48.9% | +1.1 | -10.5 to +12.8 |
| claude-opus-5-5-medium vs gpt-6.1-sol-max | 1/2 = 50.0% | 41.5% | +8.5 | -0.4 to +17.2 |
| claude-opus-5-5-medium vs gpt-6.1-sol-medium | 12/20 = 60.0% | 52.0% | +8.0 | -11.1 to +26.3 |
| claude-opus-5-5-medium vs gpt-6.1-sol-xhigh | 2/4 = 50.0% | 49.5% | +0.5 | -9.9 to +11.3 |
| claude-opus-5-5-medium vs gpt-6.1-terra-high | 0/3 = 0.0% | 51.8% | -51.8 | -64.1 to -37.8 |
| claude-opus-5-5-medium vs gpt-6.1-terra-max | 1/4 = 25.0% | 35.7% | -10.7 | -43.1 to +56.1 |
| claude-opus-5-5-medium vs gpt-6.1-terra-medium | 2/3 = 66.7% | 44.0% | +22.6 | -0.4 to +62.3 |
| claude-opus-5-5-medium vs gpt-6.1-terra-off/low | 4/7 = 57.1% | 53.9% | +3.2 | -35.4 to +44.6 |
| claude-opus-5-5-medium vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 41.1% | -7.8 | -47.8 to +60.7 |
| claude-opus-5-5-off/low vs claude-sonnet-5-5-high | 4/7 = 57.1% | 51.5% | +5.6 | -34.7 to +46.5 |
| claude-opus-5-5-off/low vs claude-sonnet-5-5-low | 4/5 = 80.0% | 65.6% | +14.4 | -32.5 to +41.8 |
| claude-opus-5-5-off/low vs claude-sonnet-5-5-medium | 5/7 = 71.4% | 54.8% | +16.6 | -15.2 to +48.8 |
| claude-opus-5-5-off/low vs claude-sonnet-5-5-off | 3/7 = 42.9% | 58.4% | -15.5 | -62.0 to +24.9 |
| claude-opus-5-5-off/low vs claude-sonnet-5-5-xhigh | 2/7 = 28.6% | 38.2% | -9.6 | -41.4 to +28.1 |
| claude-opus-5-5-off/low vs gpt-5.6-terra-medium | 0/2 = 0.0% | 63.7% | -63.7 | -72.2 to -52.5 |
| claude-opus-5-5-off/low vs gpt-6-astra-high | 1/2 = 50.0% | 31.6% | +18.4 | -38.2 to +74.4 |
| claude-opus-5-5-off/low vs gpt-6-astra-low | 1/2 = 50.0% | 39.1% | +10.9 | -45.7 to +68.4 |
| claude-opus-5-5-off/low vs gpt-6-astra-off | 0/2 = 0.0% | 41.9% | -41.9 | -54.8 to -27.5 |
| claude-opus-5-5-off/low vs gpt-6-luna-medium | 2/2 = 100.0% | 83.6% | +16.4 | +11.2 to +22.5 |
| claude-opus-5-5-off/low vs gpt-6-luna-xhigh | 1/2 = 50.0% | 56.9% | -6.9 | -18.8 to +5.5 |
| claude-opus-5-5-off/low vs gpt-6.1-terra-max | 0/2 = 0.0% | 30.6% | -30.6 | -42.1 to -20.1 |
| claude-opus-5-5-off/low vs gpt-6.1-terra-medium | 1/1 = 100.0% | 38.5% | +61.5 | +49.4 to +71.5 |
| claude-opus-5-5-off/low vs gpt-6.1-terra-off/low | 2/2 = 100.0% | 48.1% | +51.9 | +41.0 to +61.8 |
| claude-opus-5-5-off/low vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 35.7% | +14.3 | -42.9 to +70.3 |
| claude-opus-5-5-xhigh vs claude-sonnet-5-5-max | 2/10 = 20.0% | 47.2% | -27.2 | -51.9 to -1.9 |
| claude-opus-5-5-xhigh vs gpt-6-astra-high | 2/4 = 50.0% | 46.2% | +3.8 | -49.6 to +56.7 |
| claude-opus-5-5-xhigh vs gpt-6-astra-low | 2/4 = 50.0% | 54.4% | -4.4 | -57.6 to +48.3 |
| claude-opus-5-5-xhigh vs gpt-6-astra-medium | 22/41 = 53.7% | 50.3% | +3.4 | -8.7 to +15.0 |
| claude-opus-5-5-xhigh vs gpt-6-astra-off | 2/4 = 50.0% | 57.3% | -7.3 | -60.3 to +46.8 |
| claude-opus-5-5-xhigh vs gpt-6.1-sol-max | 4/10 = 40.0% | 51.2% | -11.2 | -35.4 to +4.2 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-high | 1/3 = 33.3% | 61.3% | -28.0 | -68.6 to +38.6 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-max | 5/5 = 100.0% | 45.0% | +55.0 | +41.9 to +68.1 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-medium | 2/3 = 66.7% | 53.7% | +12.9 | -54.7 to +53.2 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-off/low | 4/6 = 66.7% | 63.3% | +3.4 | -39.7 to +39.8 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 50.8% | -17.4 | -59.0 to +50.7 |
| claude-sonnet-5-5-high vs gpt-5.6-terra-medium | 1/2 = 50.0% | 62.3% | -12.3 | -21.7 to -0.9 |
| claude-sonnet-5-5-high vs gpt-6-astra-high | 2/4 = 50.0% | 30.3% | +19.7 | -31.8 to +73.1 |
| claude-sonnet-5-5-high vs gpt-6-astra-low | 2/4 = 50.0% | 37.7% | +12.3 | -39.7 to +65.6 |
| claude-sonnet-5-5-high vs gpt-6-astra-medium | 2/2 = 100.0% | 33.9% | +66.1 | +54.9 to +73.9 |
| claude-sonnet-5-5-high vs gpt-6-astra-off | 0/4 = 0.0% | 40.5% | -40.5 | -53.3 to -27.0 |
| claude-sonnet-5-5-high vs gpt-6-luna-medium | 1/2 = 50.0% | 82.7% | -32.7 | -37.9 to -25.6 |
| claude-sonnet-5-5-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 44.8% | -44.8 | -54.4 to -33.6 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-high | 3/3 = 100.0% | 44.5% | +55.5 | +41.0 to +69.3 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-max | 1/4 = 25.0% | 29.4% | -4.4 | -37.0 to +65.3 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-medium | 1/3 = 33.3% | 37.1% | -3.7 | -44.4 to +63.8 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-off/low | 2/7 = 28.6% | 46.6% | -18.1 | -50.6 to +19.3 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 34.3% | -34.3 | -46.6 to -23.1 |
| claude-sonnet-5-5-low vs gpt-6-astra-high | 0/4 = 0.0% | 19.5% | -19.5 | -28.6 to -12.1 |
| claude-sonnet-5-5-low vs gpt-6-astra-low | 0/4 = 0.0% | 25.2% | -25.2 | -36.7 to -15.2 |
| claude-sonnet-5-5-low vs gpt-6-astra-medium | 0/2 = 0.0% | 22.2% | -22.2 | -29.4 to -15.0 |
| claude-sonnet-5-5-low vs gpt-6-astra-off | 0/4 = 0.0% | 27.4% | -27.4 | -39.1 to -16.7 |
| claude-sonnet-5-5-low vs gpt-6-luna-medium | 1/2 = 50.0% | 72.7% | -22.7 | -30.4 to -12.6 |
| claude-sonnet-5-5-low vs gpt-6.1-sol-medium | 1/2 = 50.0% | 31.1% | +18.9 | +9.6 to +27.5 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-high | 1/4 = 25.0% | 30.9% | -5.9 | -39.2 to +59.3 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-max | 1/3 = 33.3% | 18.8% | +14.6 | -24.6 to +84.2 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-medium | 1/4 = 25.0% | 24.7% | +0.3 | -31.5 to +27.5 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-off/low | 3/8 = 37.5% | 32.7% | +4.8 | -30.0 to +50.4 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-xhigh | 1/4 = 25.0% | 22.5% | +2.5 | -28.3 to +72.2 |
| claude-sonnet-5-5-max vs gpt-6-astra-medium | 4/10 = 40.0% | 53.1% | -13.1 | -38.0 to +3.2 |
| claude-sonnet-5-5-max vs gpt-6-luna-medium | 2/2 = 100.0% | 91.4% | +8.6 | +5.5 to +12.7 |
| claude-sonnet-5-5-max vs gpt-6.1-sol-max | 6/10 = 60.0% | 54.0% | +6.0 | -10.9 to +29.4 |
| claude-sonnet-5-5-max vs gpt-6.1-sol-medium | 2/2 = 100.0% | 64.2% | +35.8 | +25.7 to +45.1 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-high | 1/2 = 50.0% | 61.6% | -11.6 | -22.5 to +0.6 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.0% | -14.0 | -24.9 to -2.0 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-medium | 11/20 = 55.0% | 59.2% | -4.2 | -28.1 to +19.8 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-xhigh | 0/2 = 0.0% | 50.0% | -50.0 | -61.5 to -36.5 |
| claude-sonnet-5-5-medium vs gpt-6-astra-high | 3/4 = 75.0% | 27.6% | +47.4 | -26.1 to +78.1 |
| claude-sonnet-5-5-medium vs gpt-6-astra-low | 1/4 = 25.0% | 34.6% | -9.6 | -42.0 to +66.6 |
| claude-sonnet-5-5-medium vs gpt-6-astra-medium | 7/20 = 35.0% | 31.0% | +4.0 | -10.8 to +17.5 |
| claude-sonnet-5-5-medium vs gpt-6-astra-off | 2/4 = 50.0% | 37.3% | +12.7 | -40.2 to +65.5 |
| claude-sonnet-5-5-medium vs gpt-6-luna-medium | 17/20 = 85.0% | 80.7% | +4.3 | -10.6 to +18.2 |
| claude-sonnet-5-5-medium vs gpt-6-luna-off/low | 4/4 = 100.0% | 87.0% | +13.0 | +9.1 to +17.3 |
| claude-sonnet-5-5-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 52.1% | -2.1 | -13.0 to +9.1 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 42.6% | +7.4 | -4.1 to +17.1 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-low | 1/2 = 50.0% | 38.5% | +11.5 | -0.0 to +21.4 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-max | 0/2 = 0.0% | 31.7% | -31.7 | -39.7 to -23.7 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-medium | 8/20 = 40.0% | 41.5% | -1.5 | -19.7 to +17.0 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 39.0% | +11.0 | -0.4 to +20.4 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-high | 0/4 = 0.0% | 41.3% | -41.3 | -53.9 to -28.0 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-max | 1/4 = 25.0% | 26.7% | -1.7 | -33.1 to +70.2 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-medium | 1/4 = 25.0% | 34.0% | -9.0 | -41.3 to +60.9 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-off/low | 4/8 = 50.0% | 43.3% | +6.7 | -32.0 to +45.0 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-xhigh | 3/4 = 75.0% | 31.4% | +43.6 | -25.1 to +75.3 |
| claude-sonnet-5-5-off vs gpt-5.6-terra-medium | 1/2 = 50.0% | 55.6% | -5.6 | -15.4 to +4.5 |
| claude-sonnet-5-5-off vs gpt-6-astra-high | 0/4 = 0.0% | 24.8% | -24.8 | -35.1 to -16.2 |
| claude-sonnet-5-5-off vs gpt-6-astra-low | 1/4 = 25.0% | 31.4% | -6.4 | -38.6 to +61.8 |
| claude-sonnet-5-5-off vs gpt-6-astra-medium | 2/2 = 100.0% | 27.9% | +72.1 | +62.5 to +78.9 |
| claude-sonnet-5-5-off vs gpt-6-astra-off | 1/4 = 25.0% | 33.9% | -8.9 | -41.6 to +59.0 |
| claude-sonnet-5-5-off vs gpt-6-luna-medium | 2/2 = 100.0% | 78.4% | +21.6 | +15.3 to +29.2 |
| claude-sonnet-5-5-off vs gpt-6.1-sol-medium | 1/2 = 50.0% | 38.0% | +12.0 | +2.3 to +20.9 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-high | 0/4 = 0.0% | 37.8% | -37.8 | -51.5 to -24.9 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-max | 1/4 = 25.0% | 23.9% | +1.1 | -30.1 to +68.7 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-medium | 0/4 = 0.0% | 30.8% | -30.8 | -42.0 to -22.0 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-off/low | 2/8 = 25.0% | 39.8% | -14.8 | -43.1 to +20.1 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-xhigh | 1/4 = 25.0% | 28.3% | -3.3 | -35.0 to +65.1 |
| claude-sonnet-5-5-xhigh vs gpt-5.6-terra-medium | 2/2 = 100.0% | 74.0% | +26.0 | +18.5 to +34.5 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-high | 1/4 = 25.0% | 42.8% | -17.8 | -51.2 to +47.3 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-low | 3/4 = 75.0% | 50.9% | +24.1 | -36.8 to +58.6 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-medium | 1/2 = 50.0% | 46.8% | +3.2 | -6.9 to +13.0 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-off | 4/4 = 100.0% | 53.8% | +46.2 | +34.0 to +60.4 |
| claude-sonnet-5-5-xhigh vs gpt-6-luna-medium | 2/2 = 100.0% | 89.2% | +10.8 | +7.3 to +15.0 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-sol-medium | 1/2 = 50.0% | 58.2% | -8.2 | -17.1 to +1.5 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-high | 2/3 = 66.7% | 57.9% | +8.7 | -59.7 to +50.7 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-max | 2/4 = 50.0% | 41.6% | +8.4 | -43.9 to +61.3 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-medium | 2/3 = 66.7% | 50.3% | +16.4 | -50.5 to +56.5 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-off/low | 5/7 = 71.4% | 60.0% | +11.4 | -26.2 to +42.8 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-xhigh | 2/3 = 66.7% | 47.3% | +19.4 | -4.4 to +61.4 |
| gpt-5.6-terra-high vs gpt-6-astra-off | 0/1 = 0.0% | 27.1% | -27.1 | -39.8 to -15.4 |
| gpt-5.6-terra-high vs gpt-6-luna-medium | 1/2 = 50.0% | 72.3% | -22.3 | -31.2 to -10.6 |
| gpt-5.6-terra-high vs gpt-6.1-sol-medium | 1/2 = 50.0% | 30.7% | +19.3 | +7.4 to +28.2 |
| gpt-5.6-terra-low vs gpt-6-astra-medium | 0/2 = 0.0% | 20.2% | -20.2 | -28.7 to -12.6 |
| gpt-5.6-terra-low vs gpt-6.1-terra-high | 0/1 = 0.0% | 28.4% | -28.4 | -42.1 to -15.8 |
| gpt-5.6-terra-max vs gpt-6-astra-medium | 1/2 = 50.0% | 30.4% | +19.6 | +6.3 to +29.3 |
| gpt-5.6-terra-max vs gpt-6-luna-medium | 2/2 = 100.0% | 80.3% | +19.7 | +11.6 to +29.2 |
| gpt-5.6-terra-medium vs gpt-6-astra-medium | 5/20 = 25.0% | 23.6% | +1.4 | -14.2 to +16.3 |
| gpt-5.6-terra-medium vs gpt-6-astra-off | 0/1 = 0.0% | 29.1% | -29.1 | -40.4 to -18.7 |
| gpt-5.6-terra-medium vs gpt-6-luna-high | 2/2 = 100.0% | 50.5% | +49.5 | +38.6 to +58.9 |
| gpt-5.6-terra-medium vs gpt-6-luna-max | 2/2 = 100.0% | 45.2% | +54.8 | +41.7 to +66.2 |
| gpt-5.6-terra-medium vs gpt-6-luna-medium | 15/20 = 75.0% | 74.3% | +0.7 | -21.2 to +20.1 |
| gpt-5.6-terra-medium vs gpt-6-luna-off/low | 3/4 = 75.0% | 82.2% | -7.2 | -36.4 to +21.1 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-high | 0/2 = 0.0% | 33.8% | -33.8 | -43.5 to -24.0 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-low | 0/2 = 0.0% | 30.2% | -30.2 | -40.7 to -20.7 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-max | 0/2 = 0.0% | 24.3% | -24.3 | -31.9 to -17.3 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-medium | 6/20 = 30.0% | 32.9% | -2.9 | -18.6 to +12.1 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 30.7% | -30.7 | -40.3 to -21.5 |
| gpt-5.6-terra-medium vs gpt-6.1-terra-off/low | 0/1 = 0.0% | 34.6% | -34.6 | -43.2 to -26.5 |
| gpt-5.6-terra-medium vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 24.0% | -24.0 | -33.2 to -15.5 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-high | 1/1 = 100.0% | 27.6% | +72.4 | +57.5 to +82.4 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-low | 1/1 = 100.0% | 34.6% | +65.4 | +48.1 to +77.8 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-medium | 0/2 = 0.0% | 31.0% | -31.0 | -42.1 to -21.0 |
| gpt-5.6-terra-xhigh vs gpt-6.1-sol-medium | 0/2 = 0.0% | 41.5% | -41.5 | -53.9 to -29.1 |
| gpt-5.6-terra-xhigh vs gpt-6.1-terra-off/low | 0/1 = 0.0% | 43.3% | -43.3 | -56.9 to -30.6 |
| gpt-6-astra-high vs gpt-6.1-sol-high | 1/1 = 100.0% | 66.0% | +34.0 | +21.5 to +46.8 |
| gpt-6-astra-high vs gpt-6.1-sol-medium | 1/2 = 50.0% | 65.1% | -15.1 | -25.0 to -4.0 |
| gpt-6-astra-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 64.8% | +35.2 | +21.5 to +50.5 |
| gpt-6-astra-high vs gpt-6.1-terra-max | 1/2 = 50.0% | 48.8% | +1.2 | -56.4 to +59.7 |
| gpt-6-astra-high vs gpt-6.1-terra-medium | 0/1 = 0.0% | 57.5% | -57.5 | -70.4 to -43.6 |
| gpt-6-astra-high vs gpt-6.1-terra-off/low | 3/3 = 100.0% | 66.7% | +33.3 | +22.7 to +44.3 |
| gpt-6-astra-high vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 54.5% | -54.5 | -68.5 to -39.7 |
| gpt-6-astra-low vs gpt-6-luna-medium | 2/2 = 100.0% | 88.8% | +11.2 | +6.8 to +16.8 |
| gpt-6-astra-low vs gpt-6.1-sol-low | 0/1 = 0.0% | 54.2% | -54.2 | -67.6 to -38.3 |
| gpt-6-astra-low vs gpt-6.1-sol-medium | 1/2 = 50.0% | 57.3% | -7.3 | -19.1 to +4.5 |
| gpt-6-astra-low vs gpt-6.1-terra-high | 1/1 = 100.0% | 57.0% | +43.0 | +27.4 to +58.9 |
| gpt-6-astra-low vs gpt-6.1-terra-max | 0/2 = 0.0% | 40.7% | -40.7 | -55.7 to -27.1 |
| gpt-6-astra-low vs gpt-6.1-terra-medium | 1/1 = 100.0% | 49.3% | +50.7 | +35.2 to +63.4 |
| gpt-6-astra-low vs gpt-6.1-terra-off/low | 0/2 = 0.0% | 59.1% | -59.1 | -71.0 to -47.1 |
| gpt-6-astra-low vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 46.4% | +53.6 | +37.6 to +67.5 |
| gpt-6-astra-medium vs gpt-6-luna-high | 1/2 = 50.0% | 76.7% | -26.7 | -32.8 to -18.0 |
| gpt-6-astra-medium vs gpt-6-luna-max | 2/2 = 100.0% | 72.7% | +27.3 | +18.3 to +37.5 |
| gpt-6-astra-medium vs gpt-6-luna-medium | 19/20 = 95.0% | 90.3% | +4.7 | -6.7 to +11.8 |
| gpt-6-astra-medium vs gpt-6-luna-off/low | 2/2 = 100.0% | 93.7% | +6.3 | +4.2 to +8.8 |
| gpt-6-astra-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 70.8% | -20.8 | -29.1 to -10.1 |
| gpt-6-astra-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 62.3% | -12.3 | -21.9 to -1.7 |
| gpt-6-astra-medium vs gpt-6.1-sol-low | 3/4 = 75.0% | 58.3% | +16.7 | -14.5 to +48.1 |
| gpt-6-astra-medium vs gpt-6.1-sol-max | 6/10 = 60.0% | 50.9% | +9.1 | -6.1 to +29.2 |
| gpt-6-astra-medium vs gpt-6.1-sol-medium | 12/20 = 60.0% | 61.3% | -1.3 | -20.6 to +17.6 |
| gpt-6-astra-medium vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 58.8% | -58.8 | -67.4 to -46.7 |
| gpt-6-astra-medium vs gpt-6.1-terra-max | 0/1 = 0.0% | 44.8% | -44.8 | -55.7 to -31.9 |
| gpt-6-astra-off vs gpt-6-luna-xhigh | 1/1 = 100.0% | 64.6% | +35.4 | +22.1 to +48.9 |
| gpt-6-astra-off vs gpt-6.1-sol-medium | 0/1 = 0.0% | 54.4% | -54.4 | -67.4 to -41.6 |
| gpt-6-astra-off vs gpt-6.1-terra-high | 1/1 = 100.0% | 54.2% | +45.8 | +29.4 to +61.7 |
| gpt-6-astra-off vs gpt-6.1-terra-max | 0/1 = 0.0% | 37.9% | -37.9 | -53.3 to -24.2 |
| gpt-6-astra-off vs gpt-6.1-terra-medium | 0/1 = 0.0% | 46.4% | -46.4 | -61.0 to -32.9 |
| gpt-6-astra-off vs gpt-6.1-terra-off/low | 3/3 = 100.0% | 56.3% | +43.7 | +30.4 to +56.1 |
| gpt-6-astra-off vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 43.5% | +6.5 | -51.9 to +63.0 |
| gpt-6-luna-high vs gpt-6.1-sol-medium | 1/2 = 50.0% | 32.4% | +17.6 | +8.5 to +26.2 |
| gpt-6-luna-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 32.2% | +67.8 | +53.8 to +79.1 |
| gpt-6-luna-high vs gpt-6.1-terra-off/low | 0/1 = 0.0% | 34.1% | -34.1 | -43.2 to -25.5 |
| gpt-6-luna-max vs gpt-6.1-sol-medium | 0/2 = 0.0% | 37.3% | -37.3 | -48.0 to -26.1 |
| gpt-6-luna-max vs gpt-6.1-terra-off/low | 1/2 = 50.0% | 39.1% | +10.9 | -1.5 to +21.6 |
| gpt-6-luna-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 15.0% | +35.0 | +27.5 to +39.8 |
| gpt-6-luna-medium vs gpt-6.1-sol-low | 0/2 = 0.0% | 13.0% | -13.0 | -19.3 to -8.2 |
| gpt-6-luna-medium vs gpt-6.1-sol-max | 0/2 = 0.0% | 10.0% | -10.0 | -13.7 to -6.7 |
| gpt-6-luna-medium vs gpt-6.1-sol-medium | 3/20 = 15.0% | 14.5% | +0.5 | -13.4 to +15.5 |
| gpt-6-luna-medium vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 13.3% | -13.3 | -19.3 to -8.7 |
| gpt-6-luna-off/low vs gpt-6.1-sol-medium | 1/4 = 25.0% | 9.6% | +15.4 | -11.5 to +42.2 |
| gpt-6-luna-xhigh vs gpt-6.1-sol-medium | 1/2 = 50.0% | 39.5% | +10.5 | -1.4 to +20.6 |
| gpt-6-luna-xhigh vs gpt-6.1-terra-off/low | 1/2 = 50.0% | 41.3% | +8.7 | -3.7 to +19.3 |
| gpt-6.1-sol-high vs gpt-6.1-terra-medium | 1/2 = 50.0% | 41.0% | +9.0 | -4.3 to +21.1 |
| gpt-6.1-sol-low vs gpt-6.1-terra-max | 1/1 = 100.0% | 36.7% | +63.3 | +47.4 to +76.0 |
| gpt-6.1-sol-max vs gpt-6.1-terra-max | 1/2 = 50.0% | 43.9% | +6.1 | -6.7 to +18.3 |
| gpt-6.1-sol-medium vs gpt-6.1-terra-max | 1/1 = 100.0% | 33.9% | +66.1 | +54.5 to +76.6 |
| gpt-6.1-sol-medium vs gpt-6.1-terra-medium | 1/2 = 50.0% | 42.1% | +7.9 | -2.9 to +18.0 |
| gpt-6.1-sol-medium vs gpt-6.1-terra-off/low | 1/1 = 100.0% | 51.9% | +48.1 | +38.9 to +57.0 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-high | 1/2 = 50.0% | 52.3% | -2.3 | -16.7 to +12.6 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-max | 0/1 = 0.0% | 36.2% | -36.2 | -50.2 to -23.5 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 41.7% | +8.3 | -5.0 to +20.9 |
#### claude-haiku-4-5-20251001 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-medium | 11/20 = 55.0% | 37.2% | +17.8 | +2.0 to +36.0 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal/low | 19/40 = 47.5% | 43.7% | +3.8 | -7.1 to +15.0 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 65.0% | -0.0 | -18.0 to +17.5 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-4-5-20251001-minimal/low | 22/40 = 55.0% | 56.7% | -1.7 | -13.7 to +9.6 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 75.8% | +4.2 | -11.6 to +18.5 |
| claude-haiku-4-5-20251001-minimal/low vs claude-haiku-4-5-20251001-minimal/low | 20/40 = 50.0% | 50.0% | +0.0 | +0.0 to +0.0 |
| claude-haiku-4-5-20251001-minimal/low vs claude-haiku-4-5-20251001-off | 28/40 = 70.0% | 70.6% | -0.6 | -11.6 to +10.1 |
#### claude-haiku-5-5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 56.5% | +8.5 | -11.7 to +28.4 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 44.6% | +0.4 | -20.4 to +21.3 |
| claude-haiku-5-5-high vs claude-haiku-5-5-medium | 13/20 = 65.0% | 52.5% | +12.5 | -2.3 to +28.8 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 73.6% | -8.6 | -22.5 to +6.5 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 46.3% | -16.3 | -32.9 to -1.4 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 38.3% | -3.3 | -21.4 to +15.2 |
| claude-haiku-5-5-low vs claude-haiku-5-5-medium | 12/20 = 60.0% | 46.0% | +14.0 | -4.8 to +33.5 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 68.2% | -13.2 | -36.8 to +7.0 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 39.9% | +0.1 | -14.6 to +12.6 |
| claude-haiku-5-5-max vs claude-haiku-5-5-medium | 11/20 = 55.0% | 57.9% | -2.9 | -17.8 to +14.6 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 77.6% | +2.4 | -13.2 to +16.8 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 51.7% | -6.7 | -24.4 to +9.6 |
| claude-haiku-5-5-medium vs claude-haiku-5-5-off | 14/20 = 70.0% | 71.6% | -1.6 | -16.4 to +13.8 |
| claude-haiku-5-5-medium vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 43.8% | -8.8 | -27.2 to +10.6 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 23.7% | +1.3 | -18.1 to +24.0 |
#### claude-opus-5-5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5-high vs claude-opus-5-5-max | 1/2 = 50.0% | 38.5% | +11.5 | -46.4 to +69.3 |
| claude-opus-5-5-high vs claude-opus-5-5-medium | 11/20 = 55.0% | 57.7% | -2.7 | -22.0 to +16.7 |
| claude-opus-5-5-high vs claude-opus-5-5-off/low | 4/7 = 57.1% | 63.2% | -6.0 | -45.4 to +32.9 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 48.0% | -13.0 | -31.8 to +5.0 |
| claude-opus-5-5-max vs claude-opus-5-5-medium | 6/10 = 60.0% | 68.5% | -8.5 | -45.0 to +25.4 |
| claude-opus-5-5-max vs claude-opus-5-5-off/low | 9/12 = 75.0% | 73.3% | +1.7 | -29.6 to +27.4 |
| claude-opus-5-5-max vs claude-opus-5-5-xhigh | 5/10 = 50.0% | 59.6% | -9.6 | -39.5 to +17.6 |
| claude-opus-5-5-medium vs claude-opus-5-5-off/low | 16/24 = 66.7% | 55.7% | +10.9 | -1.7 to +25.4 |
| claude-opus-5-5-medium vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 40.4% | -5.4 | -20.5 to +8.7 |
| claude-opus-5-5-off/low vs claude-opus-5-5-off/low | 5/10 = 50.0% | 50.0% | +0.0 | +0.0 to +0.0 |
| claude-opus-5-5-off/low vs claude-opus-5-5-xhigh | 3/7 = 42.9% | 35.0% | +7.9 | -31.4 to +48.7 |
#### claude-sonnet-5-5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 64.3% | -9.3 | -32.8 to +14.4 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 31.2% | +8.8 | -12.3 to +30.6 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-medium | 13/20 = 65.0% | 53.3% | +11.7 | -8.9 to +31.9 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 56.9% | +13.1 | -2.4 to +29.9 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 36.8% | -11.8 | -32.2 to +9.5 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 20.1% | -5.1 | -19.5 to +9.7 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-medium | 9/20 = 45.0% | 38.8% | +6.2 | -14.5 to +27.0 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 42.4% | +7.6 | -10.2 to +26.6 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 24.5% | -4.5 | -19.7 to +10.5 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-medium | 12/20 = 60.0% | 71.6% | -11.6 | -30.1 to +6.7 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 74.5% | -4.5 | -29.0 to +16.8 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 56.3% | +8.7 | -9.3 to +27.4 |
| claude-sonnet-5-5-medium vs claude-sonnet-5-5-off | 10/20 = 50.0% | 53.6% | -3.6 | -23.2 to +14.3 |
| claude-sonnet-5-5-medium vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 33.8% | +11.2 | -9.2 to +32.7 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 30.6% | +24.4 | +13.8 to +38.0 |
#### gpt-5.6-terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 52.5% | -7.5 | -26.4 to +11.2 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.1% | +0.9 | -15.0 to +18.7 |
| gpt-5.6-terra-high vs gpt-5.6-terra-medium | 10/20 = 50.0% | 47.5% | +2.5 | -12.1 to +17.8 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 38.4% | +11.6 | -8.2 to +32.5 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 36.7% | +3.3 | -15.4 to +23.0 |
| gpt-5.6-terra-low vs gpt-5.6-terra-medium | 9/20 = 45.0% | 44.9% | +0.1 | -15.4 to +16.1 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 36.0% | -16.0 | -31.9 to -1.0 |
| gpt-5.6-terra-max vs gpt-5.6-terra-medium | 12/20 = 60.0% | 58.5% | +1.5 | -18.9 to +21.1 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 49.3% | +5.7 | -9.8 to +23.2 |
| gpt-5.6-terra-medium vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 40.8% | -5.8 | -21.6 to +8.8 |
#### gpt-6-astra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-astra-high vs gpt-6-astra-low | 2/2 = 100.0% | 58.1% | +41.9 | +27.7 to +56.8 |
| gpt-6-astra-high vs gpt-6-astra-medium | 1/2 = 50.0% | 54.1% | -4.1 | -15.5 to +7.1 |
| gpt-6-astra-high vs gpt-6-astra-off | 0/1 = 0.0% | 60.9% | -60.9 | -73.6 to -45.0 |
| gpt-6-astra-low vs gpt-6-astra-medium | 0/2 = 0.0% | 45.9% | -45.9 | -57.8 to -33.6 |
| gpt-6-astra-low vs gpt-6-astra-off | 2/2 = 100.0% | 52.9% | +47.1 | +31.4 to +63.4 |
#### gpt-6-luna efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 44.7% | -9.7 | -30.2 to +13.5 |
| gpt-6-luna-high vs gpt-6-luna-medium | 12/20 = 60.0% | 73.9% | -13.9 | -37.2 to +8.9 |
| gpt-6-luna-high vs gpt-6-luna-off/low | 32/40 = 80.0% | 81.9% | -1.9 | -13.0 to +8.2 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 42.4% | +12.6 | -5.8 to +33.3 |
| gpt-6-luna-max vs gpt-6-luna-medium | 15/20 = 75.0% | 77.8% | -2.8 | -18.9 to +12.9 |
| gpt-6-luna-max vs gpt-6-luna-off/low | 34/40 = 85.0% | 84.9% | +0.1 | -8.4 to +9.2 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 47.7% | +2.3 | -12.3 to +16.1 |
| gpt-6-luna-medium vs gpt-6-luna-off/low | 24/40 = 60.0% | 61.5% | -1.5 | -16.3 to +13.2 |
| gpt-6-luna-medium vs gpt-6-luna-xhigh | 2/20 = 10.0% | 20.6% | -10.6 | -23.0 to +2.7 |
| gpt-6-luna-off/low vs gpt-6-luna-off/low | 20/40 = 50.0% | 50.0% | +0.0 | +0.0 to +0.0 |
| gpt-6-luna-off/low vs gpt-6-luna-xhigh | 5/40 = 12.5% | 14.0% | -1.5 | -10.7 to +9.1 |
#### gpt-6.1-sol efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 45.8% | +14.2 | -1.0 to +31.8 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 38.6% | +6.4 | -12.6 to +26.3 |
| gpt-6.1-sol-high vs gpt-6.1-sol-medium | 8/20 = 40.0% | 48.9% | -8.9 | -23.0 to +3.4 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 46.4% | -1.4 | -16.9 to +14.0 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 42.6% | -12.6 | -31.5 to +5.0 |
| gpt-6.1-sol-low vs gpt-6.1-sol-medium | 13/20 = 65.0% | 53.1% | +11.9 | -5.8 to +30.4 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 50.5% | +9.5 | -7.4 to +27.8 |
| gpt-6.1-sol-max vs gpt-6.1-sol-medium | 12/20 = 60.0% | 60.4% | -0.4 | -18.9 to +18.1 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 57.9% | -7.9 | -22.1 to +5.4 |
| gpt-6.1-sol-medium vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 47.4% | +2.6 | -18.4 to +24.3 |
#### gpt-6.1-terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-terra-high vs gpt-6.1-terra-max | 0/1 = 0.0% | 34.1% | -34.1 | -50.3 to -21.2 |
| gpt-6.1-terra-high vs gpt-6.1-terra-medium | 2/3 = 66.7% | 42.3% | +24.4 | -1.7 to +66.7 |
| gpt-6.1-terra-high vs gpt-6.1-terra-off/low | 1/3 = 33.3% | 52.1% | -18.8 | -61.0 to +49.4 |
| gpt-6.1-terra-high vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 39.4% | -6.1 | -47.0 to +67.2 |
| gpt-6.1-terra-max vs gpt-6.1-terra-medium | 1/1 = 100.0% | 58.6% | +41.4 | +27.8 to +54.1 |
| gpt-6.1-terra-max vs gpt-6.1-terra-off/low | 0/2 = 0.0% | 67.8% | -67.8 | -77.3 to -55.9 |
| gpt-6.1-terra-max vs gpt-6.1-terra-xhigh | 3/3 = 100.0% | 55.7% | +44.3 | +30.7 to +58.1 |
| gpt-6.1-terra-medium vs gpt-6.1-terra-off/low | 4/6 = 66.7% | 59.8% | +6.9 | -13.3 to +44.2 |
| gpt-6.1-terra-medium vs gpt-6.1-terra-xhigh | 3/3 = 100.0% | 47.0% | +53.0 | +39.1 to +65.7 |
| gpt-6.1-terra-off/low vs gpt-6.1-terra-off/low | 3/6 = 50.0% | 50.0% | +0.0 | +0.0 to +0.0 |
| gpt-6.1-terra-off/low vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 37.4% | -37.4 | -49.2 to -26.9 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| Cross-model | 0.5983 | 0.5983 | -0.0000 | -0.0000 to -0.0000 | 0: 49, 0.1: 1 | tau=0.1: 0.5984, tau=0.2: 0.5989, tau=0.4: 0.6007, tau=0.8: 0.6061, tau=1.6: 0.6195 | not kept |
| Cross-model (seat and starter terms) | 0.5936 | 0.5937 | -0.0000 | -0.0000 to -0.0000 | 0: 48, 0.1: 2 | tau=0.1: 0.5938, tau=0.2: 0.5942, tau=0.4: 0.5959, tau=0.8: 0.6012, tau=1.6: 0.6145 | not kept |
| claude-haiku-4-5-20251001 efforts | 0.6655 | 0.6655 | -0.0000 | -0.0001 to +0.0000 | 0: 49, 0.1: 1 | tau=0.1: 0.6659, tau=0.2: 0.6667, tau=0.4: 0.6688, tau=0.8: 0.6716, tau=1.6: 0.6737 | not kept |
| claude-haiku-4-5-20251001 efforts (seat and starter terms) | 0.6687 | 0.6695 | -0.0009 | -0.0020 to -0.0000 | 0: 45, 0.1: 1, 0.2: 1, 0.4: 3 | tau=0.1: 0.6691, tau=0.2: 0.6703, tau=0.4: 0.6734, tau=0.8: 0.6774, tau=1.6: 0.6801 | not kept |
| claude-haiku-5-5 efforts | 0.6614 | 0.6618 | -0.0004 | -0.0009 to +0.0000 | 0: 46, 0.1: 1, 0.2: 2, 0.4: 1 | tau=0.1: 0.6617, tau=0.2: 0.6629, tau=0.4: 0.6671, tau=0.8: 0.6758, tau=1.6: 0.6832 | not kept |
| claude-haiku-5-5 efforts (seat and starter terms) | 0.6398 | 0.6415 | -0.0017 | -0.0029 to -0.0008 | 0: 42, 0.1: 3, 0.2: 4, 0.8: 1 | tau=0.1: 0.6401, tau=0.2: 0.6411, tau=0.4: 0.6449, tau=0.8: 0.6529, tau=1.6: 0.6599 | not kept |
| claude-opus-5-5 efforts | 0.6839 | 0.6852 | -0.0013 | -0.0027 to -0.0002 | 0: 48, 0.2: 1, 0.4: 1 | tau=0.1: 0.6849, tau=0.2: 0.6878, tau=0.4: 0.6972, tau=0.8: 0.7183, tau=1.6: 0.7475 | not kept |
| claude-opus-5-5 efforts (seat and starter terms) | 0.6992 | 0.6992 | +0.0000 | +0.0000 to +0.0000 | 0: 50 | tau=0.1: 0.7001, tau=0.2: 0.7024, tau=0.4: 0.7101, tau=0.8: 0.7276, tau=1.6: 0.7526 | not kept |
| claude-sonnet-5-5 efforts | 0.6701 | 0.6725 | -0.0024 | -0.0080 to +0.0029 | 0: 11, 0.1: 4, 0.2: 16, 0.4: 18, 0.8: 1 | tau=0.1: 0.6697, tau=0.2: 0.6690, tau=0.4: 0.6695, tau=0.8: 0.6761, tau=1.6: 0.6849 | not kept |
| claude-sonnet-5-5 efforts (seat and starter terms) | 0.6731 | 0.6748 | -0.0017 | -0.0069 to +0.0031 | 0: 13, 0.1: 5, 0.2: 17, 0.4: 15 | tau=0.1: 0.6727, tau=0.2: 0.6719, tau=0.4: 0.6723, tau=0.8: 0.6786, tau=1.6: 0.6868 | not kept |
| gpt-5.6-terra efforts | 0.6886 | 0.6912 | -0.0026 | -0.0052 to -0.0005 | 0: 36, 0.1: 3, 0.2: 7, 0.4: 4 | tau=0.1: 0.6888, tau=0.2: 0.6892, tau=0.4: 0.6916, tau=0.8: 0.6973, tau=1.6: 0.7023 | not kept |
| gpt-5.6-terra efforts (seat and starter terms) | 0.6985 | 0.7007 | -0.0022 | -0.0047 to +0.0001 | 0: 39, 0.1: 1, 0.2: 7, 0.4: 2, 0.8: 1 | tau=0.1: 0.6988, tau=0.2: 0.6998, tau=0.4: 0.7037, tau=0.8: 0.7120, tau=1.6: 0.7193 | not kept |
| gpt-6-astra efforts | - | - | - | - | - | - | 7 seed blocks, under the minimum of 10: the fit with seat and starter terms can be singular on so few, so not tested |
| gpt-6-luna efforts | 0.5704 | 0.5774 | -0.0070 | -0.0114 to -0.0029 | 0: 31, 0.1: 3, 0.2: 5, 0.4: 6, 0.8: 5 | tau=0.1: 0.5709, tau=0.2: 0.5720, tau=0.4: 0.5755, tau=0.8: 0.5820, tau=1.6: 0.5899 | not kept |
| gpt-6-luna efforts (seat and starter terms) | 0.5794 | 0.5829 | -0.0035 | -0.0075 to -0.0001 | 0: 37, 0.2: 6, 0.4: 3, 0.8: 4 | tau=0.1: 0.5795, tau=0.2: 0.5800, tau=0.4: 0.5816, tau=0.8: 0.5857, tau=1.6: 0.5925 | not kept |
| gpt-6.1-sol efforts | 0.7042 | 0.7142 | -0.0100 | -0.0196 to -0.0016 | 0: 15, 0.1: 4, 0.2: 12, 0.4: 14, 0.8: 4, 1.6: 1 | tau=0.1: 0.7042, tau=0.2: 0.7045, tau=0.4: 0.7072, tau=0.8: 0.7151, tau=1.6: 0.7226 | not kept |
| gpt-6.1-sol efforts (seat and starter terms) | 0.7104 | 0.7169 | -0.0065 | -0.0139 to -0.0003 | 0: 19, 0.1: 6, 0.2: 11, 0.4: 13, 0.8: 1 | tau=0.1: 0.7103, tau=0.2: 0.7103, tau=0.4: 0.7121, tau=0.8: 0.7191, tau=1.6: 0.7259 | not kept |
| gpt-6.1-terra efforts | 0.8699 | 0.8281 | +0.0418 | -0.0835 to +0.1714 | 0: 2, 0.4: 1, 0.8: 8, 1.6: 39 | tau=0.1: 0.8685, tau=0.2: 0.8645, tau=0.4: 0.8498, tau=0.8: 0.8106, tau=1.6: 0.7724 | not kept |
| gpt-6.1-terra efforts (seat and starter terms) | 0.9543 | 0.8791 | +0.0752 | -0.0580 to +0.2041 | 0: 2, 0.2: 1, 0.4: 2, 0.8: 8, 1.6: 37 | tau=0.1: 0.9525, tau=0.2: 0.9472, tau=0.4: 0.9281, tau=0.8: 0.8762, tau=1.6: 0.8212 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| Cross-model | 204/394 = 51.8% | -0.11 |
| claude-haiku-4-5-20251001 efforts | 3/7 = 42.9% | -0.29 |
| claude-haiku-5-5 efforts | 5/15 = 33.3% | -0.45 |
| claude-opus-5-5 efforts | 1/11 = 9.1% | -0.81 |
| claude-sonnet-5-5 efforts | 6/15 = 40.0% | -0.04 |
| gpt-5.6-terra efforts | 4/10 = 40.0% | -0.15 |
| gpt-6-luna efforts | 4/11 = 36.4% | -0.19 |
| gpt-6.1-sol efforts | 6/10 = 60.0% | -0.18 |
| gpt-6.1-terra efforts | 5/7 = 71.4% | +0.76 |
| all cohorts pooled | 238/480 = 49.6% | -0.11 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 5.6e-17, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 4987 of 4987 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 2117 blocks, 767 seeds (753 matches in half blocks left out) | 2219/4234 = 52.4% | 47.9% to 57.1% | 51.0% to 53.9% |
| Cross-model: 1300 blocks, 757 seeds (710 matches in half blocks left out) | 1371/2600 = 52.7% | 49.1% to 56.8% | 50.9% to 54.5% |
| claude-haiku-4-5-20251001 efforts: 100 blocks, 10 seeds | 105/200 = 52.5% | 42.5% to 60.5% | 45.5% to 59.5% |
| claude-haiku-5-5 efforts: 150 blocks, 10 seeds | 142/300 = 47.3% | 34.3% to 60.0% | 41.0% to 53.0% |
| claude-opus-5-5 efforts: 58 blocks, 18 seeds (21 matches in half blocks left out) | 61/116 = 52.6% | 38.8% to 66.4% | 43.1% to 62.9% |
| claude-sonnet-5-5 efforts: 150 blocks, 10 seeds | 162/300 = 54.0% | 43.0% to 64.3% | 48.7% to 60.0% |
| gpt-5.6-terra efforts: 100 blocks, 10 seeds | 96/200 = 48.0% | 36.5% to 59.0% | 40.5% to 55.0% |
| gpt-6-astra efforts: 2 blocks, 1 seeds (5 matches in half blocks left out) | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% |
| gpt-6-luna efforts: 150 blocks, 10 seeds | 160/300 = 53.3% | 47.7% to 59.3% | 48.3% to 58.0% |
| gpt-6.1-sol efforts: 100 blocks, 10 seeds | 111/200 = 55.5% | 43.0% to 67.5% | 48.0% to 62.5% |
| gpt-6.1-terra efforts: 7 blocks, 7 seeds (17 matches in half blocks left out) | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 2319/4234 = 54.8% | 50.4% to 58.8% | 53.3% to 56.3% | 1048/2117 |
| Cross-model | 1409/2600 = 54.2% | 50.9% to 57.6% | 52.4% to 56.0% | 636/1300 |
| claude-haiku-4-5-20251001 efforts | 115/200 = 57.5% | 50.5% to 65.5% | 51.0% to 64.5% | 50/100 |
| claude-haiku-5-5 efforts | 186/300 = 62.0% | 52.0% to 72.0% | 56.3% to 68.0% | 75/150 |
| claude-opus-5-5 efforts | 67/116 = 57.8% | 44.1% to 70.4% | 48.3% to 67.2% | 31/58 |
| claude-sonnet-5-5 efforts | 164/300 = 54.7% | 42.7% to 64.7% | 49.0% to 60.0% | 75/150 |
| gpt-5.6-terra efforts | 108/200 = 54.0% | 42.5% to 64.5% | 46.5% to 61.5% | 50/100 |
| gpt-6-astra efforts | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% | 2/2 |
| gpt-6-luna efforts | 152/300 = 50.7% | 44.7% to 57.0% | 46.0% to 55.7% | 75/150 |
| gpt-6.1-sol efforts | 107/200 = 53.5% | 41.0% to 66.0% | 46.0% to 61.0% | 50/100 |
| gpt-6.1-terra efforts | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% | 4/7 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +2.5 | -1.8 to +6.6 | +1.0 to +4.0 | +4.8 | +0.3 to +8.9 | +3.4 to +6.3 |
| Cross-model | +2.8 | -0.4 to +6.4 | +1.0 to +4.6 | +4.3 | +0.6 to +7.6 | +2.4 to +6.1 |
| claude-haiku-4-5-20251001 efforts | +2.5 | -6.3 to +9.5 | -4.4 to +9.6 | +7.5 | +0.5 to +16.3 | +0.6 to +14.5 |
| claude-haiku-5-5 efforts | -2.7 | -14.0 to +7.6 | -8.4 to +3.2 | +12.0 | +1.3 to +22.7 | +6.3 to +18.0 |
| claude-opus-5-5 efforts | +2.1 | -12.0 to +15.6 | -7.0 to +11.7 | +7.6 | -6.3 to +20.8 | -2.0 to +16.9 |
| claude-sonnet-5-5 efforts | +4.0 | -7.9 to +14.6 | -1.3 to +9.9 | +4.7 | -8.1 to +15.0 | -1.0 to +10.1 |
| gpt-5.6-terra efforts | -2.0 | -14.4 to +8.6 | -9.3 to +5.0 | +4.0 | -8.5 to +15.2 | -3.3 to +11.4 |
| gpt-6-luna efforts | +3.3 | -3.1 to +9.7 | -1.6 to +8.0 | +0.7 | -5.5 to +7.1 | -4.2 to +5.7 |
| gpt-6.1-sol efforts | +5.5 | -7.8 to +18.1 | -2.1 to +12.6 | +3.5 | -9.4 to +16.5 | -4.0 to +11.1 |
| gpt-6.1-terra efforts | +6.2 | -20.8 to +33.3 | -20.8 to +35.0 | +6.2 | -20.8 to +33.3 | -20.8 to +33.8 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| Engine/2/20000: 647 blocks, 609 seeds | 747/1294 = 57.7% | 55.1% to 60.2% | 55.3% to 60.3% |
| Engine/6/20000/sampled: 78 blocks, 50 seeds | 80/156 = 51.3% | 40.6% to 62.0% | 42.9% to 59.6% |
| claude-haiku-4-5-20251001: 271 blocks, 73 seeds | 270/542 = 49.8% | 43.8% to 55.6% | 45.9% to 53.7% |
| claude-haiku-5-5: 679 blocks, 404 seeds | 715/1358 = 52.7% | 47.7% to 57.4% | 49.9% to 55.4% |
| claude-opus-5-5: 233 blocks, 67 seeds | 230/466 = 49.4% | 41.2% to 57.6% | 44.6% to 54.1% |
| claude-sonnet-5-5: 327 blocks, 41 seeds | 334/654 = 51.1% | 43.5% to 58.0% | 47.4% to 54.7% |
| gpt-5.6-terra: 208 blocks, 19 seeds | 217/416 = 52.2% | 42.9% to 61.0% | 47.1% to 57.0% |
| gpt-6-astra: 144 blocks, 57 seeds | 138/288 = 47.9% | 39.9% to 57.2% | 41.7% to 54.2% |
| gpt-6-luna: 468 blocks, 226 seeds | 479/936 = 51.2% | 48.0% to 54.6% | 48.5% to 53.8% |
| gpt-6.1-sol: 252 blocks, 49 seeds | 249/504 = 49.4% | 41.2% to 57.9% | 44.6% to 54.4% |
| gpt-6.1-terra: 110 blocks, 100 seeds | 131/220 = 59.5% | 52.7% to 66.5% | 52.7% to 66.4% |

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
| the 19 seeds with 10 or more blocks, each once |  | 1311 | mean of seed shares 57.8% (95% CI 51.7% to 64.1%, seeds drawn) |

### Tournament 3

| scored matches | Opus xhigh wins/matches = share | 95% CI (seed blocks drawn, wins over matches) | mean of block shares (a block counts once) | 95% CI | Opus minus Astra, Elo (95% CI) | blocks Opus both / split / Astra both |
|---|---|---|---|---|---|---|
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 39.0% to 68.3% | 52.4% | 38.1% to 66.7% | +25 (-84 to +139) | 6 / 10 / 4 |
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
4,987 matches, 14,961 rounds. The median 95% half-width falls from ±30 to ±24 Elo (variance of a match's round share 0.085 → 0.057). Spearman rank correlation with the raw ratings 0.973, largest rank change 11. The intervals are measured against the mean config and moved so Engine/2/20000 reads 0, so they leave out its own noise; its own luck-adjusted interval, -12 to +11, is the uncertainty of that 0.

Bias test: the mean correction per round of each config, seed-clustered, gives chi2 42.9 on 47 configs (p 0.64). Its correlation with Round Elo fitted on the other half of the seeds (20 random halvings) is -0.05.

| config | matches | rounds | Round Elo [95%] | luck-adjusted [95%] |
|---|---|---|---|---|
| gpt-6.1-terra-max | 100 | 300 | +128 [+88, +171] | +138 [+108, +168] |
| claude-sonnet-5-5-max | 140 | 420 | +120 [+85, +157] | +131 [+106, +159] |
| claude-opus-5-5-max | 80 | 240 | +135 [+93, +181] | +117 [+80, +156] |
| Engine/6/20000/sampled | 156 | 468 | +106 [+77, +136] | +113 [+88, +137] |
| claude-opus-5-5-xhigh | 170 | 510 | +108 [+79, +137] | +108 [+88, +130] |
| gpt-6-astra-high | 100 | 300 | +133 [+97, +171] | +104 [+78, +135] |
| gpt-6.1-sol-max | 142 | 426 | +112 [+83, +140] | +98 [+77, +119] |
| gpt-6-astra-medium | 254 | 762 | +99 [+76, +121] | +88 [+72, +105] |
| gpt-6.1-sol-xhigh | 101 | 303 | +83 [+47, +120] | +80 [+54, +108] |
| claude-sonnet-5-5-xhigh | 176 | 528 | +70 [+42, +97] | +72 [+52, +92] |
| gpt-6-astra-low | 80 | 240 | +75 [+37, +113] | +72 [+39, +107] |
| gpt-6-astra-off | 80 | 240 | +48 [+5, +90] | +71 [+39, +103] |
| gpt-6.1-sol-low | 98 | 294 | +77 [+37, +118] | +70 [+43, +99] |
| claude-opus-5-5-high | 80 | 240 | +88 [+47, +133] | +69 [+43, +99] |
| claude-haiku-5-5-max | 111 | 333 | +57 [+28, +87] | +62 [+35, +90] |
| gpt-6.1-terra-xhigh | 102 | 306 | +75 [+38, +114] | +62 [+36, +89] |
| gpt-6.1-terra-high | 82 | 246 | +59 [+15, +104] | +61 [+25, +101] |
| gpt-6.1-terra-medium | 130 | 390 | +74 [+40, +108] | +61 [+37, +84] |
| claude-opus-5-5-medium | 334 | 1002 | +61 [+43, +81] | +60 [+45, +74] |
| gpt-6.1-sol-medium | 271 | 813 | +72 [+50, +94] | +60 [+44, +77] |
| gpt-5.6-terra-max | 90 | 270 | +34 [-9, +76] | +53 [+18, +90] |
| claude-opus-5-5-off/low | 160 | 480 | +52 [+24, +83] | +51 [+27, +76] |
| gpt-6.1-sol-high | 99 | 297 | +59 [+21, +96] | +50 [+25, +76] |
| gpt-5.6-terra-xhigh | 93 | 279 | +48 [+5, +91] | +40 [+3, +77] |
| claude-haiku-5-5-xhigh | 158 | 474 | +24 [-3, +52] | +37 [+14, +58] |
| gpt-6.1-terra-off/low | 242 | 726 | +33 [+10, +57] | +28 [+11, +47] |
| claude-sonnet-5-5-medium | 364 | 1092 | +15 [-3, +35] | +22 [+8, +37] |
| claude-sonnet-5-5-high | 161 | 483 | +22 [-13, +54] | +22 [-2, +45] |
| claude-haiku-5-5-high | 223 | 669 | +19 [-6, +43] | +15 [-5, +35] |
| gpt-5.6-terra-high | 91 | 273 | +11 [-30, +52] | +14 [-22, +51] |
| claude-haiku-5-5-medium | 444 | 1332 | +16 [+1, +32] | +8 [-3, +21] |
| gpt-5.6-terra-medium | 259 | 777 | -7 [-30, +15] | +1 [-18, +19] |
| Engine/2/20000 | 1294 | 3882 | +0 [-14, +15] | +0 [-12, +11] |
| claude-haiku-5-5-low | 278 | 834 | +7 [-16, +30] | -3 [-20, +16] |
| gpt-5.6-terra-low | 91 | 273 | -11 [-52, +28] | -7 [-44, +28] |
| gpt-6-luna-max | 112 | 336 | +10 [-29, +51] | -9 [-40, +24] |
| claude-sonnet-5-5-low | 159 | 477 | -25 [-58, +6] | -9 [-33, +14] |
| gpt-6-luna-xhigh | 115 | 345 | +15 [-26, +57] | -15 [-43, +13] |
| claude-sonnet-5-5-off | 164 | 492 | -9 [-38, +20] | -16 [-40, +8] |
| gpt-6-luna-high | 218 | 654 | -32 [-61, -3] | -38 [-61, -16] |
| claude-haiku-5-5-off | 668 | 2004 | -87 [-105, -69] | -87 [-102, -73] |
| claude-haiku-4-5-20251001-medium | 358 | 1074 | -101 [-124, -81] | -116 [-135, -99] |
| claude-haiku-4-5-20251001-high | 135 | 405 | -131 [-163, -99] | -132 [-162, -103] |
| gpt-6-luna-medium | 398 | 1194 | -130 [-150, -110] | -134 [-151, -117] |
| claude-haiku-4-5-20251001-minimal/low | 292 | 876 | -124 [-152, -99] | -134 [-158, -112] |
| gpt-6-luna-off/low | 396 | 1188 | -188 [-215, -163] | -186 [-208, -166] |
| claude-haiku-4-5-20251001-off | 125 | 375 | -202 [-238, -169] | -188 [-214, -162] |
<!-- luck:end -->

## Elo from play and move quality

The leaderboard's second rating column (`web/src/arena-viewer/page/play-and-moves.ts`) combines each language-model config's
headline rating with the rating its points lost per move predict. Across the configs the headline rating lies close to a line in
points lost per move (on 3,709 matches: Elo = 126 - 71 x points lost per move, centred on the mean config, correlation -0.96).
A config's true distance from the line has a spread of its own, about 17 Elo. The line and the spread are fitted together by
maximum likelihood, each config weighted by the variance of its rating (from its 95% interval) plus the spread plus the slope
squared times the variance of its points lost (clustered by seed block). Each config then takes the precision-weighted mean of its
rating and the line's prediction, so a config with few matches leans on its move scores and one with many on its results. The
median 95% half-width falls from about ±31 to ±24 Elo.

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
