impl same_lexical_scope(left: UniNode | None, right: UniNode | None) -> bool {
    if left is None or right is None {
        return False;
    }
    return left is right
        or (isinstance(left, ImplDef) and left.decl_link is right)
        or (isinstance(right, ImplDef) and right.decl_link is left);
}

impl is_identifier_slot(nd: UniNode) -> bool {
    par = nd.parent;
    if isinstance(par, KWPair) {
        return par.key is nd;
    }
    if isinstance(par, AtomTrailer) {
        return par.is_attr and (par.right is nd);
    }
    if isinstance(par, (HasVar, ParamVar, Archetype, Enum)) {
        return par.name is nd;
    }
    if isinstance(par, Ability) {
        return par.name_ref is nd;
    }
    if isinstance(par, ModuleItem) {
        return (par.name is nd) or (par.alias is nd);
    }
    return False;
}

impl find_python_scope_node_of(nd: UniNode) -> (UniScopeNode | None) {
    while nd.parent {
        scope_parent = nd.parent;
        if isinstance(scope_parent, UniScopeNode)
            and UniScopeNode.is_python_scoping(scope_parent) {
            return scope_parent;
        }
        nd = scope_parent;
    }
    return None;
}

impl find_typed_decl_scope_of(nd: AstSymbolNode) -> UniScopeNode {
    if UniScopeNode.is_python_scoping(nd.sym_tab) {
        return nd.sym_tab;
    }
    py_scope = find_python_scope_node_of(nd);
    if isinstance(py_scope, (Ability, ImplDef, Test, LambdaExpr)) {
        return py_scope;
    }
    return nd.sym_tab;
}

impl lookup_enclosing_binding(from_scope: UniScopeNode, name: str) -> (Symbol | None) {
    scope = find_python_scope_node_of(from_scope);
    while scope is not None {
        if isinstance(scope, Module) {
            sym = scope.names_in_scope.get(name);
            if sym is not None and sym.sym_type == SymbolType.MOD_VAR {
                return sym;
            }
            return None;
        }
        if isinstance(scope, (Ability, ImplDef, Test, LambdaExpr)) {
            sym = scope.names_in_scope.get(name);
            if sym is not None {
                return sym;
            }
        }
        scope = find_python_scope_node_of(scope);
    }
    return None;
}

impl record_cross_scope_rebind(py_scope: UniScopeNode, name: str, sym: Symbol) -> None {
    outer_tab = sym.parent_tab;
    if outer_tab is None or same_lexical_scope(outer_tab, py_scope) {
        return;
    }
    if not isinstance(py_scope, (Ability, ImplDef, Test)) {
        return;
    }
    if isinstance(outer_tab, Module) {
        if sym.sym_type == SymbolType.MOD_VAR {
            py_scope.implicit_rebinds[name] = sym;
        }
        return;
    }
    if isinstance(outer_tab, (Ability, ImplDef, Test)) {
        py_scope.implicit_rebinds[name] = sym;
    }
}

impl rebind_or_def_insert(
    target: AstSymbolNode, py_scope: UniScopeNode, single_decl: str
) -> None {
    if isinstance(py_scope, (Ability, ImplDef, Test, LambdaExpr)) {
        outer_sym = lookup_enclosing_binding(py_scope, target.sym_name);
        if outer_sym is not None {
            outer_sym.add_use(target.name_spec);
            py_scope.adopt_primary(outer_sym, target.sym_name);
            py_scope.implicit_rebinds[target.sym_name] = outer_sym;
            return;
        }
    }
    py_scope.def_insert(target, single_decl=single_decl);
}

impl def_insert_unpacking(
    nd: Expr, sym_tab: UniScopeNode, rebind_in_python_scope: bool = False
) -> None {
    if isinstance(nd, Name) {
        if rebind_in_python_scope {
            if ((existing := sym_tab.lookup(nd.sym_name, deep=False)) is not None) {
                existing.add_use(nd.name_spec);
                return;
            }
            py_scope = find_python_scope_node_of(nd);
            if py_scope is not None {
                if ((outer := py_scope.lookup(nd.sym_name, deep=False)) is not None) {
                    outer.add_use(nd.name_spec);
                    record_cross_scope_rebind(py_scope, nd.sym_name, outer);
                } else {
                    rebind_or_def_insert(nd, py_scope, single_decl='local var');
                }
                return;
            }
        }
        sym_tab.def_insert(nd, single_decl='iterator');
    } elif isinstance(nd, (TupleVal, ListVal)) {
        for target_var in nd.values {
            if isinstance(target_var, Expr) {
                def_insert_unpacking(target_var, sym_tab, rebind_in_python_scope);
            }
        }
    } elif (isinstance(nd, UnaryExpr) and (nd.op.name == Tok.STAR_MUL)) {
        def_insert_unpacking(nd.operand, sym_tab, rebind_in_python_scope);
    }
}

impl _ability_of_defn(defn_node: UniNode) -> (Ability | None) {
    if isinstance(defn_node, Ability) {
        return defn_node;
    }
    if isinstance(defn_node.parent, Ability) {
        return defn_node.parent;
    }
    return None;
}

impl ability_of_symbol(sym: (Symbol | None)) -> (Ability | None) {
    if sym is None or not sym.defn {
        return None;
    }
    decl = _ability_of_defn(sym.defn[0]);

