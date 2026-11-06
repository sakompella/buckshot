#!/usr/bin/env python3
"""Plant type-correct bugs in a temp copy of the simple machine (simple/) and
require both SIMPLE-PROOF.bend --verdict and the simple fuzz
(test/simple-fuzz.mjs) to reject each one."""

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
TIMEOUT_SECONDS = 600
FUZZ_GAMES = "40"


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
        "shoot-without-pickup",
        "simple/main.bend",
        (
            Edit(
                "      shoot(pickup(state, seat), seat, target)",
                "      shoot(state, seat, target)",
            ),
        ),
    ),
    Mutation(
        "distribution-starts-at-shooter",
        "simple/main.bend",
        (
            Edit(
                "      grab.distribute(state, S.world.first_turn(T.state.world(state)))",
                "      grab.distribute(state, G.next_turn(S.players.health(T.state.players(state)), S.world.direction(T.state.world(state)), S.world.first_turn(T.state.world(state))))",
            ),
        ),
    ),
    Mutation(
        "place-in-second-free-slot",
        "simple/main.bend",
        (
            Edit(
                "    case S.PutAt{slot} <> _:\n      Placing{after, slot}",
                "    case S.PutAt{first} <> S.PutAt{slot} <> _:\n      Placing{after, slot}\n    case S.PutAt{slot} <> _:\n      Placing{after, slot}",
            ),
        ),
    ),
    Mutation(
        "steal-jam-takes-own-slot",
        "simple/main.bend",
        (
            Edit(
                "      jam.selected(item.use(item.use(state, seat, seat, adrenaline, D.Adrenaline{}), seat, owner, slot, D.Jammer{}), seat, target)",
                "      jam.selected(item.use(item.use(state, seat, seat, adrenaline, D.Adrenaline{}), seat, seat, slot, D.Jammer{}), seat, target)",
            ),
        ),
    ),
    Mutation(
        "jammed-seat-not-skipped",
        "simple/main.bend",
        (
            Edit(
                "  grant.step(rank, state, seat, G.jam(T.state.players(state), seat))",
                "  grant.step(rank, state, seat, S.Act{T.state.players(state)})",
            ),
        ),
    ),
    Mutation(
        "turn-amount-off-by-one",
        "simple/main.bend",
        (
            Edit(
                "      turn.winner(T.state.set_world(state, S.world.set_item_amount(T.state.world(state), value)), from, passing, winner)",
                "      turn.winner(T.state.set_world(state, S.world.set_item_amount(T.state.world(state), 1n+value)), from, passing, winner)",
            ),
        ),
    ),
    Mutation(
        "notes-newest-first",
        "simple/state.bend",
        (
            Edit(
                "      List.append(&2, D.Note, log.list(earlier), [note])",
                "      note <> log.list(earlier)",
            ),
        ),
    ),
    Mutation(
        "cigarettes-past-round-health",
        "simple/main.bend",
        (
            Edit(
                "      item.heal(state, seat, Nat.is_lt(I.seat.health(T.state.players(state), seat), S.world.round_health(T.state.world(state))))",
                "      item.heal(state, seat, True{})",
            ),
        ),
    ),
    Mutation(
        "menu-offers-chained-use",
        "simple/point.bend",
        (
            Edit(
                "      I.keep(T.IdleOption, Bool.not(Bool.or(item.chained(item), items.has(seen, item))), T.UseSlot{slot, item}, use.options(rest, item <> seen))",
                "      I.keep(T.IdleOption, Bool.not(items.has(seen, item)), T.UseSlot{slot, item}, use.options(rest, item <> seen))",
            ),
        ),
    ),
    Mutation(
        "steal-dedupe-ignores-owner",
        "simple/point.bend",
        (
            Edit(
                "picks.has(seen, owner, item))), T.StealWith{adrenaline, owner, slot, item}, steal.picks(adrenaline, rest, D.At{owner, item} <> seen))",
                "picks.has(seen, D.Seat0{}, item))), T.StealWith{adrenaline, owner, slot, item}, steal.picks(adrenaline, rest, D.At{D.Seat0{}, item} <> seen))",
            ),
        ),
    ),
)


BASELINE = Mutation("baseline", "simple/main.bend", ())


def apply(source: str, mutation: Mutation) -> str:
    for edit in mutation.edits:
        occurrences = source.count(edit.old)
        if occurrences != 1:
            raise RuntimeError(f"{mutation.name}: expected one anchor, found {occurrences}")
        source = source.replace(edit.old, edit.new, 1)
    return source


def run(command: list[str], cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=TIMEOUT_SECONDS,
        env={**os.environ, **(env or {})},
    )


def verdicts(mutation: Mutation) -> tuple[str, str]:
    """(proof verdict, fuzz verdict): REJECTED, SURVIVED, or ERROR with detail."""
    bend = os.environ.get("BEND", "bend")
    with tempfile.TemporaryDirectory(prefix="buckshot-simple-mutation-") as temporary:
        copy = Path(temporary) / "bend-mp"
        shutil.copytree(HERE, copy, ignore=shutil.ignore_patterns(".git", "node_modules", "__pycache__", ".audit"))
        target = copy / mutation.path
        target.write_text(apply(target.read_text(), mutation))
        built = run([bend, "simple/main.bend", "--check-only"], copy)
        if "ALL PROOFS CHECK" not in built.stdout + built.stderr:
            return "ERROR: not type-correct", "ERROR: not type-correct"
        proof = run([bend, "SIMPLE-PROOF.bend", "--verdict"], copy)
        proof_out = proof.stdout + proof.stderr
        proof_verdict = "SURVIVED" if "ALL PROOFS CHECK" in proof_out and "SOME PROOFS FAIL" not in proof_out else "REJECTED"
        fuzz = run(["bun", "test/simple-fuzz.mjs"], copy, {"FUZZ_GAMES": FUZZ_GAMES})
        fuzz_out = fuzz.stdout + fuzz.stderr
        if fuzz.returncode == 0:
            fuzz_verdict = "SURVIVED"
        else:
            caught = re.search(r"^(\w+ failed \(.*?\)|walk refused|Stuck at|Stalled at)", fuzz_out, re.MULTILINE)
            fuzz_verdict = f"REJECTED ({caught.group(1)})" if caught else "ERROR: " + fuzz_out.strip()[-300:]
    return proof_verdict, fuzz_verdict


def main() -> int:
    with ThreadPoolExecutor(max_workers=3) as pool:
        baseline, *outcomes = pool.map(verdicts, (BASELINE, *MUTATIONS))
    if baseline != ("SURVIVED", "SURVIVED"):
        print(f"baseline is not green: proof {baseline[0]}, fuzz {baseline[1]}", file=sys.stderr)
        return 1
    failures = []
    for mutation, (proof, fuzz) in zip(MUTATIONS, outcomes, strict=True):
        ok = proof == "REJECTED" and fuzz.startswith("REJECTED")
        print(f"{'ok   ' if ok else 'FAIL '} {mutation.name}: proof {proof}, fuzz {fuzz}")
        if not ok:
            failures.append(mutation.name)
    if failures:
        print("survived: " + ", ".join(failures), file=sys.stderr)
        return 1
    print(f"simple mutations: {len(MUTATIONS)}/{len(MUTATIONS)} planted bugs rejected by the proofs and the fuzz")
    return 0


if __name__ == "__main__":
    sys.exit(main())
