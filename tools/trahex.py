#!/usr/bin/env python3
"""Look up which hex an APPLIED name at file:line came from.

Needed when a name turns out to be wrong. The name is in the code by then, so it
cannot be edited in place: `num2` was handed to four different hex, and a
textual retag would change all four. The fix is to know which hex it was, correct
that entry in the dictionary and rerun `datten.py --lam-lai`.

This works because verify_structure has already proved each rename is a rename
and nothing else: the two line counts match, off by exactly the one XSU_NOTICE
line stripped from the top of the file. So line N here is line N+1 of the
baseline.

    python tools/trahex.py ksu_vn/system/update.rb 83
    python tools/trahex.py ksu_vn/system/update.rb 83 --ten edge
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import ROOT  # noqa: E402

BASELINE = "c45104c"
IDENT = re.compile(r"[@$]?[A-Za-z_]\w*[?!]?")
HEX = re.compile(r"\A_[0-9a-f]{8}\Z")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("line", type=int)
    ap.add_argument("--ten", help="chi hoi ve mot ten")
    ap.add_argument("--moc", default=BASELINE)
    args = ap.parse_args()

    rel = Path(args.file).as_posix()
    now = (ROOT / rel).read_text(encoding="utf-8").splitlines()
    old = subprocess.run(["git", "show", f"{args.moc}:{rel}"], cwd=ROOT,
                         capture_output=True, text=True,
                         encoding="utf-8").stdout.splitlines()
    # The notice was the first line of every decrypted file and is gone now.
    if old and old[0].startswith("XSU_NOTICE"):
        old = old[1:]
    if args.line > len(now) or args.line > len(old):
        return print("dong vuot qua file") or 1

    a = IDENT.findall(now[args.line - 1])
    b = IDENT.findall(old[args.line - 1])
    if len(a) != len(b):
        print("CANH BAO: so dinh danh hai ben khac nhau, dong nay co the da lech")
    print(f"  nay : {now[args.line - 1].strip()[:110]}")
    print(f"  moc : {old[args.line - 1].strip()[:110]}\n")
    for x, y in zip(a, b):
        if x == y or (args.ten and x.lstrip("@") != args.ten):
            continue
        if HEX.match(y.lstrip("@")):
            print(f"  {x:<24} <- {y}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
