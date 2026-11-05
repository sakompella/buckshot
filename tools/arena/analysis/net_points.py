#!/usr/bin/env python3
"""Net points against the minimax player: the rounds each seat gave up through its moves, and who gave up fewer.

A seat's points lost in a match is the sum of its regret over its searched decisions, in rounds (a regret is a loss in the chance of
winning the round, so 1,000,000 millionths is one round). The net points of a seat are the opponent's points lost minus its own.
Per config (a model with its effort) the tables give the mean of both per match, with a 95% bootstrap interval over seed blocks, and set
them beside the config's Round Elo: the Bradley-Terry rating on round shares over every scored match, as the viewer fits it.
A second table regresses the actual round margin of a match on its net points. The deeper-search section scales the stored depth 8 sample
(regret_depth.py) to this metric, and the last one prices rescoring with a deeper search from the stored runs' timings.
Matches with a DeepSeek seat are left out of the tables and rated with the rest, as the viewer does. With --doc FILE the tables replace the
text between the net-points markers of that file, and with --plots DIR two SVG plots are written.

    python3 tools/arena/analysis/net_points.py [--db PATH] [--regret PATH] [--knowledge PATH] [--depth 6] [--budget 20000] [--reload static] [--samples 256]
        [--deep PATH] [--sampled PATH] [--unbounded PATH] [--plots DIR] [--doc docs/arena/analysis/net-points.md]
"""

import argparse
import itertools
import math
import random
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

import bt
import by_round
import regret
import regret_depth
from fmt import pct, table
from load import DB, SKIPPED_MODEL, connect
from regret import DERIVED, EFFORTS, POINT
from reload_bias import Estimate

START, END = "<!-- net-points:start -->", "<!-- net-points:end -->"

ROUND = 1_000_000  # millionths of a round win
ROUNDS_PER_MATCH = len(by_round.ROUNDS)
MIN_MATCHES = 20
MIN_BLOCKS = 10
BOOTSTRAP = 2000
SEED = 20261102

Config = tuple[str, str]  # model, effort
Interval = tuple[float, float]


def label(config: Config) -> str:
    return f"{config[0]} {config[1]}"


@dataclass(frozen=True)
class Seat:
    config: Config
    lost: float  # rounds
    moves: int  # searched decisions
    rounds_won: int
    worst: int  # the largest single regret, in millionths
    worst_ordinal: int


@dataclass(frozen=True)
class Match:
    id: str
    name: str
    block: str  # the seed block: both seat orders of one seed
    first: Seat  # position 1
    second: Seat

    @property
    def net(self) -> float:
        """Net points of the first seat: how many rounds more the second seat gave up."""
        return self.second.lost - self.first.lost

    @property
    def margin(self) -> int:
        """Rounds the first seat won minus the second's."""
        return self.first.rounds_won - self.second.rounds_won

    @property
    def skipped(self) -> bool:
        return any(SKIPPED_MODEL in seat.config[0] for seat in (self.first, self.second))


@dataclass(frozen=True)
class Loaded:
    matches: list[Match]
    unreadable: int  # finished matches whose round winners could not be read
    incomplete: int  # finished matches with an agent decision that has no searched row: their totals would be too low, so they are left out
    mix: dict[Config, Counter[tuple[int, bool]]]  # per config, its decisions by shells left and shot-or-item, matches with a DeepSeek seat left out


