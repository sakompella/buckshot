"""The command line the regret analyses share: --regret, --knowledge and --doc, printing the report or splicing it between markers."""

import argparse
from collections.abc import Callable
from pathlib import Path

from docs import splice_between_markers
from regret import DERIVED, PRODUCTION


def main(
    description: str,
    marker: str,
    build: Callable[[argparse.Namespace], str],
    extra: Callable[[argparse.ArgumentParser], object] | None = None,
) -> None:
    """Parses the shared arguments (and those `extra` adds), prints `build(args)`, or with --doc replaces what lies between the `marker` markers of that file."""
    parser = argparse.ArgumentParser(description=description.split("\n")[0])
    parser.add_argument("--regret", type=Path, default=PRODUCTION)
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--doc", type=Path)
    if extra is not None:
        extra(parser)
    args = parser.parse_args()
    text = build(args)
    if args.doc is None:
        print(text)
    else:
        splice_between_markers(args.doc, marker, text)
