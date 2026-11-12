# Arena results

This page summarizes the finished tournaments and the findings about model reasoning. The raw data isn't committed. See [README.md](README.md) for how to run and resume. All costs are list-price costs: list prices applied to usage on subscription plans, not money paid.

The rating is the luck-adjusted Round Elo: a Bradley-Terry fit that counts each round as a game, with the luck of each round's chance events taken out ([ADR-0058](../adr/0058-luck-adjusted-elo.md)), over every scored match of every tournament. It is on an Elo scale with the depth-2 search engine (Engine/2/20000) at 0, per configuration (model + endpoint + effort), so one scale covers every config. The match rating, a fit on match results, is about 1.6 times as wide and carries the same signal with more noise; [matchups.md](analysis/matchups.md) keeps it with the 95% intervals and the luck adjustment's method. Most pairings play 10 seeds in both seat orders, 20 matches. Tournaments 6, 7 and 8 play one match per seed, with no seat swap. With 10 seeds, close rankings aren't reliable. "Medium" also isn't equal compute across providers.

## Leaderboard
One table per cohort, ranked by the pooled Round Elo. Matches, win share and pot share count the cohort's own games; ratings come from the one pooled fit, so a config has the same rating in every table. Sonnet max has 2 games in tournament 1's cross-model cohort (it lost both to Opus), so its rating there rests on its tournament-4 games. Tournament 5's 214 matches are one table of their own. Most of its configs had 2 to 12 matches against different opponents there, so their ratings rest mostly on the prior and later tournaments, not on that record. A config with fewer than 20 matches in total is provisional, as in the viewer. `python3 tools/arena/analysis/leaderboard.py --doc docs/arena/results.md` rewrites the tables.

<!-- leaderboard:start -->
Scope: 3,789 scored matches of tournaments 1 to 12.

### All configs

3789 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| gpt-6.1-terra-max | 100 | 68.0% | 62.4% | +133 |
| claude-sonnet-5-5-max | 140 | 67.1% | 62.3% | +133 |
| claude-opus-5-5-max | 80 | 73.8% | 64.4% | +112 |
| claude-opus-5-5-xhigh | 170 | 52.4% | 52.4% | +110 |
| Engine/6/20000/sampled | 156 | 55.1% | 53.4% | +109 |
| gpt-6-astra-high | 100 | 68.0% | 64.0% | +102 |
| gpt-6.1-sol-max | 142 | 56.3% | 54.5% | +98 |
| gpt-6-astra-medium | 254 | 66.5% | 60.2% | +88 |
| gpt-6.1-sol-xhigh | 101 | 51.5% | 52.4% | +76 |
| gpt-6-astra-low | 80 | 65.0% | 59.4% | +70 |
| claude-sonnet-5-5-xhigh | 176 | 59.7% | 53.7% | +69 |
| gpt-6-astra-off | 80 | 63.7% | 55.9% | +66 |
| gpt-6.1-terra-xhigh | 80 | 70.0% | 59.7% | +66 |
| claude-opus-5-5-high | 80 | 58.8% | 54.7% | +65 |
| gpt-6.1-sol-low | 98 | 52.0% | 50.9% | +65 |
| claude-opus-5-5-off | 80 | 62.5% | 58.8% | +62 |
| gpt-6.1-terra-high | 80 | 63.7% | 59.7% | +61 |
| claude-haiku-5-5-max | 111 | 61.3% | 58.7% | +61 |
| claude-opus-5-5-medium | 334 | 56.3% | 53.8% | +59 |
| gpt-6.1-sol-medium | 271 | 57.2% | 56.8% | +57 |
| gpt-5.6-terra-max | 90 | 57.8% | 53.8% | +53 |
| gpt-6.1-terra-medium | 80 | 62.5% | 57.7% | +49 |
| claude-opus-5-5-low | 80 | 41.2% | 49.4% | +46 |
| gpt-5.6-terra-xhigh | 93 | 57.0% | 55.1% | +45 |
| gpt-6.1-sol-high | 99 | 47.5% | 48.0% | +44 |
| claude-haiku-5-5-xhigh | 158 | 54.4% | 50.4% | +34 |
| gpt-6.1-terra-low | 80 | 56.2% | 55.5% | +29 |
| gpt-6.1-terra-off | 80 | 65.0% | 56.9% | +24 |
| claude-sonnet-5-5-medium | 364 | 48.1% | 48.8% | +20 |
| claude-sonnet-5-5-high | 161 | 46.6% | 46.9% | +20 |
| gpt-5.6-terra-high | 91 | 44.0% | 49.5% | +15 |
| claude-haiku-5-5-high | 173 | 51.4% | 50.3% | +11 |
| claude-haiku-5-5-medium | 382 | 50.5% | 50.3% | +5 |
| Engine/2/20000 | 96 | 50.0% | 50.4% | +0 |
| gpt-5.6-terra-medium | 259 | 45.9% | 48.0% | +0 |
| gpt-5.6-terra-low | 91 | 40.7% | 45.5% | -2 |
| claude-haiku-5-5-low | 194 | 50.5% | 51.3% | -3 |
| claude-sonnet-5-5-low | 159 | 31.4% | 39.5% | -10 |
| gpt-6-luna-max | 112 | 67.0% | 63.2% | -18 |
| claude-sonnet-5-5-off | 164 | 39.6% | 42.4% | -19 |
| gpt-6-luna-xhigh | 115 | 68.7% | 63.6% | -25 |
| gpt-6-luna-high | 112 | 59.8% | 55.5% | -60 |
| claude-haiku-5-5-off | 220 | 36.8% | 39.9% | -90 |
| claude-haiku-4-5-20251001-medium | 358 | 34.4% | 38.6% | -120 |
| claude-haiku-4-5-20251001-high | 135 | 34.8% | 42.0% | -135 |
| claude-haiku-4-5-20251001-low | 149 | 36.9% | 41.9% | -137 |
| gpt-6-luna-medium | 282 | 26.2% | 34.1% | -138 |
| claude-haiku-4-5-20251001-minimal | 143 | 39.9% | 42.5% | -145 |
| gpt-6-luna-off | 110 | 26.4% | 33.8% | -175 |
| claude-haiku-4-5-20251001-off | 125 | 22.4% | 32.6% | -194 |
| gpt-6-luna-low | 110 | 25.5% | 31.4% | -206 |

