# Beliefs and items

What each model knew about the shotgun when it chose a move, whether it acted on that knowledge, what happened to its items, and whether it chose the same way in the same position. Every judgement uses only the deciding player's own information: the public log and its own clues. Another player's clues and the hidden shell order never enter. The tables call these choice patterns. A move is called dominated only where the player's own information shows it.

DeepSeek (`deepseek-v4.1-flash`) is left out entirely. Every match with a DeepSeek seat is dropped from every table below, including its opponents' moves in those matches.

## Summary

Scope: the 3,537 scored matches of the ten cohorts in the Coverage table, with no DeepSeek seat, from the knowledge database rebuilt on 2026-11-04 from the analysis database (3,557 completed matches, now including tournament 8). The cohorts are Cross-model (every match between different models, 1,860 matches) and one effort cohort per model (every match of that model against itself, 1,677 matches in all).

The prose summary written for an earlier 2,471-match scope is removed. Its figures were typed by hand, were not regenerated and cannot be reproduced from the tables below, so they would describe a scope this page no longer has. The tables are the findings: each rate is numerator/denominator with a 95% interval over seed blocks. Small cohorts (Astra efforts has 9 matches, Terra 6.1 efforts 31) and Cross-model pairings with few seed blocks have wide rows that say little on their own.

## How it was measured

**Own information.** `web/scripts/arena-knowledge.ts` replays every replay-validated match in the analysis database through `replayOf`, the viewer's replay over the generated Bend rules. Before each accepted move it takes the deciding player's log since the latest load: the public events, plus the secrets that player heard, in the order it heard them. That log goes to the shell belief of the Bend minimax player (`belief.orders.log` in `sim/bend-mp/player/belief.bend`). It enumerates every shell order the log allows, with multiplicity, once with the public log alone and once with the player's own clues as well. Everything else is read off those orders: the live/blank composition left, the chance each position is live, and which positions are certain. TypeScript only marshals the log and counts orders. It never applies a shot, beer or inverter itself. The output is a separate SQLite database, `derived/knowledge.sqlite` beside the analysis database, with one row per non-forced decision, per clue, per placed item and per death. `web/scripts/arena-knowledge-report.ts` turns it into the tables below.

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
| Cross-model | 3310 | 2010 | 131456 | 61887 | 37149 | 12e2e3295899, 18b65a259496, 1af2b6e43774, 29f99c6dce47, 2a5f469d8793, 3c9b98f8b3f4, 452a3a2e13a5d1252875796eac0ee0fac2f43d55, 51408f692c1c67edd7db0425dbbb37fac8ab4db8, 51b8366684f0, 9e7d7ff22891, b72cdce126f2 |
| Astra efforts | 9 | 7 | 400 | 189 | 116 | 12e2e3295899, 2a5f469d8793, b72cdce126f2 |
| Haiku 4.5 efforts | 200 | 100 | 10636 | 5358 | 2854 | 51b8366684f0, 9e7d7ff22891 |
| Haiku 5.5 efforts | 300 | 150 | 15078 | 7000 | 4229 | 51b8366684f0, 9e7d7ff22891 |
| Luna efforts | 300 | 150 | 17231 | 7600 | 4441 | 9e7d7ff22891 |
| Opus efforts | 137 | 79 | 6754 | 3194 | 2009 | 12e2e3295899, 2a5f469d8793, 9e7d7ff22891, b72cdce126f2 |
| Sol efforts | 200 | 100 | 9726 | 4690 | 2830 | 9e7d7ff22891 |
| Sonnet efforts | 300 | 150 | 14710 | 7060 | 4383 | 51b8366684f0, 9e7d7ff22891 |
| Terra 6.1 efforts | 31 | 24 | 1574 | 786 | 499 | 12e2e3295899, 2a5f469d8793 |
| Terra efforts | 200 | 100 | 9730 | 4858 | 2886 | 9e7d7ff22891 |

## Shots with a certain chamber

Shooting the opponent on a known blank and yourself on a known live. Certainty is the player's own: the public log, its own clues, or both. In the replays a blank shot at yourself always kept the move, also across a reload, and a blank shot at the opponent always passed it, so the blank columns split the gun's last shell from the rest.

### Cross-model

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| claude-haiku-4-5-20251001 high | 27% (30/111) [16%, 39%] | 56% (34/61) [42%, 68%] | 4.1% (8/194) [1.6%, 6.7%] |
| claude-haiku-4-5-20251001 low | 17% (25/143) [11%, 25%] | 56% (36/64) [41%, 70%] | 3.8% (10/260) [1.5%, 6.8%] |
| claude-haiku-4-5-20251001 medium | 31% (150/486) [26%, 36%] | 63% (142/227) [56%, 69%] | 4.2% (39/933) [2.8%, 5.8%] |
| claude-haiku-4-5-20251001 minimal | 25% (31/122) [16%, 35%] | 64% (51/80) [50%, 76%] | 5.8% (14/243) [2.9%, 8.7%] |
| claude-haiku-4-5-20251001 off | 39% (40/102) [28%, 52%] | 75% (30/40) [60%, 88%] | 6.7% (9/134) [2.6%, 11%] |
| claude-haiku-5-5 high | 11% (22/196) [7.2%, 16%] | 81% (70/86) [70%, 91%] | 0.5% (3/629) [0%, 1.1%] |
| claude-haiku-5-5 low | 23% (66/293) [18%, 28%] | 72% (105/145) [64%, 81%] | 0.7% (6/903) [0.2%, 1.2%] |
| claude-haiku-5-5 max | 5.0% (1/20) [0%, 13%] | 50% (3/6) [17%, 83%] | 0% (0/47) [0%, 0%] |
| claude-haiku-5-5 medium | 18% (93/514) [15%, 22%] | 73% (187/256) [66%, 80%] | 0.4% (7/1659) [0.1%, 0.8%] |
| claude-haiku-5-5 off | 43% (353/816) [39%, 47%] | 79% (335/424) [75%, 83%] | 0.9% (22/2323) [0.6%, 1.4%] |
| claude-haiku-5-5 xhigh | 10% (10/96) [4.9%, 16%] | 57% (25/44) [39%, 76%] | 0% (0/269) [0%, 0%] |
| claude-opus-5-5 high | 0% (0/48) [0%, 0%] | 0% (0/23) [0%, 0%] | 0% (0/164) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/72) [0%, 0%] | 0% (0/35) [0%, 0%] | 0% (0/205) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/77) [0%, 0%] | 0% (0/60) [0%, 0%] | 0% (0/249) [0%, 0%] |
| claude-opus-5-5 medium | 0.2% (1/539) [0%, 0.6%] | 0.9% (2/215) [0%, 2.4%] | 0.1% (1/1369) [0%, 0.2%] |
| claude-opus-5-5 off | 0% (0/123) [0%, 0%] | 1.8% (1/57) [0%, 5.7%] | 0% (0/325) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/245) [0%, 0%] | 0% (0/100) [0%, 0%] | 0% (0/570) [0%, 0%] |
| claude-sonnet-5-5 high | 1.5% (2/131) [0%, 4.0%] | 4.3% (2/47) [0%, 11%] | 0.4% (1/285) [0%, 1.1%] |
| claude-sonnet-5-5 low | 1.0% (1/103) [0%, 3.3%] | 17% (6/36) [5.9%, 29%] | 0.4% (1/267) [0%, 1.3%] |
| claude-sonnet-5-5 max | 1.5% (1/68) [0%, 5.1%] | 0% (0/44) [0%, 0%] | 0% (0/187) [0%, 0%] |
| claude-sonnet-5-5 medium | 0.8% (4/475) [0.2%, 1.7%] | 7.9% (12/151) [4.1%, 12%] | 0.6% (8/1352) [0.2%, 1.0%] |
| claude-sonnet-5-5 off | 3.9% (5/129) [0.8%, 7.4%] | 23% (15/65) [11%, 35%] | 1.9% (6/321) [0.4%, 3.6%] |
| claude-sonnet-5-5 xhigh | 0% (0/140) [0%, 0%] | 4.7% (4/85) [1.1%, 9.6%] | 0% (0/400) [0%, 0%] |
| gpt-5.6-terra high | 0% (0/28) [0%, 0%] | 8.3% (1/12) [0%, 15%] | 4.2% (2/48) [0%, 8.7%] |
| gpt-5.6-terra low | 0% (0/20) [0%, 0%] | 17% (2/12) [0%, 50%] | 2.0% (1/49) [0%, 8.1%] |
| gpt-5.6-terra max | 0% (0/21) [0%, 0%] | 7.1% (1/14) [0%, 19%] | 0% (0/50) [0%, 0%] |
| gpt-5.6-terra medium | 5.1% (17/332) [2.9%, 7.6%] | 13% (24/189) [7.7%, 19%] | 0.9% (7/748) [0.3%, 1.6%] |
| gpt-5.6-terra xhigh | 0% (0/32) [0%, 0%] | 0% (0/16) [0%, 0%] | 0% (0/57) [0%, 0%] |
| gpt-6-astra high | 2.8% (5/177) [0.6%, 5.6%] | 2.2% (2/90) [0%, 6.1%] | 0% (0/472) [0%, 0%] |
| gpt-6-astra low | 1.6% (2/125) [0%, 3.9%] | 4.5% (3/67) [0%, 13%] | 0% (0/354) [0%, 0%] |
| gpt-6-astra medium | 0.8% (3/394) [0%, 1.7%] | 1.3% (3/226) [0%, 3.0%] | 0% (0/1175) [0%, 0%] |
| gpt-6-astra off | 0% (0/128) [0%, 0%] | 7.7% (6/78) [2.1%, 16%] | 0% (0/394) [0%, 0%] |
| gpt-6-luna high | 11% (28/250) [7.1%, 15%] | 25% (26/106) [17%, 33%] | 5.2% (31/596) [3.4%, 7.2%] |
| gpt-6-luna low | 31% (51/166) [23%, 38%] | 66% (45/68) [52%, 78%] | 18% (50/278) [15%, 22%] |
| gpt-6-luna max | 8.0% (2/25) [0%, 18%] | 11% (1/9) [0%, 38%] | 2.0% (1/51) [0%, 5.7%] |
| gpt-6-luna medium | 24% (141/596) [20%, 27%] | 52% (148/284) [46%, 58%] | 13% (140/1117) [10%, 15%] |
| gpt-6-luna off | 35% (86/249) [29%, 41%] | 78% (69/89) [68%, 86%] | 23% (86/380) [19%, 26%] |
| gpt-6-luna xhigh | 0% (0/28) [0%, 0%] | 22% (4/18) [0%, 63%] | 5.7% (4/70) [1.9%, 8.2%] |
| gpt-6.1-sol high | 0% (0/36) [0%, 0%] | 6.3% (1/16) [0%, 21%] | 0% (0/97) [0%, 0%] |
| gpt-6.1-sol low | 3.1% (1/32) [0%, 12%] | 14% (1/7) [0%, 38%] | 0% (0/78) [0%, 0%] |
| gpt-6.1-sol max | 1.9% (2/104) [0%, 5.0%] | 0% (0/56) [0%, 0%] | 0% (0/281) [0%, 0%] |
| gpt-6.1-sol medium | 0.9% (3/336) [0%, 2.0%] | 5.0% (7/141) [1.4%, 9.6%] | 0% (0/920) [0%, 0%] |
| gpt-6.1-sol xhigh | 0% (0/41) [0%, 0%] | 0% (0/26) [0%, 0%] | 0% (0/89) [0%, 0%] |
| gpt-6.1-terra high | 1.9% (3/154) [0%, 5.2%] | 7.5% (5/67) [1.5%, 14%] | 0% (0/372) [0%, 0%] |
| gpt-6.1-terra low | 4.8% (13/270) [2.3%, 7.8%] | 17% (16/93) [9.6%, 26%] | 0.4% (3/729) [0%, 0.9%] |
| gpt-6.1-terra max | 0.5% (1/203) [0%, 1.6%] | 0% (0/120) [0%, 0%] | 0% (0/444) [0%, 0%] |
| gpt-6.1-terra medium | 0.5% (1/194) [0%, 1.7%] | 4.8% (4/84) [1.1%, 9.7%] | 0% (0/566) [0%, 0%] |
| gpt-6.1-terra off | 5.6% (6/108) [1.8%, 11%] | 9.3% (5/54) [2.1%, 16%] | 0% (0/334) [0%, 0%] |
| gpt-6.1-terra xhigh | 0.6% (1/176) [0%, 2.0%] | 7.1% (7/98) [2.1%, 13%] | 0% (0/447) [0%, 0%] |

### Astra efforts

| Model | Opponent on known blank, not the last shell | Opponent on known blank, last shell | Self on known live |
|---|---|---|---|
| gpt-6-astra high | 0% (0/6) [0%, 0%] | 0% (0/2) [0%, 0%] | 0% (0/21) [0%, 0%] |
| gpt-6-astra low | 0% (0/5) [0%, 0%] | 0% (0/4) [0%, 0%] | 0% (0/25) [0%, 0%] |
| gpt-6-astra medium | 0% (0/5) [0%, 0%] | 0% (0/2) [0%, 0%] | 0% (0/20) [0%, 0%] |
| gpt-6-astra off | 0% (0/7) [0%, 0%] | 0% (0/1) [0%, 0%] | 0% (0/18) [0%, 0%] |

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
| claude-opus-5-5 high | 0% (0/96) [0%, 0%] | 0% (0/36) [0%, 0%] | 0% (0/214) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/71) [0%, 0%] | 3.3% (1/30) [0%, 10%] | 0% (0/189) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/60) [0%, 0%] | 0% (0/19) [0%, 0%] | 0% (0/203) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/137) [0%, 0%] | 2.0% (1/51) [0%, 5.9%] | 0% (0/349) [0%, 0%] |
| claude-opus-5-5 off | 0% (0/33) [0%, 0%] | 0% (0/8) [0%, 0%] | 0% (0/88) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/105) [0%, 0%] | 2.1% (1/47) [0%, 6.7%] | 0% (0/273) [0%, 0%] |

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
| gpt-6.1-terra high | 0% (0/22) [0%, 0%] | 0% (0/6) [0%, 0%] | 0% (0/45) [0%, 0%] |
| gpt-6.1-terra low | 4.3% (1/23) [0%, 21%] | 0% (0/6) [0%, 0%] | 0% (0/58) [0%, 0%] |
| gpt-6.1-terra max | 0% (0/23) [0%, 0%] | 0% (0/16) [0%, 0%] | 0% (0/30) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/22) [0%, 0%] | 0% (0/10) [0%, 0%] | 0% (0/76) [0%, 0%] |
| gpt-6.1-terra off | 4.5% (1/22) [0%, 11%] | 0% (0/6) [0%, 0%] | 0% (0/52) [0%, 0%] |
| gpt-6.1-terra xhigh | 5.0% (1/20) [0%, 18%] | 0% (0/5) [0%, 0%] | 0% (0/57) [0%, 0%] |

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
| Cross-model | 12% (2320/19778) [11%, 12%] | 2.2% (286/12865) [1.9%, 2.5%] | 11% (477/4349) [9.8%, 12%] | 12% (19/157) [6.8%, 18%] |
| Astra efforts | 0% (0/55) [0%, 0%] | 0% (0/41) [0%, 0%] | 0% (0/20) [0%, 0%] | – |
| Haiku 4.5 efforts | 29% (513/1770) [27%, 32%] | 12% (102/886) [9.0%, 14%] | 40% (79/196) [33%, 47%] | 0% (0/2) [0%, 0%] |
| Haiku 5.5 efforts | 20% (479/2360) [18%, 22%] | 4.0% (54/1340) [2.8%, 5.3%] | 11% (59/518) [7.9%, 15%] | 9.1% (1/11) [0%, 25%] |
| Luna efforts | 27% (705/2638) [24%, 29%] | 2.9% (39/1350) [1.9%, 3.9%] | 32% (141/442) [28%, 36%] | 9.1% (1/11) [0%, 20%] |
| Opus efforts | 0.3% (3/1065) [0%, 0.6%] | 0% (0/660) [0%, 0%] | 0% (0/273) [0%, 0%] | 0% (0/11) [0%, 0%] |
| Sol efforts | 1.3% (20/1493) [0.8%, 2.0%] | 0% (0/885) [0%, 0%] | 0% (0/446) [0%, 0%] | 0% (0/6) [0%, 0%] |
| Sonnet efforts | 1.4% (33/2341) [0.9%, 2.1%] | 0% (0/1441) [0%, 0%] | 1.2% (7/586) [0.4%, 2.1%] | 0% (0/15) [0%, 0%] |
| Terra 6.1 efforts | 0.8% (2/242) [0%, 2.1%] | 0% (0/177) [0%, 0%] | 1.3% (1/77) [0%, 4.2%] | 0% (0/3) [0%, 0%] |
| Terra efforts | 5.4% (90/1677) [4.2%, 6.6%] | 0.1% (1/937) [0%, 0.3%] | 8.6% (23/267) [5.4%, 13%] | 0% (0/5) [0%, 0%] |

### Cross-model, glass and phone by model

| Model | glass | phone |
|---|---|---|
| claude-haiku-4-5-20251001 high | 6.3% (8/127) [2.4%, 11%] | 35% (7/20) [14%, 60%] |
| claude-haiku-4-5-20251001 low | 3.5% (6/173) [1.1%, 6.1%] | 17% (4/24) [4.5%, 31%] |
| claude-haiku-4-5-20251001 medium | 11% (61/562) [7.7%, 14%] | 30% (35/117) [22%, 39%] |
| claude-haiku-4-5-20251001 minimal | 7.1% (11/156) [3.1%, 12%] | 24% (7/29) [9.1%, 42%] |
| claude-haiku-4-5-20251001 off | 13% (13/102) [5.8%, 22%] | 33% (9/27) [19%, 50%] |
| claude-haiku-5-5 high | 2.7% (8/301) [1.0%, 4.8%] | 1.8% (2/114) [0%, 4.1%] |
| claude-haiku-5-5 low | 3.2% (15/474) [1.7%, 4.8%] | 14% (21/150) [9.0%, 20%] |
| claude-haiku-5-5 max | 0% (0/18) [0%, 0%] | 0% (0/11) [0%, 0%] |
| claude-haiku-5-5 medium | 3.7% (27/732) [2.5%, 5.1%] | 4.6% (15/324) [2.5%, 7.0%] |
| claude-haiku-5-5 off | 6.0% (91/1514) [4.6%, 7.5%] | 34% (137/403) [29%, 39%] |
| claude-haiku-5-5 xhigh | 0.8% (1/127) [0%, 2.7%] | 1.9% (1/52) [0%, 6.0%] |
| claude-opus-5-5 high | 0% (0/74) [0%, 0%] | 0% (0/31) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/109) [0%, 0%] | 0% (0/26) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/113) [0%, 0%] | 0% (0/44) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/607) [0%, 0%] | 0.7% (2/275) [0%, 1.7%] |
| claude-opus-5-5 off | 0% (0/164) [0%, 0%] | 0% (0/45) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/286) [0%, 0%] | 0% (0/110) [0%, 0%] |
| claude-sonnet-5-5 high | 0.7% (1/140) [0%, 2.3%] | 1.5% (1/65) [0%, 5.3%] |
| claude-sonnet-5-5 low | 0% (0/141) [0%, 0%] | 0% (0/50) [0%, 0%] |
| claude-sonnet-5-5 max | 0% (0/94) [0%, 0%] | 2.1% (1/48) [0%, 7.3%] |
| claude-sonnet-5-5 medium | 0.1% (1/674) [0%, 0.5%] | 1.3% (3/225) [0%, 2.9%] |
| claude-sonnet-5-5 off | 0.6% (1/158) [0%, 1.9%] | 2.1% (1/48) [0%, 7.0%] |
| claude-sonnet-5-5 xhigh | 0% (0/180) [0%, 0%] | 0% (0/90) [0%, 0%] |
| gpt-5.6-terra high | 0% (0/32) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-5.6-terra low | 0% (0/30) [0%, 0%] | 0% (0/4) [0%, 0%] |
| gpt-5.6-terra max | 0% (0/28) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-5.6-terra medium | 0% (0/470) [0%, 0%] | 14% (15/105) [7.1%, 22%] |
| gpt-5.6-terra xhigh | 0% (0/36) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-6-astra high | 0% (0/283) [0%, 0%] | 0% (0/88) [0%, 0%] |
| gpt-6-astra low | 0% (0/180) [0%, 0%] | 0% (0/71) [0%, 0%] |
| gpt-6-astra medium | 0% (0/580) [0%, 0%] | 0% (0/209) [0%, 0%] |
| gpt-6-astra off | 0% (0/206) [0%, 0%] | 0% (0/77) [0%, 0%] |
| gpt-6-luna high | 0.3% (1/376) [0%, 0.8%] | 21% (23/110) [13%, 30%] |
| gpt-6-luna low | 5.2% (10/191) [2.2%, 8.7%] | 52% (33/63) [38%, 65%] |
| gpt-6-luna max | 0% (0/26) [0%, 0%] | 7.1% (1/14) [0%, 21%] |
| gpt-6-luna medium | 1.9% (14/741) [1.0%, 2.9%] | 38% (89/235) [32%, 44%] |
| gpt-6-luna off | 5.4% (15/280) [3.1%, 7.7%] | 52% (55/106) [43%, 61%] |
| gpt-6-luna xhigh | 0% (0/29) [0%, 0%] | 0% (0/7) [0%, 0%] |
| gpt-6.1-sol high | 0% (0/39) [0%, 0%] | 0% (0/22) [0%, 0%] |
| gpt-6.1-sol low | 0% (0/45) [0%, 0%] | 5.3% (1/19) [0%, 20%] |
| gpt-6.1-sol max | 0% (0/173) [0%, 0%] | 0% (0/42) [0%, 0%] |
| gpt-6.1-sol medium | 0% (0/426) [0%, 0%] | 0.6% (1/167) [0%, 1.9%] |
| gpt-6.1-sol xhigh | 0% (0/40) [0%, 0%] | 0% (0/25) [0%, 0%] |
| gpt-6.1-terra high | 0% (0/209) [0%, 0%] | 0% (0/79) [0%, 0%] |
| gpt-6.1-terra low | 0% (0/450) [0%, 0%] | 6.6% (10/152) [2.0%, 12%] |
| gpt-6.1-terra max | 0.4% (1/243) [0%, 1.3%] | 0% (0/125) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/311) [0%, 0%] | 0.9% (1/107) [0%, 3.0%] |
| gpt-6.1-terra off | 0.6% (1/170) [0%, 1.9%] | 3.5% (2/57) [0%, 8.5%] |
| gpt-6.1-terra xhigh | 0% (0/245) [0%, 0%] | 0% (0/115) [0%, 0%] |

