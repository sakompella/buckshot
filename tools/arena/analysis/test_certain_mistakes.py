"""Tests for the certain-mistake rates: python3 -m unittest discover -s tools/arena/analysis"""

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import certain_mistakes as cm


def health(own=1, opponent=1):
    return json.dumps([{"_tag": "Unjammed", "health": own}, {"_tag": "Jammed"} if opponent is None else {"_tag": "Unjammed", "health": opponent}])


def decision(ordinal, player="A", chamber=None, source=None, shot=None, hp=None, known="", live_chance="[0.5,0.5,0.5]"):
    return ("m1", ordinal, player, "agent", chamber, source, shot, hp or health(), known, "[]", "[]", 3, live_chance)


def scores(own, other):
    return json.dumps([{"label": "Shoot yourself", "score": own}, {"label": "Shoot Player B", "score": other}])


def write(directory: Path, decisions, clues=(), searched=()):
    knowledge = sqlite3.connect(directory / "knowledge.sqlite")
    knowledge.executescript(
        """CREATE TABLE matches (match_id TEXT, status TEXT, seed_block_id TEXT);
           CREATE TABLE players (match_id TEXT, player TEXT, model TEXT, effort TEXT);
           CREATE TABLE decisions (match_id TEXT, ordinal INTEGER, player TEXT, by_whom TEXT, chamber TEXT, source TEXT, shot TEXT, health_json TEXT,
                                   private_known TEXT, own_items_json TEXT, opponent_items_json TEXT, remaining INTEGER, private_live_json TEXT);
           CREATE TABLE clues (match_id TEXT, learned INTEGER, ordinal INTEGER, player TEXT, kind TEXT, position INTEGER, shell TEXT);
           INSERT INTO matches VALUES ('m1', 'completed', 'b1');
           INSERT INTO players VALUES ('m1', 'A', 'opus', 'high'), ('m1', 'B', 'sol', 'low');"""
    )
    knowledge.executemany("INSERT INTO decisions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", decisions)
    knowledge.executemany("INSERT INTO clues VALUES ('m1', ?, ?, ?, ?, ?, ?)", clues)
    knowledge.commit()
    knowledge.close()
    regret = sqlite3.connect(directory / "regret.sqlite")
    regret.execute("CREATE TABLE regret (match_id TEXT, ordinal INTEGER, max_depth INTEGER, budget INTEGER, reload TEXT, status TEXT, values_json TEXT)")
    regret.executemany("INSERT INTO regret VALUES ('m1', ?, 6, 20000, 'static', 'searched', ?)", searched)
    regret.commit()
    regret.close()
    return directory / "knowledge.sqlite", directory / "regret.sqlite"


class CertainMistakes(unittest.TestCase):
    def load(self, decisions, clues=(), searched=()):
        with tempfile.TemporaryDirectory() as directory:
            return cm.load(*write(Path(directory), decisions, clues, searched))

    def patterns(self, decisions, clues=()):
        return [(d.pattern, d.chose) for d in self.load(decisions, clues)]

    def test_shooting_itself_on_a_proven_live_is_a_mistake_and_the_other_shot_is_not(self):
        found = self.patterns([decision(0, chamber="Live", source="glass", shot="self"), decision(1, chamber="Live", source="public", shot="opponent")])
        self.assertEqual(found, [(cm.Pattern.SELF_ON_LIVE, True), (cm.Pattern.SELF_ON_LIVE, False)])

    def test_a_merely_likely_live_is_no_opportunity(self):
        self.assertEqual(self.patterns([decision(0, shot="self", live_chance="[0.95,0.95,0.1]")]), [])

    def test_a_clue_the_inverter_made_stale_is_judged_by_the_proven_chamber(self):
        found = self.patterns([decision(5, chamber="Blank", source="glass", shot="opponent", known="1B 2L")], clues=[(3, 3, "A", "glass", 0, "Live")])
        self.assertEqual(found, [(cm.Pattern.GAVE_UP_GUARANTEED_WIN, True)])

    def test_the_opponents_secret_proves_nothing_for_the_player(self):
        self.assertEqual(self.patterns([decision(4, player="A", shot="self")], clues=[(2, 2, "B", "glass", 0, "Live")]), [])

    def test_a_proven_blank_without_a_guaranteed_win_is_only_the_turn_given_away(self):
        found = self.patterns(
            [
                decision(0, chamber="Blank", shot="opponent", known="1B 2L", hp=health(own=1, opponent=None)),
                decision(1, chamber="Blank", shot="opponent", known="1B 2L", hp=health(own=1, opponent=2)),
                decision(2, chamber="Blank", shot="opponent", known="1B 2L", hp=health(own=2, opponent=1)),
                decision(3, chamber="Blank", shot="opponent", known="1B"),
            ]
        )
        self.assertEqual(found, [(cm.Pattern.GAVE_TURN_AWAY, True)] * 4)

    def test_the_turn_given_away_is_split_by_what_the_search_scored(self):
        found = self.load(
            [decision(0, chamber="Blank", shot="opponent"), decision(1, chamber="Blank", shot="opponent"), decision(2, chamber="Blank", shot="self")],
            searched=[(0, scores(400000, 500000)), (1, scores(1000000, 0))],
        )
        self.assertEqual([d.search for d in found], [cm.Search.OPPONENT_SHOT_HIGHER, cm.Search.SETTLED_FOR_SELF_SHOT, cm.Search.UNSEARCHED])


class GuaranteedWin(unittest.TestCase):
    def test_a_saw_lets_either_side_kill_from_two_health(self):
        self.assertTrue(cm.guaranteed_win(True, own_health=2, opponent_health=2, own_saw=True, opponent_saw=True))
        self.assertFalse(cm.guaranteed_win(True, own_health=2, opponent_health=2, own_saw=True, opponent_saw=False))
        self.assertFalse(cm.guaranteed_win(True, own_health=2, opponent_health=2, own_saw=False, opponent_saw=True))


if __name__ == "__main__":
    unittest.main()
