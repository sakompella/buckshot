"""Starter and seed effects in minimax self-play (docs/arena/analysis/matchups.md, "Minimax self-play").

Reads the JSON lines that web/scripts/arena-selfplay.ts writes and prints markdown tables: the round 1 starter's round and
match win share, the share of each round's starter by round, and the observed spread of seeds' shares. Every
interval is a 95% bootstrap that draws whole seeds, never single matches. Nothing here tests a seed effect: games of a seed
(swap pairs, reps) share a random stream, so they are not independent. Results describe this bot, not the game.

    python3 tools/arena/analysis/selfplay.py [--arena-doc docs/arena/analysis/matchups.md] <label>=<file.jsonl> ...

A run whose seeds all appear in the doc's per-seed table (the arena's seeds) also gets a per-seed table set beside the
arena's own starter shares.
"""

import argparse
import json
import random
import re
import statistics
from collections import defaultdict
from pathlib import Path

import boot
from fmt import frac, pct, span, table
from stats import pearson, ranks



def load(path: Path) -> list[dict]:
    games = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    for game in games:
        if any(round_["winner"] == 0 for round_ in game["rounds"]):
            raise ValueError(f"{path}: seed {game['seed']} has a round with no winner")
    settings = {(game["depth"], game["budget"], game["tieRule"]) for game in games}
    if len(settings) > 1:
        raise ValueError(f"{path}: matches played with mixed settings {sorted(settings)}")
    return games


def by_seed(games: list[dict], outcome) -> dict[int, list[float]]:
    """The outcome of every game, grouped by seed. Games for which `outcome` is None are left out."""
    groups: dict[int, list[float]] = defaultdict(list)
    for game in games:
        value = outcome(game)
        if value is not None:
            groups[game["seed"]].append(value)
    return dict(groups)


def starter_round_win(game: dict, round_: int = 1, of: int | None = None) -> float | None:
    """1 when the starter of round `of` (default: the same round) wins round `round_`, if the match played it."""
    if len(game["rounds"]) < round_:
        return None
    starter = game["rounds"][(of or round_) - 1]["starter"]
    return 1.0 if game["rounds"][round_ - 1]["winner"] == starter else 0.0


def starter_match_win(game: dict) -> float:
    """The round 1 starter's share of the match: 1 for more cash, a half for a tie."""
    starter = game["rounds"][0]["starter"] - 1
    mine, theirs = game["cash"][starter], game["cash"][1 - starter]
    return 1.0 if mine > theirs else 0.5 if mine == theirs else 0.0


def position_one_match_win(game: dict) -> float:
    mine, theirs = game["cash"]
    return 1.0 if mine > theirs else 0.5 if mine == theirs else 0.0


def mean_of(groups: dict[int, list[float]]) -> float:
    return sum(map(sum, groups.values())) / sum(map(len, groups.values()))


def bootstrap(groups: dict[int, list[float]], statistic, rng: random.Random) -> tuple[float, tuple[float, float] | None]:
    """The statistic of the groups and its 95% interval over resamples that draw whole seeds."""
    seeds = list(groups)
    replicates = [statistic({i: groups[rng.choice(seeds)] for i in range(len(seeds))}) for _ in range(boot.DRAWS)]
    return statistic(groups), boot.interval(replicates)


def share(groups: dict[int, list[float]], rng: random.Random) -> str:
    """wins/games = share (95% CI, seeds drawn)."""
    _, interval = bootstrap(groups, mean_of, rng)
    wins, games = sum(map(sum, groups.values())), sum(map(len, groups.values()))
    return f"{frac(wins, games)} ({span(interval)})"


def arena_shares(doc: Path) -> dict[int, tuple[int, float]]:
    """The arena's per-seed rows with 10 or more complete blocks: seed to (arena starter position, starter's match share)."""
    rows = re.findall(r"^\| (\d{4}) \| (\d) \| (\d+) \| (\d+)/(\d+) = [\d.]+% \|$", doc.read_text(), re.MULTILINE)
    return {int(seed): (int(position), int(wins) / int(games)) for seed, position, blocks, wins, games in rows if int(blocks) >= 10}


def run_info(games: list[dict]) -> str:
    decisions = sum(game["decisions"] for game in games)
    seeds = len({game["seed"] for game in games})
    depth = f"depth {games[0]['depth']}, budget {games[0]['budget']}, ties {games[0]['tieRule']}"
    return (
        f"{len(games)} matches over {seeds} seeds ({depth}). {decisions / len(games):.1f} analysed decisions a match, "
        f"mean depth finished {sum(game['depthSum'] for game in games) / decisions:.2f}, "
        f"{pct(sum(game['limited'] for game in games) / decisions)} stopped by the budget, "
        f"{pct(sum(game['ties'] for game in games) / decisions)} had equal best moves."
    )


