# Pending placements finish before a latched reload

When distribution finishes while a seat still holds a granted item it has not placed, that placement is applied before the reload. The real game's reload waits a short fixed time and a normal client places inside it. A slower holder is client timing, which is outside the model (ADR-0018). The model has no clock, so it needs an order, and this is the one a normal game has. The completion check itself is unchanged. This is D56 in the local decision log.

## Consequences

The comparison harness injects the pending placement inside the real game's wait, so both sides follow this order.
