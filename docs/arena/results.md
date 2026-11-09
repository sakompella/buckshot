# Arena results

This page summarizes the tournaments run so far, the findings about model reasoning, and the open work. The raw data stays under `_work/arena/`, which isn't committed. See [README.md](README.md) for how to run and resume. All costs are list-price costs: list prices applied to usage on subscription plans, not money paid.

Ratings are one Bradley-Terry fit over every scored match of every tournament, on an Elo scale with the mean at 0, per configuration (model + endpoint + effort). So one rating scale covers every config. This match rating is not the viewer's Round Elo, which fits each round as a game; [net-points.md](analysis/net-points.md) lists Round Elo per config. A second fit on pot share (a config's cash over the match's cash, which also credits round prizes a loser banked) gives the cash rating. 95% intervals are in [matchups.md](analysis/matchups.md). Each pairing plays 10 seeds in both seat orders, 20 matches, unless stated otherwise. With 10 seeds, close rankings aren't reliable. "Medium" also isn't equal compute across providers.

Scope: 3,537 scored matches with no DeepSeek seat, from the 3,557-match snapshot of 2026-11-04 (tournaments 5 to 9 are finished). The regret and patterns pages under [analysis/](analysis/) cover the same snapshot (3,536 matches; one match with an unsearched decision is left out).

## Status (snapshot of 2026-11-04)
This page describes the 3,557-match snapshot of the analysis database: 3,557 completed matches, 43 partial, 54 tournament rows (phase directories) and no replay issues.
- **tournament-1** (`_work/arena/tournament-1`): finished. 120 scheduled matches are unplayed, all against DeepSeek: 38 started and are partial, and 82 never started. The leftover Astra and terra matches finished on 2026-10-22 (below).
- **tournament-2** (`_work/arena/tournament-2`, config `web/tournaments/opus-effort.json`): stage A is finished. Stage B, the max pairings, hasn't started and needs the user's go-ahead.
- **tournament-3** (`_work/arena/tournament-3`, config `web/tournaments/astra-opus-xhigh.json`): finished, 40 of 40 capped matches.
- **tournament-4** (`_work/arena/tournament-4`): finished, 288 of 288 (below). The 138 Sonnet max matches once scheduled in tournament-1 were cut when tournament-4 took over its cross-model games; the import skips them.
- **tournament-5** (`_work/arena/tournament-5`, 11 phase directories): finished. 214 of its 264 scheduled matches were played, since the schedule was cut to a smaller selection to save usage quota (below).
- **tournament-6** (`_work/arena/tournament-6`, 4 phases): finished 2026-11-02. 37 of its 114 scheduled matches were played (the selection was cut to save quota). Phases: astra-none, terra-claude, opus-none, haiku-ladder.
- **tournament-7** (`_work/arena/tournament-7`, 8 phases): finished 2026-11-02. 73 of its 146 scheduled matches were played (selected only). Terra 6.1 efforts, Astra off and high, and cross-model games.
- **tournament-8** (`_work/arena/tournament-8`): finished 2026-11-04; all 642 matches are in the snapshot. It topped the Terra 6.1, Astra and Opus configurations up to 80 matches each.
- **tournament-9** (`_work/arena/tournament-9`, 3 phases): finished 2026-11-03. 100 of 100 matches played (Haiku 4.5 and Haiku 5.5 effort games).

## Leaderboard
One table per cohort, ranked by the pooled match rating. Matches, win share and pot share count the cohort's own games; ratings come from the one pooled fit, so a config has the same rating in every table. Sonnet max has 2 games in tournament 1's cross-model cohort (it lost both to Opus), so its rating there rests on its tournament-4 games. Tournament 5's 214 matches are one table of their own. Most of its configs had 2 to 12 matches against different opponents there, so their ratings rest mostly on the prior and later tournaments, not on that record. A config with fewer than 20 matches in total is provisional, as in the viewer. `python3 tools/arena/analysis/leaderboard.py --doc docs/arena/results.md` rewrites the tables.

<!-- leaderboard:start -->
### All configs

