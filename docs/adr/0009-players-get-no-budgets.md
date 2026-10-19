# Players get no budgets

The arena enforces no token, cost, time or step budget on a player. Fairness comes from the same instructions, the same two tools and seat rotation, and usage is recorded so it can be compared afterwards (ADR-0008). The arena plays a fallback move only when a model ends its turn without moving, even after one reminder (ADR-0038). When the provider fails, the match stops as a fault that can be resumed: a provider outage must not turn into moves.

## Considered Options

- Equal token or time budgets with fallback moves past them: they measure a model under a limit someone chose, not the model, and they mix provider slowness into the results.

## Consequences

A model that keeps calling `get_game` without ever moving would stall its match. The logs show it as it happens, and the operator stops the run.
