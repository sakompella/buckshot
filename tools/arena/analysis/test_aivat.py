"""Tests for the luck correction: python3 -m unittest discover -s tools/arena/analysis"""

import unittest

import aivat
import numpy as np
from testdb import ANALYSIS, database, events, insert


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
    def test_outcomes_follow_the_replayed_shots(self):
        db = database(":memory:", ANALYSIS)
        events(db, "m1", ("Fired", {"shooter": 0, "target": 0, "shell": "Blank"}), ("PickedUp", {"seat": 1}), ("Fired", {"shooter": 1, "target": 0, "shell": "Live"}))
        self.assertEqual(aivat.shot_outcomes(db), {"m1": [False, True]})


class DealTest(unittest.TestCase):
    def deal(self, *grants: tuple[int, str]) -> tuple:
        db = database(":memory:", ANALYSIS)
        for position, socket in ((1, 0), (2, 1)):
            insert(db, "match_seats", match_id="m1", position=position, socket=socket)
        granted = [("Granted", {"seat": seat, "item": item}) for seat, item in grants]
        events(db, "m1", ("RoundBegan", {"round": 0, "health": 3, "first": 1}), ("GrabbingBegan", {"seats": [0, 1]}), *granted, ("Loaded", {"load": {"live": 1, "blank": 2}}), ("TurnGiven", {"seat": 1}))
        return aivat.deals_of(db, {"m1": 0})

    def test_a_grant_draws_from_the_items_under_both_caps(self):
        grants, deals = self.deal((0, "Saw"), (0, "Saw"), (1, "Jammer"))
        self.assertTrue(grants.pool[2].all())  # the other seat's saws do not cap this seat's
        self.assertEqual(list(grants.inv1[2]), [2, 0, 0, 0, 0, 0, 0, 0])
        held, other = np.array([2, 0, 0, 0, 0, 0, 0, 0]), np.array([0, 0, 1, 0, 0, 0, 0, 0])
        self.assertEqual([aivat.ITEMS[k] for k in np.flatnonzero(~aivat.item_pool(held, other))], ["Saw", "Jammer"])
        self.assertEqual(list(deals.mover), [2])

    def test_a_grant_outside_its_pool_is_an_error(self):
        with self.assertRaises(ValueError):
            self.deal((0, "Saw"), (0, "Saw"), (0, "Saw"))


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
