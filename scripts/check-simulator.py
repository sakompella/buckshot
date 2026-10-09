#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import random
import sys
import types
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Check the simulator for crashes, wrong counts, and seat bias."
    )
    parser.add_argument("--sim", type=Path, default=Path("_work/sim"))
    parser.add_argument("--trials", type=int, default=20000)
    args = parser.parse_args()
    source_dir = args.sim.resolve() / "src"
    sys.path.insert(0, str(source_dir))
    import game
    import stratagem as strat

    result = {}
    for name, strategy in [
        ("opponent", strat.TriggerHappy),
        ("self_blank", strat.Suicidal),
    ]:
        match = game.Match(1, 1, 2, strategy(), strategy())
        match._shell_order = [False] if name == "self_blank" else [True]
        try:
            match.play()
        except AttributeError as error:
            result[f"stock_{name}_error"] = str(error)
        else:
            raise AssertionError("Expected the stock enum mismatch")

    match = game.Match(2, 4, 3, strat.Safe(), strat.Safe())
    before = vars(match._state).copy()
    match._reload()
    result["reload_counts"] = {
        "before": before,
        "after": vars(match._state).copy(),
        "actual_live": sum(match._shell_order),
        "actual_blank": len(match._shell_order) - sum(match._shell_order),
        "safe_next_move": strat.Safe().get_move(match._state).name,
    }
    assert result["reload_counts"]["after"] == {"blank_shells": 4, "live_shells": 2}

    source = (source_dir / "game.py").read_text()
    compatible = types.ModuleType("enum_compatible_game")
    exec(
        compile(
            source.replace("SHOOT_OPPO", "SHOOT_OPP"),
            str(source_dir / "game.py"),
            "exec",
        ),
        compatible.__dict__,
    )
    corrected = types.ModuleType("count_corrected_game")
    corrected_source = source.replace("SHOOT_OPPO", "SHOOT_OPP").replace(
        "GameState(self._load[0], self._load[1])",
        "GameState(self._load[1], self._load[0])",
    )
    exec(compile(corrected_source, "count_corrected_game", "exec"), corrected.__dict__)

    exhausted = compatible.Match(2, 4, 3, strat.Safe(), strat.Safe())
    exhausted._reload()
    exhausted._shell_order = [True] * 4 + [False] * 2
    for _ in range(6):
        exhausted._get_outcome(strat.Move.SHOOT_OPP)
    result["counts_after_full_asymmetric_reload"] = vars(exhausted._state)
    assert result["counts_after_full_asymmetric_reload"] == {
        "blank_shells": 2,
        "live_shells": -2,
    }

    invariant_failures = []
    for blanks in range(1, 9):
        for lives in range(1, 9):
            sample = game.Match(blanks, lives, 3, strat.Safe(), strat.Safe())
            assert sample._state.live_shells == sum(sample._shell_order)
            assert sample._state.blank_shells == len(sample._shell_order) - sum(
                sample._shell_order
            )
            sample._reload()
            if sample._state.live_shells != sum(sample._shell_order):
                invariant_failures.append([blanks, lives])
    result["reload_count_invariant"] = {
        "cases": 64,
        "failures": len(invariant_failures),
        "failing_blanks_lives": invariant_failures,
    }
    assert len(invariant_failures) == 56

    result["seat_complement_counterexample"] = {
        "scared_p1_vs_trigger_happy_p2": compatible.Match(
            0, 1, 1, strat.Scared(), strat.TriggerHappy()
        ).play(),
        "trigger_happy_p1_vs_scared_p2": compatible.Match(
            0, 1, 1, strat.TriggerHappy(), strat.Scared()
        ).play(),
    }
    assert all(result["seat_complement_counterexample"].values())

    result["monte_carlo"] = []
    for blanks, lives in [(4, 4), (2, 4), (1, 4)]:
        for first, second in [
            (strat.Safe, strat.Greedy),
            (strat.Safe, strat.Scared),
            (strat.Scared, strat.Safe),
        ]:
            row = {
                "blanks": blanks,
                "lives": lives,
                "health": 3,
                "p1": first.__name__,
                "p2": second.__name__,
                "trials": args.trials,
                "seed": 20261012,
            }
            for variant, engine in [
                ("enum_only", compatible),
                ("enum_and_counts", corrected),
            ]:
                random.seed(20261012)
                wins = sum(
                    engine.Match(blanks, lives, 3, first(), second()).play()
                    for _ in range(args.trials)
                )
                row[variant] = wins / args.trials
            result["monte_carlo"].append(row)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
