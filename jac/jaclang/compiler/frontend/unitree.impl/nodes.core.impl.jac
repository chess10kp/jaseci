impl UniNode.postinit -> None {
    self.__sub_node_tab = None;
    self._ctx_parent = None;
    self._struct_frozen = False;
    self._in_mod_nodes = [];
    self._gen = None;
    self.ct_pruned = False;
    if self?._role_shapes is None {
        self._role_shapes = None;
    }
    (first_tok, last_tok) = self.resolve_tok_range();
    self.loc = CodeLocInfo(first_tok, last_tok);
}

impl UniNode.walk_kids with TreeWalker entry {
    visit : 0 : [
        k
        for k in self.kid
        if k and not k.ct_pruned
    ];
}

impl UniNode._attach(child: UniNode, role: type[Role]) -> None {
    self +>:(role):+> child;
}

impl UniNode._as_node_list(value: any) -> list[UniNode] {
    return value;
}

impl UniNode._link(kid: Sequence[UniNode], roles: dict[type, any]) -> None {
    if not roles {
        for k in kid {
            if k is not None {
                self +>:Kid:+> k;
            }
        }
        return;
    }

    role_of: dict[int, type] = {};
    extra_roles: dict[int, list[type]] = {};
    if roles {
        shapes: dict[type, str] = self?._role_shapes or {};
        self._role_shapes = shapes;
        for (role, value) in roles.items() {
            if value is None {
                shapes[role] = "none";
            } elif isinstance(value, (list, tuple)) {
                shapes[role] = "many";
                vlist = self._as_node_list(value);
                for v in vlist {
                    if isinstance(v, UniNode) {
                        prev = role_of.get(id(v));
                        if prev is None {
                            role_of[id(v)] = role;
                        } elif prev is not role {
                            extra_roles.setdefault(id(v), []).append(role);
                        }
                    }
                }
            } elif isinstance(value, UniNode) {
                shapes[role] = "one";
                prev = role_of.get(id(value));
                if prev is None {
                    role_of[id(value)] = role;
                } elif prev is not role {
                    extra_roles.setdefault(id(value), []).append(role);
                }
            } else {
                shapes[role] = "none";
            }
        }
    }
    attached: set[int] = set();
    for k in kid {
        if k is not None {
            self +>:Kid:+> k;
            role = role_of.get(id(k));
            if role is not None and id(k) not in attached {
                self._attach(k, role);
                attached.add(id(k));
                if extra_roles {
                    for extra in extra_roles.get(id(k), []) {
                        self._attach(k, extra);
                    }
                }
            }
        }
    }
    for (role, value) in roles.items() {
        if isinstance(value, (list, tuple)) {
            vlist2 = self._as_node_list(value);
            for v in vlist2 {
                if isinstance(v, UniNode) and id(v) not in attached {
                    self._attach(v, role);
                    attached.add(id(v));
                    if extra_roles {
                        for extra in extra_roles.get(id(v), []) {
                            if extra is not role {
                                self._attach(v, extra);
                            }
                        }
                    }
                }
            }
        } elif isinstance(value, UniNode) and id(value) not in attached {
            one: UniNode = value;
            self._attach(one, role);
            attached.add(id(one));
            if extra_roles {
                for extra in extra_roles.get(id(one), []) {
                    if extra is not role {
                        self._attach(one, extra);
                    }
                }
            }
        }
    }
}

impl UniNode._children -> list[UniNode] {
    out: list[UniNode] = self.kid;
    seen: set[int] = {id(k) for k in out};
    for tgt in [self->:Role:->] {
        if id(tgt) not in seen {
            seen.add(id(tgt));
            out.append(tgt);
        }
    }
    return out;
}

impl UniNode.kid.getter -> list[UniNode] {
    return [self->:Kid:->];
}

impl UniNode.parent.getter -> (UniNode | None) {
    found = [self<-:Kid:<-];
    if found {
        return found[-1];
    }
    holders = [self<-:Role:<-];
    return holders[-1] if holders else self._ctx_parent;
}

impl UniNode._role_shaped(role: type[Role], found: list[UniNode]) -> any {
    shape = (self?._role_shapes or {}).get(role, "none");
    if shape == "many" {
        return found;
    }
    if shape == "one" {
        return found[0] if found else None;
    }
    return None;
}

impl UniNode._assert_thawed -> None {
    if self._struct_frozen {
        raise RuntimeError(
            f"structural mutation of frozen node {type(self).__name__}; "
            "call thaw_structure() on the module first"
        );
    }
}

impl UniNode.freeze_structure -> None {
    stack: list[UniNode] = [self];
    seen: set[int] = set();
    while stack {
        nd = stack.pop();
        if id(nd) in seen {
            continue;
        }
        seen.add(id(nd));
        nd._struct_frozen = True;
        for tgt in nd._children() {
            if id(tgt) not in seen {
                stack.append(tgt);
            }
        }
    }
}

