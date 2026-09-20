impl SessionConflictError.init(
    self: SessionConflictError,
    database: str = '',
    blockers: (list[dict[str, any]] | None) = None
) -> None {
    self.database = database;
    self.blockers = list(blockers or []);
    parts: list[str] = [];
    for b in self.blockers {
        owner = b.get('owner_pid');
        who = (
            f"pid {owner}"
                if owner is not None
                else f"backend {b.get('backend_pid', '?')}"
        );
        cmd = str(b.get('cmd') or '');
        if cmd {
            who = f"{who} (jac {cmd})";
        }
        started = str(b.get('started') or '');
        if started {
            who = f"{who} since {started}";
        }
        parts.append(who);
    }
    detail = '; '.join(parts) if parts else 'an unidentified session';
    super.__init__(
        f"project database '{database}' is held by another live jac"
        f" process: {detail}"
    );
}

impl PgStore.ensure_schema(promotions: dict[str, list[str]]) -> None {
    with self._lock {
        self.promotions = dict(promotions);
        fp = self._schema_fingerprint();
        if self._schema_stamp() == fp {
            self._load_known_types();
            return;
        }
        held = self._acquire_schema_lock(fp);
        try {
            if self._schema_stamp() == fp {
                self._load_known_types();
                return;
            }
            try {
                self._apply_schema_ddl_resilient();
            } except PgWireError as e {
                if _sqlstate(e) != '55P03' {
                    raise;
                }
                if self._reap_dead_sessions() == 0 {
                    raise SessionConflictError(
                        database=self.conninfo.database, blockers=self._live_blockers()
                    ) from e;
                }
                try {
                    self._apply_schema_ddl_resilient();
                } except PgWireError as e2 {
                    if _sqlstate(e2) != '55P03' {
                        raise;
                    }
                    raise SessionConflictError(
                        database=self.conninfo.database, blockers=self._live_blockers()
                    ) from e2;
                }
            }
            self.kv_put(SCHEMA_STAMP_KEY, fp);
            self._load_known_types();
        } finally {
            if held {
                self._release_schema_lock();
            }
        }
    }
}

impl PgStore.ensure_schema_once(promotions: dict[str, list[str]]) -> None {
    self._ensure_ready();
    ns = _store_ns(self.conninfo);
    key = _schema_extension_key();
    if _schema_ready.get(ns) == key {
        return;
    }
    with _schema_gate {
        if _schema_ready.get(ns) == key {
            return;
        }
        self.ensure_schema(promotions);
        _schema_ready[ns] = key;
    }
}

impl PgStore.reset_data -> None {
    with self._lock {
        if self._in_txn {
            self.rollback();
        }
        listed = self._run(
            'SELECT tablename FROM pg_tables WHERE schemaname = current_schema()', {}
        );
        tables = [str(row[0]) for row in listed];
        if not tables {
            return;
        }
        stamp = self._schema_stamp();
        targets = ', '.join(f'"{name}"' for name in sorted(tables));
        self._run(f"TRUNCATE {targets} RESTART IDENTITY CASCADE", {});
        if stamp {
            self.kv_put(SCHEMA_STAMP_KEY, stamp);
        }
        self._known_types = set();
    }
}

impl PgStore._acquire_schema_lock(fingerprint: str) -> bool {
    import time;
    deadline = time.monotonic() + _SCHEMA_LOCK_WAIT_SECONDS;
    delay = _SCHEMA_LOCK_POLL_SECONDS;
    while True {
        try {
            got = self._run(
                'SELECT pg_try_advisory_lock(:k)', {'k': _schema_lock_key()}
            );
            if got and bool(got[0][0]) {
                return True;
            }
        } except PgWireError as e {
            logger.debug(f"schema election unavailable ({_sqlstate(e)}): {e}");
            return False;
        }
        if self._schema_stamp() == fingerprint {
            return False;
        }
        if time.monotonic() >= deadline {
            logger.warning(
                f"waited {_SCHEMA_LOCK_WAIT_SECONDS:.0f}s for the schema"
                f" election on '{self.conninfo.database}'; applying schema"
                ' DDL without it'
            );
            return False;
        }
        time.sleep(delay);
        delay = min(delay * 2, _SCHEMA_LOCK_POLL_MAX_SECONDS);
    }
}

