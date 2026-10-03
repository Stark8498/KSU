#!/usr/bin/env python3
"""Carry names from the ZSU readable tree onto their KSU hex twins.

KSU and ZSU are two products by the same author and they share a utility
layer: utils/const.rb, utils/preset/*, utils/other.rb, utils/view.rb and more
are the same code with the module constant swapped. ZSU has already been read
out to 3.542 named identifiers, so wherever a KSU file still matches its ZSU
counterpart line for line, the names can be carried over mechanically instead
of being read by hand.

How a pair of lines is matched -- the same four rules the ZSU transfer used:

  1. Both sides are blanked of strings and comments (kscommon.code_only), so
     Vietnamese text can never be mistaken for an identifier.
  2. Every identifier is replaced by one marker, leaving a skeleton of
     punctuation, keywords and constants. The ZSU side has its `ZSU` constant
     rewritten to `KSU` first -- otherwise every qualified call reads as a
     difference and the skeletons never align.
  3. difflib aligns the two skeleton line lists. Only 'equal' blocks are used.
  4. Inside an aligned pair the identifier lists must be the same length, and
     every token that is NOT hex on the KSU side must read identically on the
     ZSU side. One mismatched API call means the line only looks aligned, and
     the whole line is dropped.

A hex is proposed only when every vote for it agrees. Disagreement means the
hex carries more than one meaning across the file and has to be read by hand.
A wrong name is worse than hex: hex says "unknown", a wrong name lies.

    python tools/sinhdoi.py <cay-zsu-da-dat-ten>
    python tools/sinhdoi.py <cay-zsu> -f utils/const.rb
"""
from __future__ import annotations

import argparse
import difflib
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import ROOT, PKG, HEX, HEX_ANY, RUBY_KEYWORDS, code_only  # noqa: E402
from datten import baseline_sources                                    # noqa: E402

# @ivar, local, method call, predicate and bang forms all count as one token.
IDENT = re.compile(r"@?[a-z_][A-Za-z0-9_]*[?!]?")

# Files whose ZSU name differs from the KSU one. Empty so far: every twin found
# sits at the same path in both trees.
ALIAS: dict[str, str] = {}

# Names that say only what TYPE a variable holds. ZSU generated these itself,
# from its own evidence, for the identifiers nobody had read yet -- they are a
# guess, not something the author wrote. Carrying one over imports ZSU's guess
# about ZSU's code and states it as fact about this tree, and it can be flatly
# wrong: `_1f153aeb` arrived as `num` and holds "file:///...". tools/dexuat.py
# derives the same kind of name from THIS tree's evidence, per method body, so
# dropping them here loses nothing and removes a way to be wrong.
GENERIC = re.compile(
    r"\A(num|str|arr|flag|h|pt|vec|grp|face|edge|vtx|ents|bb|bbox|tr|key|val|"
    r"res|tmp|obj|item|a|b|c|d|e|i|j|k|n|x|y|z|w|_)\d*\Z")


def tokens_and_skeleton(line: str) -> tuple[list[str], str]:
    """Identifiers in order, plus the line with each one replaced by \x00."""
    toks: list[str] = []

    def take(m: re.Match) -> str:
        toks.append(m.group(0))
        return "\x00"

    return toks, IDENT.sub(take, line)


def read_blanked(path: Path, as_zsu: bool, rel: str | None = None) -> list[str]:
    """Blanked lines. The KSU side comes from the BASELINE, not from disk: once
    names are applied there is no hex left to match and every pair scores 0."""
    if rel is not None:
        src = baseline_sources().get(rel)
        if src is None:
            src = path.read_text(encoding="utf-8", errors="replace")
    else:
        src = path.read_text(encoding="utf-8", errors="replace")
    if as_zsu:
        # The module constant is the one guaranteed difference between the two
        # products. Normalising it is what lets the skeletons line up at all.
        src = re.sub(r"\bZSU\b", "KSU", src)
    return code_only(src).splitlines()


