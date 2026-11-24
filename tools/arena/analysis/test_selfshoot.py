"""Tests for the findings numbers: python3 -m unittest discover -s tools/arena/analysis"""

import json
import tempfile
import unittest
from fractions import Fraction
from itertools import combinations
from pathlib import Path

import numpy as np
import selfshoot as ss
from testdb import ANALYSIS, KNOWLEDGE, REGRET, database, events, insert, rounds

SEEDS = ss.Seeds(range(1, 31))


def shot(
    seed=1,
    model="gpt-6-astra",
    effort="high",
    odds=Fraction(1, 3),
    self_shot=True,
    search_self=0.0,
):
    return ss.Shot(seed, model, effort, odds, self_shot, search_self)


def decision(seed=1, model="m", effort="high", position="p", lost=1.0, missed=False):
    return ss.Decision(seed, model, effort, position, lost, missed)


class Resampling(unittest.TestCase):
    def test_the_same_seeds_give_the_same_resamples(self):
        a, b = ss.Seeds([5, 3, 9]), ss.Seeds([9, 5, 3])
        self.assertTrue((a.counts == b.counts).all())
        self.assertEqual(a.counts.shape, (2000, 3))
        self.assertTrue((a.counts.sum(axis=1) == 3).all())

    def test_seeds_with_one_rate_give_an_interval_that_is_a_point(self):
        sums = SEEDS.sums(((seed, (2, 1)) for seed in range(1, 31)), 2)
        self.assertEqual(
            SEEDS.estimate(sums, lambda a: a[1] / a[0]), ss.Estimate(0.5, 0.5, 0.5)
        )

    def test_the_interval_of_a_spread_rate_brackets_it(self):
        sums = SEEDS.sums(((seed, (1, seed % 2)) for seed in range(1, 31)), 2)
        e = SEEDS.estimate(sums, lambda a: a[1] / a[0])
        self.assertEqual(e.value, 0.5)
        self.assertLess(e.lo, 0.5)
        self.assertGreater(e.hi, 0.5)

    def test_resamples_without_a_denominator_are_left_out_not_counted_as_nan(self):
        sums = SEEDS.sums([(1, (1, 1))], 2)
        e = SEEDS.estimate(sums, lambda a: a[1] / a[0])
        self.assertEqual(e, ss.Estimate(1.0, 1.0, 1.0))


class Shots(unittest.TestCase):
    def test_the_search_prefers_the_higher_score_and_splits_a_tie(self):
        self.assertEqual(
            [ss.search_self(5, 3), ss.search_self(3, 5), ss.search_self(4, 4)],
            [1.0, 0.0, 0.5],
        )

    def test_scores_are_read_for_self_and_the_one_opponent_whatever_the_items(self):
        values = json.dumps(
            [
                {"label": "Use beer", "score": 9},
                {"label": "Shoot Player B", "score": 3},
                {"label": "Shoot yourself", "score": 5},
            ]
        )
        self.assertEqual(ss.shot_scores(values), (5, 3))

    def test_two_opponents_stop_the_analysis(self):
        values = json.dumps(
            [
                {"label": "Shoot yourself", "score": 1},
                {"label": "Shoot Player A", "score": 2},
                {"label": "Shoot Player C", "score": 3},
            ]
        )
        with self.assertRaises(ValueError):
            ss.shot_scores(values)

    def test_a_model_outside_the_groups_stops_the_analysis(self):
        self.assertRaises(ValueError, lambda: shot(model="deepseek").group)

    def test_every_model_of_a_shot_group_is_in_one(self):
        self.assertEqual(
            {shot(model=m).group for m in ss.GROUP_OF}, {ss.STRONG, ss.HAIKU, ss.LUNA}
        )


SELF_LOW = {"Shoot yourself": 200_000, "Shoot Player B": 500_000}
PANEL = [decision(1, "m", "low", "p", 3.0), decision(1, "m", "high", "p", 1.0)]


