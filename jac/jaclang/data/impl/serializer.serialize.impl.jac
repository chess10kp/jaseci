impl Serializer._type_info(`obj: object, `include: bool) -> dict[str, object] {
    return {'__type__': type(`obj).__name__, '__module__': type(`obj).__module__}
        if `include
        else {};
}

impl Serializer._serialize_attrs(
    `obj: object,
    include_type: bool,
    api_mode: bool,
    ref_mode: bool = False,
    _seen: (tuple[set, set] | None) = None
) -> dict[str, object] {
    omitted: set[str] = (
        {'reports'} if api_mode and isinstance(`obj, WalkerArchetype) else set()
    );
    result = {
        a: Serializer._serialize_value(
            getattr(`obj, a),
            include_type,
            api_mode,
            ref_mode,
            _seen,
            Serializer._declared_of(`obj, a)
        )
        for a in dir(`obj)
        if not a.startswith('_')
            and a not in omitted
            and not callable(getattr(`obj, a, None))
    };

    if include_type and not api_mode {
        if hasattr(type(`obj), '__jac_schema__') {
            import from jaclang.data.schema_rules { merged_rules_for, repair_mode }
            if repair_mode() == 'repair' and (rules := merged_rules_for(type(`obj))) {
                for a in rules.aliases {
                    if a.new_name in result and a.stored_name not in result {
                        result[a.stored_name] = result[a.new_name];
                    }
                }
            }
        }

        attic = `obj?.__jac_attic__;
        if isinstance(attic, dict) and attic {
            result['__jac_attic__'] = Serializer._serialize_value(
                attic, include_type, api_mode, ref_mode, _seen
            );
        }
    }
    return result;
}

impl Serializer.serialize(
    `obj: object,
    include_type: bool = False,
    api_mode: bool = False,
    ref_mode: bool = False
) -> object {
    _seen = (set(), set()) if ref_mode else None;
    return Serializer._serialize_value(`obj, include_type, api_mode, ref_mode, _seen);
}

impl Serializer._declared_of(owner: object, attr: str) -> object {
    cls = type(owner);
    hit = _SIZED_FIELD_CACHE.get(cls);
    if hit is None {
        import from jaclang.runtime.sized { SIZED_TYPES }
        found: dict[str, object] = {};
        for klass in reversed(cls.__mro__) {
            ann = klass.__dict__.get('__annotations__');
            if not isinstance(ann, dict) {
                continue;
            }
            for (name, tag) in ann.items() {
                sized = SIZED_TYPES.get(tag)
                    if isinstance(tag, str)
                    else (tag if tag?.__jac_sized__ is not None else None);
                if sized is not None {
                    found[name] = sized;
                }
            }
        }
        _SIZED_FIELD_CACHE[cls] = found;
        hit = found;
    }
    return hit.get(attr);
}

impl Serializer._serialize_value(
    val: object,
    include_type: bool,
    api_mode: bool = False,
    ref_mode: bool = False,
    _seen: (tuple[set, set] | None) = None,
    declared: object = None
) -> object {
    if val is None {
        return None;
    }
    if isinstance(val, (str, int, float, bool)) {
        sized_name = declared?.__jac_sized__ if api_mode else None;
        if isinstance(sized_name, str) {
            import from jaclang.runtime.sized { json_wire_form }
            return json_wire_form(sized_name, val);
        }
        return val;
    }
    if isinstance(val, UUID) {
        return str(val);
    }
    if isinstance(val, Enum) {
        return val.value;
    }

    if isinstance(val, (list, tuple)) {
        return [
            Serializer._serialize_value(v, include_type, api_mode, ref_mode, _seen)
            for v in val
        ];
    }
    if isinstance(val, dict) {
        return {
            str(k): Serializer._serialize_value(
                v, include_type, api_mode, ref_mode, _seen
            ) for (k, v) in val.items()
        };
    }

    if isinstance(val, Access) {
        return {'anchors': {str(k): v.value for (k, v) in val.anchors.items()}};
    }
    if isinstance(val, Permission) {
        return {
            'all': val.all.value,
            'roots': Serializer._serialize_value(
                val.roots, include_type, api_mode, ref_mode, _seen
            ),
            'groups': Serializer._serialize_value(
                val.groups, include_type, api_mode, ref_mode, _seen
            )
        };
    }

    if isinstance(val, Anchor) {
        result = Serializer._type_info(val, include_type);
        result |= {
            'id': str(val.ensure_id()),
            'root': str(val.root) if val.root else None,
            'persistent': val.persistent,
            'access': Serializer._serialize_value(
                val.access, include_type, api_mode, ref_mode, _seen
            )
        };
        if val.is_populated() {
            arch = val.archetype;
            result['archetype'] = Serializer._type_info(arch, include_type)
                | Serializer._serialize_attrs(
                    arch, include_type, api_mode, ref_mode, _seen
                );
        }
        if isinstance(val, NodeAnchor) {
            edges = val.edges if api_mode else val.loaded_edges();
            result['edges'] = [str(e.ensure_id()) for e in edges];

            result['version'] = val.version;
        }
        if isinstance(val, EdgeAnchor) {
            result |= {
                'source': str(val.source.ensure_id()) if val.source else None,
                'target': str(val.target.ensure_id()) if val.target else None,
                'is_undirected': val.is_undirected
            };
        }
        return result;
    }

    if isinstance(val, Archetype) {
        if _seen is not None {
            jac_anchor = val?.__jac__;
            if jac_anchor {
                jac_id = jac_anchor.ensure_id();
                (jac_uuids, _) = _seen;
                if jac_id in jac_uuids {
                    ref_type = (
                        'node'
                            if isinstance(jac_anchor, NodeAnchor)
                            else 'edge'
                                if isinstance(jac_anchor, EdgeAnchor)
                                else 'walker'
                                    if isinstance(jac_anchor, WalkerAnchor)
                                    else 'object'
                    );
                    return {'$ref': jac_id.hex, '$type': ref_type};
                }
                jac_uuids.add(jac_id);

                try {
                    import from jaclang { JacRuntimeInterface as Jac }
                    Jac.get_context().mem.put(jac_anchor);
                } except Exception as e {
                    logger.warning(
                        f"ref_mode: failed to register {jac_id.hex} in memory: {e}"
                    );
                }
            }
        }
        result = Serializer._type_info(val, include_type);
        if api_mode {
            result |= {
                '_jac_type': type(val).__name__,
                '_jac_id': val.__jac__.ensure_id().hex if val?.__jac__ else None,
                '_jac_archetype': 'node'
                    if isinstance(val, NodeArchetype)
                    else 'walker' if isinstance(val, WalkerArchetype) else 'archetype'
            };
            type_id = val?.__jac_type_id__;
            if isinstance(type_id, str) {
                result['_jac_type_id'] = type_id;
            }
        }
        return result
            | Serializer._serialize_attrs(val, include_type, api_mode, ref_mode, _seen);
    }

    if hasattr(val, '__dict__') {
        if _seen is not None {
            (_, obj_ids) = _seen;
            obj_identity = id(val);
            if obj_identity in obj_ids {
                return str(val);
            }
            obj_ids.add(obj_identity);
        }
        result = Serializer._type_info(val, include_type);
        if api_mode {
            api_type = val?._jac_type;
            if isinstance(api_type, str) {
                result['_jac_type'] = api_type;
                type_id = val?.__jac_type_id__;
                if isinstance(type_id, str) {
                    result['_jac_type_id'] = type_id;
                }
                for key in ('_jac_type_id', '_jac_id', '_jac_archetype') {
                    if hasattr(val, key) {
                        result[key] = getattr(val, key);
                    }
                }
            } else {
                result['__type__'] = type(val).__name__;
                result['__module__'] = type(val).__module__;
            }
        }
        for (k, v) in val.__dict__.items() {
            if not k.startswith('_') {
                result[k] = Serializer._serialize_value(
                    v,
                    include_type,
                    api_mode,
                    ref_mode,
                    _seen,
                    Serializer._declared_of(val, k)
                );
            }
        }
        return result;
    }
    logger.warning(
        f"Falling back to str() for {type(val).__module__}.{type(val).__name__}"
    );
    return str(val);
}

impl Serializer.serialize_fields(
    anchor: object, field_names: set[str]
) -> dict[str, object] {
    if not hasattr(anchor, 'is_populated') or not anchor.is_populated() {
        return {};
    }
    arch = anchor.archetype;
    if arch is None {
        return {};
    }
    known = set(get_field_types(type(arch)).keys());
    _seen: tuple[set, set] = (set(), set());
    result: dict[str, object] = {};
    for name in field_names & known {
        val = getattr(arch, name, None);
        result[name] = Serializer._serialize_value(val, include_type=True, _seen=_seen);
    }

    if result and hasattr(type(arch), '__jac_schema__') {
        import from jaclang.data.schema_rules { merged_rules_for, repair_mode }
        if repair_mode() == 'repair' and (rules := merged_rules_for(type(arch))) {
            for a in rules.aliases {
                if a.new_name in result {
                    result[a.stored_name] = result[a.new_name];
                }
            }
        }
    }
    return result;
}

impl Serializer._compute_hash(anchor: Anchor) -> int {
    import from json { dumps }
    try {
        data = Serializer.serialize(anchor, include_type=True);
        return hash(dumps(data, sort_keys=True));
    } except Exception {
        return 0;
    }
}

impl Serializer.fingerprint(cls: type) -> str {
    field_pairs: list[list[str]] = [];
    if is_record(cls) {
        for f in fields(cls) {
            field_pairs.append([f.name, str(f.type)]);
        }
    }
    field_pairs.sort(key=lambda (p: list[str]) { p[0]; });
    payload = {'module': cls.__module__, 'name': cls.__name__, 'fields': field_pairs};
    encoded = _json_dumps(payload, sort_keys=True, `default=str).encode('utf-8');
    return sha256(encoded).hexdigest()[:FINGERPRINT_LENGTH];
}