impl UniNode.thaw_structure -> None {
    stack: list[UniNode] = [self];
    seen: set[int] = set();
    while stack {
        nd = stack.pop();
        if id(nd) in seen {
            continue;
        }
        seen.add(id(nd));
        nd._struct_frozen = False;
        for tgt in nd._children() {
            if id(tgt) not in seen {
                stack.append(tgt);
            }
        }
    }
}

impl UniNode.structure_thawed -> StructureThaw {
    return StructureThaw(target=self);
}

impl StructureThaw.__enter__ -> StructureThaw {
    self.refreeze = self.target._struct_frozen;
    if self.refreeze {
        self.target.thaw_structure();
    }
    return self;
}

impl StructureThaw.__exit__(exc_type: any, exc: any, tb: any) -> bool {
    if self.refreeze {
        self.target.freeze_structure();
    }
    return False;
}

impl UniNode._role_clear(role: type[Role]) -> None {
    del [edge self->:role:->];
}

impl UniNode._role_set(role: type[Role], value: any) -> None {
    shapes: dict[type, str] = self?._role_shapes or {};
    self._role_shapes = shapes;
    self._role_clear(role);
    if value is None {
        shapes[role] = "none";
    } elif isinstance(value, (list, tuple)) {
        shapes[role] = "many";
        vsrc = self._as_node_list(value);
        for v in vsrc {
            if isinstance(v, UniNode) {
                self._attach(v, role);
            }
        }
    } elif isinstance(value, UniNode) {
        shapes[role] = "one";
        one: UniNode = value;
        self._attach(one, role);
    } else {
        shapes[role] = "none";
    }
    self._invalidate_sub_node_tab();
}

impl UniNode.link_impl(impl_node: UniNode) -> None {
    self +>:ImplOf:+> impl_node;
}

impl UniNode._sub_node_tab.getter -> dict[(type, list[UniNode])] {
    if (self.__sub_node_tab is None) {
        self.__sub_node_tab = {};
        self._construct_sub_node_tab();
    }
    return self.__sub_node_tab;
}

impl UniNode._construct_sub_node_tab -> None {
    for i in self.kid {
        if not i or i.ct_pruned {
            continue;
        }
        for (k, v) in i._sub_node_tab.items() {
            if (k in self.__sub_node_tab) {
                self.__sub_node_tab[k].extend(v);
            } else {
                self.__sub_node_tab[k] = `list(v);
            }
        }
        if (`type(i) in self.__sub_node_tab) {
            self.__sub_node_tab[`type(i)].append(i);
        } else {
            self.__sub_node_tab[`type(i)] = [i];
        }
    }
}

impl UniNode._invalidate_sub_node_tab -> None {
    cur: (UniNode | None) = self;
    while cur is not None {
        cur.__sub_node_tab = None;
        cur = cur.parent;
    }
}

impl UniNode.sym_tab.getter -> UniScopeNode {
    nd: (UniNode | None) = self;

    while nd is not None {
        if isinstance(nd, UniScopeNode) {
            if isinstance(nd, Module) {
                return nd;
            }

            if nd.parent_scope is not None {
                return nd;
            }
        }
        nd = nd.parent;
    }
    raise ValueError("No scope found");
}

impl UniNode.add_kids_left(
    nodes: Sequence[UniNode],
    pos_update: bool = True,
    parent_update: bool = False,
    role: (type[Role] | None) = None
) -> UniNode {
    self.set_kids([*nodes, *self.kid], pos_update=pos_update);
    if role is not None {
        for n in nodes {
            self._attach(n, role);
        }
    }
    return self;
}

impl UniNode.add_kids_right(
    nodes: Sequence[UniNode],
    pos_update: bool = True,
    parent_update: bool = False,
    role: (type[Role] | None) = None
) -> UniNode {
    self.set_kids([*self.kid, *nodes], pos_update=pos_update);
    if role is not None {
        for n in nodes {
            self._attach(n, role);
        }
    }
    return self;
}

impl UniNode.insert_kids_at_pos(
    nodes: Sequence[UniNode],
    pos: int,
    pos_update: bool = True,
    role: (type[Role] | None) = None
) -> UniNode {
    cur = self.kid;
    self.set_kids([*cur[:pos], *nodes, *cur[pos:]], pos_update=pos_update);
    if role is not None {
        for n in nodes {
            self._attach(n, role);
        }
    }
    return self;
}

impl UniNode.set_kids(nodes: Sequence[UniNode], pos_update: bool = True) -> UniNode {
    self._assert_thawed();
    del [edge self->:Kid:->];
    for n in nodes {
        if n is not None {
            self +>:Kid:+> n;
        }
    }
    self._invalidate_sub_node_tab();
    if pos_update {
        self.loc.update_token_range(*self.resolve_tok_range());
    }
    return self;
}

impl UniNode.replace_kid(old: UniNode, new: UniNode) -> UniNode {
    self._assert_thawed();
    roles: list[type] = [];
    for e in [edge self->:Role:->] {
        if getattr(e, "__jac__").target.archetype is old and `type(e) not in roles {
            roles.append(`type(e));
        }
    }
    for role in roles {
        targets = [self->:role:->];
        del [edge self->:role:->];
        for t in targets {
            self._attach(new if t is old else t, role);
        }
    }
    self.set_kids([new if k is old else k for k in self.kid], pos_update=False);
    return self;
}

