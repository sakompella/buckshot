# Beliefs and items

What each model knew about the shotgun when it chose a move, whether it acted on that knowledge, what happened to its items, and whether it chose the same way in the same position. Every judgement uses only the deciding player's own information: the public log and its own clues. Another player's clues and the hidden shell order never enter. The tables call these choice patterns. A move is called dominated only where the player's own information shows it.

DeepSeek (`deepseek-v4.1-flash`) is left out entirely. Every match with a DeepSeek seat is dropped from every table below, including its opponents' moves in those matches.

## Summary

- **Acting on a known shell.** Opus 5.5 at every effort, Astra, Sol and Sonnet almost never shoot against a chamber they know. Opus shot the opponent on a known blank or itself on a known live 1 time in 1,134 such shots in tournament 2, and 0 in 327 in tournament 3. Haiku 4.5 at every effort often does. So do Haiku 5.5 and Luna, most at off, low and medium; their rates fall steadily with effort but stay above the others at max. Among the medium cross-model games:
  - Luna shot itself on a known live 14% of the time (74/547).
  - Haiku 4.5 shot the opponent on a known blank with shells still to come 32% of the time (74/228). For Haiku 5.5 it was 17% (36/209), and for Luna 25% (69/280).
- **The last shell.** Shooting the opponent with a known blank is most common on the gun's last shell. In the replays a blank shot at yourself always kept the move, also across the reload (430/430), and a blank at the opponent always passed it. The last-shell rate is 52–70% for Haiku 4.5, Haiku 5.5 and Luna at medium. It is 8.5% (8/94) for Sonnet medium and 1.8% (2/113) for Opus medium.
- **Phone clues are kept worse than magnifier clues.** Over all models in the medium cross-model games, a chamber known from the glass was shot against 1.8% of the time (46/2,524), and one known from the phone 8.7% (74/853). The effort sweeps show the same, 2.9% (196/6,839) against 13% (309/2,455). Luna medium: glass 1.8% (6/333), phone 38% (38/100).
- **Forgetting with time.** Glass clues are acted against more as moves pass. In the effort sweeps it is 2.0% (74/3,712) on the very next move, 3.6% (84/2,361) one move later and 4.9% (37/754) after two or three. Phone clues are acted against at 10–15% at every distance, already 11% (49/444) on the next move. That points to the offset reasoning, not memory.
- **How often an item settles the chamber.** About a quarter of every model's shots are at a chamber known from its own glass or phone: 20% (328/1,616) for Haiku 4.5 up to 27% (476/1,751) for Sonnet in the medium cross-model games. About a third more are known from counting. Blind shots taken while holding a magnifier are rare, at most 3.1% (24/820, Haiku 4.5).
- **Items.**
  - Models use 46–68% of the items they place.
  - 5–10% are stolen with adrenaline. 11–31% are still held when their owner dies, and 5–23% when the round ends.
  - 84–95% of deaths leave at least one unused item, about three on average, most often an inverter or a beer.
  - Items are used early when they are used at all. The median is one of the owner's own decisions after placement, about six or seven accepted moves.
- **Favourite items.** By the rate of using an item when it is a legal move, the magnifier is the favourite for 7 of the 8 medium models (48–68%). Terra prefers the jammer, 67% (204/306) at medium and 60–74% at every effort. The inverter is the least used item for every model: 7–17% of the decisions where it is legal at medium, and 24–45% of the inverters placed are ever used. With adrenaline, the jammer and the magnifier are what models steal. Astra also steals cigarettes, 27% (61/228).
- **Same position, same choice.** About a quarter to a third of decisions (11–43% by model, exact positions) fall in a position the same model met again: same board, same log since the load, same menu. Opus medium and xhigh in tournaments 2 and 3 are the exception: one pairing alone gives few repeats. Two decisions in the same position differ:
  - 4.9% of the time for Astra and 7.7% for Sol;
  - 11–12% for Opus and Sonnet;
  - 22–24% for Haiku 5.5 and Terra;
  - 32% for Luna and 36% for Haiku 4.5 (medium cross-model, exact positions).
- **Effort variants.**
  - Sol's variants agree with each other about as often as each agrees with itself: 84–92% across, 88–94% within.
  - Opus's do too: medium vs xhigh 89% across against 89–92% within.
  - Sonnet max plays differently from the other Sonnet levels, 66–78% across against 88–92% within. So do Haiku 5.5 off (59–69% against 76–84%) and Luna low against Luna max (50% against 67% and 81%).

## How it was measured

**Own information.** `web/scripts/arena-knowledge.ts` replays every replay-validated match in the analysis database through `replayOf`, the viewer's replay over the generated Bend rules. Before each accepted move it takes the deciding player's log since the latest load: the public events, plus the secrets that player heard, in the order it heard them. That log goes to the shell belief of the Bend minimax player (`belief.orders.log` in `sim/bend-mp/player/belief.bend`). It enumerates every shell order the log allows, with multiplicity, once with the public log alone and once with the player's own clues as well. Everything else is read off those orders: the live/blank composition left, the chance each position is live, and which positions are certain. TypeScript only marshals the log and counts orders. It never applies a shot, beer or inverter itself. The output is a separate SQLite database, `_work/arena/analysis/derived/knowledge.sqlite`, with one row per non-forced decision, per clue, per placed item and per death. `web/scripts/arena-knowledge-report.ts` turns it into the tables below.

- **Chamber certain:** every order the player's log allows has the same chambered shell.
- **Source of certainty:** *public* if the public log alone settles it (counting, for example when only live shells are left). Otherwise *glass* or *phone*: the most recent single clue that settles it together with the public log. *Combined* means only several clues together settle it. A clue from an item taken with adrenaline counts with its item.
- **Moves since the clue:** accepted moves by either player, forced grabs included, between the move that produced the clue and the shot. 0 is the very next move.
- **Item fates:** a ledger follows each placed item through the public log. Its owner uses it, or it is stolen with adrenaline, or it is still held when the owner dies, or it is still held when the round or match ends (censored). At every decision the ledger must match the board slot by slot.
- **Use when legal:** at each agent decision, whether a move that spends the item is on the menu, and whether the player chose it. "Jam Player X" spends a jammer. Steals are counted separately from the player's own items.
- **Same position:** two decisions share an *exact* position when all of these are the same: the board (health, jam state, items, cash, round, saw, and the live and blank counts shown at the load), the deciding player's whole log since the load, the legal moves, and the instructions. Players are named relative to the decider, never by letter. A looser *belief* position replaces the log with the public and private shell beliefs, plus how many clue items each opponent used this load.

**Counted.** Completed (scored) matches only, and only the agents' own moves. Forced grabs and the two fallback moves are not counted. Models are `entrants.model` plus effort. Code versions are pooled. Cohorts are never pooled: tournament 1's medium cross-model games, tournament 1's effort sweeps, tournament 2 (Opus effort) and tournament 3 (Opus xhigh vs Astra). The same model and effort appear as separate rows in different cohorts.

**Intervals.** Every rate is numerator/denominator with a 95% percentile interval from 2,000 resamples of seed blocks (`matches.seed_block_id`) within the row, never of single matches or moves. The resampler is seeded, so a rerun prints the same intervals. For consistency and agreement, the interval is over pairs of distinct decisions: a pair weighs the product of its two blocks' resample counts, and a decision never pairs with its own copy. Without that, a block drawn twice would agree with itself. The non-modal share has no interval for that reason.

**Checks.**
- On all 112,548 non-forced decisions of the 2,244 replay-validated matches, the true gun was one of the orders the player's log allows. The true gun was read only for this check and is not stored. Every chamber the player's log called certain was right. The previous build (2,184 matches) was verified in full. For the rebuild, the verify ran on a 200-match sample.
- The item ledger agreed with the board's slots at every decision of every match, with no contradictions.
- `web/test/knowledge.test.ts` checks hand-computed histories:
  - a phone clue keeping its offset through two shots;
  - an inverter after the magnifier;
  - a beer before a phone-clued shell;
  - a reload clearing clues;
  - clues that only settle the chamber together;
  - an adrenaline-stolen magnifier;
  - the item ledger, and letter-free position keys.
- Hand traces of real matches, checked shell by shell:
  - a stolen magnifier followed by a stolen inverter (`claude-opus-5-5-xhigh_gpt-6-astra_b0_p1`, moves 60–63);
  - a phone clue on the 6th shell that becomes the chamber six moves later, through shots, a second clue and a beer (`…_b10_p0`, moves 21–28);
  - three phone clues around a beer that settle the chamber only together (`…_b12_p0`, move 49).
- A rerun of 40 matches with the final code reproduced the full run's rows exactly.

## Limits

- Views are reconstructed from the logs with today's rules, as in the analysis database. They are not the prompts the models saw. A model that misread its log is judged by what the log showed.
- "Public" certainty assumes the player counts shells. Most shots against a known shell come from counting, mainly on the last shell, not from forgotten clues.
- Keeping the move with a self-shot blank is measured from the replays (two players, opponent not jammed). With a jammed opponent, a blank at the opponent skips their turn and costs the jam instead.
- The effort sweeps pair each level with every other level of the same model, so their opponents differ from the cross-model games. Opus low in tournament 2 played only medium (20 matches), and tournament 3 is one pairing. Both have almost no repeated positions.
- Partial and skipped matches are left out, as are forced grabs and fallback moves.

## Reproduce

From `web/`, after `bun run rules` (Bend comes from `$BEND`, `bend` on PATH or the pinned build):

    nice -n 10 bun scripts/arena-knowledge.ts --db <buckshot.sqlite> --out <derived>/knowledge.sqlite --verify   # about 22 minutes
    nice -n 10 bun scripts/arena-knowledge-report.ts --db <derived>/knowledge.sqlite                            # about 2 minutes
    bun scripts/arena-knowledge.ts --db <buckshot.sqlite> --trace <match name>                                 # one match, decision by decision

# Tables

Generated by `scripts/arena-knowledge-report.ts`.

## Coverage

| Cohort | Matches | Seed blocks | Agent decisions | Shots | Shots with a certain chamber |
|---|---|---|---|---|---|
| t1 cross-model medium | 560 | 280 | 27819 | 13480 | 7982 |
| t1 effort sweep | 1500 | 750 | 77111 | 36566 | 21623 |
| t2 opus effort | 80 | 40 | 3865 | 1838 | 1134 |
| t3 astra vs opus xhigh | 41 | 21 | 2085 | 1001 | 613 |

## Shots with a certain chamber

Shooting the opponent on a known blank and yourself on a known live. Certainty is the player's own: the public log, its own clues, or both. In the replays a blank shot at yourself always kept the move, also across a reload, and a blank shot at the opponent always passed it, so the blank columns split the gun's last shell from the rest.

### t1 cross-model medium

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-haiku-4-5-20251001 medium | 32% (74/228) [25%, 41%] | 62% (62/100) [52%, 71%] | 3.8% (18/468) [1.9%, 6.2%] |
| claude-haiku-5-5 medium | 17% (36/209) [11%, 24%] | 70% (74/106) [59%, 80%] | 0.4% (3/671) [0%, 1.0%] |
| claude-opus-5-5 medium | 0% (0/270) [0%, 0%] | 1.8% (2/113) [0%, 4.5%] | 0.1% (1/747) [0%, 0.4%] |
| claude-sonnet-5-5 medium | 0% (0/245) [0%, 0%] | 8.5% (8/94) [3.3%, 14%] | 0.7% (5/751) [0.1%, 1.3%] |
| gpt-5.6-terra medium | 4.7% (12/255) [2.3%, 7.7%] | 13% (20/154) [6.8%, 20%] | 1.0% (6/589) [0.3%, 1.9%] |
| gpt-6-astra medium | 0% (0/212) [0%, 0%] | 0.8% (1/128) [0%, 2.6%] | 0% (0/671) [0%, 0%] |
| gpt-6-luna medium | 25% (69/280) [20%, 31%] | 52% (71/136) [43%, 61%] | 14% (74/547) [10%, 16%] |
| gpt-6.1-sol medium | 0.8% (2/236) [0%, 2.1%] | 6.7% (7/104) [1.9%, 13%] | 0% (0/668) [0%, 0%] |

### t1 effort sweep

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-haiku-4-5-20251001 high | 38% (42/112) [29%, 46%] | 77% (70/91) [70%, 84%] | 3.8% (13/345) [1.6%, 6.3%] |
| claude-haiku-4-5-20251001 low | 38% (56/146) [30%, 48%] | 63% (59/94) [52%, 75%] | 3.6% (12/331) [1.9%, 5.4%] |
| claude-haiku-4-5-20251001 medium | 33% (49/148) [24%, 42%] | 68% (64/94) [57%, 80%] | 2.8% (10/356) [1.3%, 4.9%] |
| claude-haiku-4-5-20251001 minimal | 42% (70/165) [31%, 53%] | 65% (58/89) [55%, 74%] | 5.8% (18/312) [3.3%, 8.7%] |
| claude-haiku-4-5-20251001 off | 47% (83/177) [37%, 57%] | 73% (69/94) [66%, 82%] | 7.0% (21/300) [3.7%, 11%] |
| claude-haiku-5-5 high | 16% (23/147) [9.7%, 22%] | 77% (65/84) [65%, 89%] | 0.6% (3/478) [0%, 1.3%] |
| claude-haiku-5-5 low | 31% (47/153) [23%, 39%] | 84% (76/91) [74%, 92%] | 0.9% (4/439) [0.2%, 1.9%] |
| claude-haiku-5-5 max | 6.5% (12/186) [3.0%, 11%] | 29% (25/85) [19%, 42%] | 0% (0/510) [0%, 0%] |
| claude-haiku-5-5 medium | 23% (36/160) [15%, 30%] | 85% (73/86) [79%, 91%] | 1.1% (5/462) [0.2%, 2.0%] |
| claude-haiku-5-5 off | 56% (81/144) [46%, 66%] | 84% (72/86) [76%, 91%] | 0% (0/351) [0%, 0%] |
| claude-haiku-5-5 xhigh | 8.2% (14/170) [4.3%, 13%] | 70% (57/82) [57%, 82%] | 0% (0/515) [0%, 0%] |
| claude-sonnet-5-5 high | 0% (0/173) [0%, 0%] | 1.2% (1/86) [0%, 4.1%] | 0.4% (2/462) [0%, 1.1%] |
| claude-sonnet-5-5 low | 0.6% (1/162) [0%, 2.1%] | 9.1% (8/88) [2.7%, 17%] | 0.4% (2/470) [0%, 1.1%] |
| claude-sonnet-5-5 max | 0.5% (1/197) [0%, 1.7%] | 0% (0/105) [0%, 0%] | 0% (0/483) [0%, 0%] |
| claude-sonnet-5-5 medium | 0.6% (1/163) [0%, 2.0%] | 9.5% (6/63) [2.8%, 18%] | 0.2% (1/495) [0%, 0.6%] |
| claude-sonnet-5-5 off | 1.3% (2/153) [0%, 3.5%] | 14% (8/58) [5.7%, 24%] | 0.8% (4/502) [0.2%, 1.6%] |
| claude-sonnet-5-5 xhigh | 0.5% (1/186) [0%, 1.8%] | 2.7% (2/74) [0%, 6.8%] | 0% (0/463) [0%, 0%] |
| gpt-5.6-terra high | 4.7% (7/150) [1.2%, 9.3%] | 14% (12/87) [7.0%, 22%] | 2.7% (9/336) [1.2%, 4.4%] |
| gpt-5.6-terra low | 7.0% (9/128) [2.0%, 12%] | 18% (16/89) [9.4%, 28%] | 2.7% (9/336) [1.1%, 4.5%] |
| gpt-5.6-terra max | 1.8% (3/171) [0%, 3.9%] | 3.7% (4/108) [0.9%, 7.3%] | 0.3% (1/358) [0%, 0.9%] |
| gpt-5.6-terra medium | 9.8% (13/132) [4.9%, 16%] | 12% (8/67) [5.3%, 20%] | 1.5% (5/326) [0.3%, 2.9%] |
| gpt-5.6-terra xhigh | 3.6% (6/165) [0.7%, 7.1%] | 9.6% (8/83) [4.3%, 17%] | 1.1% (4/350) [0.3%, 2.4%] |
| gpt-6-luna high | 14% (28/196) [9.4%, 20%] | 31% (41/133) [22%, 40%] | 5.6% (26/464) [3.9%, 7.5%] |
| gpt-6-luna low | 39% (81/206) [32%, 47%] | 70% (81/116) [62%, 78%] | 23% (80/345) [18%, 29%] |
| gpt-6-luna max | 9.9% (21/212) [6.1%, 14%] | 29% (37/127) [21%, 38%] | 3.7% (18/493) [2.1%, 5.5%] |
| gpt-6-luna medium | 23% (46/197) [18%, 29%] | 52% (71/136) [43%, 61%] | 14% (57/401) [11%, 18%] |
| gpt-6-luna off | 40% (75/189) [33%, 46%] | 73% (76/104) [64%, 81%] | 20% (71/349) [16%, 24%] |
| gpt-6-luna xhigh | 11% (20/183) [6.9%, 16%] | 36% (38/106) [24%, 48%] | 3.9% (19/484) [2.3%, 5.6%] |
| gpt-6.1-sol high | 3.0% (4/133) [0.7%, 6.3%] | 2.8% (2/71) [0%, 7.3%] | 0% (0/363) [0%, 0%] |
| gpt-6.1-sol low | 0% (0/130) [0%, 0%] | 8.1% (5/62) [1.6%, 17%] | 0% (0/346) [0%, 0%] |
| gpt-6.1-sol max | 0.8% (1/129) [0%, 2.6%] | 0% (0/103) [0%, 0%] | 0% (0/363) [0%, 0%] |
| gpt-6.1-sol medium | 0% (0/135) [0%, 0%] | 5.6% (4/72) [1.4%, 11%] | 0% (0/359) [0%, 0%] |
| gpt-6.1-sol xhigh | 2.2% (3/134) [0%, 5.5%] | 1.2% (1/84) [0%, 4.3%] | 0% (0/346) [0%, 0%] |