    if decl is not None and str(decl.loc.mod_path).endswith(".pyi") {
        for alt in sym.defn {
            alt_decl = _ability_of_defn(alt);
            if alt_decl is not None
                and not str(alt_decl.loc.mod_path).endswith(".pyi") {
                return alt_decl;
            }
        }
    }
    return decl;
}

impl binding_kind_of_decl(decl: NameAtom) -> BindingKind {
    owner = decl.name_of;
    if isinstance(owner, (Archetype, Enum, TypeAlias)) {
        return BindingKind.BOTH;
    }
    if isinstance(owner, TypeParam) {
        return BindingKind.TYPE;
    }
    return BindingKind.VALUE;
}

impl import_chain_of(sym: Symbol) -> list[Symbol] {
    seen: set[int] = set();
    chain: list[Symbol] = [];
    cur: Symbol = sym;
    while True {
        if id(cur) in seen or not cur.defn {
            return chain;
        }
        seen.add(id(cur));
        chain.append(cur);
        decl = cur.decl;
        if not isinstance(decl.parent, ModuleItem) {
            return chain;
        }
        nxt = decl.sym;
        if nxt is None or nxt is cur {
            return chain;
        }
        cur = nxt;
    }
}

impl resolved_decl_of(sym: Symbol) -> (NameAtom | None) {
    for cur in import_chain_of(sym) {
        decl = cur.decl;
        if not isinstance(decl.parent, ModuleItem) {
            return decl;
        }
    }
    return None;
}

impl kind_has_runtime_binding(
    kind: BindingKind, decl: (NameAtom | None), space: CodeContext
) -> bool {
    if not kind.denotes_value() {
        return False;
    }
    if space != CodeContext.CLIENT {
        return True;
    }
    return decl is None or not isinstance(decl.name_of, TypeAlias);
}

impl has_runtime_binding(sym: Symbol, space: CodeContext) -> bool {
    return kind_has_runtime_binding(sym.binding_kind, resolved_decl_of(sym), space);
}

impl is_client_destined(nd: UniNode) -> bool {
    cur: (UniNode | None) = nd;
    while cur is not None {
        if isinstance(cur, ContextAwareNode) {
            return (cur.code_context == CodeContext.CLIENT) or cur.codespace_dual;
        }
        cur = cur.parent;
    }
    return False;
}

impl type_only_import_of(nd: NameAtom) -> (ModuleItem | None) {
    sym = nd.sym;
    if sym is None or not sym.imported or not sym.defn {
        return None;
    }
    found: (ModuleItem | None) = None;
    for d in sym.defn {
        if d is nd or not isinstance(d.parent, ModuleItem) {
            return None;
        }
        if not d.parent.from_parent.is_typed {
            return None;
        }
        found = d.parent;
    }
    return found;
}

impl in_type_position(nd: UniNode, include_subscripts: bool = True) -> bool {
    cur: UniNode = nd;
    parent = cur.parent;
    while parent is not None {
        if isinstance(parent, (SubTag, TypeAlias, TypeParam))
            or (include_subscripts and isinstance(parent, IndexSlice)) {
            return True;
        }
        if isinstance(parent, CastExpr) and parent.cast_type is cur {
            return True;
        }
        if isinstance(parent, FuncSignature) and parent.return_type is cur {
            return True;
        }
        cur = parent;
        parent = cur.parent;
    }
    return False;
}

impl bind_assignment_targets(nd: Assignment) -> None {
    for i in nd.target {
        if isinstance(i, AstSymbolNode) {
            if isinstance(i, (ListVal, TupleVal)) {
                def_insert_unpacking(i, i.sym_tab, rebind_in_python_scope=True);
            } elif (
                (i.sym_name in i.sym_tab.names_in_scope)
                and ((sym := i.sym_tab.names_in_scope[i.sym_name]) is not None)
            ) {
                if sym.imported and isinstance(nd.value, Null) {
                    sym.add_defn(i.name_spec);
                }
                sym.add_use(i.name_spec);
                record_cross_scope_rebind(i.sym_tab, i.sym_name, sym);
            } elif (
                (nd.type_tag is None)
                and ((outer_has := i.sym_tab.lookup(i.sym_name, deep=True)) is not None)
                and outer_has.sym_type == SymbolType.HAS_VAR
                and isinstance(outer_has.parent_tab, Ability)
            ) {
                outer_has.add_use(i.name_spec);
            } elif (
                (nd.type_tag is None) and not UniScopeNode.is_python_scoping(i.sym_tab)
            ) {
                py_scope = find_python_scope_node_of(i);
                if py_scope is not None {
                    if (
                        (outer := py_scope.lookup(i.sym_name, deep=False)) is not None
                    ) {
                        if outer.imported and isinstance(nd.value, Null) {
                            outer.add_defn(i.name_spec);
                        }
                        outer.add_use(i.name_spec);
                        record_cross_scope_rebind(py_scope, i.sym_name, outer);
                    } else {
                        rebind_or_def_insert(i, py_scope, single_decl='local var');
                    }
                } else {
                    i.sym_tab.def_insert(i, single_decl='local var');
                }
            } elif (
                (nd.type_tag is None)
                and isinstance(i.sym_tab, (Ability, ImplDef, Test, LambdaExpr))
            ) {
                rebind_or_def_insert(i, i.sym_tab, single_decl='local var');
            } else {
                if isinstance(i.sym_tab, Enum) {
                    i.name_spec._sym_category = SymbolType.ENUM_MEMBER;
                }
                find_typed_decl_scope_of(i).def_insert(i, single_decl='local var');
            }
        }
    }
}
