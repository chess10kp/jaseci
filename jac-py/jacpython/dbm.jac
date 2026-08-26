# Product-path facade for _dbm (Modules/_dbmmodule.c): the ndbm-style
# DBM mapping with open/close, bytes keys/values, and file persistence.
#
# Semantics mirror CPython 3.14 ``Modules/_dbmmodule.c``:
#
#   - open(filename, flags="r", mode=0o666) with the exact flag vocabulary
#     "r"/"w"/"rw"/"c"/"n" mapped to O_RDONLY / O_RDWR / O_RDWR|O_CREAT /
#     O_RDWR|O_CREAT|O_TRUNC; anything else raises error("arg 2 to open
#     should be 'r', 'w', 'c', or 'n'").
#   - filename goes through PyUnicode_FSConverter: str, bytes, and
#     path-like (__fspath__) objects are accepted.
#   - The mapping protocol: subscript/store/delete, len, contains,
#     keys(), get(key[, default]), setdefault(key[, default]), clear(),
#     close() plus the context-manager pair.
#   - Keys and values are str or bytes-like ("s#" converter); stored and
#     returned as bytes (str inputs are UTF-8 encoded like dbm_fetch's
#     datum). Missing-key fetch/delete raise KeyError when writable;
#     store on a read-only handle raises error("cannot add item to
#     database"); delete on one raises error("cannot delete item from
#     database"); operations on a closed handle raise "DBM object has
#     already been closed".
#
# Error mapping: _dbm.error is PyErr_NewException("_dbm.error", OSError).
# Facade exceptions cross by NAME (exceptions_core registry), so every
# failure carries type name ``dbm.error`` with the hierarchy registered
# against OSError at import: ``except dbm.error`` matches exactly,
# ``except OSError`` matches through the registered parent link, and
# assertIsSubclass(module.error, OSError) holds via the same table.
#
# Storage: ndbm's on-disk hash pages are not reproducible in Jac, so the
# facade persists each table as its own record file -- one ASCII line per
# record, "<key-hex>:<value-hex>", written through fd-based os I/O
# (os.open/os.read/os.write). Records are hex-encoded so arbitrary bytes
# round-trip; the empty value stays distinct from an absent one (the
# property test_empty_value relies on). Reopening always re-reads the
# file, which remains the authoritative copy across processes.
#
# Guest surface: like mmap.jac this module speaks the native PyObj
# protocol (PyDbmObj slots + bound-method dispatch) so guest imports
# resolve through build_dbm_module()/build_dbm_package() shims instead of
# host proxies.

import from objects {
    PyObj,
    PyInt,
    PyBool,
    PyStr,
    PyBytes,
    PyList,
    PyDict,
    PyModule,
    PyExceptionType,
    py_none,
    py_error,
    is_error,
}

import from exceptions_core { register_module_exception }

import os as _host_os;

# ---------------- storage helpers (plain Jac values) -------------------------

glob _HEXDIGITS = "0123456789abcdef";

# Canonical module name reported by whichdb() and module __name__ pins.
glob DBM_NDBM_NAME = "dbm.ndbm";


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
    fd = _host_os.open(path, _host_os.O_RDONLY);
    parts: list[bytes] = [];
    while True {
        chunk = _host_os.read(fd, 65536);
        if len(chunk) == 0 {
            break;
        }
        parts.append(chunk);
    }
    _host_os.close(fd);
    return b"".join(parts);
}