class Rates(unittest.TestCase):
    def test_rates_and_gap_over_the_shots(self):
        shots = [
            shot(self_shot=True, search_self=0.0),
            shot(self_shot=True, search_self=0.5),
            shot(self_shot=True, search_self=0.0),
            shot(self_shot=False, search_self=1.0),
        ]
        r = ss.rates(shots, SEEDS)
        self.assertEqual(
            (r.models.value, r.search.value, r.gap.value), (0.75, 0.375, 0.375)
        )

    def test_the_headline_counts_clean_shots_below_even_and_the_strong_among_them(self):
        shots = [
            shot(model="gpt-6-astra", odds=Fraction(1, 3), self_shot=True),
            shot(model="gpt-6-astra", odds=Fraction(1, 4), self_shot=True),
            shot(model="claude-haiku-5-5", odds=Fraction(2, 5), self_shot=False),
            shot(model="gpt-6-luna", odds=Fraction(1, 5), self_shot=False),
            shot(model="gpt-6-astra", odds=Fraction(1, 2), self_shot=False),
            shot(model="gpt-6-astra", odds=Fraction(2, 3), self_shot=False),
        ]
        h = ss.headline(PANEL, shots, SEEDS)
        self.assertEqual((h["cleanShotsN"], h["strongN"]), (4, 2))
        self.assertEqual((h["modelRate"], h["strongModelRate"]), (0.5, 1.0))
        self.assertEqual(h["gap"], 0.5)
        self.assertEqual(h["strongGap"], 1.0)

    def test_missed_items_are_their_share_of_all_points_lost(self):
        decisions = [
            decision(lost=3.0, missed=True),
            decision(lost=1.0),
            decision(lost=4.0),
        ]
        h = ss.headline(decisions + PANEL, [shot()], SEEDS)
        self.assertEqual(h["missedItemLossShare"], 3 / 12)


class Curve(unittest.TestCase):
    def test_fifths_pool_with_their_neighbours_and_every_shot_is_in_a_row(self):
        shots = [
            shot(odds=Fraction(1, 5)),
            shot(odds=Fraction(1, 4)),
            shot(odds=Fraction(4, 5)),
            shot(odds=Fraction(3, 4)),
            shot(odds=Fraction(1, 3), model="gpt-6-luna"),
        ]
        rows = ss.curve(shots, SEEDS)
        self.assertEqual(
            [(r["group"], r["pLabel"], r["n"]) for r in rows],
            [
                ("strong", "1/4", 2),
                ("strong", "3/4", 2),
                ("luna", "1/3", 1),
            ],
        )
        self.assertEqual(sum(r["n"] for r in rows), len(shots))

    def test_rows_run_strong_haiku_luna_with_odds_rising(self):
        shots = [
            shot(model="gpt-6-luna", odds=Fraction(1, 2)),
            shot(model="claude-haiku-5-5", odds=Fraction(2, 3)),
            shot(model="claude-haiku-5-5", odds=Fraction(1, 3)),
            shot(model="gpt-6-astra", odds=Fraction(3, 5)),
        ]
        rows = ss.curve(shots, SEEDS)
        self.assertEqual(
            [(r["group"], r["pLive"]) for r in rows],
            [
                ("strong", 0.6),
                ("haiku", 0.3333),
                ("haiku", 0.6667),
                ("luna", 0.5),
            ],
        )

    def test_a_row_has_a_rate_and_an_interval_for_models_and_for_the_search(self):
        (row,) = ss.curve([shot(self_shot=True, search_self=0.0)], SEEDS)
        self.assertEqual(
            (row["modelRate"], row["modelLo"], row["modelHi"]), (1.0, 1.0, 1.0)
        )
        self.assertEqual(
            (row["searchRate"], row["searchLo"], row["searchHi"]), (0.0, 0.0, 0.0)
        )


