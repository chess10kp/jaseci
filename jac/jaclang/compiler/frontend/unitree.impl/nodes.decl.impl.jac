impl ArchSpec.postinit -> None {
    CodeBlockStmt.postinit(self);
}

impl SubTag.postinit -> None {
    UniNode.postinit(self);
}

impl TypeParam.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.TYPE
    );
}

impl TypeAlias.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.TYPE
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    ContextAwareNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl ModulePath.postinit -> None {
    self.abs_path = None;
    UniNode.postinit(self);
}

impl ModulePath.is_import_from.getter -> bool {
    if (self.parent and isinstance(self.parent, Import)) {
        return (self.parent.from_loc == self);
    }
    return False;
}

impl ModulePath.string_path_value.getter -> (str | None) {
    if (self.path and (len(self.path) == 1) and isinstance(self.path[0], String)) {
        lv = self.path[0].lit_value;
        return lv if isinstance(lv, str) else None;
    }
    return None;
}

impl ModulePath.dot_path_str.getter -> str {
    spv = self.string_path_value;
    if spv is not None {
        return (('.' * self.level) + spv);
    }
    return (
        ('.' * self.level) + '.'.join([p.value for p in self.path] if self.path else [])
    );
}

impl ModulePath.base_module_name.getter -> str {
    spv = self.string_path_value;
    if spv is not None {
        return spv;
    }
    return '.'.join([p.value for p in self.path] if self.path else []);
}

impl ModulePath.resolve_relative_path(target_item: (str | None) = None) -> str {
    import from jaclang.project.modresolver { resolve_relative_path }
    bundled = self.native_bundled_path();
    if bundled is not None {
        return bundled;
    }
    spv = self.string_path_value;
    if spv is not None {
        return resolve_relative_path(spv, self.loc.mod_path, string_spec=True);
    }
    target = self.dot_path_str + (f".{target_item}" if target_item else '');
    return resolve_relative_path(target, self.loc.mod_path);
}

impl ModulePath.native_bundled_path -> (str | None) {
    import os;
    import from jaclang.compiler.frontend.codeinfo {
        is_bundled_native_module,
        resolve_native_module
    }
    mod_path = self.loc.mod_path if self.loc else None;
    if not self.in_native_context() {
        return None;
    }
    if mod_path and mod_path.endswith(".pyi") {
        return None;
    }
    base = self.dot_path_str;
    if not is_bundled_native_module(base) {
        return None;
    }
    base_dir = os.path.dirname(mod_path) if mod_path else os.getcwd();
    (_src, full_path) = resolve_native_module(base, base_dir);
    return full_path;
}

impl ModulePath.resolve_relative_path_list -> list[str] {
    parts = self.dot_path_str.split('.');
    if not parts {
        return [];
    }

    full_path = self.resolve_relative_path();

    paths: list[str] = [''] * len(parts);
    paths[-1] = full_path;

    full_basename = os.path.basename(full_path);
    cur_dir = os.path.dirname(full_path);
    if full_basename.startswith('__init__') {
        cur_dir = os.path.dirname(cur_dir);
    }
    for i in range(len(parts) - 2, -1, -1) {
        init_found = False;
        for init_name in ('__init__.jac', '__init__.py', '__init__.pyi') {
            init_path = os.path.join(cur_dir, init_name);
            if os.path.isfile(init_path) {
                paths[i] = init_path;
                init_found = True;
                break;
            }
        }
        if not init_found {
            paths[i] = cur_dir;
        }
        cur_dir = os.path.dirname(cur_dir);
    }
    return paths;
}

impl ModuleItem.postinit -> None {
    UniNode.postinit(self);
    self.abs_path = None;
}

impl ModuleItem.from_parent.getter -> Import {
    if (not self.parent or not isinstance(self.parent, Import)) {
        raise ValueError('Import parent not found. Not Possible.');
    }
    return self.parent;
}

impl ModuleItem.from_mod_path.getter -> ModulePath {
    if not self.from_parent.from_loc {
        raise ValueError('Module items should have module path. Not Possible.');
    }
    return self.from_parent.from_loc;
}

