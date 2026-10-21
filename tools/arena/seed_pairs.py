#!/usr/bin/env python3
"""Win share of one entrant against another over complete seed pairs (both seat orders of a seed), with a 95%
bootstrap CI that resamples seed pairs (10,000 draws, fixed RNG seed). With --baseline, also compares the seeds
both directories played, as the change in the first entrant's share per seed and overall.

    python3 tools/arena/seed_pairs.py DIR ENTRANT OPPONENT [--baseline DIR ENTRANT OPPONENT]

For example, tournament-3 against tournament-1's Opus medium vs Astra:
    python3 tools/arena/seed_pairs.py T3 claude-opus-5-5-xhigh gpt-6-astra --baseline T1 claude-opus-5-5 gpt-6-astra
"""

import argparse
import json
import os
import random


def pairs(tdir: str, entrant: str, opponent: str) -> tuple[dict[int, list[int]], int]:
    """Per seed, 1 for each match the entrant won; only matches between exactly these two entrants count."""
    by_seed: dict[int, list[int]] = {}
    for match in json.load(open(os.path.join(tdir, "tournament.json")))["schedule"]:
        if sorted(match["entrants"]) != sorted([entrant, opponent]):
            continue
        path = os.path.join(tdir, match["name"], "manifest.json")
        if not os.path.exists(path) or json.load(open(path)).get("status") != "finished":
            continue
        manifest = json.load(open(path))
        winner = manifest["standings"][0]["player"]
        by_seed.setdefault(match["seed"], []).append(1 if match["entrants"][match["seats"].index(winner)] == entrant else 0)
    complete = {seed: v for seed, v in by_seed.items() if len(v) == 2}
    return complete, sum(1 for v in by_seed.values() if len(v) == 1)


def interval(values: dict[int, int], games: int, seed: int) -> tuple[float, float]:
    keys, rng = list(values), random.Random(seed)
    draws = sorted(sum(values[rng.choice(keys)] for _ in keys) / games for _ in range(10000))
    return draws[250], draws[9749]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("dir")
    parser.add_argument("entrant")
    parser.add_argument("opponent")
    parser.add_argument("--baseline", nargs=3, metavar=("DIR", "ENTRANT", "OPPONENT"))
    args = parser.parse_args()
    new, half = pairs(args.dir, args.entrant, args.opponent)
    games = 2 * len(new)
    won = sum(map(sum, new.values()))
    print(f"complete seed pairs {len(new)} ({games} matches), half pairs {half}")
    if new:
        lo, hi = interval({s: sum(v) for s, v in new.items()}, games, 1)
        print(f"{args.entrant} {won}, {args.opponent} {games - won}: share {won / games:.1%}, 95% CI {lo:.1%} to {hi:.1%}")
    if args.baseline:
        old, _ = pairs(*args.baseline)
        seeds = sorted(set(new) & set(old))
        if seeds:
            diffs = {s: sum(new[s]) - sum(old[s]) for s in seeds}
            a, b = sum(sum(new[s]) for s in seeds), sum(sum(old[s]) for s in seeds)
            lo, hi = interval(diffs, 2 * len(seeds), 2)
            print(f"matched seeds {len(seeds)}: {a}/{2 * len(seeds)} vs baseline {b}/{2 * len(seeds)}; per-seed change {diffs}")
            print(f"difference in share: {(a - b) / (2 * len(seeds)):+.1%}, 95% CI {lo:+.1%} to {hi:+.1%}")


if __name__ == "__main__":
    main()