### Astra efforts, glass and phone by model

| Model | glass | phone |
|---|---|---|
| gpt-6-astra high | 0% (0/7) [0%, 0%] | 0% (0/6) [0%, 0%] |
| gpt-6-astra low | 0% (0/14) [0%, 0%] | 0% (0/4) [0%, 0%] |
| gpt-6-astra medium | 0% (0/10) [0%, 0%] | 0% (0/8) [0%, 0%] |
| gpt-6-astra off | 0% (0/10) [0%, 0%] | 0% (0/2) [0%, 0%] |

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
| claude-opus-5-5 high | 0% (0/110) [0%, 0%] | 0% (0/52) [0%, 0%] |
| claude-opus-5-5 low | 0% (0/107) [0%, 0%] | 0% (0/28) [0%, 0%] |
| claude-opus-5-5 max | 0% (0/85) [0%, 0%] | 0% (0/29) [0%, 0%] |
| claude-opus-5-5 medium | 0% (0/180) [0%, 0%] | 0% (0/79) [0%, 0%] |
| claude-opus-5-5 off | 0% (0/43) [0%, 0%] | 0% (0/16) [0%, 0%] |
| claude-opus-5-5 xhigh | 0% (0/135) [0%, 0%] | 0% (0/69) [0%, 0%] |

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
| gpt-6.1-terra high | 0% (0/28) [0%, 0%] | 0% (0/13) [0%, 0%] |
| gpt-6.1-terra low | 0% (0/35) [0%, 0%] | 0% (0/13) [0%, 0%] |
| gpt-6.1-terra max | 0% (0/20) [0%, 0%] | 0% (0/7) [0%, 0%] |
| gpt-6.1-terra medium | 0% (0/38) [0%, 0%] | 0% (0/11) [0%, 0%] |
| gpt-6.1-terra off | 0% (0/30) [0%, 0%] | 4.5% (1/22) [0%, 13%] |
| gpt-6.1-terra xhigh | 0% (0/26) [0%, 0%] | 0% (0/11) [0%, 0%] |

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
| Cross-model | 1.6% (122/7480) [1.3%, 2.0%] | 2.5% (107/4200) [2.1%, 3.1%] | 4.8% (56/1163) [3.6%, 6.1%] | 4.5% (1/22) [0%, 14%] |
| Astra efforts | 0% (0/24) [0%, 0%] | 0% (0/13) [0%, 0%] | 0% (0/4) [0%, 0%] | – |
| Haiku 4.5 efforts | 11% (55/518) [7.4%, 14%] | 11% (35/327) [7.4%, 14%] | 30% (12/40) [15%, 47%] | 0% (0/1) [0%, 0%] |
| Haiku 5.5 efforts | 2.7% (15/561) [1.3%, 4.1%] | 4.4% (25/562) [2.5%, 6.6%] | 6.0% (13/215) [3.3%, 9.4%] | 50% (1/2) [0%, 100%] |
| Luna efforts | 0.5% (4/786) [0.1%, 1.0%] | 5.1% (23/449) [3.2%, 7.4%] | 11% (12/112) [5.1%, 17%] | 0% (0/3) [0%, 0%] |
| Opus efforts | 0% (0/367) [0%, 0%] | 0% (0/210) [0%, 0%] | 0% (0/82) [0%, 0%] | 0% (0/1) [0%, 0%] |
| Sol efforts | 0% (0/563) [0%, 0%] | 0% (0/232) [0%, 0%] | 0% (0/90) [0%, 0%] | – |
| Sonnet efforts | 0% (0/709) [0%, 0%] | 0% (0/491) [0%, 0%] | 0% (0/236) [0%, 0%] | 0% (0/5) [0%, 0%] |
| Terra 6.1 efforts | 0% (0/122) [0%, 0%] | 0% (0/43) [0%, 0%] | 0% (0/12) [0%, 0%] | – |
| Terra efforts | 0% (0/575) [0%, 0%] | 0.3% (1/300) [0%, 1.0%] | 0% (0/61) [0%, 0%] | 0% (0/1) [0%, 0%] |

### phone

| Cohort | 0 | 1 | 2–3 | 4+ |
|---|---|---|---|---|
| Cross-model | 6.5% (44/680) [4.7%, 8.4%] | 9.5% (95/1003) [7.6%, 12%] | 10% (161/1538) [8.8%, 12%] | 16% (177/1128) [14%, 18%] |
| Astra efforts | – | 0% (0/5) [0%, 0%] | 0% (0/10) [0%, 0%] | 0% (0/5) [0%, 0%] |
| Haiku 4.5 efforts | 39% (16/41) [26%, 53%] | 38% (14/37) [23%, 56%] | 48% (29/60) [38%, 59%] | 34% (20/58) [25%, 44%] |
| Haiku 5.5 efforts | 9.5% (7/74) [3.5%, 17%] | 5.6% (6/108) [1.8%, 9.9%] | 13% (28/210) [8.8%, 18%] | 14% (18/126) [8.5%, 21%] |
| Luna efforts | 29% (24/84) [20%, 38%] | 30% (29/98) [22%, 38%] | 32% (47/149) [24%, 39%] | 37% (41/111) [28%, 46%] |
| Opus efforts | 0% (0/47) [0%, 0%] | 0% (0/63) [0%, 0%] | 0% (0/112) [0%, 0%] | 0% (0/51) [0%, 0%] |
| Sol efforts | 0% (0/77) [0%, 0%] | 0% (0/102) [0%, 0%] | 0% (0/148) [0%, 0%] | 0% (0/119) [0%, 0%] |
| Sonnet efforts | 0% (0/108) [0%, 0%] | 0.7% (1/134) [0%, 2.3%] | 1.3% (3/223) [0%, 3.0%] | 2.5% (3/121) [0%, 5.6%] |
| Terra 6.1 efforts | 0% (0/14) [0%, 0%] | 0% (0/14) [0%, 0%] | 3.0% (1/33) [0%, 12%] | 0% (0/16) [0%, 0%] |
| Terra efforts | 3.3% (2/60) [0%, 8.5%] | 8.3% (6/72) [2.7%, 15%] | 10% (9/86) [4.4%, 17%] | 12% (6/49) [2.6%, 22%] |

## How shots are informed

Each agent shot by what the player knew of the chamber: a clue from its own item (glass, phone or both), the public count, or nothing. The last column is blind shots taken while the player held a magnifying glass.

### Cross-model

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 high | 21% (147/690) [19%, 24%] | 32% (219/690) [29%, 35%] | 47% (324/690) [43%, 51%] | 2.2% (7/324) [0.6%, 4.0%] |
| claude-haiku-4-5-20251001 low | 23% (199/872) [21%, 25%] | 31% (268/872) [28%, 34%] | 46% (405/872) [43%, 49%] | 2.0% (8/405) [0.7%, 3.6%] |
| claude-haiku-4-5-20251001 medium | 21% (680/3255) [19%, 22%] | 30% (966/3255) [28%, 31%] | 49% (1609/3255) [48%, 51%] | 2.9% (47/1609) [1.9%, 4.2%] |
| claude-haiku-4-5-20251001 minimal | 23% (186/815) [20%, 26%] | 32% (259/815) [29%, 35%] | 45% (370/815) [42%, 49%] | 2.7% (10/370) [1.1%, 4.6%] |
| claude-haiku-4-5-20251001 off | 24% (130/531) [20%, 29%] | 27% (146/531) [24%, 31%] | 48% (255/531) [43%, 53%] | 1.6% (4/255) [0.4%, 3.0%] |
| claude-haiku-5-5 high | 30% (416/1402) [27%, 32%] | 35% (495/1402) [33%, 38%] | 35% (491/1402) [33%, 37%] | 0% (0/491) [0%, 0%] |
| claude-haiku-5-5 low | 31% (645/2056) [29%, 34%] | 34% (696/2056) [32%, 36%] | 35% (715/2056) [33%, 37%] | 0.7% (5/715) [0.1%, 1.5%] |
| claude-haiku-5-5 max | 25% (29/114) [19%, 32%] | 39% (44/114) [31%, 47%] | 36% (41/114) [32%, 41%] | 0% (0/41) [0%, 0%] |
| claude-haiku-5-5 medium | 28% (1071/3889) [26%, 29%] | 35% (1358/3889) [33%, 37%] | 38% (1460/3889) [36%, 39%] | 0.5% (8/1460) [0.2%, 1.0%] |
| claude-haiku-5-5 off | 32% (1932/6105) [30%, 33%] | 27% (1631/6105) [26%, 28%] | 42% (2542/6105) [40%, 43%] | 0.3% (7/2542) [0.1%, 0.5%] |
| claude-haiku-5-5 xhigh | 29% (184/645) [25%, 32%] | 35% (225/645) [32%, 38%] | 37% (236/645) [32%, 41%] | 0.4% (1/236) [0%, 1.4%] |
| claude-opus-5-5 high | 29% (109/379) [24%, 34%] | 33% (126/379) [28%, 39%] | 38% (144/379) [32%, 44%] | 0% (0/144) [0%, 0%] |
| claude-opus-5-5 low | 30% (138/463) [27%, 33%] | 38% (174/463) [33%, 42%] | 33% (151/463) [27%, 37%] | 0% (0/151) [0%, 0%] |
| claude-opus-5-5 max | 28% (159/578) [23%, 32%] | 39% (227/578) [36%, 43%] | 33% (192/578) [29%, 37%] | 1.0% (2/192) [0%, 2.6%] |
| claude-opus-5-5 medium | 28% (894/3242) [26%, 29%] | 38% (1229/3242) [36%, 40%] | 35% (1119/3242) [33%, 36%] | 0.2% (2/1119) [0%, 0.5%] |
| claude-opus-5-5 off | 27% (210/773) [24%, 30%] | 38% (295/773) [35%, 41%] | 35% (268/773) [31%, 39%] | 0% (0/268) [0%, 0%] |
| claude-opus-5-5 xhigh | 28% (399/1411) [25%, 31%] | 37% (516/1411) [34%, 39%] | 35% (496/1411) [32%, 38%] | 0.2% (1/496) [0%, 0.7%] |
| claude-sonnet-5-5 high | 28% (207/734) [24%, 32%] | 35% (256/734) [32%, 38%] | 37% (271/734) [34%, 40%] | 0.4% (1/271) [0%, 1.2%] |
| claude-sonnet-5-5 low | 28% (192/674) [25%, 32%] | 32% (214/674) [29%, 35%] | 40% (268/674) [35%, 44%] | 0% (0/268) [0%, 0%] |
| claude-sonnet-5-5 max | 31% (145/472) [24%, 37%] | 33% (154/472) [30%, 35%] | 37% (173/472) [31%, 43%] | 1.7% (3/173) [0%, 4.3%] |
| claude-sonnet-5-5 medium | 28% (904/3220) [26%, 30%] | 33% (1074/3220) [32%, 35%] | 39% (1242/3220) [37%, 40%] | 0.2% (3/1242) [0%, 0.5%] |
| claude-sonnet-5-5 off | 27% (213/782) [24%, 30%] | 39% (302/782) [35%, 42%] | 34% (267/782) [31%, 38%] | 0% (0/267) [0%, 0%] |
| claude-sonnet-5-5 xhigh | 29% (274/932) [26%, 33%] | 38% (351/932) [35%, 40%] | 33% (307/932) [29%, 37%] | 0% (0/307) [0%, 0%] |
| gpt-5.6-terra high | 28% (40/145) [21%, 35%] | 33% (48/145) [29%, 37%] | 39% (57/145) [34%, 43%] | 0% (0/57) [0%, 0%] |
| gpt-5.6-terra low | 24% (34/139) [19%, 30%] | 34% (47/139) [29%, 37%] | 42% (58/139) [33%, 51%] | 0% (0/58) [0%, 0%] |
| gpt-5.6-terra max | 23% (34/149) [20%, 26%] | 34% (51/149) [26%, 42%] | 43% (64/149) [36%, 50%] | 0% (0/64) [0%, 0%] |
| gpt-5.6-terra medium | 26% (577/2205) [24%, 28%] | 31% (692/2205) [29%, 33%] | 42% (936/2205) [40%, 45%] | 0.3% (3/936) [0%, 0.8%] |
| gpt-5.6-terra xhigh | 24% (44/180) [18%, 30%] | 34% (61/180) [25%, 43%] | 42% (75/180) [35%, 49%] | 0% (0/75) [0%, 0%] |
| gpt-6-astra high | 32% (375/1174) [29%, 35%] | 31% (364/1174) [29%, 33%] | 37% (435/1174) [34%, 40%] | 0% (0/435) [0%, 0%] |
| gpt-6-astra low | 28% (252/898) [25%, 31%] | 33% (294/898) [30%, 35%] | 39% (352/898) [36%, 42%] | 0.3% (1/352) [0%, 0.9%] |
| gpt-6-astra medium | 27% (793/2986) [25%, 28%] | 34% (1002/2986) [32%, 35%] | 40% (1191/2986) [38%, 42%] | 0% (0/1191) [0%, 0%] |
| gpt-6-astra off | 29% (284/994) [26%, 32%] | 32% (316/994) [29%, 34%] | 40% (394/994) [36%, 43%] | 0.3% (1/394) [0%, 0.8%] |
| gpt-6-luna high | 32% (486/1518) [29%, 35%] | 31% (466/1518) [29%, 33%] | 37% (566/1518) [35%, 40%] | 0.4% (2/566) [0%, 0.9%] |
| gpt-6-luna low | 27% (255/957) [23%, 30%] | 27% (257/957) [24%, 30%] | 46% (445/957) [43%, 50%] | 0.2% (1/445) [0%, 0.7%] |
| gpt-6-luna max | 29% (41/142) [23%, 34%] | 31% (44/142) [24%, 38%] | 40% (57/142) [32%, 50%] | 0% (0/57) [0%, 0%] |
| gpt-6-luna medium | 27% (979/3608) [26%, 29%] | 28% (1018/3608) [27%, 30%] | 45% (1611/3608) [43%, 46%] | 1.0% (16/1611) [0.5%, 1.6%] |
| gpt-6-luna off | 28% (387/1372) [26%, 30%] | 24% (331/1372) [22%, 26%] | 48% (654/1372) [45%, 50%] | 0.5% (3/654) [0%, 1.0%] |
| gpt-6-luna xhigh | 17% (36/207) [14%, 22%] | 39% (80/207) [31%, 47%] | 44% (91/207) [37%, 50%] | 0% (0/91) [0%, 0%] |
| gpt-6.1-sol high | 26% (61/238) [20%, 31%] | 37% (88/238) [31%, 42%] | 37% (89/238) [31%, 43%] | 0% (0/89) [0%, 0%] |
| gpt-6.1-sol low | 31% (64/206) [25%, 37%] | 26% (53/206) [20%, 31%] | 43% (89/206) [36%, 52%] | 0% (0/89) [0%, 0%] |
| gpt-6.1-sol max | 29% (215/743) [25%, 33%] | 30% (226/743) [27%, 34%] | 41% (302/743) [37%, 44%] | 0.3% (1/302) [0%, 1.0%] |
| gpt-6.1-sol medium | 26% (594/2319) [24%, 27%] | 35% (803/2319) [33%, 36%] | 40% (922/2319) [38%, 42%] | 0.1% (1/922) [0%, 0.3%] |
| gpt-6.1-sol xhigh | 27% (69/252) [22%, 33%] | 35% (87/252) [30%, 39%] | 38% (96/252) [32%, 43%] | 0% (0/96) [0%, 0%] |
| gpt-6.1-terra high | 31% (291/924) [28%, 35%] | 33% (302/924) [30%, 35%] | 36% (331/924) [33%, 39%] | 0% (0/331) [0%, 0%] |
| gpt-6.1-terra low | 32% (605/1865) [30%, 35%] | 26% (487/1865) [24%, 28%] | 41% (773/1865) [39%, 44%] | 0.3% (2/773) [0%, 0.7%] |
| gpt-6.1-terra max | 31% (374/1208) [29%, 33%] | 33% (393/1208) [30%, 35%] | 37% (441/1208) [34%, 39%] | 0.5% (2/441) [0%, 1.2%] |
| gpt-6.1-terra medium | 30% (427/1428) [27%, 32%] | 29% (417/1428) [27%, 32%] | 41% (584/1428) [38%, 44%] | 0% (0/584) [0%, 0%] |
| gpt-6.1-terra off | 27% (229/853) [24%, 30%] | 31% (267/853) [29%, 34%] | 42% (357/853) [38%, 45%] | 0% (0/357) [0%, 0%] |
| gpt-6.1-terra xhigh | 32% (362/1143) [29%, 34%] | 31% (359/1143) [29%, 34%] | 37% (422/1143) [34%, 40%] | 0% (0/422) [0%, 0%] |

### Astra efforts

