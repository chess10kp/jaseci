import os;
import sys;
import from _tempfile_native { tf_stdin_read_all }

def _resolve_files(files: (list[str] | str | None)) -> list[str] {
    if isinstance(files, str) {
        return [files];
    }
    if isinstance(files, list[str]) {
        if len(files) == 0 {
            return ["-"];
        }
        return files;
    }
    argv: list[str] = sys.argv;
    if len(argv) > 1 {
        return argv[1:];
    }
    return ["-"];
}

obj:pub FileInput {
    has _files: list[str] = [],
        _lines: list[str] = [],
        _lp: int = 0,
        _pending: str = "",
        _filename: (str | None) = None,
        _startlineno: int = 0,
        _filelineno: int = 0,
        _file_open: bool = False,
        _isstdin: bool = False,
        _mode: str = "r";

    def init(
        files: (list[str] | str | None) = None,
        inplace: bool = False,
        backup: str = "",
        mode: str = "r"
    ) {
        if inplace {
            raise ValueError("FileInput inplace mode is not supported natively");
        }
        if mode != "r" {
            raise ValueError("FileInput opening mode must be 'r' or 'rb'");
        }
        self._mode = mode;
        self._files = _resolve_files(files);
    }

    def _open_next {
        nm: str = self._files[0];
        self._filename = nm;
        self._files = self._files[1:];
        self._startlineno = self.lineno();
        self._filelineno = 0;
        self._lines = [];
        self._lp = 0;
        self._pending = "";
        self._file_open = True;
        self._isstdin = False;
        body: str = "";
        if nm == "-" {
            self._filename = "<stdin>";
            self._isstdin = True;
            body = tf_stdin_read_all();
        } else {
            f = open(nm, "r");
            try {
                body = f.read();
            } finally {
                f.close();
            }
        }
        self._lines = body.splitlines(True);
    }

    def _pop_line -> str {
        if not self._file_open {
            if len(self._files) == 0 {
                return "";
            }
            self._open_next();
        }
        if self._pending != "" {
            line: str = self._pending;
            self._pending = "";
            return line;
        }
        if self._lp < len(self._lines) {
            line = self._lines[self._lp];
            self._lp += 1;
            return line;
        }
        return "";
    }

    def readline -> str {
        while True {
            line: str = self._pop_line();
            if line != "" {
                self._filelineno += 1;
                return line;
            }
            if not self._file_open {
                return line;
            }
            self.nextfile();
        }
    }

    def __iter__ -> FileInput {
        return self;
    }

    def __next__ -> str {
        while True {
            line: str = self._pop_line();
            if line != "" {
                self._filelineno += 1;
                return line;
            }
            if not self._file_open {
                raise StopIteration();
            }
            self.nextfile();
        }
    }

    def nextfile {
        self._lines = [];
        self._lp = 0;
        self._pending = "";
        self._file_open = False;
        self._isstdin = False;
    }

    def close {
        try {
            self.nextfile();
        } finally {
            self._files = [];
        }
    }

    def __enter__ -> FileInput {
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.close();
        return False;
    }

    def filename -> (str | None) {
        return self._filename;
    }

    def lineno -> int {
        return self._startlineno + self._filelineno;
    }

    def filelineno -> int {
        return self._filelineno;
    }

    def fileno -> int {
        if self._file_open and self._isstdin {
            return 0;
        }
        return -1;
    }

    def isfirstline -> bool {
        return self._filelineno == 1;
    }

    def isstdin -> bool {
        return self._isstdin;
    }
}

glob _FI: FileInput = FileInput([]),
     _FI_SET: bool = False;

def:pub input(
    files: (list[str] | str | None) = None,
    inplace: bool = False,
    backup: str = "",
    mode: str = "r"
) -> FileInput {
    if _FI_SET and _FI._file_open {
        raise RuntimeError("input() already active");
    }
    _FI = FileInput(files, inplace, backup, mode);
    _FI_SET = True;
    return _FI;
}

def:pub close {
    was_set: bool = _FI_SET;
    _FI_SET = False;
    if was_set {
        _FI.close();
    }
}

def:pub nextfile {
    if not _FI_SET {
        raise RuntimeError("no active input()");
    }
    _FI.nextfile();
}

def:pub filename -> (str | None) {
    if not _FI_SET {
        raise RuntimeError("no active input()");
    }
    return _FI.filename();
}

def:pub lineno -> int {
    if not _FI_SET {
        raise RuntimeError("no active input()");
    }
    return _FI.lineno();
}

def:pub filelineno -> int {
    if not _FI_SET {
        raise RuntimeError("no active input()");
    }
    return _FI.filelineno();
}

def:pub fileno -> int {
    if not _FI_SET {
        raise RuntimeError("no active input()");
    }
    return _FI.fileno();
}

def:pub isfirstline -> bool {
    if not _FI_SET {
        raise RuntimeError("no active input()");
    }
    return _FI.isfirstline();
}

def:pub isstdin -> bool {
    if not _FI_SET {
        raise RuntimeError("no active input()");
    }
    return _FI.isstdin();
}
