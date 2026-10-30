# Certain mistakes

How often each config made a shot that its own information proves worse than the other shot. This is not bad odds, minimax disagreement or regret. A mistake counts only where an exact argument from the rules shows the other shot is better on every line. Each certain mistake has its own opportunities:

1. **Shot itself on a proven live.** Opportunities: agent decisions where the player's own information proves the chambered shell is live. Mistakes: the player shot itself.
2. **Shot the opponent, giving up a guaranteed win.** Opportunities: agent decisions where the player's own information proves the chambered shell is blank and the next shell live. The opponent must show its health (not jammed) and that health must die to the player's next shot. The player's own health must die to the opponent's next shot. Mistakes: the player shot the opponent.

Every other proven blank is the fact pattern **proven blank, gave the turn away**. Its rate is the share of those decisions where the player shot the opponent. It is never a certain-mistake rate, because there keeping the move is not proven better.

An item move at an opportunity is never a mistake. Only the chosen shot is judged. All of it is scored on the current round, like [regret](regret.md). A round's first death decides who starts the next round (`first.override` in `sim/bend-mp/sm/main.bend`), so the effect on the match is not proven.

## How it is measured

**Proves.** From `_work/arena/analysis/derived/knowledge.sqlite`, built by `web/scripts/arena-knowledge.ts` ([beliefs-and-items.md](beliefs-and-items.md)). `chamber` is set only when every shell order the player's own log allows has the same chambered shell. `private_known` lists the positions that every allowed order agrees on, so `2L` means the next shell is proven live. The log is the public events and the player's own secrets: counting, the magnifying glass, the burner phone, or several of them together. The opponent's secrets never enter. A shell that is only likely live is not proven. A clue made stale by an inverter is not used either, because the belief replays the inverter. Health and items come from the same rows. Nothing here rebuilds beliefs or applies rules.

**Why the other shot is better.** From `shoot.loaded`, `turn.end` and `grant` in `sim/bend-mp/sm/main.bend`. Either shot fires the same shell and removes it from the gun. Either shot also clears the saw, so the next shooter can saw again. Neither shot changes items, clues or what anyone sees.

- *Live.* Either shot passes the turn the same way, including the skip of a jammed opponent. On the last shell, either starts the same reload. The only difference is whose health falls, by one, or by two with the saw. Elsewhere the rules read health only to ask whether a seat is alive (legal targets, turn order, dealing, the win check) and to stop cigarettes healing past full. So the side with more health can make the same moves and never does worse in the round.
- *Blank, guaranteed win.* Shooting itself keeps the move. The player then shoots the opponent with the proven live and kills it, with its own saw if it needs two damage. The opponent never moves, so this wins on every line. Shooting the opponent passes the move. The opponent can then shoot the player with the same live and kill it, with its own saw if it needs two. So the opponent shot can lose, while the self shot cannot.
- *Blank, any other case.* The self shot still keeps the move, and the opponent shot still passes it, or with a jammed opponent spends the jam's skip. That keeping the move is never worse has no proof: the rules have no pass move. The table below splits these decisions by what the depth-6 search in `regret.sqlite` scored for the two shots. Settled scores there are not used as proof. The modelled opponent picks its move by the expected score over public information, so a settled score is a result against that one opponent, not against every play.

**Counted.** Completed matches only, agent decisions only (no forced grabs or fallback moves), and no match with a DeepSeek seat. All matches are two-player. A config is `players.model` plus effort, pooled over cohorts and code versions. Each rate has a 95% interval from 2,000 seeded resamples of seed blocks.

## Reproduce

Inside `nix develop`, from the repository root:

    python3 tools/arena/analysis/certain_mistakes.py --doc docs/arena/analysis/certain-mistakes.md
    cd tools/arena/analysis && python3 -m unittest discover -s .

# Tables

<!-- tables:start -->
### By config

