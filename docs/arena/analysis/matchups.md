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
| Cross-model | 51 | 2032 | 661 / 710 | 486/1275 | 1 / 2 / 41 | yes | 2032 completed, 2 partial, 5 partial (skipped), 138 skipped (skipped), 935 unstarted |
| claude-haiku-4-5-20251001 efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| claude-haiku-5-5 efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| claude-opus-5-5 efforts | 6 | 137 | 58 / 21 | 15/15 | 2 / 5 / 20 | yes | 137 completed, 21 unstarted |
| claude-sonnet-5-5 efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| gpt-5.6-terra efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| gpt-6-astra efforts | 4 | 9 | 2 / 5 | 5/6 | 1 / 2 / 2 | yes | 9 completed, 13 unstarted |
| gpt-6-luna efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| gpt-6.1-sol efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| gpt-6.1-terra efforts | 6 | 31 | 7 / 17 | 15/15 | 1 / 2 / 3 | yes | 31 completed, 33 unstarted |

### Pooled ratings

| config | wins/matches = win share | rating (Elo, depth-2 engine at 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) | pot share | cash rating (Elo, depth-2 engine at 0) | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5-max | 59/80 = 73.8% | +258 | +155 to +387 | +132 to +396 | 64.4% | +146 | +91 to +207 |
| gpt-6.1-terra-max | 58/80 = 72.5% | +243 | +137 to +360 | +120 to +374 | 66.0% | +149 | +98 to +206 |
| gpt-6-astra-high | 57/80 = 71.2% | +220 | +118 to +352 | +96 to +355 | 66.1% | +145 | +93 to +204 |
| claude-sonnet-5-5-max | 94/140 = 67.1% | +213 | +119 to +321 | +72 to +369 | 62.3% | +134 | +85 to +187 |
| claude-opus-5-5-xhigh | 82/150 = 54.7% | +209 | +122 to +308 | +98 to +326 | 53.4% | +128 | +84 to +176 |
| gpt-6.1-terra-xhigh | 56/80 = 70.0% | +198 | +98 to +323 | +74 to +325 | 59.7% | +88 | +32 to +146 |
| gpt-6-astra-medium | 169/254 = 66.5% | +190 | +110 to +278 | +91 to +297 | 60.2% | +113 | +70 to +157 |
| claude-opus-5-5-high | 47/80 = 58.8% | +185 | +84 to +300 | +90 to +297 | 54.7% | +105 | +49 to +165 |
| gpt-6.1-sol-max | 70/122 = 57.4% | +184 | +95 to +281 | +71 to +293 | 54.9% | +124 | +77 to +174 |
| claude-sonnet-5-5-xhigh | 105/176 = 59.7% | +165 | +77 to +258 | +42 to +302 | 53.7% | +81 | +40 to +128 |
| gpt-6-astra-low | 52/80 = 65.0% | +164 | +62 to +279 | +47 to +290 | 59.4% | +92 | +43 to +146 |
| claude-opus-5-5-off | 50/80 = 62.5% | +149 | +48 to +263 | +33 to +272 | 58.8% | +91 | +36 to +146 |
| Engine/6/20000/sampled | 44/76 = 57.9% | +146 | +48 to +254 | +27 to +289 | 57.2% | +101 | +49 to +155 |
| gpt-6.1-terra-medium | 50/80 = 62.5% | +145 | +39 to +258 | +28 to +266 | 57.7% | +78 | +27 to +134 |
| gpt-6-astra-off | 51/80 = 63.7% | +144 | +39 to +262 | +28 to +269 | 55.9% | +60 | +7 to +114 |
| gpt-6.1-terra-off | 52/80 = 65.0% | +133 | +28 to +245 | +6 to +259 | 56.9% | +54 | +0 to +111 |
| gpt-6.1-sol-low | 51/98 = 52.0% | +131 | +24 to +240 | +26 to +249 | 50.9% | +89 | +30 to +144 |
| gpt-6.1-sol-xhigh | 52/101 = 51.5% | +128 | +30 to +234 | -1 to +264 | 52.4% | +97 | +46 to +148 |
| gpt-6.1-terra-high | 51/80 = 63.7% | +127 | +25 to +245 | +0 to +255 | 59.7% | +76 | +22 to +137 |
| claude-opus-5-5-medium | 188/334 = 56.3% | +117 | +41 to +196 | +19 to +221 | 53.8% | +72 | +36 to +111 |
| claude-haiku-5-5-max | 68/111 = 61.3% | +115 | +25 to +212 | -21 to +262 | 58.7% | +74 | +31 to +121 |
| gpt-6.1-sol-medium | 155/271 = 57.2% | +107 | +26 to +196 | -5 to +223 | 56.8% | +84 | +41 to +128 |
| claude-haiku-5-5-xhigh | 86/158 = 54.4% | +104 | +18 to +195 | +12 to +187 | 50.4% | +42 | -2 to +89 |
| gpt-6.1-sol-high | 47/99 = 47.5% | +101 | +5 to +206 | -24 to +230 | 48.0% | +70 | +18 to +124 |
| gpt-6.1-terra-low | 45/80 = 56.2% | +90 | -27 to +204 | -37 to +211 | 55.5% | +60 | +8 to +113 |
| claude-sonnet-5-5-high | 75/161 = 46.6% | +75 | -21 to +175 | -27 to +171 | 46.9% | +35 | -12 to +84 |
| claude-haiku-5-5-high | 89/173 = 51.4% | +75 | -13 to +167 | -14 to +163 | 50.3% | +35 | -8 to +81 |
| gpt-5.6-terra-xhigh | 53/93 = 57.0% | +49 | -60 to +168 | -51 to +152 | 55.1% | +61 | +8 to +119 |
| claude-haiku-5-5-medium | 193/382 = 50.5% | +48 | -26 to +128 | -50 to +153 | 50.3% | +28 | -10 to +66 |
| claude-sonnet-5-5-medium | 175/364 = 48.1% | +45 | -29 to +131 | -23 to +121 | 48.8% | +28 | -9 to +68 |
| gpt-5.6-terra-max | 52/90 = 57.8% | +44 | -72 to +165 | -67 to +146 | 53.8% | +48 | -9 to +105 |
| claude-haiku-5-5-low | 98/194 = 50.5% | +43 | -39 to +130 | -50 to +139 | 51.3% | +27 | -15 to +72 |
| claude-opus-5-5-low | 33/80 = 41.2% | +32 | -73 to +132 | -76 to +138 | 49.4% | +51 | +0 to +102 |
| claude-sonnet-5-5-off | 65/164 = 39.6% | +27 | -65 to +122 | -89 to +142 | 42.4% | +5 | -41 to +53 |
| gpt-6-luna-xhigh | 79/115 = 68.7% | +16 | -94 to +134 | -111 to +146 | 63.6% | +20 | -38 to +82 |
| Engine/2/20000 | 48/96 = 50.0% | +0 | +0 to +0 | +0 to +0 | 50.4% | +0 | +0 to +0 |
| gpt-6-luna-max | 75/112 = 67.0% | -1 | -111 to +114 | -130 to +134 | 63.2% | +15 | -44 to +78 |
| gpt-5.6-terra-medium | 119/259 = 45.9% | -19 | -104 to +68 | -140 to +108 | 48.0% | +5 | -36 to +49 |
| claude-sonnet-5-5-low | 50/159 = 31.4% | -27 | -125 to +73 | -138 to +81 | 39.5% | -12 | -61 to +39 |
| gpt-5.6-terra-high | 40/91 = 44.0% | -34 | -144 to +83 | -121 to +48 | 49.5% | +25 | -29 to +80 |
| gpt-5.6-terra-low | 37/91 = 40.7% | -51 | -162 to +56 | -164 to +69 | 45.5% | +4 | -51 to +58 |
| gpt-6-luna-high | 67/112 = 59.8% | -57 | -179 to +64 | -216 to +119 | 55.5% | -38 | -93 to +20 |
| claude-haiku-5-5-off | 81/220 = 36.8% | -95 | -171 to -11 | -204 to +3 | 39.9% | -69 | -108 to -28 |
| claude-haiku-4-5-20251001-medium | 123/358 = 34.4% | -145 | -225 to -64 | -252 to -52 | 38.6% | -89 | -129 to -48 |
| claude-haiku-4-5-20251001-minimal | 57/143 = 39.9% | -188 | -289 to -92 | -297 to -88 | 42.5% | -109 | -158 to -62 |
| claude-haiku-4-5-20251001-low | 55/149 = 36.9% | -204 | -303 to -106 | -331 to -84 | 41.9% | -109 | -160 to -59 |
| gpt-6-luna-medium | 74/282 = 26.2% | -219 | -317 to -126 | -315 to -133 | 34.1% | -125 | -169 to -79 |
| claude-haiku-4-5-20251001-high | 47/135 = 34.8% | -234 | -341 to -135 | -360 to -133 | 42.0% | -116 | -166 to -69 |
| gpt-6-luna-off | 29/110 = 26.4% | -299 | -422 to -176 | -450 to -148 | 33.8% | -178 | -242 to -116 |
| gpt-6-luna-low | 28/110 = 25.5% | -304 | -440 to -182 | -421 to -197 | 31.4% | -193 | -255 to -130 |
| claude-haiku-4-5-20251001-off | 28/125 = 22.4% | -342 | -459 to -234 | -504 to -193 | 32.6% | -186 | -237 to -134 |

With a seat term and a round 1 starter term in the fit (position 1 +1 Elo, the starter +51 Elo) the largest rating change is 17.4 Elo.


### Observed pairs against the pooled ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below. Every resample refits the pooled ratings.

