#!/usr/bin/env python3
"""Emit the call sites for tools/thu_su.rb to re-check inside SketchUp.

verify_graph.py answers a weaker question than it looks: it only asks whether
some file defines a method of that name, because Ruby's `include` makes any
stricter static rule wrong. Ruby itself does not have to guess. Loaded in
SketchUp, `KSU::Sheet.respond_to?(:bottom)` resolves through the real ancestor
chain, so every include, extend, prepend and `class << self` is accounted for.

What goes in the file: each `KSU::Something.method` call site found in the tree,
with the file and line, so a failure points at the line to read. Text is masked
first -- a method name inside a Vietnamese caption is not a call.

    python tools/sinhgoi.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import ROOT, PKG, code_only  # noqa: E402

# KSU, or KSU::Foo::Bar, followed by a method call.
CALL = re.compile(r"\b(KSU(?:::[A-Z]\w*)*)\.([a-z_]\w*[?!]?)")

# Constants, not namespaces: `KSU::VERSION.to_s` calls String#to_s, and
# `KSU::TOL.abs` calls Float#abs. Neither says anything about this tree.
CONST = re.compile(r"::[A-Z0-9_]+$")

# Defined by Ruby or by SketchUp on every object, so reaching one proves
# nothing and a missing one is not our bug.
UNIVERSAL = set("""
new name to_s to_a to_i to_f inspect class freeze frozen? dup clone hash
instance_variable_get instance_variable_set respond_to? send public_send
instance_of? is_a? kind_of? nil? tap then equal? method methods
""".split())


def main() -> int:
    out: list[dict] = []
    seen: set[tuple[str, str]] = set()
    for path in sorted((ROOT / PKG).rglob("*.rb")):
        rel = path.relative_to(ROOT).as_posix()
        code = code_only(path.read_text(encoding="utf-8", errors="replace"))
        for i, line in enumerate(code.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for ns, meth in CALL.findall(line):
                if CONST.search(ns) or meth in UNIVERSAL:
                    continue
                if (ns, meth) in seen:
                    continue
                seen.add((ns, meth))
                out.append({"ns": ns, "m": meth, "f": rel, "l": i})

    mods = set()
    for path in sorted((ROOT / PKG).rglob("*.rb")):
        code = code_only(path.read_text(encoding="utf-8", errors="replace"))
        for m in re.findall(r"^\s*(?:module|class)\s+(KSU(?:::[A-Z]\w*)*)",
                            code, re.M):
            mods.add(m)

    dst = ROOT / "tools" / "goi.json"
    dst.write_text(json.dumps({"calls": out, "modules": sorted(mods)},
                              ensure_ascii=False, indent=1),
                   encoding="utf-8", newline="")
    print(f"{len(out)} loi goi rieng, {len(mods)} module -> tools/goi.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
