#!/usr/bin/env python3

import argparse
import inspect
import math
import random
import sys
from dataclasses import dataclass
from typing import Literal

LOADS = ((2, 1), (2, 3), (2, 3), (3, 3), (2, 5))


@dataclass(frozen=True)
class Scenario:
    name: str
    dealer_policy: Literal["real", "random"]
    dealer_opens_first_load: bool


SCENARIOS = (
    Scenario("real dealer, player opens every load", "real", False),
    Scenario("random dealer (no last-shell certainty)", "random", False),
    Scenario("real dealer, dealer opens load 1 only", "real", True),
)


def dealer_target(
    remaining: int,
    last_shell_live: bool | None,
    policy: Literal["real", "random"],
    rng: random.Random,
) -> str:
    if policy == "real" and remaining == 1:
        assert last_shell_live is not None
        return "player" if last_shell_live else "self"
    return rng.choice(("self", "player"))


def play(
    strategy_cls, scenario: Scenario, rng: random.Random, strat_mod, hp: int = 2
) -> bool:
    player = strategy_cls()
    hp_player = hp_dealer = hp
    for load_index in range(10_000):
        blanks, lives = LOADS[min(load_index, len(LOADS) - 1)]
        shells = [True] * lives + [False] * blanks
        rng.shuffle(shells)
        dealer_turn = scenario.dealer_opens_first_load and load_index == 0
        while shells:
            live = sum(shells)
            if dealer_turn:
                last = shells[0] if len(shells) == 1 else None
                shoot_self = (
                    dealer_target(len(shells), last, scenario.dealer_policy, rng)
                    == "self"
                )
            else:
                state = strat_mod.GameState(len(shells) - live, live)
                shoot_self = player.get_move(state) == strat_mod.Move.SHOOT_SELF
            shell_live = shells.pop()
            if shell_live:
                if shoot_self == dealer_turn:
                    hp_dealer -= 1
                else:
                    hp_player -= 1
            if hp_player <= 0 or hp_dealer <= 0:
                return hp_dealer <= 0
            if not (shoot_self and not shell_live):
                dealer_turn = not dealer_turn
    raise RuntimeError("game did not finish")


def wilson(wins: int, n: int, z: float = 1.96) -> tuple[float, float]:
    p = wins / n
    centre = (p + z * z / (2 * n)) / (1 + z * z / n)
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return centre - half, centre + half


def selftest() -> None:
    for remaining in range(2, 9):
        for seed in range(50):
            picks = {
                dealer_target(remaining, hidden, policy, random.Random(seed))
                for policy in ("real", "random")
                for hidden in (None, True, False)
            }
            assert len(picks) == 1, (remaining, seed, picks)
    assert dealer_target(1, True, "real", random.Random(0)) == "player"
    assert dealer_target(1, False, "real", random.Random(0)) == "self"


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Compare the item-free campaign dealer against simulator policies."
    )
    ap.add_argument(
        "--simpath",
        required=True,
        help="directory holding the audited sim's stratagem.py",
    )
    ap.add_argument("--trials", type=int, default=20_000)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()
    selftest()
    sys.dont_write_bytecode = True
    sys.path.insert(0, args.simpath)
    import stratagem as strat_mod

    classes = sorted(
        (
            c
            for _, c in inspect.getmembers(strat_mod, inspect.isclass)
            if issubclass(c, strat_mod.Stratagem) and c is not strat_mod.Stratagem
        ),
        key=lambda c: c.__name__,
    )
    print(
        f"trials per cell n={args.trials} seed={args.seed} python={sys.version.split()[0]} simpath={args.simpath}"
    )
    print(
        "95% Wilson CI. Item-free batch_0 only. Player never uses items. Not an exact game win rate."
    )
    for scenario in SCENARIOS:
        print(f"\n== {scenario.name}")
        for cls in classes:
            rng = random.Random(f"{args.seed}/{scenario.name}/{cls.__name__}")
            strat_mod.randint = rng.randint
            wins = sum(play(cls, scenario, rng, strat_mod) for _ in range(args.trials))
            lo, hi = wilson(wins, args.trials)
            print(
                f"{cls.__name__:<13} win {wins / args.trials:6.1%}  CI [{lo:6.1%}, {hi:6.1%}]  n={args.trials} seed={args.seed}"
            )


if __name__ == "__main__":
    main()
