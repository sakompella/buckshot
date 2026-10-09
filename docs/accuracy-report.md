# Simulator accuracy report

## Overall verdict

The simulator is not an accurate model of a complete Buckshot Roulette game. It is a small experiment about two shooting policies. Its basic blank/live damage and extra-turn rules are recognizable. Its current code cannot finish the documented data-gathering run. Even after repairing the enum names in memory, asymmetric reloads give strategies the wrong shell counts.

Do not treat its reported win rates as chances of beating the game's dealer. Items, dealer behavior, health changes, campaign progression, and double-or-nothing payouts are absent. The reload-count bug alone changes a tested win rate by 36.1 percentage points.

| Category | Verdict | Finding |
| --- | --- | --- |
| Execution and results | major | Enum names disagree. Stock data gathering crashes. |
| Initial shell composition | minor | Caller-defined experiments, not the game's round schedule. |
| Hidden shell ordering | accurate | Uniform shuffle models random insertion for a fixed composition. The display before insertion is not modeled. |
| Reload counts and load schedule | major | Live/blank knowledge swaps on reload. The same load repeats forever. |
| Load announcements | minor | Policies see counts. Debug output also reveals the hidden firing order. |
| Basic shooting damage | accurate | Live deals one point and blank deals zero, without items or final-round rules. |
| Self-shot blank extra turn | accurate | The shooter keeps control while shells remain and no cuffs intervene. |
| First turn and empty-chamber transition | major | README assigns the first move to the dealer. The game starts player control after loading, including reloads. |
| HP, defibrillators, and campaign | missing | No campaign rounds, final-round health collapse, or healing rules. |
| Inventory and all nine items | missing | Only two shooting actions exist. |
| Dealer AI and shell memory | missing | Named shooting policies are not the dealer implementation. |
| Double or nothing and cash EV | missing | No run continuation, stake, payout, or timer. |
| Multiplayer | missing | No multiplayer state. Supplied public source cannot establish its exact rules. |
| Win-rate experiment design | major | Reverse-seat results are complements, not separate trials. First-mover effects remain. |

"Accurate" describes only the stated restricted rule. It does not certify the whole simulator.

## Sources and version limits

The audit pins three repositories. Nothing below uses guessed source lines.

