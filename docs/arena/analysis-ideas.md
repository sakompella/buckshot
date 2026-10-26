# Analysis ideas

Ideas for using the tournament data, collected 2026-10-21. Most came from a GPT-6 Astra review. Nothing here is built unless marked. Rates must show their counts, intervals must bootstrap `matches.seed_block_id`, and comparisons stay within one cohort (tournament, code hash and pairing kind). See [database.md](database.md).

"Minimax" means scoring recorded positions with the player in `sim/bend-mp/player/`. Record completed depth, budget flag and whether a value is exact or heuristic; never count the depth-0 fallback as zero regret, and call a move "correct" only where the position is solved.

## Built or in progress

- **Viewer** (local, `_work/arena/viewer/`): leaderboard with Bradley-Terry ratings, choice patterns, item use, seats, cost, reliability, head to head, match explorer.
- **Matchups** (branch `analysis/matchups`): pooled ratings, matchup effects, seat advantage, tournament 3 estimates.
- **Beliefs and items** (branch `analysis/beliefs-and-items`): each player's own information per decision through Bend replay; information retention, item flow, same-position consistency.

## From existing traces, no minimax

| Idea | What it shows | Data | Signal so far | Effort |
|---|---|---|---|---|
| Moves sent blind | Replies that send several moves before seeing the first one's result: accepted prefixes, stale suffixes, lucky successes | `calls.tool_calls_json`, `session.sqlite` tool results | 201 replies with several tool calls, 384 of them moves; at most 3 per reply | 1–3 days |
| How comebacks happen | Round-by-round stories: sweeps versus reversals; whether rankings change when counted by rounds won or cash margin | round-winner events, `match_seats.cash` | no scored match ends in a tie | 2–3 days |
| It knew better, then did it anyway | The returned reasoning states the key fact or recommends a move, then the model submits something else | `calls.reasoning_text`, `response_text`, linked decisions | needs a hand-checked sample of 50–100 | 2–4 days |
| Changing its mind | A reply proposes a move, corrects itself, submits; did the correction help? | reasoning and reply text | 11,173 summaries say "actually", 6,749 "wait" (candidates only) | 2–4 days |
| Checking the models' numbers | Stated shell odds and "guaranteed" claims against the player's own information | reasoning text, belief reconstruction | 12,298 mention percentages, 6,722 "probab", 9,706 "guarantee" | 3–5 days |
| Predicting the opponent | Whether "they will shoot me"-style forecasts come true, against the common move in similar positions | reasoning text, next opponent decision | not measured | 2–4 days |
| Menu position bias | Whether a move's place in the legal list predicts choice | `legal_json` order, `selected_move` | first option 50.1% of 2-option and 33.5% of 3-option moves: no simple bias | 2–3 days |

Reasoning text is a returned summary, not the model's full reasoning. Claude returns prose and GPT short headings, so compare text-based measures within a model.

## Need minimax on recorded positions

| Idea | What it shows | Effort |
|---|---|---|
| Luck versus choice | Each match as choice losses (best minus chosen value) and surprises (realized minus expected branch value); winners who played worse | 5–8 days |
| Find the win | Puzzles from moments where a model missed a provable win; a small retrospective tactics set | 3–5 days |
| Where complexity breaks a model | Regret against menu size and the depth at which the preferred move settles | 4–7 days |
| Mistake concentration and regret | Mean and tail regret per model; replaces the odds-based choice patterns | with the evaluator run |

## Need new games or model calls

| Idea | What it tests | Effort |
|---|---|---|
| Can you beat the model? | Daily puzzles from real matches with each model's choice revealed | 3–5 days |
| Alternate endings | Play another move at a key moment and compare both futures over compatible hidden worlds | 1–2 weeks |
| Turning-point reel | A one-minute replay of a match's biggest swings | 3–5 days |
| Buckshot Trials | A fixed set of 100–300 tactical positions with a hidden test set | 1–2 weeks |
| Lifeline | A cheap model may consult an expensive one a limited number of times; does it ask at the right moments? | 1–2 weeks |
| Pressure dial | Shared positions under shrinking token or time budgets | 4–7 days |
| How sure are you? | Stated win odds against outcomes | 4–7 days |
| Framing trap | Same position with other names, move order or wording | 3–5 days |
| Exploitability ladder | Opponents with planted weaknesses; do models exploit them? | 1–2 weeks |
| Comeback lab | Every model starts from the same hard but winnable positions | 4–7 days |
| Advice crossover | One model writes a playbook, another plays with it | 1–2 weeks |
| Betrayal table | Three or four models at one table: who attacks or spares whom | 1–2 weeks |
| Spectator prediction game | Viewers bet play money on the next move or round winner (a prerecorded version needs only replays) | 3–5 days |

## More charts from existing traces

Proposed for the viewer; quick read-only counts over scored matches unless noted.

| Chart | Question | Signal |
|---|---|---|
| Menu-size heat map per model | With more options, does a model still just shoot? | shots are 66.8% of choices with 3 legal moves, 19.9% with 6, 9.7% with 10 |
| Move transition matrix | Which combinations do models play (saw then shoot, glass then shoot self)? | 7,098 handsaw→opponent-shot pairs, 2,590 glass→self-shot |
| Run-length curves | Who keeps control of the table? | 37,607 same-player runs, 6,359 of 5+ moves, longest 12 |
| Cost concentration (Lorenz) | Where does the spend go? | top 1% of calls are 37.9% of spend, top 10% are 69.8% (all calls) |
| Winner vs loser cost | Did the winner spend more? | winner spent more in 1,315 of 2,138 matches (61.5%) |
| Reasoning frequency vs length by effort | Does more effort think more often or longer? | Sonnet replies with reasoning tokens: 57.5% at low, 89.2% at max, 57.2% at off |
| Cache share by move number | How much of the prompt is reread? | cache reads are 91.1% of prompt tokens (all calls) |
| Moves in wins vs losses | How much work does winning take? | median 25 agent moves in wins, 23 in losses |
| Targeting when behind | Does trailing change whom a model shoots? | self-shots 34.3% behind, 26.9% level, 24.5% ahead (health known in both views only; 16,222 shots lack it) |

Avoid an inferred win-probability timeline until a predictive model is fitted and calibrated on held-out seeds.