impl ModuleItem.binding_name.getter -> (Name | None) {
    if isinstance(self.name, Name) {
        return self.name;
    }

    if self.name.value in ('default', '*') {
        return self.alias;
    }
    return None;
}

impl ModuleItem.resolve_relative_path -> str {
    item_name = self.name.value if isinstance(self.name, Name) else None;

    if item_name is None {
        return self.from_mod_path.resolve_relative_path();
    }

    return self.from_mod_path.resolve_relative_path(target_item=item_name);
}

impl Archetype.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category={
            Tok.KW_OBJECT.value: SymbolType.OBJECT_ARCH,
            Tok.KW_NODE.value: SymbolType.NODE_ARCH,
            Tok.KW_EDGE.value: SymbolType.EDGE_ARCH,
            Tok.KW_WALKER.value: SymbolType.WALKER_ARCH
        }.get(
            self.arch_type.name, SymbolType.TYPE
        )
    );
    ArchSpec.postinit(self);
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}

impl Archetype._get_impl_resolved_body -> list[UniNode] {
    """The nested ternary this replaced lowers natively now, but not here:
    `Archetype.body` is the `T` of the generic `AstImplNeedingNode[T]`, whose
    layout is type-erased, so the narrow can say "a list" and not what of.
    Both copies then unify at `list[jacval]` and the coercion to the declared
    `list[UniNode]` is refused. The typed local below is what pins the element
    type, so the flat form stays until a generic archetype's layout carries
    its argument.""";
    src = self.body.body if isinstance(self.body, ImplDef) else self.body;
    out: list[UniNode] = [];
    if isinstance(src, list) {
        out.extend(src);
    }
    return out;
}

