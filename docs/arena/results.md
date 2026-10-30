# Arena results

This page summarizes the tournaments run so far, the findings about model reasoning, and the open work. The raw data stays under `_work/arena/`, which isn't committed. See [README.md](README.md) for how to run and resume. All costs are list-price costs: list prices applied to usage on subscription plans, not money paid.

Ratings are one Bradley-Terry fit over every scored match of every tournament, on an Elo scale with the mean at 0, per configuration (model + endpoint + effort). So one rating scale covers every config, as in the viewer. A second fit on pot share (a config's cash over the match's cash, which also credits round prizes a loser banked) gives the cash rating. 95% intervals are in [matchups.md](analysis/matchups.md). Each pairing plays 10 seeds in both seat orders, 20 matches, unless stated otherwise. With 10 seeds, close rankings aren't reliable. "Medium" also isn't equal compute across providers.

Scope: 2,533 scored matches with no DeepSeek seat, from the 2,553-match snapshot of 2026-10-30.

## Status (snapshot of 2026-10-30)
This page describes the 2,553-match snapshot of the analysis database. Tournament 5 was still running a top-up when it was taken. Its later matches are not here.
- **tournament-1** (`_work/arena/tournament-1`): finished. 120 scheduled matches are unplayed, all against DeepSeek: 38 started and are partial, and 82 never started. The leftover Astra and terra matches finished on 2026-10-22 (below).
- **tournament-2** (`_work/arena/tournament-2`, config `web/tournaments/opus-effort.json`): stage A is finished. Stage B, the max pairings, hasn't started and needs the user's go-ahead.
- **tournament-3** (`_work/arena/tournament-3`, config `web/tournaments/astra-opus-xhigh.json`): finished, 40 of 40 capped matches.
- **tournament-4** (`_work/arena/tournament-4`): finished, 288 of 288 (below). The 138 Sonnet max matches once scheduled in tournament-1 were cut when tournament-4 took over its cross-model games; the import skips them.
- **tournament-5** (`_work/arena/tournament-5`): partly played. The snapshot holds 62 completed matches (below).

## Leaderboard
One table per cohort, ranked by the pooled rating, as the viewer's leaderboards show them. Matches, win share and pot share count the cohort's own games; ratings come from the one pooled fit, so a config has the same rating in every table. Sonnet max has 2 games in tournament 1's cross-model cohort (it lost both to Opus), so its rating there rests on its tournament-4 games. Tournament 5's 62 matches are one table of their own, with 2 to 12 matches per config against different opponents; their ratings are mostly the prior pulling a thin record, not a ranking. `python3 tools/arena/analysis/leaderboard.py --doc docs/arena/results.md` rewrites the tables.

<!-- leaderboard:start -->
### All configs

