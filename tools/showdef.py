#!/usr/bin/env python3
"""In than mot method: tools/showdef.py file.rb _hex [_hex...]"""
import re, sys
f = sys.argv[1]
lines = open(f, encoding='utf-8', errors='replace').read().splitlines()
for name in sys.argv[2:]:
    pat = re.compile(r'^(\s*)def\s+(self\.)?' + re.escape(name) + r'\b')
    for i, l in enumerate(lines):
        m = pat.match(l)
        if not m: continue
        ind = len(m.group(1))
        print(f"----- {f}:{i+1}  {name}")
        for j in range(i, min(i + 40, len(lines))):
            print("   " + lines[j])
            if j > i and re.match(r'^\s{%d}end\s*$' % ind, lines[j]): break
        print()
