"""Configs that requested different efforts and ran the same, from web/src/arena/same-treatments.json (the site reads it too).

Each group counts as one config, its effort the requested efforts joined by "/". Seat labels keep the effort each match requested.
"""

import json
from pathlib import Path

EFFORTS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"]

_GROUPS = json.loads((Path(__file__).resolve().parents[3] / "web/src/arena/same-treatments.json").read_text())
_EFFORT_OF = {(group["model"], effort): "/".join(group["efforts"]) for group in _GROUPS for effort in group["efforts"]}


def config_effort(model: str, effort: str) -> str:
    """The effort a model's config counts under."""
    return _EFFORT_OF.get((model, effort), effort)


def config_label(label: str) -> str:
    """A seat label as the config it counts as: `<model>-<effort>`, or the label itself for a seat with no effort."""
    model, _, effort = label.rpartition("-")
    return f"{model}-{_EFFORT_OF[model, effort]}" if (model, effort) in _EFFORT_OF else label


def effort_rank(effort: str) -> int:
    """Where an effort sorts, weakest first: a same-treatment group at its weakest effort."""
    return EFFORTS.index(effort.split("/")[0])
