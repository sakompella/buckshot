#!/usr/bin/env python3
"""Within-match change from round 1 to rounds 2 and 3, per model and config.

Each seat of each finished match is its own control: its round 2 and round 3 values minus its round 1 value, for mean regret,
round win and the rate of shooting itself on a proven live shell. The deltas are averaged per model and per config, with a 95% interval
from resampling seed blocks (boot.py). Regret is first made comparable across rounds: each move's regret minus the mean regret of
all moves of the same model, kind (shot or item move) and shells left, so a round with more long chambers or more item moves does not
look better or worse for that alone. A seat counts for a delta only if it moved (or played) in both rounds.

Reads the analysis database for round winners, and the regret, knowledge and certain-mistakes databases, all read only. Matches with a
DeepSeek seat and unfinished matches are left out. With --doc FILE the tables replace the text between the round-improvement markers of
that file, and with --svg DIR the figures are written there.

    python3 tools/arena/analysis/round_improvement.py [--db PATH] [--regret PATH] [--knowledge PATH] [--mistakes PATH] [--doc docs/arena/analysis/regret.md] [--svg DIR]
"""

import argparse
import math
import random
import sqlite3
from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass, replace
from pathlib import Path
from statistics import fmean, stdev

import by_round
from docs import splice_between_markers
from boot import interval
from fmt import table
from load import DB, SKIPPED_MODEL, connect, require_current
from regret import DERIVED, EFFORTS, POINT

RESAMPLES = 2000
ROUNDS = (1, 2, 3)
FEWEST_SEATS = 80  # seats with a regret in both rounds below which a config is shown but not tested
FEWEST_BLOCKS = 10
FALSE_DISCOVERY = 0.05


@dataclass(frozen=True)
class Seat:
    match: str
    player: str
    model: str
    effort: str
    block: str
    level: bool  # the match stands at one round each before round 3
    wins: frozenset[int]  # the rounds this seat won

    @property
    def config(self) -> str:
        return f"{self.model} {self.effort}"


@dataclass(frozen=True)
class Move:
    seat: Seat
    round: int
    shot: bool
    shells_left: int
    regret: int
    mistake: bool | None  # None unless the move is an opportunity to shoot itself on a proven live
    excess: float = 0.0  # regret minus the mean regret of the move's model, kind and shells left


@dataclass(frozen=True)
class Estimate:
    n: int
    mean: float
    low: float
    high: float
    p: float  # two-sided, from a normal curve on the resamples' spread


def load_moves(regret_path: Path, knowledge_path: Path, mistakes_path: Path, db_path: str, depth: int = 6, budget: int = 20000) -> list[Move]:
    db = connect(str(regret_path))
    db.execute("ATTACH DATABASE ? AS k", (f"file:{knowledge_path}?mode=ro",))
    db.execute("ATTACH DATABASE ? AS c", (f"file:{mistakes_path}?mode=ro",))
    rows = db.execute(
        """SELECT r.match_id, r.ordinal, d.player, p.model, p.effort, m.seed_block_id, d.round + 1, d.remaining, d.choice, r.regret, r.evaluator,
                  o.outcome = 'mistake'
           FROM regret r
           JOIN k.matches m ON m.match_id = r.match_id AND m.status = 'completed'
           JOIN k.decisions d ON d.match_id = r.match_id AND d.ordinal = r.ordinal AND d.by_whom = 'agent'
           JOIN k.players p ON p.match_id = d.match_id AND p.player = d.player
           LEFT JOIN c.opportunities o ON o.match_id = r.match_id AND o.ordinal = r.ordinal AND o.type = 'self_on_live'
           WHERE r.max_depth = ? AND r.budget = ? AND r.reload = 'static' AND r.samples = 0 AND r.status = 'searched'
             AND r.match_id NOT IN (SELECT match_id FROM k.players WHERE model LIKE ?)""",
        (depth, budget, f"%{SKIPPED_MODEL}%"),
    ).fetchall()
    if len({row[10] for row in rows}) > 1:
        raise SystemExit(f"{regret_path} holds rows of several evaluators at depth {depth} and budget {budget}; they must not be mixed.")
    winners = by_round.read_winners(db_path, sorted({row[0] for row in rows}))
    moves = []
    for match, _, player, model, effort, block, round, left, choice, regret, _, mistake in rows:
        if any(r not in (won := winners[match]) for r in ROUNDS):
            continue
        seat = Seat(match, player, model, effort, block, won[1] != won[2], frozenset(r for r, w in won.items() if w == player))
        moves.append(Move(seat, round, choice.startswith("Shoot"), left, regret, None if mistake is None else bool(mistake)))
    return with_excess(moves)