#### Cross-model

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| Engine/2/20000 vs claude-haiku-4-5-20251001-medium | 9/18 = 50.0% | 69.8% | -19.8 | -42.5 to -0.5 |
| Engine/2/20000 vs claude-haiku-5-5-medium | 9/20 = 45.0% | 43.1% | +1.9 | -19.8 to +25.2 |
| Engine/2/20000 vs claude-haiku-5-5-off | 12/18 = 66.7% | 63.3% | +3.4 | -12.2 to +20.2 |
| Engine/2/20000 vs claude-opus-5-5-medium | 8/20 = 40.0% | 33.7% | +6.3 | -12.4 to +24.2 |
| Engine/2/20000 vs claude-sonnet-5-5-medium | 10/20 = 50.0% | 43.5% | +6.5 | -12.3 to +25.6 |
| Engine/6/20000/sampled vs claude-haiku-5-5-medium | 10/20 = 50.0% | 63.7% | -13.7 | -29.0 to -0.2 |
| Engine/6/20000/sampled vs claude-opus-5-5-medium | 13/20 = 65.0% | 54.1% | +10.9 | -6.1 to +28.7 |
| Engine/6/20000/sampled vs claude-sonnet-5-5-medium | 14/20 = 70.0% | 64.1% | +5.9 | -9.0 to +20.9 |
| Engine/6/20000/sampled vs claude-sonnet-5-5-xhigh | 7/16 = 43.8% | 47.2% | -3.4 | -24.0 to +17.0 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-high | 0/1 = 0.0% | 14.4% | -14.4 | -21.6 to -9.0 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-max | 0/1 = 0.0% | 11.8% | -11.8 | -17.9 to -6.9 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-medium | 0/1 = 0.0% | 16.5% | -16.5 | -22.6 to -11.1 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-off | 2/10 = 20.0% | 30.9% | -10.9 | -34.6 to +17.3 |
| claude-haiku-4-5-20251001-high vs claude-haiku-5-5-xhigh | 0/1 = 0.0% | 12.5% | -12.5 | -18.5 to -7.6 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-low | 0/1 = 0.0% | 17.8% | -17.8 | -27.3 to -10.4 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-max | 0/2 = 0.0% | 5.6% | -5.6 | -9.6 to -2.7 |
| claude-haiku-4-5-20251001-high vs claude-opus-5-5-off | 1/2 = 50.0% | 9.9% | +40.1 | -12.5 to +93.0 |
| claude-haiku-4-5-20251001-high vs claude-sonnet-5-5-medium | 0/2 = 0.0% | 16.7% | -16.7 | -23.5 to -10.4 |
| claude-haiku-4-5-20251001-high vs gpt-5.6-terra-medium | 0/2 = 0.0% | 22.5% | -22.5 | -30.8 to -14.5 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-high | 0/2 = 0.0% | 6.8% | -6.8 | -11.3 to -3.3 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-low | 0/2 = 0.0% | 9.2% | -9.2 | -14.9 to -4.9 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-medium | 0/2 = 0.0% | 8.0% | -8.0 | -11.7 to -4.9 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra-off | 0/3 = 0.0% | 10.2% | -10.2 | -16.6 to -5.7 |
| claude-haiku-4-5-20251001-high vs gpt-6-luna-medium | 0/2 = 0.0% | 47.9% | -47.9 | -60.0 to -33.4 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 12.3% | -12.3 | -17.7 to -7.6 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-high | 0/4 = 0.0% | 11.1% | -11.1 | -17.9 to -6.0 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-low | 0/3 = 0.0% | 13.4% | -13.4 | -21.8 to -7.4 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-max | 0/2 = 0.0% | 6.0% | -6.0 | -10.6 to -3.0 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-medium | 1/3 = 33.3% | 10.2% | +23.2 | -13.2 to +91.3 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-off | 0/4 = 0.0% | 10.8% | -10.8 | -17.3 to -5.9 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 7.7% | -7.7 | -12.5 to -3.9 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5-low | 2/11 = 18.2% | 19.4% | -1.2 | -20.3 to +28.5 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5-medium | 1/3 = 33.3% | 19.0% | +14.3 | -23.0 to +35.0 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5-off | 4/11 = 36.4% | 34.7% | +1.6 | -30.2 to +42.2 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-high | 0/1 = 0.0% | 9.6% | -9.6 | -15.6 to -5.3 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-low | 0/1 = 0.0% | 20.5% | -20.5 | -31.4 to -12.6 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-max | 0/2 = 0.0% | 6.5% | -6.5 | -11.0 to -3.3 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-medium | 0/2 = 0.0% | 13.6% | -13.6 | -19.1 to -8.9 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5-off | 0/3 = 0.0% | 11.6% | -11.6 | -18.6 to -6.3 |
| claude-haiku-4-5-20251001-low vs gpt-5.6-terra-medium | 1/2 = 50.0% | 25.6% | +24.4 | +14.7 to +32.1 |
| claude-haiku-4-5-20251001-low vs gpt-6-astra-high | 0/3 = 0.0% | 8.0% | -8.0 | -13.2 to -4.0 |
| claude-haiku-4-5-20251001-low vs gpt-6-astra-low | 0/3 = 0.0% | 10.7% | -10.7 | -17.3 to -6.0 |
| claude-haiku-4-5-20251001-low vs gpt-6-astra-off | 1/3 = 33.3% | 11.9% | +21.4 | -15.7 to +89.7 |
| claude-haiku-4-5-20251001-low vs gpt-6-luna-medium | 2/2 = 100.0% | 52.2% | +47.8 | +34.7 to +58.2 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-sol-medium | 0/2 = 0.0% | 14.3% | -14.3 | -20.6 to -9.0 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-high | 0/4 = 0.0% | 12.9% | -12.9 | -20.8 to -7.0 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-low | 2/3 = 66.7% | 15.5% | +51.1 | -15.5 to +89.2 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-max | 0/3 = 0.0% | 7.1% | -7.1 | -11.9 to -3.9 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-medium | 0/3 = 0.0% | 11.8% | -11.8 | -18.5 to -6.8 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-off | 1/4 = 25.0% | 12.5% | +12.5 | -16.4 to +82.3 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 9.0% | -9.0 | -14.7 to -4.6 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-high | 1/12 = 8.3% | 21.9% | -13.6 | -26.6 to +4.9 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-low | 4/14 = 28.6% | 25.3% | +3.3 | -16.2 to +23.8 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-max | 0/2 = 0.0% | 18.2% | -18.2 | -24.7 to -12.4 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-medium | 8/31 = 25.8% | 24.7% | +1.1 | -11.1 to +13.0 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-off | 5/12 = 41.7% | 42.7% | -1.1 | -32.5 to +27.7 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-5-5-xhigh | 1/2 = 50.0% | 19.2% | +30.8 | +24.1 to +36.4 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-high | 0/1 = 0.0% | 13.0% | -13.0 | -19.7 to -7.8 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-low | 0/2 = 0.0% | 26.5% | -26.5 | -36.8 to -17.7 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-max | 0/2 = 0.0% | 8.9% | -8.9 | -14.1 to -4.9 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-medium | 7/20 = 35.0% | 18.1% | +16.9 | -2.5 to +37.0 |
| claude-haiku-4-5-20251001-medium vs claude-opus-5-5-off | 1/3 = 33.3% | 15.5% | +17.8 | -19.8 to +85.7 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-high | 0/2 = 0.0% | 21.9% | -21.9 | -30.0 to -15.0 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-low | 0/2 = 0.0% | 33.6% | -33.6 | -43.0 to -24.3 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-max | 0/2 = 0.0% | 11.3% | -11.3 | -16.5 to -7.1 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-medium | 2/20 = 10.0% | 25.0% | -15.0 | -26.5 to -0.6 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-off | 0/4 = 0.0% | 27.1% | -27.1 | -35.5 to -19.7 |
| claude-haiku-4-5-20251001-medium vs claude-sonnet-5-5-xhigh | 0/2 = 0.0% | 14.3% | -14.3 | -19.3 to -9.7 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-low | 0/2 = 0.0% | 36.7% | -36.7 | -48.2 to -25.3 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-max | 0/2 = 0.0% | 25.2% | -25.2 | -35.8 to -15.9 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-medium | 6/20 = 30.0% | 32.5% | -2.5 | -19.1 to +12.9 |
| claude-haiku-4-5-20251001-medium vs gpt-5.6-terra-xhigh | 1/2 = 50.0% | 24.7% | +25.3 | +15.1 to +34.1 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-high | 0/3 = 0.0% | 10.9% | -10.9 | -16.3 to -6.1 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-low | 1/3 = 33.3% | 14.4% | +18.9 | -18.2 to +85.9 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-medium | 3/20 = 15.0% | 12.7% | +2.3 | -11.3 to +18.2 |
| claude-haiku-4-5-20251001-medium vs gpt-6-astra-off | 0/3 = 0.0% | 15.9% | -15.9 | -23.6 to -9.9 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-high | 1/2 = 50.0% | 37.6% | +12.4 | -2.9 to +25.1 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-medium | 12/20 = 60.0% | 60.5% | -0.5 | -26.6 to +23.1 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-off | 2/2 = 100.0% | 70.7% | +29.3 | +17.8 to +41.0 |
| claude-haiku-4-5-20251001-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 28.3% | +21.7 | +10.9 to +30.6 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 19.5% | +30.5 | +22.1 to +36.8 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-low | 1/2 = 50.0% | 16.9% | +33.1 | +24.8 to +38.9 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-medium | 6/20 = 30.0% | 19.0% | +11.0 | -8.1 to +32.6 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 17.2% | +32.8 | +25.0 to +38.3 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-high | 0/4 = 0.0% | 17.2% | -17.2 | -25.6 to -10.5 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-low | 1/3 = 33.3% | 20.5% | +12.8 | -26.5 to +81.0 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-max | 0/3 = 0.0% | 9.7% | -9.7 | -15.2 to -5.3 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-medium | 1/3 = 33.3% | 15.9% | +17.5 | -19.9 to +85.4 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-off | 0/4 = 0.0% | 16.7% | -16.7 | -24.8 to -10.4 |
| claude-haiku-4-5-20251001-medium vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 12.2% | -12.2 | -18.3 to -7.0 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5-low | 0/10 = 0.0% | 20.9% | -20.9 | -30.0 to -13.5 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5-medium | 1/2 = 50.0% | 20.4% | +29.6 | +21.5 to +35.9 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5-off | 3/11 = 27.3% | 36.8% | -9.5 | -36.6 to +11.4 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5-low | 0/1 = 0.0% | 22.0% | -22.0 | -33.3 to -12.7 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5-max | 0/2 = 0.0% | 7.1% | -7.1 | -12.1 to -3.6 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5-medium | 1/2 = 50.0% | 14.7% | +35.3 | +28.7 to +40.2 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5-off | 0/2 = 0.0% | 12.5% | -12.5 | -20.1 to -6.9 |
| claude-haiku-4-5-20251001-minimal vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 20.7% | +29.3 | +21.2 to +35.7 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra-high | 0/3 = 0.0% | 8.7% | -8.7 | -14.3 to -4.5 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra-low | 0/2 = 0.0% | 11.6% | -11.6 | -18.5 to -6.4 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra-medium | 0/2 = 0.0% | 10.2% | -10.2 | -15.4 to -6.0 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra-off | 0/3 = 0.0% | 12.9% | -12.9 | -20.7 to -7.1 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-luna-medium | 1/2 = 50.0% | 54.4% | -4.4 | -16.5 to +8.7 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-high | 3/4 = 75.0% | 14.0% | +61.0 | -7.7 to +91.0 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-low | 0/3 = 0.0% | 16.7% | -16.7 | -26.8 to -9.6 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-max | 1/2 = 50.0% | 7.7% | +42.3 | -9.8 to +94.7 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-medium | 0/3 = 0.0% | 12.8% | -12.8 | -20.2 to -7.1 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-off | 0/4 = 0.0% | 13.6% | -13.6 | -21.5 to -7.4 |
| claude-haiku-4-5-20251001-minimal vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 9.7% | -9.7 | -15.9 to -5.1 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5-medium | 1/2 = 50.0% | 9.6% | +40.4 | +35.4 to +44.0 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5-off | 3/11 = 27.3% | 19.4% | +7.9 | -20.5 to +41.1 |
| claude-haiku-4-5-20251001-off vs claude-opus-5-5-max | 0/1 = 0.0% | 3.1% | -3.1 | -5.5 to -1.5 |
| claude-haiku-4-5-20251001-off vs claude-opus-5-5-off | 0/2 = 0.0% | 5.6% | -5.6 | -9.7 to -2.8 |
| claude-haiku-4-5-20251001-off vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 9.7% | +40.3 | +34.9 to +44.0 |
| claude-haiku-4-5-20251001-off vs gpt-5.6-terra-medium | 0/2 = 0.0% | 13.5% | -13.5 | -19.7 to -7.8 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-high | 0/2 = 0.0% | 3.8% | -3.8 | -6.7 to -1.7 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-low | 0/2 = 0.0% | 5.1% | -5.1 | -8.9 to -2.5 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-medium | 0/2 = 0.0% | 4.5% | -4.5 | -7.0 to -2.5 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra-off | 0/2 = 0.0% | 5.8% | -5.8 | -10.2 to -2.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-sol-medium | 0/2 = 0.0% | 7.0% | -7.0 | -10.7 to -4.1 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-high | 0/3 = 0.0% | 6.3% | -6.3 | -10.9 to -3.1 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-low | 0/2 = 0.0% | 7.7% | -7.7 | -13.4 to -3.8 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-max | 0/2 = 0.0% | 3.3% | -3.3 | -6.1 to -1.6 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-medium | 0/2 = 0.0% | 5.7% | -5.7 | -10.0 to -2.9 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-off | 0/3 = 0.0% | 6.1% | -6.1 | -10.5 to -3.1 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 4.3% | -4.3 | -7.4 to -2.0 |
| claude-haiku-5-5-high vs claude-opus-5-5-high | 0/2 = 0.0% | 34.7% | -34.7 | -47.1 to -22.8 |
| claude-haiku-5-5-high vs claude-opus-5-5-low | 3/3 = 100.0% | 56.2% | +43.8 | +31.0 to +56.4 |
| claude-haiku-5-5-high vs claude-opus-5-5-max | 0/4 = 0.0% | 25.9% | -25.9 | -37.2 to -15.9 |
| claude-haiku-5-5-high vs claude-opus-5-5-medium | 1/2 = 50.0% | 44.0% | +6.0 | -3.1 to +14.4 |
| claude-haiku-5-5-high vs claude-opus-5-5-off | 3/4 = 75.0% | 39.5% | +35.5 | -33.2 to +69.4 |
| claude-haiku-5-5-high vs claude-sonnet-5-5-medium | 2/4 = 50.0% | 54.2% | -4.2 | -58.4 to +49.7 |
| claude-haiku-5-5-high vs gpt-6-astra-high | 2/4 = 50.0% | 30.2% | +19.8 | -32.4 to +73.4 |
| claude-haiku-5-5-high vs gpt-6-astra-low | 1/4 = 25.0% | 37.4% | -12.4 | -45.1 to +56.6 |
| claude-haiku-5-5-high vs gpt-6-astra-medium | 0/2 = 0.0% | 34.0% | -34.0 | -42.5 to -24.7 |
| claude-haiku-5-5-high vs gpt-6-astra-off | 1/4 = 25.0% | 40.2% | -15.2 | -47.9 to +49.6 |
| claude-haiku-5-5-high vs gpt-6-luna-medium | 1/2 = 50.0% | 84.5% | -34.5 | -39.7 to -27.0 |
| claude-haiku-5-5-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 45.5% | -45.5 | -54.4 to -35.0 |
| claude-haiku-5-5-high vs gpt-6.1-terra-high | 2/4 = 50.0% | 42.6% | +7.4 | -45.2 to +60.8 |
| claude-haiku-5-5-high vs gpt-6.1-terra-low | 2/4 = 50.0% | 47.8% | +2.2 | -51.4 to +55.5 |
| claude-haiku-5-5-high vs gpt-6.1-terra-max | 0/4 = 0.0% | 27.6% | -27.6 | -40.2 to -16.9 |
| claude-haiku-5-5-high vs gpt-6.1-terra-medium | 2/4 = 50.0% | 40.1% | +9.9 | -46.6 to +60.3 |
| claude-haiku-5-5-high vs gpt-6.1-terra-off | 1/3 = 33.3% | 41.7% | -8.3 | -49.5 to +61.2 |
| claude-haiku-5-5-high vs gpt-6.1-terra-xhigh | 2/4 = 50.0% | 33.0% | +17.0 | -35.0 to +71.0 |
| claude-haiku-5-5-low vs claude-opus-5-5-high | 1/2 = 50.0% | 30.6% | +19.4 | -36.9 to +75.9 |
| claude-haiku-5-5-low vs claude-opus-5-5-low | 0/2 = 0.0% | 51.6% | -51.6 | -64.3 to -39.1 |
| claude-haiku-5-5-low vs claude-opus-5-5-max | 1/3 = 33.3% | 22.5% | +10.8 | -28.3 to +79.2 |
| claude-haiku-5-5-low vs claude-opus-5-5-medium | 2/2 = 100.0% | 39.5% | +60.5 | +50.0 to +68.4 |
| claude-haiku-5-5-low vs claude-opus-5-5-off | 1/4 = 25.0% | 35.1% | -10.1 | -43.0 to +58.8 |
| claude-haiku-5-5-low vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 49.6% | +0.4 | -9.3 to +9.1 |
| claude-haiku-5-5-low vs gpt-5.6-terra-medium | 1/2 = 50.0% | 58.8% | -8.8 | -17.9 to +1.2 |
| claude-haiku-5-5-low vs gpt-6-astra-high | 0/4 = 0.0% | 26.5% | -26.5 | -37.3 to -16.0 |
| claude-haiku-5-5-low vs gpt-6-astra-low | 0/4 = 0.0% | 33.2% | -33.2 | -45.5 to -21.9 |
| claude-haiku-5-5-low vs gpt-6-astra-medium | 0/2 = 0.0% | 30.0% | -30.0 | -38.7 to -22.0 |
| claude-haiku-5-5-low vs gpt-6-astra-off | 3/4 = 75.0% | 35.9% | +39.1 | -26.0 to +72.8 |
| claude-haiku-5-5-low vs gpt-6-luna-medium | 1/2 = 50.0% | 81.9% | -31.9 | -37.6 to -24.4 |
| claude-haiku-5-5-low vs gpt-6.1-sol-medium | 2/2 = 100.0% | 41.0% | +59.0 | +48.8 to +67.8 |
| claude-haiku-5-5-low vs gpt-6.1-terra-high | 3/4 = 75.0% | 38.1% | +36.9 | -27.6 to +71.0 |
| claude-haiku-5-5-low vs gpt-6.1-terra-low | 1/4 = 25.0% | 43.2% | -18.2 | -52.6 to +9.0 |
| claude-haiku-5-5-low vs gpt-6.1-terra-max | 1/4 = 25.0% | 24.0% | +1.0 | -30.8 to +71.2 |
| claude-haiku-5-5-low vs gpt-6.1-terra-medium | 3/4 = 75.0% | 35.8% | +39.2 | -29.1 to +72.3 |
| claude-haiku-5-5-low vs gpt-6.1-terra-off | 3/4 = 75.0% | 37.3% | +37.7 | -26.6 to +71.7 |
| claude-haiku-5-5-low vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 29.0% | -29.0 | -40.8 to -17.9 |
| claude-haiku-5-5-max vs claude-opus-5-5-medium | 2/2 = 100.0% | 49.7% | +50.3 | +38.8 to +59.2 |
| claude-haiku-5-5-max vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 59.9% | -9.9 | -18.7 to -0.2 |
| claude-haiku-5-5-max vs gpt-5.6-terra-medium | 1/2 = 50.0% | 68.4% | -18.4 | -27.3 to -8.7 |
| claude-haiku-5-5-max vs gpt-6.1-sol-medium | 1/2 = 50.0% | 51.3% | -1.3 | -12.2 to +8.9 |
| claude-haiku-5-5-medium vs claude-opus-5-5-high | 0/2 = 0.0% | 31.2% | -31.2 | -40.7 to -20.5 |
| claude-haiku-5-5-medium vs claude-opus-5-5-low | 1/2 = 50.0% | 52.3% | -2.3 | -13.9 to +9.2 |
| claude-haiku-5-5-medium vs claude-opus-5-5-max | 1/3 = 33.3% | 23.0% | +10.3 | -28.2 to +32.6 |
| claude-haiku-5-5-medium vs claude-opus-5-5-medium | 7/20 = 35.0% | 40.2% | -5.2 | -21.2 to +8.9 |
| claude-haiku-5-5-medium vs claude-opus-5-5-off | 2/4 = 50.0% | 35.8% | +14.2 | -36.8 to +67.5 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-high | 1/4 = 25.0% | 46.1% | -21.1 | -51.6 to +9.1 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-low | 2/2 = 100.0% | 60.6% | +39.4 | +29.6 to +48.2 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-max | 0/2 = 0.0% | 27.9% | -27.9 | -36.6 to -19.2 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-medium | 12/20 = 60.0% | 50.4% | +9.6 | -9.1 to +29.5 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-off | 1/2 = 50.0% | 53.0% | -3.0 | -12.2 to +5.8 |
| claude-haiku-5-5-medium vs claude-sonnet-5-5-xhigh | 1/4 = 25.0% | 33.7% | -8.7 | -38.6 to +20.7 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-high | 2/2 = 100.0% | 61.5% | +38.5 | +27.1 to +50.2 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-low | 1/2 = 50.0% | 63.9% | -13.9 | -24.7 to -2.1 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-max | 2/2 = 100.0% | 50.6% | +49.4 | +35.5 to +60.9 |
| claude-haiku-5-5-medium vs gpt-5.6-terra-medium | 13/20 = 65.0% | 59.5% | +5.5 | -8.5 to +20.9 |
| claude-haiku-5-5-medium vs gpt-6-astra-high | 1/4 = 25.0% | 27.0% | -2.0 | -34.0 to +65.6 |
| claude-haiku-5-5-medium vs gpt-6-astra-low | 2/4 = 50.0% | 33.8% | +16.2 | -36.1 to +69.5 |
| claude-haiku-5-5-medium vs gpt-6-astra-medium | 6/20 = 30.0% | 30.6% | -0.6 | -16.5 to +14.2 |
| claude-haiku-5-5-medium vs gpt-6-astra-off | 3/4 = 75.0% | 36.5% | +38.5 | -30.1 to +71.4 |
| claude-haiku-5-5-medium vs gpt-6-luna-high | 1/2 = 50.0% | 64.7% | -14.7 | -25.9 to -1.3 |
| claude-haiku-5-5-medium vs gpt-6-luna-low | 2/2 = 100.0% | 88.3% | +11.7 | +6.0 to +18.4 |
| claude-haiku-5-5-medium vs gpt-6-luna-max | 1/2 = 50.0% | 57.0% | -7.0 | -18.6 to +5.9 |
| claude-haiku-5-5-medium vs gpt-6-luna-medium | 19/20 = 95.0% | 82.3% | +12.7 | +0.1 to +21.5 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-high | 2/4 = 50.0% | 42.4% | +7.6 | -3.0 to +17.9 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-low | 0/2 = 0.0% | 38.3% | -38.3 | -48.9 to -27.4 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-max | 1/2 = 50.0% | 31.4% | +18.6 | +10.1 to +25.9 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-medium | 10/20 = 50.0% | 41.6% | +8.4 | -6.2 to +22.4 |
| claude-haiku-5-5-medium vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 38.7% | +11.3 | +0.5 to +21.1 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-high | 1/4 = 25.0% | 38.8% | -13.8 | -46.6 to +54.4 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-low | 0/4 = 0.0% | 43.9% | -43.9 | -56.4 to -31.8 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-max | 1/4 = 25.0% | 24.6% | +0.4 | -31.1 to +70.3 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-medium | 1/4 = 25.0% | 36.4% | -11.4 | -43.9 to +55.8 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-off | 1/4 = 25.0% | 37.9% | -12.9 | -45.5 to +53.7 |
| claude-haiku-5-5-medium vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 29.6% | -29.6 | -39.8 to -18.9 |
| claude-haiku-5-5-off vs claude-opus-5-5-high | 0/1 = 0.0% | 16.7% | -16.7 | -25.2 to -10.2 |
| claude-haiku-5-5-off vs claude-opus-5-5-low | 0/2 = 0.0% | 32.6% | -32.6 | -43.9 to -22.6 |
| claude-haiku-5-5-off vs claude-opus-5-5-max | 0/2 = 0.0% | 11.6% | -11.6 | -18.2 to -6.6 |
| claude-haiku-5-5-off vs claude-opus-5-5-off | 0/3 = 0.0% | 19.7% | -19.7 | -28.5 to -12.0 |
| claude-haiku-5-5-off vs gpt-5.6-terra-medium | 1/2 = 50.0% | 39.3% | +10.7 | +1.2 to +19.5 |
| claude-haiku-5-5-off vs gpt-6-astra-high | 1/3 = 33.3% | 14.0% | +19.3 | -18.1 to +87.4 |
| claude-haiku-5-5-off vs gpt-6-astra-low | 0/3 = 0.0% | 18.4% | -18.4 | -27.0 to -11.1 |
| claude-haiku-5-5-off vs gpt-6-astra-medium | 0/2 = 0.0% | 16.3% | -16.3 | -21.5 to -11.4 |
| claude-haiku-5-5-off vs gpt-6-astra-off | 1/4 = 25.0% | 20.2% | +4.8 | -25.9 to +76.2 |
| claude-haiku-5-5-off vs gpt-6-luna-medium | 1/2 = 50.0% | 67.2% | -17.2 | -25.7 to -6.9 |
| claude-haiku-5-5-off vs gpt-6.1-sol-medium | 0/2 = 0.0% | 23.9% | -23.9 | -31.6 to -17.0 |
| claude-haiku-5-5-off vs gpt-6.1-terra-high | 0/4 = 0.0% | 21.8% | -21.8 | -31.5 to -13.4 |
| claude-haiku-5-5-off vs gpt-6.1-terra-low | 2/3 = 66.7% | 25.7% | +41.0 | -26.9 to +80.9 |
| claude-haiku-5-5-off vs gpt-6.1-terra-max | 0/3 = 0.0% | 12.5% | -12.5 | -20.2 to -7.1 |
| claude-haiku-5-5-off vs gpt-6.1-terra-medium | 0/3 = 0.0% | 20.2% | -20.2 | -29.1 to -12.4 |
| claude-haiku-5-5-off vs gpt-6.1-terra-off | 0/4 = 0.0% | 21.2% | -21.2 | -30.7 to -13.2 |
| claude-haiku-5-5-off vs gpt-6.1-terra-xhigh | 0/4 = 0.0% | 15.6% | -15.6 | -23.2 to -8.8 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-high | 0/2 = 0.0% | 38.6% | -38.6 | -51.6 to -26.3 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-low | 2/3 = 66.7% | 60.3% | +6.4 | -61.6 to +47.1 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-max | 0/3 = 0.0% | 29.2% | -29.2 | -41.5 to -17.9 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-medium | 0/2 = 0.0% | 48.2% | -48.2 | -57.3 to -37.6 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5-off | 0/4 = 0.0% | 43.6% | -43.6 | -57.1 to -30.9 |
| claude-haiku-5-5-xhigh vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 58.4% | -8.4 | -17.1 to -0.0 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-high | 1/4 = 25.0% | 33.9% | -8.9 | -41.3 to +54.6 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-low | 1/4 = 25.0% | 41.5% | -16.5 | -51.1 to +50.4 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-medium | 0/2 = 0.0% | 37.9% | -37.9 | -47.5 to -28.1 |
| claude-haiku-5-5-xhigh vs gpt-6-astra-off | 3/4 = 75.0% | 44.3% | +30.7 | -38.0 to +64.8 |
| claude-haiku-5-5-xhigh vs gpt-6-luna-medium | 2/2 = 100.0% | 86.6% | +13.4 | +8.6 to +19.3 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-high | 2/4 = 50.0% | 46.7% | +3.3 | -49.6 to +56.3 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-low | 1/4 = 25.0% | 52.0% | -27.0 | -60.9 to +39.1 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-max | 0/4 = 0.0% | 31.1% | -31.1 | -43.7 to -20.0 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-medium | 3/4 = 75.0% | 44.2% | +30.8 | -34.9 to +64.0 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-off | 1/3 = 33.3% | 45.8% | -12.5 | -54.6 to +56.1 |
| claude-haiku-5-5-xhigh vs gpt-6.1-terra-xhigh | 2/4 = 50.0% | 36.8% | +13.2 | -37.6 to +65.6 |
| claude-opus-5-5-high vs claude-sonnet-5-5-high | 2/2 = 100.0% | 65.3% | +34.7 | +22.2 to +47.4 |
| claude-opus-5-5-high vs claude-sonnet-5-5-low | 2/2 = 100.0% | 77.2% | +22.8 | +13.7 to +33.3 |
| claude-opus-5-5-high vs claude-sonnet-5-5-medium | 1/2 = 50.0% | 69.1% | -19.1 | -28.8 to -7.5 |
| claude-opus-5-5-high vs claude-sonnet-5-5-off | 2/2 = 100.0% | 71.3% | +28.7 | +17.9 to +40.1 |
| claude-opus-5-5-high vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 52.8% | +47.2 | +33.7 to +60.2 |
| claude-opus-5-5-high vs gpt-6-astra-high | 0/1 = 0.0% | 45.0% | -45.0 | -59.6 to -28.0 |
| claude-opus-5-5-high vs gpt-6-astra-medium | 1/2 = 50.0% | 49.3% | +0.7 | -12.6 to +13.1 |
| claude-opus-5-5-high vs gpt-6-astra-off | 0/1 = 0.0% | 55.9% | -55.9 | -69.1 to -39.4 |
| claude-opus-5-5-high vs gpt-6-luna-medium | 2/2 = 100.0% | 91.1% | +8.9 | +5.0 to +14.7 |
| claude-opus-5-5-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 61.1% | -61.1 | -71.7 to -47.7 |
| claude-opus-5-5-high vs gpt-6.1-terra-low | 1/1 = 100.0% | 63.3% | +36.7 | +22.6 to +51.5 |
| claude-opus-5-5-high vs gpt-6.1-terra-max | 1/1 = 100.0% | 41.8% | +58.2 | +41.4 to +72.3 |
| claude-opus-5-5-low vs claude-sonnet-5-5-high | 2/3 = 66.7% | 43.8% | +22.9 | -46.1 to +65.0 |
| claude-opus-5-5-low vs claude-sonnet-5-5-low | 1/2 = 50.0% | 58.3% | -8.3 | -66.5 to +49.2 |
| claude-opus-5-5-low vs claude-sonnet-5-5-medium | 2/3 = 66.7% | 48.0% | +18.6 | -5.5 to +60.4 |
| claude-opus-5-5-low vs claude-sonnet-5-5-off | 0/3 = 0.0% | 50.7% | -50.7 | -63.9 to -37.6 |
| claude-opus-5-5-low vs claude-sonnet-5-5-xhigh | 0/3 = 0.0% | 31.7% | -31.7 | -43.0 to -21.0 |
| claude-opus-5-5-low vs gpt-5.6-terra-medium | 0/2 = 0.0% | 57.2% | -57.2 | -67.9 to -43.2 |
| claude-opus-5-5-low vs gpt-6-astra-high | 0/1 = 0.0% | 25.3% | -25.3 | -37.3 to -13.8 |
| claude-opus-5-5-low vs gpt-6-astra-low | 0/1 = 0.0% | 31.8% | -31.8 | -45.1 to -19.4 |
| claude-opus-5-5-low vs gpt-6-astra-off | 0/1 = 0.0% | 34.4% | -34.4 | -49.1 to -21.6 |
| claude-opus-5-5-low vs gpt-6-luna-medium | 2/2 = 100.0% | 80.9% | +19.1 | +11.5 to +27.9 |
| claude-opus-5-5-low vs gpt-6.1-terra-max | 0/1 = 0.0% | 22.9% | -22.9 | -35.1 to -12.7 |
| claude-opus-5-5-low vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 27.7% | +72.3 | +58.2 to +83.2 |
| claude-opus-5-5-max vs claude-sonnet-5-5-high | 3/4 = 75.0% | 74.1% | +0.9 | -65.7 to +34.1 |
| claude-opus-5-5-max vs claude-sonnet-5-5-low | 2/3 = 66.7% | 83.7% | -17.1 | -85.1 to +20.4 |
| claude-opus-5-5-max vs claude-sonnet-5-5-medium | 3/3 = 100.0% | 77.3% | +22.7 | +13.5 to +32.2 |
| claude-opus-5-5-max vs claude-sonnet-5-5-off | 3/3 = 100.0% | 79.1% | +20.9 | +12.0 to +31.8 |
| claude-opus-5-5-max vs claude-sonnet-5-5-xhigh | 2/3 = 66.7% | 63.0% | +3.7 | -64.9 to +45.2 |
| claude-opus-5-5-max vs gpt-6-astra-medium | 1/2 = 50.0% | 59.6% | -9.6 | -22.0 to +3.2 |
| claude-opus-5-5-max vs gpt-6.1-sol-medium | 1/2 = 50.0% | 70.5% | -20.5 | -31.4 to -8.5 |
| claude-opus-5-5-max vs gpt-6.1-terra-medium | 1/2 = 50.0% | 65.8% | -15.8 | -28.5 to -0.4 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-high | 2/2 = 100.0% | 56.0% | +44.0 | +33.3 to +53.7 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-low | 2/4 = 50.0% | 69.6% | -19.6 | -73.9 to +33.7 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-max | 2/2 = 100.0% | 36.6% | +63.4 | +52.3 to +72.5 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-medium | 12/20 = 60.0% | 60.2% | -0.2 | -18.5 to +18.4 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-off | 1/2 = 50.0% | 62.7% | -12.7 | -21.4 to -2.7 |
| claude-opus-5-5-medium vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 43.1% | +56.9 | +47.1 to +65.7 |
| claude-opus-5-5-medium vs gpt-5.6-terra-high | 2/2 = 100.0% | 70.5% | +29.5 | +19.8 to +40.5 |
| claude-opus-5-5-medium vs gpt-5.6-terra-low | 1/2 = 50.0% | 72.5% | -22.5 | -32.0 to -11.8 |
| claude-opus-5-5-medium vs gpt-5.6-terra-max | 2/2 = 100.0% | 60.4% | +39.6 | +27.0 to +51.3 |
| claude-opus-5-5-medium vs gpt-5.6-terra-medium | 12/20 = 60.0% | 68.6% | -8.6 | -21.4 to +5.7 |
| claude-opus-5-5-medium vs gpt-5.6-terra-xhigh | 2/2 = 100.0% | 59.7% | +40.3 | +28.1 to +52.0 |
| claude-opus-5-5-medium vs gpt-6-astra-high | 2/4 = 50.0% | 35.6% | +14.4 | -36.3 to +67.7 |
| claude-opus-5-5-medium vs gpt-6-astra-low | 2/4 = 50.0% | 43.3% | +6.7 | -44.3 to +60.1 |
| claude-opus-5-5-medium vs gpt-6-astra-medium | 9/20 = 45.0% | 39.7% | +5.3 | -6.7 to +15.1 |
| claude-opus-5-5-medium vs gpt-6-astra-off | 2/4 = 50.0% | 46.2% | +3.8 | -48.2 to +57.0 |
| claude-opus-5-5-medium vs gpt-6-luna-low | 2/2 = 100.0% | 91.9% | +8.1 | +4.1 to +13.5 |
| claude-opus-5-5-medium vs gpt-6-luna-max | 1/2 = 50.0% | 66.4% | -16.4 | -26.7 to -4.2 |
| claude-opus-5-5-medium vs gpt-6-luna-medium | 16/20 = 80.0% | 87.4% | -7.4 | -28.2 to +11.2 |
| claude-opus-5-5-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 64.2% | -14.2 | -24.6 to -2.6 |
| claude-opus-5-5-medium vs gpt-6.1-sol-high | 2/2 = 100.0% | 52.3% | +47.7 | +36.5 to +57.0 |
| claude-opus-5-5-medium vs gpt-6.1-sol-low | 1/2 = 50.0% | 48.0% | +2.0 | -9.7 to +13.5 |
| claude-opus-5-5-medium vs gpt-6.1-sol-max | 1/2 = 50.0% | 40.5% | +9.5 | -0.4 to +18.5 |
| claude-opus-5-5-medium vs gpt-6.1-sol-medium | 12/20 = 60.0% | 51.5% | +8.5 | -10.8 to +28.4 |
| claude-opus-5-5-medium vs gpt-6.1-sol-xhigh | 2/4 = 50.0% | 48.5% | +1.5 | -9.1 to +12.3 |
| claude-opus-5-5-medium vs gpt-6.1-terra-high | 0/3 = 0.0% | 48.6% | -48.6 | -61.0 to -34.7 |
| claude-opus-5-5-medium vs gpt-6.1-terra-low | 3/4 = 75.0% | 53.9% | +21.1 | -43.4 to +55.2 |
| claude-opus-5-5-medium vs gpt-6.1-terra-max | 1/4 = 25.0% | 32.7% | -7.7 | -40.9 to +61.0 |
| claude-opus-5-5-medium vs gpt-6.1-terra-medium | 2/3 = 66.7% | 46.1% | +20.6 | -3.7 to +61.4 |
| claude-opus-5-5-medium vs gpt-6.1-terra-off | 1/3 = 33.3% | 47.7% | -14.3 | -56.6 to +55.3 |
| claude-opus-5-5-medium vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 38.5% | -5.2 | -45.4 to +63.1 |
| claude-opus-5-5-off vs claude-sonnet-5-5-high | 2/4 = 50.0% | 60.5% | -10.5 | -64.6 to +41.2 |
| claude-opus-5-5-off vs claude-sonnet-5-5-low | 3/3 = 100.0% | 73.4% | +26.6 | +16.7 to +38.6 |
| claude-opus-5-5-off vs claude-sonnet-5-5-medium | 3/4 = 75.0% | 64.5% | +10.5 | -55.4 to +42.6 |
| claude-opus-5-5-off vs claude-sonnet-5-5-off | 3/4 = 75.0% | 66.9% | +8.1 | -67.2 to +40.1 |
| claude-opus-5-5-off vs claude-sonnet-5-5-xhigh | 2/4 = 50.0% | 47.7% | +2.3 | -50.3 to +55.7 |
| claude-opus-5-5-off vs gpt-6-astra-high | 1/1 = 100.0% | 39.9% | +60.1 | +43.8 to +74.1 |
| claude-opus-5-5-off vs gpt-6-astra-low | 1/1 = 100.0% | 47.9% | +52.1 | +35.8 to +65.9 |
| claude-opus-5-5-off vs gpt-6-astra-off | 0/1 = 0.0% | 50.8% | -50.8 | -65.7 to -34.3 |
| claude-opus-5-5-off vs gpt-6-luna-xhigh | 1/2 = 50.0% | 68.3% | -18.3 | -29.8 to -3.0 |
| claude-opus-5-5-off vs gpt-6.1-terra-low | 1/1 = 100.0% | 58.4% | +41.6 | +25.8 to +56.1 |
| claude-opus-5-5-off vs gpt-6.1-terra-max | 0/1 = 0.0% | 36.9% | -36.9 | -53.0 to -22.4 |
| claude-opus-5-5-off vs gpt-6.1-terra-medium | 1/1 = 100.0% | 50.7% | +49.3 | +34.4 to +62.9 |
| claude-opus-5-5-off vs gpt-6.1-terra-off | 1/1 = 100.0% | 52.3% | +47.7 | +31.6 to +61.6 |
| claude-opus-5-5-off vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 43.0% | -43.0 | -58.3 to -26.5 |
| claude-opus-5-5-xhigh vs claude-sonnet-5-5-max | 2/10 = 20.0% | 49.5% | -29.5 | -55.7 to -4.3 |
| claude-opus-5-5-xhigh vs gpt-6-astra-high | 2/4 = 50.0% | 48.4% | +1.6 | -53.2 to +54.8 |
| claude-opus-5-5-xhigh vs gpt-6-astra-low | 2/4 = 50.0% | 56.4% | -6.4 | -59.0 to +44.8 |
| claude-opus-5-5-xhigh vs gpt-6-astra-medium | 22/41 = 53.7% | 52.8% | +0.9 | -10.8 to +12.5 |
| claude-opus-5-5-xhigh vs gpt-6-astra-off | 2/4 = 50.0% | 59.3% | -9.3 | -63.5 to +44.3 |
| claude-opus-5-5-xhigh vs gpt-6.1-sol-max | 4/10 = 40.0% | 53.6% | -13.6 | -38.8 to +2.1 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-high | 1/3 = 33.3% | 61.6% | -28.3 | -70.1 to +39.6 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-low | 3/3 = 100.0% | 66.5% | +33.5 | +21.1 to +46.8 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-max | 5/5 = 100.0% | 45.2% | +54.8 | +40.6 to +68.8 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-medium | 2/3 = 66.7% | 59.2% | +7.5 | -61.3 to +49.0 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-off | 1/3 = 33.3% | 60.7% | -27.4 | -69.3 to +41.8 |
| claude-opus-5-5-xhigh vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 51.6% | -18.3 | -61.8 to +48.2 |
| claude-sonnet-5-5-high vs gpt-5.6-terra-medium | 1/2 = 50.0% | 63.2% | -13.2 | -22.7 to -1.4 |
| claude-sonnet-5-5-high vs gpt-6-astra-high | 2/4 = 50.0% | 30.3% | +19.7 | -31.5 to +73.8 |
| claude-sonnet-5-5-high vs gpt-6-astra-low | 2/4 = 50.0% | 37.5% | +12.5 | -38.6 to +66.0 |
| claude-sonnet-5-5-high vs gpt-6-astra-medium | 2/2 = 100.0% | 34.0% | +66.0 | +55.1 to +74.3 |
| claude-sonnet-5-5-high vs gpt-6-astra-off | 0/4 = 0.0% | 40.2% | -40.2 | -54.3 to -26.8 |
| claude-sonnet-5-5-high vs gpt-6-luna-medium | 1/2 = 50.0% | 84.5% | -34.5 | -40.1 to -26.7 |
| claude-sonnet-5-5-high vs gpt-6.1-sol-medium | 0/2 = 0.0% | 45.5% | -45.5 | -55.9 to -34.6 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-high | 3/3 = 100.0% | 42.6% | +57.4 | +42.8 to +71.7 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-low | 1/4 = 25.0% | 47.8% | -22.8 | -58.1 to +43.7 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-max | 1/4 = 25.0% | 27.6% | -2.6 | -34.3 to +66.8 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-medium | 1/3 = 33.3% | 40.1% | -6.8 | -48.5 to +62.4 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-off | 1/3 = 33.3% | 41.7% | -8.4 | -50.7 to +60.5 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-xhigh | 0/3 = 0.0% | 33.0% | -33.0 | -45.9 to -20.1 |
| claude-sonnet-5-5-low vs gpt-6-astra-high | 0/4 = 0.0% | 19.4% | -19.4 | -29.6 to -10.7 |
| claude-sonnet-5-5-low vs gpt-6-astra-low | 0/4 = 0.0% | 25.0% | -25.0 | -36.1 to -15.4 |
| claude-sonnet-5-5-low vs gpt-6-astra-medium | 0/2 = 0.0% | 22.3% | -22.3 | -30.3 to -15.1 |
| claude-sonnet-5-5-low vs gpt-6-astra-off | 0/4 = 0.0% | 27.2% | -27.2 | -39.1 to -16.9 |
| claude-sonnet-5-5-low vs gpt-6-luna-medium | 1/2 = 50.0% | 75.2% | -25.2 | -32.8 to -14.6 |
| claude-sonnet-5-5-low vs gpt-6.1-sol-medium | 1/2 = 50.0% | 31.7% | +18.3 | +7.9 to +27.1 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-high | 1/4 = 25.0% | 29.2% | -4.2 | -36.2 to +63.3 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-low | 3/4 = 75.0% | 33.8% | +41.2 | -23.0 to +74.7 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-max | 1/3 = 33.3% | 17.5% | +15.9 | -22.9 to +84.4 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-medium | 1/4 = 25.0% | 27.2% | -2.2 | -34.5 to +25.1 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-off | 0/4 = 0.0% | 28.5% | -28.5 | -40.8 to -17.8 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-xhigh | 1/4 = 25.0% | 21.5% | +3.5 | -27.5 to +71.9 |
| claude-sonnet-5-5-max vs gpt-6-astra-medium | 4/10 = 40.0% | 53.3% | -13.3 | -36.6 to +3.3 |
| claude-sonnet-5-5-max vs gpt-6-luna-medium | 2/2 = 100.0% | 92.3% | +7.7 | +4.6 to +11.8 |
| claude-sonnet-5-5-max vs gpt-6.1-sol-max | 6/10 = 60.0% | 54.1% | +5.9 | -11.4 to +31.7 |
| claude-sonnet-5-5-max vs gpt-6.1-sol-medium | 2/2 = 100.0% | 64.8% | +35.2 | +24.6 to +44.9 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-high | 1/2 = 50.0% | 61.2% | -11.2 | -22.0 to +1.3 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-low | 1/2 = 50.0% | 63.5% | -13.5 | -24.4 to -2.0 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-medium | 11/20 = 55.0% | 59.1% | -4.1 | -29.2 to +19.6 |
| claude-sonnet-5-5-medium vs gpt-5.6-terra-xhigh | 0/2 = 0.0% | 49.5% | -49.5 | -60.2 to -34.7 |
| claude-sonnet-5-5-medium vs gpt-6-astra-high | 3/4 = 75.0% | 26.8% | +48.2 | -25.0 to +80.4 |
| claude-sonnet-5-5-medium vs gpt-6-astra-low | 1/4 = 25.0% | 33.5% | -8.5 | -39.7 to +67.1 |
| claude-sonnet-5-5-medium vs gpt-6-astra-medium | 7/20 = 35.0% | 30.3% | +4.7 | -9.9 to +19.2 |
| claude-sonnet-5-5-medium vs gpt-6-astra-off | 2/4 = 50.0% | 36.2% | +13.8 | -37.4 to +67.2 |
| claude-sonnet-5-5-medium vs gpt-6-luna-low | 2/2 = 100.0% | 88.2% | +11.8 | +6.3 to +19.2 |
| claude-sonnet-5-5-medium vs gpt-6-luna-medium | 17/20 = 85.0% | 82.1% | +2.9 | -12.7 to +17.1 |
| claude-sonnet-5-5-medium vs gpt-6-luna-off | 2/2 = 100.0% | 87.9% | +12.1 | +6.8 to +19.3 |
| claude-sonnet-5-5-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 54.2% | -4.2 | -15.3 to +7.9 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 42.0% | +8.0 | -3.1 to +17.5 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-low | 1/2 = 50.0% | 37.9% | +12.1 | +0.4 to +22.0 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-max | 0/2 = 0.0% | 31.1% | -31.1 | -39.0 to -22.7 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-medium | 8/20 = 40.0% | 41.3% | -1.3 | -20.1 to +17.4 |
| claude-sonnet-5-5-medium vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 38.4% | +11.6 | +0.9 to +20.7 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-high | 0/4 = 0.0% | 38.5% | -38.5 | -50.8 to -26.4 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-low | 2/4 = 50.0% | 43.6% | +6.4 | -46.9 to +59.3 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-max | 1/4 = 25.0% | 24.3% | +0.7 | -30.6 to +69.8 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-medium | 1/4 = 25.0% | 36.1% | -11.1 | -42.5 to +57.7 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-off | 2/4 = 50.0% | 37.6% | +12.4 | -40.0 to +66.2 |
| claude-sonnet-5-5-medium vs gpt-6.1-terra-xhigh | 3/4 = 75.0% | 29.3% | +45.7 | -22.8 to +78.4 |
| claude-sonnet-5-5-off vs gpt-5.6-terra-medium | 1/2 = 50.0% | 56.5% | -6.5 | -16.2 to +4.1 |
| claude-sonnet-5-5-off vs gpt-6-astra-high | 0/4 = 0.0% | 24.7% | -24.7 | -35.6 to -14.5 |
| claude-sonnet-5-5-off vs gpt-6-astra-low | 1/4 = 25.0% | 31.2% | -6.2 | -38.4 to +50.7 |
| claude-sonnet-5-5-off vs gpt-6-astra-medium | 2/2 = 100.0% | 28.1% | +71.9 | +62.4 to +79.1 |
| claude-sonnet-5-5-off vs gpt-6-astra-off | 1/4 = 25.0% | 33.8% | -8.8 | -41.8 to +62.4 |
| claude-sonnet-5-5-off vs gpt-6-luna-medium | 2/2 = 100.0% | 80.5% | +19.5 | +12.7 to +27.3 |
| claude-sonnet-5-5-off vs gpt-6.1-sol-medium | 1/2 = 50.0% | 38.7% | +11.3 | +0.8 to +20.9 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-high | 0/4 = 0.0% | 36.0% | -36.0 | -49.1 to -23.5 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-low | 1/4 = 25.0% | 41.0% | -16.0 | -48.9 to +48.2 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-max | 1/4 = 25.0% | 22.4% | +2.6 | -28.8 to +72.0 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-medium | 0/4 = 0.0% | 33.7% | -33.7 | -45.5 to -22.7 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-off | 1/4 = 25.0% | 35.1% | -10.1 | -42.9 to +57.3 |
| claude-sonnet-5-5-off vs gpt-6.1-terra-xhigh | 1/4 = 25.0% | 27.2% | -2.2 | -33.8 to +68.7 |
| claude-sonnet-5-5-xhigh vs gpt-5.6-terra-medium | 2/2 = 100.0% | 74.3% | +25.7 | +18.4 to +33.6 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-high | 1/4 = 25.0% | 42.2% | -17.2 | -50.5 to +45.5 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-low | 3/4 = 75.0% | 50.2% | +24.8 | -29.9 to +58.9 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-medium | 1/2 = 50.0% | 46.5% | +3.5 | -6.6 to +13.0 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra-off | 4/4 = 100.0% | 53.1% | +46.9 | +33.5 to +60.4 |
| claude-sonnet-5-5-xhigh vs gpt-6-luna-medium | 2/2 = 100.0% | 90.2% | +9.8 | +6.1 to +14.0 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-sol-medium | 1/2 = 50.0% | 58.4% | -8.4 | -17.8 to +1.2 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-high | 2/3 = 66.7% | 55.5% | +11.2 | -57.3 to +53.6 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-low | 2/4 = 50.0% | 60.7% | -10.7 | -65.8 to +43.0 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-max | 2/4 = 50.0% | 39.0% | +11.0 | -41.6 to +64.3 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-medium | 2/3 = 66.7% | 53.0% | +13.7 | -53.1 to +55.8 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-off | 3/3 = 100.0% | 54.6% | +45.4 | +31.5 to +59.2 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-xhigh | 2/3 = 66.7% | 45.3% | +21.4 | -3.9 to +64.1 |
| gpt-5.6-terra-high vs gpt-6-astra-off | 0/1 = 0.0% | 26.4% | -26.4 | -41.1 to -15.8 |
| gpt-5.6-terra-high vs gpt-6-luna-medium | 1/2 = 50.0% | 74.4% | -24.4 | -33.6 to -12.3 |
| gpt-5.6-terra-high vs gpt-6.1-sol-medium | 1/2 = 50.0% | 30.8% | +19.2 | +7.0 to +28.0 |
| gpt-5.6-terra-low vs gpt-6-astra-medium | 0/2 = 0.0% | 20.0% | -20.0 | -28.5 to -12.2 |
| gpt-5.6-terra-low vs gpt-6.1-terra-high | 0/1 = 0.0% | 26.4% | -26.4 | -39.2 to -15.0 |
| gpt-5.6-terra-max vs gpt-6-astra-medium | 1/2 = 50.0% | 30.1% | +19.9 | +7.0 to +29.4 |
| gpt-5.6-terra-max vs gpt-6-luna-medium | 2/2 = 100.0% | 82.0% | +18.0 | +10.6 to +27.7 |
| gpt-5.6-terra-medium vs gpt-6-astra-medium | 5/20 = 25.0% | 23.1% | +1.9 | -13.2 to +17.7 |
| gpt-5.6-terra-medium vs gpt-6-astra-off | 0/1 = 0.0% | 28.2% | -28.2 | -39.0 to -17.8 |
| gpt-5.6-terra-medium vs gpt-6-luna-high | 2/2 = 100.0% | 55.6% | +44.4 | +30.8 to +57.8 |
| gpt-5.6-terra-medium vs gpt-6-luna-low | 1/2 = 50.0% | 83.8% | -33.8 | -40.8 to -22.6 |
| gpt-5.6-terra-medium vs gpt-6-luna-max | 2/2 = 100.0% | 47.5% | +52.5 | +38.0 to +63.9 |
| gpt-5.6-terra-medium vs gpt-6-luna-medium | 15/20 = 75.0% | 76.0% | -1.0 | -21.6 to +18.3 |
| gpt-5.6-terra-medium vs gpt-6-luna-off | 2/2 = 100.0% | 83.4% | +16.6 | +9.7 to +25.3 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-high | 0/2 = 0.0% | 33.4% | -33.4 | -43.1 to -23.7 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-low | 0/2 = 0.0% | 29.7% | -29.7 | -39.6 to -20.3 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-max | 0/2 = 0.0% | 23.7% | -23.7 | -31.2 to -16.8 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-medium | 6/20 = 30.0% | 32.7% | -2.7 | -18.2 to +13.1 |
| gpt-5.6-terra-medium vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 30.1% | -30.1 | -39.4 to -21.4 |
| gpt-5.6-terra-medium vs gpt-6.1-terra-off | 0/1 = 0.0% | 29.4% | -29.4 | -40.3 to -19.2 |
| gpt-5.6-terra-medium vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 22.3% | -22.3 | -32.0 to -13.5 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-high | 1/1 = 100.0% | 27.1% | +72.9 | +56.4 to +84.2 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-low | 1/1 = 100.0% | 33.9% | +66.1 | +48.3 to +78.5 |
| gpt-5.6-terra-xhigh vs gpt-6-astra-medium | 0/2 = 0.0% | 30.7% | -30.7 | -41.8 to -20.2 |
| gpt-5.6-terra-xhigh vs gpt-6.1-sol-medium | 0/2 = 0.0% | 41.7% | -41.7 | -54.6 to -29.4 |
| gpt-5.6-terra-xhigh vs gpt-6.1-terra-low | 0/1 = 0.0% | 44.0% | -44.0 | -59.0 to -28.2 |
| gpt-6-astra-high vs gpt-6.1-sol-high | 1/1 = 100.0% | 66.5% | +33.5 | +19.3 to +47.6 |
| gpt-6-astra-high vs gpt-6.1-sol-medium | 1/2 = 50.0% | 65.8% | -15.8 | -27.1 to -3.8 |
| gpt-6-astra-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 63.1% | +36.9 | +22.2 to +53.1 |
| gpt-6-astra-high vs gpt-6.1-terra-low | 2/2 = 100.0% | 67.9% | +32.1 | +18.0 to +46.7 |
| gpt-6-astra-high vs gpt-6.1-terra-max | 1/2 = 50.0% | 46.8% | +3.2 | -56.7 to +61.8 |
| gpt-6-astra-high vs gpt-6.1-terra-medium | 0/1 = 0.0% | 60.7% | -60.7 | -74.5 to -44.3 |
| gpt-6-astra-high vs gpt-6.1-terra-off | 1/1 = 100.0% | 62.2% | +37.8 | +22.1 to +53.4 |
| gpt-6-astra-high vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 53.2% | -53.2 | -69.2 to -35.3 |
| gpt-6-astra-low vs gpt-6-luna-medium | 2/2 = 100.0% | 90.1% | +9.9 | +5.4 to +15.7 |
| gpt-6-astra-low vs gpt-6.1-sol-low | 0/1 = 0.0% | 54.8% | -54.8 | -67.8 to -39.5 |
| gpt-6-astra-low vs gpt-6.1-sol-medium | 1/2 = 50.0% | 58.2% | -8.2 | -20.3 to +4.0 |
| gpt-6-astra-low vs gpt-6.1-terra-high | 1/1 = 100.0% | 55.3% | +44.7 | +29.3 to +59.0 |
| gpt-6-astra-low vs gpt-6.1-terra-low | 0/1 = 0.0% | 60.5% | -60.5 | -73.6 to -45.0 |
| gpt-6-astra-low vs gpt-6.1-terra-max | 0/2 = 0.0% | 38.9% | -38.9 | -54.8 to -24.3 |
| gpt-6-astra-low vs gpt-6.1-terra-medium | 1/1 = 100.0% | 52.8% | +47.2 | +31.9 to +61.9 |
| gpt-6-astra-low vs gpt-6.1-terra-off | 0/1 = 0.0% | 54.4% | -54.4 | -68.8 to -38.5 |
| gpt-6-astra-low vs gpt-6.1-terra-xhigh | 1/1 = 100.0% | 45.1% | +54.9 | +38.3 to +69.4 |
| gpt-6-astra-medium vs gpt-6-luna-high | 1/2 = 50.0% | 80.6% | -30.6 | -38.3 to -19.2 |
| gpt-6-astra-medium vs gpt-6-luna-max | 2/2 = 100.0% | 75.1% | +24.9 | +15.7 to +35.8 |
| gpt-6-astra-medium vs gpt-6-luna-medium | 19/20 = 95.0% | 91.3% | +3.7 | -7.9 to +10.7 |
| gpt-6-astra-medium vs gpt-6-luna-off | 2/2 = 100.0% | 94.3% | +5.7 | +3.1 to +9.1 |
| gpt-6-astra-medium vs gpt-6-luna-xhigh | 1/2 = 50.0% | 73.2% | -23.2 | -31.6 to -11.5 |
| gpt-6-astra-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 62.5% | -12.5 | -21.9 to -2.3 |
| gpt-6-astra-medium vs gpt-6.1-sol-low | 3/4 = 75.0% | 58.4% | +16.6 | -14.1 to +48.8 |
| gpt-6-astra-medium vs gpt-6.1-sol-max | 6/10 = 60.0% | 50.9% | +9.1 | -6.6 to +32.7 |
| gpt-6-astra-medium vs gpt-6.1-sol-medium | 12/20 = 60.0% | 61.8% | -1.8 | -20.3 to +16.6 |
| gpt-6-astra-medium vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 58.9% | -58.9 | -68.5 to -46.7 |
| gpt-6-astra-medium vs gpt-6.1-terra-max | 0/1 = 0.0% | 42.5% | -42.5 | -55.5 to -28.8 |
| gpt-6-astra-off vs gpt-6-luna-xhigh | 1/1 = 100.0% | 67.6% | +32.4 | +19.9 to +46.9 |
| gpt-6-astra-off vs gpt-6.1-sol-medium | 0/1 = 0.0% | 55.4% | -55.4 | -66.8 to -42.6 |
| gpt-6-astra-off vs gpt-6.1-terra-high | 1/1 = 100.0% | 52.4% | +47.6 | +32.1 to +63.8 |
| gpt-6-astra-off vs gpt-6.1-terra-low | 2/2 = 100.0% | 57.7% | +42.3 | +27.4 to +57.6 |
| gpt-6-astra-off vs gpt-6.1-terra-max | 0/1 = 0.0% | 36.1% | -36.1 | -52.5 to -21.9 |
| gpt-6-astra-off vs gpt-6.1-terra-medium | 0/1 = 0.0% | 49.9% | -49.9 | -64.5 to -33.9 |
| gpt-6-astra-off vs gpt-6.1-terra-off | 1/1 = 100.0% | 51.5% | +48.5 | +32.1 to +62.8 |
| gpt-6-astra-off vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 42.2% | +7.8 | -49.7 to +68.0 |
| gpt-6-luna-high vs gpt-6.1-sol-medium | 1/2 = 50.0% | 28.0% | +22.0 | +8.8 to +32.4 |
| gpt-6-luna-high vs gpt-6.1-terra-high | 1/1 = 100.0% | 25.7% | +74.3 | +57.5 to +85.3 |
| gpt-6-luna-high vs gpt-6.1-terra-off | 0/1 = 0.0% | 25.0% | -25.0 | -37.1 to -13.5 |
| gpt-6-luna-low vs gpt-6.1-sol-medium | 0/2 = 0.0% | 8.6% | -8.6 | -14.3 to -4.6 |
| gpt-6-luna-max vs gpt-6.1-sol-medium | 0/2 = 0.0% | 35.0% | -35.0 | -45.9 to -23.3 |
| gpt-6-luna-max vs gpt-6.1-terra-off | 1/2 = 50.0% | 31.5% | +18.5 | +3.4 to +30.4 |
| gpt-6-luna-medium vs gpt-6.1-sol-high | 1/2 = 50.0% | 13.6% | +36.4 | +29.2 to +41.3 |
| gpt-6-luna-medium vs gpt-6.1-sol-low | 0/2 = 0.0% | 11.8% | -11.8 | -18.2 to -7.0 |
| gpt-6-luna-medium vs gpt-6.1-sol-max | 0/2 = 0.0% | 8.9% | -8.9 | -12.9 to -5.5 |
| gpt-6-luna-medium vs gpt-6.1-sol-medium | 3/20 = 15.0% | 13.3% | +1.7 | -12.1 to +17.9 |
| gpt-6-luna-medium vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 12.0% | -12.0 | -17.8 to -7.2 |
| gpt-6-luna-off vs gpt-6.1-sol-medium | 1/2 = 50.0% | 8.8% | +41.2 | +35.3 to +44.9 |
| gpt-6-luna-xhigh vs gpt-6.1-sol-medium | 1/2 = 50.0% | 37.2% | +12.8 | +0.6 to +23.5 |
| gpt-6-luna-xhigh vs gpt-6.1-terra-low | 1/2 = 50.0% | 39.5% | +10.5 | -4.6 to +23.9 |
| gpt-6.1-sol-high vs gpt-6.1-terra-medium | 1/2 = 50.0% | 43.8% | +6.2 | -6.8 to +19.6 |
| gpt-6.1-sol-low vs gpt-6.1-terra-max | 1/1 = 100.0% | 34.4% | +65.6 | +50.1 to +78.0 |
| gpt-6.1-sol-max vs gpt-6.1-terra-max | 1/2 = 50.0% | 41.6% | +8.4 | -5.2 to +21.7 |
| gpt-6.1-sol-medium vs gpt-6.1-terra-low | 1/1 = 100.0% | 52.4% | +47.6 | +34.2 to +60.2 |
| gpt-6.1-sol-medium vs gpt-6.1-terra-max | 1/1 = 100.0% | 31.3% | +68.7 | +55.7 to +79.6 |
| gpt-6.1-sol-medium vs gpt-6.1-terra-medium | 1/2 = 50.0% | 44.5% | +5.5 | -5.9 to +17.2 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-high | 1/2 = 50.0% | 50.1% | -0.1 | -14.3 to +14.8 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-max | 0/1 = 0.0% | 34.0% | -34.0 | -46.9 to -21.3 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 40.0% | +10.0 | -4.4 to +23.7 |
#### claude-haiku-4-5-20251001 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-low | 8/20 = 40.0% | 45.7% | -5.7 | -23.3 to +11.4 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-medium | 11/20 = 55.0% | 37.5% | +17.5 | +2.8 to +34.7 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal | 11/20 = 55.0% | 43.5% | +11.5 | -6.9 to +31.6 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 65.0% | -0.0 | -20.2 to +17.0 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-medium | 8/20 = 40.0% | 41.6% | -1.6 | -20.0 to +16.7 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-minimal | 6/20 = 30.0% | 47.7% | -17.7 | -37.1 to +2.0 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-off | 15/20 = 75.0% | 68.8% | +6.2 | -8.9 to +22.7 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-4-5-20251001-minimal | 10/20 = 50.0% | 56.2% | -6.2 | -25.8 to +13.8 |
| claude-haiku-4-5-20251001-medium vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 75.6% | +4.4 | -10.6 to +21.2 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 70.8% | -5.8 | -28.9 to +14.3 |
#### claude-haiku-5-5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 54.6% | +10.4 | -10.2 to +30.8 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 44.2% | +0.8 | -18.7 to +19.6 |
| claude-haiku-5-5-high vs claude-haiku-5-5-medium | 13/20 = 65.0% | 53.9% | +11.1 | -2.8 to +26.9 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 72.6% | -7.6 | -21.5 to +7.2 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 45.8% | -15.8 | -31.8 to -1.3 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 39.7% | -4.7 | -22.7 to +13.8 |
| claude-haiku-5-5-low vs claude-haiku-5-5-medium | 12/20 = 60.0% | 49.3% | +10.7 | -8.0 to +29.9 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 68.8% | -13.8 | -34.9 to +6.1 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 41.3% | -1.3 | -16.0 to +11.2 |
| claude-haiku-5-5-max vs claude-haiku-5-5-medium | 11/20 = 55.0% | 59.6% | -4.6 | -20.8 to +10.6 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 77.0% | +3.0 | -12.2 to +18.3 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 51.6% | -6.6 | -22.9 to +8.9 |
| claude-haiku-5-5-medium vs claude-haiku-5-5-off | 14/20 = 70.0% | 69.4% | +0.6 | -14.1 to +16.0 |
| claude-haiku-5-5-medium vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 41.9% | -6.9 | -26.4 to +12.5 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 24.1% | +0.9 | -16.4 to +22.0 |
#### claude-opus-5-5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5-high vs claude-opus-5-5-low | 1/2 = 50.0% | 70.7% | -20.7 | -77.2 to +34.4 |
| claude-opus-5-5-high vs claude-opus-5-5-max | 1/2 = 50.0% | 39.7% | +10.3 | -47.4 to +68.5 |
| claude-opus-5-5-high vs claude-opus-5-5-medium | 11/20 = 55.0% | 59.7% | -4.7 | -24.4 to +14.2 |
| claude-opus-5-5-high vs claude-opus-5-5-off | 3/5 = 60.0% | 55.1% | +4.9 | -43.4 to +49.3 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 46.5% | -11.5 | -29.5 to +5.4 |
| claude-opus-5-5-low vs claude-opus-5-5-max | 3/10 = 30.0% | 21.4% | +8.6 | -21.2 to +49.9 |
| claude-opus-5-5-low vs claude-opus-5-5-medium | 7/20 = 35.0% | 37.9% | -2.9 | -18.3 to +10.9 |
| claude-opus-5-5-low vs claude-opus-5-5-off | 3/5 = 60.0% | 33.7% | +26.3 | -23.7 to +72.1 |
| claude-opus-5-5-low vs claude-opus-5-5-xhigh | 0/3 = 0.0% | 26.5% | -26.5 | -37.5 to -16.6 |
| claude-opus-5-5-max vs claude-opus-5-5-medium | 6/10 = 60.0% | 69.2% | -9.2 | -44.5 to +25.3 |
| claude-opus-5-5-max vs claude-opus-5-5-off | 2/2 = 100.0% | 65.1% | +34.9 | +20.9 to +49.4 |
| claude-opus-5-5-max vs claude-opus-5-5-xhigh | 5/10 = 50.0% | 57.0% | -7.0 | -34.6 to +23.8 |
| claude-opus-5-5-medium vs claude-opus-5-5-off | 3/4 = 75.0% | 45.4% | +29.6 | +2.8 to +64.0 |
| claude-opus-5-5-medium vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 37.0% | -2.0 | -17.0 to +11.9 |
| claude-opus-5-5-off vs claude-opus-5-5-xhigh | 3/4 = 75.0% | 41.5% | +33.5 | -29.4 to +67.7 |
#### claude-sonnet-5-5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 64.3% | -9.3 | -34.2 to +14.5 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 31.2% | +8.8 | -13.2 to +31.3 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-medium | 13/20 = 65.0% | 54.3% | +10.7 | -9.0 to +31.4 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 56.9% | +13.1 | -2.1 to +29.7 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 37.3% | -12.3 | -32.4 to +7.1 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 20.1% | -5.1 | -19.3 to +10.8 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-medium | 9/20 = 45.0% | 39.8% | +5.2 | -15.7 to +25.6 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 42.3% | +7.7 | -10.9 to +26.6 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 24.9% | -4.9 | -20.4 to +10.8 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-medium | 12/20 = 60.0% | 72.4% | -12.4 | -30.0 to +5.1 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 74.5% | -4.5 | -28.3 to +17.9 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 56.8% | +8.2 | -12.4 to +27.4 |
| claude-sonnet-5-5-medium vs claude-sonnet-5-5-off | 10/20 = 50.0% | 52.7% | -2.7 | -20.5 to +15.8 |
| claude-sonnet-5-5-medium vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 33.4% | +11.6 | -9.1 to +33.6 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 31.0% | +24.0 | +13.7 to +37.1 |
#### gpt-5.6-terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 52.5% | -7.5 | -27.3 to +10.0 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.0% | +1.0 | -16.0 to +18.3 |
| gpt-5.6-terra-high vs gpt-5.6-terra-medium | 10/20 = 50.0% | 47.8% | +2.2 | -11.7 to +17.1 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 38.4% | +11.6 | -6.6 to +32.0 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 36.7% | +3.3 | -15.9 to +23.4 |
| gpt-5.6-terra-low vs gpt-5.6-terra-medium | 9/20 = 45.0% | 45.4% | -0.4 | -17.2 to +15.3 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 36.0% | -16.0 | -32.5 to -1.7 |
| gpt-5.6-terra-max vs gpt-5.6-terra-medium | 12/20 = 60.0% | 58.9% | +1.1 | -20.0 to +20.5 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 49.3% | +5.7 | -10.2 to +22.1 |
| gpt-5.6-terra-medium vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 40.4% | -5.4 | -20.8 to +7.6 |
#### gpt-6-astra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-astra-high vs gpt-6-astra-low | 2/2 = 100.0% | 58.0% | +42.0 | +26.9 to +57.3 |
| gpt-6-astra-high vs gpt-6-astra-medium | 1/2 = 50.0% | 54.3% | -4.3 | -18.6 to +7.8 |
| gpt-6-astra-high vs gpt-6-astra-off | 0/1 = 0.0% | 60.8% | -60.8 | -75.2 to -44.1 |
| gpt-6-astra-low vs gpt-6-astra-medium | 0/2 = 0.0% | 46.3% | -46.3 | -57.4 to -33.9 |
| gpt-6-astra-low vs gpt-6-astra-off | 2/2 = 100.0% | 52.9% | +47.1 | +31.0 to +61.8 |
#### gpt-6-luna efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-luna-high vs gpt-6-luna-low | 14/20 = 70.0% | 80.5% | -10.5 | -25.2 to +4.6 |
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 42.0% | -7.0 | -26.0 to +13.0 |
| gpt-6-luna-high vs gpt-6-luna-medium | 12/20 = 60.0% | 71.7% | -11.7 | -33.8 to +7.7 |
| gpt-6-luna-high vs gpt-6-luna-off | 18/20 = 90.0% | 80.0% | +10.0 | -3.5 to +22.6 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 39.6% | +15.4 | -3.0 to +35.4 |
| gpt-6-luna-low vs gpt-6-luna-max | 2/20 = 10.0% | 14.9% | -4.9 | -16.1 to +7.8 |
| gpt-6-luna-low vs gpt-6-luna-medium | 8/20 = 40.0% | 38.1% | +1.9 | -20.3 to +26.0 |
| gpt-6-luna-low vs gpt-6-luna-off | 8/20 = 40.0% | 49.3% | -9.3 | -25.0 to +7.4 |
| gpt-6-luna-low vs gpt-6-luna-xhigh | 3/20 = 15.0% | 13.7% | +1.3 | -12.7 to +21.9 |
| gpt-6-luna-max vs gpt-6-luna-medium | 15/20 = 75.0% | 77.8% | -2.8 | -18.4 to +12.0 |
| gpt-6-luna-max vs gpt-6-luna-off | 16/20 = 80.0% | 84.7% | -4.7 | -19.0 to +9.1 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 47.5% | +2.5 | -11.5 to +17.5 |
| gpt-6-luna-medium vs gpt-6-luna-off | 12/20 = 60.0% | 61.2% | -1.2 | -23.4 to +18.2 |
| gpt-6-luna-medium vs gpt-6-luna-xhigh | 2/20 = 10.0% | 20.5% | -10.5 | -23.4 to +2.1 |
| gpt-6-luna-off vs gpt-6-luna-xhigh | 2/20 = 10.0% | 14.1% | -4.1 | -15.7 to +7.8 |
#### gpt-6.1-sol efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 45.7% | +14.3 | -1.3 to +32.8 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 38.3% | +6.7 | -11.4 to +26.1 |
| gpt-6.1-sol-high vs gpt-6.1-sol-medium | 8/20 = 40.0% | 49.3% | -9.3 | -23.6 to +2.9 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 46.2% | -1.2 | -16.9 to +13.8 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 42.4% | -12.4 | -30.7 to +6.4 |
| gpt-6.1-sol-low vs gpt-6.1-sol-medium | 13/20 = 65.0% | 53.5% | +11.5 | -6.2 to +31.1 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 50.5% | +9.5 | -6.3 to +27.3 |
| gpt-6.1-sol-max vs gpt-6.1-sol-medium | 12/20 = 60.0% | 61.0% | -1.0 | -18.6 to +17.5 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 58.0% | -8.0 | -22.8 to +6.0 |
| gpt-6.1-sol-medium vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 47.0% | +3.0 | -17.6 to +25.6 |
#### gpt-6.1-terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-terra-high vs gpt-6.1-terra-low | 0/1 = 0.0% | 55.3% | -55.3 | -70.1 to -39.2 |
| gpt-6.1-terra-high vs gpt-6.1-terra-max | 0/1 = 0.0% | 33.9% | -33.9 | -51.3 to -20.5 |
| gpt-6.1-terra-high vs gpt-6.1-terra-medium | 2/3 = 66.7% | 47.5% | +19.2 | -7.1 to +61.6 |
| gpt-6.1-terra-high vs gpt-6.1-terra-off | 1/2 = 50.0% | 49.1% | +0.9 | -58.0 to +58.5 |
| gpt-6.1-terra-high vs gpt-6.1-terra-xhigh | 1/3 = 33.3% | 39.9% | -6.6 | -46.7 to +66.6 |
| gpt-6.1-terra-low vs gpt-6.1-terra-max | 1/1 = 100.0% | 29.3% | +70.7 | +53.5 to +82.7 |
| gpt-6.1-terra-low vs gpt-6.1-terra-medium | 1/3 = 33.3% | 42.2% | -8.9 | -51.4 to +16.5 |
| gpt-6.1-terra-low vs gpt-6.1-terra-off | 3/3 = 100.0% | 43.8% | +56.2 | +40.0 to +70.6 |
| gpt-6.1-terra-low vs gpt-6.1-terra-xhigh | 0/1 = 0.0% | 34.9% | -34.9 | -49.6 to -19.7 |
| gpt-6.1-terra-max vs gpt-6.1-terra-medium | 1/1 = 100.0% | 63.8% | +36.2 | +22.2 to +50.9 |
| gpt-6.1-terra-max vs gpt-6.1-terra-off | 0/1 = 0.0% | 65.2% | -65.2 | -77.4 to -48.7 |
| gpt-6.1-terra-max vs gpt-6.1-terra-xhigh | 3/3 = 100.0% | 56.4% | +43.6 | +27.7 to +60.8 |
| gpt-6.1-terra-medium vs gpt-6.1-terra-off | 2/3 = 66.7% | 51.6% | +15.1 | -10.9 to +57.7 |
| gpt-6.1-terra-medium vs gpt-6.1-terra-xhigh | 3/3 = 100.0% | 42.3% | +57.7 | +41.5 to +72.8 |
| gpt-6.1-terra-off vs gpt-6.1-terra-xhigh | 0/2 = 0.0% | 40.8% | -40.8 | -55.3 to -25.8 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| Cross-model | 0.5959 | 0.5960 | -0.0001 | -0.0002 to -0.0000 | 0: 41, 0.1: 4, 0.2: 5 | tau=0.1: 0.5959, tau=0.2: 0.5962, tau=0.4: 0.5974, tau=0.8: 0.6029, tau=1.6: 0.6218 | not kept |
| Cross-model (seat and starter terms) | 0.5856 | 0.5858 | -0.0002 | -0.0004 to -0.0001 | 0: 41, 0.1: 3, 0.2: 6 | tau=0.1: 0.5857, tau=0.2: 0.5860, tau=0.4: 0.5874, tau=0.8: 0.5932, tau=1.6: 0.6128 | not kept |
| claude-haiku-4-5-20251001 efforts | 0.6740 | 0.6791 | -0.0050 | -0.0096 to -0.0007 | 0: 23, 0.1: 5, 0.2: 12, 0.4: 8, 0.8: 2 | tau=0.1: 0.6741, tau=0.2: 0.6745, tau=0.4: 0.6772, tau=0.8: 0.6847, tau=1.6: 0.6916 | not kept |
| claude-haiku-4-5-20251001 efforts (seat and starter terms) | 0.6691 | 0.6743 | -0.0052 | -0.0111 to +0.0001 | 0: 29, 0.1: 1, 0.2: 4, 0.4: 15, 0.8: 1 | tau=0.1: 0.6690, tau=0.2: 0.6689, tau=0.4: 0.6706, tau=0.8: 0.6767, tau=1.6: 0.6828 | not kept |
| claude-haiku-5-5 efforts | 0.6637 | 0.6649 | -0.0012 | -0.0023 to -0.0003 | 0: 46, 0.1: 2, 0.2: 1, 0.8: 1 | tau=0.1: 0.6642, tau=0.2: 0.6655, tau=0.4: 0.6701, tau=0.8: 0.6791, tau=1.6: 0.6866 | not kept |
| claude-haiku-5-5 efforts (seat and starter terms) | 0.6377 | 0.6382 | -0.0005 | -0.0009 to -0.0001 | 0: 42, 0.1: 3, 0.2: 5 | tau=0.1: 0.6379, tau=0.2: 0.6386, tau=0.4: 0.6416, tau=0.8: 0.6486, tau=1.6: 0.6550 | not kept |
| claude-opus-5-5 efforts | 0.6939 | 0.6947 | -0.0008 | -0.0019 to +0.0002 | 0: 49, 0.4: 1 | tau=0.1: 0.6945, tau=0.2: 0.6963, tau=0.4: 0.7021, tau=0.8: 0.7161, tau=1.6: 0.7416 | not kept |
| claude-opus-5-5 efforts (seat and starter terms) | 0.7075 | 0.7077 | -0.0002 | -0.0005 to +0.0001 | 0: 49, 0.2: 1 | tau=0.1: 0.7083, tau=0.2: 0.7106, tau=0.4: 0.7176, tau=0.8: 0.7327, tau=1.6: 0.7556 | not kept |
| claude-sonnet-5-5 efforts | 0.6729 | 0.6776 | -0.0046 | -0.0115 to +0.0016 | 0: 13, 0.1: 3, 0.2: 13, 0.4: 18, 0.8: 3 | tau=0.1: 0.6725, tau=0.2: 0.6718, tau=0.4: 0.6724, tau=0.8: 0.6788, tau=1.6: 0.6865 | not kept |
| claude-sonnet-5-5 efforts (seat and starter terms) | 0.6722 | 0.6740 | -0.0018 | -0.0065 to +0.0026 | 0: 11, 0.1: 3, 0.2: 19, 0.4: 17 | tau=0.1: 0.6718, tau=0.2: 0.6713, tau=0.4: 0.6720, tau=0.8: 0.6783, tau=1.6: 0.6858 | not kept |
| gpt-5.6-terra efforts | 0.6940 | 0.6980 | -0.0040 | -0.0072 to -0.0012 | 0: 33, 0.1: 3, 0.2: 8, 0.4: 6 | tau=0.1: 0.6942, tau=0.2: 0.6951, tau=0.4: 0.6984, tau=0.8: 0.7056, tau=1.6: 0.7118 | not kept |
| gpt-5.6-terra efforts (seat and starter terms) | 0.6973 | 0.7011 | -0.0038 | -0.0068 to -0.0014 | 0: 37, 0.1: 3, 0.2: 4, 0.4: 6 | tau=0.1: 0.6976, tau=0.2: 0.6985, tau=0.4: 0.7020, tau=0.8: 0.7096, tau=1.6: 0.7163 | not kept |
| gpt-6-astra efforts | - | - | - | - | - | - | 7 seed blocks, under the minimum of 10: the fit with seat and starter terms can be singular on so few, so not tested |
| gpt-6-luna efforts | 0.5755 | 0.5788 | -0.0033 | -0.0058 to -0.0010 | 0: 28, 0.1: 3, 0.2: 12, 0.4: 7 | tau=0.1: 0.5757, tau=0.2: 0.5763, tau=0.4: 0.5793, tau=0.8: 0.5878, tau=1.6: 0.5976 | not kept |
| gpt-6-luna efforts (seat and starter terms) | 0.5808 | 0.5836 | -0.0029 | -0.0051 to -0.0007 | 0: 31, 0.1: 4, 0.2: 9, 0.4: 5, 0.8: 1 | tau=0.1: 0.5809, tau=0.2: 0.5813, tau=0.4: 0.5838, tau=0.8: 0.5920, tau=1.6: 0.6028 | not kept |
| gpt-6.1-sol efforts | 0.7053 | 0.7102 | -0.0049 | -0.0120 to +0.0009 | 0: 18, 0.1: 3, 0.2: 13, 0.4: 15, 0.8: 1 | tau=0.1: 0.7051, tau=0.2: 0.7050, tau=0.4: 0.7068, tau=0.8: 0.7133, tau=1.6: 0.7194 | not kept |
| gpt-6.1-sol efforts (seat and starter terms) | 0.7101 | 0.7133 | -0.0032 | -0.0082 to +0.0011 | 0: 19, 0.1: 5, 0.2: 9, 0.4: 16, 0.8: 1 | tau=0.1: 0.7099, tau=0.2: 0.7096, tau=0.4: 0.7107, tau=0.8: 0.7159, tau=1.6: 0.7212 | not kept |
| gpt-6.1-terra efforts | 0.8130 | 0.8504 | -0.0374 | -0.1243 to +0.0295 | 0: 9, 0.2: 1, 0.4: 8, 0.8: 14, 1.6: 18 | tau=0.1: 0.8124, tau=0.2: 0.8106, tau=0.4: 0.8045, tau=0.8: 0.7911, tau=1.6: 0.7949 | not kept |
| gpt-6.1-terra efforts (seat and starter terms) | 1.0156 | 1.0255 | -0.0098 | -0.0761 to +0.0442 | 0: 10, 0.2: 3, 0.4: 4, 0.8: 20, 1.6: 13 | tau=0.1: 1.0149, tau=0.2: 1.0129, tau=0.4: 1.0058, tau=0.8: 0.9901, tau=1.6: 0.9934 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| Cross-model | 237/423 = 56.0% | -0.10 |
| claude-haiku-4-5-20251001 efforts | 7/10 = 70.0% | +0.09 |
| claude-haiku-5-5 efforts | 5/15 = 33.3% | -0.45 |
| claude-opus-5-5 efforts | 4/15 = 26.7% | -0.30 |
| claude-sonnet-5-5 efforts | 6/15 = 40.0% | -0.04 |
| gpt-5.6-terra efforts | 4/10 = 40.0% | -0.15 |
| gpt-6-luna efforts | 7/15 = 46.7% | -0.14 |
| gpt-6.1-sol efforts | 6/10 = 60.0% | -0.18 |
| gpt-6.1-terra efforts | 6/8 = 75.0% | +0.53 |
| all cohorts pooled | 282/521 = 54.1% | -0.09 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 1.1e-16, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 3709 of 3709 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 1478 blocks, 128 seeds (753 matches in half blocks left out) | 1492/2956 = 50.5% | 43.8% to 57.8% | 48.7% to 52.3% |
| Cross-model: 661 blocks, 118 seeds (710 matches in half blocks left out) | 644/1322 = 48.7% | 42.1% to 55.8% | 46.1% to 51.4% |
| claude-haiku-4-5-20251001 efforts: 100 blocks, 10 seeds | 105/200 = 52.5% | 42.5% to 60.0% | 45.5% to 59.5% |
| claude-haiku-5-5 efforts: 150 blocks, 10 seeds | 142/300 = 47.3% | 34.7% to 60.0% | 41.3% to 53.3% |
| claude-opus-5-5 efforts: 58 blocks, 18 seeds (21 matches in half blocks left out) | 61/116 = 52.6% | 39.3% to 65.8% | 43.1% to 62.1% |
| claude-sonnet-5-5 efforts: 150 blocks, 10 seeds | 162/300 = 54.0% | 42.3% to 64.7% | 48.7% to 59.7% |
| gpt-5.6-terra efforts: 100 blocks, 10 seeds | 96/200 = 48.0% | 37.0% to 59.0% | 40.5% to 55.5% |
| gpt-6-astra efforts: 2 blocks, 1 seeds (5 matches in half blocks left out) | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% |
| gpt-6-luna efforts: 150 blocks, 10 seeds | 160/300 = 53.3% | 47.0% to 59.3% | 48.3% to 58.3% |
| gpt-6.1-sol efforts: 100 blocks, 10 seeds | 111/200 = 55.5% | 42.5% to 68.5% | 48.0% to 62.5% |
| gpt-6.1-terra efforts: 7 blocks, 7 seeds (17 matches in half blocks left out) | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 1676/2956 = 56.7% | 50.6% to 62.8% | 54.9% to 58.4% | 718/1478 |
| Cross-model | 766/1322 = 57.9% | 51.8% to 63.4% | 55.3% to 60.7% | 306/661 |
| claude-haiku-4-5-20251001 efforts | 115/200 = 57.5% | 50.5% to 66.0% | 51.0% to 64.0% | 50/100 |
| claude-haiku-5-5 efforts | 186/300 = 62.0% | 51.0% to 72.0% | 56.3% to 67.7% | 75/150 |
| claude-opus-5-5 efforts | 67/116 = 57.8% | 44.8% to 70.4% | 48.3% to 67.2% | 31/58 |
| claude-sonnet-5-5 efforts | 164/300 = 54.7% | 43.3% to 65.0% | 49.0% to 60.0% | 75/150 |
| gpt-5.6-terra efforts | 108/200 = 54.0% | 42.5% to 65.0% | 46.5% to 61.0% | 50/100 |
| gpt-6-astra efforts | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% | 2/2 |
| gpt-6-luna efforts | 152/300 = 50.7% | 44.3% to 57.0% | 46.0% to 55.7% | 75/150 |
| gpt-6.1-sol efforts | 107/200 = 53.5% | 40.0% to 67.0% | 46.0% to 61.0% | 50/100 |
| gpt-6.1-terra efforts | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% | 4/7 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +0.7 | -5.7 to +6.7 | -1.2 to +2.4 | +6.7 | +0.3 to +12.7 | +4.9 to +8.4 |
| Cross-model | -0.7 | -6.9 to +5.0 | -3.2 to +1.9 | +7.9 | +1.3 to +13.4 | +5.3 to +10.6 |
| claude-haiku-4-5-20251001 efforts | +2.5 | -6.0 to +9.4 | -4.3 to +9.2 | +7.5 | +0.8 to +16.0 | +1.0 to +14.4 |
| claude-haiku-5-5 efforts | -2.7 | -14.0 to +8.1 | -8.2 to +2.9 | +12.0 | +0.6 to +22.3 | +6.4 to +17.7 |
| claude-opus-5-5 efforts | +2.1 | -10.6 to +15.0 | -7.8 to +11.6 | +7.6 | -5.8 to +20.4 | -2.0 to +16.9 |
| claude-sonnet-5-5 efforts | +4.0 | -7.9 to +14.6 | -1.4 to +9.7 | +4.7 | -7.2 to +15.0 | -1.1 to +10.2 |
| gpt-5.6-terra efforts | -2.0 | -14.4 to +8.5 | -9.5 to +5.4 | +4.0 | -8.1 to +15.4 | -3.3 to +11.2 |
| gpt-6-luna efforts | +3.3 | -3.1 to +9.4 | -1.8 to +8.3 | +0.7 | -5.8 to +6.9 | -4.0 to +5.6 |
| gpt-6.1-sol efforts | +5.5 | -7.6 to +18.6 | -2.4 to +12.5 | +3.5 | -10.3 to +16.7 | -4.3 to +11.1 |
| gpt-6.1-terra efforts | +6.2 | -20.8 to +33.3 | -20.0 to +35.0 | +6.2 | -20.8 to +33.3 | -20.0 to +33.3 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| Engine/2/20000: 48 blocks, 10 seeds | 62/96 = 64.6% | 52.1% to 77.0% | 55.2% to 74.0% |
| Engine/6/20000/sampled: 38 blocks, 10 seeds | 38/76 = 50.0% | 32.9% to 69.7% | 38.2% to 63.2% |
| claude-haiku-4-5-20251001: 271 blocks, 73 seeds | 270/542 = 49.8% | 43.8% to 55.4% | 45.8% to 53.5% |
| claude-haiku-5-5: 357 blocks, 82 seeds | 341/714 = 47.8% | 39.7% to 55.8% | 44.0% to 51.5% |
| claude-opus-5-5: 223 blocks, 57 seeds | 223/446 = 50.0% | 41.2% to 58.5% | 45.1% to 54.9% |
| claude-sonnet-5-5: 327 blocks, 41 seeds | 334/654 = 51.1% | 43.5% to 58.8% | 47.4% to 54.9% |
| gpt-5.6-terra: 208 blocks, 19 seeds | 217/416 = 52.2% | 42.8% to 61.7% | 47.1% to 57.2% |
| gpt-6-astra: 134 blocks, 47 seeds | 129/268 = 48.1% | 39.4% to 57.9% | 41.8% to 54.1% |
| gpt-6-luna: 269 blocks, 27 seeds | 266/538 = 49.4% | 44.5% to 54.3% | 45.7% to 53.0% |
| gpt-6.1-sol: 242 blocks, 39 seeds | 235/484 = 48.6% | 39.7% to 57.2% | 43.8% to 53.3% |
| gpt-6.1-terra: 22 blocks, 12 seeds | 21/44 = 47.7% | 29.5% to 64.3% | 31.8% to 65.9% |

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
| the 19 seeds with 10 or more blocks, each once |  | 1311 | mean of seed shares 57.8% (95% CI 51.7% to 64.1%, seeds drawn) |