impl UniNode.detached_copy -> UniNode {
    import copy;

    return copy.deepcopy(self);
}

impl UniNode.__deepcopy__(memo: dict[int, object]) -> UniNode {
    import copy;

    dup = object.__new__(type(self));
    memo[id(self)] = dup;
    for (key, val) in self.__dict__.items() {
        if key == "__jac__" {
            continue;
        }
        if key == "_ctx_parent" or key.endswith("__sub_node_tab") {
            dup.__dict__[key] = None;
        } elif key == "_struct_frozen" {
            dup.__dict__[key] = False;
        } elif key == "orig_src" {
            dup.__dict__[key] = val;
        } else {
            dup.__dict__[key] = copy.deepcopy(val, memo);
        }
    }
    for k in self.kid {
        kc = copy.deepcopy(k, memo);
        dup +>:Kid:+> kc;
    }
    roles: list[type] = [];
    for e in [edge self->:Role:->] {
        if `type(e) not in roles {
            roles.append(`type(e));
        }
    }
    for role in roles {
        for tgt in [self->:role:->] {
            dup._attach(copy.deepcopy(tgt, memo), role);
        }
    }
    return dup;
}

impl UniNode.set_parent(parent: UniNode) -> UniNode {
    self._ctx_parent = parent;
    return self;
}

impl UniNode.resolve_tok_range -> tuple[(Token, Token)] {
    kids = self.kid;
    if kids {
        return (kids[0].loc.first_tok, kids[-1].loc.last_tok);
    } elif isinstance(self, Token) {
        return (self, self);
    } else {
        raise ValueError(f"Empty kid for Token {type(self).__name__}");
    }
}

impl UniNode.gen_token(name: Tok, value: (str | None) = None) -> Token {
    import from jaclang.compiler.frontend.constant { TOKEN_MAP }
    if value is None {
        value = DELIM_MAP[name]
            if (name in DELIM_MAP)
            else TOKEN_MAP.get(name.value, name.value);
    }
    return Token(
        name=name,
        value=value,
        orig_src=self.loc.orig_src,
        col_start=self.loc.col_start,
        col_end=0,
        line=self.loc.first_line,
        end_line=self.loc.last_line,
        pos_start=0,
        pos_end=0
    );
}

impl UniNode.codespace -> CodeContext {
    if isinstance(self, ContextAwareNode) {
        if (self.code_context == CodeContext.CLIENT) {
            return CodeContext.CLIENT;
        }
        if (self.code_context == CodeContext.NATIVE) {
            return CodeContext.NATIVE;
        }
    }
    nd: (UniNode | None) = self.parent;
    while (nd is not None) {
        if isinstance(nd, ContextAwareNode) {
            context = nd.code_context;
            if (context == CodeContext.CLIENT) {
                return CodeContext.CLIENT;
            }
            if (context == CodeContext.NATIVE) {
                return CodeContext.NATIVE;
            }
        }
        if isinstance(nd, Module) {
            if nd.decided_codespace == CodeContext.NATIVE.value {
                return CodeContext.NATIVE;
            }
            if nd.decided_codespace == CodeContext.CLIENT.value {
                return CodeContext.CLIENT;
            }
            return CodeContext.SERVER;
        }
        nd = nd.parent;
    }
    return CodeContext.SERVER;
}

impl UniNode.in_client_context -> bool {
    return self.codespace() == CodeContext.CLIENT;
}

impl UniNode.in_native_context -> bool {
    return self.codespace() == CodeContext.NATIVE;
}

impl Module.absorb_annex_body(stmts: Sequence[UniNode]) -> None {
    self.add_kids_right(stmts, pos_update=False, parent_update=True, role=BodyRole);
}

impl Module.declares_codespace(ctx: CodeContext, path_hint: str = '') -> bool {
    if ctx != CodeContext.SERVER and self.decided_codespace == ctx.value {
        return True;
    }
    if self.body {
        for _stmt in self.body {
            if ctx != CodeContext.SERVER
                and isinstance(_stmt, ContextAwareNode)
                and _stmt.code_context == ctx {
                return True;
            }
        }
    }
    return False;
}

impl UniNode.flatten -> list[UniNode] {
    ret: list[UniNode] = [self];
    for k in self.kid {
        if k.ct_pruned {
            continue;
        }
        ret += k.flatten();
    }
    return ret;
}