def with_excess(moves: list[Move]) -> list[Move]:
    """Each move's regret minus its stratum's mean over every round, so the strata themselves carry no round effect."""
    strata: dict[tuple, list[int]] = defaultdict(list)
    for m in moves:
        strata[m.seat.model, m.shot, m.shells_left].append(m.regret)
    means = {key: fmean(values) for key, values in strata.items()}
    return [replace(m, excess=m.regret - means[m.seat.model, m.shot, m.shells_left]) for m in moves]


def mean_of(values: list[float]) -> float | None:
    return fmean(values) if values else None


# A metric's value for one seat in one round, from the seat's moves there (possibly none). None when the seat has no such moves.
Metric = Callable[[Seat, int, list[Move]], float | None]
METRICS: dict[str, Metric] = {
    "regret": lambda seat, round, moves: mean_of([m.excess / POINT for m in moves]),
    "raw regret": lambda seat, round, moves: mean_of([m.regret / POINT for m in moves]),
    "shot regret": lambda seat, round, moves: mean_of([m.excess / POINT for m in moves if m.shot]),
    "item regret": lambda seat, round, moves: mean_of([m.excess / POINT for m in moves if not m.shot]),
    "win": lambda seat, round, moves: 100.0 * (round in seat.wins),
    "self on live": lambda seat, round, moves: mean_of([100.0 * m.mistake for m in moves if m.mistake is not None]),
}


def seat_values(moves: list[Move]) -> dict[Seat, dict[int, dict[str, float | None]]]:
    """Every metric for each seat and round. A seat that never moved in a round (it lost before its turn) still has its round win."""
    by_seat_round: dict[tuple[Seat, int], list[Move]] = defaultdict(list)
    for m in moves:
        by_seat_round[m.seat, m.round].append(m)
    seats = {m.seat for m in moves}
    return {seat: {round: {name: metric(seat, round, by_seat_round[seat, round]) for name, metric in METRICS.items()} for round in ROUNDS} for seat in seats}


def changes(values: dict[Seat, dict[int, dict[str, float | None]]], metric: str, later: int, keep: Callable[[Seat], bool] = lambda seat: True) -> list[tuple[Seat, float]]:
    """Each seat's value in round `later` minus its value in round 1, for the seats that have both."""
    out = []
    for seat, rounds in values.items():
        first, last = rounds[1][metric], rounds[later][metric]
        if keep(seat) and first is not None and last is not None:
            out.append((seat, last - first))
    return out


def estimate(deltas: list[tuple[Seat, float]], rng: random.Random) -> Estimate | None:
    """Mean change with a 95% interval from resampling whole seed blocks, or None when there are too few blocks."""
    blocks: dict[str, list[float]] = defaultdict(list)
    for seat, delta in deltas:
        blocks[seat.block].append(delta)
    if len(blocks) < FEWEST_BLOCKS:
        return None
    sums, counts = [sum(v) for v in blocks.values()], [len(v) for v in blocks.values()]
    picks = range(len(blocks))
    replicates = []
    for _ in range(RESAMPLES):
        drawn = rng.choices(picks, k=len(blocks))
        replicates.append(sum(map(sums.__getitem__, drawn)) / sum(map(counts.__getitem__, drawn)))
    mean = sum(sums) / sum(counts)
    spread = stdev(replicates)
    low, high = interval(replicates)  # type: ignore[misc]
    return Estimate(sum(counts), mean, low, high, math.erfc(abs(mean) / spread / math.sqrt(2)) if spread else 0.0)


def surviving(ps: list[float]) -> int:
    """How many of the smallest p-values Benjamini-Hochberg keeps at a false discovery rate of FALSE_DISCOVERY."""
    ordered = sorted(ps)
    return max((rank for rank, p in enumerate(ordered, 1) if p <= FALSE_DISCOVERY * rank / len(ordered)), default=0)


