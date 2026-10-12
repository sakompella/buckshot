#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Edit:
    old: str
    new: str


@dataclass(frozen=True)
class Mutation:
    name: str
    path: str
    edits: tuple[Edit, ...]


@dataclass(frozen=True)
class Check:
    exit_code: int
    output: str
    duration: float

    @property
    def accepted(self) -> bool:
        return (
            self.exit_code == 0
            and "ALL PROOFS CHECK" in self.output
            and "SOME PROOFS FAIL" not in self.output
        )

    @property
    def rejected(self) -> bool:
        return self.exit_code != 0 and "SOME PROOFS FAIL" in self.output


def checked(bend: str, path: Path, *, types_only: bool = False) -> Check:
    command = [bend, str(path)]
    if types_only:
        command.append("--check-only")
    started = time.perf_counter()
    result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    return Check(
        result.returncode, result.stdout + result.stderr, time.perf_counter() - started
    )


MUTATIONS = (
    Mutation(
        "selfblank-wrongpass",
        "sm/rules.bend",
        (
            Edit(
                "    case D.Blank{} True{}:\n      False{}\n    case _ _:\n      True{}",
                "    case D.Blank{} True{}:\n      True{}\n    case _ _:\n      True{}",
            ),
        ),
    ),
    Mutation(
        "jam-skip-twice",
        "sm/rules.bend",
        (
            Edit(
                "S.Skip{S.players.set_checked(players, D.ring.set(Bool, S.players.checked(players), seat, True{}))}",
                "S.Skip{S.players.set_checked(players, D.ring.set(Bool, S.players.checked(players), seat, False{}))}",
            ),
        ),
    ),
    Mutation(
        "forget-first-death",
        "sm/main.bend",
        (
            Edit(
                "S.world.set_checking_first_death(S.world.set_first_death(S.state.world(state), Some{seat}), False{})",
                "S.world.set_checking_first_death(S.state.world(state), False{})",
            ),
        ),
    ),
    Mutation(
        "wrong-prize-tier",
        "sm/main.bend",
        (
            Edit(
                "+prize : U32 = D.prize(S.world.round_index(world))",
                "+prize : U32 = D.prize(1n+S.world.round_index(world))",
            ),
        ),
    ),
    Mutation(
        "deck-draw-with-replacement",
        "sm/main.bend",
        (
            Edit(
                "world : S.World = S.world.set_deck(world, G.remove(S.Batch, S.world.deck(world), index))",
                "world : S.World = world",
            ),
        ),
    ),
    Mutation(
        "offbyone-swap-range",
        "sm/point.bend",
        (
            Edit(
                "D.Draw{D.ShuffleSwap{}, D.Range{0n, extra}}",
                "D.Draw{D.ShuffleSwap{}, D.Range{0n, 1n+extra}}",
            ),
        ),
    ),
    Mutation(
        "dead-endturn-amount-draw",
        "sm/main.bend",
        (
            Edit(
                "    case D.RandomAmount{}:\n      turn.winner(state, shooter, passing, winner)",
                "    case D.RandomAmount{}:\n      S.state.set_phase(state, S.NeedAmount{})",
            ),
        ),
    ),
    Mutation(
        "menu-offers-dead-target",
        "sm/rules.bend",
        (
            Edit(
                "    case D.At{seat, 0n} <> rest:\n      targets(rest)",
                "    case D.At{seat, 0n} <> rest:\n      S.Target{seat} <> targets(rest)",
            ),
        ),
    ),
    Mutation(
        "hidden-head-shell-leak",
        "sm/point.bend",
        (
            Edit(
                "def board(+state: S.State) -> D.Board:",
                "def head.shown(gun: List<&2, D.Shell>, fallback: D.Load) -> D.Load:\n  match gun:\n    case Nil{}:\n      fallback\n    case D.Live{} <> rest:\n      D.Load{1n, 0n}\n    case D.Blank{} <> rest:\n      D.Load{0n, 1n}\n\ndef board(+state: S.State) -> D.Board:",
            ),
            Edit(
                "D.GunView{S.world.shown(world),",
                "D.GunView{head.shown(S.world.gun(world), S.world.shown(world)),",
            ),
        ),
    ),
    Mutation(
        "wrong-reload-recipient",
        "sm/main.bend",
        (
            Edit(
                "    case Nil{}:\n      reload.begin(S.state.set_world(state, S.world.set_first_turn(S.state.world(state), recipient)))",
                "    case Nil{}:\n      reload.begin(state)",
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


def sources(here: Path) -> dict[Path, bytes]:
    return {path.relative_to(here): path.read_bytes() for path in here.rglob("*.bend")}


def record(evidence: Path | None, name: str, result: Check) -> None:
    if evidence is not None:
        (evidence / f"{name}.txt").write_text(result.output)


def verify_mutations(
    here: Path,
    *,
    types_only: bool = False,
    diagnose: bool = False,
    evidence: Path | None = None,
) -> None:
    if len(MUTATIONS) < 10 or len({mutation.name for mutation in MUTATIONS}) != len(
        MUTATIONS
    ):
        raise RuntimeError("at least ten distinct planted bugs are required")
    bend = os.environ.get("BEND", "bend")
    original = sources(here)
    results = []
    survivors = []
    if evidence is not None:
        evidence.mkdir(parents=True, exist_ok=True)
    try:
        baseline_path = here / "sm/main.bend" if types_only else here / "PROOF.bend"
        baseline = checked(bend, baseline_path, types_only=types_only)
        record(evidence, "baseline", baseline)
        if not baseline.accepted:
            raise RuntimeError(f"baseline fails before mutation\n{baseline.output}")
        print(
            f"ok    baseline {'machine types' if types_only else 'proofs'} ({baseline.duration:.3f} s)",
            flush=True,
        )
        for mutation in MUTATIONS:
            relative = Path(mutation.path)
            if relative.parts[0] != "sm" or ".." in relative.parts:
                raise RuntimeError(f"mutation escapes sm/: {relative}")
            with tempfile.TemporaryDirectory(
                prefix="buckshot-bend-mutation-"
            ) as temporary:
                candidate = Path(temporary) / "bend-mp"
                shutil.copytree(
                    here,
                    candidate,
                    ignore=shutil.ignore_patterns(
                        ".git", "node_modules", "__pycache__", ".audit"
                    ),
                )
                target = candidate / relative
                target.write_text(apply(target.read_text(), mutation))
                changes = {
                    path
                    for path, content in sources(candidate).items()
                    if content != original.get(path)
                }
                if changes != {relative}:
                    raise RuntimeError(
                        f"{mutation.name}: mutation changed unexpected Bend sources: {changes}"
                    )
                types = checked(bend, candidate / "sm/main.bend", types_only=True)
                record(evidence, f"{mutation.name}.types", types)
                if not types.accepted:
                    raise RuntimeError(
                        f"{mutation.name}: planted bug is not type-correct\n{types.output}"
                    )
                item = {
                    "name": mutation.name,
                    "types": True,
                    "type_seconds": types.duration,
                }
                if types_only:
                    print(
                        f"ok    {mutation.name} type-correct ({types.duration:.3f} s)",
                        flush=True,
                    )
                else:
                    proof = checked(bend, candidate / "PROOF.bend")
                    record(evidence, f"{mutation.name}.proof", proof)
                    item.update(rejected=proof.rejected, proof_seconds=proof.duration)
                    if proof.rejected:
                        print(
                            f"ok    {mutation.name} type-correct; proof rejected ({proof.duration:.3f} s)",
                            flush=True,
                        )
                    elif proof.accepted:
                        survivors.append(mutation.name)
                        print(
                            f"SURVIVED {mutation.name} ({proof.duration:.3f} s)",
                            flush=True,
                        )
                    else:
                        raise RuntimeError(
                            f"{mutation.name}: checker failed without proof rejection\n{proof.output}"
                        )
                results.append(item)
        if evidence is not None:
            (evidence / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        if types_only:
            print(
                f"machine mutations: {len(MUTATIONS)} type-correct bugs; no proof rejection claimed"
            )
        elif survivors:
            summary = f"{len(MUTATIONS) - len(survivors)}/{len(MUTATIONS)} rejected; survivors: {', '.join(survivors)}"
            if not diagnose:
                raise RuntimeError(summary)
            print(f"partial proof diagnostics: {summary}")
        else:
            print(f"machine mutations: {len(MUTATIONS)} type-correct bugs rejected")
    finally:
        if sources(here) != original:
            raise RuntimeError(
                "baseline Bend sources changed during mutation verification"
            )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Require ten type-correct machine bugs to fail the Bend proof suite."
    )
    parser.add_argument(
        "--types-only",
        action="store_true",
        help="Check all mutation anchors and machine types without claiming proof rejection.",
    )
    parser.add_argument(
        "--diagnose",
        action="store_true",
        help="Report survivors against a passing partial proof baseline without failing the run.",
    )
    parser.add_argument(
        "--evidence",
        type=Path,
        help="Save each native checker output and a JSON result list.",
    )
    args = parser.parse_args()
    if args.types_only and args.diagnose:
        parser.error("--types-only and --diagnose are separate checks")
    verify_mutations(
        Path(__file__).resolve().parent,
        types_only=args.types_only,
        diagnose=args.diagnose,
        evidence=args.evidence,
    )


if __name__ == "__main__":
    main()