def load(db_path: str, regret_path: Path, knowledge_path: Path, depth: int, budget: int, reload: str = "static", samples: int = 0) -> Loaded:
    """Every finished two-seat match whose agent decisions all have a searched row, with its seats' points lost under one run of the regret table, and the rounds each seat won."""
    knowledge = connect(str(knowledge_path))
    seats: dict[str, list[tuple[int, str, str, str]]] = defaultdict(list)
    for match, player, position, model, effort in knowledge.execute(
        "SELECT p.match_id, p.player, p.position, p.model, p.effort FROM players p JOIN matches m ON m.match_id = p.match_id AND m.status = 'completed'"
    ):
        seats[match].append((position, player, model, effort))
    blocks = {match: (block, name) for match, block, name in knowledge.execute("SELECT match_id, seed_block_id, name FROM matches")}
    db = connect(str(regret_path))
    db.execute("ATTACH DATABASE ? AS k", (f"file:{knowledge_path}?mode=ro",))
    rows = db.execute(
        """SELECT r.match_id, r.player, d.remaining, d.choice, r.regret, r.evaluator, r.ordinal
           FROM regret r
           JOIN k.matches m ON m.match_id = r.match_id AND m.status = 'completed'
           JOIN k.decisions d ON d.match_id = r.match_id AND d.ordinal = r.ordinal AND d.by_whom = 'agent'
           WHERE r.max_depth = ? AND r.budget = ? AND r.reload = ? AND r.samples = ? AND r.status = 'searched'""",
        (depth, budget, reload, samples),
    ).fetchall()
    if len({row[5] for row in rows}) > 1:
        raise SystemExit(f"{regret_path} holds rows of several evaluators at depth {depth}, budget {budget}, reload {reload} and samples {samples}; they must not be mixed.")
    lost: dict[tuple[str, str], list[int]] = defaultdict(lambda: [0, 0, 0, 0])  # summed regret, decisions, largest regret, its ordinal
    shape: dict[tuple[str, str], Counter[tuple[int, bool]]] = defaultdict(Counter)
    for match, player, remaining, choice, regret_millionths, _, ordinal in rows:
        seat = lost[match, player]
        seat[0] += regret_millionths
        seat[1] += 1
        if regret_millionths > seat[2]:
            seat[2], seat[3] = regret_millionths, ordinal
        shape[match, player][remaining, choice.startswith("Shoot")] += 1
    agent_decisions = Counter(
        {(match, player): n for match, player, n in knowledge.execute("SELECT match_id, player, COUNT(*) FROM decisions WHERE by_whom = 'agent' GROUP BY match_id, player")}
    )

    analysis = connect(db_path)
    cash: dict[str, dict[str, int]] = defaultdict(dict)
    for match, player, total in analysis.execute("SELECT match_id, player, cash FROM match_seats"):
        cash[match][player] = total
    lines = by_round.public_lines(analysis)
    matches, unreadable, incomplete = [], 0, 0
    mix: dict[Config, Counter[tuple[int, bool]]] = defaultdict(Counter)
    for match, found in seats.items():
        winners = by_round.round_winners(lines.get(match, []), cash[match])
        if winners is None:
            unreadable += 1
            continue
        if any(lost[match, player][1] != agent_decisions[match, player] for _, player, _, _ in found):
            incomplete += 1
            continue
        first, second = (
            Seat((model, effort), lost[match, player][0] / ROUND, lost[match, player][1], sum(w == player for w in winners.values()), *lost[match, player][2:])
            for _, player, model, effort in sorted(found)
        )
        matches.append(Match(match, blocks[match][1], blocks[match][0], first, second))
        if not matches[-1].skipped:
            for _, player, model, effort in found:
                mix[model, effort] += shape[match, player]
    return Loaded(matches, unreadable, incomplete, dict(mix))


# Statistics
# ==========


def percentile_interval(values: list[float]) -> Interval:
    ordered = sorted(values)
    return ordered[int(0.025 * len(ordered))], ordered[int(0.975 * len(ordered)) - 1]


def pearson(xs: list[float], ys: list[float]) -> float:
    mx, my = sum(xs) / len(xs), sum(ys) / len(ys)
    cov = sum((x - mx) * (y - my) for x, y in zip(xs, ys, strict=False))
    return cov / math.sqrt(sum((x - mx) ** 2 for x in xs) * sum((y - my) ** 2 for y in ys))


def ranks(values: list[float]) -> list[float]:
    """Ranks from 1, tied values sharing the mean of their ranks."""
    ordered = sorted(range(len(values)), key=values.__getitem__)
    out = [0.0] * len(values)
    i = 0
    while i < len(ordered):
        j = i
        while j + 1 < len(ordered) and values[ordered[j + 1]] == values[ordered[i]]:
            j += 1
        for k in range(i, j + 1):
            out[ordered[k]] = (i + j) / 2 + 1
        i = j + 1
    return out


def spearman(xs: list[float], ys: list[float]) -> float:
    return pearson(ranks(xs), ranks(ys))


@dataclass(frozen=True)
class Line:
    slope: float
    intercept: float
    r2: float


