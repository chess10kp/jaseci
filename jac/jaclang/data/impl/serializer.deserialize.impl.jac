impl Serializer._deserialize_jac_ref(data: dict[str, object]) -> (object | None) {
    id_str = data.get('$ref');
    if not isinstance(id_str, str) {
        return None;
    }
    try {
        ref_uuid = UUID(id_str);
    } except (ValueError, AttributeError) {
        logger.error(f"Invalid UUID in $ref: {id_str}");
        return None;
    }
    try {
        import from jaclang { JacRuntimeInterface as Jac }
        anchor = Jac.get_context().mem.get(ref_uuid);
        if anchor {
            if not anchor.is_populated() {
                anchor.populate();
            }
            if anchor.is_populated() {
                return anchor.archetype;
            }
        }
    } except Exception as e {
        logger.warning(f"Failed to resolve $ref {id_str} from context: {e}");
    }
    ref_type = data.get('$type');
    stub_cls = cast(
        type[Anchor],
        (
            NodeAnchor
                if ref_type == 'node'
                else EdgeAnchor
                    if ref_type == 'edge'
                    else WalkerAnchor if ref_type == 'walker' else ObjectAnchor
        )
    );
    return Serializer._id_to_stub(stub_cls, id_str);
}

impl Serializer.deserialize(data: dict[str, object]) -> (object | None) {
    if not isinstance(data, dict) {
        return data;
    }
    raw_type_name = data.get('__type__');
    if not isinstance(raw_type_name, str) or not raw_type_name {
        return {k: Serializer._deserialize_value(v) for (k, v) in data.items()};
    }
    type_name = raw_type_name;
    dispatch = {
        'Anchor': Serializer._deserialize_anchor,
        'NodeAnchor': Serializer._deserialize_anchor,
        'EdgeAnchor': Serializer._deserialize_anchor,
        'Permission': Serializer._deserialize_permission,
        'Access': Serializer._deserialize_access
    };
    if (handler := dispatch.get(type_name)) {
        return handler(data);
    }

    raw_module_name = data.get('__module__');
    module_name = raw_module_name if isinstance(raw_module_name, str) else '';
    if (resolved := Serializer._get_class(module_name, type_name)) {
        cls = cast(type[object], resolved);
        try {
            instance = cls.__new__(cls);
            field_types = get_field_types(cls);
            for (k, v) in data.items() {
                if not k.startswith('__') {
                    deser_v = Serializer._deserialize_value(v);
                    if (target := field_types.get(k)) is not None {
                        (coerced, ok) = Serializer.coerce(deser_v, target);
                        if ok {
                            deser_v = coerced;
                        }
                    }
                    setattr(instance, k, deser_v);
                }
            }
            return instance;
        } except Exception as e {
            if (
                n
                := Serializer._warn_occurrence(
                    "deserialize-failed",
                    f"{cls.__module__}.{type_name}:{type(e).__name__}"
                )
            ) {
                logger.error(
                    f"Failed to deserialize {type_name}: {e}"
                        + Serializer._occurrence_note(n)
                );
            }
        }
    }
    return None;
}

impl Serializer.deserialize_api(
    value: object, boundary_types: dict[str, type], target: (type | None) = None
) -> object {
    if isinstance(value, list) {
        return [Serializer.deserialize_api(v, boundary_types, target) for v in value];
    }
    if not isinstance(value, dict) {
        return value;
    }
    tag = value.get('_jac_type_id', value.get('_jac_type'));
    cls = boundary_types.get(tag, target) if isinstance(tag, str) else target;
    decoded: dict[str, object] = {
        k: Serializer.deserialize_api(v, boundary_types) for (k, v) in value.items()
    };
    if cls is None {
        return decoded;
    }
    instance = object.__new__(cls);
    for (k, v) in decoded.items() {
        if not k.startswith('__') {
            setattr(instance, k, v);
        }
    }
    return instance;
}