2533 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-opus-5-5-max | 8 | 87.5% | 71.4% | +334 | +190 |
| gpt-6.1-terra-max | 4 | 75.0% | 66.1% | +227 | +126 |
| claude-opus-5-5-xhigh | 81 | 59.3% | 54.7% | +180 | +96 |
| gpt-6.1-terra-low | 6 | 66.7% | 61.1% | +167 | +72 |
| claude-sonnet-5-5-max | 110 | 69.1% | 64.3% | +160 | +112 |
| gpt-6-astra | 219 | 68.0% | 61.3% | +149 | +84 |
| gpt-6.1-sol-max | 92 | 60.9% | 57.0% | +145 | +104 |
| claude-haiku-5-5-xhigh | 110 | 62.7% | 54.0% | +103 | +16 |
| gpt-6.1-terra | 12 | 58.3% | 53.5% | +95 | +23 |
| claude-opus-5-5-off | 8 | 62.5% | 58.6% | +94 | +81 |
| claude-haiku-5-5-max | 110 | 60.9% | 58.6% | +92 | +45 |
| claude-sonnet-5-5-xhigh | 112 | 57.1% | 53.2% | +89 | +47 |
| claude-opus-5-5-high | 50 | 48.0% | 47.9% | +88 | +42 |
| gpt-6.1-sol-xhigh | 94 | 52.1% | 52.7% | +86 | +73 |
| gpt-6.1-sol-low | 90 | 50.0% | 49.9% | +81 | +63 |
| gpt-6-astra-low | 8 | 62.5% | 50.0% | +76 | -9 |
| claude-opus-5-5 | 248 | 58.1% | 54.5% | +72 | +44 |
| gpt-6.1-sol-high | 90 | 48.9% | 48.7% | +68 | +52 |
| gpt-6.1-terra-off | 6 | 50.0% | 44.4% | +66 | -14 |
| gpt-6.1-sol | 266 | 56.8% | 56.5% | +65 | +59 |
| gpt-6-astra-high | 4 | 50.0% | 67.8% | +62 | +161 |
| claude-sonnet-5-5-high | 112 | 52.7% | 50.5% | +51 | +25 |
| claude-haiku-5-5-high | 112 | 51.8% | 51.8% | +36 | +4 |
| claude-haiku-5-5 | 280 | 52.5% | 51.1% | +17 | +0 |
| claude-haiku-5-5-low | 112 | 48.2% | 48.8% | +16 | -12 |
| claude-sonnet-5-5 | 278 | 51.1% | 51.3% | +15 | +14 |
| claude-sonnet-5-5-off | 112 | 44.6% | 45.4% | +11 | +1 |
| gpt-5.6-terra-max | 90 | 57.8% | 53.8% | +10 | +24 |
| gpt-5.6-terra-xhigh | 90 | 56.7% | 54.7% | +8 | +33 |
| gpt-6-luna-xhigh | 112 | 69.6% | 64.4% | -21 | -2 |
| claude-opus-5-5-low | 34 | 41.2% | 54.0% | -24 | +56 |
| gpt-6.1-terra-xhigh | 8 | 37.5% | 37.5% | -27 | -66 |
| gpt-6-luna-max | 110 | 67.3% | 63.2% | -42 | -12 |
| claude-sonnet-5-5-low | 112 | 35.7% | 42.2% | -49 | -22 |
| gpt-5.6-terra | 256 | 46.5% | 48.3% | -50 | -16 |
| gpt-5.6-terra-high | 90 | 44.4% | 49.6% | -66 | +2 |
| gpt-5.6-terra-low | 90 | 41.1% | 45.7% | -83 | -20 |
| gpt-6-luna-high | 110 | 60.0% | 55.6% | -98 | -63 |
| claude-haiku-5-5-off | 110 | 30.9% | 35.7% | -99 | -96 |
| gpt-6.1-terra-high | 8 | 25.0% | 33.1% | -133 | -104 |
| claude-haiku-4-5-20251001-minimal | 90 | 55.6% | 50.0% | -158 | -117 |
| claude-haiku-4-5-20251001 | 256 | 38.3% | 41.7% | -163 | -101 |
| claude-haiku-4-5-20251001-low | 90 | 50.0% | 51.3% | -193 | -111 |
| claude-haiku-4-5-20251001-high | 90 | 47.8% | 49.4% | -205 | -121 |
| gpt-6-luna | 276 | 26.4% | 34.4% | -252 | -147 |
| claude-haiku-4-5-20251001-off | 90 | 27.8% | 36.3% | -327 | -195 |
| gpt-6-luna-off | 110 | 26.4% | 33.8% | -335 | -202 |
| gpt-6-luna-low | 110 | 25.5% | 31.4% | -341 | -217 |

### Cross-model games (tournament 1)

562 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-sonnet-5-5-max | 2 | 0.0% | 34.4% | +160 | +112 |
| gpt-6-astra | 140 | 72.1% | 63.3% | +149 | +84 |
| claude-opus-5-5 | 142 | 62.7% | 58.2% | +72 | +44 |
| gpt-6.1-sol | 140 | 59.3% | 58.2% | +65 | +59 |
| claude-haiku-5-5 | 140 | 57.9% | 53.7% | +17 | +0 |
| claude-sonnet-5-5 | 140 | 55.0% | 54.2% | +15 | +14 |
| gpt-5.6-terra | 140 | 45.7% | 48.3% | -50 | -16 |
| claude-haiku-4-5-20251001 | 140 | 30.0% | 35.7% | -163 | -101 |
| gpt-6-luna | 140 | 17.9% | 28.5% | -252 | -147 |