def ols(xs: list[float], ys: list[float]) -> Line:
    n, sx, sy = len(xs), sum(xs), sum(ys)
    sxx, sxy, syy = sum(x * x for x in xs), sum(x * y for x, y in zip(xs, ys, strict=False)), sum(y * y for y in ys)
    slope = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    return Line(slope, (sy - slope * sx) / n, (n * sxy - sx * sy) ** 2 / ((n * sxx - sx * sx) * (n * syy - sy * sy)))


def by_block(matches: list[Match]) -> dict[str, list[Match]]:
    out: dict[str, list[Match]] = defaultdict(list)
    for m in matches:
        out[m.block].append(m)
    return out


def elo_of(matches: list[Match]) -> dict[str, float]:
    """Round Elo per config label: Bradley-Terry on round shares, each match counting its rounds."""
    cells: dict[tuple[str, str], list[float]] = {}
    for m in matches:
        cell = cells.setdefault((label(m.first.config), label(m.second.config)), [0.0, 0.0])
        cell[0] += ROUNDS_PER_MATCH
        cell[1] += m.first.rounds_won
    return bt.fit(cells).elo()


# Per config
# ==========


@dataclass(frozen=True)
class ConfigRow:
    config: Config
    matches: int
    moves: float  # searched decisions per match
    lost: float  # rounds per match
    lost_interval: Interval
    net: float  # kept for the comparison with Round Elo; not a ranking, since it depends on the opponents met
    worst: float  # mean over matches of the seat's largest single regret, in points
    elo: float


def seat_views(matches: list[Match]):
    """(config, block, own points lost, net points, decisions, largest regret in points) for each seat of each match."""
    for m in matches:
        yield m.first.config, m.block, m.first.lost, m.net, m.first.moves, m.first.worst / POINT
        yield m.second.config, m.block, m.second.lost, -m.net, m.second.moves, m.second.worst / POINT


def config_rows(matches: list[Match], elo: dict[str, float], rng: random.Random) -> list[ConfigRow]:
    """Configs with at least MIN_MATCHES matches, the fewest points lost first. Matches with a DeepSeek seat are left out."""
    per_block: dict[Config, dict[str, list[float]]] = defaultdict(lambda: defaultdict(lambda: [0.0, 0.0, 0.0, 0.0, 0.0]))
    for config, block, lost, net, moves, worst in seat_views([m for m in matches if not m.skipped]):
        cell = per_block[config][block]
        cell[0] += lost
        cell[1] += net
        cell[2] += moves
        cell[3] += 1
        cell[4] += worst
    rows = []
    for config, blocks in per_block.items():
        cells = list(blocks.values())
        count = sum(c[3] for c in cells)
        if count < MIN_MATCHES:
            continue
        draws = [[cells[rng.randrange(len(cells))] for _ in cells] for _ in range(BOOTSTRAP)]
        totals = [(sum(c[0] for c in d), sum(c[3] for c in d)) for d in draws]
        rows.append(
            ConfigRow(
                config,
                int(count),
                sum(c[2] for c in cells) / count,
                sum(c[0] for c in cells) / count,
                percentile_interval([lost / n for lost, n in totals]),
                sum(c[1] for c in cells) / count,
                sum(c[4] for c in cells) / count,
                elo[label(config)],
            )
        )
    return sorted(rows, key=lambda r: r.lost)


def two(x: float) -> str:
    return f"{x:.2f}"


def span(interval: Interval) -> str:
    return f"{interval[0]:.2f} to {interval[1]:.2f}"


def config_table(rows: list[ConfigRow]) -> str:
    key = lambda r: (r.lost, EFFORTS.index(r.config[1]))
    body = [
        [r.config[0], r.config[1], str(r.matches), f"{two(r.lost)} ({span(r.lost_interval)})", two(r.lost / ROUNDS_PER_MATCH), f"{r.worst:.1f}", f"{r.elo:+.0f}"]
        for r in sorted(rows, key=key)
    ]
    return table(["model", "effort", "matches", "round-win equivalents lost per match", "per round", "largest gap (points)", "Round Elo"], body)


@dataclass(frozen=True)
class Correlation:
    pearson: float
    spearman: float
    interval: Interval  # of the Pearson one: seed blocks resampled, ratings refitted and configs reselected each time


