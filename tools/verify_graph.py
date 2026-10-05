#!/usr/bin/env python3
"""Tang xac minh thu 2: DO THI TU DONG.

Moi loi goi dang `KSU::Namespace.method` trong cay ma phai phan gia duoc ve mot
`def` co that trong chinh cay ma. Neu mot lan doi ten lam lech ten method o cho
DINH NGHIA ma khong lech o cho GOI (hoac nguoc lai), loi goi do thanh "treo" va
script nay bat duoc -- day la thu ma diff cau truc (verify_structure.py) KHONG
thay, vi che dinh danh thi ca hai dau deu thanh 'X'.

Ngoai le hop le, khong tinh la treo:
  - KSU::Clibs va KSU::Clipper: kernel hinh hoc native trong ksu.so, khong co
    ma nguon Ruby.
  - method Ruby / SketchUp dung san goi len namespace (vi du Module#name).

    python tools/verify_graph.py            # phai in "0 loi goi treo"
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kscommon as R
from kscommon import code_only                                          # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
GRAPH = ROOT / "tools" / "graph.json"

# Methods that live in the compiled kernel, not in the Ruby tree. clibs.rb
# loads ksu.so and the library defines them straight onto these modules, so
# there is no `def` to resolve to and the graph cannot see them. Their names
# survived the obfuscator intact -- a C extension binds its methods by name --
# which makes them some of the few ORIGINAL names the tree still carries.
NATIVE_METHODS = {
    "convex_hull",        # utils/geom.rb
    "polygons_overlap?",  # utils/nesting/bilan.rb, method/xeptam/collide.rb
    "pack_bl",            # utils/nesting.rb, utils/nesting/pack.rb -- bottom-left packing
    "nfp",                # no-fit polygon; utils/nesting/corner.rb, method/xeptam/nfp.rb
    "nfp_snap",           # method/xeptam/collide.rb
    "inflate",            # method/xeptam/nfp.rb -- polygon offset
    "contact_refine",     # method/xeptam/collide.rb
    "build_loops",        # utils/cutting/loop.rb
    # KSU::Cnc::Native -- the CNC half of ksu.so, new in 2.3.2. Declared by
    # name on the C side, so these names were never obfuscated and there is no
    # `def` to resolve them to. Every one is called behind a `Calc::NATIVE` or
    # `Calc::NATIVE_EXT` guard with a Ruby fallback beside it.
    "boundary_error",     # method/giacong/calc.rb -- probes whether ksu.so has the CNC half
    "clear_loop",         # method/giacong/profile.rb
    "contour_distance",   # method/giacong/calc.rb
    "crossings",          # method/giacong/topology.rb
    "dedupe_loop",        # method/giacong/calc.rb
    "detect_arc",         # method/giacong/geom.rb
    "gap_clear",          # method/giacong/rescue.rb
    "gouge_scan",         # method/giacong/profile.rb
    "hausdorff",          # method/giacong/clip.rb
    "in_polygon",         # method/giacong/calc.rb
    "marching",           # method/giacong/profile.rb -- marching squares on a quadtree
    "max_distance",       # method/giacong/clip.rb
    "path_matches",       # method/giacong/rescue.rb
    "planar_graph",       # method/giacong/profile.rb
    "polygon_contains",   # method/giacong/profile.rb
    "polygon_distance",   # method/giacong/calc.rb
    "rdp_keep",           # method/giacong/profile.rb -- Ramer-Douglas-Peucker
    "rescue_drift",       # method/giacong/rescue.rb
    "round_labels",       # method/giacong/canvas.rb
    "self_intersects",    # method/giacong/profile.rb
    "signed_area",        # method/giacong/calc.rb
    "sweep_intersects",   # method/giacong/clip.rb
}
NATIVE = {"KSU::Clibs", "KSU::Clipper", "KSU::Cnc::Native", "Native"}

# Calls that were ALREADY dangling in the decrypted release, before a single
# rename. Checked against the baseline by hex, not by name: `_c52ad8bc` and
# `_7b408093` are called and never defined anywhere in the 127 files, so no
# name could have resolved them and no rename broke them.
#
# All four call sites sit in the three Vietnamese-named units that 2.3.2
# superseded -- danhsovan.rb, netcatcuoi*.rb, toiuuvan*.rb, replaced by
# danhso.rb, catcuoi/* and toiuu/*. The replacements never call either method.
# They are dead code kept beside the new copies, so this list should SHRINK
# when those units are deleted; it must never grow.
KNOWN_MISSING = {
    "apply_label_hiding",   # _c52ad8bc -- KSU::Cutting, called from 3 legacy units
    "sides",                # _7b408093 -- KSU::Avail, netcatcuoi/lastcut.rb only
}
# method dung san co the goi len mot Module/Class bat ky
BUILTIN = {
    "new", "name", "class", "instance_of?", "is_a?", "kind_of?", "respond_to?",
    "send", "public_send", "instance_variable_get", "instance_variable_set",
    "include", "extend", "prepend", "included", "const_get", "constants",
    "const_set", "const_defined?", "instance_variable_defined?",
    "instance_methods", "method_defined?", "ancestors", "freeze", "frozen?",
    "hash", "inspect", "to_s", "dup", "clone", "nil?", "==", "equal?",
    "allocate",
}

# KSU::VERSION, KSU::TOL ... la HANG SO, khong phai namespace: method goi len
# chung la method cua String/Float, khong phai method cua cay ma.
CONST = re.compile(r"::[A-Z0-9_]+$")

CALL = re.compile(r"\b((?:KSU(?:::[A-Z]\w*)*))\.([a-z_]\w*[?!]?)")

# --- phan 2: loi goi TRAN ---------------------------------------------------
# `ten(` trong Ruby luon la loi goi method: mot bien cuc bo khong goi duoc bang
# dau ngoac (phai viet ten.() hoac ten[]). Nen day la tin hieu chac, khong lan
# voi bien. Cai kho duy nhat la loc ra thu KHONG PHAI Ruby cua cay ma:
#   - tu khoa Ruby:  if (...)
#   - method Ruby / SketchUp dung san
#   - JavaScript va CSS nam trong heredoc (caidat.rb, utils/preset/field.rb)
# Heredoc duoc rut bang rename.strip_heredocs, dung ham nhu luc dat ten.
#
# Vi sao PHAI co phan nay: phan 1 chi soi loi goi co tien to namespace. Thu
# nghiem that: doi 'preview_push' -> 'preview_pushx' ngay tai cho goi trong
# cokeo/chain.rb thi phan 1 KHONG bat, va verify_structure.py cung khong bat
# (che dinh danh thi ca hai dau deu thanh 'X'). Phan 2 bat duoc.
BARE = re.compile(r"(?<![.:\w@$])([a-z_]\w*[?!]?)\s*\(")

KEYWORD = {"if", "unless", "elsif", "while", "until", "case", "when", "and",
           "or", "not", "return", "yield", "defined?", "catch", "throw",
           "begin", "rescue", "ensure", "raise", "next", "break", "then",
           "do", "end", "in", "for", "super", "lambda", "proc", "loop",
           # `else (e.y - a.y).abs` is a keyword followed by a parenthesised
           # expression, not a call to a method named `else`.
           "else", "self", "alias", "undef", "module", "class", "def"}

# Ruby / SketchUp dung san, goi tran duoc tu trong mot lop.
RUBY_BUILTIN = {
    "format", "sprintf", "printf", "puts", "print", "p", "rand", "srand",
    "const_set", "const_defined?", "const_get", "define_method",
    "require", "require_relative", "instance_variable_get",
    "instance_variable_set", "instance_variables", "respond_to?", "send",
    "public_send", "method", "define_method", "attr_reader", "attr_writer",
    "attr_accessor", "include", "extend", "prepend", "freeze", "dup", "clone",
    "is_a?", "kind_of?", "instance_of?", "nil?", "eql?", "equal?", "hash",
    "inspect", "to_s", "to_a", "to_i", "to_f", "block_given?", "caller",
    "sleep", "exit", "at_exit", "binding", "eval", "gets", "open", "warn",
    "file_loaded", "file_loaded?", "instance_exec", "instance_eval",
    "instance_variable_defined?", "create_makefile",
    # KSU::ABF::FaceGuard duoc prepend vao Sketchup::Face, nen get_attribute
    # goi tran o do la Sketchup::Entity#get_attribute.
    "get_attribute", "set_attribute", "delete_attribute",
}

_QSTR = re.compile(r"\"[^\"]*\"|'[^']*'")


def main() -> int:
    if not GRAPH.exists():
        print("thieu tools/graph.json -- chay: python tools/codegraph.py . tools/graph.json")
        return 1
    # A stale graph can report green when it should not: this check only asks
    # whether a called name is in `defined`, so a snapshot taken before a rename
    # still holds the old def name, matches the old call site, and hides the
    # break. Refuse to run against a graph older than the sources it describes.
    newest = max((q.stat().st_mtime for q in ROOT.rglob("*.rb")
                  if "tools" not in q.parts), default=0.0)
    if GRAPH.stat().st_mtime < newest:
        print("tools/graph.json cu hon ma nguon -- chay lai:\n"
              "  python tools/codegraph.py . tools/graph.json")
        return 1
    g = json.loads(GRAPH.read_text(encoding="utf-8"))
    defsite: dict[str, list] = g["defsite"]

    # Ten method dinh nghia trong tung namespace. Ruby cho include module nen
    # khong the ep "phai dung namespace"; chi doi hoi ten TON TAI o dau do.
    defined = set(defsite.keys())

    dangling = []
    n_calls = 0
    for p in sorted(ROOT.rglob("*.rb")):
        if "tools" in p.parts:
            continue
        rel = p.relative_to(ROOT).as_posix()
        # Same blanking as part 2, and for the same reason: the text inside
        # `"KSU.sheet-material"` reads as a call to KSU.sheet otherwise.
        src1 = code_only(p.read_text(encoding="utf-8", errors="replace"))
        for i, line in enumerate(src1.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for ns, meth in CALL.findall(line):
                if (ns in NATIVE or meth in BUILTIN or CONST.search(ns)
                        or meth in NATIVE_METHODS or meth in KNOWN_MISSING):
                    continue
                n_calls += 1
                if meth not in defined:
                    dangling.append((rel, i, ns, meth))

    # --- phan 2: loi goi tran ---
    n_bare = 0
    for p in sorted(ROOT.rglob("*.rb")):
        if "tools" in p.parts:
            continue
        rel = p.relative_to(ROOT).as_posix()
        # code_only blanks strings, comments AND regex literals while keeping
        # the line structure. Blanking only quoted strings left the inside of
        # `/_MAT_(?:TRUOC|SAU)/` and `/(?:\A|[-_])sheet(?:[-_]|\z)/` to be read
        # as bare calls -- the §6.11 trap, reported here as dangling calls that
        # no rename could fix.
        src = code_only(R.strip_heredocs(
            p.read_text(encoding="utf-8", errors="replace"), keep_lines=True))
        for i, line in enumerate(src.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for meth in BARE.findall(line):
                if (meth in KEYWORD or meth in RUBY_BUILTIN
                        or meth in NATIVE_METHODS or meth in KNOWN_MISSING):
                    continue
                n_bare += 1
                if meth not in defined:
                    dangling.append((rel, i, "(tran)", meth))

    print(f"da soi {n_calls} loi goi Namespace.method + {n_bare} loi goi tran")
    if dangling:
        print(f"\n{len(dangling)} LOI GOI TREO:")
        for rel, i, ns, meth in dangling:
            who = meth if ns == "(tran)" else f"{ns}.{meth}"
            print(f"  {rel}:{i}  {who}  -- khong co def nao ten '{meth}'")
        return 1
    print("0 loi goi treo -- cay ma tu dong")
    return 0


if __name__ == "__main__":
    sys.exit(main())
