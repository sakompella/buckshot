#!/usr/bin/env python3
"""Coverage and sensitivity of effort comparisons: round win rates of one model's efforts against the same external configs.

Within each model, every effort is compared with the reference effort (medium) in three layers, each on its own support:
pooled (every external match of either effort), common opponents (only opponent configs both efforts faced in at least
MIN_MATCHES matches, equal weight per opponent config, so both efforts are scored on the same mix), and strict blocks (the same
opponent config, seed and seat position in both efforts; pairs are averaged per opponent, then equally over opponents). A cell
nobody played is left out, never read as 0. Rounds are primary (round winners come from by_round.py), match win shares secondary.
The comparison is run on every scored match and again on the matches that started at or after REQUEST_CHANGE, so each period's
ratings, counts and coverage describe only that period. Intervals resample seeds, jointly across opponents and both efforts, and
appear only when each effort has at least MIN_UNITS distinct seeds in the support and no resample leaves a cell empty. Games between two efforts of one model and
games with a DeepSeek seat are left out. The database is opened read-only. With --doc FILE the tables replace the text between the
matched-efforts markers of that file.

    python3 tools/arena/analysis/matched_efforts.py [--db PATH] [--draws 2000] [--doc <output.md>]
"""

import argparse
import random
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable

import boot
import bt
import by_round
from fmt import pp, signed, table
from load import DB, SKIPPED_MODEL, connect

START, END = "<!-- matched-efforts:start -->", "<!-- matched-efforts:end -->"

REFERENCE = "medium"
MIN_MATCHES = 2  # matches per effort and opponent config before the config counts as common support
MIN_UNITS = 20  # distinct seeds in each effort's support before an interval is shown
REQUEST_CHANGE = datetime(2026, 10, 16, 14, 48, 44, tzinfo=timezone.utc)  # commit time of the change to the requests each model is sent: reasoning summary mode and, for Sonnet at off, the thinking type
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
    started: datetime
    seed: int
    position: int
    focal: Config
    opponent: Config
    share: float
    rounds: tuple[bool, ...] | None


@dataclass(frozen=True)
class Scored:
    """A seat's contribution to one rate: `num` over `den`, from one seed and seat position."""

    key: tuple[int, int]  # seed, position
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

def parse_time(text: str) -> datetime:
    """A stored or given time with its offset; a time without one is an error, not a guess."""
    parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError(f"time without an offset: {text}")
    return parsed


def load_seats(db) -> tuple[list[Seat], int]:
    """Both seats of every scored match without a DeepSeek seat, and how many DeepSeek matches were left out."""
    cash: dict[str, dict[str, float]] = defaultdict(dict)
    rows = db.execute(
        """SELECT s.match_id, m.started_at, m.seed, s.position, s.player, s.win_share, s.cash, e.model, e.effort, e.endpoint_category
           FROM match_seats s JOIN entrants e ON e.id = s.entrant_id JOIN matches m ON m.id = s.match_id
           WHERE m.status = 'completed' ORDER BY s.match_id, s.position"""
    ).fetchall()
    by_match: dict[str, list[tuple]] = defaultdict(list)
    for row in rows:
        by_match[row[0]].append(row)
        cash[row[0]][row[4]] = row[6]
    lines = by_round.public_lines(db)
    seats, skipped = [], 0
    for match, pair in by_match.items():
        if any(SKIPPED_MODEL in row[7] for row in pair):
            skipped += 1
            continue
        winners = by_round.round_winners(lines.get(match, []), cash[match])
        configs = [Config(row[7], row[8], row[9]) for row in pair]
        for row, focal, opponent in zip(pair, configs, reversed(configs)):
            rounds = None if winners is None else tuple(winners[n] == row[4] for n in sorted(winners))
            seats.append(Seat(match, parse_time(row[1]), row[2], row[3], focal, opponent, row[5], rounds))
    return seats, skipped


def since(seats: list[Seat], start: datetime) -> list[Seat]:
    return [s for s in seats if s.started >= start]


# ---- layers

def external(seats: list[Seat]) -> list[Seat]:
    return [s for s in seats if s.focal.model != s.opponent.model]


def arms(seats: list[Seat], metric: Metric) -> dict[Config, Cells]:
    """Focal config to its scored seats against each external opponent config."""
    out: dict[Config, Cells] = defaultdict(lambda: defaultdict(list))
    for seat in external(seats):
        if (value := metric(seat)) is not None and value[1] > 0:
            out[seat.focal][seat.opponent].append(Scored((seat.seed, seat.position), *value))
    return out


