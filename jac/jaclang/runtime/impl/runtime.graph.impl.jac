impl JacWalker.`visit(
    `walker: WalkerArchetype,
    expr:
        (
            list[(NodeArchetype | EdgeArchetype)]
            | list[NodeArchetype]
            | list[EdgeArchetype]
            | NodeArchetype
            | EdgeArchetype
            | GraphQuery
        ),
    insert_loc: int = -1
) -> bool {
    import from jaclang.runtime.osp_kernel { osp_visit, scope_of }
    if isinstance(expr, GraphQuery) {
        expr.from_visit = True;
        expr = JacRuntimeInterface.refs(expr);
    }
    if not isinstance(`walker, WalkerArchetype) {
        raise TypeError('Invalid walker object');
    }
    items: list[any] = `list(expr)
        if isinstance(expr, `list)
        else ([expr] if isinstance(expr, (NodeArchetype, EdgeArchetype)) else []);
    targets: list[any] = [];
    for arch in items {
        anchor = arch.__jac__;
        if not isinstance(anchor, (NodeAnchor, EdgeAnchor)) {
            raise ValueError('Anchor should be NodeAnchor or EdgeAnchor.');
        }
        if anchor.destroyed is True {
            continue;
        }
        targets.append(arch);
    }
    if not targets {
        return False;
    }
    scope = scope_of(`walker);
    if scope is not None and not scope.ignores {
        if insert_loc == 0 {
            scope.front.extend(reversed(targets));
            scope.fenced = True;
            scope.pending_fence += len(targets);
            return True;
        }
        if insert_loc == -1 {
            scope.next.extend(targets);
            return True;
        }
    }
    return osp_visit(targets, insert_loc);
}

impl JacWalker.spawn_call(
    `walker: WalkerAnchor, nd: (NodeAnchor | EdgeAnchor)
) -> WalkerArchetype {
    import from jaclang.runtime.osp_kernel { osp_spawn }
    import from jaclang.runtime.osp_kernel_sv { desc_for, make_sv_runtime }
    warch = `walker.archetype;
    starts: list[any] = [a.archetype for a in `walker.next];
    osp_spawn(make_sv_runtime(), warch, desc_for(`type(warch)), starts);
    return warch;
}

impl JacWalker.async_spawn_call(
    `walker: WalkerAnchor, nd: (NodeAnchor | EdgeAnchor)
) -> WalkerArchetype {
    import from jaclang.runtime.osp_kernel_sv {
        osp_spawn_async,
        desc_for,
        make_sv_runtime
    }
    warch = `walker.archetype;
    await osp_spawn_async(
        make_sv_runtime(),
        warch,
        desc_for(`type(warch)),
        [a.archetype for a in `walker.next]
    );
    return warch;
}

impl JacWalker.`spawn(
    op1: (Archetype | list[Archetype]), op2: (Archetype | list[Archetype])
) -> (WalkerArchetype | Coroutine) {
    def collect_targets(
        `walker: WalkerAnchor, items: list[Archetype]
    ) -> (NodeAnchor | EdgeAnchor) {
        for i in items {
            a = i.__jac__;
            `walker.next.append(a) if isinstance(a, (NodeAnchor, EdgeAnchor)) else None;
            if (isinstance(a, EdgeAnchor) and a.target) {
                `walker.next.append(a.target);
            }
        }
        return `walker.next[0];
    }
    def assign(
        `walker: WalkerAnchor, t: (Archetype | list[Archetype])
    ) -> (NodeAnchor | EdgeAnchor) {
        if isinstance(t, NodeArchetype) {
            nd = t.__jac__;
            `walker.next = [nd];
            return nd;
        } elif isinstance(t, EdgeArchetype) {
            `edge = t.__jac__;
            `walker.next = [`edge, `edge.target];
            return `edge;
        } elif (
            isinstance(t, `list)
            and all(isinstance(i, (NodeArchetype, EdgeArchetype)) for i in t)
        ) {
            return collect_targets(`walker, t);
        } else {
            raise TypeError('Invalid target object');
        }
    }
    if isinstance(op1, WalkerArchetype) {
        (warch, targ) = (op1, op2);
    } elif isinstance(op2, WalkerArchetype) {
        (warch, targ) = (op2, op1);
    } else {
        raise TypeError('Invalid walker object');
    }
    `walker: WalkerAnchor = warch.__jac__;
    loc: (NodeAnchor | EdgeAnchor) = assign(`walker, targ);
    for start in `walker.next {
        if start.destroyed is True {
            raise RuntimeError(
                f"cannot spawn on a destroyed graph object: {start.archetype!r}"
            );
        }
    }
    if warch.__jac_async__ {
        import asyncio;
        import from typing { cast }
        task = cast(
            Coroutine[any, any, WalkerArchetype],
            JacRuntimeInterface.async_spawn_call(`walker=`walker, nd=loc)
        );
        try {
            asyncio.get_running_loop();
        } except RuntimeError {
            return asyncio.run(task);
        }
        return task;
    }
    return JacRuntimeInterface.spawn_call(`walker=`walker, nd=loc);
}

impl JacWalker.`disengage(`walker: WalkerArchetype) -> bool {
    import from jaclang.runtime.osp_kernel { osp_disengage }

    `walker.__jac__.disengaged = True;
    osp_disengage();
    return True;
}

