"""Do pair effects beat ratings alone on held-out seed blocks?

Blocks are split into folds, the model is fitted on the other folds and scored by log loss on the held-out blocks.
Pair effects are shrunk by tau; tau = 0 is ratings alone. The fixed-tau rows pick the best tau with the held-out
blocks in view, so the verdict uses the nested row: inside each training set an inner cross-validation picks tau
(0 included), and the outer fold only ever scores blocks that choice never saw.
"""

import random

import bt
from load import Game, blocks_of

GRID = [0.0, 0.1, 0.2, 0.4, 0.8, 1.6]


def folds(ids: list[str], k: int, rng: random.Random) -> list[list[str]]:
    shuffled = ids[:]
    rng.shuffle(shuffled)
    return [shuffled[i::k] for i in range(k)]


def fit_on(by_block: dict[str, list[Game]], ids: list[str], names: set[str], tau: float, terms: bool, pair_terms: set[tuple[str, str]] | None = None) -> bt.Fit:
    """terms adds a seat term and a round 1 starter term to the ratings."""
    games = [game for block in ids for game in by_block[block]]
    return bt.fit(bt.cells_of(games, starter=terms), tau=tau, seat=terms, start=terms, entrants=names, pair_terms=pair_terms)


def best_tau(by_block: dict[str, list[Game]], ids: list[str], names: set[str], terms: bool, rng: random.Random, k: int, pair_terms: set[tuple[str, str]]) -> float:
    """The tau with the lowest held-out loss over k folds of these blocks; the smaller tau wins a tie."""
    totals = {tau: 0.0 for tau in GRID}
    for held in folds(ids, k, rng):
        train = [b for b in ids if b not in set(held)]
        test = [game for block in held for game in by_block[block]]
        for tau in GRID:
            totals[tau] += bt.log_loss(fit_on(by_block, train, names, tau, terms, pair_terms), test)
    return min(GRID, key=lambda tau: (totals[tau], tau))


def nested(games: list[Game], terms: bool, rng: random.Random, repeats: int = 5, outer: int = 10, inner: int = 5):
    """Per block, the held-out log loss averaged over the repeats, for each fixed tau and for the nested choice.

    Returns (losses, chosen): losses maps 'tau=..' and 'nested' to {block: loss}; chosen counts the taus picked.
    """
    by_block = blocks_of(games)
    ids = sorted(by_block)
    names = {name for game in games for name in (game.first, game.second)}
    block_count: dict[tuple[str, str], int] = {}
    for block_games in by_block.values():
        for pair in {bt.pair_of(game.first, game.second) for game in block_games}:
            block_count[pair] = block_count.get(pair, 0) + 1
    pair_terms = {pair for pair, count in block_count.items() if count > 1}
    sums: dict[str, dict[str, float]] = {}
    chosen = {tau: 0 for tau in GRID}
    for _ in range(repeats):
        for held in folds(ids, outer, rng):
            train = [b for b in ids if b not in set(held)]
            tau_star = best_tau(by_block, train, names, terms, rng, inner, pair_terms)
            chosen[tau_star] += 1
            fits = {tau: fit_on(by_block, train, names, tau, terms, pair_terms) for tau in GRID}
            for block in held:
                for label, tau in [*((f"tau={t}", t) for t in GRID), ("nested", tau_star)]:
                    row = sums.setdefault(label, {})
                    row[block] = row.get(block, 0.0) + bt.log_loss(fits[tau], by_block[block])
    return {label: {b: v / repeats for b, v in row.items()} for label, row in sums.items()}, chosen
