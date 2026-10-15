# Three deliberate fixes to the real game's rules

The models follow the real rules except for three fixes, each for a bug that changes game state, not for presentation, transport or timing. Both models carry them, and the comparison harness (ADR-0021) carries the same edits, so the laws and the harness stay exact.

- **M1, distribution can stall.** With custom item caps, the last placement can leave no seat grabbing while distribution stays open, and no reload follows. After the seats with nothing eligible are ended, the game's own finished check runs again, and the reload follows if it passes.
- **M3, new-round grabbers.** At a new round the real game picks which seats get items before it clears old inventories. With custom settings that can skip a seat or the whole first distribution. The models pick after clearing, with the new round's settings.
- **M4, the adrenaline freeze.** Adrenaline can start a steal in which no opponent item can be picked and there is no cancel, so the turn freezes. It can happen with default settings. Adrenaline is a legal move only if some opponent item could be stolen and used.

M2 was withdrawn. It proposed clearing the saw when beer empties the gun. The real game keeps it, for the next shot by anyone, in single player too, so it is how the game plays. The numbers M1, M3 and M4 were kept.

## Consequences

M3 and M4 were adopted as defaults that the operator may override. A fix changes the legal move set or the order of effects, so it is made in both models and never in one.
