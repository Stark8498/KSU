#!/usr/bin/env python3
"""Carry names from the readable KSU 2.1.5 tree onto their 2.3.2 hex twins.

2.3.2 is the same product one minor version on: all 88 files of 2.1.5 are still
there, 88% of their lines are unchanged, and 39 files are new. 2.1.5 has been
read out to 3.768 named identifiers, so wherever a 2.3.2 file still matches its
2.1.5 counterpart line for line the names can be carried over mechanically.

This is tools/sinhdoi.py's method pointed at a different source. Two things
differ, and both matter:

  - There is no module constant to normalise. ZSU needed `ZSU` -> `KSU` before
    the skeletons could align; both sides here are already `KSU`.
  - The source is not a foreign product but this tree's own previous version,
    so a carried name is evidence about THIS code, not an analogy to someone
    else's. That is why this dictionary outranks tenauto.yml in datten.py.

The hex itself carries nothing across the version boundary. The obfuscator
re-randomises name -> hex per build: of the hex token pairs that line up
between the two baselines only 27,7 % have the same hex on both sides, so
applying the 2.1.5 dictionary by hex would misname three identifiers in four.
The ALIGNMENT is what survives, and it is all this tool trusts.

How a pair of lines is matched -- the same four rules as the ZSU transfer:

  1. Both sides are blanked of strings and comments (kscommon.code_only), so
     Vietnamese text can never be mistaken for an identifier.
  2. Every identifier is replaced by one marker, leaving a skeleton of
     punctuation, keywords and constants.
  3. difflib aligns the two skeleton line lists. Only 'equal' blocks are used.
  4. Inside an aligned pair the identifier lists must be the same length, and
     every token that is NOT hex on the 2.3.2 side must read identically on the
     2.1.5 side. One mismatched API call means the line only looks aligned, and
     the whole line is dropped.

A hex is proposed only when every vote for it agrees. Disagreement means the
hex carries more than one meaning, and it has to be read by hand.

WHAT A CARRIED NAME CLAIMS is carried too. 2.1.5 kept its names in four
dictionaries that assert different things, and flattening them would state a
type guess as the author's word:

  never obfuscated the author's own identifier, untouched -> emitted under `ten:`
  ten.yml `ten:`   the author typed this                  -> emitted under `ten:`
  sinhdoi.yml      recovered from the ZSU twin            -> emitted under `ten:`
  ten.yml `vai:`   only what the variable HOLDS           -> emitted under `vai:`
  tenauto.yml      a type read off 2.1.5's own evidence   -> DROPPED
  tenpv.yml        a number stuck on to break a clash     -> DROPPED

The last two are dropped rather than carried because tools/dexuat.py and
tools/goxungdot.py regenerate exactly that kind of name from 2.3.2's own
evidence, per method body. Carrying them instead would restate a guess about
2.1.5 as a fact about 2.3.2 -- the mistake §6.7 of HANDOFF-giai-hex.md records
against the ZSU transfer, where `_1f153aeb` arrived as `num` holding a URL.

Which of the six a name falls in is decided BY POSITION, never by the name.
All 85 names 2.1.5 filed under `vai:` are also somebody's `ten:` elsewhere --
`view`, `panel`, `bbox`, `thickness` -- so asking "what does this word claim"
has no answer, and asking it anyway promoted 324 role names to author's words.
Position has an exact answer: tools/datten.py substitutes one identifier for
one identifier, so the 2.1.5 baseline and the 2.1.5 readable tree agree line
for line and token for token (checked: 88/88 files, 84.688 positions, zero
drift). Token i of line j in the readable tree therefore came from whatever
sits at token i of line j in the baseline -- a hex whose dictionary entry is
known, or an identifier the obfuscator never touched.

    python tools/sinhban.py <cay-2.1.5-da-dat-ten>
    python tools/sinhban.py <cay-2.1.5> -f utils/const.rb
"""
from __future__ import annotations

import argparse
import difflib
import subprocess
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import ROOT, PKG, HEX, HEX_ANY, RUBY_KEYWORDS, code_only  # noqa: E402
from datten import baseline_sources                                    # noqa: E402

