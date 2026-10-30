# Certain mistakes

How often each config made a shot that its own information proves worse than the other shot. This is not bad odds, minimax disagreement or regret. A mistake counts only where the rules show the other shot leaves the same game except for one difference that is always worse for the player. Two types, each over its own opportunities:

1. **Shot itself on a proven live.** Opportunities: agent decisions where the player's own information proves the chambered shell is live. Mistakes: the player shot itself.
2. **Shot the opponent on a proven blank.** Opportunities: agent decisions where the player's own information proves the chambered shell is blank. Mistakes: the player shot the opponent.

An item move at an opportunity is never a mistake. Only the chosen shot is judged.

## How it is measured

**Proves.** The `chamber` column of `_work/arena/analysis/derived/knowledge.sqlite`, built by `web/scripts/arena-knowledge.ts` ([beliefs-and-items.md](beliefs-and-items.md)). It is set only when every shell order the player's own log allows has the same chambered shell. The log is the public events and the player's own secrets: counting, the magnifying glass, the burner phone, or several of them together. The opponent's secrets never enter. A shell that is only likely live is not proven. A clue made stale by an inverter is not used either, because the belief replays the inverter. Nothing here rebuilds beliefs or applies rules.

**Why the other shot is better.** From `shoot.loaded` and `turn.end` in `sim/bend-mp/sm/main.bend`. Either shot fires the same shell, removes it from the gun, and spends the saw if one was used, so a sawed shot does double damage to whoever is hit. Neither shot changes items, clues or what anyone sees.

- *Live.* Either shot passes the turn the same way, including the skip of a jammed opponent, and either empties the gun into the same reload. The only difference is whose health falls. Elsewhere the rules read health only to ask whether a seat is alive (legal targets, turn order, dealing, the win check) and to stop cigarettes healing past full. So the side with more health can make the same moves and never does worse in the round. No live case is excluded.
- *Blank.* Shooting itself keeps the move. Shooting the opponent passes it. On the last shell both start the same reload: items are dealt to every seat at once, and only the first move after it differs. If the opponent shows as jammed, shooting it spends the jam's skip and the move comes back. Shooting itself leaves the jam unspent. The two shots then leave different jam states, so neither is proven better, and these decisions are excluded and counted.

**Limits of the argument.**
- It is scored on the current round, like [regret](regret.md). A round's first death decides who starts the next round. So a live shot that changes who dies first also changes the next round's starter. That effect on the match is not proven either way.
- The blank type assumes that having the move is never worse than the opponent having it, with all else equal. The rules have no pass move, so this is a premise, not a proof. The depth-limited search in `regret.sqlite` sometimes scores the opponent shot higher at these decisions, but never with settled scores.

**Counted.** Completed matches only, agent decisions only (no forced grabs or fallback moves), and no match with a DeepSeek seat. All matches are two-player. A config is `players.model` plus effort, pooled over cohorts and code versions. Each rate is mistakes over counted opportunities (opportunities minus exclusions), with a 95% interval from 2,000 seeded resamples of seed blocks.

## Reproduce

Inside `nix develop`, from the repository root:

    python3 tools/arena/analysis/certain_mistakes.py --doc docs/arena/analysis/certain-mistakes.md
    cd tools/arena/analysis && python3 -m unittest discover -s .

# Tables

<!-- tables:start -->
### By config