def correlation(rows: list[ConfigRow], matches: list[Match], measure: str, rng: random.Random, reps: int = 300) -> Correlation:
    """Config means of a row's `measure` ("lost" or "net") against Round Elo. The interval resamples seed blocks of all matches, refits the ratings and recomputes the means."""
    column = {"lost": 2, "net": 3}[measure]
    point = pearson([getattr(r, measure) for r in rows], [r.elo for r in rows])
    blocks = list(by_block(matches).values())
    wanted = {r.config for r in rows}
    draws = []
    for _ in range(reps):
        sample = [m for _ in blocks for m in blocks[rng.randrange(len(blocks))]]
        elo = elo_of(sample)
        total: dict[Config, list[float]] = defaultdict(lambda: [0.0, 0.0])
        for view in seat_views([m for m in sample if not m.skipped]):
            if view[0] in wanted:
                total[view[0]][0] += view[column]
                total[view[0]][1] += 1
        kept = [c for c in wanted if total[c][1] and label(c) in elo]
        draws.append(pearson([total[c][0] / total[c][1] for c in kept], [elo[label(c)] for c in kept]))
    return Correlation(point, spearman([getattr(r, measure) for r in rows], [r.elo for r in rows]), percentile_interval(draws))


# Within a matchup
# ================


@dataclass(frozen=True)
class Matchup:
    a: Config
    b: Config
    blocks: int
    net: float  # of a, per match
    interval: Interval
    margin: float  # round margin of a, per match


def matchup_rows(matches: list[Match], rng: random.Random, minimum: int = MIN_BLOCKS) -> list[Matchup]:
    """Net points per match of the first-named config over each pairing's complete seed blocks (both seat orders played), the largest first.

    Pairings with fewer than `minimum` complete blocks are left out. A block's value is the mean of its two matches, so seat order cancels.
    """
    per_pair: dict[tuple[Config, Config], list[tuple[float, float]]] = defaultdict(list)
    for pair in by_block([m for m in matches if not m.skipped]).values():
        if len(pair) == 2 and pair[0].first.config == pair[1].second.config and pair[0].second.config == pair[1].first.config:
            a, b = sorted((pair[0].first.config, pair[0].second.config))
            per_pair[a, b].append((sum((1 if m.first.config == a else -1) * m.net for m in pair) / 2, sum((1 if m.first.config == a else -1) * m.margin for m in pair) / 2))
    rows = []
    for (a, b), values in per_pair.items():
        if len(values) >= minimum:
            nets = [net for net, _ in values]
            means = [sum(nets[rng.randrange(len(nets))] for _ in nets) / len(nets) for _ in range(BOOTSTRAP)]
            rows.append(Matchup(a, b, len(values), sum(nets) / len(nets), percentile_interval(means), sum(margin for _, margin in values) / len(values)))
    return sorted(rows, key=lambda r: -abs(r.net))


def matchup_table(rows: list[Matchup], count: int = 10) -> str:
    return table(
        ["config", "against", "complete seed blocks", "net points per match (positive: the first gave up less)", "round margin per match"],
        [[label(r.a), label(r.b), str(r.blocks), f"{r.net:+.2f} ({span(r.interval)})", f"{r.margin:+.2f}"] for r in rows[:count]],
    )


MISS_LEVELS = (10, 25, 50, 100)


def worst_table(matches: list[Match]) -> str:
    """How large each seat's largest single regret in a match is, over all seats of all matches. 100 points is a certain win given up."""
    seats = [s.worst / POINT for m in matches for s in (m.first, m.second)]
    return table(["largest gap in a match, at least (points)", "share of seats"], [[str(level), pct(sum(w >= level for w in seats) / len(seats))] for level in MISS_LEVELS])


# Match margin
# ============


@dataclass(frozen=True)
class Margin:
    line: Line
    slope_interval: Interval
    matches: int
    bins: list[tuple[float, float, int]]  # mean net points, mean round margin, matches


BIN_EDGES = [-math.inf, -1.0, -0.5, -0.2, 0.2, 0.5, 1.0, math.inf]


def margin_fit(matches: list[Match], rng: random.Random) -> Margin:
    """The first seat's round margin on its net points, over the matches with no DeepSeek seat."""
    kept = [m for m in matches if not m.skipped]
    xs, ys = [m.net for m in kept], [float(m.margin) for m in kept]
    blocks = list(by_block(kept).values())
    slopes = []
    for _ in range(BOOTSTRAP):
        sample = [m for _ in blocks for m in blocks[rng.randrange(len(blocks))]]
        slopes.append(ols([m.net for m in sample], [float(m.margin) for m in sample]).slope)
    bins = []
    for low, high in itertools.pairwise(BIN_EDGES):
        inside = [m for m in kept if low <= m.net < high]
        bins.append((sum(m.net for m in inside) / len(inside), sum(m.margin for m in inside) / len(inside), len(inside)))
    return Margin(ols(xs, ys), percentile_interval(slopes), len(kept), bins)


