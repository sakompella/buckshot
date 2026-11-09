#!/usr/bin/env python3
"""Checks a tournament directory's finished matches: exit 1 if any had a fallback move, a failed audit flag, or an
endpoint outside URL_PREFIX. Prints finished matches, complete seed pairs and wins per entrant configuration.

    python3 tools/arena/check_matches.py TOURNAMENT_DIR [URL_PREFIX]
"""

import json
import os
import sys


def main() -> int:
    tdir = sys.argv[1]
    prefix = sys.argv[2] if len(sys.argv) > 2 else "https://hub.dog-minnow.ts.net"
    schedule = json.load(open(os.path.join(tdir, "tournament.json")))["schedule"]
    bad, wins, by_seed = [], {}, {}
    for match in schedule:
        path = os.path.join(tdir, match["name"], "manifest.json")
        if not os.path.exists(path):
            continue
        manifest = json.load(open(path))
        if manifest.get("status") != "finished":
            continue
        by_seed.setdefault((tuple(sorted(match["entrants"])), match["seed"]), []).append(match["name"])
        agents = manifest["provenance"]["agents"]
        if manifest["moves"].get("fallback", 0) or not all(manifest["audit"].values()) or any(not a["url"].startswith(prefix) for a in agents.values()):
            bad.append(match["name"])
        standing = manifest["standings"][0]
        winner = agents.get(standing["player"])
        key = standing["controller"] if winner is None else f"{winner['model']}-{winner['effort']}"
        wins[key] = wins.get(key, 0) + 1
    pairs = sum(1 for names in by_seed.values() if len(names) == 2)
    print(f"finished {sum(map(len, by_seed.values()))}, complete seed pairs {pairs}, wins {wins}, problems {bad or 'none'}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
