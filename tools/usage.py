#!/usr/bin/env python3
"""Xem ngu canh su dung cua mot hex de dat ten dung."""
import re, subprocess, sys, glob
for hexname in sys.argv[1:]:
    print(f"\n{'='*70}\n{hexname}")
    files = glob.glob('ksu_vn/**/*.rb', recursive=True) + ['ksu_vn.rb']
    hits, defs = [], []
    for f in files:
        for i, line in enumerate(open(f, encoding='utf-8', errors='replace'), 1):
            if re.search(r'\b'+hexname+r'\b', line):
                s = line.strip()
                if re.match(r'(module|class)?\s*def\s+(self\.)?'+hexname, s): defs.append(f"{f}:{i}  {s[:100]}")
                else: hits.append(f"{f}:{i}  {s[:100]}")
    print(f"  [DEF {len(defs)}]")
    for d in defs[:4]: print("   ", d)
    print(f"  [USE {len(hits)}]  mau:")
    for h in hits[:9]: print("   ", h)