impl PgStore._release_schema_lock -> None {
    try {
        self._run('SELECT pg_advisory_unlock(:k)', {'k': _schema_lock_key()});
    } except Exception as e {
        logger.debug(f"schema election release failed: {e}");
    }
}

impl PgStore._apply_schema_ddl_resilient -> None {
    try {
        self._apply_schema_ddl();
    } except PgWireError as e {
        state = _sqlstate(e);
        if state not in _CONCURRENT_CREATE_STATES {
            raise;
        }
        logger.info(
            f"schema DDL lost a catalog race ({state}); a concurrent creator"
            ' won, re-checking'
        );
        if self._schema_stamp() == self._schema_fingerprint() {
            return;
        }

        self._apply_schema_ddl();
    }
}

impl PgStore._apply_schema_ddl -> None {
    self._run("SET lock_timeout = '5s'", {});
    try {
        for stmt in _SCHEMA_SQL {
            self._run(stmt, {});
        }
        has_seq = bool(
            self._run(
                """
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'anchors' AND column_name = 'seq'
                """,
                {}
            )
        );
        if not has_seq {
            self._run('ALTER TABLE anchors ADD COLUMN IF NOT EXISTS seq bigserial', {});
        }
        if self._promoted_column_type('version') is None {
            self._run(
                'ALTER TABLE anchors ADD COLUMN IF NOT EXISTS version bigint '
                'NOT NULL DEFAULT 0',
                {}
            );
        }
        self._apply_promotions();
        self._property_graph_ddl();
        for name in sorted(_schema_extensions) {
            for stmt in _schema_extensions[name] {
                self._run(stmt, {});
            }
        }
    } finally {
        self._run('SET lock_timeout = DEFAULT', {});
    }
}

impl PgStore._load_known_types -> None {
    for (tname, ) in self._run('SELECT DISTINCT type_name FROM graph_types', {}) {
        self._known_types.add(str(tname));
    }
}

impl PgStore._schema_fingerprint -> str {
    import hashlib;
    h = hashlib.sha256();
    h.update(str(SCHEMA_VERSION).encode());
    h.update(str(self.server_version()).encode());
    for stmt in _SCHEMA_SQL {
        h.update(stmt.encode());
    }
    for col in sorted(self._promotion_columns()) {
        h.update(str(col).encode());
    }
    for name in sorted(_schema_extensions) {
        h.update(name.encode());
        for stmt in _schema_extensions[name] {
            h.update(stmt.encode());
        }
    }
    return f"{SCHEMA_VERSION}:{h.hexdigest()[:24]}";
}

impl PgStore._schema_stamp -> (str | None) {
    try {
        return self.kv_get(SCHEMA_STAMP_KEY);
    } except PgWireError as e {
        if _sqlstate(e) == '42P01' {
            return None;
        }
        raise;
    }
}

impl PgStore._peer_sessions -> list[dict[str, any]] {
    rows = self._run(
        """
        SELECT pid, application_name, state, backend_start::text
        FROM pg_stat_activity
        WHERE datname = current_database() AND pid <> pg_backend_pid()
        """,
        {}
    );
    out: list[dict[str, any]] = [];
    for (pid, app, state, started) in rows {
        app_s = str(app or '');
        owner: (int | None) = None;
        cmd = '';
        parts = app_s.split(':', 2);
        if len(parts) == 3 and parts[0] == 'jac' {
            owner = _parse_pid(parts[1]);
            cmd = parts[2];
        }
        out.append(
            {
                'backend_pid': int(pid),
                'app': app_s,
                'state': str(state or ''),
                'started': str(started or ''),
                'owner_pid': owner,
                'cmd': cmd,
                'owner_alive': _owner_alive(owner)
            }
        );
    }
    return out;
}