### t2 opus effort

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-opus-5-5 high | 0% (0/73) [0%, 0%] | 0% (0/35) [0%, 0%] | 0% (0/172) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/36) [0%, 0%] | 6.7% (1/15) [0%, 19%] | 0% (0/91) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/109) [0%, 0%] | 0% (0/40) [0%, 0%] | 0% (0/277) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/69) [0%, 0%] | 0% (0/34) [0%, 0%] | 0% (0/183) [0%, 0%] |

### t3 astra vs opus xhigh

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-opus-5-5 xhigh | 0% (0/82) [0%, 0%] | 0% (0/37) [0%, 0%] | 0% (0/208) [0%, 0%] |
| gpt-6-astra medium | 1.4% (1/73) [0%, 4.2%] | 0% (0/32) [0%, 0%] | 0% (0/181) [0%, 0%] |

## By where the certainty came from

Shots against the known shell, by source. A clue taken with adrenaline counts with its item.

| Cohort | public | glass | phone | combined |
|---|---|---|---|---|
| t1 cross-model medium | 9.2% (424/4590) [8.0%, 10%] | 1.8% (46/2524) [1.2%, 2.5%] | 8.7% (74/853) [6.7%, 11%] | 6.7% (1/15) [0%, 18%] |
| t1 effort sweep | 15% (1840/12279) [14%, 16%] | 2.9% (196/6839) [2.3%, 3.4%] | 13% (309/2455) [11%, 14%] | 4.0% (2/50) [0%, 9.3%] |
| t2 opus effort | 0.2% (1/589) [0%, 0.5%] | 0% (0/367) [0%, 0%] | 0% (0/176) [0%, 0%] | 0% (0/2) [0%, 0%] |
| t3 astra vs opus xhigh | 0.3% (1/339) [0%, 1.0%] | 0% (0/199) [0%, 0%] | 0% (0/73) [0%, 0%] | 0% (0/2) [0%, 0%] |

### t1 cross-model medium, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-haiku-4-5-20251001 medium | 11% (30/269) [7.3%, 15%] | 29% (17/59) [17%, 40%] |
| claude-haiku-5-5 medium | 3.5% (10/283) [1.8%, 5.6%] | 4.3% (5/116) [0.9%, 8.4%] |
| claude-opus-5-5 medium | 0% (0/307) [0%, 0%] | 0.7% (1/136) [0%, 2.2%] |
| claude-sonnet-5-5 medium | 0% (0/357) [0%, 0%] | 0.8% (1/119) [0%, 2.8%] |
| gpt-5.6-terra medium | 0% (0/362) [0%, 0%] | 13% (11/86) [5.6%, 22%] |
| gpt-6-astra medium | 0% (0/303) [0%, 0%] | 0% (0/117) [0%, 0%] |
| gpt-6-luna medium | 1.8% (6/333) [0.6%, 3.4%] | 38% (38/100) [30%, 46%] |
| gpt-6.1-sol medium | 0% (0/310) [0%, 0%] | 0.8% (1/120) [0%, 2.7%] |

### t1 effort sweep, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-haiku-4-5-20251001 high | 8.2% (14/170) [4.3%, 13%] | 30% (10/33) [15%, 48%] |
| claude-haiku-4-5-20251001 low | 9.7% (16/165) [5.2%, 14%] | 42% (19/45) [27%, 59%] |
| claude-haiku-4-5-20251001 medium | 6.4% (12/187) [2.8%, 11%] | 40% (10/25) [21%, 59%] |
| claude-haiku-4-5-20251001 minimal | 16% (28/175) [9.1%, 24%] | 44% (17/39) [31%, 55%] |
| claude-haiku-4-5-20251001 off | 17% (32/189) [11%, 23%] | 43% (23/54) [31%, 57%] |
| claude-haiku-5-5 high | 1.9% (4/208) [0%, 4.3%] | 7.3% (7/96) [2.2%, 13%] |
| claude-haiku-5-5 low | 4.8% (11/228) [2.0%, 8.4%] | 17% (13/76) [7.9%, 28%] |
| claude-haiku-5-5 max | 0.4% (1/236) [0%, 1.4%] | 0% (0/108) [0%, 0%] |
| claude-haiku-5-5 medium | 5.4% (13/240) [2.6%, 8.2%] | 12% (9/73) [5.3%, 20%] |
| claude-haiku-5-5 off | 11% (23/205) [6.0%, 17%] | 47% (28/59) [34%, 61%] |
| claude-haiku-5-5 xhigh | 0.9% (2/223) [0%, 2.4%] | 1.9% (2/106) [0%, 5.1%] |
| claude-sonnet-5-5 high | 0% (0/231) [0%, 0%] | 0.9% (1/109) [0%, 3.2%] |
| claude-sonnet-5-5 low | 0% (0/252) [0%, 0%] | 1.3% (1/78) [0%, 4.4%] |
| claude-sonnet-5-5 max | 0% (0/248) [0%, 0%] | 1.0% (1/96) [0%, 3.5%] |
| claude-sonnet-5-5 medium | 0% (0/253) [0%, 0%] | 0% (0/89) [0%, 0%] |
| claude-sonnet-5-5 off | 0% (0/250) [0%, 0%] | 3.0% (3/99) [0%, 6.7%] |
| claude-sonnet-5-5 xhigh | 0% (0/207) [0%, 0%] | 0.9% (1/115) [0%, 2.9%] |
| gpt-5.6-terra high | 0% (0/179) [0%, 0%] | 11% (5/47) [2.3%, 20%] |
| gpt-5.6-terra low | 0% (0/196) [0%, 0%] | 18% (5/28) [6.5%, 31%] |
| gpt-5.6-terra max | 0% (0/190) [0%, 0%] | 2.3% (2/86) [0%, 6.2%] |
| gpt-5.6-terra medium | 0% (0/184) [0%, 0%] | 19% (7/37) [8.3%, 29%] |
| gpt-5.6-terra xhigh | 0.5% (1/188) [0%, 1.7%] | 5.8% (4/69) [0%, 14%] |
| gpt-6-luna high | 0.8% (2/265) [0%, 1.9%] | 27% (18/66) [17%, 39%] |
| gpt-6-luna low | 7.1% (14/197) [3.8%, 11%] | 54% (43/79) [43%, 66%] |
| gpt-6-luna max | 0.4% (1/231) [0%, 1.4%] | 12% (11/92) [6.4%, 18%] |
| gpt-6-luna medium | 2.5% (6/239) [0.4%, 4.8%] | 40% (27/67) [29%, 52%] |
| gpt-6-luna off | 8.1% (15/185) [4.7%, 12%] | 50% (33/66) [39%, 62%] |
| gpt-6-luna xhigh | 0.4% (1/233) [0%, 1.4%] | 13% (9/72) [6.1%, 20%] |
| gpt-6.1-sol high | 0% (0/177) [0%, 0%] | 0% (0/96) [0%, 0%] |
| gpt-6.1-sol low | 0% (0/191) [0%, 0%] | 0% (0/73) [0%, 0%] |
| gpt-6.1-sol max | 0% (0/174) [0%, 0%] | 0% (0/92) [0%, 0%] |
| gpt-6.1-sol medium | 0% (0/172) [0%, 0%] | 0% (0/91) [0%, 0%] |
| gpt-6.1-sol xhigh | 0% (0/171) [0%, 0%] | 0% (0/94) [0%, 0%] |

### t2 opus effort, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-opus-5-5 high | 0% (0/89) [0%, 0%] | 0% (0/41) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/51) [0%, 0%] | 0% (0/17) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/138) [0%, 0%] | 0% (0/68) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/89) [0%, 0%] | 0% (0/50) [0%, 0%] |

### t3 astra vs opus xhigh, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-opus-5-5 xhigh | 0% (0/87) [0%, 0%] | 0% (0/38) [0%, 0%] |
| gpt-6-astra medium | 0% (0/112) [0%, 0%] | 0% (0/35) [0%, 0%] |

## By accepted moves since the clue

Shots against a chamber known from a clue (glass or phone), by the accepted moves of either player between the clue and the shot. 0 is the very next move.

### glass

| Cohort | 0 | 1 | 2–3 | 4+ |
|---|---|---|---|---|
| t1 cross-model medium | 1.3% (19/1513) [0.7%, 1.9%] | 2.5% (21/837) [1.4%, 3.8%] | 3.5% (6/173) [1.1%, 6.6%] | 0% (0/1) [0%, 0%] |
| t1 effort sweep | 2.0% (74/3712) [1.4%, 2.6%] | 3.6% (84/2361) [2.7%, 4.5%] | 4.9% (37/754) [3.4%, 6.5%] | 8.3% (1/12) [0%, 27%] |
| t2 opus effort | 0% (0/188) [0%, 0%] | 0% (0/133) [0%, 0%] | 0% (0/46) [0%, 0%] | – |
| t3 astra vs opus xhigh | 0% (0/118) [0%, 0%] | 0% (0/67) [0%, 0%] | 0% (0/14) [0%, 0%] | – |

### phone

| Cohort | 0 | 1 | 2–3 | 4+ |
|---|---|---|---|---|
| t1 cross-model medium | 5.4% (8/148) [2.0%, 9.0%] | 9.7% (20/206) [5.8%, 14%] | 6.8% (19/281) [3.7%, 10%] | 12% (27/218) [8.2%, 17%] |
| t1 effort sweep | 11% (49/444) [8.3%, 14%] | 10% (56/551) [7.8%, 13%] | 13% (116/876) [11%, 16%] | 15% (88/584) [12%, 18%] |
| t2 opus effort | 0% (0/36) [0%, 0%] | 0% (0/46) [0%, 0%] | 0% (0/69) [0%, 0%] | 0% (0/25) [0%, 0%] |
| t3 astra vs opus xhigh | 0% (0/9) [0%, 0%] | 0% (0/14) [0%, 0%] | 0% (0/29) [0%, 0%] | 0% (0/21) [0%, 0%] |

## How shots are informed

Each agent shot by what the player knew of the chamber: a clue from its own item (glass, phone or both), the public count, or nothing. The last column is blind shots taken while the player held a magnifying glass.

### t1 cross-model medium

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 medium | 20% (328/1616) [18%, 22%] | 29% (468/1616) [27%, 31%] | 51% (820/1616) [49%, 53%] | 2.9% (24/820) [1.6%, 4.5%] |
| claude-haiku-5-5 medium | 25% (404/1597) [23%, 28%] | 36% (582/1597) [34%, 39%] | 38% (611/1597) [36%, 41%] | 0.8% (5/611) [0.2%, 1.7%] |
| claude-opus-5-5 medium | 26% (448/1731) [24%, 28%] | 39% (682/1731) [37%, 41%] | 35% (601/1731) [33%, 37%] | 0% (0/601) [0%, 0%] |
| claude-sonnet-5-5 medium | 27% (476/1751) [25%, 30%] | 35% (614/1751) [33%, 37%] | 38% (661/1751) [36%, 40%] | 0.3% (2/661) [0%, 0.8%] |
| gpt-5.6-terra medium | 26% (450/1732) [23%, 28%] | 32% (548/1732) [29%, 34%] | 42% (734/1732) [40%, 45%] | 0.4% (3/734) [0%, 0.9%] |
| gpt-6-astra medium | 25% (422/1664) [23%, 28%] | 35% (589/1664) [33%, 37%] | 39% (653/1664) [37%, 42%] | 0% (0/653) [0%, 0%] |
| gpt-6-luna medium | 25% (433/1712) [23%, 27%] | 31% (530/1712) [29%, 33%] | 44% (749/1712) [42%, 46%] | 0.7% (5/749) [0%, 1.6%] |
| gpt-6.1-sol medium | 26% (431/1677) [24%, 28%] | 34% (577/1677) [33%, 36%] | 40% (669/1677) [38%, 42%] | 0% (0/669) [0%, 0%] |

### t1 effort sweep

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 19% (203/1043) [16%, 23%] | 33% (345/1043) [31%, 36%] | 47% (495/1043) [44%, 51%] | 5.9% (29/495) [3.2%, 8.9%] |
| claude-haiku-4-5-20251001 low | 19% (210/1078) [17%, 23%] | 33% (361/1078) [30%, 36%] | 47% (507/1078) [44%, 50%] | 2.6% (13/507) [1.1%, 4.3%] |
| claude-haiku-4-5-20251001 medium | 19% (212/1112) [17%, 21%] | 35% (386/1112) [32%, 37%] | 46% (514/1112) [43%, 49%] | 5.3% (27/514) [2.6%, 8.3%] |
| claude-haiku-4-5-20251001 minimal | 20% (216/1063) [18%, 23%] | 33% (350/1063) [30%, 36%] | 47% (497/1063) [44%, 50%] | 1.6% (8/497) [0.6%, 2.7%] |
| claude-haiku-4-5-20251001 off | 23% (243/1062) [20%, 26%] | 31% (328/1062) [27%, 34%] | 46% (491/1062) [43%, 49%] | 0.8% (4/491) [0%, 1.9%] |
| claude-haiku-5-5 high | 26% (304/1181) [23%, 29%] | 34% (405/1181) [31%, 37%] | 40% (472/1181) [37%, 43%] | 0.4% (2/472) [0%, 1.0%] |
| claude-haiku-5-5 low | 26% (305/1161) [24%, 29%] | 33% (378/1161) [30%, 35%] | 41% (478/1161) [38%, 44%] | 0.4% (2/478) [0%, 1.4%] |
| claude-haiku-5-5 max | 29% (346/1210) [26%, 31%] | 36% (435/1210) [33%, 38%] | 35% (429/1210) [33%, 37%] | 2.6% (11/429) [1.2%, 4.1%] |
| claude-haiku-5-5 medium | 27% (315/1175) [24%, 30%] | 33% (393/1175) [30%, 36%] | 40% (467/1175) [36%, 44%] | 0.6% (3/467) [0%, 1.5%] |
| claude-haiku-5-5 off | 25% (267/1073) [22%, 28%] | 29% (314/1073) [26%, 33%] | 46% (492/1073) [43%, 49%] | 0% (0/492) [0%, 0%] |
| claude-haiku-5-5 xhigh | 28% (332/1200) [25%, 30%] | 36% (435/1200) [33%, 40%] | 36% (433/1200) [33%, 39%] | 0.7% (3/433) [0%, 1.7%] |
| claude-sonnet-5-5 high | 29% (344/1189) [26%, 32%] | 32% (377/1189) [29%, 34%] | 39% (468/1189) [36%, 43%] | 0% (0/468) [0%, 0%] |
| claude-sonnet-5-5 low | 29% (335/1175) [25%, 32%] | 33% (385/1175) [30%, 36%] | 39% (455/1175) [35%, 42%] | 0% (0/455) [0%, 0%] |
| claude-sonnet-5-5 max | 30% (344/1165) [27%, 32%] | 38% (441/1165) [35%, 41%] | 33% (380/1165) [30%, 35%] | 3.4% (13/380) [1.8%, 5.3%] |
| claude-sonnet-5-5 medium | 29% (345/1207) [26%, 32%] | 31% (376/1207) [28%, 34%] | 40% (486/1207) [38%, 43%] | 0% (0/486) [0%, 0%] |
| claude-sonnet-5-5 off | 30% (351/1182) [26%, 33%] | 31% (362/1182) [28%, 33%] | 40% (469/1182) [36%, 43%] | 0% (0/469) [0%, 0%] |
| claude-sonnet-5-5 xhigh | 28% (323/1142) [25%, 31%] | 35% (400/1142) [32%, 38%] | 37% (419/1142) [34%, 40%] | 0.5% (2/419) [0%, 1.2%] |
| gpt-5.6-terra high | 23% (227/968) [20%, 27%] | 36% (346/968) [32%, 39%] | 41% (395/968) [37%, 45%] | 0.3% (1/395) [0%, 0.8%] |
| gpt-5.6-terra low | 24% (228/954) [21%, 27%] | 34% (325/954) [31%, 37%] | 42% (401/954) [39%, 45%] | 0% (0/401) [0%, 0%] |
| gpt-5.6-terra max | 27% (276/1020) [23%, 31%] | 35% (361/1020) [32%, 38%] | 38% (383/1020) [34%, 42%] | 0% (0/383) [0%, 0%] |
| gpt-5.6-terra medium | 24% (221/931) [20%, 27%] | 33% (304/931) [30%, 36%] | 44% (406/931) [40%, 47%] | 0.5% (2/406) [0%, 1.2%] |
| gpt-5.6-terra xhigh | 26% (257/985) [23%, 30%] | 35% (341/985) [32%, 37%] | 39% (387/985) [35%, 43%] | 0.3% (1/387) [0%, 0.8%] |
| gpt-6-luna high | 26% (333/1303) [23%, 28%] | 35% (460/1303) [33%, 38%] | 39% (510/1303) [36%, 42%] | 0% (0/510) [0%, 0%] |
| gpt-6-luna low | 23% (276/1221) [20%, 25%] | 32% (391/1221) [29%, 35%] | 45% (554/1221) [42%, 49%] | 0.7% (4/554) [0.2%, 1.4%] |
| gpt-6-luna max | 24% (326/1331) [22%, 27%] | 38% (506/1331) [35%, 41%] | 37% (499/1331) [34%, 41%] | 0.6% (3/499) [0%, 1.3%] |
| gpt-6-luna medium | 24% (306/1280) [21%, 27%] | 33% (428/1280) [31%, 36%] | 43% (546/1280) [40%, 45%] | 0.9% (5/546) [0%, 2.0%] |
| gpt-6-luna off | 21% (252/1197) [19%, 23%] | 33% (390/1197) [31%, 35%] | 46% (555/1197) [44%, 49%] | 0.4% (2/555) [0%, 0.9%] |
| gpt-6-luna xhigh | 24% (310/1268) [22%, 27%] | 37% (463/1268) [33%, 40%] | 39% (495/1268) [36%, 42%] | 0.6% (3/495) [0%, 1.6%] |
| gpt-6.1-sol high | 29% (274/939) [26%, 33%] | 31% (293/939) [28%, 34%] | 40% (372/939) [36%, 43%] | 0% (0/372) [0%, 0%] |
| gpt-6.1-sol low | 28% (264/928) [26%, 31%] | 30% (274/928) [27%, 32%] | 42% (390/928) [39%, 46%] | 0% (0/390) [0%, 0%] |
| gpt-6.1-sol max | 28% (267/969) [24%, 31%] | 34% (328/969) [31%, 37%] | 39% (374/969) [35%, 42%] | 0.3% (1/374) [0%, 0.9%] |
| gpt-6.1-sol medium | 28% (264/937) [25%, 31%] | 32% (302/937) [29%, 35%] | 40% (371/937) [35%, 43%] | 0% (0/371) [0%, 0%] |
| gpt-6.1-sol xhigh | 29% (268/917) [25%, 33%] | 32% (296/917) [29%, 36%] | 38% (353/917) [35%, 42%] | 0.6% (2/353) [0%, 1.4%] |

