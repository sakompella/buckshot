# Timing, networking and cosmetics are outside the model

The library is the rules of the game, not the running game. It has no clock. Rule effects happen in the order they happen in normal play, and the models do not time them. Out of scope are graphics, animation, sound, networking, the lobby, seat shuffling, disconnects, timeouts, frame and screen timing, and end-of-match titles (ADR-0025). Timeouts are off in the shipped game, so no timer rule exists to model. An animation counts only when it triggers a rule effect, such as the saw. Then the effect is modelled and ordered against other effects, but not timed.

## Consequences

The real engine can reorder some effects under unusual timing, for example a very long frame that ends a turn before a shot resolves. These are recorded in the local decision log as diagnostics. They are not laws and no proof covers them. ADR-0017 is one place where the no-clock rule forced a choice.
