#!/usr/bin/env python3
"""Audit obj decls for init assigning fields not declared in `has`."""
import re
import sys
from pathlib import Path

def strip_comments_strings(src: str) -> str:
    # remove line comments
    src = re.sub(r'#[^\n"]*(?="\s*$)?', '', src)
    # crude string removal: keep it simple - remove quoted strings
    src = re.sub(r'"(?:[^"\\]|\\.)*"', '""', src)
    return src

OBJ_RE = re.compile(r'^obj\s+([A-Za-z_]\w*)\s*(?:\(([^)]*)\))?\s*\{', re.M)
HAS_RE = re.compile(r'\bhas\s+([A-Za-z_]\w*)\s*:')
SELF_ASSIGN_RE = re.compile(r'self\.([A-Za-z_]\w*)\s*=[^=]')

def brace_block(src: str, open_idx: int) -> tuple[str, int]:
    depth = 0
    i = open_idx
    while i < len(src):
        c = src[i]
        if c == '"':
            # skip string
            i += 1
            while i < len(src) and src[i] != '"':
                i += 2 if src[i] == '\\' else 1
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return src[open_idx:i], i
        i += 1
    return src[open_idx:], len(src)

INIT_RE = re.compile(r'\b(init|postinit)\s*(?:->\s*[^\{]+)?\{')

def audit_file(path: Path):
    src = path.read_text()
    findings = []
    # map of all objs in file for inheritance lookup across files handled later
    objs = {}
    spans = []
    for m in OBJ_RE.finditer(src):
        name = m.group(1)
        bases = [b.strip().split('.')[-1] for b in (m.group(2) or '').split(',') if b.strip()]
        body, end = brace_block(src, m.end() - 1)
        objs[name] = {'bases': bases, 'body': body}
        spans.append((name, m.start(), end))
    for name, start, end in spans:
        body = objs[name]['body']
        declared = set(HAS_RE.findall(body))
        assigned = {}
        for im in INIT_RE.finditer(body):
            ibody, _ = brace_block(body, im.end() - 1)
            for am in SELF_ASSIGN_RE.finditer(ibody):
                f = am.group(1)
                assigned.setdefault(f, []).append(im.group(1))
        missing = {f: where for f, where in assigned.items() if f not in declared}
        if missing:
            findings.append({'obj': name, 'bases': objs[name]['bases'], 'missing': missing,
                             'declared': sorted(declared)})
    return findings, objs

def main():
    targets = [Path(p) for p in sys.argv[1:]]
    all_objs = {}
    per_file = {}
    for p in targets:
        try:
            f, objs = audit_file(p)
        except Exception as e:
            print(f"ERROR {p}: {e}", file=sys.stderr)
            continue
        per_file[p] = f
        all_objs.update(objs)
    # resolve inherited fields transitively
    def inherited_fields(name, seen=None):
        seen = seen or set()
        fields = set()
        o = all_objs.get(name)
        if not o or name in seen:
            return fields
        seen.add(name)
        for b in o['bases']:
            fields |= inherited_fields(b, seen)
            bo = all_objs.get(b)
            if bo:
                fields |= set(HAS_RE.findall(bo['body']))
        return fields
    total = 0
    for p, finds in per_file.items():
        for fd in finds:
            inh = inherited_fields(fd['obj'])
            real_missing = {f: w for f, w in fd['missing'].items() if f not in inh}
            if real_missing:
                total += 1
                print(f"{p}:{fd['obj']}({','.join(fd['bases'])}): "
                      f"undeclared={{{', '.join(f'{f}[{w}]' for f,w in real_missing.items())}}} "
                      f"has={{{', '.join(fd['declared'])}}}")
    print(f"--- TOTAL: {total}")

if __name__ == '__main__':
    main()
