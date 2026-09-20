impl TypeCheckPass.exit_jsx_element with JsxElement exit {
    self.evaluator.get_type_of_expression(here);
}

impl TypeCheckPass._jsx_component_params(nd: Ability) -> (list[ParamVar] | None) {
    if (
        not isinstance(nd.signature, FuncSignature)
        or nd.find_parent_of_type(ImplDef) is not None
        or not return_type_is_jsx(nd.signature.return_type)
        or nd.name_spec.sym_name.startswith("__jac")
    ) {
        return None;
    }
    return [
        p
        for p in nd.signature.get_parameters()
        if isinstance(p.name, Name) and p.name.value not in ("self", "cls")
    ];
}

impl TypeCheckPass._is_ref_forward_tail_param(p: ParamVar) -> bool {
    if p.type_tag is None {
        return False;
    }
    cur: UniNode | None = p.type_tag.tag;
    while isinstance(cur, (FuncCall, AtomTrailer)) {
        cur = cur.target;
    }
    return isinstance(cur, Name) and cur.value == "Ref";
}

impl TypeCheckPass._check_props_bundle_is_exclusive(
    nd: Ability, comp_params: list[ParamVar]
) -> None {
    if len(comp_params) < 2 {
        return;
    }

    if (
        len(comp_params) == 2
        and isinstance(comp_params[0].name, Name)
        and comp_params[0].name.value == "props"
        and self._is_ref_forward_tail_param(comp_params[1])
    ) {
        return;
    }
    component = nd.name_spec.sym_name;
    for p in comp_params {
        if isinstance(p.name, Name) and p.name.value == "props" {
            self.ctx.emit(E1109, node_override=p, name=component);
            return;
        }
    }
}

impl TypeCheckPass._check_event_trigger_archetype(nd: Ability) -> None {
    sig = nd.signature;
    if not isinstance(sig, EventSignature) or sig.arch_tag_info is None {
        return;
    }
    owner = nd.method_owner;
    if not isinstance(owner, Archetype) {
        return;
    }
    owner_kind = owner.arch_kind;
    if owner_kind is None {
        return;
    }
    walker_owner = owner_kind == "walker";

    def is_valid(t: TypeBase) -> bool {
        if t.is_any_type() or isinstance(t, UnknownType) {
            return True;
        }
        if isinstance(t, UnionType) {
            return all(is_valid(m) for m in t.types);
        }
        if isinstance(t, ClassType) {
            if walker_owner {
                return t.is_node_type() or t.is_edge_type();
            }
            return t.is_walker_type();
        }
        return False;
    }

    def collect_union_leaves(expr: Expr) -> list[Expr] {
        if (
            isinstance(expr, BinaryExpr)
            and isinstance(expr.op, Token)
            and expr.op.name == Tok.BW_OR
        ) {
            return collect_union_leaves(expr.left) + collect_union_leaves(expr.right);
        }
        return [expr];
    }

    targets: list[Expr] = (
        [
            v
            for v in sig.arch_tag_info.values
            if isinstance(v, Expr)
        ]
            if (isinstance(sig.arch_tag_info, TupleVal) and sig.arch_tag_info.values)
            else collect_union_leaves(sig.arch_tag_info)
    );
    err = E1116 if walker_owner else E1117;
    resolved: list[TypeBase] = [];
    for arg in targets {
        ty = self.evaluator.get_type_of_expression(arg);
        resolved.append(ty);

        if isinstance(arg, Name) and arg.value == "root" {
            self.ctx.emit(err, node_override=arg, type="root");
            continue;
        }
        if isinstance(ty, ClassType) and ty.is_instance() {
            label = arg.value if isinstance(arg, Name) else str(ty);
            self.ctx.emit(err, node_override=arg, type=label);
            continue;
        }
        if not is_valid(ty) {
            self.ctx.emit(err, node_override=arg, type=str(ty));
        }
    }

    nd.event_triggers = resolved;
}
