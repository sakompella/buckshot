#!/usr/bin/env python3
"""Quota guard for arena runs through the CPA hub's management API.

Prints every Claude and Codex account's windows, then exits 0 when the run may go on and 1 when it must stop.
Claude: the least-used Claude account must be below LIMIT on every window it reports (a window whose reset has
passed counts as 0; an account with no 5h signal counts as over). Codex: with --claude-only it is not checked,
because pinned matches pause per account in the arena itself (ADR-0042); otherwise at least one Codex account must
be below 100% on every window. A Codex account with no quota data at all (CPA keeps it in memory, so a CPA restart
empties it) does not block. An unreadable API stops the run. Claude's 7-day window is checked only when CPA
reports it, which it currently does not.

    python3 tools/arena/quota_guard.py LIMIT --mgmt-file PATH [--hub URL] [--claude-only]
"""

import argparse
import json
import sys
import time
import urllib.request

WINDOWS = {
    "claude": [
        ("5h", "Anthropic-Ratelimit-Unified-5h-Utilization", "Anthropic-Ratelimit-Unified-5h-Reset", 1.0, True),
        ("7d", "Anthropic-Ratelimit-Unified-7d-Utilization", "Anthropic-Ratelimit-Unified-7d-Reset", 1.0, False),
    ],
    "codex": [
        ("5h", "X-Codex-Primary-Used-Percent", "X-Codex-Primary-Reset-At", 100.0, True),
        ("7d", "X-Codex-Secondary-Used-Percent", "X-Codex-Secondary-Reset-At", 100.0, True),
    ],
}


def account_ok(provider: str, signals: dict, limit: float, now: float) -> tuple[bool, str]:
    cells, ok = [], True
    for name, util_key, reset_key, scale, required in WINDOWS[provider]:
        util, reset = signals.get(util_key), signals.get(reset_key)
        if util is None:
            cells.append(f"{name} unknown")
            ok = ok and not required
            continue
        used = 0.0 if reset and float(reset) <= now else float(util) / scale
        when = time.strftime("%a %-I:%M %p", time.localtime(float(reset))) if reset else "-"
        cells.append(f"{name} {used:.2f} (resets {when})")
        ok = ok and used < limit
    return ok, "; ".join(cells)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("limit", type=float, help="Claude line, 0..1")
    parser.add_argument("--mgmt-file", required=True, help="file holding the CPA management password (mode 600)")
    parser.add_argument("--hub", default="https://hub.dog-minnow.ts.net")
    parser.add_argument("--claude-only", action="store_true")
    args = parser.parse_args()
    password = open(args.mgmt_file).read().strip()
    try:
        request = urllib.request.Request(f"{args.hub}/v0/management/auth-files", headers={"Authorization": f"Bearer {password}"})
        files = json.load(urllib.request.urlopen(request, timeout=20))["files"]
    except Exception as error:
        print(f"quota unreadable: {type(error).__name__}")
        return 1
    now = time.time()
    verdicts: dict[str, list[bool]] = {"claude": [], "codex": []}
    for f in files:
        provider = f.get("provider")
        if provider not in WINDOWS or f.get("disabled"):
            continue
        signals = (f.get("quota") or {}).get("signals") or {}
        number = len(verdicts[provider]) + 1
        if provider == "codex" and not signals:
            verdicts[provider].append(True)
            print(f"codex {number}: no quota data yet")
            continue
        ok, cells = account_ok(provider, signals, args.limit if provider == "claude" else 1.0, now)
        verdicts[provider].append(ok)
        print(f"{provider} {number}: {cells}")
    ok = any(verdicts["claude"]) and (args.claude_only or any(verdicts["codex"]))
    print("ok" if ok else "stop")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
