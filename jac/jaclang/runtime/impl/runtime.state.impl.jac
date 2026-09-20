impl JacContext.get_context -> ExecutionContext {
    ctx = JacRuntimeInterface.peek_context();
    if ctx is None {
        ctx = JacRuntimeInterface.create_j_context(user_root=None);
        JacRuntime.exec_ctx = ctx;
    }
    return ctx;
}

impl JacContext.peek_context -> (ExecutionContext | None) {
    ctx = _request_context.get();
    if ctx is not None {
        return ctx;
    }
    return JacRuntime.exec_ctx;
}

impl JacPersistence.commit(anchor: Anchor | Archetype | None = None) -> None {
    if isinstance(anchor, Archetype) {
        anchor = anchor.__jac__;
    }
    ctx = JacRuntimeInterface.get_context();
    ctx.mem.commit(anchor);
    ctx.run_pending_effects();
}

impl JacPersistence.acommit(anchor: Anchor | Archetype | None = None) -> None {
    if isinstance(anchor, Archetype) {
        anchor = anchor.__jac__;
    }
    ctx = JacRuntimeInterface.get_context();
    await ctx.mem.acommit(anchor);
    ctx.run_pending_effects();
}

impl JacPersistence.on_commit(callback: Callable) -> None {
    JacRuntimeInterface.get_context().on_commit(callback);
}

impl JacContext.reset_graph(root_node: (Root | None) = None) -> int {
    ctx = JacRuntimeInterface.get_context();
    mem = ctx.mem;
    ranchor = root_node.__jac__ if root_node else ctx.user_root;
    deleted_count = 0;
    deleted_ids: set[UUID] = `set();
    cand_map: dict[UUID, str | None] = {};
    store = mem?.store;
    if store is not None {
        mem.read_barrier();
        for row in store.rows("SELECT id, root_id FROM anchors", {}) {
            cand_map[UUID(str(row[0]))] = str(row[1]) if row[1] else None;
        }
    }
    for anchor in mem.get_mem().values() {
        if anchor.id is not None {
            cand_map[anchor.id] = str(anchor.root) if anchor.root else None;
        }
    }
    candidates = list(cand_map.items());
    import from jaclang.runtime.osp_graph_sv { sv_forget_by_id }
    for (aid, aroot) in candidates {
        if ((aid == ranchor.id) or (aroot != str(ranchor.id))) {
            continue;
        }
        deleted_ids.add(aid);
        mem.delete(aid);
        sv_forget_by_id(aid, mem);
        deleted_count += 1;
    }
    ranchor.edges = [
        e
        for e in ranchor.edges
        if (e.id not in deleted_ids)
    ];
    mem.commit(ranchor);
    return deleted_count;
}

impl JacPersistence.get_object(id: str) -> (Archetype | None) {
    if (id == 'root') {
        return JacRuntimeInterface.get_context().user_root.archetype;
    } elif (`obj := JacRuntimeInterface.get_context().mem.get(UUID(id))) {
        if not JacRuntimeInterface.check_read_access(`obj) {
            return None;
        }
        return `obj.archetype;
    }
    return None;
}

impl JacPersistence.aget_object(id: str) -> (Archetype | None) {
    if (id == 'root') {
        return JacRuntimeInterface.get_context().user_root.archetype;
    }
    `obj = await JacRuntimeInterface.get_context().mem.aget(UUID(id));
    if `obj is not None {
        if not JacRuntimeInterface.check_read_access(`obj) {
            return None;
        }
        return `obj.archetype;
    }
    return None;
}

impl JacPersistence.object_ref(`obj: Archetype) -> str {
    anchor = `obj.__jac__;
    if isinstance(anchor, ObjectAnchor) {
        try {
            JacRuntimeInterface.get_context().mem.put(anchor);
        } except Exception as e {
            logger.warning(f"object_ref: failed to register anchor in memory: {e}");
        }
    }
    return anchor.ensure_id().hex;
}

impl JacPersistence.save(`obj: (Archetype | Anchor)) -> None {
    anchor = `obj.__jac__ if isinstance(`obj, Archetype) else `obj;
    jctx = JacRuntimeInterface.get_context();
    anchor.ensure_id();
    if (not anchor.persistent and not anchor.root) {
        anchor.persistent = True;
        anchor.`root = jctx.user_root.id;
    }
    jctx.mem.put(anchor);
    match anchor {
        case NodeAnchor():
            for ed in anchor.all_edges() {
                if (ed.is_populated() and not ed.persistent) {
                    JacRuntimeInterface.save(ed);
                }
            }

        case EdgeAnchor():
            if ((src := anchor.source) and src.is_populated() and not src.persistent) {
                JacRuntimeInterface.save(src);
            }
            if ((trg := anchor.target) and trg.is_populated() and not trg.persistent) {
                JacRuntimeInterface.save(trg);
            }

        case _:
            ;

    }
}

impl JacPersistence._destroy_anchors(objs: any, strict: bool) -> list[Anchor] {
    anchors: list[Anchor] = [];
    queue: list[any] = [objs];
    seen: set[int] = set();
    idx = 0;
    while idx < len(queue) {
        item = queue[idx];
        idx += 1;
        if isinstance(item, Archetype) {
            anchors.append(item.__jac__);
        } elif isinstance(item, Anchor) {
            anchors.append(item);
        } elif isinstance(item, (`list, `tuple, `set, frozenset, deque, `dict)) {
            if id(item) not in seen {
                seen.add(id(item));
                for sub in (item.values() if isinstance(item, `dict) else item) {
                    queue.append(sub);
                }
            }
        } elif strict {
            raise TypeError(
                f"cannot destroy {type(item).__name__!r}: a `del` value "
                "target must yield nodes, edges or archetypes"
            );
        }
    }
    return anchors;
}

