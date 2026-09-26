import os;
import from _directory_native { directory_names, try_directory_names }
import from _file_native { read_file_bytes }
import from _pathlib_native { pl_lexists, pl_islink }
import from _user_home { user_home }
import from fnmatch { fnmatchcase }
import from glob { iglob }

def _root_of(p: str) -> str {
    if p.startswith("//") and not p.startswith("///") {
        return "//";
    }
    if p.startswith("/") {
        return "/";
    }
    return "";
}

def _parts_of(p: str) -> list[str] {
    out: list[str] = [];
    for comp in p.split("/") {
        if comp == "" or comp == "." {
            continue;
        }
        out.append(comp);
    }
    return out;
}

def _assemble(anchor: str, parts: list[str]) -> str {
    out: str = anchor + "/".join(parts);
    if out == "" {
        return ".";
    }
    return out;
}

def _norm(p: str) -> str {
    return _assemble(_root_of(p), _parts_of(p));
}

def _collapse(p: str) -> str {
    anchor: str = _root_of(p);
    out: list[str] = [];
    for comp in _parts_of(p) {
        if comp != ".." {
            out.append(comp);
            continue;
        }
        if anchor != "" {
            if out {
                out.pop();
            }
            continue;
        }
        if out and out[len(out) - 1] != ".." {
            out.pop();
            continue;
        }
        out.append("..");
    }
    return _assemble(anchor, out);
}

