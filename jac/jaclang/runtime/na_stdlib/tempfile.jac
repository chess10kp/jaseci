import os;
import from _errno_native { last_errno, raise_os_error }
import from _csprng_native { csprng_bytes }
import from _tempfile_native {
    tf_create_excl,
    tf_mkdir,
    tf_write,
    tf_read,
    tf_seek,
    tf_tell,
    tf_fsync,
    tf_close,
    tf_unlink,
    tf_access
}
import from shutil { rmtree }

glob:pub TMP_MAX: int = 20,
     template: str = "tmp";

glob _tempdir: str = "",
     _tempdir_set: bool = False;

glob _NAMED_CHARS: str = "abcdefghijklmnopqrstuvwxyz0123456789_";

def _rng_name -> str {
    raw: bytes = csprng_bytes(8);
    out: str = "";
    i: int = 0;
    while i < len(raw) {
        out += _NAMED_CHARS[raw[i] % len(_NAMED_CHARS)];
        i += 1;
    }
    return out;
}

def _dir_or_default(dir: (str | None)) -> str {
    if isinstance(dir, str) and dir != "" {
        return dir;
    }
    return gettempdir();
}

def _suffix_or_default(suffix: (str | None)) -> str {
    if isinstance(suffix, str) {
        return suffix;
    }
    return "";
}

def _prefix_or_default(prefix: (str | None)) -> str {
    if isinstance(prefix, str) {
        return prefix;
    }
    return template;
}

def:pub gettempdir -> str {
    if _tempdir_set {
        return _tempdir;
    }
    cand: list[str] = [];
    for env in ["TMPDIR", "TEMP", "TMP"] {
        v: (str | None) = os.getenv(env);
        if isinstance(v, str) and v != "" {
            cand.append(v);
        }
    }
    for d in ["/tmp", "/var/tmp", "/usr/tmp"] {
        cand.append(d);
    }
    for d in cand {
        if os.path.isdir(d) and tf_access(d, 7) == 0 {
            _tempdir = d;
            _tempdir_set = True;
            return d;
        }
    }
    cwd: str = os.getcwd();
    if tf_access(cwd, 7) == 0 {
        _tempdir = cwd;
        _tempdir_set = True;
        return cwd;
    }
    _tempdir_set = True;
    _tempdir = cwd;
    return cwd;
}

def:pub gettempdirb -> bytes {
    return gettempdir().encode();
}

def _candidate_name(dir: str, prefix: str, suffix: str) -> str {
    return os.path.join(dir, prefix + _rng_name() + suffix);
}

def:pub mkstemp(
    suffix: (str | None) = None,
    prefix: (str | None) = None,
    dir: (str | None) = None,
    text: bool = False
) -> tuple[(int, str)] {
    base: str = _dir_or_default(dir);
    suf: str = _suffix_or_default(suffix);
    pre: str = _prefix_or_default(prefix);
    tries: int = 0;
    while tries < TMP_MAX {
        name: str = _candidate_name(base, pre, suf);
        fd: int = tf_create_excl(name, 384);
        if fd >= 0 {
            return (fd, os.path.realpath(name));
        }
        err: int = last_errno();
        tries += 1;
        if err != 17 {
            raise_os_error("mkstemp", name, err);
        }
    }
    raise FileExistsError("No usable temporary file name found");
}

def:pub mkdtemp(
    suffix: (str | None) = None, prefix: (str | None) = None, dir: (str | None) = None
) -> str {
    base: str = _dir_or_default(dir);
    suf: str = _suffix_or_default(suffix);
    pre: str = _prefix_or_default(prefix);
    tries: int = 0;
    while tries < TMP_MAX {
        name: str = _candidate_name(base, pre, suf);
        if tf_mkdir(name, 448) == 0 {
            return os.path.realpath(name);
        }
        err: int = last_errno();
        tries += 1;
        if err != 17 {
            raise_os_error("mkdtemp", name, err);
        }
    }
    raise FileExistsError("No usable temporary directory name found");
}

