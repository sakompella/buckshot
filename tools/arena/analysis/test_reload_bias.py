"""Tests for the reload-bias sample and summary: python3 -m unittest discover -s tools/arena/analysis"""

import json
import tempfile
import unittest
from pathlib import Path

import reload_bias as rb
from stats import draw
from testdb import KNOWLEDGE, REGRET, database, insert


def decision(index, shells_left=2, shot=True, model="m", depth=6):
    return rb.Decision(f"match{index}", index, shells_left, shot, model, depth)


class Draw(unittest.TestCase):
    def setUp(self):
        self.decisions = [decision(i, shells_left=1 + i % 2, shot=i % 4 < 2, model="abc"[i % 3]) for i in range(600)]

    def test_takes_each_cells_quota_spread_over_the_models_and_deals_it_evenly_into_lists(self):
        lists = draw(self.decisions, {(1, True, True): 12, (2, False, True): 6}, lists=3, seed=1, cell_of=rb.cell)
        everything = [d for items in lists for d in items]
        self.assertEqual(sorted(len(items) for items in lists), [6, 6, 6])
        self.assertEqual(len({(d.match_id, d.ordinal) for d in everything}), 18)
        for cell, quota in {(1, True): 12, (2, False): 6}.items():
            chosen = [d for d in everything if (d.shells_left, d.shot) == cell]
            self.assertEqual(len(chosen), quota)
            self.assertEqual({m: sum(d.model == m for d in chosen) for m in "abc"}, {m: quota // 3 for m in "abc"})
            for items in lists:
                self.assertEqual(sum((d.shells_left, d.shot) == cell for d in items), quota // 3)

    def test_a_gun_the_search_cannot_empty_is_a_cell_of_its_own(self):
        decisions = [decision(i, shells_left=5, depth=3 if i % 2 else 6) for i in range(40)]
        [chosen] = draw(decisions, {(5, True, False): 4}, lists=1, seed=1, cell_of=rb.cell)
        self.assertEqual([d.depth for d in chosen], [3, 3, 3, 3])

    def test_the_same_seed_draws_the_same_sample(self):
        self.assertEqual(draw(self.decisions, {(1, True, True): 9}, 2, seed=5, cell_of=rb.cell), draw(self.decisions, {(1, True, True): 9}, 2, seed=5, cell_of=rb.cell))


def pair(shells_left=2, shot=True, model="m", static=1.0, sampled=1.0):
    return rb.Pair(shells_left, shot, model, static, sampled, True, False, False, True)


class Estimate(unittest.TestCase):
    def test_weights_each_stratum_by_its_size_in_the_whole_run(self):
        sample = [pair(model="a", sampled=0.0), pair(model="a", sampled=0.0), pair(model="b", sampled=10.0), pair(model="b", sampled=10.0)]
        sizes = {(2, True, "a", True): 900, (2, True, "b", True): 100}
        self.assertAlmostEqual(rb.estimate(sample, lambda p: p.sampled_regret, sizes).mean, 1.0)

    def test_the_interval_is_zero_when_every_value_is_alike_and_grows_with_the_spread(self):
        sizes = {(2, True, "m", True): 10}
        flat = rb.estimate([pair(sampled=3.0)] * 4, lambda p: p.sampled_regret, sizes)
        spread = rb.estimate([pair(sampled=1.0), pair(sampled=5.0), pair(sampled=1.0), pair(sampled=5.0)], lambda p: p.sampled_regret, sizes)
        self.assertEqual(flat.half_width, 0)
        self.assertGreater(spread.half_width, 0)

    def test_ignores_strata_it_has_no_sample_of(self):
        sizes = {(2, True, "a", True): 10, (2, True, "b", True): 1_000_000}
        self.assertAlmostEqual(rb.estimate([pair(model="a", sampled=4.0)], lambda p: p.sampled_regret, sizes).mean, 4.0)


def write_runs(directory: Path, static_rows, sampled_rows):
    """Writes the three databases the summary reads, from their real DDL."""
    knowledge = database(directory / "knowledge.sqlite", KNOWLEDGE)
    insert(knowledge, "players", match_id="m1", player="A", model="opus")
    insert(knowledge, "decisions", match_id="m1", ordinal=0, player="A", by_whom="agent", shot="opponent", remaining=2)
    insert(knowledge, "decisions", match_id="m1", ordinal=1, player="A", by_whom="agent", shot=None, remaining=3)
    knowledge.commit()
    for name, rows in (("regret.sqlite", static_rows), ("reload-bias.sqlite", sampled_rows)):
        db = database(directory / name, REGRET)
        for match_id, ordinal, reload, samples, values_json, best, regret, nodes, depth in rows:
            insert(db, "regret", match_id=match_id, ordinal=ordinal, max_depth=6, budget=20000, reload=reload, samples=samples, status="searched",
                   values_json=values_json, best=best, regret=regret, nodes=nodes, depth=depth)
        db.commit()
    return directory / "reload-bias.sqlite", directory / "regret.sqlite", directory / "knowledge.sqlite"


def values(*scores):
    return json.dumps([{"label": f"move {i}", "score": score} for i, score in enumerate(scores)])


class Pairs(unittest.TestCase):
    def read(self, static_rows, sampled_rows):
        with tempfile.TemporaryDirectory() as directory:
            return rb.pairs(*write_runs(Path(directory), static_rows, sampled_rows))

    def test_matches_each_decision_to_its_static_score_and_tells_whether_a_line_reloaded(self):
        found = self.read(
            static_rows=[("m1", 0, "static", 0, values(500000, 400000), "move 0", 0, 100, 3), ("m1", 1, "static", 0, values(500000, 300000), "move 0", 200000, 100, 3)],
            sampled_rows=[("m1", 0, "sampled", 256, values(500000, 400000), "move 0", 0, 100, 3), ("m1", 1, "sampled", 256, values(500000, 450000), "move 1", 0, 100, 3)],
        )
        self.assertEqual(
            found,
            [rb.Pair(2, True, "opus", 0.0, 0.0, True, False, False, True), rb.Pair(3, False, "opus", 20.0, 0.0, True, True, True, True)],
        )

    def test_a_different_tree_is_flagged(self):
        [found] = self.read(
            static_rows=[("m1", 0, "static", 0, values(1, 2), "move 1", 0, 100, 3)],
            sampled_rows=[("m1", 0, "sampled", 256, values(1, 2), "move 1", 0, 101, 3)],
        )
        self.assertFalse(found.same_tree)

    def test_leaves_out_decisions_the_static_run_has_not_scored_and_other_sample_counts(self):
        found = self.read(
            static_rows=[("m1", 0, "static", 0, values(1, 2), "move 1", 0, 100, 3)],
            sampled_rows=[("m1", 1, "sampled", 256, values(1, 2), "move 1", 0, 100, 3), ("m1", 0, "sampled", 64, values(1, 2), "move 1", 0, 100, 3)],
        )
        self.assertEqual(found, [])


if __name__ == "__main__":
    unittest.main()
