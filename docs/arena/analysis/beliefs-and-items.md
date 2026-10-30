# Beliefs and items

What each model knew about the shotgun when it chose a move, whether it acted on that knowledge, what happened to its items, and whether it chose the same way in the same position. Every judgement uses only the deciding player's own information: the public log and its own clues. Another player's clues and the hidden shell order never enter. The tables call these choice patterns. A move is called dominated only where the player's own information shows it.

DeepSeek (`deepseek-v4.1-flash`) is left out entirely. Every match with a DeepSeek seat is dropped from every table below, including its opponents' moves in those matches.

## Summary

Scope: the 2,533 scored matches of the nine cohorts in the Coverage table, with no DeepSeek seat, from the knowledge database rebuilt on 2026-10-30 from the 2,553-match snapshot of the analysis database (the first imported tournament 5 subset, 62 matches, is included). The cohorts are Cross-model (every match between different models, 931 matches) and one effort cohort per model (every match of that model against itself, 1,602 matches in all).

The prose summary written for the earlier 2,471-match scope is removed. Its figures were typed by hand, were not regenerated and cannot be reproduced from the tables below, so they would describe a scope this page no longer has. The tables are the findings: each rate is numerator/denominator with a 95% interval over seed blocks. Tournament 5's cohorts are small (Terra 6.1 efforts has 14 matches, and the 40 new Cross-model matches are spread over many pairings and efforts), so their rows are wide and say little on their own.

## How it was measured

**Own information.** `web/scripts/arena-knowledge.ts` replays every replay-validated match in the analysis database through `replayOf`, the viewer's replay over the generated Bend rules. Before each accepted move it takes the deciding player's log since the latest load: the public events, plus the secrets that player heard, in the order it heard them. That log goes to the shell belief of the Bend minimax player (`belief.orders.log` in `sim/bend-mp/player/belief.bend`). It enumerates every shell order the log allows, with multiplicity, once with the public log alone and once with the player's own clues as well. Everything else is read off those orders: the live/blank composition left, the chance each position is live, and which positions are certain. TypeScript only marshals the log and counts orders. It never applies a shot, beer or inverter itself. The output is a separate SQLite database, `_work/arena/analysis/derived/knowledge.sqlite`, with one row per non-forced decision, per clue, per placed item and per death. `web/scripts/arena-knowledge-report.ts` turns it into the tables below.

- **Chamber certain:** every order the player's log allows has the same chambered shell.
- **Source of certainty:** *public* if the public log alone settles it (counting, for example when only live shells are left). Otherwise *glass* or *phone*: the most recent single clue that settles it together with the public log. *Combined* means only several clues together settle it. A clue from an item taken with adrenaline counts with its item.
- **Moves since the clue:** accepted moves by either player, forced grabs included, between the move that produced the clue and the shot. 0 is the very next move.
- **Item fates:** a ledger follows each placed item through the public log. Its owner uses it, or it is stolen with adrenaline, or it is still held when the owner dies, or it is still held when the round or match ends (censored). At every decision the ledger must match the board slot by slot.
- **Use when legal:** at each agent decision, whether a move that spends the item is on the menu, and whether the player chose it. "Jam Player X" spends a jammer. Steals are counted separately from the player's own items.
- **Same position:** two decisions share an *exact* position when all of these are the same: the board (health, jam state, items, cash, round, saw, and the live and blank counts shown at the load), the deciding player's whole log since the load, the legal moves, and the instructions. Players are named relative to the decider, never by letter. A looser *belief* position replaces the log with the public and private shell beliefs, plus how many clue items each opponent used this load.

**Counted.** Completed (scored) matches only, and only the agents' own moves. Forced grabs and the two fallback moves are not counted. Models are `entrants.model` plus effort. Code versions are pooled. A cohort is one kind of comparison, pooled across every tournament that played it: Cross-model (every match between different models, at every effort) or one model's efforts (every match of that model against itself). It is derived from the match's players, the same rule as the viewer's cohorts. Cohorts are never split by tournament. The same model and effort appear as separate rows in different cohorts.

**Intervals.** Every rate is numerator/denominator with a 95% percentile interval from 2,000 resamples of seed blocks (`matches.seed_block_id`) within the row, never of single matches or moves. The resampler is seeded, so a rerun prints the same intervals. For consistency and agreement, the interval is over pairs of distinct decisions: a pair weighs the product of its two blocks' resample counts, and a decision never pairs with its own copy. Without that, a block drawn twice would agree with itself. The non-modal share has no interval for that reason.

**Checks.**
- On all 130,000 non-forced decisions of the 2,596 replay-validated matches of the 2026-10-30 snapshot (`--verify`, 29 minutes), the true gun was one of the orders the player's log allows (0 outside), and every chamber the log called certain was right (0 wrong). The true gun was read only for this check and is not stored. Earlier builds were verified the same way on their own scope.
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
- The effort cohorts pair each level with every other level of the same model, so their opponents differ from the Cross-model games. Cross-model has few matches at efforts other than medium, so those rows are small, and Opus xhigh there played only Astra.
- Partial and skipped matches are left out, as are forced grabs and fallback moves.

## Reproduce

From `web/`, after `bun run rules` (Bend comes from `$BEND`, `bend` on PATH or the pinned build):

    nice -n 10 bun scripts/arena-knowledge.ts --db <buckshot.sqlite> --out <derived>/knowledge.sqlite --verify   # about 30 minutes for 2,596 matches
    nice -n 10 bun scripts/arena-knowledge-report.ts --db <derived>/knowledge.sqlite                            # about 3 minutes
    bun scripts/arena-knowledge.ts --db <buckshot.sqlite> --trace <match name>                                 # one match, decision by decision

The knowledge script always rebuilds its whole output (it drops its tables first), about 34 minutes for 2,596 matches without `--verify`. The 2026-10-30 rebuild reproduced every decision, clue, item, death and player row of the 2026-10-25 database exactly and added the 62 new matches (3,182 agent decisions); only the `cohort` label of every match differs, because the earlier file used older cohort names.

# Tables

Generated by `web/scripts/arena-knowledge-report.ts` from the knowledge database. A cohort is one kind of comparison, pooled over every tournament: Cross-model (every match between different models) or one model's efforts (every match of that model against itself).

## Coverage

| Cohort | Matches | Seed blocks | Agent decisions | Shots | Shots with a certain chamber | Code versions |
|---|---|---|---|---|---|---|
| Cross-model | 931 | 466 | 46264 | 22296 | 13219 | 12e2e3295899, 3c9b98f8b3f4, 51b8366684f0, 9e7d7ff22891 |
| Haiku 4.5 efforts | 200 | 100 | 10636 | 5358 | 2854 | 51b8366684f0, 9e7d7ff22891 |
| Haiku 5.5 efforts | 300 | 150 | 15078 | 7000 | 4229 | 51b8366684f0, 9e7d7ff22891 |
| Luna efforts | 300 | 150 | 17231 | 7600 | 4441 | 9e7d7ff22891 |
| Opus efforts | 88 | 44 | 4245 | 2021 | 1236 | 12e2e3295899, 9e7d7ff22891 |
| Sol efforts | 200 | 100 | 9726 | 4690 | 2830 | 9e7d7ff22891 |
| Sonnet efforts | 300 | 150 | 14710 | 7060 | 4383 | 51b8366684f0, 9e7d7ff22891 |
| Terra 6.1 efforts | 14 | 7 | 712 | 359 | 227 | 12e2e3295899 |
| Terra efforts | 200 | 100 | 9730 | 4858 | 2886 | 9e7d7ff22891 |

## Shots with a certain chamber

Shooting the opponent on a known blank and yourself on a known live. Certainty is the player's own: the public log, its own clues, or both. In the replays a blank shot at yourself always kept the move, also across a reload, and a blank shot at the opponent always passed it, so the blank columns split the gun's last shell from the rest.

### Cross-model

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-haiku-4-5-20251001 high | 42% (5/12) [0%, 81%] | 57% (4/7) [33%, 100%] | 3.4% (1/29) [0%, 10%] |
| claude-haiku-4-5-20251001 low | 6.3% (1/16) [0%, 13%] | 63% (5/8) [25%, 100%] | 8.6% (3/35) [0%, 22%] |
| claude-haiku-4-5-20251001 medium | 30% (88/289) [24%, 37%] | 62% (80/130) [53%, 71%] | 3.7% (22/589) [2.0%, 5.8%] |
| claude-haiku-4-5-20251001 minimal | 21% (4/19) [8.3%, 30%] | 86% (6/7) [63%, 100%] | 4.8% (2/42) [0%, 11%] |
| claude-haiku-4-5-20251001 off | 40% (10/25) [15%, 67%] | 86% (6/7) [63%, 100%] | 10% (3/29) [0%, 24%] |
| claude-haiku-5-5 high | 19% (4/21) [5.6%, 30%] | 82% (9/11) [57%, 100%] | 0% (0/50) [0%, 0%] |
| claude-haiku-5-5 low | 18% (4/22) [4.0%, 39%] | 75% (6/8) [62%, 100%] | 0% (0/66) [0%, 0%] |
| claude-haiku-5-5 max | 5.6% (1/18) [0%, 14%] | 50% (3/6) [17%, 83%] | 0% (0/43) [0%, 0%] |
| claude-haiku-5-5 medium | 19% (49/261) [13%, 25%] | 74% (103/139) [65%, 83%] | 0.6% (5/849) [0.1%, 1.2%] |
| claude-haiku-5-5 off | 70% (7/10) [40%, 100%] | 89% (8/9) [73%, 100%] | 0% (0/33) [0%, 0%] |
| claude-haiku-5-5 xhigh | 7.1% (1/14) [0%, 19%] | 86% (6/7) [67%, 100%] | 0% (0/44) [0%, 0%] |
| claude-opus-5-5 high | 0% (0/8) [0%, 0%] | 0% (0/6) [0%, 0%] | 0% (0/47) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/10) [0%, 0%] | 0% (0/7) [0%, 0%] | 0% (0/44) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/8) [0%, 0%] | 0% (0/4) [0%, 0%] | 0% (0/23) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/368) [0%, 0%] | 1.3% (2/153) [0%, 3.4%] | 0.1% (1/975) [0%, 0.3%] |
| claude-opus-5-5 off | 0% (0/8) [0%, 0%] | 0% (0/4) [0%, 0%] | 0% (0/22) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/82) [0%, 0%] | 0% (0/37) [0%, 0%] | 0% (0/208) [0%, 0%] |
| claude-sonnet-5-5 high | 0% (0/14) [0%, 0%] | 0% (0/7) [0%, 0%] | 0% (0/63) [0%, 0%] |
| claude-sonnet-5-5 low | 0% (0/21) [0%, 0%] | 10% (1/10) [0%, 20%] | 0% (0/63) [0%, 0%] |
| claude-sonnet-5-5 max | 0% (0/11) [0%, 0%] | 0% (0/8) [0%, 0%] | 0% (0/46) [0%, 0%] |
| claude-sonnet-5-5 medium | 0.6% (2/311) [0%, 1.7%] | 8.5% (9/106) [3.6%, 14%] | 0.6% (6/941) [0.2%, 1.2%] |
| claude-sonnet-5-5 off | 0% (0/14) [0%, 0%] | 38% (3/8) [0%, 60%] | 2.8% (2/71) [0%, 8.8%] |
| claude-sonnet-5-5 xhigh | 0% (0/12) [0%, 0%] | 0% (0/7) [0%, 0%] | 0% (0/63) [0%, 0%] |
| gpt-5.6-terra high | 0% (0/26) [0%, 0%] | 8.3% (1/12) [0%, 15%] | 4.9% (2/41) [0%, 10%] |
| gpt-5.6-terra low | 0% (0/20) [0%, 0%] | 17% (2/12) [0%, 50%] | 2.3% (1/44) [0%, 10%] |
| gpt-5.6-terra max | 0% (0/21) [0%, 0%] | 7.1% (1/14) [0%, 19%] | 0% (0/50) [0%, 0%] |
| gpt-5.6-terra medium | 5.2% (17/324) [3.0%, 7.8%] | 12% (22/184) [7.1%, 18%] | 0.9% (7/742) [0.3%, 1.7%] |
| gpt-5.6-terra xhigh | 0% (0/28) [0%, 0%] | 0% (0/11) [0%, 0%] | 0% (0/47) [0%, 0%] |
| gpt-6-astra high | 0% (0/13) [0%, 0%] | 0% (0/7) [0%, 0%] | 0% (0/28) [0%, 0%] |
| gpt-6-astra low | 0% (0/6) [0%, 0%] | 33% (2/6) [0%, 86%] | 0% (0/25) [0%, 0%] |
| gpt-6-astra medium | 0.6% (2/339) [0%, 1.5%] | 1.6% (3/192) [0%, 3.6%] | 0% (0/1023) [0%, 0%] |
| gpt-6-luna high | 7.4% (2/27) [0%, 14%] | 40% (2/5) [0%, 100%] | 5.6% (3/54) [1.7%, 9.4%] |
| gpt-6-luna low | 12% (2/17) [0%, 24%] | 56% (5/9) [29%, 80%] | 24% (7/29) [9.5%, 50%] |
| gpt-6-luna max | 8.7% (2/23) [0%, 20%] | 14% (1/7) [0%, 43%] | 2.3% (1/43) [0%, 6.3%] |
| gpt-6-luna medium | 26% (89/345) [21%, 31%] | 51% (85/166) [44%, 59%] | 14% (96/684) [11%, 17%] |
| gpt-6-luna off | 33% (6/18) [0%, 60%] | 78% (7/9) [60%, 100%] | 24% (9/37) [20%, 29%] |
| gpt-6-luna xhigh | 0% (0/17) [0%, 0%] | 25% (4/16) [0%, 71%] | 5.8% (3/52) [2.1%, 8.8%] |
| gpt-6.1-sol high | 0% (0/14) [0%, 0%] | 14% (1/7) [0%, 50%] | 0% (0/45) [0%, 0%] |
| gpt-6.1-sol low | 5.9% (1/17) [0%, 23%] | 20% (1/5) [0%, 50%] | 0% (0/44) [0%, 0%] |
| gpt-6.1-sol max | 4.8% (1/21) [0%, 20%] | 0% (0/15) [0%, 0%] | 0% (0/61) [0%, 0%] |
| gpt-6.1-sol medium | 0.9% (3/326) [0%, 2.1%] | 5.1% (7/138) [1.4%, 9.8%] | 0% (0/887) [0%, 0%] |
| gpt-6.1-sol xhigh | 0% (0/19) [0%, 0%] | 0% (0/16) [0%, 0%] | 0% (0/61) [0%, 0%] |
| gpt-6.1-terra high | 0% (0/7) [0%, 0%] | 0% (0/2) [0%, 0%] | 0% (0/17) [0%, 0%] |
| gpt-6.1-terra low | 0% (0/3) [0%, 0%] | 0% (0/1) [0%, 0%] | 0% (0/11) [0%, 0%] |
| gpt-6.1-terra max | 0% (0/4) [0%, 0%] | 0% (0/6) [0%, 0%] | 0% (0/13) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/9) [0%, 0%] | 0% (0/2) [0%, 0%] | 0% (0/22) [0%, 0%] |
| gpt-6.1-terra off | 0% (0/5) [0%, 0%] | 0% (0/1) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-6.1-terra xhigh | 0% (0/5) [0%, 0%] | – | 0% (0/11) [0%, 0%] |

### Haiku 4.5 efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-haiku-4-5-20251001 high | 38% (42/112) [30%, 46%] | 77% (70/91) [70%, 84%] | 3.8% (13/345) [1.7%, 6.3%] |
| claude-haiku-4-5-20251001 low | 38% (56/146) [30%, 47%] | 63% (59/94) [52%, 74%] | 3.6% (12/331) [2.0%, 5.4%] |
| claude-haiku-4-5-20251001 medium | 33% (49/148) [24%, 42%] | 68% (64/94) [57%, 80%] | 2.8% (10/356) [1.2%, 4.9%] |
| claude-haiku-4-5-20251001 minimal | 42% (70/165) [31%, 54%] | 65% (58/89) [55%, 74%] | 5.8% (18/312) [3.2%, 8.6%] |
| claude-haiku-4-5-20251001 off | 47% (83/177) [38%, 57%] | 73% (69/94) [65%, 81%] | 7.0% (21/300) [3.8%, 11%] |

### Haiku 5.5 efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-haiku-5-5 high | 16% (23/147) [9.6%, 22%] | 77% (65/84) [64%, 89%] | 0.6% (3/478) [0%, 1.4%] |
| claude-haiku-5-5 low | 31% (47/153) [23%, 38%] | 84% (76/91) [74%, 92%] | 0.9% (4/439) [0.2%, 1.9%] |
| claude-haiku-5-5 max | 6.5% (12/186) [3.1%, 11%] | 29% (25/85) [20%, 41%] | 0% (0/510) [0%, 0%] |
| claude-haiku-5-5 medium | 23% (36/160) [15%, 30%] | 85% (73/86) [79%, 91%] | 1.1% (5/462) [0.2%, 2.1%] |
| claude-haiku-5-5 off | 56% (81/144) [47%, 65%] | 84% (72/86) [76%, 90%] | 0% (0/351) [0%, 0%] |
| claude-haiku-5-5 xhigh | 8.2% (14/170) [4.2%, 13%] | 70% (57/82) [56%, 82%] | 0% (0/515) [0%, 0%] |

### Luna efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| gpt-6-luna high | 14% (28/196) [9.1%, 19%] | 31% (41/133) [22%, 40%] | 5.6% (26/464) [3.9%, 7.4%] |
| gpt-6-luna low | 39% (81/206) [31%, 47%] | 70% (81/116) [62%, 78%] | 23% (80/345) [17%, 29%] |
| gpt-6-luna max | 9.9% (21/212) [6.2%, 14%] | 29% (37/127) [21%, 38%] | 3.7% (18/493) [2.0%, 5.5%] |
| gpt-6-luna medium | 23% (46/197) [18%, 29%] | 52% (71/136) [43%, 62%] | 14% (57/401) [11%, 18%] |
| gpt-6-luna off | 40% (75/189) [33%, 46%] | 73% (76/104) [64%, 81%] | 20% (71/349) [16%, 24%] |
| gpt-6-luna xhigh | 11% (20/183) [7.1%, 15%] | 36% (38/106) [24%, 48%] | 3.9% (19/484) [2.3%, 5.7%] |

### Opus efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-opus-5-5 high | 0% (0/73) [0%, 0%] | 0% (0/35) [0%, 0%] | 0% (0/172) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/44) [0%, 0%] | 5.6% (1/18) [0%, 15%] | 0% (0/111) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/7) [0%, 0%] | 0% (0/3) [0%, 0%] | 0% (0/26) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/115) [0%, 0%] | 0% (0/42) [0%, 0%] | 0% (0/288) [0%, 0%] |
| claude-opus-5-5 off | 0% (0/3) [0%, 0%] | – | 0% (0/13) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/69) [0%, 0%] | 0% (0/34) [0%, 0%] | 0% (0/183) [0%, 0%] |

### Sol efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| gpt-6.1-sol high | 3.0% (4/133) [0.6%, 6.3%] | 2.8% (2/71) [0%, 7.2%] | 0% (0/363) [0%, 0%] |
| gpt-6.1-sol low | 0% (0/130) [0%, 0%] | 8.1% (5/62) [1.6%, 17%] | 0% (0/346) [0%, 0%] |
| gpt-6.1-sol max | 0.8% (1/129) [0%, 2.6%] | 0% (0/103) [0%, 0%] | 0% (0/363) [0%, 0%] |
| gpt-6.1-sol medium | 0% (0/135) [0%, 0%] | 5.6% (4/72) [1.3%, 11%] | 0% (0/359) [0%, 0%] |
| gpt-6.1-sol xhigh | 2.2% (3/134) [0%, 5.4%] | 1.2% (1/84) [0%, 4.0%] | 0% (0/346) [0%, 0%] |

### Sonnet efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-sonnet-5-5 high | 0% (0/173) [0%, 0%] | 1.2% (1/86) [0%, 4.0%] | 0.4% (2/462) [0%, 1.1%] |
| claude-sonnet-5-5 low | 0.6% (1/162) [0%, 2.0%] | 9.1% (8/88) [3.0%, 18%] | 0.4% (2/470) [0%, 1.1%] |
| claude-sonnet-5-5 max | 0.5% (1/197) [0%, 1.7%] | 0% (0/105) [0%, 0%] | 0% (0/483) [0%, 0%] |
| claude-sonnet-5-5 medium | 0.6% (1/163) [0%, 2.0%] | 9.5% (6/63) [2.6%, 19%] | 0.2% (1/495) [0%, 0.6%] |
| claude-sonnet-5-5 off | 1.3% (2/153) [0%, 3.6%] | 14% (8/58) [5.7%, 25%] | 0.8% (4/502) [0.2%, 1.6%] |
| claude-sonnet-5-5 xhigh | 0.5% (1/186) [0%, 1.8%] | 2.7% (2/74) [0%, 6.8%] | 0% (0/463) [0%, 0%] |

### Terra 6.1 efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| gpt-6.1-terra high | 0% (0/8) [0%, 0%] | – | 0% (0/15) [0%, 0%] |
| gpt-6.1-terra low | 0% (0/14) [0%, 0%] | 0% (0/4) [0%, 0%] | 0% (0/27) [0%, 0%] |
| gpt-6.1-terra max | 0% (0/5) [0%, 0%] | 0% (0/5) [0%, 0%] | 0% (0/13) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/17) [0%, 0%] | 0% (0/7) [0%, 0%] | 0% (0/44) [0%, 0%] |
| gpt-6.1-terra off | 0% (0/7) [0%, 0%] | 0% (0/4) [0%, 0%] | 0% (0/17) [0%, 0%] |
| gpt-6.1-terra xhigh | 0% (0/10) [0%, 0%] | 0% (0/2) [0%, 0%] | 0% (0/28) [0%, 0%] |

### Terra efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| gpt-5.6-terra high | 4.7% (7/150) [1.3%, 9.2%] | 14% (12/87) [7.5%, 23%] | 2.7% (9/336) [1.2%, 4.3%] |
| gpt-5.6-terra low | 7.0% (9/128) [2.3%, 12%] | 18% (16/89) [9.5%, 28%] | 2.7% (9/336) [1.1%, 4.7%] |
| gpt-5.6-terra max | 1.8% (3/171) [0%, 3.8%] | 3.7% (4/108) [0.8%, 7.1%] | 0.3% (1/358) [0%, 0.9%] |
| gpt-5.6-terra medium | 9.8% (13/132) [5.0%, 16%] | 12% (8/67) [5.5%, 20%] | 1.5% (5/326) [0.3%, 2.9%] |
| gpt-5.6-terra xhigh | 3.6% (6/165) [0.8%, 7.0%] | 9.6% (8/83) [4.1%, 17%] | 1.1% (4/350) [0.3%, 2.4%] |

## By where the certainty came from

Shots against the known shell, by source. A clue taken with adrenaline counts with its item.

| Cohort | public | glass | phone | combined |
|---|---|---|---|---|
| Cross-model | 9.0% (689/7618) [8.1%, 10%] | 1.6% (68/4162) [1.2%, 2.1%] | 8.0% (112/1405) [6.4%, 9.7%] | 2.9% (1/34) [0%, 8.6%] |
| Haiku 4.5 efforts | 29% (513/1770) [27%, 32%] | 12% (102/886) [9.0%, 14%] | 40% (79/196) [33%, 47%] | 0% (0/2) [0%, 0%] |
| Haiku 5.5 efforts | 20% (479/2360) [18%, 22%] | 4.0% (54/1340) [2.8%, 5.3%] | 11% (59/518) [7.9%, 15%] | 9.1% (1/11) [0%, 25%] |
| Luna efforts | 27% (705/2638) [24%, 29%] | 2.9% (39/1350) [1.9%, 3.9%] | 32% (141/442) [28%, 36%] | 9.1% (1/11) [0%, 20%] |
| Opus efforts | 0.2% (1/649) [0%, 0.5%] | 0% (0/403) [0%, 0%] | 0% (0/182) [0%, 0%] | 0% (0/2) [0%, 0%] |
| Sol efforts | 1.3% (20/1493) [0.8%, 2.0%] | 0% (0/885) [0%, 0%] | 0% (0/446) [0%, 0%] | 0% (0/6) [0%, 0%] |
| Sonnet efforts | 1.4% (33/2341) [0.9%, 2.1%] | 0% (0/1441) [0%, 0%] | 1.2% (7/586) [0.4%, 2.1%] | 0% (0/15) [0%, 0%] |
| Terra 6.1 efforts | 0% (0/120) [0%, 0%] | 0% (0/73) [0%, 0%] | 0% (0/33) [0%, 0%] | 0% (0/1) [0%, 0%] |
| Terra efforts | 5.4% (90/1677) [4.2%, 6.6%] | 0.1% (1/937) [0%, 0.3%] | 8.6% (23/267) [5.4%, 13%] | 0% (0/5) [0%, 0%] |

### Cross-model, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-haiku-4-5-20251001 high | 13% (2/16) [0%, 33%] | 67% (2/3) [0%, 100%] |
| claude-haiku-4-5-20251001 low | 6.7% (1/15) [0%, 14%] | 0% (0/5) [0%, 0%] |
| claude-haiku-4-5-20251001 medium | 11% (36/338) [7.3%, 14%] | 29% (20/70) [17%, 39%] |
| claude-haiku-4-5-20251001 minimal | 4.0% (1/25) [0%, 10%] | 40% (2/5) [0%, 100%] |
| claude-haiku-4-5-20251001 off | 18% (4/22) [3.8%, 43%] | 33% (2/6) [0%, 100%] |
| claude-haiku-5-5 high | 5.6% (1/18) [0%, 17%] | 0% (0/14) [0%, 0%] |
| claude-haiku-5-5 low | 0% (0/23) [0%, 0%] | 13% (2/15) [0%, 33%] |
| claude-haiku-5-5 max | 0% (0/18) [0%, 0%] | 0% (0/9) [0%, 0%] |
| claude-haiku-5-5 medium | 4.3% (15/352) [2.3%, 6.3%] | 4.9% (7/143) [1.5%, 8.8%] |
| claude-haiku-5-5 off | 0% (0/15) [0%, 0%] | 67% (2/3) [0%, 100%] |
| claude-haiku-5-5 xhigh | 0% (0/18) [0%, 0%] | 0% (0/7) [0%, 0%] |
| claude-opus-5-5 high | 0% (0/20) [0%, 0%] | 0% (0/6) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/23) [0%, 0%] | 0% (0/5) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/10) [0%, 0%] | 0% (0/1) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/412) [0%, 0%] | 0.6% (1/171) [0%, 1.8%] |
| claude-opus-5-5 off | 0% (0/12) [0%, 0%] | 0% (0/4) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/87) [0%, 0%] | 0% (0/38) [0%, 0%] |
| claude-sonnet-5-5 high | 0% (0/19) [0%, 0%] | 0% (0/15) [0%, 0%] |
| claude-sonnet-5-5 low | 0% (0/25) [0%, 0%] | 0% (0/15) [0%, 0%] |
| claude-sonnet-5-5 max | 0% (0/14) [0%, 0%] | 0% (0/13) [0%, 0%] |
| claude-sonnet-5-5 medium | 0% (0/458) [0%, 0%] | 0.7% (1/144) [0%, 2.2%] |
| claude-sonnet-5-5 off | 0% (0/27) [0%, 0%] | 0% (0/6) [0%, 0%] |
| claude-sonnet-5-5 xhigh | 0% (0/23) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-5.6-terra high | 0% (0/27) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-5.6-terra low | 0% (0/28) [0%, 0%] | 0% (0/4) [0%, 0%] |
| gpt-5.6-terra max | 0% (0/28) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-5.6-terra medium | 0% (0/464) [0%, 0%] | 15% (15/103) [7.8%, 22%] |
| gpt-5.6-terra xhigh | 0% (0/27) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-6-astra high | 0% (0/14) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-6-astra low | 0% (0/12) [0%, 0%] | 0% (0/1) [0%, 0%] |
| gpt-6-astra medium | 0% (0/497) [0%, 0%] | 0% (0/181) [0%, 0%] |
| gpt-6-luna high | 0% (0/25) [0%, 0%] | 7.7% (1/13) [0%, 30%] |
| gpt-6-luna low | 0% (0/23) [0%, 0%] | 67% (2/3) [0%, 100%] |
| gpt-6-luna max | 0% (0/20) [0%, 0%] | 7.7% (1/13) [0%, 23%] |
| gpt-6-luna medium | 1.9% (8/412) [0.7%, 3.4%] | 40% (51/127) [33%, 47%] |
| gpt-6-luna off | 0% (0/20) [0%, 0%] | 25% (1/4) [0%, 100%] |
| gpt-6-luna xhigh | 0% (0/25) [0%, 0%] | 0% (0/3) [0%, 0%] |
| gpt-6.1-sol high | 0% (0/21) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-6.1-sol low | 0% (0/24) [0%, 0%] | 13% (1/8) [0%, 33%] |
| gpt-6.1-sol max | 0% (0/28) [0%, 0%] | 0% (0/11) [0%, 0%] |
| gpt-6.1-sol medium | 0% (0/410) [0%, 0%] | 0.6% (1/162) [0%, 2.1%] |
| gpt-6.1-sol xhigh | 0% (0/24) [0%, 0%] | 0% (0/13) [0%, 0%] |
| gpt-6.1-terra high | 0% (0/5) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-6.1-terra low | 0% (0/5) [0%, 0%] | 0% (0/1) [0%, 0%] |
| gpt-6.1-terra max | 0% (0/8) [0%, 0%] | 0% (0/2) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/12) [0%, 0%] | 0% (0/4) [0%, 0%] |
| gpt-6.1-terra off | 0% (0/6) [0%, 0%] | 0% (0/2) [0%, 0%] |
| gpt-6.1-terra xhigh | 0% (0/7) [0%, 0%] | 0% (0/2) [0%, 0%] |

### Haiku 4.5 efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-haiku-4-5-20251001 high | 8.2% (14/170) [4.3%, 13%] | 30% (10/33) [14%, 48%] |
| claude-haiku-4-5-20251001 low | 9.7% (16/165) [5.3%, 15%] | 42% (19/45) [26%, 59%] |
| claude-haiku-4-5-20251001 medium | 6.4% (12/187) [2.9%, 11%] | 40% (10/25) [22%, 59%] |
| claude-haiku-4-5-20251001 minimal | 16% (28/175) [8.7%, 24%] | 44% (17/39) [32%, 56%] |
| claude-haiku-4-5-20251001 off | 17% (32/189) [11%, 23%] | 43% (23/54) [30%, 58%] |

### Haiku 5.5 efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-haiku-5-5 high | 1.9% (4/208) [0%, 4.4%] | 7.3% (7/96) [2.2%, 13%] |
| claude-haiku-5-5 low | 4.8% (11/228) [2.0%, 8.2%] | 17% (13/76) [8.5%, 27%] |
| claude-haiku-5-5 max | 0.4% (1/236) [0%, 1.4%] | 0% (0/108) [0%, 0%] |
| claude-haiku-5-5 medium | 5.4% (13/240) [2.7%, 8.2%] | 12% (9/73) [5.3%, 20%] |
| claude-haiku-5-5 off | 11% (23/205) [6.0%, 18%] | 47% (28/59) [33%, 61%] |
| claude-haiku-5-5 xhigh | 0.9% (2/223) [0%, 2.4%] | 1.9% (2/106) [0%, 5.0%] |

### Luna efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| gpt-6-luna high | 0.8% (2/265) [0%, 1.8%] | 27% (18/66) [17%, 38%] |
| gpt-6-luna low | 7.1% (14/197) [3.7%, 11%] | 54% (43/79) [44%, 65%] |
| gpt-6-luna max | 0.4% (1/231) [0%, 1.4%] | 12% (11/92) [6.1%, 18%] |
| gpt-6-luna medium | 2.5% (6/239) [0.4%, 4.9%] | 40% (27/67) [29%, 53%] |
| gpt-6-luna off | 8.1% (15/185) [4.5%, 12%] | 50% (33/66) [38%, 63%] |
| gpt-6-luna xhigh | 0.4% (1/233) [0%, 1.4%] | 13% (9/72) [5.5%, 20%] |

### Opus efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-opus-5-5 high | 0% (0/89) [0%, 0%] | 0% (0/41) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/63) [0%, 0%] | 0% (0/19) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/10) [0%, 0%] | 0% (0/1) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/147) [0%, 0%] | 0% (0/70) [0%, 0%] |
| claude-opus-5-5 off | 0% (0/5) [0%, 0%] | 0% (0/1) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/89) [0%, 0%] | 0% (0/50) [0%, 0%] |