def bin_name(low: float, high: float) -> str:
    return f"below {high:g}" if low == -math.inf else f"{low:g} and above" if high == math.inf else f"{low:g} to {high:g}"


def margin_table(margin: Margin) -> str:
    rows = [[bin_name(low, high), f"{n:,}", f"{mean_net:+.2f}", f"{mean_margin:+.2f}"] for (low, high), (mean_net, mean_margin, n) in zip(itertools.pairwise(BIN_EDGES), margin.bins, strict=False)]
    return table(["net points of the first seat", "matches", "mean net points", "mean round margin"], rows)


# Plots
# =====

PALETTE = ["#1b9e77", "#d95f02", "#7570b3", "#e7298a", "#66a61e", "#e6ab02", "#a6761d", "#666666", "#1f78b4"]


def scatter_svg(points: list[tuple[float, float, str, str]], x_label: str, y_label: str, title: str, line: Line | None, legend: dict[str, str] | None = None) -> str:
    """A dependency-free scatter plot: (x, y, text, colour) points, an optional fitted line and a legend of colours."""
    width, height, left, right, top, bottom = 760, 520, 70, 150, 40, 55
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    pad = lambda lo, hi: (lo - 0.06 * (hi - lo), hi + 0.06 * (hi - lo))
    (x0, x1), (y0, y1) = pad(min(xs), max(xs)), pad(min(ys), max(ys))
    px = lambda x: left + (x - x0) / (x1 - x0) * (width - left - right)
    py = lambda y: height - bottom - (y - y0) / (y1 - y0) * (height - top - bottom)
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" font-family="sans-serif" font-size="11">',
        f'<rect width="{width}" height="{height}" fill="white"/>',
        f'<text x="{left}" y="22" font-size="14" font-weight="bold">{title}</text>',
        f'<rect x="{left}" y="{top}" width="{width - left - right}" height="{height - top - bottom}" fill="none" stroke="#999"/>',
        f'<text x="{(left + width - right) / 2}" y="{height - 14}" text-anchor="middle">{x_label}</text>',
        f'<text transform="translate(18 {(top + height - bottom) / 2}) rotate(-90)" text-anchor="middle">{y_label}</text>',
    ]
    for tick in [x0 + (x1 - x0) * i / 6 for i in range(7)]:
        out.append(f'<text x="{px(tick)}" y="{height - bottom + 14}" text-anchor="middle" fill="#555">{tick:.0f}</text>' if x1 - x0 > 20 else f'<text x="{px(tick)}" y="{height - bottom + 14}" text-anchor="middle" fill="#555">{tick:.1f}</text>')
    for tick in [y0 + (y1 - y0) * i / 5 for i in range(6)]:
        out.append(f'<line x1="{left}" x2="{width - right}" y1="{py(tick)}" y2="{py(tick)}" stroke="#eee"/><text x="{left - 6}" y="{py(tick) + 4}" text-anchor="end" fill="#555">{tick:.2f}</text>')
    if line:
        out.append(f'<line x1="{px(x0)}" y1="{py(line.slope * x0 + line.intercept)}" x2="{px(x1)}" y2="{py(line.slope * x1 + line.intercept)}" stroke="#444" stroke-dasharray="5 4"/>')
    for x, y, text, colour in points:
        out.append(f'<circle cx="{px(x)}" cy="{py(y)}" r="4" fill="{colour}" fill-opacity="0.85"/><text x="{px(x) + 6}" y="{py(y) - 5}" font-size="9" fill="#333">{text}</text>')
    for i, (name, colour) in enumerate((legend or {}).items()):
        out.append(f'<circle cx="{width - right + 16}" cy="{top + 12 + 18 * i}" r="5" fill="{colour}"/><text x="{width - right + 26}" y="{top + 16 + 18 * i}">{name}</text>')
    return "\n".join(out + ["</svg>"]) + "\n"


