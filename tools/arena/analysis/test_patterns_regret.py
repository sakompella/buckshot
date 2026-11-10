"""Tests for the pattern regret table: python3 -m unittest discover -s tools/arena/analysis"""

import json
import tempfile
import unittest
from pathlib import Path

import patterns_regret as pr
from testdb import KNOWLEDGE, REGRET, database, insert


def move(config="opus high", regret=0, **fields):
    defaults = {
        "shells_left": 3,
        "chamber": None,
        "source": None,
        "live_count": None,
        "sawed": False,
        "shot": None,
        "item": None,
        "stolen": False,
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
        knowledge = database(directory / "knowledge.sqlite", KNOWLEDGE)
        insert(knowledge, "matches", match_id="m", status="completed")
        for player, position in (("A", 2), ("B", 1)):
            insert(knowledge, "players", match_id="m", player=player, position=position, model="opus", effort="high")
        for ordinal, player, by_whom, shot, item, legal_items, health in decisions:
            insert(knowledge, "decisions", match_id="m", ordinal=ordinal, player=player, by_whom=by_whom, round=0, remaining=2, private_live_min=1, private_live_max=1,
                   sawed=0, shot=shot, item=item, legal_items_json=legal_items, opponent_items_json="[]", health_json=health)
        knowledge.commit()
        scored = database(directory / "regret.sqlite", REGRET)
        for ordinal, *_ in decisions:
            insert(scored, "regret", match_id="m", ordinal=ordinal, evaluator="e", max_depth=6, budget=20000, reload="static", samples=0, status="searched", regret=7)
        scored.commit()
        return directory / "regret.sqlite", directory / "knowledge.sqlite"

    def test_reads_full_health_of_the_deciding_player_and_whether_the_same_player_shoots_itself_next(self):
        def health(own, other):
            return json.dumps([{"_tag": "Unjammed", "health": own}, {"_tag": "Unjammed", "health": other}])

        with tempfile.TemporaryDirectory() as directory:
            regret_db, knowledge_db = self.build(
                Path(directory),
                [
                    (0, "A", "agent", None, "Inverter", '["Inverter"]', health(4, 3)),
                    (1, "A", "agent", "self", None, "[]", health(4, 3)),
                    (2, "B", "agent", None, None, "[]", health(2, 4)),
                    (3, "B", "forced", None, None, "[]", health(2, 4)),
                ],
            )
            moves = pr.load(regret_db, knowledge_db)
        self.assertEqual([(m.full_health, m.shoots_self_next, m.legal_items) for m in moves], [(True, True, frozenset({"Inverter"})), (True, False, frozenset()), (False, False, frozenset())])
        self.assertEqual({m.regret for m in moves}, {7})


if __name__ == "__main__":
    unittest.main()