### Sol efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| gpt-6.1-sol high | 0% (0/177) [0%, 0%] | 0% (0/96) [0%, 0%] |
| gpt-6.1-sol low | 0% (0/191) [0%, 0%] | 0% (0/73) [0%, 0%] |
| gpt-6.1-sol max | 0% (0/174) [0%, 0%] | 0% (0/92) [0%, 0%] |
| gpt-6.1-sol medium | 0% (0/172) [0%, 0%] | 0% (0/91) [0%, 0%] |
| gpt-6.1-sol xhigh | 0% (0/171) [0%, 0%] | 0% (0/94) [0%, 0%] |

### Sonnet efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-sonnet-5-5 high | 0% (0/231) [0%, 0%] | 0.9% (1/109) [0%, 3.2%] |
| claude-sonnet-5-5 low | 0% (0/252) [0%, 0%] | 1.3% (1/78) [0%, 4.2%] |
| claude-sonnet-5-5 max | 0% (0/248) [0%, 0%] | 1.0% (1/96) [0%, 3.4%] |
| claude-sonnet-5-5 medium | 0% (0/253) [0%, 0%] | 0% (0/89) [0%, 0%] |
| claude-sonnet-5-5 off | 0% (0/250) [0%, 0%] | 3.0% (3/99) [0%, 6.5%] |
| claude-sonnet-5-5 xhigh | 0% (0/207) [0%, 0%] | 0.9% (1/115) [0%, 2.8%] |

### Terra 6.1 efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| gpt-6.1-terra high | 0% (0/8) [0%, 0%] | 0% (0/5) [0%, 0%] |
| gpt-6.1-terra low | 0% (0/19) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-6.1-terra max | 0% (0/5) [0%, 0%] | 0% (0/1) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/22) [0%, 0%] | 0% (0/10) [0%, 0%] |
| gpt-6.1-terra off | 0% (0/9) [0%, 0%] | 0% (0/5) [0%, 0%] |
| gpt-6.1-terra xhigh | 0% (0/10) [0%, 0%] | 0% (0/6) [0%, 0%] |

### Terra efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| gpt-5.6-terra high | 0% (0/179) [0%, 0%] | 11% (5/47) [2.3%, 20%] |
| gpt-5.6-terra low | 0% (0/196) [0%, 0%] | 18% (5/28) [6.7%, 31%] |
| gpt-5.6-terra max | 0% (0/190) [0%, 0%] | 2.3% (2/86) [0%, 6.2%] |
| gpt-5.6-terra medium | 0% (0/184) [0%, 0%] | 19% (7/37) [8.6%, 30%] |
| gpt-5.6-terra xhigh | 0.5% (1/188) [0%, 1.8%] | 5.8% (4/69) [0%, 14%] |

## By accepted moves since the clue

Shots against a chamber known from a clue (glass or phone), by the accepted moves of either player between the clue and the shot. 0 is the very next move.

### glass

| Cohort | 0 | 1 | 2–3 | 4+ |
|---|---|---|---|---|
| Cross-model | 1.2% (31/2508) [0.8%, 1.7%] | 2.1% (28/1350) [1.3%, 2.9%] | 3.0% (9/302) [1.3%, 5.1%] | 0% (0/2) [0%, 0%] |
| Haiku 4.5 efforts | 11% (55/518) [7.4%, 14%] | 11% (35/327) [7.4%, 14%] | 30% (12/40) [15%, 47%] | 0% (0/1) [0%, 0%] |
| Haiku 5.5 efforts | 2.7% (15/561) [1.3%, 4.1%] | 4.4% (25/562) [2.5%, 6.6%] | 6.0% (13/215) [3.3%, 9.4%] | 50% (1/2) [0%, 100%] |
| Luna efforts | 0.5% (4/786) [0.1%, 1.0%] | 5.1% (23/449) [3.2%, 7.4%] | 11% (12/112) [5.1%, 17%] | 0% (0/3) [0%, 0%] |
| Opus efforts | 0% (0/212) [0%, 0%] | 0% (0/143) [0%, 0%] | 0% (0/48) [0%, 0%] | – |
| Sol efforts | 0% (0/563) [0%, 0%] | 0% (0/232) [0%, 0%] | 0% (0/90) [0%, 0%] | – |
| Sonnet efforts | 0% (0/709) [0%, 0%] | 0% (0/491) [0%, 0%] | 0% (0/236) [0%, 0%] | 0% (0/5) [0%, 0%] |
| Terra 6.1 efforts | 0% (0/47) [0%, 0%] | 0% (0/18) [0%, 0%] | 0% (0/8) [0%, 0%] | – |
| Terra efforts | 0% (0/575) [0%, 0%] | 0.3% (1/300) [0%, 1.0%] | 0% (0/61) [0%, 0%] | 0% (0/1) [0%, 0%] |

### phone

| Cohort | 0 | 1 | 2–3 | 4+ |
|---|---|---|---|---|
| Cross-model | 5.7% (13/227) [2.8%, 9.0%] | 7.4% (24/323) [4.7%, 11%] | 5.9% (29/488) [3.9%, 8.4%] | 13% (46/367) [9.0%, 16%] |
| Haiku 4.5 efforts | 39% (16/41) [26%, 53%] | 38% (14/37) [23%, 56%] | 48% (29/60) [38%, 59%] | 34% (20/58) [25%, 44%] |
| Haiku 5.5 efforts | 9.5% (7/74) [3.5%, 17%] | 5.6% (6/108) [1.8%, 9.9%] | 13% (28/210) [8.8%, 18%] | 14% (18/126) [8.5%, 21%] |
| Luna efforts | 29% (24/84) [20%, 38%] | 30% (29/98) [22%, 38%] | 32% (47/149) [24%, 39%] | 37% (41/111) [28%, 46%] |
| Opus efforts | 0% (0/37) [0%, 0%] | 0% (0/48) [0%, 0%] | 0% (0/70) [0%, 0%] | 0% (0/27) [0%, 0%] |
| Sol efforts | 0% (0/77) [0%, 0%] | 0% (0/102) [0%, 0%] | 0% (0/148) [0%, 0%] | 0% (0/119) [0%, 0%] |
| Sonnet efforts | 0% (0/108) [0%, 0%] | 0.7% (1/134) [0%, 2.3%] | 1.3% (3/223) [0%, 3.0%] | 2.5% (3/121) [0%, 5.6%] |
| Terra 6.1 efforts | 0% (0/4) [0%, 0%] | 0% (0/4) [0%, 0%] | 0% (0/15) [0%, 0%] | 0% (0/10) [0%, 0%] |
| Terra efforts | 3.3% (2/60) [0%, 8.5%] | 8.3% (6/72) [2.7%, 15%] | 10% (9/86) [4.4%, 17%] | 12% (6/49) [2.6%, 22%] |

## How shots are informed

Each agent shot by what the player knew of the chamber: a clue from its own item (glass, phone or both), the public count, or nothing. The last column is blind shots taken while the player held a magnifying glass.

### Cross-model

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 18% (19/105) [13%, 23%] | 28% (29/105) [19%, 37%] | 54% (57/105) [50%, 59%] | 7.0% (4/57) [0%, 13%] |
| claude-haiku-4-5-20251001 low | 17% (20/119) [11%, 22%] | 33% (39/119) [25%, 41%] | 50% (60/119) [45%, 57%] | 1.7% (1/60) [0%, 4.8%] |
| claude-haiku-4-5-20251001 medium | 20% (408/2023) [18%, 22%] | 30% (600/2023) [28%, 32%] | 50% (1015/2023) [48%, 52%] | 3.2% (32/1015) [1.8%, 4.7%] |
| claude-haiku-4-5-20251001 minimal | 24% (30/127) [14%, 31%] | 30% (38/127) [19%, 38%] | 46% (59/127) [41%, 53%] | 3.4% (2/59) [0%, 9.5%] |
| claude-haiku-4-5-20251001 off | 25% (28/114) [15%, 33%] | 29% (33/114) [24%, 34%] | 46% (53/114) [39%, 55%] | 3.8% (2/53) [0%, 8.7%] |
| claude-haiku-5-5 high | 25% (32/126) [21%, 30%] | 40% (50/126) [33%, 47%] | 35% (44/126) [28%, 41%] | 0% (0/44) [0%, 0%] |
| claude-haiku-5-5 low | 27% (38/143) [21%, 32%] | 41% (58/143) [34%, 47%] | 33% (47/143) [30%, 36%] | 0% (0/47) [0%, 0%] |
| claude-haiku-5-5 max | 26% (27/105) [19%, 33%] | 38% (40/105) [30%, 47%] | 36% (38/105) [31%, 41%] | 0% (0/38) [0%, 0%] |
| claude-haiku-5-5 medium | 25% (503/2012) [23%, 27%] | 37% (746/2012) [35%, 39%] | 38% (763/2012) [36%, 40%] | 0.7% (5/763) [0.1%, 1.4%] |
| claude-haiku-5-5 off | 19% (18/95) [13%, 27%] | 36% (34/95) [23%, 47%] | 45% (43/95) [36%, 54%] | 0% (0/43) [0%, 0%] |
| claude-haiku-5-5 xhigh | 27% (27/100) [18%, 35%] | 38% (38/100) [29%, 47%] | 35% (35/100) [25%, 45%] | 0% (0/35) [0%, 0%] |
| claude-opus-5-5 high | 25% (26/105) [18%, 30%] | 33% (35/105) [25%, 43%] | 42% (44/105) [34%, 48%] | 0% (0/44) [0%, 0%] |
| claude-opus-5-5 low | 27% (28/104) [24%, 29%] | 32% (33/104) [29%, 35%] | 41% (43/104) [38%, 44%] | 0% (0/43) [0%, 0%] |
| claude-opus-5-5 max | 22% (11/49) [22%, 23%] | 49% (24/49) [44%, 52%] | 29% (14/49) [26%, 33%] | 0% (0/14) [0%, 0%] |
| claude-opus-5-5 medium | 26% (590/2310) [24%, 28%] | 39% (906/2310) [37%, 41%] | 35% (814/2310) [33%, 37%] | 0.1% (1/814) [0%, 0.4%] |
| claude-opus-5-5 off | 36% (17/47) [31%, 44%] | 36% (17/47) [34%, 39%] | 28% (13/47) [17%, 34%] | 0% (0/13) [0%, 0%] |
| claude-opus-5-5 xhigh | 25% (126/508) [20%, 29%] | 40% (201/508) [36%, 44%] | 36% (181/508) [31%, 41%] | 0% (0/181) [0%, 0%] |
| claude-sonnet-5-5 high | 26% (34/130) [18%, 35%] | 38% (50/130) [33%, 43%] | 35% (46/130) [29%, 42%] | 0% (0/46) [0%, 0%] |
| claude-sonnet-5-5 low | 24% (40/166) [18%, 30%] | 33% (54/166) [28%, 38%] | 43% (72/166) [37%, 49%] | 0% (0/72) [0%, 0%] |
| claude-sonnet-5-5 max | 25% (27/107) [11%, 40%] | 36% (38/107) [28%, 43%] | 39% (42/107) [33%, 48%] | 4.8% (2/42) [0%, 12%] |
| claude-sonnet-5-5 medium | 27% (602/2199) [25%, 29%] | 34% (756/2199) [32%, 36%] | 38% (841/2199) [36%, 40%] | 0.2% (2/841) [0%, 0.6%] |
| claude-sonnet-5-5 off | 23% (33/142) [18%, 30%] | 42% (60/142) [38%, 46%] | 35% (49/142) [28%, 40%] | 0% (0/49) [0%, 0%] |
| claude-sonnet-5-5 xhigh | 22% (29/130) [17%, 27%] | 41% (53/130) [31%, 48%] | 37% (48/130) [26%, 48%] | 0% (0/48) [0%, 0%] |
| gpt-5.6-terra high | 26% (35/134) [20%, 33%] | 33% (44/134) [29%, 37%] | 41% (55/134) [38%, 44%] | 0% (0/55) [0%, 0%] |
| gpt-5.6-terra low | 25% (32/129) [19%, 31%] | 34% (44/129) [29%, 38%] | 41% (53/129) [32%, 50%] | 0% (0/53) [0%, 0%] |
| gpt-5.6-terra max | 23% (34/149) [20%, 26%] | 34% (51/149) [26%, 42%] | 43% (64/149) [36%, 50%] | 0% (0/64) [0%, 0%] |
| gpt-5.6-terra medium | 26% (569/2171) [24%, 28%] | 31% (681/2171) [29%, 33%] | 42% (921/2171) [40%, 45%] | 0.3% (3/921) [0%, 0.7%] |
| gpt-5.6-terra xhigh | 25% (35/142) [17%, 31%] | 36% (51/142) [24%, 47%] | 39% (56/142) [32%, 48%] | 0% (0/56) [0%, 0%] |
| gpt-6-astra high | 34% (22/64) [27%, 42%] | 41% (26/64) [35%, 45%] | 25% (16/64) [23%, 27%] | 0% (0/16) [0%, 0%] |
| gpt-6-astra low | 19% (13/69) [12%, 29%] | 35% (24/69) [26%, 44%] | 46% (32/69) [43%, 53%] | 0% (0/32) [0%, 0%] |
| gpt-6-astra medium | 26% (681/2593) [25%, 28%] | 34% (873/2593) [32%, 35%] | 40% (1039/2593) [38%, 42%] | 0% (0/1039) [0%, 0%] |
| gpt-6-luna high | 30% (38/126) [22%, 38%] | 38% (48/126) [32%, 46%] | 32% (40/126) [29%, 33%] | 2.5% (1/40) [0%, 7.1%] |
| gpt-6-luna low | 23% (26/115) [15%, 27%] | 25% (29/115) [17%, 32%] | 52% (60/115) [42%, 66%] | 0% (0/60) [0%, 0%] |
| gpt-6-luna max | 28% (34/121) [22%, 35%] | 32% (39/121) [23%, 39%] | 40% (48/121) [31%, 51%] | 0% (0/48) [0%, 0%] |
| gpt-6-luna medium | 25% (540/2134) [24%, 27%] | 31% (655/2134) [29%, 33%] | 44% (939/2134) [42%, 46%] | 0.7% (7/939) [0.1%, 1.6%] |
| gpt-6-luna off | 21% (24/116) [18%, 23%] | 34% (40/116) [29%, 41%] | 45% (52/116) [39%, 50%] | 1.9% (1/52) [0%, 5.9%] |
| gpt-6-luna xhigh | 18% (28/160) [13%, 22%] | 36% (57/160) [29%, 41%] | 47% (75/160) [41%, 52%] | 0% (0/75) [0%, 0%] |
| gpt-6.1-sol high | 25% (29/114) [16%, 33%] | 32% (37/114) [25%, 38%] | 42% (48/114) [36%, 47%] | 0% (0/48) [0%, 0%] |
| gpt-6.1-sol low | 28% (32/113) [23%, 34%] | 30% (34/113) [24%, 38%] | 42% (47/113) [33%, 50%] | 0% (0/47) [0%, 0%] |
| gpt-6.1-sol max | 26% (39/150) [18%, 33%] | 39% (58/150) [33%, 42%] | 35% (53/150) [27%, 44%] | 0% (0/53) [0%, 0%] |
| gpt-6.1-sol medium | 25% (573/2256) [24%, 27%] | 34% (778/2256) [33%, 36%] | 40% (905/2256) [38%, 42%] | 0.1% (1/905) [0%, 0.3%] |
| gpt-6.1-sol xhigh | 23% (39/168) [19%, 28%] | 34% (57/168) [30%, 38%] | 43% (72/168) [39%, 47%] | 0% (0/72) [0%, 0%] |
| gpt-6.1-terra high | 32% (14/44) [31%, 33%] | 27% (12/44) [17%, 35%] | 41% (18/44) [35%, 50%] | 0% (0/18) [0%, 0%] |
| gpt-6.1-terra low | 24% (7/29) [24%, 24%] | 28% (8/29) [28%, 28%] | 48% (14/29) [48%, 48%] | 0% (0/14) [0%, 0%] |
| gpt-6.1-terra max | 31% (10/32) [31%, 31%] | 41% (13/32) [41%, 41%] | 28% (9/32) [28%, 28%] | 0% (0/9) [0%, 0%] |
| gpt-6.1-terra medium | 31% (17/54) [25%, 38%] | 30% (16/54) [23%, 36%] | 39% (21/54) [38%, 39%] | 0% (0/21) [0%, 0%] |
| gpt-6.1-terra off | 35% (8/23) [35%, 35%] | 17% (4/23) [17%, 17%] | 48% (11/23) [48%, 48%] | 0% (0/11) [0%, 0%] |
| gpt-6.1-terra xhigh | 38% (9/24) [38%, 38%] | 29% (7/24) [29%, 29%] | 33% (8/24) [33%, 33%] | 0% (0/8) [0%, 0%] |

### Haiku 4.5 efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 19% (203/1043) [16%, 23%] | 33% (345/1043) [31%, 35%] | 47% (495/1043) [45%, 51%] | 5.9% (29/495) [3.1%, 9.1%] |
| claude-haiku-4-5-20251001 low | 19% (210/1078) [17%, 22%] | 33% (361/1078) [31%, 36%] | 47% (507/1078) [44%, 50%] | 2.6% (13/507) [1.0%, 4.2%] |
| claude-haiku-4-5-20251001 medium | 19% (212/1112) [17%, 22%] | 35% (386/1112) [32%, 38%] | 46% (514/1112) [43%, 50%] | 5.3% (27/514) [2.6%, 8.5%] |
| claude-haiku-4-5-20251001 minimal | 20% (216/1063) [18%, 23%] | 33% (350/1063) [30%, 36%] | 47% (497/1063) [44%, 50%] | 1.6% (8/497) [0.6%, 2.6%] |
| claude-haiku-4-5-20251001 off | 23% (243/1062) [20%, 26%] | 31% (328/1062) [28%, 34%] | 46% (491/1062) [43%, 49%] | 0.8% (4/491) [0%, 1.9%] |

### Haiku 5.5 efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-haiku-5-5 high | 26% (304/1181) [23%, 29%] | 34% (405/1181) [31%, 37%] | 40% (472/1181) [37%, 43%] | 0.4% (2/472) [0%, 1.1%] |
| claude-haiku-5-5 low | 26% (305/1161) [24%, 29%] | 33% (378/1161) [30%, 35%] | 41% (478/1161) [38%, 44%] | 0.4% (2/478) [0%, 1.3%] |
| claude-haiku-5-5 max | 29% (346/1210) [26%, 31%] | 36% (435/1210) [34%, 38%] | 35% (429/1210) [33%, 38%] | 2.6% (11/429) [1.2%, 4.1%] |
| claude-haiku-5-5 medium | 27% (315/1175) [24%, 30%] | 33% (393/1175) [30%, 36%] | 40% (467/1175) [36%, 44%] | 0.6% (3/467) [0%, 1.4%] |
| claude-haiku-5-5 off | 25% (267/1073) [22%, 28%] | 29% (314/1073) [26%, 33%] | 46% (492/1073) [43%, 49%] | 0% (0/492) [0%, 0%] |
| claude-haiku-5-5 xhigh | 28% (332/1200) [25%, 30%] | 36% (435/1200) [33%, 39%] | 36% (433/1200) [33%, 39%] | 0.7% (3/433) [0%, 1.6%] |

### Luna efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| gpt-6-luna high | 26% (333/1303) [23%, 28%] | 35% (460/1303) [32%, 38%] | 39% (510/1303) [36%, 42%] | 0% (0/510) [0%, 0%] |
| gpt-6-luna low | 23% (276/1221) [20%, 25%] | 32% (391/1221) [29%, 35%] | 45% (554/1221) [42%, 49%] | 0.7% (4/554) [0.2%, 1.4%] |
| gpt-6-luna max | 24% (326/1331) [22%, 27%] | 38% (506/1331) [35%, 41%] | 37% (499/1331) [34%, 41%] | 0.6% (3/499) [0%, 1.3%] |
| gpt-6-luna medium | 24% (306/1280) [21%, 27%] | 33% (428/1280) [31%, 36%] | 43% (546/1280) [40%, 45%] | 0.9% (5/546) [0%, 2.1%] |
| gpt-6-luna off | 21% (252/1197) [19%, 23%] | 33% (390/1197) [31%, 35%] | 46% (555/1197) [44%, 49%] | 0.4% (2/555) [0%, 0.9%] |
| gpt-6-luna xhigh | 24% (310/1268) [22%, 27%] | 37% (463/1268) [33%, 40%] | 39% (495/1268) [36%, 42%] | 0.6% (3/495) [0%, 1.6%] |

### Opus efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-opus-5-5 high | 28% (130/464) [23%, 33%] | 32% (150/464) [27%, 38%] | 40% (184/464) [34%, 45%] | 0% (0/184) [0%, 0%] |
| claude-opus-5-5 low | 29% (82/287) [21%, 36%] | 32% (91/287) [26%, 37%] | 40% (114/287) [33%, 47%] | 0% (0/114) [0%, 0%] |
| claude-opus-5-5 max | 21% (11/52) [14%, 29%] | 48% (25/52) [43%, 54%] | 31% (16/52) [17%, 43%] | 0% (0/16) [0%, 0%] |
| claude-opus-5-5 medium | 30% (217/726) [26%, 33%] | 31% (228/726) [28%, 35%] | 39% (281/726) [34%, 44%] | 0% (0/281) [0%, 0%] |
| claude-opus-5-5 off | 17% (6/36) [14%, 25%] | 28% (10/36) [13%, 32%] | 56% (20/36) [54%, 63%] | 0% (0/20) [0%, 0%] |
| claude-opus-5-5 xhigh | 31% (141/456) [26%, 36%] | 32% (145/456) [27%, 37%] | 37% (170/456) [33%, 42%] | 1.2% (2/170) [0%, 2.8%] |

### Sol efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| gpt-6.1-sol high | 29% (274/939) [26%, 32%] | 31% (293/939) [28%, 34%] | 40% (372/939) [36%, 43%] | 0% (0/372) [0%, 0%] |
| gpt-6.1-sol low | 28% (264/928) [26%, 31%] | 30% (274/928) [27%, 32%] | 42% (390/928) [38%, 46%] | 0% (0/390) [0%, 0%] |
| gpt-6.1-sol max | 28% (267/969) [25%, 31%] | 34% (328/969) [31%, 37%] | 39% (374/969) [35%, 42%] | 0.3% (1/374) [0%, 0.9%] |
| gpt-6.1-sol medium | 28% (264/937) [25%, 31%] | 32% (302/937) [29%, 35%] | 40% (371/937) [36%, 43%] | 0% (0/371) [0%, 0%] |
| gpt-6.1-sol xhigh | 29% (268/917) [26%, 33%] | 32% (296/917) [29%, 36%] | 38% (353/917) [35%, 42%] | 0.6% (2/353) [0%, 1.4%] |

### Sonnet efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-sonnet-5-5 high | 29% (344/1189) [27%, 32%] | 32% (377/1189) [29%, 34%] | 39% (468/1189) [36%, 43%] | 0% (0/468) [0%, 0%] |
| claude-sonnet-5-5 low | 29% (335/1175) [25%, 32%] | 33% (385/1175) [30%, 36%] | 39% (455/1175) [35%, 42%] | 0% (0/455) [0%, 0%] |
| claude-sonnet-5-5 max | 30% (344/1165) [27%, 32%] | 38% (441/1165) [35%, 41%] | 33% (380/1165) [31%, 35%] | 3.4% (13/380) [1.7%, 5.4%] |
| claude-sonnet-5-5 medium | 29% (345/1207) [26%, 32%] | 31% (376/1207) [28%, 34%] | 40% (486/1207) [37%, 43%] | 0% (0/486) [0%, 0%] |
| claude-sonnet-5-5 off | 30% (351/1182) [26%, 33%] | 31% (362/1182) [28%, 33%] | 40% (469/1182) [36%, 43%] | 0% (0/469) [0%, 0%] |
| claude-sonnet-5-5 xhigh | 28% (323/1142) [25%, 31%] | 35% (400/1142) [32%, 38%] | 37% (419/1142) [34%, 40%] | 0.5% (2/419) [0%, 1.2%] |

### Terra 6.1 efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| gpt-6.1-terra high | 27% (13/48) [21%, 33%] | 21% (10/48) [13%, 29%] | 52% (25/48) [50%, 54%] | 0% (0/25) [0%, 0%] |
| gpt-6.1-terra low | 42% (25/59) [33%, 49%] | 34% (20/59) [26%, 46%] | 24% (14/59) [21%, 26%] | 0% (0/14) [0%, 0%] |
| gpt-6.1-terra max | 17% (6/35) [17%, 17%] | 49% (17/35) [49%, 49%] | 34% (12/35) [34%, 34%] | 0% (0/12) [0%, 0%] |
| gpt-6.1-terra medium | 31% (33/105) [23%, 39%] | 33% (35/105) [27%, 39%] | 35% (37/105) [25%, 49%] | 0% (0/37) [0%, 0%] |
| gpt-6.1-terra off | 33% (14/43) [26%, 38%] | 33% (14/43) [32%, 33%] | 35% (15/43) [29%, 42%] | 0% (0/15) [0%, 0%] |
| gpt-6.1-terra xhigh | 23% (16/69) [11%, 32%] | 35% (24/69) [26%, 41%] | 42% (29/69) [27%, 54%] | 0% (0/29) [0%, 0%] |

### Terra efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| gpt-5.6-terra high | 23% (227/968) [20%, 27%] | 36% (346/968) [32%, 39%] | 41% (395/968) [37%, 45%] | 0.3% (1/395) [0%, 0.8%] |
| gpt-5.6-terra low | 24% (228/954) [21%, 27%] | 34% (325/954) [31%, 37%] | 42% (401/954) [39%, 45%] | 0% (0/401) [0%, 0%] |
| gpt-5.6-terra max | 27% (276/1020) [23%, 31%] | 35% (361/1020) [32%, 38%] | 38% (383/1020) [34%, 42%] | 0% (0/383) [0%, 0%] |
| gpt-5.6-terra medium | 24% (221/931) [20%, 27%] | 33% (304/931) [29%, 36%] | 44% (406/931) [40%, 47%] | 0.5% (2/406) [0%, 1.3%] |
| gpt-5.6-terra xhigh | 26% (257/985) [23%, 30%] | 35% (341/985) [32%, 37%] | 39% (387/985) [35%, 43%] | 0.3% (1/387) [0%, 0.8%] |

## Item fates

Each item a player placed, by how it left: used by its owner, stolen with adrenaline, still held when the owner died, or still held when the round ended (censored). Delays count only items used by their owner. Own turns are the owner's own decisions between placing the item and using it, so 0 is the first decision after the distribution.