SHORT = {
    "claude-opus-5-5": "Opus", "gpt-6-astra": "Astra", "gpt-6.1-sol": "Sol", "claude-sonnet-5-5": "Sonnet", "gpt-6.1-terra": "Terra 6.1",
    "claude-haiku-5-5": "Haiku 5.5", "gpt-5.6-terra": "Terra", "gpt-6-luna": "Luna", "claude-haiku-4-5-20251001": "Haiku 4.5",
}  # fmt: skip


def elo_plot(rows: list[ConfigRow]) -> str:
    models = sorted({r.config[0] for r in rows})
    colour = {m: PALETTE[i % len(PALETTE)] for i, m in enumerate(models)}
    points = [(r.elo, r.lost, r.config[1], colour[r.config[0]]) for r in rows]
    line = ols([p[0] for p in points], [p[1] for p in points])
    return scatter_svg(points, "Round Elo", "round-win equivalents lost per match", "Round-win equivalents lost per match against Round Elo, one point per config", line, {SHORT.get(m, m): colour[m] for m in models})


def margin_plot(margin: Margin) -> str:
    points = [(x, y, f"{n:,}", PALETTE[0]) for x, y, n in margin.bins]
    return scatter_svg(points, "net points of the first seat (rounds)", "mean round margin of the first seat", "Round margin against net points, binned (labels: matches)", margin.line)


# Deeper search
# =============


@dataclass(frozen=True)
class Shift:
    config: Config
    points_per_decision: Estimate  # deep regret minus production regret, in points
    rounds_per_match: float
    rounds_interval: float  # half width of the 95% interval


def depth_shifts(pairs: list[regret_depth.Pair], rows: list[ConfigRow], mix: dict[Config, Counter[tuple[int, bool]]]) -> list[Shift]:
    """Each config's change in points lost per match under a depth 8 search with ten times the budget.

    The sample's change in regret per decision of the config's model is weighted by the config's own mix of shells left and shot-or-item.
    Configs of a model that the sample does not cover (tournament 5's Terra 6.1) are left out.
    """
    models = {p.model for p in pairs}
    shifts = []
    for r in rows:
        model, _ = r.config
        if model not in models:
            continue
        sizes = {(shells, shot, model): n for (shells, shot), n in mix[r.config].items()}
        est = regret_depth.estimate([p for p in pairs if p.model == model], lambda p: p.deep_regret - p.regret, sizes)
        scale = r.moves / 100  # points per decision to rounds per match
        shifts.append(Shift(r.config, est, est.mean * scale, est.half_width * scale))
    return shifts


def shift_table(shifts: list[Shift], rows: list[ConfigRow]) -> str:
    """Models, each with the matches-weighted mean of its configs' points lost per match at depth 6 and at depth 8."""
    lost = {r.config: r for r in rows}
    out = []
    for model in sorted({s.config[0] for s in shifts}, key=lambda m: sum(lost[s.config].lost * lost[s.config].matches for s in shifts if s.config[0] == m)):
        mine = [s for s in shifts if s.config[0] == model]
        matches = sum(lost[s.config].matches for s in mine)
        at6 = sum(lost[s.config].lost * lost[s.config].matches for s in mine) / matches
        delta = sum(s.rounds_per_match * lost[s.config].matches for s in mine) / matches
        half = sum(s.rounds_interval * lost[s.config].matches for s in mine) / matches
        out.append([model, f"{matches:,}", two(at6), two(at6 + delta), f"{delta:+.2f} ± {half:.2f}"])
    return table(["model", "seat matches", "points lost per match at depth 6", "at depth 8", "change"], out)


def depth_correlation(shifts: list[Shift], rows: list[ConfigRow]) -> tuple[float, float, float, float, int]:
    """Pearson and Spearman against Round Elo of points lost per match, at depth 6 and with each shift added, over the configs that have one; the shifted ordering's Spearman against the old."""
    lost = {r.config: r for r in rows}
    cfgs = [s.config for s in shifts]
    old = [lost[c].lost for c in cfgs]
    new = [lost[c].lost + s.rounds_per_match for c, s in zip(cfgs, shifts, strict=False)]
    elo = [lost[c].elo for c in cfgs]
    return pearson(old, elo), pearson(new, elo), spearman(old, new), max(abs(s.rounds_per_match) for s in shifts), len(cfgs)


# Cost of a deeper rescoring
# ==========================


