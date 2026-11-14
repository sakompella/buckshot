#!/usr/bin/env python3
"""Matchup analysis of the scored arena matches: ratings per cohort, pair effects, seat and starter effects.

Reads the analysis database read-only and prints markdown tables. With --doc FILE the tables replace the text
between the tables markers of that file. Ratings come from one pooled fit over every scored match; kinds (see kind_of below) group matches only for pair effects and seat figures. Rating intervals
are 90% bootstraps over seed blocks (`boot.LEVEL`), the other intervals 95%, drawn with a fixed RNG seed so a rerun prints the same numbers.

    python3 tools/arena/analysis/matchups.py [--db PATH] [--draws N] [--doc docs/arena/analysis/matchups.md]
"""

from pathlib import Path
import argparse
import random
import statistics
from dataclasses import replace

import boot
import bt
import cv
import seats
import tournament3
from configs import config_label
from docs import splice_between_markers
from fmt import frac, pct, pp, signed, span, table
from load import DB, Game, blocks_of, cohorts, connect, scored_games, require_current

def kind_of(model_a: str, model_b: str) -> str:
    """Pairs and seats are compared only inside one kind of comparison pooled over every tournament: all matches between different models, or all of one model's matches against itself."""
    return "Cross-model" if model_a != model_b else f"{model_a} efforts"


# ---- coverage

def coverage(db, by_cohort: dict[str, list[Game]]) -> str:
    scheduled: dict[str, dict[str, int]] = {}
    for status, disposition, *seat in db.execute(
        """SELECT m.status, m.disposition, a.model, b.model
           FROM matches m
           JOIN match_seats sa ON sa.match_id = m.id AND sa.position = 1 JOIN entrants a ON a.id = sa.entrant_id
           JOIN match_seats sb ON sb.match_id = m.id AND sb.position = 2 JOIN entrants b ON b.id = sb.entrant_id
           WHERE m.disposition IS NOT 'excluded'"""
    ):
        cohort = kind_of(*seat)
        label = status if disposition is None else f"{status} ({disposition})"
        scheduled.setdefault(cohort, {}).setdefault(label, 0)
        scheduled[cohort][label] += 1
    rows = []
    for name, games in by_cohort.items():
        entrants = sorted({n for g in games for n in (g.first, g.second)})
        per_pair: dict[tuple[str, str], int] = {}
        for g in games:
            pair = bt.pair_of(g.first, g.second)
            per_pair[pair] = per_pair.get(pair, 0) + 1
        counts = sorted(per_pair.values())
        sizes = [len(b) for b in blocks_of(games).values()]
        parts = bt.components(games)
        rows.append(
            [
                name,
                str(len(entrants)),
                str(len(games)),
                f"{sizes.count(2)} / {sizes.count(1)}",
                f"{len(per_pair)}/{len(entrants) * (len(entrants) - 1) // 2}",
                f"{counts[0]} / {statistics.median(counts):g} / {counts[-1]}",
                "yes" if len(parts) == 1 else f"no, {len(parts)} groups",
                ", ".join(f"{n} {s}" for s, n in sorted(scheduled.get(name, {}).items())),
            ]
        )
    header = ["cohort", "entrants", "scored matches", "complete / half blocks", "pairs played", "matches per pair min / median / max", "connected", "scheduled by status"]
    return table(header, rows)


# ---- pooled ratings and observed pairs

SHARES = {"wins": lambda game: game.share_first, "cash": lambda game: game.pot_first}


def summarize(cells: bt.Cells, theta: dict[str, float]):
    """For each pair, the games, the first-named entrant's observed wins and its wins fitted by the pooled ratings."""
    pairs = {}
    for low, high in sorted({bt.pair_of(*key) for key in cells}):
        forward = cells.get((low, high), [0.0, 0.0])
        backward = cells.get((high, low), [0.0, 0.0])
        n = forward[0] + backward[0]
        pairs[(low, high)] = (n, forward[1] + backward[0] - backward[1], n * bt.sigmoid(theta[low] - theta[high]))
    return pairs


