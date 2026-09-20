def _toml_section(base_path: (str | None), section: str) -> dict[str, any] {
    if not base_path {
        return {};
    }
    manifest = os.path.join(base_path, 'jac.toml');
    if not os.path.isfile(manifest) {
        return {};
    }
    try {
        import tomllib;
        with open(manifest, 'rb') as f {
            data = tomllib.load(f);
        }
        return data.get(section) or {};
    } except Exception as e {
        logger.warning(f"could not read [{section}] from {manifest}: {e}");
        return {};
    }
}

impl promotions_for(base_path: (str | None)) -> dict[str, list[str]] {
    raw: any = _toml_section(base_path, 'database').get('indexes') or {};
    out: dict[str, list[str]] = {};
    for (arch, fields_l) in raw.items() {
        if isinstance(fields_l, list) {
            out[str(arch)] = [str(x) for x in fields_l];
        }
    }
    return out;
}

impl conninfo_from_url(url: str) -> ConnInfo {
    import from urllib.parse { urlparse, unquote }
    parsed = urlparse(url);
    return ConnInfo(
        host=(parsed.hostname or '127.0.0.1'),
        port=(parsed.port or 5432),
        user=unquote(parsed.username or 'jac'),
        password=unquote(parsed.password or ''),
        database=(parsed.path or '/jac').lstrip('/') or 'jac'
    );
}

impl shared_pg_data_dir -> str {
    import from jaclang.data.pgembed { dist_cache_dir }
    return os.path.join(os.path.dirname(dist_cache_dir()), 'main');
}

impl project_db_name(base_path: str, target_path: (str | None)) -> str {
    import hashlib;
    import from jaclang.runtime.graph_utils { get_name }
    name = get_name(target_path=target_path) or 'main';
    safe = ''.join((ch if (ch.isalnum() or ch == '_') else '_') for ch in name.lower());
    digest = hashlib.sha1(os.path.realpath(base_path).encode('utf-8')).hexdigest()[:8];
    return f"jac_{safe[:40]}_{digest}";
}

glob _scratch_bases: set[str] = set(),
     _scratch: list[ScratchState] = [];

impl mark_scratch_base(base_path: str) -> None {
    _scratch_bases.add(os.path.abspath(base_path));
}

impl scratch_requested(base_path: (str | None)) -> bool {
    if os.environ.get(SCRATCH_ENV, '').strip().lower()
        not in ('', '0', 'false', 'no') {
        return True;
    }
    if not base_path {
        return False;
    }
    return os.path.abspath(base_path) in _scratch_bases;
}

impl scratch_lease(base_path: str) -> ScratchLease {
    import secrets;
    base = os.path.abspath(base_path);
    if not _scratch {
        import atexit;
        _scratch.append(
            ScratchState(
                database=f"{SCRATCH_PREFIX}{os.getpid()}_{secrets.token_hex(3)}",
                base_path=base,
                owner_pid=os.getpid()
            )
        );
        atexit.register(drop_scratch_database);
        return ScratchLease(database=_scratch[0].database);
    }
    state = _scratch[0];
    reset = state.base_path != base;
    state.base_path = base;
    return ScratchLease(database=state.database, reset=reset);
}

impl drop_scratch_database -> None {
    if not _scratch {
        return;
    }
    if _scratch[0].owner_pid != os.getpid() {
        _scratch.clear();
        return;
    }
    state = _scratch.pop();
    stop_heartbeat(state.database);
    try {
        rt = PgRuntime(data_dir=shared_pg_data_dir(), database=MAINTENANCE_DB);
        if rt.is_running() {
            rt.drop_database(state.database, force=True);
        }
    } except Exception as e {
        logger.debug(f"could not drop the scratch database {state.database}: {e}");
    }
}

impl retention_days_for(base_path: (str | None)) -> int {
    raw: str = os.environ.get(RETENTION_ENV, '').strip();
    if not raw {
        raw = str(_toml_section(base_path, 'database').get('retention_days') or '');
    }
    if not raw {
        return 0;
    }
    try {
        days = int(raw);
    } except ValueError {
        logger.warning(f"ignoring non-integer database retention setting {raw!r}");
        return 0;
    }
    return days if days > 0 else 0;
}

impl runtime_for_base(
    base_path: str, target_path: (str | None) = None
) -> RuntimeLease {
    lease: (ScratchLease | None) = None;
    if scratch_requested(base_path) {
        lease = scratch_lease(base_path);
    }
    return RuntimeLease(
        runtime=PgRuntime(
            data_dir=shared_pg_data_dir(),
            database=(
                lease.database
                    if lease is not None
                    else project_db_name(base_path, target_path)
            ),
            owner_path=os.path.abspath(base_path),
            kind=DbKind.SCRATCH if lease is not None else DbKind.PROJECT,
            retention_days=(0 if lease is not None else retention_days_for(base_path))
        ),
        reset=lease is not None and lease.reset
    );
}

impl takeover_project(base_path: str, target_path: (str | None) = None) -> int {
    url = os.environ.get('JAC_DB_URL', '');
    if url {
        store = PgStore(conninfo=conninfo_from_url(url));
    } else {
        rt = runtime_for_base(base_path, target_path).runtime;
        store = PgStore(conninfo=rt.ensure(), ensure_cb=rt.ensure);
    }
    try {
        return store.takeover();
    } finally {
        store.close();
    }
}

def _ancestry_of(arch: (object | None)) -> list[str] {
    import from jaclang.runtime.constructs {
        Archetype,
        NodeArchetype,
        EdgeArchetype,
        WalkerArchetype
    }
    if arch is None {
        return [];
    }
    stops = (NodeArchetype, EdgeArchetype, WalkerArchetype, Archetype, object);
    out: list[str] = [];
    for c in type(arch).__mro__ {
        if c in stops {
            break;
        }
        out.append(c.__name__);
    }
    return out;
}

def _is_serialization_conflict(e: Exception) -> bool {
    seen = 0;
    cur: (BaseException | None) = e;
    while cur is not None and seen < 8 {
        c: BaseException = cur;
        for arg in getattr(c, 'args', ()) {
            if isinstance(arg, dict)
                and arg.get('C') in ('40001', '40P01', '55P03', '08006') {
                return True;
            }
        }
        cur = c.__cause__ or c.__context__;
        seen += 1;
    }
    return False;
}

def _json_default(o: object) -> str {
    return str(o);
}

def _persist_hash(anchor: Anchor) -> int {
    import from json { dumps }
    import from jaclang.data.serializer { Serializer }
    try {
        data = Serializer.serialize(anchor, include_type=True);
        if isinstance(data, dict) {
            data.pop('edges', None);
        }
        return hash(dumps(data, sort_keys=True));
    } except Exception {
        return 0;
    }
}
