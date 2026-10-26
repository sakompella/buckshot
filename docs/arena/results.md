# Arena results

This page summarizes the tournaments run so far, the findings about model reasoning, and the open work. The raw data stays under `_work/arena/`, which isn't committed. See [README.md](README.md) for how to run and resume. All costs are theoretical: list prices for usage on subscription plans.

Ratings are Bradley-Terry on an Elo scale, per configuration (model + endpoint + effort), with 95% bootstrap CIs clustered by seed. Each pairing plays 10 seeds in both seat orders, 20 matches, unless stated otherwise. With 10 seeds, close rankings aren't reliable. "Medium" also isn't equal compute across providers.

## Status (2026-10-26)
- **Nothing is running.** No arena jobs, runners, agents or heartbeats.
- **tournament-1** (`_work/arena/tournament-1`): finished. 120 scheduled matches are unplayed, all against DeepSeek: 38 started and are partial, and 82 never started. The leftover Astra and terra matches finished on 2026-10-22 (below).
- **tournament-2** (`_work/arena/tournament-2`, config `web/tournaments/opus-effort.json`): stage A is finished. Stage B, the max pairings, hasn't started and needs the user's go-ahead.
- **tournament-3** (`_work/arena/tournament-3`, config `web/tournaments/astra-opus-xhigh.json`): finished, 40 of 40 capped matches.
- **tournament-4** (`_work/arena/tournament-4`): finished, 288 of 288 (below). The 138 Sonnet max matches once scheduled in tournament-1 were cut when tournament-4 took over its cross-model games; the import skips them.
- **Where the data is:** all tournament data lives in the `agents/arena-design` worktree (`~/.t3/worktrees/buckshot/t3-1427bb8e/_work/arena/`). That worktree also serves as the `--code 9e7d7ff22891` checkout. Keep it.

## tournament-1: cross-model and effort sweeps
2,080 matches, $934.46. Code versions `51b8366684f0` and `9e7d7ff22891`; the only request difference is the GPT reasoning summary (`auto` vs `detailed`). The 60 leftover terra matches below ran under `3c9b98f8b3f4`. The tables below cover the first 2,017 matches and are not refitted.

### All models at medium effort
| Entrant | Matches | Win share | 95% CI | Rating |
|---|---|---|---|---|
| gpt-6-astra | 117 | 71.8% | 65.9% to 76.7% | 158 |
| claude-opus-5-5 | 120 | 62.5% | 53.1% to 71.2% | 92 |
| gpt-6.1-sol | 140 | 59.3% | 52.5% to 67.8% | 65 |
| claude-haiku-5-5 | 140 | 57.9% | 53.4% to 63.0% | 55 |
| claude-sonnet-5-5 | 140 | 55.0% | 47.1% to 62.5% | 36 |
| gpt-5.6-terra | 80 | 46.3% | 33.3% to 59.4% | -41 |
| claude-haiku-4-5-20251001 | 117 | 29.9% | 21.9% to 37.3% | -129 |
| gpt-6-luna | 140 | 17.9% | 12.0% to 25.0% | -235 |

**Leftovers, finished 2026-10-22** (63 matches, about $19.6; all replay-validated). Each pairing is 20 matches. Scores are matches won, first-named entrant first:
- gpt-5.6-terra vs gpt-6-astra: 5–15
- gpt-5.6-terra vs claude-opus-5-5: 8–12
- gpt-5.6-terra vs claude-haiku-4-5: 14–6
- gpt-6-astra vs claude-haiku-4-5: 17–3, after the 3 unfinished matches resumed (Astra 2, haiku 4.5 1 of them)

