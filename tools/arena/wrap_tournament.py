#!/usr/bin/env python3
"""Wrap up finished tournaments: import them, refresh every derived database, rebuild the public copy and the doc tables.

    python3 tools/arena/wrap_tournament.py --run-dir _work/arena/tournament-8 --importer ~/.t3/worktrees/buckshot/t3-XXXXXXXX --cohort "tournament 8"

Run it from the main checkout inside `nix develop`, once the runner has stopped. Each step logs to <first run dir>/wrapup/ and is
recorded in wrapup/state.json when it finishes, so a rerun skips finished steps and continues at the one that stopped. A failed
check stops the run with a message and a non-zero exit; fix the cause and rerun. Steps, in order:

  stamp     write --cohort into each tournament.json that has none (the only write to a run dir)
  copy      copy the analysis database to a scratch file
  import    arena-import.ts of the phase dirs into the copy (importer worktree)
  check     quick_check ok, 0 issues, every scored match has a cohort
  swap-main stop the viewer, move the database in with a dated .pre-<name> copy, start the viewer and check HTTP 200
  snapshot  scratch copy of the new database, the input of the derived refresh
  regret    copy the live regret databases (static and sampled) to staged files and score the decisions they lack into
            them with score_regret.py (the Rust evaluator of the --evaluator checkout); each must stay one evaluator group.
            A changed evaluator needs a full rescore: name new files with --regret and --regret-sampled
  knowledge arena-knowledge.ts --verify from the knowledge worktree
  certain   certain-mistakes database
  luck      luck corrections of the luck-adjusted Round Elo (analysis/aivat.py)
  swap-derived  swap regret, sampled regret, knowledge, certain-mistakes and luck in, each keeping a .pre-<name> copy
  public    redact_database.py, scan every column for emails, swap, restart the viewer
  export    arena-export.ts: the online site's aggregate JSON from the public copy into web/online/data
  deploy    only with --deploy: upload the site as a preview version, check it at its preview URL, then promote it to buckshot.akompella.dev (docs/arena/README.md)
  doc-*     rerun the doc table scripts into the working tree (nothing is committed)
  cleanup   restart the viewer, delete the scratch files

Doc steps rewrite files under docs/ in the checkout: review and commit them yourself.
"""

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

import score_regret

sys.path.insert(0, str(Path(__file__).resolve().parent / "analysis"))
from docs import splice_between_markers  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
WORKTREES = Path.home() / ".t3/worktrees/buckshot"
EMAIL = re.compile(rb"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+")
SIDECARS = ("", "-wal", "-shm")
CLOUDFLARE_ENV = REPO / "_work/.cloudflare-deploy.env"


class Stop(Exception):
    """A check failed or a command failed: the run stops here."""


def phase_dirs(run_dirs: list[Path]) -> list[Path]:
    """The tournament directories in the run dirs: a run dir with a tournament.json is one itself, otherwise its children are."""
    found = []
    for run in run_dirs:
        found += [run] if (run / "tournament.json").exists() else sorted(p for p in run.iterdir() if (p / "tournament.json").exists())
    if not found:
        raise Stop(f"no tournament.json under {', '.join(map(str, run_dirs))}")
    return found


def stamp_cohort(dirs: list[Path], cohort: str) -> int:
    """Adds the cohort to each tournament.json without one. A different cohort already there is an error. Returns how many files changed."""
    changed = 0
    for d in dirs:
        file = d / "tournament.json"
        data = json.loads(file.read_text())
        have = data["config"].get("cohort")
        if have == cohort:
            continue
        if have is not None:
            raise Stop(f"{file} has cohort {have!r}, not {cohort!r}")
        data["config"]["cohort"] = cohort
        tmp = file.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        os.replace(tmp, file)
        changed += 1
    return changed


def backup(src: Path, dst: Path) -> None:
    """A consistent copy of a database, including what its WAL holds."""
    dst.unlink(missing_ok=True)
    source = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
    target = sqlite3.connect(dst)
    with target:
        source.backup(target)
    source.close()
    target.close()


