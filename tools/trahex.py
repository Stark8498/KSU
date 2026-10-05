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
from kscommon import ROOT, code_only  # noqa: E402
from datten import body_ranges, load_dicts  # noqa: E402

BASELINE = "e72d0b2"
# The release before this one. 2.3.2 did NOT re-obfuscate everything, so the
# audit has to know which build a hex came from -- see audit() below.
PREV_BASELINE = "c45104c"
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


def scopes(hx: str, moc: str) -> int:
    """Every method body of the BASELINE that a hex appears in, as a scope key.

    A short local like `len` or `tr` belongs to one body and means something
    else in the next, so its entry has to be written `file#method: name`. The
    key names the body by the method name the SUBSTITUTION sees, and that pass
    rebuilds the tree from the baseline, where the method is still hex -- so the
    key is read off the baseline here, not off the readable tree.
    """
    rels = subprocess.run(["git", "ls-tree", "-r", "--name-only", moc, "ksu_vn"],
                          cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8").stdout.split()
    hits: dict[str, int] = {}
    loose = 0
    for rel in rels:
        if not rel.endswith(".rb"):
            continue
        src = subprocess.run(["git", "show", f"{moc}:{rel}"], cwd=ROOT,
                             capture_output=True, text=True,
                             encoding="utf-8").stdout
        if src.startswith("XSU_NOTICE"):
            src = src.split(chr(10), 1)[-1]
        code = code_only(src)
        owner: dict[int, str] = {}
        for lo, hi, mname in body_ranges(code):
            for i in range(lo, hi + 1):
                owner[i] = mname
        want = re.compile(r"\b" + re.escape(hx) + r"\b")
        for i, line in enumerate(code.splitlines()):
            if not want.search(line):
                continue
            m = owner.get(i)
            if m is None:
                loose += 1
            else:
                hits[f"{rel}#{m}"] = hits.get(f"{rel}#{m}", 0) + 1
    if not hits and not loose:
        print(f"khong thay {hx} trong {moc}")
        return 1
    print(f"  {hx}:")
    for k, n in sorted(hits.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f'    "{k}": ???      # {n} lan')
    if loose:
        print(f"  ({loose} lan nam ngoai moi than ham -- phai dat TOAN CUC)")
    return 0


_PREV_HEXES: set[str] | None = None


def prev_release_hexes() -> set[str]:
    """Every hex the PREVIOUS release's obfuscation produced."""
    global _PREV_HEXES
    if _PREV_HEXES is None:
        out = subprocess.run(["git", "ls-tree", "-r", "--name-only",
                              PREV_BASELINE, "--", "ksu_vn"], cwd=ROOT,
                             capture_output=True, text=True)
        _PREV_HEXES = set()
        for rel in out.stdout.split():
            if not rel.endswith(".rb"):
                continue
            src = subprocess.run(["git", "show", f"{PREV_BASELINE}:{rel}"],
                                 cwd=ROOT, capture_output=True, text=True,
                                 encoding="utf-8", errors="replace").stdout
            _PREV_HEXES |= set(re.findall(r"_[0-9a-f]{8}\b", src))
    return _PREV_HEXES


def audit(moc: str) -> int:
    """Invert the dictionary: which global names come from more than one hex.

    The obfuscator maps name -> hex once per BUILD, so the inverse of a correct
    dictionary is a function -- one name, one hex. Per-scope naming breaks the
    other direction on purpose (one hex becomes `arr` here and `pt` there,
    because that hex really does hold both), but never this one.

    2.3.2 carries two of those mappings, which is why the count is split below.
    The units it superseded -- toiuuvan*, netcatcuoi*, danhsovan -- ship
    verbatim from the 2.1.5 build and keep 100 % of their 2.1.5 hexes, while
    the files new in 2.3.2 share 0 % with 2.1.5. A word the author used in both
    halves therefore has one hex in each, and that is not an error: it is two
    builds of the same source. Only two hexes from the SAME build can be a
    mistake, so only those are reported as one.

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

    prev = prev_release_hexes()
    cross: dict[str, list[str]] = {}
    inside: dict[str, list[str]] = {}
    for n, hs in dup.items():
        seen: dict[str, int] = {}
        for h in hs:
            key = "2.1.5" if h in prev else "2.3.2"
            seen[key] = seen.get(key, 0) + 1
        (inside if max(seen.values()) > 1 else cross)[n] = hs

    print(f"soat {len(by_name)} ten toan cuc: "
          f"{len(dup)} ten den tu nhieu hon mot hex")
    print(f"  {len(cross):>4} ten moi hex mot DOT LAM ROI khac nhau"
          f"  -- khong phai loi")
    print(f"  {len(inside):>4} ten co hai hex trong CUNG mot dot"
          f"  -- phai doc lai\n")
    for n, hs in sorted(inside.items()):
        tag = ", ".join(f"{h}({'2.1.5' if h in prev else '2.3.2'})"
                        for h in sorted(hs))
        print(f"  {n:<24} {tag}")
    if inside:
        print("\nMoi dong tren la mot loi: trong MOT dot lam roi, trinh bao ve"
              "\nanh xa ten -> hex dung mot lan, nen hai hex cung dot khong the"
              "\ncung mang mot tu. Doc lai bang chung roi doi mot ben.")
    return 1 if inside else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("file", nargs="?")
    ap.add_argument("line", type=int, nargs="?")
    ap.add_argument("--ten", help="chi hoi ve mot ten")
    ap.add_argument("--tim", help="tra mot ten tren CA CAY, khong can file:dong")
    ap.add_argument("--pham-vi", dest="pham_vi",
                    help="hex nay nam trong nhung than ham nao (khoa pham vi)")
    ap.add_argument("--soat", action="store_true",
                    help="soat ca cay: ten nao den tu nhieu hon mot hex")
    ap.add_argument("--moc", default=BASELINE)
    args = ap.parse_args()

    if args.pham_vi:
        return scopes(args.pham_vi, args.moc)
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
