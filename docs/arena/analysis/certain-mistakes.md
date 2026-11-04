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
| claude-haiku-4-5-20251001 | off | 4.5% (27/606) [2.7%, 6.3%] | 2/3 | 11 |
| claude-haiku-4-5-20251001 | minimal | 3.8% (25/662) [2.4%, 5.4%] | 1/4 | 12 |
| claude-haiku-4-5-20251001 | low | 2.5% (19/750) [1.5%, 3.7%] | 0/2 | 19 |
| claude-haiku-4-5-20251001 | medium | 2.8% (47/1688) [1.9%, 3.7%] | 2/8 | 40 |
| claude-haiku-4-5-20251001 | high | 2.6% (17/661) [1.4%, 3.9%] | 0/3 | 11 |
| claude-haiku-5-5 | off | 0.3% (3/939) [0.0%, 0.7%] | 0/4 | 24 |
| claude-haiku-5-5 | low | 0.6% (6/1074) [0.2%, 1.0%] | 0/8 | 30 |
| claude-haiku-5-5 | medium | 0.5% (10/2206) [0.2%, 0.8%] | 1/12 | 62 |
| claude-haiku-5-5 | high | 0.4% (4/925) [0.1%, 0.9%] | 0/3 | 24 |
| claude-haiku-5-5 | xhigh | 0.0% (0/901) [0.0%, 0.0%] | 0/6 | 29 |
| claude-haiku-5-5 | max | 0.0% (0/878) [0.0%, 0.0%] | 0/2 | 19 |
| claude-opus-5-5 | off | 0.0% (0/177) [0.0%, 0.0%] | 0/1 | 6 |
| claude-opus-5-5 | low | 0.0% (0/331) [0.0%, 0.0%] | 0/1 | 8 |
| claude-opus-5-5 | medium | 0.1% (1/1979) [0.0%, 0.2%] | 0/13 | 57 |
| claude-opus-5-5 | high | 0.0% (0/394) [0.0%, 0.0%] | – | 12 |
| claude-opus-5-5 | xhigh | 0.0% (0/806) [0.0%, 0.0%] | 0/4 | 17 |
| claude-opus-5-5 | max | 0.0% (0/378) [0.0%, 0.0%] | – | 14 |
| claude-sonnet-5-5 | off | 0.8% (7/890) [0.2%, 1.5%] | 0/4 | 11 |
| claude-sonnet-5-5 | low | 0.3% (2/776) [0.0%, 0.7%] | 0/5 | 9 |
| claude-sonnet-5-5 | medium | 0.4% (9/2124) [0.2%, 0.7%] | 0/7 | 38 |
| claude-sonnet-5-5 | high | 0.3% (3/893) [0.0%, 0.8%] | 0/6 | 26 |
| claude-sonnet-5-5 | xhigh | 0.0% (0/924) [0.0%, 0.0%] | 0/2 | 29 |
| claude-sonnet-5-5 | max | 0.0% (0/1115) [0.0%, 0.0%] | 0/4 | 26 |
| gpt-5.6-terra | low | 1.9% (10/522) [0.8%, 3.2%] | 0/3 | 19 |
| gpt-5.6-terra | medium | 0.8% (12/1457) [0.4%, 1.3%] | 0/8 | 52 |
| gpt-5.6-terra | high | 2.0% (11/540) [1.1%, 3.2%] | 0/1 | 21 |
| gpt-5.6-terra | xhigh | 0.7% (4/614) [0.2%, 1.3%] | 0/4 | 23 |
| gpt-5.6-terra | max | 0.2% (1/665) [0.0%, 0.5%] | 0/3 | 19 |
| gpt-6-astra | off | 0.0% (0/140) [0.0%, 0.0%] | – | 6 |
| gpt-6-astra | low | 0.0% (0/111) [0.0%, 0.0%] | – | 0 |
| gpt-6-astra | medium | 0.0% (0/1698) [0.0%, 0.0%] | 0/15 | 22 |
| gpt-6-astra | high | 0.0% (0/138) [0.0%, 0.0%] | 0/1 | 1 |
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
| gpt-6.1-terra | off | 0.0% (0/119) [0.0%, 0.0%] | 0/2 | 3 |
| gpt-6.1-terra | low | 0.0% (0/155) [0.0%, 0.0%] | 0/2 | 2 |
| gpt-6.1-terra | medium | 0.0% (0/161) [0.0%, 0.0%] | 0/2 | 5 |
| gpt-6.1-terra | high | 0.0% (0/129) [0.0%, 0.0%] | 0/2 | 5 |
| gpt-6.1-terra | xhigh | 0.0% (0/133) [0.0%, 0.0%] | – | 1 |
| gpt-6.1-terra | max | 0.0% (0/168) [0.0%, 0.0%] | – | 2 |
| all |  | 1.6% (611/39203) [1.4%, 1.7%] | 3.7% (7/188) [1.6%, 6.7%] | 1,006 |

### Not a certain mistake: proven blank, gave the turn away, by config

