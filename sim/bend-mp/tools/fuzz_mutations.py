#!/usr/bin/env python3
"""Plant realistic item bugs in a temp copy of sim/bend-mp and require the item
law fuzz (test/machine-items-fuzz.mjs) to fail on each one."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
FUZZ_TIMEOUT_SECONDS = 240


@dataclass(frozen=True)
class Edit:
    old: str
    new: str


@dataclass(frozen=True)
class Mutation:
    name: str
    path: str
    edits: tuple[Edit, ...]


MUTATIONS = (
    Mutation(
        "beer-clears-saw",
        "sm/main.bend",
        (
            Edit(
                "      +state : S.State = S.state.set_world(state, S.world.set_gun(S.state.world(state), rest))\n"
                "      item.end(S.state.emit(state, D.Ejected{seat, shell}), seat, ending)",
                "      +state : S.State = S.state.set_world(state, S.world.set_sawed(S.world.set_gun(S.state.world(state), rest), False{}))\n"
                "      item.end(S.state.emit(state, D.Ejected{seat, shell}), seat, ending)",
            ),
        ),
    ),
    Mutation(
        "adrenaline-without-candidate",
        "sm/items.bend",
        (
            Edit(
                "steal.any(steal.with(players, seat, sawed, targets)))",
                "True{})",
            ),
        ),
    ),
    Mutation(
        "glass-told-to-every-seat",
        "sm/main.bend",
        (
            Edit(
                "def item.chamber(",
                "def glimpse.all(+state: S.State, +secret: D.Secret) -> S.State:\n"
                "  S.state.tell(S.state.tell(S.state.tell(S.state.tell(state, D.Seat0{}, secret), D.Seat1{}, secret), D.Seat2{}, secret), D.Seat3{}, secret)\n"
                "\n"
                "def item.chamber(",
            ),
            Edit(
                "item.end(S.state.tell(state, seat, D.Glimpse{shell}), seat, ending)",
                "item.end(glimpse.all(state, D.Glimpse{shell}), seat, ending)",
            ),
        ),
    ),
    Mutation(
        "used-slot-not-cleared",
        "sm/main.bend",
        (
            Edit(
                "I.slots.put(I.seat.slots(players, owner), slot, None{})",
                "I.seat.slots(players, owner)",
            ),
        ),
    ),
    Mutation(
        "remote-does-not-flip",
        "sm/main.bend",
        (
            Edit(
                "+direction : D.Direction = I.flip(S.world.direction(S.state.world(state)))",
                "+direction : D.Direction = S.world.direction(S.state.world(state))",
            ),
        ),
    ),
    Mutation(
        "head-shell-on-board",
        "sm/point.bend",
        (
            Edit(
                "def board.gun(+world: S.World) -> D.GunView:",
                "def head.shown(gun: List<&2, D.Shell>, fallback: D.Load) -> D.Load:\n"
                "  match gun:\n"
                "    case Nil{}:\n"
                "      fallback\n"
                "    case D.Live{} <> rest:\n"
                "      D.Load{1n, 0n}\n"
                "    case D.Blank{} <> rest:\n"
                "      D.Load{0n, 1n}\n"
                "\n"
                "def board.gun(+world: S.World) -> D.GunView:",
            ),
            Edit(
                "D.GunView{S.world.shown(world),",
                "D.GunView{head.shown(S.world.gun(world), S.world.shown(world)),",
            ),
        ),
    ),
)


def apply(source: str, mutation: Mutation) -> str:
    for edit in mutation.edits:
        occurrences = source.count(edit.old)
        if occurrences != 1:
            raise RuntimeError(
                f"{mutation.name}: expected one anchor, found {occurrences}"
            )
        source = source.replace(edit.old, edit.new, 1)
    return source


def run_fuzz(mutation: Mutation, env: dict[str, str] | None = None) -> tuple[str, str]:
    """Return (property that caught the bug, or "SURVIVED"/"ERROR", detail)."""
    with tempfile.TemporaryDirectory(prefix="buckshot-fuzz-mutation-") as temporary:
        copy = Path(temporary) / "bend-mp"
        shutil.copytree(
            HERE,
            copy,
            ignore=shutil.ignore_patterns(
                ".git", "node_modules", "__pycache__", ".audit"
            ),
        )
        target = copy / mutation.path
        target.write_text(apply(target.read_text(), mutation))
        try:
            result = subprocess.run(
                ["bun", str(copy / "test/machine-items-fuzz.mjs")],
                capture_output=True,
                text=True,
                timeout=FUZZ_TIMEOUT_SECONDS,
                env={**os.environ, **(env or {})},
            )
        except subprocess.TimeoutExpired:
            return "ERROR", f"fuzz exceeded {FUZZ_TIMEOUT_SECONDS} s"
    output = result.stdout + result.stderr
    if result.returncode == 0:
        return "SURVIVED", output.strip().splitlines()[-1]
    caught = re.search(r"^(\w+) failed \(", output, re.MULTILINE)
    if caught is None:
        return "ERROR", output.strip()[-400:]
    return caught.group(1), caught.group(0)


# What the other properties catch when step_matches is switched off; a smaller
# game count keeps survivors cheap, and survivors here are reported, not fatal.
INDEPENDENT_RUN = {"FUZZ_SKIP": "step_matches", "FUZZ_GAMES": "200"}


def main() -> int:
    with ThreadPoolExecutor(max_workers=3) as pool:
        outcomes = list(pool.map(run_fuzz, MUTATIONS))
        independent = list(pool.map(lambda m: run_fuzz(m, INDEPENDENT_RUN), MUTATIONS))
    failures = []
    for mutation, (verdict, detail), (alone, _) in zip(
        MUTATIONS, outcomes, independent, strict=True
    ):
        caught = verdict not in ("SURVIVED", "ERROR")
        print(
            f"{'ok   ' if caught else 'FAIL '} {mutation.name}: {verdict}"
            f" (without step_matches: {alone})"
        )
        if not caught:
            failures.append(f"{mutation.name}: {detail}")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"fuzz mutations: {len(MUTATIONS)}/{len(MUTATIONS)} planted item bugs caught")
    return 0


if __name__ == "__main__":
    sys.exit(main())