| Model | Known from a clue | Known from the count | Unknown | Blind with a glass in hand |
|---|---|---|---|---|
| gpt-6-astra high | 25% (13/52) [5.6%, 35%] | 31% (16/52) [26%, 39%] | 44% (23/52) [35%, 61%] | 0% (0/23) [0%, 0%] |
| gpt-6-astra low | 31% (18/59) [23%, 38%] | 27% (16/59) [22%, 32%] | 42% (25/59) [36%, 51%] | 0% (0/25) [0%, 0%] |
| gpt-6-astra medium | 49% (18/37) [39%, 58%] | 24% (9/37) [16%, 33%] | 27% (10/37) [26%, 28%] | 0% (0/10) [0%, 0%] |
| gpt-6-astra off | 29% (12/41) [25%, 33%] | 34% (14/41) [31%, 38%] | 37% (15/41) [33%, 38%] | 0% (0/15) [0%, 0%] |

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
| claude-opus-5-5 high | 29% (163/560) [25%, 34%] | 33% (183/560) [28%, 38%] | 38% (214/560) [34%, 44%] | 0% (0/214) [0%, 0%] |
| claude-opus-5-5 low | 28% (135/486) [23%, 32%] | 32% (155/486) [28%, 35%] | 40% (196/486) [35%, 46%] | 0% (0/196) [0%, 0%] |
| claude-opus-5-5 max | 29% (119/417) [24%, 33%] | 39% (163/417) [34%, 44%] | 32% (135/417) [28%, 37%] | 5.9% (8/135) [2.8%, 9.5%] |
| claude-opus-5-5 medium | 30% (259/858) [27%, 34%] | 32% (278/858) [29%, 36%] | 37% (321/858) [33%, 42%] | 0.3% (1/321) [0%, 1.0%] |
| claude-opus-5-5 off | 27% (61/222) [21%, 34%] | 31% (68/222) [27%, 35%] | 42% (93/222) [35%, 48%] | 0% (0/93) [0%, 0%] |
| claude-opus-5-5 xhigh | 32% (207/651) [28%, 36%] | 33% (218/651) [30%, 37%] | 35% (226/651) [31%, 39%] | 0.9% (2/226) [0%, 2.1%] |

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
| gpt-6.1-terra high | 33% (41/126) [27%, 39%] | 25% (32/126) [19%, 32%] | 42% (53/126) [34%, 48%] | 0% (0/53) [0%, 0%] |
| gpt-6.1-terra low | 40% (48/119) [31%, 49%] | 33% (39/119) [23%, 43%] | 27% (32/119) [22%, 35%] | 0% (0/32) [0%, 0%] |
| gpt-6.1-terra max | 23% (27/115) [15%, 34%] | 37% (42/115) [24%, 44%] | 40% (46/115) [34%, 49%] | 0% (0/46) [0%, 0%] |
| gpt-6.1-terra medium | 32% (52/164) [24%, 39%] | 34% (56/164) [28%, 40%] | 34% (56/164) [26%, 43%] | 0% (0/56) [0%, 0%] |
| gpt-6.1-terra off | 42% (52/125) [30%, 55%] | 22% (28/125) [15%, 28%] | 36% (45/125) [26%, 45%] | 0% (0/45) [0%, 0%] |
| gpt-6.1-terra xhigh | 27% (37/137) [19%, 36%] | 33% (45/137) [27%, 38%] | 40% (55/137) [32%, 48%] | 0% (0/55) [0%, 0%] |

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
| claude-haiku-4-5-20251001 high | 50% (688/1364) [47%, 55%] | 9.8% (134/1364) [8.5%, 11%] | 31% (423/1364) [27%, 35%] | 8.7% (119/1364) [6.4%, 11%] | 1.49 (1) | 6 |
| claude-haiku-4-5-20251001 low | 52% (901/1729) [49%, 55%] | 8.9% (154/1729) [7.5%, 10%] | 28% (492/1729) [25%, 32%] | 11% (182/1729) [7.2%, 14%] | 1.56 (1) | 7 |
| claude-haiku-4-5-20251001 medium | 48% (3120/6488) [46%, 50%] | 8.3% (540/6488) [7.6%, 9.0%] | 29% (1903/6488) [27%, 31%] | 14% (925/6488) [13%, 16%] | 1.41 (1) | 6 |
| claude-haiku-4-5-20251001 minimal | 51% (792/1544) [47%, 55%] | 8.2% (126/1544) [6.9%, 9.5%] | 28% (433/1544) [24%, 32%] | 13% (193/1544) [9.3%, 16%] | 1.60 (1) | 6 |
| claude-haiku-4-5-20251001 off | 52% (568/1094) [48%, 56%] | 10% (111/1094) [8.8%, 12%] | 31% (340/1094) [26%, 36%] | 6.9% (75/1094) [3.8%, 9.9%] | 1.36 (1) | 6 |
| claude-haiku-5-5 high | 59% (1690/2869) [57%, 61%] | 9.2% (263/2869) [8.1%, 10%] | 20% (570/2869) [17%, 23%] | 12% (346/2869) [10%, 14%] | 1.57 (1) | 7 |
| claude-haiku-5-5 low | 60% (2539/4240) [58%, 62%] | 8.3% (352/4240) [7.4%, 9.3%] | 16% (694/4240) [14%, 18%] | 15% (655/4240) [14%, 17%] | 1.46 (1) | 6 |
| claude-haiku-5-5 max | 59% (138/233) [49%, 67%] | 5.2% (12/233) [2.3%, 8.3%] | 17% (40/233) [8.0%, 27%] | 18% (43/233) [13%, 25%] | 1.66 (1) | 8 |
| claude-haiku-5-5 medium | 58% (4805/8270) [57%, 60%] | 8.2% (677/8270) [7.6%, 8.8%] | 20% (1626/8270) [18%, 21%] | 14% (1162/8270) [13%, 15%] | 1.56 (1) | 7 |
| claude-haiku-5-5 off | 58% (7825/13391) [57%, 59%] | 8.8% (1172/13391) [8.2%, 9.3%] | 22% (2915/13391) [21%, 23%] | 11% (1479/13391) [10%, 12%] | 1.34 (1) | 6 |
| claude-haiku-5-5 xhigh | 55% (756/1366) [52%, 59%] | 8.1% (111/1366) [6.7%, 9.6%] | 26% (356/1366) [22%, 30%] | 10% (143/1366) [7.7%, 14%] | 1.61 (1) | 7 |
| claude-opus-5-5 high | 59% (432/732) [55%, 63%] | 7.1% (52/732) [5.8%, 8.5%] | 14% (104/732) [9.4%, 19%] | 20% (144/732) [15%, 24%] | 1.81 (1) | 7 |
| claude-opus-5-5 low | 55% (494/895) [51%, 60%] | 7.9% (71/895) [6.4%, 9.5%] | 21% (184/895) [16%, 25%] | 16% (146/895) [12%, 21%] | 1.72 (1) | 7 |
| claude-opus-5-5 max | 63% (668/1059) [59%, 66%] | 5.7% (60/1059) [4.3%, 7.0%] | 11% (117/1059) [7.0%, 16%] | 20% (214/1059) [16%, 24%] | 1.86 (1) | 7 |
| claude-opus-5-5 medium | 56% (3466/6145) [55%, 58%] | 7.7% (472/6145) [7.0%, 8.4%] | 19% (1170/6145) [17%, 21%] | 17% (1037/6145) [15%, 18%] | 1.68 (1) | 7 |
| claude-opus-5-5 off | 58% (853/1460) [55%, 62%] | 7.7% (112/1460) [6.0%, 9.5%] | 16% (228/1460) [12%, 19%] | 18% (267/1460) [15%, 22%] | 1.77 (1) | 7 |
| claude-opus-5-5 xhigh | 57% (1514/2655) [55%, 59%] | 9.5% (253/2655) [8.2%, 11%] | 20% (523/2655) [17%, 22%] | 14% (365/2655) [12%, 16%] | 1.78 (1) | 7 |
| claude-sonnet-5-5 high | 52% (741/1419) [48%, 56%] | 10% (146/1419) [8.7%, 12%] | 25% (361/1419) [21%, 30%] | 12% (171/1419) [9.3%, 15%] | 1.56 (1) | 7 |
| claude-sonnet-5-5 low | 50% (670/1342) [47%, 53%] | 9.0% (121/1342) [7.5%, 11%] | 31% (420/1342) [26%, 36%] | 9.8% (131/1342) [7.1%, 13%] | 1.59 (1) | 6 |
| claude-sonnet-5-5 max | 56% (532/945) [53%, 59%] | 10% (95/945) [7.8%, 12%] | 19% (179/945) [15%, 23%] | 15% (139/945) [12%, 18%] | 1.77 (1) | 7 |
| claude-sonnet-5-5 medium | 53% (3234/6059) [52%, 55%] | 7.5% (457/6059) [6.9%, 8.2%] | 23% (1376/6059) [21%, 25%] | 16% (992/6059) [15%, 18%] | 1.72 (1) | 7 |
| claude-sonnet-5-5 off | 52% (799/1551) [48%, 55%] | 10% (158/1551) [8.8%, 12%] | 24% (375/1551) [20%, 29%] | 14% (219/1551) [11%, 17%] | 1.70 (1) | 7 |
| claude-sonnet-5-5 xhigh | 60% (1084/1810) [57%, 63%] | 8.7% (157/1810) [7.6%, 9.9%] | 18% (317/1810) [14%, 21%] | 14% (252/1810) [12%, 16%] | 1.88 (1) | 7 |
| gpt-5.6-terra high | 51% (135/264) [48%, 55%] | 8.0% (21/264) [4.7%, 11%] | 27% (71/264) [21%, 34%] | 14% (37/264) [7.5%, 21%] | 1.56 (1) | 6 |
| gpt-5.6-terra low | 51% (136/266) [43%, 56%] | 6.8% (18/266) [5.4%, 8.5%] | 24% (64/266) [19%, 33%] | 18% (48/266) [11%, 27%] | 1.21 (1) | 6 |
| gpt-5.6-terra max | 68% (170/250) [63%, 73%] | 8.0% (20/250) [5.1%, 10%] | 14% (35/250) [10%, 17%] | 10% (25/250) [5.1%, 19%] | 1.60 (1) | 6 |
| gpt-5.6-terra medium | 52% (2111/4024) [51%, 54%] | 7.9% (319/4024) [7.1%, 8.7%] | 23% (907/4024) [20%, 25%] | 17% (687/4024) [15%, 19%] | 1.47 (1) | 6 |
| gpt-5.6-terra xhigh | 63% (199/318) [56%, 70%] | 6.3% (20/318) [3.8%, 9.0%] | 16% (51/318) [10.0%, 23%] | 15% (48/318) [9.5%, 21%] | 1.65 (1) | 6 |
| gpt-6-astra high | 60% (1350/2267) [57%, 62%] | 9.0% (203/2267) [7.7%, 10%] | 15% (332/2267) [12%, 18%] | 17% (382/2267) [15%, 19%] | 1.72 (1) | 7 |
| gpt-6-astra low | 57% (970/1710) [54%, 60%] | 7.9% (135/1710) [6.6%, 9.3%] | 17% (292/1710) [13%, 21%] | 18% (313/1710) [15%, 21%] | 1.61 (1) | 6 |
| gpt-6-astra medium | 56% (3233/5743) [55%, 58%] | 7.5% (430/5743) [6.7%, 8.3%] | 17% (974/5743) [15%, 19%] | 19% (1106/5743) [18%, 21%] | 1.69 (1) | 7 |
| gpt-6-astra off | 55% (1029/1881) [52%, 57%] | 8.6% (162/1881) [7.3%, 9.9%] | 17% (329/1881) [14%, 21%] | 19% (361/1881) [16%, 22%] | 1.68 (1) | 7 |
| gpt-6-luna high | 62% (1789/2878) [60%, 64%] | 8.2% (236/2878) [7.1%, 9.3%] | 19% (541/2878) [16%, 21%] | 11% (312/2878) [9.3%, 12%] | 1.52 (1) | 6 |
| gpt-6-luna low | 69% (1357/1958) [67%, 72%] | 9.2% (180/1958) [8.0%, 10%] | 18% (360/1958) [16%, 21%] | 3.1% (61/1958) [1.9%, 4.5%] | 1.64 (1) | 6 |
| gpt-6-luna max | 58% (166/284) [47%, 67%] | 5.3% (15/284) [2.1%, 8.9%] | 24% (69/284) [15%, 35%] | 12% (34/284) [5.5%, 18%] | 1.58 (1) | 7 |
| gpt-6-luna medium | 62% (4318/6919) [61%, 64%] | 7.2% (495/6919) [6.6%, 7.7%] | 23% (1588/6919) [21%, 25%] | 7.5% (518/6919) [6.5%, 8.6%] | 1.54 (1) | 6 |
| gpt-6-luna off | 70% (1886/2701) [68%, 72%] | 7.9% (213/2701) [6.9%, 8.9%] | 20% (528/2701) [17%, 22%] | 2.7% (74/2701) [1.9%, 3.7%] | 1.64 (1) | 6 |
| gpt-6-luna xhigh | 64% (252/391) [59%, 71%] | 7.2% (28/391) [5.2%, 9.0%] | 16% (63/391) [13%, 20%] | 12% (48/391) [7.3%, 17%] | 1.85 (1) | 7 |
| gpt-6.1-sol high | 58% (269/460) [50%, 66%] | 9.3% (43/460) [6.1%, 12%] | 20% (91/460) [13%, 26%] | 12% (57/460) [7.6%, 18%] | 1.55 (1) | 6 |
| gpt-6.1-sol low | 57% (227/395) [51%, 64%] | 6.8% (27/395) [5.8%, 8.1%] | 16% (64/395) [10%, 23%] | 19% (77/395) [14%, 26%] | 1.52 (1) | 6 |
| gpt-6.1-sol max | 60% (889/1471) [57%, 64%] | 8.4% (123/1471) [7.1%, 9.7%] | 15% (226/1471) [12%, 19%] | 16% (233/1471) [13%, 19%] | 1.66 (1) | 6 |
| gpt-6.1-sol medium | 57% (2520/4448) [55%, 58%] | 6.9% (306/4448) [6.2%, 7.6%] | 18% (798/4448) [16%, 20%] | 19% (824/4448) [17%, 20%] | 1.65 (1) | 7 |
| gpt-6.1-sol xhigh | 61% (312/511) [56%, 67%] | 8.2% (42/511) [6.4%, 10%] | 15% (76/511) [9.9%, 20%] | 16% (81/511) [12%, 20%] | 1.70 (1) | 7 |
| gpt-6.1-terra high | 57% (984/1714) [55%, 60%] | 7.6% (130/1714) [6.3%, 8.9%] | 15% (256/1714) [12%, 18%] | 20% (344/1714) [17%, 23%] | 1.73 (1) | 7 |
| gpt-6.1-terra low | 55% (1878/3438) [53%, 56%] | 8.7% (299/3438) [7.9%, 9.5%] | 19% (658/3438) [17%, 21%] | 18% (603/3438) [16%, 19%] | 1.48 (1) | 6 |
| gpt-6.1-terra max | 65% (1511/2333) [62%, 68%] | 6.4% (150/2333) [5.6%, 7.3%] | 13% (302/2333) [10%, 16%] | 16% (370/2333) [13%, 18%] | 1.84 (1) | 7 |
| gpt-6.1-terra medium | 56% (1458/2617) [54%, 58%] | 8.3% (216/2617) [7.2%, 9.3%] | 17% (438/2617) [14%, 19%] | 19% (505/2617) [17%, 22%] | 1.54 (1) | 6 |
| gpt-6.1-terra off | 53% (831/1558) [50%, 56%] | 7.7% (120/1558) [6.3%, 9.2%] | 21% (323/1558) [17%, 25%] | 18% (284/1558) [15%, 21%] | 1.46 (1) | 7 |
| gpt-6.1-terra xhigh | 61% (1277/2103) [58%, 63%] | 8.2% (173/2103) [7.0%, 9.4%] | 15% (306/2103) [12%, 17%] | 17% (347/2103) [14%, 19%] | 1.62 (1) | 6 |

### Astra efforts

