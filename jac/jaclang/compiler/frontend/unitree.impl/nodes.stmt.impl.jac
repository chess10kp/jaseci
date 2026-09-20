impl WalkerStmtOnlyNode.postinit -> None {
    self.from_walker = False;
}

impl CodeBlockStmt.postinit -> None {
    UniCFGNode.postinit(self);
}

impl GlobalVars.postinit -> None {
    UniNode.postinit(self);
    ContextAwareNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl Test.postinit -> None {
    name_node = self.name;
    name_node.set_parent(self);
    name_node._sym_name = f"test_{name_node.value}"
        if not name_node.value.startswith('test_')
        else name_node.value;
    UniNode.postinit(self);

    if (self.description is None and name_node not in self.kid) {
        self.insert_kids_at_pos([name_node], pos=1, pos_update=False);
    }
    AstSymbolNode._init_symbol(
        self,
        sym_name=name_node.sym_name,
        name_spec=name_node,
        sym_category=SymbolType.TEST
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}

impl ModuleCode.postinit -> None {
    UniNode.postinit(self);
    ContextAwareNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl PyInlineCode.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl Import.postinit -> None {
    self.jac_detected = None;
    self.boundary_facts = None;
    self.native_only_drop = False;
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}

impl Import.is_jac.getter -> bool {
    if self.jac_detected is not None {
        return self.jac_detected;
    }
    if (self.hint and (self.hint.tag.value == 'jac')) {
        return True;
    }
    if not self.hint {
        return self.__jac_detected;
    }
    return False;
}

impl Import.__jac_detected.getter -> bool {
    import from jaclang.jac0core.ext_registry { is_jac, INIT_FILES }
    if self.from_loc {
        if is_jac(self.from_loc.resolve_relative_path()) {
            return True;
        }
        if os.path.isdir(self.from_loc.resolve_relative_path()) {
            for init_name in INIT_FILES {
                if os.path.exists(
                    os.path.join(self.from_loc.resolve_relative_path(), init_name)
                ) {
                    return True;
                }
            }
            for i in self.items {
                if (
                    isinstance(i, ModuleItem)
                    and is_jac(self.from_loc.resolve_relative_path(i.name.value))
                ) {
                    return True;
                }
            }
        }
    }
    return `any(
        (isinstance(i, ModulePath) and is_jac(i.resolve_relative_path()))
        for i in self.items
    );
}

impl Import.has_string_path.getter -> bool {
    if (self.from_loc is not None and self.from_loc.string_path_value is not None) {
        return True;
    }
    for item in self.items {
        if (isinstance(item, ModulePath) and item.string_path_value is not None) {
            return True;
        }
    }
    return False;
}

impl Import.is_service_import.getter -> bool {
    if self.from_loc is None or not self.items {
        return False;
    }
    import from jaclang.compiler.driver.boundary_classify { is_service_bridge_import }
    return is_service_bridge_import(self);
}

impl Import.is_virtual_jac.getter -> bool {
    if self.from_loc is not None {
        return self.from_loc.dot_path_str.startswith('@jac/');
    }
    for item in self.items {
        if isinstance(item, ModulePath) {
            spv = item.string_path_value;
            if (spv is not None and spv.startswith('@jac/')) {
                return True;
            }
        }
    }
    return False;
}

impl Import.has_clib_decls.getter -> bool {
    return bool(self.clib_decls);
}

impl Import.ecosystem.getter -> str {
    if self.has_clib_decls {
        return 'clib';
    }
    if self.is_virtual_jac {
        return 'virtual';
    }
    if self.has_string_path {
        return 'string';
    }
    if self.is_jac {
        return 'jac';
    }
    return 'py';
}

impl OpenStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl IfStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl ElseStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}

impl ExprStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl TryStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl Except.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl FinallyStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl AwaitingClause.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl IterForStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl InForStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl WhileStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl ForeverStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl WithStmt.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
}

impl RaiseStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl AssertStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl CtrlStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl DeleteStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl DeleteStmt.leaf_targets -> list[Expr] {
    leaves: list[Expr] = [];
    pending: list[Expr] = `list(self.targets);
    pending.reverse();
    while pending {
        inner = DeleteStmt.unwrap_target(pending.pop());
        if isinstance(inner, (TupleVal, ListVal)) {
            elems = [
                el
                for el in inner.values
                if isinstance(el, Expr)
            ];
            elems.reverse();
            pending.extend(elems);
        } else {
            leaves.append(inner);
        }
    }
    return leaves;
}

impl DeleteStmt.unwrap_target(target: Expr) -> Expr {
    inner: Expr = target;
    while isinstance(inner, AtomUnit) and isinstance(inner.value, Expr) {
        inner = inner.value;
    }
    return inner;
}

impl DeleteStmt.is_location(target: Expr) -> bool {
    inner = DeleteStmt.unwrap_target(target);
    if isinstance(inner, Name) {
        return True;
    }
    return isinstance(inner, AtomTrailer)
        and (inner.is_attr or isinstance(inner.right, IndexSlice));
}

impl DeleteStmt.type_has_graph_member(t: (TypeBase | None)) -> bool {
    import from jaclang.compiler.types.types { ClassType, TypeVarType, UnionType }
    if isinstance(t, TypeVarType) {
        return DeleteStmt.type_has_graph_member(t.bound);
    }
    if isinstance(t, UnionType) {
        return any(DeleteStmt.type_has_graph_member(member) for member in t.types);
    }
    if isinstance(t, ClassType) {
        if t.is_node_type() or t.is_edge_type() or t.is_walker_type() {
            return True;
        }
        if t.is_builtin(["list", "tuple", "set", "frozenset"]) {
            return any(
                DeleteStmt.type_has_graph_member(item)
                for item in (t.private.type_args or [])
            );
        }
        if t.is_builtin("dict") and len(t.private.type_args or []) == 2 {
            return DeleteStmt.type_has_graph_member(t.private.type_args[1]);
        }
    }
    return False;
}

impl DeleteStmt.type_may_hold_graph(t: (TypeBase | None)) -> bool {
    import from jaclang.compiler.types.types { ClassType, UnionType }
    if DeleteStmt.type_has_graph_member(t) {
        return True;
    }

    def never_graph(ty: any) -> bool {
        if isinstance(ty, UnionType) {
            return all(never_graph(m) for m in ty.types);
        }
        if not isinstance(ty, ClassType) {
            return False;
        }
        if ty.is_any_type() or not ty.is_builtin() {
            return False;
        }
        class_name = ty.shared.class_name;
        if class_name
            in (
                "int",
                "float",
                "complex",
                "str",
                "bytes",
                "bytearray",
                "bool",
                "None",
                "NoneType"
            ) {
            return True;
        }
        type_args = ty.private.type_args;
        if type_args is None or len(type_args) == 0 {
            return False;
        }
        if class_name in ("list", "tuple", "set", "frozenset") {
            return all(never_graph(a) for a in type_args);
        }
        if class_name == "dict" {
            return len(type_args) == 2 and never_graph(type_args[1]);
        }
        return False;
    }
    return not never_graph(t);
}

impl DeleteStmt.target_may_hold_graph(target: Expr) -> bool {
    return DeleteStmt.type_may_hold_graph(target.type);
}

impl ReportStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl ReturnStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl VisitStmt.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl DisengageStmt.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl Assignment.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl YieldExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl AssignCompr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}

impl MatchStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl MatchCase.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}

impl SwitchStmt.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl SwitchCase.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}

impl MatchOr.postinit -> None {
    UniNode.postinit(self);
}

impl MatchAs.postinit -> None {
    UniNode.postinit(self);
}

impl MatchValue.postinit -> None {
    UniNode.postinit(self);
}

impl MatchSingleton.postinit -> None {
    UniNode.postinit(self);
}

impl MatchSequence.postinit -> None {
    UniNode.postinit(self);
}

impl MatchMapping.postinit -> None {
    UniNode.postinit(self);
}

impl MatchKVPair.postinit -> None {
    UniNode.postinit(self);
}

impl MatchStar.postinit -> None {
    UniNode.postinit(self);
}

impl MatchArch.postinit -> None {
    UniNode.postinit(self);
}

impl Import.absorbed_mod.getter -> (Module | None) {
    found = [self->:Absorbs:->];
    return found[0] if found else None;
}

impl Import.absorbed_mod.setter(absorbed_mod: (Module | None)) {
    del [edge self->:Absorbs:->];
    if absorbed_mod is not None {
        self +>:Absorbs:+> absorbed_mod;
    }
}
