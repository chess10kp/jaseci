impl JacAccessValidation._resolve_anchor(
    archetype: Archetype
) -> tuple[Anchor, ExecutionContext] {
    anchor = archetype.__jac__;
    jctx = JacRuntimeInterface.get_context();
    if anchor.id is not None {
        mem_anchor = jctx.mem.get(anchor.id);
        if (mem_anchor and (mem_anchor is not anchor)) {
            anchor = mem_anchor;
        }
    }
    return (anchor, jctx);
}

impl JacAccessValidation._check_access(
    to: Anchor, min_level: AccessLevel, operation: str
) -> bool {
    actual = JacRuntimeInterface.check_access_level(to);
    granted = actual.value > min_level.value;
    if not granted {
        logger.info(
            "Current root doesn't have "
                + operation
                + " access to "
                + to.__class__.__name__
                + " "
                + to.archetype.__class__.__name__
                + "["
                + str(to.id)
                + "]"
        );
        if operation != "read" {
            required = AccessLevel(min_level.value + 1);
            diag = PermissionDenied(
                operation=operation,
                target_id=str(to.id),
                target_type=to.archetype.__class__.__name__,
                target_owner=str(to.root) if to.root else None,
                required=required,
                actual=actual
            );
            try {
                ctx = JacRuntimeInterface.get_context();
                ctx.diagnostics.append(diag);
            } except Exception {}
            if JacRuntime.strict_permissions {
                raise PermissionError(diag.message());
            }
            logger.warning(diag.message());
        }
    }
    return granted;
}

impl JacAccessValidation._is_shared_root(to: Anchor) -> bool {
    shared_id = _shared_root_resolver[1];
    return isinstance(shared_id, UUID) and to.id == shared_id;
}

impl JacAccessValidation.allow_root(
    archetype: Archetype, root_id: UUID, level: (AccessLevel | int | str | None) = None
) -> None {
    if (level is None) {
        level = AccessLevel.READ;
    }
    level = access_level_cast(level);
    (anchor, jctx) = JacAccessValidation._resolve_anchor(archetype);
    if not JacAccessValidation.check_write_access(anchor, op_hint="acl_write") {
        return;
    }
    access = anchor.own_access().roots;
    _root_id = str(root_id);
    if (level != access.anchors.get(_root_id, AccessLevel.NO_ACCESS)) {
        access.anchors[_root_id] = level;
        jctx.mem.put(anchor);
    }
}

impl JacAccessValidation.allow_group(
    archetype: Archetype, group_id: UUID, level: (AccessLevel | int | str | None) = None
) -> None {
    if (level is None) {
        level = AccessLevel.READ;
    }
    level = access_level_cast(level);
    (anchor, jctx) = JacAccessValidation._resolve_anchor(archetype);
    if not JacAccessValidation.check_write_access(anchor, op_hint="acl_write") {
        return;
    }
    access = anchor.own_access().groups;
    _group_id = str(group_id);
    if (level != access.anchors.get(_group_id, AccessLevel.NO_ACCESS)) {
        access.anchors[_group_id] = level;
        jctx.mem.put(anchor);
    }
}

impl JacAccessValidation.disallow_group(archetype: Archetype, group_id: UUID) -> None {
    (anchor, jctx) = JacAccessValidation._resolve_anchor(archetype);
    if not JacAccessValidation.check_write_access(anchor, op_hint="acl_write") {
        return;
    }
    anchor.own_access().groups.anchors.pop(str(group_id), None);
    jctx.mem.put(anchor);
}

impl JacAccessValidation.disallow_root(
    archetype: Archetype, root_id: UUID, level: (AccessLevel | int | str | None) = None
) -> None {
    if (level is None) {
        level = AccessLevel.READ;
    }
    level = access_level_cast(level);
    (anchor, jctx) = JacAccessValidation._resolve_anchor(archetype);
    if not JacAccessValidation.check_write_access(anchor, op_hint="acl_write") {
        return;
    }
    access = anchor.own_access().roots;
    access.anchors.pop(str(root_id), None);
    jctx.mem.put(anchor);
}

