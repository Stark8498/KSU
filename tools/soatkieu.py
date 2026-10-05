#!/usr/bin/env python3
"""Doc nguoc lai tung doan KIEU trong tenauto.yml, xem than ham co chiu khong.

Moi muc theo pham vi cua tenauto.yml khang dinh dung MOT dieu: bien do GIU kieu
gi. Dieu do kiem duoc. O day ten duoc doc nguoc lai bang chinh cac method goi
len bien trong cay DA DAT TEN: neu mot bien ten `pt` bi goi `.normalize!` thi
no la vector, khong phai diem.

Chi method PHAN BIET duoc moi tinh. `.each`, `.name`, `.empty?`, `.reverse`
nam tren nhieu kieu Ruby cung luc nen khong noi len dieu gi -- de chung vao se
bao nham gap nam lan so that.

Phep kiem nay khong thay duoc bien KHONG bi goi method nao, va datten chia
pham vi toi tung THAN HAM, nen mot hex doi vai ngay trong mot than ham thi
khong tach duoc.

    python tools/soatkieu.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import yaml                                                    # noqa: E402
from classify import WEAK                                      # noqa: E402
from datten import body_ranges, load_dicts                     # noqa: E402
from dexuat import SIG, VOCAB                                  # noqa: E402
from kscommon import ROOT, code_only                           # noqa: E402

# Methods that several Ruby core or SketchUp types all answer. SIG files each
# of them under one type only, so without this list every `str.empty?` and
# every `vec.transform` reads as a contradiction.
SHARED = set("""empty? include? find uniq any? all? none? reverse values keys
size length count first last each map select reject to_i to_f to_s to_a sort
sort_by min max sum join flatten compact dup freeze each_with_index group_by
index merge fetch store key? has_key? push pop shift unshift zip take drop
each_pair each_key each_value inject reduce partition find_index transform
transform! reverse! entityID get_attribute set_attribute attribute_dictionaries
typename parent model persistent_id used_by?""".split())
# used_by? sits under vertex in SIG, but Sketchup::Edge answers it too -- it
# asks whether the edge belongs to a given face.


def main() -> int:
    mapping = load_dicts()
    named = {h: (v if isinstance(v, str) else v.get("*", ""))
             for h, v in mapping.items()}
    root_of: dict[str, str] = {}
    for kind, root in VOCAB.items():
        root_of.setdefault(root, kind)
    owner: dict[str, set[str]] = {}
    for kind, meths in SIG.items():
        for m in meths:
            if m not in WEAK and m not in SHARED:
                owner.setdefault(m, set()).add(kind)

    auto = (yaml.safe_load((ROOT / "tools" / "tenauto.yml")
                           .read_text(encoding="utf-8")) or {}).get("ten") or {}
    cache: dict[str, tuple] = {}
    bad, checked = [], 0
    for v in auto.values():
        if not isinstance(v, dict):
            continue
        for scope, name in v.items():
            if "#" not in scope:
                continue
            rel, meth_hex = scope.split("#", 1)
            if not (ROOT / rel).exists():
                continue
            claim = root_of.get(re.sub(r"\d+$", "", str(name)))
            if not claim:
                continue
            if rel not in cache:
                src = (ROOT / rel).read_text(encoding="utf-8", errors="replace")
                cache[rel] = (code_only(src).splitlines(), list(body_ranges(src)))
            lines, rngs = cache[rel]
            got = [r for r in rngs if r[2] == named.get(meth_hex, meth_hex)]
            if not got:
                continue
            a, b, _ = got[0]
            checked += 1
            calls: set[str] = set()
            for ln in lines[a:b + 1]:
                calls |= set(re.findall(
                    r"\b" + re.escape(str(name)) + r"\.([A-Za-z_][A-Za-z0-9_]*[?!]?)", ln))
            for c in sorted(calls):
                if (own := owner.get(c)) and claim not in own:
                    bad.append((scope, name, claim, c, sorted(own)))
                    break

    print(f"soat {checked} muc theo pham vi; mau thuan: {len(bad)}")
    for scope, name, claim, c, own in bad:
        print(f"  {str(name):9} ({claim:6}) goi .{c:<17} "
              f"hop voi {'/'.join(own):12} {scope}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