### t2 opus effort

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-opus-5-5 high | 28% (130/464) [23%, 33%] | 32% (150/464) [26%, 38%] | 40% (184/464) [34%, 46%] | 0% (0/184) [0%, 0%] |
| claude-opus-5-5 low | 29% (68/231) [20%, 37%] | 32% (74/231) [25%, 38%] | 39% (89/231) [30%, 47%] | 0% (0/89) [0%, 0%] |
| claude-opus-5-5 medium | 30% (206/687) [26%, 34%] | 32% (220/687) [28%, 36%] | 38% (261/687) [33%, 43%] | 0% (0/261) [0%, 0%] |
| claude-opus-5-5 xhigh | 31% (141/456) [26%, 36%] | 32% (145/456) [27%, 36%] | 37% (170/456) [33%, 42%] | 1.2% (2/170) [0%, 2.8%] |

### t3 astra vs opus xhigh

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-opus-5-5 xhigh | 25% (126/508) [20%, 29%] | 40% (201/508) [36%, 44%] | 36% (181/508) [31%, 40%] | 0% (0/181) [0%, 0%] |
| gpt-6-astra medium | 30% (148/493) [27%, 33%] | 28% (138/493) [25%, 31%] | 42% (207/493) [39%, 45%] | 0% (0/207) [0%, 0%] |

## Item fates

Each item a player placed, by how it left: used by its owner, stolen with adrenaline, still held when the owner died, or still held when the round ended (censored). Delays count only items used by their owner. Own turns are the owner's own decisions between placing the item and using it, so 0 is the first decision after the distribution.

### t1 cross-model medium

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 medium | 47% (1511/3246) [45%, 49%] | 7.6% (246/3246) [6.7%, 8.5%] | 30% (976/3246) [27%, 33%] | 16% (513/3246) [14%, 18%] | 1.35 (1) | 6 |
| claude-haiku-5-5 medium | 57% (1903/3317) [55%, 59%] | 7.3% (243/3317) [6.6%, 8.2%] | 20% (658/3317) [18%, 22%] | 15% (513/3317) [13%, 17%] | 1.57 (1) | 7 |
| claude-opus-5-5 medium | 57% (1858/3285) [55%, 58%] | 7.0% (230/3285) [6.1%, 7.9%] | 18% (588/3285) [16%, 20%] | 19% (609/3285) [16%, 21%] | 1.66 (1) | 7 |
| claude-sonnet-5-5 medium | 54% (1755/3253) [51%, 56%] | 7.0% (228/3253) [6.3%, 7.7%] | 21% (684/3253) [18%, 24%] | 18% (586/3253) [16%, 20%] | 1.71 (1) | 7 |
| gpt-5.6-terra medium | 53% (1669/3160) [51%, 55%] | 8.1% (257/3160) [7.3%, 9.1%] | 23% (723/3160) [20%, 26%] | 16% (511/3160) [14%, 19%] | 1.50 (1) | 6 |
| gpt-6-astra medium | 56% (1798/3191) [54%, 58%] | 7.0% (223/3191) [6.1%, 7.9%] | 16% (497/3191) [13%, 18%] | 21% (673/3191) [19%, 23%] | 1.67 (1) | 7 |
| gpt-6-luna medium | 62% (2028/3279) [59%, 64%] | 6.0% (197/3279) [5.3%, 6.7%] | 25% (824/3279) [23%, 28%] | 7.0% (230/3279) [5.5%, 8.6%] | 1.61 (1) | 6 |
| gpt-6.1-sol medium | 56% (1817/3253) [54%, 58%] | 7.0% (227/3253) [6.2%, 7.8%] | 19% (605/3253) [16%, 21%] | 19% (604/3253) [17%, 21%] | 1.62 (1) | 7 |

### t1 effort sweep

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 52% (1040/2004) [48%, 55%] | 5.7% (115/2004) [4.8%, 6.7%] | 21% (430/2004) [18%, 25%] | 21% (419/2004) [18%, 24%] | 1.62 (1) | 7 |
| claude-haiku-4-5-20251001 low | 53% (1047/1975) [50%, 56%] | 5.4% (107/1975) [4.6%, 6.3%] | 21% (412/1975) [17%, 25%] | 21% (409/1975) [17%, 24%] | 1.41 (1) | 6 |
| claude-haiku-4-5-20251001 medium | 52% (1063/2035) [49%, 55%] | 5.6% (114/2035) [4.5%, 6.7%] | 19% (387/2035) [16%, 22%] | 23% (471/2035) [20%, 27%] | 1.57 (1) | 7 |
| claude-haiku-4-5-20251001 minimal | 53% (1017/1926) [50%, 56%] | 5.8% (112/1926) [5.0%, 6.7%] | 21% (407/1926) [17%, 25%] | 20% (390/1926) [17%, 23%] | 1.54 (1) | 6 |
| claude-haiku-4-5-20251001 off | 56% (1111/2000) [52%, 59%] | 5.4% (108/2000) [4.6%, 6.3%] | 24% (485/2000) [21%, 27%] | 15% (296/2000) [12%, 17%] | 1.59 (1) | 6 |
| claude-haiku-5-5 high | 59% (1332/2266) [57%, 61%] | 8.0% (181/2266) [7.0%, 9.0%] | 19% (439/2266) [17%, 22%] | 14% (314/2266) [12%, 16%] | 1.34 (1) | 6 |
| claude-haiku-5-5 low | 58% (1352/2347) [55%, 60%] | 8.9% (210/2347) [8.0%, 9.9%] | 20% (481/2347) [18%, 23%] | 13% (304/2347) [11%, 15%] | 1.43 (1) | 6 |
| claude-haiku-5-5 max | 60% (1363/2287) [57%, 62%] | 7.7% (175/2287) [6.7%, 8.6%] | 17% (400/2287) [15%, 20%] | 15% (349/2287) [13%, 18%] | 1.62 (1) | 7 |
| claude-haiku-5-5 medium | 60% (1383/2316) [57%, 62%] | 8.3% (192/2316) [7.3%, 9.4%] | 19% (442/2316) [16%, 22%] | 13% (299/2316) [11%, 15%] | 1.52 (1) | 6 |
| claude-haiku-5-5 off | 57% (1314/2288) [55%, 60%] | 8.3% (191/2288) [7.4%, 9.3%] | 23% (529/2288) [20%, 26%] | 11% (254/2288) [8.9%, 13%] | 1.32 (1) | 6 |
| claude-haiku-5-5 xhigh | 57% (1334/2355) [54%, 59%] | 8.3% (195/2355) [7.3%, 9.3%] | 20% (472/2355) [17%, 23%] | 15% (354/2355) [13%, 17%] | 1.52 (1) | 7 |
| claude-sonnet-5-5 high | 56% (1266/2258) [53%, 59%] | 8.5% (193/2258) [7.8%, 9.5%] | 22% (500/2258) [19%, 26%] | 13% (299/2258) [11%, 16%] | 1.70 (1) | 6 |
| claude-sonnet-5-5 low | 52% (1163/2219) [50%, 55%] | 8.1% (180/2219) [7.0%, 9.3%] | 26% (588/2219) [23%, 30%] | 13% (288/2219) [11%, 15%] | 1.72 (1) | 6 |
| claude-sonnet-5-5 max | 61% (1403/2287) [59%, 64%] | 7.8% (178/2287) [6.9%, 8.7%] | 15% (340/2287) [12%, 18%] | 16% (366/2287) [14%, 18%] | 1.95 (1) | 7 |
| claude-sonnet-5-5 medium | 56% (1288/2307) [54%, 58%] | 7.3% (168/2307) [6.4%, 8.2%] | 22% (518/2307) [19%, 26%] | 14% (333/2307) [12%, 17%] | 1.78 (1) | 7 |
| claude-sonnet-5-5 off | 56% (1233/2220) [53%, 58%] | 7.7% (171/2220) [6.7%, 8.8%] | 23% (511/2220) [20%, 26%] | 14% (305/2220) [11%, 16%] | 1.72 (1) | 6 |
| claude-sonnet-5-5 xhigh | 58% (1297/2229) [56%, 60%] | 8.0% (179/2229) [7.1%, 9.1%] | 20% (448/2229) [18%, 23%] | 14% (305/2229) [12%, 16%] | 1.69 (1) | 7 |
| gpt-5.6-terra high | 50% (918/1820) [47%, 53%] | 9.0% (163/1820) [7.8%, 10%] | 22% (408/1820) [19%, 26%] | 18% (331/1820) [15%, 21%] | 1.45 (1) | 6 |
| gpt-5.6-terra low | 48% (898/1878) [45%, 50%] | 9.1% (171/1878) [7.9%, 10%] | 27% (511/1878) [24%, 30%] | 16% (298/1878) [13%, 19%] | 1.43 (1) | 6 |
| gpt-5.6-terra max | 61% (1150/1892) [58%, 63%] | 7.8% (148/1892) [6.8%, 8.9%] | 17% (320/1892) [14%, 20%] | 14% (274/1892) [13%, 17%] | 1.57 (1) | 6 |
| gpt-5.6-terra medium | 46% (861/1855) [44%, 49%] | 8.5% (157/1855) [7.2%, 9.7%] | 31% (571/1855) [28%, 33%] | 14% (266/1855) [12%, 16%] | 1.44 (1) | 6 |
| gpt-5.6-terra xhigh | 55% (1045/1903) [52%, 58%] | 8.5% (162/1903) [7.3%, 9.7%] | 18% (339/1903) [15%, 21%] | 19% (357/1903) [16%, 21%] | 1.55 (1) | 6 |
| gpt-6-luna high | 60% (1526/2524) [58%, 63%] | 7.1% (180/2524) [6.2%, 8.0%] | 18% (452/2524) [15%, 21%] | 15% (366/2524) [13%, 17%] | 1.68 (1) | 7 |
| gpt-6-luna low | 68% (1699/2513) [65%, 70%] | 8.3% (208/2513) [7.4%, 9.1%] | 19% (474/2513) [16%, 22%] | 5.3% (132/2513) [3.9%, 6.7%] | 1.59 (1) | 6 |
| gpt-6-luna max | 66% (1605/2438) [64%, 68%] | 7.8% (189/2438) [6.8%, 8.8%] | 11% (277/2438) [9.1%, 14%] | 15% (367/2438) [13%, 17%] | 1.65 (1) | 7 |
| gpt-6-luna medium | 63% (1586/2535) [60%, 65%] | 9.0% (227/2535) [8.0%, 9.8%] | 19% (491/2535) [17%, 22%] | 9.1% (231/2535) [7.0%, 11%] | 1.72 (1) | 6 |
| gpt-6-luna off | 68% (1691/2493) [65%, 71%] | 9.4% (235/2493) [8.3%, 11%] | 18% (453/2493) [15%, 21%] | 4.6% (114/2493) [3.3%, 6.0%] | 1.58 (1) | 6 |
| gpt-6-luna xhigh | 62% (1524/2439) [60%, 65%] | 8.4% (204/2439) [7.3%, 9.5%] | 13% (327/2439) [10%, 17%] | 16% (384/2439) [13%, 18%] | 1.59 (1) | 7 |
| gpt-6.1-sol high | 56% (1012/1797) [54%, 59%] | 9.2% (165/1797) [8.0%, 10%] | 21% (386/1797) [19%, 24%] | 13% (234/1797) [11%, 15%] | 1.61 (1) | 6 |
| gpt-6.1-sol low | 52% (923/1762) [50%, 55%] | 9.6% (170/1762) [8.4%, 11%] | 23% (401/1762) [19%, 27%] | 15% (268/1762) [12%, 18%] | 1.51 (1) | 6 |
| gpt-6.1-sol max | 58% (1085/1860) [56%, 61%] | 7.7% (144/1860) [6.7%, 8.8%] | 19% (356/1860) [16%, 22%] | 15% (275/1860) [13%, 17%] | 1.55 (1) | 6 |
| gpt-6.1-sol medium | 54% (970/1784) [52%, 57%] | 10% (179/1784) [8.8%, 11%] | 22% (390/1784) [19%, 24%] | 14% (245/1784) [12%, 16%] | 1.58 (1) | 6 |
| gpt-6.1-sol xhigh | 59% (1046/1773) [56%, 62%] | 7.1% (126/1773) [6.1%, 8.1%] | 21% (367/1773) [17%, 24%] | 13% (234/1773) [11%, 16%] | 1.57 (1) | 6 |

### t2 opus effort

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| claude-opus-5-5 high | 57% (506/888) [53%, 61%] | 10% (90/888) [8.6%, 12%] | 23% (201/888) [18%, 27%] | 10% (91/888) [7.4%, 13%] | 1.78 (1) | 7 |
| claude-opus-5-5 low | 53% (237/450) [45%, 59%] | 9.6% (43/450) [7.3%, 13%] | 20% (91/450) [16%, 26%] | 18% (79/450) [11%, 24%] | 1.65 (1) | 7 |
| claude-opus-5-5 medium | 57% (771/1344) [55%, 60%] | 9.6% (129/1344) [8.2%, 11%] | 21% (285/1344) [18%, 24%] | 12% (159/1344) [10%, 14%] | 1.68 (1) | 7 |
| claude-opus-5-5 xhigh | 59% (513/869) [53%, 64%] | 10% (87/869) [8.0%, 13%] | 15% (133/869) [11%, 19%] | 16% (136/869) [12%, 20%] | 1.66 (1) | 6 |

### t3 astra vs opus xhigh

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| claude-opus-5-5 xhigh | 57% (547/956) [53%, 61%] | 9.9% (95/956) [7.7%, 12%] | 20% (190/956) [15%, 25%] | 13% (124/956) [10%, 16%] | 1.82 (1) | 7 |
| gpt-6-astra medium | 57% (537/944) [54%, 60%] | 8.5% (80/944) [6.8%, 10%] | 22% (204/944) [16%, 26%] | 13% (123/944) [10%, 16%] | 1.70 (1) | 7 |

## Use when legal

Agent decisions where using an own item is a legal move, and the share that use it. A player holding two of an item counts once per decision.

### t1 cross-model medium

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 medium | 62% (263/423) [57%, 68%] | 16% (163/1024) [13%, 19%] | 36% (242/671) [33%, 40%] | 19% (203/1077) [16%, 22%] | 12% (143/1180) [10%, 14%] | 19% (160/840) [16%, 22%] | 38% (170/447) [33%, 44%] |
| claude-haiku-5-5 medium | 65% (283/435) [60%, 70%] | 29% (257/886) [25%, 33%] | 32% (262/808) [30%, 35%] | 24% (262/1111) [21%, 27%] | 12% (174/1419) [11%, 14%] | 26% (214/834) [23%, 29%] | 46% (203/446) [41%, 50%] |
| claude-opus-5-5 medium | 55% (271/494) [51%, 59%] | 32% (264/832) [28%, 37%] | 26% (248/947) [24%, 29%] | 19% (244/1282) [17%, 21%] | 13% (183/1373) [12%, 15%] | 34% (243/712) [31%, 38%] | 37% (178/483) [33%, 41%] |
| claude-sonnet-5-5 medium | 67% (281/422) [61%, 72%] | 24% (241/991) [21%, 28%] | 26% (238/925) [24%, 28%] | 21% (256/1221) [18%, 24%] | 7.1% (108/1512) [6.0%, 8.4%] | 34% (230/679) [29%, 39%] | 34% (175/514) [30%, 39%] |
| gpt-5.6-terra medium | 59% (321/540) [55%, 64%] | 15% (177/1215) [12%, 18%] | 36% (234/659) [33%, 39%] | 19% (193/1001) [16%, 24%] | 9.1% (132/1454) [7.5%, 11%] | 14% (151/1111) [11%, 17%] | 67% (204/306) [59%, 74%] |
| gpt-6-astra medium | 48% (258/535) [44%, 53%] | 37% (299/807) [33%, 41%] | 26% (260/992) [24%, 28%] | 13% (189/1473) [11%, 15%] | 12% (165/1416) [10%, 13%] | 34% (217/632) [30%, 39%] | 36% (172/483) [33%, 39%] |
| gpt-6-luna medium | 68% (319/469) [63%, 73%] | 36% (305/841) [33%, 40%] | 34% (277/822) [31%, 36%] | 29% (306/1039) [27%, 33%] | 16% (215/1325) [13%, 19%] | 20% (199/981) [18%, 23%] | 39% (181/462) [34%, 45%] |
| gpt-6.1-sol medium | 51% (277/548) [46%, 55%] | 35% (272/784) [31%, 39%] | 28% (249/891) [26%, 30%] | 14% (178/1265) [12%, 16%] | 12% (169/1420) [11%, 13%] | 35% (228/653) [30%, 40%] | 40% (182/457) [36%, 44%] |