3537 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-opus-5-5-max | 80 | 73.8% | 64.4% | +218 | +118 |
| gpt-6.1-terra-max | 80 | 72.5% | 66.0% | +202 | +121 |
| gpt-6-astra-high | 80 | 71.2% | 66.1% | +179 | +116 |
| claude-sonnet-5-5-max | 140 | 67.1% | 62.3% | +173 | +107 |
| claude-opus-5-5-xhigh | 150 | 54.7% | 53.4% | +170 | +100 |
| gpt-6.1-terra-xhigh | 80 | 70.0% | 59.7% | +157 | +59 |
| gpt-6-astra | 254 | 66.5% | 60.2% | +149 | +84 |
| claude-opus-5-5-high | 80 | 58.8% | 54.7% | +147 | +77 |
| gpt-6.1-sol-max | 122 | 57.4% | 54.9% | +143 | +95 |
| gpt-6-astra-low | 80 | 65.0% | 59.4% | +123 | +63 |
| claude-sonnet-5-5-xhigh | 160 | 60.0% | 54.7% | +122 | +56 |
| claude-opus-5-5-off | 80 | 62.5% | 58.8% | +108 | +63 |
| gpt-6.1-terra | 80 | 62.5% | 57.7% | +103 | +49 |
| gpt-6-astra-low-recall | 80 | 63.7% | 55.9% | +102 | +31 |
| gpt-6.1-terra-off | 80 | 65.0% | 56.9% | +91 | +25 |
| gpt-6.1-sol-low | 98 | 52.0% | 50.9% | +90 | +60 |
| gpt-6.1-sol-xhigh | 101 | 51.5% | 52.4% | +87 | +68 |
| claude-opus-5-5 | 294 | 57.5% | 54.2% | +85 | +46 |
| gpt-6.1-terra-high | 80 | 63.7% | 59.7% | +85 | +47 |
| claude-haiku-5-5-max | 111 | 61.3% | 58.7% | +72 | +44 |
| gpt-6.1-sol | 271 | 57.2% | 56.8% | +65 | +55 |
| claude-haiku-5-5-xhigh | 158 | 54.4% | 50.4% | +61 | +12 |
| gpt-6.1-sol-high | 99 | 47.5% | 48.0% | +60 | +41 |
| gpt-6.1-terra-low | 80 | 56.2% | 55.5% | +48 | +31 |
| claude-sonnet-5-5-high | 161 | 46.6% | 46.9% | +35 | +7 |
| claude-haiku-5-5-high | 173 | 51.4% | 50.3% | +32 | +5 |
| claude-sonnet-5-5 | 324 | 49.1% | 49.5% | +10 | +2 |
| gpt-5.6-terra-xhigh | 93 | 57.0% | 55.1% | +7 | +32 |
| gpt-5.6-terra-max | 90 | 57.8% | 53.8% | +2 | +19 |
| claude-haiku-5-5 | 342 | 50.3% | 50.3% | +1 | -4 |
| claude-haiku-5-5-low | 194 | 50.5% | 51.3% | -1 | -3 |
| claude-opus-5-5-low | 80 | 41.2% | 49.4% | -7 | +23 |
| claude-sonnet-5-5-off | 164 | 39.6% | 42.4% | -14 | -22 |
| gpt-6-luna-xhigh | 115 | 68.7% | 63.6% | -26 | -9 |
| gpt-6-luna-max | 112 | 67.0% | 63.2% | -44 | -14 |
| gpt-5.6-terra | 259 | 45.9% | 48.0% | -61 | -24 |
| claude-sonnet-5-5-low | 159 | 31.4% | 39.5% | -67 | -40 |
| gpt-5.6-terra-high | 91 | 44.0% | 49.5% | -75 | -4 |
| gpt-5.6-terra-low | 91 | 40.7% | 45.5% | -93 | -25 |
| gpt-6-luna-high | 112 | 59.8% | 55.5% | -100 | -67 |
| claude-haiku-5-5-off | 202 | 37.1% | 39.8% | -137 | -100 |
| claude-haiku-4-5-20251001 | 340 | 33.5% | 38.3% | -198 | -122 |
| claude-haiku-4-5-20251001-minimal | 143 | 39.9% | 42.5% | -234 | -139 |
| claude-haiku-4-5-20251001-low | 149 | 36.9% | 41.9% | -250 | -139 |
| gpt-6-luna | 282 | 26.2% | 34.1% | -262 | -154 |
| claude-haiku-4-5-20251001-high | 135 | 34.8% | 42.0% | -280 | -147 |
| gpt-6-luna-off | 110 | 26.4% | 33.8% | -341 | -207 |
| gpt-6-luna-low | 110 | 25.5% | 31.4% | -346 | -222 |
| claude-haiku-4-5-20251001-off | 125 | 22.4% | 32.6% | -388 | -216 |

### Tournament 8