### claude-haiku-5-5 efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-haiku-5-5-xhigh | 100 | 65.0% | 55.0% | +103 | +16 |
| claude-haiku-5-5-max | 100 | 60.0% | 57.8% | +92 | +45 |
| claude-haiku-5-5-high | 100 | 54.0% | 53.6% | +36 | +4 |
| claude-haiku-5-5 | 100 | 45.0% | 49.5% | +17 | +0 |
| claude-haiku-5-5-low | 100 | 45.0% | 47.8% | +16 | -12 |
| claude-haiku-5-5-off | 100 | 31.0% | 36.2% | -99 | -96 |

### claude-sonnet-5-5 efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-sonnet-5-5-max | 100 | 68.0% | 63.4% | +160 | +112 |
| claude-sonnet-5-5-xhigh | 100 | 58.0% | 52.9% | +89 | +47 |
| claude-sonnet-5-5-high | 100 | 51.0% | 49.2% | +51 | +25 |
| claude-sonnet-5-5 | 100 | 45.0% | 47.6% | +15 | +14 |
| claude-sonnet-5-5-off | 100 | 43.0% | 44.9% | +11 | +1 |
| claude-sonnet-5-5-low | 100 | 35.0% | 42.0% | -49 | -22 |

### gpt-6-luna efforts (tournament 1)

300 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6-luna-xhigh | 100 | 72.0% | 66.0% | -21 | -2 |
| gpt-6-luna-max | 100 | 72.0% | 66.1% | -42 | -12 |
| gpt-6-luna-high | 100 | 62.0% | 56.8% | -98 | -63 |
| gpt-6-luna | 100 | 39.0% | 42.7% | -252 | -147 |
| gpt-6-luna-off | 100 | 28.0% | 35.4% | -335 | -202 |
| gpt-6-luna-low | 100 | 27.0% | 32.9% | -341 | -217 |

### claude-haiku-4-5-20251001 efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-haiku-4-5-20251001-minimal | 80 | 57.5% | 51.2% | -158 | -117 |
| claude-haiku-4-5-20251001 | 80 | 58.8% | 55.8% | -163 | -101 |
| claude-haiku-4-5-20251001-low | 80 | 51.2% | 52.7% | -193 | -111 |
| claude-haiku-4-5-20251001-high | 80 | 53.8% | 52.4% | -205 | -121 |
| claude-haiku-4-5-20251001-off | 80 | 28.7% | 38.0% | -327 | -195 |

### gpt-5.6-terra efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-5.6-terra-max | 80 | 58.8% | 53.9% | +10 | +24 |
| gpt-5.6-terra-xhigh | 80 | 60.0% | 56.1% | +8 | +33 |
| gpt-5.6-terra | 80 | 45.0% | 45.0% | -50 | -16 |
| gpt-5.6-terra-high | 80 | 46.2% | 50.8% | -66 | +2 |
| gpt-5.6-terra-low | 80 | 40.0% | 44.2% | -83 | -20 |

### gpt-6.1-sol efforts (tournament 1)

200 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| gpt-6.1-sol-max | 80 | 58.8% | 54.7% | +145 | +104 |
| gpt-6.1-sol-xhigh | 80 | 48.8% | 49.8% | +86 | +73 |
| gpt-6.1-sol-low | 80 | 48.8% | 48.7% | +81 | +63 |
| gpt-6.1-sol-high | 80 | 47.5% | 47.7% | +68 | +52 |
| gpt-6.1-sol | 80 | 46.2% | 49.1% | +65 | +59 |

### Opus efforts (tournament 2)