### Cross-model

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 41% (86/208) [36%, 48%] | 8.2% (17/208) [6.7%, 9.7%] | 38% (80/208) [33%, 44%] | 12% (25/208) [8.1%, 16%] | 1.21 (1) | 6 |
| claude-haiku-4-5-20251001 low | 48% (101/212) [36%, 60%] | 8.5% (18/212) [5.8%, 11%] | 25% (54/212) [17%, 36%] | 18% (39/212) [4.9%, 36%] | 1.50 (1) | 6 |
| claude-haiku-4-5-20251001 medium | 47% (1922/4064) [45%, 49%] | 7.9% (321/4064) [7.1%, 8.7%] | 29% (1192/4064) [27%, 32%] | 15% (629/4064) [13%, 18%] | 1.38 (1) | 6 |
| claude-haiku-4-5-20251001 minimal | 55% (127/231) [46%, 61%] | 6.5% (15/231) [4.1%, 8.6%] | 24% (56/231) [14%, 35%] | 14% (33/231) [6.5%, 22%] | 1.58 (1) | 7 |
| claude-haiku-4-5-20251001 off | 49% (115/237) [38%, 55%] | 8.0% (19/237) [6.1%, 9.8%] | 32% (77/237) [19%, 46%] | 11% (26/237) [1.8%, 20%] | 1.33 (1) | 7 |
| claude-haiku-5-5 high | 55% (143/258) [44%, 68%] | 7.4% (19/258) [3.5%, 11%] | 29% (74/258) [20%, 38%] | 8.5% (22/258) [3.9%, 13%] | 1.45 (1) | 6 |
| claude-haiku-5-5 low | 58% (170/294) [53%, 62%] | 5.8% (17/294) [3.4%, 8.6%] | 19% (55/294) [12%, 24%] | 18% (52/294) [13%, 24%] | 1.38 (1) | 7 |
| claude-haiku-5-5 max | 62% (133/216) [53%, 69%] | 5.6% (12/216) [2.9%, 9.0%] | 16% (34/216) [6.7%, 26%] | 17% (37/216) [12%, 23%] | 1.68 (1) | 8 |
| claude-haiku-5-5 medium | 57% (2422/4247) [55%, 59%] | 7.3% (310/4247) [6.6%, 8.0%] | 20% (861/4247) [18%, 22%] | 15% (654/4247) [14%, 17%] | 1.58 (1) | 7 |
| claude-haiku-5-5 off | 50% (119/237) [41%, 59%] | 9.3% (22/237) [6.8%, 12%] | 28% (66/237) [17%, 39%] | 13% (30/237) [4.8%, 19%] | 1.08 (1) | 6 |
| claude-haiku-5-5 xhigh | 51% (116/226) [47%, 55%] | 8.0% (18/226) [3.3%, 12%] | 30% (68/226) [21%, 39%] | 11% (24/226) [7.2%, 14%] | 1.64 (1) | 7 |
| claude-opus-5-5 high | 56% (123/220) [52%, 61%] | 6.4% (14/220) [4.7%, 8.6%] | 19% (41/220) [10%, 27%] | 19% (42/220) [9.6%, 28%] | 1.46 (1) | 7 |
| claude-opus-5-5 low | 52% (108/206) [45%, 60%] | 7.8% (16/206) [4.8%, 10%] | 16% (32/206) [6.6%, 24%] | 24% (50/206) [15%, 38%] | 1.69 (1) | 7 |
| claude-opus-5-5 max | 63% (51/81) [60%, 65%] | 1.2% (1/81) [0%, 2.2%] | 16% (13/81) [4.3%, 31%] | 20% (16/81) [8.6%, 28%] | 1.82 (1) | 9 |
| claude-opus-5-5 medium | 57% (2461/4333) [55%, 58%] | 7.3% (316/4333) [6.5%, 8.1%] | 18% (798/4333) [17%, 20%] | 17% (758/4333) [16%, 19%] | 1.67 (1) | 7 |
| claude-opus-5-5 off | 62% (66/106) [51%, 70%] | 8.5% (9/106) [8.2%, 8.9%] | 16% (17/106) [9.8%, 24%] | 13% (14/106) [11%, 16%] | 2.20 (1) | 7 |
| claude-opus-5-5 xhigh | 57% (547/956) [54%, 61%] | 9.9% (95/956) [7.9%, 12%] | 20% (190/956) [16%, 25%] | 13% (124/956) [10%, 16%] | 1.82 (1) | 7 |
| claude-sonnet-5-5 high | 56% (144/256) [48%, 65%] | 5.1% (13/256) [3.4%, 7.2%] | 18% (45/256) [6.8%, 28%] | 21% (54/256) [16%, 28%] | 1.65 (1) | 7 |
| claude-sonnet-5-5 low | 52% (150/286) [44%, 60%] | 9.8% (28/286) [6.2%, 15%] | 27% (77/286) [12%, 43%] | 11% (31/286) [3.8%, 20%] | 1.82 (1) | 6 |
| claude-sonnet-5-5 max | 57% (126/221) [46%, 66%] | 8.1% (18/221) [4.1%, 13%] | 12% (27/221) [4.9%, 24%] | 23% (50/221) [17%, 28%] | 1.68 (1) | 7 |
| claude-sonnet-5-5 medium | 53% (2196/4116) [51%, 55%] | 7.2% (297/4116) [6.5%, 7.9%] | 21% (884/4116) [19%, 24%] | 18% (739/4116) [16%, 20%] | 1.71 (1) | 7 |
| claude-sonnet-5-5 off | 51% (158/309) [45%, 55%] | 9.7% (30/309) [7.1%, 12%] | 22% (69/309) [12%, 31%] | 17% (52/309) [10%, 24%] | 1.54 (1) | 7 |
| claude-sonnet-5-5 xhigh | 57% (150/262) [53%, 61%] | 8.8% (23/262) [6.9%, 12%] | 17% (45/262) [11%, 24%] | 17% (44/262) [9.7%, 24%] | 1.72 (1) | 8 |
| gpt-5.6-terra high | 52% (124/238) [49%, 55%] | 8.0% (19/238) [4.1%, 12%] | 25% (60/238) [20%, 31%] | 15% (35/238) [7.6%, 23%] | 1.54 (1) | 6 |
| gpt-5.6-terra low | 53% (130/246) [47%, 57%] | 6.5% (16/246) [5.0%, 8.2%] | 22% (54/246) [17%, 29%] | 19% (46/246) [11%, 29%] | 1.23 (1) | 6 |
| gpt-5.6-terra max | 68% (170/250) [63%, 73%] | 8.0% (20/250) [5.1%, 10%] | 14% (35/250) [10%, 17%] | 10% (25/250) [5.1%, 19%] | 1.60 (1) | 6 |
| gpt-5.6-terra medium | 52% (2075/3953) [51%, 54%] | 7.9% (313/3953) [7.1%, 8.8%] | 22% (883/3953) [20%, 25%] | 17% (682/3953) [15%, 20%] | 1.46 (1) | 6 |
| gpt-5.6-terra xhigh | 63% (162/257) [56%, 71%] | 6.6% (17/257) [3.5%, 10.0%] | 16% (42/257) [10.0%, 23%] | 14% (36/257) [8.2%, 21%] | 1.83 (1) | 7 |
| gpt-6-astra high | 56% (61/108) [54%, 59%] | 8.3% (9/108) [7.4%, 9.3%] | 13% (14/108) [11%, 15%] | 22% (24/108) [22%, 22%] | 2.30 (1) | 8 |
| gpt-6-astra low | 55% (77/140) [47%, 62%] | 5.7% (8/140) [2.8%, 10%] | 26% (37/140) [21%, 30%] | 13% (18/140) [6.1%, 20%] | 1.34 (1) | 6 |
| gpt-6-astra medium | 56% (2800/5000) [54%, 58%] | 7.3% (363/5000) [6.5%, 8.1%] | 17% (826/5000) [14%, 19%] | 20% (1011/5000) [19%, 22%] | 1.68 (1) | 7 |
| gpt-6-luna high | 53% (132/249) [45%, 60%] | 4.4% (11/249) [2.4%, 6.6%] | 29% (71/249) [24%, 35%] | 14% (35/249) [11%, 18%] | 1.40 (1) | 7 |
| gpt-6-luna low | 71% (148/209) [63%, 79%] | 6.2% (13/209) [5.1%, 7.3%] | 19% (39/209) [13%, 26%] | 4.3% (9/209) [1.6%, 7.2%] | 1.31 (1) | 6 |
| gpt-6-luna max | 56% (138/246) [45%, 65%] | 5.7% (14/246) [2.4%, 9.9%] | 27% (67/246) [20%, 39%] | 11% (27/246) [3.4%, 18%] | 1.56 (1) | 7 |
| gpt-6-luna medium | 62% (2539/4099) [60%, 64%] | 6.1% (250/4099) [5.5%, 6.7%] | 25% (1021/4099) [23%, 27%] | 7.1% (289/4099) [5.7%, 8.4%] | 1.60 (1) | 6 |
| gpt-6-luna off | 68% (158/232) [64%, 71%] | 6.0% (14/232) [3.6%, 8.5%] | 23% (54/232) [21%, 25%] | 2.6% (6/232) [0.4%, 5.4%] | 1.72 (1) | 6 |
| gpt-6-luna xhigh | 64% (192/299) [56%, 71%] | 6.0% (18/299) [4.2%, 7.3%] | 16% (49/299) [13%, 21%] | 13% (40/299) [8.0%, 19%] | 1.71 (1) | 7 |
| gpt-6.1-sol high | 58% (134/231) [44%, 66%] | 9.1% (21/231) [5.3%, 12%] | 18% (41/231) [11%, 25%] | 15% (35/231) [7.1%, 23%] | 1.51 (1) | 6 |
| gpt-6.1-sol low | 58% (121/208) [47%, 68%] | 7.2% (15/208) [5.7%, 9.4%] | 16% (34/208) [6.9%, 28%] | 18% (38/208) [11%, 29%] | 1.46 (1) | 6 |
| gpt-6.1-sol max | 60% (175/293) [55%, 66%] | 8.2% (24/293) [6.4%, 9.9%] | 7.8% (23/293) [1.2%, 16%] | 24% (71/293) [15%, 34%] | 1.70 (1) | 7 |
| gpt-6.1-sol medium | 57% (2448/4310) [55%, 59%] | 6.9% (296/4310) [6.2%, 7.5%] | 18% (778/4310) [16%, 20%] | 18% (788/4310) [17%, 20%] | 1.65 (1) | 7 |
| gpt-6.1-sol xhigh | 64% (215/337) [57%, 71%] | 6.5% (22/337) [5.0%, 7.9%] | 12% (42/337) [6.5%, 18%] | 17% (58/337) [12%, 23%] | 1.73 (1) | 7 |
| gpt-6.1-terra high | 50% (47/94) [49%, 51%] | 6.4% (6/94) [5.1%, 7.3%] | 33% (31/94) [29%, 38%] | 11% (10/94) [5.1%, 15%] | 2.21 (1) | 7 |
| gpt-6.1-terra low | 60% (32/53) [60%, 60%] | 11% (6/53) [11%, 11%] | 15% (8/53) [15%, 15%] | 13% (7/53) [13%, 13%] | 1.47 (1) | 6 |
| gpt-6.1-terra max | 60% (37/62) [60%, 60%] | 9.7% (6/62) [9.7%, 9.7%] | 21% (13/62) [21%, 21%] | 9.7% (6/62) [9.7%, 9.7%] | 2.32 (1) | 7 |
| gpt-6.1-terra medium | 59% (64/109) [51%, 67%] | 7.3% (8/109) [7.0%, 7.7%] | 20% (22/109) [15%, 25%] | 14% (15/109) [9.6%, 18%] | 1.66 (1) | 6 |
| gpt-6.1-terra off | 54% (22/41) [54%, 54%] | 7.3% (3/41) [7.3%, 7.3%] | 12% (5/41) [12%, 12%] | 27% (11/41) [27%, 27%] | 1.59 (1) | 5 |
| gpt-6.1-terra xhigh | 69% (33/48) [69%, 69%] | 8.3% (4/48) [8.3%, 8.3%] | 13% (6/48) [13%, 13%] | 10% (5/48) [10%, 10%] | 1.88 (1) | 6 |

### Haiku 4.5 efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 52% (1040/2004) [48%, 55%] | 5.7% (115/2004) [4.8%, 6.7%] | 21% (430/2004) [18%, 25%] | 21% (419/2004) [18%, 24%] | 1.62 (1) | 7 |
| claude-haiku-4-5-20251001 low | 53% (1047/1975) [50%, 56%] | 5.4% (107/1975) [4.5%, 6.4%] | 21% (412/1975) [17%, 25%] | 21% (409/1975) [17%, 25%] | 1.41 (1) | 6 |
| claude-haiku-4-5-20251001 medium | 52% (1063/2035) [49%, 55%] | 5.6% (114/2035) [4.6%, 6.7%] | 19% (387/2035) [16%, 22%] | 23% (471/2035) [20%, 27%] | 1.57 (1) | 7 |
| claude-haiku-4-5-20251001 minimal | 53% (1017/1926) [50%, 56%] | 5.8% (112/1926) [5.0%, 6.6%] | 21% (407/1926) [18%, 25%] | 20% (390/1926) [17%, 24%] | 1.54 (1) | 6 |
| claude-haiku-4-5-20251001 off | 56% (1111/2000) [52%, 59%] | 5.4% (108/2000) [4.6%, 6.2%] | 24% (485/2000) [21%, 27%] | 15% (296/2000) [12%, 17%] | 1.59 (1) | 6 |

### Haiku 5.5 efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| claude-haiku-5-5 high | 59% (1332/2266) [57%, 61%] | 8.0% (181/2266) [7.0%, 9.0%] | 19% (439/2266) [17%, 22%] | 14% (314/2266) [12%, 16%] | 1.34 (1) | 6 |
| claude-haiku-5-5 low | 58% (1352/2347) [55%, 60%] | 8.9% (210/2347) [8.1%, 9.9%] | 20% (481/2347) [18%, 23%] | 13% (304/2347) [11%, 15%] | 1.43 (1) | 6 |
| claude-haiku-5-5 max | 60% (1363/2287) [57%, 62%] | 7.7% (175/2287) [6.7%, 8.6%] | 17% (400/2287) [15%, 20%] | 15% (349/2287) [13%, 18%] | 1.62 (1) | 7 |
| claude-haiku-5-5 medium | 60% (1383/2316) [57%, 62%] | 8.3% (192/2316) [7.2%, 9.4%] | 19% (442/2316) [16%, 22%] | 13% (299/2316) [11%, 15%] | 1.52 (1) | 6 |
| claude-haiku-5-5 off | 57% (1314/2288) [55%, 60%] | 8.3% (191/2288) [7.4%, 9.2%] | 23% (529/2288) [21%, 26%] | 11% (254/2288) [8.8%, 14%] | 1.32 (1) | 6 |
| claude-haiku-5-5 xhigh | 57% (1334/2355) [54%, 59%] | 8.3% (195/2355) [7.3%, 9.3%] | 20% (472/2355) [17%, 23%] | 15% (354/2355) [13%, 17%] | 1.52 (1) | 7 |

### Luna efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| gpt-6-luna high | 60% (1526/2524) [58%, 63%] | 7.1% (180/2524) [6.2%, 8.1%] | 18% (452/2524) [15%, 20%] | 15% (366/2524) [13%, 17%] | 1.68 (1) | 7 |
| gpt-6-luna low | 68% (1699/2513) [65%, 70%] | 8.3% (208/2513) [7.4%, 9.1%] | 19% (474/2513) [16%, 22%] | 5.3% (132/2513) [4.0%, 6.6%] | 1.59 (1) | 6 |
| gpt-6-luna max | 66% (1605/2438) [64%, 68%] | 7.8% (189/2438) [6.8%, 8.8%] | 11% (277/2438) [9.1%, 14%] | 15% (367/2438) [13%, 17%] | 1.65 (1) | 7 |
| gpt-6-luna medium | 63% (1586/2535) [60%, 65%] | 9.0% (227/2535) [8.0%, 9.9%] | 19% (491/2535) [17%, 22%] | 9.1% (231/2535) [7.1%, 11%] | 1.72 (1) | 6 |
| gpt-6-luna off | 68% (1691/2493) [65%, 71%] | 9.4% (235/2493) [8.3%, 11%] | 18% (453/2493) [15%, 21%] | 4.6% (114/2493) [3.2%, 6.0%] | 1.58 (1) | 6 |
| gpt-6-luna xhigh | 62% (1524/2439) [60%, 65%] | 8.4% (204/2439) [7.3%, 9.5%] | 13% (327/2439) [10%, 17%] | 16% (384/2439) [13%, 18%] | 1.59 (1) | 7 |

### Opus efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| claude-opus-5-5 high | 57% (506/888) [53%, 61%] | 10% (90/888) [8.5%, 12%] | 23% (201/888) [18%, 27%] | 10% (91/888) [7.5%, 13%] | 1.78 (1) | 7 |
| claude-opus-5-5 low | 55% (296/536) [48%, 62%] | 10% (54/536) [7.7%, 13%] | 19% (103/536) [15%, 24%] | 15% (83/536) [9.8%, 22%] | 1.68 (1) | 7 |
| claude-opus-5-5 max | 66% (57/87) [65%, 66%] | 20% (17/87) [19%, 20%] | 2.3% (2/87) [2.1%, 2.5%] | 13% (11/87) [13%, 13%] | 1.47 (1) | 6 |
| claude-opus-5-5 medium | 58% (815/1416) [55%, 60%] | 9.7% (137/1416) [8.3%, 11%] | 21% (301/1416) [19%, 24%] | 12% (163/1416) [9.8%, 13%] | 1.69 (1) | 7 |
| claude-opus-5-5 off | 52% (37/71) [52%, 52%] | 17% (12/71) [16%, 17%] | 17% (12/71) [15%, 20%] | 14% (10/71) [12%, 15%] | 1.32 (1) | 7 |
| claude-opus-5-5 xhigh | 59% (513/869) [53%, 64%] | 10% (87/869) [8.1%, 13%] | 15% (133/869) [11%, 20%] | 16% (136/869) [12%, 20%] | 1.66 (1) | 6 |

### Sol efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| gpt-6.1-sol high | 56% (1012/1797) [53%, 59%] | 9.2% (165/1797) [8.0%, 10%] | 21% (386/1797) [19%, 24%] | 13% (234/1797) [11%, 15%] | 1.61 (1) | 6 |
| gpt-6.1-sol low | 52% (923/1762) [50%, 55%] | 9.6% (170/1762) [8.4%, 11%] | 23% (401/1762) [19%, 27%] | 15% (268/1762) [12%, 18%] | 1.51 (1) | 6 |
| gpt-6.1-sol max | 58% (1085/1860) [56%, 61%] | 7.7% (144/1860) [6.7%, 8.8%] | 19% (356/1860) [16%, 22%] | 15% (275/1860) [13%, 17%] | 1.55 (1) | 6 |
| gpt-6.1-sol medium | 54% (970/1784) [52%, 57%] | 10% (179/1784) [8.8%, 11%] | 22% (390/1784) [19%, 24%] | 14% (245/1784) [11%, 16%] | 1.58 (1) | 6 |
| gpt-6.1-sol xhigh | 59% (1046/1773) [56%, 62%] | 7.1% (126/1773) [6.1%, 8.1%] | 21% (367/1773) [17%, 24%] | 13% (234/1773) [11%, 16%] | 1.57 (1) | 6 |

### Sonnet efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| claude-sonnet-5-5 high | 56% (1266/2258) [53%, 59%] | 8.5% (193/2258) [7.7%, 9.4%] | 22% (500/2258) [19%, 25%] | 13% (299/2258) [11%, 16%] | 1.70 (1) | 6 |
| claude-sonnet-5-5 low | 52% (1163/2219) [50%, 55%] | 8.1% (180/2219) [7.0%, 9.2%] | 26% (588/2219) [23%, 30%] | 13% (288/2219) [10%, 16%] | 1.72 (1) | 6 |
| claude-sonnet-5-5 max | 61% (1403/2287) [59%, 64%] | 7.8% (178/2287) [6.8%, 8.7%] | 15% (340/2287) [12%, 18%] | 16% (366/2287) [14%, 18%] | 1.95 (1) | 7 |
| claude-sonnet-5-5 medium | 56% (1288/2307) [54%, 58%] | 7.3% (168/2307) [6.4%, 8.2%] | 22% (518/2307) [19%, 26%] | 14% (333/2307) [12%, 17%] | 1.78 (1) | 7 |
| claude-sonnet-5-5 off | 56% (1233/2220) [53%, 58%] | 7.7% (171/2220) [6.7%, 8.8%] | 23% (511/2220) [20%, 26%] | 14% (305/2220) [11%, 16%] | 1.72 (1) | 6 |
| claude-sonnet-5-5 xhigh | 58% (1297/2229) [56%, 60%] | 8.0% (179/2229) [7.0%, 9.1%] | 20% (448/2229) [18%, 23%] | 14% (305/2229) [12%, 16%] | 1.69 (1) | 7 |

### Terra 6.1 efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| gpt-6.1-terra high | 54% (46/85) [50%, 58%] | 5.9% (5/85) [5.0%, 6.7%] | 32% (27/85) [28%, 36%] | 8.2% (7/85) [0%, 18%] | 1.30 (1) | 5 |
| gpt-6.1-terra low | 56% (54/97) [52%, 58%] | 8.2% (8/97) [7.5%, 9.1%] | 12% (12/97) [4.5%, 19%] | 24% (23/97) [15%, 34%] | 1.87 (1) | 8 |
| gpt-6.1-terra max | 71% (39/55) [71%, 71%] | 11% (6/55) [11%, 11%] | 0% (0/55) [0%, 0%] | 18% (10/55) [18%, 18%] | 1.79 (1) | 6 |
| gpt-6.1-terra medium | 54% (100/184) [41%, 66%] | 11% (20/184) [6.0%, 15%] | 19% (35/184) [11%, 28%] | 16% (29/184) [9.2%, 22%] | 1.70 (1) | 6 |
| gpt-6.1-terra off | 49% (44/90) [42%, 55%] | 13% (12/90) [11%, 16%] | 34% (31/90) [28%, 42%] | 3.3% (3/90) [0%, 6.4%] | 1.59 (1) | 6 |
| gpt-6.1-terra xhigh | 49% (70/144) [39%, 69%] | 9.7% (14/144) [4.4%, 16%] | 33% (47/144) [0%, 51%] | 9.0% (13/144) [0%, 27%] | 1.41 (1) | 7 |

### Terra efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| gpt-5.6-terra high | 50% (918/1820) [48%, 53%] | 9.0% (163/1820) [7.8%, 10%] | 22% (408/1820) [19%, 26%] | 18% (331/1820) [15%, 21%] | 1.45 (1) | 6 |
| gpt-5.6-terra low | 48% (898/1878) [45%, 51%] | 9.1% (171/1878) [7.9%, 10%] | 27% (511/1878) [24%, 30%] | 16% (298/1878) [13%, 19%] | 1.43 (1) | 6 |
| gpt-5.6-terra max | 61% (1150/1892) [58%, 63%] | 7.8% (148/1892) [6.8%, 8.8%] | 17% (320/1892) [14%, 20%] | 14% (274/1892) [12%, 16%] | 1.57 (1) | 6 |
| gpt-5.6-terra medium | 46% (861/1855) [44%, 49%] | 8.5% (157/1855) [7.3%, 9.7%] | 31% (571/1855) [28%, 34%] | 14% (266/1855) [12%, 16%] | 1.44 (1) | 6 |
| gpt-5.6-terra xhigh | 55% (1045/1903) [52%, 58%] | 8.5% (162/1903) [7.4%, 9.6%] | 18% (339/1903) [15%, 21%] | 19% (357/1903) [16%, 21%] | 1.55 (1) | 6 |

## Use when legal

Agent decisions where using an own item is a legal move, and the share that use it. A player holding two of an item counts once per decision.

### Cross-model

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 58% (14/24) [48%, 80%] | 17% (13/76) [11%, 32%] | 41% (13/32) [31%, 63%] | 17% (12/71) [13%, 24%] | 8.3% (6/72) [1.4%, 14%] | 21% (12/56) [11%, 35%] | 47% (8/17) [13%, 67%] |
| claude-haiku-4-5-20251001 low | 73% (16/22) [56%, 100%] | 25% (17/67) [17%, 35%] | 41% (19/46) [34%, 49%] | 16% (15/94) [8.4%, 23%] | 14% (10/71) [6.1%, 21%] | 12% (7/57) [7.5%, 19%] | 37% (7/19) [17%, 80%] |
| claude-haiku-4-5-20251001 medium | 63% (338/535) [58%, 69%] | 16% (209/1314) [14%, 19%] | 35% (297/858) [31%, 38%] | 21% (278/1327) [18%, 24%] | 13% (192/1470) [11%, 15%] | 18% (190/1047) [16%, 21%] | 38% (208/554) [33%, 43%] |
| claude-haiku-4-5-20251001 minimal | 67% (24/36) [61%, 77%] | 17% (16/95) [9.8%, 29%] | 50% (21/42) [38%, 69%] | 20% (20/102) [12%, 35%] | 15% (11/72) [9.3%, 23%] | 17% (11/63) [10%, 24%] | 29% (13/45) [25%, 33%] |
| claude-haiku-4-5-20251001 off | 65% (22/34) [57%, 82%] | 40% (14/35) [21%, 57%] | 26% (16/61) [16%, 50%] | 17% (14/82) [11%, 27%] | 16% (13/83) [4.6%, 25%] | 25% (15/61) [15%, 34%] | 33% (14/42) [23%, 49%] |
| claude-haiku-5-5 high | 83% (15/18) [68%, 100%] | 41% (26/63) [28%, 57%] | 21% (11/53) [13%, 33%] | 24% (23/96) [18%, 33%] | 17% (19/113) [9.2%, 24%] | 26% (12/47) [14%, 40%] | 71% (15/21) [52%, 100%] |
| claude-haiku-5-5 low | 80% (24/30) [64%, 100%] | 24% (22/93) [16%, 33%] | 32% (25/79) [26%, 39%] | 25% (23/92) [14%, 37%] | 11% (16/140) [8.4%, 14%] | 32% (24/75) [23%, 40%] | 39% (17/44) [29%, 50%] |
| claude-haiku-5-5 max | 67% (18/27) [56%, 93%] | 32% (21/66) [26%, 43%] | 19% (16/84) [12%, 29%] | 18% (15/85) [9.6%, 28%] | 11% (10/94) [7.0%, 15%] | 27% (17/62) [16%, 46%] | 45% (13/29) [28%, 78%] |
| claude-haiku-5-5 medium | 66% (360/548) [61%, 71%] | 29% (334/1142) [26%, 33%] | 32% (328/1025) [30%, 34%] | 24% (341/1406) [22%, 27%] | 13% (237/1802) [12%, 15%] | 25% (257/1032) [22%, 28%] | 46% (249/541) [42%, 51%] |
| claude-haiku-5-5 off | 68% (13/19) [53%, 82%] | 46% (23/50) [20%, 75%] | 46% (22/48) [40%, 60%] | 21% (13/63) [18%, 29%] | 8.8% (5/57) [2.9%, 13%] | 30% (11/37) [17%, 59%] | 17% (11/64) [8.8%, 26%] |
| claude-haiku-5-5 xhigh | 63% (15/24) [50%, 75%] | 38% (19/50) [30%, 55%] | 19% (10/52) [14%, 28%] | 18% (15/83) [12%, 25%] | 15% (15/99) [11%, 20%] | 20% (11/55) [14%, 32%] | 50% (13/26) [37%, 71%] |
| claude-opus-5-5 high | 55% (22/40) [48%, 62%] | 39% (16/41) [31%, 54%] | 31% (17/55) [24%, 35%] | 18% (12/68) [6.2%, 29%] | 10% (9/90) [5.5%, 15%] | 41% (16/39) [28%, 51%] | 42% (13/31) [36%, 48%] |
| claude-opus-5-5 low | 54% (21/39) [39%, 80%] | 21% (12/56) [8.2%, 33%] | 34% (16/47) [25%, 43%] | 12% (11/92) [4.6%, 20%] | 13% (11/85) [5.7%, 19%] | 31% (11/36) [20%, 50%] | 56% (10/18) [45%, 75%] |
| claude-opus-5-5 max | 62% (8/13) [50%, 80%] | 36% (5/14) [25%, 50%] | 27% (9/33) [18%, 38%] | 18% (7/40) [16%, 25%] | 10% (3/29) [0%, 13%] | 50% (7/14) [40%, 56%] | 38% (5/13) [29%, 50%] |
| claude-opus-5-5 medium | 55% (362/662) [51%, 58%] | 31% (348/1115) [28%, 35%] | 26% (323/1239) [24%, 28%] | 19% (332/1769) [17%, 21%] | 13% (240/1792) [12%, 15%] | 33% (312/938) [30%, 36%] | 38% (242/641) [34%, 41%] |
| claude-opus-5-5 off | 53% (9/17) [45%, 67%] | 23% (8/35) [23%, 23%] | 22% (10/45) [19%, 31%] | 16% (9/57) [16%, 17%] | 22% (6/27) [22%, 25%] | 44% (7/16) [29%, 56%] | 56% (5/9) [50%, 57%] |
| claude-opus-5-5 xhigh | 56% (70/126) [47%, 67%] | 38% (82/213) [30%, 50%] | 23% (73/312) [19%, 28%] | 20% (72/364) [16%, 24%] | 14% (54/400) [11%, 16%] | 36% (63/175) [27%, 46%] | 34% (53/156) [29%, 40%] |
| claude-sonnet-5-5 high | 64% (18/28) [53%, 77%] | 29% (20/68) [15%, 48%] | 25% (20/79) [19%, 32%] | 19% (21/109) [9.3%, 28%] | 10% (12/118) [5.4%, 15%] | 32% (22/68) [19%, 48%] | 44% (18/41) [34%, 60%] |
| claude-sonnet-5-5 low | 75% (18/24) [51%, 100%] | 29% (30/104) [20%, 39%] | 27% (14/52) [22%, 33%] | 15% (17/111) [9.1%, 26%] | 3.8% (5/130) [1.4%, 6.0%] | 32% (24/76) [23%, 48%] | 38% (20/52) [30%, 51%] |
| claude-sonnet-5-5 max | 54% (13/24) [29%, 91%] | 28% (22/80) [19%, 40%] | 26% (18/68) [20%, 31%] | 17% (17/102) [7.3%, 20%] | 15% (14/91) [8.9%, 21%] | 32% (15/47) [18%, 47%] | 40% (12/30) [18%, 69%] |
| claude-sonnet-5-5 medium | 68% (369/546) [63%, 72%] | 24% (302/1243) [21%, 27%] | 26% (293/1128) [24%, 28%] | 20% (317/1582) [17%, 22%] | 7.4% (142/1918) [6.4%, 8.5%] | 34% (287/833) [31%, 39%] | 33% (216/662) [29%, 37%] |
| claude-sonnet-5-5 off | 79% (23/29) [73%, 88%] | 33% (19/58) [25%, 46%] | 24% (22/91) [21%, 30%] | 28% (31/110) [19%, 37%] | 7.3% (10/137) [4.7%, 10%] | 29% (22/77) [21%, 40%] | 52% (11/21) [37%, 74%] |
| claude-sonnet-5-5 xhigh | 76% (19/25) [47%, 100%] | 36% (16/45) [18%, 63%] | 30% (18/60) [21%, 39%] | 23% (27/118) [12%, 39%] | 11% (14/124) [9.0%, 13%] | 37% (13/35) [23%, 67%] | 30% (17/56) [17%, 48%] |
| gpt-5.6-terra high | 63% (25/40) [51%, 76%] | 11% (11/99) [5.9%, 19%] | 32% (18/56) [24%, 43%] | 18% (18/101) [14%, 21%] | 11% (10/90) [5.0%, 15%] | 15% (12/80) [7.9%, 26%] | 82% (14/17) [71%, 100%] |
| gpt-5.6-terra low | 63% (24/38) [56%, 71%] | 24% (11/45) [5.6%, 53%] | 32% (23/72) [24%, 39%] | 16% (18/110) [12%, 23%] | 6.5% (6/92) [2.8%, 9.8%] | 11% (12/110) [3.0%, 26%] | 56% (18/32) [46%, 78%] |
| gpt-5.6-terra max | 60% (25/42) [42%, 78%] | 44% (25/57) [32%, 60%] | 29% (23/80) [22%, 40%] | 23% (21/92) [11%, 39%] | 14% (23/167) [9.0%, 20%] | 29% (16/55) [13%, 52%] | 45% (13/29) [26%, 79%] |
| gpt-5.6-terra medium | 60% (403/670) [57%, 64%] | 14% (216/1529) [12%, 17%] | 35% (297/849) [32%, 38%] | 19% (240/1238) [16%, 23%] | 9.3% (164/1766) [7.9%, 11%] | 13% (180/1374) [11%, 16%] | 67% (261/388) [61%, 74%] |
| gpt-5.6-terra xhigh | 59% (26/44) [36%, 79%] | 22% (19/85) [14%, 35%] | 27% (24/90) [20%, 36%] | 26% (22/85) [22%, 31%] | 12% (15/129) [9.2%, 14%] | 21% (22/107) [16%, 29%] | 59% (17/29) [49%, 93%] |
| gpt-6-astra high | 29% (10/35) [29%, 29%] | 41% (11/27) [35%, 50%] | 28% (8/29) [21%, 33%] | 16% (6/37) [10%, 24%] | 6.5% (3/46) [5.9%, 6.9%] | 17% (3/18) [0%, 21%] | 26% (9/34) [18%, 35%] |
| gpt-6-astra low | 65% (11/17) [40%, 89%] | 33% (8/24) [24%, 75%] | 29% (14/48) [21%, 54%] | 24% (11/45) [12%, 40%] | 15% (8/53) [4.0%, 24%] | 37% (10/27) [31%, 54%] | 37% (7/19) [30%, 50%] |
| gpt-6-astra medium | 50% (419/843) [46%, 54%] | 37% (449/1224) [34%, 40%] | 27% (418/1549) [25%, 29%] | 13% (294/2228) [11%, 15%] | 11% (237/2182) [9.9%, 12%] | 30% (315/1033) [27%, 35%] | 38% (264/704) [35%, 40%] |
| gpt-6-luna high | 70% (23/33) [54%, 81%] | 25% (21/83) [15%, 42%] | 40% (17/43) [32%, 47%] | 30% (23/77) [22%, 36%] | 8.0% (9/112) [4.7%, 11%] | 22% (14/64) [16%, 31%] | 30% (11/37) [17%, 52%] |
| gpt-6-luna low | 74% (20/27) [59%, 95%] | 46% (21/46) [31%, 67%] | 27% (18/66) [18%, 38%] | 34% (22/64) [22%, 49%] | 35% (21/60) [24%, 49%] | 18% (13/72) [9.2%, 24%] | 36% (13/36) [26%, 48%] |
| gpt-6-luna max | 69% (18/26) [59%, 88%] | 29% (23/78) [18%, 56%] | 26% (18/70) [19%, 36%] | 28% (23/82) [23%, 33%] | 13% (11/87) [8.7%, 16%] | 22% (14/63) [11%, 32%] | 67% (14/21) [50%, 88%] |
| gpt-6-luna medium | 68% (394/579) [64%, 72%] | 36% (381/1065) [33%, 39%] | 34% (352/1024) [32%, 37%] | 29% (381/1315) [27%, 32%] | 16% (256/1569) [14%, 19%] | 21% (254/1209) [19%, 23%] | 40% (232/582) [35%, 45%] |
| gpt-6-luna off | 54% (21/39) [40%, 94%] | 52% (24/46) [39%, 65%] | 33% (15/46) [28%, 47%] | 24% (17/72) [11%, 35%] | 27% (26/95) [19%, 39%] | 30% (14/46) [25%, 41%] | 56% (20/36) [40%, 77%] |
| gpt-6-luna xhigh | 56% (23/41) [47%, 80%] | 30% (23/77) [16%, 45%] | 26% (24/93) [20%, 31%] | 20% (25/124) [8.8%, 37%] | 12% (22/191) [8.0%, 15%] | 33% (26/78) [24%, 46%] | 61% (20/33) [49%, 77%] |
| gpt-6.1-sol high | 45% (18/40) [44%, 48%] | 32% (20/62) [22%, 42%] | 33% (23/70) [31%, 36%] | 16% (14/85) [2.5%, 37%] | 15% (13/85) [6.8%, 24%] | 33% (15/45) [25%, 46%] | 38% (15/40) [33%, 42%] |
| gpt-6.1-sol low | 59% (17/29) [45%, 76%] | 30% (15/50) [15%, 44%] | 30% (18/60) [24%, 39%] | 17% (12/69) [7.9%, 25%] | 6.9% (7/101) [2.7%, 13%] | 26% (14/54) [8.9%, 44%] | 40% (12/30) [19%, 60%] |
| gpt-6.1-sol max | 48% (23/48) [40%, 62%] | 34% (22/64) [27%, 45%] | 22% (21/94) [18%, 29%] | 16% (18/110) [10%, 23%] | 16% (22/136) [14%, 20%] | 43% (23/53) [29%, 64%] | 25% (17/67) [19%, 35%] |
| gpt-6.1-sol medium | 51% (358/704) [47%, 55%] | 35% (364/1027) [32%, 39%] | 28% (348/1228) [27%, 30%] | 14% (246/1700) [13%, 16%] | 12% (228/1828) [11%, 14%] | 34% (300/892) [29%, 38%] | 39% (254/649) [36%, 42%] |
| gpt-6.1-sol xhigh | 52% (22/42) [41%, 75%] | 51% (40/78) [35%, 66%] | 30% (29/98) [26%, 34%] | 26% (45/173) [19%, 31%] | 13% (21/159) [9.9%, 17%] | 26% (22/84) [18%, 35%] | 30% (17/56) [21%, 40%] |
| gpt-6.1-terra high | 43% (3/7) [43%, 43%] | 33% (9/27) [25%, 45%] | 29% (6/21) [23%, 38%] | 8.7% (4/46) [5.9%, 10%] | 13% (7/53) [12%, 15%] | 42% (5/12) [38%, 50%] | 50% (5/10) [33%, 75%] |
| gpt-6.1-terra low | 75% (6/8) [75%, 75%] | 43% (3/7) [43%, 43%] | 18% (3/17) [18%, 18%] | 3.8% (1/26) [3.8%, 3.8%] | 9.8% (4/41) [9.8%, 9.8%] | 21% (5/24) [21%, 21%] | 44% (4/9) [44%, 44%] |
| gpt-6.1-terra max | 40% (6/15) [40%, 40%] | 44% (8/18) [44%, 44%] | 33% (2/6) [33%, 33%] | 21% (6/29) [21%, 21%] | 2.3% (1/44) [2.3%, 2.3%] | 45% (5/11) [45%, 45%] | 33% (2/6) [33%, 33%] |
| gpt-6.1-terra medium | 27% (9/33) [14%, 50%] | 36% (13/36) [26%, 54%] | 31% (4/13) [0%, 50%] | 9.2% (6/65) [3.7%, 13%] | 15% (7/48) [12%, 18%] | 50% (11/22) [47%, 57%] | 46% (6/13) [43%, 50%] |
| gpt-6.1-terra off | 67% (4/6) [67%, 67%] | 67% (4/6) [67%, 67%] | 31% (5/16) [31%, 31%] | 4.8% (1/21) [4.8%, 4.8%] | 0% (0/20) [0%, 0%] | 17% (1/6) [17%, 17%] | 44% (4/9) [44%, 44%] |
| gpt-6.1-terra xhigh | 43% (6/14) [43%, 43%] | 78% (7/9) [78%, 78%] | 36% (4/11) [36%, 36%] | 14% (6/43) [14%, 14%] | 12% (2/17) [12%, 12%] | 11% (1/9) [11%, 11%] | 33% (3/9) [33%, 33%] |

