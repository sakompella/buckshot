#!/usr/bin/env python3
"""The production regret run: score agent decisions with the Rust evaluator (sim/rust, ADR-0052) into the `regret` table.

    python3 tools/arena/score_regret.py --db buckshot.sqlite --sampled-out derived/regret-rust-<hex>-sampled256.sqlite

Every decision gets a sampled-reload row (--samples deals per leaf, 256) in --sampled-out: the production run, which the
site, the export and the doc tables read (tools/arena/analysis/regret.py, PRODUCTION). --out, for research, gets a static-reload
row for every decision. Each file holds one run. Run it inside `nix develop` (bun, cargo and Bend on PATH, or $BUN and $CARGO). It takes the
agent decisions of the replay-validated matches (or those --matches or --decisions name) that an output has no row for
under the same evaluator, depth, budget, reload and samples, so a rerun continues and a wrap-up scores only the new
matches. The wrap-up and the analyses call `score` rather than running the steps themselves. Steps:

  1. build buckshot-search in --checkout's sim/rust: the f64 and seats-2 features (arena matches have two seats)
  2. web/scripts/rust-search-inputs.ts in --checkout (after `bun run rules`) writes each decision's position as the deciding player sees it,
     with its menu in the player's move order and the shells left, in --jobs processes split by match
  3. buckshot-search --unpruned (the f64 build's only evaluator) scores them on --threads threads, once per reload rule:
     every move's value is exact at the depth reached, which the replay's move list shows
  4. each result becomes a row of the regret table (columns: docs/arena/analysis/regret.md, The `regret` table)

The evaluator id is `bounded-v1-f64-unpruned-<16 hex>`: the hex hashes the Rust sources, Cargo files and features the
binary was built from, so rows of different builds never share an id. `evaluator_build` records each id's source
commit, features, binary hash, decision count and wall time. Rows carry no per-decision time (`ms` is null).
"""

import argparse
import hashlib
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "analysis"))
from rules import WIN  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
FEATURES = "f64,seats-2"
CLI_EVALUATOR = "bounded-v1-f64"

CREATE_REGRET = """CREATE TABLE IF NOT EXISTS regret (
    match_id TEXT, ordinal INTEGER, player TEXT, label TEXT,
    evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT NOT NULL, samples INTEGER NOT NULL CHECK ((reload = 'sampled') = (samples > 0)),
    status TEXT, reason TEXT, values_json TEXT, best TEXT, best_score INTEGER, chosen_score INTEGER, regret INTEGER, exact INTEGER,
    depth INTEGER, limited INTEGER, nodes INTEGER, ms REAL,
    PRIMARY KEY (match_id, ordinal, evaluator, max_depth, budget, reload, samples))"""

CREATE_BUILD = """CREATE TABLE IF NOT EXISTS evaluator_build (
    evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT, samples INTEGER,
    source_commit TEXT, features TEXT, binary_sha256 TEXT, decisions INTEGER, seconds REAL, threads INTEGER, finished TEXT)"""


def evaluator_id(rust: Path) -> str:
    """The CLI's id, `-unpruned`, and a hash of what decides the binary's results: the rules and search sources, the Cargo files and the features."""
    digest = hashlib.sha256(FEATURES.encode())
    files = [rust / "Cargo.toml", rust / "Cargo.lock", rust / "rust-toolchain.toml"]
    for crate in ("rules", "search"):
        files += [rust / crate / "Cargo.toml", *sorted((rust / crate / "src").rglob("*.rs"))]
    for file in files:
        digest.update(str(file.relative_to(rust)).encode() + b"\0" + file.read_bytes() + b"\0")
    return f"{CLI_EVALUATOR}-unpruned-{digest.hexdigest()[:16]}"


def build(rust: Path) -> Path:
    """Builds buckshot-search with the arena features and returns the binary."""
    cmd = [os.environ.get("CARGO", "cargo"), "build", "--release", "--quiet", "-p", "buckshot-search", "--no-default-features", "--features", FEATURES, "--message-format", "json"]
    done = subprocess.run(cmd, cwd=rust, check=True, stdout=subprocess.PIPE, text=True)
    for line in done.stdout.splitlines():
        message = json.loads(line)
        if message.get("reason") == "compiler-artifact" and message["target"]["name"] == "buckshot-search" and message.get("executable"):
            return Path(message["executable"])
    raise SystemExit("cargo built no buckshot-search binary")


