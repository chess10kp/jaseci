impl TypeEvaluator.is_any_type(ty: TypeBase) -> bool {
    if isinstance(ty, TypeVarType) {
        return True;
    }

    if ty.is_any_instance() {
        return True;
    }

    if isinstance(ty, ClassType) {
        if (
            self.prefetch.type_var_class
            and ty.shared.same_class(self.prefetch.type_var_class.shared)
        ) {
            return True;
        }
    }
    return False;
}

impl TypeEvaluator.is_explicit_any(ty: TypeBase) -> bool {
    return ty.is_any_instance();
}

impl TypeEvaluator.is_none_type(ty: TypeBase) -> bool {
    if not self.prefetch or not self.prefetch.none_type_class {
        return False;
    }
    return (
        isinstance(ty, ClassType)
        and ty.shared.same_class(self.prefetch.none_type_class.shared)
    );
}

impl TypeEvaluator._diag_unnarrowed_optional(
    nd: UniNode, ty: TypeBase, required: str
) -> bool {
    if not isinstance(ty, UnionType) {
        return False;
    }
    _has_none = False;
    for _m in (ty.types or []) {
        if self.is_none_type(self._convert_to_instance(_m)) {
            _has_none = True;
            break;
        }
    }
    if not _has_none {
        return False;
    }
    if not self._in_native_context() or not self._is_strict_site(nd) {
        return False;
    }
    self.emit_diag(E1121, nd, type=str(ty), required=required);
    return True;
}

impl TypeEvaluator._is_strict_site(nd: UniNode) -> bool {
    mod = nd.find_parent_of_type(Module);
    if mod is None {
        return False;
    }
    cached = self._strict_site_cache.get(id(mod));
    if cached is not None {
        return cached;
    }
    result = not mod.is_raised_from_py;
    self._strict_site_cache[id(mod)] = result;
    return result;
}

impl TypeEvaluator._in_native_context -> bool {
    if self._pass is None {
        return False;
    }
    cur = self._pass?.current_node;
    if cur is None or not isinstance(cur, UniNode) {
        return False;
    }

    if cur.in_native_context() {
        return True;
    }
    mod = cur.find_parent_of_type(Module);
    return mod is not None and mod.decided_codespace == 'native';
}

impl TypeEvaluator._is_typing_special_form(ty: TypeBase, name: str) -> bool {
    return (
        isinstance(ty, ClassType)
        and ty.shared is not None
        and ty.shared.class_name == name
        and ty.shared.is_from_stdlib_stub
    );
}

impl TypeEvaluator.is_typevar_class(ty: TypeBase) -> bool {
    if (
        self.prefetch
        and self.prefetch.type_var_class
        and isinstance(ty, ClassType)
        and ty.shared.same_class(self.prefetch.type_var_class.shared)
    ) {
        return True;
    }
    return self._is_typing_special_form(ty, "TypeVar");
}

impl TypeEvaluator.is_paramspec_class(ty: TypeBase) -> bool {
    if (
        self.prefetch
        and self.prefetch.param_spec_class
        and isinstance(ty, ClassType)
        and ty.shared.same_class(self.prefetch.param_spec_class.shared)
    ) {
        return True;
    }
    return self._is_typing_special_form(ty, "ParamSpec");
}

impl TypeEvaluator.is_type_var_tuple_class(ty: TypeBase) -> bool {
    if (
        self.prefetch
        and self.prefetch.type_var_tuple_class
        and isinstance(ty, ClassType)
        and ty.shared.same_class(self.prefetch.type_var_tuple_class.shared)
    ) {
        return True;
    }
    return self._is_typing_special_form(ty, "TypeVarTuple");
}

impl TypeEvaluator.ct_demand(nd: Expr) -> (CtValue | None) {
    self.get_type_of_expression(nd);
    cv = nd.ct_value;
    if cv is not None and not cv.is_deferred {
        return cv;
    }
    got = self.ct_eval.try_eval(nd, demand=True);
    if got is not None {
        nd.ct_value = got;
        return got;
    }
    return cv;
}

