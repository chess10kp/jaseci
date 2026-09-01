def pystr_count_char(s: str, ch: int) -> int {
    n: int = 0;
    i: int = 0;
    want: int = ch & 255;
    if not s {
        return 0;
    }

    n = 0;
    i = 0;
    while i < len(s) {
        if (ord(s[i]) & 255) == want {
            n += 1;
        }

        i += 1;
    }

    return n;
}