obj:pub Path {
    has _p: str = ".";
    has name: str { getter; }
    has stem: str { getter; }
    has parent: Path { getter; }
    has parts: list[str] { getter; }
    has anchor: str { getter; }
    has `root: str { getter; }
    has drive: str { getter; }
    has suffix: str { getter; }
    has suffixes: list[str] { getter; }

    def init(p: (str | Path) = "") {
        if isinstance(p, Path) {
            self._p = p._p;
        } else {
            self._p = _norm(p);
        }
    }

    def __str__ -> str {
        return self._p;
    }

    def __truediv__(other: str) -> Path {
        if other.startswith("/") {
            return Path(other);
        }
        if self._p.endswith("/") {
            return Path(self._p + other);
        }
        return Path(self._p + "/" + other);
    }

    def exists -> bool {
        return os.path.exists(self._p);
    }

    def is_dir -> bool {
        return os.path.isdir(self._p);
    }

    def read_bytes -> bytes {
        return read_file_bytes(self._p);
    }

    def iterdir -> Iterator[Path] {
        children: list[Path] = [];
        for name in directory_names(self._p) {
            children.append(self / name);
        }
        return iter(children);
    }

    def is_absolute -> bool {
        return self._p.startswith("/");
    }

    def absolute -> Path {
        if self.is_absolute() {
            return self;
        }
        return Path(os.getcwd() + "/" + self._p);
    }

    def joinpath(
        o1: str,
        o2: (str | None) = None,
        o3: (str | None) = None,
        o4: (str | None) = None
    ) -> Path {
        out: Path = self;
        out = out / o1;
        if isinstance(o2, str) {
            out = out / o2;
        }
        if isinstance(o3, str) {
            out = out / o3;
        }
        if isinstance(o4, str) {
            out = out / o4;
        }
        return out;
    }

    def with_name(nm: str) -> Path {
        if "/" in nm {
            raise ValueError("Invalid name '" + nm + "'");
        }
        if self.name == "" {
            raise ValueError("'" + self._p + "' has an empty name");
        }
        return self.parent / nm;
    }

    def with_suffix(suffix: str) -> Path {
        if suffix != "" and not suffix.startswith(".") {
            raise ValueError("Invalid suffix '" + suffix + "'");
        }
        if self.name == "" {
            raise ValueError("'" + self._p + "' has an empty name");
        }
        return self.parent / (self.stem + suffix);
    }

    def `match(pattern: str) -> bool {
        pp: list[str] = _parts_of(pattern);
        anchor_p: str = _root_of(pattern);
        if len(pp) == 0 and anchor_p == "" {
            raise ValueError("empty pattern");
        }
        me: list[str] = _parts_of(self._p);
        if len(me) < len(pp) {
            return False;
        }
        if len(me) > len(pp) and anchor_p != "" {
            return False;
        }
        if anchor_p != "" and _root_of(self._p) != anchor_p {
            return False;
        }
        i: int = len(me) - 1;
        j: int = len(pp) - 1;
        while j >= 0 {
            if not fnmatchcase(me[i], pp[j]) {
                return False;
            }
            i -= 1;
            j -= 1;
        }
        return True;
    }

    def is_file -> bool {
        return os.path.isfile(self._p);
    }

    def is_symlink -> bool {
        return pl_islink(self._p);
    }

    def read_text -> str {
        f = open(self._p, "r");
        try {
            return f.read();
        } finally {
            f.close();
        }
    }

    def write_text(data: str) -> int {
        f = open(self._p, "w");
        try {
            return int(f.write(data));
        } finally {
            f.close();
        }
    }

    def mkdir(mode: int = 511, parents: bool = False, exist_ok: bool = False) {
        if os.path.exists(self._p) {
            if exist_ok and self.is_dir() {
                return;
            }
            raise FileExistsError("[Errno 17] File exists: '" + self._p + "'");
        }
        if parents {
            os.makedirs(self._p, mode);
        } else {
            os.mkdir(self._p, mode);
        }
    }

    def unlink(missing_ok: bool = False) {
        if not pl_lexists(self._p) {
            if missing_ok {
                return;
            }
            raise FileNotFoundError(
                "[Errno 2] No such file or directory: '" + self._p + "'"
            );
        }
        if self.is_dir() and not self.is_symlink() {
            raise IsADirectoryError("[Errno 21] Is a directory: '" + self._p + "'");
        }
        os.unlink(self._p);
    }

    def rmdir {
        if not self.is_dir() {
            raise NotADirectoryError("[Errno 20] Not a directory: '" + self._p + "'");
        }
        if len(try_directory_names(self._p)) != 0 {
            raise OSError("[Errno 39] Directory not empty: '" + self._p + "'");
        }
        os.rmdir(self._p);
    }

    def `glob(pattern: str) -> list[Path] {
        if pattern.startswith("/") {
            raise NotImplementedError("Non-relative patterns are unsupported");
        }
        full: str = pattern;
        if self._p != "." {
            full = os.path.join(self._p, pattern);
        }
        out: list[Path] = [];
        for h in iglob(full, recursive=True, include_hidden=True) {
            out.append(Path(h));
        }
        return out;
    }

    def rglob(pattern: str) -> list[Path] {
        return self.glob("**/" + pattern);
    }

    static def cwd -> Path {
        return Path(os.getcwd());
    }

    static def home -> Path {
        h: (str | None) = user_home("");
        if isinstance(h, str) and h != "" {
            return Path(h);
        }
        raise RuntimeError("Could not determine home directory.");
    }

    def resolve -> Path {
        base: str = self._p;
        if not base.startswith("/") {
            cwd: str = os.getcwd();
            if base == "." {
                base = cwd;
            } else {
                base = cwd + "/" + base;
            }
        }
        return Path(_collapse(os.path.realpath(base)));
    }
}

impl Path.name.getter -> str {
    parts: list[str] = _parts_of(self._p);
    if not parts {
        return "";
    }
    return parts[len(parts) - 1];
}

impl Path.stem.getter -> str {
    nm: str = self.name;
    cut: int = nm.rfind(".");
    if cut <= 0 {
        return nm;
    }
    lead: int = 0;
    while lead < cut {
        if nm[lead] != "." {
            return nm[:cut];
        }
        lead += 1;
    }
    return nm;
}

impl Path.parent.getter -> Path {
    parts: list[str] = _parts_of(self._p);
    if not parts {
        return self;
    }
    parts.pop();
    return Path(_assemble(_root_of(self._p), parts));
}

impl Path.parts.getter -> list[str] {
    if self._p == "." {
        empty: list[str] = [];
        return empty;
    }
    out: list[str] = [];
    anchor: str = _root_of(self._p);
    if anchor != "" {
        out.append(anchor);
    }
    for comp in _parts_of(self._p) {
        out.append(comp);
    }
    return out;
}

impl Path.anchor.getter -> str {
    return _root_of(self._p);
}

impl Path.`root.getter -> str {
    if _root_of(self._p) == "" {
        return "";
    }
    return "/";
}

impl Path.drive.getter -> str {
    return "";
}

impl Path.suffix.getter -> str {
    nm: str = self.name;
    lead: int = 0;
    n: int = len(nm);
    while lead < n and nm[lead] == "." {
        lead += 1;
    }
    body: str = nm[lead:];
    i: int = body.rfind(".");
    if i < 0 {
        return "";
    }
    return body[i:];
}

impl Path.suffixes.getter -> list[str] {
    nm: str = self.name;
    lead: int = 0;
    n: int = len(nm);
    while lead < n and nm[lead] == "." {
        lead += 1;
    }
    body: str = nm[lead:];
    segs: list[str] = body.split(".");
    out: list[str] = [];
    i: int = 1;
    while i < len(segs) {
        out.append("." + segs[i]);
        i += 1;
    }
    return out;
}
