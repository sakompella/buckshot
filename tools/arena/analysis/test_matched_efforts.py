"""Tests for the matched effort comparison: python3 -m unittest discover -s tools/arena/analysis"""

import random
import sqlite3
import unittest

import matched_efforts as me
from matched_efforts import Config, Seat

HIGH, MED = Config("opus", "high", "cpa"), Config("opus", "medium", "cpa")
EASY, HARD = Config("sol", "medium", "cpa"), Config("astra", "medium", "cpa")
NO_DRAWS = 0


def seat(n: int, focal: Config, opponent: Config, won: int, rounds: int = 3, seed: int = 1, position: int = 1, code: str = "c1", block: str | None = None) -> Seat:
    return Seat(f"m{n}", block or f"b{n}", code, seed, position, focal, opponent, 1.0 if won * 2 > rounds else 0.0, tuple(i < won for i in range(rounds)) if rounds else ())


def numbered(specs) -> list[Seat]:
    return [seat(n, *spec[:3], **(spec[3] if len(spec) == 4 else {})) for n, spec in enumerate(specs)]


def only_row(seats: list[Seat], metric=me.round_metric) -> me.Row:
    (row,) = me.compare(seats, metric, {}, NO_DRAWS)
    return row


class Matching(unittest.TestCase):
    def test_unequal_opponent_schedules_can_reverse_the_pooled_difference(self):
        # High mostly met the easy opponent, medium mostly the hard one; against each opponent medium is the better one.
        specs = [(HIGH, EASY, 2)] * 8 + [(HIGH, HARD, 0)] * 2 + [(MED, EASY, 3)] * 2 + [(MED, HARD, 1)] * 8
        row = only_row(numbered(specs))
        self.assertGreater(row.pooled.rate, row.pooled.rate_ref)
        self.assertLess(row.common.rate, row.common.rate_ref)
        self.assertEqual((row.common.opponents, row.common.n, row.common.n_ref), (2, 10, 10))

    def test_equal_config_weights_ignore_how_often_each_opponent_was_met(self):
        specs = [(HIGH, EASY, 3)] * 5 + [(HIGH, HARD, 0)] * 2 + [(MED, EASY, 3)] * 2 + [(MED, HARD, 0)] * 2
        row = only_row(numbered(specs))
        self.assertAlmostEqual(row.common.rate, 0.5)
        self.assertAlmostEqual(row.common.empirical, 5 * 3 / 21)
        self.assertAlmostEqual(row.common.rate_ref, 0.5)

    def test_an_opponent_one_effort_never_met_is_outside_the_support_not_a_zero(self):
        specs = [(HIGH, EASY, 3)] * 2 + [(HIGH, HARD, 0)] * 2 + [(MED, EASY, 3)] * 2
        row = only_row(numbered(specs))
        self.assertEqual(row.common.opponents, 1)
        self.assertEqual(row.common.rate, 1.0)
        self.assertEqual(row.common.outside, 2)

    def test_no_common_opponent_gives_no_layer(self):
        row = only_row(numbered([(HIGH, EASY, 3)] * 2 + [(MED, HARD, 0)] * 2))
        self.assertIsNone(row.common)
        self.assertIsNone(row.strict)
        self.assertIsNotNone(row.pooled)

    def test_a_single_match_per_cell_is_too_thin_for_the_common_support(self):
        row = only_row(numbered([(HIGH, EASY, 3), (MED, EASY, 3)]))
        self.assertIsNone(row.common)

    def test_games_between_efforts_of_one_model_are_not_external(self):
        own = Config("opus", "low", "cpa")
        self.assertEqual(me.arms(numbered([(HIGH, own, 3), (HIGH, EASY, 3)]), me.round_metric)[HIGH].keys(), {EASY})