impl TypeEvaluator.ct_site_error(
    nd: Expr, what: str, cv: (CtValue | None), allow_deferred: bool = True
) -> bool {
    if self.ct_quiet {
        return cv is None or (cv.is_deferred and not allow_deferred);
    }
    if cv is None {
        reason = self.ct_eval.last_error;
        if reason {
            self.emit_diag(E0108, nd, reason=f"{what}: {reason}");
        } else {
            self.emit_diag(E0033, nd, what=what, reason="");
        }
        return True;
    }
    if cv.is_deferred and not allow_deferred {
        self.emit_diag(
            E0033,
            nd,
            what=what,
            reason=" (it depends on a comptime parameter or loop variable)"
        );
        return True;
    }
    return False;
}

impl TypeEvaluator.pop_symbol_resolution(symbol: Symbol) -> None {
    popped_symbol = self.symbol_resolution_stack.pop();
    assert popped_symbol == symbol;
}

impl TypeEvaluator.push_symbol_resolution(symbol: Symbol) -> bool {
    if self.get_index_of_symbol_resolution(symbol) is not None {
        return False;
    }
    self.symbol_resolution_stack.append(symbol);
    return True;
}

impl TypeEvaluator.get_index_of_symbol_resolution(symbol: Symbol) -> int | None {
    for (i, entry_) in enumerate(self.symbol_resolution_stack) {
        if entry_ == symbol {
            return i;
        }
    }
    return None;
}

impl TypeEvaluator._make_coroutine_type(inner: TypeBase) -> TypeBase {
    if self.prefetch.coroutine_class is None {
        return inner;
    }

    coro = self.prefetch.coroutine_class.clone_as_instance();
    coro.private.type_args = [AnyType(), AnyType(), inner];
    return coro;
}

impl TypeEvaluator._is_awaitable_type(t: TypeBase) -> bool {
    if not isinstance(t, ClassType) {
        return False;
    }
    if t.is_builtin(["Coroutine", "Awaitable"]) {
        return True;
    }
    return self.get_type_of_magic_method_call(t, "__await__", [], None) is not None;
}

impl TypeEvaluator._unwrap_awaitable_type(t: TypeBase, node_: UniNode) -> TypeBase {
    if not isinstance(t, ClassType) {
        return t;
    }
    if t.is_builtin("Coroutine") {
        if t.private.type_args and len(t.private.type_args) >= 3 {
            return t.private.type_args[2];
        }
        return t;
    }
    if t.is_builtin("Awaitable") {
        if t.private.type_args and len(t.private.type_args) >= 1 {
            return t.private.type_args[0];
        }
        return t;
    }

    await_ret = self.get_type_of_magic_method_call(t, "__await__", [], node_);
    if await_ret is not None {
        gen_ret = get_declared_generator_return_type(
            self._convert_to_instance(await_ret)
        );
        if gen_ret is not None {
            return gen_ret;
        }
    }
    return t;
}

impl TypeEvaluator._is_sv_async_call(expr: FuncCall) -> bool {
    tgt = expr.target;
    if not isinstance(tgt, Name) or tgt.sym is None {
        return False;
    }
    mod = expr.find_parent_of_type(Module);
    if mod is None {
        return False;
    }
    mod_key = id(mod);
    syms = self._sv_async_syms_cache.get(mod_key);
    if syms is None {
        syms = set();
        import from jaclang.compiler.driver.boundary_classify {
            CrossAppKind,
            classify_cross_app_import,
            is_client_native_edge_import
        }
        import from jaclang.compiler.symbol_utils {
            ClientImportVerdict,
            classify_client_import_item,
            decl_has_access,
            import_target_pinned_server,
            resolve_import_source_module
        }
        for imp in mod.get_all_sub_nodes(Import) {
            kind = classify_cross_app_import(imp, None);
            is_service = kind == CrossAppKind.SERVICE_BRIDGE;
            is_boundary = kind == CrossAppKind.CLIENT_BRIDGE;
            is_native_edge = (
                not is_service
                and not is_boundary
                and is_client_native_edge_import(imp, self.program)
            );
            if not (is_service or is_boundary or is_native_edge) {
                continue;
            }
            source_mod = (
                resolve_import_source_module(self.program, imp) if is_boundary else None
            );
            pinned_server = import_target_pinned_server(imp) if is_boundary else False;
            for item in imp.items {
                if not (
                    isinstance(item, ModuleItem)
                    and isinstance(item.name, Name)
                    and item.name.sym is not None
                ) {
                    continue;
                }
                sym_kind = item.name.sym.sym_type;
                if sym_kind != SymbolType.ABILITY {
                    facts = imp.boundary_facts;
                    is_bridged_walker = is_service
                        and (
                            sym_kind == SymbolType.WALKER_ARCH
                            or (
                                facts is not None
                                and item.name.value in facts.sv_walkers
                            )
                        );
                    if not is_bridged_walker and is_service {
                        decl = resolved_decl_of(item.name.sym);
                        owner = decl.name_of if decl is not None else None;
                        is_bridged_walker = (
                            isinstance(owner, Archetype) and owner.arch_kind == 'walker'
                        );
                    }
                    if not is_bridged_walker {
                        continue;
                    }
                } elif is_boundary {
                    if source_mod is None {
                        continue;
                    }
                    verdict = classify_client_import_item(source_mod, item);
                    is_stub = verdict == ClientImportVerdict.BRIDGED
                        or (
                            pinned_server
                            and (
                                verdict != ClientImportVerdict.DEAD
                                or decl_has_access(source_mod, item)
                            )
                        );
                    if not is_stub {
                        continue;
                    }
                }
                syms.add(id(item.name.sym));
            }
        }
        self._sv_async_syms_cache[mod_key] = syms;
    }
    return id(tgt.sym) in syms;
}

