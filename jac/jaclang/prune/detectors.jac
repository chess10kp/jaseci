import os;
import re;
import from typing { cast }

import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.finding { Finding, Evidence, Polarity }
import from jaclang.prune.veto { VetoIndex }


glob _INLINE_MAX_STMTS = 3,
     _SKIP_NAMES = {"self", "super", "init", "postinit"},
     _DETECTABLE_KINDS = {
         "variable",
         "mod_var",
         "ability",
         "method",
         "object",
         "node",
         "edge",
         "walker",
         "enum"
     },
     _PRIVATE_ACCESS = {"private", "protected"},
     _SPLIT_MIN_CLUSTER = 2,
     _SPLIT_MIN_CLUSTERS = 2,
     _MERGE_MIN_CROSS = 3;


def _is_dunder(name: str) -> bool {
    return name.startswith("__") and name.endswith("__");
}


glob _PROBE_EXCEPTIONS = ("ImportError", "ModuleNotFoundError", "Exception");


def _read_source(path: str) -> str {
    try {
        with open(path, "r", encoding="latin-1") as f {
            return f.read();
        }
    } except Exception {
        return "";
    }
}


def _match_brace(text: str, open_idx: int) -> int {
    depth = 0;
    i = open_idx;
    n = len(text);
    while i < n {
        ch = text[i];
        if ch == "{" {
            depth += 1;
        } elif ch == "}" {
            depth -= 1;
            if depth == 0 {
                return i;
            }
        }
        i += 1;
    }
    return -1;
}


def _has_probe_except(text: str, close_idx: int) -> bool {
    n = len(text);
    k = close_idx + 1;
    while True {
        while k < n and text[k] in " \t\r\n" {
            k += 1;
        }
        if not text.startswith("except", k) {
            return False;
        }
        brace = text.find("{", k);
        if brace == -1 {
            return False;
        }
        header = text[k + len("except"):brace];
        if header.strip() == "" {
            return True;
        }
        for exc in _PROBE_EXCEPTIONS {
            if exc in header {
                return True;
            }
        }
        eclose = _match_brace(text, brace);
        if eclose == -1 {
            return False;
        }
        k = eclose + 1;
    }
    return False;
}


def _in_probe_guard(text: str, stmt_pos: int) -> bool {
    if not text {
        return False;
    }
    n = len(text);
    search_from = 0;
    while True {
        idx = text.find("try", search_from);
        if idx == -1 {
            break;
        }
        search_from = idx + 3;

        if idx > 0 and (text[idx - 1].isalnum() or text[idx - 1] == "_") {
            continue;
        }
        after = idx + 3;
        if after < n and (text[after].isalnum() or text[after] == "_") {
            continue;
        }
        j = after;
        while j < n and text[j] in " \t\r\n" {
            j += 1;
        }
        if j >= n or text[j] != "{" {
            continue;
        }
        close = _match_brace(text, j);
        if close == -1 {
            continue;
        }
        if not (j < stmt_pos and stmt_pos < close) {
            continue;
        }
        if _has_probe_except(text, close) {
            return True;
        }
    }
    return False;
}


glob _TYPE_PREV = {":", "[", "|", ">"},
     _TYPE_NEXT = {"]", "|"},
     _NOISE_RE: any = re.compile(
         r"(?s)'''.*?'''|\"\"\".*?\"\"\"|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|#[^\n]*"
     );


def _side_effect_import(
    item_name: str, resolved_path: str, is_from: bool, module_leaves: set
) -> bool {
    leaf = item_name.rsplit(".", 1)[-1];
    if not is_from {
        return ("." in item_name) or (leaf in module_leaves);
    }
    if leaf in module_leaves {
        return True;
    }
    if not resolved_path {
        return False;
    }
    base = os.path.basename(resolved_path);
    if base == f"{item_name}.jac" {
        return True;
    }
    if base == "__init__.jac" {
        return os.path.basename(os.path.dirname(resolved_path)) == item_name;
    }
    return False;
}