### t1 effort sweep

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 56% (202/362) [50%, 62%] | 12% (85/725) [9.3%, 15%] | 36% (154/431) [31%, 41%] | 20% (141/704) [16%, 25%] | 13% (112/875) [11%, 15%] | 19% (119/611) [16%, 23%] | 34% (103/305) [28%, 40%] |
| claude-haiku-4-5-20251001 low | 70% (201/286) [65%, 76%] | 16% (120/742) [13%, 20%] | 39% (170/433) [34%, 45%] | 21% (132/633) [17%, 25%] | 12% (104/847) [10%, 14%] | 18% (116/646) [15%, 22%] | 26% (95/370) [20%, 32%] |
| claude-haiku-4-5-20251001 medium | 58% (220/379) [53%, 63%] | 12% (84/714) [8.9%, 15%] | 38% (177/463) [33%, 43%] | 17% (126/739) [14%, 21%] | 13% (122/962) [11%, 15%] | 17% (121/726) [14%, 19%] | 29% (96/333) [23%, 36%] |
| claude-haiku-4-5-20251001 minimal | 65% (197/301) [60%, 71%] | 19% (120/616) [16%, 24%] | 37% (166/446) [33%, 42%] | 18% (121/681) [15%, 21%] | 14% (122/865) [12%, 17%] | 14% (100/711) [11%, 17%] | 29% (77/266) [22%, 36%] |
| claude-haiku-4-5-20251001 off | 78% (222/284) [74%, 83%] | 27% (171/634) [22%, 32%] | 30% (145/477) [26%, 35%] | 20% (130/660) [16%, 23%] | 20% (153/761) [17%, 23%] | 16% (118/720) [13%, 20%] | 20% (80/406) [15%, 25%] |
| claude-haiku-5-5 high | 59% (199/339) [54%, 64%] | 33% (185/566) [28%, 38%] | 29% (156/546) [26%, 32%] | 21% (148/705) [17%, 25%] | 15% (131/875) [13%, 17%] | 27% (159/596) [23%, 30%] | 58% (146/252) [51%, 65%] |
| claude-haiku-5-5 low | 63% (220/348) [57%, 70%] | 26% (176/667) [22%, 32%] | 37% (178/475) [35%, 41%] | 27% (181/681) [23%, 30%] | 11% (107/977) [9.1%, 13%] | 24% (171/700) [21%, 29%] | 49% (141/289) [43%, 55%] |
| claude-haiku-5-5 max | 50% (211/423) [45%, 57%] | 32% (187/578) [28%, 37%] | 27% (160/597) [25%, 29%] | 20% (161/787) [18%, 23%] | 17% (153/926) [14%, 19%] | 26% (159/602) [22%, 31%] | 47% (130/277) [42%, 52%] |
| claude-haiku-5-5 medium | 61% (244/403) [55%, 67%] | 28% (177/635) [24%, 33%] | 32% (170/525) [29%, 36%] | 21% (164/765) [18%, 25%] | 15% (136/924) [13%, 17%] | 25% (173/686) [22%, 29%] | 46% (120/263) [35%, 56%] |
| claude-haiku-5-5 off | 76% (229/300) [72%, 81%] | 41% (200/486) [36%, 48%] | 44% (201/459) [39%, 49%] | 32% (197/609) [29%, 36%] | 8.3% (80/962) [6.7%, 10%] | 19% (141/732) [16%, 22%] | 25% (102/407) [21%, 30%] |
| claude-haiku-5-5 xhigh | 56% (200/357) [50%, 63%] | 32% (185/571) [28%, 38%] | 27% (156/570) [25%, 30%] | 19% (164/881) [16%, 22%] | 15% (148/990) [13%, 17%] | 27% (157/588) [23%, 31%] | 48% (131/271) [38%, 60%] |
| claude-sonnet-5-5 high | 64% (205/322) [59%, 69%] | 36% (202/554) [32%, 41%] | 27% (142/518) [25%, 30%] | 21% (163/789) [17%, 25%] | 8.7% (92/1053) [7.1%, 10%] | 35% (159/454) [30%, 41%] | 42% (139/330) [36%, 50%] |
| claude-sonnet-5-5 low | 65% (217/332) [61%, 71%] | 27% (162/611) [22%, 32%] | 27% (139/511) [24%, 31%] | 18% (152/830) [16%, 21%] | 8.5% (78/920) [7.1%, 10.0%] | 31% (156/505) [26%, 37%] | 34% (107/313) [29%, 40%] |
| claude-sonnet-5-5 max | 47% (216/455) [43%, 53%] | 36% (171/481) [31%, 42%] | 25% (178/721) [22%, 27%] | 18% (151/843) [15%, 21%] | 17% (187/1117) [15%, 19%] | 32% (178/549) [28%, 37%] | 37% (113/305) [33%, 42%] |
| claude-sonnet-5-5 medium | 60% (210/348) [56%, 65%] | 26% (176/678) [22%, 31%] | 27% (159/589) [25%, 30%] | 20% (167/850) [17%, 23%] | 8.3% (85/1025) [7.0%, 9.7%] | 36% (180/505) [31%, 42%] | 38% (134/352) [33%, 44%] |
| claude-sonnet-5-5 off | 64% (211/328) [61%, 68%] | 38% (210/553) [33%, 44%] | 24% (124/512) [22%, 27%] | 22% (157/706) [19%, 26%] | 7.0% (71/1013) [5.6%, 8.4%] | 31% (169/550) [26%, 37%] | 38% (120/315) [33%, 45%] |
| claude-sonnet-5-5 xhigh | 60% (176/292) [52%, 69%] | 40% (197/496) [36%, 45%] | 24% (144/598) [22%, 26%] | 21% (164/768) [18%, 25%] | 15% (137/922) [13%, 17%] | 31% (163/528) [26%, 37%] | 43% (120/282) [38%, 48%] |
| gpt-5.6-terra high | 57% (161/281) [51%, 64%] | 14% (85/594) [11%, 18%] | 36% (131/360) [32%, 41%] | 17% (104/609) [14%, 21%] | 9.2% (76/828) [7.1%, 11%] | 16% (96/600) [12%, 21%] | 71% (104/147) [64%, 78%] |
| gpt-5.6-terra low | 60% (169/284) [55%, 65%] | 12% (75/643) [8.3%, 16%] | 36% (138/380) [34%, 39%] | 16% (114/694) [12%, 21%] | 8.2% (63/768) [6.2%, 10%] | 15% (90/598) [11%, 20%] | 63% (113/178) [56%, 73%] |
| gpt-5.6-terra max | 54% (172/316) [50%, 60%] | 35% (155/444) [30%, 41%] | 28% (121/434) [25%, 31%] | 22% (145/660) [18%, 26%] | 13% (120/955) [11%, 14%] | 29% (141/488) [23%, 35%] | 60% (108/181) [54%, 67%] |
| gpt-5.6-terra medium | 55% (160/292) [49%, 61%] | 11% (70/655) [8.0%, 14%] | 42% (145/345) [38%, 47%] | 15% (91/627) [11%, 19%] | 9.5% (69/725) [7.3%, 12%] | 15% (76/495) [12%, 20%] | 74% (108/145) [65%, 84%] |
| gpt-5.6-terra xhigh | 54% (170/312) [50%, 60%] | 19% (130/675) [15%, 24%] | 35% (139/396) [31%, 40%] | 18% (123/693) [14%, 22%] | 10% (90/883) [8.4%, 12%] | 18% (103/570) [15%, 22%] | 69% (116/169) [60%, 80%] |
| gpt-6-luna high | 61% (250/410) [57%, 66%] | 21% (186/878) [18%, 24%] | 33% (211/640) [30%, 36%] | 29% (240/814) [27%, 32%] | 7.8% (105/1338) [6.6%, 9.4%] | 24% (177/748) [19%, 30%] | 49% (132/271) [43%, 56%] |
| gpt-6-luna low | 68% (225/332) [63%, 73%] | 50% (259/515) [45%, 56%] | 33% (212/637) [30%, 37%] | 29% (213/732) [25%, 34%] | 33% (265/803) [30%, 37%] | 21% (167/782) [18%, 26%] | 41% (152/367) [37%, 46%] |
| gpt-6-luna max | 53% (239/448) [49%, 59%] | 33% (198/601) [29%, 37%] | 28% (206/731) [26%, 31%] | 26% (233/885) [23%, 31%] | 13% (156/1195) [11%, 15%] | 25% (180/721) [21%, 29%] | 66% (163/247) [59%, 73%] |
| gpt-6-luna medium | 68% (253/374) [63%, 73%] | 36% (232/647) [30%, 42%] | 34% (215/631) [31%, 37%] | 29% (221/759) [26%, 33%] | 17% (179/1082) [14%, 20%] | 18% (148/842) [14%, 21%] | 39% (152/385) [34%, 46%] |
| gpt-6-luna off | 66% (217/328) [61%, 71%] | 51% (252/492) [46%, 58%] | 32% (236/745) [28%, 35%] | 31% (218/705) [28%, 34%] | 36% (254/700) [33%, 40%] | 23% (167/724) [20%, 27%] | 40% (154/388) [35%, 45%] |
| gpt-6-luna xhigh | 55% (231/417) [51%, 60%] | 25% (195/772) [21%, 30%] | 32% (202/629) [29%, 35%] | 29% (229/793) [26%, 32%] | 10.0% (113/1133) [8.2%, 12%] | 26% (192/729) [22%, 31%] | 64% (159/249) [59%, 70%] |
| gpt-6.1-sol high | 45% (161/357) [40%, 51%] | 43% (166/387) [37%, 50%] | 28% (115/405) [25%, 32%] | 15% (97/627) [13%, 19%] | 13% (89/690) [11%, 15%] | 35% (129/368) [29%, 43%] | 36% (95/264) [32%, 41%] |
| gpt-6.1-sol low | 48% (171/358) [44%, 52%] | 31% (132/421) [25%, 40%] | 31% (109/355) [27%, 34%] | 12% (81/668) [9.1%, 16%] | 9.3% (64/686) [7.0%, 12%] | 38% (128/341) [32%, 44%] | 40% (95/235) [35%, 46%] |
| gpt-6.1-sol max | 50% (155/309) [45%, 55%] | 41% (153/369) [35%, 50%] | 26% (117/445) [23%, 30%] | 21% (139/676) [18%, 24%] | 14% (108/798) [11%, 16%] | 38% (139/370) [32%, 44%] | 38% (107/281) [33%, 44%] |
| gpt-6.1-sol medium | 50% (158/318) [44%, 56%] | 35% (149/423) [29%, 44%] | 30% (107/356) [27%, 33%] | 17% (102/603) [13%, 22%] | 11% (89/826) [8.7%, 13%] | 38% (122/317) [32%, 46%] | 43% (97/227) [38%, 49%] |
| gpt-6.1-sol xhigh | 47% (152/326) [41%, 53%] | 47% (171/363) [42%, 53%] | 31% (115/377) [28%, 34%] | 19% (113/589) [16%, 23%] | 15% (106/702) [13%, 17%] | 36% (131/367) [30%, 42%] | 37% (90/244) [33%, 41%] |

### t2 opus effort

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 high | 47% (72/154) [40%, 55%] | 34% (73/212) [29%, 42%] | 25% (52/212) [19%, 31%] | 16% (56/355) [12%, 20%] | 14% (52/371) [12%, 16%] | 26% (54/208) [18%, 38%] | 50% (51/101) [42%, 63%] |
| claude-opus-5-5 low | 51% (46/91) [45%, 57%] | 15% (24/163) [12%, 22%] | 24% (29/123) [18%, 31%] | 15% (23/155) [11%, 23%] | 12% (21/169) [7.7%, 16%] | 36% (29/81) [24%, 62%] | 49% (27/55) [35%, 65%] |
| claude-opus-5-5 medium | 50% (118/237) [43%, 58%] | 30% (109/364) [26%, 35%] | 27% (82/307) [23%, 31%] | 17% (92/535) [14%, 21%] | 13% (72/571) [10%, 15%] | 37% (97/265) [29%, 46%] | 51% (69/134) [45%, 60%] |
| claude-opus-5-5 xhigh | 50% (82/164) [46%, 55%] | 40% (82/207) [32%, 49%] | 25% (54/219) [22%, 28%] | 16% (49/309) [11%, 22%] | 14% (50/359) [10%, 18%] | 33% (61/186) [24%, 43%] | 34% (52/155) [28%, 41%] |

### t3 astra vs opus xhigh

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 xhigh | 56% (70/126) [47%, 67%] | 38% (82/213) [30%, 50%] | 23% (73/312) [20%, 28%] | 20% (72/364) [16%, 24%] | 14% (54/400) [11%, 16%] | 36% (63/175) [26%, 46%] | 34% (53/156) [29%, 40%] |
| gpt-6-astra medium | 49% (90/184) [41%, 60%] | 46% (82/178) [38%, 55%] | 29% (85/290) [26%, 33%] | 13% (52/391) [9.2%, 19%] | 7.9% (35/441) [5.8%, 10%] | 27% (53/199) [19%, 35%] | 41% (45/110) [35%, 48%] |

## Adrenaline steals when legal

Agent decisions where stealing an item with adrenaline is legal, and the share that steal it. These are separate from the player's own items.

### t1 cross-model medium

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 medium | 18% (35/196) [12%, 25%] | 1.0% (4/407) [0.2%, 2.1%] | 17% (41/246) [12%, 22%] | 3.5% (15/426) [1.8%, 5.6%] | 4.9% (24/491) [3.0%, 6.9%] | 3.5% (10/282) [1.6%, 5.9%] | 35% (38/109) [26%, 45%] |
| claude-haiku-5-5 medium | 27% (47/176) [20%, 36%] | 10% (34/335) [7.1%, 14%] | 28% (47/168) [21%, 36%] | 8.5% (30/355) [5.8%, 11%] | 6.0% (23/381) [4.2%, 8.2%] | 15% (40/266) [11%, 20%] | 28% (27/96) [19%, 40%] |
| claude-opus-5-5 medium | 34% (46/134) [26%, 43%] | 5.8% (21/362) [3.3%, 8.8%] | 20% (36/179) [16%, 25%] | 6.2% (24/387) [3.9%, 8.7%] | 8.3% (36/432) [6.1%, 10%] | 10% (28/276) [6.7%, 14%] | 34% (36/105) [25%, 45%] |
| claude-sonnet-5-5 medium | 39% (85/217) [33%, 46%] | 2.3% (10/433) [0.9%, 4.1%] | 12% (34/274) [8.7%, 17%] | 2.6% (11/421) [1.3%, 4.2%] | 3.6% (21/584) [2.3%, 5.3%] | 6.4% (27/422) [4.4%, 8.7%] | 19% (38/197) [14%, 25%] |
| gpt-5.6-terra medium | 29% (58/197) [24%, 36%] | 2.2% (8/359) [0.9%, 4.0%] | 24% (73/298) [20%, 29%] | 5.9% (22/376) [3.4%, 8.7%] | 3.1% (16/514) [1.8%, 4.8%] | 4.1% (14/343) [2.3%, 6.4%] | 59% (66/111) [49%, 71%] |
| gpt-6-astra medium | 32% (48/149) [24%, 42%] | 2.8% (10/362) [1.2%, 4.8%] | 20% (35/172) [16%, 24%] | 2.7% (9/336) [1.2%, 4.4%] | 9.0% (38/423) [6.6%, 11%] | 27% (61/228) [21%, 33%] | 38% (37/98) [30%, 47%] |
| gpt-6-luna medium | 20% (46/230) [15%, 25%] | 6.3% (25/400) [3.9%, 9.1%] | 10% (25/241) [7.0%, 14%] | 8.0% (32/402) [5.2%, 11%] | 6.5% (34/520) [4.4%, 9.0%] | 5.2% (17/328) [3.1%, 7.2%] | 34% (47/138) [28%, 43%] |
| gpt-6.1-sol medium | 35% (41/117) [27%, 46%] | 5.9% (20/341) [3.6%, 8.8%] | 24% (47/197) [20%, 29%] | 4.2% (13/309) [2.1%, 6.9%] | 10% (42/416) [7.7%, 12%] | 19% (52/268) [15%, 26%] | 35% (47/133) [29%, 42%] |

