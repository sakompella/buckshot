# Play patterns

Patterns in how the models played and reasoned in the arena. Each one was found in the traces and then checked again with an independent query against the analysis database ([database.md](../database.md)) and the derived `knowledge.sqlite` ([beliefs-and-items.md](beliefs-and-items.md)). This is a casual pass: counts and rates, no intervals. Treat any gap of a few points on 20–100 seats as noise.

Scope:
- Decision rates use the 2,118 scored matches with no DeepSeek seat.
- Call counts (tokens, costs, tool calls, reasoning text) include every started match.
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
7. **Luna does not count shells.**
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

   - Haiku 5.5 max cost 9 times as much as xhigh ($95 against $11 in all) and won less, 9 of 20 against xhigh head to head.
9. **Sonnet at max effort sometimes never reaches a move.**
   - 4 calls stopped at the 128,000-token output cap after about 16 minutes each, at about $1.30 apiece.
   - A max seat costs $4.60 per match and spends 37 minutes waiting on the model, against $0.48 for xhigh.
10. **Sonnet "off" still thinks.** 57% of its "off" replies carry reasoning tokens, 113 on average, more than low's 74. Haiku 5.5 and Luna at off have none. Effort labels do not mean the same thing across models.
11. **Sonnet at max thinks longer when behind.** It writes 18.6k characters of reasoning per call at −2 HP, against 5.3k at +2. Xhigh goes from 2.1k to 0.66k, and medium is flat. Hard positions are a confound.
12. **Astra barely thinks and still wins.**
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
- Ejecting a known live shell with beer happens for every model (6–15% of beers).

## Claude calls mention an organization instruction

Some Sonnet and Haiku 5.5 replies at high effort mention an instruction about "LibKey" scholarly-research access and then set it aside. This happened in 38 calls in 38 matches: Sonnet max 25, Sonnet xhigh 2 and Haiku 5.5 max 11, mostly on the model's first move of a match. The arena prompt stored with each of those matches does not contain it. So it was added after the request left the arena, on the model-provider side. It only shows up where long reasoning restates the system prompt, so it probably reached every Claude call. No effect on play was seen.
