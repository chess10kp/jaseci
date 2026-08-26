# Product-path facade for pwd (lift of reference/cpython/Modules/pwdmodule.c).
#
# Semantics mirror CPython 3.14 ``pwdmodule.c`` (UNIX branch):
#   - getpwuid(uid): _Py_Uid_Converter ladder -- non-index argument raises
#     TypeError("uid should be integer, not <type>"), anything outside the
#     uid_t range ([-1, 2**32-2] on Linux; ULONG_MAX == (uid_t)-1 overflows
#     like in the C converter) becomes KeyError("getpwuid(): uid not found")
#     because pwd_getpwuid converts the OverflowError, and a database miss
#     keeps the ": <uid>" suffix from PyErr_Format.
#   - getpwnam(name): str-only ("name must be a str" clinic converter), FS
#     encoding first so lone surrogates outside surrogateescape range raise
#     UnicodeEncodeError before anything else, then the embedded-null-byte
#     ValueError from PyBytes_AsStringAndSize, then KeyError with the %R
#     repr of the name on a miss.
#   - getpwall(): no-argument list of every entry, in database order.
#   - Entries are struct_passwd struct sequences: tuple protocol (len,
#     indexing, iteration, value equality/hashing) plus the seven pw_*
#     attributes and the n_fields/n_sequence_fields/n_unnamed_fields type
#     surface. pw_gecos/pw_passwd may be None when the C SET_STRING macro
#     sees a NULL field.
#
# Data comes through the host bridge (importlib-resolved ``pwd``) behind one
# narrow helper: the passwd database lives in libc/NSS, which Jac cannot
# reach natively yet. All argument validation and error synthesis happens
# here first, so every error a converted Lib/test pin observes keeps its
# builtin type name and byte-exact message; only successful rows cross back.
#
# struct_passwd / struct_pwent type objects are absent from the module dict:
# facades cannot mint new types (binascii wave-16 convention). No converted
# pin touches them; revisit alongside the exception-type work that constraint
# is tracked under.


import from objects {
    PyObj,
    PyInt,
    PyStr,
    PyTuple,
    PyList,
    PyModule,
    py_none,
    py_error,
    is_error,
}

import importlib;


# ---------------- host bridge -------------------------------------------------

def _pwd_host -> any {
    # Resolved lazily per call: sys.modules makes this a dict hit, and the
    # facade never imports "pwd" statically because this module IS the guest
    # name -- a static import could self-resolve once compiled products land
    # on sys.path.
    return importlib.import_module("pwd");
}


# ---------------- entry construction ------------------------------------------

def _entry_item(raw: any) -> PyObj {
    # mkpwent emits decoded strings, longs, or None (NULL string fields).
    if isinstance(raw, str) {
        return PyStr(t="str", val=raw);
    }
    if isinstance(raw, bool) {
        return PyInt(t="int", val=1 if raw else 0);
    }
    if isinstance(raw, int) {
        return PyInt(t="int", val=raw);
    }
    return py_none();
}

def _entry_from_host(row: any) -> PwdEntry {
    items: list[PyObj] = [];
    i: int = 0;
    while i < 7 {
        items.append(_entry_item(row[i]));
        i = i + 1;
    }
    return PwdEntry(t="pwd.struct_passwd", items=items);
}


# pwd.struct_passwd: Results from getpw*() routines. Tuple protocol comes
# from PyTuple (value equality, hashing, len/index/iter/slice) exactly like
# the C PyStructSequence; only attribute access is layered on top.
obj PwdEntry(PyTuple) {
    def tp_getattro(name: str) -> PyObj {
        if name == "pw_name" {
            return self.items[0];
        }
        if name == "pw_passwd" {
            return self.items[1];
        }
        if name == "pw_uid" {
            return self.items[2];
        }
        if name == "pw_gid" {
            return self.items[3];
        }
        if name == "pw_gecos" {
            return self.items[4];
        }
        if name == "pw_dir" {
            return self.items[5];
        }
        if name == "pw_shell" {
            return self.items[6];
        }
        if name == "n_sequence_fields" or name == "n_fields" {
            return PyInt(t="int", val=7);
        }
        if name == "n_unnamed_fields" {
            return PyInt(t="int", val=0);
        }
        return py_error(
            "AttributeError",
            "'pwd.struct_passwd' object has no attribute '" + name + "'",
        );
    }
}


# ---------------- getpwuid ----------------------------------------------------

# _Py_Uid_Converter acceptance range on Linux (uid_t = unsigned 32-bit):
# the whole unsigned domain minus ULONG_MAX, whose (uid_t)-1 collision the
# C converter reports as OverflowError; a literal -1 converts cleanly.
def _uid_in_range(v: int) -> bool {
    if v == -1 {
        return True;
    }
    return v >= 0 and v <= 4294967294;
}