impl Symbol.init(
    defn: NameAtom,
    access: SymbolAccess,
    parent_tab: (UniScopeNode | None) = None,
    imported: bool = False
) -> None {
    self.name = defn.sym_name;
    self.imported = imported;
    self.access = access;
    self.semstr = '';
    self +>:Defines:+> defn;
    defn.sym = self;
    if parent_tab is not None {
        parent_tab +>:InScope:+> self;
    }
}

impl Symbol.defn.getter -> list[NameAtom] {
    return [self->:Defines:->];
}

impl Symbol.uses.getter -> list[NameAtom] {
    return [self->:Uses:->];
}

impl Symbol.parent_tab.getter -> (UniScopeNode | None) {
    found = [self<-:InScope:<-];
    return found[0] if found else None;
}

impl Symbol.decl.getter -> NameAtom {
    return self.defn[0];
}

impl Symbol.sym_name.getter -> str {
    return self.decl.sym_name;
}

impl Symbol.sym_type.getter -> SymbolType {
    return self.decl.sym_category;
}

impl Symbol.sym_dotted_name.getter -> str {
    out = [self.defn[0].sym_name];
    current_tab: (UniScopeNode | None) = self.parent_tab;
    while (current_tab is not None) {
        out.append(current_tab.scope_name);
        current_tab = current_tab.parent_scope;
    }
    out.reverse();
    return '.'.join(out);
}

impl Symbol.symbol_table.getter -> (UniScopeNode | None) {
    if self.parent_tab {
        return self.parent_tab.find_scope(self.sym_name);
    }
    return None;
}

impl Symbol.binding_kind.getter -> BindingKind {
    for cur in import_chain_of(self) {
        decl = cur.decl;
        item = decl.parent if isinstance(decl.parent, ModuleItem) else None;
        if item is not None and item.from_parent.is_typed {
            return BindingKind.TYPE;
        }
        if cur._binding_kind is not None {
            return cur._binding_kind;
        }
        if item is None {
            return binding_kind_of_decl(decl);
        }
    }
    return BindingKind.VALUE;
}

impl Symbol.binding_kind.setter(binding_kind: BindingKind) -> None {
    self._binding_kind = binding_kind;
}

impl Symbol.storage.getter -> SymbolStorage {
    owner = self.parent_tab;
    while (owner is not None and not UniScopeNode.is_python_scoping(owner)) {
        owner = owner.parent_scope;
    }
    if (owner is None) or isinstance(owner, Module) {
        return SymbolStorage.MODULE_GLOBAL;
    }
    if isinstance(owner, (Archetype, Enum)) {
        return SymbolStorage.CLASS_FIELD;
    }

    if isinstance(self.decl.name_of, ParamVar) {
        return SymbolStorage.PARAM;
    }

    def_scope: (UniNode | None) = self.decl.parent;
    while (
        def_scope is not None
        and not UniScopeNode.is_python_scoping(def_scope)
        and not isinstance(def_scope, LambdaExpr)
    ) {
        def_scope = def_scope.parent;
    }
    for use in self.uses {
        cur = use.parent;
        while (
            cur is not None
            and not UniScopeNode.is_python_scoping(cur)
            and not isinstance(cur, LambdaExpr)
        ) {
            cur = cur.parent;
        }
        if cur is None or same_lexical_scope(cur, def_scope) {
            continue;
        }
        return SymbolStorage.CAPTURED;
    }
    return SymbolStorage.LOCAL;
}

impl Symbol.add_defn(nd: NameAtom) -> None {
    self +>:Defines:+> nd;
    nd.sym = self;
}

impl Symbol.add_use(nd: NameAtom) -> None {
    nd.sym = self;

    if self.in_stub_scope() {
        return;
    }
    self +>:Uses:+> nd;
}

impl Symbol.in_stub_scope -> bool {
    memo = self._in_stub_scope;
    if memo is not None {
        return memo;
    }
    found = False;
    cur: (UniScopeNode | None) = self.parent_tab;
    while cur is not None {
        if isinstance(cur, Module) {
            found = cur.stub_only;
            break;
        }
        cur = cur.parent_scope;
    }
    self._in_stub_scope = found;
    return found;
}

impl Symbol.__repr__ -> str {
    return f"Symbol({self.sym_name}, {self.sym_type}, {self.access},{self.defn})";
}

impl Module.set_code_context(context: CodeContext) -> None {
    self.decided_codespace = context.value;
    for elem in self.body {
        if isinstance(elem, ContextAwareNode) {
            elem.code_context = context;
            if isinstance(elem, ModuleCode) and elem.body {
                for inner in elem.body {
                    if isinstance(inner, ContextAwareNode) {
                        inner.code_context = context;
                    }
                }
            }
        }
    }
}