def _write_file(path: str, flags: int, data: bytes) {
    fd = _host_os.open(path, flags, 0o666);
    written = 0;
    while written < len(data) {
        written += _host_os.write(fd, data[written:]);
    }
    _host_os.close(fd);
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


# ---------------- PyObj argument helpers -------------------------------------

# PyUnicode_FSConverter equivalent: str / bytes / path-like -> text name.
# Path-likes answer through their generic __fspath__ slot (no ceval import:
# tp_getattro + tp_call is the whole protocol), keeping dbm.jac free of
# ceval dependencies.
def _fs_path(filename: PyObj) -> PyObj {
    if isinstance(filename, PyStr) {
        return filename;
    }
    if isinstance(filename, PyBytes) {
        return PyStr(t="str", val=_host_os.fsdecode(bytes((filename as PyBytes).val)));
    }
    # Path-likes answer through their generic __fspath__ slot (no ceval
    # import needed: tp_getattro + tp_call is the whole protocol).
    bound = filename.tp_getattro("__fspath__");
    if not is_error(bound) {
        res = bound.tp_call([], {});
        if is_error(res) {
            return res;
        }
        if isinstance(res, PyStr) {
            return res;
        }
        if isinstance(res, PyBytes) {
            return PyStr(
                t="str", val=_host_os.fsdecode(bytes((res as PyBytes).val))
            );
        }
        return py_error("TypeError", "expected __fspath__() to return str or bytes");
    }
    return py_error(
        "TypeError", "argument must be str, bytes, or an os.PathLike object"
    );
}


# "s#" converter: str is UTF-8 encoded, bytes-like passes through; an
# error marker signals the caller-side TypeError.
def _datum_bytes(value: PyObj) -> PyObj {
    if isinstance(value, PyStr) {
        return PyBytes(t="bytes", val=list((value as PyStr).val.encode("utf-8")));
    }
    if isinstance(value, PyBytes) {
        return value;
    }
    return py_error("TypeError", "");
}


def _key_bytes(key: PyObj) -> PyObj {
    kb = _datum_bytes(key);
    if is_error(kb) {
        return py_error(
            "TypeError",
            "dbm key must be bytes or string, not " + key.t,
        );
    }
    return kb;
}


def _value_bytes(value: PyObj) -> PyObj {
    vb = _datum_bytes(value);
    if is_error(vb) {
        return py_error("TypeError", "dbm mappings have bytes or string elements only");
    }
    return vb;
}


def _bytes_val(o: PyObj) -> bytes {
    return bytes((o as PyBytes).val);
}


def _wrap_bytes(data: bytes) -> PyObj {
    return PyBytes(t="bytes", val=list(data));
}


# Python bytes-literal style repr for KeyError payloads (b'...').
def _key_repr(key: PyObj) -> str {
    kb = _datum_bytes(key);
    if is_error(kb) {
        return "<?>";
    }
    text = "b'";
    for octet in _bytes_val(kb) {
        if octet == 0x27 {
            text = text + "\\'";
        } elif octet >= 32 and octet < 127 {
            text = text + chr(octet);
        } else {
            text = text + "\\x" + _hex_encode(bytes([octet]));
        }
    }
    return text + "'";
}


# Shared exception identity: every facade failure raises under this name so
# guest handlers match one canonical target regardless of the importing alias.
def _make_dbm_error_type -> PyExceptionType {
    return PyExceptionType(t="exception_type", name="dbm.error");
}

glob _DBM_ERROR_TYPE: PyObj = _make_dbm_error_type();


def dbm_error(msg: str) -> PyObj {
    return py_error("dbm.error", msg);
}


def dbm_require_open(d: PyDbmObj) -> PyObj {
    if d.closed {
        return dbm_error("DBM object has already been closed");
    }
    return py_none();
}


def dbm_contains(d: PyDbmObj, key: PyObj) -> PyObj {
    err = dbm_require_open(d);
    if is_error(err) {
        return err;
    }
    kb = _key_bytes(key);
    if is_error(kb) {
        return kb;
    }
    return PyBool(t="bool", val=_bytes_val(kb) in d.table);
}


# ---------------- instance surface -------------------------------------------

def _dbm_keys(d: PyDbmObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    items: list[PyObj] = [];
    for k in d.table {
        items.append(_wrap_bytes(k));
    }
    return PyList(t="list", items=items);
}


def _dbm_get(d: PyDbmObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(args) < 1 or len(args) > 2 {
        return py_error("TypeError", "get expected 1 or 2 arguments");
    }
    kb = _key_bytes(args[0]);
    if is_error(kb) {
        return kb;
    }
    data = _bytes_val(kb);
    if data in d.table {
        return _wrap_bytes(d.table[data]);
    }
    if len(args) == 2 {
        return args[1];
    }
    return py_none();
}


def _dbm_setdefault(d: PyDbmObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(args) < 1 or len(args) > 2 {
        return py_error("TypeError", "setdefault expected 1 or 2 arguments");
    }
    kb = _key_bytes(args[0]);
    if is_error(kb) {
        return kb;
    }
    data = _bytes_val(kb);
    if data in d.table {
        return _wrap_bytes(d.table[data]);
    }
    default_value = py_none();
    if len(args) == 2 {
        default_value = args[1];
    } else {
        default_value = _wrap_bytes(b"");
    }
    vb = _value_bytes(default_value);
    if is_error(vb) {
        return vb;
    }
    if not d.writable {
        return dbm_error("cannot add item to database");
    }
    d.table[data] = _bytes_val(vb);
    flush_err = _dbm_flush(d, "cannot add item to database");
    if is_error(flush_err) {
        return flush_err;
    }
    # C returns the caller's object after a successful insert.
    return default_value;
}


def _dbm_clear(d: PyDbmObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    # A read-only handle only fails once there is something to delete (the
    # firstkey walk breaks out immediately on an empty table).
    if not d.writable and len(d.table) > 0 {
        return dbm_error("cannot delete item from database");
    }
    d.table.clear();
    if d.writable {
        return _dbm_flush(d, "cannot delete item from database");
    }
    return py_none();
}


def _dbm_close(d: PyDbmObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    d.closed = True;
    return py_none();
}


def _dbm_enter(d: PyDbmObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    return d;
}


def _dbm_exit(d: PyDbmObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    d.closed = True;
    return py_none();
}


def _dbm_flush(d: PyDbmObj, fail_msg: str) -> PyObj {
    try {
        _write_file(d.path, d.flags, _table_dump(d.table));
    } except Exception {
        return dbm_error(fail_msg);
    }
    return py_none();
}


obj PyDbmObj(PyObj) {
    has path: str = "",
        flags: int = 0,
        writable: bool = False,
        table: dict[bytes, bytes] = {},
        closed: bool = False;

    def tp_getattro(name: str) -> PyObj {
        if name == "close" or name == "keys" or name == "get"
            or name == "setdefault" or name == "clear"
            or name == "__enter__" or name == "__exit__" or name == "__len__" {
            return PyDbmMethod(t="dbm_method", target=self, name=name);
        }
        return py_error(
            "AttributeError", "'dbm.ndbm' object has no attribute '" + name + "'"
        );
    }

    def mp_subscript(index: PyObj) -> PyObj {
        err = dbm_require_open(self);
        if is_error(err) {
            return err;
        }
        kb = _key_bytes(index);
        if is_error(kb) {
            return kb;
        }
        data = _bytes_val(kb);
        if data not in self.table {
            return py_error("KeyError", _key_repr(index));
        }
        return _wrap_bytes(self.table[data]);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        err = dbm_require_open(self);
        if is_error(err) {
            return err;
        }
        if not self.writable {
            return dbm_error("cannot add item to database");
        }
        kb = _key_bytes(index);
        if is_error(kb) {
            return kb;
        }
        vb = _value_bytes(value);
        if is_error(vb) {
            return vb;
        }
        self.table[_bytes_val(kb)] = _bytes_val(vb);
        return _dbm_flush(self, "cannot add item to database");
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        err = dbm_require_open(self);
        if is_error(err) {
            return err;
        }
        # dbm_delete fails on a read-only descriptor regardless of whether
        # the key exists; CPython then distinguishes by the open flags.
        if not self.writable {
            return dbm_error("cannot delete item from database");
        }
        kb = _key_bytes(index);
        if is_error(kb) {
            return kb;
        }
        data = _bytes_val(kb);
        if data not in self.table {
            return py_error("KeyError", _key_repr(index));
        }
        del self.table[data];
        return _dbm_flush(self, "cannot delete item from database");
    }
}

obj PyDbmMethod(PyObj) {
    has target: PyDbmObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        t = self.target;
        if self.name == "keys" {
            return _dbm_keys(t, args, kwargs);
        }
        if self.name == "get" {
            return _dbm_get(t, args, kwargs);
        }
        if self.name == "setdefault" {
            return _dbm_setdefault(t, args, kwargs);
        }
        if self.name == "clear" {
            return _dbm_clear(t, args, kwargs);
        }
        if self.name == "close" {
            return _dbm_close(t, args, kwargs);
        }
        if self.name == "__enter__" {
            return _dbm_enter(t, args, kwargs);
        }
        if self.name == "__exit__" {
            return _dbm_exit(t, args, kwargs);
        }
        if self.name == "__len__" {
            err = dbm_require_open(t);
            if is_error(err) {
                return err;
            }
            return PyInt(t="int", val=len(t.table));
        }
        return py_error("AttributeError", self.name);
    }
}


