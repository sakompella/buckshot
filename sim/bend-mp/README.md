# Buckshot multiplayer rules library

This directory holds the rules of Buckshot Roulette multiplayer for 2 to 4 seats, written in Bend and checked against a faithful reference. It is a library of rules. It is not the running game.

The product is a sans-IO state machine, the machine for short. It never rolls dice and never waits for a player. At each point it returns a request, and the caller answers with a number. A request is one of four things.

- A draw, such as the starting health or a shuffle swap, with a range.
- A choice among the legal moves of the seats that may act.
- Finished.
- Stuck.

The machine also returns notes, the events and private results that seats see. Callers are the driver, the AIs, the web UI and the tests.

## Scope

In scope are the rules a normal client can play. That means every move an unmodified client can offer, the host's acceptance of those moves, rounds, cash, items, jamming and stealing, and the public and private information each seat gets.

Out of scope are graphics, animation, sound, networking, the lobby, seat shuffling, disconnects, timeouts, frame timing and end-of-match titles. Moves that only a modified client can send are out of scope too. Timeouts are off in the shipped game, so no timer rule exists to model. Titles are computed by the web UI from the public event log. Cash and round winners stay in the library.

## Layout

- `domain.bend` holds the types every part shares. They are seats, moves, requests, points, observations, notes and the match config. It holds no model state.
- `ref/` is the reference, a Bend model that follows the Godot `MP_*` scripts function by function. Its frames carry the names of the Godot functions they follow. It exists only to verify the machine.
- `sm/` is the machine. `state.bend` has the state, `rules.bend` and `items.bend` the pure rule functions, `point.bend` the requests and the public board, and `main.bend` the step function.
- `simple/` is the simple machine (ADR-0013). Its choices are whole moves for one seat, such as shoot a player or steal an item, and distribution makes no choices. It reuses `sm/`'s records and pure rules but not its step. `simple-abstract.bend` embeds a simple state in a machine state and plays each simple answer as a chain of the machine's own legal steps.
- `abstract.bend` is the bridge between the machine and the reference. `LAWS.bend` reaches the reference only through it. Proof files may also use `ref/` directly.
- `LAWS.bend` states the laws. `PROOF.bend` proves them, using `step-proof.bend` (the run, start and game laws), `accept-proof.bend` (`legal_accepted`), `roundtrip-proof.bend` (`state_roundtrip`), `items-proof.bend` and the phase proofs it calls (listed below), and `core-proof.bend`, `grant-proof.bend`, `shot-proof.bend` and `primitive.bend`.
- `ai/story.bend` and `ai/don.bend` are the two dealer AIs.
- `driver.bend` is the controller that plays whole matches. `view.bend` renders them as text.
- `main.bend` is a command line entry that plays matches and prints win rates. `web.bend` is the entry that the web UI builds to JavaScript. `analysis.bend` is the player's entry for the arena's analysis scripts.
- `player/` is the depth-limited minimax player over the simple machine (ADR-0043). It decides from one seat's public information and its own log. See `player/README.md`.
- `test/` holds scenario tests, the item law fuzz, a driver smoke test, a round trip test of the domain types, the simple machine's smoke test and fuzz, and the player's property tests (`test/player.mjs`).
- `tools/` and `mutate.py` hold the generators and the bug-planting checks.
- `check.sh` runs every gate.

When several seats can grab at once, the driver serves one grab per seat in turn, in socket order, from the seat after the first shooter (ADR-0033). The simple machine distributes in the same order, and the web bots and arena agents use the driver's chooser. The game itself has no fixed order: every client grabs at once.

The machine keeps fixed seat identity. Two seats use sockets 1 and 3. Three seats use 0 to 2, and four seats use 0 to 3.

Six modules keep to import rules that `check.sh` enforces. `ai/` imports only the domain. `sm/` imports only the domain and its own files. `simple/` imports only the domain, `sm/`'s state, rules and items, and its own files. `player/` imports what `simple/` may, plus `simple/` itself and its own files. `driver.bend` never imports `ref/` or `abstract.bend`. An AI therefore sees only its prompt, the public board and what it heard, and a wrong decision can only come from AI code. `LAWS.bend` never imports `ref/`, so every law is stated over the machine and the mapping in `abstract.bend`.

## Answers

Every number is a valid answer. A draw clamps the number into its range. A choice reads the number as an index into the flat list of every offered move, seat by seat in socket order, and clamps at the end. So any tape of numbers describes a game, and the reference and the machine read it the same way. The machine only offers moves a normal client can make, so an illegal move cannot be built.

