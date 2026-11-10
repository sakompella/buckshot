"""Tests for the by-round summary: python3 -m unittest discover -s tools/arena/analysis"""

import tempfile
import unittest
from pathlib import Path

import by_round
from regret import Decision
from testdb import ANALYSIS, KNOWLEDGE, database, events, insert, rounds


class LoadResults(unittest.TestCase):
    def test_pairs_each_round_winner_with_its_config(self):
        with tempfile.TemporaryDirectory() as directory:
            db = database(Path(directory) / "buckshot.sqlite", ANALYSIS)
            for player, socket in (("A", 0), ("B", 1)):
                insert(db, "match_seats", match_id="m1", position=socket + 1, player=player, socket=socket)
            events(db, "m1", *rounds(0, 1, 0))
            db.commit()
            knowledge = database(Path(directory) / "knowledge.sqlite", KNOWLEDGE)
            insert(knowledge, "matches", match_id="m1", status="completed")
            for player, model, effort in (("A", "opus", "high"), ("B", "sol", "low")):
                insert(knowledge, "players", match_id="m1", player=player, model=model, effort=effort)
            knowledge.commit()
            results = by_round.load_results(str(Path(directory) / "buckshot.sqlite"), Path(directory) / "knowledge.sqlite")
        self.assertEqual(
            sorted(results, key=lambda r: (r.round, r.model)),
            [by_round.RoundResult(m, e, n, won) for n, (opus, sol) in enumerate([(True, False), (False, True), (True, False)], 1) for m, e, won in [("opus", "high", opus), ("sol", "low", sol)]],
        )


class Table(unittest.TestCase):
    def test_gives_each_cell_its_rate_and_count(self):
        results = [by_round.RoundResult("opus", "high", 1, won) for won in (True, False, False, False)]
        decisions = [Decision("opus", "high", 3, True, 20_000 * n, False, False, 1) for n in (1, 2)]
        row = by_round.by_round(results, decisions).splitlines()[2]
        self.assertEqual(row, "| opus | high | 25.0% (4) | 3.0 (2) | - | - | - | - |")

    def test_pools_efforts_into_one_row_per_model(self):
        results = [by_round.RoundResult("opus", effort, 1, True) for effort in ("low", "high")]
        decisions = [Decision("opus", effort, 3, True, 10_000, False, False, 1) for effort in ("low", "high")]
        row = by_round.by_round(*by_round.pooled_over_efforts(results, decisions)).splitlines()[2]
        self.assertEqual(row, "| opus | all | 100.0% (2) | 1.0 (2) | - | - | - | - |")

    def test_splits_shots_from_item_moves(self):
        decisions = [Decision("opus", "high", 3, shot, 10_000 * n, False, False, 1) for shot, n in [(True, 3), (True, 5), (False, 1)]]
        row = by_round.by_move_kind(decisions).splitlines()[2]
        self.assertEqual(row, "| 1 | 3.0 (3) | 4.0 (2) | 1.0 (1) |")


if __name__ == "__main__":
    unittest.main()