obj PwdGetPwuidFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error(
                "TypeError", "getpwuid() takes no keyword arguments"
            );
        }
        if len(args) != 1 {
            return py_error(
                "TypeError",
                "getpwuid() takes exactly one argument (" + str(len(args)) + " given)",
            );
        }
        idx = args[0].to_index();
        if is_error(idx) or not isinstance(idx, PyInt) {
            return py_error(
                "TypeError",
                "uid should be integer, not " + args[0].tp_type_name(),
            );
        }
        v: int = (idx as PyInt).val;
        if not _uid_in_range(v) {
            # pwd_getpwuid re-formats the converter's OverflowError as a bare
            # KeyError -- no ": <uid>" suffix on this path.
            return py_error("KeyError", "getpwuid(): uid not found");
        }
        try {
            row = _pwd_host().getpwuid(v);
        } except KeyError {
            return py_error(
                "KeyError", "getpwuid(): uid not found: " + str(v)
            );
        } except Exception {
            return py_error("KeyError", "getpwuid(): uid not found: " + str(v));
        }
        return _entry_from_host(row);
    }
}


# ---------------- getpwnam ----------------------------------------------------

def _fs_encode_error(s: str) -> PyObj {
    # PyUnicode_EncodeFSDefault on Linux: UTF-8 + surrogateescape. Surrogates
    # in the U+DC80..U+DCFF window round-trip to raw bytes; every other
    # surrogate raises UnicodeEncodeError before any database lookup.
    i: int = 0;
    while i < len(s) {
        o: int = ord(s[i]);
        if o >= 55296 and o <= 57343 and (o < 56448 or o > 57343) {
            code = "\\u";
            nibbles = "0123456789abcdef";
            d: int = 0;
            while d < 4 {
                shift = 12 - d * 4;
                digit = (o >> shift) & 0xF;
                code = code + nibbles[digit];
                d = d + 1;
            }
            return py_error(
                "UnicodeEncodeError",
                "'utf-8' codec can't encode character '" + code
                + "' in position " + str(i) + ": surrogates not allowed",
            );
        }
        i = i + 1;
    }
    return py_none();
}

def _py_repr_str(s: str) -> str {
    # Minimal %R for names: single quotes unless the value contains one.
    if "'" in s and '"' not in s {
        return '"' + s + '"';
    }
    return "'" + s + "'";
}

obj PwdGetPwnamFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error(
                "TypeError", "getpwnam() takes no keyword arguments"
            );
        }
        if len(args) != 1 {
            return py_error(
                "TypeError",
                "getpwnam() takes exactly one argument (" + str(len(args)) + " given)",
            );
        }
        if not isinstance(args[0], PyStr) {
            return py_error(
                "TypeError",
                "getpwnam() argument 1 must be str, not "
                + args[0].tp_type_name(),
            );
        }
        name: str = (args[0] as PyStr).val;
        enc_err = _fs_encode_error(name);
        if is_error(enc_err) {
            return enc_err;
        }
        if "\x00" in name {
            # PyBytes_AsStringAndSize(len=NULL) rejects embedded nulls.
            return py_error("ValueError", "embedded null byte");
        }
        try {
            row = _pwd_host().getpwnam(name);
        } except KeyError {
            return py_error(
                "KeyError",
                "getpwnam(): name not found: " + _py_repr_str(name),
            );
        } except Exception {
            return py_error(
                "KeyError",
                "getpwnam(): name not found: " + _py_repr_str(name),
            );
        }
        return _entry_from_host(row);
    }
}


# ---------------- getpwall ----------------------------------------------------

obj PwdGetPwallFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error(
                "TypeError", "getpwall() takes no keyword arguments"
            );
        }
        if len(args) != 0 {
            return py_error(
                "TypeError",
                "getpwall() takes exactly 0 arguments (" + str(len(args)) + " given)",
            );
        }
        try {
            rows = _pwd_host().getpwall();
        } except Exception {
            # HAVE_GETPWENT is always defined on our targets; a bridge failure
            # surfaces as the missing-surface error instead of a bare crash.
            return py_error(
                "AttributeError", "module 'pwd' has no attribute 'getpwall'"
            );
        }
        entries: list[PyObj] = [];
        for row in rows {
            entries.append(_entry_from_host(row));
        }
        return PyList(t="list", items=entries);
    }
}


# ---------------- module builder ----------------------------------------------

def build_pwd_module -> PyObj {
    wall = PwdGetPwallFn(t="pwd.fn");
    return PyModule(
        t="module",
        name="pwd",
        attrs={
            "getpwuid": PwdGetPwuidFn(t="pwd.fn"),
            "getpwnam": PwdGetPwnamFn(t="pwd.fn"),
            "getpwall": wall,
        },
    );
}