| Model | Used | Stolen | Held at death | Held at round end | Own turns held before use, mean (median) | Accepted moves to use, median |
|---|---|---|---|---|---|---|
| gpt-6-astra high | 69% (65/94) [64%, 73%] | 5.3% (5/94) [3.0%, 9.7%] | 19% (18/94) [8.8%, 25%] | 6.4% (6/94) [2.6%, 11%] | 1.57 (1) | 8 |
| gpt-6-astra low | 52% (65/124) [46%, 62%] | 8.1% (10/124) [4.9%, 14%] | 27% (33/124) [16%, 34%] | 13% (16/124) [11%, 15%] | 1.63 (1) | 7 |
| gpt-6-astra medium | 53% (42/80) [50%, 55%] | 6.3% (5/80) [5.0%, 7.5%] | 18% (14/80) [15%, 20%] | 24% (19/80) [23%, 25%] | 0.90 (1) | 7 |
| gpt-6-astra off | 59% (39/66) [56%, 67%] | 14% (9/66) [11%, 17%] | 12% (8/66) [0%, 17%] | 15% (10/66) [10%, 22%] | 1.36 (1) | 5 |

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
| claude-opus-5-5 high | 57% (614/1075) [53%, 61%] | 9.3% (100/1075) [7.8%, 11%] | 23% (247/1075) [19%, 28%] | 11% (114/1075) [8.0%, 14%] | 1.75 (1) | 7 |
| claude-opus-5-5 low | 55% (498/910) [49%, 60%] | 9.8% (89/910) [7.9%, 12%] | 22% (198/910) [18%, 26%] | 14% (125/910) [9.9%, 18%] | 1.58 (1) | 6 |
| claude-opus-5-5 max | 63% (517/823) [58%, 67%] | 11% (88/823) [8.7%, 13%] | 14% (115/823) [9.7%, 19%] | 13% (103/823) [9.6%, 16%] | 1.82 (1) | 7 |
| claude-opus-5-5 medium | 58% (962/1673) [55%, 60%] | 9.7% (163/1673) [8.5%, 11%] | 21% (355/1673) [19%, 24%] | 12% (193/1673) [9.5%, 13%] | 1.69 (1) | 7 |
| claude-opus-5-5 off | 53% (232/441) [48%, 57%] | 9.5% (42/441) [6.7%, 12%] | 24% (105/441) [20%, 29%] | 14% (62/441) [10%, 18%] | 1.58 (1) | 7 |
| claude-opus-5-5 xhigh | 59% (737/1247) [54%, 63%] | 9.9% (123/1247) [8.3%, 12%] | 15% (193/1247) [12%, 19%] | 16% (194/1247) [13%, 18%] | 1.64 (1) | 6 |

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
| gpt-6.1-terra high | 55% (128/234) [50%, 60%] | 8.1% (19/234) [4.4%, 14%] | 24% (57/234) [13%, 34%] | 13% (30/234) [4.5%, 23%] | 1.41 (1) | 6 |
| gpt-6.1-terra low | 51% (111/219) [41%, 58%] | 11% (24/219) [6.9%, 16%] | 17% (38/219) [8.9%, 27%] | 21% (46/219) [13%, 28%] | 1.68 (1) | 8 |
| gpt-6.1-terra max | 71% (129/182) [63%, 77%] | 9.3% (17/182) [7.7%, 11%] | 4.9% (9/182) [0.5%, 14%] | 15% (27/182) [7.8%, 22%] | 1.78 (1) | 6 |
| gpt-6.1-terra medium | 52% (158/306) [42%, 60%] | 10% (31/306) [6.2%, 14%] | 22% (67/306) [15%, 29%] | 16% (50/306) [10%, 23%] | 1.59 (1) | 6 |
| gpt-6.1-terra off | 53% (125/237) [47%, 60%] | 11% (27/237) [8.4%, 14%] | 28% (66/237) [18%, 35%] | 8.0% (19/237) [4.3%, 13%] | 1.53 (1) | 6 |
| gpt-6.1-terra xhigh | 48% (137/286) [40%, 57%] | 10% (29/286) [7.6%, 13%] | 31% (90/286) [16%, 45%] | 10% (30/286) [2.6%, 20%] | 1.44 (1) | 6 |

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
| claude-haiku-4-5-20251001 high | 66% (126/190) [59%, 75%] | 15% (71/477) [11%, 19%] | 39% (93/241) [34%, 44%] | 22% (96/437) [18%, 27%] | 15% (68/463) [11%, 19%] | 23% (84/369) [18%, 28%] | 34% (59/172) [27%, 44%] |
| claude-haiku-4-5-20251001 low | 72% (175/244) [64%, 79%] | 17% (93/532) [14%, 22%] | 36% (132/370) [31%, 41%] | 23% (136/582) [20%, 28%] | 14% (87/628) [11%, 17%] | 19% (95/503) [15%, 23%] | 35% (68/195) [28%, 44%] |
| claude-haiku-4-5-20251001 medium | 64% (561/880) [59%, 68%] | 15% (327/2173) [13%, 17%] | 35% (490/1393) [33%, 38%] | 21% (432/2093) [18%, 23%] | 14% (315/2327) [12%, 15%] | 19% (317/1702) [17%, 21%] | 36% (316/867) [33%, 41%] |
| claude-haiku-4-5-20251001 minimal | 66% (163/248) [61%, 71%] | 14% (83/583) [11%, 18%] | 35% (116/335) [29%, 40%] | 20% (106/535) [15%, 25%] | 13% (68/516) [10%, 17%] | 20% (90/441) [17%, 24%] | 30% (79/263) [25%, 35%] |
| claude-haiku-4-5-20251001 off | 69% (102/147) [62%, 78%] | 30% (81/270) [25%, 37%] | 28% (86/311) [22%, 35%] | 20% (67/334) [15%, 26%] | 19% (62/330) [15%, 24%] | 22% (61/275) [16%, 29%] | 30% (47/157) [22%, 39%] |
| claude-haiku-5-5 high | 58% (258/444) [52%, 65%] | 32% (231/723) [29%, 36%] | 30% (223/748) [27%, 32%] | 23% (208/905) [20%, 26%] | 14% (168/1220) [12%, 16%] | 25% (178/708) [22%, 29%] | 52% (170/330) [46%, 57%] |
| claude-haiku-5-5 low | 72% (448/619) [68%, 77%] | 25% (344/1360) [23%, 29%] | 34% (367/1085) [32%, 36%] | 24% (333/1374) [22%, 27%] | 13% (222/1759) [11%, 14%] | 23% (244/1078) [20%, 26%] | 40% (233/581) [36%, 44%] |
| claude-haiku-5-5 max | 67% (18/27) [56%, 93%] | 32% (22/69) [27%, 43%] | 21% (19/92) [14%, 32%] | 17% (15/89) [8.3%, 26%] | 11% (10/94) [7.0%, 15%] | 25% (17/69) [13%, 39%] | 45% (13/29) [28%, 78%] |
| claude-haiku-5-5 medium | 65% (707/1089) [62%, 68%] | 29% (659/2292) [26%, 31%] | 32% (654/2064) [30%, 33%] | 25% (701/2751) [24%, 27%] | 12% (404/3347) [11%, 13%] | 25% (490/1983) [23%, 27%] | 49% (486/994) [45%, 52%] |
| claude-haiku-5-5 off | 77% (1431/1857) [75%, 79%] | 31% (1132/3634) [29%, 33%] | 41% (1243/3033) [39%, 43%] | 30% (1157/3843) [28%, 32%] | 7.8% (452/5785) [7.1%, 8.6%] | 18% (698/3897) [17%, 19%] | 24% (568/2386) [22%, 26%] |
| claude-haiku-5-5 xhigh | 55% (113/206) [48%, 63%] | 34% (101/293) [29%, 41%] | 25% (94/369) [23%, 29%] | 18% (80/435) [15%, 23%] | 14% (76/547) [11%, 17%] | 27% (86/322) [23%, 32%] | 56% (70/125) [50%, 63%] |
| claude-opus-5-5 high | 48% (70/147) [40%, 57%] | 30% (60/203) [22%, 40%] | 30% (65/220) [26%, 33%] | 13% (39/301) [8.4%, 18%] | 11% (38/357) [7.8%, 13%] | 34% (53/155) [25%, 44%] | 44% (53/121) [35%, 54%] |
| claude-opus-5-5 low | 52% (98/190) [44%, 61%] | 18% (59/325) [13%, 23%] | 32% (72/223) [28%, 36%] | 15% (54/370) [10%, 20%] | 14% (48/345) [11%, 17%] | 27% (46/168) [20%, 37%] | 46% (50/109) [38%, 57%] |
| claude-opus-5-5 max | 42% (95/224) [37%, 50%] | 32% (85/264) [26%, 40%] | 22% (88/401) [19%, 25%] | 18% (77/439) [14%, 21%] | 14% (68/479) [12%, 17%] | 37% (94/256) [29%, 46%] | 28% (55/194) [23%, 34%] |
| claude-opus-5-5 medium | 54% (522/960) [51%, 58%] | 32% (507/1604) [29%, 35%] | 26% (439/1683) [24%, 28%] | 18% (461/2570) [16%, 19%] | 13% (323/2488) [12%, 14%] | 33% (417/1265) [30%, 36%] | 38% (331/873) [35%, 41%] |
| claude-opus-5-5 off | 49% (134/273) [44%, 55%] | 16% (90/563) [12%, 21%] | 30% (125/416) [27%, 34%] | 14% (92/646) [12%, 17%] | 13% (77/597) [10%, 16%] | 40% (111/277) [34%, 47%] | 54% (87/161) [47%, 62%] |
| claude-opus-5-5 xhigh | 51% (234/458) [46%, 57%] | 35% (220/628) [30%, 41%] | 26% (207/793) [23%, 29%] | 18% (179/975) [16%, 21%] | 11% (125/1175) [8.9%, 12%] | 34% (182/543) [29%, 39%] | 35% (128/362) [31%, 40%] |
| claude-sonnet-5-5 high | 64% (133/207) [57%, 72%] | 31% (106/339) [26%, 37%] | 25% (105/425) [22%, 28%] | 22% (103/479) [18%, 26%] | 9.6% (56/581) [7.0%, 13%] | 33% (87/264) [26%, 42%] | 45% (76/168) [40%, 53%] |
| claude-sonnet-5-5 low | 74% (118/159) [68%, 82%] | 23% (102/445) [18%, 28%] | 29% (102/355) [26%, 32%] | 20% (86/431) [15%, 26%] | 6.1% (33/544) [4.3%, 8.2%] | 31% (86/275) [26%, 38%] | 31% (61/200) [24%, 38%] |
| claude-sonnet-5-5 max | 57% (84/148) [49%, 68%] | 31% (79/251) [25%, 40%] | 27% (87/317) [23%, 31%] | 14% (49/344) [10%, 18%] | 15% (58/396) [12%, 17%] | 40% (63/159) [32%, 50%] | 40% (39/97) [31%, 51%] |
| claude-sonnet-5-5 medium | 64% (537/841) [60%, 68%] | 26% (452/1747) [23%, 29%] | 27% (440/1658) [25%, 28%] | 21% (464/2254) [19%, 23%] | 7.7% (219/2846) [6.8%, 8.6%] | 30% (393/1297) [27%, 34%] | 33% (314/945) [30%, 37%] |
| claude-sonnet-5-5 off | 65% (142/218) [59%, 72%] | 25% (110/438) [20%, 31%] | 27% (104/388) [24%, 30%] | 24% (123/508) [20%, 29%] | 7.0% (47/673) [5.0%, 9.1%] | 29% (99/337) [24%, 35%] | 37% (70/189) [28%, 47%] |
| claude-sonnet-5-5 xhigh | 57% (152/267) [50%, 67%] | 40% (165/412) [34%, 47%] | 24% (133/550) [21%, 28%] | 22% (159/729) [18%, 26%] | 10% (82/784) [8.4%, 13%] | 26% (107/405) [21%, 33%] | 38% (107/280) [33%, 44%] |
| gpt-5.6-terra high | 63% (26/41) [52%, 77%] | 10% (11/110) [5.0%, 17%] | 33% (21/63) [26%, 43%] | 17% (19/115) [12%, 20%] | 11% (11/102) [5.3%, 14%] | 14% (12/86) [7.1%, 23%] | 82% (14/17) [71%, 100%] |
| gpt-5.6-terra low | 65% (26/40) [58%, 78%] | 22% (11/51) [4.3%, 45%] | 34% (26/76) [27%, 44%] | 16% (18/115) [11%, 22%] | 6.0% (6/100) [2.4%, 9.3%] | 11% (12/110) [3.0%, 26%] | 56% (18/32) [46%, 78%] |
| gpt-5.6-terra max | 60% (25/42) [42%, 78%] | 44% (25/57) [32%, 60%] | 29% (23/80) [22%, 40%] | 23% (21/92) [11%, 39%] | 14% (23/167) [9.0%, 20%] | 29% (16/55) [13%, 52%] | 45% (13/29) [26%, 79%] |
| gpt-5.6-terra medium | 60% (408/677) [57%, 64%] | 14% (219/1539) [12%, 17%] | 34% (302/876) [32%, 37%] | 20% (249/1263) [17%, 23%] | 9.3% (167/1792) [8.0%, 11%] | 13% (182/1409) [11%, 15%] | 67% (264/394) [61%, 74%] |
| gpt-5.6-terra xhigh | 60% (34/57) [41%, 75%] | 22% (20/93) [14%, 31%] | 27% (28/104) [20%, 37%] | 20% (26/128) [12%, 27%] | 11% (17/159) [7.1%, 14%] | 22% (26/117) [17%, 33%] | 65% (24/37) [53%, 91%] |
| gpt-6-astra high | 43% (233/536) [40%, 48%] | 38% (183/485) [33%, 42%] | 31% (187/612) [28%, 33%] | 12% (106/880) [9.6%, 15%] | 11% (112/983) [9.8%, 13%] | 32% (165/518) [28%, 37%] | 37% (145/388) [33%, 42%] |
| gpt-6-astra low | 47% (145/309) [42%, 53%] | 31% (128/418) [25%, 36%] | 29% (150/514) [26%, 33%] | 11% (76/716) [7.9%, 13%] | 11% (82/768) [8.4%, 13%] | 35% (119/343) [29%, 42%] | 40% (103/260) [35%, 45%] |
| gpt-6-astra medium | 48% (488/1010) [45%, 52%] | 37% (525/1415) [34%, 40%] | 27% (478/1739) [26%, 29%] | 13% (319/2461) [11%, 15%] | 11% (276/2545) [9.9%, 12%] | 32% (371/1157) [29%, 36%] | 37% (300/810) [35%, 40%] |
| gpt-6-astra off | 46% (182/400) [42%, 50%] | 26% (152/591) [21%, 31%] | 31% (156/500) [28%, 35%] | 7.4% (70/941) [5.7%, 9.2%] | 10% (81/772) [8.2%, 13%] | 37% (137/375) [30%, 44%] | 41% (95/231) [36%, 47%] |
| gpt-6-luna high | 66% (310/468) [62%, 70%] | 21% (219/1044) [19%, 23%] | 32% (252/787) [29%, 35%] | 33% (296/902) [29%, 38%] | 5.7% (86/1500) [4.6%, 6.9%] | 26% (184/702) [22%, 32%] | 47% (188/402) [42%, 52%] |
| gpt-6-luna low | 70% (199/283) [66%, 76%] | 50% (205/409) [44%, 58%] | 31% (183/589) [29%, 34%] | 26% (176/678) [22%, 30%] | 32% (191/594) [29%, 36%] | 20% (119/588) [16%, 25%] | 39% (97/247) [34%, 45%] |
| gpt-6-luna max | 64% (23/36) [54%, 80%] | 26% (26/99) [17%, 45%] | 27% (23/84) [21%, 36%] | 28% (25/90) [23%, 33%] | 13% (12/91) [9.6%, 17%] | 24% (17/70) [15%, 34%] | 69% (18/26) [54%, 86%] |
| gpt-6-luna medium | 68% (696/1031) [64%, 71%] | 36% (640/1767) [33%, 39%] | 34% (590/1754) [32%, 35%] | 29% (634/2215) [27%, 31%] | 15% (426/2769) [13%, 17%] | 21% (432/2050) [19%, 23%] | 37% (376/1004) [34%, 41%] |
| gpt-6-luna off | 66% (273/415) [61%, 71%] | 50% (294/585) [45%, 55%] | 30% (228/771) [27%, 32%] | 25% (213/841) [23%, 28%] | 32% (289/898) [29%, 35%] | 26% (173/663) [22%, 31%] | 36% (158/441) [31%, 41%] |
| gpt-6-luna xhigh | 57% (26/46) [47%, 76%] | 29% (33/113) [19%, 43%] | 25% (32/128) [19%, 31%] | 22% (35/160) [12%, 35%] | 11% (29/259) [8.3%, 15%] | 34% (32/95) [25%, 44%] | 65% (24/37) [51%, 85%] |
| gpt-6.1-sol high | 48% (30/63) [43%, 55%] | 37% (41/110) [30%, 47%] | 34% (41/122) [29%, 38%] | 18% (28/152) [7.5%, 33%] | 12% (23/194) [7.3%, 17%] | 36% (33/92) [28%, 47%] | 33% (28/85) [25%, 42%] |
| gpt-6.1-sol low | 55% (36/66) [46%, 65%] | 26% (31/118) [19%, 35%] | 28% (33/118) [23%, 34%] | 14% (19/132) [8.3%, 22%] | 9.3% (17/183) [5.2%, 13%] | 27% (26/95) [17%, 38%] | 38% (25/65) [28%, 52%] |
| gpt-6.1-sol max | 51% (148/293) [46%, 56%] | 42% (124/293) [36%, 49%] | 29% (140/483) [26%, 33%] | 16% (78/486) [13%, 20%] | 13% (87/686) [10%, 15%] | 39% (101/261) [32%, 48%] | 33% (74/225) [28%, 38%] |
| gpt-6.1-sol medium | 50% (374/745) [47%, 54%] | 35% (373/1071) [31%, 39%] | 28% (360/1265) [27%, 30%] | 14% (250/1738) [13%, 16%] | 12% (234/1881) [11%, 14%] | 34% (308/907) [30%, 38%] | 39% (263/683) [36%, 41%] |
| gpt-6.1-sol xhigh | 41% (37/90) [33%, 55%] | 49% (59/121) [38%, 62%] | 27% (37/135) [22%, 32%] | 25% (59/239) [20%, 29%] | 15% (33/223) [12%, 18%] | 26% (29/112) [19%, 34%] | 31% (22/71) [23%, 41%] |
| gpt-6.1-terra high | 41% (173/421) [36%, 47%] | 30% (156/521) [25%, 36%] | 28% (141/498) [25%, 31%] | 5.7% (43/750) [3.8%, 7.9%] | 8.7% (62/710) [6.8%, 11%] | 34% (125/372) [28%, 41%] | 43% (96/225) [37%, 50%] |
| gpt-6.1-terra low | 45% (336/742) [41%, 50%] | 32% (308/951) [29%, 36%] | 29% (269/914) [27%, 32%] | 3.0% (50/1666) [2.2%, 3.9%] | 7.0% (125/1782) [5.9%, 8.1%] | 33% (224/676) [29%, 38%] | 42% (214/504) [39%, 47%] |
| gpt-6.1-terra max | 43% (223/524) [38%, 48%] | 40% (227/566) [36%, 45%] | 24% (190/791) [22%, 26%] | 17% (189/1088) [15%, 20%] | 14% (150/1099) [12%, 16%] | 41% (189/458) [35%, 48%] | 36% (112/312) [31%, 41%] |
| gpt-6.1-terra medium | 45% (255/568) [40%, 50%] | 34% (229/677) [29%, 39%] | 30% (236/774) [28%, 33%] | 6.2% (76/1234) [4.8%, 7.6%] | 8.4% (109/1293) [7.0%, 9.9%] | 34% (174/515) [29%, 40%] | 42% (156/375) [38%, 47%] |
| gpt-6.1-terra off | 45% (134/296) [41%, 50%] | 44% (148/336) [38%, 50%] | 29% (121/421) [26%, 32%] | 4.4% (37/835) [2.9%, 5.9%] | 7.9% (57/726) [6.0%, 9.8%] | 42% (115/275) [35%, 50%] | 39% (85/218) [33%, 47%] |
| gpt-6.1-terra xhigh | 42% (196/469) [38%, 47%] | 42% (200/480) [36%, 48%] | 30% (183/619) [27%, 32%] | 9.3% (97/1043) [7.4%, 12%] | 11% (105/982) [8.9%, 13%] | 32% (149/465) [26%, 38%] | 44% (121/272) [40%, 49%] |