### Effort sweeps (each model round-robin against its own effort levels; no suffix = medium)
### gpt-6-luna
| Entrant | Matches | Win share | 95% CI | Rating |
|---|---|---|---|---|
| gpt-6-luna-xhigh | 100 | 72.0% | 67.0% to 77.0% | 146 |
| gpt-6-luna-max | 100 | 72.0% | 67.0% to 78.0% | 146 |
| gpt-6-luna-high | 100 | 62.0% | 52.0% to 72.0% | 77 |
| gpt-6-luna | 100 | 39.0% | 27.0% to 50.0% | -71 |
| gpt-6-luna-off | 100 | 28.0% | 20.0% to 36.0% | -145 |
| gpt-6-luna-low | 100 | 27.0% | 24.0% to 30.0% | -153 |
### gpt-5.6-terra
| Entrant | Matches | Win share | 95% CI | Rating |
|---|---|---|---|---|
| gpt-5.6-terra-xhigh | 80 | 60.0% | 50.0% to 67.5% | 55 |
| gpt-5.6-terra-max | 80 | 58.8% | 50.0% to 67.5% | 48 |
| gpt-5.6-terra-high | 80 | 46.3% | 38.8% to 53.8% | -20 |
| gpt-5.6-terra | 80 | 45.0% | 36.3% to 53.8% | -27 |
| gpt-5.6-terra-low | 80 | 40.0% | 28.7% to 51.2% | -55 |
### gpt-6.1-sol
| Entrant | Matches | Win share | 95% CI | Rating |
|---|---|---|---|---|
| gpt-6.1-sol-max | 80 | 58.8% | 47.5% to 68.8% | 48 |
| gpt-6.1-sol-low | 80 | 48.8% | 40.0% to 58.8% | -7 |
| gpt-6.1-sol-xhigh | 80 | 48.8% | 38.8% to 57.5% | -7 |
| gpt-6.1-sol-high | 80 | 47.5% | 40.0% to 55.0% | -14 |
| gpt-6.1-sol | 80 | 46.3% | 37.5% to 55.0% | -20 |
### claude-haiku-4-5
| Entrant | Matches | Win share | 95% CI | Rating |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 | 80 | 58.8% | 50.0% to 67.5% | 49 |
| claude-haiku-4-5-20251001-minimal | 80 | 57.5% | 50.0% to 65.0% | 42 |
| claude-haiku-4-5-20251001-high | 80 | 53.8% | 38.8% to 67.5% | 22 |
| claude-haiku-4-5-20251001-low | 80 | 51.2% | 43.8% to 58.8% | 8 |
| claude-haiku-4-5-20251001-off | 80 | 28.7% | 18.8% to 40.0% | -121 |
### claude-haiku-5-5
| Entrant | Matches | Win share | 95% CI | Rating |
|---|---|---|---|---|
| claude-haiku-5-5-xhigh | 100 | 65.0% | 58.0% to 71.0% | 89 |
| claude-haiku-5-5-max | 100 | 60.0% | 49.0% to 71.0% | 59 |
| claude-haiku-5-5-high | 100 | 54.0% | 50.0% to 58.0% | 24 |
| claude-haiku-5-5-low | 100 | 45.0% | 40.0% to 50.0% | -29 |
| claude-haiku-5-5 | 100 | 45.0% | 37.0% to 52.0% | -29 |
| claude-haiku-5-5-off | 100 | 31.0% | 25.0% to 37.0% | -114 |
### claude-sonnet-5-5
| Entrant | Matches | Win share | 95% CI | Rating |
|---|---|---|---|---|
| claude-sonnet-5-5-max | 100 | 68.0% | 55.0% to 81.0% | 107 |
| claude-sonnet-5-5-xhigh | 100 | 58.0% | 48.0% to 68.0% | 47 |
| claude-sonnet-5-5-high | 100 | 51.0% | 42.0% to 59.0% | 6 |
| claude-sonnet-5-5 | 100 | 45.0% | 34.0% to 57.0% | -29 |
| claude-sonnet-5-5-off | 100 | 43.0% | 37.0% to 50.0% | -41 |
| claude-sonnet-5-5-low | 100 | 35.0% | 28.0% to 42.0% | -89 |

Takeaways:
- xhigh is generally the best level. max rarely beats it clearly and costs about 10× more.
- luna gains the most from effort. sol barely changes except at max.
- True off clearly hurts haiku 4.5 and 5.5. haiku 4.5's minimal plays like its medium.
- sonnet 5.5's off is "requested off" (`between_tools`).

## tournament-2: Opus 5.5 effort, stage A
80 matches, $58.89. Each new level plays medium and its neighbouring level: low–medium, medium–high, medium–xhigh, high–xhigh.

| Entrant | Matches | Win share | 95% CI | Rating |
|---|---|---|---|---|
| opus xhigh | 40 | 65.0% | 50.0–80.0% | +97 |
| opus high | 40 | 45.0% | 30.0–60.1% | +8 |
| opus medium | 60 | 48.3% | 38.3–60.0% | −9 |
| opus low | 20 | 35.0% | 20.0–50.0% | −96 |

