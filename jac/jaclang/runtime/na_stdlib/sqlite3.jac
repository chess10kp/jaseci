import from _sqlite3_native {
    sq3_open_v2,
    sq3_open_err,
    sq3_close,
    sq3_busy_timeout,
    sq3_prepare,
    sq3_prep_stmt,
    sq3_prep_tail,
    sq3_prep_sqlp,
    sq3_prepare_tail,
    sq3_prep_stmt2,
    sq3_free,
    sq3_step,
    sq3_reset,
    sq3_finalize,
    sq3_clear_bindings,
    sq3_column_count,
    sq3_column_type,
    sq3_column_int,
    sq3_column_float,
    sq3_column_raw,
    sq3_column_name,
    sq3_errmsg,
    sq3_exec,
    sq3_exec_err,
    sq3_changes,
    sq3_total_changes,
    sq3_last_insert_rowid,
    sq3_get_autocommit,
    sq3_complete,
    sq3_bind_parameter_count,
    sq3_bind_parameter_name,
    sq3_bind_null,
    sq3_bind_int,
    sq3_bind_double,
    sq3_bind_text,
    sq3_bind_blob,
    sq3_libversion
}

glob apilevel: str = "2.0",
     paramstyle: str = "qmark",
     threadsafety: int = 3,
     sqlite_version: str = sq3_libversion();

glob PARSE_DECLTYPES: int = 1,
     PARSE_COLNAMES: int = 2,
     LEGACY_TRANSACTION_CONTROL: int = -1;

glob SQLITE_OK: int = 0,
     SQLITE_ERROR: int = 1,
     SQLITE_ABORT: int = 4,
     SQLITE_BUSY: int = 5,
     SQLITE_LOCKED: int = 6,
     SQLITE_NOMEM: int = 7,
     SQLITE_READONLY: int = 8,
     SQLITE_INTERRUPT: int = 9,
     SQLITE_IOERR: int = 10,
     SQLITE_FULL: int = 13,
     SQLITE_CANTOPEN: int = 14,
     SQLITE_SCHEMA: int = 17,
     SQLITE_TOOBIG: int = 18,
     SQLITE_CONSTRAINT: int = 19,
     SQLITE_MISMATCH: int = 20,
     SQLITE_MISUSE: int = 21,
     SQLITE_RANGE: int = 25,
     SQLITE_NOTADB: int = 26,
     SQLITE_INTEGER: int = 1,
     SQLITE_FLOAT: int = 2,
     SQLITE_TEXT: int = 3,
     SQLITE_BLOB: int = 4,
     SQLITE_NULL: int = 5;


obj:pub Warning(Exception) {}

obj:pub Error(Exception) {}

obj:pub InterfaceError(Error) {}

obj:pub DatabaseError(Error) {}

obj:pub InternalError(DatabaseError) {}

obj:pub OperationalError(DatabaseError) {}

obj:pub ProgrammingError(DatabaseError) {}

obj:pub IntegrityError(DatabaseError) {}

obj:pub DataError(DatabaseError) {}

obj:pub NotSupportedError(DatabaseError) {}


def _ver_info -> tuple[(int, int, int)] {
    s = sq3_libversion();
    nums: list[int] = [];
    cur = 0;
    got = False;
    for i in range(len(s)) {
        c = s[i:i + 1];
        if c == "." {
            nums.append(cur);
            cur = 0;
        } else {
            cur = cur * 10 + int(c);
            got = True;
        }
    }
    if got {
        nums.append(cur);
    }
    a = 0;
    b = 0;
    c2 = 0;
    if len(nums) > 0 {
        a = nums[0];
    }
    if len(nums) > 1 {
        b = nums[1];
    }
    if len(nums) > 2 {
        c2 = nums[2];
    }
    return (a, b, c2);
}

glob sqlite_version_info: tuple[(int, int, int)] = _ver_info();


def _type_name(v: any) -> str {
    if isinstance(v, bool) {
        return "bool";
    }
    if isinstance(v, int) {
        return "int";
    }
    if isinstance(v, float) {
        return "float";
    }
    if isinstance(v, str) {
        return "str";
    }
    if isinstance(v, bytes) {
        return "bytes";
    }
    if isinstance(v, bytearray) {
        return "bytearray";
    }
    if isinstance(v, list) {
        return "list";
    }
    if isinstance(v, tuple) {
        return "tuple";
    }
    if isinstance(v, dict) {
        return "dict";
    }
    if isinstance(v, set) {
        return "set";
    }
    if v is None {
        return "NoneType";
    }
    return "object";
}