### Tournament 3

| scored matches | Opus xhigh wins/matches = share | 95% CI (seed blocks drawn, wins over matches) | mean of block shares (a block counts once) | 95% CI | Opus minus Astra, Elo (95% CI) | blocks Opus both / split / Astra both |
|---|---|---|---|---|---|---|
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 39.0% to 69.0% | 52.4% | 38.1% to 66.7% | +25 (-81 to +139) | 6 / 10 / 4 |
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
3,709 matches, 11,127 rounds. The median 95% half-width falls from ±51 to ±43 Elo (variance of a match's round share 0.083 → 0.064). Spearman rank correlation with the raw ratings 0.986, largest rank change 8.

Bias test: the mean correction per round of each config, seed-clustered, gives chi2 52.8 on 51 configs (p 0.41). Its correlation with Round Elo fitted on the other half of the seeds (20 random halvings) is -0.05.

| config | matches | rounds | Round Elo [95%] | luck-adjusted [95%] |
|---|---|---|---|---|
| gpt-6.1-terra-max | 80 | 240 | +153 [+97, +209] | +140 [+96, +186] |
| claude-sonnet-5-5-max | 140 | 420 | +134 [+82, +185] | +130 [+86, +172] |
| claude-opus-5-5-max | 80 | 240 | +149 [+92, +207] | +125 [+79, +174] |
| gpt-6-astra-high | 80 | 240 | +147 [+92, +202] | +118 [+70, +164] |
| claude-opus-5-5-xhigh | 150 | 450 | +128 [+82, +173] | +112 [+74, +149] |
| gpt-6.1-sol-max | 122 | 366 | +124 [+75, +173] | +109 [+69, +147] |
| Engine/6/20000/sampled | 76 | 228 | +104 [+53, +155] | +101 [+55, +152] |
| gpt-6-astra-medium | 254 | 762 | +112 [+71, +154] | +87 [+51, +121] |
| gpt-6.1-sol-xhigh | 101 | 303 | +96 [+43, +145] | +86 [+43, +127] |
| claude-opus-5-5-high | 80 | 240 | +105 [+47, +164] | +82 [+36, +131] |
| gpt-6-astra-low | 80 | 240 | +91 [+40, +145] | +81 [+36, +129] |
| gpt-6.1-sol-low | 98 | 294 | +90 [+34, +143] | +77 [+31, +119] |
| gpt-6.1-sol-high | 99 | 297 | +71 [+18, +121] | +71 [+29, +112] |
| gpt-6.1-sol-medium | 271 | 813 | +84 [+41, +126] | +70 [+34, +104] |
| gpt-6.1-terra-xhigh | 80 | 240 | +88 [+33, +147] | +68 [+21, +115] |
| gpt-6.1-terra-high | 80 | 240 | +79 [+25, +139] | +67 [+17, +123] |
| claude-opus-5-5-off | 80 | 240 | +92 [+36, +146] | +67 [+21, +113] |
| claude-sonnet-5-5-xhigh | 176 | 528 | +83 [+38, +126] | +64 [+25, +102] |
| gpt-6-astra-off | 80 | 240 | +63 [+8, +116] | +64 [+16, +110] |
| claude-opus-5-5-medium | 334 | 1002 | +73 [+35, +111] | +61 [+27, +93] |
| claude-haiku-5-5-max | 111 | 333 | +74 [+29, +119] | +59 [+19, +96] |
| gpt-6.1-terra-medium | 80 | 240 | +77 [+26, +129] | +51 [+8, +95] |
| claude-opus-5-5-low | 80 | 240 | +53 [-1, +104] | +41 [-6, +90] |
| gpt-5.6-terra-max | 90 | 270 | +46 [-13, +108] | +40 [-11, +92] |
| gpt-5.6-terra-xhigh | 93 | 279 | +60 [+7, +117] | +40 [-8, +89] |
| claude-haiku-5-5-xhigh | 158 | 474 | +41 [-4, +86] | +30 [-11, +69] |
| gpt-6.1-terra-low | 80 | 240 | +59 [+9, +112] | +27 [-17, +73] |
| gpt-6.1-terra-off | 80 | 240 | +56 [+4, +110] | +25 [-26, +74] |
| claude-sonnet-5-5-medium | 364 | 1092 | +27 [-11, +64] | +23 [-9, +56] |
| claude-haiku-5-5-high | 173 | 519 | +36 [-9, +81] | +21 [-16, +59] |
| claude-sonnet-5-5-high | 161 | 483 | +36 [-14, +85] | +19 [-23, +61] |
| claude-haiku-5-5-medium | 382 | 1146 | +29 [-9, +66] | +8 [-25, +39] |
| gpt-5.6-terra-high | 91 | 273 | +24 [-30, +80] | +7 [-42, +58] |
| Engine/2/20000 | 96 | 288 | +0 [+0, +0] | +0 [+0, +0] |
| claude-haiku-5-5-low | 194 | 582 | +27 [-17, +70] | -2 [-41, +35] |
| gpt-5.6-terra-medium | 259 | 777 | +4 [-35, +46] | -6 [-42, +29] |
| gpt-5.6-terra-low | 91 | 273 | +2 [-51, +55] | -8 [-55, +39] |
| gpt-6-luna-max | 112 | 336 | +11 [-49, +69] | -13 [-63, +39] |
| claude-sonnet-5-5-low | 159 | 477 | -10 [-60, +36] | -14 [-57, +26] |
| gpt-6-luna-xhigh | 115 | 345 | +16 [-42, +74] | -18 [-69, +30] |
| claude-sonnet-5-5-off | 164 | 492 | +6 [-40, +52] | -19 [-59, +22] |
| gpt-6-luna-high | 112 | 336 | -42 [-95, +9] | -73 [-119, -28] |
| claude-haiku-5-5-off | 220 | 660 | -68 [-109, -30] | -85 [-121, -51] |
| claude-haiku-4-5-20251001-medium | 358 | 1074 | -89 [-128, -49] | -113 [-148, -79] |
| claude-haiku-4-5-20251001-high | 135 | 405 | -115 [-165, -69] | -132 [-175, -93] |
| claude-haiku-4-5-20251001-minimal | 143 | 429 | -110 [-159, -62] | -137 [-180, -95] |
| claude-haiku-4-5-20251001-low | 149 | 447 | -110 [-160, -61] | -138 [-181, -96] |
| gpt-6-luna-medium | 282 | 846 | -127 [-172, -84] | -140 [-179, -103] |
| gpt-6-luna-off | 110 | 330 | -183 [-247, -122] | -176 [-228, -126] |
| gpt-6-luna-low | 110 | 330 | -196 [-261, -137] | -196 [-249, -145] |
| claude-haiku-4-5-20251001-off | 125 | 375 | -187 [-240, -137] | -196 [-240, -158] |
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