### Tournament 8

642 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| gpt-6.1-terra-max | 60 | 71.7% | 64.7% | +133 |
| claude-opus-5-5-max | 40 | 87.5% | 73.8% | +112 |
| claude-opus-5-5-xhigh | 38 | 57.9% | 56.2% | +110 |
| gpt-6-astra-high | 60 | 76.7% | 69.8% | +102 |
| gpt-6-astra-low | 60 | 71.7% | 62.6% | +70 |
| claude-sonnet-5-5-xhigh | 38 | 63.2% | 56.0% | +69 |
| gpt-6-astra-off | 60 | 63.3% | 54.1% | +66 |
| gpt-6.1-terra-xhigh | 60 | 76.7% | 64.7% | +66 |
| claude-opus-5-5-high | 23 | 87.0% | 73.0% | +65 |
| claude-opus-5-5-off | 54 | 64.8% | 60.6% | +62 |
| gpt-6.1-terra-high | 60 | 70.0% | 62.4% | +61 |
| claude-opus-5-5-medium | 25 | 44.0% | 49.6% | +59 |
| gpt-6.1-terra-medium | 59 | 67.8% | 61.1% | +49 |
| claude-opus-5-5-low | 32 | 43.8% | 46.5% | +46 |
| claude-haiku-5-5-xhigh | 42 | 35.7% | 42.5% | +34 |
| gpt-6.1-terra-low | 60 | 56.7% | 56.7% | +29 |
| gpt-6.1-terra-off | 60 | 68.3% | 59.2% | +24 |
| claude-sonnet-5-5-medium | 32 | 37.5% | 40.0% | +20 |
| claude-sonnet-5-5-high | 38 | 31.6% | 37.7% | +20 |
| claude-haiku-5-5-high | 43 | 37.2% | 39.4% | +11 |
| claude-haiku-5-5-medium | 31 | 25.8% | 35.7% | +5 |
| claude-haiku-5-5-low | 41 | 34.1% | 42.7% | -3 |
| claude-sonnet-5-5-low | 38 | 15.8% | 31.5% | -10 |
| claude-sonnet-5-5-off | 43 | 18.6% | 29.6% | -19 |
| claude-haiku-5-5-off | 37 | 10.8% | 26.5% | -90 |
| claude-haiku-4-5-20251001-medium | 32 | 12.5% | 26.0% | -120 |
| claude-haiku-4-5-20251001-high | 29 | 6.9% | 25.1% | -135 |
| claude-haiku-4-5-20251001-low | 34 | 11.8% | 22.5% | -137 |
| claude-haiku-4-5-20251001-minimal | 31 | 9.7% | 26.2% | -145 |
| claude-haiku-4-5-20251001-off | 24 | 0.0% | 17.8% | -194 |

