#!/usr/bin/env python3
"""Matchup analysis of the scored arena matches: ratings per cohort, pair effects, seat and starter effects.

Reads the analysis database read-only and prints markdown tables. With --doc FILE the tables replace the text
between the tables markers of that file. Cohorts (see load.cohort_of) are never pooled into one ranking. Intervals
are 95% bootstraps over seed blocks, drawn with a fixed RNG seed so a rerun prints the same numbers.

    python3 tools/arena/analysis/matchups.py [--db PATH] [--draws 2000] [--doc docs/arena/analysis/matchups.md]
"""

import argparse
import math
import random
import statistics

import boot
import bt
import cv
import seats
import tournament3
from fmt import frac, pct, pp, signed, span, table
from load import Game, blocks_of, cohort_of, cohorts, connect, scored_games

START, END = "<!-- tables:start -->", "<!-- tables:end -->"


# ---- coverage

def coverage(db, by_cohort: dict[str, list[Game]]) -> str:
    scheduled: dict[str, dict[str, int]] = {}
    for status, disposition, *seat in db.execute(
        """SELECT m.status, m.disposition, t.name, a.model, b.model, a.effort, b.effort
           FROM matches m JOIN tournaments t ON t.id = m.tournament_id
           JOIN match_seats sa ON sa.match_id = m.id AND sa.position = 1 JOIN entrants a ON a.id = sa.entrant_id
           JOIN match_seats sb ON sb.match_id = m.id AND sb.position = 2 JOIN entrants b ON b.id = sb.entrant_id"""
    ):
        tournament, model_a, model_b, effort_a, effort_b = seat
        try:
            cohort = cohort_of(tournament, model_a, model_b, effort_a, effort_b)
        except ValueError:
            cohort = "(outside every cohort)"
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
        codes = {}
        for g in games:
            codes[g.code] = codes.get(g.code, 0) + 1
        parts = bt.components(games)
        rows.append(
            [
                name,
                str(len(entrants)),
                str(len(games)),
                f"{sizes.count(2)} / {sizes.count(1)}",
                f"{len(per_pair)}/{len(entrants) * (len(entrants) - 1) // 2}",
                f"{counts[0]} / {statistics.median(counts):g} / {counts[-1]}",
                ", ".join(f"`{c}` {n}" for c, n in sorted(codes.items())),
                "yes" if len(parts) == 1 else f"no, {len(parts)} groups",
                ", ".join(f"{n} {s}" for s, n in sorted(scheduled.get(name, {}).items())),
            ]
        )
    header = ["cohort", "entrants", "scored matches", "complete / half blocks", "pairs played", "matches per pair min / median / max", "matches by code hash", "connected", "scheduled by status"]
    return table(header, rows) + f"\n\nMatches outside every cohort: {sum(scheduled.get('(outside every cohort)', {}).values())}."


# ---- ratings and observed pairs

def summarize(cells: bt.Cells, names: set[str]):
    """Elo ratings, and for each pair the games, the first-named entrant's observed wins and its fitted wins."""
    fitted = bt.fit(cells, entrants=names)
    pairs = {}
    for low, high in sorted({bt.pair_of(*key) for key in cells}):
        forward = cells.get((low, high), [0.0, 0.0])
        backward = cells.get((high, low), [0.0, 0.0])
        n = forward[0] + backward[0]
        pairs[(low, high)] = (n, forward[1] + backward[0] - backward[1], n * bt.sigmoid(fitted.theta[low] - fitted.theta[high]))
    return fitted.elo(), pairs


def ratings_and_pairs(name: str, games: list[Game], draws: int, rng: random.Random) -> str:
    names = {n for g in games for n in (g.first, g.second)}
    elo, pairs = summarize(bt.cells_of(games), names)
    ids = sorted(blocks_of(games))
    rating_draws: dict[str, list[float]] = {}
    effect_draws: dict[tuple[str, str], list[float]] = {}
    for _ in range(draws):
        sample_elo, sample_pairs = summarize(bt.cells_of(games, boot.weights(ids, rng)), names)
        for entrant, value in sample_elo.items():
            rating_draws.setdefault(entrant, []).append(value)
        for pair, (n, won, expected) in sample_pairs.items():
            effect_draws.setdefault(pair, []).append((won - expected) / n)
    seeds = sorted({g.seed for g in games})
    seed_draws: dict[str, list[float]] = {}
    for _ in range(draws):
        sample = bt.fit(bt.cells_of(games, boot.weights(seeds, rng), unit=lambda g: g.seed), entrants=names).elo()
        for entrant, value in sample.items():
            seed_draws.setdefault(entrant, []).append(value)
    totals: dict[str, list[float]] = {}
    for g in games:
        for entrant, share in ((g.first, g.share_first), (g.second, 1 - g.share_first)):
            row = totals.setdefault(entrant, [0.0, 0.0])
            row[0] += 1
            row[1] += share
    rows = [
        [e, frac(totals[e][1], totals[e][0]), f"{elo[e]:+.0f}", span(boot.interval(rating_draws[e]), signed), span(boot.interval(seed_draws[e]), signed)]
        for e in sorted(elo, key=lambda e: -elo[e])
    ]
    out = [f"#### {name}: ratings\n", table(["entrant", "wins/matches = win share", "rating (Elo, mean 0)", "95% CI, seed blocks drawn", "95% CI, seeds drawn (sensitivity)"], rows)]
    out.append(sensitivity(games, names, elo))
    pair_rows = []
    for (low, high), (n, won, expected) in pairs.items():
        pair_rows.append(
            [f"{low} vs {high}", frac(won, n), pct(expected / n), pp((won - expected) / n), span(boot.interval(effect_draws[(low, high)]), pp)]
        )
    out.append(f"\n#### {name}: observed pairs against the fitted ratings\n")
    out.append("Win share is the first-named entrant's. Difference is observed minus fitted, in percentage points.\n")
    out.append(table(["pair", "wins/matches = observed share", "fitted share", "difference (pp)", "95% CI"], pair_rows))
    return "\n".join(out)