### Haiku 4.5 efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 56% (202/362) [50%, 62%] | 12% (85/725) [9.3%, 15%] | 36% (154/431) [31%, 41%] | 20% (141/704) [16%, 25%] | 13% (112/875) [11%, 15%] | 19% (119/611) [16%, 23%] | 34% (103/305) [28%, 40%] |
| claude-haiku-4-5-20251001 low | 70% (201/286) [66%, 76%] | 16% (120/742) [13%, 20%] | 39% (170/433) [34%, 45%] | 21% (132/633) [18%, 24%] | 12% (104/847) [11%, 14%] | 18% (116/646) [14%, 22%] | 26% (95/370) [20%, 32%] |
| claude-haiku-4-5-20251001 medium | 58% (220/379) [53%, 63%] | 12% (84/714) [8.9%, 15%] | 38% (177/463) [34%, 43%] | 17% (126/739) [14%, 21%] | 13% (122/962) [10%, 15%] | 17% (121/726) [14%, 20%] | 29% (96/333) [23%, 36%] |
| claude-haiku-4-5-20251001 minimal | 65% (197/301) [60%, 71%] | 19% (120/616) [16%, 24%] | 37% (166/446) [33%, 42%] | 18% (121/681) [15%, 21%] | 14% (122/865) [12%, 17%] | 14% (100/711) [12%, 17%] | 29% (77/266) [22%, 37%] |
| claude-haiku-4-5-20251001 off | 78% (222/284) [73%, 83%] | 27% (171/634) [22%, 33%] | 30% (145/477) [26%, 35%] | 20% (130/660) [16%, 23%] | 20% (153/761) [17%, 23%] | 16% (118/720) [13%, 20%] | 20% (80/406) [15%, 25%] |

### Haiku 5.5 efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-5-5 high | 59% (199/339) [54%, 65%] | 33% (185/566) [28%, 38%] | 29% (156/546) [26%, 32%] | 21% (148/705) [17%, 25%] | 15% (131/875) [13%, 17%] | 27% (159/596) [23%, 31%] | 58% (146/252) [51%, 64%] |
| claude-haiku-5-5 low | 63% (220/348) [58%, 70%] | 26% (176/667) [22%, 32%] | 37% (178/475) [35%, 41%] | 27% (181/681) [24%, 30%] | 11% (107/977) [9.1%, 13%] | 24% (171/700) [21%, 29%] | 49% (141/289) [43%, 55%] |
| claude-haiku-5-5 max | 50% (211/423) [45%, 56%] | 32% (187/578) [28%, 38%] | 27% (160/597) [25%, 29%] | 20% (161/787) [18%, 23%] | 17% (153/926) [14%, 19%] | 26% (159/602) [23%, 32%] | 47% (130/277) [42%, 52%] |
| claude-haiku-5-5 medium | 61% (244/403) [55%, 67%] | 28% (177/635) [23%, 33%] | 32% (170/525) [29%, 36%] | 21% (164/765) [18%, 25%] | 15% (136/924) [12%, 17%] | 25% (173/686) [22%, 30%] | 46% (120/263) [35%, 56%] |
| claude-haiku-5-5 off | 76% (229/300) [72%, 80%] | 41% (200/486) [36%, 48%] | 44% (201/459) [39%, 49%] | 32% (197/609) [29%, 36%] | 8.3% (80/962) [6.6%, 10%] | 19% (141/732) [16%, 22%] | 25% (102/407) [21%, 30%] |
| claude-haiku-5-5 xhigh | 56% (200/357) [50%, 63%] | 32% (185/571) [28%, 38%] | 27% (156/570) [25%, 30%] | 19% (164/881) [16%, 22%] | 15% (148/990) [13%, 17%] | 27% (157/588) [23%, 31%] | 48% (131/271) [39%, 59%] |

### Luna efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6-luna high | 61% (250/410) [57%, 66%] | 21% (186/878) [18%, 24%] | 33% (211/640) [30%, 36%] | 29% (240/814) [27%, 32%] | 7.8% (105/1338) [6.6%, 9.4%] | 24% (177/748) [19%, 30%] | 49% (132/271) [43%, 56%] |
| gpt-6-luna low | 68% (225/332) [64%, 73%] | 50% (259/515) [45%, 56%] | 33% (212/637) [30%, 37%] | 29% (213/732) [25%, 34%] | 33% (265/803) [30%, 37%] | 21% (167/782) [17%, 26%] | 41% (152/367) [37%, 47%] |
| gpt-6-luna max | 53% (239/448) [49%, 59%] | 33% (198/601) [29%, 38%] | 28% (206/731) [26%, 31%] | 26% (233/885) [22%, 31%] | 13% (156/1195) [11%, 15%] | 25% (180/721) [21%, 29%] | 66% (163/247) [59%, 73%] |
| gpt-6-luna medium | 68% (253/374) [63%, 73%] | 36% (232/647) [30%, 43%] | 34% (215/631) [31%, 37%] | 29% (221/759) [26%, 33%] | 17% (179/1082) [14%, 20%] | 18% (148/842) [15%, 22%] | 39% (152/385) [34%, 46%] |
| gpt-6-luna off | 66% (217/328) [61%, 71%] | 51% (252/492) [46%, 58%] | 32% (236/745) [29%, 35%] | 31% (218/705) [28%, 34%] | 36% (254/700) [33%, 40%] | 23% (167/724) [20%, 26%] | 40% (154/388) [35%, 45%] |
| gpt-6-luna xhigh | 55% (231/417) [51%, 60%] | 25% (195/772) [21%, 30%] | 32% (202/629) [29%, 36%] | 29% (229/793) [26%, 32%] | 10.0% (113/1133) [8.2%, 12%] | 26% (192/729) [22%, 32%] | 64% (159/249) [59%, 69%] |

### Opus efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 high | 47% (72/154) [40%, 56%] | 34% (73/212) [29%, 42%] | 25% (52/212) [19%, 30%] | 16% (56/355) [12%, 21%] | 14% (52/371) [12%, 16%] | 26% (54/208) [18%, 39%] | 50% (51/101) [42%, 63%] |
| claude-opus-5-5 low | 53% (56/106) [48%, 60%] | 16% (29/179) [13%, 25%] | 24% (34/142) [19%, 30%] | 15% (29/189) [12%, 23%] | 13% (24/191) [8.6%, 16%] | 38% (37/98) [26%, 56%] | 51% (33/65) [39%, 64%] |
| claude-opus-5-5 max | 50% (10/20) [38%, 100%] | 75% (3/4) [67%, 100%] | 33% (7/21) [33%, 33%] | 23% (7/31) [22%, 25%] | 20% (4/20) [7.1%, 50%] | 38% (9/24) [30%, 43%] | 44% (4/9) [0%, 67%] |
| claude-opus-5-5 medium | 50% (126/250) [45%, 59%] | 30% (113/377) [26%, 34%] | 27% (86/323) [23%, 31%] | 17% (94/555) [14%, 20%] | 13% (75/587) [11%, 15%] | 36% (103/287) [29%, 45%] | 53% (73/139) [46%, 61%] |
| claude-opus-5-5 off | 44% (4/9) [43%, 50%] | 50% (4/8) [50%, 50%] | 38% (6/16) [33%, 43%] | 7.4% (2/27) [5.3%, 13%] | 18% (6/34) [16%, 22%] | 33% (5/15) [17%, 44%] | 67% (4/6) [33%, 100%] |
| claude-opus-5-5 xhigh | 50% (82/164) [46%, 55%] | 40% (82/207) [32%, 49%] | 25% (54/219) [22%, 28%] | 16% (49/309) [11%, 23%] | 14% (50/359) [10%, 18%] | 33% (61/186) [25%, 43%] | 34% (52/155) [28%, 41%] |

### Sol efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6.1-sol high | 45% (161/357) [40%, 51%] | 43% (166/387) [37%, 50%] | 28% (115/405) [25%, 32%] | 15% (97/627) [13%, 19%] | 13% (89/690) [11%, 15%] | 35% (129/368) [29%, 42%] | 36% (95/264) [32%, 41%] |
| gpt-6.1-sol low | 48% (171/358) [44%, 52%] | 31% (132/421) [25%, 40%] | 31% (109/355) [28%, 34%] | 12% (81/668) [9.2%, 16%] | 9.3% (64/686) [7.0%, 12%] | 38% (128/341) [32%, 44%] | 40% (95/235) [35%, 47%] |
| gpt-6.1-sol max | 50% (155/309) [45%, 55%] | 41% (153/369) [35%, 49%] | 26% (117/445) [23%, 30%] | 21% (139/676) [18%, 24%] | 14% (108/798) [12%, 16%] | 38% (139/370) [32%, 44%] | 38% (107/281) [33%, 45%] |
| gpt-6.1-sol medium | 50% (158/318) [45%, 56%] | 35% (149/423) [29%, 43%] | 30% (107/356) [27%, 33%] | 17% (102/603) [13%, 22%] | 11% (89/826) [8.6%, 13%] | 38% (122/317) [32%, 46%] | 43% (97/227) [38%, 49%] |
| gpt-6.1-sol xhigh | 47% (152/326) [41%, 53%] | 47% (171/363) [42%, 53%] | 31% (115/377) [28%, 34%] | 19% (113/589) [16%, 23%] | 15% (106/702) [13%, 17%] | 36% (131/367) [30%, 42%] | 37% (90/244) [33%, 41%] |

### Sonnet efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-sonnet-5-5 high | 64% (205/322) [59%, 69%] | 36% (202/554) [32%, 41%] | 27% (142/518) [25%, 30%] | 21% (163/789) [17%, 24%] | 8.7% (92/1053) [7.1%, 10%] | 35% (159/454) [30%, 42%] | 42% (139/330) [36%, 50%] |
| claude-sonnet-5-5 low | 65% (217/332) [61%, 71%] | 27% (162/611) [22%, 32%] | 27% (139/511) [24%, 31%] | 18% (152/830) [16%, 21%] | 8.5% (78/920) [7.1%, 10%] | 31% (156/505) [26%, 37%] | 34% (107/313) [29%, 40%] |
| claude-sonnet-5-5 max | 47% (216/455) [43%, 53%] | 36% (171/481) [30%, 41%] | 25% (178/721) [22%, 28%] | 18% (151/843) [15%, 21%] | 17% (187/1117) [15%, 19%] | 32% (178/549) [28%, 37%] | 37% (113/305) [33%, 42%] |
| claude-sonnet-5-5 medium | 60% (210/348) [56%, 65%] | 26% (176/678) [22%, 31%] | 27% (159/589) [25%, 30%] | 20% (167/850) [17%, 23%] | 8.3% (85/1025) [7.0%, 9.6%] | 36% (180/505) [31%, 42%] | 38% (134/352) [33%, 44%] |
| claude-sonnet-5-5 off | 64% (211/328) [61%, 69%] | 38% (210/553) [33%, 44%] | 24% (124/512) [22%, 27%] | 22% (157/706) [19%, 26%] | 7.0% (71/1013) [5.6%, 8.5%] | 31% (169/550) [26%, 37%] | 38% (120/315) [32%, 44%] |
| claude-sonnet-5-5 xhigh | 60% (176/292) [52%, 69%] | 40% (197/496) [36%, 45%] | 24% (144/598) [22%, 26%] | 21% (164/768) [18%, 25%] | 15% (137/922) [13%, 17%] | 31% (163/528) [26%, 37%] | 43% (120/282) [38%, 48%] |

### Terra 6.1 efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6.1-terra high | 64% (7/11) [63%, 67%] | 42% (8/19) [29%, 50%] | 38% (10/26) [33%, 45%] | 7.0% (3/43) [6.3%, 7.4%] | 8.3% (1/12) [0%, 33%] | 38% (5/13) [27%, 100%] | 41% (7/17) [36%, 50%] |
| gpt-6.1-terra low | 33% (15/46) [31%, 33%] | 23% (8/35) [5.3%, 44%] | 24% (4/17) [13%, 33%] | 0% (0/54) [0%, 0%] | 3.3% (1/30) [0%, 17%] | 37% (7/19) [23%, 67%] | 42% (5/12) [25%, 75%] |
| gpt-6.1-terra max | 45% (5/11) [45%, 45%] | 35% (6/17) [35%, 35%] | 22% (4/18) [22%, 22%] | 36% (4/11) [36%, 36%] | 14% (4/29) [14%, 14%] | 35% (6/17) [35%, 35%] | 42% (5/12) [42%, 42%] |
| gpt-6.1-terra medium | 44% (19/43) [33%, 67%] | 37% (19/52) [28%, 40%] | 32% (12/38) [20%, 58%] | 5.2% (3/58) [1.4%, 14%] | 7.8% (4/51) [0%, 12%] | 25% (14/56) [15%, 44%] | 33% (11/33) [26%, 42%] |
| gpt-6.1-terra off | 29% (5/17) [29%, 30%] | 21% (5/24) [9.1%, 31%] | 27% (6/22) [25%, 29%] | 8.0% (4/50) [3.4%, 14%] | 14% (4/28) [11%, 16%] | 36% (5/14) [33%, 38%] | 23% (3/13) [22%, 25%] |
| gpt-6.1-terra xhigh | 37% (10/27) [33%, 50%] | 69% (9/13) [67%, 71%] | 35% (13/37) [29%, 42%] | 6.1% (3/49) [3.6%, 13%] | 11% (6/54) [0%, 13%] | 43% (9/21) [27%, 60%] | 69% (9/13) [56%, 100%] |

### Terra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-5.6-terra high | 57% (161/281) [51%, 65%] | 14% (85/594) [11%, 18%] | 36% (131/360) [32%, 41%] | 17% (104/609) [14%, 21%] | 9.2% (76/828) [7.2%, 11%] | 16% (96/600) [12%, 21%] | 71% (104/147) [64%, 78%] |
| gpt-5.6-terra low | 60% (169/284) [55%, 65%] | 12% (75/643) [8.3%, 16%] | 36% (138/380) [34%, 39%] | 16% (114/694) [12%, 21%] | 8.2% (63/768) [6.2%, 10%] | 15% (90/598) [11%, 20%] | 63% (113/178) [56%, 73%] |
| gpt-5.6-terra max | 54% (172/316) [50%, 60%] | 35% (155/444) [29%, 42%] | 28% (121/434) [25%, 31%] | 22% (145/660) [18%, 26%] | 13% (120/955) [11%, 14%] | 29% (141/488) [24%, 35%] | 60% (108/181) [53%, 67%] |
| gpt-5.6-terra medium | 55% (160/292) [49%, 61%] | 11% (70/655) [8.1%, 14%] | 42% (145/345) [38%, 47%] | 15% (91/627) [11%, 19%] | 9.5% (69/725) [7.1%, 12%] | 15% (76/495) [12%, 20%] | 74% (108/145) [65%, 84%] |
| gpt-5.6-terra xhigh | 54% (170/312) [50%, 60%] | 19% (130/675) [15%, 24%] | 35% (139/396) [31%, 40%] | 18% (123/693) [14%, 22%] | 10% (90/883) [8.4%, 12%] | 18% (103/570) [15%, 22%] | 69% (116/169) [59%, 80%] |

## Adrenaline steals when legal

Agent decisions where stealing an item with adrenaline is legal, and the share that steal it. These are separate from the player's own items.

### Cross-model

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 17% (3/18) [2.9%, 83%] | 0% (0/32) [0%, 0%] | 0% (0/19) [0%, 0%] | 6.7% (2/30) [0%, 23%] | 3.4% (1/29) [0%, 9.7%] | 0% (0/28) [0%, 0%] | 17% (2/12) [0%, 67%] |
| claude-haiku-4-5-20251001 low | – | 0% (0/5) [0%, 0%] | 12% (3/25) [5.0%, 17%] | 0% (0/29) [0%, 0%] | 2.9% (1/34) [0%, 14%] | 8.3% (2/24) [0%, 24%] | 50% (4/8) [50%, 50%] |
| claude-haiku-4-5-20251001 medium | 18% (41/233) [12%, 25%] | 1.0% (5/495) [0.2%, 2.0%] | 16% (48/300) [12%, 21%] | 3.4% (19/561) [1.8%, 5.2%] | 5.5% (35/641) [3.7%, 7.6%] | 3.6% (13/363) [1.9%, 5.5%] | 35% (49/142) [27%, 44%] |
| claude-haiku-4-5-20251001 minimal | 12% (2/17) [0%, 33%] | 0% (0/32) [0%, 0%] | 6.3% (1/16) [0%, 27%] | 7.1% (3/42) [1.8%, 21%] | 2.9% (1/34) [0%, 17%] | 5.7% (2/35) [0%, 18%] | 50% (2/4) [50%, 50%] |
| claude-haiku-4-5-20251001 off | 0% (0/30) [0%, 0%] | 0% (0/32) [0%, 0%] | 16% (3/19) [0%, 33%] | 2.4% (1/42) [0%, 6.1%] | 3.5% (2/57) [0%, 7.3%] | 0% (0/28) [0%, 0%] | 8.3% (1/12) [0%, 17%] |
| claude-haiku-5-5 high | 46% (6/13) [29%, 59%] | 15% (2/13) [0%, 100%] | 50% (3/6) [50%, 50%] | 5.0% (1/20) [0%, 13%] | 19% (3/16) [0%, 25%] | 17% (3/18) [5.3%, 36%] | 57% (4/7) [40%, 100%] |
| claude-haiku-5-5 low | 71% (5/7) [50%, 100%] | 20% (3/15) [4.3%, 60%] | 31% (4/13) [9.1%, 44%] | 15% (5/34) [2.7%, 33%] | 2.8% (1/36) [0%, 9.4%] | 0% (0/28) [0%, 0%] | 7.1% (1/14) [0%, 33%] |
| claude-haiku-5-5 max | 14% (2/14) [0%, 33%] | 14% (3/22) [0%, 30%] | 18% (3/17) [13%, 25%] | 14% (4/29) [3.3%, 26%] | 8.7% (2/23) [0%, 21%] | 28% (5/18) [17%, 50%] | 50% (4/8) [14%, 80%] |
| claude-haiku-5-5 medium | 26% (55/214) [19%, 34%] | 10% (43/411) [7.8%, 14%] | 27% (59/220) [21%, 34%] | 8.4% (38/452) [6.1%, 11%] | 6.7% (31/462) [4.8%, 9.0%] | 15% (52/337) [12%, 20%] | 30% (38/125) [23%, 40%] |
| claude-haiku-5-5 off | 75% (3/4) [50%, 100%] | 14% (4/29) [5.3%, 30%] | 43% (3/7) [0%, 67%] | 8.0% (2/25) [0%, 15%] | 20% (6/30) [3.1%, 46%] | 11% (3/27) [0%, 38%] | 0% (0/4) [0%, 0%] |
| claude-haiku-5-5 xhigh | 25% (3/12) [0%, 50%] | 4.3% (1/23) [0%, 11%] | 50% (6/12) [43%, 80%] | 6.3% (1/16) [0%, 21%] | 4.2% (1/24) [0%, 17%] | 21% (4/19) [5.9%, 46%] | 40% (2/5) [0%, 100%] |
| claude-opus-5-5 high | 5.6% (1/18) [0%, 50%] | 14% (2/14) [0%, 40%] | 14% (1/7) [0%, 100%] | 0% (0/39) [0%, 0%] | 14% (4/28) [6.3%, 25%] | 21% (5/24) [11%, 40%] | 42% (5/12) [20%, 100%] |
| claude-opus-5-5 low | 67% (2/3) [0%, 100%] | 3.1% (1/32) [0%, 4.5%] | 56% (5/9) [22%, 88%] | 0% (0/25) [0%, 0%] | 13% (3/23) [6.3%, 29%] | 13% (2/15) [0%, 33%] | 38% (3/8) [0%, 50%] |
| claude-opus-5-5 max | 100% (2/2) [100%, 100%] | 0% (0/4) [0%, 0%] | 17% (1/6) [17%, 17%] | 0% (0/9) [0%, 0%] | 6.3% (1/16) [0%, 7.7%] | 11% (1/9) [0%, 13%] | 50% (2/4) [33%, 100%] |
| claude-opus-5-5 medium | 34% (62/183) [27%, 42%] | 6.6% (30/456) [4.3%, 9.1%] | 20% (46/232) [16%, 25%] | 5.4% (28/514) [3.5%, 7.4%] | 8.6% (47/546) [6.7%, 11%] | 12% (41/351) [8.3%, 16%] | 35% (48/138) [28%, 44%] |
| claude-opus-5-5 off | 23% (3/13) [13%, 40%] | 13% (1/8) [0%, 20%] | 0% (0/11) [0%, 0%] | 14% (3/22) [11%, 15%] | 30% (3/10) [20%, 40%] | 0% (0/18) [0%, 0%] | 33% (2/6) [0%, 67%] |
| claude-opus-5-5 xhigh | 27% (19/71) [19%, 36%] | 2.6% (3/116) [0%, 6.9%] | 16% (11/68) [7.5%, 25%] | 4.4% (6/137) [0.7%, 10%] | 8.0% (14/174) [5.2%, 11%] | 10% (12/120) [6.1%, 14%] | 33% (15/45) [24%, 44%] |
| claude-sonnet-5-5 high | 17% (3/18) [8.3%, 27%] | 5.1% (2/39) [0%, 30%] | 14% (3/22) [0%, 40%] | 0% (0/11) [0%, 0%] | 2.6% (1/38) [0%, 23%] | 11% (3/27) [0%, 27%] | 17% (1/6) [17%, 17%] |
| claude-sonnet-5-5 low | 60% (9/15) [53%, 73%] | 0% (0/47) [0%, 0%] | 9.1% (3/33) [0%, 13%] | 2.2% (1/46) [0%, 12%] | 4.6% (3/65) [2.2%, 7.2%] | 0% (0/35) [0%, 0%] | 32% (6/19) [20%, 80%] |
| claude-sonnet-5-5 max | 13% (2/15) [0%, 50%] | 7.7% (1/13) [0%, 12%] | 25% (5/20) [14%, 35%] | 8.3% (1/12) [0%, 33%] | 0% (0/17) [0%, 0%] | 20% (4/20) [4.8%, 31%] | 100% (2/2) [100%, 100%] |
| claude-sonnet-5-5 medium | 36% (101/282) [30%, 42%] | 2.3% (13/561) [1.0%, 3.8%] | 13% (45/352) [9.5%, 16%] | 2.3% (13/575) [1.2%, 3.5%] | 3.3% (24/738) [2.0%, 4.6%] | 5.4% (29/534) [3.7%, 7.4%] | 19% (45/235) [14%, 25%] |
| claude-sonnet-5-5 off | 31% (5/16) [11%, 64%] | 0% (0/30) [0%, 0%] | 13% (3/23) [3.7%, 40%] | 14% (6/44) [0%, 31%] | 7.1% (3/42) [0%, 12%] | 0% (0/23) [0%, 0%] | 18% (3/17) [0%, 60%] |
| claude-sonnet-5-5 xhigh | 36% (4/11) [10%, 67%] | 12% (3/25) [0%, 23%] | 19% (4/21) [14%, 29%] | 7.3% (4/55) [0%, 13%] | 6.9% (2/29) [0%, 15%] | 19% (6/31) [11%, 33%] | 30% (3/10) [13%, 67%] |
| gpt-5.6-terra high | 40% (4/10) [20%, 100%] | 0% (0/41) [0%, 0%] | 33% (5/15) [0%, 46%] | 0% (0/29) [0%, 0%] | 2.6% (1/38) [0%, 8.3%] | 12% (3/25) [0%, 25%] | 75% (3/4) [67%, 100%] |
| gpt-5.6-terra low | 50% (4/8) [0%, 100%] | 6.9% (2/29) [0%, 29%] | 29% (6/21) [17%, 50%] | 2.0% (1/51) [0%, 5.3%] | 2.1% (1/47) [0%, 10%] | 4.0% (1/25) [0%, 7.7%] | 75% (3/4) [50%, 100%] |
| gpt-5.6-terra max | 36% (4/11) [33%, 50%] | 12% (3/26) [0%, 38%] | 17% (3/18) [0%, 50%] | 11% (3/28) [3.0%, 22%] | 13% (3/23) [4.5%, 25%] | 10% (1/10) [0%, 33%] | 64% (7/11) [45%, 100%] |
| gpt-5.6-terra medium | 32% (78/243) [27%, 38%] | 2.4% (11/465) [1.1%, 3.8%] | 23% (85/365) [19%, 28%] | 6.0% (28/469) [3.8%, 8.5%] | 2.8% (17/602) [1.6%, 4.2%] | 4.5% (19/418) [2.6%, 6.9%] | 57% (76/134) [48%, 67%] |
| gpt-5.6-terra xhigh | 33% (3/9) [6.7%, 83%] | 9.1% (2/22) [0%, 31%] | 21% (4/19) [0%, 25%] | 4.2% (1/24) [0%, 12%] | 8.3% (2/24) [0%, 30%] | 11% (2/19) [0%, 40%] | 75% (3/4) [75%, 75%] |
| gpt-6-astra high | 50% (4/8) [40%, 67%] | 9.1% (1/11) [0%, 13%] | 25% (2/8) [25%, 25%] | 0% (0/22) [0%, 0%] | 0% (0/7) [0%, 0%] | 20% (3/15) [11%, 33%] | 100% (1/1) [100%, 100%] |
| gpt-6-astra low | 100% (1/1) [100%, 100%] | 9.1% (1/11) [0%, 17%] | 50% (5/10) [33%, 67%] | 0% (0/5) [0%, 0%] | 0% (0/15) [0%, 0%] | 10% (1/10) [0%, 50%] | – |
| gpt-6-astra medium | 33% (84/255) [26%, 41%] | 2.7% (15/560) [1.4%, 4.2%] | 24% (72/300) [21%, 28%] | 2.9% (16/554) [1.6%, 4.3%] | 8.9% (61/685) [7.1%, 11%] | 23% (88/383) [19%, 28%] | 40% (68/171) [34%, 46%] |
| gpt-6-luna high | 29% (5/17) [13%, 40%] | 0% (0/33) [0%, 0%] | 18% (3/17) [0%, 23%] | 4.3% (1/23) [0%, 14%] | 0% (0/25) [0%, 0%] | 8.7% (2/23) [0%, 40%] | 43% (3/7) [0%, 50%] |
| gpt-6-luna low | 33% (5/15) [20%, 64%] | 0% (0/9) [0%, 0%] | 0% (0/26) [0%, 0%] | 21% (5/24) [13%, 26%] | 11% (5/46) [3.6%, 24%] | 8.3% (2/24) [0%, 29%] | 43% (3/7) [25%, 67%] |
| gpt-6-luna max | 33% (2/6) [0%, 75%] | 5.0% (1/20) [0%, 7.7%] | 13% (1/8) [0%, 25%] | 5.6% (1/18) [0%, 7.9%] | 12% (5/42) [4.2%, 39%] | 16% (4/25) [5.6%, 24%] | 60% (3/5) [50%, 67%] |
| gpt-6-luna medium | 22% (59/263) [18%, 28%] | 5.7% (29/507) [3.9%, 8.0%] | 11% (33/287) [7.9%, 16%] | 8.4% (43/512) [6.0%, 11%] | 7.2% (48/668) [5.3%, 9.2%] | 4.8% (20/418) [3.1%, 6.7%] | 34% (57/168) [28%, 41%] |
| gpt-6-luna off | 6.9% (2/29) [0%, 9.1%] | 8.7% (4/46) [4.0%, 13%] | 4.2% (1/24) [0%, 13%] | 5.4% (2/37) [0%, 40%] | 17% (6/36) [2.2%, 47%] | 0% (0/16) [0%, 0%] | 43% (6/14) [13%, 100%] |
| gpt-6-luna xhigh | 25% (4/16) [5.3%, 100%] | 7.1% (1/14) [0%, 14%] | 18% (5/28) [8.2%, 33%] | 20% (6/30) [11%, 30%] | 5.4% (2/37) [0%, 9.5%] | 12% (4/33) [2.6%, 23%] | 70% (7/10) [58%, 88%] |
| gpt-6.1-sol high | 19% (3/16) [3.6%, 100%] | 0% (0/6) [0%, 0%] | 22% (2/9) [0%, 67%] | 0% (0/15) [0%, 0%] | 12% (2/17) [0%, 14%] | 30% (6/20) [12%, 100%] | 43% (3/7) [0%, 100%] |
| gpt-6.1-sol low | 70% (7/10) [58%, 100%] | 13% (3/23) [0%, 39%] | 4.8% (1/21) [0%, 9.1%] | 7.1% (2/28) [0%, 29%] | 12% (5/41) [9.1%, 15%] | 25% (4/16) [0%, 50%] | 57% (4/7) [0%, 67%] |
| gpt-6.1-sol max | 38% (5/13) [13%, 86%] | 5.6% (2/36) [0%, 15%] | 23% (5/22) [17%, 32%] | 11% (3/27) [3.0%, 28%] | 11% (5/44) [4.8%, 17%] | 33% (7/21) [11%, 65%] | 29% (2/7) [0%, 67%] |
| gpt-6.1-sol medium | 34% (60/177) [26%, 44%] | 5.1% (22/429) [3.2%, 7.4%] | 22% (61/279) [18%, 26%] | 3.5% (16/452) [1.9%, 5.7%] | 9.3% (54/581) [7.3%, 11%] | 20% (70/352) [15%, 25%] | 40% (67/169) [34%, 47%] |
| gpt-6.1-sol xhigh | 14% (2/14) [0%, 29%] | 0% (0/32) [0%, 0%] | 14% (3/21) [0%, 38%] | 0% (0/54) [0%, 0%] | 5.9% (1/17) [0%, 20%] | 27% (9/33) [18%, 43%] | 57% (4/7) [14%, 100%] |
| gpt-6.1-terra high | 100% (3/3) [100%, 100%] | 43% (3/7) [20%, 100%] | 50% (1/2) [50%, 50%] | 0% (0/11) [0%, 0%] | 0% (0/12) [0%, 0%] | 0% (0/4) [0%, 0%] | 20% (1/5) [20%, 20%] |
| gpt-6.1-terra low | – | 40% (2/5) [40%, 40%] | 50% (1/2) [50%, 50%] | 0% (0/2) [0%, 0%] | 0% (0/7) [0%, 0%] | 33% (1/3) [33%, 33%] | 67% (2/3) [67%, 67%] |
| gpt-6.1-terra max | 50% (2/4) [50%, 50%] | 0% (0/2) [0%, 0%] | 33% (2/6) [33%, 33%] | 0% (0/2) [0%, 0%] | 0% (0/1) [0%, 0%] | 50% (3/6) [50%, 50%] | – |
| gpt-6.1-terra medium | 57% (4/7) [40%, 100%] | 0% (0/14) [0%, 0%] | 11% (1/9) [0%, 13%] | 0% (0/24) [0%, 0%] | 0% (0/12) [0%, 0%] | 14% (1/7) [0%, 33%] | 67% (2/3) [67%, 67%] |
| gpt-6.1-terra off | 100% (2/2) [100%, 100%] | 0% (0/1) [0%, 0%] | 0% (0/1) [0%, 0%] | 0% (0/1) [0%, 0%] | 0% (0/5) [0%, 0%] | 0% (0/2) [0%, 0%] | 100% (1/1) [100%, 100%] |
| gpt-6.1-terra xhigh | 50% (1/2) [50%, 50%] | 0% (0/2) [0%, 0%] | 0% (0/1) [0%, 0%] | 0% (0/1) [0%, 0%] | 100% (1/1) [100%, 100%] | 100% (2/2) [100%, 100%] | – |