def pooled_ratings(games: list[Game], by_cohort: dict[str, list[Game]], draws: int, rng: random.Random) -> tuple[str, dict[str, str]]:
    """One fit over every scored match, on win shares and again on pot shares, and each pair's residual against it.

    The same resampled blocks refit both, so the two ratings' intervals are comparable. Returns the ratings table
    and the observed-pair tables of the cohorts in `by_cohort`.
    """
    names = {n for g in games for n in (g.first, g.second)}
    fits = {basis: bt.fit(bt.cells_of(games, share=share), entrants=names) for basis, share in SHARES.items()}
    elo = {basis: fitted.elo() for basis, fitted in fits.items()}
    # Draws are centred, then moved by the point fit's shift, so the intervals leave out the anchor's own noise (bt.Fit.elo).
    zero = {basis: fitted.elo(None).get(bt.ANCHOR, 0.0) for basis, fitted in fits.items()}
    ids = sorted(blocks_of(games))
    rating_draws = {basis: {} for basis in SHARES}
    effect_draws: dict[str, dict[tuple[str, str], list[float]]] = {name: {} for name in by_cohort}
    for _ in range(draws):
        weights = boot.weights(ids, rng)
        for basis, share in SHARES.items():
            sample = bt.fit(bt.cells_of(games, weights, share=share), entrants=names)
            for entrant, value in sample.elo(None).items():
                rating_draws[basis].setdefault(entrant, []).append(value - zero[basis])
            if basis == "wins":
                for name, cohort_games in by_cohort.items():
                    for pair, (n, won, expected) in summarize(bt.cells_of(cohort_games, weights), sample.theta).items():
                        effect_draws[name].setdefault(pair, []).append((won - expected) / n)
    seeds = sorted({g.seed for g in games})
    seed_draws: dict[str, list[float]] = {}
    for _ in range(draws):
        sample = bt.fit(bt.cells_of(games, boot.weights(seeds, rng), unit=lambda g: g.seed), entrants=names).elo(None)
        for entrant, value in sample.items():
            seed_draws.setdefault(entrant, []).append(value - zero["wins"])
    totals: dict[str, list[float]] = {}
    for g in games:
        for entrant, share, pot in ((g.first, g.share_first, g.pot_first), (g.second, 1 - g.share_first, 1 - g.pot_first)):
            row = totals.setdefault(entrant, [0.0, 0.0, 0.0])
            row[0] += 1
            row[1] += share
            row[2] += pot
    rows = [
        [
            e,
            frac(totals[e][1], totals[e][0]),
            signed(elo["wins"][e]),
            span(boot.interval(rating_draws["wins"][e], boot.TAIL), signed),
            span(boot.interval(seed_draws[e], boot.TAIL), signed),
            pct(totals[e][2] / totals[e][0]),
            signed(elo["cash"][e]),
            span(boot.interval(rating_draws["cash"][e], boot.TAIL), signed),
        ]
        for e in sorted(names, key=lambda e: -elo["wins"][e])
    ]
    header = ["config", "wins/matches = win share", "rating (Elo, depth-7 engine at 0)", f"{boot.PERCENT} CI, seed blocks drawn", f"{boot.PERCENT} CI, seeds drawn (sensitivity)", "pot share", "cash rating (Elo, depth-7 engine at 0)", f"{boot.PERCENT} CI, seed blocks drawn"]
    text = "\n".join([table(header, rows), sensitivity(games, names, elo["wins"])])
    pair_header = ["pair", "wins/matches = observed share", "fitted share", "difference (pp)", "bootstrap range of the difference (descriptive)"]
    pair_tables = {}
    for name, cohort_games in by_cohort.items():
        pair_rows = [
            [f"{low} vs {high}", frac(won, n), pct(expected / n), pp((won - expected) / n), span(boot.interval(effect_draws[name][(low, high)]), pp)]
            for (low, high), (n, won, expected) in summarize(bt.cells_of(cohort_games), fits["wins"].theta).items()
        ]
        pair_tables[name] = f"#### {name}\n\n" + table(pair_header, pair_rows)
    return text, pair_tables


def sensitivity(games: list[Game], names: set[str], elo: dict[str, float]) -> str:
    """How far the pooled ratings move with a seat and starter term."""
    extra = bt.fit(bt.cells_of(games, starter=True), seat=True, start=True, entrants=names)
    moved = max(abs(extra.elo()[e] - elo[e]) for e in elo)
    return f"\nWith a seat term and a round 1 starter term in the fit (position 1 {extra.seat * bt.ELO:+.0f} Elo, the starter {extra.start * bt.ELO:+.0f} Elo) the largest rating change is {moved:.1f} Elo.\n"


# ---- pair effects against ratings alone

