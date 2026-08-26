# Product-path facade for _dbm (Modules/_dbmmodule.c): the ndbm-style
# DBM mapping with open/close, bytes keys/values, and file persistence.
#
# Staged ``jac-py/Modules/`` c2jac lifts remain the corpus oracles; this
# module carries the runtime truth. Semantics mirror CPython 3.14
# ``Modules/_dbmmodule.c``:
#
#   - open(filename, flags="r", mode=0o666) with the exact flag vocabulary
#     "r"/"w"/"rw"/"c"/"n" mapped to O_RDONLY / O_RDWR / O_RDWR|O_CREAT /
#     O_RDWR|O_CREAT|O_TRUNC; anything else raises error("arg 2 to open
#     should be 'r', 'w', 'c', or 'n'").
#   - filename goes through PyUnicode_FSConverter: str, bytes, and
#     path-like (os.fspath) all accepted; fsdecode normalizes bytes.
#   - The mapping protocol: subscript/store/delete, len, bool,
#     contains, keys(), get(key[, default]), setdefault(key[, default]),
#     clear(), close() plus the context-manager pair.
#   - Keys and values are str or bytes-like ("s#" converter); stored and
#     returned as bytes (str inputs are UTF-8 encoded like dbm_fetch's
#     datum). Missing-key delete raises KeyError when writable and
#     error("cannot delete item from database") otherwise; store on a
#     read-only handle raises error("cannot add item to database");
#     operations on a closed handle raise "DBM object has already been
#     closed".
#
# Error mapping: _dbm.error is PyErr_NewException("_dbm.error", OSError)
# and new exception types are unsupported from facades (binascii wave-16
# convention), so ``error`` aliases OSError itself -- assertIsSubclass(
# module.error, OSError) holds exactly and every raise keeps a builtin
# type with byte-exact messages.
#
# Storage: ndbm's on-disk hash pages are not reproducible in Jac, so the
# facade persists each table as its own record file -- one ASCII line per
# record, "<key-hex>:<value-hex>", written through fd-based os I/O
# (os.open/os.read/os.write) because a module-level ``open`` function
# would shadow the builtin inside this module. Records are hex-encoded so
# arbitrary bytes round-trip through the text layer; the empty value is
# distinct from an absent one (a plain dict property _dbmmodule relies on
# for test_empty_value). Tables are cached per resolved filename so a
# close/reopen cycle within one process sees prior writes; reopening
# always re-reads the file, which stays the authoritative copy across
# processes.

import os;

glob library = "GNU gdbm";

glob error = OSError;

# Resolved-filename -> live table. Reopening replaces the entry; handles
# opened before that keep their (now stale) dict reference, matching the
# snapshot semantics of separate ndbm descriptors closely enough for the
# supported access patterns.
glob _tables: dict[str, dict[bytes, bytes]] = {};

glob _HEXDIGITS = "0123456789abcdef";


def _hex_encode(data: bytes) -> str {
    out = "";
    for octet in data {
        out = out + _HEXDIGITS[(octet >> 4) & 15] + _HEXDIGITS[octet & 15];
    }
    return out;
}


def _hex_nibble(ch: str) -> int {
    if ch >= "0" and ch <= "9" {
        return ord(ch) - ord("0");
    }
    return (ord(ch) - ord("a")) + 10;
}


def _hex_decode(text: str) -> bytes {
    vals: list[int] = [];
    i = 0;
    while i < len(text) {
        vals.append((_hex_nibble(text[i]) * 16) + _hex_nibble(text[i + 1]));
        i += 2;
    }
    return bytes(vals);
}


def _read_file(path: str) -> bytes {
    fd = os.open(path, os.O_RDONLY);
    parts: list[bytes] = [];
    while True {
        chunk = os.read(fd, 65536);
        if len(chunk) == 0 {
            break;
        }
        parts.append(chunk);
    }
    os.close(fd);
    return b"".join(parts);
}


def _write_file(path: str, wflags: int, data: bytes) {
    fd = os.open(path, wflags, 0o666);
    written = 0;
    while written < len(data) {
        written += os.write(fd, data[written:]);
    }
    os.close(fd);
}


def _table_dump(table: dict[bytes, bytes]) -> bytes {
    parts: list[bytes] = [];
    for k in table {
        parts.append((_hex_encode(k) + ":" + _hex_encode(table[k]) + "\n").encode("ascii"));
    }
    return b"".join(parts);
}


def _table_parse(raw: bytes) -> dict[bytes, bytes] {
    table: dict[bytes, bytes] = {};
    for line in raw.decode("ascii").split("\n") {
        if len(line) == 0 {
            continue;
        }
        sep = line.index(":");
        table[_hex_decode(line[:sep])] = _hex_decode(line[sep + 1:]);
    }
    return table;
}


# PyUnicode_FSConverter equivalent: str / bytes / path-like -> text name.
def _fs_path(filename: any) -> str {
    p = os.fspath(filename);
    if isinstance(p, bytes) {
        return os.fsdecode(p);
    }
    return p;
}


# "s#" converter: str is UTF-8 encoded, bytes-like passes through; None
# signals TypeError at the caller (message unified over the sq_contains
# wording, which the pinned tests assert).
def _datum_bytes(value: any) -> bytes | None {
    if isinstance(value, str) {
        return value.encode("utf-8");
    }
    if isinstance(value, bytes) {
        return value;
    }
    if isinstance(value, bytearray) {
        return bytes(value);
    }
    return None;
}