class SonnetEffort(unittest.TestCase):
    def test_only_sonnet_shots_below_even_by_effort_in_ladder_order(self):
        sonnet = "claude-sonnet-5-5"
        shots = [
            shot(model=sonnet, effort="max", self_shot=False, search_self=0.0),
            shot(model=sonnet, effort="off", self_shot=True, search_self=0.0),
            shot(model=sonnet, effort="off", self_shot=True, search_self=1.0),
            shot(model=sonnet, effort="high", odds=Fraction(1, 2)),
            shot(model="gpt-6-astra", effort="low"),
        ]
        rows = ss.sonnet_effort(shots, SEEDS)
        self.assertEqual(
            [(r["effort"], r["n"]) for r in rows], [("off", 2), ("max", 1)]
        )
        self.assertEqual((rows[0]["modelRate"], rows[0]["searchRate"]), (1.0, 0.5))
        self.assertEqual(rows[0]["gap"], 0.5)


class EffortSlope(unittest.TestCase):
    def pair(self, position, seed=1, model="m", low=3.0, high=1.0):
        return [
            decision(seed, model, "low", position, low),
            decision(seed, model, "high", position, high),
        ]

    def test_the_slope_is_per_step_within_a_position_and_a_lone_effort_is_left_out(
        self,
    ):
        decisions = (
            self.pair("a")
            + self.pair("b", seed=2)
            + [
                decision(3, "m", "high", "c", 100.0),
                decision(3, "m", "high", "c", 0.0),
            ]
        )
        within, _ = ss.fixed_position_slope(decisions, SEEDS)
        self.assertEqual(within.value, -1.0)

    def test_the_same_position_under_two_models_is_two_groups(self):
        decisions = [
            decision(1, "m", "low", "a", 3.0),
            decision(1, "n", "high", "a", 1.0),
        ]
        with self.assertRaises(ValueError):
            ss.fixed_position_slope(decisions, SEEDS)

    def test_a_merged_effort_counts_at_its_weakest_step(self):
        decisions = [
            decision(1, "m", "off/low", "a", 3.0),
            decision(1, "m", "off/low", "a", 1.0),
            decision(1, "m", "high", "a", 1.0),
        ]
        within, _ = ss.fixed_position_slope(decisions, SEEDS)
        self.assertAlmostEqual(within.value, -1 / 3)

    def test_share_of_raw_is_the_within_slope_over_the_slope_across_all_decisions(self):
        decisions = self.pair("a") + [
            decision(1, "m", "off", "x", 5.0),
            decision(1, "m", "max", "y", 0.0),
        ]
        _, share = ss.fixed_position_slope(decisions, SEEDS)
        self.assertAlmostEqual(share, -1 / (-14.25 / 14.75))

    def test_raw_slope_is_taken_within_each_model(self):
        decisions = self.pair("a") + [
            decision(1, "n", "off", "x", 5.0),
            decision(1, "n", "max", "y", 0.0),
        ]
        _, share = ss.fixed_position_slope(decisions, SEEDS)
        pooled = (-2.0 - 25.0) / (2.0 + 25.0)
        self.assertAlmostEqual(share, -1 / pooled)


