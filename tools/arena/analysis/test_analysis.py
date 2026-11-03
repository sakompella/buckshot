"""Tests for the matchup analysis: python3 -m unittest discover -s tools/arena/analysis"""

import math
import random
import unittest
from dataclasses import replace

import boot
import bt
import cv
import seats
from load import Game, blocks_of


def game(block, first, second, share_first, seed=1, starter=1, cohort="c"):
    return Game(block, cohort, "t", "code", seed, first, second, share_first, share_first, starter, starter)


def swapped_block(block, a, b, share_a_first, share_a_second, seed=1, starter=1):
    """One complete block: a first, then b first, with a's win share in each."""
    return [game(f"{block}", a, b, share_a_first, seed, starter), game(f"{block}", b, a, 1 - share_a_second, seed, starter)]


class Bradley(unittest.TestCase):
    def test_recovers_the_win_probability_of_a_pair(self):
        games = [game(f"b{i}", "a", "b", 1.0 if i < 75 else 0.0) for i in range(100)]
        fitted = bt.fit(bt.cells_of(games))
        self.assertAlmostEqual(bt.sigmoid(fitted.theta["a"] - fitted.theta["b"]), 0.75, places=2)

    def test_a_split_counts_half(self):
        split = [game(f"b{i}", "a", "b", 0.5) for i in range(10)]
        fitted = bt.fit(bt.cells_of(split))
        self.assertAlmostEqual(fitted.theta["a"], fitted.theta["b"], places=6)

    def test_a_cash_rating_counts_the_pot_share(self):
        games = [replace(game(f"b{i}", "a", "b", 1.0), pot_first=0.6) for i in range(100)]
        fitted = bt.fit(bt.cells_of(games, share=lambda g: g.pot_first))
        self.assertAlmostEqual(bt.sigmoid(fitted.theta["a"] - fitted.theta["b"]), 0.6, places=2)

    def test_ratings_have_mean_zero_on_the_elo_scale(self):
        games = [game("1", "a", "b", 1.0), game("2", "b", "c", 1.0), game("3", "a", "c", 1.0), game("4", "b", "a", 0.0)]
        elo = bt.fit(bt.cells_of(games)).elo()
        self.assertAlmostEqual(sum(elo.values()), 0.0, places=6)
        self.assertGreater(elo["a"], elo["b"])
        self.assertGreater(elo["b"], elo["c"])

    def test_seat_term_finds_a_position_edge(self):
        games = [game(f"b{i}", "a", "b", 1.0 if i % 4 else 0.0) for i in range(40)] + [game(f"c{i}", "b", "a", 1.0 if i % 4 else 0.0) for i in range(40)]
        fitted = bt.fit(bt.cells_of(games), seat=True)
        self.assertGreater(fitted.seat, 0.5)
        self.assertAlmostEqual(fitted.theta["a"], fitted.theta["b"], places=3)

    def test_starter_term_finds_the_opening_edge(self):
        # whoever opens round 1 wins 3 of 4, whatever the seat; the entrants are equal
        games = []
        for starter in (1, 2):
            for i in range(40):
                wins = 1.0 if i % 4 else 0.0
                share_first = wins if starter == 1 else 1 - wins
                games.append(game(f"s{starter}a{i}", "a", "b", share_first, starter=starter))
                games.append(game(f"s{starter}b{i}", "b", "a", share_first, starter=starter))
        fitted = bt.fit(bt.cells_of(games, starter=True), seat=True, start=True)
        self.assertAlmostEqual(fitted.start, math.log(3), places=1)
        self.assertAlmostEqual(fitted.seat, 0.0, places=1)
        self.assertAlmostEqual(fitted.theta["a"], fitted.theta["b"], places=1)

    def test_a_large_tau_lets_a_pair_leave_the_ratings(self):
        # a beats b, b beats c, c beats a: no ratings fit it, so a free pair term must lower the loss
        games = [game(f"{x}{i}", x, y, 1.0) for x, y in [("a", "b"), ("b", "c"), ("c", "a")] for i in range(20)]
        cells = bt.cells_of(games)
        self.assertLess(bt.log_loss(bt.fit(cells, tau=3.0), games), bt.log_loss(bt.fit(cells), games))

    def test_components(self):
        games = [game("1", "a", "b", 1.0), game("2", "c", "d", 1.0)]
        self.assertEqual(bt.components(games), [{"a", "b"}, {"c", "d"}])

    def test_weights_count_resampled_blocks(self):
        games = [game("x", "a", "b", 1.0), game("y", "a", "b", 0.0)]
        self.assertEqual(bt.cells_of(games, {"x": 3}), {("a", "b"): [3.0, 3.0]})


class Bootstrap(unittest.TestCase):
    def test_interval_needs_enough_draws(self):
        self.assertIsNone(boot.interval([1.0] * 5))
        low, high = boot.interval([float(i) for i in range(101)])
        self.assertAlmostEqual(low, 2.5)
        self.assertAlmostEqual(high, 97.5)


class CrossValidation(unittest.TestCase):
    def test_nested_scores_every_block_for_every_tau(self):
        games = [g for i in range(30) for g in swapped_block(f"b{i}", "a", "b", 1.0, 1.0)]
        losses, chosen = cv.nested(games, False, random.Random(1), repeats=1, outer=5, inner=3)
        self.assertEqual(set(losses["nested"]), set(blocks_of(games)))
        self.assertEqual(sum(chosen.values()), 5)

    def test_pair_effects_can_be_limited_to_pairs_repeated_across_blocks(self):
        games = [
            *swapped_block("single", "a", "c", 1.0, 1.0),
            *swapped_block("repeat-1", "a", "b", 1.0, 1.0),
            *swapped_block("repeat-2", "a", "b", 1.0, 1.0),
        ]
        fitted = cv.fit_on(blocks_of(games), ["single", "repeat-1", "repeat-2"], {"a", "b", "c"}, 0.4, False, {("a", "b")})
        self.assertEqual(set(fitted.delta), {("a", "b")})


class Seats(unittest.TestCase):
    MODELS = {"a": "m", "b": "n"}

    def test_a_block_averages_the_two_seatings(self):
        # a beats b whichever seat it sits in, so position 1 shares half of the wins
        blocks, left = seats.complete_blocks(swapped_block("x", "a", "b", 1.0, 1.0), self.MODELS)
        self.assertEqual(left, 0)
        self.assertEqual(blocks[0].first_share, 0.5)

    def test_half_blocks_are_left_out(self):
        _, left = seats.complete_blocks([game("x", "a", "b", 1.0)], self.MODELS)
        self.assertEqual(left, 1)

    def test_blocks_must_swap_seats(self):
        with self.assertRaises(ValueError):
            seats.complete_blocks([game("x", "a", "b", 1.0), game("x", "a", "b", 1.0)], self.MODELS)

    def test_starter_and_position_effects_separate(self):
        # the starter wins both its matches in every block, wherever it sits: a pure starter effect
        blocks = []
        for starter in (1, 2):
            for i in range(5):
                first_wins = 1.0 if starter == 1 else 0.0
                pair = [game(f"s{starter}{i}", "a", "b", first_wins, 1, starter), game(f"s{starter}{i}", "b", "a", first_wins, 1, starter)]
                blocks += seats.complete_blocks(pair, self.MODELS)[0]
        out = seats.estimates(blocks)
        self.assertAlmostEqual(out["seat"], 0.0)
        self.assertAlmostEqual(out["start"], 0.5)
        self.assertAlmostEqual(out["starter"], 1.0)


if __name__ == "__main__":
    unittest.main()
