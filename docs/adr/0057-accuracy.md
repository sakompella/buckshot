# Accuracy

> Accepted 2026-11-06; written down 2026-11-11.

The arena page scores the quality of a config's moves as accuracy, computed as lichess computes it, with regret as the drop in win chance. Each move is scored from the points of round win chance it gave up, a game combines a volatility-weighted mean and a harmonic mean of its moves, and a config averages its games. 100 is perfect. The page also shows mean points lost, the 99th percentile of points lost, and inaccuracies, mistakes and blunders per 100 moves, with lichess's cut-offs of 5, 10 and 15 points. The method and its adaptations are in `docs/arena/analysis/accuracy.md`; the code is `web/src/arena-viewer/accuracy.ts`.

"Regret" stays the internal word (ADR-0052's search scores, the `regret` table). Readers see "points lost" and "accuracy".

## Considered Options

- **Mean points lost only.** It is simple and is still shown, but it has no familiar scale and weights a calm position the same as a swingy one.
- **A made-up scale.** Lichess's accuracy is public, tested on millions of games and known to many readers. Copying it costs nothing and avoids inventing a new score.

## Consequences

- Our search is depth limited, so the per-move formula keeps lichess's `+ 1` bonus for an imperfect analysis.
- The position series is not one continuous game: each seat's series is the win chance before its own moves, so the volatility weights are only roughly lichess's.
- Decisions where every move scores within 1 point are left out: they are no real choice.
- Accuracy is a function of the regret scores of one production run (ADR-0052). A new evaluator id means new accuracies.