642 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-opus-5-5-max | 40 | 87.5% | 73.8% | +218 | +118 |
| gpt-6.1-terra-max | 60 | 71.7% | 64.7% | +202 | +121 |
| gpt-6-astra-high | 60 | 76.7% | 69.8% | +179 | +116 |
| claude-opus-5-5-xhigh | 38 | 57.9% | 56.2% | +170 | +100 |
| gpt-6.1-terra-xhigh | 60 | 76.7% | 64.7% | +157 | +59 |
| claude-opus-5-5-high | 23 | 87.0% | 73.0% | +147 | +77 |
| gpt-6-astra-low | 60 | 71.7% | 62.6% | +123 | +63 |
| claude-sonnet-5-5-xhigh | 38 | 63.2% | 56.0% | +122 | +56 |
| claude-opus-5-5-off | 54 | 64.8% | 60.6% | +108 | +63 |
| gpt-6.1-terra | 59 | 67.8% | 61.1% | +103 | +49 |
| gpt-6-astra-low-recall | 60 | 63.3% | 54.1% | +102 | +31 |
| gpt-6.1-terra-off | 60 | 68.3% | 59.2% | +91 | +25 |
| claude-opus-5-5 | 25 | 44.0% | 49.6% | +85 | +46 |
| gpt-6.1-terra-high | 60 | 70.0% | 62.4% | +85 | +47 |
| claude-haiku-5-5-xhigh | 42 | 35.7% | 42.5% | +61 | +12 |
| gpt-6.1-terra-low | 60 | 56.7% | 56.7% | +48 | +31 |
| claude-sonnet-5-5-high | 38 | 31.6% | 37.7% | +35 | +7 |
| claude-haiku-5-5-high | 43 | 37.2% | 39.4% | +32 | +5 |
| claude-sonnet-5-5 | 32 | 37.5% | 40.0% | +10 | +2 |
| claude-haiku-5-5 | 31 | 25.8% | 35.7% | +1 | -4 |
| claude-haiku-5-5-low | 41 | 34.1% | 42.7% | -1 | -3 |
| claude-opus-5-5-low | 32 | 43.8% | 46.5% | -7 | +23 |
| claude-sonnet-5-5-off | 43 | 18.6% | 29.6% | -14 | -22 |
| claude-sonnet-5-5-low | 38 | 15.8% | 31.5% | -67 | -40 |
| claude-haiku-5-5-off | 37 | 10.8% | 26.5% | -137 | -100 |
| claude-haiku-4-5-20251001 | 32 | 12.5% | 26.0% | -198 | -122 |
| claude-haiku-4-5-20251001-minimal | 31 | 9.7% | 26.2% | -234 | -139 |
| claude-haiku-4-5-20251001-low | 34 | 11.8% | 22.5% | -250 | -139 |
| claude-haiku-4-5-20251001-high | 29 | 6.9% | 25.1% | -280 | -147 |
| claude-haiku-4-5-20251001-off | 24 | 0.0% | 17.8% | -388 | -216 |

### Cross-model games (tournament 1)

562 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-sonnet-5-5-max | 2 | 0.0% | 34.4% | +173 | +107 |
| gpt-6-astra | 140 | 72.1% | 63.3% | +149 | +84 |
| claude-opus-5-5 | 142 | 62.7% | 58.2% | +85 | +46 |
| gpt-6.1-sol | 140 | 59.3% | 58.2% | +65 | +55 |
| claude-sonnet-5-5 | 140 | 55.0% | 54.2% | +10 | +2 |
| claude-haiku-5-5 | 140 | 57.9% | 53.7% | +1 | -4 |
| gpt-5.6-terra | 140 | 45.7% | 48.3% | -61 | -24 |
| claude-haiku-4-5-20251001 | 140 | 30.0% | 35.7% | -198 | -122 |
| gpt-6-luna | 140 | 17.9% | 28.5% | -262 | -154 |

### claude-haiku-5-5 efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-haiku-5-5-max | 100 | 60.0% | 57.8% | +72 | +44 |
| claude-haiku-5-5-xhigh | 100 | 65.0% | 55.0% | +61 | +12 |
| claude-haiku-5-5-high | 100 | 54.0% | 53.6% | +32 | +5 |
| claude-haiku-5-5 | 100 | 45.0% | 49.5% | +1 | -4 |
| claude-haiku-5-5-low | 100 | 45.0% | 47.8% | -1 | -3 |
| claude-haiku-5-5-off | 100 | 31.0% | 36.2% | -137 | -100 |

### claude-sonnet-5-5 efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-sonnet-5-5-max | 100 | 68.0% | 63.4% | +173 | +107 |
| claude-sonnet-5-5-xhigh | 100 | 58.0% | 52.9% | +122 | +56 |
| claude-sonnet-5-5-high | 100 | 51.0% | 49.2% | +35 | +7 |
| claude-sonnet-5-5 | 100 | 45.0% | 47.6% | +10 | +2 |
| claude-sonnet-5-5-off | 100 | 43.0% | 44.9% | -14 | -22 |
| claude-sonnet-5-5-low | 100 | 35.0% | 42.0% | -67 | -40 |

### gpt-6-luna efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6-luna-xhigh | 100 | 72.0% | 66.0% | -26 | -9 |
| gpt-6-luna-max | 100 | 72.0% | 66.1% | -44 | -14 |
| gpt-6-luna-high | 100 | 62.0% | 56.8% | -100 | -67 |
| gpt-6-luna | 100 | 39.0% | 42.7% | -262 | -154 |
| gpt-6-luna-off | 100 | 28.0% | 35.4% | -341 | -207 |
| gpt-6-luna-low | 100 | 27.0% | 32.9% | -346 | -222 |

### Tournament 5

