"""Tests for the regret summary: python3 -m unittest discover -s tools/arena/analysis"""

import tempfile
import unittest
from pathlib import Path

import regret
from testdb import KNOWLEDGE, REGRET, database, insert


def databases(directory: Path, players, decisions, scores, matches=None):
    """Writes the two derived databases the summary reads, from their real DDL."""
    knowledge = database(directory / "knowledge.sqlite", KNOWLEDGE)
    for match_id, status, disposition in matches or [("m1", "completed", None)]:
        insert(knowledge, "matches", match_id=match_id, status=status, disposition=disposition)
    for match_id, player, model, effort in players:
        insert(knowledge, "players", match_id=match_id, player=player, model=model, effort=effort)
    for match_id, ordinal, player, by_whom, shot, remaining, round in decisions:
        insert(knowledge, "decisions", match_id=match_id, ordinal=ordinal, player=player, by_whom=by_whom, shot=shot, remaining=remaining, round=round)
    knowledge.commit()
    scored = database(directory / "regret.sqlite", REGRET)
    for row in scores:
        insert(scored, "regret", **dict(zip(SCORE_COLUMNS, row)))
    scored.commit()
    return directory / "regret.sqlite", directory / "knowledge.sqlite"


SCORE_COLUMNS = ("match_id", "ordinal", "evaluator", "max_depth", "budget", "reload", "samples", "status", "regret", "exact", "limited")


def score(match, ordinal, regret_value, exact=0, status="searched", evaluator="e", limited=0, reload="static", samples=0):
    return (match, ordinal, evaluator, 6, 20000, reload, samples, status, regret_value, exact, limited)


class Load(unittest.TestCase):
    def load(self, **kwargs):
        with tempfile.TemporaryDirectory() as directory:
            return regret.load(*databases(Path(directory), **kwargs))

    def test_keeps_agent_decisions_of_completed_matches_with_their_config(self):
        loaded = self.load(
            players=[("m1", "A", "opus", "high"), ("m1", "B", "sol", "low")],
            decisions=[("m1", 0, "A", "agent", "opponent", 3, 0), ("m1", 1, "B", "agent", None, 1, 1)],
            scores=[score("m1", 0, 250000, exact=1), score("m1", 1, 0, limited=1)],
        )
        self.assertEqual(
            loaded.decisions,
            [regret.Decision("opus", "high", 3, True, 250000, True, False, 1), regret.Decision("sol", "low", 1, False, 0, False, True, 2)],
        )
        self.assertEqual((loaded.unsearched, loaded.unscored), (0, 0))

    def test_leaves_out_excluded_matches_forced_moves_and_unfinished_matches(self):
        loaded = self.load(
            players=[("m1", "A", "opus", "high"), ("m2", "A", "opus", "high"), ("m3", "A", "opus", "high")],
            decisions=[("m1", 0, "A", "agent", None, 2, 1), ("m2", 0, "A", "forced", None, 2, 1), ("m3", 0, "A", "agent", None, 2, 1)],
            scores=[score("m1", 0, 5), score("m2", 0, 0), score("m3", 0, 5)],
            matches=[("m1", "completed", "excluded"), ("m2", "completed", None), ("m3", "partial", None)],
        )
        self.assertEqual(loaded.decisions, [])

    def test_counts_unsearched_and_unscored_decisions_apart_instead_of_as_zero_regret(self):
        loaded = self.load(
            players=[("m1", "A", "opus", "high")],
            decisions=[("m1", 0, "A", "agent", None, 2, 1), ("m1", 1, "A", "agent", None, 2, 1), ("m1", 2, "A", "agent", None, 2, 1)],
            scores=[score("m1", 0, None, status="fallback"), score("m1", 1, 100)],
        )
        self.assertEqual([d.regret for d in loaded.decisions], [100])
        self.assertEqual((loaded.unsearched, loaded.unscored), (1, 1))


class RunOf(unittest.TestCase):
    def test_a_file_must_hold_exactly_one_run(self):
        decisions = [("m1", 0, "A", "agent", None, 2, 1)]
        with tempfile.TemporaryDirectory() as directory:
            path, _ = databases(Path(directory), [("m1", "A", "opus", "high")], decisions, [score("m1", 0, 9, reload="sampled", samples=256)])
            self.assertEqual(regret.run_of(path), regret.Run("e", 6, 20000, "sampled", 256))
        for second in (score("m1", 0, 1), score("m1", 0, 9, evaluator="new", reload="sampled", samples=256)):
            with tempfile.TemporaryDirectory() as directory, self.assertRaises(SystemExit):
                regret.load(*databases(Path(directory), [("m1", "A", "opus", "high")], decisions, [score("m1", 0, 9, reload="sampled", samples=256), second]))


class Summary(unittest.TestCase):
    def test_mean_tail_and_exact_share(self):
        rows = [regret.Decision("m", "e", 1, True, value, exact, False, 1) for value, exact in [(0, True), (0, False), (0, False), (0, False), (100000, False)]]
        summary = regret.summarise(rows)
        self.assertEqual((summary.count, summary.exact), (5, 0.2))
        self.assertAlmostEqual(summary.mean, 20000)
        self.assertAlmostEqual(summary.p90, 60000)


if __name__ == "__main__":
    unittest.main()