### Cross-model games (tournament 1)

562 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| claude-sonnet-5-5-max | 2 | 0.0% | 34.4% | +133 |
| gpt-6-astra-medium | 140 | 72.1% | 63.3% | +88 |
| claude-opus-5-5-medium | 142 | 62.7% | 58.2% | +59 |
| gpt-6.1-sol-medium | 140 | 59.3% | 58.2% | +57 |
| claude-sonnet-5-5-medium | 140 | 55.0% | 54.2% | +20 |
| claude-haiku-5-5-medium | 140 | 57.9% | 53.7% | +5 |
| gpt-5.6-terra-medium | 140 | 45.7% | 48.3% | +0 |
| claude-haiku-4-5-20251001-medium | 140 | 30.0% | 35.7% | -120 |
| gpt-6-luna-medium | 140 | 17.9% | 28.5% | -138 |

### claude-haiku-5-5 efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| claude-haiku-5-5-max | 100 | 60.0% | 57.8% | +61 |
| claude-haiku-5-5-xhigh | 100 | 65.0% | 55.0% | +34 |
| claude-haiku-5-5-high | 100 | 54.0% | 53.6% | +11 |
| claude-haiku-5-5-medium | 100 | 45.0% | 49.5% | +5 |
| claude-haiku-5-5-low | 100 | 45.0% | 47.8% | -3 |
| claude-haiku-5-5-off | 100 | 31.0% | 36.2% | -90 |

### claude-sonnet-5-5 efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| claude-sonnet-5-5-max | 100 | 68.0% | 63.4% | +133 |
| claude-sonnet-5-5-xhigh | 100 | 58.0% | 52.9% | +69 |
| claude-sonnet-5-5-medium | 100 | 45.0% | 47.6% | +20 |
| claude-sonnet-5-5-high | 100 | 51.0% | 49.2% | +20 |
| claude-sonnet-5-5-low | 100 | 35.0% | 42.0% | -10 |
| claude-sonnet-5-5-off | 100 | 43.0% | 44.9% | -19 |

### gpt-6-luna efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| gpt-6-luna-max | 100 | 72.0% | 66.1% | -18 |
| gpt-6-luna-xhigh | 100 | 72.0% | 66.0% | -25 |
| gpt-6-luna-high | 100 | 62.0% | 56.8% | -60 |
| gpt-6-luna-medium | 100 | 39.0% | 42.7% | -138 |
| gpt-6-luna-off | 100 | 28.0% | 35.4% | -175 |
| gpt-6-luna-low | 100 | 27.0% | 32.9% | -206 |

### Tournament 5

