#!/usr/bin/env python3
"""Audit the METHOD names taken from the twin tree, by comparing BODIES.

Why this needs its own audit: tools/sinhdoi.py aligns the two files line by
line, by skeleton. The line `def _abc(x, y)` has the same skeleton as EVERY
other two-parameter `def` in the file, so difflib pairs one method with another
without any difficulty -- and the name lands on the wrong method. That is how
`_ffc7cdd6` (which starts the caret blink timer) came to be called `gap`, after
a function that returns Preset.cfg[:gap].

The audit: take the KSU body and the body THAT NAME belongs to on the ZSU side,
blank strings and comments, replace every identifier with one marker, and
measure the similarity. Two bodies cannot look alike by accident the way two
`def` lines can.

    python tools/soatham.py <cay-zsu-da-dat-ten>
    python tools/soatham.py <cay-zsu> --nguong 0.8
"""
from __future__ import annotations

import argparse
import difflib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import ROOT, PKG, code_only          # noqa: E402
from datten import (baseline_sources, body_ranges,  # noqa: E402
                    load_dicts, method_hexes)

try:
    import yaml
except ImportError:
    sys.exit("Can PyYAML: pip install pyyaml")

IDENT = re.compile(r"@?[a-z_][A-Za-z0-9_]*[?!]?")


def skeleton(body: str) -> list[str]:
    out = []
    for ln in body.splitlines():
        ln = IDENT.sub("\x00", ln).strip()
        if ln:
            out.append(ln)
    return out


def bodies_of(src: str) -> dict[str, str]:
    code = code_only(src)
    lines = code.splitlines()
    return {name: "\n".join(lines[lo:hi + 1])
            for lo, hi, name in body_ranges(code)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path, help="cay ZSU da dat ten")
    ap.add_argument("--nguong", type=float, default=0.75)
    args = ap.parse_args()

    twin = (yaml.safe_load((ROOT / "tools" / "sinhdoi.yml")
                           .read_text(encoding="utf-8")) or {}).get("ten") or {}
    defs = method_hexes()
    final = load_dicts()
    base = baseline_sources()
    zroot = args.src / "zsu_vn"

    checked = ok = suspect = 0
    rows = []
    for rel, src in sorted(base.items()):
        if "/" not in rel:
            continue
        zpath = zroot / rel.split("/", 1)[1]
        if not zpath.exists():
            continue
        ksu_b = bodies_of(src)
        zsu_b = bodies_of(re.sub(r"\bZSU\b", "KSU",
                                 zpath.read_text(encoding="utf-8", errors="replace")))
        for h, body in ksu_b.items():
            if h not in defs or h not in twin:
                continue
            nm = twin[h]
            checked += 1
            z = zsu_b.get(nm)
            if z is None:
                rows.append((0.0, rel, h, nm, "ZSU khong co method ten nay o file nay"))
                suspect += 1
                continue
            r = difflib.SequenceMatcher(None, skeleton(body), skeleton(z),
                                        autojunk=False).ratio()
            if r < args.nguong:
                rows.append((r, rel, h, nm, f"than ham giong {r:.0%}"))
                suspect += 1
            else:
                ok += 1

    rows.sort()
    print(f"soat {checked} ten method tu ban sinh doi: {ok} khop than ham, "
          f"{suspect} dang NGHI (nguong {args.nguong:.0%})\n")
    for r, rel, h, nm, why in rows:
        cur = final.get(h)
        cur = cur if isinstance(cur, str) else "(theo pham vi)"
        mark = "  " if cur == nm else "* "      # * = da duoc sua tay roi
        print(f"{mark}{h} -> {nm:<26} {why:<38} {rel}")
    if any(True for r, *_ in rows):
        print("\n* = tu dien hien tai da dat ten khac, khong con la van de.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