try:
    import yaml
except ImportError:
    sys.exit("Can PyYAML: pip install pyyaml")

# @ivar, local, method call, predicate and bang forms all count as one token.
IDENT = re.compile(r"@?[a-z_][A-Za-z0-9_]*[?!]?")

# The 2.1.5 dictionaries, as they stood when that tree was finished. They are
# read for one thing only: to tell what a name CLAIMED there. The hex keys in
# them belong to the old build and mean nothing in 2.3.2.
OLD_DICTS = ROOT / "tools" / "v2.1.5"
OLD_BASELINE = "c45104c"
NOTICE = re.compile(r'\AXSU_NOTICE\s*=\s*"(?:[^"\\]|\\.)*"\s*\n')


def old_claims_per_hex() -> dict[str, dict[str, str]]:
    """For each 2.1.5 hex, which claim each name it was ever given carries.

    Keyed by name rather than resolved to one claim per hex on purpose: a hex
    often holds a word in ten.yml and a per-scope type in tenauto.yml at once,
    and only the name actually applied at a given spot says which was used.
    """
    out: dict[str, dict[str, str]] = defaultdict(dict)

    def walk(h: str, spec: object, claim: str) -> None:
        vals = spec.values() if isinstance(spec, dict) else [spec]
        for v in vals:
            if v:
                out[h][str(v).strip()] = claim

    for fname, claim in (("sinhdoi.yml", "ten"), ("tenauto.yml", "doan"),
                         ("ten.yml", "ten"), ("tenpv.yml", "doan")):
        p = OLD_DICTS / fname
        if not p.exists():
            continue
        doc = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
        for h, spec in (doc.get("ten") or {}).items():
            walk(h, spec, claim)
        for h, spec in (doc.get("vai") or {}).items():
            walk(h, spec, "vai")
    return out


def old_source(rel: str) -> str:
    """One file as it stood at the 2.1.5 baseline, notice stripped."""
    out = subprocess.run(["git", "show", f"{OLD_BASELINE}:{rel}"], cwd=ROOT,
                         capture_output=True, text=True, encoding="utf-8",
                         errors="replace")
    return NOTICE.sub("", out.stdout) if out.returncode == 0 else ""


def claim_map(rel: str, named_path: Path) -> dict[tuple[int, int], str]:
    """What the name at each token position of a 2.1.5 file claims.

    Positions are (line, index-within-line) over the blanked source, the same
    basis transfer() counts on. A position the obfuscator never touched holds
    the author's own identifier, which is the strongest claim there is.
    """
    per_hex = old_claims_per_hex()
    base = code_only(old_source(rel)).splitlines()
    named = code_only(named_path.read_text(encoding="utf-8",
                                           errors="replace")).splitlines()
    out: dict[tuple[int, int], str] = {}
    if len(base) != len(named):
        return out                       # file moved on; fall back to no claim
    for ln, (b, n) in enumerate(zip(base, named)):
        bt, nt = IDENT.findall(b), IDENT.findall(n)
        if len(bt) != len(nt):
            continue
        for ix, (bx, nx) in enumerate(zip(bt, nt)):
            bare = bx.lstrip("@")
            if not HEX.match(bare):
                out[(ln, ix)] = "ten"    # never obfuscated: the author's word
            else:
                out[(ln, ix)] = per_hex.get(bare, {}).get(nx.lstrip("@"), "doan")
    return out


