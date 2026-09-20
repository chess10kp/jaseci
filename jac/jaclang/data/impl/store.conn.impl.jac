impl PgStore.postinit -> None {
    self._conn = None;
    self._side_conn = None;
    self._lock = threading.RLock();
    self._server_version = None;
    self._in_txn = False;
    self._isolation = None;
    self._known_types = set();
    self._listeners = [];
    self._listen_thread = None;
    self._listen_stop = None;
    self._side_listened = False;
    self._booted = False;
    self._ready = False;
    self._readying = None;
}

impl PgStore._ensure_ready -> None {
    if self._ready {
        return;
    }
    with self._lock {
        if self._ready or self._readying == threading.get_ident() {
            return;
        }
        self._readying = threading.get_ident();
        try {
            if self.ensure_cb is not None and not self._booted {
                self.conninfo = self.ensure_cb();
                self._booted = True;
            }
            if self.auto_schema {
                self.ensure_schema_once(self.promotions);
            }
            self._ready = True;
            if self.pending_reset {
                self.pending_reset = False;
                self.reset_data();
            }
        } finally {
            self._readying = None;
        }
    }
}

impl PgStore._connect -> any {
    import from jaclang.data.pgload { connect as pg_connect }
    import from jaclang.data.pgpool { checkout }
    info = self.conninfo;
    pooled = checkout(info);
    if pooled is not None {
        return pooled;
    }
    return pg_connect(
        info.user,
        host=(info.host or None),
        port=info.port,
        unix_socket_dir=info.unix_socket_dir,
        database=info.database,
        password=(info.password or None),
        startup_params={'application_name': _app_identity()}
    );
}

impl PgStore._main -> any {
    if self._conn is None {
        self._conn = self._connect();
    }
    return self._conn;
}

impl PgStore._side -> any {
    self._ensure_ready();
    if self._side_conn is None {
        self._side_conn = self._connect();
    }
    return self._side_conn;
}

impl PgStore._run(sql: str, params: dict[str, any]) -> list[any] {
    self._ensure_ready();
    with self._lock {
        conn: any = None;
        try {
            conn = self._main();
        } except Exception as e {
            if not (_conn_dead(e) and self.ensure_cb is not None) {
                raise;
            }
            self._conn = None;
            try {
                self.conninfo = self.ensure_cb();
            } except Exception {}
            conn = self._main();
        }
        try {
            return conn.run(sql, **params) or [];
        } except Exception as e {
            if _conn_dead(e) {
                try {
                    conn.close();
                } except Exception {}
                self._conn = None;
                was_txn = self._in_txn;
                self._in_txn = False;
                if self.ensure_cb is not None {
                    try {
                        self.conninfo = self.ensure_cb();
                    } except Exception {}
                }
                if was_txn {
                    import from jaclang.data.pgwire { PgWireError }
                    raise PgWireError(
                        {'C': '08006', 'M': 'connection lost mid-transaction; retry'}
                    ) from e;
                }
                conn2: any = self._main();
                return conn2.run(sql, **params) or [];
            }
            if self._in_txn {
                try {
                    conn.run('ROLLBACK');
                } except Exception {}
                self._in_txn = False;
            }
            raise;
        }
    }
}

impl PgStore.is_available -> bool {
    try {
        self._run('SELECT 1', {});
        return True;
    } except Exception {
        return False;
    }
}

impl PgStore.server_version -> int {
    if self._server_version is None {
        raw = str(self._run('SHOW server_version_num', {})[0][0]);
        self._server_version = int(raw) // 10000;
    }
    return self._server_version;
}

impl PgStore.close -> None {
    parked: any = None;
    main_conn: any = None;
    side_conn: any = None;
    was_txn = False;
    listened = False;
    with self._lock {
        parked = self._stop_listen_thread();
        self._listeners = [];
        main_conn = self._conn;
        side_conn = self._side_conn;
        was_txn = self._in_txn;
        listened = self._side_listened;
        self._conn = None;
        self._side_conn = None;
        self._in_txn = False;
        self._side_listened = False;
    }
    self._join_listen_thread(parked);
    _park_conn(self.conninfo, main_conn, was_txn, False);
    _park_conn(self.conninfo, side_conn, False, listened);
}