| Prefix | Checkout and immutable revision | Meaning |
| --- | --- | --- |
| `S/` | `_work/sim/src/`, [simulator revision](https://github.com/EightBitByte/buckshot-roulette-sim/tree/108356d74ebb2e07fa1452ca6eb3f4a484f3ed65) | Simulator Python source. |
| `P/` | `_work/decomp/`, [requested public revision](https://github.com/uncreativeCultist/buckshot-decomp-public/tree/5da18fc8aae5c4209ffee6b80b282e4301cf763f) | Public assets snapshot. |
| `G/` | `_work/decomp-full/v1.2 (Steam)/`, [supplemental revision](https://github.com/uncreativeCultist/buckshot-decomp-private/tree/0a573d3b8c835f78d47e1fa5b1143e803b6ffd7f/v1.2%20(Steam)) | Historical decompiled game logic. |

The requested public repository deliberately leaves its root `scripts/` and `scenes/` directories with empty placeholder files named `not included in public repo -lillie`. Older v1.1 scripts remain under `!OLD VERSIONS/v1.1/`. They can establish historical rules, but not the v1.2 or current implementation. Its README links the now-public supplemental repository at `P/README.md:5-8`. The public root has no `project.godot` and cannot directly build a current runnable project.

The supplemental repository includes v1.0, v1.1, and `v1.2 (Steam)`. This report uses the latter. Its scripts and scenes entered git on 2024-04-04. The tag `v1.2.2` points to the audited HEAD, but the only change from tag `v1.2-Steam` is four README lines. The tag is not evidence that the scripts implement every 1.2.2 patch. The supplemental README also warns that its repository source may be damaged at `G/../README.md:11-15`.

The public repository's last game-content commit is dated 2024-04-04. Its December 2024 and May 2025 updates change only the README. The December README promised newer assets and multiplayer code in the private repository. The now-public supplemental HEAD contains no such multiplayer code. A newer README date is not a newer game build. Historical single-player findings below are verified against `G/`. Exact later single-player and multiplayer parity remains unverified.

The simulator README calls this a shooting-strategy experiment, not a version-specific port. Its first commits are from December 2024. Its audited HEAD is dated 2026-04-09. It does not declare an older game version target. Missing items therefore cannot be excused as a documented v1.0 target, and v1.0 already had items.

## How the two implementations work

The simulator stores two health integers, a shuffled list of shell booleans, and two strategy objects. `GameState` exposes only blank and live counts. Each strategy returns shoot-self or shoot-opponent. The loop consumes a shell, subtracts one health for a live shot, and usually switches sides. It ends when either health integer reaches zero. See `S/game.py:7-24`, `S/game.py:60-124`, and `S/stratagem.py:9-32`.

The game builds configured round batches. It shares items before eligible loads, shows shells, optionally randomizes insertion, and then returns control to the player. Health persists across loads within a batch. Dealer defeat advances the batch. Its turn functions also handle item effects, cuff state, shell knowledge, and wire cuts. See `G/scripts/RoundManager.gd:86-165`, `G/scripts/RoundManager.gd:190-238`, `G/scripts/RoundManager.gd:259-330`, and `G/scripts/HealthCounter.gd:31-42`.

## Proven simulator defects

### The stock program crashes

`S/stratagem.py:23-26` defines `Move.SHOOT_OPP`. `S/stratagem.py:16-21` defines `Outcome.SHOOT_OPP_WITH_BLANK` and `Outcome.SHOOT_OPP_WITH_LIVE`. The engine instead accesses `SHOOT_OPPO` names at `S/game.py:43-48` and `S/game.py:98-101`.

An opponent shot raises `AttributeError` before returning an outcome. A self-shot blank gets past the outcome function, then fails on the missing opponent outcome during damage dispatch. Repeated self-live shots can take a narrower path, but they do not make the program generally usable.

The documented `gather_data.py` run failed in its first pairing, Balanced versus Balanced. Its error was `Outcome` having no attribute `SHOOT_OPPO_WITH_LIVE`. The game has real live/blank target branches at `G/scripts/ShotgunShooting.gd:119-143`. This is a simulator implementation bug, not a game-version difference. Impact is total for that run. No win-rate dataset was produced.

### Reloading reverses the information given to strategies

The constructor correctly calls `GameState(num_blanks, num_live)` at `S/game.py:13`. It stores `_load` as live then blank at `S/game.py:20`. `_reload()` builds the actual shells in that order, but calls `GameState(self._load[0], self._load[1])` at `S/game.py:26-31`. `GameState` still expects blank then live at `S/stratagem.py:9-13`.

A 2-blank, 4-live load therefore reloads as four actual live shells and two actual blanks, but advertises four blanks and two lives. Safe chooses self at `S/stratagem.py:58-64`. It now shoots itself with a 2/3 chance of taking damage. With correct counts it would shoot the opponent, with zero self-damage risk on that shot. After consuming the full reload, the advertised state has two blanks and minus two lives.

The game initializes the real sequence and knowledge array from the configured counts at `G/scripts/ShellSpawner.gd:102-120`. Its load announcement uses those counts at `G/scripts/ShellSpawner.gd:49-67`. It does not invert them when a load starts.

The following measurements use the actual sim engine loaded into separate in-memory modules. One variant repairs only `SHOOT_OPPO` to `SHOOT_OPP`. The other also repairs the count argument order. Neither repairs the other game-parity differences. They are not measurements of real-game win rates.

| Load, HP 3 | P1 policy | P2 policy | Enum fix only | Enum and count fix | Change |
| --- | --- | --- | ---: | ---: | ---: |
| 4 blank, 4 live | Safe | Greedy | 70.055% | 70.055% | 0.000 points |
| 2 blank, 4 live | Safe | Greedy | 42.885% | 59.135% | +16.250 points |
| 2 blank, 4 live | Safe | Scared | 23.655% | 57.370% | +33.715 points |
| 1 blank, 4 live | Scared | Safe | 100.000% | 63.905% | -36.095 points |

Each variant has 20,000 trials per row and seed `20261012` on Python 3.12.12. The largest approximate 95% binomial half-width for an individual rate is 0.7 percentage points. These changes are far larger than sampling error. Equal live/blank loads hide this bug. The full nine-row output is reproduced by `scripts/check-simulator.py`.

### Reverse matchups are not complements

`S/gather_data.py:65` runs combinations with replacement, not ordered pairs. At `S/gather_data.py:88-91`, it records the reversed policy entry as one minus the measured rate. That reverses the winner of the same match, not the policies' first-move seats.

A deterministic counterexample uses HP 1 and one live shell. Scared versus TriggerHappy always gives P1 the win. TriggerHappy versus Scared also always gives P1 the win. Both choose the opponent. The stored complementary rate would be zero for the second matchup, although a direct reversed trial is one. This is a valid simulator input, not a real game load.

The same problem appears on a more game-like fixed 4-blank, 4-live load with HP 3. Safe versus Scared wins 45.975% as P1. The independently reversed Scared versus Safe wins 66.835% as P1, rather than 54.025%. This comparison uses the enum-repaired engine. The symmetric load avoids the count bug.

The game has asymmetric player and dealer roles and starts player control after loading at `G/scripts/ShellLoader.gd:91-98`. Replacing seat-swapped experiments with complements cannot estimate either role correctly. The aggregate at `S/gather_data.py:99-109` mixes these misassigned seat rates. Rounding to three decimal places at `S/gather_data.py:86-91` also discards precision, but that is minor beside the seat error.

## Shells, health, turns, and game progression

### Normal campaign configuration

`G/scenes/main.tscn` below means the unmodified member extracted from `G/scenes/main.7z`. Its physical line numbers are preserved. The audit copy is `_work/evidence/modes/v1.2-main/main.tscn`. The batches reference these resources at `G/scenes/main.tscn:40328-40357`.

The game calls a load a round in this code. A batch is one of the three main contests against the dealer. The player need not exhaust all five configured loads. Dealer defeat advances immediately to the next batch. If both sides survive the fifth load, that fifth configuration repeats. See `G/scripts/RoundManager.gd:190-195` and `G/scripts/RoundManager.gd:476-513`.

| Campaign batch | Load | Blank | Live | Starting HP or persistence | Items per side | Game scene lines |
| --- | ---: | ---: | ---: | --- | ---: | --- |
| 1 | 1 | 2 | 1 | 2 each | 0 | `G/scenes/main.tscn:562-578` |
| 1 | 2 | 2 | 3 | HP persists | 0 | `G/scenes/main.tscn:580-596` |
| 1 | 3 | 2 | 3 | HP persists | 0 | `G/scenes/main.tscn:598-614` |
| 1 | 4 | 3 | 3 | HP persists | 0 | `G/scenes/main.tscn:616-632` |
| 1 | 5 and repeats | 2 | 5 | HP persists | 0 | `G/scenes/main.tscn:634-650` |
| 2 | 1 | 1 | 1 | 4 each | 2 | `G/scenes/main.tscn:652-668` |
| 2 | 2 | 2 | 2 | HP persists | 2 | `G/scenes/main.tscn:670-686` |
| 2 | 3 | 2 | 3 | HP persists | 2 | `G/scenes/main.tscn:688-704` |
| 2 | 4 | 3 | 3 | HP persists | 2 | `G/scenes/main.tscn:706-722` |
| 2 | 5 and repeats | 2 | 5 | HP persists | 2 | `G/scenes/main.tscn:724-740` |
| 3 | 1 | 2 | 1 | 6 each, wire-cut rule applies | 4 | `G/scenes/main.tscn:742-758` |
| 3 | 2 | 4 | 4 | HP persists | 4 | `G/scenes/main.tscn:760-776` |
| 3 | 3 | 2 | 3 | HP persists | 4 | `G/scenes/main.tscn:778-794` |
| 3 | 4 | 2 | 4 | HP persists | 4 | `G/scenes/main.tscn:796-812` |
| 3 | 5 and repeats | 3 | 5 | HP persists | 4 | `G/scenes/main.tscn:814-830` |

Every campaign load sets `insertingInRandomOrder = true`. Only batch 3 loads 2 through 5 also set `shufflingArray = true`. The shell display may start ordered, then insertion shuffles twice. The simulator's one shuffle is equivalent for the final random order of a fixed multiset. Consuming from the list's end rather than its start is also distribution-equivalent. Neither is an accuracy defect by itself. See `S/game.py:22-23`, `S/game.py:36`, `G/scripts/ShellSpawner.gd:86-89`, and `G/scripts/ShellSpawner.gd:102-120`.

The simulator uses fixed HP 3 or 5 and repeated loads of 4 blank/4 live, 2 blank/4 live, or 1 blank/4 live at `S/gather_data.py:38-46`. Its parameter constructor could represent a single real load. Its supplied experiments do not represent a whole campaign batch. This changes initial lethal-shot risk and later shell probabilities. For example, the campaign starts with a 1/3 live chance, not the experiment's 1/2, 2/3, or 4/5.

### Double or nothing

The historical code names this mode `endless`. Each batch setup regenerates all configured loads at `G/scripts/RoundManager.gd:140-165`.

- Starting health is an inclusive uniform integer from 2 through 4. Only the first load's HP initializes a batch, because `G/scripts/HealthCounter.gd:31-42` checks `isFirstRound`.
- Total shells are uniform from 2 through 8. Live count is `max(1, total_shells / 2)` with integer division. Blank count is the remainder. For totals 2 through 8, the live counts are 1, 1, 2, 2, 3, 3, and 4.
- Each load gives each side 2 through 5 items, subject to inventory capacity and item limits.
- A coin flip can enable the pre-display shuffle. The false branch does not clear a previous true flag. Insertion still randomizes the final order through the serialized `insertingInRandomOrder` flag.
- Wire-cut mechanics are disabled by the `!endless` condition at `G/scripts/HealthCounter.gd:91`.

`S/game.py:9-23` has no mode parameter. `S/game.py:26-31` reuses one fixed load. `S/stratagem.py:9-13` exposes neither HP nor items. The mode changes both available actions and the dealer's decision rules, so substituting arbitrary shell ratios does not reproduce it.

### Turn and health comparison

| Rule | Game behavior and evidence | Simulator behavior and evidence | Outcome impact |
| --- | --- | --- | --- |
| Who starts | Loading enables the player's controls, every load. `G/scripts/ShellLoader.gd:91-98`. | P1 starts at `S/game.py:68`. `S/../README.md:10` identifies P1 as Dealer. | Swapping identities gives the first move to the wrong role. P1 may instead be relabeled player, but the README's dealer claim remains wrong. |
| Blank shot at self | Keeps control while shells remain. `G/scripts/ShotgunShooting.gd:136-137`, `G/scripts/RoundManager.gd:269-285`, `G/scripts/DealerIntelligence.gd:387-394`. | Keeps the current side at `S/game.py:114-116`. | Accurate without cuffs and before empty-chamber handling. |
| Other shots | Live at either target or blank at opponent yields control, unless cuffs intervene. `G/scripts/ShotgunShooting.gd:119-143`, `G/scripts/RoundManager.gd:271-284`. | Toggles P1/P2 after any non-self-blank result. `S/game.py:91-116`. | Accurate for the item-free core after the enum fix. |
| Last shell | The shot/ejection ends the load. Cuffs clear, items may be distributed, then player control starts. `G/scripts/RoundManager.gd:190-228`, `G/scripts/ShellLoader.gd:91-98`. | Reload preserves the side selected by the previous shot. `S/game.py:73-89`, `S/game.py:114-116`. | A dealer's final self-blank cannot carry an extra turn across a real reload. The sim allows it. |
| HP and charges | Both start at the batch's 2, 4, or 6 charges. Health persists within that batch. `G/scripts/HealthCounter.gd:31-42` and the scene table above. | Both start at any caller HP and never reset within a match. `S/game.py:17-18`, `S/game.py:73-124`. | HP 3/5 experiments model different survival budgets. A match win is not a three-batch game win. |
| Revival | A nonfatal live hit plays defibrillator revival. Zero health ends the contest. `G/scripts/DeathManager.gd:49-69`, `G/scripts/DeathManager.gd:94-103`. | Subtracts health until zero. `S/game.py:91-102`, `S/game.py:73`, `S/game.py:124`. | It is correct not to add an extra life at zero. The animation is not a separate reserve-health pool. |
| Final-batch threshold | After a nonfatal hit leaves 1 or 2 HP in normal batch 3, health is set to 1 and a wire cut is queued. `G/scripts/HealthCounter.gd:91-105`. | No threshold or wire state. `S/game.py:91-102`. | With ordinary damage, a side at 3 HP becomes 1 after one hit, not 2. The sim overstates remaining survival by one hit. |
| Can't heal | Cigarettes and medicine healing stop when that side's wire is cut. Healing otherwise caps at the batch's starting HP. `G/scripts/HealthCounter.gd:126-152`. | No healing or cap. `S/stratagem.py:23-26`, `S/game.py:91-102`. | Healing strategies and final-round risk cannot be studied. |
| Empty chamber | Player and dealer paths start the next load instead of firing. `G/scripts/RoundManager.gd:285-290`, `G/scripts/DealerIntelligence.gd:92-94`. | The loop reloads before calling a strategy. `S/game.py:73-89`. | Both avoid empty firing for valid ongoing games, but their load and turn transitions differ. |
| Dealer defeat | Advances a batch; three wins complete the run. `G/scripts/RoundManager.gd:351-356`, `G/scripts/RoundManager.gd:476-495`. | Ends immediately and returns one Boolean. `S/game.py:73-124`. | No full-run win rate or progression state. |

The game announces the shell counts at `G/scripts/ShellSpawner.gd:60-80`. It also shows shell visuals and plays shell-type sounds before insertion at `G/scripts/ShellSpawner.gd:125-135` and `G/scripts/ShellSpawner.gd:147-153`. Late campaign loads and endless setup can skip spoken count text, but the physical display still exists. See `G/scripts/EndlessMode.gd:16-22`.

The simulator gives policies both counts. That matches the information available to a player who counts. In visual debug mode it prints the actual firing order at `S/game.py:50-57` and `S/game.py:84-86`. This is not equivalent to the game's pre-insertion display. Built-in strategies receive only `GameState`, so the debug leak does not affect their automated win rates.

## Items and inventory

All item rules are missing in the simulator. `S/stratagem.py:9-13` has no inventory or effect state. `S/stratagem.py:23-26` has only two shooting actions. `S/game.py:34-48` and `S/game.py:88-116` resolve only those shooting actions. Those are the simulator citations for every omission in the tables below.

Items normally act before a shot and do not, by themselves, pass the gun. Beer on the final shell starts a fresh load. Medicine can kill its user. Item animations temporarily block controls, then return them at `G/scripts/ItemInteraction.gd:104-181` and `G/scripts/ItemInteraction.gd:206-212`.

### Distribution and limits

Historical per-type limits come from `G/scenes/main.tscn:1215-1276`.

| Item | Normal limit per side | Double-or-nothing limit per side | Simulator |
| --- | ---: | ---: | --- |
| Handsaw | 8 | 3 | Missing |
| Magnifying glass | 8 | 3 | Missing |
| Beer | 8 | 2 | Missing |
| Cigarettes | 2 | 1 | Missing |
| Handcuffs | 8 | 1 | Missing |
| Expired medicine | 0 | 1 | Missing |
| Burner phone | 0 | 1 | Missing |
| Adrenaline | 0 | 2 | Missing |
| Inverter | 0 | 8 | Missing |

These are limits on the tracked stock held by each side, not weighted draw counts and not permanent per-batch lifetime quotas. Selection increments that side's counter. Item use decrements it, so the type becomes eligible again on a later distribution. See `G/scripts/ItemManager.gd:226-247`, `G/scripts/ItemManager.gd:342-370`, `G/scripts/ItemInteraction.gd:104-110`, and `G/scripts/DealerIntelligence.gd:237-241`. Batch cleanup resets counters through `G/scripts/ItemManager.gd:535-544`, called by an animation method track at `G/scenes/main.tscn:6056-6069`.

The draw pool contains each eligible item name once. Selection is uniform over eligible types. Remaining stock does not weight a type. A cap-zero type is absent. This applies separately to player and dealer. Main values become active at `G/scripts/RoundManager.gd:135-138`; endless values at `G/scripts/EndlessMode.gd:23-25`.

Each side has eight physical slots. Surviving items occupy those slots across reloads. A full side stops intake, so a promised 2 or 4 items is not guaranteed when the side lacks space. See `G/scenes/main.tscn:40681-40683`, `G/scripts/ItemManager.gd:255-305`, and `G/scripts/ItemManager.gd:342-388`. Items clear between batches through `G/scripts/ItemManager.gd:118-140` and `G/scripts/ItemManager.gd:535-544`.

The old campaign has no items in batch 1, two each per load in batch 2, and four each in batch 3. The four added item types have zero normal-mode caps. Endless uses all nine. After v1.2.1, handsaws are also excluded from the first round when starting HP is 2, according to the official patch note linked below. The historical picker lacks that condition. In the audited campaign, item-enabled batches start at HP 4 and 6, so this restriction matters to the randomized double-or-nothing setup rather than those campaign batches. Exact later spawn filters require later source.

### Exact effects and their impact

| Item | Game behavior | Game evidence | What omitting it changes |
| --- | --- | --- | --- |
| Handsaw | Sets the next shot's live damage to 2. It does not multiply an existing 2 again. A blank still deals zero. The barrel regrows after the shot. | `G/scripts/ItemInteraction.gd:152-157`, `G/scripts/RoundManager.gd:264-268`, `G/scripts/SegmentManager.gd:16-17` | Against HP 2, a known live becomes an immediate kill rather than one damage. Saw plus information radically changes lethality. |
| Magnifying glass | Reveals the current shell without consuming it. | `G/scripts/ItemInteraction.gd:141-145`, `G/scripts/ShellExamine.gd:13-24` | Replaces a risky guess with a certain target choice. It also makes saw and inverter combinations possible. |
| Beer | Ejects the current shell with no damage. Reveals what was ejected. Player control resumes unless that was the last shell. | `G/scripts/ItemInteraction.gd:129-140`, `G/scripts/ShellEjectManager.gd:27-42` | Can remove a live threat or advance to known future information without taking a shot. It can also give up a favorable load by ejecting its last shell. |
| Cigarettes | Heals one, capped at the batch's starting health. No heal after that side's wire cut. | `G/scripts/HealthCounter.gd:126-152`, `G/scenes/main.tscn:21133-21147`, `G/scenes/main.tscn:14526-14542` | Adds survival while HP allows it. Its value is zero at full HP or after the cut. |
| Handcuffs | Makes the opponent miss one would-be turn. The next attempt breaks free and acts. Does not skip two turns. New loads clear both sides' cuffs. | `G/scripts/DealerIntelligence.gd:39-57`, `G/scripts/RoundManager.gd:275-320`, `G/scripts/HandcuffManager.gd:40-55` | Creates an extra shooting opportunity or a live/saw combo. Blank self-shots do not consume the opponent's skipped turn. |
| Burner phone | Selects a later shell uniformly from zero-based indices 1 through N-1. Never selects the current shell. N=1 gives no useful information. | `G/scripts/BurnerPhone.gd:6-35`, `G/scripts/DealerIntelligence.gd:187-194` | Future information can change eject/hold decisions and the dealer's later knowledge. With two shells, the player learns the second with certainty. |
| Inverter | Flips the current shell live to blank or blank to live. It does not consume it. | `G/scripts/ItemInteraction.gd:164-170`, `G/scripts/DealerIntelligence.gd:195-201` | A known blank can become damaging. A known live can become a safe self-shot. Remaining composition must change with it. |
| Adrenaline | Consumes adrenaline, then steals and immediately uses one eligible opponent item. The player has seven seconds to choose. It does not add the item to a spare inventory slot. | `G/scripts/ItemInteraction.gd:50-101`, `G/scripts/ItemInteraction.gd:176-180`, `G/scripts/ItemManager.gd:463-474` | Combines gaining an effect with denying the same effect to the opponent. Empty or invalid opposing stock can make it useless. |
| Expired medicine | Historical source heals 2 with probability 0.4 and loses 1 with probability 0.6. Current official patch changed this to 0.5 and 0.5. Healing caps at starting HP. | `G/scripts/MedicineManager.gd:17-38`, `G/scripts/MedicineManager.gd:72-75`, `G/scripts/HealthCounter.gd:126-152`; official v1.2.1 note below | Historical uncapped expected HP change is +0.2. Patched uncapped change is +0.5. At one missing HP, those become -0.2 and 0. At HP 1, failure is fatal. |

The simulator cannot express any row in that table. There is no meaningful conversion of its shooting-only win rate to an item-enabled win rate.

### Item edge cases

- Sawing a blank is allowed for the player. It wastes the damage boost when fired, because blank damage stays zero and `EndTurn` regrows the barrel. Using beer before firing does not invoke that regrowth branch, so the boost survives ejection. See `G/scripts/ItemInteraction.gd:129-157` and `G/scripts/RoundManager.gd:259-290`.
- The player cannot stack saws while the barrel is already sawed. The player cannot re-cuff an already cuffed dealer. Permissions derive from those states at `G/scripts/PermissionManager.gd:65-80`.
- A blank self-shot keeps the shooter in control and leaves the opponent's pending cuff skip unconsumed. Only an attempted handoff checks cuffs. The cuff remains through that skipped turn, blocks immediate re-cuffing, then breaks on the opponent's next turn. See `G/scripts/RoundManager.gd:271-300` and `G/scripts/DealerIntelligence.gd:39-57`.
- Beer on the last shell begins the next load. Cuffs clear there. A saw may persist until a shot or an explicit batch-reset regrowth path. See `G/scripts/ItemInteraction.gd:131-140`, `G/scripts/RoundManager.gd:190-195`, and `G/scripts/RoundManager.gd:460-465`.
- Dealer phone use requires more than two shells, although the player phone can work at two. The dealer's known-shell flags move with ejected shells and reset on reload. See `G/scripts/DealerIntelligence.gd:187-194`, `G/scripts/ShellEjectManager.gd:27-68`, and `G/scripts/ShellSpawner.gd:111-120`.
- The historical player phone maps both index 6 and index 7 to the same `SEQUENCE7` label at `G/scripts/BurnerPhone.gd:29-32`. For eight shells, a selected last shell therefore uses the same label as the seventh. The official v1.2.2 Hotfix 1 says rare wrong information was fixed. This is a source anomaly, not evidence that the current game still has it.
- The phone's index-8-to-7 adjustment is unreachable for normal maximum-eight-shell loads at `G/scripts/BurnerPhone.gd:14-15`. It must not be read as a different probability for any valid later index in this snapshot.
- Adrenaline cannot steal another adrenaline. The steal setup disables shooting and blocks adrenaline through the active-steal flag. Other stack-invalid states also apply to saw and cuffs. See `G/scripts/ItemManager.gd:393-418`, `G/scripts/PermissionManager.gd:65-80`, and `G/scenes/main.tscn:40324-40325`. The setup gathers both sides' scene nodes without an explicit side filter. I did not verify whether own-side items are reachable through the UI. See `G/scripts/ItemManager.gd:405-411`.
- Player inverter use changes the shared shell list but does not explicitly update the dealer's phone flags. Dealer inverter use sets `knownShell` to live and target to player. See `G/scripts/ItemInteraction.gd:164-170` and `G/scripts/DealerIntelligence.gd:195-201`. A separate human-memory field does not exist in these scripts.

## Dealer AI

No simulator strategy is the dealer. The simulator runs whichever two policy classes the caller supplies at `S/game.py:9-15`. The dealer uses mode-specific shell knowledge, inventory, and item conditions at `G/scripts/DealerIntelligence.gd:85-303`.

### Decision flow and item usage

1. If the sequence is empty, start the next load. Process a pending wire cut before the decision. See `G/scripts/DealerIntelligence.gd:90-94`.
2. In endless mode, try known-shell flags and count-based deductions. See `G/scripts/DealerIntelligence.gd:96-104` and `G/scripts/DealerIntelligence.gd:282-303`.
3. If exactly one shell remains, know its type. Shoot the player if live, or self if blank. See `G/scripts/DealerIntelligence.gd:106-112`.
4. Rebuild the inventory from scene children. Dealer items come first. If dealer adrenaline exists, append available player items. See `G/scripts/DealerIntelligence.gd:118-149`.
5. Scan that list and use the first item whose condition qualifies. After use, recurse into `DealerChoice` to consider another item. See `G/scripts/DealerIntelligence.gd:151-201` and `G/scripts/DealerIntelligence.gd:266-267`.
6. If nothing qualifies, consider the special uncertain-shell saw branch. Otherwise shoot a known target or choose through `CoinFlip`. See `G/scripts/DealerIntelligence.gd:203-216` and `G/scripts/DealerIntelligence.gd:275-279`.

There is no fixed global item priority such as "always cuffs, then saw, then magnifier". The loop's first qualifying inventory entry wins. Different table-child order can change the sequence of effects. That order follows stored scene nodes and later spawns, not the strength of an item.

| Item | Historical dealer use condition | Evidence |
| --- | --- | --- |
| Magnifier | Unknown current shell, with more than one shell remaining. Set the target from the revealed type. | `G/scripts/DealerIntelligence.gd:152-159` |
| Cigarettes | Dealer HP below the batch's starting HP. This check itself does not test the wire-cut flag. | `G/scripts/DealerIntelligence.gd:160-164` |
| Expired medicine | Below max HP, no cigarettes recorded, not already using medicine, and HP not 1. | `G/scripts/DealerIntelligence.gd:165-169` |
| Beer | `knownShell` is not live and more than one shell remains. This includes an unknown shell. | `G/scripts/DealerIntelligence.gd:170-176` |
| Handcuffs | Player is not already cuffed and more than one shell remains. | `G/scripts/DealerIntelligence.gd:177-180` |
| Handsaw | Barrel not already sawed and current shell known live. | `G/scripts/DealerIntelligence.gd:181-186` |
| Burner phone | More than two shells remain. Mark a random later index as known. | `G/scripts/DealerIntelligence.gd:187-194` |
| Inverter | Current shell known blank. Flip it to live and target the player. | `G/scripts/DealerIntelligence.gd:195-201` |
| Adrenaline | Makes player inventory usable during the inventory scan. Consume it when the chosen item must come from the player. Prefer an owned copy of the same type. | `G/scripts/DealerIntelligence.gd:122-149`, `G/scripts/DealerIntelligence.gd:243-258` |

In the fallback saw branch, a dealer with a saw and no known blank calls `CoinFlip`. One result chooses self without a saw. The other chooses the player and applies two damage. That is a 50/50 branch in campaign mode. In endless, the same function uses the shell-count majority instead. See `G/scripts/DealerIntelligence.gd:203-216` and `G/scripts/DealerIntelligence.gd:421-431`.

### Randomness and memory

The campaign dealer's uninformed target choice is a fair coin. It does not prefer the more likely live/blank target, even when counts are unequal, unless its separate last-shell or item knowledge applies. Endless `CoinFlip` instead chooses the player when lives outnumber blanks, self when blanks outnumber lives, and randomly at a tie. See `G/scripts/DealerIntelligence.gd:326-329` and `G/scripts/DealerIntelligence.gd:421-431`.

The dealer has two kinds of knowledge.

- Magnifier and final-shell knowledge use `knownShell`, `dealerKnowsShell`, and `dealerTarget`. They clear after a shot at `G/scripts/DealerIntelligence.gd:275-279`.
- Phone knowledge uses an indexed Boolean array. Ejection removes index zero in tandem with the shell sequence at `G/scripts/ShellEjectManager.gd:27-68`. Reload creates a new all-false array at `G/scripts/ShellSpawner.gd:111-120`. Endless `FigureOutShell` also subtracts known future shell types from the remaining counts. If all unknown shells must have the same type, it knows the current shell. See `G/scripts/DealerIntelligence.gd:282-303`.

A historical campaign quirk matters. After magnifying a blank, the dealer can eject it with beer. The beer branch clears knowledge only when `endless` is true. Campaign `dealerTarget` can therefore stay self for the next unknown shell. A newly reached last-shell case overwrites this stale knowledge. See `G/scripts/DealerIntelligence.gd:106-112` and `G/scripts/DealerIntelligence.gd:170-176`. I verified the branch in source, not in a running retail build. It is not a claim about later patches.

Historical theft can also corrupt tracked item counters. Player theft decrements dealer stock and then player stock for the stolen type, although that player did not hold it. Dealer theft tries to decrement player stock, but breaks after the first resource whether or not its name matches. See `G/scripts/ItemInteraction.gd:90-110` and `G/scripts/HandManager.gd:76-82`. Those details matter to a source-faithful replica. They should not be silently replaced with a cleaner model and labeled exact retail parity.

### Comparison with every simulator policy

| Simulator policy and source | Behavior | Relationship to the game dealer |
| --- | --- | --- |
| Greedy, `S/stratagem.py:35-48` | Majority target, self at a tie. | Not campaign AI. Endless differs at ties, items, and memory. |
| Safe, `S/stratagem.py:51-64` | Majority target, opponent at a tie. | Not campaign AI. Endless differs at ties, items, and memory. |
| Balanced, `S/stratagem.py:67-82` | Majority target, coin at a tie. | Closest to endless's uninformed `CoinFlip`, but lacks its certainty and items. |
| Random, `S/stratagem.py:85-93` | Fair target coin on every shot. | Closest to campaign's uninformed target, but fails the game's last-shell certainty. |
| Reckless, `S/stratagem.py:96-105` | Self while any blank remains. | No dealer counterpart in the audited code. |
| Scared, `S/stratagem.py:108-117` | Opponent while any live remains. | No general dealer counterpart. |
| TriggerHappy, `S/stratagem.py:120-126` | Always opponent. | No general dealer counterpart. |
| Suicidal, `S/stratagem.py:129-135` | Always self. | No general dealer counterpart. |

The real-dealer evidence for these comparisons is `G/scripts/DealerIntelligence.gd:106-112`, `G/scripts/DealerIntelligence.gd:151-216`, and `G/scripts/DealerIntelligence.gd:421-431`. None of the policies receives HP, item ownership, cuffs, saw state, or future-shell information through `GameState`. They cannot become exact dealer AI by a different tie-break alone.

### A small source-faithful baseline experiment

`scripts/check-dealer-baseline.py` imports the actual simulator's strategy classes, but runs a separate reference transition loop. It models only the item-free first campaign batch. It uses HP 2, the scene's load schedule, player control after each load, one-point live damage, self-blank extra turns, and the campaign dealer's coin flip plus last-shell certainty.

This is deliberately smaller than a full game. Defibrillator animation has no extra-health effect in this batch. There are no items, wire cuts, payouts, or multiplayer. The script is not a claim about optimal play or a complete modern-game win rate. It does not import `game.py`, so the stock enum bug does not stop the comparison.

| Player policy | Reference dealer, player opens every load | Coin-flip dealer without last-shell certainty | Reference dealer opens only the first load |
| --- | ---: | ---: | ---: |
| Balanced | 68.4% | 72.1% | 75.8% |
| Safe | 68.8% | 75.9% | 75.7% |
| Scared | 82.4% | 86.1% | 75.9% |
| Random | 46.1% | 49.9% | 46.2% |

Each cell has 20,000 trials, command seed 1, and a separately seeded local RNG. The script prints Wilson 95% confidence intervals. Typical half-width is about 0.6 to 0.7 percentage points. Removing the dealer's final-shell certainty changes Safe's player win rate by about seven points. Giving the dealer the first opening changes different policies in different directions. This is why a generic Random opponent or a presumed first-player advantage is not enough.

The counterfactual columns are not actual game modes. They isolate the two source rules. The first column is a reference-model estimate for the historical item-free batch, not a retail-game measurement.

## Cash EV and omitted modes

The simulator returns only who won one match at `S/game.py:124`. It stores no cash, elapsed time, choice to stop, or number of batch wins. Its plotting and gathering code measure strategy win fractions, not cash EV.

Historical double or nothing computes an initial score of `70000 - int(initial_time / 600 * 40000)`, with a minimum of 10. Each later completed run doubles the previous score. Declining stores the current score for the ending. Accepting resets the batch index to zero and generates another run. See `G/scripts/RoundManager.gd:379-397`, `G/scripts/RoundManager.gd:426-451`, and `G/scripts/RoundManager.gd:460-465`.

Once a stake S is established, risking it for 2S versus losing it has a simplified threshold of p > 1/2 for the next full run. That does not make a single simulator match probability p. A full run crosses three batches with different loads, HP, dealer behavior, and item draws. The initial time-dependent score is another variable the simulator lacks. No reliable real-game cash EV follows from its output.

Multiplayer exists in the real game. The [official multiplayer release announcement](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6146943657173906021) describes new items and a peer-to-peer mode. The audited v1.2 logic predates it. The requested public repository omits current scripts. The simulator has two fixed health variables, two policies, and no peer, lobby, multi-target, or multiplayer-item actions at `S/game.py:9-20` and `S/stratagem.py:23-26`.

I cannot verify multiplayer HP, shell generation, first-player selection, item weights, or its special turn effects from these sources. Those are missing evidence, not rules proven equal to single-player. A claim that this simulator reproduces multiplayer would be unsupported.

## Later official changes

The source audit does not override published changes to the game.

- [Update v1.2.1, 2024-04-09](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5756237364327128876) says medicine changed from 60/40 to 50/50. It also excludes handsaws in the first round when starting HP is 2. It lists a fix for rounds skipped by rapid clicks at low frame rates.
- [v1.2.2 Hotfix 1, 2024-04-16](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5762994032385016401) says rare wrong burner-phone information was fixed.

These announcements were read through the official Steam news API for app 2835570. The raw response is saved locally at `_work/steam-news.json`. The local archive and scripts predate those changes. The official notes establish the changed odds and saw restriction. They do not expose the replacement phone implementation, later item filters, or multiplayer code. The exact current implementation still needs newer legally obtained source or a matching owned game build.

## Reproduce and verify

The retained scripts contain original audit code, not decompiled game code. They never patch the source files in place. The game-owned clones, extracted scene, tools, logs, and exported app stay under ignored `_work/`.

From the repository root, the simulator-only checks need Python 3.12 or newer. The stock match engine and the retained probes use the standard library. `gather_data.py` additionally needs its pinned tqdm dependency. Plotting dependencies are not required for this audit.

```sh
uv venv --python 3.12 _work/sim/.venv
uv pip install --python _work/sim/.venv/bin/python tqdm==4.67.1
nice -n 10 _work/sim/.venv/bin/python -B scripts/check-simulator.py --sim _work/sim
nice -n 10 _work/sim/.venv/bin/python -B scripts/check-dealer-baseline.py --simpath _work/sim/src --trials 20000 --seed 1
```

The first probe should print both enum errors, swapped reload counts, 56 failed reload-count invariants among 64 positive-count pairs, the two-true seat counterexample, and the Monte Carlo table. The reference baseline should print all eight policies and their intervals. Neither result is the unmodified simulator's own dataset.

To reproduce the stock CLI failure without writing its empty data directory into the main checkout, run it from its ignored clone.

```sh
cd _work/sim
nice -n 10 .venv/bin/python -B src/gather_data.py
```

Source recovery and macOS commands are in [Modding and macOS port](modding-and-macos-port.md). That document also records the limits of the exported build.

## What would make the simulator credible

First fix the enum names and reload state invariant. Then run both seat orders separately. Keep seeds and intervals in the results. Those repairs make the shooting experiment internally usable; they do not make it a game simulator.

For game parity, the state must include mode, batch, current load, actual and known shells, both HP values, both inventories, cuffs, barrel damage, and wire-cut flags. Item draws and dealer decisions must use the selected version's rules. Compare the transition model against specific source scenarios before publishing full-run win rates. Recover later game code before claiming modern multiplayer or exact current single-player parity.

The sound conclusion from this audit is narrow. The simulator has the recognizable shooting core, but its current outputs cannot answer "how likely am I to beat Buckshot Roulette?"