### Astra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6-astra high | 33% (6/18) [19%, 80%] | 64% (7/11) [0%, 86%] | 38% (12/32) [31%, 44%] | 28% (11/39) [22%, 50%] | 17% (5/29) [5.3%, 22%] | 46% (6/13) [25%, 100%] | 36% (9/25) [27%, 50%] |
| gpt-6-astra low | 53% (9/17) [50%, 59%] | 38% (10/26) [21%, 47%] | 40% (10/25) [29%, 67%] | 8.8% (6/68) [5.8%, 12%] | 12% (6/50) [9.5%, 19%] | 18% (6/34) [5.3%, 33%] | 38% (6/16) [30%, 50%] |
| gpt-6-astra medium | 90% (9/10) [80%, 100%] | 43% (10/23) [36%, 56%] | 33% (9/27) [25%, 40%] | 6.5% (3/46) [3.6%, 11%] | 13% (3/23) [7.7%, 20%] | 40% (2/5) [25%, 100%] | 23% (3/13) [20%, 33%] |
| gpt-6-astra off | 60% (9/15) [50%, 80%] | 58% (7/12) [50%, 100%] | 38% (5/13) [33%, 100%] | 13% (4/31) [0%, 23%] | 7.7% (2/26) [0%, 13%] | 30% (3/10) [29%, 33%] | 31% (4/13) [29%, 33%] |

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
| claude-opus-5-5 high | 49% (89/181) [43%, 59%] | 32% (93/290) [27%, 38%] | 25% (64/258) [20%, 30%] | 17% (66/398) [13%, 21%] | 13% (57/439) [11%, 15%] | 29% (65/228) [20%, 41%] | 46% (69/150) [39%, 57%] |
| claude-opus-5-5 low | 55% (89/161) [51%, 62%] | 20% (53/262) [15%, 28%] | 27% (58/216) [22%, 33%] | 16% (52/327) [12%, 20%] | 12% (43/345) [9.8%, 15%] | 36% (62/174) [27%, 48%] | 46% (56/123) [36%, 56%] |
| claude-opus-5-5 max | 35% (74/210) [29%, 43%] | 35% (73/207) [28%, 45%] | 28% (63/227) [25%, 30%] | 24% (63/265) [20%, 27%] | 15% (42/272) [12%, 20%] | 39% (68/174) [30%, 51%] | 36% (43/120) [29%, 45%] |
| claude-opus-5-5 medium | 50% (153/303) [45%, 57%] | 29% (133/454) [26%, 33%] | 28% (107/389) [24%, 32%] | 16% (105/660) [13%, 19%] | 13% (87/670) [11%, 15%] | 38% (125/326) [32%, 46%] | 49% (84/171) [42%, 57%] |
| claude-opus-5-5 off | 55% (35/64) [41%, 76%] | 31% (38/124) [25%, 38%] | 33% (29/88) [29%, 38%] | 14% (20/139) [9.2%, 21%] | 14% (28/206) [9.5%, 19%] | 28% (28/101) [17%, 42%] | 46% (26/57) [33%, 60%] |
| claude-opus-5-5 xhigh | 47% (117/249) [42%, 53%] | 39% (116/297) [34%, 46%] | 26% (86/328) [24%, 29%] | 15% (72/469) [12%, 20%] | 14% (70/498) [11%, 17%] | 37% (89/241) [29%, 46%] | 32% (65/202) [27%, 38%] |

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
| gpt-6.1-terra high | 54% (28/52) [47%, 61%] | 40% (21/52) [30%, 56%] | 29% (19/65) [20%, 38%] | 5.9% (8/136) [2.7%, 9.4%] | 6.9% (4/58) [1.5%, 15%] | 43% (12/28) [31%, 71%] | 44% (17/39) [39%, 52%] |
| gpt-6.1-terra low | 37% (30/81) [33%, 48%] | 25% (15/60) [11%, 40%] | 24% (11/46) [15%, 34%] | 0% (0/115) [0%, 0%] | 3.8% (3/79) [0%, 11%] | 47% (14/30) [28%, 88%] | 37% (13/35) [26%, 52%] |
| gpt-6.1-terra max | 38% (17/45) [26%, 50%] | 48% (14/29) [38%, 100%] | 25% (18/73) [14%, 38%] | 20% (13/64) [7.5%, 31%] | 15% (16/109) [13%, 18%] | 30% (17/56) [17%, 46%] | 36% (9/25) [25%, 53%] |
| gpt-6.1-terra medium | 44% (32/72) [36%, 58%] | 37% (28/76) [25%, 48%] | 32% (25/77) [26%, 42%] | 3.2% (3/95) [0%, 6.8%] | 6.1% (7/114) [1.4%, 10%] | 23% (20/86) [16%, 34%] | 40% (16/40) [31%, 59%] |
| gpt-6.1-terra off | 37% (22/59) [29%, 49%] | 37% (19/52) [24%, 57%] | 24% (17/70) [17%, 33%] | 6.8% (7/103) [2.6%, 11%] | 9.4% (8/85) [3.1%, 17%] | 39% (13/33) [32%, 55%] | 45% (10/22) [29%, 83%] |
| gpt-6.1-terra xhigh | 44% (26/59) [35%, 65%] | 47% (20/43) [25%, 74%] | 33% (19/57) [28%, 37%] | 8.5% (10/118) [5.5%, 13%] | 8.2% (8/97) [3.3%, 11%] | 34% (15/44) [22%, 51%] | 57% (17/30) [44%, 76%] |

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
| claude-haiku-4-5-20251001 high | 16% (18/115) [9.4%, 24%] | 2.3% (4/172) [0.5%, 5.2%] | 15% (19/127) [9.3%, 22%] | 7.3% (15/206) [3.6%, 12%] | 3.3% (9/271) [1.3%, 6.0%] | 4.6% (7/151) [0%, 11%] | 22% (19/86) [14%, 37%] |
| claude-haiku-4-5-20251001 low | 20% (19/95) [11%, 30%] | 2.2% (5/223) [0.5%, 4.5%] | 18% (23/125) [12%, 25%] | 4.9% (13/268) [2.1%, 8.7%] | 3.6% (11/304) [1.4%, 6.7%] | 3.0% (6/201) [1.0%, 5.7%] | 35% (38/110) [26%, 45%] |
| claude-haiku-4-5-20251001 medium | 16% (75/473) [12%, 20%] | 1.2% (10/821) [0.5%, 2.2%] | 16% (81/503) [13%, 20%] | 3.6% (34/932) [2.5%, 4.9%] | 5.4% (56/1034) [4.0%, 6.9%] | 2.4% (16/679) [1.3%, 3.6%] | 34% (90/266) [28%, 41%] |
| claude-haiku-4-5-20251001 minimal | 9.2% (14/153) [5.0%, 15%] | 2.2% (5/226) [0.5%, 4.7%] | 12% (17/139) [7.5%, 19%] | 4.3% (11/257) [2.3%, 7.0%] | 4.1% (12/290) [1.4%, 7.8%] | 4.8% (9/186) [2.2%, 8.4%] | 33% (19/58) [20%, 51%] |
| claude-haiku-4-5-20251001 off | 9.8% (10/102) [3.8%, 19%] | 1.6% (2/122) [0%, 4.5%] | 13% (11/84) [6.2%, 21%] | 6.3% (9/143) [3.1%, 9.9%] | 4.4% (10/229) [2.1%, 6.7%] | 5.2% (6/115) [1.4%, 12%] | 19% (14/73) [13%, 29%] |
| claude-haiku-5-5 high | 37% (76/203) [32%, 44%] | 8.1% (18/221) [4.6%, 12%] | 26% (39/152) [20%, 32%] | 11% (28/251) [7.7%, 15%] | 11% (38/338) [7.7%, 15%] | 9.8% (19/193) [5.7%, 15%] | 43% (36/84) [33%, 55%] |
| claude-haiku-5-5 low | 31% (100/325) [25%, 37%] | 6.6% (30/452) [4.3%, 9.1%] | 24% (65/269) [19%, 29%] | 8.5% (45/531) [6.1%, 11%] | 6.1% (37/605) [4.2%, 8.4%] | 5.6% (22/393) [3.6%, 7.9%] | 26% (49/185) [20%, 34%] |
| claude-haiku-5-5 max | 14% (2/14) [0%, 33%] | 13% (3/23) [0%, 29%] | 17% (3/18) [11%, 23%] | 14% (4/29) [3.3%, 26%] | 8.7% (2/23) [0%, 21%] | 28% (5/18) [17%, 50%] | 56% (5/9) [25%, 86%] |
| claude-haiku-5-5 medium | 24% (146/602) [20%, 29%] | 8.6% (76/879) [6.7%, 11%] | 25% (133/522) [22%, 29%] | 9.1% (88/964) [7.3%, 11%] | 7.1% (75/1051) [5.6%, 8.7%] | 13% (89/687) [10%, 15%] | 33% (97/291) [28%, 39%] |
| claude-haiku-5-5 off | 27% (368/1377) [24%, 29%] | 7.2% (125/1743) [5.8%, 8.5%] | 26% (253/962) [23%, 29%] | 8.5% (126/1487) [7.0%, 10%] | 4.2% (79/1895) [3.2%, 5.2%] | 4.2% (53/1261) [3.1%, 5.4%] | 15% (140/945) [12%, 17%] |
| claude-haiku-5-5 xhigh | 30% (21/70) [20%, 43%] | 13% (14/108) [6.9%, 21%] | 29% (30/102) [23%, 37%] | 5.0% (9/181) [2.1%, 8.1%] | 12% (20/167) [7.3%, 17%] | 13% (16/119) [7.8%, 20%] | 58% (26/45) [47%, 71%] |
| claude-opus-5-5 high | 12% (8/65) [5.6%, 21%] | 8.3% (3/36) [2.0%, 17%] | 16% (9/57) [9.2%, 24%] | 4.8% (5/104) [1.3%, 11%] | 8.5% (9/106) [4.1%, 14%] | 9.8% (6/61) [3.3%, 19%] | 34% (14/41) [20%, 53%] |
| claude-opus-5-5 low | 33% (11/33) [17%, 61%] | 3.8% (3/78) [0%, 7.8%] | 32% (20/62) [21%, 43%] | 5.2% (5/96) [0%, 12%] | 10% (12/119) [5.9%, 15%] | 9.4% (8/85) [3.8%, 17%] | 25% (8/32) [10%, 48%] |
| claude-opus-5-5 max | 28% (19/68) [17%, 46%] | 5.3% (7/132) [2.4%, 8.5%] | 15% (17/110) [12%, 20%] | 5.2% (8/155) [2.0%, 9.1%] | 8.9% (17/190) [5.0%, 14%] | 19% (20/104) [10%, 33%] | 47% (18/38) [36%, 63%] |
| claude-opus-5-5 medium | 29% (100/347) [24%, 35%] | 6.3% (42/664) [4.5%, 8.5%] | 20% (72/362) [16%, 24%] | 6.2% (44/708) [4.4%, 8.2%] | 7.9% (63/798) [6.3%, 9.6%] | 12% (61/530) [8.8%, 15%] | 37% (84/229) [31%, 43%] |
| claude-opus-5-5 off | 32% (31/97) [23%, 44%] | 2.3% (4/177) [0%, 5.4%] | 21% (26/123) [15%, 29%] | 5.4% (11/204) [2.7%, 8.4%] | 7.5% (18/239) [4.4%, 11%] | 7.8% (14/179) [3.9%, 12%] | 42% (33/79) [29%, 58%] |
| claude-opus-5-5 xhigh | 25% (60/237) [20%, 31%] | 2.4% (7/289) [0.9%, 4.5%] | 16% (39/237) [13%, 21%] | 6.8% (19/280) [3.7%, 11%] | 9.7% (45/463) [7.1%, 13%] | 12% (29/248) [8.3%, 16%] | 34% (40/116) [28%, 43%] |
| claude-sonnet-5-5 high | 25% (20/79) [17%, 35%] | 3.6% (5/139) [0.6%, 8.0%] | 10% (13/128) [5.7%, 16%] | 6.2% (10/161) [2.8%, 10%] | 4.1% (9/218) [1.7%, 7.5%] | 6.6% (6/91) [2.1%, 13%] | 31% (12/39) [19%, 50%] |
| claude-sonnet-5-5 low | 32% (30/95) [21%, 46%] | 0.5% (1/201) [0%, 1.9%] | 8.4% (13/155) [4.7%, 12%] | 3.9% (8/206) [1.1%, 7.8%] | 2.0% (5/249) [0.7%, 3.6%] | 1.8% (3/171) [0%, 3.7%] | 24% (22/90) [16%, 33%] |
| claude-sonnet-5-5 max | 23% (15/64) [11%, 44%] | 3.7% (3/81) [0%, 8.4%] | 20% (17/85) [13%, 30%] | 3.1% (3/97) [0%, 7.9%] | 4.0% (5/124) [0.8%, 7.8%] | 27% (18/67) [18%, 38%] | 60% (12/20) [36%, 100%] |
| claude-sonnet-5-5 medium | 34% (154/459) [29%, 39%] | 1.7% (13/778) [0.7%, 2.8%] | 14% (76/530) [11%, 17%] | 3.6% (29/813) [2.2%, 5.3%] | 2.9% (31/1069) [2.0%, 4.0%] | 5.1% (37/724) [3.7%, 6.7%] | 21% (75/349) [17%, 26%] |
| claude-sonnet-5-5 off | 24% (24/99) [18%, 32%] | 1.1% (2/184) [0%, 2.9%] | 8.6% (12/139) [4.9%, 14%] | 8.2% (24/292) [4.3%, 13%] | 3.6% (10/281) [1.4%, 6.0%] | 4.5% (9/201) [1.9%, 7.8%] | 23% (23/100) [16%, 32%] |
| claude-sonnet-5-5 xhigh | 24% (40/167) [18%, 32%] | 3.9% (9/230) [1.5%, 7.0%] | 18% (36/197) [15%, 22%] | 4.7% (18/383) [2.6%, 7.1%] | 5.7% (18/315) [3.7%, 8.1%] | 11% (24/215) [7.9%, 15%] | 28% (34/122) [22%, 35%] |
| gpt-5.6-terra high | 57% (8/14) [26%, 100%] | 0% (0/46) [0%, 0%] | 32% (6/19) [10%, 43%] | 0% (0/38) [0%, 0%] | 2.0% (1/49) [0%, 7.1%] | 9.4% (3/32) [0%, 22%] | 38% (3/8) [0%, 100%] |
| gpt-5.6-terra low | 40% (4/10) [0%, 80%] | 6.9% (2/29) [0%, 29%] | 26% (6/23) [14%, 47%] | 1.9% (1/54) [0%, 4.9%] | 2.0% (1/50) [0%, 9.1%] | 3.6% (1/28) [0%, 7.0%] | 57% (4/7) [40%, 100%] |
| gpt-5.6-terra max | 36% (4/11) [33%, 50%] | 12% (3/26) [0%, 38%] | 17% (3/18) [0%, 50%] | 11% (3/28) [3.0%, 22%] | 13% (3/23) [4.5%, 25%] | 10% (1/10) [0%, 33%] | 64% (7/11) [45%, 100%] |
| gpt-5.6-terra medium | 31% (79/252) [26%, 37%] | 2.3% (11/473) [1.1%, 3.7%] | 23% (86/378) [19%, 27%] | 5.8% (28/479) [3.8%, 8.4%] | 3.0% (18/606) [1.7%, 4.4%] | 4.7% (20/430) [2.8%, 6.9%] | 57% (78/136) [48%, 68%] |
| gpt-5.6-terra xhigh | 33% (4/12) [7.7%, 75%] | 8.0% (2/25) [0%, 25%] | 33% (9/27) [22%, 57%] | 3.8% (1/26) [0%, 11%] | 6.3% (2/32) [0%, 19%] | 10% (2/20) [0%, 38%] | 80% (4/5) [75%, 100%] |
| gpt-6-astra high | 31% (51/163) [23%, 41%] | 5.5% (11/199) [2.8%, 8.6%] | 25% (48/191) [20%, 30%] | 2.3% (6/262) [0.7%, 4.4%] | 7.2% (21/293) [4.7%, 10%] | 23% (42/180) [18%, 31%] | 37% (40/109) [29%, 46%] |
| gpt-6-astra low | 30% (36/120) [21%, 40%] | 4.3% (7/163) [1.2%, 8.7%] | 27% (44/162) [22%, 33%] | 3.0% (7/237) [0.8%, 6.1%] | 5.4% (11/204) [2.8%, 8.6%] | 19% (28/148) [11%, 29%] | 41% (34/83) [31%, 54%] |
| gpt-6-astra medium | 35% (98/284) [28%, 42%] | 3.4% (21/617) [2.0%, 5.0%] | 24% (88/367) [21%, 27%] | 2.8% (18/647) [1.7%, 4.1%] | 8.3% (69/828) [6.7%, 10%] | 24% (102/424) [20%, 29%] | 41% (80/194) [36%, 48%] |
| gpt-6-astra off | 23% (29/124) [17%, 32%] | 1.8% (4/218) [0.4%, 3.6%] | 18% (27/152) [12%, 24%] | 2.2% (5/225) [0.4%, 4.3%] | 6.2% (17/273) [3.7%, 9.1%] | 19% (29/149) [13%, 27%] | 57% (45/79) [47%, 69%] |
| gpt-6-luna high | 33% (96/295) [28%, 38%] | 3.0% (10/334) [1.3%, 5.2%] | 16% (44/275) [12%, 20%] | 11% (30/279) [7.4%, 15%] | 2.1% (8/386) [0.7%, 3.8%] | 8.7% (18/207) [5.0%, 13%] | 42% (48/114) [34%, 51%] |
| gpt-6-luna low | 16% (37/229) [12%, 21%] | 7.6% (19/251) [4.6%, 12%] | 9.8% (17/174) [5.6%, 15%] | 8.8% (23/262) [5.4%, 13%] | 13% (35/272) [9.2%, 17%] | 8.9% (18/203) [5.0%, 13%] | 40% (38/94) [31%, 53%] |
| gpt-6-luna max | 33% (3/9) [11%, 63%] | 3.4% (1/29) [0%, 6.8%] | 18% (3/17) [0%, 25%] | 5.6% (1/18) [0%, 7.9%] | 11% (5/46) [3.7%, 30%] | 17% (6/36) [9.7%, 23%] | 60% (3/5) [50%, 67%] |
| gpt-6-luna medium | 20% (121/615) [16%, 23%] | 5.5% (51/922) [4.2%, 7.1%] | 11% (63/574) [8.7%, 13%] | 8.8% (76/859) [6.9%, 11%] | 6.2% (68/1103) [4.7%, 7.6%] | 4.0% (30/754) [2.7%, 5.4%] | 34% (115/338) [29%, 39%] |
| gpt-6-luna off | 10% (46/451) [7.5%, 13%] | 11% (49/463) [7.5%, 14%] | 9.1% (30/331) [6.5%, 12%] | 5.4% (21/387) [3.4%, 7.8%] | 9.5% (43/453) [6.9%, 13%] | 3.3% (9/274) [1.5%, 5.6%] | 39% (60/155) [31%, 48%] |
| gpt-6-luna xhigh | 29% (5/17) [10%, 100%] | 11% (2/19) [0%, 27%] | 16% (5/32) [5.9%, 29%] | 24% (11/45) [13%, 32%] | 7.1% (4/56) [2.3%, 11%] | 13% (5/38) [4.3%, 24%] | 60% (9/15) [35%, 89%] |
| gpt-6.1-sol high | 24% (10/41) [13%, 44%] | 0% (0/23) [0%, 0%] | 25% (9/36) [11%, 42%] | 3.6% (2/55) [0%, 5.6%] | 9.8% (6/61) [4.9%, 17%] | 16% (8/51) [7.3%, 33%] | 36% (10/28) [26%, 55%] |
| gpt-6.1-sol low | 64% (9/14) [42%, 89%] | 12% (5/42) [2.6%, 26%] | 8.6% (3/35) [2.9%, 15%] | 6.7% (3/45) [0%, 18%] | 11% (6/55) [7.1%, 13%] | 20% (7/35) [7.4%, 31%] | 70% (7/10) [44%, 89%] |
| gpt-6.1-sol max | 25% (26/106) [16%, 35%] | 4.9% (8/163) [2.0%, 8.7%] | 18% (28/159) [14%, 22%] | 3.8% (7/183) [0.9%, 8.2%] | 9.8% (22/224) [7.1%, 12%] | 25% (28/110) [17%, 35%] | 50% (18/36) [32%, 70%] |
| gpt-6.1-sol medium | 31% (60/191) [24%, 41%] | 5.0% (22/443) [3.0%, 7.2%] | 22% (63/289) [18%, 26%] | 3.5% (17/482) [1.9%, 5.5%] | 9.3% (56/605) [7.3%, 11%] | 20% (73/365) [16%, 26%] | 39% (67/172) [33%, 46%] |
| gpt-6.1-sol xhigh | 17% (4/24) [3.4%, 35%] | 0% (0/47) [0%, 0%] | 19% (7/36) [8.9%, 32%] | 1.2% (1/84) [0%, 3.3%] | 9.8% (4/41) [3.0%, 17%] | 23% (12/52) [15%, 34%] | 50% (8/16) [31%, 77%] |
| gpt-6.1-terra high | 44% (41/94) [34%, 54%] | 12% (19/158) [7.1%, 19%] | 28% (37/133) [23%, 33%] | 4.6% (10/219) [2.2%, 7.1%] | 7.3% (20/274) [4.6%, 10%] | 21% (26/125) [13%, 30%] | 51% (35/69) [38%, 67%] |
| gpt-6.1-terra low | 47% (117/250) [39%, 56%] | 5.2% (19/365) [2.9%, 7.8%] | 24% (75/311) [20%, 28%] | 1.3% (5/399) [0.3%, 2.6%] | 3.0% (14/465) [1.7%, 4.3%] | 21% (52/252) [16%, 26%] | 42% (70/167) [36%, 49%] |
| gpt-6.1-terra max | 20% (33/163) [14%, 28%] | 9.9% (22/223) [5.8%, 15%] | 20% (43/213) [16%, 25%] | 4.1% (10/242) [2.0%, 6.5%] | 7.1% (24/337) [4.3%, 10%] | 25% (46/182) [18%, 34%] | 34% (53/157) [27%, 43%] |
| gpt-6.1-terra medium | 41% (60/147) [33%, 50%] | 8.1% (19/235) [4.5%, 13%] | 22% (39/180) [15%, 28%] | 1.4% (4/287) [0.3%, 3.0%] | 2.8% (9/319) [1.2%, 4.8%] | 23% (42/179) [18%, 30%] | 40% (50/125) [30%, 52%] |
| gpt-6.1-terra off | 46% (38/82) [35%, 60%] | 12% (15/130) [5.6%, 18%] | 21% (21/101) [14%, 28%] | 0% (0/127) [0%, 0%] | 3.7% (6/162) [1.2%, 6.9%] | 21% (24/114) [14%, 30%] | 36% (30/84) [26%, 47%] |
| gpt-6.1-terra xhigh | 39% (52/132) [30%, 51%] | 7.4% (16/216) [3.7%, 12%] | 26% (46/174) [21%, 33%] | 5.3% (12/225) [2.4%, 9.0%] | 5.0% (13/261) [2.8%, 7.5%] | 29% (46/156) [21%, 40%] | 43% (41/96) [32%, 55%] |