impl JacPersistence.destroy(objs: any, strict: bool = False) -> None {
    anchors = JacPersistence._destroy_anchors(objs, strict);
    if not anchors {
        return;
    }
    import from jaclang.runtime.osp_kernel { osp_forget }
    import from jaclang.runtime.region { run_drop }
    for anchor in anchors {
        if isinstance(anchor.archetype, Root) {
            raise RuntimeError("cannot destroy root");
        }
        if anchor.destroyed {
            continue;
        }
        if JacRuntimeInterface.check_write_access(anchor, op_hint="delete") {
            match anchor {
                case NodeAnchor():
                    anchor.detach_light();
                    for `edge in anchor.edges[:] {
                        eid = `edge.id;
                        `edge.detach();
                        `edge.destroyed = True;
                        _edge_handle: any = `edge.archetype;
                        run_drop(_edge_handle);
                        osp_forget(_edge_handle);
                        if eid is not None {
                            JacRuntimeInterface.get_context().mem.delete(eid);
                        }
                    }

                case EdgeAnchor():
                    anchor.detach();

                case _:
                    ;

            }
            aid = anchor.id;
            if aid is not None {
                JacRuntimeInterface.get_context().mem.delete(aid);
            }
            anchor.destroyed = True;
            _handle: any = anchor.archetype;
            run_drop(_handle);
            osp_forget(_handle);
        }
    }
}

impl JacPersistence.peek_attr(`obj: any, name: str) -> any {
    try {
        return getattr(`obj, name);
    } except Exception {
        return None;
    }
}

impl JacPersistence.peek_item(container: any, key: any) -> any {
    try {
        if isinstance(container, `dict) {
            return `dict.get(container, key);
        }
        if isinstance(container, (`list, `tuple)) {
            builtin_getitem: any = `list.__getitem__
                if isinstance(container, `list)
                else `tuple.__getitem__;
            return builtin_getitem(container, key);
        }
        return container[key];
    } except Exception {
        return None;
    }
}

impl JacContext.create_j_context(
    user_root: (str | None),
    base_path_dir: (str | None) = None,
    full_target_path: (str | None) = None
) -> ExecutionContext {
    _sp = _scale_provider();
    if _sp is not None {
        _scaled = _sp.create_j_context(user_root, base_path_dir, full_target_path);
        if _scaled is not None {
            return _scaled;
        }
    }
    import from jaclang.runtime.context { ExecutionContext }
    ctx = ExecutionContext(
        base_path_dir=base_path_dir, full_target_path=full_target_path
    );
    if (user_root is not None) {
        ctx.set_user_root(user_root);
    }
    return ctx;
}

impl JacContext.attach_program(jac_program: JacProgram) -> None {
    JacRuntime.program = jac_program;
}

impl JacContext.thread_run(func: Callable, *args: object) -> Future {
    _executor = JacRuntime.pool;
    return _executor.submit(func, *args);
}

impl JacContext.thread_wait(future: any) -> None {
    return future.result();
}

impl JacConfig.on_config_loaded(config: dict[(str, any)]) -> None {}

impl JacConfig.validate_config(config: dict[(str, any)]) -> list[str] {
    return [];
}

impl JacPersistence.get_user_manager(base_path: str) -> UserManager {
    import from jaclang.server.identity.user_manager { UserManager }
    return UserManager(base_path=base_path);
}

impl JacPersistence.store(
    base_path: str = './storage', create_dirs: bool = True
) -> any {
    _sp = _scale_provider();
    if _sp is not None {
        return _sp.store(base_path, create_dirs);
    }
    import from jaclang.data.storage { LocalStorage }
    return LocalStorage(base_path=base_path, create_dirs=create_dirs);
}

impl JacPersistence.get_persistent_memory(config: dict[str, any]) -> any {
    provider = _persistent_memory_provider[0];
    if provider is not None {
        return provider(config);
    }
    return None;
}

impl JacPersistence.set_persistent_memory_provider(provider: Callable | None) -> None {
    _persistent_memory_provider[0] = provider;
}

impl JacRuntime.reset_process_state(cls: any, clear_modules: bool = True) -> None {
    import sys;
    prepared = sys.modules.get('jaclang.runtime.prepared');
    if prepared is not None {
        prepared.clear();
    }
    import from concurrent.futures { ThreadPoolExecutor }
    if cls.exec_ctx is not None {
        cls.exec_ctx.mem.close();
    }
    cls.exec_ctx = None;
    if clear_modules {
        for mod in list(cls.loaded_modules.values()) {
            if (
                not mod.__name__.startswith("jaclang.") and (mod.__name__ != "__main__")
            ) {
                sys.modules.pop(mod.__name__, None);
            }
        }
        cls.loaded_modules.clear();
    }
    stale = cls.pool;
    cls.pool = ThreadPoolExecutor();
    if stale is not None {
        stale.shutdown(`wait=False);
    }
    cls.program = None;
    cls.compiler = None;
    cls.selfhost = None;
    import from jaclang.project.config { set_config }
    set_config(None);
}

impl JacRuntime.get_compiler(cls: any) -> JacCompiler {
    if (cls.compiler is None) {
        import from jaclang.runtime.build_services { build_services }
        cls.compiler = build_services().compiler();
        if cls.program is not None and cls.program._compiler is None {
            cls.program._compiler = cls.compiler;
        }
    }
    return cls.compiler;
}

impl JacRuntime.get_program(cls: any) -> JacProgram {
    if (cls.program is None) {
        import from jaclang.runtime.build_services { build_services }
        prog = build_services().program();

        prog._compiler = cls.get_compiler();
        cls.program = prog;
    }
    return cls.program;
}

impl JacRuntime.get_selfhost(cls: any) -> SelfHostCache {
    if (cls.selfhost is None) {
        import from jaclang.runtime.build_services { build_services }
        cls.selfhost = build_services().selfhost();
    }
    return cls.selfhost;
}

impl JacRuntime.shared_root_id -> (UUID | None) {
    resolver = _shared_root_resolver[0];
    if resolver is None {
        return None;
    }
    cached = _shared_root_resolver[1];
    if isinstance(cached, UUID) {
        return cached;
    }
    resolved = resolver();
    if not isinstance(resolved, str) {
        return None;
    }
    root_id = UUID(resolved);
    _shared_root_resolver[1] = root_id;
    return root_id;
}

impl JacRuntime.get_shared_root -> Root {
    if _shared_root_resolver[0] is None {
        return JacRuntimeInterface.get_context().get_root();
    }
    root_id = JacRuntime.shared_root_id();
    if root_id is None {
        raise RuntimeError(
            "Shared root unavailable: the registered shared-root resolver "
            "returned no root id."
        );
    }
    shared_anchor = JacRuntimeInterface.get_context().mem.get(root_id);
    shared = shared_anchor.archetype if shared_anchor else None;
    if not isinstance(shared, Root) {
        raise RuntimeError(
            f"Shared root unavailable: id {root_id} did not resolve to a Root node."
        );
    }
    return shared;
}

impl JacRuntime.set_shared_root_resolver(
    resolver: (Callable[([], (str | None))] | None)
) -> None {
    _shared_root_resolver[0] = resolver;
    _shared_root_resolver[1] = None;
}

impl JacRuntime.get_base_path_dir -> (str | None) {
    return _default_base_path_dir[0];
}

impl JacRuntime.get_full_target_path -> (str | None) {
    return _default_full_target_path[0];
}

impl JacRuntime.set_base_path(base_path: (str | None)) -> None {
    if (base_path is None) {
        _default_base_path_dir[0] = None;
    } else {
        _default_base_path_dir[0] = base_path
            if os.path.isdir(base_path)
            else os.path.dirname(base_path);
    }
}

impl JacRuntime.set_full_target_path(target_path: (str | None)) -> None {
    _default_full_target_path[0] = target_path;
}

impl JacRuntime.set_context(context: ExecutionContext) -> None {
    JacRuntime.exec_ctx = context;
}

impl JacRuntime.push_request_context(context: ExecutionContext) -> any {
    return _request_context.set(context);
}

impl JacRuntime.reset_request_context(token: any) -> None {
    _request_context.reset(token);
}

impl JacRuntime.after_fork_in_child -> None {
    import from concurrent.futures { ThreadPoolExecutor }
    import from jaclang.data.pgpool { detach }
    ctx = JacRuntime.exec_ctx;
    JacRuntime.exec_ctx = None;
    if ctx is not None {
        store = ctx.mem?.store;
        if store is not None {
            for attr in ('_conn', '_side_conn') {
                detach(getattr(store, attr, None));
                try {
                    setattr(store, attr, None);
                } except Exception {}
            }
            try {
                store._listen_thread = None;
                store._listen_stop = None;
                store._side_listened = False;
            } except Exception {}
        }
    }
    _shared_root_resolver[1] = None;
    JacRuntime.pool = ThreadPoolExecutor();
}