### Haiku 4.5 efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 7.1% (12/169) [3.4%, 13%] | 1.0% (3/286) [0%, 2.5%] | 20% (34/174) [15%, 25%] | 3.2% (9/283) [1.1%, 5.9%] | 3.9% (14/361) [1.8%, 6.4%] | 5.7% (15/264) [3.2%, 9.3%] | 34% (37/109) [27%, 42%] |
| claude-haiku-4-5-20251001 low | 14% (16/116) [8.3%, 21%] | 1.3% (4/306) [0.3%, 2.8%] | 16% (31/188) [12%, 22%] | 1.8% (5/281) [0.3%, 3.9%] | 4.0% (15/379) [1.9%, 6.4%] | 3.2% (9/277) [1.5%, 5.4%] | 20% (29/142) [13%, 29%] |
| claude-haiku-4-5-20251001 medium | 7.8% (13/166) [3.9%, 12%] | 0.7% (3/405) [0%, 1.6%] | 10% (23/226) [5.5%, 17%] | 3.0% (10/334) [1.4%, 4.8%] | 2.4% (9/369) [1.1%, 4.3%] | 3.4% (12/352) [1.5%, 6.2%] | 32% (47/147) [24%, 42%] |
| claude-haiku-4-5-20251001 minimal | 7.6% (9/119) [2.8%, 15%] | 0.6% (2/328) [0%, 1.6%] | 15% (25/168) [9.0%, 22%] | 3.7% (11/299) [1.6%, 6.1%] | 4.1% (15/365) [2.4%, 6.7%] | 4.4% (13/297) [1.9%, 7.8%] | 27% (39/145) [19%, 37%] |
| claude-haiku-4-5-20251001 off | 8.7% (16/184) [4.8%, 14%] | 0.6% (2/312) [0%, 1.6%] | 9.7% (24/247) [5.9%, 14%] | 2.3% (8/343) [1.0%, 4.2%] | 1.9% (9/469) [0.8%, 3.4%] | 1.1% (4/360) [0%, 2.7%] | 17% (29/169) [11%, 26%] |

### Haiku 5.5 efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-5-5 high | 30% (38/126) [21%, 42%] | 8.4% (14/166) [4.0%, 14%] | 28% (47/165) [23%, 36%] | 9.3% (17/183) [5.2%, 15%] | 11% (29/259) [7.4%, 16%] | 13% (26/203) [7.8%, 19%] | 38% (37/98) [30%, 48%] |
| claude-haiku-5-5 low | 31% (37/118) [23%, 41%] | 5.3% (10/190) [2.9%, 7.9%] | 23% (34/147) [18%, 29%] | 11% (23/215) [6.8%, 15%] | 6.1% (16/262) [3.4%, 9.5%] | 9.4% (19/202) [5.4%, 14%] | 41% (39/94) [32%, 53%] |
| claude-haiku-5-5 max | 36% (39/108) [27%, 49%] | 8.2% (14/171) [4.5%, 13%] | 26% (37/141) [21%, 32%] | 7.6% (14/184) [3.8%, 12%] | 11% (25/237) [7.1%, 15%] | 21% (37/178) [14%, 29%] | 38% (36/96) [29%, 49%] |
| claude-haiku-5-5 medium | 31% (35/112) [21%, 45%] | 8.1% (17/211) [5.2%, 11%] | 27% (46/170) [21%, 35%] | 9.6% (19/197) [5.7%, 15%] | 8.1% (25/310) [5.4%, 11%] | 10% (22/212) [6.4%, 15%] | 33% (35/107) [25%, 42%] |
| claude-haiku-5-5 off | 30% (28/94) [21%, 40%] | 8.4% (14/166) [4.7%, 13%] | 39% (35/90) [29%, 51%] | 15% (17/110) [9.3%, 22%] | 9.9% (24/243) [5.8%, 15%] | 11% (20/182) [6.5%, 16%] | 27% (26/95) [17%, 42%] |
| claude-haiku-5-5 xhigh | 41% (45/111) [31%, 52%] | 7.5% (11/147) [3.6%, 13%] | 25% (36/146) [20%, 30%] | 5.8% (9/156) [2.0%, 10%] | 8.9% (19/214) [5.4%, 13%] | 23% (37/160) [16%, 31%] | 47% (36/76) [36%, 60%] |

### Luna efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6-luna high | 42% (52/125) [33%, 51%] | 2.4% (6/246) [0.5%, 5.0%] | 16% (38/235) [13%, 20%] | 16% (42/263) [12%, 21%] | 3.1% (11/355) [1.5%, 5.2%] | 6.6% (17/258) [3.9%, 9.7%] | 48% (59/123) [40%, 57%] |
| gpt-6-luna low | 18% (28/159) [12%, 24%] | 8.5% (20/236) [5.5%, 12%] | 12% (32/263) [8.8%, 16%] | 7.2% (17/237) [4.5%, 10%] | 12% (40/337) [8.2%, 16%] | 7.8% (24/308) [5.3%, 11%] | 47% (45/95) [38%, 58%] |
| gpt-6-luna max | 28% (34/121) [21%, 36%] | 11% (24/210) [7.9%, 15%] | 22% (41/189) [17%, 26%] | 13% (26/207) [7.6%, 18%] | 7.7% (24/312) [5.6%, 10%] | 17% (33/198) [12%, 22%] | 62% (48/77) [52%, 73%] |
| gpt-6-luna medium | 16% (29/186) [11%, 21%] | 4.4% (10/228) [2.1%, 7.0%] | 12% (30/258) [8.1%, 15%] | 10% (25/241) [6.2%, 15%] | 4.9% (19/388) [2.6%, 7.6%] | 6.9% (20/291) [4.1%, 10%] | 45% (53/119) [35%, 57%] |
| gpt-6-luna off | 26% (36/137) [20%, 34%] | 3.7% (7/189) [1.1%, 7.1%] | 13% (25/194) [8.6%, 18%] | 7.5% (20/266) [4.4%, 12%] | 14% (49/340) [11%, 19%] | 8.6% (23/267) [5.2%, 13%] | 41% (33/80) [33%, 51%] |
| gpt-6-luna xhigh | 38% (39/103) [31%, 46%] | 11% (26/235) [6.2%, 17%] | 14% (30/218) [10.0%, 18%] | 8.2% (18/220) [4.9%, 12%] | 4.4% (15/343) [2.3%, 6.7%] | 16% (35/215) [11%, 23%] | 58% (40/69) [44%, 77%] |

### Opus efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-opus-5-5 high | 43% (20/47) [29%, 67%] | 4.8% (4/83) [1.1%, 10%] | 19% (17/91) [14%, 24%] | 12% (14/113) [6.3%, 21%] | 8.3% (9/108) [2.9%, 16%] | 23% (18/77) [16%, 33%] | 54% (14/26) [36%, 74%] |
| claude-opus-5-5 low | 30% (9/30) [19%, 53%] | 1.5% (1/67) [0%, 7.5%] | 30% (15/50) [24%, 39%] | 6.1% (6/99) [1.6%, 11%] | 8.5% (8/94) [4.3%, 15%] | 10% (6/60) [2.3%, 19%] | 41% (9/22) [19%, 65%] |
| claude-opus-5-5 max | 40% (2/5) [33%, 50%] | 50% (1/2) [50%, 50%] | – | 28% (5/18) [23%, 40%] | 9.5% (2/21) [0%, 67%] | 0% (0/5) [0%, 0%] | 43% (3/7) [33%, 50%] |
| claude-opus-5-5 medium | 27% (28/103) [20%, 37%] | 5.4% (8/148) [1.9%, 11%] | 21% (27/127) [16%, 28%] | 8.1% (13/161) [4.3%, 13%] | 8.9% (20/225) [5.7%, 12%] | 17% (24/144) [12%, 22%] | 49% (25/51) [33%, 70%] |
| claude-opus-5-5 off | 100% (1/1) [100%, 100%] | 0% (0/9) [0%, 0%] | 25% (2/8) [20%, 33%] | 0% (0/7) [0%, 0%] | 25% (1/4) [0%, 33%] | 0% (0/5) [0%, 0%] | 33% (2/6) [25%, 50%] |
| claude-opus-5-5 xhigh | 26% (12/46) [14%, 43%] | 5.8% (6/104) [1.2%, 11%] | 24% (17/71) [19%, 30%] | 9.2% (7/76) [3.2%, 21%] | 6.4% (7/110) [2.3%, 12%] | 27% (21/78) [20%, 36%] | 52% (13/25) [37%, 78%] |

### Sol efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6.1-sol high | 20% (26/127) [14%, 28%] | 4.1% (6/146) [1.0%, 8.3%] | 27% (33/124) [21%, 35%] | 10% (17/162) [6.9%, 16%] | 8.3% (20/242) [4.2%, 14%] | 19% (24/124) [12%, 28%] | 43% (34/80) [33%, 56%] |
| gpt-6.1-sol low | 26% (24/91) [18%, 39%] | 2.2% (3/139) [0%, 5.7%] | 28% (32/114) [23%, 35%] | 5.0% (8/161) [1.9%, 9.8%] | 8.0% (16/201) [4.3%, 13%] | 21% (28/132) [14%, 30%] | 62% (32/52) [49%, 77%] |
| gpt-6.1-sol max | 24% (28/117) [17%, 32%] | 1.8% (3/169) [0%, 3.8%] | 19% (31/167) [15%, 23%] | 9.1% (20/220) [5.3%, 14%] | 9.1% (22/241) [5.9%, 13%] | 16% (26/160) [11%, 23%] | 39% (37/96) [29%, 49%] |
| gpt-6.1-sol medium | 24% (23/95) [17%, 35%] | 5.1% (7/138) [1.4%, 10%] | 23% (34/149) [18%, 28%] | 6.1% (11/180) [3.2%, 9.7%] | 8.6% (20/233) [4.9%, 13%] | 13% (16/128) [6.3%, 21%] | 64% (35/55) [52%, 78%] |
| gpt-6.1-sol xhigh | 29% (32/109) [20%, 42%] | 2.4% (4/165) [0%, 5.9%] | 20% (36/184) [16%, 23%] | 11% (21/197) [7.0%, 16%] | 8.0% (20/249) [5.5%, 11%] | 15% (24/163) [9.5%, 21%] | 42% (31/74) [33%, 52%] |

### Sonnet efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-sonnet-5-5 high | 24% (34/140) [18%, 34%] | 4.7% (10/215) [1.9%, 7.8%] | 19% (44/237) [15%, 22%] | 4.1% (9/218) [1.5%, 7.8%] | 3.3% (13/391) [1.5%, 5.4%] | 6.8% (16/236) [3.4%, 10%] | 40% (38/94) [34%, 49%] |
| claude-sonnet-5-5 low | 32% (45/139) [24%, 44%] | 0.4% (1/257) [0%, 1.2%] | 17% (42/245) [13%, 22%] | 3.4% (9/265) [1.5%, 5.9%] | 2.7% (12/448) [1.4%, 4.0%] | 3.7% (9/246) [1.4%, 6.4%] | 23% (34/149) [16%, 32%] |
| claude-sonnet-5-5 max | 24% (39/161) [18%, 33%] | 3.7% (10/270) [1.7%, 6.0%] | 17% (39/234) [13%, 21%] | 4.2% (11/261) [1.8%, 7.4%] | 8.6% (31/361) [5.6%, 12%] | 19% (48/258) [14%, 24%] | 22% (31/140) [16%, 30%] |
| claude-sonnet-5-5 medium | 24% (47/196) [16%, 33%] | 1.0% (3/303) [0%, 2.3%] | 18% (46/260) [14%, 21%] | 4.7% (15/320) [2.7%, 7.3%] | 2.8% (14/494) [1.5%, 4.5%] | 3.1% (9/294) [1.2%, 5.5%] | 30% (43/143) [22%, 39%] |
| claude-sonnet-5-5 off | 26% (51/194) [21%, 34%] | 2.3% (5/217) [0%, 5.4%] | 15% (31/201) [12%, 20%] | 6.4% (20/313) [3.8%, 9.3%] | 3.0% (15/497) [1.5%, 4.7%] | 4.3% (12/276) [2.0%, 7.4%] | 32% (37/116) [24%, 41%] |
| claude-sonnet-5-5 xhigh | 28% (36/129) [21%, 38%] | 4.2% (11/263) [1.9%, 7.1%] | 15% (32/214) [11%, 19%] | 6.8% (18/265) [4.0%, 10%] | 7.8% (31/400) [4.7%, 11%] | 14% (35/252) [9.6%, 19%] | 34% (33/97) [26%, 43%] |

### Terra 6.1 efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6.1-terra high | 50% (1/2) [0%, 100%] | 0% (0/2) [0%, 0%] | – | 25% (2/8) [0%, 40%] | 0% (0/6) [0%, 0%] | – | 67% (2/3) [67%, 67%] |
| gpt-6.1-terra low | 67% (4/6) [50%, 75%] | 4.8% (1/21) [0%, 13%] | 67% (4/6) [60%, 100%] | 0% (0/30) [0%, 0%] | 3.4% (1/29) [0%, 5.3%] | 8.3% (1/12) [0%, 33%] | 25% (3/12) [0%, 33%] |
| gpt-6.1-terra max | 0% (0/4) [0%, 0%] | 20% (1/5) [20%, 20%] | 29% (2/7) [29%, 29%] | 0% (0/1) [0%, 0%] | 0% (0/19) [0%, 0%] | 9.1% (1/11) [9.1%, 9.1%] | 100% (1/1) [100%, 100%] |
| gpt-6.1-terra medium | 80% (4/5) [25%, 100%] | 3.4% (1/29) [0%, 11%] | 33% (4/12) [0%, 60%] | 6.3% (3/48) [0%, 19%] | 6.1% (2/33) [0%, 7.1%] | 6.3% (1/16) [0%, 6.7%] | 25% (3/12) [25%, 25%] |
| gpt-6.1-terra off | 50% (4/8) [33%, 60%] | 25% (2/8) [0%, 29%] | 22% (2/9) [20%, 25%] | 13% (1/8) [13%, 13%] | 0% (0/4) [0%, 0%] | 25% (1/4) [25%, 25%] | 100% (2/2) [100%, 100%] |
| gpt-6.1-terra xhigh | 50% (1/2) [0%, 100%] | 20% (3/15) [0%, 27%] | 33% (1/3) [33%, 33%] | 33% (3/9) [0%, 100%] | 0% (0/15) [0%, 0%] | 11% (2/19) [0%, 100%] | 100% (1/1) [100%, 100%] |

### Terra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-5.6-terra high | 34% (31/90) [24%, 47%] | 3.1% (7/227) [0.5%, 7.0%] | 33% (41/126) [26%, 41%] | 6.7% (12/178) [3.6%, 10%] | 7.5% (19/255) [4.3%, 11%] | 7.0% (14/200) [4.0%, 11%] | 74% (37/50) [62%, 87%] |
| gpt-5.6-terra low | 36% (36/101) [28%, 44%] | 2.2% (4/182) [0.5%, 4.9%] | 24% (29/122) [18%, 31%] | 7.7% (13/169) [3.3%, 13%] | 4.0% (12/302) [1.8%, 6.8%] | 4.3% (8/186) [1.4%, 8.1%] | 65% (34/52) [54%, 78%] |
| gpt-5.6-terra max | 30% (34/114) [22%, 42%] | 9.3% (18/193) [5.6%, 15%] | 29% (35/122) [22%, 35%] | 8.1% (15/185) [5.1%, 11%] | 7.0% (16/227) [4.1%, 11%] | 25% (41/167) [18%, 33%] | 64% (29/45) [52%, 79%] |
| gpt-5.6-terra medium | 35% (32/91) [27%, 45%] | 4.1% (7/170) [1.2%, 7.7%] | 26% (31/117) [21%, 33%] | 7.9% (18/228) [4.9%, 11%] | 2.7% (8/293) [1.0%, 4.8%] | 8.2% (14/170) [4.9%, 12%] | 68% (32/47) [57%, 81%] |
| gpt-5.6-terra xhigh | 33% (33/100) [25%, 45%] | 4.5% (11/242) [2.1%, 8.0%] | 28% (39/138) [22%, 35%] | 6.1% (10/163) [2.8%, 9.9%] | 6.2% (19/306) [3.2%, 10.0%] | 12% (25/206) [7.8%, 17%] | 64% (37/58) [52%, 76%] |

## Item fates by item

Share of placed items used by their owner, by item. Adrenaline counts as used when its owner steals with it.

### Cross-model

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 54% (14/26) [42%, 66%] | 39% (13/33) [31%, 55%] | 46% (13/28) [37%, 65%] | 44% (12/27) [34%, 57%] | 19% (6/31) [3.4%, 34%] | 60% (12/20) [43%, 75%] | 50% (8/16) [15%, 67%] | 30% (8/27) [12%, 57%] |
| claude-haiku-4-5-20251001 low | 70% (16/23) [53%, 83%] | 55% (17/31) [38%, 74%] | 58% (19/33) [41%, 70%] | 45% (15/33) [19%, 74%] | 37% (10/27) [24%, 48%] | 30% (7/23) [20%, 43%] | 47% (7/15) [31%, 70%] | 37% (10/27) [23%, 52%] |
| claude-haiku-4-5-20251001 medium | 70% (338/483) [66%, 74%] | 37% (209/560) [33%, 42%] | 57% (297/519) [53%, 62%] | 46% (278/610) [41%, 50%] | 32% (192/602) [28%, 36%] | 45% (190/419) [40%, 50%] | 58% (208/359) [53%, 63%] | 41% (210/512) [37%, 46%] |
| claude-haiku-4-5-20251001 minimal | 89% (24/27) [79%, 100%] | 47% (16/34) [27%, 74%] | 66% (21/32) [57%, 76%] | 59% (20/34) [41%, 84%] | 37% (11/30) [23%, 56%] | 44% (11/25) [20%, 62%] | 54% (13/24) [43%, 65%] | 44% (11/25) [32%, 59%] |
| claude-haiku-4-5-20251001 off | 65% (22/34) [46%, 78%] | 61% (14/23) [39%, 76%] | 48% (16/33) [37%, 64%] | 39% (14/36) [30%, 53%] | 45% (13/29) [14%, 69%] | 60% (15/25) [38%, 80%] | 56% (14/25) [42%, 71%] | 22% (7/32) [7.7%, 44%] |
| claude-haiku-5-5 high | 60% (15/25) [50%, 86%] | 63% (26/41) [54%, 73%] | 39% (11/28) [19%, 62%] | 55% (23/42) [38%, 77%] | 46% (19/41) [26%, 67%] | 52% (12/23) [29%, 79%] | 58% (15/26) [37%, 83%] | 69% (22/32) [47%, 88%] |
| claude-haiku-5-5 low | 65% (24/37) [53%, 81%] | 51% (22/43) [38%, 66%] | 69% (25/36) [56%, 84%] | 57% (23/40) [42%, 67%] | 34% (16/47) [24%, 45%] | 71% (24/34) [58%, 79%] | 68% (17/25) [57%, 80%] | 59% (19/32) [42%, 71%] |
| claude-haiku-5-5 max | 67% (18/27) [48%, 87%] | 75% (21/28) [55%, 89%] | 57% (16/28) [45%, 75%] | 54% (15/28) [33%, 68%] | 40% (10/25) [29%, 48%] | 63% (17/27) [45%, 78%] | 76% (13/17) [61%, 92%] | 64% (23/36) [51%, 76%] |
| claude-haiku-5-5 medium | 68% (360/532) [64%, 71%] | 56% (334/597) [51%, 61%] | 61% (328/541) [57%, 64%] | 57% (341/602) [53%, 61%] | 39% (237/613) [35%, 42%] | 57% (257/450) [53%, 61%] | 64% (249/391) [59%, 68%] | 61% (316/521) [56%, 65%] |
| claude-haiku-5-5 off | 48% (13/27) [40%, 54%] | 61% (23/38) [26%, 92%] | 67% (22/33) [56%, 75%] | 43% (13/30) [34%, 52%] | 21% (5/24) [6.7%, 37%] | 50% (11/22) [33%, 75%] | 44% (11/25) [26%, 65%] | 55% (21/38) [30%, 78%] |
| claude-haiku-5-5 xhigh | 58% (15/26) [45%, 77%] | 53% (19/36) [32%, 71%] | 42% (10/24) [30%, 59%] | 44% (15/34) [33%, 53%] | 44% (15/34) [36%, 53%] | 50% (11/22) [43%, 56%] | 65% (13/20) [57%, 77%] | 60% (18/30) [38%, 76%] |
| claude-opus-5-5 high | 65% (22/34) [58%, 73%] | 70% (16/23) [64%, 76%] | 59% (17/29) [46%, 71%] | 38% (12/32) [17%, 55%] | 32% (9/28) [24%, 39%] | 70% (16/23) [53%, 86%] | 62% (13/21) [48%, 74%] | 60% (18/30) [37%, 89%] |
| claude-opus-5-5 low | 70% (21/30) [59%, 89%] | 57% (12/21) [24%, 86%] | 67% (16/24) [48%, 94%] | 31% (11/35) [13%, 46%] | 32% (11/34) [15%, 50%] | 58% (11/19) [43%, 77%] | 71% (10/14) [56%, 92%] | 55% (16/29) [46%, 68%] |
| claude-opus-5-5 max | 100% (8/8) [100%, 100%] | 83% (5/6) [75%, 100%] | 64% (9/14) [50%, 75%] | 54% (7/13) [50%, 56%] | 25% (3/12) [0%, 38%] | 58% (7/12) [40%, 71%] | 83% (5/6) [67%, 100%] | 70% (7/10) [33%, 86%] |
| claude-opus-5-5 medium | 69% (362/528) [65%, 73%] | 58% (348/599) [53%, 63%] | 57% (323/566) [53%, 61%] | 49% (332/677) [45%, 53%] | 40% (240/598) [37%, 44%] | 65% (312/481) [61%, 69%] | 66% (242/366) [61%, 71%] | 58% (302/518) [54%, 62%] |
| claude-opus-5-5 off | 82% (9/11) [71%, 100%] | 67% (8/12) [60%, 71%] | 63% (10/16) [57%, 67%] | 47% (9/19) [33%, 54%] | 43% (6/14) [33%, 45%] | 70% (7/10) [50%, 83%] | 71% (5/7) [33%, 100%] | 71% (12/17) [38%, 100%] |
| claude-opus-5-5 xhigh | 60% (70/116) [50%, 70%] | 66% (82/125) [58%, 74%] | 52% (73/141) [45%, 59%] | 54% (72/133) [46%, 62%] | 40% (54/135) [31%, 48%] | 64% (63/99) [52%, 74%] | 63% (53/84) [55%, 71%] | 65% (80/123) [56%, 73%] |
| claude-sonnet-5-5 high | 72% (18/25) [62%, 79%] | 59% (20/34) [38%, 79%] | 65% (20/31) [39%, 93%] | 50% (21/42) [30%, 63%] | 30% (12/40) [14%, 46%] | 61% (22/36) [40%, 78%] | 78% (18/23) [61%, 91%] | 52% (13/25) [28%, 77%] |
| claude-sonnet-5-5 low | 64% (18/28) [48%, 85%] | 60% (30/50) [39%, 84%] | 48% (14/29) [30%, 61%] | 41% (17/41) [31%, 55%] | 13% (5/40) [5.4%, 18%] | 69% (24/35) [51%, 86%] | 71% (20/28) [60%, 83%] | 63% (22/35) [45%, 79%] |
| claude-sonnet-5-5 max | 65% (13/20) [40%, 80%] | 55% (22/40) [41%, 69%] | 67% (18/27) [52%, 86%] | 45% (17/38) [17%, 57%] | 45% (14/31) [20%, 61%] | 68% (15/22) [36%, 86%] | 57% (12/21) [32%, 78%] | 68% (15/22) [56%, 92%] |
| claude-sonnet-5-5 medium | 74% (369/497) [70%, 78%] | 54% (302/559) [50%, 58%] | 56% (293/520) [53%, 60%] | 49% (317/645) [44%, 54%] | 25% (142/573) [21%, 29%] | 66% (287/436) [61%, 70%] | 64% (216/336) [59%, 69%] | 49% (270/550) [44%, 54%] |
| claude-sonnet-5-5 off | 77% (23/30) [68%, 91%] | 49% (19/39) [34%, 63%] | 48% (22/46) [38%, 58%] | 54% (31/57) [35%, 72%] | 22% (10/45) [12%, 34%] | 65% (22/34) [52%, 76%] | 61% (11/18) [31%, 86%] | 50% (20/40) [40%, 58%] |
| claude-sonnet-5-5 xhigh | 63% (19/30) [43%, 83%] | 67% (16/24) [43%, 84%] | 58% (18/31) [38%, 79%] | 64% (27/42) [46%, 79%] | 30% (14/47) [21%, 41%] | 62% (13/21) [52%, 77%] | 65% (17/26) [50%, 81%] | 63% (26/41) [48%, 83%] |
| gpt-5.6-terra high | 71% (25/35) [53%, 88%] | 31% (11/36) [19%, 43%] | 72% (18/25) [61%, 86%] | 51% (18/35) [37%, 67%] | 32% (10/31) [11%, 43%] | 50% (12/24) [35%, 64%] | 67% (14/21) [53%, 86%] | 52% (16/31) [33%, 72%] |
| gpt-5.6-terra low | 80% (24/30) [74%, 93%] | 44% (11/25) [16%, 67%] | 53% (23/43) [43%, 64%] | 51% (18/35) [41%, 61%] | 23% (6/26) [10%, 31%] | 41% (12/29) [13%, 69%] | 82% (18/22) [71%, 95%] | 50% (18/36) [32%, 69%] |
| gpt-5.6-terra max | 86% (25/29) [69%, 100%] | 78% (25/32) [60%, 91%] | 79% (23/29) [72%, 88%] | 55% (21/38) [38%, 71%] | 51% (23/45) [35%, 69%] | 73% (16/22) [52%, 91%] | 59% (13/22) [44%, 79%] | 73% (24/33) [59%, 89%] |
| gpt-5.6-terra medium | 74% (403/542) [70%, 78%] | 39% (216/553) [33%, 45%] | 64% (297/462) [60%, 68%] | 45% (240/539) [39%, 50%] | 28% (164/588) [23%, 33%] | 45% (180/399) [40%, 50%] | 72% (261/362) [68%, 76%] | 62% (314/508) [58%, 66%] |
| gpt-5.6-terra xhigh | 79% (26/33) [61%, 96%] | 56% (19/34) [41%, 77%] | 59% (24/41) [47%, 68%] | 71% (22/31) [59%, 86%] | 47% (15/32) [37%, 62%] | 65% (22/34) [53%, 71%] | 68% (17/25) [57%, 84%] | 63% (17/27) [48%, 80%] |
| gpt-6-astra high | 59% (10/17) [50%, 67%] | 65% (11/17) [60%, 71%] | 50% (8/16) [38%, 63%] | 46% (6/13) [29%, 67%] | 38% (3/8) [33%, 50%] | 43% (3/7) [0%, 60%] | 82% (9/11) [60%, 100%] | 58% (11/19) [56%, 60%] |
| gpt-6-astra low | 73% (11/15) [50%, 100%] | 67% (8/12) [61%, 83%] | 56% (14/25) [45%, 67%] | 46% (11/24) [19%, 100%] | 36% (8/22) [14%, 57%] | 67% (10/15) [54%, 83%] | 78% (7/9) [75%, 100%] | 44% (8/18) [29%, 72%] |
| gpt-6-astra medium | 71% (419/589) [68%, 75%] | 64% (449/700) [60%, 68%] | 59% (418/706) [56%, 63%] | 38% (294/780) [33%, 42%] | 35% (237/681) [32%, 38%] | 62% (315/511) [57%, 66%] | 65% (264/409) [60%, 69%] | 65% (404/624) [61%, 69%] |
| gpt-6-luna high | 79% (23/29) [62%, 93%] | 53% (21/40) [42%, 60%] | 63% (17/27) [50%, 76%] | 57% (23/40) [40%, 71%] | 23% (9/39) [12%, 30%] | 61% (14/23) [45%, 71%] | 61% (11/18) [32%, 94%] | 42% (14/33) [16%, 79%] |
| gpt-6-luna low | 77% (20/26) [55%, 95%] | 84% (21/25) [72%, 94%] | 67% (18/27) [53%, 76%] | 71% (22/31) [56%, 87%] | 64% (21/33) [39%, 88%] | 57% (13/23) [35%, 72%] | 76% (13/17) [59%, 94%] | 74% (20/27) [61%, 94%] |
| gpt-6-luna max | 69% (18/26) [38%, 95%] | 51% (23/45) [41%, 62%] | 62% (18/29) [46%, 90%] | 57% (23/40) [34%, 73%] | 28% (11/39) [10%, 51%] | 58% (14/24) [43%, 76%] | 82% (14/17) [58%, 95%] | 65% (17/26) [50%, 77%] |
| gpt-6-luna medium | 76% (394/520) [72%, 80%] | 65% (381/585) [61%, 69%] | 66% (352/534) [62%, 70%] | 63% (381/606) [59%, 67%] | 44% (256/578) [39%, 50%] | 59% (254/431) [54%, 64%] | 68% (232/341) [63%, 73%] | 57% (289/504) [52%, 63%] |
| gpt-6-luna off | 78% (21/27) [66%, 95%] | 83% (24/29) [70%, 94%] | 60% (15/25) [45%, 75%] | 65% (17/26) [35%, 87%] | 76% (26/34) [60%, 86%] | 61% (14/23) [50%, 76%] | 65% (20/31) [47%, 88%] | 57% (21/37) [44%, 75%] |
| gpt-6-luna xhigh | 85% (23/27) [74%, 96%] | 62% (23/37) [36%, 79%] | 59% (24/41) [45%, 65%] | 60% (25/42) [29%, 82%] | 44% (22/50) [30%, 63%] | 74% (26/35) [67%, 85%] | 74% (20/27) [65%, 86%] | 73% (29/40) [63%, 79%] |
| gpt-6.1-sol high | 67% (18/27) [47%, 82%] | 57% (20/35) [41%, 71%] | 70% (23/33) [60%, 78%] | 40% (14/35) [8.3%, 75%] | 41% (13/32) [18%, 67%] | 63% (15/24) [48%, 76%] | 68% (15/22) [45%, 81%] | 70% (16/23) [56%, 85%] |
| gpt-6.1-sol low | 68% (17/25) [52%, 94%] | 65% (15/23) [29%, 91%] | 69% (18/26) [55%, 83%] | 38% (12/32) [21%, 54%] | 23% (7/31) [8.3%, 38%] | 67% (14/21) [38%, 85%] | 75% (12/16) [40%, 95%] | 76% (26/34) [68%, 88%] |
| gpt-6.1-sol max | 68% (23/34) [48%, 86%] | 58% (22/38) [50%, 70%] | 57% (21/37) [47%, 67%] | 45% (18/40) [26%, 60%] | 49% (22/45) [37%, 65%] | 70% (23/33) [56%, 84%] | 68% (17/25) [48%, 88%] | 71% (29/41) [62%, 79%] |
| gpt-6.1-sol medium | 70% (358/513) [65%, 74%] | 61% (364/600) [56%, 65%] | 59% (348/586) [56%, 64%] | 41% (246/604) [37%, 45%] | 37% (228/609) [34%, 41%] | 64% (300/466) [60%, 69%] | 65% (254/389) [61%, 70%] | 64% (350/543) [60%, 68%] |
| gpt-6.1-sol xhigh | 65% (22/34) [55%, 85%] | 74% (40/54) [62%, 85%] | 59% (29/49) [52%, 68%] | 65% (45/69) [54%, 73%] | 45% (21/47) [28%, 61%] | 69% (22/32) [47%, 85%] | 74% (17/23) [59%, 92%] | 66% (19/29) [48%, 83%] |
| gpt-6.1-terra high | 50% (3/6) [0%, 60%] | 64% (9/14) [63%, 67%] | 60% (6/10) [60%, 60%] | 24% (4/17) [17%, 27%] | 44% (7/16) [38%, 50%] | 56% (5/9) [50%, 67%] | 63% (5/8) [50%, 100%] | 57% (8/14) [50%, 67%] |
| gpt-6.1-terra low | 86% (6/7) [86%, 86%] | 60% (3/5) [60%, 60%] | 50% (3/6) [50%, 50%] | 17% (1/6) [17%, 17%] | 40% (4/10) [40%, 40%] | 71% (5/7) [71%, 71%] | 80% (4/5) [80%, 80%] | 86% (6/7) [86%, 86%] |
| gpt-6.1-terra max | 60% (6/10) [60%, 60%] | 89% (8/9) [89%, 89%] | 50% (2/4) [50%, 50%] | 50% (6/12) [50%, 50%] | 11% (1/9) [11%, 11%] | 83% (5/6) [83%, 83%] | 67% (2/3) [67%, 67%] | 78% (7/9) [78%, 78%] |
| gpt-6.1-terra medium | 82% (9/11) [60%, 100%] | 81% (13/16) [67%, 100%] | 40% (4/10) [0%, 67%] | 30% (6/20) [13%, 42%] | 47% (7/15) [38%, 57%] | 85% (11/13) [80%, 88%] | 67% (6/9) [50%, 100%] | 53% (8/15) [45%, 75%] |
| gpt-6.1-terra off | 57% (4/7) [57%, 57%] | 100% (4/4) [100%, 100%] | 100% (5/5) [100%, 100%] | 11% (1/9) [11%, 11%] | 0% (0/4) [0%, 0%] | 33% (1/3) [33%, 33%] | 80% (4/5) [80%, 80%] | 75% (3/4) [75%, 75%] |
| gpt-6.1-terra xhigh | 100% (6/6) [100%, 100%] | 100% (7/7) [100%, 100%] | 80% (4/5) [80%, 80%] | 50% (6/12) [50%, 50%] | 33% (2/6) [33%, 33%] | 33% (1/3) [33%, 33%] | 100% (3/3) [100%, 100%] | 67% (4/6) [67%, 67%] |