### Astra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer |
|---|---|---|---|---|---|---|---|
| gpt-6-astra high | 67% (2/3) [0%, 100%] | 0% (0/13) [0%, 0%] | 40% (4/10) [25%, 67%] | 5.6% (1/18) [0%, 17%] | 0% (0/9) [0%, 0%] | 100% (1/1) [100%, 100%] | 33% (1/3) [0%, 100%] |
| gpt-6-astra low | 42% (5/12) [22%, 100%] | 7.1% (1/14) [0%, 20%] | 29% (2/7) [0%, 100%] | 0% (0/22) [0%, 0%] | 14% (1/7) [0%, 25%] | 100% (1/1) [100%, 100%] | 29% (2/7) [25%, 33%] |
| gpt-6-astra medium | 33% (1/3) [0%, 100%] | 0% (0/9) [0%, 0%] | – | 9.1% (1/11) [0%, 13%] | 50% (1/2) [50%, 50%] | – | – |
| gpt-6-astra off | 100% (1/1) [100%, 100%] | 14% (1/7) [0%, 33%] | 33% (2/6) [20%, 100%] | 0% (0/7) [0%, 0%] | – | 33% (1/3) [0%, 50%] | – |

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
| claude-opus-5-5 high | 39% (25/64) [29%, 57%] | 3.4% (4/116) [0.8%, 7.9%] | 20% (20/101) [15%, 25%] | 11% (15/139) [5.6%, 18%] | 9.6% (13/136) [4.7%, 15%] | 22% (19/85) [15%, 32%] | 48% (15/31) [30%, 68%] |
| claude-opus-5-5 low | 39% (21/54) [26%, 54%] | 3.2% (3/95) [0%, 7.8%] | 28% (22/80) [21%, 35%] | 5.3% (7/132) [1.7%, 9.1%] | 7.1% (9/127) [3.5%, 12%] | 9.4% (8/85) [2.7%, 16%] | 38% (15/40) [21%, 53%] |
| claude-opus-5-5 max | 22% (17/78) [16%, 31%] | 4.5% (3/66) [0%, 11%] | 18% (17/93) [14%, 23%] | 12% (14/116) [5.6%, 21%] | 11% (12/112) [5.2%, 20%] | 11% (8/70) [4.8%, 22%] | 33% (20/60) [26%, 43%] |
| claude-opus-5-5 medium | 27% (35/132) [19%, 37%] | 5.7% (10/175) [2.5%, 11%] | 21% (30/144) [15%, 27%] | 7.4% (14/190) [3.9%, 11%] | 9.4% (24/255) [6.6%, 13%] | 15% (25/165) [11%, 20%] | 45% (30/66) [33%, 62%] |
| claude-opus-5-5 off | 44% (8/18) [29%, 80%] | 0% (0/46) [0%, 0%] | 18% (5/28) [12%, 23%] | 2.9% (2/69) [0%, 10%] | 2.9% (2/68) [0%, 9.1%] | 3.3% (1/30) [0%, 13%] | 43% (10/23) [29%, 69%] |
| claude-opus-5-5 xhigh | 24% (26/107) [15%, 36%] | 7.0% (10/143) [2.7%, 13%] | 22% (24/111) [16%, 27%] | 8.5% (10/117) [3.6%, 16%] | 7.4% (12/163) [3.3%, 12%] | 23% (24/104) [17%, 31%] | 34% (16/47) [21%, 55%] |

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
| gpt-6.1-terra high | 33% (2/6) [0%, 75%] | 13% (3/24) [4.5%, 31%] | 33% (2/6) [25%, 50%] | 8.3% (3/36) [0%, 24%] | 0% (0/25) [0%, 0%] | 67% (4/6) [50%, 100%] | 50% (5/10) [25%, 100%] |
| gpt-6.1-terra low | 38% (5/13) [10%, 62%] | 3.6% (1/28) [0%, 10%] | 31% (5/16) [5.0%, 59%] | 1.7% (1/59) [0%, 7.0%] | 6.6% (4/61) [1.2%, 20%] | 29% (5/17) [6.7%, 88%] | 24% (4/17) [0%, 36%] |
| gpt-6.1-terra max | 31% (4/13) [11%, 75%] | 7.7% (1/13) [0%, 20%] | 24% (4/17) [10%, 33%] | 5.9% (1/17) [0%, 25%] | 11% (5/44) [1.5%, 25%] | 26% (6/23) [8.3%, 69%] | 100% (4/4) [100%, 100%] |
| gpt-6.1-terra medium | 70% (7/10) [42%, 100%] | 3.4% (1/29) [0%, 11%] | 32% (6/19) [7.7%, 50%] | 7.6% (5/66) [2.3%, 17%] | 3.7% (2/54) [0%, 6.1%] | 14% (3/22) [6.3%, 40%] | 25% (3/12) [25%, 25%] |
| gpt-6.1-terra off | 56% (9/16) [40%, 71%] | 19% (5/27) [9.4%, 33%] | 13% (2/16) [0%, 21%] | 2.3% (1/43) [0%, 6.9%] | 6.3% (2/32) [0%, 16%] | 36% (4/11) [18%, 63%] | 75% (6/8) [54%, 100%] |
| gpt-6.1-terra xhigh | 7.7% (1/13) [0%, 60%] | 13% (4/30) [0%, 33%] | 23% (3/13) [6.7%, 45%] | 7.5% (3/40) [0%, 26%] | 7.0% (3/43) [0%, 19%] | 16% (5/32) [6.8%, 39%] | 30% (3/10) [13%, 67%] |

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
| claude-haiku-4-5-20251001 high | 72% (126/176) [65%, 78%] | 39% (71/181) [32%, 47%] | 54% (93/171) [48%, 61%] | 51% (96/189) [43%, 59%] | 37% (68/184) [28%, 46%] | 56% (84/149) [48%, 64%] | 50% (59/117) [40%, 61%] | 46% (91/197) [38%, 56%] |
| claude-haiku-4-5-20251001 low | 74% (175/238) [69%, 78%] | 43% (93/215) [36%, 50%] | 59% (132/224) [53%, 64%] | 54% (136/250) [46%, 62%] | 37% (87/234) [31%, 45%] | 51% (95/188) [43%, 58%] | 53% (68/129) [45%, 61%] | 46% (115/251) [40%, 52%] |
| claude-haiku-4-5-20251001 medium | 71% (561/789) [68%, 75%] | 36% (327/901) [33%, 40%] | 58% (490/849) [54%, 61%] | 47% (432/924) [43%, 50%] | 34% (315/934) [30%, 37%] | 46% (317/682) [43%, 51%] | 56% (316/561) [53%, 60%] | 43% (362/848) [39%, 46%] |
| claude-haiku-4-5-20251001 minimal | 72% (163/227) [65%, 78%] | 41% (83/204) [33%, 49%] | 59% (116/197) [52%, 66%] | 53% (106/200) [45%, 61%] | 36% (68/189) [28%, 45%] | 54% (90/166) [46%, 63%] | 55% (79/143) [47%, 62%] | 40% (87/218) [32%, 48%] |
| claude-haiku-4-5-20251001 off | 73% (102/140) [64%, 81%] | 54% (81/150) [47%, 61%] | 56% (86/154) [48%, 64%] | 44% (67/154) [35%, 52%] | 45% (62/137) [36%, 55%] | 54% (61/112) [45%, 63%] | 50% (47/94) [40%, 59%] | 41% (62/153) [30%, 51%] |
| claude-haiku-5-5 high | 68% (258/377) [63%, 74%] | 62% (231/374) [57%, 67%] | 61% (223/363) [56%, 67%] | 56% (208/370) [51%, 61%] | 39% (168/431) [34%, 44%] | 60% (178/298) [54%, 66%] | 59% (170/288) [54%, 65%] | 69% (254/368) [64%, 75%] |
| claude-haiku-5-5 low | 75% (448/597) [72%, 78%] | 58% (344/594) [53%, 63%] | 65% (367/561) [62%, 69%] | 57% (333/581) [52%, 62%] | 38% (222/577) [34%, 44%] | 61% (244/403) [55%, 66%] | 63% (233/368) [59%, 68%] | 62% (348/559) [58%, 67%] |
| claude-haiku-5-5 max | 64% (18/28) [44%, 84%] | 71% (22/31) [50%, 86%] | 59% (19/32) [47%, 75%] | 47% (15/32) [24%, 63%] | 37% (10/27) [24%, 45%] | 61% (17/28) [41%, 76%] | 76% (13/17) [61%, 92%] | 63% (24/38) [50%, 75%] |
| claude-haiku-5-5 medium | 70% (707/1015) [67%, 72%] | 58% (659/1145) [54%, 61%] | 60% (654/1090) [57%, 63%] | 59% (701/1186) [56%, 62%] | 36% (404/1119) [33%, 39%] | 56% (490/873) [53%, 59%] | 64% (486/756) [61%, 67%] | 65% (704/1086) [62%, 68%] |
| claude-haiku-5-5 off | 79% (1431/1803) [77%, 81%] | 61% (1132/1852) [58%, 64%] | 69% (1243/1794) [67%, 71%] | 65% (1157/1793) [62%, 67%] | 25% (452/1790) [23%, 27%] | 50% (698/1408) [47%, 52%] | 51% (568/1113) [48%, 54%] | 62% (1144/1838) [60%, 65%] |
| claude-haiku-5-5 xhigh | 65% (113/173) [58%, 72%] | 55% (101/185) [46%, 63%] | 52% (94/182) [45%, 59%] | 48% (80/165) [41%, 55%] | 39% (76/194) [32%, 47%] | 61% (86/142) [54%, 67%] | 59% (70/118) [51%, 68%] | 66% (136/207) [59%, 72%] |
| claude-opus-5-5 high | 71% (70/98) [64%, 79%] | 65% (60/93) [54%, 74%] | 66% (65/99) [58%, 74%] | 40% (39/98) [28%, 51%] | 39% (38/97) [28%, 50%] | 69% (53/77) [57%, 80%] | 65% (53/82) [57%, 72%] | 61% (54/88) [49%, 76%] |
| claude-opus-5-5 low | 68% (98/144) [63%, 73%] | 42% (59/141) [31%, 52%] | 73% (72/98) [63%, 83%] | 45% (54/121) [34%, 57%] | 40% (48/121) [31%, 49%] | 55% (46/84) [45%, 65%] | 63% (50/79) [56%, 70%] | 63% (67/107) [51%, 73%] |
| claude-opus-5-5 max | 74% (95/128) [68%, 81%] | 64% (85/132) [55%, 73%] | 61% (88/144) [52%, 69%] | 55% (77/139) [46%, 64%] | 45% (68/150) [37%, 54%] | 76% (94/123) [68%, 84%] | 59% (55/93) [47%, 71%] | 71% (106/150) [63%, 78%] |
| claude-opus-5-5 medium | 68% (522/771) [64%, 71%] | 60% (507/850) [56%, 64%] | 55% (439/799) [52%, 58%] | 48% (461/965) [44%, 51%] | 39% (323/821) [36%, 43%] | 64% (417/655) [60%, 67%] | 64% (331/520) [59%, 68%] | 61% (466/764) [58%, 64%] |
| claude-opus-5-5 off | 72% (134/187) [65%, 78%] | 45% (90/202) [36%, 53%] | 63% (125/197) [58%, 69%] | 42% (92/219) [35%, 50%] | 43% (77/179) [36%, 51%] | 76% (111/147) [69%, 81%] | 71% (87/122) [62%, 80%] | 66% (137/207) [59%, 73%] |
| claude-opus-5-5 xhigh | 68% (234/345) [62%, 73%] | 63% (220/352) [57%, 69%] | 57% (207/363) [52%, 62%] | 53% (179/335) [47%, 59%] | 34% (125/366) [29%, 39%] | 61% (182/298) [55%, 67%] | 57% (128/225) [50%, 63%] | 64% (239/371) [59%, 70%] |
| claude-sonnet-5-5 high | 68% (133/196) [59%, 76%] | 59% (106/180) [52%, 66%] | 54% (105/195) [46%, 61%] | 48% (103/215) [40%, 56%] | 28% (56/197) [21%, 37%] | 58% (87/149) [49%, 68%] | 60% (76/127) [52%, 67%] | 47% (75/160) [37%, 58%] |
| claude-sonnet-5-5 low | 69% (118/170) [62%, 78%] | 48% (102/214) [39%, 57%] | 54% (102/190) [48%, 59%] | 49% (86/177) [40%, 58%] | 18% (33/183) [13%, 24%] | 59% (86/145) [52%, 67%] | 59% (61/103) [51%, 68%] | 51% (82/160) [43%, 59%] |
| claude-sonnet-5-5 max | 78% (84/108) [67%, 87%] | 53% (79/150) [44%, 62%] | 63% (87/138) [57%, 71%] | 42% (49/118) [31%, 50%] | 42% (58/138) [34%, 50%] | 62% (63/101) [55%, 71%] | 59% (39/66) [49%, 70%] | 58% (73/126) [49%, 67%] |
| claude-sonnet-5-5 medium | 73% (537/739) [69%, 76%] | 57% (452/798) [53%, 60%] | 57% (440/777) [53%, 60%] | 50% (464/923) [46%, 55%] | 25% (219/864) [22%, 28%] | 60% (393/650) [57%, 65%] | 63% (314/497) [59%, 67%] | 51% (415/811) [47%, 55%] |
| claude-sonnet-5-5 off | 69% (142/207) [63%, 74%] | 54% (110/204) [47%, 61%] | 51% (104/204) [44%, 58%] | 55% (123/225) [46%, 64%] | 23% (47/203) [17%, 30%] | 59% (99/169) [51%, 65%] | 55% (70/128) [46%, 64%] | 49% (104/211) [43%, 55%] |
| claude-sonnet-5-5 xhigh | 67% (152/228) [62%, 72%] | 73% (165/226) [67%, 80%] | 59% (133/227) [52%, 66%] | 59% (159/269) [53%, 66%] | 33% (82/248) [27%, 39%] | 59% (107/182) [51%, 66%] | 65% (107/164) [58%, 72%] | 67% (179/266) [62%, 73%] |
| gpt-5.6-terra high | 72% (26/36) [55%, 88%] | 28% (11/39) [16%, 40%] | 75% (21/28) [64%, 90%] | 50% (19/38) [37%, 64%] | 31% (11/36) [11%, 40%] | 46% (12/26) [29%, 59%] | 64% (14/22) [47%, 81%] | 54% (21/39) [36%, 70%] |
| gpt-5.6-terra low | 79% (26/33) [73%, 88%] | 41% (11/27) [12%, 59%] | 54% (26/48) [45%, 63%] | 47% (18/38) [32%, 58%] | 19% (6/31) [7.1%, 29%] | 41% (12/29) [13%, 69%] | 82% (18/22) [71%, 95%] | 50% (19/38) [33%, 68%] |
| gpt-5.6-terra max | 86% (25/29) [69%, 100%] | 78% (25/32) [60%, 91%] | 79% (23/29) [72%, 88%] | 55% (21/38) [38%, 71%] | 51% (23/45) [35%, 69%] | 73% (16/22) [52%, 91%] | 59% (13/22) [44%, 79%] | 73% (24/33) [59%, 89%] |
| gpt-5.6-terra medium | 74% (408/553) [69%, 78%] | 39% (219/560) [34%, 45%] | 64% (302/470) [61%, 68%] | 45% (249/552) [40%, 51%] | 28% (167/599) [23%, 32%] | 45% (182/407) [40%, 50%] | 72% (264/367) [68%, 76%] | 62% (320/516) [58%, 66%] |
| gpt-5.6-terra xhigh | 81% (34/42) [66%, 95%] | 53% (20/38) [38%, 72%] | 58% (28/48) [47%, 68%] | 60% (26/43) [38%, 79%] | 43% (17/40) [31%, 57%] | 67% (26/39) [55%, 77%] | 75% (24/32) [63%, 92%] | 67% (24/36) [53%, 81%] |
| gpt-6-astra high | 70% (233/335) [64%, 75%] | 64% (183/284) [59%, 70%] | 60% (187/311) [54%, 66%] | 38% (106/277) [32%, 45%] | 37% (112/299) [32%, 43%] | 67% (165/247) [62%, 71%] | 67% (145/217) [60%, 73%] | 74% (219/297) [68%, 79%] |
| gpt-6-astra low | 70% (145/208) [64%, 75%] | 59% (128/216) [52%, 66%] | 64% (150/236) [58%, 69%] | 32% (76/234) [26%, 40%] | 35% (82/237) [28%, 42%] | 67% (119/178) [60%, 74%] | 68% (103/151) [61%, 76%] | 67% (167/250) [60%, 73%] |
| gpt-6-astra medium | 72% (488/679) [69%, 75%] | 64% (525/820) [60%, 68%] | 59% (478/804) [56%, 63%] | 38% (319/848) [33%, 42%] | 35% (276/788) [32%, 38%] | 62% (371/595) [58%, 66%] | 64% (300/471) [59%, 68%] | 64% (476/738) [61%, 68%] |
| gpt-6-astra off | 71% (182/255) [65%, 78%] | 55% (152/275) [50%, 61%] | 63% (156/248) [57%, 68%] | 28% (70/253) [21%, 35%] | 31% (81/259) [24%, 38%] | 69% (137/198) [63%, 75%] | 64% (95/148) [57%, 72%] | 64% (156/245) [57%, 70%] |
| gpt-6-luna high | 82% (310/380) [78%, 85%] | 60% (219/364) [55%, 65%] | 68% (252/371) [63%, 73%] | 71% (296/418) [66%, 76%] | 21% (86/409) [17%, 25%] | 60% (184/306) [55%, 66%] | 73% (188/259) [67%, 77%] | 68% (254/371) [62%, 75%] |
| gpt-6-luna low | 80% (199/248) [76%, 84%] | 80% (205/257) [75%, 85%] | 70% (183/263) [64%, 75%] | 62% (176/283) [56%, 69%] | 70% (191/271) [64%, 76%] | 52% (119/230) [45%, 58%] | 63% (97/155) [55%, 70%] | 75% (187/251) [70%, 80%] |
| gpt-6-luna max | 72% (23/32) [45%, 91%] | 52% (26/50) [43%, 62%] | 62% (23/37) [49%, 82%] | 58% (25/43) [39%, 73%] | 29% (12/41) [13%, 51%] | 63% (17/27) [46%, 82%] | 86% (18/21) [69%, 96%] | 67% (22/33) [55%, 76%] |
| gpt-6-luna medium | 77% (696/902) [74%, 80%] | 67% (640/950) [64%, 70%] | 66% (590/891) [63%, 70%] | 64% (634/997) [60%, 67%] | 43% (426/991) [39%, 47%] | 59% (432/738) [55%, 62%] | 65% (376/577) [61%, 69%] | 60% (524/873) [56%, 64%] |
| gpt-6-luna off | 79% (273/346) [75%, 83%] | 79% (294/370) [75%, 83%] | 65% (228/351) [60%, 70%] | 64% (213/335) [57%, 70%] | 76% (289/382) [71%, 80%] | 62% (173/281) [55%, 68%] | 65% (158/244) [57%, 72%] | 66% (258/392) [61%, 71%] |
| gpt-6-luna xhigh | 76% (26/34) [58%, 91%] | 67% (33/49) [47%, 82%] | 57% (32/56) [48%, 64%] | 66% (35/53) [40%, 86%] | 42% (29/69) [31%, 57%] | 78% (32/41) [69%, 90%] | 69% (24/35) [55%, 79%] | 76% (41/54) [68%, 83%] |
| gpt-6.1-sol high | 59% (30/51) [44%, 71%] | 65% (41/63) [54%, 76%] | 68% (41/60) [59%, 78%] | 47% (28/59) [22%, 71%] | 37% (23/63) [23%, 51%] | 67% (33/49) [58%, 75%] | 60% (28/47) [49%, 73%] | 66% (45/68) [48%, 86%] |
| gpt-6.1-sol low | 69% (36/52) [59%, 80%] | 56% (31/55) [41%, 72%] | 61% (33/54) [50%, 72%] | 37% (19/52) [24%, 46%] | 29% (17/58) [17%, 42%] | 67% (26/39) [50%, 80%] | 76% (25/33) [57%, 90%] | 77% (40/52) [66%, 87%] |
| gpt-6.1-sol max | 77% (148/192) [69%, 84%] | 60% (124/205) [54%, 67%] | 63% (140/222) [57%, 69%] | 51% (78/153) [41%, 60%] | 42% (87/208) [34%, 49%] | 63% (101/161) [56%, 70%] | 65% (74/114) [58%, 72%] | 63% (137/216) [56%, 71%] |
| gpt-6.1-sol medium | 70% (374/535) [66%, 74%] | 60% (373/621) [56%, 64%] | 60% (360/603) [56%, 64%] | 41% (250/617) [36%, 45%] | 37% (234/626) [34%, 41%] | 64% (308/479) [60%, 68%] | 65% (263/407) [60%, 69%] | 64% (358/560) [60%, 68%] |
| gpt-6.1-sol xhigh | 60% (37/62) [51%, 72%] | 76% (59/78) [67%, 83%] | 51% (37/72) [42%, 60%] | 62% (59/95) [54%, 69%] | 48% (33/69) [34%, 61%] | 62% (29/47) [45%, 76%] | 61% (22/36) [46%, 76%] | 69% (36/52) [55%, 83%] |
| gpt-6.1-terra high | 74% (173/234) [68%, 80%] | 64% (156/244) [58%, 70%] | 65% (141/217) [59%, 71%] | 20% (43/220) [13%, 26%] | 31% (62/202) [25%, 38%] | 68% (125/183) [61%, 75%] | 65% (96/147) [58%, 72%] | 70% (188/267) [64%, 77%] |
| gpt-6.1-terra low | 77% (336/438) [72%, 81%] | 67% (308/458) [63%, 72%] | 62% (269/437) [57%, 66%] | 11% (50/452) [8.0%, 14%] | 24% (125/515) [20%, 28%] | 66% (224/338) [62%, 71%] | 71% (214/303) [67%, 75%] | 71% (352/497) [66%, 75%] |
| gpt-6.1-terra max | 75% (223/296) [70%, 80%] | 74% (227/308) [68%, 79%] | 63% (190/304) [58%, 67%] | 54% (189/351) [48%, 60%] | 47% (150/316) [42%, 53%] | 77% (189/245) [71%, 83%] | 57% (112/197) [50%, 64%] | 73% (231/316) [68%, 78%] |
| gpt-6.1-terra medium | 76% (255/337) [70%, 81%] | 66% (229/346) [60%, 72%] | 63% (236/375) [57%, 68%] | 22% (76/346) [17%, 27%] | 28% (109/393) [23%, 33%] | 66% (174/263) [59%, 73%] | 71% (156/221) [65%, 77%] | 66% (223/336) [61%, 72%] |
| gpt-6.1-terra off | 69% (134/194) [63%, 75%] | 74% (148/200) [68%, 80%] | 59% (121/205) [52%, 65%] | 16% (37/227) [11%, 22%] | 26% (57/223) [20%, 31%] | 68% (115/169) [61%, 74%] | 63% (85/134) [55%, 71%] | 65% (134/206) [57%, 73%] |
| gpt-6.1-terra xhigh | 75% (196/263) [70%, 79%] | 75% (200/267) [68%, 81%] | 69% (183/267) [63%, 74%] | 31% (97/308) [25%, 38%] | 36% (105/288) [31%, 43%] | 67% (149/223) [60%, 73%] | 68% (121/179) [62%, 73%] | 73% (226/308) [67%, 80%] |

### Astra efforts