214 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-opus-5-5-max | 40 | 60.0% | 55.0% | +218 | +118 |
| gpt-6.1-terra-max | 4 | 75.0% | 66.1% | +202 | +121 |
| gpt-6-astra-high | 8 | 37.5% | 50.6% | +179 | +116 |
| claude-sonnet-5-5-max | 30 | 60.0% | 54.7% | +173 | +107 |
| claude-opus-5-5-xhigh | 30 | 36.7% | 45.7% | +170 | +100 |
| gpt-6.1-terra-xhigh | 10 | 40.0% | 40.0% | +157 | +59 |
| gpt-6-astra | 34 | 58.8% | 55.0% | +149 | +84 |
| claude-opus-5-5-high | 2 | 50.0% | 33.3% | +147 | +77 |
| gpt-6.1-sol-max | 32 | 46.9% | 49.7% | +143 | +95 |
| gpt-6-astra-low | 12 | 58.3% | 55.4% | +123 | +63 |
| claude-sonnet-5-5-xhigh | 8 | 87.5% | 83.3% | +122 | +56 |
| claude-opus-5-5-off | 12 | 58.3% | 61.1% | +108 | +63 |
| gpt-6.1-terra | 20 | 50.0% | 50.8% | +103 | +49 |
| gpt-6.1-terra-off | 8 | 50.0% | 41.7% | +91 | +25 |
| gpt-6.1-sol-low | 6 | 66.7% | 61.1% | +90 | +60 |
| gpt-6.1-sol-xhigh | 10 | 60.0% | 60.4% | +87 | +68 |
| claude-opus-5-5 | 28 | 57.1% | 51.1% | +85 | +46 |
| gpt-6.1-terra-high | 8 | 25.0% | 33.1% | +85 | +47 |
| gpt-6.1-sol | 12 | 58.3% | 61.1% | +65 | +55 |
| gpt-6.1-sol-high | 8 | 37.5% | 42.8% | +60 | +41 |
| gpt-6.1-terra-low | 8 | 62.5% | 58.6% | +48 | +31 |
| claude-sonnet-5-5-high | 8 | 62.5% | 53.6% | +35 | +7 |
| claude-haiku-5-5-high | 6 | 66.7% | 54.8% | +32 | +5 |
| claude-sonnet-5-5 | 10 | 30.0% | 30.0% | +10 | +2 |
| claude-haiku-5-5 | 14 | 35.7% | 37.6% | +1 | -4 |
| claude-haiku-5-5-low | 8 | 37.5% | 45.6% | -1 | -3 |
| claude-opus-5-5-low | 12 | 33.3% | 44.4% | -7 | +23 |
| claude-sonnet-5-5-off | 8 | 62.5% | 57.8% | -14 | -22 |
| gpt-6-luna-xhigh | 4 | 50.0% | 49.4% | -26 | -9 |
| gpt-6-luna-max | 2 | 50.0% | 66.7% | -44 | -14 |
| claude-sonnet-5-5-low | 8 | 25.0% | 31.9% | -67 | -40 |
| claude-haiku-4-5-20251001 | 8 | 25.0% | 28.9% | -198 | -122 |
| gpt-6-luna | 10 | 10.0% | 20.2% | -262 | -154 |

### claude-haiku-4-5-20251001 efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 | 80 | 58.8% | 55.8% | -198 | -122 |
| claude-haiku-4-5-20251001-minimal | 80 | 57.5% | 51.2% | -234 | -139 |
| claude-haiku-4-5-20251001-low | 80 | 51.2% | 52.7% | -250 | -139 |
| claude-haiku-4-5-20251001-high | 80 | 53.8% | 52.4% | -280 | -147 |
| claude-haiku-4-5-20251001-off | 80 | 28.7% | 38.0% | -388 | -216 |

### gpt-5.6-terra efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-5.6-terra-xhigh | 80 | 60.0% | 56.1% | +7 | +32 |
| gpt-5.6-terra-max | 80 | 58.8% | 53.9% | +2 | +19 |
| gpt-5.6-terra | 80 | 45.0% | 45.0% | -61 | -24 |
| gpt-5.6-terra-high | 80 | 46.2% | 50.8% | -75 | -4 |
| gpt-5.6-terra-low | 80 | 40.0% | 44.2% | -93 | -25 |

### gpt-6.1-sol efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6.1-sol-max | 80 | 58.8% | 54.7% | +143 | +95 |
| gpt-6.1-sol-low | 80 | 48.8% | 48.7% | +90 | +60 |
| gpt-6.1-sol-xhigh | 80 | 48.8% | 49.8% | +87 | +68 |
| gpt-6.1-sol | 80 | 46.2% | 49.1% | +65 | +55 |
| gpt-6.1-sol-high | 80 | 47.5% | 47.7% | +60 | +41 |

### Tournament 9

100 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-haiku-5-5-high | 10 | 90.0% | 70.4% | +32 | +5 |
| claude-haiku-5-5 | 10 | 80.0% | 83.8% | +1 | -4 |
| claude-haiku-5-5-low | 30 | 86.7% | 73.1% | -1 | -3 |
| claude-haiku-5-5-off | 50 | 70.0% | 59.3% | -137 | -100 |
| claude-haiku-4-5-20251001 | 40 | 25.0% | 30.6% | -198 | -122 |
| claude-haiku-4-5-20251001-minimal | 20 | 15.0% | 33.6% | -234 | -139 |
| claude-haiku-4-5-20251001-low | 20 | 20.0% | 33.4% | -250 | -139 |
| claude-haiku-4-5-20251001-high | 10 | 20.0% | 40.0% | -280 | -147 |
| claude-haiku-4-5-20251001-off | 10 | 30.0% | 33.6% | -388 | -216 |

### Opus efforts (tournament 2)