def _raise_db_error(db: int, rc: int) {
    msg = sq3_errmsg(db);
    base = rc % 256;
    if base == 19 {
        raise IntegrityError(msg);
    }
    if base == 2 {
        raise InternalError(msg);
    }
    if base == 7 {
        raise MemoryError(msg);
    }
    if base == 25 {
        raise ProgrammingError(msg);
    }
    if base == 20 {
        raise InterfaceError(msg);
    }
    raise OperationalError(msg);
}


def _raise_msg(rc: int, msg: str) {
    base = rc % 256;
    if base == 19 {
        raise IntegrityError(msg);
    }
    if base == 2 {
        raise InternalError(msg);
    }
    if base == 7 {
        raise MemoryError(msg);
    }
    if base == 25 {
        raise ProgrammingError(msg);
    }
    if base == 20 {
        raise InterfaceError(msg);
    }
    raise OperationalError(msg);
}


def _is_dml(sql: str) -> bool {
    i = 0;
    n = len(sql);
    while i < n {
        c = sql[i:i + 1];
        if c == " "
            or c == "\t"
            or c == "\n"
            or c == "\r"
            or c == "\x0b"
            or c == "\x0c" {
            i += 1;
            continue;
        }
        if c == "-" and i + 1 < n and sql[i + 1:i + 2] == "-" {
            while i < n and sql[i:i + 1] != "\n" {
                i += 1;
            }
            continue;
        }
        if c == "/" and i + 1 < n and sql[i + 1:i + 2] == "*" {
            i += 2;
            while i + 1 < n and not (sql[i:i + 1] == "*" and sql[i + 1:i + 2] == "/") {
                i += 1;
            }
            i += 2;
            if i > n {
                i = n;
            }
            continue;
        }
        break;
    }
    w = "";
    while i < n {
        c = sql[i:i + 1];
        if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") {
            w += c;
            i += 1;
        } else {
            break;
        }
    }
    lw = w.lower();
    return lw == "insert" or lw == "update" or lw == "delete" or lw == "replace";
}


def _is_sequence_params(p: any) -> bool {
    return isinstance(p, list)
        or isinstance(p, tuple)
        or isinstance(p, str)
        or isinstance(p, bytes)
        or isinstance(p, bytearray);
}


obj:pub Connection {
    has _db: int = 0,
        _open: bool = False,
        isolation_level: (str | None) = "",
        autocommit: int = -1,
        in_transaction: bool = False,
        total_changes: int = 0,
        _cursors: list[Cursor] = [],
        _pool: dict[str, list[int]] = {},
        _pool_n: int = 0,
        _cache_max: int = 128;

    def cursor -> Cursor {
        if not self._open {
            raise ProgrammingError("Cannot operate on a closed database.");
        }
        cur = Cursor();
        cur.connection = self;
        self._cursors.append(cur);
        return cur;
    }

    def execute(
        sql: any, parameters: (list[any] | dict[str, any] | None) = None
    ) -> Cursor {
        cur = self.cursor();
        return cur.execute(sql, parameters);
    }

    def executemany(sql: any, seq_of_parameters: list[list[any]]) -> Cursor {
        cur = self.cursor();
        return cur.executemany(sql, seq_of_parameters);
    }

    def executescript(sql_script: str) -> Cursor {
        return self.cursor().executescript(sql_script);
    }

    def _sync_state {
        if self._open and self._db != 0 {
            self.in_transaction = sq3_get_autocommit(self._db) == 0;
            self.total_changes = sq3_total_changes(self._db);
        }
    }

    def _maybe_begin(stmt: int, sql: str) {
        if not isinstance(self.isolation_level, str) {
            return;
        }
        if sq3_get_autocommit(self._db) == 0 {
            return;
        }
        if _is_dml(sql) {
            kw = self.isolation_level;
            cmd = "BEGIN";
            if kw != "" {
                cmd = "BEGIN " + kw;
            }
            rc = sq3_exec(self._db, cmd);
            if rc != 0 {
                _raise_db_error(self._db, rc);
            }
            self.in_transaction = True;
        }
    }

    def commit {
        if not self._open {
            raise ProgrammingError("Cannot operate on a closed database.");
        }
        if sq3_get_autocommit(self._db) == 0 {
            rc = sq3_exec(self._db, "COMMIT");
            if rc != 0 {
                _raise_db_error(self._db, rc);
            }
            self._sync_state();
        }
    }

    def rollback {
        if not self._open {
            raise ProgrammingError("Cannot operate on a closed database.");
        }
        if sq3_get_autocommit(self._db) == 0 {
            rc = sq3_exec(self._db, "ROLLBACK");
            if rc != 0 {
                _raise_db_error(self._db, rc);
            }
            self._sync_state();
        }
    }

    def close {
        if self._open {
            self._open = False;
            for cur in self._cursors {
                cur._mark_closed();
            }
            for sql in self._pool {
                for h in self._pool[sql] {
                    sq3_finalize(h);
                }
            }
            self._pool = {};
            self._pool_n = 0;
            sq3_close(self._db);
            self._db = 0;
            self.in_transaction = False;
        }
    }

    def __enter__ -> Connection {
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        if exc is None {
            self.commit();
        } else {
            self.rollback();
        }
        return False;
    }
}