### Haiku 4.5 efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 78% (202/260) [72%, 83%] | 34% (85/252) [28%, 40%] | 61% (154/252) [55%, 68%] | 47% (141/297) [40%, 55%] | 37% (112/303) [31%, 43%] | 58% (119/205) [50%, 65%] | 55% (103/187) [49%, 61%] | 50% (124/248) [44%, 57%] |
| claude-haiku-4-5-20251001 low | 83% (201/242) [79%, 87%] | 42% (120/288) [35%, 48%] | 65% (170/262) [59%, 71%] | 49% (132/269) [42%, 56%] | 37% (104/282) [32%, 42%] | 58% (116/200) [51%, 64%] | 53% (95/180) [43%, 61%] | 43% (109/252) [38%, 49%] |
| claude-haiku-4-5-20251001 medium | 82% (220/269) [76%, 87%] | 34% (84/247) [28%, 41%] | 63% (177/282) [57%, 68%] | 47% (126/268) [40%, 54%] | 39% (122/316) [32%, 45%] | 60% (121/203) [54%, 65%] | 54% (96/177) [46%, 63%] | 43% (117/273) [37%, 50%] |
| claude-haiku-4-5-20251001 minimal | 85% (197/232) [80%, 89%] | 45% (120/264) [38%, 52%] | 58% (166/284) [54%, 63%] | 46% (121/265) [40%, 52%] | 42% (122/292) [35%, 49%] | 50% (100/202) [43%, 56%] | 53% (77/146) [44%, 62%] | 47% (114/241) [40%, 55%] |
| claude-haiku-4-5-20251001 off | 84% (222/263) [79%, 89%] | 62% (171/274) [56%, 69%] | 58% (145/250) [51%, 64%] | 48% (130/273) [41%, 54%] | 52% (153/293) [43%, 61%] | 56% (118/209) [49%, 64%] | 48% (80/166) [41%, 55%] | 34% (92/272) [28%, 41%] |

### Haiku 5.5 efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| claude-haiku-5-5 high | 73% (199/273) [68%, 78%] | 60% (185/308) [53%, 67%] | 56% (156/279) [51%, 62%] | 50% (148/298) [44%, 56%] | 43% (131/306) [38%, 48%] | 57% (159/277) [53%, 62%] | 69% (146/212) [64%, 74%] | 66% (208/313) [62%, 71%] |
| claude-haiku-5-5 low | 71% (220/308) [66%, 77%] | 55% (176/319) [49%, 62%] | 60% (178/299) [55%, 64%] | 59% (181/306) [54%, 65%] | 34% (107/315) [29%, 39%] | 58% (171/293) [52%, 64%] | 65% (141/216) [60%, 70%] | 61% (178/291) [55%, 67%] |
| claude-haiku-5-5 max | 71% (211/296) [67%, 76%] | 62% (187/304) [56%, 66%] | 55% (160/290) [49%, 61%] | 50% (161/321) [44%, 56%] | 49% (153/313) [43%, 55%] | 66% (159/241) [60%, 71%] | 62% (130/211) [57%, 67%] | 65% (202/311) [59%, 71%] |
| claude-haiku-5-5 medium | 74% (244/330) [70%, 78%] | 59% (177/302) [52%, 65%] | 64% (170/266) [58%, 70%] | 50% (164/325) [44%, 57%] | 42% (136/321) [36%, 48%] | 61% (173/282) [56%, 66%] | 65% (120/186) [58%, 71%] | 65% (199/304) [60%, 72%] |
| claude-haiku-5-5 off | 75% (229/306) [69%, 80%] | 67% (200/299) [61%, 73%] | 64% (201/313) [59%, 69%] | 65% (197/305) [59%, 70%] | 25% (80/326) [20%, 29%] | 54% (141/260) [48%, 60%] | 52% (102/195) [46%, 59%] | 58% (164/284) [52%, 64%] |
| claude-haiku-5-5 xhigh | 73% (200/275) [67%, 78%] | 58% (185/320) [52%, 64%] | 54% (156/290) [48%, 59%] | 49% (164/338) [43%, 54%] | 43% (148/348) [36%, 49%] | 60% (157/263) [54%, 65%] | 62% (131/211) [57%, 68%] | 62% (193/310) [57%, 67%] |

### Luna efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| gpt-6-luna high | 78% (250/321) [74%, 82%] | 57% (186/329) [51%, 62%] | 67% (211/317) [62%, 72%] | 64% (240/374) [60%, 68%] | 28% (105/377) [23%, 32%] | 66% (177/267) [60%, 73%] | 70% (132/189) [64%, 76%] | 64% (225/350) [59%, 70%] |
| gpt-6-luna low | 72% (225/313) [67%, 77%] | 78% (259/332) [73%, 82%] | 66% (212/319) [61%, 73%] | 61% (213/351) [55%, 67%] | 73% (265/364) [68%, 78%] | 63% (167/265) [57%, 69%] | 64% (152/237) [59%, 70%] | 62% (206/332) [57%, 68%] |
| gpt-6-luna max | 74% (239/321) [69%, 80%] | 69% (198/287) [64%, 74%] | 68% (206/305) [62%, 72%] | 65% (233/360) [58%, 70%] | 44% (156/354) [39%, 49%] | 68% (180/266) [61%, 73%] | 71% (163/228) [66%, 76%] | 73% (230/317) [67%, 78%] |
| gpt-6-luna medium | 76% (253/333) [71%, 80%] | 66% (232/350) [60%, 72%] | 67% (215/320) [63%, 71%] | 62% (221/356) [57%, 68%] | 48% (179/370) [42%, 54%] | 58% (148/254) [53%, 64%] | 65% (152/233) [60%, 70%] | 58% (186/319) [52%, 65%] |
| gpt-6-luna off | 73% (217/296) [68%, 79%] | 71% (252/353) [68%, 75%] | 67% (236/353) [62%, 71%] | 64% (218/343) [58%, 70%] | 73% (254/346) [69%, 78%] | 61% (167/274) [56%, 66%] | 63% (154/243) [59%, 68%] | 68% (193/285) [62%, 73%] |
| gpt-6-luna xhigh | 74% (231/312) [68%, 80%] | 60% (195/323) [54%, 67%] | 70% (202/290) [64%, 75%] | 65% (229/351) [60%, 70%] | 34% (113/331) [29%, 40%] | 69% (192/279) [63%, 74%] | 73% (159/218) [68%, 78%] | 61% (203/335) [55%, 67%] |

### Opus efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| claude-opus-5-5 high | 67% (72/108) [56%, 76%] | 63% (73/115) [55%, 73%] | 47% (52/111) [37%, 57%] | 47% (56/120) [35%, 57%] | 41% (52/127) [32%, 50%] | 54% (54/100) [44%, 63%] | 68% (51/75) [60%, 75%] | 73% (96/132) [66%, 80%] |
| claude-opus-5-5 low | 73% (56/77) [59%, 83%] | 45% (29/65) [37%, 54%] | 56% (34/61) [45%, 69%] | 39% (29/74) [30%, 51%] | 34% (24/71) [23%, 45%] | 65% (37/57) [51%, 81%] | 67% (33/49) [58%, 74%] | 66% (54/82) [57%, 76%] |
| claude-opus-5-5 max | 83% (10/12) [75%, 100%] | 60% (3/5) [33%, 100%] | 70% (7/10) [67%, 71%] | 44% (7/16) [33%, 50%] | 67% (4/6) [33%, 100%] | 60% (9/15) [50%, 67%] | 67% (4/6) [0%, 100%] | 76% (13/17) [71%, 80%] |
| claude-opus-5-5 medium | 71% (126/177) [65%, 77%] | 61% (113/185) [55%, 67%] | 51% (86/169) [44%, 60%] | 44% (94/215) [37%, 50%] | 39% (75/191) [34%, 45%] | 65% (103/158) [57%, 72%] | 62% (73/118) [56%, 68%] | 71% (145/203) [67%, 76%] |
| claude-opus-5-5 off | 67% (4/6) [50%, 75%] | 100% (4/4) [100%, 100%] | 60% (6/10) [50%, 75%] | 20% (2/10) [17%, 25%] | 50% (6/12) [40%, 57%] | 50% (5/10) [33%, 57%] | 44% (4/9) [33%, 50%] | 60% (6/10) [43%, 100%] |
| claude-opus-5-5 xhigh | 69% (82/118) [59%, 79%] | 71% (82/116) [63%, 78%] | 54% (54/100) [44%, 65%] | 42% (49/117) [30%, 55%] | 40% (50/124) [30%, 50%] | 62% (61/98) [51%, 72%] | 62% (52/84) [51%, 73%] | 74% (83/112) [67%, 81%] |

### Sol efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| gpt-6.1-sol high | 69% (161/232) [63%, 75%] | 69% (166/241) [62%, 75%] | 52% (115/222) [45%, 58%] | 40% (97/242) [34%, 47%] | 38% (89/236) [32%, 44%] | 60% (129/215) [54%, 66%] | 61% (95/156) [53%, 69%] | 63% (160/253) [57%, 69%] |
| gpt-6.1-sol low | 71% (171/241) [66%, 76%] | 57% (132/233) [48%, 66%] | 51% (109/215) [44%, 58%] | 33% (81/242) [27%, 40%] | 26% (64/243) [20%, 33%] | 66% (128/195) [59%, 71%] | 58% (95/163) [52%, 65%] | 62% (143/230) [56%, 68%] |
| gpt-6.1-sol max | 67% (155/232) [59%, 74%] | 66% (153/232) [60%, 72%] | 51% (117/228) [45%, 58%] | 55% (139/255) [48%, 62%] | 40% (108/273) [33%, 46%] | 67% (139/208) [59%, 74%] | 61% (107/176) [56%, 65%] | 65% (167/256) [60%, 71%] |
| gpt-6.1-sol medium | 66% (158/239) [59%, 73%] | 60% (149/247) [53%, 68%] | 53% (107/202) [45%, 61%] | 45% (102/228) [38%, 52%] | 33% (89/268) [27%, 40%] | 60% (122/203) [56%, 65%] | 61% (97/159) [54%, 68%] | 61% (146/238) [57%, 66%] |
| gpt-6.1-sol xhigh | 66% (152/229) [58%, 75%] | 72% (171/238) [66%, 78%] | 56% (115/206) [49%, 63%] | 49% (113/230) [41%, 57%] | 44% (106/242) [36%, 51%] | 62% (131/211) [55%, 69%] | 60% (90/151) [55%, 65%] | 63% (168/266) [58%, 68%] |

### Sonnet efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| claude-sonnet-5-5 high | 69% (205/296) [64%, 74%] | 66% (202/304) [61%, 71%] | 53% (142/269) [48%, 58%] | 51% (163/319) [44%, 59%] | 28% (92/324) [23%, 34%] | 65% (159/245) [59%, 71%] | 63% (139/222) [56%, 69%] | 59% (164/279) [53%, 64%] |
| claude-sonnet-5-5 low | 73% (217/299) [68%, 77%] | 55% (162/292) [49%, 62%] | 54% (139/257) [48%, 61%] | 48% (152/320) [41%, 53%] | 25% (78/312) [21%, 30%] | 63% (156/248) [57%, 68%] | 59% (107/181) [52%, 66%] | 49% (152/310) [44%, 55%] |
| claude-sonnet-5-5 max | 69% (216/313) [63%, 75%] | 64% (171/267) [57%, 70%] | 60% (178/295) [54%, 66%] | 50% (151/304) [44%, 55%] | 52% (187/357) [46%, 58%] | 71% (178/252) [65%, 76%] | 62% (113/181) [56%, 68%] | 66% (209/318) [61%, 70%] |
| claude-sonnet-5-5 medium | 71% (210/297) [64%, 77%] | 60% (176/292) [53%, 67%] | 57% (159/279) [51%, 63%] | 51% (167/327) [45%, 57%] | 26% (85/327) [22%, 30%] | 68% (180/264) [64%, 73%] | 67% (134/199) [61%, 73%] | 55% (177/322) [50%, 61%] |
| claude-sonnet-5-5 off | 73% (211/289) [68%, 78%] | 68% (210/310) [63%, 72%] | 46% (124/271) [41%, 52%] | 56% (157/282) [49%, 62%] | 23% (71/309) [18%, 28%] | 64% (169/263) [58%, 71%] | 66% (120/182) [59%, 72%] | 54% (171/314) [50%, 60%] |
| claude-sonnet-5-5 xhigh | 63% (176/279) [57%, 69%] | 70% (197/281) [65%, 76%] | 54% (144/267) [49%, 59%] | 55% (164/300) [49%, 60%] | 41% (137/335) [36%, 46%] | 64% (163/255) [58%, 69%] | 59% (120/205) [53%, 64%] | 64% (196/307) [59%, 69%] |

### Terra 6.1 efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| gpt-6.1-terra high | 70% (7/10) [50%, 83%] | 53% (8/15) [40%, 60%] | 67% (10/15) [50%, 100%] | 19% (3/16) [11%, 29%] | 20% (1/5) [0%, 50%] | 63% (5/8) [60%, 67%] | 78% (7/9) [75%, 80%] | 71% (5/7) [67%, 75%] |
| gpt-6.1-terra low | 75% (15/20) [56%, 91%] | 40% (8/20) [14%, 54%] | 50% (4/8) [33%, 60%] | 0% (0/6) [0%, 0%] | 14% (1/7) [0%, 50%] | 100% (7/7) [100%, 100%] | 63% (5/8) [50%, 75%] | 67% (14/21) [64%, 70%] |
| gpt-6.1-terra max | 83% (5/6) [83%, 83%] | 60% (6/10) [60%, 60%] | 50% (4/8) [50%, 50%] | 100% (4/4) [100%, 100%] | 50% (4/8) [50%, 50%] | 75% (6/8) [75%, 75%] | 83% (5/6) [83%, 83%] | 100% (5/5) [100%, 100%] |
| gpt-6.1-terra medium | 79% (19/24) [61%, 88%] | 63% (19/30) [32%, 87%] | 67% (12/18) [43%, 90%] | 12% (3/25) [4.3%, 22%] | 24% (4/17) [0%, 50%] | 67% (14/21) [56%, 78%] | 61% (11/18) [42%, 87%] | 58% (18/31) [50%, 71%] |
| gpt-6.1-terra off | 50% (5/10) [40%, 60%] | 50% (5/10) [20%, 80%] | 50% (6/12) [40%, 57%] | 22% (4/18) [10%, 38%] | 29% (4/14) [20%, 33%] | 83% (5/6) [75%, 100%] | 50% (3/6) [25%, 100%] | 86% (12/14) [80%, 89%] |
| gpt-6.1-terra xhigh | 67% (10/15) [50%, 86%] | 50% (9/18) [0%, 100%] | 54% (13/24) [29%, 67%] | 20% (3/15) [14%, 33%] | 33% (6/18) [0%, 50%] | 69% (9/13) [50%, 100%] | 75% (9/12) [71%, 100%] | 38% (11/29) [22%, 75%] |

### Terra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| gpt-5.6-terra high | 70% (161/230) [63%, 77%] | 36% (85/237) [29%, 43%] | 59% (131/222) [52%, 66%] | 42% (104/245) [35%, 50%] | 27% (76/279) [21%, 34%] | 47% (96/205) [38%, 55%] | 67% (104/155) [61%, 73%] | 65% (161/247) [58%, 72%] |
| gpt-5.6-terra low | 67% (169/251) [62%, 73%] | 31% (75/243) [24%, 39%] | 59% (138/234) [54%, 64%] | 40% (114/284) [32%, 49%] | 24% (63/259) [18%, 30%] | 44% (90/206) [35%, 52%] | 65% (113/173) [58%, 73%] | 60% (136/228) [54%, 65%] |
| gpt-5.6-terra max | 72% (172/239) [66%, 78%] | 63% (155/246) [58%, 69%] | 52% (121/234) [46%, 58%] | 57% (145/256) [48%, 65%] | 40% (120/299) [36%, 45%] | 66% (141/213) [59%, 73%] | 64% (108/169) [57%, 70%] | 80% (188/236) [75%, 84%] |
| gpt-5.6-terra medium | 63% (160/253) [57%, 69%] | 28% (70/251) [22%, 34%] | 59% (145/245) [53%, 64%] | 34% (91/264) [27%, 43%] | 27% (69/256) [21%, 33%] | 42% (76/181) [35%, 49%] | 66% (108/164) [59%, 73%] | 59% (142/241) [53%, 65%] |
| gpt-5.6-terra xhigh | 68% (170/249) [63%, 73%] | 50% (130/260) [43%, 57%] | 62% (139/223) [56%, 69%] | 47% (123/262) [40%, 54%] | 32% (90/279) [27%, 38%] | 52% (103/200) [44%, 59%] | 69% (116/169) [62%, 75%] | 67% (174/261) [60%, 73%] |

## Items held at elimination

Deaths, the share with at least one unused item, and the items held per death.

### Cross-model

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| claude-haiku-4-5-20251001 high | 95% (21/22) [86%, 100%] | 3.64 (80/22) [3.15, 4.05] | inverter 19, adrenaline 16, burner phone 13 |
| claude-haiku-4-5-20251001 low | 89% (16/18) [79%, 100%] | 3.00 (54/18) [2.14, 4.20] | adrenaline 13, inverter 11, beer 10 |
| claude-haiku-4-5-20251001 medium | 89% (304/341) [86%, 92%] | 3.50 (1192/341) [3.26, 3.75] | inverter 240, burner phone 213, beer 207 |
| claude-haiku-4-5-20251001 minimal | 78% (14/18) [61%, 94%] | 3.11 (56/18) [1.80, 4.59] | adrenaline 11, inverter 10, burner phone 9 |
| claude-haiku-4-5-20251001 off | 91% (21/23) [85%, 100%] | 3.35 (77/23) [2.52, 4.24] | beer 15, adrenaline 15, inverter 12 |
| claude-haiku-5-5 high | 96% (22/23) [88%, 100%] | 3.22 (74/23) [2.45, 3.90] | beer 14, handsaw 13, inverter 13 |
| claude-haiku-5-5 low | 100% (15/15) [100%, 100%] | 3.67 (55/15) [2.73, 4.47] | inverter 17, beer 10, burner phone 7 |
| claude-haiku-5-5 max | 90% (9/10) [70%, 100%] | 3.40 (34/10) [2.29, 4.09] | adrenaline 6, magnifying glass 5, handsaw 5 |
| claude-haiku-5-5 medium | 92% (237/258) [89%, 95%] | 3.34 (861/258) [3.12, 3.59] | inverter 176, burner phone 140, beer 134 |
| claude-haiku-5-5 off | 90% (19/21) [81%, 100%] | 3.14 (66/21) [2.39, 3.71] | burner phone 10, inverter 10, adrenaline 10 |
| claude-haiku-5-5 xhigh | 100% (17/17) [100%, 100%] | 4.00 (68/17) [3.25, 4.76] | beer 13, adrenaline 11, burner phone 10 |
| claude-opus-5-5 high | 100% (11/11) [100%, 100%] | 3.73 (41/11) [3.08, 4.67] | inverter 8, beer 7, adrenaline 7 |
| claude-opus-5-5 low | 90% (9/10) [82%, 100%] | 3.20 (32/10) [3.00, 3.67] | beer 8, inverter 7, adrenaline 7 |
| claude-opus-5-5 max | 100% (4/4) [100%, 100%] | 3.25 (13/4) [2.00, 3.67] | inverter 5, beer 3, cigarettes 2 |
| claude-opus-5-5 medium | 92% (219/237) [89%, 95%] | 3.37 (798/237) [3.14, 3.59] | inverter 182, beer 154, adrenaline 108 |
| claude-opus-5-5 off | 75% (3/4) [67%, 100%] | 4.25 (17/4) [3.67, 6.00] | inverter 6, magnifying glass 2, handsaw 2 |
| claude-opus-5-5 xhigh | 90% (54/60) [83%, 97%] | 3.17 (190/60) [2.71, 3.72] | inverter 43, beer 30, adrenaline 28 |
| claude-sonnet-5-5 high | 93% (13/14) [84%, 100%] | 3.21 (45/14) [2.30, 4.50] | inverter 19, beer 6, burner phone 5 |
| claude-sonnet-5-5 low | 95% (19/20) [77%, 100%] | 3.85 (77/20) [2.67, 4.48] | inverter 20, burner phone 15, beer 12 |
| claude-sonnet-5-5 max | 100% (8/8) [100%, 100%] | 3.38 (27/8) [2.20, 4.40] | adrenaline 5, burner phone 4, beer 4 |
| claude-sonnet-5-5 medium | 91% (228/250) [87%, 95%] | 3.54 (884/250) [3.25, 3.83] | inverter 226, adrenaline 163, beer 152 |
| claude-sonnet-5-5 off | 83% (15/18) [76%, 94%] | 3.83 (69/18) [2.89, 5.33] | inverter 16, burner phone 12, adrenaline 12 |
| claude-sonnet-5-5 xhigh | 88% (14/16) [73%, 100%] | 2.81 (45/16) [2.00, 3.69] | inverter 12, beer 8, magnifying glass 6 |
| gpt-5.6-terra high | 100% (18/18) [100%, 100%] | 3.33 (60/18) [2.88, 3.93] | burner phone 14, inverter 13, beer 11 |
| gpt-5.6-terra low | 92% (12/13) [81%, 100%] | 4.15 (54/13) [3.00, 6.00] | adrenaline 11, beer 10, inverter 10 |
| gpt-5.6-terra max | 71% (10/14) [64%, 88%] | 2.50 (35/14) [2.00, 3.57] | beer 10, inverter 7, adrenaline 5 |
| gpt-5.6-terra medium | 92% (243/265) [88%, 95%] | 3.33 (883/265) [3.07, 3.63] | inverter 198, burner phone 168, beer 166 |
| gpt-5.6-terra xhigh | 82% (14/17) [69%, 94%] | 2.47 (42/17) [1.67, 3.50] | burner phone 8, inverter 8, handsaw 7 |
| gpt-6-astra high | 100% (4/4) [100%, 100%] | 3.50 (14/4) [3.00, 4.00] | beer 5, handsaw 2, cigarettes 2 |
| gpt-6-astra low | 100% (12/12) [100%, 100%] | 3.08 (37/12) [2.47, 3.60] | inverter 10, adrenaline 8, handsaw 6 |
| gpt-6-astra medium | 94% (240/255) [91%, 97%] | 3.24 (826/255) [3.00, 3.50] | inverter 215, beer 185, adrenaline 103 |
| gpt-6-luna high | 94% (16/17) [81%, 100%] | 4.18 (71/17) [3.69, 4.65] | inverter 20, burner phone 15, adrenaline 12 |
| gpt-6-luna low | 64% (16/25) [46%, 79%] | 1.56 (39/25) [0.89, 2.45] | inverter 9, beer 6, handsaw 5 |
| gpt-6-luna max | 90% (18/20) [83%, 100%] | 3.35 (67/20) [2.93, 3.88] | inverter 19, burner phone 13, beer 11 |
| gpt-6-luna medium | 84% (312/372) [80%, 87%] | 2.74 (1021/372) [2.56, 2.94] | inverter 224, beer 173, adrenaline 159 |
| gpt-6-luna off | 88% (22/25) [74%, 100%] | 2.16 (54/25) [1.83, 2.52] | adrenaline 13, cigarettes 9, handsaw 7 |
| gpt-6-luna xhigh | 83% (15/18) [71%, 95%] | 2.72 (49/18) [2.47, 3.00] | burner phone 9, handsaw 9, inverter 9 |
| gpt-6.1-sol high | 92% (12/13) [73%, 100%] | 3.15 (41/13) [2.33, 4.23] | inverter 11, burner phone 8, beer 7 |
| gpt-6.1-sol low | 92% (11/12) [70%, 100%] | 2.83 (34/12) [1.50, 4.33] | beer 15, inverter 7, magnifying glass 4 |
| gpt-6.1-sol max | 60% (6/10) [13%, 92%] | 2.30 (23/10) [0.50, 3.50] | handsaw 5, beer 4, inverter 4 |
| gpt-6.1-sol medium | 96% (215/225) [93%, 98%] | 3.46 (778/225) [3.21, 3.70] | inverter 179, beer 153, burner phone 103 |
| gpt-6.1-sol xhigh | 92% (12/13) [79%, 100%] | 3.23 (42/13) [2.73, 3.64] | inverter 16, beer 9, handsaw 6 |
| gpt-6.1-terra high | 100% (7/7) [100%, 100%] | 4.43 (31/7) [3.75, 5.33] | beer 10, adrenaline 6, inverter 5 |
| gpt-6.1-terra low | 100% (3/3) [100%, 100%] | 2.67 (8/3) [2.67, 2.67] | inverter 4, handsaw 1, beer 1 |
| gpt-6.1-terra max | 100% (4/4) [100%, 100%] | 3.25 (13/4) [3.25, 3.25] | beer 4, inverter 4, adrenaline 2 |
| gpt-6.1-terra medium | 100% (7/7) [100%, 100%] | 3.14 (22/7) [2.67, 3.50] | inverter 6, adrenaline 6, beer 5 |
| gpt-6.1-terra off | 50% (1/2) [50%, 50%] | 2.50 (5/2) [2.50, 2.50] | magnifying glass 1, beer 1, cigarettes 1 |
| gpt-6.1-terra xhigh | 100% (4/4) [100%, 100%] | 1.50 (6/4) [1.50, 1.50] | inverter 2, adrenaline 2, beer 1 |

### Haiku 4.5 efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| claude-haiku-4-5-20251001 high | 93% (106/114) [88%, 97%] | 3.77 (430/114) [3.42, 4.12] | burner phone 86, inverter 82, beer 74 |
| claude-haiku-4-5-20251001 low | 93% (106/114) [89%, 97%] | 3.61 (412/114) [3.20, 3.97] | burner phone 90, inverter 85, adrenaline 73 |
| claude-haiku-4-5-20251001 medium | 96% (102/106) [93%, 99%] | 3.65 (387/106) [3.22, 4.13] | inverter 77, burner phone 71, beer 68 |
| claude-haiku-4-5-20251001 minimal | 87% (102/117) [81%, 92%] | 3.48 (407/117) [3.12, 3.87] | inverter 81, burner phone 71, beer 68 |
| claude-haiku-4-5-20251001 off | 89% (132/149) [83%, 94%] | 3.26 (485/149) [2.89, 3.58] | adrenaline 119, beer 79, inverter 79 |

### Haiku 5.5 efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| claude-haiku-5-5 high | 91% (126/139) [85%, 96%] | 3.16 (439/139) [2.81, 3.51] | beer 80, inverter 73, adrenaline 73 |
| claude-haiku-5-5 low | 87% (136/157) [82%, 91%] | 3.06 (481/157) [2.75, 3.42] | inverter 99, beer 76, adrenaline 75 |
| claude-haiku-5-5 max | 88% (112/127) [83%, 93%] | 3.15 (400/127) [2.87, 3.44] | beer 76, adrenaline 68, inverter 67 |
| claude-haiku-5-5 medium | 88% (133/152) [82%, 93%] | 2.91 (442/152) [2.57, 3.25] | beer 97, inverter 82, burner phone 62 |
| claude-haiku-5-5 off | 84% (160/190) [79%, 89%] | 2.78 (529/190) [2.45, 3.11] | inverter 137, adrenaline 84, beer 71 |
| claude-haiku-5-5 xhigh | 89% (120/135) [83%, 94%] | 3.50 (472/135) [3.18, 3.84] | inverter 107, beer 89, adrenaline 79 |

### Luna efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| gpt-6-luna high | 89% (116/130) [84%, 94%] | 3.48 (452/130) [3.09, 3.87] | inverter 113, beer 77, adrenaline 70 |
| gpt-6-luna low | 76% (153/201) [70%, 82%] | 2.36 (474/201) [2.08, 2.66] | adrenaline 93, beer 90, inverter 70 |
| gpt-6-luna max | 82% (84/102) [74%, 90%] | 2.72 (277/102) [2.35, 3.06] | inverter 69, adrenaline 49, burner phone 42 |
| gpt-6-luna medium | 82% (141/171) [78%, 88%] | 2.87 (491/171) [2.58, 3.16] | inverter 95, beer 88, adrenaline 86 |
| gpt-6-luna off | 75% (145/194) [68%, 81%] | 2.34 (453/194) [2.09, 2.57] | beer 79, adrenaline 75, burner phone 62 |
| gpt-6-luna xhigh | 92% (94/102) [86%, 97%] | 3.21 (327/102) [2.69, 3.72] | inverter 74, adrenaline 71, burner phone 52 |

### Opus efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| claude-opus-5-5 high | 87% (58/67) [78%, 94%] | 3.00 (201/67) [2.45, 3.55] | beer 44, inverter 36, burner phone 27 |
| claude-opus-5-5 low | 84% (31/37) [70%, 97%] | 2.78 (103/37) [2.03, 3.51] | beer 28, inverter 21, burner phone 19 |
| claude-opus-5-5 max | 67% (2/3) [50%, 100%] | 0.67 (2/3) [0.50, 1.00] | handsaw 1, beer 1 |
| claude-opus-5-5 medium | 90% (91/101) [84%, 95%] | 2.98 (301/101) [2.53, 3.42] | beer 67, inverter 59, burner phone 46 |
| claude-opus-5-5 off | 67% (4/6) [67%, 67%] | 2.00 (12/6) [1.67, 2.33] | beer 5, jammer 2, adrenaline 2 |
| claude-opus-5-5 xhigh | 86% (43/50) [76%, 96%] | 2.66 (133/50) [2.09, 3.29] | inverter 32, beer 23, magnifying glass 16 |

### Sol efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| gpt-6.1-sol high | 86% (108/125) [81%, 91%] | 3.09 (386/125) [2.71, 3.44] | inverter 74, beer 73, adrenaline 65 |
| gpt-6.1-sol low | 91% (112/123) [86%, 96%] | 3.26 (401/123) [2.83, 3.67] | inverter 89, beer 86, adrenaline 62 |
| gpt-6.1-sol max | 85% (93/109) [78%, 92%] | 3.27 (356/109) [2.83, 3.71] | inverter 78, beer 62, adrenaline 58 |
| gpt-6.1-sol medium | 89% (109/122) [84%, 94%] | 3.20 (390/122) [2.89, 3.53] | inverter 86, beer 65, adrenaline 61 |
| gpt-6.1-sol xhigh | 80% (97/121) [72%, 88%] | 3.03 (367/121) [2.53, 3.58] | inverter 74, adrenaline 63, beer 55 |