impl UniScopeNode._init_scope(
    name: str, parent_scope: (UniScopeNode | None) = None
) -> None {
    self.scope_name = name;
    self.implicit_rebinds: dict[(str, Symbol)] = {};
    self._names_index: dict[(str, Symbol)] = {};
    self._overload_index: dict[(str, list[Symbol])] = {};
    if parent_scope is not None {
        self.parent_scope = parent_scope;
    }
}

impl UniScopeNode.parent_scope.getter -> (UniScopeNode | None) {
    found = [self<-:ScopeChild:<-];
    if found {
        return found[-1];
    }
    owners = [self->:ScopeParent:->];
    return owners[-1] if owners else None;
}

impl UniScopeNode.parent_scope.setter(parent_scope: (UniScopeNode | None)) {
    del [edge self<-:ScopeChild:<-];
    del [edge self->:ScopeParent:->];
    if parent_scope is not None {
        self +>:ScopeParent:+> parent_scope;
    }
}

impl UniScopeNode.kid_scope.getter -> list[UniScopeNode] {
    return [self->:ScopeChild:->];
}

impl UniScopeNode.names_in_scope.getter -> dict[(str, Symbol)] {
    return self?._names_index or {};
}

impl UniScopeNode.names_in_scope_overload.getter -> dict[(str, list[Symbol])] {
    return self?._overload_index or {};
}

impl UniScopeNode.lookup(
    name: str, deep: bool = True, incl_inner_scope: bool = False
) -> (Symbol | None) {
    if (name in self.names_in_scope) {
        return self.names_in_scope[name];
    }
    if (
        (deep and self.parent_scope)
        and (sym := self.parent_scope.lookup(name, deep, incl_inner_scope))
    ) {
        return sym;
    }
    if incl_inner_scope {
        for kid in self.kid_scope {
            if UniScopeNode.is_python_scoping(kid) {
                continue;
            }
            if ((sym := kid.lookup(name, False, True)) is not None) {
                return sym;
            }
        }
    }

    impl_def: ImplDef | None = (
        self if isinstance(self, ImplDef) else self.find_parent_of_type(ImplDef)
    );
    if (impl_def and impl_def.decl_link and impl_def.decl_link.sym_tab) {
        return impl_def.decl_link.sym_tab.lookup(
            name, deep=True, incl_inner_scope=False
        );
    }
    return None;
}

impl UniScopeNode.lookup_all(name: str, deep: bool = True) -> list[Symbol] {
    result: list[Symbol] = [];
    if name in self.names_in_scope {
        result.append(self.names_in_scope[name]);
    }
    if name in self.names_in_scope_overload {
        result.extend(self.names_in_scope_overload[name]);
    }
    if result {
        return result;
    }
    if deep and self.parent_scope {
        return self.parent_scope.lookup_all(name, deep);
    }
    return result;
}

impl UniScopeNode.insert(
    nd: AstSymbolNode,
    access_spec: AstAccessNode | None | SymbolAccess = None,
    single: bool = False,
    force_overwrite: bool = False,
    imported: bool = False
) -> (UniNode | None) {
    collision = self.names_in_scope[nd.sym_name].defn[-1]
        if (single and (nd.sym_name in self.names_in_scope))
        else None;
    symbol = nd.name_spec.create_symbol(
        access=access_spec
            if isinstance(access_spec, SymbolAccess)
            else access_spec.access_type if access_spec else SymbolAccess.PUBLIC,
        parent_tab=self,
        imported=imported
    );
    current = self.names_in_scope;
    if (nd.sym_name in current) {
        self +>:ScopeOverload:+> symbol;
        self._overload_index.setdefault(nd.sym_name, []).append(symbol);
    }
    if (force_overwrite or (nd.sym_name not in current)) {
        prev = current.get(nd.sym_name);
        if prev is not None {
            self._drop_primary(prev);
        }
        self +>:ScopePrimary:+> symbol;
        self._names_index[nd.sym_name] = symbol;
    } else {
        current[nd.sym_name].add_defn(nd.name_spec);
    }
    return collision;
}

impl UniScopeNode.find_scope(name: str) -> (UniScopeNode | None) {
    for k in self.kid_scope {
        if (k.scope_name == name) {
            return k;
        }
    }
    return None;
}

impl UniScopeNode.get_enclosing_captures -> list[Symbol] {
    out: list[Symbol] = [];
    names: list[Name] = self.get_all_sub_nodes(Name);
    names.extend(self.get_all_sub_nodes(SpecialVarRef));
    for name in names {
        if is_identifier_slot(name) {
            continue;
        }
        sym = name.sym;
        if (sym is None) {
            continue;
        }
        tab = sym.parent_tab;
        if name.value == "super" and tab is not None {
            receiver = tab.names_in_scope.get("self");
            if receiver is not None {
                sym = receiver;
                tab = sym.parent_tab;
            }
        }
        if (
            (tab is None)
            or same_lexical_scope(tab, self)
            or not isinstance(tab, (Ability, ImplDef, LambdaExpr, Test))
        ) {
            continue;
        }

        scope = self.parent_scope;
        while (scope is not None) {
            if same_lexical_scope(scope, tab) {
                if sym not in out {
                    out.append(sym);
                }
                break;
            }
            scope = scope.parent_scope;
        }
    }
    return out;
}

