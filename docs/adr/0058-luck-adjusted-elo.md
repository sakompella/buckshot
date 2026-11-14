# Luck-adjusted Round Elo

> Accepted 2026-11-08; written down 2026-11-11.

The headline rating is Round Elo (ADR-0056) with the luck of each round's chance events taken out. At each chance event, the correction is the expected value over the outcomes minus the value of the one that came, in round wins. The chance events are the shots (the chamber's live chance, given both players' clues), the loads (drawn from a known deck of nine compositions), the coin that picks round 1's first seat, the item deals (each item a uniform draw from the pool the caps leave) and the shells glass, beer and the phone show (valued by the search of the regret file, with the drift of its values removed out of fold). The value of the state after an event comes from a small model fitted out of fold by seed, so no round is corrected by a model that saw it. This is an AIVAT-style correction. The code is `tools/arena/analysis/aivat.py`; it writes the corrections to `derived/luck.sqlite` (per match and player), and the viewer (`--luck`), the export and `results.md` add them to the round wins before the Round Elo fit. The method and its tables are in `docs/arena/analysis/matchups.md#luck-adjusted-round-elo`.

## Considered Options

- **Raw Round Elo.** Unbiased, but a round's result is mostly luck, so intervals are wide. The adjustment cuts the median 90% half-width from about 30 to about 25 Elo.
- **Decision terms too.** Needs a model of the players' policies, which are unknown. The correction uses chance events only.

## Consequences

- The corrections have mean zero for any value model that depends only on the history before the event, so the strengths stay the same in expectation. A bias test checks it on the data (the mean correction per config, and its correlation with Round Elo fitted on the other half of the seeds).
- It also corrects the round-1 starter imbalance of unpaired tournaments, which raw ratings do not.
- A viewer started without `--luck` shows plain Round Elo. The numbers on the site and in `results.md` must come from the same luck file.
- The value models need the knowledge database (`derived/knowledge.sqlite`) and the regret file, so the wrap-up runs the luck step after both, and a rescored regret file needs a new luck file.
- The search's values are not a function of the history alone in practice (they drift with the position), so the item-shell terms are only as unbiased as the drift removal; the bias test must pass at every rebuild.
