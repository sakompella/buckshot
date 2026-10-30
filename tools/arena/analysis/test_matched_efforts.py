"""Tests for the matched effort comparison: python3 -m unittest discover -s tools/arena/analysis"""

import random
import sqlite3
import unittest
from datetime import datetime, timedelta, timezone

import matched_efforts as me
from matched_efforts import Config, Seat

HIGH, MED = Config("opus", "high", "cpa"), Config("opus", "medium", "cpa")
EASY, HARD = Config("sol", "medium", "cpa"), Config("astra", "medium", "cpa")
NO_DRAWS = 0
CUT = me.REQUEST_CHANGE


def seat(n: int, focal: Config, opponent: Config, won: int, rounds: int = 3, seed: int = 1, position: int = 1, started: datetime = CUT) -> Seat:
    return Seat(f"m{n}", started, seed, position, focal, opponent, 1.0 if won * 2 > rounds else 0.0, tuple(i < won for i in range(rounds)) if rounds else ())


def numbered(specs) -> list[Seat]:
    return [seat(n, *spec[:3], **(spec[3] if len(spec) == 4 else {})) for n, spec in enumerate(specs)]


def only_row(seats: list[Seat], metric=me.round_metric) -> me.Row:
    (row,) = me.compare(seats, metric, {}, NO_DRAWS)
    return row


def database(*matches: tuple[str, str, str]) -> sqlite3.Connection:
    """Matches as (id, started_at, model of the second seat); the first seat is always opus."""
    db = sqlite3.connect(":memory:")
    db.executescript(
        """CREATE TABLE source_files (path TEXT, match_id TEXT);
           CREATE TABLE source_records (path TEXT, raw TEXT, current INTEGER);
           CREATE TABLE matches (id TEXT, started_at TEXT, seed INTEGER, status TEXT);
           CREATE TABLE entrants (id TEXT, model TEXT, effort TEXT, endpoint_category TEXT);
           CREATE TABLE match_seats (match_id TEXT, position INTEGER, player TEXT, win_share REAL, cash REAL, entrant_id TEXT)"""
    )
    models = {"opus", "sol", "oc/deepseek-v4.1-flash-free"}
    db.executemany("INSERT INTO entrants VALUES (?, ?, 'medium', 'cpa')", [(m, m) for m in models])
    for match, started, other in matches:
        db.execute("INSERT INTO matches VALUES (?, ?, 1, 'completed')", (match, started))
        db.executemany("INSERT INTO match_seats VALUES (?, ?, ?, ?, 0, ?)", [(match, 1, "A", 1.0, "opus"), (match, 2, "B", 0.0, other)])
    return db


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
        self.assertAlmostEqual(row.common.rate_ref, 0.5)
        self.assertAlmostEqual(row.pooled.rate, 5 * 3 / 21)

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
        self.assertIsNone(only_row(numbered([(HIGH, EASY, 3), (MED, EASY, 3)])).common)

    def test_games_between_efforts_of_one_model_are_not_external(self):
        own = Config("opus", "low", "cpa")
        self.assertEqual(me.arms(numbered([(HIGH, own, 3), (HIGH, EASY, 3)]), me.round_metric)[HIGH].keys(), {EASY})

    def test_reports_the_distinct_seeds_of_the_effort(self):
        specs = [(HIGH, EASY, 3, dict(seed=s)) for s in (1, 1, 2)] + [(MED, EASY, 0)] * 3
        self.assertEqual(only_row(numbered(specs)).pooled.seeds, 2)


class Strict(unittest.TestCase):
    def test_pairs_only_the_same_opponent_seed_and_position(self):
        specs = [
            (HIGH, EASY, 3, dict(seed=1, position=1)), (MED, EASY, 0, dict(seed=1, position=1)),
            (HIGH, EASY, 3, dict(seed=2, position=1)), (MED, EASY, 0, dict(seed=2, position=2)),
            (HIGH, HARD, 3, dict(seed=1, position=1)),
        ]
        strict = only_row(numbered(specs)).strict
        self.assertEqual((strict.pairs, strict.seeds, strict.diff), (1, 1, 1.0))

    def test_a_repeated_cell_counts_once_and_pools_its_matches(self):
        specs = [(HIGH, EASY, 3), (HIGH, EASY, 0), (MED, EASY, 0)]
        strict = only_row(numbered(specs)).strict
        self.assertEqual(strict.pairs, 1)
        self.assertAlmostEqual(strict.diff, 0.5)

    def test_counts_paired_wins_ties_and_losses_without_an_interval_when_seeds_are_few(self):
        specs = [(HIGH, EASY, 3, dict(seed=1)), (MED, EASY, 0, dict(seed=1)), (HIGH, EASY, 0, dict(seed=2)), (MED, EASY, 3, dict(seed=2)), (HIGH, EASY, 1, dict(seed=3)), (MED, EASY, 1, dict(seed=3))]
        strict = only_row(numbered(specs)).strict
        self.assertEqual((strict.up, strict.tied, strict.down, strict.interval), (1, 1, 1, None))

    def test_opponents_weigh_equally_whatever_their_number_of_pairs(self):
        specs = [(HIGH, EASY, 3, dict(seed=s)) for s in range(1, 5)] + [(MED, EASY, 0, dict(seed=s)) for s in range(1, 5)]
        specs += [(HIGH, HARD, 0, dict(seed=1)), (MED, HARD, 0, dict(seed=1))]
        self.assertAlmostEqual(only_row(numbered(specs)).strict.diff, 0.5)