### t1 effort sweep

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 7.1% (12/169) [3.2%, 13%] | 1.0% (3/286) [0%, 2.6%] | 20% (34/174) [15%, 25%] | 3.2% (9/283) [1.2%, 6.1%] | 3.9% (14/361) [1.9%, 6.3%] | 5.7% (15/264) [3.2%, 9.1%] | 34% (37/109) [26%, 42%] |
| claude-haiku-4-5-20251001 low | 14% (16/116) [8.4%, 21%] | 1.3% (4/306) [0.3%, 2.7%] | 16% (31/188) [12%, 22%] | 1.8% (5/281) [0.3%, 3.9%] | 4.0% (15/379) [2.0%, 6.4%] | 3.2% (9/277) [1.4%, 5.4%] | 20% (29/142) [13%, 29%] |
| claude-haiku-4-5-20251001 medium | 7.8% (13/166) [3.9%, 12%] | 0.7% (3/405) [0%, 1.6%] | 10% (23/226) [5.6%, 17%] | 3.0% (10/334) [1.5%, 4.8%] | 2.4% (9/369) [1.1%, 4.1%] | 3.4% (12/352) [1.4%, 6.3%] | 32% (47/147) [24%, 43%] |
| claude-haiku-4-5-20251001 minimal | 7.6% (9/119) [2.4%, 15%] | 0.6% (2/328) [0%, 1.6%] | 15% (25/168) [9.5%, 22%] | 3.7% (11/299) [1.7%, 6.2%] | 4.1% (15/365) [2.3%, 6.7%] | 4.4% (13/297) [2.0%, 7.8%] | 27% (39/145) [19%, 37%] |
| claude-haiku-4-5-20251001 off | 8.7% (16/184) [4.8%, 14%] | 0.6% (2/312) [0%, 1.5%] | 9.7% (24/247) [5.9%, 14%] | 2.3% (8/343) [0.9%, 4.3%] | 1.9% (9/469) [0.8%, 3.4%] | 1.1% (4/360) [0%, 2.6%] | 17% (29/169) [11%, 25%] |
| claude-haiku-5-5 high | 30% (38/126) [22%, 41%] | 8.4% (14/166) [4.0%, 14%] | 28% (47/165) [23%, 36%] | 9.3% (17/183) [5.1%, 15%] | 11% (29/259) [7.5%, 16%] | 13% (26/203) [7.9%, 20%] | 38% (37/98) [30%, 47%] |
| claude-haiku-5-5 low | 31% (37/118) [23%, 41%] | 5.3% (10/190) [2.8%, 8.1%] | 23% (34/147) [18%, 29%] | 11% (23/215) [6.9%, 15%] | 6.1% (16/262) [3.4%, 9.6%] | 9.4% (19/202) [5.4%, 14%] | 41% (39/94) [32%, 52%] |
| claude-haiku-5-5 max | 36% (39/108) [27%, 49%] | 8.2% (14/171) [4.8%, 13%] | 26% (37/141) [21%, 32%] | 7.6% (14/184) [3.7%, 12%] | 11% (25/237) [7.1%, 15%] | 21% (37/178) [15%, 28%] | 38% (36/96) [29%, 49%] |
| claude-haiku-5-5 medium | 31% (35/112) [21%, 45%] | 8.1% (17/211) [5.2%, 11%] | 27% (46/170) [21%, 35%] | 9.6% (19/197) [5.7%, 14%] | 8.1% (25/310) [5.5%, 11%] | 10% (22/212) [6.3%, 15%] | 33% (35/107) [25%, 42%] |
| claude-haiku-5-5 off | 30% (28/94) [21%, 41%] | 8.4% (14/166) [4.5%, 13%] | 39% (35/90) [29%, 51%] | 15% (17/110) [9.2%, 22%] | 9.9% (24/243) [5.8%, 15%] | 11% (20/182) [6.7%, 17%] | 27% (26/95) [17%, 43%] |
| claude-haiku-5-5 xhigh | 41% (45/111) [32%, 52%] | 7.5% (11/147) [3.4%, 13%] | 25% (36/146) [20%, 31%] | 5.8% (9/156) [2.1%, 10%] | 8.9% (19/214) [5.6%, 13%] | 23% (37/160) [17%, 30%] | 47% (36/76) [36%, 60%] |
| claude-sonnet-5-5 high | 24% (34/140) [17%, 33%] | 4.7% (10/215) [1.9%, 7.7%] | 19% (44/237) [15%, 22%] | 4.1% (9/218) [1.4%, 7.8%] | 3.3% (13/391) [1.5%, 5.4%] | 6.8% (16/236) [3.4%, 11%] | 40% (38/94) [34%, 49%] |
| claude-sonnet-5-5 low | 32% (45/139) [24%, 44%] | 0.4% (1/257) [0%, 1.2%] | 17% (42/245) [13%, 22%] | 3.4% (9/265) [1.6%, 5.8%] | 2.7% (12/448) [1.5%, 4.0%] | 3.7% (9/246) [1.4%, 6.4%] | 23% (34/149) [16%, 31%] |
| claude-sonnet-5-5 max | 24% (39/161) [18%, 33%] | 3.7% (10/270) [1.7%, 6.1%] | 17% (39/234) [13%, 22%] | 4.2% (11/261) [1.9%, 7.6%] | 8.6% (31/361) [5.7%, 12%] | 19% (48/258) [14%, 23%] | 22% (31/140) [16%, 30%] |
| claude-sonnet-5-5 medium | 24% (47/196) [17%, 34%] | 1.0% (3/303) [0%, 2.3%] | 18% (46/260) [14%, 21%] | 4.7% (15/320) [2.5%, 7.2%] | 2.8% (14/494) [1.5%, 4.5%] | 3.1% (9/294) [1.2%, 5.4%] | 30% (43/143) [22%, 39%] |
| claude-sonnet-5-5 off | 26% (51/194) [20%, 34%] | 2.3% (5/217) [0%, 5.2%] | 15% (31/201) [12%, 20%] | 6.4% (20/313) [3.9%, 9.6%] | 3.0% (15/497) [1.5%, 4.8%] | 4.3% (12/276) [2.0%, 7.3%] | 32% (37/116) [24%, 42%] |
| claude-sonnet-5-5 xhigh | 28% (36/129) [21%, 38%] | 4.2% (11/263) [2.0%, 7.1%] | 15% (32/214) [11%, 19%] | 6.8% (18/265) [3.9%, 10%] | 7.8% (31/400) [4.7%, 11%] | 14% (35/252) [9.5%, 19%] | 34% (33/97) [26%, 44%] |
| gpt-5.6-terra high | 34% (31/90) [24%, 47%] | 3.1% (7/227) [0.5%, 6.8%] | 33% (41/126) [26%, 41%] | 6.7% (12/178) [3.7%, 10%] | 7.5% (19/255) [4.3%, 11%] | 7.0% (14/200) [4.0%, 10%] | 74% (37/50) [62%, 87%] |
| gpt-5.6-terra low | 36% (36/101) [28%, 45%] | 2.2% (4/182) [0.5%, 5.0%] | 24% (29/122) [18%, 31%] | 7.7% (13/169) [3.5%, 13%] | 4.0% (12/302) [1.8%, 6.6%] | 4.3% (8/186) [1.2%, 8.4%] | 65% (34/52) [54%, 79%] |
| gpt-5.6-terra max | 30% (34/114) [22%, 41%] | 9.3% (18/193) [5.4%, 15%] | 29% (35/122) [22%, 36%] | 8.1% (15/185) [5.0%, 11%] | 7.0% (16/227) [4.0%, 11%] | 25% (41/167) [18%, 33%] | 64% (29/45) [52%, 78%] |
| gpt-5.6-terra medium | 35% (32/91) [27%, 45%] | 4.1% (7/170) [1.2%, 7.6%] | 26% (31/117) [21%, 34%] | 7.9% (18/228) [4.9%, 11%] | 2.7% (8/293) [1.0%, 4.8%] | 8.2% (14/170) [4.9%, 12%] | 68% (32/47) [57%, 82%] |
| gpt-5.6-terra xhigh | 33% (33/100) [25%, 45%] | 4.5% (11/242) [2.2%, 8.0%] | 28% (39/138) [22%, 35%] | 6.1% (10/163) [3.0%, 9.9%] | 6.2% (19/306) [3.2%, 10%] | 12% (25/206) [7.9%, 17%] | 64% (37/58) [52%, 77%] |
| gpt-6-luna high | 42% (52/125) [34%, 51%] | 2.4% (6/246) [0.5%, 5.0%] | 16% (38/235) [13%, 20%] | 16% (42/263) [12%, 21%] | 3.1% (11/355) [1.5%, 5.2%] | 6.6% (17/258) [4.0%, 9.7%] | 48% (59/123) [39%, 58%] |
| gpt-6-luna low | 18% (28/159) [12%, 24%] | 8.5% (20/236) [5.3%, 12%] | 12% (32/263) [8.8%, 16%] | 7.2% (17/237) [4.3%, 10%] | 12% (40/337) [8.2%, 16%] | 7.8% (24/308) [5.3%, 11%] | 47% (45/95) [38%, 58%] |
| gpt-6-luna max | 28% (34/121) [21%, 36%] | 11% (24/210) [7.9%, 15%] | 22% (41/189) [17%, 26%] | 13% (26/207) [7.5%, 19%] | 7.7% (24/312) [5.5%, 10%] | 17% (33/198) [12%, 22%] | 62% (48/77) [51%, 74%] |
| gpt-6-luna medium | 16% (29/186) [11%, 21%] | 4.4% (10/228) [2.1%, 7.2%] | 12% (30/258) [8.1%, 16%] | 10% (25/241) [6.0%, 15%] | 4.9% (19/388) [2.6%, 7.6%] | 6.9% (20/291) [4.2%, 10%] | 45% (53/119) [35%, 56%] |
| gpt-6-luna off | 26% (36/137) [21%, 34%] | 3.7% (7/189) [1.2%, 7.1%] | 13% (25/194) [8.3%, 18%] | 7.5% (20/266) [4.3%, 12%] | 14% (49/340) [11%, 19%] | 8.6% (23/267) [5.3%, 13%] | 41% (33/80) [33%, 51%] |
| gpt-6-luna xhigh | 38% (39/103) [31%, 46%] | 11% (26/235) [6.3%, 17%] | 14% (30/218) [9.7%, 18%] | 8.2% (18/220) [4.8%, 12%] | 4.4% (15/343) [2.4%, 6.7%] | 16% (35/215) [11%, 22%] | 58% (40/69) [44%, 76%] |
| gpt-6.1-sol high | 20% (26/127) [15%, 28%] | 4.1% (6/146) [0.8%, 8.5%] | 27% (33/124) [21%, 35%] | 10% (17/162) [6.8%, 16%] | 8.3% (20/242) [4.2%, 13%] | 19% (24/124) [12%, 28%] | 43% (34/80) [33%, 56%] |
| gpt-6.1-sol low | 26% (24/91) [18%, 39%] | 2.2% (3/139) [0%, 5.6%] | 28% (32/114) [22%, 35%] | 5.0% (8/161) [2.0%, 9.8%] | 8.0% (16/201) [4.4%, 13%] | 21% (28/132) [14%, 31%] | 62% (32/52) [49%, 77%] |
| gpt-6.1-sol max | 24% (28/117) [17%, 32%] | 1.8% (3/169) [0%, 3.9%] | 19% (31/167) [14%, 23%] | 9.1% (20/220) [5.5%, 14%] | 9.1% (22/241) [5.9%, 13%] | 16% (26/160) [11%, 23%] | 39% (37/96) [28%, 49%] |
| gpt-6.1-sol medium | 24% (23/95) [16%, 35%] | 5.1% (7/138) [1.6%, 10%] | 23% (34/149) [18%, 28%] | 6.1% (11/180) [3.3%, 9.8%] | 8.6% (20/233) [5.0%, 13%] | 13% (16/128) [6.5%, 21%] | 64% (35/55) [52%, 78%] |
| gpt-6.1-sol xhigh | 29% (32/109) [20%, 42%] | 2.4% (4/165) [0%, 5.7%] | 20% (36/184) [16%, 23%] | 11% (21/197) [7.0%, 16%] | 8.0% (20/249) [5.6%, 11%] | 15% (24/163) [9.5%, 21%] | 42% (31/74) [33%, 52%] |

### t2 opus effort

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 high | 43% (20/47) [29%, 64%] | 4.8% (4/83) [1.1%, 11%] | 19% (17/91) [14%, 24%] | 12% (14/113) [6.6%, 21%] | 8.3% (9/108) [2.8%, 16%] | 23% (18/77) [16%, 33%] | 54% (14/26) [36%, 74%] |
| claude-opus-5-5 low | 28% (7/25) [16%, 50%] | 1.6% (1/64) [0%, 8.0%] | 29% (12/41) [23%, 41%] | 3.6% (3/83) [0%, 5.1%] | 8.8% (7/80) [4.2%, 18%] | 4.5% (2/44) [0%, 11%] | 32% (6/19) [11%, 50%] |
| claude-opus-5-5 medium | 27% (27/99) [20%, 38%] | 4.2% (6/144) [1.3%, 8.9%] | 22% (25/115) [16%, 29%] | 6.9% (10/145) [3.6%, 11%] | 8.3% (18/217) [5.4%, 12%] | 17% (22/129) [12%, 23%] | 52% (24/46) [35%, 73%] |
| claude-opus-5-5 xhigh | 26% (12/46) [14%, 44%] | 5.8% (6/104) [1.1%, 11%] | 24% (17/71) [19%, 29%] | 9.2% (7/76) [2.9%, 21%] | 6.4% (7/110) [2.2%, 12%] | 27% (21/78) [20%, 36%] | 52% (13/25) [37%, 78%] |

### t3 astra vs opus xhigh

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 xhigh | 27% (19/71) [19%, 36%] | 2.6% (3/116) [0%, 6.7%] | 16% (11/68) [7.6%, 25%] | 4.4% (6/137) [0.7%, 10%] | 8.0% (14/174) [5.2%, 11%] | 10% (12/120) [6.0%, 15%] | 33% (15/45) [24%, 45%] |
| gpt-6-astra medium | 35% (24/69) [23%, 49%] | 1.8% (2/109) [0%, 4.9%] | 27% (23/84) [22%, 34%] | 5.2% (6/115) [1.8%, 9.1%] | 6.2% (8/129) [2.9%, 11%] | 20% (15/76) [11%, 31%] | 45% (17/38) [31%, 63%] |

## Item fates by item

Share of placed items used by their owner, by item. Adrenaline counts as used when its owner steals with it.

### t1 cross-model medium

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 medium | 69% (263/382) [64%, 74%] | 36% (163/450) [31%, 42%] | 59% (242/407) [54%, 65%] | 43% (203/476) [38%, 47%] | 30% (143/483) [25%, 34%] | 47% (160/341) [41%, 53%] | 58% (170/295) [53%, 62%] | 41% (167/412) [36%, 45%] |
| claude-haiku-5-5 medium | 68% (283/415) [65%, 72%] | 56% (257/458) [50%, 62%] | 62% (262/426) [58%, 66%] | 55% (262/474) [51%, 60%] | 38% (174/462) [34%, 42%] | 60% (214/354) [55%, 66%] | 64% (203/317) [59%, 69%] | 60% (248/411) [55%, 66%] |
| claude-opus-5-5 medium | 67% (271/402) [62%, 72%] | 58% (264/456) [53%, 63%] | 58% (248/427) [54%, 63%] | 49% (244/498) [44%, 53%] | 40% (183/457) [36%, 44%] | 67% (243/365) [62%, 71%] | 63% (178/283) [58%, 68%] | 57% (227/397) [53%, 61%] |
| claude-sonnet-5-5 medium | 73% (281/383) [69%, 78%] | 54% (241/444) [50%, 59%] | 57% (238/416) [53%, 62%] | 50% (256/508) [44%, 56%] | 24% (108/446) [20%, 29%] | 66% (230/346) [61%, 72%] | 66% (175/267) [60%, 71%] | 51% (226/443) [46%, 57%] |
| gpt-5.6-terra medium | 73% (321/441) [69%, 77%] | 41% (177/435) [34%, 48%] | 65% (234/362) [60%, 69%] | 46% (193/422) [39%, 52%] | 28% (132/475) [23%, 33%] | 46% (151/326) [40%, 52%] | 73% (204/281) [68%, 77%] | 61% (257/418) [57%, 66%] |
| gpt-6-astra medium | 70% (258/368) [65%, 75%] | 66% (299/453) [61%, 71%] | 58% (260/448) [54%, 62%] | 38% (189/503) [33%, 43%] | 38% (165/440) [34%, 41%] | 65% (217/334) [60%, 69%] | 65% (172/264) [60%, 70%] | 62% (238/381) [58%, 68%] |
| gpt-6-luna medium | 78% (319/410) [74%, 81%] | 65% (305/472) [60%, 69%] | 65% (277/429) [60%, 69%] | 63% (306/482) [59%, 68%] | 45% (215/479) [38%, 51%] | 58% (199/345) [52%, 63%] | 68% (181/265) [62%, 74%] | 57% (226/397) [51%, 63%] |
| gpt-6.1-sol medium | 69% (277/400) [64%, 74%] | 60% (272/455) [55%, 65%] | 58% (249/432) [53%, 62%] | 40% (178/450) [35%, 45%] | 36% (169/473) [32%, 40%] | 64% (228/356) [59%, 69%] | 64% (182/285) [59%, 69%] | 65% (262/402) [60%, 70%] |