impl Archetype.is_abstract.getter -> bool {
    body = self._get_impl_resolved_body();
    return `any((isinstance(i, Ability) and i.is_abstract) for i in body);
}

impl Archetype.arch_kind.getter -> (str | None) {
    kind_map: dict[SymbolType, str] = {
        SymbolType.NODE_ARCH: "node",
        SymbolType.EDGE_ARCH: "edge",
        SymbolType.WALKER_ARCH: "walker"
    };
    return kind_map.get(self.sym_category);
}

impl Archetype.get_has_vars -> list[HasVar] {
    body = self._get_impl_resolved_body();
    has_vars: list[HasVar] = [];
    for nd in body {
        if not isinstance(nd, ArchHas) {
            continue;
        }
        for has_ in nd.vars {
            if isinstance(has_, HasVar) {
                has_vars.append(has_);
            }
        }
    }
    return has_vars;
}

impl Archetype.get_methods -> list[Ability] {
    body = self._get_impl_resolved_body();
    methods: list[Ability] = [];
    for nd in body {
        if (isinstance(nd, Ability) and nd.is_method) {
            methods.append(nd);
        }
    }
    return methods;
}

impl ImplDef.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=('impl.' + '.'.join([x.sym_name for x in self.target])),
        name_spec=self.create_impl_name_node(),
        sym_category=SymbolType.IMPL
    );
    CodeBlockStmt.postinit(self);
    UniScopeNode._init_scope(self, name=self.sym_name);
    ContextAwareNode.postinit(self);
}

impl ImplDef.create_impl_name_node -> Name {
    ret = Name(
        orig_src=self.target[-1].loc.orig_src,
        name=Tok.NAME.value,
        value=('impl.' + '.'.join([x.sym_name for x in self.target])),
        col_start=self.target[0].loc.col_start,
        col_end=self.target[-1].loc.col_end,
        line=self.target[0].loc.first_line,
        end_line=self.target[-1].loc.last_line,
        pos_start=self.target[0].loc.pos_start,
        pos_end=self.target[-1].loc.pos_end
    );
    ret.set_parent(self);
    return ret;
}

impl SemDef.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=('sem.' + '.'.join([x.sym_name for x in self.target])),
        name_spec=self.create_sem_name_node(),
        sym_category=SymbolType.SEM
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
}

impl SemDef.create_sem_name_node -> Name {
    ret = Name(
        orig_src=self.target[-1].loc.orig_src,
        name=Tok.NAME.value,
        value=('sem.' + '.'.join([x.sym_name for x in self.target])),
        col_start=self.target[0].loc.col_start,
        col_end=self.target[-1].loc.col_end,
        line=self.target[0].loc.first_line,
        end_line=self.target[-1].loc.last_line,
        pos_start=self.target[0].loc.pos_start,
        pos_end=self.target[-1].loc.pos_end
    );
    ret.set_parent(self);
    return ret;
}

impl Enum.postinit -> None {
    UniNode.postinit(self);
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=self.name,
        sym_category=SymbolType.ENUM_ARCH
    );
    ArchSpec.postinit(self);
    UniScopeNode._init_scope(self, name=self.sym_name);
    ContextAwareNode.postinit(self);
}

impl Ability.postinit -> None {
    _raises: list[str] = [];
    self.raises = _raises;
    UniNode.postinit(self);
    if (self.name_ref is None) {
        first_tok = self.kid[0]
            if (self.kid and isinstance(self.kid[0], Token))
            else None;
        if (first_tok is None) {
            raise ValueError('Cannot create synthetic name_ref without location info.');
        }
        if isinstance(self.signature, EventSignature)
            and (self.signature.event.name == Tok.KW_ENTRY) {
            event_type = "entry";
        } else {
            event_type = "exit";
        }
        synthetic_name = f"__ability_{event_type}_{first_tok.line_no}_{first_tok.c_start}__";
        synthetic_name_ref: NameAtom = Name(
            orig_src=first_tok.orig_src,
            name=Tok.NAME,
            value=synthetic_name,
            line=first_tok.line_no,
            end_line=first_tok.end_line,
            col_start=first_tok.c_start,
            col_end=first_tok.c_end,
            pos_start=first_tok.pos_start,
            pos_end=first_tok.pos_end,
            is_enum_stmt=False
        );
        name_spec_for_init: (Name | NameAtom) = synthetic_name_ref;
        self._role_set(NameRefRole, synthetic_name_ref);
    } else {
        name_spec_for_init = self.name_ref;
    }
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.py_resolve_name(),
        name_spec=name_spec_for_init,
        sym_category=SymbolType.ABILITY
    );
    UniScopeNode._init_scope(self, name=self.sym_name);
    CodeBlockStmt.postinit(self);
    ContextAwareNode.postinit(self);
}

impl Ability.is_method.getter -> bool {
    return (self.method_owner is not None);
}

impl Ability.is_cls_method.getter -> bool {
    if self.is_classmethod {
        return True;
    }
    if not self.is_method {
        return False;
    }
    decorators = self.decorators;
    if decorators is not None {
        for dec in decorators {
            if isinstance(dec, Name) and dec.sym_name == 'classmethod' {
                return True;
            }
        }
    }
    return False;
}

impl Ability.is_def.getter -> bool {
    return (not self.signature or isinstance(self.signature, FuncSignature));
}

impl Ability.method_owner.getter -> Archetype | Enum | None {
    found = (
        self.parent
            if (self.parent and isinstance(self.parent, (Archetype, Enum)))
            else None
    )
        or (
            self.parent.decl_link
                if (
                    self.parent
                    and isinstance(self.parent, ImplDef)
                    and isinstance(self.parent.decl_link, (Archetype, Enum))
                )
                else None
        );
    if (found is None) and (self.accessor_kind != "") {
        nodew = self.parent;
        while nodew is not None {
            if isinstance(nodew, (Archetype, Enum)) {
                return nodew;
            }
            nodew = nodew.parent;
        }
    }

    if found is None {
        nodew = self.parent;
        while isinstance(nodew, (IfStmt, ElseStmt, ModuleCode)) {
            nodew = nodew.parent;
        }
        if nodew is not self.parent and isinstance(nodew, (Archetype, Enum)) {
            mod = self.find_parent_of_type(Module);
            if mod is not None and mod.is_raised_from_py {
                return nodew;
            }
        }
    }
    return found;
}

impl Ability.is_genai_ability.getter -> bool {
    return isinstance(self.body, Expr);
}

impl Ability.py_resolve_name -> str {
    if (self.name_ref is None) {
        if isinstance(self.signature, EventSignature)
            and (self.signature.event.name == Tok.KW_ENTRY) {
            event_type = "entry";
        } else {
            event_type = "exit";
        }
        return f"__ability_{event_type}_{self.loc.first_line}_{self.loc.col_start}__";
    } elif isinstance(self.name_ref, Name) {
        return self.name_ref.value;
    } elif isinstance(self.name_ref, SpecialVarRef) {
        return self.name_ref.py_resolve_name();
    } else {
        raise NotImplementedError;
    }
}

impl Ability.event_trigger_type_names -> (list[str] | None) {
    if self.event_triggers is None {
        return None;
    }
    names: list[str] = [];
    for t in self.event_triggers {
        for part in t.mangle().split("|") {
            name = part.strip();
            if name.startswith("type[") and name.endswith("]") {
                name = name[5:-1];
            }
            if name and name not in names {
                names.append(name);
            }
        }
    }
    return names;
}

impl FuncSignature.postinit -> None {
    UniNode.postinit(self);
}

impl FuncSignature.get_parameters -> list[ParamVar] {
    params: list[ParamVar] = [];
    params.extend(self.posonly_params);
    if self.params is not None {
        params.extend(self.params);
    }
    if self.varargs is not None {
        params.append(self.varargs);
    }
    params.extend(self.kwonlyargs);
    if self.kwargs is not None {
        params.append(self.kwargs);
    }
    return params;
}

impl FuncSignature.is_static.getter -> bool {
    return (
        (isinstance(self.parent, Ability) and self.parent.is_static)
        or (
            isinstance(self.parent, ImplDef)
            and isinstance(self.parent.decl_link, Ability)
            and self.parent.decl_link.is_static
        )
    );
}

impl FuncSignature.is_in_py_class.getter -> bool {
    is_archi = self.find_parent_of_type(Archetype);
    is_class = (is_archi is not None) and (is_archi.arch_type.name == Tok.KW_CLASS);
    return (
        (
            isinstance(self.parent, Ability)
            and (self.parent.is_method is not None)
            and is_class
        )
        or (
            isinstance(self.parent, ImplDef)
            and isinstance(self.parent.decl_link, Ability)
            and self.parent.decl_link.is_method
            and is_class
        )
    );
}

impl EventSignature.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}

impl ParamVar.postinit -> None {
    self.param_kind = ParamKind.NORMAL;
    UniNode.postinit(self);
    pv_spec: NameAtom = self.name;
    AstSymbolNode._init_symbol(
        self, sym_name=self.name.value, name_spec=pv_spec, sym_category=SymbolType.VAR
    );
}

impl ParamVar.is_vararg.getter -> bool {
    return bool((self.unpack and (self.unpack.name == Tok.STAR_MUL.name)));
}

impl ParamVar.is_kwargs.getter -> bool {
    return bool((self.unpack and (self.unpack.name == Tok.STAR_POW.name)));
}

impl ArchHas.postinit -> None {
    UniNode.postinit(self);
    CodeBlockStmt.postinit(self);
}

impl HasVar.postinit -> None {
    UniNode.postinit(self);
    hv_spec: NameAtom = self.name;
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.name.value,
        name_spec=hv_spec,
        sym_category=SymbolType.HAS_VAR
    );
}

impl Ability.event_triggers.getter -> (list[TypeBase] | None) {
    return [self->:EventTriggerOf:->];
}

impl Ability.event_triggers.setter(event_triggers: (list[TypeBase] | None)) -> None {
    del [edge self->:EventTriggerOf:->];
    for t in (event_triggers or []) {
        self +>:EventTriggerOf:+> t;
    }
}