Head to head:
- medium beat low 65–35;
- high beat medium 55–45;
- xhigh beat medium 65–35;
- xhigh beat high 65–35.

Stage B would add medium–max and xhigh–max: 40 matches, about $355–370 (max matches take about an hour each), about 1.5–2.5 days at the Claude line. Measured quota use was about 0.0115 of a Claude 5h window per dollar on one account and 0.0080 on the other.

## tournament-3: Opus 5.5 xhigh vs Astra medium (finished, 41 matches)
- **Seeds:** fixed in advance. First 3000–3009, which are tournament-1's Opus medium vs Astra seeds, for a matched comparison. Then 3020–3029. Capped at 40 matches; Aditya later ruled that the one finished match past the cap also counts.
- **Codex accounts:** Astra was pinned to one Codex account per match (ADR-0042) from match 38 on. Opus was never pinned.
- **The last 2 matches** ran with no quota line. Seed 3028's first match started on code `9e7d7ff22891` without a pin, and CPA may have moved it to the other Codex account while account 1 was full. Seed 3029's second match stayed pinned and waited for account 1 to reset.

**Results (20 complete seed pairs plus seed 3030's first match):**
- **Overall:** Opus xhigh 22, Astra 19. Opus share 53.7%, 95% CI 38.1–69.0% (seed bootstrap over 21 seeds). On the 20 complete pairs alone it was 22–18, 55.0%, CI 40.0–70.0%.
- **Per seed:** Opus won both games on 6 seeds, Astra on 4, and 10 split. Astra won seed 3030's only game. Seat 2 won 17 of 41.
- **Matched against Opus medium** on seeds 3000–3009: 10/20 vs 9/20, a difference of +5%, 95% CI −15% to +25%.
- **Verdict:** inconclusive. The data rules out neither model being somewhat stronger, and xhigh shows no measurable gain over medium against Astra.
- **Cost:** $41.11 at list prices: Opus $29.75, Astra $11.36. Astra reasons very little at medium: about 3k reasoning tokens over 1,077 calls.

**Outside the cap.** A brief uncapped run started 6 matches (seeds 3030–3032). Seed 3030's first match finished and is scored above. The other 5 never finished, are not scored, and cost $1.38 together. They stay in the tournament directory, unfinished.

**Lessons:**
- **Pass every needed `--code` when using a cap.** While an old-code match waits for its checkout, the runner leaves it off its pending list, so `--limit` picks a match past the cap.
- **An account with no quota data isn't over the limit.** `tools/arena/quota_guard.py` now treats it as not blocking; the old rule caused a false stop at 8:58 PM.
- **List accounts on every endpoint,** Claude as well as Codex, so both sides of each new match are pinned from the start.

## tournament-4: cross-model samples (finished 2026-10-25, 288 matches)

Every config that had only played its own model's effort sweep played 10 matches against other models at medium effort: 5 seat-swapped pairs, each against a different opponent, seeds 3000–3009. Sonnet max played 8 here; its other 2 (both lost to Opus) are in tournament-1. 288 matches, no failed runs, $108.96 at list prices. With these, every config has cross-model games, so the pooled rating no longer leans on the effort sweeps alone.

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

Ten games per config is a small sample: read single cells as rough. Two patterns stand out. Haiku 4.5 at high won none of its 10. Sol stays strong at every effort (6–8 of 10). The pooled ratings over all tournaments are in the viewer, and in [matchups.md](analysis/matchups.md) once it is refreshed.

## Beliefs and items
What each model knew about the chamber when it shot, whether it acted on it, what became of its items, and how consistently it chose in repeated positions: [analysis/beliefs-and-items.md](analysis/beliefs-and-items.md).

## Other analyses
- **Matchups:** ratings within each cohort, no matchup effects, seat and round-1 starter effects: [analysis/matchups.md](analysis/matchups.md).
- **Play patterns:** reviewed habits per model, from the traces: [analysis/patterns.md](analysis/patterns.md).
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
6. Keep the `t3-1427bb8e` worktree: it holds the tournament data and the `9e7d7ff22891` code. tournament-1's old code `51b8366684f0` is commit `5e6f1b1`; check it out again only to resume its 41 partial matches.
7. Fit the minimax player's evaluator weights from the analysis database before tuning anything by hand.