class Intervals(unittest.TestCase):
    def specs(self, seeds, opponents):
        return [(f, o, 3 if f is HIGH and s % 2 else 1, dict(seed=s)) for s in seeds for o in opponents for f in (HIGH, MED)]

    def test_seeds_shared_across_opponents_count_once(self):
        # 10 seeds against 5 opponents are 10 independent units, not 50.
        opponents = [Config(f"m{i}", "medium", "cpa") for i in range(5)]
        seats = numbered(self.specs(range(10), opponents) * 2)
        row = only_row(seats)
        self.assertEqual(row.strict.seeds, 10)
        self.assertIsNone(row.strict.interval)
        self.assertIsNone(row.common.interval)

    def test_enough_seeds_give_intervals_that_cover_the_estimates(self):
        opponents = [Config(f"m{i}", "medium", "cpa") for i in range(2)]
        row = me.compare(numbered(self.specs(range(me.MIN_UNITS), opponents) * 2), me.round_metric, {}, 200)[0]
        for layer, estimate in ((row.strict, row.strict.diff), (row.common, row.common.rate - row.common.rate_ref)):
            low, high = layer.interval
            self.assertLessEqual(low, estimate)
            self.assertGreaterEqual(high, estimate)

    def test_the_same_resample_is_used_for_both_efforts(self):
        # Seeds differ widely in difficulty but high always beats medium by one round in ten: a joint resample keeps the difference exactly there.
        specs = [(f, EASY, (2 if s % 2 else 6) + (f is HIGH), dict(seed=s, rounds=10)) for s in range(me.MIN_UNITS) for f in (HIGH, MED)]
        row = me.compare(numbered(specs * 2), me.round_metric, {}, 100)[0]
        low, high = row.common.interval
        self.assertAlmostEqual(low, 0.1)
        self.assertAlmostEqual(high, 0.1)


    def test_no_interval_when_a_resample_can_leave_a_cell_empty(self):
        # Enough seeds overall, but one opponent was met under a single seed, so many resamples miss it.
        specs = [(f, EASY, 2, dict(seed=s)) for s in range(me.MIN_UNITS) for f in (HIGH, MED)] + [(f, HARD, 2, dict(seed=0)) for f in (HIGH, MED)]
        row = me.compare(numbered(specs * 2), me.round_metric, {}, 100)[0]
        self.assertEqual(row.common.opponents, 2)
        self.assertIsNone(row.common.interval)
        self.assertIsNone(row.strict.interval)


class Time(unittest.TestCase):
    def test_parses_milliseconds_and_offsets_to_the_same_instant(self):
        base = me.parse_time("2026-10-16T14:48:44Z")
        self.assertEqual(me.parse_time("2026-10-16T14:48:44.000Z"), base)
        self.assertEqual(me.parse_time("2026-10-16T14:48:44+00:00"), base)
        self.assertEqual(me.parse_time("2026-10-16T07:48:44.000-07:00"), base)
        self.assertGreater(me.parse_time("2026-10-16T14:48:44.500Z"), base)

    def test_a_time_without_an_offset_is_an_error(self):
        with self.assertRaises(ValueError):
            me.parse_time("2026-10-16T14:48:44")

    def test_since_includes_the_boundary_and_later_milliseconds_only(self):
        second = timedelta(milliseconds=1)
        seats = [seat(n, HIGH, EASY, 3, started=CUT + delta) for n, delta in enumerate((-second, timedelta(0), second))]
        self.assertEqual([s.match for s in me.since(seats, CUT)], ["m1", "m2"])

    def test_loading_reads_stored_milliseconds_as_instants(self):
        db = database(("early", "2026-10-16T14:48:43.999Z", "sol"), ("equal", "2026-10-16T14:48:44.000Z", "sol"))
        seats, _ = me.load_seats(db)
        db.close()
        self.assertEqual({s.match for s in me.since(seats, CUT)}, {"equal"})
        self.assertEqual(seats[0].started.tzinfo, timezone.utc)

    def test_chronology_counts_seats_before_and_after_the_change(self):
        seats = [seat(0, MED, EASY, 3, started=CUT - timedelta(days=1)), seat(1, HIGH, EASY, 3), seat(2, MED, EASY, 3)]
        self.assertEqual(me.chronology(seats), "External seats at medium: 1 before the change and 1 after. External seats at the other efforts: 0 before and 1 after.")


class Unscored(unittest.TestCase):
    def test_zero_round_and_unreadable_matches_do_not_enter_the_round_rates(self):
        unreadable = Seat("mx", CUT, 1, 1, HIGH, EASY, 1.0, None)
        seats = numbered([(HIGH, EASY, 0, dict(rounds=0)), (HIGH, EASY, 3)]) + [unreadable]
        self.assertEqual(len(me.arms(seats, me.round_metric)[HIGH][EASY]), 1)
        self.assertEqual(len(me.arms(seats, me.match_metric)[HIGH][EASY]), 3)

    def test_match_win_share_is_the_secondary_metric(self):
        row = only_row(numbered([(HIGH, EASY, 3)] * 2 + [(MED, EASY, 0)] * 2), me.match_metric)
        self.assertEqual(row.common.rate - row.common.rate_ref, 1.0)


class Loading(unittest.TestCase):
    def test_deepseek_matches_are_left_out_and_counted(self):
        db = database(("m1", "2026-10-20T00:00:00.000Z", "sol"), ("m2", "2026-10-20T00:00:00.000Z", "oc/deepseek-v4.1-flash-free"))
        seats, skipped = me.load_seats(db)
        db.close()
        self.assertEqual((skipped, len(seats)), (1, 2))
        self.assertTrue(all(s.rounds is None for s in seats))


if __name__ == "__main__":
    unittest.main()
