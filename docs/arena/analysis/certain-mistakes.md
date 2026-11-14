# Certain mistakes

How often each config made a shot that its own information proves worse than the other shot, within the round. This is not bad odds, minimax disagreement or regret. A mistake counts only where an exact argument from the rules shows the other shot is better on every line. Each certain mistake has its own opportunities:

1. **Shot itself on a proven live.** Opportunities: agent decisions where the player's own information proves the chambered shell is live. Mistakes: the player shot itself.
2. **Shot the opponent, giving up a guaranteed win.** Opportunities: agent decisions where the player's own information proves the chambered shell is blank and the next shell live. The opponent must show its health (not jammed) and that health must die to the player's next shot. The player's own health must die to the opponent's next shot. Mistakes: the player shot the opponent. With a jammed opponent the board hides its health, so those decisions are excluded and counted.

An opportunity is every decision where the mistake was a legal move, item moves included: it measures the ability to make the mistake. A turn with item moves before the shot is several opportunities. [beliefs-and-items.md](beliefs-and-items.md) divides by shots instead, so its rates are higher.

Every other proven blank is the fact pattern **proven blank, gave the turn away**. Its rate is the share of those decisions where the player shot the opponent. It is never a certain-mistake rate, because there keeping the move is not proven better.

An item move at an opportunity is never a mistake. Only the chosen shot is judged. Everything is proven within the current round, like [regret](regret.md), and not for the match. A round's first death decides who starts the next round (`first.override` in `sim/bend-mp/sm/main.bend`), and the round prizes rise, so only in the last round would the proof extend to the match. For type 1 the dominance is weak: in a round already won or lost on every line, both shots end the same.

## How it is measured

