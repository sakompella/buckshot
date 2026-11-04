# Beliefs and items

What each model knew about the shotgun when it chose a move, whether it acted on that knowledge, what happened to its items, and whether it chose the same way in the same position. Every judgement uses only the deciding player's own information: the public log and its own clues. Another player's clues and the hidden shell order never enter. The tables call these choice patterns. A move is called dominated only where the player's own information shows it.

DeepSeek (`deepseek-v4.1-flash`) is left out entirely. Every match with a DeepSeek seat is dropped from every table below, including its opponents' moves in those matches.

## Summary

Scope: the 2,895 scored matches of the ten cohorts in the Coverage table, with no DeepSeek seat, from the knowledge database rebuilt on 2026-11-04 from the analysis database (2,915 completed matches, now including tournaments 7 and 9). The cohorts are Cross-model (every match between different models, 1,255 matches) and one effort cohort per model (every match of that model against itself, 1,640 matches in all).

The prose summary written for an earlier 2,471-match scope is removed. Its figures were typed by hand, were not regenerated and cannot be reproduced from the tables below, so they would describe a scope this page no longer has. The tables are the findings: each rate is numerator/denominator with a 95% interval over seed blocks. Small cohorts (Astra efforts has 6 matches, Terra 6.1 efforts 16) and Cross-model pairings with few seed blocks have wide rows that say little on their own.

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
- On 148,579 checked decisions of the 2,958 replay-validated matches of the 2026-11-04 snapshot (`--verify`, 38 minutes), the true gun was one of the orders the player's log allows (0 outside), and every chamber the log called certain was right (0 wrong). The true gun was read only for this check and is not stored. Earlier builds were verified the same way on their own scope.
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

    nice -n 10 bun scripts/arena-knowledge.ts --db <buckshot.sqlite> --out <derived>/knowledge.sqlite --verify   # about 38 minutes for 2,958 matches
    nice -n 10 bun scripts/arena-knowledge-report.ts --db <derived>/knowledge.sqlite                            # about 3 minutes
    bun scripts/arena-knowledge.ts --db <buckshot.sqlite> --trace <match name>                                 # one match, decision by decision

The knowledge script always rebuilds its whole output (it drops its tables first), about 34 minutes for 2,596 matches without `--verify` (the 2026-10-30 size). The 2026-10-30 rebuild reproduced every decision, clue, item, death and player row of the 2026-10-25 database exactly and added the 62 new matches (3,182 agent decisions); only the `cohort` label of every match differs, because the earlier file used older cohort names.

# Tables

Generated by `web/scripts/arena-knowledge-report.ts` from the knowledge database. A cohort is one kind of comparison, pooled over every tournament: Cross-model (every match between different models) or one model's efforts (every match of that model against itself).

<!-- beliefs:start -->
## Coverage

| Cohort | Matches | Seed blocks | Agent decisions | Shots | Shots with a certain chamber | Code versions |
|---|---|---|---|---|---|---|
| Cross-model | 1255 | 680 | 62889 | 30163 | 18039 | 12e2e3295899, 29f99c6dce47, 2a5f469d8793, 3c9b98f8b3f4, 51b8366684f0, 9e7d7ff22891, b72cdce126f2 |
| Astra efforts | 6 | 4 | 242 | 117 | 72 | 12e2e3295899, 2a5f469d8793, b72cdce126f2 |
| Haiku 4.5 efforts | 200 | 100 | 10636 | 5358 | 2854 | 51b8366684f0, 9e7d7ff22891 |
| Haiku 5.5 efforts | 300 | 150 | 15078 | 7000 | 4229 | 51b8366684f0, 9e7d7ff22891 |
| Luna efforts | 300 | 150 | 17231 | 7600 | 4441 | 9e7d7ff22891 |
| Opus efforts | 118 | 60 | 5861 | 2763 | 1747 | 12e2e3295899, 9e7d7ff22891, b72cdce126f2 |
| Sol efforts | 200 | 100 | 9726 | 4690 | 2830 | 9e7d7ff22891 |
| Sonnet efforts | 300 | 150 | 14710 | 7060 | 4383 | 51b8366684f0, 9e7d7ff22891 |
| Terra efforts | 200 | 100 | 9730 | 4858 | 2886 | 9e7d7ff22891 |
| gpt-6.1-terra efforts | 16 | 9 | 808 | 412 | 261 | 12e2e3295899, 2a5f469d8793 |

## Shots with a certain chamber

Shooting the opponent on a known blank and yourself on a known live. Certainty is the player's own: the public log, its own clues, or both. In the replays a blank shot at yourself always kept the move, also across a reload, and a blank shot at the opponent always passed it, so the blank columns split the gun's last shell from the rest.

### Cross-model

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-haiku-4-5-20251001 high | 37% (19/52) [16%, 58%] | 55% (16/29) [38%, 72%] | 4.4% (4/91) [1.1%, 8.4%] |
| claude-haiku-4-5-20251001 low | 19% (12/62) [8.3%, 34%] | 59% (20/34) [38%, 78%] | 5.2% (7/135) [1.4%, 10%] |
| claude-haiku-4-5-20251001 medium | 31% (121/392) [25%, 37%] | 63% (114/182) [54%, 71%] | 4.8% (37/767) [3.1%, 6.8%] |
| claude-haiku-4-5-20251001 minimal | 36% (20/56) [22%, 48%] | 78% (28/36) [68%, 88%] | 5.2% (7/134) [2.2%, 8.3%] |
| claude-haiku-4-5-20251001 off | 40% (18/45) [25%, 56%] | 83% (15/18) [67%, 96%] | 10% (6/60) [3.7%, 17%] |
| claude-haiku-5-5 high | 15% (6/40) [5.4%, 23%] | 75% (24/32) [53%, 97%] | 0.6% (1/158) [0%, 2.2%] |
| claude-haiku-5-5 low | 21% (18/84) [12%, 32%] | 77% (37/48) [62%, 91%] | 0.7% (2/300) [0%, 1.7%] |
| claude-haiku-5-5 max | 5.0% (1/20) [0%, 13%] | 50% (3/6) [17%, 83%] | 0% (0/47) [0%, 0%] |
| claude-haiku-5-5 medium | 18% (55/308) [13%, 23%] | 75% (122/163) [66%, 83%] | 0.5% (5/1009) [0.1%, 0.9%] |
| claude-haiku-5-5 off | 46% (33/71) [34%, 61%] | 81% (59/73) [71%, 91%] | 1.1% (3/285) [0%, 2.4%] |
| claude-haiku-5-5 xhigh | 11% (3/28) [0%, 21%] | 89% (8/9) [75%, 100%] | 0% (0/77) [0%, 0%] |
| claude-opus-5-5 high | 0% (0/16) [0%, 0%] | 0% (0/13) [0%, 0%] | 0% (0/71) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/23) [0%, 0%] | 0% (0/11) [0%, 0%] | 0% (0/74) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/14) [0%, 0%] | 0% (0/13) [0%, 0%] | 0% (0/55) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/396) [0%, 0%] | 1.2% (2/168) [0%, 3.1%] | 0.1% (1/1040) [0%, 0.3%] |
| claude-opus-5-5 off | 0% (0/40) [0%, 0%] | 0% (0/13) [0%, 0%] | 0% (0/94) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/133) [0%, 0%] | 0% (0/53) [0%, 0%] | 0% (0/317) [0%, 0%] |
| claude-sonnet-5-5 high | 0% (0/36) [0%, 0%] | 0% (0/16) [0%, 0%] | 0.9% (1/114) [0%, 2.9%] |
| claude-sonnet-5-5 low | 0% (0/34) [0%, 0%] | 6.7% (1/15) [0%, 16%] | 0% (0/102) [0%, 0%] |
| claude-sonnet-5-5 max | 1.5% (1/68) [0%, 5.1%] | 0% (0/44) [0%, 0%] | 0% (0/187) [0%, 0%] |
| claude-sonnet-5-5 medium | 0.6% (2/336) [0%, 1.5%] | 8.2% (9/110) [3.5%, 13%] | 0.8% (8/998) [0.3%, 1.4%] |
| claude-sonnet-5-5 off | 6.5% (2/31) [0%, 16%] | 32% (6/19) [0%, 59%] | 2.5% (3/120) [0%, 6.1%] |
| claude-sonnet-5-5 xhigh | 0% (0/32) [0%, 0%] | 0% (0/22) [0%, 0%] | 0% (0/126) [0%, 0%] |
| gpt-5.6-terra high | 0% (0/28) [0%, 0%] | 8.3% (1/12) [0%, 15%] | 4.2% (2/48) [0%, 8.7%] |
| gpt-5.6-terra low | 0% (0/20) [0%, 0%] | 17% (2/12) [0%, 50%] | 2.0% (1/49) [0%, 8.1%] |
| gpt-5.6-terra max | 0% (0/21) [0%, 0%] | 7.1% (1/14) [0%, 19%] | 0% (0/50) [0%, 0%] |
| gpt-5.6-terra medium | 5.1% (17/332) [2.9%, 7.6%] | 13% (24/189) [7.7%, 19%] | 0.9% (7/748) [0.3%, 1.6%] |
| gpt-5.6-terra xhigh | 0% (0/32) [0%, 0%] | 0% (0/16) [0%, 0%] | 0% (0/57) [0%, 0%] |
| gpt-6-astra high | 0% (0/34) [0%, 0%] | 0% (0/19) [0%, 0%] | 0% (0/82) [0%, 0%] |
| gpt-6-astra low | 0% (0/19) [0%, 0%] | 20% (2/10) [0%, 67%] | 0% (0/64) [0%, 0%] |
| gpt-6-astra medium | 0.8% (3/394) [0%, 1.7%] | 1.3% (3/226) [0%, 3.0%] | 0% (0/1175) [0%, 0%] |
| gpt-6-astra off | 0% (0/30) [0%, 0%] | 27% (4/15) [0%, 57%] | 0% (0/92) [0%, 0%] |
| gpt-6-luna high | 6.5% (2/31) [0%, 13%] | 43% (3/7) [13%, 80%] | 6.5% (4/62) [2.1%, 11%] |
| gpt-6-luna low | 12% (2/17) [0%, 24%] | 56% (5/9) [29%, 80%] | 24% (7/29) [9.5%, 50%] |
| gpt-6-luna max | 8.0% (2/25) [0%, 18%] | 11% (1/9) [0%, 38%] | 2.0% (1/51) [0%, 5.7%] |
| gpt-6-luna medium | 25% (92/361) [21%, 31%] | 50% (88/176) [43%, 58%] | 14% (97/697) [11%, 17%] |
| gpt-6-luna off | 33% (6/18) [0%, 60%] | 78% (7/9) [60%, 100%] | 24% (9/37) [20%, 29%] |
| gpt-6-luna xhigh | 0% (0/28) [0%, 0%] | 22% (4/18) [0%, 63%] | 5.7% (4/70) [1.9%, 8.2%] |
| gpt-6.1-sol high | 0% (0/36) [0%, 0%] | 6.3% (1/16) [0%, 21%] | 0% (0/97) [0%, 0%] |
| gpt-6.1-sol low | 3.1% (1/32) [0%, 12%] | 14% (1/7) [0%, 38%] | 0% (0/78) [0%, 0%] |
| gpt-6.1-sol max | 1.5% (1/65) [0%, 5.3%] | 0% (0/42) [0%, 0%] | 0% (0/195) [0%, 0%] |
| gpt-6.1-sol medium | 0.9% (3/336) [0%, 2.0%] | 5.0% (7/141) [1.4%, 9.6%] | 0% (0/920) [0%, 0%] |
| gpt-6.1-sol xhigh | 0% (0/41) [0%, 0%] | 0% (0/26) [0%, 0%] | 0% (0/89) [0%, 0%] |
| gpt-6.1-terra high | 0% (0/27) [0%, 0%] | 0% (0/13) [0%, 0%] | 0% (0/70) [0%, 0%] |
| gpt-6.1-terra low | 9.5% (2/21) [0%, 24%] | 10% (1/10) [0%, 38%] | 0% (0/81) [0%, 0%] |
| gpt-6.1-terra max | 0% (0/36) [0%, 0%] | 0% (0/23) [0%, 0%] | 0% (0/91) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/25) [0%, 0%] | 0% (0/8) [0%, 0%] | 0% (0/75) [0%, 0%] |
| gpt-6.1-terra off | 3.6% (1/28) [0%, 14%] | 14% (1/7) [0%, 27%] | 0% (0/61) [0%, 0%] |
| gpt-6.1-terra xhigh | 0% (0/28) [0%, 0%] | 13% (1/8) [0%, 43%] | 0% (0/59) [0%, 0%] |

### Astra efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| gpt-6-astra high | 0% (0/4) [0%, 0%] | 0% (0/2) [0%, 0%] | 0% (0/12) [0%, 0%] |
| gpt-6-astra low | 0% (0/5) [0%, 0%] | 0% (0/3) [0%, 0%] | 0% (0/11) [0%, 0%] |
| gpt-6-astra medium | 0% (0/5) [0%, 0%] | 0% (0/2) [0%, 0%] | 0% (0/20) [0%, 0%] |
| gpt-6-astra off | 0% (0/5) [0%, 0%] | – | 0% (0/3) [0%, 0%] |

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
| claude-opus-5-5 high | 0% (0/85) [0%, 0%] | 0% (0/36) [0%, 0%] | 0% (0/185) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/60) [0%, 0%] | 4.0% (1/25) [0%, 12%] | 0% (0/158) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/55) [0%, 0%] | 0% (0/16) [0%, 0%] | 0% (0/186) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/134) [0%, 0%] | 2.0% (1/50) [0%, 6.0%] | 0% (0/336) [0%, 0%] |
| claude-opus-5-5 off | 0% (0/5) [0%, 0%] | 0% (0/3) [0%, 0%] | 0% (0/33) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/98) [0%, 0%] | 2.3% (1/43) [0%, 7.3%] | 0% (0/239) [0%, 0%] |

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

### Terra efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| gpt-5.6-terra high | 4.7% (7/150) [1.3%, 9.2%] | 14% (12/87) [7.5%, 23%] | 2.7% (9/336) [1.2%, 4.3%] |
| gpt-5.6-terra low | 7.0% (9/128) [2.3%, 12%] | 18% (16/89) [9.5%, 28%] | 2.7% (9/336) [1.1%, 4.7%] |
| gpt-5.6-terra max | 1.8% (3/171) [0%, 3.8%] | 3.7% (4/108) [0.8%, 7.1%] | 0.3% (1/358) [0%, 0.9%] |
| gpt-5.6-terra medium | 9.8% (13/132) [5.0%, 16%] | 12% (8/67) [5.5%, 20%] | 1.5% (5/326) [0.3%, 2.9%] |
| gpt-5.6-terra xhigh | 3.6% (6/165) [0.8%, 7.0%] | 9.6% (8/83) [4.1%, 17%] | 1.1% (4/350) [0.3%, 2.4%] |

### gpt-6.1-terra efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| gpt-6.1-terra high | 0% (0/12) [0%, 0%] | 0% (0/1) [0%, 0%] | 0% (0/19) [0%, 0%] |
| gpt-6.1-terra low | 0% (0/14) [0%, 0%] | 0% (0/4) [0%, 0%] | 0% (0/27) [0%, 0%] |
| gpt-6.1-terra max | 0% (0/5) [0%, 0%] | 0% (0/5) [0%, 0%] | 0% (0/13) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/17) [0%, 0%] | 0% (0/7) [0%, 0%] | 0% (0/44) [0%, 0%] |
| gpt-6.1-terra off | 0% (0/12) [0%, 0%] | 0% (0/4) [0%, 0%] | 0% (0/27) [0%, 0%] |
| gpt-6.1-terra xhigh | 0% (0/13) [0%, 0%] | 0% (0/3) [0%, 0%] | 0% (0/34) [0%, 0%] |

## By where the certainty came from

Shots against the known shell, by source. A clue taken with adrenaline counts with its item.

| Cohort | public | glass | phone | combined |
|---|---|---|---|---|
| Cross-model | 9.9% (1019/10288) [9.0%, 11%] | 1.8% (106/5754) [1.4%, 2.3%] | 7.7% (150/1939) [6.4%, 9.2%] | 10% (6/58) [2.0%, 19%] |
| Astra efforts | 0% (0/31) [0%, 0%] | 0% (0/24) [0%, 0%] | 0% (0/17) [0%, 0%] | – |
| Haiku 4.5 efforts | 29% (513/1770) [27%, 32%] | 12% (102/886) [9.0%, 14%] | 40% (79/196) [33%, 47%] | 0% (0/2) [0%, 0%] |
| Haiku 5.5 efforts | 20% (479/2360) [18%, 22%] | 4.0% (54/1340) [2.8%, 5.3%] | 11% (59/518) [7.9%, 15%] | 9.1% (1/11) [0%, 25%] |
| Luna efforts | 27% (705/2638) [24%, 29%] | 2.9% (39/1350) [1.9%, 3.9%] | 32% (141/442) [28%, 36%] | 9.1% (1/11) [0%, 20%] |
| Opus efforts | 0.3% (3/917) [0%, 0.7%] | 0% (0/574) [0%, 0%] | 0% (0/249) [0%, 0%] | 0% (0/7) [0%, 0%] |
| Sol efforts | 1.3% (20/1493) [0.8%, 2.0%] | 0% (0/885) [0%, 0%] | 0% (0/446) [0%, 0%] | 0% (0/6) [0%, 0%] |
| Sonnet efforts | 1.4% (33/2341) [0.9%, 2.1%] | 0% (0/1441) [0%, 0%] | 1.2% (7/586) [0.4%, 2.1%] | 0% (0/15) [0%, 0%] |
| Terra efforts | 5.4% (90/1677) [4.2%, 6.6%] | 0.1% (1/937) [0%, 0.3%] | 8.6% (23/267) [5.4%, 13%] | 0% (0/5) [0%, 0%] |
| gpt-6.1-terra efforts | 0% (0/134) [0%, 0%] | 0% (0/88) [0%, 0%] | 0% (0/38) [0%, 0%] | 0% (0/1) [0%, 0%] |

### Cross-model, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-haiku-4-5-20251001 high | 11% (6/53) [3.2%, 22%] | 43% (6/14) [17%, 73%] |
| claude-haiku-4-5-20251001 low | 6.0% (5/83) [2.2%, 11%] | 15% (2/13) [0%, 38%] |
| claude-haiku-4-5-20251001 medium | 12% (53/450) [8.4%, 16%] | 28% (27/97) [20%, 37%] |
| claude-haiku-4-5-20251001 minimal | 8.0% (6/75) [2.3%, 15%] | 38% (5/13) [14%, 67%] |
| claude-haiku-4-5-20251001 off | 14% (6/43) [2.8%, 28%] | 27% (3/11) [10%, 50%] |
| claude-haiku-5-5 high | 1.7% (1/59) [0%, 5.7%] | 0% (0/24) [0%, 0%] |
| claude-haiku-5-5 low | 0.8% (1/120) [0%, 2.7%] | 14% (7/50) [4.8%, 23%] |
| claude-haiku-5-5 max | 0% (0/18) [0%, 0%] | 0% (0/11) [0%, 0%] |
| claude-haiku-5-5 medium | 3.6% (15/420) [1.9%, 5.2%] | 5.8% (10/171) [2.8%, 9.3%] |
| claude-haiku-5-5 off | 3.1% (4/129) [0.8%, 5.9%] | 23% (11/47) [12%, 36%] |
| claude-haiku-5-5 xhigh | 0% (0/36) [0%, 0%] | 0% (0/13) [0%, 0%] |
| claude-opus-5-5 high | 0% (0/31) [0%, 0%] | 0% (0/12) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/38) [0%, 0%] | 0% (0/9) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/24) [0%, 0%] | 0% (0/6) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/444) [0%, 0%] | 0.5% (1/188) [0%, 1.7%] |
| claude-opus-5-5 off | 0% (0/54) [0%, 0%] | 0% (0/14) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/147) [0%, 0%] | 0% (0/57) [0%, 0%] |
| claude-sonnet-5-5 high | 0% (0/42) [0%, 0%] | 0% (0/29) [0%, 0%] |
| claude-sonnet-5-5 low | 0% (0/46) [0%, 0%] | 0% (0/23) [0%, 0%] |
| claude-sonnet-5-5 max | 0% (0/94) [0%, 0%] | 2.1% (1/48) [0%, 7.3%] |
| claude-sonnet-5-5 medium | 0% (0/483) [0%, 0%] | 1.3% (2/156) [0%, 3.2%] |
| claude-sonnet-5-5 off | 0% (0/52) [0%, 0%] | 10% (1/10) [0%, 33%] |
| claude-sonnet-5-5 xhigh | 0% (0/51) [0%, 0%] | 0% (0/22) [0%, 0%] |
| gpt-5.6-terra high | 0% (0/32) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-5.6-terra low | 0% (0/30) [0%, 0%] | 0% (0/4) [0%, 0%] |
| gpt-5.6-terra max | 0% (0/28) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-5.6-terra medium | 0% (0/470) [0%, 0%] | 14% (15/105) [7.1%, 22%] |
| gpt-5.6-terra xhigh | 0% (0/36) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-6-astra high | 0% (0/44) [0%, 0%] | 0% (0/10) [0%, 0%] |
| gpt-6-astra low | 0% (0/34) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-6-astra medium | 0% (0/580) [0%, 0%] | 0% (0/209) [0%, 0%] |
| gpt-6-astra off | 0% (0/46) [0%, 0%] | 0% (0/26) [0%, 0%] |
| gpt-6-luna high | 0% (0/30) [0%, 0%] | 7.1% (1/14) [0%, 27%] |
| gpt-6-luna low | 0% (0/23) [0%, 0%] | 67% (2/3) [0%, 100%] |
| gpt-6-luna max | 0% (0/26) [0%, 0%] | 7.1% (1/14) [0%, 21%] |
| gpt-6-luna medium | 2.1% (9/428) [0.9%, 3.6%] | 40% (51/128) [33%, 47%] |
| gpt-6-luna off | 0% (0/20) [0%, 0%] | 25% (1/4) [0%, 100%] |
| gpt-6-luna xhigh | 0% (0/29) [0%, 0%] | 0% (0/7) [0%, 0%] |
| gpt-6.1-sol high | 0% (0/39) [0%, 0%] | 0% (0/22) [0%, 0%] |
| gpt-6.1-sol low | 0% (0/45) [0%, 0%] | 5.3% (1/19) [0%, 20%] |
| gpt-6.1-sol max | 0% (0/111) [0%, 0%] | 0% (0/31) [0%, 0%] |
| gpt-6.1-sol medium | 0% (0/426) [0%, 0%] | 0.6% (1/167) [0%, 1.9%] |
| gpt-6.1-sol xhigh | 0% (0/40) [0%, 0%] | 0% (0/25) [0%, 0%] |
| gpt-6.1-terra high | 0% (0/35) [0%, 0%] | 0% (0/18) [0%, 0%] |
| gpt-6.1-terra low | 0% (0/46) [0%, 0%] | 8.3% (1/12) [0%, 27%] |
| gpt-6.1-terra max | 0% (0/51) [0%, 0%] | 0% (0/16) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/38) [0%, 0%] | 0% (0/15) [0%, 0%] |
| gpt-6.1-terra off | 0% (0/39) [0%, 0%] | 0% (0/10) [0%, 0%] |
| gpt-6.1-terra xhigh | 0% (0/36) [0%, 0%] | 0% (0/12) [0%, 0%] |