# ---------------- open() / whichdb() -----------------------------------------

# Parse-and-validate mirrors dbmopen_impl: filename positional, flags/mode
# optional positionally or by keyword ("rw" is the documented backward-
# compatibility alias of "c"). The file materializes immediately (ndbm
# creates it inside dbm_open); a missing file without a create flag maps
# ENOENT onto the facade error channel byte-exact.
obj PyDbmOpenCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        names: list[str] = ["filename", "flags", "mode"];
        values: list[PyObj] = [];
        seen: list[bool] = [];
        k: int = 0;
        while k < 3 {
            if k < len(args) {
                values.append(args[k]);
                seen.append(True);
            } elif names[k] in kwargs {
                values.append(kwargs[names[k]]);
                seen.append(True);
            } else {
                values.append(py_none());
                seen.append(False);
            }
            k = k + 1;
        }
        for key in kwargs {
            known: bool = False;
            n: int = 0;
            while n < 3 {
                if key == names[n] {
                    known = True;
                }
                n = n + 1;
            }
            if not known {
                return py_error(
                    "TypeError",
                    "'" + key + "' is an invalid keyword argument for open()",
                );
            }
        }
        if len(args) > 3 {
            return py_error("TypeError", "open expected at most 3 arguments");
        }
        if not seen[0] {
            return py_error(
                "TypeError", "function missing required argument 'filename' (pos 1)"
            );
        }
        path_res = _fs_path(values[0]);
        if is_error(path_res) {
            return path_res;
        }
        path = (path_res as PyStr).val;

        flagname = "r";
        if seen[1] {
            if not isinstance(values[1], PyStr) {
                return py_error("TypeError", "flags must be a string");
            }
            flagname = (values[1] as PyStr).val;
        }
        iflags: int = 0;
        create: bool = False;
        truncate: bool = False;
        if flagname == "r" {
            iflags = _host_os.O_RDONLY;
        } elif flagname == "w" {
            iflags = _host_os.O_RDWR;
        } elif flagname == "rw" {
            iflags = _host_os.O_RDWR | _host_os.O_CREAT;
            create = True;
        } elif flagname == "c" {
            iflags = _host_os.O_RDWR | _host_os.O_CREAT;
            create = True;
        } elif flagname == "n" {
            iflags = _host_os.O_RDWR | _host_os.O_CREAT | _host_os.O_TRUNC;
            create = True;
            truncate = True;
        } else {
            return dbm_error("arg 2 to open should be 'r', 'w', 'c', or 'n'");
        }

        exists = _host_os.path.isfile(path);
        if not exists and not create {
            # PyErr_SetFromErrnoWithFilename shape for ENOENT.
            return dbm_error(
                "[Errno 2] No such file or directory: '" + path + "'"
            );
        }

        table: dict[bytes, bytes] = {};
        if exists and not truncate {
            table = _table_parse(_read_file(path));
        }
        if truncate or not exists {
            try {
                _write_file(path, iflags, b"");
            } except Exception {
                return dbm_error("cannot add item to database");
            }
        }

        return PyDbmObj(
            t="dbm_obj",
            path=path,
            flags=iflags,
            writable=(iflags & _host_os.O_RDWR) != 0,
            table=table,
        );
    }
}


