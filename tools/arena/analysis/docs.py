"""Generated sections of the docs."""

from pathlib import Path


def splice_between_markers(path: Path, name: str, body: str) -> None:
    """Replace what lies between the <!-- name:start --> and <!-- name:end --> lines of the file with body."""
    start, end = f"<!-- {name}:start -->", f"<!-- {name}:end -->"
    head, found, rest = path.read_text().partition(start)
    if not found or end not in rest:
        raise ValueError(f"{path} lacks the {start} / {end} markers")
    path.write_text(head + start + "\n" + body.strip("\n") + "\n" + end + rest.partition(end)[2])