## How the machine maps to the reference

The laws compare the machine to the reference, so something must turn a machine state into a reference state. That is `A.ref` in `abstract.bend`.

`A.ref` builds the reference's host from the machine's world and its per-seat data. The two models store different things, so some fields are derived.

- `has_turn` comes from the phase. Only the seat that an idle, aim, phone, jam or steal request waits on holds the turn. A blocked machine keeps the seat that held it.
- The reference stores two flags per seat, jammed and jammer checked. The machine stores one `Jam` value per seat. Free reads as neither flag. Jammed reads as jammed only. Jammed and skipped reads as both.
- The grab flags, the held item and the grant counts come from the machine's `Grabs`.

`frame(phase)` gives the reference's waiting point. It is the request the reference is blocked on, the stage, and what the reference does with the answer.

`back` is the inverse. It reads the world, the seats and the `Grabs` back from the host, the phase back from the frame, a recomputed menu back from the reference's own rendering of it, and a blocked machine's holder back from the seats' turn flags. The law `state_roundtrip` states that `back(ref(state))` returns the state at every valid state, so the mapping loses nothing.

The mapping covers only the states the machine can reach. `A.Valid` says which those are. It covers every config, with or without items. A state is valid when all four of these hold.

- It is in item normal form. The stored menus of an idle, jam, steal or grab phase equal their recomputation from the state, since the reference checks ownership and the grab flags where the machine reads the stored menu. A swap at index 0 is blocked.
- Its seat ring and every ring of its `Grabs` have the config's table.
- Its round index is inside the round plan.
- Its phase fits its world. A first-seat draw has a round left to begin, and the seat that an idle, aim, jam, steal or phone phase waits on holds the world's turn. The holder of a blocked machine and the seat of a phone draw sit at the table, since the reference keeps a blocked holder only in its seats' turn flags.

## The laws

The twelve required laws are listed in `check.sh`. Each is stated in `LAWS.bend`.

`start_matches` says that for every config, the machine's start and the reference's start give the same result, the same first point, and a valid machine state. The helper law `start_result_matches` states only the equality of the two start results.

`step_matches` says that for a valid state and any answer, the reference's answer, including its bounded run of silent internal steps, equals the machine's answer. Both reach the same request point with the same notes, and the machine state is valid again.

`run_matches` lifts that to whole runs. For any fuel, valid state and tape, the reference's run equals the machine's run.

`games_match` says that for every config, fuel and tape, the reference's game equals the machine's game read through `A.ran`. A game is the start's notes, then the run from the start state on the tape (`A.ref_game` and `A.machine_game`). So every machine game is a reference game, and the reverse. The two models offer equal menus, so neither can take a move the other cannot. The proof is `start_result_matches` and `run_matches` from the valid start state.

`reachable_valid` says that for every config, every state the machine reaches from its start through any tape is valid. The machine builds states only through `start` and `answer`, so no game reaches a state that `A.Valid` rules out. The state type itself can still hold invalid states, for example an idle phase whose seat does not hold the turn. Only code that builds a state by hand can make one.

`legal_exact` says that at every valid state the machine's request equals the reference's request at the mapped state. The legal moves are exactly the same.

`legal_accepted` says that at every valid state, every move the machine offers is accepted by the host's `VerifyPacket`: the seat holds the turn, the move fits the mode, the seat owns the item it uses or steals, and a grab or place fits the seat's grab flags. So the faithful reference never rejects a move the machine offers. `accept-proof.bend` reads the choice back from the request by the phase.

`observe_matches` says that at every valid state, for every seat, the observation and the heard notes of the machine equal those of the reference.

`privacy` says that a seat's observation and heard notes do not change if the hidden shell order and the decks are replaced. The new gun must have the same length. The law holds for all states, with or without items.

`turn_traversal` says the machine's choice of the next seat equals the reference's. Both skip dead seats and follow the direction of play. It reads only the seats' health and the direction, so items do not enter it.

`jam_skip_once` says that a jammed seat loses exactly one turn. The first grant of the turn skips the seat and marks it skipped. The next grant lifts the jam and gives the seat the turn. The one after that finds a free seat. The law also says the machine's jam step matches the reference's. After a lift, the reference leaves Godot's checked flag set, and the mapping restores that. A seat that is jammed again goes back to the jammed state, so it is skipped again. The law holds for all jam states.

`state_roundtrip` says that at every valid state `back(ref(state))` is the state, as above. The proof is in `roundtrip-proof.bend`. It needs three parts of `A.Valid`: the `Grabs` rings have the table's shape, a stored menu is its recomputation, and a blocked holder sits at the table. Without the last two the mapping would lose data: a menu stored for a seat outside the table, or a holder outside it, leaves no trace in the reference.

