"""Buckshot developer commands. Run from anywhere in the repo:
`uv run --project dev dev ...`, `nix run .#dev -- ...`, or `dev ...` inside `nix develop`."""

import argparse
import fcntl
import os
import subprocess
import sys
import time

# Same lock files as the pre-dev local heavy launcher, so both take the same slots.
SLOT_NAMES = ("buckshot-heavy-1.lock", "buckshot-heavy-2.lock")

# Not tempfile.gettempdir(): inside `nix develop` TMPDIR is per shell, so shells would not share slots.
SLOT_DIR = "/tmp"


def heavy_cmd(cmd: list[str], slot_dir: str = SLOT_DIR, poll: float = 5) -> int:
    """Run `cmd` niced, holding one of the two machine-wide heavy slots.

    Blocks until a slot is free: at most two heavy jobs run at once across
    all agents (AGENTS.md).
    """
    if not cmd:
        raise SystemExit("dev heavy: no command, use `dev heavy -- CMD [ARG...]`")
    while True:
        for name in SLOT_NAMES:
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
        help="run a command niced, holding one of two machine-wide heavy slots (waits for a free one)",
    )
    heavy.add_argument("cmd", nargs=argparse.REMAINDER, metavar="-- CMD [ARG...]")
    args = parser.parse_args()
    if args.command == "heavy":
        cmd = args.cmd[1:] if args.cmd[:1] == ["--"] else args.cmd
        if not cmd:
            heavy.error("no command: use `dev heavy -- CMD [ARG...]`")
        sys.exit(heavy_cmd(cmd))
    parser.error(f"unknown command {args.command!r}")
