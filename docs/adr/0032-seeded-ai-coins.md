# Seeded AI coins

Story and DoN (Double or Nothing) are ports of the verified two-player dealer policies in `sim/python/dealer_vs_dealer.py`, and DoN is Story plus three upgrades. Each is one pure Bend function from its seat's prompt, the public board, what it heard and its own memory to a move of the machine's own legal type. `check.sh` enforces that `ai/` imports only the domain types, so a wrong decision can only come from AI code, never from hidden state. The driver gives each AI its own seeded coin stream. A seat's choices then do not depend on how many coins another seat used, and a seed replays a match. The web page and the Bend driver call the same AI entry points and the same coin function.

## Consequences

In mirror matches later seats win more often; these seeds do not say whether the cause is turn order or a bias in the AIs.
