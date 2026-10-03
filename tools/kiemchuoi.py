#!/usr/bin/env python3
"""Every string and comment must still read exactly as it did before renaming.

Why this is a check of its own: renaming touches identifiers, never text. But a
word-boundary replace is blind to Vietnamese. In "Khong co nhom" the c of "co"
is followed by a letter outside [A-Za-z0-9_], so \\bc\\b matches inside the word
and c -> ctr turns the sentence into "Khong ctro nhom" -- text the user reads,
broken silently. The ZSU tree had 21 captions corrupted this way across 7 files
before the check existed.

verify_structure.py cannot see it either: it masks identifiers and keeps text,
so a line whose text changed still compares equal under the mask.

What counts as text comes from kscommon.text_spans, which walks the source
instead of pattern-matching it, so a caption nested inside an interpolation --
"#{name || "Dang toi uu"}" -- is compared like any other.

    python tools/kiemchuoi.py [rev]        # mac dinh c45104c
"""
from __future__ import annotations

import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import ROOT, literals  # noqa: E402

DEFAULT_REV = "c45104c"

# The decrypted files open with an XSU_NOTICE constant that the readable tree
# does not keep: 88 copies of it make Ruby warn about an already initialised
# constant on every load. Dropped on both sides so the rest still lines up.
NOTICE = re.compile(r'\AXSU_NOTICE\s*=\s*"(?:[^"\\]|\\.)*"\s*\n')


def texts(src: str) -> Counter:
    return Counter(literals(NOTICE.sub("", src, count=1)))


def main() -> int:
    rev = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REV
    files = subprocess.run(["git", "show", "--name-only", "--format=", rev],
                           cwd=ROOT, capture_output=True, text=True,
                           check=True).stdout.split()
    bad = n = 0
    for rel in files:
        p = ROOT / rel
        if not p.is_file() or p.suffix != ".rb":
            continue
        n += 1
        old = subprocess.run(["git", "show", f"{rev}:{rel}"], cwd=ROOT,
                             capture_output=True, text=True,
                             encoding="utf-8").stdout
        a, b = texts(old), texts(p.read_text(encoding="utf-8", errors="replace"))
        mat, moi = a - b, b - a
        if not mat and not moi:
            continue
        bad += 1
        print(f"\nKHAC {rel}")
        for s in sorted(mat):
            print(f"  goc : {s[:120]!r}")
        for s in sorted(moi):
            print(f"  nay : {s[:120]!r}")
    print(f"\n{bad}/{n} file co chuoi/chu thich bi doi so voi {rev}")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
