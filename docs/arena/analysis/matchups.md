# Matchup analysis

Ratings, pair effects, seat and round 1 starter effects for the scored arena matches, from the analysis database ([database.md](../database.md)). All scored matches are two-player. Every rate shows numerator/denominator, a win share counts a split by its share, and every interval is a 95% bootstrap that draws whole units, never single matches or seat swaps: seed blocks (the two seat-swapped matches of one pair and seed) for ratings, and seeds (every block played at a seed, in any pairing) for the headline seat and starter figures. The tables below the line "Tables" are generated: `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` rewrites them, with a fixed RNG seed, in about 70 minutes under `nice` on the 2,705-match snapshot. Nothing here reads provenance or account data.

**DeepSeek is left out.** Every match with deepseek-v4.1-flash (20 scored matches) is dropped from all cohorts, fits, seat and starter figures and tables, because its free tier refused requests, so its games are not a random sample of what was scheduled. That leaves 2,685 scored matches from the 2,705-match snapshot of 2026-11-01. Every finding below uses these.

## Findings

**Ratings are pooled.** One Bradley-Terry fit covers every scored match of every tournament, so all 48 configs share one Elo scale with the mean at 0, as in the viewer. Tournament 4 gave every older config games against other models, so no rating leans on an assumption that effort gaps carry across opponents. Most of tournament 5's new configs have 4 to 12 matches against changing opponents, so their intervals are often several hundred Elo wide and their point ratings mostly reflect the prior pulling a thin record. `results.md` and the viewer show the same ratings. A second fit on pot share (a config's cash over the match's cash, which credits the round prizes a loser banks) gives the cash rating. Cohorts are only a way to group matches. A cohort is one kind of comparison, pooled over every tournament: Cross-model (every match between different models) or one model's efforts (every match of that model against itself), as in the viewer. There are ten: Cross-model and the efforts of Astra, Haiku 4.5, Haiku 5.5, Luna, Opus, Sol, Sonnet, Terra and Terra 6.1.
- **Coverage.** The Cross-model cohort has 48 entrants and 1,051 matches over 225 of the 1,128 pairs, 2 to 41 matches per pair. Each older effort cohort is a round robin with 20 matches per pair. Opus efforts plays 10 of its 15 pairs (2 to 20 matches each), Terra 6.1 efforts 7 of 15 and Astra efforts 2 of 3, 2 matches each. Tournament 5 is finished; the scheduled matches it did not play stay unstarted in the table below.
- **Cross-model medium configs**, win rating (95% CI by seed blocks): astra +157 (+116 to +203), opus +86 (+42 to +133), sol +70 (+28 to +116), haiku 5.5 +25 (-12 to +67), sonnet +28 (-16 to +74), terra -40 (-86 to +9), haiku 4.5 -152 (-204 to -102), luna -241 (-305 to -188). Astra stands above and luna and haiku 4.5 below; the middle ones overlap. Drawing seeds instead of blocks moves the intervals modestly.
- **Top and bottom.** Among configs with 80 or more matches, Sonnet max +192 (+129 to +273), astra +157, Opus xhigh +154 (+92 to +225) and Sol max +146 lead. Luna low -328, luna off -323 and haiku 4.5 off -316 trail. Opus max (40 matches, +145, +34 to +264) sits with the leaders. Terra 6.1 max (4 matches, +234, 0 to +512) rates highest but its interval is too wide to place it. Effort configs from the older tournaments have 80 to 110 matches each, so their intervals are about 150 to 200 Elo wide.
- **Effort.** Within each model the top level is xhigh or max in every model with a sweep or effort tournament, Opus included: luna xhigh -7 and max -28 against medium -241, sonnet max +192 against medium +28, haiku 5.5 xhigh +112, terra max +20, sol max +146, Opus max +145 and xhigh +154 against medium +86. Haiku 4.5 has no such level; its top is minimal (-147) and medium (-152). Off or low is the bottom level in the older sweeps: luna low -328, haiku 4.5 off -316, haiku 5.5 off -91, sonnet low -28, terra low -73 and Opus low -6. Opus off (+93, 12 matches, -11 to +240) is not at the bottom, but its interval is wide. Sol is the exception: medium +70 sits at the bottom of a flat range up to +146, and the intervals overlap. Terra 6.1 has no clear order across its efforts (max +234, low +99, medium +37, off +19, xhigh -8, high -136), and every effort but medium has an interval several hundred Elo wide. The order of neighbouring levels is mostly inside the intervals.
- **Cash.** Cash ratings spread less than win ratings among configs with 80 or more matches (+122 to -212 against +192 to -328), because losers bank round prizes. The two ratings agree on the leaders (Sonnet max +122, Sol max +99, Opus xhigh +94) and the trailers (luna low -212). A config can win less than it earns: Opus low wins 40.5% of its 42 matches yet takes 52.5% of the pot (cash +58, win -6), and terra high wins 44.4% and takes 49.6% (cash +5, win -56). Haiku 5.5 xhigh is the reverse: 62.7% of wins, 54.0% of the pot, cash +20 against win +112.

**Matchup effects: none worth keeping.** The observed pair share minus the share fitted by the pooled ratings is small and is reported as a descriptive residual. It is not a test: the ratings are regularized, so residuals are forced (a pair at the end of a chain of pairs is pulled to its fit), and the bootstrap range around a residual is not a calibrated interval around zero. The largest Cross-model residual over a pair of 20 matches or more is haiku 4.5 against sonnet (-16.2 points). Pairs of 2 matches are too thin to read.
- The test is held-out prediction. Whole seed blocks were held out (5 repeats of 10-fold cross-validation, with the shrinkage chosen inside each training set from 0 to 1.6, so no held-out block picks it). Pair effects are fitted only for pairs seen in more than one seed block: a pair confined to one block has no training data when that block is held out, so its games still count in the test score but it gets no pair term. Terra 6.1 efforts has 7 seed blocks, under the minimum of 10 this test needs (the fit with seat and starter terms can be singular on so few), and Astra efforts is a tree of pairs, so neither is tested. In every other cohort the nested pair-effect model scored no better than ratings alone: the gain per match is between -0.0053 and +0.0000 nats, and the lower end of its interval is never above 0. The shrinkage chose 0 (ratings only) in most folds for Cross-model, Haiku 5.5, Luna, Opus and Terra. So **no tested cohort keeps pair effects**. Cross-model holds tournament 4's one-block pairs, tournament 5's and the 41-match Opus xhigh against Astra pair.
- The same holds when the ratings also have a seat term and a round 1 starter term, which on their own lower the Cross-model loss from 0.6293 to 0.6062 per match.
- Reverse pairs, described and not tested: for the entrant seated first, a real matchup effect should show the opposite sign when A sat first and when B sat first. 106 of 225 pairs (47.1%) do, with a correlation of -0.25 between the A-first effect and minus the B-first effect (a negative value means the two orders lean the same way). The signs are not independent (the two orders of a block share a seed, seeds are reused across pairings, and the ratings are fitted jointly), so no test is made. The two entrants' effects in a pair sum to zero to rounding (6e-17) because every match's shares sum to 1.
- With 20 matches per pair in the effort cohorts and 2 in most of Cross-model, only large pair effects could show.

