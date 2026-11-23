#!/usr/bin/env python3
"""Checks a tournament directory's finished matches: exit 1 if any had a fallback move, a failed audit flag, or an
endpoint outside URL_PREFIX. Prints finished matches, complete seed pairs and wins per seat label.

    python3 tools/arena/check_matches.py TOURNAMENT_DIR URL_PREFIX
"""

import json
import sys
from pathlib import Path


def check(tdir: Path, prefix: str) -> tuple[str, bool]:
    """The summary line for a tournament directory and whether any finished match is a problem."""
    schedule = json.loads((tdir / "tournament.json").read_text())["schedule"]
    bad, wins, by_seed = [], {}, {}
    for match in schedule:
        path = tdir / match["name"] / "manifest.json"
        if not path.exists():
            continue
        manifest = json.loads(path.read_text())
        if manifest.get("status") != "finished":
            continue
        by_seed.setdefault(
            (tuple(sorted(match["entrants"])), match["seed"]), []
        ).append(match["name"])
        agents = manifest["provenance"]["agents"]
        if (
            manifest["moves"].get("fallback", 0)
            or not all(manifest["audit"].values())
            or any(not a["url"].startswith(prefix) for a in agents.values())
        ):
            bad.append(match["name"])
        standing = manifest["standings"][0]
        labels = manifest.get("labels")
        # A match from before labels were recorded counts by its controller; the importer names its config.
        label = (
            standing["controller"]
            if labels is None
            else labels[manifest["letters"].index(standing["player"])]
        )
        wins[label] = wins.get(label, 0) + 1
    pairs = sum(1 for names in by_seed.values() if len(names) == 2)
    return (
        f"finished {sum(map(len, by_seed.values()))}, complete seed pairs {pairs}, wins {wins}, problems {bad or 'none'}",
        bool(bad),
    )


def main() -> int:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    line, bad = check(Path(sys.argv[1]), sys.argv[2])
    print(line)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
