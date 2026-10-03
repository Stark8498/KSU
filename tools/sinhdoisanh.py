#!/usr/bin/env python3
"""Generate tools/doisanh.rb: the same inputs through both copies of KSU.

Loading proves the tree loads. Resolving proves every call finds a method. What
neither proves is that a method still COMPUTES what it did -- a rename cannot
change behaviour in theory, and this is how the theory gets tested rather than
asserted.

The shipped plugin still sits in SketchUp 2025 and still carries hex, while the
readable tree loads into SketchUp 2024. Two processes, two copies, one set of
inputs. So each case here records BOTH names: `convex_hull` on this side,
`_35c2c696` on that one. The runner asks which copy it is in and calls the name
that copy has.

The hex is not typed in by hand. verify_structure has already proved the only
difference between the two files is the identifiers and the one stripped
XSU_NOTICE line, so line N here is line N+1 of the baseline, and the `def` on
that line names the same method.

    python tools/sinhdoisanh.py
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import ROOT  # noqa: E402

BASELINE = "c45104c"

# Fixed inputs, written as Ruby so no value has to survive a round trip through
# JSON. An L shape rather than a square: a convex hull, a centroid and a
# separating axis all have something to say about an L and nothing to say about
# a square.
PRELUDE = """
def pt(x, y, z = 0) Geom::Point3d.new(x, y, z) end

L = [pt(0, 0), pt(90, 0), pt(90, 30), pt(40, 30), pt(40, 80), pt(0, 80)]
L2 = [pt(60, 20), pt(160, 20), pt(160, 70), pt(60, 70)]
SCATTER = [pt(10, 10), pt(50, 12), pt(90, 10), pt(50, 50),
           pt(88, 60), pt(12, 62), pt(45, 30), pt(60, 40)]
BOX_A = { min_x: 0.0, max_x: 90.0, min_y: 0.0, max_y: 80.0 }
BOX_B = { min_x: 85.0, max_x: 200.0, min_y: 40.0, max_y: 120.0 }
BOX_C = { min_x: 300.0, max_x: 400.0, min_y: 0.0, max_y: 10.0 }