def settle(path: Path) -> None:
    """Folds a database's WAL into the main file and leaves it in rollback-journal mode, so it is one file."""
    db = sqlite3.connect(path)
    db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    db.execute("PRAGMA journal_mode=DELETE")
    db.close()
    for suffix in SIDECARS[1:]:
        Path(f"{path}{suffix}").unlink(missing_ok=True)


def swap(live: Path, new: Path, tag: str) -> bool:
    """Moves `live` (and its -wal/-shm) to `<live>.pre-<tag>` and puts `new` in its place. No reader may have the files open.

    Returns False when the swap already happened: `new` is gone and `live` exists."""
    if not new.exists():
        if live.exists():
            return False
        raise Stop(f"neither {live} nor {new} exists")
    pre = Path(f"{live}.pre-{tag}")
    if live.exists():
        if pre.exists():
            raise Stop(f"{pre} exists already; refusing to overwrite it")
        for suffix in SIDECARS:
            if Path(f"{live}{suffix}").exists():
                os.replace(f"{live}{suffix}", f"{pre}{suffix}")
    for suffix in SIDECARS[1:]:
        Path(f"{live}{suffix}").unlink(missing_ok=True)
    os.replace(new, live)
    return True


def check_import(db_path: Path, load_dir: Path) -> str:
    """Stops unless the imported database is sound and every scored match has a cohort. Returns a summary line."""
    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    quick = db.execute("PRAGMA quick_check").fetchall()
    if quick != [("ok",)]:
        raise Stop(f"quick_check on {db_path}: {quick[:5]}")
    issues = db.execute("SELECT COUNT(*) FROM issues").fetchone()[0]
    if issues:
        sample = db.execute("SELECT message FROM issues LIMIT 5").fetchall()
        raise Stop(f"{issues} import issues, such as {sample}")
    sys.path.insert(0, str(load_dir))
    import load

    try:
        games = load.scored_games(db)
    except ValueError as error:
        raise Stop(f"a scored match has no cohort: {error}") from error
    by_status = dict(db.execute("SELECT status, COUNT(*) FROM matches GROUP BY status").fetchall())
    db.close()
    return f"quick_check ok, 0 issues, {len(games)} scored games with cohorts, matches by status {by_status}"


def dotenv(text: str) -> dict[str, str]:
    """KEY=VALUE lines of an env file; blank lines and # comments are skipped."""
    pairs = (line.split("=", 1) for line in text.splitlines() if "=" in line and not line.lstrip().startswith("#"))
    return {key.strip(): value.strip() for key, value in pairs}


def preview_version(output: str) -> str:
    """The version id in the last JSON line of `deploy-online.ts preview`; stops unless the preview passed its checks."""
    for line in reversed(output.splitlines()):
        if line.startswith("{"):
            result = json.loads(line)
            if result["problems"]:
                raise Stop(f"the preview {result['url']} fails its checks: {result['problems']}")
            return result["versionId"]
    raise Stop("deploy-online.ts preview printed no result")


def email_hits(path: Path) -> int:
    """How many email-shaped strings the database holds in any column. Values are read as text, not raw bytes: a record header byte can be an `@`."""
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    hits = 0
    for (table,) in db.execute("SELECT name FROM sqlite_master WHERE type = 'table'").fetchall():
        for column in [row[1] for row in db.execute(f'PRAGMA table_info("{table}")')]:
            for (value,) in db.execute(f'SELECT CAST("{column}" AS TEXT) FROM "{table}" WHERE CAST("{column}" AS TEXT) LIKE \'%@%\''):
                hits += len(EMAIL.findall(value.encode()))
    db.close()
    return hits


def run_steps(steps: list[tuple[str, Callable[[], str | None]]], state_file: Path, log: Callable[[str], None]) -> None:
    """Runs the steps in order, skipping those the state file lists as done and recording each as it finishes."""
    state = json.loads(state_file.read_text()) if state_file.exists() else {}
    for name, step in steps:
        if name in state:
            log(f"skip {name}: done {state[name]}")
            continue
        log(f"start {name}")
        note = step()
        state[name] = datetime.now().isoformat(timespec="seconds")
        state_file.write_text(json.dumps(state, indent=2) + "\n")
        log(f"done {name}" + (f": {note}" if note else ""))


