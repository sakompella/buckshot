"""Tests for the luck correction: python3 -m unittest discover -s tools/arena/analysis"""

import unittest

import aivat
import numpy as np


class DeckTest(unittest.TestCase):
    def test_the_deck_is_drawn_without_replacement_and_refilled(self):
        order = list(aivat.DECK) * 2
        chances = aivat.deck_chances(order)
        self.assertEqual(chances[0], {comp: 1 / 9 for comp in aivat.DECK})
        self.assertEqual(chances[8], {aivat.DECK[8]: 1.0})
        self.assertEqual(chances[9], chances[0])

    def test_a_load_not_left_in_the_deck_is_an_error(self):
        with self.assertRaises(ValueError):
            aivat.deck_chances([(1, 2), (1, 2)])


class ShotTest(unittest.TestCase):
    def test_outcomes_follow_the_public_log(self):
        lines = ["Player A shot themselves: blank.", "Player B picked up the shotgun.", "Player B shot Player A: live, 1 damage, 3 health left."]
        self.assertEqual(aivat.shot_outcomes(lines), [False, True])


class FitTest(unittest.TestCase):
    def test_a_correction_moves_the_rating_it_credits(self):
        rng = np.random.default_rng(0)
        n = 300
        i = rng.integers(0, 3, n)
        j = (i + rng.integers(1, 3, n)) % 3
        wins = rng.binomial(3, np.where(i == 0, 0.7, 0.5)).astype(float)
        t = aivat.Rated(["a", "b", "c"], i, j, np.full(n, 3.0), wins, np.zeros(n), np.arange(n) % 30, np.arange(n) % 30)
        raw = aivat.fit(t, t.raw)
        self.assertGreater(raw[0], 0)
        lucky = aivat.fit(t, t.raw - np.where(i == 0, 0.3, 0.0))
        self.assertLess(lucky[0], raw[0])

    def test_a_weight_counts_a_match_that_many_times(self):
        t = aivat.Rated(["a", "b"], np.array([0, 1]), np.array([1, 0]), np.full(2, 3.0), np.array([2.0, 1.0]), np.zeros(2), np.arange(2), np.arange(2))
        twice = aivat.Rated(["a", "b"], np.array([0, 1, 0]), np.array([1, 0, 1]), np.full(3, 3.0), np.array([2.0, 1.0, 2.0]), np.zeros(3), np.arange(3), np.arange(3))
        np.testing.assert_allclose(aivat.fit(t, t.raw, np.array([2.0, 1.0])), aivat.fit(twice, twice.raw))


if __name__ == "__main__":
    unittest.main()
