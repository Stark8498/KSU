#!/usr/bin/env python3
"""Apply the KSU name dictionaries to the tree, with the safety rails.

Dictionaries, lowest priority first -- a later one overrides an earlier one:

  tools/sinhdoi.yml   carried over from the ZSU twin by tools/sinhdoi.py
  tools/tenauto.yml   a data type read off this tree, by tools/dexuat.py
  tools/sinhban.yml   carried over from KSU 2.1.5 by tools/sinhban.py
  tools/ten.yml       read out by hand; this one wins
  tools/tenpv.yml     per-scope numbering from tools/goxungdot.py

sinhban.yml outranks the two generated dictionaries above it because it carries
the author's own words off the previous version of this same code, while those
two state a type or a counter.

Both hold `hex: name` pairs under a top-level `ten:` key. A blank value means
"not known yet" and is skipped. A hex says "unknown"; a wrong name lies.

Rails, each one here because a rename broke without it:

  - a name must be a legal Ruby identifier and not a keyword. A hex that took
    the name `else` compiles with nothing worse than a warning, and silently
    rewrites the control flow.
  - a name must not collide with an identifier the file already uses. Not every
    identifier was obfuscated, and a surviving local would be merged with the
    renamed hex.
  - two hex must not take the same name in one scope. Locals are checked per
    method body, because the author reuses short names like `pt2` across
    methods; @ivars and method names are checked per file, and `@x` is kept
    distinct from `x` -- merging those loses a method definition.

Substituting hex is safe as text: every hex is exactly 9 characters and none is
a prefix of another, so a word-boundary replacement is one-to-one. Renaming an
ALREADY APPLIED name is not safe that way, because a Ruby word boundary cuts
into Vietnamese letters, so that goes through --retag and never through a
hand-written regex.

    python tools/datten.py --check      # validate the dictionaries only
    python tools/datten.py --dry-run    # report what would change
    python tools/datten.py --apply      # rewrite the files
    python tools/datten.py --retag CU MOI
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import (ROOT, HEX, HEX_ANY, IDENT, RUBY_KEYWORDS,  # noqa: E402
                      code_only, plain_idents, ruby_files)

try:
    import yaml
except ImportError:
    sys.exit("Can PyYAML: pip install pyyaml")

# Lowest priority first. tenpv.yml comes last because it holds nothing but the
# per-scope entries tools/goxungdot.py generates to break a collision, and those
# have to win over whatever gave the colliding name in the first place.
DICTS = ["sinhdoi.yml", "tenauto.yml", "sinhban.yml", "ten.yml",
         "tenpv.yml"]

BASELINE = "e72d0b2"
# Every decrypted file opens with an XSU_NOTICE constant the readable tree
# does not keep.
NOTICE = re.compile(r'\AXSU_NOTICE\s*=\s*"(?:[^"\\]|\\.)*"\s*\n')


def load_dicts(files: list[str] | None = None) -> dict[str, object]:
    """Merge the dictionaries. A later file overrides an earlier one.

    A value is either a plain name, applied everywhere:

        _c2148d5e: x

    or a map from scope to name, for a hex the author reused for different
    things. The obfuscator maps name -> hex across the whole tree, so every
    variable the author called `d` became one hex; a single global name is
    faithful to the original but often says less than the code can support.

        _d14b3aa1:
          "*": rec                                 # fallback
          ksu_vn/utils/font.rb: adv                # whole file
          "ksu_vn/method/xeptam/push.rb#_726c65ba": pt   # one method body

    `vai:` holds the same thing in the same shape, but says less about it. A
    name under `ten:` claims to be the word the author typed, and the audit
    holds those to one name per hex, because the obfuscator mapped name -> hex
    once for the whole tree. A name under `vai:` claims only what the variable
    HOLDS -- `x` for a coordinate, `rec` for a record -- which the code can
    show and the text cannot confirm. Two of those may read alike, so they are
    stored per-scope and the audit passes over them.

        vai:
          _e2947d11: x        # a coordinate here; the author's word is unknown

    `bo:` throws a proposal out instead of replacing it. Since sinhdoi.yml and
    tenauto.yml are generated and get overwritten on every run, a rejection has
    to live in the hand-written file, with its reason beside it.
    """
    out: dict[str, object] = {}
    drop: set[str] = set()
    for name in (files or DICTS):
        p = ROOT / "tools" / name
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        warn_dup_keys(name, text)
        doc = yaml.safe_load(text) or {}
        for h, v in (doc.get("ten") or {}).items():
            if isinstance(v, dict):
                merged = dict(out[h]) if isinstance(out.get(h), dict) else {}
                if isinstance(out.get(h), str):
                    merged["*"] = out[h]
                merged.update({str(k): str(x).strip()
                               for k, x in v.items() if x})
                out[h] = merged
            elif v:                      # blank means "not known yet"
                out[h] = str(v).strip()
        # A role name enters as a scope map so that every reader downstream --
        # the audit above all -- can tell it apart from a recovered word
        # without needing to know which section it came from.
        # A plain role name enters as the `*` fallback and leaves whatever an
        # earlier dictionary scoped per body in place. That is deliberate: the
        # bulk of `vai:` is a tree-wide fallback for the bodies dexuat.py could
        # not type, and letting it replace the per-body names instead would
        # trade `pt`/`grp` for one blunt word everywhere. The cost is that
        # moving a name from `ten:` to `vai:` is NOT output-neutral wherever
        # tenauto.yml has a scope for that hex -- so a name worth keeping stays
        # in `ten:`, and `--soat` reports it as an over-claim instead.
        for h, v in (doc.get("vai") or {}).items():
            if not v:
                continue
            spec = dict(out[h]) if isinstance(out.get(h), dict) else {}
            if isinstance(out.get(h), str):
                spec["*"] = out[h]
            if isinstance(v, dict):
                spec.update({str(k): str(x).strip() for k, x in v.items() if x})
            else:
                spec["*"] = str(v).strip()
            out[h] = spec
        # `bo:` rejects what the EARLIER dictionaries proposed, so it applies at
        # once and only to those. A hex this same file also names has simply
        # been read out since; the name is the newer decision and wins, and the
        # stale `bo:` line is reported so it can be removed.
        named_here = {h for h, v in (doc.get("ten") or {}).items() if v}
        bo_here = set(doc.get("bo") or [])
        for h in sorted(bo_here & named_here):
            print(f"  (ghi chu) {name}: {h} da co ten, dong `- {h}` trong "
                  f"`bo:` thua, go di duoc")
        for h in bo_here - named_here:
            out.pop(h, None)
        drop |= bo_here - named_here
    for h in drop:
        out.pop(h, None)
    return out


def param_names(spec: str) -> list[str]:
    """The names a parameter list BINDS, in order; [] if it is not one.

    Splits on top-level commas and keeps the head of each part, so a default
    value, a splat, a block argument or a keyword colon never counts as a
    binding of its own. A part that is not a bare identifier means the capture
    was never a parameter list, and the whole thing yields nothing.
    """
    parts, depth, cur = [], 0, []
    for ch in spec:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    parts.append("".join(cur))

    out: list[str] = []
    for part in parts:
        head = part.split("=", 1)[0].strip().lstrip("*&").rstrip(":").strip()
        if not head:
            continue                     # a bare `*` or `**` binds nothing
        if not re.fullmatch(r"[A-Za-z_]\w*", head):
            return []                    # not a parameter list after all
        out.append(head)
    return out


def warn_dup_keys(name: str, text: str) -> None:
    """A hex written twice in one file keeps only its LAST entry.

    yaml.safe_load drops the earlier one without a word, so a batch that adds a
    second block for a hex instead of editing the first silently throws the
    first away -- including any per-scope detail in it, which then stops being
    applied while the dictionary still appears to hold it.
    """
    seen: dict[str, int] = {}
    for line in text.splitlines():
        m = re.match(r"^  (_[0-9a-f]{8}):", line)
        if m:
            seen[m.group(1)] = seen.get(m.group(1), 0) + 1
    dup = sorted(h for h, n in seen.items() if n > 1)
    for h in dup:
        print(f"  CANH BAO {name}: {h} co {seen[h]} muc, chi muc CUOI duoc dung"
              f" -- gop lai thanh mot")


def name_for(spec: object, rel: str, method: str | None) -> str | None:
    """The name a hex takes in one place. Most specific scope wins."""
    if isinstance(spec, str):
        return spec
    if method is not None:
        hit = spec.get(f"{rel}#{method}")
        if hit:
            return hit
    return spec.get(rel) or spec.get("*")


def all_names(spec: object) -> set[str]:
    return {spec} if isinstance(spec, str) else set(spec.values())


def body_ranges(src: str):
    """(first_line, last_line, method_name) for every method in the file.

    A Ruby local never escapes its method body, so this is the boundary inside
    which two hex may not share a name.
    """
    lines = src.splitlines()
    starts = [(i, len(m.group(1)), m.group(2))
              for i, line in enumerate(lines)
              if (m := re.match(
                  r"(\s*)def\s+(?:self\.)?([A-Za-z_][A-Za-z0-9_]*[?!=]?)", line))]
    for k, (i, ind, name) in enumerate(starts):
        end = len(lines) - 1
        for j in range(i + 1, len(lines)):
            if re.match(r"\s{%d}end\s*$" % ind, lines[j]):
                end = j
                break
        # Ranges must not overlap. A body whose `end` does not line up -- a
        # one-line def, or an `end` with something after it -- would otherwise
        # run to the bottom of the file and swallow the methods below it, and
        # every scope check downstream would then compare unrelated locals.
        if k + 1 < len(starts) and starts[k + 1][0] <= end:
            end = starts[k + 1][0] - 1
        if end >= i:
            yield i, end, name


_IVAR_HEXES: set[str] | None = None


def ivar_hexes() -> set[str]:
    """Hex written as @hex somewhere, read from the BASELINE."""
    global _IVAR_HEXES
    if _IVAR_HEXES is None:
        _IVAR_HEXES = set()
        for src in baseline_sources().values():
            _IVAR_HEXES |= set(re.findall(r"@(_[0-9a-f]{8})", code_only(src)))
    return _IVAR_HEXES


_LOCAL_HEXES: set[str] | None = None


def local_hexes() -> set[str]:
    """Hex that is a local or a parameter somewhere, read from the BASELINE.

    Same reason as ivar_hexes(), one step wider. `?` and `!` are legal only in
    a method name, and the obfuscator maps one author word to one hex across
    the whole tree, so a word used for both a predicate method and a variable
    cannot keep its `?`. Checking only `@ivar` missed exactly that: Clip's
    `elements_match?(...)` is the same hex as a plain local in rescue.rb, and
    `elements_match? = arr[:refit_check]` is a SyntaxError that nothing caught
    until ruby -c ran over the written file.
    """
    global _LOCAL_HEXES
    if _LOCAL_HEXES is None:
        _LOCAL_HEXES = set()
        # `h = ...` and `a, h = ...`, but never `==`, `!=`, `<=`, `>=`, `=>`.
        assign = re.compile(r"(?<![=!<>])\b(_[0-9a-f]{8})\s*(?:,[^=\n]*?)?=(?!=|~)")
        for src in baseline_sources().values():
            code = code_only(src)
            _LOCAL_HEXES |= set(assign.findall(code))
            for params in re.findall(r"\bdef\s+\S+\s*\(([^)]*)\)|\|([^|\n]*)\|",
                                     code):
                _LOCAL_HEXES |= {t for t in param_names(params[0] or params[1]
                                                        or "")
                                 if HEX.match(t)}
    return _LOCAL_HEXES


_METHOD_HEXES: set[str] | None = None


def method_hexes() -> set[str]:
    """Hex that `def` somewhere, read from the BASELINE.

    It has to come from the baseline: once a name is applied the hex is gone
    from the working tree, so scanning what is on disk would report an empty
    set and the rule it feeds would quietly stop guarding anything.
    """
    global _METHOD_HEXES
    if _METHOD_HEXES is None:
        blob = subprocess.run(["git", "grep", "-h", "-E",
                               r"^\s*def\s+(self\.)?_[0-9a-f]{8}",
                               BASELINE, "--", "ksu_vn"],
                              cwd=ROOT, capture_output=True, text=True,
                              encoding="utf-8").stdout
        _METHOD_HEXES = set(re.findall(
            r"^\s*def\s+(?:self\.)?(_[0-9a-f]{8})", blob, re.M))
    return _METHOD_HEXES


_BASE_SRC: dict[str, str] | None = None


def baseline_sources() -> dict[str, str]:
    """Every file as it stands at the baseline, notice stripped.

    Checking has to read this, not the working tree. The dictionary maps
    baseline hex to names, so once names are applied the hexes are gone from
    disk and every scope check would silently find nothing to complain about.
    """
    global _BASE_SRC
    if _BASE_SRC is None:
        _BASE_SRC = {}
        for p in ruby_files():
            rel = p.relative_to(ROOT).as_posix()
            out = subprocess.run(["git", "show", f"{BASELINE}:{rel}"], cwd=ROOT,
                                 capture_output=True)
            if out.returncode == 0:
                src = out.stdout.decode("utf-8").replace("\r\n", "\n")
                _BASE_SRC[rel] = NOTICE.sub("", src, count=1)
    return _BASE_SRC


def validate(mapping: dict[str, object]) -> list[str]:
    errs: list[str] = []
    defs = method_hexes()
    for h, spec in sorted(mapping.items()):
        if not HEX.match(h):
            errs.append(f"{h}: khoa khong phai hex")
            continue
        names = all_names(spec)
        # A method name cannot be scoped at all. The definition lives in one
        # file and the calls in others, so any per-scope entry renames one end
        # and leaves the other pointing at a method that no longer exists --
        # whether it renames the definition (calls dangle) or only a call site
        # (that call dangles). It must be one name, everywhere.
        if h in defs and isinstance(spec, dict) and set(spec) != {"*"}:
            errs.append(f"{h}: la ten METHOD nen phai mot ten cho ca cay, "
                        f"dang dat theo pham vi ({' '.join(sorted(spec))})")
        for nm in sorted(names):
            if not IDENT.match(nm):
                errs.append(f"{h} -> {nm}: khong phai dinh danh Ruby hop le")
            elif nm in RUBY_KEYWORDS:
                errs.append(f"{h} -> {nm}: trung tu khoa Ruby")
            # `?` and `!` are legal in a method name but not in a variable one.
            # A hex is often BOTH -- `def _x; @_x; end` -- and then the reader
            # `_x` wants `labelling?` while the field `@_x` cannot take it:
            # `@labelling? = false` is a SyntaxError, which only ruby -c sees.
            elif nm[-1] in "?!" and h in ivar_hexes():
                errs.append(f"{h} -> {nm}: hex nay con la @ivar, ten khong "
                            f"duoc co '{nm[-1]}' o cuoi")
            elif nm[-1] in "?!" and h in local_hexes():
                errs.append(f"{h} -> {nm}: hex nay con la bien cuc bo / tham "
                            f"so, ten khong duoc co '{nm[-1]}' o cuoi")

    for rel, src in sorted(baseline_sources().items()):
        here = set(HEX_ANY.findall(src)) & set(mapping)
        if not here:
            continue

        code = code_only(src)
        code_lines = code.splitlines()
        bodies = list(body_ranges(code))

        # Collision with a name the file already carries. The obfuscator left
        # some identifiers alone -- it skips the ones that collide with a Ruby
        # or SketchUp API name -- and renaming a hex onto a surviving one would
        # merge two different things. Only a shared SCOPE merges them, though:
        # `view` as a parameter of one method and `_c0b8bb8d` inside another
        # are the same original name, not a conflict.
        survivors = {i for i in plain_idents(src) if not HEX.match(i)}
        for h in sorted(here):
            hex_at = re.compile(r"\b" + h + r"\b")
            # An @ivar never collides with a local of the same spelling:
            # `@on_done = on_done` is how the original reads, one being the
            # keyword parameter and the other the field it is stored in.
            if re.search(r"@" + h + r"\b", code):
                continue
            for lo, hi, mname in bodies:
                nm = name_for(mapping[h], rel, mname)
                if nm is None or nm not in survivors:
                    continue
                body = "\n".join(code_lines[lo:hi + 1])
                nm_at = re.compile(r"(?<![\w@$.:])" + re.escape(nm) + r"(?![\w?!:])")
                if hex_at.search(body) and nm_at.search(body):
                    errs.append(f"{rel}:{lo + 1} ({mname}): {h} -> {nm} "
                                f"trung dinh danh san co trong cung than ham")
                    break

        # A hex that appears TWICE in one parameter list must keep a leading
        # underscore. Ruby allows a duplicated block or method parameter only
        # when its name starts with '_', and every hex does -- so the obfuscated
        # source compiles while `|part, part, b|` does not. The author wrote
        # `{ |_x, _x, _y| ... }` meaning "ignore the first two"; dropping the
        # underscore turns a legal file into a SyntaxError, and only ruby -c
        # catches it, after the fact.
        # Only a name in PARAMETER POSITION counts. Both patterns below match
        # more than parameter lists -- `|` pairs up with the nearest `|`, which
        # on `a || b` or a ternary is not a block at all, and `([^)]*)` runs on
        # into a default value -- so the capture is parsed before it is judged.
        # Counting raw hex instead reported two lists that were legal Ruby:
        # `(stream, len = "...#{stream.bytesize}")`, where the repeat is a
        # default value reading an earlier parameter, and a stretch of ternary
        # between two `|` operators holding @ivars, which cannot be parameters.
        for params in re.findall(r"\bdef\s+\S+\s*\(([^)]*)\)|\|([^|\n]*)\|", code):
            toks = param_names(params[0] or params[1] or "")
            for h in {t for t in toks if toks.count(t) > 1} & here:
                for nm in sorted(all_names(mapping[h])):
                    if not nm.startswith("_"):
                        errs.append(f"{rel}: {h} -> {nm} lap lai trong cung mot "
                                    f"danh sach tham so, ten phai bat dau bang '_'")

        # @ivars and method names live for the whole file, so they cannot be
        # scoped per body -- only the file-level name counts here.
        wide: dict[str, list[str]] = defaultdict(list)
        for h in sorted(here):
            at = bool(re.search(r"@" + h + r"\b", code))
            isdef = bool(re.search(r"^\s*def\s+(?:self\.)?" + h + r"\b", code, re.M))
            if at or isdef:
                nm = name_for(mapping[h], rel, None)
                if nm:
                    wide[("@" if at else "") + nm].append(h)
        for nm, hs in sorted(wide.items()):
            if len(hs) > 1:
                errs.append(f"{rel}: {' '.join(hs)} cung nhan ten {nm} trong ca file")

        # Locals: one method body at a time -- short names get reused.
        for lo, hi, mname in bodies:
            body = "\n".join(code_lines[lo:hi + 1])
            seen: dict[str, str] = {}
            for h in sorted(set(HEX_ANY.findall(body)) & here):
                if re.search(r"@" + h + r"\b", body):
                    continue
                nm = name_for(mapping[h], rel, mname)
                if nm is None:
                    continue
                if nm in seen and seen[nm] != h:
                    errs.append(f"{rel}:{lo + 1} ({mname}): {seen[nm]} va {h} "
                                f"cung nhan ten {nm}")
                seen[nm] = h

    errs += same_module_clashes(mapping)
    return errs


def same_module_clashes(mapping: dict[str, object]) -> list[str]:
    """Two hexes DEFINED in one module must not take the same name.

    Ruby reopens a module across files, so `module KSU::Back` in toiuu/back.rb
    and in toiuuvan/back.rb is ONE module. Two `def`s with one name there is
    not a clash the parser reports: the second silently replaces the first and
    a method disappears.

    This is the only rail here that can delete behaviour rather than break the
    build, and it is the one no other check sees -- `ruby -c` is happy,
    verify_structure only masks identifiers so the shapes still match, and
    verify_graph resolves the call because the NAME still exists. 2.3.2 ships
    the superseded Vietnamese-named units beside their English rewrites and
    both halves reopen the same module, so carrying one 2.1.5 name onto both
    sides collapsed 160 pairs of distinct methods into 160 single ones.

    The per-body rail above cannot see it: these two `def`s are in different
    files, and nothing smaller than the module is the right scope to check.
    """
    ns_re = re.compile(r"^(\s*)(?:module|class)\s+([A-Za-z0-9_:]+)")
    def_re = re.compile(r"^(\s*)def\s+(self\.)?(_[0-9a-f]{8})")
    seen: dict[tuple, set] = defaultdict(set)
    for rel, src in sorted(baseline_sources().items()):
        stack: list[tuple[int, str]] = []
        for line in code_only(src).splitlines():
            m = ns_re.match(line)
            if m:
                indent = len(m.group(1))
                while stack and stack[-1][0] >= indent:
                    stack.pop()
                stack.append((indent, m.group(2)))
                continue
            d = def_re.match(line)
            if not d:
                continue
            spec = mapping.get(d.group(3))
            nm = None if spec is None else name_for(spec, rel, None)
            if nm is None:
                continue
            ns = "::".join(n for _, n in stack) or "(top)"
            seen[(ns, bool(d.group(2)), nm)].add((d.group(3), rel))

    out = []
    for (ns, is_self, nm), hits in sorted(seen.items()):
        if len({h for h, _ in hits}) < 2:
            continue
        where = ", ".join(f"{h} o {f}" for h, f in sorted(hits))
        out.append(f"{ns}.{'self.' if is_self else ''}{nm}: hai def trong cung "
                   f"mot module cung nhan ten nay -- {where}")
    return out


def apply(mapping: dict[str, object], dry_run: bool) -> tuple[int, int]:
    """Rewrite the tree. Substitution is per LINE, because the name a hex takes
    can depend on which method body the line falls in."""
    if not mapping:
        return 0, 0
    pattern = re.compile(r"\b(" + "|".join(sorted(mapping)) + r")\b")
    total = touched = 0
    for p in ruby_files():
        rel = p.relative_to(ROOT).as_posix()
        src = p.read_text(encoding="utf-8")
        scoped = any(isinstance(mapping[h], dict)
                     for h in set(HEX_ANY.findall(src)) & set(mapping))

        if not scoped:
            new, n = pattern.subn(
                lambda m: name_for(mapping[m.group(1)], rel, None) or m.group(1),
                src)
        else:
            # Which body each line sits in. Bodies are listed outermost first,
            # so a later (inner) range overwrites an earlier one and the
            # innermost method wins, which is the one that binds the local.
            owner: dict[int, str] = {}
            for lo, hi, mname in body_ranges(code_only(src)):
                for i in range(lo, hi + 1):
                    owner[i] = mname
            out, n = [], 0
            for i, line in enumerate(src.splitlines(keepends=True)):
                def sub(m: re.Match, _i=i) -> str:
                    nonlocal n
                    nm = name_for(mapping[m.group(1)], rel, owner.get(_i))
                    if nm is None:
                        return m.group(1)
                    n += 1
                    return nm
                out.append(pattern.sub(sub, line))
            new = "".join(out)

        if n:
            total += n
            touched += 1
            if not dry_run:
                p.write_text(new, encoding="utf-8", newline="")
    return total, touched


def retag(old: str, new: str) -> int:
    """Rename an already-applied name. Text is masked before matching.

    A Ruby word boundary is [A-Za-z0-9_]; Vietnamese vowels fall outside it, so
    in "Khong co nhom" the 'c' of 'co' reads as a whole identifier and a naive
    substitution corrupts the caption. Matching against the blanked copy and
    splicing back by offset is what keeps the strings intact.
    """
    if not IDENT.match(new) or new in RUBY_KEYWORDS:
        sys.exit(f"{new}: khong phai ten hop le")
    pat = re.compile(r"(?<![\w@$.:])" + re.escape(old) + r"(?![\w?!:])")
    total = 0
    for p in ruby_files():
        src = p.read_text(encoding="utf-8")
        spans = [m.span() for m in pat.finditer(code_only(src))]
        if not spans:
            continue
        out, at = [], 0
        for a, b in spans:
            out.append(src[at:a])
            out.append(new)
            at = b
        out.append(src[at:])
        total += len(spans)
        print(f"  {p.relative_to(ROOT).as_posix()}: {len(spans)}")
        p.write_text("".join(out), encoding="utf-8", newline="")
    return total


def restore() -> int:
    """Put every .rb file back to the obfuscated baseline, notice stripped.

    Why this exists: once a name is applied the hex is gone, so a name that
    turns out wrong cannot simply be renamed -- `num2` was handed to four
    different hexes, and --retag would hit all four. Rebuilding from the
    baseline makes the dictionaries the single source of truth, so correcting
    an entry there and applying again is always enough.
    """
    n = 0
    for p in ruby_files():
        rel = p.relative_to(ROOT).as_posix()
        out = subprocess.run(["git", "show", f"{BASELINE}:{rel}"], cwd=ROOT,
                             capture_output=True)
        if out.returncode != 0:
            continue
        src = out.stdout.decode("utf-8").replace("\r\n", "\n")
        p.write_text(NOTICE.sub("", src, count=1), encoding="utf-8", newline="")
        n += 1
    return n


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--check", action="store_true")
    g.add_argument("--dry-run", action="store_true")
    g.add_argument("--apply", action="store_true")
    g.add_argument("--lam-lai", action="store_true",
                   help="dung lai tu moc roi ap ca tu dien (tu dien la nguon duy nhat)")
    g.add_argument("--retag", nargs=2, metavar=("CU", "MOI"))
    args = ap.parse_args()

    if args.retag:
        print(f"doi {retag(*args.retag)} cho")
        return 0

    if args.lam_lai:
        print(f"dung lai {restore()} file tu moc {BASELINE}, da go XSU_NOTICE")
        args.apply = True

    mapping = load_dicts()
    print(f"tu dien: {len(mapping)} ten")
    errs = validate(mapping)
    if errs:
        print(f"\n{len(errs)} loi:")
        for e in errs[:60]:
            print("  " + e)
        if len(errs) > 60:
            print(f"  ... con {len(errs) - 60}")
        return 1
    print("kiem tra: OK")
    if args.check:
        return 0
    total, touched = apply(mapping, dry_run=args.dry_run)
    print(f"{'se doi' if args.dry_run else 'da doi'} {total} luot tren {touched} file")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