def wanted(db: sqlite3.Connection, out: sqlite3.Connection, group: tuple, matches: set[str] | None, decisions: set[tuple[str, int]] | None) -> list[tuple[str, int]]:
    """The agent decisions of replay-validated matches to score, minus those --out has for the group, ordered by match.
    A one-move menu is no choice: the run logs of match 4f16575f… record three item grabs as the agent's."""
    rows = db.execute(
        """SELECT d.match_id, d.ordinal, m.name FROM decisions d JOIN matches m ON m.id = d.match_id
           WHERE d.by_whom = 'agent' AND json_array_length(d.legal_json) > 1 AND m.replay_status = 'validated' AND m.manifest_json IS NOT NULL ORDER BY d.match_id, d.ordinal"""
    ).fetchall()
    done = set(out.execute("SELECT match_id, ordinal FROM regret WHERE evaluator = ? AND max_depth = ? AND budget = ? AND reload = ? AND samples = ?", group).fetchall())
    keep = [(match, ordinal) for match, ordinal, name in rows if (match, ordinal) not in done and (matches is None or name in matches) and (decisions is None or (match, ordinal) in decisions)]
    if decisions is not None and len(decisions - {(m, o) for m, o, _ in rows}):
        raise SystemExit(f"--decisions names decisions that are not agent decisions of a replay-validated match: {sorted(decisions - {(m, o) for m, o, _ in rows})[:5]}")
    return keep


def write_inputs(decisions: list[tuple[str, int]], db: Path, web: Path, work: Path, jobs: int) -> list[Path]:
    """Runs rust-search-inputs.ts on the decisions in `jobs` processes, whole matches to each, and returns their input files."""
    by_match: dict[str, list[int]] = {}
    for match, ordinal in decisions:
        by_match.setdefault(match, []).append(ordinal)
    parts: list[list[str]] = [[] for _ in range(jobs)]
    for k, (match, ordinals) in enumerate(by_match.items()):
        parts[k % jobs] += [f"{match} {ordinal}\n" for ordinal in ordinals]
    subprocess.run([os.environ.get("BUN", "bun"), "run", "rules"], cwd=web, check=True, stdout=subprocess.DEVNULL)
    procs = []
    for k, lines in enumerate(parts):
        if not lines:
            continue
        (work / f"decisions-{k}.txt").write_text("".join(lines))
        cmd = [os.environ.get("BUN", "bun"), "scripts/rust-search-inputs.ts", "--db", str(db), "--decisions", str(work / f"decisions-{k}.txt"), "--out", str(work / f"inputs-{k}")]
        with open(work / f"inputs-{k}.log", "w") as log:
            procs.append((k, subprocess.Popen(cmd, cwd=web, stderr=log)))
    for k, proc in procs:
        if proc.wait() != 0:
            raise SystemExit(f"rust-search-inputs.ts exited {proc.returncode}; see {work / f'inputs-{k}.log'}")
    return [work / f"inputs-{k}.jsonl" for k, _ in procs]


def disagreement(decision: dict, result: dict) -> str | None:
    """Why Bend's analysis of a decision and Rust's disagree, if they do (Bend wins, so either is a bug to fix)."""
    if decision["menu"] is None:
        return f"Bend's player refuses a position the game reached: {decision['invalid']}"
    if "error" in result:
        return f"Rust refuses a position Bend analysed: {result['error']}"
    codes = [line["code"] for line in result["lines"]]
    if codes != decision["codes"]:
        return f"Rust's root moves {codes} are not Bend's {decision['codes']}"
    return None


def dump(bugs: Path, reason: str, decision: dict, fed: str, line: str, build: dict) -> Path:
    """Writes what reproduces a disagreement: the input exactly as fed to buckshot-search, Bend's menu, Rust's whole row and the build."""
    bugs.mkdir(parents=True, exist_ok=True)
    path = bugs / f"{decision['id']}-{decision['ordinal']}.json"
    bend = {key: decision.get(key) for key in ("menu", "codes", "invalid", "chosen", "me", "table", "shells")}
    path.write_text(json.dumps({"match_id": decision["id"], "ordinal": decision["ordinal"], "reason": reason, "fed": fed, "bend": bend, "rust": line, **build}, indent=2) + "\n")
    return path


