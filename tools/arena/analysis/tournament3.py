"""Tournament 3 (Opus 5.5 xhigh vs Astra medium): the 41-match and the 40-match estimates, and the matched seeds.

Seed 3030 has only its first match scored, so the 41 matches are 20 complete seed pairs and one half block; the 40
matches are the 20 complete pairs. Both are one pair of entrants, so the Bradley-Terry gap is the log odds of the
pooled win share.
"""

import random

import boot
import bt
from fmt import table
from load import Game, blocks_of

OPUS, ASTRA = "claude-opus-5-5-xhigh", "gpt-6-astra-medium"
OPUS_MEDIUM = "claude-opus-5-5-medium"


def opus_share(game: Game) -> float:
    return game.share_first if game.first == OPUS else 1 - game.share_first


def estimate(games: list[Game], draws: int, rng: random.Random) -> list[str]:
    """Pooled share, mean of block shares, and the Elo gap, each with a block bootstrap interval."""
    by_block = blocks_of(games)
    ids = sorted(by_block)
    won = {b: sum(opus_share(g) for g in by_block[b]) for b in ids}
    size = {b: len(by_block[b]) for b in ids}
    pooled, paired, gap = [], [], []
    for _ in range(draws):
        picked = [rng.choice(ids) for _ in ids]
        total = sum(won[b] for b in picked) / sum(size[b] for b in picked)
        pooled.append(total)
        paired.append(sum(won[b] / size[b] for b in picked) / len(picked))
        weights = boot.weights(ids, rng)
        sample = bt.fit(bt.cells_of(games, weights)).elo()
        gap.append(sample[OPUS] - sample[ASTRA])
    total_won, total_size = sum(won.values()), sum(size.values())
    elo = bt.fit(bt.cells_of(games)).elo()
    outcomes = [round(won[b] / size[b], 2) for b in ids if size[b] == 2]
    return [
        f"{total_won:g}/{total_size} = {total_won / total_size * 100:.1f}%",
        f"{boot.interval(pooled)[0] * 100:.1f}% to {boot.interval(pooled)[1] * 100:.1f}%",
        f"{sum(won[b] / size[b] for b in ids) / len(ids) * 100:.1f}%",
        f"{boot.interval(paired)[0] * 100:.1f}% to {boot.interval(paired)[1] * 100:.1f}%",
        f"{elo[OPUS] - elo[ASTRA]:+.0f} ({boot.interval(gap)[0]:+.0f} to {boot.interval(gap)[1]:+.0f})",
        f"{outcomes.count(1.0)} / {outcomes.count(0.5)} / {outcomes.count(0.0)}",
    ]


def matched(t3: list[Game], baseline: list[Game], draws: int, rng: random.Random) -> list[str]:
    """Opus xhigh minus Opus medium against Astra on the seeds both played, per seed and in share."""
    new, old = {}, {}
    for game in t3:
        new.setdefault(game.seed, []).append(opus_share(game))
    for game in baseline:
        old.setdefault(game.seed, []).append(game.share_first if game.first == OPUS_MEDIUM else 1 - game.share_first)
    seeds = sorted(s for s in set(new) & set(old) if len(new[s]) == 2 and len(old[s]) == 2)
    diff = {s: sum(new[s]) - sum(old[s]) for s in seeds}
    a, b = sum(sum(new[s]) for s in seeds), sum(sum(old[s]) for s in seeds)
    n = 2 * len(seeds)
    replicates = [sum(diff[rng.choice(seeds)] for _ in seeds) / n for _ in range(draws)]
    low, high = boot.interval(replicates)
    return [
        f"{len(seeds)} seeds, {n} matches each",
        f"{a:g}/{n}",
        f"{b:g}/{n}",
        f"{(a - b) / n * 100:+.1f} pp ({low * 100:+.1f} to {high * 100:+.1f})",
    ]


def report(games: list[Game], draws: int, rng: random.Random) -> str:
    t3 = [g for g in games if g.cohort == "tournament 3"]
    baseline = [g for g in games if g.cohort == "tiers cross-model" and {g.first, g.second} == {OPUS_MEDIUM, ASTRA}]
    complete = [g for g in t3 if len(blocks_of(t3)[g.block]) == 2]
    rows = [
        ["41 matches, 21 seed blocks (seed 3030 half)", *estimate(t3, draws, rng)],
        ["40 matches, 20 complete seed pairs", *estimate(complete, draws, rng)],
    ]
    out = [
        table(["scored matches", "Opus xhigh wins/matches = share", "95% CI (seed blocks drawn, wins over matches)", "mean of block shares (a block counts once)", "95% CI", "Opus minus Astra, Elo (95% CI)", "blocks Opus both / split / Astra both"], rows),
        "\nThe 41-match estimate adds seed 3030's one scored match, which Astra won, to the 40 matches of complete pairs.",
        "\n#### Matched against Opus medium vs Astra on the same seeds (tournament 1)\n",
        table(["matched seeds", "Opus xhigh wins", "Opus medium wins", "difference in share (95% CI, seeds drawn)"], [matched(t3, baseline, draws, rng)]),
        "\nThe matched seeds are 3000 to 3009, so the matched estimate is the same whether tournament 3 counts 40 or 41 matches.",
    ]
    return "\n".join(out)