def verdict(e: Estimate | None, lower_is_better: bool = True) -> str:
    if e is None:
        return "too few"
    if e.low > 0 or e.high < 0:
        return "better" if (e.high < 0) == lower_is_better else "worse"
    return "flat"


@dataclass(frozen=True)
class Row:
    label: str
    seats: int  # with a regret in rounds 1 and 3

    @property
    def testable(self) -> bool:
        return self.seats >= FEWEST_SEATS
    estimates: dict[tuple[str, int], Estimate | None]  # (metric, later round)


COLUMNS = [(metric, later) for metric in ("regret", "win") for later in (2, 3)]
EXTRA = [("raw regret", 3), ("shot regret", 3), ("item regret", 3), ("self on live", 3)]


def rows_for(values: dict[Seat, dict[int, dict[str, float | None]]], label: Callable[[Seat], str], rng: random.Random, columns=COLUMNS + EXTRA) -> list[Row]:
    rows = []
    for name in sorted({label(seat) for seat in values}):
        mine = lambda seat: label(seat) == name
        rows.append(Row(name, len(changes(values, "regret", 3, mine)), {(metric, later): estimate(changes(values, metric, later, mine), rng) for metric, later in columns}))
    return rows


def show(e: Estimate | None, digits: int = 2) -> str:
    return "-" if e is None else f"{e.mean:+.{digits}f} ({e.low:+.{digits}f} to {e.high:+.{digits}f})"


def model_rows(values, rng) -> list[Row]:
    """Models from the biggest regret drop to the biggest rise, then everyone."""
    models = sorted(rows_for(values, lambda s: s.model, rng), key=lambda r: r.estimates["regret", 3].mean)
    return models + rows_for(values, lambda s: "all", rng)


def config_rows(values, rng) -> list[Row]:
    order = lambda r: (r.label.rsplit(" ", 1)[0], EFFORTS.index(r.label.rsplit(" ", 1)[1]))
    return sorted(rows_for(values, lambda s: s.config, rng, COLUMNS), key=order)


def by_model(rows: list[Row]) -> str:
    return table(
        ["model", "seats", "regret, round 2 minus 1", "regret, round 3 minus 1", "round 3: verdict", "win, round 2 minus 1 (points)", "win, round 3 minus 1 (points)", "shot with a proven live: self-shots, round 3 minus 1 (points)"],
        [[r.label, f"{r.seats:,}", show(r.estimates["regret", 2]), show(r.estimates["regret", 3]), verdict(r.estimates["regret", 3]), show(r.estimates["win", 2], 1), show(r.estimates["win", 3], 1), show(r.estimates["self on live", 3], 1)] for r in rows],
    )


def by_kind(rows: list[Row]) -> str:
    return table(
        ["model", "all moves, raw regret", "all moves, adjusted", "shots, adjusted", "item moves, adjusted"],
        [[r.label] + [show(r.estimates[key]) for key in (("raw regret", 3), ("regret", 3), ("shot regret", 3), ("item regret", 3))] for r in rows],
    )


def by_level(values, rng) -> str:
    """Round 3 minus round 1 regret, split by whether the match was level at one round each (round 3 still decides the match) or already won."""
    rows = []
    for model in sorted({s.model for s in values}):
        cells = []
        for level in (True, False):
            deltas = changes(values, "regret", 3, lambda s: s.model == model and s.level == level)
            cells += [f"{len(deltas):,}", show(estimate(deltas, rng))]
        rows.append([model, *cells])
    return table(["model", "level: seats", "level: change", "decided: seats", "decided: change"], rows)


def by_config(rows: list[Row]) -> str:
    def row(r: Row) -> list[str]:
        cells = [show(r.estimates[key], 1 if key[0] == "win" else 2) for key in COLUMNS]
        return [*r.label.rsplit(" ", 1), f"{r.seats:,}", *cells, verdict(r.estimates["regret", 3]) if r.testable else "too few seats"]
    return table(["model", "effort", "seats", "regret, round 2 minus 1", "regret, round 3 minus 1", "win, round 2 minus 1 (points)", "win, round 3 minus 1 (points)", "round 3 regret"], [row(r) for r in rows])