impl TypeEvaluator._prefetch_types{
    def get_types_class(type_name: str) -> ClassType | None {
        return self._get_class_from_module(self.types_module, type_name);
    }
    def get_typing_class(type_name: str) -> ClassType | None {
        return self._get_class_from_module(self.typing_module, type_name);
    }
    def get_builtin_class(type_name: str) -> ClassType | None {
        return self._get_class_from_module(self.builtins_module, type_name);
    }
    def get_enum_class(type_name: str) -> ClassType | None {
        return self._get_class_from_module(self.enum_module, type_name);
    }
    def get_jac_builtin_class(type_name: str) -> ClassType | None {
        return self._get_class_from_module(self.jac_builtins_module, type_name);
    }

    self.prefetch.none_type_class = get_types_class("NoneType");
    self.prefetch.object_class = get_builtin_class("object");
    self.prefetch.type_class = get_builtin_class("type");
    self.prefetch.classmethod_class = get_builtin_class("classmethod");

    self.prefetch.coroutine_class = get_typing_class("Coroutine");
    self.prefetch.generator_class = get_typing_class("Generator");
    self.prefetch.function_class = get_types_class("FunctionType");
    self.prefetch.mappingproxy_class = get_types_class("MappingProxyType");

    self.prefetch.tuple_class = get_builtin_class("tuple");
    self.prefetch.bool_class = get_builtin_class("bool");
    self.prefetch.int_class = get_builtin_class("int");
    self.prefetch.float_class = get_builtin_class("float");
    self.prefetch.str_class = get_builtin_class("str");
    self.prefetch.bytes_class = get_builtin_class("bytes");
    self.prefetch.dict_class = get_builtin_class("dict");
    self.prefetch.list_class = get_builtin_class("list");
    self.prefetch.slice_class = get_builtin_class("slice");
    self.prefetch.set_class = get_builtin_class("set");
    self.prefetch.enum_class = get_enum_class("Enum");
    if self.prefetch.enum_class {
        self.prefetch.enum_class.shared.is_enum_class = True;
    }
    self.prefetch.protocol_class = get_typing_class("Protocol");
    self.prefetch.any_class = get_typing_class("Any");

    self.prefetch.callable_class = get_typing_class("Callable");
    if self.prefetch.callable_class {
        self.prefetch.callable_class.private.alias_name = "Callable";
    }

    if self.prefetch.str_class {
        self.prefetch.literal_string_class = self._create_special_builtin_type(
            "LiteralString", self.prefetch.str_class
        );
    }

    self.prefetch.root_class = get_jac_builtin_class("Root");
    if self.prefetch.root_class {
        self.prefetch.root_class.shared.is_root_class = True;
    }
    self.prefetch.final_class = get_jac_builtin_class("Final");
    self.prefetch.node_class = get_jac_builtin_class("Node");
    self.prefetch.edge_class = get_jac_builtin_class("Edge");
    self.prefetch.walker_class = get_jac_builtin_class("Walker");
    self.prefetch.path_class = get_jac_builtin_class("GraphQuery");
    self.prefetch.jsx_element_class = get_jac_builtin_class("JsxElement");
    self.prefetch.html_common_props_class = get_jac_builtin_class("_HtmlCommonProps");
    self.prefetch.jsx_intrinsic_elements_class = get_jac_builtin_class(
        "_JsxIntrinsicElements"
    );
}