def _used_as_type(name: str, text: str) -> bool {
    if not name or not text {
        return False;
    }
    stripped = _NOISE_RE.sub(" ", text);
    n = len(stripped);
    pat = re.compile(r"(?<![\w.])" + re.escape(name) + r"(?![\w])");
    for m in pat.finditer(stripped) {
        p = m.start() - 1;
        while p >= 0 and stripped[p] in " \t" {
            p -= 1;
        }
        prev = stripped[p] if p >= 0 else "";
        q = m.end();
        while q < n and stripped[q] in " \t" {
            q += 1;
        }
        nxt = stripped[q] if q < n else "";
        if prev in _TYPE_PREV or nxt in _TYPE_NEXT {
            return True;
        }
    }
    return False;
}


def _symbol_finding(
    detector: str,
    d: dict,
    message: str,
    veto: VetoIndex,
    evidence: list[Evidence],
    kind: str = "",
    name: str = "",
    access: str = "",
    citations: list[str] | None = None,
    related: list[str] | None = None,
    plan_meta: dict | None = None
) -> Finding {
    nm = name or str(d["name"]);
    kd = kind or str(d["kind"]);
    mod = str(d["module_path"]);
    f = Finding(
        detector=detector,
        symbol_id=str(d["id"]),
        name=nm,
        module_path=mod,
        kind=kd,
        message=message,
        pos_start=int(d["decl_pos_start"]),
        pos_end=int(d["decl_pos_end"]),
        line=int(d["decl_line"]),
        access=access or str(d["access"]),
        scope_chain=str(d["scope_chain"]),
        citations=citations if citations is not None else [],
        related=related if related is not None else [],
        plan_meta=plan_meta if plan_meta is not None else {}
    );
    for ev in evidence {
        f.add(ev);
    }
    for ev in veto.check_symbol(nm, mod) {
        f.add(ev);
    }
    return f;
}


def detect_unused_imports(store: FactStore, veto: VetoIndex) -> list[Finding] {
    out: list[Finding] = [];
    src_cache: dict = {};
    module_leaves = store.module_leaf_names();
    for item in store.unused_import_items() {
        d: any = item;
        name = str(d["item_name"]);
        alias = str(d["alias"]);
        mod = str(d["module_path"]);

        if os.path.basename(mod) == "__init__.jac" {
            continue;
        }
        f = Finding(
            detector="unused-imports",
            symbol_id=str(d["resolved_id"]),
            name=name,
            module_path=mod,
            kind="import",
            message=f"import '{alias or name}' is never used in this module",
            pos_start=int(d["pos_start"]),
            pos_end=int(d["pos_end"]),
            line=int(d["line"]),
            plan_meta={
                "stmt_pos_start": int(d["stmt_pos_start"]),
                "stmt_pos_end": int(d["stmt_pos_end"]),
                "n_items": int(d["n_items"]),
                "is_from": bool(d["is_from"])
            }
        );
        f.add(
            Evidence(
                kind="zero-refs",
                polarity=Polarity.SUPPORTS,
                detail="0 references to the imported symbol"
            )
        );

        if mod not in src_cache {
            src_cache[mod] = _read_source(mod);
        }
        if _in_probe_guard(str(src_cache[mod]), int(d["stmt_pos_start"])) {
            f.add(
                Evidence(
                    kind="probe-import",
                    polarity=Polarity.VETOES,
                    detail="import sits inside a try/except importability guard (probe import)"
                )
            );
        }
        if _side_effect_import(
            name, str(d["resolved_path"]), bool(d["is_from"]), module_leaves
        ) {
            f.add(
                Evidence(
                    kind="side-effect-import",
                    polarity=Polarity.VETOES,
                    detail="module imported for import-time side effects (registration/plugin), not a used name binding"
                )
            );
        }
        if _used_as_type(alias or name, str(src_cache[mod])) {
            f.add(
                Evidence(
                    kind="signature-type-use",
                    polarity=Polarity.VETOES,
                    detail=f"'{alias
                    or name}' appears in a type-annotation position (likely a decl-signature use the ref extractor missed)"
                )
            );
        }
        for ev in veto.check_symbol(alias or name, mod) {
            f.add(ev);
        }
        out.append(f);
    }
    return out;
}