### Astra efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| gpt-6-astra high | 0% (0/3) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-6-astra low | 0% (0/7) [0%, 0%] | 0% (0/3) [0%, 0%] |
| gpt-6-astra medium | 0% (0/10) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-6-astra off | 0% (0/4) [0%, 0%] | – |

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
| claude-opus-5-5 high | 0% (0/99) [0%, 0%] | 0% (0/49) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/92) [0%, 0%] | 0% (0/24) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/75) [0%, 0%] | 0% (0/29) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/175) [0%, 0%] | 0% (0/78) [0%, 0%] |
| claude-opus-5-5 off | 0% (0/13) [0%, 0%] | 0% (0/4) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/120) [0%, 0%] | 0% (0/65) [0%, 0%] |

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

### Terra efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| gpt-5.6-terra high | 0% (0/179) [0%, 0%] | 11% (5/47) [2.3%, 20%] |
| gpt-5.6-terra low | 0% (0/196) [0%, 0%] | 18% (5/28) [6.7%, 31%] |
| gpt-5.6-terra max | 0% (0/190) [0%, 0%] | 2.3% (2/86) [0%, 6.2%] |
| gpt-5.6-terra medium | 0% (0/184) [0%, 0%] | 19% (7/37) [8.6%, 30%] |
| gpt-5.6-terra xhigh | 0.5% (1/188) [0%, 1.8%] | 5.8% (4/69) [0%, 14%] |

### gpt-6.1-terra efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| gpt-6.1-terra high | 0% (0/12) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-6.1-terra low | 0% (0/19) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-6.1-terra max | 0% (0/5) [0%, 0%] | 0% (0/1) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/22) [0%, 0%] | 0% (0/10) [0%, 0%] |
| gpt-6.1-terra off | 0% (0/16) [0%, 0%] | 0% (0/7) [0%, 0%] |
| gpt-6.1-terra xhigh | 0% (0/14) [0%, 0%] | 0% (0/8) [0%, 0%] |

## By accepted moves since the clue

Shots against a chamber known from a clue (glass or phone), by the accepted moves of either player between the clue and the shot. 0 is the very next move.

### glass

| Cohort | 0 | 1 | 2–3 | 4+ |
|---|---|---|---|---|
| Cross-model | 1.6% (53/3397) [1.1%, 2.1%] | 2.0% (37/1862) [1.3%, 2.7%] | 3.3% (16/490) [1.8%, 4.9%] | 0% (0/5) [0%, 0%] |
| Astra efforts | 0% (0/15) [0%, 0%] | 0% (0/8) [0%, 0%] | 0% (0/1) [0%, 0%] | – |
| Haiku 4.5 efforts | 11% (55/518) [7.4%, 14%] | 11% (35/327) [7.4%, 14%] | 30% (12/40) [15%, 47%] | 0% (0/1) [0%, 0%] |
| Haiku 5.5 efforts | 2.7% (15/561) [1.3%, 4.1%] | 4.4% (25/562) [2.5%, 6.6%] | 6.0% (13/215) [3.3%, 9.4%] | 50% (1/2) [0%, 100%] |
| Luna efforts | 0.5% (4/786) [0.1%, 1.0%] | 5.1% (23/449) [3.2%, 7.4%] | 11% (12/112) [5.1%, 17%] | 0% (0/3) [0%, 0%] |
| Opus efforts | 0% (0/314) [0%, 0%] | 0% (0/190) [0%, 0%] | 0% (0/70) [0%, 0%] | – |
| Sol efforts | 0% (0/563) [0%, 0%] | 0% (0/232) [0%, 0%] | 0% (0/90) [0%, 0%] | – |
| Sonnet efforts | 0% (0/709) [0%, 0%] | 0% (0/491) [0%, 0%] | 0% (0/236) [0%, 0%] | 0% (0/5) [0%, 0%] |
| Terra efforts | 0% (0/575) [0%, 0%] | 0.3% (1/300) [0%, 1.0%] | 0% (0/61) [0%, 0%] | 0% (0/1) [0%, 0%] |
| gpt-6.1-terra efforts | 0% (0/60) [0%, 0%] | 0% (0/20) [0%, 0%] | 0% (0/8) [0%, 0%] | – |

### phone

| Cohort | 0 | 1 | 2–3 | 4+ |
|---|---|---|---|---|
| Cross-model | 5.1% (16/311) [2.9%, 7.8%] | 6.5% (29/446) [4.2%, 8.9%] | 6.1% (41/672) [4.2%, 8.2%] | 13% (64/510) [9.3%, 16%] |
| Astra efforts | – | 0% (0/5) [0%, 0%] | 0% (0/9) [0%, 0%] | 0% (0/3) [0%, 0%] |
| Haiku 4.5 efforts | 39% (16/41) [26%, 53%] | 38% (14/37) [23%, 56%] | 48% (29/60) [38%, 59%] | 34% (20/58) [25%, 44%] |
| Haiku 5.5 efforts | 9.5% (7/74) [3.5%, 17%] | 5.6% (6/108) [1.8%, 9.9%] | 13% (28/210) [8.8%, 18%] | 14% (18/126) [8.5%, 21%] |
| Luna efforts | 29% (24/84) [20%, 38%] | 30% (29/98) [22%, 38%] | 32% (47/149) [24%, 39%] | 37% (41/111) [28%, 46%] |
| Opus efforts | 0% (0/45) [0%, 0%] | 0% (0/58) [0%, 0%] | 0% (0/100) [0%, 0%] | 0% (0/46) [0%, 0%] |
| Sol efforts | 0% (0/77) [0%, 0%] | 0% (0/102) [0%, 0%] | 0% (0/148) [0%, 0%] | 0% (0/119) [0%, 0%] |
| Sonnet efforts | 0% (0/108) [0%, 0%] | 0.7% (1/134) [0%, 2.3%] | 1.3% (3/223) [0%, 3.0%] | 2.5% (3/121) [0%, 5.6%] |
| Terra efforts | 3.3% (2/60) [0%, 8.5%] | 8.3% (6/72) [2.7%, 15%] | 10% (9/86) [4.4%, 17%] | 12% (6/49) [2.6%, 22%] |
| gpt-6.1-terra efforts | 0% (0/5) [0%, 0%] | 0% (0/5) [0%, 0%] | 0% (0/18) [0%, 0%] | 0% (0/10) [0%, 0%] |

## How shots are informed

Each agent shot by what the player knew of the chamber: a clue from its own item (glass, phone or both), the public count, or nothing. The last column is blind shots taken while the player held a magnifying glass.

### Cross-model

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 21% (67/323) [17%, 24%] | 33% (105/323) [27%, 38%] | 47% (151/323) [40%, 53%] | 3.3% (5/151) [0%, 6.5%] |
| claude-haiku-4-5-20251001 low | 22% (98/443) [19%, 25%] | 30% (133/443) [27%, 34%] | 48% (212/443) [44%, 51%] | 2.8% (6/212) [0.8%, 5.6%] |
| claude-haiku-4-5-20251001 medium | 21% (548/2670) [19%, 22%] | 30% (793/2670) [28%, 31%] | 50% (1329/2670) [48%, 52%] | 2.9% (39/1329) [1.8%, 4.3%] |
| claude-haiku-4-5-20251001 minimal | 21% (88/418) [17%, 25%] | 33% (138/418) [29%, 37%] | 46% (192/418) [41%, 51%] | 4.2% (8/192) [1.5%, 7.6%] |
| claude-haiku-4-5-20251001 off | 22% (55/246) [17%, 29%] | 28% (68/246) [24%, 32%] | 50% (123/246) [43%, 57%] | 2.4% (3/123) [0%, 4.7%] |
| claude-haiku-5-5 high | 25% (83/338) [20%, 28%] | 43% (147/338) [39%, 49%] | 32% (108/338) [28%, 36%] | 0% (0/108) [0%, 0%] |
| claude-haiku-5-5 low | 27% (174/654) [23%, 30%] | 39% (258/654) [36%, 43%] | 34% (222/654) [30%, 38%] | 0.5% (1/222) [0%, 1.5%] |
| claude-haiku-5-5 max | 25% (29/114) [19%, 32%] | 39% (44/114) [31%, 47%] | 36% (41/114) [32%, 41%] | 0% (0/41) [0%, 0%] |
| claude-haiku-5-5 medium | 26% (602/2353) [24%, 28%] | 37% (878/2353) [35%, 39%] | 37% (873/2353) [35%, 39%] | 0.6% (5/873) [0.1%, 1.2%] |
| claude-haiku-5-5 off | 24% (177/739) [21%, 27%] | 34% (252/739) [31%, 37%] | 42% (310/739) [38%, 45%] | 0.3% (1/310) [0%, 1.1%] |
| claude-haiku-5-5 xhigh | 30% (51/169) [23%, 38%] | 37% (63/169) [31%, 44%] | 33% (55/169) [25%, 41%] | 0% (0/55) [0%, 0%] |
| claude-opus-5-5 high | 26% (43/163) [22%, 31%] | 35% (57/163) [28%, 43%] | 39% (63/163) [28%, 47%] | 0% (0/63) [0%, 0%] |
| claude-opus-5-5 low | 29% (47/161) [26%, 34%] | 38% (61/161) [33%, 45%] | 33% (53/161) [23%, 40%] | 0% (0/53) [0%, 0%] |
| claude-opus-5-5 max | 24% (30/126) [21%, 27%] | 41% (52/126) [34%, 48%] | 35% (44/126) [29%, 42%] | 2.3% (1/44) [0%, 7.1%] |
| claude-opus-5-5 medium | 26% (641/2464) [24%, 28%] | 39% (963/2464) [37%, 41%] | 35% (860/2464) [33%, 37%] | 0.1% (1/860) [0%, 0.4%] |
| claude-opus-5-5 off | 33% (69/212) [25%, 41%] | 37% (78/212) [31%, 43%] | 31% (65/212) [22%, 40%] | 0% (0/65) [0%, 0%] |
| claude-opus-5-5 xhigh | 27% (206/759) [23%, 31%] | 39% (297/759) [36%, 42%] | 34% (256/759) [30%, 38%] | 0.4% (1/256) [0%, 1.3%] |
| claude-sonnet-5-5 high | 27% (71/260) [20%, 34%] | 37% (95/260) [31%, 41%] | 36% (94/260) [32%, 40%] | 0% (0/94) [0%, 0%] |
| claude-sonnet-5-5 low | 26% (69/267) [21%, 30%] | 31% (82/267) [27%, 34%] | 43% (116/267) [39%, 47%] | 0% (0/116) [0%, 0%] |
| claude-sonnet-5-5 max | 31% (145/472) [24%, 37%] | 33% (154/472) [30%, 35%] | 37% (173/472) [31%, 43%] | 1.7% (3/173) [0%, 4.3%] |
| claude-sonnet-5-5 medium | 27% (639/2350) [25%, 29%] | 34% (805/2350) [32%, 36%] | 39% (906/2350) [37%, 40%] | 0.3% (3/906) [0%, 0.8%] |
| claude-sonnet-5-5 off | 24% (64/262) [20%, 29%] | 40% (106/262) [34%, 46%] | 35% (92/262) [30%, 41%] | 0% (0/92) [0%, 0%] |
| claude-sonnet-5-5 xhigh | 28% (73/263) [22%, 33%] | 41% (107/263) [35%, 46%] | 32% (83/263) [25%, 39%] | 0% (0/83) [0%, 0%] |
| gpt-5.6-terra high | 28% (40/145) [21%, 35%] | 33% (48/145) [29%, 37%] | 39% (57/145) [34%, 43%] | 0% (0/57) [0%, 0%] |
| gpt-5.6-terra low | 24% (34/139) [19%, 30%] | 34% (47/139) [29%, 37%] | 42% (58/139) [33%, 51%] | 0% (0/58) [0%, 0%] |
| gpt-5.6-terra max | 23% (34/149) [20%, 26%] | 34% (51/149) [26%, 42%] | 43% (64/149) [36%, 50%] | 0% (0/64) [0%, 0%] |
| gpt-5.6-terra medium | 26% (577/2205) [24%, 28%] | 31% (692/2205) [29%, 33%] | 42% (936/2205) [40%, 45%] | 0.3% (3/936) [0%, 0.8%] |
| gpt-5.6-terra xhigh | 24% (44/180) [18%, 30%] | 34% (61/180) [25%, 43%] | 42% (75/180) [35%, 49%] | 0% (0/75) [0%, 0%] |
| gpt-6-astra high | 26% (57/221) [19%, 32%] | 35% (78/221) [30%, 40%] | 39% (86/221) [32%, 48%] | 0% (0/86) [0%, 0%] |
| gpt-6-astra low | 28% (42/150) [20%, 35%] | 34% (51/150) [27%, 40%] | 38% (57/150) [30%, 46%] | 0% (0/57) [0%, 0%] |
| gpt-6-astra medium | 27% (793/2986) [25%, 28%] | 34% (1002/2986) [32%, 35%] | 40% (1191/2986) [38%, 42%] | 0% (0/1191) [0%, 0%] |
| gpt-6-astra off | 30% (72/238) [24%, 37%] | 27% (65/238) [24%, 31%] | 42% (101/238) [36%, 49%] | 0% (0/101) [0%, 0%] |
| gpt-6-luna high | 31% (44/144) [23%, 37%] | 39% (56/144) [33%, 47%] | 31% (44/144) [26%, 33%] | 2.3% (1/44) [0%, 6.7%] |
| gpt-6-luna low | 23% (26/115) [15%, 27%] | 25% (29/115) [17%, 32%] | 52% (60/115) [42%, 66%] | 0% (0/60) [0%, 0%] |
| gpt-6-luna max | 29% (41/142) [23%, 34%] | 31% (44/142) [24%, 38%] | 40% (57/142) [32%, 50%] | 0% (0/57) [0%, 0%] |
| gpt-6-luna medium | 25% (557/2197) [24%, 27%] | 31% (677/2197) [29%, 33%] | 44% (963/2197) [42%, 46%] | 0.8% (8/963) [0.2%, 1.6%] |
| gpt-6-luna off | 21% (24/116) [18%, 23%] | 34% (40/116) [29%, 41%] | 45% (52/116) [39%, 50%] | 1.9% (1/52) [0%, 5.9%] |
| gpt-6-luna xhigh | 17% (36/207) [14%, 22%] | 39% (80/207) [31%, 47%] | 44% (91/207) [37%, 50%] | 0% (0/91) [0%, 0%] |
| gpt-6.1-sol high | 26% (61/238) [20%, 31%] | 37% (88/238) [31%, 42%] | 37% (89/238) [31%, 43%] | 0% (0/89) [0%, 0%] |
| gpt-6.1-sol low | 31% (64/206) [25%, 37%] | 26% (53/206) [20%, 31%] | 43% (89/206) [36%, 52%] | 0% (0/89) [0%, 0%] |
| gpt-6.1-sol max | 28% (142/501) [23%, 33%] | 32% (160/501) [28%, 36%] | 40% (199/501) [35%, 45%] | 0.5% (1/199) [0%, 1.6%] |
| gpt-6.1-sol medium | 26% (594/2319) [24%, 27%] | 35% (803/2319) [33%, 36%] | 40% (922/2319) [38%, 42%] | 0.1% (1/922) [0%, 0.3%] |
| gpt-6.1-sol xhigh | 27% (69/252) [22%, 33%] | 35% (87/252) [30%, 39%] | 38% (96/252) [32%, 43%] | 0% (0/96) [0%, 0%] |
| gpt-6.1-terra high | 30% (54/178) [26%, 36%] | 31% (56/178) [26%, 37%] | 38% (68/178) [33%, 44%] | 0% (0/68) [0%, 0%] |
| gpt-6.1-terra low | 31% (59/189) [27%, 35%] | 28% (53/189) [23%, 33%] | 41% (77/189) [36%, 45%] | 0% (0/77) [0%, 0%] |
| gpt-6.1-terra max | 28% (67/239) [23%, 32%] | 35% (83/239) [29%, 39%] | 37% (89/239) [32%, 43%] | 0% (0/89) [0%, 0%] |
| gpt-6.1-terra medium | 32% (54/168) [27%, 38%] | 32% (54/168) [25%, 40%] | 36% (60/168) [31%, 41%] | 0% (0/60) [0%, 0%] |
| gpt-6.1-terra off | 31% (49/157) [25%, 36%] | 30% (47/157) [25%, 36%] | 39% (61/157) [31%, 46%] | 0% (0/61) [0%, 0%] |
| gpt-6.1-terra xhigh | 31% (48/156) [24%, 36%] | 30% (47/156) [23%, 37%] | 39% (61/156) [31%, 50%] | 0% (0/61) [0%, 0%] |

### Astra efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| gpt-6-astra high | 28% (9/32) [0%, 38%] | 28% (9/32) [25%, 38%] | 44% (14/32) [38%, 63%] | 0% (0/14) [0%, 0%] |
| gpt-6-astra low | 28% (10/36) [13%, 40%] | 25% (9/36) [20%, 28%] | 47% (17/36) [40%, 63%] | 0% (0/17) [0%, 0%] |
| gpt-6-astra medium | 49% (18/37) [39%, 58%] | 24% (9/37) [16%, 33%] | 27% (10/37) [26%, 28%] | 0% (0/10) [0%, 0%] |
| gpt-6-astra off | 33% (4/12) [33%, 33%] | 33% (4/12) [33%, 33%] | 33% (4/12) [33%, 33%] | 0% (0/4) [0%, 0%] |

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
| claude-opus-5-5 high | 30% (149/499) [25%, 35%] | 31% (157/499) [26%, 37%] | 39% (193/499) [33%, 44%] | 0% (0/193) [0%, 0%] |
| claude-opus-5-5 low | 29% (116/400) [24%, 34%] | 32% (127/400) [27%, 36%] | 39% (157/400) [34%, 45%] | 0% (0/157) [0%, 0%] |
| claude-opus-5-5 max | 28% (107/376) [23%, 34%] | 40% (150/376) [35%, 45%] | 32% (119/376) [27%, 37%] | 6.7% (8/119) [3.3%, 11%] |
| claude-opus-5-5 medium | 30% (253/835) [27%, 34%] | 32% (267/835) [28%, 35%] | 38% (315/835) [33%, 42%] | 0.3% (1/315) [0%, 1.0%] |
| claude-opus-5-5 off | 24% (17/71) [10%, 41%] | 34% (24/71) [26%, 42%] | 42% (30/71) [24%, 55%] | 0% (0/30) [0%, 0%] |
| claude-opus-5-5 xhigh | 32% (188/582) [28%, 37%] | 33% (192/582) [29%, 37%] | 35% (202/582) [31%, 39%] | 1.0% (2/202) [0%, 2.4%] |

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

### Terra efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| gpt-5.6-terra high | 23% (227/968) [20%, 27%] | 36% (346/968) [32%, 39%] | 41% (395/968) [37%, 45%] | 0.3% (1/395) [0%, 0.8%] |
| gpt-5.6-terra low | 24% (228/954) [21%, 27%] | 34% (325/954) [31%, 37%] | 42% (401/954) [39%, 45%] | 0% (0/401) [0%, 0%] |
| gpt-5.6-terra max | 27% (276/1020) [23%, 31%] | 35% (361/1020) [32%, 38%] | 38% (383/1020) [34%, 42%] | 0% (0/383) [0%, 0%] |
| gpt-5.6-terra medium | 24% (221/931) [20%, 27%] | 33% (304/931) [29%, 36%] | 44% (406/931) [40%, 47%] | 0.5% (2/406) [0%, 1.3%] |
| gpt-5.6-terra xhigh | 26% (257/985) [23%, 30%] | 35% (341/985) [32%, 37%] | 39% (387/985) [35%, 43%] | 0.3% (1/387) [0%, 0.8%] |

### gpt-6.1-terra efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| gpt-6.1-terra high | 31% (18/59) [21%, 45%] | 24% (14/59) [13%, 36%] | 46% (27/59) [18%, 54%] | 0% (0/27) [0%, 0%] |
| gpt-6.1-terra low | 42% (25/59) [33%, 49%] | 34% (20/59) [26%, 46%] | 24% (14/59) [21%, 26%] | 0% (0/14) [0%, 0%] |
| gpt-6.1-terra max | 17% (6/35) [17%, 17%] | 49% (17/35) [49%, 49%] | 34% (12/35) [34%, 34%] | 0% (0/12) [0%, 0%] |
| gpt-6.1-terra medium | 31% (33/105) [23%, 39%] | 33% (35/105) [27%, 39%] | 35% (37/105) [25%, 49%] | 0% (0/37) [0%, 0%] |
| gpt-6.1-terra off | 33% (23/69) [21%, 50%] | 29% (20/69) [23%, 33%] | 38% (26/69) [26%, 52%] | 0% (0/26) [0%, 0%] |
| gpt-6.1-terra xhigh | 26% (22/85) [15%, 36%] | 33% (28/85) [26%, 38%] | 41% (35/85) [31%, 51%] | 0% (0/35) [0%, 0%] |

## Item fates

Each item a player placed, by how it left: used by its owner, stolen with adrenaline, still held when the owner died, or still held when the round ended (censored). Delays count only items used by their owner. Own turns are the owner's own decisions between placing the item and using it, so 0 is the first decision after the distribution.