class VarianceComponents(unittest.TestCase):
    def test_balanced_data_gives_the_analysis_of_variance_estimates(self):
        configs, seeds, reps = 5, 6, 4
        rng = np.random.default_rng(3)
        c = rng.normal(0, 2.0, configs)[:, None, None]
        s = rng.normal(0, 1.5, seeds)[None, :, None]
        cs = rng.normal(0, 1.2, (configs, seeds))[:, :, None]
        e = rng.normal(0, 0.5, (configs, seeds, reps))
        y = 10 + c + s + cs + e
        grand = y.mean()
        cm, sm = y.mean(axis=(1, 2)), y.mean(axis=(0, 2))
        cell = y.mean(axis=2)
        ms_c = seeds * reps * ((cm - grand) ** 2).sum() / (configs - 1)
        ms_s = configs * reps * ((sm - grand) ** 2).sum() / (seeds - 1)
        interaction = cell - cm[:, None] - sm[None, :] + grand
        ms_cs = reps * (interaction**2).sum() / ((configs - 1) * (seeds - 1))
        ms_e = ((y - cell[:, :, None]) ** 2).sum() / (configs * seeds * (reps - 1))
        expected = [
            (ms_c - ms_cs) / (seeds * reps),
            (ms_s - ms_cs) / (configs * reps),
            (ms_cs - ms_e) / reps,
            ms_e,
        ]
        self.assertTrue(all(v > 0 for v in expected))
        config_of, seed_of, rep_of = np.indices(y.shape)
        got = ss.reml(
            y.ravel(),
            [
                config_of.ravel(),
                seed_of.ravel(),
                (config_of * seeds + seed_of).ravel(),
            ],
        )
        for g, x in zip(got, expected):
            self.assertAlmostEqual(g, x, delta=0.002 * max(x, 1.0))
        self.assertEqual(rep_of.shape, y.shape)

    def test_a_factor_with_no_effect_is_estimated_at_zero(self):
        configs, seeds, reps = 6, 5, 3
        rng = np.random.default_rng(5)
        c = rng.normal(0, 2.0, configs)[:, None, None]
        y = c + rng.normal(0, 0.5, (configs, seeds, reps))
        config_of, seed_of, _ = np.indices(y.shape)
        got = ss.reml(
            y.ravel(),
            [config_of.ravel(), seed_of.ravel(), (config_of * seeds + seed_of).ravel()],
        )
        self.assertLess(got[1], 1e-4)
        self.assertGreater(got[0], 1.0)

    def test_seeds_needed_follow_the_reliability_formula(self):
        c = ss.Components(config=1.0, seed=0.5, config_seed=0.3, residual=1.4)
        self.assertAlmostEqual(c.seeds_for(0.8), 4.0)
        self.assertAlmostEqual(c.seeds_for(0.9), 9.0)
        reliability = 1 / (1 + (0.3 + 1.4 / ss.PER_SEED) / c.seeds_for(0.8))
        self.assertAlmostEqual(reliability, 0.8)

    def test_codes_number_the_distinct_values_in_order(self):
        self.assertEqual(ss.codes([("b", 1), ("a", 2), ("b", 1)]).tolist(), [1, 0, 1])


def seat(config, seed, lost, rounds_won):
    return ss.SeatMatch(seed, config, lost, rounds_won)


class GStudy(unittest.TestCase):
    def seats(self):
        rng = np.random.default_rng(11)
        out = []
        for n, config in enumerate([("m", str(i)) for i in range(6)]):
            for seed in range(3000, 3008):
                for _ in range(2):
                    out.append(
                        seat(
                            config,
                            seed,
                            0.4 * n + rng.normal(0, 0.3),
                            min(1.0, max(0.0, 0.1 * n + rng.normal(0.2, 0.3))),
                        )
                    )
        return out

    def test_it_reports_the_panel_size_shares_that_sum_to_one_and_the_seeds_needed(
        self,
    ):
        g = ss.g_study(self.seats())
        self.assertEqual((g["configs"], g["seeds"]), (6, 8))
        for metric in ("rounds", "regret"):
            self.assertAlmostEqual(sum(g[metric].values()), 1.0, delta=0.0005)
        self.assertLess(g["seedsG80"]["regret"], g["seedsG90"]["regret"])
        self.assertLess(g["seedsG80"]["regret"], g["seedsG80"]["rounds"])
        self.assertGreater(g["ratioAll"], 1.0)
        self.assertGreater(g["ratioTop14"], 0.0)


