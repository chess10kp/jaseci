import hashlib;
import ast;
import jaclang.jac0core.unitree as uni;

import from jaclang.prune.manifest { Manifest, FileRole, role_label }


obj ModuleFact {
    has path: str,
        module_name: str,
        content_hash: str,
        role: str,
        deps: list[str] = [];
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
        kind: str;
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
        is_from: bool;
}

obj FieldAccessFact {
    has field_id: str,
        module_path: str,
        pos_start: int,
        pos_end: int,
        line: int,
        kind: str;
}


obj FactSet {
    has modules: list[ModuleFact] = [],
        symbols: list[SymbolFact] = [],
        refs: list[ReferenceFact] = [],
        imports: list[ImportFact] = [],
        field_accesses: list[FieldAccessFact] = [];

    def by_module -> dict[str, tuple] {
        out: dict[str, tuple] = {};
        for m in self.modules {
            out[m.path] = ([], [], [], []);
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


def _scope_chain(sym: any) -> list[str] {
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


def stable_symbol_id(sym: any) -> str {
    decl = sym.decl;
    modp = decl.loc.mod_path if decl is not None else "";
    chain = _scope_chain(sym);
    key = "|".join([modp, ">".join(chain), sym.sym_name, str(sym.sym_type)]);
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:16];
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
    scope: any,
    module_path: str,
    parent_id: str,
    facts: FactSet,
    seen_refs: set,
    seen_syms: set,
    in_scope_paths: set
) {
    for (name, sym) in scope.names_in_scope.items() {
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
        sym_mod = loc.mod_path;
        kind = str(sym.sym_type);
        facts.symbols.append(
            SymbolFact(
                id=sid,
                module_path=sym_mod,
                name=name,
                kind=kind,
                access=str(sym.access),
                imported=sym.imported,
                parent_id=parent_id,
                decl_pos_start=loc.pos_start,
                decl_pos_end=loc.pos_end,
                decl_line=loc.first_line,
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


def _scope_id(scope: any) -> str {
    if isinstance(scope, uni.AstSymbolNode) {
        s = scope.sym;
        if s is not None {
            return stable_symbol_id(s);
        }
    }
    return "";
}


def _emit_uses(
    sym: any, sid: str, kind: str, facts: FactSet, seen_refs: set, in_scope_paths: set
) {
    is_field = kind == _FIELD_KIND;
    for use_nd in sym.uses {
        loc = use_nd.loc;
        use_mod = loc.mod_path;
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
        using_id = stable_symbol_id(encl) if encl is not None else "";
        facts.refs.append(
            ReferenceFact(
                used_id=sid,
                using_id=using_id,
                module_path=use_mod,
                pos_start=loc.pos_start,
                pos_end=loc.pos_end,
                line=loc.first_line,
                kind=rkind
            )
        );
        if is_field {
            facts.field_accesses.append(
                FieldAccessFact(
                    field_id=sid,
                    module_path=use_mod,
                    pos_start=loc.pos_start,
                    pos_end=loc.pos_end,
                    line=loc.first_line,
                    kind=rkind
                )
            );
        }
    }
}


def _extract_imports(mod: any, facts: FactSet, in_scope_paths: set) {
    for imp in mod.get_all_sub_nodes(uni.Import) {
        loc = imp.loc;
        imp_mod = loc.mod_path;
        if imp_mod not in in_scope_paths {
            continue;
        }
        is_from = imp.from_loc is not None;
        for item in imp.items {
            if isinstance(item, uni.ModuleItem) {
                nm_node = item.name;
                resolved_id = "";
                item_name = str(getattr_name(nm_node));
                if isinstance(nm_node, uni.AstSymbolNode) and nm_node.sym is not None {
                    resolved_id = stable_symbol_id(nm_node.sym);
                    item_name = nm_node.sym_name;
                }
                alias = item.alias.sym_name if item.alias is not None else "";
                iloc = nm_node.loc;
                facts.imports.append(
                    ImportFact(
                        module_path=imp_mod,
                        item_name=item_name,
                        alias=alias,
                        resolved_id=resolved_id,
                        resolved_path=item.abs_path or "",
                        pos_start=iloc.pos_start,
                        pos_end=iloc.pos_end,
                        line=iloc.first_line,
                        is_from=is_from
                    )
                );
            } elif isinstance(item, uni.ModulePath) {
                resolved_id = "";
                if item.alias is not None
                and isinstance(item.alias, uni.AstSymbolNode)
                and item.alias.sym is not None {
                    resolved_id = stable_symbol_id(item.alias.sym);
                }
                alias = item.alias.sym_name if item.alias is not None else "";
                iloc = item.loc;
                facts.imports.append(
                    ImportFact(
                        module_path=imp_mod,
                        item_name=item.dot_path_str,
                        alias=alias,
                        resolved_id=resolved_id,
                        resolved_path=item.abs_path or "",
                        pos_start=iloc.pos_start,
                        pos_end=iloc.pos_end,
                        line=iloc.first_line,
                        is_from=is_from
                    )
                );
            }
        }
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
        paths: list = [];
        if imp.from_loc is not None {
            paths.append(imp.from_loc);
        } else {
            for item in imp.items {
                if isinstance(item, uni.ModulePath) {
                    paths.append(item);
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
    in_scope_paths = set(role_by_path.keys());

    source_paths = {e.path for e in manifest.by_role(FileRole.SOURCE)};
    seen_refs: set = set();
    seen_syms: set = set();

    for (path, mod) in prog.mod.hub.items() {
        if path not in source_paths {
            continue;
        }
        _walk_scope(
            mod, path, _scope_id(mod), facts, seen_refs, seen_syms, in_scope_paths
        );
        _extract_imports(mod, facts, in_scope_paths);
    }

    deps_by_source: dict[str, list[str]] = {};
    for (path, mod) in prog.mod.hub.items() {
        if path in source_paths {
            deps_by_source[path] = _module_deps(mod, in_scope_paths);
        }
    }
    for (path, role) in role_by_path.items() {
        facts.modules.append(
            ModuleFact(
                path=path,
                module_name=name_by_path.get(path, ""),
                content_hash=hash_by_path.get(path, ""),
                role=role,
                deps=deps_by_source.get(path, [])
            )
        );
    }
    return facts;
}
