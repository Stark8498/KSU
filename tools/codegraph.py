#!/usr/bin/env python3
"""Build a code graph for the ksu_vn readable SketchUp plugin."""
import json, re, sys
from pathlib import Path
from collections import defaultdict, Counter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kscommon import code_only  # noqa: E402

ROOT = Path(sys.argv[1]).resolve()
OUT  = Path(sys.argv[2]).resolve()

RE_NS      = re.compile(r'^(\s*)(module|class)\s+([A-Za-z0-9_:]+)(?:\s*<\s*([A-Za-z0-9_:]+))?')
# Cho phep ca dang gon mot dong:  def ten; than; end
# (khong co nhanh '|;.*' thi 4 method trong taocanh/grid.rb bi bo sot hoan toan)
RE_DEF     = re.compile(r'^(\s*)def\s+(self\.)?([A-Za-z_][A-Za-z0-9_]*[?!=]?)\s*(\(.*|;.*)?$')
RE_DEF_1LINE = re.compile(r'^\s*def\s.*;\s*end\s*$')
RE_END     = re.compile(r'^(\s*)end\s*$')
RE_CONST   = re.compile(r'^\s*([A-Z][A-Z0-9_]{2,})\s*=')
RE_INCLUDE = re.compile(r'^\s*(include|prepend|extend)\s+([A-Za-z0-9_:]+)')
RE_IVAR    = re.compile(r'@(_[0-9a-f]{8}|[a-z_][a-z0-9_]*)')
RE_QUAL    = re.compile(r'\b((?:KSU::)?(?:[A-Z][A-Za-z0-9]*::)*[A-Z][A-Za-z0-9]*)\.([a-z_][A-Za-z0-9_]*[?!]?|_[0-9a-f]{8})')
RE_MANGLED = re.compile(r'\b(_[0-9a-f]{8})\b')
RE_SKREQ   = re.compile(r'Sketchup\.require\s+"([^"]+)"')
RE_HTML    = re.compile(r'["\']([a-z_]+\.html)["\']')
RE_SUOBS   = re.compile(r'\b(Sketchup|UI|Geom|Layout)\b(?:::([A-Za-z]+))?')

files = sorted(p for p in ROOT.rglob('*.rb'))
symbols   = {}                      # fqname -> record
per_file  = defaultdict(lambda: {'namespaces': [], 'defs': [], 'consts': [], 'mixins': [], 'requires': [], 'lines': 0, 'html': []})
refs      = Counter()               # mangled name -> count of references
ref_sites = defaultdict(set)        # mangled name -> files referencing
qual_edges= Counter()               # (from_file, TargetNamespace) -> count
qual_pairs= Counter()               # (TargetNamespace, method) -> count
sk_api    = Counter()

def rel(p): return p.relative_to(ROOT).as_posix()