214 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| gpt-6.1-terra-max | 4 | 75.0% | 66.1% | +133 |
| claude-sonnet-5-5-max | 30 | 60.0% | 54.7% | +133 |
| claude-opus-5-5-max | 40 | 60.0% | 55.0% | +112 |
| claude-opus-5-5-xhigh | 30 | 36.7% | 45.7% | +110 |
| gpt-6-astra-high | 8 | 37.5% | 50.6% | +102 |
| gpt-6.1-sol-max | 32 | 46.9% | 49.7% | +98 |
| gpt-6-astra-medium | 34 | 58.8% | 55.0% | +88 |
| gpt-6.1-sol-xhigh | 10 | 60.0% | 60.4% | +76 |
| gpt-6-astra-low | 12 | 58.3% | 55.4% | +70 |
| claude-sonnet-5-5-xhigh | 8 | 87.5% | 83.3% | +69 |
| gpt-6.1-terra-xhigh | 10 | 40.0% | 40.0% | +66 |
| claude-opus-5-5-high | 2 | 50.0% | 33.3% | +65 |
| gpt-6.1-sol-low | 6 | 66.7% | 61.1% | +65 |
| claude-opus-5-5-off | 12 | 58.3% | 61.1% | +62 |
| gpt-6.1-terra-high | 8 | 25.0% | 33.1% | +61 |
| claude-opus-5-5-medium | 28 | 57.1% | 51.1% | +59 |
| gpt-6.1-sol-medium | 12 | 58.3% | 61.1% | +57 |
| gpt-6.1-terra-medium | 20 | 50.0% | 50.8% | +49 |
| claude-opus-5-5-low | 12 | 33.3% | 44.4% | +46 |
| gpt-6.1-sol-high | 8 | 37.5% | 42.8% | +44 |
| gpt-6.1-terra-low | 8 | 62.5% | 58.6% | +29 |
| gpt-6.1-terra-off | 8 | 50.0% | 41.7% | +24 |
| claude-sonnet-5-5-medium | 10 | 30.0% | 30.0% | +20 |
| claude-sonnet-5-5-high | 8 | 62.5% | 53.6% | +20 |
| claude-haiku-5-5-high | 6 | 66.7% | 54.8% | +11 |
| claude-haiku-5-5-medium | 14 | 35.7% | 37.6% | +5 |
| claude-haiku-5-5-low | 8 | 37.5% | 45.6% | -3 |
| claude-sonnet-5-5-low | 8 | 25.0% | 31.9% | -10 |
| gpt-6-luna-max | 2 | 50.0% | 66.7% | -18 |
| claude-sonnet-5-5-off | 8 | 62.5% | 57.8% | -19 |
| gpt-6-luna-xhigh | 4 | 50.0% | 49.4% | -25 |
| claude-haiku-4-5-20251001-medium | 8 | 25.0% | 28.9% | -120 |
| gpt-6-luna-medium | 10 | 10.0% | 20.2% | -138 |

### claude-haiku-4-5-20251001 efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001-medium | 80 | 58.8% | 55.8% | -120 |
| claude-haiku-4-5-20251001-high | 80 | 53.8% | 52.4% | -135 |
| claude-haiku-4-5-20251001-low | 80 | 51.2% | 52.7% | -137 |
| claude-haiku-4-5-20251001-minimal | 80 | 57.5% | 51.2% | -145 |
| claude-haiku-4-5-20251001-off | 80 | 28.7% | 38.0% | -194 |

### gpt-5.6-terra efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| gpt-5.6-terra-max | 80 | 58.8% | 53.9% | +53 |
| gpt-5.6-terra-xhigh | 80 | 60.0% | 56.1% | +45 |
| gpt-5.6-terra-high | 80 | 46.2% | 50.8% | +15 |
| gpt-5.6-terra-medium | 80 | 45.0% | 45.0% | +0 |
| gpt-5.6-terra-low | 80 | 40.0% | 44.2% | -2 |

### gpt-6.1-sol efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| gpt-6.1-sol-max | 80 | 58.8% | 54.7% | +98 |
| gpt-6.1-sol-xhigh | 80 | 48.8% | 49.8% | +76 |
| gpt-6.1-sol-low | 80 | 48.8% | 48.7% | +65 |
| gpt-6.1-sol-medium | 80 | 46.2% | 49.1% | +57 |
| gpt-6.1-sol-high | 80 | 47.5% | 47.7% | +44 |

### Tournament 10

120 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| Engine/6/20000/sampled | 60 | 61.7% | 57.4% | +109 |
| claude-opus-5-5-medium | 40 | 47.5% | 50.4% | +59 |
| claude-sonnet-5-5-medium | 40 | 40.0% | 43.5% | +20 |
| claude-haiku-5-5-medium | 40 | 52.5% | 50.8% | +5 |
| Engine/2/20000 | 60 | 45.0% | 46.2% | +0 |

### Tournament 9

100 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| claude-haiku-5-5-high | 10 | 90.0% | 70.4% | +11 |
| claude-haiku-5-5-medium | 10 | 80.0% | 83.8% | +5 |
| claude-haiku-5-5-low | 30 | 86.7% | 73.1% | -3 |
| claude-haiku-5-5-off | 50 | 70.0% | 59.3% | -90 |
| claude-haiku-4-5-20251001-medium | 40 | 25.0% | 30.6% | -120 |
| claude-haiku-4-5-20251001-high | 10 | 20.0% | 40.0% | -135 |
| claude-haiku-4-5-20251001-low | 20 | 20.0% | 33.4% | -137 |
| claude-haiku-4-5-20251001-minimal | 20 | 15.0% | 33.6% | -145 |
| claude-haiku-4-5-20251001-off | 10 | 30.0% | 33.6% | -194 |

