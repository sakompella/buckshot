#!/usr/bin/env python3
"""Do effort gains survive matching on the opponent? Round win rates of one model's efforts against the same external configs.

Within each model, every effort is compared with the reference effort (medium) in three layers, each on its own support:
pooled (every external match of either effort), common opponents (only opponent configs both efforts faced, equal weight per
opponent config, so both efforts are scored on the same mix), and strict blocks (only the same opponent config, seed, seat
position and code version in both efforts, one paired difference per block). A cell nobody played is left out, never read as 0.
Round winners come from by_round.py, so rounds are primary and match win shares secondary. Intervals resample seed blocks (strict
layer: seeds of one opponent) within each opponent config and appear only when there are at least MIN_UNITS of them.
Games between two efforts of one model and games with a DeepSeek seat are left out. The database is opened read-only. With --doc
FILE the tables replace the text between the matched-efforts markers of that file.

    python3 tools/arena/analysis/matched_efforts.py [--db PATH] [--draws 2000] [--doc docs/arena/analysis/matched-efforts.md]
"""

import argparse
import hashlib
import random
from collections import defaultdict
from dataclasses import dataclass
from typing import Callable

import boot
import bt
import by_round
from fmt import pct, pp, signed, table
from load import DB, SKIPPED_MODEL, connect

START, END = "<!-- matched-efforts:start -->", "<!-- matched-efforts:end -->"

REFERENCE = "medium"
MIN_MATCHES = 2  # matches per effort and opponent config before the config counts as common support
MIN_UNITS = 20  # independent seed blocks (strict layer: seeds) before an interval is shown
EFFORTS = ("off", "minimal", "low", "medium", "high", "xhigh", "max")


@dataclass(frozen=True, order=True)
class Config:
    model: str
    effort: str
    endpoint: str


@dataclass(frozen=True)
class Seat:
    """One seat of one scored match. `rounds` says per round whether this seat won it, or is None when the winners cannot be read."""

    match: str
    block: str
    code: str
    seed: int
    position: int
    focal: Config
    opponent: Config
    share: float
    rounds: tuple[bool, ...] | None


@dataclass(frozen=True)
class Scored:
    """A seat's contribution to one rate: `num` over `den`, from one seed block and one strict key."""

    block: str
    key: tuple[int, int, str]  # seed, position, code
    num: float
    den: int


Metric = Callable[[Seat], tuple[float, int] | None]
Cells = dict[Config, list[Scored]]  # opponent config to the focal config's scored seats


def round_metric(seat: Seat) -> tuple[float, int] | None:
    return (sum(seat.rounds), len(seat.rounds)) if seat.rounds else None


def match_metric(seat: Seat) -> tuple[float, int] | None:
    return seat.share, 1


METRICS = {"rounds": round_metric, "matches": match_metric}


def rate(units: list[Scored]) -> float:
    return sum(u.num for u in units) / sum(u.den for u in units)


# ---- loading

def load_seats(db) -> tuple[list[Seat], int]:
    """Both seats of every scored match without a DeepSeek seat, and how many DeepSeek matches were left out."""
    cash: dict[str, dict[str, float]] = defaultdict(dict)
    rows = db.execute(
        """SELECT s.match_id, m.seed_block_id, m.code_hash, m.seed, s.position, s.player, s.win_share, s.cash, e.model, e.effort, e.endpoint_category
           FROM match_seats s JOIN entrants e ON e.id = s.entrant_id JOIN matches m ON m.id = s.match_id
           WHERE m.status = 'completed' ORDER BY s.match_id, s.position"""
    ).fetchall()
    by_match: dict[str, list[tuple]] = defaultdict(list)
    for row in rows:
        by_match[row[0]].append(row)
        cash[row[0]][row[5]] = row[7]
    lines = by_round.public_lines(db)
    seats, skipped = [], 0
    for match, pair in by_match.items():
        if any(SKIPPED_MODEL in row[8] for row in pair):
            skipped += 1
            continue
        winners = by_round.round_winners(lines.get(match, []), cash[match])
        configs = [Config(row[8], row[9], row[10]) for row in pair]
        for row, focal, opponent in zip(pair, configs, reversed(configs)):
            rounds = None if winners is None else tuple(winners[n] == row[5] for n in sorted(winners))
            seats.append(Seat(match, row[1], row[2], row[3], row[4], focal, opponent, row[6], rounds))
    return seats, skipped


# ---- layers

def external(seats: list[Seat]) -> list[Seat]:
    return [s for s in seats if s.focal.model != s.opponent.model]


def arms(seats: list[Seat], metric: Metric) -> dict[Config, Cells]:
    """Focal config to its scored seats against each external opponent config."""
    out: dict[Config, Cells] = defaultdict(lambda: defaultdict(list))
    for seat in external(seats):
        if (value := metric(seat)) is not None and value[1] > 0:
            out[seat.focal][seat.opponent].append(Scored(seat.block, (seat.seed, seat.position, seat.code), *value))
    return out