| Model | magnifying glass | burner phone | handsaw | beer | inverter | cigarettes | jammer | adrenaline |
|---|---|---|---|---|---|---|---|---|
| gpt-6-astra high | 60% (6/10) [43%, 100%] | 70% (7/10) [0%, 100%] | 75% (12/16) [56%, 88%] | 61% (11/18) [50%, 79%] | 56% (5/9) [14%, 80%] | 75% (6/8) [57%, 100%] | 75% (9/12) [63%, 100%] | 82% (9/11) [67%, 100%] |
| gpt-6-astra low | 69% (9/13) [58%, 86%] | 53% (10/19) [17%, 70%] | 48% (10/21) [13%, 62%] | 26% (6/23) [11%, 54%] | 46% (6/13) [26%, 86%] | 60% (6/10) [14%, 91%] | 67% (6/9) [0%, 90%] | 75% (12/16) [64%, 91%] |
| gpt-6-astra medium | 75% (9/12) [71%, 80%] | 63% (10/16) [56%, 71%] | 53% (9/17) [50%, 55%] | 20% (3/15) [13%, 29%] | 43% (3/7) [33%, 50%] | 67% (2/3) [50%, 100%] | 75% (3/4) [67%, 100%] | 50% (3/6) [50%, 50%] |
| gpt-6-astra off | 82% (9/11) [50%, 100%] | 70% (7/10) [67%, 100%] | 56% (5/9) [33%, 100%] | 44% (4/9) [0%, 60%] | 25% (2/8) [0%, 50%] | 50% (3/6) [50%, 50%] | 67% (4/6) [67%, 67%] | 71% (5/7) [50%, 100%] |

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
| claude-opus-5-5 high | 67% (89/133) [58%, 75%] | 62% (93/150) [55%, 70%] | 48% (64/132) [40%, 57%] | 48% (66/138) [38%, 58%] | 38% (57/149) [30%, 46%] | 56% (65/117) [47%, 64%] | 69% (69/100) [61%, 76%] | 71% (111/156) [65%, 77%] |
| claude-opus-5-5 low | 67% (89/132) [58%, 76%] | 49% (53/108) [41%, 59%] | 52% (58/112) [45%, 59%] | 41% (52/126) [33%, 50%] | 36% (43/120) [28%, 44%] | 63% (62/99) [51%, 73%] | 65% (56/86) [58%, 71%] | 67% (85/127) [58%, 76%] |
| claude-opus-5-5 max | 59% (74/126) [48%, 69%] | 68% (73/108) [60%, 75%] | 54% (63/116) [45%, 63%] | 60% (63/105) [51%, 69%] | 51% (42/83) [39%, 64%] | 71% (68/96) [64%, 79%] | 68% (43/63) [57%, 81%] | 72% (91/126) [65%, 80%] |
| claude-opus-5-5 medium | 70% (153/218) [64%, 76%] | 62% (133/215) [56%, 67%] | 53% (107/202) [46%, 61%] | 42% (105/248) [36%, 49%] | 40% (87/217) [35%, 46%] | 66% (125/189) [59%, 73%] | 60% (84/141) [53%, 66%] | 69% (168/243) [64%, 74%] |
| claude-opus-5-5 off | 66% (35/53) [53%, 80%] | 54% (38/71) [42%, 65%] | 55% (29/53) [45%, 64%] | 36% (20/56) [24%, 47%] | 42% (28/66) [31%, 54%] | 58% (28/48) [45%, 71%] | 62% (26/42) [45%, 78%] | 54% (28/52) [42%, 67%] |
| claude-opus-5-5 xhigh | 68% (117/172) [60%, 76%] | 71% (116/163) [65%, 78%] | 55% (86/155) [47%, 64%] | 42% (72/171) [32%, 52%] | 42% (70/165) [34%, 50%] | 64% (89/140) [54%, 72%] | 57% (65/114) [48%, 67%] | 73% (122/167) [66%, 80%] |

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
| gpt-6.1-terra high | 76% (28/37) [66%, 86%] | 60% (21/35) [50%, 74%] | 63% (19/30) [48%, 86%] | 19% (8/42) [8.5%, 33%] | 21% (4/19) [5.6%, 35%] | 57% (12/21) [42%, 74%] | 77% (17/22) [60%, 90%] | 68% (19/28) [48%, 83%] |
| gpt-6.1-terra low | 75% (30/40) [57%, 91%] | 39% (15/38) [23%, 50%] | 52% (11/21) [37%, 68%] | 0% (0/25) [0%, 0%] | 14% (3/21) [3.0%, 40%] | 88% (14/16) [69%, 100%] | 62% (13/21) [44%, 84%] | 68% (25/37) [62%, 75%] |
| gpt-6.1-terra max | 89% (17/19) [82%, 100%] | 70% (14/20) [62%, 90%] | 60% (18/30) [37%, 85%] | 65% (13/20) [25%, 91%] | 50% (16/32) [44%, 57%] | 68% (17/25) [50%, 77%] | 82% (9/11) [70%, 100%] | 100% (25/25) [100%, 100%] |
| gpt-6.1-terra medium | 78% (32/41) [67%, 86%] | 64% (28/44) [43%, 83%] | 68% (25/37) [54%, 80%] | 8.1% (3/37) [0%, 14%] | 18% (7/39) [2.8%, 35%] | 56% (20/36) [41%, 68%] | 64% (16/25) [48%, 85%] | 57% (27/47) [49%, 67%] |
| gpt-6.1-terra off | 67% (22/33) [53%, 83%] | 63% (19/30) [43%, 83%] | 50% (17/34) [36%, 66%] | 19% (7/37) [6.1%, 29%] | 27% (8/30) [12%, 42%] | 72% (13/18) [57%, 86%] | 63% (10/16) [42%, 85%] | 74% (29/39) [56%, 89%] |
| gpt-6.1-terra xhigh | 70% (26/37) [58%, 82%] | 59% (20/34) [30%, 90%] | 56% (19/34) [38%, 71%] | 24% (10/41) [18%, 32%] | 24% (8/34) [9.1%, 34%] | 54% (15/28) [33%, 73%] | 68% (17/25) [53%, 81%] | 42% (22/53) [29%, 61%] |

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
| claude-haiku-4-5-20251001 high | 93% (111/120) [87%, 97%] | 3.52 (423/120) [3.17, 3.89] | inverter 86, adrenaline 79, burner phone 73 |
| claude-haiku-4-5-20251001 low | 92% (135/146) [88%, 96%] | 3.37 (492/146) [3.07, 3.65] | adrenaline 102, inverter 101, burner phone 80 |
| claude-haiku-4-5-20251001 medium | 91% (500/552) [88%, 93%] | 3.45 (1903/552) [3.25, 3.63] | inverter 370, burner phone 366, beer 309 |
| claude-haiku-4-5-20251001 minimal | 91% (118/130) [86%, 95%] | 3.33 (433/130) [2.91, 3.79] | adrenaline 99, burner phone 77, inverter 76 |
| claude-haiku-4-5-20251001 off | 89% (93/104) [83%, 95%] | 3.27 (340/104) [2.83, 3.67] | adrenaline 74, beer 61, inverter 53 |
| claude-haiku-5-5 high | 89% (170/190) [85%, 94%] | 3.00 (570/190) [2.70, 3.32] | inverter 132, beer 92, burner phone 77 |
| claude-haiku-5-5 low | 85% (216/253) [81%, 89%] | 2.74 (694/253) [2.52, 2.99] | inverter 164, beer 126, burner phone 116 |
| claude-haiku-5-5 max | 91% (10/11) [73%, 100%] | 3.64 (40/11) [2.57, 4.44] | inverter 7, adrenaline 7, magnifying glass 6 |
| claude-haiku-5-5 medium | 89% (450/506) [86%, 92%] | 3.21 (1626/506) [3.03, 3.40] | inverter 343, beer 268, burner phone 262 |
| claude-haiku-5-5 off | 87% (907/1046) [85%, 89%] | 2.79 (2915/1046) [2.67, 2.90] | inverter 771, adrenaline 474, burner phone 459 |
| claude-haiku-5-5 xhigh | 97% (98/101) [94%, 100%] | 3.52 (356/101) [3.19, 3.90] | inverter 74, adrenaline 56, burner phone 51 |
| claude-opus-5-5 high | 97% (28/29) [88%, 100%] | 3.59 (104/29) [3.08, 4.22] | adrenaline 20, beer 17, inverter 17 |
| claude-opus-5-5 low | 86% (48/56) [76%, 94%] | 3.29 (184/56) [2.81, 3.79] | burner phone 48, inverter 37, beer 30 |
| claude-opus-5-5 max | 85% (34/40) [71%, 96%] | 2.92 (117/40) [2.22, 3.65] | inverter 28, burner phone 22, adrenaline 19 |
| claude-opus-5-5 medium | 91% (317/347) [88%, 94%] | 3.37 (1170/347) [3.18, 3.57] | inverter 245, beer 229, burner phone 155 |
| claude-opus-5-5 off | 89% (59/66) [81%, 96%] | 3.45 (228/66) [2.97, 4.00] | inverter 52, burner phone 40, beer 38 |
| claude-opus-5-5 xhigh | 89% (152/171) [84%, 93%] | 3.06 (523/171) [2.75, 3.37] | inverter 126, adrenaline 82, burner phone 80 |
| claude-sonnet-5-5 high | 91% (95/104) [87%, 96%] | 3.47 (361/104) [3.09, 3.90] | inverter 94, beer 58, adrenaline 53 |
| claude-sonnet-5-5 low | 95% (108/114) [91%, 98%] | 3.68 (420/114) [3.34, 4.02] | inverter 112, burner phone 77, beer 59 |
| claude-sonnet-5-5 max | 100% (49/49) [100%, 100%] | 3.65 (179/49) [3.27, 4.02] | burner phone 42, adrenaline 38, inverter 28 |
| claude-sonnet-5-5 medium | 90% (364/403) [87%, 93%] | 3.41 (1376/403) [3.20, 3.64] | inverter 345, adrenaline 245, beer 230 |
| claude-sonnet-5-5 off | 92% (108/118) [87%, 96%] | 3.18 (375/118) [2.82, 3.54] | inverter 87, adrenaline 66, beer 63 |
| claude-sonnet-5-5 xhigh | 90% (93/103) [85%, 95%] | 3.08 (317/103) [2.71, 3.44] | inverter 75, beer 58, adrenaline 46 |
| gpt-5.6-terra high | 100% (20/20) [100%, 100%] | 3.55 (71/20) [2.96, 4.38] | burner phone 17, inverter 17, beer 12 |
| gpt-5.6-terra low | 93% (14/15) [83%, 100%] | 4.27 (64/15) [3.14, 5.70] | beer 13, inverter 13, adrenaline 11 |
| gpt-5.6-terra max | 71% (10/14) [64%, 88%] | 2.50 (35/14) [2.00, 3.57] | beer 10, inverter 7, adrenaline 5 |
| gpt-5.6-terra medium | 92% (249/272) [88%, 95%] | 3.33 (907/272) [3.05, 3.61] | inverter 204, burner phone 171, beer 170 |
| gpt-5.6-terra xhigh | 85% (17/20) [74%, 96%] | 2.55 (51/20) [1.89, 3.41] | burner phone 9, inverter 9, handsaw 8 |
| gpt-6-astra high | 91% (91/100) [85%, 96%] | 3.32 (332/100) [2.94, 3.68] | inverter 80, beer 69, burner phone 39 |
| gpt-6-astra low | 91% (80/88) [85%, 96%] | 3.32 (292/88) [2.91, 3.72] | inverter 79, adrenaline 49, beer 44 |
| gpt-6-astra medium | 93% (280/300) [90%, 96%] | 3.25 (974/300) [3.02, 3.50] | inverter 240, beer 207, adrenaline 128 |
| gpt-6-astra off | 91% (91/100) [85%, 96%] | 3.29 (329/100) [2.92, 3.68] | inverter 82, beer 74, burner phone 52 |
| gpt-6-luna high | 86% (161/188) [81%, 90%] | 2.88 (541/188) [2.58, 3.17] | inverter 174, burner phone 87, adrenaline 82 |
| gpt-6-luna low | 70% (135/193) [63%, 76%] | 1.87 (360/193) [1.64, 2.10] | beer 82, adrenaline 58, inverter 53 |
| gpt-6-luna max | 86% (19/22) [75%, 96%] | 3.14 (69/22) [2.44, 3.70] | inverter 20, burner phone 13, beer 12 |
| gpt-6-luna medium | 83% (512/619) [80%, 85%] | 2.57 (1588/619) [2.41, 2.72] | inverter 370, beer 261, adrenaline 246 |
| gpt-6-luna off | 72% (188/260) [67%, 78%] | 2.03 (528/260) [1.83, 2.23] | adrenaline 118, beer 95, burner phone 68 |
| gpt-6-luna xhigh | 83% (20/24) [71%, 96%] | 2.63 (63/24) [2.18, 3.00] | inverter 17, handsaw 13, burner phone 9 |
| gpt-6.1-sol high | 90% (26/29) [79%, 97%] | 3.14 (91/29) [2.23, 4.07] | inverter 21, adrenaline 17, burner phone 13 |
| gpt-6.1-sol low | 95% (20/21) [83%, 100%] | 3.05 (64/21) [2.16, 3.95] | beer 20, inverter 17, magnifying glass 7 |
| gpt-6.1-sol max | 85% (72/85) [75%, 93%] | 2.66 (226/85) [2.26, 3.06] | inverter 54, adrenaline 47, burner phone 44 |
| gpt-6.1-sol medium | 95% (218/229) [92%, 98%] | 3.48 (798/229) [3.24, 3.74] | inverter 182, beer 155, burner phone 109 |
| gpt-6.1-sol xhigh | 92% (22/24) [81%, 100%] | 3.17 (76/24) [2.71, 3.65] | inverter 26, beer 15, handsaw 11 |
| gpt-6.1-terra high | 88% (72/82) [80%, 95%] | 3.12 (256/82) [2.68, 3.58] | inverter 53, beer 49, adrenaline 47 |
| gpt-6.1-terra low | 96% (203/211) [94%, 99%] | 3.12 (658/211) [2.89, 3.35] | inverter 205, beer 192, adrenaline 73 |
| gpt-6.1-terra max | 87% (91/105) [80%, 93%] | 2.88 (302/105) [2.48, 3.23] | inverter 64, beer 53, adrenaline 48 |
| gpt-6.1-terra medium | 94% (131/140) [89%, 97%] | 3.13 (438/140) [2.82, 3.45] | inverter 129, beer 105, adrenaline 56 |
| gpt-6.1-terra off | 96% (81/84) [92%, 100%] | 3.85 (323/84) [3.46, 4.25] | inverter 82, beer 81, adrenaline 47 |
| gpt-6.1-terra xhigh | 97% (97/100) [94%, 100%] | 3.06 (306/100) [2.74, 3.39] | beer 76, inverter 72, adrenaline 47 |

### Astra efforts

