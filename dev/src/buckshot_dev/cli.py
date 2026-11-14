"""Buckshot developer commands. Run from anywhere in the repo:
`uv run --project dev dev ...`, `nix run .#dev -- ...`, or `dev ...` inside `nix develop`."""

import argparse
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import time

# Not tempfile.gettempdir(): inside `nix develop` TMPDIR is per shell, so shells would not share slots.
DEFAULT_SLOT_DIR = "/tmp"
DEFAULT_MEM = "4G"
BUDGET_SHARE = 0.6
UNITS = {"": 1, "K": 1 << 10, "M": 1 << 20, "G": 1 << 30, "T": 1 << 40}


def slot_names(slots: int) -> list[str]:
    return [f"buckshot-heavy-{i}.lock" for i in range(1, slots + 1)]


def parse_size(text: str) -> int:
    """Bytes in a size like `6G` or `512M` (powers of 1024, as systemd reads it)."""
    m = re.fullmatch(r"(\d+(?:\.\d+)?)([KMGT]?)", text.strip().upper())
    if not m:
        raise SystemExit(f"dev heavy: bad size {text!r}, use e.g. 6G or 512M")
    return int(float(m[1]) * UNITS[m[2]])


def gib(n: int) -> str:
    return f"{n / (1 << 30):.1f}G"


def meminfo(field: str) -> int:
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith(field + ":"):
                return int(line.split()[1]) << 10
    raise SystemExit(f"dev heavy: no {field} in /proc/meminfo")


def mem_budget() -> int:
    """`$BUCKSHOT_HEAVY_MEM_BUDGET`, else 60% of MemTotal."""
    env = os.environ.get("BUCKSHOT_HEAVY_MEM_BUDGET")
    return parse_size(env) if env else int(meminfo("MemTotal") * BUDGET_SHARE)


def admits(live_mem: int, size: int, budget: int, available: int) -> bool:
    """A job fits when the declared memory of live jobs plus its own is within the budget and the host has it free."""
    return live_mem + size <= budget and size <= available


def pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        pass
    return True


def job_path(slot_dir: str, pid: int) -> str:
    return os.path.join(slot_dir, f"buckshot-heavy-{pid}.job")


def live_jobs(slot_dir: str) -> list[dict]:
    """Jobs recorded in the lock directory; a job whose process died is dropped, which frees its share."""
    jobs = []
    for name in sorted(os.listdir(slot_dir)):
        if not (name.startswith("buckshot-heavy-") and name.endswith(".job")):
            continue
        path = os.path.join(slot_dir, name)
        try:
            with open(path) as f:
                job = json.load(f)
        except (OSError, ValueError):
            continue
        if pid_alive(job["pid"]):
            jobs.append(job)
        else:
            os.path.exists(path) and os.unlink(path)
    return jobs


def tree_rss(pid: int) -> int:
    """Resident bytes of `pid` and its descendants, from /proc."""
    children: dict[int, list[int]] = {}
    rss: dict[int, int] = {}
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/stat") as f:
                fields = f.read().rsplit(")", 1)[1].split()
            children.setdefault(int(fields[1]), []).append(int(entry))
            rss[int(entry)] = int(fields[21]) * os.sysconf("SC_PAGE_SIZE")
        except (OSError, IndexError):
            continue
    total, todo = 0, [pid]
    while todo:
        p = todo.pop()
        total += rss.get(p, 0)
        todo += children.get(p, [])
    return total


def command_line(cmd: list[str], mem: str) -> list[str]:
    """`cmd` niced, in a systemd scope capped at `mem` with no swap, so a runaway job dies alone; plain niced without systemd-run."""
    niced = ["nice", "-n", "10", *cmd]
    if shutil.which("systemd-run") is None:
        return niced
    return [
        "systemd-run", "--user", "--scope", "--quiet",
        "-p", f"MemoryMax={mem}", "-p", "MemorySwapMax=0", *niced,
    ]  # fmt: skip