def row_of(decision: dict, result: dict, player: str, group: tuple) -> dict:
    """The regret row of a decision Bend and Rust agree on: searched (a regret) or fallback (depth 0: values, no regret)."""
    evaluator, depth, budget, reload, samples = group
    row = {"match_id": decision["id"], "ordinal": decision["ordinal"], "player": player, "label": decision["chosen"], "evaluator": evaluator, "max_depth": depth, "budget": budget, "reload": reload, "samples": samples, "nodes": result.get("nodes")}
    values = [{"label": label, "score": line["score"]} for label, line in zip(decision["menu"], result["lines"], strict=True)]
    row |= {"values_json": json.dumps(values, separators=(",", ":")), "limited": int(result["limited"])}
    if result["depth"] == 0:
        return {**row, "status": "fallback", "depth": 0}
    best = values[result["best"]]
    chosen = next(value for value in values if value["label"] == decision["chosen"])
    certain = best["score"] in (0, WIN) and chosen["score"] in (0, WIN)
    return {**row, "status": "searched", "best": best["label"], "best_score": best["score"], "chosen_score": chosen["score"], "regret": best["score"] - chosen["score"], "exact": int(certain), "depth": result["depth"]}


def run_search(binary: Path, inputs: list[Path], work: Path, out: sqlite3.Connection, players: dict[tuple[str, int], str], group: tuple, threads: int, keys: set[tuple[str, int]], bugs: Path, build: dict) -> int:
    """Feeds the inputs of `keys` to buckshot-search and writes a row per result, committing every chunk.
    Stops after an input file with a disagreement between Bend and Rust, with a dump of each in `bugs`. Returns the rows written."""
    _, depth, budget, reload, samples = group
    sampled = ["--reload", "sampled", "--samples", str(samples)] if reload == "sampled" else []
    cmd = [str(binary), "--unpruned", "--depth", str(depth), "--budget", str(budget), "--threads", str(threads), *sampled]
    written = 0
    for path in inputs:
        decisions = [d for d in map(json.loads, path.read_text().splitlines()) if (d["id"], d["ordinal"]) in keys]
        feed = work / f"{path.stem}.{group[3]}.jsonl"
        fed = [json.dumps({"id": d["id"], "ordinal": d["ordinal"], "input": d["input"]}) for d in decisions]
        feed.write_text("".join(line + "\n" for line in fed))
        dumps = []
        with open(feed) as stdin, open(work / f"{path.stem}.{group[3]}.log", "w") as log:
            proc = subprocess.Popen(cmd, stdin=stdin, stdout=subprocess.PIPE, stderr=log, text=True)
            assert proc.stdout is not None
            for decision, given, line in zip(decisions, fed, proc.stdout, strict=True):
                result = json.loads(line)
                if (result["id"], result["ordinal"]) != (decision["id"], decision["ordinal"]):
                    raise SystemExit(f"buckshot-search answered {result['id']} {result['ordinal']} for {decision['id']} {decision['ordinal']}")
                reason = disagreement(decision, result)
                if reason is not None:
                    dumps.append(dump(bugs, reason, decision, given, line.rstrip("\n"), {**build, "command": cmd}))
                    continue
                row = row_of(decision, result, players[(decision["id"], decision["ordinal"])], group)
                out.execute(f"INSERT INTO regret ({', '.join(row)}) VALUES ({', '.join('?' * len(row))})", list(row.values()))
                written += 1
                if written % 512 == 0:
                    out.commit()
                    print(f"{written} rows", file=sys.stderr, flush=True)
        if proc.wait() != 0:
            raise SystemExit(f"buckshot-search exited {proc.returncode}; see {work / f'{path.stem}.{group[3]}.log'}")
        out.commit()
        if dumps:
            raise SystemExit(f"Bend and Rust disagree on {len(dumps)} decisions; dumps:\n" + "\n".join(map(str, dumps)))
    return written