impl UniScopeNode.set_primary_names(syms: dict[(str, Symbol)]) -> None {
    del [edge self->:ScopePrimary:->];
    for (key, sym) in syms.items() {
        self +>:ScopePrimary:+> sym;
    }
    self._names_index = dict(syms);
}

impl UniScopeNode.adopt_primary(sym: Symbol, alias: str = "") -> None {
    key = alias or sym.name;
    prev = self._names_index.get(key);
    if prev is not None {
        self._drop_primary(prev);
    }
    self +>:ScopePrimary:+> sym;
    self._names_index[key] = sym;
}

impl UniScopeNode._drop_primary(sym: Symbol) -> None {
    edges = [edge self->:ScopePrimary:->];
    targets = [self->:ScopePrimary:->];
    for i in range(len(targets)) {
        target: Symbol = targets[i];
        if target is sym {
            edge_to_drop = edges[i];
            del edge_to_drop;
            break;
        }
    }
}

impl UniScopeNode.link_kid_scope(key_node: UniScopeNode) -> UniScopeNode {
    del [edge key_node<-:ScopeChild:<-];
    del [edge key_node->:ScopeParent:->];
    self +>:ScopeChild:+> key_node;
    return key_node;
}

impl UniScopeNode.def_insert(
    nd: AstSymbolNode,
    access_spec: AstAccessNode | None | SymbolAccess = None,
    single_decl: (str | None) = None,
    force_overwrite: bool = False,
    imported: bool = False
) -> (Symbol | None) {
    if (nd.sym and (self == nd.sym.parent_tab)) {
        return nd.sym;
    }
    self.insert(
        nd=nd,
        single=(single_decl is not None),
        access_spec=access_spec,
        force_overwrite=force_overwrite,
        imported=imported
    );
    self.update_expr_ctx_for_def(nd);
    return nd.sym;
}

impl UniScopeNode.chain_def_insert(node_list: list[AstSymbolNode]) -> None {
    if not node_list {
        return;
    }
    cur_sym_tab: (UniScopeNode | None) = node_list[0].sym_tab;
    node_list[-1].name_spec.expr_ctx = ExprCtx.STORE;
    if isinstance(node_list[-1].name_spec, AstSymbolNode) {
        node_list[-1].name_spec.expr_ctx = ExprCtx.STORE;
    }
    node_list = node_list[:-1];
    for i in node_list {
        cur_sym_tab = lookup.decl.sym_tab
            if (lookup := self.use_lookup(i, sym_table=cur_sym_tab))
            else None;
    }
}

impl UniScopeNode.use_lookup(
    nd: AstSymbolNode, sym_table: (UniScopeNode | None) = None
) -> (Symbol | None) {
    if nd.sym {
        return nd.sym;
    }
    if not sym_table {
        sym_table = nd.sym_tab;
    }
    if sym_table {
        found = sym_table.lookup(name=nd.sym_name, deep=True);
        if found {
            found.add_use(nd.name_spec);
        }
    }
    return nd.sym;
}

impl UniScopeNode.chain_use_lookup(node_list: Sequence[AstSymbolNode]) -> None {
    if not node_list {
        return;
    }
    cur_sym_tab: (UniScopeNode | None) = node_list[0].sym_tab;
    for i in node_list {
        if (cur_sym_tab is None) {
            break;
        }
        found = self.use_lookup(i, sym_table=cur_sym_tab);
        if found {
            decl_tab = found.decl.sym_tab;
            cur_sym_tab = decl_tab;
            if decl_tab is not None and (decl_tab.scope_name != i.sym_name) {
                t = decl_tab.find_scope(i.sym_name);
                if t {
                    cur_sym_tab = t;
                }
            }
        } else {
            cur_sym_tab = None;
        }
    }
}

impl UniScopeNode._fix_store_ctx(item: UniNode) -> None {
    if isinstance(item, UnaryExpr) {
        if isinstance(item.operand, AstSymbolNode) {
            item.operand.name_spec.expr_ctx = ExprCtx.STORE;
        }
    } elif isinstance(item, (TupleVal, ListVal)) {
        for i in item.values {
            if isinstance(i, AstSymbolNode) {
                i.name_spec.expr_ctx = ExprCtx.STORE;
            } elif isinstance(i, AtomTrailer) {
                self.chain_def_insert(i.as_attr_list);
            }
            if isinstance(i, (TupleVal, ListVal, UnaryExpr)) {
                self._fix_store_ctx(i);
            }
        }
    }
}

