import os;
import from _errno_native { last_errno, raise_os_error }
import from _file_native { read_file_bytes }
import from _directory_native { directory_names }
import from _filecmp_native { fc_probe, fc_size, fc_kind }

glob:pub DEFAULT_IGNORES: list[str] = [
         "RCS",
         "CVS",
         "tags",
         ".git",
         ".hg",
         ".bzr",
         "_darcs",
         "__pycache__"
     ];

glob _cache: dict[str, int] = {};

def _new_cache -> dict[str, int] {
    return {};
}

def:pub clear_cache {
    _cache = _new_cache();
}

def _do_cmp(f1: str, f2: str) -> bool {
    return read_file_bytes(f1) == read_file_bytes(f2);
}

def _cmp(a: str, b: str, sh: bool) -> int {
    try {
        if cmp(a, b, sh) {
            return 1;
        }
        return 0;
    } except Exception {
        return 2;
    }
}

def:pub cmp(f1: str, f2: str, shallow: bool = True) -> bool {
    p1: int = fc_probe(f1);
    if p1 < 0 {
        raise_os_error("stat", f1, last_errno());
    }
    p2: int = fc_probe(f2);
    if p2 < 0 {
        raise_os_error("stat", f2, last_errno());
    }
    if p1 % 2 == 0 or p2 % 2 == 0 {
        return False;
    }
    s1: int = p1 // 2;
    s2: int = p2 // 2;
    if shallow and s1 == s2 {
        return True;
    }
    z1: int = fc_size(f1);
    z2: int = fc_size(f2);
    if z1 != z2 {
        return False;
    }
    key: str = f1 + "\x01" + f2 + "\x01" + str(s1) + "\x01" + str(s2);
    hit: int = -1;
    if key in _cache {
        hit = _cache[key];
    }
    if hit >= 0 {
        return hit == 1;
    }
    outcome: bool = _do_cmp(f1, f2);
    if len(_cache) > 100 {
        clear_cache();
    }
    _cache[key] = 1 if outcome else 0;
    return outcome;
}

def:pub cmpfiles(
    a: str, b: str, common: list[str], shallow: bool = True
) -> tuple[(list[str], list[str], list[str])] {
    same: list[str] = [];
    missame: list[str] = [];
    errors: list[str] = [];
    for x in common {
        ax: str = os.path.join(a, x);
        bx: str = os.path.join(b, x);
        r: int = _cmp(ax, bx, shallow);
        if r == 1 {
            same.append(x);
        } elif r == 0 {
            missame.append(x);
        } else {
            errors.append(x);
        }
    }
    return (same, missame, errors);
}

def _filtered(names: list[str], skip_list: list[str]) -> list[str] {
    out: list[str] = [];
    for n in names {
        drop: bool = False;
        for s in skip_list {
            if n == s {
                drop = True;
                break;
            }
        }
        if not drop {
            out.append(n);
        }
    }
    return out;
}

def _sub(a: list[str], b: list[str]) -> list[str] {
    out: list[str] = [];
    for x in a {
        found: bool = False;
        for y in b {
            if x == y {
                found = True;
                break;
            }
        }
        if not found {
            out.append(x);
        }
    }
    return out;
}

def _inter(a: list[str], b: list[str]) -> list[str] {
    out: list[str] = [];
    for x in a {
        for y in b {
            if x == y {
                out.append(x);
                break;
            }
        }
    }
    return out;
}

def _cat(a: list[str], b: list[str]) -> list[str] {
    out: list[str] = [];
    for x in a {
        out.append(x);
    }
    for x in b {
        out.append(x);
    }
    return out;
}

obj:pub dircmp {
    has left: str = "",
        right: str = "",
        hide: list[str] = [],
        ignore: list[str] = [],
        shallow: bool = True,
        left_list: list[str] = [],
        right_list: list[str] = [],
        common: list[str] = [],
        left_only: list[str] = [],
        right_only: list[str] = [],
        common_dirs: list[str] = [],
        common_files: list[str] = [],
        common_funny: list[str] = [],
        same_files: list[str] = [],
        diff_files: list[str] = [],
        funny_files: list[str] = [],
        subdirs: dict[str, dircmp] = {};

    def init(
        a: str,
        b: str,
        ignore: (list[str] | None) = None,
        hide: (list[str] | None) = None,
        shallow: bool = True
    ) {
        self.left = a;
        self.right = b;
        self.shallow = shallow;
        if hide is None {
            self.hide = [".", ".."];
        } else {
            self.hide = hide;
        }
        if ignore is None {
            self.ignore = DEFAULT_IGNORES;
        } else {
            self.ignore = ignore;
        }
        self._phase0();
        self._phase1();
        self._phase2();
        self._phase3();
        self._phase4();
    }

    def _phase0 {
        skip_list: list[str] = _cat(self.hide, self.ignore);
        self.left_list = sorted(_filtered(directory_names(self.left), skip_list));
        self.right_list = sorted(_filtered(directory_names(self.right), skip_list));
    }

    def _phase1 {
        self.common = _inter(self.left_list, self.right_list);
        self.left_only = _sub(self.left_list, self.right_list);
        self.right_only = _sub(self.right_list, self.left_list);
    }

    def _phase2 {
        self.common_dirs = [];
        self.common_files = [];
        self.common_funny = [];
        for x in self.common {
            a_path: str = os.path.join(self.left, x);
            b_path: str = os.path.join(self.right, x);
            ka: int = fc_kind(a_path);
            kb: int = fc_kind(b_path);
            if ka < 0 or kb < 0 or ka != kb {
                self.common_funny.append(x);
                continue;
            }
            if ka == 2 {
                self.common_dirs.append(x);
            } elif ka == 1 {
                self.common_files.append(x);
            } else {
                self.common_funny.append(x);
            }
        }
    }

    def _phase3 {
        xx: tuple[(list[str], list[str], list[str])] = cmpfiles(
            self.left, self.right, self.common_files, self.shallow
        );
        self.same_files = xx[0];
        self.diff_files = xx[1];
        self.funny_files = xx[2];
    }

    def _phase4 {
        self.subdirs = {};
        for x in self.common_dirs {
            a_x: str = os.path.join(self.left, x);
            b_x: str = os.path.join(self.right, x);
            self.subdirs[x] = dircmp(a_x, b_x, self.ignore, self.hide, self.shallow);
        }
    }
}