def transfer(hex_path: Path, named_path: Path, rel: str) -> tuple[dict, dict, dict]:
    a_lines = read_blanked(hex_path, as_zsu=False, rel=rel)   # KSU, carries hex
    b_lines = read_blanked(named_path, as_zsu=True)   # ZSU, fully named

    a_parsed = [tokens_and_skeleton(ln) for ln in a_lines]
    b_parsed = [tokens_and_skeleton(ln) for ln in b_lines]
    a_skel = [s for _, s in a_parsed]
    b_skel = [s for _, s in b_parsed]

    votes: dict[str, Counter] = defaultdict(Counter)
    matched_lines = 0

    sm = difflib.SequenceMatcher(None, a_skel, b_skel, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != "equal":
            continue
        for off in range(i2 - i1):
            a_toks = a_parsed[i1 + off][0]
            b_toks = b_parsed[j1 + off][0]
            if len(a_toks) != len(b_toks):
                continue
            # Every non-hex token has to agree, or the pairing is an illusion.
            if any(not HEX.match(a.lstrip("@")) and a != b
                   for a, b in zip(a_toks, b_toks)):
                continue
            matched_lines += 1
            for a, b in zip(a_toks, b_toks):
                bare_a, bare_b = a.lstrip("@"), b.lstrip("@")
                # An @ivar may only take an @ivar's name, and a plain local a
                # plain one: ZSU keeps @ui_scale distinct from ui_scale, and
                # merging the two loses a method definition.
                if HEX.match(bare_a) and a.startswith("@") == b.startswith("@"):
                    votes[bare_a][bare_b] += 1

    # A hex sitting where the twin has `else` is a misalignment, not a name.
    agreed = {h: c.most_common(1)[0][0] for h, c in votes.items()
              if len(c) == 1 and c.most_common(1)[0][0] not in RUBY_KEYWORDS
              and not GENERIC.match(c.most_common(1)[0][0])}
    split = {h: dict(c) for h, c in votes.items() if len(c) > 1}
    return agreed, split, {"lines": matched_lines, "total": len(a_lines)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path, help="ZSU readable tree (the one holding zsu_vn/)")
    ap.add_argument("-f", "--file", action="append", help="limit to these pairs")
    ap.add_argument("-o", "--out", default="sinhdoi.yml")
    ap.add_argument("--min-lines", type=int, default=3,
                    help="ignore a pair that aligns on fewer lines than this")
    args = ap.parse_args()

    zroot = args.src / "zsu_vn"
    if not zroot.is_dir():
        return print(f"khong thay {zroot}") or 1

    ksu_rel = sorted(p.relative_to(ROOT / PKG).as_posix()
                     for p in (ROOT / PKG).rglob("*.rb"))
    wanted = args.file or ksu_rel

    all_agreed: dict[str, str] = {}
    conflicts: dict[str, dict] = {}
    hit = 0

    for rel in wanted:
        hex_path = ROOT / PKG / rel
        named_path = zroot / ALIAS.get(rel, rel)
        if not hex_path.exists() or not named_path.exists():
            continue
        agreed, split, stat = transfer(hex_path, named_path,
                                       f"{PKG}/{rel}")
        if stat["lines"] < args.min_lines:
            continue
        hit += 1
        n_hex = len(set(HEX_ANY.findall(
            baseline_sources().get(f"{PKG}/{rel}", ""))))
        print(f"{rel:<28} khop {stat['lines']:>4}/{stat['total']:<4} dong"
              f"  -> {len(agreed):>3}/{n_hex:<4} hex co ten"
              f"{('  (' + str(len(split)) + ' mau thuan)') if split else ''}")
        for h, name in agreed.items():
            if h in all_agreed and all_agreed[h] != name:
                conflicts.setdefault(h, {})[rel] = name
            else:
                all_agreed[h] = name
        for h, c in split.items():
            conflicts.setdefault(h, {})[rel] = c

    # A hex that disagreed anywhere is not trustworthy anywhere.
    for h in conflicts:
        all_agreed.pop(h, None)

    print(f"\n{hit} cap sinh doi | {len(all_agreed)} hex nhan duoc ten, "
          f"{len(conflicts)} phai doc tay")
    out = ROOT / "tools" / args.out
    lines = ["# Sinh boi tools/sinhdoi.py -- ten chuyen tu ban sinh doi ZSU.",
             "# Moi phieu cho cac ten nay deu nhat tri.",
             "ten:"]
    for h in sorted(all_agreed):
        lines.append(f"  {h}: {all_agreed[h]}")
    if conflicts:
        lines += ["", "# Lech nhau giua cac cho -- phai doc tay, co y de trong.",
                  "mau_thuan:"]
        for h in sorted(conflicts):
            lines.append(f"  {h}:   # {conflicts[h]}")
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"ghi: {out.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
