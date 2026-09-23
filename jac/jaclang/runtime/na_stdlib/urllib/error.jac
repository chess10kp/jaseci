"""Pure-Jac port of CPython 3.14's ``urllib.error`` (issue #6978).

``URLError`` (an ``OSError``) is the base; ``HTTPError`` is both an exception
and a valid response (it multi-inherits ``addinfourl``);
``ContentTooShortError`` reports a short ``urlretrieve`` download.

Native scope notes:

- ``URLError.args`` is not assigned (native exception ``args`` are managed by
  the raise machinery, not by ``init``); ``reason`` / ``filename`` carry the
  payload instead.
- ``HTTPError.fp`` accepts ``BytesIO | StringIO | None`` (``None`` becomes an
  empty ``BytesIO``), matching the bundled ``urllib.response`` file-type
  scope; ``headers`` is read-only (the CPython setter is a native gap).
"""

import from io { BytesIO, StringIO }
import from urllib.response { addinfourl }


def _reason_str(r: any) -> str {
    if isinstance(r, str) {
        return r;
    }
    return str(r);
}


obj:pub URLError(OSError) {
    """Base exception for urllib errors; carries ``reason`` (and optionally
    ``filename``) rather than the usual OSError errno/strerror pair."""
    has:pub reason: (str | None) = None,
        filename: (str | None) = None;

    def init(reason: any, filename: (str | None) = None) {
        if isinstance(reason, str) {
            self.reason = reason;
        } else {
            self.reason = _reason_str(reason);
        }
        if isinstance(filename, str) {
            self.filename = filename;
        }
    }

    def __str__ -> str {
        r = self.reason;
        if isinstance(r, str) {
            return "<urlopen error " + r + ">";
        }
        return "<urlopen error>";
    }
}


obj:pub HTTPError(URLError, addinfourl) {
    """HTTP error: an exception that is also a valid response object.

    ``code`` / ``headers`` / ``url`` / ``fp`` come from ``addinfourl`` so that
    the inherited ``status`` / ``getcode`` / ``info`` accessors stay
    consistent; ``msg`` and ``hdrs`` are the HTTPError-specific aliases."""
    has:pub msg: str = "",
        hdrs: any = None;

    def init(
        url: str,
        code: int,
        msg: str,
        hdrs: any,
        fp: (BytesIO | StringIO | None)
    ) {
        self.code = code;
        self.msg = msg;
        self.hdrs = hdrs;
        self.headers = hdrs;
        self.filename = url;
        self.reason = msg;
        if isinstance(fp, BytesIO) {
            self.fp = fp;
        } elif isinstance(fp, StringIO) {
            self.fp = fp;
        } else {
            self.fp = BytesIO();
        }
        self.url = url;
    }

    def __str__ -> str {
        return "HTTP Error " + str(self.code) + ": " + self.msg;
    }

    def __repr__ -> str {
        return "<HTTPError " + str(self.code) + ": '" + self.msg + "'>";
    }
}


obj:pub ContentTooShortError(URLError) {
    """Downloaded size does not match Content-Length; carries the partial
    ``content``."""
    has:pub content: (bytes | str) = b"";

    def init(message: str, content: (bytes | str)) {
        self.reason = message;
        self.content = content;
    }
}
