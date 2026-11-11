# Round Elo

> Accepted 2026-10-28 (the viewer's default rating since then); written down 2026-11-11.

The arena's rating is Round Elo: one Bradley-Terry fit over every scored two-player match of every tournament, in which each round is a game. A match with three rounds adds three games, with the round winner as the winner. Ratings are in Elo points, one scale for every config (model, endpoint and effort), because effort sweeps meet the other models through their medium configs. Intervals come from refitting resamples of whole seed blocks, since the rounds of a match, and the two seat orders of a seed, are not independent. The fit is in `web/src/arena-viewer/page/ratings.ts` and again, for the docs, in `tools/arena/analysis/bt.py` (`round_elo`); `test_round_elo.py` ties them.

## Considered Options

- **Fit on match results.** Two round wins decide a match, so a match is a coarse win or loss and carries less than its three rounds do. It gives a wider scale (about 1.6 times) with more noise. It stays in `docs/arena/analysis/matchups.md` as a derived view.
- **Fit on pot share (cash).** A loser's banked round prizes show in cash, so it spreads less than match results. It is not what the game is played for, and it is still a function of the same rounds. Kept in matchups.md only.

## Consequences

- Only matches whose rounds are known count, and only two-player ones.
- Round Elo is not match Elo. A rating of +120 corresponds to about +200 on match results, so a reader must not read it as a match win rate against the anchor.
- A dead rubber (round 3 after a 2-0 lead) counts as a round. See `docs/arena/analysis/regret.md` (By round) for why that is kept.