def detect_private_dead_defs(store: FactStore, veto: VetoIndex) -> list[Finding] {
    out: list[Finding] = [];
    for s in store.symbols_for_detection() {
        d: any = s;
        name = str(d["name"]);
        kind = str(d["kind"]);
        if name in _SKIP_NAMES or _is_dunder(name) {
            continue;
        }
        if kind not in _DETECTABLE_KINDS {
            continue;
        }
        if veto.method_dispatched(name, kind) {
            continue;
        }
        if str(d["access"]) not in _PRIVATE_ACCESS {
            continue;
        }
        if store.external_use_count(str(d["id"])) != 0 {
            continue;
        }
        out.append(
            _symbol_finding(
                "private-dead-defs",
                d,
                f"private {kind} '{name}' has no references outside its own definition",
                veto,
                [
                    Evidence(
                        kind="zero-external-refs",
                        polarity=Polarity.SUPPORTS,
                        detail="0 references outside own definition"
                    )
                ]
            )
        );
    }
    return out;
}


def detect_dead_enum_variants(store: FactStore, veto: VetoIndex) -> list[Finding] {
    out: list[Finding] = [];
    for s in store.symbols_for_detection() {
        d: any = s;
        if str(d["kind"]) != "enum_member" {
            continue;
        }
        name = str(d["name"]);
        if _is_dunder(name) {
            continue;
        }
        if store.external_use_count(str(d["id"])) != 0 {
            continue;
        }
        out.append(
            _symbol_finding(
                "dead-enum-variants",
                d,
                f"enum variant '{name}' is never constructed, read, or matched - dead speculative generality",
                veto,
                [
                    Evidence(
                        kind="zero-refs",
                        polarity=Polarity.SUPPORTS,
                        detail="0 references to the enum variant"
                    )
                ]
            )
        );
    }
    return out;
}


def detect_write_only_fields(store: FactStore, veto: VetoIndex) -> list[Finding] {
    out: list[Finding] = [];
    for s in store.symbols_for_detection() {
        d: any = s;
        if str(d["kind"]) != "field" {
            continue;
        }
        name = str(d["name"]);
        if _is_dunder(name) {
            continue;
        }
        if str(d["access"]) not in _PRIVATE_ACCESS {
            continue;
        }
        (reads, writes) = store.field_rw_counts(str(d["id"]));
        if not (writes >= 1 and reads == 0) {
            continue;
        }
        out.append(
            _symbol_finding(
                "write-only-fields",
                d,
                f"private field '{name}' is written ({writes}) but never read",
                veto,
                [
                    Evidence(
                        kind="write-only",
                        polarity=Polarity.SUPPORTS,
                        detail=f"{writes} write(s), 0 reads"
                    )
                ]
            )
        );
    }
    return out;
}


def detect_literal_dead_branches(store: FactStore, veto: VetoIndex) -> list[Finding] {
    out: list[Finding] = [];
    for br in store.literal_branches() {
        d: any = br;
        val = str(d["cond_value"]);
        if val == "false" {
            msg = "`if` condition is literal False - the body is unreachable";
            dead = "body";
        } elif val == "true" {
            if not d["has_else"] {
                continue;
            }
            msg = "`if` condition is literal True - the else branch is unreachable";
            dead = "else";
        } else {
            continue;
        }
        f = Finding(
            detector="literal-dead-branch",
            symbol_id="",
            name=f"if({val})",
            module_path=str(d["module_path"]),
            kind="branch",
            message=msg,
            pos_start=int(d["if_pos_start"]),
            pos_end=int(d["if_pos_end"]),
            line=int(d["line"])
        );
        f.add(
            Evidence(
                kind="literal-condition",
                polarity=Polarity.SUPPORTS,
                detail=f"condition is literal {val}; {dead} branch is dead"
            )
        );
        out.append(f);
    }
    return out;
}