def heavy_cmd(
    cmd: list[str], mem: str = DEFAULT_MEM, slot_dir: str | None = None, poll: float = 5
) -> int:
    """Run `cmd` niced, holding a heavy slot and a declared share of the memory budget.

    The number of slots (the CPU limit) comes from `$BUCKSHOT_HEAVY_SLOTS`, the
    lock directory from `$BUCKSHOT_HEAVY_LOCK_DIR` (default `/tmp`), and the
    memory budget from `$BUCKSHOT_HEAVY_MEM_BUDGET` (default 60% of MemTotal),
    so callers on one machine share them by setting the same values. Blocks
    until a slot is free and the job's declared memory fits the budget and the
    host's MemAvailable. The job runs with `$BUCKSHOT_HEAVY_MEM` set to its
    declared size, which tells a script it is already in the queue.
    """
    if not cmd:
        raise SystemExit("dev heavy: no command, use `dev heavy -- CMD [ARG...]`")
    if slot_dir is None:
        slot_dir = os.environ.get("BUCKSHOT_HEAVY_LOCK_DIR", DEFAULT_SLOT_DIR)
    slots = os.environ.get("BUCKSHOT_HEAVY_SLOTS", "1")
    if not slots.isdigit() or int(slots) < 1:
        raise SystemExit(
            f"dev heavy: $BUCKSHOT_HEAVY_SLOTS must be a positive number, got {slots!r}"
        )
    size, budget = parse_size(mem), mem_budget()
    if size > budget:
        raise SystemExit(
            f"dev heavy: the job declares {gib(size)}, more than the memory budget {gib(budget)} ($BUCKSHOT_HEAVY_MEM_BUDGET); refusing to start it"
        )
    names = slot_names(int(slots))
    announced = False
    while True:
        slot = admit(slot_dir, names, size, budget, cmd)
        if slot is not None:
            break
        if not announced:
            print(
                f"dev heavy: waiting for a slot and {mem} of memory (budget {gib(budget)})",
                file=sys.stderr,
            )
            announced = True
        time.sleep(poll)
    try:
        return subprocess.run(command_line(cmd, mem), env={**os.environ, "BUCKSHOT_HEAVY_MEM": mem}).returncode
    finally:
        os.unlink(job_path(slot_dir, os.getpid()))
        fcntl.flock(slot, fcntl.LOCK_UN)
        os.close(slot)


def admit(
    slot_dir: str, names: list[str], size: int, budget: int, cmd: list[str]
) -> int | None:
    """Under the admission lock, take a free slot and record this job when its memory fits. Returns the slot fd."""
    admission = os.open(
        os.path.join(slot_dir, "buckshot-heavy-admit.lock"),
        os.O_CREAT | os.O_RDWR,
        0o666,
    )
    try:
        fcntl.flock(admission, fcntl.LOCK_EX)
        live = sum(job["mem"] for job in live_jobs(slot_dir))
        if not admits(live, size, budget, meminfo("MemAvailable")):
            return None
        for name in names:
            fd = os.open(os.path.join(slot_dir, name), os.O_CREAT | os.O_RDWR, 0o666)
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                os.close(fd)
                continue
            record = {"pid": os.getpid(), "mem": size, "cmd": cmd, "start": time.time()}
            with open(job_path(slot_dir, os.getpid()), "w") as f:
                json.dump(record, f)
            return fd
        return None
    finally:
        os.close(admission)


def status(slot_dir: str | None = None) -> None:
    """Print the live heavy jobs (declared memory, current resident memory) and the budget."""
    slot_dir = slot_dir or os.environ.get("BUCKSHOT_HEAVY_LOCK_DIR", DEFAULT_SLOT_DIR)
    jobs = live_jobs(slot_dir)
    for job in jobs:
        mins = (time.time() - job["start"]) / 60
        print(
            f"pid {job['pid']}  declared {gib(job['mem'])}  rss {gib(tree_rss(job['pid']))}  {mins:.0f} min  {' '.join(job['cmd'])[:100]}"
        )
    declared = sum(job["mem"] for job in jobs)
    print(
        f"{len(jobs)} live; declared {gib(declared)} of budget {gib(mem_budget())}; host MemAvailable {gib(meminfo('MemAvailable'))}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="dev", description="Buckshot developer commands."
    )
    sub = parser.add_subparsers(dest="command", required=True)
    heavy = sub.add_parser(
        "heavy",
        help=(
            "run a command niced, holding a heavy slot and a declared share of the memory budget "
            "(waits; $BUCKSHOT_HEAVY_SLOTS slots, $BUCKSHOT_HEAVY_MEM_BUDGET budget, $BUCKSHOT_HEAVY_LOCK_DIR lock dir)"
        ),
    )
    heavy.add_argument(
        "--mem",
        default=DEFAULT_MEM,
        metavar="SIZE",
        help=f"expected peak memory, e.g. 6G (default {DEFAULT_MEM}); also the job's hard cap",
    )
    heavy.add_argument(
        "--status", action="store_true", help="list live heavy jobs and the budget"
    )
    heavy.add_argument("cmd", nargs=argparse.REMAINDER, metavar="-- CMD [ARG...]")
    args = parser.parse_args()
    if args.command == "heavy":
        if args.status:
            return status()
        cmd = args.cmd[1:] if args.cmd[:1] == ["--"] else args.cmd
        if not cmd:
            heavy.error("no command: use `dev heavy [--mem SIZE] -- CMD [ARG...]`")
        sys.exit(heavy_cmd(cmd, args.mem))
    parser.error(f"unknown command {args.command!r}")