### Cross-model

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 48% (303/625) [43%, 54%] | 10% (65/625) [8.5%, 12%] | 30% (188/625) [23%, 37%] | 11% (69/625) [7.5%, 14%] | 1.38 (1) | 6 |
| claude-haiku-4-5-20251001 low | 52% (444/860) [47%, 56%] | 7.4% (64/860) [5.6%, 9.3%] | 26% (227/860) [22%, 31%] | 15% (125/860) [9.3%, 21%] | 1.60 (1) | 7 |
| claude-haiku-4-5-20251001 medium | 48% (2547/5289) [46%, 50%] | 8.2% (432/5289) [7.4%, 8.9%] | 29% (1543/5289) [27%, 31%] | 15% (767/5289) [13%, 17%] | 1.40 (1) | 6 |
| claude-haiku-4-5-20251001 minimal | 50% (397/790) [44%, 55%] | 8.7% (69/790) [7.2%, 10%] | 27% (215/790) [21%, 34%] | 14% (109/790) [8.7%, 19%] | 1.56 (1) | 6 |
| claude-haiku-4-5-20251001 off | 50% (249/502) [45%, 54%] | 8.8% (44/502) [7.0%, 11%] | 32% (160/502) [24%, 40%] | 9.8% (49/502) [4.6%, 15%] | 1.32 (1) | 7 |
| claude-haiku-5-5 high | 60% (407/677) [54%, 66%] | 7.7% (52/677) [5.3%, 10%] | 18% (124/677) [12%, 25%] | 14% (94/677) [9.4%, 19%] | 1.48 (1) | 7 |
| claude-haiku-5-5 low | 60% (809/1349) [57%, 63%] | 6.8% (92/1349) [5.2%, 8.3%] | 13% (175/1349) [9.6%, 16%] | 20% (273/1349) [17%, 24%] | 1.64 (1) | 7 |
| claude-haiku-5-5 max | 59% (138/233) [49%, 67%] | 5.2% (12/233) [2.3%, 8.3%] | 17% (40/233) [8.0%, 27%] | 18% (43/233) [13%, 25%] | 1.66 (1) | 8 |
| claude-haiku-5-5 medium | 57% (2856/5020) [55%, 59%] | 7.3% (368/5020) [6.7%, 8.0%] | 20% (1017/5020) [18%, 22%] | 16% (779/5020) [14%, 17%] | 1.58 (1) | 7 |
| claude-haiku-5-5 off | 59% (923/1572) [55%, 62%] | 6.5% (102/1572) [5.3%, 7.6%] | 20% (314/1572) [16%, 24%] | 15% (233/1572) [12%, 17%] | 1.35 (1) | 6 |
| claude-haiku-5-5 xhigh | 53% (198/376) [47%, 58%] | 8.5% (32/376) [5.3%, 11%] | 30% (113/376) [23%, 37%] | 8.8% (33/376) [4.6%, 13%] | 1.67 (1) | 7 |
| claude-opus-5-5 high | 59% (189/321) [54%, 65%] | 6.9% (22/321) [5.4%, 8.6%] | 18% (58/321) [10%, 26%] | 16% (52/321) [8.4%, 24%] | 1.76 (1) | 7 |
| claude-opus-5-5 low | 50% (165/329) [42%, 58%] | 9.4% (31/329) [7.1%, 12%] | 21% (70/329) [13%, 31%] | 19% (63/329) [12%, 28%] | 1.69 (1) | 7 |
| claude-opus-5-5 max | 67% (138/207) [63%, 69%] | 4.8% (10/207) [1.5%, 7.9%] | 14% (30/207) [6.9%, 24%] | 14% (29/207) [5.4%, 22%] | 1.59 (1) | 7 |
| claude-opus-5-5 medium | 57% (2644/4660) [55%, 58%] | 7.4% (343/4660) [6.6%, 8.1%] | 18% (850/4660) [16%, 20%] | 18% (823/4660) [16%, 20%] | 1.67 (1) | 7 |
| claude-opus-5-5 off | 55% (240/439) [48%, 61%] | 8.4% (37/439) [5.7%, 11%] | 21% (92/439) [13%, 31%] | 16% (70/439) [9.9%, 22%] | 2.01 (1) | 7 |
| claude-opus-5-5 xhigh | 55% (803/1451) [52%, 58%] | 9.6% (140/1451) [7.9%, 12%] | 21% (304/1451) [17%, 25%] | 14% (204/1451) [12%, 17%] | 1.76 (1) | 7 |
| claude-sonnet-5-5 high | 54% (282/524) [45%, 61%] | 8.4% (44/524) [5.9%, 11%] | 21% (111/524) [14%, 29%] | 17% (87/524) [12%, 21%] | 1.60 (1) | 7 |
| claude-sonnet-5-5 low | 52% (265/508) [47%, 57%] | 8.7% (44/508) [6.1%, 12%] | 28% (143/508) [19%, 37%] | 11% (56/508) [6.3%, 17%] | 1.73 (1) | 7 |
| claude-sonnet-5-5 max | 56% (532/945) [53%, 59%] | 10% (95/945) [7.8%, 12%] | 19% (179/945) [15%, 23%] | 15% (139/945) [12%, 18%] | 1.77 (1) | 7 |
| claude-sonnet-5-5 medium | 53% (2360/4429) [51%, 55%] | 7.1% (316/4429) [6.5%, 7.8%] | 22% (975/4429) [20%, 24%] | 18% (778/4429) [16%, 19%] | 1.72 (1) | 7 |
| claude-sonnet-5-5 off | 53% (287/543) [48%, 57%] | 10% (56/543) [8.2%, 13%] | 18% (96/543) [11%, 25%] | 19% (104/543) [14%, 25%] | 1.64 (1) | 7 |
| claude-sonnet-5-5 xhigh | 60% (316/523) [57%, 64%] | 8.2% (43/523) [6.3%, 10%] | 15% (78/523) [9.0%, 22%] | 16% (86/523) [11%, 21%] | 1.84 (1) | 7 |
| gpt-5.6-terra high | 51% (135/264) [48%, 55%] | 8.0% (21/264) [4.7%, 11%] | 27% (71/264) [21%, 34%] | 14% (37/264) [7.5%, 21%] | 1.56 (1) | 6 |
| gpt-5.6-terra low | 51% (136/266) [43%, 56%] | 6.8% (18/266) [5.4%, 8.5%] | 24% (64/266) [19%, 33%] | 18% (48/266) [11%, 27%] | 1.21 (1) | 6 |
| gpt-5.6-terra max | 68% (170/250) [63%, 73%] | 8.0% (20/250) [5.1%, 10%] | 14% (35/250) [10%, 17%] | 10% (25/250) [5.1%, 19%] | 1.60 (1) | 6 |
| gpt-5.6-terra medium | 52% (2111/4024) [51%, 54%] | 7.9% (319/4024) [7.1%, 8.7%] | 23% (907/4024) [20%, 25%] | 17% (687/4024) [15%, 19%] | 1.47 (1) | 6 |
| gpt-5.6-terra xhigh | 63% (199/318) [56%, 70%] | 6.3% (20/318) [3.8%, 9.0%] | 16% (51/318) [10.0%, 23%] | 15% (48/318) [9.5%, 21%] | 1.65 (1) | 6 |
| gpt-6-astra high | 56% (228/409) [49%, 62%] | 8.1% (33/409) [5.3%, 11%] | 19% (76/409) [12%, 27%] | 18% (72/409) [12%, 23%] | 1.64 (1) | 6 |
| gpt-6-astra low | 52% (165/319) [45%, 57%] | 7.2% (23/319) [4.7%, 11%] | 25% (80/319) [15%, 37%] | 16% (51/319) [7.3%, 24%] | 1.52 (1) | 7 |
| gpt-6-astra medium | 56% (3233/5743) [55%, 58%] | 7.5% (430/5743) [6.7%, 8.3%] | 17% (974/5743) [15%, 19%] | 19% (1106/5743) [18%, 21%] | 1.69 (1) | 7 |
| gpt-6-astra off | 54% (253/465) [49%, 59%] | 9.9% (46/465) [7.4%, 12%] | 14% (67/465) [8.8%, 20%] | 21% (99/465) [17%, 26%] | 1.70 (1) | 7 |
| gpt-6-luna high | 55% (156/286) [48%, 61%] | 4.2% (12/286) [2.2%, 6.4%] | 28% (79/286) [23%, 33%] | 14% (39/286) [11%, 17%] | 1.40 (1) | 7 |
| gpt-6-luna low | 71% (148/209) [63%, 79%] | 6.2% (13/209) [5.1%, 7.3%] | 19% (39/209) [13%, 26%] | 4.3% (9/209) [1.6%, 7.2%] | 1.31 (1) | 6 |
| gpt-6-luna max | 58% (166/284) [47%, 67%] | 5.3% (15/284) [2.1%, 8.9%] | 24% (69/284) [15%, 35%] | 12% (34/284) [5.5%, 18%] | 1.58 (1) | 7 |
| gpt-6-luna medium | 62% (2628/4257) [60%, 64%] | 6.3% (267/4257) [5.6%, 6.9%] | 25% (1067/4257) [23%, 27%] | 6.9% (295/4257) [5.7%, 8.2%] | 1.59 (1) | 6 |
| gpt-6-luna off | 68% (158/232) [64%, 71%] | 6.0% (14/232) [3.6%, 8.5%] | 23% (54/232) [21%, 25%] | 2.6% (6/232) [0.4%, 5.4%] | 1.72 (1) | 6 |
| gpt-6-luna xhigh | 64% (252/391) [59%, 71%] | 7.2% (28/391) [5.2%, 9.0%] | 16% (63/391) [13%, 20%] | 12% (48/391) [7.3%, 17%] | 1.85 (1) | 7 |
| gpt-6.1-sol high | 58% (269/460) [50%, 66%] | 9.3% (43/460) [6.1%, 12%] | 20% (91/460) [13%, 26%] | 12% (57/460) [7.6%, 18%] | 1.55 (1) | 6 |
| gpt-6.1-sol low | 57% (227/395) [51%, 64%] | 6.8% (27/395) [5.8%, 8.1%] | 16% (64/395) [10%, 23%] | 19% (77/395) [14%, 26%] | 1.52 (1) | 6 |
| gpt-6.1-sol max | 59% (596/1005) [55%, 63%] | 8.4% (84/1005) [6.6%, 10%] | 15% (151/1005) [11%, 19%] | 17% (174/1005) [14%, 22%] | 1.66 (1) | 6 |
| gpt-6.1-sol medium | 57% (2520/4448) [55%, 58%] | 6.9% (306/4448) [6.2%, 7.6%] | 18% (798/4448) [16%, 20%] | 19% (824/4448) [17%, 20%] | 1.65 (1) | 7 |
| gpt-6.1-sol xhigh | 61% (312/511) [56%, 67%] | 8.2% (42/511) [6.4%, 10%] | 15% (76/511) [9.9%, 20%] | 16% (81/511) [12%, 20%] | 1.70 (1) | 7 |
| gpt-6.1-terra high | 48% (168/348) [43%, 53%] | 6.9% (24/348) [5.3%, 8.6%] | 21% (73/348) [11%, 29%] | 24% (83/348) [17%, 33%] | 1.80 (1) | 7 |
| gpt-6.1-terra low | 54% (206/384) [49%, 59%] | 9.6% (37/384) [6.9%, 12%] | 22% (83/384) [15%, 28%] | 15% (58/384) [11%, 21%] | 1.57 (1) | 7 |
| gpt-6.1-terra max | 65% (300/460) [61%, 71%] | 8.0% (37/460) [5.8%, 10%] | 13% (58/460) [5.4%, 20%] | 14% (65/460) [8.8%, 20%] | 1.81 (1) | 6 |
| gpt-6.1-terra medium | 54% (172/317) [47%, 61%] | 7.9% (25/317) [4.9%, 11%] | 25% (79/317) [21%, 30%] | 13% (41/317) [8.0%, 17%] | 1.50 (1) | 6 |
| gpt-6.1-terra off | 52% (153/294) [47%, 57%] | 5.4% (16/294) [2.8%, 8.0%] | 23% (68/294) [15%, 32%] | 19% (57/294) [12%, 26%] | 1.44 (1) | 6 |
| gpt-6.1-terra xhigh | 59% (173/295) [52%, 65%] | 7.5% (22/295) [4.2%, 10%] | 19% (56/295) [14%, 25%] | 15% (44/295) [9.8%, 20%] | 1.58 (1) | 6 |

### Astra efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| gpt-6-astra high | 72% (38/53) [70%, 77%] | 3.8% (2/53) [2.5%, 7.7%] | 17% (9/53) [0%, 23%] | 7.5% (4/53) [5.0%, 15%] | 1.47 (1) | 6 |
| gpt-6-astra low | 49% (35/71) [48%, 54%] | 9.9% (7/71) [5.0%, 23%] | 30% (21/71) [15%, 35%] | 11% (8/71) [7.7%, 13%] | 1.46 (1) | 7 |
| gpt-6-astra medium | 53% (42/80) [50%, 55%] | 6.3% (5/80) [5.0%, 7.5%] | 18% (14/80) [15%, 20%] | 24% (19/80) [23%, 25%] | 0.90 (1) | 7 |
| gpt-6-astra off | 56% (10/18) [56%, 56%] | 11% (2/18) [11%, 11%] | 17% (3/18) [17%, 17%] | 17% (3/18) [17%, 17%] | 1.10 (1) | 5 |

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
| claude-opus-5-5 high | 57% (546/952) [53%, 61%] | 9.8% (93/952) [8.2%, 11%] | 23% (216/952) [19%, 27%] | 10% (97/952) [7.5%, 13%] | 1.80 (1) | 7 |
| claude-opus-5-5 low | 56% (428/766) [50%, 61%] | 10% (79/766) [8.3%, 13%] | 20% (154/766) [15%, 25%] | 14% (105/766) [9.5%, 19%] | 1.59 (1) | 6 |
| claude-opus-5-5 max | 62% (454/729) [57%, 68%] | 11% (81/729) [9.0%, 14%] | 15% (108/729) [10%, 20%] | 12% (86/729) [9.0%, 15%] | 1.79 (1) | 7 |
| claude-opus-5-5 medium | 58% (939/1619) [56%, 60%] | 9.8% (158/1619) [8.5%, 11%] | 21% (345/1619) [19%, 24%] | 11% (177/1619) [9.1%, 13%] | 1.70 (1) | 7 |
| claude-opus-5-5 off | 49% (78/158) [43%, 52%] | 11% (18/158) [5.3%, 16%] | 23% (37/158) [17%, 34%] | 16% (25/158) [14%, 18%] | 1.50 (1) | 7 |
| claude-opus-5-5 xhigh | 59% (653/1102) [55%, 64%] | 10% (114/1102) [8.6%, 13%] | 15% (166/1102) [11%, 19%] | 15% (169/1102) [12%, 19%] | 1.67 (1) | 6 |

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

### Terra efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| gpt-5.6-terra high | 50% (918/1820) [48%, 53%] | 9.0% (163/1820) [7.8%, 10%] | 22% (408/1820) [19%, 26%] | 18% (331/1820) [15%, 21%] | 1.45 (1) | 6 |
| gpt-5.6-terra low | 48% (898/1878) [45%, 51%] | 9.1% (171/1878) [7.9%, 10%] | 27% (511/1878) [24%, 30%] | 16% (298/1878) [13%, 19%] | 1.43 (1) | 6 |
| gpt-5.6-terra max | 61% (1150/1892) [58%, 63%] | 7.8% (148/1892) [6.8%, 8.8%] | 17% (320/1892) [14%, 20%] | 14% (274/1892) [12%, 16%] | 1.57 (1) | 6 |
| gpt-5.6-terra medium | 46% (861/1855) [44%, 49%] | 8.5% (157/1855) [7.3%, 9.7%] | 31% (571/1855) [28%, 34%] | 14% (266/1855) [12%, 16%] | 1.44 (1) | 6 |
| gpt-5.6-terra xhigh | 55% (1045/1903) [52%, 58%] | 8.5% (162/1903) [7.4%, 9.6%] | 18% (339/1903) [15%, 21%] | 19% (357/1903) [16%, 21%] | 1.55 (1) | 6 |

### gpt-6.1-terra efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| gpt-6.1-terra high | 54% (56/104) [50%, 58%] | 6.7% (7/104) [5.0%, 11%] | 33% (34/104) [28%, 37%] | 6.7% (7/104) [0%, 18%] | 1.36 (1) | 5 |
| gpt-6.1-terra low | 56% (54/97) [52%, 58%] | 8.2% (8/97) [7.5%, 9.1%] | 12% (12/97) [4.5%, 19%] | 24% (23/97) [15%, 34%] | 1.87 (1) | 8 |
| gpt-6.1-terra max | 71% (39/55) [71%, 71%] | 11% (6/55) [11%, 11%] | 0% (0/55) [0%, 0%] | 18% (10/55) [18%, 18%] | 1.79 (1) | 6 |
| gpt-6.1-terra medium | 54% (100/184) [41%, 66%] | 11% (20/184) [6.0%, 15%] | 19% (35/184) [11%, 28%] | 16% (29/184) [9.2%, 22%] | 1.70 (1) | 6 |
| gpt-6.1-terra off | 50% (66/133) [42%, 58%] | 11% (14/133) [4.7%, 15%] | 33% (44/133) [23%, 42%] | 6.8% (9/133) [1.7%, 14%] | 1.59 (1) | 6 |
| gpt-6.1-terra xhigh | 48% (81/169) [39%, 61%] | 9.5% (16/169) [5.7%, 14%] | 29% (49/169) [2.9%, 47%] | 14% (23/169) [1.0%, 31%] | 1.47 (1) | 7 |

## Use when legal

Agent decisions where using an own item is a legal move, and the share that use it. A player holding two of an item counts once per decision.

### Cross-model

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 70% (53/76) [59%, 84%] | 16% (38/240) [12%, 21%] | 38% (50/130) [34%, 46%] | 18% (38/206) [13%, 24%] | 12% (22/188) [7.5%, 16%] | 22% (37/169) [15%, 29%] | 35% (28/79) [22%, 50%] |
| claude-haiku-4-5-20251001 low | 66% (86/130) [54%, 79%] | 19% (51/273) [14%, 25%] | 37% (73/195) [31%, 46%] | 22% (65/296) [17%, 28%] | 12% (39/324) [9.1%, 15%] | 19% (47/250) [14%, 23%] | 39% (31/80) [28%, 55%] |
| claude-haiku-4-5-20251001 medium | 63% (441/697) [58%, 68%] | 16% (277/1786) [14%, 18%] | 36% (397/1112) [33%, 39%] | 21% (359/1698) [19%, 24%] | 13% (255/1926) [12%, 15%] | 19% (264/1384) [17%, 21%] | 37% (262/702) [33%, 42%] |
| claude-haiku-4-5-20251001 minimal | 59% (78/132) [54%, 66%] | 15% (48/322) [11%, 19%] | 45% (58/128) [40%, 52%] | 19% (54/287) [13%, 26%] | 12% (32/264) [8.5%, 16%] | 18% (42/228) [14%, 23%] | 31% (44/142) [25%, 37%] |
| claude-haiku-4-5-20251001 off | 70% (39/56) [57%, 89%] | 34% (36/106) [27%, 46%] | 24% (44/180) [17%, 37%] | 20% (32/164) [11%, 30%] | 16% (24/148) [9.8%, 22%] | 19% (29/155) [11%, 29%] | 32% (23/72) [20%, 45%] |
| claude-haiku-5-5 high | 68% (50/74) [60%, 78%] | 32% (58/184) [24%, 41%] | 27% (49/184) [22%, 31%] | 20% (58/291) [16%, 24%] | 15% (45/302) [11%, 19%] | 25% (39/156) [18%, 34%] | 63% (47/75) [51%, 75%] |
| claude-haiku-5-5 low | 66% (126/190) [59%, 76%] | 23% (105/464) [18%, 28%] | 30% (107/354) [26%, 35%] | 23% (117/512) [19%, 27%] | 13% (77/580) [11%, 16%] | 23% (99/422) [19%, 29%] | 42% (77/184) [35%, 51%] |
| claude-haiku-5-5 max | 67% (18/27) [56%, 93%] | 32% (22/69) [27%, 43%] | 21% (19/92) [14%, 32%] | 17% (15/89) [8.3%, 26%] | 11% (10/94) [7.0%, 15%] | 25% (17/69) [13%, 39%] | 45% (13/29) [28%, 78%] |
| claude-haiku-5-5 medium | 64% (424/662) [60%, 69%] | 28% (394/1386) [25%, 32%] | 31% (389/1236) [30%, 33%] | 24% (405/1660) [22%, 27%] | 13% (270/2085) [12%, 14%] | 25% (297/1210) [22%, 28%] | 46% (296/638) [42%, 50%] |
| claude-haiku-5-5 off | 77% (140/182) [72%, 82%] | 33% (154/467) [28%, 39%] | 44% (150/341) [40%, 48%] | 31% (120/391) [25%, 37%] | 7.3% (51/700) [5.6%, 9.2%] | 20% (89/447) [16%, 24%] | 30% (77/258) [24%, 38%] |
| claude-haiku-5-5 xhigh | 56% (30/54) [39%, 74%] | 33% (31/93) [24%, 44%] | 22% (16/74) [16%, 29%] | 18% (22/125) [13%, 24%] | 13% (20/156) [8.5%, 18%] | 25% (20/81) [18%, 37%] | 50% (24/48) [39%, 63%] |
| claude-opus-5-5 high | 45% (32/71) [36%, 56%] | 31% (23/75) [20%, 47%] | 30% (26/87) [25%, 34%] | 18% (23/125) [10%, 29%] | 11% (15/142) [6.6%, 15%] | 37% (21/57) [26%, 48%] | 43% (23/54) [36%, 52%] |
| claude-opus-5-5 low | 51% (35/68) [42%, 68%] | 19% (21/111) [10%, 26%] | 32% (24/75) [24%, 39%] | 10% (15/147) [4.2%, 16%] | 15% (20/131) [9.9%, 21%] | 36% (18/50) [25%, 53%] | 60% (12/20) [48%, 85%] |
| claude-opus-5-5 max | 51% (18/35) [41%, 70%] | 33% (18/55) [27%, 44%] | 25% (15/59) [12%, 37%] | 17% (18/103) [12%, 22%] | 14% (9/66) [3.1%, 22%] | 47% (23/49) [31%, 82%] | 37% (15/41) [31%, 48%] |
| claude-opus-5-5 medium | 55% (388/709) [51%, 59%] | 32% (375/1179) [28%, 36%] | 26% (340/1332) [24%, 28%] | 18% (363/1966) [17%, 20%] | 13% (254/1903) [12%, 15%] | 33% (325/978) [30%, 37%] | 37% (258/691) [34%, 41%] |
| claude-opus-5-5 off | 49% (47/95) [44%, 59%] | 17% (26/151) [10%, 26%] | 26% (32/122) [21%, 35%] | 13% (28/212) [9.7%, 18%] | 11% (19/166) [6.8%, 17%] | 46% (29/63) [35%, 60%] | 59% (19/32) [50%, 71%] |
| claude-opus-5-5 xhigh | 52% (123/238) [46%, 60%] | 35% (117/337) [29%, 44%] | 26% (111/432) [22%, 30%] | 16% (91/555) [13%, 20%] | 11% (70/629) [8.8%, 13%] | 34% (95/279) [28%, 41%] | 34% (68/200) [28%, 41%] |
| claude-sonnet-5-5 high | 68% (42/62) [56%, 80%] | 36% (46/128) [26%, 47%] | 25% (38/150) [21%, 30%] | 24% (43/179) [17%, 32%] | 6.9% (17/245) [3.6%, 11%] | 29% (37/129) [19%, 42%] | 41% (34/83) [35%, 48%] |
| claude-sonnet-5-5 low | 76% (38/50) [60%, 95%] | 25% (42/171) [18%, 32%] | 29% (34/116) [25%, 35%] | 20% (38/190) [13%, 30%] | 5.7% (12/209) [3.3%, 8.8%] | 31% (41/131) [24%, 41%] | 32% (31/98) [23%, 42%] |
| claude-sonnet-5-5 max | 57% (84/148) [49%, 68%] | 31% (79/251) [25%, 40%] | 27% (87/317) [23%, 31%] | 14% (49/344) [10%, 18%] | 15% (58/396) [12%, 17%] | 40% (63/159) [32%, 50%] | 40% (39/97) [31%, 51%] |
| claude-sonnet-5-5 medium | 67% (390/586) [63%, 71%] | 25% (329/1316) [22%, 28%] | 26% (329/1244) [25%, 28%] | 20% (336/1664) [18%, 23%] | 7.4% (152/2045) [6.5%, 8.5%] | 34% (304/905) [30%, 38%] | 33% (235/713) [29%, 37%] |
| claude-sonnet-5-5 off | 68% (45/66) [58%, 79%] | 29% (36/124) [19%, 41%] | 24% (38/156) [21%, 28%] | 24% (46/190) [17%, 33%] | 7.7% (16/209) [4.6%, 12%] | 29% (38/129) [21%, 40%] | 47% (26/55) [31%, 70%] |
| claude-sonnet-5-5 xhigh | 58% (43/74) [46%, 80%] | 34% (43/128) [25%, 47%] | 25% (34/136) [19%, 32%] | 20% (51/254) [15%, 28%] | 12% (28/233) [8.7%, 15%] | 27% (25/93) [16%, 46%] | 38% (40/105) [28%, 49%] |
| gpt-5.6-terra high | 63% (26/41) [52%, 77%] | 10% (11/110) [5.0%, 17%] | 33% (21/63) [26%, 43%] | 17% (19/115) [12%, 20%] | 11% (11/102) [5.3%, 14%] | 14% (12/86) [7.1%, 23%] | 82% (14/17) [71%, 100%] |
| gpt-5.6-terra low | 65% (26/40) [58%, 78%] | 22% (11/51) [4.3%, 45%] | 34% (26/76) [27%, 44%] | 16% (18/115) [11%, 22%] | 6.0% (6/100) [2.4%, 9.3%] | 11% (12/110) [3.0%, 26%] | 56% (18/32) [46%, 78%] |
| gpt-5.6-terra max | 60% (25/42) [42%, 78%] | 44% (25/57) [32%, 60%] | 29% (23/80) [22%, 40%] | 23% (21/92) [11%, 39%] | 14% (23/167) [9.0%, 20%] | 29% (16/55) [13%, 52%] | 45% (13/29) [26%, 79%] |
| gpt-5.6-terra medium | 60% (408/677) [57%, 64%] | 14% (219/1539) [12%, 17%] | 34% (302/876) [32%, 37%] | 20% (249/1263) [17%, 23%] | 9.3% (167/1792) [8.0%, 11%] | 13% (182/1409) [11%, 15%] | 67% (264/394) [61%, 74%] |
| gpt-5.6-terra xhigh | 60% (34/57) [41%, 75%] | 22% (20/93) [14%, 31%] | 27% (28/104) [20%, 37%] | 20% (26/128) [12%, 27%] | 11% (17/159) [7.1%, 14%] | 22% (26/117) [17%, 33%] | 65% (24/37) [53%, 91%] |
| gpt-6-astra high | 40% (34/85) [34%, 51%] | 43% (37/86) [33%, 54%] | 28% (30/108) [20%, 33%] | 18% (20/114) [11%, 25%] | 11% (21/193) [7.6%, 15%] | 28% (20/71) [20%, 44%] | 35% (27/77) [27%, 49%] |
| gpt-6-astra low | 51% (28/55) [36%, 69%] | 30% (14/46) [19%, 48%] | 31% (28/91) [23%, 45%] | 15% (18/120) [9.1%, 25%] | 13% (18/141) [5.9%, 18%] | 40% (20/50) [25%, 62%] | 39% (17/44) [28%, 50%] |
| gpt-6-astra medium | 48% (488/1010) [45%, 52%] | 37% (525/1415) [34%, 40%] | 27% (478/1739) [26%, 29%] | 13% (319/2461) [11%, 15%] | 11% (276/2545) [9.9%, 12%] | 32% (371/1157) [29%, 36%] | 37% (300/810) [35%, 40%] |
| gpt-6-astra off | 46% (43/93) [37%, 56%] | 29% (38/129) [21%, 41%] | 36% (45/125) [30%, 43%] | 5.2% (12/230) [1.9%, 10.0%] | 12% (22/187) [6.6%, 16%] | 25% (30/120) [18%, 35%] | 37% (26/70) [31%, 45%] |
| gpt-6-luna high | 71% (27/38) [56%, 82%] | 26% (24/91) [17%, 43%] | 37% (22/59) [30%, 46%] | 31% (29/93) [25%, 37%] | 8.9% (11/123) [5.4%, 15%] | 22% (14/64) [16%, 31%] | 29% (12/41) [15%, 50%] |
| gpt-6-luna low | 74% (20/27) [59%, 95%] | 46% (21/46) [31%, 67%] | 27% (18/66) [18%, 38%] | 34% (22/64) [22%, 49%] | 35% (21/60) [24%, 49%] | 18% (13/72) [9.2%, 24%] | 36% (13/36) [26%, 48%] |
| gpt-6-luna max | 64% (23/36) [54%, 80%] | 26% (26/99) [17%, 45%] | 27% (23/84) [21%, 36%] | 28% (25/90) [23%, 33%] | 13% (12/91) [9.6%, 17%] | 24% (17/70) [15%, 34%] | 69% (18/26) [54%, 86%] |
| gpt-6-luna medium | 68% (410/603) [64%, 73%] | 36% (393/1097) [33%, 39%] | 34% (363/1071) [32%, 36%] | 29% (400/1384) [26%, 32%] | 16% (261/1613) [14%, 19%] | 21% (264/1259) [19%, 23%] | 39% (235/598) [34%, 44%] |
| gpt-6-luna off | 54% (21/39) [40%, 94%] | 52% (24/46) [39%, 65%] | 33% (15/46) [28%, 47%] | 24% (17/72) [11%, 35%] | 27% (26/95) [19%, 39%] | 30% (14/46) [25%, 41%] | 56% (20/36) [40%, 77%] |
| gpt-6-luna xhigh | 57% (26/46) [47%, 76%] | 29% (33/113) [19%, 43%] | 25% (32/128) [19%, 31%] | 22% (35/160) [12%, 35%] | 11% (29/259) [8.3%, 15%] | 34% (32/95) [25%, 44%] | 65% (24/37) [51%, 85%] |
| gpt-6.1-sol high | 48% (30/63) [43%, 55%] | 37% (41/110) [30%, 47%] | 34% (41/122) [29%, 38%] | 18% (28/152) [7.5%, 33%] | 12% (23/194) [7.3%, 17%] | 36% (33/92) [28%, 47%] | 33% (28/85) [25%, 42%] |
| gpt-6.1-sol low | 55% (36/66) [46%, 65%] | 26% (31/118) [19%, 35%] | 28% (33/118) [23%, 34%] | 14% (19/132) [8.3%, 22%] | 9.3% (17/183) [5.2%, 13%] | 27% (26/95) [17%, 38%] | 38% (25/65) [28%, 52%] |
| gpt-6.1-sol max | 51% (93/183) [45%, 59%] | 40% (85/211) [33%, 49%] | 29% (91/311) [25%, 34%] | 15% (48/325) [11%, 19%] | 13% (62/484) [9.7%, 16%] | 42% (72/173) [33%, 53%] | 30% (46/151) [26%, 37%] |
| gpt-6.1-sol medium | 50% (374/745) [47%, 54%] | 35% (373/1071) [31%, 39%] | 28% (360/1265) [27%, 30%] | 14% (250/1738) [13%, 16%] | 12% (234/1881) [11%, 14%] | 34% (308/907) [30%, 38%] | 39% (263/683) [36%, 41%] |
| gpt-6.1-sol xhigh | 41% (37/90) [33%, 55%] | 49% (59/121) [38%, 62%] | 27% (37/135) [22%, 32%] | 25% (59/239) [20%, 29%] | 15% (33/223) [12%, 18%] | 26% (29/112) [19%, 34%] | 31% (22/71) [23%, 41%] |
| gpt-6.1-terra high | 50% (25/50) [38%, 69%] | 31% (30/98) [22%, 39%] | 24% (20/85) [16%, 29%] | 4.0% (7/176) [0.9%, 7.1%] | 9.0% (16/178) [5.2%, 12%] | 28% (18/65) [11%, 54%] | 43% (10/23) [30%, 62%] |
| gpt-6.1-terra low | 45% (35/78) [33%, 58%] | 32% (33/102) [22%, 43%] | 27% (29/106) [22%, 36%] | 3.2% (5/158) [1.5%, 4.7%] | 8.3% (18/218) [5.7%, 11%] | 27% (25/91) [21%, 40%] | 51% (21/41) [44%, 63%] |
| gpt-6.1-terra max | 43% (44/102) [34%, 55%] | 41% (42/102) [31%, 53%] | 25% (34/134) [20%, 33%] | 19% (36/193) [14%, 23%] | 11% (28/248) [7.7%, 16%] | 41% (49/119) [33%, 53%] | 44% (21/48) [37%, 54%] |
| gpt-6.1-terra medium | 37% (32/86) [26%, 51%] | 35% (36/103) [24%, 49%] | 34% (19/56) [21%, 44%] | 8.0% (11/137) [4.2%, 11%] | 9.4% (15/159) [4.7%, 14%] | 38% (24/64) [25%, 47%] | 54% (14/26) [47%, 67%] |
| gpt-6.1-terra off | 49% (33/68) [40%, 62%] | 51% (33/65) [42%, 60%] | 30% (28/94) [25%, 35%] | 4.5% (7/157) [1.4%, 7.8%] | 4.1% (5/122) [1.5%, 7.0%] | 35% (19/55) [24%, 55%] | 25% (8/32) [9.1%, 47%] |
| gpt-6.1-terra xhigh | 43% (29/67) [37%, 53%] | 32% (24/74) [18%, 52%] | 32% (27/84) [26%, 38%] | 11% (16/152) [5.7%, 15%] | 9.4% (13/139) [4.7%, 16%] | 19% (14/72) [7.6%, 33%] | 47% (18/38) [37%, 63%] |

