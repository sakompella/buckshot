# Accuracy

How the arena page scores move quality. It mirrors lichess ([lila](https://github.com/lichess-org/lila) `AccuracyPercent.scala` and `Advice.scala`, scalalib `Maths.scala`) over our regret scores. Code: `web/src/arena-viewer/accuracy.ts`. Regret stays the internal term; the page says "points lost".

## Scale

A score is the deciding player's round win chance, in points (0 to 100; the regret table stores millionths). Lichess's win percent plays that role. A move's drop is its regret: the best move's score minus the chosen move's.

## Per move

`accuracy = 103.1668100711649 * exp(-0.04354415386753951 * drop) - 3.166924740191411 + 1`, clamped to 0 to 100; 100 when the drop is 0. The `+ 1` is lichess's bonus for an imperfect analysis, kept because ours is a depth-limited search.

## Per game (a seat in a match)

As lichess's `gameAccuracy`: the mean of a volatility-weighted mean and a harmonic mean of the move accuracies.
- Weight of a move: the population standard deviation of the win chances in a sliding window around it, clamped to 0.5 to 12. Window size is `(positions - 1) / 10` clamped to 2 to 8; the first windows repeat the first window, as lichess does.
- Harmonic mean: `n / sum(1 / max(1, accuracy))`.
- A config's accuracy is the mean of its seats' game accuracies.

## Judgements

Lichess's thresholds are 0.1, 0.2 and 0.3 of its winning chances, which run from -1 to 1, so they are 5, 10 and 15 points of win chance: inaccuracy from 5, mistake from 10, blunder from 15 (`BLUNDER_POINTS` was 10 before). The page shows each per 100 moves, plus the share of best moves (no points lost), the mean points lost (the counterpart of lichess's average centipawn loss) and the 99th percentile of points lost (nearest rank, zeros counted).

## Adaptations

- Our position series is not one continuous game. Each seat's series is the win chance before each of its own moves (the best move's score), then the last chosen score; the opponent's moves and round boundaries are not in it. Move accuracy uses each move's own best and chosen score, not the next position's.
- Decisions where every move scores within 1 point are left out of everything above (no real choice).
- Scores come from two runs, labelled per move as `source` (`static` or `sampled`): the sampled-reload run (`regret-sampled256-native.sqlite`, evaluator group sampled/256) for decisions with 2 shells or fewer left, and the static run (`regret.sqlite`) for the rest. Where both have a decision the sampled score wins. The viewer and `arena-export.ts` take it with `--regret-sampled <db>` next to `--regret <db>`; the live viewer unit needs the flag.
