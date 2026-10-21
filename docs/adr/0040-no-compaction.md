# No compaction

pi-durable can compact a conversation near its model's context window. The arena turns that off for every match and records `compaction: "off"`. A summary would have to keep every log entry the agent was sent, exactly once, and the delivery audit checks that; a summary that drops or repeats entries gives one agent a different match from the others. The longest real match so far, `three-1`, peaked near 70k tokens of context, within every entrant's window, so compaction would only save cost.

## Considered Options

- Compaction with a summary of this round's entries: it lost earlier rounds and repeated entries still in the kept tail.
- A correct summary with a forced-compaction parity check: possible, but it is work no match yet needs.

## Consequences

A match that outgrows a model's window fails as a provider error, which stops it as a resumable fault (ADR-0009) rather than playing on with a lossy history. Cost grows with every call, because each call rereads the whole conversation.
