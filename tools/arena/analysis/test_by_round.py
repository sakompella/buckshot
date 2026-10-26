"""Tests for the by-round summary: python3 -m unittest discover -s tools/arena/analysis"""

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import by_round
from regret import Decision


def lines(*wins: str | None) -> list[str]:
    """Public lines of a match: each round begins and, unless None, names its winner."""
    out = []
    for n, win in enumerate(wins, 1):
        out.append(f"Round {n} begins. Everyone has 3 health; Player A starts.")
        out += ["Player B shot Player A: live, 1 damage, 0 health left."] + ([win] if win else [])
    return out


A1, B2, A3 = "Player A wins the round and $70,000.", "Player B wins the round and $75,000.", "Player A wins the round and $80,000."


class RoundWinners(unittest.TestCase):
    def test_reads_every_round(self):
        self.assertEqual(by_round.round_winners(lines(A1, B2, A3), {"A": 150_000, "B": 75_000}), {1: "A", 2: "B", 3: "A"})

    def test_infers_a_last_round_win_that_no_line_names(self):
        self.assertEqual(by_round.round_winners(lines(A1, B2, None), {"A": 150_000, "B": 75_000}), {1: "A", 2: "B", 3: "A"})

    def test_rejects_prizes_that_differ_from_the_cash(self):
        self.assertIsNone(by_round.round_winners(lines(A1, B2, A3), {"A": 70_000, "B": 75_000}))

    def test_rejects_a_missing_middle_round(self):
        self.assertIsNone(by_round.round_winners(lines(A1, None, A3), {"A": 150_000, "B": 0}))

    def test_rejects_an_ambiguous_last_round(self):
        self.assertIsNone(by_round.round_winners(lines(A1, B2, None), {"A": 70_000 + 40_000, "B": 75_000 + 40_000}))


def event(player: str, start: int, entries: list[str]) -> str:
    return json.dumps({"kind": "delivered", "player": player, "from": start, "entries": entries}, separators=(",", ":"))


class LoadResults(unittest.TestCase):
    def test_pairs_each_round_winner_with_its_config_from_the_longest_log(self):
        public = lines(A1, B2, A3)
        with tempfile.TemporaryDirectory() as directory:
            db = sqlite3.connect(Path(directory) / "buckshot.sqlite")
            db.executescript(
                """CREATE TABLE source_files (path TEXT, match_id TEXT);
                   CREATE TABLE source_records (path TEXT, raw TEXT, current INTEGER);
                   CREATE TABLE match_seats (match_id TEXT, player TEXT, cash INTEGER)"""
            )
            db.execute("INSERT INTO source_files VALUES ('t/m1/events.jsonl', 'm1')")
            # B was shown the log in two overlapping deliveries; A only its first half.
            records = [event("A", 0, public[:4]), event("B", 4, public[4:]), event("B", 0, public[:4]), event("B", 4, public[4:])]
            db.executemany("INSERT INTO source_records VALUES ('t/m1/events.jsonl', ?, 1)", [(r,) for r in records])
            db.executemany("INSERT INTO match_seats VALUES ('m1', ?, ?)", [("A", 150_000), ("B", 75_000)])
            db.commit()
            knowledge = sqlite3.connect(Path(directory) / "knowledge.sqlite")
            knowledge.executescript(
                """CREATE TABLE matches (match_id TEXT, status TEXT);
                   CREATE TABLE players (match_id TEXT, player TEXT, model TEXT, effort TEXT)"""
            )
            knowledge.execute("INSERT INTO matches VALUES ('m1', 'completed')")
            knowledge.executemany("INSERT INTO players VALUES ('m1', ?, ?, ?)", [("A", "opus", "high"), ("B", "sol", "low")])
            knowledge.commit()
            results = by_round.load_results(str(Path(directory) / "buckshot.sqlite"), Path(directory) / "knowledge.sqlite")
        self.assertEqual(results.unreadable, 0)
        self.assertEqual(
            sorted(results.rounds, key=lambda r: (r.round, r.model)),
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
