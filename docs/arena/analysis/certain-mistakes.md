# Certain mistakes

How often each config made a shot that its own information proves worse than the other shot, within the round. This is not bad odds, minimax disagreement or regret. A mistake counts only where an exact argument from the rules shows the other shot is better on every line. Each certain mistake has its own opportunities:

1. **Shot itself on a proven live.** Opportunities: agent decisions where the player's own information proves the chambered shell is live. Mistakes: the player shot itself.
2. **Shot the opponent, giving up a guaranteed win.** Opportunities: agent decisions where the player's own information proves the chambered shell is blank and the next shell live. The opponent must show its health (not jammed) and that health must die to the player's next shot. The player's own health must die to the opponent's next shot. Mistakes: the player shot the opponent. With a jammed opponent the board hides its health, so those decisions are excluded and counted.

An opportunity is every decision where the mistake was a legal move, item moves included: it measures the ability to make the mistake. A turn with item moves before the shot is several opportunities. [beliefs-and-items.md](beliefs-and-items.md) divides by shots instead, so its rates are higher.

Every other proven blank is the fact pattern **proven blank, gave the turn away**. Its rate is the share of those decisions where the player shot the opponent. It is never a certain-mistake rate, because there keeping the move is not proven better.

An item move at an opportunity is never a mistake. Only the chosen shot is judged. Everything is proven within the current round, like [regret](regret.md), and not for the match. A round's first death decides who starts the next round (`first.override` in `sim/bend-mp/sm/main.bend`), and the round prizes rise, so only in the last round would the proof extend to the match. For type 1 the dominance is weak: in a round already won or lost on every line, both shots end the same.

## How it is measured

**Proves.** From `_work/arena/analysis/derived/knowledge.sqlite`, built by `web/scripts/arena-knowledge.ts` ([beliefs-and-items.md](beliefs-and-items.md)). `chamber` is set only when every shell order the player's own log allows has the same chambered shell. `private_known` lists the positions that every allowed order agrees on, so `2L` means the next shell is proven live. The log is the public events and the player's own secrets: counting, the magnifying glass, the burner phone, or several of them together. The opponent's secrets never enter. A shell that is only likely live is not proven. A clue made stale by an inverter is not used either, because the belief replays the inverter. Health and items come from the same rows. Nothing here rebuilds beliefs or applies rules.

**Why the other shot is better.** From `shoot.loaded`, `turn.end` and `grant` in `sim/bend-mp/sm/main.bend`. Either shot fires the same shell and removes it from the gun. Either shot also clears the saw, so the next shooter can saw again. Neither shot changes items, clues or the rest of the gun.

- *Live.* Either shot passes the turn the same way, including the skip of a jammed opponent. On the last shell, either starts the same reload. The only difference is whose health falls, by one, or by two with the saw. Elsewhere the rules read health only to ask whether a seat is alive (legal targets, turn order, dealing, the win check) and to stop cigarettes healing past full. So the side with more health can make the same moves and never does worse in the round.
- *Blank, guaranteed win.* Shooting itself keeps the move. The player then shoots the opponent with the proven live and kills it, with its own saw if it needs two damage. The opponent never moves, so this wins on every line. Shooting the opponent passes the move. The opponent can then shoot the player with the same live and kill it, with its own saw if it needs two. So the opponent shot can lose, while the self shot cannot.
- *Blank, any other case.* The self shot still keeps the move, and the opponent shot still passes it, or with a jammed opponent spends the jam's skip. That keeping the move is never worse has no proof: the rules have no pass move. The table below splits these decisions by what the depth-6 search in `regret.sqlite` scored for the two shots. Settled scores there are not used as proof. The modelled opponent picks its move by the expected score over public information, so a settled score is a result against that one opponent, not against every play.

**Counted.** Completed matches only, agent decisions only (no forced grabs or fallback moves), and no match with a DeepSeek seat. All matches are two-player. A config is `players.model` plus effort, pooled over cohorts and code versions. Each rate has a 95% interval from 2,000 seeded resamples of seed blocks. A cell with fewer than 20 decisions shows only its count. The `all` row pools every config.

## Reproduce

Inside `nix develop`, from the repository root:

    python3 tools/arena/analysis/certain_mistakes.py --doc docs/arena/analysis/certain-mistakes.md
    cd tools/arena/analysis && python3 -m unittest discover -s .