def _key_bytes(key: any) -> bytes {
    kb = _datum_bytes(key);
    if kb is None {
        raise TypeError("dbm key must be bytes or string, not " + type(key).__name__);
    }
    return kb;
}


def _value_bytes(value: any) -> bytes {
    vb = _datum_bytes(value);
    if vb is None {
        raise TypeError("dbm mappings have bytes or string elements only");
    }
    return vb;
}


obj Dbm {
    has path: str = "",
        rflags: int = 0,
        wflags: int = 0,
        writable: bool = False,
        table: dict[bytes, bytes] = {},
        closed: bool = False;


    def _require_open {
        if self.closed {
            raise OSError("DBM object has already been closed");
        }
    }


    def _flush(wflags: int, fail_msg: str) {
        try {
            _write_file(self.path, wflags, _table_dump(self.table));
        } except Exception {
            raise OSError(fail_msg);
        }
    }


    def __len__ -> int {
        self._require_open();
        return len(self.table);
    }


    def __bool__ -> bool {
        self._require_open();
        return len(self.table) > 0;
    }


    def __contains__(key: any) -> bool {
        self._require_open();
        kb = _key_bytes(key);
        return kb in self.table;
    }


    def __getitem__(key: any) -> any {
        self._require_open();
        kb = _key_bytes(key);
        if kb not in self.table {
            raise KeyError(key);
        }
        return self.table[kb];
    }


    def __setitem__(key: any, value: any) {
        self._require_open();
        kb = _key_bytes(key);
        vb = _value_bytes(value);
        self.table[kb] = vb;
        self._flush(self.wflags, "cannot add item to database");
    }


    def __delitem__(key: any) {
        self._require_open();
        kb = _key_bytes(key);
        # dbm_delete fails on a read-only descriptor regardless of whether
        # the key exists; CPython then distinguishes by the open flags.
        if not self.writable {
            raise OSError("cannot delete item from database");
        }
        if kb not in self.table {
            raise KeyError(key);
        }
        del self.table[kb];
        self._flush(self.wflags, "cannot delete item from database");
    }


    def keys -> list {
        self._require_open();
        return list(self.table.keys());
    }


    def get(key: any, default_value: any = None) -> any {
        self._require_open();
        kb = _key_bytes(key);
        if kb in self.table {
            return self.table[kb];
        }
        return default_value;
    }


    def setdefault(key: any, default_value: any = b"") -> any {
        self._require_open();
        kb = _key_bytes(key);
        if kb in self.table {
            return self.table[kb];
        }
        vb = _value_bytes(default_value);
        self.table[kb] = vb;
        self._flush(self.wflags, "cannot add item to database");
        # C returns the caller's object after a successful insert.
        return default_value;
    }


    def clear {
        self._require_open();
        # A read-only handle only fails once there is something to delete
        # (the firstkey walk breaks out immediately on an empty table).
        if not self.writable and len(self.table) > 0 {
            raise OSError("cannot delete item from database");
        }
        self.table.clear();
        if self.writable {
            self._flush(self.wflags, "cannot delete item from database");
        }
    }


    def close {
        self.closed = True;
    }


    def __enter__ -> Dbm {
        return self;
    }


    def __exit__(exc_type: any, exc_val: any, exc_tb: any) {
        self.close();
    }
}


def _load_table(path: str, exists: bool) -> dict[bytes, bytes] {
    if exists {
        return _table_parse(_read_file(path));
    }
    return {};
}


def open(filename: any, flags: str = "r", mode: int = 0o666) -> Dbm {
    # Flag mapping mirrors dbmopen_impl exactly ("rw" is the documented
    # backward-compatibility alias of "c").
    iflags: int;
    create: bool = False;
    truncate: bool = False;
    if flags == "r" {
        iflags = os.O_RDONLY;
    } elif flags == "w" {
        iflags = os.O_RDWR;
    } elif flags == "rw" {
        iflags = os.O_RDWR | os.O_CREAT;
        create = True;
    } elif flags == "c" {
        iflags = os.O_RDWR | os.O_CREAT;
        create = True;
    } elif flags == "n" {
        iflags = os.O_RDWR | os.O_CREAT | os.O_TRUNC;
        create = True;
        truncate = True;
    } else {
        raise OSError("arg 2 to open should be 'r', 'w', 'c', or 'n'");
    }

    path = _fs_path(filename);
    exists = os.path.isfile(path);
    if not exists and not create {
        # PyErr_SetFromErrnoWithFilename shape for ENOENT.
        raise OSError("[Errno 2] No such file or directory: '" + path + "'");
    }

    table = _load_table(path, exists and not truncate);
    _tables[path] = table;
    if truncate or not exists {
        # Materialize the file now (ndbm creates it inside dbm_open).
        try {
            _write_file(path, iflags, b"");
        } except Exception {
            raise OSError("cannot add item to database");
        }
    }

    handle = Dbm(
        path=path,
        rflags=iflags,
        wflags=os.O_RDWR | os.O_CREAT,
        writable=(iflags & os.O_RDWR) != 0,
        table=table,
    );
    return handle;
}
