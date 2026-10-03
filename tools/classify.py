#!/usr/bin/env python3
"""Doan KIEU DU LIEU cua tung hex con lai, de dat ten hang loat.

Cach lam: cham diem tap method duoc goi len hex voi chu ky cua tung kieu
SketchUp/Ruby. Tap method la chi dau manh hon doc tung dong, va o day no chay
duoc tren ca tram hex mot luot.

    python tools/classify.py                 # bang phan loai, hex nhieu nhat truoc
    python tools/classify.py --min-ns 5      # chi hex xuyen suot (lan A)
    python tools/classify.py --kind point    # chi mot kieu
    python tools/classify.py --taken         # liet ke ten DA dung, de khoi trung

Cot 'chac' = ty le diem cua kieu thang so voi tong diem. Duoi ~0.6 la da nghia,
gan nhu chac chan phai dung names.scoped.yml.
"""
from __future__ import annotations

import argparse
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEX = re.compile(r"_[0-9a-f]{8}")

SIG = {
    "point":  "offset offset! transform transform! distance vector_to x y z "
              "project_to_plane project_to_line to_a distance_to_plane "
              "distance_to_line".split(),
    "vector": "cross dot parallel? normalize normalize! samedirection? "
              "angle_between reverse reverse! perpendicular? axes unitvector? "
              "valid?".split(),
    "group":  "make_unique definition entities transformation entityID erase! "
              "layer local_transformation glued_to name explode "
              "set_attribute get_attribute attribute_dictionaries "
              "position_material".split(),
    "face":   "vertices edges normal outer_loop loops area pushpull "
              "classify_point all_connected material back_material".split(),
    "edge":   "start end line faces curve smooth? soft? split "
              "common_face".split(),
    "vertex": "position used_by? faces".split(),
    # Sketchup::Entities -- kieu trung tam cua cay ma nay. Phai dat TRUOC
    # "array" trong y niem: .grep va .each cung co o Entities, nhung
    # .add_line/.add_face/.erase_entities thi CHI Entities moi co.
    "ents":   "add_line add_face add_group add_curve add_circle add_edges "
              "add_instance add_cline add_text add_3d_text erase_entities "
              "intersect_with transform_entities parent model active".split(),
    "array":  "each map select reject first last empty? flat_map concat push "
              "size length find any? all? uniq sort_by min_by max_by "
              "each_with_index include? sum count grep zip compact "
              "each_slice each_cons index rotate sample shuffle "
              "delete_at".split(),
    "hash":   "key? fetch each_value each_key each_pair delete dup keys "
              "values store merge".split(),
    "num":    "to_f to_i round abs mm to_l to_mm times floor ceil zero? "
              "positive? negative? clamp divmod".split(),
    "str":    "strip to_s split upcase downcase sub gsub start_with? "
              "end_with? chars bytes unpack unpack1 encode".split(),
    "tf":     "inverse xscale yscale zscale origin xaxis yaxis zaxis "
              "identity?".split(),
    "bbox":   "min max width height depth add corner center diagonal".split(),
    "bool":   [],
}
# method chung nhieu kieu -> giam trong so, khong duoc quyet dinh
WEAK = {"grep", "valid?", "to_a", "to_s", "name", "material", "length", "size",
        "first", "last", "min", "max", "each", "map", "add", "dup",
        "is_a?", "nil?", "respond_to?", "send", "clone", "bounds",
        "vertices", "edges", "normal", "position", "delete", "count"}


