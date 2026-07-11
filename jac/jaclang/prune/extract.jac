import hashlib;
import ast;
import from typing { cast }
import jaclang.jac0core.unitree as uni;

import from jaclang.prune.manifest { Manifest, FileRole, role_label }
import from jaclang.prune.bodies { BodyFact, extract_bodies }
import from jaclang.prune.literals { LiteralFact, extract_literals }
import from jaclang.prune.docstrings { DocstringFact, extract_docstrings }


glob EXTRACTOR_VERSION = "2";


obj ModuleFact {
    has path: str,
        module_name: str,
        content_hash: str,
        role: str,
        deps: list[str] = [],
        fact_hash: str = "",
        status: str = "complete",
        error_count: int = 0;
}

obj SymbolFact {
    has id: str,
        module_path: str,
        name: str,
        kind: str,
        access: str,
        imported: bool,
        parent_id: str,
        decl_pos_start: int,
        decl_pos_end: int,
        decl_line: int,
        scope_chain: str;
}

obj ReferenceFact {
    has used_id: str,
        using_id: str,
        module_path: str,
        pos_start: int,
        pos_end: int,
        line: int,
        kind: str,
        id: str = "";

    def postinit {
        if not self.id {
            self.id = ref_fact_id(
                self.used_id,
                self.using_id,
                self.module_path,
                self.kind,
                self.pos_start,
                self.pos_end
            );
        }
    }
}

obj ImportFact {
    has module_path: str,
        item_name: str,
        alias: str,
        resolved_id: str,
        resolved_path: str,
        pos_start: int,
        pos_end: int,
        line: int,
        is_from: bool,
        stmt_pos_start: int = 0,
        stmt_pos_end: int = 0,
        n_items: int = 1;
}

obj FieldAccessFact {
    has field_id: str,
        module_path: str,
        pos_start: int,
        pos_end: int,
        line: int,
        kind: str;
}

obj BranchFact {
    has module_path: str,
        cond_value: str,
        is_elif: bool,
        has_else: bool,
        if_pos_start: int,
        if_pos_end: int,
        cond_pos_start: int,
        cond_pos_end: int,
        line: int;
}


obj FactSet {
    has modules: list[ModuleFact] = [],
        symbols: list[SymbolFact] = [],
        refs: list[ReferenceFact] = [],
        imports: list[ImportFact] = [],
        field_accesses: list[FieldAccessFact] = [],
        branches: list[BranchFact] = [],
        bodies: list[BodyFact] = [],
        literals: list[LiteralFact] = [],
        docstrings: list[DocstringFact] = [];

    def by_module -> dict[str, tuple] {
        out: dict[str, tuple] = {};
        for m in self.modules {
            out[m.path] = ([], [], [], [], [], [], [], []);
        }
        def bucket(path: str) -> (tuple | None) {
            return out.get(path);
        }
        for s in self.symbols {
            b = bucket(s.module_path);
            if b is not None {
                b[0].append(s);
            }
        }
        for r in self.refs {
            b = bucket(r.module_path);
            if b is not None {
                b[1].append(r);
            }
        }
        for im in self.imports {
            b = bucket(im.module_path);
            if b is not None {
                b[2].append(im);
            }
        }
        for fa in self.field_accesses {
            b = bucket(fa.module_path);
            if b is not None {
                b[3].append(fa);
            }
        }
        for br in self.branches {
            b = bucket(br.module_path);
            if b is not None {
                b[4].append(br);
            }
        }
        for bd in self.bodies {
            b = bucket(bd.module_path);
            if b is not None {
                b[5].append(bd);
            }
        }
        for lit in self.literals {
            b = bucket(lit.module_path);
            if b is not None {
                b[6].append(lit);
            }
        }
        for dc in self.docstrings {
            b = bucket(dc.module_path);
            if b is not None {
                b[7].append(dc);
            }
        }
        return out;
    }
}


glob _SCOPE_OWNER_KINDS = {
         "ability",
         "method",
         "constructor",
         "object",
         "node",
         "edge",
         "walker",
         "enum",
         "module"
     },
     _FIELD_KIND = "field";


