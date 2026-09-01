def pystr_endswith_c(s: str, suffix: str) -> int {
    ns: int = 0;
    nfx: int = 0;
    i: int = 0;
    if (not s) or (not suffix) {
        return 0;
    }

    ns = len(s);
    nfx = len(suffix);
    if (nfx > ns) {
        return 0;
    }

    i = 0;
    while i < nfx {
        if ((ord(s[((ns - nfx) + i)]) & 255) != (ord(suffix[i]) & 255)) {
            return 0;
        }

        i += 1;
    }

    return 1;
}
