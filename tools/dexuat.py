#!/usr/bin/env python3
"""Propose a name for every remaining local and @ivar, from TYPE evidence.

Why this is not guessing: a name produced here asserts exactly one thing --
what kind of object the variable holds -- and that is read off the set of
methods actually called on it. `pt` is claimed only where something calls
`.offset`/`.distance`/`.x`, `ents` only where something calls `.add_face`.
A hex with no usable evidence is left alone.

Why it has to work per SCOPE, not per hex: the obfuscator maps name -> hex
across the whole tree, so every variable the author called `d` became the same
hex. `_d14b3aa1` appears 542 times in 48 files holding a hash here, a point
there and a string somewhere else. One global name would be faithful to the
original but would lie about 48 different things, so each method body gets the
name its own evidence supports, and tools/datten.py applies it per body.

Collisions inside a scope are resolved by numbering, in order of how often each
hex occurs, after excluding the identifiers the obfuscator left alone -- a
proposal never takes a name the body already uses for something else.

    python tools/dexuat.py                 # xem de xuat
    python tools/dexuat.py --write         # ghi tools/tenauto.yml
    python tools/dexuat.py --chac 0.55     # nguong do chac toi thieu
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import (ROOT, HEX, HEX_ANY, RUBY_KEYWORDS, code_only,  # noqa: E402
                      plain_idents, ruby_files)
from classify import SIG, WEAK                                       # noqa: E402
from datten import (body_ranges, load_dicts, name_for, baseline_sources,  # noqa: E402
                    all_names as all_names_of)

try:
    import yaml
except ImportError:
    sys.exit("Can PyYAML: pip install pyyaml")

# One short root per type. Numbering handles reuse inside a scope.
VOCAB = {
    "point": "pt", "vector": "vec", "group": "grp", "face": "face",
    "edge": "edge", "vertex": "vtx", "ents": "ents", "array": "arr",
    "hash": "h", "num": "num", "str": "str", "tf": "tr", "bbox": "bb",
    "bool": "flag", "material": "mat", "model": "model",
}

# Types classify.py does not carry but that this tree is full of.
SIG = dict(SIG)
SIG["material"] = "texture alpha colorize_type materials".split()
SIG["model"] = ("active_entities start_operation commit_operation selection "
                "active_view definitions layers pages rendering_options "
                "active_path close_active").split()

# Constructors and calls that settle the type on their own, read off the
# right-hand side. Stronger than the method set: `Geom::Point3d.new` is a point
# whatever is called on it afterwards.
RHS = [
    (re.compile(r"\.materials\b|Sketchup::Color|add_material"), "material"),
    (re.compile(r"Sketchup\.active_model\b"), "model"),
    (re.compile(r"Geom::Point3d\.new|\.position\b|screen_coords|\.origin\b"), "point"),
    (re.compile(r"Geom::Vector3d\.new|\.normal\b|vector_to"), "vector"),
    (re.compile(r"Geom::Transformation|\.transformation\b"), "tf"),
    (re.compile(r"Geom::BoundingBox|\.bounds\b|local_bounds"), "bbox"),
    (re.compile(r"\.entities\b|active_entities"), "ents"),
    (re.compile(r"\bdefinition\b"), "group"),
    (re.compile(r"^\s*\[\s*\]|\.map\b|\.select\b|\.reject\b|\.sort_by\b|"
                r"\.flat_map\b|\.to_a\b|\.keys\b|\.values\b|\.grep\b"), "array"),
    (re.compile(r"^\s*\{\s*\}|\.group_by\b|\.tally\b|Hash\.new"), "hash"),
    (re.compile(r'^\s*(?:"|\'|%[qQ])|\.to_s\b|\.join\b|\.strip\b'), "str"),
    (re.compile(r"^\s*-?\d|\.to_f\b|\.to_i\b|\.round\b|\.abs\b|\.size\b|"
                r"\.length\b|\.count\b|\.sum\b"), "num"),
    (re.compile(r"^\s*(?:true|false)\b|\?|\.nil\?|\.empty\?|\.any\?|\.all\?"), "bool"),
]

CALL = re.compile(r"@?(_[0-9a-f]{8})\.([a-zA-Z_][\w?!]*)")
INDEX = re.compile(r"@?(_[0-9a-f]{8})\s*\[")
ASSIGN = re.compile(r"(_[0-9a-f]{8})\s*(?:\|\|)?=\s*([^=\n].*)$")
BLOCK = re.compile(r"\|([^|\n]*)\|")


def evidence(text: str) -> dict[str, Counter]:
    """Per-hex type scores gathered from one stretch of code."""
    out: dict[str, Counter] = defaultdict(Counter)
    for h, meth in CALL.findall(text):
        w = 0.3 if meth in WEAK else 1.0
        for kind, sig in SIG.items():
            if meth in sig:
                out[h][kind] += w
    for h in INDEX.findall(text):
        out[h]["array"] += 0.5
        out[h]["hash"] += 0.5
    for line in text.splitlines():
        m = ASSIGN.search(line)
        if not m:
            continue
        for rx, kind in RHS:
            if rx.search(m.group(2)):
                out[m.group(1)][kind] += 1.5
                break
    return out


def best(scores: Counter, chac: float) -> str | None:
    if not scores:
        return None
    kind, top = scores.most_common(1)[0]
    if top / sum(scores.values()) < chac:
        return None
    return VOCAB.get(kind)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--force", action="store_true",
                    help="ghi de du ban moi it hex hon ban dang co")
    ap.add_argument("--chac", type=float, default=0.5,
                    help="ty le diem toi thieu cua kieu thang (mac dinh 0.5)")
    args = ap.parse_args()

    # tenauto.yml is this tool's own output. Reading it back as "already
    # done" would make a rerun propose almost nothing, so it is left out and
    # regenerated whole each time.
    mapping = load_dicts(["sinhdoi.yml", "ten.yml"])
    done = set(mapping)
    proposals: dict[str, dict[str, str]] = defaultdict(dict)
    n_scope = n_name = 0

    # A hex that is a method name or an @ivar ANYWHERE needs one name for the
    # whole tree. A method name is called from other files, and an @ivar
    # belongs to a class that several files reopen -- naming either per body
    # would split one thing into several, or merge two into one.
    # Read the BASELINE, not the working tree: once names are applied the hex
    # is gone from disk and there is nothing left to propose a name for.
    sources = baseline_sources()
    whole_tree: dict[str, str] = {}      # hex -> kind
    for src in sources.values():
        c = code_only(src)
        for h in re.findall(r"@(_[0-9a-f]{8})", c):
            whole_tree[h] = "ivar"
        for h in re.findall(r"^\s*def\s+(?:self\.)?(_[0-9a-f]{8})", c, re.M):
            whole_tree[h] = "method"

    # Names already spoken for anywhere, so a global proposal cannot clash with
    # one. Locals are checked per scope later and do not belong here.
    reserved_tree = set()
    for src in sources.values():
        c = code_only(src)
        reserved_tree |= set(re.findall(r"^\s*def\s+(?:self\.)?(\w+)", c, re.M))
        reserved_tree |= set(re.findall(r"@(\w+)", c))
    reserved_tree = {r for r in reserved_tree if not HEX.match(r)}
    for h, spec in mapping.items():
        reserved_tree |= all_names_of(spec)

    # --- @ivars, one global name each ---
    tree_ev: dict[str, Counter] = defaultdict(Counter)
    for src in sources.values():
        for h, sc in evidence(code_only(src)).items():
            tree_ev[h].update(sc)
    for h in sorted(k for k, v in whole_tree.items() if v == "ivar"):
        if h in done:
            continue
        root = best(tree_ev.get(h, Counter()), args.chac)
        if not root:
            continue
        nm = uniq(root, reserved_tree)
        reserved_tree.add(nm)
        proposals[h]["*"] = nm
        n_name += 1

    for rel, src in sorted(sources.items()):
        code = code_only(src)
        if not HEX_ANY.search(code):
            continue
        lines = code.splitlines()
        survivors = {i for i in plain_idents(src) if not HEX.match(i)}
        file_ev = evidence(code)
        bodies = list(body_ranges(code))

        # Names a method or @ivar already holds in this file are off limits for
        # a local: Ruby would resolve the bare word to the local and silently
        # stop calling the method.
        reserved = set(re.findall(r"^\s*def\s+(?:self\.)?(\w+)", code, re.M))
        reserved |= set(re.findall(r"@(\w+)", code))

        # --- locals: one scope per method body ---
        for lo, hi, mname in bodies:
            body = "\n".join(lines[lo:hi + 1])
            here = set(HEX_ANY.findall(body)) - done - set(whole_tree)
            if not here:
                continue
            n_scope += 1
            body_ev = evidence(body)
            # Inside a scope the busiest hex gets the unnumbered name.
            order = sorted(here, key=lambda h: -len(re.findall(r"\b" + h + r"\b", body)))
            taken = set(re.findall(r"(?<![\w@$.:])([a-z_]\w*)(?![\w?!:])", body))
            taken = {t for t in taken if not HEX.match(t)} | reserved
            # A hex the dictionary already covers still occupies its name in
            # this body. Without this the proposer hands the same name to a
            # second hex and the two get merged.
            for h in set(HEX_ANY.findall(body)) & done:
                nm = name_for(mapping[h], rel, mname)
                if nm:
                    taken.add(nm)
            # An @ivar named a moment ago holds its name everywhere, and in a
            # body like this one it can appear as a bare local too -- the same
            # hex is an @ivar in one file and a plain variable in another. Key
            # off the hex, not off the leading '@'.
            for h in set(HEX_ANY.findall(body)) & set(proposals):
                if "*" in proposals[h]:
                    taken.add(proposals[h]["*"])
            for h in order:
                sc = body_ev.get(h) or Counter()
                # Only this body's own evidence counts. Borrowing the file's
                # evidence looked like free coverage but states one method's
                # type as fact about another: `_9a5525a8` is an Array in one
                # method here and a Sketchup::Material in the next, and the
                # fallback called the material `arr`.
                root = best(sc, args.chac)
                if not root:
                    continue
                nm = uniq(root, taken | survivors)
                taken.add(nm)
                proposals[h][f"{rel}#{mname}"] = nm
                n_name += 1

    # Scoped entries stay scoped. Collapsing a hex that happened to get one
    # name everywhere into a global entry looks tidier but is wrong: the global
    # then also applies in bodies the proposer never looked at, where another
    # hex may already hold that name. Correctness over a shorter file.
    flat: dict[str, object] = {}
    for h, by_scope in proposals.items():
        flat[h] = by_scope["*"] if "*" in by_scope else dict(by_scope)

    glob = sum(1 for v in flat.values() if isinstance(v, str))
    print(f"{len(flat)} hex nhan de xuat ({glob} toan cuc, {len(flat) - glob} "
          f"theo pham vi) tren {n_scope} pham vi, {n_name} cho dat ten")
    rest = set(h for src in sources.values() for h in HEX_ANY.findall(src))
    print(f"con lai khong du bang chung: {len(rest - done - set(flat))}")

    if args.write:
        out = ROOT / "tools" / "tenauto.yml"
        # Evidence is read off the tree as it stands, and the tree no longer
        # stands as it did: every name already applied has replaced the hex the
        # scan looks for, so a second run sees less than the first and writes a
        # SMALLER file over the bigger one. Rerunning this against a tree that
        # has been named drops proposals wholesale -- it is not idempotent, and
        # the only safe input is the all-hex baseline.
        if out.exists():
            had = len(re.findall(r"^  _[0-9a-f]{8}:", out.read_text(
                encoding="utf-8"), re.M))
            if len(flat) < had and not args.force:
                print(f"TU CHOI GHI: file dang co {had} hex, ban moi chi co "
                      f"{len(flat)}.\nChay lai tren cay DA DAT TEN thi bang "
                      f"chung mat dan -- dung `git stash` ve moc hex truoc,\n"
                      f"hoac --force neu that su muon ghi de.")
                return 1
        buf = ["# Sinh boi tools/dexuat.py -- ten theo KIEU DU LIEU, suy tu tap",
               "# method goi len tung hex trong tung pham vi. Chay lai se GHI DE:",
               "# muon sua mot ten thi dat lai o ten.yml, dung sua o day.",
               "ten:"]
        for h in sorted(flat):
            v = flat[h]
            if isinstance(v, str):
                buf.append(f"  {h}: {v}")
            else:
                buf.append(f"  {h}:")
                for k in sorted(v):
                    buf.append(f'    "{k}": {v[k]}')
        out.write_text("\n".join(buf) + "\n", encoding="utf-8", newline="")
        print(f"ghi: tools/tenauto.yml")
    return 0


def uniq(root: str, taken: set[str]) -> str:
    if root not in taken and root not in RUBY_KEYWORDS:
        return root
    i = 2
    while f"{root}{i}" in taken:
        i += 1
    return f"{root}{i}"


if __name__ == "__main__":
    raise SystemExit(main())