impl JacArchetype.make_archetype(cls: type[Archetype]) -> type[Archetype] {
    entries: OrderedDict[(str, ObjectSpatialFunction)] = OrderedDict(
        (fn.name, fn) for fn in cls._jac_entry_funcs_
    );
    exits: OrderedDict[(str, ObjectSpatialFunction)] = OrderedDict(
        (fn.name, fn) for fn in cls._jac_exit_funcs_
    );
    for func in cls.__dict__.values() {
        if callable(func) and (func?.__jac_entry or func?.__jac_exit) {
            dsfunc = JacRuntimeInterface.DSFunc(
                func.__name__, func, func.__jac_trigger__
            )
                if func?.__jac_trigger__
                else JacRuntimeInterface.DSFunc(func.__name__, func);
            if func?.__jac_entry {
                entries[func.__name__] = dsfunc;
            }
            if func?.__jac_exit {
                exits[func.__name__] = dsfunc;
            }
        }
    }
    cls._jac_entry_funcs_ = [*entries.values()];
    cls._jac_exit_funcs_ = [*exits.values()];
    if cls.__dict__.get('__annotations__') and not cls.__doc__ {
        cls.__doc__ = cls.__name__;
    }
    return make_object(cls);
}

impl JacGraph.refs(
    path: GraphQuery | NodeArchetype | list[NodeArchetype],
    slc: (slice | None) = None,
    lazy: bool = False
) -> list[NodeArchetype] | list[EdgeArchetype] | list[(NodeArchetype | EdgeArchetype)] {
    import from jaclang.runtime.graph_walk {
        access_gated,
        has_persistent_origin,
        needs_store,
        origin_anchors,
        walk_edges,
        walk_nodes
    }
    if not isinstance(path, GraphQuery) {
        path = GraphQuery(path, hops=[QHop(dir=EdgeDir.OUT.value)]);
    }
    if slc is not None and path.slc is None {
        path.slc = slc;
    }
    origins = origin_anchors(path);
    ctx = JacRuntimeInterface.peek_context();
    if ctx is None and has_persistent_origin(origins) {
        ctx = JacRuntimeInterface.get_context();
    }

    def _archetypes(planned: list[any]) -> list[(NodeArchetype | EdgeArchetype)] {
        out: list[(NodeArchetype | EdgeArchetype)] = [];
        for a in planned {
            arch = a.archetype;
            if isinstance(arch, (NodeArchetype, EdgeArchetype)) {
                out.append(arch);
            }
        }
        return out;
    }

    if ctx is None or not needs_store(ctx.mem, origins) {
        gated = access_gated();
        return _archetypes(
            walk_edges(origins, path, gated)
                if path.edges_only
                else walk_nodes(origins, path, gated)
        );
    }
    import from typing { cast }
    import from jaclang.data.query_planner {
        LazyRefs,
        resolve_query,
        resolve_query_edges
    }
    import from jaclang.server.session { Session }
    ctx.note_traversal_reads([nd.__jac__ for nd in path.origin]);
    store_mem = cast(Session, ctx.mem);

    def _run(q: GraphQuery) -> list[(NodeArchetype | EdgeArchetype)] {
        return _archetypes(
            resolve_query_edges(store_mem, q)
                if q.edges_only
                else resolve_query(store_mem, q)
        );
    }
    if lazy and path.slc is None {
        return LazyRefs(_run, path);
    }
    return _run(path);
}

impl JacGraph.arefs(path: GraphQuery | NodeArchetype | list[NodeArchetype]) -> None {}

impl JacGraph.filter_on(
    items: list[Archetype], func: Callable[([Archetype], bool)]
) -> list[Archetype] {
    return [
        item
        for item in items
        if func(item)
    ];
}

