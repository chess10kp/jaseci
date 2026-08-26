# Product-path facade for pwd (Modules/pwdmodule.c).
#
# Semantics mirror CPython 3.14 ``Modules/pwdmodule.c``: the struct_passwd
# struct-sequence (7 fields, tuple protocol + named attributes), getpwuid /
# getpwnam / getpwall, and the byte-exact KeyError channels from mkpwent's
# callers ("getpwuid(): uid not found: %S" / "getpwnam(): name not found: %R").
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original resolves
# entries through the NSS floor (getpwuid_r/getpwnam_r/getpwent with ERANGE
# retry). There is no differently-named host extension to delegate to (the
# module IS ``pwd``, so a same-name host import inside this facade would
# self-resolve), and the guest VM has no libc bridge yet. The floor here is
# therefore the files backend itself: /etc/passwd parsed with glibc's
# files-parser rules (blank lines, comments and rows whose uid/gid are not
# numeric are skipped; exactly seven colon-separated fields required). On any
# host where passwd lives purely in /etc/passwd -- every CI target -- results
# are identical to NSS order-for-order; pure-NSS sources (LDAP, NIS) diverge.
#
# Entry representation: pwd.struct_passwd is a PyStructSequence -- a tuple
# subclass carrying named attributes. Here each entry is a PyUserObj whose
# class is a native-tuple PyClass and whose boxed base is the 7-item PyTuple,
# so len()/indexing/iteration/equality/hash run through the tuple slot chain
# while pw_* reads resolve through the instance attrs dict.
#
# Argument validation follows the C converters: uidobj goes through the
# __index__ protocol (floats raise the canonical "'<T>' object cannot be
# interpreted as an integer"), names must be str, embedded NUL raises
# ValueError("embedded null character") after the FS-encode step, and lone
# surrogates outside the surrogateescape window (U+DC80..U+DCFF) raise
# UnicodeEncodeError exactly where PyUnicode_EncodeFSDefault does on Linux.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyTuple,
    PyList,
    PyModule,
    py_error,
    py_none,
    is_error,
}

import from ceval {
    PyUserObj,
    PyClass,
    py_repr,
    _sm_int,
}


# ---------------- struct_passwd type (PyStructSequence_NewType) --------------

glob _struct_passwd_cls_cache: PyClass | None = None;

def _struct_passwd_type -> PyClass {
    # pwdmodule_exec: PyStructSequence_NewType over struct_pwd_type_desc --
    # one heap type, minted once per module lifetime.
    if _struct_passwd_cls_cache is None {
        _struct_passwd_cls_cache = PyClass(
            t="class",
            name="struct_passwd",
            attrs={},
            bases=[],
            native_base="tuple",
        );
    }
    return _struct_passwd_cls_cache as PyClass;
}


# ---------------- entry construction (mkpwent) -------------------------------

def _mk_entry(fields: list[str]) -> PyObj {
    # mkpwent: SET_STRING for name/passwd/gecos/dir/shell, _PyLong_FromUid/Gid
    # for uid/gid -- positions and attribute names fixed by
    # struct_pwd_type_fields. The files backend never yields NULL fields, so
    # the None arms of SET_STRING never fire.
    items: list[PyObj] = [
        PyStr(t="str", val=fields[0]),
        PyStr(t="str", val=fields[1]),
        PyInt(t="int", val=int(fields[2])),
        PyInt(t="int", val=int(fields[3])),
        PyStr(t="str", val=fields[4]),
        PyStr(t="str", val=fields[5]),
        PyStr(t="str", val=fields[6]),
    ];
    return PyUserObj(
        t="instance",
        cls=_struct_passwd_type(),
        attrs={
            "pw_name": items[0],
            "pw_passwd": items[1],
            "pw_uid": items[2],
            "pw_gid": items[3],
            "pw_gecos": items[4],
            "pw_dir": items[5],
            "pw_shell": items[6],
        },
        base=PyTuple(t="tuple", items=items),
    );
}


# ---------------- files backend (getpwent floor) ------------------------------

def _read_passwd_rows -> list[list[str]] {
    rows: list[list[str]] = [];
    try {
        fh = open("/etc/passwd", "r");
        data = str(fh.read());
        fh.close();
    } except Exception {
        # No readable database: getpwent yields nothing rather than failing.
        return rows;
    }
    for line in data.split("\n") {
        # glibc files-parse rules: blank lines and '#' comments never yield
        # entries; a row needs exactly the seven passwd fields.
        if line == "" or line.startswith("#") {
            continue;
        }
        fields = line.split(":");
        if len(fields) != 7 {
            continue;
        }
        try {
            int(fields[2]);
            int(fields[3]);
        } except Exception {
            continue;
        }
        rows.append(fields);
    }
    return rows;
}


