"""Generate A-level wrappers for the reference, for abstract.bend.

Not part of check.sh: proof files import ref/ directly, so abstract.bend
carries no generated section. Run this only if you want thin
A-level wrappers again (removed in 4a1e122 because almost none were called).

    python3 tools/ref_api.py          # print the section
    python3 tools/ref_api.py --write  # (re)write it at the end of abstract.bend

Names: ref_main.X, ref_items.X, ref_rules.X, ref_state.X wrap the reference
module's def X; frame_X and cont_X build the Frame and Continuation
constructor X (a leading underscore is dropped).
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
ABSTRACT = HERE / "abstract.bend"
BEGIN = "# BEGIN GENERATED REF API (tools/ref_api.py)\n"
END = "# END GENERATED REF API\n"

# module key -> (file, alias in abstract.bend, alias map of that file's imports)
MODULES = {
    "main": ("ref/main.bend", "R", {"S": "H", "G": "G", "I": "RI", "D": "D"}),
    "items": ("ref/items.bend", "RI", {"S": "H", "G": "G", "D": "D"}),
    "rules": ("ref/rules.bend", "G", {"S": "H", "D": "D"}),
    "state": ("ref/state.bend", "H", {"D": "D"}),
}


def split_top(text: str) -> list[str]:
    """Split on commas outside brackets."""
    parts, depth, current = [], 0, ""
    for ch in text:
        depth += ch in "{([<"
        depth -= ch in "})]>"
        if ch == "," and depth == 0:
            parts.append(current.strip())
            current = ""
        else:
            current += ch
    parts.append(current.strip())
    return [p for p in parts if p]


def qualify(tp: str, alias: str, imports: dict[str, str], local: list[str]) -> str:
    tp = re.sub(
        r"\b([A-Z])\.(\w+)", lambda m: f"{imports[m.group(1)]}.{m.group(2)}", tp
    )
    for name in local:
        tp = re.sub(rf"(?<![\w.]){name}\b", f"{alias}.{name}", tp)
    return tp


def wrappers(key: str) -> list[str]:
    file, alias, imports = MODULES[key]
    src = (HERE / file).read_text()
    local = re.findall(r"^type (\w+)", src, re.M)
    out = []
    for name, params, ret in re.findall(r"^def ([\w.]+)\((.*)\) -> (.*):$", src, re.M):
        if "T." in params + ret:  # the audit snapshot type stays in ref/
            continue
        names, typed = [], []
        for param in split_top(params):
            pname, ptype = param.split(":", 1)
            names.append(pname.strip().lstrip("+-"))
            typed.append(
                f"{pname.strip()}: {qualify(ptype.strip(), alias, imports, local)}"
            )
        ret = qualify(ret, alias, imports, local)
        out.append(
            f"def ref_{key}.{name}({', '.join(typed)}) -> {ret}:\n  {alias}.{name}({', '.join(names)})\n"
        )
    return out


def constructors(type_name: str, prefix: str, result: str) -> list[str]:
    _, alias, imports = MODULES["main"]
    src = (HERE / "ref/main.bend").read_text()
    local = re.findall(r"^type (\w+)", src, re.M)
    body = re.search(rf"^type {type_name} is Data:\n((?:  .*\n)+)", src, re.M).group(1)
    out = []
    for name, fields in re.findall(r"^\s+(\w+)\{(.*)\}$", body, re.M):
        pairs = [field.split(":", 1) for field in split_top(fields)]
        typed = ", ".join(
            f"{n.strip()}: {qualify(t.strip(), alias, imports, local)}"
            for n, t in pairs
        )
        args = ", ".join(n.strip() for n, _ in pairs)
        out.append(
            f"def {prefix}{name.lstrip('_')}({typed}) -> {result}:\n  R.{name}{{{args}}}\n"
        )
    return out


def section() -> str:
    defs = constructors("Frame", "frame_", "R.Frame") + constructors(
        "Continuation", "cont_", "R.Continuation"
    )
    for key in MODULES:
        defs += wrappers(key)
    return BEGIN + "\n" + "\n".join(defs) + "\n" + END


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Append the reference API section to abstract.bend, or print it."
    )
    parser.add_argument("--write", action="store_true", help="append to abstract.bend")
    args = parser.parse_args()
    if not args.write:
        print(section(), end="")
        return 0
    text = ABSTRACT.read_text()
    if BEGIN in text:
        start, end = text.index(BEGIN), text.index(END) + len(END)
        text = text[:start] + text[end:]
    ABSTRACT.write_text(text.rstrip("\n") + "\n\n" + section())
    print("wrote the generated reference API section to abstract.bend")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