## What is proven and what is fuzzed

These laws are proven for every config, items included: `start_matches`, `start_result_matches`, `step_matches`, `run_matches`, `games_match`, `reachable_valid`, `legal_exact`, `legal_accepted`, `observe_matches` and `state_roundtrip`. `privacy` and `jam_skip_once` hold for all states, and `turn_traversal` does not depend on items. No law is stated for no-item configs only.

`step_matches` is `step.items` in `items-proof.bend`, by the phase. The phase proofs are in `load-proof.bend` (the handout and reload), `turn-proof.bend` (turn end), `use-proof.bend` (item uses at Idle), `aim-proof.bend` (shots), `pick-proof.bend` (jam targets, steals, the phone draw and the end-of-turn item draw), `round-proof.bend` (wins and round start), `load-step-proof.bend` (shell batches and swaps) and `item-step-proof.bend` (the grab and item handout points, and `point.items`: the machine's point equals the reference's at every valid state). `step-proof.bend` lifts the step to runs by induction on the fuel and proves the start, game, `legal_exact` and `observe_matches` laws. `accept-proof.bend` proves `legal_accepted`.

The laws are also checked on random games. `test/machine-items-fuzz.mjs` plays seeded random games, 500 for each of 2, 3 and 4 seats, so 1,500 games by default. At every request point it compares the machine to the reference on `step_matches`, `observe_matches`, `legal_exact`, `legal_accepted` and `privacy`. It checks `step_matches` on whole states: after each answer the reference's state equals `A.ref` of the machine's (abstract.bend is built to JS for this), and the notes and points match. It also checks `reachable_valid` against `A.Valid`, and `state_roundtrip`: `A.back` of `A.ref` of the machine's state is that state. It checks `legal_accepted` for every offered move. Checking `step_matches` at every point covers what `run_matches` says about those games. The fuzz does not check `turn_traversal` or `jam_skip_once` with items. `FUZZ_GAMES` sets the number of games for each table size.