| model | effort | proven live | shot itself | proven blank | excluded, opponent jammed | shot the opponent |
|---|---|---|---|---|---|---|
| claude-haiku-4-5-20251001 | off | 549 | 4.4% (24/549) [2.6%, 6.5%] | 441 | 68 | 37.0% (138/373) [32.2%, 42.4%] |
| claude-haiku-4-5-20251001 | minimal | 533 | 3.8% (20/533) [2.3%, 5.5%] | 415 | 68 | 31.1% (108/347) [25.3%, 36.5%] |
| claude-haiku-4-5-20251001 | low | 587 | 2.6% (15/587) [1.5%, 3.8%] | 396 | 79 | 28.1% (89/317) [22.8%, 33.2%] |
| claude-haiku-4-5-20251001 | medium | 1,409 | 2.3% (32/1409) [1.5%, 3.2%] | 962 | 200 | 26.5% (202/762) [23.0%, 30.2%] |
| claude-haiku-4-5-20251001 | high | 561 | 2.5% (14/561) [1.2%, 4.1%] | 380 | 89 | 29.2% (85/291) [24.6%, 34.9%] |
| claude-haiku-5-5 | off | 572 | 0.0% (0/572) [0.0%, 0.0%] | 453 | 68 | 35.3% (136/385) [30.3%, 40.7%] |
| claude-haiku-5-5 | low | 737 | 0.5% (4/737) [0.1%, 1.1%] | 497 | 91 | 21.4% (87/406) [18.0%, 25.3%] |
| claude-haiku-5-5 | medium | 1,953 | 0.5% (10/1953) [0.2%, 0.8%] | 1,265 | 282 | 17.6% (173/983) [15.5%, 19.7%] |
| claude-haiku-5-5 | high | 760 | 0.4% (3/760) [0.0%, 0.9%] | 497 | 111 | 18.9% (73/386) [14.9%, 23.1%] |
| claude-haiku-5-5 | xhigh | 844 | 0.0% (0/844) [0.0%, 0.0%] | 471 | 104 | 15.3% (56/367) [11.4%, 19.1%] |
| claude-haiku-5-5 | max | 872 | 0.0% (0/872) [0.0%, 0.0%] | 490 | 117 | 7.2% (27/373) [4.6%, 10.1%] |
| claude-opus-5-5 | off | 55 | 0.0% (0/55) [0.0%, 0.0%] | 27 | 4 | 0.0% (0/23) [0.0%, 0.0%] |
| claude-opus-5-5 | low | 223 | 0.0% (0/223) [0.0%, 0.0%] | 112 | 25 | 1.1% (1/87) [0.0%, 3.6%] |
| claude-opus-5-5 | medium | 1,799 | 0.1% (1/1799) [0.0%, 0.2%] | 979 | 203 | 0.3% (2/776) [0.0%, 0.7%] |
| claude-opus-5-5 | high | 339 | 0.0% (0/339) [0.0%, 0.0%] | 179 | 28 | 0.0% (0/151) [0.0%, 0.0%] |
| claude-opus-5-5 | xhigh | 579 | 0.0% (0/579) [0.0%, 0.0%] | 320 | 57 | 0.0% (0/263) [0.0%, 0.0%] |
| claude-opus-5-5 | max | 79 | 0.0% (0/79) [0.0%, 0.0%] | 31 | 8 | 0.0% (0/23) [0.0%, 0.0%] |
| claude-sonnet-5-5 | off | 816 | 0.7% (6/816) [0.1%, 1.5%] | 384 | 58 | 3.7% (12/326) [1.6%, 6.2%] |
| claude-sonnet-5-5 | low | 725 | 0.3% (2/725) [0.0%, 0.7%] | 430 | 55 | 2.1% (8/375) [0.6%, 3.9%] |
| claude-sonnet-5-5 | medium | 2,044 | 0.3% (7/2044) [0.1%, 0.6%] | 972 | 160 | 1.5% (12/812) [0.7%, 2.4%] |
| claude-sonnet-5-5 | high | 805 | 0.2% (2/805) [0.0%, 0.6%] | 416 | 94 | 0.0% (0/322) [0.0%, 0.0%] |
| claude-sonnet-5-5 | xhigh | 815 | 0.0% (0/815) [0.0%, 0.0%] | 449 | 89 | 0.0% (0/360) [0.0%, 0.0%] |
| claude-sonnet-5-5 | max | 893 | 0.0% (0/893) [0.0%, 0.0%] | 522 | 113 | 0.2% (1/409) [0.0%, 0.8%] |
| gpt-5.6-terra | low | 515 | 1.9% (10/515) [0.8%, 3.3%] | 327 | 90 | 8.9% (21/237) [4.8%, 13.6%] |
| gpt-5.6-terra | medium | 1,443 | 0.8% (12/1443) [0.4%, 1.3%] | 936 | 266 | 7.8% (52/670) [5.9%, 9.7%] |
| gpt-5.6-terra | high | 530 | 2.1% (11/530) [1.0%, 3.3%] | 357 | 99 | 5.8% (15/258) [2.8%, 9.3%] |
| gpt-5.6-terra | xhigh | 599 | 0.7% (4/599) [0.2%, 1.4%] | 384 | 104 | 2.9% (8/280) [1.1%, 5.3%] |
| gpt-5.6-terra | max | 665 | 0.2% (1/665) [0.0%, 0.5%] | 430 | 102 | 0.9% (3/328) [0.0%, 2.1%] |
| gpt-6-astra | low | 39 | 0.0% (0/39) [0.0%, 0.0%] | 18 | 4 | 14.3% (2/14) [0.0%, 46.2%] |
| gpt-6-astra | medium | 1,446 | 0.0% (0/1446) [0.0%, 0.0%] | 764 | 154 | 0.3% (2/610) [0.0%, 0.8%] |
| gpt-6-astra | high | 43 | 0.0% (0/43) [0.0%, 0.0%] | 25 | 2 | 0.0% (0/23) [0.0%, 0.0%] |
| gpt-6-luna | off | 707 | 11.3% (80/707) [9.2%, 13.4%] | 581 | 127 | 25.1% (114/454) [21.5%, 28.7%] |
| gpt-6-luna | low | 726 | 12.0% (87/726) [9.2%, 15.2%] | 540 | 138 | 28.4% (114/402) [23.9%, 32.5%] |
| gpt-6-luna | medium | 1,775 | 8.6% (153/1775) [7.2%, 10.1%] | 1,199 | 295 | 22.8% (206/904) [20.0%, 25.8%] |
| gpt-6-luna | high | 784 | 3.7% (29/784) [2.7%, 4.8%] | 529 | 130 | 12.3% (49/399) [9.3%, 15.5%] |
| gpt-6-luna | xhigh | 834 | 2.6% (22/834) [1.7%, 3.7%] | 512 | 142 | 11.9% (44/370) [8.9%, 15.1%] |
| gpt-6-luna | max | 850 | 2.2% (19/850) [1.3%, 3.3%] | 551 | 187 | 11.0% (40/364) [7.6%, 14.7%] |
| gpt-6.1-sol | low | 544 | 0.0% (0/544) [0.0%, 0.0%] | 296 | 55 | 2.5% (6/241) [0.5%, 4.8%] |
| gpt-6.1-sol | medium | 1,773 | 0.0% (0/1773) [0.0%, 0.0%] | 996 | 204 | 1.3% (10/792) [0.5%, 2.1%] |
| gpt-6.1-sol | high | 584 | 0.0% (0/584) [0.0%, 0.0%] | 340 | 49 | 2.4% (7/291) [0.9%, 4.4%] |
| gpt-6.1-sol | xhigh | 629 | 0.0% (0/629) [0.0%, 0.0%] | 360 | 66 | 0.7% (2/294) [0.0%, 1.9%] |
| gpt-6.1-sol | max | 653 | 0.0% (0/653) [0.0%, 0.0%] | 367 | 78 | 0.7% (2/289) [0.0%, 1.8%] |
| gpt-6.1-terra | off | 35 | 0.0% (0/35) [0.0%, 0.0%] | 23 | 3 | 0.0% (0/20) [0.0%, 0.0%] |
| gpt-6.1-terra | low | 51 | 0.0% (0/51) [0.0%, 0.0%] | 26 | 4 | 0.0% (0/22) [0.0%, 0.0%] |
| gpt-6.1-terra | medium | 94 | 0.0% (0/94) [0.0%, 0.0%] | 54 | 9 | 0.0% (0/45) [0.0%, 0.0%] |
| gpt-6.1-terra | high | 53 | 0.0% (0/53) [0.0%, 0.0%] | 27 | 6 | 0.0% (0/21) [0.0%, 0.0%] |
| gpt-6.1-terra | xhigh | 55 | 0.0% (0/55) [0.0%, 0.0%] | 27 | 3 | 0.0% (0/24) [0.0%, 0.0%] |
| gpt-6.1-terra | max | 46 | 0.0% (0/46) [0.0%, 0.0%] | 22 | 6 | 0.0% (0/16) [0.0%, 0.0%] |

### By source of the proof and shells left, all configs

| mistake | public | glass | phone | combined | last shell | earlier shells |
|---|---|---|---|---|---|---|
| shot itself on a proven live | 2.3% (450/19250) [2.1%, 2.6%] | 0.1% (17/12000) [0.1%, 0.2%] | 3.7% (100/2720) [2.9%, 4.5%] | 1.9% (1/52) [0.0%, 5.7%] | 2.8% (331/11965) [2.4%, 3.1%] | 1.1% (237/22057) [0.9%, 1.3%] |
| shot the opponent on a proven blank | 17.0% (1506/8850) [15.9%, 18.2%] | 3.0% (155/5252) [2.4%, 3.6%] | 11.5% (244/2125) [10.0%, 13.1%] | 3.4% (2/58) [0.0%, 8.2%] | 19.0% (1148/6042) [17.7%, 20.3%] | 7.4% (759/10243) [6.7%, 8.1%] |
<!-- tables:end -->
