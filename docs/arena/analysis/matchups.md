# Matchup analysis

Ratings, pair effects, seat and round 1 starter effects for the scored arena matches, from the analysis database ([database.md](../database.md)). All scored matches are two-player. Every rate shows numerator/denominator, a win share counts a split by its share, and every interval is a 95% bootstrap that draws whole units, never single matches or seat swaps: seed blocks (the two seat-swapped matches of one pair and seed) for ratings, and seeds (every block played at a seed, in any pairing) for the headline seat and starter figures. The tables below the line "Tables" are generated: `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` rewrites them, with a fixed RNG seed, in about 11 minutes under `nice` on the 2,553-match snapshot. Nothing here reads provenance or account data.

**DeepSeek is left out.** Every match with deepseek-v4.1-flash (20 scored matches) is dropped from all cohorts, fits, seat and starter figures and tables, because its free tier refused requests, so its games are not a random sample of what was scheduled. That leaves 2,533 scored matches from the 2,553-match snapshot of 2026-10-30. Every finding below uses these.

## Findings

**Ratings are pooled.** One Bradley-Terry fit covers every scored match of every tournament, so all 48 configs share one Elo scale with the mean at 0, as in the viewer. Tournament 4 gave every older config games against other models, so no rating leans on an assumption that effort gaps carry across opponents. Tournament 5's configs have 2 to 12 matches against changing opponents, so their intervals are often several hundred Elo wide and their point ratings mostly reflect the prior pulling a thin record. `results.md` and the viewer show the same ratings. A second fit on pot share (a config's cash over the match's cash, which credits the round prizes a loser banks) gives the cash rating. Cohorts are only a way to group matches. A cohort is one kind of comparison, pooled over every tournament: Cross-model (every match between different models) or one model's efforts (every match of that model against itself), as in the viewer. There are nine: Cross-model and the efforts of Haiku 4.5, Haiku 5.5, Luna, Opus, Sol, Sonnet, Terra and Terra 6.1.
- **Coverage.** The Cross-model cohort has 48 entrants and 931 matches over 194 of the 1,128 pairs, 2 to 41 matches per pair. Each older effort cohort is a round robin with 20 matches per pair. Opus efforts plays 8 of its 15 pairs and Terra 6.1 efforts 7 of 15, 2 matches each. Tournament 5 is still partly unplayed (160 Cross-model, 28 Opus and 16 Terra 6.1 scheduled matches are unstarted).
- **Cross-model medium configs**, win rating (95% CI by seed blocks): astra +149 (+101 to +205), opus +72 (+25 to +123), sol +65 (+17 to +113), haiku 5.5 +17 (-26 to +63), sonnet +15 (-28 to +64), terra -50 (-100 to +0), haiku 4.5 -163 (-218 to -109), luna -252 (-318 to -197). Astra stands above and luna and haiku 4.5 below; the middle ones overlap. Drawing seeds instead of blocks moves the intervals modestly.
- **Top and bottom.** Among configs with 80 or more matches, Opus xhigh +180 (+99 to +266), Sonnet max +160, astra +149 and Sol max +145 lead. Luna low -341, luna off -335 and haiku 4.5 off -327 trail. Opus max (8 matches, +334) and Terra 6.1 max (4 matches, +227) rate higher but their intervals start near 0 and run to +500 or more. Effort configs from the older tournaments have 80 to 110 matches each, so their intervals are about 150 to 200 Elo wide.
- **Effort.** Within each model the top level is xhigh or max in every model with a sweep or effort tournament, Terra 6.1 and Opus included, though the Opus and Terra 6.1 max cells are tiny: luna xhigh -21 and max -42 against medium -252, sonnet max +160 against medium +15, haiku 5.5 xhigh +103, terra max +10, sol max +145, Opus max +334 and xhigh +180. Haiku 4.5 has no such level; its top is minimal (-158) and medium (-163). Off or low is the bottom level in the older sweeps: luna low -341, haiku 4.5 off -327, haiku 5.5 off -99, sonnet low -49, terra low -83 and Opus low -24. Sol is the exception: medium +65 sits at the bottom of a flat range up to +145, and the intervals overlap. The order of neighbouring levels is mostly inside the intervals.
- **Cash.** Cash ratings spread less than win ratings among configs with 80 or more matches (+112 to -217 against +180 to -341), because losers bank round prizes. The two ratings agree on the leaders (Sonnet max +112, Sol max +104, Opus xhigh +96) and the trailers (luna low -217). A config can win less than it earns: Opus low wins 41.2% of its 34 matches yet takes 54.0% of the pot (cash +56, win -24), and terra high wins 44.4% and takes 49.6% (cash +2, win -66). Haiku 5.5 xhigh is the reverse: 62.7% of wins, 54.0% of the pot, cash +16 against win +103.

**Matchup effects: none worth keeping.** The observed pair share minus the share fitted by the pooled ratings is small and is reported as a descriptive residual. It is not a test: the ratings are regularized, so residuals are forced (a pair at the end of a chain of pairs is pulled to its fit), and the bootstrap range around a residual is not a calibrated interval around zero. The largest Cross-model residual over a pair of 20 matches or more is haiku 4.5 against sonnet (-16.4 points). Pairs of 2 matches are too thin to read.
- The test is held-out prediction. Whole seed blocks were held out (5 repeats of 10-fold cross-validation, with the shrinkage chosen inside each training set from 0 to 1.6, so no held-out block picks it). Pair effects are fitted only for pairs seen in more than one seed block: a pair confined to one block has no training data when that block is held out, so its games still count in the test score but it gets no pair term. Terra 6.1 efforts has 7 seed blocks, too few for 10 folds, so it is not tested. In every other cohort the nested pair-effect model scored no better than ratings alone: the gain per match is between -0.0090 and -0.0000 nats, and the lower end of its interval is never above 0. The shrinkage chose 0 (ratings only) in most folds for Cross-model, Haiku 5.5, Luna, Opus and Terra. So **no tested cohort keeps pair effects**. Cross-model holds tournament 4's one-block pairs, tournament 5's and the 41-match Opus xhigh against Astra pair.
- The same holds when the ratings also have a seat term and a round 1 starter term, which on their own lower the Cross-model loss from 0.6224 to 0.6053 per match.
- Reverse pairs, described and not tested: for the entrant seated first, a real matchup effect should show the opposite sign when A sat first and when B sat first. 132 of 277 pairs (47.7%) do, with a correlation of -0.27 between the A-first effect and minus the B-first effect (a negative value means the two orders lean the same way). The signs are not independent (the two orders of a block share a seed, seeds are reused across pairings, and the ratings are fitted jointly), so no test is made. The two entrants' effects in a pair sum to zero to rounding (6e-17) because every match's shares sum to 1.
- With 20 matches per pair in the effort cohorts and 2 in most of Cross-model, only large pair effects could show.

