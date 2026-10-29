"""Tests for the regret-depth sample and summary: python3 -m unittest discover -s tools/arena/analysis"""

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import regret_depth as rd


def decision(index, shells_left=2, shot=True, model="m", depth=6):
    return rd.Decision(f"match{index}", index, shells_left, shot, model, depth)


class Draw(unittest.TestCase):
    def setUp(self):
        self.decisions = [decision(i, shells_left=1 + i % 2, shot=i % 4 < 2, model="abc"[i % 3]) for i in range(600)]

    def test_takes_each_cells_quota_spread_over_the_models_and_deals_it_evenly_into_lists(self):
        lists = rd.draw(self.decisions, {(1, True): 12, (2, False): 6}, lists=3, seed=1)
        everything = [d for items in lists for d in items]
        self.assertEqual(sorted(len(items) for items in lists), [6, 6, 6])
        self.assertEqual(len({(d.match_id, d.ordinal) for d in everything}), 18)
        for cell, quota in {(1, True): 12, (2, False): 6}.items():
            chosen = [d for d in everything if (d.shells_left, d.shot) == cell]
            self.assertEqual({m: sum(d.model == m for d in chosen) for m in "abc"}, {m: quota // 3 for m in "abc"})
            for items in lists:
                self.assertEqual(sum((d.shells_left, d.shot) == cell for d in items), quota // 3)

    def test_the_same_seed_draws_the_same_sample(self):
        self.assertEqual(rd.draw(self.decisions, {(1, True): 9}, 2, seed=5), rd.draw(self.decisions, {(1, True): 9}, 2, seed=5))


def pair(shells_left=2, shot=True, model="m", regret=1.0, deep_regret=1.0):
    return rd.Pair(shells_left, shot, model, regret, deep_regret, 6, 8, False, False, False, 0.0)


class Estimate(unittest.TestCase):
    def test_weights_each_stratum_by_its_size_in_the_whole_run(self):
        sample = [pair(model="a", deep_regret=0.0), pair(model="a", deep_regret=0.0), pair(model="b", deep_regret=10.0), pair(model="b", deep_regret=10.0)]
        sizes = {(2, True, "a"): 900, (2, True, "b"): 100}
        self.assertAlmostEqual(rd.estimate(sample, lambda p: p.deep_regret, sizes).mean, 1.0)

    def test_ignores_strata_it_has_no_sample_of(self):
        sizes = {(2, True, "a"): 10, (2, True, "b"): 1_000_000}
        self.assertAlmostEqual(rd.estimate([pair(model="a", deep_regret=4.0)], lambda p: p.deep_regret, sizes).mean, 4.0)


def values(*scores):
    return json.dumps([{"label": f"move {i}", "score": score} for i, score in enumerate(scores)])


def write_runs(directory: Path, production_rows, deep_rows):
    """Writes the three databases the summary reads, with only the columns it uses."""
    knowledge = sqlite3.connect(directory / "knowledge.sqlite")
    knowledge.executescript(
        """CREATE TABLE players (match_id TEXT, player TEXT, model TEXT);
           CREATE TABLE decisions (match_id TEXT, ordinal INTEGER, player TEXT, by_whom TEXT, choice TEXT, remaining INTEGER);
           INSERT INTO players VALUES ('m1', 'A', 'opus');
           INSERT INTO decisions VALUES ('m1', 0, 'A', 'agent', 'Shoot player +1', 2), ('m1', 1, 'A', 'agent', 'Use beer', 3)"""
    )
    knowledge.commit()
    for name, rows in (("regret.sqlite", production_rows), ("regret-depth.sqlite", deep_rows)):
        db = sqlite3.connect(directory / name)
        db.execute("CREATE TABLE regret (match_id TEXT, ordinal INTEGER, max_depth INTEGER, budget INTEGER, reload TEXT, status TEXT, values_json TEXT, best TEXT, best_score INTEGER, regret INTEGER, depth INTEGER, limited INTEGER)")
        db.executemany("INSERT INTO regret VALUES (?, ?, ?, ?, 'static', 'searched', ?, ?, ?, ?, ?, ?)", rows)
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
            [rd.Pair(2, True, "opus", 0.0, 0.0, 6, 8, False, False, False, 0.0), rd.Pair(3, False, "opus", 20.0, 15.0, 3, 6, True, True, True, 15.0)],
        )

    def test_leaves_out_other_settings_and_decisions_the_production_run_has_not_scored(self):
        found = self.read(
            production_rows=[("m1", 0, 6, 20000, values(1, 2), "move 1", 2, 0, 6, 0)],
            deep_rows=[("m1", 1, 8, 200000, values(1, 2), "move 1", 2, 0, 8, 0), ("m1", 0, 6, 20000, values(1, 2), "move 1", 2, 0, 6, 0)],
        )
        self.assertEqual(found, [])


if __name__ == "__main__":
    unittest.main()
