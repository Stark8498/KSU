#!/usr/bin/env python3
"""Call graph and seam index for the KSU tree, built for CHANGING the code.

tools/codegraph.py answers "what exists"; it is the inventory the rename
verifier checks against. This answers the two questions a change starts from:

    who calls this?        -- the blast radius of an edit
    what does this call?   -- everything an edit has to keep working

On top of the call edges it indexes the SEAMS, the places where the plugin
touches something outside the Ruby tree and where a bug therefore crosses a
boundary the call graph alone cannot follow:

    toolbar command -> entry method       (main.rb TOOL_DATA)
    HtmlDialog callback -> handler        (add_action_callback)
    Ruby -> JS                            (execute_script)
    settings.json key -> reader/writer    (Settings.get/set)
    model attribute key -> reader/writer  (get_attribute "KSU")
    native kernel call                    (KSU::Clibs, KSU::Clipper in ksu.so)
    SketchUp Tool callback                (activate, draw, onLButtonDown ...)

Build, then query:

    python tools/dothi.py --dung                 # build tools/dothi.json
    python tools/dothi.py --ai-goi draw_sheet    # callers, transitively
    python tools/dothi.py --goi KSU::Nest.open   # callees, transitively
    python tools/dothi.py --duong A B            # a call path from A to B
    python tools/dothi.py --tinhnang nesting     # everything one tool reaches
    python tools/dothi.py --file utils/sheet.rb  # one file's card
    python tools/dothi.py --seam                 # every seam, grouped
    python tools/dothi.py --tim "nhan"           # find a def by name fragment

Resolution is deliberate about what it does NOT know. A bare call whose name
is defined in several namespaces is recorded as ambiguous with its candidates
listed, never silently pinned to one of them -- a wrong edge is worse than a
missing one when the graph is used to decide what an edit can break.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict, deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kscommon as R  # noqa: E402

ROOT = R.ROOT
OUT = ROOT / "tools" / "dothi.json"

# --- Ruby / SketchUp surface the tree calls but does not define -------------
# A name here is NOT a dangling call; it belongs to the interpreter or to the
# SketchUp API. verify_graph.py keeps its own copy for the same reason; the two
# lists are allowed to drift because they answer different questions (that one
# asks "is this call broken", this one asks "is this edge worth drawing").
RUBY_BUILTIN = {
    "format", "sprintf", "printf", "puts", "print", "p", "pp", "rand", "srand",
    "require", "require_relative", "load", "raise", "fail", "catch", "throw",
    "loop", "lambda", "proc", "block_given?", "caller", "binding", "eval",
    "sleep", "exit", "at_exit", "gets", "open", "warn", "freeze", "frozen?",
    "dup", "clone", "hash", "inspect", "to_s", "to_a", "to_i", "to_f", "to_r",
    "to_sym", "to_proc", "nil?", "eql?", "equal?", "is_a?", "kind_of?",
    "instance_of?", "respond_to?", "send", "public_send", "method",
    "define_method", "instance_variable_get", "instance_variable_set",
    "instance_variables", "instance_variable_defined?", "instance_exec",
    "instance_eval", "attr_reader", "attr_writer", "attr_accessor",
    "include", "extend", "prepend", "included", "const_get", "constants",
    "instance_methods", "method_defined?", "ancestors", "allocate", "new",
    "name", "class", "file_loaded", "file_loaded?", "create_makefile",
    "get_attribute", "set_attribute", "delete_attribute", "defined?",
    "Integer", "Float", "String", "Array", "Hash", "Rational",
}

# Methods bound by the compiled kernel (ksu_vn/clibs/*/ksu.so). There is no
# `def` for these anywhere in the tree, so the resolver would call them
# dangling; they are real calls into native code and get their own edge kind.
NATIVE_METHODS = {
    "convex_hull", "polygons_overlap?", "pack_bl", "nfp", "nfp_snap",
    "inflate", "contact_refine", "build_loops",
}
NATIVE_NS = {"KSU::Clibs", "KSU::Clipper"}

# Methods SketchUp calls on us, never the tree on itself. A def with one of
# these names is a graph ROOT even when nothing in the tree calls it: miss
# them and every Tool class looks like dead code.
SU_CALLBACKS = {
    "activate", "deactivate", "draw", "getExtents", "resume", "suspend",
    "onCancel", "onSetCursor", "onReturn", "onUserText", "enableVCB?",
    "onLButtonDown", "onLButtonUp", "onLButtonDoubleClick",
    "onRButtonDown", "onRButtonUp", "onMButtonDown",
    "onMouseMove", "onMouseEnter", "onMouseLeave", "onMouseWheel",
    "onKeyDown", "onKeyUp", "getInstructorContentDirectory", "getMenu",
    "onTransactionCommit", "onTransactionUndo", "onTransactionRedo",
    "onTransactionStart", "onTransactionAbort",
    # Ruby's own hooks: the interpreter calls these, never the tree.
    "included", "extended", "inherited", "method_missing", "initialize",
}

KEYWORD = {
    "if", "unless", "elsif", "else", "while", "until", "case", "when", "and",
    "or", "not", "return", "yield", "begin", "rescue", "ensure", "next",
    "break", "redo", "retry", "then", "do", "end", "in", "for", "super",
    "self", "alias", "undef", "module", "class", "def", "nil", "true",
    "false", "__FILE__", "__LINE__", "__dir__", "defined",
}

RE_NS = re.compile(r"^(\s*)(module|class)\s+([A-Za-z0-9_:]+)(?:\s*<\s*([A-Za-z0-9_:]+))?")
# `class << self` opens a singleton body: every plain `def` inside it is a
# class method. method/chontam/pick.rb is the one place in the tree that uses
# it, and without this its 40-odd defs are filed as instance methods, so the
# `self.class.panel_at(...)` calls in chontam.rb resolve to nothing.
RE_SINGLETON = re.compile(r"^(\s*)class\s*<<\s*self\s*$")
RE_DEF = re.compile(r"^(\s*)def\s+(self\.)?([A-Za-z_][A-Za-z0-9_]*[?!=]?)\s*(\(.*)?$")
RE_END = re.compile(r"^(\s*)end\b")
RE_INCLUDE = re.compile(r"^\s*(include|prepend|extend)\s+([A-Za-z0-9_:]+)")
# The tree's real composition mechanism, and the one nothing else shows. Each
# method/<tool>/<part>.rb and utils/<thing>/<part>.rb defines a standalone
# module and then folds itself into its parent on the LAST LINE of the file:
#
#     KSU::Xeptam.include(KSU::Drag)
#
# So KSU::Xeptam owns the methods of eight files, a bare call in drag.rb can
# land in collide.rb, and KSU::Drag is never a receiver anyone calls through.
# Miss this and half the bare calls in method/ look unresolvable.
RE_COMPOSE = re.compile(r"^(KSU(?:::\w+)*)\.(extend|include|prepend)\((KSU(?:::\w+)*)\)")
# The second composition mechanism, inside `def self.included(base)`:
#
#     def self.included(base)
#       base.extend(ClassMethods)
#       base.prepend(SbUserTextHandler)
#     end
#
# Ruby runs this for every class that includes the outer module, so all nine
# tool classes silently gain those two modules. utils/preset.rb is the only
# user, but it reaches the whole method/ layer through it.
RE_HOOK = re.compile(r"^\s*(\w+)\.(extend|include|prepend)\((\w+)\)")
RE_CONST = re.compile(r"^\s*([A-Z][A-Z0-9_]{2,})\s*=[^=]")

# A call with an explicit receiver that names a KSU namespace. This is the
# edge we can resolve exactly, because the receiver says where to look.
RE_QUAL = re.compile(r"\b(KSU(?:::[A-Z]\w*)*)\.([a-z_]\w*[?!]?)")
# A bare call. `name(` in Ruby is always a method call -- a local variable
# cannot be called with parentheses (it needs .() or []). `name` without
# parens is ambiguous with a local read, so it is only taken when the name is
# a method of the enclosing namespace chain.
RE_BARE_PAREN = re.compile(r"(?<![.:\w@$])([a-z_]\w*[?!]?)\s*\(")
RE_BARE_PLAIN = re.compile(r"(?<![.:\w@$])([a-z_]\w*[?!]?)(?![\w:(])")
RE_SELFCLASS = re.compile(r"\bself\.class\.([a-z_]\w*[?!]?)")
# A chained call through a namespace: KSU::Nesting::Engine.instance.stop. The
# head resolves, the tail does not, and the tail is the interesting half.
RE_CHAIN = re.compile(r"\bKSU(?:::[A-Z]\w*)*\.[a-z_]\w*[?!]?\.([a-z_]\w*[?!]?)")
# Any call through a receiver the graph cannot type: @engine.stop, row.width.
# These never become edges -- the receiver's class is unknown, so an edge
# would be a guess -- but they do prove a name is still reached from
# somewhere, which is what keeps the dead-code list honest.
RE_RECV = re.compile(r"[\w\])}\"']\.([a-z_]\w*[?!]?)")
# Duck-typed dispatch: `tool.reload_settings if tool.respond_to?(:reload_settings)`
# in setting.rb is the only caller of every tool's reload_settings. A def
# named in one of these is reachable even when no edge points at it.
RE_SYMCALL = re.compile(r"(?:respond_to\?|\bsend|public_send|method)\(\s*:([a-z_]\w*[?!]?)")

# --- seams ------------------------------------------------------------------
RE_CALLBACK = re.compile(r"add_action_callback\(\s*[\"']([^\"']+)[\"']")
RE_EXEC_JS = re.compile(r"execute_script\((.*)$")
RE_JS_FN = re.compile(r"(?:window\.)?([A-Za-z_$][\w$]*)\s*\(")
RE_SKP = re.compile(r"skp\(\s*['\"]([a-z_]+)['\"]")
# One `when` can carry several labels -- `when "load_data", "reload_data"` --
# so the line is matched first and every string on it taken, not just the one
# right after the keyword.
RE_WHEN_LINE = re.compile(r"^\s*when\s+(.*)$", re.M)
RE_WHEN_LBL = re.compile(r"\"([a-z_]+)\"")
RE_SET_KEY = re.compile(
    r"(?:KSU::)?Settings\.(get_raw|get|set|set_raw|fetch)\(\s*[\"']([^\"']+)[\"']")
RE_ATTR = re.compile(
    r"\.(get_attribute|set_attribute|delete_attribute)\(\s*[\"']([^\"']+)[\"']"
    r"(?:\s*,\s*[\"']([^\"']+)[\"'])?")
RE_HTML = re.compile(r"[\"']([a-z_]+\.html)[\"']")
RE_DIALOG = re.compile(r"UI::HtmlDialog\.new|UI::WebDialog\.new")


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


# ---------------------------------------------------------------------------
# pass 1: definitions
# ---------------------------------------------------------------------------
def scan_defs(files: list[Path]) -> tuple[dict, dict, dict, dict, dict]:
    """Every def in the tree, keyed by `Owner.name` / `Owner#name`.

    The namespace stack is driven by indentation, not by a Ruby parse: the
    tree is uniformly two-space indented and every `end` sits at the column of
    what it closes, so matching on column is exact here and costs no parser.
    """
    defs: dict[str, dict] = {}
    files_info: dict[str, dict] = {}
    mixins: dict[str, list[str]] = defaultdict(list)
    compose: dict[str, list[str]] = defaultdict(list)
    supers: dict[str, str] = {}
    hooks: dict[str, list[str]] = defaultdict(list)

    for p in files:
        r = rel(p)
        raw = p.read_text(encoding="utf-8", errors="replace")
        code = R.code_only(raw)
        lines = code.splitlines()
        info = {
            "lines": len(lines), "namespaces": [], "defs": [], "consts": [],
            "includes": [], "html": [], "raw": raw, "code": code,
        }
        files_info[r] = info

        stack: list[tuple[int, str, str]] = []  # (indent, kind, name)
        open_defs: list[tuple[int, str]] = []   # (indent, def_id)
        singleton: list[int] = []               # indents of open `class << self`

        for i, line in enumerate(lines, 1):
            if not line.strip():
                continue
            m = RE_END.match(line)
            if m:
                ind = len(m.group(1))
                while open_defs and open_defs[-1][0] >= ind:
                    _, did = open_defs.pop()
                    defs[did]["end"] = i
                while stack and stack[-1][0] >= ind:
                    stack.pop()
                while singleton and singleton[-1] >= ind:
                    singleton.pop()
                continue
            m = RE_SINGLETON.match(line)
            if m:
                singleton.append(len(m.group(1)))
                continue
            m = RE_NS.match(line)
            if m:
                indent, kind, name, sup = m.groups()
                outer = stack[-1][2] if stack else ""
                fq = name if name.startswith("KSU") or not outer else f"{outer}::{name}"
                stack.append((len(indent), kind, fq))
                info["namespaces"].append({"kind": kind, "name": fq, "line": i, "super": sup})
                if sup:
                    supers[fq] = sup if sup.startswith("KSU") else f"{fq.rsplit('::', 1)[0]}::{sup}"
                continue
            m = RE_DEF.match(line)
            if m:
                indent, is_self, name, _ = m.groups()
                owner = stack[-1][2] if stack else "(toplevel)"
                is_self = bool(is_self) or bool(singleton)
                did = f"{owner}{'.' if is_self else '#'}{name}"
                defs[did] = {
                    "id": did, "name": name, "owner": owner, "self": bool(is_self),
                    "file": r, "line": i, "end": i, "sig": raw.splitlines()[i - 1].strip(),
                }
                info["defs"].append(did)
                open_defs.append((len(indent), did))
                continue
            if open_defs and defs[open_defs[-1][1]]["name"] == "included":
                m = RE_HOOK.match(line)
                if m and m.group(1) not in ("KSU",):
                    outer = defs[open_defs[-1][1]]["owner"]
                    hooks[outer].append(f"{outer}::{m.group(3)}")
            m = RE_COMPOSE.match(line)
            if m:
                parent, how, child = m.groups()
                compose[parent].append(child)
                info["includes"].append({"how": f"{how}()", "what": child,
                                         "into": parent, "line": i})
                continue
            m = RE_INCLUDE.match(line)
            if m and stack:
                # `extend self` makes the module's instance methods callable
                # on the module itself; it adds no other module to the chain.
                if m.group(2) == "self":
                    info["includes"].append({"how": "extend", "what": "self", "line": i})
                    continue
                mixins[stack[-1][2]].append(m.group(2))
                info["includes"].append({"how": m.group(1), "what": m.group(2), "line": i})
                continue
            m = RE_CONST.match(line)
            if m:
                owner = stack[-1][2] if stack else "(toplevel)"
                info["consts"].append({"name": m.group(1), "owner": owner, "line": i})

        for m in RE_HTML.finditer(raw):
            if m.group(1) not in info["html"]:
                info["html"].append(m.group(1))

    return defs, files_info, dict(mixins), dict(compose), supers, dict(hooks)


def build_chains(mixins: dict, compose: dict, supers: dict,
                 hooks: dict) -> dict[str, list[str]]:
    """Lookup chain per namespace, as Ruby would see it at run time.

    For a module folded into a parent (KSU::Xeptam.include(KSU::Drag)) the
    chain is not just Drag: at run time every method of every module folded
    into Xeptam sits in one ancestor list, so a bare call in drag.rb reaches
    push.rb and collide.rb. Modelling only the lexical `include` lines misses
    that and leaves most of method/ looking unresolvable.
    """
    folded_into: dict[str, str] = {}
    for parent, kids in compose.items():
        for k in kids:
            folded_into[k] = parent

    def norm(n: str) -> str:
        return n if n.startswith("KSU") else f"KSU::{n}"

    # A module injected by an `included` hook is in the chain of every class
    # that includes its outer module -- and, the other way round, code inside
    # that module runs with `self` being one of those classes, so the classes
    # belong in ITS chain too. Both directions are needed or
    # SbUserTextHandler#onKeyDown reads as calling nothing.
    hosts: dict[str, list[str]] = defaultdict(list)
    for owner, ms in mixins.items():
        for m in ms:
            for inj in hooks.get(norm(m), []):
                hosts[inj].append(owner)

    seeds = set(list(mixins) + list(compose) + list(folded_into)
                + list(supers) + list(hosts))
    for ms in hooks.values():
        seeds.update(ms)
    chains: dict[str, list[str]] = {}
    for owner in seeds:
        seen, order, queue = set(), [], deque([owner])
        while queue:
            cur = queue.popleft()
            if cur in seen:
                continue
            seen.add(cur)
            order.append(cur)
            group = folded_into.get(cur)
            if group:
                queue.append(group)
            for sib in compose.get(cur, []):
                queue.append(sib)
            for m in mixins.get(cur, []):
                queue.append(norm(m))
                queue.extend(hooks.get(norm(m), []))
            queue.extend(hosts.get(cur, []))
            if cur in supers:
                queue.append(supers[cur])
        chains[owner] = order
    return chains


def ancestors(owner: str, chains: dict[str, list[str]]) -> list[str]:
    return chains.get(owner, [owner])


# ---------------------------------------------------------------------------
# pass 2: call edges
# ---------------------------------------------------------------------------
def scan_calls(defs: dict, files_info: dict, chains: dict) -> tuple[dict, dict]:
    by_owner: dict[str, dict[str, str]] = defaultdict(dict)
    by_name: dict[str, list[str]] = defaultdict(list)
    for did, d in defs.items():
        by_owner[d["owner"]][d["name"]] = did
        by_name[d["name"]].append(did)

    calls: dict[str, list[dict]] = defaultdict(list)
    unresolved = Counter()
    recv_names: set[str] = set()

    # line -> enclosing def, per file. Nested defs do not occur in this tree,
    # so the innermost span that covers a line is simply the last one opened.
    for r, info in files_info.items():
        owner_at: list[tuple[int, int, str]] = [
            (defs[d]["line"], defs[d]["end"], d) for d in info["defs"]]
        owner_at.sort()
        lines = info["code"].splitlines()

        body_ns = [(n["line"], n["name"]) for n in info["namespaces"]]
        for i, line in enumerate(lines, 1):
            # The signature line belongs to its own def, not to the module
            # body: `def rank_plan(sweep = sweep_dir)` really does call
            # sweep_dir, and filing that line under the module body turns
            # every def into a phantom caller of itself.
            holder = next((d for a, b, d in owner_at if a <= i <= b), None)
            if holder is not None and defs[holder]["line"] == i:
                line = re.sub(r"^(\s*)def\s+(self\.)?[A-Za-z_]\w*[?!=]?", r"\1", line)
            if holder is None:
                # Module-body code, not inside any def. Skipping it would hide
                # the tree's real entry points: ksu_vn/main.rb binds all 14
                # toolbar commands from a table at module level, so without
                # this every `KSU::Intem.open` looks like it has no caller.
                holder = f"{r} (than module)"
                if holder not in defs:
                    defs[holder] = {"id": holder, "name": "(than module)",
                                    "owner": "(than module)", "self": False,
                                    "file": r, "line": 1, "end": info["lines"],
                                    "sig": f"-- ma o thann module cua {r} --"}
                host_owner = next((n for ln, n in reversed(body_ns) if ln <= i),
                                  "(toplevel)")
            else:
                host_owner = defs[holder]["owner"]
            chain = ancestors(host_owner, chains)
            seen_here: set[tuple[str, str]] = set()

            def add(target: str, kind: str, label: str) -> None:
                if (target, label) in seen_here:
                    return
                seen_here.add((target, label))
                calls[holder].append({"to": target, "kind": kind, "line": i, "via": label})

            for ns, meth in RE_QUAL.findall(line):
                if ns in NATIVE_NS:
                    add(f"{ns}.{meth}", "native", f"{ns}.{meth}")
                    continue
                # Our own defs are consulted BEFORE the builtin filter. The
                # tree defines KSU::Intem.open, KSU::Nest.open and others whose
                # names collide with Kernel's; filtering first drops the only
                # edge that connects the toolbar table to those dialogs.
                hit = next((by_owner[o][meth] for o in ancestors(ns, chains)
                            if meth in by_owner.get(o, {})), None)
                if hit:
                    add(hit, "qual", f"{ns}.{meth}")
                elif meth in RUBY_BUILTIN:
                    continue
                elif meth in by_name:
                    cands = by_name[meth]
                    if len(cands) == 1:
                        add(cands[0], "qual-mixin", f"{ns}.{meth}")
                    else:
                        add("|".join(cands), "ambig", f"{ns}.{meth}")
                elif meth in NATIVE_METHODS:
                    add(f"(native).{meth}", "native", meth)
                else:
                    unresolved[f"{ns}.{meth}"] += 1

            recv_names.update(RE_RECV.findall(line))

            for meth in RE_CHAIN.findall(line):
                cands = by_name.get(meth, [])
                if len(cands) == 1 and meth not in RUBY_BUILTIN:
                    add(cands[0], "chain", meth)

            # `self.class.foo` inside an instance method reaches the class
            # methods of the very class the method lives in -- how chontam.rb
            # calls the `class << self` half of chontam/pick.rb.
            for meth in RE_SELFCLASS.findall(line):
                hit = next((by_owner[o][meth] for o in chain
                            if meth in by_owner.get(o, {})), None)
                if not hit and len(by_name.get(meth, [])) == 1:
                    hit = by_name[meth][0]
                if hit:
                    add(hit, "self-class", f"self.class.{meth}")

            stripped = RE_SELFCLASS.sub(" ", RE_QUAL.sub(" ", line))
            for meth in RE_BARE_PAREN.findall(stripped):
                if meth in KEYWORD:
                    continue
                if meth in NATIVE_METHODS:
                    add(f"(native).{meth}", "native", meth)
                    continue
                hit = next((by_owner[o][meth] for o in chain if meth in by_owner.get(o, {})), None)
                if hit:
                    add(hit, "bare", meth)
                elif meth in RUBY_BUILTIN:
                    continue
                elif meth in by_name:
                    cands = by_name[meth]
                    add(cands[0] if len(cands) == 1 else "|".join(cands),
                        "bare" if len(cands) == 1 else "ambig", meth)
                else:
                    unresolved[meth] += 1
            # Paren-less calls are only trusted inside the owner's own chain;
            # anywhere else the token is far more likely to be a local read.
            # No builtin filter here: this branch only accepts a name the
            # enclosing chain actually defines, and when it does, Ruby's own
            # lookup picks ours over Kernel's. Filtering first lost every
            # `data = load` in system/setting.rb -- ten calls to the method
            # right above them.
            for meth in RE_BARE_PLAIN.findall(stripped):
                if meth in KEYWORD:
                    continue
                hit = next((by_owner[o][meth] for o in chain if meth in by_owner.get(o, {})), None)
                if hit and hit != holder:
                    add(hit, "bare", meth)

    return dict(calls), dict(unresolved), recv_names


def find_overrides(defs: dict, chains: dict) -> dict[str, list[str]]:
    """base def -> defs that override it further down a lookup chain.

    KSU::Store#apply_preset is what every caller resolves to, but Chongbay,
    Danhsovan and Xephang each redefine it; at run time those bodies are what
    runs for those tools. Without this link each override reads as dead code,
    and an edit to the base looks safe when three tools have their own copy.
    """
    by_owner: dict[str, dict[str, str]] = defaultdict(dict)
    for did, d in defs.items():
        by_owner[d["owner"]][d["name"]] = did
    out: dict[str, list[str]] = defaultdict(list)
    for did, d in defs.items():
        for anc in ancestors(d["owner"], chains)[1:]:
            base = by_owner.get(anc, {}).get(d["name"])
            if base and base != did:
                out[base].append(did)
                break
    return dict(out)


# ---------------------------------------------------------------------------
# pass 3: seams
# ---------------------------------------------------------------------------
def scan_seams(defs: dict, files_info: dict) -> dict:
    seams: dict[str, list] = {
        "commands": [], "callbacks": [], "exec_js": [], "settings": [],
        "attributes": [], "native": [], "su_callbacks": [], "dialogs": [],
    }
    owner_of: dict[str, list[tuple[int, int, str]]] = {}
    for r, info in files_info.items():
        owner_of[r] = sorted((defs[d]["line"], defs[d]["end"], d) for d in info["defs"])

    def holder(r: str, i: int) -> str:
        return next((d for a, b, d in owner_of[r] if a < i <= b), f"{r} (than module)")

    for r, info in files_info.items():
        for i, line in enumerate(info["raw"].splitlines(), 1):
            for name in RE_CALLBACK.findall(line):
                seams["callbacks"].append({"name": name, "file": r, "line": i,
                                           "in": holder(r, i)})
            for arg in RE_EXEC_JS.findall(line):
                # Most call sites pass a variable built elsewhere, so there is
                # no JS name to read on this line; those are recorded as
                # "(dong)" rather than dropped -- a dynamic script is exactly
                # the kind of seam a reader must not assume is absent.
                names = [n for n in RE_JS_FN.findall(arg)
                         if n not in ("if", "execute_script")]
                for n in names or ["(dong)"]:
                    seams["exec_js"].append({"js": n, "file": r, "line": i,
                                             "in": holder(r, i)})
            for how, key in RE_SET_KEY.findall(line):
                seams["settings"].append({"key": key, "how": how, "file": r,
                                          "line": i, "in": holder(r, i)})
            for how, dic, key in RE_ATTR.findall(line):
                seams["attributes"].append({"dict": dic, "key": key or "(bien)",
                                            "how": how, "file": r, "line": i,
                                            "in": holder(r, i)})
            if RE_DIALOG.search(line):
                seams["dialogs"].append({"file": r, "line": i, "in": holder(r, i)})

    for did, d in defs.items():
        if d["name"] in SU_CALLBACKS:
            seams["su_callbacks"].append({"name": d["name"], "def": did,
                                          "file": d["file"], "line": d["line"]})

    sym: dict[str, list] = defaultdict(list)
    for r, info in files_info.items():
        for i, line in enumerate(info["code"].splitlines(), 1):
            for name in RE_SYMCALL.findall(line):
                sym[name].append(f"{r}:{i}")
    seams["symbol_dispatch"] = {k: v for k, v in sorted(sym.items()) if k in
                                {d["name"] for d in defs.values()}}

    # The toolbar table in main.rb is the only place a tool key is bound to the
    # method that starts it. Parsing it is what lets --tinhnang take a key.
    main = files_info.get("ksu_vn/main.rb")
    if main:
        in_data = False
        for i, line in enumerate(main["raw"].splitlines(), 1):
            if "TOOL_DATA = {" in line:
                in_data = True
                continue
            if in_data:
                if line.strip().startswith("}"):
                    in_data = False
                    continue
                m = re.match(r"\s*(\w+):\s*\[(.*)\],?\s*$", line)
                if m:
                    key, body = m.group(1), m.group(2)
                    icon = (re.match(r'\s*"([^"]*)"', body) or [None, None])[1]
                    # Every entry is wrapped in KSU.with_license { ... }; the
                    # wrapper is the same for all 14 and tells a reader
                    # nothing, so it is dropped to expose the real entry.
                    inner = body.replace("KSU.with_license", "")
                    tool = re.search(r"select_tool\((?:KSU::)?(\w+)\)", inner)
                    call = re.search(r"(KSU(?:::\w+)*)\.(\w+)", inner)
                    if tool:
                        entry, kind = f"KSU::{tool.group(1)}", "tool"
                    elif call:
                        entry, kind = f"{call.group(1)}.{call.group(2)}", "dialog"
                    else:
                        entry, kind = "?", "?"
                    seams["commands"].append({"key": key, "icon": icon, "entry": entry,
                                              "kind": kind, "line": i})

    seams["bridge"] = scan_bridge(defs, files_info)
    return seams


# `skp('x', arg)` in a dialog page travels: postMessage -> the relay in
# method/caidat.rb -> the "tool_call" callback -> Settings.on_dialog_action ->
# KSU::<Tool>.handle_action, where a `when "x"` branch finally runs. Nothing in
# the Ruby call graph crosses that gap, so the two ends are matched by name
# here: an action with no branch is a dead button, a branch no page calls is
# dead code, and both are invisible to every other check in tools/.
def scan_bridge(defs: dict, files_info: dict) -> dict:
    pages: dict[str, dict] = {}
    html_dir = ROOT / "ksu_vn" / "html"
    for p in sorted(html_dir.glob("*.html")):
        txt = p.read_text(encoding="utf-8", errors="replace")
        pages[p.stem] = {
            "lines": len(txt.splitlines()),
            "skp": sorted(set(RE_SKP.findall(txt))),
            "tool_call": "tool_call" in txt,
        }

    handlers: dict[str, dict] = {}
    for did, d in defs.items():
        if d["name"] != "handle_action":
            continue
        src = (ROOT / d["file"]).read_text(encoding="utf-8", errors="replace").splitlines()
        body = "\n".join(src[d["line"]: d["end"]])
        acts: set[str] = set()
        for ln in RE_WHEN_LINE.findall(body):
            acts |= set(RE_WHEN_LBL.findall(ln))
        handlers[d["owner"]] = {"def": did, "file": d["file"], "line": d["line"],
                                "actions": sorted(acts)}

    # html stem -> the module whose handle_action serves it. KSU::Nest gets
    # its handler by composition (KSU::Nest.extend(KSU::Launch)), so the name
    # on the left of the arrow is not the module the def lives in.
    pairing = {"nesting": "KSU::Launch", "intem": "KSU::Intem",
               "thongke": "KSU::Thongke", "xuatdxf": "KSU::Xuatdxf"}
    out = {"pages": pages, "handlers": handlers, "pairs": [], "orphans": []}
    for stem, owner in pairing.items():
        page = pages.get(stem, {"skp": []})
        h = handlers.get(owner, {"actions": []})
        js, rb = set(page["skp"]), set(h["actions"])
        out["pairs"].append({"page": f"{stem}.html", "owner": owner,
                             "matched": sorted(js & rb),
                             "js_only": sorted(js - rb), "rb_only": sorted(rb - js)})
        for a in sorted(js - rb):
            out["orphans"].append({"what": a, "side": "js", "page": stem, "owner": owner})
        for a in sorted(rb - js):
            out["orphans"].append({"what": a, "side": "ruby", "page": stem, "owner": owner})
    return out


# ---------------------------------------------------------------------------
def build() -> dict:
    files = [ROOT / "ksu_vn.rb"] + [p for p in R.ruby_files() if p.name != "ksu_vn.rb"]
    files = [p for p in files if p.exists()]
    defs, files_info, mixins, compose, supers, hooks = scan_defs(files)
    chains = build_chains(mixins, compose, supers, hooks)
    calls, unresolved, recv_names = scan_calls(defs, files_info, chains)
    overrides = find_overrides(defs, chains)
    seams = scan_seams(defs, files_info)

    called_by: dict[str, list[str]] = defaultdict(list)
    for src, edges in calls.items():
        for e in edges:
            if e["kind"] == "ambig":
                continue
            if src not in called_by[e["to"]]:
                called_by[e["to"]].append(src)

    for r, info in files_info.items():
        info.pop("raw", None)
        info.pop("code", None)

    return {
        "root": str(ROOT),
        "file_count": len(files),
        "def_count": len(defs),
        "edge_count": sum(len(v) for v in calls.values()),
        "defs": defs,
        "calls": calls,
        "called_by": dict(called_by),
        "mixins": mixins,
        "hooks": hooks,
        "compose": compose,
        "supers": supers,
        "chains": chains,
        "overrides": overrides,
        "recv_names": sorted(recv_names),
        "files": files_info,
        "seams": seams,
        "unresolved": dict(sorted(unresolved.items(), key=lambda x: -x[1])[:60]),
    }


def load() -> dict:
    if not OUT.exists():
        sys.exit("thieu tools/dothi.json -- chay: python tools/dothi.py --dung")
    newest = max((p.stat().st_mtime for p in R.ruby_files()), default=0.0)
    g = json.loads(OUT.read_text(encoding="utf-8"))
    if OUT.stat().st_mtime < newest:
        print("[!] dothi.json cu hon ma nguon -- chay lai: python tools/dothi.py --dung\n")
    return g


# ---------------------------------------------------------------------------
# queries
# ---------------------------------------------------------------------------
def pick(g: dict, needle: str) -> list[str]:
    """Resolve a user-typed name to def ids, exact match winning."""
    if needle in g["defs"]:
        return [needle]
    low = needle.lower()
    exact = [d for d in g["defs"] if g["defs"][d]["name"].lower() == low]
    if exact:
        return exact
    return sorted(d for d in g["defs"] if low in d.lower())


def where(g: dict, did: str) -> str:
    d = g["defs"].get(did)
    return f"{d['file']}:{d['line']}" if d else "(ngoai cay)"


def walk(g: dict, start: list[str], key: str, depth: int) -> dict[str, int]:
    seen: dict[str, int] = {}
    q = deque((s, 0) for s in start)
    while q:
        cur, lv = q.popleft()
        if cur in seen or lv > depth:
            continue
        seen[cur] = lv
        nxt = g[key].get(cur, [])
        for n in nxt:
            tgt = n["to"] if isinstance(n, dict) else n
            if isinstance(n, dict) and n["kind"] == "ambig":
                continue
            q.append((tgt, lv + 1))
    return seen


def show_tree(g: dict, roots: list[str], key: str, depth: int, label: str) -> None:
    for root in roots:
        print(f"\n=== {label}: {root}   [{where(g, root)}]")
        reach = walk(g, [root], key, depth)
        reach.pop(root, None)
        if not reach:
            print("    (khong co)")
            continue
        per: dict[int, list[str]] = defaultdict(list)
        for k, v in reach.items():
            per[v].append(k)
        for lv in sorted(per):
            print(f"  -- cap {lv} ({len(per[lv])}) --")
            for k in sorted(per[lv]):
                print(f"    {k:<58} {where(g, k)}")
        byfile = Counter(g["defs"][k]["file"] for k in reach if k in g["defs"])
        print(f"  -- {len(reach)} def, {len(byfile)} file --")
        for f, n in byfile.most_common():
            print(f"    {n:4d}  {f}")


def path_between(g: dict, a: str, b: str) -> list[str] | None:
    prev: dict[str, str] = {a: ""}
    q = deque([a])
    while q:
        cur = q.popleft()
        if cur == b:
            out = [cur]
            while prev[out[-1]]:
                out.append(prev[out[-1]])
            return list(reversed(out))
        for e in g["calls"].get(cur, []):
            if e["kind"] == "ambig" or e["to"] in prev:
                continue
            prev[e["to"]] = cur
            q.append(e["to"])
    return None


def file_card(g: dict, frag: str) -> None:
    hits = [f for f in g["files"] if frag in f]
    if not hits:
        sys.exit(f"khong co file nao khop '{frag}'")
    for r in hits:
        info = g["files"][r]
        print(f"\n=== {r}   ({info['lines']} dong)")
        if info["namespaces"]:
            print("  namespace: " + ", ".join(
                f"{n['kind']} {n['name']}" + (f" < {n['super']}" if n["super"] else "")
                for n in info["namespaces"]))
        if info["includes"]:
            print("  include:   " + ", ".join(f"{m['how']} {m['what']}" for m in info["includes"]))
        if info["consts"]:
            print("  hang:      " + ", ".join(c["name"] for c in info["consts"][:12]))
        if info["html"]:
            print("  html:      " + ", ".join(info["html"]))
        mine = set(info["defs"])
        out_files, in_files = Counter(), Counter()
        for d in mine:
            for e in g["calls"].get(d, []):
                t = g["defs"].get(e["to"])
                if t and t["file"] != r:
                    out_files[t["file"]] += 1
        for d, callers in g["called_by"].items():
            if d in mine:
                for c in callers:
                    cf = g["defs"].get(c, {}).get("file")
                    if cf and cf != r:
                        in_files[cf] += 1
        print(f"\n  -- {len(mine)} def --")
        for d in sorted(mine, key=lambda x: g["defs"][x]["line"]):
            n_in = len(g["called_by"].get(d, []))
            print(f"    {g['defs'][d]['line']:5d}  {d:<52} <- {n_in}")
        print("\n  -- phu thuoc RA (file nay goi ai) --")
        for f, n in out_files.most_common(12):
            print(f"    {n:4d}  {f}")
        print("  -- phu thuoc VAO (ai goi file nay) --")
        for f, n in in_files.most_common(12):
            print(f"    {n:4d}  {f}")


def feature(g: dict, key: str) -> None:
    """One tool's own code, and the line between it and the shared layer.

    The transitive closure is useless here: every tool reaches utils/, utils/
    reaches almost everything, and the answer comes back as "72 of 89 files".
    What a change actually needs is the boundary -- the files this tool owns
    outright, then the one-hop dependencies it leans on and must not break.
    """
    cmds = {c["key"]: c for c in g["seams"]["commands"]}
    if key not in cmds:
        sys.exit("khoa khong co. Cac khoa: " + ", ".join(sorted(cmds)))
    c = cmds[key]
    icon = c["icon"]
    print(f"=== tinh nang {key}   vao tu {c['entry']}  ({c['kind']})")
    print(f"    icon ksu_vn/icons/{icon}.svg | trang ksu_vn/html/{icon}.html")

    own_files = sorted(f for f in g["files"]
                       if f"/{icon}.rb" in f or f"/{icon}/" in f)
    own_defs = [d for d in g["defs"] if g["defs"][d]["file"] in own_files]
    print(f"\n  -- {len(own_files)} file rieng, {len(own_defs)} def --")
    for f in own_files:
        print(f"    {g['files'][f]['lines']:5d} dong  {f}")

    outside = Counter()
    for d in own_defs:
        for e in g["calls"].get(d, []):
            t = g["defs"].get(e["to"])
            if e["kind"] == "native":
                outside[e["via"]] += 1
            elif t and t["file"] not in own_files:
                outside[e["to"]] += 1
    print(f"\n  -- dua vao {len(outside)} thu ben ngoai (1 buoc) --")
    for t, n in outside.most_common(25):
        print(f"    {n:4d}  {t:<48} {where(g, t)}")

    inbound = Counter()
    for d in own_defs:
        for caller in g["called_by"].get(d, []):
            cf = g["defs"].get(caller, {}).get("file")
            if cf and cf not in own_files:
                inbound[caller] += 1
    print(f"\n  -- {len(inbound)} cho ben ngoai goi NGUOC vao tinh nang nay --")
    for t, n in inbound.most_common(15):
        print(f"    {n:4d}  {t:<48} {where(g, t)}")
    if not inbound:
        print("    (khong co -- tinh nang nay khong ai dung lai)")

    s = g["seams"]
    keys = sorted({e["key"] for e in s["settings"] if e["file"] in own_files})
    attrs = sorted({f"{e['dict']}/{e['key']}" for e in s["attributes"]
                    if e["file"] in own_files})
    print(f"\n  -- {len(keys)} khoa settings doc/ghi o day --")
    print("    " + (", ".join(keys) or "(khong co)"))
    print(f"  -- {len(attrs)} khoa thuoc tinh model --")
    print("    " + (", ".join(attrs) or "(khong co)"))
    pr = next((p for p in s["bridge"]["pairs"] if p["page"] == f"{icon}.html"), None)
    if pr:
        print(f"  -- {len(pr['matched'])} hanh dong tu trang {pr['page']} --")
        print("    " + ", ".join(pr["matched"]))


def seams_report(g: dict) -> None:
    s = g["seams"]
    print(f"=== {len(s['commands'])} lenh thanh cong cu (ksu_vn/main.rb TOOL_DATA)")
    for c in s["commands"]:
        print(f"  {c['key']:<14} {str(c['icon']):<12} {c['kind']:<7} -> {c['entry']}")

    b = s["bridge"]
    print("\n=== cau noi trang HTML <-> Ruby  (skp('x')  <->  when \"x\")")
    for pr in b["pairs"]:
        h = b["handlers"].get(pr["owner"], {})
        print(f"  {pr['page']:<16} {pr['owner']:<16} {h.get('file', '?')}:{h.get('line', '?')}")
        print(f"      khop ({len(pr['matched'])}): {', '.join(pr['matched'])}")
        if pr["js_only"]:
            print(f"      [!] JS goi, Ruby khong co nhanh: {', '.join(pr['js_only'])}")
        if pr["rb_only"]:
            print(f"      [!] Ruby co nhanh, khong trang nao goi: {', '.join(pr['rb_only'])}")
    plain = [k for k, v in b["pages"].items() if not v["tool_call"]]
    print(f"  {len(plain)} trang chi la tab cai dat (khong co skp/tool_call): "
          + ", ".join(sorted(plain)))

    print(f"\n=== {len(s['callbacks'])} callback HtmlDialog (JS -> Ruby)")
    for c in sorted(s["callbacks"], key=lambda x: (x["file"], x["line"])):
        print(f"  {c['name']:<26} {c['file']}:{c['line']}  trong {c['in']}")

    js = Counter(e["js"] for e in s["exec_js"] if e["js"])
    print(f"\n=== {len(js)} ham JS duoc Ruby goi (execute_script)")
    for fn, n in js.most_common(30):
        print(f"  {n:4d}  {fn}")

    keys = defaultdict(lambda: {"r": 0, "w": 0, "sites": set()})
    for e in s["settings"]:
        keys[e["key"]]["w" if e["how"].startswith("set") else "r"] += 1
        keys[e["key"]]["sites"].add(e["file"])
    print(f"\n=== {len(keys)} khoa settings.json")
    for k, v in sorted(keys.items(), key=lambda x: -(x[1]['r'] + x[1]['w']))[:40]:
        print(f"  doc {v['r']:3d} ghi {v['w']:3d}  {k:<30} {', '.join(sorted(v['sites'])[:3])}")

    attrs = defaultdict(lambda: {"r": 0, "w": 0, "sites": set()})
    for e in s["attributes"]:
        attrs[(e["dict"], e["key"])]["w" if e["how"].startswith("set") else "r"] += 1
        attrs[(e["dict"], e["key"])]["sites"].add(e["file"])
    print(f"\n=== {len(attrs)} khoa thuoc tinh gan tren model SketchUp")
    for (d, k), v in sorted(attrs.items(), key=lambda x: -(x[1]['r'] + x[1]['w']))[:40]:
        print(f"  doc {v['r']:3d} ghi {v['w']:3d}  {d}/{k:<24} {', '.join(sorted(v['sites'])[:3])}")

    nat = Counter()
    for src, edges in g["calls"].items():
        for e in edges:
            if e["kind"] == "native":
                nat[e["via"]] += 1
    print(f"\n=== {len(nat)} loi goi vao nhan native ksu.so")
    for k, n in nat.most_common():
        print(f"  {n:4d}  {k}")

    per = defaultdict(list)
    for c in s["su_callbacks"]:
        per[g["defs"][c["def"]]["owner"]].append(c["name"])
    print(f"\n=== {len(per)} lop co callback cua SketchUp Tool")
    for owner, names in sorted(per.items()):
        print(f"  {owner:<26} {', '.join(sorted(names))}")

    print(f"\n=== {len(s['dialogs'])} cho tao HtmlDialog")
    for d in s["dialogs"]:
        print(f"  {d['file']}:{d['line']}  trong {d['in']}")

    # The license check is smeared on purpose: one piece per module, almost
    # always the LAST def in the file, in modules whose names have nothing to
    # do with licensing. Listing it in one place is the only way a reader sees
    # the shape instead of meeting machine_id halfway down a mirroring file.
    lic = [(d, v) for d, v in g["defs"].items()
           # `(?<![a-z])id_cache` and not `id_cache`: drag.rb's grid_cache
           # helpers are not part of this and reading them as licensing sends
           # the next reader down the wrong file.
           if re.search(r"licen[cs]|machine_id|id_hash|(?<![a-z])id_cache"
                        r"|activate_key|deactivate_key|deactivate_now"
                        r"|hardware|serial", v["name"], re.I)]
    tail = [d for d, v in lic
            if v["line"] > g["files"][v["file"]]["lines"] - 12]
    print(f"\n=== {len(lic)} def thuoc mach kiem BAN QUYEN, "
          f"nam rai o {len({v['file'] for _, v in lic})} file "
          f"({len(tail)} cai la def CUOI file)")
    for d, v in sorted(lic, key=lambda x: (x[1]["file"], x[1]["line"])):
        mark = "  <- cuoi file" if d in tail else ""
        print(f"  {v['file']}:{v['line']:<5} {v['name']:<22}{mark}")


def hotspots(g: dict) -> None:
    print("=== def bi goi tu nhieu noi nhat (sua = rui ro cao nhat)")
    rank = sorted(g["called_by"].items(), key=lambda x: -len(x[1]))
    for did, callers in rank[:30]:
        files = len({g["defs"][c]["file"] for c in callers if c in g["defs"]})
        print(f"  {len(callers):4d} loi goi / {files:2d} file   {did:<52} {where(g, did)}")

    # Everything that is reachable WITHOUT a call edge has to come off this
    # list first, or it reads as 40 false alarms and nobody reads it twice:
    # SketchUp calls the Tool callbacks, `.new` calls initialize, and
    # respond_to?/send reach a name the graph cannot follow.
    cb = {c["def"] for c in g["seams"]["su_callbacks"]}
    sym = set(g["seams"].get("symbol_dispatch", {}))
    recv = set(g.get("recv_names", []))
    overridden = {base for base, kids in g.get("overrides", {}).items() for _ in kids}
    is_override = {k for kids in g.get("overrides", {}).values() for k in kids}

    rest, via_recv, via_over = [], [], []
    for d, v in g["defs"].items():
        if g["called_by"].get(d) or d in cb or v["name"] in sym:
            continue
        if v["owner"] in ("KSU", "(than module)"):
            continue
        if d in is_override:
            via_over.append(d)
        elif v["name"] in recv:
            via_recv.append(d)
        else:
            rest.append(d)

    print(f"\n=== {len(via_over)} def de len mot def KHAC da duoc goi "
          "(chay khi self la lop con -- khong phai ma chet)")
    for d in sorted(via_over)[:12]:
        base = next(b for b, k in g["overrides"].items() if d in k)
        print(f"  {d:<50} de len {base}")
    print(f"\n=== {len(via_recv)} def chi dat toi qua receiver dong "
          "(@x.ten / bien.ten -- do thi khong lan duoc)")
    for d in sorted(via_recv)[:12]:
        print(f"  {d:<58} {where(g, d)}")
    print(f"\n=== {len(rest)} def KHONG co loi goi nao duoi bat ky dang nao "
          "(ung vien ma chet that su)")
    for d in sorted(rest):
        print(f"  {d:<58} {where(g, d)}")
    _ = overridden

    print("\n=== goi mo ho (mot ten, nhieu def) -- do thi KHONG ve canh o day")
    amb = Counter()
    for src, edges in g["calls"].items():
        for e in edges:
            if e["kind"] == "ambig":
                amb[e["via"]] += 1
    for k, n in amb.most_common(25):
        print(f"  {n:4d}  {k}")


def main() -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--dung", action="store_true", help="dung lai tools/dothi.json")
    ap.add_argument("--ai-goi", metavar="TEN", help="ai goi den TEN (de quy)")
    ap.add_argument("--goi", metavar="TEN", help="TEN goi den nhung gi (de quy)")
    ap.add_argument("--duong", nargs=2, metavar=("A", "B"), help="mot duong goi tu A toi B")
    ap.add_argument("--tinhnang", metavar="KHOA", help="lat cat mot cong cu")
    ap.add_argument("--file", metavar="DUONGDAN", help="the cua mot file")
    ap.add_argument("--seam", action="store_true", help="moi duong noi ra ngoai cay Ruby")
    ap.add_argument("--diem-nong", action="store_true", help="def nhieu nguoi goi / ma chet / mo ho")
    ap.add_argument("--tim", metavar="CHUOI", help="tim def theo manh ten")
    ap.add_argument("--sau", type=int, default=2, metavar="N", help="do sau cho --ai-goi/--goi")
    a = ap.parse_args()

    if a.dung:
        g = build()
        OUT.write_text(json.dumps(g, indent=1, ensure_ascii=False), encoding="utf-8")
        print(f"file={g['file_count']}  def={g['def_count']}  canh={g['edge_count']}")
        print(f"lenh={len(g['seams']['commands'])}  callback={len(g['seams']['callbacks'])}  "
              f"khoa-settings={len({e['key'] for e in g['seams']['settings']})}  "
              f"khoa-attr={len({(e['dict'], e['key']) for e in g['seams']['attributes']})}")
        print(f"-> {OUT.relative_to(ROOT).as_posix()}")
        if g["unresolved"]:
            top = list(g["unresolved"].items())[:8]
            print("ten khong phan giai duoc (API Ruby/SketchUp la binh thuong): "
                  + ", ".join(f"{k}x{v}" for k, v in top))
        return 0

    g = load()
    if a.tim:
        hits = pick(g, a.tim)
        for d in hits[:60]:
            print(f"  {d:<58} {where(g, d)}  <-{len(g['called_by'].get(d, []))}")
        print(f"  ({len(hits)} ket qua)")
    elif a.ai_goi:
        show_tree(g, pick(g, a.ai_goi), "called_by", a.sau, "AI GOI")
    elif a.goi:
        show_tree(g, pick(g, a.goi), "calls", a.sau, "GOI GI")
    elif a.duong:
        aa, bb = pick(g, a.duong[0]), pick(g, a.duong[1])
        for raw, hit in ((a.duong[0], aa), (a.duong[1], bb)):
            if not hit:
                print(f"khong co def nao khop '{raw}' -- thu: "
                      f"python tools/dothi.py --tim {raw}")
        if not aa or not bb:
            return 1
        p = path_between(g, aa[0], bb[0])
        if not p:
            print(f"khong co duong goi tu {aa[0]} toi {bb[0]}")
            return 1
        for i, n in enumerate(p):
            print(f"  {'  ' * i}{'-> ' if i else ''}{n}   [{where(g, n)}]")
    elif a.tinhnang:
        feature(g, a.tinhnang)
    elif a.file:
        file_card(g, a.file)
    elif a.seam:
        seams_report(g)
    elif a.diem_nong:
        hotspots(g)
    else:
        ap.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