80 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-opus-5-5-xhigh | 40 | 65.0% | 58.6% | +170 | +100 |
| claude-opus-5-5-high | 40 | 45.0% | 44.1% | +147 | +77 |
| claude-opus-5-5 | 60 | 48.3% | 48.1% | +85 | +46 |
| claude-opus-5-5-low | 20 | 35.0% | 50.2% | -7 | +23 |

### Tournament 7

73 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6.1-terra-max | 16 | 75.0% | 70.7% | +202 | +121 |
| gpt-6-astra-high | 12 | 66.7% | 58.1% | +179 | +116 |
| claude-opus-5-5-xhigh | 1 | 100.0% | 64.4% | +170 | +100 |
| gpt-6.1-terra-xhigh | 6 | 66.7% | 55.6% | +157 | +59 |
| gpt-6-astra | 1 | 0.0% | 0.0% | +149 | +84 |
| claude-opus-5-5-high | 4 | 50.0% | 51.1% | +147 | +77 |
| gpt-6-astra-low | 7 | 14.3% | 38.4% | +123 | +63 |
| claude-sonnet-5-5-xhigh | 3 | 33.3% | 22.2% | +122 | +56 |
| claude-opus-5-5-off | 3 | 66.7% | 43.7% | +108 | +63 |
| gpt-6-astra-low-recall | 13 | 76.9% | 69.1% | +102 | +31 |
| gpt-6.1-terra-off | 9 | 77.8% | 63.0% | +91 | +25 |
| gpt-6.1-sol-low | 2 | 100.0% | 65.6% | +90 | +60 |
| gpt-6.1-sol-xhigh | 1 | 0.0% | 33.3% | +87 | +68 |
| claude-opus-5-5 | 1 | 0.0% | 31.1% | +85 | +46 |
| gpt-6.1-terra-high | 9 | 66.7% | 66.4% | +85 | +47 |
| gpt-6.1-sol | 2 | 100.0% | 84.4% | +65 | +55 |
| claude-haiku-5-5-xhigh | 4 | 25.0% | 33.3% | +61 | +12 |
| gpt-6.1-sol-high | 1 | 0.0% | 31.1% | +60 | +41 |
| gpt-6.1-terra-low | 9 | 55.6% | 48.9% | +48 | +31 |
| claude-sonnet-5-5-high | 3 | 33.3% | 34.8% | +35 | +7 |
| claude-haiku-5-5-high | 2 | 0.0% | 0.0% | +32 | +5 |
| claude-sonnet-5-5 | 4 | 25.0% | 33.3% | +10 | +2 |
| gpt-5.6-terra-xhigh | 3 | 66.7% | 67.4% | +7 | +32 |
| claude-haiku-5-5 | 4 | 0.0% | 32.8% | +1 | -4 |
| claude-haiku-5-5-low | 2 | 50.0% | 66.7% | -1 | -3 |
| claude-opus-5-5-low | 4 | 0.0% | 32.8% | -7 | +23 |
| claude-sonnet-5-5-off | 2 | 50.0% | 34.4% | -14 | -22 |
| gpt-6-luna-xhigh | 1 | 0.0% | 0.0% | -26 | -9 |
| gpt-5.6-terra | 3 | 0.0% | 22.2% | -61 | -24 |
| claude-sonnet-5-5-low | 2 | 50.0% | 47.8% | -67 | -40 |
| gpt-5.6-terra-high | 1 | 0.0% | 35.6% | -75 | -4 |
| gpt-5.6-terra-low | 1 | 0.0% | 31.1% | -93 | -25 |
| gpt-6-luna-high | 2 | 50.0% | 51.1% | -100 | -67 |
| claude-haiku-5-5-off | 2 | 0.0% | 0.0% | -137 | -100 |
| claude-haiku-4-5-20251001 | 1 | 0.0% | 0.0% | -198 | -122 |
| claude-haiku-4-5-20251001-minimal | 1 | 100.0% | 66.7% | -234 | -139 |
| claude-haiku-4-5-20251001-low | 2 | 0.0% | 17.8% | -250 | -139 |
| claude-haiku-4-5-20251001-high | 2 | 0.0% | 16.7% | -280 | -147 |

### Tournament 6

37 scored matches.

