import unittest
from itertools import count

from load import Game
from schedule import next_matches


def game(first: str, second: str, share: float, seed: int) -> Game:
    return Game(block=str(seed), cohort="c", tournament="t", code="", seed=seed, first=first, second=second, share_first=share, pot_first=share, starter=1, first_shot=1)


class NextMatches(unittest.TestCase):
    def test_a_settled_pair_is_left_and_a_close_cheap_one_is_played_in_both_seat_orders(self):
        # a beats c every time; a and b split their games, so only a and b are close.
        games = [game("a", "c", 1.0, s) for s in range(40)] + [game("b", "c", 1.0, s) for s in range(40, 80)]
        games += [game("a", "b", s % 2, s) for s in range(80, 84)]
        matches = next_matches(games, {"a": 1.0, "b": 1.0, "c": 1.0}, 4, count(1000))
        self.assertEqual(matches, [("a", "b", 1000), ("b", "a", 1000), ("a", "b", 1001), ("b", "a", 1001)])

    def test_a_dearer_config_is_played_less(self):
        games = [game("a", "b", s % 2, s) for s in range(4)] + [game("b", "c", s % 2, s) for s in range(4, 8)]
        matches = next_matches(games, {"a": 1.0, "b": 1.0, "c": 100.0}, 2, count(1000))
        self.assertEqual(matches, [("a", "b", 1000), ("b", "a", 1000)])


if __name__ == "__main__":
    unittest.main()