def common_support(a: Cells, b: Cells) -> set[Config]:
    return {o for o in a.keys() & b.keys() if len(a[o]) >= MIN_MATCHES and len(b[o]) >= MIN_MATCHES}


def equal_configs(support: set[Config]) -> dict[Config, float]:
    return {o: 1 / len(support) for o in support}


def equal_models(support: set[Config]) -> dict[Config, float]:
    models = {o.model for o in support}
    return {o: 1 / len(models) / sum(p.model == o.model for p in support) for o in support}


def medium_opponents(support: set[Config]) -> dict[Config, float]:
    return equal_configs({o for o in support if o.effort == REFERENCE}) if any(o.effort == REFERENCE for o in support) else {}


MIXES = {"config": equal_configs, "model": equal_models, "medium opponents": medium_opponents}


def standardized(cells: Cells, weights: dict[Config, float]) -> float:
    return sum(w * rate(cells[o]) for o, w in weights.items())


def blocks_of(units: list[Scored]) -> list[list[Scored]]:
    out: dict[str, list[Scored]] = defaultdict(list)
    for u in units:
        out[u.block].append(u)
    return list(out.values())


def common_interval(a: Cells, b: Cells, weights: dict[Config, float], rng: random.Random, draws: int) -> tuple[float, float] | None:
    by_arm = [{o: blocks_of(cells[o]) for o in weights} for cells in (a, b)]
    if min(sum(len(v) for v in arm.values()) for arm in by_arm) < MIN_UNITS:
        return None

    def resampled(blocks: list[list[Scored]]) -> float:
        return rate([u for _ in blocks for u in rng.choice(blocks)])

    return boot.interval([sum(w * (resampled(by_arm[0][o]) - resampled(by_arm[1][o])) for o, w in weights.items()) for _ in range(draws)])


@dataclass(frozen=True)
class Pooled:
    n: int
    n_ref: int
    rate: float
    rate_ref: float


@dataclass(frozen=True)
class Common:
    opponents: int
    models: int
    n: int
    n_ref: int
    empirical: float  # count weighted over the common opponents: each effort has its own mix, so not comparable
    empirical_ref: float
    rate: float  # equal weight per opponent config
    rate_ref: float
    interval: tuple[float, float] | None
    mixes: dict[str, float | None]  # difference under the other weightings; None where the mix has no opponent
    outside: int  # matches against opponents outside the common support, not counted above
    outside_ref: int


@dataclass(frozen=True)
class Strict:
    pairs: int
    opponents: int
    seeds: int
    diff: float
    interval: tuple[float, float] | None
    up: int
    tied: int
    down: int


def pooled(a: Cells, b: Cells) -> Pooled | None:
    flat = lambda cells: [u for units in cells.values() for u in units]
    return Pooled(len(flat(a)), len(flat(b)), rate(flat(a)), rate(flat(b))) if flat(a) and flat(b) else None


def common(a: Cells, b: Cells, rng: random.Random, draws: int) -> Common | None:
    support = common_support(a, b)
    if not support:
        return None
    flat = lambda cells: [u for o in support for u in cells[o]]
    weights = equal_configs(support)
    mixes = {name: (standardized(a, w) - standardized(b, w) if (w := mix(support)) else None) for name, mix in MIXES.items() if name != "config"}
    outside = lambda cells: sum(len(u) for o, u in cells.items() if o not in support)
    return Common(
        len(support), len({o.model for o in support}), len(flat(a)), len(flat(b)), rate(flat(a)), rate(flat(b)),
        standardized(a, weights), standardized(b, weights), common_interval(a, b, weights, rng, draws), mixes, outside(a), outside(b),
    )


def key_rates(units: list[Scored], code: bool) -> dict[tuple[int, int, str], float]:
    """Seats sharing a strict key (repeated matches of one cell) count once, pooled. Without `code` the key ignores the code version."""
    out: dict[tuple, list[Scored]] = defaultdict(list)
    for u in units:
        out[u.key if code else (*u.key[:2], "")].append(u)
    return {key: rate(group) for key, group in out.items()}