# KSU::Sheet.dist_to_box reads .min and .max off a real BoundingBox, not off
# the { min_x: ... } hash KSU::Geom.bounds returns. Two shapes, both called a
# box in this tree.
BB = Geom::BoundingBox.new
BB.add(pt(0, 0, 0))
BB.add(pt(90, 80, 0))
"""

# (module, method, file it is defined in, Ruby for the arguments)
CASES = [
    ("KSU::Geom", "convex_hull", "ksu_vn/utils/geom.rb", "SCATTER"),
    ("KSU::Geom", "bounds", "ksu_vn/utils/geom.rb", "L"),
    ("KSU::Geom", "boxes_overlap?", "ksu_vn/utils/geom.rb", "BOX_A, BOX_B, 0.0"),
    ("KSU::Geom", "boxes_overlap?", "ksu_vn/utils/geom.rb", "BOX_A, BOX_C, 0.0"),
    ("KSU::Geom", "boxes_overlap?", "ksu_vn/utils/geom.rb", "BOX_A, BOX_C, 215.0"),
    ("KSU::Geom", "edge_normals", "ksu_vn/utils/geom.rb", "L"),
    ("KSU::Geom", "project_range", "ksu_vn/utils/geom.rb", "L, 0.6, 0.8"),
    ("KSU::Geom", "centroid", "ksu_vn/utils/geom.rb", "L"),
    ("KSU::Geom", "translate", "ksu_vn/utils/geom.rb", "L, 12.5, -3.25"),
    ("KSU::Geom", "sat_mtv", "ksu_vn/utils/geom.rb", "L, L2, 0.0"),
    ("KSU::Geom", "sat_mtv", "ksu_vn/utils/geom.rb", "L, L2, 5.0"),
    ("KSU::Geom", "point_in?", "ksu_vn/utils/geom.rb", "20.0, 20.0, L"),
    ("KSU::Geom", "point_in?", "ksu_vn/utils/geom.rb", "70.0, 70.0, L"),
    ("KSU::Geom", "cross3", "ksu_vn/utils/geom.rb", "pt(0, 0), pt(10, 0), pt(10, 10)"),
    ("KSU::Geom", "segments_cross?", "ksu_vn/utils/geom.rb",
     "pt(0, 0), pt(10, 10), pt(0, 10), pt(10, 0)"),
    ("KSU::Geom", "segments_cross?", "ksu_vn/utils/geom.rb",
     "pt(0, 0), pt(1, 1), pt(5, 5), pt(6, 6)"),
    ("KSU::Geom", "dist2_to_seg", "ksu_vn/utils/geom.rb",
     "pt(5, 9), pt(0, 0), pt(10, 0)"),
    ("KSU::Geom", "seg_dist2", "ksu_vn/utils/geom.rb",
     "pt(0, 0), pt(10, 0), pt(3, 4), pt(7, 4)"),
    ("KSU::Nfp", "simplify_pts", "ksu_vn/method/xeptam/nfp.rb", "L"),
    ("KSU::Nfp", "convex?", "ksu_vn/method/xeptam/nfp.rb", "L"),
    ("KSU::Nfp", "convex?", "ksu_vn/method/xeptam/nfp.rb", "L2"),
    ("KSU::Nfp", "lowest_ix", "ksu_vn/method/xeptam/nfp.rb", "L"),
    ("KSU::Nfp", "minkowski_convex", "ksu_vn/method/xeptam/nfp.rb", "L2, L2"),
    ("KSU::Nfp", "nfp_of", "ksu_vn/method/xeptam/nfp.rb", "L2, L2"),
    ("KSU::Nfp", "poly_key", "ksu_vn/method/xeptam/nfp.rb", "L"),
    ("KSU::Sheet", "dist_to_box", "ksu_vn/utils/sheet.rb", "pt(200, 200), BB"),
    ("KSU::Sheet", "dist_to_box", "ksu_vn/utils/sheet.rb", "pt(45, 40), BB"),
    ("KSU::Sheet", "to_point", "ksu_vn/utils/sheet.rb", "pt(1, 2, 3)"),
    ("KSU::Sheet", "to_point", "ksu_vn/utils/sheet.rb", "[pt(1, 2, 3)]"),
    ("KSU::Sheet", "to_point", "ksu_vn/utils/sheet.rb", "nil"),
]


def baseline_lines(rel: str) -> list[str]:
    src = subprocess.run(["git", "show", f"{BASELINE}:{rel}"], cwd=ROOT,
                         capture_output=True, text=True,
                         encoding="utf-8").stdout.splitlines()
    if src and src[0].startswith("XSU_NOTICE"):
        src = src[1:]
    return src


def old_name(rel: str, meth: str) -> str | None:
    """The hex that this method had, found at the same line of the baseline."""
    now = (ROOT / rel).read_text(encoding="utf-8", errors="replace").splitlines()
    old = baseline_lines(rel)
    # Not \b: a name ending in `?` or `!` puts a non-word character last, and
    # `\b` between that and the `(` of the parameter list never matches, which
    # silently dropped every predicate from the battery.
    want = re.compile(r"^\s*def\s+(?:self\.)?" + re.escape(meth) + r"(?![\w?!])")
    for i, line in enumerate(now):
        if not want.match(line) or i >= len(old):
            continue
        m = re.match(r"^\s*def\s+(?:self\.)?(\S+?)(?:\(|\s|$)", old[i])
        if m:
            return m.group(1)
    return None


def main() -> int:
    rows = []
    for mod, meth, rel, args in CASES:
        old = old_name(rel, meth)
        if old is None:
            print(f"BO QUA (khong tra duoc hex): {mod}.{meth}")
            continue
        rows.append(f'  ["{mod}", "{meth}", "{old}", lambda {{ [{args}] }}],')

    body = PRELUDE + "\nCASES = [\n" + "\n".join(rows) + "\n]\n"
    dst = ROOT / "tools" / "doisanh_cases.rb"
    dst.write_text(
        "# Sinh boi tools/sinhdoisanh.py -- dung sua tay, chay lai se ghi de.\n"
        "# Moi dong: [module, ten moi, ten hex cu, ham dung doi so].\n"
        + body, encoding="utf-8", newline="")
    print(f"{len(rows)} truong hop -> tools/doisanh_cases.rb")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