**Seat and starter.** Whoever opens round 1 (read from the public line `Round 1 begins ... Player X starts.` of each match's events) also fired the first shot in 2533 of 2533 matches. The seed decides that position, and both matches of a block share it.
- **Position 1:** 1276/2532 = 50.4% over 1,266 complete blocks at 53 seeds (95% CI by seeds 43.6% to 57.7%; by seed blocks 48.4% to 52.4%). Cross-model 448/930 = 48.2% (40.2% to 57.7% by seeds).
- **Starter:** the player who opens round 1 won 1440/2532 = 56.9% (50.5% to 63.4% by seeds; 55.0% to 58.7% by seed blocks). The overall starter association stands: it is about 7 points above even.
- **Split:** the position and starter effects below are a descriptive additive split of block shares by which position starts. Every complete-block seed has exactly one starter position, so a starter effect cannot be told from a seed effect. The split describes these seed blocks; only the seeds-drawn intervals reach beyond them. Starter +6.9 points overall (seeds +0.4 to +13.5; blocks +5.1 to +8.8), +9.1 Cross-model (+1.7 to +16.5; blocks +6.0 to +12.3). Position +0.7 overall (-5.9 to +7.0 by seeds).
- **It depends on the seed.** The starter won 173/244 = 70.9% of matches at seed 3000 and 28/74 = 37.8% at seed 3005. Counting each of the 19 seeds with 10 or more blocks once, the starter's mean share is 57.7% (51.7% to 63.8%, seeds drawn). Starter figures are therefore not reported per model: a model's blocks cover a handful of seeds, so they say as much about those seeds as about the model. Position 1 per model is in the tables.
- **Recommendation:** a starter term is worth keeping as an option for future ratings. It lowers held-out loss a lot (Cross-model 0.6224 to 0.6053 per match) and moves the pooled ratings by up to 7.4 Elo. The headline fits stay without it.

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
- **Thin cells.** Tournament 4 has one seat-swapped block (2 matches) per pair, so one pair says little; its value is that it links every config to the others. Sonnet max's rating rests on its 8 tournament-4 matches and 2 tournament-1 games.
- **Position and starter overlap** because the seed fixes the starter's position, and tournament 1's seeds 3000 to 3009 start position 2 six times in ten.
- **No replays.** Everything comes from standings, cash, seating and the public round 1 line; no moves were reviewed.

## Tables

<!-- tables:start -->
### Schedule coverage

| cohort | entrants | scored matches | complete / half blocks | pairs played | matches per pair min / median / max | connected | scheduled by status |
|---|---|---|---|---|---|---|---|
| Cross-model | 48 | 931 | 465 / 1 | 194/1128 | 2 / 2 / 41 | yes | 931 completed, 5 partial (skipped), 138 skipped (skipped), 160 unstarted |
| Haiku 4.5 efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| Haiku 5.5 efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Luna efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Opus efforts | 6 | 88 | 44 / 0 | 8/15 | 2 / 11 / 20 | yes | 88 completed, 28 unstarted |
| Sol efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |
| Sonnet efforts | 6 | 300 | 150 / 0 | 15/15 | 20 / 20 / 20 | yes | 300 completed |
| Terra 6.1 efforts | 6 | 14 | 7 / 0 | 7/15 | 2 / 2 / 2 | yes | 14 completed, 16 unstarted |
| Terra efforts | 5 | 200 | 100 / 0 | 10/10 | 20 / 20 / 20 | yes | 200 completed |

### Pooled ratings

| config | wins/matches = win share | rating (Elo, mean 0) | 95% CI, seed blocks drawn | 95% CI, seeds drawn (sensitivity) | pot share | cash rating (Elo, mean 0) | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5-max | 7/8 = 87.5% | +334 | +48 to +605 | +0 to +629 | 71.4% | +190 | +48 to +278 |
| gpt-6.1-terra-max | 3/4 = 75.0% | +227 | +0 to +505 | +0 to +474 | 66.1% | +126 | -47 to +487 |
| claude-opus-5-5-xhigh | 48/81 = 59.3% | +180 | +99 to +266 | +105 to +264 | 54.7% | +96 | +50 to +142 |
| gpt-6.1-terra-low | 4/6 = 66.7% | +167 | -25 to +541 | -17 to +538 | 61.1% | +72 | -40 to +260 |
| claude-sonnet-5-5-max | 76/110 = 69.1% | +160 | +82 to +255 | +47 to +317 | 64.3% | +112 | +66 to +165 |
| gpt-6-astra | 149/219 = 68.0% | +149 | +101 to +205 | +103 to +201 | 61.3% | +84 | +57 to +113 |
| gpt-6.1-sol-max | 56/92 = 60.9% | +145 | +67 to +228 | +55 to +234 | 57.0% | +104 | +53 to +150 |
| claude-haiku-5-5-xhigh | 69/110 = 62.7% | +103 | +29 to +185 | +31 to +181 | 54.0% | +16 | -21 to +58 |
| gpt-6.1-terra | 7/12 = 58.3% | +95 | -72 to +277 | -55 to +244 | 53.5% | +23 | -75 to +135 |
| claude-opus-5-5-off | 5/8 = 62.5% | +94 | -50 to +359 | -50 to +355 | 58.6% | +81 | -4 to +211 |
| claude-haiku-5-5-max | 67/110 = 60.9% | +92 | +20 to +168 | +9 to +189 | 58.6% | +45 | +9 to +82 |
| claude-sonnet-5-5-xhigh | 64/112 = 57.1% | +89 | +15 to +174 | +6 to +177 | 53.2% | +47 | +10 to +90 |
| claude-opus-5-5-high | 24/50 = 48.0% | +88 | -19 to +198 | -27 to +210 | 47.9% | +42 | -12 to +96 |
| gpt-6.1-sol-xhigh | 49/94 = 52.1% | +86 | +8 to +169 | +4 to +169 | 52.7% | +73 | +25 to +120 |
| gpt-6.1-sol-low | 45/90 = 50.0% | +81 | +2 to +162 | +6 to +158 | 49.9% | +63 | +17 to +107 |
| gpt-6-astra-low | 5/8 = 62.5% | +76 | +4 to +208 | +1 to +201 | 50.0% | -9 | -56 to +35 |
| claude-opus-5-5 | 144/248 = 58.1% | +72 | +25 to +123 | +20 to +124 | 54.5% | +44 | +19 to +71 |
| gpt-6.1-sol-high | 44/90 = 48.9% | +68 | -6 to +145 | -15 to +145 | 48.7% | +52 | +7 to +99 |
| gpt-6.1-terra-off | 3/6 = 50.0% | +66 | -370 to +412 | -357 to +412 | 44.4% | -14 | -207 to +110 |
| gpt-6.1-sol | 151/266 = 56.8% | +65 | +17 to +113 | +7 to +132 | 56.5% | +59 | +31 to +84 |
| gpt-6-astra-high | 2/4 = 50.0% | +62 | +0 to +100 | +0 to +108 | 67.8% | +161 | +0 to +184 |
| claude-sonnet-5-5-high | 59/112 = 52.7% | +51 | -31 to +141 | -32 to +137 | 50.5% | +25 | -18 to +74 |
| claude-haiku-5-5-high | 58/112 = 51.8% | +36 | -37 to +105 | -25 to +98 | 51.8% | +4 | -35 to +42 |
| claude-haiku-5-5 | 147/280 = 52.5% | +17 | -26 to +63 | -16 to +60 | 51.1% | +0 | -23 to +24 |
| claude-haiku-5-5-low | 54/112 = 48.2% | +16 | -60 to +90 | -51 to +90 | 48.8% | -12 | -53 to +29 |
| claude-sonnet-5-5 | 142/278 = 51.1% | +15 | -28 to +64 | -33 to +65 | 51.3% | +14 | -9 to +42 |
| claude-sonnet-5-5-off | 50/112 = 44.6% | +11 | -66 to +93 | -56 to +89 | 45.4% | +1 | -42 to +47 |
| gpt-5.6-terra-max | 52/90 = 57.8% | +10 | -77 to +103 | -55 to +80 | 53.8% | +24 | -21 to +71 |
| gpt-5.6-terra-xhigh | 51/90 = 56.7% | +8 | -79 to +95 | -74 to +86 | 54.7% | +33 | -8 to +76 |
| gpt-6-luna-xhigh | 78/112 = 69.6% | -21 | -103 to +66 | -93 to +54 | 64.4% | -2 | -49 to +47 |
| claude-opus-5-5-low | 14/34 = 41.2% | -24 | -130 to +74 | -141 to +75 | 54.0% | +56 | -9 to +116 |
| gpt-6.1-terra-xhigh | 3/8 = 37.5% | -27 | -435 to +294 | -432 to +298 | 37.5% | -66 | -333 to +332 |
| gpt-6-luna-max | 74/110 = 67.3% | -42 | -128 to +53 | -120 to +38 | 63.2% | -12 | -62 to +38 |
| claude-sonnet-5-5-low | 40/112 = 35.7% | -49 | -132 to +37 | -127 to +35 | 42.2% | -22 | -63 to +27 |
| gpt-5.6-terra | 119/256 = 46.5% | -50 | -100 to +0 | -97 to -2 | 48.3% | -16 | -43 to +10 |
| gpt-5.6-terra-high | 40/90 = 44.4% | -66 | -148 to +16 | -131 to -5 | 49.6% | +2 | -40 to +45 |
| gpt-5.6-terra-low | 37/90 = 41.1% | -83 | -168 to -2 | -162 to -10 | 45.7% | -20 | -64 to +23 |
| gpt-6-luna-high | 66/110 = 60.0% | -98 | -190 to +1 | -196 to +11 | 55.6% | -63 | -104 to -20 |
| claude-haiku-5-5-off | 34/110 = 30.9% | -99 | -178 to -26 | -173 to -30 | 35.7% | -96 | -137 to -54 |
| gpt-6.1-terra-high | 2/8 = 25.0% | -133 | -539 to +117 | -520 to +132 | 33.1% | -104 | -426 to +69 |
| claude-haiku-4-5-20251001-minimal | 50/90 = 55.6% | -158 | -247 to -65 | -234 to -85 | 50.0% | -117 | -166 to -67 |
| claude-haiku-4-5-20251001 | 98/256 = 38.3% | -163 | -218 to -109 | -221 to -110 | 41.7% | -101 | -132 to -71 |
| claude-haiku-4-5-20251001-low | 45/90 = 50.0% | -193 | -287 to -105 | -278 to -117 | 51.3% | -111 | -161 to -61 |
| claude-haiku-4-5-20251001-high | 43/90 = 47.8% | -205 | -294 to -118 | -325 to -101 | 49.4% | -121 | -164 to -74 |
| gpt-6-luna | 73/276 = 26.4% | -252 | -318 to -197 | -303 to -201 | 34.4% | -147 | -177 to -118 |
| claude-haiku-4-5-20251001-off | 25/90 = 27.8% | -327 | -429 to -239 | -439 to -226 | 36.3% | -195 | -246 to -146 |
| gpt-6-luna-off | 29/110 = 26.4% | -335 | -434 to -250 | -447 to -240 | 33.8% | -202 | -254 to -154 |
| gpt-6-luna-low | 28/110 = 25.5% | -341 | -450 to -239 | -410 to -279 | 31.4% | -217 | -269 to -167 |

With a seat term and a round 1 starter term in the fit (position 1 +6 Elo, the starter +56 Elo) the largest rating change is 7.4 Elo.


### Observed pairs against the pooled ratings

Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below. Every resample refits the pooled ratings.

#### Cross-model

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-5-5 | 6/20 = 30.0% | 26.2% | +3.8 | -11.4 to +18.9 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-high | 0/2 = 0.0% | 24.2% | -24.2 | -33.4 to -16.1 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-low | 0/2 = 0.0% | 26.3% | -26.3 | -37.0 to -17.4 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-max | 0/2 = 0.0% | 18.7% | -18.7 | -26.2 to -12.0 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-off | 1/2 = 50.0% | 40.9% | +9.1 | -3.4 to +19.9 |
| claude-haiku-4-5-20251001 vs claude-haiku-5-5-xhigh | 1/2 = 50.0% | 17.8% | +32.2 | +22.3 to +38.6 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5 | 7/20 = 35.0% | 20.5% | +14.5 | -3.9 to +34.1 |
| claude-haiku-4-5-20251001 vs claude-opus-5-5-low | 0/2 = 0.0% | 31.0% | -31.0 | -44.5 to -18.9 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5 | 2/20 = 10.0% | 26.4% | -16.4 | -28.9 to -2.0 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-high | 0/2 = 0.0% | 22.6% | -22.6 | -33.2 to -13.8 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-low | 0/2 = 0.0% | 34.2% | -34.2 | -46.3 to -22.0 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 13.5% | -13.5 | -20.7 to -7.5 |
| claude-haiku-4-5-20251001 vs claude-sonnet-5-5-off | 0/2 = 0.0% | 26.9% | -26.9 | -37.5 to -17.0 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra | 6/20 = 30.0% | 34.3% | -4.3 | -21.0 to +10.3 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-low | 0/2 = 0.0% | 38.7% | -38.7 | -51.4 to -26.8 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-max | 0/2 = 0.0% | 27.1% | -27.1 | -38.5 to -16.9 |
| claude-haiku-4-5-20251001 vs gpt-5.6-terra-xhigh | 1/2 = 50.0% | 27.2% | +22.8 | +11.4 to +31.7 |
| claude-haiku-4-5-20251001 vs gpt-6-astra | 3/20 = 15.0% | 14.2% | +0.8 | -12.5 to +16.0 |
| claude-haiku-4-5-20251001 vs gpt-6-luna | 12/20 = 60.0% | 62.6% | -2.6 | -28.1 to +19.9 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-high | 1/2 = 50.0% | 40.8% | +9.2 | -5.7 to +23.2 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-off | 2/2 = 100.0% | 73.0% | +27.0 | +15.8 to +38.7 |
| claude-haiku-4-5-20251001 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 30.7% | +19.3 | +6.8 to +29.8 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol | 6/20 = 30.0% | 21.2% | +8.8 | -10.3 to +29.6 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-high | 1/2 = 50.0% | 20.9% | +29.1 | +19.5 to +36.3 |
| claude-haiku-4-5-20251001 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 19.3% | +30.7 | +19.8 to +38.0 |
| claude-haiku-4-5-20251001-high vs claude-sonnet-5-5 | 0/2 = 0.0% | 21.9% | -21.9 | -31.7 to -13.4 |
| claude-haiku-4-5-20251001-high vs gpt-5.6-terra | 0/2 = 0.0% | 29.0% | -29.0 | -41.1 to -18.7 |
| claude-haiku-4-5-20251001-high vs gpt-6-astra | 0/2 = 0.0% | 11.5% | -11.5 | -18.1 to -6.6 |
| claude-haiku-4-5-20251001-high vs gpt-6-luna | 0/2 = 0.0% | 56.7% | -56.7 | -68.5 to -41.4 |
| claude-haiku-4-5-20251001-high vs gpt-6.1-sol | 0/2 = 0.0% | 17.4% | -17.4 | -27.4 to -10.7 |
| claude-haiku-4-5-20251001-low vs claude-haiku-5-5 | 1/2 = 50.0% | 23.0% | +27.0 | +16.1 to +34.9 |
| claude-haiku-4-5-20251001-low vs claude-opus-5-5 | 0/2 = 0.0% | 17.9% | -17.9 | -27.2 to -10.5 |
| claude-haiku-4-5-20251001-low vs gpt-5.6-terra | 1/2 = 50.0% | 30.5% | +19.5 | +6.6 to +29.7 |
| claude-haiku-4-5-20251001-low vs gpt-6-luna | 2/2 = 100.0% | 58.5% | +41.5 | +26.8 to +54.5 |
| claude-haiku-4-5-20251001-low vs gpt-6.1-sol | 0/2 = 0.0% | 18.5% | -18.5 | -27.8 to -10.8 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-5-5 | 1/2 = 50.0% | 26.8% | +23.2 | +10.3 to +32.5 |
| claude-haiku-4-5-20251001-minimal vs claude-opus-5-5 | 1/2 = 50.0% | 21.0% | +29.0 | +16.6 to +36.9 |
| claude-haiku-4-5-20251001-minimal vs claude-sonnet-5-5 | 1/2 = 50.0% | 27.0% | +23.0 | +10.3 to +32.2 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-astra | 0/2 = 0.0% | 14.6% | -14.6 | -22.8 to -8.5 |
| claude-haiku-4-5-20251001-minimal vs gpt-6-luna | 1/2 = 50.0% | 63.3% | -13.3 | -25.9 to +0.9 |
| claude-haiku-4-5-20251001-off vs claude-haiku-5-5 | 1/2 = 50.0% | 12.1% | +37.9 | +30.0 to +42.5 |
| claude-haiku-4-5-20251001-off vs claude-sonnet-5-5 | 1/2 = 50.0% | 12.3% | +37.7 | +30.2 to +43.1 |
| claude-haiku-4-5-20251001-off vs gpt-5.6-terra | 0/2 = 0.0% | 16.9% | -16.9 | -25.5 to -9.1 |
| claude-haiku-4-5-20251001-off vs gpt-6-astra | 0/2 = 0.0% | 6.1% | -6.1 | -10.0 to -3.1 |
| claude-haiku-4-5-20251001-off vs gpt-6.1-sol | 0/2 = 0.0% | 9.5% | -9.5 | -16.0 to -5.2 |
| claude-haiku-5-5 vs claude-opus-5-5 | 7/20 = 35.0% | 42.2% | -7.2 | -22.5 to +7.0 |
| claude-haiku-5-5 vs claude-opus-5-5-high | 0/2 = 0.0% | 39.9% | -39.9 | -53.6 to -25.3 |
| claude-haiku-5-5 vs claude-opus-5-5-low | 1/2 = 50.0% | 55.9% | -5.9 | -19.5 to +8.5 |
| claude-haiku-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 50.3% | +9.7 | -8.5 to +28.4 |
| claude-haiku-5-5 vs claude-sonnet-5-5-high | 0/2 = 0.0% | 45.1% | -45.1 | -56.9 to -31.4 |
| claude-haiku-5-5 vs claude-sonnet-5-5-low | 2/2 = 100.0% | 59.4% | +40.6 | +27.7 to +53.4 |
| claude-haiku-5-5 vs claude-sonnet-5-5-max | 0/2 = 0.0% | 30.5% | -30.5 | -41.0 to -19.6 |
| claude-haiku-5-5 vs claude-sonnet-5-5-off | 1/2 = 50.0% | 51.0% | -1.0 | -13.1 to +11.4 |
| claude-haiku-5-5 vs claude-sonnet-5-5-xhigh | 1/2 = 50.0% | 39.9% | +10.1 | -1.9 to +22.2 |
| claude-haiku-5-5 vs gpt-5.6-terra | 13/20 = 65.0% | 59.5% | +5.5 | -8.3 to +20.7 |
| claude-haiku-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 61.8% | +38.2 | +26.3 to +49.1 |
| claude-haiku-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 64.0% | -14.0 | -24.6 to -1.6 |
| claude-haiku-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 51.1% | +48.9 | +34.8 to +61.1 |
| claude-haiku-5-5 vs gpt-6-astra | 6/20 = 30.0% | 31.9% | -1.9 | -17.0 to +13.3 |
| claude-haiku-5-5 vs gpt-6-astra-low | 1/2 = 50.0% | 41.6% | +8.4 | -0.6 to +16.9 |
| claude-haiku-5-5 vs gpt-6-luna | 19/20 = 95.0% | 82.5% | +12.5 | +0.7 to +21.2 |
| claude-haiku-5-5 vs gpt-6-luna-high | 1/2 = 50.0% | 66.0% | -16.0 | -27.0 to -0.5 |
| claude-haiku-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.7% | +11.3 | +6.1 to +18.3 |
| claude-haiku-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 58.4% | -8.4 | -20.1 to +6.0 |
| claude-haiku-5-5 vs gpt-6.1-sol | 10/20 = 50.0% | 43.1% | +6.9 | -8.0 to +21.7 |
| claude-haiku-5-5 vs gpt-6.1-sol-high | 1/2 = 50.0% | 42.7% | +7.3 | -3.7 to +18.2 |
| claude-haiku-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 32.5% | +17.5 | +5.6 to +27.0 |
| claude-haiku-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 40.2% | +9.8 | -2.1 to +21.1 |
| claude-haiku-5-5-high vs claude-opus-5-5 | 1/2 = 50.0% | 44.7% | +5.3 | -6.0 to +16.5 |
| claude-haiku-5-5-high vs claude-sonnet-5-5 | 0/2 = 0.0% | 52.9% | -52.9 | -62.9 to -39.8 |
| claude-haiku-5-5-high vs gpt-6-astra | 0/2 = 0.0% | 34.2% | -34.2 | -44.4 to -23.1 |
| claude-haiku-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 84.0% | -34.0 | -39.6 to -25.2 |
| claude-haiku-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 45.7% | -45.7 | -56.4 to -33.3 |
| claude-haiku-5-5-low vs claude-opus-5-5 | 2/2 = 100.0% | 42.0% | +58.0 | +44.9 to +68.0 |
| claude-haiku-5-5-low vs claude-sonnet-5-5 | 1/2 = 50.0% | 50.2% | -0.2 | -11.4 to +12.0 |
| claude-haiku-5-5-low vs gpt-5.6-terra | 1/2 = 50.0% | 59.4% | -9.4 | -20.2 to +3.2 |
| claude-haiku-5-5-low vs gpt-6.1-sol | 2/2 = 100.0% | 43.0% | +57.0 | +44.0 to +67.0 |
| claude-haiku-5-5-low vs gpt-6.1-terra-low | 1/2 = 50.0% | 29.6% | +20.4 | -2.3 to +35.3 |
| claude-haiku-5-5-max vs claude-opus-5-5 | 2/2 = 100.0% | 52.9% | +47.1 | +34.9 to +58.4 |
| claude-haiku-5-5-max vs claude-sonnet-5-5 | 1/2 = 50.0% | 60.9% | -10.9 | -21.5 to +1.5 |
| claude-haiku-5-5-max vs gpt-5.6-terra | 1/2 = 50.0% | 69.4% | -19.4 | -28.1 to -8.4 |
| claude-haiku-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 53.8% | -3.8 | -15.0 to +7.5 |
| claude-haiku-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 43.0% | +7.0 | -4.5 to +17.9 |
| claude-haiku-5-5-off vs gpt-6-astra | 0/2 = 0.0% | 19.3% | -19.3 | -27.1 to -12.3 |
| claude-haiku-5-5-off vs gpt-6-luna | 1/2 = 50.0% | 70.8% | -20.8 | -30.6 to -7.9 |
| claude-haiku-5-5-off vs gpt-6.1-sol | 0/2 = 0.0% | 28.0% | -28.0 | -38.0 to -18.5 |
| claude-haiku-5-5-xhigh vs claude-opus-5-5 | 0/2 = 0.0% | 54.4% | -54.4 | -65.5 to -40.5 |
| claude-haiku-5-5-xhigh vs claude-sonnet-5-5 | 1/2 = 50.0% | 62.4% | -12.4 | -22.6 to +0.8 |
| claude-haiku-5-5-xhigh vs gpt-6-astra | 0/2 = 0.0% | 43.4% | -43.4 | -55.3 to -31.0 |
| claude-haiku-5-5-xhigh vs gpt-6-luna | 2/2 = 100.0% | 88.5% | +11.5 | +6.6 to +17.1 |
| claude-opus-5-5 vs claude-sonnet-5-5 | 12/20 = 60.0% | 58.1% | +1.9 | -16.4 to +20.5 |
| claude-opus-5-5 vs claude-sonnet-5-5-low | 0/2 = 0.0% | 66.7% | -66.7 | -76.6 to -53.0 |
| claude-opus-5-5 vs claude-sonnet-5-5-max | 2/2 = 100.0% | 37.6% | +62.4 | +47.7 to +73.3 |
| claude-opus-5-5 vs claude-sonnet-5-5-xhigh | 2/2 = 100.0% | 47.6% | +52.4 | +38.9 to +64.6 |
| claude-opus-5-5 vs gpt-5.6-terra | 12/20 = 60.0% | 66.9% | -6.9 | -19.4 to +6.3 |
| claude-opus-5-5 vs gpt-5.6-terra-high | 2/2 = 100.0% | 68.9% | +31.1 | +20.2 to +41.5 |
| claude-opus-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 71.0% | -21.0 | -29.9 to -10.0 |
| claude-opus-5-5 vs gpt-5.6-terra-max | 2/2 = 100.0% | 58.9% | +41.1 | +28.3 to +53.5 |
| claude-opus-5-5 vs gpt-5.6-terra-xhigh | 2/2 = 100.0% | 59.1% | +40.9 | +27.8 to +52.7 |
| claude-opus-5-5 vs gpt-6-astra | 9/20 = 45.0% | 39.1% | +5.9 | -6.0 to +16.2 |
| claude-opus-5-5 vs gpt-6-astra-high | 1/2 = 50.0% | 51.5% | -1.5 | -5.4 to +2.5 |
| claude-opus-5-5 vs gpt-6-astra-low | 1/2 = 50.0% | 49.4% | +0.6 | -7.1 to +11.6 |
| claude-opus-5-5 vs gpt-6-luna | 16/20 = 80.0% | 86.6% | -6.6 | -28.7 to +11.5 |
| claude-opus-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 91.5% | +8.5 | +4.3 to +14.4 |
| claude-opus-5-5 vs gpt-6-luna-max | 1/2 = 50.0% | 65.8% | -15.8 | -27.0 to -1.5 |
| claude-opus-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 63.1% | -13.1 | -24.9 to +0.4 |
| claude-opus-5-5 vs gpt-6.1-sol | 12/20 = 60.0% | 51.0% | +9.0 | -7.9 to +26.7 |
| claude-opus-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 48.8% | +1.2 | -11.5 to +12.9 |
| claude-opus-5-5 vs gpt-6.1-sol-max | 1/2 = 50.0% | 39.7% | +10.3 | -2.8 to +20.8 |
| claude-opus-5-5 vs gpt-6.1-sol-xhigh | 1/2 = 50.0% | 48.0% | +2.0 | -10.9 to +14.5 |
| claude-opus-5-5 vs gpt-6.1-terra | 1/2 = 50.0% | 46.7% | +3.3 | -15.3 to +20.9 |
| claude-opus-5-5-high vs claude-sonnet-5-5 | 1/2 = 50.0% | 60.4% | -10.4 | -24.3 to +5.4 |
| claude-opus-5-5-high vs gpt-6-astra | 1/2 = 50.0% | 41.3% | +8.7 | -7.3 to +22.7 |
| claude-opus-5-5-high vs gpt-6-luna | 2/2 = 100.0% | 87.7% | +12.3 | +6.4 to +21.1 |
| claude-opus-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 53.3% | -53.3 | -66.6 to -36.1 |
| claude-opus-5-5-low vs claude-sonnet-5-5 | 1/2 = 50.0% | 44.5% | +5.5 | -9.3 to +20.3 |
| claude-opus-5-5-low vs gpt-5.6-terra | 0/2 = 0.0% | 53.7% | -53.7 | -63.9 to -35.5 |
| claude-opus-5-5-low vs gpt-6-luna | 2/2 = 100.0% | 78.9% | +21.1 | +12.0 to +33.4 |
| claude-opus-5-5-max vs claude-sonnet-5-5 | 2/2 = 100.0% | 86.3% | +13.7 | +3.0 to +29.2 |
| claude-opus-5-5-max vs gpt-6.1-sol | 1/2 = 50.0% | 82.5% | -32.5 | -40.2 to +1.4 |
| claude-opus-5-5-off vs claude-sonnet-5-5-off | 2/2 = 100.0% | 61.7% | +38.3 | +10.8 to +49.2 |
| claude-opus-5-5-off vs gpt-6-luna-xhigh | 1/2 = 50.0% | 65.9% | -15.9 | -33.2 to +4.2 |
| claude-opus-5-5-xhigh vs gpt-6-astra | 22/41 = 53.7% | 54.4% | -0.7 | -9.6 to +7.7 |
| claude-sonnet-5-5 vs gpt-5.6-terra | 11/20 = 55.0% | 59.2% | -4.2 | -29.8 to +18.3 |
| claude-sonnet-5-5 vs gpt-5.6-terra-high | 1/2 = 50.0% | 61.5% | -11.5 | -23.2 to +0.7 |
| claude-sonnet-5-5 vs gpt-5.6-terra-low | 1/2 = 50.0% | 63.8% | -13.8 | -24.6 to -1.8 |
| claude-sonnet-5-5 vs gpt-5.6-terra-xhigh | 0/2 = 0.0% | 51.0% | -51.0 | -62.8 to -36.0 |
| claude-sonnet-5-5 vs gpt-6-astra | 7/20 = 35.0% | 31.6% | +3.4 | -11.1 to +16.8 |
| claude-sonnet-5-5 vs gpt-6-luna | 17/20 = 85.0% | 82.3% | +2.7 | -13.3 to +16.0 |
| claude-sonnet-5-5 vs gpt-6-luna-low | 2/2 = 100.0% | 88.6% | +11.4 | +5.9 to +18.7 |
| claude-sonnet-5-5 vs gpt-6-luna-off | 2/2 = 100.0% | 88.2% | +11.8 | +6.3 to +18.5 |
| claude-sonnet-5-5 vs gpt-6-luna-xhigh | 1/2 = 50.0% | 55.2% | -5.2 | -17.4 to +8.4 |
| claude-sonnet-5-5 vs gpt-6.1-sol | 8/20 = 40.0% | 42.8% | -2.8 | -22.1 to +14.9 |
| claude-sonnet-5-5 vs gpt-6.1-sol-high | 1/2 = 50.0% | 42.4% | +7.6 | -4.3 to +18.8 |
| claude-sonnet-5-5 vs gpt-6.1-sol-low | 1/2 = 50.0% | 40.7% | +9.3 | -2.9 to +20.9 |
| claude-sonnet-5-5 vs gpt-6.1-sol-max | 0/2 = 0.0% | 32.2% | -32.2 | -42.6 to -21.5 |
| claude-sonnet-5-5-high vs gpt-5.6-terra | 1/2 = 50.0% | 64.1% | -14.1 | -26.1 to -0.7 |
| claude-sonnet-5-5-high vs gpt-6-luna | 1/2 = 50.0% | 85.2% | -35.2 | -41.1 to -25.7 |
| claude-sonnet-5-5-high vs gpt-6.1-sol | 0/2 = 0.0% | 48.0% | -48.0 | -60.7 to -34.3 |
| claude-sonnet-5-5-high vs gpt-6.1-terra-high | 2/2 = 100.0% | 74.3% | +25.7 | +2.7 to +44.7 |
| claude-sonnet-5-5-low vs gpt-6-astra | 0/2 = 0.0% | 24.2% | -24.2 | -35.0 to -14.7 |
| claude-sonnet-5-5-low vs gpt-6-luna | 1/2 = 50.0% | 76.4% | -26.4 | -35.4 to -13.8 |
| claude-sonnet-5-5-low vs gpt-6.1-terra-off | 0/2 = 0.0% | 34.0% | -34.0 | -49.7 to -6.3 |
| claude-sonnet-5-5-max vs gpt-6-luna | 2/2 = 100.0% | 91.5% | +8.5 | +4.5 to +13.9 |
| claude-sonnet-5-5-max vs gpt-6.1-sol | 2/2 = 100.0% | 63.3% | +36.7 | +23.7 to +48.0 |
| claude-sonnet-5-5-off vs gpt-5.6-terra | 1/2 = 50.0% | 58.6% | -8.6 | -20.8 to +4.1 |
| claude-sonnet-5-5-off vs gpt-6-astra | 2/2 = 100.0% | 31.1% | +68.9 | +55.9 to +77.4 |
| claude-sonnet-5-5-off vs gpt-6.1-sol | 1/2 = 50.0% | 42.2% | +7.8 | -5.5 to +19.1 |
| claude-sonnet-5-5-xhigh vs gpt-5.6-terra | 2/2 = 100.0% | 68.9% | +31.1 | +19.9 to +42.1 |
| claude-sonnet-5-5-xhigh vs gpt-6-astra | 1/2 = 50.0% | 41.4% | +8.6 | -5.4 to +19.5 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 53.3% | -3.3 | -17.3 to +8.4 |
| claude-sonnet-5-5-xhigh vs gpt-6.1-terra-xhigh | 1/2 = 50.0% | 66.0% | -16.0 | -34.6 to +14.3 |
| gpt-5.6-terra vs gpt-6-astra | 5/20 = 25.0% | 24.1% | +0.9 | -14.5 to +16.4 |
| gpt-5.6-terra vs gpt-6-luna | 15/20 = 75.0% | 76.3% | -1.3 | -23.0 to +16.7 |
| gpt-5.6-terra vs gpt-6-luna-high | 2/2 = 100.0% | 56.9% | +43.1 | +28.4 to +56.9 |
| gpt-5.6-terra vs gpt-6-luna-low | 1/2 = 50.0% | 84.2% | -34.2 | -41.2 to -23.8 |
| gpt-5.6-terra vs gpt-6-luna-max | 2/2 = 100.0% | 48.8% | +51.2 | +36.0 to +63.2 |
| gpt-5.6-terra vs gpt-6-luna-off | 2/2 = 100.0% | 83.8% | +16.2 | +9.0 to +25.6 |
| gpt-5.6-terra vs gpt-6.1-sol | 6/20 = 30.0% | 34.0% | -4.0 | -19.0 to +10.5 |
| gpt-5.6-terra vs gpt-6.1-sol-high | 0/2 = 0.0% | 33.7% | -33.7 | -43.5 to -23.4 |
| gpt-5.6-terra vs gpt-6.1-sol-low | 0/2 = 0.0% | 32.1% | -32.1 | -43.3 to -21.6 |
| gpt-5.6-terra vs gpt-6.1-sol-max | 0/2 = 0.0% | 24.6% | -24.6 | -34.3 to -16.2 |
| gpt-5.6-terra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 31.4% | -31.4 | -42.4 to -20.8 |
| gpt-5.6-terra-high vs gpt-6-luna | 1/2 = 50.0% | 74.5% | -24.5 | -33.5 to -12.1 |
| gpt-5.6-terra-high vs gpt-6.1-sol | 1/2 = 50.0% | 31.9% | +18.1 | +5.7 to +27.6 |
| gpt-5.6-terra-low vs gpt-6-astra | 0/2 = 0.0% | 20.8% | -20.8 | -29.6 to -12.6 |
| gpt-5.6-terra-max vs gpt-6-astra | 1/2 = 50.0% | 30.9% | +19.1 | +5.8 to +29.1 |
| gpt-5.6-terra-max vs gpt-6-luna | 2/2 = 100.0% | 81.9% | +18.1 | +10.2 to +27.4 |
| gpt-5.6-terra-xhigh vs gpt-6-astra | 0/2 = 0.0% | 30.8% | -30.8 | -42.0 to -19.4 |
| gpt-5.6-terra-xhigh vs gpt-6.1-sol | 0/2 = 0.0% | 41.8% | -41.8 | -54.2 to -28.9 |
| gpt-6-astra vs gpt-6-luna | 19/20 = 95.0% | 91.0% | +4.0 | -7.0 to +11.1 |
| gpt-6-astra vs gpt-6-luna-high | 1/2 = 50.0% | 80.6% | -30.6 | -38.3 to -19.1 |
| gpt-6-astra vs gpt-6-luna-max | 2/2 = 100.0% | 75.0% | +25.0 | +15.8 to +35.7 |
| gpt-6-astra vs gpt-6-luna-off | 2/2 = 100.0% | 94.2% | +5.8 | +3.0 to +9.3 |
| gpt-6-astra vs gpt-6-luna-xhigh | 1/2 = 50.0% | 72.7% | -22.7 | -32.0 to -10.5 |
| gpt-6-astra vs gpt-6.1-sol | 12/20 = 60.0% | 61.8% | -1.8 | -19.3 to +15.8 |
| gpt-6-astra vs gpt-6.1-sol-low | 2/2 = 100.0% | 59.7% | +40.3 | +27.6 to +51.5 |
| gpt-6-astra vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 59.0% | -59.0 | -70.0 to -44.3 |
| gpt-6-astra-high vs gpt-6.1-sol | 1/2 = 50.0% | 49.5% | +0.5 | -4.3 to +3.9 |
| gpt-6-astra-low vs gpt-6-luna | 2/2 = 100.0% | 86.9% | +13.1 | +5.6 to +16.6 |
| gpt-6-astra-low vs gpt-6.1-sol | 1/2 = 50.0% | 51.6% | -1.6 | -11.4 to +6.1 |
| gpt-6-luna vs gpt-6.1-sol | 3/20 = 15.0% | 13.8% | +1.2 | -12.8 to +15.9 |
| gpt-6-luna vs gpt-6.1-sol-high | 1/2 = 50.0% | 13.6% | +36.4 | +28.9 to +41.6 |
| gpt-6-luna vs gpt-6.1-sol-low | 0/2 = 0.0% | 12.8% | -12.8 | -19.7 to -7.3 |
| gpt-6-luna vs gpt-6.1-sol-max | 0/2 = 0.0% | 9.2% | -9.2 | -15.2 to -5.3 |
| gpt-6-luna vs gpt-6.1-sol-xhigh | 0/2 = 0.0% | 12.5% | -12.5 | -19.2 to -7.2 |
| gpt-6-luna-high vs gpt-6.1-sol | 1/2 = 50.0% | 28.1% | +21.9 | +7.4 to +32.2 |
| gpt-6-luna-low vs gpt-6.1-sol | 0/2 = 0.0% | 8.8% | -8.8 | -15.0 to -4.4 |
| gpt-6-luna-max vs gpt-6.1-sol | 0/2 = 0.0% | 35.1% | -35.1 | -47.5 to -22.4 |
| gpt-6-luna-off vs gpt-6.1-sol | 1/2 = 50.0% | 9.1% | +40.9 | +34.5 to +44.5 |
| gpt-6-luna-xhigh vs gpt-6.1-sol | 1/2 = 50.0% | 37.8% | +12.2 | -1.6 to +23.6 |
| gpt-6.1-sol vs gpt-6.1-terra | 1/2 = 50.0% | 45.8% | +4.2 | -15.4 to +22.6 |
| gpt-6.1-sol-max vs gpt-6.1-terra-max | 1/2 = 50.0% | 38.4% | +11.6 | -5.0 to +26.3 |
| gpt-6.1-sol-xhigh vs gpt-6.1-terra-high | 1/2 = 50.0% | 77.9% | -27.9 | -41.1 to +1.9 |
#### Haiku 4.5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-high | 9/20 = 45.0% | 56.1% | -11.1 | -27.5 to +4.3 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-low | 12/20 = 60.0% | 54.3% | +5.7 | -10.0 to +22.9 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-minimal | 10/20 = 50.0% | 49.2% | +0.8 | -17.4 to +18.9 |
| claude-haiku-4-5-20251001 vs claude-haiku-4-5-20251001-off | 16/20 = 80.0% | 72.0% | +8.0 | -6.9 to +23.9 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-low | 8/20 = 40.0% | 48.2% | -8.2 | -24.9 to +7.9 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-minimal | 11/20 = 55.0% | 43.2% | +11.8 | -5.5 to +31.0 |
| claude-haiku-4-5-20251001-high vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 66.8% | -1.8 | -18.5 to +14.7 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-minimal | 6/20 = 30.0% | 44.9% | -14.9 | -34.3 to +3.0 |
| claude-haiku-4-5-20251001-low vs claude-haiku-4-5-20251001-off | 15/20 = 75.0% | 68.3% | +6.7 | -8.0 to +22.2 |
| claude-haiku-4-5-20251001-minimal vs claude-haiku-4-5-20251001-off | 13/20 = 65.0% | 72.6% | -7.6 | -28.4 to +11.7 |
#### Haiku 5.5 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-haiku-5-5 vs claude-haiku-5-5-high | 7/20 = 35.0% | 47.4% | -12.4 | -27.6 to +1.0 |
| claude-haiku-5-5 vs claude-haiku-5-5-low | 8/20 = 40.0% | 50.1% | -10.1 | -28.5 to +8.1 |
| claude-haiku-5-5 vs claude-haiku-5-5-max | 9/20 = 45.0% | 39.4% | +5.6 | -9.5 to +22.7 |
| claude-haiku-5-5 vs claude-haiku-5-5-off | 14/20 = 70.0% | 66.1% | +3.9 | -10.4 to +19.0 |
| claude-haiku-5-5 vs claude-haiku-5-5-xhigh | 7/20 = 35.0% | 37.9% | -2.9 | -20.8 to +16.2 |
| claude-haiku-5-5-high vs claude-haiku-5-5-low | 13/20 = 65.0% | 52.8% | +12.2 | -5.5 to +31.7 |
| claude-haiku-5-5-high vs claude-haiku-5-5-max | 9/20 = 45.0% | 41.9% | +3.1 | -15.9 to +21.7 |
| claude-haiku-5-5-high vs claude-haiku-5-5-off | 13/20 = 65.0% | 68.4% | -3.4 | -17.2 to +10.7 |
| claude-haiku-5-5-high vs claude-haiku-5-5-xhigh | 6/20 = 30.0% | 40.4% | -10.4 | -26.2 to +3.5 |
| claude-haiku-5-5-low vs claude-haiku-5-5-max | 7/20 = 35.0% | 39.3% | -4.3 | -21.6 to +14.9 |
| claude-haiku-5-5-low vs claude-haiku-5-5-off | 11/20 = 55.0% | 66.0% | -11.0 | -31.6 to +8.0 |
| claude-haiku-5-5-low vs claude-haiku-5-5-xhigh | 8/20 = 40.0% | 37.8% | +2.2 | -12.0 to +14.9 |
| claude-haiku-5-5-max vs claude-haiku-5-5-off | 16/20 = 80.0% | 75.0% | +5.0 | -8.9 to +19.1 |
| claude-haiku-5-5-max vs claude-haiku-5-5-xhigh | 9/20 = 45.0% | 48.4% | -3.4 | -19.8 to +12.8 |
| claude-haiku-5-5-off vs claude-haiku-5-5-xhigh | 5/20 = 25.0% | 23.8% | +1.2 | -16.7 to +21.4 |
#### Luna efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6-luna vs gpt-6-luna-high | 8/20 = 40.0% | 29.1% | +10.9 | -9.6 to +32.8 |
| gpt-6-luna vs gpt-6-luna-low | 12/20 = 60.0% | 62.4% | -2.4 | -26.1 to +18.9 |
| gpt-6-luna vs gpt-6-luna-max | 5/20 = 25.0% | 22.9% | +2.1 | -13.3 to +17.4 |
| gpt-6-luna vs gpt-6-luna-off | 12/20 = 60.0% | 61.7% | -1.7 | -21.6 to +18.2 |
| gpt-6-luna vs gpt-6-luna-xhigh | 2/20 = 10.0% | 20.9% | -10.9 | -23.8 to +3.1 |
| gpt-6-luna-high vs gpt-6-luna-low | 14/20 = 70.0% | 80.2% | -10.2 | -25.1 to +4.9 |
| gpt-6-luna-high vs gpt-6-luna-max | 7/20 = 35.0% | 42.0% | -7.0 | -26.1 to +13.5 |
| gpt-6-luna-high vs gpt-6-luna-off | 18/20 = 90.0% | 79.7% | +10.3 | -2.4 to +23.5 |
| gpt-6-luna-high vs gpt-6-luna-xhigh | 11/20 = 55.0% | 39.2% | +15.8 | -1.8 to +36.2 |
| gpt-6-luna-low vs gpt-6-luna-max | 2/20 = 10.0% | 15.2% | -5.2 | -17.7 to +7.9 |
| gpt-6-luna-low vs gpt-6-luna-off | 8/20 = 40.0% | 49.2% | -9.2 | -26.7 to +7.4 |
| gpt-6-luna-low vs gpt-6-luna-xhigh | 3/20 = 15.0% | 13.7% | +1.3 | -13.7 to +21.5 |
| gpt-6-luna-max vs gpt-6-luna-off | 16/20 = 80.0% | 84.4% | -4.4 | -19.2 to +9.8 |
| gpt-6-luna-max vs gpt-6-luna-xhigh | 10/20 = 50.0% | 47.1% | +2.9 | -11.8 to +17.7 |
| gpt-6-luna-off vs gpt-6-luna-xhigh | 2/20 = 10.0% | 14.1% | -4.1 | -15.9 to +9.5 |
#### Opus efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-opus-5-5 vs claude-opus-5-5-high | 9/20 = 45.0% | 47.7% | -2.7 | -19.8 to +13.9 |
| claude-opus-5-5 vs claude-opus-5-5-low | 13/20 = 65.0% | 63.5% | +1.5 | -9.5 to +11.7 |
| claude-opus-5-5 vs claude-opus-5-5-max | 0/2 = 0.0% | 18.1% | -18.1 | -34.8 to -4.1 |
| claude-opus-5-5 vs claude-opus-5-5-off | 1/2 = 50.0% | 46.9% | +3.1 | -14.5 to +24.6 |
| claude-opus-5-5 vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 35.0% | +0.0 | -14.3 to +14.0 |
| claude-opus-5-5-high vs claude-opus-5-5-xhigh | 7/20 = 35.0% | 37.1% | -2.1 | -17.8 to +13.4 |
| claude-opus-5-5-low vs claude-opus-5-5-max | 0/2 = 0.0% | 11.3% | -11.3 | -26.3 to -2.3 |
| claude-opus-5-5-low vs claude-opus-5-5-off | 1/2 = 50.0% | 33.7% | +16.3 | -4.2 to +32.1 |
#### Sol efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-sol vs gpt-6.1-sol-high | 12/20 = 60.0% | 49.6% | +10.4 | -1.9 to +25.5 |
| gpt-6.1-sol vs gpt-6.1-sol-low | 7/20 = 35.0% | 47.8% | -12.8 | -31.8 to +5.3 |
| gpt-6.1-sol vs gpt-6.1-sol-max | 8/20 = 40.0% | 38.8% | +1.2 | -15.7 to +18.3 |
| gpt-6.1-sol vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 47.0% | +3.0 | -17.4 to +24.0 |
| gpt-6.1-sol-high vs gpt-6.1-sol-low | 12/20 = 60.0% | 48.2% | +11.8 | -3.2 to +29.5 |
| gpt-6.1-sol-high vs gpt-6.1-sol-max | 9/20 = 45.0% | 39.2% | +5.8 | -12.3 to +25.4 |
| gpt-6.1-sol-high vs gpt-6.1-sol-xhigh | 9/20 = 45.0% | 47.4% | -2.4 | -17.5 to +12.6 |
| gpt-6.1-sol-low vs gpt-6.1-sol-max | 6/20 = 30.0% | 40.9% | -10.9 | -29.4 to +6.2 |
| gpt-6.1-sol-low vs gpt-6.1-sol-xhigh | 12/20 = 60.0% | 49.2% | +10.8 | -5.6 to +29.4 |
| gpt-6.1-sol-max vs gpt-6.1-sol-xhigh | 10/20 = 50.0% | 58.4% | -8.4 | -22.7 to +5.9 |
#### Sonnet efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| claude-sonnet-5-5 vs claude-sonnet-5-5-high | 7/20 = 35.0% | 44.8% | -9.8 | -29.7 to +10.6 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-low | 11/20 = 55.0% | 59.1% | -4.1 | -23.2 to +16.1 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-max | 8/20 = 40.0% | 30.3% | +9.7 | -7.9 to +29.3 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-off | 10/20 = 50.0% | 50.6% | -0.6 | -17.8 to +18.7 |
| claude-sonnet-5-5 vs claude-sonnet-5-5-xhigh | 9/20 = 45.0% | 39.6% | +5.4 | -13.7 to +24.8 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-low | 11/20 = 55.0% | 64.0% | -9.0 | -31.0 to +13.3 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-max | 8/20 = 40.0% | 34.8% | +5.2 | -13.9 to +26.8 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-off | 14/20 = 70.0% | 55.8% | +14.2 | -1.3 to +31.5 |
| claude-sonnet-5-5-high vs claude-sonnet-5-5-xhigh | 5/20 = 25.0% | 44.6% | -19.6 | -37.9 to -1.4 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-max | 3/20 = 15.0% | 23.1% | -8.1 | -22.1 to +5.9 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-off | 10/20 = 50.0% | 41.5% | +8.5 | -10.8 to +26.1 |
| claude-sonnet-5-5-low vs claude-sonnet-5-5-xhigh | 4/20 = 20.0% | 31.2% | -11.2 | -26.4 to +3.5 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-off | 14/20 = 70.0% | 70.3% | -0.3 | -23.4 to +20.8 |
| claude-sonnet-5-5-max vs claude-sonnet-5-5-xhigh | 13/20 = 65.0% | 60.1% | +4.9 | -13.1 to +24.0 |
| claude-sonnet-5-5-off vs claude-sonnet-5-5-xhigh | 11/20 = 55.0% | 39.0% | +16.0 | +4.3 to +28.9 |
#### Terra 6.1 efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-6.1-terra vs gpt-6.1-terra-high | 1/2 = 50.0% | 78.8% | -28.8 | -41.3 to +0.4 |
| gpt-6.1-terra vs gpt-6.1-terra-low | 1/2 = 50.0% | 39.8% | +10.2 | -12.3 to +27.7 |
| gpt-6.1-terra vs gpt-6.1-terra-off | 1/2 = 50.0% | 54.1% | -4.1 | -27.9 to +23.1 |
| gpt-6.1-terra vs gpt-6.1-terra-xhigh | 2/2 = 100.0% | 66.8% | +33.2 | +4.2 to +48.2 |
| gpt-6.1-terra-high vs gpt-6.1-terra-xhigh | 0/2 = 0.0% | 35.2% | -35.2 | -53.7 to -4.9 |
| gpt-6.1-terra-low vs gpt-6.1-terra-off | 2/2 = 100.0% | 64.1% | +35.9 | +4.6 to +48.5 |
| gpt-6.1-terra-max vs gpt-6.1-terra-xhigh | 2/2 = 100.0% | 81.1% | +18.9 | +3.1 to +29.3 |
#### Terra efforts

| pair | wins/matches = observed share | fitted share | difference (pp) | bootstrap range of the difference (descriptive) |
|---|---|---|---|---|
| gpt-5.6-terra vs gpt-5.6-terra-high | 10/20 = 50.0% | 52.4% | -2.4 | -17.0 to +11.9 |
| gpt-5.6-terra vs gpt-5.6-terra-low | 11/20 = 55.0% | 54.8% | +0.2 | -16.0 to +16.1 |
| gpt-5.6-terra vs gpt-5.6-terra-max | 8/20 = 40.0% | 41.5% | -1.5 | -21.1 to +19.2 |
| gpt-5.6-terra vs gpt-5.6-terra-xhigh | 7/20 = 35.0% | 41.7% | -6.7 | -23.0 to +7.7 |
| gpt-5.6-terra-high vs gpt-5.6-terra-low | 9/20 = 45.0% | 52.4% | -7.4 | -27.1 to +10.4 |
| gpt-5.6-terra-high vs gpt-5.6-terra-max | 8/20 = 40.0% | 39.3% | +0.7 | -17.3 to +16.4 |
| gpt-5.6-terra-high vs gpt-5.6-terra-xhigh | 10/20 = 50.0% | 39.5% | +10.5 | -8.1 to +30.6 |
| gpt-5.6-terra-low vs gpt-5.6-terra-max | 8/20 = 40.0% | 37.0% | +3.0 | -15.9 to +22.3 |
| gpt-5.6-terra-low vs gpt-5.6-terra-xhigh | 4/20 = 20.0% | 37.2% | -17.2 | -32.7 to -2.6 |
| gpt-5.6-terra-max vs gpt-5.6-terra-xhigh | 11/20 = 55.0% | 50.2% | +4.8 | -11.2 to +21.3 |

### Pair effects against ratings alone

| cohort | ratings-only loss | nested pair-effect loss | gain per match | 95% CI of gain | tau chosen (folds) | fixed-tau loss (picked with the held-out blocks in view) | verdict |
|---|---|---|---|---|---|---|---|
| Cross-model | 0.6224 | 0.6231 | -0.0007 | -0.0011 to -0.0004 | 0: 48, 0.4: 2 | tau=0.1: 0.6227, tau=0.2: 0.6235, tau=0.4: 0.6264, tau=0.8: 0.6329, tau=1.6: 0.6408 | not kept |
| Cross-model (seat and starter terms) | 0.6053 | 0.6054 | -0.0000 | -0.0001 to +0.0000 | 0: 49, 0.2: 1 | tau=0.1: 0.6056, tau=0.2: 0.6065, tau=0.4: 0.6094, tau=0.8: 0.6159, tau=1.6: 0.6234 | not kept |
| Haiku 4.5 efforts | 0.6750 | 0.6792 | -0.0043 | -0.0108 to +0.0008 | 0: 23, 0.1: 2, 0.2: 16, 0.4: 8, 0.8: 1 | tau=0.1: 0.6747, tau=0.2: 0.6745, tau=0.4: 0.6754, tau=0.8: 0.6800, tau=1.6: 0.6848 | not kept |
| Haiku 4.5 efforts (seat and starter terms) | 0.6768 | 0.6859 | -0.0090 | -0.0171 to -0.0020 | 0: 18, 0.1: 2, 0.2: 13, 0.4: 13, 0.8: 4 | tau=0.1: 0.6770, tau=0.2: 0.6776, tau=0.4: 0.6810, tau=0.8: 0.6900, tau=1.6: 0.6982 | not kept |
| Haiku 5.5 efforts | 0.6649 | 0.6657 | -0.0008 | -0.0014 to -0.0002 | 0: 46, 0.1: 1, 0.2: 1, 0.4: 2 | tau=0.1: 0.6654, tau=0.2: 0.6667, tau=0.4: 0.6713, tau=0.8: 0.6802, tau=1.6: 0.6875 | not kept |
| Haiku 5.5 efforts (seat and starter terms) | 0.6407 | 0.6408 | -0.0001 | -0.0003 to +0.0000 | 0: 47, 0.1: 2, 0.2: 1 | tau=0.1: 0.6411, tau=0.2: 0.6423, tau=0.4: 0.6467, tau=0.8: 0.6560, tau=1.6: 0.6642 | not kept |
| Luna efforts | 0.5765 | 0.5778 | -0.0013 | -0.0031 to +0.0005 | 0: 33, 0.1: 6, 0.2: 7, 0.4: 4 | tau=0.1: 0.5764, tau=0.2: 0.5765, tau=0.4: 0.5781, tau=0.8: 0.5851, tau=1.6: 0.5952 | not kept |
| Luna efforts (seat and starter terms) | 0.5795 | 0.5841 | -0.0046 | -0.0086 to -0.0012 | 0: 30, 0.1: 2, 0.2: 12, 0.4: 5, 0.8: 1 | tau=0.1: 0.5797, tau=0.2: 0.5803, tau=0.4: 0.5838, tau=0.8: 0.5939, tau=1.6: 0.6068 | not kept |
| Opus efforts | 0.6573 | 0.6587 | -0.0014 | -0.0026 to -0.0004 | 0: 46, 0.2: 1, 0.4: 1, 1.6: 2 | tau=0.1: 0.6578, tau=0.2: 0.6590, tau=0.4: 0.6624, tau=0.8: 0.6671, tau=1.6: 0.6701 | not kept |
| Opus efforts (seat and starter terms) | 0.7035 | 0.7049 | -0.0014 | -0.0031 to +0.0001 | 0: 45, 0.2: 1, 0.4: 2, 1.6: 2 | tau=0.1: 0.7037, tau=0.2: 0.7043, tau=0.4: 0.7060, tau=0.8: 0.7083, tau=1.6: 0.7098 | not kept |
| Sol efforts | 0.7038 | 0.7065 | -0.0027 | -0.0090 to +0.0032 | 0: 15, 0.1: 4, 0.2: 10, 0.4: 18, 0.8: 3 | tau=0.1: 0.7035, tau=0.2: 0.7029, tau=0.4: 0.7032, tau=0.8: 0.7076, tau=1.6: 0.7124 | not kept |
| Sol efforts (seat and starter terms) | 0.7144 | 0.7183 | -0.0039 | -0.0103 to +0.0019 | 0: 18, 0.1: 3, 0.2: 14, 0.4: 13, 0.8: 2 | tau=0.1: 0.7142, tau=0.2: 0.7140, tau=0.4: 0.7154, tau=0.8: 0.7216, tau=1.6: 0.7277 | not kept |
| Sonnet efforts | 0.6743 | 0.6776 | -0.0032 | -0.0108 to +0.0030 | 0: 6, 0.1: 5, 0.2: 21, 0.4: 17, 0.8: 1 | tau=0.1: 0.6741, tau=0.2: 0.6738, tau=0.4: 0.6753, tau=0.8: 0.6833, tau=1.6: 0.6932 | not kept |
| Sonnet efforts (seat and starter terms) | 0.6716 | 0.6749 | -0.0034 | -0.0091 to +0.0019 | 0: 14, 0.1: 5, 0.2: 14, 0.4: 15, 0.8: 2 | tau=0.1: 0.6711, tau=0.2: 0.6703, tau=0.4: 0.6708, tau=0.8: 0.6771, tau=1.6: 0.6848 | not kept |
| Terra 6.1 efforts | - | - | - | - | - | - | 7 seed blocks: too few for 10-fold cross-validation |
| Terra efforts | 0.6892 | 0.6920 | -0.0027 | -0.0054 to -0.0003 | 0: 37, 0.1: 3, 0.2: 5, 0.4: 3, 0.8: 2 | tau=0.1: 0.6895, tau=0.2: 0.6904, tau=0.4: 0.6936, tau=0.8: 0.7003, tau=1.6: 0.7058 | not kept |
| Terra efforts (seat and starter terms) | 0.7010 | 0.7027 | -0.0017 | -0.0031 to -0.0003 | 0: 37, 0.1: 3, 0.2: 8, 0.4: 2 | tau=0.1: 0.7011, tau=0.2: 0.7016, tau=0.4: 0.7039, tau=0.8: 0.7093, tau=1.6: 0.7139 | not kept |

Loss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.

Reverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.

| cohort | pairs with opposite signs | correlation of A-first effect with minus B-first effect |
|---|---|---|
| Cross-model | 95/194 = 49.0% | -0.26 |
| Haiku 4.5 efforts | 7/10 = 70.0% | +0.05 |
| Haiku 5.5 efforts | 5/15 = 33.3% | -0.44 |
| Luna efforts | 7/15 = 46.7% | -0.09 |
| Opus efforts | 2/8 = 25.0% | -0.94 |
| Sol efforts | 6/10 = 60.0% | -0.18 |
| Sonnet efforts | 6/15 = 40.0% | -0.04 |
| Terra efforts | 4/10 = 40.0% | -0.15 |
| all cohorts pooled | 132/277 = 47.7% | -0.27 |

Pair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is 5.6e-17, because each match's shares sum to 1.

Cohorts that keep pair effects: none.

### Seat and round 1 starter

The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in 2533 of 2533 scored matches.

#### Overall and per cohort

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| all cohorts: 1266 blocks, 53 seeds (1 matches in half blocks left out) | 1276/2532 = 50.4% | 43.6% to 57.7% | 48.4% to 52.4% |
| Cross-model: 465 blocks, 46 seeds (1 matches in half blocks left out) | 448/930 = 48.2% | 40.2% to 57.7% | 45.1% to 51.3% |
| Haiku 4.5 efforts: 100 blocks, 10 seeds | 105/200 = 52.5% | 42.5% to 60.0% | 45.5% to 60.0% |
| Haiku 5.5 efforts: 150 blocks, 10 seeds | 142/300 = 47.3% | 35.3% to 59.0% | 41.0% to 53.0% |
| Luna efforts: 150 blocks, 10 seeds | 160/300 = 53.3% | 47.0% to 59.0% | 48.7% to 58.3% |
| Opus efforts: 44 blocks, 13 seeds | 44/88 = 50.0% | 32.0% to 67.1% | 38.6% to 61.4% |
| Sol efforts: 100 blocks, 10 seeds | 111/200 = 55.5% | 43.0% to 68.5% | 48.0% to 63.0% |
| Sonnet efforts: 150 blocks, 10 seeds | 162/300 = 54.0% | 42.7% to 64.7% | 48.7% to 59.3% |
| Terra 6.1 efforts: 7 blocks, 7 seeds | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% |
| Terra efforts: 100 blocks, 10 seeds | 96/200 = 48.0% | 36.5% to 58.5% | 40.5% to 56.0% |

Round 1 starter:

| group | starter wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn | blocks where position 1 starts |
|---|---|---|---|---|
| all cohorts | 1440/2532 = 56.9% | 50.5% to 63.4% | 55.0% to 58.7% | 601/1266 |
| Cross-model | 550/930 = 59.1% | 52.1% to 66.0% | 56.1% to 62.5% | 199/465 |
| Haiku 4.5 efforts | 115/200 = 57.5% | 50.5% to 65.5% | 50.5% to 64.0% | 50/100 |
| Haiku 5.5 efforts | 186/300 = 62.0% | 51.7% to 72.3% | 56.3% to 67.7% | 75/150 |
| Luna efforts | 152/300 = 50.7% | 44.3% to 56.7% | 45.7% to 55.7% | 75/150 |
| Opus efforts | 50/88 = 56.8% | 40.2% to 73.5% | 45.5% to 68.2% | 23/44 |
| Sol efforts | 107/200 = 53.5% | 40.5% to 66.5% | 46.0% to 61.0% | 50/100 |
| Sonnet efforts | 164/300 = 54.7% | 43.3% to 65.0% | 49.3% to 60.0% | 75/150 |
| Terra 6.1 efforts | 8/14 = 57.1% | 35.7% to 78.6% | 35.7% to 78.6% | 4/7 |
| Terra efforts | 108/200 = 54.0% | 43.0% to 64.0% | 47.0% to 61.0% | 50/100 |

Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.

| group | position effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn | starter effect | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|---|---|---|
| all cohorts | +0.7 | -5.9 to +7.0 | -1.2 to +2.7 | +6.9 | +0.4 to +13.5 | +5.1 to +8.8 |
| Cross-model | -0.5 | -7.7 to +7.5 | -3.5 to +2.6 | +9.1 | +1.7 to +16.5 | +6.0 to +12.3 |
| Haiku 4.5 efforts | +2.5 | -6.7 to +9.2 | -4.4 to +9.6 | +7.5 | +0.2 to +16.5 | +0.6 to +14.4 |
| Haiku 5.5 efforts | -2.7 | -14.0 to +7.5 | -8.9 to +2.9 | +12.0 | +0.7 to +22.8 | +6.3 to +17.7 |
| Luna efforts | +3.3 | -3.3 to +9.6 | -1.4 to +8.1 | +0.7 | -5.7 to +7.2 | -4.2 to +5.5 |
| Opus efforts | -0.3 | -18.4 to +16.4 | -11.6 to +11.0 | +6.8 | -10.4 to +24.3 | -4.4 to +18.1 |
| Sol efforts | +5.5 | -7.8 to +18.8 | -2.0 to +12.8 | +3.5 | -10.0 to +16.9 | -3.9 to +10.6 |
| Sonnet efforts | +4.0 | -7.9 to +14.6 | -1.3 to +9.3 | +4.7 | -7.3 to +15.0 | -0.7 to +10.1 |
| Terra 6.1 efforts | +6.2 | -20.8 to +33.3 | -20.8 to +35.0 | +6.2 | -20.8 to +35.0 | -20.8 to +35.0 |
| Terra efforts | -2.0 | -14.4 to +8.6 | -9.4 to +5.8 | +4.0 | -7.9 to +14.8 | -3.2 to +11.0 |

#### Per model

A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).

