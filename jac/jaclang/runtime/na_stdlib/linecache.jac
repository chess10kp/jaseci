import os;

glob _LC_SIZE: dict[str, int] = {},
     _LC_MTIME: dict[str, float] = {},
     _LC_LINES: dict[str, list[str]] = {},
     _LC_FULL: dict[str, str] = {};

def:pub clearcache {
    _LC_SIZE = _lc_new_sizes();
    _LC_MTIME = _lc_new_mtimes();
    _LC_LINES = _lc_new_lines_map();
    _LC_FULL = _lc_new_fulls();
}

def _lc_new_sizes -> dict[str, int] {
    return {};
}

def _lc_new_mtimes -> dict[str, float] {
    return {};
}

def _lc_new_lines_map -> dict[str, list[str]] {
    return {};
}

def _lc_new_fulls -> dict[str, str] {
    return {};
}

def _lc_drop(filename: str) {
    if filename in _LC_LINES {
        _LC_LINES.pop(filename);
        _LC_SIZE.pop(filename);
        _LC_MTIME.pop(filename);
        _LC_FULL.pop(filename);
    }
}

def _source_unavailable(filename: str) -> bool {
    if filename == "" {
        return True;
    }
    return filename.startswith("<")
        and filename.endswith(">")
        and not filename.startswith("<frozen ");
}

def _read_lines(path: str) -> list[str] {
    f = open(path, "r");
    try {
        body: str = f.read();
        return body.splitlines(True);
    } finally {
        f.close();
    }
}

def _entry_lines(filename: str) -> list[str] {
    if filename in _LC_LINES {
        return _LC_LINES[filename];
    }
    empty: list[str] = [];
    return empty;
}

def:pub getlines(filename: str) -> list[str] {
    if filename in _LC_LINES {
        return _entry_lines(filename);
    }
    return updatecache(filename);
}

def:pub getline(filename: str, lineno: int) -> str {
    lines: list[str] = getlines(filename);
    if lineno >= 1 and lineno <= len(lines) {
        return lines[lineno - 1];
    }
    return "";
}

def _check_one(filename: str) {
    if not (filename in _LC_LINES) {
        return;
    }
    if _LC_MTIME[filename] < 0.0 {
        return;
    }
    fullname: str = _LC_FULL[filename];
    if not os.path.exists(fullname) {
        _lc_drop(filename);
        return;
    }
    size: int = os.path.getsize(fullname);
    mtime: float = os.path.getmtime(fullname);
    if size != _LC_SIZE[filename] or mtime != _LC_MTIME[filename] {
        _lc_drop(filename);
    }
}

def:pub checkcache(filename: (str | None) = None) {
    if isinstance(filename, str) {
        _check_one(filename);
        return;
    }
    names: list[str] = [];
    for k in _LC_LINES {
        names.append(k);
    }
    for k in names {
        _check_one(k);
    }
}

def:pub updatecache(filename: str) -> list[str] {
    if filename in _LC_LINES {
        _lc_drop(filename);
    }
    empty: list[str] = [];
    if _source_unavailable(filename) {
        return empty;
    }
    if filename.startswith("<frozen ") {
        return empty;
    }
    fullname: str = filename;
    if not os.path.exists(fullname) {
        return empty;
    }
    size: int = -1;
    mtime: float = -1.0;
    try {
        size = os.path.getsize(fullname);
        mtime = os.path.getmtime(fullname);
    } except Exception {
        return empty;
    }
    lines: list[str] = [];
    try {
        lines = _read_lines(fullname);
    } except Exception {
        return empty;
    }
    if not lines {
        lines = ["\n"];
    } elif not lines[len(lines) - 1].endswith("\n") {
        lines[len(lines) - 1] = lines[len(lines) - 1] + "\n";
    }
    _LC_LINES[filename] = lines;
    _LC_SIZE[filename] = size;
    _LC_MTIME[filename] = mtime;
    _LC_FULL[filename] = fullname;
    return lines;
}

def:pub lazycache(
    filename: str, module_globals: (dict[any, any] | None) = None
) -> bool {
    return False;
}
