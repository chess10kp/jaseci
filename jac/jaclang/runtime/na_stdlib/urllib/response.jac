"""Pure-Jac port of CPython 3.14's ``urllib.response`` (issue #6978).

``addbase`` wraps a file-like object with a minimal file interface;
``addclosehook`` adds a close hook; ``addinfo`` adds ``info()``; and
``addinfourl`` adds ``geturl()`` / ``getcode()`` / ``status``.

Native scope notes:

- CPython's ``addbase`` inherits ``tempfile._TemporaryFileWrapper`` and
  accepts any file object. Natively ``fp`` is typed ``BytesIO | StringIO``
  (the concrete file-like types the bundled ``io`` provides); arbitrary
  duck-typed file objects are a native gap since method calls need a static
  receiver type.
- ``addclosehook`` stores the hook but can only invoke a hook that is a
  ``CloseHook`` archetype (``def call(args)``) -- arbitrary Python callables
  cannot be invoked on the native pathway.
- ``__repr__`` omits CPython's ``id(...)`` (not stable/replicable natively).
"""

import from io { BytesIO, StringIO }


obj:pub addbase {
    """Minimal file-like wrapper; the base for addinfo/addclosehook."""
    has:pub fp: (BytesIO | StringIO);

    def init(fp: (BytesIO | StringIO)) {
        self.fp = fp;
    }

    has:pub file: (BytesIO | StringIO) { getter; }
    has:pub closed: bool { getter; }

    def read(size: int = -1) -> (bytes | str) {
        # Method calls on a union-typed receiver mis-dispatch natively, so
        # narrow explicitly before every call.
        f = self.fp;
        if isinstance(f, BytesIO) {
            return f.read(size);
        }
        if isinstance(f, StringIO) {
            return f.read(size);
        }
        return b"";
    }

    def readline(size: int = -1) -> (bytes | str) {
        f = self.fp;
        if isinstance(f, BytesIO) {
            return f.readline(size);
        }
        if isinstance(f, StringIO) {
            return f.readline(size);
        }
        return b"";
    }

    def readlines(hint: int = -1) -> (list[bytes] | list[str]) {
        f = self.fp;
        if isinstance(f, BytesIO) {
            return f.readlines(hint);
        }
        out: list[str] = [];
        if isinstance(f, StringIO) {
            total: int = 0;
            line = f.readline();
            while len(line) > 0 {
                out.append(line);
                total += len(line);
                if hint > 0 and total > hint {
                    break;
                }
                line = f.readline();
            }
        }
        return out;
    }

    def close {
        f = self.fp;
        if isinstance(f, BytesIO) {
            f.close();
        } elif isinstance(f, StringIO) {
            f.close();
        }
    }

    def __enter__ -> addbase {
        if self.closed {
            raise ValueError("I/O operation on closed file");
        }
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.close();
        return False;
    }

    def __iter__ -> addbase {
        return self;
    }

    def __next__ -> (bytes | str) {
        line = self.readline();
        if isinstance(line, bytes) {
            if len(line) == 0 {
                raise StopIteration;
            }
            return line;
        }
        if len(line) == 0 {
            raise StopIteration;
        }
        return line;
    }
}


obj:pub CloseHook {
    """Callable wrapper a native ``addclosehook`` can invoke on ``close()``;
    subclass it and implement ``call`` (native first-class function calls are
    a backend gap, so a plain ``def`` cannot serve as the hook)."""
    def call(args: list[any]) -> int {
        return 0;
    }
}


obj:pub addclosehook(addbase) {
    """addbase plus a close hook fired once on ``close()``."""
    has:pub closehook: (CloseHook | None) = None,
        hookargs: list[any] = [];

    def init(
        fp: (BytesIO | StringIO),
        closehook: (CloseHook | None) = None,
        hookargs: list[any] = []
    ) {
        self.fp = fp;
        self.closehook = closehook;
        self.hookargs = hookargs;
    }

    def close {
        ch = self.closehook;
        if isinstance(ch, CloseHook) {
            ch.call(self.hookargs);
            self.closehook = None;
            self.hookargs = [];
        }
        addbase.close(self);
    }
}


obj:pub addinfo(addbase) {
    """addbase plus an ``info()`` returning the response headers."""
    has:pub headers: any = None;

    def init(fp: (BytesIO | StringIO), headers: any) {
        self.fp = fp;
        self.headers = headers;
    }

    def info -> any {
        return self.headers;
    }
}


obj:pub addinfourl(addinfo) {
    """addinfo plus ``geturl()`` / ``getcode()`` / ``status``."""
    has:pub url: str = "",
        code: (int | None) = None;

    def init(
        fp: (BytesIO | StringIO),
        headers: any,
        url: str,
        code: (int | None) = None
    ) {
        self.fp = fp;
        self.headers = headers;
        self.url = url;
        self.code = code;
    }

    has:pub status: (int | None) { getter; }

    def getcode -> (int | None) {
        return self.code;
    }

    def geturl -> str {
        return self.url;
    }
}

impl addbase.file.getter -> (BytesIO | StringIO) {
    return self.fp;
}


impl addbase.closed.getter -> bool {
    f = self.fp;
    if isinstance(f, BytesIO) {
        return f.closed;
    }
    if isinstance(f, StringIO) {
        return f.closed;
    }
    return True;
}


impl addinfourl.status.getter -> (int | None) {
    return self.code;
}
