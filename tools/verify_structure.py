#!/usr/bin/env python3
"""Chung minh mot thay doi CHI doi ten, khong doi cau truc chuong trinh.

Cach lam: che moi dinh danh thuong (bien/ham, ke ca _xxxxxxxx) thanh 'X', giu
nguyen tu khoa Ruby, hang so, chuoi, so va dau. Sau do so voi MOC doi chieu.
Neu con khac mot dong nao la co gi khac ten da bi sua -- phai xem lai.

MOC DOI CHIEU (quan trong -- da doi):
  Truoc day moc la commit baseline (ban bi lam roi), va 0/109 file khac nghia
  la "toan bo viec da lam chi la doi ten". Viec do XONG o tag
  rename-only-complete: 3.542/3.542 dinh danh, khong con hex nao.

  Tu day cay ma doc duoc LA nguon chinh, va se co nhung sua doi hanh vi that.
  Nen moc mac dinh chuyen thanh tag rename-only-complete: script van tra loi
  cau hoi huu ich "lan sua nay co dung chi la doi ten khong", chi khac la no
  khong con tu chung minh lai menh de doi voi ban goc -- menh de do da nam
  trong 32 commit tu baseline-obfuscated den rename-only-complete.

  Muon doi chieu voi ban goc thi chi ro:
      python tools/verify_structure.py baseline-obfuscated

Han che (phai biet): phep che nay khong nhin thay doi ten, ke ca doi ten CO Y
NGHIA nhu ban sua loi KSU.abort -> KSU.abort_op. Sua doi hanh vi phai duyet
bang mat, khong tang nao thay duoc viec do.

    python tools/verify_structure.py [moc]
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

KEYWORDS = {
    "__ENCODING__", "__LINE__", "__FILE__", "BEGIN", "END", "alias", "and",
    "begin", "break", "case", "class", "def", "defined?", "do", "else",
    "elsif", "end", "ensure", "false", "for", "if", "in", "module", "next",
    "nil", "not", "or", "redo", "rescue", "retry", "return", "self", "super",
    "then", "true", "undef", "unless", "until", "when", "while", "yield",
}
IDENT = re.compile(r"\b([a-z_][A-Za-z0-9_]*[?!]?)")


# The decrypted files open with an XSU_NOTICE constant the readable tree drops
# (88 copies of it make Ruby warn about an already initialised constant on every
# load). Removed on both sides, or every single file reads as one line short.
NOTICE = re.compile(r'\AXSU_NOTICE\s*=\s*"(?:[^"\\]|\\.)*"\s*\n')


def mask(src: str) -> str:
    src = NOTICE.sub("", src, count=1)
    return IDENT.sub(lambda m: m.group(1) if m.group(1) in KEYWORDS else "X", src)


DEFAULT_REF = "c45104c"


def resolve(ref: str) -> str:
    return subprocess.run(["git", "rev-parse", "--verify", f"{ref}^{{commit}}"],
                          cwd=ROOT, capture_output=True,
                          text=True).stdout.strip()


def main() -> int:
    ref = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REF
    rev = resolve(ref)
    if not rev:
        # Ban sao chua co tag thi lui ve commit dau tien, va noi ro.
        rev = subprocess.run(["git", "rev-list", "--max-parents=0", "HEAD"],
                             cwd=ROOT, capture_output=True,
                             text=True).stdout.strip()
        if not rev:
            print(f"khong phan giai duoc moc {ref!r}, cung khong co commit dau")
            return 1
        print(f"khong co tag {ref!r} -- lui ve commit dau {rev[:8]}. "
              f"Tao lai bang: git tag {DEFAULT_REF} <sha>")
    print(f"moc doi chieu: {ref} = {rev[:8]}")
    files = [p for p in sorted(ROOT.rglob("*.rb")) if "tools" not in p.parts]
    diff = 0
    for p in files:
        rel = p.relative_to(ROOT).as_posix()
        old = subprocess.run(["git", "show", f"{rev}:{rel}"], cwd=ROOT,
                             capture_output=True, text=True,
                             encoding="utf-8").stdout
        new = p.read_text(encoding="utf-8", errors="replace")
        a, b = mask(old).splitlines(), mask(new).splitlines()
        if a != b:
            diff += 1
            print(f"  KHAC {rel}")
            for i, (x, y) in enumerate(zip(a, b)):
                if x != y:
                    print(f"    dong {i + 1}\n      goc : {x.strip()[:100]}"
                          f"\n      nay : {y.strip()[:100]}")
                    break
            if len(a) != len(b):
                print(f"    so dong: {len(a)} -> {len(b)}")
    print(f"\ndiff cau truc (da che dinh danh): {diff}/{len(files)} file khac moc")
    return 1 if diff else 0


if __name__ == "__main__":
    raise SystemExit(main())