Position 1:

| group | position 1 wins/matches = share | 95% CI, seeds drawn | 95% CI, seed blocks drawn |
|---|---|---|---|
| claude-haiku-4-5-20251001: 208 blocks, 19 seeds | 206/416 = 49.5% | 42.8% to 55.9% | 45.0% to 54.1% |
| claude-haiku-5-5: 267 blocks, 22 seeds | 252/534 = 47.2% | 37.8% to 57.7% | 42.7% to 51.5% |
| claude-opus-5-5: 170 blocks, 39 seeds | 168/340 = 49.4% | 39.7% to 60.1% | 43.8% to 55.3% |
| claude-sonnet-5-5: 268 blocks, 24 seeds | 273/536 = 50.9% | 42.5% to 59.1% | 46.8% to 54.9% |
| gpt-5.6-terra: 208 blocks, 19 seeds | 217/416 = 52.2% | 43.2% to 61.1% | 47.4% to 57.0% |
| gpt-6-astra: 115 blocks, 35 seeds | 110/230 = 47.8% | 38.3% to 59.3% | 41.3% to 54.3% |
| gpt-6-luna: 264 blocks, 22 seeds | 264/528 = 50.0% | 44.9% to 55.4% | 46.6% to 53.6% |
| gpt-6.1-sol: 216 blocks, 26 seeds | 216/432 = 50.0% | 40.5% to 60.1% | 45.1% to 55.1% |
| gpt-6.1-terra: 15 blocks, 9 seeds | 18/30 = 60.0% | 41.7% to 78.1% | 40.0% to 76.7% |

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
| 4000 | 1 | 2 | 2/4 = 50.0% |
| 4006 | 1 | 1 | 0/2 = 0.0% |
| 4008 | 2 | 1 | 1/2 = 50.0% |
| 4011 | 1 | 1 | 0/2 = 0.0% |
| 4013 | 2 | 1 | 2/2 = 100.0% |
| 4016 | 1 | 1 | 0/2 = 0.0% |
| 4017 | 1 | 1 | 1/2 = 50.0% |
| 4021 | 1 | 1 | 1/2 = 50.0% |
| 4023 | 1 | 1 | 1/2 = 50.0% |
| 4033 | 2 | 1 | 2/2 = 100.0% |
| 4034 | 1 | 2 | 1/4 = 25.0% |
| 4035 | 2 | 2 | 1/4 = 25.0% |
| 4036 | 1 | 1 | 2/2 = 100.0% |
| 4037 | 2 | 1 | 1/2 = 50.0% |
| 4038 | 1 | 1 | 1/2 = 50.0% |
| 4039 | 1 | 3 | 4/6 = 66.7% |
| 4043 | 2 | 2 | 0/4 = 0.0% |
| 4044 | 2 | 2 | 2/4 = 50.0% |
| 4045 | 1 | 1 | 0/2 = 0.0% |
| 4047 | 1 | 1 | 2/2 = 100.0% |
| 4048 | 2 | 1 | 2/2 = 100.0% |
| 4051 | 2 | 1 | 1/2 = 50.0% |
| 4059 | 1 | 1 | 2/2 = 100.0% |
| 4060 | 2 | 1 | 0/2 = 0.0% |
| the 19 seeds with 10 or more blocks, each once |  | 1225 | mean of seed shares 57.7% (95% CI 51.7% to 63.8%, seeds drawn) |

### Tournament 3

| scored matches | Opus xhigh wins/matches = share | 95% CI (seed blocks drawn, wins over matches) | mean of block shares (a block counts once) | 95% CI | Opus minus Astra, Elo (95% CI) | blocks Opus both / split / Astra both |
|---|---|---|---|---|---|---|
| 41 matches, 21 seed blocks (seed 3030 half) | 22/41 = 53.7% | 38.1% to 69.0% | 52.4% | 35.7% to 69.0% | +25 (-88 to +132) | 6 / 10 / 4 |
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