The simple machine has its own nine laws in `SIMPLE-LAWS.bend`, proven in `SIMPLE-PROOF.bend` and the `simple-*-proof.bend` files. They are `simple_start`, `simple_refines` (each simple answer is a chain of the machine's legal steps that ends at the mapped next state with the same notes, for every state), `simple_roundtrip`, `simple_valid`, `simple_reachable_valid`, `simple_run_refines`, `simple_observe`, `simple_privacy` and `simple_complete` (every legal first-slot gesture from a turn is a simple move). That the simple distribution loop never reaches its `Stalled` state is fuzzed, not proven. `tools/simple_mutations.py` plants 10 bugs in the simple machine. Each must fail both the simple proofs and the simple fuzz.

Two mutation gates check that the checks can fail.

- `mutate.py` plants 10 type-correct bugs in a temporary copy of the machine, one at a time. Each must make `PROOF.bend` fail.
- `tools/fuzz_mutations.py` plants 6 item bugs the same way. Each must make the fuzz fail. It also reruns the fuzz with `step_matches` switched off, to see what the other properties catch alone. That second run reports survivors and does not fail the gate.

## What you must trust

A proof of a law is only as good as these five things.

1. The law statements. A law that is stated too weakly proves little. Read `LAWS.bend` and `A.Valid` before relying on them.
2. The mapping. `A.ref`, `frame` and `back` define what "the same state" means. A wrong mapping would prove the machine equal to the wrong thing.
3. The reference against Godot. This is testing, not proof. See the section on verification.
4. The gate for `@unsafe` and unfinished `def name?(` holes. It is a text search in `check.sh`. It finds none in this directory.
5. The checkers. These are the Bend compiler and proof kernel, the Lean-built kernel `BENDTT`, and the scripts in `check.sh`.

The model fixes below also depart on purpose from raw Godot. The reference and the machine both carry them.

## Generated proof bodies

Some lemmas in the proof files are case splits over every table shape, seat and value the rules branch on. They are too large to write by hand. `tools/proof_cases.py` writes their bodies. The claims, meaning the signatures, are written by hand. The script is not trusted. The Bend kernel checks every generated body like any other proof. `check.sh` runs the script in check mode and fails if the file differs from what the script would write.

## Model fixes

The reference follows the Godot rules, except for three model fixes, M1, M3 and M4. A fourth, M2, was withdrawn. Each fix covers a bug that changes game state. Each is in both models and was also made as a small edit to the harness's copy of the Godot code, so the laws and the harness stay exact. Bugs outside the game model, such as presentation, transport and timing, are ignored.

M1, distribution can soft-lock. Godot checks whether item distribution is finished, then ends the seats that have no eligible item. It never checks again. With custom item caps, the last placement can leave every grab flag clear while distribution stays open, and no reload follows. The library runs Godot's own completion check again after those seats end. If it passes, the reload follows. A seat that still holds an item to place keeps distribution open, as in Godot.

M2, withdrawn. The proposal was to clear the saw when beer empties the gun. Godot's multiplayer code keeps the saw active, and it applies to the next shot, whoever fires it. The single-player game does the same, so this is how the game plays. The library keeps it. The numbers M1, M3 and M4 were kept.

M3, new-round grabbers. At a new round Godot decides which seats get items before it clears the inventories. With custom settings that can skip a seat, or the whole first handout. The library decides after the clearing, using the new round's settings.

M4, adrenaline soft-lock. In Godot, adrenaline can start a steal in which no opponent item can be clicked. There is no cancel, so the turn freezes. It can happen with default settings. For example the barrel is sawed and the opponent holds only a saw and adrenaline. The library offers adrenaline only when at least one opponent item would be valid to steal and use.

Other decisions that matter, from the decision log D01 to D56, which stays local.

- D56. If distribution finishes while a seat still holds an item it has not placed, the placement is applied before the reload. Godot's reload waits two seconds, and a normal client places inside that time. A slower holder is client timing and out of scope.
- D10 and D11. A random draw is in the model only if its value can affect play. The library does not match Godot's random stream. It has seven draw kinds. They are first seat, starting health, item amount, item choice, phone index, sequence batch and shuffle swap. The shuffle swaps follow Godot's Fisher-Yates order.
- D16. A blank shot at yourself gives you another action, but it still goes through the pass-turn code, so jam checks apply.
- D25. A round winner is paid 70,000 at round index 0, 75,000 at index 1 and 80,000 at index 2.
- D31. The machine offers only moves a normal client can make. The reference's host verification is stated as a predicate so `legal_accepted` can say that every machine move passes it.
- D45. The first-death seat stays the first seat of later rounds until another death replaces it.

## Timing deviations

The library has no clock. It orders rule effects as they happen in normal play. The real engine can reorder some of them. Examples are a very long frame that ends a turn before a shot's outcome runs, a round's item handout starting before the new health is installed, and a reload that runs before the last placed item is installed. These deviations are recorded in the decision log as diagnostics. They are not proof cases and the library does not model them.

## Verification against Godot

The reference is checked against the real game code by a local harness. It is not in git. It lives under the ignored `_work/` directory.

The harness loads the real `mp_main` scene of a copy of the decompiled project, headless, with only Steam stubbed. Every multiplayer script, animation and timer runs as in the game. A small set of edits lets it read the random draws and the player moves from a tape. Six files change, and 60 lines. The edits also carry M1, M3 and M4.

For each run the harness makes random configs and random tapes. At each request point it builds the menu of every seat from the host's fields, takes the move the tape selects, and sends it as the exact packet a client sends, through the host's real verification. It records a trace and compares it with the reference's trace at every request point.

Results so far.

- 2 seats, core rules, 2,000 random tapes, 0 mismatches. 1,999 matches ran to the end with identical traces. One tape is a custom config that never ends. All 4,029 points before the game-time limit were identical. One engine crash after a trace was written was recovered by a rerun.
- Item tapes, 76 in all, 37 with 2 seats, 23 with 3 and 16 with 4. That is 25,533 request points and 0 mismatches. They include witness tapes for M1, M3, M4 and D56. They use every kind of move and every kind of draw.
- Random item games, 100 each with 2, 3 and 4 seats (seeds 2026101302, 2026101303 and 2026101304), 0 mismatches. Each round has items at default caps or a random subset at random caps and amounts.
- The comparator flagged all 7 trace differences planted in a test.
- 4 seats, core rules, 1,000 random tapes (seed 2026101104), 0 mismatches. Every match ran to the end with identical traces. Three tapes first crashed Godot (exit 241) while a second harness run competed for memory; run alone, they matched.
- 3 seats, core rules, a smaller run of 16 tapes, 0 mismatches.

The harness had two bugs of its own. Both showed up as mismatches and both were fixed.

- It read the global copy of each seat's inventory, which Godot clears 3.73 seconds after a new round starts. At a reload that falls in that gap, this gave 9 mismatches in the slots. It now reads each seat's own inventory.
- It answered before animations ended. A steal was answered before the thief's own animation finished, and a late end of that animation gave the thief a second shot. Two of eight early item tapes mismatched. A request point now also waits until no one-shot item or shotgun animation is playing.

Limits of the harness. Its menus come from a function over host fields, not from client code. A request point is a quiet period of one second of game time, which was checked by comparing traces and not proven. The indicator remote is never dealt at 2 seats, so only 3 and 4 seats exercise it.

## How to run

Enter the dev shell. It provides the pinned Bend 2.0.40, bun, python3 and uv, and sets `BEND` and `BENDTT` to a proof kernel built with nixpkgs' Lean.

    nix develop

Run every gate.

    bash sim/bend-mp/check.sh

It takes about 7 to 8 minutes on a Mac, and about 1.5 minutes on a 7-core Linux box. It prints one line per gate, then PASS or FAIL, and exits nonzero on any failure. `FUZZ_GAMES` sets the games for each table size in the item fuzz. It fails at once if `FUZZ_SKIP` is exported, since that switches fuzz properties off. The gates, in order:

1. `domain.bend` type-checks and its proofs check.
2. No `@unsafe` and no unfinished `def name?(` hole anywhere under this directory.
3. The import rules for `ai/`, `sm/`, `simple/`, `player/`, `driver.bend` and `LAWS.bend`.
4. The driver smoke test and the simple machine's smoke test. 64 matches at each table size finish with none stuck and no fuel spent.
5. All twelve required laws are present in `LAWS.bend`.
6. The generated proof bodies match their script.
7. `PROOF.bend` checks with `--verdict`.
8. The round trip of the domain types through JavaScript.
9. The reference's core and item scenarios.
10. The machine's core and item scenarios.
11. The item law fuzz, and the simple machine fuzz. At every point of seeded random games it checks that the simple answer is a chain of the machine's legal steps that lands on the mapped next state with the same notes, and that the mapped state is valid. It also checks that boards, draws, menus, privacy and the distribution order agree.
   Then the player's property tests on positions from seeded random games. `PLAYER_GAMES` sets the games for each table size (default 2); see `player/README.md`.
12. The machine mutations and the item fuzz mutations.

Run only the proof kernel.

    bend sim/bend-mp/PROOF.bend --verdict

It prints `ALL PROOFS CHECK` when every law checks. Bend 2.0.40 wants Lean 4.34.0 and builds its kernel itself when `BENDTT` is unset. The dev shell sets `BENDTT`, so nixpkgs' Lean is used as it is.

Play matches and print win rates.

    bend sim/bend-mp/main.bend

It plays one verbose 2-seat match, then 16,384 matches for each line, with 3 rounds per match.

An optional script, `_work/tools/remote-check.sh`, copies the working tree to a remote Linux machine over ssh and runs `check.sh` there. It is local, not in git, and needs a host with Nix. Pass `VAR=value` arguments, such as `FUZZ_GAMES=60`, to set the fuzz size.

## AI win rates

The two AIs are ports of the verified two-player dealer policies in `sim/python/dealer_vs_dealer.py`. Story uses fair coins and the dealer's item rules. Double or Nothing, DoN for short, is the story policy plus three upgrades. They are count_flip, deduce and beer_reset. Each AI is one pure function from its prompt, the board, what it heard and its own memory to a move. The driver gives each AI its own random stream.

`main.bend` runs 16,384 matches per line. In 2-seat matches DoN beats story in both seat orders:

| Items | DoN in seat 1 | DoN in seat 3 |
|---|---|---|
| on | 71.9% | 72.4% |
| off | 78.9% | 79.1% |

In the mirrors, where every seat runs the same AI, the later seats win more often (items on, seats in table order):

| Table | Story | DoN |
|---|---|---|
| 3 seats | 30.8 / 33.8 / 35.3 | 30.4 / 33.8 / 35.7 |
| 4 seats | 20.8 / 24.4 / 26.9 / 27.7 | 20.9 / 24.3 / 26.5 / 28.1 |

These numbers use the round-robin distribution of ADR-0033. Earlier tables came from a driver that served the lowest socket first, so seat 0 took all its items first and had first claim on the jammer and the remotes. With that driver the mirrors were wider: 28.4 / 33.1 / 38.3 for story at 3 seats, and 19.5 / 23.2 / 26.4 / 30.7 at 4 seats. The 2-seat items-on figures were 72.5% and 71.4%. Fixing the order narrowed the later-seat advantage but did not remove it. The rest is still an open question. It may be the turn order or a bias in the AIs.