impl JacGraph.connect(
    left: (NodeArchetype | list[NodeArchetype]),
    right: (NodeArchetype | list[NodeArchetype]),
    `edge: type[EdgeArchetype] | EdgeArchetype | None = None,
    undir: bool = False,
    conn_assign: (tuple[(tuple[any, ...], tuple[any, ...])] | None) = None,
    edges_only: bool = False
) -> (NodeArchetype | list[NodeArchetype] | list[EdgeArchetype]) {
    if (
        not undir
        and conn_assign is None
        and not edges_only
        and isinstance(`edge, `type)
        and isinstance(left, NodeArchetype)
        and isinstance(right, NodeArchetype)
    ) {
        light = _light_edge_types.get(`edge);
        if light is None {
            light = is_light_edge_type(`edge);
        }
        if light {
            src = left.__jac__;
            tgt = right.__jac__;
            if src.destroyed is True or tgt.destroyed is True {
                dead = left if src.destroyed is True else right;
                raise RuntimeError(f"cannot connect a destroyed node: {dead!r}");
            }
            if not (src.persistent or tgt.persistent) {
                light_connect(src, `edge, tgt);
                return right;
            }
        }
    }
    left = [left] if isinstance(left, NodeArchetype) else left;
    right_is_node = isinstance(right, NodeArchetype);
    right = [right] if isinstance(right, NodeArchetype) else right;
    for operands in (left, right) {
        for operand in operands {
            if not isinstance(operand, NodeArchetype) {
                raise TypeError(
                    "connect operands must be nodes or flat collections of nodes"
                );
            }
        }
    }
    edges = [];
    for i in left {
        _left = i.__jac__;
        if _left.destroyed is True {
            raise RuntimeError(f"cannot connect a destroyed node: {i!r}");
        }
        if JacRuntimeInterface.check_connect_access(_left, op_hint="edge_write") {
            for j in right {
                _right = j.__jac__;
                if _right.destroyed is True {
                    raise RuntimeError(f"cannot connect a destroyed node: {j!r}");
                }
                if JacRuntimeInterface.check_connect_access(
                    _right, op_hint="edge_write"
                ) {
                    edges.append(
                        JacRuntimeInterface.build_edge(
                            is_undirected=undir,
                            conn_type=`edge,
                            conn_assign=conn_assign
                        )(
                            _left, _right
                        )
                    );
                }
            }
        }
    }
    if edges_only {
        return edges;
    }

    return right[0] if right_is_node else right;
}

impl JacGraph.hop(
    origin: any, dir: int, edge_type: (type | None) = None, edges_only: bool = False
) -> list[any] {
    if not isinstance(origin, `list) {
        anchor = origin.__jac__;
        if (
            edge_type is not None
            and dir != 3
            and not edges_only
            and not anchor.persistent
            and (
                not anchor.has_heavy_edges()
                or (not anchor.mixed and _light_edge_types.get(edge_type))
            )
            and len(_edge_subtypes.get(edge_type) or edge_subtypes(edge_type)) == 1
        ) {
            if dir == 2 {
                d = anchor.out_light;
                lst = d.get(edge_type) if d else None;
                return `list(lst) if lst else [];
            }
            d = anchor.in_light;
            lst = d.get(edge_type) if d else None;
            return _deref(lst) if lst else [];
        }
        if light_hop_answers(anchor, edge_type) {
            return light_hop(anchor, dir, edge_type, edges_only);
        }
    }
    return JacRuntimeInterface.refs(
        GraphQuery(origin, hops=[QHop(dir=dir, `edge=edge_type)], edges_only=edges_only)
    );
}

impl JacGraph.clear_edges(
    origin: any, dir: int, edge_type: (type | None) = None
) -> bool {
    import from jaclang.runtime.osp_kernel { osp_forget }
    if edge_type is not None and not isinstance(origin, `list) {
        anchor = origin.__jac__;
        if (
            not anchor.has_heavy_edges()
            and len(_edge_subtypes.get(edge_type) or edge_subtypes(edge_type)) == 1
        ) {
            d_out = anchor.out_light;
            d_in = anchor.in_light;
            if (
                (dir == 1 or not d_out or edge_type not in d_out)
                and (dir == 2 or not d_in or edge_type not in d_in)
            ) {
                return False;
            }
        }
    }
    origins = origin if isinstance(origin, `list) else [origin];
    hit = False;
    for o in origins {
        anchor = o.__jac__;
        if light_clear_hop(anchor, dir, edge_type) {
            hit = True;
        }
        for ea in `list(anchor.edges) {
            if edge_type is not None and not isinstance(ea.archetype, edge_type) {
                continue;
            }
            if dir == 2 and not (ea.source is anchor or ea.is_undirected) {
                continue;
            }
            if dir == 1 and not (ea.target is anchor or ea.is_undirected) {
                continue;
            }
            if ea.persistent {
                JacRuntimeInterface.destroy([ea]);
            } else {
                ea.detach();
                ea.destroyed = True;
                _ea_handle: any = ea.archetype;
                osp_forget(_ea_handle);
            }
            hit = True;
        }
    }
    return hit;
}

impl JacGraph.disconnect(
    left: (NodeArchetype | list[NodeArchetype]),
    right: (NodeArchetype | list[NodeArchetype]),
    dir: EdgeDir = EdgeDir.OUT,
    filter: (Callable[([EdgeArchetype], bool)] | None) = None
) -> bool {
    import from jaclang.runtime.osp_graph_sv {
        sv_candidate_edges_between,
        sv_register_hydrated
    }
    disconnect_occurred = False;
    left = [left] if isinstance(left, NodeArchetype) else left;
    right = [right] if isinstance(right, NodeArchetype) else right;
    for i in left {
        nd = i.__jac__;
        for stub in `set(nd.edges) {
            if not stub.is_populated() {
                stub.populate();
            }
        }
        sv_register_hydrated(nd);
        handled: set = set();
        for j in right {
            if _light_disconnect_between(nd, j.__jac__, dir.value, filter) {
                disconnect_occurred = True;
            }
            for anchor in sv_candidate_edges_between(nd, j.__jac__, dir.value) {
                akey = anchor_key(anchor);
                if akey in handled {
                    continue;
                }
                handled.add(akey);
                if (
                    (source := anchor.source)
                    and (target := anchor.target)
                    and (not filter or filter(anchor.archetype))
                    and source.archetype
                    and target.archetype
                ) {
                    other = target if same_anchor(source, nd) else source;
                    if JacRuntimeInterface.check_connect_access(
                        other, op_hint="edge_delete"
                    ) {
                        JacRuntimeInterface.destroy([anchor])
                            if anchor.persistent
                            else anchor.detach();
                        disconnect_occurred = True;
                    }
                }
            }
        }
    }
    return disconnect_occurred;
}

impl JacGraph.assign_all(
    target: list[T], attr_val: tuple[(tuple[str, ...], tuple[any, ...])]
) -> list[T] {
    for `obj in target {
        (attrs, values) = attr_val;
        for (attr, value) in zip(attrs, values, strict=False) {
            setattr(`obj, attr, value);
        }
    }
    return target;
}