| config | matches | win share | pot share | match rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6.1-terra-xhigh | 4 | 50.0% | 41.1% | +157 | +59 |
| claude-opus-5-5-high | 1 | 0.0% | 33.3% | +147 | +77 |
| gpt-6-astra-low | 1 | 100.0% | 68.9% | +123 | +63 |
| claude-sonnet-5-5-xhigh | 1 | 100.0% | 66.7% | +122 | +56 |
| claude-opus-5-5-off | 11 | 54.5% | 51.7% | +108 | +63 |
| gpt-6.1-terra | 1 | 0.0% | 0.0% | +103 | +49 |
| gpt-6-astra-low-recall | 7 | 42.9% | 47.0% | +102 | +31 |
| gpt-6.1-terra-off | 3 | 0.0% | 33.3% | +91 | +25 |
| claude-opus-5-5 | 2 | 100.0% | 66.7% | +85 | +46 |
| gpt-6.1-terra-high | 3 | 33.3% | 55.6% | +85 | +47 |
| claude-haiku-5-5-max | 1 | 100.0% | 66.7% | +72 | +44 |
| gpt-6.1-sol | 1 | 100.0% | 64.4% | +65 | +55 |
| claude-haiku-5-5-xhigh | 2 | 50.0% | 51.1% | +61 | +12 |
| gpt-6.1-terra-low | 3 | 33.3% | 44.4% | +48 | +31 |
| claude-sonnet-5-5-high | 2 | 0.0% | 32.2% | +35 | +7 |
| claude-haiku-5-5-high | 2 | 100.0% | 100.0% | +32 | +5 |
| claude-sonnet-5-5 | 2 | 50.0% | 51.1% | +10 | +2 |
| claude-haiku-5-5 | 5 | 100.0% | 73.8% | +1 | -4 |
| claude-haiku-5-5-low | 3 | 33.3% | 45.9% | -1 | -3 |
| claude-opus-5-5-low | 2 | 100.0% | 65.6% | -7 | +23 |
| claude-sonnet-5-5-off | 1 | 100.0% | 100.0% | -14 | -22 |
| claude-sonnet-5-5-low | 1 | 100.0% | 66.7% | -67 | -40 |
| claude-haiku-5-5-off | 3 | 66.7% | 56.3% | -137 | -100 |
| claude-haiku-4-5-20251001 | 3 | 0.0% | 22.2% | -198 | -122 |
| claude-haiku-4-5-20251001-minimal | 1 | 0.0% | 31.1% | -234 | -139 |
| claude-haiku-4-5-20251001-low | 3 | 66.7% | 54.1% | -250 | -139 |
| claude-haiku-4-5-20251001-high | 4 | 0.0% | 16.7% | -280 | -147 |
| claude-haiku-4-5-20251001-off | 1 | 0.0% | 35.6% | -388 | -216 |
<!-- leaderboard:end -->

## tournament-1: cross-model and effort sweeps
2,080 matches, list-price cost $934.46. The only request difference between its two runs of the arena is the GPT reasoning summary (`auto` vs `detailed`).

**Leftovers, finished 2026-10-22** (63 matches, list-price cost about $19.6; all replay-validated). Each pairing is 20 matches. Scores are matches won, first-named entrant first:
- gpt-5.6-terra vs gpt-6-astra: 5–15
- gpt-5.6-terra vs claude-opus-5-5: 8–12
- gpt-5.6-terra vs claude-haiku-4-5: 14–6
- gpt-6-astra vs claude-haiku-4-5: 17–3, after the 3 unfinished matches resumed (Astra 2, haiku 4.5 1 of them)

### Effort sweeps
Each model plays a round robin against its own effort levels (no suffix = medium). Their ratings, pooled with every cross-model game, are in the leaderboard above.

Takeaways:
- xhigh is generally the best level. max rarely beats it clearly and has about 10 times the list-price cost.
- luna gains the most from effort. sol barely changes except at max.
- True off clearly hurts haiku 4.5 and 5.5. haiku 4.5's minimal plays like its medium.
- sonnet 5.5's off is "requested off" (`between_tools`).

## tournament-2: Opus 5.5 effort, stage A
80 matches, list-price cost $58.89. Each new level plays medium and its neighbouring level: low–medium, medium–high, medium–xhigh, high–xhigh.

Ratings are in the leaderboard above.

Head to head:
- medium beat low 65–35;
- high beat medium 55–45;
- xhigh beat medium 65–35;
- xhigh beat high 65–35.

Stage B would add medium–max and xhigh–max: 40 matches, list-price cost about $355–370 (max matches take about an hour each), about 1.5–2.5 days at the Claude line. Measured quota use was about 0.0115 of a Claude 5h window per dollar on one account and 0.0080 on the other.

## tournament-3: Opus 5.5 xhigh vs Astra medium (finished, 41 matches)
- **Seeds:** fixed in advance. First 3000–3009, which are tournament-1's Opus medium vs Astra seeds, for a matched comparison. Then 3020–3029. Capped at 40 matches; Aditya later ruled that the one finished match past the cap also counts.
- **Codex accounts:** Astra was pinned to one Codex account per match (ADR-0042) from match 38 on. Opus was never pinned.
- **The last 2 matches** ran with no quota line. Seed 3028's first match started without a pin, and CPA may have moved it to the other Codex account while account 1 was full. Seed 3029's second match stayed pinned and waited for account 1 to reset.