def detect_single_caller_inline(store: FactStore, veto: VetoIndex) -> list[Finding] {
    out: list[Finding] = [];
    for s in store.private_callable_bodies() {
        d: any = s;
        name = str(d["name"]);
        kind = str(d["kind"]);
        if name in _SKIP_NAMES or _is_dunder(name) {
            continue;
        }
        stmt_count = int(d["stmt_count"]);
        if stmt_count > _INLINE_MAX_STMTS {
            continue;
        }
        sid = str(d["id"]);
        callers: list[str] = [];
        for c in store.callers_of(sid) {
            if c != sid {
                callers.append(c);
            }
        }
        if len(callers) != 1 {
            continue;
        }
        out.append(
            _symbol_finding(
                "single-caller-inline",
                d,
                f"private {kind} '{name}' has a single caller and a {stmt_count}-statement body - inline and delete",
                veto,
                [
                    Evidence(
                        kind="single-caller",
                        polarity=Polarity.SUPPORTS,
                        detail=f"exactly 1 caller, {stmt_count}-statement body"
                    )
                ],
                citations=["sym:" + sid],
                related=["sym:" + callers[0]]
            )
        );
    }
    return out;
}


glob _TIGHTEN_KINDS = {"mod_var", "ability", "method", "object", "node", "edge"};


def detect_visibility_tightening(store: FactStore, veto: VetoIndex) -> list[Finding] {
    out: list[Finding] = [];
    for s in store.symbols_for_detection() {
        d: any = s;
        name = str(d["name"]);
        kind = str(d["kind"]);
        mod = str(d["module_path"]);
        if name in _SKIP_NAMES or _is_dunder(name) {
            continue;
        }
        if kind not in _TIGHTEN_KINDS {
            continue;
        }
        if veto.method_dispatched(name, kind) {
            continue;
        }
        if str(d["access"]) != "public" {
            continue;
        }
        if os.path.basename(mod) == "__init__.jac" {
            continue;
        }
        sid = str(d["id"]);
        if store.is_reexported(sid) {
            continue;
        }
        if store.cross_module_use_count(sid) != 0 {
            continue;
        }
        internal = store.use_count(sid);
        out.append(
            _symbol_finding(
                "visibility-tightening",
                d,
                f"public {kind} '{name}' has no cross-module references; demote from :pub (or delete if not exported API)",
                veto,
                [
                    Evidence(
                        kind="no-cross-module-refs",
                        polarity=Polarity.SUPPORTS,
                        detail=f"0 references outside module; {internal} in-module use(s)"
                    )
                ],
                access="public",
                citations=["sym:" + sid],
                plan_meta={"internal_uses": internal, "exported": False}
            )
        );
    }
    return out;
}


glob _BLOB_MIN_SIZE = 40,
     _DOC_MIN_LENGTH = 40;


def detect_duplicated_constant_blobs(
    store: FactStore, veto: VetoIndex
) -> list[Finding] {
    out: list[Finding] = [];
    for group in store.duplicated_literals(_BLOB_MIN_SIZE, 2) {
        g: any = group;
        sites = cast(list, g["sites"]);
        value_hash = str(g["value_hash"]);
        kind = str(g["literal_kind"]);
        size = int(g["size"]);
        site_count = len(sites);
        modules: set = {str(s["module_path"]) for s in sites};
        module_count = len(modules);
        related: set = set();
        related_lines: list[str] = [];
        for s in sites {
            oid = str(s["owner_id"]);
            if oid {
                related.add("sym:" + oid);
            }
            related_lines.append(f"{s['module_path']}:{s['line']}");
        }
        first: any = sites[0];
        f = Finding(
            detector="duplicated-constant-blobs",
            symbol_id="",
            name=f"{kind}:{value_hash}",
            module_path=str(first["module_path"]),
            kind="literal",
            message=f"{kind} literal ({size} chars) duplicated across {site_count} sites in {module_count} module(s) - hoist to a shared constant",
            pos_start=int(first["pos_start"]),
            pos_end=int(first["pos_end"]),
            line=int(first["line"]),
            related=sorted(related),
            plan_meta={
                "value_hash": value_hash,
                "size": size,
                "literal_kind": kind,
                "site_count": site_count,
                "module_count": module_count,
                "sites": related_lines
            }
        );
        f.add(
            Evidence(
                kind="duplicate-blob",
                polarity=Polarity.SUPPORTS,
                detail=f"{site_count} occurrences across {module_count} module(s); ~{(
                    site_count - 1
                )} copies removable"
            )
        );
        out.append(f);
    }
    return out;
}


