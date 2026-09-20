impl Serializer.register(cls: type) -> None {
    Serializer._registry[f"{cls.__module__}.{cls.__name__}"] = cls;
    import from jaclang.runtime.typecache {
        invalidate as _invalidate_typecache,
        warm as _warm_typecache
    }
    _invalidate_typecache(cls);

    _warm_typecache(cls);
    try {
        setattr(cls, '__jac_fingerprint__', Serializer.fingerprint(cls));
    } except Exception as e {
        logger.debug(f"Failed to compute fingerprint for {cls.__name__}: {e}");
        setattr(cls, '__jac_fingerprint__', '');
    }

    import from jaclang.data.schema_rules { collect_rules }
    if (rules := collect_rules(cls)) {
        for old_name in rules.was_names {
            Serializer.register_alias(old_name, cls);
        }
    }
}

impl Serializer.is_auto_registered_module(module_name: str) -> bool {
    return (
        not module_name.startswith('jaclang.')
        or module_name.startswith('jaclang.scale.')
    );
}

impl Serializer.register_alias(old_name: str, cls: type) -> None {
    new_name = f"{cls.__module__}.{cls.__name__}";
    if old_name == new_name {
        logger.debug(f"archetype_alias: {old_name} == current name; alias is a no-op");
        return;
    }
    Serializer._aliases[old_name] = new_name;
}

impl Serializer.repair(
    data: dict[str, object], cls: type
) -> tuple[dict[str, object], list[str]] {
    import from jaclang.data.schema_rules { apply_rules, merged_rules_for, repair_mode }
    mode = repair_mode();
    if mode == 'off' {
        return (data, []);
    }
    rules = merged_rules_for(cls);
    if rules is None {
        return (data, []);
    }
    (repaired, steps) = apply_rules(data, rules);
    if repaired is data and not steps {
        return (data, []);
    }
    cls_key = f"{cls.__module__}.{cls.__name__}";
    if mode == 'detect' {
        if steps and (n := Serializer._warn_occurrence("drift-detected", cls_key)) {
            logger.info(
                f"Serializer: drift detected on {cls_key} "
                f"(JAC_SCHEMA_REPAIR=detect; steps not applied: {steps})"
                    + Serializer._occurrence_note(n)
            );
        }
        return (data, []);
    }
    if steps and (n := Serializer._warn_occurrence("repaired", cls_key)) {
        logger.info(
            f"Serializer: repaired {cls_key}: {steps}" + Serializer._occurrence_note(n)
        );
    }

    return (repaired, steps);
}

impl Serializer.coerce(val: object, target_type: object) -> tuple[object, bool] {
    if target_type is None or isinstance(target_type, str) {
        return (val, False);
    }

    (origin, args) = (get_origin(target_type), get_args(target_type));
    if origin is Union or origin is UnionType {
        non_none = [
            a
            for a in args
            if a is not NoneType
        ];
        if val is None {
            return (None, True);
        }

        for variant in non_none {
            (coerced, ok) = Serializer.coerce(val, variant);
            if ok {
                return (coerced, True);
            }
        }
        return (val, False);
    }

    base = origin if origin is not None else target_type;
    if not isinstance(base, type) {
        return (val, True);
    }
    if val is None {
        return (None, False);
    }
    if isinstance(val, base) {
        return (val, True);
    }

    try {
        sized_name = base?.__jac_sized__;
        if isinstance(sized_name, str) {
            import from jaclang.runtime.sized { json_wire_read }
            if isinstance(val, (bool, int, float, str)) {
                return (json_wire_read(sized_name, val), True);
            }
            return (val, False);
        }
        if base is bool {
            if isinstance(val, (int, float)) {
                return (bool(val), True);
            }
            if isinstance(val, str) {
                lowered = val.strip().lower();
                if lowered in ('true', '1', 'yes', 'y', 'on') {
                    return (True, True);
                }
                if lowered in ('false', '0', 'no', 'n', 'off', '') {
                    return (False, True);
                }
            }
            return (val, False);
        }
        if base is int {
            if isinstance(val, bool) {
                return (int(val), True);
            }
            if isinstance(val, (str, float)) {
                return (int(val), True);
            }
        }
        if base is float {
            if isinstance(val, (bool, int, str)) {
                return (float(val), True);
            }
        }
        if base is str {
            return (str(val), True);
        }
        if base is UUID and isinstance(val, str) {
            return (UUID(val), True);
        }

        if base is datetime and isinstance(val, str) {
            return (getattr(datetime, 'fromisoformat')(val), True);
        }
        if base is date and isinstance(val, str) {
            return (getattr(date, 'fromisoformat')(val), True);
        }
        if base is time and isinstance(val, str) {
            return (getattr(time, 'fromisoformat')(val), True);
        }
        if isinstance(base, type) and issubclass(base, Enum) {
            try {
                return (base(val), True);
            } except (ValueError, KeyError) {
                members = getattr(base, '__members__', {});
                if isinstance(val, str) and val in members {
                    return (members[val], True);
                }
            }
        }

        if base is tuple and isinstance(val, list) {
            return (tuple(val), True);
        }
        if base is list and isinstance(val, tuple) {
            return (list(val), True);
        }
    } except Exception as e {
        logger.debug(
            f"Serializer.coerce fallback: {type(val).__name__} -> "
            f"{getattr(base, '__name__', base)}: {e}"
        );
    }
    return (val, False);
}

