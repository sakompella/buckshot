"""Properties of the analysis helpers: python3 -m unittest discover -s tools/arena/analysis"""

import random
import unittest

import boot
import bt
import cv
import net_points
import regret
import selfplay
from load import Game
from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st

settings.register_profile("arena", deadline=None, suppress_health_check=[HealthCheck.too_slow])
settings.load_profile("arena")

finite = st.floats(-1e6, 1e6, allow_nan=False)
nonempty = st.lists(finite, min_size=1, max_size=40)
shares = st.floats(0, 1)
rank_functions = [net_points.ranks, selfplay.ranks]


class Percentiles(unittest.TestCase):
    @given(nonempty, shares)
    def test_lies_within_the_data(self, values, share):
        self.assertTrue(min(values) <= regret.percentile(values, share) <= max(values))

    @given(nonempty, shares, shares)
    def test_never_falls_as_the_share_rises(self, values, a, b):
        low, high = sorted((a, b))
        self.assertLessEqual(regret.percentile(values, low), regret.percentile(values, high))

    @given(nonempty, shares, st.randoms())
    def test_ignores_the_order_of_the_values(self, values, share, rng):
        shuffled = rng.sample(values, len(values))
        self.assertEqual(regret.percentile(shuffled, share), regret.percentile(values, share))

    @given(nonempty, shares)
    def test_agrees_with_the_bootstrap_quantile(self, values, share):
        self.assertAlmostEqual(boot.quantile(sorted(values), share), regret.percentile(values, share))


class Ranks(unittest.TestCase):
    @given(st.lists(st.integers(-20, 20), min_size=1, max_size=30))
    def test_order_the_values_and_total_the_first_n_integers(self, values):
        for ranks in rank_functions:
            out = ranks(values)
            self.assertAlmostEqual(sum(out), len(values) * (len(values) + 1) / 2)
            for i, x in enumerate(values):
                for j, y in enumerate(values):
                    self.assertEqual((x < y), (out[i] < out[j]))

    @given(st.lists(st.integers(-20, 20), min_size=2, max_size=30, unique=True), st.lists(st.integers(-20, 20), min_size=2, max_size=30, unique=True))
    def test_spearman_ignores_increasing_maps(self, xs, ys):
        n = min(len(xs), len(ys))
        xs, ys = xs[:n], ys[:n]
        self.assertAlmostEqual(net_points.spearman(xs, ys), net_points.spearman([x**3 + 2 * x for x in xs], ys))


class Regression(unittest.TestCase):
    @given(st.lists(st.integers(-30, 30), min_size=2, max_size=20, unique=True), st.integers(-9, 9).filter(bool), st.integers(-50, 50))
    def test_ols_recovers_any_line(self, xs, slope, intercept):
        line = net_points.ols([float(x) for x in xs], [float(slope * x + intercept) for x in xs])
        self.assertAlmostEqual(line.slope, slope)
        self.assertAlmostEqual(line.intercept, intercept, places=5)
        self.assertAlmostEqual(line.r2, 1.0)

    @given(st.integers(1, 5).flatmap(lambda n: st.tuples(st.lists(st.lists(st.floats(-1, 1), min_size=n, max_size=n), min_size=n, max_size=n), st.lists(finite, min_size=n, max_size=n))))
    def test_solve_satisfies_the_system(self, system):
        matrix, b = system
        n = len(b)
        dominant = [[row[c] + (n + 1) * (c == r) for c in range(n)] for r, row in enumerate(matrix)]
        x = bt.solve(dominant, b)
        for row, target in zip(dominant, b):
            self.assertAlmostEqual(sum(a * v for a, v in zip(row, x)), target, delta=1e-6 * (1 + abs(target)))


class Resampling(unittest.TestCase):
    @given(st.lists(st.text(max_size=3), min_size=1, max_size=30, unique=True), st.integers())
    def test_a_resample_draws_exactly_as_many_blocks_as_there_are(self, blocks, seed):
        drawn = boot.weights(blocks, random.Random(seed))
        self.assertEqual(sum(drawn.values()), len(blocks))
        self.assertLessEqual(set(drawn), set(blocks))

    @given(st.lists(st.text(max_size=3), min_size=1, max_size=40, unique=True), st.integers(1, 10), st.integers())
    def test_folds_hold_out_every_block_exactly_once_in_near_equal_parts(self, ids, k, seed):
        parts = cv.folds(ids, k, random.Random(seed))
        self.assertEqual(sorted(b for part in parts for b in part), sorted(ids))
        self.assertLessEqual(max(map(len, parts)) - min(map(len, parts)), 1)


if __name__ == "__main__":
    unittest.main()


class Ratings(unittest.TestCase):
    @given(st.lists(st.tuples(st.integers(0, 3), st.integers(1, 3), st.sampled_from([0.0, 0.5, 1.0])), min_size=1, max_size=40))
    def test_have_mean_zero_on_the_elo_scale(self, played):
        games = [Game(f"b{i}", "c", "t", "code", 1, "abcd"[first], "abcd"[(first + offset) % 4], share, share, 1, 1) for i, (first, offset, share) in enumerate(played)]
        self.assertAlmostEqual(sum(bt.fit(bt.cells_of(games)).elo().values()), 0.0, places=6)