| Model | Deaths with an item held | Items held per death | Items held at death, most common |
|---|---|---|---|
| gpt-6-astra high | 75% (6/8) [40%, 100%] | 2.25 (18/8) [1.00, 3.00] | inverter 4, burner phone 3, handsaw 3 |
| gpt-6-astra low | 100% (10/10) [100%, 100%] | 3.30 (33/10) [2.00, 4.33] | beer 9, handsaw 7, inverter 6 |
| gpt-6-astra medium | 100% (4/4) [100%, 100%] | 3.50 (14/4) [3.00, 4.00] | beer 7, burner phone 3, handsaw 2 |
| gpt-6-astra off | 60% (3/5) [0%, 100%] | 1.60 (8/5) [0.00, 2.50] | beer 3, burner phone 2, adrenaline 2 |

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
| claude-opus-5-5 high | 89% (71/80) [82%, 95%] | 3.09 (247/80) [2.59, 3.65] | beer 51, inverter 44, burner phone 38 |
| claude-opus-5-5 low | 83% (54/65) [72%, 92%] | 3.05 (198/65) [2.53, 3.54] | beer 46, inverter 34, burner phone 28 |
| claude-opus-5-5 max | 82% (37/45) [68%, 94%] | 2.56 (115/45) [2.00, 3.11] | magnifying glass 21, handsaw 20, beer 17 |
| claude-opus-5-5 medium | 90% (104/116) [84%, 95%] | 3.06 (355/116) [2.66, 3.45] | beer 77, inverter 68, burner phone 51 |
| claude-opus-5-5 off | 85% (28/33) [73%, 97%] | 3.18 (105/33) [2.48, 4.00] | burner phone 24, beer 24, inverter 16 |
| claude-opus-5-5 xhigh | 83% (60/72) [75%, 91%] | 2.68 (193/72) [2.18, 3.18] | inverter 37, beer 35, adrenaline 25 |

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
| gpt-6.1-terra high | 100% (18/18) [100%, 100%] | 3.17 (57/18) [2.74, 3.68] | beer 16, burner phone 11, inverter 10 |
| gpt-6.1-terra low | 100% (10/10) [100%, 100%] | 3.80 (38/10) [2.70, 5.33] | burner phone 14, inverter 7, beer 5 |
| gpt-6.1-terra max | 86% (6/7) [40%, 100%] | 1.29 (9/7) [0.50, 1.60] | handsaw 4, inverter 4, beer 1 |
| gpt-6.1-terra medium | 94% (16/17) [83%, 100%] | 3.94 (67/17) [3.32, 4.65] | inverter 21, beer 15, adrenaline 10 |
| gpt-6.1-terra off | 95% (18/19) [81%, 100%] | 3.47 (66/19) [2.60, 4.19] | beer 24, inverter 15, burner phone 10 |
| gpt-6.1-terra xhigh | 100% (22/22) [100%, 100%] | 4.09 (90/22) [3.36, 4.50] | adrenaline 25, beer 20, inverter 20 |

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
| Cross-model | claude-haiku-4-5-20251001 high | 9 | 1.3% (18/1378) | 5.6% (1/18) | 11% over 9 positions [0%, 50%] |
| Cross-model | claude-haiku-4-5-20251001 low | 5 | 0.6% (10/1773) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-haiku-4-5-20251001 medium | 268 | 11% (729/6375) | 19% (139/729) | 36% over 268 positions [30%, 41%] |
| Cross-model | claude-haiku-4-5-20251001 minimal | 4 | 0.5% (8/1607) | 13% (1/8) | 25% over 4 positions [0%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 off | 5 | 0.9% (10/1099) | 20% (2/10) | 40% over 5 positions [33%, 50%] |
| Cross-model | claude-haiku-5-5 high | 10 | 0.6% (20/3092) | 10% (2/20) | 20% over 10 positions [0%, 50%] |
| Cross-model | claude-haiku-5-5 low | 41 | 1.8% (82/4598) | 11% (9/82) | 22% over 41 positions [17%, 33%] |
| Cross-model | claude-haiku-5-5 max | 0 | 0% (0/252) | – | – |
| Cross-model | claude-haiku-5-5 medium | 364 | 11% (978/8694) | 11% (112/978) | 20% over 364 positions [17%, 25%] |
| Cross-model | claude-haiku-5-5 off | 101 | 1.5% (202/13930) | 14% (29/202) | 29% over 101 positions [23%, 40%] |
| Cross-model | claude-haiku-5-5 xhigh | 0 | 0% (0/1401) | – | – |
| Cross-model | claude-opus-5-5 high | 0 | 0% (0/811) | – | – |
| Cross-model | claude-opus-5-5 low | 0 | 0% (0/957) | – | – |
| Cross-model | claude-opus-5-5 max | 3 | 0.5% (6/1246) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Cross-model | claude-opus-5-5 medium | 474 | 19% (1244/6708) | 5.8% (72/1244) | 10% over 474 positions [8.7%, 14%] |
| Cross-model | claude-opus-5-5 off | 0 | 0% (0/1626) | – | – |
| Cross-model | claude-opus-5-5 xhigh | 61 | 4.2% (122/2925) | 7.4% (9/122) | 15% over 61 positions [4.2%, 100%] |
| Cross-model | claude-sonnet-5-5 high | 5 | 0.7% (10/1475) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 low | 5 | 0.7% (10/1344) | 10% (1/10) | 20% over 5 positions [0%, 50%] |
| Cross-model | claude-sonnet-5-5 max | 131 | 33% (331/1004) | 4.8% (16/331) | 9.7% over 131 positions [4.6%, 14%] |
| Cross-model | claude-sonnet-5-5 medium | 447 | 19% (1194/6454) | 6.0% (72/1194) | 12% over 447 positions [9.4%, 14%] |
| Cross-model | claude-sonnet-5-5 off | 13 | 1.6% (26/1581) | 0% (0/26) | 0% over 13 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 xhigh | 0 | 0% (0/2016) | – | – |
| Cross-model | gpt-5.6-terra high | 0 | 0% (0/280) | – | – |
| Cross-model | gpt-5.6-terra low | 0 | 0% (0/275) | – | – |
| Cross-model | gpt-5.6-terra max | 0 | 0% (0/319) | – | – |
| Cross-model | gpt-5.6-terra medium | 296 | 16% (690/4316) | 10% (72/690) | 20% over 296 positions [16%, 26%] |
| Cross-model | gpt-5.6-terra xhigh | 2 | 1.1% (4/379) | 0% (0/4) | 0% over 2 positions [0%, 0%] |
| Cross-model | gpt-6-astra high | 6 | 0.5% (12/2524) | 17% (2/12) | 33% over 6 positions [33%, 33%] |
| Cross-model | gpt-6-astra low | 19 | 2.0% (38/1868) | 0% (0/38) | 0% over 19 positions [0%, 0%] |
| Cross-model | gpt-6-astra medium | 468 | 20% (1268/6219) | 2.9% (37/1268) | 6.0% over 468 positions [3.9%, 7.3%] |
| Cross-model | gpt-6-astra off | 0 | 0% (0/2023) | – | – |
| Cross-model | gpt-6-luna high | 11 | 0.7% (22/3307) | 18% (4/22) | 36% over 11 positions [20%, 100%] |
| Cross-model | gpt-6-luna low | 25 | 2.2% (50/2314) | 14% (7/50) | 28% over 25 positions [17%, 67%] |
| Cross-model | gpt-6-luna max | 7 | 4.5% (14/308) | 14% (2/14) | 29% over 7 positions [29%, 29%] |
| Cross-model | gpt-6-luna medium | 336 | 12% (913/7926) | 17% (154/913) | 31% over 336 positions [26%, 35%] |
| Cross-model | gpt-6-luna off | 33 | 2.0% (66/3258) | 14% (9/66) | 27% over 33 positions [20%, 38%] |
| Cross-model | gpt-6-luna xhigh | 0 | 0% (0/459) | – | – |
| Cross-model | gpt-6.1-sol high | 2 | 0.8% (4/507) | 0% (0/4) | 0% over 2 positions [0%, 0%] |
| Cross-model | gpt-6.1-sol low | 1 | 0.5% (2/433) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6.1-sol max | 134 | 19% (318/1632) | 2.8% (9/318) | 5.5% over 134 positions [1.6%, 12%] |
| Cross-model | gpt-6.1-sol medium | 395 | 22% (1076/4839) | 4.9% (53/1076) | 8.6% over 395 positions [7.1%, 13%] |
| Cross-model | gpt-6.1-sol xhigh | 1 | 0.4% (2/564) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6.1-terra high | 14 | 1.5% (28/1908) | 3.6% (1/28) | 7.1% over 14 positions [7.1%, 7.1%] |
| Cross-model | gpt-6.1-terra low | 21 | 1.1% (42/3743) | 7.1% (3/42) | 14% over 21 positions [0%, 50%] |
| Cross-model | gpt-6.1-terra max | 1 | 0.1% (2/2719) | 0% (0/2) | 0% over 1 positions [0%, 0%] |
| Cross-model | gpt-6.1-terra medium | 53 | 3.7% (106/2886) | 3.8% (4/106) | 7.5% over 53 positions [2.7%, 21%] |
| Cross-model | gpt-6.1-terra off | 0 | 0% (0/1684) | – | – |
| Cross-model | gpt-6.1-terra xhigh | 16 | 1.3% (32/2420) | 6.3% (2/32) | 13% over 16 positions [11%, 14%] |
| Astra efforts | gpt-6-astra high | 0 | 0% (0/117) | – | – |
| Astra efforts | gpt-6-astra low | 0 | 0% (0/124) | – | – |
| Astra efforts | gpt-6-astra medium | 13 | 33% (26/79) | 0% (0/26) | 0% over 13 positions [0%, 0%] |
| Astra efforts | gpt-6-astra off | 0 | 0% (0/80) | – | – |
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
| Opus efforts | claude-opus-5-5 high | 149 | 26% (301/1174) | 5.0% (15/301) | 9.6% over 149 positions [2.2%, 29%] |
| Opus efforts | claude-opus-5-5 low | 3 | 0.6% (6/984) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Opus efforts | claude-opus-5-5 max | 106 | 28% (257/934) | 3.9% (10/257) | 8.5% over 106 positions [3.5%, 14%] |
| Opus efforts | claude-opus-5-5 medium | 207 | 28% (512/1820) | 4.9% (25/512) | 11% over 207 positions [6.5%, 13%] |
| Opus efforts | claude-opus-5-5 off | 0 | 0% (0/454) | – | – |
| Opus efforts | claude-opus-5-5 xhigh | 157 | 23% (319/1388) | 5.6% (18/319) | 11% over 157 positions [5.1%, 24%] |
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
| Terra 6.1 efforts | gpt-6.1-terra high | 0 | 0% (0/254) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra low | 0 | 0% (0/230) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra max | 0 | 0% (0/244) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra medium | 0 | 0% (0/322) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra off | 0 | 0% (0/250) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra xhigh | 2 | 1.5% (4/274) | 25% (1/4) | 50% over 2 positions [50%, 50%] |
| Terra efforts | gpt-5.6-terra high | 128 | 19% (351/1886) | 14% (49/351) | 27% over 128 positions [20%, 32%] |
| Terra efforts | gpt-5.6-terra low | 152 | 20% (374/1852) | 13% (50/374) | 24% over 152 positions [19%, 35%] |
| Terra efforts | gpt-5.6-terra max | 185 | 23% (503/2170) | 9.3% (47/503) | 20% over 185 positions [12%, 24%] |
| Terra efforts | gpt-5.6-terra medium | 160 | 22% (403/1792) | 13% (51/403) | 24% over 160 positions [18%, 32%] |
| Terra efforts | gpt-5.6-terra xhigh | 135 | 17% (355/2030) | 14% (48/355) | 29% over 135 positions [20%, 34%] |

### Belief positions

| Cohort | Model | Positions seen twice or more | Coverage | Non-modal choices | Two differ |
|---|---|---|---|---|---|
| Cross-model | claude-haiku-4-5-20251001 high | 9 | 1.3% (18/1378) | 5.6% (1/18) | 11% over 9 positions [0%, 50%] |
| Cross-model | claude-haiku-4-5-20251001 low | 5 | 0.6% (10/1773) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-haiku-4-5-20251001 medium | 292 | 12% (793/6375) | 19% (150/793) | 36% over 292 positions [31%, 41%] |
| Cross-model | claude-haiku-4-5-20251001 minimal | 4 | 0.5% (8/1607) | 13% (1/8) | 25% over 4 positions [0%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 off | 5 | 0.9% (10/1099) | 20% (2/10) | 40% over 5 positions [33%, 50%] |
| Cross-model | claude-haiku-5-5 high | 10 | 0.6% (20/3092) | 10% (2/20) | 20% over 10 positions [0%, 50%] |
| Cross-model | claude-haiku-5-5 low | 45 | 2.0% (90/4598) | 10% (9/90) | 20% over 45 positions [15%, 29%] |
| Cross-model | claude-haiku-5-5 max | 0 | 0% (0/252) | – | – |
| Cross-model | claude-haiku-5-5 medium | 406 | 13% (1093/8694) | 11% (118/1093) | 19% over 406 positions [16%, 23%] |
| Cross-model | claude-haiku-5-5 off | 108 | 1.6% (216/13930) | 14% (30/216) | 28% over 108 positions [22%, 39%] |
| Cross-model | claude-haiku-5-5 xhigh | 0 | 0% (0/1401) | – | – |
| Cross-model | claude-opus-5-5 high | 0 | 0% (0/811) | – | – |
| Cross-model | claude-opus-5-5 low | 0 | 0% (0/957) | – | – |
| Cross-model | claude-opus-5-5 max | 3 | 0.5% (6/1246) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Cross-model | claude-opus-5-5 medium | 521 | 21% (1380/6708) | 5.7% (78/1380) | 10% over 521 positions [8.6%, 13%] |
| Cross-model | claude-opus-5-5 off | 0 | 0% (0/1626) | – | – |
| Cross-model | claude-opus-5-5 xhigh | 67 | 4.6% (134/2925) | 6.7% (9/134) | 13% over 67 positions [4.2%, 100%] |
| Cross-model | claude-sonnet-5-5 high | 5 | 0.7% (10/1475) | 0% (0/10) | 0% over 5 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 low | 5 | 0.7% (10/1344) | 10% (1/10) | 20% over 5 positions [0%, 50%] |
| Cross-model | claude-sonnet-5-5 max | 144 | 36% (362/1004) | 4.7% (17/362) | 9.5% over 144 positions [4.4%, 14%] |
| Cross-model | claude-sonnet-5-5 medium | 484 | 20% (1290/6454) | 6.1% (79/1290) | 13% over 484 positions [9.7%, 15%] |
| Cross-model | claude-sonnet-5-5 off | 13 | 1.6% (26/1581) | 0% (0/26) | 0% over 13 positions [0%, 0%] |
| Cross-model | claude-sonnet-5-5 xhigh | 0 | 0% (0/2016) | – | – |
| Cross-model | gpt-5.6-terra high | 0 | 0% (0/280) | – | – |
| Cross-model | gpt-5.6-terra low | 0 | 0% (0/275) | – | – |
| Cross-model | gpt-5.6-terra max | 0 | 0% (0/319) | – | – |
| Cross-model | gpt-5.6-terra medium | 315 | 17% (739/4316) | 10% (77/739) | 20% over 315 positions [16%, 26%] |
| Cross-model | gpt-5.6-terra xhigh | 2 | 1.1% (4/379) | 0% (0/4) | 0% over 2 positions [0%, 0%] |
| Cross-model | gpt-6-astra high | 10 | 0.8% (20/2524) | 10% (2/20) | 20% over 10 positions [20%, 20%] |
| Cross-model | gpt-6-astra low | 19 | 2.0% (38/1868) | 0% (0/38) | 0% over 19 positions [0%, 0%] |
| Cross-model | gpt-6-astra medium | 499 | 22% (1338/6219) | 3.0% (40/1338) | 6.2% over 499 positions [4.0%, 7.6%] |
| Cross-model | gpt-6-astra off | 0 | 0% (0/2023) | – | – |
| Cross-model | gpt-6-luna high | 14 | 0.8% (28/3307) | 14% (4/28) | 29% over 14 positions [13%, 100%] |
| Cross-model | gpt-6-luna low | 31 | 2.7% (62/2314) | 13% (8/62) | 26% over 31 positions [13%, 67%] |
| Cross-model | gpt-6-luna max | 7 | 4.5% (14/308) | 14% (2/14) | 29% over 7 positions [29%, 29%] |
| Cross-model | gpt-6-luna medium | 361 | 12% (973/7926) | 17% (163/973) | 31% over 361 positions [26%, 36%] |
| Cross-model | gpt-6-luna off | 38 | 2.3% (76/3258) | 12% (9/76) | 24% over 38 positions [18%, 31%] |
| Cross-model | gpt-6-luna xhigh | 0 | 0% (0/459) | – | – |
| Cross-model | gpt-6.1-sol high | 2 | 0.8% (4/507) | 0% (0/4) | 0% over 2 positions [0%, 0%] |
| Cross-model | gpt-6.1-sol low | 1 | 0.5% (2/433) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6.1-sol max | 141 | 21% (339/1632) | 2.7% (9/339) | 5.2% over 141 positions [1.6%, 11%] |
| Cross-model | gpt-6.1-sol medium | 426 | 24% (1165/4839) | 4.7% (55/1165) | 8.4% over 426 positions [6.7%, 12%] |
| Cross-model | gpt-6.1-sol xhigh | 1 | 0.4% (2/564) | 50% (1/2) | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6.1-terra high | 14 | 1.5% (28/1908) | 3.6% (1/28) | 7.1% over 14 positions [7.1%, 7.1%] |
| Cross-model | gpt-6.1-terra low | 25 | 1.3% (50/3743) | 8.0% (4/50) | 16% over 25 positions [5.9%, 50%] |
| Cross-model | gpt-6.1-terra max | 1 | 0.1% (2/2719) | 0% (0/2) | 0% over 1 positions [0%, 0%] |
| Cross-model | gpt-6.1-terra medium | 53 | 3.7% (106/2886) | 3.8% (4/106) | 7.5% over 53 positions [2.2%, 21%] |
| Cross-model | gpt-6.1-terra off | 0 | 0% (0/1684) | – | – |
| Cross-model | gpt-6.1-terra xhigh | 16 | 1.3% (32/2420) | 6.3% (2/32) | 13% over 16 positions [11%, 14%] |
| Astra efforts | gpt-6-astra high | 0 | 0% (0/117) | – | – |
| Astra efforts | gpt-6-astra low | 0 | 0% (0/124) | – | – |
| Astra efforts | gpt-6-astra medium | 13 | 33% (26/79) | 0% (0/26) | 0% over 13 positions [0%, 0%] |
| Astra efforts | gpt-6-astra off | 0 | 0% (0/80) | – | – |
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
| Opus efforts | claude-opus-5-5 high | 158 | 27% (319/1174) | 5.3% (17/319) | 10% over 158 positions [3.7%, 25%] |
| Opus efforts | claude-opus-5-5 low | 3 | 0.6% (6/984) | 0% (0/6) | 0% over 3 positions [0%, 0%] |
| Opus efforts | claude-opus-5-5 max | 114 | 30% (277/934) | 4.7% (13/277) | 9.9% over 114 positions [4.2%, 16%] |
| Opus efforts | claude-opus-5-5 medium | 226 | 30% (555/1820) | 5.0% (28/555) | 11% over 226 positions [6.5%, 14%] |
| Opus efforts | claude-opus-5-5 off | 0 | 0% (0/454) | – | – |
| Opus efforts | claude-opus-5-5 xhigh | 168 | 25% (343/1388) | 5.8% (20/343) | 12% over 168 positions [5.6%, 22%] |
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
| Terra 6.1 efforts | gpt-6.1-terra high | 0 | 0% (0/254) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra low | 0 | 0% (0/230) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra max | 0 | 0% (0/244) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra medium | 0 | 0% (0/322) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra off | 0 | 0% (0/250) | – | – |
| Terra 6.1 efforts | gpt-6.1-terra xhigh | 2 | 1.5% (4/274) | 25% (1/4) | 50% over 2 positions [50%, 50%] |
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
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 medium | 34 | 69% over 34 positions [61%, 100%] | – | 77% over 13 positions [50%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 minimal | 9 | 89% over 9 positions [89%, 89%] | – | – |
| Cross-model | claude-haiku-4-5-20251001 high vs claude-haiku-4-5-20251001 off | 17 | 71% over 17 positions [33%, 100%] | – | 100% over 1 positions [100%, 100%] |
| Cross-model | claude-haiku-4-5-20251001 low vs claude-haiku-4-5-20251001 medium | 31 | 58% over 31 positions [25%, 80%] | – | 67% over 12 positions [50%, 100%] |
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
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 low | 25 | 90% over 25 positions [86%, 100%] | – | 50% over 2 positions [50%, 50%] |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 max | 7 | 57% over 7 positions [0%, 75%] | – | – |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 medium | 40 | 89% over 40 positions [80%, 100%] | 100% over 5 positions [100%, 100%] | 93% over 14 positions [88%, 100%] |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 off | 6 | 83% over 6 positions [50%, 100%] | – | – |
| Cross-model | claude-sonnet-5-5 high vs claude-sonnet-5-5 xhigh | 4 | 75% over 4 positions [75%, 75%] | – | – |
| Cross-model | claude-sonnet-5-5 low vs claude-sonnet-5-5 max | 20 | 70% over 20 positions [50%, 100%] | 50% over 2 positions [50%, 50%] | – |
| Cross-model | claude-sonnet-5-5 low vs claude-sonnet-5-5 medium | 28 | 84% over 28 positions [67%, 96%] | 50% over 2 positions [50%, 50%] | 85% over 13 positions [0%, 100%] |
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
| Cross-model | gpt-6-luna high vs gpt-6-luna medium | 31 | 53% over 31 positions [0%, 80%] | – | 54% over 15 positions [0%, 100%] |
| Cross-model | gpt-6-luna high vs gpt-6-luna off | 5 | 60% over 5 positions [0%, 75%] | – | – |
| Cross-model | gpt-6-luna high vs gpt-6-luna xhigh | 3 | 67% over 3 positions [67%, 67%] | – | – |
| Cross-model | gpt-6-luna low vs gpt-6-luna max | 15 | 40% over 15 positions [0%, 75%] | – | 100% over 1 positions [100%, 100%] |
| Cross-model | gpt-6-luna low vs gpt-6-luna medium | 25 | 56% over 25 positions [20%, 75%] | 0% over 1 positions [0%, 0%] | 78% over 12 positions [0%, 100%] |
| Cross-model | gpt-6-luna low vs gpt-6-luna off | 10 | 60% over 10 positions [56%, 100%] | – | – |
| Cross-model | gpt-6-luna low vs gpt-6-luna xhigh | 8 | 50% over 8 positions [40%, 67%] | – | – |
| Cross-model | gpt-6-luna max vs gpt-6-luna medium | 27 | 56% over 27 positions [40%, 68%] | 100% over 4 positions [100%, 100%] | 76% over 15 positions [0%, 100%] |
| Cross-model | gpt-6-luna max vs gpt-6-luna off | 9 | 56% over 9 positions [50%, 60%] | – | – |
| Cross-model | gpt-6-luna max vs gpt-6-luna xhigh | 17 | 88% over 17 positions [88%, 88%] | – | – |
| Cross-model | gpt-6-luna medium vs gpt-6-luna off | 24 | 67% over 24 positions [0%, 86%] | 71% over 7 positions [0%, 100%] | – |
| Cross-model | gpt-6-luna medium vs gpt-6-luna xhigh | 22 | 68% over 22 positions [25%, 100%] | 0% over 2 positions [0%, 0%] | – |
| Cross-model | gpt-6-luna off vs gpt-6-luna xhigh | 8 | 63% over 8 positions [50%, 75%] | – | – |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol low | 0 | – | – | – |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol max | 0 | – | – | – |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol medium | 51 | 90% over 51 positions [71%, 100%] | – | 89% over 19 positions [0%, 100%] |
| Cross-model | gpt-6.1-sol high vs gpt-6.1-sol xhigh | 36 | 83% over 36 positions [43%, 100%] | – | – |
| Cross-model | gpt-6.1-sol low vs gpt-6.1-sol max | 33 | 82% over 33 positions [67%, 100%] | – | – |
| Cross-model | gpt-6.1-sol low vs gpt-6.1-sol medium | 62 | 90% over 62 positions [75%, 100%] | – | 86% over 14 positions [50%, 100%] |
| Cross-model | gpt-6.1-sol low vs gpt-6.1-sol xhigh | 0 | – | – | – |
| Cross-model | gpt-6.1-sol max vs gpt-6.1-sol medium | 47 | 84% over 47 positions [63%, 100%] | – | 79% over 14 positions [50%, 100%] |
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
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 low | 150 | 86% over 150 positions [78%, 91%] | 93% over 99 positions [75%, 100%] | 100% over 2 positions [100%, 100%] |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 max | 0 | – | – | – |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 medium | 353 | 90% over 353 positions [88%, 93%] | 91% over 146 positions [72%, 98%] | 91% over 170 positions [88%, 95%] |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 off | 6 | 83% over 6 positions [83%, 83%] | – | – |
| Opus efforts | claude-opus-5-5 high vs claude-opus-5-5 xhigh | 203 | 86% over 203 positions [83%, 90%] | 94% over 108 positions [77%, 100%] | 87% over 116 positions [76%, 93%] |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 max | 23 | 67% over 23 positions [33%, 82%] | – | 94% over 21 positions [75%, 100%] |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 medium | 249 | 86% over 249 positions [82%, 89%] | 100% over 1 positions [100%, 100%] | 96% over 106 positions [91%, 99%] |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 off | 5 | 80% over 5 positions [80%, 80%] | – | – |
| Opus efforts | claude-opus-5-5 low vs claude-opus-5-5 xhigh | 197 | 82% over 197 positions [75%, 87%] | – | 91% over 88 positions [77%, 100%] |
| Opus efforts | claude-opus-5-5 max vs claude-opus-5-5 medium | 20 | 55% over 20 positions [33%, 69%] | 92% over 16 positions [71%, 100%] | 100% over 1 positions [100%, 100%] |
| Opus efforts | claude-opus-5-5 max vs claude-opus-5-5 off | 0 | – | – | – |
| Opus efforts | claude-opus-5-5 max vs claude-opus-5-5 xhigh | 44 | 84% over 44 positions [44%, 94%] | 94% over 24 positions [74%, 100%] | – |
| Opus efforts | claude-opus-5-5 medium vs claude-opus-5-5 off | 2 | 0% over 2 positions [0%, 0%] | – | – |
| Opus efforts | claude-opus-5-5 medium vs claude-opus-5-5 xhigh | 365 | 88% over 365 positions [86%, 91%] | 92% over 160 positions [90%, 97%] | 89% over 119 positions [78%, 97%] |
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
| Cross-model | 12e2e3295899 | 5.8% (373/6466) [4.8%, 6.8%] | 26% (2782/10702) [25%, 27%] | 450 |
| Cross-model | 18b65a259496 | 11% (39/342) [6.8%, 17%] | 29% (176/609) [25%, 33%] | 52 |
| Cross-model | 1af2b6e43774 | 3.9% (36/924) [2.2%, 5.8%] | 32% (472/1458) [30%, 35%] | 120 |
| Cross-model | 29f99c6dce47 | 20% (291/1445) [18%, 23%] | 24% (594/2504) [22%, 26%] | 100 |
| Cross-model | 2a5f469d8793 | 4.7% (472/10132) [4.2%, 5.2%] | 28% (4673/16435) [28%, 29%] | 675 |
| Cross-model | 3c9b98f8b3f4 | 4.4% (39/888) [2.5%, 6.8%] | 26% (383/1491) [23%, 29%] | 63 |
| Cross-model | 452a3a2e13a5d1252875796eac0ee0fac2f43d55 | 0.3% (2/604) [0%, 0.8%] | 33% (318/975) [29%, 36%] | 80 |
| Cross-model | 51408f692c1c67edd7db0425dbbb37fac8ab4db8 | 16% (1308/8131) [15%, 17%] | 32% (4448/13906) [31%, 33%] | 1198 |
| Cross-model | 51b8366684f0 | 7.3% (439/6022) [6.3%, 8.4%] | 25% (2539/10172) [24%, 26%] | 420 |
| Cross-model | 9e7d7ff22891 | 4.0% (68/1685) [2.7%, 5.6%] | 26% (744/2818) [24%, 29%] | 118 |
| Cross-model | b72cdce126f2 | 6.9% (35/510) [3.5%, 11%] | 30% (242/817) [26%, 33%] | 34 |
| Astra efforts | 12e2e3295899 | 0% (0/52) [0%, 0%] | 41% (32/79) [38%, 43%] | 4 |
| Astra efforts | 2a5f469d8793 | 0% (0/53) [0%, 0%] | 27% (24/90) [22%, 33%] | 4 |
| Astra efforts | b72cdce126f2 | 0% (0/11) [0%, 0%] | 25% (5/20) [25%, 25%] | 1 |
| Haiku 4.5 efforts | 51b8366684f0 | 17% (19/114) [9.2%, 24%] | 15% (37/251) [13%, 17%] | 12 |
| Haiku 4.5 efforts | 9e7d7ff22891 | 25% (675/2740) [23%, 27%] | 21% (1047/5107) [19%, 22%] | 188 |
| Haiku 5.5 efforts | 51b8366684f0 | 12% (22/188) [7.6%, 16%] | 16% (57/354) [11%, 22%] | 20 |
| Haiku 5.5 efforts | 9e7d7ff22891 | 14% (571/4041) [13%, 16%] | 27% (1812/6646) [26%, 29%] | 280 |
| Luna efforts | 9e7d7ff22891 | 20% (886/4441) [18%, 22%] | 24% (1803/7600) [22%, 25%] | 300 |
| Opus efforts | 12e2e3295899 | 0.3% (2/590) [0%, 0.8%] | 31% (274/888) [27%, 36%] | 36 |
| Opus efforts | 2a5f469d8793 | 0% (0/262) [0%, 0%] | 26% (114/431) [23%, 30%] | 19 |
| Opus efforts | 9e7d7ff22891 | 0.1% (1/1134) [0%, 0.3%] | 30% (545/1838) [26%, 33%] | 80 |
| Opus efforts | b72cdce126f2 | 0% (0/23) [0%, 0%] | 30% (11/37) [29%, 30%] | 2 |
| Sol efforts | 9e7d7ff22891 | 0.7% (20/2830) [0.4%, 1.0%] | 29% (1337/4690) [27%, 30%] | 200 |
| Sonnet efforts | 51b8366684f0 | 0% (0/55) [0%, 0%] | 24% (22/91) [20%, 26%] | 5 |
| Sonnet efforts | 9e7d7ff22891 | 0.9% (40/4328) [0.6%, 1.3%] | 29% (2020/6969) [28%, 30%] | 295 |
| Terra 6.1 efforts | 12e2e3295899 | 0% (0/227) [0%, 0%] | 30% (107/359) [22%, 37%] | 14 |
| Terra 6.1 efforts | 2a5f469d8793 | 1.1% (3/272) [0%, 2.3%] | 35% (150/427) [30%, 41%] | 17 |
| Terra efforts | 9e7d7ff22891 | 4.0% (114/2886) [3.1%, 4.8%] | 25% (1209/4858) [23%, 27%] | 200 |
<!-- beliefs:end -->
