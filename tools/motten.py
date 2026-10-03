#!/usr/bin/env python3
"""Glean names the obfuscator could not take away.

It renamed identifiers. It could not rename text, and a lot of this code names
its own variables in text right next to them:

  rect = h[:rect]            a hash key is a string literal, not an identifier
  { size: s, font: f }       so is a hash label
  g.get_attribute("KSU", "do_day")
  instance_variable_defined?("@label_section_hidden")

It also skipped identifiers whose names collide with a Ruby or SketchUp API
name, so a signature can read `def draw(view, _c2148d5e, y)` -- and a hex that
stands between `view` and `y` in 48 signatures is `x`, proved by its neighbours
rather than guessed from its body.

Each rule below votes. A hex is proposed only when every vote agrees and there
are at least --min of them; disagreement means the hex carries more than one
meaning and has to be read by hand. A wrong name is worse than hex.

    python tools/motten.py                 # xem de xuat
    python tools/motten.py --min 3
    python tools/motten.py -o motten.yml   # ghi ra de soat roi chep sang ten.yml
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import ROOT, HEX, IDENT, RUBY_KEYWORDS, ruby_files  # noqa: E402

H = r"_[0-9a-f]{8}"

RULES = [
    # hex = something[:key]            -- the key names the thing
    ("khoa-hash", re.compile(rf"\b({H})\s*(?:\|\|)?=\s*[^=\n]*?\[:\s*([a-z_]\w*)\s*\]\s*$")),
    # key: hex                         -- a hash label or keyword argument
    ("nhan-hash", re.compile(rf"(?<![\w:])([a-z_]\w*):\s*({H})\b")),
    # hex = x.get_attribute("DICT", "name" ...)
    ("thuoc-tinh", re.compile(rf"\b({H})\s*=\s*[^=\n]*?get_attribute\(\s*\"[^\"]*\"\s*,\s*\"([a-z_]\w*)\"")),
    # hex = h.fetch(:key ...) / h.dig(:key)
    ("fetch", re.compile(rf"\b({H})\s*=\s*[^=\n]*?\b(?:fetch|dig)\(\s*:([a-z_]\w*)")),
]
# The first group is the name and the second the hex in this one.
SWAPPED = {"nhan-hash"}

# def f(view, HEX, y) -- a hex between two surviving names takes the name its
# neighbours imply. Only the exact x/y pair is claimed: it is the SketchUp
# convention (onMouseMove, pick, screen_coords) and it is unambiguous.
SIG = re.compile(rf"\bdef\s+(?:self\.)?\w+[?!]?\s*\(([^)]*)\)")
NEIGHBOUR = {("view", "y"): "x", ("x", None): None}


def vote(votes: dict, h: str, name: str, rule: str, where: str) -> None:
    if not IDENT.match(name) or name in RUBY_KEYWORDS or HEX.match(name):
        return
    votes[h][name] += 1
    votes[h].setdefault  # keep type stable
    SITES[(h, name)].append(f"{rule} {where}")


SITES: dict[tuple[str, str], list[str]] = defaultdict(list)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--min", type=int, default=2,
                    help="so phieu toi thieu (mac dinh 2)")
    ap.add_argument("--troi", type=float, default=4.0,
                    help="phieu dau phai gap bao nhieu lan phieu nhi (mac dinh 4)")
    ap.add_argument("-o", "--out", help="ghi ra tools/<file>")
    args = ap.parse_args()

    votes: dict[str, Counter] = defaultdict(Counter)

    for p in ruby_files():
        rel = p.relative_to(ROOT).as_posix()
        for i, line in enumerate(p.read_text(encoding="utf-8",
                                             errors="replace").splitlines(), 1):
            for rule, rx in RULES:
                for a, b in rx.findall(line):
                    h, name = (b, a) if rule in SWAPPED else (a, b)
                    if HEX.match(h):
                        vote(votes, h, name, rule, f"{rel}:{i}")

            # Positional evidence from a signature.
            for params in SIG.findall(line):
                toks = [t.strip().split(":")[0].split("=")[0].strip()
                        for t in params.split(",")]
                for k in range(1, len(toks) - 1):
                    if (re.fullmatch(H, toks[k]) and toks[k - 1] == "view"
                            and toks[k + 1] == "y"):
                        vote(votes, toks[k], "x", "canh-y", f"{rel}:{i}")

    # A hex named at many sites usually picks up a few one-off labels: `x` is
    # also written `lx` or `x1` somewhere. That is not two meanings, it is one
    # meaning spelled loosely, so a clear majority still decides. Two votes
    # against one does NOT -- that is a real split, and it stays hex.
    agreed, split = {}, {}
    for h, c in sorted(votes.items()):
        top, n_top = c.most_common(1)[0]
        rest = c.most_common(2)[1][1] if len(c) > 1 else 0
        if n_top >= args.min and (len(c) == 1 or n_top >= max(args.troi * rest, 3)):
            agreed[h] = top
        elif len(c) > 1:
            split[h] = dict(c)

    print(f"{len(agreed)} hex co ten (>= {args.min} phieu, troi >= {args.troi}x), "
          f"{len(split)} hex phieu lech -- phai doc tay\n")
    for h, nm in sorted(agreed.items(), key=lambda kv: -votes[kv[0]][kv[1]]):
        c = votes[h]
        other = {k: v for k, v in c.items() if k != nm}
        tail = f"   (lech: {other})" if other else ""
        print(f"  {h} -> {nm:<20} {c[nm]:>3} phieu   {SITES[(h, nm)][0]}{tail}")

    if args.out:
        out = ROOT / "tools" / args.out
        lines = ["# Sinh boi tools/motten.py -- ten mot tu chuoi con sot lai.",
                 "# SOAT MAT roi hay chep sang ten.yml; file nay khong duoc ap thang.",
                 "ten:"]
        lines += [f"  {h}: {agreed[h]}" for h in sorted(agreed)]
        if split:
            lines += ["", "# Phieu lech -- de trong co chu y.", "mau_thuan:"]
            lines += [f"  {h}:   # {split[h]}" for h in sorted(split)]
        out.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"\nghi: tools/{args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