# 2.3.2 added an English-named copy of five Vietnamese-named units and kept the
# original beside it, so these pairs sit at different paths and the by-path walk
# would never try them. The content is close enough that the alignment carries
# most of the names; where the rewrite went further, rule 4 drops the line and
# nothing is claimed.
ALIAS: dict[str, str] = {
    "method/toiuu.rb": "method/toiuuvan.rb",
    "method/toiuu/back.rb": "method/toiuuvan/back.rb",
    "method/toiuu/engine.rb": "method/toiuuvan/engine.rb",
    "method/toiuu/postproc.rb": "method/toiuuvan/postproc.rb",
    "method/catcuoi.rb": "method/netcatcuoi.rb",
    "method/catcuoi/lastcut.rb": "method/netcatcuoi/lastcut.rb",
    "method/catcuoi/resize.rb": "method/netcatcuoi/resize.rb",
    "method/thongke/export.rb": "method/thongke/xuat.rb",
    "method/thongke/hardware.rb": "method/thongke/phukien.rb",
    "method/thongke/scan.rb": "method/thongke/quet.rb",
    "method/thongke/summary.rb": "method/thongke/tonghop.rb",
    "method/danhso.rb": "method/danhsovan.rb",
    "utils/normalize.rb": "utils/chuanhoa.rb",
}


def yq(name: str) -> str:
    """A name as YAML, quoted whenever bare YAML would not read it back.

    YAML 1.1 turns a bare `on`, `off`, `yes`, `no`, `y`, `n` and `true` into a
    boolean, so `_0574ff7a: on` loads as Python True and the rail downstream
    rejects it as "not a legal Ruby identifier" -- which is right about the
    value and wrong about the name. `on` is what the author called the switch
    state in utils/preset/field.rb; the dictionary just has to say so in a way
    PyYAML gives back unchanged.
    """
    return name if isinstance(yaml.safe_load(name), str) else f'"{name}"'


def tokens_and_skeleton(line: str) -> tuple[list[str], str]:
    """Identifiers in order, plus the line with each one replaced by \x00."""
    toks: list[str] = []

    def take(m: re.Match) -> str:
        toks.append(m.group(0))
        return "\x00"

    return toks, IDENT.sub(take, line)


def read_blanked(path: Path, rel: str | None = None) -> list[str]:
    """Blanked lines. The 2.3.2 side comes from the BASELINE, not from disk:
    once names are applied there is no hex left to match and every pair scores
    0 without a word of complaint."""
    if rel is not None:
        src = baseline_sources().get(rel)
        if src is None:
            src = path.read_text(encoding="utf-8", errors="replace")
    else:
        src = path.read_text(encoding="utf-8", errors="replace")
    return code_only(src).splitlines()