obj:pub Cursor {
    has connection: Connection = Connection(),
        _stmt: int = 0,
        _closed: bool = False,
        _done: bool = False,
        arraysize: int = 1,
        rowcount: int = -1,
        lastrowid: (int | None) = None,
        description: (list[any] | None) = None,
        _many_total: int = 0,
        _sql: str = "";

    def _check_open {
        if self._closed {
            raise ProgrammingError("Cannot operate on a closed cursor.");
        }
        if not self.connection._open {
            raise ProgrammingError("Cannot operate on a closed database.");
        }
    }

    def _mark_closed {
        self._closed = True;
        self._finish_stmt();
    }

    def _finish_stmt {
        if self._stmt != 0 {
            conn = self.connection;
            if conn._open and self._sql != "" and conn._pool_n < conn._cache_max {
                sq3_reset(self._stmt);
                sq3_clear_bindings(self._stmt);
                lst: list[int] = [];
                try {
                    lst = conn._pool[self._sql];
                } except KeyError {
                    lst = [];
                }
                lst.append(self._stmt);
                conn._pool[self._sql] = lst;
                conn._pool_n += 1;
            } else {
                sq3_finalize(self._stmt);
            }
            self._stmt = 0;
        }
        self._sql = "";
        self._done = False;
    }

    def _bind_value(i: int, v: any) {
        if v is None {
            sq3_bind_null(self._stmt, i);
        } elif isinstance(v, bool) {
            sq3_bind_int(self._stmt, i, 1 if v else 0);
        } elif isinstance(v, int) {
            sq3_bind_int(self._stmt, i, v);
        } elif isinstance(v, float) {
            sq3_bind_double(self._stmt, i, v);
        } elif isinstance(v, str) {
            sq3_bind_text(self._stmt, i, v);
        } elif isinstance(v, bytes) {
            sq3_bind_blob(self._stmt, i, v);
        } elif isinstance(v, bytearray) {
            sq3_bind_blob(self._stmt, i, bytes(v));
        } else {
            raise ProgrammingError(
                "Error binding parameter "
                    + str(i)
                    + ": type '"
                    + _type_name(v)
                    + "' is not supported"
            );
        }
    }

    def _bind_params(parameters: (list[any] | dict[str, any] | None)) {
        n = sq3_bind_parameter_count(self._stmt);
        if parameters is None {
            if n != 0 {
                raise ProgrammingError(
                    "Incorrect number of bindings supplied. The current statement uses "
                        + str(n)
                        + ", and there are 0 supplied."
                );
            }
            return;
        }
        if isinstance(parameters, dict) {
            d: dict[str, any] = parameters;
            for i in range(1, n + 1) {
                pname = sq3_bind_parameter_name(self._stmt, i);
                if len(pname) == 0 {
                    raise ProgrammingError(
                        "Binding "
                            + str(i)
                            + " has no name, but you supplied a dictionary (which has only names)."
                    );
                }
                key = pname[1:];
                found = True;
                v: any = None;
                try {
                    v = d[key];
                } except KeyError as e {
                    found = False;
                }
                if not found {
                    raise ProgrammingError(
                        "You did not supply a value for binding parameter "
                            + pname
                            + "."
                    );
                }
                self._bind_value(i, v);
            }
            return;
        }
        m = len(parameters);
        if m != n {
            raise ProgrammingError(
                "Incorrect number of bindings supplied. The current statement uses "
                    + str(n)
                    + ", and there are "
                    + str(m)
                    + " supplied."
            );
        }
        for i in range(1, n + 1) {
            pname = sq3_bind_parameter_name(self._stmt, i);
            if len(pname) > 0 and pname[0:1] != "?" {
                raise ProgrammingError(
                    "Binding "
                        + str(i)
                        + " ('"
                        + pname
                        + "') is a named parameter, but you supplied a sequence which requires nameless (qmark) placeholders."
                );
            }
            self._bind_value(i, parameters[i - 1]);
        }
    }

    def _fetch_row -> list[any] {
        n = sq3_column_count(self._stmt);
        row: list[any] = [];
        for i in range(n) {
            t = sq3_column_type(self._stmt, i);
            v: any = None;
            if t == 1 {
                v = sq3_column_int(self._stmt, i);
            } elif t == 2 {
                v = sq3_column_float(self._stmt, i);
            } elif t == 3 {
                v = sq3_column_raw(self._stmt, i).decode();
            } elif t == 4 {
                v = sq3_column_raw(self._stmt, i);
            }
            row.append(v);
        }
        return row;
    }

    def _check_tail(stmt: int, sqlp: int) {
        conn = self.connection;
        rc2 = sq3_prepare_tail(conn._db, sq3_prep_tail());
        stmt2 = sq3_prep_stmt2();
        sq3_free(sqlp);
        if stmt2 != 0 {
            sq3_finalize(stmt2);
        }
        if rc2 != 0 {
            sq3_finalize(stmt);
            _raise_db_error(conn._db, -rc2);
        }
        if stmt2 != 0 {
            sq3_finalize(stmt);
            raise ProgrammingError("You can only execute one statement at a time.");
        }
    }

    def execute(
        sql: any, parameters: (list[any] | dict[str, any] | None) = None
    ) -> Cursor {
        self._check_open();
        if not isinstance(sql, str) {
            raise TypeError("execute() argument 1 must be str, not " + _type_name(sql));
        }
        self._finish_stmt();
        self.description = None;
        self.rowcount = -1;
        conn = self.connection;
        stmt = 0;
        pooled = False;
        try {
            pl = conn._pool[sql];
            if len(pl) > 0 {
                stmt = pl.pop();
                conn._pool[sql] = pl;
                conn._pool_n -= 1;
                pooled = True;
            }
        } except KeyError {
            pooled = False;
        }
        if pooled {
            sq3_reset(stmt);
            sq3_clear_bindings(stmt);
        } else {
            rc = sq3_prepare(conn._db, sql);
            if rc != 0 {
                _raise_db_error(conn._db, -rc);
            }
            stmt = sq3_prep_stmt();
            sqlp = sq3_prep_sqlp();
            if stmt == 0 {
                sq3_free(sqlp);
                return self;
            }
            self._check_tail(stmt, sqlp);
        }
        self._stmt = stmt;
        self._sql = sql;
        ncols = sq3_column_count(stmt);
        if ncols > 0 {
            desc: list[any] = [];
            for i in range(ncols) {
                nm = sq3_column_name(stmt, i);
                d: list[any] = [];
                d.append(nm);
                d.append(None);
                d.append(None);
                d.append(None);
                d.append(None);
                d.append(None);
                d.append(None);
                desc.append(d);
            }
            self.description = desc;
        }
        self._bind_params(parameters);
        conn._maybe_begin(stmt, sql);
        if ncols == 0 {
            rc3 = sq3_step(stmt);
            self._finish_stmt();
            if rc3 != 100 and rc3 != 101 {
                _raise_db_error(conn._db, rc3);
            }
            if _is_dml(sql) {
                self.rowcount = sq3_changes(conn._db);
            }
            self.lastrowid = sq3_last_insert_rowid(conn._db);
            conn._sync_state();
            self._done = True;
        }
        return self;
    }

    def executemany(sql: any, seq_of_parameters: list[list[any]]) -> Cursor {
        self._check_open();
        if not isinstance(sql, str) {
            raise TypeError(
                "executemany() argument 1 must be str, not " + _type_name(sql)
            );
        }
        self._finish_stmt();
        self.description = None;
        self.rowcount = -1;
        conn = self.connection;
        stmt = 0;
        pooled = False;
        try {
            pl = conn._pool[sql];
            if len(pl) > 0 {
                stmt = pl.pop();
                conn._pool[sql] = pl;
                conn._pool_n -= 1;
                pooled = True;
            }
        } except KeyError {
            pooled = False;
        }
        if not pooled {
            rc = sq3_prepare(conn._db, sql);
            if rc != 0 {
                _raise_db_error(conn._db, -rc);
            }
            stmt = sq3_prep_stmt();
            sqlp = sq3_prep_sqlp();
            if stmt == 0 {
                sq3_free(sqlp);
                return self;
            }
            self._check_tail(stmt, sqlp);
        }
        if sq3_column_count(stmt) > 0 {
            sq3_finalize(stmt);
            raise ProgrammingError("executemany() can only execute DML statements.");
        }
        if pooled {
            sq3_reset(stmt);
            sq3_clear_bindings(stmt);
        }
        self._stmt = stmt;
        self._sql = sql;
        conn._maybe_begin(stmt, sql);
        self._many_total = 0;
        for parameters in seq_of_parameters {
            self._many_one(parameters);
        }
        total = self._many_total;
        self._finish_stmt();
        self.rowcount = total;
        conn._sync_state();
        return self;
    }

    def _many_one(parameters: list[any]) {
        self._bind_params(parameters);
        stmt = self._stmt;
        rc3 = sq3_step(stmt);
        if rc3 != 100 and rc3 != 101 {
            sq3_finalize(stmt);
            self._stmt = 0;
            _raise_db_error(self.connection._db, rc3);
        }
        self._many_total += sq3_changes(self.connection._db);
        sq3_reset(stmt);
        sq3_clear_bindings(stmt);
    }

    def executescript(sql_script: str) -> Cursor {
        return self._exec_script_impl(sql_script);
    }

    def _exec_script_impl(sql_script: str) -> Cursor {
        self._check_open();
        self._finish_stmt();
        self.description = None;
        self.rowcount = -1;
        conn = self.connection;
        if conn.in_transaction {
            conn.commit();
        }
        rc = sq3_exec(conn._db, sql_script);
        if rc != 0 {
            msg = sq3_exec_err();
            if len(msg) > 0 {
                _raise_msg(rc, msg);
            }
            _raise_db_error(conn._db, rc);
        }
        conn._sync_state();
        return self;
    }

    def fetchone -> (list[any] | None) {
        self._check_open();
        if self._stmt == 0 or self._done {
            return None;
        }
        rc = sq3_step(self._stmt);
        if rc == 100 {
            return self._fetch_row();
        }
        conn = self.connection;
        if rc != 101 {
            self._finish_stmt();
            _raise_db_error(conn._db, rc);
        }
        self._finish_stmt();
        self._done = True;
        conn._sync_state();
        return None;
    }

    def fetchmany(size: any = None) -> list[any] {
        self._check_open();
        n = self.arraysize;
        if isinstance(size, int) {
            if size < 0 {
                raise ValueError("Cannot convert negative int");
            }
            n = size;
        } elif size is not None {
            raise TypeError("an integer is required");
        }
        out: list[any] = [];
        for _ in range(n) {
            r = self.fetchone();
            if r is None {
                break;
            }
            out.append(r);
        }
        return out;
    }

    def fetchall -> list[any] {
        self._check_open();
        out: list[any] = [];
        while True {
            r = self.fetchone();
            if r is None {
                break;
            }
            out.append(r);
        }
        return out;
    }

    def __iter__ -> Cursor {
        return self;
    }

    def __next__ -> list[any] {
        r = self.fetchone();
        if r is None {
            raise StopIteration();
        }
        return r;
    }

    def close {
        if not self._closed {
            self._closed = True;
            self._finish_stmt();
        }
    }
}


