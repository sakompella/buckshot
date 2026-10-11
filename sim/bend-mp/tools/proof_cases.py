"""Generate the case-split proof bodies of PROOF.bend.

Some lemmas in PROOF.bend are case splits too large to write by hand: the
same small proof repeated for every table shape, seat and value the rules
branch on. Their signatures (the claims) are written by hand in PROOF.bend;
this script owns only their bodies.

    python3 tools/proof_cases.py          # fail if PROOF.bend differs
    python3 tools/proof_cases.py --write  # rewrite the bodies in place
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Callable
from dataclasses import dataclass
from itertools import product
from pathlib import Path

PROOF = Path(__file__).resolve().parent.parent / "PROOF.bend"

SEATS = ("D.Seat0{}", "D.Seat1{}", "D.Seat2{}", "D.Seat3{}")


@dataclass(frozen=True)
class Shape:
    """A table shape: its ring constructor and the seat numbers it holds."""

    ring: str
    seated: tuple[int, ...]

    def pattern(self, health: dict[int, str] | None = None) -> str:
        cells = []
        for seat in self.seated:
            hp = (health or {}).get(seat, f"h{seat}")
            cells.append(f"A.CoreSeat{{{hp}, j{seat}, c{seat}, p{seat}, t{seat}}}")
        return f"D.{self.ring}{{{', '.join(cells)}}}"


SHAPES = (Shape("Duo", (1, 3)), Shape("Trio", (0, 1, 2)), Shape("Quad", (0, 1, 2, 3)))


def world(checking: str = "checking") -> str:
    return (
        "S.World{D.Config{table, plan}, before, round, load, first, rh, recipient, "
        f"turn, direction, died, {checking}, amount, saw, gun, shown, deck}}"
    )


def indent(depth: int, rows: list[str]) -> list[str]:
    return [" " * depth + row for row in rows]


def seat_split(match_world: bool) -> Callable[[], list[str]]:
    """Every shape and seat, each closed by computation."""

    def body() -> list[str]:
        rows = ["match seats seat:"]
        for shape, seat in product(SHAPES, SEATS):
            rows += [f"  case {shape.pattern()} {seat}:", "    {==}"]
        if match_world:
            return ["match world:", f"  case {world()}:", *indent(4, rows)]
        return rows

    return body


def seat_pairs(leaf: Callable[[bool], list[str]]) -> list[str]:
    """Every (actor, target) pair per shape; a seat off the table is refuted."""
    rows = ["match seats actor target:"]
    for shape, actor, target in product(SHAPES, range(4), range(4)):
        rows.append(f"  case {shape.pattern()} {SEATS[actor]} {SEATS[target]}:")
        if actor not in shape.seated:
            rows.append("    match present_a:")
        elif target not in shape.seated:
            rows.append("    match present_t:")
        else:
            rows += indent(4, leaf(actor == target))
    return rows


MID_TAIL = (
    "aimstep.tail(S.state.world(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), "
    "A.shot.turn_write(A.shot.health_write(seats, target, hp), actor, False{}), phase, "
    "S.state.notes(A.aim.ms_mid(world, seats, actor, target, shell, rest, phase, hp, d, dmg)), "
    "actor, Q.shot.passes(shell, D.seat.eq(actor, target)), supported, bounded, synced)"
)


def mid() -> list[str]:
    """Shot middle: split the shell and whether a live shell leaves 0 health."""

    def leaf(_same: bool) -> list[str]:
        rows = ["match shell hp:"]
        for pattern in ("D.Blank{} _", "D.Live{} 0n", "D.Live{} 1n+x"):
            rows += [f"  case {pattern}:", f"    {MID_TAIL}"]
        return rows

    rows = ["match world:"]
    for checking in ("False{}", "True{}"):
        rows += [f"  case {world(checking)}:", *indent(4, seat_pairs(leaf))]
    return rows


def r1() -> list[str]:
    """Reference shot prefix: a self shot also splits the shell (saw timing)."""

    def leaf(same: bool) -> list[str]:
        if not same:
            return ["{==}"]
        return [
            "match shell:",
            "  case D.Live{}:",
            "    {==}",
            "  case D.Blank{}:",
            "    {==}",
        ]

    return ["match world:", f"  case {world()}:", *indent(4, seat_pairs(leaf))]


FRONT_STUCK = (
    "({==}, pack_valid(A.world_for(world, seats), seats, "
    "S.Aim{actor, Q.targets(D.ring.entries(Nat, A.seats.health(seats)))}, notes, "
    "aimstep.front_stable(world, seats, supported, bounded), {==}, {==}))"
)


def front_pick(target: int, index: int) -> str:
    return (
        f"aimstep.pick(A.world_for(world, seats), seats, actor, {SEATS[target]}, {index}n, "
        "{==}, Unit{}, Unit{}, supported, bounded, {==})"
    )


def front_menu(living: list[int]) -> list[str]:
    """The tape value picks a living target; values past the menu clamp."""
    if not living:
        return [FRONT_STUCK]
    rows = ["match n:"]
    for index, target in enumerate(living):
        rows += [f"  case {index}n:", f"    {front_pick(target, index)}"]
    last = len(living) - 1
    return rows + [f"  case {last + 1}n+more:", f"    {front_pick(living[last], last)}"]


def front() -> list[str]:
    """Aim answer: split the actor and which seats are alive."""
    rows = ["match seats actor:"]
    for shape, actor in product(SHAPES, range(4)):
        if actor not in shape.seated:
            rows += [f"  case {shape.pattern()} {SEATS[actor]}:", f"    {FRONT_STUCK}"]
            continue
        for alive in product((False, True), repeat=len(shape.seated)):
            health = {
                seat: f"1n+h{seat}" if live else "0n"
                for seat, live in zip(shape.seated, alive)
            }
            living = [seat for seat, live in zip(shape.seated, alive) if live]
            rows.append(f"  case {shape.pattern(health)} {SEATS[actor]}:")
            rows += indent(4, front_menu(living))
    return ["match world:", f"  case {world()}:", *indent(4, rows)]


BODIES: dict[str, Callable[[], list[str]]] = {
    "give_pack": seat_split(match_world=False),
    "turn_shape": seat_split(match_world=False),
    "idleproof.idle_permission": seat_split(match_world=True),
    "aimproof.players_health_write": seat_split(match_world=False),
    "aimproof.players_turn_write": seat_split(match_world=False),
    "aimproof.players_cash_write": seat_split(match_world=False),
    "aimproof.cash_shape": seat_split(match_world=False),
    "aimstep.machine_final_gate": seat_split(match_world=True),
    "aimstep.loop_award": seat_split(match_world=True),
    "aimstep.mid": mid,
    "aimstep.r1": r1,
    "aimstep.front": front,
}


def body_span(text: str, name: str) -> tuple[int, int]:
    """The body of `def name(`: after its signature line, to the last indented line."""
    head = text.index(f"\ndef {name}(") + 1
    start = text.index("\n", head) + 1
    end = start
    for row in text[start:].split("\n"):
        if row and not row.startswith(" "):
            break
        end += len(row) + 1
    return start, len(text[:end].rstrip("\n"))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate the case-split proof bodies of PROOF.bend."
    )
    parser.add_argument("--write", action="store_true", help="rewrite PROOF.bend")
    args = parser.parse_args()
    text = PROOF.read_text()
    stale = []
    for name, generate in BODIES.items():
        body = "\n".join(indent(2, generate()))
        start, end = body_span(text, name)
        if text[start:end] != body:
            stale.append(name)
            text = text[:start] + body + text[end:]
    if args.write:
        PROOF.write_text(text)
        print(f"rewrote {len(stale)} of {len(BODIES)} generated bodies")
        return 0
    if stale:
        print(
            f"PROOF.bend differs from tools/proof_cases.py: {', '.join(stale)}",
            file=sys.stderr,
        )
        return 1
    print(f"{len(BODIES)} generated proof bodies match tools/proof_cases.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
