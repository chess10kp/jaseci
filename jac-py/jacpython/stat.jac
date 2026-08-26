# Native stat module facade (lift of reference/cpython/Modules/_stat.c).
#
# _stat.c is the multi-phase-init accelerator behind Lib/stat.py: at exec it
# inserts the S_IF*/S_I*/UF_*/SF_*/ST_* constant tables and binds the METH_O
# helpers S_IS*(mode), S_IMODE, S_IFMT and filemode. This facade mirrors that
# surface for the Linux/glibc build of the pinned CPython 3.14 reference:
#
# - Constant values follow stat_exec()'s ADD_INT_MACRO insertion order using
#   whichever arm is active on this platform: glibc definitions where present,
#   otherwise the C file's #ifndef fallbacks. MS_WINDOWS FILE_ATTRIBUTE_* /
#   IO_REPARSE_TAG_* and the __APPLE__-only SF_SUPPORTED/SF_SYNTHETIC branches
#   never fire here and are intentionally absent.
# - The function surface delegates to the staged ``_statmodule.jac`` extract
#   (aliased to public names), which already carries the reference semantics
#   for the predicates, masks and filemode.
# - Mode coercion mirrors ``_PyLong_AsMode_t``: index-coerce the single
#   positional, then range-check against the Linux mode_t (unsigned int);
#   negative -> OverflowError("can't convert negative value to unsigned
#   int"), > 0xFFFFFFFF -> OverflowError("mode out of range").
#
# Wiring: ceval.jac registers this surface as a lazy shim in both import_native
# and host_import, so guest ``import stat`` resolves proxy-free like
# errno/gc/heapq instead of leaking a host PyProxy.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    py_error,
    is_error,
}

import from _statmodule {
    _p2_S_IMODE as S_IMODE,
    _p2_S_IFMT as S_IFMT,
    _p2_S_ISDIR as S_ISDIR,
    _p2_S_ISCHR as S_ISCHR,
    _p2_S_ISBLK as S_ISBLK,
    _p2_S_ISREG as S_ISREG,
    _p2_S_ISFIFO as S_ISFIFO,
    _p2_S_ISLNK as S_ISLNK,
    _p2_S_ISSOCK as S_ISSOCK,
    _p2_filemode as filemode,
    S_IFDIR,
    S_IFCHR,
    S_IFBLK,
    S_IFREG,
    S_IFIFO,
    S_IFLNK,
    S_IFSOCK,
    S_ISUID,
    S_ISGID,
    S_ISVTX,
    S_ENFMT,
    S_IREAD,
    S_IWRITE,
    S_IEXEC,
    S_IRWXU,
    S_IRUSR,
    S_IWUSR,
    S_IXUSR,
    S_IRWXG,
    S_IRGRP,
    S_IWGRP,
    S_IXGRP,
    S_IRWXO,
    S_IROTH,
    S_IWOTH,
    S_IXOTH,
    ST_MODE,
    ST_INO,
    ST_DEV,
    ST_NLINK,
    ST_UID,
    ST_GID,
    ST_SIZE,
    ST_ATIME,
    ST_MTIME,
    ST_CTIME,
}

# Non-standard file types: POSIX builds define no S_IFDOOR/S_IFPORT/S_IFWHT,
# so the C file's literal-0 fallbacks apply (same for their S_IS* predicates).
glob S_IFDOOR: int = 0,
     S_IFPORT: int = 0,
     S_IFWHT: int = 0,
     # BSD file flags; glibc <sys/stat.h> does not define them on Linux, so
     # these are the C file's #ifndef fallback values, matching what the
     # reference build exports on this platform.
     UF_SETTABLE: int = 0xffff,
     UF_NODUMP: int = 0x1,
     UF_IMMUTABLE: int = 0x2,
     UF_APPEND: int = 0x4,
     UF_OPAQUE: int = 0x8,
     UF_NOUNLINK: int = 0x10,
     UF_COMPRESSED: int = 0x20,
     UF_TRACKED: int = 0x40,
     UF_DATAVAULT: int = 0x80,
     UF_HIDDEN: int = 0x8000,
     SF_SETTABLE: int = 0xffff0000,
     SF_ARCHIVED: int = 0x10000,
     SF_IMMUTABLE: int = 0x20000,
     SF_APPEND: int = 0x40000,
     SF_NOUNLINK: int = 0x100000,
     SF_SNAPSHOT: int = 0x200000,
     SF_FIRMLINK: int = 0x800000,
     SF_DATALESS: int = 0x40000000;

# _PyLong_AsMode_t(): coerce one index-able argument to the mode word, or
# return the error PyObj the C path would raise.
def _mode_arg(o: PyObj) -> PyObj {
    r = o.to_index();
    if is_error(r) {
        return py_error(
            "TypeError",
            "'" + o.tp_type_name() + "' object cannot be interpreted as an integer",
        );
    }
    v = (r as PyInt).val;
    if v < 0 {
        return py_error(
            "OverflowError", "can't convert negative value to unsigned int"
        );
    }
    if v > 0xFFFFFFFF {
        return py_error("OverflowError", "mode out of range");
    }
    return r;
}

