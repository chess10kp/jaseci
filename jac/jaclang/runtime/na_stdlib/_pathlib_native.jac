import from c { def lstat(path: str, buf: int) -> i32;  }
import from c { def malloc(size: int) -> int;  }

glob _PL_STBUF: int = malloc(512);

def:pub pl_lexists(path: str) -> bool {
    return lstat(path, _PL_STBUF) == 0;
}

def:pub pl_islink(path: str) -> bool {
    if lstat(path, _PL_STBUF) != 0 {
        return False;
    }
    return (__mem_load_i32(_PL_STBUF + 24) & 61440) == 40960;
}
