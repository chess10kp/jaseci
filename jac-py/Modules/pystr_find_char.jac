def pystr_find_char(s: str, ch: int) -> int {
    i: int = 0;
    want: int = ch & 255;
    if not s {
        return -1;
    }

    i = 0;
    while i < len(s) {
        if (ord(s[i]) & 255) == want {
            return i;
        }

        i += 1;
    }

    return -1;
}
