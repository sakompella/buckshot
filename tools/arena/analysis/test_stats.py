"""Tests for the shared statistics: python3 -m unittest discover -s tools/arena/analysis"""

import math
import unittest

from stats import pearson, ranks, split_evenly


class SplitEvenly(unittest.TestCase):
    def test_equal_shares_with_the_remainder_to_the_first_keys(self):
        self.assertEqual(split_evenly(7, {"a": 100, "b": 100, "c": 100}), {"a": 3, "b": 2, "c": 2})

    def test_a_small_key_gives_its_unused_share_to_the_others(self):
        self.assertEqual(split_evenly(10, {"a": 1, "b": 100, "c": 100}), {"a": 1, "b": 5, "c": 4})

    def test_never_more_than_exists(self):
        self.assertEqual(split_evenly(50, {"a": 2, "b": 3}), {"a": 2, "b": 3})


class Correlation(unittest.TestCase):
    def test_tied_values_share_the_mean_of_their_ranks(self):
        self.assertEqual(ranks([5.0, 1.0, 5.0, 3.0]), [3.5, 1.0, 3.5, 2.0])

    def test_no_spread_has_no_correlation(self):
        self.assertTrue(math.isnan(pearson([1.0, 1.0, 1.0], [1.0, 2.0, 3.0])))