def common_support(a: Cells, b: Cells) -> set[Config]:
    return {o for o in a.keys() & b.keys() if len(a[o]) >= MIN_MATCHES and len(b[o]) >= MIN_MATCHES}


def equal_configs(support: set[Config]) -> dict[Config, float]:
    return {o: 1 / len(support) for o in support}


def standardized(cells: Cells, weights: dict[Config, float]) -> float:
    return sum(w * rate(cells[o]) for o, w in weights.items())


def seeds_of(units: list[Scored]) -> set[int]:
    return {u.key[0] for u in units}


def seed_draws(seeds: set[int], rng: random.Random, draws: int):
    """Resamples of the seeds: how often each is drawn, so one seed counts the same in every cell and both efforts."""
    ordered = sorted(seeds)
    for _ in range(draws):
        yield Counter(rng.choices(ordered, k=len(ordered)))


def interval_of(replicates: list[float], draws: int) -> tuple[float, float] | None:
    """The central 95%, or None when any resample left a cell without data: dropping those resamples would bias the interval."""
    return boot.interval(replicates) if len(replicates) == draws else None


def common_interval(a: Cells, b: Cells, weights: dict[Config, float], rng: random.Random, draws: int) -> tuple[float, float] | None:
    units = {o: (a[o], b[o]) for o in weights}
    if min(len(seeds_of([u for pair in units.values() for u in pair[arm]])) for arm in (0, 1)) < MIN_UNITS:
        return None
    all_seeds = seeds_of([u for pair in units.values() for arm in pair for u in arm])

    def resampled(cell: list[Scored], count: Counter) -> float | None:
        den = sum(count[u.key[0]] * u.den for u in cell)
        return sum(count[u.key[0]] * u.num for u in cell) / den if den else None

    replicates = []
    for count in seed_draws(all_seeds, rng, draws):
        parts = [(w, resampled(units[o][0], count), resampled(units[o][1], count)) for o, w in weights.items()]
        if all(x is not None and y is not None for _, x, y in parts):
            replicates.append(sum(w * (x - y) for w, x, y in parts))
    return interval_of(replicates, draws)


@dataclass(frozen=True)
class Pooled:
    n: int
    n_ref: int
    seeds: int  # distinct seeds of the effort's matches
    rate: float
    rate_ref: float


@dataclass(frozen=True)
class Common:
    opponents: int
    n: int
    n_ref: int
    seeds: int  # distinct seeds of the effort's matches on the common opponents
    rate: float  # equal weight per opponent config
    rate_ref: float
    interval: tuple[float, float] | None
    outside: int  # the effort's matches against opponents outside the common support, not counted above
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
    return Pooled(len(flat(a)), len(flat(b)), len(seeds_of(flat(a))), rate(flat(a)), rate(flat(b))) if flat(a) and flat(b) else None


def common(a: Cells, b: Cells, rng: random.Random, draws: int) -> Common | None:
    support = common_support(a, b)
    if not support:
        return None
    flat = lambda cells: [u for o in support for u in cells[o]]
    weights = equal_configs(support)
    outside = lambda cells: sum(len(u) for o, u in cells.items() if o not in support)
    return Common(
        len(support), len(flat(a)), len(flat(b)), len(seeds_of(flat(a))), standardized(a, weights), standardized(b, weights),
        common_interval(a, b, weights, rng, draws), outside(a), outside(b),
    )


def key_rates(units: list[Scored]) -> dict[tuple[int, int], float]:
    """Seats sharing a strict key (repeated matches of one cell) count once, pooled."""
    out: dict[tuple, list[Scored]] = defaultdict(list)
    for u in units:
        out[u.key].append(u)
    return {key: rate(group) for key, group in out.items()}