def cell_ms(path: Path, depth: int, budget: int, reload: str, samples: int, knowledge_path: Path) -> dict[tuple[int, bool], tuple[float, int]]:
    """Mean milliseconds per searched decision of a run, and its decisions, by shells left and shot-or-item."""
    db = connect(str(path))
    db.execute("ATTACH DATABASE ? AS k", (f"file:{knowledge_path}?mode=ro",))
    rows = db.execute(
        """SELECT d.remaining, d.choice LIKE 'Shoot%', AVG(r.ms), COUNT(*) FROM regret r
           JOIN k.decisions d ON d.match_id = r.match_id AND d.ordinal = r.ordinal AND d.by_whom = 'agent'
           WHERE r.max_depth = ? AND r.budget = ? AND r.reload = ? AND r.samples = ? AND r.status = 'searched' GROUP BY 1, 2""",
        (depth, budget, reload, samples),
    )
    return {(shells, bool(shot)): (ms, n) for shells, shot, ms, n in rows}


def hours(per_cell: dict[tuple[int, bool], float], population: Counter[tuple[int, bool]], only: range = range(1, 7)) -> float:
    return sum(per_cell[cell] * n for cell, n in population.items() if cell[0] in only) / 3_600_000


def cost_table(mix: dict[Config, Counter[tuple[int, bool]]], regret_path: Path, deep_path: Path, sampled_path: Path, unbounded: dict[tuple[int, bool], float], knowledge_path: Path) -> str:
    """CPU hours, in one process, to score every decision of the run under each setting: the stored runs' mean time per cell times the cell's size in the whole run."""
    population = sum(mix.values(), Counter())
    production = {c: ms for c, (ms, _) in cell_ms(regret_path, 6, 20000, "static", 0, knowledge_path).items()}
    deep = {c: ms for c, (ms, _) in cell_ms(deep_path, 8, 200_000, "static", 0, knowledge_path).items()}
    sampled = {c: ms for c, (ms, _) in cell_ms(sampled_path, 6, 20000, "sampled", 64, knowledge_path).items()}
    few, many = range(1, 4), range(4, 7)
    settings = [
        ("production: depth 6, 20,000 nodes, static leaf", hours(production, population)),
        ("depth 8, 200,000 nodes everywhere", hours(deep, population)),
        ("depth 8, 200,000 nodes with 4 or more shells left, production below", hours(production, population, few) + hours(deep, population, many)),
        ("to the reload (depth 16, 2,000,000 nodes) with 3 or fewer shells left, production above", hours(unbounded, population, few) + hours(production, population, many)),
        ("as above, and depth 8, 200,000 nodes with 4 or more", hours(unbounded, population, few) + hours(deep, population, many)),
        ("sampled leaf, 64 deals, depth 6 with 3 or fewer shells left, production above", hours(sampled, population, few) + hours(production, population, many)),
    ]
    return table(["setting", "CPU hours", "on 8 processes"], [[name, f"{h:,.0f}", f"{h / 8:,.0f}"] for name, h in settings])


def unbounded_cells(path: Path, knowledge_path: Path, depth: int, budget: int) -> dict[tuple[int, bool], float]:
    return {c: ms for c, (ms, _) in cell_ms(path, depth, budget, "static", 0, knowledge_path).items()}


# Report
# ======


