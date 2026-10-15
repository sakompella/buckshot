# The arena sends each log entry once, from a cursor in its journal

ADR-0003 keeps views free of delivery state, because a lost tool reply would lose events. In the arena nothing is lost on the way: every delivery is a message written into the agent's pi-durable conversation in the store. So the arena keeps one cursor per agent in its journal, counting the entries of that agent's log it has sent, and sends each entry once. With on-turn delivery the new entries come with the agent's turn. With live delivery they come as they happen, through write submissions, which add a message without a model call. Tool results carry no entries. The views themselves stay as ADR-0003 says.

## Considered Options

- Entries in every view and tool result, as ADR-0003 gives them: models got the same entries twice in one turn, and live delivery would repeat them a third time.
- A second buffer of entries carried past forced turns: this was the first design, and the cursor replaced it.

## Consequences

The audit rebuilds the entries each transcript was sent and checks that they add up to the agent's log exactly, with no gaps or repeats.
