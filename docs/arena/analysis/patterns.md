# Play patterns

Patterns in how the models played and reasoned in the arena. Each one was found in the traces and then checked again with an independent query against the analysis database ([database.md](../database.md)) and the derived `knowledge.sqlite` ([beliefs-and-items.md](beliefs-and-items.md)). This is a casual pass: counts and rates, no intervals. Treat any gap of a few points on 20–100 seats as noise.

Scope:
- **Data.** Only the table and prose of "Patterns against regret" use the 2,533 scored matches with no DeepSeek seat, from the 2,553-match snapshot of 2026-10-30. Every other count and rate on this page was taken from 2,118 such matches around 2026-10-22 and was not refreshed. Where the two disagree, trust the regret section.
- Decision rates count scored matches with no DeepSeek seat.
- Call counts (tokens, list-price costs, tool calls, reasoning text) include every started match.
- "Known" means the deciding player's own log proves the shell. A shot's result is read from the log that follows it.
- Effort comparisons use each model's own effort sweep, except where a tournament is named. Saved reasoning is provider-returned text and often a summary, so quotes are short and paraphrase-like.

## Patterns, most interesting first

1. **Opus sends two moves in one reply and guesses the next turn number.**
   - The arena accepts the second move in 145 of 146 cases.
   - In one case the menu had shifted, and Opus shot itself on a known live shell. That is its only such shot in 1,106. Its own comment: "the numbering shifted".
   - Sonnet (24) and Haiku 5.5 (9) also send two moves, but with the same turn number, so the arena refuses the second.
2. **Keeping the turn into the next load with an inverter.** With a known live last shell and an inverter in hand, a player can invert the shell and shoot itself. The shot is then a blank, so it moves first in the next load, at the cost of a sure hit.
   - The rules allow it. A blank fired at yourself keeps the turn, also across a reload. In the replays this held 2,726 times out of 2,726.
   - Rate per such decision: Sol 49/350, Terra 37/306, Astra 17/120, Luna 33/464, Haiku 4.5 21/309, Sonnet 18/533, Opus 9/248, Haiku 5.5 5/441.
   - No model did it with the opponent at 1 HP.
3. **Dead rubbers.** Prizes are 70k, 75k and 80k, so after a 2-0 start round 3 cannot change the winner. That was 127 of 241 Opus matches. In those round 3s Opus wrote about 30% fewer output tokens: xhigh 731 per call against 1,094, medium 166 against 225. It often says the match is already won.
4. **Smoking at full health is steal denial.**
   - Outside Luna, 75 of 79 cigarettes smoked at full health came while the opponent held adrenaline. At other times the opponent holds adrenaline 26–41% of the time.
   - Haiku 5.5 does it only at max (16/159) and xhigh (5/157). Haiku 4.5 never does (0/707).
   - Luna's 84 of 1,230 are mostly plain waste at off, low and medium: off 14%, low 16%, medium 7%, high to max 1–2%.
5. **Opus calls its opponent "the dealer"** in 115 calls across 79 matches, rising from 0.6% of calls at low to 2.2% at xhigh. The word appears in no view and not in the prompt. It comes from the original game.
6. **The Haiku models rarely take a likely-free self-shot.** The case: an unknown chamber, the live count known exactly, and under 50% live.
   - Haiku 5.5 shoots itself 14% of the time (58/413) and Haiku 4.5 23% (118/509).
   - The others do so 49–70% of the time: Opus 112/161, Astra 57/81, Sol 225/347, Sonnet 374/575, Terra 171/325, Luna 270/546.
7. **Luna often acts against shells known from counting.** The behaviour is measured. The cause is not: a failure to count is one guess.
   - It shoots itself into a shell the public log proves live: off 58/226, low 64/215, medium 106/553, high 21/272, xhigh 18/313, max 15/309. When the magnifier showed live it almost never does (0–3%).
   - At medium it gives reasoning tokens to only 42% of calls. Moves with no reasoning do this 25% of the time (82/325), against 11% (24/228) with reasoning.
   - 40 of its 92 self-inflicted deaths were on a provably live last shell.