def transfer(hex_path: Path, named_path: Path, rel: str,
             claims: dict[tuple[int, int], str]) -> tuple[dict, dict, dict, dict]:
    a_lines = read_blanked(hex_path, rel=rel)        # 2.3.2, carries hex
    b_lines = read_blanked(named_path)               # 2.1.5, fully named

    a_parsed = [tokens_and_skeleton(ln) for ln in a_lines]
    b_parsed = [tokens_and_skeleton(ln) for ln in b_lines]
    a_skel = [s for _, s in a_parsed]
    b_skel = [s for _, s in b_parsed]

    votes: dict[str, Counter] = defaultdict(Counter)
    seen: dict[str, set] = defaultdict(set)
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
            for ix, (a, b) in enumerate(zip(a_toks, b_toks)):
                bare_a, bare_b = a.lstrip("@"), b.lstrip("@")
                # An @ivar may only take an @ivar's name, and a plain local a
                # plain one: `@ui_scale` and `ui_scale` are two things, and
                # merging them loses a method definition.
                if HEX.match(bare_a) and a.startswith("@") == b.startswith("@"):
                    # The 2.1.5 side may still hold hex of its own only if that
                    # tree were unfinished; it is not, but guard anyway.
                    if not HEX.match(bare_b):
                        votes[bare_a][bare_b] += 1
                        seen[bare_a].add(claims.get((j1 + off, ix), "doan"))

    # A hex sitting where the twin has `else` is a misalignment, not a name.
    agreed = {h: c.most_common(1)[0][0] for h, c in votes.items()
              if len(c) == 1 and c.most_common(1)[0][0] not in RUBY_KEYWORDS}
    split = {h: dict(c) for h, c in votes.items() if len(c) > 1}
    # Where a name was carried from spots of differing standing, the strongest
    # stands: one genuine sighting of the author's word is not cancelled by a
    # type guess that happened to spell itself the same way.
    rank = {"ten": 3, "vai": 2, "doan": 1}
    claim = {h: max(seen[h], key=lambda c: rank[c]) for h in agreed}
    return agreed, split, claim, {"lines": matched_lines, "total": len(a_lines)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path,
                    help="readable 2.1.5 tree (the one holding ksu_vn/)")
    ap.add_argument("-f", "--file", action="append", help="limit to these pairs")
    ap.add_argument("-o", "--out", default="sinhban.yml")
    ap.add_argument("--min-lines", type=int, default=3,
                    help="ignore a pair that aligns on fewer lines than this")
    args = ap.parse_args()

    oroot = args.src / PKG
    if not oroot.is_dir():
        return print(f"khong thay {oroot}") or 1

    rel_all = sorted(p.relative_to(ROOT / PKG).as_posix()
                     for p in (ROOT / PKG).rglob("*.rb"))
    wanted = args.file or rel_all

    all_agreed: dict[str, str] = {}
    all_claim: dict[str, str] = {}
    conflicts: dict[str, dict] = {}
    hit = 0

    for rel in wanted:
        hex_path = ROOT / PKG / rel
        named_path = oroot / ALIAS.get(rel, rel)
        if not hex_path.exists() or not named_path.exists():
            continue
        claims = claim_map(f"{PKG}/{ALIAS.get(rel, rel)}", named_path)
        agreed, split, claim, stat = transfer(hex_path, named_path,
                                              f"{PKG}/{rel}", claims)
        if stat["lines"] < args.min_lines:
            continue
        hit += 1
        n_hex = len(set(HEX_ANY.findall(
            baseline_sources().get(f"{PKG}/{rel}", ""))))
        print(f"{rel:<34} khop {stat['lines']:>4}/{stat['total']:<4} dong"
              f"  -> {len(agreed):>3}/{n_hex:<4} hex co ten"
              f"{('  (' + str(len(split)) + ' mau thuan)') if split else ''}")
        rank = {"ten": 3, "vai": 2, "doan": 1}
        for h, name in agreed.items():
            if h in all_agreed and all_agreed[h] != name:
                conflicts.setdefault(h, {})[rel] = name
            else:
                all_agreed[h] = name
                if rank[claim[h]] > rank.get(all_claim.get(h, ""), 0):
                    all_claim[h] = claim[h]
        for h, c in split.items():
            conflicts.setdefault(h, {})[rel] = c
        rank[""] = 0

    # A hex that disagreed anywhere is not trustworthy anywhere.
    for h in conflicts:
        all_agreed.pop(h, None)

    # Split by what the name claims, and drop what dexuat.py will say better
    # from this tree's own evidence.
    word = {h: n for h, n in all_agreed.items() if all_claim.get(h) == "ten"}
    role = {h: n for h, n in all_agreed.items() if all_claim.get(h) == "vai"}
    guess = {h: n for h, n in all_agreed.items() if all_claim.get(h) == "doan"}

    print(f"\n{hit} cap sinh ban | {len(all_agreed)} hex nhan duoc ten, "
          f"{len(conflicts)} phai doc tay")
    print(f"  ten tac gia go   {len(word):>5}")
    print(f"  ten theo VAI     {len(role):>5}")
    print(f"  doan kieu -> bo  {len(guess):>5}  (dexuat.py tinh lai)")

    out = ROOT / "tools" / args.out
    lines = ["# Sinh boi tools/sinhban.py -- ten chuyen tu cay KSU 2.1.5.",
             "# Moi phieu cho cac ten nay deu nhat tri.",
             "# `ten:` la chu tac gia go (2.1.5 giu o ten.yml/sinhdoi.yml).",
             "ten:"]
    for h in sorted(word):
        lines.append(f"  {h}: {yq(word[h])}")
    lines += ["",
              "# Chi noi bien GIU cai gi, khong noi tac gia go tu nay.",
              "vai:"]
    for h in sorted(role):
        lines.append(f"  {h}: {yq(role[h])}")
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