def sensitivity(games: list[Game], names: set[str], elo: dict[str, float]) -> str:
    """How far the ratings move with a seat term, and with only the cohort's main code hash."""
    lines = []
    extra = bt.fit(bt.cells_of(games, starter=True), seat=True, start=True, entrants=names)
    moved = max(abs(extra.elo()[e] - elo[e]) for e in elo)
    lines.append(f"With a seat term and a round 1 starter term in the fit (position 1 {extra.seat * bt.ELO:+.0f} Elo, the starter {extra.start * bt.ELO:+.0f} Elo) the largest rating change is {moved:.1f} Elo.")
    codes = {}
    for g in games:
        codes[g.code] = codes.get(g.code, 0) + 1
    if len(codes) > 1:
        main = max(codes, key=codes.get)
        kept = [g for g in games if g.code == main]
        left = sorted(names - {n for g in kept for n in (g.first, g.second)})
        if len(bt.components(kept)) != 1:
            lines.append(f"The {len(kept)} matches under code `{main}` alone do not connect the cohort, so there is no code-stratified refit.")
        else:
            only = bt.fit(bt.cells_of(kept)).elo()
            shared = [e for e in only]
            full = {e: elo[e] - sum(elo[s] for s in shared) / len(shared) for e in shared}
            lines.append(f"Fitting only the {len(kept)} matches under code `{main}` (leaving out {len(games) - len(kept)} matches{' and the entrant ' + ', '.join(left) if left else ''}) moves no remaining rating by more than {max(abs(only[e] - full[e]) for e in shared):.1f} Elo.")
    return "\n" + " ".join(lines) + "\n"


# ---- pair effects against ratings alone

def sign_test(agree: int, total: int) -> float:
    """Two-sided exact p of this many agreements or fewer/more out of total at probability 1/2."""
    tail = sum(math.comb(total, k) for k in range(max(agree, total - agree), total + 1)) / 2**total
    return min(1.0, 2 * tail)