### Opus efforts (tournament 2)

80 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| claude-opus-5-5-xhigh | 40 | 65.0% | 58.6% | +110 |
| claude-opus-5-5-high | 40 | 45.0% | 44.1% | +65 |
| claude-opus-5-5-medium | 60 | 48.3% | 48.1% | +59 |
| claude-opus-5-5-low | 20 | 35.0% | 50.2% | +46 |

### Tournament 12

80 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| gpt-6.1-terra-max | 20 | 50.0% | 48.3% | +133 |
| claude-opus-5-5-xhigh | 20 | 35.0% | 45.3% | +110 |
| Engine/6/20000/sampled | 80 | 52.5% | 49.8% | +109 |
| gpt-6-astra-high | 20 | 55.0% | 55.3% | +102 |
| gpt-6.1-sol-max | 20 | 50.0% | 51.8% | +98 |

### Tournament 7

73 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| gpt-6.1-terra-max | 16 | 75.0% | 70.7% | +133 |
| claude-opus-5-5-xhigh | 1 | 100.0% | 64.4% | +110 |
| gpt-6-astra-high | 12 | 66.7% | 58.1% | +102 |
| gpt-6-astra-medium | 1 | 0.0% | 0.0% | +88 |
| gpt-6.1-sol-xhigh | 1 | 0.0% | 33.3% | +76 |
| gpt-6-astra-low | 7 | 14.3% | 38.4% | +70 |
| claude-sonnet-5-5-xhigh | 3 | 33.3% | 22.2% | +69 |
| gpt-6-astra-off | 13 | 76.9% | 69.1% | +66 |
| gpt-6.1-terra-xhigh | 6 | 66.7% | 55.6% | +66 |
| claude-opus-5-5-high | 4 | 50.0% | 51.1% | +65 |
| gpt-6.1-sol-low | 2 | 100.0% | 65.6% | +65 |
| claude-opus-5-5-off | 3 | 66.7% | 43.7% | +62 |
| gpt-6.1-terra-high | 9 | 66.7% | 66.4% | +61 |
| claude-opus-5-5-medium | 1 | 0.0% | 31.1% | +59 |
| gpt-6.1-sol-medium | 2 | 100.0% | 84.4% | +57 |
| claude-opus-5-5-low | 4 | 0.0% | 32.8% | +46 |
| gpt-5.6-terra-xhigh | 3 | 66.7% | 67.4% | +45 |
| gpt-6.1-sol-high | 1 | 0.0% | 31.1% | +44 |
| claude-haiku-5-5-xhigh | 4 | 25.0% | 33.3% | +34 |
| gpt-6.1-terra-low | 9 | 55.6% | 48.9% | +29 |
| gpt-6.1-terra-off | 9 | 77.8% | 63.0% | +24 |
| claude-sonnet-5-5-medium | 4 | 25.0% | 33.3% | +20 |
| claude-sonnet-5-5-high | 3 | 33.3% | 34.8% | +20 |
| gpt-5.6-terra-high | 1 | 0.0% | 35.6% | +15 |
| claude-haiku-5-5-high | 2 | 0.0% | 0.0% | +11 |
| claude-haiku-5-5-medium | 4 | 0.0% | 32.8% | +5 |
| gpt-5.6-terra-medium | 3 | 0.0% | 22.2% | +0 |
| gpt-5.6-terra-low | 1 | 0.0% | 31.1% | -2 |
| claude-haiku-5-5-low | 2 | 50.0% | 66.7% | -3 |
| claude-sonnet-5-5-low | 2 | 50.0% | 47.8% | -10 |
| claude-sonnet-5-5-off | 2 | 50.0% | 34.4% | -19 |
| gpt-6-luna-xhigh | 1 | 0.0% | 0.0% | -25 |
| gpt-6-luna-high | 2 | 50.0% | 51.1% | -60 |
| claude-haiku-5-5-off | 2 | 0.0% | 0.0% | -90 |
| claude-haiku-4-5-20251001-medium | 1 | 0.0% | 0.0% | -120 |
| claude-haiku-4-5-20251001-high | 2 | 0.0% | 16.7% | -135 |
| claude-haiku-4-5-20251001-low | 2 | 0.0% | 17.8% | -137 |
| claude-haiku-4-5-20251001-minimal | 1 | 100.0% | 66.7% | -145 |