def world(directory: str):
    """Five configs playing each other on eight panel seeds; each seat has one clean shot below even, one opponent shot and one item move. Returns the three database paths."""
    configs = [
        ("claude-sonnet-5-5", "max"),
        ("claude-sonnet-5-5", "off"),
        ("gpt-6-luna", "high"),
        ("claude-sonnet-5-5", "low"),
        ("claude-haiku-5-5", "medium"),
    ]
    base = Path(directory)
    main = database(base / "buckshot.sqlite", ANALYSIS)
    knowledge = database(base / "knowledge.sqlite", KNOWLEDGE)
    out = database(base / "regret.sqlite", REGRET)
    for seed in range(3000, 3008):
        for i, j in combinations(range(len(configs)), 2):
            match = f"match-{seed}-{i}{j}"
            insert(
                knowledge,
                "matches",
                match_id=match,
                status="completed",
                seed=seed,
            )
            winners = [0, 0, 1] if (seed + i) % 3 else [0, 0, 0]
            events(main, match, *rounds(*winners))
            ordinal = 0
            for player, position, c in (("A", 1, i), ("B", 2, j)):
                model, effort = configs[c]
                insert(
                    main,
                    "match_seats",
                    match_id=match,
                    position=position,
                    player=player,
                    socket=position - 1,
                    label=f"{model}-{effort}",
                )
                insert(
                    knowledge,
                    "players",
                    match_id=match,
                    player=player,
                    position=position,
                    model=model,
                    effort=effort,
                )
                for shot_kind, labels in (
                    ("self", {"Shoot yourself": 480_000, "Shoot Player B": 500_000}),
                    (
                        "opponent",
                        {"Shoot yourself": 480_000, "Shoot Player B": 500_000},
                    ),
                    (
                        None,
                        {
                            "Use beer": 600_000,
                            "Shoot yourself": 500_000,
                            "Shoot Player B": 450_000,
                        },
                    ),
                ):
                    chosen = {
                        "self": "Shoot yourself",
                        "opponent": "Shoot Player B",
                        None: "Use beer",
                    }[shot_kind]
                    best = max(labels.values())
                    insert(
                        knowledge,
                        "decisions",
                        match_id=match,
                        ordinal=ordinal,
                        player=player,
                        by_whom="agent",
                        shot=shot_kind,
                        sawed=0,
                        private_orders=3,
                        private_live_json="[1]",
                        health_json='[{"_tag":"Unjammed","health":3},{"_tag":"Unjammed","health":3}]',
                        exact_key=f"{seed}-{ordinal}",
                    )
                    insert(
                        out,
                        "regret",
                        match_id=match,
                        ordinal=ordinal,
                        player=player,
                        evaluator="e",
                        max_depth=7,
                        budget=1,
                        reload="static",
                        samples=0,
                        status="searched",
                        values_json=json.dumps(
                            [{"label": k, "score": v} for k, v in labels.items()]
                        ),
                        best_score=best,
                        chosen_score=labels[chosen],
                        regret=best
                        - labels[chosen]
                        + 3_000 * c * ((seed + ordinal) % 2),
                    )
                    ordinal += 1
    for db in (main, knowledge, out):
        db.commit()
        db.close()
    return (
        str(base / "buckshot.sqlite"),
        base / "regret.sqlite",
        base / "knowledge.sqlite",
    )