### Astra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6-astra high | 21% (3/14) [17%, 50%] | 78% (7/9) [50%, 86%] | 37% (7/19) [25%, 40%] | 24% (6/25) [17%, 26%] | 22% (4/18) [21%, 25%] | 33% (2/6) [20%, 100%] | 33% (4/12) [20%, 43%] |
| gpt-6-astra low | 57% (4/7) [50%, 60%] | 40% (6/15) [40%, 40%] | 36% (8/22) [29%, 40%] | 8.8% (3/34) [0%, 17%] | 18% (3/17) [13%, 33%] | 14% (2/14) [0%, 33%] | 50% (3/6) [50%, 50%] |
| gpt-6-astra medium | 90% (9/10) [80%, 100%] | 43% (10/23) [36%, 56%] | 33% (9/27) [25%, 40%] | 6.5% (3/46) [3.6%, 11%] | 13% (3/23) [7.7%, 20%] | 40% (2/5) [25%, 100%] | 23% (3/13) [20%, 33%] |
| gpt-6-astra off | 50% (3/6) [50%, 50%] | 100% (2/2) [100%, 100%] | 100% (1/1) [100%, 100%] | 10% (1/10) [10%, 10%] | 6.3% (1/16) [6.3%, 6.3%] | – | – |

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
| claude-opus-5-5 high | 48% (80/166) [42%, 57%] | 34% (84/249) [29%, 40%] | 24% (54/223) [19%, 30%] | 16% (59/362) [12%, 22%] | 13% (53/395) [11%, 16%] | 27% (57/215) [18%, 39%] | 46% (58/126) [38%, 59%] |
| claude-opus-5-5 low | 54% (76/140) [49%, 61%] | 20% (47/239) [15%, 27%] | 27% (50/187) [21%, 34%] | 15% (42/276) [12%, 20%] | 12% (34/273) [9.3%, 15%] | 38% (56/147) [28%, 53%] | 46% (46/101) [35%, 57%] |
| claude-opus-5-5 max | 35% (64/185) [29%, 42%] | 36% (63/173) [29%, 49%] | 28% (55/196) [25%, 31%] | 25% (56/228) [21%, 28%] | 16% (35/225) [11%, 21%] | 38% (61/159) [29%, 52%] | 35% (36/104) [27%, 45%] |
| claude-opus-5-5 medium | 50% (149/299) [44%, 57%] | 29% (130/442) [26%, 34%] | 27% (104/379) [24%, 32%] | 17% (103/623) [14%, 19%] | 13% (85/659) [11%, 15%] | 38% (122/320) [31%, 47%] | 50% (84/169) [43%, 58%] |
| claude-opus-5-5 off | 37% (10/27) [33%, 44%] | 33% (8/24) [22%, 50%] | 34% (10/29) [28%, 40%] | 18% (10/57) [9.0%, 28%] | 19% (11/57) [13%, 34%] | 28% (10/36) [11%, 60%] | 67% (8/12) [43%, 100%] |
| claude-opus-5-5 xhigh | 47% (106/225) [42%, 53%] | 39% (105/267) [34%, 46%] | 25% (74/291) [23%, 29%] | 15% (60/412) [11%, 20%] | 14% (61/439) [11%, 17%] | 36% (80/225) [28%, 45%] | 32% (59/186) [27%, 38%] |

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

### Terra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-5.6-terra high | 57% (161/281) [51%, 65%] | 14% (85/594) [11%, 18%] | 36% (131/360) [32%, 41%] | 17% (104/609) [14%, 21%] | 9.2% (76/828) [7.2%, 11%] | 16% (96/600) [12%, 21%] | 71% (104/147) [64%, 78%] |
| gpt-5.6-terra low | 60% (169/284) [55%, 65%] | 12% (75/643) [8.3%, 16%] | 36% (138/380) [34%, 39%] | 16% (114/694) [12%, 21%] | 8.2% (63/768) [6.2%, 10%] | 15% (90/598) [11%, 20%] | 63% (113/178) [56%, 73%] |
| gpt-5.6-terra max | 54% (172/316) [50%, 60%] | 35% (155/444) [29%, 42%] | 28% (121/434) [25%, 31%] | 22% (145/660) [18%, 26%] | 13% (120/955) [11%, 14%] | 29% (141/488) [24%, 35%] | 60% (108/181) [53%, 67%] |
| gpt-5.6-terra medium | 55% (160/292) [49%, 61%] | 11% (70/655) [8.1%, 14%] | 42% (145/345) [38%, 47%] | 15% (91/627) [11%, 19%] | 9.5% (69/725) [7.1%, 12%] | 15% (76/495) [12%, 20%] | 74% (108/145) [65%, 84%] |
| gpt-5.6-terra xhigh | 54% (170/312) [50%, 60%] | 19% (130/675) [15%, 24%] | 35% (139/396) [31%, 40%] | 18% (123/693) [14%, 22%] | 10% (90/883) [8.4%, 12%] | 18% (103/570) [15%, 22%] | 69% (116/169) [59%, 80%] |

### gpt-6.1-terra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6.1-terra high | 55% (11/20) [44%, 67%] | 45% (10/22) [29%, 67%] | 35% (12/34) [25%, 45%] | 6.3% (3/48) [0%, 7.4%] | 8.3% (1/12) [0%, 33%] | 43% (6/14) [27%, 100%] | 44% (8/18) [36%, 100%] |
| gpt-6.1-terra low | 33% (15/46) [31%, 33%] | 23% (8/35) [5.3%, 44%] | 24% (4/17) [13%, 33%] | 0% (0/54) [0%, 0%] | 3.3% (1/30) [0%, 17%] | 37% (7/19) [23%, 67%] | 42% (5/12) [25%, 75%] |
| gpt-6.1-terra max | 45% (5/11) [45%, 45%] | 35% (6/17) [35%, 35%] | 22% (4/18) [22%, 22%] | 36% (4/11) [36%, 36%] | 14% (4/29) [14%, 14%] | 35% (6/17) [35%, 35%] | 42% (5/12) [42%, 42%] |
| gpt-6.1-terra medium | 44% (19/43) [33%, 67%] | 37% (19/52) [28%, 40%] | 32% (12/38) [19%, 58%] | 5.2% (3/58) [1.4%, 14%] | 7.8% (4/51) [0%, 12%] | 25% (14/56) [16%, 42%] | 33% (11/33) [26%, 42%] |
| gpt-6.1-terra off | 41% (11/27) [29%, 61%] | 25% (7/28) [9.1%, 50%] | 22% (8/37) [11%, 35%] | 8.5% (5/59) [3.4%, 14%] | 13% (5/40) [8.3%, 16%] | 36% (8/22) [31%, 56%] | 33% (6/18) [22%, 60%] |
| gpt-6.1-terra xhigh | 33% (14/42) [29%, 44%] | 56% (10/18) [20%, 71%] | 35% (13/37) [29%, 42%] | 5.6% (4/72) [3.9%, 9.5%] | 10% (6/58) [0%, 12%] | 48% (11/23) [32%, 82%] | 63% (10/16) [44%, 100%] |

## Adrenaline steals when legal

Agent decisions where stealing an item with adrenaline is legal, and the share that steal it. These are separate from the player's own items.

