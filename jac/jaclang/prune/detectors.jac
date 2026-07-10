import os;

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
     _PRIVATE_ACCESS = {"private", "protected"};


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


def run_detectors(
    store: FactStore, veto: VetoIndex, recipes: list[str]
) -> list[Finding] {
    out: list[Finding] = [];
    for name in recipes {
        if name == "unused-imports" {
            out.extend(detect_unused_imports(store, veto));
        } elif name == "private-dead-defs" {
            out.extend(detect_private_dead_defs(store, veto));
        } elif name == "write-only-fields" {
            out.extend(detect_write_only_fields(store, veto));
        } elif name == "literal-dead-branch" {
            out.extend(detect_literal_dead_branches(store, veto));
        } elif name == "single-caller-inline" {
            out.extend(detect_single_caller_inline(store, veto));
        } elif name == "visibility-tightening" {
            out.extend(detect_visibility_tightening(store, veto));
        }
    }
    return out;
}
