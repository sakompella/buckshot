# A seat sees and hears only what its screen shows

The machine gives each seat what it observes (`observe`: the public board), what it hears (`hear`: private results such as what the magnifying glass showed) and its prompt of legal moves. None is built from the host's full state. The hidden shell order and the decks never enter them. A point's draw range can reveal the deck size, so a point is controller data and never goes to a seat. The law `privacy` says that replacing the shell order and decks, with a gun of the same length, changes neither what a seat observes nor what it hears, for all states. AIs get only these. Agent views are built from the public log and the secrets heard (ADR-0003). Private here means presented to that seat only. It does not mean secret from the host or from a modified client, whose network-level leaks are outside the model (ADR-0019).

## Consequences

Any new fact a seat should learn must be a note that only that seat hears, or part of the public board.
