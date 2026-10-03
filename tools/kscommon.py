#!/usr/bin/env python3
"""Shared primitives for the KSU de-obfuscation tools.

Every tool here has to answer the same question first: which characters of a
Ruby file are CODE and which are TEXT. Vietnamese strings are full of letters
that look exactly like identifiers, so blanking text is what keeps a rename
from reaching into a dialog caption. These helpers are carried over from the
ZSU toolchain, where each one was added because a specific rename broke.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKG = "ksu_vn"

HEX = re.compile(r"\A_[0-9a-f]{8}\Z")
HEX_ANY = re.compile(r"\b_[0-9a-f]{8}\b")
IDENT = re.compile(r"\A[a-z_][A-Za-z0-9_]*[?!]?\Z")

RUBY_KEYWORDS = {
    "__ENCODING__", "__LINE__", "__FILE__", "BEGIN", "END", "alias", "and",
    "begin", "break", "case", "class", "def", "defined?", "do", "else",
    "elsif", "end", "ensure", "false", "for", "if", "in", "module", "next",
    "nil", "not", "or", "redo", "rescue", "retry", "return", "self", "super",
    "then", "true", "undef", "unless", "until", "when", "while", "yield",
}

# A slash only opens a regex after =~ !~ [ ( or a comma. Anything looser reads
# "2 * Math::PI * i / nv" as one literal and swallows the code between.
_REGEX = re.compile(r"(=~|!~|\[|\(|,)(\s*)/(?:[^/\\\n]|\\.)*/[imxounse]*")
_STR = re.compile(r'"(?:[^"\\\n]|\\.)*"' + r"|'(?:[^'\\\n]|\\.)*'")
_PCTR = re.compile(r"%[rwiqW]?\{[^{}\n]*\}")
_COMMENT = re.compile(r"#.*$", re.M)

# '(?!:)' at the end drops hash labels and keyword arguments: in  tr: @_f88fa20a
# the 'tr' is a LABEL, not a variable. A real variable never sits before a colon.
# The '[A-Za-z0-9_]' in the lookahead forces the identifier to be whole --
# without it the regex backtracks and invents an 'i' out of 'include:'.
_IDENT_PLAIN = re.compile(r"(?<![\w.:@$])([a-z_][A-Za-z0-9_]*)(?![A-Za-z0-9_:])")

_TEXT = re.compile(
    r"(?:=~|!~|\[|\(|,)\s*/(?:[^/\\\n]|\\.)*/[imxounse]*"
    r'|"(?:[^"\\\n]|\\.)*"'
    r"|'(?:[^'\\\n]|\\.)*'"
    r"|#.*$",
    re.M,
)
_INTERP = re.compile(r"#\{(?:[^{}]|\{[^{}]*\})*\}")

_HEREDOC_OPEN = re.compile(r"<<[-~]?['\"]?([A-Z_][A-Z0-9_]*)['\"]?")


def ruby_files(root: Path | None = None) -> list[Path]:
    """Every Ruby file of the plugin, tools/ and test/ excluded."""
    root = root or ROOT
    out = []
    for p in sorted(root.rglob("*.rb")):
        parts = p.relative_to(root).parts
        if parts[0] in ("tools", "test", "port"):
            continue
        out.append(p)
    return out


def strip_heredocs(src: str, keep_lines: bool = False) -> str:
    """Drop heredoc bodies, keeping the #{...} interpolations inside them.

    utils/preset/field.rb embeds HTML and JavaScript in heredocs. The 'b' in
    `var c = b * s;` is JavaScript, not a Ruby variable -- leaving it in makes
    the collision check reject a correct name. The #{...} parts MUST stay:
    those really are Ruby.

    keep_lines=True preserves the line count, replacing a body line with the
    interpolations found on it. Anything that reports line numbers needs that
    mode; the default shifts lines in files that use heredocs.
    """
    out: list[str] = []
    lines = src.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        m = _HEREDOC_OPEN.search(line)
        if not m:
            i += 1
            continue
        tag = m.group(1)
        i += 1
        while i < len(lines) and lines[i].strip() != tag:
            frags = re.findall(r"#\{([^}\n]*)\}", lines[i])
            out.append(" ".join(frags)) if keep_lines else out.extend(frags)
            i += 1
        if i < len(lines):
            out.append(lines[i])
            i += 1
    return "\n".join(out)


# A keyword parameter in a def signature CREATES a local: 'def f(pool: nil)'
# binds 'pool'. _IDENT_PLAIN skips anything before a colon to drop hash labels,
# so it never sees these -- they have to be collected separately.
_DEFLINE = re.compile(r"^\s*def\s+.*$", re.M)
_KWPARAM = re.compile(r"\b([a-z_]\w*):")


def plain_idents(src: str) -> set[str]:
    """Identifiers that really occur, text and heredoc bodies removed."""
    s = strip_heredocs(src)
    s = _REGEX.sub(r"\1\2//", s)
    s = _PCTR.sub('""', s)
    s = _STR.sub('""', s)
    s = _COMMENT.sub("", s)
    out = set(_IDENT_PLAIN.findall(s))
    for line in _DEFLINE.findall(s):
        out |= set(_KWPARAM.findall(line))
    return out


def _blank_heredoc_bodies(src: str) -> str:
    """Blank heredoc bodies in place, keeping #{...} and the exact length.

    utils/preset/field.rb and method/caidat.rb embed whole HTML pages. Left
    visible, that markup reaches the renamer: a word-boundary rename of a short
    name would cut into the Vietnamese captions inside it. Blanking in place,
    rather than dropping the lines, keeps every character offset valid so
    retag() can splice its result straight back into the original source.
    """
    lines = src.split("\n")
    i = 0
    while i < len(lines):
        m = _HEREDOC_OPEN.search(lines[i])
        i += 1
        if not m:
            continue
        tag = m.group(1)
        while i < len(lines) and lines[i].strip() != tag:
            line = lines[i]
            out, at = [], 0
            for iv in _INTERP.finditer(line):
                out.append(" " * (iv.start() - at))
                out.append(iv.group(0))
                at = iv.end()
            out.append(" " * (len(line) - at))
            lines[i] = "".join(out)
            i += 1
        i += 1
    return "\n".join(lines)


# A slash is a regex only where a value cannot already stand: right after an
# operator, an opening bracket, a comma or a keyword. Anywhere else it divides.
_BEFORE_REGEX = re.compile(
    r"(?:[=!]~|[-+*/%|&^<>=,(\[{;:?]|\*\*|&&|\|\||\b(?:and|or|not|if|unless|"
    r"while|until|when|return|case|then|do|else|elsif|in|puts|match|split|"
    r"gsub|sub|scan|grep|index)\b)\s*\Z")


def text_spans(src: str) -> list[tuple[int, int]]:
    """Character spans of src that are TEXT rather than code.

    Regexes cannot do this correctly. A Ruby string may hold #{...}, that
    interpolation holds code, and that code may open another string -- as
    utils/pdf/svg.rb does with "#{i.zero? ? 'm' : 'l'}". Pairing quotes by
    pattern ends the outer literal at the inner quote and reports the code
    between as changed text, which is exactly the false alarm that hides a real
    one. This walks the source once instead, tracking the nesting, and returns
    only the stretches a rename must never touch.

    Covered: double and single quotes, #{...} to any depth, # comments,
    =begin/=end blocks, heredoc bodies (plain and quoted), %w %i %q %Q literals
    and regex literals. Inside an interpolation the scan resumes as code, so
    identifiers there stay visible to the renamer.
    """
    spans: list[tuple[int, int]] = []
    n = len(src)
    i = 0
    at_line_start = True
    pending_heredocs: list[tuple[str, bool]] = []
    prev_code = ""        # code seen on this line, to tell regex from division

    def close(a: int, b: int) -> None:
        if b > a:
            spans.append((a, b))

    while i < n:
        ch = src[i]

        if ch == "\n":
            i += 1
            at_line_start = True
            prev_code = ""
            # Heredoc bodies begin on the line after their opener.
            while pending_heredocs:
                tag, interp = pending_heredocs.pop(0)
                start = i
                while i < n:
                    eol = src.find("\n", i)
                    eol = n if eol < 0 else eol
                    if src[i:eol].strip() == tag:
                        close(start, i)
                        i = eol + 1 if eol < n else n
                        break
                    if interp:
                        # Keep #{...} as code: blank around it instead.
                        j = i
                        for m in _INTERP.finditer(src[i:eol]):
                            close(j, i + m.start())
                            j = i + m.end()
                        close(j, eol)
                        i = eol + 1 if eol < n else n
                        start = i
                    else:
                        i = eol + 1 if eol < n else n
                else:
                    close(start, n)
            continue

        if at_line_start and src.startswith("=begin", i):
            end = src.find("\n=end", i)
            end = n if end < 0 else src.find("\n", end + 1)
            close(i, n if end < 0 else end)
            i = n if end < 0 else end
            continue
        if not ch.isspace():
            at_line_start = False

        if ch == "#":
            eol = src.find("\n", i)
            eol = n if eol < 0 else eol
            close(i, eol)
            i = eol
            continue

        if ch in "\"'":
            i = _scan_quoted(src, i, spans)
            prev_code += "x"
            continue

        if ch == "%" and i + 1 < n and src[i + 1] in "wWiIqQr([{<|!/":
            j = _scan_percent(src, i, spans)
            if j > i:
                i = j
                prev_code += "x"
                continue

        if ch == "<" and src.startswith("<<", i):
            m = re.match(r"<<([-~]?)(['\"]?)([A-Za-z_]\w*)\2", src[i:])
            if m and (m.group(1) or m.group(2) or m.group(3).isupper()):
                pending_heredocs.append((m.group(3), m.group(2) != "'"))
                i += m.end()
                prev_code += "x"
                continue

        # A '/' that opens an expression is a regex, never a division: nothing
        # is there to divide. `def part_re; /-(?:part|#{x})\d+\z/; end` is the
        # shape in utils/sheet/reorder.rb, and reading it as division swallows
        # the rest of the line as text.
        if ch == "/" and (not prev_code.strip()
                          or _BEFORE_REGEX.search(prev_code)):
            j = _scan_regex(src, i, spans)
            if j > i:
                i = j
                prev_code += "x"
                continue

        if ch == "?" and i + 1 < n and src[i + 1].isalnum() and (
                i + 2 >= n or not src[i + 2].isalnum()):
            i += 2                      # ?a character literal
            prev_code += "x"
            continue

        prev_code += ch
        i += 1
    return spans


def _scan_quoted(src: str, i: int, spans: list) -> int:
    """Consume a quoted literal from src[i], recording its text parts."""
    quote = src[i]
    n = len(src)
    j = i + 1
    seg = j
    while j < n:
        c = src[j]
        if c == "\\":
            j += 2
            continue
        if c == quote:
            if seg < j:
                spans.append((seg, j))
            return j + 1
        if c == "#" and quote == '"' and j + 1 < n and src[j + 1] == "{":
            if seg < j:
                spans.append((seg, j))
            j = _skip_interp(src, j + 1, spans)
            seg = j
            continue
        j += 1
    if seg < n:
        spans.append((seg, n))
    return n


def _skip_interp(src: str, i: int, spans: list) -> int:
    """src[i] is '{'. Return the index past its matching '}'.

    A string opened inside the interpolation is scanned as a string, so its own
    braces and quotes cannot end the interpolation early -- and its text is
    still recorded as text. "#{name || "Dang toi uu"}" holds a caption the user
    reads, nested two levels down, and it has to be protected like any other.
    """
    n = len(src)
    depth = 0
    j = i
    while j < n:
        c = src[j]
        if c in "\"'":
            j = _scan_quoted(src, j, spans)
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    return n


_PCT_CLOSE = {"(": ")", "[": "]", "{": "}", "<": ">"}


def _scan_percent(src: str, i: int, spans: list) -> int:
    m = re.match(r"%([wWiIqQr]?)([([{<|!/])", src[i:])
    if not m:
        return i
    kind, opener = m.group(1), m.group(2)
    closer = _PCT_CLOSE.get(opener, opener)
    n = len(src)
    j = i + m.end()
    seg = j
    depth = 1
    while j < n:
        c = src[j]
        if c == "\\":
            j += 2
            continue
        if c == opener and closer != opener:
            depth += 1
        elif c == closer:
            depth -= 1
            if depth == 0:
                if seg < j:
                    spans.append((seg, j))
                return j + 1
        elif c == "#" and kind in ("", "W", "I", "Q", "r") and j + 1 < n and src[j + 1] == "{":
            if seg < j:
                spans.append((seg, j))
            j = _skip_interp(src, j + 1, spans)
            seg = j
            continue
        j += 1
    return i


def _scan_regex(src: str, i: int, spans: list) -> int:
    n = len(src)
    j = i + 1
    seg = j
    in_class = False
    while j < n:
        c = src[j]
        if c == "\\":
            j += 2
            continue
        if c == "\n":
            return i                     # unterminated: it was a division
        if c == "[":
            in_class = True
        elif c == "]":
            in_class = False
        elif c == "#" and j + 1 < n and src[j + 1] == "{":
            if seg < j:
                spans.append((seg, j))
            j = _skip_interp(src, j + 1, spans)
            seg = j
            continue
        elif c == "/" and not in_class:
            if seg < j:
                spans.append((seg, j))
            while j + 1 < n and src[j + 1] in "imxounse":
                j += 1
            return j + 1
        j += 1
    return i


def code_only(src: str) -> str:
    """Same length and line count as src, text blanked, #{...} kept as code."""
    out = list(src)
    for a, b in text_spans(src):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "
    return "".join(out)


def literals(src: str) -> list[str]:
    """The text of src, one piece per uninterrupted stretch.

    What a rename must leave byte-for-byte identical. Comments are included:
    they are text too, and the obfuscator stripped every original one, so every
    comment in the tree was written by a reader and is worth protecting.
    """
    return [src[a:b] for a, b in text_spans(src)]