# whichdb(path): "" for a nonexistent file, the owning backend's module
# name for a parseable record file, "" for garbage (ndbm's hash pages
# cannot be reproduced, so everything readable here belongs to us).
obj PyDbmWhichDbFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "whichdb() takes no keyword arguments");
        }
        if len(args) != 1 {
            return py_error("TypeError", "whichdb expected exactly 1 argument");
        }
        path_res = _fs_path(args[0]);
        if is_error(path_res) {
            return path_res;
        }
        path = (path_res as PyStr).val;
        if not _host_os.path.isfile(path) {
            return PyStr(t="str", val="");
        }
        try {
            _table_parse(_read_file(path));
        } except Exception {
            return PyStr(t="str", val="");
        }
        return PyStr(t="str", val=DBM_NDBM_NAME);
    }
}


# ---------------- module builders --------------------------------------------

# The backend module (CPython registers the same C module under
# "dbm.ndbm"; "_dbm" survives as its legacy import name).
def build_dbm_module(modname: str) -> PyObj {
    return PyModule(
        t="module",
        name=modname,
        attrs={
            "open": PyDbmOpenCtor(t="dbm_open_ctor"),
            "error": _DBM_ERROR_TYPE,
            "whichdb": PyDbmWhichDbFn(t="dbm_whichdb_fn"),
            "library": PyStr(t="str", val="GNU gdbm"),
        },
    );
}


# The dbm package facade: open/whichdb/error route to the default backend
# and the discovery vocabulary (_names/_modules/_defaultmod) exposes
# exactly the backends this runtime serves.
def build_dbm_package(ndbm_mod: PyObj) -> PyObj {
    modules = PyDict(t="dict", items={});
    modules.dict_set(PyStr(t="str", val=DBM_NDBM_NAME), ndbm_mod);
    return PyModule(
        t="module",
        name="dbm",
        attrs={
            "open": PyDbmOpenCtor(t="dbm_open_ctor"),
            "error": _DBM_ERROR_TYPE,
            "whichdb": PyDbmWhichDbFn(t="dbm_whichdb_fn"),
            "_names": PyList(
                t="list", items=[PyStr(t="str", val=DBM_NDBM_NAME)]
            ),
            "_modules": modules,
            "_defaultmod": ndbm_mod,
            "ndbm": ndbm_mod,
        },
    );
}


with entry {
    # Module-exception declaration (bridge-table registry, exceptions_core):
    # declared AT IMPORT so boundary matching/minting knows this exception's
    # hierarchy without bare getattr(builtins, ...) lookups. The short-form
    # alias ("error") is registered automatically.
    register_module_exception("dbm.error", "OSError");
    register_module_exception("_dbm.error", "OSError");
    register_module_exception("dbm.ndbm.error", "OSError");
}