def:pub connect(
    database: any,
    timeout: float = 5.0,
    detect_types: int = 0,
    isolation_level: (str | None) = "",
    check_same_thread: bool = True,
    factory: any = None,
    cached_statements: int = 128,
    uri: bool = False,
    autocommit: any = None
) -> Connection {
    if not isinstance(database, str) {
        raise TypeError(
            "expected str, bytes or os.PathLike object, not " + _type_name(database)
        );
    }
    h = sq3_open_v2(database, uri);
    if h <= 0 {
        msg = sq3_open_err();
        if len(msg) == 0 {
            msg = "unable to open database file";
        }
        raise OperationalError(msg);
    }
    conn = Connection(_db=h, _open=True);
    conn.isolation_level = isolation_level;
    conn._cache_max = cached_statements;
    if isinstance(autocommit, bool) {
        if autocommit {
            conn.isolation_level = None;
            conn.autocommit = 1;
        } else {
            conn.autocommit = 0;
        }
    }
    sq3_busy_timeout(h, int(timeout * 1000.0));
    return conn;
}


def:pub complete_statement(sql: any) -> bool {
    if not isinstance(sql, str) {
        raise TypeError("argument must be str, not " + _type_name(sql));
    }
    return sq3_complete(sql) != 0;
}


def:pub Binary(b: any) -> bytes {
    if isinstance(b, bytes) {
        return b;
    }
    if isinstance(b, bytearray) {
        return bytes(b);
    }
    raise TypeError("expected bytes-like object, not " + _type_name(b));
}