impl Serializer._get_class(module_name: str, class_name: str) -> (type | None) {
    if not module_name or not class_name {
        return None;
    }
    key = f"{module_name}.{class_name}";
    if (cls := Serializer._registry.get(key)) {
        return cls;
    }

    if (aliased_key := Serializer._aliases.get(key)) {
        aliased = Serializer._registry.get(aliased_key);
        if aliased is None and '.' in aliased_key {
            alias_parts = aliased_key.rsplit('.', 1);
            aliased = Serializer._resolve_class_by_import(
                alias_parts[0], alias_parts[1]
            );
            if aliased is not None {
                Serializer.register(cast(type, aliased));
            }
        }
        if aliased is not None {
            if (n := Serializer._warn_occurrence("alias-resolved", key)) {
                logger.info(
                    f"Serializer: resolving aliased class {key} -> {aliased_key}"
                        + Serializer._occurrence_note(n)
                );
            }
            return aliased;
        }

        if (n := Serializer._warn_occurrence("alias-missing", key)) {
            logger.warning(
                f"Serializer: alias {key} -> {aliased_key} has no registered "
                "target; cannot resolve."
                    + Serializer._occurrence_note(n)
            );
        }
        return None;
    }
    if (resolved := Serializer._resolve_class_by_import(module_name, class_name)) {
        Serializer.register(resolved);
        if (n := Serializer._warn_occurrence("import-resolved", key)) {
            logger.info(
                f"Serializer: {key} was not registered when it was first read; "
                "resolved it from its own module and registered it. Archetype "
                "classes normally register themselves as they are defined."
                    + Serializer._occurrence_note(n)
            );
        }
        return resolved;
    }
    if (n := Serializer._warn_occurrence("unregistered", key)) {
        logger.warning(
            f"Refused to deserialize unregistered class: {key}; it is not "
            "registered and could not be resolved from its own module "
            "(enable DEBUG on this logger for the resolution attempt)."
                + Serializer._occurrence_note(n)
        );
    }
    return None;
}

impl Serializer._resolve_class_by_import(
    module_name: str, class_name: str
) -> (type | None) {
    if not class_name.isidentifier() {
        return None;
    }
    module_parts = module_name.split('.');
    for part in module_parts {
        if not part.isidentifier() {
            return None;
        }
    }
    tracing = logger.isEnabledFor(logging.DEBUG);
    if not Serializer.is_auto_registered_module(module_name) {
        if tracing {
            logger.debug(
                f"Serializer: refusing {module_name}.{class_name}; runtime-internal "
                "archetypes only resolve when they are registered explicitly"
            );
        }
        return None;
    }
    mod = sys.modules.get(module_name);
    if mod is None {
        if not Serializer._import_allowed(module_name) {
            if tracing {
                logger.debug(
                    f"Serializer: not importing {module_name} to resolve "
                    f"{class_name}; a recent import of it failed and its retry "
                    "window has not passed"
                );
            }
            return None;
        }
        if module_parts[0] not in sys.modules {
            if tracing {
                logger.debug(
                    f"Serializer: not importing {module_name} to resolve "
                    f"{class_name}; its top-level package is not loaded here"
                );
            }
            return None;
        }
        try {
            mod = importlib.import_module(module_name);
        } except Exception as e {
            retry_in = Serializer._record_import_failure(module_name);
            logger.debug(
                f"Serializer: cannot import {module_name} to resolve "
                f"{class_name}: {e}; retrying it in {retry_in:.0f}s"
            );
            return None;
        }
    }
    Serializer._clear_import_failure(module_name);
    try {
        found = getattr(mod, class_name, None);
    } except Exception as e {
        logger.debug(f"Serializer: {module_name}.{class_name} is not readable: {e}");
        return None;
    }
    if not isinstance(found, type) or not issubclass(found, Archetype) {
        if tracing {
            logger.debug(
                f"Serializer: refusing {module_name}.{class_name}; it is not an "
                "Archetype subclass"
            );
        }
        return None;
    }
    if found.__module__ != module_name or found.__name__ != class_name {
        if tracing {
            logger.debug(
                f"Serializer: refusing {module_name}.{class_name}; it resolves to "
                f"{found.__module__}.{found.__name__}"
            );
        }
        return None;
    }
    return cast(type, found);
}

