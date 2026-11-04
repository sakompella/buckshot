# Arena results

This page summarizes the tournaments run so far, the findings about model reasoning, and the open work. The raw data stays under `_work/arena/`, which isn't committed. See [README.md](README.md) for how to run and resume. All costs are list-price costs: list prices applied to usage on subscription plans, not money paid.

Ratings are one Bradley-Terry fit over every scored match of every tournament, on an Elo scale with the mean at 0, per configuration (model + endpoint + effort). So one rating scale covers every config, as in the viewer. A second fit on pot share (a config's cash over the match's cash, which also credits round prizes a loser banked) gives the cash rating. 95% intervals are in [matchups.md](analysis/matchups.md). Each pairing plays 10 seeds in both seat orders, 20 matches, unless stated otherwise. With 10 seeds, close rankings aren't reliable. "Medium" also isn't equal compute across providers.

Scope: 2,895 scored matches with no DeepSeek seat, from the 2,915-match snapshot of 2026-11-04 (tournaments 5, 6, 7 and 9 are finished; tournament 8 is still running and isn't in it). The regret and patterns pages under [analysis/](analysis/) still describe the 2,553-match snapshot of 2026-10-30.

## Status (snapshot of 2026-11-04)
This page describes the 2,915-match snapshot of the analysis database: 2,915 completed matches, 43 partial, 30 tournament rows (phase directories) and no replay issues.
- **tournament-1** (`_work/arena/tournament-1`): finished. 120 scheduled matches are unplayed, all against DeepSeek: 38 started and are partial, and 82 never started. The leftover Astra and terra matches finished on 2026-10-22 (below).
- **tournament-2** (`_work/arena/tournament-2`, config `web/tournaments/opus-effort.json`): stage A is finished. Stage B, the max pairings, hasn't started and needs the user's go-ahead.
- **tournament-3** (`_work/arena/tournament-3`, config `web/tournaments/astra-opus-xhigh.json`): finished, 40 of 40 capped matches.
- **tournament-4** (`_work/arena/tournament-4`): finished, 288 of 288 (below). The 138 Sonnet max matches once scheduled in tournament-1 were cut when tournament-4 took over its cross-model games; the import skips them.
- **tournament-5** (`_work/arena/tournament-5`, 11 phase directories): finished. 214 of its 264 scheduled matches were played, since the schedule was cut to a smaller selection to save usage quota (below).
- **tournament-6** (`_work/arena/tournament-6`, 4 phases): finished 2026-11-02. 37 of its 114 scheduled matches were played (the selection was cut to save quota). Phases: astra-none, terra-claude, opus-none, haiku-ladder.
- **tournament-7** (`_work/arena/tournament-7`, 8 phases): finished 2026-11-02. 73 of its 146 scheduled matches were played (selected only). Terra 6.1 efforts, Astra off and high, and cross-model games.
- **tournament-8** (`_work/arena/tournament-8`): running, not in the snapshot. Its driver is paused on Codex quota as of 2026-11-04 12:38 AM, waiting for a reset. Opus, Opus max and GPT phases are in progress.
- **tournament-9** (`_work/arena/tournament-9`, 3 phases): finished 2026-11-03. 100 of 100 matches played (Haiku 4.5 and Haiku 5.5 effort games).

## Leaderboard
One table per cohort, ranked by the pooled rating, as the viewer's leaderboards show them. Matches, win share and pot share count the cohort's own games; ratings come from the one pooled fit, so a config has the same rating in every table. Sonnet max has 2 games in tournament 1's cross-model cohort (it lost both to Opus), so its rating there rests on its tournament-4 games. Tournament 5's 214 matches are one table of their own. Most of its configs had 2 to 12 matches against different opponents there, so their ratings rest mostly on the prior and later tournaments, not on that record. A config with fewer than 20 matches in total is provisional, as in the viewer. `python3 tools/arena/analysis/leaderboard.py --doc docs/arena/results.md` rewrites the tables.

<!-- leaderboard:start -->
### All configs

2895 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6.1-terra-max | 20 | 75.0% | 69.8% | +272 | +192 |
| claude-sonnet-5-5-max | 140 | 67.1% | 62.3% | +190 | +117 |
| claude-opus-5-5-xhigh | 112 | 53.6% | 52.4% | +156 | +92 |
| gpt-6-astra | 254 | 66.5% | 60.2% | +153 | +85 |
| gpt-6.1-sol-max | 122 | 57.4% | 54.9% | +148 | +98 |
| claude-opus-5-5-max | 40 | 60.0% | 55.0% | +144 | +89 |
| gpt-6-astra-low-recall | 20 | 65.0% | 61.3% | +133 | +92 |
| claude-sonnet-5-5-xhigh | 122 | 59.0% | 54.3% | +117 | +55 |
| gpt-6-astra-high | 20 | 55.0% | 55.1% | +113 | +84 |
| claude-opus-5-5-off | 26 | 57.7% | 55.1% | +112 | +70 |
| claude-haiku-5-5-xhigh | 116 | 61.2% | 53.2% | +104 | +19 |
| claude-haiku-5-5-max | 111 | 61.3% | 58.7% | +100 | +50 |
| gpt-6.1-sol-low | 98 | 52.0% | 50.9% | +93 | +62 |
| gpt-6.1-sol-xhigh | 101 | 51.5% | 52.4% | +87 | +68 |
| claude-opus-5-5-high | 57 | 47.4% | 47.3% | +84 | +41 |
| claude-opus-5-5 | 269 | 58.7% | 54.7% | +83 | +46 |
| gpt-6.1-terra-low | 20 | 55.0% | 52.1% | +81 | +37 |
| gpt-6.1-sol | 271 | 57.2% | 56.8% | +71 | +57 |
| claude-sonnet-5-5-high | 123 | 51.2% | 49.7% | +68 | +28 |
| gpt-6.1-sol-high | 99 | 47.5% | 48.0% | +63 | +43 |
| claude-haiku-5-5-high | 130 | 56.2% | 53.8% | +59 | +16 |
| gpt-6.1-terra-xhigh | 20 | 50.0% | 44.9% | +55 | +2 |
| claude-sonnet-5-5-off | 121 | 47.1% | 47.0% | +40 | +9 |
| gpt-6.1-terra | 21 | 47.6% | 48.4% | +33 | +13 |
| claude-haiku-5-5-low | 153 | 54.9% | 53.6% | +22 | -3 |
| claude-sonnet-5-5 | 292 | 50.3% | 50.5% | +22 | +10 |
| claude-haiku-5-5 | 311 | 52.7% | 51.7% | +21 | +3 |
| gpt-6-astra-low | 20 | 45.0% | 50.1% | +18 | +38 |
| gpt-5.6-terra-xhigh | 93 | 57.0% | 55.1% | +13 | +35 |
| gpt-5.6-terra-max | 90 | 57.8% | 53.8% | +10 | +22 |
| gpt-6.1-terra-off | 20 | 55.0% | 50.0% | +8 | -23 |
| claude-opus-5-5-low | 48 | 39.6% | 51.4% | -9 | +50 |
| gpt-6-luna-xhigh | 115 | 68.7% | 63.6% | -18 | -7 |
| claude-sonnet-5-5-low | 121 | 36.4% | 42.0% | -27 | -21 |
| gpt-6-luna-max | 112 | 67.0% | 63.2% | -38 | -13 |
| gpt-5.6-terra | 259 | 45.9% | 48.0% | -51 | -20 |
| gpt-6.1-terra-high | 20 | 45.0% | 51.4% | -64 | -16 |
| gpt-5.6-terra-high | 91 | 44.0% | 49.5% | -67 | +0 |
| gpt-5.6-terra-low | 91 | 40.7% | 45.5% | -86 | -23 |
| gpt-6-luna-high | 112 | 59.8% | 55.5% | -94 | -65 |
| claude-haiku-5-5-off | 165 | 43.0% | 42.8% | -95 | -93 |
| claude-haiku-4-5-20251001 | 308 | 35.7% | 39.6% | -177 | -119 |
| claude-haiku-4-5-20251001-minimal | 112 | 48.2% | 47.1% | -202 | -142 |
| claude-haiku-4-5-20251001-low | 115 | 44.3% | 47.7% | -224 | -137 |
| claude-haiku-4-5-20251001-high | 106 | 42.5% | 46.7% | -247 | -149 |
| gpt-6-luna | 282 | 26.2% | 34.1% | -252 | -151 |
| gpt-6-luna-off | 110 | 26.4% | 33.8% | -333 | -205 |
| gpt-6-luna-low | 110 | 25.5% | 31.4% | -338 | -220 |
| claude-haiku-4-5-20251001-off | 101 | 27.7% | 36.1% | -349 | -217 |

### Cross-model games (tournament 1)

562 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-sonnet-5-5-max | 2 | 0.0% | 34.4% | +190 | +117 |
| gpt-6-astra | 140 | 72.1% | 63.3% | +153 | +85 |
| claude-opus-5-5 | 142 | 62.7% | 58.2% | +83 | +46 |
| gpt-6.1-sol | 140 | 59.3% | 58.2% | +71 | +57 |
| claude-sonnet-5-5 | 140 | 55.0% | 54.2% | +22 | +10 |
| claude-haiku-5-5 | 140 | 57.9% | 53.7% | +21 | +3 |
| gpt-5.6-terra | 140 | 45.7% | 48.3% | -51 | -20 |
| claude-haiku-4-5-20251001 | 140 | 30.0% | 35.7% | -177 | -119 |
| gpt-6-luna | 140 | 17.9% | 28.5% | -252 | -151 |

### claude-haiku-5-5 efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-haiku-5-5-xhigh | 100 | 65.0% | 55.0% | +104 | +19 |
| claude-haiku-5-5-max | 100 | 60.0% | 57.8% | +100 | +50 |
| claude-haiku-5-5-high | 100 | 54.0% | 53.6% | +59 | +16 |
| claude-haiku-5-5-low | 100 | 45.0% | 47.8% | +22 | -3 |
| claude-haiku-5-5 | 100 | 45.0% | 49.5% | +21 | +3 |
| claude-haiku-5-5-off | 100 | 31.0% | 36.2% | -95 | -93 |

### claude-sonnet-5-5 efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-sonnet-5-5-max | 100 | 68.0% | 63.4% | +190 | +117 |
| claude-sonnet-5-5-xhigh | 100 | 58.0% | 52.9% | +117 | +55 |
| claude-sonnet-5-5-high | 100 | 51.0% | 49.2% | +68 | +28 |
| claude-sonnet-5-5-off | 100 | 43.0% | 44.9% | +40 | +9 |
| claude-sonnet-5-5 | 100 | 45.0% | 47.6% | +22 | +10 |
| claude-sonnet-5-5-low | 100 | 35.0% | 42.0% | -27 | -21 |

### gpt-6-luna efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6-luna-xhigh | 100 | 72.0% | 66.0% | -18 | -7 |
| gpt-6-luna-max | 100 | 72.0% | 66.1% | -38 | -13 |
| gpt-6-luna-high | 100 | 62.0% | 56.8% | -94 | -65 |
| gpt-6-luna | 100 | 39.0% | 42.7% | -252 | -151 |
| gpt-6-luna-off | 100 | 28.0% | 35.4% | -333 | -205 |
| gpt-6-luna-low | 100 | 27.0% | 32.9% | -338 | -220 |

### Tournament 5

214 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6.1-terra-max | 4 | 75.0% | 66.1% | +272 | +192 |
| claude-sonnet-5-5-max | 30 | 60.0% | 54.7% | +190 | +117 |
| claude-opus-5-5-xhigh | 30 | 36.7% | 45.7% | +156 | +92 |
| gpt-6-astra | 34 | 58.8% | 55.0% | +153 | +85 |
| gpt-6.1-sol-max | 32 | 46.9% | 49.7% | +148 | +98 |
| claude-opus-5-5-max | 40 | 60.0% | 55.0% | +144 | +89 |
| claude-sonnet-5-5-xhigh | 8 | 87.5% | 83.3% | +117 | +55 |
| gpt-6-astra-high | 8 | 37.5% | 50.6% | +113 | +84 |
| claude-opus-5-5-off | 12 | 58.3% | 61.1% | +112 | +70 |
| gpt-6.1-sol-low | 6 | 66.7% | 61.1% | +93 | +62 |
| gpt-6.1-sol-xhigh | 10 | 60.0% | 60.4% | +87 | +68 |
| claude-opus-5-5-high | 2 | 50.0% | 33.3% | +84 | +41 |
| claude-opus-5-5 | 28 | 57.1% | 51.1% | +83 | +46 |
| gpt-6.1-terra-low | 8 | 62.5% | 58.6% | +81 | +37 |
| gpt-6.1-sol | 12 | 58.3% | 61.1% | +71 | +57 |
| claude-sonnet-5-5-high | 8 | 62.5% | 53.6% | +68 | +28 |
| gpt-6.1-sol-high | 8 | 37.5% | 42.8% | +63 | +43 |
| claude-haiku-5-5-high | 6 | 66.7% | 54.8% | +59 | +16 |
| gpt-6.1-terra-xhigh | 10 | 40.0% | 40.0% | +55 | +2 |
| claude-sonnet-5-5-off | 8 | 62.5% | 57.8% | +40 | +9 |
| gpt-6.1-terra | 20 | 50.0% | 50.8% | +33 | +13 |
| claude-haiku-5-5-low | 8 | 37.5% | 45.6% | +22 | -3 |
| claude-sonnet-5-5 | 10 | 30.0% | 30.0% | +22 | +10 |
| claude-haiku-5-5 | 14 | 35.7% | 37.6% | +21 | +3 |
| gpt-6-astra-low | 12 | 58.3% | 55.4% | +18 | +38 |
| gpt-6.1-terra-off | 8 | 50.0% | 41.7% | +8 | -23 |
| claude-opus-5-5-low | 12 | 33.3% | 44.4% | -9 | +50 |
| gpt-6-luna-xhigh | 4 | 50.0% | 49.4% | -18 | -7 |
| claude-sonnet-5-5-low | 8 | 25.0% | 31.9% | -27 | -21 |
| gpt-6-luna-max | 2 | 50.0% | 66.7% | -38 | -13 |
| gpt-6.1-terra-high | 8 | 25.0% | 33.1% | -64 | -16 |
| claude-haiku-4-5-20251001 | 8 | 25.0% | 28.9% | -177 | -119 |
| gpt-6-luna | 10 | 10.0% | 20.2% | -252 | -151 |

### claude-haiku-4-5-20251001 efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 | 80 | 58.8% | 55.8% | -177 | -119 |
| claude-haiku-4-5-20251001-minimal | 80 | 57.5% | 51.2% | -202 | -142 |
| claude-haiku-4-5-20251001-low | 80 | 51.2% | 52.7% | -224 | -137 |
| claude-haiku-4-5-20251001-high | 80 | 53.8% | 52.4% | -247 | -149 |
| claude-haiku-4-5-20251001-off | 80 | 28.7% | 38.0% | -349 | -217 |

### gpt-5.6-terra efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-5.6-terra-xhigh | 80 | 60.0% | 56.1% | +13 | +35 |
| gpt-5.6-terra-max | 80 | 58.8% | 53.9% | +10 | +22 |
| gpt-5.6-terra | 80 | 45.0% | 45.0% | -51 | -20 |
| gpt-5.6-terra-high | 80 | 46.2% | 50.8% | -67 | +0 |
| gpt-5.6-terra-low | 80 | 40.0% | 44.2% | -86 | -23 |

### gpt-6.1-sol efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6.1-sol-max | 80 | 58.8% | 54.7% | +148 | +98 |
| gpt-6.1-sol-low | 80 | 48.8% | 48.7% | +93 | +62 |
| gpt-6.1-sol-xhigh | 80 | 48.8% | 49.8% | +87 | +68 |
| gpt-6.1-sol | 80 | 46.2% | 49.1% | +71 | +57 |
| gpt-6.1-sol-high | 80 | 47.5% | 47.7% | +63 | +43 |

### Tournament 9

100 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-haiku-5-5-high | 10 | 90.0% | 70.4% | +59 | +16 |
| claude-haiku-5-5-low | 30 | 86.7% | 73.1% | +22 | -3 |
| claude-haiku-5-5 | 10 | 80.0% | 83.8% | +21 | +3 |
| claude-haiku-5-5-off | 50 | 70.0% | 59.3% | -95 | -93 |
| claude-haiku-4-5-20251001 | 40 | 25.0% | 30.6% | -177 | -119 |
| claude-haiku-4-5-20251001-minimal | 20 | 15.0% | 33.6% | -202 | -142 |
| claude-haiku-4-5-20251001-low | 20 | 20.0% | 33.4% | -224 | -137 |
| claude-haiku-4-5-20251001-high | 10 | 20.0% | 40.0% | -247 | -149 |
| claude-haiku-4-5-20251001-off | 10 | 30.0% | 33.6% | -349 | -217 |

### Opus efforts (tournament 2)

80 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-opus-5-5-xhigh | 40 | 65.0% | 58.6% | +156 | +92 |
| claude-opus-5-5-high | 40 | 45.0% | 44.1% | +84 | +41 |
| claude-opus-5-5 | 60 | 48.3% | 48.1% | +83 | +46 |
| claude-opus-5-5-low | 20 | 35.0% | 50.2% | -9 | +50 |

### Tournament 7

73 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6.1-terra-max | 16 | 75.0% | 70.7% | +272 | +192 |
| claude-opus-5-5-xhigh | 1 | 100.0% | 64.4% | +156 | +92 |
| gpt-6-astra | 1 | 0.0% | 0.0% | +153 | +85 |
| gpt-6-astra-low-recall | 13 | 76.9% | 69.1% | +133 | +92 |
| claude-sonnet-5-5-xhigh | 3 | 33.3% | 22.2% | +117 | +55 |
| gpt-6-astra-high | 12 | 66.7% | 58.1% | +113 | +84 |
| claude-opus-5-5-off | 3 | 66.7% | 43.7% | +112 | +70 |
| claude-haiku-5-5-xhigh | 4 | 25.0% | 33.3% | +104 | +19 |
| gpt-6.1-sol-low | 2 | 100.0% | 65.6% | +93 | +62 |
| gpt-6.1-sol-xhigh | 1 | 0.0% | 33.3% | +87 | +68 |
| claude-opus-5-5-high | 4 | 50.0% | 51.1% | +84 | +41 |
| claude-opus-5-5 | 1 | 0.0% | 31.1% | +83 | +46 |
| gpt-6.1-terra-low | 9 | 55.6% | 48.9% | +81 | +37 |
| gpt-6.1-sol | 2 | 100.0% | 84.4% | +71 | +57 |
| claude-sonnet-5-5-high | 3 | 33.3% | 34.8% | +68 | +28 |
| gpt-6.1-sol-high | 1 | 0.0% | 31.1% | +63 | +43 |
| claude-haiku-5-5-high | 2 | 0.0% | 0.0% | +59 | +16 |
| gpt-6.1-terra-xhigh | 6 | 66.7% | 55.6% | +55 | +2 |
| claude-sonnet-5-5-off | 2 | 50.0% | 34.4% | +40 | +9 |
| claude-haiku-5-5-low | 2 | 50.0% | 66.7% | +22 | -3 |
| claude-sonnet-5-5 | 4 | 25.0% | 33.3% | +22 | +10 |
| claude-haiku-5-5 | 4 | 0.0% | 32.8% | +21 | +3 |
| gpt-6-astra-low | 7 | 14.3% | 38.4% | +18 | +38 |
| gpt-5.6-terra-xhigh | 3 | 66.7% | 67.4% | +13 | +35 |
| gpt-6.1-terra-off | 9 | 77.8% | 63.0% | +8 | -23 |
| claude-opus-5-5-low | 4 | 0.0% | 32.8% | -9 | +50 |
| gpt-6-luna-xhigh | 1 | 0.0% | 0.0% | -18 | -7 |
| claude-sonnet-5-5-low | 2 | 50.0% | 47.8% | -27 | -21 |
| gpt-5.6-terra | 3 | 0.0% | 22.2% | -51 | -20 |
| gpt-6.1-terra-high | 9 | 66.7% | 66.4% | -64 | -16 |
| gpt-5.6-terra-high | 1 | 0.0% | 35.6% | -67 | +0 |
| gpt-5.6-terra-low | 1 | 0.0% | 31.1% | -86 | -23 |
| gpt-6-luna-high | 2 | 50.0% | 51.1% | -94 | -65 |
| claude-haiku-5-5-off | 2 | 0.0% | 0.0% | -95 | -93 |
| claude-haiku-4-5-20251001 | 1 | 0.0% | 0.0% | -177 | -119 |
| claude-haiku-4-5-20251001-minimal | 1 | 100.0% | 66.7% | -202 | -142 |
| claude-haiku-4-5-20251001-low | 2 | 0.0% | 17.8% | -224 | -137 |
| claude-haiku-4-5-20251001-high | 2 | 0.0% | 16.7% | -247 | -149 |

### Tournament 6

37 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6-astra-low-recall | 7 | 42.9% | 47.0% | +133 | +92 |
| claude-sonnet-5-5-xhigh | 1 | 100.0% | 66.7% | +117 | +55 |
| claude-opus-5-5-off | 11 | 54.5% | 51.7% | +112 | +70 |
| claude-haiku-5-5-xhigh | 2 | 50.0% | 51.1% | +104 | +19 |
| claude-haiku-5-5-max | 1 | 100.0% | 66.7% | +100 | +50 |
| claude-opus-5-5-high | 1 | 0.0% | 33.3% | +84 | +41 |
| claude-opus-5-5 | 2 | 100.0% | 66.7% | +83 | +46 |
| gpt-6.1-terra-low | 3 | 33.3% | 44.4% | +81 | +37 |
| gpt-6.1-sol | 1 | 100.0% | 64.4% | +71 | +57 |
| claude-sonnet-5-5-high | 2 | 0.0% | 32.2% | +68 | +28 |
| claude-haiku-5-5-high | 2 | 100.0% | 100.0% | +59 | +16 |
| gpt-6.1-terra-xhigh | 4 | 50.0% | 41.1% | +55 | +2 |
| claude-sonnet-5-5-off | 1 | 100.0% | 100.0% | +40 | +9 |
| gpt-6.1-terra | 1 | 0.0% | 0.0% | +33 | +13 |
| claude-haiku-5-5-low | 3 | 33.3% | 45.9% | +22 | -3 |
| claude-sonnet-5-5 | 2 | 50.0% | 51.1% | +22 | +10 |
| claude-haiku-5-5 | 5 | 100.0% | 73.8% | +21 | +3 |
| gpt-6-astra-low | 1 | 100.0% | 68.9% | +18 | +38 |
| gpt-6.1-terra-off | 3 | 0.0% | 33.3% | +8 | -23 |
| claude-opus-5-5-low | 2 | 100.0% | 65.6% | -9 | +50 |
| claude-sonnet-5-5-low | 1 | 100.0% | 66.7% | -27 | -21 |
| gpt-6.1-terra-high | 3 | 33.3% | 55.6% | -64 | -16 |
| claude-haiku-5-5-off | 3 | 66.7% | 56.3% | -95 | -93 |
| claude-haiku-4-5-20251001 | 3 | 0.0% | 22.2% | -177 | -119 |
| claude-haiku-4-5-20251001-minimal | 1 | 0.0% | 31.1% | -202 | -142 |
| claude-haiku-4-5-20251001-low | 3 | 66.7% | 54.1% | -224 | -137 |
| claude-haiku-4-5-20251001-high | 4 | 0.0% | 16.7% | -247 | -149 |
| claude-haiku-4-5-20251001-off | 1 | 0.0% | 35.6% | -349 | -217 |
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

Only three pairings played 5 seeds in both seats (10 matches): Opus max against low, medium and xhigh. The top-four round robin also plays 5 seeds per pair. Everything else is one seed in both seats (2 matches per pairing), so a single pairing says very little. Counts below are from tournament 5 alone. With tournaments 7 and 9 added, no config in this list is under 20 matches in total: Opus off has 26, Astra low and high 20 each, Terra 6.1 medium 21 and its other efforts 20 each. Ratings are the pooled ones of the 2026-11-04 snapshot.

- **Opus max:** 24 wins in 40 matches (60%), pooled rating +144 (95% interval +35 to +267). Before this tournament it had 8 matches and +334, so that was a small-sample high.
  - Against its own efforts, 5 seeds in both seats: 7-3 against low, 6-4 against medium, 5-5 against xhigh. The 95% intervals on those shares span 60 to 70 points (20% to 80% for xhigh), so none is settled.
  - Against Sonnet, Haiku 5.5, Astra, Sol and Terra 6.1 at medium, one seed each: 6 wins in 10.
  - On the pooled scale it sits with Opus xhigh (+156) and above medium (+83), high (+84) and low (-9).
- **Terra 6.1:** results at all six efforts, no trend. Medium has 21 matches, 10 wins, +33 (-89 to +146). The others, with tournament-5 wins and the pooled rating: off 4 of 8 (+8), low 5 of 8 (+81), high 2 of 8 (-64), xhigh 4 of 10 (+55), max 3 of 4 (+272, +123 to +511 over 20 matches).
  - Against each other: low beat off 2-0, xhigh beat high 2-0, max beat xhigh 2-0, medium beat xhigh 2-0, and medium split 1-1 with off, low and high.
  - Terra 6.1 medium (+33) is above Terra 5.6 medium (-51), on 21 matches against 259.
- **Opus off:** 7 wins in 12 matches (58%) here; 15 of 26 overall (58%), +112 (-4 to +239). It split 1-1 with Opus low, medium, high, Haiku 5.5 medium and Luna xhigh, and beat Sonnet off 2-0. That is level with Opus medium and high (+83, +84); the interval is still wide.
- **Astra low and high:** low won 7 of 12 here (+18 pooled, -138 to +146), high won 3 of 8 (+113, -34 to +283), against Astra medium at +153 (254 matches).
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

  Sonnet max won 8 of 10 against Opus xhigh (over complete seed pairs, 95% interval 60% to 100%). The pooled ratings are Sonnet max +190, Astra +153, Opus xhigh +156, Sol max +148. Opus xhigh was +180 before tournament 5, Sonnet max +160.

The regret and patterns pages in [analysis/](analysis/) have not been rebuilt for these matches. The viewer has no move-quality data for them, which must not be read as zero mistakes.

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