**Proves.** From the knowledge database (`derived/knowledge.sqlite` beside the analysis database), built by `web/scripts/arena-knowledge.ts` ([beliefs-and-items.md](beliefs-and-items.md)). `chamber` is set only when every shell order the player's own log allows has the same chambered shell. `private_known` lists the positions that every allowed order agrees on, so `2L` means the next shell is proven live. The log is the public events and the player's own secrets: counting, the magnifying glass, the burner phone, or several of them together. The opponent's secrets never enter. A shell that is only likely live is not proven. A clue made stale by an inverter is not used either, because the belief replays the inverter. Health and items come from the same rows. Nothing here rebuilds beliefs or applies rules.

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
| claude-haiku-4-5-20251001 | off | 4.1% (30/737) [2.6%, 5.7%] | 2/4 | 18 |
| claude-haiku-4-5-20251001 | minimal/low | 3.0% (54/1801) [2.2%, 3.9%] | 1/7 | 36 |
| claude-haiku-4-5-20251001 | medium | 2.5% (49/1958) [1.8%, 3.3%] | 2/9 | 47 |
| claude-haiku-4-5-20251001 | high | 2.5% (21/831) [1.5%, 3.7%] | 0/5 | 13 |
| claude-haiku-5-5 | off | 0.6% (22/3853) [0.3%, 0.8%] | 18.2% (4/22) [4.5%, 33.4%] | 96 |
| claude-haiku-5-5 | low | 0.5% (10/1957) [0.2%, 0.8%] | 1/17 | 43 |
| claude-haiku-5-5 | medium | 0.4% (12/3184) [0.2%, 0.6%] | 1/14 | 94 |
| claude-haiku-5-5 | high | 0.4% (6/1659) [0.1%, 0.6%] | 1/8 | 45 |
| claude-haiku-5-5 | xhigh | 0.0% (0/1224) [0.0%, 0.0%] | 0/8 | 35 |
| claude-haiku-5-5 | max | 0.0% (0/878) [0.0%, 0.0%] | 0/2 | 19 |
| claude-opus-5-5 | off/low | 0.0% (0/1165) [0.0%, 0.0%] | 0/8 | 33 |
| claude-opus-5-5 | medium | 0.0% (1/2468) [0.0%, 0.1%] | 0/15 | 76 |
| claude-opus-5-5 | high | 0.0% (0/582) [0.0%, 0.0%] | 0/1 | 18 |
| claude-opus-5-5 | xhigh | 0.0% (0/1230) [0.0%, 0.0%] | 0/7 | 24 |
| claude-opus-5-5 | max | 0.0% (0/716) [0.0%, 0.0%] | 0/3 | 26 |
| claude-sonnet-5-5 | off | 0.8% (10/1179) [0.3%, 1.5%] | 0/7 | 20 |
| claude-sonnet-5-5 | low | 0.3% (3/1013) [0.0%, 0.7%] | 0/5 | 11 |
| claude-sonnet-5-5 | medium | 0.3% (9/2632) [0.1%, 0.6%] | 0/12 | 49 |
| claude-sonnet-5-5 | high | 0.3% (3/1176) [0.0%, 0.6%] | 0/10 | 35 |
| claude-sonnet-5-5 | xhigh | 0.0% (0/1376) [0.0%, 0.0%] | 0/5 | 36 |
| claude-sonnet-5-5 | max | 0.0% (0/1131) [0.0%, 0.0%] | 0/4 | 26 |
| gpt-5.6-terra | low | 1.9% (10/522) [0.8%, 3.2%] | 0/3 | 19 |
| gpt-5.6-terra | medium | 0.8% (12/1457) [0.4%, 1.3%] | 0/8 | 52 |
| gpt-5.6-terra | high | 2.0% (11/540) [1.1%, 3.2%] | 0/1 | 21 |
| gpt-5.6-terra | xhigh | 0.7% (4/614) [0.2%, 1.3%] | 0/4 | 23 |
| gpt-5.6-terra | max | 0.2% (1/665) [0.0%, 0.5%] | 0/3 | 19 |
| gpt-6-astra | off | 0.0% (0/581) [0.0%, 0.0%] | 0/1 | 15 |
| gpt-6-astra | low | 0.0% (0/551) [0.0%, 0.0%] | 0/1 | 11 |
| gpt-6-astra | medium | 0.0% (0/1698) [0.0%, 0.0%] | 0/15 | 22 |
| gpt-6-astra | high | 0.0% (0/733) [0.0%, 0.0%] | 0/5 | 13 |
| gpt-6-luna | off/low | 11.2% (287/2569) [9.9%, 12.4%] | 0/6 | 93 |
| gpt-6-luna | medium | 8.0% (197/2462) [6.9%, 9.2%] | 1/11 | 70 |
| gpt-6-luna | high | 3.6% (57/1584) [2.7%, 4.6%] | 0/11 | 52 |
| gpt-6-luna | xhigh | 2.7% (23/862) [1.7%, 3.7%] | 1/1 | 28 |
| gpt-6-luna | max | 2.2% (19/862) [1.3%, 3.3%] | 0/3 | 40 |
| gpt-6.1-sol | low | 0.0% (0/595) [0.0%, 0.0%] | 0/2 | 14 |
| gpt-6.1-sol | medium | 0.0% (0/1819) [0.0%, 0.0%] | 0/11 | 36 |
| gpt-6.1-sol | high | 0.0% (0/669) [0.0%, 0.0%] | – | 10 |
| gpt-6.1-sol | xhigh | 0.0% (0/677) [0.0%, 0.0%] | 0/8 | 14 |
| gpt-6.1-sol | max | 0.0% (0/1004) [0.0%, 0.0%] | 0/6 | 15 |
| gpt-6.1-terra | off/low | 0.2% (3/1641) [0.0%, 0.4%] | 2/14 | 33 |
| gpt-6.1-terra | medium | 0.0% (0/902) [0.0%, 0.0%] | 0/7 | 14 |
| gpt-6.1-terra | high | 0.0% (0/606) [0.0%, 0.0%] | 0/4 | 18 |
| gpt-6.1-terra | xhigh | 0.0% (0/741) [0.0%, 0.0%] | – | 19 |
| gpt-6.1-terra | max | 0.0% (0/787) [0.0%, 0.0%] | 0/5 | 17 |
| all |  | 1.5% (854/57891) [1.3%, 1.6%] | 5.3% (16/303) [2.9%, 8.0%] | 1,468 |

### Not a certain mistake: proven blank, gave the turn away, by config