impl JacGraph.`root -> Root {
    return JacRuntime.get_context().get_root();
}

impl JacGraph.get_all_root -> list[Root] {
    jmem = JacRuntimeInterface.get_context().mem;
    return `list(jmem.get_roots());
}

impl JacGraph.build_edge(
    is_undirected: bool,
    conn_type: type[EdgeArchetype] | EdgeArchetype | None,
    conn_assign: (tuple[(tuple[any, ...], tuple[any, ...])] | None)
) -> Callable[([NodeAnchor, NodeAnchor], EdgeArchetype)] {
    ct = conn_type or GenericEdge;
    cls = ct if isinstance(ct, `type) else `type(ct);
    light = (not is_undirected) and (not conn_assign) and is_light_edge_type(cls);
    def builder(source: NodeAnchor, target: NodeAnchor) -> EdgeArchetype {
        if light and not (source.persistent or target.persistent) {
            light_connect(source, cls, target);
            return light_edge_view(cls, source, target);
        }
        return JacRuntimeInterface.heavy_edge(
            source, target, ct, is_undirected, conn_assign
        );
    }
    return builder;
}

impl JacGraph.heavy_edge(
    source: NodeAnchor,
    target: NodeAnchor,
    conn_type: type[EdgeArchetype] | EdgeArchetype | None,
    is_undirected: bool,
    conn_assign: (tuple[(tuple[any, ...], tuple[any, ...])] | None)
) -> EdgeArchetype {
    import from jaclang.runtime.osp_graph_sv { sv_conn }
    ct = conn_type or GenericEdge;
    `edge = ct() if isinstance(ct, `type) else ct;
    eanch = `edge.__jac__=EdgeAnchor(
        archetype=`edge, source=source, target=target, is_undirected=is_undirected
    );
    source.edges.append(eanch);
    target.edges.append(eanch);
    if is_light_edge_type(`type(`edge)) {
        source.mixed = True;
        target.mixed = True;
    }
    sv_conn(source, target, eanch, is_undirected);
    if conn_assign {
        for (fld, val) in zip(conn_assign[0], conn_assign[1], strict=False) {
            if hasattr(`edge, fld) {
                setattr(`edge, fld, val);
            } else {
                raise ValueError(f"Invalid attribute: {fld}");
            }
        }
    }
    if (source.persistent or target.persistent) {
        JacRuntimeInterface.save(eanch);
    }
    return `edge;
}

impl JacArchetype.on_entry(func: Callable) -> Callable {
    setattr(func, '__jac_entry', True);
    return func;
}

impl JacArchetype.on_exit(func: Callable) -> Callable {
    setattr(func, '__jac_exit', True);
    return func;
}

impl JacArchetype.set_trigger(
    trigger_thunk: Callable
) -> Callable[([Callable], Callable)] {
    def deco(func: Callable) -> Callable {
        setattr(func, '__jac_trigger__', trigger_thunk);
        return func;
    }
    return deco;
}