def _import_retry_window(attempts: int) -> float {
    doublings = min(max(attempts - 1, 0), _IMPORT_RETRY_MAX_DOUBLINGS);
    return min(_IMPORT_RETRY_SECONDS * (2 ** doublings), _IMPORT_RETRY_CEILING_SECONDS);
}

def _import_retry_due(failure: ImportFailure) -> bool {
    return monotonic() - failure.failed_at >= _import_retry_window(failure.attempts);
}

impl Serializer._import_allowed(module_name: str) -> bool {
    failure = Serializer._import_failures.get(module_name);
    return failure is None or _import_retry_due(failure);
}

impl Serializer._record_import_failure(module_name: str) -> float {
    with Serializer._import_lock {
        failures = Serializer._import_failures;
        failure = failures.get(module_name);
        if failure is None {
            if len(failures) >= _MAX_IMPORT_FAILURES {
                for (name, stale) in list(failures.items()) {
                    if _import_retry_due(stale) {
                        failures.pop(name, None);
                    }
                }
                if len(failures) >= _MAX_IMPORT_FAILURES {
                    return _import_retry_window(1);
                }
            }
            failure = ImportFailure();
            failures[module_name] = failure;
        }
        failure.attempts += 1;
        failure.failed_at = monotonic();
        return _import_retry_window(failure.attempts);
    }
}

impl Serializer._clear_import_failure(module_name: str) -> None {
    if module_name not in Serializer._import_failures {
        return;
    }
    with Serializer._import_lock {
        Serializer._import_failures.pop(module_name, None);
    }
}

impl Serializer._reset_import_failures -> None {
    with Serializer._import_lock {
        Serializer._import_failures.clear();
    }
}

impl Serializer._warn_occurrence(scope: str, key: str) -> int {
    dedup_key = f"{scope}:{key}";
    counts = Serializer._warn_counts;
    seen_count = counts.get(dedup_key);
    if seen_count is not None {
        n = seen_count + 1;
        counts[dedup_key] = n;
        return n if Serializer._is_report_threshold(n) else 0;
    }
    if Serializer._warn_dedup_saturated {
        if logger.isEnabledFor(logging.DEBUG) {
            logger.debug(
                f"Serializer: warning suppressed (dedup cap reached): {dedup_key}"
            );
        }
        return 0;
    }
    with Serializer._warn_lock {
        seen_count = counts.get(dedup_key);
        if seen_count is not None {
            n = seen_count + 1;
            counts[dedup_key] = n;
            return n if Serializer._is_report_threshold(n) else 0;
        }
        if len(counts) >= _MAX_WARNED_CLASS_KEYS {
            if not Serializer._warn_dedup_saturated {
                Serializer._warn_dedup_saturated = True;
                logger.warning(
                    f"Serializer: warning dedup cache reached {_MAX_WARNED_CLASS_KEYS} "
                    "distinct keys; further first-occurrence warnings are suppressed "
                    "(enable DEBUG to still see suppressed keys)."
                );
            }
            return 0;
        }
        counts[dedup_key] = 1;
        return 1;
    }
}

impl Serializer._is_report_threshold(n: int) -> bool {
    if n < 1 {
        return False;
    }
    while n % 10 == 0 {
        n //= 10;
    }
    return n == 1;
}

impl Serializer._occurrence_note(n: int) -> str {
    return f" (occurrence #{n})";
}

impl Serializer._reset_warn_cache -> None {
    with Serializer._warn_lock {
        Serializer._warn_counts.clear();
        Serializer._warn_dedup_saturated = False;
    }
}
