# A tournament spans code versions, and each match finishes on the code it started with

A fix to how the arena plays, such as effort off really disabling thinking, can come while a tournament has matches stopped partway by a provider's limit. The tournament takes the new code version anyway. New matches start under the runner's code. A started match resumes under the code version its journal records (ADR-0039), run from a checkout of that version that the runner is given with `--code <code_sha>=<web dir>`; without one it waits. The stats list every version with its matches, and give the win share per version of each entrant that played under more than one. Because the requests a model is sent are part of how a match plays, `endpoints.ts`, which builds them, is in the code hash.

## Considered Options

- Draining: start no new match until every started one finishes on the old code. A match stopped by a free tier's limit can wait for days, and the tournament with it.
- Starting the stopped matches again on the new code: it throws away the moves played and their cost.
- One code version per tournament: a fix waits for the tournament to end, or starts a new one.

## Consequences

An old checkout stays on disk until the last match started under it finishes. Results from two versions pool only where the change leaves an entrant's requests alone. A report that pools them says so, with evidence such as the requests captured for each entrant under both versions.