def:pub mktemp(
    suffix: (str | None) = None, prefix: (str | None) = None, dir: (str | None) = None
) -> str {
    base: str = _dir_or_default(dir);
    suf: str = _suffix_or_default(suffix);
    pre: str = _prefix_or_default(prefix);
    tries: int = 0;
    while tries < TMP_MAX {
        name: str = _candidate_name(base, pre, suf);
        if not os.path.exists(name) {
            return os.path.realpath(name);
        }
        tries += 1;
    }
    raise FileExistsError("No usable temporary file name found");
}

obj:pub TempFile {
    has _fd: int = -1,
        name: str = "",
        _delete: bool = False,
        closed: bool = False,
        _text: bool = False,
        mode: str = "w+b";

    def _check_open {
        if self.closed {
            raise ValueError("I/O operation on closed file.");
        }
    }

    def readable -> bool {
        return True;
    }

    def writable -> bool {
        return True;
    }

    def seekable -> bool {
        return True;
    }

    def fileno -> int {
        return self._fd;
    }

    def flush {
        self._check_open();
    }

    def seek(offset: int, whence: int = 0) -> int {
        self._check_open();
        return tf_seek(self._fd, offset, whence);
    }

    def tell -> int {
        self._check_open();
        return tf_tell(self._fd);
    }

    def write(data: any) -> int {
        self._check_open();
        payload: bytes = b"";
        if isinstance(data, str) {
            payload = data.encode();
        } else {
            payload = data as bytes;
        }
        if tf_write(self._fd, payload) != 0 {
            raise_os_error("write", self.name, last_errno());
        }
        return len(payload);
    }

    def read(size: int = -1) -> any {
        self._check_open();
        out = bytearray();
        if size < 0 {
            while True {
                chunk: bytes = tf_read(self._fd, 65536);
                if len(chunk) == 0 {
                    break;
                }
                out.extend(chunk);
                if len(chunk) < 65536 {
                    break;
                }
            }
        } else {
            out.extend(tf_read(self._fd, size));
        }
        data: bytes = bytes(out);
        if self._text {
            return data.decode("utf-8");
        }
        return data;
    }

    def close {
        if self.closed {
            return;
        }
        self.closed = True;
        if self._fd >= 0 {
            tf_close(self._fd);
            self._fd = -1;
        }
        if self._delete and self.name != "" {
            tf_unlink(self.name);
            self._delete = False;
        }
    }

    def __enter__ -> TempFile {
        self._check_open();
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.close();
        return False;
    }
}

def _mk_tempfile(
    mode: str,
    suffix: (str | None),
    prefix: (str | None),
    dir: (str | None),
    delete: bool,
    anonymous: bool
) -> TempFile {
    flags: tuple[(int, str)] = mkstemp(suffix, prefix, dir);
    f: TempFile = TempFile();
    f._fd = flags[0];
    f.name = flags[1];
    f.mode = mode;
    f._text = not ("b" in mode);
    if anonymous {
        tf_unlink(f.name);
        f._delete = False;
    } else {
        f._delete = delete;
    }
    return f;
}

def:pub NamedTemporaryFile(
    mode: str = "w+b",
    suffix: (str | None) = None,
    prefix: (str | None) = None,
    dir: (str | None) = None,
    delete: bool = True
) -> TempFile {
    return _mk_tempfile(mode, suffix, prefix, dir, delete, False);
}

def:pub TemporaryFile(
    mode: str = "w+b",
    suffix: (str | None) = None,
    prefix: (str | None) = None,
    dir: (str | None) = None
) -> TempFile {
    return _mk_tempfile(mode, suffix, prefix, dir, False, True);
}

obj:pub TemporaryDirectory {
    has name: str = "",
        _ignore_cleanup_errors: bool = False,
        _delete: bool = True;

    def init(
        suffix: (str | None) = None,
        prefix: (str | None) = None,
        dir: (str | None) = None,
        ignore_cleanup_errors: bool = False,
        delete: bool = True
    ) {
        self.name = mkdtemp(suffix, prefix, dir);
        self._ignore_cleanup_errors = ignore_cleanup_errors;
        self._delete = delete;
    }

    def cleanup {
        if self._delete and self.name != "" {
            if os.path.exists(self.name) {
                rmtree(self.name, self._ignore_cleanup_errors);
            }
            self.name = "";
        }
    }

    def __enter__ -> TemporaryDirectory {
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.cleanup();
        return False;
    }
}