impl Serializer._deserialize_value(val: object) -> object {
    if val is None or isinstance(val, (str, int, float, bool)) {
        return val;
    }
    if isinstance(val, list) {
        return [Serializer._deserialize_value(v) for v in val];
    }
    if isinstance(val, dict) {
        if '$ref' in val and val.keys() <= {'$ref', '$type'} {
            return Serializer._deserialize_jac_ref(val);
        }
        return Serializer.deserialize(val)
            if '__type__' in val
            else {k: Serializer._deserialize_value(v) for (k, v) in val.items()};
    }
    return val;
}

impl Serializer._id_to_stub(anchor_cls: type[Anchor], id_str: str) -> (Anchor | None) {
    try {
        stub = anchor_cls.__new__(anchor_cls);
        stub.id = UUID(id_str);
        return stub;
    } except Exception as e {
        logger.error(
            f"Failed to create stub for {anchor_cls.__name__} with id {id_str}: {e}"
        );
        return None;
    }
}

def _new_anchor(type_name: object) -> Anchor {
    if type_name == 'NodeAnchor' {
        return NodeAnchor.__new__(NodeAnchor);
    }
    if type_name == 'EdgeAnchor' {
        return EdgeAnchor.__new__(EdgeAnchor);
    }
    return Anchor.__new__(Anchor);
}

def _node_stub(raw_id: object, role: str) -> NodeAnchor {
    if not isinstance(raw_id, str) or not raw_id {
        raise TypeError(f"anchor payload '{role}' is not a string id");
    }
    stub = Serializer._id_to_stub(NodeAnchor, raw_id);
    if not isinstance(stub, NodeAnchor) {
        raise ValueError(f"anchor payload '{role}' is not a usable id: {raw_id}");
    }
    return stub;
}

