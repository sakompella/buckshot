# Fixed match config

> The code identity is superseded 2026-11-11 by the git commit (ADR-0054): the journal records the commit of the checkout, refused over uncommitted changes, instead of a hash of the playing files. The rest of this record stands.

When a match starts, its journal records what decides how it plays: a hash of the files that make up the rules and the arena's turn loop, the hash of the instructions, that compaction is off (ADR-0040), and for each agent the API, provider id, base URL, model, catalog model, effort and the thinking settings that effort resolves to in pi-ai. A rerun that resumes the match computes the same record from its own configuration and stops with the differences listed if any field changed. Keys are not recorded, so a key can change between a crash and a resume. The manifest shows the recorded configuration, not the one of the latest run.

## Considered Options

- Checking only the model id: the same id behind another URL can be another model, and a different effort or code changes play.
- The git commit: uncommitted edits would pass, and a commit that only touches docs would be refused.

## Consequences

A match from before this record cannot be resumed; it is started again. Any edit to a file in the code hash, `bun.lock` included, makes the matches it would resume refuse to run, so each match is finished on the code it started with, from a checkout of that code when the tournament has moved on (ADR-0041). Since ADR-0054 the code identity is the git commit, so this holds for any edit, and only over a clean tree.