def report(loaded: Loaded, rows: list[ConfigRow], elo_lost: Correlation, elo_net: Correlation, matchups: list[Matchup], margin: Margin, depth_text: str) -> str:
    kept = [m for m in loaded.matches if not m.skipped]
    ranked = len({label(c) for m in loaded.matches for c in (m.first.config, m.second.config)})
    return (
        f"{len(kept):,} finished matches with no DeepSeek seat ({len(loaded.matches):,} with it, used for the ratings, which cover {ranked} configs). Left out: {loaded.unreadable:,} matches whose round winners did not match the final cash and {loaded.incomplete:,} with an agent decision that has no searched row. "
        f"{len(rows)} configs have at least {MIN_MATCHES} matches. Intervals are 95%, {BOOTSTRAP:,} resamples of seed blocks.\n\n"
        f"### Round-win equivalents lost, by config\n\n{config_table(rows)}\n\n"
        f"### Against Round Elo\n\n"
        + table(
            ["measure per config", "Pearson", "95% interval", "Spearman"],
            [["own points lost per match", f"{elo_lost.pearson:+.2f}", span(elo_lost.interval), f"{elo_lost.spearman:+.2f}"], ["net points per match", f"{elo_net.pearson:+.2f}", span(elo_net.interval), f"{elo_net.spearman:+.2f}"]],
        )
        + f"\n\n### Net points within a matchup\n\n{len(matchups)} pairings have at least {MIN_BLOCKS} complete seed blocks. Across them, net points and round margin per match correlate at {pearson([r.net for r in matchups], [r.margin for r in matchups]):+.2f}. The ten largest nets:\n\n{matchup_table(matchups)}\n\n"
        f"### Largest gap per match\n\n{worst_table(kept)}\n\n"
        f"### Round margin on net points, per match\n\n"
        f"{margin.matches:,} matches. Round margin of the first seat = {margin.line.intercept:+.3f} + {margin.line.slope:.2f} × its net points; R² {margin.line.r2:.3f}, slope interval {span(margin.slope_interval)}.\n\n{margin_table(margin)}\n\n"
        + depth_text
    )


def depth_report(shifts: list[Shift], rows: list[ConfigRow], mix, args) -> str:
    old, new, order, biggest, n = depth_correlation(shifts, rows)
    text = (
        f"### Under a deeper search\n\nThe stored depth 8 sample, scaled to {n} configs: Pearson against Round Elo {old:+.3f} at depth 6 and {new:+.3f} with the shifts; Spearman between the two orderings {order:+.3f}; the largest change in one config's points lost per match is {biggest:+.2f}.\n\n"
        f"{shift_table(shifts, rows)}\n"
    )
    if args.sampled and args.unbounded:
        unbounded = unbounded_cells(args.unbounded, args.knowledge, args.unbounded_depth, args.unbounded_budget)
        text += f"\n### Cost of rescoring {sum(sum(c.values()) for c in mix.values()):,} decisions\n\n{cost_table(mix, args.regret, args.deep, args.sampled, unbounded, args.knowledge)}\n"
    return text


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--db", default=DB)
    parser.add_argument("--regret", type=Path, default=DERIVED / "regret.sqlite")
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--depth", type=int, default=6)
    parser.add_argument("--budget", type=int, default=20000)
    parser.add_argument("--reload", choices=["static", "expected-deal", "sampled"], default="static")
    parser.add_argument("--samples", type=int, help="deals per leaf of a sampled run, 256 by default")
    parser.add_argument("--deep", type=Path, default=DERIVED / "regret-depth.sqlite")
    parser.add_argument("--sampled", type=Path, help="the reload-bias run, for the cost table")
    parser.add_argument("--unbounded", type=Path, help="a timed run to the reload of decisions with 3 or fewer shells left, for the cost table")
    parser.add_argument("--unbounded-depth", type=int, default=16)
    parser.add_argument("--unbounded-budget", type=int, default=2_000_000)
    parser.add_argument("--plots", type=Path)
    parser.add_argument("--doc", type=Path)
    args = parser.parse_args()
    loaded = load(args.db, args.regret, args.knowledge, args.depth, args.budget, args.reload, regret.run_samples(args.reload, args.samples))
    rng = random.Random(SEED)
    elo = elo_of(loaded.matches)
    rows = config_rows(loaded.matches, elo, rng)
    elo_lost, elo_net = correlation(rows, loaded.matches, "lost", rng), correlation(rows, loaded.matches, "net", rng)
    matchups = matchup_rows(loaded.matches, rng)
    margin = margin_fit(loaded.matches, rng)
    pairs = regret_depth.pairs(args.deep, args.regret, args.knowledge)
    text = report(loaded, rows, elo_lost, elo_net, matchups, margin, depth_report(depth_shifts(pairs, rows, loaded.mix), rows, loaded.mix, args))
    if args.plots:
        args.plots.mkdir(parents=True, exist_ok=True)
        (args.plots / "points-lost-vs-elo.svg").write_text(elo_plot(rows))
        (args.plots / "margin-vs-net-points.svg").write_text(margin_plot(margin))
    if args.doc is None:
        print(text)
    else:
        head, rest = args.doc.read_text().split(START)
        tail = rest.split(END)[1]
        args.doc.write_text(f"{head}{START}\n{text}{END}{tail}")


if __name__ == "__main__":
    main()