def tally(rows: list[Row], noun: str) -> str:
    """For each delta, how many testable rows come out better, worse and flat, and how many would by chance."""
    testable = [r for r in rows if r.testable]
    lines = [f"{len(testable)} of {len(rows)} {noun} have {FEWEST_SEATS} or more seats with a regret in rounds 1 and 3. Per delta, with a 95% interval, about {0.025 * len(testable):.1f} should land on each side by chance alone."]
    for metric, later in COLUMNS:
        estimates = [r.estimates[metric, later] for r in testable]
        counts = {name: sum(verdict(e, metric == "regret") == name for e in estimates) for name in ("better", "worse", "flat")}
        kept = surviving([e.p for e in estimates])
        lines.append(f"- {metric}, round {later} minus 1: {counts['better']} better, {counts['worse']} worse, {counts['flat']} flat. {kept} survive Benjamini-Hochberg at {FALSE_DISCOVERY:.0%}.")
    return "\n".join(lines)


def report(moves: list[Move]) -> str:
    rng = random.Random(0)
    values = seat_values(moves)
    models, configs = model_rows(values, rng), config_rows(values, rng)
    matches = len({m.seat.match for m in moves})
    return (
        f"{matches:,} finished matches, {len(values):,} seats. A regret change counts only the seats that moved in both rounds. Negative regret change is better; win changes are in percentage points of rounds won.\n\n"
        f"### Change within a match, per model\n\n{by_model(models)}\n\n"
        f"### Where the regret change sits, round 3 minus round 1\n\n{by_kind(models)}\n\n"
        f"### Round 3 minus round 1 regret, by whether round 3 still decides the match\n\n{by_level(values, rng)}\n\n"
        f"### Change within a match, per config\n\n{by_config(configs)}\n\n"
        f"### What chance alone would give\n\n{tally(configs, 'configs')}\n\n{tally([r for r in models if r.label != 'all'], 'models')}\n"
    )


COLOURS = {"better": "#2a9d4b", "worse": "#d1495b", "flat": "#6b7280", "too few": "#b8bdc6"}


def svg(width: int, height: int, parts: list[str]) -> str:
    background = f'<rect width="{width}" height="{height}" fill="white"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}" font-family="sans-serif" font-size="11">' + background + "".join(parts) + "</svg>\n"


def text(x: float, y: float, content: str, anchor: str = "middle", fill: str = "#222") -> str:
    return f'<text x="{x:.1f}" y="{y:.1f}" text-anchor="{anchor}" fill="{fill}">{content}</text>'


def bar(x: float, y: float, e: Estimate, scale: Callable[[float], float], colour: str, vertical: bool) -> str:
    """A dot at the mean with a line to the ends of the interval, along y (vertical) or x."""
    mean, low, high = scale(e.mean), scale(e.low), scale(e.high)
    if vertical:
        return f'<line x1="{x:.1f}" x2="{x:.1f}" y1="{low:.1f}" y2="{high:.1f}" stroke="{colour}" stroke-width="2"/><circle cx="{x:.1f}" cy="{mean:.1f}" r="3.5" fill="{colour}"/>'
    return f'<line x1="{low:.1f}" x2="{high:.1f}" y1="{y:.1f}" y2="{y:.1f}" stroke="{colour}" stroke-width="2"/><circle cx="{mean:.1f}" cy="{y:.1f}" r="3.5" fill="{colour}"/>'


def reach(estimates: list[Estimate]) -> float:
    """A symmetric axis limit that holds every interval."""
    return math.ceil(max(max(abs(e.low), abs(e.high)) for e in estimates))


