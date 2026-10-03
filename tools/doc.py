#!/usr/bin/env python3
"""Print a file the way it has to be READ to be named: only what still has hex.

A 600-line file may be down to 8 hex, and they cluster in a couple of methods.
Printing the whole file buries them in heredoc HTML and in methods that already
read fine. This prints every method that still contains hex, body included, plus
the lines outside any body that carry hex -- constants, dispatch tables.

    python tools/doc.py ksu_vn/method/caidat.rb
    python tools/doc.py ksu_vn/utils/*.rb --max 40
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import ROOT, HEX_ANY, code_only  # noqa: E402
from datten import body_ranges                 # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--max", type=int, default=70,
                    help="so dong toi da in cho mot method")
    args = ap.parse_args()

    for f in args.files:
        p = Path(f)
        if not p.is_absolute():
            p = ROOT / f
        src = p.read_text(encoding="utf-8", errors="replace")
        lines = src.splitlines()
        code = code_only(src)
        bodies = list(body_ranges(code))
        covered = set()
        print(f"\n{'=' * 78}\n== {p.relative_to(ROOT).as_posix()}  "
              f"({len(lines)} dong, {len(set(HEX_ANY.findall(src)))} hex)")
        for lo, hi, _ in bodies:
            covered |= set(range(lo, hi + 1))
            chunk = lines[lo:hi + 1]
            if not HEX_ANY.search(code[sum(len(x) + 1 for x in lines[:lo]):
                                       sum(len(x) + 1 for x in lines[:hi + 1])]):
                continue
            print()
            for k, ln in enumerate(chunk[:args.max], lo + 1):
                print(f"{k:>5}| {ln[:160]}")
            if len(chunk) > args.max:
                print(f"      | ... con {len(chunk) - args.max} dong")
        # Lines that live outside any method but still carry hex.
        loose = [(i, lines[i]) for i in range(len(lines))
                 if i not in covered and HEX_ANY.search(lines[i])]
        if loose:
            print("\n  -- ngoai than ham --")
            for i, ln in loose:
                print(f"{i + 1:>5}| {ln[:160]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
