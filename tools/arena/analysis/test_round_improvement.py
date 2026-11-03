"""Tests for the within-match round change: python3 -m unittest discover -s tools/arena/analysis"""

import random
import sqlite3
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

import round_improvement as ri
from test_by_round import A1, A3, B2, event, lines

POINT = ri.POINT


def seat(n: int, wins: frozenset[int] = frozenset(), block: str | None = None) -> ri.Seat:
    return ri.Seat(f"m{n}", "A", "opus", "high", block or f"b{n}", False, wins)


def move(s: ri.Seat, round: int, regret: int, shot: bool = True, left: int = 2, mistake: bool | None = None) -> ri.Move:
    return ri.Move(s, round, shot, left, regret, mistake)


class Adjustment(unittest.TestCase):
    def test_a_shift_to_easier_strata_is_not_an_improvement(self):
        # Long chambers are cheap and short ones dear for everyone, so a seat that meets short ones in round 1 and long ones in round 3 has no real change.
        s = seat(1)
        moves = ri.with_excess([move(s, 1, 40 * POINT, left=2), move(s, 3, 10 * POINT, left=5), move(seat(2), 1, 40 * POINT, left=2), move(seat(2), 3, 10 * POINT, left=5)])
        values = ri.seat_values(moves)
        self.assertEqual(ri.changes(values, "raw regret", 3)[0][1], -30)
        self.assertEqual(ri.changes(values, "regret", 3)[0][1], 0)


class Changes(unittest.TestCase):
    def test_a_win_counts_for_a_seat_that_never_moved_in_the_round(self):
        s = seat(1, wins=frozenset({1, 3}))
        values = ri.seat_values([move(s, 1, 0), move(s, 2, 0)])
        self.assertEqual(ri.changes(values, "win", 2), [(s, -100.0)])
        self.assertEqual(ri.changes(values, "win", 3), [(s, 0.0)])

    def test_regret_changes_need_moves_in_both_rounds(self):
        s = seat(1)
        values = ri.seat_values([move(s, 1, 2 * POINT), move(s, 2, 5 * POINT)])
        self.assertEqual(ri.changes(values, "regret", 2), [(s, 0.0)])
        self.assertEqual(ri.changes(values, "regret", 3), [])

    def test_self_shots_are_rated_over_opportunities_only(self):
        s = seat(1)
        values = ri.seat_values([move(s, 1, 0, mistake=True), move(s, 1, 0, mistake=False), move(s, 1, 0), move(s, 3, 0, mistake=False)])
        self.assertEqual(ri.changes(values, "self on live", 3), [(s, -50.0)])


class Estimates(unittest.TestCase):
    def deltas(self, values: list[float]) -> list[tuple[ri.Seat, float]]:
        return [(seat(n), v) for n, v in enumerate(values)]

    def test_a_steady_drop_has_an_interval_below_zero(self):
        e = ri.estimate(self.deltas([-1.0] * 40), random.Random(0))
        self.assertEqual((e.n, e.mean, e.low, e.high), (40, -1.0, -1.0, -1.0))
        self.assertEqual(ri.verdict(e), "better")

    def test_noise_around_zero_is_flat(self):
        rng = random.Random(1)
        e = ri.estimate(self.deltas([rng.gauss(0, 3) for _ in range(200)]), random.Random(0))
        self.assertLess(e.low, e.mean)
        self.assertLess(e.mean, e.high)
        self.assertEqual(ri.verdict(e), "flat")

    def test_seats_of_one_block_are_resampled_together(self):
        # Two blocks, one all +1 and one all -1: every resample is all +1, all -1 or a mix, so the interval spans both.
        deltas = [(seat(n, block="up"), 1.0) for n in range(5)] + [(seat(n + 5, block="down"), -1.0) for n in range(5)]
        ri.FEWEST_BLOCKS, saved = 2, ri.FEWEST_BLOCKS
        try:
            e = ri.estimate(deltas, random.Random(0))
        finally:
            ri.FEWEST_BLOCKS = saved
        self.assertEqual((e.low, e.high), (-1.0, 1.0))

    def test_too_few_blocks_give_no_estimate(self):
        self.assertIsNone(ri.estimate(self.deltas([1.0] * 5), random.Random(0)))

    def test_win_improves_upward(self):
        e = ri.Estimate(50, 5.0, 1.0, 9.0, 0.01)
        self.assertEqual((ri.verdict(e), ri.verdict(e, lower_is_better=False)), ("worse", "better"))