def detect_duplicate_docstrings(store: FactStore, veto: VetoIndex) -> list[Finding] {
    out: list[Finding] = [];
    for group in store.duplicate_docstrings(_DOC_MIN_LENGTH) {
        g: any = group;
        sites = cast(list, g["sites"]);
        text_hash = str(g["text_hash"]);
        length = int(g["length"]);
        kinds = cast(list, g["kinds"]);
        site_count = len(sites);
        modules: set = {str(s["module_path"]) for s in sites};
        module_count = len(modules);
        related: set = set();
        names: list[str] = [];
        for s in sites {
            related.add("sym:" + str(s["symbol_id"]));
            names.append(str(s["name"]));
        }
        namelist = ", ".join(sorted(set(names))[:4]);
        source = "/".join(kinds);
        first: any = sites[0];
        f = Finding(
            detector="duplicate-docstrings",
            symbol_id="",
            name=f"{source}:{text_hash}",
            module_path=str(first["module_path"]),
            kind="docstring",
            message=f"identical {source} text on {site_count} symbols ({namelist}) - likely the same concept implemented twice",
            pos_start=int(first["pos_start"]),
            pos_end=int(first["pos_end"]),
            line=int(first["line"]),
            related=sorted(related),
            plan_meta={
                "text_hash": text_hash,
                "length": length,
                "site_count": site_count,
                "module_count": module_count,
                "kinds": kinds
            }
        );
        f.add(
            Evidence(
                kind="duplicate-doc",
                polarity=Polarity.SUPPORTS,
                detail=f"{site_count} symbols share identical {source} text"
            )
        );
        checked: set = set();
        for s in sites {
            nm = str(s["name"]);
            mp = str(s["module_path"]);
            ck = (nm, mp);
            if ck in checked {
                continue;
            }
            checked.add(ck);
            for ev in veto.check_symbol(nm, mp) {
                f.add(ev);
            }
        }
        out.append(f);
    }
    return out;
}


def _connected_components(nodes: set, adj: dict) -> list[list[str]] {
    seen: set = set();
    comps: list[list[str]] = [];
    for start in sorted(nodes) {
        if start in seen {
            continue;
        }
        comp: list[str] = [];
        stack: list[str] = [start];
        seen.add(start);
        while stack {
            cur = str(stack.pop());
            comp.append(cur);
            for nxt in cast(set, adj.get(cur, set())) {
                n = str(nxt);
                if n not in seen {
                    seen.add(n);
                    stack.append(n);
                }
            }
        }
        comps.append(sorted(comp));
    }
    return comps;
}