impl JacAccessValidation.perm_grant(
    archetype: Archetype, level: (AccessLevel | int | str | None) = None
) -> None {
    if (level is None) {
        level = AccessLevel.READ;
    }
    level = access_level_cast(level);
    (anchor, jctx) = JacAccessValidation._resolve_anchor(archetype);
    if not JacAccessValidation.check_write_access(anchor, op_hint="acl_write") {
        return;
    }
    if (level != _all_grant(anchor)) {
        anchor.own_access().all = level;
        jctx.mem.put(anchor);
    }
}

impl JacAccessValidation.perm_revoke(archetype: Archetype) -> None {
    (anchor, jctx) = JacAccessValidation._resolve_anchor(archetype);
    if not JacAccessValidation.check_write_access(anchor, op_hint="acl_write") {
        return;
    }
    if (_all_grant(anchor).value > AccessLevel.NO_ACCESS.value) {
        anchor.own_access().all = AccessLevel.NO_ACCESS;
        jctx.mem.put(anchor);
    }
}

impl JacAccessValidation.check_read_access(to: Anchor) -> bool {
    return JacAccessValidation._check_access(to, AccessLevel.NO_ACCESS, "read");
}

impl JacAccessValidation.check_connect_access(
    to: Anchor, op_hint: str = "connect"
) -> bool {
    return JacAccessValidation._check_access(to, AccessLevel.READ, op_hint);
}

impl JacAccessValidation.check_write_access(
    to: Anchor, op_hint: str = "write"
) -> bool {
    return JacAccessValidation._check_access(to, AccessLevel.CONNECT, op_hint);
}

impl JacAccessValidation.check_access_level(
    to: Anchor, no_custom: bool = False
) -> AccessLevel {
    if (not to.persistent or (to.hash == 0)) {
        return AccessLevel.WRITE;
    }
    jctx = JacRuntimeInterface.get_context();
    _jroot = jctx.user_root;
    if (_jroot is None) {
        return AccessLevel.NO_ACCESS;
    }
    jroot: NodeAnchor = _jroot;
    if ((jroot == jctx.system_root) or (jroot.id == to.root) or (jroot == to)) {
        return AccessLevel.WRITE;
    }
    if (
        not no_custom and ((custom_level := to.archetype.__jac_access__()) is not None)
    ) {
        return access_level_cast(custom_level);
    }
    access_level: AccessLevel = AccessLevel.NO_ACCESS;

    to_access = to.access;
    if to_access is not None and to_access.all.value > AccessLevel.NO_ACCESS.value {
        access_level = to_access.all;
    } elif JacAccessValidation._is_shared_root(to) {
        access_level = AccessLevel.CONNECT;
    }
    if (to.root and isinstance((to_root := jctx.mem.get(to.root)), Anchor)) {
        root_access = to_root.access;
        if root_access is not None {
            if (root_access.all.value > access_level.value) {
                access_level = root_access.all;
            }
            if ((level := root_access.roots.check(str(jroot.id))) is not None) {
                access_level = level;
            }
        }
    }
    if to_access is None {
        return access_level;
    }
    if ((level := to_access.roots.check(str(jroot.id))) is not None) {
        access_level = level;
    }
    if to_access.groups.anchors {
        for gid in JacAccessValidation._groups_of(jroot) {
            if ((glevel := to_access.groups.check(gid)) is not None)
                and glevel.value > access_level.value {
                access_level = glevel;
            }
        }
    }
    return access_level;
}

impl JacAccessValidation._groups_of(jroot: NodeAnchor) -> list[str] {
    import from jaclang.runtime.osp_graph_sv { sv_live_edges, sv_register_hydrated }
    sv_register_hydrated(jroot, fetch_stubs=True);
    out: list[str] = [];
    for grp in sv_live_edges(jroot, EdgeDir.OUT.value, None, False) {
        gid = grp.id;
        if gid is not None {
            out.append(str(gid));
        }
    }
    return out;
}
