"""Tests for the self-play summary: python3 -m unittest discover -s tools/arena/analysis"""

import random
import unittest

import selfplay as sp


def game(seed, starter_wins_round_1, cash=(150000, 75000), starter=1):
    winner = starter if starter_wins_round_1 else 3 - starter
    return {"seed": seed, "rounds": [{"round": 1, "starter": starter, "winner": winner, "prize": 70000}], "cash": list(cash)}


class SeedSpread(unittest.TestCase):
    def test_seeds_that_always_agree_with_themselves_spread_fully(self):
        groups = {seed: [float(seed % 2)] * 4 for seed in range(40)}
        self.assertAlmostEqual(sp.seed_sd(groups), 0.5, places=1)

    def test_outcomes_that_ignore_the_seed_show_no_spread(self):
        rng = random.Random(7)
        groups = {seed: [float(rng.random() < 0.5) for _ in range(4)] for seed in range(400)}
        self.assertLess(sp.seed_sd(groups), 0.1)

    def test_shuffling_outcomes_across_seeds_finds_a_real_spread_unlikely(self):
        groups = {seed: [float(seed % 2)] * 2 for seed in range(30)}
        self.assertLess(sp.permutation_p(groups, random.Random(1)), 0.01)


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


class Intervals(unittest.TestCase):
    def test_wilson_brackets_the_share_and_stays_inside_zero_to_one(self):
        low, high = sp.wilson(0, 10)
        self.assertAlmostEqual(low, 0.0)
        self.assertTrue(0 < high < 0.4)
        low, high = sp.wilson(5, 10)
        self.assertTrue(low < 0.5 < high)

    def test_ranks_average_ties(self):
        self.assertEqual(sp.ranks([3.0, 1.0, 3.0, 2.0]), [3.5, 1.0, 3.5, 2.0])


if __name__ == "__main__":
    unittest.main()
