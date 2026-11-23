import json
import tempfile
import unittest
from pathlib import Path

import check_matches
import seed_pairs

URL = "http://hub/v1"


def manifest(winner: str, fallback: int = 0, url: str = URL) -> dict:
    return {
        "status": "finished",
        "provenance": {"agents": {"a": {"url": url}, "b": {"url": url}}},
        "moves": {"fallback": fallback},
        "audit": {"ok": True},
        "standings": [{"player": winner, "controller": winner}],
        "letters": ["a", "b"],
        "labels": ["A", "B"],
    }


def tournament(root: Path, matches: list[tuple[int, list[str], dict | None]]) -> Path:
    """Matches as (seed, seats, manifest); entrants A and B in the order of the seats."""
    schedule = []
    for k, (seed, seats, body) in enumerate(matches):
        name = f"m{k}"
        schedule.append(
            {"name": name, "seed": seed, "seats": seats, "entrants": ["A", "B"]}
        )
        if body is not None:
            (root / name).mkdir()
            (root / name / "manifest.json").write_text(json.dumps(body))
    (root / "tournament.json").write_text(json.dumps({"schedule": schedule}))
    return root


class TmpCase(unittest.TestCase):
    def tmp(self) -> Path:
        return Path(self.enterContext(tempfile.TemporaryDirectory()))


class CheckMatches(TmpCase):
    def test_a_clean_tournament_has_no_problem(self):
        root = tournament(
            self.tmp(), [(1, ["a", "b"], manifest("a")), (1, ["b", "a"], manifest("b"))]
        )
        line, bad = check_matches.check(root, URL)
        self.assertFalse(bad)
        self.assertIn("complete seed pairs 1", line)

    def test_a_fallback_move_or_foreign_endpoint_is_a_problem(self):
        for body in (manifest("a", fallback=1), manifest("a", url="http://other/v1")):
            _, bad = check_matches.check(
                tournament(self.tmp(), [(1, ["a", "b"], body)]), URL
            )
            self.assertTrue(bad)


class SeedPairs(TmpCase):
    def test_only_complete_pairs_count(self):
        root = tournament(
            self.tmp(),
            [
                (1, ["a", "b"], manifest("a")),
                (1, ["b", "a"], manifest("a")),
                (2, ["a", "b"], manifest("a")),
                (3, ["a", "b"], None),
            ],
        )
        complete, half = seed_pairs.pairs(str(root), "A", "B")
        self.assertEqual(complete, {1: [1, 0]})
        self.assertEqual(half, 1)


if __name__ == "__main__":
    unittest.main()
