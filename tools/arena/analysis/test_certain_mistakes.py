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
    regret.execute(
        "CREATE TABLE regret (match_id TEXT, ordinal INTEGER, evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT, samples INTEGER, status TEXT, values_json TEXT)"
    )
    regret.executemany("INSERT INTO regret VALUES ('m1', ?, ?, 6, 20000, 'static', 0, 'searched', ?)", searched)
    regret.commit()
    regret.close()
    return directory / "knowledge.sqlite", directory / "regret.sqlite"


class CertainMistakes(unittest.TestCase):
    def load(self, decisions, clues=(), searched=()):
        with tempfile.TemporaryDirectory() as directory:
            return cm.load(*write(Path(directory), decisions, clues, searched))

    def patterns(self, decisions, clues=()):
        return [(d.model, d.pattern, d.chose) for d in self.load(decisions, clues)]

    def test_shooting_itself_on_a_proven_live_is_a_mistake_and_the_other_shot_is_not(self):
        found = self.patterns([decision(0, chamber="Live", source="glass", shot="self"), decision(1, chamber="Live", source="public", shot="opponent")])
        self.assertEqual(found, [("opus", cm.Pattern.SELF_ON_LIVE, True), ("opus", cm.Pattern.SELF_ON_LIVE, False)])

    def test_a_merely_likely_live_is_no_opportunity(self):
        self.assertEqual(self.patterns([decision(0, shot="self", known="2B", live_chance="[0.95,0.0,0.95]")]), [])

    def test_a_glass_clue_the_inverter_made_stale_proves_nothing_live(self):
        found = self.patterns(
            [
                decision(2, shot=None),
                decision(4, shot=None),
                decision(5, chamber="Blank", source="combined", shot="self", known="1B"),
                decision(7, shot="self"),
            ],
            clues=[(2, 2, "A", "glass", 0, "Live")],
        )
        self.assertEqual(found, [("opus", cm.Pattern.GAVE_TURN_AWAY, False)])

    def test_the_opponents_secret_proves_nothing_for_the_player(self):
        found = self.patterns(
            [decision(1, player="B", chamber="Live", source="glass", shot="opponent"), decision(2, player="A", shot="self")],
            clues=[(1, 1, "B", "glass", 0, "Live")],
        )
        self.assertEqual(found, [("sol", cm.Pattern.SELF_ON_LIVE, False)])

    def test_a_proven_blank_needs_both_kills_for_a_guaranteed_win(self):
        found = self.patterns(
            [
                decision(0, chamber="Blank", shot="opponent", known="1B 2L", hp=health(own=1, opponent=1)),
                decision(1, chamber="Blank", shot="opponent", known="1B 2L", hp=health(own=1, opponent=2)),
                decision(2, chamber="Blank", shot="opponent", known="1B 2L", hp=health(own=2, opponent=1)),
                decision(3, chamber="Blank", shot="opponent", known="1B"),
            ]
        )
        self.assertEqual([pattern for _, pattern, _ in found], [cm.Pattern.GAVE_UP_GUARANTEED_WIN] + [cm.Pattern.GAVE_TURN_AWAY] * 3)

    def test_a_jammed_opponent_with_a_proven_live_next_is_excluded_and_counted(self):
        found = self.load([decision(0, chamber="Blank", shot="opponent", known="1B 2L", hp=health(own=1, opponent=None))])
        self.assertEqual([d.pattern for d in found], [cm.Pattern.HIDDEN_HEALTH])
        self.assertIn("| all |  | – | – | 1 |", cm.certain(found))

    def test_the_turn_given_away_is_split_by_what_the_search_scored(self):
        found = self.load(
            [decision(0, chamber="Blank", shot="opponent"), decision(1, chamber="Blank", shot="opponent"), decision(2, chamber="Blank", shot="self")],
            searched=[(0, "e1", scores(400000, 500000)), (1, "e1", scores(1000000, 0))],
        )
        self.assertEqual([d.search for d in found], [cm.Search.OPPONENT_SHOT_HIGHER, cm.Search.SETTLED_FOR_SELF_SHOT, cm.Search.UNSEARCHED])

    def test_every_opportunity_is_written_with_its_outcome_and_source(self):
        decisions = [
            decision(0, chamber="Live", source="glass", shot="self"),
            decision(1, chamber="Live", source="public", shot="opponent"),
            decision(2, chamber="Blank", source="phone", shot="opponent", known="1B 2L"),
            decision(3, chamber="Blank", source="public", shot="opponent", known="1B 2L", hp=health(opponent=None)),
            decision(4, chamber="Blank", source="public", shot="opponent"),
            decision(5, chamber="Blank", source="combined", shot="self"),
            decision(6, shot="self", known="2B"),
        ]
        with tempfile.TemporaryDirectory() as directory:
            found = cm.load(*write(Path(directory), decisions))
            target = Path(directory) / "opportunities.sqlite"
            cm.write_opportunities(found, target)
            cm.write_opportunities(found, target)
            db = sqlite3.connect(target)
            rows = db.execute("SELECT * FROM opportunities ORDER BY ordinal").fetchall()
            db.close()
        self.assertEqual(
            rows,
            [
                ("m1", 0, "A", "self_on_live", "mistake", "glass"),
                ("m1", 1, "A", "self_on_live", "not a mistake", "public"),
                ("m1", 2, "A", "gave_up_guaranteed_win", "mistake", "phone"),
                ("m1", 3, "A", "hidden_health", "excluded", "public"),
                ("m1", 4, "A", "gave_turn_away", "fact pattern", "public"),
                ("m1", 5, "A", "gave_turn_away", "not a mistake", "combined"),
            ],
        )
        for pattern in (cm.Pattern.SELF_ON_LIVE, cm.Pattern.GAVE_UP_GUARANTEED_WIN):
            self.assertEqual(sum(r[3] == pattern.name.lower() and r[4] == "mistake" for r in rows), cm.rate(cm.of(found, pattern)).chose)

    def test_rows_of_two_evaluators_are_refused(self):
        with self.assertRaises(SystemExit):
            self.load([decision(0, chamber="Blank"), decision(1, chamber="Blank")], searched=[(0, "e1", scores(1, 2)), (1, "e2", scores(1, 2))])


class Cells(unittest.TestCase):
    def test_fewer_than_twenty_decisions_show_counts_only(self):
        self.assertEqual(cm.Rate(3, 1, (0.0, 1.0)).cell(), "1/3")
        self.assertEqual(cm.Rate(20, 1, (0.0, 0.1)).cell(), "5.0% (1/20) [0.0%, 10.0%]")


class GuaranteedWin(unittest.TestCase):
    def test_a_saw_lets_either_side_kill_from_two_health(self):
        self.assertTrue(cm.guaranteed_win(own_health=2, opponent_health=2, own_saw=True, opponent_saw=True))
        self.assertFalse(cm.guaranteed_win(own_health=2, opponent_health=2, own_saw=True, opponent_saw=False))
        self.assertFalse(cm.guaranteed_win(own_health=2, opponent_health=2, own_saw=False, opponent_saw=True))


if __name__ == "__main__":
    unittest.main()