impl TypeEvaluator._load_stub_module(path: str) -> Module {
    catalog = self.program.stub_catalog();
    if catalog is not None {
        cat_mod = catalog.module_for_path(path);
        if cat_mod is not None {
            if cat_mod.parent_scope is None and cat_mod is not self.builtins_module {
                cat_mod.parent_scope = self.builtins_module;
            }
            return cat_mod;
        }
    }
    if not os.path.exists(path) {
        raise FileNotFoundError(f"Stub file not found at {path}");
    }

    resolved_path = str(Path(path).resolve());
    compiler = self.program._get_compiler();
    target_program = compiler.selfhost.resolve(resolved_path, self.program);
    target_hub = target_program.mod.hub;

    if resolved_path in self.program.mod.hub {
        mod = self.program.mod.hub[resolved_path];
        if mod.parent_scope is None and mod is not self.builtins_module {
            mod.parent_scope = self.builtins_module;
        }
        return mod;
    }
    if resolved_path in target_hub {
        mod = target_hub[resolved_path];
        if mod.parent_scope is None and mod is not self.builtins_module {
            mod.parent_scope = self.builtins_module;
        }
        return mod;
    }

    mod = self.program.load_dependency_module(path);
    if mod.parent_scope is None and mod is not self.builtins_module {
        mod.parent_scope = self.builtins_module;
    }
    return mod;
}

impl TypeEvaluator.postinit -> None {
    self.ct_eval = CtEvaluator(evaluator=self);
    self._BUILTINS_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/builtins.pyi"
    );
    self._TYPING_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/typing.pyi"
    );
    self._TYPES_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/types.pyi"
    );
    self._JAC_BUILTINS_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "jac_builtins.pyi"
    );
    self._BUILTIN_OVERRIDES_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "builtin_overrides.pyi"
    );
    self._DOM_TYPES_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "dom_types.pyi"
    );
    self._NA_BUILTINS_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "na_builtins.pyi"
    );
    self._JS_GLOBALS_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "js_globals.pyi"
    );
    self._TYPING_AMBIENT_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "typing_ambient.pyi"
    );
    self._ENUM_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/enum.pyi"
    );

    self.prefetch = PrefetchedTypes();
    self._flow_pending_symbols = set();
    self._flow_pending_keys = set();
    self._modules_in_compile = set();

    catalog = self.program.stub_catalog();
    prelude = (
        self._init_prelude_from_catalog(catalog)
            if catalog is not None
            else self._init_prelude_from_sources()
    );
    self.typing_module = prelude[0];
    self.types_module = prelude[1];
    self.enum_module = prelude[2];
    self.jac_builtins_module = prelude[3];
    self.dom_types_module = prelude[4];
    self.na_builtins_module = prelude[5];
    self.js_globals_module = prelude[6];
    self._prefetch_types();
    install_builtin_extensions(self.prefetch.list_class, self.prefetch.int_class);
}

impl TypeEvaluator._init_prelude_from_catalog(catalog: StubCatalog) -> list[Module] {
    names = (
        "builtins",
        "typing",
        "types",
        "enum",
        "jac_builtins",
        "dom_types",
        "na_builtins",
        "js_globals"
    );
    loaded: list[Module] = [];
    for name in names {
        mod = catalog.module(name);
        if mod is None {
            raise RuntimeError(f"stub catalog is missing the '{name}' module");
        }
        loaded.append(mod);
    }
    self.builtins_module = loaded[0];
    typing_mod = loaded[1];
    self.prefetch.type_var_class = self._get_class_from_module(typing_mod, "TypeVar");
    self.prefetch.param_spec_class = self._get_class_from_module(
        typing_mod, "ParamSpec"
    );
    self.prefetch.type_var_tuple_class = self._get_class_from_module(
        typing_mod, "TypeVarTuple"
    );
    self.ambient_typing_names_by_module = catalog.ambient_typing_names();
    return loaded[1:];
}

impl TypeEvaluator._init_prelude_from_sources -> list[Module] {
    import from jaclang.compiler.frontend.module_facts { ModuleFacts }
    typing_mod = self._load_stub_module(self._TYPING_STUB_FILE_PATH);
    types_mod = self._load_stub_module(self._TYPES_STUB_FILE_PATH);
    enum_mod = self._load_stub_module(self._ENUM_STUB_FILE_PATH);

