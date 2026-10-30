"""Tests for the certain-mistake rates: python3 -m unittest discover -s tools/arena/analysis"""

import json
import random
import sqlite3
import tempfile
import unittest
from pathlib import Path

import certain_mistakes as cm

FREE = json.dumps([{"_tag": "Unjammed", "health": 3}, {"_tag": "Unjammed", "health": 3}])
JAMMED = json.dumps([{"_tag": "Unjammed", "health": 3}, {"_tag": "Jammed"}])


def decision(ordinal, player="A", chamber=None, source=None, shot=None, health=FREE, remaining=3, live_chance="[0.5,0.5,0.5]"):
    return ("m1", ordinal, player, "agent", chamber, source, shot, health, remaining, live_chance)


def write(directory: Path, decisions, clues=()):
    path = directory / "knowledge.sqlite"
    db = sqlite3.connect(path)
    db.executescript(
        """CREATE TABLE matches (match_id TEXT, status TEXT, seed_block_id TEXT);
           CREATE TABLE players (match_id TEXT, player TEXT, model TEXT, effort TEXT);
           CREATE TABLE decisions (match_id TEXT, ordinal INTEGER, player TEXT, by_whom TEXT, chamber TEXT, source TEXT, shot TEXT,
                                   health_json TEXT, remaining INTEGER, private_live_json TEXT);
           CREATE TABLE clues (match_id TEXT, learned INTEGER, ordinal INTEGER, player TEXT, kind TEXT, position INTEGER, shell TEXT);
           INSERT INTO matches VALUES ('m1', 'completed', 'b1');
           INSERT INTO players VALUES ('m1', 'A', 'opus', 'high'), ('m1', 'B', 'sol', 'low');"""
    )
    db.executemany("INSERT INTO decisions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", decisions)
    db.executemany("INSERT INTO clues VALUES ('m1', ?, ?, ?, ?, ?, ?)", clues)
    db.commit()
    db.close()
    return path


class CertainMistakes(unittest.TestCase):
    def rates(self, decisions, clues=()):
        with tempfile.TemporaryDirectory() as directory:
            loaded = cm.load(write(Path(directory), decisions, clues))
        rng = random.Random(0)
        return {kind: cm.rate([d for d in loaded if d.kind is kind], rng) for kind in cm.Kind}

    def test_shooting_itself_on_a_proven_live_is_a_mistake_and_the_other_shot_is_not(self):
        rates = self.rates([decision(0, chamber="Live", source="glass", shot="self"), decision(1, chamber="Live", source="public", shot="opponent")])
        self.assertEqual(rates[cm.Kind.SELF_ON_LIVE], cm.Rate(2, 0, 1, (0.5, 0.5)))

    def test_a_merely_likely_live_is_no_opportunity(self):
        rates = self.rates([decision(0, shot="self", live_chance="[0.95,0.95,0.1]")])
        self.assertEqual(rates[cm.Kind.SELF_ON_LIVE].opportunities, 0)

    def test_a_clue_the_inverter_made_stale_is_judged_by_the_proven_chamber(self):
        rates = self.rates(
            [decision(5, chamber="Blank", source="glass", shot="opponent")],
            clues=[(3, 3, "A", "glass", 0, "Live")],
        )
        self.assertEqual(rates[cm.Kind.SELF_ON_LIVE].opportunities, 0)
        self.assertEqual(rates[cm.Kind.OPPONENT_ON_BLANK].mistakes, 1)

    def test_the_opponents_secret_proves_nothing_for_the_player(self):
        rates = self.rates([decision(4, player="A", shot="self")], clues=[(2, 2, "B", "glass", 0, "Live")])
        self.assertEqual(rates[cm.Kind.SELF_ON_LIVE].opportunities, 0)

    def test_a_proven_blank_against_a_jammed_opponent_is_excluded_and_counted(self):
        rates = self.rates(
            [decision(0, chamber="Blank", source="public", shot="opponent", health=JAMMED), decision(1, chamber="Blank", source="phone", shot="opponent")]
        )
        self.assertEqual(rates[cm.Kind.OPPONENT_ON_BLANK], cm.Rate(2, 1, 1, (1.0, 1.0)))
        self.assertEqual(rates[cm.Kind.OPPONENT_ON_BLANK].counted, 1)


if __name__ == "__main__":
    unittest.main()