| model | effort | shot itself on a proven live | shot the opponent, giving up a guaranteed win | proven blank, gave the turn away |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 | off | 4.4% (24/549) [2.6%, 6.5%] | 66.7% (2/3) [0.0%, 100.0%] | 37.9% (166/438) [33.2%, 42.9%] |
| claude-haiku-4-5-20251001 | minimal | 3.8% (20/533) [2.2%, 5.5%] | 25.0% (1/4) [0.0%, 50.0%] | 33.3% (137/411) [27.5%, 39.2%] |
| claude-haiku-4-5-20251001 | low | 2.6% (15/587) [1.5%, 3.8%] | 0.0% (0/1) [0.0%, 0.0%] | 30.6% (121/395) [25.6%, 35.5%] |
| claude-haiku-4-5-20251001 | medium | 2.3% (32/1409) [1.5%, 3.2%] | 16.7% (1/6) [0.0%, 50.0%] | 29.3% (280/956) [25.8%, 32.7%] |
| claude-haiku-4-5-20251001 | high | 2.5% (14/561) [1.2%, 4.1%] | 0.0% (0/1) [0.0%, 0.0%] | 31.9% (121/379) [27.9%, 36.4%] |
| claude-haiku-5-5 | off | 0.0% (0/572) [0.0%, 0.0%] | – | 37.1% (168/453) [32.1%, 42.1%] |
| claude-haiku-5-5 | low | 0.5% (4/737) [0.1%, 1.1%] | 0.0% (0/6) [0.0%, 0.0%] | 27.1% (133/491) [23.6%, 30.7%] |
| claude-haiku-5-5 | medium | 0.5% (10/1953) [0.2%, 0.8%] | 9.1% (1/11) [0.0%, 30.0%] | 20.7% (260/1254) [18.4%, 23.0%] |
| claude-haiku-5-5 | high | 0.4% (3/760) [0.0%, 0.9%] | 0.0% (0/3) [0.0%, 0.0%] | 20.4% (101/494) [16.5%, 24.4%] |
| claude-haiku-5-5 | xhigh | 0.0% (0/844) [0.0%, 0.0%] | 0.0% (0/5) [0.0%, 0.0%] | 16.7% (78/466) [13.6%, 20.0%] |
| claude-haiku-5-5 | max | 0.0% (0/872) [0.0%, 0.0%] | 0.0% (0/2) [0.0%, 0.0%] | 8.4% (41/488) [5.9%, 11.1%] |
| claude-opus-5-5 | off | 0.0% (0/55) [0.0%, 0.0%] | 0.0% (0/1) [0.0%, 0.0%] | 0.0% (0/26) [0.0%, 0.0%] |
| claude-opus-5-5 | low | 0.0% (0/223) [0.0%, 0.0%] | 0.0% (0/1) [0.0%, 0.0%] | 0.9% (1/111) [0.0%, 3.0%] |
| claude-opus-5-5 | medium | 0.1% (1/1799) [0.0%, 0.2%] | 0.0% (0/11) [0.0%, 0.0%] | 0.2% (2/968) [0.0%, 0.5%] |
| claude-opus-5-5 | high | 0.0% (0/339) [0.0%, 0.0%] | – | 0.0% (0/179) [0.0%, 0.0%] |
| claude-opus-5-5 | xhigh | 0.0% (0/579) [0.0%, 0.0%] | 0.0% (0/3) [0.0%, 0.0%] | 0.0% (0/317) [0.0%, 0.0%] |
| claude-opus-5-5 | max | 0.0% (0/79) [0.0%, 0.0%] | – | 0.0% (0/31) [0.0%, 0.0%] |
| claude-sonnet-5-5 | off | 0.7% (6/816) [0.1%, 1.5%] | 0.0% (0/3) [0.0%, 0.0%] | 3.4% (13/381) [1.5%, 5.6%] |
| claude-sonnet-5-5 | low | 0.3% (2/725) [0.0%, 0.7%] | 0.0% (0/5) [0.0%, 0.0%] | 2.4% (10/425) [0.9%, 4.2%] |
| claude-sonnet-5-5 | medium | 0.3% (7/2044) [0.1%, 0.6%] | 0.0% (0/7) [0.0%, 0.0%] | 1.9% (18/965) [1.0%, 2.8%] |
| claude-sonnet-5-5 | high | 0.2% (2/805) [0.0%, 0.6%] | 0.0% (0/5) [0.0%, 0.0%] | 0.2% (1/411) [0.0%, 0.8%] |
| claude-sonnet-5-5 | xhigh | 0.0% (0/815) [0.0%, 0.0%] | 0.0% (0/1) [0.0%, 0.0%] | 0.7% (3/448) [0.0%, 1.5%] |
| claude-sonnet-5-5 | max | 0.0% (0/893) [0.0%, 0.0%] | 0.0% (0/3) [0.0%, 0.0%] | 0.2% (1/519) [0.0%, 0.6%] |
| gpt-5.6-terra | low | 1.9% (10/515) [0.8%, 3.3%] | 0.0% (0/3) [0.0%, 0.0%] | 8.3% (27/324) [5.0%, 11.9%] |
| gpt-5.6-terra | medium | 0.8% (12/1443) [0.4%, 1.3%] | 0.0% (0/7) [0.0%, 0.0%] | 6.5% (60/929) [4.9%, 8.1%] |
| gpt-5.6-terra | high | 2.1% (11/530) [1.1%, 3.3%] | 0.0% (0/1) [0.0%, 0.0%] | 5.6% (20/356) [3.0%, 8.4%] |
| gpt-5.6-terra | xhigh | 0.7% (4/599) [0.2%, 1.4%] | 0.0% (0/4) [0.0%, 0.0%] | 3.7% (14/380) [2.0%, 5.7%] |
| gpt-5.6-terra | max | 0.2% (1/665) [0.0%, 0.5%] | 0.0% (0/3) [0.0%, 0.0%] | 1.9% (8/427) [0.7%, 3.3%] |
| gpt-6-astra | low | 0.0% (0/39) [0.0%, 0.0%] | – | 11.1% (2/18) [0.0%, 42.9%] |
| gpt-6-astra | medium | 0.0% (0/1446) [0.0%, 0.0%] | 0.0% (0/13) [0.0%, 0.0%] | 0.7% (5/751) [0.1%, 1.4%] |
| gpt-6-astra | high | 0.0% (0/43) [0.0%, 0.0%] | – | 0.0% (0/25) [0.0%, 0.0%] |
| gpt-6-luna | off | 11.3% (80/707) [9.1%, 13.4%] | 0.0% (0/1) [0.0%, 0.0%] | 28.3% (164/580) [24.9%, 31.8%] |
| gpt-6-luna | low | 12.0% (87/726) [9.0%, 15.2%] | – | 31.3% (169/540) [27.4%, 35.0%] |
| gpt-6-luna | medium | 8.6% (153/1775) [7.3%, 10.1%] | 0.0% (0/7) [0.0%, 0.0%] | 24.4% (291/1192) [21.9%, 26.9%] |
| gpt-6-luna | high | 3.7% (29/784) [2.7%, 4.8%] | 0.0% (0/4) [0.0%, 0.0%] | 13.9% (73/525) [11.2%, 16.9%] |
| gpt-6-luna | xhigh | 2.6% (22/834) [1.7%, 3.7%] | 100.0% (1/1) [100.0%, 100.0%] | 11.9% (61/511) [8.7%, 15.3%] |
| gpt-6-luna | max | 2.2% (19/850) [1.3%, 3.3%] | 0.0% (0/3) [0.0%, 0.0%] | 11.1% (61/548) [8.4%, 14.1%] |
| gpt-6.1-sol | low | 0.0% (0/544) [0.0%, 0.0%] | 0.0% (0/2) [0.0%, 0.0%] | 2.4% (7/294) [0.7%, 4.2%] |
| gpt-6.1-sol | medium | 0.0% (0/1773) [0.0%, 0.0%] | 0.0% (0/9) [0.0%, 0.0%] | 1.4% (14/987) [0.7%, 2.2%] |
| gpt-6.1-sol | high | 0.0% (0/584) [0.0%, 0.0%] | – | 2.1% (7/340) [0.8%, 3.8%] |
| gpt-6.1-sol | xhigh | 0.0% (0/629) [0.0%, 0.0%] | 0.0% (0/7) [0.0%, 0.0%] | 1.1% (4/353) [0.3%, 2.4%] |
| gpt-6.1-sol | max | 0.0% (0/653) [0.0%, 0.0%] | 0.0% (0/6) [0.0%, 0.0%] | 0.6% (2/361) [0.0%, 1.4%] |
| gpt-6.1-terra | off | 0.0% (0/35) [0.0%, 0.0%] | 0.0% (0/1) [0.0%, 0.0%] | 0.0% (0/22) [0.0%, 0.0%] |
| gpt-6.1-terra | low | 0.0% (0/51) [0.0%, 0.0%] | – | 0.0% (0/26) [0.0%, 0.0%] |
| gpt-6.1-terra | medium | 0.0% (0/94) [0.0%, 0.0%] | 0.0% (0/1) [0.0%, 0.0%] | 0.0% (0/53) [0.0%, 0.0%] |
| gpt-6.1-terra | high | 0.0% (0/53) [0.0%, 0.0%] | – | 0.0% (0/27) [0.0%, 0.0%] |
| gpt-6.1-terra | xhigh | 0.0% (0/55) [0.0%, 0.0%] | – | 0.0% (0/27) [0.0%, 0.0%] |
| gpt-6.1-terra | max | 0.0% (0/46) [0.0%, 0.0%] | – | 0.0% (0/22) [0.0%, 0.0%] |

