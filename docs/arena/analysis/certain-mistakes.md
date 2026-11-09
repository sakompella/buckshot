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
| claude-haiku-4-5-20251001 | minimal | 3.8% (32/835) [2.5%, 5.2%] | 1/5 | 14 |
| claude-haiku-4-5-20251001 | low | 2.3% (22/966) [1.4%, 3.2%] | 0/2 | 22 |
| claude-haiku-4-5-20251001 | medium | 2.5% (49/1958) [1.8%, 3.3%] | 2/9 | 47 |
| claude-haiku-4-5-20251001 | high | 2.5% (21/831) [1.5%, 3.7%] | 0/5 | 13 |
| claude-haiku-5-5 | off | 0.5% (6/1243) [0.2%, 0.9%] | 0/4 | 34 |
| claude-haiku-5-5 | low | 0.6% (8/1392) [0.2%, 1.0%] | 0/11 | 36 |
| claude-haiku-5-5 | medium | 0.4% (11/2711) [0.2%, 0.7%] | 1/13 | 75 |
| claude-haiku-5-5 | high | 0.4% (5/1235) [0.1%, 0.8%] | 0/3 | 35 |
| claude-haiku-5-5 | xhigh | 0.0% (0/1224) [0.0%, 0.0%] | 0/8 | 35 |
| claude-haiku-5-5 | max | 0.0% (0/878) [0.0%, 0.0%] | 0/2 | 19 |
| claude-opus-5-5 | off | 0.0% (0/599) [0.0%, 0.0%] | 0/5 | 18 |
| claude-opus-5-5 | low | 0.0% (0/566) [0.0%, 0.0%] | 0/3 | 15 |
| claude-opus-5-5 | medium | 0.0% (1/2468) [0.0%, 0.1%] | 0/15 | 76 |
| claude-opus-5-5 | high | 0.0% (0/582) [0.0%, 0.0%] | 0/1 | 18 |
| claude-opus-5-5 | xhigh | 0.0% (0/1073) [0.0%, 0.0%] | 0/6 | 20 |
| claude-opus-5-5 | max | 0.0% (0/704) [0.0%, 0.0%] | 0/3 | 26 |
| claude-sonnet-5-5 | off | 0.8% (10/1179) [0.3%, 1.5%] | 0/7 | 20 |
| claude-sonnet-5-5 | low | 0.3% (3/1013) [0.0%, 0.7%] | 0/5 | 11 |
| claude-sonnet-5-5 | medium | 0.3% (9/2632) [0.1%, 0.6%] | 0/12 | 49 |
| claude-sonnet-5-5 | high | 0.3% (3/1176) [0.0%, 0.6%] | 0/10 | 35 |
| claude-sonnet-5-5 | xhigh | 0.0% (0/1376) [0.0%, 0.0%] | 0/5 | 36 |
| claude-sonnet-5-5 | max | 0.0% (0/1115) [0.0%, 0.0%] | 0/4 | 26 |
| gpt-5.6-terra | low | 1.9% (10/522) [0.8%, 3.2%] | 0/3 | 19 |
| gpt-5.6-terra | medium | 0.8% (12/1457) [0.4%, 1.3%] | 0/8 | 52 |
| gpt-5.6-terra | high | 2.0% (11/540) [1.1%, 3.2%] | 0/1 | 21 |
| gpt-5.6-terra | xhigh | 0.7% (4/614) [0.2%, 1.3%] | 0/4 | 23 |
| gpt-5.6-terra | max | 0.2% (1/665) [0.0%, 0.5%] | 0/3 | 19 |
| gpt-6-astra | off | 0.0% (0/581) [0.0%, 0.0%] | 0/1 | 15 |
| gpt-6-astra | low | 0.0% (0/551) [0.0%, 0.0%] | 0/1 | 11 |
| gpt-6-astra | medium | 0.0% (0/1698) [0.0%, 0.0%] | 0/15 | 22 |
| gpt-6-astra | high | 0.0% (0/595) [0.0%, 0.0%] | 0/5 | 11 |
| gpt-6-luna | off | 11.3% (80/707) [9.2%, 13.6%] | 0/1 | 29 |
| gpt-6-luna | low | 12.0% (87/726) [9.1%, 15.1%] | – | 26 |
| gpt-6-luna | medium | 8.6% (154/1797) [7.3%, 10.0%] | 0/7 | 52 |
| gpt-6-luna | high | 3.8% (30/798) [2.7%, 4.9%] | 0/4 | 28 |
| gpt-6-luna | xhigh | 2.7% (23/862) [1.7%, 3.7%] | 1/1 | 28 |
| gpt-6-luna | max | 2.2% (19/862) [1.3%, 3.3%] | 0/3 | 40 |
| gpt-6.1-sol | low | 0.0% (0/595) [0.0%, 0.0%] | 0/2 | 14 |
| gpt-6.1-sol | medium | 0.0% (0/1819) [0.0%, 0.0%] | 0/11 | 36 |
| gpt-6.1-sol | high | 0.0% (0/669) [0.0%, 0.0%] | – | 10 |
| gpt-6.1-sol | xhigh | 0.0% (0/677) [0.0%, 0.0%] | 0/8 | 14 |
| gpt-6.1-sol | max | 0.0% (0/864) [0.0%, 0.0%] | 0/6 | 14 |
| gpt-6.1-terra | off | 0.0% (0/531) [0.0%, 0.0%] | 0/5 | 12 |
| gpt-6.1-terra | low | 0.2% (1/554) [0.0%, 0.6%] | 0/6 | 8 |
| gpt-6.1-terra | medium | 0.0% (0/563) [0.0%, 0.0%] | 0/3 | 9 |
| gpt-6.1-terra | high | 0.0% (0/594) [0.0%, 0.0%] | 0/4 | 18 |
| gpt-6.1-terra | xhigh | 0.0% (0/570) [0.0%, 0.0%] | – | 11 |
| gpt-6.1-terra | max | 0.0% (0/648) [0.0%, 0.0%] | 0/2 | 14 |
| all |  | 1.3% (642/49552) [1.2%, 1.4%] | 2.8% (7/246) [0.8%, 5.0%] | 1,254 |

