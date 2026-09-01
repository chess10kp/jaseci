def _uchar(c: int) -> int {
    return c & 0xFF;
}

def pystr_cmp_c(a: str, b: str) -> int {
    if (not a) and (not b) {
        return 0;
    }

    if not a {
        return -1;
    }

    if not b {
        return 1;
    }

    while (
        _uchar(ord(a[0]) if a else 0)
        and (_uchar(ord(a[0]) if a else 0) == _uchar(ord(b[0]) if b else 0))
    ) {
        a = a[1:];
        b = b[1:];
    }

    return _uchar(ord(a[0]) if a else 0) - _uchar(ord(b[0]) if b else 0);
}
