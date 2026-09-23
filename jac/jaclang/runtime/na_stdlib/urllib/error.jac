import from io { BytesIO, StringIO }
import from urllib.response { addinfourl }


def _reason_str(r: any) -> str {
    if isinstance(r, str) {
        return r;
    }
    return str(r);
}


obj:pub URLError(OSError) {
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
    has:pub msg: str = "",
        hdrs: any = None;

    def init(
        url: str, code: int, msg: str, hdrs: any, fp: (BytesIO | StringIO | None)
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
    has:pub content: (bytes | str) = b"";

    def init(message: str, content: (bytes | str)) {
        self.reason = message;
        self.content = content;
    }
}