| model | effort | shot the opponent on a proven blank |
|---|---|---|
| claude-haiku-4-5-20251001 | off | 38.7% (180/465) [34.5%, 43.2%] |
| claude-haiku-4-5-20251001 | minimal | 34.7% (171/493) [29.5%, 39.7%] |
| claude-haiku-4-5-20251001 | low | 28.5% (140/491) [24.1%, 32.8%] |
| claude-haiku-4-5-20251001 | medium | 30.3% (336/1108) [27.1%, 33.9%] |
| claude-haiku-4-5-20251001 | high | 31.8% (143/450) [28.1%, 35.9%] |
| claude-haiku-5-5 | off | 35.1% (236/672) [31.2%, 39.1%] |
| claude-haiku-5-5 | low | 26.2% (174/663) [23.0%, 29.4%] |
| claude-haiku-5-5 | medium | 20.9% (277/1326) [18.8%, 23.1%] |
| claude-haiku-5-5 | high | 21.5% (118/549) [17.5%, 25.4%] |
| claude-haiku-5-5 | xhigh | 17.5% (81/463) [14.0%, 21.0%] |
| claude-haiku-5-5 | max | 8.7% (41/471) [6.2%, 11.5%] |
| claude-opus-5-5 | off | 0.0% (0/86) [0.0%, 0.0%] |
| claude-opus-5-5 | low | 0.6% (1/160) [0.0%, 2.1%] |
| claude-opus-5-5 | medium | 0.3% (3/1006) [0.0%, 0.7%] |
| claude-opus-5-5 | high | 0.0% (0/205) [0.0%, 0.0%] |
| claude-opus-5-5 | xhigh | 0.2% (1/449) [0.0%, 0.7%] |
| claude-opus-5-5 | max | 0.0% (0/137) [0.0%, 0.0%] |
| claude-sonnet-5-5 | off | 4.4% (18/409) [2.1%, 7.1%] |
| claude-sonnet-5-5 | low | 2.0% (9/444) [0.7%, 3.5%] |
| claude-sonnet-5-5 | medium | 1.8% (18/973) [1.0%, 2.8%] |
| claude-sonnet-5-5 | high | 0.2% (1/423) [0.0%, 0.8%] |
| claude-sonnet-5-5 | xhigh | 0.4% (2/473) [0.0%, 1.1%] |
| claude-sonnet-5-5 | max | 0.3% (2/621) [0.0%, 0.8%] |
| gpt-5.6-terra | low | 8.9% (27/305) [5.4%, 12.5%] |
| gpt-5.6-terra | medium | 6.8% (61/891) [5.2%, 8.6%] |
| gpt-5.6-terra | high | 5.6% (19/338) [3.0%, 8.7%] |
| gpt-5.6-terra | xhigh | 3.3% (12/367) [1.6%, 5.3%] |
| gpt-5.6-terra | max | 1.7% (7/408) [0.5%, 3.2%] |
| gpt-6-astra | off | 5.8% (4/69) [0.0%, 13.6%] |
| gpt-6-astra | low | 3.9% (2/51) [0.0%, 15.4%] |
| gpt-6-astra | medium | 0.7% (6/854) [0.1%, 1.4%] |
| gpt-6-astra | high | 0.0% (0/75) [0.0%, 0.0%] |
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
| gpt-6.1-terra | off | 3.2% (2/63) [0.0%, 8.3%] |
| gpt-6.1-terra | low | 4.6% (3/65) [0.0%, 10.3%] |
| gpt-6.1-terra | medium | 0.0% (0/81) [0.0%, 0.0%] |
| gpt-6.1-terra | high | 0.0% (0/67) [0.0%, 0.0%] |
| gpt-6.1-terra | xhigh | 1.4% (1/70) [0.0%, 4.2%] |
| gpt-6.1-terra | max | 0.0% (0/92) [0.0%, 0.0%] |
| all |  | 12.9% (2915/22557) [12.1%, 13.7%] |

### Not a certain mistake: proven blank, gave the turn away, by what the search scored, all configs

| opponent jammed | search scores the opponent shot higher | search settles the self shot as a win and the opponent shot as a loss | the rest | no search |
|---|---|---|---|---|
| 18.3% (734/4003) [16.7%, 20.0%] | 4.9% (15/308) [2.6%, 7.4%] | 2.8% (6/215) [0.5%, 5.7%] | 12.0% (2160/18031) [11.2%, 12.8%] | – |

### By source of the proof and shells left, all configs

| pattern | public | glass | phone | combined | last shell | earlier shells |
|---|---|---|---|---|---|---|
| shot itself on a proven live | 2.2% (485/22065) [1.9%, 2.5%] | 0.1% (19/13850) [0.1%, 0.2%] | 3.3% (106/3229) [2.6%, 3.9%] | 1.7% (1/59) [0.0%, 5.2%] | 2.6% (362/13731) [2.3%, 3.0%] | 1.0% (249/25472) [0.8%, 1.1%] |
| shot the opponent, giving up a guaranteed win | 1/1 | 2.9% (4/140) [0.7%, 5.8%] | 2.4% (1/42) [0.0%, 7.3%] | 1/5 | – | 3.7% (7/188) [1.6%, 6.7%] |
| proven blank, gave the turn away | 18.0% (2351/13077) [16.9%, 19.1%] | 3.8% (259/6870) [3.2%, 4.4%] | 11.9% (301/2532) [10.4%, 13.4%] | 5.1% (4/78) [1.2%, 10.7%] | 19.5% (1741/8913) [18.3%, 20.7%] | 8.6% (1174/13644) [7.9%, 9.3%] |
<!-- tables:end -->