### t1 effort sweep

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 78% (202/260) [72%, 83%] | 34% (85/252) [28%, 40%] | 61% (154/252) [55%, 68%] | 47% (141/297) [39%, 55%] | 37% (112/303) [31%, 43%] | 58% (119/205) [50%, 66%] | 55% (103/187) [49%, 61%] | 50% (124/248) [44%, 56%] |
| claude-haiku-4-5-20251001 low | 83% (201/242) [79%, 87%] | 42% (120/288) [36%, 48%] | 65% (170/262) [59%, 70%] | 49% (132/269) [42%, 56%] | 37% (104/282) [32%, 42%] | 58% (116/200) [51%, 64%] | 53% (95/180) [44%, 61%] | 43% (109/252) [38%, 49%] |
| claude-haiku-4-5-20251001 medium | 82% (220/269) [76%, 87%] | 34% (84/247) [28%, 40%] | 63% (177/282) [57%, 68%] | 47% (126/268) [40%, 54%] | 39% (122/316) [32%, 45%] | 60% (121/203) [54%, 65%] | 54% (96/177) [45%, 63%] | 43% (117/273) [37%, 50%] |
| claude-haiku-4-5-20251001 minimal | 85% (197/232) [80%, 90%] | 45% (120/264) [39%, 52%] | 58% (166/284) [54%, 63%] | 46% (121/265) [40%, 52%] | 42% (122/292) [35%, 49%] | 50% (100/202) [43%, 56%] | 53% (77/146) [44%, 61%] | 47% (114/241) [40%, 55%] |
| claude-haiku-4-5-20251001 off | 84% (222/263) [79%, 89%] | 62% (171/274) [56%, 69%] | 58% (145/250) [51%, 65%] | 48% (130/273) [41%, 54%] | 52% (153/293) [43%, 61%] | 56% (118/209) [49%, 64%] | 48% (80/166) [41%, 55%] | 34% (92/272) [27%, 41%] |
| claude-haiku-5-5 high | 73% (199/273) [68%, 78%] | 60% (185/308) [53%, 67%] | 56% (156/279) [50%, 62%] | 50% (148/298) [44%, 55%] | 43% (131/306) [38%, 48%] | 57% (159/277) [52%, 62%] | 69% (146/212) [64%, 73%] | 66% (208/313) [61%, 72%] |
| claude-haiku-5-5 low | 71% (220/308) [66%, 77%] | 55% (176/319) [49%, 62%] | 60% (178/299) [55%, 64%] | 59% (181/306) [54%, 65%] | 34% (107/315) [29%, 39%] | 58% (171/293) [52%, 64%] | 65% (141/216) [61%, 70%] | 61% (178/291) [55%, 67%] |
| claude-haiku-5-5 max | 71% (211/296) [67%, 75%] | 62% (187/304) [56%, 67%] | 55% (160/290) [49%, 61%] | 50% (161/321) [44%, 56%] | 49% (153/313) [42%, 55%] | 66% (159/241) [60%, 72%] | 62% (130/211) [56%, 67%] | 65% (202/311) [59%, 71%] |
| claude-haiku-5-5 medium | 74% (244/330) [69%, 78%] | 59% (177/302) [52%, 65%] | 64% (170/266) [58%, 70%] | 50% (164/325) [44%, 57%] | 42% (136/321) [36%, 49%] | 61% (173/282) [56%, 66%] | 65% (120/186) [58%, 71%] | 65% (199/304) [59%, 72%] |
| claude-haiku-5-5 off | 75% (229/306) [69%, 80%] | 67% (200/299) [61%, 72%] | 64% (201/313) [59%, 69%] | 65% (197/305) [60%, 70%] | 25% (80/326) [20%, 29%] | 54% (141/260) [48%, 60%] | 52% (102/195) [46%, 58%] | 58% (164/284) [52%, 64%] |
| claude-haiku-5-5 xhigh | 73% (200/275) [67%, 78%] | 58% (185/320) [52%, 64%] | 54% (156/290) [48%, 59%] | 49% (164/338) [42%, 54%] | 43% (148/348) [36%, 49%] | 60% (157/263) [54%, 66%] | 62% (131/211) [56%, 68%] | 62% (193/310) [57%, 67%] |
| claude-sonnet-5-5 high | 69% (205/296) [64%, 74%] | 66% (202/304) [61%, 72%] | 53% (142/269) [48%, 58%] | 51% (163/319) [44%, 59%] | 28% (92/324) [23%, 34%] | 65% (159/245) [58%, 71%] | 63% (139/222) [57%, 69%] | 59% (164/279) [53%, 65%] |
| claude-sonnet-5-5 low | 73% (217/299) [68%, 77%] | 55% (162/292) [49%, 62%] | 54% (139/257) [48%, 61%] | 48% (152/320) [42%, 53%] | 25% (78/312) [21%, 30%] | 63% (156/248) [58%, 68%] | 59% (107/181) [52%, 66%] | 49% (152/310) [43%, 55%] |
| claude-sonnet-5-5 max | 69% (216/313) [63%, 75%] | 64% (171/267) [57%, 70%] | 60% (178/295) [54%, 67%] | 50% (151/304) [44%, 55%] | 52% (187/357) [46%, 58%] | 71% (178/252) [65%, 76%] | 62% (113/181) [56%, 68%] | 66% (209/318) [61%, 70%] |
| claude-sonnet-5-5 medium | 71% (210/297) [64%, 78%] | 60% (176/292) [54%, 67%] | 57% (159/279) [52%, 63%] | 51% (167/327) [45%, 57%] | 26% (85/327) [22%, 30%] | 68% (180/264) [64%, 73%] | 67% (134/199) [61%, 73%] | 55% (177/322) [50%, 60%] |
| claude-sonnet-5-5 off | 73% (211/289) [67%, 78%] | 68% (210/310) [63%, 72%] | 46% (124/271) [41%, 51%] | 56% (157/282) [49%, 63%] | 23% (71/309) [18%, 28%] | 64% (169/263) [58%, 71%] | 66% (120/182) [59%, 72%] | 54% (171/314) [49%, 60%] |
| claude-sonnet-5-5 xhigh | 63% (176/279) [57%, 69%] | 70% (197/281) [65%, 76%] | 54% (144/267) [49%, 59%] | 55% (164/300) [50%, 60%] | 41% (137/335) [36%, 46%] | 64% (163/255) [58%, 70%] | 59% (120/205) [53%, 64%] | 64% (196/307) [59%, 69%] |
| gpt-5.6-terra high | 70% (161/230) [63%, 77%] | 36% (85/237) [29%, 43%] | 59% (131/222) [52%, 66%] | 42% (104/245) [35%, 50%] | 27% (76/279) [21%, 34%] | 47% (96/205) [38%, 55%] | 67% (104/155) [61%, 73%] | 65% (161/247) [58%, 71%] |
| gpt-5.6-terra low | 67% (169/251) [63%, 73%] | 31% (75/243) [24%, 39%] | 59% (138/234) [54%, 64%] | 40% (114/284) [32%, 49%] | 24% (63/259) [19%, 30%] | 44% (90/206) [36%, 52%] | 65% (113/173) [58%, 73%] | 60% (136/228) [54%, 65%] |
| gpt-5.6-terra max | 72% (172/239) [66%, 78%] | 63% (155/246) [58%, 69%] | 52% (121/234) [46%, 57%] | 57% (145/256) [48%, 65%] | 40% (120/299) [35%, 45%] | 66% (141/213) [59%, 73%] | 64% (108/169) [58%, 70%] | 80% (188/236) [75%, 84%] |
| gpt-5.6-terra medium | 63% (160/253) [57%, 69%] | 28% (70/251) [22%, 34%] | 59% (145/245) [54%, 65%] | 34% (91/264) [27%, 43%] | 27% (69/256) [21%, 33%] | 42% (76/181) [34%, 49%] | 66% (108/164) [59%, 73%] | 59% (142/241) [53%, 64%] |
| gpt-5.6-terra xhigh | 68% (170/249) [63%, 73%] | 50% (130/260) [43%, 56%] | 62% (139/223) [56%, 69%] | 47% (123/262) [40%, 54%] | 32% (90/279) [27%, 38%] | 52% (103/200) [44%, 58%] | 69% (116/169) [62%, 75%] | 67% (174/261) [61%, 73%] |
| gpt-6-luna high | 78% (250/321) [74%, 82%] | 57% (186/329) [51%, 62%] | 67% (211/317) [61%, 72%] | 64% (240/374) [60%, 69%] | 28% (105/377) [24%, 33%] | 66% (177/267) [60%, 73%] | 70% (132/189) [64%, 76%] | 64% (225/350) [59%, 69%] |
| gpt-6-luna low | 72% (225/313) [67%, 77%] | 78% (259/332) [73%, 83%] | 66% (212/319) [61%, 73%] | 61% (213/351) [55%, 67%] | 73% (265/364) [68%, 78%] | 63% (167/265) [57%, 69%] | 64% (152/237) [59%, 69%] | 62% (206/332) [57%, 68%] |
| gpt-6-luna max | 74% (239/321) [69%, 79%] | 69% (198/287) [63%, 74%] | 68% (206/305) [63%, 72%] | 65% (233/360) [58%, 71%] | 44% (156/354) [39%, 49%] | 68% (180/266) [62%, 73%] | 71% (163/228) [66%, 76%] | 73% (230/317) [67%, 78%] |
| gpt-6-luna medium | 76% (253/333) [72%, 80%] | 66% (232/350) [60%, 73%] | 67% (215/320) [63%, 71%] | 62% (221/356) [56%, 68%] | 48% (179/370) [43%, 54%] | 58% (148/254) [53%, 64%] | 65% (152/233) [60%, 71%] | 58% (186/319) [52%, 65%] |
| gpt-6-luna off | 73% (217/296) [67%, 79%] | 71% (252/353) [67%, 76%] | 67% (236/353) [62%, 71%] | 64% (218/343) [58%, 69%] | 73% (254/346) [69%, 78%] | 61% (167/274) [56%, 66%] | 63% (154/243) [59%, 68%] | 68% (193/285) [62%, 74%] |
| gpt-6-luna xhigh | 74% (231/312) [68%, 80%] | 60% (195/323) [54%, 67%] | 70% (202/290) [64%, 75%] | 65% (229/351) [60%, 70%] | 34% (113/331) [28%, 40%] | 69% (192/279) [63%, 74%] | 73% (159/218) [68%, 78%] | 61% (203/335) [55%, 66%] |
| gpt-6.1-sol high | 69% (161/232) [63%, 75%] | 69% (166/241) [62%, 75%] | 52% (115/222) [45%, 58%] | 40% (97/242) [34%, 47%] | 38% (89/236) [32%, 44%] | 60% (129/215) [54%, 66%] | 61% (95/156) [53%, 69%] | 63% (160/253) [57%, 69%] |
| gpt-6.1-sol low | 71% (171/241) [66%, 76%] | 57% (132/233) [48%, 66%] | 51% (109/215) [44%, 58%] | 33% (81/242) [27%, 40%] | 26% (64/243) [20%, 33%] | 66% (128/195) [59%, 71%] | 58% (95/163) [52%, 65%] | 62% (143/230) [57%, 68%] |
| gpt-6.1-sol max | 67% (155/232) [59%, 74%] | 66% (153/232) [61%, 72%] | 51% (117/228) [45%, 58%] | 55% (139/255) [48%, 61%] | 40% (108/273) [33%, 46%] | 67% (139/208) [60%, 74%] | 61% (107/176) [56%, 65%] | 65% (167/256) [60%, 71%] |
| gpt-6.1-sol medium | 66% (158/239) [59%, 73%] | 60% (149/247) [53%, 68%] | 53% (107/202) [45%, 61%] | 45% (102/228) [38%, 52%] | 33% (89/268) [26%, 40%] | 60% (122/203) [55%, 64%] | 61% (97/159) [54%, 68%] | 61% (146/238) [57%, 66%] |
| gpt-6.1-sol xhigh | 66% (152/229) [58%, 75%] | 72% (171/238) [65%, 78%] | 56% (115/206) [49%, 63%] | 49% (113/230) [41%, 57%] | 44% (106/242) [37%, 51%] | 62% (131/211) [55%, 69%] | 60% (90/151) [55%, 64%] | 63% (168/266) [58%, 68%] |

### t2 opus effort

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| claude-opus-5-5 high | 67% (72/108) [56%, 77%] | 63% (73/115) [56%, 73%] | 47% (52/111) [37%, 57%] | 47% (56/120) [35%, 58%] | 41% (52/127) [32%, 49%] | 54% (54/100) [44%, 63%] | 68% (51/75) [60%, 75%] | 73% (96/132) [66%, 79%] |
| claude-opus-5-5 low | 72% (46/64) [55%, 84%] | 42% (24/57) [35%, 50%] | 55% (29/53) [43%, 68%] | 39% (23/59) [29%, 53%] | 32% (21/65) [19%, 44%] | 60% (29/48) [45%, 78%] | 66% (27/41) [56%, 72%] | 60% (38/63) [54%, 68%] |
| claude-opus-5-5 medium | 71% (118/166) [64%, 77%] | 61% (109/180) [54%, 66%] | 50% (82/164) [42%, 59%] | 45% (92/204) [39%, 51%] | 39% (72/183) [33%, 46%] | 65% (97/150) [57%, 72%] | 63% (69/110) [56%, 69%] | 71% (132/187) [66%, 76%] |
| claude-opus-5-5 xhigh | 69% (82/118) [59%, 79%] | 71% (82/116) [63%, 79%] | 54% (54/100) [44%, 65%] | 42% (49/117) [29%, 55%] | 40% (50/124) [30%, 51%] | 62% (61/98) [51%, 73%] | 62% (52/84) [51%, 73%] | 74% (83/112) [68%, 81%] |

### t3 astra vs opus xhigh

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| claude-opus-5-5 xhigh | 60% (70/116) [50%, 70%] | 66% (82/125) [58%, 73%] | 52% (73/141) [45%, 59%] | 54% (72/133) [45%, 62%] | 40% (54/135) [31%, 48%] | 64% (63/99) [52%, 75%] | 63% (53/84) [55%, 71%] | 65% (80/123) [56%, 74%] |
| gpt-6-astra medium | 73% (90/124) [67%, 78%] | 68% (82/121) [59%, 77%] | 63% (85/135) [54%, 72%] | 39% (52/133) [29%, 50%] | 28% (35/126) [19%, 37%] | 57% (53/93) [46%, 67%] | 60% (45/75) [49%, 71%] | 69% (95/137) [60%, 78%] |

## Items held at elimination

Deaths, the share with at least one unused item, and the items held per death.

### t1 cross-model medium

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| claude-haiku-4-5-20251001 medium | 91% (245/270) [87%, 94%] | 3.61 (976/270) [3.35, 3.88] | inverter 197, burner phone 181, beer 171 |
| claude-haiku-5-5 medium | 92% (178/194) [88%, 95%] | 3.39 (658/194) [3.13, 3.65] | inverter 129, beer 106, adrenaline 105 |
| claude-opus-5-5 medium | 91% (161/176) [88%, 95%] | 3.34 (588/176) [3.07, 3.62] | inverter 140, beer 110, adrenaline 79 |
| claude-sonnet-5-5 medium | 92% (177/193) [87%, 96%] | 3.54 (684/193) [3.23, 3.86] | inverter 172, beer 125, adrenaline 125 |
| gpt-5.6-terra medium | 93% (202/217) [89%, 96%] | 3.33 (723/217) [3.02, 3.65] | inverter 165, burner phone 134, beer 134 |
| gpt-6-astra medium | 94% (144/154) [89%, 97%] | 3.23 (497/154) [2.90, 3.59] | inverter 126, beer 111, adrenaline 67 |
| gpt-6-luna medium | 84% (254/301) [81%, 88%] | 2.74 (824/301) [2.54, 2.93] | inverter 180, beer 137, adrenaline 127 |
| gpt-6.1-sol medium | 95% (167/175) [92%, 98%] | 3.46 (605/175) [3.18, 3.74] | inverter 142, beer 114, burner phone 78 |

### t1 effort sweep

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| claude-haiku-4-5-20251001 high | 93% (106/114) [88%, 97%] | 3.77 (430/114) [3.41, 4.11] | burner phone 86, inverter 82, beer 74 |
| claude-haiku-4-5-20251001 low | 93% (106/114) [88%, 97%] | 3.61 (412/114) [3.22, 4.00] | burner phone 90, inverter 85, adrenaline 73 |
| claude-haiku-4-5-20251001 medium | 96% (102/106) [92%, 99%] | 3.65 (387/106) [3.21, 4.09] | inverter 77, burner phone 71, beer 68 |
| claude-haiku-4-5-20251001 minimal | 87% (102/117) [82%, 93%] | 3.48 (407/117) [3.12, 3.87] | inverter 81, burner phone 71, beer 68 |
| claude-haiku-4-5-20251001 off | 89% (132/149) [82%, 94%] | 3.26 (485/149) [2.91, 3.58] | adrenaline 119, beer 79, inverter 79 |
| claude-haiku-5-5 high | 91% (126/139) [85%, 96%] | 3.16 (439/139) [2.80, 3.51] | beer 80, inverter 73, adrenaline 73 |
| claude-haiku-5-5 low | 87% (136/157) [82%, 91%] | 3.06 (481/157) [2.72, 3.41] | inverter 99, beer 76, adrenaline 75 |
| claude-haiku-5-5 max | 88% (112/127) [83%, 93%] | 3.15 (400/127) [2.87, 3.43] | beer 76, adrenaline 68, inverter 67 |
| claude-haiku-5-5 medium | 88% (133/152) [83%, 92%] | 2.91 (442/152) [2.55, 3.26] | beer 97, inverter 82, burner phone 62 |
| claude-haiku-5-5 off | 84% (160/190) [79%, 89%] | 2.78 (529/190) [2.46, 3.11] | inverter 137, adrenaline 84, beer 71 |
| claude-haiku-5-5 xhigh | 89% (120/135) [83%, 94%] | 3.50 (472/135) [3.18, 3.83] | inverter 107, beer 89, adrenaline 79 |
| claude-sonnet-5-5 high | 91% (138/152) [85%, 96%] | 3.29 (500/152) [2.96, 3.61] | inverter 128, adrenaline 82, beer 79 |
| claude-sonnet-5-5 low | 93% (161/174) [88%, 96%] | 3.38 (588/174) [3.04, 3.72] | inverter 149, adrenaline 115, beer 94 |
| claude-sonnet-5-5 max | 92% (101/110) [86%, 97%] | 3.09 (340/110) [2.72, 3.44] | inverter 73, beer 60, adrenaline 53 |
| claude-sonnet-5-5 medium | 90% (142/158) [85%, 95%] | 3.28 (518/158) [2.88, 3.65] | inverter 139, adrenaline 101, beer 87 |
| claude-sonnet-5-5 off | 91% (150/165) [86%, 95%] | 3.10 (511/165) [2.75, 3.42] | inverter 138, adrenaline 92, beer 66 |
| claude-sonnet-5-5 xhigh | 90% (127/141) [85%, 95%] | 3.18 (448/141) [2.87, 3.50] | inverter 106, beer 75, adrenaline 70 |
| gpt-5.6-terra high | 94% (111/118) [89%, 98%] | 3.46 (408/118) [3.09, 3.82] | inverter 105, beer 71, burner phone 65 |
| gpt-5.6-terra low | 95% (127/134) [91%, 98%] | 3.81 (511/134) [3.52, 4.13] | inverter 107, beer 95, burner phone 90 |
| gpt-5.6-terra max | 88% (98/111) [83%, 94%] | 2.88 (320/111) [2.50, 3.27] | inverter 78, beer 61, burner phone 45 |
| gpt-5.6-terra medium | 97% (128/132) [93%, 100%] | 4.33 (571/132) [3.94, 4.73] | inverter 122, burner phone 116, beer 100 |
| gpt-5.6-terra xhigh | 91% (96/105) [86%, 96%] | 3.23 (339/105) [2.87, 3.61] | inverter 77, beer 63, burner phone 51 |
| gpt-6-luna high | 89% (116/130) [84%, 94%] | 3.48 (452/130) [3.07, 3.88] | inverter 113, beer 77, adrenaline 70 |
| gpt-6-luna low | 76% (153/201) [70%, 82%] | 2.36 (474/201) [2.07, 2.65] | adrenaline 93, beer 90, inverter 70 |
| gpt-6-luna max | 82% (84/102) [74%, 90%] | 2.72 (277/102) [2.35, 3.09] | inverter 69, adrenaline 49, burner phone 42 |
| gpt-6-luna medium | 82% (141/171) [77%, 88%] | 2.87 (491/171) [2.59, 3.19] | inverter 95, beer 88, adrenaline 86 |
| gpt-6-luna off | 75% (145/194) [68%, 81%] | 2.34 (453/194) [2.09, 2.58] | beer 79, adrenaline 75, burner phone 62 |
| gpt-6-luna xhigh | 92% (94/102) [86%, 97%] | 3.21 (327/102) [2.72, 3.68] | inverter 74, adrenaline 71, burner phone 52 |
| gpt-6.1-sol high | 86% (108/125) [82%, 91%] | 3.09 (386/125) [2.73, 3.48] | inverter 74, beer 73, adrenaline 65 |
| gpt-6.1-sol low | 91% (112/123) [86%, 96%] | 3.26 (401/123) [2.86, 3.65] | inverter 89, beer 86, adrenaline 62 |
| gpt-6.1-sol max | 85% (93/109) [79%, 92%] | 3.27 (356/109) [2.81, 3.70] | inverter 78, beer 62, adrenaline 58 |
| gpt-6.1-sol medium | 89% (109/122) [84%, 94%] | 3.20 (390/122) [2.88, 3.53] | inverter 86, beer 65, adrenaline 61 |
| gpt-6.1-sol xhigh | 80% (97/121) [72%, 88%] | 3.03 (367/121) [2.50, 3.58] | inverter 74, adrenaline 63, beer 55 |

