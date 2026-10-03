#!/usr/bin/env python3
"""Break every remaining scope collision by numbering, per method body.

Two different hex can legitimately carry the same name: the author called both
`umin` in two unrelated places, or a name collides with an identifier the
obfuscator skipped. Before per-scope naming the only answer was to drop the name
and leave hex behind. It no longer is: one hex keeps the real name as its
default, and only the bodies where they actually meet get a number.

The loop: run `datten.py --check`, read each error, add one scope entry, rerun,
until it comes back clean. The hex that occurs less often yields the bare name;
the other keeps it.

It works against the LIVE dictionary -- sinhdoi + tenauto + ten already merged --
so what it resolves is what `datten.py --apply` will actually see.

    python tools/goxungdot.py --dry-run
    python tools/goxungdot.py --apply
    python tools/goxungdot.py --apply --tu-bo    # reclaim the hex listed in `bo:`
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import ROOT, HEX_ANY, ruby_files  # noqa: E402
from datten import load_dicts, method_hexes      # noqa: E402

try:
    import yaml
except ImportError:
    sys.exit("Can PyYAML: pip install pyyaml")

TEN = ROOT / "tools" / "ten.yml"
PV = ROOT / "tools" / "tenpv.yml"
MOT = ROOT / "tools" / "motten.yml"

E_PAIR = re.compile(r"^\s*(\S+\.rb):(\d+) \((\S+)\): (_[0-9a-f]{8}) va "
                    r"(_[0-9a-f]{8}) cung nhan ten (\S+)")
E_SURV = re.compile(r"^\s*(\S+\.rb):(\d+) \((\S+)\): (_[0-9a-f]{8}) -> (\S+) "
                    r"trung dinh danh san co")
E_WIDE = re.compile(r"^\s*(\S+\.rb): (_[0-9a-f]{8}) (_[0-9a-f]{8}) cung nhan "
                    r"ten @?(\S+) trong ca file")


def occurrences() -> Counter:
    c = Counter()
    for p in ruby_files():
        c.update(HEX_ANY.findall(p.read_text(encoding="utf-8", errors="replace")))
    return c


def run_check() -> list[str]:
    out = subprocess.run([sys.executable, "tools/datten.py", "--check"],
                         cwd=ROOT, capture_output=True, text=True,
                         encoding="utf-8")
    return [ln for ln in (out.stdout + out.stderr).splitlines()
            if ln.strip().startswith("ksu_vn/")]


HEADER = """# Sinh boi tools/goxungdot.py -- CHI chua cac muc theo PHAM VI de go
# xung dot. Chay lai se GHI DE. Ten mac dinh cua mot hex nam o ten.yml hoac
# tenauto.yml; o day chi ghi nhung than ham ma hex phai doi sang ten khac vi
# trong do no dung do voi mot hex khac hoac voi mot dinh danh con sot lai.
"""


def write_pv(pv: dict) -> None:
    PV.write_text(HEADER + yaml.safe_dump({"ten": pv}, allow_unicode=True,
                                          sort_keys=True, width=100),
                  encoding="utf-8", newline="")


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--dry-run", action="store_true")
    g.add_argument("--apply", action="store_true")
    ap.add_argument("--tu-bo", action="store_true",
                    help="truoc het lay lai ten that cho cac hex dang nam trong `bo:`")
    args = ap.parse_args()

    ten_backup = TEN.read_text(encoding="utf-8")
    pv_backup = PV.read_text(encoding="utf-8") if PV.exists() else None
    freq = occurrences()
    pv: dict[str, dict] = {}
    DEFS = method_hexes()

    if args.tu_bo:
        # A hex in `bo:` was dropped only because its real name clashed in some
        # scope. Give it the name back as a default here; the loop below pins a
        # different one in whichever bodies actually clash.
        mot = (yaml.safe_load(MOT.read_text(encoding="utf-8")) or {}).get("ten") or {}
        raw = ten_backup
        back = 0
        for h in re.findall(r"^  - (_[0-9a-f]{8})", raw, re.M):
            nm = mot.get(h)
            if isinstance(nm, str) and re.fullmatch(r"[a-z_]\w*[?!]?", nm):
                raw = re.sub(rf"^  - {h}\n", "", raw, flags=re.M)
                pv[h] = {"*": nm}
                back += 1
        TEN.write_text(raw, encoding="utf-8", newline="")
        print(f"lay lai {back} hex tu `bo:`")

    write_pv(pv)
    used = {n for spec in load_dicts().values()
            for n in ([spec] if isinstance(spec, str) else spec.values())}

    def yields(h1: str, h2: str) -> str:
        """Which of two clashing hex gives up the plain name.

        A method name can never be scoped, so if exactly one side is a method
        the other one yields regardless of how often each occurs. Otherwise the
        rarer one yields and the common one keeps the short name.
        """
        if (h1 in DEFS) != (h2 in DEFS):
            return h2 if h1 in DEFS else h1
        return h1 if freq[h1] <= freq[h2] else h2

    def numbered(base: str) -> str:
        i = 2
        while f"{base}{i}" in used:
            i += 1
        used.add(f"{base}{i}")
        return f"{base}{i}"

    def scope_in(h: str, key: str, nm: str) -> bool:
        """Pin hex h to a new name inside one scope, keeping its default.

        Only the scope key is written. The default stays wherever it was, so a
        hand-written entry in ten.yml keeps its comment and its reasoning.
        """
        if h in DEFS:
            # A method name must stay one name tree-wide: scoping it would
            # rename the definition and leave the calls dangling.
            return False
        if key in pv.get(h, {}):
            return False            # already pinned here and still clashing
        pv.setdefault(h, {})[key] = numbered(nm)
        return True

    ok = False
    for round_ in range(1, 41):
        errs = run_check()
        if not errs:
            print(f"vong {round_}: sach")
            ok = True
            break
        fixed = 0
        for ln in errs:
            if (m := E_PAIR.match(ln)):
                rel, _, meth, h1, h2, nm = m.groups()
                h = yields(h1, h2)
                fixed += scope_in(h, f"{rel}#{meth}", nm)
            elif (m := E_SURV.match(ln)):
                rel, _, meth, h, nm = m.groups()
                fixed += scope_in(h, f"{rel}#{meth}", nm)
            elif (m := E_WIDE.match(ln)):
                rel, h1, h2, nm = m.groups()
                h = yields(h1, h2)
                fixed += scope_in(h, rel, nm)
        write_pv(pv)
        print(f"vong {round_}: {len(errs)} loi, sua {fixed}")
        if not fixed:
            print("  con loi khong tu sua duoc -- phai doc tay:")
            for e in errs[:10]:
                print("   ", e.strip())
            break

    if args.dry_run:
        TEN.write_text(ten_backup, encoding="utf-8", newline="")
        if pv_backup is None:
            PV.unlink(missing_ok=True)
        else:
            PV.write_text(pv_backup, encoding="utf-8", newline="")
        print("(dry-run: ten.yml va tenpv.yml giu nguyen)")
    else:
        print(f"da ghi tools/tenpv.yml ({len(pv)} hex)")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