impl Serializer._deserialize_anchor(data: dict[str, object]) -> (Anchor | None) {
    try {
        anchor: Anchor = _new_anchor(data.get('__type__', ''));
        raw_id = data.get('id');
        if not isinstance(raw_id, str) or not raw_id {
            raise ValueError("anchor payload carries no usable 'id'");
        }
        anchor.id = UUID(raw_id);
        raw_root = data.get('root');
        anchor.`root = UUID(raw_root)
            if isinstance(raw_root, str) and raw_root
            else None;
        anchor.access = Serializer._deserialize_permission(data.get('access'));

        if (arch_data := data.get('archetype')) {
            if not isinstance(arch_data, dict) {
                if (
                    n
                    := Serializer._warn_occurrence(
                        "archetype-not-dict",
                        f"{data.get('__type__', 'anchor')}.{type(arch_data).__name__}"
                    )
                ) {
                    logger.warning(
                        "Serializer: archetype field is not a dict "
                        f"({type(arch_data).__name__}); dropping anchor."
                            + Serializer._occurrence_note(n)
                    );
                }
                return None;
            }
            archetype = Serializer._deserialize_archetype(arch_data, anchor);
            if archetype is None {
                arch_key = f"{arch_data.get('__module__')}.{arch_data.get('__type__')}";
                if (n := Serializer._warn_occurrence("archetype-failed", arch_key)) {
                    logger.warning(
                        "Serializer: archetype reconstruction failed for "
                        f"{arch_key}; dropping anchor (caller should quarantine)."
                            + Serializer._occurrence_note(n)
                    );
                }
                return None;
            }
            if not isinstance(archetype, Archetype) {
                raise TypeError(
                    "anchor payload 'archetype' did not reconstruct an Archetype"
                );
            }
            anchor.archetype = archetype;
        }

        anchor.persistent = bool(data.get('persistent', False));
        if isinstance(anchor, NodeAnchor) {
            raw_edges = data.get('edges');
            edge_ids: list[str] = [];
            if raw_edges {
                if not isinstance(raw_edges, list) {
                    raise TypeError("anchor payload 'edges' is not a list");
                }
                for raw_eid in raw_edges {
                    if not isinstance(raw_eid, str) {
                        raise TypeError(
                            "anchor payload 'edges' holds a non-string edge id"
                        );
                    }
                    edge_ids.append(raw_eid);
                }
            }
            if not edge_ids {
                anchor.edges = [];
            } else {
                edges: list[EdgeAnchor] = [];
                for eid in edge_ids {
                    stub = Serializer._id_to_stub(EdgeAnchor, eid);
                    if isinstance(stub, EdgeAnchor) {
                        edges.append(stub);
                    }
                }
                anchor.edges = edges;
            }

            setattr(
                anchor,
                '_initial_edge_ids',
                frozenset(UUID(eid) for eid in (edge_ids or []))
            );

            raw_version = data.get('version', 0);
            anchor.version = raw_version if isinstance(raw_version, int) else 0;
        }
        if isinstance(anchor, EdgeAnchor) {
            anchor.is_undirected = bool(data.get('is_undirected', False));

            if (source_id := data.get('source')) {
                anchor.source = _node_stub(source_id, 'source');
            }
            if (target_id := data.get('target')) {
                anchor.target = _node_stub(target_id, 'target');
            }
        }

        anchor.hash = Serializer._compute_hash(anchor);
        return anchor;
    } except Exception as e {
        failed_arch = data.get('archetype');
        arch_id = (
            f"{failed_arch.get('__module__')}.{failed_arch.get('__type__')}"
                if isinstance(failed_arch, dict)
                else data.get('__type__', 'anchor')
        );
        if (
            n
            := Serializer._warn_occurrence(
                "anchor-failed", f"{arch_id}:{type(e).__name__}"
            )
        ) {
            logger.error(
                f"Failed to deserialize anchor: {e}" + Serializer._occurrence_note(n)
            );
        }
        return None;
    }
}

impl Serializer._deserialize_permission(data: object) -> (Permission | None) {
    if not isinstance(data, dict) or not data {
        return None;
    }
    perm = Permission();
    perm.all = access_level_cast(data.get('all', -1));
    if (roots := data.get('roots')) {
        perm.roots = Serializer._deserialize_access(roots);
    }
    if (groups := data.get('groups')) {
        perm.groups = Serializer._deserialize_access(groups);
    }
    return perm;
}

impl Serializer._deserialize_access(data: object) -> Access {
    if not isinstance(data, dict) {
        return Access();
    }
    access = Access();
    anchors = data.get('anchors');
    if isinstance(anchors, dict) and anchors {
        for (k, v) in anchors.items() {
            if isinstance(v, (int, str, AccessLevel)) {
                access.anchors[str(k)] = access_level_cast(v);
            }
        }
    }
    return access;
}

impl Serializer._deserialize_archetype(
    data: dict[str, object], anchor: Anchor
) -> (object | None) {
    import from jaclang.data.schema_rules { ATTIC_KEY, REPAIRS_ATTR, repair_mode }
    raw_type_name = data.get('__type__');
    raw_module_name = data.get('__module__');
    if not isinstance(raw_type_name, str) or not isinstance(raw_module_name, str) {
        return None;
    }
    type_name = raw_type_name;
    module_name = raw_module_name;
    resolved = Serializer._get_class(module_name, type_name);
    if not resolved {
        return None;
    }
    cls = cast(type[object], resolved);
    mode = repair_mode();
    (data, repair_steps) = Serializer.repair(data, cls);
    try {
        arch: object = cls.__new__(cls);
        field_types = get_field_types(cls);
        known = set(field_types.keys());
        attic: dict[str, any] = {};

        stored_attic = data.get(ATTIC_KEY);
        if isinstance(stored_attic, dict) {
            attic.update(stored_attic);
        }
        dropped: list[str] = [];
        assigned: set[str] = set();
        for (k, v) in data.items() {
            if k.startswith('__') {
                continue;
            }
            deser_v = Serializer._deserialize_value(v);
            if k not in known {
                dropped.append(k);
                if mode == 'repair' {
                    attic[k] = {'value': deser_v, 'reason': 'unknown'};
                }
                continue;
            }
            target = field_types[k];
            (coerced, ok) = Serializer.coerce(deser_v, target);
            if not ok {
                field_key = f"{module_name}.{type_name}.{k}";
                origin = get_origin(target);
                args = get_args(target);
                is_optional = (
                    (origin is Union or origin is UnionType) and NoneType in args
                );
                if deser_v is None and not is_optional {
                    recovered: object = None;
                    has_default = False;
                    for fd in fields(cls) {
                        if fd.name == k {
                            if fd.default_factory is not None {
                                recovered = fd.default_factory();
                                has_default = True;
                            } elif fd.`default is not MISSING {
                                recovered = fd.`default;
                                has_default = True;
                            }
                            break;
                        }
                    }
                    if not has_default {
                        if (
                            n
                            := Serializer._warn_occurrence(
                                "stored-none-no-default", field_key
                            )
                        ) {
                            logger.warning(
                                f"Serializer: {module_name}.{type_name}.{k}: stored None "
                                f"on non-Optional field {target} and no class default "
                                "available; cannot recover."
                                    + Serializer._occurrence_note(n)
                            );
                        }
                        return None;
                    }
                    if (
                        n
                        := Serializer._warn_occurrence(
                            "stored-none-defaulted", field_key
                        )
                    ) {
                        logger.warning(
                            f"Serializer: {module_name}.{type_name}.{k}: stored None "
                            f"on non-Optional field {target}; restored class default."
                                + Serializer._occurrence_note(n)
                        );
                    }
                    setattr(arch, k, recovered);
                    assigned.add(k);
                    continue;
                }
                if (n := Serializer._warn_occurrence("coercion-fallback", field_key)) {
                    logger.warning(
                        f"Serializer: coercion fallback on {module_name}."
                        f"{type_name}.{k}: stored={type(deser_v).__name__}, "
                        f"target={target}; stored value kept as-is."
                            + Serializer._occurrence_note(n)
                    );
                }
            }
            setattr(arch, k, coerced);
            assigned.add(k);
        }
        if dropped {
            if mode == 'repair' {
                if (
                    n
                    := Serializer._warn_occurrence(
                        "attic-preserved", f"{module_name}.{type_name}"
                    )
                ) {
                    logger.info(
                        f"Serializer: preserved unknown fields in attic on "
                        f"{module_name}.{type_name}: {sorted(dropped)}"
                            + Serializer._occurrence_note(n)
                    );
                }
            } else {
                logger.debug(
                    f"Serializer: dropped removed fields on {module_name}."
                    f"{type_name}: {sorted(dropped)}"
                );
            }
        }

        for fd in fields(cls) {
            if fd.name in assigned {
                continue;
            }
            if fd.default_factory is not None {
                setattr(arch, fd.name, fd.default_factory());
            } elif fd.`default is MISSING {
                if (
                    n
                    := Serializer._warn_occurrence(
                        "required-missing", f"{module_name}.{type_name}.{fd.name}"
                    )
                ) {
                    logger.warning(
                        f"Serializer: {module_name}.{type_name}.{fd.name}: "
                        "required field missing from stored data and no default "
                        "available; attribute left unset."
                            + Serializer._occurrence_note(n)
                    );
                }
            }
        }
        if attic {
            setattr(arch, ATTIC_KEY, attic);
        }
        if repair_steps {
            setattr(arch, REPAIRS_ATTR, repair_steps);
        }
        setattr(arch, '__jac__', anchor);
        return arch;
    } except Exception as e {
        if (
            n
            := Serializer._warn_occurrence(
                "archetype-error", f"{module_name}.{type_name}:{type(e).__name__}"
            )
        ) {
            logger.error(
                f"Failed to deserialize archetype {type_name}: {e}"
                    + Serializer._occurrence_note(n)
            );
        }
        return None;
    }
}