8. **Effort ladders** (win share in each model's own sweep):

   | Model | Seats per effort | Win share by effort |
   |---|---|---|
   | Luna | 100 | off .28, low .27, medium .39, high .62, xhigh .72, max .72 |
   | Haiku 4.5 | 80 | off .29; minimal, low, medium, high .51–.59 in no order |
   | Haiku 5.5 | 100 | off .31, low .45, medium .45, high .54, max .60, xhigh .65 |
   | Sonnet | 100 | low .35, off .43, medium .45, high .51, xhigh .58, max .68 |
   | Sol | 80 | .46–.49 at every effort below max, max .59 |
   | Terra | 80 | low .40, medium .45, high .46, max .59, xhigh .60 |
   | Opus, tournament 2 | 20–60 | low .35, high .45, medium .48, xhigh .65 |

   - Haiku 5.5 max had 9 times the list-price cost of xhigh ($95 against $11 in all) and won less, 9 of 20 against xhigh head to head.
9. **Sonnet at max effort sometimes never reaches a move.**
   - 4 calls stopped at the 128,000-token output cap after about 16 minutes each, at a list-price cost of about $1.30 apiece.
   - A max seat has a list-price cost of $4.20 per match and spends 37 minutes waiting on the model, against $0.48 for xhigh.
10. **Sonnet "off" still thinks.** 57% of its "off" replies carry reasoning tokens, 113 on average, more than low's 74. Haiku 5.5 and Luna at off have none. Effort labels do not mean the same thing across models.
11. **Sonnet at max thinks longer when behind.** It writes 18.6k characters of reasoning per call at −2 HP, against 5.3k at +2. Xhigh goes from 2.1k to 0.66k, and medium is flat. Hard positions are a confound.
12. **Astra reports few reasoning tokens and still wins.** The provider returns token counts and short summaries, which are not the whole of its internal computation.
    - 3,663 of its 4,075 replies have 0 reasoning tokens, and the most in any reply is 131. Its only reasoning text is 234 short titles, such as "Inverting blank .6".
    - It wins .72 in the cross-model games (luna 19/20) and .46 against Opus xhigh (n=41).
13. **Talk about what the opponent knows grows with effort.**
    - Opus inference words: xhigh 7.2% of calls, medium 0.8%. Haiku 5.5 words about the opponent's beliefs: max 20%, medium 0.3%.
    - Sonnet's game-theory words (minimax, Nash, backward induction): max 8.9%, every other effort 0.7% or less.
    - Part of this is only that higher efforts write more.
14. **Haiku 4.5 is upbeat.** 40% of its replies (5,369/13,564) open with "Excellent", "Perfect", "Great" or "Fantastic", sometimes just after losing health.
15. **Haiku 4.5 gets stuck in one position.** 22 of its 47 calls over 5,000 output tokens are in seed block 0, at the same kind of position: opponent at 1 HP, 1 live and 2 blank.
16. **Haiku 5.5 at off wastes its clue items.** It uses the phone with 2 or fewer shells left, when the phone shows nothing, 37 of 200 times (other efforts 0–8). It shoots the opponent on a known blank 153 of 230 times (max: 37 of 271).
17. **Coin flips go to the opponent, and a sawed gun is never turned on oneself.**
    - At exactly 50% live with no saw, the self-shot rate is 17% for Sol and Astra, 23% for Terra, 24% for Opus, 37% for Luna and 45% for Sonnet.
    - Sonnet's coin-flip self-shots rise with its own health, from 20% at 1 HP to 60% at 4.
    - Sawed self-shots: Sonnet 2/1,392, Opus 4/613, Sol 8/1,026.
18. **Protocol hygiene.**
    - Sol, Terra and Astra make exactly one `play_move` call per reply, with 0 wrong turn numbers.
    - Almost all failed calls are hub rate-limit cooldowns, not model errors. For example, 3,889 of Sonnet's 3,964 failed calls were cooldowns, and 40% of Sonnet max attempts failed.
19. **Sol's reasoning summaries drift** into the real-world meaning of items in 7 of its 497 texts: beer as a drink, the jammer as music. The moves themselves were fine.
20. **Items left at death.** Haiku 4.5 dies holding 3.56 items on average and Terra 3.55, against Luna's 2.75. Players jammed for a whole round add to this.

## Things that looked like patterns but are not

- Using the handsaw on an unknown chamber is common to every model (34–66% of saws), not a habit of one.
- Sawing a known live shell when a saw is legal is also common (53–61% for every model).
- Ejecting a known live shell with beer happens for every model (7–15% of beers).

## Patterns against regret

Each choice pattern above that is a single move, checked against [regret](regret.md): the minimax player's score of the move, in percentage points of the round win chance, from the deciding player's own information. A row takes the decisions where the pattern could have happened, splits them into those it matched and the rest, and gives the mean regret of each. "Same configs" is the mean of the rest for the same model and effort mix as the matched ones, so a weak model's share does not explain a gap. Numbers in brackets are the pattern's number above. The certain-live rows pool all models, where pattern 7 is Luna's, and the certain-blank rows belong to the known-shell measures of [beliefs-and-items.md](beliefs-and-items.md). The patterns that are not a single move are not in the table, the clue source `combined` is left out, and rates may differ slightly from the counts above where the definitions differ. The three last rows are in the section above on things that are not patterns. Casual pass: means over 125,150 searched decisions, no intervals, DeepSeek left out.

<!-- regret:start -->
128,332 searched decisions.

| pattern | matched | mean regret | other applicable | mean regret | same configs |
|---|---|---|---|---|---|
| Invert the last shell and shoot yourself, known live (2) | 232 | 10.1 | 3,140 | 1.5 | 1.3 |
| Smoke at full health, outside Luna (4) | 94 | 1.4 | 10,545 | 1.5 | 0.9 |
| Smoke at full health, outside Luna, opponent holds adrenaline (4) | 87 | 1.2 | 4,231 | 1.8 | 1.1 |
| Smoke at full health, Luna (4) | 95 | 4.2 | 2,761 | 2.4 | 2.8 |
| Shoot yourself, unknown chamber, under half live (6) | 1,658 | 5.5 | 1,813 | 4.5 | 3.3 |
| Shoot yourself on a certain live, from the count (7) | 450 | 27.4 | 13,118 | 1.6 | 2.3 |
| Shoot yourself on a certain live, from the glass | 17 | 20.6 | 7,128 | 2.6 | 6.5 |
| Shoot yourself on a certain live, from the phone | 100 | 26.7 | 1,838 | 2.0 | 3.1 |
| Shoot the opponent on a certain blank, not the last shell | 1,137 | 19.7 | 7,795 | 0.8 | 1.2 |
| Shoot the opponent on a certain blank, last shell | 1,513 | 3.5 | 3,178 | 2.2 | 2.9 |
| Use the phone with two or fewer shells left (16) | 511 | 2.5 | 10,954 | 3.1 | 5.2 |
| Shoot yourself at exactly half live, no saw (17) | 1,813 | 4.3 | 5,314 | 3.7 | 3.2 |
| Shoot yourself with the gun sawed (17) | 117 | 10.1 | 10,548 | 2.8 | 3.6 |
| Saw an unknown chamber (not a pattern) | 5,516 | 1.6 | 17,662 | 3.1 | 3.5 |
| Saw a certain live (not a pattern) | 4,743 | 0.3 | 2,515 | 5.2 | 3.5 |
| Beer a certain live (not a pattern) | 852 | 5.7 | 10,704 | 2.8 | 3.5 |
<!-- regret:end -->

- **Costly.** Shooting yourself on a shell you can prove live averages 27 points when proven by the count, against 1.6 for the other shots there. The glass (21, only 17 shots) and phone (27) rows are as bad. Shooting the opponent on the last shell's certain blank is mildly worse than the rest, 3.5 against 2.2. Shooting the opponent on a certain blank before the last shell costs 20 against 0.8. Inverting a known live last shell to keep the turn costs 10 against 1.5, and a self-shot with the gun sawed 10 against 2.8. Throwing a beer at a certain live costs 6 against 3 for the rest.
- **Cost little.** Using the phone with two or fewer shells left averages 2.5. Sawing an unknown chamber averages 1.6, and sawing a certain live 0.3.
- **No clear gap.** Smoking your own cigarettes at full health averages 1.4 points outside Luna (1.2 while the opponent holds adrenaline), against 1.5 for the other moves there. Luna's 95 such smokes average 4.2 against 2.4, which is a small sample. Shooting yourself at exactly half live is 4.3 against 3.7 for shooting the opponent. The self-shot the Haiku models skip, an unknown chamber under half live, is 5.5 against 4.5, so skipping it shows no cost here.
- **Limits.** The item rows (smoking, phone, saws) are only as good as the evaluator's untrained item weights, so "cost little" there means the evaluator values the item little. Shots on the last shell end at the next reload, which the search scores as a static leaf. Many of the other rows have more than three shells left, where most searches stop early. Smoking counts only the player's own cigarettes, not ones stolen with adrenaline: 94 decisions outside Luna and 95 for Luna; pattern 4's counts of 79 and 84 above were not refreshed.

Rerun with `python3 tools/arena/analysis/patterns_regret.py --doc docs/arena/analysis/patterns.md`. This table and its prose use the full data. The scope at the top of this page says what the rest uses.

## Claude calls mention an organization instruction

Some Sonnet and Haiku 5.5 replies at high effort mention an instruction about "LibKey" scholarly-research access and then set it aside. This happened in 38 calls in 38 matches: Sonnet max 25, Sonnet xhigh 2 and Haiku 5.5 max 11, mostly on the model's first move of a match. The arena prompt stored with each of those matches does not contain it. So it was added after the request left the arena, on the model-provider side. It only shows up where long reasoning restates the system prompt, so it probably reached every Claude call. No effect on play was seen.
