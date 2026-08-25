#!/usr/bin/env python3
"""Audit v2: obj decls whose init/postinit (in-obj OR `impl X.init` blocks)
assign self.<f> where <f> not in X's has-block nor inherited base fields."""
import re
import sys
from pathlib import Path

HAS_LIST_RE = re.compile(r'\bhas\b')

def has_names(body: str):
    """Extract all field names from has decl lists (multi-line, comma-separated)."""
    names = set()
    for m in HAS_LIST_RE.finditer(body):
        i = m.end()
        depth = 0
        j = i
        while j < len(body):
            c = body[j]
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
            elif c == ';' and depth == 0:
                break
            j += 1
        seg = body[i:j]
        # items separated by commas at depth 0
        for item in re.split(r',', seg):
            im = re.match(r'\s*([A-Za-z_]\w*)\s*:', item)
            if im:
                names.add(im.group(1))
            else:
                im2 = re.match(r'\s*([A-Za-z_]\w*)\s*\{', item)  # e.g. `has x { getter; }`
                if im2:
                    names.add(im2.group(1))
    return names
SELF_ASSIGN_RE = re.compile(r'self\.([A-Za-z_]\w*)\s*=[^=]')

def brace_block(src: str, open_idx: int) -> tuple[str, int]:
    depth = 0
    i = open_idx
    while i < len(src):
        c = src[i]
        if c == '"':
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

OBJ_RE = re.compile(r'^obj\s+([A-Za-z_]\w*)\s*(?:\(([^)]*)\))?\s*\{|^@\w[\s\S]*?\nobj\s+([A-Za-z_]\w*)\s*(?:\(([^)]*)\))?\s*\{', re.M)

def find_objs(src: str):
    objs = {}
    for m in re.finditer(r'^(?:@[^\n]+\n)*obj\s+([A-Za-z_]\w*)\s*(?:\(([^)]*)\))?\s*\{', src, re.M):
        name = m.group(1)
        bases = [b.strip().split('.')[-1].split(':')[0].strip() for b in (m.group(2) or '').split(',') if b.strip()]
        body, _ = brace_block(src, m.end() - 1)
        objs[name] = {'bases': bases, 'body': body}
    return objs

INIT_HDR_RE = re.compile(r'^(?:impl\s+)?([A-Za-z_]\w*)\.(init|postinit)\s*(?:\([^)]*\))?(?:\s*->\s*[^\{]+)?\{', re.M)

def audit(paths):
    all_objs = {}
    impl_inits = {}  # objname -> [(where, path)]
    for p in paths:
        try:
            src = p.read_text()
        except Exception as e:
            print(f"ERROR read {p}: {e}", file=sys.stderr); continue
        objs = find_objs(src)
        # in-obj init/postinit bodies
        IN_OBJ_INIT_RE = re.compile(r'^\s+(init|postinit)\s*(?:->\s*[^\{]+)?\{', re.M)
        for n, o in objs.items():
            for im in IN_OBJ_INIT_RE.finditer(o['body']):
                ibody, _ = brace_block(o['body'], im.end() - 1)
                for am in SELF_ASSIGN_RE.finditer(ibody):
                    f = am.group(1)
                    rec = all_objs.setdefault(n, {'bases': [], 'body': '', 'extra_has': set()})
                    rec.setdefault('assigned', {}).setdefault(f, []).append(f"{im.group(1)}@{p.name}")
        for n, o in objs.items():
            if n in all_objs:
                all_objs[n]['bases'] = o['bases'] or all_objs[n]['bases']
                # merge has fields from both decl sites
                extra = has_names(o['body'])
                cur = has_names(all_objs[n]['body'])
                merged = cur | extra
                # rebuild body markers via a set stored separately
                all_objs[n]['extra_has'] = all_objs[n].get('extra_has', set()) | extra
            else:
                o['extra_has'] = set()
                all_objs[n] = o
        for im in INIT_HDR_RE.finditer(src):
            name, kind = im.group(1), im.group(2)
            ibody, _ = brace_block(src, im.end() - 1)
            for am in SELF_ASSIGN_RE.finditer(ibody):
                f = am.group(1)
                rec = all_objs.setdefault(name, {'bases': [], 'body': '', 'extra_has': set()})
                rec.setdefault('assigned', {}).setdefault(f, []).append(f"{kind}@{p.name}")
    findings = []
    def has_fields(o, seen=None):
        fields = has_names(o.get('body', '')) | o.get('extra_has', set())
        seen = seen or set()
        for b in o.get('bases', []):
            if b in seen or b not in all_objs:
                continue
            seen.add(b)
            fields |= has_fields(all_objs[b], seen)
        return fields
    for name, o in sorted(all_objs.items()):
        assigned = o.get('assigned', {})
        declared = has_fields(o)
        missing = {f: w for f, w in assigned.items() if f not in declared}
        # exclude private/dunder and known dynamic attrs? report everything; triage later
        if missing:
            findings.append((name, o.get('bases', []), missing, sorted(declared)))
    return findings

def main():
    targets = [Path(p) for p in sys.argv[1:]]
    for name, bases, missing, declared in audit(targets):
        ms = ', '.join(f"{f}[{'/'.join(w)}]" for f, w in missing.items())
        print(f"{name}({','.join(bases)}): undeclared={{{ms}}} has={{{', '.join(declared)}}}")

if __name__ == '__main__':
    main()