### Cross-model

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 17% (8/48) [6.8%, 34%] | 1.1% (1/89) [0%, 2.9%] | 13% (8/62) [6.0%, 21%] | 5.7% (5/87) [1.0%, 15%] | 3.2% (4/125) [0%, 8.6%] | 4.9% (4/82) [0%, 15%] | 15% (7/46) [6.7%, 38%] |
| claude-haiku-4-5-20251001 low | 15% (6/41) [3.6%, 31%] | 0.9% (1/106) [0%, 2.8%] | 16% (13/82) [9.3%, 22%] | 2.1% (3/146) [0%, 6.1%] | 1.7% (3/172) [0%, 3.6%] | 2.3% (3/128) [0%, 5.4%] | 36% (23/64) [26%, 46%] |
| claude-haiku-4-5-20251001 medium | 18% (60/339) [13%, 23%] | 1.5% (10/671) [0.6%, 2.6%] | 16% (62/390) [13%, 20%] | 3.6% (27/741) [2.3%, 5.2%] | 5.5% (44/805) [3.9%, 7.2%] | 2.7% (15/564) [1.4%, 4.1%] | 34% (74/215) [27%, 42%] |
| claude-haiku-4-5-20251001 minimal | 12% (7/58) [4.7%, 25%] | 0.8% (1/121) [0%, 2.7%] | 12% (8/69) [4.9%, 23%] | 4.0% (4/99) [1.1%, 7.7%] | 4.6% (7/152) [0.6%, 11%] | 4.0% (4/100) [0.8%, 9.8%] | 42% (10/24) [22%, 73%] |
| claude-haiku-4-5-20251001 off | 11% (5/44) [1.4%, 31%] | 0% (0/42) [0%, 0%] | 11% (4/38) [2.2%, 21%] | 3.4% (2/58) [0%, 8.2%] | 4.0% (4/101) [1.1%, 7.1%] | 8.9% (4/45) [0%, 24%] | 7.7% (3/39) [0%, 16%] |
| claude-haiku-5-5 high | 48% (15/31) [36%, 60%] | 13% (5/39) [4.9%, 22%] | 23% (5/22) [6.7%, 38%] | 5.7% (3/53) [0%, 14%] | 14% (11/79) [7.4%, 22%] | 16% (8/50) [8.5%, 24%] | 61% (14/23) [46%, 80%] |
| claude-haiku-5-5 low | 22% (16/74) [13%, 36%] | 6.7% (13/193) [4.3%, 9.7%] | 25% (20/80) [16%, 36%] | 8.0% (16/200) [4.0%, 13%] | 6.8% (13/192) [3.3%, 12%] | 3.2% (5/158) [1.0%, 6.0%] | 37% (18/49) [22%, 55%] |
| claude-haiku-5-5 max | 14% (2/14) [0%, 33%] | 13% (3/23) [0%, 29%] | 17% (3/18) [11%, 23%] | 14% (4/29) [3.3%, 26%] | 8.7% (2/23) [0%, 21%] | 28% (5/18) [17%, 50%] | 56% (5/9) [25%, 86%] |
| claude-haiku-5-5 medium | 23% (66/286) [18%, 30%] | 8.6% (45/523) [6.1%, 11%] | 27% (75/280) [22%, 33%] | 8.2% (45/549) [6.0%, 11%] | 6.8% (38/558) [4.9%, 8.9%] | 16% (66/414) [13%, 20%] | 29% (46/161) [21%, 38%] |
| claude-haiku-5-5 off | 26% (19/74) [16%, 39%] | 9.8% (23/234) [6.0%, 14%] | 25% (26/102) [17%, 35%] | 12% (21/177) [7.0%, 17%] | 9.4% (22/233) [5.5%, 14%] | 7.5% (14/186) [4.2%, 12%] | 13% (17/136) [7.1%, 19%] |
| claude-haiku-5-5 xhigh | 31% (8/26) [14%, 50%] | 8.6% (3/35) [2.4%, 18%] | 36% (8/22) [21%, 48%] | 5.3% (2/38) [0%, 20%] | 9.8% (5/51) [2.9%, 16%] | 16% (4/25) [3.7%, 33%] | 56% (5/9) [22%, 86%] |
| claude-opus-5-5 high | 8.7% (2/23) [0%, 36%] | 14% (3/22) [3.2%, 29%] | 17% (2/12) [0%, 43%] | 3.4% (2/58) [0%, 12%] | 13% (5/40) [5.9%, 21%] | 15% (5/33) [5.6%, 28%] | 50% (7/14) [29%, 100%] |
| claude-opus-5-5 low | 75% (3/4) [25%, 100%] | 5.3% (2/38) [0%, 13%] | 50% (5/10) [13%, 80%] | 0% (0/31) [0%, 0%] | 8.3% (3/36) [2.3%, 19%] | 9.5% (2/21) [0%, 23%] | 38% (5/13) [14%, 67%] |
| claude-opus-5-5 max | 55% (6/11) [29%, 100%] | 0% (0/22) [0%, 0%] | 15% (2/13) [0%, 25%] | 3.6% (1/28) [0%, 7.9%] | 12% (5/42) [2.2%, 28%] | 19% (5/27) [2.8%, 42%] | 38% (3/8) [25%, 100%] |
| claude-opus-5-5 medium | 33% (70/215) [27%, 40%] | 6.6% (32/483) [4.5%, 9.2%] | 21% (54/263) [16%, 25%] | 5.4% (31/572) [3.6%, 7.3%] | 8.6% (52/605) [6.7%, 11%] | 12% (45/387) [8.6%, 15%] | 35% (57/162) [28%, 43%] |
| claude-opus-5-5 off | 27% (7/26) [12%, 57%] | 1.9% (1/53) [0%, 7.9%] | 16% (5/31) [4.9%, 45%] | 5.9% (5/85) [1.4%, 12%] | 10% (8/80) [5.4%, 16%] | 6.5% (4/62) [1.6%, 13%] | 34% (10/29) [21%, 54%] |
| claude-opus-5-5 xhigh | 28% (28/99) [21%, 36%] | 3.2% (5/156) [0.8%, 7.1%] | 16% (20/126) [10%, 22%] | 5.6% (10/179) [2.0%, 11%] | 12% (29/250) [7.4%, 17%] | 10% (15/146) [6.6%, 15%] | 36% (21/58) [27%, 47%] |
| claude-sonnet-5-5 high | 17% (5/29) [11%, 23%] | 4.3% (3/69) [0%, 14%] | 9.6% (5/52) [2.2%, 22%] | 3.1% (2/64) [0%, 7.5%] | 4.4% (4/91) [1.0%, 12%] | 8.0% (4/50) [1.4%, 17%] | 25% (2/8) [17%, 50%] |
| claude-sonnet-5-5 low | 34% (12/35) [14%, 64%] | 0% (0/92) [0%, 0%] | 5.8% (4/69) [0%, 10%] | 3.1% (3/98) [0%, 6.7%] | 2.6% (3/117) [0%, 4.6%] | 0% (0/50) [0%, 0%] | 26% (7/27) [12%, 44%] |
| claude-sonnet-5-5 max | 23% (15/64) [11%, 44%] | 3.7% (3/81) [0%, 8.4%] | 20% (17/85) [13%, 30%] | 3.1% (3/97) [0%, 7.9%] | 4.0% (5/124) [0.8%, 7.8%] | 27% (18/67) [18%, 38%] | 60% (12/20) [36%, 100%] |
| claude-sonnet-5-5 medium | 36% (107/297) [30%, 42%] | 2.3% (13/571) [1.0%, 3.7%] | 12% (48/386) [9.1%, 16%] | 2.3% (14/613) [1.2%, 3.5%] | 3.2% (25/770) [2.1%, 4.7%] | 5.5% (30/544) [3.9%, 7.6%] | 19% (48/255) [14%, 24%] |
| claude-sonnet-5-5 off | 29% (9/31) [14%, 50%] | 1.9% (1/52) [0%, 6.3%] | 9.4% (5/53) [3.0%, 22%] | 8.6% (8/93) [1.2%, 19%] | 5.9% (5/85) [0%, 8.9%] | 7.0% (5/71) [1.7%, 13%] | 21% (9/43) [10%, 35%] |
| claude-sonnet-5-5 xhigh | 29% (12/42) [19%, 53%] | 6.5% (4/62) [1.4%, 14%] | 16% (7/44) [10%, 22%] | 5.3% (6/113) [1.1%, 11%] | 8.0% (6/75) [2.6%, 15%] | 13% (8/63) [7.4%, 21%] | 41% (9/22) [27%, 62%] |
| gpt-5.6-terra high | 57% (8/14) [26%, 100%] | 0% (0/46) [0%, 0%] | 32% (6/19) [10%, 43%] | 0% (0/38) [0%, 0%] | 2.0% (1/49) [0%, 7.1%] | 9.4% (3/32) [0%, 22%] | 38% (3/8) [0%, 100%] |
| gpt-5.6-terra low | 40% (4/10) [0%, 80%] | 6.9% (2/29) [0%, 29%] | 26% (6/23) [14%, 47%] | 1.9% (1/54) [0%, 4.9%] | 2.0% (1/50) [0%, 9.1%] | 3.6% (1/28) [0%, 7.0%] | 57% (4/7) [40%, 100%] |
| gpt-5.6-terra max | 36% (4/11) [33%, 50%] | 12% (3/26) [0%, 38%] | 17% (3/18) [0%, 50%] | 11% (3/28) [3.0%, 22%] | 13% (3/23) [4.5%, 25%] | 10% (1/10) [0%, 33%] | 64% (7/11) [45%, 100%] |
| gpt-5.6-terra medium | 31% (79/252) [26%, 37%] | 2.3% (11/473) [1.1%, 3.7%] | 23% (86/378) [19%, 27%] | 5.8% (28/479) [3.8%, 8.4%] | 3.0% (18/606) [1.7%, 4.4%] | 4.7% (20/430) [2.8%, 6.9%] | 57% (78/136) [48%, 68%] |
| gpt-5.6-terra xhigh | 33% (4/12) [7.7%, 75%] | 8.0% (2/25) [0%, 25%] | 33% (9/27) [22%, 57%] | 3.8% (1/26) [0%, 11%] | 6.3% (2/32) [0%, 19%] | 10% (2/20) [0%, 38%] | 80% (4/5) [75%, 100%] |
| gpt-6-astra high | 34% (10/29) [17%, 65%] | 9.4% (3/32) [4.3%, 12%] | 22% (8/36) [13%, 31%] | 1.8% (1/56) [0%, 7.5%] | 14% (5/36) [4.8%, 30%] | 14% (5/37) [5.1%, 25%] | 33% (7/21) [14%, 67%] |
| gpt-6-astra low | 38% (6/16) [20%, 67%] | 6.3% (2/32) [0%, 19%] | 38% (8/21) [22%, 64%] | 0% (0/33) [0%, 0%] | 2.3% (1/44) [0%, 5.7%] | 8.0% (2/25) [0%, 27%] | 100% (3/3) [100%, 100%] |
| gpt-6-astra medium | 35% (98/284) [28%, 42%] | 3.4% (21/617) [2.0%, 5.0%] | 24% (88/367) [21%, 27%] | 2.8% (18/647) [1.7%, 4.1%] | 8.3% (69/828) [6.7%, 10%] | 24% (102/424) [20%, 29%] | 41% (80/194) [36%, 48%] |
| gpt-6-astra off | 17% (4/23) [7.1%, 24%] | 2.1% (1/48) [0%, 4.7%] | 19% (6/32) [12%, 29%] | 1.8% (1/55) [0%, 6.3%] | 4.8% (3/63) [0%, 14%] | 20% (9/45) [10%, 41%] | 76% (13/17) [65%, 92%] |
| gpt-6-luna high | 32% (6/19) [18%, 42%] | 0% (0/35) [0%, 0%] | 17% (3/18) [0%, 22%] | 4.3% (1/23) [0%, 14%] | 3.7% (1/27) [0%, 19%] | 8.3% (2/24) [0%, 33%] | 50% (4/8) [0%, 100%] |
| gpt-6-luna low | 33% (5/15) [20%, 64%] | 0% (0/9) [0%, 0%] | 0% (0/26) [0%, 0%] | 21% (5/24) [13%, 26%] | 11% (5/46) [3.6%, 24%] | 8.3% (2/24) [0%, 29%] | 43% (3/7) [25%, 67%] |
| gpt-6-luna max | 33% (3/9) [11%, 63%] | 3.4% (1/29) [0%, 6.8%] | 18% (3/17) [0%, 25%] | 5.6% (1/18) [0%, 7.9%] | 11% (5/46) [3.7%, 30%] | 17% (6/36) [9.7%, 23%] | 60% (3/5) [50%, 67%] |
| gpt-6-luna medium | 22% (63/284) [18%, 27%] | 5.6% (30/535) [3.8%, 7.7%] | 11% (35/310) [8.0%, 15%] | 8.2% (44/539) [5.8%, 11%] | 7.0% (49/699) [5.3%, 9.0%] | 4.6% (20/435) [2.9%, 6.4%] | 34% (61/180) [28%, 41%] |
| gpt-6-luna off | 6.9% (2/29) [0%, 9.1%] | 8.7% (4/46) [4.0%, 13%] | 4.2% (1/24) [0%, 13%] | 5.4% (2/37) [0%, 40%] | 17% (6/36) [2.2%, 47%] | 0% (0/16) [0%, 0%] | 43% (6/14) [13%, 100%] |
| gpt-6-luna xhigh | 29% (5/17) [10%, 100%] | 11% (2/19) [0%, 27%] | 16% (5/32) [5.9%, 29%] | 24% (11/45) [13%, 32%] | 7.1% (4/56) [2.3%, 11%] | 13% (5/38) [4.3%, 24%] | 60% (9/15) [35%, 89%] |
| gpt-6.1-sol high | 24% (10/41) [13%, 44%] | 0% (0/23) [0%, 0%] | 25% (9/36) [11%, 42%] | 3.6% (2/55) [0%, 5.6%] | 9.8% (6/61) [4.9%, 17%] | 16% (8/51) [7.3%, 33%] | 36% (10/28) [26%, 55%] |
| gpt-6.1-sol low | 64% (9/14) [42%, 89%] | 12% (5/42) [2.6%, 26%] | 8.6% (3/35) [2.9%, 15%] | 6.7% (3/45) [0%, 18%] | 11% (6/55) [7.1%, 13%] | 20% (7/35) [7.4%, 31%] | 70% (7/10) [44%, 89%] |
| gpt-6.1-sol max | 28% (18/64) [18%, 39%] | 4.1% (5/121) [1.2%, 7.8%] | 17% (20/115) [14%, 23%] | 4.8% (7/145) [1.1%, 11%] | 11% (19/166) [8.5%, 14%] | 26% (19/73) [14%, 42%] | 48% (11/23) [24%, 75%] |
| gpt-6.1-sol medium | 31% (60/191) [24%, 41%] | 5.0% (22/443) [3.0%, 7.2%] | 22% (63/289) [18%, 26%] | 3.5% (17/482) [1.9%, 5.5%] | 9.3% (56/605) [7.3%, 11%] | 20% (73/365) [16%, 26%] | 39% (67/172) [33%, 46%] |
| gpt-6.1-sol xhigh | 17% (4/24) [3.4%, 35%] | 0% (0/47) [0%, 0%] | 19% (7/36) [8.9%, 32%] | 1.2% (1/84) [0%, 3.3%] | 9.8% (4/41) [3.0%, 17%] | 23% (12/52) [15%, 34%] | 50% (8/16) [31%, 77%] |
| gpt-6.1-terra high | 52% (11/21) [33%, 85%] | 25% (6/24) [7.1%, 73%] | 25% (4/16) [7.7%, 47%] | 4.5% (3/67) [0%, 7.7%] | 7.5% (4/53) [2.0%, 15%] | 16% (5/32) [3.4%, 27%] | 53% (9/17) [33%, 83%] |
| gpt-6.1-terra low | 67% (12/18) [56%, 85%] | 12% (3/26) [0%, 27%] | 31% (9/29) [22%, 50%] | 5.6% (2/36) [0%, 13%] | 2.6% (1/39) [0%, 10%] | 26% (7/27) [12%, 53%] | 46% (6/13) [19%, 82%] |
| gpt-6.1-terra max | 21% (9/43) [11%, 35%] | 18% (6/34) [2.7%, 48%] | 24% (9/37) [16%, 35%] | 1.6% (1/63) [0%, 4.7%] | 5.0% (3/60) [0%, 11%] | 34% (10/29) [22%, 50%] | 36% (8/22) [17%, 61%] |
| gpt-6.1-terra medium | 58% (7/12) [38%, 100%] | 3.1% (1/32) [0%, 14%] | 18% (3/17) [7.1%, 33%] | 2.4% (1/41) [0%, 11%] | 0% (0/30) [0%, 0%] | 11% (2/18) [0%, 25%] | 64% (7/11) [38%, 86%] |
| gpt-6.1-terra off | 44% (7/16) [17%, 82%] | 0% (0/29) [0%, 0%] | 27% (4/15) [7.7%, 46%] | 0% (0/26) [0%, 0%] | 5.7% (2/35) [0%, 14%] | 10% (2/20) [0%, 29%] | 28% (5/18) [15%, 50%] |
| gpt-6.1-terra xhigh | 33% (7/21) [12%, 65%] | 15% (3/20) [0%, 33%] | 26% (6/23) [10%, 41%] | 4.2% (1/24) [0%, 21%] | 3.4% (1/29) [0%, 16%] | 44% (8/18) [20%, 67%] | 40% (6/15) [33%, 67%] |

### Astra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6-astra high | 100% (1/1) [100%, 100%] | 0% (0/13) [0%, 0%] | 29% (2/7) [25%, 33%] | 0% (0/12) [0%, 0%] | 0% (0/3) [0%, 0%] | 100% (1/1) [100%, 100%] | 100% (1/1) [100%, 100%] |
| gpt-6-astra low | 100% (3/3) [100%, 100%] | 11% (1/9) [0%, 20%] | 50% (1/2) [0%, 100%] | 0% (0/14) [0%, 0%] | 25% (1/4) [25%, 25%] | – | – |
| gpt-6-astra medium | 33% (1/3) [0%, 100%] | 0% (0/9) [0%, 0%] | – | 9.1% (1/11) [0%, 13%] | 50% (1/2) [50%, 50%] | – | – |
| gpt-6-astra off | 100% (1/1) [100%, 100%] | 33% (1/3) [33%, 33%] | – | 0% (0/3) [0%, 0%] | – | – | – |

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
| claude-opus-5-5 high | 40% (23/58) [29%, 60%] | 3.9% (4/103) [0.8%, 9.3%] | 19% (18/94) [15%, 25%] | 11% (14/123) [5.6%, 19%] | 8.4% (10/119) [3.3%, 15%] | 23% (18/77) [16%, 33%] | 54% (14/26) [36%, 74%] |
| claude-opus-5-5 low | 38% (18/48) [24%, 54%] | 3.5% (3/86) [0%, 9.0%] | 30% (21/71) [24%, 37%] | 5.8% (7/121) [1.7%, 10%] | 8.3% (9/109) [4.3%, 14%] | 10% (8/77) [3.3%, 18%] | 35% (11/31) [17%, 54%] |
| claude-opus-5-5 max | 23% (17/75) [17%, 33%] | 4.7% (2/43) [0%, 16%] | 20% (16/80) [15%, 25%] | 14% (14/101) [7.1%, 23%] | 12% (11/91) [5.8%, 23%] | 7.9% (5/63) [1.8%, 17%] | 35% (19/55) [27%, 45%] |
| claude-opus-5-5 medium | 27% (34/128) [19%, 37%] | 5.4% (9/168) [2.2%, 10%] | 22% (30/138) [16%, 28%] | 7.9% (14/177) [4.4%, 12%] | 9.3% (23/248) [6.6%, 13%] | 16% (25/160) [11%, 21%] | 47% (27/58) [33%, 65%] |
| claude-opus-5-5 off | 43% (3/7) [11%, 100%] | 0% (0/20) [0%, 0%] | 25% (3/12) [20%, 33%] | 0% (0/19) [0%, 0%] | 7.7% (1/13) [0%, 23%] | 0% (0/11) [0%, 0%] | 25% (4/16) [18%, 36%] |
| claude-opus-5-5 xhigh | 24% (22/91) [14%, 38%] | 6.8% (9/133) [2.4%, 13%] | 22% (19/87) [16%, 29%] | 9.3% (10/107) [3.8%, 18%] | 8.0% (11/138) [3.5%, 13%] | 24% (21/88) [17%, 32%] | 36% (16/45) [22%, 58%] |

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

### Terra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-5.6-terra high | 34% (31/90) [24%, 47%] | 3.1% (7/227) [0.5%, 7.0%] | 33% (41/126) [26%, 41%] | 6.7% (12/178) [3.6%, 10%] | 7.5% (19/255) [4.3%, 11%] | 7.0% (14/200) [4.0%, 11%] | 74% (37/50) [62%, 87%] |
| gpt-5.6-terra low | 36% (36/101) [28%, 44%] | 2.2% (4/182) [0.5%, 4.9%] | 24% (29/122) [18%, 31%] | 7.7% (13/169) [3.3%, 13%] | 4.0% (12/302) [1.8%, 6.8%] | 4.3% (8/186) [1.4%, 8.1%] | 65% (34/52) [54%, 78%] |
| gpt-5.6-terra max | 30% (34/114) [22%, 42%] | 9.3% (18/193) [5.6%, 15%] | 29% (35/122) [22%, 35%] | 8.1% (15/185) [5.1%, 11%] | 7.0% (16/227) [4.1%, 11%] | 25% (41/167) [18%, 33%] | 64% (29/45) [52%, 79%] |
| gpt-5.6-terra medium | 35% (32/91) [27%, 45%] | 4.1% (7/170) [1.2%, 7.7%] | 26% (31/117) [21%, 33%] | 7.9% (18/228) [4.9%, 11%] | 2.7% (8/293) [1.0%, 4.8%] | 8.2% (14/170) [4.9%, 12%] | 68% (32/47) [57%, 81%] |
| gpt-5.6-terra xhigh | 33% (33/100) [25%, 45%] | 4.5% (11/242) [2.1%, 8.0%] | 28% (39/138) [22%, 35%] | 6.1% (10/163) [2.8%, 9.9%] | 6.2% (19/306) [3.2%, 10.0%] | 12% (25/206) [7.8%, 17%] | 64% (37/58) [52%, 76%] |

### gpt-6.1-terra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6.1-terra high | 50% (1/2) [0%, 100%] | 0% (0/2) [0%, 0%] | – | 25% (2/8) [0%, 40%] | 0% (0/6) [0%, 0%] | – | 67% (2/3) [67%, 67%] |
| gpt-6.1-terra low | 67% (4/6) [50%, 75%] | 4.8% (1/21) [0%, 13%] | 67% (4/6) [60%, 100%] | 0% (0/30) [0%, 0%] | 3.4% (1/29) [0%, 5.3%] | 8.3% (1/12) [0%, 33%] | 25% (3/12) [0%, 33%] |
| gpt-6.1-terra max | 0% (0/4) [0%, 0%] | 20% (1/5) [20%, 20%] | 29% (2/7) [29%, 29%] | 0% (0/1) [0%, 0%] | 0% (0/19) [0%, 0%] | 9.1% (1/11) [9.1%, 9.1%] | 100% (1/1) [100%, 100%] |
| gpt-6.1-terra medium | 80% (4/5) [25%, 100%] | 3.4% (1/29) [0%, 11%] | 33% (4/12) [0%, 60%] | 6.3% (3/48) [0%, 19%] | 6.1% (2/33) [0%, 7.1%] | 6.3% (1/16) [0%, 6.7%] | 25% (3/12) [25%, 25%] |
| gpt-6.1-terra off | 56% (5/9) [33%, 100%] | 21% (3/14) [0%, 29%] | 22% (2/9) [20%, 25%] | 3.8% (1/26) [0%, 13%] | 10% (1/10) [0%, 17%] | 17% (1/6) [0%, 25%] | 100% (3/3) [100%, 100%] |
| gpt-6.1-terra xhigh | 9.1% (1/11) [0%, 100%] | 17% (3/18) [0%, 27%] | 17% (1/6) [0%, 33%] | 17% (3/18) [0%, 75%] | 0% (0/27) [0%, 0%] | 15% (3/20) [5.6%, 100%] | 33% (2/6) [20%, 100%] |

## Item fates by item

Share of placed items used by their owner, by item. Adrenaline counts as used when its owner steals with it.