    self.prefetch.type_var_class = self._get_class_from_module(typing_mod, "TypeVar");
    self.prefetch.param_spec_class = self._get_class_from_module(
        typing_mod, "ParamSpec"
    );
    self.prefetch.type_var_tuple_class = self._get_class_from_module(
        typing_mod, "TypeVarTuple"
    );
    builtins_mod = self._load_stub_module(self._BUILTINS_STUB_FILE_PATH);
    self.builtins_module = builtins_mod;
    jac_builtins_mod = self._load_stub_module(self._JAC_BUILTINS_STUB_FILE_PATH);
    dom_types_mod = self._load_stub_module(self._DOM_TYPES_STUB_FILE_PATH);
    na_builtins_mod = self._load_stub_module(self._NA_BUILTINS_STUB_FILE_PATH);
    js_globals_mod = self._load_stub_module(self._JS_GLOBALS_STUB_FILE_PATH);

    jac_allowed = ModuleFacts.literal_exports(jac_builtins_mod);
    for (name, sym) in jac_builtins_mod.names_in_scope.items() {
        if jac_allowed is not None and name not in jac_allowed {
            continue;
        }
        existing = builtins_mod.names_in_scope.get(name);
        if existing is None or existing.imported {
            builtins_mod.adopt_primary(sym, name);
        }
    }

    builtin_overrides_module = self._load_stub_module(
        self._BUILTIN_OVERRIDES_STUB_FILE_PATH
    );
    overrides_allowed = ModuleFacts.literal_exports(builtin_overrides_module);
    for (name, sym) in builtin_overrides_module.names_in_scope.items() {
        if overrides_allowed is not None and name not in overrides_allowed {
            continue;
        }
        builtins_mod.adopt_primary(sym, name);
    }

    for (name, sym) in dom_types_mod.names_in_scope.items() {
        existing = builtins_mod.names_in_scope.get(name);
        if existing is None or existing.imported {
            builtins_mod.adopt_primary(sym, name);
        }
    }

    ambient_mod = self._load_stub_module(self._TYPING_AMBIENT_STUB_FILE_PATH);
    raw_groups = ModuleFacts.exported_import_names(ambient_mod);
    typing_ambient_flat: set[str] = set();
    for names in raw_groups.values() {
        typing_ambient_flat = typing_ambient_flat | names;
    }

    self.ambient_typing_names_by_module = raw_groups;
    self.ambient_typing_names_by_module["typing"] = typing_ambient_flat;
    for typing_name in typing_ambient_flat {
        typing_sym = typing_mod.names_in_scope.get(typing_name);
        if typing_sym is None {
            continue;
        }
        existing_typing = builtins_mod.names_in_scope.get(typing_name);
        if existing_typing is None or existing_typing.imported {
            builtins_mod.adopt_primary(typing_sym, typing_name);
        }
    }
    return [
        typing_mod,
        types_mod,
        enum_mod,
        jac_builtins_mod,
        dom_types_mod,
        na_builtins_mod,
        js_globals_mod
    ];
}

impl TypeEvaluator._intern_shared(shared: ClassDetailsShared) -> ClassDetailsShared {
    site = shared.canonical_key();
    if site is None {
        return shared;
    }

    src = shared.symbol_table?.loc?.orig_src;
    key = (site, src.hash if src is not None else "");
    found = self._shared_intern.get(key);
    if found is None {
        self._shared_intern[key] = shared;
        return shared;
    }
    if found.symbol_table is not shared.symbol_table
        and self._scope_is_current(shared.symbol_table) {
        found.symbol_table = shared.symbol_table;
    }
    fresh_bases = [
        b
        for b in shared.base_classes
        if isinstance(b, ClassType)
    ];
    known_bases = [
        b
        for b in found.base_classes
        if isinstance(b, ClassType)
    ];
    if fresh_bases and not known_bases {
        found.base_classes = shared.base_classes;
        found._mro_sig = ();
        found._provisional = shared._provisional;
    }
    return found;
}

impl TypeEvaluator._scope_is_current(scope: UniScopeNode) -> bool {
    mod = scope if isinstance(scope, Module) else scope.find_parent_of_type(Module);
    if mod is None or mod.loc is None or not mod.loc.mod_path {
        return False;
    }
    return self.program.find_module(self.program.hub_key(mod.loc.mod_path)) is mod;
}