### t2 opus effort

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| claude-opus-5-5 high | 87% (58/67) [78%, 94%] | 3.00 (201/67) [2.46, 3.58] | beer 44, inverter 36, burner phone 27 |
| claude-opus-5-5 low | 90% (27/30) [75%, 100%] | 3.03 (91/30) [2.21, 3.79] | beer 24, inverter 21, burner phone 17 |
| claude-opus-5-5 medium | 90% (84/93) [84%, 96%] | 3.06 (285/93) [2.60, 3.54] | beer 61, inverter 54, burner phone 46 |
| claude-opus-5-5 xhigh | 86% (43/50) [76%, 95%] | 2.66 (133/50) [2.09, 3.30] | inverter 32, beer 23, magnifying glass 16 |

### t3 astra vs opus xhigh

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| claude-opus-5-5 xhigh | 90% (54/60) [84%, 98%] | 3.17 (190/60) [2.71, 3.73] | inverter 43, beer 30, adrenaline 28 |
| gpt-6-astra medium | 95% (60/63) [89%, 100%] | 3.24 (204/63) [2.79, 3.64] | inverter 59, beer 40, adrenaline 25 |

## Same-position consistency

Agent decisions grouped by the deciding player's own position. Exact: the same board, cash and round, the same log since the load, the same legal moves, code and instructions. Belief: the same board, load shown, cash, round, legal moves and versions, the same public and private shell beliefs, and the same count of clue items each opponent used this load. Players are named relative to the decider. Coverage is the share of decisions in a position seen at least twice. Non-modal is the share of those decisions that differ from their position's most common choice; it has no interval, because resampling blocks duplicates decisions and a copy always matches the mode. Two differ is the chance two different decisions in a position differ, averaged over positions, with an interval over pairs of distinct decisions.

### Exact positions

| Cohort | Model | Positions seen twice or more | Coverage | Non-modal choices | Two differ |
|---|---|---|---|---|---|
| t1 cross-model medium | claude-haiku-4-5-20251001 medium | 225 | 21% (643/3127) | 19% (124/643) | 36% over 225 positions [30%, 42%] |
| t1 cross-model medium | claude-haiku-5-5 medium | 256 | 22% (758/3500) | 12% (94/758) | 22% over 256 positions [18%, 27%] |
| t1 cross-model medium | claude-opus-5-5 medium | 327 | 26% (942/3589) | 6.1% (57/942) | 11% over 327 positions [8.7%, 14%] |
| t1 cross-model medium | claude-sonnet-5-5 medium | 307 | 26% (895/3506) | 5.9% (53/895) | 12% over 307 positions [8.7%, 15%] |
| t1 cross-model medium | gpt-5.6-terra medium | 224 | 16% (546/3401) | 12% (65/546) | 24% over 224 positions [18%, 30%] |
| t1 cross-model medium | gpt-6-astra medium | 331 | 29% (991/3462) | 2.5% (25/991) | 4.9% over 331 positions [3.4%, 6.6%] |
| t1 cross-model medium | gpt-6-luna medium | 259 | 20% (754/3740) | 17% (131/754) | 32% over 259 positions [27%, 36%] |
| t1 cross-model medium | gpt-6.1-sol medium | 337 | 27% (960/3494) | 4.7% (45/960) | 7.7% over 337 positions [6.2%, 12%] |
| t1 effort sweep | claude-haiku-4-5-20251001 high | 84 | 11% (228/2083) | 17% (38/228) | 34% over 84 positions [24%, 40%] |
| t1 effort sweep | claude-haiku-4-5-20251001 low | 97 | 12% (250/2125) | 17% (42/250) | 32% over 97 positions [25%, 39%] |
| t1 effort sweep | claude-haiku-4-5-20251001 medium | 106 | 14% (296/2175) | 15% (43/296) | 29% over 106 positions [20%, 36%] |
| t1 effort sweep | claude-haiku-4-5-20251001 minimal | 115 | 15% (308/2080) | 15% (46/308) | 32% over 115 positions [22%, 36%] |
| t1 effort sweep | claude-haiku-4-5-20251001 off | 105 | 13% (285/2173) | 18% (52/285) | 34% over 105 positions [28%, 43%] |
| t1 effort sweep | claude-haiku-5-5 high | 186 | 21% (525/2513) | 9.1% (48/525) | 19% over 186 positions [13%, 23%] |
| t1 effort sweep | claude-haiku-5-5 low | 235 | 26% (641/2513) | 9.4% (60/641) | 19% over 235 positions [14%, 23%] |
| t1 effort sweep | claude-haiku-5-5 max | 247 | 26% (667/2573) | 9.7% (65/667) | 19% over 247 positions [14%, 23%] |
| t1 effort sweep | claude-haiku-5-5 medium | 222 | 24% (624/2558) | 8.5% (53/624) | 16% over 222 positions [12%, 20%] |
| t1 effort sweep | claude-haiku-5-5 off | 248 | 27% (655/2387) | 12% (78/655) | 22% over 248 positions [18%, 28%] |
| t1 effort sweep | claude-haiku-5-5 xhigh | 266 | 27% (692/2534) | 8.4% (58/692) | 15% over 266 positions [12%, 19%] |
| t1 effort sweep | claude-sonnet-5-5 high | 302 | 34% (842/2455) | 5.8% (49/842) | 12% over 302 positions [7.8%, 14%] |
| t1 effort sweep | claude-sonnet-5-5 low | 260 | 32% (747/2338) | 7.9% (59/747) | 16% over 260 positions [12%, 19%] |
| t1 effort sweep | claude-sonnet-5-5 max | 311 | 37% (955/2568) | 5.4% (52/955) | 12% over 311 positions [7.9%, 13%] |
| t1 effort sweep | claude-sonnet-5-5 medium | 284 | 33% (826/2495) | 5.7% (47/826) | 11% over 284 positions [7.8%, 14%] |
| t1 effort sweep | claude-sonnet-5-5 off | 327 | 41% (988/2415) | 6.1% (60/988) | 12% over 327 positions [8.8%, 15%] |
| t1 effort sweep | claude-sonnet-5-5 xhigh | 262 | 33% (813/2439) | 5.9% (48/813) | 12% over 262 positions [8.7%, 15%] |
| t1 effort sweep | gpt-5.6-terra high | 128 | 19% (351/1886) | 14% (49/351) | 27% over 128 positions [20%, 33%] |
| t1 effort sweep | gpt-5.6-terra low | 152 | 20% (374/1852) | 13% (50/374) | 24% over 152 positions [19%, 35%] |
| t1 effort sweep | gpt-5.6-terra max | 185 | 23% (503/2170) | 9.3% (47/503) | 20% over 185 positions [12%, 24%] |
| t1 effort sweep | gpt-5.6-terra medium | 160 | 22% (403/1792) | 13% (51/403) | 24% over 160 positions [18%, 32%] |
| t1 effort sweep | gpt-5.6-terra xhigh | 135 | 17% (355/2030) | 14% (48/355) | 29% over 135 positions [21%, 34%] |
| t1 effort sweep | gpt-6-luna high | 135 | 13% (358/2829) | 18% (63/358) | 32% over 135 positions [26%, 40%] |
| t1 effort sweep | gpt-6-luna low | 160 | 15% (436/2920) | 19% (85/436) | 36% over 160 positions [30%, 44%] |
| t1 effort sweep | gpt-6-luna max | 153 | 15% (433/2936) | 11% (46/433) | 21% over 153 positions [16%, 26%] |
| t1 effort sweep | gpt-6-luna medium | 123 | 12% (342/2866) | 16% (54/342) | 28% over 123 positions [22%, 38%] |
| t1 effort sweep | gpt-6-luna off | 155 | 14% (413/2888) | 16% (67/413) | 30% over 155 positions [24%, 37%] |
| t1 effort sweep | gpt-6-luna xhigh | 139 | 13% (375/2792) | 15% (55/375) | 28% over 139 positions [21%, 36%] |
| t1 effort sweep | gpt-6.1-sol high | 302 | 41% (801/1951) | 5.5% (44/801) | 11% over 302 positions [7.7%, 13%] |
| t1 effort sweep | gpt-6.1-sol low | 291 | 42% (776/1851) | 4.4% (34/776) | 8.4% over 291 positions [5.7%, 11%] |
| t1 effort sweep | gpt-6.1-sol max | 321 | 43% (886/2054) | 5.5% (49/886) | 12% over 321 positions [7.8%, 14%] |
| t1 effort sweep | gpt-6.1-sol medium | 283 | 41% (784/1907) | 4.3% (34/784) | 8.9% over 283 positions [6.1%, 11%] |
| t1 effort sweep | gpt-6.1-sol xhigh | 290 | 40% (777/1963) | 6.3% (49/777) | 11% over 290 positions [8.6%, 16%] |
| t2 opus effort | claude-opus-5-5 high | 149 | 31% (301/970) | 5.0% (15/301) | 9.6% over 149 positions [2.3%, 25%] |
| t2 opus effort | claude-opus-5-5 low | 3 | 1.3% (6/468) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| t2 opus effort | claude-opus-5-5 medium | 202 | 34% (502/1458) | 4.8% (24/502) | 11% over 202 positions [6.4%, 13%] |
| t2 opus effort | claude-opus-5-5 xhigh | 157 | 33% (319/969) | 5.6% (18/319) | 11% over 157 positions [5.3%, 23%] |
| t3 astra vs opus xhigh | claude-opus-5-5 xhigh | 1 | 0.2% (2/1055) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| t3 astra vs opus xhigh | gpt-6-astra medium | 0 | 0% (0/1030) | – | – |

### Belief positions

| Cohort | Model | Positions seen twice or more | Coverage | Non-modal choices | Two differ |
|---|---|---|---|---|---|
| t1 cross-model medium | claude-haiku-4-5-20251001 medium | 244 | 22% (697/3127) | 19% (133/697) | 36% over 244 positions [30%, 42%] |
| t1 cross-model medium | claude-haiku-5-5 medium | 284 | 24% (845/3500) | 12% (99/845) | 20% over 284 positions [17%, 25%] |
| t1 cross-model medium | claude-opus-5-5 medium | 347 | 29% (1023/3589) | 5.9% (60/1023) | 10% over 347 positions [8.3%, 13%] |
| t1 cross-model medium | claude-sonnet-5-5 medium | 333 | 28% (967/3506) | 6.2% (60/967) | 13% over 333 positions [9.3%, 16%] |
| t1 cross-model medium | gpt-5.6-terra medium | 240 | 17% (589/3401) | 12% (70/589) | 24% over 240 positions [18%, 29%] |
| t1 cross-model medium | gpt-6-astra medium | 349 | 30% (1035/3462) | 2.6% (27/1035) | 5.2% over 349 positions [3.4%, 6.8%] |
| t1 cross-model medium | gpt-6-luna medium | 281 | 22% (808/3740) | 17% (139/808) | 31% over 281 positions [27%, 37%] |
| t1 cross-model medium | gpt-6.1-sol medium | 362 | 30% (1036/3494) | 4.4% (46/1036) | 7.5% over 362 positions [6.1%, 11%] |
| t1 effort sweep | claude-haiku-4-5-20251001 high | 91 | 12% (244/2083) | 17% (42/244) | 35% over 91 positions [25%, 41%] |
| t1 effort sweep | claude-haiku-4-5-20251001 low | 107 | 13% (271/2125) | 17% (45/271) | 31% over 107 positions [25%, 38%] |
| t1 effort sweep | claude-haiku-4-5-20251001 medium | 112 | 14% (308/2175) | 14% (43/308) | 28% over 112 positions [20%, 34%] |
| t1 effort sweep | claude-haiku-4-5-20251001 minimal | 121 | 15% (322/2080) | 15% (49/322) | 32% over 121 positions [22%, 36%] |
| t1 effort sweep | claude-haiku-4-5-20251001 off | 110 | 14% (297/2173) | 18% (53/297) | 33% over 110 positions [28%, 42%] |
| t1 effort sweep | claude-haiku-5-5 high | 223 | 25% (616/2513) | 9.3% (57/616) | 19% over 223 positions [13%, 24%] |
| t1 effort sweep | claude-haiku-5-5 low | 261 | 28% (715/2513) | 10% (72/715) | 21% over 261 positions [15%, 24%] |
| t1 effort sweep | claude-haiku-5-5 max | 292 | 31% (793/2573) | 9.2% (73/793) | 19% over 292 positions [14%, 22%] |
| t1 effort sweep | claude-haiku-5-5 medium | 245 | 27% (679/2558) | 8.8% (60/679) | 17% over 245 positions [13%, 21%] |
| t1 effort sweep | claude-haiku-5-5 off | 273 | 30% (720/2387) | 12% (86/720) | 22% over 273 positions [17%, 28%] |
| t1 effort sweep | claude-haiku-5-5 xhigh | 304 | 31% (785/2534) | 7.6% (60/785) | 14% over 304 positions [11%, 17%] |
| t1 effort sweep | claude-sonnet-5-5 high | 326 | 37% (898/2455) | 5.8% (52/898) | 12% over 326 positions [7.5%, 14%] |
| t1 effort sweep | claude-sonnet-5-5 low | 263 | 33% (769/2338) | 8.3% (64/769) | 17% over 263 positions [12%, 19%] |
| t1 effort sweep | claude-sonnet-5-5 max | 332 | 40% (1020/2568) | 5.4% (55/1020) | 12% over 332 positions [7.7%, 13%] |
| t1 effort sweep | claude-sonnet-5-5 medium | 294 | 35% (862/2495) | 6.0% (52/862) | 12% over 294 positions [8.5%, 15%] |
| t1 effort sweep | claude-sonnet-5-5 off | 334 | 42% (1021/2415) | 6.5% (66/1021) | 13% over 334 positions [9.6%, 16%] |
| t1 effort sweep | claude-sonnet-5-5 xhigh | 280 | 36% (867/2439) | 5.8% (50/867) | 12% over 280 positions [8.5%, 14%] |
| t1 effort sweep | gpt-5.6-terra high | 140 | 21% (388/1886) | 13% (52/388) | 27% over 140 positions [19%, 31%] |
| t1 effort sweep | gpt-5.6-terra low | 173 | 23% (422/1852) | 14% (58/422) | 26% over 173 positions [20%, 34%] |
| t1 effort sweep | gpt-5.6-terra max | 208 | 26% (558/2170) | 9.0% (50/558) | 19% over 208 positions [12%, 22%] |
| t1 effort sweep | gpt-5.6-terra medium | 176 | 25% (453/1792) | 13% (57/453) | 23% over 176 positions [19%, 31%] |
| t1 effort sweep | gpt-5.6-terra xhigh | 156 | 20% (405/2030) | 12% (50/405) | 26% over 156 positions [19%, 32%] |
| t1 effort sweep | gpt-6-luna high | 159 | 15% (421/2829) | 17% (73/421) | 31% over 159 positions [26%, 38%] |
| t1 effort sweep | gpt-6-luna low | 193 | 17% (508/2920) | 20% (102/508) | 38% over 193 positions [31%, 46%] |
| t1 effort sweep | gpt-6-luna max | 170 | 16% (471/2936) | 12% (55/471) | 24% over 170 positions [18%, 28%] |
| t1 effort sweep | gpt-6-luna medium | 148 | 14% (400/2866) | 17% (69/400) | 32% over 148 positions [24%, 40%] |
| t1 effort sweep | gpt-6-luna off | 175 | 16% (458/2888) | 18% (82/458) | 34% over 175 positions [27%, 41%] |
| t1 effort sweep | gpt-6-luna xhigh | 161 | 16% (435/2792) | 14% (62/435) | 27% over 161 positions [19%, 34%] |
| t1 effort sweep | gpt-6.1-sol high | 316 | 43% (845/1951) | 5.4% (46/845) | 10% over 316 positions [7.6%, 13%] |
| t1 effort sweep | gpt-6.1-sol low | 305 | 44% (820/1851) | 4.5% (37/820) | 8.9% over 305 positions [6.1%, 11%] |
| t1 effort sweep | gpt-6.1-sol max | 339 | 45% (929/2054) | 5.6% (52/929) | 12% over 339 positions [8.0%, 14%] |
| t1 effort sweep | gpt-6.1-sol medium | 292 | 43% (821/1907) | 4.3% (35/821) | 9.0% over 292 positions [5.8%, 11%] |
| t1 effort sweep | gpt-6.1-sol xhigh | 304 | 42% (821/1963) | 6.5% (53/821) | 11% over 304 positions [8.8%, 17%] |
| t2 opus effort | claude-opus-5-5 high | 158 | 33% (319/970) | 5.3% (17/319) | 10% over 158 positions [4.0%, 25%] |
| t2 opus effort | claude-opus-5-5 low | 3 | 1.3% (6/468) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| t2 opus effort | claude-opus-5-5 medium | 221 | 37% (545/1458) | 5.0% (27/545) | 11% over 221 positions [6.4%, 13%] |
| t2 opus effort | claude-opus-5-5 xhigh | 168 | 35% (343/969) | 5.8% (20/343) | 12% over 168 positions [5.9%, 21%] |
| t3 astra vs opus xhigh | claude-opus-5-5 xhigh | 1 | 0.2% (2/1055) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| t3 astra vs opus xhigh | gpt-6-astra medium | 0 | 0% (0/1030) | – | – |

## Agreement between effort variants

For each pair of one model's effort levels in the same cohort, exact positions both met. Across: the chance a random decision of each variant agrees, averaged over shared positions. Within: for comparison, the chance two decisions of the same variant agree, over shared positions that variant met at least twice.