impl UniScopeNode.update_expr_ctx_for_def(nd: AstSymbolNode) -> None {
    nd.name_spec.expr_ctx = ExprCtx.STORE;
    if isinstance(nd, (TupleVal, ListVal)) and nd.values {
        self._fix_store_ctx(nd);
    }
}

impl UniScopeNode.__repr__ -> str {
    out = f"{self.scope_name} {super().__repr__()}:\n";
    for (k, v) in self.names_in_scope.items() {
        out += f"    {k}: {v}\n";
    }
    return out;
}

impl AstDocNode.set_doc(elem_doc: (String | None)) -> None {
    self._role_set(DocRole, elem_doc);
}

impl AstSymbolNode._init_symbol(
    sym_name: str, name_spec: NameAtom, sym_category: SymbolType
) -> None {
    self.name_spec = name_spec;
    self.name_spec.bind_sym(self, sym_name, sym_category);
    self.semstr = '';
}

impl AstSymbolNode.sym.getter -> (Symbol | None) {
    return self.name_spec.sym;
}

impl AstSymbolNode.sym_name.getter -> str {
    return self.name_spec.sym_name;
}

impl AstSymbolNode.sym_category.getter -> SymbolType {
    return self.name_spec.sym_category;
}

impl AstSymbolNode.expr_ctx.getter -> ExprCtx {
    return self.name_spec.expr_ctx;
}

impl AstSymbolNode.type_sym_tab.getter -> (UniScopeNode | None) {
    return self.name_spec.type_sym_tab;
}

impl AstSymbolStubNode._init_stub(sym_type: SymbolType) -> None {
    AstSymbolNode._init_symbol(
        self,
        sym_name=f"[{self.__class__.__name__}]",
        name_spec=Name.gen_stub_from_node(self, f"[{self.__class__.__name__}]"),
        sym_category=sym_type
    );
}

impl AstAccessNode.access_type.getter -> SymbolAccess {
    return SymbolAccess.PRIVATE
        if (self.access and (self.access.tag.name == Tok.KW_PRIV))
        else SymbolAccess.PROTECTED
            if (self.access and (self.access.tag.name == Tok.KW_PROT))
            else SymbolAccess.PUBLIC;
}

impl AstAccessNode.public_access.getter -> bool {
    return (self.access_type == SymbolAccess.PUBLIC);
}

impl ContextAwareNode.postinit -> None {}

impl ContextAwareNode.code_context.getter -> CodeContext {
    found = [self->:PlacedIn:->];
    if found {
        target: Codespace = found[0];
        return CodeContext(target.kind);
    }
    enclosing = self.find_parent_of_type(ContextAwareNode);
    return enclosing.code_context if enclosing is not None else CodeContext.SERVER;
}

impl ContextAwareNode.code_context.setter(code_context: CodeContext) {
    del [edge self->:PlacedIn:->];
    self +>:PlacedIn:+> codespace_node(code_context.value);
}

impl Module.decided_codespace.getter -> str {
    found = [self->:DecidedCodespace:->];
    if found {
        target: Codespace = found[0];
        return target.kind;
    }
    return "";
}

impl Module.decided_codespace.setter(decided_codespace: str) {
    del [edge self->:DecidedCodespace:->];
    if decided_codespace {
        self +>:DecidedCodespace:+> codespace_node(decided_codespace);
    }
}

impl UniCFGNode.postinit -> None {
    _syms: set[str] = set();
    self.affected_symbols = _syms;
}

impl UniCFGNode.bb_out.getter -> list[UniCFGNode] {
    return [self->:CfgSucc:->];
}

impl UniCFGNode.bb_in.getter -> list[UniCFGNode] {
    return [self<-:CfgSucc:<-];
}

impl UniCFGNode.cfg_link(target: UniCFGNode) -> None {
    if target not in [self->:CfgSucc:->] {
        self +>:CfgSucc:+> target;
    }
}

impl ConditionalNode.sc_true_target.getter -> (UniCFGNode | None) {
    found = [self->:CfgTrue:->];
    return found[0] if found else None;
}

impl ConditionalNode.sc_true_target.setter(sc_true_target: (UniCFGNode | None)) {
    del [edge self->:CfgTrue:->];
    if sc_true_target is not None {
        self +>:CfgTrue:+> sc_true_target;
    }
}

impl ConditionalNode.sc_false_target.getter -> (UniCFGNode | None) {
    found = [self->:CfgFalse:->];
    return found[0] if found else None;
}

impl ConditionalNode.sc_false_target.setter(sc_false_target: (UniCFGNode | None)) {
    del [edge self->:CfgFalse:->];
    if sc_false_target is not None {
        self +>:CfgFalse:+> sc_false_target;
    }
}

impl ConditionalNode.postinit -> None {
    UniCFGNode.postinit(self);
}