for p in files:
    r = rel(p)
    text = p.read_text(encoding='utf-8', errors='replace')
    # Calls are read off a copy with strings and comments blanked. Scanning the
    # raw text reported the inside of `"KSU.sheet-material"` as a call to
    # KSU.sheet and `/_MAT_(?:TRUOC|SAU)/` as a method `_MAT_`, and those
    # reached verify_graph.py as dangling calls that no rename could ever fix.
    # code_only keeps the line structure, so line numbers still line up.
    code = code_only(text)
    lines = text.splitlines()
    per_file[r]['lines'] = len(lines)
    stack = []                      # (indent, kind, name)
    for i, line in enumerate(lines, 1):
        if line.lstrip().startswith('#'):
            continue
        m = RE_NS.match(line)
        if m:
            indent, kind, name, sup = m.group(1), m.group(2), m.group(3), m.group(4)
            outer = stack[-1][2] if stack else ''
            fq = name if name.startswith('KSU') or not outer else f'{outer}::{name}'
            stack.append((len(indent), kind, fq))
            per_file[r]['namespaces'].append({'kind': kind, 'name': fq, 'line': i, 'super': sup})
            symbols.setdefault(fq, {'kind': kind, 'files': set(), 'methods': [], 'super': sup})
            symbols[fq]['files'].add(r)
            if sup: symbols[fq]['super'] = sup
            continue
        m = RE_DEF.match(line)
        if m:
            indent, is_self, name = m.group(1), bool(m.group(2)), m.group(3)
            owner = stack[-1][2] if stack else '(toplevel)'
            sig = (line.strip()[:160])
            rec = {'name': name, 'self': is_self, 'owner': owner, 'line': i, 'file': r, 'sig': sig}
            per_file[r]['defs'].append(rec)
            symbols.setdefault(owner, {'kind': 'module', 'files': set(), 'methods': [], 'super': None})
            symbols[owner]['methods'].append(rec)
            # do not push def onto ns stack (its `end` is matched below by indent rule)
            # Method gon mot dong da tu dong 'end' ngay tai day -> khong day vao
            # stack, neu khong stack se lech va gan sai namespace cho cac method sau.
            if not RE_DEF_1LINE.match(line):
                stack.append((len(indent), 'def', owner))
            continue
        m = RE_END.match(line)
        if m and stack:
            ind = len(m.group(1))
            while stack and stack[-1][0] >= ind:
                stack.pop()
            continue
        m = RE_CONST.match(line)
        if m:
            owner = next((s[2] for s in reversed(stack) if s[1] != 'def'), '(toplevel)')
            per_file[r]['consts'].append({'name': m.group(1), 'owner': owner, 'line': i})
        m = RE_INCLUDE.match(line)
        if m:
            per_file[r]['mixins'].append({'how': m.group(1), 'what': m.group(2), 'line': i})
    for m in RE_SKREQ.finditer(text):
        per_file[r]['requires'].append(m.group(1))
    for m in RE_HTML.finditer(text):
        per_file[r]['html'].append(m.group(1))
    for m in RE_MANGLED.finditer(code):
        refs[m.group(1)] += 1
        ref_sites[m.group(1)].add(r)
    for m in RE_QUAL.finditer(code):
        qual_edges[(r, m.group(1))] += 1
        if m.group(1) == 'KSU' or m.group(1).startswith('KSU::'):
            qual_pairs[(m.group(1), m.group(2))] += 1
    for m in RE_SUOBS.finditer(code):
        sk_api[m.group(0)] += 1

# map mangled defs -> definition site
defsite = defaultdict(list)
for r, d in per_file.items():
    for rec in d['defs']:
        defsite[rec['name']].append(f"{rec['owner']}{'.' if rec['self'] else '#'}{rec['name']}  ({rec['file']}:{rec['line']})")

data = {
  'root': str(ROOT),
  'file_count': len(files),
  'total_lines': sum(d['lines'] for d in per_file.values()),
  'symbols': {k: {'kind': v['kind'], 'files': sorted(v['files']), 'super': v['super'],
                  'method_count': len(v['methods']),
                  'methods': [f"{'self.' if m['self'] else ''}{m['name']}" for m in v['methods']]}
              for k, v in sorted(symbols.items())},
  'per_file': {k: {**v, 'defs': [{'n': d['name'], 's': d['self'], 'o': d['owner'], 'l': d['line']} for d in v['defs']]}
               for k, v in sorted(per_file.items())},
  'refs_top': refs.most_common(80),
  'defsite': {k: v for k, v in sorted(defsite.items())},
  'qual_edges': [{'file': k[0], 'target': k[1], 'n': v} for k, v in sorted(qual_edges.items(), key=lambda x: -x[1])],
  'qual_pairs': [{'ns': k[0], 'm': k[1], 'n': v} for k, v in qual_pairs.most_common()],
  'sk_api': sk_api.most_common(40),
}
OUT.write_text(json.dumps(data, indent=1, ensure_ascii=False), encoding='utf-8')

print(f"files={len(files)} lines={data['total_lines']} namespaces={len(symbols)} defs={sum(len(v['methods']) for v in symbols.values())}")
print("\n=== namespaces by method count ===")
for k, v in sorted(symbols.items(), key=lambda x: -len(x[1]['methods']))[:80]:
    print(f"{len(v['methods']):4d}  {v['kind']:6s} {k}   [{', '.join(sorted(v['files'])[:3])}]")
