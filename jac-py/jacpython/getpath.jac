# Product-path facade for getpath (initial module search path helpers).
# Semantics mirror CPython 3.14 ``Modules/getpath.c``: the getpath_* helper
# table (abspath/basename/dirname/hassuffix/isabs/isdir/isfile/isxfile/
# joinpath/readlines/realpath/warn) that _PyConfig_InitPathConfig injects
# into the globals dict before evaluating the frozen getpath.py bytecode.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original operates
# on wchar buffers with hand-rolled normalization (_Py_normpath/_Py_abspath/
# _Py_add_relfile in Python/fileutils.c) because it runs before any Python
# module can be imported. This facade runs inside a live VM, so filesystem
# probes delegate to the host os/stat modules and path surgery is a direct
# string-level lift of the same algorithms (POSIX branches; the MS_WINDOWS /
# macOS-only arms of the C source are out of scope for the linux product
# path).
#
# Out of scope by design: _Py_Get_Getpath_CodeObject (frozen-marshal bridge)
# and _PyConfig_InitPathConfig (needs the PyConfig <-> dict bridge). The
# helper contract below is everything getpath.py itself consumes.

import os as host_os;
import stat as host_stat;
import sys as host_sys;

glob SEP: str = "/";
glob _MAX_READLINES_BYTES: int = 32 * 1024;
glob _MAX_SYMLINKS: int = 40;


# ---------------- _Py_normpath (POSIX arm, string level) ----------------

def _normpath(path: str) -> str {
    # _Py_normpath_and_size (Python/fileutils.c), POSIX arm: collapse
    # separator runs, drop '.' segments, resolve '..' against the previous
    # segment without crossing a root, strip trailing separators. Unlike
    # posixpath.normpath, an empty input stays empty and a fully-absorbed
    # relative path collapses to "" rather than ".".
    if not path {
        return "";
    }
    rooted: bool = path.startswith(SEP);
    parts: list = [];
    for seg in path.split(SEP) {
        if seg == "" or seg == "." {
            continue;
        }
        if seg == ".." {
            if len(parts) and parts[-1] != ".." {
                parts.pop();
            } elif not rooted {
                parts.append("..");
            }
            continue;
        }
        parts.append(seg);
    }
    if rooted {
        return SEP + SEP.join(parts);
    }
    return SEP.join(parts);
}


def _isabs(path: str) -> bool {
    # _Py_isabs POSIX arm: leading separator.
    return path.startswith(SEP);
}


def _join_relfile(dirname_: str, relfile: str) -> str {
    # join_relfile (Python/fileutils.c) POSIX arm: no leading separator when
    # the directory is empty, none doubled when it already ends in one.
    if not dirname_ {
        return relfile;
    }
    if dirname_.endswith(SEP) {
        return dirname_ + relfile;
    }
    return dirname_ + SEP + relfile;
}


# ---------------- getpath_* helper table (Modules/getpath.c) ------------

def abspath(path: str) -> str {
    # getpath_abspath: normalize first, then absolutize against CWD
    # (_Py_abspath POSIX arm).
    p = _normpath(path);
    if not p or p == "." {
        return host_os.getcwd();
    }
    if _isabs(p) {
        return p;
    }
    return host_os.getcwd() + SEP + p;
}


def basename(path: str) -> str {
    # getpath_basename: substring after the last separator (searched
    # back-to-front like PyUnicode_FindChar with -1).
    pos = path.rfind(SEP);
    if pos < 0 {
        return path;
    }
    return path[pos + 1:];
}


def dirname(path: str) -> str {
    # getpath_dirname: prefix before the last separator, else "".
    pos = path.rfind(SEP);
    if pos < 0 {
        return "";
    }
    return path[:pos];
}


def hassuffix(path: str, suffix: str) -> bool {
    # getpath_hassuffix: length-guarded exact tail comparison.
    if len(suffix) > len(path) {
        return False;
    }
    return path.endswith(suffix);
}


def isabs(path: str) -> bool {
    return _isabs(path);
}


def isdir(path: str) -> bool {
    # getpath_isdir POSIX arm: stat + S_ISDIR (follows symlinks).
    try {
        st = host_os.stat(path);
    } except OSError {
        return False;
    }
    return host_stat.S_ISDIR(st.st_mode);
}


def isfile(path: str) -> bool {
    # getpath_isfile POSIX arm: stat + S_ISREG (follows symlinks).
    try {
        st = host_os.stat(path);
    } except OSError {
        return False;
    }
    return host_stat.S_ISREG(st.st_mode);
}


def isxfile(path: str) -> bool {
    # getpath_isxfile POSIX arm: regular file with any execute bit.
    try {
        st = host_os.stat(path);
    } except OSError {
        return False;
    }
    return host_stat.S_ISREG(st.st_mode) and (st.st_mode & 0o111) != 0;
}


def joinpath(*parts: any) -> str {
    # getpath_joinpath: None parts vanish, the LAST absolute part resets the
    # join base (everything before it is dropped), remaining parts are glued
    # with single separators and the result normalized.
    first = -1;
    for i in range(len(parts)) {
        p = parts[i];
        if p is None {
            continue;
        }
        if isinstance(p, str) {
            if _isabs(p) {
                first = i;
            }
        } else {
            raise TypeError("all arguments to joinpath() must be str or None");
        }
    }
    if first < 0 {
        return "";
    }
    final = "";
    for p in parts[first:] {
        if p is None {
            continue;
        }
        if not final {
            final = p;
        } else {
            final = _join_relfile(final, p);
        }
    }
    return _normpath(final);
}


def readlines(path: str) -> list {
    # getpath_readlines: at most 32KB of UTF-8 (surrogateescaped), split on
    # newlines with every trailing CR/LF stripped from complete lines; a
    # non-empty tail after the last newline is kept verbatim.
    fp = open(path, "rb");
    try {
        buffer = fp.read(_MAX_READLINES_BYTES);
    } finally {
        fp.close();
    }
    if len(buffer) >= _MAX_READLINES_BYTES {
        raise MemoryError("cannot read file larger than 32KB during initialization");
    }
    if not buffer {
        return [];
    }
    text = buffer.decode("utf-8", "surrogateescape");
    segments = text.split("\n");
    lines: list = [];
    for seg in segments[:-1] {
        lines.append(seg.rstrip("\r\n"));
    }
    tail = segments[-1];
    if tail {
        lines.append(tail);
    }
    return lines;
}


def realpath(path: str) -> str {
    # getpath_realpath HAVE_READLINK arm: resolve only a symlinked leaf (no
    # intermediate segments), up to the Linux-kernel 40-link limit. A failed
    # readlink emits the current path unchanged.
    path_worked: str = path;
    nlink = 0;
    while True {
        try {
            resolved = host_os.readlink(path_worked);
        } except OSError {
            return path_worked;
        }
        if _isabs(resolved) {
            path_worked = resolved;
        } else {
            s = path_worked.rfind(SEP);
            if s >= 0 {
                head = path_worked[:s];
            } else {
                head = path_worked;
            }
            path_worked = _normpath(_join_relfile(head, resolved));
        }
        nlink += 1;
        if nlink >= _MAX_SYMLINKS {
            raise OSError("maximum number of symbolic links reached");
        }
    }
}


def warn(message: str) -> None {
    # getpath_warn: init-time warnings go straight to stderr (the nowarn
    # variant selected when pathconfig_warnings is false is a no-op, so
    # callers simply skip the call guest-side).
    host_sys.stderr.write(message + "\n");
}