def scan():
    info = defaultdict(lambda: {"n": 0, "ns": set(), "calls": Counter(),
                                "index": 0, "kinds": set()})
    for p in sorted(ROOT.rglob("*.rb")):
        if "tools" in p.parts:
            continue
        stack = []
        for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"^(\s*)(?:module|class)\s+([A-Z][\w:]*)", line)
            if m:
                stack = [s for s in stack if s[0] < len(m.group(1))]
                stack.append((len(m.group(1)), m.group(2)))
            here = "::".join(s[1] for s in stack) or p.name
            for h in HEX.findall(line):
                info[h]["n"] += 1
            for h in set(HEX.findall(line)):
                info[h]["ns"].add(here)
            for mm in re.finditer(r"@?(_[0-9a-f]{8})\.([a-zA-Z_][\w?!]*)", line):
                info[mm.group(1)]["calls"][mm.group(2)] += 1
            for mm in re.finditer(r"@?(_[0-9a-f]{8})\s*\[", line):
                info[mm.group(1)]["index"] += 1
            for h in re.findall(r"@(_[0-9a-f]{8})", line):
                info[h]["kinds"].add("ivar")
            for mm in re.finditer(r"^\s*def\s+(?:self\.)?(_[0-9a-f]{8})", line):
                info[mm.group(1)]["kinds"].add("method")
    return info


def score(d: dict) -> list[tuple[str, float]]:
    s: Counter = Counter()
    for meth, c in d["calls"].items():
        w = 0.3 if meth in WEAK else 1.0
        for kind, sig in SIG.items():
            if meth in sig:
                s[kind] += c * w
    if d["index"]:
        s["array"] += d["index"] * 0.5
        s["hash"] += d["index"] * 0.5
    return s.most_common()


def named_hexes() -> set[str]:
    """Hex da co ten trong bat ky tu dien nao -> bo qua khi phan loai.

    Can vi quy trinh chuan chay tren cay DA PHUC HOI baseline, luc do hex da
    dat ten van con nguyen dang hex trong cay.
    """
    out = set()
    for f in ("names.core.yml", "names.license.yml", "names.scoped.yml"):
        q = ROOT / "tools" / f
        if not q.exists():
            continue
        for line in q.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"\s*(_[0-9a-f]{8})\s*:\s*(\S.*)?$", line)
            if m and (m.group(2) or "").strip().rstrip(":"):
                out.add(m.group(1))
            elif re.match(r"^_[0-9a-f]{8}:\s*$", line):        # khoa cua scoped
                out.add(line.split(":")[0])
    return out


def taken_names() -> set[str]:
    out = set()
    for f in ("names.core.yml", "names.license.yml", "names.scoped.yml"):
        p = ROOT / "tools" / f
        if p.exists():
            for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
                m = re.match(r"\s*(?:_[0-9a-f]{8}|default|name)\s*:\s*([a-z_]\w*[?!]?)\s*(?:#.*)?$",
                             line)
                if m:
                    out.add(m.group(1))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--min-ns", type=int, default=0)
    ap.add_argument("--kind")
    ap.add_argument("--taken", action="store_true")
    ap.add_argument("--limit", type=int, default=60)
    args = ap.parse_args()

    if args.taken:
        t = sorted(taken_names())
        print(f"{len(t)} ten da dung:\n")
        for i in range(0, len(t), 10):
            print("  " + "  ".join(f"{x:<16}" for x in t[i:i + 10]))
        return 0

    info = scan()
    have = named_hexes()
    rows = []
    for h, d in info.items():
        if len(d["ns"]) < args.min_ns or h in have:
            continue
        sc = score(d)
        top, tot = (sc[0] if sc else ("?", 0)), sum(v for _, v in sc)
        conf = (top[1] / tot) if tot else 0.0
        rows.append((d["n"], len(d["ns"]), h, top[0] if tot else "?", conf,
                     ",".join(sorted(d["kinds"])) or "local",
                     [f"{k}:{v:.0f}" for k, v in sc[:3]]))
    rows.sort(key=lambda r: -r[0])
    if args.kind:
        rows = [r for r in rows if r[3] == args.kind]
    print(f"{len(rows)} hex\n")
    print(f"  {'lan':>4} {'ns':>3}  {'hex':<11} {'kieu':<7} {'chac':>5}  "
          f"{'la gi':<13} diem")
    for n, nns, h, kind, conf, kinds, det in rows[:args.limit]:
        flag = "" if conf >= 0.6 else "  <- da nghia"
        print(f"  {n:4} {nns:3}  {h:<11} {kind:<7} {conf:5.2f}  {kinds:<13} "
              f"{' '.join(det)}{flag}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