**Seat and starter.** Whoever opens round 1 (read from the public line `Round 1 begins ... Player X starts.` of each match's events) also fired the first shot in 2685 of 2685 matches. The seed decides that position, and both matches of a block share it.
- **Position 1:** 1342/2684 = 50.0% over 1,342 complete blocks at 78 seeds (95% CI by seeds 42.9% to 56.6%; by seed blocks 48.2% to 51.8%). Cross-model 494/1050 = 47.0% (39.6% to 55.1% by seeds).
- **Starter:** the player who opens round 1 won 1538/2684 = 57.3% (51.7% to 63.2% by seeds; 55.3% to 59.1% by seed blocks). The overall starter association stands: it is about 7 points above even.
- **Split:** the position and starter effects below are a descriptive additive split of block shares by which position starts. Every complete-block seed has exactly one starter position, so a starter effect cannot be told from a seed effect. The split describes these seed blocks; only the seeds-drawn intervals reach beyond them. Starter +7.3 points overall (seeds +1.6 to +13.2; blocks +5.3 to +9.1), +9.6 Cross-model (+3.5 to +15.7; blocks +6.7 to +12.4). Position +0.3 overall (-6.2 to +5.9 by seeds).
- **It depends on the seed.** The starter won 173/244 = 70.9% of matches at seed 3000 and 28/74 = 37.8% at seed 3005. Counting each of the 19 seeds with 10 or more blocks once, the starter's mean share is 57.7% (51.7% to 63.8%, seeds drawn). Starter figures are therefore not reported per model: a model's blocks cover a handful of seeds, so they say as much about those seeds as about the model. Position 1 per model is in the tables.
- **Recommendation:** a starter term is worth keeping as an option for future ratings. It lowers held-out loss a lot (Cross-model 0.6293 to 0.6062 per match) and moves the pooled ratings by up to 8.0 Elo. The headline fits stay without it.

**Tournament 3 (Opus xhigh against Astra medium).**
- **41 matches** (21 seed blocks, seed 3030 half): Opus 22/41 = 53.7% (38.1% to 69.0%); Elo gap +25 (-88 to +132), in a fit of the two alone.
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
- **Unmatched blocks.** One half block (tournament 3's seed 3030, 1 match) cannot be matched and is left out of every seat figure.
- **Power.** The held-out test can rule out large pair effects only; "none kept" is not "none exist". Cohorts with 40 blocks (Opus efforts) are the weakest, and a pair-effect model with 4 pairs is almost saturated.
- **Thin cells.** Tournament 4 has one seat-swapped block (2 matches) per pair, so one pair says little; its value is that it links every config to the others. Sonnet max's cross-model rating rests on 8 tournament-4 matches, 2 tournament-1 games and the 30 top-four matches of tournament 5.
- **Position and starter overlap** because the seed fixes the starter's position, and tournament 1's seeds 3000 to 3009 start position 2 six times in ten.
- **No replays.** Everything comes from standings, cash, seating and the public round 1 line; no moves were reviewed.

## Tables

<!-- tables:start -->
### Schedule coverage

| cohort | entrants | scored matches | complete / half blocks | pairs played | matches per pair min / median / max | connected | scheduled by status |
|---|---|---|---|---|---|---|---|
| Astra efforts | 3 | 4 | 2 / 0 | 2/3 | 2 / 2 / 2 | yes | 4 completed, 8 unstarted |
| Cross-model | 48 | 1051 | 525 / 1 | 225/1128 | 2 / 2 / 41 | yes | 1051 completed, 5 partial (skipped), 138 skipped (skipped), 40 unstarted |
| Haiku 4.5 efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| Haiku 5.5 efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Luna efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Opus efforts | 6 | 116 | 58 / 0 | 10/15 | 2 / 10 / 20 | yes | 116 completed |
| Sol efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| Sonnet efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Terra 6.1 efforts | 6 | 14 | 7 / 0 | 7/15 | 2 / 2 / 2 | yes | 14 completed, 16 unstarted |
| Terra efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |

### Pooled ratings

| config | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) | pot share | cash rating (Elo, mean 0) | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|---|
| gpt-6.1-terra-max | 3/4 = 75.0% | +234 | +0 to +512 | +0 to +488 | 66.1% | +135 | -44 to +487 |
| claude-sonnet-5-5-max | 94/140 = 67.1% | +192 | +129 to +273 | +110 to +299 | 62.3% | +122 | +85 to +163 |
| gpt-6-astra | 169/253 = 66.8% | +157 | +116 to +203 | +119 to +202 | 60.4% | +91 | +66 to +117 |
| claude-opus-5-5-xhigh | 59/111 = 53.2% | +154 | +92 to +225 | +92 to +224 | 52.3% | +94 | +57 to +132 |
| gpt-6.1-sol-max | 70/122 = 57.4% | +146 | +89 to +206 | +82 to +213 | 54.9% | +99 | +63 to +132 |
| claude-opus-5-5-max | 24/40 = 60.0% | +145 | +34 to +264 | +31 to +285 | 55.0% | +94 | +33 to +155 |
| claude-sonnet-5-5-xhigh | 70/118 = 59.3% | +119 | +52 to +194 | +43 to +207 | 55.0% | +62 | +24 to +99 |
| claude-haiku-5-5-xhigh | 69/110 = 62.7% | +112 | +41 to +188 | +36 to +182 | 54.0% | +20 | -17 to +58 |
| claude-haiku-5-5-max | 67/110 = 60.9% | +101 | +34 to +171 | +21 to +191 | 58.6% | +49 | +13 to +83 |
| gpt-6.1-terra-low | 5/8 = 62.5% | +99 | -38 to +400 | -34 to +374 | 58.6% | +49 | -23 to +178 |
| claude-opus-5-5-off | 7/12 = 58.3% | +93 | -11 to +240 | -10 to +246 | 61.1% | +103 | +34 to +184 |
| gpt-6-astra-low | 7/12 = 58.3% | +88 | -81 to +291 | -78 to +281 | 55.4% | +51 | -44 to +204 |
| gpt-6.1-sol-low | 49/96 = 51.0% | +86 | +15 to +159 | +19 to +153 | 50.6% | +61 | +20 to +102 |
| claude-opus-5-5-high | 25/52 = 48.1% | +86 | -13 to +189 | -18 to +201 | 47.3% | +42 | -12 to +93 |
| claude-opus-5-5 | 156/266 = 58.6% | +86 | +42 to +133 | +40 to +135 | 54.7% | +50 | +27 to +74 |
| gpt-6.1-sol-xhigh | 52/100 = 52.0% | +85 | +14 to +161 | +18 to +159 | 52.6% | +68 | +30 to +111 |
| claude-sonnet-5-5-high | 62/118 = 52.5% | +75 | +1 to +155 | +2 to +159 | 50.4% | +34 | -8 to +79 |
| gpt-6.1-sol | 152/268 = 56.7% | +70 | +28 to +116 | +16 to +133 | 56.6% | +59 | +34 to +83 |
| gpt-6.1-sol-high | 47/98 = 48.0% | +64 | -4 to +133 | -5 to +133 | 48.2% | +45 | +2 to +85 |
| claude-haiku-5-5-high | 62/116 = 53.4% | +54 | -17 to +130 | -5 to +113 | 52.5% | +13 | -28 to +52 |
| claude-sonnet-5-5-off | 55/118 = 46.6% | +39 | -31 to +113 | -27 to +109 | 46.8% | +13 | -24 to +53 |
| gpt-6.1-terra | 10/20 = 50.0% | +37 | -92 to +147 | -102 to +143 | 50.8% | +17 | -46 to +79 |
| claude-sonnet-5-5 | 145/286 = 50.7% | +28 | -16 to +74 | -21 to +75 | 50.8% | +17 | -8 to +43 |
| claude-haiku-5-5 | 151/292 = 51.7% | +25 | -12 to +67 | -8 to +60 | 50.5% | +2 | -20 to +26 |
| gpt-5.6-terra-max | 52/90 = 57.8% | +20 | -64 to +109 | -45 to +86 | 53.8% | +28 | -17 to +72 |
| gpt-6.1-terra-off | 4/8 = 50.0% | +19 | -314 to +331 | -243 to +342 | 41.7% | -46 | -191 to +86 |
| gpt-5.6-terra-xhigh | 51/90 = 56.7% | +18 | -63 to +101 | -65 to +95 | 54.7% | +37 | -4 to +77 |
| claude-haiku-5-5-low | 56/118 = 47.5% | +15 | -55 to +85 | -52 to +80 | 48.6% | -12 | -52 to +26 |
| gpt-6-astra-high | 3/8 = 37.5% | -5 | -312 to +139 | -331 to +137 | 50.6% | +55 | -76 to +174 |
| claude-opus-5-5-low | 17/42 = 40.5% | -6 | -118 to +92 | -117 to +99 | 52.5% | +58 | -4 to +119 |
| gpt-6-luna-xhigh | 79/114 = 69.3% | -7 | -86 to +75 | -76 to +63 | 64.1% | +4 | -42 to +47 |
| gpt-6.1-terra-xhigh | 4/10 = 40.0% | -8 | -387 to +207 | -351 to +224 | 40.0% | -34 | -291 to +189 |
| claude-sonnet-5-5-low | 42/118 = 35.6% | -28 | -105 to +48 | -95 to +48 | 41.7% | -17 | -58 to +23 |
| gpt-6-luna-max | 75/112 = 67.0% | -28 | -112 to +56 | -104 to +46 | 63.2% | -6 | -52 to +40 |
| gpt-5.6-terra | 119/256 = 46.5% | -40 | -86 to +9 | -85 to +9 | 48.3% | -13 | -39 to +13 |
| gpt-5.6-terra-high | 40/90 = 44.4% | -56 | -138 to +24 | -119 to +1 | 49.6% | +5 | -37 to +46 |
| gpt-5.6-terra-low | 37/90 = 41.1% | -73 | -158 to +10 | -148 to +1 | 45.7% | -16 | -59 to +27 |
| gpt-6-luna-high | 66/110 = 60.0% | -85 | -180 to +4 | -182 to +24 | 55.6% | -58 | -101 to -19 |
| claude-haiku-5-5-off | 34/110 = 30.9% | -91 | -168 to -17 | -156 to -27 | 35.7% | -92 | -131 to -51 |
| gpt-6.1-terra-high | 2/8 = 25.0% | -136 | -507 to +90 | -512 to +100 | 33.1% | -97 | -377 to +60 |
| claude-haiku-4-5-20251001-minimal | 50/90 = 55.6% | -147 | -233 to -59 | -219 to -73 | 50.0% | -115 | -160 to -68 |
| claude-haiku-4-5-20251001 | 100/264 = 37.9% | -152 | -204 to -102 | -205 to -104 | 41.3% | -98 | -127 to -70 |
| claude-haiku-4-5-20251001-low | 45/90 = 50.0% | -182 | -273 to -97 | -266 to -102 | 51.3% | -108 | -154 to -61 |
| claude-haiku-4-5-20251001-high | 43/90 = 47.8% | -195 | -286 to -110 | -319 to -96 | 49.4% | -118 | -164 to -74 |
| gpt-6-luna | 74/282 = 26.2% | -241 | -305 to -188 | -293 to -194 | 34.1% | -144 | -173 to -117 |
| claude-haiku-4-5-20251001-off | 25/90 = 27.8% | -316 | -422 to -227 | -426 to -213 | 36.3% | -193 | -241 to -144 |
| gpt-6-luna-off | 29/110 = 26.4% | -323 | -419 to -237 | -439 to -224 | 33.8% | -197 | -248 to -150 |
| gpt-6-luna-low | 28/110 = 25.5% | -328 | -429 to -233 | -399 to -270 | 31.4% | -212 | -263 to -163 |

With a seat term and a round 1 starter term in the fit (position 1 +2 Elo, the starter +59 Elo) the largest rating change is 8.0 Elo.


### Observed pairs against the pooled ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below. Every resample refits the pooled ratings.

#### Astra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-astra vs gpt-6-astra-high | 1/2 = 50.0% | 71.8% | -21.8 | -37.3 to -2.7 |
| gpt-6-astra vs gpt-6-astra-low | 2/2 = 100.0% | 59.9% | +40.1 | +16.4 to +54.6 |
#### Cross-model

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-5-5 | 6/20 = 30.0% | 26.6% | +3.4 | -11.7 to +19.3 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-high | 0/2 = 0.0% | 23.4% | -23.4 | -31.8 to -15.1 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-low | 1/4 = 25.0% | 27.8% | -2.8 | -33.9 to +27.1 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-max | 0/2 = 0.0% | 19.0% | -19.0 | -26.1 to -12.4 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-off | 1/2 = 50.0% | 41.3% | +8.7 | -3.1 to +20.0 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-xhigh | 1/2 = 50.0% | 18.0% | +32.0 | +23.3 to +38.3 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5 | 7/20 = 35.0% | 20.3% | +14.7 | -4.1 to +35.0 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-low | 0/2 = 0.0% | 30.2% | -30.2 | -43.6 to -18.3 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5 | 2/20 = 10.0% | 26.2% | -16.2 | -29.1 to -1.8 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-high | 0/2 = 0.0% | 21.3% | -21.3 | -30.4 to -12.9 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-low | 0/2 = 0.0% | 32.9% | -32.9 | -44.5 to -21.7 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 12.1% | -12.1 | -17.8 to -7.3 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-off | 0/4 = 0.0% | 25.0% | -25.0 | -34.6 to -16.5 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-xhigh | 0/2 = 0.0% | 17.4% | -17.4 | -24.7 to -10.8 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra | 6/20 = 30.0% | 34.4% | -4.4 | -19.8 to +11.0 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-low | 0/2 = 0.0% | 38.9% | -38.9 | -49.4 to -26.2 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-max | 0/2 = 0.0% | 27.2% | -27.2 | -38.3 to -16.9 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-xhigh | 1/2 = 50.0% | 27.3% | +22.7 | +11.3 to +32.2 |
| claude-haiku-4-5-20251001 vs gpt-6-astra | 3/20 = 15.0% | 14.4% | +0.6 | -13.0 to +15.3 |
| claude-haiku-4-5-20251001 vs gpt-6-luna | 12/20 = 60.0% | 62.6% | -2.6 | -27.9 to +22.0 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-high | 1/2 = 50.0% | 40.6% | +9.4 | -6.0 to +22.1 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-off | 2/2 = 100.0% | 72.8% | +27.2 | +16.5 to +38.7 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 30.3% | +19.7 | +6.7 to +29.2 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol | 6/20 = 30.0% | 21.9% | +8.1 | -12.0 to +28.9 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-high | 1/2 = 50.0% | 22.4% | +27.6 | +18.3 to +34.5 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-low | 1/2 = 50.0% | 20.3% | +29.7 | +20.0 to +36.1 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 20.3% | +29.7 | +20.2 to +36.5 |
| claude-haiku-4-5-20251001-high vs claude-sonnet-5-5 | 0/2 = 0.0% | 21.7% | -21.7 | -31.6 to -13.3 |
| claude-haiku-4-5-20251001-high vs gpt-5.6-terra | 0/2 = 0.0% | 29.1% | -29.1 | -40.8 to -18.1 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra | 0/2 = 0.0% | 11.6% | -11.6 | -18.2 to -6.8 |
| claude-haiku-4-5-20251001-high vs gpt-6-luna | 0/2 = 0.0% | 56.6% | -56.6 | -69.1 to -40.4 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-sol | 0/2 = 0.0% | 17.9% | -17.9 | -26.9 to -10.6 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5 | 1/2 = 50.0% | 23.3% | +26.7 | +15.5 to +34.6 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5 | 0/2 = 0.0% | 17.6% | -17.6 | -25.9 to -10.4 |
| claude-haiku-4-5-20251001-low vs gpt-5.6-terra | 1/2 = 50.0% | 30.6% | +19.4 | +6.7 to +29.6 |
| claude-haiku-4-5-20251001-low vs gpt-6-luna | 2/2 = 100.0% | 58.4% | +41.6 | +27.2 to +54.9 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-sol | 0/2 = 0.0% | 19.0% | -19.0 | -28.4 to -11.2 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5 | 1/2 = 50.0% | 27.1% | +22.9 | +11.0 to +31.9 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5 | 1/2 = 50.0% | 20.8% | +29.2 | +18.0 to +36.6 |
| claude-haiku-4-5-20251001-minimal vs claude-sonnet-5-5 | 1/2 = 50.0% | 26.8% | +23.2 | +11.0 to +32.2 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra | 0/2 = 0.0% | 14.8% | -14.8 | -22.0 to -8.7 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-luna | 1/2 = 50.0% | 63.2% | -13.2 | -25.4 to +1.1 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5 | 1/2 = 50.0% | 12.3% | +37.7 | +29.8 to +42.6 |
| claude-haiku-4-5-20251001-off vs claude-sonnet-5-5 | 1/2 = 50.0% | 12.1% | +37.9 | +30.4 to +42.8 |
| claude-haiku-4-5-20251001-off vs gpt-5.6-terra | 0/2 = 0.0% | 16.9% | -16.9 | -26.1 to -9.3 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra | 0/2 = 0.0% | 6.2% | -6.2 | -10.1 to -3.2 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-sol | 0/2 = 0.0% | 9.8% | -9.8 | -16.2 to -5.2 |
| claude-haiku-5-5 vs claude-opus-5-5 | 7/20 = 35.0% | 41.4% | -6.4 | -21.6 to +7.2 |
| claude-haiku-5-5 vs claude-opus-5-5-high | 0/2 = 0.0% | 41.4% | -41.4 | -53.8 to -26.8 |
| claude-haiku-5-5 vs claude-opus-5-5-low | 1/2 = 50.0% | 54.4% | -4.4 | -19.3 to +10.1 |
| claude-haiku-5-5 vs claude-opus-5-5-max | 1/2 = 50.0% | 33.4% | +16.6 | -0.9 to +29.0 |
| claude-haiku-5-5 vs claude-opus-5-5-off | 1/2 = 50.0% | 40.4% | +9.6 | -5.4 to +25.3 |
| claude-haiku-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 49.6% | +10.4 | -8.2 to +30.0 |
| claude-haiku-5-5 vs claude-sonnet-5-5-high | 1/4 = 25.0% | 42.8% | -17.8 | -50.2 to +13.3 |
| claude-haiku-5-5 vs claude-sonnet-5-5-low | 2/2 = 100.0% | 57.6% | +42.4 | +29.8 to +53.3 |
| claude-haiku-5-5 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 27.6% | -27.6 | -36.5 to -18.8 |
| claude-haiku-5-5 vs claude-sonnet-5-5-off | 1/2 = 50.0% | 48.0% | +2.0 | -9.0 to +13.0 |
| claude-haiku-5-5 vs claude-sonnet-5-5-xhigh | 1/4 = 25.0% | 36.7% | -11.7 | -43.7 to +18.9 |
| claude-haiku-5-5 vs gpt-5.6-terra | 13/20 = 65.0% | 59.2% | +5.8 | -8.0 to +22.4 |
| claude-haiku-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 61.5% | +38.5 | +26.6 to +49.1 |
| claude-haiku-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 63.7% | -13.7 | -24.5 to -1.7 |
| claude-haiku-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 50.8% | +49.2 | +35.3 to +61.6 |
| claude-haiku-5-5 vs gpt-6-astra | 6/20 = 30.0% | 31.8% | -1.8 | -18.4 to +12.5 |
| claude-haiku-5-5 vs gpt-6-astra-low | 1/2 = 50.0% | 41.1% | +8.9 | -12.5 to +27.0 |
| claude-haiku-5-5 vs gpt-6-luna | 19/20 = 95.0% | 82.2% | +12.8 | +0.9 to +21.9 |
| claude-haiku-5-5 vs gpt-6-luna-high | 1/2 = 50.0% | 65.4% | -15.4 | -27.5 to -2.7 |
| claude-haiku-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.4% | +11.6 | +6.2 to +18.3 |
| claude-haiku-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 57.6% | -7.6 | -19.8 to +5.0 |
| claude-haiku-5-5 vs gpt-6.1-sol | 10/20 = 50.0% | 43.6% | +6.4 | -7.3 to +20.4 |
| claude-haiku-5-5 vs gpt-6.1-sol-high | 2/4 = 50.0% | 44.3% | +5.7 | -5.0 to +16.0 |
| claude-haiku-5-5 vs gpt-6.1-sol-low | 0/2 = 0.0% | 41.4% | -41.4 | -51.8 to -30.4 |
| claude-haiku-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 33.2% | +16.8 | +7.2 to +24.9 |
| claude-haiku-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 41.4% | +8.6 | -2.7 to +18.7 |
| claude-haiku-5-5-high vs claude-opus-5-5 | 1/2 = 50.0% | 45.5% | +4.5 | -7.3 to +15.6 |
| claude-haiku-5-5-high vs claude-sonnet-5-5 | 2/4 = 50.0% | 53.8% | -3.8 | -58.8 to +51.0 |
| claude-haiku-5-5-high vs gpt-6-astra | 0/2 = 0.0% | 35.6% | -35.6 | -46.7 to -25.4 |
| claude-haiku-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 84.5% | -34.5 | -40.1 to -26.2 |
| claude-haiku-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 47.8% | -47.8 | -59.4 to -35.6 |
| claude-haiku-5-5-high vs gpt-6.1-terra | 2/2 = 100.0% | 52.5% | +47.5 | +25.7 to +58.0 |
| claude-haiku-5-5-low vs claude-opus-5-5 | 2/2 = 100.0% | 39.9% | +60.1 | +47.2 to +68.9 |
| claude-haiku-5-5-low vs claude-sonnet-5-5 | 1/2 = 50.0% | 48.1% | +1.9 | -10.2 to +13.4 |
| claude-haiku-5-5-low vs gpt-5.6-terra | 1/2 = 50.0% | 57.7% | -7.7 | -18.7 to +3.6 |
| claude-haiku-5-5-low vs gpt-6-astra | 0/2 = 0.0% | 30.5% | -30.5 | -41.0 to -20.5 |
| claude-haiku-5-5-low vs gpt-6-luna | 1/2 = 50.0% | 81.3% | -31.3 | -38.5 to -21.6 |
| claude-haiku-5-5-low vs gpt-6.1-sol | 2/2 = 100.0% | 42.1% | +57.9 | +45.3 to +67.8 |
| claude-haiku-5-5-low vs gpt-6.1-terra-low | 1/2 = 50.0% | 38.1% | +11.9 | -6.8 to +30.7 |
| claude-haiku-5-5-max vs claude-opus-5-5 | 2/2 = 100.0% | 52.2% | +47.8 | +35.2 to +58.5 |
| claude-haiku-5-5-max vs claude-sonnet-5-5 | 1/2 = 50.0% | 60.3% | -10.3 | -20.4 to +1.2 |
| claude-haiku-5-5-max vs gpt-5.6-terra | 1/2 = 50.0% | 69.2% | -19.2 | -27.9 to -8.7 |
| claude-haiku-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 54.4% | -4.4 | -15.3 to +6.9 |
| claude-haiku-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 42.7% | +7.3 | -4.6 to +18.9 |
| claude-haiku-5-5-off vs gpt-6-astra | 0/2 = 0.0% | 19.3% | -19.3 | -27.3 to -12.3 |
| claude-haiku-5-5-off vs gpt-6-luna | 1/2 = 50.0% | 70.4% | -20.4 | -30.9 to -7.6 |
| claude-haiku-5-5-off vs gpt-6.1-sol | 0/2 = 0.0% | 28.4% | -28.4 | -38.5 to -18.8 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5 | 0/2 = 0.0% | 53.7% | -53.7 | -64.8 to -40.7 |
| claude-haiku-5-5-xhigh vs claude-sonnet-5-5 | 1/2 = 50.0% | 61.8% | -11.8 | -22.0 to -0.4 |
| claude-haiku-5-5-xhigh vs gpt-6-astra | 0/2 = 0.0% | 43.4% | -43.4 | -54.7 to -31.4 |
| claude-haiku-5-5-xhigh vs gpt-6-luna | 2/2 = 100.0% | 88.4% | +11.6 | +6.8 to +17.9 |
| claude-opus-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 58.2% | +1.8 | -15.8 to +20.0 |
| claude-opus-5-5 vs claude-sonnet-5-5-high | 2/2 = 100.0% | 51.5% | +48.5 | +35.4 to +61.0 |
| claude-opus-5-5 vs claude-sonnet-5-5-low | 2/4 = 50.0% | 65.8% | -15.8 | -71.4 to +39.4 |
| claude-opus-5-5 vs claude-sonnet-5-5-max | 2/2 = 100.0% | 35.1% | +64.9 | +53.4 to +73.8 |
| claude-opus-5-5 vs claude-sonnet-5-5-off | 1/2 = 50.0% | 56.7% | -6.7 | -17.6 to +5.9 |
| claude-opus-5-5 vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 45.1% | +54.9 | +41.7 to +64.9 |
| claude-opus-5-5 vs gpt-5.6-terra | 12/20 = 60.0% | 67.3% | -7.3 | -20.5 to +6.0 |
| claude-opus-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 69.3% | +30.7 | +20.3 to +41.5 |
| claude-opus-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 71.4% | -21.4 | -30.4 to -9.0 |
| claude-opus-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 59.4% | +40.6 | +27.7 to +53.4 |
| claude-opus-5-5 vs gpt-5.6-terra-xhigh | 2/2 = 100.0% | 59.6% | +40.4 | +28.2 to +52.0 |
| claude-opus-5-5 vs gpt-6-astra | 9/20 = 45.0% | 39.8% | +5.2 | -6.9 to +15.2 |
| claude-opus-5-5 vs gpt-6-astra-high | 1/2 = 50.0% | 62.7% | -12.7 | -32.9 to +5.8 |
| claude-opus-5-5 vs gpt-6-astra-low | 1/2 = 50.0% | 49.7% | +0.3 | -18.2 to +22.2 |
| claude-opus-5-5 vs gpt-6-luna | 16/20 = 80.0% | 86.7% | -6.7 | -29.3 to +11.7 |
| claude-opus-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 91.5% | +8.5 | +4.3 to +14.2 |
| claude-opus-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 65.8% | -15.8 | -26.8 to -3.7 |
| claude-opus-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 63.0% | -13.0 | -24.9 to +0.3 |
| claude-opus-5-5 vs gpt-6.1-sol | 12/20 = 60.0% | 52.3% | +7.7 | -9.4 to +25.9 |
| claude-opus-5-5 vs gpt-6.1-sol-high | 2/2 = 100.0% | 53.0% | +47.0 | +35.0 to +57.3 |
| claude-opus-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 50.0% | +0.0 | -11.5 to +11.4 |
| claude-opus-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 41.3% | +8.7 | -1.6 to +18.1 |
| claude-opus-5-5 vs gpt-6.1-sol-xhigh | 2/4 = 50.0% | 50.0% | -0.0 | -11.1 to +11.2 |
| claude-opus-5-5 vs gpt-6.1-terra | 1/2 = 50.0% | 57.0% | -7.0 | -22.5 to +8.5 |
| claude-opus-5-5-high vs claude-sonnet-5-5 | 1/2 = 50.0% | 58.2% | -8.2 | -21.8 to +7.2 |
| claude-opus-5-5-high vs gpt-6-astra | 1/2 = 50.0% | 39.8% | +10.2 | -5.0 to +23.2 |
| claude-opus-5-5-high vs gpt-6-luna | 2/2 = 100.0% | 86.8% | +13.2 | +7.1 to +22.1 |
| claude-opus-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 52.3% | -52.3 | -64.9 to -35.9 |
| claude-opus-5-5-low vs claude-sonnet-5-5 | 1/2 = 50.0% | 45.2% | +4.8 | -9.9 to +19.8 |
| claude-opus-5-5-low vs gpt-5.6-terra | 0/2 = 0.0% | 54.8% | -54.8 | -65.7 to -36.4 |
| claude-opus-5-5-low vs gpt-6-luna | 2/2 = 100.0% | 79.5% | +20.5 | +11.1 to +32.9 |
| claude-opus-5-5-max vs claude-sonnet-5-5 | 2/2 = 100.0% | 66.3% | +33.7 | +19.2 to +47.1 |
| claude-opus-5-5-max vs gpt-6-astra | 1/2 = 50.0% | 48.2% | +1.8 | -13.7 to +17.4 |
| claude-opus-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 60.7% | -10.7 | -24.3 to +6.2 |
| claude-opus-5-5-max vs gpt-6.1-terra | 1/2 = 50.0% | 65.1% | -15.1 | -30.4 to +5.4 |
| claude-opus-5-5-off vs claude-sonnet-5-5-off | 2/2 = 100.0% | 57.7% | +42.3 | +20.7 to +51.0 |
| claude-opus-5-5-off vs gpt-6-luna-xhigh | 1/2 = 50.0% | 63.9% | -13.9 | -29.5 to +2.7 |
| claude-opus-5-5-xhigh vs claude-sonnet-5-5-max | 2/10 = 20.0% | 44.5% | -24.5 | -49.3 to +0.6 |
| claude-opus-5-5-xhigh vs gpt-6-astra | 22/41 = 53.7% | 49.5% | +4.1 | -5.9 to +14.7 |
| claude-opus-5-5-xhigh vs gpt-6.1-sol-max | 4/10 = 40.0% | 51.1% | -11.1 | -33.2 to +5.1 |
| claude-sonnet-5-5 vs gpt-5.6-terra | 11/20 = 55.0% | 59.6% | -4.6 | -28.9 to +20.7 |
| claude-sonnet-5-5 vs gpt-5.6-terra-high | 1/2 = 50.0% | 61.9% | -11.9 | -23.2 to +0.7 |
| claude-sonnet-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.1% | -14.1 | -24.5 to -0.9 |
| claude-sonnet-5-5 vs gpt-5.6-terra-xhigh | 0/2 = 0.0% | 51.4% | -51.4 | -62.2 to -38.1 |
| claude-sonnet-5-5 vs gpt-6-astra | 7/20 = 35.0% | 32.2% | +2.8 | -12.1 to +17.1 |
| claude-sonnet-5-5 vs gpt-6-astra-high | 2/2 = 100.0% | 54.7% | +45.3 | +10.6 to +53.8 |
| claude-sonnet-5-5 vs gpt-6-astra-low | 0/2 = 0.0% | 41.5% | -41.5 | -54.5 to -15.4 |
| claude-sonnet-5-5 vs gpt-6-luna | 17/20 = 85.0% | 82.5% | +2.5 | -12.9 to +16.0 |
| claude-sonnet-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.6% | +11.4 | +6.1 to +18.7 |
| claude-sonnet-5-5 vs gpt-6-luna-off | 2/2 = 100.0% | 88.3% | +11.7 | +6.7 to +18.8 |
| claude-sonnet-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 55.0% | -5.0 | -17.5 to +8.7 |
| claude-sonnet-5-5 vs gpt-6.1-sol | 8/20 = 40.0% | 44.0% | -4.0 | -22.5 to +14.6 |
| claude-sonnet-5-5 vs gpt-6.1-sol-high | 1/2 = 50.0% | 44.8% | +5.2 | -6.5 to +16.0 |
| claude-sonnet-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 41.8% | +8.2 | -2.9 to +19.1 |
| claude-sonnet-5-5 vs gpt-6.1-sol-max | 0/2 = 0.0% | 33.6% | -33.6 | -41.9 to -24.6 |
| claude-sonnet-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 41.8% | +8.2 | -2.6 to +19.3 |
| claude-sonnet-5-5-high vs gpt-5.6-terra | 1/2 = 50.0% | 65.9% | -15.9 | -26.2 to -3.7 |
| claude-sonnet-5-5-high vs gpt-6-astra | 2/2 = 100.0% | 38.4% | +61.6 | +48.3 to +71.4 |
| claude-sonnet-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 86.0% | -36.0 | -41.7 to -28.2 |
| claude-sonnet-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 50.8% | -50.8 | -62.1 to -37.2 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-high | 2/2 = 100.0% | 77.1% | +22.9 | +2.9 to +40.4 |
| claude-sonnet-5-5-low vs gpt-6-astra | 0/2 = 0.0% | 25.6% | -25.6 | -36.0 to -16.9 |
| claude-sonnet-5-5-low vs gpt-6-luna | 1/2 = 50.0% | 77.3% | -27.3 | -35.6 to -16.5 |
| claude-sonnet-5-5-low vs gpt-6.1-sol | 1/2 = 50.0% | 36.3% | +13.7 | +1.1 to +24.6 |
| claude-sonnet-5-5-low vs gpt-6.1-terra | 1/2 = 50.0% | 40.8% | +9.2 | -10.1 to +23.9 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-off | 0/2 = 0.0% | 43.3% | -43.3 | -56.2 to -10.0 |
| claude-sonnet-5-5-max vs gpt-6-astra | 4/10 = 40.0% | 55.0% | -15.0 | -39.1 to +2.3 |
| claude-sonnet-5-5-max vs gpt-6-luna | 2/2 = 100.0% | 92.4% | +7.6 | +4.4 to +11.5 |
| claude-sonnet-5-5-max vs gpt-6.1-sol | 2/2 = 100.0% | 66.9% | +33.1 | +22.8 to +42.9 |
| claude-sonnet-5-5-max vs gpt-6.1-sol-max | 6/10 = 60.0% | 56.6% | +3.4 | -13.8 to +26.6 |
| claude-sonnet-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 61.1% | -11.1 | -21.9 to +0.4 |
| claude-sonnet-5-5-off vs gpt-6-astra | 2/2 = 100.0% | 33.6% | +66.4 | +54.1 to +74.8 |
| claude-sonnet-5-5-off vs gpt-6-luna | 2/2 = 100.0% | 83.3% | +16.7 | +9.9 to +24.4 |
| claude-sonnet-5-5-off vs gpt-6.1-sol | 1/2 = 50.0% | 45.6% | +4.4 | -7.4 to +15.1 |
| claude-sonnet-5-5-xhigh vs gpt-5.6-terra | 2/2 = 100.0% | 71.4% | +28.6 | +18.8 to +38.0 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra | 1/2 = 50.0% | 44.5% | +5.5 | -7.1 to +16.6 |
| claude-sonnet-5-5-xhigh vs gpt-6-luna | 2/2 = 100.0% | 88.8% | +11.2 | +6.4 to +16.6 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 57.1% | -7.1 | -17.7 to +4.4 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 67.6% | -17.6 | -37.0 to +9.2 |
| gpt-5.6-terra vs gpt-6-astra | 5/20 = 25.0% | 24.3% | +0.7 | -13.9 to +15.4 |
| gpt-5.6-terra vs gpt-6-luna | 15/20 = 75.0% | 76.1% | -1.1 | -21.8 to +18.4 |
| gpt-5.6-terra vs gpt-6-luna-high | 2/2 = 100.0% | 56.5% | +43.5 | +28.6 to +56.8 |
| gpt-5.6-terra vs gpt-6-luna-low | 1/2 = 50.0% | 84.0% | -34.0 | -40.6 to -23.4 |
| gpt-5.6-terra vs gpt-6-luna-max | 2/2 = 100.0% | 48.4% | +51.6 | +37.1 to +63.5 |
| gpt-5.6-terra vs gpt-6-luna-off | 2/2 = 100.0% | 83.6% | +16.4 | +9.1 to +25.6 |
| gpt-5.6-terra vs gpt-6.1-sol | 6/20 = 30.0% | 34.8% | -4.8 | -20.4 to +11.1 |
| gpt-5.6-terra vs gpt-6.1-sol-high | 0/2 = 0.0% | 35.4% | -35.4 | -45.8 to -24.4 |
| gpt-5.6-terra vs gpt-6.1-sol-low | 0/2 = 0.0% | 32.7% | -32.7 | -42.5 to -22.1 |
| gpt-5.6-terra vs gpt-6.1-sol-max | 0/2 = 0.0% | 25.5% | -25.5 | -33.5 to -17.3 |
| gpt-5.6-terra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 32.7% | -32.7 | -42.1 to -21.9 |
| gpt-5.6-terra-high vs gpt-6-luna | 1/2 = 50.0% | 74.3% | -24.3 | -33.5 to -11.9 |
| gpt-5.6-terra-high vs gpt-6.1-sol | 1/2 = 50.0% | 32.6% | +17.4 | +4.1 to +27.2 |
| gpt-5.6-terra-low vs gpt-6-astra | 0/2 = 0.0% | 21.0% | -21.0 | -29.9 to -13.0 |
| gpt-5.6-terra-max vs gpt-6-astra | 1/2 = 50.0% | 31.1% | +18.9 | +6.0 to +29.1 |
| gpt-5.6-terra-max vs gpt-6-luna | 2/2 = 100.0% | 81.7% | +18.3 | +10.7 to +27.7 |
| gpt-5.6-terra-xhigh vs gpt-6-astra | 0/2 = 0.0% | 31.0% | -31.0 | -41.8 to -21.0 |
| gpt-5.6-terra-xhigh vs gpt-6.1-sol | 0/2 = 0.0% | 42.6% | -42.6 | -54.4 to -29.8 |
| gpt-6-astra vs gpt-6-luna | 19/20 = 95.0% | 90.8% | +4.2 | -7.6 to +11.2 |
| gpt-6-astra vs gpt-6-luna-high | 1/2 = 50.0% | 80.2% | -30.2 | -37.7 to -19.9 |
| gpt-6-astra vs gpt-6-luna-max | 2/2 = 100.0% | 74.4% | +25.6 | +16.0 to +36.2 |
| gpt-6-astra vs gpt-6-luna-off | 2/2 = 100.0% | 94.1% | +5.9 | +3.3 to +9.8 |
| gpt-6-astra vs gpt-6-luna-xhigh | 1/2 = 50.0% | 72.0% | -22.0 | -30.7 to -10.6 |
| gpt-6-astra vs gpt-6.1-sol | 12/20 = 60.0% | 62.4% | -2.4 | -20.4 to +15.4 |
| gpt-6-astra vs gpt-6.1-sol-high | 1/2 = 50.0% | 63.1% | -13.1 | -22.1 to -2.4 |
| gpt-6-astra vs gpt-6.1-sol-low | 3/4 = 75.0% | 60.2% | +14.8 | -16.0 to +47.0 |
| gpt-6-astra vs gpt-6.1-sol-max | 6/10 = 60.0% | 51.6% | +8.4 | -7.1 to +29.7 |
| gpt-6-astra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 60.2% | -60.2 | -69.1 to -47.4 |
| gpt-6-astra-high vs gpt-6.1-sol | 1/2 = 50.0% | 39.4% | +10.6 | -8.0 to +30.9 |
| gpt-6-astra-low vs gpt-6-luna | 2/2 = 100.0% | 86.9% | +13.1 | +3.7 to +23.8 |
| gpt-6-astra-low vs gpt-6.1-sol | 1/2 = 50.0% | 52.6% | -2.6 | -22.7 to +19.3 |
| gpt-6-luna vs gpt-6.1-sol | 3/20 = 15.0% | 14.3% | +0.7 | -13.4 to +15.7 |
| gpt-6-luna vs gpt-6.1-sol-high | 1/2 = 50.0% | 14.7% | +35.3 | +27.6 to +40.4 |
| gpt-6-luna vs gpt-6.1-sol-low | 0/2 = 0.0% | 13.2% | -13.2 | -20.6 to -7.9 |
| gpt-6-luna vs gpt-6.1-sol-max | 0/2 = 0.0% | 9.7% | -9.7 | -14.0 to -5.9 |
| gpt-6-luna vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 13.3% | -13.3 | -19.3 to -7.8 |
| gpt-6-luna-high vs gpt-6.1-sol | 1/2 = 50.0% | 29.1% | +20.9 | +8.2 to +31.1 |
| gpt-6-luna-low vs gpt-6.1-sol | 0/2 = 0.0% | 9.2% | -9.2 | -15.2 to -4.8 |
| gpt-6-luna-max vs gpt-6.1-sol | 0/2 = 0.0% | 36.3% | -36.3 | -48.8 to -24.2 |
| gpt-6-luna-max vs gpt-6.1-terra-off | 1/2 = 50.0% | 43.3% | +6.7 | -19.5 to +30.5 |
| gpt-6-luna-off vs gpt-6.1-sol | 1/2 = 50.0% | 9.4% | +40.6 | +34.2 to +44.3 |
| gpt-6-luna-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 39.1% | +10.9 | -2.1 to +22.6 |
| gpt-6-luna-xhigh vs gpt-6.1-terra-low | 1/2 = 50.0% | 35.3% | +14.7 | -5.5 to +29.9 |
| gpt-6.1-sol vs gpt-6.1-terra | 1/2 = 50.0% | 54.8% | -4.8 | -22.3 to +10.5 |
| gpt-6.1-sol-high vs gpt-6.1-terra | 1/2 = 50.0% | 54.0% | -4.0 | -20.7 to +12.7 |
| gpt-6.1-sol-max vs gpt-6.1-terra-max | 1/2 = 50.0% | 37.6% | +12.4 | -4.8 to +26.5 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-high | 1/2 = 50.0% | 78.1% | -28.1 | -40.2 to -0.6 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 63.2% | -13.2 | -33.8 to +12.3 |
#### Haiku 4.5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-high | 9/20 = 45.0% | 56.2% | -11.2 | -27.7 to +4.2 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-low | 12/20 = 60.0% | 54.4% | +5.6 | -10.9 to +21.8 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-minimal | 10/20 = 50.0% | 49.3% | +0.7 | -17.9 to +17.0 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 72.0% | +8.0 | -6.2 to +24.6 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-low | 8/20 = 40.0% | 48.2% | -8.2 | -24.4 to +7.6 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal | 11/20 = 55.0% | 43.1% | +11.9 | -6.4 to +30.8 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 66.8% | -1.8 | -19.6 to +15.9 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-minimal | 6/20 = 30.0% | 44.9% | -14.9 | -34.4 to +2.1 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-off | 15/20 = 75.0% | 68.3% | +6.7 | -7.9 to +22.5 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 72.6% | -7.6 | -29.5 to +12.5 |
#### Haiku 5.5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-5-5 vs claude-haiku-5-5-high | 7/20 = 35.0% | 45.8% | -10.8 | -26.5 to +2.6 |
| claude-haiku-5-5 vs claude-haiku-5-5-low | 8/20 = 40.0% | 51.5% | -11.5 | -31.1 to +5.2 |
| claude-haiku-5-5 vs claude-haiku-5-5-max | 9/20 = 45.0% | 39.3% | +5.7 | -10.7 to +21.8 |
| claude-haiku-5-5 vs claude-haiku-5-5-off | 14/20 = 70.0% | 66.0% | +4.0 | -10.7 to +19.0 |
| claude-haiku-5-5 vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 37.8% | -2.8 | -20.5 to +17.3 |
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 55.7% | +9.3 | -9.2 to +27.2 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 43.4% | +1.6 | -18.2 to +21.7 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 69.7% | -4.7 | -18.2 to +9.9 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 41.8% | -11.8 | -27.6 to +2.8 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 37.9% | -2.9 | -20.9 to +15.3 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 64.7% | -9.7 | -28.2 to +8.0 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 36.4% | +3.6 | -9.8 to +17.2 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 75.0% | +5.0 | -9.6 to +19.6 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 48.4% | -3.4 | -19.3 to +12.0 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 23.8% | +1.2 | -16.7 to +20.4 |
#### Luna efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-luna vs gpt-6-luna-high | 8/20 = 40.0% | 29.0% | +11.0 | -9.9 to +32.9 |
| gpt-6-luna vs gpt-6-luna-low | 12/20 = 60.0% | 62.3% | -2.3 | -25.6 to +20.3 |
| gpt-6-luna vs gpt-6-luna-max | 5/20 = 25.0% | 22.7% | +2.3 | -12.4 to +17.7 |
| gpt-6-luna vs gpt-6-luna-off | 12/20 = 60.0% | 61.6% | -1.6 | -22.6 to +17.4 |
| gpt-6-luna vs gpt-6-luna-xhigh | 2/20 = 10.0% | 20.6% | -10.6 | -23.1 to +3.9 |
| gpt-6-luna-high vs gpt-6-luna-low | 14/20 = 70.0% | 80.2% | -10.2 | -25.1 to +4.9 |
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 41.9% | -6.9 | -27.8 to +13.9 |
| gpt-6-luna-high vs gpt-6-luna-off | 18/20 = 90.0% | 79.7% | +10.3 | -2.8 to +23.1 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 38.9% | +16.1 | -2.3 to +35.9 |
| gpt-6-luna-low vs gpt-6-luna-max | 2/20 = 10.0% | 15.1% | -5.1 | -16.8 to +8.2 |
| gpt-6-luna-low vs gpt-6-luna-off | 8/20 = 40.0% | 49.2% | -9.2 | -26.9 to +6.5 |
| gpt-6-luna-low vs gpt-6-luna-xhigh | 3/20 = 15.0% | 13.6% | +1.4 | -13.1 to +21.3 |
| gpt-6-luna-max vs gpt-6-luna-off | 16/20 = 80.0% | 84.5% | -4.5 | -19.0 to +10.0 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 46.9% | +3.1 | -11.2 to +17.5 |
| gpt-6-luna-off vs gpt-6-luna-xhigh | 2/20 = 10.0% | 14.0% | -4.0 | -15.5 to +8.8 |
#### Opus efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5 vs claude-opus-5-5-high | 9/20 = 45.0% | 50.0% | -5.0 | -22.0 to +11.2 |
| claude-opus-5-5 vs claude-opus-5-5-low | 13/20 = 65.0% | 62.9% | +2.1 | -11.2 to +15.0 |
| claude-opus-5-5 vs claude-opus-5-5-max | 4/10 = 40.0% | 41.5% | -1.5 | -32.4 to +29.9 |
| claude-opus-5-5 vs claude-opus-5-5-off | 1/2 = 50.0% | 49.0% | +1.0 | -12.1 to +18.0 |
| claude-opus-5-5 vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 40.2% | -5.2 | -20.1 to +8.6 |
| claude-opus-5-5-high vs claude-opus-5-5-off | 1/2 = 50.0% | 49.0% | +1.0 | -14.8 to +20.6 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 40.3% | -5.3 | -21.4 to +10.0 |
| claude-opus-5-5-low vs claude-opus-5-5-max | 3/10 = 30.0% | 29.5% | +0.5 | -28.9 to +33.7 |
| claude-opus-5-5-low vs claude-opus-5-5-off | 1/2 = 50.0% | 36.2% | +13.8 | -2.7 to +29.5 |
| claude-opus-5-5-max vs claude-opus-5-5-xhigh | 5/10 = 50.0% | 48.7% | +1.3 | -26.7 to +29.1 |
#### Sol efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-sol vs gpt-6.1-sol-high | 12/20 = 60.0% | 50.8% | +9.2 | -3.3 to +24.1 |
| gpt-6.1-sol vs gpt-6.1-sol-low | 7/20 = 35.0% | 47.7% | -12.7 | -30.8 to +6.8 |
| gpt-6.1-sol vs gpt-6.1-sol-max | 8/20 = 40.0% | 39.2% | +0.8 | -17.4 to +18.3 |
| gpt-6.1-sol vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 47.7% | +2.3 | -17.2 to +23.7 |
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 47.0% | +13.0 | -3.6 to +30.4 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 38.4% | +6.6 | -12.6 to +25.1 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 47.0% | -2.0 | -17.8 to +14.3 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 41.3% | -11.3 | -30.6 to +7.4 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 50.0% | +10.0 | -6.3 to +26.8 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 58.7% | -8.7 | -23.0 to +5.7 |
#### Sonnet efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-sonnet-5-5 vs claude-sonnet-5-5-high | 7/20 = 35.0% | 43.3% | -8.3 | -29.2 to +12.4 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-low | 11/20 = 55.0% | 58.0% | -3.0 | -24.0 to +18.2 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-max | 8/20 = 40.0% | 28.0% | +12.0 | -5.3 to +30.8 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-off | 10/20 = 50.0% | 48.4% | +1.6 | -16.3 to +20.0 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 37.1% | +7.9 | -11.9 to +28.9 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 64.4% | -9.4 | -32.3 to +12.5 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 33.7% | +6.3 | -14.6 to +29.0 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 55.2% | +14.8 | +0.2 to +31.7 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 43.7% | -18.7 | -38.4 to +0.7 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 21.9% | -6.9 | -21.6 to +7.2 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 40.5% | +9.5 | -8.1 to +28.4 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 30.0% | -10.0 | -26.4 to +5.5 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 70.7% | -0.7 | -23.3 to +19.7 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 60.3% | +4.7 | -13.5 to +23.1 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 38.6% | +16.4 | +5.4 to +28.8 |
#### Terra 6.1 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-terra vs gpt-6.1-terra-high | 1/2 = 50.0% | 72.9% | -22.9 | -38.2 to +5.5 |
| gpt-6.1-terra vs gpt-6.1-terra-low | 1/2 = 50.0% | 41.1% | +8.9 | -10.0 to +27.5 |
| gpt-6.1-terra vs gpt-6.1-terra-off | 1/2 = 50.0% | 52.6% | -2.6 | -24.5 to +25.2 |
| gpt-6.1-terra vs gpt-6.1-terra-xhigh | 2/2 = 100.0% | 56.4% | +43.6 | +6.7 to +58.6 |
| gpt-6.1-terra-high vs gpt-6.1-terra-xhigh | 0/2 = 0.0% | 32.5% | -32.5 | -51.7 to -5.3 |
| gpt-6.1-terra-low vs gpt-6.1-terra-off | 2/2 = 100.0% | 61.3% | +38.7 | +6.8 to +50.8 |
| gpt-6.1-terra-max vs gpt-6.1-terra-xhigh | 2/2 = 100.0% | 80.1% | +19.9 | +3.1 to +31.3 |
#### Terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-5.6-terra vs gpt-5.6-terra-high | 10/20 = 50.0% | 52.4% | -2.4 | -16.8 to +12.4 |
| gpt-5.6-terra vs gpt-5.6-terra-low | 11/20 = 55.0% | 54.8% | +0.2 | -15.4 to +17.4 |
| gpt-5.6-terra vs gpt-5.6-terra-max | 8/20 = 40.0% | 41.6% | -1.6 | -21.1 to +17.8 |
| gpt-5.6-terra vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 41.8% | -6.8 | -22.2 to +7.5 |
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 52.4% | -7.4 | -26.8 to +9.9 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.3% | +0.7 | -16.1 to +17.3 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 39.5% | +10.5 | -8.0 to +31.2 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 37.0% | +3.0 | -15.5 to +23.9 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 37.2% | -17.2 | -33.3 to -2.0 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 50.2% | +4.8 | -10.9 to +21.1 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| Astra efforts | - | - | - | - | - | - | no spare pairs: a tree of pairs, so pair effects are not identified |
| Cross-model | 0.6293 | 0.6294 | -0.0001 | -0.0002 to +0.0000 | 0: 46, 0.1: 3, 0.2: 1 | tau=0.1: 0.6295, tau=0.2: 0.6302, tau=0.4: 0.6327, tau=0.8: 0.6402, tau=1.6: 0.6529 | not kept |
| Cross-model (seat and starter terms) | 0.6062 | 0.6063 | -0.0002 | -0.0002 to -0.0001 | 0: 46, 0.1: 2, 0.2: 2 | tau=0.1: 0.6064, tau=0.2: 0.6070, tau=0.4: 0.6095, tau=0.8: 0.6170, tau=1.6: 0.6294 | not kept |
| Haiku 4.5 efforts | 0.6739 | 0.6769 | -0.0030 | -0.0087 to +0.0020 | 0: 17, 0.1: 6, 0.2: 16, 0.4: 9, 0.8: 2 | tau=0.1: 0.6739, tau=0.2: 0.6740, tau=0.4: 0.6764, tau=0.8: 0.6839, tau=1.6: 0.6912 | not kept |
| Haiku 4.5 efforts (seat and starter terms) | 0.6702 | 0.6729 | -0.0027 | -0.0071 to +0.0015 | 0: 19, 0.1: 6, 0.2: 11, 0.4: 13, 0.8: 1 | tau=0.1: 0.6700, tau=0.2: 0.6699, tau=0.4: 0.6712, tau=0.8: 0.6772, tau=1.6: 0.6834 | not kept |
| Haiku 5.5 efforts | 0.6637 | 0.6647 | -0.0010 | -0.0018 to -0.0004 | 0: 43, 0.1: 2, 0.2: 4, 0.4: 1 | tau=0.1: 0.6641, tau=0.2: 0.6653, tau=0.4: 0.6695, tau=0.8: 0.6776, tau=1.6: 0.6842 | not kept |
| Haiku 5.5 efforts (seat and starter terms) | 0.6398 | 0.6415 | -0.0017 | -0.0029 to -0.0007 | 0: 41, 0.2: 6, 0.4: 3 | tau=0.1: 0.6403, tau=0.2: 0.6417, tau=0.4: 0.6464, tau=0.8: 0.6561, tau=1.6: 0.6643 | not kept |
| Luna efforts | 0.5748 | 0.5772 | -0.0024 | -0.0046 to -0.0005 | 0: 27, 0.1: 6, 0.2: 11, 0.4: 6 | tau=0.1: 0.5750, tau=0.2: 0.5758, tau=0.4: 0.5794, tau=0.8: 0.5890, tau=1.6: 0.6003 | not kept |
| Luna efforts (seat and starter terms) | 0.5796 | 0.5805 | -0.0009 | -0.0025 to +0.0006 | 0: 29, 0.1: 4, 0.2: 14, 0.4: 3 | tau=0.1: 0.5796, tau=0.2: 0.5800, tau=0.4: 0.5824, tau=0.8: 0.5905, tau=1.6: 0.6008 | not kept |
| Opus efforts | 0.6999 | 0.6999 | +0.0000 | +0.0000 to +0.0000 | 0: 50 | tau=0.1: 0.7008, tau=0.2: 0.7030, tau=0.4: 0.7098, tau=0.8: 0.7221, tau=1.6: 0.7337 | not kept |
| Opus efforts (seat and starter terms) | 0.7040 | 0.7059 | -0.0019 | -0.0048 to +0.0001 | 0: 49, 0.8: 1 | tau=0.1: 0.7046, tau=0.2: 0.7062, tau=0.4: 0.7111, tau=0.8: 0.7205, tau=1.6: 0.7293 | not kept |
| Sol efforts | 0.7029 | 0.7060 | -0.0031 | -0.0096 to +0.0023 | 0: 16, 0.1: 5, 0.2: 12, 0.4: 16, 0.8: 1 | tau=0.1: 0.7027, tau=0.2: 0.7026, tau=0.4: 0.7041, tau=0.8: 0.7103, tau=1.6: 0.7165 | not kept |
| Sol efforts (seat and starter terms) | 0.7077 | 0.7130 | -0.0053 | -0.0120 to +0.0009 | 0: 18, 0.1: 5, 0.2: 14, 0.4: 11, 0.8: 2 | tau=0.1: 0.7075, tau=0.2: 0.7072, tau=0.4: 0.7084, tau=0.8: 0.7143, tau=1.6: 0.7205 | not kept |
| Sonnet efforts | 0.6722 | 0.6757 | -0.0035 | -0.0097 to +0.0026 | 0: 11, 0.1: 6, 0.2: 15, 0.4: 16, 0.8: 2 | tau=0.1: 0.6718, tau=0.2: 0.6713, tau=0.4: 0.6722, tau=0.8: 0.6788, tau=1.6: 0.6866 | not kept |
| Sonnet efforts (seat and starter terms) | 0.6720 | 0.6752 | -0.0031 | -0.0087 to +0.0016 | 0: 11, 0.1: 2, 0.2: 18, 0.4: 19 | tau=0.1: 0.6717, tau=0.2: 0.6713, tau=0.4: 0.6726, tau=0.8: 0.6798, tau=1.6: 0.6878 | not kept |
| Terra 6.1 efforts | - | - | - | - | - | - | 7 seed blocks, under the minimum of 10: the fit with seat and starter terms can be singular on so few, so not tested |
| Terra efforts | 0.6884 | 0.6912 | -0.0028 | -0.0052 to -0.0005 | 0: 36, 0.1: 4, 0.2: 3, 0.4: 7 | tau=0.1: 0.6885, tau=0.2: 0.6891, tau=0.4: 0.6919, tau=0.8: 0.6981, tau=1.6: 0.7034 | not kept |
| Terra efforts (seat and starter terms) | 0.7013 | 0.7022 | -0.0009 | -0.0024 to +0.0005 | 0: 39, 0.1: 4, 0.2: 4, 0.4: 3 | tau=0.1: 0.7014, tau=0.2: 0.7020, tau=0.4: 0.7049, tau=0.8: 0.7115, tau=1.6: 0.7174 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| Cross-model | 106/225 = 47.1% | -0.25 |
| Haiku 4.5 efforts | 7/10 = 70.0% | +0.05 |
| Haiku 5.5 efforts | 5/15 = 33.3% | -0.44 |
| Luna efforts | 7/15 = 46.7% | -0.09 |
| Opus efforts | 0/10 = 0.0% | -0.97 |
| Sol efforts | 6/10 = 60.0% | -0.18 |
| Sonnet efforts | 6/15 = 40.0% | -0.04 |
| Terra efforts | 4/10 = 40.0% | -0.15 |
| all cohorts pooled | 141/310 = 45.5% | -0.26 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 1.3e-16, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 2685 of 2685 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 1342 blocks, 78 seeds (1 matches in half blocks left out) | 1342/2684 = 50.0% | 42.9% to 56.6% | 48.2% to 51.8% |
| Astra efforts: 2 blocks, 1 seeds | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% |
| Cross-model: 525 blocks, 68 seeds (1 matches in half blocks left out) | 494/1050 = 47.0% | 39.6% to 55.1% | 44.0% to 50.1% |
| Haiku 4.5 efforts: 100 blocks, 10 seeds | 105/200 = 52.5% | 42.5% to 60.5% | 45.5% to 59.5% |
| Haiku 5.5 efforts: 150 blocks, 10 seeds | 142/300 = 47.3% | 34.7% to 59.7% | 41.3% to 53.3% |
| Luna efforts: 150 blocks, 10 seeds | 160/300 = 53.3% | 47.7% to 59.3% | 48.3% to 58.0% |
| Opus efforts: 58 blocks, 18 seeds | 61/116 = 52.6% | 39.3% to 66.1% | 43.1% to 62.1% |
| Sol efforts: 100 blocks, 10 seeds | 111/200 = 55.5% | 42.5% to 68.0% | 48.0% to 62.5% |
| Sonnet efforts: 150 blocks, 10 seeds | 162/300 = 54.0% | 42.7% to 64.7% | 48.3% to 59.7% |
| Terra 6.1 efforts: 7 blocks, 7 seeds | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% |
| Terra efforts: 100 blocks, 10 seeds | 96/200 = 48.0% | 36.5% to 59.5% | 40.5% to 56.0% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 1538/2684 = 57.3% | 51.7% to 63.2% | 55.3% to 59.1% | 643/1342 |
| Astra efforts | 3/4 = 75.0% | 75.0% to 75.0% | 50.0% to 100.0% | 2/2 |
| Cross-model | 628/1050 = 59.8% | 53.7% to 65.7% | 57.0% to 62.6% | 231/525 |
| Haiku 4.5 efforts | 115/200 = 57.5% | 50.5% to 65.5% | 51.0% to 64.0% | 50/100 |
| Haiku 5.5 efforts | 186/300 = 62.0% | 51.0% to 72.3% | 56.3% to 67.7% | 75/150 |
| Luna efforts | 152/300 = 50.7% | 44.7% to 57.0% | 46.0% to 55.7% | 75/150 |
| Opus efforts | 67/116 = 57.8% | 44.4% to 71.3% | 48.3% to 67.2% | 31/58 |
| Sol efforts | 107/200 = 53.5% | 40.5% to 66.0% | 46.0% to 60.5% | 50/100 |
| Sonnet efforts | 164/300 = 54.7% | 43.7% to 64.7% | 49.3% to 60.0% | 75/150 |
| Terra 6.1 efforts | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% | 4/7 |
| Terra efforts | 108/200 = 54.0% | 42.5% to 64.5% | 46.5% to 61.5% | 50/100 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +0.3 | -6.2 to +5.9 | -1.5 to +2.2 | +7.3 | +1.6 to +13.2 | +5.3 to +9.1 |
| Cross-model | -1.8 | -8.0 to +4.8 | -4.7 to +1.1 | +9.6 | +3.5 to +15.7 | +6.7 to +12.4 |
| Haiku 4.5 efforts | +2.5 | -6.3 to +9.5 | -4.5 to +9.3 | +7.5 | +0.6 to +16.4 | +0.8 to +14.0 |
| Haiku 5.5 efforts | -2.7 | -14.3 to +7.7 | -8.1 to +3.0 | +12.0 | +0.3 to +23.0 | +6.0 to +17.6 |
| Luna efforts | +3.3 | -3.0 to +9.6 | -1.5 to +8.0 | +0.7 | -5.4 to +7.2 | -4.1 to +5.7 |
| Opus efforts | +2.1 | -11.6 to +15.7 | -6.9 to +11.4 | +7.6 | -6.3 to +21.6 | -1.8 to +16.9 |
| Sol efforts | +5.5 | -8.3 to +19.0 | -2.3 to +12.6 | +3.5 | -9.6 to +17.1 | -4.0 to +10.4 |
| Sonnet efforts | +4.0 | -7.5 to +15.3 | -1.7 to +9.4 | +4.7 | -7.3 to +15.0 | -0.7 to +9.9 |
| Terra 6.1 efforts | +6.2 | -20.8 to +33.3 | -20.8 to +35.0 | +6.2 | -20.8 to +35.0 | -20.8 to +33.3 |
| Terra efforts | -2.0 | -14.0 to +9.4 | -9.5 to +5.8 | +4.0 | -9.0 to +15.0 | -3.5 to +11.2 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| claude-haiku-4-5-20251001: 212 blocks, 23 seeds | 208/424 = 49.1% | 42.2% to 55.6% | 44.3% to 53.8% |
| claude-haiku-5-5: 278 blocks, 32 seeds | 259/556 = 46.6% | 37.5% to 55.8% | 42.1% to 51.3% |
| claude-opus-5-5: 203 blocks, 57 seeds | 198/406 = 48.8% | 40.3% to 57.1% | 43.3% to 53.9% |
| claude-sonnet-5-5: 299 blocks, 41 seeds | 303/598 = 50.7% | 43.1% to 58.2% | 46.8% to 54.5% |
| gpt-5.6-terra: 208 blocks, 19 seeds | 217/416 = 52.2% | 42.8% to 61.2% | 47.1% to 57.2% |
| gpt-6-astra: 134 blocks, 47 seeds | 129/268 = 48.1% | 39.3% to 58.0% | 41.8% to 54.1% |
| gpt-6-luna: 269 blocks, 27 seeds | 266/538 = 49.4% | 44.3% to 54.4% | 45.7% to 53.2% |
| gpt-6.1-sol: 242 blocks, 39 seeds | 235/484 = 48.6% | 39.8% to 57.0% | 43.6% to 53.3% |
| gpt-6.1-terra: 22 blocks, 12 seeds | 21/44 = 47.7% | 29.4% to 64.3% | 31.8% to 65.9% |

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