**Results (20 complete seed pairs plus seed 3030's first match):**
- **Overall:** Opus xhigh 22, Astra 19. Opus share 53.7%, 95% CI 38.1–69.0% (seed bootstrap over 21 seeds). On the 20 complete pairs alone it was 22–18, 55.0%, CI 40.0–70.0%.
- **Per seed:** Opus won both games on 6 seeds, Astra on 4, and 10 split. Astra won seed 3030's only game. Seat 2 won 17 of 41.
- **Matched against Opus medium** on seeds 3000–3009: 10/20 vs 9/20, a difference of +5%, 95% CI −15% to +25%.
- **Verdict:** inconclusive. The data rules out neither model being somewhat stronger, and xhigh shows no measurable gain over medium against Astra.
- **List-price cost:** $41.11: Opus $29.75, Astra $11.36. Astra reports few reasoning tokens at medium: about 3k over 1,077 calls.

**Outside the cap.** A brief uncapped run started 6 matches (seeds 3030–3032). Seed 3030's first match finished and is scored above. The other 5 never finished, are not scored, and have a list-price cost of $1.38 together. They stay in the tournament directory, unfinished.

**Lessons:**
- **Pass every needed `--code` when using a cap.** While an old-code match waits for its checkout, the runner leaves it off its pending list, so `--limit` picks a match past the cap.
- **An account with no quota data isn't over the limit.** `tools/arena/quota_guard.py` now treats it as not blocking; the old rule caused a false stop at 8:58 PM.
- **List accounts on every endpoint,** Claude as well as Codex, so both sides of each new match are pinned from the start.

## tournament-4: cross-model samples (finished 2026-10-25, 288 matches)

Every config that had only played its own model's effort sweep played 10 matches against other models at medium effort: 5 seat-swapped pairs, each against a different opponent, seeds 3000–3009. Sonnet max played 8 here; its other 2 (both lost to Opus) are in tournament-1. 288 matches, no failed runs, list-price cost $108.96. With these, every config has cross-model games, so the pooled rating no longer leans on the effort sweeps alone.

Wins out of 10 (Sonnet max: of 8 here):

| model | wins by effort |
|---|---|
| Haiku 4.5 | off 2/10, minimal 4/10, low 4/10, high 0/10 |
| Haiku 5.5 | off 3/10, low 8/10, high 4/10, xhigh 4/10, max 7/10 |
| Opus 5.5 | low 6/10, high 6/10 |
| Sonnet 5.5 | off 7/10, low 5/10, high 6/10, xhigh 5/10, max 8/8 |
| Terra | low 5/10, high 3/10, xhigh 3/10, max 5/10 |
| Luna | off 1/10, low 1/10, high 4/10, xhigh 5/10, max 2/10 |
| Sol | low 6/10, high 6/10, xhigh 7/10, max 8/10 |

Ten games per config is a small sample: read single cells as rough. Two patterns stand out. Haiku 4.5 at high won none of its 10. Sol stays strong at every effort (6–8 of 10). The pooled ratings over all tournaments are in the leaderboard above, the viewer and [matchups.md](analysis/matchups.md).

## Tournament 5 (finished 2026-11-01)

214 scored matches in 11 phases, $353.50 of list-price usage (every call priced). The database total is now $1,557.95. Seeds are 4000 to 4061, which no earlier tournament played, so there is no matched-seed comparison with tournaments 1 to 4. The matched-seed tool (`tools/arena/seed_pairs.py`) was used within the tournament. Ratings below are the pooled ones in the leaderboard.

Only three pairings played 5 seeds in both seats (10 matches): Opus max against low, medium and xhigh. The top-four round robin also plays 5 seeds per pair. Everything else is one seed in both seats (2 matches per pairing), so a single pairing says very little. Counts below are from tournament 5 alone. With tournaments 7, 8 and 9 added, Opus off, Astra low and high, and every Terra 6.1 effort have 80 matches each. Ratings are the pooled ones of the 2026-11-04 snapshot.

- **Opus max:** 24 wins in 40 matches (60%) here; 59 of 80 overall (73.8%), pooled rating +218 (+137 to +318), the top of the all-configs table. Before this tournament it had 8 matches and +334.
  - Against its own efforts, 5 seeds in both seats: 7-3 against low, 6-4 against medium, 5-5 against xhigh. The 95% intervals on those shares span 60 to 70 points (20% to 80% for xhigh), so none is settled.
  - Against Sonnet, Haiku 5.5, Astra, Sol and Terra 6.1 at medium, one seed each: 6 wins in 10.
  - On the pooled scale Opus xhigh is +170, high +147, medium +85 and low -7.
- **Terra 6.1:** results at all six efforts. Medium has 80 matches overall, 50 wins, +103 (+26 to +185). The others, with tournament-5 wins and the pooled rating over 80 matches: off 4 of 8 (+91), low 5 of 8 (+48), high 2 of 8 (+85), xhigh 4 of 10 (+157), max 3 of 4 (+202, +120 to +296). Max is second in the all-configs table.
  - Against each other: low beat off 2-0, xhigh beat high 2-0, max beat xhigh 2-0, medium beat xhigh 2-0, and medium split 1-1 with off, low and high.
  - Terra 6.1 medium (+103) is above Terra 5.6 medium (-61), on 80 matches against 259.
- **Opus off:** 7 wins in 12 matches (58%) here; 50 of 80 overall (62.5%), +108 (+30 to +193). It split 1-1 with Opus low, medium, high, Haiku 5.5 medium and Luna xhigh, and beat Sonnet off 2-0. That is above Opus medium (+85) and below high (+147); the intervals overlap.
- **Astra low and high:** low won 7 of 12 here (+123 pooled over 80 matches, +52 to +209), high won 3 of 8 (+179 over 80, +98 to +274), against Astra medium at +149 (254 matches).
  - Astra medium beat Astra low 2-0 and split 1-1 with Astra high.
  - Low: Sonnet medium 2-0 for low, Luna medium 2-0, 1-1 with Opus, Haiku 5.5 and Sol at medium.
  - High: lost 0-2 to Sonnet medium, 1-1 with Opus and Sol at medium.
- **Top-four round robin** (5 seeds in both seats per pair; Opus xhigh against Astra is tournament 3's 41 matches):

| pair | first named wins |
|---|---|
| Sonnet max v Opus xhigh | 8-2 |
| Sonnet max v Sol max | 6-4 |
| Sonnet max v Astra | 4-6 |
| Astra v Sol max | 6-4 |
| Opus xhigh v Sol max | 4-6 |
| Opus xhigh v Astra | 22-19 |

  Sonnet max won 8 of 10 against Opus xhigh (over complete seed pairs, 95% interval 60% to 100%). The pooled ratings are Sonnet max +173, Astra +149, Opus xhigh +170, Sol max +143. Opus xhigh was +180 before tournament 5, Sonnet max +160.

## Beliefs and items
What each model knew about the chamber when it shot, whether it acted on it, what became of its items, and how consistently it chose in repeated positions: [analysis/beliefs-and-items.md](analysis/beliefs-and-items.md).

## Other analyses
- **Matchups:** ratings within each cohort, no matchup effects, seat and round-1 starter effects: [analysis/matchups.md](analysis/matchups.md).
- **Patterns against regret:** the mean regret of single-move choice patterns: [analysis/patterns.md](analysis/patterns.md).
- **Ideas not yet built:** [analysis-ideas.md](analysis-ideas.md).

## Known confound: an extra system prompt on Claude calls
The Claude subscription account behind CPA carries organization-level instructions about a LibKey scholarly-article connector, and they reach every Claude request sent through CPA. The arena's own prompts never contain them. 38 Claude calls in 38 matches mention them (Sonnet max 25, Sonnet xhigh 2, Haiku 5.5 max 11), always to say they don't apply; other calls likely carried them silently. GPT calls never saw them. The effect on play is probably small, but Claude and GPT did not get identical prompts. To remove it, turn off the account's organization instructions or use an account without them before the next tournament.

## Reasoning findings
- **GPT reasoning summaries are short upstream.** Nothing is lost in CPA, pi-ai or the arena.
  - A census of 50,904 saved calls and 36 raw streaming probes showed every summary delta equals the final item; there's no raw reasoning text.
  - Direct requests to the Codex backend without CPA return the same thing: headings for luna, terra and astra; rare prose or nothing for sol.
  - Keep `summary: "detailed"`. Omitting it returns no text; `auto` is echoed as `detailed`; `concise` gave sol headings where `detailed` gave none, but sol's `detailed` sometimes returns real prose.
  - The public OpenAI API can't be tested with the subscription credentials (missing `api.responses.write`).
- **Saved runs keep the full text.** Each match's `calls.jsonl` keeps the returned thinking text, usage including reasoning tokens, tool calls and latency. `session.sqlite` keeps full conversations with encrypted reasoning signatures, which allow resume but can't be decrypted.
- **Claude 5.5 summaries are prose,** from about 250 characters at medium to 9–13k at max. At medium, sonnet and opus skip thinking on 40–50% of calls.
- **A required `reason` field on `play_move`** produced readable 1–3 sentence rationales from all four GPT models, exposing their mistakes. It's a self-report, and its effect on play is untested.
- **Effort availability:**
  - terra and gpt-5.6-luna `none` reach the Codex backend fine (0 reasoning tokens), but CPA rewrites them to `low`.
  - gpt-6-luna `none` works.
  - gpt-6.1-sol rejects `none`.
  - opus 5.5 can't disable thinking.
  - sonnet 5.5 `disabled` returned 200 with 0 thinking through the hub, which contradicts Anthropic's docs. Unresolved.
- **How other benchmarks pair entrants:** Kaggle Game Arena plays a round robin with seat swaps. LMArena samples pairs adaptively. Effort variants appear as separate entrants elsewhere, but no benchmark found plays a model's own effort levels against each other. Here, neighbouring effort levels plus medium carry the most information per game.

## Open work
1. tournament-2 stage B: needs the user's go-ahead.
2. gpt-5.6-luna effort sweep: a medium entrant, placement against the medium models, then low–max. About 160 matches on Codex quota. `none` needs the CPA patch.
3. tournament-1 leftovers: 20 matches per pairing against DeepSeek (free tier refusing). Refit the medium table with the 63 new matches.
4. `web/src/arena/runlog.ts`: join thinking blocks with `"\n\n"`. About 1.9% of saved texts run headings together. This changes the code hash.
5. An optional, separately labelled entrant with a `reason` field. Check its effect on play with paired seeds before rating it.
6. Keep the `t3-1427bb8e` worktree: it holds the tournament data and the current code checkout. its 41 partial tournament-1 matches need the older arena code from git history to resume.
7. Fit the minimax player's evaluator weights from the analysis database before tuning anything by hand.
