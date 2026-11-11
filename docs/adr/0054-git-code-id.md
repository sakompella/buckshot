# The git commit as the code identity

> Amended 2026-11-11: the identity and the dirty-tree check cover only the paths that play (`web/`, `sim/`, `flake.lock`), and the test suite plays under the code id `test`.

A match records the git commit of the checkout it plays from, and refuses to start or resume while that checkout has uncommitted changes to tracked files, so the commit alone identifies the code that played it. A resume must bring the same commit. This replaces the hash of the playing files (`codeSha`, `PLAY_FILES`) that ADR-0039 introduced and ADR-0041 carried; the rest of both records stands.

## Considered Options

- Keeping the file hash: it changes exactly when gameplay code changes, but it is a second identity beside the commit, and its hand-listed files go stale silently the first time a new file starts to matter and is not added.
- The commit without the dirty-tree check, as ADR-0039 rejected it: uncommitted edits would pass, and a commit would not identify the code. The check closes that hole, and the other half of the old objection — that a docs-only commit changes the identity — is accepted: any commit is a new version.

## Consequences

- Any edit to the tree, gameplay or not, is a new code version once committed: matches stop resuming across it, and a tournament mixes versions as ADR-0041 says, with `--code <commit>=<web dir>` naming a checkout to resume from.
- A dirty tree refuses to play. The tests that start matches would need a clean checkout too, so `bun run test` sets `BUCKSHOT_CODE=test`, and every match and tournament it starts records the code id `test` instead of a commit. Tests can then run before the commit, as the workflow asks.

## Amendment: only the paths that play

The code version is the last commit that changed `web/`, `sim/` or `flake.lock` (which pins Bend), and the dirty-tree check looks at those paths only (`PLAYING` in `web/src/arena/match.ts`). A commit that only changes the docs, `tools/` or `dev/` is no new code version, so matches resume across it. The first consequence above now reads: any committed edit under those paths is a new code version.
- Old manifests keep their `code_sha`; the importer reads it, in one place, as the code identity of matches from before commits were recorded. A journal from before this change has no commit, so its match refuses to resume and is started again.