### Tournament 11

52 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| Engine/6/20000/sampled | 16 | 43.8% | 56.4% | +109 |
| claude-sonnet-5-5-xhigh | 16 | 56.2% | 43.6% | +69 |
| Engine/2/20000 | 36 | 58.3% | 57.3% | +0 |
| claude-haiku-5-5-off | 18 | 33.3% | 40.7% | -90 |
| claude-haiku-4-5-20251001-medium | 18 | 50.0% | 44.6% | -120 |

### Tournament 6

37 scored matches.

| config | matches | win share | pot share | Round Elo (luck-adjusted) |
|---|---|---|---|---|
| gpt-6-astra-low | 1 | 100.0% | 68.9% | +70 |
| claude-sonnet-5-5-xhigh | 1 | 100.0% | 66.7% | +69 |
| gpt-6-astra-off | 7 | 42.9% | 47.0% | +66 |
| gpt-6.1-terra-xhigh | 4 | 50.0% | 41.1% | +66 |
| claude-opus-5-5-high | 1 | 0.0% | 33.3% | +65 |
| claude-opus-5-5-off | 11 | 54.5% | 51.7% | +62 |
| gpt-6.1-terra-high | 3 | 33.3% | 55.6% | +61 |
| claude-haiku-5-5-max | 1 | 100.0% | 66.7% | +61 |
| claude-opus-5-5-medium | 2 | 100.0% | 66.7% | +59 |
| gpt-6.1-sol-medium | 1 | 100.0% | 64.4% | +57 |
| gpt-6.1-terra-medium | 1 | 0.0% | 0.0% | +49 |
| claude-opus-5-5-low | 2 | 100.0% | 65.6% | +46 |
| claude-haiku-5-5-xhigh | 2 | 50.0% | 51.1% | +34 |
| gpt-6.1-terra-low | 3 | 33.3% | 44.4% | +29 |
| gpt-6.1-terra-off | 3 | 0.0% | 33.3% | +24 |
| claude-sonnet-5-5-medium | 2 | 50.0% | 51.1% | +20 |
| claude-sonnet-5-5-high | 2 | 0.0% | 32.2% | +20 |
| claude-haiku-5-5-high | 2 | 100.0% | 100.0% | +11 |
| claude-haiku-5-5-medium | 5 | 100.0% | 73.8% | +5 |
| claude-haiku-5-5-low | 3 | 33.3% | 45.9% | -3 |
| claude-sonnet-5-5-low | 1 | 100.0% | 66.7% | -10 |
| claude-sonnet-5-5-off | 1 | 100.0% | 100.0% | -19 |
| claude-haiku-5-5-off | 3 | 66.7% | 56.3% | -90 |
| claude-haiku-4-5-20251001-medium | 3 | 0.0% | 22.2% | -120 |
| claude-haiku-4-5-20251001-high | 4 | 0.0% | 16.7% | -135 |
| claude-haiku-4-5-20251001-low | 3 | 66.7% | 54.1% | -137 |
| claude-haiku-4-5-20251001-minimal | 1 | 0.0% | 31.1% | -145 |
| claude-haiku-4-5-20251001-off | 1 | 0.0% | 35.6% | -194 |
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

## tournament-2: Opus 5.5 effort
80 matches, list-price cost $58.89. Each new level plays medium and its neighbouring level: low–medium, medium–high, medium–xhigh, high–xhigh.

Ratings are in the leaderboard above.

Head to head:
- medium beat low 65–35;
- high beat medium 55–45;
- xhigh beat medium 65–35;
- xhigh beat high 65–35.

## tournament-3: Opus 5.5 xhigh vs Astra medium (finished, 41 matches)
- **Seeds:** fixed in advance. First 3000–3009, which are tournament-1's Opus medium vs Astra seeds, for a matched comparison. Then 3020–3029. Capped at 40 matches; the one finished match past the cap also counts.