impl UniCFGNode.get_head -> UniCFGNode {
    nd = self;
    while (
        nd.bb_in
        and (len(nd.bb_in) == 1)
        and not isinstance(
            nd,
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and not isinstance(
            nd.bb_in[0],
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and nd.bb_in[0].bb_out
        and (len(nd.bb_in[0].bb_out) == 1)
    ) {
        nd = nd.bb_in[0];
    }
    return nd;
}

impl UniCFGNode.get_tail -> UniCFGNode {
    nd = self;
    while (
        nd.bb_out
        and (len(nd.bb_out) == 1)
        and not isinstance(
            nd,
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and not isinstance(
            nd.bb_out[0],
            (
                InForStmt,
                IterForStmt,
                WhileStmt,
                ForeverStmt,
                ConditionalNode,
                InnerCompr
            )
        )
        and nd.bb_out[0].bb_in
        and (len(nd.bb_out[0].bb_in) == 1)
    ) {
        nd = nd.bb_out[0];
    }
    return nd;
}

impl AstImplNeedingNode.needs_impl.getter -> bool {
    return (self.body is None);
}

impl Module.postinit -> None {
    self.src_terminals = self.terminals;
    self.codespace_inferred = False;
    self.ct_file_deps = [];
    self.ct_body_deps = [];
    self.rc_last_use = {};
    self.rc_scope_cleanup = {};
    _rc_move_in: set[int] = set();
    self.rc_move_in = _rc_move_in;
    _own_move_sites: set[int] = set();
    self.own_move_sites = _own_move_sites;
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=self.name);
}

impl Module.annexable_by.getter -> (str | None) {
    if self.stub_only {
        return None;
    }
    import from jaclang.compiler.driver.bccache { discover_base_file }
    return discover_base_file(self.loc.mod_path);
}

impl ProgramModule.postinit -> None {
    UniNode.postinit(self);
    main = self.main_mod;
    self.hub = {self.loc.mod_path: main} if main else {};
}

impl Token.init(
    orig_src: Source,
    name: str,
    value: str,
    line: int,
    end_line: int,
    col_start: int,
    col_end: int,
    pos_start: int,
    pos_end: int
) -> None {
    self.orig_src = orig_src;
    self.name = name;
    self.value = value;
    self.line_no = line;
    self.end_line = end_line;
    self.c_start = col_start;
    self.c_end = col_end;
    self.pos_start = pos_start;
    self.pos_end = pos_end;
    self._is_synthetic = False;
    UniNode.postinit(self);
}

impl Token.__repr__ -> str {
    return f"Token({self.name}, {self.value}, {self.loc})";
}

impl EmptyToken.init(orig_src: (Source | None) = None) -> None {
    _src = orig_src;
    if _src is None {
        _src = Source('', '');
    }
    super.init(
        name='EmptyToken',
        orig_src=_src,
        value='',
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
}

impl CommentToken.init(
    orig_src: Source,
    name: str,
    value: str,
    line: int,
    end_line: int,
    col_start: int,
    col_end: int,
    pos_start: int,
    pos_end: int,
    kid: Sequence[UniNode]
) -> None {
    Token.init(
        self,
        orig_src=orig_src,
        name=name,
        value=value,
        line=line,
        end_line=end_line,
        col_start=col_start,
        col_end=col_end,
        pos_start=pos_start,
        pos_end=pos_end
    );
    self._link(kid, {});
    (first_tok, last_tok) = self.resolve_tok_range();
    self.loc = CodeLocInfo(first_tok, last_tok);
}

impl Source.init(source: str, mod_path: str) -> None {
    super.init(orig_src=self);
    self.value = source;
    self._hash = "";
    self.file_path = mod_path;
    self.comments = [];
    self.inline_suppressions = {};
}

impl Source.hash.getter -> str {
    if not self._hash {
        h = 0xCBF29CE484222325;
        for b in self.value.encode() {
            h = ((h ^ b) * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF;
        }
        self._hash = f"{h:016x}";
    }
    return self._hash;
}

impl Source.code.getter -> str {
    return self.value;
}

impl PythonModuleAst.init(ast: object, orig_src: Source) -> None {
    super.init();
    self.ast = ast;
    self.orig_src = orig_src;
    self.file_path = orig_src.file_path;
}

impl UniNode.gen.getter -> CodeGenTarget {
    if (self._gen is None) {
        import from jaclang.compiler.frontend.codeinfo { CodeGenTarget as _CGT }
        self._gen = _CGT();
    }
    return self._gen;
}

impl UniNode.gen.setter(value: CodeGenTarget) {
    self._gen = value;
}

impl AstTypedVarNode.type.getter -> (TypeBase | None) {
    found = [self->:TypeOf:->];
    return found[0] if found else None;
}

impl AstTypedVarNode.type.setter(type: (TypeBase | None)) -> None {
    del [edge self->:TypeOf:->];
    if type is not None {
        self +>:TypeOf:+> type;
    }
}
