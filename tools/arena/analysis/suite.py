"""A fixed position suite: a stratified sample of recorded agent decisions, each with the prompt its player saw rebuilt.

    python3 tools/arena/analysis/suite.py --out _work/arena/suite/positions.jsonl [--per-cell 20] [--seed 1]

Cells are shells left (1, 2, 3, 4, 5+), whether the menu offers an item, and the score spread between the best and the
worst move (under 2 points, 2 to 10, 10 or more), from the production regret file and the knowledge database. Each cell
gives `--per-cell` decisions at random; every exact row whose recorded move lost is added on top, as stratum "exact".

Each position carries the turn inputs of its player in that match, oldest first, each with the move the player made
from it; the last one is the decision's own. A move made in the same reply as the one before it has no input.
`web/scripts/arena-suite.ts` turns them into the request the arena sends: the shared instructions, then each input, a
play_move call and its result. The player's own text and reasoning, any get_game calls, reminders and retried inputs
are left out, so every config is asked the same position. The inputs are rebuilt from the decisions table and checked
against the match's session store, the conversation the model was really sent; any difference stops the run with a
dump. The hash of the stored system message goes with each position, and the asking script stops unless it sends the
same one.
"""

import argparse
import json
import random
import sqlite3
from collections import defaultdict
from hashlib import sha256
from pathlib import Path

from load import DB, connect
from regret import DERIVED, PRODUCTION
from rules import POINT

KNOWLEDGE = DERIVED / "knowledge.sqlite"
SHELLS = ("1", "2", "3", "4", "5+")
SPREADS = ("<2", "2-10", "10+")


def cell_of(remaining: int, menu: list[dict], values: list[dict]) -> tuple[str, str, str]:
    """A decision's cell: shells left, whether the menu offers an item, and the spread of its moves' scores in points."""
    scores = [value["score"] for value in values]
    spread = (max(scores) - min(scores)) / POINT
    has_item = any(not move["label"].startswith("Shoot") for move in menu)
    return SHELLS[min(remaining, 5) - 1], "item" if has_item else "shoot", SPREADS[(spread >= 2) + (spread >= 10)]


def cell_key(row: tuple) -> str:
    return "/".join(cell_of(row[8], json.loads(row[4]), json.loads(row[5])))


def population(db: sqlite3.Connection) -> list[tuple]:
    """Every agent decision of a completed match with its own turn input, a searched production row and at least two moves,
    by a player on the shared instructions alone."""
    return db.execute(
        """SELECT d.match_id, d.ordinal, d.player, s.label, d.legal_json, r.values_json, r.exact, r.regret, k.remaining
           FROM decisions d
           JOIN matches m ON m.id = d.match_id AND m.status = 'completed'
           JOIN match_seats s ON s.match_id = d.match_id AND s.player = d.player
           JOIN entrants e ON e.id = s.entrant_id AND json_extract(e.config_json, '$.instructionsAddendum') IS NULL
           JOIN regret.regret r ON r.match_id = d.match_id AND r.ordinal = d.ordinal AND r.status = 'searched'
           JOIN knowledge.decisions k ON k.match_id = d.match_id AND k.ordinal = d.ordinal
           WHERE d.by_whom = 'agent' AND d.delivered_json != '[]' AND json_array_length(d.legal_json) > 1
           ORDER BY d.match_id, d.ordinal"""
    ).fetchall()


def draw(rows: list[tuple], per_cell: int, seed: int) -> list[tuple[str, tuple]]:
    """`per_cell` rows of each cell at random, then every exact row whose move lost, each with its stratum."""
    cells = defaultdict(list)
    for row in rows:
        cells[cell_key(row)].append(row)
    rng = random.Random(seed)
    picked = [(cell, row) for cell in sorted(cells) for row in rng.sample(cells[cell], min(per_cell, len(cells[cell])))]
    taken = {(row[0], row[1]) for _, row in picked}
    return picked + [("exact", row) for row in rows if row[6] == 1 and row[7] > 0 and (row[0], row[1]) not in taken]


def turn_input(visible: str, delivered: str) -> str:
    """A turn input as match.ts writes it: the view, with the log entries delivered with it in place of the view's own."""
    view = json.loads(visible)
    entries = [entry for line in json.loads(delivered) for entry in line["entries"]]
    if entries:
        view["events"] = entries
    else:
        view.pop("events", None)
    return "Your turn.\n" + json.dumps(view, separators=(",", ":"), ensure_ascii=False)