@dataclass
class Wrap:
    run_dirs: list[Path]
    importer: Path
    analysis: Path
    docs: Path
    name: str
    cohort: str | None
    skips: Path | None
    evaluator: Path
    knowledge: Path
    viewer_unit: str | None
    viewer_url: str
    jobs: int
    regret_name: str
    sampled_name: str
    threads: int
    sampled_max_shells: int
    deploy: bool = False

    def __post_init__(self) -> None:
        self.logs = self.run_dirs[0] / "wrapup"
        self.logs.mkdir(exist_ok=True)
        self.scratch = self.analysis / f"wrapup-{self.name}"
        self.scratch.mkdir(exist_ok=True)
        self.derived = self.analysis / "derived"
        self.main = self.analysis / "buckshot.sqlite"
        self.public = self.analysis / "buckshot.public.sqlite"
        self.regret_db = self.derived / self.regret_name
        self.sampled_db = self.derived / self.sampled_name
        self.state = self.logs / "state.json"
        # Without $BEND: each `nix develop <worktree>` gets the Bend of that worktree's pin. A $BEND inherited from this
        # checkout's dev shell would make an older evaluator worktree build its player with a newer, incompatible Bend.
        self.env = {**{k: v for k, v in os.environ.items() if k != "BEND"}, "XDG_RUNTIME_DIR": os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")}

    @property
    def tag(self) -> str:
        """`<name>-<date>`, fixed by the first use so a rerun on a later day finds its own .pre files."""
        file = self.logs / "tag"
        if not file.exists():
            file.write_text(f"{self.name}-{date.today().isoformat()}")
        return file.read_text()

    def log(self, message: str) -> None:
        line = f"{datetime.now().isoformat(timespec='seconds')} {message}"
        print(line, flush=True)
        with open(self.logs / "wrapup.log", "a") as f:
            f.write(line + "\n")

    def run(self, step: str, cmd: list[str], cwd: Path = REPO, stdout: Path | None = None, env: dict[str, str] | None = None) -> None:
        """Runs a command, its output going to the step's log (or `stdout`, with stderr to the log); a failure stops the run."""
        log = self.logs / f"{step}.log"
        with open(log, "a") as err, open(stdout or log, "a") as out:
            done = subprocess.run(cmd, cwd=cwd, env=env or self.env, stdout=out, stderr=err if stdout else subprocess.STDOUT)
        if done.returncode != 0:
            raise Stop(f"{' '.join(cmd[:6])} exited {done.returncode}; see {log}")

    def nix(self, worktree: Path, *cmd: str) -> list[str]:
        return ["nix", "develop", str(worktree), "--command", "nice", "-n", "10", *cmd]

    def viewer(self, action: str) -> None:
        if self.viewer_unit:
            self.run("viewer", ["systemctl", "--user", action, self.viewer_unit])

    def viewer_up(self) -> str:
        if not self.viewer_unit:
            return "viewer skipped"
        self.viewer("restart")
        for _ in range(60):
            try:
                with urllib.request.urlopen(self.viewer_url) as response:
                    if response.status == 200:
                        return "viewer answers 200"
            except OSError:
                pass
            time.sleep(1)
        raise Stop(f"{self.viewer_url} did not answer 200 after the restart; see journalctl --user -u {self.viewer_unit}")

    # steps

    def stamp(self) -> str:
        return f"{stamp_cohort(phase_dirs(self.run_dirs), self.cohort)} tournament.json files stamped" if self.cohort else "no cohort given"

    def copy(self) -> str:
        backup(self.main, self.scratch / "new.sqlite")
        return "copied"

    def import_(self) -> None:
        skips = ["--skips", str(self.skips)] if self.skips else []
        dirs = [str(d) for d in phase_dirs(self.run_dirs)]
        self.run("import", self.nix(self.importer, "bun", "scripts/arena-import.ts", "--db", str(self.scratch / "new.sqlite"), *skips, *dirs), cwd=self.importer / "web")

    def check(self) -> str:
        return check_import(self.scratch / "new.sqlite", REPO / "tools/arena/analysis")

    def swap_main(self) -> str:
        self.viewer("stop")
        if (self.scratch / "new.sqlite").exists():
            settle(self.scratch / "new.sqlite")
        swapped = swap(self.main, self.scratch / "new.sqlite", self.tag)
        return self.viewer_up() + ("" if swapped else " (was already swapped)")

    def snapshot(self) -> None:
        backup(self.main, self.scratch / "snapshot.sqlite")

    def regret(self) -> str:
        """Scores the decisions the live regret databases lack into staged copies of them; a rerun continues where it stopped."""
        staged = {self.regret_db: self.scratch / "regret.staged.sqlite", self.sampled_db: self.scratch / "regret-sampled.staged.sqlite"}
        for live, copy in staged.items():
            if live.exists() and not copy.exists():
                backup(live, copy)
        settings = score_regret.Settings(threads=self.threads, jobs=self.jobs, sampled_max_shells=self.sampled_max_shells)
        summary = score_regret.score(self.scratch / "snapshot.sqlite", staged[self.regret_db], staged[self.sampled_db], self.evaluator, settings, work=self.scratch / "score")
        groups = []
        for copy in staged.values():
            db = sqlite3.connect(copy)
            found = db.execute("SELECT DISTINCT evaluator, max_depth, budget, reload, samples FROM regret").fetchall()
            quick = db.execute("PRAGMA quick_check").fetchall()
            db.close()
            if quick != [("ok",)] or len(found) != 1:
                raise Stop(f"{copy}: quick_check {quick[:3]}, evaluator groups {found}; a regret database holds one group (a changed evaluator needs a full rescore)")
            settle(copy)
            groups += found
        return f"{json.dumps(summary)}; groups {groups}"

    def knowledge_(self) -> str:
        out = self.scratch / "knowledge.sqlite"
        for suffix in SIDECARS:
            Path(f"{out}{suffix}").unlink(missing_ok=True)
        self.run("knowledge", self.nix(self.knowledge, "bun", "scripts/arena-knowledge.ts", "--db", str(self.scratch / "snapshot.sqlite"), "--out", str(out), "--verify"), cwd=self.knowledge / "web")
        summary = json.loads((self.logs / "knowledge.log").read_text().strip().splitlines()[-1])
        if summary["problems"] or summary["outside"] or summary["wrongCertain"]:
            raise Stop(f"knowledge --verify: {summary}")
        settle(out)
        return json.dumps(summary)

    def certain(self) -> None:
        out = self.scratch / "certain-mistakes.sqlite"
        out.unlink(missing_ok=True)
        python = [sys.executable, "tools/arena/analysis/certain_mistakes.py", "--knowledge", str(self.scratch / "knowledge.sqlite"), "--regret", str(self.scratch / "regret.staged.sqlite"), "--opportunities", str(out)]
        self.run("certain", python)
        settle(out)

    def luck(self) -> None:
        python = [sys.executable, "tools/arena/analysis/aivat.py", "--db", str(self.scratch / "snapshot.sqlite"), "--knowledge", str(self.scratch / "knowledge.sqlite"), "--out", str(self.scratch / "luck.sqlite")]
        self.run("luck", python)

    def swap_derived(self) -> str:
        self.viewer("stop")
        pairs = [(self.regret_db, "regret.staged.sqlite"), (self.derived / "knowledge.sqlite", "knowledge.sqlite"), (self.derived / "certain-mistakes.sqlite", "certain-mistakes.sqlite"), (self.derived / "luck.sqlite", "luck.sqlite"), (self.sampled_db, "regret-sampled.staged.sqlite")]
        moved = [swap(live, self.scratch / new, self.tag) for live, new in pairs]
        return f"swapped {moved}; " + self.viewer_up()

    def public_(self) -> str:
        new = self.scratch / "public.sqlite"
        if not new.exists():
            self.run("public", [sys.executable, "tools/arena/redact_database.py", str(self.main), str(new)])
        hits = email_hits(new)
        if hits:
            raise Stop(f"{new} holds {hits} email-shaped strings; it was not swapped in")
        swap(self.public, new, self.tag)
        return "0 emails in the public copy; " + self.viewer_up()

    def export(self) -> str:
        out = REPO / "web/online/data"
        derived = [("--regret", self.regret_db), ("--regret-sampled", self.sampled_db), ("--knowledge", self.derived / "knowledge.sqlite"), ("--certain-mistakes", self.derived / "certain-mistakes.sqlite"), ("--luck", self.derived / "luck.sqlite")]
        args = [str(self.public), "--out", str(out), *[a for flag, path in derived for a in (flag, str(path))]]
        self.run("export", self.nix(REPO, "bun", "scripts/arena-export.ts", *args), cwd=REPO / "web")
        return f"aggregates in {out}" + ("" if self.deploy else "; deploy with --deploy or `bun run deploy:online` from web/")

    def deploy_(self) -> str:
        """Preview, check and promote the exported site. The preview step fails the run unless the preview URL passes the privacy scan and the smoke checks, so a bad site is never promoted."""
        if not CLOUDFLARE_ENV.exists():
            raise Stop(f"{CLOUDFLARE_ENV} is missing: see docs/arena/README.md, Deploying the online site")
        env = {**self.env, **dotenv(CLOUDFLARE_ENV.read_text())}
        web = REPO / "web"
        out = self.logs / "deploy-preview.out"
        out.unlink(missing_ok=True)
        self.run("deploy-preview", self.nix(REPO, "bun", "run", "deploy:preview", "--alias", self.tag), cwd=web, stdout=out, env=env)
        version = preview_version(out.read_text())
        self.run("deploy-promote", self.nix(REPO, "bun", "run", "deploy:promote", version), cwd=web, env=env)
        return f"version {version} is live at buckshot.akompella.dev"

    def doc(self, script: str, doc: str, *args: str) -> Callable[[], None]:
        def step() -> None:
            self.run(f"doc-{script}", [sys.executable, f"tools/arena/analysis/{script}.py", *args, "--doc", str(self.docs / doc)])

        return step

    def beliefs(self) -> str:
        out = self.logs / "beliefs-and-items.tables.md"
        out.unlink(missing_ok=True)
        self.run("doc-beliefs", self.nix(self.knowledge, "bun", "scripts/arena-knowledge-report.ts", "--db", str(self.derived / "knowledge.sqlite")), cwd=self.knowledge / "web", stdout=out)
        doc = self.docs / "analysis/beliefs-and-items.md"
        try:
            splice_between_markers(doc, "beliefs", out.read_text())
        except ValueError as e:
            raise Stop(str(e)) from e

    def cleanup(self) -> str:
        note = self.viewer_up()
        for file in self.scratch.iterdir():
            file.unlink()
        self.scratch.rmdir()
        return note + "; scratch deleted"

    def steps(self) -> list[tuple[str, Callable[[], str | None]]]:
        live, reg, kn = self.main, self.regret_db, self.derived / "knowledge.sqlite"
        dbs = ["--db", str(live)]
        derived = ["--regret", str(reg), "--knowledge", str(kn)]
        a = "analysis"
        return [
            ("stamp", self.stamp),
            ("copy", self.copy),
            ("import", self.import_),
            ("check", self.check),
            ("swap-main", self.swap_main),
            ("snapshot", self.snapshot),
            ("regret", self.regret),
            ("knowledge", self.knowledge_),
            ("certain", self.certain),
            ("luck", self.luck),
            ("swap-derived", self.swap_derived),
            ("public", self.public_),
            ("export", self.export),
            *([("deploy", self.deploy_)] if self.deploy else []),
            ("doc-leaderboard", self.doc("leaderboard", "results.md", *dbs)),
            ("doc-regret", self.doc("regret", f"{a}/regret.md", *derived)),
            ("doc-by_round", self.doc("by_round", f"{a}/regret.md", *dbs, *derived)),
            ("doc-patterns_regret", self.doc("patterns_regret", f"{a}/patterns.md", *derived)),
            ("doc-certain_mistakes", self.doc("certain_mistakes", f"{a}/certain-mistakes.md", *derived)),
            ("doc-net_points", self.doc("net_points", f"{a}/net-points.md", *dbs, *derived)),
            ("doc-beliefs", self.beliefs),
            ("doc-matchups", self.doc("matchups", f"{a}/matchups.md", *dbs)),
            ("doc-luck", self.doc("aivat", f"{a}/matchups.md", *dbs, "--knowledge", str(kn))),
            ("cleanup", self.cleanup),
        ]


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--run-dir", type=Path, action="append", required=True, help="a run dir of phase directories (or a tournament directory); repeatable")
    p.add_argument("--importer", type=Path, required=True, help="worktree whose web/ imports (rules built, with the config cohort field)")
    p.add_argument("--name", help="label of the .pre-<name>-<date> copies, default the last run dir's name")
    p.add_argument("--cohort", help="cohort to stamp into tournament.json files that have none")
    p.add_argument("--skips", type=Path, help="a skips file for arena-import.ts")
    p.add_argument("--analysis", type=Path, default=REPO / "_work/arena/analysis")
    p.add_argument("--docs", type=Path, default=REPO / "docs/arena")
    p.add_argument("--evaluator", type=Path, help="checkout that scores: its sim/rust and web/ (default this checkout)")
    p.add_argument("--regret", help="file name under <analysis>/derived of the static regret rows (default regret-rust.sqlite)")
    p.add_argument("--regret-sampled", help="file name under <analysis>/derived of the sampled rows (default regret-rust-sampled256.sqlite)")
    p.add_argument("--threads", type=int, default=score_regret.Settings.threads, help="buckshot-search threads (half the cores)")
    p.add_argument("--sampled-max-shells", type=int, default=score_regret.Settings.sampled_max_shells, help="sampled rows for decisions with at most this many shells left")
    p.add_argument("--knowledge", type=Path, default=WORKTREES / "t3-5e0b7a11", help="worktree that runs arena-knowledge.ts")
    p.add_argument("--viewer-unit", default="buckshot-viewer", help="user unit to restart; '' leaves the viewer alone")
    p.add_argument("--viewer-url", default="http://127.0.0.1:8790/")
    p.add_argument("--jobs", type=int, default=4, help="regret scoring processes")
    p.add_argument("--skip", action="append", default=[], help="step to leave out, repeatable")
    p.add_argument("--deploy", action="store_true", help="after the export, preview, check and promote the online site to buckshot.akompella.dev (off by default)")
    p.add_argument("--dry-run", action="store_true", help="list the steps and which are done")
    args = p.parse_args()
    runs = [r.resolve() for r in args.run_dir]
    evaluator = (args.evaluator or REPO).resolve()
    regret_name = args.regret or "regret-rust.sqlite"
    sampled_name = args.regret_sampled or "regret-rust-sampled256.sqlite"
    wrap = Wrap(runs, args.importer.resolve(), args.analysis.resolve(), args.docs.resolve(), args.name or re.sub(r"tournament-?", "t", runs[-1].name), args.cohort, args.skips, evaluator, args.knowledge, args.viewer_unit or None, args.viewer_url, args.jobs, regret_name, sampled_name, args.threads, args.sampled_max_shells, args.deploy)
    steps = [(n, f) for n, f in wrap.steps() if n not in args.skip]
    if args.dry_run:
        done = json.loads(wrap.state.read_text()) if wrap.state.exists() else {}
        print("\n".join(f"{'done' if n in done else 'todo'}  {n}" for n, _ in steps))
        return
    try:
        run_steps(steps, wrap.state, wrap.log)
    except Stop as stop:
        wrap.log(f"STOPPED: {stop}")
        sys.exit(1)
    wrap.log("wrap-up finished; review and commit the doc changes")


if __name__ == "__main__":
    main()
