"""Markdown formatting shared by the analysis tables."""


def pct(x: float) -> str:
    return f"{x * 100:.1f}%"


def pp(x: float) -> str:
    return f"{x * 100:+.1f}"


def span(interval, show=pct) -> str:
    return "n/a" if interval is None else f"{show(interval[0])} to {show(interval[1])}"


def signed(x: float) -> str:
    return f"{round(x):+d}"


def frac(wins: float, games: float) -> str:
    return f"{wins:g}/{games:g} = {pct(wins / games)}"


def table(header: list[str], rows: list[list[str]]) -> str:
    lines = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    return "\n".join(lines + ["| " + " | ".join(row) + " |" for row in rows])