def strict(a: Cells, b: Cells, code: bool, rng: random.Random, draws: int) -> Strict | None:
    """Paired differences per (opponent, seed, position) and, with `code`, code version, averaged within an opponent seed, then equally over opponents."""
    diffs: dict[Config, dict[int, list[float]]] = {}
    for o in a.keys() & b.keys():
        ra, rb = key_rates(a[o], code), key_rates(b[o], code)
        for key in ra.keys() & rb.keys():
            diffs.setdefault(o, {}).setdefault(key[0], []).append(ra[key] - rb[key])
    if not diffs:
        return None
    mean = lambda xs: sum(xs) / len(xs)
    flat = lambda by_seed: [d for ds in by_seed.values() for d in ds]
    estimate = lambda units: mean([mean([d for ds in by_seed for d in ds]) for by_seed in units.values()])
    units = {o: list(by_seed.values()) for o, by_seed in diffs.items()}
    all_diffs = [d for by_seed in diffs.values() for d in flat(by_seed)]
    seeds = sum(len(u) for u in units.values())
    interval = None
    if seeds >= MIN_UNITS:
        interval = boot.interval([estimate({o: [rng.choice(u) for _ in u] for o, u in units.items()}) for _ in range(draws)])
    return Strict(
        len(all_diffs), len(diffs), seeds, estimate(units), interval,
        sum(d > 0 for d in all_diffs), sum(d == 0 for d in all_diffs), sum(d < 0 for d in all_diffs),
    )


@dataclass(frozen=True)
class Row:
    model: str
    effort: str
    pooled: Pooled | None
    common: Common | None
    common_code: Common | None  # common opponents again, with the reference's matches cut to the code versions the effort played
    strict_code: Strict | None  # same opponent, seed, seat and code version
    strict: Strict | None  # same opponent, seed and seat, any code version
    elo: float | None  # pooled Bradley-Terry rating difference to the reference, from every scored match


def compare(seats: list[Seat], metric: Metric, elo: dict[tuple[str, str], float], draws: int, seed: int = 0) -> list[Row]:
    """One row per model and non-reference effort, against the reference effort of the same model and endpoint."""
    by_config = arms(seats, metric)
    rng = random.Random(seed)
    rows = []
    for focal in sorted(by_config):
        ref = Config(focal.model, REFERENCE, focal.endpoint)
        if focal.effort == REFERENCE or ref not in by_config:
            continue
        a, b = by_config[focal], by_config[ref]
        both = (elo.get((focal.model, focal.effort)), elo.get((focal.model, REFERENCE)))
        codes = {u.key[2] for units in a.values() for u in units}
        b_code = {o: [u for u in units if u.key[2] in codes] for o, units in b.items()}
        rows.append(
            Row(
                focal.model, focal.effort, pooled(a, b), common(a, b, rng, draws), common(a, b_code, rng, draws),
                strict(a, b, True, rng, draws), strict(a, b, False, rng, draws), None if None in both else both[0] - both[1],
            )
        )
    return sorted(rows, key=lambda r: (r.model, EFFORTS.index(r.effort) if r.effort in EFFORTS else -1))


# ---- rendering

def ratings(seats: list[Seat]) -> dict[tuple[str, str], float]:
    """Pooled Bradley-Terry rating (Elo) of each model and effort over every scored match, fitted as leaderboard.py does but without its cohort labels."""
    cells: bt.Cells = {}
    for seat in seats:
        if seat.position == 1:
            first, second = (seat.focal.model, seat.focal.effort), (seat.opponent.model, seat.opponent.effort)
            cell = cells.setdefault((first, second), [0.0, 0.0])
            cell[0] += 1
            cell[1] += seat.share
    return bt.fit(cells).elo()


def interval_text(interval, shown=pp) -> str:
    return "" if interval is None else f" [{shown(interval[0])}, {shown(interval[1])}]"


def strict_text(s: Strict | None) -> str:
    if s is None:
        return "none"
    return f"{pp(s.diff)}{interval_text(s.interval)} ({s.pairs} pairs, {s.opponents} configs, {s.seeds} seeds; +{s.up} ={s.tied} -{s.down})"


def common_text(c: Common | None) -> str:
    if c is None:
        return "none"
    return f"{pp(c.rate - c.rate_ref)}{interval_text(c.interval)} ({c.opponents} configs, {c.n:,}/{c.n_ref:,})"


def effort_table(rows: list[Row]) -> str:
    def cells(r: Row) -> list[str]:
        p = r.pooled
        return [
            r.model, r.effort,
            "-" if p is None else f"{pp(p.rate - p.rate_ref)} ({p.n:,}/{p.n_ref:,})",
            "-" if r.elo is None else signed(r.elo),
            common_text(r.common), common_text(r.common_code), strict_text(r.strict_code), strict_text(r.strict),
        ]

    header = ["model", "effort", "pooled diff (matches)", "pooled rating diff (Elo)", "common opponents diff (matches)", "common opponents, same code", "strict blocks, same code", "strict blocks, any code"]
    return table(header, [cells(r) for r in rows])