| model | effort | shot the opponent on a proven blank |
|---|---|---|
| claude-haiku-4-5-20251001 | off | 38.0% (213/560) [33.9%, 42.2%] |
| claude-haiku-4-5-20251001 | minimal/low | 29.4% (373/1269) [26.4%, 32.2%] |
| claude-haiku-4-5-20251001 | medium | 30.3% (390/1289) [27.2%, 33.5%] |
| claude-haiku-4-5-20251001 | high | 29.8% (171/573) [26.5%, 33.3%] |
| claude-haiku-5-5 | off | 29.9% (792/2645) [27.9%, 32.0%] |
| claude-haiku-5-5 | low | 23.7% (282/1189) [21.3%, 26.0%] |
| claude-haiku-5-5 | medium | 20.5% (375/1832) [18.6%, 22.4%] |
| claude-haiku-5-5 | high | 19.4% (178/918) [16.4%, 22.3%] |
| claude-haiku-5-5 | xhigh | 16.9% (105/621) [13.7%, 19.7%] |
| claude-haiku-5-5 | max | 8.7% (41/471) [6.2%, 11.5%] |
| claude-opus-5-5 | off/low | 0.4% (2/571) [0.0%, 0.9%] |
| claude-opus-5-5 | medium | 0.3% (4/1245) [0.1%, 0.7%] |
| claude-opus-5-5 | high | 0.0% (0/284) [0.0%, 0.0%] |
| claude-opus-5-5 | xhigh | 0.1% (1/670) [0.0%, 0.5%] |
| claude-opus-5-5 | max | 0.0% (0/310) [0.0%, 0.0%] |
| claude-sonnet-5-5 | off | 4.9% (29/597) [3.0%, 7.0%] |
| claude-sonnet-5-5 | low | 2.7% (15/564) [1.3%, 4.2%] |
| claude-sonnet-5-5 | medium | 1.9% (23/1226) [1.1%, 2.7%] |
| claude-sonnet-5-5 | high | 0.9% (5/563) [0.2%, 1.7%] |
| claude-sonnet-5-5 | xhigh | 0.9% (6/700) [0.3%, 1.6%] |
| claude-sonnet-5-5 | max | 0.3% (2/629) [0.0%, 0.8%] |
| gpt-5.6-terra | low | 8.9% (27/305) [5.4%, 12.5%] |
| gpt-5.6-terra | medium | 6.8% (61/891) [5.2%, 8.6%] |
| gpt-5.6-terra | high | 5.6% (19/338) [3.0%, 8.7%] |
| gpt-5.6-terra | xhigh | 3.3% (12/367) [1.6%, 5.3%] |
| gpt-5.6-terra | max | 1.7% (7/408) [0.5%, 3.2%] |
| gpt-6-astra | off | 2.1% (6/289) [0.4%, 4.2%] |
| gpt-6-astra | low | 1.8% (5/276) [0.3%, 3.8%] |
| gpt-6-astra | medium | 0.7% (6/854) [0.1%, 1.4%] |
| gpt-6-astra | high | 2.0% (7/350) [0.6%, 3.8%] |
| gpt-6-luna | off/low | 30.1% (528/1752) [27.9%, 32.5%] |
| gpt-6-luna | medium | 23.5% (382/1625) [21.5%, 25.6%] |
| gpt-6-luna | high | 12.7% (114/896) [10.6%, 15.0%] |
| gpt-6-luna | xhigh | 11.9% (60/504) [8.5%, 15.6%] |
| gpt-6-luna | max | 11.7% (60/513) [9.1%, 14.7%] |
| gpt-6.1-sol | low | 2.3% (7/305) [0.7%, 4.2%] |
| gpt-6.1-sol | medium | 1.4% (14/971) [0.7%, 2.2%] |
| gpt-6.1-sol | high | 1.9% (7/370) [0.7%, 3.4%] |
| gpt-6.1-sol | xhigh | 1.1% (4/374) [0.2%, 2.2%] |
| gpt-6.1-sol | max | 0.6% (3/511) [0.0%, 1.3%] |
| gpt-6.1-terra | off/low | 5.0% (38/756) [3.5%, 6.6%] |
| gpt-6.1-terra | medium | 1.2% (5/428) [0.2%, 2.2%] |
| gpt-6.1-terra | high | 2.6% (8/312) [0.6%, 5.0%] |
| gpt-6.1-terra | xhigh | 2.3% (9/393) [1.0%, 4.0%] |
| gpt-6.1-terra | max | 0.2% (1/450) [0.0%, 0.7%] |
| all |  | 13.3% (4397/32964) [12.7%, 14.0%] |

### Not a certain mistake: proven blank, gave the turn away, by what the search scored, all configs

| opponent jammed | search scores the opponent shot higher | search settles the self shot as a win and the opponent shot as a loss | the rest | no search |
|---|---|---|---|---|
| 19.5% (1085/5570) [18.1%, 20.8%] | 6.2% (18/288) [3.8%, 9.2%] | 3.0% (11/371) [1.3%, 4.9%] | 12.3% (3283/26734) [11.7%, 12.9%] | 0/1 |

### By source of the proof and shells left, all configs

| pattern | public | glass | phone | combined | last shell | earlier shells |
|---|---|---|---|---|---|---|
| shot itself on a proven live | 2.1% (652/31311) [1.9%, 2.3%] | 0.1% (25/21255) [0.1%, 0.2%] | 3.4% (175/5211) [2.8%, 3.9%] | 1.8% (2/114) [0.0%, 4.4%] | 2.5% (470/19079) [2.2%, 2.7%] | 1.0% (384/38812) [0.9%, 1.1%] |
| shot the opponent, giving up a guaranteed win | 2/3 | 2.7% (6/225) [0.9%, 4.9%] | 10.0% (7/70) [2.9%, 18.6%] | 1/5 | – | 5.3% (16/303) [2.9%, 8.0%] |
| proven blank, gave the turn away | 19.1% (3476/18211) [18.2%, 20.0%] | 3.7% (410/10949) [3.3%, 4.2%] | 13.6% (500/3665) [12.4%, 14.9%] | 7.9% (11/139) [4.0%, 12.9%] | 20.5% (2561/12484) [19.5%, 21.5%] | 9.0% (1836/20480) [8.4%, 9.5%] |
<!-- tables:end -->