### Cross-model

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 69% (53/77) [58%, 79%] | 41% (38/93) [32%, 51%] | 56% (50/89) [49%, 66%] | 47% (38/81) [36%, 56%] | 28% (22/79) [18%, 38%] | 60% (37/62) [47%, 71%] | 56% (28/50) [39%, 69%] | 39% (37/94) [29%, 54%] |
| claude-haiku-4-5-20251001 low | 72% (86/119) [64%, 80%] | 46% (51/110) [37%, 56%] | 63% (73/115) [56%, 71%] | 54% (65/120) [43%, 65%] | 35% (39/110) [27%, 45%] | 50% (47/94) [40%, 58%] | 53% (31/59) [42%, 64%] | 39% (52/133) [32%, 45%] |
| claude-haiku-4-5-20251001 medium | 70% (441/629) [66%, 74%] | 37% (277/739) [34%, 41%] | 58% (397/682) [54%, 62%] | 47% (359/769) [43%, 51%] | 33% (255/771) [29%, 37%] | 48% (264/546) [44%, 53%] | 57% (262/461) [53%, 61%] | 42% (292/692) [38%, 46%] |
| claude-haiku-4-5-20251001 minimal | 72% (78/108) [63%, 80%] | 41% (48/117) [31%, 52%] | 59% (58/98) [51%, 67%] | 51% (54/105) [39%, 63%] | 36% (32/90) [26%, 47%] | 51% (42/83) [41%, 58%] | 55% (44/80) [45%, 64%] | 38% (41/109) [26%, 51%] |
| claude-haiku-4-5-20251001 off | 68% (39/57) [54%, 81%] | 54% (36/67) [45%, 65%] | 54% (44/81) [43%, 67%] | 40% (32/81) [27%, 51%] | 41% (24/59) [23%, 56%] | 57% (29/51) [42%, 70%] | 55% (23/42) [38%, 70%] | 34% (22/64) [19%, 51%] |
| claude-haiku-5-5 high | 74% (50/68) [62%, 87%] | 60% (58/97) [53%, 68%] | 57% (49/86) [44%, 68%] | 54% (58/107) [46%, 63%] | 45% (45/99) [34%, 57%] | 63% (39/62) [50%, 77%] | 66% (47/71) [53%, 78%] | 70% (61/87) [60%, 80%] |
| claude-haiku-5-5 low | 72% (126/176) [64%, 78%] | 55% (105/190) [46%, 64%] | 63% (107/170) [57%, 69%] | 59% (117/200) [54%, 64%] | 42% (77/183) [35%, 49%] | 73% (99/135) [64%, 82%] | 65% (77/119) [57%, 73%] | 57% (101/176) [50%, 65%] |
| claude-haiku-5-5 max | 64% (18/28) [44%, 84%] | 71% (22/31) [50%, 86%] | 59% (19/32) [47%, 75%] | 47% (15/32) [24%, 63%] | 37% (10/27) [24%, 45%] | 61% (17/28) [41%, 76%] | 76% (13/17) [61%, 92%] | 63% (24/38) [50%, 75%] |
| claude-haiku-5-5 medium | 68% (424/628) [64%, 71%] | 55% (394/717) [50%, 60%] | 60% (389/650) [56%, 63%] | 57% (405/710) [53%, 61%] | 38% (270/704) [35%, 42%] | 57% (297/525) [53%, 61%] | 64% (296/465) [59%, 68%] | 61% (381/621) [57%, 66%] |
| claude-haiku-5-5 off | 77% (140/182) [69%, 84%] | 60% (154/255) [54%, 67%] | 74% (150/204) [67%, 79%] | 66% (120/182) [58%, 73%] | 25% (51/205) [20%, 30%] | 56% (89/159) [49%, 63%] | 56% (77/138) [48%, 64%] | 57% (142/247) [51%, 64%] |
| claude-haiku-5-5 xhigh | 60% (30/50) [45%, 74%] | 53% (31/59) [35%, 72%] | 42% (16/38) [24%, 62%] | 45% (22/49) [37%, 54%] | 37% (20/54) [28%, 45%] | 54% (20/37) [45%, 67%] | 65% (24/37) [54%, 79%] | 67% (35/52) [52%, 81%] |
| claude-opus-5-5 high | 68% (32/47) [61%, 76%] | 66% (23/35) [56%, 74%] | 62% (26/42) [52%, 74%] | 50% (23/46) [31%, 70%] | 39% (15/38) [29%, 55%] | 70% (21/30) [55%, 85%] | 64% (23/36) [53%, 75%] | 55% (26/47) [35%, 78%] |
| claude-opus-5-5 low | 66% (35/53) [60%, 74%] | 50% (21/42) [23%, 74%] | 62% (24/39) [44%, 80%] | 29% (15/52) [13%, 42%] | 38% (20/53) [25%, 51%] | 58% (18/31) [46%, 73%] | 63% (12/19) [43%, 79%] | 50% (20/40) [38%, 60%] |
| claude-opus-5-5 max | 82% (18/22) [69%, 100%] | 78% (18/23) [70%, 94%] | 63% (15/24) [31%, 83%] | 56% (18/32) [42%, 68%] | 38% (9/24) [7.1%, 64%] | 74% (23/31) [59%, 87%] | 75% (15/20) [44%, 95%] | 71% (22/31) [56%, 82%] |
| claude-opus-5-5 medium | 68% (388/572) [64%, 72%] | 59% (375/636) [54%, 64%] | 57% (340/601) [53%, 61%] | 49% (363/746) [45%, 52%] | 40% (254/634) [37%, 44%] | 65% (325/499) [61%, 69%] | 65% (258/398) [60%, 69%] | 59% (341/574) [56%, 63%] |
| claude-opus-5-5 off | 71% (47/66) [57%, 81%] | 47% (26/55) [28%, 63%] | 64% (32/50) [53%, 76%] | 39% (28/72) [32%, 47%] | 35% (19/55) [23%, 46%] | 64% (29/45) [53%, 74%] | 66% (19/29) [44%, 82%] | 60% (40/67) [47%, 75%] |
| claude-opus-5-5 xhigh | 67% (123/184) [58%, 74%] | 59% (117/199) [51%, 67%] | 54% (111/205) [48%, 61%] | 49% (91/187) [40%, 56%] | 35% (70/201) [28%, 42%] | 61% (95/157) [52%, 69%] | 59% (68/116) [50%, 67%] | 63% (128/202) [57%, 70%] |
| claude-sonnet-5-5 high | 67% (42/63) [48%, 82%] | 62% (46/74) [51%, 74%] | 58% (38/65) [41%, 75%] | 59% (43/73) [47%, 70%] | 24% (17/72) [12%, 35%] | 62% (37/60) [47%, 76%] | 68% (34/50) [54%, 80%] | 37% (25/67) [21%, 60%] |
| claude-sonnet-5-5 low | 73% (38/52) [60%, 87%] | 51% (42/83) [36%, 68%] | 57% (34/60) [46%, 68%] | 49% (38/77) [37%, 63%] | 17% (12/70) [9.5%, 27%] | 65% (41/63) [54%, 76%] | 66% (31/47) [53%, 78%] | 52% (29/56) [36%, 67%] |
| claude-sonnet-5-5 max | 78% (84/108) [67%, 87%] | 53% (79/150) [44%, 62%] | 63% (87/138) [57%, 71%] | 42% (49/118) [31%, 50%] | 42% (58/138) [34%, 50%] | 62% (63/101) [55%, 71%] | 59% (39/66) [49%, 70%] | 58% (73/126) [49%, 67%] |
| claude-sonnet-5-5 medium | 73% (390/532) [69%, 77%] | 55% (329/595) [51%, 59%] | 58% (329/571) [54%, 61%] | 49% (336/688) [44%, 54%] | 25% (152/619) [21%, 28%] | 65% (304/471) [60%, 69%] | 64% (235/366) [59%, 69%] | 49% (285/587) [44%, 53%] |
| claude-sonnet-5-5 off | 76% (45/59) [68%, 86%] | 53% (36/68) [41%, 64%] | 51% (38/74) [40%, 64%] | 51% (46/90) [36%, 66%] | 24% (16/68) [14%, 36%] | 63% (38/60) [52%, 74%] | 57% (26/46) [44%, 70%] | 54% (42/78) [45%, 63%] |
| claude-sonnet-5-5 xhigh | 63% (43/68) [54%, 71%] | 75% (43/57) [64%, 84%] | 56% (34/61) [43%, 70%] | 61% (51/84) [50%, 72%] | 36% (28/78) [24%, 49%] | 64% (25/39) [49%, 77%] | 70% (40/57) [61%, 79%] | 66% (52/79) [55%, 76%] |
| gpt-5.6-terra high | 72% (26/36) [55%, 88%] | 28% (11/39) [16%, 40%] | 75% (21/28) [64%, 90%] | 50% (19/38) [37%, 64%] | 31% (11/36) [11%, 40%] | 46% (12/26) [29%, 59%] | 64% (14/22) [47%, 81%] | 54% (21/39) [36%, 70%] |
| gpt-5.6-terra low | 79% (26/33) [73%, 88%] | 41% (11/27) [12%, 59%] | 54% (26/48) [45%, 63%] | 47% (18/38) [32%, 58%] | 19% (6/31) [7.1%, 29%] | 41% (12/29) [13%, 69%] | 82% (18/22) [71%, 95%] | 50% (19/38) [33%, 68%] |
| gpt-5.6-terra max | 86% (25/29) [69%, 100%] | 78% (25/32) [60%, 91%] | 79% (23/29) [72%, 88%] | 55% (21/38) [38%, 71%] | 51% (23/45) [35%, 69%] | 73% (16/22) [52%, 91%] | 59% (13/22) [44%, 79%] | 73% (24/33) [59%, 89%] |
| gpt-5.6-terra medium | 74% (408/553) [69%, 78%] | 39% (219/560) [34%, 45%] | 64% (302/470) [61%, 68%] | 45% (249/552) [40%, 51%] | 28% (167/599) [23%, 32%] | 45% (182/407) [40%, 50%] | 72% (264/367) [68%, 76%] | 62% (320/516) [58%, 66%] |
| gpt-5.6-terra xhigh | 81% (34/42) [66%, 95%] | 53% (20/38) [38%, 72%] | 58% (28/48) [47%, 68%] | 60% (26/43) [38%, 79%] | 43% (17/40) [31%, 57%] | 67% (26/39) [55%, 77%] | 75% (24/32) [63%, 92%] | 67% (24/36) [53%, 81%] |
| gpt-6-astra high | 61% (34/56) [48%, 73%] | 62% (37/60) [49%, 76%] | 55% (30/55) [39%, 71%] | 39% (20/51) [24%, 53%] | 38% (21/56) [26%, 52%] | 56% (20/36) [43%, 66%] | 73% (27/37) [57%, 85%] | 67% (39/58) [56%, 80%] |
| gpt-6-astra low | 68% (28/41) [52%, 81%] | 54% (14/26) [36%, 65%] | 60% (28/47) [49%, 71%] | 36% (18/50) [20%, 69%] | 33% (18/54) [15%, 47%] | 67% (20/30) [45%, 86%] | 68% (17/25) [47%, 89%] | 48% (22/46) [33%, 64%] |
| gpt-6-astra medium | 72% (488/679) [69%, 75%] | 64% (525/820) [60%, 68%] | 59% (478/804) [56%, 63%] | 38% (319/848) [33%, 42%] | 35% (276/788) [32%, 38%] | 62% (371/595) [58%, 66%] | 64% (300/471) [59%, 68%] | 64% (476/738) [61%, 68%] |
| gpt-6-astra off | 69% (43/62) [52%, 85%] | 61% (38/62) [52%, 70%] | 67% (45/67) [59%, 77%] | 20% (12/60) [7.4%, 37%] | 34% (22/65) [21%, 45%] | 58% (30/52) [45%, 68%] | 60% (26/43) [49%, 75%] | 69% (37/54) [57%, 80%] |
| gpt-6-luna high | 79% (27/34) [65%, 92%] | 55% (24/44) [45%, 63%] | 67% (22/33) [54%, 80%] | 59% (29/49) [45%, 70%] | 24% (11/45) [13%, 35%] | 58% (14/24) [40%, 69%] | 60% (12/20) [33%, 89%] | 46% (17/37) [22%, 80%] |
| gpt-6-luna low | 77% (20/26) [55%, 95%] | 84% (21/25) [72%, 94%] | 67% (18/27) [53%, 76%] | 71% (22/31) [56%, 87%] | 64% (21/33) [39%, 88%] | 57% (13/23) [35%, 72%] | 76% (13/17) [59%, 94%] | 74% (20/27) [61%, 94%] |
| gpt-6-luna max | 72% (23/32) [45%, 91%] | 52% (26/50) [43%, 62%] | 62% (23/37) [49%, 82%] | 58% (25/43) [39%, 73%] | 29% (12/41) [13%, 51%] | 63% (17/27) [46%, 82%] | 86% (18/21) [69%, 96%] | 67% (22/33) [55%, 76%] |
| gpt-6-luna medium | 75% (410/544) [71%, 79%] | 65% (393/601) [61%, 69%] | 66% (363/554) [61%, 70%] | 63% (400/635) [60%, 67%] | 44% (261/598) [38%, 49%] | 59% (264/447) [54%, 64%] | 67% (235/351) [62%, 72%] | 57% (302/527) [52%, 62%] |
| gpt-6-luna off | 78% (21/27) [66%, 95%] | 83% (24/29) [70%, 94%] | 60% (15/25) [45%, 75%] | 65% (17/26) [35%, 87%] | 76% (26/34) [60%, 86%] | 61% (14/23) [50%, 76%] | 65% (20/31) [47%, 88%] | 57% (21/37) [44%, 75%] |
| gpt-6-luna xhigh | 76% (26/34) [58%, 91%] | 67% (33/49) [47%, 82%] | 57% (32/56) [48%, 64%] | 66% (35/53) [40%, 86%] | 42% (29/69) [31%, 57%] | 78% (32/41) [69%, 90%] | 69% (24/35) [55%, 79%] | 76% (41/54) [68%, 83%] |
| gpt-6.1-sol high | 59% (30/51) [44%, 71%] | 65% (41/63) [54%, 76%] | 68% (41/60) [59%, 78%] | 47% (28/59) [22%, 71%] | 37% (23/63) [23%, 51%] | 67% (33/49) [58%, 75%] | 60% (28/47) [49%, 73%] | 66% (45/68) [48%, 86%] |
| gpt-6.1-sol low | 69% (36/52) [59%, 80%] | 56% (31/55) [41%, 72%] | 61% (33/54) [50%, 72%] | 37% (19/52) [24%, 46%] | 29% (17/58) [17%, 42%] | 67% (26/39) [50%, 80%] | 76% (25/33) [57%, 90%] | 77% (40/52) [66%, 87%] |
| gpt-6.1-sol max | 74% (93/126) [64%, 84%] | 57% (85/150) [49%, 64%] | 66% (91/138) [59%, 73%] | 48% (48/101) [35%, 60%] | 42% (62/146) [33%, 51%] | 65% (72/111) [56%, 74%] | 65% (46/71) [57%, 73%] | 61% (99/162) [54%, 68%] |
| gpt-6.1-sol medium | 70% (374/535) [66%, 74%] | 60% (373/621) [56%, 64%] | 60% (360/603) [56%, 64%] | 41% (250/617) [36%, 45%] | 37% (234/626) [34%, 41%] | 64% (308/479) [60%, 68%] | 65% (263/407) [60%, 69%] | 64% (358/560) [60%, 68%] |
| gpt-6.1-sol xhigh | 60% (37/62) [51%, 72%] | 76% (59/78) [67%, 83%] | 51% (37/72) [42%, 60%] | 62% (59/95) [54%, 69%] | 48% (33/69) [34%, 61%] | 62% (29/47) [45%, 76%] | 61% (22/36) [46%, 76%] | 69% (36/52) [55%, 83%] |
| gpt-6.1-terra high | 66% (25/38) [50%, 80%] | 59% (30/51) [47%, 68%] | 53% (20/38) [41%, 61%] | 13% (7/55) [2.4%, 22%] | 34% (16/47) [20%, 46%] | 53% (18/34) [30%, 74%] | 45% (10/22) [25%, 64%] | 67% (42/63) [53%, 82%] |
| gpt-6.1-terra low | 74% (35/47) [59%, 91%] | 62% (33/53) [48%, 74%] | 57% (29/51) [49%, 65%] | 12% (5/43) [5.4%, 17%] | 26% (18/70) [16%, 38%] | 64% (25/39) [49%, 79%] | 70% (21/30) [57%, 83%] | 78% (40/51) [63%, 90%] |
| gpt-6.1-terra max | 75% (44/59) [65%, 85%] | 72% (42/58) [57%, 85%] | 63% (34/54) [52%, 74%] | 54% (36/67) [42%, 65%] | 44% (28/63) [33%, 56%] | 82% (49/60) [72%, 91%] | 60% (21/35) [43%, 75%] | 72% (46/64) [60%, 83%] |
| gpt-6.1-terra medium | 76% (32/42) [64%, 88%] | 69% (36/52) [57%, 82%] | 59% (19/32) [33%, 82%] | 25% (11/44) [13%, 35%] | 29% (15/51) [15%, 43%] | 62% (24/39) [39%, 77%] | 74% (14/19) [57%, 100%] | 55% (21/38) [41%, 68%] |
| gpt-6.1-terra off | 72% (33/46) [62%, 83%] | 79% (33/42) [66%, 93%] | 64% (28/44) [53%, 76%] | 14% (7/49) [5.0%, 24%] | 13% (5/38) [4.8%, 26%] | 70% (19/27) [57%, 88%] | 57% (8/14) [27%, 75%] | 59% (20/34) [38%, 82%] |
| gpt-6.1-terra xhigh | 81% (29/36) [69%, 89%] | 63% (24/38) [41%, 87%] | 69% (27/39) [57%, 80%] | 36% (16/45) [19%, 43%] | 32% (13/41) [16%, 48%] | 54% (14/26) [24%, 77%] | 67% (18/27) [55%, 79%] | 74% (32/43) [57%, 86%] |

### Astra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| gpt-6-astra high | 43% (3/7) [40%, 50%] | 78% (7/9) [75%, 100%] | 88% (7/8) [86%, 100%] | 60% (6/10) [50%, 63%] | 80% (4/5) [75%, 100%] | 67% (2/3) [50%, 100%] | 80% (4/5) [75%, 100%] | 83% (5/6) [67%, 100%] |
| gpt-6-astra low | 67% (4/6) [50%, 75%] | 50% (6/12) [0%, 67%] | 62% (8/13) [60%, 67%] | 18% (3/17) [0%, 50%] | 43% (3/7) [20%, 100%] | 50% (2/4) [0%, 100%] | 60% (3/5) [0%, 100%] | 86% (6/7) [67%, 100%] |
| gpt-6-astra medium | 75% (9/12) [71%, 80%] | 63% (10/16) [56%, 71%] | 53% (9/17) [50%, 55%] | 20% (3/15) [13%, 29%] | 43% (3/7) [33%, 50%] | 67% (2/3) [50%, 100%] | 75% (3/4) [67%, 100%] | 50% (3/6) [50%, 50%] |
| gpt-6-astra off | 100% (3/3) [100%, 100%] | 67% (2/3) [67%, 67%] | 100% (1/1) [100%, 100%] | 33% (1/3) [33%, 33%] | 20% (1/5) [20%, 20%] | – | – | 67% (2/3) [67%, 67%] |

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
| claude-opus-5-5 high | 67% (80/119) [57%, 76%] | 64% (84/132) [56%, 72%] | 47% (54/115) [38%, 56%] | 48% (59/124) [37%, 58%] | 40% (53/133) [31%, 48%] | 54% (57/105) [45%, 63%] | 68% (58/85) [61%, 75%] | 73% (101/139) [67%, 79%] |
| claude-opus-5-5 low | 68% (76/112) [58%, 77%] | 51% (47/92) [42%, 62%] | 53% (50/95) [44%, 62%] | 42% (42/101) [33%, 52%] | 35% (34/98) [26%, 44%] | 65% (56/86) [54%, 77%] | 64% (46/72) [56%, 71%] | 70% (77/110) [61%, 79%] |
| claude-opus-5-5 max | 57% (64/113) [45%, 67%] | 67% (63/94) [58%, 76%] | 54% (55/102) [45%, 63%] | 60% (56/94) [50%, 70%] | 51% (35/69) [37%, 67%] | 71% (61/86) [63%, 80%] | 65% (36/55) [54%, 79%] | 72% (84/116) [65%, 80%] |
| claude-opus-5-5 medium | 70% (149/213) [64%, 76%] | 62% (130/210) [56%, 68%] | 53% (104/198) [45%, 60%] | 44% (103/236) [37%, 50%] | 40% (85/211) [35%, 46%] | 66% (122/184) [59%, 73%] | 61% (84/137) [56%, 67%] | 70% (162/230) [66%, 76%] |
| claude-opus-5-5 off | 56% (10/18) [40%, 67%] | 47% (8/17) [14%, 89%] | 53% (10/19) [38%, 67%] | 40% (10/25) [23%, 59%] | 44% (11/25) [25%, 64%] | 53% (10/19) [31%, 74%] | 53% (8/15) [27%, 83%] | 55% (11/20) [38%, 86%] |
| claude-opus-5-5 xhigh | 69% (106/153) [61%, 77%] | 71% (105/147) [64%, 78%] | 54% (74/137) [45%, 64%] | 41% (60/147) [30%, 52%] | 41% (61/147) [33%, 50%] | 63% (80/126) [54%, 72%] | 58% (59/102) [48%, 68%] | 76% (108/143) [69%, 81%] |

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

### Terra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| gpt-5.6-terra high | 70% (161/230) [63%, 77%] | 36% (85/237) [29%, 43%] | 59% (131/222) [52%, 66%] | 42% (104/245) [35%, 50%] | 27% (76/279) [21%, 34%] | 47% (96/205) [38%, 55%] | 67% (104/155) [61%, 73%] | 65% (161/247) [58%, 72%] |
| gpt-5.6-terra low | 67% (169/251) [62%, 73%] | 31% (75/243) [24%, 39%] | 59% (138/234) [54%, 64%] | 40% (114/284) [32%, 49%] | 24% (63/259) [18%, 30%] | 44% (90/206) [35%, 52%] | 65% (113/173) [58%, 73%] | 60% (136/228) [54%, 65%] |
| gpt-5.6-terra max | 72% (172/239) [66%, 78%] | 63% (155/246) [58%, 69%] | 52% (121/234) [46%, 58%] | 57% (145/256) [48%, 65%] | 40% (120/299) [36%, 45%] | 66% (141/213) [59%, 73%] | 64% (108/169) [57%, 70%] | 80% (188/236) [75%, 84%] |
| gpt-5.6-terra medium | 63% (160/253) [57%, 69%] | 28% (70/251) [22%, 34%] | 59% (145/245) [53%, 64%] | 34% (91/264) [27%, 43%] | 27% (69/256) [21%, 33%] | 42% (76/181) [35%, 49%] | 66% (108/164) [59%, 73%] | 59% (142/241) [53%, 65%] |
| gpt-5.6-terra xhigh | 68% (170/249) [63%, 73%] | 50% (130/260) [43%, 57%] | 62% (139/223) [56%, 69%] | 47% (123/262) [40%, 54%] | 32% (90/279) [27%, 38%] | 52% (103/200) [44%, 59%] | 69% (116/169) [62%, 75%] | 67% (174/261) [60%, 73%] |

### gpt-6.1-terra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| gpt-6.1-terra high | 79% (11/14) [50%, 100%] | 50% (10/20) [40%, 60%] | 71% (12/17) [50%, 100%] | 18% (3/17) [0%, 29%] | 20% (1/5) [0%, 50%] | 60% (6/10) [50%, 67%] | 73% (8/11) [50%, 80%] | 50% (5/10) [0%, 75%] |
| gpt-6.1-terra low | 75% (15/20) [56%, 91%] | 40% (8/20) [14%, 54%] | 50% (4/8) [33%, 60%] | 0% (0/6) [0%, 0%] | 14% (1/7) [0%, 50%] | 100% (7/7) [100%, 100%] | 63% (5/8) [50%, 75%] | 67% (14/21) [64%, 70%] |
| gpt-6.1-terra max | 83% (5/6) [83%, 83%] | 60% (6/10) [60%, 60%] | 50% (4/8) [50%, 50%] | 100% (4/4) [100%, 100%] | 50% (4/8) [50%, 50%] | 75% (6/8) [75%, 75%] | 83% (5/6) [83%, 83%] | 100% (5/5) [100%, 100%] |
| gpt-6.1-terra medium | 79% (19/24) [61%, 88%] | 63% (19/30) [38%, 87%] | 67% (12/18) [43%, 90%] | 12% (3/25) [4.3%, 22%] | 24% (4/17) [0%, 50%] | 67% (14/21) [53%, 78%] | 61% (11/18) [42%, 87%] | 58% (18/31) [50%, 71%] |
| gpt-6.1-terra off | 65% (11/17) [43%, 90%] | 50% (7/14) [17%, 75%] | 47% (8/17) [36%, 56%] | 22% (5/23) [9.1%, 36%] | 29% (5/17) [20%, 33%] | 73% (8/11) [60%, 89%] | 60% (6/10) [25%, 100%] | 67% (16/24) [40%, 86%] |
| gpt-6.1-terra xhigh | 67% (14/21) [50%, 81%] | 50% (10/20) [10%, 93%] | 54% (13/24) [29%, 67%] | 18% (4/22) [14%, 25%] | 30% (6/20) [0%, 45%] | 73% (11/15) [55%, 100%] | 71% (10/14) [60%, 80%] | 39% (13/33) [28%, 63%] |

## Items held at elimination

Deaths, the share with at least one unused item, and the items held per death.

### Cross-model

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| claude-haiku-4-5-20251001 high | 89% (49/55) [80%, 97%] | 3.42 (188/55) [2.79, 4.04] | inverter 41, adrenaline 39, burner phone 32 |
| claude-haiku-4-5-20251001 low | 93% (62/67) [87%, 97%] | 3.39 (227/67) [2.99, 3.77] | adrenaline 55, inverter 46, burner phone 32 |
| claude-haiku-4-5-20251001 medium | 89% (403/451) [86%, 92%] | 3.42 (1543/451) [3.22, 3.63] | inverter 303, burner phone 280, beer 262 |
| claude-haiku-4-5-20251001 minimal | 87% (53/61) [78%, 95%] | 3.52 (215/61) [2.82, 4.22] | adrenaline 44, burner phone 43, inverter 33 |
| claude-haiku-4-5-20251001 off | 91% (41/45) [85%, 98%] | 3.56 (160/45) [3.06, 4.07] | beer 31, adrenaline 29, inverter 26 |
| claude-haiku-5-5 high | 90% (37/41) [82%, 98%] | 3.02 (124/41) [2.45, 3.59] | beer 26, inverter 24, handsaw 19 |
| claude-haiku-5-5 low | 93% (52/56) [86%, 98%] | 3.13 (175/56) [2.59, 3.61] | inverter 43, beer 30, burner phone 26 |
| claude-haiku-5-5 max | 91% (10/11) [73%, 100%] | 3.64 (40/11) [2.57, 4.44] | inverter 7, adrenaline 7, magnifying glass 6 |
| claude-haiku-5-5 medium | 92% (273/298) [89%, 94%] | 3.41 (1017/298) [3.19, 3.64] | inverter 197, burner phone 178, beer 159 |
| claude-haiku-5-5 off | 90% (83/92) [84%, 95%] | 3.41 (314/92) [3.00, 3.84] | inverter 78, adrenaline 57, burner phone 53 |
| claude-haiku-5-5 xhigh | 100% (28/28) [100%, 100%] | 4.04 (113/28) [3.41, 4.71] | inverter 20, beer 19, burner phone 18 |
| claude-opus-5-5 high | 94% (16/17) [80%, 100%] | 3.41 (58/17) [2.79, 4.18] | adrenaline 16, inverter 9, handsaw 8 |
| claude-opus-5-5 low | 89% (17/19) [76%, 100%] | 3.68 (70/19) [2.89, 4.71] | beer 17, inverter 15, burner phone 13 |
| claude-opus-5-5 max | 85% (11/13) [54%, 100%] | 2.31 (30/13) [1.38, 3.23] | beer 8, inverter 8, adrenaline 5 |
| claude-opus-5-5 medium | 92% (232/251) [89%, 95%] | 3.39 (850/251) [3.18, 3.61] | inverter 189, beer 164, adrenaline 119 |
| claude-opus-5-5 off | 88% (21/24) [75%, 100%] | 3.83 (92/24) [2.92, 4.81] | inverter 24, beer 15, burner phone 14 |
| claude-opus-5-5 xhigh | 90% (86/96) [84%, 95%] | 3.17 (304/96) [2.74, 3.60] | inverter 70, burner phone 54, beer 46 |
| claude-sonnet-5-5 high | 91% (30/33) [82%, 100%] | 3.36 (111/33) [2.53, 4.24] | inverter 35, adrenaline 23, burner phone 14 |
| claude-sonnet-5-5 low | 94% (34/36) [86%, 100%] | 3.97 (143/36) [3.42, 4.37] | inverter 38, burner phone 30, beer 22 |
| claude-sonnet-5-5 max | 100% (49/49) [100%, 100%] | 3.65 (179/49) [3.27, 4.02] | burner phone 42, adrenaline 38, inverter 28 |
| claude-sonnet-5-5 medium | 91% (253/277) [88%, 95%] | 3.52 (975/277) [3.26, 3.78] | inverter 245, adrenaline 177, beer 167 |
| claude-sonnet-5-5 off | 85% (23/27) [78%, 95%] | 3.56 (96/27) [2.74, 4.61] | beer 21, inverter 21, adrenaline 16 |
| claude-sonnet-5-5 xhigh | 88% (23/26) [75%, 100%] | 3.00 (78/26) [2.37, 3.62] | inverter 19, beer 17, handsaw 12 |
| gpt-5.6-terra high | 100% (20/20) [100%, 100%] | 3.55 (71/20) [2.96, 4.38] | burner phone 17, inverter 17, beer 12 |
| gpt-5.6-terra low | 93% (14/15) [83%, 100%] | 4.27 (64/15) [3.14, 5.70] | beer 13, inverter 13, adrenaline 11 |
| gpt-5.6-terra max | 71% (10/14) [64%, 88%] | 2.50 (35/14) [2.00, 3.57] | beer 10, inverter 7, adrenaline 5 |
| gpt-5.6-terra medium | 92% (249/272) [88%, 95%] | 3.33 (907/272) [3.05, 3.61] | inverter 204, burner phone 171, beer 170 |
| gpt-5.6-terra xhigh | 85% (17/20) [74%, 96%] | 2.55 (51/20) [1.89, 3.41] | burner phone 9, inverter 9, handsaw 8 |
| gpt-6-astra high | 95% (21/22) [85%, 100%] | 3.45 (76/22) [2.76, 4.00] | inverter 18, beer 17, burner phone 11 |
| gpt-6-astra low | 96% (22/23) [85%, 100%] | 3.48 (80/23) [2.83, 4.23] | inverter 22, adrenaline 16, burner phone 11 |
| gpt-6-astra medium | 93% (280/300) [90%, 96%] | 3.25 (974/300) [3.02, 3.50] | inverter 240, beer 207, adrenaline 128 |
| gpt-6-astra off | 90% (19/21) [76%, 100%] | 3.19 (67/21) [2.35, 4.00] | inverter 20, beer 17, handsaw 8 |
| gpt-6-luna high | 90% (18/20) [74%, 100%] | 3.95 (79/20) [3.30, 4.47] | inverter 21, burner phone 15, beer 13 |
| gpt-6-luna low | 64% (16/25) [46%, 79%] | 1.56 (39/25) [0.89, 2.45] | inverter 9, beer 6, handsaw 5 |
| gpt-6-luna max | 86% (19/22) [75%, 96%] | 3.14 (69/22) [2.44, 3.70] | inverter 20, burner phone 13, beer 12 |
| gpt-6-luna medium | 84% (325/386) [81%, 87%] | 2.76 (1067/386) [2.57, 2.95] | inverter 234, beer 180, adrenaline 169 |
| gpt-6-luna off | 88% (22/25) [74%, 100%] | 2.16 (54/25) [1.83, 2.52] | adrenaline 13, cigarettes 9, handsaw 7 |
| gpt-6-luna xhigh | 83% (20/24) [71%, 96%] | 2.63 (63/24) [2.18, 3.00] | inverter 17, handsaw 13, burner phone 9 |
| gpt-6.1-sol high | 90% (26/29) [79%, 97%] | 3.14 (91/29) [2.23, 4.07] | inverter 21, adrenaline 17, burner phone 13 |
| gpt-6.1-sol low | 95% (20/21) [83%, 100%] | 3.05 (64/21) [2.16, 3.95] | beer 20, inverter 17, magnifying glass 7 |
| gpt-6.1-sol max | 86% (48/56) [75%, 94%] | 2.70 (151/56) [2.27, 3.08] | burner phone 35, inverter 34, adrenaline 33 |
| gpt-6.1-sol medium | 95% (218/229) [92%, 98%] | 3.48 (798/229) [3.24, 3.74] | inverter 182, beer 155, burner phone 109 |
| gpt-6.1-sol xhigh | 92% (22/24) [81%, 100%] | 3.17 (76/24) [2.71, 3.65] | inverter 26, beer 15, handsaw 11 |
| gpt-6.1-terra high | 100% (18/18) [100%, 100%] | 4.06 (73/18) [3.44, 4.67] | beer 17, adrenaline 13, burner phone 10 |
| gpt-6.1-terra low | 96% (24/25) [87%, 100%] | 3.32 (83/25) [2.54, 4.07] | inverter 31, beer 16, handsaw 8 |
| gpt-6.1-terra max | 89% (16/18) [71%, 100%] | 3.22 (58/18) [2.00, 4.38] | inverter 13, beer 11, burner phone 8 |
| gpt-6.1-terra medium | 100% (23/23) [100%, 100%] | 3.43 (79/23) [3.04, 3.86] | inverter 23, beer 19, adrenaline 13 |
| gpt-6.1-terra off | 95% (18/19) [82%, 100%] | 3.58 (68/19) [3.12, 3.95] | beer 18, inverter 15, adrenaline 10 |
| gpt-6.1-terra xhigh | 95% (20/21) [86%, 100%] | 2.67 (56/21) [2.14, 3.23] | inverter 15, beer 11, adrenaline 8 |