### Not a certain mistake: proven blank, gave the turn away, by config

| model | effort | shot the opponent on a proven blank |
|---|---|---|
| claude-haiku-4-5-20251001 | off | 38.0% (213/560) [33.9%, 42.2%] |
| claude-haiku-4-5-20251001 | minimal | 32.2% (205/637) [27.7%, 36.4%] |
| claude-haiku-4-5-20251001 | low | 26.6% (168/632) [22.7%, 30.4%] |
| claude-haiku-4-5-20251001 | medium | 30.3% (390/1289) [27.2%, 33.5%] |
| claude-haiku-4-5-20251001 | high | 29.8% (171/573) [26.5%, 33.3%] |
| claude-haiku-5-5 | off | 32.7% (296/906) [29.2%, 36.0%] |
| claude-haiku-5-5 | low | 25.9% (214/826) [23.2%, 28.7%] |
| claude-haiku-5-5 | medium | 21.0% (336/1597) [19.1%, 23.0%] |
| claude-haiku-5-5 | high | 20.7% (145/702) [17.3%, 23.9%] |
| claude-haiku-5-5 | xhigh | 16.9% (105/621) [13.7%, 19.7%] |
| claude-haiku-5-5 | max | 8.7% (41/471) [6.2%, 11.5%] |
| claude-opus-5-5 | off | 0.3% (1/300) [0.0%, 1.1%] |
| claude-opus-5-5 | low | 0.4% (1/271) [0.0%, 1.2%] |
| claude-opus-5-5 | medium | 0.3% (4/1245) [0.1%, 0.7%] |
| claude-opus-5-5 | high | 0.0% (0/284) [0.0%, 0.0%] |
| claude-opus-5-5 | xhigh | 0.2% (1/588) [0.0%, 0.5%] |
| claude-opus-5-5 | max | 0.0% (0/305) [0.0%, 0.0%] |
| claude-sonnet-5-5 | off | 4.9% (29/597) [3.0%, 7.0%] |
| claude-sonnet-5-5 | low | 2.7% (15/564) [1.3%, 4.2%] |
| claude-sonnet-5-5 | medium | 1.9% (23/1226) [1.1%, 2.7%] |
| claude-sonnet-5-5 | high | 0.9% (5/563) [0.2%, 1.7%] |
| claude-sonnet-5-5 | xhigh | 0.9% (6/700) [0.3%, 1.6%] |
| claude-sonnet-5-5 | max | 0.3% (2/621) [0.0%, 0.8%] |
| gpt-5.6-terra | low | 8.9% (27/305) [5.4%, 12.5%] |
| gpt-5.6-terra | medium | 6.8% (61/891) [5.2%, 8.6%] |
| gpt-5.6-terra | high | 5.6% (19/338) [3.0%, 8.7%] |
| gpt-5.6-terra | xhigh | 3.3% (12/367) [1.6%, 5.3%] |
| gpt-5.6-terra | max | 1.7% (7/408) [0.5%, 3.2%] |
| gpt-6-astra | off | 2.1% (6/289) [0.4%, 4.2%] |
| gpt-6-astra | low | 1.8% (5/276) [0.3%, 3.8%] |
| gpt-6-astra | medium | 0.7% (6/854) [0.1%, 1.4%] |
| gpt-6-astra | high | 2.1% (6/283) [0.4%, 4.2%] |
| gpt-6-luna | off | 28.5% (157/551) [24.9%, 32.2%] |
| gpt-6-luna | low | 30.5% (157/514) [26.4%, 34.7%] |
| gpt-6-luna | medium | 24.0% (281/1173) [21.5%, 26.5%] |
| gpt-6-luna | high | 13.9% (70/504) [11.0%, 16.8%] |
| gpt-6-luna | xhigh | 11.9% (60/504) [8.5%, 15.6%] |
| gpt-6-luna | max | 11.7% (60/513) [9.1%, 14.7%] |
| gpt-6.1-sol | low | 2.3% (7/305) [0.7%, 4.2%] |
| gpt-6.1-sol | medium | 1.4% (14/971) [0.7%, 2.2%] |
| gpt-6.1-sol | high | 1.9% (7/370) [0.7%, 3.4%] |
| gpt-6.1-sol | xhigh | 1.1% (4/374) [0.2%, 2.2%] |
| gpt-6.1-sol | max | 0.4% (2/445) [0.0%, 1.2%] |
| gpt-6.1-terra | off | 4.4% (11/252) [2.2%, 7.0%] |
| gpt-6.1-terra | low | 5.6% (13/233) [2.7%, 8.9%] |
| gpt-6.1-terra | medium | 0.4% (1/272) [0.0%, 1.3%] |
| gpt-6.1-terra | high | 2.6% (8/305) [0.7%, 5.3%] |
| gpt-6.1-terra | xhigh | 1.6% (5/314) [0.3%, 3.0%] |
| gpt-6.1-terra | max | 0.3% (1/383) [0.0%, 0.9%] |
| all |  | 12.0% (3378/28072) [11.4%, 12.7%] |

