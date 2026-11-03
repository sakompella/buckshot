"""Tests for net points: python3 -m unittest discover -s tools/arena/analysis"""

import json
import random
import sqlite3
import tempfile
import unittest
from pathlib import Path

import net_points as np_


def seat(model: str, lost: float, won: int, worst: int = 0, effort: str = "high") -> np_.Seat:
    return np_.Seat((model, effort), lost, 5, won, worst, 3)


def match(block: str, first: np_.Seat, second: np_.Seat, name: str = "m") -> np_.Match:
    return np_.Match(name, name, block, first, second)


class Arithmetic(unittest.TestCase):
    def test_net_is_the_opponents_loss_minus_ones_own_and_margin_counts_rounds(self):
        m = match("b", seat("opus", 0.4, 2), seat("sol", 1.0, 1))
        self.assertAlmostEqual(m.net, 0.6)
        self.assertEqual(m.margin, 1)

    def test_tied_values_share_the_mean_of_their_ranks(self):
        self.assertEqual(np_.ranks([5.0, 1.0, 5.0, 3.0]), [3.5, 1.0, 3.5, 2.0])

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


def event(player: str, start: int, entries: list[str]) -> str:
    return json.dumps({"kind": "delivered", "player": player, "from": start, "entries": entries}, separators=(",", ":"))


class Load(unittest.TestCase):
    def build(self, directory: str, searched: dict[int, int]):
        """One match, A (opus) at position 1 and B (sol) at 2; A wins rounds 1 and 3. `searched` maps an ordinal to its regret; A decides 0 and 1, B decides 2."""
        public = []
        for n, win in enumerate(["Player A wins the round and $70,000.", "Player B wins the round and $75,000.", "Player A wins the round and $80,000."], 1):
            public += [f"Round {n} begins. Everyone has 3 health; Player A starts.", win]
        analysis = sqlite3.connect(Path(directory) / "buckshot.sqlite")
        analysis.executescript(
            """CREATE TABLE source_files (path TEXT, match_id TEXT); CREATE TABLE source_records (path TEXT, raw TEXT, current INTEGER);
               CREATE TABLE match_seats (match_id TEXT, player TEXT, cash INTEGER)"""
        )
        analysis.execute("INSERT INTO source_files VALUES ('t/m1/events.jsonl', 'm1')")
        analysis.execute("INSERT INTO source_records VALUES ('t/m1/events.jsonl', ?, 1)", (event("A", 0, public),))
        analysis.executemany("INSERT INTO match_seats VALUES ('m1', ?, ?)", [("A", 150_000), ("B", 75_000)])
        analysis.commit()
        knowledge = sqlite3.connect(Path(directory) / "knowledge.sqlite")
        knowledge.executescript(
            """CREATE TABLE matches (match_id TEXT, name TEXT, status TEXT, seed_block_id TEXT);
               CREATE TABLE players (match_id TEXT, player TEXT, position INTEGER, model TEXT, effort TEXT);
               CREATE TABLE decisions (match_id TEXT, ordinal INTEGER, player TEXT, by_whom TEXT, remaining INTEGER, choice TEXT)"""
        )
        knowledge.execute("INSERT INTO matches VALUES ('m1', 'name1', 'completed', 'block1')")
        knowledge.executemany("INSERT INTO players VALUES ('m1', ?, ?, ?, 'high')", [("A", 1, "opus"), ("B", 2, "sol")])
        knowledge.executemany("INSERT INTO decisions VALUES ('m1', ?, ?, 'agent', 3, 'Shoot Player B')", [(0, "A"), (1, "A"), (2, "B")])
        knowledge.commit()
        out = sqlite3.connect(Path(directory) / "regret.sqlite")
        out.execute(
            """CREATE TABLE regret (match_id TEXT, ordinal INTEGER, player TEXT, evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT, samples INTEGER, status TEXT, regret INTEGER)"""
        )
        owners = {0: "A", 1: "A", 2: "B"}
        out.executemany("INSERT INTO regret VALUES ('m1', ?, ?, 'e', 6, 20000, 'static', 0, 'searched', ?)", [(o, owners[o], r) for o, r in searched.items()])
        out.commit()
        return Path(directory)

    def load(self, searched: dict[int, int]) -> np_.Loaded:
        with tempfile.TemporaryDirectory() as directory:
            root = self.build(directory, searched)
            return np_.load(str(root / "buckshot.sqlite"), root / "regret.sqlite", root / "knowledge.sqlite", 6, 20000)

    def test_sums_each_seats_regret_in_rounds_and_keeps_its_largest_with_the_rounds_it_won(self):
        loaded = self.load({0: 100_000, 1: 250_000, 2: 40_000})
        (m,) = loaded.matches
        self.assertEqual((m.first.config, m.first.lost, m.first.worst, m.first.worst_ordinal, m.first.rounds_won), (("opus", "high"), 0.35, 250_000, 1, 2))
        self.assertEqual((m.second.config, m.second.lost, m.second.rounds_won), (("sol", "high"), 0.04, 1))
        self.assertAlmostEqual(m.net, -0.31)
        self.assertEqual((loaded.unreadable, loaded.incomplete), (0, 0))

    def test_a_match_with_an_unsearched_agent_decision_is_left_out_not_counted_as_zero(self):
        loaded = self.load({0: 100_000, 2: 40_000})
        self.assertEqual((loaded.matches, loaded.incomplete), ([], 1))


if __name__ == "__main__":
    unittest.main()