**Results (20 complete seed pairs plus seed 3030's first match):**
- **Overall:** Opus xhigh 22, Astra 19. Opus share 53.7%, 95% CI 38.1–69.0% (seed bootstrap over 21 seeds). On the 20 complete pairs alone it was 22–18, 55.0%, CI 40.0–70.0%.
- **Per seed:** Opus won both games on 6 seeds, Astra on 4, and 10 split. Astra won seed 3030's only game. Seat 2 won 17 of 41.
- **Matched against Opus medium** on seeds 3000–3009: 10/20 vs 9/20, a difference of +5%, 95% CI −15% to +25%.
- **Verdict:** inconclusive. The data rules out neither model being somewhat stronger, and xhigh shows no measurable gain over medium against Astra.
- **List-price cost:** $41.11: Opus $29.75, Astra $11.36. Astra reports few reasoning tokens at medium: about 3k over 1,077 calls.

**Outside the cap.** A brief uncapped run started 6 matches (seeds 3030–3032). Seed 3030's first match finished and is scored above. The other 5 never finished, are not scored, and have a list-price cost of $1.38 together. They stay in the tournament directory, unfinished.

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

214 scored matches in 11 phases, $353.50 of list-price usage (every call priced). The database total is now $1,557.95. Seeds are 4000 to 4061, which no earlier tournament played, so there is no matched-seed comparison with tournaments 1 to 4. The matched-seed tool (`tools/arena/seed_pairs.py`) was used within the tournament. The ratings quoted in this section are the luck-adjusted Round Elo of the leaderboard above (depth-2 engine at 0); the match ratings with their intervals are in [matchups.md](analysis/matchups.md).

Only three pairings played 5 seeds in both seats (10 matches): Opus max against low, medium and xhigh. The top-four round robin also plays 5 seeds per pair. Everything else is one seed in both seats (2 matches per pairing), so a single pairing says very little. Counts below are from tournament 5 alone. With tournaments 7, 8 and 9 added, Opus off, Astra low and high, and every Terra 6.1 effort have 80 matches each. Ratings are over all tournaments.

- **Opus max:** 24 wins in 40 matches (60%) here; 59 of 80 overall (73.8%), Round Elo +125, third in the all-configs table after Terra 6.1 max (+140) and Sonnet max (+130).
  - Against its own efforts, 5 seeds in both seats: 7-3 against low, 6-4 against medium, 5-5 against xhigh. The 95% intervals on those shares span 60 to 70 points (20% to 80% for xhigh), so none is settled.
  - Against Sonnet, Haiku 5.5, Astra, Sol and Terra 6.1 at medium, one seed each: 6 wins in 10.
  - On the same scale Opus xhigh is +112, high +82, medium +61 and low +41.
- **Terra 6.1:** results at all six efforts. Medium has 80 matches overall, 50 wins, +51. The others, with tournament-5 wins and the rating over 80 matches: off 4 of 8 (+25), low 5 of 8 (+27), high 2 of 8 (+67), xhigh 4 of 10 (+68), max 3 of 4 (+140). Max is first in the all-configs table.
  - Against each other: low beat off 2-0, xhigh beat high 2-0, max beat xhigh 2-0, medium beat xhigh 2-0, and medium split 1-1 with off, low and high.
  - Terra 6.1 medium (+51) is above Terra 5.6 medium (-6), on 80 matches against 259.
- **Opus off:** 7 wins in 12 matches (58%) here; 50 of 80 overall (62.5%), +67. It split 1-1 with Opus low, medium, high, Haiku 5.5 medium and Luna xhigh, and beat Sonnet off 2-0. That is above Opus medium (+61) and below high (+82); the match-rating intervals overlap.
- **Astra low and high:** low won 7 of 12 here (+81 over 80 matches), high won 3 of 8 (+118 over 80), against Astra medium at +87 (254 matches).
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

  Sonnet max won 8 of 10 against Opus xhigh (over complete seed pairs, 95% interval 60% to 100%). The Round Elos are Sonnet max +130, Opus xhigh +112, Sol max +109 and Astra +87.

## Tournament 8 (finished 2026-11-04)

642 scored matches, $373.87 of list-price usage. Nine GPT configs (Terra 6.1 at all six efforts, Astra off, low and high) and Opus off and max played the Claude configs at every effort, about 3 matches against each. It gave the new configs 60 matches each against a spread of opponents, to bring them to 80 with tournaments 5, 7 and 9. Seeds are 5000 to 7302, one match per seed and no seat swap. The tournament scheduled the swapped half of each match too (another 642), and they never started. So every match here is unpaired, and the seat that opens round 1 is not balanced by design. Ratings are the pooled ones in the leaderboard.

## Tournament 10 (finished 2026-11-09)

120 matches, $13.75 of list-price usage. It put the two search-engine configs, `Engine/2/20000` (depth 2) and `Engine/6/20000/sampled` (depth 6, sampled reload), against Haiku 5.5, Sonnet 5.5 and Opus 5.5, all at medium. Each of the six pairings plays 10 seeds (3000 to 3018) in both seat orders, 20 matches. The engines are reference points for the models (see [ADR-0059](../adr/0059-engine-anchors.md)).

Match wins, engine first:
- Engine depth 6: 10-10 against Haiku, 13-7 against Opus, 14-6 against Sonnet;
- Engine depth 2: 9-11 against Haiku, 8-12 against Opus, 10-10 against Sonnet.

## Tournament 11 (2026-11-09)

52 scored matches, $10.87 of list-price usage. Of 200 scheduled matches, 2 more were partly played and 146 never started. Same seeds and both seat orders as tournament 10. It gave the engines opponents outside tournament 10: Engine depth 2 against Haiku 4.5 medium (9-9) and Haiku 5.5 off (12-6), and Engine depth 6 against Sonnet 5.5 xhigh (7-9).

## Tournament 12 (2026-11-11)

80 matches, $26.22 of list-price usage. The depth-6 anchor, `Engine/6/20000/sampled`, against four top configs it had never met: Terra 6.1 max, Astra high, Sol max and Opus xhigh. Each pairing plays 10 fresh seeds (12000 to 12039, one per pairing and block) in both seat orders, 20 matches.

Match wins, engine first: 10-10 against Terra max, 9-11 against Astra high, 10-10 against Sol max, 13-7 against Opus xhigh. The anchor's luck-adjusted Round Elo moves from +74 to +109, now from 156 matches against eight opponents.

## Beliefs and items
What each model knew about the chamber when it shot, whether it acted on it, what became of its items, and how consistently it chose in repeated positions: [analysis/beliefs-and-items.md](analysis/beliefs-and-items.md).

## Other analyses
- **Matchups:** ratings within each cohort, no matchup effects, seat and round-1 starter effects: [analysis/matchups.md](analysis/matchups.md).
- **Patterns against regret:** the mean regret of single-move choice patterns: [analysis/patterns.md](analysis/patterns.md).


## Reasoning findings
- **GPT reasoning summaries are short upstream.** Nothing is lost in the proxy, pi-ai or the arena.
  - A census of 50,904 saved calls and 36 raw streaming probes showed every summary delta equals the final item; there's no raw reasoning text.
  - Direct requests to the Codex backend without the proxy return the same thing: headings for luna, terra and astra; rare prose or nothing for sol.
  - Keep `summary: "detailed"`. Omitting it returns no text; `auto` is echoed as `detailed`; `concise` gave sol headings where `detailed` gave none, but sol's `detailed` sometimes returns real prose.
  - The public OpenAI API can't be tested with the subscription credentials (missing `api.responses.write`).
- **Saved runs keep the full text.** Each match's `calls.jsonl` keeps the returned thinking text, usage including reasoning tokens, tool calls and latency. `session.sqlite` keeps full conversations with encrypted reasoning signatures, which allow resume but can't be decrypted.
- **Claude 5.5 summaries are prose,** from about 250 characters at medium to 9–13k at max. At medium, sonnet and opus skip thinking on 40–50% of calls.
- **A required `reason` field on `play_move`** produced readable 1–3 sentence rationales from all four GPT models, exposing their mistakes. It's a self-report, and its effect on play is untested.
- **Effort availability:**
  - terra and gpt-5.6-luna `none` reach the Codex backend fine (0 reasoning tokens), but the proxy used here rewrites them to `low`.
  - gpt-6-luna `none` works.
  - gpt-6.1-sol rejects `none`.
  - opus 5.5 can't disable thinking.
  - sonnet 5.5 `disabled` returned 200 with 0 thinking through the proxy, which contradicts Anthropic's docs.
- **How other benchmarks pair entrants:** Kaggle Game Arena plays a round robin with seat swaps. LMArena samples pairs adaptively. Effort variants appear as separate entrants elsewhere, but no benchmark found plays a model's own effort levels against each other. Here, neighbouring effort levels plus medium carry the most information per game.