def strict(a: Cells, b: Cells, rng: random.Random, draws: int) -> Strict | None:
    """Paired differences per (opponent, seed, position), averaged within an opponent, then equally over opponents."""
    pairs: list[tuple[Config, int, float]] = []
    for o in a.keys() & b.keys():
        ra, rb = key_rates(a[o]), key_rates(b[o])
        pairs += [(o, key[0], ra[key] - rb[key]) for key in ra.keys() & rb.keys()]
    if not pairs:
        return None
    opponents = {o for o, _, _ in pairs}

    def estimate(count: Counter | None) -> float | None:
        means = []
        for o in opponents:
            weighted = [(1 if count is None else count[seed], d) for p, seed, d in pairs if p == o]
            total = sum(w for w, _ in weighted)
            if not total:
                return None
            means.append(sum(w * d for w, d in weighted) / total)
        return sum(means) / len(means)

    seeds = {seed for _, seed, _ in pairs}
    interval = None
    if len(seeds) >= MIN_UNITS:
        replicates = [e for count in seed_draws(seeds, rng, draws) if (e := estimate(count)) is not None]
        interval = interval_of(replicates, draws)
    diffs = [d for _, _, d in pairs]
    return Strict(len(pairs), len(opponents), len(seeds), estimate(None), interval, sum(d > 0 for d in diffs), sum(d == 0 for d in diffs), sum(d < 0 for d in diffs))


@dataclass(frozen=True)
class Row:
    model: str
    effort: str
    pooled: Pooled | None
    common: Common | None
    strict: Strict | None
    elo: float | None  # Bradley-Terry rating difference to the reference, fitted on the same period's matches


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
        rows.append(Row(focal.model, focal.effort, pooled(a, b), common(a, b, rng, draws), strict(a, b, rng, draws), None if None in both else both[0] - both[1]))
    return sorted(rows, key=lambda r: (r.model, EFFORTS.index(r.effort) if r.effort in EFFORTS else -1))


# ---- rendering

def ratings(seats: list[Seat]) -> dict[tuple[str, str], float]:
    """Bradley-Terry rating (Elo) of each model and effort over the given seats, fitted as leaderboard.py does but without its cohort labels."""
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
    return f"{pp(c.rate - c.rate_ref)}{interval_text(c.interval)} ({c.opponents} configs, {c.n:,}/{c.n_ref:,} matches, {c.seeds} seeds; {c.outside:,}/{c.outside_ref:,} outside)"


def effort_table(rows: list[Row]) -> str:
    def cells(r: Row) -> list[str]:
        p = r.pooled
        return [
            r.model, r.effort,
            "-" if p is None else f"{pp(p.rate - p.rate_ref)} ({p.n:,}/{p.n_ref:,} matches, {p.seeds} seeds)",
            "-" if r.elo is None else signed(r.elo),
            common_text(r.common), strict_text(r.strict),
        ]

    header = ["model", "effort", "pooled diff", "rating diff (Elo)", "common opponents diff", "strict blocks diff"]
    return table(header, [cells(r) for r in rows])


def coverage(seats: list[Seat]) -> str:
    matches = {s.match for s in seats}
    same = {s.match for s in seats if s.focal.model == s.opponent.model}
    unreadable = {s.match for s in seats if s.rounds is None}
    empty = {s.match for s in seats if s.rounds == ()}
    return (
        f"{len(matches):,} scored matches, of which {len(same):,} are between two efforts of one model and {len(matches) - len(same):,} are external. "
        f"{len(unreadable):,} have unreadable round winners and {len(empty):,} have no rounds; they stay out of the round layers."
    )


def chronology(seats: list[Seat]) -> str:
    """External seats before and after REQUEST_CHANGE, medium against the other efforts."""
    counts = Counter((s.focal.effort == REFERENCE, s.started >= REQUEST_CHANGE) for s in external(seats))
    return (
        f"External seats at {REFERENCE}: {counts[True, False]:,} before the change and {counts[True, True]:,} after. "
        f"External seats at the other efforts: {counts[False, False]:,} before and {counts[False, True]:,} after."
    )


def report(db, draws: int) -> str:
    seats, skipped = load_seats(db)
    parts = [f"Matches with a DeepSeek seat ({skipped:,}) are left out.", chronology(seats)]
    for period, group in (("All matches", seats), (f"Matches started on or after {REQUEST_CHANGE:%Y-%m-%d %H:%M} UTC", since(seats, REQUEST_CHANGE))):
        elo = ratings(group)
        parts.append(f"## {period}\n\n{coverage(group)}")
        for title, name in (("Round win rate (primary)", "rounds"), ("Match win share (secondary)", "matches")):
            parts.append(f"### {title}\n\n{effort_table(compare(group, METRICS[name], elo, draws))}")
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