class Load(unittest.TestCase):
    def one_match(self, directory, *decisions, disposition=None, status="searched"):
        """One match, seed 7, player A of sonnet at effort low deciding each of `decisions`: (by_whom, shot, chamber, sawed, jammed, scores)."""
        knowledge = database(Path(directory) / "knowledge.sqlite", KNOWLEDGE)
        out = database(Path(directory) / "regret.sqlite", REGRET)
        insert(
            knowledge,
            "matches",
            match_id="m",
            status="completed",
            disposition=disposition,
            seed=7,
        )
        insert(
            knowledge,
            "players",
            match_id="m",
            player="A",
            position=1,
            model="claude-sonnet-5-5",
            effort="low",
        )
        for ordinal, (by_whom, shot_kind, chamber, sawed, jammed, scores) in enumerate(
            decisions
        ):
            tag = "Jammed" if jammed else "Unjammed"
            insert(
                knowledge,
                "decisions",
                match_id="m",
                ordinal=ordinal,
                player="A",
                by_whom=by_whom,
                shot=shot_kind,
                chamber=chamber,
                sawed=sawed,
                private_orders=3,
                private_live_json="[1]",
                health_json=json.dumps([{"_tag": "Unjammed"}, {"_tag": tag}]),
                exact_key=f"k{ordinal}",
            )
            best = max(scores.values())
            chosen = {
                "self": "Shoot yourself",
                "opponent": "Shoot Player B",
            }.get(shot_kind, "Use beer")
            insert(
                out,
                "regret",
                match_id="m",
                ordinal=ordinal,
                player="A",
                evaluator="e",
                max_depth=7,
                budget=1,
                reload="static",
                samples=0,
                status=status,
                values_json=json.dumps(
                    [{"label": k, "score": v} for k, v in scores.items()]
                ),
                best_score=best,
                chosen_score=scores[chosen],
                regret=best - scores[chosen],
            )
        for db in (knowledge, out):
            db.commit()
            db.close()
        return Path(directory) / "regret.sqlite", Path(directory) / "knowledge.sqlite"

    def load(self, *decisions, **kwargs):
        with tempfile.TemporaryDirectory() as directory:
            regret_path, knowledge_path = self.one_match(
                directory, *decisions, **kwargs
            )
            return ss.load(regret_path, knowledge_path)

    def test_a_clean_unknown_chamber_shot_is_read_with_its_odds_and_the_searchs_preference(
        self,
    ):
        _, shots = self.load(("agent", "self", None, 0, False, SELF_LOW))
        self.assertEqual(
            shots,
            [ss.Shot(7, "claude-sonnet-5-5", "low", Fraction(1, 3), True, 0.0)],
        )

    def test_a_tied_search_prefers_self_by_half(self):
        tied = {"Shoot yourself": 300_000, "Shoot Player B": 300_000}
        _, (found,) = self.load(("agent", "opponent", None, 0, False, tied))
        self.assertEqual((found.self_shot, found.search_self), (False, 0.5))

    def test_sawed_jammed_known_chamber_and_item_decisions_are_no_clean_shots(self):
        decisions, shots = self.load(
            ("agent", "self", None, 1, False, SELF_LOW),
            ("agent", "self", None, 0, True, SELF_LOW),
            ("agent", "self", "Blank", 0, False, SELF_LOW),
            ("agent", None, None, 0, False, {"Use beer": 1, **SELF_LOW}),
        )
        self.assertEqual((len(decisions), shots), (4, []))

    def test_decisions_of_bots_unscored_rows_and_excluded_matches_are_left_out(self):
        self.assertEqual(self.load(("bot", "self", None, 0, False, SELF_LOW))[0], [])
        self.assertEqual(
            self.load(("agent", "self", None, 0, False, SELF_LOW), status="skipped"),
            ([], []),
        )
        self.assertEqual(
            self.load(
                ("agent", "self", None, 0, False, SELF_LOW), disposition="excluded"
            ),
            ([], []),
        )

    def test_a_shot_below_every_item_is_a_missed_item_and_one_tying_the_best_is_not(
        self,
    ):
        decisions, _ = self.load(
            (
                "agent",
                "self",
                None,
                0,
                False,
                {"Use beer": 900_000, **SELF_LOW},
            ),
            (
                "agent",
                "opponent",
                None,
                0,
                False,
                {"Use beer": 500_000, **SELF_LOW},
            ),
            ("agent", None, None, 0, False, {"Use beer": 100_000, **SELF_LOW}),
        )
        self.assertEqual(
            [(d.missed_item, d.lost) for d in decisions],
            [(True, 70.0), (False, 0.0), (False, 40.0)],
        )

    def test_a_decision_is_in_points_with_its_seed_position_and_merged_effort(self):
        (found,), _ = self.load(("agent", "self", None, 0, False, SELF_LOW))
        self.assertEqual(
            (found.seed, found.model, found.position, found.lost),
            (7, "claude-sonnet-5-5", "k0", 30.0),
        )
        self.assertEqual(found.effort, ss.config_effort("claude-sonnet-5-5", "low"))