obj PyStatFn(PyObj) {
    has name: str;

    # Identity hash (builtin-style callable; stdlib stores these in sets).
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # METH_O: no keyword acceptance, exactly one positional.
        if len(kwargs) > 0 {
            return py_error(
                "TypeError", "_stat." + self.name + "() takes no keyword arguments"
            );
        }
        if len(args) != 1 {
            return py_error(
                "TypeError",
                "_stat." + self.name + "() takes exactly one argument ("
                + str(len(args)) + " given)",
            );
        }
        m = _mode_arg(args[0]);
        if is_error(m) {
            return m;
        }
        mode = (m as PyInt).val;
        if self.name == "S_ISDIR" {
            return PyBool(t="bool", val=S_ISDIR(mode));
        }
        if self.name == "S_ISCHR" {
            return PyBool(t="bool", val=S_ISCHR(mode));
        }
        if self.name == "S_ISBLK" {
            return PyBool(t="bool", val=S_ISBLK(mode));
        }
        if self.name == "S_ISREG" {
            return PyBool(t="bool", val=S_ISREG(mode));
        }
        if self.name == "S_ISFIFO" {
            return PyBool(t="bool", val=S_ISFIFO(mode));
        }
        if self.name == "S_ISLNK" {
            return PyBool(t="bool", val=S_ISLNK(mode));
        }
        if self.name == "S_ISSOCK" {
            return PyBool(t="bool", val=S_ISSOCK(mode));
        }
        if self.name == "S_ISDOOR" {
            # Literal-0 macro: always False on POSIX builds.
            return PyBool(t="bool", val=False);
        }
        if self.name == "S_ISPORT" {
            return PyBool(t="bool", val=False);
        }
        if self.name == "S_ISWHT" {
            return PyBool(t="bool", val=False);
        }
        if self.name == "S_IMODE" {
            return PyInt(t="int", val=S_IMODE(mode));
        }
        if self.name == "S_IFMT" {
            return PyInt(t="int", val=S_IFMT(mode));
        }
        if self.name == "filemode" {
            return PyStr(t="str", val=filemode(mode));
        }
        return py_error("SystemError", "unknown stat function '" + self.name + "'");
    }
}

# Module attrs: the full stat_exec() constant table plus the stat_methods[]
# callables -- the exact shape the C module dict ends up with.
def stat_module_attrs -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {};
    const_names: list[str] = [
        "S_IFDIR", "S_IFCHR", "S_IFBLK", "S_IFREG", "S_IFIFO", "S_IFLNK",
        "S_IFSOCK", "S_IFDOOR", "S_IFPORT", "S_IFWHT",
        "S_ISUID", "S_ISGID", "S_ISVTX", "S_ENFMT",
        "S_IREAD", "S_IWRITE", "S_IEXEC",
        "S_IRWXU", "S_IRUSR", "S_IWUSR", "S_IXUSR",
        "S_IRWXG", "S_IRGRP", "S_IWGRP", "S_IXGRP",
        "S_IRWXO", "S_IROTH", "S_IWOTH", "S_IXOTH",
        "UF_SETTABLE", "UF_NODUMP", "UF_IMMUTABLE", "UF_APPEND", "UF_OPAQUE",
        "UF_NOUNLINK", "UF_COMPRESSED", "UF_TRACKED", "UF_DATAVAULT",
        "UF_HIDDEN",
        "SF_SETTABLE", "SF_ARCHIVED", "SF_IMMUTABLE", "SF_APPEND",
        "SF_NOUNLINK", "SF_SNAPSHOT", "SF_FIRMLINK", "SF_DATALESS",
        "ST_MODE", "ST_INO", "ST_DEV", "ST_NLINK", "ST_UID", "ST_GID",
        "ST_SIZE", "ST_ATIME", "ST_MTIME", "ST_CTIME",
    ];
    const_vals: list[int] = [
        S_IFDIR, S_IFCHR, S_IFBLK, S_IFREG, S_IFIFO, S_IFLNK, S_IFSOCK,
        S_IFDOOR, S_IFPORT, S_IFWHT,
        S_ISUID, S_ISGID, S_ISVTX, S_ENFMT,
        S_IREAD, S_IWRITE, S_IEXEC,
        S_IRWXU, S_IRUSR, S_IWUSR, S_IXUSR,
        S_IRWXG, S_IRGRP, S_IWGRP, S_IXGRP,
        S_IRWXO, S_IROTH, S_IWOTH, S_IXOTH,
        UF_SETTABLE, UF_NODUMP, UF_IMMUTABLE, UF_APPEND, UF_OPAQUE,
        UF_NOUNLINK, UF_COMPRESSED, UF_TRACKED, UF_DATAVAULT, UF_HIDDEN,
        SF_SETTABLE, SF_ARCHIVED, SF_IMMUTABLE, SF_APPEND, SF_NOUNLINK,
        SF_SNAPSHOT, SF_FIRMLINK, SF_DATALESS,
        ST_MODE, ST_INO, ST_DEV, ST_NLINK, ST_UID, ST_GID, ST_SIZE,
        ST_ATIME, ST_MTIME, ST_CTIME,
    ];
    for i in range(len(const_names)) {
        attrs[const_names[i]] = PyInt(t="int", val=const_vals[i]);
    }
    for fname in [
        "S_ISDIR", "S_ISCHR", "S_ISBLK", "S_ISREG", "S_ISFIFO",
        "S_ISLNK", "S_ISSOCK", "S_ISDOOR", "S_ISPORT", "S_ISWHT",
        "S_IMODE", "S_IFMT", "filemode",
    ] {
        attrs[fname] = PyStatFn(t="stat_fn", name=fname) as PyObj;
    }
    return attrs;
}
