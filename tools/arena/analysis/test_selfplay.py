"""Tests for the self-play summary: python3 -m unittest discover -s tools/arena/analysis"""

import json
import tempfile
import unittest
from pathlib import Path

import selfplay as sp


def game(seed, starter_wins_round_1, cash=(150000, 75000), starter=1):
    winner = starter if starter_wins_round_1 else 3 - starter
    return {"seed": seed, "rounds": [{"round": 1, "starter": starter, "winner": winner, "prize": 70000}], "cash": list(cash)}


class Spread(unittest.TestCase):
    def test_spread_is_the_sd_of_the_seeds_own_shares(self):
        games = [game(seed, seed % 2 == 0) for seed in range(40) for _ in range(2)]
        self.assertIn("50.0", sp.spread(games))


class Load(unittest.TestCase):
    def test_mixed_settings_are_rejected(self):
        rows = [{**game(1, True), "depth": depth, "budget": 20000, "tieRule": "random"} for depth in (2, 3)]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "mixed.jsonl"
            path.write_text("\n".join(map(json.dumps, rows)))
            with self.assertRaises(ValueError):
                sp.load(path)


class StarterShares(unittest.TestCase):
    def test_a_match_won_by_the_other_position_is_the_starters_loss_when_that_position_starts(self):
        self.assertEqual(sp.starter_match_win(game(1, True, cash=(150000, 75000), starter=2)), 0.0)
        self.assertEqual(sp.starter_match_win(game(1, True, cash=(150000, 75000), starter=1)), 1.0)
        self.assertEqual(sp.starter_match_win(game(1, True, cash=(100000, 100000))), 0.5)

    def test_round_win_follows_the_named_rounds_starter(self):
        played = {"rounds": [{"starter": 1, "winner": 1}, {"starter": 2, "winner": 1}]}
        self.assertEqual(sp.starter_round_win(played, 2), 0.0)
        self.assertEqual(sp.starter_round_win(played, 2, of=1), 1.0)
        self.assertIsNone(sp.starter_round_win(played, 3))


class Ranks(unittest.TestCase):
    def test_ranks_average_ties(self):
        self.assertEqual(sp.ranks([3.0, 1.0, 3.0, 2.0]), [3.5, 1.0, 3.5, 2.0])


if __name__ == "__main__":
    unittest.main()
