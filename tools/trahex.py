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
from datten import load_dicts  # noqa: E402

BASELINE = "c45104c"
IDENT = re.compile(r"[@$]?[A-Za-z_]\w*[?!]?")
HEX = re.compile(r"\A_[0-9a-f]{8}\Z")


def sweep(name: str, moc: str) -> int:
    """Every hex an applied name came from, read off the whole tree.

    Pairing a name with a hex by eye is where a name goes onto the wrong thing:
    a line often carries several identifiers, and picking the first hex on it
    silently pairs the name with a neighbour. This pairs them by POSITION, the
    way the single-line lookup does, and then reports what it found. One global
    name must come back from exactly one hex -- the obfuscator maps name to hex
    across the whole tree, so two means one of the two entries is a lie.
    """
    out = subprocess.run(["git", "ls-tree", "-r", "--name-only", moc, "ksu_vn"],
                         cwd=ROOT, capture_output=True, text=True,
                         encoding="utf-8").stdout.split()
    found: dict[str, list[str]] = {}
    for rel in out:
        if not rel.endswith(".rb"):
            continue
        path = ROOT / rel
        if not path.exists():
            continue
        now = path.read_text(encoding="utf-8", errors="replace").splitlines()
        old_src = subprocess.run(["git", "show", f"{moc}:{rel}"], cwd=ROOT,
                                 capture_output=True, text=True,
                                 encoding="utf-8").stdout.splitlines()
        if old_src and old_src[0].startswith("XSU_NOTICE"):
            old_src = old_src[1:]
        for i, (ln_now, ln_old) in enumerate(zip(now, old_src), 1):
            if name not in ln_now:
                continue
            a, b = IDENT.findall(ln_now), IDENT.findall(ln_old)
            if len(a) != len(b):
                continue
            for x, y in zip(a, b):
                if x.lstrip("@") == name and HEX.match(y.lstrip("@")):
                    found.setdefault(y.lstrip("@"), []).append(f"{rel}:{i}")
    if not found:
        print(f"khong thay ten `{name}` nao den tu hex")
        return 1
    for h, where in sorted(found.items(), key=lambda kv: -len(kv[1])):
        print(f"  {h}  {len(where):>4} lan   {where[0]}")
    if len(found) > 1:
        print(f"\n  {len(found)} hex cung cho ra ten `{name}`. Neu day la ten"
              f" TOAN CUC thi mot trong so do dat sai.")
    return 0


def audit(moc: str) -> int:
    """Invert the dictionary: which global names come from more than one hex.

    The obfuscator mapped name -> hex once for the whole tree, so the inverse of
    a correct dictionary is a function -- one name, one hex. Per-scope naming
    breaks the other direction on purpose (one hex becomes `arr` here and `pt`
    there, because that hex really does hold both), but never this one.

    Only GLOBAL entries are judged. A scoped entry claims nothing but the type a
    variable holds in one body, and dexuat.py hands the same short root to a
    different hex in every body by design. A global entry makes the other kind
    of claim: this hex IS the word the author typed. Two of those agreeing on
    one word contradict the mapping, so at least one is wrong -- and no other
    check can see it. Both renames are legal, the tree still loads, every string
    is untouched; only a reader is misled.
    """
    by_name: dict[str, list[str]] = {}
    for h, spec in load_dicts().items():
        if isinstance(spec, str):
            by_name.setdefault(spec, []).append(h)
    dup = {n: hs for n, hs in by_name.items() if len(hs) > 1}
    print(f"soat {len(by_name)} ten toan cuc: "
          f"{len(dup)} ten den tu nhieu hon mot hex\n")
    for n, hs in sorted(dup.items()):
        print(f"  {n:<24} {', '.join(sorted(hs))}")
    if dup:
        print("\nMoi dong tren la mot loi: bat bien noi mot ten ung voi dung"
              "\nmot hex. Doc lai bang chung roi doi mot ben sang ten khac.")
    return 1 if dup else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("file", nargs="?")
    ap.add_argument("line", type=int, nargs="?")
    ap.add_argument("--ten", help="chi hoi ve mot ten")
    ap.add_argument("--tim", help="tra mot ten tren CA CAY, khong can file:dong")
    ap.add_argument("--soat", action="store_true",
                    help="soat ca cay: ten nao den tu nhieu hon mot hex")
    ap.add_argument("--moc", default=BASELINE)
    args = ap.parse_args()

    if args.soat:
        return audit(args.moc)
    if args.tim:
        return sweep(args.tim, args.moc)
    if not args.file or args.line is None:
        return print("can <file> <dong>, hoac --tim <ten>") or 1

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