### Sonnet efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| claude-sonnet-5-5 high | 91% (138/152) [84%, 96%] | 3.29 (500/152) [2.93, 3.60] | inverter 128, adrenaline 82, beer 79 |
| claude-sonnet-5-5 low | 93% (161/174) [88%, 96%] | 3.38 (588/174) [3.05, 3.70] | inverter 149, adrenaline 115, beer 94 |
| claude-sonnet-5-5 max | 92% (101/110) [86%, 97%] | 3.09 (340/110) [2.74, 3.43] | inverter 73, beer 60, adrenaline 53 |
| claude-sonnet-5-5 medium | 90% (142/158) [84%, 95%] | 3.28 (518/158) [2.89, 3.64] | inverter 139, adrenaline 101, beer 87 |
| claude-sonnet-5-5 off | 91% (150/165) [86%, 95%] | 3.10 (511/165) [2.76, 3.45] | inverter 138, adrenaline 92, beer 66 |
| claude-sonnet-5-5 xhigh | 90% (127/141) [85%, 95%] | 3.18 (448/141) [2.87, 3.49] | inverter 106, beer 75, adrenaline 70 |

### Terra 6.1 efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| gpt-6.1-terra high | 100% (9/9) [100%, 100%] | 3.00 (27/9) [2.67, 3.67] | beer 9, burner phone 7, handsaw 4 |
| gpt-6.1-terra low | 100% (4/4) [100%, 100%] | 3.00 (12/4) [2.00, 3.33] | burner phone 6, inverter 2, adrenaline 2 |
| gpt-6.1-terra max | – | – | – |
| gpt-6.1-terra medium | 90% (9/10) [75%, 100%] | 3.50 (35/10) [2.75, 4.00] | beer 11, inverter 8, burner phone 7 |
| gpt-6.1-terra off | 100% (8/8) [100%, 100%] | 3.88 (31/8) [3.60, 4.33] | beer 13, inverter 8, burner phone 5 |
| gpt-6.1-terra xhigh | 100% (11/11) [100%, 100%] | 4.27 (47/11) [3.80, 4.67] | adrenaline 17, inverter 9, beer 8 |

### Terra efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| gpt-5.6-terra high | 94% (111/118) [90%, 98%] | 3.46 (408/118) [3.10, 3.85] | inverter 105, beer 71, burner phone 65 |
| gpt-5.6-terra low | 95% (127/134) [91%, 98%] | 3.81 (511/134) [3.53, 4.11] | inverter 107, beer 95, burner phone 90 |
| gpt-5.6-terra max | 88% (98/111) [82%, 94%] | 2.88 (320/111) [2.51, 3.27] | inverter 78, beer 61, burner phone 45 |
| gpt-5.6-terra medium | 97% (128/132) [93%, 100%] | 4.33 (571/132) [3.93, 4.73] | inverter 122, burner phone 116, beer 100 |
| gpt-5.6-terra xhigh | 91% (96/105) [86%, 96%] | 3.23 (339/105) [2.88, 3.61] | inverter 77, beer 63, burner phone 51 |

## Same-position consistency

Agent decisions grouped by the deciding player's own position. Exact: the same board, cash and round, the same log since the load, the same legal moves, code and instructions. Belief: the same board, load shown, cash, round, legal moves and versions, the same public and private shell beliefs, and the same count of clue items each opponent used this load. Players are named relative to the decider. Coverage is the share of decisions in a position seen at least twice. Non-modal is the share of those decisions that differ from their position's most common choice; it has no interval, because resampling blocks duplicates decisions and a copy always matches the mode. Two differ is the chance two different decisions in a position differ, averaged over positions, with an interval over pairs of distinct decisions.

### Exact positions