def reverse_pairs(games: list[Game]) -> tuple[int, int, list[float], list[float]]:
    """For each pair, the first-seated entrant's observed minus fitted share when A sat first, and when B sat first.

    A real matchup effect that favours A shows as positive for A first and negative for B first, so the reverse
    ordered pairs should have opposite signs. The fit has a seat term and a round 1 starter term, so neither edge
    fakes it. Under no matchup effect the two signs are independent and half the pairs are opposite.
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
    return [name, f"{opposite}/{both} = {pct(opposite / both)}", f"{sign_test(opposite, both):.2f}", f"{correlation:+.2f}"]


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
        "\nReverse pairs: opposite signs for the entrant seated first, observed minus fitted with seat and round 1 starter terms, when A sat first and when B sat first.\n",
        table(
            ["cohort", "pairs with opposite signs", "sign-test p", "correlation of A-first effect with minus B-first effect"],
            [reverse_row(*row) for row in reverse_rows]
            + [reverse_row("all cohorts pooled", sum(r[1] for r in reverse_rows), sum(r[2] for r in reverse_rows), [x for r in reverse_rows for x in r[3]], [y for r in reverse_rows for y in r[4]])],
        ),
    ]
    worst = max(antisymmetry(games) for games in by_cohort.values())
    out.append(f"\nPair-level effects (all matches of a pair, either order) are exactly opposite for the two entrants: the largest sum of the two entrants' effects over every pair of every cohort is {worst:.1e}, because each match's shares sum to 1.")
    out.append(f"\nCohorts that keep pair effects: {', '.join(kept) if kept else 'none'}.")
    return "\n".join(out)


# ---- seats and starters

def seat_rows(groups: list[tuple[str, list[seats.Block]]], draws: int, rng: random.Random, extra: dict[str, int]) -> str:
    position, starter, effects = [], [], []
    for name, blocks in groups:
        if not blocks:
            continue
        point = seats.estimates(blocks)
        by_block, by_seed = seats.bootstrap(blocks, draws, rng), seats.bootstrap(blocks, draws, rng, by_seed=True)
        matches = 2 * len(blocks)
        left = f" ({extra[name]} matches in half blocks left out)" if extra.get(name) else ""
        label = f"{name}: {len(blocks)} blocks{left}"
        position.append([label, frac(sum(b.first_wins for b in blocks), matches), span(by_block["first"]), span(by_seed["first"])])
        starter.append([name, frac(sum(b.starter_wins for b in blocks), matches), span(by_block["starter"]), span(by_seed["starter"]), f"{sum(b.starter == 1 for b in blocks)}/{len(blocks)}"])
        if "seat" in point:
            effects.append([name, f"{pp(point['seat'])}", span(by_block.get("seat"), pp), span(by_seed.get("seat"), pp), f"{pp(point['start'])}", span(by_block.get("start"), pp), span(by_seed.get("start"), pp)])
    return "\n\n".join(
        [
            "Position 1:\n\n" + table(["group", "position 1 wins/matches = share", "95% CI, seed blocks drawn", "95% CI, seeds drawn (sensitivity)"], position),
            "Round 1 starter:\n\n" + table(["group", "starter wins/matches = share", "95% CI, seed blocks drawn", "95% CI, seeds drawn (sensitivity)", "blocks where position 1 starts"], starter),
            "Position and starter effects with the other held equal, in percentage points:\n\n"
            + table(["group", "position effect", "95% CI, blocks", "95% CI, seeds (sensitivity)", "starter effect", "95% CI, blocks", "95% CI, seeds (sensitivity)"], effects),
        ]
    )


def by_seed_table(blocks: list[seats.Block]) -> str:
    """Per seed, across every cohort: the starter position and how often the starter won."""
    rows = []
    for seed in sorted({b.seed for b in blocks}):
        here = [b for b in blocks if b.seed == seed]
        rows.append([str(seed), str(here[0].starter), str(len(here)), frac(sum(b.starter_wins for b in here), 2 * len(here))])
    big = {s for s in {b.seed for b in blocks} if sum(b.seed == s for b in blocks) >= 10}
    shares = {s: sum(b.starter_wins for b in blocks if b.seed == s) / (2 * sum(b.seed == s for b in blocks)) for s in big}
    seeds, rng = sorted(shares), random.Random(7)
    means = sorted(sum(shares[rng.choice(seeds)] for _ in seeds) / len(seeds) for _ in range(2000))
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
            "A block counts for every model that plays in it; a matched block gives one position-1 share for both sides, so this says how large the position edge is in games that involve the model, not which side of the board benefits.\n",
            seat_rows(per_model, draws, rng, {}),
            "\n#### Per code hash, all cohorts\n",
            seat_rows([(f"code `{code}`", [b for b in everything if b.code == code]) for code in sorted({b.code for b in everything}) if sum(b.code == code for b in everything) >= 10], draws, rng, {}),
            "Codes with fewer than 10 complete blocks (`3c9b98f8b3f4` has 1, and 1 block mixes two codes) are left out.",
            "\n#### Per seed, all cohorts\n",
            "Cohorts reuse seeds 3000 to 3018 (tournament 3 adds 3020 to 3029), so a seed's starter result pools many pairings.\n",
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
    parser.add_argument("--draws", type=int, default=2000)
    parser.add_argument("--repeats", type=int, default=5, help="repeats of the 10-fold cross-validation")
    parser.add_argument("--doc")
    args = parser.parse_args()
    db = connect(args.db) if args.db else connect()
    games = scored_games(db)
    by_cohort = cohorts(games)
    model_of = dict(db.execute("SELECT DISTINCT name, model FROM entrants"))
    rng = random.Random(20261021)
    parts = [
        "### Schedule coverage\n", coverage(db, by_cohort),
        "\n### Ratings and observed pairs\n",
        *[ratings_and_pairs(name, g, args.draws, rng) for name, g in by_cohort.items() if name != "tournament 3"],
        "\n### Pair effects against ratings alone\n", matchup_test({k: v for k, v in by_cohort.items() if k != "tournament 3"}, rng, args.draws, args.repeats),
        "\n### Seat and round 1 starter\n", first_shooter_check(games), "", seat_section(by_cohort, model_of, args.draws, rng),
        "\n### Tournament 3\n", tournament3.report(games, args.draws, rng),
    ]
    text = "\n".join(parts) + "\n"
    if args.doc:
        doc = open(args.doc).read()
        head, rest = doc.split(START)
        _, tail = rest.split(END)
        open(args.doc, "w").write(f"{head}{START}\n{text}{END}{tail}")
    else:
        print(text)


if __name__ == "__main__":
    main()
