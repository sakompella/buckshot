"""Buckshot developer commands. Run from anywhere in the repo:
`uv run --project dev dev ...`, `nix run .#dev -- ...`, or `dev ...` inside `nix develop`."""

import argparse
import fcntl
import os
import subprocess
import sys
import time

# Not tempfile.gettempdir(): inside `nix develop` TMPDIR is per shell, so shells would not share slots.
DEFAULT_SLOT_DIR = "/tmp"


def slot_names(slots: int) -> list[str]:
    return [f"buckshot-heavy-{i}.lock" for i in range(1, slots + 1)]


def heavy_cmd(cmd: list[str], slot_dir: str | None = None, poll: float = 5) -> int:
    """Run `cmd` niced, holding a heavy slot.

    The number of slots comes from `$BUCKSHOT_HEAVY_SLOTS` and the lock
    directory from `$BUCKSHOT_HEAVY_LOCK_DIR` (default `/tmp`), so callers on
    one machine share slots by setting the same values. Blocks until a slot
    is free.
    """
    if not cmd:
        raise SystemExit("dev heavy: no command, use `dev heavy -- CMD [ARG...]`")
    if slot_dir is None:
        slot_dir = os.environ.get("BUCKSHOT_HEAVY_LOCK_DIR", DEFAULT_SLOT_DIR)
    slots = os.environ.get("BUCKSHOT_HEAVY_SLOTS", "1")
    if not slots.isdigit() or int(slots) < 1:
        raise SystemExit(f"dev heavy: $BUCKSHOT_HEAVY_SLOTS must be a positive number, got {slots!r}")
    names = slot_names(int(slots))
    while True:
        for name in names:
            fd = os.open(os.path.join(slot_dir, name), os.O_CREAT | os.O_RDWR, 0o666)
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                os.close(fd)
                continue
            try:
                return subprocess.run(["nice", "-n", "10", *cmd]).returncode
            finally:
                fcntl.flock(fd, fcntl.LOCK_UN)
                os.close(fd)
        time.sleep(poll)


def main() -> None:
    parser = argparse.ArgumentParser(prog="dev", description="Buckshot developer commands.")
    sub = parser.add_subparsers(dest="command", required=True)
    heavy = sub.add_parser(
        "heavy",
        help="run a command niced, holding a heavy slot (waits for a free one; $BUCKSHOT_HEAVY_SLOTS slots, $BUCKSHOT_HEAVY_LOCK_DIR lock dir)",
    )
    heavy.add_argument("cmd", nargs=argparse.REMAINDER, metavar="-- CMD [ARG...]")
    args = parser.parse_args()
    if args.command == "heavy":
        cmd = args.cmd[1:] if args.cmd[:1] == ["--"] else args.cmd
        if not cmd:
            heavy.error("no command: use `dev heavy -- CMD [ARG...]`")
        sys.exit(heavy_cmd(cmd))
    parser.error(f"unknown command {args.command!r}")
