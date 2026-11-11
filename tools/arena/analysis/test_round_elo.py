"""Ties Round Elo's two fitters: python3 -m unittest discover -s tools/arena/analysis (needs node, as in nix develop)

Round Elo is fitted twice: here by bt.round_elo for the docs (net_points, aivat) and in TypeScript by the viewer for the
site (web/src/arena-viewer/page/ratings.ts). They cannot share code - each refits thousands of times on bootstrap
resamples in its own runtime - so this test feeds both the same matches and fails on any difference beyond float noise.
The matches are the analysis database's when this checkout has it, else a seeded synthetic tournament of the same shape,
so the tie also runs where the private data is absent (nix flake check).
"""

import json
import random
import subprocess
import unittest
from collections import defaultdict
from pathlib import Path

import bt
from load import DB, connect, round_winners

REPO = Path(__file__).resolve().parents[3]
RATINGS = REPO / "web/src/arena-viewer/page/ratings.ts"
TOLERANCE = 1e-6  # Elo points; on the real matches the two fits agree to about 1e-14


def from_database() -> list[tuple[str, str, float, float]] | None:
    """Every scored two-seat match as (first entrant, second entrant, rounds, the first's round wins), or None without the database."""
    if not Path(DB).is_file():
        return None
    db = connect(DB)
    winners = round_winners(db)
    seats: dict[str, list[tuple[int, str, str]]] = defaultdict(list)
    for match, position, player, name in db.execute(
        """SELECT s.match_id, s.position, s.player, e.name FROM match_seats s JOIN entrants e ON e.id = s.entrant_id
           JOIN matches m ON m.id = s.match_id WHERE m.status = 'completed' AND m.disposition IS NULL ORDER BY s.match_id, s.position"""
    ):
        seats[match].append((position, player, name))
    out = []
    for match, found in seats.items():
        won = winners.get(match, {})
        if len(found) == 2 and won:
            first, second = sorted(found)
            out.append((first[2], second[2], float(len(won)), float(sum(w == first[1] for w in won.values()))))
    db.close()
    return out


def synthetic() -> list[tuple[str, str, float, float]]:
    """A seeded tournament of the real one's shape: twelve configs of spread strength, both seat orders, repeated pairs."""
    rng = random.Random(20261111)
    names = [f"model-{i}" for i in range(12)]
    strength = {name: 0.04 * i for i, name in enumerate(names)}
    out = []
    for _ in range(400):
        first, second = rng.sample(names, 2)
        rounds = rng.randint(2, 6)
        wins = sum(rng.random() < 0.5 + strength[first] - strength[second] for _ in range(rounds))
        out.append((first, second, float(rounds), float(wins)))
    return out


def matches() -> list[tuple[str, str, float, float]]:
    return from_database() or synthetic()


def viewer_ratings(rows: list[tuple[str, str, float, float]]) -> dict[str, float]:
    """The viewer's fit of the same matches: node runs the TypeScript (web/src/arena-viewer/page/ratings.ts) on them."""
    games = [{"a": a, "b": b, "sa": wins / rounds, "weight": rounds} for a, b, rounds, wins in rows]
    read = 'import { readFileSync } from "node:fs"; const { bradleyTerry } = await import(process.argv[1]);'
    read += ' console.log(JSON.stringify(Object.fromEntries(bradleyTerry(JSON.parse(readFileSync(0, "utf8"))))))'
    fitted = subprocess.run(
        ["node", "--experimental-strip-types", "--input-type=module", "-e", read, RATINGS.as_uri()],
        input=json.dumps(games),
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(fitted.stdout)


class RoundElo(unittest.TestCase):
    def test_the_docs_fit_is_the_sites_fit(self):
        rows = matches()
        ours, theirs = bt.round_elo(rows), viewer_ratings(rows)
        self.assertEqual(sorted(ours), sorted(theirs))
        for name, elo in ours.items():
            self.assertAlmostEqual(elo, theirs[name], delta=TOLERANCE, msg=name)


if __name__ == "__main__":
    unittest.main()
