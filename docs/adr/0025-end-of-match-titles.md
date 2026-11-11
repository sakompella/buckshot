# End-of-match titles

> Superseded 2026-11-10 by ADR-0053: the end screen and `web/src/titles.ts` are deleted with the game table. The rules library still drops the titles. The text below is kept as history.

The rules library keeps cash and round winners and drops the real game's end-of-match statistics and titles. The public event log carries enough (shots, damage, hits, cigarettes, items used) for `web/src/titles.ts` to compute them. A rule that only decorates the end screen does not belong in the proofs.