def _scope_chain(sym: uni.Symbol) -> list[str] {
    chain: list[str] = [];
    pt = sym.parent_tab;
    while pt is not None {
        nm = pt.scope_name;
        if nm == "builtins" {
            break;
        }
        chain.append(nm);
        pt = pt.parent_scope;
    }
    chain.reverse();
    return chain;
}


def stable_symbol_id(sym: uni.Symbol) -> str {
    decl = sym.decl;
    modp = str(decl.loc.mod_path) if decl is not None else "";
    chain = _scope_chain(sym);
    key = "|".join([modp, ">".join(chain), sym.sym_name, str(sym.sym_type)]);
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:16];
}


def ref_fact_id(
    used_id: str,
    using_id: str,
    module_path: str,
    kind: str,
    pos_start: int,
    pos_end: int
) -> str {
    key = "|".join(
        [used_id, using_id, module_path, kind, str(pos_start), str(pos_end)]
    );
    return "ref:" + hashlib.sha256(key.encode("utf-8")).hexdigest()[:16];
}


def dep_fact_id(from_path: str, to_path: str) -> str {
    key = "|".join([from_path, to_path]);
    return "dep:" + hashlib.sha256(key.encode("utf-8")).hexdigest()[:16];
}


def _enclosing_symbol(nd: any) -> any {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, uni.AstSymbolNode) {
            s = cur.sym;
            if s is not None and str(s.sym_type) in _SCOPE_OWNER_KINDS {
                return s;
            }
        }
        cur = cur.parent;
    }
    return None;
}


def _enclosing_scope(nd: any) -> any {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, uni.UniScopeNode) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}


def _local_import_binding(imp: any, local_name: str) -> str {
    scope = _enclosing_scope(imp);
    if scope is None or not local_name {
        return "";
    }
    binding = scope.names_in_scope.get(local_name);
    if binding is not None and binding.decl is not None {
        return stable_symbol_id(cast(uni.Symbol, binding));
    }
    return "";
}


def _is_call_target(use_nd: any) -> bool {
    prev = use_nd;
    p = use_nd.parent;
    while p is not None and type(p).__name__ == "AtomTrailer" {
        prev = p;
        p = p.parent;
    }
    return p is not None and type(p).__name__ == "FuncCall" and p.target is prev;
}


def _ref_kind(use_nd: any) -> str {
    pcf = use_nd.py_ctx_func;
    ctx = pcf.__name__ if pcf is not None else "Load";
    if ctx == "Store" {
        return "write";
    }
    if ctx == "Del" {
        return "del";
    }
    if _is_call_target(use_nd) {
        return "call";
    }
    return "read";
}


def _walk_scope(
    scope: uni.UniScopeNode,
    module_path: str,
    parent_id: str,
    facts: FactSet,
    seen_refs: set,
    seen_syms: set,
    in_scope_paths: set
) {
    for (name, raw_sym) in scope.names_in_scope.items() {
        sym = cast(uni.Symbol, raw_sym);
        decl = sym.decl;
        if decl is None {
            continue;
        }
        sid = stable_symbol_id(sym);

        if sid in seen_syms {
            continue;
        }
        seen_syms.add(sid);
        loc = decl.loc;
        sym_mod = str(loc.mod_path);
        kind = str(sym.sym_type);
        facts.symbols.append(
            SymbolFact(
                id=sid,
                module_path=sym_mod,
                name=str(name),
                kind=kind,
                access=str(sym.access),
                imported=bool(sym.imported),
                parent_id=parent_id,
                decl_pos_start=int(loc.pos_start),
                decl_pos_end=int(loc.pos_end),
                decl_line=int(loc.first_line),
                scope_chain=">".join(_scope_chain(sym))
            )
        );
        _emit_uses(sym, sid, kind, facts, seen_refs, in_scope_paths);
    }
    for kid in scope.kid_scope {
        _walk_scope(
            kid,
            module_path,
            _scope_id(kid),
            facts,
            seen_refs,
            seen_syms,
            in_scope_paths
        );
    }
}


