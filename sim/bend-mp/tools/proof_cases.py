"""Generate the case-split proof bodies of core-proof.bend, item-step-proof.bend,
grab-proof.bend and load-proof.bend.

Some lemmas in the proof files are case splits too large to write by hand: the
same small proof repeated for every table shape, seat and value the rules
branch on. Their signatures (the claims) are written by hand in core-proof.bend;
this script owns only their bodies.

    python3 tools/proof_cases.py          # fail if core-proof.bend differs
    python3 tools/proof_cases.py --write  # rewrite the bodies in place
"""

from __future__ import annotations

import argparse
import re
import sys
from collections.abc import Callable
from dataclasses import dataclass
from itertools import product
from pathlib import Path

PROOF = Path(__file__).resolve().parent.parent / "core-proof.bend"
ITEM_PROOF = PROOF.with_name("item-step-proof.bend")
GRAB_PROOF = PROOF.with_name("grab-proof.bend")
LOAD_PROOF = PROOF.with_name("load-proof.bend")

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
            cells.append(
                f"S.Seat{{{hp}, j{seat}, p{seat}, s{seat}}}"
            )
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


def seat_split_present() -> list[str]:
    """Every shape and seat; a seat off the table is refuted by `present`."""
    rows = ["match seats seat:"]
    for shape, seat in product(SHAPES, range(4)):
        rows.append(f"  case {shape.pattern()} {SEATS[seat]}:")
        rows.append("    {==}" if seat in shape.seated else "    match present:")
    return ["match world:", f"  case {world()}:", *indent(4, rows)]


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
    "A.shot.health_write(seats, target, hp), phase, "
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
    "S.Aim{actor}, notes, "
    "aimstep.front_stable(world, seats, supported, bounded), {==}, ready))"
)