`--opportunities FILE` also writes every decision with a proven chambered shell to a SQLite file, one row per decision: match, ordinal, player, type (`self_on_live`, `gave_up_guaranteed_win`, `hidden_health`, `gave_turn_away`), outcome (`mistake`, `not a mistake`, `excluded`, `fact pattern`) and the source of the proof. A second table, `rates`, holds each config's, each model's and every config's counts and 95% interval per type, computed as the tables below are, so the viewer shows these numbers exactly. The arena viewer reads that file with `--certain-mistakes` to show these rates and to mark the mistakes in its replay, so the classifier lives only here.

# Tables

<!-- tables:start -->
### Certain mistakes by config

| model | effort | shot itself on a proven live | shot the opponent, giving up a guaranteed win | excluded: proven blank, proven live next, opponent jammed |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 | off | 4.4% (24/549) [2.6%, 6.5%] | 2/3 | 11 |
| claude-haiku-4-5-20251001 | minimal | 3.8% (20/533) [2.3%, 5.5%] | 1/4 | 10 |
| claude-haiku-4-5-20251001 | low | 2.6% (15/587) [1.5%, 3.8%] | 0/1 | 13 |
| claude-haiku-4-5-20251001 | medium | 2.3% (32/1409) [1.5%, 3.2%] | 1/6 | 33 |
| claude-haiku-4-5-20251001 | high | 2.5% (14/561) [1.2%, 4.1%] | 0/1 | 10 |
| claude-haiku-5-5 | off | 0.0% (0/572) [0.0%, 0.0%] | – | 17 |
| claude-haiku-5-5 | low | 0.5% (4/737) [0.1%, 1.1%] | 0/6 | 21 |
| claude-haiku-5-5 | medium | 0.5% (10/1953) [0.2%, 0.9%] | 1/11 | 52 |
| claude-haiku-5-5 | high | 0.4% (3/760) [0.0%, 0.9%] | 0/3 | 19 |
| claude-haiku-5-5 | xhigh | 0.0% (0/844) [0.0%, 0.0%] | 0/5 | 25 |
| claude-haiku-5-5 | max | 0.0% (0/872) [0.0%, 0.0%] | 0/2 | 19 |
| claude-opus-5-5 | off | 0.0% (0/55) [0.0%, 0.0%] | 0/1 | 1 |
| claude-opus-5-5 | low | 0.0% (0/223) [0.0%, 0.0%] | 0/1 | 7 |
| claude-opus-5-5 | medium | 0.1% (1/1799) [0.0%, 0.2%] | 0/11 | 54 |
| claude-opus-5-5 | high | 0.0% (0/339) [0.0%, 0.0%] | – | 7 |
| claude-opus-5-5 | xhigh | 0.0% (0/579) [0.0%, 0.0%] | 0/3 | 14 |
| claude-opus-5-5 | max | 0.0% (0/79) [0.0%, 0.0%] | – | 1 |
| claude-sonnet-5-5 | off | 0.7% (6/816) [0.1%, 1.5%] | 0/3 | 11 |
| claude-sonnet-5-5 | low | 0.3% (2/725) [0.0%, 0.7%] | 0/5 | 9 |
| claude-sonnet-5-5 | medium | 0.3% (7/2044) [0.1%, 0.6%] | 0/7 | 36 |
| claude-sonnet-5-5 | high | 0.2% (2/805) [0.0%, 0.6%] | 0/5 | 26 |
| claude-sonnet-5-5 | xhigh | 0.0% (0/815) [0.0%, 0.0%] | 0/1 | 22 |
| claude-sonnet-5-5 | max | 0.0% (0/893) [0.0%, 0.0%] | 0/3 | 24 |
| gpt-5.6-terra | low | 1.9% (10/515) [0.8%, 3.3%] | 0/3 | 19 |
| gpt-5.6-terra | medium | 0.8% (12/1443) [0.4%, 1.3%] | 0/7 | 52 |
| gpt-5.6-terra | high | 2.1% (11/530) [1.1%, 3.3%] | 0/1 | 21 |
| gpt-5.6-terra | xhigh | 0.7% (4/599) [0.2%, 1.3%] | 0/4 | 22 |
| gpt-5.6-terra | max | 0.2% (1/665) [0.0%, 0.5%] | 0/3 | 19 |
| gpt-6-astra | low | 0.0% (0/39) [0.0%, 0.0%] | – | 0 |
| gpt-6-astra | medium | 0.0% (0/1446) [0.0%, 0.0%] | 0/13 | 22 |
| gpt-6-astra | high | 0.0% (0/43) [0.0%, 0.0%] | – | 0 |
| gpt-6-luna | off | 11.3% (80/707) [9.2%, 13.6%] | 0/1 | 29 |
| gpt-6-luna | low | 12.0% (87/726) [9.1%, 15.1%] | – | 26 |
| gpt-6-luna | medium | 8.6% (153/1775) [7.2%, 10.0%] | 0/7 | 52 |
| gpt-6-luna | high | 3.7% (29/784) [2.6%, 4.8%] | 0/4 | 28 |
| gpt-6-luna | xhigh | 2.6% (22/834) [1.6%, 3.7%] | 1/1 | 27 |
| gpt-6-luna | max | 2.2% (19/850) [1.3%, 3.3%] | 0/3 | 40 |
| gpt-6.1-sol | low | 0.0% (0/544) [0.0%, 0.0%] | 0/2 | 13 |
| gpt-6.1-sol | medium | 0.0% (0/1773) [0.0%, 0.0%] | 0/9 | 34 |
| gpt-6.1-sol | high | 0.0% (0/584) [0.0%, 0.0%] | – | 10 |
| gpt-6.1-sol | xhigh | 0.0% (0/629) [0.0%, 0.0%] | 0/7 | 13 |
| gpt-6.1-sol | max | 0.0% (0/653) [0.0%, 0.0%] | 0/6 | 13 |
| gpt-6.1-terra | off | 0.0% (0/35) [0.0%, 0.0%] | 0/1 | 1 |
| gpt-6.1-terra | low | 0.0% (0/51) [0.0%, 0.0%] | – | 1 |
| gpt-6.1-terra | medium | 0.0% (0/94) [0.0%, 0.0%] | 0/1 | 3 |
| gpt-6.1-terra | high | 0.0% (0/53) [0.0%, 0.0%] | – | 2 |
| gpt-6.1-terra | xhigh | 0.0% (0/55) [0.0%, 0.0%] | – | 0 |
| gpt-6.1-terra | max | 0.0% (0/46) [0.0%, 0.0%] | – | 1 |
| all |  | 1.7% (568/34022) [1.5%, 1.9%] | 3.9% (6/155) [1.3%, 7.2%] | 890 |