### Not a certain mistake: proven blank, gave the turn away, by what the search scored, all configs

| opponent jammed | search scores the opponent shot higher | search settles the self shot as a win and the opponent shot as a loss | the rest | no search |
|---|---|---|---|---|
| 17.7% (853/4810) [16.4%, 19.1%] | 3.7% (8/217) [1.4%, 6.3%] | 2.9% (9/308) [1.0%, 5.1%] | 11.0% (2508/22736) [10.4%, 11.7%] | 0/1 |

### By source of the proof and shells left, all configs

| pattern | public | glass | phone | combined | last shell | earlier shells |
|---|---|---|---|---|---|---|
| shot itself on a proven live | 1.9% (510/27547) [1.6%, 2.1%] | 0.1% (21/17632) [0.1%, 0.2%] | 2.5% (109/4284) [2.1%, 3.1%] | 2.2% (2/89) [0.0%, 5.4%] | 2.2% (383/17120) [2.0%, 2.5%] | 0.8% (259/32432) [0.7%, 0.9%] |
| shot the opponent, giving up a guaranteed win | 1/1 | 2.2% (4/184) [0.5%, 4.4%] | 1.8% (1/56) [0.0%, 5.5%] | 1/5 | – | 2.8% (7/246) [0.8%, 5.0%] |
| proven blank, gave the turn away | 17.0% (2729/16034) [16.1%, 18.0%] | 3.4% (302/8781) [3.0%, 4.0%] | 10.8% (340/3139) [9.6%, 12.1%] | 5.9% (7/118) [1.7%, 10.4%] | 18.3% (2013/10989) [17.3%, 19.4%] | 8.0% (1365/17083) [7.4%, 8.6%] |
<!-- tables:end -->
