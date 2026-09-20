impl TypeCheckPass._body_always_returns(body: list[CodeBlockStmt]) -> bool {
    return self.evaluator._collect_return_types(body, []);
}

impl TypeCheckPass._check_bare_generic(
    ann_node: UniNode, ty: object, shape: (UniNode | None) = None, nested: bool = False
) -> None {
    at = shape if nested else ann_node;
    if isinstance(ty, UnionType) and ty.types {
        leaves = self._union_leaves(at);
        for branch in ty.types {
            match_at: (UniNode | None) = None;
            if isinstance(branch, ClassType) {
                for leaf in leaves {
                    if self._written_type_args(leaf, branch) is not None {
                        match_at = leaf;
                        break;
                    }
                }
            }
            self._check_bare_generic(ann_node, branch, match_at, True);
        }
        return;
    }
    if not isinstance(ty, ClassType) or not ty.shared {
        return;
    }
    arg_nodes = self._written_type_args(at, ty);
    type_args: list[TypeBase] = ty.private.type_args if ty.private else [];
    if ty.shared.type_params and not type_args {
        if arg_nodes is None {
            if ty.is_builtin(BARE_GENERIC_REQUIRED) {
                self.ctx.emit(E1036, node_override=ann_node, type=ty.shared.class_name);
            } else {
                self.ctx.emit(W1036, node_override=ann_node, type=ty.shared.class_name);
            }
        }
        return;
    }
    for (i, arg) in enumerate(type_args) {
        child: (UniNode | None) = None;
        if arg_nodes is not None and len(arg_nodes) == len(type_args) {
            child = arg_nodes[i];
        }
        self._check_bare_generic(ann_node, arg, child, True);
    }
}

impl TypeCheckPass._written_type_args(
    shape: (UniNode | None), ty: ClassType
) -> (list[Expr] | None) {
    if not (isinstance(shape, AtomTrailer) and isinstance(shape.right, IndexSlice)) {
        return None;
    }
    target_ty = self.evaluator.get_type_of_expression(shape.target);
    if not (
        isinstance(target_ty, ClassType)
        and target_ty.shared
        and target_ty.shared.same_class(ty.shared)
    ) {
        return None;
    }
    return self._index_args(shape.right);
}

impl TypeCheckPass._index_args(index: IndexSlice) -> list[Expr] {
    start = index.slices[0].start if index.slices else None;
    if start is None {
        return [];
    }
    if isinstance(start, TupleVal) {
        return [
            v
            for v in (start.values or [])
            if isinstance(v, Expr)
        ];
    }
    return [start];
}

impl TypeCheckPass._union_leaves(shape: (UniNode | None)) -> list[UniNode] {
    if shape is None {
        return [];
    }
    if isinstance(shape, BinaryExpr)
        and isinstance(shape.op, Token)
        and shape.op.name == Tok.BW_OR {
        return self._union_leaves(shape.left) + self._union_leaves(shape.right);
    }
    if isinstance(shape, AtomTrailer)
        and isinstance(shape.right, IndexSlice)
        and self._names_union_form(shape.target) {
        leaves: list[UniNode] = [];
        for arg in self._index_args(shape.right) {
            leaves.extend(self._union_leaves(arg));
        }
        return leaves;
    }
    return [shape];
}

impl TypeCheckPass._names_union_form(target: Expr) -> bool {
    name: UniNode = target;
    if isinstance(target, AtomTrailer) and target.is_attr {
        name = target.right;
    }
    return isinstance(name, Name) and name.value in ("Optional", "Union");
}

impl TypeCheckPass._check_unresolved_lambda_params -> None {
    if self.module is None {
        return;
    }
    for lam in self.module.get_all_sub_nodes(LambdaExpr) {
        if lam.signature is None {
            continue;
        }
        for param in lam.signature.get_parameters() {
            if param.type_tag is not None {
                continue;
            }

            resolved = param.name.type;
            if resolved is None or isinstance(resolved, UnknownType) {
                self.ctx.emit(E1119, node_override=param.name, name=param.name.value);
            }
        }
    }
}