| Cohort | Variants | Shared positions | Across | Within, first | Within, second |
|---|---|---|---|---|---|
| t1 effort sweep | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 low | 195 | 69% over 195 positions [64%, 75%] | 66% over 60 positions [62%, 77%] | 70% over 71 positions [62%, 77%] |
| t1 effort sweep | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 medium | 170 | 70% over 170 positions [64%, 77%] | 72% over 55 positions [64%, 82%] | 74% over 66 positions [65%, 84%] |
| t1 effort sweep | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 minimal | 169 | 69% over 169 positions [65%, 76%] | 67% over 59 positions [60%, 77%] | 74% over 75 positions [69%, 83%] |
| t1 effort sweep | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 off | 147 | 67% over 147 positions [60%, 72%] | 69% over 50 positions [63%, 80%] | 71% over 76 positions [60%, 79%] |
| t1 effort sweep | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 medium | 186 | 70% over 186 positions [63%, 75%] | 70% over 69 positions [62%, 77%] | 74% over 78 positions [67%, 83%] |
| t1 effort sweep | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 minimal | 160 | 64% over 160 positions [61%, 72%] | 66% over 61 positions [58%, 77%] | 72% over 78 positions [68%, 83%] |
| t1 effort sweep | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 off | 162 | 61% over 162 positions [55%, 68%] | 71% over 61 positions [62%, 80%] | 69% over 74 positions [59%, 76%] |
| t1 effort sweep | claude-haiku-4-5-20251001 medium vs claude-haiku-4-5-20251001 minimal | 173 | 69% over 173 positions [66%, 76%] | 77% over 70 positions [64%, 85%] | 73% over 70 positions [67%, 84%] |
| t1 effort sweep | claude-haiku-4-5-20251001 medium vs claude-haiku-4-5-20251001 off | 128 | 67% over 128 positions [58%, 72%] | 75% over 54 positions [67%, 85%] | 69% over 69 positions [59%, 77%] |
| t1 effort sweep | claude-haiku-4-5-20251001 minimal vs claude-haiku-4-5-20251001 off | 137 | 59% over 137 positions [55%, 68%] | 77% over 73 positions [70%, 87%] | 65% over 62 positions [55%, 76%] |
| t1 effort sweep | claude-haiku-5-5 high vs claude-haiku-5-5 low | 442 | 79% over 442 positions [77%, 83%] | 80% over 141 positions [75%, 87%] | 82% over 178 positions [79%, 87%] |
| t1 effort sweep | claude-haiku-5-5 high vs claude-haiku-5-5 max | 324 | 77% over 324 positions [72%, 81%] | 81% over 102 positions [76%, 88%] | 82% over 147 positions [77%, 87%] |
| t1 effort sweep | claude-haiku-5-5 high vs claude-haiku-5-5 medium | 356 | 79% over 356 positions [76%, 83%] | 85% over 146 positions [79%, 90%] | 84% over 161 positions [79%, 88%] |
| t1 effort sweep | claude-haiku-5-5 high vs claude-haiku-5-5 off | 251 | 67% over 251 positions [61%, 72%] | 79% over 90 positions [74%, 89%] | 77% over 114 positions [70%, 84%] |
| t1 effort sweep | claude-haiku-5-5 high vs claude-haiku-5-5 xhigh | 395 | 82% over 395 positions [79%, 85%] | 81% over 136 positions [76%, 88%] | 84% over 187 positions [80%, 88%] |
| t1 effort sweep | claude-haiku-5-5 low vs claude-haiku-5-5 max | 234 | 67% over 234 positions [62%, 73%] | 80% over 99 positions [75%, 88%] | 82% over 106 positions [78%, 88%] |
| t1 effort sweep | claude-haiku-5-5 low vs claude-haiku-5-5 medium | 399 | 78% over 399 positions [75%, 81%] | 81% over 157 positions [77%, 88%] | 82% over 150 positions [78%, 87%] |
| t1 effort sweep | claude-haiku-5-5 low vs claude-haiku-5-5 off | 265 | 69% over 265 positions [64%, 74%] | 81% over 109 positions [78%, 87%] | 79% over 118 positions [72%, 85%] |
| t1 effort sweep | claude-haiku-5-5 low vs claude-haiku-5-5 xhigh | 299 | 71% over 299 positions [68%, 77%] | 81% over 144 positions [77%, 88%] | 80% over 146 positions [76%, 85%] |
| t1 effort sweep | claude-haiku-5-5 max vs claude-haiku-5-5 medium | 257 | 70% over 257 positions [67%, 75%] | 81% over 107 positions [76%, 87%] | 83% over 113 positions [77%, 88%] |
| t1 effort sweep | claude-haiku-5-5 max vs claude-haiku-5-5 off | 172 | 59% over 172 positions [53%, 65%] | 80% over 79 positions [74%, 89%] | 74% over 86 positions [67%, 84%] |
| t1 effort sweep | claude-haiku-5-5 max vs claude-haiku-5-5 xhigh | 381 | 81% over 381 positions [77%, 84%] | 83% over 152 positions [79%, 87%] | 83% over 172 positions [79%, 86%] |
| t1 effort sweep | claude-haiku-5-5 medium vs claude-haiku-5-5 off | 257 | 67% over 257 positions [62%, 73%] | 84% over 105 positions [78%, 88%] | 77% over 117 positions [71%, 83%] |
| t1 effort sweep | claude-haiku-5-5 medium vs claude-haiku-5-5 xhigh | 289 | 76% over 289 positions [73%, 80%] | 84% over 117 positions [79%, 88%] | 84% over 145 positions [79%, 88%] |
| t1 effort sweep | claude-haiku-5-5 off vs claude-haiku-5-5 xhigh | 188 | 63% over 188 positions [56%, 67%] | 76% over 86 positions [67%, 85%] | 84% over 105 positions [76%, 88%] |
| t1 effort sweep | claude-sonnet-5-5 high vs claude-sonnet-5-5 low | 406 | 85% over 406 positions [82%, 88%] | 87% over 203 positions [85%, 92%] | 87% over 193 positions [83%, 90%] |
| t1 effort sweep | claude-sonnet-5-5 high vs claude-sonnet-5-5 max | 210 | 76% over 210 positions [73%, 80%] | 94% over 141 positions [91%, 97%] | 90% over 126 positions [88%, 95%] |
| t1 effort sweep | claude-sonnet-5-5 high vs claude-sonnet-5-5 medium | 403 | 86% over 403 positions [84%, 90%] | 90% over 219 positions [88%, 94%] | 89% over 197 positions [87%, 93%] |
| t1 effort sweep | claude-sonnet-5-5 high vs claude-sonnet-5-5 off | 345 | 84% over 345 positions [80%, 88%] | 89% over 159 positions [86%, 93%] | 89% over 178 positions [86%, 93%] |
| t1 effort sweep | claude-sonnet-5-5 high vs claude-sonnet-5-5 xhigh | 406 | 83% over 406 positions [82%, 87%] | 92% over 204 positions [89%, 95%] | 89% over 203 positions [87%, 93%] |
| t1 effort sweep | claude-sonnet-5-5 low vs claude-sonnet-5-5 max | 180 | 73% over 180 positions [67%, 76%] | 86% over 108 positions [81%, 90%] | 90% over 109 positions [87%, 94%] |
| t1 effort sweep | claude-sonnet-5-5 low vs claude-sonnet-5-5 medium | 488 | 89% over 488 positions [85%, 91%] | 87% over 214 positions [84%, 90%] | 90% over 215 positions [87%, 93%] |
| t1 effort sweep | claude-sonnet-5-5 low vs claude-sonnet-5-5 off | 371 | 84% over 371 positions [81%, 87%] | 88% over 192 positions [85%, 91%] | 89% over 221 positions [87%, 93%] |
| t1 effort sweep | claude-sonnet-5-5 low vs claude-sonnet-5-5 xhigh | 296 | 81% over 296 positions [77%, 85%] | 87% over 155 positions [83%, 92%] | 90% over 146 positions [88%, 94%] |
| t1 effort sweep | claude-sonnet-5-5 max vs claude-sonnet-5-5 medium | 199 | 72% over 199 positions [69%, 77%] | 89% over 118 positions [86%, 94%] | 92% over 103 positions [88%, 96%] |
| t1 effort sweep | claude-sonnet-5-5 max vs claude-sonnet-5-5 off | 160 | 66% over 160 positions [63%, 72%] | 88% over 100 positions [85%, 94%] | 92% over 99 positions [88%, 96%] |
| t1 effort sweep | claude-sonnet-5-5 max vs claude-sonnet-5-5 xhigh | 326 | 78% over 326 positions [74%, 82%] | 88% over 147 positions [86%, 93%] | 90% over 153 positions [87%, 93%] |
| t1 effort sweep | claude-sonnet-5-5 medium vs claude-sonnet-5-5 off | 395 | 85% over 395 positions [83%, 89%] | 88% over 199 positions [85%, 92%] | 87% over 212 positions [84%, 91%] |
| t1 effort sweep | claude-sonnet-5-5 medium vs claude-sonnet-5-5 xhigh | 306 | 79% over 306 positions [78%, 84%] | 91% over 164 positions [88%, 95%] | 89% over 164 positions [88%, 94%] |
| t1 effort sweep | claude-sonnet-5-5 off vs claude-sonnet-5-5 xhigh | 271 | 79% over 271 positions [76%, 83%] | 92% over 159 positions [89%, 95%] | 88% over 142 positions [86%, 92%] |
| t1 effort sweep | gpt-5.6-terra high vs gpt-5.6-terra low | 257 | 76% over 257 positions [71%, 79%] | 75% over 93 positions [69%, 83%] | 74% over 100 positions [63%, 80%] |
| t1 effort sweep | gpt-5.6-terra high vs gpt-5.6-terra max | 204 | 72% over 204 positions [67%, 78%] | 76% over 95 positions [70%, 84%] | 85% over 112 positions [79%, 91%] |
| t1 effort sweep | gpt-5.6-terra high vs gpt-5.6-terra medium | 236 | 74% over 236 positions [70%, 79%] | 75% over 92 positions [70%, 84%] | 77% over 115 positions [69%, 83%] |
| t1 effort sweep | gpt-5.6-terra high vs gpt-5.6-terra xhigh | 224 | 70% over 224 positions [67%, 75%] | 74% over 92 positions [69%, 83%] | 77% over 94 positions [69%, 84%] |
| t1 effort sweep | gpt-5.6-terra low vs gpt-5.6-terra max | 210 | 70% over 210 positions [64%, 76%] | 74% over 85 positions [63%, 82%] | 82% over 105 positions [76%, 90%] |
| t1 effort sweep | gpt-5.6-terra low vs gpt-5.6-terra medium | 285 | 78% over 285 positions [73%, 82%] | 74% over 101 positions [64%, 80%] | 77% over 124 positions [67%, 83%] |
| t1 effort sweep | gpt-5.6-terra low vs gpt-5.6-terra xhigh | 221 | 71% over 221 positions [67%, 77%] | 76% over 85 positions [64%, 82%] | 78% over 93 positions [70%, 85%] |
| t1 effort sweep | gpt-5.6-terra max vs gpt-5.6-terra medium | 221 | 71% over 221 positions [65%, 76%] | 82% over 100 positions [76%, 90%] | 77% over 106 positions [67%, 83%] |
| t1 effort sweep | gpt-5.6-terra max vs gpt-5.6-terra xhigh | 227 | 72% over 227 positions [70%, 78%] | 86% over 118 positions [81%, 91%] | 77% over 96 positions [69%, 84%] |
| t1 effort sweep | gpt-5.6-terra medium vs gpt-5.6-terra xhigh | 192 | 69% over 192 positions [66%, 75%] | 77% over 102 positions [69%, 83%] | 76% over 90 positions [68%, 83%] |
| t1 effort sweep | gpt-6-luna high vs gpt-6-luna low | 179 | 54% over 179 positions [49%, 61%] | 67% over 76 positions [60%, 75%] | 70% over 88 positions [59%, 76%] |
| t1 effort sweep | gpt-6-luna high vs gpt-6-luna max | 212 | 69% over 212 positions [63%, 74%] | 67% over 71 positions [59%, 76%] | 75% over 83 positions [72%, 83%] |
| t1 effort sweep | gpt-6-luna high vs gpt-6-luna medium | 194 | 66% over 194 positions [59%, 71%] | 64% over 74 positions [58%, 74%] | 72% over 74 positions [64%, 78%] |
| t1 effort sweep | gpt-6-luna high vs gpt-6-luna off | 145 | 52% over 145 positions [47%, 59%] | 62% over 64 positions [57%, 72%] | 71% over 76 positions [61%, 77%] |
| t1 effort sweep | gpt-6-luna high vs gpt-6-luna xhigh | 245 | 71% over 245 positions [64%, 76%] | 65% over 77 positions [59%, 74%] | 72% over 90 positions [63%, 79%] |
| t1 effort sweep | gpt-6-luna low vs gpt-6-luna max | 165 | 50% over 165 positions [47%, 58%] | 67% over 73 positions [56%, 74%] | 81% over 77 positions [76%, 87%] |
| t1 effort sweep | gpt-6-luna low vs gpt-6-luna medium | 215 | 63% over 215 positions [57%, 69%] | 66% over 90 positions [57%, 74%] | 71% over 82 positions [63%, 79%] |
| t1 effort sweep | gpt-6-luna low vs gpt-6-luna off | 278 | 68% over 278 positions [62%, 73%] | 62% over 93 positions [54%, 70%] | 75% over 100 positions [65%, 81%] |
| t1 effort sweep | gpt-6-luna low vs gpt-6-luna xhigh | 159 | 55% over 159 positions [48%, 61%] | 72% over 85 positions [60%, 78%] | 73% over 71 positions [63%, 81%] |
| t1 effort sweep | gpt-6-luna max vs gpt-6-luna medium | 190 | 65% over 190 positions [59%, 71%] | 82% over 84 positions [76%, 87%] | 71% over 70 positions [64%, 79%] |
| t1 effort sweep | gpt-6-luna max vs gpt-6-luna off | 175 | 59% over 175 positions [53%, 65%] | 82% over 70 positions [75%, 88%] | 72% over 78 positions [63%, 79%] |
| t1 effort sweep | gpt-6-luna max vs gpt-6-luna xhigh | 263 | 78% over 263 positions [72%, 81%] | 80% over 95 positions [76%, 86%] | 74% over 91 positions [66%, 82%] |
| t1 effort sweep | gpt-6-luna medium vs gpt-6-luna off | 217 | 67% over 217 positions [62%, 73%] | 73% over 88 positions [63%, 79%] | 70% over 88 positions [59%, 77%] |
| t1 effort sweep | gpt-6-luna medium vs gpt-6-luna xhigh | 182 | 65% over 182 positions [56%, 70%] | 72% over 70 positions [65%, 79%] | 69% over 66 positions [60%, 79%] |
| t1 effort sweep | gpt-6-luna off vs gpt-6-luna xhigh | 141 | 54% over 141 positions [49%, 61%] | 74% over 75 positions [63%, 81%] | 78% over 69 positions [65%, 84%] |
| t1 effort sweep | gpt-6.1-sol high vs gpt-6.1-sol low | 446 | 89% over 446 positions [86%, 91%] | 92% over 221 positions [88%, 94%] | 93% over 214 positions [90%, 95%] |
| t1 effort sweep | gpt-6.1-sol high vs gpt-6.1-sol max | 328 | 86% over 328 positions [84%, 88%] | 90% over 182 positions [87%, 94%] | 90% over 188 positions [88%, 94%] |
| t1 effort sweep | gpt-6.1-sol high vs gpt-6.1-sol medium | 455 | 91% over 455 positions [88%, 92%] | 91% over 219 positions [87%, 94%] | 92% over 220 positions [90%, 95%] |
| t1 effort sweep | gpt-6.1-sol high vs gpt-6.1-sol xhigh | 434 | 88% over 434 positions [86%, 91%] | 92% over 239 positions [89%, 94%] | 89% over 240 positions [83%, 91%] |
| t1 effort sweep | gpt-6.1-sol low vs gpt-6.1-sol max | 259 | 84% over 259 positions [82%, 88%] | 93% over 172 positions [89%, 95%] | 91% over 168 positions [89%, 95%] |
| t1 effort sweep | gpt-6.1-sol low vs gpt-6.1-sol medium | 524 | 92% over 524 positions [90%, 93%] | 92% over 244 positions [89%, 95%] | 91% over 216 positions [89%, 94%] |
| t1 effort sweep | gpt-6.1-sol low vs gpt-6.1-sol xhigh | 340 | 85% over 340 positions [82%, 88%] | 94% over 204 positions [91%, 96%] | 90% over 197 positions [84%, 92%] |
| t1 effort sweep | gpt-6.1-sol max vs gpt-6.1-sol medium | 320 | 87% over 320 positions [84%, 90%] | 91% over 184 positions [89%, 95%] | 92% over 160 positions [90%, 96%] |
| t1 effort sweep | gpt-6.1-sol max vs gpt-6.1-sol xhigh | 406 | 89% over 406 positions [86%, 91%] | 89% over 224 positions [87%, 93%] | 88% over 217 positions [83%, 91%] |
| t1 effort sweep | gpt-6.1-sol medium vs gpt-6.1-sol xhigh | 383 | 88% over 383 positions [85%, 90%] | 93% over 204 positions [91%, 96%] | 89% over 192 positions [83%, 92%] |
| t2 opus effort | claude-opus-5-5 high vs claude-opus-5-5 low | 150 | 86% over 150 positions [78%, 91%] | 93% over 99 positions [73%, 100%] | 100% over 2 positions [100%, 100%] |
| t2 opus effort | claude-opus-5-5 high vs claude-opus-5-5 medium | 353 | 90% over 353 positions [88%, 93%] | 91% over 146 positions [73%, 98%] | 91% over 170 positions [88%, 95%] |
| t2 opus effort | claude-opus-5-5 high vs claude-opus-5-5 xhigh | 203 | 86% over 203 positions [83%, 90%] | 94% over 108 positions [78%, 100%] | 87% over 116 positions [76%, 93%] |
| t2 opus effort | claude-opus-5-5 low vs claude-opus-5-5 medium | 181 | 85% over 181 positions [81%, 89%] | 100% over 1 positions [100%, 100%] | 96% over 106 positions [91%, 99%] |
| t2 opus effort | claude-opus-5-5 low vs claude-opus-5-5 xhigh | 139 | 83% over 139 positions [74%, 88%] | – | 91% over 88 positions [77%, 98%] |
| t2 opus effort | claude-opus-5-5 medium vs claude-opus-5-5 xhigh | 294 | 89% over 294 positions [87%, 91%] | 92% over 158 positions [89%, 97%] | 89% over 119 positions [79%, 97%] |