# ---------------- FS-encode step (PyUnicode_EncodeFSDefault) ------------------

def _fs_encode_check(name: str) -> PyObj {
    # Linux FS encoder is utf-8/surrogateescape: U+DC80..U+DCFF map to raw
    # bytes and pass; every other lone surrogate fails the encode exactly as
    # PyUnicode_EncodeFSDefault does. Runs BEFORE the NUL check, matching the
    # C order (encode first, then the strlen size comparison).
    i = 0;
    for ch in name {
        o = ord(ch);
        if o >= 0xD800 and o < 0xDC80 {
            return py_error(
                "UnicodeEncodeError",
                "'utf-8' codec can't encode character '\\u"
                + hex(o)[2:]
                + "' in position "
                + str(i)
                + ": surrogates not allowed",
            );
        }
        i += 1;
    }
    if "\x00" in name {
        # strlen(name_chars) < byte-length check after FS encoding.
        return py_error("ValueError", "embedded null character");
    }
    return py_none();
}


# ---------------- pwd.getpwuid ------------------------------------------------

def _pwd_getpwuid_impl(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(kwargs) > 0 {
        return py_error("TypeError", "getpwuid() takes no keyword arguments");
    }
    if len(args) == 0 {
        return py_error(
            "TypeError", "function missing required argument 'uid' (pos 1)"
        );
    }
    if len(args) > 1 {
        return py_error(
            "TypeError", "getpwuid expected 1 argument, got " + str(len(args))
        );
    }
    # _Py_Uid_Converter: the __index__ protocol (floats reject here).
    idx = _sm_int(args[0]);
    if is_error(idx) {
        return idx;
    }
    uid = (idx as PyInt).val;
    for row in _read_passwd_rows() {
        if int(row[2]) == uid {
            return _mk_entry(row);
        }
    }
    # PyErr_Format(PyExc_KeyError, "getpwuid(): uid not found: %S", uid_obj).
    return py_error("KeyError", "getpwuid(): uid not found: " + str(uid));
}


# ---------------- pwd.getpwnam ------------------------------------------------

def _pwd_getpwnam_impl(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(kwargs) > 0 {
        return py_error("TypeError", "getpwnam() takes no keyword arguments");
    }
    if len(args) == 0 {
        return py_error(
            "TypeError", "function missing required argument 'name' (pos 1)"
        );
    }
    if len(args) > 1 {
        return py_error(
            "TypeError", "getpwnam expected 1 argument, got " + str(len(args))
        );
    }
    if not isinstance(args[0], PyStr) {
        return py_error(
            "TypeError",
            "'" + args[0].tp_type_name() + "' object cannot be converted to 'str'",
        );
    }
    encode_err = _fs_encode_check((args[0] as PyStr).val);
    if is_error(encode_err) {
        return encode_err;
    }
    name = (args[0] as PyStr).val;
    for row in _read_passwd_rows() {
        if row[0] == name {
            return _mk_entry(row);
        }
    }
    # PyErr_Format(PyExc_KeyError, "getpwnam(): name not found: %R", name).
    rep = py_repr(args[0]);
    rep_text = "";
    if isinstance(rep, PyStr) {
        rep_text = (rep as PyStr).val;
    }
    return py_error("KeyError", "getpwnam(): name not found: " + rep_text);
}


# ---------------- pwd.getpwall ------------------------------------------------

def _pwd_getpwall_impl(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(args) > 0 or len(kwargs) > 0 {
        return py_error(
            "TypeError", "getpwall() takes no arguments (" + str(len(args) + len(kwargs)) + " given)"
        );
    }
    entries: list[PyObj] = [];
    for row in _read_passwd_rows() {
        entries.append(_mk_entry(row));
    }
    return PyList(t="list", items=entries);
}


# ---------------- callable surfaces ------------------------------------------

obj PwdGetpwuidFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _pwd_getpwuid_impl(args, kwargs);
    }
}

obj PwdGetpwnamFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _pwd_getpwnam_impl(args, kwargs);
    }
}

obj PwdGetpwallFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _pwd_getpwall_impl(args, kwargs);
    }
}


# ---------------- module builder ----------------------------------------------

def build_pwd_module -> PyObj {
    return PyModule(
        t="module",
        name="pwd",
        attrs={
            "struct_passwd": _struct_passwd_type(),
            "getpwuid": PwdGetpwuidFn(t="pwd_getpwuid"),
            "getpwnam": PwdGetpwnamFn(t="pwd_getpwnam"),
            "getpwall": PwdGetpwallFn(t="pwd_getpwall"),
        },
    );
}