def reverse_pairs(games: list[Game]) -> tuple[int, int, list[float], list[float]]:
    """For each pair, the first-seated entrant's observed minus fitted share when A sat first, and when B sat first.

    A real matchup effect that favours A shows as positive for A first and negative for B first, so the reverse
    ordered pairs should have opposite signs. The fit has a seat term and a round 1 starter term, so neither edge
    fakes it. The counts are descriptive only: the two orders of a block share a seed and the ratings are fitted
    jointly, so the signs are not independent and no test is made.
    """
    names = {n for g in games for n in (g.first, g.second)}
    fitted = bt.fit(bt.cells_of(games, starter=True), seat=True, start=True, entrants=names)
    residual: dict[tuple[str, str], list[float]] = {}
    for g in games:
        cell = residual.setdefault((g.first, g.second), [0.0, 0.0])
        cell[0] += 1
        cell[1] += g.share_first - fitted.p_first(g.first, g.second, g.starter == 1)
    both, opposite, xs, ys = 0, 0, [], []
    for low, high in sorted({bt.pair_of(*key) for key in residual}):
        if (low, high) not in residual or (high, low) not in residual:
            continue
        a = residual[(low, high)][1] / residual[(low, high)][0]
        b = residual[(high, low)][1] / residual[(high, low)][0]
        xs.append(a)
        ys.append(-b)
        if a and b:
            both += 1
            opposite += (a > 0) != (b > 0)
    return opposite, both, xs, ys


def reverse_row(name: str, opposite: int, both: int, xs: list[float], ys: list[float]) -> list[str]:
    correlation = statistics.correlation(xs, ys) if len(xs) > 2 else float("nan")
    return [name, f"{opposite}/{both} = {pct(opposite / both)}", f"{correlation:+.2f}"]


def antisymmetry(games: list[Game]) -> float:
    """The largest |effect of A + effect of B| over the pairs, each entrant's effect summed from its own seats.

    It is 0 when every match's shares sum to 1 and the fit is a two-player model, which is what the data should be.
    """
    names = {n for g in games for n in (g.first, g.second)}
    fitted = bt.fit(bt.cells_of(games), entrants=names)
    sums: dict[tuple[str, str], list[float]] = {}
    for g in games:
        p = fitted.p_first(g.first, g.second)
        low, high = bt.pair_of(g.first, g.second)
        row = sums.setdefault((low, high), [0.0, 0.0, 0.0])
        row[2] += 1
        for entrant, share, expected in ((g.first, g.share_first, p), (g.second, 1 - g.share_first, 1 - p)):
            row[0 if entrant == low else 1] += share - expected
    return max(abs(a + b) / n for a, b, n in sums.values())


def matchup_test(by_cohort: dict[str, list[Game]], rng: random.Random, draws: int, repeats: int) -> str:
    rows, reverse_rows, kept = [], [], []
    for name, games in by_cohort.items():
        names = {n for g in games for n in (g.first, g.second)}
        pairs = {bt.pair_of(g.first, g.second) for g in games}
        if len(pairs) <= len(names) - 1:
            rows.append([name, "-", "-", "-", "-", "-", "-", "no spare pairs: a tree of pairs, so pair effects are not identified"])
            continue
        by_block = blocks_of(games)
        if len(by_block) < cv.OUTER_FOLDS:
            rows.append([name, "-", "-", "-", "-", "-", "-", f"{len(by_block)} seed blocks, under the minimum of {cv.OUTER_FOLDS}: the fit with seat and starter terms can be singular on so few, so not tested"])
            continue
        for with_terms in (False, True):
            losses, chosen = cv.nested(games, with_terms, rng, repeats)
            ids = sorted(by_block)
            per_game = {label: sum(row.values()) / len(games) for label, row in losses.items()}
            gain = {b: losses["tau=0.0"][b] - losses["nested"][b] for b in ids}
            estimate = sum(gain.values()) / len(games)
            replicates = []
            for _ in range(draws):
                picked = [rng.choice(ids) for _ in ids]
                replicates.append(sum(gain[b] for b in picked) / sum(len(by_block[b]) for b in picked))
            low, high = boot.interval(replicates)
            keep = low > 0
            if keep and not with_terms:
                kept.append(name)
            rows.append(
                [
                    f"{name}{' (seat and starter terms)' if with_terms else ''}",
                    f"{per_game['tau=0.0']:.4f}",
                    f"{per_game['nested']:.4f}",
                    f"{estimate:+.4f}",
                    f"{low:+.4f} to {high:+.4f}",
                    ", ".join(f"{t:g}: {n}" for t, n in chosen.items() if n),
                    ", ".join(f"{t}: {per_game[t]:.4f}" for t in per_game if t.startswith("tau=") and t != "tau=0.0"),
                    "kept" if keep else "not kept",
                ]
            )
        reverse_rows.append((name, *reverse_pairs(games)))
    out = [
        table(
            ["cohort", "ratings-only loss", "nested pair-effect loss", "gain per match", "95% CI of gain", "tau chosen (folds)", "fixed-tau loss (picked with the held-out blocks in view)", "verdict"],
            rows,
        ),
        "\nLoss is the mean held-out log loss per match, in nats, over repeats of 10-fold cross-validation over whole seed blocks (a fair coin scores 0.6931). Gain is ratings-only loss minus nested loss, so positive means pair effects helped. A cohort keeps its pair effects only when the lower end of the interval is above 0.",
        "\nReverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first. The counts and correlations are descriptive; the signs are not independent (shared seeds, jointly fitted ratings), so no test is made.\n",
        table(
            ["cohort", "pairs with opposite signs", "correlation of A-first effect with minus B-first effect"],
            [reverse_row(*row) for row in reverse_rows]
            + [reverse_row("all cohorts pooled", sum(r[1] for r in reverse_rows), sum(r[2] for r in reverse_rows), [x for r in reverse_rows for x in r[3]], [y for r in reverse_rows for y in r[4]])],
        ),
    ]
    worst = max(antisymmetry(games) for games in by_cohort.values())
    out.append(f"\nPair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is {worst:.1e}, because each match's shares sum to 1.")
    out.append(f"\nCohorts that keep pair effects: {', '.join(kept) if kept else 'none'}.")
    return "\n".join(out)