### Not a certain mistake: proven blank, gave the turn away, by config

| model | effort | shot the opponent on a proven blank |
|---|---|---|
| claude-haiku-4-5-20251001 | off | 38.2% (163/427) [33.6%, 43.1%] |
| claude-haiku-4-5-20251001 | minimal | 33.2% (133/401) [27.5%, 38.6%] |
| claude-haiku-4-5-20251001 | low | 29.8% (114/382) [25.2%, 34.4%] |
| claude-haiku-4-5-20251001 | medium | 29.3% (270/923) [25.9%, 32.8%] |
| claude-haiku-4-5-20251001 | high | 32.0% (118/369) [27.9%, 36.6%] |
| claude-haiku-5-5 | off | 36.9% (161/436) [31.8%, 42.3%] |
| claude-haiku-5-5 | low | 27.7% (130/470) [23.9%, 31.2%] |
| claude-haiku-5-5 | medium | 21.0% (253/1202) [18.9%, 23.4%] |
| claude-haiku-5-5 | high | 21.3% (101/475) [17.2%, 25.2%] |
| claude-haiku-5-5 | xhigh | 17.5% (77/441) [13.8%, 21.3%] |
| claude-haiku-5-5 | max | 8.7% (41/469) [6.2%, 11.5%] |
| claude-opus-5-5 | off | 0.0% (0/25) [0.0%, 0.0%] |
| claude-opus-5-5 | low | 1.0% (1/104) [0.0%, 3.1%] |
| claude-opus-5-5 | medium | 0.2% (2/914) [0.0%, 0.6%] |
| claude-opus-5-5 | high | 0.0% (0/172) [0.0%, 0.0%] |
| claude-opus-5-5 | xhigh | 0.0% (0/303) [0.0%, 0.0%] |
| claude-opus-5-5 | max | 0.0% (0/30) [0.0%, 0.0%] |
| claude-sonnet-5-5 | off | 3.5% (13/370) [1.6%, 5.8%] |
| claude-sonnet-5-5 | low | 2.2% (9/416) [0.7%, 3.8%] |
| claude-sonnet-5-5 | medium | 1.9% (18/929) [1.1%, 2.9%] |
| claude-sonnet-5-5 | high | 0.3% (1/385) [0.0%, 0.8%] |
| claude-sonnet-5-5 | xhigh | 0.5% (2/426) [0.0%, 1.2%] |
| claude-sonnet-5-5 | max | 0.2% (1/495) [0.0%, 0.6%] |
| gpt-5.6-terra | low | 8.9% (27/305) [5.4%, 12.5%] |
| gpt-5.6-terra | medium | 6.7% (59/877) [5.1%, 8.4%] |
| gpt-5.6-terra | high | 5.7% (19/335) [2.9%, 8.9%] |
| gpt-5.6-terra | xhigh | 3.4% (12/358) [1.6%, 5.4%] |
| gpt-5.6-terra | max | 1.7% (7/408) [0.5%, 3.2%] |
| gpt-6-astra | low | 2/18 |
| gpt-6-astra | medium | 0.7% (5/729) [0.1%, 1.4%] |
| gpt-6-astra | high | 0.0% (0/25) [0.0%, 0.0%] |
| gpt-6-luna | off | 28.5% (157/551) [24.9%, 32.2%] |
| gpt-6-luna | low | 30.5% (157/514) [26.4%, 34.7%] |
| gpt-6-luna | medium | 24.1% (275/1140) [21.6%, 26.6%] |
| gpt-6-luna | high | 13.9% (69/497) [10.8%, 17.0%] |
| gpt-6-luna | xhigh | 12.4% (60/484) [8.8%, 16.0%] |
| gpt-6-luna | max | 11.8% (60/508) [9.0%, 14.9%] |
| gpt-6.1-sol | low | 2.5% (7/281) [0.8%, 4.5%] |
| gpt-6.1-sol | medium | 1.5% (14/953) [0.8%, 2.3%] |
| gpt-6.1-sol | high | 2.1% (7/330) [0.8%, 3.8%] |
| gpt-6.1-sol | xhigh | 1.2% (4/340) [0.3%, 2.4%] |
| gpt-6.1-sol | max | 0.6% (2/348) [0.0%, 1.5%] |
| gpt-6.1-terra | off | 0.0% (0/21) [0.0%, 0.0%] |
| gpt-6.1-terra | low | 0.0% (0/25) [0.0%, 0.0%] |
| gpt-6.1-terra | medium | 0.0% (0/50) [0.0%, 0.0%] |
| gpt-6.1-terra | high | 0.0% (0/25) [0.0%, 0.0%] |
| gpt-6.1-terra | xhigh | 0.0% (0/27) [0.0%, 0.0%] |
| gpt-6.1-terra | max | 0.0% (0/21) [0.0%, 0.0%] |
| all |  | 12.9% (2551/19734) [12.1%, 13.7%] |

