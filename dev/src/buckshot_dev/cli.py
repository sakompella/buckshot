"""Buckshot developer commands. Run from anywhere in the repo: `uv run --project dev dev ...` or `nix run .#dev -- ...`."""

import argparse
import os
import subprocess
import sys
from pathlib import Path


def repo_root() -> Path:
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True)
    return Path(out.stdout.strip())


def run(cmd: list[str], cwd: Path, env: dict[str, str] | None = None) -> int:
    print("==", " ".join(cmd), flush=True)
    return subprocess.run(["nice", "-n", "10", *cmd], cwd=cwd, env={**os.environ, **(env or {})}).returncode


def py_test(root: Path) -> int:
    """The tools/arena unit and property tests."""
    failed = 0
    for directory in (root / "tools/arena", root / "tools/arena/analysis"):
        failed |= run([sys.executable, "-m", "unittest", "discover", "-s", str(directory), "-p", "test_*.py"], cwd=directory)
    return failed


def rust_lint(root: Path) -> int:
    """fmt and clippy on the default features: the same commands the Nix checks run."""
    here = root / "sim/rust"
    return run(["cargo", "fmt", "--check"], here) or run(
        ["cargo", "clippy", "--workspace", "--all-targets", "--", "-D", "warnings"], here
    )


COMMANDS = {"py-test": py_test, "rust-lint": rust_lint}


def main() -> None:
    parser = argparse.ArgumentParser(prog="dev")
    parser.add_argument("command", choices=COMMANDS)
    args = parser.parse_args()
    sys.exit(COMMANDS[args.command](repo_root()))
