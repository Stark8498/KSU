#!/usr/bin/env python3
"""Ho so mot hex: no la gi, dung o dau, bi goi method gi len no.

Dung cho "lan A" -- cac hex trai nhieu namespace, phai tim MOT ten dung o MOI cho.

    python tools/profile.py _e09e9747          # ho so 1 hex
    python tools/profile.py --rank             # xep hang hex xuyen suot
    python tools/profile.py --batch 20         # ho so 20 hex hang dau (chua co ten)
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEX = re.compile(r"_[0-9a-f]{8}")


def rb_files():
    return [p for p in sorted(ROOT.rglob("*.rb")) if "tools" not in p.parts]


def scan():
    """Tra ve dict hex -> ho so."""
    info = defaultdict(lambda: {
        "n": 0, "ns": set(), "files": set(), "calls": Counter(),
        "assign": [], "def_at": None, "kind": set(), "params": 0,
        "blockvar": 0, "index": 0, "iter": Counter(),
    })
    for p in rb_files():
        rel = p.relative_to(ROOT).as_posix()
        stack = []
        for lineno, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            m = re.match(r"^(\s*)(?:module|class)\s+([A-Z][\w:]*)", line)
            if m:
                stack = [s for s in stack if s[0] < len(m.group(1))]
                stack.append((len(m.group(1)), m.group(2)))
            here = "::".join(s[1] for s in stack) or rel

            for h in set(HEX.findall(line)):
                d = info[h]
                d["ns"].add(here)
                d["files"].add(rel)
            for h in HEX.findall(line):
                info[h]["n"] += 1

            # dinh nghia method
            for m2 in re.finditer(r"^\s*def\s+(self\.)?(_[0-9a-f]{8})", line):
                info[m2.group(2)]["def_at"] = f"{rel}:{lineno}"
                info[m2.group(2)]["kind"].add("method")
            # ivar
            for h in re.findall(r"@(_[0-9a-f]{8})", line):
                info[h]["kind"].add("ivar")
            # tham so cua def
            m3 = re.match(r"^\s*def\s+(?:self\.)?[\w?!=]+\s*\((.*)\)", line)
            if m3:
                for h in HEX.findall(m3.group(1)):
                    info[h]["kind"].add("param")
                    info[h]["params"] += 1
            # bien block  |a, b|
            for m4 in re.finditer(r"\|([^|\n]*)\|", line):
                for h in HEX.findall(m4.group(1)):
                    info[h]["kind"].add("block")
                    info[h]["blockvar"] += 1
            # gan:  x = RHS
            m5 = re.match(r"^\s*@?(_[0-9a-f]{8})\s*(?:\|\|)?=(?!=|~|>)\s*(.+?)\s*$", line)
            if m5:
                info[m5.group(1)]["kind"].add("local")
                rhs = m5.group(2)
                if len(info[m5.group(1)]["assign"]) < 400:
                    info[m5.group(1)]["assign"].append((rel, lineno, rhs))
            # method goi len no:  hex.foo   /  hex[...]
            for m6 in re.finditer(r"@?(_[0-9a-f]{8})\.([a-zA-Z_][\w?!]*)", line):
                info[m6.group(1)]["calls"][m6.group(2)] += 1
            for m7 in re.finditer(r"@?(_[0-9a-f]{8})\[", line):
                info[m7.group(1)]["index"] += 1
            # duoc lap qua: for x in hex / hex.each
            for m8 in re.finditer(r"@?(_[0-9a-f]{8})\.(each|map|select|reject|find|sum|min_by|max_by|sort_by|any\?|all\?|first|last|length|size|empty\?|include\?|each_with_index|flat_map|uniq|reverse|zip|count)\b", line):
                info[m8.group(1)]["iter"][m8.group(2)] += 1
    return info


def named_hexes() -> set[str]:
    """Hex da co ten trong yml (de --batch bo qua)."""
    out = set()
    for f in ("names.core.yml", "names.license.yml"):
        p = ROOT / "tools" / f
        if p.exists():
            for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
                m = re.match(r"\s*(_[0-9a-f]{8})\s*:\s*(\S+)", line)
                if m:
                    out.add(m.group(1))
    return out


def show(h: str, d: dict, verbose=True):
    kinds = ",".join(sorted(d["kind"])) or "?"
    print(f"\n{'='*78}\n{h}   {d['n']} lan | {len(d['ns'])} namespace | {len(d['files'])} file | {kinds}")
    if d["def_at"]:
        print(f"  def tai: {d['def_at']}")
    if d["params"]:
        print(f"  la tham so cua def: {d['params']} lan")
    if d["blockvar"]:
        print(f"  la bien block: {d['blockvar']} lan")
    if d["index"]:
        print(f"  bi index hex[..]: {d['index']} lan   -> array/hash?")
    if d["iter"]:
        print(f"  duoc lap qua: {dict(d['iter'].most_common(8))}   -> COLLECTION")
    if d["calls"]:
        print(f"  method goi len no ({sum(d['calls'].values())} lan):")
        for k, c in d["calls"].most_common(14):
            print(f"      .{k:<22} {c}")
    if verbose and d["assign"]:
        print(f"  {len(d['assign'])} cho gan, mau:")
        seen = set()
        shown = 0
        for rel, ln, rhs in d["assign"]:
            sig = re.sub(r"_[0-9a-f]{8}", "_H", rhs)[:70]
            if sig in seen:
                continue
            seen.add(sig)
            print(f"      {rel}:{ln}  = {rhs[:88]}")
            shown += 1
            if shown >= 12:
                print(f"      ... ({len(d['assign'])-shown} cho gan nua)")
                break
    if verbose:
        ns = sorted(d["ns"])
        print(f"  namespace: {', '.join(ns[:12])}{' ...' if len(ns) > 12 else ''}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("hex", nargs="*")
    ap.add_argument("--rank", action="store_true", help="xep hang hex xuyen suot")
    ap.add_argument("--batch", type=int, default=0, help="ho so N hex hang dau chua co ten")
    ap.add_argument("--min-ns", type=int, default=5)
    args = ap.parse_args()

    info = scan()
    have = named_hexes()

    if args.rank:
        rows = [(h, d) for h, d in info.items() if len(d["ns"]) >= args.min_ns and h not in have]
        rows.sort(key=lambda r: -r[1]["n"])
        print(f"{len(rows)} hex trai >={args.min_ns} namespace, chua co ten:\n")
        print(f"  {'lan':>5} {'ns':>4}  {'hex':<11} kind")
        for h, d in rows:
            print(f"  {d['n']:5} {len(d['ns']):4}  {h:<11} {','.join(sorted(d['kind'])) or '?'}")
        print(f"\ntong {sum(d['n'] for _, d in rows)} lan xuat hien")
        return 0

    if args.batch:
        rows = [(h, d) for h, d in info.items() if len(d["ns"]) >= args.min_ns and h not in have]
        rows.sort(key=lambda r: -r[1]["n"])
        for h, d in rows[:args.batch]:
            show(h, d)
        return 0

    for h in args.hex:
        if h not in info:
            print(f"{h}: khong thay")
            continue
        show(h, info[h])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