class Panel(unittest.TestCase):
    def test_seat_matches_carry_mean_points_and_the_share_of_rounds_won(self):
        with tempfile.TemporaryDirectory() as directory:
            db, regret_path, knowledge_path = world(directory)
            seats = ss.seat_matches(db, regret_path, knowledge_path)
        self.assertEqual(len(seats), 8 * 10 * 2)
        self.assertEqual({s.seed for s in seats}, set(range(3000, 3008)))
        first = next(
            s
            for s in seats
            if s.seed == 3000 and s.config == ("claude-sonnet-5-5", "max")
        )
        self.assertAlmostEqual(first.rounds, 1.0)
        self.assertTrue(all(0.0 <= s.rounds <= 1.0 for s in seats))

    def test_seeds_off_the_panel_are_left_out(self):
        with tempfile.TemporaryDirectory() as directory:
            db, regret_path, knowledge_path = world(directory)
            knowledge = database(Path(knowledge_path), "")
            knowledge.execute("UPDATE matches SET seed = 5 WHERE seed = 3000")
            knowledge.commit()
            knowledge.close()
            seats = ss.seat_matches(db, regret_path, knowledge_path)
        self.assertEqual(len(seats), 7 * 10 * 2)


class Build(unittest.TestCase):
    def built(self):
        with tempfile.TemporaryDirectory() as directory:
            db, regret_path, knowledge_path = world(directory)
            return ss.build(db, regret_path, knowledge_path)

    def test_the_findings_have_the_page_schema(self):
        found = self.built()
        self.assertEqual(
            list(found), ["generated", "headline", "curve", "sonnetEffort", "gStudy"]
        )
        self.assertEqual(
            list(found["headline"]),
            [
                "cleanShotsN", "modelRate", "searchRate", "gap", "gapLo", "gapHi",
                "strongN", "strongModelRate", "strongSearchRate", "strongGap",
                "strongGapLo", "strongGapHi", "missedItemLossShare",
                "missedItemLossLo", "missedItemLossHi", "fixedPosEffortSlope",
                "fixedPosEffortLo", "fixedPosEffortHi", "fixedPosEffortShareOfRaw",
            ],
        )  # fmt: skip
        self.assertEqual(
            list(found["curve"][0]),
            [
                "group", "pLive", "pLabel", "n", "modelRate", "modelLo", "modelHi",
                "searchRate", "searchLo", "searchHi",
            ],
        )  # fmt: skip
        self.assertEqual(
            list(found["sonnetEffort"][0]),
            ["effort", "n", "modelRate", "searchRate", "gap", "gapLo", "gapHi"],
        )
        self.assertEqual(
            list(found["gStudy"]),
            [
                "configs", "seeds", "rounds", "regret", "seedsG80", "seedsG90",
                "ratioAll", "ratioTop14",
            ],
        )  # fmt: skip
        self.assertEqual(
            list(found["gStudy"]["rounds"]),
            ["config", "seed", "configSeed", "residual"],
        )

    def test_the_numbers_follow_from_the_shots_of_the_world(self):
        found = self.built()
        self.assertEqual(found["headline"]["cleanShotsN"], 8 * 10 * 2 * 2)
        self.assertEqual(found["headline"]["strongN"], 8 * 4 * 3 * 2)
        self.assertEqual(sum(r["n"] for r in found["curve"]), 8 * 10 * 2 * 2)
        self.assertEqual((found["gStudy"]["configs"], found["gStudy"]["seeds"]), (5, 8))
        self.assertEqual(found["headline"]["modelRate"], 0.5)
        self.assertEqual(found["headline"]["searchRate"], 0.0)

    def test_the_findings_hold_no_match_ids_and_every_number_is_finite_json(self):
        text = json.dumps(self.built(), allow_nan=False)
        self.assertNotIn("match-", text)

    def test_rounded_floats_have_at_most_four_places(self):
        self.assertEqual(ss.rounded(1 / 3), 0.3333)
        self.assertEqual(ss.rounded(float(Fraction(2, 3))), 0.6667)
        self.assertEqual(ss.rounded(28.714, 1), 28.7)


if __name__ == "__main__":
    unittest.main()
