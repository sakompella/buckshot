"""Tests for the regret-depth sample and summary: python3 -m unittest discover -s tools/arena/analysis"""

import json
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

import regret_depth as rd
from testdb import KNOWLEDGE, REGRET, database, insert


def pair(shells_left=2, shot=True, model="m", regret=1.0, deep_regret=1.0, limited=False, ordinal=0):
    return rd.Pair(f"{model}-{ordinal}", ordinal, shells_left, shot, model, regret, deep_regret, 6, 8, limited, False, False, 0.0)


class Estimate(unittest.TestCase):
    def test_weights_each_stratum_by_its_size_in_the_whole_run(self):
        sample = [pair(model="a", deep_regret=0.0), pair(model="a", deep_regret=0.0), pair(model="b", deep_regret=10.0), pair(model="b", deep_regret=10.0)]
        sizes = {(2, True, "a"): 900, (2, True, "b"): 100}
        self.assertAlmostEqual(rd.estimate(sample, lambda p: p.deep_regret, sizes).mean, 1.0)

    def test_refuses_a_population_stratum_the_sample_misses_or_holds_once(self):
        sizes = {(2, True, "a"): 10, (2, True, "b"): 1_000_000}
        with self.assertRaises(ValueError):
            rd.estimate([pair(model="a", ordinal=0), pair(model="a", ordinal=1)], lambda p: p.deep_regret, sizes)
        with self.assertRaises(ValueError):
            rd.estimate([pair(model="a", ordinal=0), pair(model="a", ordinal=1), pair(model="b")], lambda p: p.deep_regret, sizes)

    def test_refuses_a_sampled_stratum_outside_the_population(self):
        with self.assertRaises(ValueError):
            rd.estimate([pair(model="a", ordinal=0), pair(model="a", ordinal=1), pair(model="b", ordinal=0), pair(model="b", ordinal=1)], lambda p: p.deep_regret, {(2, True, "a"): 10})

    def test_a_domain_across_strata_weights_by_the_domain_members_of_each_stratum(self):
        """Limited decisions are 90% of stratum a and 10% of stratum b, with regret 0 in a and 10 in b, so their true mean is (90 * 0 + 10 * 10) / 100 = 1."""
        sizes = {(2, True, "a"): 100, (2, True, "b"): 100}
        sample = [pair(model=m, ordinal=i, regret=10.0 if m == "b" else 0.0, limited=i < (9 if m == "a" else 1)) for m in "ab" for i in range(10)]
        limited = rd.estimate(sample, lambda p: p.regret * p.limited, sizes, domain_size=100).mean
        self.assertAlmostEqual(limited, 1.0)


def values(*scores):
    return json.dumps([{"label": f"move {i}", "score": score} for i, score in enumerate(scores)])


def write_runs(directory: Path, production_rows, deep_rows, deep_evaluator="rust-1"):
    """Writes the three databases the summary reads, from their real DDL."""
    knowledge = database(directory / "knowledge.sqlite", KNOWLEDGE)
    insert(knowledge, "players", match_id="m1", player="A", model="opus")
    insert(knowledge, "decisions", match_id="m1", ordinal=0, player="A", by_whom="agent", shot="opponent", remaining=2)
    insert(knowledge, "decisions", match_id="m1", ordinal=1, player="A", by_whom="agent", shot=None, remaining=3)
    knowledge.commit()
    for name, rows, evaluator in (("regret.sqlite", production_rows, "rust-1"), ("regret-depth.sqlite", deep_rows, deep_evaluator)):
        db = database(directory / name, REGRET)
        for match_id, ordinal, max_depth, budget, values_json, best, best_score, regret, depth, limited in rows:
            insert(db, "regret", match_id=match_id, ordinal=ordinal, max_depth=max_depth, budget=budget, reload="static", status="searched",
                   values_json=values_json, best=best, best_score=best_score, regret=regret, depth=depth, limited=limited, evaluator=evaluator)
        db.commit()
    return directory / "regret-depth.sqlite", directory / "regret.sqlite", directory / "knowledge.sqlite"


class Pairs(unittest.TestCase):
    def read(self, production_rows, deep_rows):
        with tempfile.TemporaryDirectory() as directory:
            return rd.pairs(*write_runs(Path(directory), production_rows, deep_rows))

    def test_matches_each_decision_to_its_production_score_and_measures_what_a_changed_best_move_gives_up(self):
        found = self.read(
            production_rows=[("m1", 0, 6, 20000, values(500000, 400000), "move 0", 500000, 0, 6, 0), ("m1", 1, 6, 20000, values(500000, 300000), "move 0", 500000, 200000, 3, 1)],
            deep_rows=[("m1", 0, 8, 200000, values(500000, 400000), "move 0", 500000, 0, 8, 0), ("m1", 1, 8, 200000, values(300000, 450000), "move 1", 450000, 150000, 6, 1)],
        )
        self.assertEqual(
            found,
            [rd.Pair("m1", 0, 2, True, "opus", 0.0, 0.0, 6, 8, False, False, False, 0.0), rd.Pair("m1", 1, 3, False, "opus", 20.0, 15.0, 3, 6, True, True, True, 15.0)],
        )

    def test_ignores_other_settings_but_fails_on_a_deep_row_it_cannot_match(self):
        production = [("m1", 0, 6, 20000, values(1, 2), "move 1", 2, 0, 6, 0)]
        other_setting = ("m1", 1, 6, 20000, values(1, 2), "move 1", 2, 0, 6, 0)
        matched = ("m1", 0, 8, 200000, values(1, 2), "move 1", 2, 0, 8, 0)
        self.assertEqual(len(self.read(production, [matched, other_setting])), 1)
        with self.assertRaises(ValueError):
            self.read(production, [matched, ("m1", 1, 8, 200000, values(1, 2), "move 1", 2, 0, 8, 0)])

    def test_fails_when_the_deep_run_is_another_evaluator_than_production(self):
        rows = ("m1", 0, 6, 20000, values(1, 2), "move 1", 2, 0, 6, 0)
        deep = ("m1", 0, 8, 200000, values(1, 2), "move 1", 2, 0, 8, 0)
        with tempfile.TemporaryDirectory() as directory, self.assertRaisesRegex(ValueError, "different evaluators"):
            rd.pairs(*write_runs(Path(directory), [rows], [deep], deep_evaluator="bend-1"))

    def test_fails_on_a_deep_row_that_was_not_searched(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = write_runs(Path(directory), [("m1", 0, 6, 20000, values(1, 2), "move 1", 2, 0, 6, 0)], [("m1", 0, 8, 200000, values(1, 2), "move 1", 2, 0, 8, 0)])
            with closing(sqlite3.connect(paths[0])) as db, db:
                db.execute("UPDATE regret SET status = 'skipped'")
            with self.assertRaises(ValueError):
                rd.pairs(*paths)


class CheckSample(unittest.TestCase):
    def test_accepts_exactly_the_drawn_decisions(self):
        rd.check_sample([pair(ordinal=0, limited=True), pair(ordinal=1)], {("m-0", 0), ("m-1", 1)})

    def test_rejects_missing_foreign_and_repeated_decisions(self):
        sample = [pair(ordinal=0), pair(ordinal=1)]
        for expected, found in (
            ({("m-0", 0), ("m-1", 1), ("m-2", 2)}, sample),
            ({("m-0", 0)}, sample),
            ({("m-0", 0), ("m-1", 1)}, [*sample, sample[0]]),
        ):
            with self.assertRaises(ValueError):
                rd.check_sample(found, expected)


if __name__ == "__main__":
    unittest.main()