def headline(games: list[dict], rng: random.Random) -> str:
    rows = [
        ["round 1 starter wins round 1", share(by_seed(games, starter_round_win), rng)],
        ["round 1 starter wins the match (a tie counts half)", share(by_seed(games, starter_match_win), rng)],
        ["position 1 wins the match", share(by_seed(games, position_one_match_win), rng)],
    ]
    return table(["measure", "wins/matches = share (95% CI, seeds drawn)"], rows)


def by_round(games: list[dict], rng: random.Random) -> str:
    rows = []
    for round_ in (1, 2, 3):
        own = by_seed(games, lambda game, r=round_: starter_round_win(game, r))
        first = by_seed(games, lambda game, r=round_: starter_round_win(game, r, of=1))
        rows.append([str(round_), share(own, rng), share(first, rng)])
    return table(["round", "its own starter wins it", "the round 1 starter wins it"], rows)


def spread(games: list[dict]) -> str:
    """The observed spread of the seeds' own shares. Games of a seed share a random stream, so this is description, not an estimate of true seed effects."""
    rows = []
    for name, outcome in (("round 1", starter_round_win), ("match", starter_match_win)):
        groups = by_seed(games, outcome)
        shares = [statistics.fmean(values) for values in groups.values()]
        rows.append([name, f"{statistics.fmean(map(len, groups.values())):.1f}", f"{statistics.pstdev(shares) * 100:.1f}"])
    return table(["starter's win in", "matches per seed", "SD of the seeds' observed shares, points"], rows)


def openings(games: list[dict], rng: random.Random) -> str:
    """The round 1 starter's own score at its first analysed decision, as a win share."""
    scores = by_seed(games, lambda game: next((o["score"] / 1e6 for o in game["openings"] if o["round"] == 1 and o["position"] == game["rounds"][0]["starter"]), None))
    wins = by_seed(games, starter_round_win)
    seeds = [seed for seed in scores if seed in wins]
    mean_scores = [statistics.fmean(scores[seed]) for seed in seeds]
    mean_wins = [statistics.fmean(wins[seed]) for seed in seeds]
    point, interval = bootstrap(scores, mean_of, rng)
    spread_ = statistics.pstdev(mean_scores)
    return table(
        ["the starter's opening score", "mean (95% CI, seeds drawn)", "SD over seeds", "seeds' correlation with the round 1 result"],
        [[f"{len(seeds)} seeds", f"{pct(point)} ({span(interval)})", f"{spread_ * 100:.1f} points", f"{pearson(mean_scores, mean_wins):+.2f}"]],
    )


def per_seed(games: list[dict], arena: dict[int, tuple[int, float]]) -> str:
    round_1, match = by_seed(games, starter_round_win), by_seed(games, starter_match_win)
    rows, mine, theirs = [], [], []
    for seed in sorted(match):
        wins, count = sum(match[seed]), len(match[seed])
        position, arena_share = arena[seed]
        rows.append([str(seed), str(position), str(count), frac(sum(round_1[seed]), count), frac(wins, count), pct(arena_share)])
        mine.append(wins / count)
        theirs.append(arena_share)
    summary = (
        f"Across the {len(rows)} seeds, the minimax starter's match share and the arena's starter share correlate at {pearson(mine, theirs):+.2f}, "
        f"by rank {pearson(ranks(mine), ranks(theirs)):+.2f}. This is descriptive over {len(rows)} seeds, with no test."
    )
    return table(["seed", "arena starter position", "matches", "starter wins round 1", "starter wins the match", "arena starter share"], rows) + "\n\n" + summary


def report(label: str, games: list[dict], arena: dict[int, tuple[int, float]]) -> str:
    rng = random.Random(label)
    parts = [f"### {label}", run_info(games), "Round 1 starter:", headline(games, rng), "By round:", by_round(games, rng), "Spread of the seeds' observed shares:", spread(games), "Opening score:", openings(games, rng)]
    if arena and {game["seed"] for game in games} <= arena.keys():
        parts += ["Per seed, set beside the arena's starter shares:", per_seed(games, arena)]
    return "\n\n".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("runs", nargs="+", metavar="LABEL=FILE", help="a run's label and its JSON lines")
    parser.add_argument("--arena-doc", type=Path, help="matchups.md, for the arena's per-seed starter shares")
    args = parser.parse_args()
    arena = arena_shares(args.arena_doc) if args.arena_doc else {}
    for run in args.runs:
        label, _, path = run.partition("=")
        print(report(label, load(Path(path)), arena), end="\n\n")


if __name__ == "__main__":
    main()