def detect_module_cohesion(store: FactStore, veto: VetoIndex) -> list[Finding] {
    out: list[Finding] = [];
    edges = store.symbol_ref_edges();

    intra_adj: dict = {};
    intra_nodes: dict = {};
    intra_count: dict = {};
    cross_count: dict = {};

    def _touch_intra(mod: str) {
        if mod not in intra_adj {
            intra_adj[mod] = {};
            intra_nodes[mod] = set();
            intra_count[mod] = 0;
        }
    }

    for e in edges {
        um = str(e["using_mod"]);
        dm = str(e["used_mod"]);
        ui = str(e["using_id"]);
        di = str(e["used_id"]);
        if um == dm {
            _touch_intra(um);
            adj: any = intra_adj[um];
            if ui not in adj {
                adj[ui] = set();
            }
            if di not in adj {
                adj[di] = set();
            }
            adj[ui].add(di);
            adj[di].add(ui);
            cast(set, intra_nodes[um]).add(ui);
            cast(set, intra_nodes[um]).add(di);
            intra_count[um] = int(intra_count[um]) + 1;
        } else {
            _touch_intra(um);
            _touch_intra(dm);
            pair = (um, dm) if um < dm else (dm, um);
            cross_count[pair] = int(cross_count.get(pair, 0)) + 1;
        }
    }

    for mod_raw in sorted(intra_adj.keys()) {
        mod = str(mod_raw);
        comps = _connected_components(
            cast(set, intra_nodes[mod]), cast(dict, intra_adj[mod])
        );
        clusters = [
            c
            for c in comps
            if len(c) >= _SPLIT_MIN_CLUSTER
        ];
        if len(clusters) < _SPLIT_MIN_CLUSTERS {
            continue;
        }
        sizes = sorted([len(c) for c in clusters], reverse=True);
        related: set = set();
        for c in clusters {
            related.add("sym:" + c[0]);
        }
        f = Finding(
            detector="module-cohesion",
            symbol_id="",
            name=f"split:{mod}",
            module_path=mod,
            kind="module",
            message=f"module '{mod}' has {len(
                clusters
            )} disconnected symbol clusters (sizes {sizes}) - consider splitting along the seam",
            pos_start=0,
            pos_end=0,
            line=1,
            related=sorted(related),
            plan_meta={
                "shape": "split",
                "cluster_count": len(clusters),
                "cluster_sizes": sizes,
                "intra_edges": int(intra_count[mod])
            }
        );
        f.add(
            Evidence(
                kind="module-split",
                polarity=Polarity.SUPPORTS,
                detail=f"{len(
                    clusters
                )} internal clusters with no call/reference edges between them"
            )
        );
        out.append(f);
    }

    for pair in sorted(cross_count.keys()) {
        cross = int(cross_count[pair]);
        if cross < _MERGE_MIN_CROSS {
            continue;
        }
        a = str(pair[0]);
        b = str(pair[1]);
        ia = int(intra_count.get(a, 0));
        ib = int(intra_count.get(b, 0));
        if not (cross > ia and cross > ib) {
            continue;
        }
        f = Finding(
            detector="module-cohesion",
            symbol_id="",
            name=f"merge:{a}|{b}",
            module_path=a,
            kind="module",
            message=f"modules '{a}' and '{b}' are coupled by {cross} cross-references, more than either's internal cohesion ({ia}/{ib}) - consider merging or moving the shared seam",
            pos_start=0,
            pos_end=0,
            line=1,
            related=[f"mod:{a}", f"mod:{b}"],
            plan_meta={
                "shape": "merge",
                "cross_edges": cross,
                "intra_a": ia,
                "intra_b": ib
            }
        );
        f.add(
            Evidence(
                kind="module-merge",
                polarity=Polarity.SUPPORTS,
                detail=f"{cross} cross-module edges vs {ia}/{ib} intra-module edges"
            )
        );
        out.append(f);
    }
    return out;
}


glob DETECTOR_REGISTRY: dict = {
         "unused-imports": detect_unused_imports,
         "private-dead-defs": detect_private_dead_defs,
         "dead-enum-variants": detect_dead_enum_variants,
         "write-only-fields": detect_write_only_fields,
         "literal-dead-branch": detect_literal_dead_branches,
         "single-caller-inline": detect_single_caller_inline,
         "visibility-tightening": detect_visibility_tightening,
         "duplicated-constant-blobs": detect_duplicated_constant_blobs,
         "duplicate-docstrings": detect_duplicate_docstrings,
         "module-cohesion": detect_module_cohesion
     };


def detector_names -> list[str] {
    return list(DETECTOR_REGISTRY.keys());
}


def run_detectors(
    store: FactStore, veto: VetoIndex, recipes: list[str]
) -> list[Finding] {
    out: list[Finding] = [];
    for name in recipes {
        fn = DETECTOR_REGISTRY.get(name);
        if fn is not None {
            out.extend(fn(store, veto));
        }
    }
    return out;
}