impl PgStore._reap_dead_sessions -> int {
    if not self.conninfo.unix_socket_dir {
        return 0;
    }
    n = 0;
    for p in self._peer_sessions() {
        if p['owner_pid'] is not None and not p['owner_alive'] {
            try {
                self._run('SELECT pg_terminate_backend(:p)', {'p': p['backend_pid']});
                n += 1;
            } except Exception as e {
                logger.warning(f"failed to reap backend {p['backend_pid']}: {e}");
            }
        }
    }
    if n {
        logger.info(f"reaped {n} database session(s) left by dead process(es)");
    }
    return n;
}

impl PgStore._live_blockers -> list[dict[str, any]] {
    peers = [
        p
        for p in self._peer_sessions()
        if p['owner_alive']
    ];
    held = [
        p
        for p in peers
        if 'idle in transaction' in str(p['state'])
    ];
    return held or peers;
}

impl PgStore.takeover -> int {
    n = 0;
    for p in self._peer_sessions() {
        try {
            self._run('SELECT pg_terminate_backend(:p)', {'p': p['backend_pid']});
            n += 1;
        } except Exception as e {
            logger.warning(f"takeover failed for backend {p['backend_pid']}: {e}");
        }
    }
    return n;
}

impl PgStore._promotion_columns -> list[tuple[str, str, str]] {
    out: list[tuple[str, str, str]] = [];
    for (arch, fields_l) in sorted(self.promotions.items()) {
        for fld in fields_l {
            col = f"g_{_sanitize_ident(arch)}_{_sanitize_ident(fld)}";
            out.append((arch, fld, col));
        }
    }
    return out;
}

impl PgStore._promoted_column_type(col: str) -> (str | None) {
    rows = self._run(
        'SELECT data_type FROM information_schema.columns '
        'WHERE table_name = :t AND column_name = :c',
        {'t': 'anchors', 'c': col.lower()}
    );
    return str(rows[0][0]) if rows else None;
}

impl PgStore._apply_promotions -> None {
    for (arch, fld, col) in self._promotion_columns() {
        try {
            have = self._promoted_column_type(col);
            if have is not None and have != 'jsonb' {
                logger.info(
                    f"promotion {arch}.{fld}: rebuilding {col} from {have} to jsonb"
                );
                self._run(f'DROP INDEX IF EXISTS idx_{col}', {});
                self._run(f'ALTER TABLE anchors DROP COLUMN IF EXISTS {col}', {});
            }
            self._run(
                f"""
                ALTER TABLE anchors ADD COLUMN IF NOT EXISTS {col} jsonb
                GENERATED ALWAYS AS (props->'archetype'->'{fld}') STORED
                """,
                {}
            );
            self._run(f'CREATE INDEX IF NOT EXISTS idx_{col} ON anchors ({col})', {});
        } except Exception as e {
            logger.warning(f"promotion {arch}.{fld} failed: {e}");
        }
    }
}

impl PgStore._property_graph_ddl -> None {
    if self.server_version() < 19 {
        return;
    }
    stmts = [
        """
        CREATE OR REPLACE VIEW graph_nodes AS
            SELECT id, arch_type, root_id, props FROM anchors
            WHERE kind = 'NodeAnchor'
        """,
        """
        CREATE OR REPLACE VIEW graph_edges AS
            SELECT id, arch_type, src, dst, undirected, props FROM anchors
            WHERE kind = 'EdgeAnchor' AND src IS NOT NULL AND dst IS NOT NULL
        """,
        """
        CREATE PROPERTY GRAPH IF NOT EXISTS jac_graph
            VERTEX TABLES (
                graph_nodes KEY (id) LABEL node PROPERTIES (arch_type)
            )
            EDGE TABLES (
                graph_edges KEY (id)
                    SOURCE KEY (src) REFERENCES graph_nodes (id)
                    DESTINATION KEY (dst) REFERENCES graph_nodes (id)
                    LABEL edge PROPERTIES (arch_type)
            )
        """
    ];
    for stmt in stmts {
        try {
            self._run(stmt, {});
        } except Exception as e {
            logger.debug(f"property graph ddl skipped: {e}");
            return;
        }
    }
}