class Multiplicity(unittest.TestCase):
    def test_benjamini_hochberg_keeps_the_ranks_under_their_line(self):
        self.assertEqual(ri.surviving([0.001, 0.2, 0.9]), 1)
        self.assertEqual(ri.surviving([0.03, 0.02, 0.01]), 3)
        self.assertEqual(ri.surviving([0.3, 0.6]), 0)


def flat_rows(count: int) -> list[ri.Row]:
    flat = ri.Estimate(100, 0.0, -1.0, 1.0, 0.5)
    return [ri.Row(f"model{n}", 100, {key: flat for key in ri.COLUMNS + ri.EXTRA}) for n in range(count)]


class Figures(unittest.TestCase):
    def test_both_figures_are_well_formed_svg(self):
        rows = flat_rows(2)
        rows.append(ri.Row("opus all", 3, {key: None for key in ri.COLUMNS + ri.EXTRA}))
        for figure in (ri.by_round_figure(rows), ri.config_figure([ri.Row("opus high", r.seats, r.estimates) for r in rows])):
            self.assertEqual(ET.fromstring(figure).tag, "{http://www.w3.org/2000/svg}svg")


class Load(unittest.TestCase):
    def test_reads_seats_rounds_and_self_shot_opportunities(self):
        public = lines(A1, B2, A3)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            db = sqlite3.connect(root / "buckshot.sqlite")
            db.executescript(
                """CREATE TABLE source_files (path TEXT, match_id TEXT);
                   CREATE TABLE source_records (path TEXT, raw TEXT, current INTEGER);
                   CREATE TABLE match_seats (match_id TEXT, player TEXT, cash INTEGER)"""
            )
            db.execute("INSERT INTO source_files VALUES ('t/m1/events.jsonl', 'm1')")
            db.execute("INSERT INTO source_records VALUES ('t/m1/events.jsonl', ?, 1)", (event("A", 0, public),))
            db.executemany("INSERT INTO match_seats VALUES ('m1', ?, ?)", [("A", 150_000), ("B", 75_000)])
            db.commit()
            knowledge = sqlite3.connect(root / "knowledge.sqlite")
            knowledge.executescript(
                """CREATE TABLE matches (match_id TEXT, status TEXT, seed_block_id TEXT);
                   CREATE TABLE players (match_id TEXT, player TEXT, model TEXT, effort TEXT);
                   CREATE TABLE decisions (match_id TEXT, ordinal INTEGER, player TEXT, by_whom TEXT, round INTEGER, remaining INTEGER, choice TEXT)"""
            )
            knowledge.execute("INSERT INTO matches VALUES ('m1', 'completed', 'block1')")
            knowledge.executemany("INSERT INTO players VALUES ('m1', ?, ?, ?)", [("A", "opus", "high"), ("B", "sol", "low")])
            knowledge.executemany("INSERT INTO decisions VALUES ('m1', ?, ?, 'agent', ?, 3, ?)", [(0, "A", 0, "Shoot Player B"), (1, "B", 1, "Use Beer")])
            knowledge.commit()
            regret = sqlite3.connect(root / "regret.sqlite")
            regret.execute(
                """CREATE TABLE regret (match_id TEXT, ordinal INTEGER, evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT, samples INTEGER, status TEXT, regret INTEGER)"""
            )
            regret.executemany("INSERT INTO regret VALUES ('m1', ?, 'e', 6, 20000, 'static', 0, 'searched', ?)", [(0, 30_000), (1, 0)])
            regret.commit()
            mistakes = sqlite3.connect(root / "mistakes.sqlite")
            mistakes.execute("CREATE TABLE opportunities (match_id TEXT, ordinal INTEGER, player TEXT, type TEXT, outcome TEXT, source TEXT)")
            mistakes.execute("INSERT INTO opportunities VALUES ('m1', 0, 'A', 'self_on_live', 'mistake', 'public')")
            mistakes.commit()
            moves = ri.load_moves(root / "regret.sqlite", root / "knowledge.sqlite", root / "mistakes.sqlite", str(root / "buckshot.sqlite"))
        first, second = sorted(moves, key=lambda m: m.round)
        self.assertEqual((first.seat.model, first.seat.wins, first.seat.level, first.seat.block), ("opus", frozenset({1, 3}), True, "block1"))
        self.assertEqual((first.round, first.shot, first.shells_left, first.regret, first.mistake), (1, True, 3, 30_000, True))
        self.assertEqual((second.seat.model, second.seat.wins, second.round, second.shot, second.mistake), ("sol", frozenset({2}), 2, False, None))


if __name__ == "__main__":
    unittest.main()