def by_round_figure(rows: list[Row]) -> str:
    """One small panel per model and row of panels per metric: the change from round 1 at rounds 2 and 3, each with its interval."""
    panel, top, left = 104, 52, 30
    metrics = [("regret", "mean regret change (points); below 0 is better", True), ("win", "round win change (points); above 0 is better", False)]
    parts = [text(left + len(rows) * panel / 2, 16, "Change from round 1 in the same seat and match. Dot: mean. Bar: 95% interval over seed blocks. Green better, red worse.")]
    for line, (metric, caption, lower_is_better) in enumerate(metrics):
        shown = [e for r in rows if r.testable for e in (r.estimates[metric, 2], r.estimates[metric, 3]) if e]
        limit = reach(shown)
        y0 = top + line * 190
        scale = lambda v, y0=y0, limit=limit: y0 + 70 - v / limit * 60
        parts += [text(left, y0 + 2, caption, "start", "#555"), text(left - 6, scale(limit) + 4, f"{limit:+d}", "end"), text(left - 6, scale(0) + 4, "0", "end"), text(left - 6, scale(-limit) + 4, f"{-limit:+d}", "end")]
        for i, r in enumerate(rows):
            x0 = left + i * panel
            parts.append(f'<line x1="{x0 + 8}" x2="{x0 + panel - 8}" y1="{scale(0):.1f}" y2="{scale(0):.1f}" stroke="#ccc"/>')
            parts.append(f'<circle cx="{x0 + 22}" cy="{scale(0):.1f}" r="3.5" fill="none" stroke="#6b7280"/>')
            for later, x in ((2, x0 + 52), (3, x0 + 82)):
                e = r.estimates[metric, later]
                if e and r.testable and not (metric == "win" and r.label == "all"):
                    parts.append(bar(x, 0, e, scale, COLOURS[verdict(e, lower_is_better)], True))
            if line == 0:
                parts.append(text(x0 + panel / 2, top - 8, f"{r.label.replace('claude-', '').replace('-20251001', '')} ({r.seats:,})"))
            parts.append(text(x0 + 22, y0 + 150, "1") + text(x0 + 52, y0 + 150, "2") + text(x0 + 82, y0 + 150, "3"))
    return svg(left + len(rows) * panel, top + 2 * 190, parts)


def config_figure(rows: list[Row]) -> str:
    """Round 3 minus round 1 regret for every config, with its interval. Grey dots have too few seats to test."""
    row, label_width, plot = 15, 230, 420
    shown = [e for r in rows if (e := r.estimates["regret", 3])]
    limit = reach(shown)
    scale = lambda v: label_width + (v + limit) / (2 * limit) * plot
    parts = [text(label_width + plot / 2 - 40, 16, "Regret change, round 3 minus round 1 (points). Left of 0 is better. Bars: 95% intervals.")]
    parts.append(f'<line x1="{scale(0):.1f}" x2="{scale(0):.1f}" y1="24" y2="{30 + len(rows) * row}" stroke="#999"/>')
    for step in range(-limit, limit + 1):
        parts.append(text(scale(step), 30 + len(rows) * row + 14, f"{step:+d}" if step else "0"))
    for i, r in enumerate(rows):
        y = 34 + i * row
        parts.append(text(label_width - 8, y + 4, r.label.replace("claude-", "").replace("-20251001", ""), "end", "#222" if r.testable else "#999"))
        if e := r.estimates["regret", 3]:
            parts.append(bar(0, y, e, scale, COLOURS[verdict(e) if r.testable else "too few"], False))
    return svg(label_width + plot + 20, 50 + len(rows) * row, parts)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--db", default=DB)
    parser.add_argument("--regret", type=Path, default=DERIVED / "regret.sqlite")
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--mistakes", type=Path, default=DERIVED / "certain-mistakes.sqlite")
    parser.add_argument("--doc", type=Path)
    parser.add_argument("--svg", type=Path, help="directory for the two figures")
    args = parser.parse_args()
    require_current(args.db)
    moves = load_moves(args.regret, args.knowledge, args.mistakes, args.db)
    values = seat_values(moves)
    if args.svg is not None:
        rng = random.Random(0)
        args.svg.mkdir(parents=True, exist_ok=True)
        (args.svg / "round-change-by-model.svg").write_text(by_round_figure(model_rows(values, rng)))
        (args.svg / "round-change-by-config.svg").write_text(config_figure(config_rows(values, rng)))
    text_ = report(moves)
    if args.doc is None:
        print(text_)
    else:
        splice_between_markers(args.doc, "round-improvement", text_)


if __name__ == "__main__":
    main()