| Cohort | Model | Positions seen twice or more | Coverage | Non-modal choices | Two differ |
|---|---|---|---|---|---|
| Cross-model | claude-haiku-4-5-20251001 high | 0 | 0% (0/191) | – | – |
| Cross-model | claude-haiku-4-5-20251001 low | 5 | 4.5% (10/220) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-haiku-4-5-20251001 medium | 263 | 18% (719/3945) | 19% (137/719) | 36% over 263 positions [31%, 41%] |
| Cross-model | claude-haiku-4-5-20251001 minimal | 0 | 0% (0/254) | – | – |
| Cross-model | claude-haiku-4-5-20251001 off | 5 | 4.4% (10/229) | 20% (2/10) | 40% over 5 positions [33%, 50%] |
| Cross-model | claude-haiku-5-5 high | 3 | 2.2% (6/269) | 17% (1/6) | 33% over 3 positions [33%, 33%] |
| Cross-model | claude-haiku-5-5 low | 0 | 0% (0/313) | – | – |
| Cross-model | claude-haiku-5-5 max | 0 | 0% (0/238) | – | – |
| Cross-model | claude-haiku-5-5 medium | 303 | 19% (852/4434) | 12% (101/852) | 21% over 303 positions [18%, 26%] |
| Cross-model | claude-haiku-5-5 off | 9 | 8.4% (18/214) | 11% (2/18) | 22% over 9 positions [17%, 33%] |
| Cross-model | claude-haiku-5-5 xhigh | 0 | 0% (0/216) | – | – |
| Cross-model | claude-opus-5-5 high | 0 | 0% (0/228) | – | – |
| Cross-model | claude-opus-5-5 low | 0 | 0% (0/212) | – | – |
| Cross-model | claude-opus-5-5 max | 3 | 6.0% (6/100) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Cross-model | claude-opus-5-5 medium | 399 | 23% (1086/4771) | 6.0% (65/1086) | 11% over 399 positions [9.0%, 14%] |
| Cross-model | claude-opus-5-5 off | 0 | 0% (0/113) | – | – |
| Cross-model | claude-opus-5-5 xhigh | 1 | 0.2% (2/1055) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-sonnet-5-5 high | 5 | 3.6% (10/274) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 low | 5 | 3.2% (10/316) | 10% (1/10) | 20% over 5 positions [0%, 50%] |
| Cross-model | claude-sonnet-5-5 max | 3 | 2.6% (6/233) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 medium | 357 | 23% (995/4395) | 5.9% (59/995) | 12% over 357 positions [8.8%, 15%] |
| Cross-model | claude-sonnet-5-5 off | 13 | 8.7% (26/300) | 0% (0/26) | 0% over 13 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 xhigh | 0 | 0% (0/280) | – | – |
| Cross-model | gpt-5.6-terra high | 0 | 0% (0/258) | – | – |
| Cross-model | gpt-5.6-terra low | 0 | 0% (0/259) | – | – |
| Cross-model | gpt-5.6-terra max | 0 | 0% (0/319) | – | – |
| Cross-model | gpt-5.6-terra medium | 296 | 16% (690/4246) | 10% (72/690) | 20% over 296 positions [16%, 27%] |
| Cross-model | gpt-5.6-terra xhigh | 2 | 1.3% (4/304) | 0% (0/4) | 0% over 2 positions [0%, 0%] |
| Cross-model | gpt-6-astra high | 0 | 0% (0/125) | – | – |
| Cross-model | gpt-6-astra low | 0 | 0% (0/146) | – | – |
| Cross-model | gpt-6-astra medium | 398 | 21% (1125/5393) | 2.8% (31/1125) | 5.5% over 398 positions [3.6%, 7.0%] |
| Cross-model | gpt-6-luna high | 0 | 0% (0/258) | – | – |
| Cross-model | gpt-6-luna low | 12 | 9.1% (24/263) | 8.3% (2/24) | 17% over 12 positions [9.1%, 100%] |
| Cross-model | gpt-6-luna max | 7 | 5.4% (14/259) | 14% (2/14) | 29% over 7 positions [29%, 29%] |
| Cross-model | gpt-6-luna medium | 306 | 18% (853/4673) | 17% (148/853) | 32% over 306 positions [27%, 37%] |
| Cross-model | gpt-6-luna off | 0 | 0% (0/274) | – | – |
| Cross-model | gpt-6-luna xhigh | 0 | 0% (0/352) | – | – |
| Cross-model | gpt-6.1-sol high | 0 | 0% (0/248) | – | – |
| Cross-model | gpt-6.1-sol low | 0 | 0% (0/234) | – | – |
| Cross-model | gpt-6.1-sol max | 0 | 0% (0/325) | – | – |
| Cross-model | gpt-6.1-sol medium | 395 | 23% (1076/4704) | 4.9% (53/1076) | 8.6% over 395 positions [6.9%, 13%] |
| Cross-model | gpt-6.1-sol xhigh | 1 | 0.5% (2/383) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6.1-terra high | 0 | 0% (0/91) | – | – |
| Cross-model | gpt-6.1-terra low | 0 | 0% (0/61) | – | – |
| Cross-model | gpt-6.1-terra max | 0 | 0% (0/69) | – | – |
| Cross-model | gpt-6.1-terra medium | 0 | 0% (0/118) | – | – |
| Cross-model | gpt-6.1-terra off | 0 | 0% (0/45) | – | – |
| Cross-model | gpt-6.1-terra xhigh | 0 | 0% (0/57) | – | – |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 high | 84 | 11% (228/2083) | 17% (38/228) | 34% over 84 positions [24%, 40%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 low | 97 | 12% (250/2125) | 17% (42/250) | 32% over 97 positions [24%, 38%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 medium | 106 | 14% (296/2175) | 15% (43/296) | 29% over 106 positions [20%, 36%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 minimal | 115 | 15% (308/2080) | 15% (46/308) | 32% over 115 positions [22%, 36%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 off | 105 | 13% (285/2173) | 18% (52/285) | 34% over 105 positions [29%, 43%] |
| Haiku 5.5 efforts | claude-haiku-5-5 high | 186 | 21% (525/2513) | 9.1% (48/525) | 19% over 186 positions [13%, 23%] |
| Haiku 5.5 efforts | claude-haiku-5-5 low | 235 | 26% (641/2513) | 9.4% (60/641) | 19% over 235 positions [14%, 23%] |
| Haiku 5.5 efforts | claude-haiku-5-5 max | 247 | 26% (667/2573) | 9.7% (65/667) | 19% over 247 positions [14%, 23%] |
| Haiku 5.5 efforts | claude-haiku-5-5 medium | 222 | 24% (624/2558) | 8.5% (53/624) | 16% over 222 positions [12%, 21%] |
| Haiku 5.5 efforts | claude-haiku-5-5 off | 248 | 27% (655/2387) | 12% (78/655) | 22% over 248 positions [17%, 28%] |
| Haiku 5.5 efforts | claude-haiku-5-5 xhigh | 266 | 27% (692/2534) | 8.4% (58/692) | 15% over 266 positions [12%, 20%] |
| Luna efforts | gpt-6-luna high | 135 | 13% (358/2829) | 18% (63/358) | 32% over 135 positions [26%, 40%] |
| Luna efforts | gpt-6-luna low | 160 | 15% (436/2920) | 19% (85/436) | 36% over 160 positions [30%, 44%] |
| Luna efforts | gpt-6-luna max | 153 | 15% (433/2936) | 11% (46/433) | 21% over 153 positions [15%, 26%] |
| Luna efforts | gpt-6-luna medium | 123 | 12% (342/2866) | 16% (54/342) | 28% over 123 positions [22%, 38%] |
| Luna efforts | gpt-6-luna off | 155 | 14% (413/2888) | 16% (67/413) | 30% over 155 positions [24%, 37%] |
| Luna efforts | gpt-6-luna xhigh | 139 | 13% (375/2792) | 15% (55/375) | 28% over 139 positions [20%, 37%] |
| Opus efforts | claude-opus-5-5 high | 149 | 31% (301/970) | 5.0% (15/301) | 9.6% over 149 positions [2.4%, 27%] |
| Opus efforts | claude-opus-5-5 low | 3 | 1.0% (6/583) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Opus efforts | claude-opus-5-5 max | 13 | 24% (26/109) | 3.8% (1/26) | 7.7% over 13 positions [7.7%, 7.7%] |
| Opus efforts | claude-opus-5-5 medium | 202 | 33% (502/1541) | 4.8% (24/502) | 11% over 202 positions [6.5%, 12%] |
| Opus efforts | claude-opus-5-5 off | 0 | 0% (0/73) | – | – |
| Opus efforts | claude-opus-5-5 xhigh | 157 | 33% (319/969) | 5.6% (18/319) | 11% over 157 positions [5.6%, 23%] |
| Sol efforts | gpt-6.1-sol high | 302 | 41% (801/1951) | 5.5% (44/801) | 11% over 302 positions [7.7%, 14%] |
| Sol efforts | gpt-6.1-sol low | 291 | 42% (776/1851) | 4.4% (34/776) | 8.4% over 291 positions [5.7%, 11%] |
| Sol efforts | gpt-6.1-sol max | 321 | 43% (886/2054) | 5.5% (49/886) | 12% over 321 positions [7.8%, 14%] |
| Sol efforts | gpt-6.1-sol medium | 283 | 41% (784/1907) | 4.3% (34/784) | 8.9% over 283 positions [6.0%, 11%] |
| Sol efforts | gpt-6.1-sol xhigh | 290 | 40% (777/1963) | 6.3% (49/777) | 11% over 290 positions [8.8%, 16%] |
| Sonnet efforts | claude-sonnet-5-5 high | 302 | 34% (842/2455) | 5.8% (49/842) | 12% over 302 positions [7.6%, 14%] |
| Sonnet efforts | claude-sonnet-5-5 low | 260 | 32% (747/2338) | 7.9% (59/747) | 16% over 260 positions [12%, 19%] |
| Sonnet efforts | claude-sonnet-5-5 max | 311 | 37% (955/2568) | 5.4% (52/955) | 12% over 311 positions [7.9%, 13%] |
| Sonnet efforts | claude-sonnet-5-5 medium | 284 | 33% (826/2495) | 5.7% (47/826) | 11% over 284 positions [7.9%, 14%] |
| Sonnet efforts | claude-sonnet-5-5 off | 327 | 41% (988/2415) | 6.1% (60/988) | 12% over 327 positions [9.1%, 14%] |
| Sonnet efforts | claude-sonnet-5-5 xhigh | 262 | 33% (813/2439) | 5.9% (48/813) | 12% over 262 positions [8.6%, 15%] |
| Terra 6.1 efforts | gpt-6.1-terra high | 0 | 0% (0/94) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra low | 0 | 0% (0/113) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra max | 0 | 0% (0/74) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra medium | 0 | 0% (0/205) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra off | 0 | 0% (0/87) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra xhigh | 2 | 2.9% (4/139) | 25% (1/4) | 50% over 2 positions [50%, 50%] |
| Terra efforts | gpt-5.6-terra high | 128 | 19% (351/1886) | 14% (49/351) | 27% over 128 positions [20%, 32%] |
| Terra efforts | gpt-5.6-terra low | 152 | 20% (374/1852) | 13% (50/374) | 24% over 152 positions [19%, 35%] |
| Terra efforts | gpt-5.6-terra max | 185 | 23% (503/2170) | 9.3% (47/503) | 20% over 185 positions [12%, 24%] |
| Terra efforts | gpt-5.6-terra medium | 160 | 22% (403/1792) | 13% (51/403) | 24% over 160 positions [18%, 32%] |
| Terra efforts | gpt-5.6-terra xhigh | 135 | 17% (355/2030) | 14% (48/355) | 29% over 135 positions [20%, 34%] |

### Belief positions

| Cohort | Model | Positions seen twice or more | Coverage | Non-modal choices | Two differ |
|---|---|---|---|---|---|
| Cross-model | claude-haiku-4-5-20251001 high | 0 | 0% (0/191) | – | – |
| Cross-model | claude-haiku-4-5-20251001 low | 5 | 4.5% (10/220) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-haiku-4-5-20251001 medium | 287 | 20% (783/3945) | 19% (148/783) | 35% over 287 positions [31%, 41%] |
| Cross-model | claude-haiku-4-5-20251001 minimal | 0 | 0% (0/254) | – | – |
| Cross-model | claude-haiku-4-5-20251001 off | 5 | 4.4% (10/229) | 20% (2/10) | 40% over 5 positions [33%, 50%] |
| Cross-model | claude-haiku-5-5 high | 3 | 2.2% (6/269) | 17% (1/6) | 33% over 3 positions [33%, 33%] |
| Cross-model | claude-haiku-5-5 low | 0 | 0% (0/313) | – | – |
| Cross-model | claude-haiku-5-5 max | 0 | 0% (0/238) | – | – |
| Cross-model | claude-haiku-5-5 medium | 334 | 21% (945/4434) | 11% (106/945) | 19% over 334 positions [17%, 24%] |
| Cross-model | claude-haiku-5-5 off | 9 | 8.4% (18/214) | 11% (2/18) | 22% over 9 positions [17%, 33%] |
| Cross-model | claude-haiku-5-5 xhigh | 0 | 0% (0/216) | – | – |
| Cross-model | claude-opus-5-5 high | 0 | 0% (0/228) | – | – |
| Cross-model | claude-opus-5-5 low | 0 | 0% (0/212) | – | – |
| Cross-model | claude-opus-5-5 max | 3 | 6.0% (6/100) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Cross-model | claude-opus-5-5 medium | 430 | 25% (1189/4771) | 5.8% (69/1189) | 10% over 430 positions [8.7%, 13%] |
| Cross-model | claude-opus-5-5 off | 0 | 0% (0/113) | – | – |
| Cross-model | claude-opus-5-5 xhigh | 1 | 0.2% (2/1055) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-sonnet-5-5 high | 5 | 3.6% (10/274) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 low | 5 | 3.2% (10/316) | 10% (1/10) | 20% over 5 positions [0%, 50%] |
| Cross-model | claude-sonnet-5-5 max | 3 | 2.6% (6/233) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 medium | 392 | 25% (1085/4395) | 6.1% (66/1085) | 13% over 392 positions [9.2%, 15%] |
| Cross-model | claude-sonnet-5-5 off | 13 | 8.7% (26/300) | 0% (0/26) | 0% over 13 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 xhigh | 0 | 0% (0/280) | – | – |
| Cross-model | gpt-5.6-terra high | 0 | 0% (0/258) | – | – |
| Cross-model | gpt-5.6-terra low | 0 | 0% (0/259) | – | – |
| Cross-model | gpt-5.6-terra max | 0 | 0% (0/319) | – | – |
| Cross-model | gpt-5.6-terra medium | 315 | 17% (739/4246) | 10% (77/739) | 20% over 315 positions [16%, 27%] |
| Cross-model | gpt-5.6-terra xhigh | 2 | 1.3% (4/304) | 0% (0/4) | 0% over 2 positions [0%, 0%] |
| Cross-model | gpt-6-astra high | 0 | 0% (0/125) | – | – |
| Cross-model | gpt-6-astra low | 0 | 0% (0/146) | – | – |
| Cross-model | gpt-6-astra medium | 420 | 22% (1177/5393) | 2.9% (34/1177) | 6.0% over 420 positions [3.7%, 7.6%] |
| Cross-model | gpt-6-luna high | 0 | 0% (0/258) | – | – |
| Cross-model | gpt-6-luna low | 15 | 11% (30/263) | 6.7% (2/30) | 13% over 15 positions [7.1%, 100%] |
| Cross-model | gpt-6-luna max | 7 | 5.4% (14/259) | 14% (2/14) | 29% over 7 positions [29%, 29%] |
| Cross-model | gpt-6-luna medium | 330 | 19% (911/4673) | 17% (156/911) | 31% over 330 positions [27%, 37%] |
| Cross-model | gpt-6-luna off | 0 | 0% (0/274) | – | – |
| Cross-model | gpt-6-luna xhigh | 0 | 0% (0/352) | – | – |
| Cross-model | gpt-6.1-sol high | 0 | 0% (0/248) | – | – |
| Cross-model | gpt-6.1-sol low | 0 | 0% (0/234) | – | – |
| Cross-model | gpt-6.1-sol max | 0 | 0% (0/325) | – | – |
| Cross-model | gpt-6.1-sol medium | 426 | 25% (1165/4704) | 4.7% (55/1165) | 8.4% over 426 positions [6.7%, 12%] |
| Cross-model | gpt-6.1-sol xhigh | 1 | 0.5% (2/383) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6.1-terra high | 0 | 0% (0/91) | – | – |
| Cross-model | gpt-6.1-terra low | 0 | 0% (0/61) | – | – |
| Cross-model | gpt-6.1-terra max | 0 | 0% (0/69) | – | – |
| Cross-model | gpt-6.1-terra medium | 0 | 0% (0/118) | – | – |
| Cross-model | gpt-6.1-terra off | 0 | 0% (0/45) | – | – |
| Cross-model | gpt-6.1-terra xhigh | 0 | 0% (0/57) | – | – |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 high | 91 | 12% (244/2083) | 17% (42/244) | 35% over 91 positions [25%, 41%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 low | 107 | 13% (271/2125) | 17% (45/271) | 31% over 107 positions [25%, 38%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 medium | 112 | 14% (308/2175) | 14% (43/308) | 28% over 112 positions [20%, 34%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 minimal | 121 | 15% (322/2080) | 15% (49/322) | 32% over 121 positions [22%, 36%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 off | 110 | 14% (297/2173) | 18% (53/297) | 33% over 110 positions [28%, 42%] |
| Haiku 5.5 efforts | claude-haiku-5-5 high | 223 | 25% (616/2513) | 9.3% (57/616) | 19% over 223 positions [13%, 24%] |
| Haiku 5.5 efforts | claude-haiku-5-5 low | 261 | 28% (715/2513) | 10% (72/715) | 21% over 261 positions [15%, 24%] |
| Haiku 5.5 efforts | claude-haiku-5-5 max | 292 | 31% (793/2573) | 9.2% (73/793) | 19% over 292 positions [14%, 21%] |
| Haiku 5.5 efforts | claude-haiku-5-5 medium | 245 | 27% (679/2558) | 8.8% (60/679) | 17% over 245 positions [13%, 22%] |
| Haiku 5.5 efforts | claude-haiku-5-5 off | 273 | 30% (720/2387) | 12% (86/720) | 22% over 273 positions [18%, 28%] |
| Haiku 5.5 efforts | claude-haiku-5-5 xhigh | 304 | 31% (785/2534) | 7.6% (60/785) | 14% over 304 positions [11%, 18%] |
| Luna efforts | gpt-6-luna high | 159 | 15% (421/2829) | 17% (73/421) | 31% over 159 positions [26%, 38%] |
| Luna efforts | gpt-6-luna low | 193 | 17% (508/2920) | 20% (102/508) | 38% over 193 positions [31%, 45%] |
| Luna efforts | gpt-6-luna max | 170 | 16% (471/2936) | 12% (55/471) | 24% over 170 positions [18%, 28%] |
| Luna efforts | gpt-6-luna medium | 148 | 14% (400/2866) | 17% (69/400) | 32% over 148 positions [24%, 40%] |
| Luna efforts | gpt-6-luna off | 175 | 16% (458/2888) | 18% (82/458) | 34% over 175 positions [27%, 41%] |
| Luna efforts | gpt-6-luna xhigh | 161 | 16% (435/2792) | 14% (62/435) | 27% over 161 positions [20%, 35%] |
| Opus efforts | claude-opus-5-5 high | 158 | 33% (319/970) | 5.3% (17/319) | 10% over 158 positions [4.2%, 26%] |
| Opus efforts | claude-opus-5-5 low | 3 | 1.0% (6/583) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Opus efforts | claude-opus-5-5 max | 13 | 24% (26/109) | 3.8% (1/26) | 7.7% over 13 positions [7.7%, 7.7%] |
| Opus efforts | claude-opus-5-5 medium | 221 | 35% (545/1541) | 5.0% (27/545) | 11% over 221 positions [6.4%, 14%] |
| Opus efforts | claude-opus-5-5 off | 0 | 0% (0/73) | – | – |
| Opus efforts | claude-opus-5-5 xhigh | 168 | 35% (343/969) | 5.8% (20/343) | 12% over 168 positions [5.6%, 21%] |
| Sol efforts | gpt-6.1-sol high | 316 | 43% (845/1951) | 5.4% (46/845) | 10% over 316 positions [7.5%, 13%] |
| Sol efforts | gpt-6.1-sol low | 305 | 44% (820/1851) | 4.5% (37/820) | 8.9% over 305 positions [6.1%, 11%] |
| Sol efforts | gpt-6.1-sol max | 339 | 45% (929/2054) | 5.6% (52/929) | 12% over 339 positions [8.0%, 14%] |
| Sol efforts | gpt-6.1-sol medium | 292 | 43% (821/1907) | 4.3% (35/821) | 9.0% over 292 positions [5.8%, 11%] |
| Sol efforts | gpt-6.1-sol xhigh | 304 | 42% (821/1963) | 6.5% (53/821) | 11% over 304 positions [8.9%, 16%] |
| Sonnet efforts | claude-sonnet-5-5 high | 326 | 37% (898/2455) | 5.8% (52/898) | 12% over 326 positions [7.6%, 14%] |
| Sonnet efforts | claude-sonnet-5-5 low | 263 | 33% (769/2338) | 8.3% (64/769) | 17% over 263 positions [12%, 19%] |
| Sonnet efforts | claude-sonnet-5-5 max | 332 | 40% (1020/2568) | 5.4% (55/1020) | 12% over 332 positions [7.6%, 13%] |
| Sonnet efforts | claude-sonnet-5-5 medium | 294 | 35% (862/2495) | 6.0% (52/862) | 12% over 294 positions [8.5%, 15%] |
| Sonnet efforts | claude-sonnet-5-5 off | 334 | 42% (1021/2415) | 6.5% (66/1021) | 13% over 334 positions [9.5%, 16%] |
| Sonnet efforts | claude-sonnet-5-5 xhigh | 280 | 36% (867/2439) | 5.8% (50/867) | 12% over 280 positions [8.5%, 14%] |
| Terra 6.1 efforts | gpt-6.1-terra high | 0 | 0% (0/94) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra low | 0 | 0% (0/113) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra max | 0 | 0% (0/74) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra medium | 0 | 0% (0/205) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra off | 0 | 0% (0/87) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra xhigh | 2 | 2.9% (4/139) | 25% (1/4) | 50% over 2 positions [50%, 50%] |
| Terra efforts | gpt-5.6-terra high | 140 | 21% (388/1886) | 13% (52/388) | 27% over 140 positions [19%, 31%] |
| Terra efforts | gpt-5.6-terra low | 173 | 23% (422/1852) | 14% (58/422) | 26% over 173 positions [20%, 34%] |
| Terra efforts | gpt-5.6-terra max | 208 | 26% (558/2170) | 9.0% (50/558) | 19% over 208 positions [12%, 23%] |
| Terra efforts | gpt-5.6-terra medium | 176 | 25% (453/1792) | 13% (57/453) | 23% over 176 positions [19%, 31%] |
| Terra efforts | gpt-5.6-terra xhigh | 156 | 20% (405/2030) | 12% (50/405) | 26% over 156 positions [19%, 31%] |

## Agreement between effort variants

For each pair of one model's effort levels in the same cohort, exact positions both met. Across: the chance a random decision of each variant agrees, averaged over shared positions. Within: for comparison, the chance two decisions of the same variant agree, over shared positions that variant met at least twice.

| Cohort | Variants | Shared positions | Across | Within, first | Within, second |
|---|---|---|---|---|---|
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 low | 4 | 75% over 4 positions [75%, 75%] | – | – |
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 medium | 33 | 68% over 33 positions [61%, 83%] | – | 77% over 13 positions [50%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 minimal | 9 | 89% over 9 positions [89%, 89%] | – | – |
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 off | 17 | 71% over 17 positions [33%, 100%] | – | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 medium | 31 | 58% over 31 positions [25%, 80%] | – | 67% over 12 positions [50%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 minimal | 31 | 74% over 31 positions [0%, 92%] | 100% over 5 positions [100%, 100%] | – |
| Cross-model | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 off | 0 | – | – | – |
| Cross-model | claude-haiku-4-5-20251001 medium vs claude-haiku-4-5-20251001 minimal | 44 | 65% over 44 positions [52%, 75%] | 53% over 19 positions [40%, 67%] | – |
| Cross-model | claude-haiku-4-5-20251001 medium vs claude-haiku-4-5-20251001 off | 20 | 55% over 20 positions [20%, 83%] | 75% over 8 positions [0%, 100%] | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 minimal vs claude-haiku-4-5-20251001 off | 6 | 67% over 6 positions [67%, 67%] | – | – |
| Cross-model | claude-haiku-5-5 high vs claude-haiku-5-5 low | 26 | 83% over 26 positions [50%, 100%] | 67% over 3 positions [67%, 67%] | – |
| Cross-model | claude-haiku-5-5 high vs claude-haiku-5-5 max | 3 | 67% over 3 positions [67%, 67%] | – | – |
| Cross-model | claude-haiku-5-5 high vs claude-haiku-5-5 medium | 46 | 80% over 46 positions [67%, 92%] | 67% over 3 positions [67%, 67%] | 94% over 18 positions [89%, 100%] |
| Cross-model | claude-haiku-5-5 high vs claude-haiku-5-5 off | 3 | 33% over 3 positions [33%, 33%] | – | – |
| Cross-model | claude-haiku-5-5 high vs claude-haiku-5-5 xhigh | 4 | 100% over 4 positions [100%, 100%] | – | – |
| Cross-model | claude-haiku-5-5 low vs claude-haiku-5-5 max | 3 | 67% over 3 positions [67%, 67%] | – | – |
| Cross-model | claude-haiku-5-5 low vs claude-haiku-5-5 medium | 52 | 78% over 52 positions [67%, 86%] | – | 94% over 17 positions [80%, 100%] |
| Cross-model | claude-haiku-5-5 low vs claude-haiku-5-5 off | 0 | – | – | – |
| Cross-model | claude-haiku-5-5 low vs claude-haiku-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-haiku-5-5 max vs claude-haiku-5-5 medium | 35 | 77% over 35 positions [33%, 93%] | – | 62% over 13 positions [0%, 100%] |
| Cross-model | claude-haiku-5-5 max vs claude-haiku-5-5 off | 12 | 58% over 12 positions [0%, 100%] | – | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-haiku-5-5 max vs claude-haiku-5-5 xhigh | 46 | 87% over 46 positions [50%, 100%] | – | – |
| Cross-model | claude-haiku-5-5 medium vs claude-haiku-5-5 off | 32 | 72% over 32 positions [50%, 83%] | 78% over 18 positions [50%, 100%] | 80% over 5 positions [67%, 100%] |
| Cross-model | claude-haiku-5-5 medium vs claude-haiku-5-5 xhigh | 41 | 76% over 41 positions [50%, 100%] | 69% over 16 positions [50%, 100%] | – |
| Cross-model | claude-haiku-5-5 off vs claude-haiku-5-5 xhigh | 16 | 56% over 16 positions [0%, 75%] | 100% over 1 positions [100%, 100%] | – |
| Cross-model | claude-opus-5-5 high vs claude-opus-5-5 low | 21 | 90% over 21 positions [75%, 100%] | – | – |
| Cross-model | claude-opus-5-5 high vs claude-opus-5-5 max | 0 | – | – | – |
| Cross-model | claude-opus-5-5 high vs claude-opus-5-5 medium | 43 | 90% over 43 positions [0%, 100%] | – | 96% over 23 positions [86%, 100%] |
| Cross-model | claude-opus-5-5 high vs claude-opus-5-5 off | 0 | – | – | – |
| Cross-model | claude-opus-5-5 high vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-opus-5-5 low vs claude-opus-5-5 max | 0 | – | – | – |
| Cross-model | claude-opus-5-5 low vs claude-opus-5-5 medium | 63 | 91% over 63 positions [83%, 100%] | – | 98% over 40 positions [92%, 100%] |
| Cross-model | claude-opus-5-5 low vs claude-opus-5-5 off | 0 | – | – | – |
| Cross-model | claude-opus-5-5 low vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-opus-5-5 max vs claude-opus-5-5 medium | 0 | – | – | – |
| Cross-model | claude-opus-5-5 max vs claude-opus-5-5 off | 0 | – | – | – |
| Cross-model | claude-opus-5-5 max vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-opus-5-5 medium vs claude-opus-5-5 off | 0 | – | – | – |
| Cross-model | claude-opus-5-5 medium vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-opus-5-5 off vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 low | 12 | 88% over 12 positions [86%, 100%] | – | 50% over 2 positions [50%, 50%] |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 max | 7 | 57% over 7 positions [0%, 75%] | – | – |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 medium | 40 | 89% over 40 positions [80%, 100%] | 100% over 5 positions [100%, 100%] | 93% over 14 positions [88%, 100%] |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 off | 6 | 83% over 6 positions [50%, 100%] | – | – |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 xhigh | 4 | 75% over 4 positions [75%, 75%] | – | – |
| Cross-model | claude-sonnet-5-5 low vs claude-sonnet-5-5 max | 20 | 70% over 20 positions [50%, 100%] | 50% over 2 positions [50%, 50%] | – |
| Cross-model | claude-sonnet-5-5 low vs claude-sonnet-5-5 medium | 28 | 84% over 28 positions [67%, 100%] | 50% over 2 positions [50%, 50%] | 85% over 13 positions [0%, 100%] |
| Cross-model | claude-sonnet-5-5 low vs claude-sonnet-5-5 off | 19 | 79% over 19 positions [0%, 100%] | 100% over 1 positions [100%, 100%] | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-sonnet-5-5 low vs claude-sonnet-5-5 xhigh | 6 | 67% over 6 positions [50%, 100%] | – | – |
| Cross-model | claude-sonnet-5-5 max vs claude-sonnet-5-5 medium | 16 | 53% over 16 positions [0%, 70%] | – | 91% over 11 positions [0%, 100%] |
| Cross-model | claude-sonnet-5-5 max vs claude-sonnet-5-5 off | 7 | 71% over 7 positions [0%, 100%] | – | – |
| Cross-model | claude-sonnet-5-5 max vs claude-sonnet-5-5 xhigh | 2 | 50% over 2 positions [50%, 50%] | – | – |
| Cross-model | claude-sonnet-5-5 medium vs claude-sonnet-5-5 off | 29 | 79% over 29 positions [50%, 100%] | 89% over 19 positions [75%, 100%] | – |
| Cross-model | claude-sonnet-5-5 medium vs claude-sonnet-5-5 xhigh | 37 | 80% over 37 positions [60%, 92%] | 81% over 16 positions [50%, 100%] | – |
| Cross-model | claude-sonnet-5-5 off vs claude-sonnet-5-5 xhigh | 27 | 81% over 27 positions [50%, 89%] | – | – |
| Cross-model | gpt-5.6-terra high vs gpt-5.6-terra low | 4 | 100% over 4 positions [100%, 100%] | – | – |
| Cross-model | gpt-5.6-terra high vs gpt-5.6-terra max | 20 | 80% over 20 positions [75%, 83%] | – | – |
| Cross-model | gpt-5.6-terra high vs gpt-5.6-terra medium | 45 | 87% over 45 positions [50%, 96%] | – | 88% over 17 positions [0%, 100%] |
| Cross-model | gpt-5.6-terra high vs gpt-5.6-terra xhigh | 17 | 82% over 17 positions [80%, 86%] | – | – |
| Cross-model | gpt-5.6-terra low vs gpt-5.6-terra max | 2 | 0% over 2 positions [0%, 0%] | – | – |
| Cross-model | gpt-5.6-terra low vs gpt-5.6-terra medium | 35 | 79% over 35 positions [33%, 92%] | – | 63% over 8 positions [0%, 100%] |
| Cross-model | gpt-5.6-terra low vs gpt-5.6-terra xhigh | 20 | 90% over 20 positions [67%, 100%] | – | – |
| Cross-model | gpt-5.6-terra max vs gpt-5.6-terra medium | 26 | 63% over 26 positions [33%, 75%] | – | 70% over 10 positions [0%, 100%] |
| Cross-model | gpt-5.6-terra max vs gpt-5.6-terra xhigh | 0 | – | – | – |
| Cross-model | gpt-5.6-terra medium vs gpt-5.6-terra xhigh | 52 | 83% over 52 positions [56%, 92%] | 89% over 19 positions [50%, 100%] | 100% over 2 positions [100%, 100%] |
| Cross-model | gpt-6-astra high vs gpt-6-astra low | 0 | – | – | – |
| Cross-model | gpt-6-astra high vs gpt-6-astra medium | 0 | – | – | – |
| Cross-model | gpt-6-astra low vs gpt-6-astra medium | 0 | – | – | – |
| Cross-model | gpt-6-luna high vs gpt-6-luna low | 7 | 57% over 7 positions [0%, 80%] | – | – |
| Cross-model | gpt-6-luna high vs gpt-6-luna max | 15 | 80% over 15 positions [75%, 83%] | – | – |
| Cross-model | gpt-6-luna high vs gpt-6-luna medium | 31 | 53% over 31 positions [6.7%, 80%] | – | 54% over 15 positions [0%, 100%] |
| Cross-model | gpt-6-luna high vs gpt-6-luna off | 5 | 60% over 5 positions [0%, 75%] | – | – |
| Cross-model | gpt-6-luna high vs gpt-6-luna xhigh | 3 | 67% over 3 positions [67%, 67%] | – | – |
| Cross-model | gpt-6-luna low vs gpt-6-luna max | 15 | 40% over 15 positions [0%, 75%] | – | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6-luna low vs gpt-6-luna medium | 24 | 58% over 24 positions [25%, 78%] | 0% over 1 positions [0%, 0%] | 78% over 12 positions [0%, 100%] |
| Cross-model | gpt-6-luna low vs gpt-6-luna off | 9 | 56% over 9 positions [56%, 56%] | – | – |
| Cross-model | gpt-6-luna low vs gpt-6-luna xhigh | 8 | 50% over 8 positions [40%, 67%] | – | – |
| Cross-model | gpt-6-luna max vs gpt-6-luna medium | 27 | 56% over 27 positions [38%, 68%] | 100% over 4 positions [100%, 100%] | 76% over 15 positions [0%, 100%] |
| Cross-model | gpt-6-luna max vs gpt-6-luna off | 9 | 56% over 9 positions [50%, 60%] | – | – |
| Cross-model | gpt-6-luna max vs gpt-6-luna xhigh | 17 | 88% over 17 positions [88%, 88%] | – | – |
| Cross-model | gpt-6-luna medium vs gpt-6-luna off | 24 | 67% over 24 positions [25%, 83%] | 71% over 7 positions [0%, 100%] | – |
| Cross-model | gpt-6-luna medium vs gpt-6-luna xhigh | 22 | 68% over 22 positions [25%, 100%] | 0% over 2 positions [0%, 0%] | – |
| Cross-model | gpt-6-luna off vs gpt-6-luna xhigh | 8 | 63% over 8 positions [50%, 75%] | – | – |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol low | 0 | – | – | – |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol max | 0 | – | – | – |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol medium | 41 | 91% over 41 positions [0%, 100%] | – | 94% over 18 positions [83%, 100%] |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol xhigh | 22 | 77% over 22 positions [0%, 100%] | – | – |
| Cross-model | gpt-6.1-sol low vs gpt-6.1-sol max | 33 | 82% over 33 positions [67%, 100%] | – | – |
| Cross-model | gpt-6.1-sol low vs gpt-6.1-sol medium | 45 | 87% over 45 positions [69%, 100%] | – | 86% over 14 positions [50%, 100%] |
| Cross-model | gpt-6.1-sol low vs gpt-6.1-sol xhigh | 0 | – | – | – |
| Cross-model | gpt-6.1-sol max vs gpt-6.1-sol medium | 47 | 84% over 47 positions [63%, 100%] | – | 79% over 14 positions [50%, 100%] |
| Cross-model | gpt-6.1-sol max vs gpt-6.1-sol xhigh | 7 | 86% over 7 positions [86%, 86%] | – | – |
| Cross-model | gpt-6.1-sol medium vs gpt-6.1-sol xhigh | 41 | 74% over 41 positions [50%, 86%] | 93% over 15 positions [83%, 100%] | – |
| Cross-model | gpt-6.1-terra high vs gpt-6.1-terra low | 4 | 75% over 4 positions [75%, 75%] | – | – |
| Cross-model | gpt-6.1-terra high vs gpt-6.1-terra max | 6 | 83% over 6 positions [83%, 83%] | – | – |
| Cross-model | gpt-6.1-terra high vs gpt-6.1-terra medium | 0 | – | – | – |
| Cross-model | gpt-6.1-terra high vs gpt-6.1-terra off | 0 | – | – | – |
| Cross-model | gpt-6.1-terra high vs gpt-6.1-terra xhigh | 0 | – | – | – |
| Cross-model | gpt-6.1-terra low vs gpt-6.1-terra max | 0 | – | – | – |
| Cross-model | gpt-6.1-terra low vs gpt-6.1-terra medium | 0 | – | – | – |
| Cross-model | gpt-6.1-terra low vs gpt-6.1-terra off | 0 | – | – | – |
| Cross-model | gpt-6.1-terra low vs gpt-6.1-terra xhigh | 0 | – | – | – |
| Cross-model | gpt-6.1-terra max vs gpt-6.1-terra medium | 0 | – | – | – |
| Cross-model | gpt-6.1-terra max vs gpt-6.1-terra off | 0 | – | – | – |
| Cross-model | gpt-6.1-terra max vs gpt-6.1-terra xhigh | 0 | – | – | – |
| Cross-model | gpt-6.1-terra medium vs gpt-6.1-terra off | 0 | – | – | – |
| Cross-model | gpt-6.1-terra medium vs gpt-6.1-terra xhigh | 20 | 90% over 20 positions [90%, 90%] | – | – |
| Cross-model | gpt-6.1-terra off vs gpt-6.1-terra xhigh | 0 | – | – | – |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 low | 195 | 69% over 195 positions [65%, 75%] | 66% over 60 positions [62%, 76%] | 70% over 71 positions [62%, 78%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 medium | 170 | 70% over 170 positions [64%, 77%] | 72% over 55 positions [64%, 82%] | 74% over 66 positions [65%, 84%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 minimal | 169 | 69% over 169 positions [65%, 76%] | 67% over 59 positions [59%, 77%] | 74% over 75 positions [69%, 83%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 off | 147 | 67% over 147 positions [60%, 72%] | 69% over 50 positions [63%, 79%] | 71% over 76 positions [60%, 79%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 medium | 186 | 70% over 186 positions [64%, 74%] | 70% over 69 positions [61%, 77%] | 74% over 78 positions [66%, 83%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 minimal | 160 | 64% over 160 positions [61%, 72%] | 66% over 61 positions [58%, 76%] | 72% over 78 positions [68%, 82%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 off | 162 | 61% over 162 positions [56%, 68%] | 71% over 61 positions [63%, 80%] | 69% over 74 positions [59%, 76%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 medium vs claude-haiku-4-5-20251001 minimal | 173 | 69% over 173 positions [66%, 75%] | 77% over 70 positions [65%, 86%] | 73% over 70 positions [68%, 84%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 medium vs claude-haiku-4-5-20251001 off | 128 | 67% over 128 positions [59%, 72%] | 75% over 54 positions [67%, 85%] | 69% over 69 positions [59%, 77%] |
| Haiku 4.5 efforts | claude-haiku-4-5-20251001 minimal vs claude-haiku-4-5-20251001 off | 137 | 59% over 137 positions [55%, 68%] | 77% over 73 positions [70%, 87%] | 65% over 62 positions [54%, 76%] |
| Haiku 5.5 efforts | claude-haiku-5-5 high vs claude-haiku-5-5 low | 442 | 79% over 442 positions [77%, 83%] | 80% over 141 positions [74%, 87%] | 82% over 178 positions [78%, 87%] |
| Haiku 5.5 efforts | claude-haiku-5-5 high vs claude-haiku-5-5 max | 324 | 77% over 324 positions [72%, 81%] | 81% over 102 positions [75%, 88%] | 82% over 147 positions [77%, 88%] |
| Haiku 5.5 efforts | claude-haiku-5-5 high vs claude-haiku-5-5 medium | 356 | 79% over 356 positions [76%, 83%] | 85% over 146 positions [79%, 90%] | 84% over 161 positions [79%, 88%] |
| Haiku 5.5 efforts | claude-haiku-5-5 high vs claude-haiku-5-5 off | 251 | 67% over 251 positions [61%, 72%] | 79% over 90 positions [75%, 89%] | 77% over 114 positions [70%, 85%] |
| Haiku 5.5 efforts | claude-haiku-5-5 high vs claude-haiku-5-5 xhigh | 395 | 82% over 395 positions [79%, 85%] | 81% over 136 positions [76%, 88%] | 84% over 187 positions [80%, 88%] |
| Haiku 5.5 efforts | claude-haiku-5-5 low vs claude-haiku-5-5 max | 234 | 67% over 234 positions [62%, 73%] | 80% over 99 positions [75%, 88%] | 82% over 106 positions [78%, 89%] |
| Haiku 5.5 efforts | claude-haiku-5-5 low vs claude-haiku-5-5 medium | 399 | 78% over 399 positions [75%, 81%] | 81% over 157 positions [78%, 88%] | 82% over 150 positions [78%, 87%] |
| Haiku 5.5 efforts | claude-haiku-5-5 low vs claude-haiku-5-5 off | 265 | 69% over 265 positions [64%, 74%] | 81% over 109 positions [78%, 87%] | 79% over 118 positions [72%, 84%] |
| Haiku 5.5 efforts | claude-haiku-5-5 low vs claude-haiku-5-5 xhigh | 299 | 71% over 299 positions [68%, 77%] | 81% over 144 positions [76%, 89%] | 80% over 146 positions [76%, 85%] |
| Haiku 5.5 efforts | claude-haiku-5-5 max vs claude-haiku-5-5 medium | 257 | 70% over 257 positions [67%, 75%] | 81% over 107 positions [77%, 87%] | 83% over 113 positions [78%, 88%] |
| Haiku 5.5 efforts | claude-haiku-5-5 max vs claude-haiku-5-5 off | 172 | 59% over 172 positions [53%, 65%] | 80% over 79 positions [74%, 89%] | 74% over 86 positions [67%, 83%] |
| Haiku 5.5 efforts | claude-haiku-5-5 max vs claude-haiku-5-5 xhigh | 381 | 81% over 381 positions [77%, 84%] | 83% over 152 positions [79%, 88%] | 83% over 172 positions [79%, 87%] |
| Haiku 5.5 efforts | claude-haiku-5-5 medium vs claude-haiku-5-5 off | 257 | 67% over 257 positions [62%, 73%] | 84% over 105 positions [79%, 88%] | 77% over 117 positions [71%, 83%] |
| Haiku 5.5 efforts | claude-haiku-5-5 medium vs claude-haiku-5-5 xhigh | 289 | 76% over 289 positions [73%, 80%] | 84% over 117 positions [79%, 88%] | 84% over 145 positions [79%, 88%] |
| Haiku 5.5 efforts | claude-haiku-5-5 off vs claude-haiku-5-5 xhigh | 188 | 63% over 188 positions [57%, 68%] | 76% over 86 positions [68%, 85%] | 84% over 105 positions [77%, 88%] |
| Luna efforts | gpt-6-luna high vs gpt-6-luna low | 179 | 54% over 179 positions [49%, 61%] | 67% over 76 positions [59%, 75%] | 70% over 88 positions [59%, 76%] |
| Luna efforts | gpt-6-luna high vs gpt-6-luna max | 212 | 69% over 212 positions [64%, 74%] | 67% over 71 positions [59%, 76%] | 75% over 83 positions [72%, 83%] |
| Luna efforts | gpt-6-luna high vs gpt-6-luna medium | 194 | 66% over 194 positions [59%, 71%] | 64% over 74 positions [58%, 73%] | 72% over 74 positions [64%, 78%] |
| Luna efforts | gpt-6-luna high vs gpt-6-luna off | 145 | 52% over 145 positions [47%, 59%] | 62% over 64 positions [57%, 72%] | 71% over 76 positions [61%, 77%] |
| Luna efforts | gpt-6-luna high vs gpt-6-luna xhigh | 245 | 71% over 245 positions [64%, 75%] | 65% over 77 positions [58%, 74%] | 72% over 90 positions [64%, 79%] |
| Luna efforts | gpt-6-luna low vs gpt-6-luna max | 165 | 50% over 165 positions [46%, 58%] | 67% over 73 positions [56%, 74%] | 81% over 77 positions [75%, 87%] |
| Luna efforts | gpt-6-luna low vs gpt-6-luna medium | 215 | 63% over 215 positions [57%, 69%] | 66% over 90 positions [57%, 74%] | 71% over 82 positions [63%, 78%] |
| Luna efforts | gpt-6-luna low vs gpt-6-luna off | 278 | 68% over 278 positions [63%, 73%] | 62% over 93 positions [54%, 70%] | 75% over 100 positions [65%, 81%] |
| Luna efforts | gpt-6-luna low vs gpt-6-luna xhigh | 159 | 55% over 159 positions [48%, 61%] | 72% over 85 positions [60%, 78%] | 73% over 71 positions [63%, 81%] |
| Luna efforts | gpt-6-luna max vs gpt-6-luna medium | 190 | 65% over 190 positions [60%, 71%] | 82% over 84 positions [76%, 87%] | 71% over 70 positions [63%, 78%] |
| Luna efforts | gpt-6-luna max vs gpt-6-luna off | 175 | 59% over 175 positions [54%, 65%] | 82% over 70 positions [75%, 87%] | 72% over 78 positions [62%, 78%] |
| Luna efforts | gpt-6-luna max vs gpt-6-luna xhigh | 263 | 78% over 263 positions [72%, 81%] | 80% over 95 positions [76%, 85%] | 74% over 91 positions [66%, 82%] |
| Luna efforts | gpt-6-luna medium vs gpt-6-luna off | 217 | 67% over 217 positions [62%, 73%] | 73% over 88 positions [64%, 79%] | 70% over 88 positions [58%, 77%] |
| Luna efforts | gpt-6-luna medium vs gpt-6-luna xhigh | 182 | 65% over 182 positions [56%, 70%] | 72% over 70 positions [65%, 80%] | 69% over 66 positions [60%, 79%] |
| Luna efforts | gpt-6-luna off vs gpt-6-luna xhigh | 141 | 54% over 141 positions [49%, 61%] | 74% over 75 positions [63%, 81%] | 78% over 69 positions [66%, 84%] |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 low | 150 | 86% over 150 positions [78%, 90%] | 93% over 99 positions [77%, 100%] | 100% over 2 positions [100%, 100%] |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 max | 0 | – | – | – |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 medium | 353 | 90% over 353 positions [88%, 93%] | 91% over 146 positions [73%, 98%] | 91% over 170 positions [88%, 95%] |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 off | 0 | – | – | – |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 xhigh | 203 | 86% over 203 positions [83%, 90%] | 94% over 108 positions [78%, 100%] | 87% over 116 positions [76%, 93%] |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 max | 9 | 78% over 9 positions [78%, 78%] | – | 100% over 4 positions [100%, 100%] |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 medium | 192 | 85% over 192 positions [81%, 89%] | 100% over 1 positions [100%, 100%] | 96% over 106 positions [92%, 99%] |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 off | 5 | 80% over 5 positions [80%, 80%] | – | – |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 xhigh | 139 | 83% over 139 positions [74%, 89%] | – | 91% over 88 positions [78%, 98%] |
| Opus efforts | claude-opus-5-5 max vs claude-opus-5-5 medium | 6 | 67% over 6 positions [0%, 67%] | 100% over 1 positions [100%, 100%] | – |
| Opus efforts | claude-opus-5-5 max vs claude-opus-5-5 off | 0 | – | – | – |
| Opus efforts | claude-opus-5-5 max vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Opus efforts | claude-opus-5-5 medium vs claude-opus-5-5 off | 2 | 0% over 2 positions [0%, 0%] | – | – |
| Opus efforts | claude-opus-5-5 medium vs claude-opus-5-5 xhigh | 294 | 89% over 294 positions [87%, 91%] | 92% over 158 positions [90%, 97%] | 89% over 119 positions [79%, 97%] |
| Opus efforts | claude-opus-5-5 off vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Sol efforts | gpt-6.1-sol high vs gpt-6.1-sol low | 446 | 89% over 446 positions [86%, 91%] | 92% over 221 positions [88%, 94%] | 93% over 214 positions [90%, 95%] |
| Sol efforts | gpt-6.1-sol high vs gpt-6.1-sol max | 328 | 86% over 328 positions [83%, 88%] | 90% over 182 positions [87%, 94%] | 90% over 188 positions [88%, 94%] |
| Sol efforts | gpt-6.1-sol high vs gpt-6.1-sol medium | 455 | 91% over 455 positions [88%, 92%] | 91% over 219 positions [87%, 93%] | 92% over 220 positions [90%, 95%] |
| Sol efforts | gpt-6.1-sol high vs gpt-6.1-sol xhigh | 434 | 88% over 434 positions [86%, 91%] | 92% over 239 positions [88%, 94%] | 89% over 240 positions [83%, 92%] |
| Sol efforts | gpt-6.1-sol low vs gpt-6.1-sol max | 259 | 84% over 259 positions [82%, 88%] | 93% over 172 positions [89%, 95%] | 91% over 168 positions [89%, 95%] |
| Sol efforts | gpt-6.1-sol low vs gpt-6.1-sol medium | 524 | 92% over 524 positions [90%, 94%] | 92% over 244 positions [89%, 94%] | 91% over 216 positions [89%, 94%] |
| Sol efforts | gpt-6.1-sol low vs gpt-6.1-sol xhigh | 340 | 85% over 340 positions [82%, 88%] | 94% over 204 positions [91%, 96%] | 90% over 197 positions [84%, 93%] |
| Sol efforts | gpt-6.1-sol max vs gpt-6.1-sol medium | 320 | 87% over 320 positions [84%, 90%] | 91% over 184 positions [89%, 95%] | 92% over 160 positions [89%, 96%] |
| Sol efforts | gpt-6.1-sol max vs gpt-6.1-sol xhigh | 406 | 89% over 406 positions [86%, 91%] | 89% over 224 positions [87%, 93%] | 88% over 217 positions [83%, 91%] |
| Sol efforts | gpt-6.1-sol medium vs gpt-6.1-sol xhigh | 383 | 88% over 383 positions [85%, 90%] | 93% over 204 positions [91%, 96%] | 89% over 192 positions [83%, 92%] |
| Sonnet efforts | claude-sonnet-5-5 high vs claude-sonnet-5-5 low | 406 | 85% over 406 positions [82%, 88%] | 87% over 203 positions [84%, 92%] | 87% over 193 positions [83%, 90%] |
| Sonnet efforts | claude-sonnet-5-5 high vs claude-sonnet-5-5 max | 210 | 76% over 210 positions [73%, 80%] | 94% over 141 positions [92%, 97%] | 90% over 126 positions [88%, 95%] |
| Sonnet efforts | claude-sonnet-5-5 high vs claude-sonnet-5-5 medium | 403 | 86% over 403 positions [84%, 90%] | 90% over 219 positions [88%, 94%] | 89% over 197 positions [86%, 93%] |
| Sonnet efforts | claude-sonnet-5-5 high vs claude-sonnet-5-5 off | 345 | 84% over 345 positions [80%, 88%] | 89% over 159 positions [86%, 93%] | 89% over 178 positions [86%, 94%] |
| Sonnet efforts | claude-sonnet-5-5 high vs claude-sonnet-5-5 xhigh | 406 | 83% over 406 positions [83%, 88%] | 92% over 204 positions [89%, 95%] | 89% over 203 positions [87%, 93%] |
| Sonnet efforts | claude-sonnet-5-5 low vs claude-sonnet-5-5 max | 180 | 73% over 180 positions [67%, 76%] | 86% over 108 positions [81%, 90%] | 90% over 109 positions [87%, 94%] |
| Sonnet efforts | claude-sonnet-5-5 low vs claude-sonnet-5-5 medium | 488 | 89% over 488 positions [86%, 90%] | 87% over 214 positions [84%, 90%] | 90% over 215 positions [87%, 93%] |
| Sonnet efforts | claude-sonnet-5-5 low vs claude-sonnet-5-5 off | 371 | 84% over 371 positions [81%, 87%] | 88% over 192 positions [84%, 91%] | 89% over 221 positions [87%, 93%] |
| Sonnet efforts | claude-sonnet-5-5 low vs claude-sonnet-5-5 xhigh | 296 | 81% over 296 positions [78%, 85%] | 87% over 155 positions [83%, 92%] | 90% over 146 positions [88%, 94%] |
| Sonnet efforts | claude-sonnet-5-5 max vs claude-sonnet-5-5 medium | 199 | 72% over 199 positions [69%, 77%] | 89% over 118 positions [87%, 94%] | 92% over 103 positions [88%, 96%] |
| Sonnet efforts | claude-sonnet-5-5 max vs claude-sonnet-5-5 off | 160 | 66% over 160 positions [63%, 72%] | 88% over 100 positions [85%, 94%] | 92% over 99 positions [88%, 95%] |
| Sonnet efforts | claude-sonnet-5-5 max vs claude-sonnet-5-5 xhigh | 326 | 78% over 326 positions [74%, 82%] | 88% over 147 positions [86%, 93%] | 90% over 153 positions [87%, 93%] |
| Sonnet efforts | claude-sonnet-5-5 medium vs claude-sonnet-5-5 off | 395 | 85% over 395 positions [83%, 89%] | 88% over 199 positions [85%, 92%] | 87% over 212 positions [84%, 91%] |
| Sonnet efforts | claude-sonnet-5-5 medium vs claude-sonnet-5-5 xhigh | 306 | 79% over 306 positions [78%, 84%] | 91% over 164 positions [88%, 95%] | 89% over 164 positions [88%, 94%] |
| Sonnet efforts | claude-sonnet-5-5 off vs claude-sonnet-5-5 xhigh | 271 | 79% over 271 positions [76%, 83%] | 92% over 159 positions [89%, 95%] | 88% over 142 positions [86%, 92%] |
| Terra 6.1 efforts | gpt-6.1-terra high vs gpt-6.1-terra low | 0 | – | – | – |
| Terra 6.1 efforts | gpt-6.1-terra high vs gpt-6.1-terra max | 0 | – | – | – |
| Terra 6.1 efforts | gpt-6.1-terra high vs gpt-6.1-terra medium | 26 | 92% over 26 positions [92%, 92%] | – | – |
| Terra 6.1 efforts | gpt-6.1-terra high vs gpt-6.1-terra off | 0 | – | – | – |
| Terra 6.1 efforts | gpt-6.1-terra high vs gpt-6.1-terra xhigh | 3 | 33% over 3 positions [33%, 33%] | – | – |
| Terra 6.1 efforts | gpt-6.1-terra low vs gpt-6.1-terra max | 0 | – | – | – |
| Terra 6.1 efforts | gpt-6.1-terra low vs gpt-6.1-terra medium | 9 | 89% over 9 positions [89%, 89%] | – | – |
| Terra 6.1 efforts | gpt-6.1-terra low vs gpt-6.1-terra off | 1 | 0% over 1 positions [0%, 0%] | – | – |
| Terra 6.1 efforts | gpt-6.1-terra low vs gpt-6.1-terra xhigh | 0 | – | – | – |
| Terra 6.1 efforts | gpt-6.1-terra max vs gpt-6.1-terra medium | 0 | – | – | – |
| Terra 6.1 efforts | gpt-6.1-terra max vs gpt-6.1-terra off | 0 | – | – | – |
| Terra 6.1 efforts | gpt-6.1-terra max vs gpt-6.1-terra xhigh | 3 | 67% over 3 positions [67%, 67%] | – | – |
| Terra 6.1 efforts | gpt-6.1-terra medium vs gpt-6.1-terra off | 1 | 0% over 1 positions [0%, 0%] | – | – |
| Terra 6.1 efforts | gpt-6.1-terra medium vs gpt-6.1-terra xhigh | 12 | 83% over 12 positions [83%, 83%] | – | – |
| Terra 6.1 efforts | gpt-6.1-terra off vs gpt-6.1-terra xhigh | 0 | – | – | – |
| Terra efforts | gpt-5.6-terra high vs gpt-5.6-terra low | 257 | 76% over 257 positions [71%, 79%] | 75% over 93 positions [69%, 83%] | 74% over 100 positions [63%, 81%] |
| Terra efforts | gpt-5.6-terra high vs gpt-5.6-terra max | 204 | 72% over 204 positions [67%, 78%] | 76% over 95 positions [69%, 84%] | 85% over 112 positions [79%, 91%] |
| Terra efforts | gpt-5.6-terra high vs gpt-5.6-terra medium | 236 | 74% over 236 positions [70%, 79%] | 75% over 92 positions [70%, 84%] | 77% over 115 positions [68%, 83%] |
| Terra efforts | gpt-5.6-terra high vs gpt-5.6-terra xhigh | 224 | 70% over 224 positions [67%, 76%] | 74% over 92 positions [69%, 83%] | 77% over 94 positions [69%, 83%] |
| Terra efforts | gpt-5.6-terra low vs gpt-5.6-terra max | 210 | 70% over 210 positions [64%, 76%] | 74% over 85 positions [62%, 82%] | 82% over 105 positions [76%, 90%] |
| Terra efforts | gpt-5.6-terra low vs gpt-5.6-terra medium | 285 | 78% over 285 positions [73%, 82%] | 74% over 101 positions [64%, 80%] | 77% over 124 positions [67%, 83%] |
| Terra efforts | gpt-5.6-terra low vs gpt-5.6-terra xhigh | 221 | 71% over 221 positions [66%, 77%] | 76% over 85 positions [64%, 82%] | 78% over 93 positions [69%, 85%] |
| Terra efforts | gpt-5.6-terra max vs gpt-5.6-terra medium | 221 | 71% over 221 positions [65%, 76%] | 82% over 100 positions [75%, 90%] | 77% over 106 positions [68%, 83%] |
| Terra efforts | gpt-5.6-terra max vs gpt-5.6-terra xhigh | 227 | 72% over 227 positions [70%, 78%] | 86% over 118 positions [81%, 92%] | 77% over 96 positions [69%, 84%] |
| Terra efforts | gpt-5.6-terra medium vs gpt-5.6-terra xhigh | 192 | 69% over 192 positions [65%, 75%] | 77% over 102 positions [69%, 83%] | 76% over 90 positions [67%, 83%] |

## Code versions

The main rates within each cohort by code version, pooled over models.

| Cohort | Code | Against a known shell | Shots known from a clue | Matches |
|---|---|---|---|---|
| Cross-model | 12e2e3295899 | 7.0% (324/4624) [5.8%, 8.3%] | 25% (1935/7815) [24%, 26%] | 330 |
| Cross-model | 3c9b98f8b3f4 | 4.4% (39/888) [2.5%, 6.8%] | 26% (383/1491) [23%, 29%] | 63 |
| Cross-model | 51b8366684f0 | 7.3% (439/6022) [6.3%, 8.4%] | 25% (2539/10172) [24%, 26%] | 420 |
| Cross-model | 9e7d7ff22891 | 4.0% (68/1685) [2.7%, 5.6%] | 26% (744/2818) [24%, 29%] | 118 |
| Haiku 4.5 efforts | 51b8366684f0 | 17% (19/114) [9.2%, 24%] | 15% (37/251) [13%, 17%] | 12 |
| Haiku 4.5 efforts | 9e7d7ff22891 | 25% (675/2740) [23%, 27%] | 21% (1047/5107) [19%, 22%] | 188 |
| Haiku 5.5 efforts | 51b8366684f0 | 12% (22/188) [7.6%, 16%] | 16% (57/354) [11%, 22%] | 20 |
| Haiku 5.5 efforts | 9e7d7ff22891 | 14% (571/4041) [13%, 16%] | 27% (1812/6646) [26%, 29%] | 280 |
| Luna efforts | 9e7d7ff22891 | 20% (886/4441) [18%, 22%] | 24% (1803/7600) [22%, 25%] | 300 |
| Opus efforts | 12e2e3295899 | 0% (0/102) [0%, 0%] | 23% (42/183) [19%, 29%] | 8 |
| Opus efforts | 9e7d7ff22891 | 0.1% (1/1134) [0%, 0.3%] | 30% (545/1838) [26%, 33%] | 80 |
| Sol efforts | 9e7d7ff22891 | 0.7% (20/2830) [0.4%, 1.0%] | 29% (1337/4690) [27%, 30%] | 200 |
| Sonnet efforts | 51b8366684f0 | 0% (0/55) [0%, 0%] | 24% (22/91) [20%, 26%] | 5 |
| Sonnet efforts | 9e7d7ff22891 | 0.9% (40/4328) [0.6%, 1.3%] | 29% (2020/6969) [28%, 30%] | 295 |
| Terra 6.1 efforts | 12e2e3295899 | 0% (0/227) [0%, 0%] | 30% (107/359) [22%, 37%] | 14 |
| Terra efforts | 9e7d7ff22891 | 4.0% (114/2886) [3.1%, 4.8%] | 25% (1209/4858) [23%, 27%] | 200 |

