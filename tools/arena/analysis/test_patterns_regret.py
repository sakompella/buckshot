"""Tests for the pattern regret table: python3 -m unittest discover -s tools/arena/analysis"""

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import patterns_regret as pr


def move(config="opus high", regret=0, **fields):
    defaults = {
        "shells_left": 3,
        "chamber": None,
        "source": None,
        "live_count": None,
        "sawed": False,
        "shot": None,
        "item": None,
        "legal_items": frozenset(),
        "opponent_items": frozenset(),
        "full_health": False,
        "shoots_self_next": False,
    }
    return pr.Move(config, regret, **{**defaults, **fields})


class Evaluate(unittest.TestCase):
    pattern = pr.Pattern("p", lambda m: m.shot is not None, lambda m: m.shot == "self")

    def test_compares_matches_with_the_other_applicable_decisions(self):
        moves = [move(regret=30, shot="self"), move(regret=10, shot="opponent"), move(regret=20, shot="opponent"), move(regret=999)]
        row = pr.evaluate(self.pattern, moves)
        self.assertEqual((row.matched, row.matched_mean, row.others, row.others_mean), (1, 30, 2, 15))

    def test_same_config_baseline_ignores_other_configs_mix(self):
        moves = [
            move("a", 10, shot="self"),
            move("a", 0, shot="opponent"),
            move("b", 40, shot="opponent"),
            move("b", 40, shot="opponent"),
        ]
        row = pr.evaluate(self.pattern, moves)
        self.assertEqual((row.others_mean, row.others_mean_same_configs), (80 / 3, 0))

    def test_no_row_without_both_sides(self):
        self.assertIsNone(pr.evaluate(self.pattern, [move(shot="self")]))
        self.assertIsNone(pr.evaluate(self.pattern, [move(shot="opponent")]))


class Load(unittest.TestCase):
    def build(self, directory: Path, decisions):
        knowledge = sqlite3.connect(directory / "knowledge.sqlite")
        knowledge.executescript(
            """CREATE TABLE matches (match_id TEXT, status TEXT);
               CREATE TABLE players (match_id TEXT, player TEXT, model TEXT, effort TEXT);
               CREATE TABLE decisions (match_id TEXT, ordinal INTEGER, player TEXT, by_whom TEXT, round INTEGER, remaining INTEGER, chamber TEXT, source TEXT,
                 private_live_min INTEGER, private_live_max INTEGER, sawed INTEGER, shot TEXT, item TEXT, legal_items_json TEXT, opponent_items_json TEXT, health_json TEXT)"""
        )
        knowledge.execute("INSERT INTO matches VALUES ('m', 'completed')")
        knowledge.executemany("INSERT INTO players VALUES ('m', ?, 'opus', 'high')", [("A",), ("B",)])
        knowledge.executemany("INSERT INTO decisions VALUES ('m', ?, ?, ?, 0, 2, NULL, NULL, 1, 1, 0, ?, ?, ?, '[]', ?)", decisions)
        knowledge.commit()
        scored = sqlite3.connect(directory / "regret.sqlite")
        scored.execute("CREATE TABLE regret (match_id TEXT, ordinal INTEGER, max_depth INTEGER, budget INTEGER, status TEXT, regret INTEGER)")
        scored.executemany("INSERT INTO regret VALUES ('m', ?, 6, 20000, 'searched', 7)", [(d[0],) for d in decisions])
        scored.commit()
        return directory / "regret.sqlite", directory / "knowledge.sqlite"

    def test_reads_full_health_and_whether_the_same_player_shoots_itself_next(self):
        def health(a, b):
            return json.dumps([{"_tag": "Unjammed", "health": a}, {"_tag": "Unjammed", "health": b}])

        with tempfile.TemporaryDirectory() as directory:
            regret_db, knowledge_db = self.build(
                Path(directory),
                [
                    (0, "A", "agent", None, "Inverter", '["Inverter"]', health(4, 3)),
                    (1, "A", "agent", "self", None, "[]", health(4, 3)),
                    (2, "B", "agent", None, None, "[]", health(2, 3)),
                    (3, "B", "forced", None, None, "[]", health(2, 3)),
                ],
            )
            moves = pr.load(regret_db, knowledge_db, 6, 20000)
        self.assertEqual([(m.full_health, m.shoots_self_next, m.legal_items) for m in moves], [(True, True, frozenset({"Inverter"})), (True, False, frozenset()), (False, False, frozenset())])
        self.assertEqual({m.regret for m in moves}, {7})


if __name__ == "__main__":
    unittest.main()