class Strict(unittest.TestCase):
    def test_pairs_only_the_same_opponent_seed_position_and_code(self):
        specs = [
            (HIGH, EASY, 3, dict(seed=1, position=1)), (MED, EASY, 0, dict(seed=1, position=1)),
            (HIGH, EASY, 3, dict(seed=2, position=1)), (MED, EASY, 0, dict(seed=2, position=2)),
            (HIGH, EASY, 3, dict(seed=3, position=1, code="c2")), (MED, EASY, 0, dict(seed=3, position=1)),
            (HIGH, HARD, 3, dict(seed=1, position=1)),
        ]
        row = only_row(numbered(specs))
        self.assertEqual((row.strict_code.pairs, row.strict_code.seeds, row.strict_code.diff), (1, 1, 1.0))
        self.assertEqual((row.strict.pairs, row.strict.seeds), (2, 2))

    def test_a_repeated_cell_counts_once_and_pools_its_matches(self):
        specs = [(HIGH, EASY, 3, dict(block="x")), (HIGH, EASY, 0, dict(block="y")), (MED, EASY, 0, dict(block="z"))]
        row = only_row(numbered(specs))
        self.assertEqual(row.strict.pairs, 1)
        self.assertAlmostEqual(row.strict.diff, 0.5)

    def test_counts_paired_wins_ties_and_losses_without_an_interval_when_blocks_are_few(self):
        specs = [(HIGH, EASY, 3, dict(seed=1)), (MED, EASY, 0, dict(seed=1)), (HIGH, EASY, 0, dict(seed=2)), (MED, EASY, 3, dict(seed=2)), (HIGH, EASY, 1, dict(seed=3)), (MED, EASY, 1, dict(seed=3))]
        strict = only_row(numbered(specs)).strict
        self.assertEqual((strict.up, strict.tied, strict.down, strict.interval), (1, 1, 1, None))

    def test_opponents_weigh_equally_whatever_their_number_of_pairs(self):
        specs = [(HIGH, EASY, 3, dict(seed=s)) for s in range(1, 5)] + [(MED, EASY, 0, dict(seed=s)) for s in range(1, 5)]
        specs += [(HIGH, HARD, 0, dict(seed=1)), (MED, HARD, 0, dict(seed=1))]
        self.assertAlmostEqual(only_row(numbered(specs)).strict.diff, 0.5)

    def test_an_interval_appears_with_enough_independent_seeds_and_covers_the_estimate(self):
        seeds = range(me.MIN_UNITS)
        specs = [(f, EASY, 3 if f is HIGH and s % 2 else 1, dict(seed=s)) for s in seeds for f in (HIGH, MED)]
        strict = me.strict(*[me.arms(numbered(specs), me.round_metric)[f] for f in (HIGH, MED)], False, random.Random(0), 200)
        low, high = strict.interval
        self.assertLessEqual(low, strict.diff)
        self.assertGreaterEqual(high, strict.diff)


class Unscored(unittest.TestCase):
    def test_zero_round_and_unreadable_matches_do_not_enter_the_round_rates(self):
        unreadable = Seat("mx", "bx", "c1", 1, 1, HIGH, EASY, 1.0, None)
        seats = numbered([(HIGH, EASY, 0, dict(rounds=0)), (HIGH, EASY, 3)]) + [unreadable]
        units = me.arms(seats, me.round_metric)[HIGH][EASY]
        self.assertEqual(len(units), 1)
        self.assertEqual(len(me.arms(seats, me.match_metric)[HIGH][EASY]), 3)

    def test_match_win_share_is_the_secondary_metric(self):
        row = only_row(numbered([(HIGH, EASY, 3)] * 2 + [(MED, EASY, 0)] * 2), me.match_metric)
        self.assertEqual(row.common.rate - row.common.rate_ref, 1.0)

    def test_standard_mixes_each_sum_to_one(self):
        support = {EASY, HARD, Config("sol", "high", "cpa")}
        for mix in me.MIXES.values():
            self.assertAlmostEqual(sum(mix(support).values()), 1.0)
        self.assertEqual(me.medium_opponents({Config("sol", "high", "cpa")}), {})


class Loading(unittest.TestCase):
    def test_deepseek_matches_are_left_out_and_counted(self):
        db = sqlite3.connect(":memory:")
        db.executescript(
            """CREATE TABLE source_files (path TEXT, match_id TEXT);
               CREATE TABLE source_records (path TEXT, raw TEXT, current INTEGER);
               CREATE TABLE matches (id TEXT, seed_block_id TEXT, code_hash TEXT, seed INTEGER, status TEXT);
               CREATE TABLE entrants (id TEXT, model TEXT, effort TEXT, endpoint_category TEXT);
               CREATE TABLE match_seats (match_id TEXT, position INTEGER, player TEXT, win_share REAL, cash REAL, entrant_id TEXT)"""
        )
        db.executemany("INSERT INTO entrants VALUES (?, ?, 'medium', 'cpa')", [("e1", "opus"), ("e2", "sol"), ("e3", "oc/deepseek-v4.1-flash-free")])
        for match, other in (("m1", "e2"), ("m2", "e3")):
            db.execute("INSERT INTO matches VALUES (?, 'b', 'c', 1, 'completed')", (match,))
            db.executemany("INSERT INTO match_seats VALUES (?, ?, ?, ?, 0, ?)", [(match, 1, "A", 1.0, "e1"), (match, 2, "B", 0.0, other)])
        seats, skipped = me.load_seats(db)
        db.close()
        self.assertEqual((skipped, len(seats)), (1, 2))
        self.assertTrue(all(s.rounds is None for s in seats))


if __name__ == "__main__":
    unittest.main()