### Astra efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| gpt-6-astra high | 60% (3/5) [0%, 75%] | 1.80 (9/5) [0.00, 2.25] | magnifying glass 2, burner phone 2, handsaw 1 |
| gpt-6-astra low | 100% (7/7) [100%, 100%] | 3.00 (21/7) [1.00, 5.00] | beer 8, burner phone 4, handsaw 3 |
| gpt-6-astra medium | 100% (4/4) [100%, 100%] | 3.50 (14/4) [3.00, 4.00] | beer 7, burner phone 3, handsaw 2 |
| gpt-6-astra off | 100% (2/2) [100%, 100%] | 1.50 (3/2) [1.50, 1.50] | beer 1, inverter 1, adrenaline 1 |

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
| claude-opus-5-5 high | 88% (64/73) [80%, 94%] | 2.96 (216/73) [2.42, 3.49] | beer 45, inverter 38, burner phone 32 |
| claude-opus-5-5 low | 82% (42/51) [70%, 94%] | 3.02 (154/51) [2.39, 3.58] | beer 36, inverter 28, burner phone 24 |
| claude-opus-5-5 max | 83% (34/41) [69%, 95%] | 2.63 (108/41) [2.00, 3.22] | magnifying glass 21, handsaw 19, beer 16 |
| claude-opus-5-5 medium | 89% (102/114) [84%, 95%] | 3.03 (345/114) [2.62, 3.42] | beer 74, inverter 66, burner phone 51 |
| claude-opus-5-5 off | 82% (9/11) [69%, 100%] | 3.36 (37/11) [2.21, 5.13] | beer 12, burner phone 6, jammer 4 |
| claude-opus-5-5 xhigh | 83% (53/64) [74%, 91%] | 2.59 (166/64) [2.09, 3.13] | inverter 34, beer 30, burner phone 21 |

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

### Terra efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| gpt-5.6-terra high | 94% (111/118) [90%, 98%] | 3.46 (408/118) [3.10, 3.85] | inverter 105, beer 71, burner phone 65 |
| gpt-5.6-terra low | 95% (127/134) [91%, 98%] | 3.81 (511/134) [3.53, 4.11] | inverter 107, beer 95, burner phone 90 |
| gpt-5.6-terra max | 88% (98/111) [82%, 94%] | 2.88 (320/111) [2.51, 3.27] | inverter 78, beer 61, burner phone 45 |
| gpt-5.6-terra medium | 97% (128/132) [93%, 100%] | 4.33 (571/132) [3.93, 4.73] | inverter 122, burner phone 116, beer 100 |
| gpt-5.6-terra xhigh | 91% (96/105) [86%, 96%] | 3.23 (339/105) [2.88, 3.61] | inverter 77, beer 63, burner phone 51 |

### gpt-6.1-terra efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| gpt-6.1-terra high | 100% (11/11) [100%, 100%] | 3.09 (34/11) [2.67, 3.67] | beer 10, burner phone 9, handsaw 4 |
| gpt-6.1-terra low | 100% (4/4) [100%, 100%] | 3.00 (12/4) [2.00, 3.33] | burner phone 6, inverter 2, adrenaline 2 |
| gpt-6.1-terra max | – | – | – |
| gpt-6.1-terra medium | 90% (9/10) [75%, 100%] | 3.50 (35/10) [2.75, 4.00] | beer 11, inverter 8, burner phone 7 |
| gpt-6.1-terra off | 100% (11/11) [100%, 100%] | 4.00 (44/11) [3.50, 4.71] | beer 16, inverter 10, burner phone 7 |
| gpt-6.1-terra xhigh | 100% (12/12) [100%, 100%] | 4.08 (49/12) [2.00, 4.67] | adrenaline 17, inverter 10, beer 9 |

## Same-position consistency

Agent decisions grouped by the deciding player's own position. Exact: the same board, cash and round, the same log since the load, the same legal moves, code and instructions. Belief: the same board, load shown, cash, round, legal moves and versions, the same public and private shell beliefs, and the same count of clue items each opponent used this load. Players are named relative to the decider. Coverage is the share of decisions in a position seen at least twice. Non-modal is the share of those decisions that differ from their position's most common choice; it has no interval, because resampling blocks duplicates decisions and a copy always matches the mode. Two differ is the chance two different decisions in a position differ, averaged over positions, with an interval over pairs of distinct decisions.

### Exact positions