# ---- seats and starters

def seat_rows(groups: list[tuple[str, list[seats.Block]]], draws: int, rng: random.Random, extra: dict[str, int], position_only: bool = False) -> str:
    """The headline interval draws seeds (every block played at a seed, in any pairing); seed blocks are the second column."""
    position, starter, effects = [], [], []
    for name, blocks in groups:
        if not blocks:
            continue
        point = seats.estimates(blocks)
        by_block, by_seed = seats.bootstrap(blocks, draws, rng), seats.bootstrap(blocks, draws, rng, by_seed=True)
        matches = 2 * len(blocks)
        left = f" ({extra[name]} matches in half blocks left out)" if extra.get(name) else ""
        label = f"{name}: {len(blocks)} blocks, {len({b.seed for b in blocks})} seeds{left}"
        position.append([label, frac(sum(b.first_wins for b in blocks), matches), span(by_seed["first"]), span(by_block["first"])])
        starter.append([name, frac(sum(b.starter_wins for b in blocks), matches), span(by_seed["starter"]), span(by_block["starter"]), f"{sum(b.starter == 1 for b in blocks)}/{len(blocks)}"])
        if "seat" in point:
            effects.append([name, pp(point["seat"]), span(by_seed.get("seat"), pp), span(by_block.get("seat"), pp), pp(point["start"]), span(by_seed.get("start"), pp), span(by_block.get("start"), pp)])
    parts = ["Position 1:\n\n" + table(["group", "position 1 wins/matches = share", "95% CI, seeds drawn", "95% CI, seed blocks drawn"], position)]
    if not position_only:
        parts += [
            "Round 1 starter:\n\n" + table(["group", "starter wins/matches = share", "95% CI, seeds drawn", "95% CI, seed blocks drawn", "blocks where position 1 starts"], starter),
            "Position and starter effects, in percentage points: a descriptive additive split of block shares by which position starts. Every seed has one starter position, so starter and seed effects are not separated; the seeds-drawn interval is the one that reaches beyond these seeds.\n\n"
            + table(["group", "position effect", "95% CI, seeds drawn", "95% CI, seed blocks drawn", "starter effect", "95% CI, seeds drawn", "95% CI, seed blocks drawn"], effects),
        ]
    return "\n\n".join(parts)


