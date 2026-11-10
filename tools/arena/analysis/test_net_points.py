"""Tests for net points: python3 -m unittest discover -s tools/arena/analysis"""

import random
import tempfile
import unittest
from pathlib import Path

import net_points as np_
from testdb import ANALYSIS, KNOWLEDGE, REGRET, database, events, insert, rounds


def seat(model: str, lost: float, won: int, worst: int = 0, effort: str = "high") -> np_.Seat:
    return np_.Seat((model, effort), lost, 5, won, worst, 3)


def match(block: str, first: np_.Seat, second: np_.Seat, name: str = "m") -> np_.Match:
    return np_.Match(name, name, block, first, second)


class Arithmetic(unittest.TestCase):
    def test_net_is_the_opponents_loss_minus_ones_own_and_margin_counts_rounds(self):
        m = match("b", seat("opus", 0.4, 2), seat("sol", 1.0, 1))
        self.assertAlmostEqual(m.net, 0.6)
        self.assertEqual(m.margin, 1)

    def test_interval_of_identical_blocks_is_a_point(self):
        rows = np_.config_rows([match(str(n), seat("opus", 0.5, 1), seat("sol", 0.7, 2)) for n in range(25)], {"opus high": 10.0, "sol high": -10.0}, random.Random(1))
        opus = next(r for r in rows if r.config[0] == "opus")
        self.assertEqual(opus.lost_interval, (0.5, 0.5))
        self.assertAlmostEqual(opus.net, 0.2)


class Matchups(unittest.TestCase):
    def test_a_complete_block_averages_both_seat_orders_and_an_incomplete_one_is_dropped(self):
        complete = [match("b1", seat("a", 1.0, 2), seat("b", 0.0, 1)), match("b1", seat("b", 0.5, 1), seat("a", 0.0, 2))]
        alone = [match("b2", seat("a", 9.0, 0), seat("b", 0.0, 3))]
        (row,) = np_.matchup_rows(complete + alone, random.Random(1), minimum=1)
        self.assertEqual((row.a, row.b, row.blocks), (("a", "high"), ("b", "high"), 1))
        self.assertAlmostEqual(row.net, (-1.0 + 0.5) / 2)


class Load(unittest.TestCase):
    def build(self, directory: str, searched: dict[int, int]):
        """One match, A (opus) at position 1 and B (sol) at 2; A wins rounds 1 and 3. `searched` maps an ordinal to its regret; A decides 0 and 1, B decides 2."""
        analysis = database(Path(directory) / "buckshot.sqlite", ANALYSIS)
        for player, socket in (("A", 0), ("B", 1)):
            insert(analysis, "match_seats", match_id="m1", position=socket + 1, player=player, socket=socket)
        events(analysis, "m1", *rounds(0, 1, 0))
        analysis.commit()
        knowledge = database(Path(directory) / "knowledge.sqlite", KNOWLEDGE)
        insert(knowledge, "matches", match_id="m1", name="name1", status="completed", seed_block_id="block1")
        for player, position, model in (("A", 1, "opus"), ("B", 2, "sol")):
            insert(knowledge, "players", match_id="m1", player=player, position=position, model=model, effort="high")
        for ordinal, player in ((0, "A"), (1, "A"), (2, "B")):
            insert(knowledge, "decisions", match_id="m1", ordinal=ordinal, player=player, by_whom="agent", remaining=3, shot="opponent")
        knowledge.commit()
        out = database(Path(directory) / "regret.sqlite", REGRET)
        owners = {0: "A", 1: "A", 2: "B"}
        for ordinal, regret in searched.items():
            insert(out, "regret", match_id="m1", ordinal=ordinal, player=owners[ordinal], evaluator="e", max_depth=6, budget=20000, reload="static", samples=0, status="searched", regret=regret)
        out.commit()
        return Path(directory)

    def load(self, searched: dict[int, int]) -> np_.Loaded:
        with tempfile.TemporaryDirectory() as directory:
            root = self.build(directory, searched)
            return np_.load(str(root / "buckshot.sqlite"), root / "regret.sqlite", root / "knowledge.sqlite")

    def test_sums_each_seats_regret_in_rounds_and_keeps_its_largest_with_the_rounds_it_won(self):
        loaded = self.load({0: 100_000, 1: 250_000, 2: 40_000})
        (m,) = loaded.matches
        self.assertEqual((m.first.config, m.first.lost, m.first.worst, m.first.worst_ordinal, m.first.rounds_won), (("opus", "high"), 0.35, 250_000, 1, 2))
        self.assertEqual((m.second.config, m.second.lost, m.second.rounds_won), (("sol", "high"), 0.04, 1))
        self.assertAlmostEqual(m.net, -0.31)
        self.assertEqual(loaded.incomplete, 0)

    def test_a_match_with_an_unsearched_agent_decision_is_left_out_not_counted_as_zero(self):
        loaded = self.load({0: 100_000, 2: 40_000})
        self.assertEqual((loaded.matches, loaded.incomplete), ([], 1))


if __name__ == "__main__":
    unittest.main()
