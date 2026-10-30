"""Tests for the regret summary: python3 -m unittest discover -s tools/arena/analysis"""

import sqlite3
import tempfile
import unittest
from pathlib import Path

import regret


def databases(directory: Path, players, decisions, scores, matches=None):
    """Writes the two derived databases the summary reads, with only the columns it uses."""
    knowledge = sqlite3.connect(directory / "knowledge.sqlite")
    knowledge.executescript(
        """CREATE TABLE matches (match_id TEXT, status TEXT);
           CREATE TABLE players (match_id TEXT, player TEXT, model TEXT, effort TEXT);
           CREATE TABLE decisions (match_id TEXT, ordinal INTEGER, player TEXT, by_whom TEXT, choice TEXT, remaining INTEGER, round INTEGER)"""
    )
    knowledge.executemany("INSERT INTO matches VALUES (?, ?)", matches or [("m1", "completed")])
    knowledge.executemany("INSERT INTO players VALUES (?, ?, ?, ?)", players)
    knowledge.executemany("INSERT INTO decisions VALUES (?, ?, ?, ?, ?, ?, ?)", decisions)
    knowledge.commit()
    scored = sqlite3.connect(directory / "regret.sqlite")
    scored.execute(
        "CREATE TABLE regret (match_id TEXT, ordinal INTEGER, evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT, samples INTEGER, status TEXT, regret INTEGER, exact INTEGER, limited INTEGER)"
    )
    scored.executemany("INSERT INTO regret VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", scores)
    scored.commit()
    return directory / "regret.sqlite", directory / "knowledge.sqlite"


def score(match, ordinal, regret_value, exact=0, status="searched", evaluator="e", limited=0, reload="static", samples=0):
    return (match, ordinal, evaluator, 6, 20000, reload, samples, status, regret_value, exact, limited)


class Percentile(unittest.TestCase):
    def test_interpolates_between_ranks(self):
        self.assertEqual(regret.percentile([0, 10, 20, 30, 40], 0.9), 36)

    def test_one_value(self):
        self.assertEqual(regret.percentile([7], 0.9), 7)


class Load(unittest.TestCase):
    def load(self, **kwargs):
        with tempfile.TemporaryDirectory() as directory:
            return regret.load(*databases(Path(directory), **kwargs), depth=6, budget=20000)

    def test_keeps_agent_decisions_of_completed_matches_with_their_config(self):
        loaded = self.load(
            players=[("m1", "A", "opus", "high"), ("m1", "B", "sol", "low")],
            decisions=[("m1", 0, "A", "agent", "Shoot player +1", 3, 0), ("m1", 1, "B", "agent", "Use beer", 1, 1)],
            scores=[score("m1", 0, 250000, exact=1), score("m1", 1, 0, limited=1)],
        )
        self.assertEqual(
            loaded.decisions,
            [regret.Decision("opus", "high", 3, True, 250000, True, False, 1), regret.Decision("sol", "low", 1, False, 0, False, True, 2)],
        )
        self.assertEqual((loaded.unsearched, loaded.unscored), (0, 0))

    def test_leaves_out_deepseek_matches_forced_moves_and_unfinished_matches(self):
        loaded = self.load(
            players=[("m1", "A", "opus", "high"), ("m1", "B", "deepseek-v4", "medium"), ("m2", "A", "opus", "high"), ("m3", "A", "opus", "high")],
            decisions=[("m1", 0, "A", "agent", "Use beer", 2, 1), ("m2", 0, "A", "forced", "Grab an item", 2, 1), ("m3", 0, "A", "agent", "Use beer", 2, 1)],
            scores=[score("m1", 0, 5), score("m2", 0, 0), score("m3", 0, 5)],
            matches=[("m1", "completed"), ("m2", "completed"), ("m3", "partial")],
        )
        self.assertEqual(loaded.decisions, [])

    def test_counts_unsearched_and_unscored_decisions_apart_instead_of_as_zero_regret(self):
        loaded = self.load(
            players=[("m1", "A", "opus", "high")],
            decisions=[("m1", 0, "A", "agent", "Use beer", 2, 1), ("m1", 1, "A", "agent", "Use beer", 2, 1), ("m1", 2, "A", "agent", "Use beer", 2, 1)],
            scores=[score("m1", 0, None, status="fallback"), score("m1", 1, 100)],
        )
        self.assertEqual([d.regret for d in loaded.decisions], [100])
        self.assertEqual((loaded.unsearched, loaded.unscored), (1, 1))

    def test_refuses_to_mix_evaluators(self):
        with self.assertRaises(SystemExit):
            self.load(
                players=[("m1", "A", "opus", "high")],
                decisions=[("m1", 0, "A", "agent", "Use beer", 2, 1), ("m1", 1, "A", "agent", "Use beer", 2, 1)],
                scores=[score("m1", 0, 1, evaluator="old"), score("m1", 1, 1, evaluator="new")],
            )

    def test_mixes_evaluators_only_when_recorded_as_equivalent(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = databases(
                Path(directory),
                players=[("m1", "A", "opus", "high")],
                decisions=[("m1", 0, "A", "agent", "Use beer", 2, 1), ("m1", 1, "A", "agent", "Use beer", 2, 1)],
                scores=[score("m1", 0, 1, evaluator="old"), score("m1", 1, 1, evaluator="new")],
            )
            scored = sqlite3.connect(paths[0])
            scored.execute("CREATE TABLE evaluator_equivalence (evaluator_a TEXT, evaluator_b TEXT, compared_decisions INTEGER, differing_decisions INTEGER, note TEXT)")
            scored.execute("INSERT INTO evaluator_equivalence VALUES ('old', 'new', 100, 1, '')")
            scored.commit()
            with self.assertRaises(SystemExit):
                regret.load(*paths, depth=6, budget=20000)
            scored.execute("UPDATE evaluator_equivalence SET differing_decisions = 0")
            scored.commit()
            self.assertEqual(len(regret.load(*paths, depth=6, budget=20000).decisions), 2)
            scored.close()

    def test_reads_one_reload_rule(self):
        loaded = self.load(
            players=[("m1", "A", "opus", "high")],
            decisions=[("m1", 0, "A", "agent", "Use beer", 2, 1), ("m1", 1, "A", "agent", "Use beer", 2, 1)],
            scores=[score("m1", 0, 1), score("m1", 0, 7, reload="expected-deal"), score("m1", 0, 9, reload="sampled", samples=256)],
        )
        self.assertEqual([d.regret for d in loaded.decisions], [1])
        self.assertEqual(loaded.unscored, 1)


class RunSamples(unittest.TestCase):
    def test_a_sampled_run_defaults_to_the_scripts_count_and_other_rules_take_none(self):
        self.assertEqual((regret.run_samples("sampled", None), regret.run_samples("sampled", 64), regret.run_samples("static", None)), (256, 64, 0))
        with self.assertRaises(SystemExit):
            regret.run_samples("expected-deal", 64)
        with self.assertRaises(SystemExit):
            regret.run_samples("sampled", 0)


class Summary(unittest.TestCase):
    def test_mean_tail_and_exact_share(self):
        rows = [regret.Decision("m", "e", 1, True, value, exact, False, 1) for value, exact in [(0, True), (0, False), (0, False), (0, False), (100000, False)]]
        summary = regret.summarise(rows)
        self.assertEqual((summary.count, summary.exact), (5, 0.2))
        self.assertAlmostEqual(summary.mean, 20000)
        self.assertAlmostEqual(summary.p90, 60000)


if __name__ == "__main__":
    unittest.main()