80 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-opus-5-5-xhigh | 40 | 65.0% | 58.6% | +180 | +96 |
| claude-opus-5-5-high | 40 | 45.0% | 44.1% | +88 | +42 |
| claude-opus-5-5 | 60 | 48.3% | 48.1% | +72 | +44 |
| claude-opus-5-5-low | 20 | 35.0% | 50.2% | -24 | +56 |

### Tournament 5, first imported subset

62 scored matches.

| config | matches | win share | pot share | rating (Elo) | cash rating (Elo) |
|---|---|---|---|---|---|
| claude-opus-5-5-max | 8 | 87.5% | 71.4% | +334 | +190 |
| gpt-6.1-terra-max | 4 | 75.0% | 66.1% | +227 | +126 |
| gpt-6.1-terra-low | 6 | 66.7% | 61.1% | +167 | +72 |
| gpt-6.1-sol-max | 2 | 50.0% | 67.8% | +145 | +104 |
| gpt-6.1-terra | 12 | 58.3% | 53.5% | +95 | +23 |
| claude-opus-5-5-off | 8 | 62.5% | 58.6% | +94 | +81 |
| claude-sonnet-5-5-xhigh | 2 | 50.0% | 65.6% | +89 | +47 |
| gpt-6.1-sol-xhigh | 4 | 75.0% | 75.0% | +86 | +73 |
| gpt-6-astra-low | 8 | 62.5% | 50.0% | +76 | -9 |
| claude-opus-5-5 | 10 | 40.0% | 39.8% | +72 | +44 |
| gpt-6.1-terra-off | 6 | 50.0% | 44.4% | +66 | -14 |
| gpt-6.1-sol | 10 | 60.0% | 59.8% | +65 | +59 |
| gpt-6-astra-high | 4 | 50.0% | 67.8% | +62 | +161 |
| claude-sonnet-5-5-high | 2 | 100.0% | 67.8% | +51 | +25 |
| claude-haiku-5-5-high | 2 | 0.0% | 16.7% | +36 | +4 |
| claude-haiku-5-5 | 2 | 50.0% | 48.9% | +17 | +0 |
| claude-haiku-5-5-low | 2 | 50.0% | 47.8% | +16 | -12 |
| claude-sonnet-5-5 | 2 | 0.0% | 16.7% | +15 | +14 |
| claude-sonnet-5-5-off | 2 | 0.0% | 16.7% | +11 | +1 |
| gpt-6-luna-xhigh | 2 | 50.0% | 50.0% | -21 | -2 |
| claude-opus-5-5-low | 4 | 25.0% | 40.6% | -24 | +56 |
| gpt-6.1-terra-xhigh | 8 | 37.5% | 37.5% | -27 | -66 |
| claude-sonnet-5-5-low | 2 | 0.0% | 32.2% | -49 | -22 |
| gpt-6.1-terra-high | 8 | 25.0% | 33.1% | -133 | -104 |
| gpt-6-luna | 4 | 0.0% | 16.7% | -252 | -147 |
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

## Tournament 5: first completed subset (2026-10-30)

The viewer now includes 62 completed matches from the first subset and earlier small batches. The database has 2,553 completed matches in total. This snapshot excludes the additional top-up still running. The new matches add $49.58 of list-price usage, bringing the database total to $1,200.01; every call is priced.

These are sparse comparisons, not a new leaderboard verdict. Each new pairing has two matches on one seed with swapped seats. Configs have between two and twelve matches in this snapshot, against different opponents. Opus max won seven of its eight matches and Opus off five of eight, but neither is enough to establish their relative strength. Terra 6.1 has results at all six tested effort levels; the sample does not establish an effort trend.

The viewer's outcome ratings include these matches. The knowledge and regret datasets were rebuilt for them on 2026-10-30 from the same snapshot, and the tables in [analysis/beliefs-and-items.md](analysis/beliefs-and-items.md) and [analysis/regret.md](analysis/regret.md) include them. They are new files until the live derived databases are swapped, so a viewer still on the old files has no move-quality data for them, which must not be read as zero mistakes. The [deeper-search check](analysis/regret.md#deeper-search) and [minimax self-play study](analysis/matchups.md#minimax-self-play) describe separate CPU-only evaluations.

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
