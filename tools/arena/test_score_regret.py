import sqlite3
import tempfile
import unittest
from pathlib import Path

import score_regret as s

GROUP = (s.EVALUATOR, 7, 50_000_000, "sampled", 256)


def source() -> sqlite3.Connection:
    db = sqlite3.connect(":memory:")
    db.execute(
        "CREATE TABLE matches (id TEXT, name TEXT, replay_status TEXT, manifest_json TEXT)"
    )
    db.execute(
        "CREATE TABLE decisions (match_id TEXT, ordinal INTEGER, by_whom TEXT, legal_json TEXT)"
    )
    db.executemany(
        "INSERT INTO matches VALUES (?, ?, ?, ?)",
        [
            ("a", "m-a", "validated", "{}"),
            ("b", "m-b", "validated", "{}"),
            ("c", "m-c", "failed", "{}"),
        ],
    )
    db.executemany(
        "INSERT INTO decisions VALUES (?, ?, ?, ?)",
        [
            ("a", 0, "agent", '["x", "y"]'),
            ("a", 1, "agent", '["x"]'),  # a one-move menu is no choice
            ("a", 2, "engine", '["x", "y"]'),
            ("a", 3, "agent", '["x", "y"]'),
            ("b", 0, "agent", '["x", "y"]'),
            ("c", 0, "agent", '["x", "y"]'),  # the replay did not validate
        ],
    )
    return db


def scored(*keys: tuple[str, int]) -> sqlite3.Connection:
    out = sqlite3.connect(":memory:")
    out.execute(s.CREATE_REGRET)
    for match, ordinal in keys:
        out.execute(
            "INSERT INTO regret (match_id, ordinal, evaluator, max_depth, budget, reload, samples) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (match, ordinal, *GROUP),
        )
    return out


class Wanted(unittest.TestCase):
    def test_agent_choices_of_validated_matches_without_a_row(self):
        todo = s.wanted(source(), scored(("a", 0)), GROUP, None, None)
        self.assertEqual(todo, [("a", 3), ("b", 0)])

    def test_matches_and_decisions_narrow_it(self):
        db, out = source(), scored()
        self.assertEqual(s.wanted(db, out, GROUP, {"m-b"}, None), [("b", 0)])
        self.assertEqual(s.wanted(db, out, GROUP, None, {("a", 3)}), [("a", 3)])

    def test_a_named_decision_that_is_no_agent_choice_stops(self):
        with self.assertRaises(SystemExit):
            s.wanted(source(), scored(), GROUP, None, {("a", 1)})


class OneRun(unittest.TestCase):
    def test_a_file_holding_another_run_stops_before_scoring(self):
        path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "regret.sqlite"
        s.open_out(path, GROUP).close()
        other = (*GROUP[:4], 64)
        with sqlite3.connect(path) as db:
            db.execute(
                "INSERT INTO regret (match_id, ordinal, evaluator, max_depth, budget, reload, samples) VALUES ('a', 0, ?, ?, ?, ?, ?)",
                other,
            )
        with self.assertRaises(SystemExit):
            s.open_out(path, GROUP)
        s.open_out(path, other).close()


class DeclaredMemory(unittest.TestCase):
    def test_grows_with_threads_and_budget_and_exceeds_a_budget_when_unbounded(self):
        small = s.declared_memory(s.Settings(budget=1_000_000, threads=1))
        self.assertGreater(
            s.declared_memory(s.Settings(budget=1_000_000, threads=2)), small
        )
        self.assertGreater(
            s.declared_memory(s.Settings(budget=2_000_000, threads=1)), small
        )
        self.assertGreater(
            s.declared_memory(s.Settings(budget=10**12, threads=1)), 1 << 40
        )


if __name__ == "__main__":
    unittest.main()