def by_seed_table(blocks: list[seats.Block]) -> str:
    """Per seed, across every cohort: the starter position and how often the starter won."""
    rows = []
    for seed in sorted({b.seed for b in blocks}):
        here = [b for b in blocks if b.seed == seed]
        rows.append([str(seed), str(here[0].starter), str(len(here)), frac(sum(b.starter_wins for b in here), 2 * len(here))])
    big = {s for s in {b.seed for b in blocks} if sum(b.seed == s for b in blocks) >= 10}
    shares = {s: sum(b.starter_wins for b in blocks if b.seed == s) / (2 * sum(b.seed == s for b in blocks)) for s in big}
    seeds, rng = sorted(shares), random.Random(7)
    means = sorted(sum(shares[rng.choice(seeds)] for _ in seeds) / len(seeds) for _ in range(boot.DRAWS))
    mean = sum(shares.values()) / len(shares)
    rows.append([f"the {len(seeds)} seeds with 10 or more blocks, each once", "", str(sum(b.seed in big for b in blocks)), f"mean of seed shares {pct(mean)} (95% CI {pct(boot.quantile(means, 0.025))} to {pct(boot.quantile(means, 0.975))}, seeds drawn)"])
    return table(["seed", "position that starts", "complete blocks", "starter wins/matches = share"], rows)


def seat_section(by_cohort: dict[str, list[Game]], model_of: dict[str, str], draws: int, rng: random.Random) -> str:
    per_cohort, extra = [], {}
    for name, games in by_cohort.items():
        blocks, left_out = seats.complete_blocks(games, model_of)
        per_cohort.append((name, blocks))
        if left_out:
            extra[name] = left_out
    everything = [b for _, blocks in per_cohort for b in blocks]
    models = sorted({m for b in everything for m in b.models})
    per_model = [(m, [b for b in everything if m in b.models]) for m in models]
    return "\n".join(
        [
            "#### Overall and per cohort\n",
            seat_rows([("all cohorts", everything), *per_cohort], draws, rng, {"all cohorts": sum(extra.values()), **extra}),
            "\n#### Per model\n",
            "A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits. Starter figures per model are not reported: a model's blocks cover a handful of seeds, and the starter's result depends on the seed (see below).\n",
            seat_rows(per_model, draws, rng, {}, position_only=True),
            "\n#### Per seed, all cohorts\n",
            "Cohorts reuse seeds 3000 to 3018 (tournament 3 adds 3020 to 3029, and tournament 5 many seeds from 4000 up, most with one block), so a seed's starter result pools many pairings.\n",
            by_seed_table(everything),
        ]
    )


def first_shooter_check(games: list[Game]) -> str:
    same = sum(g.starter == g.first_shot for g in games)
    return f"The player who opened round 1 (from the public line `Round 1 begins ... Player X starts.` in events.jsonl) also fired the first accepted shot in {same} of {len(games)} scored matches."


# ---- main

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db")
    parser.add_argument("--draws", type=int, default=boot.DRAWS)
    parser.add_argument("--repeats", type=int, default=5, help="repeats of the 10-fold cross-validation")
    parser.add_argument("--doc")
    args = parser.parse_args()
    require_current(args.db or DB)
    db = connect(args.db) if args.db else connect()
    # An engine has no model: it stands for itself, so its matches are cross-model.
    model_of = {config_label(label): model or label for label, model in db.execute("SELECT DISTINCT s.label, e.model FROM match_seats s JOIN entrants e ON e.id = s.entrant_id")}
    tournament_games = scored_games(db)
    games = [replace(game, cohort=kind_of(model_of[game.first], model_of[game.second])) for game in tournament_games]
    by_cohort = cohorts(games)
    rng = random.Random(20261021)
    pooled_text, pair_tables = pooled_ratings(games, by_cohort, args.draws, rng)
    parts = [
        "### Schedule coverage\n", coverage(db, by_cohort),
        "\n### Pooled ratings\n", pooled_text,
        "\n### Observed pairs against the pooled ratings\n",
        "Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points. These are descriptive residuals of a regularized fit, not tests of a zero pair effect: the prior forces residuals (a pair at the end of a chain of pairs is pulled to its fit), so the bootstrap range is not a calibrated interval around zero. Pair effects are judged by the held-out test below. Every resample refits the pooled ratings.\n",
        *pair_tables.values(),
        "\n### Pair effects against ratings alone\n", matchup_test(by_cohort, rng, args.draws, args.repeats),
        "\n### Seat and round 1 starter\n", first_shooter_check(games), "", seat_section(by_cohort, model_of, args.draws, rng),
        "\n### Tournament 3\n", tournament3.report(tournament_games, args.draws, rng),
    ]
    text = "\n".join(parts) + "\n"
    if args.doc:
        splice_between_markers(Path(args.doc), "tables", text)
    else:
        print(text)


if __name__ == "__main__":
    main()
