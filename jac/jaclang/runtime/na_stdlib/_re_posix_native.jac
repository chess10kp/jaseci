import from c {
    def regcomp(preg: bytes, pattern: str, cflags: i32) -> i32;  def regexec(
        preg: bytes, string: str, nmatch: u64, pmatch: bytes, eflags: i32
    ) -> i32;
}

glob _REG_EXTENDED: i32 = 1,
     _REG_ICASE: i32 = 2;


def:pub posix_compile(pat: str, icase: bool) -> bytes {
    preg: bytes = b"\x00" * 256;
    cflags: i32 = _REG_EXTENDED;
    if icase {
        cflags += _REG_ICASE;
    }
    if regcomp(preg, pat, cflags) != 0 {
        return b"";
    }
    return preg;
}


def:pub posix_exec(preg: bytes, s: str, nmatch: int) -> bytes {
    pm: bytes = b"\x00" * (8 * nmatch);
    if regexec(preg, s, u64(nmatch), pm, 0) != 0 {
        return b"";
    }
    return pm;
}


def:pub pm_i32(pm: bytes, i: int) -> int {
    off: int = i * 4;
    v: int = pm[off] | (pm[off + 1] << 8) | (pm[off + 2] << 16) | (pm[off + 3] << 24);
    if v >= 2147483648 {
        v -= 4294967296;
    }
    return v;
}