def _scope_id(scope: uni.UniScopeNode) -> str {
    if isinstance(scope, uni.AstSymbolNode) {
        s = scope.sym;
        if s is not None {
            return stable_symbol_id(cast(uni.Symbol, s));
        }
    }
    return "";
}


def _emit_uses(
    sym: uni.Symbol,
    sid: str,
    kind: str,
    facts: FactSet,
    seen_refs: set,
    in_scope_paths: set
) {
    is_field = kind == _FIELD_KIND;
    for use_nd in sym.uses {
        loc = use_nd.loc;
        use_mod = str(loc.mod_path);
        if use_mod not in in_scope_paths {
            continue;
        }
        dedup = (sid, use_mod, loc.pos_start, loc.pos_end);
        if dedup in seen_refs {
            continue;
        }
        seen_refs.add(dedup);
        rkind = _ref_kind(use_nd);
        encl = _enclosing_symbol(use_nd);
        using_id = stable_symbol_id(cast(uni.Symbol, encl)) if encl is not None else "";
        facts.refs.append(
            ReferenceFact(
                used_id=sid,
                using_id=using_id,
                module_path=use_mod,
                pos_start=int(loc.pos_start),
                pos_end=int(loc.pos_end),
                line=int(loc.first_line),
                kind=rkind
            )
        );
        if is_field {
            facts.field_accesses.append(
                FieldAccessFact(
                    field_id=sid,
                    module_path=use_mod,
                    pos_start=int(loc.pos_start),
                    pos_end=int(loc.pos_end),
                    line=int(loc.first_line),
                    kind=rkind
                )
            );
        }
    }
}


def _extract_imports(mod: any, facts: FactSet, in_scope_paths: set) {
    for imp in mod.get_all_sub_nodes(uni.Import) {
        loc = imp.loc;
        imp_mod = str(loc.mod_path);
        if imp_mod not in in_scope_paths {
            continue;
        }
        is_from = imp.from_loc is not None;
        stmt_start = loc.pos_start;
        stmt_end = loc.pos_end;
        n_items = len(cast(list, imp.items));
        for item in imp.items {
            if isinstance(item, uni.ModuleItem) {
                nm_node = item.name;
                item_name = str(getattr_name(nm_node));
                if isinstance(nm_node, uni.AstSymbolNode) {
                    item_name = str(nm_node.sym_name);
                }
                alias = str(item.alias.sym_name) if item.alias is not None else "";
                resolved_id = _local_import_binding(imp, alias or item_name);
                iloc = nm_node.loc;
                facts.imports.append(
                    ImportFact(
                        module_path=imp_mod,
                        item_name=item_name,
                        alias=alias,
                        resolved_id=resolved_id,
                        resolved_path=str(item.abs_path or ""),
                        pos_start=int(iloc.pos_start),
                        pos_end=int(iloc.pos_end),
                        line=int(iloc.first_line),
                        is_from=bool(is_from),
                        stmt_pos_start=int(stmt_start),
                        stmt_pos_end=int(stmt_end),
                        n_items=n_items
                    )
                );
            } elif isinstance(item, uni.ModulePath) {
                alias = str(item.alias.sym_name) if item.alias is not None else "";
                head = item.dot_path_str.split(".")[0] if item.dot_path_str else "";
                resolved_id = _local_import_binding(imp, alias or head);
                iloc = item.loc;
                facts.imports.append(
                    ImportFact(
                        module_path=imp_mod,
                        item_name=str(item.dot_path_str),
                        alias=alias,
                        resolved_id=resolved_id,
                        resolved_path=str(item.abs_path or ""),
                        pos_start=int(iloc.pos_start),
                        pos_end=int(iloc.pos_end),
                        line=int(iloc.first_line),
                        is_from=bool(is_from),
                        stmt_pos_start=int(stmt_start),
                        stmt_pos_end=int(stmt_end),
                        n_items=n_items
                    )
                );
            }
        }
    }
}