### Proven blank, gave the turn away, by what the search scored, all configs

| pattern | opponent jammed | search scores the opponent shot higher | search settles the self shot as a win and the opponent shot as a loss | search scores the self shot higher or equal, not both settled | no search |
|---|---|---|---|---|---|
| proven blank, gave the turn away | 16.5% (743/4494) [15.1%, 18.1%] | 5.0% (13/262) [2.6%, 7.7%] | 2.6% (5/190) [0.5%, 5.6%] | 12.0% (1883/15678) [11.2%, 12.8%] | – |

### By source of the proof and shells left, all configs

| pattern | public | glass | phone | combined | last shell | earlier shells |
|---|---|---|---|---|---|---|
| shot itself on a proven live | 2.3% (450/19250) [2.1%, 2.6%] | 0.1% (17/12000) [0.1%, 0.2%] | 3.7% (100/2720) [2.9%, 4.5%] | 1.9% (1/52) [0.0%, 5.7%] | 2.8% (331/11965) [2.4%, 3.1%] | 1.1% (237/22057) [0.9%, 1.3%] |
| shot the opponent, giving up a guaranteed win | 100.0% (1/1) [100.0%, 100.0%] | 2.6% (3/115) [0.0%, 6.1%] | 2.8% (1/36) [0.0%, 8.6%] | 33.3% (1/3) [0.0%, 100.0%] | – | 3.9% (6/155) [1.3%, 7.2%] |
| proven blank, gave the turn away | 17.8% (2079/11676) [16.7%, 19.0%] | 3.9% (244/6321) [3.3%, 4.5%] | 12.5% (320/2560) [11.0%, 14.1%] | 1.5% (1/67) [0.0%, 4.8%] | 19.3% (1513/7830) [18.1%, 20.6%] | 8.8% (1131/12794) [8.1%, 9.6%] |
<!-- tables:end -->
