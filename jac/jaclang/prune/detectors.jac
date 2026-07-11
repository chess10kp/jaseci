import os;
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


def detect_unused_imports(store: FactStore, veto: VetoIndex) -> list[Finding] {
    out: list[Finding] = [];
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
        if str(d["access"]) not in _PRIVATE_ACCESS {
            continue;
        }
        if store.external_use_count(str(d["id"])) != 0 {
            continue;
        }
        f = Finding(
            detector="private-dead-defs",
            symbol_id=str(d["id"]),
            name=name,
            module_path=str(d["module_path"]),
            kind=kind,
            message=f"private {kind} '{name}' has no references outside its own definition",
            pos_start=int(d["decl_pos_start"]),
            pos_end=int(d["decl_pos_end"]),
            line=int(d["decl_line"]),
            access=str(d["access"]),
            scope_chain=str(d["scope_chain"])
        );
        f.add(
            Evidence(
                kind="zero-external-refs",
                polarity=Polarity.SUPPORTS,
                detail="0 references outside own definition"
            )
        );
        for ev in veto.check_symbol(name, str(d["module_path"])) {
            f.add(ev);
        }
        out.append(f);
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
        f = Finding(
            detector="dead-enum-variants",
            symbol_id=str(d["id"]),
            name=name,
            module_path=str(d["module_path"]),
            kind="enum_member",
            message=f"enum variant '{name}' is never constructed, read, or matched - dead speculative generality",
            pos_start=int(d["decl_pos_start"]),
            pos_end=int(d["decl_pos_end"]),
            line=int(d["decl_line"]),
            access=str(d["access"]),
            scope_chain=str(d["scope_chain"])
        );
        f.add(
            Evidence(
                kind="zero-refs",
                polarity=Polarity.SUPPORTS,
                detail="0 references to the enum variant"
            )
        );
        for ev in veto.check_symbol(name, str(d["module_path"])) {
            f.add(ev);
        }
        out.append(f);
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
        f = Finding(
            detector="write-only-fields",
            symbol_id=str(d["id"]),
            name=name,
            module_path=str(d["module_path"]),
            kind="field",
            message=f"private field '{name}' is written ({writes}) but never read",
            pos_start=int(d["decl_pos_start"]),
            pos_end=int(d["decl_pos_end"]),
            line=int(d["decl_line"]),
            access=str(d["access"]),
            scope_chain=str(d["scope_chain"])
        );
        f.add(
            Evidence(
                kind="write-only",
                polarity=Polarity.SUPPORTS,
                detail=f"{writes} write(s), 0 reads"
            )
        );
        for ev in veto.check_symbol(name, str(d["module_path"])) {
            f.add(ev);
        }
        out.append(f);
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
        f = Finding(
            detector="single-caller-inline",
            symbol_id=sid,
            name=name,
            module_path=str(d["module_path"]),
            kind=kind,
            message=f"private {kind} '{name}' has a single caller and a {stmt_count}-statement body - inline and delete",
            pos_start=int(d["decl_pos_start"]),
            pos_end=int(d["decl_pos_end"]),
            line=int(d["decl_line"]),
            access=str(d["access"]),
            scope_chain=str(d["scope_chain"]),
            citations=["sym:" + sid],
            related=["sym:" + callers[0]]
        );
        f.add(
            Evidence(
                kind="single-caller",
                polarity=Polarity.SUPPORTS,
                detail=f"exactly 1 caller, {stmt_count}-statement body"
            )
        );
        for ev in veto.check_symbol(name, str(d["module_path"])) {
            f.add(ev);
        }
        out.append(f);
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
        f = Finding(
            detector="visibility-tightening",
            symbol_id=sid,
            name=name,
            module_path=mod,
            kind=kind,
            message=f"public {kind} '{name}' has no cross-module references; demote from :pub (or delete if not exported API)",
            pos_start=int(d["decl_pos_start"]),
            pos_end=int(d["decl_pos_end"]),
            line=int(d["decl_line"]),
            access="public",
            scope_chain=str(d["scope_chain"]),
            citations=["sym:" + sid],
            plan_meta={"internal_uses": internal, "exported": False}
        );
        f.add(
            Evidence(
                kind="no-cross-module-refs",
                polarity=Polarity.SUPPORTS,
                detail=f"0 references outside module; {internal} in-module use(s)"
            )
        );
        for ev in veto.check_symbol(name, mod) {
            f.add(ev);
        }
        out.append(f);
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


def run_detectors(
    store: FactStore, veto: VetoIndex, recipes: list[str]
) -> list[Finding] {
    out: list[Finding] = [];
    for name in recipes {
        if name == "unused-imports" {
            out.extend(detect_unused_imports(store, veto));
        } elif name == "private-dead-defs" {
            out.extend(detect_private_dead_defs(store, veto));
        } elif name == "dead-enum-variants" {
            out.extend(detect_dead_enum_variants(store, veto));
        } elif name == "write-only-fields" {
            out.extend(detect_write_only_fields(store, veto));
        } elif name == "literal-dead-branch" {
            out.extend(detect_literal_dead_branches(store, veto));
        } elif name == "single-caller-inline" {
            out.extend(detect_single_caller_inline(store, veto));
        } elif name == "visibility-tightening" {
            out.extend(detect_visibility_tightening(store, veto));
        } elif name == "duplicated-constant-blobs" {
            out.extend(detect_duplicated_constant_blobs(store, veto));
        } elif name == "duplicate-docstrings" {
            out.extend(detect_duplicate_docstrings(store, veto));
        } elif name == "module-cohesion" {
            out.extend(detect_module_cohesion(store, veto));
        }
    }
    return out;
}
