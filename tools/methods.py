#!/usr/bin/env python3
"""Tom tat cac method CHUA DAT TEN trong mot file, de dat ten hang loat.

Ten method phai noi no LAM GI, nen suy kieu khong giup -- phai doc. Bo nay in
gon lai: chu ky, may dong dau, dong return, va cac khoa cai dat tieng Viet ma
than ham cham vao (nhung khoa nay khong bi lam roi nen rat giau thong tin).

    python tools/methods.py ksu_vn/method/dancanh.rb
    python tools/methods.py ksu_vn/method/dancanh.rb --full _abc12345
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rename as R                                              # noqa: E402

HEX = re.compile(r"_[0-9a-f]{8}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--full", help="in day du than mot method")
    ap.add_argument("--lines", type=int, default=4)
    args = ap.parse_args()

    p = R.ROOT / args.file
    lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    ns_stack: list[tuple[int, str]] = []
    ns_at: dict[int, str] = {}
    for i, line in enumerate(lines):
        m = re.match(r"^(\s*)(?:module|class)\s+([A-Z][\w:]*)", line)
        if m:
            ns_stack = [s for s in ns_stack if s[0] < len(m.group(1))]
            ns_stack.append((len(m.group(1)), m.group(2)))
        ns_at[i] = "::".join(s[1] for s in ns_stack)

    for lo, hi, nm in R.body_ranges(p):
        if not HEX.fullmatch(nm):
            continue
        if args.full and nm != args.full:
            continue
        body = lines[lo:hi + 1]
        sig = body[0].strip()
        keys = sorted(set(re.findall(r'[:"\']([a-z_]{4,}(?:_[a-z]+)+)["\']?', "\n".join(body))))
        rets = [b.strip() for b in body[1:] if re.match(r"\s*(return|[^#]*\bend\b)?", b)
                and b.strip().startswith("return")]
        print(f"\n--- {ns_at[lo]}  dong {lo + 1}-{hi + 1}  ({hi - lo + 1} dong)")
        print(f"  {sig}")
        if args.full:
            for b in body[1:]:
                print("  " + b.rstrip())
            continue
        shown = [b.strip() for b in body[1:-1] if b.strip()
                 and not b.strip().startswith("#")]
        for b in shown[:args.lines]:
            print(f"      {b[:110]}")
        if len(shown) > args.lines:
            print(f"      ... ({len(shown) - args.lines} dong nua)")
            if shown[-1] not in shown[:args.lines]:
                print(f"      cuoi: {shown[-1][:110]}")
        if rets:
            for r in rets[:2]:
                print(f"      {r[:110]}")
        if keys:
            print(f"      khoa: {', '.join(keys[:8])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
