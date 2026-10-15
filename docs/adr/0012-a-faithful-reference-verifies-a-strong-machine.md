# A faithful reference verifies a strong machine

The rules exist twice in `sim/bend-mp/`. The reference (`ref/`) follows the real game's multiplayer rules function by function and exists only to be checked. The machine (`sm/`) is the product: a typed state machine written for clarity, in which a move the rules do not offer cannot be built. Laws say the two agree on every config, state and answer (ADR-0014). One model written for clarity would have nothing to be trusted against. One written to mirror the original is too tangled to build on.

## Considered Options

- Test the machine against the real game only: it finds bugs but cannot say there are none.
- A bug-for-bug port: the reference keeps the real rules, quirks included, except for the approved fixes of ADR-0016. Intended rules instead of real ones would be a different model.

## Consequences

A rule change is made in both models and the laws must still check. The reference is trusted only as far as the real-game comparison reaches (ADR-0021).
