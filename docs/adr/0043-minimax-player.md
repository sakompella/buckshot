# Minimax player

The multiplayer player in `sim/bend-mp/player/` searches whole moves of the simple machine. Its input contains only the match configuration, the public board, and one player's complete log of public events and own secrets. It cannot receive a machine state or an RNG. Beliefs contain synthetic simple states reconstructed from that input, not copies of the host's hidden state.

Shell orders start uniformly over the permutations of each shown batch. Public shots, ejections and inverters transform or filter that belief; magnifier and phone clues filter only the player's private belief. Remaining shell composition is inferred, not read from the host. Batch decks are reconstructed from the public history, including uncertainty when fixed shell rules hide which batch resource was removed. An input whose belief cannot be constructed within the bound returns an explicit error rather than silently using hidden information or truncating the posterior.

## Search and information

Use paranoid expectiminimax. The acting player maximizes its expected share of the current round; every other player minimizes it. This agrees with minimax at two players and is a deliberately pessimistic coalition model at three or four. Max-n would model self-interested opponents better but needs a different tie and coalition policy. All decisions occur over a belief, never separately in each hidden world. Chance branches split on observations, not on unobserved shell orders, so decisions cannot depend on hidden information.

Opponents' private clues are unknown and ignored. They choose from the public belief, without the acting player's existing private clues. The search therefore keeps a public belief alongside the player's posterior. A private clue can improve the player's choices, but cannot change the modeled opponent's decision until a public result reveals information.

Depth counts player decisions. Draws do not consume depth, but every expanded state consumes a node. There is no alpha-beta or chance pruning in the first version. A budget stops both chance and decision expansion. Iterative deepening publishes only completed iterations, retaining scores for every legal move at the same depth. The zero-depth fallback is the static evaluation, explicitly marked incomplete. No transposition table is needed yet.

## Scores and play

The target is current-round win probability, not final match cash. A round winner is exact, with 1 for the winner and 0 for others. Internal scores use fixed-point millionths, displayed as win percent by dividing by 10,000. Rounding affects expectations by at most a few units per tree level. Regret is the best score minus the chosen move's score, in the same units.

A separate evaluator normalizes each living player's effective health. Starting item weights, tempo, knowledge and jam weights live in one module and are documented in its README. These are estimates, not fitted probabilities. The policy adds one weakness knob: a seeded uniform pick among moves within a supplied score gap of the best. Depth and budget remain explicit. Analysis and play share one entry point; neither is registered with the web or arena here.
