# Arena results

This page summarizes the tournaments run so far, the findings about model reasoning, and the open work. The raw data stays under `_work/arena/`, which isn't committed. See [README.md](README.md) for how to run and resume. All costs are theoretical: list prices for usage on subscription plans.

Ratings are Bradley-Terry on an Elo scale, per configuration (model + endpoint + effort), with 95% bootstrap CIs clustered by seed. Each pairing plays 10 seeds in both seat orders, 20 matches, unless stated otherwise. With 10 seeds, close rankings aren't reliable. "Medium" also isn't equal compute across providers.

## Status (2026-10-20, 8:30 PM PDT)
- **tournament-1** (`_work/arena/tournament-1`): finished. 123 matches were skipped (DeepSeek and Astra), and they're still in its `tournament.json`.
- **tournament-2** (`_work/arena/tournament-2`, config `web/tournaments/opus-effort.json`): stage A is finished. Stage B, the max pairings, hasn't started and needs the user's go-ahead.
- **tournament-3** (`_work/arena/tournament-3`, config `web/tournaments/astra-opus-xhigh.json`): running, capped at 40 matches.
  - The live copy of the config adds the Codex account pool.
  - It runs from a detached checkout at `ec711b3` (code `3c9b98f8b3f4`) under launchd `com.aditya.buckshot-astra-opus`.
  - Seed 3028's first match started on code `9e7d7ff22891` and resumes from the `agents/arena-design` worktree (`--code`).
  - Seed 3030's two matches were stopped by the cap and aren't scored.
  - The final numbers replace the interim ones below when it ends.

## tournament-1: cross-model and effort sweeps
2,017 matches, $971.53. Code versions `51b8366684f0` and `9e7d7ff22891`; the only request difference is the GPT reasoning summary (`auto` vs `detailed`).

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

## tournament-3: Opus 5.5 xhigh vs Astra medium (interim)
The seeds were fixed in advance: 3000–3009 first (tournament-1's Opus medium vs Astra seeds, for a matched comparison), then 3020–3029.

At 39 finished matches:
- **Complete pairs:** 18. Opus xhigh 20, Astra 16: Opus share 55.6%, 95% CI 38.9–72.2%.
- **Matched against Opus medium** on seeds 3000–3009: 10/20 vs 9/20, a difference of +5%, 95% CI −15% to +25%.
- **So far:** inconclusive. xhigh shows no measurable gain over medium against Astra.
- **Astra's reasoning:** it reasons very little at medium; only about 1k reasoning tokens over 850 calls.

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
1. tournament-3: final report when it ends.
2. tournament-2 stage B: needs the user's go-ahead.
3. gpt-5.6-luna effort sweep: a medium entrant, placement against the medium models, then low–max. About 160 matches on Codex quota. `none` needs the CPA patch.
4. tournament-1 leftovers: 3 Astra vs haiku 4.5 matches (cheap; restores seed balance) and 20 vs DeepSeek (free tier refusing).
5. `web/src/arena/runlog.ts`: join thinking blocks with `"\n\n"`. About 1.9% of saved texts run headings together. This changes the code hash.
6. An optional, separately labelled entrant with a `reason` field. Check its effect on play with paired seeds before rating it.
7. Remove the worktrees `t3-1427bb8e` (`agents/arena-design`, nothing unmerged), `t3-code-51b8366684f0` and the tournament-3 runner checkout once no match needs them.