| Cohort | Model | Positions seen twice or more | Coverage | Non-modal choices | Two differ |
|---|---|---|---|---|---|
| Cross-model | claude-haiku-4-5-20251001 high | 9 | 2.9% (18/626) | 5.6% (1/18) | 11% over 9 positions [0%, 50%] |
| Cross-model | claude-haiku-4-5-20251001 low | 5 | 1.1% (10/887) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-haiku-4-5-20251001 medium | 265 | 14% (723/5217) | 19% (138/723) | 36% over 265 positions [30%, 41%] |
| Cross-model | claude-haiku-4-5-20251001 minimal | 4 | 1.0% (8/815) | 13% (1/8) | 25% over 4 positions [0%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 off | 5 | 2.0% (10/495) | 20% (2/10) | 40% over 5 positions [33%, 50%] |
| Cross-model | claude-haiku-5-5 high | 3 | 0.8% (6/745) | 17% (1/6) | 33% over 3 positions [33%, 33%] |
| Cross-model | claude-haiku-5-5 low | 0 | 0% (0/1463) | – | – |
| Cross-model | claude-haiku-5-5 max | 0 | 0% (0/252) | – | – |
| Cross-model | claude-haiku-5-5 medium | 308 | 17% (862/5209) | 12% (102/862) | 21% over 308 positions [17%, 26%] |
| Cross-model | claude-haiku-5-5 off | 14 | 1.7% (28/1662) | 14% (4/28) | 29% over 14 positions [17%, 50%] |
| Cross-model | claude-haiku-5-5 xhigh | 0 | 0% (0/367) | – | – |
| Cross-model | claude-opus-5-5 high | 0 | 0% (0/352) | – | – |
| Cross-model | claude-opus-5-5 low | 0 | 0% (0/326) | – | – |
| Cross-model | claude-opus-5-5 max | 3 | 2.3% (6/264) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Cross-model | claude-opus-5-5 medium | 409 | 22% (1106/5108) | 6.1% (67/1106) | 11% over 409 positions [9.1%, 14%] |
| Cross-model | claude-opus-5-5 off | 0 | 0% (0/452) | – | – |
| Cross-model | claude-opus-5-5 xhigh | 61 | 7.8% (122/1562) | 7.4% (9/122) | 15% over 61 positions [4.2%, 100%] |
| Cross-model | claude-sonnet-5-5 high | 5 | 1.8% (10/542) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 low | 5 | 1.9% (10/532) | 10% (1/10) | 20% over 5 positions [0%, 50%] |
| Cross-model | claude-sonnet-5-5 max | 131 | 33% (331/1004) | 4.8% (16/331) | 9.7% over 131 positions [4.6%, 14%] |
| Cross-model | claude-sonnet-5-5 medium | 376 | 22% (1033/4710) | 5.8% (60/1033) | 12% over 376 positions [8.7%, 14%] |
| Cross-model | claude-sonnet-5-5 off | 13 | 4.7% (26/549) | 0% (0/26) | 0% over 13 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 xhigh | 0 | 0% (0/579) | – | – |
| Cross-model | gpt-5.6-terra high | 0 | 0% (0/280) | – | – |
| Cross-model | gpt-5.6-terra low | 0 | 0% (0/275) | – | – |
| Cross-model | gpt-5.6-terra max | 0 | 0% (0/319) | – | – |
| Cross-model | gpt-5.6-terra medium | 296 | 16% (690/4316) | 10% (72/690) | 20% over 296 positions [16%, 26%] |
| Cross-model | gpt-5.6-terra xhigh | 2 | 1.1% (4/379) | 0% (0/4) | 0% over 2 positions [0%, 0%] |
| Cross-model | gpt-6-astra high | 0 | 0% (0/449) | – | – |
| Cross-model | gpt-6-astra low | 19 | 12% (38/315) | 0% (0/38) | 0% over 19 positions [0%, 0%] |
| Cross-model | gpt-6-astra medium | 468 | 20% (1268/6219) | 2.9% (37/1268) | 6.0% over 468 positions [3.9%, 7.3%] |
| Cross-model | gpt-6-astra off | 0 | 0% (0/491) | – | – |
| Cross-model | gpt-6-luna high | 0 | 0% (0/300) | – | – |
| Cross-model | gpt-6-luna low | 12 | 9.1% (24/263) | 8.3% (2/24) | 17% over 12 positions [9.1%, 100%] |
| Cross-model | gpt-6-luna max | 7 | 4.5% (14/308) | 14% (2/14) | 29% over 7 positions [29%, 29%] |
| Cross-model | gpt-6-luna medium | 306 | 18% (853/4825) | 17% (148/853) | 32% over 306 positions [27%, 37%] |
| Cross-model | gpt-6-luna off | 0 | 0% (0/274) | – | – |
| Cross-model | gpt-6-luna xhigh | 0 | 0% (0/459) | – | – |
| Cross-model | gpt-6.1-sol high | 2 | 0.8% (4/507) | 0% (0/4) | 0% over 2 positions [0%, 0%] |
| Cross-model | gpt-6.1-sol low | 1 | 0.5% (2/433) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6.1-sol max | 130 | 28% (310/1097) | 2.6% (8/310) | 4.9% over 130 positions [0%, 10%] |
| Cross-model | gpt-6.1-sol medium | 395 | 22% (1076/4839) | 4.9% (53/1076) | 8.6% over 395 positions [7.1%, 13%] |
| Cross-model | gpt-6.1-sol xhigh | 1 | 0.4% (2/564) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6.1-terra high | 0 | 0% (0/346) | – | – |
| Cross-model | gpt-6.1-terra low | 0 | 0% (0/395) | – | – |
| Cross-model | gpt-6.1-terra max | 0 | 0% (0/539) | – | – |
| Cross-model | gpt-6.1-terra medium | 0 | 0% (0/340) | – | – |
| Cross-model | gpt-6.1-terra off | 0 | 0% (0/310) | – | – |
| Cross-model | gpt-6.1-terra xhigh | 0 | 0% (0/329) | – | – |
| Astra efforts | gpt-6-astra high | 0 | 0% (0/70) | – | – |
| Astra efforts | gpt-6-astra low | 0 | 0% (0/71) | – | – |
| Astra efforts | gpt-6-astra medium | 13 | 33% (26/79) | 0% (0/26) | 0% over 13 positions [0%, 0%] |
| Astra efforts | gpt-6-astra off | 0 | 0% (0/22) | – | – |
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
| Opus efforts | claude-opus-5-5 high | 149 | 29% (301/1045) | 5.0% (15/301) | 9.6% over 149 positions [2.2%, 27%] |
| Opus efforts | claude-opus-5-5 low | 3 | 0.7% (6/828) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Opus efforts | claude-opus-5-5 max | 106 | 31% (257/830) | 3.9% (10/257) | 8.5% over 106 positions [3.4%, 14%] |
| Opus efforts | claude-opus-5-5 medium | 207 | 29% (512/1774) | 4.9% (25/512) | 11% over 207 positions [6.6%, 13%] |
| Opus efforts | claude-opus-5-5 off | 0 | 0% (0/149) | – | – |
| Opus efforts | claude-opus-5-5 xhigh | 157 | 26% (319/1235) | 5.6% (18/319) | 11% over 157 positions [5.3%, 22%] |
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
| Terra efforts | gpt-5.6-terra high | 128 | 19% (351/1886) | 14% (49/351) | 27% over 128 positions [20%, 32%] |
| Terra efforts | gpt-5.6-terra low | 152 | 20% (374/1852) | 13% (50/374) | 24% over 152 positions [19%, 35%] |
| Terra efforts | gpt-5.6-terra max | 185 | 23% (503/2170) | 9.3% (47/503) | 20% over 185 positions [12%, 24%] |
| Terra efforts | gpt-5.6-terra medium | 160 | 22% (403/1792) | 13% (51/403) | 24% over 160 positions [18%, 32%] |
| Terra efforts | gpt-5.6-terra xhigh | 135 | 17% (355/2030) | 14% (48/355) | 29% over 135 positions [20%, 34%] |
| gpt-6.1-terra efforts | gpt-6.1-terra high | 0 | 0% (0/115) | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra low | 0 | 0% (0/113) | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra max | 0 | 0% (0/74) | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra medium | 0 | 0% (0/205) | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra off | 0 | 0% (0/135) | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra xhigh | 2 | 2.4% (4/166) | 25% (1/4) | 50% over 2 positions [50%, 50%] |

### Belief positions

| Cohort | Model | Positions seen twice or more | Coverage | Non-modal choices | Two differ |
|---|---|---|---|---|---|
| Cross-model | claude-haiku-4-5-20251001 high | 9 | 2.9% (18/626) | 5.6% (1/18) | 11% over 9 positions [0%, 50%] |
| Cross-model | claude-haiku-4-5-20251001 low | 5 | 1.1% (10/887) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-haiku-4-5-20251001 medium | 289 | 15% (787/5217) | 19% (149/787) | 36% over 289 positions [31%, 41%] |
| Cross-model | claude-haiku-4-5-20251001 minimal | 4 | 1.0% (8/815) | 13% (1/8) | 25% over 4 positions [0%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 off | 5 | 2.0% (10/495) | 20% (2/10) | 40% over 5 positions [33%, 50%] |
| Cross-model | claude-haiku-5-5 high | 3 | 0.8% (6/745) | 17% (1/6) | 33% over 3 positions [33%, 33%] |
| Cross-model | claude-haiku-5-5 low | 0 | 0% (0/1463) | – | – |
| Cross-model | claude-haiku-5-5 max | 0 | 0% (0/252) | – | – |
| Cross-model | claude-haiku-5-5 medium | 339 | 18% (955/5209) | 11% (107/955) | 19% over 339 positions [17%, 24%] |
| Cross-model | claude-haiku-5-5 off | 15 | 1.8% (30/1662) | 17% (5/30) | 33% over 15 positions [17%, 50%] |
| Cross-model | claude-haiku-5-5 xhigh | 0 | 0% (0/367) | – | – |
| Cross-model | claude-opus-5-5 high | 0 | 0% (0/352) | – | – |
| Cross-model | claude-opus-5-5 low | 0 | 0% (0/326) | – | – |
| Cross-model | claude-opus-5-5 max | 3 | 2.3% (6/264) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Cross-model | claude-opus-5-5 medium | 443 | 24% (1215/5108) | 5.8% (71/1215) | 10% over 443 positions [8.7%, 13%] |
| Cross-model | claude-opus-5-5 off | 0 | 0% (0/452) | – | – |
| Cross-model | claude-opus-5-5 xhigh | 67 | 8.6% (134/1562) | 6.7% (9/134) | 13% over 67 positions [4.2%, 100%] |
| Cross-model | claude-sonnet-5-5 high | 5 | 1.8% (10/542) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 low | 5 | 1.9% (10/532) | 10% (1/10) | 20% over 5 positions [0%, 50%] |
| Cross-model | claude-sonnet-5-5 max | 144 | 36% (362/1004) | 4.7% (17/362) | 9.5% over 144 positions [4.4%, 14%] |
| Cross-model | claude-sonnet-5-5 medium | 411 | 24% (1123/4710) | 6.0% (67/1123) | 12% over 411 positions [9.0%, 15%] |
| Cross-model | claude-sonnet-5-5 off | 13 | 4.7% (26/549) | 0% (0/26) | 0% over 13 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 xhigh | 0 | 0% (0/579) | – | – |
| Cross-model | gpt-5.6-terra high | 0 | 0% (0/280) | – | – |
| Cross-model | gpt-5.6-terra low | 0 | 0% (0/275) | – | – |
| Cross-model | gpt-5.6-terra max | 0 | 0% (0/319) | – | – |
| Cross-model | gpt-5.6-terra medium | 315 | 17% (739/4316) | 10% (77/739) | 20% over 315 positions [16%, 26%] |
| Cross-model | gpt-5.6-terra xhigh | 2 | 1.1% (4/379) | 0% (0/4) | 0% over 2 positions [0%, 0%] |
| Cross-model | gpt-6-astra high | 0 | 0% (0/449) | – | – |
| Cross-model | gpt-6-astra low | 19 | 12% (38/315) | 0% (0/38) | 0% over 19 positions [0%, 0%] |
| Cross-model | gpt-6-astra medium | 499 | 22% (1338/6219) | 3.0% (40/1338) | 6.2% over 499 positions [4.0%, 7.6%] |
| Cross-model | gpt-6-astra off | 0 | 0% (0/491) | – | – |
| Cross-model | gpt-6-luna high | 0 | 0% (0/300) | – | – |
| Cross-model | gpt-6-luna low | 15 | 11% (30/263) | 6.7% (2/30) | 13% over 15 positions [7.1%, 100%] |
| Cross-model | gpt-6-luna max | 7 | 4.5% (14/308) | 14% (2/14) | 29% over 7 positions [29%, 29%] |
| Cross-model | gpt-6-luna medium | 330 | 19% (911/4825) | 17% (156/911) | 31% over 330 positions [26%, 37%] |
| Cross-model | gpt-6-luna off | 0 | 0% (0/274) | – | – |
| Cross-model | gpt-6-luna xhigh | 0 | 0% (0/459) | – | – |
| Cross-model | gpt-6.1-sol high | 2 | 0.8% (4/507) | 0% (0/4) | 0% over 2 positions [0%, 0%] |
| Cross-model | gpt-6.1-sol low | 1 | 0.5% (2/433) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6.1-sol max | 137 | 30% (331/1097) | 2.4% (8/331) | 4.6% over 137 positions [0%, 10%] |
| Cross-model | gpt-6.1-sol medium | 426 | 24% (1165/4839) | 4.7% (55/1165) | 8.4% over 426 positions [6.7%, 12%] |
| Cross-model | gpt-6.1-sol xhigh | 1 | 0.4% (2/564) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6.1-terra high | 0 | 0% (0/346) | – | – |
| Cross-model | gpt-6.1-terra low | 0 | 0% (0/395) | – | – |
| Cross-model | gpt-6.1-terra max | 0 | 0% (0/539) | – | – |
| Cross-model | gpt-6.1-terra medium | 0 | 0% (0/340) | – | – |
| Cross-model | gpt-6.1-terra off | 0 | 0% (0/310) | – | – |
| Cross-model | gpt-6.1-terra xhigh | 0 | 0% (0/329) | – | – |
| Astra efforts | gpt-6-astra high | 0 | 0% (0/70) | – | – |
| Astra efforts | gpt-6-astra low | 0 | 0% (0/71) | – | – |
| Astra efforts | gpt-6-astra medium | 13 | 33% (26/79) | 0% (0/26) | 0% over 13 positions [0%, 0%] |
| Astra efforts | gpt-6-astra off | 0 | 0% (0/22) | – | – |
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
| Opus efforts | claude-opus-5-5 high | 158 | 31% (319/1045) | 5.3% (17/319) | 10% over 158 positions [4.0%, 26%] |
| Opus efforts | claude-opus-5-5 low | 3 | 0.7% (6/828) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Opus efforts | claude-opus-5-5 max | 114 | 33% (277/830) | 4.7% (13/277) | 9.9% over 114 positions [4.7%, 16%] |
| Opus efforts | claude-opus-5-5 medium | 226 | 31% (555/1774) | 5.0% (28/555) | 11% over 226 positions [6.5%, 14%] |
| Opus efforts | claude-opus-5-5 off | 0 | 0% (0/149) | – | – |
| Opus efforts | claude-opus-5-5 xhigh | 168 | 28% (343/1235) | 5.8% (20/343) | 12% over 168 positions [5.3%, 21%] |
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
| Terra efforts | gpt-5.6-terra high | 140 | 21% (388/1886) | 13% (52/388) | 27% over 140 positions [19%, 31%] |
| Terra efforts | gpt-5.6-terra low | 173 | 23% (422/1852) | 14% (58/422) | 26% over 173 positions [20%, 34%] |
| Terra efforts | gpt-5.6-terra max | 208 | 26% (558/2170) | 9.0% (50/558) | 19% over 208 positions [12%, 23%] |
| Terra efforts | gpt-5.6-terra medium | 176 | 25% (453/1792) | 13% (57/453) | 23% over 176 positions [19%, 31%] |
| Terra efforts | gpt-5.6-terra xhigh | 156 | 20% (405/2030) | 12% (50/405) | 26% over 156 positions [19%, 31%] |
| gpt-6.1-terra efforts | gpt-6.1-terra high | 0 | 0% (0/115) | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra low | 0 | 0% (0/113) | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra max | 0 | 0% (0/74) | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra medium | 0 | 0% (0/205) | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra off | 0 | 0% (0/135) | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra xhigh | 2 | 2.4% (4/166) | 25% (1/4) | 50% over 2 positions [50%, 50%] |

## Agreement between effort variants

For each pair of one model's effort levels in the same cohort, exact positions both met. Across: the chance a random decision of each variant agrees, averaged over shared positions. Within: for comparison, the chance two decisions of the same variant agree, over shared positions that variant met at least twice.

| Cohort | Variants | Shared positions | Across | Within, first | Within, second |
|---|---|---|---|---|---|
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 low | 4 | 75% over 4 positions [75%, 75%] | – | – |
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 medium | 34 | 69% over 34 positions [61%, 100%] | – | 77% over 13 positions [50%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 minimal | 9 | 89% over 9 positions [89%, 89%] | – | – |
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 off | 17 | 71% over 17 positions [33%, 100%] | – | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 medium | 31 | 58% over 31 positions [20%, 79%] | – | 67% over 12 positions [50%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 minimal | 31 | 74% over 31 positions [0%, 92%] | 100% over 5 positions [100%, 100%] | – |
| Cross-model | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 off | 0 | – | – | – |
| Cross-model | claude-haiku-4-5-20251001 medium vs claude-haiku-4-5-20251001 minimal | 44 | 65% over 44 positions [53%, 75%] | 53% over 19 positions [40%, 67%] | – |
| Cross-model | claude-haiku-4-5-20251001 medium vs claude-haiku-4-5-20251001 off | 20 | 55% over 20 positions [20%, 83%] | 75% over 8 positions [0%, 100%] | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 minimal vs claude-haiku-4-5-20251001 off | 6 | 67% over 6 positions [67%, 67%] | – | – |
| Cross-model | claude-haiku-5-5 high vs claude-haiku-5-5 low | 26 | 83% over 26 positions [50%, 100%] | 67% over 3 positions [67%, 67%] | – |
| Cross-model | claude-haiku-5-5 high vs claude-haiku-5-5 max | 3 | 67% over 3 positions [67%, 67%] | – | – |
| Cross-model | claude-haiku-5-5 high vs claude-haiku-5-5 medium | 54 | 81% over 54 positions [67%, 91%] | 67% over 3 positions [67%, 67%] | 94% over 18 positions [89%, 100%] |
| Cross-model | claude-haiku-5-5 high vs claude-haiku-5-5 off | 3 | 33% over 3 positions [33%, 33%] | – | – |
| Cross-model | claude-haiku-5-5 high vs claude-haiku-5-5 xhigh | 4 | 100% over 4 positions [100%, 100%] | – | – |
| Cross-model | claude-haiku-5-5 low vs claude-haiku-5-5 max | 3 | 67% over 3 positions [67%, 67%] | – | – |
| Cross-model | claude-haiku-5-5 low vs claude-haiku-5-5 medium | 52 | 78% over 52 positions [67%, 86%] | – | 94% over 17 positions [80%, 100%] |
| Cross-model | claude-haiku-5-5 low vs claude-haiku-5-5 off | 0 | – | – | – |
| Cross-model | claude-haiku-5-5 low vs claude-haiku-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-haiku-5-5 max vs claude-haiku-5-5 medium | 35 | 77% over 35 positions [0%, 93%] | – | 62% over 13 positions [0%, 100%] |
| Cross-model | claude-haiku-5-5 max vs claude-haiku-5-5 off | 12 | 58% over 12 positions [0%, 100%] | – | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-haiku-5-5 max vs claude-haiku-5-5 xhigh | 46 | 87% over 46 positions [50%, 100%] | – | – |
| Cross-model | claude-haiku-5-5 medium vs claude-haiku-5-5 off | 32 | 72% over 32 positions [50%, 85%] | 78% over 18 positions [50%, 100%] | 80% over 5 positions [67%, 100%] |
| Cross-model | claude-haiku-5-5 medium vs claude-haiku-5-5 xhigh | 41 | 76% over 41 positions [50%, 100%] | 69% over 16 positions [50%, 100%] | – |
| Cross-model | claude-haiku-5-5 off vs claude-haiku-5-5 xhigh | 16 | 56% over 16 positions [0%, 75%] | 100% over 1 positions [100%, 100%] | – |
| Cross-model | claude-opus-5-5 high vs claude-opus-5-5 low | 21 | 90% over 21 positions [75%, 100%] | – | – |
| Cross-model | claude-opus-5-5 high vs claude-opus-5-5 max | 0 | – | – | – |
| Cross-model | claude-opus-5-5 high vs claude-opus-5-5 medium | 43 | 90% over 43 positions [60%, 100%] | – | 96% over 23 positions [86%, 100%] |
| Cross-model | claude-opus-5-5 high vs claude-opus-5-5 off | 0 | – | – | – |
| Cross-model | claude-opus-5-5 high vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-opus-5-5 low vs claude-opus-5-5 max | 0 | – | – | – |
| Cross-model | claude-opus-5-5 low vs claude-opus-5-5 medium | 63 | 91% over 63 positions [80%, 100%] | – | 98% over 40 positions [92%, 100%] |
| Cross-model | claude-opus-5-5 low vs claude-opus-5-5 off | 0 | – | – | – |
| Cross-model | claude-opus-5-5 low vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-opus-5-5 max vs claude-opus-5-5 medium | 0 | – | – | – |
| Cross-model | claude-opus-5-5 max vs claude-opus-5-5 off | 0 | – | – | – |
| Cross-model | claude-opus-5-5 max vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-opus-5-5 medium vs claude-opus-5-5 off | 0 | – | – | – |
| Cross-model | claude-opus-5-5 medium vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-opus-5-5 off vs claude-opus-5-5 xhigh | 0 | – | – | – |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 low | 25 | 90% over 25 positions [86%, 100%] | – | 50% over 2 positions [50%, 50%] |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 max | 7 | 57% over 7 positions [0%, 75%] | – | – |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 medium | 40 | 89% over 40 positions [80%, 100%] | 100% over 5 positions [100%, 100%] | 93% over 14 positions [88%, 100%] |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 off | 6 | 83% over 6 positions [50%, 100%] | – | – |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 xhigh | 4 | 75% over 4 positions [75%, 75%] | – | – |
| Cross-model | claude-sonnet-5-5 low vs claude-sonnet-5-5 max | 20 | 70% over 20 positions [50%, 100%] | 50% over 2 positions [50%, 50%] | – |
| Cross-model | claude-sonnet-5-5 low vs claude-sonnet-5-5 medium | 28 | 84% over 28 positions [67%, 97%] | 50% over 2 positions [50%, 50%] | 85% over 13 positions [0%, 100%] |
| Cross-model | claude-sonnet-5-5 low vs claude-sonnet-5-5 off | 19 | 79% over 19 positions [0%, 100%] | 100% over 1 positions [100%, 100%] | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-sonnet-5-5 low vs claude-sonnet-5-5 xhigh | 6 | 67% over 6 positions [50%, 100%] | – | – |
| Cross-model | claude-sonnet-5-5 max vs claude-sonnet-5-5 medium | 16 | 53% over 16 positions [0%, 70%] | – | 91% over 11 positions [0%, 100%] |
| Cross-model | claude-sonnet-5-5 max vs claude-sonnet-5-5 off | 7 | 71% over 7 positions [0%, 100%] | – | – |
| Cross-model | claude-sonnet-5-5 max vs claude-sonnet-5-5 xhigh | 2 | 50% over 2 positions [50%, 50%] | – | – |
| Cross-model | claude-sonnet-5-5 medium vs claude-sonnet-5-5 off | 29 | 79% over 29 positions [50%, 100%] | 89% over 19 positions [75%, 100%] | – |
| Cross-model | claude-sonnet-5-5 medium vs claude-sonnet-5-5 xhigh | 40 | 76% over 40 positions [50%, 88%] | 81% over 16 positions [50%, 100%] | – |
| Cross-model | claude-sonnet-5-5 off vs claude-sonnet-5-5 xhigh | 34 | 79% over 34 positions [50%, 89%] | – | – |
| Cross-model | gpt-5.6-terra high vs gpt-5.6-terra low | 4 | 100% over 4 positions [100%, 100%] | – | – |
| Cross-model | gpt-5.6-terra high vs gpt-5.6-terra max | 20 | 80% over 20 positions [75%, 83%] | – | – |
| Cross-model | gpt-5.6-terra high vs gpt-5.6-terra medium | 45 | 87% over 45 positions [50%, 96%] | – | 88% over 17 positions [0%, 100%] |
| Cross-model | gpt-5.6-terra high vs gpt-5.6-terra xhigh | 17 | 82% over 17 positions [80%, 86%] | – | – |
| Cross-model | gpt-5.6-terra low vs gpt-5.6-terra max | 2 | 0% over 2 positions [0%, 0%] | – | – |
| Cross-model | gpt-5.6-terra low vs gpt-5.6-terra medium | 35 | 79% over 35 positions [33%, 92%] | – | 63% over 8 positions [0%, 100%] |
| Cross-model | gpt-5.6-terra low vs gpt-5.6-terra xhigh | 20 | 90% over 20 positions [67%, 100%] | – | – |
| Cross-model | gpt-5.6-terra max vs gpt-5.6-terra medium | 26 | 63% over 26 positions [33%, 75%] | – | 70% over 10 positions [0%, 100%] |
| Cross-model | gpt-5.6-terra max vs gpt-5.6-terra xhigh | 0 | – | – | – |
| Cross-model | gpt-5.6-terra medium vs gpt-5.6-terra xhigh | 52 | 83% over 52 positions [58%, 93%] | 89% over 19 positions [50%, 100%] | 100% over 2 positions [100%, 100%] |
| Cross-model | gpt-6-astra high vs gpt-6-astra low | 0 | – | – | – |
| Cross-model | gpt-6-astra high vs gpt-6-astra medium | 0 | – | – | – |
| Cross-model | gpt-6-astra high vs gpt-6-astra off | 0 | – | – | – |
| Cross-model | gpt-6-astra low vs gpt-6-astra medium | 0 | – | – | – |
| Cross-model | gpt-6-astra low vs gpt-6-astra off | 0 | – | – | – |
| Cross-model | gpt-6-astra medium vs gpt-6-astra off | 0 | – | – | – |
| Cross-model | gpt-6-luna high vs gpt-6-luna low | 7 | 57% over 7 positions [0%, 80%] | – | – |
| Cross-model | gpt-6-luna high vs gpt-6-luna max | 15 | 80% over 15 positions [75%, 83%] | – | – |
| Cross-model | gpt-6-luna high vs gpt-6-luna medium | 31 | 53% over 31 positions [11%, 80%] | – | 54% over 15 positions [0%, 100%] |
| Cross-model | gpt-6-luna high vs gpt-6-luna off | 5 | 60% over 5 positions [0%, 75%] | – | – |
| Cross-model | gpt-6-luna high vs gpt-6-luna xhigh | 3 | 67% over 3 positions [67%, 67%] | – | – |
| Cross-model | gpt-6-luna low vs gpt-6-luna max | 15 | 40% over 15 positions [0%, 75%] | – | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6-luna low vs gpt-6-luna medium | 24 | 58% over 24 positions [25%, 78%] | 0% over 1 positions [0%, 0%] | 78% over 12 positions [0%, 100%] |
| Cross-model | gpt-6-luna low vs gpt-6-luna off | 9 | 56% over 9 positions [56%, 56%] | – | – |
| Cross-model | gpt-6-luna low vs gpt-6-luna xhigh | 8 | 50% over 8 positions [40%, 67%] | – | – |
| Cross-model | gpt-6-luna max vs gpt-6-luna medium | 27 | 56% over 27 positions [33%, 75%] | 100% over 4 positions [100%, 100%] | 76% over 15 positions [0%, 100%] |
| Cross-model | gpt-6-luna max vs gpt-6-luna off | 9 | 56% over 9 positions [50%, 60%] | – | – |
| Cross-model | gpt-6-luna max vs gpt-6-luna xhigh | 17 | 88% over 17 positions [88%, 88%] | – | – |
| Cross-model | gpt-6-luna medium vs gpt-6-luna off | 24 | 67% over 24 positions [0%, 83%] | 71% over 7 positions [0%, 100%] | – |
| Cross-model | gpt-6-luna medium vs gpt-6-luna xhigh | 22 | 68% over 22 positions [25%, 100%] | 0% over 2 positions [0%, 0%] | – |
| Cross-model | gpt-6-luna off vs gpt-6-luna xhigh | 8 | 63% over 8 positions [50%, 75%] | – | – |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol low | 0 | – | – | – |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol max | 0 | – | – | – |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol medium | 51 | 90% over 51 positions [71%, 100%] | – | 89% over 19 positions [0%, 100%] |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol xhigh | 36 | 83% over 36 positions [43%, 100%] | – | – |
| Cross-model | gpt-6.1-sol low vs gpt-6.1-sol max | 33 | 82% over 33 positions [67%, 100%] | – | – |
| Cross-model | gpt-6.1-sol low vs gpt-6.1-sol medium | 62 | 90% over 62 positions [75%, 100%] | – | 86% over 14 positions [50%, 100%] |
| Cross-model | gpt-6.1-sol low vs gpt-6.1-sol xhigh | 0 | – | – | – |
| Cross-model | gpt-6.1-sol max vs gpt-6.1-sol medium | 47 | 84% over 47 positions [62%, 100%] | – | 79% over 14 positions [50%, 100%] |
| Cross-model | gpt-6.1-sol max vs gpt-6.1-sol xhigh | 7 | 86% over 7 positions [86%, 86%] | – | – |
| Cross-model | gpt-6.1-sol medium vs gpt-6.1-sol xhigh | 51 | 76% over 51 positions [57%, 86%] | 88% over 16 positions [0%, 100%] | – |
| Cross-model | gpt-6.1-terra high vs gpt-6.1-terra low | 7 | 86% over 7 positions [75%, 100%] | – | – |
| Cross-model | gpt-6.1-terra high vs gpt-6.1-terra max | 6 | 83% over 6 positions [83%, 83%] | – | – |
| Cross-model | gpt-6.1-terra high vs gpt-6.1-terra medium | 0 | – | – | – |
| Cross-model | gpt-6.1-terra high vs gpt-6.1-terra off | 0 | – | – | – |
| Cross-model | gpt-6.1-terra high vs gpt-6.1-terra xhigh | 0 | – | – | – |
| Cross-model | gpt-6.1-terra low vs gpt-6.1-terra max | 8 | 100% over 8 positions [100%, 100%] | – | – |
| Cross-model | gpt-6.1-terra low vs gpt-6.1-terra medium | 0 | – | – | – |
| Cross-model | gpt-6.1-terra low vs gpt-6.1-terra off | 0 | – | – | – |
| Cross-model | gpt-6.1-terra low vs gpt-6.1-terra xhigh | 0 | – | – | – |
| Cross-model | gpt-6.1-terra max vs gpt-6.1-terra medium | 0 | – | – | – |
| Cross-model | gpt-6.1-terra max vs gpt-6.1-terra off | 0 | – | – | – |
| Cross-model | gpt-6.1-terra max vs gpt-6.1-terra xhigh | 0 | – | – | – |
| Cross-model | gpt-6.1-terra medium vs gpt-6.1-terra off | 0 | – | – | – |
| Cross-model | gpt-6.1-terra medium vs gpt-6.1-terra xhigh | 20 | 90% over 20 positions [90%, 90%] | – | – |
| Cross-model | gpt-6.1-terra off vs gpt-6.1-terra xhigh | 0 | – | – | – |
| Astra efforts | gpt-6-astra high vs gpt-6-astra low | 16 | 81% over 16 positions [81%, 81%] | – | – |
| Astra efforts | gpt-6-astra high vs gpt-6-astra medium | 14 | 79% over 14 positions [79%, 85%] | – | 100% over 10 positions [100%, 100%] |
| Astra efforts | gpt-6-astra high vs gpt-6-astra off | 0 | – | – | – |
| Astra efforts | gpt-6-astra low vs gpt-6-astra medium | 9 | 89% over 9 positions [83%, 89%] | – | 100% over 5 positions [100%, 100%] |
| Astra efforts | gpt-6-astra low vs gpt-6-astra off | 0 | – | – | – |
| Astra efforts | gpt-6-astra medium vs gpt-6-astra off | 0 | – | – | – |
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
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 low | 150 | 86% over 150 positions [77%, 91%] | 93% over 99 positions [75%, 100%] | 100% over 2 positions [100%, 100%] |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 max | 0 | – | – | – |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 medium | 353 | 90% over 353 positions [88%, 93%] | 91% over 146 positions [75%, 98%] | 91% over 170 positions [88%, 96%] |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 off | 6 | 83% over 6 positions [83%, 83%] | – | – |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 xhigh | 203 | 86% over 203 positions [83%, 90%] | 94% over 108 positions [78%, 100%] | 87% over 116 positions [75%, 93%] |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 max | 23 | 67% over 23 positions [33%, 82%] | – | 94% over 21 positions [75%, 100%] |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 medium | 249 | 86% over 249 positions [82%, 89%] | 100% over 1 positions [100%, 100%] | 96% over 106 positions [92%, 99%] |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 off | 5 | 80% over 5 positions [80%, 80%] | – | – |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 xhigh | 197 | 82% over 197 positions [75%, 87%] | – | 91% over 88 positions [78%, 100%] |
| Opus efforts | claude-opus-5-5 max vs claude-opus-5-5 medium | 20 | 55% over 20 positions [33%, 69%] | 92% over 16 positions [72%, 100%] | 100% over 1 positions [100%, 100%] |
| Opus efforts | claude-opus-5-5 max vs claude-opus-5-5 off | 0 | – | – | – |
| Opus efforts | claude-opus-5-5 max vs claude-opus-5-5 xhigh | 44 | 84% over 44 positions [42%, 94%] | 94% over 24 positions [75%, 100%] | – |
| Opus efforts | claude-opus-5-5 medium vs claude-opus-5-5 off | 2 | 0% over 2 positions [0%, 0%] | – | – |
| Opus efforts | claude-opus-5-5 medium vs claude-opus-5-5 xhigh | 365 | 88% over 365 positions [86%, 91%] | 92% over 160 positions [90%, 97%] | 89% over 119 positions [78%, 98%] |
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
| gpt-6.1-terra efforts | gpt-6.1-terra high vs gpt-6.1-terra low | 0 | – | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra high vs gpt-6.1-terra max | 0 | – | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra high vs gpt-6.1-terra medium | 26 | 92% over 26 positions [92%, 92%] | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra high vs gpt-6.1-terra off | 0 | – | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra high vs gpt-6.1-terra xhigh | 3 | 33% over 3 positions [33%, 33%] | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra low vs gpt-6.1-terra max | 0 | – | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra low vs gpt-6.1-terra medium | 9 | 89% over 9 positions [89%, 89%] | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra low vs gpt-6.1-terra off | 1 | 0% over 1 positions [0%, 0%] | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra low vs gpt-6.1-terra xhigh | 0 | – | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra max vs gpt-6.1-terra medium | 0 | – | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra max vs gpt-6.1-terra off | 0 | – | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra max vs gpt-6.1-terra xhigh | 3 | 67% over 3 positions [67%, 67%] | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra medium vs gpt-6.1-terra off | 1 | 0% over 1 positions [0%, 0%] | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra medium vs gpt-6.1-terra xhigh | 12 | 83% over 12 positions [83%, 83%] | – | – |
| gpt-6.1-terra efforts | gpt-6.1-terra off vs gpt-6.1-terra xhigh | 0 | – | – | – |

## Code versions

The main rates within each cohort by code version, pooled over models.

| Cohort | Code | Against a known shell | Shots known from a clue | Matches |
|---|---|---|---|---|
| Cross-model | 12e2e3295899 | 5.8% (373/6466) [4.8%, 6.8%] | 26% (2782/10702) [25%, 27%] | 450 |
| Cross-model | 29f99c6dce47 | 20% (291/1445) [18%, 23%] | 24% (594/2504) [22%, 26%] | 100 |
| Cross-model | 2a5f469d8793 | 3.5% (36/1023) [2.0%, 5.1%] | 28% (467/1659) [26%, 30%] | 70 |
| Cross-model | 3c9b98f8b3f4 | 4.4% (39/888) [2.5%, 6.8%] | 26% (383/1491) [23%, 29%] | 63 |
| Cross-model | 51b8366684f0 | 7.3% (439/6022) [6.3%, 8.4%] | 25% (2539/10172) [24%, 26%] | 420 |
| Cross-model | 9e7d7ff22891 | 4.0% (68/1685) [2.7%, 5.6%] | 26% (744/2818) [24%, 29%] | 118 |
| Cross-model | b72cdce126f2 | 6.9% (35/510) [3.5%, 11%] | 30% (242/817) [26%, 33%] | 34 |
| Astra efforts | 12e2e3295899 | 0% (0/52) [0%, 0%] | 41% (32/79) [38%, 43%] | 4 |
| Astra efforts | 2a5f469d8793 | 0% (0/9) [0%, 0%] | 22% (4/18) [22%, 22%] | 1 |
| Astra efforts | b72cdce126f2 | 0% (0/11) [0%, 0%] | 25% (5/20) [25%, 25%] | 1 |
| Haiku 4.5 efforts | 51b8366684f0 | 17% (19/114) [9.2%, 24%] | 15% (37/251) [13%, 17%] | 12 |
| Haiku 4.5 efforts | 9e7d7ff22891 | 25% (675/2740) [23%, 27%] | 21% (1047/5107) [19%, 22%] | 188 |
| Haiku 5.5 efforts | 51b8366684f0 | 12% (22/188) [7.6%, 16%] | 16% (57/354) [11%, 22%] | 20 |
| Haiku 5.5 efforts | 9e7d7ff22891 | 14% (571/4041) [13%, 16%] | 27% (1812/6646) [26%, 29%] | 280 |
| Luna efforts | 9e7d7ff22891 | 20% (886/4441) [18%, 22%] | 24% (1803/7600) [22%, 25%] | 300 |
| Opus efforts | 12e2e3295899 | 0.3% (2/590) [0%, 0.8%] | 31% (274/888) [27%, 36%] | 36 |
| Opus efforts | 9e7d7ff22891 | 0.1% (1/1134) [0%, 0.3%] | 30% (545/1838) [26%, 33%] | 80 |
| Opus efforts | b72cdce126f2 | 0% (0/23) [0%, 0%] | 30% (11/37) [29%, 30%] | 2 |
| Sol efforts | 9e7d7ff22891 | 0.7% (20/2830) [0.4%, 1.0%] | 29% (1337/4690) [27%, 30%] | 200 |
| Sonnet efforts | 51b8366684f0 | 0% (0/55) [0%, 0%] | 24% (22/91) [20%, 26%] | 5 |
| Sonnet efforts | 9e7d7ff22891 | 0.9% (40/4328) [0.6%, 1.3%] | 29% (2020/6969) [28%, 30%] | 295 |
| Terra efforts | 9e7d7ff22891 | 4.0% (114/2886) [3.1%, 4.8%] | 25% (1209/4858) [23%, 27%] | 200 |
| gpt-6.1-terra efforts | 12e2e3295899 | 0% (0/227) [0%, 0%] | 30% (107/359) [22%, 37%] | 14 |
| gpt-6.1-terra efforts | 2a5f469d8793 | 0% (0/34) [0%, 0%] | 38% (20/53) [26%, 55%] | 2 |
<!-- beliefs:end -->
