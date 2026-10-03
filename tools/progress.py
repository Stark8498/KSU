#!/usr/bin/env python3
"""Do tien do de-obfuscate: bao nhieu dinh danh da co ten de doc.

    python tools/progress.py            # tong quan + top namespace con nhieu hex
    python tools/progress.py --todo     # liet ke hex con lai, nhieu nhat truoc

So sanh voi commit baseline (commit dau tien cua repo).
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEX = re.compile(r"_[0-9a-f]{8}")


def ruby_files() -> list[str]:
    out = []
    for p in sorted(ROOT.rglob("*.rb")):
        if "tools" in p.parts:
            continue
        out.append(p.relative_to(ROOT).as_posix())
    return out


def baseline_rev() -> str | None:
    r = subprocess.run(["git", "rev-list", "--max-parents=0", "HEAD"],
                       cwd=ROOT, capture_output=True, text=True)
    return r.stdout.strip() or None


def read_baseline(rel: str, rev: str) -> str:
    r = subprocess.run(["git", "show", f"{rev}:{rel}"], cwd=ROOT,
                       capture_output=True, text=True, encoding="utf-8")
    return r.stdout


def measure(texts: dict[str, str]) -> dict:
    names: set[str] = set()
    occ = 0
    defs: set[str] = set()
    ivars: set[str] = set()
    locs: set[str] = set()
    for t in texts.values():
        found = HEX.findall(t)
        occ += len(found)
        names |= set(found)
        defs |= set(re.findall(r"^\s*def\s+(?:self\.)?(_[0-9a-f]{8})", t, re.M))
        ivars |= set(re.findall(r"@(_[0-9a-f]{8})", t))
        locs |= set(re.findall(
            r"(?:^|[\s(|,])(_[0-9a-f]{8})\s*(?:,\s*_[0-9a-f]{8}\s*)*=(?!=|~|>)",
            t, re.M))
        for m in re.finditer(r"\|([^|\n]*)\|", t):
            locs |= set(HEX.findall(m.group(1)))
    return {"names": names, "occ": occ, "defs": defs, "ivars": ivars, "locs": locs}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--todo", action="store_true",
                    help="liet ke hex con lai theo so lan xuat hien")
    args = ap.parse_args()

    files = ruby_files()
    now = measure({f: (ROOT / f).read_text(encoding="utf-8", errors="replace")
                   for f in files})

    rev = baseline_rev()
    if not rev:
        print("Khong tim thay commit baseline (repo chua co commit?).")
        print(f"Hien tai: {len(now['names'])} hex rieng, {now['occ']} lan xuat hien.")
        return 0
    old = measure({f: read_baseline(f, rev) for f in files})

    def row(label: str, o: int, n: int) -> str:
        done = o - n
        pct = (100.0 * done / o) if o else 0.0
        bar = "#" * int(pct / 5) + "." * (20 - int(pct / 5))
        return f"{label:24} {o:6} {n:6} {done:6}  {pct:5.1f}%  {bar}"

    print(f"baseline = {rev[:8]}\n")
    print(f"{'':24} {'dau':>6} {'con':>6} {'xong':>6}")
    print(row("Ten dinh danh rieng", len(old["names"]), len(now["names"])))
    print(row("  ten method", len(old["defs"]), len(now["defs"])))
    print(row("  bien thuc the @", len(old["ivars"]), len(now["ivars"])))
    print(row("  local / tham so", len(old["locs"]), len(now["locs"])))
    print(row("Lan xuat hien (text)", old["occ"], now["occ"]))

    # dem theo lan xuat hien de biet nen dat ten cai nao truoc
    freq: Counter = Counter()
    where: dict[str, str] = {}
    for f in files:
        t = (ROOT / f).read_text(encoding="utf-8", errors="replace")
        for h in HEX.findall(t):
            freq[h] += 1
        for m in re.finditer(r"^\s*def\s+(?:self\.)?(_[0-9a-f]{8})", t, re.M):
            where.setdefault(m.group(1), f)

    if args.todo:
        print(f"\n{len(freq)} hex con lai, nhieu nhat truoc:\n")
        for h, c in freq.most_common():
            kind = "method" if h in now["defs"] else (
                "ivar" if h in now["ivars"] else "local")
            print(f"  {c:5}  {h}  {kind:7} {where.get(h, '')}")
        return 0

    print("\n10 hex con lai duoc dung nhieu nhat (dat ten truoc se loi nhat):\n")
    for h, c in freq.most_common(10):
        kind = "method" if h in now["defs"] else (
            "ivar" if h in now["ivars"] else "local")
        print(f"  {c:5}  {h}  {kind:7} {where.get(h, '')}")

    # namespace con nhieu method hex nhat
    per: Counter = Counter()
    for f in files:
        t = (ROOT / f).read_text(encoding="utf-8", errors="replace")
        n = len(re.findall(r"^\s*def\s+(?:self\.)?(_[0-9a-f]{8})", t, re.M))
        if n:
            per[f] = n
    print("\n10 file con nhieu method chua dat ten nhat:\n")
    for f, n in per.most_common(10):
        print(f"  {n:4} method  {f}")
    print("\nXem tools/names.core.yml de bo sung ten; "
          "python tools/usage.py <hex> de tra ngu canh.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