### Not a certain mistake: proven blank, gave the turn away, by what the search scored, all configs

| opponent jammed | search scores the opponent shot higher | search settles the self shot as a win and the opponent shot as a loss | the rest | no search |
|---|---|---|---|---|
| 18.0% (650/3604) [16.4%, 19.7%] | 5.0% (13/262) [2.5%, 7.6%] | 2.6% (5/190) [0.5%, 5.7%] | 12.0% (1883/15678) [11.2%, 12.8%] | – |

### By source of the proof and shells left, all configs

| pattern | public | glass | phone | combined | last shell | earlier shells |
|---|---|---|---|---|---|---|
| shot itself on a proven live | 2.3% (450/19250) [2.1%, 2.6%] | 0.1% (17/12000) [0.1%, 0.2%] | 3.7% (100/2720) [2.9%, 4.5%] | 1.9% (1/52) [0.0%, 5.9%] | 2.8% (331/11965) [2.4%, 3.1%] | 1.1% (237/22057) [0.9%, 1.3%] |
| shot the opponent, giving up a guaranteed win | 1/1 | 2.6% (3/115) [0.0%, 6.1%] | 2.8% (1/36) [0.0%, 8.6%] | 1/3 | – | 3.9% (6/155) [1.3%, 7.2%] |
| proven blank, gave the turn away | 17.8% (2054/11562) [16.6%, 18.9%] | 3.9% (226/5859) [3.2%, 4.5%] | 12.0% (270/2256) [10.3%, 13.6%] | 1.8% (1/57) [0.0%, 5.6%] | 19.3% (1513/7830) [18.0%, 20.7%] | 8.7% (1038/11904) [8.0%, 9.5%] |
<!-- tables:end -->