def _extract_branches(mod: any, facts: FactSet, in_scope_paths: set) {
    for ifs in mod.get_all_sub_nodes(uni.IfStmt) {
        cond = ifs.condition;
        if not isinstance(cond, uni.Bool) {
            continue;
        }
        loc = ifs.loc;
        if_mod = str(loc.mod_path);
        if if_mod not in in_scope_paths {
            continue;
        }
        cloc = cond.loc;
        facts.branches.append(
            BranchFact(
                module_path=if_mod,
                cond_value=str(cond.lit_value).lower(),
                is_elif=isinstance(ifs, uni.ElseIf),
                has_else=ifs.else_body is not None,
                if_pos_start=int(loc.pos_start),
                if_pos_end=int(loc.pos_end),
                cond_pos_start=cloc.pos_start,
                cond_pos_end=cloc.pos_end,
                line=int(loc.first_line)
            )
        );
    }
}


def getattr_name(nd: any) -> str {
    if isinstance(nd, uni.AstSymbolNode) {
        return nd.sym_name;
    }
    val = nd?.value or "";
    return str(val);
}


def _module_deps(mod: any, in_scope_paths: set) -> list[str] {
    import from pathlib { Path }
    deps: set[str] = set();
    for imp in mod.get_all_sub_nodes(uni.Import) {
        paths: list[uni.ModulePath] = [];
        if imp.from_loc is not None {
            paths.append(cast(uni.ModulePath, imp.from_loc));
        } else {
            for item in imp.items {
                if isinstance(item, uni.ModulePath) {
                    paths.append(cast(uni.ModulePath, item));
                }
            }
        }
        for mp in paths {
            try {
                target = str(Path(mp.resolve_relative_path()).resolve());
            } except Exception {
                continue;
            }
            deps.add(target);
        }
    }
    return sorted(deps);
}


def _module_fact_hash(mod: ModuleFact, bundle: (tuple | None)) -> str {
    parts: list[str] = [
        f"v={EXTRACTOR_VERSION}",
        f"role={mod.role}",
        f"status={mod.status}",
        f"errors={mod.error_count}"
    ];
    (syms, refs, imports, fields, branches, bodies, literals, docstrings) = (
        bundle if bundle is not None else ([], [], [], [], [], [], [], [])
    );
    for s in sorted(syms, key=(lambda x : x.id)) {
        parts.append(
            "S|" + "|".join(
                [
                    s.id,
                    s.name,
                    s.kind,
                    s.access,
                    str(int(s.imported)),
                    s.parent_id,
                    str(s.decl_pos_start),
                    str(s.decl_pos_end),
                    s.scope_chain
                ]
            )
        );
    }
    for r in sorted(refs, key=(lambda x : x.id)) {
        parts.append("R|" + r.id + "|" + r.using_id);
    }
    for im in sorted(imports, key=(lambda x : (x.pos_start, x.pos_end, x.item_name))) {
        parts.append(
            "I|" + "|".join([im.item_name, im.alias, im.resolved_id, str(im.pos_start)])
        );
    }
    for fa in sorted(fields, key=(lambda x : (x.field_id, x.pos_start, x.kind))) {
        parts.append("F|" + fa.field_id + "|" + str(fa.pos_start) + "|" + fa.kind);
    }
    for br in sorted(branches, key=(lambda x : (x.if_pos_start, x.cond_value))) {
        parts.append("B|" + str(br.if_pos_start) + "|" + br.cond_value);
    }
    for bd in sorted(bodies, key=(lambda x : x.symbol_id)) {
        parts.append(
            "Y|" + "|".join(
                [bd.symbol_id, bd.exact_hash, bd.structural_hash, bd.completeness]
            )
        );
    }
    for lit in sorted(literals, key=(lambda x : (x.pos_start, x.value_hash))) {
        parts.append(
            "L|" + "|".join([lit.value_hash, str(lit.pos_start), lit.owner_id])
        );
    }
    for dc in sorted(docstrings, key=(lambda x : (x.pos_start, x.text_hash))) {
        parts.append("C|" + "|".join([dc.text_hash, dc.kind, dc.symbol_id]));
    }
    for dep in sorted(mod.deps) {
        parts.append("D|" + dep);
    }
    blob = "\n".join(parts);
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:32];
}