def front_pick(target: int, index: int) -> str:
    return (
        f"aimstep.pick(A.world_for(world, seats), seats, actor, {SEATS[target]}, {index}n, "
        "{==}, Unit{}, Unit{}, supported, bounded, {==}, ready)"
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



def pack_shape() -> list[str]:
    """The table tie of a no-item pack, per table shape."""
    rows = ["match seats:"]
    for shape in SHAPES:
        rows += [f"  case {shape.pattern()}:", "    ({==}, ({==}, ({==}, ({==}, {==}))))"]
    return ["match world:", f"  case {world()}:", *indent(4, rows)]


# Each phase constructor and what the no-item normal form makes of it: kept,
# Blocked, or Idle with the gun alone.
PHASES = (
    ("S.NeedFirst{}", "keep"),
    ("S.NeedHealth{}", "keep"),
    ("S.NeedAmount{}", "keep"),
    ("S.NeedBatch{}", "keep"),
    ("S.NeedSwap{_, _, 0n}", "blocked"),
    ("S.NeedSwap{+swap_load, +shells, 1n+i}", "keep"),
    ("S.Idle{+seat, options}", "idle"),
    ("S.Aim{+seat}", "keep"),
    ("S.Ended{}", "keep"),
    ("S.Blocked{+holder}", "keep"),
    ("S.NeedTurnAmount{_, _, _}", "blocked"),
    ("S.Grab{_}", "blocked"),
    ("S.NeedItem{_, _, _, _}", "blocked"),
    ("S.NeedPhone{_, _, _}", "blocked"),
    ("S.JamPick{_, _}", "blocked"),
    ("S.StealPick{_, _}", "blocked"),
)


def pack_valid() -> list[str]:
    """ValidItems of a no-item pack, per phase constructor."""
    w = world()
    idle = "S.Idle{seat, D.NonEmpty{S.TakeGun{}, Nil{}}}"
    pack = f"A.pack(A.world_for({w}, seats), seats, {idle}, notes)"
    rows = ["match phase:"]
    for pattern, kind in PHASES:
        canonical = {"keep": re.sub(r"(?<=[{ ])\+", "", pattern), "blocked": "S.Blocked{None{}}", "idle": idle}[kind]
        shape = f"items.pack_shape({w}, seats, {canonical}, notes)"
        if kind == "idle":
            state = f"xs => S.State{{A.world_for({w}, seats), A.players.free(seats), S.Idle{{seat, D.NonEmpty{{S.TakeGun{{}}, xs}}}}, notes, A.grabs(seats)}}"
            normal = f"Equal.cong(List<&2, S.IdleOption>, S.State, {state}, I.uses({pack}, seat), Nil{{}}, items.idle_uses({w}, seats, seat, notes))"
        else:
            normal = "{==}"
        ready = "{==}" if kind == "blocked" else "ready"
        rows += [f"  case {pattern}:", f"    ({normal}, ({shape}, (bounded, {ready})))"]
    return ["match world:", f"  case {w}:", *indent(4, rows)]

BODIES: dict[str, Callable[[], list[str]]] = {
    "give_pack": seat_split(match_world=False),
    "idleproof.idle_guards": seat_split_present,
    "aimproof.players_health_write": seat_split(match_world=False),
    "aimproof.players_cash_write": seat_split(match_world=False),
    "aimproof.cash_shape": seat_split(match_world=False),
    "aimstep.machine_final_gate": seat_split(match_world=True),
    "aimstep.loop_award": seat_split(match_world=True),
    "aimstep.mid": mid,
    "aimstep.r1": r1,
    "inv.idle_phase": seat_split(match_world=True),
    "aimstep.front": front,
}

ITEM_BODIES: dict[str, Callable[[], list[str]]] = {
    "items.idle_uses": seat_split(match_world=False),
    "items.pack_shape": pack_shape,
    "items.pack_valid": pack_valid,
}

# ---------------------------------------------------------------------------
# grab-proof.bend: splits over the table, the seat ring and the Grabs rings an
# A.Shape(s) premise ties to it. A ring with another table's constructor is
# refuted by its Shape equation.

TABLES = (
    ("D.TwoSeats{}", "two", SHAPES[0]),
    ("D.ThreeSeats{}", "three", SHAPES[1]),
    ("D.FourSeats{}", "four", SHAPES[2]),
)
RINGS = ("players", "grabbing", "holding", "granted", "intake")
GRAB_RINGS = RINGS[1:]
CELLS = {
    "players": lambda k: f"S.Seat{{+h{k}, +j{k}, +c{k}, +s{k}}}",
    "grabbing": lambda k: f"+g{k}",
    "holding": lambda k: f"+o{k}",
    "granted": lambda k: f"+n{k}",
    "intake": lambda k: f"+i{k}",
}
STATE_WORLD_FIELDS = "before, round, load, first, rh, recipient, turn, direction, died, checking, amount, saw, gun, shown, deck"
SHAPE_FACTS = "Tuple{e_players, Tuple{e_grabbing, Tuple{e_holding, Tuple{e_granted, e_intake}}}}"


def ring_pattern(ring: str, shape: Shape) -> str:
    return f"D.{shape.ring}{{{', '.join(CELLS[ring](k) for k in shape.seated)}}}"


def unplus(text: str) -> str:
    return re.sub(r"(?<=[{ ])\+", "", text)


def state_text(table: str, rings: dict[str, str], with_grabs: bool) -> str:
    world = f"S.World{{D.Config{{{table}, plan}}, {STATE_WORLD_FIELDS}}}"
    grabs = f"S.Grabs{{dist, {', '.join(rings[r] for r in GRAB_RINGS)}}}" if with_grabs else "grabs"
    return f"S.State{{{world}, {rings['players']}, phase, notes, {grabs}}}"


def ring_split(
    claim: Callable[[str], str],
    rings: tuple[str, ...],
    seat: bool,
    leaf: Callable[[Shape, int | None, str], list[str]],
    scope: str = "",
) -> Callable[[], list[str]]:
    """Split s's table, the named rings and (if seat) the seat; `claim(state)` is
    the lemma's type at a refuted state, `leaf(shape, seat, state)` the proof of
    a case at its split state. `scope` qualifies grab-proof.bend's `absurd` and
    `clash.*` from another file."""

    def body() -> list[str]:
        with_players = "players" in rings
        # Shape(s) reads the Grabs constructor, so grabs is always matched.
        with_grabs = True
        fields = ", ".join("+" + f for f in STATE_WORLD_FIELDS.split(", "))
        head = [
            "match s:",
            f"  case S.State{{S.World{{D.Config{{table, +plan}}, {fields}}}, players, +phase, +notes, grabs}}:",
        ]

        def patterns(assigned: dict[str, str]) -> list[str]:
            out = [assigned["players"]] if with_players else []
            if with_grabs:
                out.append(f"S.Grabs{{+dist, {', '.join(assigned[r] for r in GRAB_RINGS)}}}")
            return out

        scrutinees = ["table"] + (["players"] if with_players else []) + (["grabs"] if with_grabs else [])
        rows = [f"match {' '.join(scrutinees + (['seat'] if seat else []))}:"]
        free = {r: "+" + r for r in RINGS}
        for table, name, shape in TABLES:
            good = free | {r: ring_pattern(r, shape) for r in rings}
            state = state_text(table, {r: unplus(good[r]).lstrip("+") for r in RINGS}, with_grabs)
            for k in range(4) if seat else [None]:
                rows.append(f"  case {' '.join([table, *patterns(good), *([SEATS[k]] if seat else [])])}:")
                rows += indent(4, leaf(shape, k, state))
            for ring in rings:
                for _, other, wrong in TABLES:
                    if wrong is shape:
                        continue
                    bad = free | {ring: ring_pattern(ring, wrong)}
                    state = state_text(table, {r: r for r in RINGS} | {ring: unplus(bad[ring])}, with_grabs)
                    rows += [
                        f"  case {' '.join([table, *patterns(bad), *(['+seat'] if seat else [])])}:",
                        "    match shape:",
                        f"      case {SHAPE_FACTS}:",
                        f"        {scope}absurd({claim(state)}, {scope}clash.{other}_{name}(e_{ring}))",
                    ]
        return head + indent(4, rows)

    return body


def closed(_shape: Shape, _seat: int | None, _state: str) -> list[str]:
    return ["{==}"]


def own_leaf(shape: Shape, seat: int | None, _state: str) -> list[str]:
    """A seated seat's count is L1 on its slots and hand; a missing seat reads 0 on both sides."""
    return [f"count.owned(s{seat}, o{seat}, item)"] if seat in shape.seated else ["{==}"]


def total_leaf(shape: Shape, _seat: int | None, _state: str) -> list[str]:
    """The table count, one count.owned per seat chained through add_cong."""

    def sums(seats: tuple[int, ...], side: str) -> str:
        out = "0n"
        for k in reversed(seats):
            out = f"Nat.add(own.{side}(s{k}, o{k}, item), {out})"
        return out

    def chain(seats: tuple[int, ...]) -> str:
        if not seats:
            return "{==}"
        k, rest = seats[0], seats[1:]
        return (
            f"add_cong(own.ref(s{k}, o{k}, item), own.machine(s{k}, o{k}, item), "
            f"{sums(rest, 'ref')}, {sums(rest, 'machine')}, count.owned(s{k}, o{k}, item), {chain(rest)})"
        )

    return [chain(shape.seated)]


def last_leaf(shape: Shape, seat: int | None, state: str) -> list[str]:
    """IsPlacingLastItem's three reads; a missing seat reads empty slots and no grants."""
    slots, granted = (f"s{seat}", f"n{seat}") if seat in shape.seated else ("D.slots.empty()", "0n")
    at = SEATS[seat]
    return [
        f"last.parts(G.GetItemToGrab.pool(D.item.order(), A.ref_host({state}), {at}), I.pool({state}, {at}), "
        f"{slots}, {granted}, amount, empty.eq({state}, {at}, shape))"
    ]


def menu_leaf(shape: Shape, seat: int | None, _state: str) -> list[str]:
    """One seat's grab menu from its cells; a missing seat is not grabbing."""
    turn = f"A.turn.held(A.turn.holder(phase), {SEATS[seat]})"
    if seat in shape.seated:
        k = seat
        cells = [f"g{k}", f"o{k}", f"i{k}", "dist", f"s{k}", f"h{k}", f"S.jam.jammed(j{k})", f"A.jam.checked(j{k})", f"c{k}", turn, f"n{k}"]
    else:
        cells = ["False{}", "None{}", "False{}", "dist", "D.slots.empty()", "100n", "False{}", "False{}", "0", turn, "0n"]
    return [f"menu.cell({', '.join(cells)})"]


def accept_leaf(shape: Shape, seat: int | None, _state: str) -> list[str]:
    """The selected option passes the grab check; a missing seat has no options."""
    if seat in shape.seated:
        k = seat
        cells = [f"g{k}", f"o{k}", f"Bool.and(i{k}, dist)", f"s{k}", f"h{k}", f"S.jam.jammed(j{k})", f"A.jam.checked(j{k})", f"c{k}", f"A.turn.held(A.turn.holder(phase), {SEATS[seat]})"]
    else:
        cells = ["False{}", "None{}", "False{}", "D.slots.empty()", "100n", "False{}", "False{}", "0", "False{}"]
    return [f"accept.cell({', '.join(cells)}, index, move, sel)"]


def menus_set() -> list[str]:
    """A ring write commutes with rendering, per ring shape and seat."""
    rows = ["match menus seat:"]
    for shape, seat in product(SHAPES, SEATS):
        cells = ", ".join(f"m{k}" for k in shape.seated)
        rows += [f"  case D.{shape.ring}{{{cells}}} {seat}:", "    {==}"]
    return rows


GRAB_BODIES: dict[str, Callable[[], list[str]]] = {
    "own.eq": ring_split(lambda state: f"own.claim({state}, seat, item)", ("players", "holding"), True, own_leaf),
    "total.eq": ring_split(lambda state: f"total.claim({state}, item)", ("players", "holding"), False, total_leaf),
    "entries.eq": ring_split(lambda state: f"entries.claim({state})", ("players",), False, closed),
    "ended.eq": ring_split(lambda state: f"ended.claim({state})", ("players", "grabbing"), False, closed),
    "last.eq": ring_split(lambda state: f"last.claim({state}, seat)", ("players", "granted"), True, last_leaf),
    "holding.eq": ring_split(lambda state: f"holding.claim({state})", ("holding",), False, closed),
    "menu.at": ring_split(lambda state: f"menu.claim({state}, seat)", RINGS, True, menu_leaf),
    "menus.set": menus_set,
    "stop.eq": ring_split(lambda state: f"stop.claim({state}, seat)", ("players", "intake"), True, closed),
    "give.eq": ring_split(lambda state: f"give.claim({state}, seat, item)", ("players", "holding", "granted", "intake"), True, closed),
    "close.eq": ring_split(lambda state: f"close.claim({state}, seat)", ("players", "grabbing"), True, closed),
    "put.eq": ring_split(lambda state: f"put.claim({state}, seat, fresh)", ("players", "holding", "intake"), True, closed),
    "done.eq": ring_split(lambda state: f"done.claim({state})", ("players",), False, closed),
    "held.eq": ring_split(lambda state: f"held.claim({state}, seat)", ("players", "holding"), True, closed),
    "slots.eq": ring_split(lambda state: f"slots.claim({state}, seat)", ("players",), True, closed),
    "accept.at": ring_split(lambda state: f"accept.at.claim({state}, seat, move)", ("players", "grabbing", "holding", "intake"), True, accept_leaf),
}


def view_leaf(shape: Shape, seat: int | None, _state: str) -> list[str]:
    """A seated seat's view from its cells; a missing seat reads the defaults on both sides."""
    if seat not in shape.seated:
        return ["{==}"]
    k = seat
    cells = [f"h{k}", f"S.jam.jammed(j{k})", f"A.jam.checked(j{k})", f"c{k}", f"s{k}", f"g{k}", f"o{k}", f"A.turn.held(A.turn.holder(phase), {SEATS[seat]})"]
    return [f"view.parts({', '.join(cells)})"]


# item-step-proof.bend's splits of the same kind, refuting through grab-proof.bend.
ITEM_BODIES |= {
    "view.eq": ring_split(lambda state: f"view.claim({state}, seat)", ("players", "grabbing", "holding"), True, view_leaf, "GP."),
    "health.eq": ring_split(lambda state: f"health.claim({state})", ("players",), False, closed, "GP."),
}

LOAD_BODIES: dict[str, Callable[[], list[str]]] = {
    "inventory.eq": ring_split(lambda state: f"inventory.claim({state})", ("players",), False, closed, "GP."),
}

FILES = {PROOF: BODIES, ITEM_PROOF: ITEM_BODIES, GRAB_PROOF: GRAB_BODIES, LOAD_PROOF: LOAD_BODIES}


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
        description="Generate the case-split proof bodies of the proof files."
    )
    parser.add_argument("--write", action="store_true", help="rewrite the proof files")
    args = parser.parse_args()
    stale = []
    total = sum(len(bodies) for bodies in FILES.values())
    for path, bodies in FILES.items():
        text = path.read_text()
        for name, generate in bodies.items():
            body = "\n".join(indent(2, generate()))
            start, end = body_span(text, name)
            if text[start:end] != body:
                stale.append(f"{path.name}:{name}")
                text = text[:start] + body + text[end:]
        if args.write:
            path.write_text(text)
    if args.write:
        print(f"rewrote {len(stale)} of {total} generated bodies")
        return 0
    if stale:
        print(
            f"proof files differ from tools/proof_cases.py: {', '.join(stale)}",
            file=sys.stderr,
        )
        return 1
    print(f"{total} generated proof bodies match tools/proof_cases.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