def support_table(rows: list[Row]) -> str:
    def cells(r: Row) -> list[str]:
        c = r.common
        if c is None:
            return [r.model, r.effort, "-", "-", "-", "-"]
        mixes = " / ".join("-" if v is None else pp(v) for v in c.mixes.values())
        return [r.model, r.effort, f"{pct(c.empirical)} vs {pct(c.empirical_ref)}", f"{pct(c.rate)} vs {pct(c.rate_ref)}", mixes, f"{c.outside:,}/{c.outside_ref:,}"]

    header = ["model", "effort", "count-weighted rates on common opponents", "equal-config rates", f"diff by weighting: {' / '.join(k for k in MIXES if k != 'config')}", "matches outside the common support"]
    return table(header, [cells(r) for r in rows])


def coverage(seats: list[Seat], skipped: int, snapshot: str) -> str:
    matches = {s.match for s in seats}
    same = {s.match for s in seats if s.focal.model == s.opponent.model}
    unreadable = {s.match for s in seats if s.rounds is None}
    empty = {s.match for s in seats if s.rounds == ()}
    return (
        f"Snapshot {snapshot}: {len(matches) + skipped:,} scored matches; {skipped:,} with a DeepSeek seat, {len(same):,} between two efforts of one model "
        f"and {len(unreadable):,} with unreadable round winners (and {len(empty):,} with no rounds) are left out of the layers they cannot enter; "
        f"{len(matches) - len(same):,} external matches remain."
    )


def by_effort(rows: list[Row]) -> str:
    """Per effort, the models' differences averaged with equal weight per model, and how many models are positive."""
    out = []
    for effort in EFFORTS:
        group = [r for r in rows if r.effort == effort]
        layers = {
            "pooled": [r.pooled.rate - r.pooled.rate_ref for r in group if r.pooled],
            "common": [r.common.rate - r.common.rate_ref for r in group if r.common],
            "strict": [r.strict.diff for r in group if r.strict],
        }
        if group:
            out.append([effort, *(f"{pp(sum(v) / len(v))} ({sum(x > 0 for x in v)}/{len(v)} up)" if v else "-" for v in layers.values())])
    return table(["effort", "pooled", "common opponents", "strict blocks, any code"], out)


def code_mix(seats: list[Seat]) -> str:
    """External seats by code version (numbered by size), reference effort against the other efforts."""
    counts: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for seat in external(seats):
        counts[seat.code][seat.focal.effort != REFERENCE] += 1
    ordered = sorted(counts.values(), key=lambda c: -sum(c))
    return table(["code version", f"seats at {REFERENCE}", "seats at other efforts"], [[str(n), f"{a:,}", f"{b:,}"] for n, (a, b) in enumerate(ordered, 1)])


def signs(rows: list[Row]) -> str:
    """How often the matched layers keep the sign of the pooled difference."""
    def agree(layer) -> str:
        pairs = [(r.pooled.rate - r.pooled.rate_ref, d) for r in rows if r.pooled and (d := layer(r)) is not None]
        return f"{sum(x * y > 0 for x, y in pairs)} of {len(pairs)}"

    intervals = sum(1 for r in rows for x in (r.common, r.common_code, r.strict_code, r.strict) if x is not None and x.interval is not None)
    return (
        f"{len(rows)} effort comparisons. Sign kept from the pooled difference: common opponents {agree(lambda r: r.common and r.common.rate - r.common.rate_ref)}, "
        f"common opponents with the same code {agree(lambda r: r.common_code and r.common_code.rate - r.common_code.rate_ref)}, "
        f"strict blocks with the same code {agree(lambda r: r.strict_code and r.strict_code.diff)}, strict blocks with any code {agree(lambda r: r.strict and r.strict.diff)}. "
        f"Intervals shown: {intervals}."
    )


def snapshot_id(db) -> str:
    digest = hashlib.sha256()
    for (fingerprint,) in db.execute("SELECT fingerprint FROM matches WHERE status = 'completed' ORDER BY id"):
        digest.update(fingerprint.encode())
    return digest.hexdigest()[:12]


def report(db, draws: int) -> str:
    seats, skipped = load_seats(db)
    elo = ratings(seats)
    parts = [coverage(seats, skipped, snapshot_id(db)), code_mix(seats)]
    for title, name in (("Round win rate (primary)", "rounds"), ("Match win share (secondary)", "matches")):
        rows = compare(seats, METRICS[name], elo, draws)
        parts.append(f"### {title}\n\n{signs(rows)}\n\n{by_effort(rows)}\n\n{effort_table(rows)}\n\n#### Common support and weightings\n\n{support_table(rows)}")
    return "\n\n".join(parts) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--db", default=DB)
    parser.add_argument("--draws", type=int, default=2000)
    parser.add_argument("--doc")
    args = parser.parse_args()
    text = report(connect(args.db), args.draws)
    if args.doc:
        doc = open(args.doc).read()
        head, rest = doc.split(START)
        _, tail = rest.split(END)
        open(args.doc, "w").write(f"{head}{START}\n{text}{END}{tail}")
    else:
        print(text)


if __name__ == "__main__":
    main()