impl TypeCheckPass._check_explicit_any(ann_node: UniNode) -> None {
    if isinstance(ann_node, BuiltinType) and ann_node.value == "any" {
        self.ctx.emit(W1037, node_override=ann_node);
    }
    for sub in ann_node.get_all_sub_nodes(BuiltinType) {
        if sub.value == "any" {
            self.ctx.emit(W1037, node_override=sub);
        }
    }

    names = ann_node.get_all_sub_nodes(Name);
    if isinstance(ann_node, Name) {
        names = [ann_node] + names;
    }
    for nm in names {
        if nm.sym_name != "Any" {
            continue;
        }

        resolve_target: Expr = nm;
        parent = nm.parent;
        if (
            isinstance(parent, AtomTrailer) and parent.is_attr and (parent.right is nm)
        ) {
            resolve_target = parent;
        }
        if self.evaluator.is_explicit_any(
            self.evaluator.get_type_of_expression(resolve_target)
        ) {
            self.ctx.emit(W1037, node_override=nm);
        }
    }
}

impl TypeCheckPass._insert_builtin_symbols -> None {
    if (self.module == self.evaluator.builtins_module) {
        return;
    }
    if (self.module.parent_scope is not None) {
        return;
    }
    self.module.parent_scope = self.evaluator.builtins_module;
}

impl TypeCheckPass._client_state_field_owner(nd: HasVar) -> (Ability | None) {
    if not isinstance(nd.parent, ArchHas) {
        return None;
    }
    owner: (UniNode | None) = nd.parent;
    while (owner is not None and not isinstance(owner, (Ability, Archetype))) {
        owner = owner.parent;
    }
    if not isinstance(owner, Ability) {
        return None;
    }
    if not nd.in_client_context() {
        return None;
    }
    for probe in (nd.value, nd.type_tag.tag if nd.type_tag else None) {
        cur: (UniNode | None) = probe;
        while isinstance(cur, (FuncCall, AtomTrailer)) {
            cur = cur.target;
        }
        if isinstance(cur, Name) and cur.value == 'Ref' {
            return None;
        }
    }
    return owner;
}

impl TypeCheckPass._install_client_state_setters -> None {
    import from jaclang.compiler.frontend.constant { client_state_setter_name }
    import from jaclang.compiler.types.types { create_callable_type }
    mod = self.module;
    if mod is None {
        return;
    }

    none_type = self.evaluator._convert_to_instance(self.evaluator.get_none_type());
    for nd in mod.get_all_sub_nodes(typ=HasVar) {
        owner = self._client_state_field_owner(nd);
        if owner is None {
            continue;
        }
        setter_name = client_state_setter_name(nd.name.value);
        if not setter_name {
            continue;
        }
        scope = nd.sym_tab;
        if (scope is None) or (scope.names_in_scope.get(setter_name) is not None) {
            continue;
        }
        sym = nd.sym;
        if sym is None {
            continue;
        }
        stub = Name.gen_stub_from_node(nd.name, setter_name);
        stub.type = create_callable_type(
            [self.evaluator.get_type_of_symbol(sym)], none_type
        );
        scope.def_insert(stub);
    }
}

impl TypeCheckPass.postinit -> None {
    self.evaluator = self.prog.get_type_evaluator();
}

impl TypeCheckPass.initialize with entry {
    if self.ctx.nested_depth {
        return;
    }
    self.ctx.resources.callback(setattr, self.evaluator, '_pass', self.evaluator._pass);
    self.ctx.resources.callback(
        setattr, self.evaluator, 'ct_quiet', self.evaluator.ct_quiet
    );
    self.evaluator._pass = self.ctx;
    self.evaluator.ct_quiet = False;
}

impl TypeCheckPass.prepare with entry {
    if self.ctx.nested_depth {
        return;
    }
    self._insert_builtin_symbols();
    self._install_client_state_setters();
}

impl TypeCheckPass.finish with exit {
    if self.ctx.nested_depth {
        return;
    }
    self._check_unresolved_lambda_params();
    self._stamp_fixed_width();
}