def extract_facts(prog: any, manifest: Manifest) -> FactSet {
    facts = FactSet();

    role_by_path: dict[str, str] = {};
    hash_by_path: dict[str, str] = {};
    name_by_path: dict[str, str] = {};
    for entry in manifest.live_entries() {
        role_by_path[entry.path] = role_label(entry.role);
        hash_by_path[entry.path] = entry.content_hash;
        name_by_path[entry.path] = entry.module_name;
    }
    in_scope_paths: set[str] = set(role_by_path.keys());

    source_paths: set[str] = {e.path for e in manifest.by_role(FileRole.SOURCE)};
    seen_refs: set = set();
    seen_syms: set = set();

    for (raw_path, raw_mod) in prog.mod.hub.items() {
        path = str(raw_path);
        mod = cast(uni.Module, raw_mod);
        if path not in source_paths {
            continue;
        }
        _walk_scope(
            mod, path, _scope_id(mod), facts, seen_refs, seen_syms, in_scope_paths
        );
        _extract_imports(mod, facts, in_scope_paths);
        _extract_branches(mod, facts, in_scope_paths);
        facts.bodies.extend(extract_bodies(mod, stable_symbol_id));
        facts.literals.extend(extract_literals(mod, stable_symbol_id));
        facts.docstrings.extend(extract_docstrings(mod, stable_symbol_id));
    }

    deps_by_source: dict[str, list[str]] = {};
    for (raw_path, raw_mod) in prog.mod.hub.items() {
        path = str(raw_path);
        mod = cast(uni.Module, raw_mod);
        if path in source_paths {
            deps_by_source[path] = _module_deps(mod, in_scope_paths);
        }
    }

    errs_by_path: dict[str, int] = {};
    for alert in cast(list, prog.errors_had) {
        try {
            apath = str(alert.loc.mod_path);
        } except Exception {
            continue;
        }
        errs_by_path[apath] = errs_by_path.get(apath, 0) + 1;
    }

    for bd in facts.bodies {
        if errs_by_path.get(bd.module_path, 0) > 0 {
            bd.completeness = "error";
        }
    }

    grouped: dict[str, tuple] = {};
    def _bucket(p: str) -> tuple {
        b = grouped.get(p);
        if b is None {
            b = ([], [], [], [], [], [], [], []);
            grouped[p] = b;
        }
        return b;
    }
    for s in facts.symbols {
        _bucket(s.module_path)[0].append(s);
    }
    for r in facts.refs {
        _bucket(r.module_path)[1].append(r);
    }
    for im in facts.imports {
        _bucket(im.module_path)[2].append(im);
    }
    for fa in facts.field_accesses {
        _bucket(fa.module_path)[3].append(fa);
    }
    for br in facts.branches {
        _bucket(br.module_path)[4].append(br);
    }
    for bd in facts.bodies {
        _bucket(bd.module_path)[5].append(bd);
    }
    for lit in facts.literals {
        _bucket(lit.module_path)[6].append(lit);
    }
    for dc in facts.docstrings {
        _bucket(dc.module_path)[7].append(dc);
    }

    for (path, role) in role_by_path.items() {
        ecount = errs_by_path.get(path, 0);
        mod_fact = ModuleFact(
            path=path,
            module_name=name_by_path.get(path, ""),
            content_hash=hash_by_path.get(path, ""),
            role=role,
            deps=deps_by_source.get(path, []),
            status=("error" if ecount > 0 else "complete"),
            error_count=ecount
        );
        mod_fact.fact_hash = _module_fact_hash(mod_fact, grouped.get(path));
        facts.modules.append(mod_fact);
    }
    return facts;
}
