def pystr_startswith_c(s: str, prefix: str) -> int {
    i: int = 0;
    if (not s) or (not prefix) {
        return 0;
    }

    i = 0;
    while i < len(prefix) {
        if (i >= len(s)) {
            return 0;
        }

        if ((ord(s[i]) & 255) != (ord(prefix[i]) & 255)) {
            return 0;
        }

        i += 1;
    }

    return 1;
}
