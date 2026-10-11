# Bend simulator

`sim/bend/` is a 2-player Buckshot Roulette simulator in Bend 2. It plays the story and Double or Nothing (DoN) dealer AIs against each other under the 2-player multiplayer rules. It is a port of `sim/python/dealer_vs_dealer.py` and reproduces its results.

## Run

From the repo root:

```sh
nix develop
cd sim/bend
bend main.bend -o /tmp/bsim && /tmp/bsim --threads 8
bend PROOF.bend
bun verify-model-tests.mjs
```

`main` prints one full DoN vs story match with a fixed seed. Then it runs 16,384 independent matches for each matchup and prints match and round win rates.

## Modules

- `model.bend` owns the game: the hidden shell order, the shell deck, the counter-based random numbers, reloads, jams, rounds and prizes. `observe(game, side)` returns what one side may know. `step(game, action)` applies one action and returns events.
- `controller.bend` holds the policies: story, DoN, and a trivial `AlwaysOpp`. A controller sees only its `Obs`, its own memory, and the events addressed to its side. It never sees `Game`, so it can't read the shell order. Randomness reaches it only as an explicit coin. The driver still draws that coin from the model's random stream, so controller and game randomness share one stream.
- `driver.bend` runs matches. It routes events to each side's memory, supplies coins, caps a match at 4,096 actions, records the printed match as a list of entries, and runs batches as a parallel fork tree.
- `view.bend` renders events, a side's view of the table, the recorded match, the match summary and batch results as strings.
- `main.bend` only calls the driver and the view.
- `LAWS.bend` and `PROOF.bend` hold the laws and their proofs.

The model's event type is `GameEvent`, because Base already defines `Event`.

## Results

Each matchup uses 16,384 matches (49,152 rounds). Native and JS builds print byte-identical output.

| A vs B | A's match wins | A's round wins | Python, 100,000 matches |
| --- | ---: | ---: | ---: |
| story vs story | 49.94% | 49.83% | 50.0% / 50.0% |
| DoN vs DoN | 50.48% | 50.26% | 50.0% / 50.0% |
| DoN vs story | 73.79% | 66.42% | 73.7% / 66.4% |

With the Python rates as reference, the 2-sigma band is 49.2% to 50.8% for the mirrors and 73.0% to 74.4% for DoN vs story. All three results fall inside it. No match ran out of actions.

## How it was checked

- The controller made the same decision as the Python port on 68,331 decisions across 22,000 traces. The Python port matches the real `DealerIntelligence.gd` on 44,000 random states.
- `verify-model-tests.mjs` compiles the real model and controller to JS and runs 16 checks. They cover shots, reloads, shell shuffles, round winners, jams, item caps, and that observations never leak the shell order or the other side's phone memory.
- The laws in `LAWS.bend` cover only the damage helper: zero damage keeps health, damage equal to health is fatal, and health lost plus health left equals health before. They don't cover turns, shells or items. No definition uses `@unsafe`. `bend PROOF.bend --verdict` needs Lean 4.34.0, which the dev shell doesn't provide.

## Differences from the Python port

- Each match draws from its own hashed seed instead of one shared `random.Random` stream. The two agree statistically, not game by game.
- A coin is drawn before every decision, even when the policy doesn't use it.
- Shells are shuffled by weighted live and blank draws. That gives the same uniform distribution over orders as shuffling a list.
- The model accepts actions the dealer AIs never take: beer on the last shell (reload, same player keeps the turn) and the inverter on a live shell. Invalid item actions leave the state unchanged.
- A round start clears the jam's checked flag. Python leaves it stale while unjammed, which never affects play.

## Timings

One warm run on a 10-core M4 Mac, compile time excluded, covering the printed match and all three batches:

| Target | Threads | Wall time |
| --- | ---: | ---: |
| Native | 1 | 2.85 s |
| Native | 8 | 0.52 s |
| JS via Bun | 1 | 4.05 s |