def stored_conversation(source_dir: str, player: str) -> tuple[list[str], str]:
    """The turn inputs the player's conversation holds, in order, and the SHA-256 of its system message's sections and tools,
    after checking its start is the arena's: input, system, reply."""
    store = sqlite3.connect(f"file:{source_dir}/session.sqlite?mode=ro", uri=True)
    entries = [json.loads(record) for (record,) in store.execute("SELECT record FROM entries ORDER BY id")]
    store.close()
    mine = [entry for entry in entries if entry["kind"] == "pi.user" and f'"you":"{player}"' in entry["model"][0]["content"]]
    conversation = [entry for entry in entries if entry["conversationId"] == mine[0]["conversationId"]]
    if [entry["kind"] for entry in conversation[:3]] != ["pi.user", "pi.system", "pi.assistant"] or sum(entry["kind"] == "pi.system" for entry in conversation) != 1:
        raise SystemExit(f"{source_dir} player {player}: the conversation does not start as the arena starts one: {[entry['kind'] for entry in conversation[:5]]}")
    inputs = [entry["model"][0]["content"] for entry in conversation if entry["kind"] == "pi.user" and entry["model"][0]["content"].startswith("Your turn.")]
    # A retry after a model error sends its turn's input again, without the log entries the first one carried.
    turns = [json.loads(text[text.index("{") :])["turn"] for text in inputs]
    system = conversation[1]["model"][0]
    system_sha = sha256(json.dumps({"sections": system["sections"], "toolsAdded": system["toolsAdded"]}, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()
    return [text for index, text in enumerate(inputs) if index == 0 or turns[index] != turns[index - 1]], system_sha


def position(db: sqlite3.Connection, stratum: str, row: tuple, dumps: Path) -> dict:
    """One position: its decision, the config that played it, its scores, and its player's turn inputs up to it."""
    match_id, ordinal, player, label, _menu, values, exact, regret, remaining = row
    source_dir, seed = db.execute("SELECT source_dir, seed FROM matches WHERE id = ?", (match_id,)).fetchone()
    # A move with no delivery of its own came in the same reply as the move before it, so it has no input.
    turns = [
        {"input": turn_input(visible, delivered) if delivered != "[]" else None, "turn": turn, "move": move, "label": played}
        for visible, delivered, turn, move, played in db.execute(
            "SELECT visible_json, delivered_json, turn, selected_move, label FROM decisions WHERE match_id = ? AND player = ? AND by_whom = 'agent' AND ordinal <= ? ORDER BY ordinal", (match_id, player, ordinal)
        )
    ]
    rebuilt = [turn["input"] for turn in turns if turn["input"] is not None]
    stored, system_sha = stored_conversation(source_dir, player)
    stored = stored[: len(rebuilt)]
    if rebuilt != stored or turns[0]["input"] is None:
        dump = dumps / f"{match_id}-{ordinal}.json"
        dumps.mkdir(parents=True, exist_ok=True)
        dump.write_text(json.dumps({"match_id": match_id, "ordinal": ordinal, "player": player, "source_dir": source_dir, "rebuilt": rebuilt, "stored": stored}, indent=1))
        raise SystemExit(f"the rebuilt turn inputs differ from the session store; see {dump}")
    return {
        "match_id": match_id,
        "ordinal": ordinal,
        "player": player,
        "seed": seed,
        "config": label,
        "stratum": stratum,
        "shells": remaining,
        "values": json.loads(values),
        "exact": exact == 1,
        "regret": regret,
        "system_sha": system_sha,
        "turns": turns,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--db", default=DB)
    parser.add_argument("--regret", default=str(PRODUCTION))
    parser.add_argument("--knowledge", default=str(KNOWLEDGE))
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--per-cell", type=int, default=20)
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()
    db = connect(args.db, regret=args.regret, knowledge=args.knowledge)
    rows = population(db)
    picked = draw(rows, args.per_cell, args.seed)
    sizes = defaultdict(int)
    for row in rows:
        sizes[cell_key(row)] += 1
        sizes["exact"] += row[6] == 1 and row[7] > 0
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w") as out:
        for stratum, row in picked:
            out.write(json.dumps({**position(db, stratum, row, args.out.parent / "suite-bugs"), "stratum_size": sizes[stratum]}) + "\n")
    print(f"{len(picked)} positions from {len(rows)} decisions in {len(sizes) - 1} cells ({sum(s == 'exact' for s, _ in picked)} exact) -> {args.out}")


if __name__ == "__main__":
    main()