def git_commit(checkout: Path) -> str:
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=checkout, stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
    dirty = subprocess.run(["git", "status", "--porcelain", "--", "sim/rust"], cwd=checkout, stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
    return head + ("+dirty" if dirty else "")


@dataclass(frozen=True)
class Settings:
    depth: int = 6
    budget: int = 20000
    samples: int = 256
    threads: int = max(1, (os.cpu_count() or 2) // 2)
    jobs: int = 4


def open_out(path: Path, group: tuple) -> sqlite3.Connection:
    """The regret file for `group`; one that holds another run stops before any scoring, since a file holds one run."""
    path.parent.mkdir(parents=True, exist_ok=True)
    out = sqlite3.connect(path)
    out.execute(CREATE_REGRET)
    out.execute(CREATE_BUILD)
    others = [run for run in out.execute("SELECT DISTINCT evaluator, max_depth, budget, reload, samples FROM regret") if run != group]
    if others:
        raise SystemExit(f"{path} holds the run {others}, not {group} (evaluator, max_depth, budget, reload, samples); a changed evaluator or setting needs a new file.")
    return out


def score(db: Path, out: Path | None, sampled_out: Path | None, checkout: Path, settings: Settings, matches: set[str] | None = None, decisions: set[tuple[str, int]] | None = None, work: Path | None = None) -> dict:
    """Scores the decisions `out` (static reload) and `sampled_out` (sampled reload) lack, writing their rows. Returns a summary."""
    rust = checkout / "sim/rust"
    evaluator = evaluator_id(rust)
    runs = [(path, (evaluator, settings.depth, settings.budget, reload, samples)) for path, reload, samples in ((out, "static", 0), (sampled_out, "sampled", settings.samples)) if path is not None]
    source = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    outs = [(open_out(path, group), group) for path, group in runs]
    todo = [(conn, group, set(wanted(source, conn, group, matches, decisions))) for conn, group in outs]
    players = {(m, o): p for m, o, p in source.execute("SELECT match_id, ordinal, player FROM decisions WHERE by_whom = 'agent'")}
    source.close()
    union = sorted(set().union(*(keys for *_, keys in todo)))
    summary: dict = {"evaluator": evaluator, "decisions": len(union)}
    print(f"{evaluator}: inputs for {len(union)} decisions", file=sys.stderr, flush=True)
    if not union:
        return summary
    binary = build(rust)
    sha = hashlib.sha256(binary.read_bytes()).hexdigest()
    work = work or Path(tempfile.mkdtemp(prefix="buckshot-score-regret-"))
    work.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    inputs = write_inputs(union, db, checkout / "web", work, settings.jobs)
    summary["input_seconds"] = round(time.monotonic() - started)
    commit = git_commit(checkout)
    for (path, _), (conn, group, keys) in zip(runs, todo, strict=True):
        started = time.monotonic()
        build_info = {"evaluator": evaluator, "features": FEATURES, "binary_sha256": sha, "source_commit": commit}
        written = run_search(binary, inputs, work, conn, players, group, settings.threads, keys, path.parent / f"{path.stem}-bugs", build_info)
        seconds = time.monotonic() - started
        conn.execute("INSERT INTO evaluator_build VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))", (*group, commit, FEATURES, sha, written, seconds, settings.threads))
        conn.commit()
        conn.close()
        summary[group[3]] = {"rows": written, "seconds": round(seconds)}
    summary["work"] = str(work)
    return summary


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--db", type=Path, required=True, help="the analysis database, opened read only")
    p.add_argument("--sampled-out", type=Path, help="derived database for the sampled rows, the production run (created if missing)")
    p.add_argument("--out", type=Path, help="derived database for static rows, for research (created if missing)")
    p.add_argument("--checkout", type=Path, default=REPO, help="checkout whose sim/rust builds the evaluator and whose web/ writes the inputs")
    p.add_argument("--depth", type=int, default=Settings.depth)
    p.add_argument("--budget", type=int, default=Settings.budget, help="nodes per decision")
    p.add_argument("--samples", type=int, default=Settings.samples, help="deals per sampled leaf")
    p.add_argument("--matches", type=Path, help="file of match names, one per line: score only these")
    p.add_argument("--decisions", type=Path, help="file of '<match id> <ordinal>' lines: score only these")
    p.add_argument("--threads", type=int, default=Settings.threads, help="buckshot-search threads (half the cores)")
    p.add_argument("--jobs", type=int, default=Settings.jobs, help="processes writing the inputs")
    p.add_argument("--work", type=Path, help="directory for the inputs and logs (kept); a temporary one by default")
    args = p.parse_args()
    if args.out is None and args.sampled_out is None:
        p.error("give --sampled-out, --out or both")
    settings = Settings(args.depth, args.budget, args.samples, args.threads, args.jobs)
    matches = set(args.matches.read_text().split()) if args.matches else None
    listed = {(m, int(o)) for m, o in (line.split() for line in args.decisions.read_text().splitlines() if line.strip())} if args.decisions else None
    print(json.dumps(score(args.db.resolve(), args.out, args.sampled_out, args.checkout.resolve(), settings, matches, listed, args.work)))


if __name__ == "__main__":
    main()
