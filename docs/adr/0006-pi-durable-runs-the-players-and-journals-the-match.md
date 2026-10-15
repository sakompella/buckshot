# pi-durable runs the players and journals the match

Each match has one pi-durable store, `session.sqlite`, holding every player's conversation and a match journal: the seed, the seats, and every move with who played it. pi-durable commits every model reply and tool call before acting on it. So after a crash the arena rebuilds the table from the seed and the journal, resumes the conversations, and resubmits the turn under the same request id, and the match ends as an uninterrupted one would. The game replays from the seed and the journal; model answers are reread from the store, never regenerated.

## Considered Options

- A hand-written agent loop with its own log: we would rebuild what pi-durable already does (retries, compaction, idempotent submits, crash recovery).
- One store per tournament: one process owns a store, so a stuck match would block the whole file.

## Consequences

The arena depends on pi-durable 1.1.0, which is experimental, so the version is pinned. Its store is the record of a match: deleting `session.sqlite` loses the transcripts.
